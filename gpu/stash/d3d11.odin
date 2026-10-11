#+build windows
#+private
package gpu

// // Core
// import "base:runtime"
// import "core:container/xar"
// import "core:fmt"
// import "core:log"
// import "core:mem"
// import "core:slice"
// import "core:strings"
// import "core:sync"

// import hm "core:container/handle_map"
// import win32 "core:sys/windows"

// // Vendor
// import "vendor:directx/dxgi"
// import "vendor:directx/d3d11"
// import "vendor:directx/d3d_compiler"

// D3D11_Device_Pool :: Device_Pool(D3D11_Device_Impl)

// D3D11_State :: struct {
//     devices:  D3D11_Device_Pool,
//     surfaces: DHM(D3D11_Surface_Impl, D3D11_Surface_Handle),
//     adapters: DHM(D3D11_Adapter_Impl, D3D11_Adapter_Handle),
//     mtx:      sync.Mutex,
// }

// d3d11_set_procedures :: proc() {
//     gpu.backend = .DX11
//     gpu.is_embedded = false

//     // Global procedures
//     get_instance_features = d3d11_get_instance_features
//     get_instance_limits = d3d11_get_instance_limits
//     has_instance_feature = d3d11_has_instance_feature
//     get_proc_address = d3d11_get_proc_address

//     // Procedures of Adapter
//     adapter_get_features = d3d11_adapter_get_features
//     adapter_get_features_view = d3d11_adapter_get_features_view
//     adapter_get_info = d3d11_adapter_get_info
//     adapter_get_limits = d3d11_adapter_get_limits
//     adapter_has_feature = d3d11_adapter_has_feature
//     adapter_request_device = d3d11_adapter_request_device
//     adapter_add_ref = d3d11_adapter_add_ref
//     adapter_release = d3d11_adapter_release

//     // Private procedures of Adapter
//     adapter_texture_format_capabilities = d3d11_adapter_texture_format_capabilities

//     // Procedures of Adapter_Info
//     adapter_info_free_members = d3d11_adapter_info_free_members

//     // Procedures of Bind_Group
//     bind_group_set_label = d3d11_bind_group_set_label
//     bind_group_add_ref = d3d11_bind_group_add_ref
//     bind_group_release = d3d11_bind_group_release
//     bind_group_layout_set_label = d3d11_bind_group_layout_set_label
//     bind_group_layout_add_ref = d3d11_bind_group_layout_add_ref
//     bind_group_layout_release = d3d11_bind_group_layout_release

//     // Procedures of Buffer
//     buffer_destroy = d3d11_buffer_destroy
//     buffer_get_const_mapped_range = d3d11_buffer_get_const_mapped_range
//     buffer_get_mapped_range = d3d11_buffer_get_mapped_range
//     buffer_get_map_state = d3d11_buffer_get_map_state
//     buffer_get_size = d3d11_buffer_get_size
//     buffer_get_usage = d3d11_buffer_get_usage
//     buffer_map_async = d3d11_buffer_map_async
//     buffer_read_mapped_range = d3d11_buffer_read_mapped_range
//     buffer_set_label = d3d11_buffer_set_label
//     buffer_unmap = d3d11_buffer_unmap
//     buffer_write_mapped_range = d3d11_buffer_write_mapped_range
//     buffer_add_ref = d3d11_buffer_add_ref
//     buffer_release = d3d11_buffer_release

//     // Procedures of Command_Buffer
//     command_buffer_set_label = d3d11_command_buffer_set_label
//     command_buffer_add_ref = d3d11_command_buffer_add_ref
//     command_buffer_release = d3d11_command_buffer_release

//     // Procedures of Command_Encoder
//     command_encoder_begin_compute_pass = d3d11_command_encoder_begin_compute_pass
//     command_encoder_begin_render_pass = d3d11_command_encoder_begin_render_pass
//     command_encoder_clear_buffer = d3d11_command_encoder_clear_buffer
//     command_encoder_copy_buffer_to_buffer = d3d11_command_encoder_copy_buffer_to_buffer
//     command_encoder_copy_buffer_to_texture = d3d11_command_encoder_copy_buffer_to_texture
//     command_encoder_copy_texture_to_buffer = d3d11_command_encoder_copy_texture_to_buffer
//     command_encoder_copy_texture_to_texture = d3d11_command_encoder_copy_texture_to_texture
//     command_encoder_finish = d3d11_command_encoder_finish
//     command_encoder_insert_debug_marker = d3d11_command_encoder_insert_debug_marker
//     command_encoder_pop_debug_group = d3d11_command_encoder_pop_debug_group
//     command_encoder_push_debug_group = d3d11_command_encoder_push_debug_group
//     command_encoder_resolve_query_set = d3d11_command_encoder_resolve_query_set
//     command_encoder_set_label = d3d11_command_encoder_set_label
//     command_encoder_write_timestamp = d3d11_command_encoder_write_timestamp
//     command_encoder_add_ref = d3d11_command_encoder_add_ref
//     command_encoder_release = d3d11_command_encoder_release

//     // Procedures of Compute_Pass_Encoder
//     compute_pass_encoder_dispatch_workgroups = d3d11_compute_pass_encoder_dispatch_workgroups
//     compute_pass_encoder_dispatch_workgroups_indirect =
//         d3d11_compute_pass_encoder_dispatch_workgroups_indirect
//     compute_pass_encoder_end = d3d11_compute_pass_encoder_end
//     compute_pass_encoder_insert_debug_marker = d3d11_compute_pass_encoder_insert_debug_marker
//     compute_pass_encoder_pop_debug_group = d3d11_compute_pass_encoder_pop_debug_group
//     compute_pass_encoder_push_debug_group = d3d11_compute_pass_encoder_push_debug_group
//     compute_pass_encoder_set_bind_group = d3d11_compute_pass_encoder_set_bind_group
//     compute_pass_encoder_set_immediates = d3d11_compute_pass_encoder_set_immediates
//     compute_pass_encoder_set_label = d3d11_compute_pass_encoder_set_label
//     compute_pass_encoder_set_pipeline = d3d11_compute_pass_encoder_set_pipeline
//     compute_pass_encoder_add_ref = d3d11_compute_pass_encoder_add_ref
//     compute_pass_encoder_release = d3d11_compute_pass_encoder_release

//     // Procedures of Compute_Pipeline
//     compute_pipeline_get_bind_group_layout = d3d11_compute_pipeline_get_bind_group_layout
//     compute_pipeline_set_label = d3d11_compute_pipeline_set_label
//     compute_pipeline_add_ref = d3d11_compute_pipeline_add_ref
//     compute_pipeline_release = d3d11_compute_pipeline_release

//     // Procedures of Device
//     device_get_adapter = d3d11_device_get_adapter
//     device_create_bind_group = d3d11_device_create_bind_group
//     device_create_bind_group_layout = d3d11_device_create_bind_group_layout
//     device_create_buffer = d3d11_device_create_buffer
//     device_create_command_encoder = d3d11_device_create_command_encoder
//     device_create_compute_pipeline = d3d11_device_create_compute_pipeline
//     device_create_compute_pipeline_async = d3d11_device_create_compute_pipeline_async
//     device_create_pipeline_layout = d3d11_device_create_pipeline_layout
//     device_create_query_set = d3d11_device_create_query_set
//     device_create_render_bundle_encoder = d3d11_device_create_render_bundle_encoder
//     device_create_render_pipeline = d3d11_device_create_render_pipeline
//     device_create_render_pipeline_async = d3d11_device_create_render_pipeline_async
//     device_create_sampler = d3d11_device_create_sampler
//     device_create_shader_module = d3d11_device_create_shader_module
//     device_create_texture = d3d11_device_create_texture
//     device_destroy = d3d11_device_destroy
//     device_get_adapter_info = d3d11_device_get_adapter_info
//     device_get_features = d3d11_device_get_features
//     device_get_features_view = d3d11_device_get_features_view
//     device_get_limits = d3d11_device_get_limits
//     device_get_lost_future = d3d11_device_get_lost_future
//     device_get_queue = d3d11_device_get_queue
//     device_has_feature = d3d11_device_has_feature
//     device_pop_error_scope = d3d11_device_pop_error_scope
//     device_push_error_scope = d3d11_device_push_error_scope
//     device_set_label = d3d11_device_set_label
//     device_add_ref = d3d11_device_add_ref
//     device_release = d3d11_device_release

//     // Procedures of External_Texture
//     external_texture_set_label = d3d11_external_texture_set_label
//     external_texture_add_ref = d3d11_external_texture_add_ref
//     external_texture_release = d3d11_external_texture_release

//     // Procedures of Instance
//     instance_create_surface = d3d11_instance_create_surface
//     instance_get_wgsl_language_features = d3d11_instance_get_wgsl_language_features
//     instance_has_wgsl_language_feature = d3d11_instance_has_wgsl_language_feature
//     instance_process_events = d3d11_instance_process_events
//     instance_request_adapter = d3d11_instance_request_adapter
//     instance_wait_any = d3d11_instance_wait_any
//     instance_add_ref = d3d11_instance_add_ref
//     instance_release = d3d11_instance_release

//     // Procedures of Pipeline_Layout
//     pipeline_layout_set_label = d3d11_pipeline_layout_set_label
//     pipeline_layout_add_ref = d3d11_pipeline_layout_add_ref
//     pipeline_layout_release = d3d11_pipeline_layout_release

//     // Procedures of Query_Set
//     query_set_destroy = d3d11_query_set_destroy
//     query_set_get_count = d3d11_query_set_get_count
//     query_set_get_type = d3d11_query_set_get_type
//     query_set_set_label = d3d11_query_set_set_label
//     query_set_add_ref = d3d11_query_set_add_ref
//     query_set_release = d3d11_query_set_release

//     // Procedures of Queue
//     queue_on_submitted_work_done = d3d11_queue_on_submitted_work_done
//     queue_set_label = d3d11_queue_set_label
//     queue_submit = d3d11_queue_submit
//     queue_write_buffer = d3d11_queue_write_buffer
//     queue_write_texture = d3d11_queue_write_texture
//     queue_add_ref = d3d11_queue_add_ref
//     queue_release = d3d11_queue_release

//     // Procedures of Render_Bundle
//     render_bundle_set_label = d3d11_render_bundle_set_label
//     render_bundle_add_ref = d3d11_render_bundle_add_ref
//     render_bundle_release = d3d11_render_bundle_release

//     // Procedures of Render_Bundle_Encoder
//     render_bundle_encoder_draw = d3d11_render_bundle_encoder_draw
//     render_bundle_encoder_draw_indexed = d3d11_render_bundle_encoder_draw_indexed
//     render_bundle_encoder_draw_indexed_indirect = d3d11_render_bundle_encoder_draw_indexed_indirect
//     render_bundle_encoder_draw_indirect = d3d11_render_bundle_encoder_draw_indirect
//     render_bundle_encoder_finish = d3d11_render_bundle_encoder_finish
//     render_bundle_encoder_insert_debug_marker = d3d11_render_bundle_encoder_insert_debug_marker
//     render_bundle_encoder_pop_debug_group = d3d11_render_bundle_encoder_pop_debug_group
//     render_bundle_encoder_push_debug_group = d3d11_render_bundle_encoder_push_debug_group
//     render_bundle_encoder_set_bind_group = d3d11_render_bundle_encoder_set_bind_group
//     render_bundle_encoder_set_immediates = d3d11_render_bundle_encoder_set_immediates
//     render_bundle_encoder_set_index_buffer = d3d11_render_bundle_encoder_set_index_buffer
//     render_bundle_encoder_set_label = d3d11_render_bundle_encoder_set_label
//     render_bundle_encoder_set_pipeline = d3d11_render_bundle_encoder_set_pipeline
//     render_bundle_encoder_set_vertex_buffer = d3d11_render_bundle_encoder_set_vertex_buffer
//     render_bundle_encoder_add_ref = d3d11_render_bundle_encoder_add_ref
//     render_bundle_encoder_release = d3d11_render_bundle_encoder_release

//     // Procedures of Render_Pass_Encoder
//     render_pass_encoder_begin_occlusion_query = d3d11_render_pass_encoder_begin_occlusion_query
//     render_pass_encoder_draw = d3d11_render_pass_encoder_draw
//     render_pass_encoder_draw_indexed = d3d11_render_pass_encoder_draw_indexed
//     render_pass_encoder_draw_indexed_indirect = d3d11_render_pass_encoder_draw_indexed_indirect
//     render_pass_encoder_draw_indirect = d3d11_render_pass_encoder_draw_indirect
//     render_pass_encoder_end = d3d11_render_pass_encoder_end
//     render_pass_encoder_end_occlusion_query = d3d11_render_pass_encoder_end_occlusion_query
//     render_pass_encoder_execute_bundles = d3d11_render_pass_encoder_execute_bundles
//     render_pass_encoder_insert_debug_marker = d3d11_render_pass_encoder_insert_debug_marker
//     render_pass_encoder_pop_debug_group = d3d11_render_pass_encoder_pop_debug_group
//     render_pass_encoder_push_debug_group = d3d11_render_pass_encoder_push_debug_group
//     render_pass_encoder_set_bind_group = d3d11_render_pass_encoder_set_bind_group
//     render_pass_encoder_set_blend_constant = d3d11_render_pass_encoder_set_blend_constant
//     render_pass_encoder_set_immediates = d3d11_render_pass_encoder_set_immediates
//     render_pass_encoder_set_index_buffer = d3d11_render_pass_encoder_set_index_buffer
//     render_pass_encoder_set_label = d3d11_render_pass_encoder_set_label
//     render_pass_encoder_set_pipeline = d3d11_render_pass_encoder_set_pipeline
//     render_pass_encoder_set_scissor_rect = d3d11_render_pass_encoder_set_scissor_rect
//     render_pass_encoder_set_stencil_reference = d3d11_render_pass_encoder_set_stencil_reference
//     render_pass_encoder_set_vertex_buffer = d3d11_render_pass_encoder_set_vertex_buffer
//     render_pass_encoder_set_viewport = d3d11_render_pass_encoder_set_viewport
//     render_pass_encoder_add_ref = d3d11_render_pass_encoder_add_ref
//     render_pass_encoder_release = d3d11_render_pass_encoder_release

//     // Procedures of Render_Pipeline
//     render_pipeline_get_bind_group_layout = d3d11_render_pipeline_get_bind_group_layout
//     render_pipeline_set_label = d3d11_render_pipeline_set_label
//     render_pipeline_add_ref = d3d11_render_pipeline_add_ref
//     render_pipeline_release = d3d11_render_pipeline_release

//     // Procedures of Sampler
//     sampler_set_label = d3d11_sampler_set_label
//     sampler_add_ref = d3d11_sampler_add_ref
//     sampler_release = d3d11_sampler_release

//     // Procedures of Shader_Module
//     shader_module_get_compilation_info = d3d11_shader_module_get_compilation_info
//     shader_module_set_label = d3d11_shader_module_set_label
//     shader_module_add_ref = d3d11_shader_module_add_ref
//     shader_module_release = d3d11_shader_module_release

//     // Procedures of Supported_Features
//     supported_features_free_members = d3d11_supported_features_free_members

//     // Procedures of Supported_Instance_Features
//     supported_instance_features_free_members = d3d11_supported_instance_features_free_members

//     // Procedures of Supported_WGSL_Language_Features
//     supported_wgsl_language_features_free_members =
//         d3d11_supported_wgsl_language_features_free_members

//     // Procedures of Surface
//     surface_configure = d3d11_surface_configure
//     surface_get_capabilities = d3d11_surface_get_capabilities
//     surface_get_current_texture = d3d11_surface_get_current_texture
//     surface_present = d3d11_surface_present
//     surface_set_label = d3d11_surface_set_label
//     surface_unconfigure = d3d11_surface_unconfigure
//     surface_add_ref = d3d11_surface_add_ref
//     surface_release = d3d11_surface_release
//     surface_capabilities_free_members = d3d11_surface_capabilities_free_members

//     // Procedures of Texture
//     texture_create_view = d3d11_texture_create_view
//     texture_destroy = d3d11_texture_destroy
//     texture_get_depth_or_array_layers = d3d11_texture_get_depth_or_array_layers
//     texture_get_descriptor = d3d11_texture_get_descriptor
//     texture_get_dimension = d3d11_texture_get_dimension
//     texture_get_format = d3d11_texture_get_format
//     texture_get_height = d3d11_texture_get_height
//     texture_get_mip_level_count = d3d11_texture_get_mip_level_count
//     texture_get_sample_count = d3d11_texture_get_sample_count
//     texture_get_size = d3d11_texture_get_size
//     texture_get_texture_binding_view_dimension = d3d11_texture_get_texture_binding_view_dimension
//     texture_get_usage = d3d11_texture_get_usage
//     texture_get_width = d3d11_texture_get_width
//     texture_set_label = d3d11_texture_set_label
//     texture_add_ref = d3d11_texture_add_ref
//     texture_release = d3d11_texture_release

//     // Procedures of Texture_View
//     texture_view_set_label = d3d11_texture_view_set_label
//     texture_view_add_ref = d3d11_texture_view_add_ref
//     texture_view_release = d3d11_texture_view_release
// }

// // -----------------------------------------------------------------------------
// // Global procedures
// // -----------------------------------------------------------------------------

// d3d11_create_instance :: proc(
//     descriptor: ^Instance_Descriptor = nil,
//     loc := #caller_location,
// ) -> Instance {
//     // Do we have an optional descriptor?
//     desc := descriptor != nil ? descriptor^ : {}

//     // Get the instance extra options if any
//     extras := chain_get(Instance_Extras, desc.next_in_chain, .Instance_Extras)

//     flags: Instance_Flags
//     is_debug: bool

//     if extras != nil {
//         flags = extras.flags
//         is_debug = .Debug in flags
//     }

//     dxgi_factory := d3d_create_factory(is_debug, loc)

//     impl := new(D3D11_Instance_Impl) \
//         or_else panic("Failed to allocate memory for Instance", loc)
//     init_ref(impl)

//     impl.ctx = context
//     impl.allocator = context.allocator
//     impl.flags = flags
//     impl.current_future_id = 1
//     impl.pending_futures.allocator = impl.allocator
//     impl.dxgi_factory = dxgi_factory

//     hm.dynamic_init(&gpu.d3d11.surfaces, impl.allocator)
//     hm.dynamic_init(&gpu.d3d11.adapters, impl.allocator)

//     d3d11_set_procedures()

//     return Instance(impl)
// }

// d3d11_get_instance_features :: proc(
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Instance_Features,
// ) {
//     features.features = make([]Instance_Feature_Name, 1, allocator) or_else \
//         panic("Failed to allocate []Instance_Feature_Name", loc )
//     features.features[0] = .Timed_Wait_Any
//     return
// }

// d3d11_get_instance_limits :: proc(loc := #caller_location) -> (limits: Instance_Limits) {
//     limits.timed_wait_any_max_count = max(uint) // unlimited
//     return
// }

// d3d11_has_instance_feature :: proc(
//     feature: Instance_Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     return feature == .Timed_Wait_Any
// }

// d3d11_get_proc_address :: proc(procName: string, loc := #caller_location) -> Proc {
//     unimplemented(loc = loc)
// }

// d3d11_set_log_callback :: proc(callback: Log_Callback, userdata: rawptr, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_set_log_level :: proc(level: Log_Level, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_get_version :: proc(loc := #caller_location) -> u32 {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Adapter
// // -----------------------------------------------------------------------------

// D3D11_Adapter_Handle :: distinct hm.Handle64

// D3D11_Adapter_Capabilities :: struct {
//     dedicated_video_memory:               uint,
//     shared_system_memory:                 uint,
//     max_shader_model:                     u32,
//     max_feature_level:                    d3d11.FEATURE_LEVEL,
//     conservative_raster_tier:             d3d11.CONSERVATIVE_RASTERIZATION_TIER,
//     supports_vp_rt_index_no_gs_emulation: bool,
//     supports_shared_resource_tier2:       bool,
//     is_uma:                               bool,
//     supports_rov:                         bool,
//     supports_monitored_fence:             bool,
//     supports_non_monitored_fence:         bool,
//     supports_map_on_default_buffer:       bool,
//     supports_map_no_overwrite_dynamic:    bool,
//     supports_partial_cbuffer_update:      bool,
//     supports_conservative_raster:         bool,
//     supports_typed_uav_load_more_formats: bool,
// }

// D3D11_Adapter_Impl :: struct {
//     dxgi_adapter:   ^dxgi.IAdapter2,
//     d3d_device:     ^d3d11.IDevice,
//     d3d_device3:    ^D3D11_IDevice3,
//     d3d_device5:    ^D3D11_IDevice5,
//     dxgi_desc:      dxgi.ADAPTER_DESC2,
//     caps:           D3D11_Adapter_Capabilities,
//     instance:       ^D3D11_Instance_Impl,
//     features:       []Feature_Name,
//     limits:         Limits,
//     driver_version: [4]u16,
//     handle:         D3D11_Adapter_Handle,
//     allocator:      runtime.Allocator,
//     adapter_type:   Device_Type,
//     ref:            Ref_Count_Type,
//     is_warp:        bool,
// }

// d3d11_adapter_get_impl :: #force_inline proc "contextless" (
//     adapter: Adapter,
//     loc := #caller_location,
// ) -> ^D3D11_Adapter_Impl {
//     assert_contextless(adapter != {}, "Invalid adapter", loc)
//     h := transmute(D3D11_Adapter_Handle)adapter
//     return hm.get(&gpu.d3d11.adapters, h)
// }

// d3d11_create_adapter :: proc(
//     instance: ^D3D11_Instance_Impl,
//     dxgi_adapter1: ^dxgi.IAdapter1,
// ) -> (
//     adapter: Adapter,
//     ok: bool,
// ) {
//     dxgi_adapter2: ^dxgi.IAdapter2
//     d3d_check_ok(dxgi_adapter1->QueryInterface(
//         dxgi.IAdapter2_UUID, cast(^rawptr)&dxgi_adapter2)) or_return
//     defer dxgi_adapter1->Release()

//     // Get adapter information
//     desc: dxgi.ADAPTER_DESC2
//     d3d_check_ok(dxgi_adapter2->GetDesc2(&desc)) or_return

//     // Get adapter name
//     device_name_buf: [128]u8
//     device_name := win32.wstring_to_utf8_buf(
//         device_name_buf[:], cstring16(raw_data(desc.Description[:])))

//     is_warp := strings.contains(device_name, "Microsoft Basic Render Driver")

//     // Driver version
//     umd_version: win32.LARGE_INTEGER
//     driver_version: [4]u16

//     if dxgi_adapter2->CheckInterfaceSupport(dxgi.IDevice_UUID, &umd_version) == win32.S_OK {
//         driver_version.x = u16(umd_version >> 48)
//         driver_version.y = u16(umd_version >> 32)
//         driver_version.z = u16(umd_version >> 16)
//         driver_version.w = u16(umd_version)
//     }

//     // Create device + immediate context, requesting the highest feature level
//     // the adapter supports.
//     FEATURE_LEVELS :: []d3d11.FEATURE_LEVEL {
//         ._11_1, ._11_0,
//     }

//     d3d_device: ^d3d11.IDevice
//     max_feature_level: d3d11.FEATURE_LEVEL

//     flags: d3d11.CREATE_DEVICE_FLAGS = {.BGRA_SUPPORT}
//     if .Debug in instance.flags {
//         flags |= {.DEBUG}
//     }

//     d3d_check_ok(d3d11.CreateDevice(
//         pAdapter           = cast(^dxgi.IAdapter)dxgi_adapter2,
//         DriverType         = .UNKNOWN, // ignored when pAdapter is non-nil
//         Software           = nil,
//         Flags              = flags,
//         pFeatureLevels     = raw_data(FEATURE_LEVELS),
//         FeatureLevels      = u32(len(FEATURE_LEVELS)),
//         SDKVersion         = d3d11.SDK_VERSION,
//         ppDevice           = &d3d_device,
//         pFeatureLevel      = &max_feature_level,
//         ppImmediateContext = nil,
//     )) or_return
//     defer if !ok { d3d_device->Release() }

//     if max_feature_level < ._11_0 {
//         log.warnf("D3D11 [%s]: unsupported feature level %v", device_name, max_feature_level)
//         return
//     }

//     d3d_device3: ^D3D11_IDevice3
//     hr := d3d_device->QueryInterface(D3D11_IDevice3_UUID, cast(^rawptr)&d3d_device3)
//     if win32.FAILED(hr) {
//         // IDevice3 unsupported on this driver/OS (needs Windows 10 1607+)
//         log.warnf("D3D11 [%s]: adapter does not support IDevice3", device_name)
//         return
//     }
//     defer if !ok { d3d_device3->Release() }

//     d3d_device5: ^D3D11_IDevice5
//     d3d_device3->QueryInterface(D3D11_IDevice5_UUID, cast(^rawptr)&d3d_device5)

//     // Double-precision shader support
//     doubles: d3d11.FEATURE_DATA_DOUBLES
//     has_doubles := d3d_device3->CheckFeatureSupport(
//         .DOUBLES, &doubles, size_of(doubles)) == win32.S_OK
//     shader_f64_supported := has_doubles && bool(doubles.DoublePrecisionFloatShaderOps)

//     // Format support queries
//     bgra8unorm_storage_supported: bool
//     {
//         info := d3d11.FEATURE_DATA_FORMAT_SUPPORT2{ InFormat = .B8G8R8A8_UNORM }
//         if d3d_device3->CheckFeatureSupport(.FORMAT_SUPPORT2, &info, size_of(info)) == win32.S_OK {
//             bgra8unorm_storage_supported =
//                 info.OutFormatSupport2 & u32(d3d11.FORMAT_SUPPORT2.UAV_TYPED_STORE) != {}
//         }
//     }

