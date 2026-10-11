#+build !js
package gpu

// // Core
// import "base:runtime"
// import "core:fmt"
// import "core:log"
// import "core:mem"
// import "core:slice"
// import "core:strings"
// import "core:sync"

// import intr "base:intrinsics"
// import hm "core:container/handle_map"
// import sa "core:container/small_array"

// // Vendor
// import "lib/vma"
// import vk "vendor:vulkan"

// VK_Device_Pool :: Device_Pool(VK_Device_Impl)

// VK_State :: struct {
//     devices:  VK_Device_Pool,
//     surfaces: DHM(VK_Surface_Impl, VK_Surface_Handle),
//     adapters: DHM(VK_Adapter_Impl, VK_Adapter_Handle),
//     mtx:      sync.Mutex,
// }

// vk_set_procedures :: proc() {
//     gpu.backend = .Vulkan
//     gpu.is_embedded = false

//     // Global procedures
//     get_instance_features = vk_get_instance_features
//     get_instance_limits = vk_get_instance_limits
//     has_instance_feature = vk_has_instance_feature
//     get_proc_address = vk_get_proc_address

//     // Procedures of Adapter
//     adapter_get_features = vk_adapter_get_features
//     adapter_get_features_view = vk_adapter_get_features_view
//     adapter_get_info = vk_adapter_get_info
//     adapter_get_limits = vk_adapter_get_limits
//     adapter_has_feature = vk_adapter_has_feature
//     adapter_request_device = vk_adapter_request_device
//     adapter_add_ref = vk_adapter_add_ref
//     adapter_release = vk_adapter_release

//     // Private procedures of Adapter
//     adapter_texture_format_capabilities = vk_adapter_texture_format_capabilities

//     // Procedures of Adapter_Info
//     adapter_info_free_members = vk_adapter_info_free_members

//     // Procedures of Bind_Group
//     bind_group_set_label = vk_bind_group_set_label
//     bind_group_add_ref = vk_bind_group_add_ref
//     bind_group_release = vk_bind_group_release
//     bind_group_layout_set_label = vk_bind_group_layout_set_label
//     bind_group_layout_add_ref = vk_bind_group_layout_add_ref
//     bind_group_layout_release = vk_bind_group_layout_release

//     // Procedures of Buffer
//     buffer_destroy = vk_buffer_destroy
//     buffer_get_const_mapped_range = vk_buffer_get_const_mapped_range
//     buffer_get_mapped_range = vk_buffer_get_mapped_range
//     buffer_get_map_state = vk_buffer_get_map_state
//     buffer_get_size = vk_buffer_get_size
//     buffer_get_usage = vk_buffer_get_usage
//     buffer_map_async = vk_buffer_map_async
//     buffer_read_mapped_range = vk_buffer_read_mapped_range
//     buffer_set_label = vk_buffer_set_label
//     buffer_unmap = vk_buffer_unmap
//     buffer_write_mapped_range = vk_buffer_write_mapped_range
//     buffer_add_ref = vk_buffer_add_ref
//     buffer_release = vk_buffer_release

//     // Procedures of Command_Buffer
//     command_buffer_set_label = vk_command_buffer_set_label
//     command_buffer_add_ref = vk_command_buffer_add_ref
//     command_buffer_release = vk_command_buffer_release

//     // Procedures of Command_Encoder
//     command_encoder_begin_compute_pass = vk_command_encoder_begin_compute_pass
//     command_encoder_begin_render_pass = vk_command_encoder_begin_render_pass
//     command_encoder_clear_buffer = vk_command_encoder_clear_buffer
//     command_encoder_copy_buffer_to_buffer = vk_command_encoder_copy_buffer_to_buffer
//     command_encoder_copy_buffer_to_texture = vk_command_encoder_copy_buffer_to_texture
//     command_encoder_copy_texture_to_buffer = vk_command_encoder_copy_texture_to_buffer
//     command_encoder_copy_texture_to_texture = vk_command_encoder_copy_texture_to_texture
//     command_encoder_finish = vk_command_encoder_finish
//     command_encoder_insert_debug_marker = vk_command_encoder_insert_debug_marker
//     command_encoder_pop_debug_group = vk_command_encoder_pop_debug_group
//     command_encoder_push_debug_group = vk_command_encoder_push_debug_group
//     command_encoder_resolve_query_set = vk_command_encoder_resolve_query_set
//     command_encoder_set_label = vk_command_encoder_set_label
//     command_encoder_write_timestamp = vk_command_encoder_write_timestamp
//     command_encoder_add_ref = vk_command_encoder_add_ref
//     command_encoder_release = vk_command_encoder_release

//     // Procedures of Compute_Pass_Encoder
//     compute_pass_encoder_dispatch_workgroups = vk_compute_pass_encoder_dispatch_workgroups
//     compute_pass_encoder_dispatch_workgroups_indirect =
//         vk_compute_pass_encoder_dispatch_workgroups_indirect
//     compute_pass_encoder_end = vk_compute_pass_encoder_end
//     compute_pass_encoder_insert_debug_marker = vk_compute_pass_encoder_insert_debug_marker
//     compute_pass_encoder_pop_debug_group = vk_compute_pass_encoder_pop_debug_group
//     compute_pass_encoder_push_debug_group = vk_compute_pass_encoder_push_debug_group
//     compute_pass_encoder_set_bind_group = vk_compute_pass_encoder_set_bind_group
//     compute_pass_encoder_set_immediates = vk_compute_pass_encoder_set_immediates
//     compute_pass_encoder_set_label = vk_compute_pass_encoder_set_label
//     compute_pass_encoder_set_pipeline = vk_compute_pass_encoder_set_pipeline
//     compute_pass_encoder_add_ref = vk_compute_pass_encoder_add_ref
//     compute_pass_encoder_release = vk_compute_pass_encoder_release

//     // Procedures of Compute_Pipeline
//     compute_pipeline_get_bind_group_layout = vk_compute_pipeline_get_bind_group_layout
//     compute_pipeline_set_label = vk_compute_pipeline_set_label
//     compute_pipeline_add_ref = vk_compute_pipeline_add_ref
//     compute_pipeline_release = vk_compute_pipeline_release

//     // Procedures of Device
//     device_get_adapter = vk_device_get_adapter
//     device_create_bind_group = vk_device_create_bind_group
//     device_create_bind_group_layout = vk_device_create_bind_group_layout
//     device_create_buffer = vk_device_create_buffer
//     device_create_command_encoder = vk_device_create_command_encoder
//     device_create_compute_pipeline = vk_device_create_compute_pipeline
//     device_create_compute_pipeline_async = vk_device_create_compute_pipeline_async
//     device_create_pipeline_layout = vk_device_create_pipeline_layout
//     device_create_query_set = vk_device_create_query_set
//     device_create_render_bundle_encoder = vk_device_create_render_bundle_encoder
//     device_create_render_pipeline = vk_device_create_render_pipeline
//     device_create_render_pipeline_async = vk_device_create_render_pipeline_async
//     device_create_sampler = vk_device_create_sampler
//     device_create_shader_module = vk_device_create_shader_module
//     device_create_texture = vk_device_create_texture
//     device_destroy = vk_device_destroy
//     device_get_adapter_info = vk_device_get_adapter_info
//     device_get_features = vk_device_get_features
//     device_get_features_view = vk_device_get_features_view
//     device_get_limits = vk_device_get_limits
//     device_get_lost_future = vk_device_get_lost_future
//     device_get_queue = vk_device_get_queue
//     device_has_feature = vk_device_has_feature
//     device_pop_error_scope = vk_device_pop_error_scope
//     device_push_error_scope = vk_device_push_error_scope
//     device_set_label = vk_device_set_label
//     device_add_ref = vk_device_add_ref
//     device_release = vk_device_release

//     // Procedures of External_Texture
//     external_texture_set_label = vk_external_texture_set_label
//     external_texture_add_ref = vk_external_texture_add_ref
//     external_texture_release = vk_external_texture_release

//     // Procedures of Instance
//     instance_create_surface = vk_instance_create_surface
//     instance_get_wgsl_language_features = vk_instance_get_wgsl_language_features
//     instance_has_wgsl_language_feature = vk_instance_has_wgsl_language_feature
//     instance_process_events = vk_instance_process_events
//     instance_request_adapter = vk_instance_request_adapter
//     instance_wait_any = vk_instance_wait_any
//     instance_add_ref = vk_instance_add_ref
//     instance_release = vk_instance_release

//     // Procedures of Pipeline_Layout
//     pipeline_layout_set_label = vk_pipeline_layout_set_label
//     pipeline_layout_add_ref = vk_pipeline_layout_add_ref
//     pipeline_layout_release = vk_pipeline_layout_release

//     // Procedures of Query_Set
//     query_set_destroy = vk_query_set_destroy
//     query_set_get_count = vk_query_set_get_count
//     query_set_get_type = vk_query_set_get_type
//     query_set_set_label = vk_query_set_set_label
//     query_set_add_ref = vk_query_set_add_ref
//     query_set_release = vk_query_set_release

//     // Procedures of Queue
//     queue_on_submitted_work_done = vk_queue_on_submitted_work_done
//     queue_set_label = vk_queue_set_label
//     queue_submit = vk_queue_submit
//     queue_write_buffer = vk_queue_write_buffer
//     queue_write_texture = vk_queue_write_texture
//     queue_add_ref = vk_queue_add_ref
//     queue_release = vk_queue_release

//     // Procedures of Render_Bundle
//     render_bundle_set_label = vk_render_bundle_set_label
//     render_bundle_add_ref = vk_render_bundle_add_ref
//     render_bundle_release = vk_render_bundle_release

//     // Procedures of Render_Bundle_Encoder
//     render_bundle_encoder_draw = vk_render_bundle_encoder_draw
//     render_bundle_encoder_draw_indexed = vk_render_bundle_encoder_draw_indexed
//     render_bundle_encoder_draw_indexed_indirect = vk_render_bundle_encoder_draw_indexed_indirect
//     render_bundle_encoder_draw_indirect = vk_render_bundle_encoder_draw_indirect
//     render_bundle_encoder_finish = vk_render_bundle_encoder_finish
//     render_bundle_encoder_insert_debug_marker = vk_render_bundle_encoder_insert_debug_marker
//     render_bundle_encoder_pop_debug_group = vk_render_bundle_encoder_pop_debug_group
//     render_bundle_encoder_push_debug_group = vk_render_bundle_encoder_push_debug_group
//     render_bundle_encoder_set_bind_group = vk_render_bundle_encoder_set_bind_group
//     render_bundle_encoder_set_immediates = vk_render_bundle_encoder_set_immediates
//     render_bundle_encoder_set_index_buffer = vk_render_bundle_encoder_set_index_buffer
//     render_bundle_encoder_set_label = vk_render_bundle_encoder_set_label
//     render_bundle_encoder_set_pipeline = vk_render_bundle_encoder_set_pipeline
//     render_bundle_encoder_set_vertex_buffer = vk_render_bundle_encoder_set_vertex_buffer
//     render_bundle_encoder_add_ref = vk_render_bundle_encoder_add_ref
//     render_bundle_encoder_release = vk_render_bundle_encoder_release

//     // Procedures of Render_Pass_Encoder
//     render_pass_encoder_begin_occlusion_query = vk_render_pass_encoder_begin_occlusion_query
//     render_pass_encoder_draw = vk_render_pass_encoder_draw
//     render_pass_encoder_draw_indexed = vk_render_pass_encoder_draw_indexed
//     render_pass_encoder_draw_indexed_indirect = vk_render_pass_encoder_draw_indexed_indirect
//     render_pass_encoder_draw_indirect = vk_render_pass_encoder_draw_indirect
//     render_pass_encoder_end = vk_render_pass_encoder_end
//     render_pass_encoder_end_occlusion_query = vk_render_pass_encoder_end_occlusion_query
//     render_pass_encoder_execute_bundles = vk_render_pass_encoder_execute_bundles
//     render_pass_encoder_insert_debug_marker = vk_render_pass_encoder_insert_debug_marker
//     render_pass_encoder_pop_debug_group = vk_render_pass_encoder_pop_debug_group
//     render_pass_encoder_push_debug_group = vk_render_pass_encoder_push_debug_group
//     render_pass_encoder_set_bind_group = vk_render_pass_encoder_set_bind_group
//     render_pass_encoder_set_blend_constant = vk_render_pass_encoder_set_blend_constant
//     render_pass_encoder_set_immediates = vk_render_pass_encoder_set_immediates
//     render_pass_encoder_set_index_buffer = vk_render_pass_encoder_set_index_buffer
//     render_pass_encoder_set_label = vk_render_pass_encoder_set_label
//     render_pass_encoder_set_pipeline = vk_render_pass_encoder_set_pipeline
//     render_pass_encoder_set_scissor_rect = vk_render_pass_encoder_set_scissor_rect
//     render_pass_encoder_set_stencil_reference = vk_render_pass_encoder_set_stencil_reference
//     render_pass_encoder_set_vertex_buffer = vk_render_pass_encoder_set_vertex_buffer
//     render_pass_encoder_set_viewport = vk_render_pass_encoder_set_viewport
//     render_pass_encoder_add_ref = vk_render_pass_encoder_add_ref
//     render_pass_encoder_release = vk_render_pass_encoder_release

//     // Procedures of Render_Pipeline
//     render_pipeline_get_bind_group_layout = vk_render_pipeline_get_bind_group_layout
//     render_pipeline_set_label = vk_render_pipeline_set_label
//     render_pipeline_add_ref = vk_render_pipeline_add_ref
//     render_pipeline_release = vk_render_pipeline_release

//     // Procedures of Sampler
//     sampler_set_label = vk_sampler_set_label
//     sampler_add_ref = vk_sampler_add_ref
//     sampler_release = vk_sampler_release

//     // Procedures of Shader_Module
//     shader_module_get_compilation_info = vk_shader_module_get_compilation_info
//     shader_module_set_label = vk_shader_module_set_label
//     shader_module_add_ref = vk_shader_module_add_ref
//     shader_module_release = vk_shader_module_release

//     // Procedures of Supported_Features
//     supported_features_free_members = vk_supported_features_free_members

//     // Procedures of Supported_Instance_Features
//     supported_instance_features_free_members = vk_supported_instance_features_free_members

//     // Procedures of Supported_WGSL_Language_Features
//     supported_wgsl_language_features_free_members =
//         vk_supported_wgsl_language_features_free_members

//     // Procedures of Surface
//     surface_configure = vk_surface_configure
//     surface_get_capabilities = vk_surface_get_capabilities
//     surface_get_current_texture = vk_surface_get_current_texture
//     surface_present = vk_surface_present
//     surface_set_label = vk_surface_set_label
//     surface_unconfigure = vk_surface_unconfigure
//     surface_add_ref = vk_surface_add_ref
//     surface_release = vk_surface_release
//     surface_capabilities_free_members = vk_surface_capabilities_free_members

//     // Procedures of Texture
//     texture_create_view = vk_texture_create_view
//     texture_destroy = vk_texture_destroy
//     texture_get_depth_or_array_layers = vk_texture_get_depth_or_array_layers
//     texture_get_descriptor = vk_texture_get_descriptor
//     texture_get_dimension = vk_texture_get_dimension
//     texture_get_format = vk_texture_get_format
//     texture_get_height = vk_texture_get_height
//     texture_get_mip_level_count = vk_texture_get_mip_level_count
//     texture_get_sample_count = vk_texture_get_sample_count
//     texture_get_size = vk_texture_get_size
//     texture_get_texture_binding_view_dimension = vk_texture_get_texture_binding_view_dimension
//     texture_get_usage = vk_texture_get_usage
//     texture_get_width = vk_texture_get_width
//     texture_set_label = vk_texture_set_label
//     texture_add_ref = vk_texture_add_ref
//     texture_release = vk_texture_release

//     // Procedures of Texture_View
//     texture_view_set_label = vk_texture_view_set_label
//     texture_view_add_ref = vk_texture_view_add_ref
//     texture_view_release = vk_texture_view_release
// }

// // Minimum required api version
// VK_API_VERSION :: vk.API_VERSION_1_2

// // Default validations
// VK_REQUIRED_VALIDATION_LAYERS :: []cstring{"VK_LAYER_KHRONOS_validation"}

// // Missing extension names
// VK_KHR_SURFACE_MAINTENANCE_1_EXTENSION_NAME   :: "VK_KHR_surface_maintenance1"
// VK_KHR_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME :: "VK_KHR_swapchain_maintenance1"

// // -----------------------------------------------------------------------------
// // Global procedures
// // -----------------------------------------------------------------------------

// vk_create_instance :: proc(
//     descriptor: ^Instance_Descriptor = nil,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> Instance {
//     // Alias to the temporary allocator
//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

//     // Do we have an optional descriptor?
//     desc := descriptor != nil ? descriptor^ : {}

//     // Get the instance extra options if any
//     extras := chain_get(Instance_Extras, desc.next_in_chain, .Instance_Extras)

//     // Extra options
//     flags: Instance_Flags
//     vk_proc_addr: vk.ProcGetInstanceProcAddr

//     if extras != nil {
//         flags = extras.flags
//         vk_proc_addr = vk.ProcGetInstanceProcAddr(extras.vk_get_instance_proc_addr)
//     }

//     // Init the Vulkan library using the instance options
//     if vk_initialization(.Init, vk_proc_addr) != .SUCCESS {
//         return nil
//     }

//     impl := new(VK_Instance_Impl) or_else panic("Failed to allocate memory for Instance", loc)
//     init_ref(impl)

//     impl.ctx = context
//     impl.allocator = context.allocator
//     impl.flags = flags
//     impl.current_future_id = 1
//     impl.pending_futures.allocator = impl.allocator

//     // Query current instance version
//     impl.instance_version = vk.API_VERSION_1_0
//     // Instance implementation may be too old to support EnumerateInstanceVersion. We need
//     // to check the function pointer before calling it, if the function doesn't exist,
//     // then the instance version must be 1.0.
//     if vk.EnumerateInstanceVersion != nil {
//         res := vk.EnumerateInstanceVersion(&impl.instance_version)
//         if res != .SUCCESS {
//             impl.instance_version = vk.API_VERSION_1_0
//         }
//     }

//     // Check required minimum version
//     if impl.instance_version < VK_API_VERSION {
//         required := vk_api_version(VK_API_VERSION)
//         supported := vk_api_version(impl.instance_version)
//         log.fatalf("Vulkan: required API >= %d.%d.%d but found %d.%d.%d",
//             required.major, required.minor, required.patch,
//             supported.major, supported.minor, supported.patch)
//         free(impl, impl.allocator)
//         return nil
//     }

//     // Check if we have the validation layer in the system
//     layer_count: u32
//     vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, nil))
//     layer_properties := make([dynamic]vk.LayerProperties, layer_count, ta)
//     vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layer_properties)))

//     if .Validation in impl.flags {
//         impl.validation_layers_available = true
//         required_loop: for required in VK_REQUIRED_VALIDATION_LAYERS {
//             for &layer in layer_properties {
//                 layer_name := byte_arr_str(&layer.layerName)
//                 if layer_name == string(required) {
//                     continue required_loop
//                 }
//             }
//             impl.validation_layers_available = false
//             log.warnf("Vulkan: required validation layer not available: %s", required)
//         }
//         if !impl.validation_layers_available {
//             log.warn("Vulkan: validation layers are disabled!")
//             log.warn(
//                 "Vulkan: install the Vulkan SDK to enable validation:\n\t" +
//                 "https://vulkan.lunarg.com/sdk/home",
//             )
//         }
//     }

//     // Get instance extensions
//     extension_count: u32
//     vk_check(vk.EnumerateInstanceExtensionProperties(nil, &extension_count, nil))
//     available_extensions := make([dynamic]vk.ExtensionProperties, extension_count, ta)
//     vk_check(vk.EnumerateInstanceExtensionProperties(
//         nil, &extension_count, raw_data(available_extensions[:])))

//     // Collect instance extensions from the validation layers
//     if impl.validation_layers_available {
//         for layer in VK_REQUIRED_VALIDATION_LAYERS {
//             count: u32
//             vk_check(vk.EnumerateInstanceExtensionProperties(layer, &count, nil))
//             if count > 0 {
//                 sz := u32(len(available_extensions))
//                 resize(&available_extensions, sz + count)
//                 vk_check(vk.EnumerateInstanceExtensionProperties(
//                     layer, &count, raw_data(available_extensions[sz:])))
//             }
//         }
//         for &ext in available_extensions {
//             ext_name := byte_arr_str(&ext.extensionName)
//             if ext_name == vk.EXT_DEBUG_UTILS_EXTENSION_NAME {
//                 impl.debug_utils_available = true
//                 break
//             }
//         }
//     }

//     // Required instance extensions to enable
//     extensions := make([dynamic]cstring, ta)

//     has_portability_enumeration := vk_has_extension(
//         available_extensions,
//         vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME,
//     )
//     if has_portability_enumeration {
//         append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
//     }

//     // Add platform extensions
//     if vk_has_extension(available_extensions[:], vk.KHR_SURFACE_EXTENSION_NAME) {
//         // VK_KHR_surface
//         append(&extensions, vk.KHR_SURFACE_EXTENSION_NAME)

//         when ODIN_OS == .Windows {
//             // VK_KHR_win32_surface
//             if vk_has_extension(available_extensions[:], vk.KHR_WIN32_SURFACE_EXTENSION_NAME) {
//                 append(&extensions, vk.KHR_WIN32_SURFACE_EXTENSION_NAME)
//             }
//         } else when ODIN_OS == .Linux {
//             // VK_KHR_xlib_surface
//             if vk_has_extension(available_extensions[:], vk.KHR_XLIB_SURFACE_EXTENSION_NAME) {
//                 append(&extensions, vk.KHR_XLIB_SURFACE_EXTENSION_NAME)
//             }

//             // VK_KHR_xcb_surface
//             if vk_has_extension(available_extensions[:], vk.KHR_XCB_SURFACE_EXTENSION_NAME) {
//                 append(&extensions, vk.KHR_XCB_SURFACE_EXTENSION_NAME)
//             }

//             // VK_KHR_wayland_surface
//             if vk_has_extension(available_extensions[:], vk.KHR_WAYLAND_SURFACE_EXTENSION_NAME) {
//                 append(&extensions, vk.KHR_WAYLAND_SURFACE_EXTENSION_NAME)
//             }
//         } else when ODIN_OS == .Darwin {
//             VK_MVK_MACOS_SURFACE_EXTENSION_NAME :: "VK_MVK_macos_surface"

//             // VK_EXT_layer_settings
//             if vk_has_extension(available_extensions[:], vk.EXT_LAYER_SETTINGS_EXTENSION_NAME) {
//                 append(&extensions, vk.EXT_LAYER_SETTINGS_EXTENSION_NAME)
//             }

//             // VK_MVK_macos_surface
//             if vk_has_extension(available_extensions[:], VK_MVK_MACOS_SURFACE_EXTENSION_NAME) {
//                 impl.has_mvk_macos_surface = true
//                 append(&extensions, VK_MVK_MACOS_SURFACE_EXTENSION_NAME)
//             }

//             // VK_EXT_metal_surface
//             if vk_has_extension(available_extensions[:], vk.EXT_METAL_SURFACE_EXTENSION_NAME) {
//                 append(&extensions, vk.EXT_METAL_SURFACE_EXTENSION_NAME)
//             }
//         } else {
//             #panic("Unsupported platform")
//         }
//     } else {
//         if vk_has_extension(available_extensions[:], vk.EXT_HEADLESS_SURFACE_EXTENSION_NAME) {
//             impl.headless = true
//             append(&extensions, vk.EXT_HEADLESS_SURFACE_EXTENSION_NAME)
//         }
//     }

//     if impl.validation_layers_available {
//         if vk_has_extension(available_extensions[:], vk.EXT_VALIDATION_FEATURES_EXTENSION_NAME) {
//             append(&extensions, vk.EXT_VALIDATION_FEATURES_EXTENSION_NAME)
//         }
//     }

//     ext_device_address_binding: bool
//     if impl.debug_utils_available {
//         append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

//         if vk_has_extension(
//             available_extensions,
//             vk.EXT_DEVICE_ADDRESS_BINDING_REPORT_EXTENSION_NAME,
//         ) {
//             ext_device_address_binding = true
//             append(&extensions, vk.EXT_DEVICE_ADDRESS_BINDING_REPORT_EXTENSION_NAME)
//         }
//     }

//     // VK_EXT_swapchain_colorspace, provides wide color gamut
//     if vk_has_extension(available_extensions[:], vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME) {
//         impl.has_ext_swapchain_colorspace = true
//         append(&extensions, vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME)
//     }

//     // VK_KHR_surface_maintenance1
//     // Required for the device extension VK_EXT_swapchain_maintenance1
//     if vk_has_extension(available_extensions[:], VK_KHR_SURFACE_MAINTENANCE_1_EXTENSION_NAME) {
//         append(&extensions, VK_KHR_SURFACE_MAINTENANCE_1_EXTENSION_NAME)
//     }

//     // VK_EXT_surface_maintenance1
//     if vk_has_extension(available_extensions[:], vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME) {
//         append(&extensions, vk.EXT_SURFACE_MAINTENANCE_1_EXTENSION_NAME)
//     }

//     // VK_KHR_get_surface_capabilities2
//     if vk_has_extension(
//         available_extensions[:],
//         vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME,
//     ) {
//         append(&extensions, vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME)
//     }

//     gpu_validation_enabled :=
//         .GPU_Based_Validation in impl.flags && impl.validation_layers_available

//     gpu_validation_features := []vk.ValidationFeatureEnableEXT {
//         .GPU_ASSISTED,
//         .GPU_ASSISTED_RESERVE_BINDING_SLOT,
//     }

//     pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

//     features: vk.ValidationFeaturesEXT
//     if gpu_validation_enabled {
//         features.sType = .VALIDATION_FEATURES_EXT
//         features.enabledValidationFeatureCount = u32(len(gpu_validation_features))
//         features.pEnabledValidationFeatures = raw_data(gpu_validation_features)
//         append(&pnext_chain, cast(^vk.BaseOutStructure)&features)
//     }

//     app_info := vk.ApplicationInfo {
//         sType              = .APPLICATION_INFO,
//         pApplicationName   = "Odin/Vulkan",
//         applicationVersion = vk.MAKE_VERSION(1, 0, 0),
//         pEngineName        = "Odin/Vulkan",
//         engineVersion      = vk.MAKE_VERSION(1, 0, 0),
//         apiVersion         = impl.instance_version,
//     }

//     ci := vk.InstanceCreateInfo {
//         sType                   = .INSTANCE_CREATE_INFO,
//         pApplicationInfo        = &app_info,
//         enabledExtensionCount   = u32(len(extensions)),
//         ppEnabledExtensionNames = raw_data(extensions),
//     }

//     if impl.validation_layers_available {
//         ci.enabledLayerCount = u32(len(VK_REQUIRED_VALIDATION_LAYERS))
//         ci.ppEnabledLayerNames = raw_data(VK_REQUIRED_VALIDATION_LAYERS)
//     }

//     dbg_create_info: vk.DebugUtilsMessengerCreateInfoEXT
//     if impl.debug_utils_available {
//         severity: vk.DebugUtilsMessageSeverityFlagsEXT
//         if context.logger.lowest_level <= .Error {
//             severity |= {.ERROR}
//         }
//         if context.logger.lowest_level <= .Warning {
//             severity |= {.WARNING}
//         }
//         if context.logger.lowest_level <= .Info {
//             // severity |= {.INFO}
//         }
//         if context.logger.lowest_level <= .Debug {
//             // severity |= {.VERBOSE}
//         }

//         type := vk.DebugUtilsMessageTypeFlagsEXT{.GENERAL, .VALIDATION, .PERFORMANCE}
//         if ext_device_address_binding {
//             type |= {.DEVICE_ADDRESS_BINDING}
//         }

//         vk_debug_callback :: proc "system" (
//             messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
//             messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
//             pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
//             pUserData: rawptr,
//         ) -> b32 {
//             impl := cast(^VK_Instance_Impl)pUserData
//             context = impl.ctx

//             level: log.Level
//             if .ERROR in messageSeverity {
//                 level = .Error
//             } else if .WARNING in messageSeverity {
//                 level = .Warning
//             } else if .INFO in messageSeverity {
//                 level = .Info
//             } else {
//                 level = .Debug
//             }

//             log.logf(
//                 level,
//                 "[%s] - %s\n%s",
//                 messageTypes,
//                 pCallbackData.pMessageIdName != nil ? pCallbackData.pMessageIdName : "(no id)",
//                 pCallbackData.pMessage != nil ? pCallbackData.pMessage : "(no message)",
//             )

//             return false
//         }

//         dbg_create_info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
//         dbg_create_info.messageSeverity = severity
//         dbg_create_info.messageType = type
//         dbg_create_info.pfnUserCallback = vk_debug_callback
//         dbg_create_info.pUserData = impl

//         append(&pnext_chain, cast(^vk.BaseOutStructure)&dbg_create_info)
//     }

//     when ODIN_OS == .Darwin {
//         if has_portability_enumeration {
//             ci.flags |= {.ENUMERATE_PORTABILITY_KHR}
//         }
//     }

//     vk_setup_pnext_chain(&ci, pnext_chain[:])

//     // Create the Vulkan Instance
//     if res := vk.CreateInstance(&ci, nil, &impl.instance); res != .SUCCESS {
//         log.errorf("Vulkan: vk.CreateInstance failed: %v", res)
//         free(impl, impl.allocator)
//         return nil
//     }

//     // Load instance-level functions
//     vk.load_proc_addresses_instance(impl.instance)

//     if impl.debug_utils_available {
//         vk_check(vk.CreateDebugUtilsMessengerEXT(
//             impl.instance, &dbg_create_info, nil, &impl.debug_messenger))
//     }

//     hm.dynamic_init(&gpu.vk.surfaces, impl.allocator)
//     hm.dynamic_init(&gpu.vk.adapters, impl.allocator)

//     // Set backend procedures
//     vk_set_procedures()

//     return Instance(impl)
// }

// vk_get_instance_features :: proc(
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Instance_Features,
// ) {
//     features.features = make([]Instance_Feature_Name, 3, allocator) or_else \
//         panic("Failed to allocate []Instance_Feature_Name", loc )
//     features.features[0] = .Timed_Wait_Any
//     features.features[1] = .Shader_Source_SPIRV
//     features.features[2] = .Multiple_Devices_Per_Adapter
//     return
// }

// vk_get_instance_limits :: proc(loc := #caller_location) -> (limits: Instance_Limits) {
//     limits.timed_wait_any_max_count = max(uint) // unlimited
//     return
// }

// vk_has_instance_feature :: proc(feature: Instance_Feature_Name, loc := #caller_location) -> bool {
//     return true // supports all instance features
// }

// vk_get_proc_address :: proc(procName: string, loc := #caller_location) -> Proc {
//     unimplemented(loc = loc)
// }

// vk_set_log_callback :: proc(callback: Log_Callback, userdata: rawptr, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_set_log_level :: proc(level: Log_Level, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_get_version :: proc(loc := #caller_location) -> u32 {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Adapter
// // -----------------------------------------------------------------------------

// VK_Capability :: struct($P, $F: typeid) {
//     properties: P,
//     features:   F,
// }

// VK_Feature :: struct($F: typeid) {
//     using features:  F,
// }

// VK_Property :: struct($P: typeid) {
//     using properties: P,
// }

// VK_Adapter_Capabilities :: struct {
//     using properties:                 vk.PhysicalDeviceProperties,
//     using features:                   vk.PhysicalDeviceFeatures,
//     acceleration_structure:           VK_Capability(
//         vk.PhysicalDeviceAccelerationStructurePropertiesKHR,
//         vk.PhysicalDeviceAccelerationStructureFeaturesKHR),
//     astc_hdr:                         VK_Feature(
//         vk.PhysicalDeviceTextureCompressionASTCHDRFeatures),
//     bit16_storage:                    VK_Feature(vk.PhysicalDevice16BitStorageFeatures),
//     buffer_device_address:            VK_Feature(vk.PhysicalDeviceBufferDeviceAddressFeatures),
//     copy_commands2:                   bool,
//     descriptor_indexing:              VK_Capability(
//         vk.PhysicalDeviceDescriptorIndexingPropertiesEXT,
//         vk.PhysicalDeviceDescriptorIndexingFeatures),
//     device_fault:                     VK_Feature(
//         vk.PhysicalDeviceFaultFeaturesEXT),
//     driver:                           VK_Property(vk.PhysicalDeviceDriverPropertiesKHR),
//     dynamic_rendering:                VK_Feature(vk.PhysicalDeviceDynamicRenderingFeatures),
//     extended_dynamic_state:           VK_Feature(
//         vk.PhysicalDeviceExtendedDynamicStateFeaturesEXT),
//     hdr_metadata:                     bool,
//     maintenance3:                     VK_Property(vk.PhysicalDeviceMaintenance3Properties),
//     maintenance4:                     VK_Capability(
//         vk.PhysicalDeviceMaintenance4Properties,
//         vk.PhysicalDeviceMaintenance4Features),
//     maintenance5:                     VK_Capability(
//         vk.PhysicalDeviceMaintenance5Properties,
//         vk.PhysicalDeviceMaintenance5Features),
//     mesh_shader:                      VK_Capability(
//         vk.PhysicalDeviceMeshShaderPropertiesEXT,
//         vk.PhysicalDeviceMeshShaderFeaturesEXT),
//     multiview:                        VK_Capability(
//         vk.PhysicalDeviceMultiviewProperties,
//         vk.PhysicalDeviceMultiviewFeatures),
//     pci_bus_info:                     VK_Property(
//         vk.PhysicalDevicePCIBusInfoPropertiesEXT),
//     portability_subset:               VK_Capability(
//         vk.PhysicalDevicePortabilitySubsetPropertiesKHR,
//         vk.PhysicalDevicePortabilitySubsetFeaturesKHR),
//     position_fetch:                   VK_Feature(
//         vk.PhysicalDeviceRayTracingPositionFetchFeaturesKHR),
//     properties11:                     VK_Property(vk.PhysicalDeviceVulkan11Properties),
//     properties12:                     VK_Property(vk.PhysicalDeviceVulkan12Properties),
//     properties13:                     VK_Property(vk.PhysicalDeviceVulkan13Properties),
//     ray_query:                        VK_Feature(
//         vk.PhysicalDeviceRayQueryFeaturesKHR),
//     robustness2:                      VK_Capability(
//         vk.PhysicalDeviceRobustness2PropertiesEXT,
//         vk.PhysicalDeviceRobustness2FeaturesEXT),
//     sampler_ycbcr_conversion:         VK_Feature(vk.PhysicalDeviceSamplerYcbcrConversionFeatures),
//     shader_atomic_float:              VK_Feature(
//         vk.PhysicalDeviceShaderAtomicFloatFeaturesEXT),
//     shader_atomic_int64:              VK_Feature(vk.PhysicalDeviceShaderAtomicInt64Features),
//     shader_barycentrics:              VK_Capability(
//         vk.PhysicalDeviceFragmentShaderBarycentricPropertiesKHR,
//         vk.PhysicalDeviceFragmentShaderBarycentricFeaturesKHR),
//     shader_draw_parameters:           VK_Feature(vk.PhysicalDeviceShaderDrawParametersFeatures),
//     shader_float16_int8:              VK_Feature(vk.PhysicalDeviceShaderFloat16Int8Features),
//     shader_image_atomic_int64:        VK_Feature(
//         vk.PhysicalDeviceShaderImageAtomicInt64FeaturesEXT),
//     shader_integer_dot_product:       VK_Feature(vk.PhysicalDeviceShaderIntegerDotProductFeatures),
//     subgroup:                         VK_Property(vk.PhysicalDeviceSubgroupProperties),
//     subgroup_size_control:            VK_Capability(
//         vk.PhysicalDeviceSubgroupSizeControlProperties,
//         vk.PhysicalDeviceSubgroupSizeControlFeatures),
//     swapchain_maintenance1:           VK_Feature(
//         vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT),
//     synchronization2:                 VK_Feature(vk.PhysicalDeviceSynchronization2Features),
//     texture_d24:                      bool,
//     texture_d24_s8:                   bool,
//     texture_s8:                       bool,
//     timeline_semaphore:               VK_Feature(vk.PhysicalDeviceTimelineSemaphoreFeatures),
//     vulkan_13_properties:             VK_Property(
//         vk.PhysicalDeviceVulkan13Properties),
//     vulkan_memory_model:              VK_Feature(vk.PhysicalDeviceVulkanMemoryModelFeatures),
//     zero_initialize_workgroup_memory: VK_Feature(
//         vk.PhysicalDeviceZeroInitializeWorkgroupMemoryFeatures),
//     queue_families:                   []vk.QueueFamilyProperties,
//     memory_properties:                vk.PhysicalDeviceMemoryProperties,
//     extensions:                       []string,
// }

