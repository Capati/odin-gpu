/*
Example - Clear Screen

This example shows how to set up a color target to clear the screen.
*/
package clear_screen

// Core
import "core:log"
import "core:math"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Clear Screen"
CLIENT_WIDTH :: 640
CLIENT_HEIGHT :: 480

State :: struct {
    clear_value: gpu.Color,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.clear_value = {0.0, 0.0, 0.0, 1.0}
    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = { .Clear, .Store, state.clear_value },
    }

    state.rpass.descriptor = {
        label             = "Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    return true
}

quit :: proc(ctx: ^app.Application) {
}

update :: proc(ctx: ^app.Application, dt: f32) {
    current_time := app.get_time()
    color := [4]f64 {
        math.sin(f64(current_time)) * 0.5 + 0.5,
        math.cos(f64(current_time)) * 0.5 + 0.5,
        0.0,
        1.0,
    }
    state.rpass.colors[0].ops.clear_value = color
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip {return}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_present(ctx.surface)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
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
