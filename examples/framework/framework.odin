package application

// Core
import "base:runtime"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"

// Local packages
import "../../gpu"

ASSETS_DIR :: "assets/"

// Force srgb when configuring the surface.
USE_SRGB :: #config(USE_SRGB, false)

DEFAULT_WINDOW_WIDTH  :: 1280
DEFAULT_WINDOW_HEIGHT :: 720

// Returns false to abort startup, anything allocated before returning false
// must be released by `init_cb` itself.
App_Init_Proc    :: #type proc(ctx: ^Application) -> bool
App_Iterate_Proc :: #type proc(ctx: ^Application, dt: f32) -> bool
App_Event_Proc   :: #type proc(ctx: ^Application, event: Event)
App_Quit_Proc    :: #type proc(ctx: ^Application)

Application_Settings :: struct {
    power_preference:  gpu.Power_Preference,
    required_features: []gpu.Feature_Name,
    requried_limits:   gpu.Limits,
}

DEFAULT_CONTEXT_SETTINGS :: Application_Settings {
    power_preference  = .High_Performance,
    required_features = {},
    requried_limits   = gpu.DEFAULT_LIMITS,
}

Application_Descriptor :: struct {
    width:             u32,
    height:            u32,
    sample_count:      u32,
    no_depth_buffer:   bool,
    title:             string,
    init_cb:           App_Init_Proc,
    iterate_cb:        App_Iterate_Proc,
    quit_cb:           App_Quit_Proc,
    event_cb:          App_Event_Proc,
    required_features: []gpu.Feature_Name,
    required_limits:   gpu.Limits,
    // Target frame rate for CPU frame pacing. 0 (default) means uncapped.
    target_fps:        u32,
    // Requested present mode. Fifo is guaranteed.
    present_mode:      gpu.Present_Mode,
    // Desired maximum number of frames in flight, always clamped by the
    // backend.
    max_frame_latency: u32,
}

Application :: struct {
    desc:                Application_Descriptor,
    width:               u32,
    height:              u32,
    exit_key:            Key,
    info:                gpu.Adapter_Info,
    caps:                gpu.Surface_Capabilities,
    config:              gpu.Surface_Configuration,
    instance:            gpu.Instance,
    adapter:             gpu.Adapter,
    device:              gpu.Device,
    queue:               gpu.Queue,
    surface:             gpu.Surface,
    render_format:       gpu.Texture_Format,
    msaa_tex:            gpu.Texture,
    depth_stencil_tex:   gpu.Texture,
    depth_stencil_fmt:   gpu.Texture_Format,
    swapchain_view:      gpu.Texture_View,
    msaa_view:           gpu.Texture_View,
    depth_stencil_view:  gpu.Texture_View,
    mipmap_generator:    rawptr,
    os:                  OS,
    custom_ctx:          runtime.Context,
    allocator:           runtime.Allocator,
    track:               mem.Tracking_Allocator,
    debug_teardown_done: bool,
    initialized:         bool,
    is_minimized:        bool,
    quit_done:           bool,
}

@(private)
g_ctx: Application

