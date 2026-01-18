#+build !js
package gpu

// Core
import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:sync"
import sa "core:container/small_array"

// Local packages
import "libs/vma"

// Vendor
import vk "vendor:vulkan"

// Required Vulkan version
VK_API_VERSION :: vk.API_VERSION_1_3

vk_init :: proc(allocator := context.allocator) {
    // Global procedures
    create_instance_impl              = vk_create_instance

    // Adapter procedures
    adapter_get_info                  = vk_adapter_get_info
    adapter_info_free_members         = vk_adapter_info_free_members
    adapter_get_features              = vk_adapter_get_features
    adapter_get_limits                = vk_adapter_get_limits
    adapter_request_device            = vk_adapter_request_device
    adapter_get_label                 = vk_adapter_get_label
    adapter_set_label                 = vk_adapter_set_label
    adapter_add_ref                   = vk_adapter_add_ref
    adapter_release                   = vk_adapter_release

    // Bind Group procedures
    bind_group_get_label              = vk_bind_group_get_label
    bind_group_set_label              = vk_bind_group_set_label
    bind_group_add_ref                = vk_bind_group_add_ref
    bind_group_release                = vk_bind_group_release

    // Bind Group Layout procedures
    bind_group_layout_get_label       = vk_bind_group_layout_get_label
    bind_group_layout_set_label       = vk_bind_group_layout_set_label
    bind_group_layout_add_ref         = vk_bind_group_layout_add_ref
    bind_group_layout_release         = vk_bind_group_layout_release

    // Buffer procedures
    buffer_unmap                      = vk_buffer_unmap
    buffer_get_map_state              = vk_buffer_get_map_state
    buffer_get_size                   = vk_buffer_get_size
    buffer_get_usage                  = vk_buffer_get_usage
    buffer_get_label                  = vk_buffer_get_label
    buffer_set_label                  = vk_buffer_set_label
    buffer_add_ref                    = vk_buffer_add_ref
    buffer_release                    = vk_buffer_release

    // Command Buffer procedures
    command_buffer_get_label          = vk_command_buffer_get_label
    command_buffer_set_label          = vk_command_buffer_set_label
    command_buffer_add_ref            = vk_command_buffer_add_ref
    command_buffer_release            = vk_command_buffer_release

    // Command Encoder procedures
    command_encoder_begin_render_pass = vk_command_encoder_begin_render_pass
    command_encoder_finish            = vk_command_encoder_finish
    command_encoder_get_label         = vk_command_encoder_get_label
    command_encoder_set_label         = vk_command_encoder_set_label
    command_encoder_add_ref           = vk_command_encoder_add_ref
    command_encoder_release           = vk_command_encoder_release

    // Device procedures
    device_get_features               = vk_device_get_features
    device_get_limits                 = vk_device_get_limits
    device_create_bind_group          = vk_device_create_bind_group
    device_create_bind_group_layout   = vk_device_create_bind_group_layout
    device_create_buffer              = vk_device_create_buffer
    device_create_command_encoder     = vk_device_create_command_encoder
    device_create_pipeline_layout     = vk_device_create_pipeline_layout
    device_create_render_pipeline     = vk_device_create_render_pipeline
    device_create_sampler             = vk_device_create_sampler
    device_create_shader_module       = vk_device_create_shader_module
    device_create_texture             = vk_device_create_texture
    device_get_queue                  = vk_device_get_queue
    device_get_label                  = vk_device_get_label
    device_set_label                  = vk_device_set_label
    device_add_ref                    = vk_device_add_ref
    device_release                    = vk_device_release

    // Instance procedures
    instance_create_surface           = vk_instance_create_surface
    instance_request_adapter          = vk_instance_request_adapter
    instance_get_label                = vk_instance_get_label
    instance_set_label                = vk_instance_set_label
    instance_add_ref                  = vk_instance_add_ref
    instance_release                  = vk_instance_release

    // Queue procedures
    queue_submit                      = vk_queue_submit
    queue_write_buffer_impl           = vk_queue_write_buffer
    queue_write_texture               = vk_queue_write_texture
    queue_get_label                   = vk_queue_get_label
    queue_set_label                   = vk_queue_set_label
    queue_add_ref                     = vk_queue_add_ref
    queue_release                     = vk_queue_release

    // Render Pass procedures
    render_pass_draw                  = vk_render_pass_draw
    render_pass_draw_indexed          = vk_render_pass_draw_indexed
    render_pass_end                   = vk_render_pass_end
    render_pass_set_bind_group        = vk_render_pass_set_bind_group
    render_pass_set_index_buffer      = vk_render_pass_set_index_buffer
    render_pass_set_pipeline          = vk_render_pass_set_pipeline
    render_pass_set_scissor_rect      = vk_render_pass_set_scissor_rect
    render_pass_set_stencil_reference = vk_render_pass_set_stencil_reference
    render_pass_set_vertex_buffer     = vk_render_pass_set_vertex_buffer
    render_pass_set_viewport          = vk_render_pass_set_viewport
    render_pass_get_label             = vk_render_pass_get_label
    render_pass_set_label             = vk_render_pass_set_label
    render_pass_add_ref               = vk_render_pass_add_ref
    render_pass_release               = vk_render_pass_release

    // Render Pipeline procedures
    render_pipeline_get_label         = vk_render_pipeline_get_label
    render_pipeline_set_label         = vk_render_pipeline_set_label
    render_pipeline_add_ref           = vk_render_pipeline_add_ref
    render_pipeline_release           = vk_render_pipeline_release

    // Pipeline Layout procedures
    pipeline_layout_get_label         = vk_pipeline_layout_get_label
    pipeline_layout_set_label         = vk_pipeline_layout_set_label
    pipeline_layout_add_ref           = vk_pipeline_layout_add_ref
    pipeline_layout_release           = vk_pipeline_layout_release

    // Sampler procedures
    sampler_get_label                 = vk_sampler_get_label
    sampler_set_label                 = vk_sampler_set_label
    sampler_add_ref                   = vk_sampler_add_ref
    sampler_release                   = vk_sampler_release

    // Shader Module procedures
    shader_module_get_label           = vk_shader_module_get_label
    shader_module_set_label           = vk_shader_module_set_label
    shader_module_add_ref             = vk_shader_module_add_ref
    shader_module_release             = vk_shader_module_release

    // Surface procedures
    surface_get_capabilities          = vk_surface_get_capabilities
    surface_capabilities_free_members = vk_surface_capabilities_free_members
    surface_configure                 = vk_surface_configure
    surface_get_current_texture       = vk_surface_get_current_texture
    surface_present                   = vk_surface_present
    surface_get_label                 = vk_surface_get_label
    surface_set_label                 = vk_surface_set_label
    surface_add_ref                   = vk_surface_add_ref
    surface_release                   = vk_surface_release

    // Texture procedures
    texture_create_view_impl                = vk_texture_create_view
    texture_get_descriptor                  = vk_texture_get_descriptor
    texture_get_dimension                   = vk_texture_get_dimension
    texture_get_format                      = vk_texture_get_format
    texture_get_height                      = vk_texture_get_height
    texture_get_mip_level_count             = vk_texture_get_mip_level_count
    texture_get_sample_count                = vk_texture_get_sample_count
    texture_get_size                        = vk_texture_get_size
    texture_get_usage                       = vk_texture_get_usage
    texture_get_width                       = vk_texture_get_width
    texture_get_label                       = vk_texture_get_label
    texture_set_label                       = vk_texture_set_label
    texture_add_ref                         = vk_texture_add_ref
    texture_release                         = vk_texture_release

    // Texture View procedures
    texture_view_get_label            = vk_texture_view_get_label
    texture_view_set_label            = vk_texture_view_set_label
    texture_view_add_ref              = vk_texture_view_add_ref
    texture_view_release              = vk_texture_view_release
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------


// VK_LAYER_KHRONOS_validation
VK_VALIDATION_LAYER_NAME :: "VK_LAYER_KHRONOS_validation"

Vulkan_Library :: struct {
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr,
    library:                dynlib.Library,
    did_load:               bool,
    init_mutex:             sync.Mutex,
}

@(require_results)
vk_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    instance: Instance,
) {
    desc := descriptor.? or_else {}

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    lib: Vulkan_Library

    // Check if user provided a custom proc addr
    fp_get_instance_proc_addr := desc.backend_options.vulkan.fp_get_instance_proc_addr
    if fp_get_instance_proc_addr != nil {
        lib.get_instance_proc_addr = auto_cast fp_get_instance_proc_addr
    }

    // Otherwise, load the Vulkan library...
    if lib.get_instance_proc_addr == nil {
        library: dynlib.Library
        did_load: bool

        when ODIN_OS == .Windows {
            library, did_load = dynlib.load_library("vulkan-1.dll")
        } else when ODIN_OS == .Darwin {
            library, did_load = dynlib.load_library("libvulkan.dylib")

            if !did_load { library, did_load = dynlib.load_library("libvulkan.1.dylib") }

            // Modern versions of macOS don't search /usr/local/lib
            // automatically contrary to what man dlopen says Vulkan SDK uses
            // this as the system-wide installation location, so we're going to
            // fallback to this if all else fails
            if !did_load {
                _, found_lib_path := os.lookup_env("DYLD_FALLBACK_LIBRARY_PATH", ta)
                if !found_lib_path {
                    library, did_load = dynlib.load_library("/usr/local/lib/libvulkan.dylib")
                }
            }

            if !did_load { library, did_load = dynlib.load_library("libMoltenVK.dylib") }

            // Add support for using Vulkan and MoltenVK in a Framework. App
            // store rules for iOS strictly enforce no .dylib's. If they aren't
            // found it just falls through
            if !did_load { library, did_load = dynlib.load_library("vulkan.framework/vulkan") }
            if !did_load { library, did_load = dynlib.load_library("MoltenVK.framework/MoltenVK") }
        } else {
            library, did_load = dynlib.load_library("libvulkan.so.1")
            if !did_load { library, did_load = dynlib.load_library("libvulkan.so") }
        }

        ensure(did_load && library != nil, "Failed to load Vulkan library", loc)

        fp, fp_found := dynlib.symbol_address(library, "vkGetInstanceProcAddr")
        ensure(fp_found, "Failed to load Vulkan library", loc)

        lib.get_instance_proc_addr = auto_cast fp
        lib.library = library
        lib.did_load = true
    }

    // Load the base Vulkan procedures before we can start using them
    vk.load_proc_addresses_global(auto_cast lib.get_instance_proc_addr)
    ensure(vk.CreateInstance != nil, "Failed to load Vulkan proc addresses", loc)

    // Create the instance impl
    impl := instance_new_impl(Vulkan_Instance_Impl, allocator, loc)

    impl.lib = lib
    impl.backend = .Vulkan
    impl.shader_formats = { .Spirv }

    layer_count: u32
    vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, nil))
    available_layers := make([]vk.LayerProperties, layer_count, ta)
    vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(available_layers)))

    validation_layers_available: bool
    for &layer in available_layers {
        layer_name := byte_arr_str(&layer.layerName)
        if layer_name == VK_VALIDATION_LAYER_NAME {
            validation_layers_available = true
            break
        }
    }

    extension_count: u32
    vk_check(vk.EnumerateInstanceExtensionProperties(nil, &extension_count, nil))
    available_extensions := make([]vk.ExtensionProperties, extension_count, ta)
    vk_check(vk.EnumerateInstanceExtensionProperties(
        nil, &extension_count, raw_data(available_extensions)))

    debug_utils_available: bool
    for &ext in available_extensions {
        ext_name := byte_arr_str(&ext.extensionName)
        if ext_name == vk.EXT_DEBUG_UTILS_EXTENSION_NAME {
            debug_utils_available = true
            break
        }
    }

    is_extension_available :: proc(
        available_extensions: []vk.ExtensionProperties,
        required: string,
    ) -> bool {
        for &available in available_extensions {
            ext_name := byte_arr_str(&available.extensionName)
            if ext_name == required { return true }
        }
        return false
    }

    // Query current instance version
    instance_api_version : u32 = vk.API_VERSION_1_0
    // Instance implementation may be too old to support EnumerateInstanceVersion. We need
    // to check the function pointer before calling it, if the function doesn't exist,
    // then the instance version must be 1.0.
    if vk.EnumerateInstanceVersion != nil {
        res := vk.EnumerateInstanceVersion(&instance_api_version)
        if res != .SUCCESS {
            instance_api_version = vk.API_VERSION_1_0
        }
    }

    ensure(instance_api_version >= VK_API_VERSION, "Vulkan version not available", loc)

    // If validation was requested and layers are NOT available, silently
    // disable validation flags, this also disables debug messenger
    if .Validation in desc.flags && !validation_layers_available {
        desc.flags -= { .Validation }
    }

    // Extensions names to enable
    extensions: sa.Small_Array(8, cstring)

    if .Validation in desc.flags && debug_utils_available {
        sa.push_back(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    when ODIN_OS == .Darwin {
        portability_enumeration_support: bool
        if is_extension_available(
            available_extensions,
            vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME,
        ) {
            portability_enumeration_support = true
            sa.push_back(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
        }
    }

    // Add required surface extensions
    if !desc.headless {
        sa.push_back(&extensions, vk.KHR_SURFACE_EXTENSION_NAME)
        when ODIN_OS == .Windows {
            sa.push_back(&extensions, vk.KHR_WIN32_SURFACE_EXTENSION_NAME)
        } else when ODIN_OS == .Linux {
            sa.push_back(&extensions, vk.KHR_XCB_SURFACE_EXTENSION_NAME)
            sa.push_back(&extensions, vk.KHR_XLIB_SURFACE_EXTENSION_NAME)
            sa.push_back(&extensions, vk.KHR_WAYLAND_SURFACE_EXTENSION_NAME)
        } else when ODIN_OS == Darwin {
            sa.push_back(&extensions, vk.EXT_METAL_SURFACE_EXTENSION_NAME)
        }
    } else {
        sa.push_back(&extensions, vk.EXT_HEADLESS_SURFACE_EXTENSION_NAME)
    }

    // Optional instance extensions for enhanced swapchain functionality
    if is_extension_available(available_extensions, vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME) {
        impl.swapchain_colorspace = true
        sa.push_back(&extensions, vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME)
    }

    // Required for the device extension VK_EXT_swapchain_maintenance1
    if is_extension_available(available_extensions, vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME) {
        sa.push_back(&extensions, vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME)
    }

    // Required dependency for VK_EXT_surface_maintenance1
    if is_extension_available(available_extensions, vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME) {
        sa.push_back(&extensions, vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME)
    }

    // Layer names to enable
    layers: sa.Small_Array(1, cstring)

    if .Validation in desc.flags {
        sa.push_back(&layers, VK_VALIDATION_LAYER_NAME)
    }

    pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

    // Setup instance debug utils
    messenger_create_info: vk.DebugUtilsMessengerCreateInfoEXT
    if .Validation in desc.flags && debug_utils_available {
        messenger_create_info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
        messenger_create_info.messageSeverity = { .WARNING, .ERROR }
        messenger_create_info.messageType = { .GENERAL, .VALIDATION, .PERFORMANCE }
        messenger_create_info.pfnUserCallback = vk_default_debug_callback
        messenger_create_info.pUserData = impl

        append(&pnext_chain, cast(^vk.BaseOutStructure)&messenger_create_info)
    }

    app_info := vk.ApplicationInfo {
        sType              = .APPLICATION_INFO,
        pApplicationName   = "Odin/GPU",
        engineVersion      = vk.MAKE_VERSION(1, 0, 0),
        pEngineName        = "Odin/GPU",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        apiVersion         = VK_API_VERSION,
    }

    instance_create_info := vk.InstanceCreateInfo {
        sType                   = .INSTANCE_CREATE_INFO,
        pApplicationInfo        = &app_info,
        enabledExtensionCount   = u32(sa.len(extensions)),
        ppEnabledExtensionNames = raw_data(sa.slice(&extensions)),
        enabledLayerCount       = u32(sa.len(layers)),
        ppEnabledLayerNames     = raw_data(sa.slice(&layers)),
    }

    when ODIN_OS == .Darwin {
        if portability_enumeration_support {
            instance_create_info.flags += { .ENUMERATE_PORTABILITY_KHR }
        }
    }

    vk_setup_pnext_chain(&instance_create_info, pnext_chain[:])

    vk_instance: vk.Instance
    vk_check(vk.CreateInstance(&instance_create_info, nil, &vk_instance))

    // Load the rest of the functions with our instance
    vk.load_proc_addresses(vk_instance)

    vk_debug_messenger: vk.DebugUtilsMessengerEXT
    if .Validation in desc.flags && debug_utils_available {
        debug_utils_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
            sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            messageSeverity = { .WARNING, .ERROR },
            messageType     = { .GENERAL, .VALIDATION, .PERFORMANCE },
            pfnUserCallback = vk_default_debug_callback,
            pUserData       = impl,
        }

        vk_check(vk.CreateDebugUtilsMessengerEXT(
            vk_instance,
            &debug_utils_create_info,
            nil,
            &vk_debug_messenger,
        ))
    }

    impl.vk_instance        = vk_instance
    impl.vk_debug_messenger = vk_debug_messenger
    impl.instance_version   = instance_api_version
    impl.api_version        = VK_API_VERSION
    impl.flags              = desc.flags
    impl.headless           = desc.headless

    return Instance(impl)
}

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


Vulkan_Adapter_Impl :: struct {
    // Base
    using base:         Adapter_Base,

    // Initialization
    vk_physical_device: vk.PhysicalDevice,
    features_10:        vk.PhysicalDeviceFeatures,
    features_11:        vk.PhysicalDeviceVulkan11Features,
    features_12:        vk.PhysicalDeviceVulkan12Features,
    features_13:        vk.PhysicalDeviceVulkan13Features,
}

@(require_results)
vk_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc: runtime.Source_Code_Location,
) -> (
    info: Adapter_Info,
) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)

    device_properties2 := vk.PhysicalDeviceProperties2 {
        sType = .PHYSICAL_DEVICE_PROPERTIES_2,
    }
    driver_properties := vk.PhysicalDeviceDriverProperties {
        sType = .PHYSICAL_DEVICE_DRIVER_PROPERTIES,
    }
    device_properties2.pNext = &driver_properties

    // Get properties
    vk.GetPhysicalDeviceProperties2(impl.vk_physical_device, &device_properties2)

    // Convert byte arrays to strings
    device_name := strings.string_from_null_terminated_ptr(
        &device_properties2.properties.deviceName[0],
        len(device_properties2.properties.deviceName),
    )
    if device_name != "" {
        info.name = strings.clone_from(device_name, allocator)
    }

    driver_name := strings.string_from_null_terminated_ptr(
        &driver_properties.driverName[0],
        len(driver_properties.driverName),
    )
    if driver_name != "" {
        info.driver = strings.clone_from(driver_name, allocator)
    }

    driver_info := strings.string_from_null_terminated_ptr(
        &driver_properties.driverInfo[0],
        len(driver_properties.driverInfo),
    )
    if driver_info != "" {
        info.driver_info = strings.clone_from(driver_info, allocator)
    }

    // Convert device type to our enum
    #partial switch device_properties2.properties.deviceType {
    case .INTEGRATED_GPU:
        info.device_type = .Integrated_Gpu
    case .DISCRETE_GPU:
        info.device_type = .Discrete_Gpu
    case .VIRTUAL_GPU, .CPU:
        info.device_type = .Cpu
    case:
        info.device_type = .Other
    }

    info.vendor = device_properties2.properties.vendorID
    info.device = device_properties2.properties.deviceID

    info.backend = .Vulkan

    return
}

