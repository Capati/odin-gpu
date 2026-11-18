#+build !js
package gpu

// Core
import "base:intrinsics"
import "core:log"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:time"

// Vendor
import gpua "allocator"
import "lib/vma"
import vk "vendor:vulkan"

VK_Device_VTable :: struct {
    vk_device: vk.Device,
    using fp:  vk.Device_VTable,
}

VK_BUFFER_ORDERED_USES_MASK  :: BUFFER_USES_INCLUSIVE | {.Map_Write}
VK_TEXTURE_ORDERED_USES_MASK :: TEXTURE_USES_INCLUSIVE

VK_DHM_Bind_Groups            :: DHM_Resource(VK_Bind_Group_Impl, VK_Bind_Group_Handle)
VK_DHM_Bind_Group_Layouts     :: DHM_Resource(
    VK_Bind_Group_Layout_Impl,
    VK_Bind_Group_Layout_Handle,
)
VK_DHM_Buffers                :: DHM_Resource(VK_Buffer_Impl, VK_Buffer_Handle)
VK_DHM_Command_Buffers        :: DHM_Resource(VK_Command_Buffer_Wrapper, VK_Command_Buffer_Handle)
VK_DHM_Command_Encoders       :: DHM_Resource(VK_Command_Encoder_Impl, VK_Command_Encoder_Handle)
VK_DHM_Compute_Passes         :: DHM_Resource(VK_Compute_Pass_Impl, VK_Compute_Pass_Handle)
VK_DHM_Pipeline_Layouts       :: DHM_Resource(VK_Pipeline_Layout_Impl, VK_Pipeline_Layout_Handle)
VK_DHM_Queues                 :: DHM_Resource(VK_Queue_Impl, VK_Queue_Handle)
VK_DHM_Render_Passes          :: DHM_Resource(VK_Render_Pass_Impl, VK_Render_Pass_Handle)
VK_DHM_Render_Pipelines       :: DHM_Resource(VK_Render_Pipeline_Impl, VK_Render_Pipeline_Handle)
VK_DHM_Compute_Pipelines      :: DHM_Resource(VK_Compute_Pipeline_Impl, VK_Compute_Pipeline_Handle)
VK_DHM_Samplers               :: DHM_Resource(VK_Sampler_Impl, VK_Sampler_Handle)
VK_DHM_Render_Bundles         :: DHM_Resource(VK_Render_Bundle_Impl, VK_Render_Bundle_Handle)
VK_DHM_Render_Bundle_Encoders :: DHM_Resource(
    VK_Render_Bundle_Encoder_Impl,
    VK_Render_Bundle_Encoder_Handle,
)
VK_DHM_Query_Sets             :: DHM_Resource(VK_Query_Set_Impl, VK_Query_Set_Handle)
VK_DHM_Shader_Modules         :: DHM_Resource(VK_Shader_Module_Impl, VK_Shader_Module_Handle)
VK_DHM_Texture_Views          :: DHM_Resource(VK_Texture_View_Impl, VK_Texture_View_Handle)
VK_DHM_Textures               :: DHM_Resource(VK_Texture_Impl, VK_Texture_Handle)

VK_Error_Scope :: struct {
    filter:  Error_Filter,
    error:   Error_Type,
    message: string,
}

VK_Device_Impl :: struct {
    // Base
    using base: _Device_Impl,

    // Resources
    bind_groups:            VK_DHM_Bind_Groups,
    bind_group_layouts:     VK_DHM_Bind_Group_Layouts,
    buffers:                VK_DHM_Buffers,
    command_buffers:        VK_DHM_Command_Buffers,
    command_encoders:       VK_DHM_Command_Encoders,
    computer_passes:        VK_DHM_Compute_Passes,
    compute_pipelines:      VK_DHM_Compute_Pipelines,
    pipeline_layouts:       VK_DHM_Pipeline_Layouts,
    queues:                 VK_DHM_Queues,
    render_passes:          VK_DHM_Render_Passes,
    render_pipelines:       VK_DHM_Render_Pipelines,
    samplers:               VK_DHM_Samplers,
    render_bundles:         VK_DHM_Render_Bundles,
    render_bundle_encoders: VK_DHM_Render_Bundle_Encoders,
    query_sets:             VK_DHM_Query_Sets,
    // Query sets destroyed by the caller. Their handles may still be referenced
    // by a recorded command buffer, so keep the tombstone until submit checks it.
    destroyed_query_sets:   map[Query_Set]bool,
    shader_modules:         VK_DHM_Shader_Modules,
    texture_views:          VK_DHM_Texture_Views,
    textures:               VK_DHM_Textures,

    // Initialization
    queue:                       VK_Queue_Default_Impl,
    vk_device:                   vk.Device,
    pipeline_cache:              vk.PipelineCache,
    fp:                          VK_Device_VTable,
    submitter:                   VK_Submit_Context,
    descriptor:                  VK_Descriptor_Allocator,
    deferred:                    VK_Deferred_Deletor,
    vma_allocator:               vma.Allocator,
    gpu_allocator:               gpua.VK_Allocator,
    non_coherent_atom_size_mask: vk.DeviceSize,
    // Global bit mask AND-ed with any memoryTypeBits to disallow certain memory types.
    valid_memory_type_bits:      u32,
    queue_flags:                 vk.QueueFlags,
    caps:                        VK_Private_Capabilities,

    // Default layouts
    vk_empty_pipeline_layout:       vk.PipelineLayout,
    vk_empty_descriptor_set_layout: vk.DescriptorSetLayout,

    // Resource caches
    render_pass_cache:           map[VK_Render_Pass_Key]vk.RenderPass,
    // MRU handles, not keys: a cache hit reorders this on every pass, and
    // shifting 8-byte handles is far cheaper than shifting 360-byte keys.
    render_pass_cache_order:     [VK_RENDER_PASS_CACHE_MAX]vk.RenderPass,
    render_pass_cache_order_len: u32,
    // Separate locks keep cache access independent. They are dropped before
    // Vulkan object destruction or deferred-deletion enqueueing.
    render_pass_cache_mtx:       sync.RW_Mutex,
    framebuffer_cache:           VK_Framebuffer_Cache_Map,
    framebuffer_cache_mtx:       sync.RW_Mutex,
    sampler_cache:               VK_Sampler_Cache,
    // Labels for resources that are only a pool key.
    labels:                      VK_Label_Store,

    // Device state reported by `device_get_lost_future` and the error scopes.
    label:               string,
    default_queue_label: string,
    lost_callback_info:  Device_Lost_Callback_Info,
    // Scopes are device-global; a thread must pop the scopes it pushed. The
    // lock only keeps the stack and its message strings consistent.
    error_scopes_mtx:    sync.Mutex,
    error_scopes:        [dynamic]VK_Error_Scope,
    lost:                bool,
    destroyed:           bool,
    lost_future_id:      u64,
    // Diagnostic: one per `vkCmdPipelineBarrier` this device records.
    barrier_calls:       u64,
    // Monotonic count of buffers and textures marked `destroyed` here. Validation
    // that would otherwise re-probe every resource in a bind group on every bind
    // can skip that scan while this is zero, which is the entire steady state of
    // an application that destroys its resources at teardown. It only increases,
    // so a non-zero reading is always conservative.
    destroyed_resources: u64,
    // Buffers whose `map_state` is not `Idle`, i.e. created-with-mapping, mapped
    // or waiting on a map. Submission validation refuses any of those, so the
    // per-submit resource scan can be skipped while this is zero.
    mapped_buffers:      u64,

    // Staging rings and their reservation reclaim FIFO. `staging_mtx` guards
    // the arrays and every ring cursor. Order: submitter -> staging; ring
    // creation drops the lock before touching the device.
    staging_mtx:      sync.Mutex,
    staging_rings:    [dynamic]^VK_Staging_Ring,
    staging_reclaims: [dynamic]VK_Staging_Reclaim,
}

