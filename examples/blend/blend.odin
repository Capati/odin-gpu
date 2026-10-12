/*
Example - Blend

This example shows blending in sRGB or linear space.
*/
package blend

// Core
import "core:log"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Blend"
CLIENT_WIDTH :: 800
CLIENT_HEIGHT :: 600

State :: struct {
    vertex_buffer: gpu.Buffer,
    index_buffer: gpu.Buffer,
    render_pipeline: gpu.Render_Pipeline,
    index_count: u32,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

Vertex :: struct {
    pos:   [4]f32,
    color: [4]f32,
}

VERTEX_COUNT :: 4 * 2
INDEX_COUNT  :: 6 * 2

init_vertex_buffers :: proc(ctx: ^app.Application) {
    // Generate two quads
    vertex_data: [VERTEX_COUNT]Vertex
    index_data: [INDEX_COUNT]u16

    scale : f32 = 0.5

    Quad :: struct {
        color:  [4]f32,
        offset: f32,
    }

    quads := [2]Quad{
        {color = {1.0, 0.0, 0.0, 0.5}, offset =  0.5}, // red
        {color = {0.0, 0.0, 1.0, 0.5}, offset = -0.5}, // blue
    }

    positions := [4][2]f32{{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}
    quad_indices := [6]u16{0, 1, 2, 2, 3, 0}

    for q, qi in quads {
        base_v := qi * 4
        base_i := qi * 6

        for p, pi in positions {
            vertex_data[base_v + pi] = Vertex{
                pos = {
                    (p[0] + q.offset) * scale,
                    (p[1] + q.offset) * scale,
                    0.0,
                    1.0,
                },
                color = q.color,
            }
        }

        for idx, ii in quad_indices {
            index_data[base_i + ii] = u16(base_v) + idx
        }
    }

    state.vertex_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, vertex_data[:])

    state.index_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Index buffer",
        usage = {.Index, .Copy_Dst},
    }, index_data[:])
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "blend"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    state.render_pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = TITLE + " Render Pipeline",
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        {format = .Float32x4, offset = 0, shader_location = 0},
                        {
                            format = .Float32x4,
                            offset = u64(offset_of(Vertex, color)),
                            shader_location = 1,
                        },
                    },
                },
            },
        },
        fragment = &gpu.Fragment_State {
            module = frag_shader_module,
            entry_point = "fs_main",
            targets = {
                {
                    format = ctx.config.format,
                    blend = &gpu.BLEND_STATE_ALPHA_BLENDING, // !
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_List,
            front_face = .CCW,
            cull_mode = .None,
        },
        multisample = gpu.DEFAULT_MULTISAMPLE_STATE,
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = gpu.COLOR_BLACK,
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render Pass",
        color_attachments = state.rpass.colors[:],
    }

    init_vertex_buffers(ctx)
    init_pipeline(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    gpu.render_pipeline_release(state.render_pipeline)
    gpu.buffer_release(state.vertex_buffer)
    gpu.buffer_release(state.index_buffer)
}

update :: proc(ctx: ^app.Application, dt: f32) {
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip { return true }
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    // Sets the active render pipeline
    gpu.render_pass_set_pipeline(rpass, state.render_pipeline)

    // Bind vertex buffers and index buffer
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertex_buffer)
    gpu.render_pass_set_index_buffer(rpass, state.index_buffer, .Uint16, 0, gpu.WHOLE_SIZE)

    // Draw quads
    gpu.render_pass_draw_indexed(rpass, INDEX_COUNT, 1, 0, 0, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    #partial switch ev in event {
        case app.Resize_Event:
            resize(ctx, ev.width, ev.height)
    }
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
        width      = CLIENT_WIDTH,
        height     = CLIENT_HEIGHT,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