vk_adapter_info_free_members :: proc(self: Adapter_Info, allocator := context.allocator) {
    context.allocator = allocator
    if len(self.name) > 0 do delete(self.name)
    if len(self.driver) > 0 do delete(self.driver)
    if len(self.driver_info) > 0 do delete(self.driver_info)
}

@private
vk_adapter_get_features_impl :: proc(impl: ^Vulkan_Adapter_Impl) -> (features: Features) {
    return
}

vk_adapter_get_features :: proc(adapter: Adapter, loc := #caller_location) -> (features: Features) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    return impl.features
}

@private
vk_adapter_get_limits_impl :: proc(impl: ^Vulkan_Adapter_Impl) -> (ret: Limits) {
    subgroup_props := vk.PhysicalDeviceSubgroupProperties{
        sType = .PHYSICAL_DEVICE_SUBGROUP_PROPERTIES,
    }
    vk_properties := vk.PhysicalDeviceProperties2{
        sType = .PHYSICAL_DEVICE_PROPERTIES_2,
        pNext = &subgroup_props,
    }
    vk.GetPhysicalDeviceProperties2(impl.vk_physical_device, &vk_properties)

    properties := vk_properties.properties
    limits := properties.limits

    // Texture limits
    ret.max_texture_dimension_1d = limits.maxImageDimension1D
    ret.max_texture_dimension_2d = limits.maxImageDimension2D
    ret.max_texture_dimension_3d = limits.maxImageDimension3D
    ret.max_texture_array_layers = limits.maxImageArrayLayers

    // Descriptor/Binding limits
    ret.max_bind_groups = min(limits.maxBoundDescriptorSets, 4)
    ret.max_bind_groups_plus_vertex_buffers = min(
        limits.maxBoundDescriptorSets + limits.maxVertexInputBindings, 24)
    ret.max_bindings_per_bind_group = 1000

    // Dynamic buffer limits
    ret.max_dynamic_uniform_buffers_per_pipeline_layout =
        limits.maxDescriptorSetUniformBuffersDynamic
    ret.max_dynamic_storage_buffers_per_pipeline_layout =
        limits.maxDescriptorSetStorageBuffersDynamic

    // Per-shader-stage limits
    ret.max_sampled_textures_per_shader_stage = limits.maxPerStageDescriptorSampledImages
    ret.max_samplers_per_shader_stage = limits.maxPerStageDescriptorSamplers
    ret.max_storage_buffers_per_shader_stage = limits.maxPerStageDescriptorStorageBuffers
    ret.max_storage_textures_per_shader_stage = limits.maxPerStageDescriptorStorageImages
    ret.max_uniform_buffers_per_shader_stage = limits.maxPerStageDescriptorUniformBuffers

    // Buffer limits
    ret.max_uniform_buffer_binding_size = limits.maxUniformBufferRange
    ret.max_storage_buffer_binding_size = limits.maxStorageBufferRange
    ret.min_uniform_buffer_offset_alignment = u32(limits.minUniformBufferOffsetAlignment)
    ret.min_storage_buffer_offset_alignment = u32(limits.minStorageBufferOffsetAlignment)

    // On Linux/Android non-NVIDIA drivers, there's a known issue where very
    // large buffer sizes (>2GB) can cause problems, so we limit it to max(i32).
    // NVIDIA drivers and other platforms can handle the full size.
    max_buffer_size: u64
    when ODIN_OS == .Linux {
        is_nvidia := properties.vendorID == NVIDIA_VENDOR
        if !is_nvidia {
            max_buffer_size = u64(max(i32))
        } else {
            max_buffer_size = 1 << 52
        }
    } else {
        max_buffer_size = 1 << 52
    }
    ret.max_buffer_size = max_buffer_size

    // Vertex input limits
    ret.max_vertex_buffers = limits.maxVertexInputBindings
    ret.max_vertex_attributes = limits.maxVertexInputAttributes
    ret.max_vertex_buffer_array_stride = limits.maxVertexInputBindingStride

    // Inter-stage limits
    ret.max_inter_stage_shader_variables = min(
        limits.maxVertexOutputComponents,
        limits.maxFragmentInputComponents) / 4 // Divide by 4 for vec4s

    // Color attachment limits
    ret.max_color_attachments = limits.maxColorAttachments
    ret.max_color_attachment_bytes_per_sample =
        limits.maxColorAttachments * MAX_TARGET_PIXEL_BYTE_COST

    // Compute shader limits
    ret.max_compute_workgroup_storage_size = limits.maxComputeSharedMemorySize
    ret.max_compute_invocations_per_workgroup = limits.maxComputeWorkGroupInvocations
    ret.max_compute_workgroup_size_x = limits.maxComputeWorkGroupSize[0]
    ret.max_compute_workgroup_size_y = limits.maxComputeWorkGroupSize[1]
    ret.max_compute_workgroup_size_z = limits.maxComputeWorkGroupSize[2]
    ret.max_compute_workgroups_per_dimension = limits.maxComputeWorkGroupCount[0]

    // Subgroup limits
    ret.min_subgroup_size = subgroup_props.subgroupSize
    ret.max_subgroup_size = subgroup_props.subgroupSize

    // Push constant limits
    ret.max_push_constant_size = limits.maxPushConstantsSize

    // Non-sampler bindings (sum of all non-sampler descriptors)
    ret.max_non_sampler_bindings = min(
        limits.maxPerStageDescriptorUniformBuffers +
        limits.maxPerStageDescriptorStorageBuffers +
        limits.maxPerStageDescriptorSampledImages +
        limits.maxPerStageDescriptorStorageImages, 1000000)

    // TODO: ray tracing
    ret.max_task_workgroup_total_count = 0
    ret.max_task_workgroups_per_dimension = 0
    ret.max_mesh_output_layers = 0
    ret.max_mesh_multiview_count = 0
    ret.max_blas_primitive_count = 0
    ret.max_blas_geometry_count = 0
    ret.max_tlas_instance_count = 0
    ret.max_acceleration_structures_per_shader_stage = 0

    return
}

vk_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> (ret: Limits) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    return impl.limits
}

vk_adapter_request_device :: proc(
    adapter: Adapter,
    descriptor: Maybe(Device_Descriptor),
    callback_info: Request_Device_Callback_Info,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    instance_impl := get_impl(Vulkan_Instance_Impl, impl.instance, loc)

    invoke_callback :: proc(
        callback_info: Request_Device_Callback_Info,
        status: Request_Device_Status,
        device: Device,
        message: string,
    ) {
        callback_info.callback(
            status,
            device,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    extension_count: u32
    vk_check(vk.EnumerateDeviceExtensionProperties(impl.vk_physical_device, nil, &extension_count, nil))
    available_extensions := make([]vk.ExtensionProperties, extension_count, ta)
    vk_check(vk.EnumerateDeviceExtensionProperties(
        impl.vk_physical_device, nil, &extension_count, raw_data(available_extensions)))

    queue_family_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(impl.vk_physical_device, &queue_family_count, nil)
    queue_families := make([]vk.QueueFamilyProperties, queue_family_count, ta)
    vk.GetPhysicalDeviceQueueFamilyProperties(
        impl.vk_physical_device, &queue_family_count, raw_data(queue_families))

    is_extension_available :: proc(
        available_extensions: []vk.ExtensionProperties,
        required: string,
    ) -> bool {
        for &available in available_extensions {
            ext_name := byte_arr_str(&available.extensionName)
            if ext_name == required { return true }
        }
        return false
    }

    // Chain of extensions
    pnext_chain: sa.Small_Array(4, ^vk.BaseOutStructure)
    // Extension names to enable
    extensions: sa.Small_Array(10, cstring)

    // Extension `VK_KHR_swapchain` is required to present surface
    if !instance_impl.headless {
        sa.push_back(&extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME)
    }

    // Core Vulkan 1.2 features
    enabled_features_12 := vk.PhysicalDeviceVulkan12Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        descriptorIndexing = true,
        descriptorBindingVariableDescriptorCount = true,
        runtimeDescriptorArray = true,
        bufferDeviceAddress = true,
        timelineSemaphore = true,
        drawIndirectCount = true,
    }
    sa.push_back(&pnext_chain, cast(^vk.BaseOutStructure)&enabled_features_12)

    // Core Vulkan 1.3 features
    enabled_features_13 := vk.PhysicalDeviceVulkan13Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        synchronization2 = true,
        dynamicRendering = true,
        maintenance4 = true,
    }
    sa.push_back(&pnext_chain, cast(^vk.BaseOutStructure)&enabled_features_13)

    // Vulkan 1.0 features
    enabled_features_10 := vk.PhysicalDeviceFeatures {
        samplerAnisotropy = true,
        shaderClipDistance = true,
        shaderCullDistance = true,
    }

    // Enables relaxed present timing and fence-based release of swapchain
    // images for lower latency
    has_EXT_swapchain_maintenance1: bool
    swapchain_maintenance1_features := vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT {
        sType = .PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT,
        swapchainMaintenance1 = true,
    }
    if is_extension_available(available_extensions[:], vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME) {
        has_EXT_swapchain_maintenance1 = true
        sa.push_back(&extensions, vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME)
        sa.push_back(&pnext_chain, cast(^vk.BaseOutStructure)&swapchain_maintenance1_features)
    }

    // Provides detailed GPU fault reporting (page faults, driver errors).
    has_EXT_device_fault: bool
    device_fault_features := vk.PhysicalDeviceFaultFeaturesEXT {
        sType = .PHYSICAL_DEVICE_FAULT_FEATURES_EXT,
        deviceFault = true,
    }
    if is_extension_available(available_extensions[:], vk.EXT_DEVICE_FAULT_EXTENSION_NAME) {
        has_EXT_device_fault = true
        sa.push_back(&extensions, vk.EXT_DEVICE_FAULT_EXTENSION_NAME)
        sa.push_back(&pnext_chain, cast(^vk.BaseOutStructure)&device_fault_features)
    }

    has_KHR_maintenance5: bool
    if is_extension_available(available_extensions[:], vk.KHR_MAINTENANCE_5_EXTENSION_NAME) {
        has_KHR_maintenance5 = true
        sa.push_back(&extensions, vk.KHR_MAINTENANCE_5_EXTENSION_NAME)
    }

    // Allows setting HDR metadata (e.g., max luminance, color primaries) on
    // swapchains for HDR displays
    has_EXT_hdr_metadata: bool
    if is_extension_available(available_extensions[:], vk.EXT_HDR_METADATA_EXTENSION_NAME) {
        has_EXT_hdr_metadata = true
        sa.push_back(&extensions, vk.EXT_HDR_METADATA_EXTENSION_NAME)
    }

    find_queue_family_index :: proc(
        vk_physical_device: vk.PhysicalDevice,
        queue_families: []vk.QueueFamilyProperties,
        flags: vk.QueueFlags,
    ) -> (
        index: u32,
    ) {
        // Helper to find a dedicated queue family
        find_dedicated_queue_family_index :: proc(
            props: []vk.QueueFamilyProperties,
            require: vk.QueueFlags,
            avoid: vk.QueueFlags,
        ) -> u32 {
            for &prop, i in props {
                is_suitable := (prop.queueFlags >= require)
                is_dedicated := (prop.queueFlags & avoid) == {}

                if prop.queueCount > 0 && is_suitable && is_dedicated {
                    return u32(i)
                }
            }
            return vk.QUEUE_FAMILY_IGNORED
        }

        // Try to find dedicated compute queue (no graphics)
        if .COMPUTE in flags {
            q := find_dedicated_queue_family_index(
                queue_families,
                flags,
                {.GRAPHICS},
            )
            if q != vk.QUEUE_FAMILY_IGNORED {
                return q
            }
        }

        // Try to find dedicated transfer queue (no graphics)
        if .TRANSFER in flags {
            q := find_dedicated_queue_family_index(
                queue_families,
                flags,
                {.GRAPHICS},
            )
            if q != vk.QUEUE_FAMILY_IGNORED {
                return q
            }
        }

        // Fall back to any suitable queue (no avoidance)
        return find_dedicated_queue_family_index(queue_families, flags, {})
    }

    graphics_queue_family_index :=
        find_queue_family_index(impl.vk_physical_device, queue_families, { .GRAPHICS })
    ensure(graphics_queue_family_index !=
        vk.QUEUE_FAMILY_IGNORED, "GRAPHICS queue is not supported", loc)

    compute_queue_family_index :=
        find_queue_family_index(impl.vk_physical_device, queue_families, { .COMPUTE })
    ensure(compute_queue_family_index !=
        vk.QUEUE_FAMILY_IGNORED, "COMPUTE queue is not supported", loc)

    default_queue_priority : f32 = 1.0
    queue_setup := [2]vk.DeviceQueueCreateInfo {
        {
            sType = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = graphics_queue_family_index,
            queueCount = 1,
            pQueuePriorities = &default_queue_priority,
        },
        {
            sType = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = compute_queue_family_index,
            queueCount = 1,
            pQueuePriorities = &default_queue_priority,
        },
    }
    num_queues := queue_setup[0].queueFamilyIndex == queue_setup[1].queueFamilyIndex ? 1 : 2

    device_create_info := vk.DeviceCreateInfo {
        sType                   = .DEVICE_CREATE_INFO,
        queueCreateInfoCount    = u32(num_queues),
        pQueueCreateInfos       = raw_data(queue_setup[:]),
        enabledExtensionCount   = u32(sa.len(extensions)),
        ppEnabledExtensionNames = raw_data(sa.slice(&extensions)),
        pEnabledFeatures        = &enabled_features_10,
    }

    vk_setup_pnext_chain(&device_create_info, sa.slice(&pnext_chain))

    vk_device: vk.Device
    vk_check(vk.CreateDevice(impl.vk_physical_device, &device_create_info, nil, &vk_device))

    vk.load_proc_addresses_device(vk_device)

    vk_set_debug_object_name(
        vk_device, .DEVICE, u64(uintptr(vk_device)), "Device: impl.vk_device")

    device := adapter_new_handle(Vulkan_Device_Impl, adapter, loc)

    device.heap_alloc = runtime.default_allocator()
    device.backend = .Vulkan
    device.shader_formats = { .Spirv }
    device.vk_physical_device = impl.vk_physical_device
    device.vk_device = vk_device
    device.has_EXT_hdr_metadata = has_EXT_hdr_metadata
    device.has_EXT_swapchain_maintenance1 = has_EXT_swapchain_maintenance1
    device.has_EXT_device_fault = has_EXT_device_fault
    device.has_KHR_maintenance5 = has_KHR_maintenance5

    vk_graphics_queue: vk.Queue
    vk.GetDeviceQueue(vk_device, graphics_queue_family_index, 0, &vk_graphics_queue)

    vk_compute_queue: vk.Queue
    vk.GetDeviceQueue(vk_device, compute_queue_family_index, 0, &vk_compute_queue)

    // Set device queues
    device.queue = device_new_handle(Vulkan_Queue_Impl, Device(device), loc)
    device.queue.queues = {
        .Graphics = {
            graphics_queue_family_index, vk_graphics_queue,
        },
        .Compute = {
            compute_queue_family_index, vk_compute_queue,
        },
    }
    device.queue.pending_writes.allocator = device.allocator

    // Set command encoder defaults
    device.encoder = Vulkan_Command_Encoder_Impl {
        vk_device                 = device.vk_device,
        vk_queue                  = vk_graphics_queue,
        available_command_buffers = VK_MAX_COMMAND_BUFFERS,
        submit_counter            = 1,
        last_submit_semaphore     = { sType = .SEMAPHORE_SUBMIT_INFO, stageMask = { .ALL_COMMANDS } },
        wait_semaphore            = { sType = .SEMAPHORE_SUBMIT_INFO, stageMask = { .ALL_COMMANDS } },
        signal_semaphore          = { sType = .SEMAPHORE_SUBMIT_INFO, stageMask = { .ALL_COMMANDS } },
    }

    command_pool_info := vk.CommandPoolCreateInfo {
        sType            = .COMMAND_POOL_CREATE_INFO,
        flags            = { .RESET_COMMAND_BUFFER, .TRANSIENT },
        queueFamilyIndex = graphics_queue_family_index,
    }
    vk_check(vk.CreateCommandPool(
        device.vk_device, &command_pool_info, nil, &device.encoder.vk_command_pool))

    allocate_info := vk.CommandBufferAllocateInfo {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = device.encoder.vk_command_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }

    encoder_label := "Device: impl.encoder"

    // for i in 0 ..< u32(VK_MAX_COMMAND_BUFFERS) {
    for i : u32 = 0; i != VK_MAX_COMMAND_BUFFERS; i += 1 {
        buf := &device.encoder.buffers[i]

        buf.device = Device(device)
        buf.vk_device = device.vk_device

        vk_deletion_queue_init(&buf.resources, device.vk_device, device.heap_alloc)

        // Name the synchronization objects for debugging
        semaphore_name: [256]u8
        fence_name: [256]u8

        semaphore_name_str := fmt.bprintf(
            semaphore_name[:], "Semaphore: %s (cmdbuf %d)", encoder_label, i)
        fence_name_str := fmt.bprintf(fence_name[:], "Fence: %s (cmdbuf %d)", encoder_label, i)

        // Create synchronization primitives
        buf.vk_semaphore = vk_create_semaphore(device.vk_device, semaphore_name_str)
        buf.vk_fence = vk_create_fence(device.vk_device, fence_name_str)

        // Allocate the command buffer
        vk_check(vk.AllocateCommandBuffers(
            device.vk_device,
            &allocate_info,
            &buf.vk_cmd_buf_allocated,
        ))

        // Store buffer index
        buf.handle.buffer_index = i
    }

    // Default pool ratios for common descriptor types
    default_ratios := []Vulkan_Pool_Size_Ratio {
        {.UNIFORM_BUFFER, 1.0},
        {.STORAGE_BUFFER, 1.0},
        {.SAMPLED_IMAGE, 2.0},
        {.STORAGE_IMAGE, 1.0},
        {.SAMPLER, 1.0},
        {.COMBINED_IMAGE_SAMPLER, 2.0},
    }

    vk_descriptor_allocator_init(
        &device.descriptor_allocator,
        device,
        64, // Initial sets per pool
        default_ratios,
        device.allocator,
    )

    // Create the VMA (Vulkan Memory Allocator)
    // Initializes a subset of Vulkan functions required by VMA
    vma_vulkan_functions := vma.create_vulkan_functions()

    vma_create_info: vma.Allocator_Create_Info = {
        flags              = { .Buffer_Device_Address },
        instance           = instance_impl.vk_instance,
        physical_device    = impl.vk_physical_device,
        device             = device.vk_device,
        vulkan_functions   = &vma_vulkan_functions,
        // Convert Vulkan api version to VMA's expected decimal format
        // ex: 4206592 -> 1003000
        vulkan_api_version = vma.VK_API_VERSION_TO_DECIMAL(instance_impl.api_version),
    }

    vk_check(vma.create_allocator(vma_create_info, &device.vma_allocator))

    invoke_callback(callback_info, .Success, Device(device), "")
}

