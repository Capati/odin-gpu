/*
Example - Square

This example shows how to render a static colored square with only using
vertex buffers.

Ref:

- https://github.com/cx20/webgpu-test/tree/master/examples/webgpu_wgsl/square
- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/square.c
*/
package square

// Core
import "core:log"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Colored Square"
CLIENT_WIDTH :: 640
CLIENT_HEIGHT :: 480

State :: struct {
    positions_buffer: gpu.Buffer,
    colors_buffer:    gpu.Buffer,
    render_pipeline:  gpu.Render_Pipeline,

    // Cache the render pass descriptor
    rpass:            struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

// Square data
//             1.0 y
//              ^  -1.0
//              | / z
//              |/       x
// -1.0 -----------------> +1.0
//            / |
//      +1.0 /  |
//           -1.0
//
//        [0]------[1]
//         |        |
//         |        |
//         |        |
//        [2]------[3]
//
@(rodata)
POSITIONS := []f32 {
    -0.5,  0.5, 0.0, // v0
     0.5,  0.5, 0.0, // v1
    -0.5, -0.5, 0.0, // v2
     0.5, -0.5, 0.0, // v3
}

@(rodata)
COLORS := []f32 {
    1.0, 0.0, 0.0, 1.0, // v0
    0.0, 1.0, 0.0, 1.0, // v1
    0.0, 0.0, 1.0, 1.0, // v2
    1.0, 1.0, 0.0, 1.0, // v3
}

init_vertex_buffers :: proc(ctx: ^app.Application) {
    // Create the positions vertex buffer
    positions_buffer_desc := gpu.Buffer_Data_Descriptor {
        label = "Colored square - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }
    state.positions_buffer = gpu.device_create_buffer_with_data(
        ctx.device, positions_buffer_desc, POSITIONS)

    // Create the colors vertex buffer
    colors_buffer_desc := gpu.Buffer_Data_Descriptor {
        label = "Colored square - Colors buffer",
        usage = {.Vertex, .Copy_Dst},
    }
    state.colors_buffer = gpu.device_create_buffer_with_data(
        ctx.device, colors_buffer_desc, COLORS)
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "square"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    // Create the render pipeline
    state.render_pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = TITLE + " Render Pipeline",
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = 3 * 4,
                    step_mode = .Vertex,
                    attributes = {{shader_location = 0, format = .Float32x3, offset = 0}},
                },
                {
                    array_stride = 4 * 4,
                    step_mode = .Vertex,
                    attributes = {{shader_location = 1, format = .Float32x4, offset = 0}},
                },
            },
        },
        fragment = &gpu.Fragment_State {
            module = frag_shader_module,
            entry_point = "fs_main",
            targets = {
                {
                    format = ctx.config.format,
                    blend = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_Strip,
            strip_index_format = .Uint32,
            front_face = .CCW,
            cull_mode = .Front,
        },
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    init_vertex_buffers(ctx)
    init_pipeline(ctx)

    // Cache render pass descriptor
    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = { .Clear, .Store, gpu.COLOR_BLACK },
    }

    state.rpass.descriptor = {
        label             = "Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
}

quit :: proc(ctx: ^app.Application) {
    gpu.buffer_release(state.colors_buffer)
    gpu.buffer_release(state.positions_buffer)
    gpu.render_pipeline_release(state.render_pipeline)
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    frame := app.get_current_frame()
    if frame.skip {return}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    // Sets the active render pipeline
    gpu.render_pass_set_pipeline(rpass, state.render_pipeline)

    // Bind vertex buffers (contain position & colors)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.positions_buffer)
    gpu.render_pass_set_vertex_buffer(rpass, 1, state.colors_buffer)

    // Draw quad
    gpu.render_pass_draw(rpass, 4, 1, 0, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = {.Level, .Terminal_Color},
        )
        defer log.destroy_console_logger(context.logger)

        when ODIN_OS != .JS {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)

            defer {
                if len(track.allocation_map) > 0 {
                    log.errorf("=== %v allocations not freed: ===", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        log.warnf("- %v bytes @ %v", entry.size, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }
    }

    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
