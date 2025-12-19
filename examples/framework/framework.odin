package framework

// Core
import "base:runtime"
import "core:log"

// Local packages
import gpu "../../"

App_Result :: enum {
    Continue,
    Success,
    Failure,
}

App_Init_Proc    :: #type proc(appstate: ^rawptr) -> App_Result
App_Iterate_Proc :: #type proc(appstate: rawptr, dt: f32) -> App_Result
App_Event_Proc   :: #type proc(appstate: rawptr, event: Event) -> App_Result
App_Quit_Proc    :: #type proc(appstate: rawptr, result: App_Result)

init_proc:    App_Init_Proc
iterate_proc: App_Iterate_Proc
event_proc:   App_Event_Proc
quit_proc:    App_Quit_Proc

Input_Action :: enum {
    None,
    Pressed,
    Released,
}

Quit_Event :: struct {}

Resize_Event :: struct {
    width, height: u32,
}

Key_Event :: struct {
    key:      Key,
    scancode: Scancode,
    ctrl:     bool,
    shift:    bool,
    alt:      bool,
}

Key_Pressed_Event :: distinct Key_Event

Key_Released_Event :: distinct Key_Event

Mouse_Button_Event :: struct {
    button: Mouse_Button,
    pos:    [2]f32,
}

Char_Event :: struct {
    bytes: [4]u8,
    size:  int,
}

Mouse_Button_Pressed_Event :: distinct Mouse_Button_Event

Mouse_Button_Released_Event :: distinct Mouse_Button_Event

Mouse_Wheel_Event :: [2]f32

Mouse_Moved_Event :: struct {
    pos:    [2]f32,
    button: Mouse_Button,
    action: Input_Action,
}

Minimized_Event :: struct {
    minimized: bool,
}

Restored_Event :: struct {
    restored: bool,
}

Event :: union {
    Quit_Event,
    Resize_Event,
    Key_Pressed_Event,
    Key_Released_Event,
    Char_Event,
    Mouse_Button_Pressed_Event,
    Mouse_Button_Released_Event,
    Mouse_Wheel_Event,
    Mouse_Moved_Event,
    Minimized_Event,
    Restored_Event,
}

GPU_Context :: struct {
    instance: gpu.Instance,
    surface:  gpu.Surface,
    adapter:  gpu.Adapter,
    device:   gpu.Device,
    queue:    gpu.Queue,
    caps:     gpu.Surface_Capabilities,
    config:   gpu.Surface_Configuration,
}

App_Context :: struct {
    // Initialization
    custom_ctx:   runtime.Context,
    appstate:     rawptr,
    allocator:    runtime.Allocator,

    // State
    is_minimized: bool,

    // Platform
    os:           OS,

    // GPU Context
    gc:           GPU_Context,
}

@(private) ctx: App_Context

init :: proc(title: string, width, height: u32, allocator := context.allocator) {
    ctx.custom_ctx = context
    ctx.allocator = allocator

    // Create window
    os_init(title, width, height)

    when ODIN_DEBUG {
        // ctx.exit_key = .Escape
    }

    instance_descriptor: gpu.Instance_Descriptor

    when ODIN_DEBUG {
        instance_descriptor.flags = { .Debug, .Validation }
    }

    ctx.gc.instance = gpu.create_instance(instance_descriptor)
    assert(ctx.gc.instance != nil)

    // Create surface from window
    ctx.gc.surface = window_get_gpu_surface(ctx.gc.instance)
    assert(ctx.gc.surface != nil, "Failed to create GPU surface")

    // Request adapter
    adapter_options := gpu.Request_Adapter_Options {
        compatible_surface     = ctx.gc.surface,
        power_preference       = .High_Performance,
        force_fallback_adapter = false,
    }

    gpu.instance_request_adapter(ctx.gc.instance, adapter_options, { callback = on_adapter })
}

