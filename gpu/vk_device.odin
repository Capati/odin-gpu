#+build !js
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:sync"

// Vendor
import "lib/vma"
import gpua "allocator"
import vk "vendor:vulkan"

VK_Device_VTable :: struct {
    vk_device: vk.Device,
    using fp:  vk.Device_VTable,
}

VK_BUFFER_ORDERED_USES_MASK  :: BUFFER_USES_INCLUSIVE | { .Map_Write }
VK_TEXTURE_ORDERED_USES_MASK :: TEXTURE_USES_INCLUSIVE

VK_DHM_Bind_Groups        :: DHM_Resource(VK_Bind_Group_Impl, VK_Bind_Group_Handle)
VK_DHM_Bind_Group_Layouts :: DHM_Resource(VK_Bind_Group_Layout_Impl, VK_Bind_Group_Layout_Handle)
VK_DHM_Buffers            :: DHM_Resource(VK_Buffer_Impl, VK_Buffer_Handle)
VK_DHM_Command_Buffers    :: DHM_Resource(VK_Command_Buffer_Wrapper, VK_Command_Buffer_Handle)
VK_DHM_Command_Encoders   :: DHM_Resource(VK_Command_Encoder_Impl, VK_Command_Encoder_Handle)
VK_DHM_Compute_Passes     :: DHM_Resource(VK_Compute_Pass_Impl, VK_Compute_Pass_Handle)
VK_DHM_Pipeline_Layouts   :: DHM_Resource(VK_Pipeline_Layout_Impl, VK_Pipeline_Layout_Handle)
VK_DHM_Queues             :: DHM_Resource(VK_Queue_Impl, VK_Queue_Handle)
VK_DHM_Render_Passes      :: DHM_Resource(VK_Render_Pass_Impl, VK_Render_Pass_Handle)
VK_DHM_Render_Pipelines   :: DHM_Resource(VK_Render_Pipeline_Impl, VK_Render_Pipeline_Handle)
VK_DHM_Samplers           :: DHM_Resource(VK_Sampler_Impl, VK_Sampler_Handle)
VK_DHM_Shader_Modules     :: DHM_Resource(VK_Shader_Module_Impl, VK_Shader_Module_Handle)
VK_DHM_Texture_Views      :: DHM_Resource(VK_Texture_View_Impl, VK_Texture_View_Handle)
VK_DHM_Textures           :: DHM_Resource(VK_Texture_Impl, VK_Texture_Handle)

VK_Device_Impl :: struct {
    // Base
    using base:                     Device_Impl,

    // Resources
    bind_groups:                    VK_DHM_Bind_Groups,
    bind_group_layouts:             VK_DHM_Bind_Group_Layouts,
    buffers:                        VK_DHM_Buffers,
    command_buffers:                VK_DHM_Command_Buffers,
    command_encoders:               VK_DHM_Command_Encoders,
    computer_passes:                VK_DHM_Compute_Passes,
    pipeline_layouts:               VK_DHM_Pipeline_Layouts,
    queues:                         VK_DHM_Queues,
    render_passes:                  VK_DHM_Render_Passes,
    render_pipelines:               VK_DHM_Render_Pipelines,
    samplers:                       VK_DHM_Samplers,
    shader_modules:                 VK_DHM_Shader_Modules,
    texture_views:                  VK_DHM_Texture_Views,
    textures:                       VK_DHM_Textures,

    // Initialization
    queue:                          VK_Queue_Default_Impl,
    vk_device:                      vk.Device,
    fp:                             VK_Device_VTable,
    submitter:                      VK_Submit_Context,
    descriptor:                     VK_Descriptor_Allocator,
    deferred:                       VK_Deferred_Deletor,
    vma_allocator:                  vma.Allocator,
    gpu_allocator:                  gpua.VK_Allocator,
    non_coherent_atom_size_mask:    vk.DeviceSize,
    // Global bit mask AND-ed with any memoryTypeBits to disallow certain memory types.
    valid_memory_type_bits:         u32,
    queue_flags:                    vk.QueueFlags,
    caps:                           VK_Private_Capabilities,

    // Default layouts
    vk_empty_pipeline_layout:       vk.PipelineLayout,
    vk_empty_descriptor_set_layout: vk.DescriptorSetLayout,

    // Resource caches
    render_pass_cache:              map[VK_Render_Pass_Key]vk.RenderPass,
    // Separate locks keep cache access independent. They are dropped before
    // Vulkan object destruction or deferred-deletion enqueueing.
    render_pass_cache_mtx:          sync.RW_Mutex,
    framebuffer_cache:              VK_Framebuffer_Cache_Map,
    framebuffer_cache_mtx:          sync.RW_Mutex,
    sampler_cache:                  VK_Sampler_Cache,
}