@(require_results)
vk_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    return string_buffer_get_string(&impl.label)
}

vk_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    string_buffer_init(&impl.label, label)
}

vk_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    ref_count_add(&impl.ref, loc)
}

vk_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------


Vulkan_Buffer_Access :: struct {
    buffer:  Buffer,
    storage: bool,
}

Vulkan_Texture_View_Access :: struct {
    texture_view: Texture_View,
    storage:      bool,
}

Vulkan_Bind_Group_Impl :: struct {
    // Base
    using base:         Bind_Group_Base,

    // Initialization
    layout:             ^Vulkan_Bind_Group_Layout_Impl,
    vk_descriptor_pool: vk.DescriptorPool,
    vk_descriptor_set:  vk.DescriptorSet,
    buffers:            [dynamic]Vulkan_Buffer_Access,
    texture_views:      [dynamic]Vulkan_Texture_View_Access,
    samplers:           [dynamic]Sampler,
}

@(require_results)
vk_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Bind_Group_Impl, bind_group, loc)
    return string_buffer_get_string(&impl.label)
}

vk_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location)  {
    impl := get_impl(Vulkan_Bind_Group_Impl, bind_group, loc)
    string_buffer_init(&impl.label, label)
}

vk_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(Vulkan_Bind_Group_Impl, bind_group, loc)
    ref_count_add(&impl.ref, loc)
}

vk_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(Vulkan_Bind_Group_Impl, bind_group, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        // Release tracked resources
        for &buffer_access in impl.buffers {
            vk_buffer_release(buffer_access.buffer, loc)
        }
        delete(impl.buffers)

        for &texture_view_access in impl.texture_views {
            vk_texture_view_release(texture_view_access.texture_view, loc)
        }
        delete(impl.texture_views)

        for sampler in impl.samplers {
            vk_sampler_release(sampler, loc)
        }
        delete(impl.samplers)

        // Release layout reference
        vk_bind_group_layout_release(Bind_Group_Layout(impl.layout), loc)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------


Vulkan_Bind_Group_Layout_Impl :: struct {
    // Base
    using base: Bind_Group_Layout_Base,

    // Initialization
    vk_layout:  vk.DescriptorSetLayout,
    entries:    []Bind_Group_Layout_Entry,
}

@(require_results)
vk_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(Vulkan_Bind_Group_Layout_Impl, bind_group_layout, loc)
    return string_buffer_get_string(&impl.label)
}

vk_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Bind_Group_Layout_Impl, bind_group_layout, loc)
    string_buffer_init(&impl.label, label)
}

vk_bind_group_layout_add_ref :: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location) {
    impl := get_impl(Vulkan_Bind_Group_Layout_Impl, bind_group_layout, loc)
    ref_count_add(&impl.ref, loc)
}

vk_bind_group_layout_release :: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location) {
    impl := get_impl(Vulkan_Bind_Group_Layout_Impl, bind_group_layout, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vk.DestroyDescriptorSetLayout(device_impl.vk_device, impl.vk_layout, nil)
        delete(impl.entries)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------


Vulkan_Buffer_Impl :: struct {
    // Base
    using base:     Buffer_Base,

    // Initialization
    vk_buffer:      vk.Buffer,
    vma_allocation: vma.Allocation,
    vk_device_size: vk.DeviceSize,
    vk_usage_flags: vk.BufferUsageFlags,
    vma_alloc_info: vma.Allocation_Info,
    vk_mem_flags:   vk.MemoryPropertyFlags,
}

vk_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    assert(impl.mapped_ptr != nil, "Attempted to unmap buffer that is not mapped", loc)
    assert(impl.map_state != .Unmapped, "Unmap called in wrong state", loc)

    vma.unmap_memory(device_impl.vma_allocator, impl.vma_allocation)

    // Clear mapping state
    impl.mapped_ptr = nil
    impl.mapped_range = {}
    impl.mapped_at_creation = false
    impl.map_state = .Unmapped
}

@(require_results)
vk_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    return impl.map_state
}

@(require_results)
vk_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    return impl.size
}

@(require_results)
vk_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    return impl.usage
}

@(require_results)
vk_buffer_get_label :: proc(buffer: Buffer, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    return string_buffer_get_string(&impl.label)
}

vk_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location)  {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
    string_buffer_init(&impl.label, label)
    vk_set_debug_object_name(device_impl.vk_device, .BUFFER, impl.vk_buffer, label)
}

vk_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    ref_count_add(&impl.ref, loc)
}

vk_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vma.destroy_buffer(device_impl.vma_allocator, impl.vk_buffer, impl.vma_allocation)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Command Buffer procedures
// -----------------------------------------------------------------------------


Vulkan_Submit_Handle :: struct {
    buffer_index: u32,
    submit_id:    u32,
}

Vulkan_Command_Buffer_Impl :: struct {
    // Base
    using base:                Command_Buffer_Base,

    // Initialization
    vk_device:                 vk.Device,
    vk_cmd_buf:                vk.CommandBuffer,
    vk_cmd_buf_allocated:      vk.CommandBuffer,
    vk_fence:                  vk.Fence,
    vk_semaphore:              vk.Semaphore,
    handle:                    Vulkan_Submit_Handle,
    is_encoding:               bool,
    is_rendering:              bool,

    // State
    color_attachments:         sa.Small_Array(MAX_COLOR_ATTACHMENTS, Render_Pass_Color_Attachment),
    resources:                 Vulkan_Deletion_Queue,
    current_pipeline_graphics: ^Vulkan_Render_Pipeline_Impl,
}

@(require_results)
vk_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_buffer, loc)
    return string_buffer_get_string(&impl.label)
}

vk_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_buffer, loc)
    string_buffer_init(&impl.label, label)
}

@(disabled = true)
vk_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
}

@(disabled = true)
vk_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Command Encoder procedures
// -----------------------------------------------------------------------------


// Limits the total number of command buffers that can be active concurrently.
//
// If all buffers are in use, the system will wait until one is freed.
VK_MAX_COMMAND_BUFFERS :: 64

Vulkan_Command_Encoder_Impl :: struct {
    // Base
    using base:                Command_Encoder_Base,

    // Initialization
    vk_device:                 vk.Device,
    vk_queue:                  vk.Queue,
    vk_command_pool:           vk.CommandPool,

    // Buffers
    buffers:                   [VK_MAX_COMMAND_BUFFERS]Vulkan_Command_Buffer_Impl,
    last_submit_handle:        Vulkan_Submit_Handle,
    next_submit_handle:        Vulkan_Submit_Handle,
    last_submit_semaphore:     vk.SemaphoreSubmitInfo,
    wait_semaphore:            vk.SemaphoreSubmitInfo,
    signal_semaphore:          vk.SemaphoreSubmitInfo,
    available_command_buffers: u32,
    submit_counter:            u32,
}

@require_results
vk_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_encoder, loc)

    assert(impl.is_rendering == false, "Already rendering", loc)
    impl.is_rendering = true

    assert(len(descriptor.color_attachments) <= MAX_COLOR_ATTACHMENTS,
        "Too many color attachments", loc)

    // Framebuffer dimensions from first valid attachment
    fb_width, fb_height: u32

    color_attachments: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.RenderingAttachmentInfo)
    sa.clear(&impl.color_attachments)

    for &attachment in descriptor.color_attachments {
        assert(attachment.view != nil, "Invalid color attachment view", loc)

        sa.push_back(&impl.color_attachments, attachment)

        color_tex_view := get_impl(Vulkan_Texture_View_Impl, attachment.view, loc)
        color_tex := get_impl(Vulkan_Texture_Impl, color_tex_view.texture, loc)

        // Retain user owned texture for command buffer lifetime
        if color_tex.is_owning_vk_image {
            vk_deletion_queue_push(&impl.resources, color_tex)
        }

        if fb_width == 0 {
            fb_width = color_tex.vk_extent.width
            fb_height = color_tex.vk_extent.height
        } else {
            assert(color_tex.vk_extent.width == fb_width && color_tex.vk_extent.height == fb_height,
               "All color attachments must have matching dimensions", loc)
        }

        // Transition main color attachment
        vk_transition_to_color_attachment(impl, color_tex, loc)

        has_resolve := attachment.resolve_target != nil
        resolve_tex: ^Vulkan_Texture_Impl
        samples := color_tex.vk_samples

        if has_resolve {
            resolve_tex_view := get_impl(Vulkan_Texture_View_Impl, attachment.resolve_target, loc)
            resolve_tex = get_impl(Vulkan_Texture_Impl, resolve_tex_view.texture, loc)

            assert(resolve_tex.vk_extent.width == fb_width &&
                   resolve_tex.vk_extent.height == fb_height,
               "Resolve target must match framebuffer dimensions", loc)
            assert(resolve_tex.vk_samples == {._1}, "Resolve target must be single-sampled", loc)

            vk_transition_to_color_attachment(impl, resolve_tex, loc)
            vk_deletion_queue_push(&impl.resources, resolve_tex)
        }

        clear_value_f32 := [4]f32{
            f32(attachment.ops.clear_value.x),
            f32(attachment.ops.clear_value.y),
            f32(attachment.ops.clear_value.z),
            f32(attachment.ops.clear_value.w),
        }

        sa.push_back(&color_attachments, vk.RenderingAttachmentInfo{
            sType              = .RENDERING_ATTACHMENT_INFO,
            imageView          = color_tex.vk_image_view,
            imageLayout        = .COLOR_ATTACHMENT_OPTIMAL,
            resolveMode        = has_resolve && samples != {._1} ? { .AVERAGE } : {},
            resolveImageView   = has_resolve ? resolve_tex.vk_image_view : {},
            resolveImageLayout = has_resolve ? .COLOR_ATTACHMENT_OPTIMAL : .UNDEFINED,
            loadOp             = vk_conv_to_attachment_load_op(attachment.ops.load),
            storeOp            = vk_conv_to_attachment_store_op(attachment.ops.store),
            clearValue         = { color = { float32 = clear_value_f32 } },
        })
    }

    // Depth-stencil attachment
    has_depth: bool
    has_stencil: bool
    vk_depth_attachment: vk.RenderingAttachmentInfo
    vk_stencil_attachment: vk.RenderingAttachmentInfo

    if descriptor.depth_stencil_attachment != nil {
        assert(descriptor.depth_stencil_attachment.view != nil, "Invalid depth attachment view", loc)

        depth_stencil := descriptor.depth_stencil_attachment
        view_impl := get_impl(Vulkan_Texture_View_Impl, depth_stencil.view, loc)
        texture_impl := get_impl(Vulkan_Texture_Impl, view_impl.texture, loc)

        // Retain texture
        vk_deletion_queue_push(&impl.resources, texture_impl)

        // Determine/validate dimensions
        if fb_width == 0 {
            fb_width = texture_impl.vk_extent.width
            fb_height = texture_impl.vk_extent.height
        } else {
            assert(texture_impl.vk_extent.width == fb_width &&
                   texture_impl.vk_extent.height == fb_height,
               "Depth/stencil attachment must match framebuffer dimensions", loc)
        }

        has_depth = texture_format_has_depth_aspect(view_impl.format)
        has_stencil = texture_format_has_stencil_aspect(view_impl.format)

        aspect_mask: vk.ImageAspectFlags
        if has_depth   { aspect_mask += {.DEPTH}   }
        if has_stencil { aspect_mask += {.STENCIL} }

        subresource_range := vk.ImageSubresourceRange{
            aspectMask     = aspect_mask,
            baseMipLevel   = 0,
            levelCount     = texture_impl.mip_level_count,
            baseArrayLayer = 0,
            layerCount     = texture_impl.array_layer_count,
        }

        vk_texture_transition_layout(
            texture_impl,
            impl.vk_cmd_buf,
            .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            subresource_range,
        )

        // Full depth-stencil clear value
        depth_clear_val := has_depth   ? depth_stencil.depth_ops.clear_value   : 0.0
        stencil_clear_val := has_stencil ? depth_stencil.stencil_ops.clear_value : 0
        full_ds_clear := vk.ClearDepthStencilValue{
            depth   = depth_clear_val,
            stencil = stencil_clear_val,
        }
        ds_clear_value := vk.ClearValue{ depthStencil = full_ds_clear }

        if has_depth {
            depth_load : vk.AttachmentLoadOp = depth_stencil.depth_ops.read_only \
                ? .LOAD : vk_conv_to_attachment_load_op(depth_stencil.depth_ops.load)
            depth_store : vk.AttachmentStoreOp = depth_stencil.depth_ops.read_only \
                ? .DONT_CARE : vk_conv_to_attachment_store_op(depth_stencil.depth_ops.store)

            vk_depth_attachment = vk.RenderingAttachmentInfo{
                sType       = .RENDERING_ATTACHMENT_INFO,
                imageView   = view_impl.vk_image_view,
                imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                loadOp      = depth_load,
                storeOp     = depth_store,
                clearValue  = ds_clear_value,
            }
        }

        // Stencil aspect
        if has_stencil {
            stencil_load : vk.AttachmentLoadOp = depth_stencil.stencil_ops.read_only \
                ? .LOAD      : vk_conv_to_attachment_load_op(depth_stencil.stencil_ops.load)
            stencil_store : vk.AttachmentStoreOp = depth_stencil.stencil_ops.read_only \
                ? .DONT_CARE : vk_conv_to_attachment_store_op(depth_stencil.stencil_ops.store)

            vk_stencil_attachment = vk.RenderingAttachmentInfo{
                sType       = .RENDERING_ATTACHMENT_INFO,
                imageView   = view_impl.vk_image_view,
                imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                loadOp      = stencil_load,
                storeOp     = stencil_store,
                clearValue  = ds_clear_value,
            }
        }
    }

    assert(fb_width > 0 && fb_height > 0,
        "Invalid framebuffer dimensions, no valid attachments provided", loc)

    scissor := vk.Rect2D{
        offset = {0, 0},
        extent = {fb_width, fb_height},
    }

    rendering_info := vk.RenderingInfo{
        sType                = .RENDERING_INFO,
        renderArea           = scissor,
        layerCount           = 1,
        viewMask             = 0,
        colorAttachmentCount = u32(sa.len(color_attachments)),
        pColorAttachments    = raw_data(sa.slice(&color_attachments)),
        pDepthAttachment     = has_depth   ? &vk_depth_attachment   : nil,
        pStencilAttachment   = has_stencil ? &vk_stencil_attachment : nil,
    }

    vk.CmdBeginRendering(impl.vk_cmd_buf, &rendering_info)

    render_pass := Render_Pass(command_encoder)

    // Default viewport/scissor
    vk_render_pass_set_viewport(
        render_pass = render_pass,
        x           = 0.0,
        y           = 0.0,
        width       = f32(fb_width),
        height      = f32(fb_height),
        min_depth   = 0.0,
        max_depth   = 1.0,
    )

    vk_render_pass_set_scissor_rect(
        render_pass = render_pass,
        x           = 0,
        y           = 0,
        width       = fb_width,
        height      = fb_height,
    )

    // Improved dynamic state defaults
    depth_store_op := has_depth ? vk_depth_attachment.storeOp : .DONT_CARE

    vk.CmdSetDepthTestEnable(impl.vk_cmd_buf, b32(has_depth))
    vk.CmdSetDepthWriteEnable(impl.vk_cmd_buf, b32(has_depth && depth_store_op == .STORE))
    vk.CmdSetDepthCompareOp(impl.vk_cmd_buf, .LESS)
    vk.CmdSetDepthBiasEnable(impl.vk_cmd_buf, false)

    if has_stencil {
        vk.CmdSetStencilTestEnable(impl.vk_cmd_buf, true)
    }
    vk.CmdSetStencilReference(impl.vk_cmd_buf, {.FRONT, .BACK}, 0)

    return render_pass
}

vk_command_encoder_copy_buffer_to_buffer :: proc(
    encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, encoder, loc)
    src_impl := get_impl(Vulkan_Buffer_Impl, source, loc)
    dst_impl := get_impl(Vulkan_Buffer_Impl, destination, loc)

    copy_region := vk.BufferCopy{
        srcOffset = vk.DeviceSize(source_offset),
        dstOffset = vk.DeviceSize(destination_offset),
        size = vk.DeviceSize(size),
    }

    vk.CmdCopyBuffer(
        impl.vk_cmd_buf,
        src_impl.vk_buffer,
        dst_impl.vk_buffer,
        1,
        &copy_region,
    )

    vk_deletion_queue_push(&impl.resources, src_impl)
    vk_deletion_queue_push(&impl.resources, dst_impl)
}