run :: proc(
    desc: Application_Descriptor,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    ok: bool,
) {
    assert(desc.init_cb != nil, "init_cb must not be nil", loc)
    assert(desc.iterate_cb != nil, "iterate_cb must not be nil", loc)
    assert(desc.quit_cb != nil, "quit_cb must not be nil", loc)
    assert(desc.title != "", "title must not be empty", loc)

    // Reset the lifecycle flags so a second `run` after a `quit` (or a failed
    // startup) starts from a clean state.
    g_ctx.initialized = false
    g_ctx.quit_done = false
    g_ctx.debug_teardown_done = false

    g_ctx.allocator = allocator

    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = {.Level, .Terminal_Color},
            allocator = allocator,
        )

        when ODIN_OS != .JS {
            mem.tracking_allocator_init(&g_ctx.track, allocator)
            context.allocator = mem.tracking_allocator(&g_ctx.track)
        }

        // Paired with `teardown_debug`, which `quit` calls on a successful run.
        // The cleanup has to happen here too when startup fails before the
        // frame loop starts.
        defer if !ok {teardown_debug()}
    }

    g_ctx.custom_ctx = context

    g_ctx.desc = desc
    g_ctx.width = desc.width if desc.width != 0 else DEFAULT_WINDOW_WIDTH
    g_ctx.height = desc.height if desc.height != 0 else DEFAULT_WINDOW_HEIGHT
    g_ctx.desc.sample_count = desc.sample_count if desc.sample_count != 0 else 1

    // Create window
    os_init(desc.title, g_ctx.width, g_ctx.height)
    defer if !ok {os_quit()}

    when ODIN_DEBUG {
        g_ctx.exit_key = .Escape
    }

    // Create the instance
    instance_descriptor: gpu.Instance_Descriptor

    when ODIN_DEBUG {
        instance_descriptor.flags = {.Debug, .Validation}
    }

    when ODIN_OS == .JS {
        instance_descriptor.display = gpu.HTML_Canvas_Handle {
            selector = DEFAULT_CANVAS_ID,
        }
    }

    g_ctx.instance = gpu.create_instance(g_ctx.allocator, instance_descriptor)
    if g_ctx.instance == nil {
        log.error("Failed to create the GPU instance")
        return
    }
    defer if !ok {gpu.instance_release(g_ctx.instance)}

    // Create a platform surface
    g_ctx.surface = window_get_gpu_surface(g_ctx.instance, loc)
    if g_ctx.surface == nil {
        log.error("Failed to create the GPU surface")
        return
    }
    defer if !ok {gpu.surface_release(g_ctx.surface)}

    // Create the adapter
    adapter_options := gpu.Request_Adapter_Options {
        power_preference       = .High_Performance,
        force_fallback_adapter = false,
        compatible_surface     = g_ctx.surface,
    }

    g_ctx.adapter = gpu.instance_create_adapter(g_ctx.instance, adapter_options)
    if g_ctx.adapter == nil {
        log.error("No compatible GPU adapter")
        return
    }
    defer if !ok {gpu.adapter_release(g_ctx.adapter)}

    // Get information about the selected adapter
    g_ctx.info = gpu.adapter_get_info(g_ctx.adapter, g_ctx.allocator)
    defer if !ok {gpu.adapter_info_free_members(g_ctx.info, g_ctx.allocator)}

    log.debug("Selected adapter:")
    log_adapter_info(g_ctx.info)

    // Get surface capabilities supported by this surface and adapter
    g_ctx.caps = gpu.surface_get_capabilities(g_ctx.surface, g_ctx.adapter, g_ctx.allocator)
    defer if !ok {gpu.surface_capabilities_free_members(g_ctx.caps, g_ctx.allocator)}

    if len(g_ctx.caps.formats) == 0 {
        log.error("Surface reports no supported formats")
        return
    }

    lost_callback_info := gpu.Device_Lost_Callback_Info {
        callback = device_lost_callback,
    }

    uncaptured_error_callback_info := gpu.Uncaptured_Error_Callback_Info {
        callback = uncaptured_error_callback,
    }

    required_limits := g_ctx.desc.required_limits
    if required_limits == {} {
        required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS
    }

    // Create the logical device
    g_ctx.device = gpu.adapter_create_device(g_ctx.adapter, {
        required_features              = g_ctx.desc.required_features,
        required_limits                = required_limits,
        default_queue                  = {},
        lost_callback_info             = lost_callback_info,
        uncaptured_error_callback_info = uncaptured_error_callback_info,
    })
    if g_ctx.device == nil {
        log.error("Failed to create the GPU device")
        return
    }
    defer if !ok {gpu.device_release(g_ctx.device)}

    // Get the default queue
    g_ctx.queue = gpu.device_get_queue(g_ctx.device)
    if g_ctx.queue == {} {
        log.error("Failed to get the default GPU queue")
        return
    }
    defer if !ok {gpu.queue_release(g_ctx.queue)}

    // Resolve requested present mode.
    present_mode := resolve_present_mode(g_ctx.desc.present_mode, g_ctx.caps.present_modes)

    // Use first available format as the preferred one
    preferred_format := g_ctx.caps.formats[0]
    when USE_SRGB && ODIN_OS != .JS {
        log.info("sRGB enabled")
        preferred_format = gpu.texture_format_add_srgb_suffix(preferred_format)
    } else {
        preferred_format = gpu.texture_format_remove_srgb_suffix(preferred_format)
    }

    width, height := get_framebuffer_size()

    // Use the full size in the web
    when ODIN_OS == .JS {
        g_ctx.width = width
        g_ctx.height = height
    }

    // Frame latency defaults to 2 (balanced latency/throughput); 0 means default.
    frame_latency :=
        max(g_ctx.desc.max_frame_latency, 1) if g_ctx.desc.max_frame_latency != 0 else 2
    log.infof("Present mode %v, max frame latency %d", present_mode, frame_latency)

    // Create final surface configuration
    g_ctx.config = gpu.Surface_Configuration {
        device                        = g_ctx.device,
        usage                         = {.Render_Attachment, .Copy_Src, .Copy_Dst},
        format                        = preferred_format,
        width                         = width,
        height                        = height,
        present_mode                  = present_mode,
        desired_maximum_frame_latency = frame_latency,
        alpha_mode                    = .Opaque,
    }

    // when ODIN_OS == .JS {
    //     g_ctx.config.view_formats = {
    //         gpu.texture_format_add_srgb_suffix(preferred_format)
    //     }
    // }

    gpu.surface_configure(g_ctx.surface, g_ctx.config)

    g_ctx.render_format = preferred_format

    when gpu.USE_SLANG {
        log.info("Slang enabled")
    }

    if g_ctx.desc.init_cb != nil && !g_ctx.desc.init_cb(&g_ctx) {
        log.fatal("[init_proc]: Failed to initialize")
        return
    }

    g_ctx.initialized = true

    os_run()

    return true
}