@(require_results)
vk_create_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor,
    loc := #caller_location,
) -> (
    device: Device,
    ok: bool,
) {
    adapter_impl := vk_adapter_get_impl(adapter, loc)

    for feature in descriptor.required_features {
        if !adapter_has_feature(adapter, feature, loc) {
            log.errorf("VULKAN: adapter does not support requested feature [%v]", feature)
            return
        }
    }
    limits_ok := true
    limits_check_ex(
        descriptor.required_limits,
        adapter_impl.limits,
        true,
        proc(name: string, requested_value: u64, allowed_value: u64, user_data: rawptr) {
            (^bool)(user_data)^ = false
            log.errorf(
                "VULKAN: requested limit %s=%d exceeds adapter limit %d",
                name,
                requested_value,
                allowed_value,
            )
        },
        &limits_ok,
    )
    if !limits_ok {
        return
    }

    // Alias to the temporary allocator
    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    api_version := adapter_impl.vk_properties.apiVersion

    impl: VK_Device_Impl

    impl.allocator = adapter_impl.allocator
    impl.adapter = adapter
    impl.instance = adapter_impl.instance
    impl.alignments = adapter_impl.alignments
    impl.dl_features = adapter_impl.dl_features
    impl.limits = descriptor.required_limits
    for feature in descriptor.required_features {
        append(&impl.features, feature)
    }
    slice.sort(impl.features[:])
    impl.caps = adapter_impl.caps
    impl.backend = .Vulkan
    impl.is_embedded = false
    if descriptor.label != "" {
        impl.label = strings.clone(descriptor.label, impl.allocator)
    }
    if descriptor.default_queue.label != "" {
        impl.default_queue_label = strings.clone(descriptor.default_queue.label, impl.allocator)
    }
    impl.lost_callback_info = descriptor.lost_callback_info
    impl.uncaptured_error_callback = descriptor.uncaptured_error_callback_info
    impl.error_scopes = make([dynamic]VK_Error_Scope, 0, 8, impl.allocator)
    impl.staging_rings = make([dynamic]^VK_Staging_Ring, 0, 4, impl.allocator)
    impl.staging_reclaims = make([dynamic]VK_Staging_Reclaim, 0, 64, impl.allocator)

    // Everything above is owned by `impl`, which only becomes the device handle
    // on the success path; a failure below must not leak it.
    defer if !ok {
        delete(impl.label)
        delete(impl.default_queue_label)
        delete(impl.error_scopes)
        delete(impl.staging_rings)
        delete(impl.staging_reclaims)
    }

    for i in 0 ..< adapter_impl.vk_mem_properties.memoryTypeCount {
        mem_type := adapter_impl.vk_mem_properties.memoryTypes[i]
        if mem_type.propertyFlags <= adapter_impl.known_memory_flags {     // subset check
            impl.valid_memory_type_bits |= (1 << i)
        }
    }

    vk_limits := adapter_impl.vk_properties.limits

    non_coherent_atom_size := vk_limits.nonCoherentAtomSize
    impl.non_coherent_atom_size_mask = vk.DeviceSize(non_coherent_atom_size) - 1

    available_extensions := adapter_impl.vk_properties.extensions

    needs_bindless := has_any_features(descriptor.required_features, INDEXING_FEATURES)

    // Enabled extensions
    extensions_to_enable := make([dynamic]cstring, 0, 16, ta)

    // Require VK_KHR_swapchain
    append(&extensions_to_enable, vk.KHR_SWAPCHAIN_EXTENSION_NAME)

    if api_version < vk.API_VERSION_1_1 {
        // Require VK_KHR_maintenance1
        append(&extensions_to_enable, vk.KHR_MAINTENANCE_1_EXTENSION_NAME)

        // Optional VK_KHR_maintenance2
        if vk_has_extension(available_extensions, vk.KHR_MAINTENANCE_2_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_MAINTENANCE_2_EXTENSION_NAME)
        }

        // Optional VK_KHR_maintenance3
        if vk_has_extension(available_extensions, vk.KHR_MAINTENANCE_3_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_MAINTENANCE_3_EXTENSION_NAME)
        }

        // Require VK_KHR_storage_buffer_storage_class
        append(&extensions_to_enable, vk.KHR_STORAGE_BUFFER_STORAGE_CLASS_EXTENSION_NAME)

        // Required VK_KHR_multiview (if requested)
        if has_features(descriptor.required_features, {.Multiview}) {
            append(&extensions_to_enable, vk.KHR_MULTIVIEW_EXTENSION_NAME)
        }

        // Required VK_KHR_sampler_ycbcr_conversion (if requested)
        if has_features(descriptor.required_features, {.Texture_Format_Nv12}) {
            append(&extensions_to_enable, vk.KHR_SAMPLER_YCBCR_CONVERSION_EXTENSION_NAME)
        }

        // Required VK_KHR_16bit_storage (if `Shader_F16` or `Shader_I16` was requested)
        if has_any_features(descriptor.required_features, {.Shader_F16, .Shader_I16}) {
            // Shader_F16 needs VK_KHR_shader_float16_int8 (already required if available).
            // VK_KHR_16bit_storage needs VK_KHR_storage_buffer_storage_class (also already
            // required if available).
            append(&extensions_to_enable, vk.KHR_16BIT_STORAGE_EXTENSION_NAME)
        }

        // Required VK_KHR_shader_draw_parameters (if requested)
        if has_features(descriptor.required_features, {.Shader_Draw_Index}) {
            append(&extensions_to_enable, vk.KHR_SHADER_DRAW_PARAMETERS_EXTENSION_NAME)
        }
    }

    if api_version < vk.API_VERSION_1_2 {
        // Optional VK_KHR_image_format_list
        if vk_has_extension(available_extensions, vk.KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME)
        }

        // Optional VK_KHR_driver_properties
        if vk_has_extension(available_extensions, vk.KHR_DRIVER_PROPERTIES_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_DRIVER_PROPERTIES_EXTENSION_NAME)
        }

        // Optional VK_KHR_timeline_semaphore
        if vk_has_extension(available_extensions, vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME)
        }

        // Require VK_EXT_descriptor_indexing if one of the associated features was requested
        if needs_bindless {
            append(&extensions_to_enable, vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME)
        }

        // Always require `VK_KHR_shader_float16_int8` if available as it enables
        // Int8 optimizations. Also require it even if it's not available but
        // requested so that we get a corresponding error message.
        if has_features(descriptor.required_features, {.Shader_F16}) ||
           vk_has_extension(available_extensions, vk.KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME)
        }
    }

    if api_version < vk.API_VERSION_1_3 {
        // Optional VK_KHR_maintenance4
        if vk_has_extension(available_extensions, vk.KHR_MAINTENANCE_4_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_MAINTENANCE_4_EXTENSION_NAME)
        }

        // Optional VK_EXT_image_robustness
        if vk_has_extension(available_extensions, vk.EXT_IMAGE_ROBUSTNESS_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.EXT_IMAGE_ROBUSTNESS_EXTENSION_NAME)
        }

        // Require VK_EXT_subgroup_size_control if the associated feature was requested
        if has_features(descriptor.required_features, {.Subgroup}) ||
           has_features(descriptor.required_features, {.Subgroup_Size_Control}) {
            append(&extensions_to_enable, vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME)
        }

        // Optional VK_KHR_shader_integer_dot_product
        if vk_has_extension(
            available_extensions,
            vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME,
        ) {
            append(&extensions_to_enable, vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME)
        }

        // Optional VK_KHR_dynamic_rendering
        if api_version >= vk.API_VERSION_1_2 &&
           vk_has_extension(available_extensions, vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME)
        }

        // Optional VK_KHR_load_store_op_none
        if vk_has_extension(available_extensions, vk.KHR_LOAD_STORE_OP_NONE_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_LOAD_STORE_OP_NONE_EXTENSION_NAME)
        }

        // Optional VK_QCOM_render_pass_store_ops
        if vk_has_extension(available_extensions, vk.QCOM_RENDER_PASS_STORE_OPS_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.QCOM_RENDER_PASS_STORE_OPS_EXTENSION_NAME)
        }

        // Optional VK_EXT_load_store_op_none
        if vk_has_extension(available_extensions, vk.EXT_LOAD_STORE_OP_NONE_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.EXT_LOAD_STORE_OP_NONE_EXTENSION_NAME)
        }
    }

    // Optional VK_KHR_swapchain_mutable_format
    if vk_has_extension(available_extensions, vk.KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME)
    }

    // Optional VK_EXT_robustness2
    if vk_has_extension(available_extensions, vk.EXT_ROBUSTNESS_2_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_ROBUSTNESS_2_EXTENSION_NAME)
    }

    // Optional VK_KHR_external_memory_win32
    if vk_has_extension(available_extensions, vk.KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME)
    }

    // Optional VK_KHR_external_memory_fd
    if vk_has_extension(available_extensions, vk.KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME)
    }

    // Optional VK_EXT_external_memory_dma_buf
    if vk_has_extension(available_extensions, vk.EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME)
    }

    // Optional VK_EXT_image_drm_format_modifier
    if vk_has_extension(available_extensions, vk.EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME)
    }

    // Optional VK_EXT_memory_budget
    if vk_has_extension(available_extensions, vk.EXT_MEMORY_BUDGET_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_MEMORY_BUDGET_EXTENSION_NAME)
    }

    // Require VK_KHR_draw_indirect_count (if requested)
    if has_features(descriptor.required_features, {.Multi_Draw_Indirect_Count}) {
        append(&extensions_to_enable, vk.KHR_DRAW_INDIRECT_COUNT_EXTENSION_NAME)
    }

    // Require acceleration structures, buffer device addresses and ray queries
    // as a set when either ray-tracing feature is requested.
    if has_features(descriptor.required_features, {.Ray_Query}) ||
       has_features(descriptor.required_features, {.Ray_Tracing_Pipelines}) ||
       has_features(descriptor.required_features, {.Ray_Hit_Vertex_Return}) ||
       has_features(
           descriptor.required_features,
           {.Extended_Acceleration_Structure_Vertex_Formats},
       ) {
        if vk_has_extension(available_extensions, vk.KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME)
        }
        append(&extensions_to_enable, vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME)
        append(&extensions_to_enable, vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME)
        if has_features(descriptor.required_features, {.Ray_Query}) {
            append(&extensions_to_enable, vk.KHR_RAY_QUERY_EXTENSION_NAME)
        }
        if has_features(descriptor.required_features, {.Ray_Tracing_Pipelines}) {
            append(&extensions_to_enable, vk.KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME)
        }
        if has_features(descriptor.required_features, {.Ray_Hit_Vertex_Return}) {
            append(&extensions_to_enable, vk.KHR_RAY_TRACING_POSITION_FETCH_EXTENSION_NAME)
        }
    }

    // VK_EXT_mesh_shader requires SPIR-V 1.4 on Vulkan 1.1.
    if has_features(descriptor.required_features, {.Mesh_Shader}) ||
       has_features(descriptor.required_features, {.Mesh_Shader_Multiview}) {
        if api_version < vk.API_VERSION_1_2 {
            append(&extensions_to_enable, vk.KHR_SPIRV_1_4_EXTENSION_NAME)
        }
        append(&extensions_to_enable, vk.EXT_MESH_SHADER_EXTENSION_NAME)
    }

    if has_features(descriptor.required_features, {.Vulkan_Google_Display_Timing}) {
        append(&extensions_to_enable, vk.GOOGLE_DISPLAY_TIMING_EXTENSION_NAME)
    }

    // VK_KHR_portability_subset is required on Apple when the device exposes it.
    if vk_has_extension(available_extensions, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME)
    }

    // VK_EXT_texture_compression_astc_hdr.
    if has_features(descriptor.required_features, {.Texture_Compression_Astc_Hdr}) &&
       vk_has_extension(available_extensions, vk.EXT_TEXTURE_COMPRESSION_ASTC_HDR_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_TEXTURE_COMPRESSION_ASTC_HDR_EXTENSION_NAME)
    }

    // VK_KHR_shader_atomic_int64.
    if (has_features(descriptor.required_features, {.Shader_Int64_Atomic_Min_Max}) ||
           has_features(descriptor.required_features, {.Shader_Int64_Atomic_All_Ops})) &&
       vk_has_extension(available_extensions, vk.KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME)
    }

    // VK_EXT_shader_image_atomic_int64.
    if has_features(descriptor.required_features, {.Texture_Int64_Atomic}) &&
       vk_has_extension(available_extensions, vk.EXT_SHADER_IMAGE_ATOMIC_INT64_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_SHADER_IMAGE_ATOMIC_INT64_EXTENSION_NAME)
    }

    // VK_EXT_shader_atomic_float.
    if has_features(descriptor.required_features, {.Shader_Float32_Atomic}) &&
       vk_has_extension(available_extensions, vk.EXT_SHADER_ATOMIC_FLOAT_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.EXT_SHADER_ATOMIC_FLOAT_EXTENSION_NAME)
    }

    // VK_KHR_fragment_shader_barycentric. Vulkan bundles barycentrics and
    // per-vertex attributes under the same feature.
    if (has_features(descriptor.required_features, {.Shader_Barycentrics}) ||
           has_features(descriptor.required_features, {.Shader_Per_Vertex})) &&
       vk_has_extension(available_extensions, vk.KHR_FRAGMENT_SHADER_BARYCENTRIC_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_FRAGMENT_SHADER_BARYCENTRIC_EXTENSION_NAME)
    }

    // VK_KHR_cooperative_matrix.
    if has_features(descriptor.required_features, {.Cooperative_Matrix}) &&
       vk_has_extension(available_extensions, vk.KHR_COOPERATIVE_MATRIX_EXTENSION_NAME) {
        append(&extensions_to_enable, vk.KHR_COOPERATIVE_MATRIX_EXTENSION_NAME)
    }

    features_to_enable := VK_Physical_Device_Features {
        core = {
            robustBufferAccess        = b32(adapter_impl.caps.robust_buffer_access),
            imageCubeArray            = .Cube_Array_Textures in adapter_impl.dl_features,
            independentBlend          = .Independent_Blend in adapter_impl.dl_features,
            sampleRateShading         = .Multisampled_Shading in adapter_impl.dl_features,
            multiDrawIndirect         = adapter_impl.vk_features.multiDrawIndirect,
            drawIndirectFirstInstance = b32(
                has_features(descriptor.required_features, {.Indirect_First_Instance}),
            ),
            samplerAnisotropy         = .Anisotropic_Filtering in adapter_impl.dl_features,
            fragmentStoresAndAtomics  = .Fragment_Writable_Storage in adapter_impl.dl_features,
        },
    }

    // Required features
    pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

    // Populate every feature struct the adapter supports and the application
    // asked for.
    vk_fill_device_features(
        &features_to_enable,
        descriptor.required_features,
        &adapter_impl.vk_features,
        loc,
    )

    features2 := vk.PhysicalDeviceFeatures2 {
        sType    = .PHYSICAL_DEVICE_FEATURES_2,
        features = features_to_enable.core,
    }
    append(&pnext_chain, cast(^vk.BaseOutStructure)&features2)

    if needs_bindless {
        needs_partially_bound := has_features(
            descriptor.required_features,
            {.Partially_Bound_Binding_Array},
        )
        features_to_enable.descriptor_indexing = vk.PhysicalDeviceDescriptorIndexingFeaturesEXT {
            sType                                         = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
            shaderSampledImageArrayNonUniformIndexing     = true,
            shaderStorageImageArrayNonUniformIndexing     = true,
            shaderStorageBufferArrayNonUniformIndexing    = true,
            descriptorBindingSampledImageUpdateAfterBind  = true,
            descriptorBindingStorageImageUpdateAfterBind  = true,
            descriptorBindingStorageBufferUpdateAfterBind = true,
            descriptorBindingPartiallyBound               = b32(needs_partially_bound),
        }
        append(&pnext_chain, cast(^vk.BaseOutStructure)&features_to_enable.descriptor_indexing)
    }

    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(available_extensions, vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME) {
        features_to_enable.timeline_semaphore = vk.PhysicalDeviceTimelineSemaphoreFeaturesKHR {
            sType             = .PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES,
            timelineSemaphore = b32(adapter_impl.caps.timeline_semaphores),
        }
        append(&pnext_chain, cast(^vk.BaseOutStructure)&features_to_enable.timeline_semaphore)
    }

    // VK_KHR_shader_draw_parameters (core in Vulkan 1.1). Required by any
    // shader that reads `InstanceIndex`/`VertexIndex` draw parameters, which
    // makes the SPIR-V declare the `DrawParameters` capability.
    if has_features(descriptor.required_features, {.Shader_Draw_Index}) {
        features_to_enable.shader_draw_parameters = vk.PhysicalDeviceShaderDrawParametersFeatures {
            sType                = .PHYSICAL_DEVICE_SHADER_DRAW_PARAMETERS_FEATURES,
            shaderDrawParameters = true,
        }
    }

    if feature, feature_ok := &features_to_enable.image_robustness.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.robustness2.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.multiview.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.astc_hdr.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_float16_int8.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable._16bit_storage.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.zero_initialize_workgroup_memory.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.acceleration_structure.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.buffer_device_address.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.ray_query.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.ray_tracing_pipeline.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_atomic_int64.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.position_fetch.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_image_atomic_int64.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_atomic_float.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.subgroup_size_control.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.maintenance4.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.mesh_shader.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_integer_dot_product.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_barycentrics.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.portability_subset.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.cooperative_matrix.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.vulkan_memory_model.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }
    if feature, feature_ok := &features_to_enable.shader_draw_parameters.?; feature_ok {
        append(&pnext_chain, cast(^vk.BaseOutStructure)feature)
    }

    default_family_index := adapter_impl.graphics_family
    if adapter_impl.has_present_family {
        default_family_index = adapter_impl.present_family
    }
    if default_family_index == vk.QUEUE_FAMILY_IGNORED {
        log.error("VULKAN: adapter has no usable queue family")
        return
    }
    default_queue_priority: f32 = 1.0

    queue_create_info: vk.DeviceQueueCreateInfo = {
        sType            = .DEVICE_QUEUE_CREATE_INFO,
        queueFamilyIndex = default_family_index,
        queueCount       = 1,
        pQueuePriorities = &default_queue_priority,
    }

    device_create_info := vk.DeviceCreateInfo {
        sType                   = .DEVICE_CREATE_INFO,
        queueCreateInfoCount    = 1,
        pQueueCreateInfos       = &queue_create_info,
        enabledExtensionCount   = u32(len(extensions_to_enable)),
        ppEnabledExtensionNames = raw_data(extensions_to_enable),
    }

    impl.queue_flags = adapter_impl.vk_queue_families[default_family_index].queueFlags

    vk_setup_pnext_chain(&device_create_info, pnext_chain[:])

    res := vk.CreateDevice(
        adapter_impl.vk_physical_device,
        &device_create_info,
        nil,
        &impl.vk_device,
    )
    if res != .SUCCESS {
        // No device handle exists yet, so this reports through the log rather
        // than through a device's error scopes.
        vk_try(nil, res, "vkCreateDevice", loc)
        return
    }

    // Bind Vulkan functions
    vk.load_proc_addresses_device_vtable(impl.vk_device, &impl.fp)
    impl.fp.vk_device = impl.vk_device

    // A shared device cache lets pipelines reuse compiled code. Failure is
    // non-fatal: VK_NULL_HANDLE is a valid pipeline-cache argument.
    cache_info := vk.PipelineCacheCreateInfo {
        sType = .PIPELINE_CACHE_CREATE_INFO,
    }
    if impl.fp.CreatePipelineCache(impl.vk_device, &cache_info, nil, &impl.pipeline_cache) !=
       .SUCCESS {
        log.debug("VULKAN: vkCreatePipelineCache failed; pipelines are created uncached")
        impl.pipeline_cache = {}
    }

    device_impl := new_clone(impl, adapter_impl.allocator)
    init_ref(device_impl)
    device_out := Device(device_impl)

    // For use with empty pipeline layouts
    vk_create_empty_pipeline_layout :: proc(fp: VK_Device_VTable) -> vk.PipelineLayout {
        layout_create_info := vk.PipelineLayoutCreateInfo {
            sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
            setLayoutCount         = 0,
            pSetLayouts            = nil,
            pushConstantRangeCount = 0,
            pPushConstantRanges    = nil,
        }
        layout: vk.PipelineLayout
        vk_check(fp.CreatePipelineLayout(fp.vk_device, &layout_create_info, nil, &layout))
        return layout
    }

    device_impl.vk_empty_pipeline_layout = vk_create_empty_pipeline_layout(device_impl.fp)

    // Create empty layouts
    vk_create_empty_descriptor_set_layout :: proc(fp: VK_Device_VTable) -> vk.DescriptorSetLayout {
        vk_info := vk.DescriptorSetLayoutCreateInfo {
            sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            bindingCount = 0,
            pBindings    = nil,
        }
        layout: vk.DescriptorSetLayout
        vk_check(fp.CreateDescriptorSetLayout(fp.vk_device, &vk_info, nil, &layout))
        return layout
    }

    device_impl.vk_empty_descriptor_set_layout = vk_create_empty_descriptor_set_layout(
        device_impl.fp,
    )

    when USE_VMA {
        log.debug("VULKAN: using Vulkan Memory Allocator (VMA)")

        instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)

        // Initializes a subset of Vulkan functions required by VMA
        vma_vulkan_functions := vma.create_device_vulkan_functions(device_impl.fp)

        vma_create_info: vma.AllocatorCreateInfo = {
            // flags            = { .BUFFER_DEVICE_ADDRESS },
            instance         = instance_impl.vk_instance,
            physicalDevice   = adapter_impl.vk_physical_device,
            device           = device_impl.vk_device,
            pVulkanFunctions = &vma_vulkan_functions,
            vulkanApiVersion = min(
                instance_impl.instance_version,
                adapter_impl.vk_properties.apiVersion,
            ),
        }

        // Create the VMA (Vulkan Memory Allocator)
        vk_check(vma.CreateAllocator(vma_create_info, &device_impl.vma_allocator))
    } else {
        log.debug("VULKAN: using internal GPU Allocator")

        // Initializes a subset of Vulkan functions required by the GPu allocator
        gpu_vulkan_functions := gpua.create_device_vulkan_functions(device_impl.fp)

        allocator_desc := gpua.VK_Allocator_Create_Desc {
            physical_device  = adapter_impl.vk_physical_device,
            device           = device_impl.vk_device,
            allocation_sizes = gpua.DEFAULT_ALLOCATION_SIZES,
            vulkan_functions = gpu_vulkan_functions,
        }

        when ODIN_DEBUG {
            allocator_desc.debug_settings = {
                log_memory_information = true,
                log_leaks_on_shutdown  = true,
                log_frees              = false,
            }
        }

        gpua.vk_allocator_init(
            &device_impl.gpu_allocator,
            allocator_desc,
            device_impl.allocator,
            loc,
        )
    }

    // Set default graphics queue
    vk_queue_init(&device_impl.queue, default_family_index, device_out)

    // Initialize sub-systems
    vk_submit_context_init(
        &device_impl.submitter,
        device_out,
        default_family_index,
        device_impl.allocator,
    )

    max_update_after_bind: u32
    if prop, prop_ok := adapter_impl.vk_properties.descriptor_indexing.?; prop_ok {
        max_update_after_bind = prop.maxUpdateAfterBindDescriptorsInAllPools
    }
    vk_descriptor_allocator_init(
        &device_impl.descriptor,
        device_out,
        max_update_after_bind,
        device_impl.allocator,
    )

    vk_deferred_init(
        &device_impl.deferred,
        device_out,
        device_impl.vma_allocator,
        &device_impl.gpu_allocator,
        device_impl.allocator,
    )

    // Set default allocator
    device_impl.framebuffer_cache.allocator = device_impl.allocator
    device_impl.render_pass_cache.allocator = device_impl.allocator

    // Initialize the sampler cache
    vk_sampler_cache_init(
        &device_impl.sampler_cache,
        device_out,
        adapter_impl.vk_properties.limits.maxSamplerAllocationCount,
        device_impl.allocator,
    )

    vk_label_store_init(&device_impl.labels, device_impl.allocator)

    // Initialize resources
    dhm_init(&device_impl.bind_groups, device_impl.allocator)
    dhm_init(&device_impl.bind_group_layouts, device_impl.allocator)
    dhm_init(&device_impl.buffers, device_impl.allocator)
    dhm_init(&device_impl.command_buffers, device_impl.allocator)
    dhm_init(&device_impl.command_encoders, device_impl.allocator)
    dhm_init(&device_impl.computer_passes, device_impl.allocator)
    dhm_init(&device_impl.compute_pipelines, device_impl.allocator)
    dhm_init(&device_impl.pipeline_layouts, device_impl.allocator)
    dhm_init(&device_impl.queues, device_impl.allocator)
    dhm_init(&device_impl.render_passes, device_impl.allocator)
    dhm_init(&device_impl.render_pipelines, device_impl.allocator)
    dhm_init(&device_impl.samplers, device_impl.allocator)
    dhm_init(&device_impl.render_bundles, device_impl.allocator)
    dhm_init(&device_impl.render_bundle_encoders, device_impl.allocator)
    dhm_init(&device_impl.query_sets, device_impl.allocator)
    dhm_init(&device_impl.shader_modules, device_impl.allocator)
    dhm_init(&device_impl.texture_views, device_impl.allocator)
    dhm_init(&device_impl.textures, device_impl.allocator)

    device_impl.destroyed_query_sets = make(map[Query_Set]bool, device_impl.allocator)

    device_tracker_init(
        &device_impl.trackers,
        device_impl.allocator,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
    )

    tracker_index_allocators_init(&device_impl.tracker_indices, device_impl.allocator)

    vk_adapter_add_ref(adapter, loc)

    return device_out, true
}