vk_command_encoder_copy_buffer_to_texture :: proc(
    encoder: Command_Encoder,
    source: Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    assert(encoder != nil, "Invalid command encoder", loc)
    assert(source.buffer != nil, "Invalid source buffer", loc)
    assert(destination.texture != nil, "Invalid destination texture", loc)

    impl := get_impl(Vulkan_Command_Buffer_Impl, encoder, loc)
    buffer_impl := get_impl(Vulkan_Buffer_Impl, source.buffer, loc)
    texture_impl := get_impl(Vulkan_Texture_Impl, destination.texture, loc)

    // Calculate the mip level dimensions
    mip_level := destination.mip_level
    mip_width := max(1, texture_impl.vk_extent.width >> mip_level)
    mip_height := max(1, texture_impl.vk_extent.height >> mip_level)
    // mip_depth := max(1, texture_impl.vk_extent.depth >> mip_level)

    // Validate copy region
    assert(destination.origin.x + copy_size.width <= mip_width,
        "Copy width exceeds texture dimensions", loc)
    assert(destination.origin.y + copy_size.height <= mip_height,
        "Copy height exceeds texture dimensions", loc)

    // Determine aspect flags
    aspect_flags := vk_conv_to_image_aspect_flags(destination.aspect, texture_impl.format)

    // Define subresource range for the copy
    subresource_range := vk.ImageSubresourceRange{
        aspectMask     = aspect_flags,
        baseMipLevel   = destination.mip_level,
        levelCount     = 1,
        baseArrayLayer = destination.origin.z,
        layerCount     = copy_size.depth_or_array_layers,
    }

    // Transition to TRANSFER_DST_OPTIMAL
    vk_texture_transition_layout(
        texture_impl,
        impl.vk_cmd_buf,
        .TRANSFER_DST_OPTIMAL,
        subresource_range,
    )

    // Set up the buffer image copy region
    region := vk.BufferImageCopy{
        bufferOffset = vk.DeviceSize(source.layout.offset),
        bufferRowLength = source.layout.bytes_per_row / texture_format_block_copy_size(texture_impl.format),
        bufferImageHeight = source.layout.rows_per_image,
        imageSubresource = vk.ImageSubresourceLayers{
            aspectMask = vk_conv_to_image_aspect_flags(destination.aspect, texture_impl.format),
            mipLevel = destination.mip_level,
            baseArrayLayer = destination.origin.z,
            layerCount = copy_size.depth_or_array_layers,
        },
        imageOffset = vk.Offset3D{
            x = i32(destination.origin.x),
            y = i32(destination.origin.y),
            z = i32(destination.origin.z),
        },
        imageExtent = vk.Extent3D{
            width = copy_size.width,
            height = copy_size.height,
            depth = copy_size.depth_or_array_layers,
        },
    }

    // Copy buffer to image
    vk.CmdCopyBufferToImage(
        impl.vk_cmd_buf,
        buffer_impl.vk_buffer,
        texture_impl.vk_image,
        .TRANSFER_DST_OPTIMAL,
        1,
        &region,
    )

    // Transition to SHADER_READ_ONLY_OPTIMAL for shader usage
    vk_texture_transition_layout(
        texture_impl,
        impl.vk_cmd_buf,
        .SHADER_READ_ONLY_OPTIMAL,
        subresource_range,
    )

    vk_deletion_queue_push(&impl.resources, buffer_impl)
    vk_deletion_queue_push(&impl.resources, texture_impl)
}

vk_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_encoder, loc)
    assert(impl.is_encoding, "Attempt to finish a command encoder that is not encoding", loc)
    assert(impl.is_rendering == false, "Attempt to finish a command encoder that is rendering", loc)
    vk_check(vk.EndCommandBuffer(impl.vk_cmd_buf))
    impl.is_encoding = false
    return Command_Buffer(impl)
}

@(require_results)
vk_command_encoder_get_label :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_encoder, loc)
    return string_buffer_get_string(&impl.label)
}

vk_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, command_encoder, loc)
    string_buffer_init(&impl.label, label)
}

@(disabled = true)
vk_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
}

@(disabled = true)
vk_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------


Vulkan_Device_Impl :: struct {
    // Base
    using base:                     Device_Base,
    heap_alloc:                     runtime.Allocator,

    // Initialization
    vk_physical_device:             vk.PhysicalDevice,
    vk_device:                      vk.Device,
    queue:                          ^Vulkan_Queue_Impl,
    has_EXT_hdr_metadata:           bool,
    has_EXT_swapchain_maintenance1: bool,
    has_EXT_device_fault:           bool,
    has_KHR_maintenance5:           bool,

    // Commands
    encoder:                        Vulkan_Command_Encoder_Impl,
    descriptor_allocator:           Vulkan_Descriptor_Allocator,

    // Vulkan Memory Allocator
    vma_allocator:                  vma.Allocator,
}

vk_device_get_features :: proc(device: Device, loc := #caller_location) -> (features: Features) {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    return impl.features
}

vk_device_get_limits :: proc(device: Device, loc := #caller_location) -> (limits: Limits) {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    return impl.limits
}

@(require_results)
vk_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    assert(descriptor.layout != nil, "Invalid bind group descriptor layout", loc)

    impl := get_impl(Vulkan_Device_Impl, device, loc)
    layout_impl := get_impl(Vulkan_Bind_Group_Layout_Impl, descriptor.layout, loc)

    vk_bind_group_layout_add_ref(descriptor.layout, loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    vk_descriptor_set, vk_descriptor_pool :=
        vk_descriptor_allocator_allocate(&impl.descriptor_allocator, &layout_impl.vk_layout, loc)

    // Count descriptors
    buffer_desc_count := 0
    image_desc_count  := 0
    for entry in descriptor.entries {
        switch res in entry.resource {
        case Buffer_Binding:      buffer_desc_count += 1
        case []Buffer_Binding:    buffer_desc_count += len(res)
        case Sampler:             image_desc_count += 1
        case []Sampler:           image_desc_count += len(res)
        case Texture_View:        image_desc_count += 1
        case []Texture_View:      image_desc_count += len(res)
        }
    }

    writes := make([]vk.WriteDescriptorSet, len(descriptor.entries), ta)

    buffer_infos := make([]vk.DescriptorBufferInfo, buffer_desc_count, ta)
    image_infos := make([]vk.DescriptorImageInfo,  image_desc_count,  ta)

    // Resource tracking
    buffers := make([dynamic]Vulkan_Buffer_Access, 0, 16, impl.allocator)
    texture_views := make([dynamic]Vulkan_Texture_View_Access, 0, 16, impl.allocator)
    samplers := make([dynamic]Sampler, 0, 16, impl.allocator)

    write_idx, buffer_idx, image_idx: int
    for entry in descriptor.entries {
        // Search for layout entry
        layout_index, layout_found := slice.binary_search_by(
            layout_impl.entries,
            entry.binding,
            proc(layout_entry: Bind_Group_Layout_Entry, binding: u32) -> slice.Ordering {
                return slice.cmp(layout_entry.binding, binding)
            },
        )
        assert(layout_found, "Failed to find bind group layout entry for binding", loc)

        layout_entry := layout_impl.entries[layout_index]
        vk_desc_type := vk_conv_to_descriptor_type(layout_entry, loc)
        expected_count := layout_entry.count

        // Compute provided count and validate against layout
        provided_count: u32
        switch res in entry.resource {
        case Buffer_Binding:     provided_count = 1
        case []Buffer_Binding:   provided_count = u32(len(res))
        case Sampler:            provided_count = 1
        case []Sampler:          provided_count = u32(len(res))
        case Texture_View:       provided_count = 1
        case []Texture_View:     provided_count = u32(len(res))
        }
        assert(provided_count == expected_count,
               "Descriptor count mismatch for binding (provided != layout expected)", loc)

        writes[write_idx] = vk.WriteDescriptorSet{
            sType           = .WRITE_DESCRIPTOR_SET,
            dstSet          = vk_descriptor_set,
            dstBinding      = entry.binding,
            dstArrayElement = 0,
            descriptorCount = expected_count,
            descriptorType  = vk_desc_type,
        }

        switch res in entry.resource {
        case Buffer_Binding:
            buffer_impl := get_impl(Vulkan_Buffer_Impl, res.buffer, loc)

            buffer_infos[buffer_idx] = vk.DescriptorBufferInfo{
                buffer = buffer_impl.vk_buffer,
                offset = vk.DeviceSize(res.offset),
                range  = vk.DeviceSize(res.size),
            }
            writes[write_idx].pBufferInfo = &buffer_infos[buffer_idx]

            binding_type := layout_entry.type.(Buffer_Binding_Layout)
            is_storage := binding_type.type == .Storage || binding_type.type == .Read_Only_Storage
            append(&buffers, Vulkan_Buffer_Access{
                buffer  = res.buffer,
                storage = is_storage,
            })
            vk_buffer_add_ref(res.buffer)

            buffer_idx += 1

        case []Buffer_Binding:
            writes[write_idx].pBufferInfo = &buffer_infos[buffer_idx]

            binding_type := layout_entry.type.(Buffer_Binding_Layout)
            is_storage := binding_type.type == .Storage || binding_type.type == .Read_Only_Storage

            for sub_res, i in res {
                buffer_impl := get_impl(Vulkan_Buffer_Impl, sub_res.buffer, loc)
                buffer_infos[buffer_idx + i] = vk.DescriptorBufferInfo{
                    buffer = buffer_impl.vk_buffer,
                    offset = vk.DeviceSize(sub_res.offset),
                    range  = vk.DeviceSize(sub_res.size),
                }
                append(&buffers, Vulkan_Buffer_Access{
                    buffer  = sub_res.buffer,
                    storage = is_storage,
                })
                vk_buffer_add_ref(sub_res.buffer)
            }

            buffer_idx += int(expected_count)

        case Sampler:
            sampler_impl := get_impl(Vulkan_Sampler_Impl, res, loc)

            image_infos[image_idx] = vk.DescriptorImageInfo{
                sampler = sampler_impl.vk_sampler,
            }
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            append(&samplers, res)
            vk_sampler_add_ref(res)

            image_idx += 1

        case []Sampler:
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for sub_res, i in res {
                sampler_impl := get_impl(Vulkan_Sampler_Impl, sub_res, loc)
                image_infos[image_idx + i] = vk.DescriptorImageInfo{
                    sampler = sampler_impl.vk_sampler,
                }
                append(&samplers, sub_res)
                vk_sampler_add_ref(sub_res)
            }

            image_idx += int(expected_count)

        case Texture_View:
            texture_view_impl := get_impl(Vulkan_Texture_View_Impl, res, loc)

            image_layout: vk.ImageLayout
            is_storage: bool
            #partial switch binding_type in layout_entry.type {
            case Texture_Binding_Layout:
                image_layout = .SHADER_READ_ONLY_OPTIMAL
                is_storage = false
            case Storage_Texture_Binding_Layout:
                image_layout = .GENERAL
                is_storage = true
            case:
                panic("Invalid texture binding type", loc)
            }

            image_infos[image_idx] = vk.DescriptorImageInfo{
                imageView   = texture_view_impl.vk_image_view,
                imageLayout = image_layout,
            }
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            append(&texture_views, Vulkan_Texture_View_Access{
                texture_view = res,
                storage      = is_storage,
            })
            vk_texture_view_add_ref(res)

            image_idx += 1

        case []Texture_View:
            image_layout: vk.ImageLayout
            is_storage: bool
            #partial switch binding_type in layout_entry.type {
            case Texture_Binding_Layout:
                image_layout = .SHADER_READ_ONLY_OPTIMAL
                is_storage = false
            case Storage_Texture_Binding_Layout:
                image_layout = .GENERAL
                is_storage = true
            case:
                panic("Invalid texture binding type", loc)
            }

            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for sub_res, i in res {
                tv_impl := get_impl(Vulkan_Texture_View_Impl, sub_res, loc)
                image_infos[image_idx + i] = vk.DescriptorImageInfo{
                    imageView   = tv_impl.vk_image_view,
                    imageLayout = image_layout,
                }
                append(&texture_views, Vulkan_Texture_View_Access{
                    texture_view = sub_res,
                    storage      = is_storage,
                })
                vk_texture_view_add_ref(sub_res)
            }

            image_idx += int(expected_count)
        }

        write_idx += 1
    }

    // Update descriptor sets
    vk.UpdateDescriptorSets(impl.vk_device, u32(len(writes)), raw_data(writes), 0, nil)

    bind_group := device_new_handle(Vulkan_Bind_Group_Impl, device, loc)

    bind_group.layout             = layout_impl
    bind_group.vk_descriptor_pool = vk_descriptor_pool
    bind_group.vk_descriptor_set  = vk_descriptor_set
    bind_group.buffers            = buffers
    bind_group.samplers           = samplers
    bind_group.texture_views      = texture_views

    return Bind_Group(bind_group)
}

@(require_results)
vk_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    assert(len(descriptor.entries) != 0, "Bind group layout entries is empty", loc)

    entries := make([]Bind_Group_Layout_Entry, len(descriptor.entries), impl.allocator)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    vk_bindings := make([]vk.DescriptorSetLayoutBinding, len(descriptor.entries), ta)

    for &entry, i in descriptor.entries {
        normalized_count := max(1, entry.count)

        entries[i] = entry
        entries[i].count = normalized_count

        vk_bindings[i].binding         = entry.binding
        vk_bindings[i].descriptorType  = vk_conv_to_descriptor_type(entry, loc)
        vk_bindings[i].descriptorCount = normalized_count
        vk_bindings[i].pImmutableSamplers = nil

        if entry.visibility == {} {
            vk_bindings[i].stageFlags = { .VERTEX, .GEOMETRY, .FRAGMENT, .COMPUTE }
        } else {
            vk_bindings[i].stageFlags = vk_conv_to_stage_flags(entry.visibility)
        }
    }

    create_info := vk.DescriptorSetLayoutCreateInfo {
        sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        bindingCount = u32(len(vk_bindings)),
        pBindings    = raw_data(vk_bindings),
    }

    vk_layout: vk.DescriptorSetLayout
    vk_check(vk.CreateDescriptorSetLayout(impl.vk_device, &create_info, nil, &vk_layout))

    layout := device_new_handle(Vulkan_Bind_Group_Layout_Impl, device, loc)

    // Sort entries by binding in ascending order
    slice.sort_by(entries[:], proc(a, b: Bind_Group_Layout_Entry) -> bool {
        return a.binding < b.binding
    })

    layout.entries   = entries
    layout.vk_layout = vk_layout

    return Bind_Group_Layout(layout)
}

@(require_results)
vk_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    assert(descriptor.size > 0, "Invalid buffer size", loc)
    assert(descriptor.usage != {}, "Invalid buffer usage", loc)

    // Validate mapped_at_creation alignment requirement
    if descriptor.mapped_at_creation {
        assert(
            descriptor.size % COPY_BUFFER_ALIGNMENT == 0,
            "Buffer size must be a multiple of COPY_BUFFER_ALIGNMENT when mapped_at_creation is true",
            loc,
        )
    }

    usage_flags := vk_conv_to_buffer_usage_flags(descriptor.usage)
    map_state: Buffer_Map_State

    create_info := vk.BufferCreateInfo {
        sType       = .BUFFER_CREATE_INFO,
        size        = vk.DeviceSize(descriptor.size),
        usage       = usage_flags,
        sharingMode = .EXCLUSIVE,
    }

    // Determine memory properties
    property_to_find: vk.MemoryPropertyFlags
    if .Map_Read in descriptor.usage || .Map_Write in descriptor.usage || descriptor.mapped_at_creation {
        // Host-visible memory for mappable buffers
        property_to_find = { .HOST_VISIBLE, .HOST_COHERENT }
        map_state = .Pending_Map
    } else {
        // Device-local memory for GPU-only buffers
        property_to_find = { .DEVICE_LOCAL }
    }

    vma_alloc_info := vma.Allocation_Create_Info {
        required_flags = property_to_find,
        usage = .Auto,
    }

    // If mapped_at_creation, ensure the allocation will be mapped
    if descriptor.mapped_at_creation {
        vma_alloc_info.flags = { .Mapped }
        map_state = .Mapped_At_Creation
    }

    vk_buffer: vk.Buffer
    vma_allocation: vma.Allocation
    vma_alloc_result_info: vma.Allocation_Info

    vk_check(
        vma.create_buffer_with_alignment(
            impl.vma_allocator,
            create_info,
            vma_alloc_info,
            16, // alignment
            &vk_buffer,
            &vma_allocation,
            &vma_alloc_result_info,
        ),
    )

    assert(vk_buffer != {}, "[VK] Failed to create buffer", loc)
    assert(vma_allocation != nil, "[VK] Failed to create buffer allocation", loc)

    buffer := device_new_handle(Vulkan_Buffer_Impl, device, loc)

    // Set base
    buffer.size = descriptor.size
    buffer.usage = descriptor.usage
    buffer.mapped_at_creation = descriptor.mapped_at_creation
    buffer.map_state = map_state

    // Set backend
    buffer.vk_buffer = vk_buffer
    buffer.vma_allocation = vma_allocation
    buffer.vma_alloc_info = vma_alloc_result_info
    buffer.vk_usage_flags = usage_flags
    buffer.vk_device_size = vk.DeviceSize(descriptor.size)

    // Store mapped pointer if created mapped
    if descriptor.mapped_at_creation {
        buffer.mapped_ptr = vma_alloc_result_info.mapped_data
        buffer.mapped_range = { 0, descriptor.size }
    }

    // Set debug name
    if len(descriptor.label) > 0 {
        vk_buffer_set_label(Buffer(buffer), descriptor.label, loc)
    }

    return Buffer(buffer)
}

@(require_results)
vk_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    encoder := &impl.encoder

    if encoder.available_command_buffers == 0 {
        vk_command_encoder_purge(encoder)
    }

    for encoder.available_command_buffers == 0 {
        log.warn("Waiting for command buffers...")
        vk_command_encoder_purge(encoder)
    }

    // Get any available buffer
    current: ^Vulkan_Command_Buffer_Impl
    for &buf in encoder.buffers {
        if buf.vk_cmd_buf == nil {
            current = &buf
            break
        }
    }

    assert(encoder.available_command_buffers != 0, "No available command buffers", loc)
    assert(current != nil, "No available command buffers", loc)
    assert(current.vk_cmd_buf_allocated != nil, loc = loc)

    current.handle.submit_id = encoder.submit_counter
    encoder.available_command_buffers -= 1

    current.vk_cmd_buf = current.vk_cmd_buf_allocated
    current.is_encoding = true

    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = { .ONE_TIME_SUBMIT },
    }
    vk_check(vk.BeginCommandBuffer(current.vk_cmd_buf, &begin_info))

    encoder.next_submit_handle = current.handle

    return Command_Encoder(current)
}