//     p010_supported: bool
//     {
//         info := d3d11.FEATURE_DATA_FORMAT_SUPPORT{ InFormat = .P010 }
//         if d3d_device3->CheckFeatureSupport(.FORMAT_SUPPORT, &info, size_of(info)) == win32.S_OK {
//             p010_supported =
//                 info.OutFormatSupport & u32(d3d11.FORMAT_SUPPORT.TEXTURE2D) != {} &&
//                 info.OutFormatSupport & u32(d3d11.FORMAT_SUPPORT.SHADER_LOAD) != {} &&
//                 info.OutFormatSupport & u32(d3d11.FORMAT_SUPPORT.SHADER_SAMPLE) != {}
//         }
//     }

//     max_shader_model : u32 = 50

//     supports_map_no_overwrite_dynamic_buffers: bool
//     supports_partial_constant_buffer_update: bool

//     options: d3d11.FEATURE_DATA_OPTIONS
//     if d3d_device3->CheckFeatureSupport(.OPTIONS, &options, size_of(options)) == win32.S_OK {
//         supports_map_no_overwrite_dynamic_buffers =
//             bool(options.MapNoOverwriteOnDynamicBufferSRV &&
//                  options.MapNoOverwriteOnDynamicConstantBuffer)
//         supports_partial_constant_buffer_update = bool(options.ConstantBufferPartialUpdate)
//     }

//     supports_map_on_default_buffer: bool

//     options1: d3d11.FEATURE_DATA_OPTIONS1
//     if d3d_device3->CheckFeatureSupport(.OPTIONS1, &options1, size_of(options1)) == win32.S_OK {
//         supports_map_on_default_buffer = bool(options1.MapOnDefaultBuffers)
//     }

//     options2: d3d11.FEATURE_DATA_OPTIONS2
//     d3d_check_ok(d3d_device3->CheckFeatureSupport(
//         .OPTIONS2, &options2, size_of(options2))) or_return

//     is_uma := bool(options2.UnifiedMemoryArchitecture)
//     supports_rov := bool(options2.ROVsSupported)
//     supports_typed_uav_load_additional_formats := bool(options2.TypedUAVLoadAdditionalFormats)
//     conservative_raster_tier := options2.ConservativeRasterizationTier
//     supports_conservative_raster :=
//         conservative_raster_tier != .CONSERVATIVE_RASTERIZATION_NOT_SUPPORTED

//     options3: d3d11.FEATURE_DATA_OPTIONS3
//     supports_vp_rt_array_index_without_gs_emulation: bool
//     if d3d_device3->CheckFeatureSupport(.OPTIONS3, &options3, size_of(options3)) == win32.S_OK {
//         supports_vp_rt_array_index_without_gs_emulation =
//             bool(options3.VPAndRTArrayIndexFromAnyShaderFeedingRasterizer)
//     }

//     supports_shared_resource_capability_tier2: bool

//     options5: d3d11.FEATURE_DATA_OPTIONS5
//     if d3d_device3->CheckFeatureSupport(.OPTIONS5, &options5, size_of(options5)) == win32.S_OK {
//         supports_shared_resource_capability_tier2 = options5.SharedResourceTier >= ._2
//     }

//     supports_monitored_fence: bool
//     supports_non_monitored_fence: bool

//     // TODO(Capati): dxgi.ADAPTER_FLAGS3 enum values are wrong in bindings.
//     // Using a locally corrected copy until an upstream PR lands.
//     ADAPTER_FLAGS3 :: bit_set[ADAPTER_FLAG3;u32]
//     ADAPTER_FLAG3 :: enum u32 {
//         REMOTE                       = 0, // 0x1
//         SOFTWARE                     = 1, // 0x2
//         ACG_COMPATIBLE               = 2, // 0x4
//         SUPPORT_MONITORED_FENCES     = 3, // 0x8
//         SUPPORT_NON_MONITORED_FENCES = 4, // 0x10
//         KEYED_MUTEX_CONFORMANCE      = 5, // 0x20
//     }

//     ADAPTER_DESC3 :: struct {
//         Description:                   [128]win32.WCHAR,
//         VendorId:                      u32,
//         DeviceId:                      u32,
//         SubSysId:                      u32,
//         Revision:                      u32,
//         DedicatedVideoMemory:          u64,
//         DedicatedSystemMemory:         u64,
//         SharedSystemMemory:            u64,
//         AdapterLuid:                   win32.LUID,
//         Flags:                         ADAPTER_FLAGS3,
//         GraphicsPreemptionGranularity: dxgi.GRAPHICS_PREEMPTION_GRANULARITY,
//         ComputePreemptionGranularity:  dxgi.COMPUTE_PREEMPTION_GRANULARITY,
//     }

//     adapter4: ^dxgi.IAdapter4
//     if win32.SUCCEEDED(dxgi_adapter2->QueryInterface(
//             dxgi.IAdapter4_UUID, cast(^rawptr)&adapter4),
//     ) {
//         defer adapter4->Release()
//         desc3: ADAPTER_DESC3
//         d3d_check_ok(adapter4->GetDesc3(cast(^dxgi.ADAPTER_DESC3)&desc3)) or_return
//         supports_monitored_fence = .SUPPORT_MONITORED_FENCES in desc3.Flags
//         supports_non_monitored_fence = .SUPPORT_NON_MONITORED_FENCES in desc3.Flags
//     }

//     adapter_type: Device_Type
//     if .SOFTWARE in desc.Flags {
//         adapter_type = .Cpu
//     } else {
//         adapter_type = .Integrated_GPU if is_uma else .Discrete_GPU
//     }

//     // Features always available at FL11.0+, plus queried optional ones below.
//     features := make([dynamic]Feature_Name, 0, len(Feature_Name), instance.allocator)

//     append(&features, Feature_Name.Depth_Clip_Control)
//     append(&features, Feature_Name.Indirect_First_Instance)
//     append(&features, Feature_Name.Multi_Draw_Indirect_Count)
//     append(&features, Feature_Name.Polygon_Mode_Line)
//     append(&features, Feature_Name.Timestamp_Query)
//     append(&features, Feature_Name.Texture_Compression_BC)
//     append(&features, Feature_Name.Texture_Compression_BC_Sliced_3D)
//     append(&features, Feature_Name.Clear_Texture)
//     append(&features, Feature_Name.Texture_Format_16Bit_Norm)
//     append(&features, Feature_Name.Texture_Format_Nv12)
//     append(&features, Feature_Name.Float32_Filterable)
//     append(&features, Feature_Name.Vertex_Writable_Storage)
//     append(&features, Feature_Name.Texture_Adapter_Specific_Format_Features)
//     append(&features, Feature_Name.Timestamp_Query_Inside_Encoders)
//     append(&features, Feature_Name.Timestamp_Query_Inside_Passes)
//     append(&features, Feature_Name.RG11B10Ufloat_Renderable)

//     if bgra8unorm_storage_supported {
//         append(&features, Feature_Name.BGRA8_Unorm_Storage)
//     }
//     if p010_supported {
//         append(&features, Feature_Name.Texture_Format_P010)
//     }
//     if shader_f64_supported {
//         append(&features, Feature_Name.Shader_F64)
//     }
//     if supports_conservative_raster {
//         append(&features, Feature_Name.Conservative_Rasterization)
//     }

//     slice.sort(features[:])

//     RESERVED_CBV_SLOTS :: 1
//     max_uniform_buffers_per_shader_stage: u32 =
//         d3d11.COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT - RESERVED_CBV_SLOTS // 13
//     max_sampled_textures_per_shader_stage: u32 =
//         d3d11.COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT // 128
//     max_samplers_per_shader_stage: u32 =
//         d3d11.COMMONSHADER_SAMPLER_SLOT_COUNT // 16

//     // At FL11.1, UAV slots are shared between the fragment and vertex stages,
//     // so the all-stage count is halved to get a per-stage figure. At FL11.0,
//     // only fragment and compute have UAVs at all (vertex has none), so the full
//     // count is available per stage with no division.
//     max_uav_all_stages: u32
//     max_uav_per_shader_stage: u32
//     if max_feature_level == ._11_1 {
//         max_uav_all_stages = d3d11._1_UAV_SLOT_COUNT
//         max_uav_per_shader_stage = max_uav_all_stages / 2
//     } else {
//         max_uav_all_stages = d3d11.PS_CS_UAV_REGISTER_COUNT
//         max_uav_per_shader_stage = max_uav_all_stages
//     }
//     max_storage_textures_per_shader_stage := max_uav_per_shader_stage / 2
//     max_storage_buffers_per_shader_stage := max_uav_per_shader_stage / 2

//     max_vertex_buffers: u32 : 16

//     D3D11_MIN_UNIFORM_BUFFER_OFFSET_ALIGNMENT :: 256

//     limits := Limits {
//         // WebGPU
//         max_texture_dimension_1d = d3d11.REQ_TEXTURE1D_U_DIMENSION,
//         max_texture_dimension_2d = d3d11.REQ_TEXTURE2D_U_OR_V_DIMENSION,
//         max_texture_dimension_3d = d3d11.REQ_TEXTURE3D_U_V_OR_W_DIMENSION,
//         max_texture_array_layers = d3d11.REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION,
//         max_bind_groups = MAX_BIND_GROUPS,
//         max_bind_groups_plus_vertex_buffers = MAX_BIND_GROUPS + max_vertex_buffers,
//         max_bindings_per_bind_group = max(u32),
//         max_dynamic_uniform_buffers_per_pipeline_layout = max_uniform_buffers_per_shader_stage,
//         max_dynamic_storage_buffers_per_pipeline_layout = max_storage_buffers_per_shader_stage,
//         max_sampled_textures_per_shader_stage = max_sampled_textures_per_shader_stage,
//         max_samplers_per_shader_stage = max_samplers_per_shader_stage,
//         max_storage_buffers_per_shader_stage = max_storage_buffers_per_shader_stage,
//         max_storage_textures_per_shader_stage = max_storage_textures_per_shader_stage,
//         max_uniform_buffers_per_shader_stage = max_uniform_buffers_per_shader_stage,
//         max_uniform_buffer_binding_size = u64(d3d11.REQ_CONSTANT_BUFFER_ELEMENT_COUNT) * 16,
//         max_storage_buffer_binding_size = ASSUMED_MAX_BUFFER_SIZE,
//         min_uniform_buffer_offset_alignment = D3D11_MIN_UNIFORM_BUFFER_OFFSET_ALIGNMENT,
//         min_storage_buffer_offset_alignment = d3d11.RAW_UAV_SRV_BYTE_ALIGNMENT,
//         max_vertex_buffers = max_vertex_buffers,
//         max_buffer_size = ASSUMED_MAX_BUFFER_SIZE,
//         max_vertex_attributes = d3d11.IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT - 2,
//         max_vertex_buffer_array_stride = d3d11.SO_BUFFER_MAX_STRIDE_IN_BYTES,
//         max_inter_stage_shader_variables = d3d11.PS_INPUT_REGISTER_COUNT - 2,
//         max_color_attachments = d3d11.SIMULTANEOUS_RENDER_TARGET_COUNT,
//         max_color_attachment_bytes_per_sample = d3d11.SIMULTANEOUS_RENDER_TARGET_COUNT * 16,
//         max_compute_workgroup_storage_size = 32768,
//         max_compute_invocations_per_workgroup = d3d11.CS_THREAD_GROUP_MAX_THREADS_PER_GROUP,
//         max_compute_workgroup_size_x = d3d11.CS_THREAD_GROUP_MAX_X,
//         max_compute_workgroup_size_y = d3d11.CS_THREAD_GROUP_MAX_Y,
//         max_compute_workgroup_size_z = d3d11.CS_THREAD_GROUP_MAX_Z,
//         max_compute_workgroups_per_dimension = d3d11.CS_DISPATCH_MAX_THREAD_GROUPS_PER_DIMENSION,
//         max_immediate_size = MAX_IMMEDIATE_DATA_BYTES,

//         // Native
//         max_non_sampler_bindings = 1_000_000,
//         max_binding_array_elements_per_shader_stage = 0,
//         max_binding_array_sampler_elements_per_shader_stage = 0,
//         max_multiview_view_count = 0,
//     }

//     sync.guard(&gpu.d3d11.mtx)

//     caps := D3D11_Adapter_Capabilities {
//         dedicated_video_memory               = desc.DedicatedVideoMemory,
//         shared_system_memory                 = desc.SharedSystemMemory,
//         max_shader_model                     = max_shader_model,
//         max_feature_level                    = max_feature_level,
//         is_uma                               = is_uma,
//         supports_rov                         = supports_rov,
//         supports_conservative_raster         = supports_conservative_raster,
//         conservative_raster_tier             = conservative_raster_tier,
//         supports_typed_uav_load_more_formats = supports_typed_uav_load_additional_formats,
//         supports_vp_rt_index_no_gs_emulation = supports_vp_rt_array_index_without_gs_emulation,
//         supports_map_no_overwrite_dynamic    = supports_map_no_overwrite_dynamic_buffers,
//         supports_partial_cbuffer_update      = supports_partial_constant_buffer_update,
//         supports_map_on_default_buffer       = supports_map_on_default_buffer,
//         supports_shared_resource_tier2       = supports_shared_resource_capability_tier2,
//         supports_monitored_fence             = supports_monitored_fence,
//         supports_non_monitored_fence         = supports_non_monitored_fence,
//     }

//     adapter_impl := hm_dynamic_add_get(&gpu.d3d11.adapters, D3D11_Adapter_Impl {
//         dxgi_adapter   = dxgi_adapter2,
//         d3d_device     = d3d_device,
//         d3d_device3    = d3d_device3,
//         d3d_device5    = d3d_device5,
//         caps           = caps,
//         dxgi_desc      = desc,
//         instance       = instance,
//         features       = features[:],
//         limits         = limits,
//         driver_version = driver_version,
//         allocator      = instance.allocator,
//         adapter_type   = adapter_type,
//         is_warp        = is_warp,
//     })

//     adapter = transmute(Adapter)adapter_impl.handle

//     init_ref(adapter_impl)
//     d3d11_instance_add_ref(Instance(instance))

//     return adapter, true
// }

// d3d11_adapter_get_features :: proc(
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := d3d11_adapter_get_impl(adapter, loc)
//     features.features = make([]Feature_Name, len(impl.features), allocator)
//     copy(features.features, impl.features)
//     return
// }

// d3d11_adapter_get_features_view :: proc(
//     adapter: Adapter,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := d3d11_adapter_get_impl(adapter, loc)
//     features.features = impl.features
//     return
// }

// d3d11_adapter_get_info :: proc(
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     info: Adapter_Info,
//     status: Status,
// ) {
//     impl := d3d11_adapter_get_impl(adapter, loc)

//     device_name_buf: [128]u8
//     device_name := win32.wstring_to_utf8_buf(
//         device_name_buf[:], cstring16(raw_data(impl.dxgi_desc.Description[:])))

//     driver_version_str := fmt.aprintf("%d.%d.%d.%d",
//         impl.driver_version.x, impl.driver_version.y,
//         impl.driver_version.z, impl.driver_version.w,
//         allocator = allocator)

//     info.device = strings.clone(device_name, allocator)
//     info.vendor = strings.clone(vendor_name(impl.dxgi_desc.VendorId), allocator)
//     info.description = driver_version_str
//     info.backend_type = .D3D11
//     info.vendor_id = impl.dxgi_desc.VendorId
//     info.device_id = impl.dxgi_desc.DeviceId
//     info.adapter_type = impl.adapter_type
//     info.subgroup_min_size = DEFAULT_SUBGROUP_MIN_SIZE
//     info.subgroup_max_size = DEFAULT_SUBGROUP_MAX_SIZE

//     return info, .Success
// }

// d3d11_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
//     impl := d3d11_adapter_get_impl(adapter, loc)
//     return impl.limits
// }

// d3d11_adapter_has_feature :: proc(
//     adapter: Adapter,
//     feature: Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     if feature == {} { return true }
//     impl := d3d11_adapter_get_impl(adapter)
//     _, found := slice.binary_search(impl.features, feature)
//     return found
// }

// d3d11_adapter_request_device :: proc(
//     adapter: Adapter,
//     descriptor: ^Device_Descriptor,
//     callback_info: Request_Device_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     // impl := d3d11_adapter_get_impl(adapter, loc)

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
//     device, device_ok := d3d11_create_device(adapter, desc, loc)
//     if !device_ok {
//         callback(callback_info, .Error, nil, "Failed to create logical device")
//         return {}
//     }

//     // Success
//     callback(callback_info, .Success, device, "")

//     return {}
// }

// d3d11_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
//     impl := d3d11_adapter_get_impl(adapter, loc)
//     add_ref(impl, loc)
// }

// d3d11_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
//     impl := d3d11_adapter_get_impl(adapter, loc)
//     if release_ref(impl) {
//         context.allocator = impl.allocator

//         if impl.d3d_device5 != nil {
//             impl.d3d_device5->Release()
//         }
//         impl.d3d_device3->Release()
//         impl.d3d_device->Release()
//         impl.dxgi_adapter->Release()

//         delete(impl.features)
//         d3d11_instance_release(Instance(impl.instance))

//         sync.guard(&gpu.d3d11.mtx)
//         hm.remove(&gpu.d3d11.adapters, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Adapter private procedures
// // -----------------------------------------------------------------------------

// d3d11_adapter_texture_format_capabilities :: proc(
//     adapter: Adapter,
//     format: Texture_Format,
//     loc := #caller_location,
// ) -> (caps: Texture_Format_Capabilities) {
//     assert(format != .Undefined, "Invalid texture format", loc)

//     impl := d3d11_adapter_get_impl(adapter, loc)

//     dxgi_format := d3d_conv_to_dxgi_format(format)
//     if dxgi_format == .UNKNOWN {
//         return
//     }

//     srv_uav_format: dxgi.FORMAT
//     if texture_format_is_combined_depth_stencil_format(format, loc) {
//         srv_uav_format = d3d_conv_format_for_srv_uav(format, {.Depth}, loc)
//     } else {
//         srv_uav_format = d3d_conv_format_for_srv_uav(
//             format, texture_format_aspects_from(format), loc)
//     }

//     support: u32
//     if win32.FAILED(impl.d3d_device->CheckFormatSupport(dxgi_format, &support)) {
//         return {}
//     }

//     support_srv_uav := support
//     if srv_uav_format != dxgi_format {
//         if win32.FAILED(
//                 impl.d3d_device->CheckFormatSupport(srv_uav_format, &support_srv_uav )) {
//             support_srv_uav = 0
//         }
//     }

//     support2: d3d11.FEATURE_DATA_FORMAT_SUPPORT2
//     support2.InFormat = srv_uav_format
//     impl.d3d_device->CheckFeatureSupport(.FORMAT_SUPPORT2, &support2, size_of(support2))
//     out_format2 := support2.OutFormatSupport2

//     has :: proc(mask: u32, flag: d3d11.FORMAT_SUPPORT) -> bool {
//         return mask & u32(flag) != 0
//     }
//     has2 :: proc(mask: u32, flag: d3d11.FORMAT_SUPPORT2) -> bool {
//         return mask & u32(flag) != 0
//     }

//     caps |= {.Copy_Src, .Copy_Dst}

//     is_texture :=
//         has(support, .TEXTURE1D) ||
//         has(support, .TEXTURE2D) ||
//         has(support, .TEXTURE3D) ||
//         has(support, .TEXTURECUBE)

//     if is_texture && (has(support_srv_uav, .SHADER_LOAD)) {
//         caps |= {.Sampled}
//     }
//     if has(support_srv_uav, .SHADER_SAMPLE) {
//         caps |= {.Sampled_Linear}
//     }

//     if has(support, .RENDER_TARGET) {
//         caps |= {.Color_Attachment}
//     }
//     if has(support, .BLENDABLE) {
//         caps |= {.Color_Attachment_Blend}
//     }
//     if has(support, .DEPTH_STENCIL) {
//         caps |= {.Depth_Stencil_Attachment}
//     }

//     storage_read_only := has2(out_format2, .UAV_TYPED_LOAD)
//     storage_write_only := has2(out_format2, .UAV_TYPED_STORE)
//     if storage_read_only {
//         caps |= {.Storage_Read_Only}
//     }
//     if storage_write_only {
//         caps |= {.Storage_Write_Only}
//     }
//     if storage_read_only && storage_write_only {
//         caps |= {.Storage_Read_Write}
//     }

//     if has2(out_format2, .UAV_ATOMIC_UNSIGNED_MIN_OR_MAX) {
//         caps |= {.Storage_Atomic}
//     }

//     no_msaa_load := .Sampled in caps && !has(support_srv_uav, .MULTISAMPLE_LOAD)
//     no_msaa_target :=
//         (has(support, .RENDER_TARGET) || has(support, .DEPTH_STENCIL)) &&
//         !has(support, .MULTISAMPLE_RENDERTARGET)

//     if has(support, .MULTISAMPLE_RESOLVE) {
//         caps |= {.Multisample_Resolve}
//     }

//     set_sample_count :: proc(
//         impl: ^D3D11_Adapter_Impl,
//         dxgi_format: dxgi.FORMAT,
//         sample_count: u32,
//         flag: Texture_Format_Capabilities_Flags,
//         no_msaa_load, no_msaa_target: bool,
//         caps: ^Texture_Format_Capabilities,
//     ) {
//         num_quality_levels: u32
//         hr := impl.d3d_device->CheckMultisampleQualityLevels(
//             dxgi_format,
//             sample_count,
//             &num_quality_levels,
//         )
//         if win32.SUCCEEDED(hr) && num_quality_levels != 0 && !no_msaa_load && !no_msaa_target {
//             caps^ |= {flag}
//         }
//     }

//     set_sample_count(
//         impl, dxgi_format, 2, .Multisample_X2, no_msaa_load, no_msaa_target, &caps)
//     set_sample_count(
//         impl, dxgi_format, 4, .Multisample_X4, no_msaa_load, no_msaa_target, &caps)
//     set_sample_count(
//         impl, dxgi_format, 8, .Multisample_X8, no_msaa_load, no_msaa_target, &caps)
//     set_sample_count(
//         impl, dxgi_format, 16, .Multisample_X16, no_msaa_load, no_msaa_target, &caps)

//     return
// }

// // -----------------------------------------------------------------------------
// // Procedures of Adapter_Info
// // -----------------------------------------------------------------------------

// d3d11_adapter_info_free_members :: proc(
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

// D3D11_Bind_Group_Handle :: distinct hm.Handle64

// D3D11_Bind_Group_Impl :: struct {
//     device:  Device,
//     layout:  Bind_Group_Layout,
//     entries: []Bind_Group_Entry,
//     handle:  D3D11_Bind_Group_Handle,
//     ref:     Ref_Count_Type,
// }

// d3d11_bind_group_get_impl :: #force_inline proc "contextless" (
//     bind_group: Bind_Group,
//     loc := #caller_location,
// ) -> ^D3D11_Bind_Group_Impl {
//     assert_contextless(bind_group != {}, "Invalid bind group", loc)
//     h := id_to_handle(bind_group)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := D3D11_Bind_Group_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.bind_groups, map_handle)
// }

// d3d11_bind_group_set_label :: proc(
//     bind_group: Bind_Group, label: string, loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
//     impl := d3d11_bind_group_get_impl(bind_group, loc)
//     add_ref(impl, loc)
// }

// d3d11_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
//     impl := d3d11_bind_group_get_impl(bind_group, loc)
//     if release_ref(impl) {
//         d3d11_bind_group_layout_release(impl.layout, loc)
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         delete(impl.entries, device_impl.allocator)
//         hm.remove(&device_impl.bind_groups, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Bind_Group_Layout
// // -----------------------------------------------------------------------------

// D3D11_Bind_Group_Layout_Handle :: distinct hm.Handle64

// D3D11_Bind_Group_Layout_Impl :: struct {
//     device:  Device,
//     entries: []Bind_Group_Layout_Entry,
//     handle:  D3D11_Bind_Group_Layout_Handle,
//     ref:     Ref_Count_Type,
// }

