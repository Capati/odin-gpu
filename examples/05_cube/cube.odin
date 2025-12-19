package cube

// Core
import "core:log"
import "core:mem"
import la "core:math/linalg"

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"

CLIENT_WIDTH    :: 640
CLIENT_HEIGHT   :: 480
EXAMPLE_TITLE   :: "Cube"
DEPTH_FORMAT    :: gpu.Texture_Format.Depth24_Plus
COLOR_DARK_GRAY :: gpu.Color{0.6, 0.6, 0.6, 1.0}

Application :: struct {
    using gc:        app.GPU_Context,

    render_pipeline: gpu.Render_Pipeline,
    vertex_buffer:   gpu.Buffer,
    uniform_buffer:  gpu.Buffer,
    bind_group:      gpu.Bind_Group,
    depth_view:      gpu.Texture_View,

    // Cache the render pass descriptor
    rpass:           struct {
        colors:                   [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:               gpu.Render_Pass_Descriptor,
    },
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    self.vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Vertex buffer",
            usage = {.Vertex},
        },
        vertex_data[:],
    )

    // Load and create a shader module
    vertex_source := shaders.load(self.device, .Vertex)
    vertex_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Vertex Shader",
            code = vertex_source,
            stage = .Vertex,
        },
    )
    defer gpu.release(vertex_shader)

    fragment_source := shaders.load(self.device, .Fragment)
    fragment_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Fragment Shader",
            code = fragment_source,
            stage = .Fragment,
        },
    )
    defer gpu.release(fragment_shader)

    bind_group_layout := gpu.device_create_bind_group_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Bind Group Layout",
            entries = {
                {
                    binding = 0,
                    visibility = {.Vertex},
                    type = gpu.Buffer_Binding_Layout {
                        type = .Uniform,
                        has_dynamic_offset = false,
                        min_binding_size = size_of(la.Matrix4f32),
                    },
                },
            },
        },
    )
    defer gpu.release(bind_group_layout)

    pipeline_layout := gpu.device_create_pipeline_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Pipeline Layout",
            bind_group_layouts = {bind_group_layout},
        },
    )
    defer gpu.release(pipeline_layout)

    pipeline_descriptor := gpu.Render_Pipeline_Descriptor {
        label = EXAMPLE_TITLE + " Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module = vertex_shader,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        { format = .Float32x3, offset = 0, shader_location = 0 },
                        {
                            format = .Float32x3,
                            offset = u64(offset_of(Vertex, color)),
                            shader_location = 1,
                        },
                    },
                },
            },
        },
        fragment = &{
            module = fragment_shader,
            entry_point = "fs_main",
            targets = {
                {
                    format = self.config.format,
                    blend = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {topology = .Triangle_List, front_face = .Ccw, cull_mode = .Back},
        // Enable depth testing so that the fragment closest to the camera
        // is rendered in front.
        depth_stencil = &{
            format = DEPTH_FORMAT,
            depth_write_enabled = true,
            depth_compare = .Less,
            stencil = {
                front = {
                    compare = .Always,
                    fail_op = .Keep,
                    depth_fail_op = .Keep,
                    pass_op = .Keep,
                },
                back = {
                    compare = .Always,
                    fail_op = .Keep,
                    depth_fail_op = .Keep,
                    pass_op = .Keep,
                },
                read_mask = 0xFFFFFFFF,
                write_mask = 0xFFFFFFFF,
            },
        },
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    }

    // Create the triangle pipeline
    self.render_pipeline =
        gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    aspect := f32(self.config.width) / f32(self.config.height)
    mvp_mat := app.create_view_projection_matrix(aspect)

    self.uniform_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Uniform buffer",
            usage = {.Uniform, .Copy_Dst},
        },
        gpu.to_bytes(mvp_mat),
    )

    self.bind_group = gpu.device_create_bind_group(
        self.device,
        {
            layout = bind_group_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = self.uniform_buffer,
                        size = gpu.buffer_get_size(self.uniform_buffer),
                    },
                },
            },
        },
    )

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops = {
            load = .Clear,
            store = .Store,
            clear_value = COLOR_DARK_GRAY,
        },
    }

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = &self.rpass.depth_stencil_attachment,
    }

    create_depth_framebuffer(self)

    return .Continue
}

create_depth_framebuffer :: proc(self: ^Application) {
    adapter_features := gpu.adapter_get_features(self.adapter)
    format_features :=
        gpu.texture_format_guaranteed_format_features(DEPTH_FORMAT, adapter_features)

    // Check if render attachment is supported
    assert(.Render_Attachment in format_features.allowed_usages,
           "Depth format does not support render attachment")

    width, height := app.get_framebuffer_size()

    texture_descriptor := gpu.Texture_Descriptor {
        size            = { width, height, 1 },
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = DEPTH_FORMAT,
        usage           = { .Copy_Src, .Copy_Dst, .Render_Attachment },
    }

    texture := gpu.device_create_texture(self.device, texture_descriptor)
    defer gpu.release(texture)

    self.depth_view = gpu.texture_create_view(texture)

    // Setup depth stencil attachment
    self.rpass.depth_stencil_attachment = {
        view = self.depth_view,
        depth_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 1.0,
        },
    }
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    // Creates an empty Command_Encoder
    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.release(encoder)

    // Begins recording of a render pass
    self.rpass.colors[0].view = frame.view
    render_pass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.release(render_pass)

    // Sets the active render pipeline
    gpu.render_pass_set_pipeline(render_pass, self.render_pipeline)
    // Sets the active bind group
    gpu.render_pass_set_bind_group(render_pass, 0, self.bind_group)
    // Bind the vertex buffer (contain position & colors)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, self.vertex_buffer)
    // Draws primitives in the range of vertices
    gpu.render_pass_draw(render_pass, {0, u32(len(vertex_data))})
    // Record the end of the render pass
    gpu.render_pass_end(render_pass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (ok: bool) {
    #partial switch &ev in event {
        case app.Resize_Event:
            resize(self, ev.width, ev.height)
    }
    return true
}

quit :: proc(self: ^Application, res: app.App_Result) {
    gpu.release(self.depth_view)
    gpu.release(self.bind_group)
    gpu.release(self.uniform_buffer)
    gpu.release(self.vertex_buffer)
    gpu.release(self.render_pipeline)

    free(self)
}

resize :: proc(self: ^Application, width, height: u32) {
    gpu.texture_view_release(self.depth_view)
    create_depth_framebuffer(self)

    // Update uniform buffer with new aspect ratio
    aspect := f32(width) / f32(height)
    new_matrix := app.create_view_projection_matrix(aspect)
    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(new_matrix),
    )
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})
        defer log.destroy_console_logger(context.logger)

        // TODO(Capati): WASM requires additional flags for the tracking allocator?
        when ODIN_OS != .JS {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)

            defer {
                if len(track.allocation_map) > 0 {
                    log.warnf("=== %v allocations not freed: ===", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        log.debugf("- %v bytes @ %v", entry.size, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }
    }

    // Set main callbacks
    app.init_proc = cast(app.App_Init_Proc)init
    app.quit_proc = cast(app.App_Quit_Proc)quit
    app.iterate_proc = cast(app.App_Iterate_Proc)iterate
    app.event_proc = cast(app.App_Event_Proc)event

    // Initialize framework and run application
    app.init(EXAMPLE_TITLE, CLIENT_WIDTH, CLIENT_HEIGHT)
}