@(require_results)
vk_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    assert(len(descriptor.bind_group_layouts) > 0, "Bind group layouts is empty", loc)

    impl := get_impl(Vulkan_Device_Impl, device, loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    vk_set_layouts := make([]vk.DescriptorSetLayout, len(descriptor.bind_group_layouts), ta)
    layouts := make([]Bind_Group_Layout, len(descriptor.bind_group_layouts), impl.allocator)

    for entry, i in descriptor.bind_group_layouts {
        layouts[i] = entry // copy
        vk_bind_group_layout_add_ref(entry, loc)
        entry_impl := get_impl(Vulkan_Bind_Group_Layout_Impl, entry, loc)
        vk_set_layouts[i] = entry_impl.vk_layout
    }

    create_info := vk.PipelineLayoutCreateInfo {
        sType          = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = u32(len(vk_set_layouts)),
        pSetLayouts    = raw_data(vk_set_layouts),
    }

    vk_pipeline_layout: vk.PipelineLayout
    vk_check(vk.CreatePipelineLayout(impl.vk_device, &create_info, nil, &vk_pipeline_layout))

    layout := device_new_handle(Vulkan_Pipeline_Layout_Impl, device, loc)
    layout.layouts = layouts
    layout.vk_pipeline_layout = vk_pipeline_layout

    return Pipeline_Layout(layout)
}

@(require_results)
vk_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    // Basic validation
    assert(descriptor.vertex.module != nil, "Vertex shader module is required", loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    // Initialize builder with defaults
    builder := VULKAN_PIPELINE_BUILDER_DEFAULT

    // Add shader stages
    vertex_module_impl := get_impl(Vulkan_Shader_Module_Impl, descriptor.vertex.module, loc)
    vertex_entry_buf: String_Buffer_Small
    string_buffer_init(&vertex_entry_buf, descriptor.vertex.entry_point)

    vk_pipeline_builder_add_shader_stage(&builder, {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = { .VERTEX },
        module = vertex_module_impl.vk_shader_module,
        pName  = string_buffer_get_cstring(&vertex_entry_buf),
    })

    // Fragment shader stage (optional)
    fragment_entry_buf: String_Buffer_Small
    if descriptor.fragment != nil {
        fragment_module_impl := get_impl(Vulkan_Shader_Module_Impl, descriptor.fragment.module, loc)
        string_buffer_init(&fragment_entry_buf, descriptor.fragment.entry_point)

        vk_pipeline_builder_add_shader_stage(&builder, {
            sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage  = { .FRAGMENT },
            module = fragment_module_impl.vk_shader_module,
            pName  = string_buffer_get_cstring(&fragment_entry_buf),
        })
    }

    // Setup vertex input state
    vertex_binding_descriptions := make([dynamic]vk.VertexInputBindingDescription, ta)
    vertex_attribute_descriptions := make([dynamic]vk.VertexInputAttributeDescription, ta)

    for &buffer, binding_idx in descriptor.vertex.buffers {
        append(&vertex_binding_descriptions, vk.VertexInputBindingDescription{
            binding   = u32(binding_idx),
            stride    = u32(buffer.array_stride),
            inputRate = vk_conv_to_vertex_step_mode(buffer.step_mode),
        })

        for &attrib in buffer.attributes {
            append(&vertex_attribute_descriptions, vk.VertexInputAttributeDescription{
                location = attrib.shader_location,
                binding  = u32(binding_idx),
                format   = vk_conv_to_vertex_format(attrib.format),
                offset   = u32(attrib.offset),
            })
        }
    }

    vk_pipeline_builder_set_vertex_input_state(&builder, {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount   = u32(len(vertex_binding_descriptions)),
        pVertexBindingDescriptions      = raw_data(vertex_binding_descriptions),
        vertexAttributeDescriptionCount = u32(len(vertex_attribute_descriptions)),
        pVertexAttributeDescriptions    = raw_data(vertex_attribute_descriptions),
    })

    // Setup primitive topology
    vk_pipeline_builder_set_primitive_topology(&builder,
        vk_conv_to_primitive_topology(descriptor.primitive.topology))

    builder.input_assembly.primitiveRestartEnable =
        descriptor.primitive.strip_index_format != .Undefined

    // Setup rasterization state
    vk_pipeline_builder_set_polygon_mode(&builder,
        vk_conv_to_polygon_mode(descriptor.primitive.polygon_mode))
    vk_pipeline_builder_set_cull_mode(&builder,
        vk_conv_to_cull_mode_flags(descriptor.primitive.cull_mode))
    vk_pipeline_builder_set_front_face(&builder,
        vk_conv_to_front_face(descriptor.primitive.front_face))

    if descriptor.depth_stencil != nil {
        bias := descriptor.depth_stencil.bias
        builder.rasterization_state.depthBiasEnable = bias.constant != 0 || bias.slope_scale != 0
        builder.rasterization_state.depthBiasConstantFactor = f32(bias.constant)
        builder.rasterization_state.depthBiasClamp = bias.clamp
        builder.rasterization_state.depthBiasSlopeFactor = bias.slope_scale
    }

    // Setup multisample state
    multisample_mask := vk.SampleMask(descriptor.multisample.mask)
    vk_pipeline_builder_set_rasterization_samples(&builder,
        vk_conv_to_sample_count_flags(descriptor.multisample.count), 0.0)
    builder.multisample_state.alphaToCoverageEnable =
        b32(descriptor.multisample.alpha_to_coverage_enabled)
    builder.multisample_state.alphaToOneEnable = false
    builder.multisample_state.pSampleMask =
        &multisample_mask if multisample_mask != 0.0 else nil

    // Setup depth stencil state
    if descriptor.depth_stencil != nil {
        ds := descriptor.depth_stencil
        builder.depth_stencil_state.depthTestEnable =
            b32(ds.depth_compare != .Always || ds.depth_write_enabled)
        builder.depth_stencil_state.depthWriteEnable = b32(ds.depth_write_enabled)
        builder.depth_stencil_state.depthCompareOp = vk_conv_to_compare_op(ds.depth_compare)
        builder.depth_stencil_state.stencilTestEnable = stencil_state_is_enabled(ds.stencil)
        builder.depth_stencil_state.front = vk_conv_to_stencil_front_op_state(ds.stencil)
        builder.depth_stencil_state.back = vk_conv_to_stencil_back_op_state(ds.stencil)

        vk_format := VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT[ds.format]

        if texture_format_has_depth_aspect(ds.format) {
            vk_pipeline_builder_set_depth_attachment_format(&builder, vk_format)
        }

        if texture_format_has_stencil_aspect(ds.format) {
            vk_pipeline_builder_set_stencil_attachment_format(&builder, vk_format)
        }
    }

    // Setup color blend attachments
    color_blend_attachments := make([dynamic]vk.PipelineColorBlendAttachmentState, ta)
    color_attachment_formats := make([dynamic]vk.Format, ta)

    if descriptor.fragment != nil {
        for target in descriptor.fragment.targets {
            blend := vk.PipelineColorBlendAttachmentState{
                blendEnable         = target.blend != nil,
                colorWriteMask      = vk_conv_to_color_component_flags(target.write_mask),
                srcColorBlendFactor = .ONE,
                dstColorBlendFactor = .ZERO,
                colorBlendOp        = .ADD,
                srcAlphaBlendFactor = .ONE,
                dstAlphaBlendFactor = .ZERO,
                alphaBlendOp        = .ADD,
            }

            if blend.blendEnable {
                blend.srcColorBlendFactor = vk_conv_to_blend_factor(target.blend.color.src_factor)
                blend.dstColorBlendFactor = vk_conv_to_blend_factor(target.blend.color.dst_factor)
                blend.colorBlendOp = vk_conv_to_blend_op(target.blend.color.operation)
                blend.srcAlphaBlendFactor = vk_conv_to_blend_factor(target.blend.alpha.src_factor)
                blend.dstAlphaBlendFactor = vk_conv_to_blend_factor(target.blend.alpha.dst_factor)
                blend.alphaBlendOp = vk_conv_to_blend_op(target.blend.alpha.operation)
            }

            append(&color_blend_attachments, blend)
            append(&color_attachment_formats, VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT[target.format])
        }
    }

    vk_pipeline_builder_add_color_attachments(&builder,
        color_blend_attachments[:],
        color_attachment_formats[:],
        loc)

    // Setup dynamic states
    // TODO(Capati): reduce dynamic states?
    dynamic_states := []vk.DynamicState{
        .VIEWPORT,
        .SCISSOR,
        .DEPTH_BIAS,
        .BLEND_CONSTANTS,
        .DEPTH_TEST_ENABLE,
        .DEPTH_WRITE_ENABLE,
        .DEPTH_COMPARE_OP,
        .DEPTH_BIAS_ENABLE,
        .STENCIL_REFERENCE,
    }
    vk_pipeline_builder_add_dynamic_states(&builder, dynamic_states, loc)

    // Get or create pipeline layout
    pipeline_layout_impl: ^Vulkan_Pipeline_Layout_Impl
    if descriptor.layout != nil {
        pipeline_layout_impl = get_impl(Vulkan_Pipeline_Layout_Impl, descriptor.layout, loc)
        vk_pipeline_layout_add_ref(descriptor.layout, loc)
    } else {
        // Create empty pipeline layout
        layout_create_info := vk.PipelineLayoutCreateInfo{
            sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
            setLayoutCount         = 0,
            pSetLayouts            = nil,
            pushConstantRangeCount = 0,
            pPushConstantRanges    = nil,
        }
        vk_pipeline_layout: vk.PipelineLayout
        vk_check(vk.CreatePipelineLayout(impl.vk_device, &layout_create_info, nil, &vk_pipeline_layout))
        pipeline_layout_impl = device_new_handle(Vulkan_Pipeline_Layout_Impl, device, loc)
        pipeline_layout_impl.vk_pipeline_layout = vk_pipeline_layout
    }

    // Build the pipeline
    vk_pipeline := vk_pipeline_builder_build(
        &builder,
        impl.vk_device,
        {},  // pipeline_cache
        pipeline_layout_impl.vk_pipeline_layout,
        descriptor.label,
        loc,
    )

    pipeline := device_new_handle(Vulkan_Render_Pipeline_Impl, device, loc)
    pipeline.vk_pipeline = vk_pipeline
    pipeline.pipeline_layout = pipeline_layout_impl

    return Render_Pipeline(pipeline)
}

@(require_results)
vk_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    anisotropy_enable := descriptor.anisotropy_clamp > 1
    compare_enable := descriptor.compare != .Undefined

    create_info := vk.SamplerCreateInfo {
        sType            = .SAMPLER_CREATE_INFO,
        compareEnable    = b32(compare_enable),
        compareOp        = compare_enable ? vk_conv_to_compare_op(descriptor.compare) : .NEVER,
        maxLod           = descriptor.lod_max_clamp,
        minLod           = descriptor.lod_min_clamp,
        addressModeU     = vk_conv_to_sampler_address_mode(descriptor.address_mode_u),
        addressModeV     = vk_conv_to_sampler_address_mode(descriptor.address_mode_v),
        addressModeW     = vk_conv_to_sampler_address_mode(descriptor.address_mode_w),
        mipmapMode       = descriptor.mipmap_filter == .Linear ? .LINEAR : .NEAREST,
        anisotropyEnable = b32(anisotropy_enable),
        maxAnisotropy    = anisotropy_enable ? f32(descriptor.anisotropy_clamp) : 1.0,
        magFilter        = descriptor.mag_filter == .Linear ? .LINEAR : .NEAREST,
        minFilter        = descriptor.min_filter == .Linear ? .LINEAR : .NEAREST,
    }

    vk_sampler: vk.Sampler
    vk_check(vk.CreateSampler(impl.vk_device, &create_info, nil, &vk_sampler), loc = loc)

    sampler := device_new_handle(Vulkan_Sampler_Impl, device, loc)
    sampler.vk_sampler = vk_sampler

    if len(descriptor.label) > 0 {
        vk_sampler_set_label(Sampler(sampler), descriptor.label, loc)
    }

    return Sampler(sampler)
}

@(require_results)
vk_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    assert(len(descriptor.code) > 0, "Shader code is empty", loc)
    assert(len(descriptor.code) >= 4, "Shader bytecode too small to be valid", loc)

    code := slice.reinterpret([]u32, descriptor.code)
    create_info := vk.ShaderModuleCreateInfo {
        sType    = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(code) * 4,
        pCode    = raw_data(code),
    }

    vk_shader_module: vk.ShaderModule
    vk_check(vk.CreateShaderModule(impl.vk_device, &create_info, nil, &vk_shader_module))

    shader_module := device_new_handle(Vulkan_Shader_Module_Impl, device, loc)
    shader_module.vk_shader_module = vk_shader_module

    return Shader_Module(shader_module)
}

vk_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    impl := get_impl(Vulkan_Device_Impl, device, loc)

    texture_descriptor_validade(descriptor, impl.features, loc)

    // Convert texture format to Vulkan format
    vk_format := VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT[descriptor.format]

    // Get format properties from device
    vk_format_properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(impl.vk_physical_device, vk_format, &vk_format_properties)

    // Map dimension to Vulkan image type and flags
    vk_image_type: vk.ImageType
    vk_image_view_type: vk.ImageViewType
    vk_create_flags: vk.ImageCreateFlags
    array_layers := descriptor.size.depth_or_array_layers
    depth : u32 = 1

    #partial switch descriptor.dimension {
    case .D1:
        vk_image_type = .D1
        vk_image_view_type = array_layers > 1 ? .D1_ARRAY : .D1
        assert(descriptor.size.height == 1, "1D texture height must be 1", loc)

    case .D2:
        vk_image_type = .D2
        vk_image_view_type = array_layers > 1 ? .D2_ARRAY : .D2
        depth = 1

    case .D3:
        vk_image_type = .D3
        vk_image_view_type = .D3
        depth = descriptor.size.depth_or_array_layers
        array_layers = 1
    case:
        unreachable()
    }

    // Convert sample count to Vulkan sample count
    vk_samples := vk_conv_to_sample_count_flags(descriptor.sample_count)

    // Build Vulkan usage flags from descriptor usage
    vk_usage: vk.ImageUsageFlags

    if .Copy_Src in descriptor.usage {
        vk_usage |= { .TRANSFER_SRC }
    }

    if .Copy_Dst in descriptor.usage {
        vk_usage |= { .TRANSFER_DST }
    }

    if .Texture_Binding in descriptor.usage {
        vk_usage |= { .SAMPLED }
    }

    if .Storage_Binding in descriptor.usage {
        assert(descriptor.sample_count == 1, "Storage textures cannot be multisampled", loc)
        vk_usage |= { .STORAGE }
    }

    // Note: Vulkan doesn't have separate atomic flag, just storage
    if .Storage_Atomic in descriptor.usage {
        assert(descriptor.sample_count == 1, "Storage textures cannot be multisampled", loc)
        vk_usage |= { .STORAGE }
    }

    if .Render_Attachment in descriptor.usage {
        if texture_format_is_depth_stencil_format(descriptor.format) {
            vk_usage |= {.DEPTH_STENCIL_ATTACHMENT}
        } else {
            vk_usage |= {.COLOR_ATTACHMENT}
        }
    }

    // Always add transfer capabilities for internal operations if not memoryless
    // This allows for texture uploads, downloads, and mipmap generation
    if .Render_Attachment in descriptor.usage ||
       .Texture_Binding in descriptor.usage ||
       .Storage_Binding in descriptor.usage {
        vk_usage |= { .TRANSFER_SRC, .TRANSFER_DST }
    }

    assert(vk_usage != {}, "No valid usage flags specified", loc)

    vk_extent := vk.Extent3D {
        width = descriptor.size.width,
        height = descriptor.size.height,
        depth = depth,
    }

    image_create_info := vk.ImageCreateInfo {
        sType         = .IMAGE_CREATE_INFO,
        flags         = vk_create_flags,
        imageType     = vk_image_type,
        format        = vk_format,
        extent        = vk_extent,
        mipLevels     = descriptor.mip_level_count,
        arrayLayers   = array_layers,
        samples       = vk_samples,
        tiling        = .OPTIMAL,
        usage         = vk_usage,
        sharingMode   = .EXCLUSIVE,
        initialLayout = .UNDEFINED,
    }

    vma_alloc_info := vma.Allocation_Create_Info {
        usage = .Auto,  // Let VMA decide optimal memory type
    }

    // Allocate the image
    vk_image: vk.Image
    vma_allocation: vma.Allocation
    vk_check(vma.create_image(
        impl.vma_allocator, image_create_info, vma_alloc_info, &vk_image, &vma_allocation, nil))

    texture := device_new_handle(Vulkan_Texture_Impl, device, loc)

    // Set base fields
    texture.usage                 = descriptor.usage
    texture.dimension             = descriptor.dimension
    texture.size                  = descriptor.size
    texture.format                = descriptor.format
    texture.mip_level_count       = descriptor.mip_level_count
    texture.sample_count          = descriptor.sample_count
    texture.array_layer_count     = array_layers
    texture.is_swapchain          = false

    // Set backend fields
    texture.vk_image              = vk_image
    texture.vk_usage_flags        = vk_usage
    texture.vk_format_properties  = vk_format_properties
    texture.vk_extent             = vk_extent
    texture.vk_type               = vk_image_type
    texture.vk_image_format       = vk_format
    texture.vk_samples            = vk_samples
    texture.vma_allocation        = vma_allocation
    texture.mapped_ptr            = nil  // Not mapped by default
    texture.is_owning_vk_image    = true
    texture.is_resolve_attachment = false
    texture.num_levels            = descriptor.mip_level_count
    texture.num_layers            = array_layers
    texture.is_depth_format       = texture_format_has_depth_aspect(descriptor.format)
    texture.is_stencil_format     = texture_format_has_stencil_aspect(descriptor.format)
    texture.vk_image_layout       = .UNDEFINED
    texture.vk_image_view         = {}
    texture.vk_image_view_storage = {}
    texture.is_swapchain_image    = false
    texture.surface               = {}

    if len(descriptor.label) > 0 {
        vk_texture_set_label(Texture(texture), descriptor.label, loc)
    }

    return Texture(texture)
}

@(require_results)
vk_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    return Queue(impl.queue)
}

@(require_results)
vk_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    return string_buffer_get_string(&impl.label)
}

vk_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    string_buffer_init(&impl.label, label)
}

vk_device_add_ref :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    ref_count_add(&impl.ref, loc)
}