// d3d11_bind_group_layout_get_impl :: #force_inline proc "contextless" (
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) -> ^D3D11_Bind_Group_Layout_Impl {
//     assert_contextless(bind_group_layout != {}, "Invalid bind group", loc)
//     h := id_to_handle(bind_group_layout)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := D3D11_Bind_Group_Layout_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.bind_group_layouts, map_handle)
// }

// d3d11_is_uniform_binding :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     return e.buffer.type == .Uniform
// }

// d3d11_is_readonly_storage_buffer :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     return e.buffer.type == .Read_Only_Storage
// }

// d3d11_is_sampler_binding :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     return e.sampler.type != .Binding_Not_Used
// }

// d3d11_is_texture_binding :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     return e.texture.sample_type != .Binding_Not_Used
// }

// d3d11_is_readonly_storage_texture :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     return e.storage_texture.access == .Read_Only
// }

// d3d11_is_uav_binding :: proc(e: Bind_Group_Layout_Entry) -> bool {
//     if e.buffer.type == .Storage {
//         return true
//     }
//     if e.storage_texture.access == .Write_Only || e.storage_texture.access == .Read_Write {
//         return true
//     }
//     return false
// }

// d3d11_bind_group_layout_set_label :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_bind_group_layout_add_ref :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) {
//     impl := d3d11_bind_group_layout_get_impl(bind_group_layout, loc)
//     add_ref(impl, loc)
// }

// d3d11_bind_group_layout_release :: proc(
//     bind_group_layout: Bind_Group_Layout,
//     loc := #caller_location,
// ) {
//     impl := d3d11_bind_group_layout_get_impl(bind_group_layout, loc)
//     if release_ref(impl) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         delete(impl.entries, device_impl.allocator)
//         hm.remove(&device_impl.bind_group_layouts, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Buffer
// // -----------------------------------------------------------------------------

// D3D11_Buffer_Handle :: distinct hm.Handle64

// // Storage entry used to sync different type of buffer access.
// D3D11_Storage_Plan_Entry :: struct {
//     storage_type: D3D11_Buffer_Storage_Type,
//     // the non_uniform_usage that would be passed to bind-flag computation
//     uses:         Buffer_Uses,
//     is_mappable:  bool,
// }

// D3D11_MAX_BUFFER_STORAGES :: 3

// D3D11_BUFFER_USES_GPU_WRITE :: Buffer_Uses{.Storage_Read_Write, .Indirect}

// D3D11_Storage_Plan :: [dynamic; D3D11_MAX_BUFFER_STORAGES]D3D11_Storage_Plan_Entry

// D3D11_Buffer_View_Key :: struct {
//     d3d11_buffer: ^d3d11.IBuffer,
//     offset:       u64,
//     size:         u64,
// }

// D3D11_Buffer_Impl :: struct {
//     storages:             [D3D11_Buffer_Storage_Type]D3D11_Buffer_Storage,
//     device:               Device,
//     handle:               D3D11_Buffer_Handle,
//     size:                 u64,
//     allocated_size:       u32,
//     usage:                Buffer_Usages,
//     internal_uses:        Buffer_Uses,
//     ref:                  Ref_Count_Type,
//     last_updated_storage: D3D11_Buffer_Storage_Type,
//     mappable_storage:     D3D11_Buffer_Storage_Type,
//     map_state:            Buffer_Map_State_Impl,
//     srv_cache:            map[D3D11_Buffer_View_Key]^d3d11.IShaderResourceView,
//     uav_cache:            map[D3D11_Buffer_View_Key]^D3D11_IUnorderedAccessView1,
//     has_last_updated:     bool,
//     has_mappable:         bool,
// }

// d3d11_buffer_get_impl :: #force_inline proc "contextless" (
//     buffer: Buffer,
//     loc := #caller_location,
// ) -> ^D3D11_Buffer_Impl {
//     assert_contextless(buffer != {}, "Invalid buffer", loc)
//     h := id_to_handle(buffer)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := D3D11_Buffer_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.buffers, map_handle)
// }

// d3d11_buffer_incr_storage_rev_and_make_latest :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     dst_storage: ^D3D11_Buffer_Storage,
//     device_impl: ^D3D11_Device_Impl,
//     loc := #caller_location,
// ) {
//     last_updated_storage := &buffer.storages[buffer.last_updated_storage]
//     assert(dst_storage.revision == last_updated_storage.revision, loc = loc)

//     d3d11_buffer_storage_set_revision(dst_storage, dst_storage.revision + 1)
//     buffer.last_updated_storage = d3d11_buffer_storage_get_storage_type(dst_storage)
//     buffer.has_last_updated     = true

//     if !d3d11_buffer_storage_is_gpu_writable(dst_storage) {
//         return
//     }
//     if !buffer.has_mappable {
//         return
//     }
//     if buffer.mappable_storage == dst_storage.storage_type {
//         return
//     }

//     if d3d11_buffer_storage_is_gpu_writable(dst_storage) \
//         && d3d11_buffer_is_mappable(buffer.internal_uses) \
//         &&  buffer.mappable_storage != dst_storage.storage_type {

//         buffer_handle := handle_make(buffer.handle, device_impl.handle)
//         d3d11_queue_add_buffer_for_cpu_sync(
//             &device_impl.queue, handle_to_raw(Buffer, buffer_handle))
//     }
// }

// d3d11_buffer_get_constant_buffer :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     ctx: ^D3D11_IDeviceContext3,
//     loc := #caller_location,
// ) -> ^d3d11.IBuffer {
//     current := &buffer.storages[buffer.last_updated_storage]

//     if d3d11_buffer_storage_is_constant_buffer(current) {
//         return d3d11_buffer_storage_get_buffer(current)
//     }

//     cb_storage := d3d11_buffer_get_or_create_storage(buffer, .GPU_Copy_Dst_Constant_Buffer, loc)

//     if cb_storage.revision != current.revision {
//         ctx->CopyResource(
//             d3d11_buffer_storage_get_buffer(cb_storage),
//             d3d11_buffer_storage_get_buffer(current),
//         )
//         d3d11_buffer_storage_set_revision(cb_storage, current.revision)
//     }

//     return d3d11_buffer_storage_get_buffer(cb_storage)
// }

// d3d11_buffer_get_non_constant_buffer :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     ctx: ^d3d11.IDeviceContext,
//     loc := #caller_location,
// ) -> ^d3d11.IBuffer {
//     cpu_storage := &buffer.storages[.CPU_Writable_Non_Constant_Buffer]
//     last_updated := &buffer.storages[buffer.last_updated_storage]

//     if cpu_storage.buffer != nil && cpu_storage.revision == last_updated.revision {
//         // CPUWritableNonConstantBuffer is up to date, use it directly.
//         return d3d11_buffer_storage_get_buffer(cpu_storage)
//     }

//     // Otherwise use (and sync) GPUWritableNonConstantBuffer, either it's
//     // already current, or a CopyResource is cheaper than a CPU-side memcpy.
//     gpu_storage := d3d11_buffer_get_or_create_storage(
//         buffer, .GPU_Writable_Non_Constant_Buffer, loc)
//     d3d11_buffer_sync_storage(buffer, gpu_storage, ctx, loc)
//     return d3d11_buffer_storage_get_buffer(gpu_storage)
// }

// d3d11_buffer_sync_storage :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     dst_storage: ^D3D11_Buffer_Storage,
//     ctx: ^d3d11.IDeviceContext,
//     loc := #caller_location,
// ) {
//     current := &buffer.storages[buffer.last_updated_storage]
//     if current.revision == dst_storage.revision {
//         return
//     }

//     if d3d11_buffer_storage_supports_copy_dst(dst_storage) {
//         ctx->CopyResource(
//             d3d11_buffer_storage_get_buffer(dst_storage),
//             d3d11_buffer_storage_get_buffer(current),
//         )
//         d3d11_buffer_storage_set_revision(dst_storage, current.revision)
//         return
//     }

//     // Slow path: dst can't be a CopyResource target (e.g. DYNAMIC/mappable storage).
//     // Sync through Staging, then Map(READ) + Map(WRITE_DISCARD) + memcpy.
//     assert(d3d11_buffer_storage_is_cpu_writable(dst_storage),
//         "sync target must be CPU-writable if not Copy_Dst-capable", loc)

//     staging := d3d11_buffer_get_or_create_storage(buffer, .Staging, loc)
//     // recursive: brings staging up to date
//     d3d11_buffer_sync_storage(buffer, staging, ctx, loc)

//     mapped_src: d3d11.MAPPED_SUBRESOURCE
//     d3d_check(ctx->Map(
//         d3d11_buffer_storage_get_buffer(staging), 0, .READ, {}, &mapped_src))

//     mapped_dst: d3d11.MAPPED_SUBRESOURCE
//     map_err := ctx->Map(
//         d3d11_buffer_storage_get_buffer(dst_storage), 0, .WRITE_DISCARD, {}, &mapped_dst)
//     if map_err == 0 {
//         mem.copy(mapped_dst.pData, mapped_src.pData, int(buffer.allocated_size))
//         ctx->Unmap(d3d11_buffer_storage_get_buffer(dst_storage), 0)
//     }

//     ctx->Unmap(d3d11_buffer_storage_get_buffer(staging), 0)
//     d3d_check(map_err)

//     d3d11_buffer_storage_set_revision(dst_storage, current.revision)
// }

// d3d11_buffer_sync_gpu_writes_to_staging :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     device_impl: ^D3D11_Device_Impl,
//     loc := #caller_location,
// ) {
//     assert(d3d11_buffer_is_mappable(buffer.internal_uses), "buffer must be mappable", loc)
//     staging := d3d11_buffer_get_or_create_storage(buffer, .Staging, loc)
//     d3d11_buffer_sync_storage(buffer, staging, device_impl.ctx.d3d_context, loc)
// }

// d3d11_buffer_get_gpu_usable_storage :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     loc := #caller_location,
// ) -> ^D3D11_Buffer_Storage {
//     storage := &buffer.storages[buffer.last_updated_storage]
//     assert(storage.buffer != nil, "buffer storage not allocated", loc)
//     return storage
// }

// // D3D11_BIND_INDEX_BUFFER as a harmless placeholder bind flag: D3D11_USAGE_DYNAMIC
// // requires at least one bind flag, even when the buffer is e.g. Map_Write |
// // Query_Resolve with no real GPU-visible binding.
// d3d11_ensure_nonzero_bind_flags :: proc(flags: d3d11.BIND_FLAGS) -> d3d11.BIND_FLAGS {
//     if flags == {} {
//         return {.INDEX_BUFFER}
//     }
//     return flags
// }

// // True only when the buffer has both a GPU-writable side (which needs
// // syncing out) and a CPU-visible side (mappable or staging) it must be
// // synced into. A buffer that's purely GPU-writable, or purely CPU-mappable,
// // never needs this internal copy.
// d3d11_needs_gpu_to_staging_sync :: #force_inline proc "contextless" (
//     uses: Buffer_Uses,
// ) -> bool {
//     has_gpu_writable := (uses & D3D11_BUFFER_USES_GPU_WRITE) != {}
//     has_cpu_visible  := .Map_Read in uses ||
//                          (uses & BUFFER_USES_STAGING) == BUFFER_USES_STAGING
//     return has_gpu_writable && has_cpu_visible
// }

// d3d11_buffer_needs_gpu_to_staging_sync :: proc "contextless" (
//     buffer: ^D3D11_Buffer_Impl,
// ) -> bool {
//     return d3d11_needs_gpu_to_staging_sync(buffer.internal_uses)
// }

// // Any buffer whose GPU-writable storage may need to be
// // synced into Staging (for Map_Read, or for the CPU-writable/staging
// // fallback path) implicitly needs Copy_Src-shaped capability on that
// // storage, regardless of whether the app requested Copy_Src.
// d3d11_get_effective_uses :: #force_inline proc "contextless" (
//     uses: Buffer_Uses,
// ) -> Buffer_Uses {
//     if d3d11_needs_gpu_to_staging_sync(uses) {
//         return uses + {.Copy_Src}
//     }
//     return uses
// }

// d3d11_buffer_get_effective_uses :: proc "contextless" (
//     buffer: ^D3D11_Buffer_Impl,
// ) -> Buffer_Uses {
//     return d3d11_get_effective_uses(buffer.internal_uses)
// }

// d3d11_plan_buffer_storages :: proc(internal_uses: Buffer_Uses) -> (plan: D3D11_Storage_Plan) {
//     usages_to_handle := internal_uses

//     if .Map_Read in usages_to_handle {
//         append(&plan, D3D11_Storage_Plan_Entry{.Staging, {}, true})
//         usages_to_handle &= ~BUFFER_USES_STAGING
//     }

//     if .Uniform in usages_to_handle {
//         usages_to_handle &= ~{.Uniform, .Copy_Src}

//         if .Map_Write in usages_to_handle {
//             usages_to_handle &= ~{.Map_Write}
//             append(&plan, D3D11_Storage_Plan_Entry{.CPU_Writable_Constant_Buffer, {}, true})
//         } else {
//             usages_to_handle &= ~{.Copy_Dst}
//             append(&plan, D3D11_Storage_Plan_Entry{.GPU_Copy_Dst_Constant_Buffer, {}, false})
//         }
//     }

//     if usages_to_handle == {} {
//         return plan
//     }

//     if .Map_Write in usages_to_handle {
//         usages_to_handle &= ~{.Map_Write}
//         non_uniform := internal_uses & ~{.Uniform, .Storage_Read_Write}
//         append(&plan, D3D11_Storage_Plan_Entry{
//             storage_type = .CPU_Writable_Non_Constant_Buffer,
//             uses = non_uniform,
//             is_mappable = true,
//         })
//     } else {
//         usages_to_handle &= ~{.Copy_Dst}
//         non_uniform := (d3d11_get_effective_uses(internal_uses) \
//             & ~{.Uniform}) & ~BUFFER_USES_MAPPABLE
//         append(&plan, D3D11_Storage_Plan_Entry{
//             storage_type = .GPU_Writable_Non_Constant_Buffer,
//             uses = non_uniform,
//             is_mappable = false,
//         })
//     }

//     return plan
// }

// d3d11_buffer_get_or_create_dst_copyable_storage :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     loc := #caller_location,
// ) -> ^D3D11_Buffer_Storage {
//     if buffer.storages[.GPU_Copy_Dst_Constant_Buffer].buffer != nil {
//         return &buffer.storages[.GPU_Copy_Dst_Constant_Buffer]
//     }
//     if buffer.storages[.GPU_Writable_Non_Constant_Buffer].buffer != nil {
//         return &buffer.storages[.GPU_Writable_Non_Constant_Buffer]
//     }
//     if .Uniform in buffer.internal_uses {
//         return d3d11_buffer_get_or_create_storage(buffer, .GPU_Copy_Dst_Constant_Buffer, loc)
//     }
//     return d3d11_buffer_get_or_create_storage(buffer, .GPU_Writable_Non_Constant_Buffer, loc)
// }

// d3d11_buffer_get_or_create_storage :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     storage_type: D3D11_Buffer_Storage_Type,
//     loc := #caller_location,
// ) -> ^D3D11_Buffer_Storage {
//     if buffer.storages[storage_type].buffer != nil {
//         return &buffer.storages[storage_type]
//     }

//     impl := d3d11_device_get_impl(buffer.device, loc)

//     buf_desc := d3d11.BUFFER_DESC{
//         ByteWidth           = buffer.allocated_size,
//         StructureByteStride = 0,
//     }

//     switch storage_type {
//     case .CPU_Writable_Constant_Buffer:
//         buf_desc.Usage          = .DYNAMIC
//         buf_desc.CPUAccessFlags = {.WRITE}
//         buf_desc.BindFlags      = {.CONSTANT_BUFFER}
//         buf_desc.MiscFlags      = {}

//     case .GPU_Copy_Dst_Constant_Buffer:
//         buf_desc.Usage          = .DEFAULT
//         buf_desc.CPUAccessFlags = {}
//         buf_desc.BindFlags      = {.CONSTANT_BUFFER}
//         buf_desc.MiscFlags      = {}

//     case .CPU_Writable_Non_Constant_Buffer:
//         // Exclude GPU-write-only usages: a CPU-writable (DYNAMIC) buffer can't also be
//         // GPU-writable in D3D11 (no UAV on DYNAMIC resources).
//         non_uniform_usage := buffer.internal_uses & ~{.Uniform, .Storage_Read_Write}
//         buf_desc.Usage          = .DYNAMIC
//         buf_desc.CPUAccessFlags = {.WRITE}
//         buf_desc.BindFlags      = d3d11_ensure_nonzero_bind_flags(
//             d3d11_conv_to_buffer_bind_flags(non_uniform_usage))
//         buf_desc.MiscFlags      = d3d11_conv_to_buffer_misc_flags(non_uniform_usage)

//     case .GPU_Writable_Non_Constant_Buffer:
//         non_uniform_usage := (d3d11_buffer_get_effective_uses(buffer) \
//             & ~{.Uniform}) & ~BUFFER_USES_MAPPABLE
//         // effective uses here means: if this buffer will need syncing to Staging later,
//         // its GPU-writable storage picks up Copy_Src capability now, at creation time,
//         // since D3D11 buffer bind flags can't be changed after CreateBuffer.
//         buf_desc.Usage          = .DEFAULT
//         buf_desc.CPUAccessFlags = {}
//         buf_desc.BindFlags      = d3d11_conv_to_buffer_bind_flags(non_uniform_usage)
//         buf_desc.MiscFlags      = d3d11_conv_to_buffer_misc_flags(non_uniform_usage)

//     case .Staging:
//         buf_desc.Usage          = .STAGING
//         buf_desc.CPUAccessFlags = {.READ, .WRITE}
//         buf_desc.BindFlags      = {}
//         buf_desc.MiscFlags      = {}
//     }

//     d3d11_buffer: ^d3d11.IBuffer
//     d3d_check(impl.d3d_device->CreateBuffer(&buf_desc, nil, &d3d11_buffer))

//     d3d11_buffer_storage_init(&buffer.storages[storage_type], d3d11_buffer, storage_type)
//     return &buffer.storages[storage_type]
// }

// d3d11_buffer_initialize_impl :: proc(buffer: ^D3D11_Buffer_Impl, loc := #caller_location) {
//     plan := d3d11_plan_buffer_storages(buffer.internal_uses)

//     for &entry in plan {
//         storage := d3d11_buffer_get_or_create_storage(buffer, entry.storage_type, loc)
//         assert(storage != nil, loc = loc)
//         buffer.last_updated_storage = entry.storage_type
//         buffer.has_last_updated     = true
//         if entry.is_mappable {
//             buffer.mappable_storage = entry.storage_type
//             buffer.has_mappable     = true
//         }
//     }
// }

// d3d11_buffer_is_mappable :: #force_inline proc "contextless" (uses: Buffer_Uses) -> bool {
//     return (uses & {.Map_Read, .Map_Write}) != {}
// }

// d3d11_buffer_create_srv_from_d3d_buffer :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     d3d11_buffer: ^d3d11.IBuffer,
//     offset: u64,
//     original_size: u64,
//     loc := #caller_location,
// ) -> ^d3d11.IShaderResourceView {
//     size := align_size(original_size, 4)
//     assert(offset % 4 == 0, "SRV offset must be 4-byte aligned", loc)
//     assert(size <= u64(buffer.allocated_size), "SRV size exceeds allocated buffer size", loc)

//     first_element := u32(offset / 4)
//     num_elements := u32(size / 4)

//     desc := d3d11.SHADER_RESOURCE_VIEW_DESC{
//         Format        = .R32_TYPELESS,
//         ViewDimension = .BUFFEREX,
//         BufferEx = {
//             FirstElement = first_element,
//             NumElements  = num_elements,
//             Flags        = {.RAW},
//         },
//     }

//     impl := d3d11_device_get_impl(buffer.device, loc)
//     srv: ^d3d11.IShaderResourceView
//     d3d_check(impl.d3d_device->CreateShaderResourceView(d3d11_buffer, &desc, &srv))
//     return srv
// }

// d3d11_buffer_create_uav_from_d3d_buffer :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     d3d11_buffer: ^d3d11.IBuffer,
//     offset: u64,
//     original_size: u64,
//     loc := #caller_location,
// ) -> ^D3D11_IUnorderedAccessView1 {
//     size := align_size(original_size, 4)
//     assert(offset % 4 == 0, "UAV offset must be 4-byte aligned", loc)
//     assert(size <= u64(buffer.allocated_size), "UAV size exceeds allocated buffer size", loc)

//     first_element := u32(offset / 4)
//     num_elements := u32(size / 4)

//     desc := D3D11_UNORDERED_ACCESS_VIEW_DESC1{
//         Format        = .R32_TYPELESS,
//         ViewDimension = .BUFFER,
//         Buffer = {
//             FirstElement = first_element,
//             NumElements  = num_elements,
//             Flags        = {.RAW},
//         },
//     }

//     impl := d3d11_device_get_impl(buffer.device, loc)
//     uav: ^D3D11_IUnorderedAccessView1
//     d3d_check(impl.d3d_device3->CreateUnorderedAccessView1(d3d11_buffer, &desc, &uav))
//     return uav
// }

// d3d11_buffer_get_or_create_srv :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     ctx: ^d3d11.IDeviceContext,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) -> ^d3d11.IShaderResourceView {
//     d3d_buffer := d3d11_buffer_get_non_constant_buffer(buffer, ctx, loc)

//     key := D3D11_Buffer_View_Key{d3d_buffer, offset, size}
//     if cached, ok := buffer.srv_cache[key]; ok {
//         return cached
//     }

//     srv := d3d11_buffer_create_srv_from_d3d_buffer(buffer, d3d_buffer, offset, size, loc)
//     buffer.srv_cache[key] = srv
//     return srv
// }

// d3d11_buffer_get_or_create_uav :: proc(
//     buffer: ^D3D11_Buffer_Impl,
//     ctx: ^d3d11.IDeviceContext,
//     device_impl: ^D3D11_Device_Impl,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) -> ^D3D11_IUnorderedAccessView1 {
//     storage := d3d11_buffer_get_or_create_storage(buffer, .GPU_Writable_Non_Constant_Buffer, loc)
//     d3d11_buffer_sync_storage(buffer, storage, ctx, loc)

//     d3d_buffer := d3d11_buffer_storage_get_buffer(storage)
//     key := D3D11_Buffer_View_Key{d3d_buffer, offset, size}

//     uav: ^D3D11_IUnorderedAccessView1
//     if cached, ok := buffer.uav_cache[key]; ok {
//         uav = cached
//     } else {
//         uav = d3d11_buffer_create_uav_from_d3d_buffer(buffer, d3d_buffer, offset, size, loc)
//         buffer.uav_cache[key] = uav
//     }

//     // Shader will write through this UAV: bump revision and mark this
//     // storage as the current source of truth, same as any other GPU write.
//     d3d11_buffer_incr_storage_rev_and_make_latest(buffer, storage, device_impl, loc)

//     return uav
// }

// d3d11_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_get_const_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint = 0,
//     size: uint = WHOLE_MAP_SIZE,
//     loc := #caller_location,
// ) -> rawptr {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_get_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint = 0,
//     size: uint = WHOLE_MAP_SIZE,
//     loc := #caller_location,
// ) -> rawptr {
//     impl := d3d11_buffer_get_impl(buffer, loc)

//     range_size := buffer_get_mapped_range_size(impl.size, size, offset, loc)

//     switch &state in impl.map_state {
//     case Buffer_Map_State_Init:
//         staging_impl := d3d11_buffer_get_impl(state.staging_buffer.buffer, loc)
//         assert(offset <= uint(staging_impl.size), "map start offset overrun", loc)
//         assert(u64(offset) + range_size <= staging_impl.size, "map end offset overrun", loc)
//         return rawptr(uintptr(state.staging_buffer.ptr) + uintptr(offset))

//     case Buffer_Map_State_Active:
//         assert(offset <= uint(state.range.start), "map start offset overrun", loc)
//         assert(u64(offset) + u64(range_size) <= state.range.end, "map end offset overrun", loc)
//         return rawptr(uintptr(state.ptr) + uintptr(offset))

//     case Buffer_Pending_Mapping:
//         panic("buffer is waiting on GPU sync before it can be mapped", loc)

//     case Buffer_Map_State_Idle:
//         panic("buffer is not mapped", loc)
//     }

//     unreachable()
// }

// d3d11_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
//     impl := d3d11_buffer_get_impl(buffer, loc)
//     return impl.size
// }

// d3d11_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_map_async :: proc(
//     buffer: Buffer,
//     mode: Map_Modes,
//     offset: uint,
//     size: uint,
//     callback_info: Buffer_Map_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_map_sync :: proc(
//     buffer: Buffer,
//     mode: Map_Modes,
//     offset: uint,
//     size: uint,
//     loc := #caller_location,
// ) -> rawptr {
//     impl := d3d11_buffer_get_impl(buffer, loc)

//     mapping := impl.map_state
//     impl.map_state = Buffer_Map_State_Idle{}

//     pending: Buffer_Pending_Mapping
//     #partial switch &state in mapping {
//     case Buffer_Pending_Mapping:
//         pending = state
//     case Buffer_Map_State_Idle:
//         return nil // mapping cancelled
//     case Buffer_Map_State_Active:
//         impl.map_state = mapping
//         return nil // already mapped, no-op
//     case:
//         panic("No pending mapping.", loc)
//     }

//     device_impl := d3d11_device_get_impl(impl.device, loc)
//     storage := &impl.storages[impl.mappable_storage]

//     is_dynamic := impl.mappable_storage == .CPU_Writable_Constant_Buffer ||
//                   impl.mappable_storage == .CPU_Writable_Non_Constant_Buffer

//     if !(is_dynamic && .Read not_in mode) {
//         // Bring the mappable storage up to date with current updated
//         d3d11_buffer_sync_storage(impl, storage, device_impl.ctx.d3d_context, loc)
//     }

//     map_type: d3d11.MAP
//     switch {
//     case is_dynamic:
//         assert(.Read not_in mode, "CPU_Writable storages do not support Map_Read", loc)
//         map_type = .WRITE_DISCARD

//     case .Read in mode && .Write in mode:
//         map_type = .READ_WRITE

//     case .Read in mode:
//         map_type = .READ

//     case .Write in mode:
//         map_type = .WRITE

//     case:
//         panic("Map_Modes must include at least one of Read or Write", loc)
//     }

//     mapped: d3d11.MAPPED_SUBRESOURCE
//     d3d_check(device_impl.ctx.d3d_context->Map(storage.buffer, 0, map_type, {}, &mapped))

//     impl.map_state = Buffer_Map_State_Active{
//         mapping = {ptr = mapped.pData, is_coherent = true},
//         range   = pending.range,
//         mode    = pending.op.mode,
//     }

//     return mapped.pData
// }

// d3d11_buffer_read_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) -> Status {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
//     unmap_active_storage :: proc(
//         impl: ^D3D11_Buffer_Impl,
//         device_impl: ^D3D11_Device_Impl,
//         loc := #caller_location,
//     ) {
//         storage := &impl.storages[impl.mappable_storage]
//         device_impl.ctx.d3d_context->Unmap(d3d11_buffer_storage_get_buffer(storage), 0)

//         last_updated_storage := &impl.storages[impl.last_updated_storage]
//         d3d11_buffer_storage_set_revision(storage, last_updated_storage.revision + 1)

//         impl.last_updated_storage = impl.mappable_storage
//         impl.has_last_updated     = true
//     }

//     impl := d3d11_buffer_get_impl(buffer, loc)
//     device_impl := d3d11_device_get_impl(impl.device, loc)

//     mapping := impl.map_state
//     impl.map_state = Buffer_Map_State_Idle{}

//     switch state in mapping {
//     case Buffer_Map_State_Init:
//         staging_impl := d3d11_buffer_get_impl(state.staging_buffer.buffer, loc)
//         unmap_active_storage(staging_impl, device_impl, loc)

//         if impl.size > 0 {
//             cmdbuf_impl := &device_impl.queue.stgbuf
//             copy := command_allocator_allocate(
//                 &cmdbuf_impl.commands,
//                 Copy_Buffer_To_Buffer_Cmd,
//                 loc,
//             )
//             copy.src        = state.staging_buffer.buffer
//             copy.src_offset = 0
//             copy.dst        = buffer
//             copy.dst_offset = 0
//             copy.size       = impl.size
//         }

//         d3d11_transfer_batch_consume(&device_impl.transfer_batch, state.staging_buffer)
//         d3d11_transfer_batch_insert_buffer(&device_impl.transfer_batch, buffer)

//     case Buffer_Map_State_Idle:
//         panic("buffer not mapped", loc)

//     case Buffer_Pending_Mapping:
//         // Mapping was requested but never resolved.
//         return

//     case Buffer_Map_State_Active:
//         unmap_active_storage(impl, device_impl, loc)
//     }
// }

// d3d11_buffer_write_mapped_range :: proc(
//     buffer: Buffer,
//     offset: uint,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) -> Status {
//     unimplemented(loc = loc)
// }

// d3d11_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := d3d11_buffer_get_impl(buffer, loc)
//     add_ref(impl, loc)
// }

// d3d11_buffer_destroy_storages :: proc(impl: ^D3D11_Buffer_Impl, loc := #caller_location) {
//     for &storage in impl.storages {
//         if storage.buffer != nil {
//             storage.buffer->Release()
//             storage.buffer = nil
//         }
//     }
// }

// d3d11_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := d3d11_buffer_get_impl(buffer, loc)
//     if release_ref(impl, loc) {
//         d3d11_buffer_destroy_storages(impl, loc)
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.buffers, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Command_Buffer
// // -----------------------------------------------------------------------------

// D3D11_Command_Buffer_Handle :: distinct hm.Handle64

// D3D11_Command_Buffer_Impl :: struct {
//     device:      Device,
//     // encoder:     Command_Encoder,
//     commands:   Command_Allocator,
//     // handle:      D3D11_Command_Buffer_Handle,
//     // ref:         Ref_Count_Type,
//     initialized: bool,
// }

// d3d11_command_buffer_set_label :: proc(
//     command_buffer: Command_Buffer,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
//     d3d11_command_encoder_add_ref(Command_Encoder(command_buffer), loc)
// }

// d3d11_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
//     d3d11_command_encoder_release(Command_Encoder(command_buffer), loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of D3d11_Command_Encoder_Impl
// // -----------------------------------------------------------------------------

// D3D11_Command_Encoder_Handle :: distinct hm.Handle64

// D3D11_Command_Encoder_Impl :: struct {
//     device:       Device,
//     cmdbuf:       D3D11_Command_Buffer_Impl,
//     handle:       D3D11_Command_Encoder_Handle,
//     ref:          Ref_Count_Type,
//     is_encoding:  bool,
//     is_rendering: bool,
//     is_computing: bool,
// }

// d3d11_command_encoder_get_impl :: #force_inline proc "contextless" (
//     command_encoder: Command_Encoder,
//     loc := #caller_location,
// ) -> ^D3D11_Command_Encoder_Impl {
//     assert_contextless(command_encoder != {}, "Invalid Command_Encoder", loc)
//     h := id_to_handle(command_encoder)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     command_encoder_handle := D3D11_Command_Encoder_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.command_encoders, command_encoder_handle)
// }

// d3d11_command_encoder_begin_compute_pass :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Compute_Pass_Descriptor,
//     loc := #caller_location,
// ) -> Compute_Pass_Encoder {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_begin_render_pass :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Render_Pass_Descriptor,
//     loc := #caller_location,
// ) -> Render_Pass_Encoder {
//     assert(descriptor != nil, "Invalid descriptor", loc)

//     impl := d3d11_command_encoder_get_impl(command_encoder, loc)
//     device_impl := d3d11_device_get_impl(impl.device, loc)

//     // Basic state validation
//     assert(impl.is_encoding, "Command encoder is finished", loc)
//     assert(impl.is_computing == false, "Command encoder is in compute state", loc)
//     assert(impl.is_rendering == false, "Command encoder is already rendering", loc)

//     impl.is_rendering = true

//     cmd := command_allocator_allocate(&impl.cmdbuf.commands, Begin_Render_Pass_Cmd, loc)

//     fb_width, fb_height: u32

//     // Copy color attachments
//     for &color in descriptor.color_attachments {
//         assert(color.view != nil, "Invalid color attachment view", loc)

//         append(&cmd.color_attachments, color)

//         view_impl := d3d11_texture_view_get_impl(color.view, loc)
//         size := d3d11_texture_get_size(view_impl.texture, loc)
//         if fb_width > 0 {
//             assert(size.width == fb_width, "All attachments should have the same width", loc)
//         }
//         if fb_height > 0 {
//             assert(size.height == fb_height,
//                 "All attachments should have the same height", loc)
//         }
//         fb_width  = size.width
//         fb_height = size.height
//     }

//     // set depth stencil
//     if descriptor.depth_stencil_attachment != nil {
//         ds := descriptor.depth_stencil_attachment^
//         cmd.depth_stencil_attachment = ds

//         ds_view_impl := d3d11_texture_view_get_impl(ds.view, loc)
//         ds_texture_impl := d3d11_texture_get_impl(ds_view_impl.texture, loc)
//         has_depth := texture_format_has_depth_aspect(ds_texture_impl.format)
//         has_stencil := texture_format_has_stencil_aspect(ds_texture_impl.format)

//         if has_depth && !ds.depth_read_only {
//             assert(ds.depth_load_op != .Undefined,
//                 "depth_load_op must be provided when format has a depth aspect " +
//                 "and depth_read_only is false", loc)
//             assert(ds.depth_store_op != .Undefined,
//                 "depth_store_op must be provided when format has a depth aspect " +
//                 "and depth_read_only is false", loc)
//         }

//         if has_stencil && !ds.stencil_read_only {
//             assert(ds.stencil_load_op != .Undefined,
//                 "stencil_load_op must be provided when format has a stencil aspect " +
//                 "and stencil_read_only is false", loc)
//             assert(ds.stencil_store_op != .Undefined,
//                 "stencil_store_op must be provided when format has a stencil aspect " +
//                 "and stencil_read_only is false", loc)
//         }
//     }

//     assert(fb_width != 0, "Invalid framebuffer width", loc)
//     assert(fb_height != 0, "Invalid framebuffer height", loc)

//     cmd.width = fb_width
//     cmd.height = fb_height

//     cmd.occlusion_query_set = descriptor.occlusion_query_set

//     if descriptor.timestamp_writes != nil {
//         cmd.timestamp_writes = descriptor.timestamp_writes^
//     }

//     rpass_impl := hm_dynamic_add_get(&device_impl.render_pass_encoders,
//         D3D11_Render_Pass_Encoder_Impl {
//             device       = impl.device,
//             encoder      = command_encoder,
//             is_rendering = true,
//         })

//     rpass_handle := handle_make(rpass_impl.handle, device_impl.handle)
//     rpass := handle_to_raw(Render_Pass_Encoder, rpass_handle)

//     init_ref(rpass_impl, loc)
//     d3d11_command_encoder_add_ref(command_encoder, loc)

//     return rpass
// }

// d3d11_command_encoder_clear_buffer :: proc(
//     command_encoder: Command_Encoder,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_copy_buffer_to_buffer :: proc(
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

// d3d11_command_encoder_copy_buffer_to_texture :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Buffer_Info,
//     destination: ^Texel_Copy_Texture_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_copy_texture_to_buffer :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Texture_Info,
//     destination: ^Texel_Copy_Buffer_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_copy_texture_to_texture :: proc(
//     command_encoder: Command_Encoder,
//     source: ^Texel_Copy_Texture_Info,
//     destination: ^Texel_Copy_Texture_Info,
//     copy_size: ^Extent_3D,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_finish :: proc(
//     command_encoder: Command_Encoder,
//     descriptor: ^Command_Buffer_Descriptor,
//     loc := #caller_location,
// ) -> Command_Buffer {
//     impl := d3d11_command_encoder_get_impl(command_encoder, loc)

//     assert(impl.is_encoding, "Finishing encoder while not encoding", loc)
//     assert(impl.is_computing == false, "Finishing encoder in compute state", loc)
//     assert(impl.is_rendering == false, "Finishing encoder in render state", loc)

//     impl.is_encoding = false

//     // Command_Buffer is just a finished Command_Encoder, same handle value
//     d3d11_command_encoder_add_ref(command_encoder, loc)
//     return Command_Buffer(command_encoder)
// }

// d3d11_command_encoder_insert_debug_marker :: proc(
//     command_encoder: Command_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_pop_debug_group :: proc(
//     command_encoder: Command_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_push_debug_group :: proc(
//     command_encoder: Command_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_resolve_query_set :: proc(
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

// d3d11_command_encoder_set_label :: proc(
//     command_encoder: Command_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_write_timestamp :: proc(
//     command_encoder: Command_Encoder,
//     query_set: Query_Set,
//     query_index: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
//     impl := d3d11_command_encoder_get_impl(command_encoder, loc)
//     add_ref(impl, loc)
// }

// d3d11_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
//     impl := d3d11_command_encoder_get_impl(command_encoder, loc)
//     if release_ref(impl, loc) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         d3d11_device_release_command_buffer(device_impl, impl.cmdbuf)
//         hm.remove(&device_impl.command_encoders, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Compute_Pass_Encoder
// // -----------------------------------------------------------------------------

// d3d11_compute_pass_encoder_dispatch_workgroups :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     workgroup_count_x: u32,
//     workgroup_count_y: u32,
//     workgroup_count_z: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_dispatch_workgroups_indirect :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_end :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_insert_debug_marker :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_pop_debug_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_push_debug_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_set_bind_group :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_set_immediates :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_set_label :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_set_pipeline :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     pipeline: Compute_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_add_ref :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pass_encoder_release :: proc(
//     compute_pass_encoder: Compute_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Compute_Pipeline
// // -----------------------------------------------------------------------------

// d3d11_compute_pipeline_get_bind_group_layout :: proc(
//     compute_pipeline: Compute_Pipeline,
//     group_index: u32,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pipeline_set_label :: proc(
//     compute_pipeline: Compute_Pipeline,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pipeline_add_ref :: proc(
//     compute_pipeline: Compute_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_compute_pipeline_release :: proc(
//     compute_pipeline: Compute_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of D3d11_Device_Impl
// // -----------------------------------------------------------------------------

// D3D11_Device_Impl :: struct {
//     // Object pools
//     bind_groups:               DHM(D3D11_Bind_Group_Impl, D3D11_Bind_Group_Handle),
//     bind_group_layouts:        DHM(D3D11_Bind_Group_Layout_Impl, D3D11_Bind_Group_Layout_Handle),
//     buffers:                   DHM(D3D11_Buffer_Impl, D3D11_Buffer_Handle),
//     // command_buffers:        DHM(D3D11_Command_Buffer_Impl, Command_Buffer_Handle),
//     command_encoders:          DHM(D3D11_Command_Encoder_Impl, D3D11_Command_Encoder_Handle),
//     // compute_pass_encoders:  DHM(D3D11_Compute_Pass_Encoder_Impl, Compute_Pass_Encoder_Handle),
//     // compute_pipelines:      DHM(D3D11_Compute_Pipeline_Impl, Compute_Pipeline_Handle),
//     // external_textures:      DHM(D3D11_External_Texture_Impl, External_Texture_Handle),
//     pipeline_layouts:          DHM(D3D11_Pipeline_Layout_Impl, D3D11_Pipeline_Layout_Handle),
//     // query_sets:             DHM(D3D11_Query_Set_Impl, Query_Set_Handle),
//     queues:                    DHM(D3D11_Queue_Impl, D3D11_Queue_Handle),
//     // render_bundles:         DHM(D3D11_Render_Bundle_Impl, Render_Bundle_Handle),
//     // render_bundle_encoders: DHM(D3D11_Render_Bundle_Encoder_Impl, Render_Bundle_Encoder_Handle),
//     render_pass_encoders:      DHM(D3D11_Render_Pass_Encoder_Impl, D3D11_Render_Pass_Encoder_Handle),
//     render_pipelines:          DHM(D3D11_Render_Pipeline_Impl, D3D11_Render_Pipeline_Handle),
//     samplers:                  DHM(D3D11_Sampler_Impl, D3D11_Sampler_Handle),
//     shader_modules:            DHM(D3D11_Shader_Module_Impl, D3D11_Shader_Module_Handle),
//     textures:                  DHM(D3D11_Texture_Impl, D3D11_Texture_Handle),
//     texture_views:             DHM(D3D11_Texture_View_Impl, D3D11_Texture_View_Handle),

//     adapter:                   Adapter,
//     caps:                      D3D11_Adapter_Capabilities,
//     queue:                     D3D11_Queue_Impl,
//     ctx:                       D3D11_Command_Recording_Context,
//     transfer_batch:            D3D11_Transfer_Batch,
//     d3d_device:                ^d3d11.IDevice,
//     d3d_device3:               ^D3D11_IDevice3,
//     d3d_device5:               ^D3D11_IDevice5,
//     free_command_buffers:      [dynamic]D3D11_Command_Buffer_Impl,
//     rtv_pool:                  xar.Freelist_Array(^D3D11_IRenderTargetView1, 6),
//     handle:                    Device_Handle,
//     ref:                       Ref_Count_Type,
//     limits:                    Limits,
//     features:                  []Feature_Name,
//     allocator:                 runtime.Allocator,
//     has_fence:                 bool,
// }

// d3d11_device_get_impl :: #force_inline proc(
//     device: Device,
//     loc := #caller_location,
// ) -> ^D3D11_Device_Impl {
//     assert_contextless(device != {}, "Invalid device", loc)
//     idx := Device_Handle(uintptr(device) - 1)
//     return device_pool_get(&gpu.d3d11.devices, idx)
// }

// d3d11_create_device :: proc(
//     adapter: Adapter,
//     descriptor: Device_Descriptor,
//     loc := #caller_location,
// ) -> (
//     device: Device,
//     ok: bool,
// ) {
//     adapter_impl := d3d11_adapter_get_impl(adapter, loc)

//     impl: D3D11_Device_Impl

//     impl.allocator = adapter_impl.allocator
//     impl.adapter = adapter
//     impl.d3d_device = adapter_impl.d3d_device
//     impl.d3d_device3 = adapter_impl.d3d_device3
//     impl.caps = adapter_impl.caps

//     if descriptor.required_limits != nil {
//         impl.limits = descriptor.required_limits^
//     }

//     if len(descriptor.required_features) > 0 {
//         impl.features = make([]Feature_Name, len(descriptor.required_features), impl.allocator)
//         copy(impl.features, descriptor.required_features)
//     }

//     device_handle := device_pool_add(&gpu.d3d11.devices, impl)
//     device = Device(uintptr(device_handle) + 1) // 0→1, 1→2, etc. nil stays 0

//     device_impl := d3d11_device_get_impl(device)
//     device_impl.handle = device_handle

//     init_ref(device_impl, loc)
//     d3d11_adapter_add_ref(adapter, loc)

//     device_impl.d3d_device->AddRef()
//     device_impl.d3d_device3->AddRef()

//     if adapter_impl.d3d_device5 != nil {
//         device_impl.d3d_device5 = adapter_impl.d3d_device5
//         device_impl.d3d_device5->AddRef()
//     }

//     d3d11_command_recording_context_init(
//         &device_impl.ctx, device_impl.d3d_device3, device_impl.has_fence)

//     device_impl.queue = d3d11_queue_create(device, loc)

//     device_impl.transfer_batch.temp_resources.allocator = impl.allocator
//     device_impl.transfer_batch.dst_buffers.allocator = impl.allocator

//     // Initialize dynamic handles
//     hm.dynamic_init(&device_impl.bind_groups, impl.allocator)
//     hm.dynamic_init(&device_impl.bind_group_layouts, impl.allocator)
//     hm.dynamic_init(&device_impl.buffers, impl.allocator)
//     // hm.dynamic_init(&device_impl.command_buffers, impl.allocator)
//     hm.dynamic_init(&device_impl.command_encoders, impl.allocator)
//     // hm.dynamic_init(&device_impl.compute_pass_encoders, impl.allocator)
//     // hm.dynamic_init(&device_impl.compute_pipelines, impl.allocator)
//     // hm.dynamic_init(&device_impl.external_textures, impl.allocator)
//     hm.dynamic_init(&device_impl.pipeline_layouts, impl.allocator)
//     // hm.dynamic_init(&device_impl.query_sets, impl.allocator)
//     hm.dynamic_init(&device_impl.queues, impl.allocator)
//     // hm.dynamic_init(&device_impl.render_bundles, impl.allocator)
//     // hm.dynamic_init(&device_impl.render_bundle_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.render_pass_encoders, impl.allocator)
//     hm.dynamic_init(&device_impl.render_pipelines, impl.allocator)
//     hm.dynamic_init(&device_impl.samplers, impl.allocator)
//     hm.dynamic_init(&device_impl.shader_modules, impl.allocator)
//     hm.dynamic_init(&device_impl.textures, impl.allocator)
//     hm.dynamic_init(&device_impl.texture_views, impl.allocator)

//     device_impl.free_command_buffers =
//         make([dynamic]D3D11_Command_Buffer_Impl, 0, 16, impl.allocator)

//     xar.freelist_init(&device_impl.rtv_pool, impl.allocator)

//     return device, true
// }

// d3d11_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
//     impl := d3d11_device_get_impl(device, loc)
//     return impl.adapter
// }

// d3d11_device_create_bind_group :: proc(
//     device: Device,
//     descriptor: ^Bind_Group_Descriptor,
//     loc := #caller_location,
// ) -> Bind_Group {
//     assert(descriptor != nil, "Invalid bind group descriptor", loc)
//     assert(descriptor.layout != nil, "Invalid bind group layout", loc)
//     assert(len(descriptor.entries) > 0, "Invalid bind group entries", loc)

//     impl := d3d11_device_get_impl(device, loc)

//     bg_impl := hm_dynamic_add_get(&impl.bind_groups, D3D11_Bind_Group_Impl {
//         device = device,
//         layout = descriptor.layout,
//     })

//     init_ref(bg_impl, loc)
//     d3d11_bind_group_layout_add_ref(descriptor.layout, loc)

//     bg_impl.entries = make([]Bind_Group_Entry, len(descriptor.entries), impl.allocator)
//     copy(bg_impl.entries, descriptor.entries)

//     bgl_handle := handle_make(bg_impl.handle, impl.handle)
//     bgl := handle_to_raw(Bind_Group, bgl_handle)

//     return bgl
// }

// d3d11_device_create_bind_group_layout :: proc(
//     device: Device,
//     descriptor: ^Bind_Group_Layout_Descriptor,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     assert(descriptor != nil, "Invalid bind group layout descriptor", loc)
//     assert(len(descriptor.entries) > 0, "Invalid bind group layout entries", loc)

//     impl := d3d11_device_get_impl(device, loc)

//     bgl_impl := hm_dynamic_add_get(&impl.bind_group_layouts, D3D11_Bind_Group_Layout_Impl {
//         device = device,
//     })

//     init_ref(bgl_impl, loc)

//     bgl_impl.entries = make([]Bind_Group_Layout_Entry, len(descriptor.entries), impl.allocator)
//     copy(bgl_impl.entries, descriptor.entries)

//     when ODIN_DEBUG {
//         for entry in bgl_impl.entries {
//             assert(entry.binding < D3D11_MAX_BINDINGS,
//                 "binding number exceeds D3D11 backend's fixed table size", loc)

//             buffer_set      := entry.buffer.type != .Binding_Not_Used
//             sampler_set     := entry.sampler.type != .Binding_Not_Used
//             texture_set     := entry.texture.sample_type != .Binding_Not_Used
//             storage_tex_set := entry.storage_texture.access != .Binding_Not_Used

//             kind_count := int(buffer_set) +
//                 int(sampler_set) +
//                 int(texture_set) +
//                 int(storage_tex_set)
//             assert(kind_count == 1,
//                 "bind group layout entry must specify exactly one binding kind", loc)

//             assert(!buffer_set  || entry.buffer.type != .Undefined,
//                 "buffer binding type is Undefined", loc)
//             assert(!sampler_set || entry.sampler.type != .Undefined,
//                 "sampler binding type is Undefined", loc)
//             assert(!texture_set || entry.texture.sample_type != .Undefined,
//                 "texture sample type is Undefined", loc)
//             assert(!storage_tex_set || entry.storage_texture.access != .Undefined,
//                 "storage texture access is Undefined", loc)
//         }
//     }

//     bgl_handle := handle_make(bgl_impl.handle, impl.handle)
//     bgl := handle_to_raw(Bind_Group_Layout, bgl_handle)

//     return bgl
// }

// d3d11_buffer_map_at_creation :: proc(buffer: Buffer, loc := #caller_location) {
//     impl := d3d11_buffer_get_impl(buffer, loc)
//     assert(impl.has_mappable, "mapped_at_creation requires a mappable storage", loc)

//     impl.map_state = Buffer_Pending_Mapping{
//         range = {0, u64(impl.allocated_size)},
//         op    = {mode = .Write, callback = nil},
//     }

//     result := d3d11_buffer_map_sync(buffer, {.Write}, 0, uint(impl.allocated_size), loc)
//     assert(result != nil, "mapped_at_creation Map call failed", loc)
// }

// d3d11_device_create_buffer_impl :: proc(
//     device: Device,
//     desc: Buffer_Descriptor_Impl,
//     loc := #caller_location,
// ) -> ^D3D11_Buffer_Impl {
//     impl := d3d11_device_get_impl(device, loc)

//     // Ensure a minimum allocation of 4 bytes so clamped accesses remain within bounds.
//     allocated_size := u32(max(desc.size, 4))

//     // D3D11 requires indirect argument buffers to be at least 12 bytes.
//     if .Indirect in desc.usage {
//         allocated_size = max(allocated_size, 12)
//     }

//     alignment := d3d11_buffer_size_alignment(desc.usage)
//     allocated_size = align(allocated_size, alignment)

//     // Check for alignment overflow
//     assert(allocated_size <= max(u32) - alignment, "Buffer allocation is too large", loc)

//     buffer_impl := hm_dynamic_add_get(&impl.buffers, D3D11_Buffer_Impl {
//         device         = device,
//         size           = desc.size,
//         usage          = desc.usage,
//         internal_uses  = desc.internal_uses,
//         allocated_size = allocated_size,
//     })

//     init_ref(buffer_impl, loc)

//     d3d11_buffer_initialize_impl(buffer_impl, loc)

//     return buffer_impl
// }

// d3d11_device_create_buffer :: proc(
//     device: Device,
//     descriptor: ^Buffer_Descriptor,
//     loc := #caller_location,
// ) -> Buffer {
//     impl := d3d11_device_get_impl(device, loc)

//     desc := resolve_buffer_descriptor(device, descriptor, loc)
//     buffer_impl := d3d11_device_create_buffer_impl(device, desc, loc)

//     buffer_handle := handle_make(buffer_impl.handle, impl.handle)
//     buffer := handle_to_raw(Buffer, buffer_handle)

//     if desc.mapped_at_creation {
//         if .Map_Write not_in desc.internal_uses {
//             stage_desc := Buffer_Descriptor_Impl {
//                 label              = "Internal stage buffer",
//                 size               = desc.size,
//                 internal_uses      = {.Map_Write, .Copy_Src},
//                 memory_flags       = {.Transient},
//                 mapped_at_creation = true,
//             }
//             stg_buffer_impl := d3d11_device_create_buffer_impl(device, stage_desc, loc)

//             stg_handle := handle_make(stg_buffer_impl.handle, impl.handle)
//             stg_buffer := handle_to_raw(Buffer, stg_handle)

//             d3d11_buffer_map_at_creation(stg_buffer, loc)

//             active, ok := stg_buffer_impl.map_state.(Buffer_Map_State_Active)
//             assert(ok, "staging buffer mapped_at_creation did not leave an active mapping", loc)

//             buffer_impl.map_state = Buffer_Map_State_Init {
//                 staging_buffer = {
//                     buffer      = stg_buffer,
//                     device      = device,
//                     size        = desc.size,
//                     is_coherent = true,
//                     ptr         = active.mapping.ptr,
//                 },
//             }
//         } else {
//             d3d11_buffer_map_at_creation(buffer, loc)
//         }
//     }

//     return buffer
// }

// d3d11_device_acquire_command_buffer :: proc(
//     device_impl: ^D3D11_Device_Impl, loc := #caller_location,
// ) -> (
//     buffer: D3D11_Command_Buffer_Impl,
// ) {
//     if len(device_impl.free_command_buffers) > 0 {
//         buffer = pop(&device_impl.free_command_buffers)
//         return
//     }
//     command_allocator_init(&buffer.commands, device_impl.allocator, loc)
//     return
// }

// d3d11_device_release_command_buffer :: proc(
//     device_impl: ^D3D11_Device_Impl,
//     buffer: D3D11_Command_Buffer_Impl,
// ) {
//     append(&device_impl.free_command_buffers, buffer)
// }

// d3d11_device_create_command_encoder :: proc(
//     device: Device,
//     descriptor: ^Command_Encoder_Descriptor,
//     loc := #caller_location,
// ) -> Command_Encoder {
//     impl := d3d11_device_get_impl(device, loc)

//     cmdbuf := d3d11_device_acquire_command_buffer(impl, loc)

//     encoder_impl := hm_dynamic_add_get(&impl.command_encoders, D3D11_Command_Encoder_Impl {
//         device      = device,
//         cmdbuf      = cmdbuf,
//         is_encoding = true,
//     })
//     init_ref(encoder_impl, loc)

//     command_allocator_reset(&encoder_impl.cmdbuf.commands)

//     encoder_handle := handle_make(encoder_impl.handle, impl.handle)
//     encoder := handle_to_raw(Command_Encoder, encoder_handle)

//     return encoder
// }

// d3d11_device_create_compute_pipeline :: proc(
//     device: Device,
//     descriptor: ^Compute_Pipeline_Descriptor,
//     loc := #caller_location,
// ) -> Compute_Pipeline {
//     unimplemented(loc = loc)
// }

// d3d11_device_create_compute_pipeline_async :: proc(
//     device: Device,
//     descriptor: ^Compute_Pipeline_Descriptor,
//     callback_info: Create_Compute_Pipeline_Async_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_pipeline_layout_build_binding_table :: proc(
//     layout: ^D3D11_Pipeline_Layout_Impl,
//     bind_group_layouts: []Bind_Group_Layout,
//     loc := #caller_location,
// ) {
//     assert(len(bind_group_layouts) <= D3D11_MAX_BINDINGS,
//         "too many bind groups for D3D11 backend", loc)

//     for &group in layout.binding_map {
//         for &slots in group {
//             slots = {
//                 .Vertex = D3D11_INVALID_SLOT,
//                 .Fragment = D3D11_INVALID_SLOT,
//                 .Compute = D3D11_INVALID_SLOT,
//             }
//         }
//     }

//     // Pass 1: count fragment-visible UAVs to fix where the fragment UAV
//     // range starts (packed at the top of the UAV slot space so it can
//     // coexist with render targets in one OMSetRenderTargetsAndUnorderedAccessViews call).
//     fragment_uav_count: u32
//     for bgl in bind_group_layouts {
//         bgl_impl := d3d11_bind_group_layout_get_impl(bgl, loc)
//         for &entry in bgl_impl.entries {
//             if d3d11_is_uav_binding(entry) && .Fragment in entry.visibility {
//                 fragment_uav_count += 1
//             }
//         }
//     }
//     layout.uav_start_index_fragment =
//         d3d11._1_UAV_SLOT_COUNT - layout.pls_slot_count - fragment_uav_count

//     // Pass 2: assign every slot.
//     //
//     // slot 0 reserved for builtin constants
//     cbv_next     : [Shader_Stage]u32 = {.Vertex = 0, .Fragment = 0, .Compute = 0}
//     srv_next     : [Shader_Stage]u32
//     sampler_next : [Shader_Stage]u32
//     uav_next_cs  : u32
//     uav_next_ps  := layout.uav_start_index_fragment

//     for bgl, group_index in bind_group_layouts {
//         bgl_impl := d3d11_bind_group_layout_get_impl(bgl, loc)

//         for entry in bgl_impl.entries {
//             slots := &layout.binding_map[group_index][entry.binding]

//             if d3d11_is_uav_binding(entry) {
//                 if .Compute in entry.visibility {
//                     slots[.Compute] = uav_next_cs
//                     uav_next_cs += 1
//                 }
//                 if .Fragment in entry.visibility {
//                     slots[.Fragment] = uav_next_ps
//                     uav_next_ps += 1
//                     layout.uav_bind_group_mask |= 1 << u32(group_index)
//                 }
//                 continue
//             }

//             // Uniform, read-only-storage buffer, sampler, texture, and
//             // read-only storage texture all map to a simple per-stage
//             // bump allocation across CBV / SRV / sampler slot spaces.
//             is_cbv  := d3d11_is_uniform_binding(entry)
//             is_samp := d3d11_is_sampler_binding(entry)
//             // everything else (read-only storage buffer, texture,
//             // read-only storage texture) is an SRV

//             for stage in Shader_Stage {
//                 if stage not_in entry.visibility do continue
//                 switch {
//                 case is_cbv:  slots[stage] = cbv_next[stage];     cbv_next[stage]     += 1
//                 case is_samp: slots[stage] = sampler_next[stage]; sampler_next[stage] += 1
//                 case:         slots[stage] = srv_next[stage];     srv_next[stage]     += 1
//                 }
//             }
//         }
//     }

//     layout.cbv_count     = cbv_next
//     layout.srv_count     = srv_next
//     layout.sampler_count = sampler_next
//     layout.uav_count     = #partial {.Compute = uav_next_cs, .Fragment = fragment_uav_count}
// }

// d3d11_device_create_pipeline_layout :: proc(
//     device: Device,
//     descriptor: ^Pipeline_Layout_Descriptor,
//     loc := #caller_location,
// ) -> Pipeline_Layout {
//     assert(descriptor != nil, "Invalid pipeline layout descriptor", loc)

//     impl := d3d11_device_get_impl(device, loc)

//     pl_impl := hm_dynamic_add_get(&impl.pipeline_layouts, D3D11_Pipeline_Layout_Impl {
//         device = device,
//     })

//     init_ref(pl_impl, loc)

//     pl_impl.layouts = make([]Bind_Group_Layout, len(descriptor.bind_group_layouts), impl.allocator)
//     copy(pl_impl.layouts, descriptor.bind_group_layouts)
//     for bgl in pl_impl.layouts {
//         d3d11_bind_group_layout_add_ref(bgl, loc)
//     }

//     d3d11_pipeline_layout_build_binding_table(pl_impl, pl_impl.layouts, loc)

//     pl_handle := handle_make(pl_impl.handle, impl.handle)
//     pl := handle_to_raw(Pipeline_Layout, pl_handle)

//     return pl
// }

// d3d11_device_create_query_set :: proc(
//     device: Device,
//     descriptor: ^Query_Set_Descriptor,
//     loc := #caller_location,
// ) -> Query_Set {
//     unimplemented(loc = loc)
// }

// d3d11_device_create_render_bundle_encoder :: proc(
//     device: Device,
//     descriptor: ^Render_Bundle_Encoder_Descriptor,
//     loc := #caller_location,
// ) -> Render_Bundle_Encoder {
//     unimplemented(loc = loc)
// }

// d3d11_device_create_render_pipeline :: proc(
//     device: Device,
//     descriptor: ^Render_Pipeline_Descriptor,
//     loc := #caller_location,
// ) -> Render_Pipeline {
//     impl := d3d11_device_get_impl(device, loc)

//     // Basic validation
//     assert(descriptor != nil, "D3D11: Invalid render pipeline descriptor", loc)
//     assert(descriptor.vertex.module != nil, "D3D11: Vertex shader module is required", loc)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = impl.allocator == ta || context.allocator == ta)

//     out: D3D11_Render_Pipeline_Impl
//     out.device = device

//     // Vertex Shader
//     vs_impl := d3d11_shader_module_get_impl(descriptor.vertex.module, loc)
//     assert(vs_impl.vertex_shader != nil, "D3D11: Invalid vertex shader", loc)
//     out.vertex_shader = vs_impl.vertex_shader
//     out.vertex_shader->AddRef()

//     // Pixel Shader (optional)
//     if descriptor.fragment != nil {
//         ps_impl := d3d11_shader_module_get_impl(descriptor.fragment.module, loc)
//         assert(ps_impl.pixel_shader != nil, "D3D11: Invalid pixel shader", loc)
//         out.pixel_shader = ps_impl.pixel_shader
//         out.pixel_shader->AddRef()
//     }

//     // Store primitive topology
//     out.primitive_topology = d3d11_conv_to_primitive_topology(descriptor.primitive.topology)

//     // Input Layout
//     if len(descriptor.vertex.buffers) > 0 {
//         // Store vertex buffer info (stride + step mode + attributes copy)
//         // for use when the pipeline is bound later
//         out.vertex_buffers =
//             make([]D3D11_Vertex_Buffer_Info, len(descriptor.vertex.buffers), impl.allocator)
//         for &buffer, i in descriptor.vertex.buffers {
//             vb := &out.vertex_buffers[i]
//             vb.stride = u32(buffer.array_stride)
//             vb.step_mode = buffer.step_mode
//             vb.attributes = make([]Vertex_Attribute, len(buffer.attributes), impl.allocator)
//             copy(vb.attributes, buffer.attributes)
//         }

//         vs_ref: ^d3d11.IShaderReflection
//         hr := d3d_compiler.Reflect(
//             raw_data(vs_impl.bytecode), uint(len(vs_impl.bytecode)),
//             d3d11.ID3D11ShaderReflection_UUID, (^rawptr)(&vs_ref))
//         d3d_check(hr, "Failed to reflect vertex shader")
//         defer vs_ref->Release()

//         shader_desc: d3d11.SHADER_DESC
//         vs_ref->GetDesc(&shader_desc)

//         input_elements := make([dynamic]d3d11.INPUT_ELEMENT_DESC, ta)

//         // Collect non-system-value inputs in declaration order
//         real_inputs := make([dynamic]d3d11.SIGNATURE_PARAMETER_DESC, ta)
//         for i in 0 ..< shader_desc.InputParameters {
//             param_desc: d3d11.SIGNATURE_PARAMETER_DESC
//             vs_ref->GetInputParameterDesc(i, &param_desc)
//             if param_desc.SystemValueType != .UNDEFINED { continue }
//             append(&real_inputs, param_desc)
//         }

//         // Flatten descriptor attributes in declaration order (same order as the
//         // shader struct)
//         flat_idx := 0
//         for &buffer, buffer_idx in descriptor.vertex.buffers {
//             for &attrib in buffer.attributes {
//                 log.assertf(flat_idx < len(real_inputs),
//                     "D3D11: More vertex attributes in descriptor than shader inputs", loc = loc)
//                 param := real_inputs[flat_idx]
//                 append(&input_elements, d3d11.INPUT_ELEMENT_DESC {
//                     SemanticName         = param.SemanticName,
//                     SemanticIndex        = param.SemanticIndex,
//                     Format               = d3d_conv_to_vertex_format(attrib.format),
//                     InputSlot            = u32(buffer_idx),
//                     AlignedByteOffset    = u32(attrib.offset),
//                     InputSlotClass       = buffer.step_mode == .Vertex ? .VERTEX_DATA : .INSTANCE_DATA,
//                     InstanceDataStepRate = buffer.step_mode == .Instance ? 1 : 0,
//                 })
//                 flat_idx += 1
//             }
//         }

//         d3d_check(impl.d3d_device->CreateInputLayout(
//             raw_data(input_elements), u32(len(input_elements)),
//             raw_data(vs_impl.bytecode), len(vs_impl.bytecode),
//             &out.input_layout))
//     }

//     // Blend state
//     if descriptor.fragment != nil && len(descriptor.fragment.targets) > 0 {
//         blend_desc := d3d11.BLEND_DESC {
//             AlphaToCoverageEnable  = win32.BOOL(descriptor.multisample.alpha_to_coverage_enabled),
//             IndependentBlendEnable = win32.BOOL(len(descriptor.fragment.targets) > 1),
//         }

//         for &target, i in descriptor.fragment.targets {
//             rt := &blend_desc.RenderTarget[i]
//             rt.BlendEnable = target.blend != nil
//             if rt.BlendEnable {
//                 rt.SrcBlend = d3d11_conv_to_blend(target.blend.color.src_factor)
//                 format_components := texture_format_components(target.format)
//                 if format_components < 4 && rt.SrcBlend == .DEST_ALPHA {
//                     // Missing format components default to 0, except A which defaults
//                     // to 1. Replacing DEST_ALPHA with ONE can be an optimization, this
//                     // avoids reading the destination texture.
//                     rt.SrcBlend = .ONE
//                 }
//                 rt.DestBlend = d3d11_conv_to_blend(target.blend.color.dst_factor)
//                 rt.BlendOp = d3d11_conv_to_blend_op(target.blend.color.operation)
//                 rt.SrcBlendAlpha = d3d11_conv_to_blend_alpha(target.blend.alpha.src_factor)
//                 rt.DestBlendAlpha = d3d11_conv_to_blend_alpha(target.blend.alpha.dst_factor)
//                 rt.BlendOpAlpha = d3d11_conv_to_blend_op(target.blend.alpha.operation)
//             }
//             rt.RenderTargetWriteMask = d3d11_conv_to_color_write_enable(target.write_mask)
//         }

//         d3d_check(impl.d3d_device->CreateBlendState(&blend_desc, &out.blend_state))
//     }

//     // Rasterizer state
//     rasterizer_desc := d3d11.RASTERIZER_DESC {
//         FillMode              = .SOLID,
//         CullMode              = d3d11_conv_to_cull_mode(descriptor.primitive.cull_mode),
//         FrontCounterClockwise = descriptor.primitive.front_face == .CCW,
//         DepthBias             = 0,
//         DepthBiasClamp        = 0,
//         SlopeScaledDepthBias  = 0,
//         DepthClipEnable       = !descriptor.primitive.unclipped_depth,
//         ScissorEnable         = true,
//         MultisampleEnable     = descriptor.multisample.count > 1,
//         AntialiasedLineEnable = false,
//     }

//     // Apply depth bias if depth stencil is present
//     if descriptor.depth_stencil != nil {
//         ds := descriptor.depth_stencil
//         rasterizer_desc.DepthBias = ds.depth_bias
//         rasterizer_desc.DepthBiasClamp = ds.depth_bias_clamp
//         rasterizer_desc.SlopeScaledDepthBias = ds.depth_bias_slope_scale
//     }

//     d3d_check(impl.d3d_device->CreateRasterizerState(&rasterizer_desc, &out.rasterizer_state))

//     // Initialize depth stencil state
//     if descriptor.depth_stencil != nil {
//         ds := descriptor.depth_stencil

//         stencil_enabled := stencil_face_state_is_enabled(ds.stencil_front) ||
//                            stencil_face_state_is_enabled(ds.stencil_back)

//         depth_stencil_desc := d3d11.DEPTH_STENCIL_DESC {
//             DepthEnable = win32.BOOL(ds.depth_compare != .Always || ds.depth_write_enabled),
//             DepthWriteMask = ds.depth_write_enabled  ? .ALL : .ZERO,
//             DepthFunc = d3d11_conv_to_comparison_func(ds.depth_compare),
//             StencilEnable = win32.BOOL(stencil_enabled),
//             StencilReadMask = u8(ds.stencil_read_mask),
//             StencilWriteMask = u8(ds.stencil_write_mask),
//             FrontFace = {
//                 StencilFailOp = d3d11_conv_to_stencil_op(ds.stencil_front.fail_op),
//                 StencilDepthFailOp = d3d11_conv_to_stencil_op(ds.stencil_front.depth_fail_op),
//                 StencilPassOp = d3d11_conv_to_stencil_op(ds.stencil_front.pass_op),
//                 StencilFunc = d3d11_conv_to_comparison_func(ds.stencil_front.compare),
//             },
//             BackFace = {
//                 StencilFailOp = d3d11_conv_to_stencil_op(ds.stencil_back.fail_op),
//                 StencilDepthFailOp = d3d11_conv_to_stencil_op(ds.stencil_back.depth_fail_op),
//                 StencilPassOp = d3d11_conv_to_stencil_op(ds.stencil_back.pass_op),
//                 StencilFunc = d3d11_conv_to_comparison_func(ds.stencil_back.compare),
//             },
//         }

//         d3d_check(impl.d3d_device->CreateDepthStencilState(
//             &depth_stencil_desc, &out.depth_stencil_state))
//     }

//     // Store pipeline layout
//     if descriptor.layout != nil {
//         out.layout = descriptor.layout
//         d3d11_pipeline_layout_add_ref(descriptor.layout, loc)
//     }

//     // Multisample mask
//     out.sample_mask = descriptor.multisample.mask
//     if out.sample_mask == 0 {
//         out.sample_mask = 0xFFFFFFFF
//     }

//     pipeline_impl := hm_dynamic_add_get(&impl.render_pipelines, out)
//     init_ref(pipeline_impl, loc)

//     pipeline_handle := handle_make(pipeline_impl.handle, impl.handle)
//     render_pipeline := handle_to_raw(Render_Pipeline, pipeline_handle)

//     return render_pipeline
// }

// // Called at: render_pass_encoder_set_pipeline
// d3d11_render_pipeline_apply :: proc(
//     ctx: ^D3D11_IDeviceContext3,
//     pipeline: ^D3D11_Render_Pipeline_Impl,
//     blend_color: [4]f32 = { 0.0, 0.0, 0.0, 0.0 },
//     stencil_reference: u32 = 0,
// ) {
//     ctx->IASetPrimitiveTopology(pipeline.primitive_topology)

//     if pipeline.input_layout != nil {
//         ctx->IASetInputLayout(pipeline.input_layout)
//     }

//     if pipeline.rasterizer_state != nil {
//         ctx->RSSetState(pipeline.rasterizer_state)
//     }

//     ctx->VSSetShader(pipeline.vertex_shader, nil, 0)
//     if pipeline.pixel_shader != nil {
//         ctx->PSSetShader(pipeline.pixel_shader, nil, 0)
//     }

//     d3d11_render_pipeline_apply_blend_state(ctx, pipeline, blend_color)
//     d3d11_render_pipeline_apply_depth_stencil_state(ctx, pipeline, stencil_reference)
// }

// d3d11_render_pipeline_apply_depth_stencil_state :: proc(
//     ctx: ^D3D11_IDeviceContext3,
//     pipeline: ^D3D11_Render_Pipeline_Impl,
//     stencil_reference: u32,
// ) {
//     if pipeline.depth_stencil_state != nil {
//         ctx->OMSetDepthStencilState(pipeline.depth_stencil_state, stencil_reference)
//     }
// }

// d3d11_render_pipeline_apply_blend_state :: proc(
//     ctx: ^D3D11_IDeviceContext3,
//     pipeline: ^D3D11_Render_Pipeline_Impl,
//     blend_color: [4]f32 = { 0.0, 0.0, 0.0, 0.0 },
// ) {
//     if pipeline.blend_state != nil {
//         blend_color := blend_color
//         ctx->OMSetBlendState(pipeline.blend_state, &blend_color, pipeline.sample_mask)
//     }
// }

// d3d11_device_create_render_pipeline_async :: proc(
//     device: Device,
//     descriptor: ^Render_Pipeline_Descriptor,
//     callback_info: Create_Render_Pipeline_Async_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_device_create_sampler :: proc(
//     device: Device,
//     descriptor: ^Sampler_Descriptor,
//     loc := #caller_location,
// ) -> Sampler {
//     unimplemented(loc = loc)
// }

// d3d11_compile_shader :: proc(
//     allocator: runtime.Allocator,
//     source: string,
//     entry_point: string,
//     target: string,
//     loc := #caller_location,
// ) -> (data: []u8, ok: bool) {
//     blob: ^d3d11.IBlob
//     error_blob: ^d3d11.IBlob
//     defer if blob != nil { blob->Release() }
//     defer if error_blob != nil { error_blob->Release() }

//     ta := context.temp_allocator
//     entry_point_c := strings.clone_to_cstring(entry_point, ta)
//     target_c := strings.clone_to_cstring(target, ta)

//     hr := d3d_compiler.Compile(
//         raw_data(source), len(source), nil, nil, nil,
//         entry_point_c, target_c, 0, 0, &blob, &error_blob,
//     )

//     if win32.FAILED(hr) {
//         if error_blob != nil {
//             msg := string(cstring(error_blob->GetBufferPointer()))
//             log.errorf("D3D11: shader compile failed (entry=%q target=%q hr=0x%x): %s",
//                 entry_point, target, u32(hr), msg, location = loc)
//         } else {
//             log.errorf("D3D11: shader compile failed (entry=%q target=%q hr=0x%x)",
//                 entry_point, target, u32(hr), location = loc)
//         }
//         return
//     }

//     assert(blob != nil, loc = loc)

//     data = make([]u8, blob->GetBufferSize(), allocator)
//     mem.copy(raw_data(data), blob->GetBufferPointer(), len(data))

//     return data, true
// }

// d3d11_device_create_shader_module_from_bytecode :: proc(
//     device: Device,
//     bytecode: []u8,
//     stage: Shader_Stage,
//     loc := #caller_location,
// ) -> Shader_Module {
//     impl := d3d11_device_get_impl(device, loc)

//     sm_impl := hm_dynamic_add_get(&impl.shader_modules, D3D11_Shader_Module_Impl {
//         device   = device,
//         bytecode = bytecode,
//         stage    = stage,
//     })

//     init_ref(sm_impl, loc)

//     switch stage {
//     case .Vertex:
//         d3d_check(impl.d3d_device->CreateVertexShader(
//             raw_data(bytecode), len(bytecode), nil, &sm_impl.vertex_shader))
//     case .Fragment:
//         d3d_check(impl.d3d_device->CreatePixelShader(
//             raw_data(bytecode), len(bytecode), nil, &sm_impl.pixel_shader))
//     case .Compute:
//         d3d_check(impl.d3d_device->CreateComputeShader(
//             raw_data(bytecode), len(bytecode), nil, &sm_impl.compute_shader))
//     }

//     sm_handle := handle_make(sm_impl.handle, impl.handle)
//     return handle_to_raw(Shader_Module, sm_handle)
// }

// d3d11_device_create_shader_module_from_hlsl :: proc(
//     device: Device,
//     source: ^Shader_Source_HLSL,
//     loc := #caller_location,
// ) -> Shader_Module {
//     impl := d3d11_device_get_impl(device, loc)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = impl.allocator == ta || context.allocator == ta)

//     target: string
//     switch source.stage {
//     case .Vertex:   target = "vs_5_0"
//     case .Fragment: target = "ps_5_0"
//     case .Compute:  target = "cs_5_0"
//     }

//     bytecode, bytecode_ok := d3d11_compile_shader(
//         impl.allocator, source.source, source.entry_point, target)
//     assert(bytecode_ok, "D3D11: Failed to compile HLSL shader", loc)

//     return d3d11_device_create_shader_module_from_bytecode(device, bytecode, source.stage, loc)
// }

// d3d11_device_create_shader_module_from_dxbc :: proc(
//     device: Device,
//     source: ^Shader_Source_DXBC,
//     loc := #caller_location,
// ) -> Shader_Module {
//     impl := d3d11_device_get_impl(device, loc)
//     bytecode := slice.clone(source.bytecode, impl.allocator)
//     return d3d11_device_create_shader_module_from_bytecode(
//         device, bytecode, source.stage, loc)
// }

// d3d11_device_create_shader_module :: proc(
//     device: Device,
//     descriptor: ^Shader_Module_Descriptor,
//     loc := #caller_location,
// ) -> Shader_Module {
//     assert(descriptor != nil, "Invalid shader module descriptor", loc)

//     head := descriptor.next_in_chain
//     for head != nil {
//         #partial switch head.stype {
//         case .Shader_Source_HLSL:
//             s := cast(^Shader_Source_HLSL)head
//             return d3d11_device_create_shader_module_from_hlsl(device, s, loc)
//         case .Shader_Source_DXBC:
//             s := cast(^Shader_Source_DXBC)head
//             return d3d11_device_create_shader_module_from_dxbc(device, s, loc)
//         case .Shader_Source_Slang:
//             unimplemented("D3D11: Slang source compilation not yet implemented " +
//                 "(compile to HLSL or DXBC first)", loc)
//         case .Shader_Source_DXIL:
//             panic("D3D11: DXIL bytecode is not supported by the D3D11 backend " +
//                 "(use D3D12, or provide HLSL/DXBC)", loc)
//         }
//         head = head.next
//     }

//     panic("D3D11: Invalid shader source", loc)
// }

// d3d11_device_create_texture :: proc(
//     device: Device,
//     _descriptor_: ^Texture_Descriptor,
//     loc := #caller_location,
// ) -> Texture {
//     assert(_descriptor_ != nil, "Invalid texture descriptor", loc)

//     impl := d3d11_device_get_impl(device, loc)

//     // Get the descriptor implementation
//     desc := resolve_texture_descriptor(device, _descriptor_^, loc)

//     kind := D3D11_Texture_Kind.Normal
//     d3d_resource: ^d3d11.IResource

//     switch desc.dimension {
//     case .D1:
//         d3d_desc := d3d11_conv_to_texture_desc(d3d11.TEXTURE1D_DESC, desc, kind)
//         d3d_texture_1d: ^d3d11.ITexture1D
//         d3d_check(impl.d3d_device->CreateTexture1D(&d3d_desc, nil, &d3d_texture_1d))
//         d3d_resource = cast(^d3d11.IResource)d3d_texture_1d

//     case .D2:
//         d3d_desc := d3d11_conv_to_texture_desc(d3d11.TEXTURE2D_DESC, desc, kind, loc)
//         d3d_texture_2d: ^d3d11.ITexture2D
//         d3d_check(impl.d3d_device->CreateTexture2D(&d3d_desc, nil, &d3d_texture_2d))
//         d3d_resource = cast(^d3d11.IResource)d3d_texture_2d

//     case .D3:
//         d3d_desc := d3d11_conv_to_texture_desc(d3d11.TEXTURE3D_DESC, desc, kind, loc)
//         d3d_texture_3d: ^d3d11.ITexture3D
//         d3d_check(impl.d3d_device->CreateTexture3D(&d3d_desc, nil, &d3d_texture_3d))
//         d3d_resource = cast(^d3d11.IResource)d3d_texture_3d

//     case .Undefined:
//         unreachable()
//     }

//     texture_impl := hm_dynamic_add_get(&impl.textures, D3D11_Texture_Impl{
//         device      = device,
//         desc_impl   = desc,
//         kind        = kind,
//         d3d_texture = d3d_resource,
//     }) or_else panic("Failed to allocate texture handle", loc)

//     init_ref(texture_impl, loc)

//     texture_handle := handle_make(texture_impl.handle, impl.handle)
//     texture := handle_to_raw(Texture, texture_handle)

//     return texture
// }

// d3d11_device_destroy :: proc(device: Device, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_device_get_adapter_info :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     info: Adapter_Info,
//     status: Status,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_device_get_features :: proc(
//     device: Device,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := d3d11_device_get_impl(device, loc)
//     features.features = make([]Feature_Name, len(impl.features), allocator)
//     copy(features.features, impl.features)
//     return
// }

// d3d11_device_get_features_view :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     features: Supported_Features,
// ) {
//     impl := d3d11_device_get_impl(device, loc)
//     features.features = impl.features
//     return
// }

// d3d11_device_get_limits :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     limits: Limits,
//     status: Status,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
//     impl := d3d11_device_get_impl(device, loc)
//     handle_impl, alloc_err := hm_dynamic_add_get(
//         &impl.queues, D3D11_Queue_Impl{wrapper = impl.queue})
//     assert_contextless(alloc_err == nil, "Failed to allocate Queue", loc)
//     h := handle_make(handle_impl.handle, impl.handle)
//     queue := handle_to_raw(Queue, h)
//     init_ref(handle_impl, loc)
//     return queue
// }

// d3d11_device_has_feature :: proc(
//     device: Device,
//     feature: Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     if feature == {} {
//         return true
//     }
//     impl := d3d11_device_get_impl(device, loc)
//     _, found := slice.binary_search(impl.features, feature)
//     return found
// }

// d3d11_device_pop_error_scope :: proc(
//     device: Device,
//     callback_info: Pop_Error_Scope_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_device_push_error_scope :: proc(
//     device: Device,
//     filter: Error_Filter,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_device_add_ref :: proc(device: Device, loc := #caller_location) {
//     impl := d3d11_device_get_impl(device, loc)
//     add_ref(impl, loc)
// }

// d3d11_device_release :: proc(device: Device, loc := #caller_location) {
//     impl := d3d11_device_get_impl(device, loc)
//     if release_ref(impl, loc) {
//         context.allocator = impl.allocator

//         xar.freelist_destroy(&impl.rtv_pool)

//         // Ensure any pending staged writes get released
//         d3d11_transfer_batch_flush(&impl.transfer_batch, device, loc)

//         clear(&impl.queue.pending_cpu_sync)

//         delete(impl.transfer_batch.dst_buffers)
//         delete(impl.transfer_batch.temp_resources)

//         for &b in impl.free_command_buffers {
//             command_allocator_destroy(&b.commands)
//         }
//         delete(impl.free_command_buffers)

//         switch impl.queue.sync_kind {
//         case .Monitored_Fence, .Unmonitored_Fence_Event:
//              impl.queue.fence->Release()
//         case .Query_Event:
//             impl.queue.sync_query->Release()
//         }

//         d3d11_command_recording_context_uninit(&impl.queue.ctx)
//         d3d11_command_recording_context_uninit(&impl.ctx)

//         command_allocator_destroy(&impl.queue.stgbuf.commands)

//         delete(impl.queue.pending_cpu_sync)

//         if impl.d3d_device5 != nil {
//             impl.d3d_device5->Release()
//         }

//         impl.d3d_device3->Release()
//         impl.d3d_device->Release()

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
//         // if hm.len(impl.command_buffers) > 0 {
//         //     log.warnf("Leaked %d command buffer(s)", hm.len(impl.command_buffers))
//         // }
//         if hm.len(impl.command_encoders) > 0 {
//             log.warnf("Leaked %d command encoder(s)", hm.len(impl.command_encoders))
//         }
//         // if hm.len(impl.compute_pass_encoders) > 0 {
//         //     log.warnf("Leaked %d compute pass encoder(s)", hm.len(impl.compute_pass_encoders))
//         // }
//         // if hm.len(impl.compute_pipelines) > 0 {
//         //     log.warnf("Leaked %d compute pipeline(s)", hm.len(impl.compute_pipelines))
//         // }
//         // if hm.len(impl.external_textures) > 0 {
//         //     log.warnf("Leaked %d external texture(s)", hm.len(impl.external_textures))
//         // }
//         if hm.len(impl.pipeline_layouts) > 0 {
//             log.warnf("Leaked %d pipeline layout(s)", hm.len(impl.pipeline_layouts))
//         }
//         // if hm.len(impl.query_sets) > 0 {
//         //     log.warnf("Leaked %d query_set(s)", hm.len(impl.query_sets))
//         // }
//         if hm.len(impl.queues) > 0 {
//             log.warnf("Leaked %d queue(s)", hm.len(impl.queues))
//         }
//         // if hm.len(impl.render_bundles) > 0 {
//         //     log.warnf("Leaked %d render bundle(s)", hm.len(impl.render_bundles))
//         // }
//         // if hm.len(impl.render_bundle_encoders) > 0 {
//         //     log.warnf("Leaked %d render bundle encoder(s)", hm.len(impl.render_bundle_encoders))
//         // }
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
//         // hm.dynamic_destroy(&impl.command_buffers)
//         hm.dynamic_destroy(&impl.command_encoders)
//         // hm.dynamic_destroy(&impl.compute_pass_encoders)
//         // hm.dynamic_destroy(&impl.compute_pipelines)
//         // hm.dynamic_destroy(&impl.external_textures)
//         hm.dynamic_destroy(&impl.pipeline_layouts)
//         // hm.dynamic_destroy(&impl.query_sets)
//         hm.dynamic_destroy(&impl.queues)
//         // hm.dynamic_destroy(&impl.render_bundles)
//         // hm.dynamic_destroy(&impl.render_bundle_encoders)
//         hm.dynamic_destroy(&impl.render_pass_encoders)
//         hm.dynamic_destroy(&impl.render_pipelines)
//         hm.dynamic_destroy(&impl.samplers)
//         hm.dynamic_destroy(&impl.shader_modules)
//         hm.dynamic_destroy(&impl.textures)
//         hm.dynamic_destroy(&impl.texture_views)

//         d3d11_adapter_release(impl.adapter)
//         device_pool_remove(&gpu.d3d11.devices, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of External_Texture
// // -----------------------------------------------------------------------------

// d3d11_external_texture_set_label :: proc(
//     external_texture: External_Texture,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_external_texture_add_ref :: proc(
//     external_texture: External_Texture,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_external_texture_release :: proc(
//     external_texture: External_Texture,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Instance
// // -----------------------------------------------------------------------------

// D3D11_Instance_Impl :: struct {
//     ctx:                  runtime.Context,
//     allocator:            runtime.Allocator,
//     pending_futures:      map[u64]Future_Impl,
//     future_mtx:           sync.Mutex,
//     dxgi_factory:         ^dxgi.IFactory4,
//     dxc_path:             string,
//     dxc_max_shader_model: Dxc_Max_Shader_Model,
//     flags:                Instance_Flags,
//     current_future_id:    u64,
//     ref:                  Ref_Count_Type,
//     headless:             bool,
// }

// @(require_results)
// d3d11_instance_get_impl :: #force_inline proc "contextless" (
//     instance: Instance,
//     loc := #caller_location,
// ) -> ^D3D11_Instance_Impl {
//     assert_contextless(instance != {}, "Invalid instance", loc)
//     return cast(^D3D11_Instance_Impl)instance
// }

// d3d11_instance_create_surface :: proc(
//     instance: Instance,
//     descriptor: ^Surface_Descriptor,
//     loc := #caller_location,
// ) -> Surface {
//     assert(descriptor != nil, "Invalid surface descriptor", loc)

//     impl := d3d11_instance_get_impl(instance, loc)

//     hinstance: win32.HINSTANCE
//     hwnd: win32.HWND

//     tearing_support := d3d_tearing_support(impl.dxgi_factory)

//     head := descriptor.next_in_chain
//     for head != nil {
//         #partial switch head.stype {
//         case .Surface_Source_Windows_HWND:
//             s := cast(^Surface_Source_Windows_HWND)head
//             // assert(s.hinstance != nil, "Invalid win32.HINSTANCE", loc)
//             assert(s.hwnd != nil, "Invalid win32.HWND", loc)
//             hinstance = win32.HINSTANCE(s.hinstance)
//             hwnd = win32.HWND(s.hwnd)
//         }
//         head = head.next
//     }

//     assert(hwnd != nil, loc = loc)

//     sync.guard(&gpu.d3d11.mtx)

//     surface_impl := hm_dynamic_add_get(&gpu.d3d11.surfaces, D3D11_Surface_Impl{
//         instance        = impl,
//         hinstance       = hinstance,
//         hwnd            = hwnd,
//         allocator       = impl.allocator,
//         tearing_support = tearing_support,
//     })
//     surface := transmute(Surface)surface_impl.handle

//     init_ref(surface_impl, loc)
//     d3d11_instance_add_ref(instance, loc)

//     return surface
// }

// d3d11_instance_get_wgsl_language_features :: proc(
//     instance: Instance,
//     loc := #caller_location,
// ) -> Supported_WGSL_Language_Features {
//     unimplemented(loc = loc)
// }

// d3d11_instance_has_wgsl_language_feature :: proc(
//     instance: Instance,
//     feature: WGSL_Language_Feature_Name,
//     loc := #caller_location,
// ) -> bool {
//     unimplemented(loc = loc)
// }

// d3d11_instance_process_events :: proc(instance: Instance, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_instance_request_adapter :: proc(
//     instance: Instance,
//     options: ^Request_Adapter_Options,
//     callback_info: Request_Adapter_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     impl := d3d11_instance_get_impl(instance, loc)

//     ta := context.temp_allocator
//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
//         ignore = context.allocator == ta || impl.allocator == ta)

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

//     opts := options != nil ? options^ : {}

//     adapters := d3d_discover_adapters(impl.dxgi_factory, opts, ta, loc)

//     adapter, adapter_ok := d3d11_create_adapter(impl, adapters[0])

//     for a in adapters[1:] {
//         a->Release()
//     }

//     if !adapter_ok {
//         adapters[0]->Release()
//         callback(callback_info, .Unavailable, nil, "No suitable adapter found")
//         return {}
//     }

//     callback(callback_info, .Success, adapter, "")
//     return {}
// }

// d3d11_instance_wait_any :: proc(
//     instance: Instance,
//     futures: []^Future_Wait_Info,
//     timeout_ns: u64 = max(u64),
//     loc := #caller_location,
// ) -> Wait_Status {
//     unimplemented(loc = loc)
// }

// d3d11_generate_report :: proc(
//     instance: Instance,
//     loc := #caller_location,
// ) -> (
//     report: Global_Report,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_instance_enumerate_adapters :: proc(
//     instance: Instance,
//     options: ^Instance_Enumerate_Adapter_Options = nil,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     adapters: []Adapter,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
//     impl := d3d11_instance_get_impl(instance, loc)
//     add_ref(impl, loc)
// }

// d3d11_instance_release :: proc(instance: Instance, loc := #caller_location) {
//     impl := d3d11_instance_get_impl(instance, loc)
//     if release_ref(impl, loc) {
//         context.allocator = impl.allocator

//         if len(impl.pending_futures) > 0 {
//             log.warnf("Leaked %d pending futures", len(impl.pending_futures))
//             for _, &v in impl.pending_futures {
//                 free(v.userdata, v.allocator)
//             }
//         }
//         delete(impl.pending_futures)

//         impl.dxgi_factory->Release()

//         if .Debug in impl.flags {
//             // Report live objects
//             dxgi_debug: ^dxgi.IDebug
//             hr := dxgi.GetDebugInterface1(0, dxgi.IDebug_UUID, (^rawptr)(&dxgi_debug))
//             if hr == win32.S_OK {
//                 defer dxgi_debug->Release()
//                 dxgi_debug->ReportLiveObjects(dxgi.DEBUG_ALL, .ALL)
//             }
//         }

//         hm.dynamic_destroy(&gpu.d3d11.surfaces)
//         hm.dynamic_destroy(&gpu.d3d11.adapters)

//         free(impl)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Pipeline_Layout
// // -----------------------------------------------------------------------------

// D3D11_Pipeline_Layout_Handle :: distinct hm.Handle64

// D3D11_Binding_Slots :: [Shader_Stage]u32

// D3D11_MAX_BINDINGS :: 32
// D3D11_INVALID_SLOT :: max(u32)

// D3D11_Pipeline_Layout_Impl :: struct {
//     device:                   Device,
//     layouts:                  []Bind_Group_Layout,

//     binding_map:              [MAX_BIND_GROUPS][D3D11_MAX_BINDINGS]D3D11_Binding_Slots,

//     cbv_count:                [Shader_Stage]u32,
//     srv_count:                [Shader_Stage]u32,
//     sampler_count:            [Shader_Stage]u32,
//     uav_count:                [Shader_Stage]u32,

//     uav_start_index_fragment: u32,
//     pls_slot_count:           u32,
//     uav_bind_group_mask:      u32,

//     handle:                   D3D11_Pipeline_Layout_Handle,
//     ref:                      Ref_Count_Type,
// }

// d3d11_pipeline_layout_get_impl :: #force_inline proc "contextless" (
//     pipeline_layout: Pipeline_Layout,
//     loc := #caller_location,
// ) -> ^D3D11_Pipeline_Layout_Impl {
//     assert_contextless(pipeline_layout != {}, "Invalid bind group", loc)
//     h := id_to_handle(pipeline_layout)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := D3D11_Pipeline_Layout_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.pipeline_layouts, map_handle)
// }

// d3d11_pipeline_layout_set_label :: proc(
//     pipeline_layout: Pipeline_Layout,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
//     impl := d3d11_pipeline_layout_get_impl(pipeline_layout, loc)
//     add_ref(impl, loc)
// }

// d3d11_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
//     impl := d3d11_pipeline_layout_get_impl(pipeline_layout, loc)
//     if release_ref(impl, loc) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         if len(impl.layouts) > 0 {
//             for layout in impl.layouts {
//                 d3d11_bind_group_layout_release(layout, loc)
//             }
//             delete(impl.layouts, device_impl.allocator)
//         }
//         hm.remove(&device_impl.pipeline_layouts, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Query_Set
// // -----------------------------------------------------------------------------

// d3d11_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
//     unimplemented(loc = loc)
// }

// d3d11_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
//     unimplemented(loc = loc)
// }

// d3d11_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Queue
// // -----------------------------------------------------------------------------

// D3D11_Queue_Handle :: distinct hm.Handle64

// D3D11_Queue_Sync_Kind :: enum {
//     Monitored_Fence,
//     Unmonitored_Fence_Event,
//     Query_Event,
// }

// D3D11_Queue_Wrapper_Impl :: struct {
//     device:           Device,
//     sync_kind:        D3D11_Queue_Sync_Kind,

//     ctx:              D3D11_Command_Recording_Context,
//     stgbuf:           D3D11_Command_Buffer_Impl,
//     pending_cpu_sync: [dynamic]Buffer,

//     // Fence path (monitored or non-monitored + system event)
//     fence:            ^D3D11_IFence,
//     fence_value:      u64,
//     fence_event:      win32.HANDLE,

//     // Query fallback path (no ID3D11Device5 at all)
//     sync_query:       ^d3d11.IQuery,
// }

// D3D11_Queue_Impl :: struct {
//     using wrapper: D3D11_Queue_Wrapper_Impl,
//     handle:        D3D11_Queue_Handle,
//     ref:           Ref_Count_Type,
// }

// d3d11_queue_get_impl :: #force_inline proc "contextless" (
//     queue: Queue,
//     loc := #caller_location,
// ) -> ^D3D11_Queue_Impl {
//     assert_contextless(queue != {}, "Invalid queue", loc)
//     h := id_to_handle(queue)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     map_handle := D3D11_Queue_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.queues, map_handle)
// }

// d3d11_queue_add_buffer_for_cpu_sync :: proc(queue: ^D3D11_Queue_Impl, buffer: Buffer) {
//     for b in queue.pending_cpu_sync {
//         if b == buffer {
//             return  // already pending, avoid duplicate entries
//         }
//     }
//     append(&queue.pending_cpu_sync, buffer)
// }

// d3d11_flush_pending_cpu_sync :: proc(device_impl: ^D3D11_Device_Impl, loc := #caller_location) {
//     for b in device_impl.queue.pending_cpu_sync {
//         b_impl := d3d11_buffer_get_impl(b, loc)
//         d3d11_buffer_sync_gpu_writes_to_staging(b_impl, device_impl, loc)
//     }
//     clear(&device_impl.queue.pending_cpu_sync)
// }

// d3d11_queue_create :: proc(
//     device: Device, loc := #caller_location,
// ) -> (q: D3D11_Queue_Impl) {
//     device_impl := d3d11_device_get_impl(device, loc)

//     q.stgbuf.device = device

//     if device_impl.d3d_device5 == nil {
//         // No IDevice5 -> no IFence at all, fall back to IQuery.
//         q = d3d11_queue_create_query_event(device)
//     } else if device_impl.caps.supports_monitored_fence {
//         q = d3d11_queue_create_monitored_fence(device)
//     } else {
//         // IDevice5 exists but monitored fences aren't supported.
//         q = d3d11_queue_create_event_fence(device)
//     }

//     d3d11_command_recording_context_init(
//         &q.ctx, device_impl.d3d_device3, device_impl.has_fence)

//     command_allocator_init(&q.stgbuf.commands, device_impl.allocator)

//     q.pending_cpu_sync.allocator = device_impl.allocator

//     return
// }

// d3d11_queue_init_fence :: proc(
//     q: ^D3D11_Queue_Wrapper_Impl, use_non_monitored: bool, loc := #caller_location,
// ) {
//     device_impl := d3d11_device_get_impl(q.device, loc)

//     flags := D3D11_FENCE_FLAGS{.SHARED}
//     if use_non_monitored {
//         if device_impl.caps.supports_non_monitored_fence {
//             flags |= {.NON_MONITORED}
//             // Per DXGI_ADAPTER_FLAG3 docs: on adapters that support both fence
//             // kinds, non-monitored fences require SHARED + SHARED_CROSS_ADAPTER.
//             if device_impl.caps.supports_monitored_fence {
//                 flags |= {.SHARED_CROSS_ADAPTER}
//             }
//         } else {
//             log.warn("D3D11: non-monitored fence not supported, falling back to monitored fence")
//         }
//     } else {
//         assert(device_impl.caps.supports_monitored_fence, loc = loc)
//     }

//     d3d_check(device_impl.d3d_device5->CreateFence(
//         0, flags, D3D11_IFence_UUID, (^rawptr)(&q.fence)))

//     q.fence_event = win32.CreateEventW(nil, false, false, nil)
//     assert(q.fence_event != nil, "D3D11: failed to create fence wait event", loc)
// }

// d3d11_queue_create_monitored_fence :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     q: D3D11_Queue_Impl,
// ) {
//     q.device    = device
//     q.sync_kind = .Monitored_Fence
//     d3d11_queue_init_fence(&q, use_non_monitored = false, loc = loc)
//     return
// }

// d3d11_queue_create_event_fence :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     q: D3D11_Queue_Impl,
// ) {
//     q.device    = device
//     q.sync_kind = .Unmonitored_Fence_Event
//     d3d11_queue_init_fence(&q, use_non_monitored = true, loc = loc)
//     return
// }

// d3d11_queue_create_query_event :: proc(
//     device: Device,
//     loc := #caller_location,
// ) -> (
//     q: D3D11_Queue_Impl,
// ) {
//     device_impl := d3d11_device_get_impl(q.device, loc)

//     q.device    = device
//     q.sync_kind = .Query_Event

//     desc := d3d11.QUERY_DESC{
//         Query     = .EVENT,
//         MiscFlags = {},
//     }

//     d3d_check(device_impl.d3d_device3->CreateQuery(&desc, &q.sync_query))

//     return
// }

// d3d11_queue_on_submitted_work_done :: proc(
//     queue: Queue,
//     callback_info: Queue_Work_Done_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_record_render_pass :: proc(
//     device: Device,
//     cmdbuf: ^D3D11_Command_Buffer_Impl,
//     rpass: ^Begin_Render_Pass_Cmd,
//     loc := #caller_location,
// ) {
//     device_impl := d3d11_device_get_impl(device, loc)
//     d3d_context := device_impl.ctx.d3d_context

//     // Collect render target views
//     rtvs: [dynamic; MAX_COLOR_ATTACHMENTS]^d3d11.IRenderTargetView

//     // Process color attachments
//     for &color in rpass.color_attachments {
//         assert(color.view != nil, "Invalid color attachment view", rpass.loc)

//         view_impl := d3d11_texture_view_get_impl(color.view, rpass.loc)
//         // texture_impl := d3d11_texture_get_impl(view_impl.texture, rpass.loc)

//         depth_slice := color.depth_slice == DEPTH_SLICE_UNDEFINED ? 0 : u32(color.depth_slice)
//         rtv := d3d11_texture_view_get_or_create_rtv(view_impl, depth_slice, rpass.loc)
//         assert(rtv != nil,
//             "Color attachment view must have a render target view", rpass.loc)
//         append(&rtvs, rtv)

//         // Handle clear operation
//         if color.load_op == .Clear {
//             clear_color: [4]f32 = {
//                 f32(color.clear_value.r),
//                 f32(color.clear_value.g),
//                 f32(color.clear_value.b),
//                 f32(color.clear_value.a),
//             }
//             d3d_context->ClearRenderTargetView(rtv, &clear_color)
//         }
//     }

//     // Handle depth stencil attachment
//     dsv: ^d3d11.IDepthStencilView = nil
//     if ds, has_ds := rpass.depth_stencil_attachment.?; has_ds {
//         assert(ds.view != nil, "Invalid depth attachment view", rpass.loc)

//         ds_view_impl := d3d11_texture_view_get_impl(ds.view, rpass.loc)
//         ds_texture_impl := d3d11_texture_get_impl(ds_view_impl.texture, rpass.loc)

//         dsv = d3d11_texture_view_get_or_create_dsv(
//             ds_view_impl, ds.depth_read_only, ds.stencil_read_only, rpass.loc)
//         assert(dsv != nil,
//             "Depth stencil attachment view must have a depth stencil view", rpass.loc)

//         // Determine clear flags based on format and load operations
//         clear_flags: d3d11.CLEAR_FLAGS

//         has_depth := texture_format_has_depth_aspect(ds_texture_impl.format)
//         has_stencil := texture_format_has_stencil_aspect(ds_texture_impl.format)

//         if has_depth && ds.depth_load_op == .Clear {
//             clear_flags |= { .DEPTH }
//         }

//         if has_stencil && ds.stencil_load_op == .Clear {
//             clear_flags |= { .STENCIL }
//         }

//         // Clear if any flags are set
//         if clear_flags != {} {
//             d3d_context->ClearDepthStencilView(
//                 dsv,
//                 clear_flags,
//                 ds.depth_clear_value,
//                 u8(ds.stencil_clear_value),
//             )
//         }
//     }

//     // Bind render targets
//     d3d_context->OMSetRenderTargets(u32(len(rtvs)), raw_data(rtvs[:]), dsv)

//     // Set default viewport
//     d3d_context->RSSetViewports(1, &d3d11.VIEWPORT{
//         TopLeftX = 0,
//         TopLeftY = 0,
//         Width    = f32(rpass.width),
//         Height   = f32(rpass.height),
//         MinDepth = 0.0,
//         MaxDepth = 1.0,
//     })

//     // Set default scissor rect
//     d3d_context->RSSetScissorRects(1, &d3d11.RECT{
//         left   = 0,
//         top    = 0,
//         right  = i32(rpass.width),
//         bottom = i32(rpass.height),
//     })

//     active_pipeline: Render_Pipeline
//     vertex_buffer_tracker: D3D11_Vertex_Buffer_Tracker
//     bind_group_tracker: D3D11_Bind_Group_Tracker
//     // TODO: pixel_local_storage_uavs
//     d3d11_bind_group_tracker_init(&bind_group_tracker, d3d_context)
//     blend_color: [4]f32
//     stencil_reference: u32

//     // Record render pass commands
//     LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
//         #partial switch &cmd in curr {
//         case Set_Bind_Group_Cmd:
//             d3d11_bind_group_tracker_on_set_bind_group(
//                 &bind_group_tracker, cmd.index, cmd.bind_group, cmd.dynamic_offsets)

//         case Set_Render_Pipeline_Cmd:
//             pipeline_impl := d3d11_render_pipeline_get_impl(cmd.pipeline, cmd.loc)
//             d3d11_render_pipeline_apply(
//                 device_impl.ctx.d3d_context,
//                 pipeline_impl,
//                 blend_color,
//                 stencil_reference)
//             active_pipeline = cmd.pipeline

//         case Set_Index_Buffer_Cmd:
//             buffer_impl := d3d11_buffer_get_impl(cmd.buffer, cmd.loc)
//             storage := d3d11_buffer_get_gpu_usable_storage(buffer_impl, cmd.loc)
//             format := d3d_conv_to_index_format(cmd.index_format, cmd.loc)

//             d3d_context->IASetIndexBuffer(
//                 d3d11_buffer_storage_get_buffer(storage),
//                 format,
//                 u32(cmd.offset),
//             )

//         case Set_Vertex_Buffer_Cmd:
//             buffer_impl := d3d11_buffer_get_impl(cmd.buffer, cmd.loc)
//             storage := d3d11_buffer_get_gpu_usable_storage(buffer_impl, cmd.loc)

//             d3d11_vertex_buffer_tracker_on_set(
//                 &vertex_buffer_tracker,
//                 cmd.slot,
//                 d3d11_buffer_storage_get_buffer(storage),
//                 u32(cmd.offset),
//             )

//         case Set_Blend_Constant_Cmd:
//             blend_color = {
//                 f32(cmd.color.r),
//                 f32(cmd.color.g),
//                 f32(cmd.color.b),
//                 f32(cmd.color.a),
//             }
//             if active_pipeline != nil {
//                 pipeline_impl := d3d11_render_pipeline_get_impl(active_pipeline, loc)
//                 d3d11_render_pipeline_apply_blend_state(d3d_context, pipeline_impl, blend_color)
//             }

//         case Set_Stencil_Reference_Cmd:
//             stencil_reference = cmd.reference
//             if active_pipeline != nil {
//                 pipeline_impl := d3d11_render_pipeline_get_impl(active_pipeline, loc)
//                 d3d11_render_pipeline_apply_depth_stencil_state(
//                     d3d_context, pipeline_impl, stencil_reference)
//             }

//         case Set_Viewport_Cmd:
//             d3d_context->RSSetViewports(1, &d3d11.VIEWPORT{
//                 TopLeftX = cmd.x,
//                 TopLeftY = cmd.y,
//                 Width    = cmd.width,
//                 Height   = cmd.height,
//                 MinDepth = cmd.min_depth,
//                 MaxDepth = cmd.max_depth,
//             })

//         case Set_Scissor_Cmd:
//             d3d_context->RSSetScissorRects(1, &d3d11.RECT{
//                 left   = i32(cmd.x),
//                 top    = i32(cmd.y),
//                 right  = i32(cmd.width),
//                 bottom = i32(cmd.height),
//             })

//         case Draw_Cmd:
//             assert(active_pipeline != {}, "no render pipeline bound before Draw", cmd.loc)
//             d3d11_bind_group_tracker_apply(&bind_group_tracker, active_pipeline, cmd.loc)
//             d3d11_vertex_buffer_tracker_apply(
//                 &vertex_buffer_tracker, d3d_context, active_pipeline, cmd.loc)
//             d3d_context->DrawInstanced(
//                 cmd.vertex_count, cmd.instance_count,
//                 cmd.first_vertex, cmd.first_instance,
//             )

//         case Draw_Indexed_Cmd:
//             assert(active_pipeline != {}, "no render pipeline bound before DrawIndexed", cmd.loc)
//             d3d11_vertex_buffer_tracker_apply(
//                 &vertex_buffer_tracker, d3d_context, active_pipeline, cmd.loc)
//             d3d_context->DrawIndexedInstanced(
//                 cmd.index_count, cmd.instance_count,
//                 cmd.first_index, i32(cmd.base_vertex), cmd.first_instance,
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
// }

// d3d11_record_commands :: proc(
//     device: Device,
//     cmdbuf: ^D3D11_Command_Buffer_Impl,
//     loc := #caller_location,
// ) {
//     device_impl := d3d11_device_get_impl(device, loc)

//     command_allocator_iterator_reset(&cmdbuf.commands)
//     for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
//         #partial switch &cmd in curr {
//         case Begin_Render_Pass_Cmd:
//             d3d11_record_render_pass(device, cmdbuf, &cmd, loc)

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
//             if cmd.size == 0 {
//                 break
//             }

//             src_impl := d3d11_buffer_get_impl(cmd.src, cmd.loc)
//             dst_impl := d3d11_buffer_get_impl(cmd.dst, cmd.loc)

//             src_authoritative := d3d11_buffer_get_gpu_usable_storage(src_impl, cmd.loc)
//             src_d3d_buffer := d3d11_buffer_storage_get_buffer(src_authoritative)

//             dst_authoritative := &dst_impl.storages[dst_impl.last_updated_storage]

//             dst_storage: ^D3D11_Buffer_Storage
//             if d3d11_buffer_storage_supports_copy_dst(dst_authoritative) {
//                 dst_storage = dst_authoritative
//             } else {
//                 dst_storage = d3d11_buffer_get_or_create_dst_copyable_storage(dst_impl, cmd.loc)
//             }
//             dst_d3d_buffer := d3d11_buffer_storage_get_buffer(dst_storage)

//             src_box := d3d11.BOX{
//                 left   = u32(cmd.src_offset),
//                 top    = 0,
//                 front  = 0,
//                 right  = u32(cmd.src_offset + cmd.size),
//                 bottom = 1,
//                 back   = 1,
//             }

//             device_impl.ctx.d3d_context->CopySubresourceRegion(
//                 dst_d3d_buffer, 0, u32(cmd.dst_offset), 0, 0,
//                 src_d3d_buffer, 0, &src_box,
//             )

//             d3d11_buffer_incr_storage_rev_and_make_latest(
//                 dst_impl, dst_storage, device_impl, cmd.loc)

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
//             unimplemented(loc = cmd.loc)

//         case Transition_Texture_Cmd:
//             unimplemented(loc = cmd.loc)
//         }
//     }
// }

// d3d11_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
//     impl := d3d11_queue_get_impl(queue, loc)
//     device_impl := d3d11_device_get_impl(impl.device, loc)

//     d3d11_transfer_batch_flush(&device_impl.transfer_batch, impl.device, loc)

//     for cmdbuf in commands {
//         encoder_impl := d3d11_command_encoder_get_impl(Command_Encoder(cmdbuf), loc)
//         d3d11_record_commands(impl.device, &encoder_impl.cmdbuf, loc)
//     }

//     d3d11_flush_pending_cpu_sync(device_impl, loc)
// }

// d3d11_queue_write_buffer :: proc(
//     queue: Queue,
//     buffer: Buffer,
//     bufferOffset: u64,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_queue_write_texture :: proc(
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

// d3d11_queue_submit_for_index :: proc(
//     queue: Queue,
//     commands: []Command_Buffer,
//     loc := #caller_location,
// ) -> Submission_Index {
//     unimplemented(loc = loc)
// }

// d3d11_queue_get_timestamp_period :: proc(queue: Queue, loc := #caller_location) -> f32 {
//     unimplemented(loc = loc)
// }

// d3d11_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
//     impl := d3d11_queue_get_impl(queue, loc)
//     add_ref(impl, loc)
// }

// d3d11_queue_release :: proc(queue: Queue, loc := #caller_location) {
//     impl := d3d11_queue_get_impl(queue, loc)
//     if release_ref(impl) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.queues, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Bundle
// // -----------------------------------------------------------------------------

// d3d11_render_bundle_set_label :: proc(
//     render_bundle: Render_Bundle,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Bundle_Encoder
// // -----------------------------------------------------------------------------

// d3d11_render_bundle_encoder_draw :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     vertex_count: u32,
//     instance_count: u32,
//     first_vertex: u32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_draw_indexed :: proc(
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

// d3d11_render_bundle_encoder_draw_indexed_indirect :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_draw_indirect :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_finish :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     descriptor: ^Render_Bundle_Descriptor,
//     loc := #caller_location,
// ) -> Render_Bundle {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_insert_debug_marker :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_pop_debug_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_push_debug_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_bind_group :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_immediates :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_index_buffer :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     buffer: Buffer,
//     format: Index_Format,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_label :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_pipeline :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_set_vertex_buffer :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     slot: u32,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_add_ref :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_bundle_encoder_release :: proc(
//     render_bundle_encoder: Render_Bundle_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Pass_Encoder
// // -----------------------------------------------------------------------------

// D3D11_Render_Pass_Encoder_Handle :: distinct hm.Handle64

// D3D11_Render_Pass_Encoder_Impl :: struct {
//     device:       Device,
//     encoder:      Command_Encoder,
//     handle:       D3D11_Render_Pass_Encoder_Handle,
//     ref:          Ref_Count_Type,
//     is_rendering: bool,
// }

// d3d11_render_pass_encoder_get_impl :: #force_inline proc "contextless" (
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) -> ^D3D11_Render_Pass_Encoder_Impl {
//     assert_contextless(render_pass_encoder != {}, "Invalid Render_Pass_Encoder", loc)
//     h := id_to_handle(render_pass_encoder)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     render_pass_encoder_handle := D3D11_Render_Pass_Encoder_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.render_pass_encoders, render_pass_encoder_handle)
// }

// d3d11_render_pass_encoder_begin_occlusion_query :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     query_index: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_draw :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     vertex_count: u32,
//     instance_count: u32,
//     first_vertex: u32,
//     first_instance: u32,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Draw_Cmd, loc)

//     cmd.vertex_count = vertex_count
//     cmd.instance_count = instance_count
//     cmd.first_vertex = first_vertex
//     cmd.first_instance = first_instance
// }

// d3d11_render_pass_encoder_draw_indexed :: proc(
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

// d3d11_render_pass_encoder_draw_indexed_indirect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_draw_indirect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     indirect_buffer: Buffer,
//     indirect_offset: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_end :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)
//     impl.is_rendering = false

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     encoder_impl.is_rendering = false
// }

// d3d11_render_pass_encoder_end_occlusion_query :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_execute_bundles :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     bundles: []Render_Bundle,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_insert_debug_marker :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     marker_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_pop_debug_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_push_debug_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     group_label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_bind_group :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     group_index: u32,
//     group: Bind_Group,
//     dynamic_offsets: []u32,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Set_Bind_Group_Cmd, loc)

//     cmd.index = group_index
//     cmd.bind_group = group

//     // TODO: dynamic offsets
// }

// d3d11_render_pass_encoder_set_blend_constant :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     color: Color,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_immediates :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     offset: u32,
//     data: rawptr,
//     size: uint,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_index_buffer :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     buffer: Buffer,
//     format: Index_Format,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_label :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_pipeline :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     cmd := command_allocator_allocate(
//         &encoder_impl.cmdbuf.commands, Set_Render_Pipeline_Cmd, loc)

//     cmd.pipeline = pipeline
// }

// d3d11_render_pass_encoder_set_scissor_rect :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     x: u32,
//     y: u32,
//     width: u32,
//     height: u32,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_set_stencil_reference :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     reference: u32,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)
//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     cmd := command_allocator_allocate(
//         &encoder_impl.cmdbuf.commands, Set_Stencil_Reference_Cmd, loc)

//     // cmd.render_pass = render_pass_encoder
//     cmd.reference = reference
// }

// d3d11_render_pass_encoder_set_vertex_buffer :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     slot: u32,
//     buffer: Buffer,
//     offset: u64,
//     size: u64,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering, "Expected an active render pass", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Set_Vertex_Buffer_Cmd, loc)

//     cmd.slot = slot
//     cmd.buffer = buffer
//     cmd.offset = offset
//     cmd.size = size
// }

// d3d11_render_pass_encoder_set_viewport :: proc(
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

// d3d11_render_pass_encoder_add_ref :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pass_encoder_release :: proc(
//     render_pass_encoder: Render_Pass_Encoder,
//     loc := #caller_location,
// ) {
//     impl := d3d11_render_pass_encoder_get_impl(render_pass_encoder, loc)

//     assert(impl.is_rendering == false, "Releasing render pass while rendering", loc)

//     encoder_impl := d3d11_command_encoder_get_impl(impl.encoder, loc)
//     assert(encoder_impl.is_encoding == false, "Releasing render pass while encoding", loc)

//     if release_ref(impl) {
//         d3d11_command_encoder_release(impl.encoder, loc)
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.render_pass_encoders, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Render_Pipeline
// // -----------------------------------------------------------------------------

// D3D11_Render_Pipeline_Handle :: distinct hm.Handle64

// D3D11_Vertex_Buffer_Info :: struct {
//     stride:     u32,
//     step_mode:  Vertex_Step_Mode,
//     attributes: []Vertex_Attribute,
// }

// D3D11_Render_Pipeline_Impl :: struct {
//     device:              Device,
//     vertex_shader:       ^d3d11.IVertexShader,
//     pixel_shader:        ^d3d11.IPixelShader,
//     input_layout:        ^d3d11.IInputLayout,
//     blend_state:         ^d3d11.IBlendState,
//     rasterizer_state:    ^d3d11.IRasterizerState,
//     depth_stencil_state: ^d3d11.IDepthStencilState,
//     primitive_topology:  d3d11.PRIMITIVE_TOPOLOGY,
//     vertex_buffers:      []D3D11_Vertex_Buffer_Info,
//     layout:              Pipeline_Layout,
//     blend_factor:        [4]f32,
//     handle:              D3D11_Render_Pipeline_Handle,
//     ref:                 Ref_Count_Type,
//     sample_mask:         u32,
//     stencil_ref:         u32,
// }

// d3d11_render_pipeline_get_impl :: #force_inline proc "contextless" (
//     render_pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) -> ^D3D11_Render_Pipeline_Impl {
//     assert_contextless(render_pipeline != {}, "Invalid D3D11_Render_Pipeline_Impl", loc)
//     h := id_to_handle(render_pipeline)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     render_pipeline_handle := D3D11_Render_Pipeline_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.render_pipelines, render_pipeline_handle)
// }

// d3d11_render_pipeline_get_bind_group_layout :: proc(
//     render_pipeline: Render_Pipeline,
//     group_index: u32,
//     loc := #caller_location,
// ) -> Bind_Group_Layout {
//     unimplemented(loc = loc)
// }

// d3d11_render_pipeline_set_label :: proc(
//     render_pipeline: Render_Pipeline,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_render_pipeline_add_ref :: proc(
//     render_pipeline: Render_Pipeline, loc := #caller_location,
// ) {
//     impl := d3d11_render_pipeline_get_impl(render_pipeline, loc)
//     add_ref(impl, loc)
// }

// d3d11_render_pipeline_release :: proc(
//     render_pipeline: Render_Pipeline, loc := #caller_location,
// ) {
//     impl := d3d11_render_pipeline_get_impl(render_pipeline, loc)
//     if release_ref(impl, loc) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         context.allocator = device_impl.allocator

//         if impl.vertex_buffers != nil && len(impl.vertex_buffers) > 0 {
//             for &vb_info in impl.vertex_buffers {
//                 if vb_info.attributes != nil {
//                     delete(vb_info.attributes)
//                 }
//             }
//             delete(impl.vertex_buffers)
//             impl.vertex_buffers = nil
//         }

//         if impl.depth_stencil_state != nil {
//             impl.depth_stencil_state->Release()
//             impl.depth_stencil_state = nil
//         }

//         if impl.blend_state != nil {
//             impl.blend_state->Release()
//             impl.blend_state = nil
//         }

//         if impl.rasterizer_state != nil {
//             impl.rasterizer_state->Release()
//             impl.rasterizer_state = nil
//         }

//         if impl.input_layout != nil {
//             impl.input_layout->Release()
//             impl.input_layout = nil
//         }

//         if impl.pixel_shader != nil {
//             impl.pixel_shader->Release()
//             impl.pixel_shader = nil
//         }

//         if impl.vertex_shader != nil {
//             impl.vertex_shader->Release()
//             impl.vertex_shader = nil
//         }

//         if impl.layout != nil {
//             pipeline_layout_release(impl.layout, loc)
//             impl.layout = nil
//         }

//         hm.remove(&device_impl.render_pipelines, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Sampler
// // -----------------------------------------------------------------------------

// D3D11_Sampler_Handle :: distinct hm.Handle64

// D3D11_Sampler_Impl :: struct {
//     device:        Device,
//     sampler_state: ^d3d11.ISamplerState,
//     handle:        D3D11_Sampler_Handle,
//     ref:           Ref_Count_Type,
// }

// d3d11_sampler_get_impl :: #force_inline proc "contextless" (
//     sampler: Sampler,
//     loc := #caller_location,
// ) -> ^D3D11_Sampler_Impl {
//     assert_contextless(sampler != {}, "Invalid Sampler", loc)
//     h := id_to_handle(sampler)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     sampler_handle := D3D11_Sampler_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.samplers, sampler_handle)
// }

// d3d11_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
//     impl := d3d11_sampler_get_impl(sampler, loc)
//     add_ref(impl, loc)
// }

// d3d11_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
//     impl := d3d11_sampler_get_impl(sampler, loc)
//     if release_ref(impl, loc) {
//         impl.sampler_state->Release()
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.samplers, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Shader_Module
// // -----------------------------------------------------------------------------

// D3D11_Shader_Module_Handle :: distinct hm.Handle64

// D3D11_Shader_Type :: enum u8 {
//     Vertex,
//     Pixel,
//     Compute,
// }

// D3D11_Shader_Module_Impl :: struct {
//     device:         Device,
//     bytecode:       []u8,
//     stage:          Shader_Stage,
//     vertex_shader:  ^d3d11.IVertexShader,
//     pixel_shader:   ^d3d11.IPixelShader,
//     compute_shader: ^d3d11.IComputeShader,
//     handle:         D3D11_Shader_Module_Handle,
//     ref:            Ref_Count_Type,
// }

// d3d11_shader_module_get_impl :: #force_inline proc "contextless" (
//     shader_module: Shader_Module,
//     loc := #caller_location,
// ) -> ^D3D11_Shader_Module_Impl {
//     assert_contextless(shader_module != {}, "Invalid Shader_Module", loc)
//     h := id_to_handle(shader_module)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     shader_module_handle := D3D11_Shader_Module_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.shader_modules, shader_module_handle)
// }

// d3d11_shader_module_get_compilation_info :: proc(
//     shader_module: Shader_Module,
//     callback_info: Compilation_Info_Callback_Info,
//     loc := #caller_location,
// ) -> Future {
//     unimplemented(loc = loc)
// }

// d3d11_shader_module_set_label :: proc(
//     shader_module: Shader_Module,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
//     impl := d3d11_shader_module_get_impl(shader_module, loc)
//     add_ref(impl, loc)
// }

// d3d11_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
//     impl := d3d11_shader_module_get_impl(shader_module, loc)
//     if release_ref(impl) {
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         if impl.vertex_shader != nil { impl.vertex_shader->Release() }
//         if impl.pixel_shader != nil { impl.pixel_shader->Release() }
//         if impl.compute_shader != nil { impl.compute_shader->Release() }
//         delete(impl.bytecode, device_impl.allocator)
//         hm.remove(&device_impl.shader_modules, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_Features
// // -----------------------------------------------------------------------------

// d3d11_supported_features_free_members :: proc(
//     supportedFeatures: Supported_Features,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_Instance_Features
// // -----------------------------------------------------------------------------

// d3d11_supported_instance_features_free_members :: proc(
//     supportedInstanceFeatures: Supported_Instance_Features,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Supported_WGSL_Language_Features
// // -----------------------------------------------------------------------------

// d3d11_supported_wgsl_language_features_free_members :: proc(
//     supportedWGSLLanguageFeatures: Supported_WGSL_Language_Features,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// // -----------------------------------------------------------------------------
// // Procedures of Surface
// // -----------------------------------------------------------------------------

// D3D11_Surface_Handle :: distinct hm.Handle64

// D3D11_Surface_Impl :: struct {
//     instance:          ^D3D11_Instance_Impl,
//     device:            Device,
//     framebuffer_impl:  Texture,
//     config:            Surface_Configuration,
//     hinstance:         win32.HINSTANCE,
//     hwnd:              win32.HWND,
//     swapchain_desc:    dxgi.SWAP_CHAIN_DESC1,
//     dxgi_swapchain:    ^dxgi.ISwapChain1,
//     dxgi_format:       dxgi.FORMAT,
//     dxgi_buffer_usage: dxgi.USAGE,
//     swapchain_flags:   dxgi.SWAP_CHAIN,
//     buffer_count:      u32,
//     handle:            D3D11_Surface_Handle,
//     allocator:         runtime.Allocator,
//     ref:               Ref_Count_Type,
//     tearing_support:   bool,
// }

// @(require_results)
// d3d11_surface_get_impl :: #force_inline proc "contextless" (
//     surface: Surface,
//     loc := #caller_location,
// ) -> ^D3D11_Surface_Impl {
//     assert_contextless(surface != {}, "Invalid Instance", loc)
//     h := transmute(D3D11_Surface_Handle)surface
//     return hm.get(&gpu.d3d11.surfaces, h)
// }

// d3d11_surface_configure :: proc(
//     surface: Surface,
//     config: ^Surface_Configuration,
//     loc := #caller_location,
// ) {
//     impl := d3d11_surface_get_impl(surface, loc)
//     device_impl := d3d11_device_get_impl(config.device, loc)

//     assert(config != nil, "Invalid surface configuration", loc)
//     assert(config.width != 0, "Surface width must be > 0", loc)
//     assert(config.height != 0, "Surface height must be > 0", loc)

//     dxgi_factory := impl.instance.dxgi_factory
//     assert(dxgi_factory != nil, loc = loc)

//     // Flip-model swapchains only accept the non-sRGB format
//     format := texture_format_remove_srgb_suffix(config.format, loc)

//     buffer_count    := d3d_conv_to_buffer_count(config.present_mode)
//     dxgi_format     := d3d_conv_to_dxgi_format(format)
//     swapchain_flags := d3d_conv_to_swap_chain_flags(config.present_mode, impl.tearing_support)
//     dxgi_usage      := d3d_conv_to_dxgi_usage(config.usage, format)

//     new_desc := dxgi.SWAP_CHAIN_DESC1 {
//         Width       = config.width,
//         Height      = config.height,
//         Format      = dxgi_format,
//         Stereo      = false,
//         SampleDesc  = { Count = 1 },
//         BufferUsage = dxgi_usage,
//         BufferCount = buffer_count,
//         Scaling     = .STRETCH,
//         SwapEffect  = .FLIP_DISCARD,
//         AlphaMode   = .IGNORE,
//         Flags       = swapchain_flags,
//     }

//     impl.config = config^

//     if impl.dxgi_swapchain == nil {
//         // First configure: nothing to reuse.
//         impl.device = config.device
//         d3d11_device_add_ref(impl.device, loc)
//         impl.swapchain_desc = new_desc

//         d3d_check(dxgi_factory->CreateSwapChainForHwnd(
//             pDevice           = device_impl.d3d_device,
//             hWnd              = impl.hwnd,
//             pDesc             = &impl.swapchain_desc,
//             pFullscreenDesc   = nil,
//             pRestrictToOutput = nil,
//             ppSwapChain       = &impl.dxgi_swapchain,
//         ))
//         d3d_check(dxgi_factory->MakeWindowAssociation(impl.hwnd, { .NO_ALT_ENTER }))
//     } else {
//         // Reconfigure: decide whether we can keep the IDXGISwapChain or must
//         assert(impl.device == config.device,
//             "D3D11 surface cannot switch devices on reconfigure", loc)

//         old_desc := impl.swapchain_desc

//         // DXGI requires a brand new swapchain if ALLOW_TEARING toggles.
//         can_reuse_swapchain :=
//             .ALLOW_TEARING in old_desc.Flags && .ALLOW_TEARING in new_desc.Flags

//         d3d11_surface_release_framebuffer(impl, device_impl, loc)

//         if !can_reuse_swapchain {
//             impl.dxgi_swapchain->Release()
//             impl.dxgi_swapchain = nil
//             impl.swapchain_desc = new_desc

//             d3d_check(dxgi_factory->CreateSwapChainForHwnd(
//                 pDevice           = device_impl.d3d_device,
//                 hWnd              = impl.hwnd,
//                 pDesc             = &impl.swapchain_desc,
//                 pFullscreenDesc   = nil,
//                 pRestrictToOutput = nil,
//                 ppSwapChain       = &impl.dxgi_swapchain,
//             ))
//             d3d_check(dxgi_factory->MakeWindowAssociation(impl.hwnd, { .NO_ALT_ENTER }))
//         } else {
//             needs_resize :=
//                 old_desc.Width  != new_desc.Width  ||
//                 old_desc.Height != new_desc.Height ||
//                 old_desc.Format != new_desc.Format ||
//                 old_desc.Flags  != new_desc.Flags

//             impl.swapchain_desc = new_desc

//             if needs_resize {
//                 d3d_check(impl.dxgi_swapchain->ResizeBuffers(
//                     buffer_count,
//                     config.width,
//                     config.height,
//                     dxgi_format,
//                     swapchain_flags,
//                 ))
//             }
//         }
//     }

//     // (Re)acquire buffer 0 and rebuild the framebuffer texture + RTV.
//     framebuffer: ^d3d11.ITexture2D
//     d3d_check(impl.dxgi_swapchain->GetBuffer(
//         0, d3d11.ITexture2D_UUID, (^rawptr)(&framebuffer)))

//     impl.dxgi_format       = dxgi_format
//     impl.dxgi_buffer_usage = dxgi_usage
//     impl.buffer_count      = buffer_count
//     impl.swapchain_flags   = swapchain_flags

//     texture_impl := hm_dynamic_add_get(&device_impl.textures, D3D11_Texture_Impl{
//         device          = config.device,
//         usage           = config.usage,
//         dimension       = .D2,
//         size            = { config.width, config.height, 1 },
//         format          = config.format,
//         mip_level_count = 1,
//         sample_count    = 1,
//         is_swapchain    = true,
//         d3d_texture     = framebuffer,
//     }) or_else panic("Failed to allocate swapchain texture handle", loc)

//     texture_handle := handle_make(texture_impl.handle, device_impl.handle)
//     impl.framebuffer_impl = handle_to_raw(Texture, texture_handle)

//     view_impl := hm_dynamic_add_get(&device_impl.texture_views, D3D11_Texture_View_Impl {
//         device            = config.device,
//         texture           = impl.framebuffer_impl,
//         format            = config.format,
//         dimension         = .D2,
//         range = {
//             aspect            = .All,
//             mip_level_count   = 1,
//             array_layer_count = 1,
//         },
//         is_swapchain      = true,
//     })

//     view_handle := handle_make(view_impl.handle, device_impl.handle)
//     texture_impl.texture_view = handle_to_raw(Texture_View, view_handle)

//     small_vec_init(&view_impl.rtv_slots, device_impl.allocator)
// }

// d3d11_surface_release_framebuffer :: proc(
//     impl: ^D3D11_Surface_Impl,
//     device_impl: ^D3D11_Device_Impl,
//     loc := #caller_location,
// ) {
//     if impl.framebuffer_impl == nil {
//         return
//     }

//     framebuffer_impl := d3d11_texture_get_impl(impl.framebuffer_impl, loc)
//     framebuffer_view_impl := d3d11_texture_view_get_impl(framebuffer_impl.texture_view, loc)

//     d3d11_texture_view_destroy(framebuffer_view_impl)

//     framebuffer_impl.d3d_texture->Release()

//     hm.remove(&device_impl.texture_views, framebuffer_view_impl.handle)
//     hm.remove(&device_impl.textures, framebuffer_impl.handle)

//     impl.framebuffer_impl = nil
// }

// d3d11_surface_get_capabilities :: proc(
//     surface: Surface,
//     adapter: Adapter,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> (
//     caps: Surface_Capabilities,
//     status: Status,
// ) {
//     impl := d3d11_surface_get_impl(surface, loc)

//     formats := make([dynamic]Texture_Format, 0, 6, allocator)
//     append(&formats, ..[]Texture_Format{
//         .BGRA8_Unorm_Srgb,
//         .BGRA8_Unorm,
//         .RGBA8_Unorm_Srgb,
//         .RGBA8_Unorm,
//         .RGB10A2_Unorm,
//         .RGBA16_Float,
//     })

//     present_modes := make([dynamic]Present_Mode, 0, 3, allocator)
//     append(&present_modes, ..[]Present_Mode{
//         .Fifo,
//         .Mailbox,
//     })
//     if impl.tearing_support {
//         append(&present_modes, Present_Mode.Immediate)
//     }

//     alpha_modes := make([dynamic]Composite_Alpha_Mode, 0, 2, allocator)
//     append(&alpha_modes, ..[]Composite_Alpha_Mode{
//         .Opaque,
//         .Premultiplied,
//     })

//     caps.formats = formats[:]
//     caps.present_modes = present_modes[:]
//     caps.alpha_modes = alpha_modes[:]
//     caps.usages = {.Render_Attachment, .Texture_Binding, .Copy_Src, .Copy_Dst}

//     return caps, .Success
// }

// d3d11_surface_get_current_texture :: proc(
//     surface: Surface,
//     loc := #caller_location,
// ) -> (
//     surface_texture: Surface_Texture,
// ) {
//     impl := d3d11_surface_get_impl(surface, loc)
//     surface_texture.texture = impl.framebuffer_impl
//     surface_texture.status = .Success_Optimal
//     return
// }

// d3d11_surface_present :: proc(surface: Surface, loc := #caller_location) -> Status {
//     impl := d3d11_surface_get_impl(surface, loc)
//     sync_interval := d3d_present_mode_to_swap_interval(impl.config.present_mode)
//     hr := impl.dxgi_swapchain->Present(sync_interval, {})
//     d3d_check(hr, "Failed to present")
//     return .Success
// }

// d3d11_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_surface_unconfigure :: proc(surface: Surface, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
//     impl := d3d11_surface_get_impl(surface, loc)
//     add_ref(impl, loc)
// }

// d3d11_surface_release :: proc(surface: Surface, loc := #caller_location) {
//     impl := d3d11_surface_get_impl(surface, loc)
//     if release_ref(impl, loc) {
//         context.allocator = impl.allocator

//         if impl.dxgi_swapchain != nil {
//             device_impl := d3d11_device_get_impl(impl.device, loc)
//             d3d11_surface_release_framebuffer(impl, device_impl, loc)
//             impl.dxgi_swapchain->Release()
//             d3d11_device_release(impl.device, loc)
//             impl.device = nil
//             impl.dxgi_swapchain = nil
//         }

//         d3d11_instance_release(Instance(impl.instance), loc)
//         sync.guard(&gpu.d3d11.mtx)
//         hm.remove(&gpu.d3d11.surfaces, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Surface_Capabilities
// // -----------------------------------------------------------------------------

// d3d11_surface_capabilities_free_members :: proc(
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

// D3D11_Texture_Handle :: distinct hm.Handle64

D3D11_Texture_Kind :: enum {
    Normal,
    Staging,
    Interim,
}

// D3D11_Texture_Impl :: struct {
//     using desc_impl: Texture_Descriptor_Impl,
//     device:          Device,
//     texture_view:    Texture_View,
//     d3d_texture:     ^d3d11.IResource,
//     kind:            D3D11_Texture_Kind,
//     dxgi_format:     dxgi.FORMAT,
//     handle:          D3D11_Texture_Handle,
//     ref:             Ref_Count_Type,
//     is_swapchain:    bool,
// }

// d3d11_texture_get_impl :: #force_inline proc "contextless" (
//     texture: Texture,
//     loc := #caller_location,
// ) -> ^D3D11_Texture_Impl {
//     assert_contextless(texture != {}, "Invalid texture", loc)
//     h := id_to_handle(texture)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     texture_handle := D3D11_Texture_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.textures, texture_handle)
// }

// d3d11_texture_get_mip_level_single_subresource_virtual_size :: proc(
//     texture: Texture,
//     level:   u32,
//     aspect:  Texture_Aspect,
//     loc := #caller_location,
// ) -> Extent_3D {
//     aspect_size := texture_get_size(texture, loc)

//     extent := Extent_3D{
//         width               = max(aspect_size.width >> level, 1),
//         height              = 1,
//         depth_or_array_layers = 1,
//     }

//     texture_impl := d3d11_texture_get_impl(texture, loc)

//     if texture_impl.dimension == .D1 {
//         return extent
//     }

//     extent.height = max(aspect_size.height >> level, 1)
//     if texture_impl.dimension == .D2 {
//         return extent
//     }

//     extent.depth_or_array_layers = max(aspect_size.depth_or_array_layers >> level, 1)
//     return extent
// }

// d3d11_texture_create_view :: proc(
//     texture: Texture,
//     descriptor: ^Texture_View_Descriptor = nil,
//     loc := #caller_location,
// ) -> Texture_View {
//     impl := d3d11_texture_get_impl(texture, loc)

//     if impl.is_swapchain {
//         return impl.texture_view
//     } else {
//         device_impl := d3d11_device_get_impl(impl.device, loc)

//         desc := resolve_texture_view_descriptor(texture, impl.device, descriptor, loc)

//         view_impl := hm_dynamic_add_get(&device_impl.texture_views, D3D11_Texture_View_Impl{
//             device    = impl.device,
//             texture   = texture,
//             format    = desc.format,
//             dimension = desc.dimension,
//             usage     = desc.usage,
//             range     = desc.range,
//             label     = desc.label,
//         })

//         init_ref(view_impl, loc)
//         d3d11_texture_add_ref(texture, loc)

//         view_handle := handle_make(view_impl.handle, device_impl.handle)
//         view := handle_to_raw(Texture_View, view_handle)

//         small_vec_init(&view_impl.rtv_slots, device_impl.allocator)

//         return view
//     }
// }

// d3d11_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_texture_get_depth_or_array_layers :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.size.depth_or_array_layers
// }

// d3d11_texture_get_descriptor :: proc(
//     texture: Texture,
//     loc := #caller_location,
// ) -> Texture_Descriptor {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc
// }

// d3d11_texture_get_dimension :: proc(
//     texture: Texture, loc := #caller_location,
// ) -> Texture_Dimension {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.dimension
// }

// d3d11_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.format
// }

// d3d11_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.size.height
// }

// d3d11_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.mip_level_count
// }

// d3d11_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.sample_count
// }

// d3d11_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.size
// }

// d3d11_texture_get_texture_binding_view_dimension :: proc(
//     texture: Texture,
//     loc := #caller_location,
// ) -> Texture_View_Dimension {
//     unimplemented(loc = loc)
// }

// d3d11_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.usage
// }

// d3d11_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
//     impl := d3d11_texture_get_impl(texture, loc)
//     return impl.desc.size.width
// }

// d3d11_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
//     unimplemented(loc = loc)
// }

// d3d11_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
//     impl := d3d11_texture_get_impl(texture, loc)

//     if impl.is_swapchain {
//         return
//     }

//     add_ref(impl, loc)
// }

// d3d11_texture_release :: proc(texture: Texture, loc := #caller_location) {
//     impl := d3d11_texture_get_impl(texture, loc)

//     if impl.is_swapchain {
//         return
//     }

//     if release_ref(impl, loc) {
//         impl.d3d_texture->Release()
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.textures, impl.handle)
//     }
// }

