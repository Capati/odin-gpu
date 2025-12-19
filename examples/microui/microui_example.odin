package microui_example

// Core
import "core:log"
import "core:mem"

// Vendor
import mu "vendor:microui"

// Local packages
import gpu "../../"
import gpu_mu "../../utils/microui"
import app "../framework"

CLIENT_WIDTH  :: 800
CLIENT_HEIGHT :: 600
EXAMPLE_TITLE :: "MicroUI Example"

Application :: struct {
    using gc:        app.GPU_Context,
    mu_ctx:          ^mu.Context,
    log_buf:         [64000]u8,
    log_buf_len:     int,
    log_buf_updated: bool,
    bg:              mu.Color,
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    mu_init_info := gpu_mu.MICROUI_INIT_INFO_DEFAULT
    mu_init_info.device = self.device
    mu_init_info.format = self.config.format
    mu_init_info.width = self.config.width
    mu_init_info.height = self.config.height

    self.mu_ctx = new(mu.Context)
    mu.init(self.mu_ctx)
    self.mu_ctx.text_width = mu.default_atlas_text_width
    self.mu_ctx.text_height = mu.default_atlas_text_height

    // Initialize MicroUI renderer
    gpu_mu.init(mu_init_info)

    // Set initial state
    self.bg = {56, 130, 210, 255}

    return .Continue
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    mu_update(self)

    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.release(encoder)

    color_attachment := gpu.Render_Pass_Color_Attachment {
        view = frame.view,
        ops  = {.Clear, .Store, get_color_from_mu_color(self.bg)},
    }

    rpass_desc := gpu.Render_Pass_Descriptor {
        label             = "MicroUI Render Pass",
        color_attachments = {color_attachment},
    }

    rpass := gpu.command_encoder_begin_render_pass(encoder, rpass_desc)
    defer gpu.release(rpass)

    gpu_mu.begin(rpass)
    gpu_mu.render(self.mu_ctx)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (res: app.App_Result) {
    app.mu_handle_events(self.mu_ctx, event)
    #partial switch &ev in event {
    case app.Resize_Event:
        resize(self, ev.width, ev.height)
    }
    return .Continue
}

quit :: proc(self: ^Application, res: app.App_Result) {
    gpu_mu.destroy()
    free(self.mu_ctx)
    free(self)
}

resize :: proc(self: ^Application, width, height: u32) {
    gpu_mu.resize(width, height)
}

get_color_from_mu_color :: proc(color: mu.Color) -> gpu.Color {
    return {
        f64(color.r) / 255.0,
        f64(color.g) / 255.0,
        f64(color.b) / 255.0,
        1.0,
    }
}

mu_update :: proc(self: ^Application) {
    // UI definition
    mu.begin(self.mu_ctx)
    test_window(self, self.mu_ctx)
    log_window(self, self.mu_ctx)
    style_window(self, self.mu_ctx)
    mu.end(self.mu_ctx)
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