vk_device_release :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(Vulkan_Device_Impl, device, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        vk.DeviceWaitIdle(impl.vk_device)

        vk_command_encoder_wait_all(&impl.encoder, loc)

        for &buf in impl.encoder.buffers {
            vk_deletion_queue_destroy(&buf.resources)
            vk.DestroyFence(impl.vk_device, buf.vk_fence, nil)
            vk.DestroySemaphore(impl.vk_device, buf.vk_semaphore, nil)
        }
        vk.DestroyCommandPool(impl.vk_device, impl.encoder.vk_command_pool, nil)

        vk_descriptor_allocator_destroy(&impl.descriptor_allocator)

        vma.destroy_allocator(impl.vma_allocator)

        vk.DestroyDevice(impl.vk_device, nil)

        delete(impl.queue.pending_writes)
        free(impl.queue)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Instance procedures
// -----------------------------------------------------------------------------


Vulkan_Instance_Impl :: struct {
    // Base
    using base:           Instance_Base,

    // Library
    lib:                  Vulkan_Library,

    // Initialization
    vk_instance:          vk.Instance,
    vk_debug_messenger:   vk.DebugUtilsMessengerEXT,
    instance_version:     u32,
    api_version:          u32,
    swapchain_colorspace: bool,
    headless:             bool,
}

@(require_results)
vk_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    impl := get_impl(Vulkan_Instance_Impl, instance, loc)

    vk_surface: vk.SurfaceKHR
    res := vk.Result.ERROR_INITIALIZATION_FAILED

    if impl.headless {
        ci := vk.HeadlessSurfaceCreateInfoEXT {
            sType = .HEADLESS_SURFACE_CREATE_INFO_EXT,
        }
        res = vk.CreateHeadlessSurfaceEXT(impl.vk_instance, &ci, nil, &vk_surface)
    } else {
        switch &t in descriptor.target {
        case Surface_Source_Android_Native_Window:
            unimplemented(loc = loc)
            // create_info := vk.AndroidSurfaceCreateInfoKHR {
            //      sType  = .ANDROID_SURFACE_CREATE_INFO_KHR,
            //      window = cast(^vk.ANativeWindow)t.window,
            // }
            // res = vk.CreateAndroidSurfaceKHR(impl.vk_instance, &create_info, nil, &vk_surface)

        case Surface_Source_Canvas_HTML_Selector:
            unimplemented(loc = loc)

        case Surface_Source_Metal_Layer:
            create_info := vk.MetalSurfaceCreateInfoEXT {
                sType  = .METAL_SURFACE_CREATE_INFO_EXT,
                pLayer = cast(^vk.CAMetalLayer)t.layer,
            }
            res = vk.CreateMetalSurfaceEXT(impl.vk_instance, &create_info, nil, &vk_surface)

        case Surface_Source_Wayland_Surface:
            create_info := vk.WaylandSurfaceCreateInfoKHR {
                sType   = .WAYLAND_SURFACE_CREATE_INFO_KHR,
                display = cast(^vk.wl_display)t.display,
                surface = cast(^vk.wl_surface)t.surface,
            }
            res = vk.CreateWaylandSurfaceKHR(impl.vk_instance, &create_info, nil, &vk_surface)

        case Surface_Source_Windows_HWND:
            assert(t.hinstance != nil, loc = loc)
            assert(t.hwnd != nil, loc = loc)
            create_info := vk.Win32SurfaceCreateInfoKHR {
                sType     = .WIN32_SURFACE_CREATE_INFO_KHR,
                hinstance = vk.HINSTANCE(t.hinstance),
                hwnd      = vk.HWND(t.hwnd),
            }
            res = vk.CreateWin32SurfaceKHR(impl.vk_instance, &create_info, nil, &vk_surface)

        case Surface_Source_Xcb_Window:
            create_info := vk.XcbSurfaceCreateInfoKHR {
                sType      = .XCB_SURFACE_CREATE_INFO_KHR,
                connection = cast(^vk.xcb_connection_t)t.connection,
                window     = t.window,
            }
            res = vk.CreateXcbSurfaceKHR(impl.vk_instance, &create_info, nil, &vk_surface)

        case Surface_Source_Xlib_Window:
            create_info := vk.XlibSurfaceCreateInfoKHR {
                sType  = .XLIB_SURFACE_CREATE_INFO_KHR,
                dpy    = cast(^vk.XlibDisplay)t.display,
                window = cast(vk.XlibWindow)t.window,
            }
            res = vk.CreateXlibSurfaceKHR(impl.vk_instance, &create_info, nil, &vk_surface)
        }
    }

    if res != .SUCCESS {
        log.errorf("[VK]: Failed to create surface: %v", res)
        return nil
    }

    surface := instance_new_handle(Vulkan_Surface_Impl, instance, loc)
    surface.vk_surface = vk_surface
    surface.swapchain_colorspace = impl.swapchain_colorspace

    if len(descriptor.label) > 0 {
        string_buffer_init(&surface.label, descriptor.label)
    }

    return Surface(surface)
}

vk_instance_request_adapter :: proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
) {
    assert(callback_info.callback != nil, "No callback provided", loc)

    impl := get_impl(Vulkan_Instance_Impl, instance, loc)
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

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator == ta)

    // Get available physical devices
    device_count: u32
    vk_check(vk.EnumeratePhysicalDevices(impl.vk_instance, &device_count, nil))
    physical_devices := make([]vk.PhysicalDevice, device_count, ta)
    vk_check(vk.EnumeratePhysicalDevices(impl.vk_instance, &device_count, raw_data(physical_devices)))

    check_surface_support :: proc(
        device: vk.PhysicalDevice,
        options: Request_Adapter_Options,
        loc := #caller_location,
    ) -> bool {
        ta := context.temp_allocator

        queue_family_count: u32
        vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
        if queue_family_count == 0 {
            return false
        }

        queue_families := make([]vk.QueueFamilyProperties, queue_family_count, ta)
        vk.GetPhysicalDeviceQueueFamilyProperties(
            device, &queue_family_count, raw_data(queue_families))

        graphics_family_found: bool
        present_family_found: bool

        for family, i in queue_families {
            if .GRAPHICS in family.queueFlags {
                graphics_family_found = true
            }

            surface_impl := get_impl(Vulkan_Surface_Impl, options.compatible_surface, loc)
            present_support: b32
            vk.GetPhysicalDeviceSurfaceSupportKHR(
                device,
                u32(i),
                surface_impl.vk_surface,
                &present_support,
            )
            if present_support {
                present_family_found = true
            }
        }

        return graphics_family_found && present_family_found
    }

    rate_device_suitability :: proc(
        device: vk.PhysicalDevice,
        options: Request_Adapter_Options,
    ) -> int {
        properties: vk.PhysicalDeviceProperties
        features: vk.PhysicalDeviceFeatures

        vk.GetPhysicalDeviceProperties(device, &properties)
        vk.GetPhysicalDeviceFeatures(device, &features)

        score := 0

        // Prefer discrete GPUs for high performance
        if options.power_preference == .High_Performance {
            #partial switch properties.deviceType {
            case .DISCRETE_GPU:   score += 1000
            case .INTEGRATED_GPU: score += 100
            case .VIRTUAL_GPU:    score += 50
            case .CPU:            score += 10
            }
        } else {
            // Low_Power preference
            #partial switch properties.deviceType {
            case .INTEGRATED_GPU: score += 1000
            case .DISCRETE_GPU:   score += 100
            case .VIRTUAL_GPU:    score += 50
            case .CPU:            score += 10
            }
        }

        // Handle fallback adapter preference
        if options.force_fallback_adapter {
            // Prefer software/CPU rendering or basic devices
            if properties.deviceType == .CPU {
                score += 2000
            }
        }

        // Additional scoring based on device limits
        score += int(properties.limits.maxImageDimension2D >> 12)
        score += int(properties.limits.maxComputeWorkGroupCount[0] >> 16)

        return score
    }

    // Find best adapter based on preferences
    vk_physical_device: vk.PhysicalDevice
    best_score := -1
    suitable_devices_found: int

    for pd in physical_devices {
        if opts.compatible_surface != nil && !check_surface_support(pd, opts, loc) {
            continue
        }

        suitable_devices_found += 1
        score := rate_device_suitability(pd, opts)
        if score > best_score {
            best_score = score
            vk_physical_device = pd
        }
    }

    if suitable_devices_found == 0 || vk_physical_device == nil {
        error_msg := "No suitable physical devices found for the given options"
        invoke_callback(callback_info, .Unavailable, nil, error_msg)
        return
    }

    adapter := instance_new_handle(Vulkan_Adapter_Impl, instance, loc)
    adapter.vk_physical_device = vk_physical_device

    vk_instance_adapter_default_impl(adapter)

    invoke_callback(callback_info, .Success, Adapter(adapter), "")
}

@private
vk_instance_adapter_default_impl :: proc(impl: ^Vulkan_Adapter_Impl) {
    impl.backend = .Vulkan
    impl.shader_formats = { .Spirv }

    // Get supported features
    impl.features_13 = vk.PhysicalDeviceVulkan13Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    }
    impl.features_12 = vk.PhysicalDeviceVulkan12Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        pNext = &impl.features_13,
    }
    impl.features_11 = vk.PhysicalDeviceVulkan11Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
        pNext = &impl.features_12,
    }
    supported_features := vk.PhysicalDeviceFeatures2 {
        sType = .PHYSICAL_DEVICE_FEATURES_2,
        pNext = &impl.features_11,
    }
    vk.GetPhysicalDeviceFeatures2(impl.vk_physical_device, &supported_features)
    impl.features_10 = supported_features.features

    // Fill api features and limits
    impl.features = vk_adapter_get_features_impl(impl)
    impl.limits = vk_adapter_get_limits_impl(impl)
}

@(require_results)
vk_instance_get_label :: proc(instance: Instance, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Instance_Impl, instance, loc)
    return string_buffer_get_string(&impl.label)
}

vk_instance_set_label :: proc(instance: Instance, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Instance_Impl, instance, loc)
    string_buffer_init(&impl.label, label)
}

vk_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    impl := get_impl(Vulkan_Instance_Impl, instance, loc)
    ref_count_add(&impl.ref, loc)
}

vk_instance_release :: proc(instance: Instance, loc := #caller_location) {
    impl := get_impl(Vulkan_Instance_Impl, instance, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.vk_debug_messenger != 0 {
            vk.DestroyDebugUtilsMessengerEXT(impl.vk_instance, impl.vk_debug_messenger, nil)
        }
        vk.DestroyInstance(impl.vk_instance, nil)

        // Unload the Vulkan library
        if impl.lib.did_load && impl.lib.library != nil {
            dynlib.unload_library(impl.lib.library)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------


Vulkan_Device_Queue_Kind :: enum {
    Graphics,
    Compute,
}

Vulkan_Device_Queue :: struct {
    index: u32,
    queue: vk.Queue,
}

Vulkan_Pending_Write :: struct {
    staging_buffer: Buffer,
}

Vulkan_Queue_Impl :: struct {
    // Base
    using base:        Queue_Base,

    // Initialization
    queues:            [Vulkan_Device_Queue_Kind]Vulkan_Device_Queue,

    // Pending writes
    pending_writes:    [dynamic]Vulkan_Pending_Write,
    pending_write_cmd: ^Vulkan_Command_Buffer_Impl,
}

vk_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    impl := get_impl(Vulkan_Queue_Impl, queue, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    pending_commands: sa.Small_Array(VK_MAX_COMMAND_BUFFERS, Command_Buffer)

    // Finish pending write command if exists
    pending_write_cmd: Command_Buffer
    if impl.pending_write_cmd != nil {
        pending_write_cmd = vk_command_encoder_finish(Command_Encoder(impl.pending_write_cmd), loc)
        sa.push_back(&pending_commands, pending_write_cmd)
        impl.pending_write_cmd = nil
    }

    assert(sa.len(pending_commands) + len(commands) <= VK_MAX_COMMAND_BUFFERS,
        "Too many command buffers", loc)

    sa.push_back_elems(&pending_commands, ..commands)

    // Allow empty submit (to flush pending writes)
    if sa.len(pending_commands) == 0 {
        return
    }

    // Process each command buffer
    for cmd in sa.slice(&pending_commands) {
        cmd_buf_impl := get_impl(Vulkan_Command_Buffer_Impl, cmd, loc)

        assert(cmd_buf_impl != nil, "Command buffer is invalid", loc)
        assert(cmd_buf_impl.is_encoding == false, "Command buffer is still encoding", loc)
        assert(cmd_buf_impl.vk_cmd_buf != nil, "Command buffer is invalid", loc)

        // Build wait semaphores (max 2: user wait + last submit)
        wait_semaphores: sa.Small_Array(2, vk.SemaphoreSubmitInfo)

        // Add user wait semaphore if set
        if device_impl.encoder.wait_semaphore.semaphore != {} {
            sa.push_back(&wait_semaphores, device_impl.encoder.wait_semaphore)
        }

        // Add last submit semaphore (for automatic dependency chain)
        if device_impl.encoder.last_submit_semaphore.semaphore != {} {
            sa.push_back(&wait_semaphores, device_impl.encoder.last_submit_semaphore)
        }

        // Build signal semaphores (max 2: buffer semaphore + user signal)
        signal_semaphores: sa.Small_Array(2, vk.SemaphoreSubmitInfo)

        // Always signal this buffer's semaphore
        sa.push_back(&signal_semaphores, vk.SemaphoreSubmitInfo{
            sType     = .SEMAPHORE_SUBMIT_INFO,
            semaphore = cmd_buf_impl.vk_semaphore,
            stageMask = { .ALL_COMMANDS },
        })

        // Add user signal semaphore if set
        if device_impl.encoder.signal_semaphore.semaphore != {} {
            sa.push_back(&signal_semaphores, device_impl.encoder.signal_semaphore)
        }

         // Command buffer submit info
        buffer_submit_info := vk.CommandBufferSubmitInfo{
            sType         = .COMMAND_BUFFER_SUBMIT_INFO,
            commandBuffer = cmd_buf_impl.vk_cmd_buf,
        }

        // Submit info
        submit_info := vk.SubmitInfo2 {
            sType                    = .SUBMIT_INFO_2,
            waitSemaphoreInfoCount   = u32(sa.len(wait_semaphores)),
            pWaitSemaphoreInfos      = raw_data(sa.slice(&wait_semaphores)),
            commandBufferInfoCount   = 1,
            pCommandBufferInfos      = &buffer_submit_info,
            signalSemaphoreInfoCount = u32(sa.len(signal_semaphores)),
            pSignalSemaphoreInfos    = raw_data(sa.slice(&signal_semaphores)),
        }

        // Submit to queue
        vk_check(vk.QueueSubmit2(
            impl.queues[.Graphics].queue, 1, &submit_info, cmd_buf_impl.vk_fence))

        device_impl.encoder.last_submit_semaphore.semaphore = cmd_buf_impl.vk_semaphore
        device_impl.encoder.last_submit_handle = cmd_buf_impl.handle
        device_impl.encoder.wait_semaphore.semaphore = {}
        device_impl.encoder.signal_semaphore.semaphore = {}

        // Reset
        device_impl.encoder.submit_counter += 1
        if device_impl.encoder.submit_counter == 0 {
            device_impl.encoder.submit_counter = 1 // Skip 0 value when wrapping around
        }
    }

    // Clean up staging buffers after submit
    for &write in impl.pending_writes {
        vk_buffer_release(write.staging_buffer, loc)
    }
    clear(&impl.pending_writes)
}

vk_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    assert(queue != nil, "Invalid queue", loc)
    assert(buffer != nil, "Invalid buffer", loc)
    assert(data != nil, "Invalid data pointer", loc)
    assert(size > 0, "Size must be greater than 0", loc)

    impl := get_impl(Vulkan_Queue_Impl, queue, loc)
    buffer_impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    assert(buffer_offset + u64(size) <= buffer_impl.size, "Write exceeds buffer size", loc)

    // Get memory properties for this buffer's memory type
    mem_props: vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(device_impl.vk_physical_device, &mem_props)

    memory_type_props := mem_props.memoryTypes[buffer_impl.vma_alloc_info.memory_type].propertyFlags

    // Check if buffer is host-visible
    if .HOST_VISIBLE in memory_type_props {
        // Directly map and copy (immediate, no GPU work needed)
        mapped_data: rawptr
        vk_check(vma.map_memory(
            device_impl.vma_allocator, buffer_impl.vma_allocation, &mapped_data), loc = loc)
        defer vma.unmap_memory(device_impl.vma_allocator, buffer_impl.vma_allocation)

        if mapped_data != nil {
            dst := mem.ptr_offset(cast(^u8)mapped_data, int(buffer_offset))
            mem.copy(dst, data, int(size))

            // Flush if not coherent
            if .HOST_COHERENT not_in memory_type_props {
                vma.flush_allocation(
                    device_impl.vma_allocator,
                    buffer_impl.vma_allocation,
                    vk.DeviceSize(buffer_offset),
                    vk.DeviceSize(size),
                )
            }
        }
    } else {
        // Create staging buffer
        staging_desc := Buffer_Descriptor{
            label = "Queue write buffer",
            size  = u64(size),
            usage = { .Map_Write, .Copy_Src },
        }

        staging_buffer := vk_device_create_buffer(impl.device, staging_desc, loc)
        staging_impl := get_impl(Vulkan_Buffer_Impl, staging_buffer, loc)

        // Get staging buffer memory properties
        staging_memory_type_props :=
            mem_props.memoryTypes[staging_impl.vma_alloc_info.memory_type].propertyFlags

        // Copy data to staging immediately (synchronous)
        mapped_data: rawptr
        vk_check(vma.map_memory(
            device_impl.vma_allocator, staging_impl.vma_allocation, &mapped_data), loc = loc)
        mem.copy(mapped_data, data, int(size))
        vma.unmap_memory(device_impl.vma_allocator, staging_impl.vma_allocation)

        // Flush if needed
        if .HOST_COHERENT not_in staging_memory_type_props {
            vma.flush_allocation(
                device_impl.vma_allocator, staging_impl.vma_allocation, 0, vk.DeviceSize(size))
        }

        // Create or reuse command encoder for pending writes
        if impl.pending_write_cmd == nil {
            impl.pending_write_cmd =
                cast(^Vulkan_Command_Buffer_Impl)vk_device_create_command_encoder(impl.device, {}, loc)
        }

        // Record GPU copy command (deferred)
        vk_command_encoder_copy_buffer_to_buffer(
            Command_Encoder(impl.pending_write_cmd),
            staging_buffer,
            0,
            buffer,
            buffer_offset,
            u64(size),
            loc,
        )

        // Track staging buffer to keep it alive until submit
        append(&impl.pending_writes, Vulkan_Pending_Write {
            staging_buffer = staging_buffer,
        })
    }
}

vk_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    assert(queue != nil, "Invalid queue", loc)
    assert(destination.texture != nil, "Invalid destination texture", loc)
    assert(len(data) > 0, "Data size must be greater than 0", loc)

    // Early exit if nothing to write
    if write_size.width == 0 || write_size.height == 0 || write_size.depth_or_array_layers == 0 {
        return
    }

    queue_impl := get_impl(Vulkan_Queue_Impl, queue, loc)
    // texture_impl := get_impl(Vulkan_Texture_Impl, destination.texture, loc)
    device_impl := get_impl(Vulkan_Device_Impl, queue_impl.device, loc)

    // Create staging buffer
    staging_desc := Buffer_Descriptor{
        label = "Queue write texture staging",
        size  = u64(len(data)),
        usage = {.Copy_Src, .Map_Write},
    }

    staging_buffer := vk_device_create_buffer(queue_impl.device, staging_desc, loc)
    staging_impl := get_impl(Vulkan_Buffer_Impl, staging_buffer, loc)

    // Get memory properties
    mem_props: vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(device_impl.vk_physical_device, &mem_props)

    staging_memory_type_props :=
        mem_props.memoryTypes[staging_impl.vma_alloc_info.memory_type].propertyFlags

    // Copy data to staging buffer (synchronous)
    mapped_data: rawptr
    vk_check(vma.map_memory(
        device_impl.vma_allocator, staging_impl.vma_allocation, &mapped_data), loc = loc)
    mem.copy(mapped_data, raw_data(data), len(data))
    vma.unmap_memory(device_impl.vma_allocator, staging_impl.vma_allocation)

    // Flush if needed
    if .HOST_COHERENT not_in staging_memory_type_props {
        vma.flush_allocation(
            device_impl.vma_allocator,
            staging_impl.vma_allocation,
            0,
            vk.DeviceSize(len(data)),
        )
    }

    // Create or reuse command encoder for pending writes
    if queue_impl.pending_write_cmd == nil {
        queue_impl.pending_write_cmd =
            cast(^Vulkan_Command_Buffer_Impl)vk_device_create_command_encoder(
                queue_impl.device, {}, loc,
            )
    }

    // Record GPU copy command (deferred)
    source := Texel_Copy_Buffer_Info{
        buffer = staging_buffer,
        layout = data_layout,
    }

    vk_command_encoder_copy_buffer_to_texture(
        Command_Encoder(queue_impl.pending_write_cmd),
        source,
        destination,
        write_size,
        loc,
    )

    // Track staging buffer to keep it alive until submit
    append(&queue_impl.pending_writes, Vulkan_Pending_Write{
        staging_buffer = staging_buffer,
    })
}

@(require_results)
vk_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Instance_Impl, queue, loc)
    return string_buffer_get_string(&impl.label)
}