vk_device_get_internal_impl :: #force_inline proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^_Device_Impl {
    return vk_device_get_impl(device, loc)
}

vk_device_get_impl :: #force_inline proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^VK_Device_Impl {
    assert_contextless(device != nil, "invalid device", loc)
    return cast(^VK_Device_Impl)device
}

vk_device_get_limits :: proc(device: Device, loc := #caller_location) -> Limits {
    impl := vk_device_get_impl(device, loc)
    return impl.limits
}

vk_device_has_feature :: proc(
    device: Device,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    impl := vk_device_get_impl(device, loc)
    _, found := slice.binary_search(impl.features[:], feature)
    return found
}

vk_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
    impl := vk_device_get_impl(device, loc)
    return impl.adapter
}

vk_device_get_instance :: proc(device: Device, loc := #caller_location) -> Instance {
    impl := vk_device_get_impl(device, loc)
    return impl.instance
}

vk_device_get_features :: proc(device: Device, loc := #caller_location) -> Features {
    impl := vk_device_get_impl(device, loc)
    return impl.features
}

vk_device_create_bind_group :: vk_create_bind_group

vk_device_create_bind_group_layout :: vk_create_bind_group_layout

vk_device_create_buffer :: vk_create_buffer

vk_device_create_command_encoder :: vk_create_command_encoder

