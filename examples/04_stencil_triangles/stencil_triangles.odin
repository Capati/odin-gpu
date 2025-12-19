package stencil_triangles

// Core
import "core:log"
import "core:mem"
import la "core:math/linalg"

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"

CLIENT_WIDTH  :: 640
CLIENT_HEIGHT :: 480
EXAMPLE_TITLE :: "Stencil Triangles"

STENCIL_FORMAT :: gpu.Texture_Format.Stencil8

Application :: struct {
    using gc:            app.GPU_Context,
    outer_vertex_buffer: gpu.Buffer,
    mask_vertex_buffer:  gpu.Buffer,
    outer_pipeline:      gpu.Render_Pipeline,
    mask_pipeline:       gpu.Render_Pipeline,
    stencil_buffer:      gpu.Texture,
    depth_view:          gpu.Texture_View,
    depth_texture:       app.Depth_Stencil_Texture,
    rpass:               struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        depth:      gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

Vertex :: struct {
    pos: la.Vector4f32,
}

vertex :: proc(x, y: f32) -> Vertex {
    return {pos = {x, y, 0.0, 1.0}}
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    outer_vertices := []Vertex{vertex(-1.0, -1.0), vertex(1.0, -1.0), vertex(0.0, 1.0)}
    self.outer_vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Outer Vertex Buffer",
            usage = {.Vertex},
        },
        outer_vertices[:],
    )

    mask_vertices := []Vertex{vertex(-0.5, 0.0), vertex(0.0, -1.0), vertex(0.5, 0.0)}
    self.mask_vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Mask Vertex Buffer",
            usage = {.Vertex},
        },
        mask_vertices[:],
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
    defer gpu.shader_module_release(vertex_shader)

    fragment_source := shaders.load(self.device, .Fragment)
    fragment_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Fragment Shader",
            code = fragment_source,
            stage = .Fragment,
        },
    )
    defer gpu.shader_module_release(fragment_shader)

    vertex_buffers := [1]gpu.Vertex_Buffer_Layout {
        {
            array_stride = size_of(Vertex),
            step_mode    = .Vertex,
            attributes  = {{format = .Float32x4, offset = 0, shader_location = 0}},
        },
    }

    pipeline_descriptor := gpu.Render_Pipeline_Descriptor {
        label = EXAMPLE_TITLE + " Render Pipeline",
        vertex = {
            module = vertex_shader,
            entry_point = "vs_main",
            buffers = vertex_buffers[:],
        },
        fragment = &{
            module = fragment_shader,
            entry_point = "fs_main",
            targets = {
                {
                    format = self.config.format,
                    write_mask = gpu.COLOR_WRITES_NONE,
                },
            },
        },
        primitive = gpu.PRIMITIVE_STATE_DEFAULT,
        depth_stencil = &{
            format = STENCIL_FORMAT,
            depth_write_enabled = false,
            depth_compare = .Always,
            stencil = {
                front = {
                    compare = .Always,
                    fail_op = .Keep,
                    depth_fail_op = .Keep,
                    pass_op = .Replace,
                },
                back = gpu.STENCIL_FACE_STATE_IGNORE,
                read_mask = max(u32),
                write_mask = max(u32),
            },
        },
        multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
    }

    pipeline_descriptor.label = "Mask Pipeline"

    self.mask_pipeline =
        gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    pipeline_descriptor.label = "Outer Pipeline"
    pipeline_descriptor.depth_stencil.stencil.front = {
        compare = .Greater,
        fail_op = .Keep,
        depth_fail_op = .Keep,
        pass_op = .Keep,
    }
    pipeline_descriptor.fragment.targets[0].write_mask = gpu.COLOR_WRITES_ALL

    self.outer_pipeline =
        gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops  = { .Clear, .Store, { 0.1, 0.2, 0.3, 1.0 } },
    }

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = nil, // Assigned later
    }

    create_stencil_buffer(self, self.config.width, self.config.height)

    return .Continue
}

create_stencil_buffer :: proc(self: ^Application, width, height: u32) {
    self.stencil_buffer = gpu.device_create_texture(
        self.device,
        {
            label = "Stencil buffer",
            size = {
                width              = width,
                height             = height,
                depth_or_array_layers = 1,
            },
            mip_level_count = 1,
            sample_count    = 1,
            dimension       = .D2,
            format          = STENCIL_FORMAT,
            usage           = {.Render_Attachment},
        },
    )

    texture_view_descriptor := gpu.Texture_View_Descriptor {
        format            = STENCIL_FORMAT,
        dimension         = .D2,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .All,
    }

    self.depth_view = gpu.texture_create_view(self.stencil_buffer, texture_view_descriptor)

    self.rpass.depth = {
        view = self.depth_view,
        depth_ops = {
            clear_value = 1.0,
        },
        stencil_ops = {
            load       = .Clear,
            store      = .Store,
            clear_value = 0.0,
        },
    }

    self.rpass.descriptor.depth_stencil_attachment = &self.rpass.depth
}

recreate_stencil_buffer :: proc(self: ^Application, width, height: u32) {
    destroy_stencil_buffer(self)
    create_stencil_buffer(self, width, height)
}

destroy_stencil_buffer :: proc(self: ^Application) {
    gpu.release(self.stencil_buffer)
    gpu.release(self.depth_view)
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.command_encoder_release(encoder)

    self.rpass.colors[0].view = frame.view
    render_pass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.render_pass_release(render_pass)

    gpu.render_pass_set_pipeline(render_pass, self.mask_pipeline)
    gpu.render_pass_set_stencil_reference(render_pass, 1)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, self.mask_vertex_buffer)
    gpu.render_pass_draw(render_pass, {0, 3})

    gpu.render_pass_set_pipeline(render_pass, self.outer_pipeline)
    gpu.render_pass_set_stencil_reference(render_pass, 1)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, self.outer_vertex_buffer)
    gpu.render_pass_draw(render_pass, {0, 3})

    gpu.render_pass_end(render_pass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (res: app.App_Result) {
    #partial switch &ev in event {
    case app.Resize_Event:
        recreate_stencil_buffer(self, ev.width, ev.height)
    }
    return .Continue
}

quit :: proc(self: ^Application, res: app.App_Result) {
    destroy_stencil_buffer(self)

    gpu.release(self.outer_pipeline)
    gpu.release(self.mask_pipeline)
    gpu.release(self.mask_vertex_buffer)
    gpu.release(self.outer_vertex_buffer)

    free(self)
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
