#+build windows
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:strings"
import "core:slice"
import sa "core:container/small_array"
import win32 "core:sys/windows"

// Vendor
import gl "vendor:OpenGL"

GL_INSTANCE_CLASS_NAME   :: "gpu-hwnd"
ERROR_CLASS_ALREADY_EXISTS : win32.DWORD : 1410

GL_Active_Context :: struct {
    old_hdc:   win32.HDC,
    old_hglrc: win32.HGLRC,
}

gl_active_context_init :: proc(
    self: ^GL_Active_Context,
    hdc: win32.HDC,
    hglrc: win32.HGLRC,
    loc := #caller_location,
) -> bool {
    self.old_hdc = win32.wglGetCurrentDC()
    self.old_hglrc = win32.wglGetCurrentContext()

    if !win32.wglMakeCurrent(hdc, hglrc) {
        log.errorf("wglMakeCurrent failed: error code %d", win32.GetLastError(), location = loc)
        return false
    }

    return true
}

gl_active_context_deinit :: proc(self: ^GL_Active_Context) {
    win32.wglMakeCurrent(self.old_hdc, self.old_hglrc)
}

GL_Context :: struct {
    hwnd:         win32.HWND,
    hdc:          win32.HDC,
    hglrc:        win32.HGLRC,
    pixel_format: i32,
}

gl_win32_set_proc_address :: proc(p: rawptr, name: cstring) {
    ptr := cast(^rawptr)p

    // Try wglGetProcAddress first (for extensions and OpenGL 1.2+)
    proc_addr := win32.wglGetProcAddress(name)

    // Fall back to GetProcAddress for OpenGL 1.1 functions
    if proc_addr == nil {
        opengl32 := win32.GetModuleHandleW(win32.L("opengl32.dll"))
        if opengl32 != nil {
            proc_addr = win32.GetProcAddress(opengl32, name)
        }
    }

    ptr^ = proc_addr
}

@(require_results)
gl_win32_create_dummy_window :: proc() -> win32.HWND {
    hinstance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
    if hinstance == nil {
        log.errorf("GetModuleHandleW failed: error code %d", win32.GetLastError())
        return nil
    }

    dw_ex_style := win32.WS_EX_OVERLAPPEDWINDOW
    dw_style := win32.WS_CLIPSIBLINGS | win32.WS_CLIPCHILDREN
    hwnd := win32.CreateWindowExW(
        dwExStyle = dw_ex_style,
        lpClassName = win32.L(GL_INSTANCE_CLASS_NAME),
        lpWindowName = win32.L(GL_INSTANCE_CLASS_NAME),
        dwStyle = dw_style,
        X = 0, Y = 0, nWidth = 1, nHeight = 1,
        hWndParent = nil,
        hMenu = nil,
        hInstance = hinstance,
        lpParam = nil,
    )
    if hwnd == nil {
        log.errorf("CreateWindowExW failed: error code %d", win32.GetLastError())
        return nil
    }

    return hwnd
}

@(require_results)
gl_win32_set_pixel_format :: proc(
    wgl: GL_Instance_WGL,
    hdc: win32.HDC,
) -> (pixel_format: i32, ok: bool) #optional_ok {
    format_attribs := [?]i32 {
        win32.WGL_DRAW_TO_WINDOW_ARB, 1,
        win32.WGL_SUPPORT_OPENGL_ARB, 1,
        win32.WGL_DOUBLE_BUFFER_ARB,  1,
        win32.WGL_PIXEL_TYPE_ARB,     win32.WGL_TYPE_RGBA_ARB,
        win32.WGL_COLOR_BITS_ARB,     32,
        win32.WGL_DEPTH_BITS_ARB,     24,
        win32.WGL_STENCIL_BITS_ARB,   8,
        0,
    }

    num_formats: win32.UINT
    res := wgl.ChoosePixelFormatARB(
        hdc, raw_data(format_attribs[:]), nil, 1, &pixel_format, &num_formats)
    if !res {
        log.errorf("ChoosePixelFormatARB failed: error code %d", win32.GetLastError())
        return
    }

    if num_formats == 0 {
        log.error("No suitable pixel formats found")
        return
    }

    pfd: win32.PIXELFORMATDESCRIPTOR
    if win32.DescribePixelFormat(hdc, pixel_format, size_of(pfd), &pfd) == 0 {
        log.errorf("DescribePixelFormat failed: error code %d", win32.GetLastError())
        return
    }

    if !win32.SetPixelFormat(hdc, pixel_format, &pfd) {
        log.errorf("SetPixelFormat failed: error code %d", win32.GetLastError())
        return
    }

    return pixel_format, true
}

