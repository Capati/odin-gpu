package gpu

// Core
import "base:runtime"
import "core:log"

// Context for all other GPU objects.
//
// This is the first thing you create when using GPU. Its primary use is to
// create `Adapter`s and `Surface`s.
Instance :: distinct rawptr

// The instance base object for all implementations.
Instance_Base :: struct {
    // Base
    using base:     Handle_Base,
    // The Odin context when the instance was created.
    ctx:            runtime.Context,
    flags:          Instance_Flags,
    backend:        Backend,
    // Types of shader model supported by the current backend
    shader_formats: Shader_Formats,
}

// Backends supported by the GPU.
Backend :: enum i32 {
    Null,
    Vulkan,
    Metal,
    Dx11,
    Dx12,
    Gl,
    WebGPU,
}

// Represents the backends that the GPU will use.
Backends :: bit_set[Backend;Flags]

// All supported apis.
BACKENDS_ALL :: Backends{.Vulkan, .Metal, .Dx11, .Dx12, .WebGPU, .Gl}

// All the apis that the GPU offers first tier of support for.
BACKENDS_PRIMARY :: Backends{.Vulkan, .Metal, .Dx12, .WebGPU}

// All the apis that the GPU offers second tier of support for. These may be
// unsupported/still experimental.
BACKENDS_SECONDARY :: Backends{.Dx11, .Gl}

// Instance debugging flags.
Instance_Flags :: bit_set[Instance_Flag;Flags]
Instance_Flag :: enum i32 {
    Debug,
    Validation,
}

INSTANCE_FLAGS_DEFAULT :: Instance_Flags{}

// Configuration for the OpenGL/OpenGLES backend.
//
// Part of `Backend_Options`.
Gl_Backend_Options :: struct {
    major_version: i32,
    minor_version: i32,
    core_profile:  bool,
}

// The Fxc compiler (default) is old, slow and unmaintained.
//
// However, it doesn’t require any additional .dlls to be shipped with the application.
Dx12_Compiler_Fxc :: struct {}

// DXC shader model.
Dxc_Shader_Model :: enum i32 {
    V6_0, V6_1, V6_2, V6_3, V6_4, V6_5, V6_6, V6_7,
}

// The Dxc compiler is new, fast and maintained.
//
// However, it requires `dxcompiler.dll` to be shipped with the application.
// These files can be downloaded from
// [Microsoft](https://github.com/microsoft/DirectXShaderCompiler/releases).
//
// Minimum supported version:
// [v1.8.2502](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2502)
//
// It also requires WDDM 2.1 (Windows 10 version 1607).
Dx12_Compiler_Dxc :: struct {
    dxc_path:         string,
    max_shader_model: Dxc_Shader_Model,
}

// Selects which DX12 shader compiler to use.
Dx12_Compiler :: union {
    Dx12_Compiler_Fxc,
    Dx12_Compiler_Dxc,
}

// Configuration for the Dx12 backend.
//
// Part of `Backend_Options`.
Dx12_Backend_Options :: struct {
    shader_compiler: Dx12_Compiler,
}

// Configuration for the Vulkan backend.
//
// Part of `Backend_Options`.
Vulkan_Backend_Options :: struct {
    fp_get_instance_proc_addr: rawptr,
}

// Options that are passed to a given backend.
Backend_Options :: struct {
    gl:     Gl_Backend_Options,
    dx12:   Dx12_Backend_Options,
    vulkan: Vulkan_Backend_Options,
}

// Options for creating an instance.
Instance_Descriptor :: struct {
    label:           string,
    backends:        Backends,
    flags:           Instance_Flags,
    backend_options: Backend_Options,
    headless:        bool,
}

INSTANCE_DESCRIPTOR_DEFAULT :: Instance_Descriptor {
    backends = BACKENDS_PRIMARY,
    flags    = INSTANCE_FLAGS_DEFAULT,
}

