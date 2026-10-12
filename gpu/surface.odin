package gpu

// Handle to a presentable surface.
//
// A `Surface` represents a platform-specific surface (e.g. a window) onto which
// rendered images may be presented. A `Surface` may be created with the
// function `instance_create_surface`.
//
// This type is unique to our API. In the WebGPU specification,
// [`GPUCanvasContext`](https://gpuweb.github.io/gpuweb/#canvas-context) serves
// a similar role.
Surface :: distinct rawptr

// The color space in which the presentation engine interprets the values
// written to a surface texture.
Surface_Color_Space :: enum u32 {
    // `Srgb` is supported.
    Srgb,
    // `Extended_Srgb_Linear` is supported.
    Extended_Srgb_Linear,
    // `Display_P3` is supported.
    Display_P3,
    // `Bt2100_Pq` is supported.
    Bt2100_Pq,
    // `Bt2100_Hlg` is supported.
    Bt2100_Hlg,
    // `Extended_Srgb` is supported.
    Extended_Srgb,
    // `Extended_Display_P3` is supported.
    Extended_Display_P3,
}

// A set of `Surface_Color_Space`s supported by a surface for a particular
// texture format.
//
// Reported per format in `Surface_Capabilities.formats` via
// `Surface_Format_Capabilities`.
Surface_Color_Spaces :: distinct bit_set[Surface_Color_Space;u32]

// A texture format supported by a surface, together with the color spaces in
// which the surface can present it.
Surface_Format_Capabilities :: struct {
    // The texture format.
    format: Texture_Format,
    // The set of color spaces the surface supports for this format.
    //
    // This reports which color spaces the surface can be *configured* with; it
    // does not reflect whether the display is currently in HDR mode. For the
    // display's live HDR state.
    //
    // Guaranteed to be non-empty.
    color_spaces: Surface_Color_Spaces,
}

// Defines the capabilities of a given surface and adapter.
Surface_Capabilities :: struct {
    // List of supported formats to use with the given adapter. The first format
    // in the slice is preferred.
    //
    // Only contains formats that can be configured with the default
    // `Surface_Color_Space.Auto`; formats available exclusively in
    // explicit-opt-in (wide-gamut / HDR) color spaces appear only in
    // `format_capabilities`.
    //
    // Returns an empty slice if the surface is incompatible with the adapter.
    formats:             []Texture_Format,
    // List of supported formats together with the color spaces supported for
    // each format, in the same preference order as `formats`.
    //
    // Returns an empty slice if the surface is incompatible with the adapter.
    format_capabilities: []Surface_Format_Capabilities,
    // List of supported presentation modes to use with the given adapter.
    //
    // Returns an empty vector if the surface is incompatible with the adapter.
    present_modes:       []Present_Mode,
    // List of supported alpha modes to use with the given adapter.
    //
    // Will return at least one element, `Opaque` or `Inherit`.
    alpha_modes:         []Composite_Alpha_Mode,
    // Bitflag of supported texture usages for the surface to use with the given adapter.
    //
    // The usage `Render_Attachment` is guaranteed.
    usages:              Texture_Usages,
}

Surface_Color_Management :: struct {
    color_space:       Predefined_Color_Space,
    tone_mapping_mode: Tone_Mapping_Mode,
}