// VK_Adapter_Handle :: distinct hm.Handle64

// VK_Adapter_Impl :: struct {
//     caps:                         VK_Adapter_Capabilities,
//     features:                     []Feature_Name,
//     limits:                       Limits,
//     instance:                     ^VK_Instance_Impl,
//     physical_device:              vk.PhysicalDevice,
//     allocator:                    runtime.Allocator,
//     arena_buf:                    []byte,
//     arena:                        mem.Arena,
//     handle:                       VK_Adapter_Handle,
//     ref:                          Ref_Count_Type,
//     graphics_family_index:        u32,
//     compute_family_index:         u32,
//     transfer_family_index:        u32,
//     has_dedicated_transfer_queue: bool,
// }

// vk_adapter_get_impl :: #force_inline proc "contextless" (
//     adapter: Adapter,
//     loc := #caller_location,
// ) -> ^VK_Adapter_Impl {
//     assert_contextless(adapter != {}, "Invalid adapter", loc)
//     h := transmute(VK_Adapter_Handle)adapter
//     return hm.get(&gpu.vk.adapters, h)
// }

// vk_create_adapter :: proc(
//     instance: ^VK_Instance_Impl,
//     pd: vk.PhysicalDevice,
// ) -> (
//     adapter: Adapter,
//     ok: bool,
// ) {
//     impl: VK_Adapter_Impl

//     impl.instance = instance
//     impl.allocator = instance.allocator
//     impl.physical_device = pd

//     // Get base properties (needed to gate version-specific queries below)
//     vk.GetPhysicalDeviceProperties(pd, &impl.caps.properties)

//     api_version := impl.caps.apiVersion

//     // Get queue families
//     queue_family_count: u32
//     vk.GetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, nil)
//     impl.caps.queue_families = make([]vk.QueueFamilyProperties, queue_family_count, impl.allocator)
//     defer if !ok {delete(impl.caps.queue_families, impl.allocator)}
//     vk.GetPhysicalDeviceQueueFamilyProperties(
//         pd, &queue_family_count, raw_data(impl.caps.queue_families))

//     // Get memory properties
//     vk.GetPhysicalDeviceMemoryProperties(pd, &impl.caps.memory_properties)

//     ta := context.temp_allocator

//     // Get supported device extension names
//     extension_count: u32
//     res := vk.EnumerateDeviceExtensionProperties(pd, nil, &extension_count, nil)
//     if res != .SUCCESS {
//         return
//     }
//     available_extensions := make([]vk.ExtensionProperties, extension_count, ta)
//     res = vk.EnumerateDeviceExtensionProperties(
//         pd, nil, &extension_count, raw_data(available_extensions))
//     if res != .SUCCESS {
//         return
//     }

//     // Initialize an arena allocator with enough space to clone the device
//     // extensions names. Typical devices commonly expose 200-350 extensions
//     impl.arena_buf = make([]byte, 256 * mem.Kilobyte, impl.allocator)
//     mem.arena_init(&impl.arena, impl.arena_buf)
//     defer if !ok {delete(impl.arena_buf, impl.allocator)}

//     buf_allocator := mem.arena_allocator(&impl.arena)

//     impl.caps.extensions = make([]string, extension_count, impl.allocator)
//     for &ext, i in available_extensions {
//         ext_name := byte_arr_str(&ext.extensionName)
//         impl.caps.extensions[i] = strings.clone(ext_name, buf_allocator)
//     }

//     // We use binary search later to optimize the query, this requires data to be sorted
//     slice.sort(impl.caps.extensions)

//     // Get the graphics queue family
//     impl.graphics_family_index = vk_find_queue_family_index(impl.caps.queue_families, {.GRAPHICS})
//     graphics_queue_family: vk.QueueFamilyProperties
//     if impl.graphics_family_index != vk.QUEUE_FAMILY_IGNORED {
//         graphics_queue_family = impl.caps.queue_families[impl.graphics_family_index]
//     }

//     // Get the compute queue family
//     impl.compute_family_index = vk_find_queue_family_index(impl.caps.queue_families, {.COMPUTE})
//     compute_queue_family: vk.QueueFamilyProperties
//     if impl.compute_family_index != vk.QUEUE_FAMILY_IGNORED {
//         compute_queue_family = impl.caps.queue_families[impl.compute_family_index]
//     }

//     // Get the transfer queue family
//     impl.transfer_family_index = vk_find_queue_family_index(impl.caps.queue_families, {.TRANSFER})
//     transfer_queue_family: vk.QueueFamilyProperties
//     if impl.transfer_family_index != vk.QUEUE_FAMILY_IGNORED {
//         transfer_queue_family = impl.caps.queue_families[impl.transfer_family_index]
//     }
//     impl.has_dedicated_transfer_queue = impl.transfer_family_index != impl.graphics_family_index

//     properties_chain := make([dynamic]^vk.BaseOutStructure, ta)
//     features_chain   := make([dynamic]^vk.BaseOutStructure, ta)

//     // Allows setting HDR metadata (e.g., max luminance, color primaries) on
//     // swapchains for HDR displays
//     impl.caps.hdr_metadata = vk_has_extension(
//         impl.caps.extensions, vk.EXT_HDR_METADATA_EXTENSION_NAME)

//     // Limits and capabilities for descriptor indexing (bindless descriptors):
//     // max per-stage/per-type descriptor counts, update-after-bind pool sizes
//     has_descriptor_indexing_ext := api_version >= vk.API_VERSION_1_2 ||
//         vk_has_extension(impl.caps.extensions, vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME)
//     if has_descriptor_indexing_ext {
//         impl.caps.descriptor_indexing = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_PROPERTIES,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
//             },
//         }
//         append(&properties_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.descriptor_indexing.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.descriptor_indexing.features)
//     }

//     // Driver identification: vendor-assigned driver ID, name, info string,
//     // and conformance test suite version
//     if vk_has_extension(impl.caps.extensions, vk.KHR_DRIVER_PROPERTIES_EXTENSION_NAME) {
//         impl.caps.driver = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_DRIVER_PROPERTIES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.driver.properties)
//     }

//     // Limits on descriptor sets and memory allocations visible to a single
//     // pipeline stage (e.g., maxPerSetDescriptors, maxMemoryAllocationSize)
//     has_maintenance3_ext := api_version >= vk.API_VERSION_1_1 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_MAINTENANCE_3_EXTENSION_NAME)
//     if has_maintenance3_ext {
//         impl.caps.maintenance3 = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_MAINTENANCE_3_PROPERTIES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.maintenance3.properties)
//     }

//     // Exposes maxBufferSize, the maximum byte size of a single buffer resource,
//     // which may exceed the Vulkan 1.0 limit on some implementations
//     can_query_maintenance4 := api_version >= vk.API_VERSION_1_3 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_MAINTENANCE_5_EXTENSION_NAME)
//     if can_query_maintenance4 {
//         impl.caps.maintenance4 = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_MAINTENANCE_4_PROPERTIES,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_MAINTENANCE_4_FEATURES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.maintenance4.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.maintenance4.features)
//     }

//     // Buffer usage querying without creating a buffer, early fragment test
//     // interactions, and relaxed SPIR-V entry point rules introduced in maintenance5
//     can_query_maintenance5 := api_version >= vk.API_VERSION_1_4 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_MAINTENANCE_5_EXTENSION_NAME)
//     if can_query_maintenance5 {
//         impl.caps.maintenance5 = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_MAINTENANCE_5_PROPERTIES,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.maintenance5.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.maintenance5.features)
//     }

//     // Multiview rendering limits: max view count and max instance index
//     // for draw calls inside a multiview render pass (e.g., VR stereo rendering)
//     has_multiview_ext := api_version >= vk.API_VERSION_1_1 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_MULTIVIEW_EXTENSION_NAME)
//     if has_multiview_ext {
//         impl.caps.multiview = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_MULTIVIEW_PROPERTIES,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_MULTIVIEW_FEATURES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.multiview.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.multiview.features)
//     }

//     // Subgroup (warp/wavefront) capabilities: size, supported stages,
//     // and supported subgroup operations (arithmetic, ballot, shuffle, etc.)
//     if api_version >= vk.API_VERSION_1_1 {
//         impl.caps.subgroup = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_SUBGROUP_PROPERTIES,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.subgroup.properties)
//     }

//     // Min/max subgroup sizes when VK_EXT_subgroup_size_control is in use,
//     // allowing shaders to request a specific SIMD width at pipeline creation
//     has_subgroup_size_control_ext := api_version >= vk.API_VERSION_1_3 ||
//         vk_has_extension(impl.caps.extensions, vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME)
//     if has_subgroup_size_control_ext {
//         impl.caps.subgroup_size_control = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES,
//             },
//         }
//         append(&properties_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.subgroup_size_control.properties)
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.subgroup_size_control.features)
//     }

//     // Required on non-conformant Vulkan implementations (e.g., MoltenVK
//     // on Metal): advertises which standard Vulkan features are unavailable
//     has_portability_subset_ext :=
//         vk_has_extension(impl.caps.extensions, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME)
//     if has_portability_subset_ext {
//         impl.caps.portability_subset = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_PORTABILITY_SUBSET_PROPERTIES_KHR,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_PORTABILITY_SUBSET_FEATURES_KHR,
//             },
//         }
//         append(&properties_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.portability_subset.properties)
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.portability_subset.features)
//     }

//     // Core Vulkan 1.1 properties: includes subgroup size, device ID,
//     // point clipping behavior, and protected memory support
//     if impl.caps.properties.apiVersion >= vk.API_VERSION_1_2 {
//         impl.caps.properties11.properties = {
//             sType = .PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES,
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.properties11.properties)
//     }

//     // Core Vulkan 1.2 properties: includes driver info, shader float controls,
//     // descriptor indexing limits, and depth resolve modes
//     if impl.caps.properties.apiVersion >= vk.API_VERSION_1_2 {
//         impl.caps.properties12.properties = {
//             sType = .PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES,
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.properties12.properties)
//     }

//     // Core Vulkan 1.3 properties: includes limits for inline uniform blocks,
//     // max buffer size, and other 1.3-specific device limits
//     if impl.caps.properties.apiVersion >= vk.API_VERSION_1_3 {
//         impl.caps.properties13.properties = {
//             sType = .PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES,
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.properties13.properties)
//     }

//     // Ray tracing acceleration structure limits: max geometry/instance/primitive
//     // counts, scratch buffer alignment, and AS compaction support
//     has_acceleration_structure_ext :=
//         vk_has_extension(impl.caps.extensions, vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME)
//     if has_acceleration_structure_ext {
//         impl.caps.acceleration_structure = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR,
//             },
//         }
//         append(&properties_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.acceleration_structure.properties)
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.acceleration_structure.features)
//     }

//     // Mesh/task shader limits: max threadgroup sizes, shared memory,
//     // output vertices/primitives, and preferred mesh output granularity
//     has_mesh_shader_ext :=vk_has_extension(impl.caps.extensions, vk.EXT_MESH_SHADER_EXTENSION_NAME)
//     if has_mesh_shader_ext {
//         impl.caps.mesh_shader = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_MESH_SHADER_PROPERTIES_EXT,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.mesh_shader.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.mesh_shader.features)
//     }

//     impl.caps.copy_commands2 = vk_has_extension(
//         impl.caps.extensions, vk.KHR_COPY_COMMANDS_2_EXTENSION_NAME)

//     // PCI topology identifiers (domain, bus, device, function) for
//     // correlating the Vulkan device with OS-level GPU enumeration
//     if vk_has_extension(impl.caps.extensions, vk.EXT_PCI_BUS_INFO_EXTENSION_NAME) {
//         impl.caps.pci_bus_info = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_PCI_BUS_INFO_PROPERTIES_EXT,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.pci_bus_info.properties)
//     }

//     // Alignment requirements for robust buffer/image access when
//     // nullDescriptor or robustBufferAccess2/robustImageAccess2 are enabled
//     has_robustness2_ext :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_ROBUSTNESS_2_EXTENSION_NAME)
//     if has_robustness2_ext {
//         impl.caps.robustness2 = {
//             properties = {
//                 sType = .PHYSICAL_DEVICE_ROBUSTNESS_2_PROPERTIES_EXT,
//             },
//             features = {
//                 sType = .PHYSICAL_DEVICE_ROBUSTNESS_2_FEATURES_EXT,
//             },
//         }
//         append(&properties_chain, cast(^vk.BaseOutStructure)&impl.caps.robustness2.properties)
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.robustness2.features)
//     }

//     // 16-bit integer and float types in storage classes (UBOs, SSBOs, push
//     // constants, and shader I/O interfaces)
//     can_query_bit16_storage := api_version >= vk.API_VERSION_1_1 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_16BIT_STORAGE_EXTENSION_NAME)
//     if can_query_bit16_storage {
//         impl.caps.bit16_storage.features = {
//             sType = .PHYSICAL_DEVICE_16BIT_STORAGE_FEATURES,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.bit16_storage.features)
//     }

//     // GPU virtual address access from shaders via uint64 pointers, required
//     // for ray tracing, descriptor buffers, and pointer-based data structures
//     can_query_buffer_device_address :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME)
//     if can_query_buffer_device_address {
//         impl.caps.buffer_device_address.features = {
//             sType = .PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.buffer_device_address.features)
//     }

//     // YCbCr image sampling for video decode output and camera feed textures,
//     // with format conversion happening inside the combined image sampler
//     can_query_sampler_ycbcr_conversion := api_version >= vk.API_VERSION_1_1 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_SAMPLER_YCBCR_CONVERSION_EXTENSION_NAME)
//     if can_query_sampler_ycbcr_conversion {
//         impl.caps.sampler_ycbcr_conversion.features = {
//             sType = .PHYSICAL_DEVICE_SAMPLER_YCBCR_CONVERSION_FEATURES,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.sampler_ycbcr_conversion.features)
//     }

//     // 64-bit integer atomic operations (add, min, max, compare-swap) on
//     // storage buffers and shared memory from compute and fragment shaders
//     can_query_shader_atomic_int64 := api_version >= vk.API_VERSION_1_2 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME)
//     if can_query_shader_atomic_int64 {
//         impl.caps.shader_atomic_int64.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.shader_atomic_int64.features)
//     }

//     // Enables gl_DrawID, gl_BaseVertex, and gl_BaseInstance built-ins in
//     // vertex shaders for multi-draw indirect and instanced draw calls
//     if api_version >= vk.API_VERSION_1_1 {
//         impl.caps.shader_draw_parameters.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_DRAW_PARAMETERS_FEATURES,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.shader_draw_parameters.features)
//     }

//     // float16 arithmetic and int8 arithmetic in shaders, useful for
//     // ML inference workloads and bandwidth-sensitive compute kernels
//     can_query_shader_float16_int8 := api_version >= vk.API_VERSION_1_2 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME)
//     if can_query_shader_float16_int8 {
//         impl.caps.shader_float16_int8.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.shader_float16_int8.features)
//     }

//     // Dot product instructions operating on packed integer vectors, accelerated
//     // on hardware with dedicated DP4a units (e.g., RDNA, Turing+)
//     has_shader_integer_dot_product_ext := api_version >= vk.API_VERSION_1_3 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME)
//     if has_shader_integer_dot_product_ext {
//         impl.caps.shader_integer_dot_product.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_FEATURES,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.shader_integer_dot_product.features)
//     }

//     // Vulkan memory model: formally defined acquire/release memory ordering
//     // semantics for shader memory operations, enabling correct lock-free algorithms
//     has_vulkan_memory_model_ext := api_version >= vk.API_VERSION_1_2 ||
//         vk_has_extension(impl.caps.extensions, vk.KHR_VULKAN_MEMORY_MODEL_EXTENSION_NAME)
//     if has_vulkan_memory_model_ext {
//         impl.caps.vulkan_memory_model.features = {
//             sType = .PHYSICAL_DEVICE_VULKAN_MEMORY_MODEL_FEATURES,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.vulkan_memory_model.features)
//     }

//     // Workgroup shared memory is guaranteed to be zero-initialized at the
//     // start of each compute dispatch, removing the need for manual clearing
//     has_zero_initialize_workgroup_memory_ext := api_version >= vk.API_VERSION_1_3 ||
//         vk_has_extension(impl.caps.extensions,
//             vk.KHR_ZERO_INITIALIZE_WORKGROUP_MEMORY_EXTENSION_NAME)
//     if has_zero_initialize_workgroup_memory_ext {
//         impl.caps.zero_initialize_workgroup_memory.features = {
//             sType = .PHYSICAL_DEVICE_ZERO_INITIALIZE_WORKGROUP_MEMORY_FEATURES,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.zero_initialize_workgroup_memory.features)
//     }

//     // On GPU crash or TDR, captures a vendor fault report with shader
//     // addresses and resource info to aid post-mortem debugging
//     can_query_device_fault :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_DEVICE_FAULT_EXTENSION_NAME)
//     if can_query_device_fault {
//         impl.caps.device_fault.features = vk.PhysicalDeviceFaultFeaturesEXT {
//             sType = .PHYSICAL_DEVICE_FAULT_FEATURES_EXT,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.device_fault.features)
//     }

//     // Exposes gl_BaryCoordKHR and gl_BaryCoordNoPerspKHR in fragment
//     // shaders for custom attribute interpolation and wireframe rendering
//     has_shader_barycentrics_ext :=
//         vk_has_extension(impl.caps.extensions, vk.KHR_FRAGMENT_SHADER_BARYCENTRIC_EXTENSION_NAME)
//     if has_shader_barycentrics_ext {
//         impl.caps.shader_barycentrics.features = {
//             sType = .PHYSICAL_DEVICE_FRAGMENT_SHADER_BARYCENTRIC_FEATURES_KHR,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.shader_barycentrics.features)
//     }

//     // Inline ray traversal from any shader stage (compute, fragment, etc.)
//     // without a full ray tracing pipeline or shader binding table
//     can_query_ray_query := vk_has_extension(impl.caps.extensions, vk.KHR_RAY_QUERY_EXTENSION_NAME)
//     if can_query_ray_query {
//         impl.caps.ray_query.features = {
//             sType = .PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.ray_query.features)
//     }

//     // Allows hit shaders to fetch triangle vertex positions directly from
//     // the acceleration structure, avoiding a redundant vertex buffer read
//     can_query_position_fetch :=
//         vk_has_extension(impl.caps.extensions, vk.KHR_RAY_TRACING_POSITION_FETCH_EXTENSION_NAME)
//     if can_query_position_fetch {
//         impl.caps.position_fetch.features = {
//             sType = .PHYSICAL_DEVICE_RAY_TRACING_POSITION_FETCH_FEATURES_KHR,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.position_fetch.features)
//     }

//     can_query_shader_atomic_float :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_SHADER_ATOMIC_FLOAT_EXTENSION_NAME)
//     if can_query_shader_atomic_float {
//         // Floating-point atomic add, min, and max on storage buffers and
//         // images, useful for lock-free histogram and reduction passes
//         impl.caps.shader_atomic_float.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_FEATURES_EXT,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.shader_atomic_float.features)
//     }

//     has_shader_image_atomic_int64_ext :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_SHADER_IMAGE_ATOMIC_INT64_EXTENSION_NAME)
//     if has_shader_image_atomic_int64_ext {
//         // 64-bit integer atomics directly on image resources (storage images),
//         // extending shader_atomic_int64 to image memory
//         impl.caps.shader_image_atomic_int64.features = {
//             sType = .PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT64_FEATURES_EXT,
//         }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.shader_image_atomic_int64.features)
//     }

//     // Deferred swapchain destruction, per-present fence signaling, and
//     // the ability to change present modes without recreating the swapchain
//     can_query_swapchain_maintenance1 :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME)
//     if can_query_swapchain_maintenance1 {
//         impl.caps.swapchain_maintenance1.features =
//             vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT {
//                 sType = .PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT,
//             }
//         append(&features_chain,
//             cast(^vk.BaseOutStructure)&impl.caps.swapchain_maintenance1.features)
//     }

//     // ASTC compressed formats with HDR (floating-point) endpoints, used
//     // for HDR environment maps and emissive textures on mobile/tiled GPUs
//     can_query_astc_hdr :=
//         vk_has_extension(impl.caps.extensions, vk.EXT_TEXTURE_COMPRESSION_ASTC_HDR_EXTENSION_NAME)
//     if can_query_astc_hdr {
//         impl.caps.astc_hdr.features = {
//             sType = .PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTC_HDR_FEATURES,
//         }
//         append(&features_chain, cast(^vk.BaseOutStructure)&impl.caps.astc_hdr.features)
//     }

//     // Chain props2
//     props2 := vk.PhysicalDeviceProperties2 {
//         sType = .PHYSICAL_DEVICE_PROPERTIES_2,
//     }
//     vk_setup_pnext_chain(&props2, properties_chain[:])
//     vk.GetPhysicalDeviceProperties2(pd, &props2)
//     impl.caps.properties = props2.properties

//     // Chain features2
//     vk_features2 := vk.PhysicalDeviceFeatures2 {
//         sType = .PHYSICAL_DEVICE_FEATURES_2,
//     }
//     vk_setup_pnext_chain(&vk_features2, features_chain[:])
//     vk.GetPhysicalDeviceFeatures2(pd, &vk_features2)
//     impl.caps.features = vk_features2.features

//     // Aliases to common properties
//     limits := impl.caps.properties.limits
//     descriptor_indexing := impl.caps.descriptor_indexing.properties
//     maintenance3 := impl.caps.maintenance3.properties

//     max_per_set_descriptors := maintenance3.maxPerSetDescriptors
//     max_bindings_per_bind_group := max(1000, max_per_set_descriptors)

//     // Divisor used to derive a safe per-stage descriptor budget from the
//     // set-wide limit (maxDescriptorSet*). Since pipelines are usually
//     // vertex + fragment, dividing by 2 ensures both stages can each use
//     // the advertised limit without exceeding the total descriptor set capacity.
//     MAX_SHADER_STAGES_PER_PIPELINE :: 2

//     max_sampled_textures_per_shader_stage := min(
//         limits.maxPerStageDescriptorSampledImages,
//         limits.maxDescriptorSetSampledImages / MAX_SHADER_STAGES_PER_PIPELINE,
//     )

//     max_samplers_per_shader_stage := min(
//         limits.maxPerStageDescriptorSamplers,
//         limits.maxDescriptorSetSamplers / MAX_SHADER_STAGES_PER_PIPELINE,
//     )

//     max_storage_buffers_per_shader_stage := min(
//         limits.maxPerStageDescriptorStorageBuffers,
//         limits.maxDescriptorSetStorageBuffers / MAX_SHADER_STAGES_PER_PIPELINE,
//     )

//     max_storage_textures_per_shader_stage := min(
//         limits.maxPerStageDescriptorStorageImages,
//         limits.maxDescriptorSetStorageImages / MAX_SHADER_STAGES_PER_PIPELINE,
//     )

//     max_uniform_buffers_per_shader_stage := min(
//         limits.maxPerStageDescriptorUniformBuffers,
//         limits.maxDescriptorSetUniformBuffers / MAX_SHADER_STAGES_PER_PIPELINE,
//     )

//     max_binding_array_elements := min(
//         descriptor_indexing.maxDescriptorSetUpdateAfterBindSampledImages,
//         descriptor_indexing.maxDescriptorSetUpdateAfterBindStorageImages,
//         descriptor_indexing.maxDescriptorSetUpdateAfterBindStorageBuffers,
//         descriptor_indexing.maxPerStageDescriptorUpdateAfterBindSampledImages,
//         descriptor_indexing.maxPerStageDescriptorUpdateAfterBindStorageImages,
//         descriptor_indexing.maxPerStageDescriptorUpdateAfterBindStorageBuffers,
//     )

//     max_sampler_binding_array_elements := min(
//         descriptor_indexing.maxDescriptorSetUpdateAfterBindSamplers,
//         descriptor_indexing.maxPerStageDescriptorUpdateAfterBindSamplers,
//     )

//     max_memory_allocation_size := vk.DeviceSize(maintenance3.maxMemoryAllocationSize)

//     max_buffer_size: vk.DeviceSize = max(vk.DeviceSize)
//     if can_query_maintenance4 {
//         max_buffer_size = vk.DeviceSize(impl.caps.maintenance4.properties.maxBufferSize)
//     }
//     max_buffer_size = min(max_buffer_size, max_memory_allocation_size)

//     // On Linux non-NVIDIA drivers, there's a known issue where very large buffer
//     // sizes (>2GB) can cause problems, so we limit it to max(i32). NVIDIA drivers
//     // and other platforms can handle the full size.
//     max_buffer_size_cap: vk.DeviceSize = 1 << 52
//     when ODIN_OS == .Linux {
//         if impl.caps.properties.vendorID != VENDOR_NVIDIA {
//             max_buffer_size_cap = vk.DeviceSize(max(i32))
//         }
//     }
//     max_buffer_size = min(max_buffer_size, max_buffer_size_cap)

//     max_color_attachments := min(limits.maxColorAttachments, limits.maxFragmentOutputAttachments)
//     max_color_attachment_bytes_per_sample := max_color_attachments * MAX_TARGET_PIXEL_BYTE_COST

//     // Mesh shader limits
//     max_task_workgroup_total_count: u32
//     max_task_workgroups_per_dimension: u32
//     max_mesh_workgroup_total_count: u32
//     max_mesh_workgroups_per_dimension: u32
//     max_task_invocations_per_workgroup: u32
//     max_task_invocations_per_dimension: u32
//     max_mesh_invocations_per_workgroup: u32
//     max_mesh_invocations_per_dimension: u32
//     max_task_payload_size: u32
//     max_mesh_output_vertices: u32
//     max_mesh_output_primitives: u32
//     max_mesh_output_layers: u32
//     max_mesh_multiview_view_count: u32

//     if has_mesh_shader_ext {
//         mesh_shader := impl.caps.mesh_shader.properties
//         max_task_workgroup_total_count = mesh_shader.maxTaskWorkGroupTotalCount
//         max_task_workgroups_per_dimension = min(
//             mesh_shader.maxTaskWorkGroupCount.x,
//             mesh_shader.maxTaskWorkGroupCount.y,
//             mesh_shader.maxTaskWorkGroupCount.z,
//         )
//         max_mesh_workgroup_total_count = mesh_shader.maxMeshWorkGroupTotalCount
//         max_mesh_workgroups_per_dimension = min(
//             mesh_shader.maxMeshWorkGroupCount.x,
//             mesh_shader.maxMeshWorkGroupCount.y,
//             mesh_shader.maxMeshWorkGroupCount.z,
//         )
//         max_task_invocations_per_workgroup = mesh_shader.maxTaskWorkGroupInvocations
//         max_task_invocations_per_dimension = min(
//             mesh_shader.maxTaskWorkGroupSize.x,
//             mesh_shader.maxTaskWorkGroupSize.y,
//             mesh_shader.maxTaskWorkGroupSize.z,
//         )
//         max_mesh_invocations_per_workgroup = mesh_shader.maxMeshWorkGroupInvocations
//         max_mesh_invocations_per_dimension = min(
//             mesh_shader.maxMeshWorkGroupSize.x,
//             mesh_shader.maxMeshWorkGroupSize.y,
//             mesh_shader.maxMeshWorkGroupSize.z,
//         )
//         max_task_payload_size = mesh_shader.maxTaskPayloadSize
//         max_mesh_output_vertices = mesh_shader.maxMeshOutputVertices
//         max_mesh_output_primitives = mesh_shader.maxMeshOutputPrimitives
//         max_mesh_output_layers = mesh_shader.maxMeshOutputLayers
//         max_mesh_multiview_view_count = mesh_shader.maxMeshMultiviewViewCount
//     }

//     // Acceleration structure limits
//     max_blas_geometry_count: u32
//     max_blas_primitive_count: u32
//     max_tlas_instance_count: u32
//     max_acceleration_structures_per_shader_stage: u32

//     if has_acceleration_structure_ext {
//         acl := impl.caps.acceleration_structure.properties
//         max_blas_geometry_count = u32(acl.maxGeometryCount)
//         max_blas_primitive_count = u32(acl.maxPrimitiveCount)
//         max_tlas_instance_count = u32(acl.maxInstanceCount)
//         max_acceleration_structures_per_shader_stage = min(
//             acl.maxPerStageDescriptorAccelerationStructures,
//             acl.maxDescriptorSetAccelerationStructures / MAX_SHADER_STAGES_PER_PIPELINE,
//         )
//     }

//     // Multiview limits
//     max_multiview_view_count := impl.caps.multiview.properties.maxMultiviewViewCount

//     // Fill WebGPU limits
//     impl.limits = {
//         // WebGPU
//         max_texture_dimension_1d                            = limits.maxImageDimension1D,
//         max_texture_dimension_2d                            = min(
//             limits.maxImageDimension2D,
//             limits.maxImageDimensionCube,
//             limits.maxFramebufferWidth,
//             limits.maxFramebufferHeight,
//         ),
//         max_texture_dimension_3d                            = limits.maxImageDimension3D,
//         max_texture_array_layers                            = limits.maxImageArrayLayers,
//         max_bind_groups                                     = limits.maxBoundDescriptorSets,
//         max_bind_groups_plus_vertex_buffers                 = limits.maxBoundDescriptorSets + limits.maxVertexInputBindings,
//         max_bindings_per_bind_group                         = max_bindings_per_bind_group,
//         max_dynamic_uniform_buffers_per_pipeline_layout     = limits.maxDescriptorSetUniformBuffersDynamic,
//         max_dynamic_storage_buffers_per_pipeline_layout     = limits.maxDescriptorSetStorageBuffersDynamic,
//         max_sampled_textures_per_shader_stage               = max_sampled_textures_per_shader_stage,
//         max_samplers_per_shader_stage                       = max_samplers_per_shader_stage,
//         max_storage_buffers_per_shader_stage                = max_storage_buffers_per_shader_stage,
//         max_storage_textures_per_shader_stage               = max_storage_textures_per_shader_stage,
//         max_uniform_buffers_per_shader_stage                = max_uniform_buffers_per_shader_stage,
//         max_uniform_buffer_binding_size                     = u64(limits.maxUniformBufferRange),
//         max_storage_buffer_binding_size                     = u64(limits.maxStorageBufferRange),
//         min_uniform_buffer_offset_alignment                 = u32(
//             limits.minUniformBufferOffsetAlignment,
//         ),
//         min_storage_buffer_offset_alignment                 = u32(
//             limits.minStorageBufferOffsetAlignment,
//         ),
//         max_vertex_buffers                                  = limits.maxVertexInputBindings,
//         max_buffer_size                                     = u64(max_buffer_size),
//         max_vertex_attributes                               = limits.maxVertexInputAttributes,
//         max_vertex_buffer_array_stride                      = limits.maxVertexInputBindingStride,
//         max_inter_stage_shader_variables                    = min(
//             limits.maxVertexOutputComponents,
//             limits.maxFragmentInputComponents / 4 - 1,
//         ),
//         max_color_attachments                               = max_color_attachments,
//         max_color_attachment_bytes_per_sample               = max_color_attachment_bytes_per_sample,
//         max_compute_workgroup_storage_size                  = limits.maxComputeSharedMemorySize,
//         max_compute_invocations_per_workgroup               = limits.maxComputeWorkGroupInvocations,
//         max_compute_workgroup_size_x                        = limits.maxComputeWorkGroupSize.x,
//         max_compute_workgroup_size_y                        = limits.maxComputeWorkGroupSize.y,
//         max_compute_workgroup_size_z                        = limits.maxComputeWorkGroupSize.z,
//         max_compute_workgroups_per_dimension                = min(
//             limits.maxComputeWorkGroupCount.x,
//             limits.maxComputeWorkGroupCount.y,
//             limits.maxComputeWorkGroupCount.z,
//         ),
//         max_immediate_size                                  = limits.maxPushConstantsSize,

//         // Native
//         max_non_sampler_bindings                            = max(u32),
//         max_binding_array_elements_per_shader_stage         = max_binding_array_elements,
//         max_binding_array_sampler_elements_per_shader_stage = max_sampler_binding_array_elements,
//         max_multiview_view_count                            = max_multiview_view_count,
//     }

//     features := make([dynamic]Feature_Name, 0, len(Feature_Name), impl.allocator)

//     // Always-available features
//     append(&features, Feature_Name.Immediates)
//     append(&features, Feature_Name.Mappable_Primary_Buffers)
//     append(&features, Feature_Name.Texture_Adapter_Specific_Format_Features)
//     append(&features, Feature_Name.Clear_Texture)
//     append(&features, Feature_Name.Pipeline_Cache)
//     append(&features, Feature_Name.Shader_Early_Depth_Test)
//     append(&features, Feature_Name.Texture_Atomic)
//     append(&features, Feature_Name.Memory_Decoration_Coherent)
//     append(&features, Feature_Name.Memory_Decoration_Volatile)

//     // Timestamp queries require at least 36 valid bits to avoid wrap-around
//     // at practical GPU frequencies expose all three granularities if available
//     if graphics_queue_family.timestampValidBits >= 36 {
//         append(&features, Feature_Name.Timestamp_Query)
//         append(&features, Feature_Name.Timestamp_Query_Inside_Encoders)
//         append(&features, Feature_Name.Timestamp_Query_Inside_Passes)
//     }

//     // First-instance support allows gl_BaseInstance / firstInstance in indirect
//     // draws, required for efficient GPU-driven rendering
//     if impl.caps.features.drawIndirectFirstInstance {
//         append(&features, Feature_Name.Indirect_First_Instance)
//     }