@(private="file")
on_adapter :: proc "c" (
    status: gpu.Request_Adapter_Status,
    adapter: gpu.Adapter,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = ctx.custom_ctx
    if status != .Success || adapter == nil {
        log.panicf("request adapter failure: [%v] %s", status, message)
    }
    ctx.gc.adapter = adapter

    when ODIN_OS != .JS {
        runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
        ta := context.temp_allocator

        adapter_info := gpu.adapter_get_info(adapter)
        defer gpu.adapter_info_free_members(adapter_info)

        log.infof("Selected adapter:\n%s", gpu.adapter_info_string(adapter_info, ta))
    }

    // Request device with specified requirements
    device_descriptor := gpu.Device_Descriptor {
        uncaptured_error_callback_info = {
            callback = on_uncaptured_error_callback,
        },
    }

    gpu.adapter_request_device(adapter, device_descriptor, { callback = on_device })
}

@(private="file")
on_uncaptured_error_callback :: proc "c" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = ctx.custom_ctx
}

@(private="file")
on_device :: proc "c" (
    status: gpu.Request_Device_Status,
    device: gpu.Device,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = ctx.custom_ctx
    if status != .Success || device == nil {
        log.panicf("request device failure: [%v] %s", status, message)
    }
    ctx.gc.device = device
    on_adapter_and_device()
}

@(private="file")
on_adapter_and_device :: proc() {
    // Get default queue
    ctx.gc.queue = gpu.device_get_queue(ctx.gc.device)

    // Get surface capabilities
    ctx.gc.caps = gpu.surface_get_capabilities(ctx.gc.surface, ctx.gc.adapter)

    // Use first available format as the preferred one and remove the srgb if any
    preferred_format := gpu.texture_format_remove_srgb_suffix(ctx.gc.caps.formats[0])

    width, height := get_framebuffer_size()

    // Create final surface configuration
    ctx.gc.config = gpu.Surface_Configuration {
        usage        = { .Render_Attachment },
        format       = preferred_format,
        width        = width,
        height       = height,
        present_mode = .Fifo,
        alpha_mode   = .Auto,
    }

    gpu.surface_configure(ctx.gc.surface, ctx.gc.device, ctx.gc.config)

    if init_proc != nil {
        if res := init_proc(&ctx.appstate); res != .Continue {
            destroy()
            #partial switch res {
            case .Success: return // early exit
            case .Failure:
                log.fatal("Failed to initialize framework")
                return
            }
            return
        }
    }
    run()
}

get_gpu_context :: proc() -> GPU_Context {
    return ctx.gc
}

destroy :: proc() {
    context = ctx.custom_ctx

    // Release GPU Context
    gpu.surface_capabilities_free_members(ctx.gc.caps)
    gpu.release(ctx.gc.queue)
    gpu.release(ctx.gc.device)
    gpu.release(ctx.gc.adapter)
    gpu.release(ctx.gc.surface)
    gpu.release(ctx.gc.instance)

    // Release user context
    if quit_proc != nil {
        quit_proc(ctx.appstate, .Success)
    }
}

dispatch_event :: proc(event: Event) {
    if event_proc != nil {
        event_proc(ctx.appstate, event)
    }
}

Frame_Texture :: struct {
    using base: gpu.Surface_Texture,
    skip:       bool,
    view:       gpu.Texture_View,
}

@(require_results)
get_current_frame :: proc(loc := #caller_location) -> (frame: Frame_Texture) {
    width, height := get_framebuffer_size()
    if width != ctx.gc.config.width || height != ctx.gc.config.height {
        resize_surface(width, height)
    }

    frame.base = gpu.surface_get_current_texture(ctx.gc.surface)

    switch frame.status {
    case .Success_Optimal, .Success_Suboptimal:
        // All good, could handle suboptimal here

    case .Timeout, .Outdated, .Lost:
        // Skip this frame, and re-configure surface.
        release_current_frame(&frame)
        w, h := get_framebuffer_size()
        resize_surface(w, h)
        frame.skip = true
        return

    case .Out_Of_Memory, .Device_Lost, .Error:
        log.panicf("Failed to acquire surface texture: %v", frame.status, location = loc)
    }

    view_descriptor := gpu.Texture_View_Descriptor {
        label = "Frame View",
    }
    frame.view = gpu.texture_create_view(frame.texture, view_descriptor)

    assert(frame.texture != nil, "Invalid surface texture", loc)
    assert(frame.view != nil, "Invalid surface view", loc)

    return
}