vk_device_create_compute_pipeline :: vk_create_compute_pipeline

vk_device_create_compute_pipeline_async :: vk_create_compute_pipeline_async

vk_device_create_pipeline_layout :: vk_create_pipeline_layout

@(require_results)
vk_device_create_query_set :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set {
    return vk_create_query_set(device, descriptor, loc)
}

@(require_results)
vk_device_create_render_bundle_encoder :: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder {
    return vk_create_render_bundle_encoder(device, descriptor, loc)
}

vk_device_create_render_pipeline :: vk_create_render_pipeline

vk_device_create_render_pipeline_async :: vk_create_render_pipeline_async

vk_device_create_sampler :: vk_create_sampler

vk_device_create_shader_module_spirv :: vk_create_shader_module_spirv

vk_device_create_shader_module :: vk_create_shader_module

vk_device_create_texture :: vk_create_texture

vk_device_destroy :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    if impl.destroyed {
        return
    }
    impl.destroyed = true
    vk_device_note_lost(device, .Destroyed, "", loc)
}

vk_device_get_adapter_info :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
    status: Status,
) {
    impl := vk_device_get_impl(device, loc)
    return adapter_get_info(impl.adapter, context.allocator, loc), .Success
}

vk_device_lost_resolve :: proc(userdata: Future_Data) {
    #partial switch data in userdata {
    case Future_Data_For_Lost_Device:
        if data.callback_info.callback != nil {
            device := data.device
            data.callback_info.callback(
                &device,
                data.reason,
                data.message,
                data.callback_info.userdata1,
                data.callback_info.userdata2,
            )
        }
    case:
        unreachable()
    }
}

