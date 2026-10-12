/*
Example - Template

Just a template to start new examples
*/
package template_example

// Core
import "base:runtime"
import "core:log"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Template"
CLIENT_WIDTH :: 640
CLIENT_HEIGHT :: 480

State :: struct {
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {} // assigned later
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = gpu.COLOR_BLACK,
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render Pass",
        color_attachments = state.rpass.colors[:],
    }

    return true
}

quit :: proc(ctx: ^app.Application) {
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