// Resolves the requested present mode against supported modes. Fifo is the default
// and is guaranteed by the spec. Auto modes degrade to the first supported
// concrete mode.
@(private)
resolve_present_mode :: proc(
    requested: gpu.Present_Mode,
    supported: []gpu.Present_Mode,
) -> gpu.Present_Mode {
    // Browsers ignore present mode; skip validation when nothing is reported.
    if len(supported) == 0 {
        return .Fifo
    }

    candidates: [4]gpu.Present_Mode
    n := 0
    #partial switch requested {
    case .Auto_Vsync:
        candidates = {.Fifo_Relaxed, .Fifo, {}, {}}
        n = 2
    case .Auto_No_Vsync:
        candidates = {.Immediate, .Mailbox, .Fifo, {}}
        n = 3
    case:
        candidates = {requested, .Fifo, {}, {}}
        n = 2
    }
    for i in 0 ..< n {
        if slice.contains(supported, candidates[i]) {
            if candidates[i] != requested {
                log.warnf("Present mode %v unsupported, using %v", requested, candidates[i])
            }
            return candidates[i]
        }
    }
    log.warnf("Requested present mode %v unsupported, falling back to Fifo", requested)
    return .Fifo
}

device_lost_callback :: proc "contextless" (
    device: ^gpu.Device,
    reason: gpu.Device_Lost_Reason,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = g_ctx.custom_ctx
    log.error(message)
}

uncaptured_error_callback :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = g_ctx.custom_ctx
    log.error(message)
}

