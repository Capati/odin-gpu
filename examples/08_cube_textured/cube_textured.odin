package cube_textured

// Core
import "core:mem"
import "core:log"
import "core:math"
import la "core:math/linalg"

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"

CLIENT_WIDTH    :: 640
CLIENT_HEIGHT   :: 480
EXAMPLE_TITLE   :: "Cube Textured"
DEPTH_FORMAT    :: gpu.Texture_Format.Depth24_Plus
COLOR_DARK_GRAY :: gpu.Color{0.6, 0.6, 0.6, 1.0}
TEXEL_SIZE      :: 256

Application :: struct {
    using gc:        app.GPU_Context,

    vertex_buffer:   gpu.Buffer,
    index_buffer:    gpu.Buffer,
    uniform_buffer:  gpu.Buffer,
    render_pipeline: gpu.Render_Pipeline,
    bind_group:      gpu.Bind_Group,
    sampler:         gpu.Sampler,
    depth_texture:   app.Depth_Stencil_Texture,
    rpass:           struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    // Creates vertex buffer containing cube vertices with position and uv coordinates
    self.vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = EXAMPLE_TITLE + " Vertex Buffer",
            usage = {.Vertex},
        },
        gpu.to_bytes(vertex_data),
    )

    // Creates index buffer
    self.index_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = EXAMPLE_TITLE + " Index Buffer",
            usage = {.Index},
        },
        gpu.to_bytes(index_data),
    )

    texture_extent := gpu.Extent_3D {
        width                 = TEXEL_SIZE,
        height                = TEXEL_SIZE,
        depth_or_array_layers = 1,
    }

    texture := gpu.device_create_texture(
        self.device,
        {
            label           = "Mandelbrot Texels",
            size            = texture_extent,
            mip_level_count = 1,
            sample_count    = 1,
            dimension       = .D2,
            format          = .R8_Unorm,
            usage           = { .Texture_Binding, .Copy_Dst },
        },
    )
    defer gpu.release(texture)

    texture_view := gpu.texture_create_view(texture)
    defer gpu.release(texture_view)

    // Generates a dynamic texture using the Mandelbrot fractal algorithm
    texels := create_texels()

    gpu.queue_write_texture(
        self.queue,
        {
            texture = texture,
            mip_level = 0,
            origin = {},
            aspect = .All,
        },
        gpu.to_bytes(texels),
        {
            offset = 0,
            bytes_per_row = TEXEL_SIZE,
            rows_per_image = TEXEL_SIZE,
        },
        texture_extent,
    )

    // Create sampler
    sampler_desc := gpu.SAMPLER_DESCRIPTOR_DEFAULT
    self.sampler = gpu.device_create_sampler(self.device, sampler_desc)
    defer gpu.release(self.sampler)

    mx_total := create_view_projection_matrix(
        cast(f32)self.config.width / cast(f32)self.config.height,
    )

    self.uniform_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = EXAMPLE_TITLE + " Uniform Buffer",
            usage = {.Uniform, .Copy_Dst},
        },
        gpu.to_bytes(mx_total),
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
                {
                    binding = 1,
                    visibility = {.Fragment},
                    type = gpu.Texture_Binding_Layout {
                        sample_type = .Float,
                        view_dimension = .D2,
                        multisampled = false,
                    },
                },
                {
                    binding = 2,
                    visibility = {.Fragment},
                    type = gpu.Sampler_Binding_Layout {
                        type = .Filtering,
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

    vertex_buffer_layout := gpu.Vertex_Buffer_Layout {
        array_stride = size_of(Vertex),
        step_mode    = .Vertex,
        attributes   = {
            {format = .Float32x4, offset = 0, shader_location = 0},
            {
                format = .Float32x2,
                offset = u64(offset_of(Vertex, tex_coords)),
                shader_location = 1,
            },
        },
    }

    depth_stencil := app.create_depth_stencil_state()

    self.render_pipeline = gpu.device_create_render_pipeline(
        self.device,
        {
            label = EXAMPLE_TITLE + " Render Pipeline",
            layout = pipeline_layout,
            vertex = {
                module = vertex_shader,
                entry_point = "vs_main",
                buffers = {vertex_buffer_layout},
            },
            fragment = &{
                module = fragment_shader,
                entry_point = "fs_main",
                targets = {
                    {
                        format = self.config.format,
                        blend = &gpu.BLEND_STATE_REPLACE,
                        write_mask = gpu.COLOR_WRITES_ALL,
                    },
                },
            },
            depth_stencil = &depth_stencil,
            primitive = {
                topology = .Triangle_List,
                front_face = .Ccw,
                cull_mode = .Back,
            },
            multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
        },
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
                        size = gpu.WHOLE_SIZE,
                    },
                },
                {
                    binding = 1,
                    resource = texture_view,
                },
                {
                    binding = 2,
                    resource = self.sampler,
                },
            },
        },
    )

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops  = { .Clear, .Store, {0.1, 0.2, 0.3, 1.0} },
    }

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = nil, // Assigned later
    }

    create_depth_stencil_texture(self, self.config.width, self.config.height)

    return .Continue
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.release(encoder)

    self.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.release(rpass)

    gpu.render_pass_set_pipeline(rpass, self.render_pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, self.bind_group)
    gpu.render_pass_set_vertex_buffer(rpass, 0, self.vertex_buffer)
    gpu.render_pass_set_index_buffer(rpass, self.index_buffer, .Uint16)
    gpu.render_pass_draw_indexed(rpass, {0, u32(len(index_data))}, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (res: app.App_Result) {
    #partial switch &ev in event {
    case app.Resize_Event:
        resize(self, ev.width, ev.height)
    }
    return .Continue
}

