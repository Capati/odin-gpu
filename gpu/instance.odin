package gpu

// Core
import "base:runtime"
import "core:log"
import "core:reflect"

// Contains the various entry points to start interacting with the system's GPUs.
//
// This is the first thing you create when using the api. Its primary use is to
// create `Adapter`s and `Surface`s.
//
// Does not have to be kept alive.
//
// Corresponds to [WebGPU
// `GPU`](https://gpuweb.github.io/gpuweb/#gpu-interface).
Instance :: distinct rawptr

@private
Instance_Impl :: struct {
    backend:     Backend_Type,
    ctx:         runtime.Context,
    is_embedded: bool,
    headless:    bool,
    flags:       Instance_Flags,
    allocator:   runtime.Allocator,
    ref:         Ref_Count_Type,
}

@private
instance_get_public_impl: proc "contextless" (
    instance: Instance,
    loc := #caller_location,
) -> ^Instance_Impl

Backend :: enum i32 {
    Vulkan,
    GL,
    Metal,
    DX11,
    DX12,
    BrowserWebGPU,
}

// Represents the backends the gpu will use.
Backends :: bit_set[Backend;Flags]

BACKENDS_ALL       :: Backends{}
BACKENDS_PRIMARY   :: Backends{.Vulkan, .Metal, .DX11, .DX12, .BrowserWebGPU}
BACKENDS_SECONDARY :: Backends{.GL, .DX11}

// Instance debugging flags.
Instance_Flag :: enum i32 {
    // Generate debug information in shaders and objects.
    //
    // This is also enabled when `GPU_DEBUG` config is set.
    Debug,
    // Enable validation in the backend API, if possible:
    //
    // - On the Direct3D `dx12` backend, this calls `ID3D12Debug.EnableDebugLayer`.
    //
    // - On the Vulkan backend, this enables the Vulkan Validation Layer.
    //
    // - On the `gles` backend driving Windows OpenGL, this enables debug
    //   output, effectively calling `glEnable(GL_DEBUG_OUTPUT)`.
    //
    // - On non-Windows `gles` backends, this calls
    //   `eglDebugMessageControlKHR` to enable all debugging messages.
    //   If the GLES implementation is ANGLE running on Vulkan, this also
    //   enables the Vulkan validation layers by setting
    //   `EGL_PLATFORM_ANGLE_DEBUG_LAYERS_ENABLED`.
    //
    // This is also enabled when `GPU_VALIDATION` config is set.
    Validation,
    // Whether the api should expose adapters that run on top of non-compliant
    // adapters.
    //
    // Turning this on might mean that some of the functionality provided by the
    // api adapter/device is not working or is broken. It could be that all the
    // functionality the api currently exposes works but we can't tell for sure
    // since we have no additional transparency into what is working and what is
    // not on the underlying adapter.
    //
    // This mainly applies to a Vulkan driver's compliance version. If the major
    // compliance version is `0`, then the driver is ignored. This flag allows
    // that driver to be enabled for testing.
    //
    // This flag controls whether adapters that don't meet the *native* API's
    // own compliance requirements are returned, while
    // `Strict_Webgpu_Compliance` controls whether adapters that can't fully
    // satisfy the *WebGPU v1* spec are excluded.
    //
    // This is also enabled when `GPU_ALLOW_UNDERLYING_NONCOMPLIANT_ADAPTER`
    // config is set.
    Allow_Underlying_Noncompliant_Adapter,
    // Enable GPU-based validation. Implies[`Validation`. Currently, this only
    // changes behavior on the DX12 and Vulkan backends.
    //
    // Supported platforms:
    //
    // - D3D12; called "GPU-based validation", or "GBV"
    // - Vulkan, via the `VK_LAYER_KHRONOS_validation` layer; called
    //   "GPU-Assisted Validation"
    //
    // This is also enabled when `GPU_BASED_VALIDATION` config is set.
    GPU_Based_Validation,
    // Validate indirect buffer content prior to issuing indirect
    // draws/dispatches.
    //
    // This validation will transform indirect calls into no-ops if they are not
    // valid:
    //
    // - When calling `dispatch_workgroups_indirect`, all 3 indirect arguments
    //   encoded in the buffer must be less than the
    //   `max_compute_workgroups_per_dimension` device limit.
    // - When calling `draw_indirect`, `draw_indexed_indirect`,
    //   `multi_draw_indirect`, `multi_draw_indexed_indirect`:
    //   - If `Indirect_First_Instance` feature is not enabled on the device,
    //     the `first_instance` indirect argument must be 0.
    //   - The `first_instance` & `instance_count` indirect arguments must form
    //     a range that fits within all bound vertex buffers with `step_mode`
    //     set to `Instance`.
    // - When calling `draw_indirect`/`multi_draw_indirect`:
    //   - The `first_vertex` & `vertex_count` indirect arguments must form a
    //     range that fits within all bound vertex buffers with `step_mode` set
    //     to `Vertex`.
    // - When calling `draw_indexed_indirect`/`multi_draw_indexed_indirect`:
    //   - The `first_index` & `index_count` indirect arguments must form a
    //     range that fits within the bound index buffer.
    //
    // __Behavior is undefined if this validation is disabled and the rules
    // above are not satisfied.__
    //
    // This is also enabled when `GPU_VALIDATION_INDIRECT_CALL` config is set.
    Validation_Indirect_Call,
    // Enable automatic timestamp normalization. This means that in
    // `command_encoder_resolve_query_set`, the timestamps will
    // automatically be normalized to be in nanoseconds instead of the raw
    // timestamp values.
    //
    // This is disabled by default because it introduces a compute shader into
    // the resolution of query sets.
    //
    // This can be useful for users that need to read timestamps on the gpu, as
    // the normalization can be a hassle to do manually. When this is enabled,
    // the timestamp period returned by the queue will always be `1.0`.
    Automatic_Timestamp_Normalization,
    // Restrict the available feature set to the one defined by the WebGPU
    // specification.
    //
    // This is also enabled when `GPU_STRICT_WEBGPU_COMPLIANCE` config is set.
    Strict_Webgpu_Compliance,
}