//     // Non-solid fill modes (wireframe / point cloud) for debug visualization
//     if impl.caps.features.fillModeNonSolid {
//         append(&features, Feature_Name.Polygon_Mode_Point)
//         append(&features, Feature_Name.Polygon_Mode_Line)
//     }

//     // ASTC LDR compressed textures for mobile/tiled GPU bandwidth savings
//     if impl.caps.features.textureCompressionASTC_LDR {
//         append(&features, Feature_Name.Texture_Compression_ASTC)
//     }

//     // BC (DXT/S3TC) compressed textures, standard on desktop GPUs
//     if impl.caps.features.textureCompressionBC {
//         append(&features, Feature_Name.Texture_Compression_BC)
//         append(&features, Feature_Name.Texture_Compression_BC_Sliced_3D)
//     }

//     // Pipeline statistics queries (vertex invocations, fragment invocations,
//     // etc.) for GPU performance profiling
//     if impl.caps.features.pipelineStatisticsQuery {
//         append(&features, Feature_Name.Pipeline_Statistics_Query)
//     }

//     // Storage buffer and image writes from vertex/geometry stages, needed
//     // for GPU-driven culling that writes visibility results from vertex shaders
//     if impl.caps.features.vertexPipelineStoresAndAtomics {
//         append(&features, Feature_Name.Vertex_Writable_Storage)
//     }

//     // 64-bit float arithmetic in shaders for scientific/simulation workloads
//     if impl.caps.features.shaderFloat64 {
//         append(&features, Feature_Name.Shader_F64)
//     }

//     // 64-bit integer arithmetic in shaders
//     if impl.caps.features.shaderInt64 {
//         append(&features, Feature_Name.Shader_Int64)
//     }

//     // 16-bit integer arithmetic in shaders for bandwidth-sensitive compute
//     if impl.caps.features.shaderInt16 {
//         append(&features, Feature_Name.Shader_I16)
//     }

//     // Geometry shaders expose gl_PrimitiveID in fragment shaders without
//     // requiring a full geometry stage in the pipeline
//     if impl.caps.features.geometryShader {
//         append(&features, Feature_Name.Primitive_Index)
//     }

//     // 64-bit integer atomics on both SSBOs and shared memory both must be
//     // present for a coherent atomic programming model
//     if impl.caps.shader_atomic_int64.features.shaderBufferInt64Atomics &&
//            impl.caps.shader_atomic_int64.features.shaderSharedInt64Atomics {
//         append(&features, Feature_Name.Shader_Int64_Atomic_All_Ops)
//         append(&features, Feature_Name.Shader_Int64_Atomic_Min_Max)
//     }

//     // 64-bit integer atomics directly on storage images (extends buffer atomics
//     // to image memory for lock-free texture updates)
//     if impl.caps.shader_image_atomic_int64.features.shaderImageInt64Atomics {
//         append(&features, Feature_Name.Texture_Int64_Atomic)
//     }

//     // float32 atomic add on SSBOs, used for lock-free accumulation passes
//     // such as order-independent transparency and light binning
//     if impl.caps.shader_atomic_float.features.shaderBufferFloat32Atomics &&
//             impl.caps.shader_atomic_float.features.shaderBufferFloat32AtomicAdd {
//         append(&features, Feature_Name.Shader_Float32_Atomic)
//     }

//     // Fragment shader barycentric coordinates for custom attribute interpolation
//     // and analytical wireframe rendering without geometry shaders
//     if impl.caps.shader_barycentrics.features.fragmentShaderBarycentric {
//         append(&features, Feature_Name.Shader_Barycentrics)
//         append(&features, Feature_Name.Shader_Per_Vertex)
//     }

//     // vkCmdDrawIndirectCount / vkCmdDrawIndexedIndirectCount for GPU-driven
//     // rendering where the draw count itself is determined on the GPU
//     if vk_has_extension(impl.caps.extensions, vk.KHR_DRAW_INDIRECT_COUNT_EXTENSION_NAME) {
//         append(&features, Feature_Name.Multi_Draw_Indirect_Count)
//     }

//     // Conservative rasterization guarantees a fragment is generated if a
//     // primitive touches any part of a pixel, used for voxelization and occlusion
//     if vk_has_extension(impl.caps.extensions, vk.EXT_CONSERVATIVE_RASTERIZATION_EXTENSION_NAME) {
//         append(&features, Feature_Name.Conservative_Rasterization)
//     }

//     // Ray tracing hit shaders can read back triangle vertex positions directly
//     // from the BLAS without a separate vertex buffer fetch
//     if vk_has_extension(impl.caps.extensions, vk.KHR_RAY_TRACING_POSITION_FETCH_EXTENSION_NAME) {
//         // append(&features, Feature_Name.Ray_Hit_Vertex_Return)
//     }

//     // Bindless descriptor indexing: all three resource types (sampled images,
//     // storage images, storage buffers) must support non-uniform indexing and
//     // update-after-bind to advertise the full bindless feature set
//     f_descriptor_indexing := impl.caps.descriptor_indexing.features

//     supports_descriptor_indexing :=
//         f_descriptor_indexing.shaderSampledImageArrayNonUniformIndexing &&
//         f_descriptor_indexing.descriptorBindingSampledImageUpdateAfterBind &&
//         f_descriptor_indexing.shaderStorageImageArrayNonUniformIndexing &&
//         f_descriptor_indexing.descriptorBindingStorageImageUpdateAfterBind &&
//         f_descriptor_indexing.shaderStorageBufferArrayNonUniformIndexing &&
//         f_descriptor_indexing.descriptorBindingStorageBufferUpdateAfterBind

//     if supports_descriptor_indexing {
//         append(&features, Feature_Name.Texture_Binding_Array)
//         append(&features, Feature_Name.Storage_Resource_Binding_Array)
//         append(
//             &features,
//             Feature_Name.Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
//         )
//         append(&features, Feature_Name.Storage_Texture_Array_Non_Uniform_Indexing)
//     }

//     // Depth clamping instead of clipping: fragments outside [0,1] depth are
//     // clamped rather than discarded, used for shadow volume rendering
//     if impl.caps.features.depthClamp {
//         append(&features, Feature_Name.Depth_Clip_Control)
//     }

//     // Two source inputs to the blend unit from the same fragment shader
//     // invocation, required for sub-pixel font rendering (Porter-Duff src1)
//     if impl.caps.features.dualSrcBlend {
//         append(&features, Feature_Name.Dual_Source_Blending)
//     }

//     // gl_ClipDistance[] built-in for user-defined clip planes in vertex shaders
//     if impl.caps.features.shaderClipDistance {
//         append(&features, Feature_Name.Clip_Distances)
//     }

//     // Render to multiple views in a single pass SELECTIVE_MULTIVIEW allows
//     // per-draw view masks for asymmetric rendering (e.g. foveated VR)
//     if impl.caps.multiview.features.multiview {
//         append(&features, Feature_Name.Multiview)
//         append(&features, Feature_Name.Selective_Multiview)
//     }

//     VK_DEPTH_STENCIL_REQUIRED_FLAGS :: vk.FormatFeatureFlags {
//         .SAMPLED_IMAGE,
//         .DEPTH_STENCIL_ATTACHMENT,
//     }

//     supports_format :: proc(
//         pd: vk.PhysicalDevice,
//         format: vk.Format,
//         tiling: vk.ImageTiling,
//         features: vk.FormatFeatureFlags,
//     ) -> bool {
//         properties: vk.FormatProperties
//         vk.GetPhysicalDeviceFormatProperties(pd, format, &properties)
//         #partial switch tiling {
//         case .LINEAR:
//             return features & properties.linearTilingFeatures != {}
//         case .OPTIMAL:
//             return features & properties.optimalTilingFeatures != {}
//         case:
//             return false
//         }
//     }

//     supports_depth_format :: proc(pd: vk.PhysicalDevice, format: vk.Format) -> bool {
//         return supports_format(pd, format, .OPTIMAL, VK_DEPTH_STENCIL_REQUIRED_FLAGS)
//     }

//     is_format16bit_norm_supported :: proc(pd: vk.PhysicalDevice) -> bool {
//         FORMATS :: []vk.Format {
//             .R16_UNORM,
//             .R16_SNORM,
//             .R16G16_UNORM,
//             .R16G16_SNORM,
//             .R16G16B16A16_UNORM,
//             .R16G16B16A16_SNORM,
//         }
//         features := vk.FormatFeatureFlags {
//             .SAMPLED_IMAGE,
//             .STORAGE_IMAGE,
//             .TRANSFER_SRC,
//             .TRANSFER_DST,
//         }
//         for vk_format in FORMATS {
//             if (!supports_format(pd, vk_format, .OPTIMAL, features)) {
//                 return false
//             }
//         }
//         return true
//     }

//     impl.caps.texture_d24 = supports_depth_format(pd, .X8_D24_UNORM_PACK32)
//     impl.caps.texture_d24_s8 = supports_depth_format(pd, .D24_UNORM_S8_UINT)
//     impl.caps.texture_s8 = supports_depth_format(pd, .S8_UINT)

//     // 16-bit normalized formats (e.g. R16_UNORM) as render targets and
//     // sampled textures, not guaranteed by the Vulkan 1.3 baseline
//     if is_format16bit_norm_supported(pd) {
//         append(&features, Feature_Name.Texture_Format_16Bit_Norm)
//     }

//     // ASTC HDR compressed formats with floating-point endpoints for HDR
//     // environment maps and emissive textures on mobile GPUs
//     if impl.caps.astc_hdr.features.textureCompressionASTC_HDR {
//         append(&features, Feature_Name.Texture_Compression_Astc_Hdr)
//     }

//     // 3D slices of ASTC LDR compressed textures (requires textureCompressionASTC_LDR)
//     if impl.caps.features.textureCompressionASTC_LDR {
//         append(&features, Feature_Name.Texture_Compression_ASTC_Sliced_3D)
//     }

//     // 16-bit float arithmetic in shaders plus 16-bit access in UBOs and SSBOs
//     // all three sub-features must be present for a coherent f16 programming model
//     if impl.caps.shader_float16_int8.features.shaderFloat16 &&
//        impl.caps.bit16_storage.features.storageBuffer16BitAccess &&
//        impl.caps.bit16_storage.features.uniformAndStorageBuffer16BitAccess {
//         append(&features, Feature_Name.Shader_F16)
//     }

//     // Subgroup (warp) operations: require the full set of operations used by
//     // shaders (vote, arithmetic, ballot, shuffle, quad) in both compute and
//     // fragment stages before advertising subgroup support
//     supported_operations := vk.SubgroupFeatureFlags {
//         .BASIC,
//         .VOTE,
//         .ARITHMETIC,
//         .BALLOT,
//         .SHUFFLE,
//         .SHUFFLE_RELATIVE,
//         .QUAD,
//     }

//     supported_subgroup_features :=
//         supported_operations & impl.caps.subgroup.properties.supportedOperations != {}

//     if supported_subgroup_features {
//         // Compute + fragment subgroup ops are the common case
//         subgroupStage := vk.ShaderStageFlags{.COMPUTE, .FRAGMENT}
//         if impl.caps.subgroup.properties.supportedStages & subgroupStage != {} {
//             append(&features, Feature_Name.Subgroup)
//         }
//         // Vertex stage subgroup ops are optional on some vendors
//         subgroupVertexStage := vk.ShaderStageFlags{.VERTEX}
//         if impl.caps.subgroup.properties.supportedStages & subgroupVertexStage != {} {
//             append(&features, Feature_Name.Subgroup_Vertex)
//         }
//         append(&features, Feature_Name.Subgroup_Barrier)
//     }

//     // D32S8 is the only combined depth-stencil format checked here D24S8
//     // and plain D32 are queried separately into caps below
//     texture_d32_s8 := supports_depth_format(pd, .D32_SFLOAT_S8_UINT)

//     if texture_d32_s8 {
//         append(&features, Feature_Name.Depth32Float_Stencil8)
//     }

//     // Ray query requires all three extensions: deferred host operations (needed
//     // by the AS build API), the AS extension itself, and buffer device address
//     // (AS handles are GPU pointers)
//     supports_deferred_host_operations_ext := vk_has_extension(
//         impl.caps.extensions,
//         vk.KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
//     )

//     supports_acceleration_structure_ext := vk_has_extension(
//         impl.caps.extensions,
//         vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
//     )

//     supports_buffer_device_address_ext := vk_has_extension(
//         impl.caps.extensions,
//         vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,
//     )

//     supports_acceleration_structure :=
//         supports_deferred_host_operations_ext &&
//         supports_acceleration_structure_ext &&
//         supports_buffer_device_address_ext

//     supports_ray_query := supports_acceleration_structure && can_query_ray_query

//     // Bindless AS arrays require update-after-bind on top of ray query support
//     supports_acceleration_structure_binding_array := false
//     if supports_ray_query {
//         if impl.caps.acceleration_structure.features.descriptorBindingAccelerationStructureUpdateAfterBind {
//             supports_acceleration_structure_binding_array = true
//         }
//     }

//     if supports_ray_query {
//         // RayQuery: inline traversal from any stage
//         // ExtendedAccelerationStructureVertexFormats: non-float16 vertex
//         // formats in BLAS geometry (e.g. float32, int16 snorm)
//         append(&features, Feature_Name.Ray_Query)
//         // append(&features, Feature_Name.Extended_Acceleration_Structure_Vertex_Formats)
//     }

//     if supports_acceleration_structure_binding_array {
//         append(&features, Feature_Name.Acceleration_Structure_Binding_Array)
//     }

//     // B10G11R11 as a render target with blending not guaranteed by Vulkan,
//     // but widely supported on desktop and commonly used for HDR scene color
//     rg11b10ufloat_renderable := supports_format(
//         pd,
//         .B10G11R11_UFLOAT_PACK32,
//         .OPTIMAL,
//         {.COLOR_ATTACHMENT, .COLOR_ATTACHMENT_BLEND},
//     )

//     if rg11b10ufloat_renderable {
//         append(&features, Feature_Name.RG11B10Ufloat_Renderable)
//     }

//     float32_filterable_supported :: proc(pd: vk.PhysicalDevice) -> bool {
//         FORMATS :: []vk.Format {
//             .R32_SFLOAT,
//             // .R32G32B32_SFLOAT, // commonly unsupported
//             .R32G32_SFLOAT,
//             .R32G32B32A32_SFLOAT,
//         }
//         for vk_format in FORMATS {
//             if (!supports_format(pd, vk_format, .OPTIMAL, {.SAMPLED_IMAGE_FILTER_LINEAR})) {
//                 return false
//             }
//         }
//         return true
//     }

//     float32_blendable_supported :: proc(pd: vk.PhysicalDevice) -> bool {
//         FORMATS :: []vk.Format {
//             .R32_SFLOAT,
//             // .R32G32B32_SFLOAT, // commonly unsupported
//             .R32G32_SFLOAT,
//             .R32G32B32A32_SFLOAT,
//         }
//         for vk_format in FORMATS {
//             if (!supports_format(pd, vk_format, .OPTIMAL, {.COLOR_ATTACHMENT_BLEND})) {
//                 return false
//             }
//         }
//         return true
//     }

//     // Linear filtering of float32 textures (e.g. shadow maps, HDR lookups)
//     // not guaranteed by Vulkan and absent on some mobile GPUs
//     if float32_filterable_supported(pd) {
//         append(&features, Feature_Name.Float32_Filterable)
//     }

//     // Blending into float32 render targets required for accumulation passes
//     // and order-independent transparency with float accumulators
//     if float32_blendable_supported(pd) {
//         append(&features, Feature_Name.Float32_Blendable)
//     }

//     // NV12: 8-bit 4:2:0 planar YCbCr format used for video decode output
//     // and camera preview textures
//     texture_format_nv12 := supports_format(
//         pd,
//         .G8_B8R8_2PLANE_420_UNORM,
//         .OPTIMAL,
//         {.SAMPLED_IMAGE, .TRANSFER_SRC, .TRANSFER_DST},
//     )
//     if texture_format_nv12 {
//         append(&features, Feature_Name.Texture_Format_Nv12)
//     }

//     // P010: 10-bit 4:2:0 planar YCbCr format for HDR video content (HDR10/HLG)
//     texture_format_p010 := supports_format(
//         pd,
//         .G10X6_B10X6R10X6_2PLANE_420_UNORM_3PACK16,
//         .OPTIMAL,
//         {.SAMPLED_IMAGE, .TRANSFER_SRC, .TRANSFER_DST},
//     )
//     if texture_format_p010 {
//         append(&features, Feature_Name.Texture_Format_P010)
//     }

//     // Present timing feedback from the display compositor (Android / ChromeOS),
//     // used to implement frame pacing without relying on vkQueuePresentKHR timing
//     if vk_has_extension(impl.caps.extensions, vk.GOOGLE_DISPLAY_TIMING_EXTENSION_NAME) {
//         // append(&features, Feature_Name.Vulkan_Google_Display_Timing)
//     }

//     // Win32 exportable/importable memory handles for interop with D3D12,
//     // DirectML, CUDA, and other Windows APIs sharing GPU memory
//     if vk_has_extension(impl.caps.extensions, vk.KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME) {
//         // append(&features, Feature_Name.Vulkan_External_Memory_Win32)
//     }

//     // POSIX file descriptor memory handles for GPU memory sharing between
//     // processes on Linux (required for DMA-BUF below)
//     supports_external_memory_fd := vk_has_extension(
//         impl.caps.extensions,
//         vk.KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
//     )

//     if supports_external_memory_fd {
//         // append(&features, Feature_Name.Vulkan_External_Memory_Fd)
//     }

//     // DMA-BUF: Linux kernel buffer sharing across drivers (V4L2, media,
//     // display) via file descriptors and DRM format modifiers requires all
//     // three extensions for correct tiling/layout negotiation
//     supports_external_memory_dma_buf := vk_has_extension(
//         impl.caps.extensions,
//         vk.EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME,
//     )
//     supports_image_drm_format_modifier := vk_has_extension(
//         impl.caps.extensions,
//         vk.EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
//     )

//     if supports_external_memory_fd &&
//        supports_external_memory_dma_buf &&
//        supports_image_drm_format_modifier {
//         // append(&features, Feature_Name.Vulkan_External_Memory_Dma_Buf)
//     }

//     // Mesh and task shader stages replacing the fixed vertex pipeline
//     // MESH_SHADER_POINTS allows mesh shaders to emit point topology
//     if vk_has_extension(impl.caps.extensions, vk.EXT_MESH_SHADER_EXTENSION_NAME) {
//         // append(&features, Feature_Name.Mesh_Shader)
//         // append(&features, Feature_Name.Mesh_Shader_Points)
//     }

//     // Multiview support inside mesh shader render passes (VR stereo with meshlets)
//     if impl.caps.mesh_shader.features.multiviewMeshShader {
//         // append(&features, Feature_Name.Mesh_Shader_Multiview)
//     }

//     // multisampleArrayImage is not guaranteed on portability subset (MoltenVK)
//     // on fully conformant Vulkan implementations it is always available
//     if impl.caps.portability_subset.features.multisampleArrayImage {
//         append(&features, Feature_Name.Multisample_Array)
//     } else {
//         append(&features, Feature_Name.Multisample_Array)
//     }

//     // gl_DrawID in vertex shaders for identifying the current draw inside a
//     // multi-draw indirect call promoted to core 1.1 but checked via extension
//     // for compatibility with drivers that report 1.0 + the extension
//     if vk_has_extension(impl.caps.extensions, vk.KHR_SHADER_DRAW_PARAMETERS_EXTENSION_NAME) {
//         append(&features, Feature_Name.Shader_Draw_Index)
//     }

//     slice.sort(features[:])
//     impl.features = features[:]

//     sync.guard(&gpu.vk.mtx)

//     adapter_impl := hm_dynamic_add_get(&gpu.vk.adapters, impl)
//     adapter = transmute(Adapter)adapter_impl.handle

//     init_ref(adapter_impl)
//     vk_instance_add_ref(Instance(instance))

//     return adapter, true
// }

// vk_adapter_get_features :: proc(
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := vk_adapter_get_impl(adapter, loc)
//     features.features = make([]Feature_Name, len(impl.features), allocator)
//     copy(features.features, impl.features)
//     return
// }

// vk_adapter_get_features_view :: proc(
//     adapter: Adapter,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := vk_adapter_get_impl(adapter, loc)
//     features.features = impl.features
//     return
// }

// vk_adapter_get_info :: proc(
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     info: Adapter_Info,
//     status: Status,
// ) {
//     impl := vk_adapter_get_impl(adapter, loc)

//     props := impl.caps.properties
//     driver := impl.caps.driver.properties

//     info.vendor = strings.clone(vendor_name(props.vendorID), allocator)
//     info.architecture = strings.clone(byte_arr_str(&driver.driverName), allocator)
//     info.device = strings.clone(byte_arr_str(&props.deviceName), allocator)
//     info.description = strings.clone(byte_arr_str(&driver.driverInfo), allocator)
//     info.backend_type = .Vulkan
//     info.vendor_id = props.vendorID
//     info.device_id = props.deviceID

//     #partial switch props.deviceType {
//     case .INTEGRATED_GPU:
//         info.adapter_type = .Integrated_GPU
//     case .DISCRETE_GPU:
//         info.adapter_type = .Discrete_GPU
//     case .CPU:
//         info.adapter_type = .Cpu
//     case:
//         info.adapter_type = .Unknown
//     }

//     info.subgroup_min_size = impl.caps.subgroup_size_control.properties.minSubgroupSize
//     info.subgroup_max_size = impl.caps.subgroup_size_control.properties.maxSubgroupSize

//     return info, .Success
// }

// vk_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
//     impl := vk_adapter_get_impl(adapter, loc)
//     return impl.limits
// }

// vk_adapter_has_feature :: proc(
//     adapter: Adapter,
//     feature: Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     if feature == {} { return true }
//     impl := vk_adapter_get_impl(adapter)
//     _, found := slice.binary_search(impl.features, feature)
//     return found
// }

// VK_Request_Device_Info :: struct {
//     adapter:       Adapter,
//     descriptor:    Device_Descriptor,
//     callback_info: Request_Device_Callback_Info,
// }

// vk_adapter_request_device :: proc(
//     adapter: Adapter,
//     descriptor: ^Device_Descriptor,
//     callback_info: Request_Device_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     // impl := vk_adapter_get_impl(adapter, loc)

//     callback :: proc(
//         callback_info: Request_Device_Callback_Info,
//         status: Request_Device_Status,
//         device: Device,
//         message: string,
//     ) {
//         callback_info.callback(
//             status,
//             device,
//             message,
//             callback_info.userdata1,
//             callback_info.userdata2,
//         )
//     }

//     desc := descriptor != nil ? descriptor^ : {}
//     device, device_ok := vk_create_device(adapter, desc, loc)
//     if !device_ok {
//         callback(callback_info, .Error, nil, "Failed to create logical device")
//         return {}
//     }

//     // Success
//     callback(callback_info, .Success, device, "")

//     return {}

//     // info := new(VK_Request_Device_Info, impl.allocator)
//     // info.adapter = adapter
//     // info.descriptor = descriptor != nil ? descriptor^ : {}
//     // info.callback_info = callback_info

//     // resolve_device :: proc(userdata: rawptr) {
//     //     reject_device :: proc(
//     //         callback_info: Request_Device_Callback_Info,
//     //         status: Request_Device_Status,
//     //         message: string,
//     //     ) {
//     //         callback_info.callback(
//     //             status,
//     //             {},
//     //             message,
//     //             callback_info.userdata1,
//     //             callback_info.userdata2,
//     //         )
//     //     }

//     //     info := cast(^VK_Request_Device_Info)userdata

//     //     device, device_ok := vk_create_device(info.adapter, info.descriptor)
//     //     if !device_ok {
//     //         reject_device(info.callback_info, .Error, "Failed to create logical device")
//     //         return
//     //     }

//     //     // Success
//     //     info.callback_info.callback(
//     //         .Success,
//     //         device,
//     //         "",
//     //         info.callback_info.userdata1,
//     //         info.callback_info.userdata2,
//     //     )
//     // }

//     // id := intr.atomic_add(&impl.instance.current_future_id, 1)
//     // impl.instance.pending_futures[id] = {
//     //     allocator = impl.allocator,
//     //     resolve   = resolve_device,
//     //     userdata  = info,
//     // }

//     // return {id}
// }

// vk_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
//     impl := vk_adapter_get_impl(adapter, loc)
//     add_ref(impl)
// }

// vk_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
//     impl := vk_adapter_get_impl(adapter, loc)
//     if release_ref(impl) {
//         context.allocator = impl.allocator
//         delete(impl.features)
//         delete(impl.caps.extensions)
//         delete(impl.caps.queue_families)
//         delete(impl.arena_buf)
//         vk_instance_release(Instance(impl.instance))
//         sync.guard(&gpu.vk.mtx)
//         hm.remove(&gpu.vk.adapters, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // VK_Adapter_Impl private procedures
// // -----------------------------------------------------------------------------

// vk_adapter_texture_format_capabilities :: proc(
//     adapter: Adapter,
//     format: Texture_Format,
//     loc := #caller_location,
// ) -> (caps: Texture_Format_Capabilities) {
//     impl := vk_adapter_get_impl(adapter, loc)

//     vk_format := vk_conv_to_format(impl.caps, format)

//     properties: vk.FormatProperties
//     vk.GetPhysicalDeviceFormatProperties(impl.physical_device, vk_format, &properties)

//     features := properties.optimalTilingFeatures

//     if .SAMPLED_IMAGE in features {
//         caps |= {.Sampled}
//     }
//     if .SAMPLED_IMAGE_FILTER_LINEAR in features {
//         caps |= {.Sampled_Linear}
//     }
//     if .SAMPLED_IMAGE_FILTER_MINMAX in features {
//         caps |= {.Sampled_Minmax}
//     }
//     if .STORAGE_IMAGE in features {
//         caps |= {.Storage_Read_Write, .Storage_Write_Only, .Storage_Read_Only, .Storage_Atomic}
//     }
//     if .STORAGE_IMAGE_ATOMIC in features {
//         caps |= {.Storage_Atomic}
//     }
//     if .COLOR_ATTACHMENT in features {
//         caps |= {.Color_Attachment}
//     }
//     if .COLOR_ATTACHMENT_BLEND in features {
//         caps |= {.Color_Attachment_Blend}
//     }
//     if .DEPTH_STENCIL_ATTACHMENT in features {
//         caps |= {.Depth_Stencil_Attachment}
//     }
//     if .TRANSFER_SRC in features {
//         caps |= {.Copy_Src}
//     }
//     if .TRANSFER_DST in features {
//         caps |= {.Copy_Dst}
//     }
//     if .STORAGE_IMAGE_ATOMIC in features {
//         caps |= {.Storage_Atomic}
//     }

//     // Vulkan is very permissive about MSAA
//     if !texture_format_is_compressed(format, loc) {
//         caps |= {.Multisample_Resolve}
//     }

//     // get the supported sample counts
//     format_aspect := texture_format_aspects_from(format)
//     limits := impl.caps.properties.limits

//     sample_flags: vk.SampleCountFlags

//     if .Depth in format_aspect {
//         sample_flags = limits.framebufferDepthSampleCounts &
//             limits.sampledImageDepthSampleCounts
//     } else if .Stencil in format_aspect {
//         sample_flags = limits.framebufferStencilSampleCounts &
//             limits.sampledImageStencilSampleCounts
//     } else {
//         // Color or planar (YUV) formats: take the first aspect bit, We've
//         // already excluded Depth/Stencil above, so this can only be Color,
//         // Plane0, Plane1, or Plane2.
//         first_aspect: Texture_Aspect
//         switch {
//         case .Color in format_aspect:  first_aspect = .All
//         case .Plane0 in format_aspect: first_aspect = .Plane0
//         case .Plane1 in format_aspect: first_aspect = .Plane1
//         case .Plane2 in format_aspect: first_aspect = .Plane2
//         case:
//             panic("Texture format has no recognized aspect", loc)
//         }

//         sample_type := texture_format_sample_type(format, first_aspect, {}, loc)

//         #partial switch sample_type {
//         case .Float:
//             sample_flags = limits.framebufferColorSampleCounts &
//                 limits.sampledImageColorSampleCounts
//         case .Sint, .Uint:
//             sample_flags = limits.sampledImageIntegerSampleCounts
//         case:
//             panic("Invalid texture sample type for multisample count query", loc)
//         }
//     }

//     if ._2 in sample_flags  { caps |= {.Multisample_X2} }
//     if ._4 in sample_flags  { caps |= {.Multisample_X4} }
//     if ._8 in sample_flags  { caps |= {.Multisample_X8} }
//     if ._16 in sample_flags { caps |= {.Multisample_X16} }

//     return
// }

// // -----------------------------------------------------------------------------
// // Procedures of AdapterInfo
// // -----------------------------------------------------------------------------

// vk_adapter_info_free_members :: proc(
//     adapter_info: Adapter_Info,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     if len(adapter_info.vendor) > 0 {delete(adapter_info.vendor, allocator)}
//     if len(adapter_info.architecture) > 0 {delete(adapter_info.architecture, allocator)}
//     if len(adapter_info.device) > 0 {delete(adapter_info.device, allocator)}
//     if len(adapter_info.description) > 0 {delete(adapter_info.description, allocator)}
// }

// // -----------------------------------------------------------------------------
// // Procedures of Bind_Group
// // -----------------------------------------------------------------------------

// VK_Bind_Group_Handle :: distinct hm.Handle64

// VK_Bind_Group_Impl :: struct {
//     device:             Device,
//     layout:             Bind_Group_Layout,
//     vk_descriptor_pool: vk.DescriptorPool,
//     vk_descriptor_set:  vk.DescriptorSet,
//     buffers:            []VK_Buffer_Access,
//     samplers:           []Sampler,
//     texture_views:      []VK_Texture_View_Access,
//     handle:             VK_Bind_Group_Handle,
//     ref:                Ref_Count_Type,
// }

// vk_bind_group_set_label :: proc(Bind_Group: Bind_Group, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_bind_group_add_ref :: proc(Bind_Group: Bind_Group, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_bind_group_release :: proc(Bind_Group: Bind_Group, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Bind_Group_Layout
// // -----------------------------------------------------------------------------

// VK_Bind_Group_Layout_Handle :: distinct hm.Handle64

// VK_Binding_Info :: struct {
//     key:                u32,
//     binding:            u32,
//     binding_array_size: u32,
// }

// VK_Bind_Group_Layout_Impl :: struct {
//     device:                  Device,
//     descriptor_set_layout:   vk.DescriptorSetLayout,
//     desc_count:              VK_Descriptor_Total_Count,
//     entries:                 []Bind_Group_Layout_Entry,
//     binding_map:             []VK_Binding_Info,
//     handle:                  VK_Bind_Group_Layout_Handle,
//     ref:                     Ref_Count_Type,
//     contains_binding_arrays: bool,
// }