// // -----------------------------------------------------------------------------
// // Procedures of Texture_View
// // -----------------------------------------------------------------------------

// D3D11_Texture_View_Handle :: distinct hm.Handle64

// D3D11_Texture_View_Impl :: struct {
//     // Initialization
//     using desc:            Texture_View_Descriptor_Impl,
//     device:                Device,
//     texture:               Texture,

//     // Handles
//     srv:                   ^d3d11.IShaderResourceView,
//     rtv_slots:             Small_Vec(1, int),
//     dsv:                   ^d3d11.IDepthStencilView,
//     dsv_depth_read_only:   bool,
//     dsv_stencil_read_only: bool,
//     uav:                   ^d3d11.IUnorderedAccessView,

//     // Internal
//     handle:                D3D11_Texture_View_Handle,
//     ref:                   Ref_Count_Type,
//     is_swapchain:          bool,
// }

// d3d11_texture_view_get_impl :: #force_inline proc "contextless" (
//     texture_view: Texture_View,
//     loc := #caller_location,
// ) -> ^D3D11_Texture_View_Impl {
//     assert_contextless(texture_view != {}, "Invalid Texture_View", loc)
//     h := id_to_handle(texture_view)
//     device_impl := device_pool_get(&gpu.d3d11.devices, h.fields.device_idx)
//     assert_contextless(device_impl != nil, "Invalid device", loc)
//     texture_view_handle := D3D11_Texture_View_Handle {
//         idx = h.fields.idx,
//         gen = h.fields.gen,
//     }
//     return hm.get(&device_impl.texture_views, texture_view_handle)
// }