vk_create_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor,
    loc := #caller_location,
) -> (
    device: Device,
    ok: bool,
) {
    adapter_impl := vk_adapter_get_impl(adapter, loc)

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
    impl.caps = adapter_impl.caps
    impl.backend = .Vulkan
    impl.is_embedded = false

    for i in 0..< adapter_impl.vk_mem_properties.memoryTypeCount {
        mem_type := adapter_impl.vk_mem_properties.memoryTypes[i]
        if mem_type.propertyFlags <= adapter_impl.known_memory_flags { // subset check
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
        if has_features(descriptor.required_features, {.Subgroup}) {
            append(&extensions_to_enable, vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME)
        }

        // Optional VK_KHR_shader_integer_dot_product
        if vk_has_extension(available_extensions,
                vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME) {
            append(&extensions_to_enable, vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME)
        }

        // Optional VK_KHR_dynamic_rendering
        if api_version >= vk.API_VERSION_1_2  &&
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

    // // Require `VK_KHR_deferred_host_operations`,
    // // `VK_KHR_acceleration_structure` `VK_KHR_buffer_device_address` (for
    // // acceleration structures) if either `EXPERIMENTAL_RAY_QUERY` or
    // // `EXPERIMENTAL_RAY_TRACING_PIPELINES` were requested.
    // if requested_features.intersects(
    //     wgt::Features::EXPERIMENTAL_RAY_QUERY
    //         | wgt::Features::EXPERIMENTAL_RAY_TRACING_PIPELINES,
    // ) {
    //     append(&extensions_to_enable, khr::deferred_host_operations::NAME)
    //     append(&extensions_to_enable, khr::acceleration_structure::NAME)
    //     append(&extensions_to_enable, khr::buffer_device_address::NAME)
    // }

    // // Require `VK_KHR_ray_query` if `EXPERIMENTAL_RAY_QUERY` was requested
    // if requested_features.contains(wgt::Features::EXPERIMENTAL_RAY_QUERY) {
    //     append(&extensions_to_enable, khr::ray_query::NAME)
    // }

    // // Require `VK_KHR_ray_tracing_pipeline` if `EXPERIMENTAL_RAY_TRACING_PIPELINES` was requested
    // if requested_features.contains(wgt::Features::EXPERIMENTAL_RAY_TRACING_PIPELINES) {
    //     append(&extensions_to_enable, khr::ray_tracing_pipeline::NAME)
    // }

    // if requested_features.contains(wgt::Features::EXPERIMENTAL_RAY_HIT_VERTEX_RETURN) {
    //     append(&extensions_to_enable, khr::ray_tracing_position_fetch::NAME
    // }

    // // Require `VK_EXT_conservative_rasterization` if the associated feature was requested
    // if requested_features.contains(wgt::Features::CONSERVATIVE_RASTERIZATION) {
    //     append(&extensions_to_enable, ext::conservative_rasterization::NAME)
    // }

    // // Require `VK_KHR_portability_subset` on macOS/iOS
    // #[cfg(target_vendor = "apple")]
    // append(&extensions_to_enable, khr::portability_subset::NAME)

    // // Require `VK_EXT_texture_compression_astc_hdr` if the associated feature was requested
    // if requested_features.contains(wgt::Features::TEXTURE_COMPRESSION_ASTC_HDR) {
    //     append(&extensions_to_enable, ext::texture_compression_astc_hdr::NAME)
    // }

    // // Require `VK_KHR_shader_atomic_int64` if the associated feature was requested
    // if requested_features.intersects(
    //     wgt::Features::SHADER_INT64_ATOMIC_ALL_OPS | wgt::Features::SHADER_INT64_ATOMIC_MIN_MAX,
    // ) {
    //     append(&extensions_to_enable, khr::shader_atomic_int64::NAME)
    // }

    // // Require `VK_EXT_shader_image_atomic_int64` if the associated feature was requested
    // if requested_features.intersects(wgt::Features::TEXTURE_INT64_ATOMIC) {
    //     append(&extensions_to_enable, ext::shader_image_atomic_int64::NAME)
    // }

    // // Require `VK_EXT_shader_atomic_float` if the associated feature was requested
    // if requested_features.contains(wgt::Features::SHADER_FLOAT32_ATOMIC) {
    //     append(&extensions_to_enable, ext::shader_atomic_float::NAME)
    // }

    // // Require VK_GOOGLE_display_timing if the associated feature was requested
    // if requested_features.contains(wgt::Features::VULKAN_GOOGLE_DISPLAY_TIMING) {
    //     append(&extensions_to_enable, google::display_timing::NAME)
    // }

    // if requested_features.contains(wgt::Features::EXPERIMENTAL_MESH_SHADER) {
    //     append(&extensions_to_enable, ext::mesh_shader::NAME)
    // }

    // // Require `VK_KHR_fragment_shader_barycentric` if an associated feature was requested
    // // Vulkan bundles both barycentrics and per-vertex attributes under the same feature.
    // if requested_features
    //     .intersects(wgt::Features::SHADER_BARYCENTRICS | wgt::Features::SHADER_PER_VERTEX)
    // {
    //     append(&extensions_to_enable, khr::fragment_shader_barycentric::NAME)
    // }

    // // Require `VK_KHR_cooperative_matrix` if the associated feature was requested
    // if requested_features.contains(wgt::Features::EXPERIMENTAL_COOPERATIVE_MATRIX) {
    //     append(&extensions_to_enable, khr::cooperative_matrix::NAME)
    // }

    features_to_enable := VK_Physical_Device_Features {
        core = {
            robustBufferAccess = b32(adapter_impl.caps.robust_buffer_access),
            fullDrawIndexUint32 = false,
            imageCubeArray = .Cube_Array_Textures in adapter_impl.dl_features,
            independentBlend = .Independent_Blend in adapter_impl.dl_features,
            geometryShader = false,
            tessellationShader = false,
            sampleRateShading = .Multisampled_Shading in adapter_impl.dl_features,
            dualSrcBlend = false,
            logicOp = false,
            multiDrawIndirect = adapter_impl.vk_features.multiDrawIndirect,
            drawIndirectFirstInstance = b32(has_features(
                descriptor.required_features, {.Indirect_First_Instance})),
            depthClamp = false,
            depthBiasClamp = false,
            fillModeNonSolid = false,
            depthBounds = false,
            wideLines = false,
            largePoints = false,
            alphaToOne = false,
            multiViewport = false,
            samplerAnisotropy = .Anisotropic_Filtering in adapter_impl.dl_features,
            textureCompressionETC2 = false,
            textureCompressionASTC_LDR = false,
            textureCompressionBC = false,
            occlusionQueryPrecise = false,
            pipelineStatisticsQuery = false,
            vertexPipelineStoresAndAtomics = false,
            fragmentStoresAndAtomics = .Fragment_Writable_Storage in adapter_impl.dl_features,
            shaderTessellationAndGeometryPointSize = false,
            shaderImageGatherExtended = false,
            shaderStorageImageExtendedFormats = false,
            shaderStorageImageMultisample = false,
            shaderStorageImageReadWithoutFormat = false,
            shaderStorageImageWriteWithoutFormat = false,
            shaderUniformBufferArrayDynamicIndexing = false,
            shaderSampledImageArrayDynamicIndexing = false,
            shaderStorageBufferArrayDynamicIndexing = false,
            shaderStorageImageArrayDynamicIndexing = false,
            shaderClipDistance = false,
            shaderCullDistance = false,
            shaderFloat64 = false,
            shaderInt64 = false,
            shaderInt16 = false,
            shaderResourceResidency = false,
            shaderResourceMinLod = false,
            sparseBinding = false,
            sparseResidencyBuffer = false,
            sparseResidencyImage2D = false,
            sparseResidencyImage3D = false,
            sparseResidency2Samples = false,
            sparseResidency4Samples = false,
            sparseResidency8Samples = false,
            sparseResidency16Samples = false,
            sparseResidencyAliased = false,
            variableMultisampleRate = false,
            inheritedQueries = false,
        },
    }

    // Required features
    pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

    features2 := vk.PhysicalDeviceFeatures2 {
        sType    = .PHYSICAL_DEVICE_FEATURES_2,
        features = features_to_enable.core,
    }
    append(&pnext_chain, cast(^vk.BaseOutStructure)&features2)

    // TODO

    if needs_bindless {
        needs_partially_bound := has_features(
            descriptor.required_features, {.Partially_Bound_Binding_Array})
        features_to_enable.descriptor_indexing = vk.PhysicalDeviceDescriptorIndexingFeaturesEXT {
            sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
            shaderSampledImageArrayNonUniformIndexing = true,
            shaderStorageImageArrayNonUniformIndexing = true,
            shaderStorageBufferArrayNonUniformIndexing = true,
            descriptorBindingSampledImageUpdateAfterBind = true,
            descriptorBindingStorageImageUpdateAfterBind = true,
            descriptorBindingStorageBufferUpdateAfterBind = true,
            descriptorBindingPartiallyBound = b32(needs_partially_bound),
        }
        append(&pnext_chain, cast(^vk.BaseOutStructure)&features_to_enable.descriptor_indexing)
    }

    if api_version >= vk.API_VERSION_1_2 || vk_has_extension(available_extensions,
            vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME) {
        features_to_enable.timeline_semaphore = vk.PhysicalDeviceTimelineSemaphoreFeaturesKHR {
            sType = .PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES,
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

    // TODO

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

    default_family_index :   u32 = 0 // default
    default_queue_priority : f32 = 1.0

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

    impl.queue_flags =
        adapter_impl.vk_queue_families[default_family_index].queueFlags

    vk_setup_pnext_chain(&device_create_info, pnext_chain[:])

    res := vk.CreateDevice(
        adapter_impl.vk_physical_device, &device_create_info, nil, &impl.vk_device)
    if res != .SUCCESS {
        return
    }

    // Bind Vulkan functions
    vk.load_proc_addresses_device_vtable(impl.vk_device, &impl.fp)
    impl.fp.vk_device = impl.vk_device

    device_impl := new_clone(impl, adapter_impl.allocator)
    init_ref(device_impl)
    device_out := Device(device_impl)

    // For use with empty pipeline layouts
    vk_create_empty_pipeline_layout :: proc(
        fp: VK_Device_VTable,
    ) -> vk.PipelineLayout {
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
    vk_create_empty_descriptor_set_layout :: proc(
        fp: VK_Device_VTable,
    ) -> vk.DescriptorSetLayout {
        vk_info := vk.DescriptorSetLayoutCreateInfo {
            sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            bindingCount = 0,
            pBindings    = nil,
        }
        layout: vk.DescriptorSetLayout
        vk_check(fp.CreateDescriptorSetLayout(fp.vk_device, &vk_info, nil, &layout))
        return layout
    }

    device_impl.vk_empty_descriptor_set_layout =
        vk_create_empty_descriptor_set_layout(device_impl.fp)

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

        allocator_desc : = gpua.VK_Allocator_Create_Desc {
            physical_device  = adapter_impl.vk_physical_device,
            device           = device_impl.vk_device,
            allocation_sizes = gpua.DEFAULT_ALLOCATION_SIZES,
            vulkan_functions = gpu_vulkan_functions,
        }

        when ODIN_DEBUG {
            allocator_desc.debug_settings = {
                log_memory_information = true,
                log_leaks_on_shutdown = true,
                log_frees = false,
            }
        }

        gpua.vk_allocator_init(
            &device_impl.gpu_allocator, allocator_desc, device_impl.allocator, loc)
    }

    // Set default graphics queue
    vk_queue_init(&device_impl.queue, default_family_index, device_out)

    // Initialize sub-systems
    vk_submit_context_init(
        &device_impl.submitter,
        device_out,
        default_family_index,
        device_impl.allocator)

    max_update_after_bind: u32
    if prop, prop_ok := adapter_impl.vk_properties.descriptor_indexing.?; prop_ok {
        max_update_after_bind = prop.maxUpdateAfterBindDescriptorsInAllPools
    }
    vk_descriptor_allocator_init(
        &device_impl.descriptor,
        device_out,
        max_update_after_bind,
        device_impl.allocator)

    vk_deferred_init(
        &device_impl.deferred,
        device_out,
        device_impl.vma_allocator,
        &device_impl.gpu_allocator,
        device_impl.allocator)

    // Set default allocator
    device_impl.framebuffer_cache.allocator = device_impl.allocator
    device_impl.render_pass_cache.allocator = device_impl.allocator

    // Initialize the sampler cache
    vk_sampler_cache_init(
        &device_impl.sampler_cache,
        device_out,
        adapter_impl.vk_properties.limits.maxSamplerAllocationCount,
        device_impl.allocator)

    // Initialize resources
    dhm_init(&device_impl.bind_groups, device_impl.allocator)
    dhm_init(&device_impl.bind_group_layouts, device_impl.allocator)
    dhm_init(&device_impl.buffers, device_impl.allocator)
    dhm_init(&device_impl.command_buffers, device_impl.allocator)
    dhm_init(&device_impl.command_encoders, device_impl.allocator)
    dhm_init(&device_impl.computer_passes, device_impl.allocator)
    dhm_init(&device_impl.pipeline_layouts, device_impl.allocator)
    dhm_init(&device_impl.queues, device_impl.allocator)
    dhm_init(&device_impl.render_passes, device_impl.allocator)
    dhm_init(&device_impl.render_pipelines, device_impl.allocator)
    dhm_init(&device_impl.samplers, device_impl.allocator)
    dhm_init(&device_impl.shader_modules, device_impl.allocator)
    dhm_init(&device_impl.texture_views, device_impl.allocator)
    dhm_init(&device_impl.textures, device_impl.allocator)

    device_tracker_init(
        &device_impl.trackers,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
        device_impl.allocator)

    tracker_index_allocators_init(&device_impl.tracker_indices, device_impl.allocator)

    vk_adapter_add_ref(adapter, loc)

    return device_out, true
}

vk_device_get_deferred_writes :: #force_inline proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^Deferred_Writes {
    impl := vk_device_get_impl(device, loc)
    return &impl.queue.deferred_writes
}

vk_device_get_public_impl :: #force_inline proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^Device_Impl {
    return vk_device_get_impl(device, loc)
}

vk_device_get_impl :: #force_inline proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^VK_Device_Impl {
    assert_contextless(device != nil, "invalid device", loc)
    return cast(^VK_Device_Impl)device
}

vk_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
    impl := vk_device_get_impl(device, loc)
    return impl.adapter
}