// Instance debugging flags.
//
// These are not part of the WebGPU standard.
//
// Defaults to enabling debugging-related flags if `ODIN_DEBUG` is set.
Instance_Flags :: bit_set[Instance_Flag;Flags]

// Enable recommended debugging and validation flags.
INSTANCE_FLAGS_DEFAULT :: Instance_Flags{ .Debug, .Validation }

// Enable recommended debugging and validation flags.
INSTANCE_FLAGS_DEBUGGING :: Instance_Flags{ .Debug, .Validation, .Validation_Indirect_Call }

// Enable advanced debugging and validation flags (potentially very slow).
INSTANCE_FLAGS_ADVANCED_DEBUGGING :: Instance_Flags{
    .Debug,
    .Validation,
    .Validation_Indirect_Call,
    .GPU_Based_Validation,
}

Memory_Budget_Thresholds :: struct {
    for_resource_creation: u8,
    for_device_loss:       u8,
}

// Selects which OpenGL ES 3 minor version to request.
//
// When using ANGLE as an OpenGL ES/EGL implementation, explicitly requesting
// `Version1` can provide a non-conformant ES 3.1 on APIs like D3D11.
Gles3_Minor_Version :: enum i32 {
    // No explicit minor version is requested, the driver automatically picks
    // the highest available.
    Automatic,
    // Request an ES 3.0 context.
    Version0,
    // Request an ES 3.1 context.
    Version1,
    // Request an ES 3.2 context.
    Version2,
}

// Dictate the behavior of fences in OpenGL.
GL_Fence_Behaviour :: enum i32 {
    // Fences in OpenGL behave normally. If you don't know what to pick, this is
    // what you want.
    Normal,
    // Fences in OpenGL are short-circuited to always return `true` immediately.
    //
    // When this is set `queue_on_completed_work_done` will always return the
    // next time the device is maintained, not when the work is actually done on
    // the GPU.
    Auto_Finish,
}

// Configuration for the OpenGL/OpenGLES backend.
//
// Part of `Backend_Options`.
GL_Backend_Options :: struct {
    // Which OpenGL ES 3 minor version to request, if using OpenGL ES.
    gles_minor_version: Gles3_Minor_Version,
    // Behavior of OpenGL fences. Affects how `on_completed_work_done` and
    // `device_poll` behave.
    fence_behaviour:    GL_Fence_Behaviour,
}

// Selects which DX12 shader compiler to use.
Dx12_Compiler :: enum i32 {
    // Use statically-linked DXC if available. Otherwise check for dynamically
    // linked DXC on the PATH. Finally, fallback to FXC.
    Auto,
    // The Fxc compiler (default) is old, slow and unmaintained.
    //
    // However, it doesn't require any additional .dlls to be shipped with the application.
    Fxc,
    // The Dxc compiler is new, fast and maintained.
    //
    // However, it requires `dxcompiler.dll` to be shipped with the application.
    // These files can be downloaded from:
    //
    // https://github.com/microsoft/DirectXShaderCompiler/releases
    //
    // Minimum supported version: v1.8.2502
    //
    // It also requires WDDM 2.1 (Windows 10 version 1607).
    Dxc,
}