GL_Instance_WGL :: struct {
    extensions_view:         string,
    extensions:              []string,
    GetExtensionsStringARB:  win32.GetExtensionsStringARBType,
    CreateContextAttribsARB: win32.CreateContextAttribsARBType,
    ChoosePixelFormatARB:    win32.ChoosePixelFormatARBType,
}

GL_Instance_Impl :: struct {
    using base: Instance_Base,
    hwnd:       win32.HWND,
    hdc:        win32.HDC,
    wgl:        GL_Instance_WGL,
}

@(require_results)
gl_win32_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    instance: Instance,
) {
    desc := descriptor.? or_else {}

    // Register window class
    hinstance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
    if hinstance == nil {
        log.errorf("GetModuleHandleW failed: error code %d", win32.GetLastError())
        return nil
    }

    wc := win32.WNDCLASSW {
        lpfnWndProc   = win32.DefWindowProcW,
        hInstance     = hinstance,
        lpszClassName = win32.L(GL_INSTANCE_CLASS_NAME),
        style         = win32.CS_OWNDC,
    }

    if res := win32.RegisterClassW(&wc); res == 0 {
        err := win32.GetLastError()
        // ERROR_CLASS_ALREADY_EXISTS is okay
        if err != ERROR_CLASS_ALREADY_EXISTS {
            log.errorf("RegisterClassW failed: error code %d", err)
            return
        }
    }

    // Create dummy window
    hwnd := gl_win32_create_dummy_window()
    if hwnd == nil do return nil
    defer if instance == nil do win32.DestroyWindow(hwnd)

    hdc := win32.GetDC(hwnd)
    if hdc == nil {
        log.errorf("GetDC failed: error code %d", win32.GetLastError())
        return
    }
    defer if instance == nil do win32.ReleaseDC(hwnd, hdc)

    // Set pixel format for dummy window (using legacy approach for compatibility)
    pfd := win32.PIXELFORMATDESCRIPTOR{
        nSize = size_of(win32.PIXELFORMATDESCRIPTOR),
        nVersion = 1,
        dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
        iPixelType = win32.PFD_TYPE_RGBA,
        cColorBits = 32,
        cDepthBits = 24,
        cStencilBits = 8,
        iLayerType = win32.PFD_MAIN_PLANE,
    }
    pixel_format := win32.ChoosePixelFormat(hdc, &pfd)
    if pixel_format == 0 {
        log.errorf("ChoosePixelFormat failed: error code %d", win32.GetLastError())
        return
    }
    if !win32.SetPixelFormat(hdc, pixel_format, &pfd) {
        log.errorf("SetPixelFormat failed: error code %d", win32.GetLastError())
        return
    }

    // Create legacy context
    hglrc := win32.wglCreateContext(hdc)
    if hglrc == nil {
        log.errorf("wglCreateContext failed: error code %d", win32.GetLastError())
        return
    }
    defer win32.wglDeleteContext(hglrc)

    ctx: GL_Active_Context
    if !gl_active_context_init(&ctx, hdc, hglrc, loc) {
        return
    }
    defer gl_active_context_deinit(&ctx)

    // Load WGL extensions
    GetExtensionsStringARB := win32.GetExtensionsStringARBType(
        win32.wglGetProcAddress("wglGetExtensionsStringARB"))
    if GetExtensionsStringARB == nil {
        log.error("Failed to load wglGetExtensionsStringARB")
        return
    }

    CreateContextAttribsARB := win32.CreateContextAttribsARBType(
        win32.wglGetProcAddress("wglCreateContextAttribsARB"))
    if CreateContextAttribsARB == nil {
        log.error("Failed to load wglCreateContextAttribsARB")
        return
    }

    ChoosePixelFormatARB := win32.ChoosePixelFormatARBType(
        win32.wglGetProcAddress("wglChoosePixelFormatARB"))
    if ChoosePixelFormatARB == nil {
        log.error("Failed to load wglChoosePixelFormatARB")
        return
    }

    extensions_cstr := GetExtensionsStringARB(hdc)
    extensions_str: string
    extensions: []string
    if extensions_cstr != nil {
        extensions_str = strings.clone_from_cstring(extensions_cstr, allocator)
        extensions = strings.split(extensions_str, " ", allocator)
    }

    // Create instance
    impl := instance_new_impl(GL_Instance_Impl, allocator, loc)
    impl.ctx = context
    impl.flags = desc.flags
    impl.hwnd = hwnd
    impl.hdc = hdc
    impl.wgl = {
        extensions_view         = extensions_str,
        extensions              = extensions,
        GetExtensionsStringARB  = GetExtensionsStringARB,
        CreateContextAttribsARB = CreateContextAttribsARB,
        ChoosePixelFormatARB    = ChoosePixelFormatARB,
    }

    return Instance(impl)
}