vk_device_get_instance :: proc(device: Device, loc := #caller_location) -> Instance {
    impl := vk_device_get_impl(device, loc)
    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)
    return adapter_impl.instance
}

vk_device_create_bind_group :: vk_create_bind_group

vk_device_create_bind_group_layout :: vk_create_bind_group_layout

vk_device_create_buffer :: vk_create_buffer

vk_device_create_command_encoder :: vk_create_command_encoder

vk_device_create_compute_pipeline :: vk_create_compute_pipeline

vk_device_create_compute_pipeline_async :: vk_create_compute_pipeline_async

vk_device_create_pipeline_layout :: vk_create_pipeline_layout

vk_device_create_query_set :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set {
    unimplemented(loc = loc)
}

vk_device_create_render_bundle_encoder :: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder {
    unimplemented(loc = loc)
}

vk_device_create_render_pipeline :: vk_create_render_pipeline

vk_device_create_render_pipeline_async :: vk_create_render_pipeline_async

vk_device_create_sampler :: vk_create_sampler

vk_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    impl := vk_device_get_impl(device, loc)

    #partial switch source in descriptor.source {
    case Shader_Source_SPIRV:
        assert(len(source.code) > 0, "VULKAN: shader code is empty", loc)
        assert(len(source.code) >= 5, "VULKAN: shader bytecode too small to be valid", loc)

        create_info := vk.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(source.code) * size_of(u32),
            pCode    = raw_data(source.code),
        }

        vk_shader_module: vk.ShaderModule
        vk_check(vk.CreateShaderModule(
            impl.vk_device, &create_info, nil, &vk_shader_module), loc = loc)

        _, shader_module_handle := add_impl(&impl.shader_modules, VK_Shader_Module_Impl{
            device           = device,
            vk_shader_module = vk_shader_module,
        })

        return new_handle(Shader_Module, device, shader_module_handle)
    case:
        panic("VULKAN: Invalid shader source", loc)
    }

    unreachable()
}