vk_device_lost_wait :: proc(userdata: Future_Data, timeout_ns: u64) -> bool {
    #partial switch data in userdata {
    case Future_Data_For_Lost_Device:
        impl := vk_device_get_impl(data.device)
        adapter_impl := vk_adapter_get_impl(impl.adapter)
        instance_impl := vk_instance_get_impl(adapter_impl.instance)

        sync.guard(&instance_impl.future_mtx)
        if impl.lost {
            return true
        }
        if timeout_ns == 0 {
            return false
        }
        start := time.tick_now()

        for !impl.lost {
            if timeout_ns == max(u64) {
                sync.cond_wait(&instance_impl.future_cond, &instance_impl.future_mtx)
                continue
            }
            elapsed := u64(time.tick_since(start))
            if elapsed >= timeout_ns {
                return false
            }
            remaining := timeout_ns - elapsed
            if !sync.cond_wait_with_timeout(
                &instance_impl.future_cond,
                &instance_impl.future_mtx,
                time.Duration(remaining),
            ) {
                return impl.lost
            }
        }
        return true
    }
    return true
}

vk_device_note_lost :: proc(
    device: Device,
    reason: Device_Lost_Reason,
    message: string,
    loc := #caller_location,
) {
    impl := vk_device_get_impl(device, loc)

    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)
    instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)

    pending: Future_Impl
    have_pending := false
    {
        sync.guard(&instance_impl.future_mtx)
        if impl.lost {
            return
        }
        impl.lost = true

        if impl.lost_future_id != 0 {
            if p, ok := instance_impl.pending_futures[impl.lost_future_id]; ok {
                p.ready = true
                pending = p
                have_pending = true
                delete_key(&instance_impl.pending_futures, impl.lost_future_id)
            }
            impl.lost_future_id = 0
        }
    }
    // Callbacks may call back into the API; never run them under future_mtx.
    if have_pending {
        if pending.resolve != nil {
            pending.resolve(pending.userdata)
        }
        sync.cond_broadcast(&instance_impl.future_cond)
    }
}

