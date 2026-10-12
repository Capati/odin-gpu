/*
Example - MicroUI

Renders a MicroUI user interface using the utils/microui renderer.
*/
package microui_example

// Core
import "core:log"
import "core:mem"

// Vendor
import "../../gpu"
import app "../framework"
import mu "vendor:microui"
import mur "../../utils/microui"

TITLE :: "MicroUI"
CLIENT_WIDTH :: 800
CLIENT_HEIGHT :: 600

State :: struct {
    log_buf:         [64000]u8,
    log_buf_len:     int,
    log_buf_updated: bool,
    clear_value: gpu.Color,
    bg_color: mu.Color,
    mu_ctx: mu.Context,
    mu_renderer: mur.Renderer,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    // Set initial color
    state.bg_color = {56, 130, 210, 255}

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = { .Clear, .Store, get_color_from_mu_color(state.bg_color) },
    }

    state.rpass.descriptor = {
        label             = "Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device = ctx.device,
        target_format = ctx.config.format,
        pipeline_multisample_state = gpu.DEFAULT_MULTISAMPLE_STATE,
    })

    mur.resize(&state.mu_renderer, ctx.config.width, ctx.config.height)

    return true
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
}

get_color_from_mu_color :: #force_inline proc "contextless" (color: mu.Color) -> gpu.Color {
    return {
        f64(color.r) / 255.0,
        f64(color.g) / 255.0,
        f64(color.b) / 255.0,
        1.0,
    }
}

update :: proc(ctx: ^app.Application, dt: f32) {
    // UI definition
    mu.begin(&state.mu_ctx)
    test_window(&state.mu_ctx)
    log_window(&state.mu_ctx)
    style_window(&state.mu_ctx)
    mu.end(&state.mu_ctx)

    // Update state
    state.rpass.colors[0].ops.clear_value = get_color_from_mu_color(state.bg_color)
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

    gpu.render_pass_set_viewport(rpass, 0, 0, f32(ctx.width), f32(ctx.height), 0, 1)
    gpu.render_pass_set_scissor_rect(rpass, 0, 0, ctx.width, ctx.height)

    mur.render(&state.mu_renderer, &state.mu_ctx, rpass)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    mur.resize(&state.mu_renderer, width, height)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.mu_handle_events(&state.mu_ctx, event)
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