vk_device_create_texture :: vk_create_texture

vk_device_destroy :: proc(device: Device, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_device_get_adapter_info :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
    status: Status,
) {
    unimplemented(loc = loc)
}

vk_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
    unimplemented(loc = loc)
}

vk_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    impl := vk_device_get_impl(device, loc)
    _, queue_handle := add_impl(&impl.queues, VK_Queue_Impl{
        device = device,
    })
    return new_handle(Queue, device, queue_handle)
}

vk_device_pop_error_scope :: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

vk_device_push_error_scope :: proc(device: Device, filter: Error_Filter, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_device_backend :: proc(device: Device, loc := #caller_location) -> Backend_Type {
    return .Vulkan
}

vk_device_is_embedded :: proc(device: Device, loc := #caller_location) -> bool {
    return false
}

vk_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_device_add_ref :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    add_ref(impl, loc)
}

vk_device_clear_render_passes :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)

    // Detach entries under their cache locks, then enqueue destruction after
    // unlocking so cache -> deferred-deletion is never a nested lock order.
    framebuffers: [dynamic]vk.Framebuffer
    render_passes: [dynamic]vk.RenderPass
    framebuffers.allocator = impl.allocator
    render_passes.allocator = impl.allocator

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
    }

    for fb in framebuffers {
        vk_deferred_add_resource(&impl.deferred, &impl.submitter, fb)
    }
    for rp in render_passes {
        vk_deferred_add_resource(&impl.deferred, &impl.submitter, rp)
    }
    delete(framebuffers)
    delete(render_passes)
}