@(require_results)
gl_win32_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    impl := get_impl(GL_Instance_Impl, instance, loc)

    hinstance: win32.HINSTANCE
    hwnd:      win32.HWND

    #partial switch &t in descriptor.target {
    case Surface_Source_Windows_HWND:
        if t.hinstance == nil || t.hwnd == nil {
            log.error("Invalid HWND surface descriptor")
            return nil
        }
        hinstance = win32.HINSTANCE(t.hinstance)
        hwnd = win32.HWND(t.hwnd)
    case:
        log.error("Unsupported surface descriptor type")
        return nil
    }

    hdc := win32.GetDC(hwnd)
    if hdc == nil {
        log.errorf("GetDC failed: error code %d", win32.GetLastError())
        return nil
    }

    pixel_format, pixel_format_ok := gl_win32_set_pixel_format(impl.wgl, hdc)
    if !pixel_format_ok {
        win32.ReleaseDC(hwnd, hdc)
        return nil
    }

    surface := instance_new_handle(GL_Surface_Impl, instance, loc)

    surface.hinstance = hinstance
    surface.hwnd = hwnd
    surface.hdc = hdc
    surface.pixel_format = pixel_format

    return Surface(surface)
}

gl_win32_instance_request_adapter :: proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
) {
    assert(callback_info.callback != nil, "No callback provided for adapter request", loc)
    impl := get_impl(GL_Instance_Impl, instance, loc)

    opts := options.? or_else {}

    invoke_callback :: proc(
        callback_info: Request_Adapter_Callback_Info,
        status: Request_Adapter_Status,
        adapter: Adapter,
        message: string,
    ) {
        callback_info.callback(
            status,
            adapter,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }

    // Determine which window/DC to use
    hwnd: win32.HWND
    hdc: win32.HDC
    pixel_format: i32
    owns_hdc := false

    if opts.compatible_surface != nil {
        surface_impl := get_impl(GL_Surface_Impl, opts.compatible_surface, loc)
        hwnd = surface_impl.hwnd
        hdc = win32.GetDC(hwnd)
        if hdc == nil {
            invoke_callback(callback_info, .Error, nil, "Failed to get DC from surface")
            return
        }
        owns_hdc = true
        pixel_format = surface_impl.pixel_format

        // Need to set pixel format again for this DC
        pfd: win32.PIXELFORMATDESCRIPTOR
        if win32.DescribePixelFormat(hdc, pixel_format, size_of(pfd), &pfd) == 0 {
            if owns_hdc do win32.ReleaseDC(hwnd, hdc)
            invoke_callback(callback_info, .Error, nil, "Failed to describe pixel format")
            return
        }
        if !win32.SetPixelFormat(hdc, pixel_format, &pfd) {
            if owns_hdc do win32.ReleaseDC(hwnd, hdc)
            invoke_callback(callback_info, .Error, nil, "Failed to set pixel format")
            return
        }
    } else {
        hwnd = impl.hwnd
        hdc = impl.hdc
        pixel_format = gl_win32_set_pixel_format(impl.wgl, impl.hdc) or_else 0
        if pixel_format == 0 {
            invoke_callback(callback_info, .Error, nil, "Failed to get pixel format")
            return
        }
    }
    defer if owns_hdc do win32.ReleaseDC(hwnd, hdc)

    // Build context attributes
    attribs: sa.Small_Array(9, i32)
    sa.push_back_elems(&attribs,
        win32.WGL_CONTEXT_MAJOR_VERSION_ARB, GL_MAJOR_VERSION,
        win32.WGL_CONTEXT_MINOR_VERSION_ARB, GL_MINOR_VERSION,
        win32.WGL_CONTEXT_PROFILE_MASK_ARB,  win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
    )

    if .Debug in impl.flags {
        sa.push_back_elems(&attribs,
            win32.WGL_CONTEXT_FLAGS_ARB, win32.WGL_CONTEXT_DEBUG_BIT_ARB,
        )
    }

    sa.push_back(&attribs, 0) // null terminated

    // Create modern OpenGL context
    hglrc := impl.wgl.CreateContextAttribsARB(hdc, nil, raw_data(sa.slice(&attribs)))
    if hglrc == nil {
        log.errorf("CreateContextAttribsARB failed: OpenGL %d.%d may not be supported",
                   GL_MAJOR_VERSION, GL_MINOR_VERSION)
        invoke_callback(callback_info, .Error, nil, "Failed to create OpenGL context")
        return
    }

    // Make the modern context current
    ctx: GL_Active_Context
    if !gl_active_context_init(&ctx, hdc, hglrc, loc) {
        win32.wglDeleteContext(hglrc)
        invoke_callback(callback_info, .Error, nil, "Failed to make context current")
        return
    }
    // defer gl_active_context_deinit(&ctx)

    // Load OpenGL function pointers (only once per process)
    if gl.loaded_up_to == {} {
        gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, gl_win32_set_proc_address)
    }

    // Query OpenGL info
    vendor := gl.GetString(gl.VENDOR)
    renderer := gl.GetString(gl.RENDERER)
    version := gl.GetString(gl.VERSION)

    adapter_impl := instance_new_handle(GL_Adapter_Impl, instance, loc)

    adapter_impl.hwnd = hwnd
    adapter_impl.hdc = hdc
    adapter_impl.hglrc = hglrc
    adapter_impl.pixel_format = pixel_format
    adapter_impl.vendor = vendor
    adapter_impl.renderer = renderer
    adapter_impl.version = version

    // Get features and limits
    adapter_impl.features = gl_adapter_get_features(Adapter(adapter_impl), loc)
    adapter_impl.limits = gl_adapter_get_limits(Adapter(adapter_impl), loc)

    invoke_callback(callback_info, .Success, Adapter(adapter_impl), "")
}