vk_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
    impl := vk_device_get_impl(device, loc)

    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)
    instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)

    lost_callback_info: Device_Lost_Callback_Info
    {
        sync.shared_guard(&impl.state_mtx)
        lost_callback_info = impl.lost_callback_info
    }

    sync.guard(&instance_impl.future_mtx)
    if impl.lost {
        return {}
    }
    if impl.lost_future_id != 0 {
        return {id = impl.lost_future_id}
    }

    id := intrinsics.atomic_add(&instance_impl.current_future_id, 1)
    instance_impl.pending_futures[id] = {
        resolve = vk_device_lost_resolve,
        wait = vk_device_lost_wait,
        userdata = Future_Data_For_Lost_Device {
            device        = device,
            reason        = .Unknown,
            message       = "",
            callback_info = lost_callback_info,
        },
        poll = true,
        ready = false,
    }
    impl.lost_future_id = id
    return {id = id}
}

@(require_results)
vk_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    impl := vk_device_get_impl(device, loc)
    _, queue_handle := add_impl(&impl.queues, VK_Queue_Impl {
        device = device,
    })
    queue := new_handle(Queue, device, queue_handle)
    if impl.default_queue_label != "" {
        vk_queue_set_label(queue, impl.default_queue_label, loc)
    }
    return queue
}