vk_device_release :: proc(device: Device, loc := #caller_location) {
    impl := vk_device_get_impl(device, loc)
    if release_ref(impl, loc) {
        vk_submit_context_device_wait_idle(&impl.submitter, loc)

        context.allocator = impl.allocator

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

        vk_deferred_wait_and_process_all(&impl.deferred, &impl.submitter)

        vk_sampler_cache_destroy(&impl.sampler_cache)

        vk_deferred_uninit(&impl.deferred)
        vk_submit_context_uninit(&impl.submitter)
        vk_descriptor_allocator_uninit(&impl.descriptor)

        vk_queue_uinit(&impl.queue)

        when USE_VMA {
            vma.DestroyAllocator(impl.vma_allocator)
        } else {
            gpua.vk_allocator_uninit(&impl.gpu_allocator)
        }

        impl.fp.DestroyPipelineLayout(impl.vk_device, impl.vk_empty_pipeline_layout, nil)
        impl.fp.DestroyDescriptorSetLayout(
            impl.vk_device, impl.vk_empty_descriptor_set_layout, nil)

        vk_adapter_release(impl.adapter, loc)

        vk.DestroyDevice(impl.vk_device, nil)

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
        dhm_destroy(&impl.pipeline_layouts)
        dhm_destroy(&impl.queues)
        dhm_destroy(&impl.render_passes)
        dhm_destroy(&impl.render_pipelines)
        dhm_destroy(&impl.samplers)
        dhm_destroy(&impl.shader_modules)
        dhm_destroy(&impl.texture_views)
        dhm_destroy(&impl.textures)

        device_tracker_uninit(&impl.trackers)
        tracker_index_allocators_uninit(&impl.tracker_indices)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Deferred deletion
// -----------------------------------------------------------------------------

VK_Deferred_Buffer :: struct {
    buffer:         vk.Buffer,
    tracker_index:  Tracker_Index,
    vma_allocation: vma.Allocation,
    gpu_allocation: gpua.VK_Allocation,
}

VK_Deferred_Image :: struct {
    image:         vk.Image,
    tracker_index: Tracker_Index,
    allocation:    VK_Texture_Memory_Allocation,
}

VK_Deferred_Descriptor_Set :: struct {
    descriptor:     ^VK_Descriptor_Allocator,
    descriptor_set: VK_Descriptor_Set,
}

VK_Deferred_Sampler :: struct {
    cache:       ^VK_Sampler_Cache,
    create_info: vk.SamplerCreateInfo,
    sampler:     vk.Sampler,
}

VK_Deferred_Bind_Group_Layout :: struct {
    allocator: ^VK_Descriptor_Allocator,
    layout:    VK_Descriptor_Layout_Info,
}

VK_Deferred_Resource :: union {
    VK_Deferred_Buffer,
    VK_Deferred_Image,
    VK_Deferred_Descriptor_Set,
    VK_Deferred_Sampler,
    VK_Deferred_Bind_Group_Layout,
    vk.ImageView,
    vk.Pipeline,
    vk.Sampler,
    vk.Framebuffer,
    vk.RenderPass,
    vk.DescriptorSetLayout,
    vk.PipelineLayout,
}

VK_Deferred_Deletion :: struct {
    wait_on:  VK_Submit_Handle,
    resource: VK_Deferred_Resource,
}

// Resources whose last reference was dropped, held back until the submission they
// were last used in has completed.
//
// `mtx` is held while the queue is drained (`vk_deferred_process`), which includes
// destroying the Vulkan objects. Lock ordering: `mtx` -> device tracker -> shared
// tracker-index allocator, and `mtx` -> submit context. The device tracker locks are
// leaves (their metadata is weak, so they never fire the retain/release hooks that
// route into `vk_deferred_add_resource`), which is what keeps this a DAG rather
// than a cycle.
VK_Deferred_Deletor :: struct {
    device:        Device,
    resources:     [dynamic]VK_Deferred_Deletion,
    allocator:     runtime.Allocator,
    vma_allocator: vma.Allocator,
    gpu_allocator: ^gpua.VK_Allocator,
    mtx:           sync.Mutex,
}

vk_deferred_init :: proc(
    self: ^VK_Deferred_Deletor,
    device: Device,
    vma_allocator: vma.Allocator,
    gpu_allocator: ^gpua.VK_Allocator,
    allocator: runtime.Allocator,
) {
    self.device = device
    self.vma_allocator = vma_allocator
    self.allocator = allocator
    self.gpu_allocator = gpu_allocator
    self.resources = make([dynamic]VK_Deferred_Deletion, 0, 16, allocator)
}

vk_deferred_uninit :: proc(self: ^VK_Deferred_Deletor) {
    delete(self.resources)
}

vk_deferred_add_resource :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    resource: VK_Deferred_Resource,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    wait_on := vk_submit_context_get_next_submit_handle(submitter)
    assert(wait_on != {}, "nothing to wait on", loc)
    append(&self.resources, VK_Deferred_Deletion{
        wait_on  = wait_on,
        resource = resource,
    })
}

vk_deferred_destroy_buffer :: proc(
    self: ^VK_Deferred_Deletor,
    res: ^VK_Deferred_Buffer,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    device_buffer_tracker_remove(
        &device_impl.trackers.buffers, res.tracker_index)
    shared_tracker_index_allocator_free(
        &device_impl.tracker_indices.buffers, res.tracker_index)

    when USE_VMA {
        vma.DestroyBuffer(self.vma_allocator, res.buffer, res.vma_allocation)
    } else {
        device_impl.fp.DestroyBuffer(device_impl.vk_device, res.buffer, nil)
        free_err := gpua.vk_allocator_free(self.gpu_allocator, &res.gpu_allocation)
        if free_err != .None {
            log.errorf("VULKAN: failed to free buffer allocation: %v", free_err, location = loc)
        }
    }
}

vk_deferred_destroy_image :: proc(
    self: ^VK_Deferred_Deletor,
    res: ^VK_Deferred_Image,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    device_texture_tracker_remove(
        &device_impl.trackers.textures, res.tracker_index)
    shared_tracker_index_allocator_free(
        &device_impl.tracker_indices.textures, res.tracker_index)

    when USE_VMA {
        #partial switch &allocation in res.allocation {
        case vma.Allocation:
            vma.DestroyImage(self.vma_allocator, res.image, allocation)
        case:
            unreachable()
        }
    } else {
        device_impl.fp.DestroyImage(device_impl.vk_device, res.image, nil)
        #partial switch &allocation in res.allocation {
        case gpua.VK_Allocation:
            free_err := gpua.vk_allocator_free(self.gpu_allocator, &allocation)
            if free_err != .None {
                log.errorf("VULKAN: failed to free image allocation: %v", free_err, location = loc)
            }
        case:
            unreachable()
        }
    }
}