// d3d11_texture_create_shader_resource_view :: proc(
//     view_impl: ^D3D11_Texture_View_Impl,
//     loc := #caller_location,
// ) -> ^D3D11_IShaderResourceView1 {
//     texture_impl := d3d11_texture_get_impl(view_impl.texture, loc)
//     device_impl := d3d11_device_get_impl(texture_impl.device, loc)

//     range := view_impl.range

//     srv_desc: D3D11_SHADER_RESOURCE_VIEW_DESC1
//     srv_desc.Format = d3d_shader_resource_view_format(
//         texture_impl.format, view_impl.format, range.aspect)

//     if texture_impl.sample_count > 1 {
//         #partial switch view_impl.dimension {
//         case .D2_Array:
//             assert(texture_impl.size.depth_or_array_layers == 1, loc = loc)
//             fallthrough
//         case .D2:
//             assert(texture_impl.dimension == .D2, loc = loc)
//             srv_desc.ViewDimension = .TEXTURE2DMS
//         case:
//             unreachable()
//         }
//     } else {
//         switch view_impl.dimension {
//         case .D1:
//             srv_desc.ViewDimension             = .TEXTURE1D
//             srv_desc.Texture1D.MipLevels       = range.mip_level_count
//             srv_desc.Texture1D.MostDetailedMip = range.base_mip_level

