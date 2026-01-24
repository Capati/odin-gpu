package blend

// Core
import "base:runtime"
import "core:log"
import "core:mem"

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"

CLIENT_WIDTH  :: 640
CLIENT_HEIGHT :: 480
EXAMPLE_TITLE :: "Blend"

Application :: struct {
    using gc:        app.GPU_Context,

    vertex_buf:      gpu.Buffer,
    index_buf:       gpu.Buffer,
    render_pipeline: gpu.Render_Pipeline,
    index_count:     u32,

    // Cache the render pass descriptor
    rpass:           struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

Vertex :: struct {
    pos:   [4]f32,
    color: [4]f32,
}

vertex :: #force_inline proc "contextless" (pos: [2]f32, color: [4]f32, offset: f32) -> Vertex {
    scale : f32 = 0.5
    return {
        pos = {
            (pos[0] + offset) * scale,
            (pos[1] + offset) * scale,
            0.0,
            1.0,
        },
        color = color,
    }
}

quad :: proc(vertices: ^[dynamic]Vertex, indices: ^[dynamic]u16, color: [4]f32, offset: f32) {
    base := u16(len(vertices))

    append(vertices,
        vertex({-1, -1}, color, offset),
        vertex({ 1, -1}, color, offset),
        vertex({ 1,  1}, color, offset),
        vertex({-1,  1}, color, offset),
    )

    quad_indices := [6]u16{0, 1, 2, 2, 3, 0}
    for i in quad_indices {
        append(indices, base + i)
    }
}

create_vertices :: proc(allocator := context.allocator) -> ([]Vertex, []u16) {
    vertices := make([dynamic]Vertex, allocator)
    indices := make([dynamic]u16, allocator)

    red  := [4]f32{1.0, 0.0, 0.0, 0.5}
    blue := [4]f32{0.0, 0.0, 1.0, 0.5}

    quad(&vertices, &indices, red, 0.5)
    quad(&vertices, &indices, blue, -0.5)

    return vertices[:], indices[:]
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vertex_data, index_data := create_vertices(ta)

    self.vertex_buf = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Vertex buffer",
            usage = { .Vertex },
        },
        vertex_data[:],
    )

    self.index_buf = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Index buffer",
            usage = { .Index },
        },
        index_data[:],
    )

    // Load and create a vertex shader module
    vertex_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Vertex Shader",
            code = shaders.load(self.device, .Vertex),
            stage = .Vertex,
        },
    )
    defer gpu.shader_module_release(vertex_shader)

    // Load and create a fragment shader module
    fragment_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Fragment Shader",
            code = shaders.load(self.device, .Fragment),
            stage = .Fragment,
        },
    )
    defer gpu.shader_module_release(fragment_shader)

    pipeline_descriptor := gpu.Render_Pipeline_Descriptor {
        label = EXAMPLE_TITLE + " Render Pipeline",
        vertex = {
            module = vertex_shader,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        {
                            shader_location = 0,
                            format = .Float32x4,
                            offset = 0,
                        },
                        {
                            shader_location = 1,
                            format = .Float32x4,
                            offset = u64(offset_of(Vertex, color)),
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
                    blend = &gpu.BLEND_STATE_ALPHA_BLENDING, // !
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_List,
            front_face = .Ccw,
            cull_mode = .Back,
        },
        multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
    }

    // Create the triangle pipeline
    self.render_pipeline =
        gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops  = { .Clear, .Store, { 0.0, 0.0, 0.0, 1.0 } },
    }

    self.rpass.descriptor = {
        label             = "Render pass descriptor",
        color_attachments = self.rpass.colors[:],
    }

    self.index_count = u32(len(index_data))

    return .Continue
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    // Creates an empty command encoder
    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.command_encoder_release(encoder)

    // Begins recording of a render pass
    self.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    // Sets the active render pipeline
    gpu.render_pass_set_pipeline(rpass, self.render_pipeline)

    // Bind vertex buffers and index buffer
    gpu.render_pass_set_vertex_buffer(rpass, 0, self.vertex_buf)
    gpu.render_pass_set_index_buffer(rpass, self.index_buf, .Uint16)

    // Draw quads
    gpu.render_pass_draw_indexed(rpass, {0, self.index_count}, 0)

    // Record the end of the render pass
    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (res: app.App_Result) {
    return .Continue
}

quit :: proc(self: ^Application, res: app.App_Result) {
    gpu.release(self.render_pipeline)
    gpu.release(self.index_buf)
    gpu.release(self.vertex_buf)
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