// Describes a `Surface`.
//
// For use with `surface_configure`.
//
// Corresponds to [WebGPU `GPUCanvasConfiguration`](
// https://gpuweb.github.io/gpuweb/#canvas-configuration).
Surface_Configuration :: struct {
    device:                        Device,
    // The usage of the swap chain. The only usage guaranteed to be supported is
    // `Render_Attachment`.
    usage:                         Texture_Usages,
    // The texture format of the swap chain. The only formats that are
    // guaranteed are `BGRA8_Unorm` and `BGRA8_Unorm_Srgb`.
    format:                        Texture_Format,
    // The color space in which the presentation engine interprets the values
    // written to the swap chain.
    //
    // The supported color spaces for each format are listed in
    // `Surface_Capabilities.format_capabilities`. The default is supported for
    // every format in `Surface_Capabilities.formats`; any other value must be
    // present in the format's `Surface_Format_Capabilities.color_spaces` set.
    color_space:                   Surface_Color_Space,
    // Width of the swap chain. Must be the same size as the surface, and nonzero.
    //
    // If this is not the same size as the underlying surface (e.g. if it is
    // set once, and the window is later resized), the behaviour is defined
    // but platform-specific, and may change in the future (currently macOS
    // scales the surface, other platforms may do something else).
    width:                         u32,
    // Height of the swap chain. Must be the same size as the surface, and nonzero.
    //
    // If this is not the same size as the underlying surface (e.g. if it is
    // set once, and the window is later resized), the behaviour is defined
    // but platform-specific, and may change in the future (currently macOS
    // scales the surface, other platforms may do something else).
    height:                        u32,
    // Presentation mode of the swap chain. Fifo is the only mode guaranteed to
    // be supported. `FifoRelaxed`, `Immediate`, and `Mailbox` will crash if
    // unsupported, while `AutoVsync` and `AutoNoVsync` will gracefully do a
    // designed sets of fallbacks if their primary modes are unsupported.
    present_mode:                  Present_Mode,
    // Desired maximum number of monitor refreshes between a
    // `surface_get_current_texture` call and the texture being presented to the
    // screen. This is sometimes called "Frames in Flight".
    //
    // Defaults to `2` when created via `surface_get_default_config` as this is
    // a reasonable default.
    //
    // This is ultimately a hint to the backend implementation and will always
    // be clamped to the supported range.
    //
    // Typical values are `1` to `3`, but higher values are valid, though likely
    // to be clamped.
    //
    // - Choose `1` to minimize latency above all else. This only gives a single
    //   monitor refresh for all of the CPU and GPU work to complete. ⚠️ As a
    //   result of these short swapchains, the CPU and GPU cannot run in
    //   parallel, prioritizing latency over throughput. For applications like
    //   GUIs doing a small amount of GPU work each frame that need low latency,
    //   this is a reasonable choice.
    // - Choose `2` for a balance between latency and throughput. The CPU and
    //   GPU both can each use a full monitor refresh to do their computations.
    //   This is a reasonable default for most applications.
    // - Choose `3` or higher to maximize throughput, sacrificing latency when
    //   the CPU and GPU are using less than a full monitor refresh each. For
    //   applications that use CPU-side pipelining of frames this may be a
    //   reasonable choice. ⚠️ On 60hz displays the latency can be very
    //   noticeable.
    //
    // This maps to the backend in the following ways:
    //
    // - Vulkan: Number of frames in the swapchain is
    //   `desired_maximum_frame_latency + 1`, clamped to the supported range.
    //   Acquire additionally waits while more than `desired_maximum_frame_latency`
    //   submissions are still outstanding, bounding queue depth and latency
    //   (but not frame rate: mailbox still presents as fast as rendered).
    // - DX12: Calls `IDXGISwapChain2::SetMaximumFrameLatency`.
    // - Metal: Sets the `maximumDrawableCount` of the underlying `CAMetalLayer`
    //   to `desired_maximum_frame_latency + 1`, clamped to the supported range.
    // - OpenGL: Ignored
    //
    // It also has various subtle interactions with various present modes and
    // APIs.
    //
    // - DX12 + Mailbox: Limits framerate to `desired_maximum_frame_latency *
    //   Monitor Hz` fps.
    // - Vulkan/Metal + Mailbox: If this is set to `2`, limits framerate to `2 *
    //   Monitor Hz` fps. `3` or higher is unlimited.
    desired_maximum_frame_latency: u32,
    // Specifies how the alpha channel of the textures should be handled during
    // compositing.
    alpha_mode:                    Composite_Alpha_Mode,
    // Specifies what view formats will be allowed when calling
    // `texture_create_view` on the texture returned by
    // `surface_get_current_texture`.
    //
    // View formats of the same format as the texture are always allowed.
    //
    // Note:                       currently, only the srgb-ness is allowed to change. (ex:
    // `RGBA8_Unorm` texture + `RGBA8_Unorm_Srgb` view)
    view_formats:                  []Texture_Format,
}

// Surface texture that can be rendered to.
Surface_Texture :: struct {
    // The surface where this texture belong to.
    surface: Surface,
    // Accessible view of the frame.
    texture: Texture,
    // Result of a call to `surface_get_current_texture`.
    status:  Surface_Get_Current_Texture_Status,
}

