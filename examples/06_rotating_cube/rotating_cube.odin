package rotating_cube

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
EXAMPLE_TITLE   :: "Rotating Cube"
DEPTH_FORMAT    :: gpu.Texture_Format.Depth24_Plus
COLOR_DARK_GRAY :: gpu.Color{0.6, 0.6, 0.6, 1.0}

Application :: struct {
    using gc:           app.GPU_Context,

    vertex_buffer:      gpu.Buffer,
    index_buffer:       gpu.Buffer,
    render_pipeline:    gpu.Render_Pipeline,
    uniform_buffer:     gpu.Buffer,
    uniform_bind_group: gpu.Bind_Group,
    projection_matrix:  la.Matrix4f32,
    depth_texture:      app.Depth_Stencil_Texture,

    // Cache the render pass descriptor
    rpass:              struct {
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
            label = EXAMPLE_TITLE + " Vertex Data",
            usage = {.Vertex},
        },
        gpu.to_bytes(CUBE_VERTEX_DATA),
    )

    self.index_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = EXAMPLE_TITLE + " Index Buffer",
            usage = {.Index},
        },
        gpu.to_bytes(CUBE_INDICES_DATA),
    )

    vertex_buffer_layout := gpu.Vertex_Buffer_Layout {
        array_stride = size_of(Vertex),
        step_mode    = .Vertex,
        attributes   = {
            {format = .Float32x4, offset = 0, shader_location = 0},
            {format = .Float32x4, offset = u64(offset_of(Vertex, color)), shader_location = 1},
            {
                format = .Float32x2,
                offset = u64(offset_of(Vertex, tex_coords)),
                shader_location = 2,
            },
        },
    }

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
                        blend = &gpu.BLEND_STATE_NORMAL,
                        write_mask = gpu.COLOR_WRITES_ALL,
                    },
                },
            },
            primitive = {
                topology   = .Triangle_List,
                front_face = .Ccw,
                // Backface culling since the cube is solid piece of geometry.
                // Faces pointing away from the camera will be occluded by faces
                // pointing toward the camera.
                cull_mode  = .Back,
            },
            // Enable depth testing so that the fragment closest to the camera
            // is rendered in front.
            depth_stencil = &{
                depth_write_enabled = true,
                depth_compare = .Less,
                format = DEPTH_FORMAT,
                stencil = {
                    back = { compare = .Always },
                    front = { compare = .Always },
                    read_mask = 0xFFFFFFFF,
                    write_mask = 0xFFFFFFFF,
                },
            },
            multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
        },
    )

    self.uniform_buffer = gpu.device_create_buffer(
        self.device,
        {
            label = EXAMPLE_TITLE + " Uniform Buffer",
            size  = 4 * 16, // 4x4 matrix
            usage = {.Uniform, .Copy_Dst},
        },
    )

    self.uniform_bind_group = gpu.device_create_bind_group(
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
        view = nil, /* Assigned later */
        ops  = { .Clear, .Store, COLOR_DARK_GRAY },
    }

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = &self.rpass.depth_stencil_attachment,
    }

    create_depth_stencil_texture(self, self.config.width, self.config.height)

    set_projection_matrix(self, self.config.width, self.config.height)

    return .Continue
}

update :: proc(self: ^Application) {
    transformation_matrix := get_transformation_matrix(self)
    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(transformation_matrix),
    )
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    update(self)

    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.release(encoder)

    self.rpass.colors[0].view = frame.view
    render_pass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.release(render_pass)

    gpu.render_pass_set_pipeline(render_pass, self.render_pipeline)
    gpu.render_pass_set_bind_group(render_pass, 0, self.uniform_bind_group)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, self.vertex_buffer)
    gpu.render_pass_set_index_buffer(render_pass, self.index_buffer, .Uint16)
    gpu.render_pass_draw_indexed(render_pass, {0, u32(len(CUBE_INDICES_DATA))}, 0)

    gpu.render_pass_end(render_pass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.release(cmdbuf)

    gpu.queue_submit(self.queue, { cmdbuf })
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
    app.release_depth_stencil_texture(self.depth_texture)

    gpu.release(self.uniform_bind_group)
    gpu.release(self.uniform_buffer)
    gpu.release(self.render_pipeline)
    gpu.release(self.index_buffer)
    gpu.release(self.vertex_buffer)

    free(self)
}

resize :: proc(self: ^Application, width, height: u32) {
    recreate_depth_stencil_texture(self, width, height)
    set_projection_matrix(self, width, height)
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

set_projection_matrix :: proc(self: ^Application, width, height: u32) {
    aspect := f32(width) / f32(height)
    self.projection_matrix = la.matrix4_perspective(2 * math.PI / 5, aspect, 1, 100.0)
}

get_transformation_matrix :: proc(self: ^Application) -> (mvp_mat: la.Matrix4f32) {
    view_matrix := la.MATRIX4F32_IDENTITY

    // Translate
    translation := la.Vector3f32{0, 0, -4}
    view_matrix = la.matrix_mul(view_matrix, la.matrix4_translate(translation))

    // Rotate
    now := f32(app.get_time())
    rotation_axis := la.Vector3f32{math.sin(now), math.cos(now), 0}
    rotation_matrix := la.matrix4_rotate(1, rotation_axis)
    view_matrix = la.matrix_mul(view_matrix, rotation_matrix)

    // Multiply projection and view matrices
    mvp_mat = la.matrix_mul(self.projection_matrix, view_matrix)

    return
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