when ODIN_OS == .JS {
    GPU_PLATFORM_BACKENDS :: Backends{ .WebGPU }
} else when ODIN_OS == .Windows {
    GPU_PLATFORM_BACKENDS :: Backends{ .Dx12, .Dx11, .Vulkan, .Gl }
} else when ODIN_OS == .Linux {
    GPU_PLATFORM_BACKENDS :: Backends{ .Vulkan, .Gl }
} else when ODIN_OS == .Darwin {
    GPU_PLATFORM_BACKENDS :: Backends{ .Metal, .Vulkan } // Vulkan with MontenVK
} else {
    GPU_PLATFORM_BACKENDS :: Backends{ .Gl }
}

GPU_BACKEND_TYPE_STR :: #config(GPU_BACKEND_TYPE, "")

// Initialize the GPU context and create a new GPU instance.
@(require_results)
create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> Instance {
    desc := descriptor.? or_else INSTANCE_DESCRIPTOR_DEFAULT

    // Try to read the config to see if a backend type should be used
    when GPU_BACKEND_TYPE_STR != "" {
        backends := Backends{}
        {
            backend, backend_ok := reflect.enum_from_name(Backend, GPU_BACKEND_TYPE_STR)
            if backend_ok {
                backends = { backend }
                log.warnf("Backend type selected with [GPU_BACKEND_TYPE_STR]: %v", backend)
            } else {
                log.errorf(
                    "Backend type %v is invalid, " +
                    "possible values are from [Backends] (case sensitive): " +
                    "\n\tVulkan,\n\tMetal,\n\tDx11,\n\tDX12,\n\tGl,\n\tWebGPU",
                    GPU_BACKEND_TYPE_STR,
                    location = loc,
                )
                return nil
            }
        }
    } else {
        backends := desc.backends if desc.backends != {} else BACKENDS_ALL
    }

    requested_backends := backends & GPU_PLATFORM_BACKENDS
    if requested_backends == {} {
        log.error("No supported backends requested for this platform", location = loc)
        return nil
    }

    backend: Backend
    shader_formats: Shader_Formats

    when ODIN_OS == .JS {
        if .WebGPU in requested_backends {
            wgpu_init(allocator)
            backend = .WebGPU
            shader_formats = { .Wgsl }
        }
    } else when ODIN_OS == .Windows {
        // TODO: Dx12 should be the priority
        requested_backends -= { .Dx12 }
        if .Dx12 in requested_backends {
            // d3d12_init(allocator)
            // backend = .Dx12
            // shader_formats = { .Dxil, .Dxbc }
        } else if .Vulkan in requested_backends {
            vk_init(allocator)
            backend = .Vulkan
            shader_formats = { .Spirv }
        } else if .Dx11 in requested_backends {
            d3d11_init(allocator)
            backend = .Dx11
            shader_formats = { .Dxbc }
        } else if .Gl in requested_backends {
            gl_init(allocator)
            backend = .Gl
            shader_formats = { .Glsl }
        }
    } else when ODIN_OS == .Linux {
        if .Vulkan in requested_backends {
            vk_init(allocator)
            backend = .Vulkan
            shader_formats = { .Spirv }
        } else if .Gl in requested_backends {
            gl_init(allocator)
            backend = .Gl
            shader_formats = { .Glsl }
        }
    } else when ODIN_OS == .Darwin {
        // TODO: Metal should be the priority
        requested_backends -= { .Metal }
        if .Metal in requested_backends {
            // metal_init(allocator)
            // backend = .Metal
            // shader_formats = {.Msl, .Metallib}
        } else if .Vulkan in requested_backends {
            vk_init(allocator)
            backend = .Vulkan
            shader_formats = { .Spirv }
        }
    } else {
        unimplemented("Unsupported platform!")
    }

    assert(backend != .Null)

    // Ensure procedures pointer are valid
    check_interface_procedures()

    instance := create_instance_impl(desc, allocator, loc)

    instance_impl := cast(^Instance_Base)instance
    instance_impl.backend = backend
    instance_impl.shader_formats = shader_formats

    return instance
}

// Describes an Android Native Window.
Surface_Source_Android_Native_Window :: struct {
    window: rawptr,
}

// Describes a Canvas HTML selector.
Surface_Source_Canvas_HTML_Selector :: struct {
    selector: string,
}

// Describes a Metal Layer.
Surface_Source_Metal_Layer :: struct {
    layer: rawptr,
}

