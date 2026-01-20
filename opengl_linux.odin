#+build linux
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:slice"
import "core:strings"
import sa "core:container/small_array"

// Vendor
import gl "vendor:OpenGL"

// Local packages
import "libs/egl" // vendor version is incomplete

// -----------------------------------------------------------------------------
// Global procedures
// -----------------------------------------------------------------------------


GL_Instance_Impl :: struct {
    // Base
    using instance_base:  Instance_Base,

    // Backend
    egl_display:          egl.Display,
    egl_major, egl_minor: i32,
    extensions_view:      string,
    extensions:           []string,
    egl_context:          egl.Context,
}

EGL_MAJOR_VERSION :: 1
EGL_MINOR_VERSION :: 4

@(require_results)
gl_linux_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    instance: Instance,
) {
    desc := descriptor.? or_else {}

    // Get EGL default display
    display := egl.GetDisplay(egl.DEFAULT_DISPLAY)
    if display == egl.NO_DISPLAY {
        log.error("egl.GetDisplay failed")
        return
    }

    // Initialize EGL
    major, minor: i32
    if !egl.Initialize(display, &major, &minor) {
        log.error("egl.Initialize failed")
        return
    }

    // Check for minimum EGL version
    if major < EGL_MAJOR_VERSION || (major == EGL_MAJOR_VERSION && minor < EGL_MINOR_VERSION) {
        log.errorf("EGL version %d.%d - %d.%d+ is required", EGL_MAJOR_VERSION, EGL_MINOR_VERSION)
        return
    }

    // Bind OpenGL api
    if !egl.BindAPI(egl.OPENGL_API) {
        log.error("egl.BindAPI failed")
        return
    }

    // Get extensions
    extensions_cstr := egl.QueryString(display, egl.EXTENSIONS)
    extensions_str: string
    extensions: []string
    if extensions_cstr != nil && len(extensions_cstr) > 0 {
        extensions_str = strings.clone_from_cstring(extensions_cstr, allocator)
        extensions = strings.split(extensions_str, " ", allocator)
    }

    // Build context attributes
    attribs: sa.Small_Array(9, i32)
    sa.push_back_elems(
        &attribs,
        egl.CONTEXT_MAJOR_VERSION,
        GL_MAJOR_VERSION,
        egl.CONTEXT_MINOR_VERSION,
        GL_MINOR_VERSION,
        egl.CONTEXT_OPENGL_PROFILE_MASK,
        egl.CONTEXT_OPENGL_CORE_PROFILE_BIT,
    )

    if .Debug in desc.flags {
        sa.push_back_elems(&attribs, egl.CONTEXT_OPENGL_DEBUG, 1)
    }

    sa.push_back(&attribs, egl.NONE) // end of the list

    // Create OpenGL context
    egl_context := egl.CreateContext(
        display,
        egl.NO_CONFIG,
        egl.NO_CONTEXT,
        raw_data(sa.slice(&attribs)),
    )
    if egl_context == egl.NO_CONTEXT {
        log.errorf("egl.CreateContext failed: 0x%x", egl.GetError())
        return
    }

    if !egl.MakeCurrent(display, egl.NO_SURFACE, egl.NO_SURFACE, egl_context) {
        log.error("Failed to make context current")
        return
    }

    // Load OpenGL function pointers (only once per process)
    if gl.loaded_up_to == {} {
        gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, egl.gl_set_proc_address)
    }

    // Create instance
    impl := instance_new_impl(GL_Instance_Impl, allocator, loc)

    impl.ctx             = context
    impl.flags           = desc.flags
    impl.egl_display     = display
    impl.egl_major       = major
    impl.egl_minor       = minor
    impl.extensions_view = extensions_str
    impl.extensions      = extensions
    impl.egl_context     = egl_context

    return Instance(impl)
}