vk_deferred_destroy_resource :: proc(
    self: ^VK_Deferred_Deletor,
    pending: ^VK_Deferred_Deletion,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    switch &res in pending.resource {
    case VK_Deferred_Buffer:
        vk_deferred_destroy_buffer(self, &res, loc)

    case VK_Deferred_Image:
        vk_deferred_destroy_image(self, &res, loc)

    case VK_Deferred_Descriptor_Set:
        vk_descriptor_allocator_free(res.descriptor, res.descriptor_set)

    case VK_Deferred_Sampler:
        vk_sampler_cache_destroy_sampler(res.cache, &res.create_info, res.sampler)

    case VK_Deferred_Bind_Group_Layout:
        vk_descriptor_allocator_unregister_layout(res.allocator, res.layout, loc)
        device_impl.fp.DestroyDescriptorSetLayout(device_impl.vk_device, res.layout.raw, nil)

    case vk.ImageView:
        device_impl.fp.DestroyImageView(device_impl.vk_device, res, nil)

    case vk.Pipeline:
        device_impl.fp.DestroyPipeline(device_impl.vk_device, res, nil)

    case vk.Sampler:
        device_impl.fp.DestroySampler(device_impl.vk_device, res, nil)

    case vk.Framebuffer:
        device_impl.fp.DestroyFramebuffer(device_impl.vk_device, res, nil)

    case vk.RenderPass:
        device_impl.fp.DestroyRenderPass(device_impl.vk_device, res, nil)

    case vk.DescriptorSetLayout:
        device_impl.fp.DestroyDescriptorSetLayout(device_impl.vk_device, res, nil)

    case vk.PipelineLayout:
        device_impl.fp.DestroyPipelineLayout(device_impl.vk_device, res, nil)
    }
}