// Selects which kind of swapchain to use on DX12.
Dx12_Swapchain_Kind :: enum i32 {
    // Use a DXGI swapchain made directly from the window's HWND.
    //
    // This does not support transparency but has better support from developer
    // tooling from RenderDoc.
    Dxgi_From_Hwnd,
    // Use a DXGI swapchain made from a DirectComposition visual made
    // automatically from the window's HWND.
    //
    // This creates a single `IDCompositionVisual` over the entire window that
    // is used by the `Surface`.
    //
    // This supports transparent windows, but does not have support from
    // RenderDoc.
    Dxgi_From_Visual,
}

// .DXC shader model
Dxc_Max_Shader_Model :: enum i32 {
    V6_0,
    V6_1,
    V6_2,
    V6_3,
    V6_4,
    V6_5,
    V6_6,
    V6_7,
}

// Configuration for the DX12 backend.
//
// Part of `Backend_Options`.
Dx12_Backend_Options :: struct {
    // Which DX12 shader compiler to use.
    shader_compiler:      Dx12_Compiler,
    // Which DX12 presentation system (swapchain kind) to use.
    presentation_system:  Dx12_Swapchain_Kind,
    // File system path to `dxcompiler.dll` for dynamic DXC loading. Only used
    // when `shader_compiler` is ``DXC. An empty/undefined string view means the
    // DLL will be searched for on the system PATH.
    dxc_path:             string,
    // Maximum HLSL shader model version that DXC should target. Only used with
    // the DXC compiler.
    dxc_max_shader_model: Dxc_Max_Shader_Model,
}

// Configuration for the Vulkan backend.
//
// Part of `Backend_Options`.
Vulkan_Backend_Options :: struct {
    // Function pointer used to load Vulkan instance-level functions (equivalent
    // to `vkGetInstanceProcAddr`).
    //
    // If `nil`, the implementation uses its default Vulkan loader.
    get_instance_proc_addr: rawptr,
}

// Options that are passed to a given backend.
//
// Part of `Instance_Descriptor`.
Backend_Options :: struct {
    // Options for the OpenGL/OpenGLES backend.
    gl:     GL_Backend_Options,
    // Options for the DX12 backend.
    dx12:   Dx12_Backend_Options,
    // Options for the Vulkan backend.
    vulkan: Vulkan_Backend_Options,
}

// An Xlib display handle.
Xlib_Display_Handle :: struct {
    // Pointer to the Xlib `Display` connected to the X server.
    display: rawptr,
    // X screen associated with the display.
    screen:  i32,
}

// An XCB display handle.
Xcb_Display_Handle :: struct {
    // Pointer to the XCB `xcb_connection_t` connected to the X server.
    connection: rawptr,
    // X screen associated with the connection.
    screen:     int,
}

// A Wayland display handle.
Wayland_Display_Handle :: struct {
    // Pointer to the Wayland `wl_display` representing the connection to the
    // Wayland compositor.
    display: rawptr,
}

// An HTML canvas handle.
HTML_Canvas_Handle :: struct {
    // CSS selector identifying the HTML `<canvas>` element.
    selector: string,
}

// A native display handle.
//
// Identifies the native display or platform connection associated with the
// instance.
Native_Display_Handle :: union {
    Xlib_Display_Handle,
    Xcb_Display_Handle,
    Wayland_Display_Handle,
    HTML_Canvas_Handle,
}

// Options for creating an instance.
Instance_Descriptor :: struct {
    // Which backends to enable.
    backends:                 Backends,
    // Flags to tune the behavior of the instance.
    flags:                    Instance_Flags,
    // Memory budget thresholds used by some backends.
    memory_budget_thresholds: Memory_Budget_Thresholds,
    // Options for configuring the behavior of specific backends.
    backend_options:          Backend_Options,
    // System platform or compositor connection to connect this `Instance` to.
    display:                  Native_Display_Handle,
}