// Describes a Wayland Surface.
Surface_Source_Wayland_Surface :: struct {
    display: rawptr,
    surface: rawptr,
}

// Describes a Window HWND.
Surface_Source_Windows_HWND :: struct {
    hinstance: rawptr,
    hwnd:      rawptr,
}

// Describes a Xcb Window.
Surface_Source_Xcb_Window :: struct {
    connection: rawptr,
    window:     u32,
}

// Describes a Xlib Window.
Surface_Source_Xlib_Window :: struct {
    display: rawptr,
    window:  u64,
}

// Describes a surface target.
Surface_Descriptor :: struct {
    label:  string,
    target: union {
        Surface_Source_Android_Native_Window,
        Surface_Source_Canvas_HTML_Selector,
        Surface_Source_Metal_Layer,
        Surface_Source_Wayland_Surface,
        Surface_Source_Windows_HWND,
        Surface_Source_Xcb_Window,
        Surface_Source_Xlib_Window,
        // SurfaceSourceSwapChainPanel,
    },
}

// Creates a surface from a target.
Proc_Instance_Create_Surface :: #type proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface
instance_create_surface: Proc_Instance_Create_Surface

Request_Adapter_Status :: enum i32 {
    Success = 1,
    Instance_Dropped,
    Unavailable,
    Error,
    Unknown,
}

Request_Adapter_Callback :: #type proc "c" (
    status: Request_Adapter_Status,
    adapter: Adapter,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Request_Adapter_Callback_Info :: struct {
    callback:  Request_Adapter_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Power Preference when choosing a physical adapter.
Power_Preference :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // Adapter that uses the least possible power. This is often an integrated GPU.
    Low_Power,
    // Adapter that has the highest performance. This is often a discrete GPU.
    High_Performance,
}

// Options for requesting adapter.
Request_Adapter_Options :: struct {
    // Power preference for the adapter.
    power_preference:       Power_Preference,
    // Indicates that only a fallback adapter can be returned. This is generally
    // a "software" implementation on the system.
    force_fallback_adapter: bool,
    // Surface that is required to be presentable with the requested adapter.
    // This does not create the surface, only guarantees that the adapter can
    // present to said surface. For WebGL, this is strictly required, as an
    // adapter can not be created without a surface.
    compatible_surface:     Surface,
}

REQUEST_ADAPTER_OPTIONS_DEFAULT :: Request_Adapter_Options {
    power_preference       = .High_Performance,
    force_fallback_adapter = false,
    compatible_surface     = nil,
}

// Retrieves an `Adapter` which matches the given `Request_Adapter_Options`.
//
// Some options are "soft", so treated as non-mandatory. Others are "hard".
//
// If no adapters are found that suffice all the "hard" options, `nil` is returned.
Proc_Instance_Request_Adapter :: #type proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
)
instance_request_adapter: Proc_Instance_Request_Adapter

// Retrieves all available `Adapters` for the current backend.
Proc_Instance_Enumarate_Adapters :: #type proc(
    instance: Instance,
    allocator := context.allocator,
    loc := #caller_location,
) -> []Adapter
instance_enumarate_adapters: Proc_Instance_Enumarate_Adapters

// Get the current backend.
instance_get_backend :: proc(instance: Instance, loc := #caller_location) -> Backend {
    impl := get_impl(Instance_Base, instance, loc)
    return impl.backend
}

// Get the shader formats that is compatible for the current backend.
instance_get_backend_shader_formats :: proc(instance: Instance, loc := #caller_location) -> Shader_Formats {
    impl := get_impl(Instance_Base, instance, loc)
    return impl.shader_formats
}

// Get the `Instance` debug label.
Proc_Instance_Get_Label :: #type proc(instance: Instance, loc := #caller_location) -> string
instance_get_label: Proc_Instance_Get_Label

// Set the `Instance` debug label.
Proc_Instance_Set_Label :: #type proc(instance: Instance, label: string, loc := #caller_location)
instance_set_label: Proc_Instance_Set_Label

// Increase the `Instance` reference count.
Proc_Instance_Add_Ref :: #type proc(instance: Instance, loc := #caller_location)
instance_add_ref: Proc_Instance_Add_Ref