vk_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Instance_Impl, queue, loc)
    string_buffer_init(&impl.label, label)
}

vk_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    impl := get_impl(Vulkan_Instance_Impl, queue, loc)
    ref_count_add(&impl.ref, loc)
}

@(disabled = true)
vk_queue_release :: proc(queue: Queue, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Render Pass procedures
// -----------------------------------------------------------------------------


Vulkan_Render_Pass_Impl :: struct {
    // Base
    using base: Render_Pass_Base,
}

vk_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    vk.CmdDraw(
        impl.vk_cmd_buf,
        vertices.end - vertices.start,
        instances.end - instances.start,
        vertices.start,
        instances.start,
    )
}

vk_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    vk.CmdDrawIndexed(
        impl.vk_cmd_buf,
        indices.end - indices.start,
        instances.end - instances.start,
        indices.start,
        base_vertex,
        instances.start,
    )
}

vk_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    assert(impl.is_rendering, "Attempt to finish render pass that is not rendering", loc)

    impl.is_rendering = false
    vk.CmdEndRendering(impl.vk_cmd_buf)

    // Transition swapchain images to PRESENT_SRC_KHR
    color_attachments := sa.slice(&impl.color_attachments)
    for attachment in color_attachments {
        texture_view := get_impl(Vulkan_Texture_View_Impl, attachment.view, loc)
        texture := get_impl(Vulkan_Texture_Impl, texture_view.texture, loc)
        if texture.is_swapchain_image {
            subresource_range := vk.ImageSubresourceRange{
                aspectMask     = {.COLOR},
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            }

            vk_texture_transition_layout(
                texture,
                impl.vk_cmd_buf,
                .PRESENT_SRC_KHR,
                subresource_range,
            )
        }
    }
}

vk_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    assert(impl.is_rendering, "Attempt to set render pass bind group that is not rendering", loc)

    // Check if we have a bound pipeline first
    assert(impl.current_pipeline_graphics != nil, "No render pipeline bound", loc)

    group_impl := get_impl(Vulkan_Bind_Group_Impl, group, loc)

    // Bind the descriptor set
    vk.CmdBindDescriptorSets(
        impl.vk_cmd_buf,
        .GRAPHICS,
        impl.current_pipeline_graphics.pipeline_layout.vk_pipeline_layout,
        group_index,
        1,
        &group_impl.vk_descriptor_set,
        u32(len(dynamic_offsets)),
        raw_data(dynamic_offsets) if len(dynamic_offsets) > 0 else nil,
    )

    vk_deletion_queue_push(&impl.resources, group_impl)
}

vk_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid index buffer", loc)
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    buffer_impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    device_impl := get_impl(Vulkan_Device_Impl, buffer_impl.device, loc)
    vk_deletion_queue_push(&impl.resources, buffer_impl)

    vk_offset := vk.DeviceSize(offset)
    vk_size: vk.DeviceSize

    if size == WHOLE_SIZE {
        vk_size = buffer_impl.vk_device_size - vk_offset
    } else {
        vk_size = vk.DeviceSize(size)
        assert(vk_offset + vk_size <= buffer_impl.vk_device_size,
               "Index buffer offset + size exceeds buffer capacity", loc)
    }

    if device_impl.has_KHR_maintenance5 {
        vk.CmdBindIndexBuffer2KHR(
            impl.vk_cmd_buf,
            buffer_impl.vk_buffer,
            vk_offset,
            vk_size,
            vk_conv_to_index_type(format),
        )
    } else {
        vk.CmdBindIndexBuffer(
            impl.vk_cmd_buf,
            buffer_impl.vk_buffer,
            vk_offset,
            vk_conv_to_index_type(format),
        )
    }
}

vk_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    assert(pipeline != nil, "Invalid render pipeline", loc)
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    pipeline_impl := get_impl(Vulkan_Render_Pipeline_Impl, pipeline, loc)

    impl.current_pipeline_graphics = pipeline_impl
    vk_deletion_queue_push(&impl.resources, pipeline_impl)

    vk.CmdBindPipeline(impl.vk_cmd_buf, .GRAPHICS, pipeline_impl.vk_pipeline)
}

vk_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    scissor := vk.Rect2D {
        offset = { i32(x), i32(y) },
        extent = { width, height },
    }
    vk.CmdSetScissor(impl.vk_cmd_buf, 0, 1, &scissor)
}

vk_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    vk.CmdSetStencilReference(impl.vk_cmd_buf, { .FRONT, .BACK }, reference)
}

vk_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid vertex buffer", loc)
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    buffer_impl := get_impl(Vulkan_Buffer_Impl, buffer, loc)
    vk_deletion_queue_push(&impl.resources, buffer_impl)

    vk_offset := vk.DeviceSize(offset)
    vk_size: vk.DeviceSize

    if size == WHOLE_SIZE {
        vk_size = buffer_impl.vk_device_size - vk_offset
    } else {
        vk_size = vk.DeviceSize(size)
        assert(vk_offset + vk_size <= buffer_impl.vk_device_size,
               "Vertex buffer offset + size exceeds buffer capacity", loc)
    }

    vk.CmdBindVertexBuffers2(
        impl.vk_cmd_buf, slot, 1, &buffer_impl.vk_buffer, &vk_offset, &vk_size, nil)
}

vk_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    // https://www.saschawillems.de/blog/2019/03/29/flipping-the-vulkan-viewport/
    impl := get_impl(Vulkan_Command_Buffer_Impl, render_pass, loc)
    vp := vk.Viewport {
        x        = x,
        y        = height - y,
        width    = width,
        height   = -height,
        minDepth = min_depth,
        maxDepth = max_depth,
    }
    vk.CmdSetViewport(impl.vk_cmd_buf, 0, 1, &vp)
}

@(require_results)
vk_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    return ""
}

vk_render_pass_set_label :: proc(render_pass: Render_Pass, label: string, loc := #caller_location) {
}

@(disabled = true)
vk_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
}

@(disabled = true)
vk_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------


Vulkan_Render_Pipeline_Impl :: struct {
    // Base
    using base:      Render_Pipeline_Base,

    // Initialization
    vk_pipeline:     vk.Pipeline,
    pipeline_layout: ^Vulkan_Pipeline_Layout_Impl,
}

@(require_results)
vk_render_pipeline_get_label :: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string {
    impl := get_impl(Vulkan_Render_Pipeline_Impl, render_pipeline, loc)
    return string_buffer_get_string(&impl.label)
}

vk_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Render_Pipeline_Impl, render_pipeline, loc)
    string_buffer_init(&impl.label, label)
}

vk_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(Vulkan_Render_Pipeline_Impl, render_pipeline, loc)
    ref_count_add(&impl.ref, loc)
}

vk_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(Vulkan_Render_Pipeline_Impl, render_pipeline, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        if impl.pipeline_layout != nil {
            vk_pipeline_layout_release(Pipeline_Layout(impl.pipeline_layout))
        }
        vk.DestroyPipeline(device_impl.vk_device, impl.vk_pipeline, nil)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Pipeline Layout procedures
// -----------------------------------------------------------------------------


Vulkan_Pipeline_Layout_Impl :: struct {
    // Base
    using base:         Pipeline_Layout_Base,

    // Initialization
    layouts:            []Bind_Group_Layout,
    vk_pipeline_layout: vk.PipelineLayout,
}

@(require_results)
vk_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(Vulkan_Pipeline_Layout_Impl, pipeline_layout, loc)
    return string_buffer_get_string(&impl.label)
}

vk_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Pipeline_Layout_Impl, pipeline_layout, loc)
    string_buffer_init(&impl.label, label)
}

vk_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(Vulkan_Pipeline_Layout_Impl, pipeline_layout, loc)
    ref_count_add(&impl.ref, loc)
}

vk_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(Vulkan_Pipeline_Layout_Impl, pipeline_layout, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        for layout in impl.layouts {
            vk_bind_group_layout_release(layout)
        }
        delete(impl.layouts)
        vk.DestroyPipelineLayout(device_impl.vk_device, impl.vk_pipeline_layout, nil)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------


Vulkan_Sampler_Impl :: struct {
    // Base
    using base: Sampler_Base,

    // Initialization
    vk_sampler: vk.Sampler,
}

@(require_results)
vk_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Sampler_Impl, sampler, loc)
    return string_buffer_get_string(&impl.label)
}

vk_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Sampler_Impl, sampler, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
    string_buffer_init(&impl.label, label)
    vk_set_debug_object_name(device_impl.vk_device, .SAMPLER, impl.vk_sampler, label)
}

vk_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(Vulkan_Sampler_Impl, sampler, loc)
    ref_count_add(&impl.ref, loc)
}

vk_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(Vulkan_Sampler_Impl, sampler, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vk.DestroySampler(device_impl.vk_device, impl.vk_sampler, nil)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------


Vulkan_Shader_Module_Impl :: struct {
    // Base
    using base:       Shader_Module_Base,

    // Initialization
    vk_shader_module: vk.ShaderModule,
}

@(require_results)
vk_shader_module_get_label :: proc(shader_module: Shader_Module, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Shader_Module_Impl, shader_module, loc)
    return string_buffer_get_string(&impl.label)
}

vk_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(Vulkan_Shader_Module_Impl, shader_module, loc)
    string_buffer_init(&impl.label, label)
}

vk_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(Vulkan_Shader_Module_Impl, shader_module, loc)
    ref_count_add(&impl.ref, loc)
}

vk_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(Vulkan_Shader_Module_Impl, shader_module, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vk.DestroyShaderModule(device_impl.vk_device, impl.vk_shader_module, nil)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Surface procedures
// -----------------------------------------------------------------------------


VK_MAX_SWAPCHAIN_IMAGES :: 16

Vulkan_Surface_Impl :: struct {
    // Base
    using base:           Surface_Base,

    // Initialization
    vk_surface:           vk.SurfaceKHR,
    swapchain_colorspace: bool,

    // Swapchain
    vk_swapchain:         vk.SwapchainKHR,
    num_images:           u32,
    current_image_index:  u32, // [0:num_images)
    current_frame_index:  u32, // [0:+inf)
    get_next_image:       bool,
    textures:             [VK_MAX_SWAPCHAIN_IMAGES]Vulkan_Texture_Impl,
    texture_views:        [VK_MAX_SWAPCHAIN_IMAGES]Vulkan_Texture_View_Impl,
    acquire_semaphore:    [VK_MAX_SWAPCHAIN_IMAGES]vk.Semaphore,
    present_fence:        [VK_MAX_SWAPCHAIN_IMAGES]vk.Fence,
    acquire_fences:       [VK_MAX_SWAPCHAIN_IMAGES]vk.Fence,

    // Timeline
    timeline_semaphore:   vk.Semaphore,
    timeline_wait_values: [VK_MAX_SWAPCHAIN_IMAGES]u64,
}

vk_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    adapter_impl := get_impl(Vulkan_Adapter_Impl, adapter, loc)

    // Query supported surface formats
    format_count: u32
    vk_check(vk.GetPhysicalDeviceSurfaceFormatsKHR(
        adapter_impl.vk_physical_device,
        impl.vk_surface,
        &format_count,
        nil,
    ), loc = loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    vk_surface_formats := make([]vk.SurfaceFormatKHR, format_count, ta)
    vk_check(vk.GetPhysicalDeviceSurfaceFormatsKHR(
        adapter_impl.vk_physical_device,
        impl.vk_surface,
        &format_count,
        raw_data(vk_surface_formats),
    ), loc = loc)

    surface_formats := make([dynamic]Texture_Format, allocator)
    for i in 0 ..< format_count {
        format := vk_format_to_texture_format(vk_surface_formats[i].format)
        if format != .Undefined && !slice.contains(surface_formats[:], format) {
            append(&surface_formats, format)
        }
    }

    slice.sort_by(caps.formats, proc(i, j: Texture_Format) -> bool {
        return surface_get_format_priority(i) > surface_get_format_priority(j)
    })

    caps.formats = surface_formats[:]

    // Query supported present modes
    present_mode_count: u32
    vk_check(vk.GetPhysicalDeviceSurfacePresentModesKHR(
        adapter_impl.vk_physical_device,
        impl.vk_surface,
        &present_mode_count,
        nil,
    ), loc = loc)

    vk_present_modes := make([]vk.PresentModeKHR, present_mode_count, ta)
    vk_check(vk.GetPhysicalDeviceSurfacePresentModesKHR(
        adapter_impl.vk_physical_device,
        impl.vk_surface,
        &present_mode_count,
        raw_data(vk_present_modes),
    ), loc = loc)

    present_modes := make([dynamic]Present_Mode, allocator)
    for i in 0 ..< present_mode_count {
        mode := vk_conv_from_present_mode(vk_present_modes[i])
        if !slice.contains(present_modes[:], mode) {
            append(&present_modes, mode)
        }
    }

    caps.present_modes = present_modes[:]

    // Query surface capabilities
    surface_capabilities: vk.SurfaceCapabilitiesKHR
    vk_check(vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
        adapter_impl.vk_physical_device,
        impl.vk_surface,
        &surface_capabilities,
    ), loc = loc)

    // Populate supported composite alpha modes
    caps.alpha_modes = vk_composite_alpha_flags_to_slice(
        surface_capabilities.supportedCompositeAlpha,allocator)

    // Convert supported usage flags to Texture_Usages
    caps.usages = vk_image_usage_to_texture_usages(surface_capabilities.supportedUsageFlags)

    return
}

vk_surface_capabilities_free_members :: proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
) {
    context.allocator = allocator
    delete(caps.formats)
    delete(caps.present_modes)
    delete(caps.alpha_modes)
}

