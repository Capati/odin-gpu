package application

// Core
import "base:runtime"
import "core:log"
import "core:slice"
import "core:strings"

// Local packages
import "../../gpu"

ASSETS_DIR :: "assets/"

// Force srgb when configuring the surface.
USE_SRGB :: #config(USE_SRGB, false)

DEFAULT_WINDOW_WIDTH  :: 1280
DEFAULT_WINDOW_HEIGHT :: 720

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
    // Target frame rate for time-based frame pacing. The loop sleeps the remainder of each
    // frame budget after iterating. 0 (default) means uncapped.
    target_fps:        u32,
}

Application :: struct {
    desc:               Application_Descriptor,
    width:              u32,
    height:             u32,
    exit_key:           Key,
    info:               gpu.Adapter_Info,
    caps:               gpu.Surface_Capabilities,
    config:             gpu.Surface_Configuration,
    instance:           gpu.Instance,
    adapter:            gpu.Adapter,
    device:             gpu.Device,
    queue:              gpu.Queue,
    surface:            gpu.Surface,
    render_format:      gpu.Texture_Format,
    msaa_tex:           gpu.Texture,
    depth_stencil_tex:  gpu.Texture,
    depth_stencil_fmt:  gpu.Texture_Format,
    swapchain_view:     gpu.Texture_View,
    msaa_view:          gpu.Texture_View,
    depth_stencil_view: gpu.Texture_View,
    mipmap_generator:   rawptr,
    os:                 OS,
    custom_ctx:         runtime.Context,
    allocator:          runtime.Allocator,
    initialized:        bool,
    is_minimized:       bool,
}

@(private)
g_ctx: Application

run :: proc(
    desc: Application_Descriptor,
    allocator := context.allocator,
    loc := #caller_location,
) {
    assert(desc.init_cb != nil, "init_cb must not be nil", loc)
    assert(desc.iterate_cb != nil, "iterate_cb must not be nil", loc)
    assert(desc.quit_cb != nil, "quit_cb must not be nil", loc)
    assert(desc.title != "", "title must not be empty", loc)

    g_ctx.custom_ctx = context
    g_ctx.allocator = allocator

    g_ctx.desc              = desc
    g_ctx.width             = desc.width  if desc.width  != 0 else DEFAULT_WINDOW_WIDTH
    g_ctx.height            = desc.height if desc.height != 0 else DEFAULT_WINDOW_HEIGHT
    g_ctx.desc.sample_count = desc.sample_count if desc.sample_count != 0 else 1

    // Create window
    os_init(desc.title, g_ctx.width, g_ctx.height)

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

    g_ctx.instance = gpu.create_instance(allocator, instance_descriptor)

    // Create a platform surface
    g_ctx.surface = window_get_gpu_surface(g_ctx.instance, loc)

    // Create the adapter
    adapter_options := gpu.Request_Adapter_Options {
        power_preference       = .High_Performance,
        force_fallback_adapter = false,
        compatible_surface     = g_ctx.surface,
    }

    g_ctx.adapter = gpu.instance_create_adapter(g_ctx.instance, adapter_options)
    assert(g_ctx.adapter != {})

    // Get information about the selected adapter
    g_ctx.info = gpu.adapter_get_info(g_ctx.adapter, g_ctx.allocator)

    log.debug("Selected adapter:")
    log_adapter_info(g_ctx.info)

    // Get surface capabilities supported by this surface and adapter
    g_ctx.caps = gpu.surface_get_capabilities(g_ctx.surface, g_ctx.adapter)

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

    // Get the default queue
    g_ctx.queue = gpu.device_get_queue(g_ctx.device)

    // Get optimal present mode
    present_mode := gpu.Present_Mode.Fifo
    if slice.contains(g_ctx.caps.present_modes, gpu.Present_Mode.Mailbox) {
        present_mode = .Mailbox // TODO
    }

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

    // Create final surface configuration
    g_ctx.config = gpu.Surface_Configuration {
        device                        = g_ctx.device,
        usage                         = {.Render_Attachment, .Copy_Src, .Copy_Dst},
        format                        = preferred_format,
        width                         = width,
        height                        = height,
        present_mode                  = present_mode,
        desired_maximum_frame_latency = 2,
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

quit :: proc() {
    context = g_ctx.custom_ctx

    log.debug("Exiting...")

    hide_window()

    // Release user context
    if g_ctx.desc.quit_cb != nil {
        g_ctx.desc.quit_cb(&g_ctx)
    }

    // Release GPU context
    gpu.surface_capabilities_free_members(g_ctx.caps)
    gpu.adapter_info_free_members(g_ctx.info)
    gpu.adapter_release(g_ctx.adapter)
    gpu.surface_release(g_ctx.surface)
    gpu.queue_release(g_ctx.queue)
    gpu.device_release(g_ctx.device)
    gpu.instance_release(g_ctx.instance)

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