//         case .D2, .D2_Array:
//             assert(texture_impl.dimension == .D2, loc = loc)
//             srv_desc.ViewDimension                   = .TEXTURE2DARRAY
//             srv_desc.Texture2DArray.ArraySize         = range.array_layer_count
//             srv_desc.Texture2DArray.FirstArraySlice   = range.base_array_layer
//             srv_desc.Texture2DArray.MipLevels         = range.mip_level_count
//             srv_desc.Texture2DArray.MostDetailedMip   = range.base_mip_level
//             srv_desc.Texture2DArray.PlaneSlice         = aspect_index(range.aspect, loc)

//         case .Cube, .Cube_Array:
//             assert(texture_impl.dimension == .D2, loc = loc)
//             assert(range.array_layer_count % 6 == 0, loc = loc)
//             srv_desc.ViewDimension                     = .TEXTURECUBEARRAY
//             srv_desc.TextureCubeArray.First2DArrayFace = range.base_array_layer
//             srv_desc.TextureCubeArray.NumCubes         = range.array_layer_count / 6
//             srv_desc.TextureCubeArray.MipLevels        = range.mip_level_count
//             srv_desc.TextureCubeArray.MostDetailedMip  = range.base_mip_level

//         case .D3:
//             assert(texture_impl.dimension == .D3, loc = loc)
//             srv_desc.ViewDimension             = .TEXTURE3D
//             srv_desc.Texture3D.MostDetailedMip = range.base_mip_level
//             srv_desc.Texture3D.MipLevels       = range.mip_level_count