release_current_frame :: proc(self: ^Frame_Texture) {
    gpu.texture_view_release(self.view)
    gpu.texture_release(self.texture)
}

resize_surface :: proc(width, height: u32) {
    assert(width != 0, "Surface width cannot be zero")
    assert(height != 0, "Surface height cannot be zero")

    log.debugf("Resizing surface to %d×%d", width, height)

    // Wait for the device to finish all operations
    when ODIN_OS != .JS {
        // gpu.device_poll(ctx.device, true)
    }

    ctx.gc.config.width = width
    ctx.gc.config.height = height

    // Reconfigure the surface
    // gpu.surface_unconfigure(app.surface)
    gpu.surface_configure(ctx.gc.surface, ctx.gc.device, ctx.gc.config)
}

Depth_Stencil_State_Descriptor :: struct {
    format:              gpu.Texture_Format,
    depth_write_enabled: bool,
}

DEFAULT_DEPTH_FORMAT :: gpu.Texture_Format.Depth24_Plus

create_depth_stencil_state :: proc(
    desc: Depth_Stencil_State_Descriptor = { DEFAULT_DEPTH_FORMAT, true },
) -> gpu.Depth_Stencil_State {
    stencil_state_face_desc := gpu.Stencil_Face_State {
        compare       = .Always,
        fail_op       = .Keep,
        depth_fail_op = .Keep,
        pass_op       = .Keep,
    }

    format := desc.format if desc.format != .Undefined else DEFAULT_DEPTH_FORMAT

    return {
        format = format,
        depth_write_enabled = desc.depth_write_enabled,
        depth_compare = .Less_Equal,
        stencil = {
            front = stencil_state_face_desc,
            back = stencil_state_face_desc,
            read_mask = max(u32),
            write_mask = max(u32),
        },
    }
}

Depth_Stencil_Texture_Creation_Options :: struct {
    format:        gpu.Texture_Format,
    width, height: u32,
    sample_count:  u32,
}

Depth_Stencil_Texture :: struct {
    format:     gpu.Texture_Format,
    texture:    gpu.Texture,
    view:       gpu.Texture_View,
    descriptor: gpu.Render_Pass_Depth_Stencil_Attachment,
}

@(require_results)
create_depth_stencil_texture :: proc(
    device: gpu.Device,
    options: Depth_Stencil_Texture_Creation_Options,
) -> (
    ret: Depth_Stencil_Texture,
) {
    ret.format = options.format if options.format != .Undefined else DEFAULT_DEPTH_FORMAT

    sample_count := max(1, options.sample_count)

    texture_descriptor := gpu.Texture_Descriptor {
        usage           = {.Render_Attachment, .Copy_Dst},
        format          = ret.format,
        dimension       = .D2,
        mip_level_count = 1,
        sample_count    = sample_count,
        size = {
            width                 = options.width,
            height                = options.height,
            depth_or_array_layers = 1,
        },
    }

    ret.texture = gpu.device_create_texture(device, texture_descriptor)

    texture_view_descriptor := gpu.Texture_View_Descriptor {
        format            = texture_descriptor.format,
        dimension         = .D2,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .All,
    }

    ret.view = gpu.texture_create_view(ret.texture, texture_view_descriptor)

    ret.descriptor = {
        view = ret.view,
        depth_ops = {
            load = .Clear,
            store = .Store,
            clear_value = 1.0,
        },
    }

    return
}

release_depth_stencil_texture :: proc(self: Depth_Stencil_Texture) {
    gpu.release(self.texture)
    gpu.release(self.view)
}