gl_win32_instance_release :: proc(instance: Instance, loc := #caller_location) {
    assert(instance != nil, "Attempted to release nil instance", loc)
    impl := get_impl(GL_Instance_Impl, instance, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if len(impl.wgl.extensions) > 0 {
            delete(impl.wgl.extensions_view)
            delete(impl.wgl.extensions)
        }

        if impl.hdc != nil && impl.hwnd != nil {
            win32.ReleaseDC(impl.hwnd, impl.hdc)
        }

        if impl.hwnd != nil {
            win32.DestroyWindow(impl.hwnd)
        }

        free(instance)
    }
}

// -----------------------------------------------------------------------------
// Surface
// -----------------------------------------------------------------------------

GL_Surface_Impl :: struct {
    // Base
    label:               String_Buffer_Small,
    ref:                 Ref_Count,
    instance:            Instance,
    allocator:           runtime.Allocator,
    device:              Device,
    config:              Surface_Configuration,

    // Backend
    hinstance:           win32.HINSTANCE,
    hwnd:                win32.HWND,
    hdc:                 win32.HDC,
    pixel_format:        i32,
    back_buffer_count:   u32,
    textures:            sa.Small_Array(GL_MAX_BACK_BUFFERS, ^GL_Texture_Impl),
    views:               sa.Small_Array(GL_MAX_BACK_BUFFERS, ^GL_Texture_View_Impl),
    framebuffers:        sa.Small_Array(GL_MAX_BACK_BUFFERS, u32),
    current_frame_index: u32,
}