// Used in  `Surface_Descriptor` to make an `Surface` wrapping an Android `ANativeWindow.`
Surface_Source_Android_Native_Window :: struct {
    // The pointer to the `ANativeWindow` that will be wrapped by the `Surface`.
    window: rawptr,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a html `selector` id.
Surface_Source_Canvas_HTML_Selector :: struct {
    // The html `selector` id that will be wrapped by the `Surface`.
    selector: string,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a `CAMetalLayer`.
Surface_Source_Metal_Layer :: struct {
    // The pointer to the `CAMetalLayer` that will be wrapped by the `Surface`.
    layer: rawptr,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a `Wayland` `wl_surface`.
Surface_Source_Wayland_Surface :: struct {
    // A `wl_display`for this Wayland instance.
    display: rawptr,
    // A `wl_surface` that will be wrapped by the `Surface`
    surface: rawptr,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a Windows `HWND`.
Surface_Source_Windows_HWND :: struct {
    // The `HINSTANCE` for this application. Most commonly
    // `win32.GetModuleHandle(nil)`.
    hinstance: rawptr,
    // The `HWND` that will be wrapped by the `Surface`.
    hwnd:      rawptr,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a `XCB` `xcb_window_t`.
Surface_Source_XCB_Window :: struct {
    // The `xcb_connection_t` for the connection to the X server.
    connection: rawptr,
    // The `xcb_window_t` for the window that will be wrapped by the `Surface`.
    window:     u32,
}

// Used in `Surface_Descriptor` to make an `Surface` wrapping a `Xlib` window.
Surface_Source_Xlib_Window :: struct {
    // A pointer to the `Display` connected to the X server.
    display: rawptr,
    // The `Window` that will be wrapped by the `Surface`.
    window:  u64,
}

Surface_Source_Swap_Chain_Panel :: struct {
    panel_native: rawptr,
}

Surface_Source_Ohos_Native_Window :: struct {
    window: rawptr,
}

// Platform-specific surface source.
Surface_Source :: union {
    Surface_Source_Android_Native_Window,
    Surface_Source_Canvas_HTML_Selector,
    Surface_Source_Metal_Layer,
    Surface_Source_Wayland_Surface,
    Surface_Source_Windows_HWND,
    Surface_Source_XCB_Window,
    Surface_Source_Xlib_Window,
    Surface_Source_Swap_Chain_Panel,
    Surface_Source_Ohos_Native_Window,
}

// Describes a `Surface`.
//
// For use with `instance_create_surface`.
Surface_Descriptor :: struct {
    // Debug label of a surface.
    label:  string,
    // Platform-specific surface source.
    source: Surface_Source,
}

surface_configure: proc(surface: Surface, config: Surface_Configuration, loc := #caller_location)

surface_get_capabilities: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> Surface_Capabilities

surface_get_current_texture: proc(surface: Surface, loc := #caller_location) -> Surface_Texture

surface_present: proc(surface: Surface, loc := #caller_location) -> Status

surface_set_label: proc(surface: Surface, label: string, loc := #caller_location)

surface_unconfigure: proc(surface: Surface, loc := #caller_location)

surface_add_ref: proc(surface: Surface, loc := #caller_location)

surface_release: proc(surface: Surface, loc := #caller_location)

surface_texture_present: proc(texture: Surface_Texture, loc := #caller_location) -> Status

// Retires a successfully acquired surface texture when the caller has no work
// to present. Release views and cancel any unfinished encoders that reference
// the image first; it must not be used by later submissions. The backend may
// submit a transition-only operation and present unchanged or undefined contents
// to return the acquired image to the presentation engine.
surface_texture_discard :: proc(
    texture: Surface_Texture,
    loc := #caller_location,
) -> Status {
    if texture.surface == {} ||
        (texture.status != .Success && texture.status != .Suboptimal) {
        return .Error
    }
    return surface_present(texture.surface, loc)
}

surface_capabilities_free_members: proc(
    surface_capabilities: Surface_Capabilities,
    allocator := context.allocator,
    loc := #caller_location,
)