// Tears down the debug-only logger and tracking allocator. `run` owns them on
// startup failure; `quit` owns them on a normal exit. The flag makes the call
// idempotent so calling `quit` after a failed `run` is harmless.
@(private)
teardown_debug :: proc() {
    when ODIN_DEBUG {
        if g_ctx.debug_teardown_done {
            return
        }
        g_ctx.debug_teardown_done = true

        when ODIN_OS != .JS {
            if len(g_ctx.track.allocation_map) > 0 {
                log.errorf("=== %v allocations not freed: ===", len(g_ctx.track.allocation_map))
                for _, entry in g_ctx.track.allocation_map {
                    log.warnf("- %v bytes @ %v", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&g_ctx.track)
        }

        log.destroy_console_logger(context.logger, g_ctx.allocator)

        // The saved context must not keep pointing at the freed tracker. Its
        // logger is dead too, so nothing may log through `custom_ctx` after
        // this point.
        g_ctx.custom_ctx.allocator = g_ctx.allocator
    }
}

quit :: proc() {
    // The frame loop calls this once, but user code may call it again. Also
    // guards the JS path, where a repeated runtime step would otherwise run
    // against released objects.
    if g_ctx.quit_done do return
    g_ctx.quit_done = true

    context = g_ctx.custom_ctx

    if !g_ctx.debug_teardown_done {
        log.debug("Exiting...")
    }

    defer teardown_debug()

    if !g_ctx.initialized {
        return
    }

    hide_window()

    // Release user context
    if g_ctx.desc.quit_cb != nil {
        g_ctx.desc.quit_cb(&g_ctx)
    }

    // Release GPU context
    gpu.surface_capabilities_free_members(g_ctx.caps, g_ctx.allocator)
    gpu.adapter_info_free_members(g_ctx.info, g_ctx.allocator)
    gpu.adapter_release(g_ctx.adapter)
    gpu.surface_release(g_ctx.surface)
    gpu.queue_release(g_ctx.queue)
    gpu.device_release(g_ctx.device)
    gpu.instance_release(g_ctx.instance)

    g_ctx.initialized = false

    os_quit()
}

set_callbacks :: proc(
    $T: typeid,
    init: proc(appstate: ^^T) -> bool,
    iterate: proc(appstate: ^T, dt: f32) -> bool,
    event: proc(appstate: ^T, event: Event) -> bool,
    quit: proc(appstate: ^T),
) {
    g_ctx.init_proc = auto_cast init
    g_ctx.iterate_proc = auto_cast iterate
    g_ctx.event_proc = auto_cast event
    g_ctx.quit_proc = auto_cast quit
}

Frame_Texture :: struct {
    using base: gpu.Surface_Texture,
    view:       gpu.Texture_View,
    skip:       bool,
}

@(require_results)
get_current_frame :: proc(loc := #caller_location) -> (frame: Frame_Texture) {
    width, height := get_framebuffer_size()
    if width != g_ctx.config.width || height != g_ctx.config.height {
        resize_surface(width, height)
    }

    frame.base = gpu.surface_get_current_texture(g_ctx.surface)

    #partial switch frame.status {
    case .Success:
        // All good

    case .Suboptimal, .Timeout, .Outdated, .Lost:
        // Skip this frame, and re-configure surface.
        release_current_frame(&frame)
        w, h := get_framebuffer_size()
        log.warnf("Swapchain [%v]: resizing to %d×%d...", frame.status, w, h)
        resize_surface(w, h)
        frame.skip = true
        return

    case:
        log.panicf("Failed to acquire surface texture: %v", frame.status, location = loc)
    }

    frame.view = gpu.texture_create_view(frame.texture)

    assert(frame.texture != {}, "Invalid surface texture", loc)
    assert(frame.view != {}, "Invalid surface view", loc)

    return
}

release_current_frame :: proc(self: ^Frame_Texture) {
    // Handles may be unset when acquisition failed
    if self.view != {} {
        gpu.texture_view_release(self.view)
    }
    if self.texture != {} {
        gpu.texture_release(self.texture)
    }
}

resize_surface :: proc(width, height: u32) {
    // Minimized windows report zero size; reconfiguring is impossible
    if width == 0 || height == 0 {
        return
    }

    log.debugf("Resizing surface to %d×%d", width, height)

    g_ctx.width = width
    g_ctx.height = height

    g_ctx.config.width = width
    g_ctx.config.height = height

    // Reconfigure the surface
    gpu.surface_configure(g_ctx.surface, g_ctx.config)
}

log_adapter_info :: proc(info: gpu.Adapter_Info) {
    buf: [512]u8
    sb := strings.builder_from_bytes(buf[:])

    strings.write_string(&sb, info.name if info.name != "" else "Unknown device")
    strings.write_byte(&sb, '\n')

    strings.write_string(&sb, "  - Driver: ")
    if info.driver != "" {
        strings.write_string(&sb, info.driver)
        if info.driver_info != "" {
            strings.write_string(&sb, ", ")
            strings.write_string(&sb, info.driver_info)
        }
    } else if info.driver_info != "" {
        strings.write_string(&sb, info.driver_info)
    } else {
        strings.write_string(&sb, "Unknown")
    }
    strings.write_byte(&sb, '\n')

    device_type: string
    #partial switch info.device_type {
    case .Discrete_Gpu:
        device_type = "Discrete GPU (separate CPU/GPU memory)"
    case .Integrated_Gpu:
        device_type = "Integrated GPU (shared CPU/GPU memory)"
    case .Cpu:
        device_type = "CPU / Software Rendering"
    case:
        device_type = "Unknown"
    }
    strings.write_string(&sb, "  - Type: ")
    strings.write_string(&sb, device_type)
    strings.write_byte(&sb, '\n')

    backend: string
    #partial switch info.backend {
    case .Null:
        backend = "Dummy backend"
    case .WebGPU:
        backend = "WebGPU"
    case .D3D11:
        backend = "Direct3D-11"
    case .D3D12:
        backend = "Direct3D-12"
    case .Metal:
        backend = "Metal"
    case .Vulkan:
        backend = "Vulkan"
    case .OpenGL:
        backend = "OpenGL"
    case .OpenGLES:
        backend = "OpenGLES"
    case:
        backend = "Unknown"
    }
    strings.write_string(&sb, "  - Backend: ")
    strings.write_string(&sb, backend)

    log.info(strings.to_string(sb))
}