// vk_bind_group_layout_get_impl :: #force_inline proc "contextless" (
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) -> ^VK_Bind_Group_Layout_Impl {
//     assert_contextless(bind_group_layout != {}, "Invalid Bind_Group_Layout_Impl", loc)
//     h := id_to_handle(bind_group_layout)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := VK_Bind_Group_Layout_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.bind_group_layouts, map_handle)
// }

// vk_bind_group_layout_set_label :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_bind_group_layout_add_ref :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_bind_group_layout_release :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Buffer
// // -----------------------------------------------------------------------------

// VK_Buffer_Handle :: distinct hm.Handle64

// VK_Buffer_Impl :: struct {
//     vma_allocation_info: vma.AllocationInfo,
//     map_state:           Buffer_Map_State_Impl,
//     vma_allocation:      vma.Allocation,
//     device:              Device,
//     vk_buffer:           vk.Buffer,
//     size:                u64,
//     vk_size:             vk.DeviceSize,
//     vk_memory:           vk.DeviceMemory, // for no VMA
//     mapped_ptr:          rawptr,
//     handle:              VK_Buffer_Handle,
//     vk_buffer_flags:     vk.BufferUsageFlags,
//     vk_mem_flags:        vk.MemoryPropertyFlags,
//     usage:               Buffer_Usages,
//     internal_uses:       Buffer_Uses,
//     ref:                 Ref_Count_Type,
//     is_coherent_memory:  bool,
// }

// vk_buffer_get_impl :: #force_inline proc "contextless" (
//     buffer: Buffer,
//     loc := #caller_location,
// ) -> ^VK_Buffer_Impl {
//     assert_contextless(buffer != {}, "Invalid buffer", loc)
//     h := id_to_handle(buffer)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := VK_Buffer_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.buffers, map_handle)
// }

// vk_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_buffer_get_mapped_range_size :: proc(
//     impl: ^VK_Buffer_Impl,
//     offset: uint = 0,
//     size: uint = WHOLE_MAP_SIZE,
//     loc := #caller_location,
// ) -> u64 {
//     assert(size != 0, "mapped range size must not be zero", loc)

//     range_size: u64
//     if size == WHOLE_MAP_SIZE {
//         range_size = intr.saturating_sub(impl.size, u64(offset))
//     } else {
//         range_size = u64(size)
//     }

//     assert(is_multiple_of(offset, MAP_ALIGNMENT), "unaligned offset", loc)
//     assert(is_multiple_of(range_size, COPY_BUFFER_ALIGNMENT), "unaligned range size", loc)

//     return range_size
// }

// vk_buffer_get_mapped_range_active :: proc(
//     impl: ^VK_Buffer_Impl,
//     offset: uint = 0,
//     range_size: u64,
//     loc := #caller_location,
// ) -> rawptr {
//     #partial switch &state in impl.map_state {
//     case Buffer_Map_State_Active:
//         assert(offset <= uint(state.range.end), "out of bounds start offset overrun", loc)
//         assert(offset >= uint(state.range.start), "out of bounds start offset underrun", loc)
//         assert(
//             uint(range_size) <= uint(state.range.end) - offset,
//             "out of bounds end offset overrun",
//             loc,
//         )
//         relative_offset := offset - uint(state.range.start)
//         return rawptr(uintptr(state.ptr) + uintptr(relative_offset))
//     case:
//         unreachable()
//     }
// }

// vk_buffer_get_const_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint = 0,
//     size: uint = WHOLE_MAP_SIZE,
//     loc := #caller_location,
// ) -> rawptr {
//     impl := vk_buffer_get_impl(buffer, loc)

//     range_size := buffer_get_mapped_range_size(impl.size, size, offset, loc)

//     switch &state in impl.map_state {
//     case Buffer_Map_State_Init:
//         panic("const mapped range requested on a write-staged buffer", loc)

//     case Buffer_Map_State_Active:
//         return vk_buffer_get_mapped_range_active(impl, offset, range_size, loc)

//     case Buffer_Pending_Mapping:
//         panic("buffer is waiting on GPU sync before it can be mapped", loc)

//     case Buffer_Map_State_Idle:
//         panic("buffer is not mapped", loc)
//     }

//     unreachable()
// }

// vk_buffer_get_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint = 0,
//     size: uint = WHOLE_MAP_SIZE,
//     loc := #caller_location,
// ) -> rawptr {
//     impl := vk_buffer_get_impl(buffer, loc)

//     range_size := vk_buffer_get_mapped_range_size(impl, offset, size, loc)

//     switch &state in impl.map_state {
//     case Buffer_Map_State_Init:
//         staging_impl := vk_buffer_get_impl(state.staging_buffer.buffer, loc)
//         assert(offset <= uint(staging_impl.size), "map start offset overrun", loc)
//         assert(u64(offset) + range_size <= staging_impl.size, "map end offset overrun", loc)
//         return rawptr(uintptr(state.staging_buffer.ptr) + uintptr(offset))

//     case Buffer_Map_State_Active:
//         return vk_buffer_get_mapped_range_active(impl, offset, range_size, loc)

//     case Buffer_Pending_Mapping:
//         panic("buffer is waiting on GPU sync before it can be mapped", loc)

//     case Buffer_Map_State_Idle:
//         panic("buffer is not mapped", loc)
//     }

//     unreachable()
// }

// vk_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
//     unimplemented(loc = loc)
// }

// vk_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
//     unimplemented(loc = loc)
// }

// vk_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
//     unimplemented(loc = loc)
// }

// vk_buffer_map_async :: proc(
//     buffer: Buffer,
//     mode: Map_Modes,
//     offset: uint,
//     size: uint,
//     callback_info: Buffer_Map_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_buffer_map_sync :: proc(
//     buffer: Buffer,
//     mode: Map_Modes,
//     offset: uint,
//     size: uint,
//     loc := #caller_location,
// ) -> rawptr {
//     impl := vk_buffer_get_impl(buffer, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     mapping := impl.map_state
//     impl.map_state = Buffer_Map_State_Idle{}

//     pending: Buffer_Pending_Mapping
//     #partial switch &state in mapping {
//     case Buffer_Pending_Mapping:
//         pending = state
//     case Buffer_Map_State_Idle:
//         return nil // Mapping cancelled
//     case Buffer_Map_State_Active:
//         impl.map_state = mapping
//         return nil // already mapped, no-op
//     case:
//         panic("No pending mapping.", loc)
//     }

//     when USE_VMA {
//         vk_check(vma.MapMemory(device_impl.vma_allocator, impl.vma_allocation, &impl.mapped_ptr))
//     } else {
//         vk_check(
//             device_impl.fp.MapMemory(
//                 device_impl.device,
//                 impl.vk_memory,
//                 vk.DeviceSize(offset),
//                 vk.DeviceSize(size),
//                 {},
//                 &impl.mapped_ptr,
//             ),
//         )
//     }

//     impl.map_state = Buffer_Map_State_Active {
//         mapping = {ptr = impl.mapped_ptr, is_coherent = impl.is_coherent_memory},
//         range = pending.range,
//         mode = pending.op.mode,
//     }

//     return impl.mapped_ptr
// }

// vk_buffer_read_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) -> Status {
//     unimplemented(loc = loc)
// }

// vk_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := vk_buffer_get_impl(buffer, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     mapping := impl.map_state
//     impl.map_state = Buffer_Map_State_Idle{}
//     impl.mapped_ptr = nil

//     switch state in mapping {
//     case Buffer_Map_State_Init:
//         staging_impl := vk_buffer_get_impl(state.staging_buffer.buffer, loc)
//         staging_impl.mapped_ptr = nil

//         encoder := vk_transfer_batch_activate(&device_impl.transfer_batch, impl.device, loc)
//         encoder_impl := vk_command_encoder_get_impl(encoder, loc)
//         cmdbuf_impl := &device_impl.submitter.buffers[encoder_impl.buffer_index]

//         t0 := command_allocator_allocate(&cmdbuf_impl.commands, Transition_Buffer_Cmd, loc)
//         t0.buffer = state.staging_buffer.buffer
//         t0.state_from = {.Map_Write}
//         t0.state_to = {.Copy_Src}

//         t1 := command_allocator_allocate(&cmdbuf_impl.commands, Transition_Buffer_Cmd, loc)
//         t1.buffer = buffer
//         t1.state_from = {}
//         t1.state_to = {.Copy_Dst}

//         if impl.size > 0 {
//             copy := command_allocator_allocate(
//                 &cmdbuf_impl.commands,
//                 Copy_Buffer_To_Buffer_Cmd,
//                 loc,
//             )
//             copy.src = state.staging_buffer.buffer
//             copy.src_offset = 0
//             copy.dst = buffer
//             copy.dst_offset = 0
//             copy.size = impl.size
//         }

//         vk_transfer_batch_consume(&device_impl.transfer_batch, state.staging_buffer)
//         vk_transfer_batch_insert_buffer(&device_impl.transfer_batch, buffer)

//     case Buffer_Map_State_Idle:
//         panic("buffer not mapped", loc)

//     case Buffer_Pending_Mapping:
//         // Mapping was requested but never resolved
//         return

//     case Buffer_Map_State_Active:
//         when USE_VMA {
//             if !impl.is_coherent_memory {
//                 vk_check(
//                     vma.FlushAllocation(
//                         device_impl.vma_allocator,
//                         impl.vma_allocation,
//                         0,
//                         vk.DeviceSize(vk.WHOLE_SIZE),
//                     ),
//                 )
//             }

//             vma.UnmapMemory(device_impl.vma_allocator, impl.vma_allocation)
//         } else {
//             if !impl.is_coherent_memory {
//                 range := vk.MappedMemoryRange {
//                     sType  = .MAPPED_MEMORY_RANGE,
//                     memory = impl.vk_memory,
//                     offset = 0,
//                     size   = vk.DeviceSize(vk.WHOLE_SIZE),
//                 }
//                 vk_check(device_impl.fp.FlushMappedMemoryRanges(device_impl.device, 1, &range))
//             }
//             device_impl.fp.UnmapMemory(device_impl.device, impl.vk_memory)
//         }
//     }
// }

// vk_buffer_write_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) -> Status {
//     unimplemented(loc = loc)
// }

// vk_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := vk_buffer_get_impl(buffer, loc)
//     add_ref(impl, loc)
// }

// vk_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := vk_buffer_get_impl(buffer, loc)
//     if release_ref(impl, loc) {
//         device_impl := vk_device_get_impl(impl.device, loc)

//         if impl.mapped_ptr != nil {
//             vk_buffer_unmap(buffer, loc)
//         }

//         vk_device_add_deferred_resource(impl.device, VK_Deferred_Buffer {
//             buffer         = impl.vk_buffer,
//             vma_allocation = impl.vma_allocation,
//             vk_memory      = impl.vk_memory,
//         })

//         hm.remove(&device_impl.buffers, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Command_Buffer
// // -----------------------------------------------------------------------------

// Command_Buffer_Handle :: distinct hm.Handle64

// VK_Command_Buffer_Impl :: struct {
//     commands:          Command_Allocator,
//     encoder:           Command_Encoder,
//     device:            vk.Device,
//     cmdbuf:            vk.CommandBuffer,
//     cmdbuf_allocated:  vk.CommandBuffer,
//     semaphore:         vk.Semaphore,
//     buffer_index:      u32,
//     reserved_value:    u64,
//     last_signal_value: u64,
//     is_encoding:       bool,
// }

// VK_Command_Buffer_Wrapper :: struct {
//     device:       Device,
//     encoder:      Command_Encoder,
//     handle:       Command_Buffer_Handle,
//     ref:          Ref_Count_Type,
//     buffer_index: u32,
// }

// vk_command_buffer_get_impl :: #force_inline proc "contextless" (
//     command_buffer: Command_Buffer,
//     loc := #caller_location,
// ) -> ^VK_Command_Buffer_Wrapper {
//     assert_contextless(command_buffer != {}, "Invalid Command_Buffer", loc)
//     h := id_to_handle(command_buffer)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     command_buffer_impl := hm.get(
//         &device_impl.command_buffers,
//         Command_Buffer_Handle{h.fields.idx, h.fields.gen},
//     )
//     return command_buffer_impl
// }

// vk_command_buffer_set_label :: proc(
//     command_buffer: Command_Buffer,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
//     impl := vk_command_buffer_get_impl(command_buffer, loc)
//     add_ref(impl, loc)
// }

// vk_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
//     impl := vk_command_buffer_get_impl(command_buffer, loc)
//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         vk_command_encoder_release(impl.encoder, loc)
//         hm.remove(&device_impl.command_buffers, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of VK_Command_Encoder_Impl
// // -----------------------------------------------------------------------------

// VK_Command_Encoder_Handle :: distinct hm.Handle64

// VK_Command_Encoder_Impl :: struct {
//     // Device sued to create this encoder.
//     device:       Device,
//     // The internal handle to the command encoders pool.
//     handle:       VK_Command_Encoder_Handle,
//     // Index to the cached vk.CommandBuffer
//     buffer_index: u32,
//     // Internal reference counter.
//     ref:          Ref_Count_Type,
//     // What kind of pass we are currently within: compute or render.
//     bind_point:   vk.PipelineBindPoint,
//     is_encoding:  bool,
//     is_rendering: bool,
//     is_computing: bool,
// }

// vk_command_encoder_get_impl :: #force_inline proc "contextless" (
//     command_encoder: Command_Encoder,
//     loc := #caller_location,
// ) -> ^VK_Command_Encoder_Impl {
//     assert_contextless(command_encoder != {}, "Invalid Command_Encoder", loc)
//     h := id_to_handle(command_encoder)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     command_encoder_handle := VK_Command_Encoder_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.command_encoders, command_encoder_handle)
// }

// vk_command_encoder_begin_compute_pass :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Compute_Pass_Descriptor,
//     loc := #caller_location,
// ) -> Compute_Pass_Encoder {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_begin_render_pass :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Render_Pass_Descriptor,
//     loc := #caller_location,
// ) -> Render_Pass_Encoder {
//     assert(descriptor != nil, "Invalid descriptor", loc)

//     impl := vk_command_encoder_get_impl(command_encoder, loc)

//     // Basic state validation
//     assert(impl.is_encoding, "Command encoder is finished", loc)
//     assert(impl.is_computing == false, "Command encoder is in compute state", loc)
//     assert(impl.is_rendering == false, "Command encoder is already rendering", loc)

//     impl.bind_point = .GRAPHICS
//     impl.is_rendering = true

//     device_impl := vk_device_get_impl(impl.device, loc)
//     cmdbuf_impl := &device_impl.submitter.buffers[impl.buffer_index]

//     cmd := command_allocator_allocate(&cmdbuf_impl.commands, Begin_Render_Pass_Cmd, loc)

//     // Copy color attachments
//     for &color in descriptor.color_attachments {
//         append(&cmd.color_attachments, color)
//     }

//     // set depth stencil
//     if descriptor.depth_stencil_attachment != nil {
//         cmd.depth_stencil_attachment = descriptor.depth_stencil_attachment^
//     }

//     rpass_impl := hm_dynamic_add_get(&device_impl.render_pass_encoders,
//         VK_Render_Pass_Encoder_Impl {
//             device       = impl.device,
//             encoder      = command_encoder,
//             buffer_index = impl.buffer_index,
//             is_rendering = true,
//         })

//     rpass_handle := handle_make(rpass_impl.handle, device_impl.handle)
//     rpass := handle_to_raw(Render_Pass_Encoder, rpass_handle)

//     init_ref(rpass_impl, loc)
//     vk_command_encoder_add_ref(command_encoder, loc)

//     return rpass
// }

// vk_command_encoder_clear_buffer :: proc(
//     command_encoder: Command_Encoder,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_copy_buffer_to_buffer :: proc(
//     command_encoder: Command_Encoder,
//     source: Buffer,
//     source_offset: u64,
//     destination: Buffer,
//     destination_offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_copy_buffer_to_texture :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Buffer_Info,
//     destination: ^Texel_Copy_Texture_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_copy_texture_to_buffer :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Texture_Info,
//     destination: ^Texel_Copy_Buffer_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_copy_texture_to_texture :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Texture_Info,
//     destination: ^Texel_Copy_Texture_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_finish :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Command_Buffer_Descriptor,
//     loc := #caller_location,
// ) -> Command_Buffer {
//     impl := vk_command_encoder_get_impl(command_encoder, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     assert(impl.is_encoding, "Finishing encoder while not encoding", loc)
//     assert(impl.is_computing == false, "Finishing encoder in compute state", loc)
//     assert(impl.is_rendering == false, "Finishing encoder in render state", loc)

//     impl.is_encoding = false

//     command_buffer_impl := hm_dynamic_add_get(&device_impl.command_buffers,
//         VK_Command_Buffer_Wrapper {
//             device       = impl.device,
//             encoder      = command_encoder,
//             buffer_index = impl.buffer_index,
//         })

//     cmdbuf_handle := handle_make(command_buffer_impl.handle, device_impl.handle)
//     command_buffer := handle_to_raw(Command_Buffer, cmdbuf_handle)

//     init_ref(command_buffer_impl, loc)
//     vk_command_encoder_add_ref(command_encoder, loc)

//     return command_buffer
// }

// vk_command_encoder_insert_debug_marker :: proc(
//     command_encoder: Command_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_pop_debug_group :: proc(
//     command_encoder: Command_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_push_debug_group :: proc(
//     command_encoder: Command_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_resolve_query_set :: proc(
//     command_encoder: Command_Encoder,
//     query_set: Query_Set,
//     first_query: u32,
//     query_count: u32,
//     destination: Buffer,
//     destination_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_set_label :: proc(
//     command_encoder: Command_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_write_timestamp :: proc(
//     command_encoder: Command_Encoder,
//     query_set: Query_Set,
//     query_index: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
//     impl := vk_command_encoder_get_impl(command_encoder, loc)
//     add_ref(impl, loc)
// }

// vk_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
//     impl := vk_command_encoder_get_impl(command_encoder, loc)

//     assert(!impl.is_encoding, "Releasing encoder while encoding", loc)
//     assert(!impl.is_computing, "Releasing encoder while in compute state", loc)
//     assert(!impl.is_rendering, "Releasing encoder while in render state", loc)

//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.command_encoders, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Compute_Pass_Encoder
// // -----------------------------------------------------------------------------

// Compute_Pass_Encoder_Handle :: distinct hm.Handle64

// VK_Compute_Pass_Encoder_Impl :: struct {
//     handle: Compute_Pass_Encoder_Handle,
// }

// vk_compute_pass_encoder_dispatch_workgroups :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     workgroup_count_x: u32,
//     workgroup_count_y: u32,
//     workgroup_count_z: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_dispatch_workgroups_indirect :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_end :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_insert_debug_marker :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_pop_debug_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_push_debug_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_set_bind_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_set_immediates :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_set_label :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_set_pipeline :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     pipeline: Compute_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_add_ref :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pass_encoder_release :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Compute_Pipeline
// // -----------------------------------------------------------------------------

// Compute_Pipeline_Handle :: distinct hm.Handle64

// VK_Compute_Pipeline_Impl :: struct {
//     handle: Compute_Pipeline_Handle,
// }

// vk_compute_pipeline_get_bind_group_layout :: proc(
//     compute_pipeline: Compute_Pipeline,
//     group_index: u32,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     unimplemented(loc = loc)
// }

// vk_compute_pipeline_set_label :: proc(
//     compute_pipeline: Compute_Pipeline,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_compute_pipeline_add_ref :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_compute_pipeline_release :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of VK_Device_Impl
// // -----------------------------------------------------------------------------

// VK_Device_Impl :: struct {
//     // Object pools
//     bind_groups:                 DHM(VK_Bind_Group_Impl, VK_Bind_Group_Handle),
//     bind_group_layouts:          DHM(VK_Bind_Group_Layout_Impl, VK_Bind_Group_Layout_Handle),
//     buffers:                     DHM(VK_Buffer_Impl, VK_Buffer_Handle),
//     command_buffers:             DHM(VK_Command_Buffer_Wrapper, Command_Buffer_Handle),
//     command_encoders:            DHM(VK_Command_Encoder_Impl, VK_Command_Encoder_Handle),
//     compute_pass_encoders:       DHM(VK_Compute_Pass_Encoder_Impl, Compute_Pass_Encoder_Handle),
//     compute_pipelines:           DHM(VK_Compute_Pipeline_Impl, Compute_Pipeline_Handle),
//     external_textures:           DHM(VK_External_Texture_Impl, External_Texture_Handle),
//     pipeline_layouts:            DHM(VK_Pipeline_Layout_Impl, VK_Pipeline_Layout_Handle),
//     query_sets:                  DHM(VK_Query_Set_Impl, Query_Set_Handle),
//     queues:                      DHM(VK_Queue_Impl, VK_Queue_Handle),
//     render_bundles:              DHM(VK_Render_Bundle_Impl, Render_Bundle_Handle),
//     render_bundle_encoders:      DHM(VK_Render_Bundle_Encoder_Impl, Render_Bundle_Encoder_Handle),
//     render_pass_encoders:        DHM(VK_Render_Pass_Encoder_Impl, VK_Render_Pass_Encoder_Handle),
//     render_pipelines:            DHM(VK_Render_Pipeline_Impl, VK_Render_Pipeline_Handle),
//     samplers:                    DHM(VK_Sampler_Impl, VK_Sampler_Handle),
//     shader_modules:              DHM(VK_Shader_Module_Impl, VK_Shader_Module_Handle),
//     textures:                    DHM(VK_Texture_Impl, VK_Texture_Handle),
//     texture_views:               DHM(VK_Texture_View_Impl, VK_Texture_View_Handle),

//     // Queue submission subsystem
//     submitter:                   VK_Submit_Context, // graphics
//     // transfer_submitter:          VK_Submit_Context, // dedicated transfer if any
//     // has_transfer_queue:          bool,

//     // Function pointer table
//     fp:                          vk.Device_VTable,

//     // Descriptor set allocator subsystem
//     descriptor_allocator:        VK_Descriptor_Allocator,
//     transfer_batch:              VK_Transfer_Batch,

//     // Deferred deletion
//     deferred_deletion:           [dynamic]VK_Deferred_Deletion,
//     deferred_mtx:                sync.Mutex,

//     // Initialization
//     error_callback:              Uncaptured_Error_Callback_Info,
//     instance:                    ^VK_Instance_Impl,
//     adapter:                     Adapter,
//     queue:                       VK_Queue_Default_Impl,
//     device:                      vk.Device,
//     handle:                      Device_Handle,
//     vma_allocator:               vma.Allocator,
//     allocator:                   runtime.Allocator,

//     // Default layouts
//     empty_descriptor_set_layout: vk.DescriptorSetLayout,
//     empty_pipeline_layout:       vk.PipelineLayout,

//     // Capabilities
//     features:                    []Feature_Name,
//     limits:                      Limits,

//     // Internal
//     ref:                         Ref_Count_Type,
// }

// vk_create_device :: proc(
//     adapter: Adapter,
//     descriptor: Device_Descriptor,
//     loc := #caller_location,
// ) -> (
//     device: Device,
//     ok: bool,
// ) {
//     adapter_impl := vk_adapter_get_impl(adapter, loc)

//     // Alias to the temporary allocator
//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || adapter_impl.allocator == ta)

//     impl: VK_Device_Impl

//     impl.allocator = adapter_impl.allocator
//     impl.adapter = adapter

//     if descriptor.required_limits != nil {
//         impl.limits = descriptor.required_limits^
//     }

//     if len(descriptor.required_features) > 0 {
//         impl.features = make([]Feature_Name, len(descriptor.required_features), impl.allocator)
//         copy(impl.features, descriptor.required_features)
//     }

//     Queue_Setup :: struct {
//         index:    u32,
//         priority: f32,
//     }

//     // Queue setup
//     default_queue_priority: f32 = 1.0
//     queue_setup := [3]Queue_Setup {
//         {adapter_impl.graphics_family_index, default_queue_priority},
//         {adapter_impl.compute_family_index, default_queue_priority},
//         {adapter_impl.transfer_family_index, default_queue_priority},
//     }

//     queue_create_infos: sa.Small_Array(3, vk.DeviceQueueCreateInfo)

//     LOOP: for i in 0 ..< len(queue_setup) {
//         q := &queue_setup[i]
//         if q.index == vk.QUEUE_FAMILY_IGNORED {
//             continue
//         }

//         // Skip if an earlier entry already claimed this family index.
//         for j in 0 ..< i {
//             if queue_setup[j].index == q.index {
//                 continue LOOP
//             }
//         }

//         queue_create_info: vk.DeviceQueueCreateInfo = {
//             sType            = .DEVICE_QUEUE_CREATE_INFO,
//             queueFamilyIndex = q.index,
//             queueCount       = 1,
//             pQueuePriorities = &q.priority,
//         }

//         sa.push(&queue_create_infos, queue_create_info)
//     }

//     // Required features
//     pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

//     features2 := vk.PhysicalDeviceFeatures2 {
//         sType = .PHYSICAL_DEVICE_FEATURES_2,
//         // Vulkan 1.0 features
//         features = {
//             samplerAnisotropy = true,
//             // TODO
//         },
//     }
//     append(&pnext_chain, cast(^vk.BaseOutStructure)&features2)

//     extensions_to_enable := make([dynamic]cstring, ta)

//     // VK_KHR_synchronization2: unified barrier/submit API, required core-1.3
//     // functionality exposed as a standalone extension on devices below 1.3
//     synchronization2_features := vk.PhysicalDeviceSynchronization2Features {
//         sType            = .PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES,
//         synchronization2 = true,
//     }
//     append(&extensions_to_enable, vk.KHR_SYNCHRONIZATION_2_EXTENSION_NAME)
//     append(&pnext_chain, cast(^vk.BaseOutStructure)&synchronization2_features)

//     // VK_KHR_dynamic_rendering: render without VkRenderPass/VkFramebuffer
//     dynamic_rendering_features := vk.PhysicalDeviceDynamicRenderingFeatures {
//         sType            = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
//         dynamicRendering = true,
//     }
//     append(&extensions_to_enable, vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME)
//     append(&pnext_chain, cast(^vk.BaseOutStructure)&dynamic_rendering_features)

//     // VK_KHR_timeline_semaphore: monotonic counter semaphores for VK_Submit_Context
//     timeline_semaphore_features := vk.PhysicalDeviceTimelineSemaphoreFeatures {
//         sType             = .PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES,
//         timelineSemaphore = true,
//     }
//     append(&extensions_to_enable, vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME)
//     append(&pnext_chain, cast(^vk.BaseOutStructure)&timeline_semaphore_features)

//     // Extension `VK_KHR_swapchain` is required to present surface
//     if !adapter_impl.instance.headless {
//         append(&extensions_to_enable, vk.KHR_SWAPCHAIN_EXTENSION_NAME)
//     }

//     // VK_KHR_swapchain_maintenance1
//     swapchain_maintenance1: vk.PhysicalDeviceSwapchainMaintenance1FeaturesEXT
//     if adapter_impl.caps.swapchain_maintenance1.swapchainMaintenance1 {
//         swapchain_maintenance1 = {
//             sType                 = .PHYSICAL_DEVICE_SWAPCHAIN_MAINTENANCE_1_FEATURES_EXT,
//             swapchainMaintenance1 = true,
//         }

//         if vk_has_extension(
//             adapter_impl.caps.extensions,
//             VK_KHR_SURFACE_MAINTENANCE_1_EXTENSION_NAME,
//         ) {
//             append(&extensions_to_enable, VK_KHR_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME)
//         } else {
//             append(&extensions_to_enable, vk.EXT_SWAPCHAIN_MAINTENANCE_1_EXTENSION_NAME)
//         }

//         append(&pnext_chain, cast(^vk.BaseOutStructure)&swapchain_maintenance1)
//     }

//     // VK_EXT_device_fault
//     device_fault: vk.PhysicalDeviceFaultFeaturesEXT
//     if adapter_impl.caps.device_fault.deviceFault {
//         device_fault = {
//             sType       = .PHYSICAL_DEVICE_FAULT_FEATURES_EXT,
//             deviceFault = true,
//         }
//         append(&extensions_to_enable, vk.EXT_DEVICE_FAULT_EXTENSION_NAME)
//         append(&pnext_chain, cast(^vk.BaseOutStructure)&device_fault)
//     }

//     // VK_KHR_maintenance4
//     maintenance4_features: vk.PhysicalDeviceMaintenance4Features
//     if adapter_impl.caps.maintenance4.features.maintenance4 {
//         maintenance4_features = {
//             sType        = .PHYSICAL_DEVICE_MAINTENANCE_4_FEATURES,
//             maintenance4 = true,
//         }
//         append(&extensions_to_enable, vk.KHR_MAINTENANCE_4_EXTENSION_NAME)
//         append(&pnext_chain, cast(^vk.BaseOutStructure)&maintenance4_features)
//     }

//     // VK_KHR_maintenance5
//     maintenance5: vk.PhysicalDeviceMaintenance5FeaturesKHR
//     if adapter_impl.caps.maintenance5.features.maintenance5 {
//         maintenance5 = {
//             sType        = .PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR,
//             maintenance5 = true,
//         }
//         append(&extensions_to_enable, vk.KHR_MAINTENANCE_5_EXTENSION_NAME)
//         append(&pnext_chain, cast(^vk.BaseOutStructure)&maintenance5)
//     }

//     // VK_EXT_hdr_metadata
//     if adapter_impl.caps.hdr_metadata {
//         append(&extensions_to_enable, vk.EXT_HDR_METADATA_EXTENSION_NAME)
//     }

//     device_create_info := vk.DeviceCreateInfo {
//         sType                   = .DEVICE_CREATE_INFO,
//         queueCreateInfoCount    = u32(sa.len(queue_create_infos)),
//         pQueueCreateInfos       = raw_data(sa.slice(&queue_create_infos)),
//         enabledExtensionCount   = u32(len(extensions_to_enable)),
//         ppEnabledExtensionNames = raw_data(extensions_to_enable),
//     }

//     vk_setup_pnext_chain(&device_create_info, pnext_chain[:])

//     res := vk.CreateDevice(adapter_impl.physical_device, &device_create_info, nil, &impl.device)
//     if res != .SUCCESS {
//         return
//     }

//     // Bind Vulkan functions
//     vk.load_proc_addresses_device_vtable(impl.device, &impl.fp)

//     // Patch core-1.3-promoted entry points that may not resolve under their
//     // unsuffixed name on devices reporting apiVersion < 1.3 but exposing the
//     // functionality via standalone KHR extensions (e.g. Mesa Dozen on WSL2)
//     fallback_load :: #force_inline proc "contextless" (
//         device: vk.Device,
//         core_name, khr_name: cstring,
//     ) -> rawptr {
//         p := vk.GetDeviceProcAddr(device, core_name)
//         if p == nil {
//             p = vk.GetDeviceProcAddr(device, khr_name)
//         }
//         return rawptr(p)
//     }

//     if impl.fp.CmdBeginRendering == nil {
//         impl.fp.CmdBeginRendering = auto_cast fallback_load(
//             impl.device, "vkCmdBeginRendering", "vkCmdBeginRenderingKHR")
//     }
//     if impl.fp.CmdEndRendering == nil {
//         impl.fp.CmdEndRendering = auto_cast fallback_load(
//             impl.device, "vkCmdEndRendering", "vkCmdEndRenderingKHR")
//     }
//     if impl.fp.CmdPipelineBarrier2 == nil {
//         impl.fp.CmdPipelineBarrier2 = auto_cast fallback_load(
//             impl.device, "vkCmdPipelineBarrier2", "vkCmdPipelineBarrier2KHR")
//     }
//     if impl.fp.CmdSetEvent2 == nil {
//         impl.fp.CmdSetEvent2 = auto_cast fallback_load(
//             impl.device, "vkCmdSetEvent2", "vkCmdSetEvent2KHR")
//     }
//     if impl.fp.CmdResetEvent2 == nil {
//         impl.fp.CmdResetEvent2 = auto_cast fallback_load(
//             impl.device, "vkCmdResetEvent2", "vkCmdResetEvent2KHR")
//     }
//     if impl.fp.CmdWaitEvents2 == nil {
//         impl.fp.CmdWaitEvents2 = auto_cast fallback_load(
//             impl.device, "vkCmdWaitEvents2", "vkCmdWaitEvents2KHR")
//     }
//     if impl.fp.CmdWriteTimestamp2 == nil {
//         impl.fp.CmdWriteTimestamp2 = auto_cast fallback_load(
//             impl.device, "vkCmdWriteTimestamp2", "vkCmdWriteTimestamp2KHR")
//     }
//     if impl.fp.QueueSubmit2 == nil {
//         impl.fp.QueueSubmit2 = auto_cast fallback_load(
//             impl.device, "vkQueueSubmit2", "vkQueueSubmit2KHR")
//     }
//     if impl.fp.CmdCopyBuffer2 == nil {
//         impl.fp.CmdCopyBuffer2 = auto_cast fallback_load(
//             impl.device, "vkCmdCopyBuffer2", "vkCmdCopyBuffer2KHR")
//     }
//     if impl.fp.CmdBindVertexBuffers2 == nil {
//         impl.fp.CmdBindVertexBuffers2 = auto_cast fallback_load(
//             impl.device, "vkCmdBindVertexBuffers2", "vkCmdBindVertexBuffers2KHR")
//     }

//     when USE_VMA {
//         // Initializes a subset of Vulkan functions required by VMA
//         vma_vulkan_functions := vma.create_device_vulkan_functions(impl.fp)

//         api_version := min(
//             adapter_impl.instance.instance_version,
//             adapter_impl.caps.properties.apiVersion,
//         )

//         vma_create_info: vma.AllocatorCreateInfo = {
//             // flags            = { .BUFFER_DEVICE_ADDRESS },
//             instance         = adapter_impl.instance.instance,
//             physicalDevice   = adapter_impl.physical_device,
//             device           = impl.device,
//             pVulkanFunctions = &vma_vulkan_functions,
//             vulkanApiVersion = api_version,
//         }

//         // Create the VMA (Vulkan Memory Allocator)
//         vk_check(vma.CreateAllocator(vma_create_info, &impl.vma_allocator))
//     }

//     // Create empty layouts
//     vk_create_empty_descriptor_set_layout :: proc(
//         device: vk.Device,
//         fp: vk.Device_VTable,
//     ) -> vk.DescriptorSetLayout {
//         vk_info := vk.DescriptorSetLayoutCreateInfo {
//             sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
//             bindingCount = 0,
//             pBindings    = nil,
//         }
//         layout: vk.DescriptorSetLayout
//         vk_check(fp.CreateDescriptorSetLayout(device, &vk_info, nil, &layout))
//         return layout
//     }

//     impl.empty_descriptor_set_layout = vk_create_empty_descriptor_set_layout(impl.device, impl.fp)

//     // For use with empty pipeline layouts
//     vk_create_empty_pipeline_layout :: proc(
//         device: vk.Device,
//         fp: vk.Device_VTable,
//     ) -> vk.PipelineLayout {
//         layout_create_info := vk.PipelineLayoutCreateInfo {
//             sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
//             setLayoutCount         = 0,
//             pSetLayouts            = nil,
//             pushConstantRangeCount = 0,
//             pPushConstantRanges    = nil,
//         }
//         layout: vk.PipelineLayout
//         vk_check(fp.CreatePipelineLayout(device, &layout_create_info, nil, &layout))
//         return layout
//     }

//     impl.empty_pipeline_layout = vk_create_empty_pipeline_layout(impl.device, impl.fp)

//     device_handle := device_pool_add(&gpu.vk.devices, impl)
//     device = Device(uintptr(device_handle) + 1) // 0→1, 1→2, etc. nil stays 0

//     device_impl := vk_device_get_impl(device)
//     device_impl.handle = device_handle

//     // Create default Queue
//     vk_default_queue_init(
//         device,
//         adapter_impl.graphics_family_index,
//         adapter_impl.compute_family_index,
//         adapter_impl.transfer_family_index,
//     )

//     // Initialize the command buffers
//     vk_submit_context_init(
//         &device_impl.submitter,
//         device,
//         adapter_impl.graphics_family_index,
//         impl.allocator,
//     )

//     // Initialize the descriptor allocator
//     vk_device_descriptor_allocator_init(device)

//     // Initialize dynamic handles
//     hm.dynamic_init(&device_impl.bind_groups, impl.allocator)
//     hm.dynamic_init(&device_impl.bind_group_layouts, impl.allocator)
//     hm.dynamic_init(&device_impl.buffers, impl.allocator)
//     hm.dynamic_init(&device_impl.command_buffers, impl.allocator)
//     hm.dynamic_init(&device_impl.command_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.compute_pass_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.compute_pipelines, impl.allocator)
//     hm.dynamic_init(&device_impl.external_textures, impl.allocator)
//     hm.dynamic_init(&device_impl.pipeline_layouts, impl.allocator)
//     hm.dynamic_init(&device_impl.query_sets, impl.allocator)
//     hm.dynamic_init(&device_impl.queues, impl.allocator)
//     hm.dynamic_init(&device_impl.render_bundles, impl.allocator)
//     hm.dynamic_init(&device_impl.render_bundle_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.render_pass_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.render_pipelines, impl.allocator)
//     hm.dynamic_init(&device_impl.samplers, impl.allocator)
//     hm.dynamic_init(&device_impl.shader_modules, impl.allocator)
//     hm.dynamic_init(&device_impl.textures, impl.allocator)
//     hm.dynamic_init(&device_impl.texture_views, impl.allocator)

//     // Initialize default allocators
//     device_impl.deferred_deletion.allocator = impl.allocator
//     device_impl.transfer_batch.temp_resources.allocator = impl.allocator
//     device_impl.transfer_batch.dst_buffers.allocator = impl.allocator

//     init_ref(device_impl, loc)
//     vk_adapter_add_ref(adapter)

//     return device, true
// }

// vk_device_get_impl :: #force_inline proc(
//     device: Device,
//     loc := #caller_location,
// ) -> ^VK_Device_Impl {
//     assert_contextless(device != {}, "Invalid device", loc)
//     idx := Device_Handle(uintptr(device) - 1)
//     return device_pool_get(&gpu.vk.devices, idx)
// }

// vk_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
//     impl := vk_device_get_impl(device, loc)
//     return impl.adapter
// }

// vk_device_callback :: proc(
//     device: Device,
//     type: Error_Type,
//     msg: string,
//     loc := #caller_location,
// ) {
//     assert(device != {}, "Invalid device", loc)
//     device := device
//     impl := vk_device_get_impl(device, loc)
//     if impl.error_callback.callback != nil {
//         impl.error_callback.callback(
//             &device,
//             type,
//             msg,
//             impl.error_callback.userdata1,
//             impl.error_callback.userdata2,
//         )
//     }
// }

// VK_Buffer_Access :: struct {
//     buffer:     Buffer,
//     is_storage: bool,
// }

// VK_Texture_View_Access :: struct {
//     texture_view: Texture_View,
//     is_storage:   bool,
// }

// vk_device_create_bind_group :: proc(
//     device: Device,
//     descriptor: ^Bind_Group_Descriptor,
//     loc := #caller_location,
// ) -> Bind_Group {
//     assert(descriptor != nil, "Invalid Bind_Group_Descriptor", loc)
//     assert(descriptor.layout != nil, "Invalid bind group layout", loc)

//     impl := vk_device_get_impl(device, loc)
//     layout_impl := vk_bind_group_layout_get_impl(descriptor.layout, loc)

//     bind_group_layout_add_ref(descriptor.layout)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta)

//     vk_descriptor_set, vk_descriptor_pool := vk_device_descriptor_allocator_allocate(
//         device,
//         &layout_impl.descriptor_set_layout,
//         layout_impl.desc_count,
//         layout_impl.contains_binding_arrays,
//         loc,
//     )

//     buffer_desc_count  := vk_device_descriptor_total_count_buffers(layout_impl.desc_count)
//     image_desc_count   := vk_device_descriptor_total_count_images(layout_impl.desc_count)
//     view_desc_count    := vk_device_descriptor_total_count_texture_views(layout_impl.desc_count)
//     sampler_desc_count := vk_device_descriptor_total_count_samplers(layout_impl.desc_count)

//     writes       := make([]vk.WriteDescriptorSet, len(descriptor.entries), ta)
//     buffer_infos := make([]vk.DescriptorBufferInfo, buffer_desc_count, ta)
//     image_infos  := make([]vk.DescriptorImageInfo, image_desc_count, ta)

//     buffers       := make([dynamic]VK_Buffer_Access, 0, buffer_desc_count, impl.allocator)
//     texture_views := make([dynamic]VK_Texture_View_Access, 0, view_desc_count, impl.allocator)
//     samplers      := make([dynamic]Sampler, 0, sampler_desc_count, impl.allocator)

//     write_idx, buffer_idx, image_idx: int

//     for entry in descriptor.entries {
//         layout_index, layout_found := slice.binary_search_by(
//             layout_impl.binding_map,
//             entry.binding,
//             proc(layout_entry: VK_Binding_Info, binding: u32) -> slice.Ordering {
//                 return slice.cmp(layout_entry.key, binding)
//             },
//         )
//         assert(layout_found, "Failed to find bind group layout entry for binding", loc)
//         layout_entry   := layout_impl.entries[layout_index]
//         layout_binding := layout_impl.binding_map[layout_index]

//         vk_desc_type   := vk_conv_to_descriptor_type(layout_entry)
//         expected_count := layout_binding.binding_array_size

//         entry_extras := chain_get(Bind_Group_Entry_Extras,
//             entry.next_in_chain, .Bind_Group_Entry_Extras)

//         when ODIN_DEBUG {
//             provided_count: u32 = 1
//             if entry_extras != nil {
//                 switch {
//                 case len(entry_extras.buffers) > 0:
//                     provided_count = u32(len(entry_extras.buffers))
//                 case len(entry_extras.samplers) > 0:
//                     provided_count = u32(len(entry_extras.samplers))
//                 case len(entry_extras.texture_views) > 0:
//                     provided_count = u32(len(entry_extras.texture_views))
//                 }
//             }
//             assert(provided_count == expected_count,
//                 "Descriptor count mismatch for binding (provided != layout expected)", loc)
//         }

//         writes[write_idx] = vk.WriteDescriptorSet{
//             sType           = .WRITE_DESCRIPTOR_SET,
//             dstSet          = vk_descriptor_set,
//             dstBinding      = entry.binding,
//             dstArrayElement = 0,
//             descriptorCount = expected_count,
//             descriptorType  = vk_desc_type,
//         }

//         if is_binding_active(layout_entry.buffer.type) {
//             b := layout_entry.buffer
//             is_storage := b.type == .Storage || b.type == .Read_Only_Storage

//             writes[write_idx].pBufferInfo = &buffer_infos[buffer_idx]

//             if entry_extras != nil && len(entry_extras.buffers) > 0 {
//                 for buf, i in entry_extras.buffers {
//                     buffer_impl := vk_buffer_get_impl(buf, loc)
//                     buffer_infos[buffer_idx + i] = vk.DescriptorBufferInfo{
//                         buffer = buffer_impl.vk_buffer,
//                         offset = vk.DeviceSize(entry.offset),
//                         range  = vk.DeviceSize(entry.size),
//                     }
//                     append(&buffers, VK_Buffer_Access{buffer = buf, is_storage = is_storage})
//                     vk_buffer_add_ref(buf)
//                 }
//                 buffer_idx += int(expected_count)
//             } else {
//                 buffer_impl := vk_buffer_get_impl(entry.buffer, loc)
//                 buffer_infos[buffer_idx] = vk.DescriptorBufferInfo{
//                     buffer = buffer_impl.vk_buffer,
//                     offset = vk.DeviceSize(entry.offset),
//                     range  = vk.DeviceSize(entry.size),
//                 }
//                 append(&buffers, VK_Buffer_Access{buffer = entry.buffer, is_storage = is_storage})
//                 vk_buffer_add_ref(entry.buffer)
//                 buffer_idx += 1
//             }

//         } else if is_binding_active(layout_entry.sampler.type) {
//             writes[write_idx].pImageInfo = &image_infos[image_idx]

//             if entry_extras != nil && len(entry_extras.samplers) > 0 {
//                 for smp, i in entry_extras.samplers {
//                     sampler_impl := vk_sampler_get_impl(smp, loc)
//                     image_infos[image_idx + i] =
//                         vk.DescriptorImageInfo{sampler = sampler_impl.sampler}
//                     append(&samplers, smp)
//                     vk_sampler_add_ref(smp)
//                 }
//                 image_idx += int(expected_count)
//             } else {
//                 sampler_impl := vk_sampler_get_impl(entry.sampler, loc)
//                 image_infos[image_idx] = vk.DescriptorImageInfo{sampler = sampler_impl.sampler}
//                 append(&samplers, entry.sampler)
//                 vk_sampler_add_ref(entry.sampler)
//                 image_idx += 1
//             }

//         } else if is_binding_active(layout_entry.texture.sample_type) ||
//                   is_binding_active(layout_entry.storage_texture.access) {
//             image_layout := vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
//             is_storage   := is_binding_active(layout_entry.storage_texture.access)
//             if is_storage {
//                 image_layout = .GENERAL
//             }

//             writes[write_idx].pImageInfo = &image_infos[image_idx]

//             if entry_extras != nil && len(entry_extras.texture_views) > 0 {
//                 for tv, i in entry_extras.texture_views {
//                     tv_impl := vk_texture_view_get_impl(tv, loc)
//                     image_infos[image_idx + i] = vk.DescriptorImageInfo{
//                         imageView   = tv_impl.vk_image_view,
//                         imageLayout = image_layout,
//                     }
//                     append(&texture_views, VK_Texture_View_Access{
//                         texture_view = tv,
//                         is_storage = is_storage,
//                     })
//                     vk_texture_view_add_ref(tv)
//                 }
//                 image_idx += int(expected_count)
//             } else {
//                 tv_impl := vk_texture_view_get_impl(entry.texture_view, loc)
//                 image_infos[image_idx] = vk.DescriptorImageInfo{
//                     imageView   = tv_impl.vk_image_view,
//                     imageLayout = image_layout,
//                 }
//                 append(&texture_views, VK_Texture_View_Access{
//                     texture_view = entry.texture_view,
//                     is_storage = is_storage,
//                 })
//                 vk_texture_view_add_ref(entry.texture_view)
//                 image_idx += 1
//             }

//         } else {
//             panic("Unsupported bind group layout entry", loc)
//         }

//         write_idx += 1
//     }

//     vk.UpdateDescriptorSets(impl.device, u32(write_idx), raw_data(writes), 0, nil)

//     bg_impl := hm_dynamic_add_get(&impl.bind_groups, VK_Bind_Group_Impl{
//         device             = device,
//         layout             = descriptor.layout,
//         vk_descriptor_pool = vk_descriptor_pool,
//         vk_descriptor_set  = vk_descriptor_set,
//         buffers            = buffers[:],
//         texture_views      = texture_views[:],
//         samplers           = samplers[:],
//     }) or_else panic("Failed to allocate bind group layout handle", loc)

//     init_ref(bg_impl)

//     bg_handle := handle_make(bg_impl.handle, impl.handle)
//     bg := handle_to_raw(Bind_Group, bg_handle)

//     return bg
// }

// vk_device_create_bind_group_layout :: proc(
//     device: Device,
//     descriptor: ^Bind_Group_Layout_Descriptor,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     assert(descriptor != nil, "Invalid Bind_Group_Layout_Descriptor", loc)

//     impl := vk_device_get_impl(device, loc)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta)

//     vk_bindings := make([dynamic]vk.DescriptorSetLayoutBinding, ta)
//     vk_binding_flags := make([dynamic]vk.DescriptorBindingFlags, ta)

//     binding_map := make([dynamic]VK_Binding_Info, impl.allocator)

//     next_binding: u32
//     contains_binding_arrays: bool
//     desc_count: VK_Descriptor_Total_Count

//     for &entry in descriptor.entries {
//         extra_count: u32
//         entry_extras := chain_get(Bind_Group_Layout_Entry_Extras,
//             entry.next_in_chain, .Bind_Group_Layout_Entry_Extras)

//         if entry_extras != nil {
//             extra_count = entry_extras.count
//         }

//         if extra_count != 0 {
//             contains_binding_arrays = true
//         }

//         // partially_bound := .PartiallyBound in descriptor.flags
//         flags: vk.DescriptorBindingFlags
//         // if partially_bound && entry.count != 0 {
//         //     flags += {.PARTIALLY_BOUND}
//         // }
//         if extra_count != 0 {
//             flags += {.UPDATE_AFTER_BIND}
//         }

//         count := max(1, extra_count)

//         append(&vk_bindings, vk.DescriptorSetLayoutBinding{
//             binding            = next_binding,
//             descriptorType     = vk_conv_to_descriptor_type(entry),
//             descriptorCount    = count,
//             stageFlags         = vk_conv_to_shader_stage_flags(entry.visibility),
//             pImmutableSamplers = nil,
//         })
//         append(&vk_binding_flags, flags)
//         append(&binding_map, VK_Binding_Info{
//             key                = entry.binding,
//             binding            = next_binding,
//             binding_array_size = count,
//         })
//         next_binding += 1

//         if is_binding_active(entry.buffer.type) {
//             b := entry.buffer
//             switch b.type {
//             case .Uniform:
//                 if b.has_dynamic_offset {
//                     desc_count.uniform_buffer_dynamic += count
//                 } else {
//                     desc_count.uniform_buffer += count
//                 }
//             case .Storage, .Read_Only_Storage:
//                 if b.has_dynamic_offset {
//                     desc_count.storage_buffer_dynamic += count
//                 } else {
//                     desc_count.storage_buffer += count
//                 }
//             case .Undefined, .Binding_Not_Used:
//                 panic("Invalid buffer binding layout", loc)
//             }
//         } else if is_binding_active(entry.sampler.type) {
//             desc_count.sampler += count
//         } else if is_binding_active(entry.texture.sample_type) {
//             desc_count.sampled_image += count
//         } else if is_binding_active(entry.storage_texture.access) {
//             desc_count.storage_image += count
//         }else {
//             panic("Invalid bind group layout entry", loc)
//         }
//     }

//     layout_flags: vk.DescriptorSetLayoutCreateFlags
//     if contains_binding_arrays {
//         layout_flags = {.UPDATE_AFTER_BIND_POOL}
//     }

//     binding_flag_info := vk.DescriptorSetLayoutBindingFlagsCreateInfo{
//         sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
//         bindingCount  = u32(len(vk_binding_flags)),
//         pBindingFlags = raw_data(vk_binding_flags),
//     }

//     vk_info := vk.DescriptorSetLayoutCreateInfo{
//         sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
//         pNext        = &binding_flag_info,
//         flags        = layout_flags,
//         bindingCount = u32(len(vk_bindings)),
//         pBindings    = raw_data(vk_bindings),
//     }

//     vk_layout: vk.DescriptorSetLayout
//     vk_check(impl.fp.CreateDescriptorSetLayout(impl.device, &vk_info, nil, &vk_layout))

//     bgl_impl := hm_dynamic_add_get(&impl.bind_group_layouts, VK_Bind_Group_Layout_Impl{
//         device                  = device,
//         descriptor_set_layout   = vk_layout,
//         desc_count              = desc_count,
//         contains_binding_arrays = contains_binding_arrays,
//         binding_map             = binding_map[:],
//     }) or_else panic("Failed to allocate bind group layout handle", loc)

//     init_ref(bgl_impl)

//     entry_count := u32(len(descriptor.entries))
//     if entry_count > 0 {
//         bgl_impl.entries = make([]Bind_Group_Layout_Entry, entry_count, impl.allocator)
//         copy(bgl_impl.entries, descriptor.entries)

//         // Sort entries by binding in ascending order
//         slice.sort_by(bgl_impl.entries[:], proc(a, b: Bind_Group_Layout_Entry) -> bool {
//             return a.binding < b.binding
//         })
//     }

//     slice.sort_by(bgl_impl.binding_map[:], proc(a, b: VK_Binding_Info) -> bool {
//         return a.key < b.key
//     })

//     bgl_handle := handle_make(bgl_impl.handle, impl.handle)
//     bgl := handle_to_raw(Bind_Group_Layout, bgl_handle)

//     return bgl
// }

// vk_device_create_buffer_impl :: proc(
//     device: Device,
//     desc: Buffer_Descriptor_Impl,
//     loc := #caller_location,
// ) -> ^VK_Buffer_Impl {
//     impl := vk_device_get_impl(device, loc)
//     adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

//     vk_buffer_flags := vk_conv_to_buffer_usage_flags(desc.internal_uses)

//     mem_flags := vk_infer_memory_flags(desc.internal_uses)

//     ci := vk.BufferCreateInfo {
//         sType                 = .BUFFER_CREATE_INFO,
//         pNext                 = nil,
//         flags                 = {},
//         size                  = vk.DeviceSize(desc.size),
//         usage                 = vk_buffer_flags,
//         sharingMode           = .EXCLUSIVE,
//         queueFamilyIndexCount = 0,
//         pQueueFamilyIndices   = nil,
//     }

//     is_coherent_memory: bool

//     when USE_VMA {
//         vma_alloc_info: vma.AllocationCreateInfo

//         // Initialize vma.AllocationCreateInfo for host-visible memory
//         if .HOST_VISIBLE in mem_flags {
//             vma_alloc_info = {
//                 flags          = {.HOST_ACCESS_RANDOM},
//                 requiredFlags  = {.HOST_VISIBLE},
//                 preferredFlags = {.HOST_COHERENT, .HOST_CACHED},
//             }

//             // Persistent mapping, only when requested at creation
//             if desc.mapped_at_creation {
//                 vma_alloc_info.flags += {.MAPPED}
//             }

//             // Probe for coherency
//             temp_buffer: vk.Buffer
//             vk_check(impl.fp.CreateBuffer(impl.device, &ci, nil, &temp_buffer))
//             requirements: vk.MemoryRequirements
//             impl.fp.GetBufferMemoryRequirements(impl.device, temp_buffer, &requirements)
//             impl.fp.DestroyBuffer(impl.device, temp_buffer, nil)

//             is_coherent_memory = vk_utils_is_coherent_memory(
//                 adapter_impl.caps.memory_properties,
//                 requirements.memoryTypeBits,
//             )

//             if is_coherent_memory {
//                 vma_alloc_info.requiredFlags += {.HOST_COHERENT}
//             }
//         }

//         vma_alloc_info.usage = .AUTO

//         vk_buffer: vk.Buffer
//         vma_allocation: vma.Allocation
//         vma_allocation_info: vma.AllocationInfo
//         vk_check(vma.CreateBufferWithAlignment(
//             impl.vma_allocator,
//             ci,
//             vma_alloc_info,
//             16,
//             &vk_buffer,
//             &vma_allocation,
//             &vma_allocation_info,
//         ))

//         mapped_ptr: rawptr
//         if desc.mapped_at_creation {
//             mapped_ptr = vma_allocation_info.pMappedData
//         }
//     } else {
//         // Create buffer
//         vk_buffer: vk.Buffer
//         vk_check(impl.fp.CreateBuffer(impl.device, &ci, nil, &vk_buffer))

//         requirements_info2 := vk.BufferMemoryRequirementsInfo2 {
//             sType  = .BUFFER_MEMORY_REQUIREMENTS_INFO_2,
//             buffer = vk_buffer,
//         }
//         requirements := vk.MemoryRequirements2 {
//             sType = .MEMORY_REQUIREMENTS_2,
//         }
//         impl.fp.GetBufferMemoryRequirements2(impl.device, &requirements_info2, &requirements)

//         is_coherent_memory = vk_utils_is_coherent_memory(
//             adapter_impl.vk_memory_properties, requirements.memoryRequirements.memoryTypeBits)

//         vk_out_memory: vk.DeviceMemory
//         vk_check(vk_utils_allocate_memory2(
//             adapter_impl.physical_device, impl.device, &requirements, mem_flags, &vk_out_memory))
//         vk_check(vk.BindBufferMemory(impl.device, vk_buffer, vk_out_memory, 0))

//         mapped_ptr: rawptr
//         if desc.mapped_at_creation {
//             vk_check(impl.fp.MapMemory(
//                 impl.device, vk_out_memory, 0, vk.DeviceSize(vk.WHOLE_SIZE), {}, &mapped_ptr))
//         }
//     }

//     buffer_impl := hm_dynamic_add_get(&impl.buffers, VK_Buffer_Impl {
//         map_state          = Buffer_Map_State_Idle{},
//         device             = device,
//         vk_buffer          = vk_buffer,
//         size               = desc.size,
//         vk_size            = vk.DeviceSize(desc.size),
//         mapped_ptr         = mapped_ptr,
//         vk_buffer_flags    = vk_buffer_flags,
//         vk_mem_flags       = mem_flags,
//         usage              = desc.usage,
//         internal_uses      = desc.internal_uses,
//         is_coherent_memory = is_coherent_memory,
//     })

//     init_ref(buffer_impl)

//     when USE_VMA {
//         buffer_impl.vma_allocation = vma_allocation
//         buffer_impl.vma_allocation_info = vma_allocation_info
//     } else {
//         buffer_impl.vk_memory = vk_out_memory
//     }

//     return buffer_impl
// }

// vk_device_create_buffer :: proc(
//     device: Device,
//     descriptor: ^Buffer_Descriptor,
//     loc := #caller_location,
// ) -> Buffer {
//     impl := vk_device_get_impl(device, loc)

//     desc := resolve_buffer_descriptor(device, descriptor, loc)
//     buffer_impl := vk_device_create_buffer_impl(device, desc, loc)

//     if desc.mapped_at_creation {
//         if .Map_Write not_in desc.internal_uses {
//             stage_desc := Buffer_Descriptor_Impl {
//                 label              = "Internal stage buffer",
//                 size               = desc.size,
//                 internal_uses      = {.Map_Write, .Copy_Src},
//                 memory_flags       = {.Transient},
//                 mapped_at_creation = true,
//             }
//             stg_buffer_impl := vk_device_create_buffer_impl(device, stage_desc, loc)

//             stg_handle := handle_make(stg_buffer_impl.handle, impl.handle)
//             buffer_impl.map_state = Buffer_Map_State_Init {
//                 staging_buffer = {
//                     buffer      = handle_to_raw(Buffer, stg_handle),
//                     device      = device,
//                     size        = desc.size,
//                     is_coherent = stg_buffer_impl.is_coherent_memory,
//                     ptr         = stg_buffer_impl.mapped_ptr,
//                 },
//             }
//         } else {
//             buffer_impl.map_state = Buffer_Map_State_Active {
//                 ptr         = buffer_impl.mapped_ptr,
//                 is_coherent = buffer_impl.is_coherent_memory,
//                 range       = {0, desc.size},
//                 mode        = .Write,
//             }
//         }
//     }

//     buffer_handle := handle_make(buffer_impl.handle, impl.handle)
//     buffer := handle_to_raw(Buffer, buffer_handle)

//     return buffer
// }

// vk_device_create_command_encoder :: proc(
//     device: Device,
//     descriptor: ^Command_Encoder_Descriptor,
//     loc := #caller_location,
// ) -> Command_Encoder {
//     impl := vk_device_get_impl(device, loc)

//     cmdbuf := vk_submit_context_acquire(&impl.submitter, loc)

//     handle_impl := hm_dynamic_add_get(&impl.command_encoders, VK_Command_Encoder_Impl {
//         device       = device,
//         buffer_index = cmdbuf.buffer_index,
//         is_encoding  = true,
//         is_rendering = false,
//         is_computing = false,
//     })
//     init_ref(handle_impl, loc)

//     encoder_handle := handle_make(handle_impl.handle, impl.handle)

//     encoder := handle_to_raw(Command_Encoder, encoder_handle)
//     cmdbuf.encoder = encoder

//     return encoder
// }

// vk_device_create_compute_pipeline :: proc(
//     device: Device,
//     descriptor: ^Compute_Pipeline_Descriptor,
//     loc := #caller_location,
// ) -> Compute_Pipeline {
//     unimplemented(loc = loc)
// }

// vk_device_create_compute_pipeline_async :: proc(
//     device: Device,
//     descriptor: ^Compute_Pipeline_Descriptor,
//     callback_info: Create_Compute_Pipeline_Async_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_device_create_pipeline_layout :: proc(
//     device: Device,
//     descriptor: ^Pipeline_Layout_Descriptor,
//     loc := #caller_location,
// ) -> Pipeline_Layout {
//     unimplemented(loc = loc)
// }

// vk_device_create_query_set :: proc(
//     device: Device,
//     descriptor: ^Query_Set_Descriptor,
//     loc := #caller_location,
// ) -> Query_Set {
//     unimplemented(loc = loc)
// }

// vk_device_create_render_bundle_encoder :: proc(
//     device: Device,
//     descriptor: ^Render_Bundle_Encoder_Descriptor,
//     loc := #caller_location,
// ) -> Render_Bundle_Encoder {
//     unimplemented(loc = loc)
// }

// vk_device_create_render_pipeline :: proc(
//     device: Device,
//     descriptor: ^Render_Pipeline_Descriptor,
//     loc := #caller_location,
// ) -> Render_Pipeline {
//     impl := vk_device_get_impl(device, loc)
//     adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta,
//     )

//     vk_rendering_info := vk.PipelineRenderingCreateInfo {
//         sType = .PIPELINE_RENDERING_CREATE_INFO_KHR,
//     }

//     // Shader stages
//     vk_shader_stages: sa.Small_Array(5, vk.PipelineShaderStageCreateInfo)

//     // Add the vertex shader (required)
//     assert(descriptor.vertex.module != nil, "Vertex shader module is required", loc)
//     assert(descriptor.vertex.entry_point != "", "Invalid vertex shader entry point", loc)

//     vertex_module_impl := vk_shader_module_get_impl(descriptor.vertex.module, loc)

//     sa.push_back(&vk_shader_stages, vk.PipelineShaderStageCreateInfo {
//         sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
//         stage  = {.VERTEX},
//         module = vertex_module_impl.shader_module,
//         pName  = strings.clone_to_cstring(descriptor.vertex.entry_point, ta),
//     })

//     // Vertex input state
//     vertex_bindings := make([dynamic]vk.VertexInputBindingDescription,
//         0, len(descriptor.vertex.buffers), ta)
//     vertex_attributes := make([dynamic]vk.VertexInputAttributeDescription, ta)

//     for &buffer, binding in descriptor.vertex.buffers {
//         append(&vertex_bindings, vk.VertexInputBindingDescription {
//             binding   = u32(binding),
//             stride    = u32(buffer.array_stride),
//             inputRate = vk_conv_to_vertex_step_mode(buffer.step_mode, loc),
//         })

//         // Ensure capacity for everything appended so far plus the new batch
//         reserve(&vertex_attributes, len(vertex_attributes) + len(buffer.attributes))
//         for &attr in buffer.attributes {
//             append(&vertex_attributes, vk.VertexInputAttributeDescription {
//                 location = attr.shader_location,
//                 binding  = u32(binding),
//                 format   = vk_conv_to_vertex_format(attr.format),
//                 offset   = u32(attr.offset),
//             })
//         }
//     }

//     vk_vertex_input_state := vk.PipelineVertexInputStateCreateInfo {
//         sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
//         vertexBindingDescriptionCount   = u32(len(vertex_bindings)),
//         pVertexBindingDescriptions      = raw_data(vertex_bindings),
//         vertexAttributeDescriptionCount = u32(len(vertex_attributes)),
//         pVertexAttributeDescriptions    = raw_data(vertex_attributes),
//     }

//     // Input assembly state
//     primitive := descriptor.primitive
//     vk_input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
//         sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
//         topology               = vk_conv_to_primitive_topology(primitive.topology, loc),
//         primitiveRestartEnable = primitive.strip_index_format != .Undefined,
//     }

//     // Viewport and scissor can be nil if the viewport state is dynamic
//     vk_viewport_state := vk.PipelineViewportStateCreateInfo {
//         sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
//         viewportCount = 1,
//         pViewports    = nil,
//         scissorCount  = 1,
//         pScissors     = nil,
//     }

//     // Rasterization state
//     vk_rasterization_state := vk.PipelineRasterizationStateCreateInfo {
//         sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
//         flags                   = {},
//         depthClampEnable        = b32(primitive.unclipped_depth),
//         rasterizerDiscardEnable = false,
//         // polygonMode             = vk_conv_to_polygon_mode(primitive.polygon_mode),
//         cullMode                = vk_conv_to_cull_mode_flags(primitive.cull_mode, loc),
//         frontFace               = vk_conv_to_front_face(primitive.front_face, loc),
//         lineWidth               = 1.0,
//     }

//     // Multisample state
//     multisample := descriptor.multisample
//     vk_sample_mask := vk.SampleMask(multisample.mask)
//     vk_multisample_state := vk.PipelineMultisampleStateCreateInfo {
//         sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
//         rasterizationSamples  = vk_conv_to_sample_count_flags(multisample.count, loc),
//         sampleShadingEnable   = false,
//         minSampleShading      = 0.0,
//         pSampleMask           = multisample.mask != max(u32) ? &vk_sample_mask : nil,
//         alphaToCoverageEnable = b32(multisample.alpha_to_coverage_enabled),
//         alphaToOneEnable      = false,
//     }

//     // Depth stencil state
//     vk_depth_stencil_state: vk.PipelineDepthStencilStateCreateInfo
//     has_depth_stencil: bool
//     if descriptor.depth_stencil != nil {
//         ds := descriptor.depth_stencil
//         has_depth_stencil = true

//         set_stencil_state_ops :: proc(
//             self: ^vk.PipelineDepthStencilStateCreateInfo,
//             face_mask: vk.StencilFaceFlags,
//             state: Stencil_Face_State,
//             loc := #caller_location,
//         ) {
//             fail_op := vk_conv_to_stencil_op(state.fail_op, loc)
//             pass_op := vk_conv_to_stencil_op(state.pass_op, loc)
//             depth_fail_op := vk_conv_to_stencil_op(state.depth_fail_op, loc)
//             compare_op := vk_conv_to_compare_op(state.compare, loc)

//             stencil_test_enable :=
//                 self.stencilTestEnable ||
//                 fail_op != .KEEP ||
//                 pass_op != .KEEP ||
//                 depth_fail_op != .KEEP ||
//                 compare_op != .ALWAYS
//             self.stencilTestEnable = b32(stencil_test_enable)

//             if .FRONT in face_mask {
//                 self.front.failOp = fail_op
//                 self.front.passOp = pass_op
//                 self.front.depthFailOp = depth_fail_op
//                 self.front.compareOp = compare_op
//             }

//             if .BACK in face_mask {
//                 self.back.failOp = fail_op
//                 self.back.passOp = pass_op
//                 self.back.depthFailOp = depth_fail_op
//                 self.back.compareOp = compare_op
//             }
//         }

//         vk_depth_stencil_state = {
//             sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
//             pNext                 = {},
//             flags                 = {},
//             depthTestEnable       = b32(ds.depth_compare != .Always || ds.depth_write_enabled),
//             depthWriteEnable      = b32(ds.depth_write_enabled),
//             depthCompareOp        = vk_conv_to_compare_op(ds.depth_compare, loc),
//             depthBoundsTestEnable = false,
//             stencilTestEnable     = false,
//             front                 = {},
//             back                  = {},
//             minDepthBounds        = 0.0,
//             maxDepthBounds        = 1.0,
//         }

//         set_stencil_state_ops(&vk_depth_stencil_state, {.FRONT}, ds.stencil_front, loc)
//         set_stencil_state_ops(&vk_depth_stencil_state, {.BACK}, ds.stencil_back, loc)

//         vk_depth_stencil_state.front.compareMask = ds.stencil_read_mask
//         vk_depth_stencil_state.front.writeMask = ds.stencil_write_mask
//         vk_depth_stencil_state.back.compareMask = ds.stencil_read_mask
//         vk_depth_stencil_state.back.writeMask = ds.stencil_write_mask

//         // reference is dynamic
//         vk_depth_stencil_state.front.reference = 0
//         vk_depth_stencil_state.back.reference = 0

//         // Rasterization state depth bias
//         if ds.depth_bias != 0 || ds.depth_bias_clamp != 0 || ds.depth_bias_slope_scale != 0 {
//             vk_rasterization_state.depthBiasEnable = true
//             vk_rasterization_state.depthBiasConstantFactor = f32(ds.depth_bias)
//             vk_rasterization_state.depthBiasClamp = ds.depth_bias_clamp
//             vk_rasterization_state.depthBiasSlopeFactor = ds.depth_bias_slope_scale
//         }

//         vk_ds_format := vk_conv_to_format(adapter_impl.caps, ds.format)

//         if texture_format_has_depth_aspect(ds.format) {
//             vk_rendering_info.depthAttachmentFormat = vk_ds_format
//         }
//         if texture_format_has_stencil_aspect(ds.format) {
//             vk_rendering_info.stencilAttachmentFormat = vk_ds_format
//         }
//     }

//     // Optional fragment stage + color targets
//     color_blend_attachment_states: sa.Small_Array(
//         MAX_COLOR_ATTACHMENTS,
//         vk.PipelineColorBlendAttachmentState,
//     )

//     // Color formats for dynamic rendering
//     color_attachment_formats: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.Format)

//     if descriptor.fragment != nil {
//         frag := descriptor.fragment

//         assert(frag.module != nil, "Fragment shader module is required", loc)
//         assert(frag.entry_point != "", "Invalid fragment shader entry point", loc)

//         fragment_module_impl := vk_shader_module_get_impl(frag.module, loc)

//         sa.push_back(&vk_shader_stages, vk.PipelineShaderStageCreateInfo {
//             sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
//             stage  = {.FRAGMENT},
//             module = fragment_module_impl.shader_module,
//             pName  = strings.clone_to_cstring(frag.entry_point, ta),
//         })

//         // Color attachments from targets
//         for &target in frag.targets {
//             attachment := vk.PipelineColorBlendAttachmentState {
//                 blendEnable    = false,
//                 colorWriteMask = {.R, .G, .B, .A},
//             }

//             if target.blend != nil {
//                 color := target.blend.color
//                 alpha := target.blend.alpha
//                 attachment.blendEnable = true
//                 attachment.srcColorBlendFactor = vk_conv_to_blend_factor(color.src_factor, loc)
//                 attachment.dstColorBlendFactor = vk_conv_to_blend_factor(color.dst_factor, loc)
//                 attachment.colorBlendOp        = vk_conv_to_blend_op(color.operation, loc)
//                 attachment.srcAlphaBlendFactor = vk_conv_to_blend_factor(alpha.src_factor, loc)
//                 attachment.dstAlphaBlendFactor = vk_conv_to_blend_factor(alpha.dst_factor, loc)
//                 attachment.alphaBlendOp        = vk_conv_to_blend_op(alpha.operation, loc)
//             }

//             attachment.colorWriteMask = vk_conv_to_color_component_flags(target.write_mask, loc)

//             attachment_format := vk_conv_to_format(adapter_impl.caps, target.format)

//             sa.push_back(&color_blend_attachment_states, attachment)
//             sa.push_back(&color_attachment_formats, attachment_format)
//         }
//     }

//     vk_color_blend_state := vk.PipelineColorBlendStateCreateInfo {
//         sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
//         logicOpEnable   = false,
//         logicOp         = .COPY,
//         attachmentCount = u32(sa.len(color_blend_attachment_states)),
//         pAttachments    = raw_data(sa.slice(&color_blend_attachment_states)),
//     }

//     vk_rendering_info.colorAttachmentCount = u32(sa.len(color_attachment_formats))
//     vk_rendering_info.pColorAttachmentFormats = raw_data(sa.slice(&color_attachment_formats))

//     // Dynamic states (required for dynamic rendering)
//     vk_dynamic_states := []vk.DynamicState {
//         .VIEWPORT,
//         .SCISSOR,
//         .BLEND_CONSTANTS,
//         .STENCIL_REFERENCE,
//     }

//     vk_dynamic_state := vk.PipelineDynamicStateCreateInfo {
//         sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
//         dynamicStateCount = u32(len(vk_dynamic_states)),
//         pDynamicStates    = raw_data(vk_dynamic_states),
//     }

//     // Use the provided pipeline layout or use the default empty one
//     vk_pipeline_layout: vk.PipelineLayout
//     is_empty_layout: bool

//     if descriptor.layout != nil {
//         vk_pipeline_impl := vk_pipeline_layout_get_impl(descriptor.layout, loc)
//         vk_pipeline_layout = vk_pipeline_impl.pipeline_layout
//         vk_pipeline_layout_add_ref(descriptor.layout)
//     } else {
//         is_empty_layout = true
//         vk_pipeline_layout = impl.empty_pipeline_layout
//     }

//     create_info := vk.GraphicsPipelineCreateInfo {
//         sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
//         pNext               = &vk_rendering_info,
//         flags               = {},
//         stageCount          = u32(sa.len(vk_shader_stages)),
//         pStages             = raw_data(sa.slice(&vk_shader_stages)),
//         pVertexInputState   = &vk_vertex_input_state,
//         pInputAssemblyState = &vk_input_assembly,
//         pTessellationState  = {}, // no tessellation
//         pViewportState      = &vk_viewport_state,
//         pRasterizationState = &vk_rasterization_state,
//         pMultisampleState   = &vk_multisample_state,
//         pDepthStencilState  = &vk_depth_stencil_state if has_depth_stencil else nil,
//         pColorBlendState    = &vk_color_blend_state,
//         pDynamicState       = &vk_dynamic_state,
//         layout              = vk_pipeline_layout,
//         renderPass          = {},
//         subpass             = {},
//         basePipelineHandle  = {},
//         basePipelineIndex   = {},
//     }

//     vk_pipeline: vk.Pipeline
//     vk_check(vk.CreateGraphicsPipelines(
//         impl.device, {}, 1, &create_info, nil, &vk_pipeline), loc = loc)

//     handle_impl := hm_dynamic_add_get(&impl.render_pipelines, VK_Render_Pipeline_Impl {
//         device          = device,
//         layout          = descriptor.layout,
//         pipeline        = vk_pipeline,
//         is_empty_layout = is_empty_layout,
//     })
//     init_ref(handle_impl)

//     render_pipeline_handle := handle_make(handle_impl.handle, impl.handle)
//     return handle_to_raw(Render_Pipeline, render_pipeline_handle)
// }

// vk_device_create_render_pipeline_async :: proc(
//     device: Device,
//     descriptor: ^Render_Pipeline_Descriptor,
//     callback_info: Create_Render_Pipeline_Async_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_device_create_sampler :: proc(
//     device: Device,
//     descriptor: ^Sampler_Descriptor,
//     loc := #caller_location,
// ) -> Sampler {
//     impl := vk_device_get_impl(device, loc)

//     create_info := vk.SamplerCreateInfo {
//         sType                   = .SAMPLER_CREATE_INFO,
//         magFilter               = vk_conv_to_filter(descriptor.mag_filter),
//         minFilter               = vk_conv_to_filter(descriptor.min_filter),
//         mipmapMode              = vk_cont_to_sampler_filter_mode(descriptor.mipmap_filter),
//         addressModeU            = vk_conv_to_sampler_address_mode(descriptor.address_mode_u),
//         addressModeV            = vk_conv_to_sampler_address_mode(descriptor.address_mode_v),
//         addressModeW            = vk_conv_to_sampler_address_mode(descriptor.address_mode_w),
//         mipLodBias              = {},
//         anisotropyEnable        = false,
//         maxAnisotropy           = 1.0,
//         compareEnable           = false,
//         compareOp               = .ALWAYS,
//         minLod                  = descriptor.lod_min_clamp,
//         maxLod                  = descriptor.lod_max_clamp,
//         borderColor             = {},
//         unnormalizedCoordinates = {},
//     }

//     if descriptor.compare != .Always {
//         create_info.compareEnable = true
//         create_info.compareOp = vk_conv_to_compare_op(descriptor.compare)
//     }

//     if descriptor.max_anisotropy > 1 {
//         create_info.anisotropyEnable = true
//         create_info.maxAnisotropy = f32(descriptor.max_anisotropy)
//     }

//     vk_sampler: vk.Sampler
//     vk_check(impl.fp.CreateSampler(impl.device, &create_info, nil, &vk_sampler), loc = loc)

//     sampler_impl := hm_dynamic_add_get(&impl.samplers, VK_Sampler_Impl {
//         device  = device,
//         sampler = vk_sampler,
//     })

//     init_ref(sampler_impl, loc)

//     sampler_handle := handle_make(sampler_impl.handle, impl.handle)
//     sampler := handle_to_raw(Sampler, sampler_handle)

//     return sampler
// }

// vk_device_create_shader_module :: proc(
//     device: Device,
//     descriptor: ^Shader_Module_Descriptor,
//     loc := #caller_location,
// ) -> Shader_Module {
//     impl := vk_device_get_impl(device, loc)

//     assert(descriptor != nil, "Invalid shader module descriptor", loc)

//     source := chain_get(Shader_Source_SPIRV, descriptor.next_in_chain, .Shader_Source_SPIRV)
//     assert(source != nil, "Shader_Source_SPIRV is missing", loc)

//     assert(len(source.code) > 0, "Shader code is empty", loc)
//     assert(len(source.code) >= 4, "Shader bytecode too small to be valid", loc)

//     create_info := vk.ShaderModuleCreateInfo {
//         sType    = .SHADER_MODULE_CREATE_INFO,
//         codeSize = len(source.code) * 4, // bytes
//         pCode    = raw_data(source.code),
//     }

//     vk_shader_module: vk.ShaderModule
//     vk_check(vk.CreateShaderModule(
//         impl.device, &create_info, nil, &vk_shader_module), loc = loc)

//     handle_impl := hm_dynamic_add_get(&impl.shader_modules, VK_Shader_Module_Impl {
//         device        = device,
//         shader_module = vk_shader_module,
//     })

//     init_ref(handle_impl, loc)

//     shader_module_handle := handle_make(handle_impl.handle, impl.handle)
//     return handle_to_raw(Shader_Module, shader_module_handle)
// }

// vk_device_create_texture :: proc(
//     device: Device,
//     _descriptor_: ^Texture_Descriptor,
//     loc := #caller_location,
// ) -> Texture {
//     assert(_descriptor_ != nil, "Invalid Texture_Descriptor", loc)

//     impl := vk_device_get_impl(device, loc)
//     adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

//     // Get the descriptor implementation
//     desc := resolve_texture_descriptor(device, _descriptor_^, loc)

//     // Set create flags
//     vk_create_flags: vk.ImageCreateFlags

//     // 3D textures used as color targets need 2D array compatible for slice rendering
//     if desc.dimension == .D3 && .Color_Target in desc.internal_usage {
//         vk_create_flags += {.D2_ARRAY_COMPATIBLE}
//     }

//     // Cubemap support
//     if texture_descriptor_is_cube_compatible(desc) {
//         vk_create_flags += { .CUBE_COMPATIBLE }
//     }

//     // View format reinterpretation requires mutable format
//     if len(desc.view_formats) > 0 {
//         vk_create_flags += {.MUTABLE_FORMAT}
//     }

//     // Convert TextureDimension to vk.ImageType
//     vk_image_type := vk_conv_to_image_type(desc.dimension)

//     // Convert TextureFormat to vk.Format
//     vk_format := vk_conv_to_format(adapter_impl.caps, desc.format)

//     // Convert Extent3d to vk.Extent3D
//     vk_extent := vk_conv_to_extent_3d(desc.size, desc.dimension)

//     // Convert TextureUsage to vk.ImageUsageFlags
//     vk_image_usage_flags := vk_conv_to_image_usage_flags(desc.internal_usage)

//     // Convert sample count to vk.SampleCountFlags
//     vk_samples := vk_conv_to_sample_count_flags(desc.sample_count, loc)

//     image_create_info := vk.ImageCreateInfo {
//         sType         = .IMAGE_CREATE_INFO,
//         flags         = vk_create_flags,
//         imageType     = vk_image_type,
//         format        = vk_format,
//         extent        = vk_extent,
//         mipLevels     = desc.mip_level_count,
//         arrayLayers   = texture_descriptor_array_layer_count(desc, loc),
//         samples       = vk_samples,
//         tiling        = .OPTIMAL,
//         usage         = vk_image_usage_flags,
//         sharingMode   = .EXCLUSIVE,
//         initialLayout = .UNDEFINED,
//     }

//     // Build view formats list for pNext chain if needed
//     vk_view_formats: [dynamic]vk.Format
//     view_format_count := u32(len(desc.view_formats))

//     vk_format_list_info: vk.ImageFormatListCreateInfo
//     if view_format_count > 0 {
//         ta := context.temp_allocator
//         runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//             ignore = context.allocator == ta || impl.allocator == ta)

//         vk_view_formats = make([dynamic]vk.Format, 0, view_format_count, ta)

//         for f in desc.view_formats {
//             append(&vk_view_formats, vk_conv_to_format(adapter_impl.caps, f))
//         }
//         // Include the base format itself
//         append(&vk_view_formats, vk_format)

//         vk_format_list_info = vk.ImageFormatListCreateInfo{
//             sType           = .IMAGE_FORMAT_LIST_CREATE_INFO,
//             viewFormatCount = view_format_count,
//             pViewFormats    = raw_data(vk_view_formats),
//         }
//         image_create_info.pNext = &vk_format_list_info
//     }

//     num_planes: u32 = 1 // TODO
//     is_disjoint := num_planes > 1

//     if is_disjoint {
//         // TODO
//     }

//     // For no-MVA path or multi planar textures
//     vk_device_create_texture_manual_alloc :: proc(
//         impl: ^VK_Device_Impl,
//         image_create_info: ^vk.ImageCreateInfo,
//         num_planes: u32,
//         loc := #caller_location,
//     ) -> (
//         vk_image: vk.Image,
//         vk_memory: [VK_MAX_IMAGE_PLANES]vk.DeviceMemory,
//     ) {
//         adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

//         is_disjoint := num_planes > 1

//         vk_check(vk.CreateImage(impl.device, image_create_info, nil, &vk_image), loc = loc)

//         mem_requirements: [VK_MAX_IMAGE_PLANES]vk.MemoryRequirements2
//         for i in 0 ..< VK_MAX_IMAGE_PLANES {
//             mem_requirements[i].sType = .MEMORY_REQUIREMENTS_2
//         }

//         plane_aspects := [VK_MAX_IMAGE_PLANES]vk.ImageAspectFlags{
//             {.PLANE_0},
//             {.PLANE_1},
//             {.PLANE_2},
//         }

//         plane_requirements: [VK_MAX_IMAGE_PLANES]vk.ImagePlaneMemoryRequirementsInfo
//         img_requirements:   [VK_MAX_IMAGE_PLANES]vk.ImageMemoryRequirementsInfo2

//         for p in 0 ..< num_planes {
//             plane_requirements[p] = vk.ImagePlaneMemoryRequirementsInfo{
//                 sType       = .IMAGE_PLANE_MEMORY_REQUIREMENTS_INFO,
//                 planeAspect = plane_aspects[p],
//             }
//             img_requirements[p] = vk.ImageMemoryRequirementsInfo2{
//                 sType  = .IMAGE_MEMORY_REQUIREMENTS_INFO_2,
//                 pNext  = &plane_requirements[p] if is_disjoint else nil,
//                 image  = vk_image,
//             }
//             vk.GetImageMemoryRequirements2(
//                 impl.device, &img_requirements[p], &mem_requirements[p])
//             vk_check(vk_utils_allocate_memory2(
//                 adapter_impl.physical_device,
//                 impl.device,
//                 &mem_requirements[p],
//                 { .DEVICE_LOCAL },
//                 &vk_memory[p],
//             ))
//         }

//         // Bind memory: use plane binding for disjoint, simple binding for single plane
//         bind_plane_info: [VK_MAX_IMAGE_PLANES]vk.BindImagePlaneMemoryInfo
//         bind_info:       [VK_MAX_IMAGE_PLANES]vk.BindImageMemoryInfo
//         for p in 0 ..< num_planes {
//             bind_plane_info[p] = vk.BindImagePlaneMemoryInfo{
//                 sType       = .BIND_IMAGE_PLANE_MEMORY_INFO,
//                 planeAspect = plane_aspects[p],
//             }
//             bind_info[p] = vk.BindImageMemoryInfo{
//                 sType      = .BIND_IMAGE_MEMORY_INFO,
//                 pNext      = &bind_plane_info[p] if (is_disjoint || p > 0) else nil,
//                 image      = vk_image,
//                 memory     = vk_memory[p],
//                 memoryOffset = 0,
//             }
//         }
//         vk_check(vk.BindImageMemory2(impl.device, num_planes, &bind_info[0]))

//         return
//     }

//     vk_image: vk.Image
//     vk_memory: [VK_MAX_IMAGE_PLANES]vk.DeviceMemory
//     vma_allocation: vma.Allocation

//     when USE_VMA {
//         if num_planes == 1 {
//             vma_alloc_info := vma.AllocationCreateInfo{
//                 usage         = .AUTO,
//                 requiredFlags = {.DEVICE_LOCAL},
//             }
//             vk_check(vma.CreateImage(
//                 impl.vma_allocator,
//                 image_create_info,
//                 vma_alloc_info,
//                 &vk_image,
//                 &vma_allocation,
//                 nil,
//             ))
//         } else {
//             vk_image, vk_memory = vk_device_create_texture_manual_alloc(
//                 impl, &image_create_info, num_planes)
//         }
//     } else {
//         vk_image, vk_memory = vk_device_create_texture_manual_alloc(
//             impl, &image_create_info, num_planes)
//     }

//     assert(vk_image != {}, "Failed to create vk.Image", loc)

//     texture_impl := hm_dynamic_add_get(&impl.textures, VK_Texture_Impl{
//         // From descriptor
//         usage                 = desc.usage,
//         dimension             = desc.dimension,
//         size                  = desc.size,
//         format                = desc.format,
//         mip_level_count       = desc.mip_level_count,
//         sample_count          = desc.sample_count,

//         // Backend
//         vk_format_properties  = {},
//         vk_extent             = vk_extent,
//         device                = device,
//         vk_image              = vk_image,
//         vk_usage_flags        = vk_image_usage_flags,
//         vk_type               = vk_image_type,
//         vk_image_format       = vk_format,
//         vk_samples            = vk_samples,
//         vk_image_layout       = .UNDEFINED,
//         num_levels            = desc.mip_level_count,
//         num_layers            = image_create_info.arrayLayers,
//         is_owning_vk_image    = false,
//         is_resolve_attachment = false,
//         is_depth_format       = texture_format_has_depth_aspect(desc.format),
//         is_stencil_format     = texture_format_has_stencil_aspect(desc.format),
//         is_swapchain          = false,
//     }) or_else panic("Failed to allocate texture handle", loc)

//     when USE_VMA {
//         texture_impl.vma_allocation = vma_allocation
//     } else {
//         texture_impl.vk_memory = vk_memory
//     }

//     init_ref(texture_impl)

//     texture_handle := handle_make(texture_impl.handle, impl.handle)
//     texture := handle_to_raw(Texture, texture_handle)

//     return texture
// }

// vk_device_destroy :: proc(device: Device, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_device_get_adapter_info :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     info: Adapter_Info,
//     status: Status,
// ) {
//     unimplemented(loc = loc)
// }

// vk_device_get_features :: proc(
//     device: Device,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := vk_device_get_impl(device, loc)
//     features.features = make([]Feature_Name, len(impl.features), allocator)
//     copy(features.features, impl.features)
//     return
// }

// vk_device_get_features_view :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := vk_device_get_impl(device, loc)
//     features.features = impl.features
//     return
// }

// vk_device_get_limits :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     limits: Limits,
//     status: Status,
// ) {
//     unimplemented(loc = loc)
// }

// vk_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
//     unimplemented(loc = loc)
// }

// vk_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
//     impl := vk_device_get_impl(device, loc)
//     handle_impl, alloc_err := hm_dynamic_add_get(&impl.queues, VK_Queue_Impl{base = impl.queue})
//     assert_contextless(alloc_err == nil, "Failed to allocate Queue", loc)
//     h := handle_make(handle_impl.handle, impl.handle)
//     queue := handle_to_raw(Queue, h)
//     init_ref(handle_impl, loc)
//     return queue
// }

// vk_device_has_feature :: proc(
//     device: Device,
//     feature: Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     if feature == {} {
//         return true
//     }
//     impl := vk_device_get_impl(device, loc)
//     _, found := slice.binary_search(impl.features, feature)
//     return found
// }

// vk_device_pop_error_scope :: proc(
//     device: Device,
//     callback_info: Pop_Error_Scope_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_device_push_error_scope :: proc(device: Device, filter: Error_Filter, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_device_add_ref :: proc(device: Device, loc := #caller_location) {
//     impl := vk_device_get_impl(device, loc)
//     add_ref(impl, loc)
// }

// vk_device_release :: proc(device: Device, loc := #caller_location) {
//     impl := vk_device_get_impl(device, loc)
//     if release_ref(impl, loc) {
//         vk_check(impl.fp.DeviceWaitIdle(impl.device))

//         context.allocator = impl.allocator

//         // Release deferred deletion resources
//         vk_device_wait_deferred_deletion(device)
//         delete(impl.deferred_deletion)

//         delete(impl.transfer_batch.dst_buffers)
//         delete(impl.transfer_batch.temp_resources)

//         vma.DestroyAllocator(impl.vma_allocator)

//         impl.fp.DestroyPipelineLayout(impl.device, impl.empty_pipeline_layout, nil)
//         impl.fp.DestroyDescriptorSetLayout(impl.device, impl.empty_descriptor_set_layout, nil)

//         vk_device_descriptor_allocator_uninit(device)
//         vk_submit_context_uninit(&impl.submitter)

//         impl.fp.DestroyDevice(impl.device, nil)

//         // Check for leaked resources
//         if hm.len(impl.bind_groups) > 0 {
//             log.warnf("Leaked %d bind group(s)", hm.len(impl.bind_groups))
//         }
//         if hm.len(impl.bind_group_layouts) > 0 {
//             log.warnf("Leaked %d bind group layout(s)", hm.len(impl.bind_group_layouts))
//         }
//         if hm.len(impl.buffers) > 0 {
//             log.warnf("Leaked %d buffer(s)", hm.len(impl.buffers))
//         }
//         if hm.len(impl.command_buffers) > 0 {
//             log.warnf("Leaked %d command buffer(s)", hm.len(impl.command_buffers))
//         }
//         if hm.len(impl.command_encoders) > 0 {
//             log.warnf("Leaked %d command encoder(s)", hm.len(impl.command_encoders))
//         }
//         if hm.len(impl.compute_pass_encoders) > 0 {
//             log.warnf("Leaked %d compute pass encoder(s)", hm.len(impl.compute_pass_encoders))
//         }
//         if hm.len(impl.compute_pipelines) > 0 {
//             log.warnf("Leaked %d compute pipeline(s)", hm.len(impl.compute_pipelines))
//         }
//         if hm.len(impl.external_textures) > 0 {
//             log.warnf("Leaked %d external texture(s)", hm.len(impl.external_textures))
//         }
//         if hm.len(impl.pipeline_layouts) > 0 {
//             log.warnf("Leaked %d pipeline layout(s)", hm.len(impl.pipeline_layouts))
//         }
//         if hm.len(impl.query_sets) > 0 {
//             log.warnf("Leaked %d query_set(s)", hm.len(impl.query_sets))
//         }
//         if hm.len(impl.queues) > 0 {
//             log.warnf("Leaked %d queue(s)", hm.len(impl.queues))
//         }
//         if hm.len(impl.render_bundles) > 0 {
//             log.warnf("Leaked %d render bundle(s)", hm.len(impl.render_bundles))
//         }
//         if hm.len(impl.render_bundle_encoders) > 0 {
//             log.warnf("Leaked %d render bundle encoder(s)", hm.len(impl.render_bundle_encoders))
//         }
//         if hm.len(impl.render_pass_encoders) > 0 {
//             log.warnf("Leaked %d render pass encoder(s)", hm.len(impl.render_pass_encoders))
//         }
//         if hm.len(impl.render_pipelines) > 0 {
//             log.warnf("Leaked %d render pipeline(s)", hm.len(impl.render_pipelines))
//         }
//         if hm.len(impl.samplers) > 0 {
//             log.warnf("Leaked %d sampler(s)", hm.len(impl.samplers))
//         }
//         if hm.len(impl.shader_modules) > 0 {
//             log.warnf("Leaked %d shader module(s)", hm.len(impl.shader_modules))
//         }
//         if hm.len(impl.textures) > 0 {
//             log.warnf("Leaked %d texture(s)", hm.len(impl.textures))
//         }
//         if hm.len(impl.texture_views) > 0 {
//             log.warnf("Leaked %d texture view(s)", hm.len(impl.texture_views))
//         }

//         // Free pool of objects
//         hm.dynamic_destroy(&impl.bind_groups)
//         hm.dynamic_destroy(&impl.bind_group_layouts)
//         hm.dynamic_destroy(&impl.buffers)
//         hm.dynamic_destroy(&impl.command_buffers)
//         hm.dynamic_destroy(&impl.command_encoders)
//         hm.dynamic_destroy(&impl.compute_pass_encoders)
//         hm.dynamic_destroy(&impl.compute_pipelines)
//         hm.dynamic_destroy(&impl.external_textures)
//         hm.dynamic_destroy(&impl.pipeline_layouts)
//         hm.dynamic_destroy(&impl.query_sets)
//         hm.dynamic_destroy(&impl.queues)
//         hm.dynamic_destroy(&impl.render_bundles)
//         hm.dynamic_destroy(&impl.render_bundle_encoders)
//         hm.dynamic_destroy(&impl.render_pass_encoders)
//         hm.dynamic_destroy(&impl.render_pipelines)
//         hm.dynamic_destroy(&impl.samplers)
//         hm.dynamic_destroy(&impl.shader_modules)
//         hm.dynamic_destroy(&impl.textures)
//         hm.dynamic_destroy(&impl.texture_views)

//         if len(impl.features) > 0 {
//             delete(impl.features)
//         }

//         vk_adapter_release(impl.adapter)
//         device_pool_remove(&gpu.vk.devices, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of External_Texture
// // -----------------------------------------------------------------------------

// External_Texture_Handle :: distinct hm.Handle64

// VK_External_Texture_Impl :: struct {
//     handle: External_Texture_Handle,
// }

// vk_external_texture_set_label :: proc(
//     external_texture: External_Texture,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_external_texture_add_ref :: proc(external_texture: External_Texture, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_external_texture_release :: proc(external_texture: External_Texture, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Instance
// // -----------------------------------------------------------------------------

// VK_Instance_Impl :: struct {
//     ctx:                          runtime.Context,
//     allocator:                    runtime.Allocator,
//     pending_futures:              map[u64]Future_Impl,
//     future_mtx:                   sync.Mutex,
//     instance:                     vk.Instance,
//     debug_messenger:              vk.DebugUtilsMessengerEXT,
//     flags:                        Instance_Flags,
//     current_future_id:            u64,
//     ref:                          Ref_Count_Type,
//     instance_version:             u32,
//     khr_validation_version:       u32,
//     headless:                     bool,
//     has_mvk_macos_surface:        bool,
//     validation_layers_available:  bool,
//     debug_utils_available:        bool,
//     has_ext_swapchain_colorspace: bool,
// }

// @(require_results)
// vk_instance_get_impl :: #force_inline proc "contextless" (
//     instance: Instance,
//     loc := #caller_location,
// ) -> ^VK_Instance_Impl {
//     assert_contextless(instance != {}, "Invalid instance", loc)
//     return cast(^VK_Instance_Impl)instance
// }

// vk_instance_create_surface :: proc(
//     instance: Instance,
//     descriptor: ^Surface_Descriptor,
//     loc := #caller_location,
// ) -> Surface {
//     impl := vk_instance_get_impl(instance, loc)

//     vk_surface: vk.SurfaceKHR
//     head := descriptor.next_in_chain

//     if impl.headless {
//         ci := vk.HeadlessSurfaceCreateInfoEXT {
//             sType = .HEADLESS_SURFACE_CREATE_INFO_EXT,
//         }
//         vk_check(vk.CreateHeadlessSurfaceEXT(impl.instance, &ci, nil, &vk_surface))
//     } else {
//         for head != nil {
//             #partial switch head.stype {
//             case .Surface_Source_Windows_HWND:
//                 s := cast(^Surface_Source_Windows_HWND)head
//                 assert(s.hwnd != {}, "Invalid Win32_HWND", loc)
//                 ci := vk.Win32SurfaceCreateInfoKHR {
//                     sType     = .WIN32_SURFACE_CREATE_INFO_KHR,
//                     hinstance = auto_cast s.hinstance,
//                     hwnd      = auto_cast s.hwnd,
//                 }
//                 vk_check(vk.CreateWin32SurfaceKHR(impl.instance, &ci, nil, &vk_surface))
//             case .Surface_Source_Android_Native_Window:
//                 unimplemented(loc = loc)
//             case .Surface_Source_Xlib_Window:
//                 s := cast(^Surface_Source_Xlib_Window)head
//                 ci := vk.XlibSurfaceCreateInfoKHR {
//                     sType  = .XLIB_SURFACE_CREATE_INFO_KHR,
//                     dpy    = auto_cast s.display,
//                     window = auto_cast s.window,
//                 }
//                 vk_check(vk.CreateXlibSurfaceKHR(impl.instance, &ci, nil, &vk_surface))
//             case .Surface_Source_Wayland_Surface:
//                 s := cast(^Surface_Source_Wayland_Surface)head
//                 ci := vk.WaylandSurfaceCreateInfoKHR {
//                     sType   = .WAYLAND_SURFACE_CREATE_INFO_KHR,
//                     display = auto_cast s.display,
//                     surface = auto_cast s.surface,
//                 }
//                 vk_check(vk.CreateWaylandSurfaceKHR(impl.instance, &ci, nil, &vk_surface))
//             case .Surface_Source_Metal_Layer:
//                 s := cast(^Surface_Source_Metal_Layer)head
//                 ci := vk.MetalSurfaceCreateInfoEXT {
//                     sType  = .METAL_SURFACE_CREATE_INFO_EXT,
//                     pLayer = auto_cast s.layer,
//                 }
//                 vk_check(vk.CreateMetalSurfaceEXT(impl.instance, &ci, nil, &vk_surface))
//             }
//             head = head.next
//         }
//     }

//     assert(vk_surface != {}, "Failed to create vk.SurfaceKHR", loc)

//     sync.guard(&gpu.vk.mtx)

//     surface_impl := hm_dynamic_add_get(&gpu.vk.surfaces, VK_Surface_Impl{
//         instance  = impl,
//         surface   = vk_surface,
//         allocator = impl.allocator,
//     })
//     surface := transmute(Surface)surface_impl.handle

//     init_ref(surface_impl, loc)
//     vk_instance_add_ref(instance, loc)

//     return surface
// }

// vk_instance_get_wgsl_language_features :: proc(
//     instance: Instance,
//     loc := #caller_location,
// ) -> Supported_WGSL_Language_Features {
//     unimplemented(loc = loc)
// }

// vk_instance_has_wgsl_language_feature :: proc(
//     instance: Instance,
//     feature: WGSL_Language_Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     unimplemented(loc = loc)
// }

// vk_instance_process_events :: proc(instance: Instance, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_instance_is_adapter_suitable :: proc(impl: ^VK_Instance_Impl, pd: vk.PhysicalDevice) -> bool {
//     properties: vk.PhysicalDeviceProperties
//     vk.GetPhysicalDeviceProperties(pd, &properties)

//     if properties.apiVersion < VK_API_VERSION {
//         return false
//     }

//     sync2_features := vk.PhysicalDeviceSynchronization2Features {
//         sType = .PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES,
//     }
//     dynamic_rendering_features := vk.PhysicalDeviceDynamicRenderingFeatures {
//         sType = .PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES,
//         pNext = &sync2_features,
//     }
//     timeline_features := vk.PhysicalDeviceTimelineSemaphoreFeatures {
//         sType = .PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES,
//         pNext = &dynamic_rendering_features,
//     }
//     features2 := vk.PhysicalDeviceFeatures2 {
//         sType = .PHYSICAL_DEVICE_FEATURES_2,
//         pNext = &timeline_features,
//     }
//     vk.GetPhysicalDeviceFeatures2(pd, &features2)

//     if !features2.features.samplerAnisotropy ||
//        !sync2_features.synchronization2 ||
//        !dynamic_rendering_features.dynamicRendering ||
//        !timeline_features.timelineSemaphore {
//         return false
//     }

//     // Check for swapchain support
//     if !impl.headless {
//         REQUIRED_DEVICE_EXTENSIONS :: []cstring{vk.KHR_SWAPCHAIN_EXTENSION_NAME}

//         ext_count: u32
//         res := vk.EnumerateDeviceExtensionProperties(pd, nil, &ext_count, nil)
//         if res  != .SUCCESS || ext_count == 0 {
//             return false
//         }
//         available_exts := make([]vk.ExtensionProperties, ext_count, context.temp_allocator)
//         res = vk.EnumerateDeviceExtensionProperties(pd, nil, &ext_count, raw_data(available_exts))
//         if res != .SUCCESS {
//             return false
//         }
//         for required in REQUIRED_DEVICE_EXTENSIONS {
//             found := false
//             for &ext in available_exts {
//                 if string(required) == byte_arr_str(&ext.extensionName) {
//                     found = true
//                     break
//                 }
//             }
//             if !found {return false}
//         }
//     }

//     return true
// }

// VK_Request_Adapter_Info :: struct {
//     instance:      ^VK_Instance_Impl,
//     options:       Request_Adapter_Options,
//     callback_info: Request_Adapter_Callback_Info,
// }

// vk_instance_request_adapter :: proc(
//     instance: Instance,
//     options: ^Request_Adapter_Options,
//     callback_info: Request_Adapter_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     impl := vk_instance_get_impl(instance, loc)

//     callback :: proc(
//         callback_info: Request_Adapter_Callback_Info,
//         status: Request_Adapter_Status,
//         adapter: Adapter,
//         message: string,
//     ) {
//         callback_info.callback(
//             status,
//             adapter,
//             message,
//             callback_info.userdata1,
//             callback_info.userdata2,
//         )
//     }

//     rate_physical_device :: proc(pd: vk.PhysicalDevice, options: Request_Adapter_Options) -> u32 {
//         ta := context.temp_allocator

//         // Check minimum Vulkan version
//         properties: vk.PhysicalDeviceProperties
//         vk.GetPhysicalDeviceProperties(pd, &properties)

//         // Check if this device has support for the given surface
//         if options.compatible_surface != {} {
//             surface_impl := vk_surface_get_impl(options.compatible_surface)

//             // Check queue family support
//             queue_family_count: u32
//             vk.GetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, nil)
//             if queue_family_count == 0 {return 0}
//             queue_families := make([]vk.QueueFamilyProperties, queue_family_count, ta)
//             vk.GetPhysicalDeviceQueueFamilyProperties(
//                 pd, &queue_family_count, raw_data(queue_families))

//             if vk_get_first_queue_index(queue_families, {.GRAPHICS}) == vk.QUEUE_FAMILY_IGNORED {
//                 return 0
//             }

//             if vk_get_present_queue_index(queue_families, pd, surface_impl.surface) ==
//                vk.QUEUE_FAMILY_IGNORED {
//                 return 0
//             }
//         }

//         score: u32 = 1

//         // Rate the preferred device type
//         if options.force_fallback_adapter {
//             // Force software/CPU renderer: lowest priority device type
//             if properties.deviceType != .CPU {
//                 return 0
//             }
//         } else {
//             #partial switch options.power_preference {
//             case .High_Performance:
//                 #partial switch properties.deviceType {
//                 case .DISCRETE_GPU:   score += 1000
//                 case .INTEGRATED_GPU: score += 100
//                 case .VIRTUAL_GPU:    score += 50
//                 case .CPU:            score += 10
//                 case:                 score += 1
//                 }
//             case .Low_Power:
//                 switch properties.deviceType {
//                 case .INTEGRATED_GPU: score += 1000
//                 case .VIRTUAL_GPU:    score += 100
//                 case .CPU:            score += 50
//                 case .DISCRETE_GPU:   score += 10
//                 case .OTHER:          score += 1
//                 }
//             case:
//                 // No preference, just pick discrete over integrated, no strong bias
//                 if properties.deviceType == .DISCRETE_GPU {score += 100}
//                 if properties.deviceType == .INTEGRATED_GPU {score += 50}
//             }
//         }

//         score += properties.limits.maxImageDimension2D

//         return score
//     }

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta,
//     )

//     device_count: u32
//     res := vk.EnumeratePhysicalDevices(impl.instance, &device_count, nil)
//     if res != .SUCCESS {
//         callback(callback_info, .Unavailable, nil, "vk.EnumeratePhysicalDevices failed")
//         return {}
//     }
//     physical_devices := make([]vk.PhysicalDevice, device_count, ta)
//     res = vk.EnumeratePhysicalDevices(impl.instance, &device_count, raw_data(physical_devices))
//     if res != .SUCCESS {
//         callback(callback_info, .Unavailable, nil, "vk.EnumeratePhysicalDevices failed")
//         return {}
//     }

//     suitable_device: vk.PhysicalDevice
//     best_score: u32

//     opts := options != nil ? options^ : {}

//     for pd in physical_devices {
//         if !vk_instance_is_adapter_suitable(impl, pd) {
//             continue
//         }
//         score := rate_physical_device(pd, opts)
//         if score > best_score {
//             best_score = score
//             suitable_device = pd
//         }
//     }

//     if suitable_device == {} {
//         callback(callback_info, .Unavailable, nil, "No suitable adapter found")
//         return {}
//     }

//     adapter, adapter_ok := vk_create_adapter(impl, suitable_device)
//     if !adapter_ok {
//         callback(callback_info, .Unavailable, nil, "No suitable adapter found")
//         return {}
//     }

//     // Success
//     callback(callback_info, .Success, adapter, "")

//     return {}
// }

// vk_instance_wait_any :: proc(
//     instance: Instance,
//     futures: []^Future_Wait_Info,
//     timeout_ns: u64 = max(u64),
//     loc := #caller_location,
// ) -> Wait_Status {
//     impl := vk_instance_get_impl(instance, loc)

//     sync.guard(&impl.future_mtx)

//     for f in futures {
//         assert(f != {}, "Invalid future", loc)
//         if f.completed {continue}
//         id := f.future.id
//         if pending, ok := impl.pending_futures[id]; ok {
//             pending.resolve(pending.userdata)
//             free(pending.userdata, pending.allocator)
//             delete_key(&impl.pending_futures, id)
//         }
//         f.completed = true
//     }

//     return .Success
// }

// vk_generate_report :: proc(
//     instance: Instance,
//     loc := #caller_location,
// ) -> (
//     report: Global_Report,
// ) {
//     unimplemented(loc = loc)
// }

// vk_instance_enumerate_adapters :: proc(
//     instance: Instance,
//     options: ^Instance_Enumerate_Adapter_Options = nil,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     adapters: []Adapter,
// ) {
//     unimplemented(loc = loc)
// }

// vk_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
//     impl := vk_instance_get_impl(instance, loc)
//     add_ref(impl, loc)
// }

// vk_instance_release :: proc(instance: Instance, loc := #caller_location) {
//     impl := vk_instance_get_impl(instance, loc)
//     if release_ref(impl, loc) {
//         context.allocator = impl.allocator

//         if len(impl.pending_futures) > 0 {
//             log.warnf("Leaked %d pending futures", len(impl.pending_futures))
//             for _, &v in impl.pending_futures {
//                 free(v.userdata, v.allocator)
//             }
//         }

//         delete(impl.pending_futures)

//         if impl.debug_messenger != {} {
//             vk.DestroyDebugUtilsMessengerEXT(impl.instance, impl.debug_messenger, nil)
//         }
//         vk.DestroyInstance(impl.instance, nil)

//         vk_initialization(.Uninit)

//         hm.dynamic_destroy(&gpu.vk.surfaces)
//         hm.dynamic_destroy(&gpu.vk.adapters)

//         free(impl, impl.allocator)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Pipeline_Layout
// // -----------------------------------------------------------------------------

// VK_Pipeline_Layout_Handle :: distinct hm.Handle64

// VK_Pipeline_Layout_Impl :: struct {
//     pipeline_layout: vk.PipelineLayout,
//     handle:          VK_Pipeline_Layout_Handle,
//     ref:             Ref_Count_Type,
// }

// vk_pipeline_layout_get_impl :: #force_inline proc "contextless" (
//     pipeline_layout: Pipeline_Layout,
//     loc := #caller_location,
// ) -> ^VK_Pipeline_Layout_Impl {
//     assert_contextless(pipeline_layout != {}, "Invalid VK_Pipeline_Layout_Handle", loc)
//     h := id_to_handle(pipeline_layout)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     pipeline_layout_handle := VK_Pipeline_Layout_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.pipeline_layouts, pipeline_layout_handle)
// }

// vk_pipeline_layout_set_label :: proc(
//     pipeline_layout: Pipeline_Layout,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Query_Set
// // -----------------------------------------------------------------------------

// Query_Set_Handle :: distinct hm.Handle64

// VK_Query_Set_Impl :: struct {
//     handle: Query_Set_Handle,
// }

// vk_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
//     unimplemented(loc = loc)
// }

// vk_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
//     unimplemented(loc = loc)
// }

// vk_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Queue
// // -----------------------------------------------------------------------------

// VK_Queue_Handle :: distinct hm.Handle64

// VK_Queue_Default_Impl :: struct {
//     device:                Device,
//     graphics_queue:        vk.Queue,
//     compute_queue:         vk.Queue,
//     graphics_family_index: u32,
//     compute_family_index:  u32,
//     transfer_family_index: u32,
// }

// VK_Queue_Impl :: struct {
//     using base: VK_Queue_Default_Impl,
//     handle:     VK_Queue_Handle,
//     ref:        Ref_Count_Type,
// }

// vk_queue_get_impl :: #force_inline proc "contextless" (
//     queue: Queue,
//     loc := #caller_location,
// ) -> ^VK_Queue_Impl {
//     assert_contextless(queue != {}, "Invalid queue", loc)
//     h := id_to_handle(queue)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := VK_Queue_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.queues, map_handle)
// }

// vk_default_queue_init :: proc(
//     device: Device,
//     graphics_family_index: u32,
//     compute_family_index: u32,
//     transfer_family_index: u32,
//     loc := #caller_location,
// ) {
//     device_impl := vk_device_get_impl(device, loc)

//     self := &device_impl.queue

//     self.device = device
//     self.graphics_family_index = graphics_family_index
//     self.compute_family_index = compute_family_index
//     self.transfer_family_index = transfer_family_index

//     // Get graphics queue
//     device_impl.fp.GetDeviceQueue(
//         device_impl.device,
//         graphics_family_index,
//         0,
//         &self.graphics_queue,
//     )

//     // Get compute queue
//     device_impl.fp.GetDeviceQueue(device_impl.device, compute_family_index, 0, &self.compute_queue)

//     // Get transfer queue
//     device_impl.fp.GetDeviceQueue(
//         device_impl.device,
//         transfer_family_index,
//         0,
//         &self.compute_queue,
//     )
// }

// vk_queue_on_submitted_work_done :: proc(
//     queue: Queue,
//     callback_info: Queue_Work_Done_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// VK_Texture_Transition :: struct {
//     texture:           Texture,
//     final_layout:      vk.ImageLayout,
//     subresource_range: vk.ImageSubresourceRange,
// }

// VK_Texture_Transition_Array :: sa.Small_Array(MAX_ATTACHMENT_COUNT, VK_Texture_Transition)

// vk_record_render_pass :: proc(
//     device: Device,
//     cmdbuf: ^VK_Command_Buffer_Impl,
//     rpass: ^Begin_Render_Pass_Cmd,
//     loc := #caller_location,
// ) {
//     device_impl := vk_device_get_impl(device, loc)

//     texture_transitions: VK_Texture_Transition_Array

//     fb_width: u32
//     fb_height: u32

//     vk_color_attachments: [MAX_COLOR_ATTACHMENTS]vk.RenderingAttachmentInfo

//     for &color, i in rpass.color_attachments {
//         assert(color.view != nil, "Invalid color attachment view", rpass.loc)

//         view_impl := vk_texture_view_get_impl(color.view, rpass.loc)
//         texture_impl := vk_texture_get_impl(view_impl.texture, rpass.loc)

//         dim := texture_impl.vk_extent
//         if fb_width > 0 {
//             assert(dim.width == fb_width, "All attachments should have the same width", rpass.loc)
//         }
//         if fb_height > 0 {
//             assert(dim.height == fb_height,
//                 "All attachments should have the same height", rpass.loc)
//         }

//         fb_width = dim.width
//         fb_height = dim.height

//         color_final_transition: vk.ImageLayout =
//             texture_impl.is_swapchain ? .PRESENT_SRC_KHR : .SHADER_READ_ONLY_OPTIMAL

//         // Transition main color attachment
//         vk_texture_transition_to_color_attachment(device_impl, texture_impl, cmdbuf.cmdbuf)
//         sa.push_back(&texture_transitions, VK_Texture_Transition{
//             texture = view_impl.texture,
//             final_layout = color_final_transition,
//             subresource_range = VK_DEFAULT_COLOR_SUBRESOURCE_RANGE,
//         })

//         has_resolve := color.resolve_target != nil
//         vk_resolve_view: vk.ImageView // Optional

//         if has_resolve {
//             resolve_view_impl := vk_texture_view_get_impl(color.resolve_target, rpass.loc)
//             resolve_texture_impl := vk_texture_get_impl(resolve_view_impl.texture, rpass.loc)

//             vk_resolve_view = resolve_view_impl.vk_image_view

//             assert(
//                 resolve_texture_impl.vk_extent.width == fb_width &&
//                 resolve_texture_impl.vk_extent.height == fb_height,
//                 "Resolve target must match framebuffer dimensions", rpass.loc)
//             assert(resolve_texture_impl.vk_samples == {._1},
//                 "Resolve target must be single-sampled", rpass.loc)

//             color_final_transition =
//                 resolve_texture_impl.is_swapchain ? .PRESENT_SRC_KHR : .SHADER_READ_ONLY_OPTIMAL

//             vk_texture_transition_to_color_attachment(
//                 device_impl, resolve_texture_impl, cmdbuf.cmdbuf, rpass.loc)
//             sa.push_back(&texture_transitions, VK_Texture_Transition {
//                 texture = resolve_view_impl.texture,
//                 final_layout = color_final_transition,
//                 subresource_range = VK_DEFAULT_COLOR_SUBRESOURCE_RANGE,
//             })
//         }

//         clear_value := vk.ClearValue {
//             color = {
//                 float32 = {
//                     f32(color.clear_value.r),
//                     f32(color.clear_value.g),
//                     f32(color.clear_value.b),
//                     f32(color.clear_value.a),
//                 },
//             },
//         }

//         samples := texture_impl.vk_samples

//         vk_color_attachments[i] = {
//             sType              = .RENDERING_ATTACHMENT_INFO,
//             imageView          = view_impl.vk_image_view,
//             imageLayout        = .COLOR_ATTACHMENT_OPTIMAL,
//             resolveMode        = has_resolve && ._1 not_in samples ? {.AVERAGE} : {},
//             resolveImageView   = has_resolve ? vk_resolve_view : {},
//             resolveImageLayout = has_resolve ? .COLOR_ATTACHMENT_OPTIMAL : .UNDEFINED,
//             loadOp             = vk_conv_to_attachment_load_op(color.load_op),
//             storeOp            = vk_conv_to_attachment_store_op(color.store_op),
//             clearValue         = clear_value,
//         }
//     }

//     // Depth-stencil attachment
//     has_depth: bool
//     has_stencil: bool
//     vk_depth_attachment: vk.RenderingAttachmentInfo
//     vk_stencil_attachment: vk.RenderingAttachmentInfo

//     if ds, has_ds := rpass.depth_stencil_attachment.?; has_ds {
//         assert(ds.view != nil, "Invalid depth attachment view", rpass.loc)

//         ds_view_impl := vk_texture_view_get_impl(ds.view, rpass.loc)
//         ds_texture_impl := vk_texture_get_impl(ds_view_impl.texture, rpass.loc)

//         has_depth = texture_format_has_depth_aspect(ds_texture_impl.format)
//         has_stencil = texture_format_has_stencil_aspect(ds_texture_impl.format)

//         aspect_mask: vk.ImageAspectFlags
//         if has_depth {aspect_mask += {.DEPTH}}
//         if has_stencil {aspect_mask += {.STENCIL}}

//         ds_subresource_range := vk.ImageSubresourceRange {
//             aspectMask     = aspect_mask,
//             baseMipLevel   = 0,
//             levelCount     = ds_texture_impl.mip_level_count,
//             baseArrayLayer = 0,
//             layerCount     = ds_texture_impl.num_layers,
//         }

//         // Get the correct image layout
//         ds_layout: vk.ImageLayout
//         if ds.depth_read_only && ds.stencil_read_only {
//             ds_layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL
//         } else if ds.depth_read_only {
//             ds_layout = .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL
//         } else if ds.stencil_read_only {
//             ds_layout = .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL
//         } else {
//             ds_layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
//         }

//         ds_final_layout: vk.ImageLayout
//         if has_depth && has_stencil {
//             ds_final_layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
//         } else if has_depth {
//             ds_final_layout = .DEPTH_ATTACHMENT_OPTIMAL
//         } else {
//             ds_final_layout = .STENCIL_ATTACHMENT_OPTIMAL
//         }

//         // Full depth-stencil clear value
//         ds_clear_value := vk.ClearValue {
//             depthStencil = {
//                 depth = has_depth ? ds.depth_clear_value : 0.0,
//                 stencil = has_stencil ? ds.stencil_clear_value : 0,
//             },
//         }

//         // Depth aspect
//         if has_depth {
//             depth_load: vk.AttachmentLoadOp = ds.depth_read_only \
//                 ? .LOAD : vk_conv_to_attachment_load_op(ds.depth_load_op)
//             depth_store: vk.AttachmentStoreOp = ds.depth_read_only \
//                 ? .DONT_CARE : vk_conv_to_attachment_store_op(ds.depth_store_op)

//             vk_depth_attachment = vk.RenderingAttachmentInfo {
//                 sType       = .RENDERING_ATTACHMENT_INFO,
//                 imageView   = ds_view_impl.vk_image_view,
//                 imageLayout = ds_layout,
//                 loadOp      = depth_load,
//                 storeOp     = depth_store,
//                 clearValue  = ds_clear_value,
//             }
//         }

//         // Stencil aspect
//         if has_stencil {
//             stencil_load: vk.AttachmentLoadOp = ds.stencil_read_only \
//                 ? .LOAD : vk_conv_to_attachment_load_op(ds.stencil_load_op)
//             stencil_store: vk.AttachmentStoreOp = ds.stencil_read_only \
//                 ? .DONT_CARE : vk_conv_to_attachment_store_op(ds.stencil_store_op)

//             vk_stencil_attachment = vk.RenderingAttachmentInfo {
//                 sType       = .RENDERING_ATTACHMENT_INFO,
//                 imageView   = ds_view_impl.vk_image_view,
//                 imageLayout = ds_layout,
//                 loadOp      = stencil_load,
//                 storeOp     = stencil_store,
//                 clearValue  = ds_clear_value,
//             }
//         }

//         vk_texture_transition_layout(
//             device_impl, ds_texture_impl, cmdbuf.cmdbuf, ds_layout, ds_subresource_range)
//         sa.push_back(&texture_transitions, VK_Texture_Transition {
//             texture = ds_view_impl.texture,
//             final_layout = ds_final_layout,
//             subresource_range = ds_subresource_range,
//         })

//         dim := ds_texture_impl.vk_extent
//         if fb_width > 0 {
//             assert(dim.width == fb_width, "All attachments should have the same width", rpass.loc)
//         }
//         if fb_height > 0 {
//             assert(dim.height == fb_height,
//                 "All attachments should have the same height", rpass.loc)
//         }

//         fb_width = dim.width
//         fb_height = dim.height
//     }

//     assert(fb_width != 0, "Invalid framebuffer width", rpass.loc)
//     assert(fb_height != 0, "Invalid framebuffer height", rpass.loc)

//     render_area := vk.Rect2D {
//         offset = {0, 0},
//         extent = {fb_width, fb_height},
//     }

//     color_attachments_len := u32(len(rpass.color_attachments))

//     rendering_info := vk.RenderingInfo {
//         sType                = .RENDERING_INFO,
//         renderArea           = render_area,
//         layerCount           = 1,
//         viewMask             = 0,
//         colorAttachmentCount = color_attachments_len,
//         pColorAttachments    = raw_data(vk_color_attachments[:color_attachments_len]),
//         pDepthAttachment     = has_depth ? &vk_depth_attachment : nil,
//         pStencilAttachment   = has_stencil ? &vk_stencil_attachment : nil,
//     }

//     // Begin rendering
//     device_impl.fp.CmdBeginRendering(cmdbuf.cmdbuf, &rendering_info)

//     // Set default dynamic state for this pass
//     vk_render_pass_encoder_set_viewport_impl(
//         cmdbuf.cmdbuf, 0.0, 0.0, f32(fb_width), f32(fb_height), 0.0, 1.0)
//     vk_render_pass_encoder_set_scissor_rect_impl(cmdbuf.cmdbuf, 0, 0, fb_width, fb_height)
//     vk_render_pass_encoder_set_blend_constant_impl(cmdbuf.cmdbuf, {1.0, 1.0, 1.0, 1.0})
//     vk_render_pass_encoder_set_stencil_reference_impl(cmdbuf.cmdbuf, 0)

//     active_pipeline: Render_Pipeline

//     // Record render pass commands
//     LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
//         #partial switch &cmd in curr {
//         case Set_Bind_Group_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Set_Render_Pipeline_Cmd:
//             pipeline_impl := vk_render_pipeline_get_impl(cmd.pipeline, cmd.loc)
//             device_impl.fp.CmdBindPipeline(cmdbuf.cmdbuf, .GRAPHICS, pipeline_impl.pipeline)
//             active_pipeline = cmd.pipeline

//         case Set_Index_Buffer_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Set_Vertex_Buffer_Cmd:
//             buffer_impl := vk_buffer_get_impl(cmd.buffer, cmd.loc)

//             vk_offset := vk.DeviceSize(cmd.offset)
//             vk_size: vk.DeviceSize

//             if cmd.size == WHOLE_SIZE {
//                 vk_size = buffer_impl.vk_size - vk_offset
//             } else {
//                 vk_size = vk.DeviceSize(cmd.size)
//             }

//             assert(vk_offset + vk_size <= buffer_impl.vk_size,
//                 "Vertex buffer offset + size exceeds requested buffer size", cmd.loc)

//             if device_impl.fp.CmdBindVertexBuffers2 != nil {
//                 device_impl.fp.CmdBindVertexBuffers2(
//                     cmdbuf.cmdbuf, cmd.slot, 1, &buffer_impl.vk_buffer, &vk_offset, &vk_size, nil)
//             } else {
//                 // Legacy path: vkCmdBindVertexBuffers (core 1.0) has no size/stride
//                 // parameters, size-based bounds checking above is the only place
//                 // that constraint is enforced when on this path; stride must be
//                 // baked into the bound pipeline's VkVertexInputBindingDescription
//                 device_impl.fp.CmdBindVertexBuffers(
//                     cmdbuf.cmdbuf, cmd.slot, 1, &buffer_impl.vk_buffer, &vk_offset)
//             }

//         case Set_Blend_Constant_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Set_Stencil_Reference_Cmd:
//             device_impl.fp.CmdSetStencilReference(
//                 cmdbuf.cmdbuf, vk.StencilFaceFlags_FRONT_AND_BACK, cmd.reference)

//         case Set_Viewport_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Set_Scissor_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Draw_Cmd:
//             device_impl.fp.CmdDraw(
//                 cmdbuf.cmdbuf,
//                 cmd.vertex_count,
//                 cmd.instance_count,
//                 cmd.first_vertex,
//                 cmd.first_instance,
//             )

//         case Draw_Indexed_Cmd:
//             device_impl.fp.CmdDrawIndexed(
//                 cmdbuf.cmdbuf,
//                 cmd.index_count,
//                 cmd.instance_count,
//                 cmd.first_index,
//                 i32(cmd.base_vertex),
//                 cmd.first_instance,
//             )

//         case Draw_Mesh_Tasks_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Draw_Indirect_Cmd:
//             unimplemented(loc = rpass.loc)

//         case Multi_Draw_Indirect_Count_Cmd:
//             unimplemented(loc = rpass.loc)

//         case:
//             break LOOP
//         }
//     }

//     device_impl.fp.CmdEndRendering(cmdbuf.cmdbuf)

//     deferred_transitions_slice := sa.slice(&texture_transitions)
//     for &t in deferred_transitions_slice {
//         texture_impl := vk_texture_get_impl(t.texture, rpass.loc)
//         vk_texture_transition_layout(
//             device_impl,
//             texture_impl,
//             cmdbuf.cmdbuf,
//             t.final_layout,
//             t.subresource_range,
//         )
//     }
// }

// vk_record_commands :: proc(
//     device: Device,
//     cmdbuf: ^VK_Command_Buffer_Impl,
//     loc := #caller_location,
// ) {
//     device_impl := vk_device_get_impl(device, loc)

//     LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
//         #partial switch &cmd in curr {
//         case Begin_Render_Pass_Cmd:
//             vk_record_render_pass(device, cmdbuf, &cmd, loc)

//         case Begin_Compute_Pass_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Set_Immediate_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Push_Debug_Group_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Pop_Debug_Group_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Insert_Debug_Marker_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Write_Timestamp_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Begin_Occlusion_Query_Cmd:
//             unimplemented(loc = cmd.loc)

//         case End_Occlusion_Query_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Begin_Pipeline_Statistics_Query_Cmd:
//             unimplemented(loc = cmd.loc)

//         case End_Pipeline_Statistics_Query_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Execute_Bundle_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Copy_Buffer_To_Buffer_Cmd:
//             src_impl := vk_buffer_get_impl(cmd.src, cmd.loc)
//             dst_impl := vk_buffer_get_impl(cmd.dst, cmd.loc)

//             if device_impl.fp.CmdCopyBuffer2 != nil {
//                 copy_region := vk.BufferCopy2 {
//                     sType     = .BUFFER_COPY_2,
//                     srcOffset = vk.DeviceSize(cmd.src_offset),
//                     dstOffset = vk.DeviceSize(cmd.dst_offset),
//                     size      = vk.DeviceSize(cmd.size),
//                 }

//                 copy_info := vk.CopyBufferInfo2 {
//                     sType       = .COPY_BUFFER_INFO_2,
//                     srcBuffer   = src_impl.vk_buffer,
//                     dstBuffer   = dst_impl.vk_buffer,
//                     regionCount = 1,
//                     pRegions    = &copy_region,
//                 }

//                 device_impl.fp.CmdCopyBuffer2(cmdbuf.cmdbuf, &copy_info)
//             } else {
//                 // Legacy path for devices without VK_KHR_copy_commands2
//                 copy_region := vk.BufferCopy {
//                     srcOffset = vk.DeviceSize(cmd.src_offset),
//                     dstOffset = vk.DeviceSize(cmd.dst_offset),
//                     size      = vk.DeviceSize(cmd.size),
//                 }

//                 vk.CmdCopyBuffer(
//                     cmdbuf.cmdbuf,
//                     src_impl.vk_buffer,
//                     dst_impl.vk_buffer,
//                     1,
//                     &copy_region,
//                 )
//             }

//         case Copy_Buffer_To_Texture_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Copy_Texture_To_Buffer_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Copy_Texture_To_Texture_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Clear_Buffer_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Clear_Texture_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Build_Acceleration_Structures_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Resolve_Query_Set_Cmd:
//             unimplemented(loc = cmd.loc)

//         case Transition_Buffer_Cmd:
//             buffer_impl := vk_buffer_get_impl(cmd.buffer, cmd.loc)

//             vk_command_buffer_barrier(
//                 device_impl,
//                 command_buffer = cmdbuf.cmdbuf,
//                 buffer = buffer_impl.vk_buffer,
//                 state_from = cmd.state_from,
//                 state_to = cmd.state_to,
//                 loc = cmd.loc,
//             )

//         case Transition_Texture_Cmd:
//             unimplemented(loc = cmd.loc)
//         }
//     }
// }

// vk_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
//     impl := vk_queue_get_impl(queue, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     vk_transfer_batch_flush(&device_impl.transfer_batch, impl.device, loc)

//     for cmdbuf, i in commands {
//         cmdbuf_wrapper := vk_command_buffer_get_impl(cmdbuf, loc)
//         cmdbuf_impl := &device_impl.submitter.buffers[cmdbuf_wrapper.buffer_index]

//         vk_record_commands(impl.device, cmdbuf_impl, loc)
//         device_impl.fp.EndCommandBuffer(cmdbuf_impl.cmdbuf)

//         is_last := i == len(commands) - 1
//         vk_submit_context_submit(
//             &device_impl.submitter,
//             cmdbuf_impl,
//             is_last_submit = is_last,
//             loc = loc,
//         )
//     }
// }

// vk_queue_write_buffer :: proc(
//     queue: Queue,
//     buffer: Buffer,
//     bufferOffset: u64,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_queue_write_texture :: proc(
//     queue: Queue,
//     destination: ^Texel_Copy_Texture_Info,
//     data: rawptr,
//     dataSize: uint,
//     dataLayout: ^Texel_Copy_Buffer_Layout,
//     writeSize: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_queue_submit_for_index :: proc(
//     queue: Queue,
//     commands: []Command_Buffer,
//     loc := #caller_location,
// ) -> Submission_Index {
//     unimplemented(loc = loc)
// }

// vk_queue_get_timestamp_period :: proc(queue: Queue, loc := #caller_location) -> f32 {
//     unimplemented(loc = loc)
// }

// vk_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
//     impl := vk_queue_get_impl(queue, loc)
//     add_ref(impl, loc)
// }

// vk_queue_release :: proc(queue: Queue, loc := #caller_location) {
//     impl := vk_queue_get_impl(queue, loc)
//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.queues, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Bundle
// // -----------------------------------------------------------------------------

// Render_Bundle_Handle :: distinct hm.Handle64

// VK_Render_Bundle_Impl :: struct {
//     handle: Render_Bundle_Handle,
// }

// vk_render_bundle_set_label :: proc(
//     render_bundle: Render_Bundle,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Bundle_Encoder
// // -----------------------------------------------------------------------------

// Render_Bundle_Encoder_Handle :: distinct hm.Handle64

// VK_Render_Bundle_Encoder_Impl :: struct {
//     handle: Render_Bundle_Encoder_Handle,
// }

// vk_render_bundle_encoder_draw :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     vertex_count: u32,
//     instance_count: u32,
//     first_vertex: u32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_draw_indexed :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     index_count: u32,
//     instance_count: u32,
//     first_index: u32,
//     base_vertex: i32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_draw_indexed_indirect :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_draw_indirect :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_finish :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     descriptor: ^Render_Bundle_Descriptor,
//     loc := #caller_location,
// ) -> Render_Bundle {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_insert_debug_marker :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_pop_debug_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_push_debug_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_bind_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_immediates :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_index_buffer :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     buffer: Buffer,
//     format: Index_Format,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_label :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_pipeline :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_set_vertex_buffer :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     slot: u32,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_add_ref :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_bundle_encoder_release :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Pass_Encoder
// // -----------------------------------------------------------------------------

// VK_Render_Pass_Encoder_Handle :: distinct hm.Handle64

// VK_Render_Pass_Encoder_Impl :: struct {
//     device:       Device,
//     encoder:      Command_Encoder,
//     handle:       VK_Render_Pass_Encoder_Handle,
//     buffer_index: u32,
//     ref:          Ref_Count_Type,
//     is_rendering: bool,
// }

// vk_render_pass_encoder_get_impl :: #force_inline proc "contextless" (
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) -> ^VK_Render_Pass_Encoder_Impl {
//     assert_contextless(render_pass_encoder != {}, "Invalid Render_Pass_Encoder", loc)
//     h := id_to_handle(render_pass_encoder)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     render_pass_encoder_handle := VK_Render_Pass_Encoder_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.render_pass_encoders, render_pass_encoder_handle)
// }

// vk_render_pass_encoder_begin_occlusion_query :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     query_index: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_draw :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     vertex_count: u32,
//     instance_count: u32,
//     first_vertex: u32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     device_impl := vk_device_get_impl(impl.device, loc)
//     cmdbuf_impl := &device_impl.submitter.buffers[impl.buffer_index]

//     cmd := command_allocator_allocate(&cmdbuf_impl.commands, Draw_Cmd, loc)

//     cmd.vertex_count = vertex_count
//     cmd.instance_count = instance_count
//     cmd.first_vertex = first_vertex
//     cmd.first_instance = first_instance
// }

// vk_render_pass_encoder_draw_indexed :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     index_count: u32,
//     instance_count: u32,
//     first_index: u32,
//     base_vertex: i32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_draw_indexed_indirect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_draw_indirect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_end :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)
//     impl.is_rendering = false

//     encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)
//     encoder_impl.is_rendering = false
// }

// vk_render_pass_encoder_end_occlusion_query :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_execute_bundles :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     bundles: []Render_Bundle,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_insert_debug_marker :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_pop_debug_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_push_debug_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_bind_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_blend_constant_impl :: proc(
//     vk_cmdbuf: vk.CommandBuffer,
//     color: Color,
//     loc := #caller_location,
// ) {
//     color := [4]f32{f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
//     vk.CmdSetBlendConstants(vk_cmdbuf, &color)
// }

// vk_render_pass_encoder_set_blend_constant :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     color: Color,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_immediates :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_index_buffer :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     buffer: Buffer,
//     format: Index_Format,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_label :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_pipeline :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     cmdbuf_impl := &device_impl.submitter.buffers[impl.buffer_index]

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     cmd := command_allocator_allocate(&cmdbuf_impl.commands, Set_Render_Pipeline_Cmd, loc)

//     // cmd.render_pass = render_pass
//     cmd.pipeline = pipeline
// }

// vk_render_pass_encoder_set_scissor_rect_impl :: proc(
//     cmdbuf: vk.CommandBuffer,
//     x: u32,
//     y: u32,
//     width: u32,
//     height: u32,
//     loc := #caller_location,
// ) {
//     scissor := vk.Rect2D {
//         offset = {i32(x), i32(y)},
//         extent = {width, height},
//     }
//     vk.CmdSetScissor(cmdbuf, 0, 1, &scissor)
// }

// vk_render_pass_encoder_set_scissor_rect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     x: u32,
//     y: u32,
//     width: u32,
//     height: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_set_stencil_reference_impl :: proc(
//     cmdbuf: vk.CommandBuffer,
//     reference: u32,
//     loc := #caller_location,
// ) {
//     vk.CmdSetStencilReference(cmdbuf, {.FRONT, .BACK}, reference)
// }

// vk_render_pass_encoder_set_stencil_reference :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     reference: u32,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)

//     cmdbuf_impl := &device_impl.submitter.buffers[impl.buffer_index]

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     cmd := command_allocator_allocate(&cmdbuf_impl.commands, Set_Stencil_Reference_Cmd, loc)

//     // cmd.render_pass = render_pass_encoder
//     cmd.reference = reference
// }

// vk_render_pass_encoder_set_vertex_buffer :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     slot: u32,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     device_impl := vk_device_get_impl(impl.device, loc)
//     cmdbuf_impl := &device_impl.submitter.buffers[impl.buffer_index]

//     cmd := command_allocator_allocate(&cmdbuf_impl.commands, Set_Vertex_Buffer_Cmd, loc)

//     cmd.slot = slot
//     cmd.buffer = buffer
//     cmd.offset = offset
//     cmd.size = size
// }

// vk_render_pass_encoder_set_viewport_impl :: proc(
//     cmdbuf: vk.CommandBuffer,
//     x: f32,
//     y: f32,
//     width: f32,
//     height: f32,
//     min_depth: f32,
//     max_depth: f32,
//     loc := #caller_location,
// ) {
//     // https://www.saschawillems.de/blog/2019/03/29/flipping-the-vulkan-viewport/
//     vp := vk.Viewport {
//         x        = x,
//         y        = height - y,
//         width    = width,
//         height   = -height,
//         minDepth = min_depth,
//         maxDepth = max_depth,
//     }
//     vk.CmdSetViewport(cmdbuf, 0, 1, &vp)
// }

// vk_render_pass_encoder_set_viewport :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     x: f32,
//     y: f32,
//     width: f32,
//     height: f32,
//     min_depth: f32,
//     max_depth: f32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pass_encoder_add_ref :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)
//     add_ref(impl, loc)
// }

// vk_render_pass_encoder_release :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     impl := vk_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering == false, "Releasing render pass while rendering", loc)

//     encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)
//     assert(encoder_impl.is_encoding == false, "Releasing render pass while encoding", loc)

//     if release_ref(impl) {
//         vk_command_encoder_release(impl.encoder, loc)
//         device_impl := vk_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.render_pass_encoders, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Pipeline
// // -----------------------------------------------------------------------------

// VK_Render_Pipeline_Handle :: distinct hm.Handle64

// VK_Render_Pipeline_Impl :: struct {
//     device:          Device,
//     layout:          Pipeline_Layout,
//     pipeline:        vk.Pipeline,
//     handle:          VK_Render_Pipeline_Handle,
//     ref:             Ref_Count_Type,
//     is_empty_layout: bool,
// }

// vk_render_pipeline_get_impl :: #force_inline proc "contextless" (
//     render_pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) -> ^VK_Render_Pipeline_Impl {
//     assert_contextless(render_pipeline != {}, "Invalid VK_Render_Pipeline_Handle", loc)
//     h := id_to_handle(render_pipeline)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     render_pipeline_handle := VK_Render_Pipeline_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.render_pipelines, render_pipeline_handle)
// }

// vk_render_pipeline_get_bind_group_layout :: proc(
//     render_pipeline: Render_Pipeline,
//     group_index: u32,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     unimplemented(loc = loc)
// }

// vk_render_pipeline_set_label :: proc(
//     render_pipeline: Render_Pipeline,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
//     impl := vk_render_pipeline_get_impl(render_pipeline, loc)
//     add_ref(impl, loc)
// }

// vk_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
//     impl := vk_render_pipeline_get_impl(render_pipeline, loc)
//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         if !impl.is_empty_layout {
//             vk_pipeline_layout_release(impl.layout)
//         }
//         vk_device_add_deferred_resource(impl.device, impl.pipeline)
//         hm.remove(&device_impl.render_pipelines, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Sampler
// // -----------------------------------------------------------------------------

// VK_Sampler_Handle :: distinct hm.Handle64

// VK_Sampler_Impl :: struct {
//     device:  Device,
//     sampler: vk.Sampler,
//     handle:  VK_Sampler_Handle,
//     ref:     Ref_Count_Type,
// }

// vk_sampler_get_impl :: #force_inline proc "contextless" (
//     sampler: Sampler,
//     loc := #caller_location,
// ) -> ^VK_Sampler_Impl {
//     assert_contextless(sampler != {}, "Invalid Sampler", loc)
//     h := id_to_handle(sampler)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := VK_Sampler_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.samplers, map_handle)
// }

// vk_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
//     impl := vk_sampler_get_impl(sampler, loc)
//     add_ref(impl, loc)
// }

// vk_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
//     impl := vk_sampler_get_impl(sampler, loc)
//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         vk_device_add_deferred_resource(impl.device, impl.sampler)
//         hm.remove(&device_impl.samplers, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Shader_Module
// // -----------------------------------------------------------------------------

// VK_Shader_Module_Handle :: distinct hm.Handle64

// VK_Shader_Module_Impl :: struct {
//     device:        Device,
//     shader_module: vk.ShaderModule,
//     handle:        VK_Shader_Module_Handle,
//     ref:           Ref_Count_Type,
// }

// vk_shader_module_get_impl :: #force_inline proc "contextless" (
//     shader_module: Shader_Module,
//     loc := #caller_location,
// ) -> ^VK_Shader_Module_Impl {
//     assert_contextless(shader_module != {}, "Invalid VK_Shader_Module_Handle", loc)
//     h := id_to_handle(shader_module)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     shader_module_handle := VK_Shader_Module_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.shader_modules, shader_module_handle)
// }

// vk_shader_module_get_compilation_info :: proc(
//     shader_module: Shader_Module,
//     callback_info: Compilation_Info_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// vk_shader_module_set_label :: proc(
//     shader_module: Shader_Module,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
//     impl := vk_shader_module_get_impl(shader_module, loc)
//     add_ref(impl, loc)
// }

// vk_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
//     impl := vk_shader_module_get_impl(shader_module, loc)
//     if release_ref(impl) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         device_impl.fp.DestroyShaderModule(device_impl.device, impl.shader_module, nil)
//         hm.remove(&device_impl.shader_modules, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_Features
// // -----------------------------------------------------------------------------

// vk_supported_features_free_members :: proc(
//     supportedFeatures: Supported_Features,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     delete(supportedFeatures.features, allocator)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_Instance_Features
// // -----------------------------------------------------------------------------

// vk_supported_instance_features_free_members :: proc(
//     supportedInstanceFeatures: Supported_Instance_Features,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     delete(supportedInstanceFeatures.features, allocator)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_WGSL_Language_Features
// // -----------------------------------------------------------------------------

// vk_supported_wgsl_language_features_free_members :: proc(
//     supportedWGSLLanguageFeatures: Supported_WGSL_Language_Features,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Surface
// // -----------------------------------------------------------------------------

// VK_MAX_SWAPCHAIN_IMAGES :: 16

// VK_Surface_Handle :: distinct hm.Handle64

// VK_Surface_Impl :: struct {
//     swapchain_textures:   [VK_MAX_SWAPCHAIN_IMAGES]Texture,
//     swapchain_views:      [VK_MAX_SWAPCHAIN_IMAGES]Texture_View,
//     acquire_semaphore:    [VK_MAX_SWAPCHAIN_IMAGES]vk.Semaphore,
//     present_semaphore:    [VK_MAX_SWAPCHAIN_IMAGES]vk.Semaphore,
//     present_fence:        [VK_MAX_SWAPCHAIN_IMAGES]vk.Fence,
//     acquire_fence:        [VK_MAX_SWAPCHAIN_IMAGES]vk.Fence,
//     timeline_wait_values: [VK_MAX_SWAPCHAIN_IMAGES]u64,
//     allocator:            runtime.Allocator,
//     config:               Surface_Configuration,
//     instance:             ^VK_Instance_Impl,
//     device:               Device,
//     swapchain:            vk.SwapchainKHR,
//     surface:              vk.SurfaceKHR,
//     surface_format:       vk.SurfaceFormatKHR,
//     timeline_semaphore:   vk.Semaphore,
//     handle:               VK_Surface_Handle,
//     current_frame_index:  u64, // [0:+inf)
//     num_swapchain_images: u32,
//     current_image_index:  u32, // [0:num_swapchain_images)
//     ref:                  Ref_Count_Type,
//     get_next_image:       bool,
// }

// @(require_results)
// vk_surface_get_impl :: #force_inline proc "contextless" (
//     surface: Surface,
//     loc := #caller_location,
// ) -> ^VK_Surface_Impl {
//     assert_contextless(surface != {}, "Invalid Instance", loc)
//     h := transmute(VK_Surface_Handle)surface
//     return hm.get(&gpu.vk.surfaces, h)
// }

// vk_surface_configure :: proc(
//     surface: Surface,
//     config: ^Surface_Configuration,
//     loc := #caller_location,
// ) {
//     assert(config != {}, "Invalid configuration", loc)
//     assert(config.device != {}, "Invalid device", loc)
//     assert(config.width > 0, "Invalid width", loc)
//     assert(config.height > 0, "Invalid height", loc)

//     impl := vk_surface_get_impl(surface, loc)
//     device_impl := vk_device_get_impl(config.device, loc)
//     adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

//     // Set current configuration
//     impl.config = config^

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta,
//     )

//     caps, caps_status := surface_get_capabilities(surface, Adapter(device_impl.adapter), ta)
//     assert(caps_status == .Success, "Unsupported surface with this device", loc)
//     assert(slice.contains(caps.formats, config.format), "Unsupported surface format", loc)

//     surface_capabilities: vk.SurfaceCapabilitiesKHR
//     vk_check(
//         vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
//             adapter_impl.physical_device,
//             impl.surface,
//             &surface_capabilities,
//         ),
//     )

//     find_extent :: proc(
//         capabilities: vk.SurfaceCapabilitiesKHR,
//         desired_width, desired_height: u32,
//     ) -> vk.Extent2D {
//         if capabilities.currentExtent.width != max(u32) {
//             return capabilities.currentExtent
//         }

//         actual_extent: vk.Extent2D = {desired_width, desired_height}

//         actual_extent.width = max(
//             capabilities.minImageExtent.width,
//             min(capabilities.maxImageExtent.width, actual_extent.width),
//         )
//         actual_extent.height = max(
//             capabilities.minImageExtent.height,
//             min(capabilities.maxImageExtent.height, actual_extent.height),
//         )

//         return actual_extent
//     }

//     // Get the user's preference
//     config_extras := chain_get(
//         Surface_Configuration_Extras,
//         config.next_in_chain,
//         .Surface_Configuration_Extras,
//     )

//     desired_max_frame_latency: u32 = 2
//     if config_extras != nil {
//         desired_max_frame_latency = config_extras.desired_maximum_frame_latency
//     }

//     desired_swapchain_images := desired_max_frame_latency + 1

//     // Respect the surface's hard minimum, but otherwise use exactly
//     // what the latency preference asks for. No unconditional +1.
//     min_image_count := max(desired_swapchain_images, surface_capabilities.minImageCount)

//     // Respect the surface's hard maximum (0 means no upper limit).
//     if surface_capabilities.maxImageCount > 0 {
//         min_image_count = min(min_image_count, surface_capabilities.maxImageCount)
//     }

//     // Set desired extent
//     image_extent := find_extent(surface_capabilities, config.width, config.height)

//     // Set image usage flags
//     vk_image_usage_flags := vk_conv_to_image_usage_flags(config.usage, config.format)

//     // Set desired format and colorspace
//     vk_desired_format := vk.SurfaceFormatKHR {
//         format     = vk_conv_to_format(adapter_impl.caps, config.format),
//         colorSpace = .SRGB_NONLINEAR,
//     }

//     // Set composite alpha flags
//     vk_composite_alpha := vk_conv_to_composite_alpha_flags(config.alpha_mode)

//     // Set desired present mode
//     vk_present_mode := vk_conv_to_present_mode(config.present_mode)

//     swapchain_create_info := vk.SwapchainCreateInfoKHR {
//         sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
//         flags                 = {},
//         surface               = impl.surface,
//         minImageCount         = min_image_count,
//         imageFormat           = vk_desired_format.format,
//         imageColorSpace       = vk_desired_format.colorSpace,
//         imageExtent           = image_extent,
//         imageArrayLayers      = 1,
//         imageUsage            = vk_image_usage_flags,
//         imageSharingMode      = .EXCLUSIVE,
//         queueFamilyIndexCount = {},
//         pQueueFamilyIndices   = {},
//         preTransform          = surface_capabilities.currentTransform,
//         compositeAlpha        = vk_composite_alpha,
//         presentMode           = vk_present_mode,
//         clipped               = true,
//         oldSwapchain          = {},
//     }

//     // Set device reference or set old swapchain when reconfiguring
//     if impl.swapchain == {} {
//         // Set the device used to configure this surface
//         impl.device = config.device

//         // Since this is the initial configuration of the surface,
//         // the device must remain alive for the entire lifetime of the surface.
//         vk_device_add_ref(impl.device)
//     } else {
//         swapchain_create_info.oldSwapchain = impl.swapchain
//     }

//     // Create the swapchain
//     vk_swapchain: vk.SwapchainKHR
//     vk_check(vk.CreateSwapchainKHR(device_impl.device, &swapchain_create_info, nil, &vk_swapchain))
//     if impl.swapchain != {} {
//         vk_swapchain_destroy_resources(impl, loc)
//     }
//     impl.swapchain = vk_swapchain

//     get_images :: proc(
//         device: vk.Device,
//         swapchain: vk.SwapchainKHR,
//         max_images: u32 = 0,
//     ) -> (
//         images: []vk.Image,
//     ) {
//         // Get the number of images in the swapchain
//         image_count: u32 = 0
//         vk_check(vk.GetSwapchainImagesKHR(device, swapchain, &image_count, nil))

//         // Limit the number of images if `max_images` is specified
//         if max_images > 0 && image_count > max_images {
//             image_count = max_images
//         }

//         // Allocate memory for the images
//         images = make([]vk.Image, image_count, context.temp_allocator)

//         // Retrieve the actual images
//         vk_check(vk.GetSwapchainImagesKHR(device, swapchain, &image_count, raw_data(images)))

//         return
//     }

//     // Get the swapchain images
//     swapchain_images := get_images(device_impl.device, impl.swapchain)
//     impl.num_swapchain_images = u32(len(swapchain_images))
//     assert(impl.num_swapchain_images > 0, loc = loc)

//     // Driver may have given us more than requested; clamp frames in flight
//     // to what we actually have minus one presenter image.
//     max_frames_in_flight := min(desired_max_frame_latency, impl.num_swapchain_images - 1)

//     impl.timeline_semaphore = vk_utils_create_semaphore_timeline(
//         device_impl, max_frames_in_flight, "Semaphore: timeline_semaphore")

//     for vk_image, i in swapchain_images {
//         impl.acquire_semaphore[i] =
//             vk_utils_create_semaphore(device_impl, "Semaphore: swapchain-acquire", loc)
//         impl.present_semaphore[i] =
//             vk_utils_create_semaphore(device_impl, "Semaphore: swapchain-present", loc)

//         if !adapter_impl.caps.swapchain_maintenance1.swapchainMaintenance1 {
//             impl.acquire_fence[i] = vk_utils_create_fence(
//                 device_impl, fmt.tprintf("Fence: swapchain %d", i), signaled = true)
//         }

//         texture_impl := hm_dynamic_add_get(&device_impl.textures, VK_Texture_Impl{
//             usage              = config.usage,
//             dimension          = .D2,
//             size               = {config.width, config.height, 1},
//             format             = config.format,
//             mip_level_count    = 1,
//             sample_count       = 1,
//             vk_extent          = {config.width, config.height, 1},
//             device             = config.device,
//             surface            = surface,
//             vk_image           = vk_image,
//             vk_usage_flags     = vk_image_usage_flags,
//             vk_type            = .D2,
//             vk_image_format    = vk_desired_format.format,
//             vk_samples         = {._1},
//             vk_image_layout    = .UNDEFINED,
//             num_levels         = 1,
//             num_layers         = 1,
//             is_owning_vk_image = true,
//             is_swapchain       = true,
//         })

//         texture_handle := handle_make(texture_impl.handle, device_impl.handle)

//         vk_utils_set_debug_object_name(
//             device_impl, .IMAGE, vk_image, fmt.tprintf("Image: swapchain %d", i))

//         vk_image_view := vk_texture_create_image_view(texture_impl,
//             type        = .D2,
//             format      = vk_desired_format.format,
//             aspect_mask = {.COLOR},
//             base_level  = 0,
//         )

//         view_impl := hm_dynamic_add_get(&device_impl.texture_views, VK_Texture_View_Impl {
//             device            = config.device,
//             texture           = handle_to_raw(Texture, texture_handle),
//             vk_image_view     = vk_image_view,
//             format            = config.format,
//             dimension         = .D2,
//             aspect            = .All,
//             mip_level_count   = 1,
//             array_layer_count = 1,
//             is_owning_vk_view = true,
//             is_swapchain      = true,
//         })

//         vciew_handle := handle_make(view_impl.handle, device_impl.handle)

//         vk_utils_set_debug_object_name(
//             device_impl, .IMAGE_VIEW, vk_image_view, fmt.tprintf("ImageView: swapchain %d", i))

//         impl.swapchain_textures[i] = handle_to_raw(Texture, texture_handle)
//         impl.swapchain_views[i] = handle_to_raw(Texture_View, vciew_handle)

//         texture_impl.texture_view = impl.swapchain_views[i]
//     }

//     impl.get_next_image = true
// }

// vk_surface_get_capabilities :: proc(
//     surface: Surface,
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     caps: Surface_Capabilities,
//     status: Status,
// ) {
//     impl := vk_surface_get_impl(surface, loc)
//     adapter_impl := vk_adapter_get_impl(adapter, loc)

//     // Alias to the temporary allocator
//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = allocator == ta || impl.allocator == ta)

//     physical_device := adapter_impl.physical_device

//     // Query supported formats
//     format_count: u32
//     res := vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, impl.surface, &format_count, nil)
//     if res != .SUCCESS || format_count == 0 {
//         return {}, .Error
//     }

//     vk_formats := make([]vk.SurfaceFormatKHR, format_count, ta)
//     res = vk.GetPhysicalDeviceSurfaceFormatsKHR(
//         physical_device, impl.surface, &format_count, raw_data(vk_formats))
//     if res != .SUCCESS {
//         return {}, .Error
//     }

//     // Query supported present modes
//     present_mode_count: u32
//     res = vk.GetPhysicalDeviceSurfacePresentModesKHR(
//         physical_device, impl.surface, &present_mode_count, nil)
//     if res != .SUCCESS || format_count == 0 {
//         return {}, .Error
//     }

//     vk_present_modes := make([]vk.PresentModeKHR, present_mode_count, ta)
//     res = vk.GetPhysicalDeviceSurfacePresentModesKHR(
//         physical_device, impl.surface, &present_mode_count, raw_data(vk_present_modes))
//     if res != .SUCCESS {
//         return {}, .Error
//     }

//     // Query surface capabilities
//     surface_caps: vk.SurfaceCapabilitiesKHR
//     res = vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, impl.surface, &surface_caps)
//     if res != .SUCCESS {
//         return {}, .Error
//     }

//     // Fill texture formats
//     formats := make([dynamic]Texture_Format, 0, format_count, allocator)

//     // Collect valid formats
//     for vk_format in vk_formats {
//         format := vk_conv_from_format(vk_format.format)
//         if format != .Undefined {
//             append(&formats, format)
//         }
//     }

//     // Sort formats with srgb priority
//     slice.stable_sort_by(formats[:], proc(a, b: Texture_Format) -> bool {
//         a_srgb := texture_format_is_srgb(a)
//         b_srgb := texture_format_is_srgb(b)
//         if a_srgb != b_srgb {
//             return a_srgb
//         }
//         return false
//     })

//     // Fill present modes
//     present_modes := make([dynamic]Present_Mode, 0, present_mode_count, allocator)

//     for &vk_present_mode in vk_present_modes {
//         mode := vk_conv_from_present_mode(vk_present_mode)
//         if mode != .Undefined {
//             append(&present_modes, mode)
//         }
//     }

//     // Fill alpha modes
//     alpha_modes := make([dynamic]Composite_Alpha_Mode, 0, 4, allocator)

//     if .OPAQUE in surface_caps.supportedCompositeAlpha {
//         append(&alpha_modes, Composite_Alpha_Mode.Opaque)
//     }
//     if .PRE_MULTIPLIED in surface_caps.supportedCompositeAlpha {
//         append(&alpha_modes, Composite_Alpha_Mode.Premultiplied)
//     }
//     if .POST_MULTIPLIED in surface_caps.supportedCompositeAlpha {
//         append(&alpha_modes, Composite_Alpha_Mode.Unpremultiplied)
//     }
//     if .INHERIT in surface_caps.supportedCompositeAlpha {
//         append(&alpha_modes, Composite_Alpha_Mode.Inherit)
//     }

//     // Map supported texture usage flags
//     caps.usages = vk_conv_from_image_usage_flags(
//         adapter_impl.caps,
//         surface_caps.supportedUsageFlags,
//     )

//     // fill output slices
//     caps.formats = formats[:]
//     caps.present_modes = present_modes[:]
//     caps.alpha_modes = alpha_modes[:]

//     return caps, .Success
// }

// vk_surface_get_current_texture :: proc(
//     surface: Surface,
//     loc := #caller_location,
// ) -> (
//     surface_texture: Surface_Texture,
// ) {
//     impl := vk_surface_get_impl(surface, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)
//     adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

//     submitter := &device_impl.submitter // short alias

//     surface_texture.status = .Success_Optimal

//     if impl.get_next_image {
//         // Common wait on timeline semaphore for previous operations
//         wait_info := vk.SemaphoreWaitInfo {
//             sType          = .SEMAPHORE_WAIT_INFO,
//             semaphoreCount = 1,
//             pSemaphores    = &impl.timeline_semaphore,
//             pValues        = &impl.timeline_wait_values[impl.current_image_index],
//         }
//         vk_check(device_impl.fp.WaitSemaphores(device_impl.device, &wait_info, max(u64)))

//         acquire_fence: vk.Fence // Optional

//         if adapter_impl.caps.swapchain_maintenance1.swapchainMaintenance1 {
//             // VK_EXT_swapchain_maintenance1: before acquiring again, wait for
//             // the presentation operation to finish
//             present_fence := impl.present_fence[impl.current_image_index]
//             if present_fence != {} {
//                 vk_check(device_impl.fp.WaitForFences(
//                     device_impl.device, 1, &present_fence, true, max(u64)))
//                 vk_check(device_impl.fp.ResetFences(device_impl.device, 1, &present_fence))
//             }
//         } else {
//             // without VK_EXT_swapchain_maintenance1: use acquire fences to
//             // synchronize semaphore reuse
//             acquire_fence = impl.acquire_fence[impl.current_image_index]
//             vk_check(device_impl.fp.WaitForFences(
//                 device_impl.device, 1, &acquire_fence, true, max(u64)))
//             vk_check(device_impl.fp.ResetFences(
//                 device_impl.device, 1, &acquire_fence))
//         }

//         acquire_semaphore := impl.acquire_semaphore[impl.current_image_index]

//         // When timeout is set to max(u64), we wait until the next image has been acquired
//         res := device_impl.fp.AcquireNextImageKHR(
//             device      = device_impl.device,
//             swapchain   = impl.swapchain,
//             timeout     = max(u64),
//             semaphore   = acquire_semaphore,
//             fence       = acquire_fence, // Optional
//             pImageIndex = &impl.current_image_index,
//         )

//         #partial switch res {
//         case .SUCCESS:
//             surface_texture.status = .Success_Optimal
//         case .SUBOPTIMAL_KHR:
//             surface_texture.status = .Success_Suboptimal
//         case .TIMEOUT:
//             surface_texture.status = .Timeout
//         case .NOT_READY, .ERROR_OUT_OF_DATE_KHR:
//             surface_texture.status = .Outdated
//         case .ERROR_SURFACE_LOST_KHR, .ERROR_DEVICE_LOST:
//             // .ERROR_OUT_OF_HOST_MEMORY,
//             // .ERROR_OUT_OF_DEVICE_MEMORY:
//             surface_texture.status = .Lost
//         case:
//             surface_texture.status = .Error
//         }

//         impl.get_next_image = false
//         vk_submit_context_wait_semaphore(submitter, acquire_semaphore)

//         // Update timeline value for this image
//         signal_value := u64(impl.current_frame_index) + u64(impl.num_swapchain_images)
//         // We wait for this value next time we want to acquire this swapchain image
//         impl.timeline_wait_values[impl.current_image_index] = signal_value
//         vk_submit_context_signal_semaphore(submitter, impl.timeline_semaphore, signal_value)

//         vk_submit_context_signal_present_semaphore(
//             submitter, impl.present_semaphore[impl.current_image_index])
//     }

//     assert(impl.current_image_index < impl.num_swapchain_images)
//     surface_texture.texture = impl.swapchain_textures[impl.current_image_index]

//     return
// }

// vk_surface_present :: proc(surface: Surface, loc := #caller_location) -> Status {
//     impl := vk_surface_get_impl(surface, loc)
//     device_impl := vk_device_get_impl(impl.device, loc)
//     adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

//     submitter := &device_impl.submitter // short alias

//     // If the present semaphore is still armed-but-unconsumed, no submit
//     // happened since acquire, it was never actually signaled. Presenting
//     // with a wait on an unsignaled semaphore would hang the presentation
//     // engine, so fall back to an unsynchronized present instead.
//     no_submit_this_frame := vk_submit_context_present_semaphore_pending(submitter)

//     present_semaphore := impl.present_semaphore[impl.current_image_index]

//     wait_semaphore_count: u32 = 0
//     p_wait_semaphores: ^vk.Semaphore = nil

//     if present_semaphore != {} && !no_submit_this_frame {
//         wait_semaphore_count = 1
//         p_wait_semaphores = &present_semaphore
//     }

//     // If nothing was submitted, clear the stale arm so it doesn't leak
//     // into the next acquire cycle's bookkeeping.
//     if no_submit_this_frame {
//         vk_submit_context_clear_present_semaphore(submitter)
//     }

//     res := vk.Result.ERROR_UNKNOWN

//     if adapter_impl.caps.swapchain_maintenance1.swapchainMaintenance1 {
//         if impl.present_fence[impl.current_image_index] == {} {
//             fence_name_buf: [256]u8
//             fence_name := fmt.bprintf(
//                 fence_name_buf[:], "Fence: present-fence-%d", impl.current_image_index)
//             impl.present_fence[impl.current_image_index] =
//                 vk_utils_create_fence(device_impl, fence_name)
//         }

//         swap_fence_info := vk.SwapchainPresentFenceInfoEXT {
//             sType          = .SWAPCHAIN_PRESENT_FENCE_INFO_EXT,
//             swapchainCount = 1,
//             pFences        = &impl.present_fence[impl.current_image_index],
//         }

//         present_info := vk.PresentInfoKHR {
//             sType              = .PRESENT_INFO_KHR,
//             pNext              = &swap_fence_info,
//             waitSemaphoreCount = wait_semaphore_count,
//             pWaitSemaphores    = p_wait_semaphores,
//             swapchainCount     = 1,
//             pSwapchains        = &impl.swapchain,
//             pImageIndices      = &impl.current_image_index,
//         }

//         res = device_impl.fp.QueuePresentKHR(device_impl.queue.graphics_queue, &present_info)
//     } else {
//         present_info := vk.PresentInfoKHR {
//             sType              = .PRESENT_INFO_KHR,
//             waitSemaphoreCount = wait_semaphore_count,
//             pWaitSemaphores    = p_wait_semaphores,
//             swapchainCount     = 1,
//             pSwapchains        = &impl.swapchain,
//             pImageIndices      = &impl.current_image_index,
//         }

//         res = device_impl.fp.QueuePresentKHR(device_impl.queue.graphics_queue, &present_info)
//     }

//     if res != .SUCCESS && res != .SUBOPTIMAL_KHR && res != .ERROR_OUT_OF_DATE_KHR {
//         vk_check(res)
//     }

//     impl.get_next_image = true
//     impl.current_frame_index += 1

//     return .Success
// }

// vk_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_swapchain_destroy_resources :: proc(impl: ^VK_Surface_Impl, loc := #caller_location) {
//     assert(impl.swapchain != {}, "Invalid vk.SwapchainKHR", loc)
//     assert(impl.device != {}, "Invalid VK_Device_Impl", loc)

//     device_impl := vk_device_get_impl(impl.device, loc)

//     device_impl.fp.DeviceWaitIdle(device_impl.device)

//     for i in 0 ..< impl.num_swapchain_images {
//         // Remove the image handle
//         texture_handle := vk_texture_get_handle(impl.swapchain_textures[i])
//         hm.remove(&device_impl.textures, texture_handle)
//         impl.swapchain_textures[i] = {}

//         // Destroy the vk.ImageView and remove the handle
//         view_impl := vk_texture_view_get_impl(impl.swapchain_views[i])
//         device_impl.fp.DestroyImageView(device_impl.device, view_impl.vk_image_view, nil)
//         hm.remove(&device_impl.texture_views, view_impl.handle)
//         impl.swapchain_views[i] = {}

//         // Destroy sync objects
//         if impl.acquire_fence[i] != {} {
//             device_impl.fp.DestroyFence(device_impl.device, impl.acquire_fence[i], nil)
//             impl.acquire_fence[i] = {}
//         }
//         if impl.present_fence[i] != {} {
//             device_impl.fp.DestroyFence(device_impl.device, impl.present_fence[i], nil)
//             impl.present_fence[i] = {}
//         }
//         if impl.acquire_semaphore[i] != {} {
//             device_impl.fp.DestroySemaphore(device_impl.device, impl.acquire_semaphore[i], nil)
//             impl.acquire_semaphore[i] = {}
//         }
//         if impl.present_semaphore[i] != {} {
//             device_impl.fp.DestroySemaphore(device_impl.device, impl.present_semaphore[i], nil)
//             impl.present_semaphore[i] = {}
//         }
//     }

//     device_impl.fp.DestroySemaphore(device_impl.device, impl.timeline_semaphore, nil)
//     impl.timeline_semaphore = {}

//     device_impl.fp.DestroySwapchainKHR(device_impl.device, impl.swapchain, nil)
//     impl.swapchain = {}

//     // Reset frame state
//     impl.current_image_index = 0
//     impl.current_frame_index = 0

//     slice.zero(impl.timeline_wait_values[:VK_MAX_SWAPCHAIN_IMAGES])
//     slice.zero(impl.present_fence[:VK_MAX_SWAPCHAIN_IMAGES])
//     slice.zero(impl.acquire_semaphore[:VK_MAX_SWAPCHAIN_IMAGES])
//     slice.zero(impl.present_semaphore[:VK_MAX_SWAPCHAIN_IMAGES])
//     slice.zero(impl.acquire_fence[:VK_MAX_SWAPCHAIN_IMAGES])
//     slice.zero(impl.swapchain_textures[:impl.num_swapchain_images])
//     slice.zero(impl.swapchain_views[:impl.num_swapchain_images])

//     impl.num_swapchain_images = 0
// }

// vk_surface_unconfigure :: proc(surface: Surface, loc := #caller_location) {
//     impl := vk_surface_get_impl(surface, loc)
//     vk_swapchain_destroy_resources(impl, loc)
//     vk_device_release(impl.device, loc)
//     impl.device = {}
// }

// vk_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
//     impl := vk_surface_get_impl(surface, loc)
//     add_ref(impl, loc)
// }

// vk_surface_release :: proc(surface: Surface, loc := #caller_location) {
//     impl := vk_surface_get_impl(surface, loc)
//     if release_ref(impl, loc) {
//         context.allocator = impl.allocator
//         if impl.swapchain != {} {
//             vk_surface_unconfigure(surface, loc)
//         }
//         if impl.instance != {} && impl.surface != {} {
//             vk.DestroySurfaceKHR(impl.instance.instance, impl.surface, nil)
//         }
//         vk_instance_release(Instance(impl.instance), loc)
//         sync.guard(&gpu.vk.mtx)
//         hm.remove(&gpu.vk.surfaces, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Surface_Capabilities
// // -----------------------------------------------------------------------------

// vk_surface_capabilities_free_members :: proc(
//     surface_capabilities: Surface_Capabilities,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     context.allocator = allocator
//     delete(surface_capabilities.formats)
//     delete(surface_capabilities.present_modes)
//     delete(surface_capabilities.alpha_modes)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Texture
// // -----------------------------------------------------------------------------

// VK_MAX_IMAGE_PLANES :: 3

// VK_Texture_Handle :: distinct hm.Handle64

// VK_Texture_Impl :: struct {
//     using desc:            Texture_Descriptor,
//     vk_memory:             [VK_MAX_IMAGE_PLANES]vk.DeviceMemory,
//     vk_format_properties:  vk.FormatProperties,
//     vk_extent:             vk.Extent3D,
//     device:                Device,
//     surface:               Surface,
//     vk_image:              vk.Image,
//     texture_view:          Texture_View,
//     vma_allocation:        vma.Allocation,
//     mapped_ptr:            rawptr,
//     handle:                VK_Texture_Handle,
//     vk_usage_flags:        vk.ImageUsageFlags,
//     vk_type:               vk.ImageType,
//     vk_image_format:       vk.Format,
//     vk_samples:            vk.SampleCountFlags,
//     vk_image_layout:       vk.ImageLayout,
//     num_levels:            u32,
//     num_layers:            u32,
//     ref:                   Ref_Count_Type,
//     is_owning_vk_image:    bool,
//     is_resolve_attachment: bool,
//     is_depth_format:       bool,
//     is_stencil_format:     bool,
//     is_swapchain:          bool,
// }

// vk_texture_get_impl :: #force_inline proc "contextless" (
//     texture: Texture,
//     loc := #caller_location,
// ) -> ^VK_Texture_Impl {
//     assert_contextless(texture != {}, "Invalid texture", loc)
//     h := id_to_handle(texture)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     texture_handle := VK_Texture_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.textures, texture_handle)
// }

// vk_texture_get_handle :: #force_inline proc "contextless" (
//     texture: Texture,
//     loc := #caller_location,
// ) -> VK_Texture_Handle {
//     assert_contextless(texture != {}, "Invalid texture", loc)
//     h := id_to_handle(texture)
//     texture_handle := VK_Texture_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return texture_handle
// }

// VK_DEFAULT_COLOR_SUBRESOURCE_RANGE :: vk.ImageSubresourceRange {
//     aspectMask     = {.COLOR},
//     baseMipLevel   = 0,
//     levelCount     = vk.REMAINING_MIP_LEVELS,
//     baseArrayLayer = 0,
//     layerCount     = vk.REMAINING_ARRAY_LAYERS,
// }

// vk_texture_transition_to_color_attachment :: proc(
//     device: ^VK_Device_Impl,
//     texture: ^VK_Texture_Impl,
//     vk_command_buffer: vk.CommandBuffer,
//     loc := #caller_location,
// ) {
//     assert(texture.is_depth_format == false, "Color attachments cannot have depth format", loc)
//     assert(texture.is_stencil_format == false, "Color attachments cannot have stencil format", loc)
//     assert(texture.vk_image_format != .UNDEFINED, "Invalid color attachment format", loc)

//     vk_texture_transition_layout(
//         device,
//         texture,
//         vk_command_buffer,
//         .COLOR_ATTACHMENT_OPTIMAL,
//         VK_DEFAULT_COLOR_SUBRESOURCE_RANGE,
//     )
// }

// vk_texture_transition_layout :: proc(
//     device: ^VK_Device_Impl,
//     texture: ^VK_Texture_Impl,
//     vk_command_buffer: vk.CommandBuffer,
//     new_image_layout: vk.ImageLayout,
//     subresource_range: vk.ImageSubresourceRange,
//     loc := #caller_location,
// ) {
//     if texture.vk_image_layout == new_image_layout {
//         return // no-op
//     }

//     new_image_layout := new_image_layout

//     is_depth_attachment := vk_image_usage_flags_is_depth_attachment(texture.vk_usage_flags)

//     old_image_layout: vk.ImageLayout = texture.vk_image_layout == .ATTACHMENT_OPTIMAL \
//         ? is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL\
//             : .COLOR_ATTACHMENT_OPTIMAL : texture.vk_image_layout

//     if new_image_layout == .ATTACHMENT_OPTIMAL {
//         new_image_layout =
//             is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
//     }

//     src := vk_image_layout_get_stage_access(old_image_layout)
//     dst := vk_image_layout_get_stage_access(new_image_layout)

//     if is_depth_attachment && texture.is_resolve_attachment {
//         // https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#renderpass-resolve-operations
//         src.stage |= {.COLOR_ATTACHMENT_OUTPUT}
//         dst.stage |= {.COLOR_ATTACHMENT_OUTPUT}
//         src.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
//         dst.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
//     }

//     barrier := vk.ImageMemoryBarrier2 {
//         sType               = .IMAGE_MEMORY_BARRIER_2,
//         srcStageMask        = src.stage,
//         srcAccessMask       = src.access,
//         dstStageMask        = dst.stage,
//         dstAccessMask       = dst.access,
//         oldLayout           = texture.vk_image_layout,
//         newLayout           = new_image_layout,
//         srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
//         dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
//         image               = texture.vk_image,
//         subresourceRange    = subresource_range,
//     }

//     dep_info := vk.DependencyInfo {
//         sType                   = .DEPENDENCY_INFO,
//         imageMemoryBarrierCount = 1,
//         pImageMemoryBarriers    = &barrier,
//     }

//     device.fp.CmdPipelineBarrier2(vk_command_buffer, &dep_info)

//     texture.vk_image_layout = new_image_layout
// }

// vk_texture_create_view :: proc(
//     texture: Texture,
//     descriptor: ^Texture_View_Descriptor = nil,
//     loc := #caller_location,
// ) -> Texture_View {
//     impl := vk_texture_get_impl(texture, loc)

//     if impl.is_owning_vk_image {
//         return impl.texture_view
//     } else {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

//         desc := resolve_texture_view_descriptor(texture, impl.device, descriptor, loc)

//         vk_image_view := vk_texture_create_image_view(impl,
//             type        = vk_conv_to_image_view_type(desc.dimension),
//             format      = vk_conv_to_format(adapter_impl.caps, desc.format),
//             aspect_mask = vk_conv_to_image_aspect_flags(desc.range.aspect, desc.format),
//             base_level  = desc.range.base_mip_level,
//             num_levels  = desc.range.mip_level_count,
//             base_layer  = desc.range.base_array_layer,
//             num_layers  = desc.range.array_layer_count,
//             // debug_name  = desc.label,
//         )

//         view_impl := hm_dynamic_add_get(&device_impl.texture_views, VK_Texture_View_Impl{
//             device            = impl.device,
//             texture           = texture,
//             vk_image_view     = vk_image_view,
//             is_swapchain      = false,
//             format            = desc.format,
//             dimension         = desc.dimension,
//             usage             = desc.usage,
//             aspect            = desc.range.aspect,
//             base_mip_level    = desc.range.base_mip_level,
//             mip_level_count   = desc.range.mip_level_count,
//             base_array_layer  = desc.range.base_array_layer,
//             array_layer_count = desc.range.array_layer_count,
//         }) or_else panic("Failed to allocate texture view handle", loc)

//         init_ref(view_impl)
//         vk_texture_add_ref(texture, loc)

//         view_handle := handle_make(view_impl.handle, device_impl.handle)
//         texture := handle_to_raw(Texture_View, view_handle)

//         return texture
//     }
// }

// vk_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_texture_get_depth_or_array_layers :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.size.depth_or_array_layers
// }

// vk_texture_get_descriptor :: proc(
//     texture: Texture,
//     loc := #caller_location,
// ) -> Texture_Descriptor {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc
// }

// vk_texture_get_dimension :: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.dimension
// }

// vk_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.format
// }

// vk_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.size.height
// }

// vk_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.mip_level_count
// }

// vk_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.sample_count
// }

// vk_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.size
// }

// vk_texture_get_texture_binding_view_dimension :: proc(
//     texture: Texture,
//     loc := #caller_location,
// ) -> Texture_View_Dimension {
//     unimplemented(loc = loc)
// }

// vk_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.usage
// }

// vk_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := vk_texture_get_impl(texture, loc)
//     return impl.desc.size.width
// }

// vk_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// vk_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
//     impl := vk_texture_get_impl(texture, loc)
//     add_ref(impl, loc)
// }

// vk_texture_release :: proc(texture: Texture, loc := #caller_location) {
//     impl := vk_texture_get_impl(texture, loc)

//     if impl.is_owning_vk_image {
//         return
//     }

//     if release_ref(impl, loc) {
//         device_impl := vk_device_get_impl(impl.device, loc)

//         vk_device_add_deferred_resource(impl.device,
//             VK_Deferred_Image{impl.vk_image, impl.vma_allocation, impl.vk_memory})

//         hm.remove(&device_impl.textures, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Texture_View
// // -----------------------------------------------------------------------------

// VK_Texture_View_Handle :: distinct hm.Handle64

// VK_Texture_View_Impl :: struct {
//     device:                Device,
//     texture:               Texture,
//     vk_image_view:         vk.ImageView,
//     vk_image_view_storage: vk.ImageView,
//     handle:                VK_Texture_View_Handle,
//     ref:                   Ref_Count_Type,
//     format:                Texture_Format,
//     dimension:             Texture_View_Dimension,
//     usage:                 Texture_Uses,
//     aspect:                Texture_Aspect,
//     base_mip_level:        u32,
//     mip_level_count:       u32,
//     base_array_layer:      u32,
//     array_layer_count:     u32,
//     is_owning_vk_view:     bool,
//     is_swapchain:          bool,
// }

// vk_texture_view_get_impl :: #force_inline proc "contextless" (
//     texture_view: Texture_View,
//     loc := #caller_location,
// ) -> ^VK_Texture_View_Impl {
//     assert_contextless(texture_view != {}, "Invalid Texture_View", loc)
//     h := id_to_handle(texture_view)
//     device_impl := device_pool_get(&gpu.vk.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     texture_view_handle := VK_Texture_View_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.texture_views, texture_view_handle)
// }

// vk_texture_create_image_view :: proc(
//     self: ^VK_Texture_Impl,
//     type: vk.ImageViewType,
//     format: vk.Format,
//     aspect_mask: vk.ImageAspectFlags,
//     base_level: u32,
//     num_levels: u32 = vk.REMAINING_MIP_LEVELS,
//     base_layer: u32 = 0,
//     num_layers: u32 = 1,
//     components: vk.ComponentMapping = {}, // .IDENTITY
//     ycbcr: ^vk.SamplerYcbcrConversionInfo = nil,
//     debug_name := "",
//     loc := #caller_location,
// ) -> (
//     vk_image_view: vk.ImageView,
// ) {
//     device_impl := vk_device_get_impl(self.device, loc)

//     image_view_create_info := vk.ImageViewCreateInfo {
//         sType = .IMAGE_VIEW_CREATE_INFO,
//         pNext = ycbcr,
//         image = self.vk_image,
//         viewType = type,
//         format = format,
//         components = components,
//         subresourceRange = {
//             aspectMask = aspect_mask,
//             baseMipLevel = base_level,
//             levelCount = num_levels > 0 ? num_levels : self.num_levels,
//             baseArrayLayer = base_layer,
//             layerCount = num_layers,
//         },
//     }

//     vk_check(
//         device_impl.fp.CreateImageView(
//             device_impl.device,
//             &image_view_create_info,
//             nil,
//             &vk_image_view,
//         ),
//         loc = loc,
//     )
//     vk_utils_set_debug_object_name(device_impl, .IMAGE_VIEW, vk_image_view, debug_name, loc)

//     return
// }

// vk_texture_view_set_label :: proc(
//     texture_view: Texture_View,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// vk_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
//     impl := vk_texture_view_get_impl(texture_view, loc)
//     add_ref(impl, loc)
// }

// vk_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
//     impl := vk_texture_view_get_impl(texture_view, loc)

//     if impl.is_owning_vk_view {
//         return
//     }

//     if release_ref(impl, loc) {
//         device_impl := vk_device_get_impl(impl.device, loc)
//         vk_device_add_deferred_resource(impl.device, impl.vk_image_view)
//         texture_release(impl.texture)
//         hm.remove(&device_impl.texture_views, impl.handle)
//     }
// }