VK_Deferred_Slot_State :: enum u8 { Unknown, Not_Ready, Ready }

@(optimization_mode="favor_size")
vk_deferred_process :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    loc := #caller_location,
) #no_bounds_check {
    sync.guard(&self.mtx)

    slot_state: [MAX_COMMAND_BUFFERS]VK_Deferred_Slot_State

    write_index := 0
    for read_index := 0; read_index < len(self.resources); read_index += 1 {
        pending := &self.resources[read_index]
        idx := pending.wait_on.buffer_index

        // Cheap path first: stale handle (slot already recycled onto a
        // newer submit_id) resolves without touching Vulkan at all.
        ready := vk_submit_context_is_ready(
            submitter, pending.wait_on, fast_check_no_vulkan = true, loc = loc)
        if !ready {
            if slot_state[idx] == .Unknown {
                slot_state[idx] =
                    vk_submit_context_is_ready(submitter, pending.wait_on, loc = loc) \
                        ? .Ready : .Not_Ready
            }
            ready = slot_state[idx] == .Ready
        }

        if ready {
            vk_deferred_destroy_resource(self, pending, loc)
            continue
        }

        if write_index != read_index {
            self.resources[write_index] = self.resources[read_index]
        }
        write_index += 1
    }

    resize(&self.resources, write_index)
}

vk_deferred_wait_and_process_all :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)

    for &pending in self.resources {
        vk_submit_context_wait(submitter, pending.wait_on, loc = loc)
        vk_deferred_destroy_resource(self, &pending, loc)
    }

    clear(&self.resources)
}