@(require_results)
vk_error_filter_for_type :: proc(error_type: Error_Type) -> (Error_Filter, bool) {
    switch error_type {
    case .Validation:
        return .Validation, true
    case .Out_Of_Memory:
        return .Out_Of_Memory, true
    case .Internal:
        return .Internal, true
    case .No_Error, .Unknown:
    }
    return {}, false
}

@(require_results)
vk_device_capture_error_scope :: proc(
    device: Device,
    error_type: Error_Type,
    message: string,
    loc := #caller_location,
) -> bool {
    filter, has_filter := vk_error_filter_for_type(error_type)
    if !has_filter {
        return false
    }
    impl := vk_device_get_impl(device, loc)
    sync.guard(&impl.error_scopes_mtx)
    for index := len(impl.error_scopes) - 1; index >= 0; index -= 1 {
        scope := &impl.error_scopes[index]
        if scope.filter != filter {
            continue
        }
        if scope.error == .No_Error {
            scope.error = error_type
            scope.message = strings.clone(message, impl.allocator)
        }
        return true
    }
    return false
}

@(require_results)
vk_device_pop_error_scope :: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future {
    impl := vk_device_get_impl(device, loc)

    status := Pop_Error_Scope_Status.Success
    error_type: Error_Type
    message: string
    {
        sync.guard(&impl.error_scopes_mtx)
        if len(impl.error_scopes) == 0 {
            status = .Error
        } else {
            scope := impl.error_scopes[len(impl.error_scopes) - 1]
            pop(&impl.error_scopes)
            error_type = scope.error
            message = scope.message
        }
    }

    if callback_info.callback != nil {
        callback_info.callback(
            status,
            error_type,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }
    if message != "" {
        delete(message, impl.allocator)
    }

    // The Vulkan backend reports errors synchronously through `vk_check`, so
    // every scope resolves as soon as it is popped.
    return {}
}

vk_device_push_error_scope :: proc(device: Device, filter: Error_Filter, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    sync.guard(&impl.error_scopes_mtx)
    append(&impl.error_scopes, VK_Error_Scope{filter = filter})
}

vk_device_start_graphics_debugger_capture :: proc(
    device: Device,
    loc := #caller_location,
) -> bool {
    return false
}

vk_device_stop_graphics_debugger_capture :: proc(device: Device, loc := #caller_location) {}

vk_device_backend :: proc(device: Device, loc := #caller_location) -> Backend_Type {
    return .Vulkan
}

@(require_results)
vk_device_is_embedded :: proc(device: Device, loc := #caller_location) -> bool {
    return false
}

vk_device_set_lost_callback :: proc(
    device: Device,
    callback_info: Device_Lost_Callback_Info,
    loc := #caller_location,
) {
    impl := vk_device_get_impl(device, loc)
    sync.guard(&impl.state_mtx)
    impl.lost_callback_info = callback_info
}

vk_device_set_uncaptured_error_callback :: proc(
    device: Device,
    callback_info: Uncaptured_Error_Callback_Info,
    loc := #caller_location,
) {
    impl := vk_device_get_impl(device, loc)
    sync.guard(&impl.state_mtx)
    impl.uncaptured_error_callback = callback_info
}

vk_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    impl := vk_device_get_impl(device, loc)
    sync.shared_guard(&impl.state_mtx)
    return impl.label
}

vk_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    {
        sync.guard(&impl.state_mtx)
        if impl.label != "" {
            delete(impl.label, impl.allocator)
        }
        impl.label = ""
        if label != "" {
            impl.label = strings.clone(label, impl.allocator)
        }
    }
    vk_utils_set_debug_object_name(impl.fp, .DEVICE, uintptr(impl.vk_device), label, loc)
}