//         case .Undefined:
//             unreachable()
//         }
//     }

//     srv: ^D3D11_IShaderResourceView1
//     d3d_check(device_impl.d3d_device3->CreateShaderResourceView1(
//         texture_impl.d3d_texture, &srv_desc, &srv))

//     return srv
// }

// d3d11_texture_view_get_or_create_srv :: proc(
//     view: ^D3D11_Texture_View_Impl,
//     loc := #caller_location,
// ) -> ^d3d11.IShaderResourceView {
//     if view.srv != nil { return view.srv }
//     view.srv = d3d11_texture_create_shader_resource_view(view, loc)
//     return view.srv
// }

// d3d11_texture_create_render_target_view :: proc(
//     view_impl: ^D3D11_Texture_View_Impl,
//     depth_slice: u32,
//     loc := #caller_location,
// ) -> ^D3D11_IRenderTargetView1 {
//     texture_impl := d3d11_texture_get_impl(view_impl.texture, loc)
//     device_impl := d3d11_device_get_impl(texture_impl.device, loc)

//     assert(texture_impl.dimension != .Undefined, "Invalid texture dimension", loc)

//     range := view_impl.range

//     // base_array_layer + depth_slice for 2D, or depth_slice directly as the
//     // W-slice offset for 3D.
//     base_slice  := range.base_array_layer + depth_slice
//     slice_count := range.array_layer_count