@(require_results)
gl_linux_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> (
    ret: Surface,
) {
    impl := get_impl(GL_Instance_Impl, instance, loc)

    create_egl_surface :: proc(
        display: egl.Display,
        window: egl.NativeWindowType,
        use_srgb := false,
        use_msaa := false,
        msaa_samples := 4,
    ) -> (
        config: egl.Config,
        surface: egl.Surface,
        ok: bool,
    ) {
        MAX_CONFIGS :: 64
        MAX_ATTRIBUTES :: 24
        configs: [MAX_CONFIGS]egl.Config
        attribs: sa.Small_Array(MAX_ATTRIBUTES, i32)
        config_count: i32

        {
            sa.push_back_elems(&attribs,
                egl.SURFACE_TYPE,       egl.WINDOW_BIT,
                egl.CONFORMANT,         egl.OPENGL_BIT,
                egl.RENDERABLE_TYPE,    egl.OPENGL_BIT,
                egl.COLOR_BUFFER_TYPE,  egl.RGB_BUFFER,
                egl.RED_SIZE,           8,
                egl.GREEN_SIZE,         8,
                egl.BLUE_SIZE,          8,
                egl.DEPTH_SIZE,         24,
                egl.STENCIL_SIZE,       8,
            )

            if use_msaa {
                sa.push_back_elems(&attribs, egl.SAMPLE_BUFFERS, 1)
                sa.push_back_elems(&attribs, egl.SAMPLES, i32(msaa_samples))
            }

            sa.push_back(&attribs, egl.NONE)
            if !egl.ChooseConfig(
                display,
                raw_data(sa.slice(&attribs)),
                &configs[0],
                MAX_CONFIGS,
                &config_count,
            ) {
                log.error("egl.ChooseConfig failed")
                return
            }

            if config_count == 0 {
                log.error("No suitable EGL configs found")
                return
            }
        }

        // Then try all configs to find one that works
        result_surface: egl.Surface
        result_config: egl.Config

        for i in 0 ..< config_count {
            // Build surface attributes
            surface_attribs: sa.Small_Array(MAX_ATTRIBUTES, i32)

            // double buffered
            sa.push_back_elems(&surface_attribs, egl.RENDER_BUFFER, egl.BACK_BUFFER)

            // Request sRGB framebuffer
            if use_srgb {
                sa.push_back_elems(&surface_attribs, egl.GL_COLORSPACE, egl.GL_COLORSPACE_SRGB)
            }

            sa.push_back(&surface_attribs, egl.NONE)

            // Try to create surface with this config
            result_surface = egl.CreateWindowSurface(
                display,
                configs[i],
                window,
                raw_data(sa.slice(&surface_attribs)),
            )

            if result_surface != egl.NO_SURFACE {
                result_config = configs[i]
                break
            }

            // Log why it failed (optional)
            err := egl.GetError()
            log.debugf("Config #%d failed: 0x%x", i, err)
        }

        if result_surface == egl.NO_SURFACE {
            log.error("Cannot create EGL surface with any config")
            return
        }

        return result_config, result_surface, true
    }

    native_window: egl.NativeWindowType

    #partial switch &t in descriptor.target {
    case Surface_Source_Xlib_Window:
        native_window = egl.NativeWindowType(uintptr(t.window))
    case Surface_Source_Wayland_Surface:
        native_window = egl.NativeWindowType(t.surface)
    case:
        panic("Unsupported surface descriptor type", loc)
    }

    // Choose EGL config and create surface
    egl_config, egl_surface, egl_surface_ok := create_egl_surface(
        impl.egl_display,
        native_window,
        use_srgb = false,
        use_msaa = false,
    )
    assert(egl_surface_ok, "Failed to create EGL surface", loc)

    // Bind the context to the actual window surface
    if !egl.MakeCurrent(impl.egl_display, egl_surface, egl_surface, impl.egl_context) {
        err := egl.GetError()
        log.errorf("eglMakeCurrent failed on window surface: 0x%x", err)

        // Cleanup
        egl.DestroySurface(impl.egl_display, egl_surface)
        return
    }

    surface := instance_new_handle(GL_Surface_Impl, instance, loc)

    surface.native_window = native_window
    surface.egl_config = egl_config
    surface.egl_surface = egl_surface

    return Surface(surface)
}

gl_linux_instance_request_adapter :: proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
) {
    assert(callback_info.callback != nil, "No callback provided for adapter request", loc)
    // impl := get_impl(GL_Instance_Impl, instance, loc)

    // opts := options.? or_else {}

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

    // Query OpenGL info
    vendor := gl.GetString(gl.VENDOR)
    renderer := gl.GetString(gl.RENDERER)
    version := gl.GetString(gl.VERSION)

    adapter_impl := instance_new_handle(GL_Adapter_Impl, instance, loc)

    adapter_impl.vendor = vendor
    adapter_impl.renderer = renderer
    adapter_impl.version = version

    // Get features and limits
    adapter_impl.features = gl_adapter_get_features(Adapter(adapter_impl), loc)
    adapter_impl.limits = gl_adapter_get_limits(Adapter(adapter_impl), loc)

    invoke_callback(callback_info, .Success, Adapter(adapter_impl), "")
}