vk_device_add_ref :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    add_ref(impl, loc)
}

vk_device_clear_render_passes :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // Detach entries under their cache locks, then enqueue destruction after
    // unlocking so cache -> deferred-deletion is never a nested lock order.
    framebuffers := make([dynamic]vk.Framebuffer, 0, 2, ta)
    render_passes := make([dynamic]vk.RenderPass, 0, 2, ta)

    {
        sync.guard(&impl.framebuffer_cache_mtx)
        for _, fb in impl.framebuffer_cache {
            append(&framebuffers, fb.vk_framebuffer)
        }
        clear(&impl.framebuffer_cache)
    }
    {
        sync.guard(&impl.render_pass_cache_mtx)
        for _, rp in impl.render_pass_cache {
            append(&render_passes, rp)
        }
        clear(&impl.render_pass_cache)
        impl.render_pass_cache_order_len = 0
    }

    for fb in framebuffers {
        vk_deferred_add_resource(&impl.deferred, &impl.submitter, fb)
    }
    for rp in render_passes {
        vk_deferred_add_resource(&impl.deferred, &impl.submitter, rp)
    }
}

vk_device_release :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    if release_ref(impl, loc) {
        vk_submit_context_device_wait_idle(&impl.submitter, loc)

        context.allocator = impl.allocator

        vk_queue_abandon_pending_writes(&impl.queue, loc)

        // Command-buffer trackers own strong references to resources used by
        // submitted work. Purge them while the framebuffer cache is still alive:
        // releasing a tracked bind group may release a texture view, which
        // invalidates matching framebuffer-cache entries.
        vk_submit_context_wait_all(&impl.submitter, loc)

        vk_device_clear_render_passes(device, loc)
        {
            sync.guard(&impl.framebuffer_cache_mtx)
            delete(impl.framebuffer_cache)
        }
        {
            sync.guard(&impl.render_pass_cache_mtx)
            delete(impl.render_pass_cache)
        }

        vk_staging_uninit(impl, loc)

        vk_deferred_wait_and_process_all(&impl.deferred, &impl.submitter)

        vk_sampler_cache_destroy(&impl.sampler_cache)
        vk_label_store_destroy(&impl.labels)

        if impl.label != "" {
            delete(impl.label, impl.allocator)
        }
        if impl.default_queue_label != "" {
            delete(impl.default_queue_label, impl.allocator)
        }
        for scope in impl.error_scopes {
            if scope.message != "" {
                delete(scope.message, impl.allocator)
            }
        }
        delete(impl.error_scopes)

        vk_deferred_uninit(&impl.deferred)
        vk_submit_context_uninit(&impl.submitter)
        vk_descriptor_allocator_destroy_all(&impl.descriptor, loc)
        vk_descriptor_allocator_uninit(&impl.descriptor)

        vk_queue_uninit(&impl.queue)

        when USE_VMA {
            vma.DestroyAllocator(impl.vma_allocator)
        } else {
            gpua.vk_allocator_uninit(&impl.gpu_allocator)
        }

        impl.fp.DestroyPipelineLayout(impl.vk_device, impl.vk_empty_pipeline_layout, nil)
        impl.fp.DestroyDescriptorSetLayout(
            impl.vk_device,
            impl.vk_empty_descriptor_set_layout,
            nil,
        )
        if impl.pipeline_cache != {} {
            impl.fp.DestroyPipelineCache(impl.vk_device, impl.pipeline_cache, nil)
        }

        vk.DestroyDevice(impl.vk_device, nil)
        vk_adapter_release(impl.adapter, loc)

        // Delete resources
        // leaked_texture_views := hm.len(gpu.vk.texture_views.resources)
        // if leaked_texture_views > 0 {
        //     log.warnf("Leaked [%d] texture view(s)", leaked_texture_views)
        // }

        dhm_destroy(&impl.bind_groups)
        dhm_destroy(&impl.bind_group_layouts)
        dhm_destroy(&impl.buffers)
        dhm_destroy(&impl.command_buffers)
        dhm_destroy(&impl.command_encoders)
        dhm_destroy(&impl.computer_passes)
        dhm_destroy(&impl.compute_pipelines)
        dhm_destroy(&impl.pipeline_layouts)
        dhm_destroy(&impl.queues)
        dhm_destroy(&impl.render_passes)
        dhm_destroy(&impl.render_pipelines)
        dhm_destroy(&impl.samplers)
        dhm_destroy(&impl.render_bundles)
        dhm_destroy(&impl.render_bundle_encoders)
        dhm_destroy(&impl.query_sets)
        dhm_destroy(&impl.shader_modules)
        dhm_destroy(&impl.texture_views)
        dhm_destroy(&impl.textures)

        delete(impl.destroyed_query_sets)

        device_tracker_free(&impl.trackers)
        tracker_index_allocators_uninit(&impl.tracker_indices)

        free(impl)
    }
}