//     rtv_desc: D3D11_RENDER_TARGET_VIEW_DESC1
//     rtv_desc.Format = d3d_conv_to_dxgi_format(view_impl.format)

//     if texture_impl.sample_count > 1 {
//         assert(texture_impl.dimension == .D2, loc = loc)
//         assert(texture_impl.mip_level_count == 1, loc = loc)
//         assert(range.base_mip_level == 0, loc = loc)
//         assert(base_slice == 0, loc = loc)
//         assert(slice_count == 1, loc = loc)
//         assert(aspect_index(range.aspect) == 0, loc = loc)
//         rtv_desc.ViewDimension = .TEXTURE2DMS
//     } else {
//         switch texture_impl.dimension {
//         case .Undefined:
//             unreachable()
//         case .D2:
//             // Always TEXTURE2DARRAY: D3D11_TEX2D_RTV has no base-array-layer /
//             // layer-count fields, so 2D views are treated as 1-layer 2D arrays,
//             // same as the SRV path.
//             rtv_desc.ViewDimension                  = .TEXTURE2DARRAY
//             rtv_desc.Texture2DArray.MipSlice        = range.base_mip_level
//             rtv_desc.Texture2DArray.FirstArraySlice = base_slice
//             rtv_desc.Texture2DArray.ArraySize       = slice_count
//             rtv_desc.Texture2DArray.PlaneSlice      = aspect_index(range.aspect)
//         case .D3:
//             rtv_desc.ViewDimension         = .TEXTURE3D
//             rtv_desc.Texture3D.MipSlice    = range.base_mip_level
//             rtv_desc.Texture3D.FirstWSlice = base_slice
//             rtv_desc.Texture3D.WSize       = slice_count
//         case .D1:
//             rtv_desc.ViewDimension      = .TEXTURE1D
//             rtv_desc.Texture1D.MipSlice = range.base_mip_level
//         }
//     }

//     rtv: ^D3D11_IRenderTargetView1
//     d3d_check(device_impl.d3d_device3->CreateRenderTargetView1(
//         texture_impl.d3d_texture, &rtv_desc, &rtv))
//     return rtv
// }

// d3d11_texture_view_get_or_create_rtv :: proc(
//     view: ^D3D11_Texture_View_Impl,
//     depth_slice: u32,
//     loc := #caller_location,
// ) -> ^D3D11_IRenderTargetView1 {
//     device_impl := d3d11_device_get_impl(view.device, loc)

//     virtual_size := d3d11_texture_get_mip_level_single_subresource_virtual_size(
//         view.texture, view.range.base_mip_level, view.range.aspect, loc)
//     assert(depth_slice < virtual_size.depth_or_array_layers, loc = loc)

//     for small_vec_len(&view.rtv_slots) <= int(depth_slice) {
//         small_vec_push_back(&view.rtv_slots, -1)
//     }

//     slot_index_ptr := small_vec_get_ptr(&view.rtv_slots, depth_slice, loc)

//     if slot_index_ptr^ != -1 {
//         assert(!xar.is_freed(&device_impl.rtv_pool, slot_index_ptr^), loc = loc)
//         return xar.get(&device_impl.rtv_pool, slot_index_ptr^, loc)
//     }

//     rtv := d3d11_texture_create_render_target_view(view, depth_slice, loc)

//     _, pool_index, push_err := xar.push_with_index(&device_impl.rtv_pool, rtv, loc)
//     assert(push_err == nil, loc = loc)

//     slot_index_ptr^ = pool_index

//     return rtv
// }

// d3d11_texture_create_depth_stencil_view :: proc(
//     view_impl: ^D3D11_Texture_View_Impl,
//     depth_read_only: bool,
//     stencil_read_only: bool,
//     loc := #caller_location,
// ) -> ^d3d11.IDepthStencilView {
//     texture_impl := d3d11_texture_get_impl(view_impl.texture, loc)
//     device_impl := d3d11_device_get_impl(texture_impl.device, loc)

//     range := view_impl.range

//     assert(range.mip_level_count == 1, loc = loc)

//     dsv_desc: d3d11.DEPTH_STENCIL_VIEW_DESC
//     dsv_desc.Format = d3d_conv_to_dxgi_format(texture_impl.format)
//     dsv_desc.Flags  = {}

//     if depth_read_only && aspect_includes_depth(range.aspect) {
//         dsv_desc.Flags |= {.DEPTH}
//     }
//     if stencil_read_only && aspect_includes_stencil(range.aspect) {
//         dsv_desc.Flags |= {.STENCIL}
//     }

//     if texture_impl.sample_count > 1 {
//         assert(texture_impl.mip_level_count == 1, loc = loc)
//         assert(range.base_mip_level == 0, loc = loc)
//         assert(range.base_array_layer == 0, loc = loc)
//         assert(range.array_layer_count == 1, loc = loc)
//         dsv_desc.ViewDimension = .TEXTURE2DMS
//     } else {
//         dsv_desc.ViewDimension                 = .TEXTURE2DARRAY
//         dsv_desc.Texture2DArray.MipSlice        = range.base_mip_level
//         dsv_desc.Texture2DArray.FirstArraySlice = range.base_array_layer
//         dsv_desc.Texture2DArray.ArraySize        = range.array_layer_count
//     }

//     dsv: ^d3d11.IDepthStencilView
//     d3d_check(device_impl.d3d_device3->CreateDepthStencilView(
//         texture_impl.d3d_texture, &dsv_desc, &dsv))

//     return dsv
// }

// d3d11_texture_view_get_or_create_dsv :: proc(
//     view: ^D3D11_Texture_View_Impl,
//     depth_read_only: bool,
//     stencil_read_only: bool,
//     loc := #caller_location,
// ) -> ^d3d11.IDepthStencilView {
//     if view.dsv != nil &&
//            view.dsv_depth_read_only == depth_read_only &&
//            view.dsv_stencil_read_only == stencil_read_only {
//         return view.dsv
//     }

//     if view.dsv != nil {
//         view.dsv->Release()
//         view.dsv = nil
//     }

//     view.dsv = d3d11_texture_create_depth_stencil_view(
//         view, depth_read_only, stencil_read_only, loc)

//     view.dsv_depth_read_only = depth_read_only
//     view.dsv_stencil_read_only = stencil_read_only

//     return view.dsv
// }

// d3d11_texture_view_get_or_create_uav :: proc(
//     view: ^D3D11_Texture_View_Impl,
//     loc := #caller_location,
// ) -> ^d3d11.IUnorderedAccessView {
//     if view.uav != nil { return view.uav }

//     texture_impl := d3d11_texture_get_impl(view.texture, loc)
//     device_impl := d3d11_device_get_impl(texture_impl.device, loc)

//     uav_desc: d3d11.UNORDERED_ACCESS_VIEW_DESC
//     uav_desc.Format = d3d_conv_to_dxgi_format(view.format)
//     assert(texture_impl.sample_count == 1, loc = loc)

//     switch view.dimension {
//     case .D1:
//         uav_desc.ViewDimension = .TEXTURE1D
//         uav_desc.Texture1D.MipSlice = view.range.base_mip_level
//     case .D2:
//         uav_desc.ViewDimension = .TEXTURE2D
//         uav_desc.Texture2D.MipSlice = view.range.base_mip_level
//     case .D2_Array:
//         uav_desc.ViewDimension = .TEXTURE2DARRAY
//         uav_desc.Texture2DArray.FirstArraySlice = view.range.base_array_layer
//         uav_desc.Texture2DArray.ArraySize       = view.range.array_layer_count
//         uav_desc.Texture2DArray.MipSlice        = view.range.base_mip_level
//     case .D3:
//         vsize := d3d11_texture_get_mip_level_single_subresource_virtual_size(
//             view.texture, view.range.base_mip_level, view.range.aspect, loc)
//         uav_desc.ViewDimension         = .TEXTURE3D
//         uav_desc.Texture3D.FirstWSlice = 0
//         uav_desc.Texture3D.WSize       = max(u32(1), vsize.depth_or_array_layers)
//         uav_desc.Texture3D.MipSlice    = view.range.base_mip_level
//     case .Cube, .Cube_Array, .Undefined:
//         panic("D3D11: Cube/cube-array can't be storage textures", loc)
//     }

//     d3d_check(device_impl.d3d_device->CreateUnorderedAccessView(
//         texture_impl.d3d_texture, &uav_desc, &view.uav))

//     return view.uav
// }

// d3d11_texture_view_set_label :: proc(
//     texture_view: Texture_View,
//     label: string,
//     loc := #caller_location,
// ) {
//     unimplemented(loc = loc)
// }

// d3d11_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
//     impl := d3d11_texture_view_get_impl(texture_view, loc)

//     if impl.is_swapchain {
//         return
//     }

//     add_ref(impl, loc)
// }

// d3d11_texture_view_destroy :: proc(view_impl: ^D3D11_Texture_View_Impl) {
//     if view_impl.srv != nil { view_impl.srv->Release() }

//     device_impl := d3d11_device_get_impl(view_impl.device)

//     n := small_vec_len(&view_impl.rtv_slots)
//     for i in 0..<n {
//         slot_index := small_vec_get_ptr(&view_impl.rtv_slots, i)^
//         if slot_index != -1 {
//             rtv := xar.get(&device_impl.rtv_pool, slot_index)
//             if rtv != nil do rtv->Release()
//             xar.release(&device_impl.rtv_pool, slot_index)
//         }
//     }
//     small_vec_destroy(&view_impl.rtv_slots)

//     if view_impl.dsv != nil { view_impl.dsv->Release() }
//     if view_impl.uav != nil { view_impl.uav->Release() }
// }

// d3d11_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
//     impl := d3d11_texture_view_get_impl(texture_view, loc)

//     if impl.is_swapchain {
//         return
//     }

//     if release_ref(impl, loc) {
//         d3d11_texture_release(impl.texture)
//         d3d11_texture_view_destroy(impl)
//         device_impl := d3d11_device_get_impl(impl.device, loc)
//         hm.remove(&device_impl.texture_views, impl.handle)
//     }
// }