// Release the `Instance` resources, use to decrease the reference count.
Proc_Instance_Release :: #type proc(instance: Instance, loc := #caller_location)
instance_release: Proc_Instance_Release

@private
check_interface_procedures :: proc() {
    // Global procedures
    assert(create_instance_impl != nil)

    // // Adapter procedures
    // assert(adapter_get_info != nil)
    // assert(adapter_info_free_members != nil)
    // assert(adapter_get_features != nil)
    // assert(adapter_has_feature != nil)
    // assert(adapter_get_limits != nil)
    // assert(adapter_request_device != nil)
    // assert(adapter_get_texture_format_capabilities != nil)
    // assert(adapter_get_label != nil)
    // assert(adapter_set_label != nil)
    // assert(adapter_add_ref != nil)
    // assert(adapter_release != nil)

    // // Bind Group procedures
    // assert(bind_group_get_label != nil)
    // assert(bind_group_set_label != nil)
    // assert(bind_group_add_ref != nil)
    // assert(bind_group_release != nil)

    // // Bind Group Layout procedures
    // assert(bind_group_layout_get_label != nil)
    // assert(bind_group_layout_set_label != nil)
    // assert(bind_group_layout_add_ref != nil)
    // assert(bind_group_layout_release != nil)

    // // Buffer procedures
    // assert(buffer_destroy != nil)
    // assert(buffer_get_const_mapped_range != nil)
    // assert(buffer_get_map_state != nil)
    // assert(buffer_get_mapped_range != nil)
    // assert(buffer_get_size != nil)
    // assert(buffer_get_usage != nil)
    // assert(buffer_map_async != nil)
    // assert(buffer_unmap != nil)
    // assert(buffer_get_label != nil)
    // assert(buffer_set_label != nil)
    // assert(buffer_add_ref != nil)
    // assert(buffer_release != nil)

    // // Command Buffer procedures
    // assert(command_buffer_get_label != nil)
    // assert(command_buffer_set_label != nil)
    // assert(command_buffer_add_ref != nil)
    // assert(command_buffer_release != nil)

    // Command Encoder procedures
    // assert(command_encoder_begin_compute_pass != nil)
    // assert(command_encoder_begin_render_pass != nil)
    // assert(command_encoder_copy_buffer_to_buffer != nil)
    // assert(command_encoder_copy_buffer_to_texture != nil)
    // assert(command_encoder_copy_texture_to_buffer != nil)
    // assert(command_encoder_copy_texture_to_texture != nil)
    // assert(command_encoder_clear_buffer != nil)
    // assert(command_encoder_resolve_query_set != nil)
    // assert(command_encoder_write_timestamp != nil)
    // assert(command_encoder_finish != nil)
    // assert(command_encoder_get_label != nil)
    // assert(command_encoder_set_label != nil)
    // assert(command_encoder_add_ref != nil)
    // assert(command_encoder_release != nil)

    // // Compute Pass Encoder procedures
    // assert(compute_pass_dispatch_workgroups != nil)
    // assert(compute_pass_dispatch_workgroups_indirect != nil)
    // assert(compute_pass_end != nil)
    // assert(compute_pass_insert_debug_marker != nil)
    // assert(compute_pass_pop_debug_group != nil)
    // assert(compute_pass_push_debug_group != nil)
    // assert(compute_pass_set_bind_group != nil)
    // assert(compute_pass_set_label != nil)
    // assert(compute_pass_set_pipeline != nil)
    // assert(compute_pass_add_ref != nil)
    // assert(compute_pass_release != nil)
    // assert(compute_pass_get_label != nil)
    // assert(compute_pass_set_label != nil)
    // assert(compute_pass_add_ref != nil)
    // assert(compute_pass_release != nil)

    // // Compute Pipeline procedures
    // assert(compute_pipeline_get_bind_group_layout != nil)
    // assert(compute_pipeline_get_label != nil)
    // assert(compute_pipeline_set_label != nil)
    // assert(compute_pipeline_add_ref != nil)
    // assert(compute_pipeline_release != nil)

    // TODO: remain api
}