// Additional information required when requesting an adapter.
//
// For use with `instance_request_adapter`.
//
// Corresponds to [WebGPU `GPURequestAdapterOptions`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurequestadapteroptions).
Request_Adapter_Options :: struct {
    // The feature level to request (`Compatibility` or `Core`).
    // Defaults to `Core` when left unspecified.
    feature_level:          Feature_Level,
    // Power preference for the adapter.
    power_preference:       Power_Preference,
    // Indicates that only a fallback adapter can be returned. This is generally
    // a “software” implementation on the system.
    force_fallback_adapter: bool,
    // Optional backend type filter. When set to a specific backend, only
    // adapters of that backend will be considered.
    backend_type:           Backend_Type,
    // Surface that is required to be presentable with the requested adapter.
    // This does not create the surface, only guarantees that the adapter can
    // present to said surface. For WebGL, this is strictly required, as an
    // adapter can not be created without a surface.
    compatible_surface:     Surface,
}

DEFAULT_REQUEST_ADAPTER_OPTIONS :: Request_Adapter_Options {
    feature_level          = .Core,
    power_preference       = .None,
    force_fallback_adapter = false,
    backend_type           = .Undefined,
    compatible_surface     = {},
}

// Specifies the requested feature level when requesting a GPU adapter.
//
// Used in the `feature_level` field of `Request_Adapter_Options`.
Feature_Level :: enum i32 {
    // Requests the "Core" profile. This is the full standard WebGPU feature set
    // that requires modern graphics APIs such as Vulkan, Metal, or Direct3D 12
    // (at least).
    Core,
    // Requests the "Compatibility" profile. This is a reduced feature set that
    // can be supported on older graphics APIs such as OpenGL ES 3.1 and
    // Direct3D 11.
    Compatibility,
}

// Optional features that can be requested when creating a `Instance` (via
// `Instance_Descriptor.required_features`).
//
// These control instance-level capabilities that are not part of the core WebGPU.
Instance_Feature_Name :: enum i32 {
    // Enable use of `instance_wait_any` with `timeout_ns > 0`.
    Timed_Wait_Any,
    // Enables passing SPIR-V shader code to `device_create_shader_module`.
    Shader_Source_SPIRV,
    // Allows a single `Adapter` to create multiple devices. By default an
    // adapter can only create one device and then expires; with this feature
    // enabled the adapter remains usable for creating additional devices (it
    // may still expire for other reasons).
    Multiple_Devices_Per_Adapter,
}

INSTANCE_FEATURE_COUNT :: len(Instance_Feature_Name)

Instance_Features :: [dynamic;INSTANCE_FEATURE_COUNT]Instance_Feature_Name

Registry_Report :: struct {
    num_allocated:          uint,
    num_kept_from_user:     uint,
    num_released_from_user: uint,
    element_size:           uint,
}

Hub_Report :: struct {
    adapters:           Registry_Report,
    devices:            Registry_Report,
    queues:             Registry_Report,
    pipeline_layouts:   Registry_Report,
    shader_modules:     Registry_Report,
    bind_group_layouts: Registry_Report,
    bind_groups:        Registry_Report,
    command_buffers:    Registry_Report,
    render_bundles:     Registry_Report,
    render_pipelines:   Registry_Report,
    compute_pipelines:  Registry_Report,
    pipeline_caches:    Registry_Report,
    query_sets:         Registry_Report,
    buffers:            Registry_Report,
    textures:           Registry_Report,
    texture_views:      Registry_Report,
    samplers:           Registry_Report,
}

Global_Report :: struct {
    surfaces: Registry_Report,
    hub:      Hub_Report,
}

Supported_Instance_Features :: struct {
    features: []Instance_Feature_Name,
}

Supported_WGSL_Language_Features :: struct {
    features: []WGSL_Language_Feature_Name,
}

// Limits that can be requested or queried for a `Instance`.
Instance_Limits :: struct {
    // Maximum number of `Future`s that may be passed to a single
    // `instance_wait_any` call when `timeout_ns > 0` (a timed wait).
    //
    // Requires the `Timed_Wait_Any` instance feature to be enabled. A value of
    // `0` means the limit is not requested / not supported.
    timed_wait_any_max_count: uint,
}

Instance_Enumerate_Adapter_Options :: struct {
    backends: Backends,
}

when ODIN_OS == .JS {
    SUPPORTED_BACKENDS :: Backends{.BrowserWebGPU, .GL}
} else when ODIN_OS == .Windows {
    SUPPORTED_BACKENDS :: Backends{.DX12, .DX11, .Vulkan, .GL}
} else when ODIN_OS == .Linux {
    SUPPORTED_BACKENDS :: Backends{.Vulkan, .GL}
} else when ODIN_OS == .Darwin {
    SUPPORTED_BACKENDS :: Backends{.Metal, .Vulkan, .GL}
} else {
    #panic("Unsupported platform")
}