quit :: proc(self: ^Application, res: app.App_Result) {
    app.release_depth_stencil_texture(self.depth_texture)

    gpu.release(self.bind_group)
    gpu.release(self.render_pipeline)
    gpu.release(self.uniform_buffer)
    gpu.release(self.index_buffer)
    gpu.release(self.vertex_buffer)

    free(self)
}

resize :: proc(self: ^Application, width, height: u32) {
    recreate_depth_stencil_texture(self, width, height)

    data := create_view_projection_matrix(f32(width) / f32(height))
    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(data),
    )
}

create_depth_stencil_texture :: proc(self: ^Application, width, height: u32) {
    self.depth_texture = app.create_depth_stencil_texture(self.device, {
        width = width, height = height,
    })
    self.rpass.descriptor.depth_stencil_attachment = &self.depth_texture.descriptor
}

recreate_depth_stencil_texture :: proc(self: ^Application, width, height: u32) {
    app.release_depth_stencil_texture(self.depth_texture)
    create_depth_stencil_texture(self, width, height)
}

create_texels :: proc() -> (texels: [TEXEL_SIZE * TEXEL_SIZE]u8) {
    for id := 0; id < (TEXEL_SIZE * TEXEL_SIZE); id += 1 {
        cx := 3.0 * f32(id % TEXEL_SIZE) / f32(TEXEL_SIZE - 1) - 2.0
        cy := 2.0 * f32(id / TEXEL_SIZE) / f32(TEXEL_SIZE - 1) - 1.0
        x, y, count := f32(cx), f32(cy), u8(0)
        for count < 0xFF && x * x + y * y < 4.0 {
            old_x := x
            x = x * x - y * y + cx
            y = 2.0 * old_x * y + cy
            count += 1
        }
        texels[id] = count
    }

    return
}

create_view_projection_matrix :: proc(aspect: f32) -> la.Matrix4f32 {
    projection := la.matrix4_perspective_f32(math.PI / 4, aspect, 1.0, 10.0)
    view := la.matrix4_look_at_f32(
        eye = {1.5, -5.0, 3.0},
        centre = {0.0, 0.0, 0.0},
        up = {0.0, 0.0, 1.0},
    )
    return la.mul(projection, view)
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