gl_linux_instance_release :: proc(instance: Instance, loc := #caller_location) {
    assert(instance != nil, "Attempted to release nil instance", loc)
    impl := get_impl(GL_Instance_Impl, instance, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if len(impl.extensions) > 0 {
            delete(impl.extensions_view)
            delete(impl.extensions)
        }

        if impl.egl_display != egl.NO_DISPLAY {
            egl.Terminate(impl.egl_display)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


GL_Adapter_Impl :: struct {
    // Base
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    instance:  Instance,
    allocator: runtime.Allocator,
    features:  Features,
    limits:    Limits,
    vendor:    cstring,
    renderer:  cstring,
    version:   cstring,
}

gl_linux_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    assert(adapter != nil, "Attempted to release nil adapter", loc)
    impl := get_impl(GL_Adapter_Impl, adapter, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Surface procedures
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
    pixel_format:        i32,
    back_buffer_count:   u32,
    textures:            sa.Small_Array(GL_MAX_BACK_BUFFERS, ^GL_Texture_Impl),
    views:               sa.Small_Array(GL_MAX_BACK_BUFFERS, ^GL_Texture_View_Impl),
    framebuffers:        sa.Small_Array(GL_MAX_BACK_BUFFERS, u32),
    current_frame_index: u32,

    // Backend
    native_window:       egl.NativeWindowType,
    egl_surface:         egl.Surface,
    egl_config:          egl.Config,
}

gl_linux_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    assert(surface != nil, "Invalid surface", loc)
    assert(adapter != nil, "Invalid adapter", loc)

    impl := get_impl(GL_Surface_Impl, adapter, loc)
    instance_impl := get_impl(GL_Instance_Impl, impl.instance, loc)

    context.allocator = allocator

    // Query EGL config attributes
    red_size, green_size, blue_size, alpha_size: i32
    egl.GetConfigAttrib(instance_impl.egl_display, impl.egl_config, egl.RED_SIZE, &red_size)
    egl.GetConfigAttrib(instance_impl.egl_display, impl.egl_config, egl.GREEN_SIZE, &green_size)
    egl.GetConfigAttrib(instance_impl.egl_display, impl.egl_config, egl.BLUE_SIZE, &blue_size)
    egl.GetConfigAttrib(instance_impl.egl_display, impl.egl_config, egl.ALPHA_SIZE, &alpha_size)

    has_alpha := alpha_size > 0

    // Determine formats based on config
    formats := make([dynamic]Texture_Format, allocator)

    // Check BGRA support
    has_bgra_support :=
        gl_check_extension_support("GL_EXT_texture_format_BGRA8888") ||
        gl_check_extension_support("GL_EXT_bgra")

    if has_bgra_support {
        append(&formats, ..[]Texture_Format{.Bgra8_Unorm_Srgb, .Bgra8_Unorm})
    }

    // Add core formats
    append(&formats, ..[]Texture_Format{.Rgba8_Unorm_Srgb, .Rgba8_Unorm})

    slice.sort_by(formats[:], proc(i, j: Texture_Format) -> bool {
        return surface_get_format_priority(i) > surface_get_format_priority(j)
    })

    // Present modes - check EGL swap interval support
    present_modes := make([dynamic]Present_Mode, allocator)

    // EGL always supports swap interval control
    append(&present_modes, ..[]Present_Mode{.Fifo, .Immediate})

    // Check for adaptive vsync (EGL_EXT_swap_buffers_with_damage or platform-specific extensions)
    has_adaptive := false
    for ext in instance_impl.extensions {
        if ext == "EGL_EXT_swap_buffers_with_damage" || ext == "EGL_KHR_swap_buffers_with_damage" {
            has_adaptive = true
            break
        }
    }

    if has_adaptive {
        append(&present_modes, Present_Mode.Mailbox)
    }

    // Alpha modes
    alpha_modes := make([dynamic]Composite_Alpha_Mode, allocator)
    append(&alpha_modes, Composite_Alpha_Mode.Opaque)

    if has_alpha {
        append(&alpha_modes, ..[]Composite_Alpha_Mode{.Pre_Multiplied, .Post_Multiplied})
    }

    // Usages
    usages := Texture_Usages{.Render_Attachment, .Copy_Src}

    caps = Surface_Capabilities {
        formats       = formats[:],
        present_modes = present_modes[:],
        alpha_modes   = alpha_modes[:],
        usages        = usages,
    }

    return
}

gl_linux_surface_present :: proc(impl: ^GL_Surface_Impl, loc := #caller_location) {
    instance_impl := get_impl(GL_Instance_Impl, impl.instance, loc)

    // Swap buffers
    ok := bool(egl.SwapBuffers(instance_impl.egl_display, impl.egl_surface))
    if !ok {
        err := egl.GetError()
        log.errorf("eglSwapBuffers failed: 0x%x", err)

        // Handle common errors
        switch err {
        case 0x300D: // EGL_BAD_SURFACE
            log.error("Bad surface - surface may have been destroyed")
        case 0x300E: // EGL_BAD_CONTEXT
            log.error("Bad context - context may not be current")
        case 0x3001: // EGL_NOT_INITIALIZED
            log.error("EGL not initialized")
        }
    }
    assert(ok, "eglSwapBuffers failed", loc)
}

gl_linux_surface_release :: proc(surface: Surface, loc := #caller_location) {
    assert(surface != nil, "Attempted to release nil surface", loc)
    impl := get_impl(GL_Surface_Impl, surface, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        instance_impl := get_impl(GL_Instance_Impl, impl.instance, loc)

        gl_surface_cleanup_resources(impl, loc)

        for i in 0 ..< int(impl.back_buffer_count) {
            view_impl := sa.get(impl.views, i)
            gl_texture_release(view_impl.texture, loc)
            texture_impl := sa.get(impl.textures, i)
            gl_device_release(texture_impl.device, loc)
            free(view_impl)
            free(texture_impl)
        }

        if impl.egl_surface != nil {
            egl.DestroySurface(instance_impl.egl_display, impl.egl_surface)
        }

        if impl.device != nil {
            gl_device_release(impl.device, loc)
        }

        free(impl)
    }
}