DEFAULT_BACKEND :: #config(GPU_DEFAULT_BACKEND, "")

// Creates a new GPU instance.
//
// Inputs:
//
// - `allocator`: Allocator used for internal API allocations.
// - `descriptor`: Describes the instance options and enabled backends.
//
// Returns: A new `Instance`, or `nil` if creation fails.
@(require_results)
create_instance :: proc(
    allocator: runtime.Allocator,
    descriptor: Instance_Descriptor = {},
    loc := #caller_location,
) -> Instance {
    backends := SUPPORTED_BACKENDS

    if DEFAULT_BACKEND != "" {
        if backend, ok := reflect.enum_from_name(Backend, DEFAULT_BACKEND); ok {
            backends = {backend}
        } else {
            log.warnf(
                "Invalid GPU_DEFAULT_BACKEND value: %q\n\t" +
                "Expected a case-sensitive name from [Backend] (e.g. Vulkan).\n\t" +
                "Defaulting to supported backends...",
                backend,
            )
        }
    }

    when ODIN_OS == .JS {
        if .BrowserWebGPU in backends {
            // First check if WebGPU is supported
            if instance := webgpu_create_instance(allocator, descriptor, loc); instance != nil {
                return instance
            }
        }
        if .GL in backends {
            // TODO
            unimplemented()
        }
        return nil
    } else {
        // TODO: currently default for native
        return vk_create_instance(allocator, descriptor, loc)
    }
}

// Sink for backend diagnostics (currently Vulkan validation-layer messages).
// While this is nil those messages keep flowing through `log.*`, which is
// filtered by `context.logger`. Installing a callback diverts them to the
// callback instead, and diverting is all it does: `context.logger` remains the
// authority for every `log.*` call in the package.
@private
g_log_callback: Log_Callback
@private
g_log_callback_userdata: rawptr

// Minimum severity for messages routed to `g_log_callback`. It gates only the
// callback path -- it never suppresses, widens or overrides the
// `context.logger` level that `log.*` output is filtered by.
//
// Like `log.Level`, `Log_Level` is ordered least-verbose-first, so a message is
// emitted when its level compares `<=` this value.
@private
g_log_level: Log_Level = .Info

set_log_callback :: proc(callback: Log_Callback, userdata: rawptr, loc := #caller_location) {
    g_log_callback = callback
    g_log_callback_userdata = userdata
}

set_log_level :: proc(level: Log_Level, loc := #caller_location) {
    g_log_level = level
}

get_version :: proc(loc := #caller_location) -> u32 {
    return 0
}

get_instance_features: proc(loc := #caller_location) -> Instance_Features

get_instance_limits: proc(loc := #caller_location) -> Instance_Limits

has_instance_feature: proc(feature: Instance_Feature_Name, loc := #caller_location) -> bool

generate_report: proc(instance: Instance, loc := #caller_location) -> Global_Report

instance_enumerate_adapters: proc(
    instance: Instance,
    options: Instance_Enumerate_Adapter_Options,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Adapter

instance_create_surface: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface

instance_get_wgsl_language_features: proc(
    instance: Instance,
    loc := #caller_location,
) -> Supported_WGSL_Language_Features

instance_has_wgsl_language_feature: proc(
    instance: Instance,
    feature: WGSL_Language_Feature_Name,
    loc := #caller_location,
) -> bool

instance_process_events: proc(instance: Instance, loc := #caller_location)

instance_create_adapter: proc(
    instance: Instance,
    options: Request_Adapter_Options = {},
    loc := #caller_location,
) -> Adapter

instance_wait_any: proc(
    instance: Instance,
    futures: []^Future_Wait_Info = {},
    timeout_ns: u64 = max(u64),
    loc := #caller_location,
) -> Wait_Status

supported_instance_features_free_members: proc(
    features: []Instance_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
)
supported_wgsl_language_features_free_members: proc(
    features: []WGSL_Language_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
)

// Get the current active backend.
instance_backend :: proc(instance: Instance, loc := #caller_location) -> Backend_Type {
    impl := instance_get_public_impl(instance, loc)
    return impl.backend
}

// Check for embedded backend.
instance_is_embedded :: proc(instance: Instance, loc := #caller_location) -> bool {
    impl := instance_get_public_impl(instance, loc)
    return impl.is_embedded
}

instance_add_ref: proc(instance: Instance, loc := #caller_location)

instance_release: proc(instance: Instance, loc := #caller_location)