gl_win32_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    assert(surface != nil, "Invalid surface", loc)
    assert(adapter != nil, "Invalid adapter", loc)

    impl := get_impl(GL_Surface_Impl, surface, loc)
    instance_impl := get_impl(GL_Instance_Impl, impl.instance, loc)

    context.allocator = allocator

    // Get HDC for the surface
    hdc := win32.GetDC(impl.hwnd)
    if hdc == nil {
        log.error("Failed to get DC from surface")
        return
    }
    defer win32.ReleaseDC(impl.hwnd, hdc)

    // Query pixel format descriptor
    pfd: win32.PIXELFORMATDESCRIPTOR
    if win32.DescribePixelFormat(hdc, impl.pixel_format, size_of(pfd), &pfd) == 0 {
        log.errorf("DescribePixelFormat failed: error code %d", win32.GetLastError())
        return
    }

    has_alpha := pfd.cAlphaBits > 0

    // Determine format based on pixel format
    formats := make([dynamic]Texture_Format)

    // Check bgra support for preferred format
    has_bgra_support := gl_check_extension_support("GL_EXT_texture_format_BGRA8888") ||
       gl_check_extension_support("GL_EXT_bgra")

    if has_bgra_support {
        append(&formats, ..[]Texture_Format{.Bgra8_Unorm_Srgb, .Bgra8_Unorm})
    }

    // Add core formats
    append(&formats, ..[]Texture_Format{.Rgba8_Unorm_Srgb, .Rgba8_Unorm})

    slice.sort_by(formats[:], proc(i, j: Texture_Format) -> bool {
        return surface_get_format_priority(i) > surface_get_format_priority(j)
    })

    // Present modes
    present_modes := make([dynamic]Present_Mode, allocator)

    // Check if swap interval control is supported
    has_swap_control := gl_check_wgl_extension(instance_impl.wgl, "WGL_EXT_swap_control")
    if has_swap_control {
        append(&present_modes, ..[]Present_Mode{.Fifo, .Immediate})

        // Check for adaptive vsync
        has_adaptive := gl_check_wgl_extension(instance_impl.wgl, "WGL_EXT_swap_control_tear")
        if has_adaptive {
            append(&present_modes, Present_Mode.Mailbox)
        }
    } else {
        append(&present_modes, Present_Mode.Fifo) // Default
    }

    // Alpha modes
    alpha_modes := make([dynamic]Composite_Alpha_Mode, allocator)

    append(&alpha_modes, Composite_Alpha_Mode.Opaque)
    if has_alpha {
        append(&alpha_modes, ..[]Composite_Alpha_Mode{.Pre_Multiplied, .Post_Multiplied})
    }

    // Usages
    usages := Texture_Usages{.Render_Attachment, .Copy_Src}

    caps = Surface_Capabilities{
        formats = formats[:],
        present_modes = present_modes[:],
        alpha_modes = alpha_modes[:],
        usages = usages,
    }

    return
}

gl_win32_surface_present :: proc(impl: ^GL_Surface_Impl, loc := #caller_location) {
    ok := win32.SwapBuffers(impl.hdc)
    assert(ok == win32.TRUE, "SwapBuffers failed", loc)
}

gl_win32_surface_release :: proc(surface: Surface, loc := #caller_location) {
    assert(surface != nil, "Attempted to release nil surface", loc)
    impl := get_impl(GL_Surface_Impl, surface, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        gl_surface_cleanup_resources(impl, loc)

        for i in 0 ..< int(impl.back_buffer_count) {
            view_impl := sa.get(impl.views, i)
            gl_texture_release(view_impl.texture, loc)
            free(view_impl)

            texture_impl := sa.get(impl.textures, i)
            free(texture_impl)
        }

        if impl.device != nil {
            gl_device_release(impl.device, loc)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Adapter
// -----------------------------------------------------------------------------

GL_Adapter_Impl :: struct {
    // Base
    label:        String_Buffer_Small,
    ref:          Ref_Count,
    instance:     Instance,
    allocator:    runtime.Allocator,
    features:     Features,
    limits:       Limits,

    // Backend
    hwnd:         win32.HWND,
    hdc:          win32.HDC,
    hglrc:        win32.HGLRC,
    pixel_format: i32,
    vendor:       cstring,
    renderer:     cstring,
    version:      cstring,
}

gl_win32_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    assert(adapter != nil, "Attempted to release nil adapter", loc)
    impl := get_impl(GL_Adapter_Impl, adapter, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        // Clean up the OpenGL context
        if impl.hglrc != nil {
            // Unbind context if it's current
            if win32.wglGetCurrentContext() == impl.hglrc {
                win32.wglMakeCurrent(nil, nil)
            }
            win32.wglDeleteContext(impl.hglrc)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Utils
// -----------------------------------------------------------------------------

// Check if a WGL extension is supported
@(require_results)
gl_check_wgl_extension :: proc(wgl: GL_Instance_WGL, extension: string) -> bool {
    return slice.contains(wgl.extensions, extension)
}

gl_make_current :: proc(ctx: GL_Context, loc := #caller_location) -> bool {
    assert(ctx.hdc != nil && ctx.hglrc != nil, "Attempted to make invalid context current", loc)
    return bool(win32.wglMakeCurrent(ctx.hdc, ctx.hglrc))
}

gl_destroy_context :: proc(ctx: GL_Context) {
    if ctx.hglrc != nil {
        win32.wglDeleteContext(ctx.hglrc)
    }
    if ctx.hdc != nil && ctx.hwnd != nil {
        win32.ReleaseDC(ctx.hwnd, ctx.hdc)
    }
}