vk_surface_configure :: proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    assert(config.width != 0, "Surface width must be > 0", loc)
    assert(config.height != 0, "Surface height must be > 0", loc)

    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    device_impl := get_impl(Vulkan_Device_Impl, device, loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = impl.allocator  == ta)

    // Set image usage flags
    image_usage_flags := vk_texture_usage_to_vk(config.usage)

    // Set desired format and colorspace
    desired_format := vk.SurfaceFormatKHR {
        format     = VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT[config.format],
        colorSpace = .SRGB_NONLINEAR,
    }

    // Set desired present mode
    desired_present_mode := vk_conv_to_present_mode(config.present_mode)

    // Set composite alpha flags
    composite_alpha_flags := vk_composite_alpha_mode_to_vk_flags(config.alpha_mode)

    capabilities:  vk.SurfaceCapabilitiesKHR
    vk_check(vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
        device_impl.vk_physical_device,
        impl.vk_surface,
        &capabilities,
    ))

    find_extent :: proc(
        capabilities: vk.SurfaceCapabilitiesKHR,
        desired_width, desired_height: u32,
    ) -> vk.Extent2D {
        if capabilities.currentExtent.width != max(u32) {
            return capabilities.currentExtent
        }

        actual_extent: vk.Extent2D = {desired_width, desired_height}

        actual_extent.width = max(
            capabilities.minImageExtent.width,
            min(capabilities.maxImageExtent.width, actual_extent.width),
        )
        actual_extent.height = max(
            capabilities.minImageExtent.height,
            min(capabilities.maxImageExtent.height, actual_extent.height),
        )

        return actual_extent
    }

    extent := find_extent(capabilities, config.width, config.height)

    image_count := capabilities.minImageCount + 1

    swapchain_create_info: vk.SwapchainCreateInfoKHR = {
        sType            = .SWAPCHAIN_CREATE_INFO_KHR,
        surface          = impl.vk_surface,
        minImageCount    = image_count,
        imageFormat      = desired_format.format,
        imageColorSpace  = desired_format.colorSpace,
        imageExtent      = extent,
        imageArrayLayers = 1,
        imageUsage       = image_usage_flags,
        preTransform     = capabilities.currentTransform,
        compositeAlpha   = composite_alpha_flags,
        presentMode      = desired_present_mode,
        clipped          = true,
    }

    queue_family_indices: []u32 = {
        device_impl.queue.queues[.Graphics].index,
        device_impl.queue.queues[.Compute].index,
    }

    if queue_family_indices[0] != queue_family_indices[1] {
        swapchain_create_info.imageSharingMode = .CONCURRENT
        swapchain_create_info.queueFamilyIndexCount = u32(len(queue_family_indices))
        swapchain_create_info.pQueueFamilyIndices = raw_data(queue_family_indices)
    } else {
        swapchain_create_info.imageSharingMode = .EXCLUSIVE
    }

    reconfiguring := impl.vk_swapchain != {}
    if reconfiguring {
        swapchain_create_info.oldSwapchain = impl.vk_swapchain
    } else {
        // Defer device release after surface is released
        vk_device_add_ref(device, loc)
    }

    vk_swapchain: vk.SwapchainKHR
    vk_check(vk.CreateSwapchainKHR(device_impl.vk_device, &swapchain_create_info, nil, &vk_swapchain))

    if reconfiguring {
        vk_check(vk.DeviceWaitIdle(device_impl.vk_device))

        impl.timeline_wait_values = {}

        for i in 0..<impl.num_images {
            vk.DestroySemaphore(device_impl.vk_device, impl.acquire_semaphore[i], nil)
            vk_texture := &impl.textures[i]
            if vk_texture.vk_image_view != {} {
                vk.DestroyImageView(device_impl.vk_device, vk_texture.vk_image_view, nil)
            }
            if impl.present_fence[i] != {} {
                vk.DestroyFence(device_impl.vk_device, impl.present_fence[i], nil)
                impl.present_fence[i] = {}
            }
            if impl.acquire_fences[i] != {} {
                vk.DestroyFence(device_impl.vk_device, impl.acquire_fences[i], nil)
                impl.acquire_fences[i] = {}
            }
        }

        if impl.timeline_semaphore != {} {
            vk.DestroySemaphore(device_impl.vk_device, impl.timeline_semaphore, nil)
            impl.timeline_semaphore = {}
        }

        vk.DestroySwapchainKHR(device_impl.vk_device, impl.vk_swapchain, nil)
    }

    impl.vk_swapchain = vk_swapchain
    impl.config = config
    impl.device = device

    if device_impl.has_EXT_hdr_metadata {
        metadata := vk.HdrMetadataEXT {
            sType                     = .HDR_METADATA_EXT,
            displayPrimaryRed         = {x = 0.680, y = 0.320},
            displayPrimaryGreen       = {x = 0.265, y = 0.690},
            displayPrimaryBlue        = {x = 0.150, y = 0.060},
            whitePoint                = {x = 0.3127, y = 0.3290},
            maxLuminance              = 80.0,
            minLuminance              = 0.001,
            maxContentLightLevel      = 2000.0,
            maxFrameAverageLightLevel = 500.0,
        }
        vk.SetHdrMetadataEXT(device_impl.vk_device, 1, &impl.vk_swapchain, &metadata)
    }

    // Get the number of images in the swapchain
    max_image_count: u32
    vk_check(vk.GetSwapchainImagesKHR(device_impl.vk_device, vk_swapchain, &max_image_count, nil))
    max_image_count = min(max_image_count, VK_MAX_SWAPCHAIN_IMAGES)

    // Allocate memory for the images
    swapchain_images := make([]vk.Image, max_image_count, ta)

    // Retrieve the actual images
    vk_check(vk.GetSwapchainImagesKHR(
        device_impl.vk_device,
        vk_swapchain,
        &image_count,
        raw_data(swapchain_images),
    ))

    impl.num_images = u32(len(swapchain_images))
    assert(impl.num_images > 0)

    debug_name_fence: [256]u8
    debug_name_image: [256]u8
    debug_name_image_view: [256]u8

    for img, i in swapchain_images {
        impl.acquire_semaphore[i] =
            vk_create_semaphore(device_impl.vk_device, "Semaphore: swapchain-acquire")

        if device_impl.has_EXT_device_fault == false {
            debug_name_fence_str := fmt.bprintf(debug_name_fence[:], "Fence: swapchain %d", i)
            impl.acquire_fences[i] =
                vk_create_fence(device_impl.vk_device, debug_name_fence_str, signaled = true)
        }

        debug_name_image_str := fmt.bprintf(debug_name_image[:], "Image: swapchain %d", i)
        debug_name_image_view_str :=
            fmt.bprintf(debug_name_image_view[:], "Image View: swapchain %d", i)

        texture := Vulkan_Texture_Impl {
            // Base
            device             = device,
            surface            = surface,
            usage              = config.usage,
            dimension          = .D2,
            size               = { config.width, config.height, 1 },
            format             = config.format,
            mip_level_count    = 1,
            sample_count       = 1,
            allocator          = impl.allocator,

            // Backend
            vk_image           = img,
            vk_usage_flags     = image_usage_flags,
            vk_extent          = { config.width, config.height, 1 },
            vk_type            = .D2,
            vk_image_format    = desired_format.format,
            vk_samples         = { ._1 },
            num_levels         = 1,
            num_layers         = 1,
            is_swapchain_image = true,
        }

        vk_set_debug_object_name(device_impl.vk_device, .IMAGE, img, debug_name_image_str)

        texture.vk_image_view = vk_texture_create_image_view(
            texture     = &texture,
            device      = device_impl.vk_device,
            type        = .D2,
            format      = desired_format.format,
            aspect_mask = { .COLOR },
            base_level  = 0,
            debug_name  = debug_name_image_view_str,
        )

        impl.textures[i] = texture

        texture_view := Vulkan_Texture_View_Impl {
            vk_image_view     = texture.vk_image_view,
            device            = device,
            texture           = Texture(&impl.textures[i]),
            format            = config.format,
            dimension         = .D2,
            usage             = config.usage,
            mip_level_count   = 1,
            array_layer_count = 1,
            aspect            = .All,
        }

        impl.texture_views[i] = texture_view
    }

    impl.timeline_semaphore = vk_create_semaphore_timeline(
        device_impl.vk_device, u64(impl.num_images - 1), "Semaphore: impl.timeline_semaphore")

    impl.get_next_image = true
}

@(require_results)
vk_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    texture: Surface_Texture,
) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    if impl.get_next_image {
        // Common wait on timeline semaphore for previous operations
        wait_info := vk.SemaphoreWaitInfo {
            sType          = .SEMAPHORE_WAIT_INFO,
            semaphoreCount = 1,
            pSemaphores    = &impl.timeline_semaphore,
            pValues        = &impl.timeline_wait_values[impl.current_image_index],
        }
        vk_check(vk.WaitSemaphores(device_impl.vk_device, &wait_info, max(u64)))

        acquire_fence: vk.Fence

        if device_impl.has_EXT_swapchain_maintenance1 {
            // VK_EXT_swapchain_maintenance1: before acquiring again, wait for
            // the presentation operation to finish
            if impl.present_fence[impl.current_image_index] != {} {
                vk_check(vk.WaitForFences(
                    device_impl.vk_device,
                    1,
                    &impl.present_fence[impl.current_image_index],
                    true,
                    max(u64),
                ))
                vk_check(vk.ResetFences(
                    device_impl.vk_device, 1, &impl.present_fence[impl.current_image_index]))
            }
        } else {
            // without VK_EXT_swapchain_maintenance1: use acquire fences to
            // synchronize semaphore reuse
            vk_check(vk.WaitForFences(
                device_impl.vk_device,
                1,
                &impl.acquire_fences[impl.current_image_index],
                true,
                max(u64),
            ))
            vk_check(vk.ResetFences(
                device_impl.vk_device,
                1,
                &impl.acquire_fences[impl.current_image_index]))

            acquire_fence = impl.acquire_fences[impl.current_image_index]
        }

        acquire_semaphore := impl.acquire_semaphore[impl.current_image_index]
        res := vk.AcquireNextImageKHR(
            device_impl.vk_device,
            impl.vk_swapchain,
            max(u64),
            acquire_semaphore,
            acquire_fence, // Optional
            &impl.current_image_index,
        )

        #partial switch res {
        case .SUCCESS:
            texture.status = .Success_Optimal
        case .SUBOPTIMAL_KHR:
            texture.status = .Success_Suboptimal
        case .TIMEOUT:
            texture.status = .Timeout
        case .ERROR_OUT_OF_DATE_KHR:
            texture.status = .Outdated
        case .ERROR_SURFACE_LOST_KHR:
            texture.status = .Lost
        case .ERROR_OUT_OF_HOST_MEMORY, .ERROR_OUT_OF_DEVICE_MEMORY:
            texture.status = .Out_Of_Memory
        case .ERROR_DEVICE_LOST:
            texture.status = .Device_Lost
        case:
            vk_check(res, "vk.AcquireNextImageKHR failed")
            texture.status = .Error // unreachable?
        }

        impl.get_next_image = false
        device_impl.encoder.wait_semaphore.semaphore = acquire_semaphore

        // Update timeline for this image
        signal_value := u64(impl.current_frame_index) + u64(impl.num_images)
        impl.timeline_wait_values[impl.current_image_index] = signal_value
        device_impl.encoder.signal_semaphore.semaphore = impl.timeline_semaphore
        device_impl.encoder.signal_semaphore.value = signal_value
    }

    assert(impl.current_image_index < impl.num_images)

    texture.surface = surface
    texture.texture = Texture(&impl.textures[impl.current_image_index])

    return
}

vk_surface_present :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    // Get current swapchain image texture
    present_texture := &impl.textures[impl.current_image_index]
    if present_texture.vk_image_layout == .UNDEFINED {
        return
    }

    // Acquire last submit semaphore
    wait_semaphore := device_impl.encoder.last_submit_semaphore.semaphore
    device_impl.encoder.last_submit_semaphore.semaphore = {}

    res := vk.Result.ERROR_UNKNOWN

    // Present the image with appropriate synchronization
    if device_impl.has_EXT_swapchain_maintenance1 {
        // WITH VK_EXT_swapchain_maintenance1: Use presentation fence
        swap_fence_info := vk.SwapchainPresentFenceInfoEXT {
            sType          = .SWAPCHAIN_PRESENT_FENCE_INFO_EXT,
            swapchainCount = 1,
            pFences        = &impl.present_fence[impl.current_image_index],
        }

        // Ensure presentation fence exists
        if impl.present_fence[impl.current_image_index] == {} {
            impl.present_fence[impl.current_image_index] =
                vk_create_fence(device_impl.vk_device,
                    fmt.tprintf("Fence: present-fence-%d", impl.current_image_index))
        }

        present_info := vk.PresentInfoKHR {
            sType              = .PRESENT_INFO_KHR,
            pNext              = &swap_fence_info,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = &wait_semaphore,
            swapchainCount     = 1,
            pSwapchains        = &impl.vk_swapchain,
            pImageIndices      = &impl.current_image_index,
        }

        res = vk.QueuePresentKHR(device_impl.encoder.vk_queue, &present_info)
    } else {
        // WITHOUT VK_EXT_swapchain_maintenance1: Normal presentation
        present_info := vk.PresentInfoKHR {
            sType              = .PRESENT_INFO_KHR,
            waitSemaphoreCount = 1,
            pWaitSemaphores    = &wait_semaphore,
            swapchainCount     = 1,
            pSwapchains        = &impl.vk_swapchain,
            pImageIndices      = &impl.current_image_index,
        }

        res = vk.QueuePresentKHR(device_impl.encoder.vk_queue, &present_info)
    }

    if res != .SUCCESS && res != .SUBOPTIMAL_KHR && res != .ERROR_OUT_OF_DATE_KHR {
        vk_check(res, "vk.QueuePresentKHR", loc)
    }

    impl.get_next_image = true
    impl.current_frame_index += 1
}

@(require_results)
vk_surface_get_label :: proc(surface: Surface, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    return string_buffer_get_string(&impl.label)
}

vk_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    string_buffer_init(&impl.label, label)
}

vk_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)
    ref_count_add(&impl.ref, loc)
}

vk_surface_release :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(Vulkan_Surface_Impl, surface, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.device != nil {
            device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
            vk.DeviceWaitIdle(device_impl.vk_device)

            for i in 0 ..< impl.num_images {
                vk.DestroySemaphore(device_impl.vk_device, impl.acquire_semaphore[i], nil)

                vk_texture := &impl.textures[i]
                vk.DestroyImageView(device_impl.vk_device, vk_texture.vk_image_view, nil)

                if impl.present_fence[i] !=  {} {
                    vk.DestroyFence(device_impl.vk_device, impl.present_fence[i], nil)
                }

                if impl.acquire_fences[i] !=  {} {
                    vk.DestroyFence(device_impl.vk_device, impl.acquire_fences[i], nil)
                }
            }

            vk.DestroySemaphore(device_impl.vk_device, impl.timeline_semaphore, nil)

            if impl.vk_swapchain != {} {
                vk.DestroySwapchainKHR(device_impl.vk_device, impl.vk_swapchain, nil)
            }
        }

        if impl.vk_surface != 0 {
            instance_impl := get_impl(Vulkan_Instance_Impl, impl.instance, loc)
            vk.DestroySurfaceKHR(instance_impl.vk_instance, impl.vk_surface, nil)
        }

        if impl.device != nil {
            vk_device_release(impl.device, loc)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Texture procedures
// -----------------------------------------------------------------------------


Vulkan_Texture_Impl :: struct {
    // Base
    using base:            Texture_Base,

    // Backend
    vk_image:              vk.Image,
    vk_usage_flags:        vk.ImageUsageFlags,
    vk_format_properties:  vk.FormatProperties,
    vk_extent:             vk.Extent3D,
    vk_type:               vk.ImageType,
    vk_image_format:       vk.Format,
    vk_samples:            vk.SampleCountFlags,
    vma_allocation:        vma.Allocation,
    mapped_ptr:            rawptr,
    is_owning_vk_image:    bool,
    is_resolve_attachment: bool,
    num_levels:            u32,
    num_layers:            u32,
    is_depth_format:       bool,
    is_stencil_format:     bool,
    debug_name:            String_Buffer_Small,
    vk_image_layout:       vk.ImageLayout,
    vk_image_view:         vk.ImageView,
    vk_image_view_storage: vk.ImageView,

    // Swapchain texture
    is_swapchain_image:    bool,
    surface:               Surface,
}

@(require_results)
vk_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    assert(impl.device != nil, loc = loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)

    if impl.is_swapchain_image {
        assert(impl.surface != nil, loc = loc)
        surface_impl := get_impl(Vulkan_Surface_Impl, impl.surface, loc)
        return Texture_View(&surface_impl.texture_views[surface_impl.current_image_index])
    } else {
        create_info := vk.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            image = impl.vk_image,
            viewType = VK_CONV_TO_IMAGE_VIEW_TYPE_LUT[descriptor.dimension],
            format = VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT[descriptor.format],
            components = {
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = {
                aspectMask     = vk_conv_to_image_aspect_flags(descriptor.aspect, descriptor.format),
                baseMipLevel   = descriptor.base_mip_level,
                levelCount     = descriptor.mip_level_count,
                baseArrayLayer = descriptor.base_array_layer,
                layerCount     = descriptor.array_layer_count,
            },
        }

        vk_image_view: vk.ImageView
        res := vk.CreateImageView(device_impl.vk_device, &create_info, nil, &vk_image_view)
        vk_check(res, "CreateImageView failed", loc)

        texture_view := texture_new_handle(Vulkan_Texture_View_Impl, texture, loc)

        // Set base fields
        texture_view.format            = descriptor.format
        texture_view.dimension         = descriptor.dimension
        texture_view.aspect            = descriptor.aspect
        texture_view.base_mip_level    = descriptor.base_mip_level
        texture_view.mip_level_count   = descriptor.mip_level_count
        texture_view.base_array_layer  = descriptor.base_array_layer
        texture_view.array_layer_count = descriptor.array_layer_count

        // Set backend fields
        texture_view.vk_image_view     = vk_image_view

        return Texture_View(texture_view)
    }

    unreachable()
}

@(require_results)
vk_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    desc: Texture_Descriptor
    // label
    desc.usage = impl.usage
    desc.dimension = impl.dimension
    desc.size = impl.size
    desc.size = impl.size
    desc.format = impl.format
    desc.mip_level_count = impl.mip_level_count
    desc.sample_count = impl.sample_count
    // view_formats
    return desc
}

@(require_results)
vk_texture_get_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Dimension {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.dimension
}

@(require_results)
vk_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.format
}

@(require_results)
vk_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.size.height
}

@(require_results)
vk_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.mip_level_count
}

@(require_results)
vk_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.sample_count
}

@(require_results)
vk_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.size
}

@(require_results)
vk_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.usage
}

@(require_results)
vk_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return impl.size.width
}

@(require_results)
vk_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    return string_buffer_get_string(&impl.label)
}

vk_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
    string_buffer_init(&impl.label, label)
    vk_set_debug_object_name(device_impl.vk_device, .IMAGE, impl.vk_image, label, loc)
}

vk_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)
    ref_count_add(&impl.ref, loc)
}

vk_texture_release :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_Impl, texture, loc)

    if impl.is_swapchain_image {
        return
    }

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vma.destroy_image(device_impl.vma_allocator, impl.vk_image, impl.vma_allocation)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Texture View procedures
// -----------------------------------------------------------------------------


Vulkan_Texture_View_Impl :: struct {
    // Base
    using base:    Texture_View_Base,

    // Initialization
    vk_image_view: vk.ImageView,
}

@(require_results)
vk_texture_view_get_label :: proc(texture_view: Texture_View, loc := #caller_location) -> string {
    impl := get_impl(Vulkan_Texture_View_Impl, texture_view, loc)
    return string_buffer_get_string(&impl.label)
}

vk_texture_view_set_label :: proc(texture_view: Texture_View, label: string, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_View_Impl, texture_view, loc)
    string_buffer_init(&impl.label, label)
}

vk_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_View_Impl, texture_view, loc)
    ref_count_add(&impl.ref, loc)
}

vk_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := get_impl(Vulkan_Texture_View_Impl, texture_view, loc)
    texture_impl := get_impl(Vulkan_Texture_Impl, impl.texture, loc)

    if texture_impl.is_swapchain_image {
        return
    }

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        device_impl := get_impl(Vulkan_Device_Impl, impl.device, loc)
        vk.DestroyImageView(device_impl.vk_device, impl.vk_image_view, nil)
        vk_texture_release(impl.texture, loc)
        free(impl)
    }
}
