#+build !js
package gpu

// Core
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Physical_Device_Properties :: struct {
    using properties:       vk.PhysicalDeviceProperties,
    extensions:             []string,
    maintenance3:           Maybe(vk.PhysicalDeviceMaintenance3Properties),
    maintenance4:           Maybe(vk.PhysicalDeviceMaintenance4Properties),
    descriptor_indexing:    Maybe(vk.PhysicalDeviceDescriptorIndexingPropertiesEXT),
    acceleration_structure: Maybe(vk.PhysicalDeviceAccelerationStructurePropertiesKHR),
    ray_tracing_pipeline:   Maybe(vk.PhysicalDeviceRayTracingPipelinePropertiesKHR),
    driver:                 Maybe(vk.PhysicalDeviceDriverPropertiesKHR),
    subgroup:               Maybe(vk.PhysicalDeviceSubgroupProperties),
    subgroup_size_control:  Maybe(vk.PhysicalDeviceSubgroupSizeControlProperties),
    robustness2:            Maybe(vk.PhysicalDeviceRobustness2PropertiesEXT),
    mesh_shader:            Maybe(vk.PhysicalDeviceMeshShaderPropertiesEXT),
    multiview:              Maybe(vk.PhysicalDeviceMultiviewPropertiesKHR),
    pci_bus_info:           Maybe(vk.PhysicalDevicePCIBusInfoPropertiesEXT),
}

// Features supported by a `vk.PhysicalDevice` and its extensions.
VK_Physical_Device_Features :: struct {
    using core:                       vk.PhysicalDeviceFeatures,
    descriptor_indexing:              Maybe(vk.PhysicalDeviceDescriptorIndexingFeaturesEXT),
    timeline_semaphore:               Maybe(vk.PhysicalDeviceTimelineSemaphoreFeaturesKHR),
    image_robustness:                 Maybe(vk.PhysicalDeviceImageRobustnessFeaturesEXT),
    robustness2:                      Maybe(vk.PhysicalDeviceRobustness2FeaturesEXT),
    multiview:                        Maybe(vk.PhysicalDeviceMultiviewFeaturesKHR),
    sampler_ycbcr_conversion:         Maybe(vk.PhysicalDeviceSamplerYcbcrConversionFeatures),
    astc_hdr:                         Maybe(vk.PhysicalDeviceTextureCompressionASTCHDRFeaturesEXT),
    shader_float16_int8:              Maybe(vk.PhysicalDeviceShaderFloat16Int8Features),
    _16bit_storage:                   Maybe(vk.PhysicalDevice16BitStorageFeatures),
    acceleration_structure:           Maybe(vk.PhysicalDeviceAccelerationStructureFeaturesKHR),
    buffer_device_address:            Maybe(vk.PhysicalDeviceBufferDeviceAddressFeaturesKHR),
    ray_query:                        Maybe(vk.PhysicalDeviceRayQueryFeaturesKHR),
    ray_tracing_pipeline:             Maybe(vk.PhysicalDeviceRayTracingPipelineFeaturesKHR),
    zero_initialize_workgroup_memory: Maybe(
        vk.PhysicalDeviceZeroInitializeWorkgroupMemoryFeatures,
    ),
    position_fetch:                   Maybe(vk.PhysicalDeviceRayTracingPositionFetchFeaturesKHR),
    shader_atomic_int64:              Maybe(vk.PhysicalDeviceShaderAtomicInt64Features),
    shader_image_atomic_int64:        Maybe(vk.PhysicalDeviceShaderImageAtomicInt64FeaturesEXT),
    shader_atomic_float:              Maybe(vk.PhysicalDeviceShaderAtomicFloatFeaturesEXT),
    subgroup_size_control:            Maybe(vk.PhysicalDeviceSubgroupSizeControlFeatures),
    maintenance4:                     Maybe(vk.PhysicalDeviceMaintenance4FeaturesKHR),
    mesh_shader:                      Maybe(vk.PhysicalDeviceMeshShaderFeaturesEXT),
    shader_integer_dot_product:       Maybe(vk.PhysicalDeviceShaderIntegerDotProductFeaturesKHR),
    shader_barycentrics:              Maybe(vk.PhysicalDeviceFragmentShaderBarycentricFeaturesKHR),
    portability_subset:               Maybe(vk.PhysicalDevicePortabilitySubsetFeaturesKHR),
    cooperative_matrix:               Maybe(vk.PhysicalDeviceCooperativeMatrixFeaturesKHR),
    vulkan_memory_model:              Maybe(vk.PhysicalDeviceVulkanMemoryModelFeaturesKHR),
    shader_draw_parameters:           Maybe(vk.PhysicalDeviceShaderDrawParametersFeatures),
}

// Set of internal capabilities, which affect the code paths taken internally.
VK_Private_Capabilities :: struct {
    image_view_usage:                     bool,
    timeline_semaphores:                  bool,
    texture_d24:                          bool,
    texture_d24_s8:                       bool,
    texture_s8:                           bool,
    can_present:                          bool,
    non_coherent_map_mask:                u64,
    multi_draw_indirect:                  bool,
    max_draw_indirect_count:              u32,
    robust_buffer_access:                 bool,
    robust_image_access:                  bool,
    robust_buffer_access2:                bool,
    robust_image_access2:                 bool,
    zero_initialize_workgroup_memory:     bool,
    image_format_list:                    bool,
    maximum_samplers:                     u32,
    shader_integer_dot_product:           bool,
    shader_int8:                          bool,
    multiview_instance_index_limit:       u32,
    scratch_buffer_alignment:             u32,
    ray_tracing_pipeline_group_data_size: u32,
    store_op_none:                        bool,
}

VK_Adapter_Impl :: struct {
    using base:         _Adapter_Impl,
    vk_physical_device: vk.PhysicalDevice,
    vk_properties:      VK_Physical_Device_Properties,
    vk_features:        VK_Physical_Device_Features,
    vk_queue_families:  []vk.QueueFamilyProperties,
    graphics_family:    u32,
    present_family:     u32,
    has_present_family: bool,
    vk_mem_properties:  vk.PhysicalDeviceMemoryProperties,
    known_memory_flags: vk.MemoryPropertyFlags,
    arena_buf:          []u8,
    caps:               VK_Private_Capabilities,
    arena:              mem.Arena,

    // Format capabilities are immutable for a physical device, but
    // `GetPhysicalDeviceFormatProperties` is a driver call. Render-pass and
    // pipeline validation hit this per attachment, so fill lazily and reuse.
    format_caps:       [Texture_Format]Texture_Format_Capabilities,
    format_caps_ready: [Texture_Format]bool,
    format_caps_mtx:   sync.Mutex,
}

@(require_results)
vk_adapter_get_impl :: #force_inline proc "contextless" (
    adapter: Adapter,
    loc := #caller_location,
) -> ^VK_Adapter_Impl {
    assert_contextless(adapter != nil, "invalid adapter", loc)
    return cast(^VK_Adapter_Impl)adapter
}

@(require_results)
vk_adapter_get_internal_impl :: #force_inline proc "contextless" (
    adapter: Adapter,
    loc := #caller_location,
) -> ^_Adapter_Impl {
    return vk_adapter_get_impl(adapter, loc)
}

@(require_results)
vk_create_adapter :: proc(
    pd: vk.PhysicalDevice,
    instance: Instance,
    surface: Surface,
    loc := #caller_location,
) -> (
    out: VK_Adapter_Impl,
    ok: bool,
) {
    instance_impl := vk_instance_get_impl(instance, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    out.instance = instance
    out.allocator = instance_impl.allocator
    out.vk_physical_device = pd

    // Get supported device extension names
    extension_count: u32
    res := vk.EnumerateDeviceExtensionProperties(pd, nil, &extension_count, nil)
    if res != .SUCCESS {
        return
    }
    available_extensions := make([]vk.ExtensionProperties, extension_count, ta)
    res = vk.EnumerateDeviceExtensionProperties(
        pd,
        nil,
        &extension_count,
        raw_data(available_extensions),
    )
    if res != .SUCCESS {
        return
    }

    // Initialize an arena allocator with enough space to clone the device
    // extensions names. Typical devices commonly expose 200-350 extensions
    out.arena_buf = make([]byte, 256 * mem.Kilobyte, out.allocator)
    mem.arena_init(&out.arena, out.arena_buf)
    defer if !ok {delete(out.arena_buf, out.allocator)}

    buf_allocator := mem.arena_allocator(&out.arena)

    out.vk_properties.extensions = make([]string, extension_count, out.allocator)
    defer if !ok {delete(out.vk_properties.extensions, out.allocator)}

    for &ext, i in available_extensions {
        ext_name := byte_arr_str(&ext.extensionName)
        out.vk_properties.extensions[i] = strings.clone(ext_name, buf_allocator)
    }

    // We use binary search later to optimize the query, this requires data to be sorted
    slice.sort(out.vk_properties.extensions)

    // Get base properties
    vk.GetPhysicalDeviceProperties(pd, &out.vk_properties.properties)
    api_version := out.vk_properties.apiVersion

    properties_chain := make([dynamic]^vk.BaseOutStructure, ta)

    // VK_KHR_maintenance3
    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_3_EXTENSION_NAME) {
        out.vk_properties.maintenance3 = vk.PhysicalDeviceMaintenance3Properties {
            sType = .PHYSICAL_DEVICE_MAINTENANCE_3_PROPERTIES,
        }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.maintenance3)
    }

    // VK_KHR_maintenance4
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_4_EXTENSION_NAME) {
        out.vk_properties.maintenance4 = vk.PhysicalDeviceMaintenance4Properties {
            sType = .PHYSICAL_DEVICE_MAINTENANCE_4_PROPERTIES,
        }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.maintenance4)
    }

    // VK_EXT_descriptor_indexing
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(out.vk_properties.extensions, vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME) {
        out.vk_properties.descriptor_indexing = vk.PhysicalDeviceDescriptorIndexingProperties {
            sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_PROPERTIES,
        }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.descriptor_indexing)
    }

    // VK_KHR_acceleration_structure
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    ) {
        out.vk_properties.acceleration_structure =
            vk.PhysicalDeviceAccelerationStructurePropertiesKHR {
                sType = .PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR,
            }
        append(
            &properties_chain,
            cast(^vk.BaseOutStructure)&out.vk_properties.acceleration_structure,
        )
    }

    // VK_KHR_acceleration_structure
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME) {
        out.vk_properties.ray_tracing_pipeline = vk.PhysicalDeviceRayTracingPipelinePropertiesKHR {
                sType = .PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR,
            }
        append(
            &properties_chain,
            cast(^vk.BaseOutStructure)&out.vk_properties.ray_tracing_pipeline,
        )
    }

    // VK_KHR_driver_properties
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_DRIVER_PROPERTIES_EXTENSION_NAME) {
        out.vk_properties.driver = vk.PhysicalDeviceDriverPropertiesKHR {
                sType = .PHYSICAL_DEVICE_DRIVER_PROPERTIES,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.driver)
    }

    // Subgroup
    if api_version >= vk.API_VERSION_1_1 {
        out.vk_properties.subgroup = vk.PhysicalDeviceSubgroupProperties {
                sType = .PHYSICAL_DEVICE_SUBGROUP_PROPERTIES,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.subgroup)
    }

    // VK_EXT_subgroup_size_control
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME,
       ) {
        out.vk_properties.subgroup_size_control = vk.PhysicalDeviceSubgroupSizeControlProperties {
                sType = .PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES,
            }
        append(
            &properties_chain,
            cast(^vk.BaseOutStructure)&out.vk_properties.subgroup_size_control,
        )
    }

    // VK_EXT_robustness2
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_ROBUSTNESS_2_EXTENSION_NAME) {
        out.vk_properties.robustness2 = vk.PhysicalDeviceRobustness2PropertiesEXT {
                sType = .PHYSICAL_DEVICE_ROBUSTNESS_2_PROPERTIES_EXT,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.robustness2)
    }

    // VK_EXT_mesh_shader
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_MESH_SHADER_EXTENSION_NAME) {
        out.vk_properties.mesh_shader = vk.PhysicalDeviceMeshShaderPropertiesEXT {
                sType = .PHYSICAL_DEVICE_MESH_SHADER_PROPERTIES_EXT,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.mesh_shader)
    }

    // VK_KHR_multiview
    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MULTIVIEW_EXTENSION_NAME) {
        out.vk_properties.multiview = vk.PhysicalDeviceMultiviewPropertiesKHR {
                sType = .PHYSICAL_DEVICE_MULTIVIEW_PROPERTIES,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.multiview)
    }

    // VK_EXT_pci_bus_info
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_PCI_BUS_INFO_EXTENSION_NAME) {
        out.vk_properties.pci_bus_info = vk.PhysicalDevicePCIBusInfoPropertiesEXT {
                sType = .PHYSICAL_DEVICE_PCI_BUS_INFO_PROPERTIES_EXT,
            }
        append(&properties_chain, cast(^vk.BaseOutStructure)&out.vk_properties.pci_bus_info)
    }

    properties2 := vk.PhysicalDeviceProperties2KHR {
            sType = .PHYSICAL_DEVICE_PROPERTIES_2,
        }
    vk_setup_pnext_chain(&properties2, properties_chain[:])
    vk.GetPhysicalDeviceProperties2(pd, &properties2)
    out.vk_properties.properties = properties2.properties

    name := byte_arr_str(&out.vk_properties.deviceName)

    // Check Vulkan conformance implementation
    if driver, props_ok := out.vk_properties.driver.?; props_ok {
        if driver.conformanceVersion.major == 0 {
            if driver.driverID == .MOLTENVK {
                log.debugf(
                    "VULKAN: Adapter [%s] is not Vulkan compliant, " +
                    "but is MoltenVK, continuing...",
                    name,
                )
            } else if .Allow_Underlying_Noncompliant_Adapter in instance_impl.flags {
                log.debugf("VULKAN: Adapter is not Vulkan compliant: %s", name)
            } else {
                log.debugf("VULKAN: Adapter is not Vulkan compliant, ignoring adapter: [%s]", name)
                return
            }
        }
    }

    // Check required VK_KHR_storage_buffer_storage_class
    if api_version == vk.API_VERSION_1_0 &&
       !vk_has_extension(
               out.vk_properties.extensions,
               vk.KHR_STORAGE_BUFFER_STORAGE_CLASS_EXTENSION_NAME,
           ) {
        log.debugf(
            "VULKAN: SPIR-V storage buffer class is not supported, " + "ignoring adapter: [%s]",
            name,
        )
        return
    }

    // Check required VK_KHR_maintenance1
    if !vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_1_EXTENSION_NAME) &&
       api_version < vk.API_VERSION_1_1 {
        log.debugf("VULKAN: VK_KHR_maintenance1 is not supported, ignoring adapter: [%s]", name)
        return
    }

    // Query queue families
    queue_family_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(pd, &queue_family_count, nil)
    if queue_family_count == 0 {
        log.debugf("VULKAN: No queue family found, ignoring adapter: [%s]", name)
        return
    }
    out.vk_queue_families = make([]vk.QueueFamilyProperties, queue_family_count, out.allocator)
    defer if !ok {delete(out.vk_queue_families, out.allocator)}
    vk.GetPhysicalDeviceQueueFamilyProperties(
        pd,
        &queue_family_count,
        raw_data(out.vk_queue_families),
    )

    out.graphics_family = vk_get_first_queue_index(out.vk_queue_families, {.GRAPHICS})
    if out.graphics_family == vk.QUEUE_FAMILY_IGNORED {
        log.debugf("VULKAN: No GRAPHICS queue found, ignoring adapter: [%s]", name)
        return
    }

    // Check for presentation support
    if surface != {} {
        if !vk_has_extension(out.vk_properties.extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME) {
            log.debugf("VULKAN: VK_KHR_swapchain is not supported, ignoring adapter: [%s]", name)
            return
        }

        surface_impl := vk_surface_get_impl(surface)

        if vk_get_first_queue_index(out.vk_queue_families, {.GRAPHICS}) ==
           vk.QUEUE_FAMILY_IGNORED {
            log.debugf(
                "VULKAN: The first queue does not expose GRAPHICS, " + "ignoring adapter: [%s]",
                name,
            )
            return
        }

        present_family := vk_get_present_queue_index(
            out.vk_queue_families,
            pd,
            surface_impl.vk_surface,
        )
        if present_family == vk.QUEUE_FAMILY_IGNORED {
            log.debugf("VULKAN: No PRESENT queue found, ignoring adapter: [%s]", name)
            return
        }
        out.present_family = present_family
        out.has_present_family = true
    }

    features_chain := make([dynamic]^vk.BaseOutStructure, ta)

    // VK_KHR_multiview
    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MULTIVIEW_EXTENSION_NAME) {
        out.vk_features.multiview = vk.PhysicalDeviceMultiviewFeatures {
            sType = .PHYSICAL_DEVICE_MULTIVIEW_FEATURES,
        }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.multiview)
    }

    // VK_KHR_sampler_ycbcr_conversion
    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_SAMPLER_YCBCR_CONVERSION_EXTENSION_NAME,
       ) {
        out.vk_features.sampler_ycbcr_conversion =
            vk.PhysicalDeviceSamplerYcbcrConversionFeatures {
                sType = .PHYSICAL_DEVICE_SAMPLER_YCBCR_CONVERSION_FEATURES,
            }
        append(
            &features_chain,
            cast(^vk.BaseOutStructure)&out.vk_features.sampler_ycbcr_conversion,
        )
    }

    // VK_EXT_descriptor_indexing
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME) {
        out.vk_features.descriptor_indexing = vk.PhysicalDeviceDescriptorIndexingFeaturesEXT {
                sType = .PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.descriptor_indexing)
    }

    // VK_KHR_timeline_semaphore
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_TIMELINE_SEMAPHORE_EXTENSION_NAME) {
        out.vk_features.timeline_semaphore = vk.PhysicalDeviceTimelineSemaphoreFeaturesKHR {
                sType = .PHYSICAL_DEVICE_TIMELINE_SEMAPHORE_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.timeline_semaphore)
    }

    // VK_KHR_shader_atomic_int64
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME) {
        out.vk_features.shader_atomic_int64 = vk.PhysicalDeviceShaderAtomicInt64Features {
                sType = .PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.shader_atomic_int64)
    }

    // VK_EXT_shader_image_atomic_int64
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.EXT_SHADER_IMAGE_ATOMIC_INT64_EXTENSION_NAME,
    ) {
        out.vk_features.shader_image_atomic_int64 =
            vk.PhysicalDeviceShaderImageAtomicInt64FeaturesEXT {
                sType = .PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT64_FEATURES_EXT,
            }
        append(
            &features_chain,
            cast(^vk.BaseOutStructure)&out.vk_features.shader_image_atomic_int64,
        )
    }

    // VK_EXT_shader_atomic_float
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_SHADER_ATOMIC_FLOAT_EXTENSION_NAME) {
        out.vk_features.shader_atomic_float = vk.PhysicalDeviceShaderAtomicFloatFeaturesEXT {
                sType = .PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_FEATURES_EXT,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.shader_atomic_float)
    }

    // VK_EXT_image_robustness
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_IMAGE_ROBUSTNESS_EXTENSION_NAME) {
        out.vk_features.image_robustness = vk.PhysicalDeviceImageRobustnessFeaturesEXT {
                sType = .PHYSICAL_DEVICE_IMAGE_ROBUSTNESS_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.image_robustness)
    }

    // VK_EXT_robustness2
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_ROBUSTNESS_2_EXTENSION_NAME) {
        out.vk_features.robustness2 = vk.PhysicalDeviceRobustness2FeaturesEXT {
                sType = .PHYSICAL_DEVICE_ROBUSTNESS_2_FEATURES_EXT,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.robustness2)
    }

    // VK_EXT_texture_compression_astc_hdr
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.EXT_TEXTURE_COMPRESSION_ASTC_HDR_EXTENSION_NAME,
    ) {
        out.vk_features.astc_hdr = vk.PhysicalDeviceTextureCompressionASTCHDRFeaturesEXT {
                sType = .PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTC_HDR_FEATURES_EXT,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.astc_hdr)
    }

    // VK_KHR_shader_float16_int8
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_SHADER_FLOAT16_INT8_EXTENSION_NAME) {
        out.vk_features.shader_float16_int8 = vk.PhysicalDeviceShaderFloat16Int8FeaturesKHR {
                sType = .PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.shader_float16_int8)
    }

    // VK_KHR_16bit_storage
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_16BIT_STORAGE_EXTENSION_NAME) {
        out.vk_features._16bit_storage = vk.PhysicalDevice16BitStorageFeaturesKHR {
                sType = .PHYSICAL_DEVICE_16BIT_STORAGE_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features._16bit_storage)
    }

    // VK_KHR_acceleration_structure
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
    ) {
        out.vk_features.acceleration_structure =
            vk.PhysicalDeviceAccelerationStructureFeaturesKHR {
                sType = .PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.acceleration_structure)
    }

    // VK_KHR_buffer_device_address
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,
       ) {
        out.vk_features.buffer_device_address = vk.PhysicalDeviceBufferDeviceAddressFeaturesKHR {
                sType = .PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.buffer_device_address)
    }

    // VK_KHR_ray_query
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_RAY_QUERY_EXTENSION_NAME) {
        out.vk_features.ray_query = vk.PhysicalDeviceRayQueryFeaturesKHR {
                sType = .PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.ray_query)
    }

    // Ray tracing pipelines are optional alongside ray queries.
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME) {
        out.vk_features.ray_tracing_pipeline = vk.PhysicalDeviceRayTracingPipelineFeaturesKHR {
                sType = .PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.ray_tracing_pipeline)
    }

    // VK_KHR_ray_tracing_position_fetch
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_RAY_TRACING_POSITION_FETCH_EXTENSION_NAME,
    ) {
        out.vk_features.position_fetch = vk.PhysicalDeviceRayTracingPositionFetchFeaturesKHR {
                sType = .PHYSICAL_DEVICE_RAY_TRACING_POSITION_FETCH_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.position_fetch)
    }

    // VK_KHR_maintenance4
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_4_EXTENSION_NAME) {
        out.vk_features.maintenance4 = vk.PhysicalDeviceMaintenance4Features {
                sType = .PHYSICAL_DEVICE_MAINTENANCE_4_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.maintenance4)
    }

    // VK_KHR_zero_initialize_workgroup_memory
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_ZERO_INITIALIZE_WORKGROUP_MEMORY_EXTENSION_NAME,
       ) {
        out.vk_features.zero_initialize_workgroup_memory =
            vk.PhysicalDeviceZeroInitializeWorkgroupMemoryFeatures {
                sType = .PHYSICAL_DEVICE_ZERO_INITIALIZE_WORKGROUP_MEMORY_FEATURES,
            }
        append(
            &features_chain,
            cast(^vk.BaseOutStructure)&out.vk_features.zero_initialize_workgroup_memory,
        )
    }

    // VK_EXT_subgroup_size_control
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME,
       ) {
        out.vk_features.subgroup_size_control = vk.PhysicalDeviceSubgroupSizeControlFeatures {
                sType = .PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.subgroup_size_control)
    }

    // VK_EXT_mesh_shader
    if vk_has_extension(out.vk_properties.extensions, vk.EXT_MESH_SHADER_EXTENSION_NAME) {
        out.vk_features.mesh_shader = vk.PhysicalDeviceMeshShaderFeaturesEXT {
                sType = .PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.mesh_shader)
    }

    // VK_KHR_shader_integer_dot_product
    if api_version >= vk.API_VERSION_1_3 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_SHADER_INTEGER_DOT_PRODUCT_EXTENSION_NAME,
       ) {
        out.vk_features.shader_integer_dot_product =
            vk.PhysicalDeviceShaderIntegerDotProductFeatures {
                sType = .PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_FEATURES,
            }
        append(
            &features_chain,
            cast(^vk.BaseOutStructure)&out.vk_features.shader_integer_dot_product,
        )
    }

    // VK_KHR_fragment_shader_barycentric
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_FRAGMENT_SHADER_BARYCENTRIC_EXTENSION_NAME,
    ) {
        out.vk_features.shader_barycentrics =
            vk.PhysicalDeviceFragmentShaderBarycentricFeaturesKHR {
                sType = .PHYSICAL_DEVICE_FRAGMENT_SHADER_BARYCENTRIC_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.shader_barycentrics)
    }

    // VK_KHR_portability_subset
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME) {
        out.vk_features.portability_subset = vk.PhysicalDevicePortabilitySubsetFeaturesKHR {
                sType = .PHYSICAL_DEVICE_PORTABILITY_SUBSET_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.portability_subset)
    }

    // VK_KHR_cooperative_matrix
    if vk_has_extension(out.vk_properties.extensions, vk.KHR_COOPERATIVE_MATRIX_EXTENSION_NAME) {
        out.vk_features.cooperative_matrix = vk.PhysicalDeviceCooperativeMatrixFeaturesKHR {
                sType = .PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.cooperative_matrix)
    }

    // VK_KHR_vulkan_memory_model
    if api_version >= vk.API_VERSION_1_2 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_VULKAN_MEMORY_MODEL_EXTENSION_NAME) {
        out.vk_features.vulkan_memory_model = vk.PhysicalDeviceVulkanMemoryModelFeaturesKHR {
                sType = .PHYSICAL_DEVICE_VULKAN_MEMORY_MODEL_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.vulkan_memory_model)
    }

    // VK_KHR_shader_draw_parameters (core in 1.1)
    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_SHADER_DRAW_PARAMETERS_EXTENSION_NAME,
       ) {
        out.vk_features.shader_draw_parameters = vk.PhysicalDeviceShaderDrawParametersFeatures {
                sType = .PHYSICAL_DEVICE_SHADER_DRAW_PARAMETERS_FEATURES,
            }
        append(&features_chain, cast(^vk.BaseOutStructure)&out.vk_features.shader_draw_parameters)
    }

    features2 := vk.PhysicalDeviceFeatures2 {
            sType = .PHYSICAL_DEVICE_FEATURES_2,
        }
    vk_setup_pnext_chain(&features2, features_chain[:])
    vk.GetPhysicalDeviceFeatures2(pd, &features2)
    out.vk_features.core = features2.features

    // Always-available features
    append(&out.features, Feature_Name.Mappable_Primary_Buffers)
    append(&out.features, Feature_Name.Immediates)
    append(&out.features, Feature_Name.Address_Mode_Clamp_To_Border)
    append(&out.features, Feature_Name.Address_Mode_Clamp_To_Zero)
    append(&out.features, Feature_Name.Texture_Adapter_Specific_Format_Features)
    append(&out.features, Feature_Name.Clear_Texture)
    append(&out.features, Feature_Name.Pipeline_Cache)
    append(&out.features, Feature_Name.Shader_Early_Depth_Test)
    append(&out.features, Feature_Name.Texture_Atomic)
    append(&out.features, Feature_Name.Texture_Component_Swizzle)
    append(&out.features, Feature_Name.Memory_Decoration_Coherent)
    append(&out.features, Feature_Name.Memory_Decoration_Volatile)

    // Always-available dl-features
    out.dl_features = {
            .Compute_Shaders,
            .Base_Vertex,
            .Non_Power_Of_Two_Mipmapped_Textures,
            .Comparison_Samplers,
            .Vertex_Storage,
            .Fragment_Storage,
            .Depth_Texture_And_Buffer_Copies,
            .Buffer_Bindings_Not_16_Byte_Aligned,
            .Unrestricted_Index_Buffer,
            .Indirect_Execution,
            .View_Formats,
            .Unrestricted_External_Texture_Copies,
            .Nonblocking_Query_Resolve,
            .Shader_F16_In_F32,
            .Msl2_1,
            .Linear_Interpolation,
        }

    if api_version >= vk.API_VERSION_1_1 ||
       vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_2_EXTENSION_NAME) {
        out.dl_features |= {.Read_Only_Depth_Stencil}
    }

    // If there is a swapchain: only true if the mutable-format extension is
    // actually present.
    //
    // If there's no swapchain at all? true, nothing to restrict.
    if vk_has_extension(
           out.vk_properties.extensions,
           vk.KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME,
       ) ||
       !vk_has_extension(out.vk_properties.extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME) {
        out.dl_features |= {.Surface_View_Formats}
    }

    if out.vk_features.imageCubeArray {
        out.dl_features |= {.Cube_Array_Textures}
    }

    if out.vk_features.samplerAnisotropy {
        out.dl_features |= {.Anisotropic_Filtering}
    }

    if out.vk_features.fragmentStoresAndAtomics {
        out.dl_features |= {.Fragment_Writable_Storage}
    }

    if out.vk_features.independentBlend {
        out.dl_features |= {.Independent_Blend}
    }

    if out.vk_features.fullDrawIndexUint32 {
        out.dl_features |= {.Full_Draw_Index_Uint32}
    }

    if out.vk_features.depthBiasClamp {
        out.dl_features |= {.Depth_Bias_Clamp}
    }

    #no_bounds_check queue_family_properties := out.vk_queue_families[out.graphics_family]
    if queue_family_properties.timestampValidBits >= 36 {
        append(&out.features, Feature_Name.Timestamp_Query)
        append(&out.features, Feature_Name.Timestamp_Query_Inside_Encoders)
        append(&out.features, Feature_Name.Timestamp_Query_Inside_Passes)
    }

    if out.vk_features.drawIndirectFirstInstance {
        append(&out.features, Feature_Name.Indirect_First_Instance)
    }

    if out.vk_features.fillModeNonSolid {
        append(&out.features, Feature_Name.Polygon_Mode_Line)
        append(&out.features, Feature_Name.Polygon_Mode_Point)
    }

    if out.vk_features.textureCompressionETC2 {
        append(&out.features, Feature_Name.Texture_Compression_ETC2)
    }

    if out.vk_features.textureCompressionASTC_LDR {
        append(&out.features, Feature_Name.Texture_Compression_ASTC)
    }

    if out.vk_features.textureCompressionBC {
        append(&out.features, Feature_Name.Texture_Compression_BC)
        append(&out.features, Feature_Name.Texture_Compression_BC_Sliced_3D)
    }

    if out.vk_features.pipelineStatisticsQuery {
        append(&out.features, Feature_Name.Pipeline_Statistics_Query)
    }

    if out.vk_features.vertexPipelineStoresAndAtomics {
        append(&out.features, Feature_Name.Vertex_Writable_Storage)
    }

    if out.vk_features.shaderFloat64 {
        append(&out.features, Feature_Name.Shader_F64)
    }

    if out.vk_features.shaderInt64 {
        append(&out.features, Feature_Name.Shader_Int64)
    }

    if props, props_ok := out.vk_features._16bit_storage.?; props_ok {
        has_16bit_storage :=
            props.storageBuffer16BitAccess && props.uniformAndStorageBuffer16BitAccess
        if out.vk_features.shaderInt16 && has_16bit_storage {
            append(&out.features, Feature_Name.Shader_I16)
        }
        if f16, f16_ok := out.vk_features.shader_float16_int8.?; f16_ok {
            if f16.shaderFloat16 && has_16bit_storage {
                append(&out.features, Feature_Name.Shader_F16)
            }
        }
    }

    if out.vk_features.geometryShader {
        append(&out.features, Feature_Name.Primitive_Index)
    }

    if props, props_ok := out.vk_features.shader_draw_parameters.?; props_ok {
        if props.shaderDrawParameters {
            append(&out.features, Feature_Name.Shader_Draw_Index)
        }
    }

    if props, props_ok := out.vk_features.shader_atomic_int64.?; props_ok {
        if props.shaderBufferInt64Atomics && props.shaderSharedInt64Atomics {
            append(&out.features, Feature_Name.Shader_Int64_Atomic_All_Ops)
            append(&out.features, Feature_Name.Shader_Int64_Atomic_Min_Max)
        }
    }

    if props, props_ok := out.vk_features.shader_image_atomic_int64.?; props_ok {
        if props.shaderImageInt64Atomics {
            append(&out.features, Feature_Name.Texture_Int64_Atomic)
        }
    }

    if props, props_ok := out.vk_features.shader_atomic_float.?; props_ok {
        if props.shaderBufferFloat32Atomics && props.shaderBufferFloat32AtomicAdd {
            append(&out.features, Feature_Name.Shader_Float32_Atomic)
        }
    }

    if props, props_ok := out.vk_features.shader_barycentrics.?; props_ok {
        if props.fragmentShaderBarycentric {
            append(&out.features, Feature_Name.Shader_Barycentrics)
            append(&out.features, Feature_Name.Shader_Per_Vertex)
        }
    }

    if vk_has_extension(out.vk_properties.extensions, vk.KHR_DRAW_INDIRECT_COUNT_EXTENSION_NAME) {
        append(&out.features, Feature_Name.Multi_Draw_Indirect_Count)
    }

    if vk_has_extension(
        out.vk_properties.extensions,
        vk.EXT_CONSERVATIVE_RASTERIZATION_EXTENSION_NAME,
    ) {
        append(&out.features, Feature_Name.Conservative_Rasterization)
    }

    if props, props_ok := out.vk_features.descriptor_indexing.?; props_ok {
        // We use update-after-bind descriptors for all bind groups containing
        // binding arrays.
        //
        // In those bind groups, we allow all binding types except uniform
        // buffers to be present.
        //
        // As we can only switch between update-after-bind and not on a per bind
        // group basis, all supported binding types need to be able to be marked
        // update after bind.
        //
        // As such, we enable all features as a whole, rather individually.
        supports_descriptor_indexing :=
            props.shaderSampledImageArrayNonUniformIndexing &&
            props.descriptorBindingSampledImageUpdateAfterBind &&// Sampled Images
            props.shaderStorageImageArrayNonUniformIndexing &&
            props.descriptorBindingStorageImageUpdateAfterBind &&// Storage Images
            props.shaderStorageBufferArrayNonUniformIndexing &&
            props.descriptorBindingStorageBufferUpdateAfterBind// Storage Buffers

        if supports_descriptor_indexing {
            append(&out.features, Feature_Name.Buffer_Binding_Array)
            append(&out.features, Feature_Name.Texture_Binding_Array)
            append(&out.features, Feature_Name.Storage_Resource_Binding_Array)
            append(
                &out.features,
                Feature_Name.Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
            )
            append(&out.features, Feature_Name.Storage_Texture_Array_Non_Uniform_Indexing)
        }

        if props.descriptorBindingPartiallyBound {
            append(&out.features, Feature_Name.Partially_Bound_Binding_Array)
        }
    }

    if out.vk_features.depthClamp {
        append(&out.features, Feature_Name.Depth_Clip_Control)
    }
    if out.vk_features.dualSrcBlend {
        append(&out.features, Feature_Name.Dual_Source_Blending)
    }
    if out.vk_features.shaderClipDistance {
        append(&out.features, Feature_Name.Clip_Distances)
    }

    if props, props_ok := out.vk_features.multiview.?; props_ok {
        if props.multiview {
            append(&out.features, Feature_Name.Multiview)
            append(&out.features, Feature_Name.Selective_Multiview)
        }
    }

    if props, props_ok := out.vk_features.portability_subset.?; props_ok {
        if props.multisampleArrayImage {
            append(&out.features, Feature_Name.Multisample_Array)
        }
    } else {
        append(&out.features, Feature_Name.Multisample_Array)
    }

    if vk_is_format_16bit_norm_supported(pd) {
        append(&out.features, Feature_Name.Texture_Format_16Bit_Norm)
    }

    if props, props_ok := out.vk_features.astc_hdr.?; props_ok {
        if props.textureCompressionASTC_HDR {
            append(&out.features, Feature_Name.Texture_Compression_Astc_Hdr)
        }
    }

    if out.vk_features.textureCompressionASTC_LDR {
        if vk_supports_astc_3d(pd) {
            append(&out.features, Feature_Name.Texture_Compression_ASTC_Sliced_3D)
        }
    }

    if vk_is_float32_filterable(pd) {
        append(&out.features, Feature_Name.Float32_Filterable)
    }
    if vk_is_float32_blendable(pd) {
        append(&out.features, Feature_Name.Float32_Blendable)
    }

    if vk_supports_format(pd, .B10G11R11_UFLOAT_PACK32, .OPTIMAL, {
        .COLOR_ATTACHMENT,
        .COLOR_ATTACHMENT_BLEND,
    }) {
        append(&out.features, Feature_Name.RG11B10_Ufloat_Renderable)
    }

    if vk_supports_bgra8_unorm_storage(pd, api_version) {
        append(&out.features, Feature_Name.BGRA8_Unorm_Storage)
    }

    planar_features := vk.FormatFeatureFlags {
            .SAMPLED_IMAGE,
            .TRANSFER_SRC,
            .TRANSFER_DST,
        }
    if vk_supports_format(pd, .G8_B8R8_2PLANE_420_UNORM, .OPTIMAL, planar_features) {
        append(&out.features, Feature_Name.Texture_Format_Nv12)
    }
    if vk_supports_format(
        pd,
        .G10X6_B10X6R10X6_2PLANE_420_UNORM_3PACK16,
        .OPTIMAL,
        planar_features,
    ) {
        append(&out.features, Feature_Name.Texture_Format_P010)
    }

    if props, props_ok := out.vk_properties.subgroup.?; props_ok {
        supports_subgroup_size_control :=
            api_version >= vk.API_VERSION_1_3 ||
            vk_has_extension(
                out.vk_properties.extensions,
                vk.EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME,
            )
        if supports_subgroup_size_control {
            required_operations := vk.SubgroupFeatureFlags {
                    .BASIC,
                    .VOTE,
                    .ARITHMETIC,
                    .BALLOT,
                    .SHUFFLE,
                    .SHUFFLE_RELATIVE,
                    .QUAD,
                }
            if props.supportedOperations & required_operations == required_operations {
                required_stages := vk.ShaderStageFlags{.COMPUTE, .FRAGMENT}
                if props.supportedStages & required_stages == required_stages {
                    append(&out.features, Feature_Name.Subgroup)
                    append(&out.features, Feature_Name.Subgroup_Barrier)
                }
                if .VERTEX in props.supportedStages {
                    append(&out.features, Feature_Name.Subgroup_Vertex)
                }
            }
        }
    }

    supports_acceleration_structure :=
        vk_has_extension(
            out.vk_properties.extensions,
            vk.KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
        ) &&
        vk_has_extension(
            out.vk_properties.extensions,
            vk.KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
        ) &&
        vk_has_extension(out.vk_properties.extensions, vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME)
    supports_ray_query :=
        supports_acceleration_structure &&
        vk_has_extension(out.vk_properties.extensions, vk.KHR_RAY_QUERY_EXTENSION_NAME)
    if supports_ray_query {
        append(&out.features, Feature_Name.Ray_Query)
        if props, props_ok := out.vk_features.acceleration_structure.?; props_ok {
            if props.descriptorBindingAccelerationStructureUpdateAfterBind {
                append(&out.features, Feature_Name.Acceleration_Structure_Binding_Array)
            }
        }
    }

    supports_ray_tracing_pipelines :=
        supports_acceleration_structure &&
        vk_has_extension(out.vk_properties.extensions, vk.KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME)
    if supports_ray_query || supports_ray_tracing_pipelines {
        append(&out.features, Feature_Name.Extended_Acceleration_Structure_Vertex_Formats)
    }
    if supports_ray_tracing_pipelines {
        append(&out.features, Feature_Name.Ray_Tracing_Pipelines)
    }
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_RAY_TRACING_POSITION_FETCH_EXTENSION_NAME,
    ) {
        append(&out.features, Feature_Name.Ray_Hit_Vertex_Return)
    }

    if vk_has_extension(out.vk_properties.extensions, vk.EXT_MESH_SHADER_EXTENSION_NAME) {
        append(&out.features, Feature_Name.Mesh_Shader)
        append(&out.features, Feature_Name.Mesh_Shader_Points)
        if props, props_ok := out.vk_features.mesh_shader.?; props_ok {
            if props.multiviewMeshShader {
                append(&out.features, Feature_Name.Mesh_Shader_Multiview)
            }
        }
    }

    if vk_has_extension(out.vk_properties.extensions, vk.KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME) {
        append(&out.features, Feature_Name.Vulkan_External_Memory_Fd)
    }
    if vk_has_extension(
        out.vk_properties.extensions,
        vk.KHR_EXTERNAL_MEMORY_WIN32_EXTENSION_NAME,
    ) {
        append(&out.features, Feature_Name.Vulkan_External_Memory_Win32)
    }
    if vk_has_extension(
           out.vk_properties.extensions,
           vk.EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME,
       ) &&
       vk_has_extension(
           out.vk_properties.extensions,
           vk.EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
       ) {
        append(&out.features, Feature_Name.Vulkan_External_Memory_Dma_Buf)
    }
    if vk_has_extension(out.vk_properties.extensions, vk.GOOGLE_DISPLAY_TIMING_EXTENSION_NAME) {
        append(&out.features, Feature_Name.Vulkan_Google_Display_Timing)
    }

    if props, props_ok := out.vk_features.cooperative_matrix.?; props_ok {
        if props.cooperativeMatrix {
            if memory_model, memory_model_ok := out.vk_features.vulkan_memory_model.?;
               memory_model_ok {
                if memory_model.vulkanMemoryModel && memory_model.vulkanMemoryModelDeviceScope {
                    count: u32
                    if vk.GetPhysicalDeviceCooperativeMatrixPropertiesKHR != nil &&
                       vk.GetPhysicalDeviceCooperativeMatrixPropertiesKHR(pd, &count, nil) ==
                           .SUCCESS &&
                       count > 0 {
                        append(&out.features, Feature_Name.Cooperative_Matrix)
                    }
                }
            }
        }
    }
    vk_supports_depth_format :: proc "contextless" (
        pd: vk.PhysicalDevice,
        format: vk.Format,
    ) -> bool {
        return vk_supports_format(pd, format, .OPTIMAL, {
            .SAMPLED_IMAGE,
            .DEPTH_STENCIL_ATTACHMENT,
        })
    }

    texture_s8 := vk_supports_depth_format(pd, .S8_UINT)
    texture_d32 := vk_supports_depth_format(pd, .D32_SFLOAT)
    texture_d24_s8 := vk_supports_depth_format(pd, .D24_UNORM_S8_UINT)
    texture_d32_s8 := vk_supports_depth_format(pd, .D32_SFLOAT_S8_UINT)

    stencil8 := texture_s8 || texture_d24_s8
    depth24_plus_stencil8 := texture_d24_s8 || texture_d32_s8

    if stencil8 && depth24_plus_stencil8 && texture_d32 {
        out.dl_features |= {.Webgpu_Texture_Format_Support}
    }

    if texture_d32_s8 {
        append(&out.features, Feature_Name.Depth32_Float_Stencil8)
    }

    // Ray tracing pipelines, mesh shaders, external memory and display timing
    // have no public `Feature_Name` entries yet, so they are not advertised.

    slice.sort(out.features[:])

    if driver, props_ok := out.vk_properties.driver.?; props_ok {
        // LLVMpipe requires native F16 support for F16_IN_F32 to work correctly.
        if driver.driverID == .MESA_LLVMPIPE && has_features(out.features[:], {.Shader_F16}) {
            out.dl_features -= {.Shader_F16_In_F32}
        }
    }

    if has_features(out.features[:], {.Texture_Compression_BC}) ||
       has_features(out.features[:], {.Texture_Compression_ETC2, .Texture_Compression_ASTC}) {
        out.dl_features |= {.Texture_Compression}
    }

    has_robust_buffer_access2: bool
    if props, props_ok := out.vk_features.robustness2.?; props_ok {
        has_robust_buffer_access2 = bool(props.robustBufferAccess2)
    }

    // Get memory properties
    vk.GetPhysicalDeviceMemoryProperties(pd, &out.vk_mem_properties)

    memory_types := out.vk_mem_properties.memoryTypes[:out.vk_mem_properties.memoryTypeCount]
    supports_lazily_allocated: bool
    for &mem in memory_types {
        if .LAZILY_ALLOCATED in mem.propertyFlags {
            supports_lazily_allocated = true
            break
        }
    }

    // The set of property flag bits the allocator logic actually handles.
    out.known_memory_flags = {
            .DEVICE_LOCAL,
            .HOST_VISIBLE,
            .HOST_COHERENT,
            .HOST_CACHED,
            .LAZILY_ALLOCATED,
        }

    device_type: Device_Type
    switch out.vk_properties.deviceType {
    case .OTHER:
        device_type = .Unknown
    case .INTEGRATED_GPU:
        device_type = .Integrated_Gpu
    case .DISCRETE_GPU:
        device_type = .Discrete_Gpu
    case .VIRTUAL_GPU:
        device_type = .Virtual_Gpu
    case .CPU:
        device_type = .Cpu
    }

    out.caps.image_view_usage =
        api_version >= vk.API_VERSION_1_1 ||
        vk_has_extension(out.vk_properties.extensions, vk.KHR_MAINTENANCE_2_EXTENSION_NAME)

    if props, props_ok := out.vk_features.timeline_semaphore.?; props_ok {
        out.caps.timeline_semaphores = bool(props.timelineSemaphore)
    }

    out.caps.texture_d24 = vk_supports_depth_format(pd, .X8_D24_UNORM_PACK32)
    out.caps.texture_d24_s8 = vk_supports_depth_format(pd, .D24_UNORM_S8_UINT)
    out.caps.texture_s8 = vk_supports_depth_format(pd, .S8_UINT)
    out.caps.multi_draw_indirect = bool(out.vk_features.multiDrawIndirect)
    out.caps.max_draw_indirect_count = out.vk_properties.limits.maxDrawIndirectCount
    out.caps.non_coherent_map_mask = u64(out.vk_properties.limits.nonCoherentAtomSize - 1)
    out.caps.can_present = true
    out.caps.robust_buffer_access = bool(out.vk_features.robustBufferAccess)

    if props1, props1_ok := out.vk_features.robustness2.?; props1_ok {
        out.caps.robust_image_access = bool(props1.robustImageAccess2)
        out.caps.robust_image_access2 = out.caps.robust_image_access
    } else if props2, props2_ok := out.vk_features.image_robustness.?; props2_ok {
        out.caps.robust_image_access = bool(props2.robustImageAccess)
    }

    out.caps.robust_buffer_access2 = has_robust_buffer_access2

    if props, props_ok := out.vk_features.zero_initialize_workgroup_memory.?; props_ok {
        out.caps.zero_initialize_workgroup_memory = bool(props.shaderZeroInitializeWorkgroupMemory)
    }

    out.caps.image_format_list =
        api_version >= vk.API_VERSION_1_2 ||
        vk_has_extension(out.vk_properties.extensions, vk.KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME)

    out.caps.maximum_samplers = out.vk_properties.limits.maxSamplerAllocationCount

    if props, props_ok := out.vk_features.shader_integer_dot_product.?; props_ok {
        out.caps.shader_integer_dot_product = bool(props.shaderIntegerDotProduct)
    }

    if props, props_ok := out.vk_features.shader_float16_int8.?; props_ok {
        out.caps.shader_int8 = bool(props.shaderInt8)
    }

    if props, props_ok := out.vk_properties.multiview.?; props_ok {
        out.caps.multiview_instance_index_limit = props.maxMultiviewInstanceIndex
    }

    out.caps.store_op_none =
        api_version >= vk.API_VERSION_1_3 ||
        (api_version >= vk.API_VERSION_1_2 &&
                vk_has_extension(
                    out.vk_properties.extensions,
                    vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
                )) ||
        vk_has_extension(out.vk_properties.extensions, vk.KHR_LOAD_STORE_OP_NONE_EXTENSION_NAME) ||
        vk_has_extension(
            out.vk_properties.extensions,
            vk.QCOM_RENDER_PASS_STORE_OPS_EXTENSION_NAME,
        ) ||
        vk_has_extension(out.vk_properties.extensions, vk.EXT_LOAD_STORE_OP_NONE_EXTENSION_NAME)

    vk_limits := out.vk_properties.limits

    max_memory_allocation_size := max(u64)
    if props, props_ok := out.vk_properties.maintenance3.?; props_ok {
        max_memory_allocation_size = u64(props.maxMemoryAllocationSize)
    }

    max_buffer_size := max(u64)
    if props, props_ok := out.vk_properties.maintenance4.?; props_ok {
        max_buffer_size = u64(props.maxBufferSize)
    }

    max_buffer_size = min(max_buffer_size, max_memory_allocation_size)

    // On Linux non-NVIDIA drivers, there's a known issue where very large buffer
    // // sizes (>2GB) can cause problems, so we limit it to max(i32). NVIDIA drivers
    // // and other platforms can handle the full size.
    max_buffer_size_cap: u64 = 1 << 52
    when ODIN_OS == .Linux {
        if out.vk_properties.vendorID != VENDOR_NVIDIA {
            max_buffer_size_cap = u64(max(i32))
        }
    }
    max_buffer_size = min(max_buffer_size, max_buffer_size_cap)

    max_binding_array_elements: u32
    max_sampler_binding_array_elements: u32

    if props, props_ok := out.vk_properties.descriptor_indexing.?; props_ok {
        max_binding_array_elements = min(
            props.maxDescriptorSetUpdateAfterBindSampledImages,
            props.maxDescriptorSetUpdateAfterBindStorageImages,
            props.maxDescriptorSetUpdateAfterBindStorageBuffers,
            props.maxPerStageDescriptorUpdateAfterBindSampledImages,
            props.maxPerStageDescriptorUpdateAfterBindStorageImages,
            props.maxPerStageDescriptorUpdateAfterBindStorageBuffers,
        )

        max_sampler_binding_array_elements = min(
            props.maxDescriptorSetUpdateAfterBindSamplers,
            props.maxPerStageDescriptorUpdateAfterBindSamplers,
        )
    }

    max_per_set: u32 = 256
    if maintenance3, has_m3 := out.vk_properties.maintenance3.?; has_m3 {
        max_per_set = maintenance3.maxPerSetDescriptors
    }

    portable_max_buffer_size := u64(1) << 52
    if maintenance4, has_m4 := out.vk_properties.maintenance4.?; has_m4 {
        portable_max_buffer_size = min(portable_max_buffer_size, u64(maintenance4.maxBufferSize))
    }
    if maintenance3, has_m3 := out.vk_properties.maintenance3.?; has_m3 {
        portable_max_buffer_size = min(
            portable_max_buffer_size,
            u64(maintenance3.maxMemoryAllocationSize),
        )
    }

    max_storage_textures := min(
        vk_limits.maxPerStageDescriptorStorageImages,
        vk_limits.maxDescriptorSetStorageImages / 2,
    )
    max_storage_buffers := min(
        vk_limits.maxPerStageDescriptorStorageBuffers,
        vk_limits.maxDescriptorSetStorageBuffers / 2,
    )
    max_colors := min(vk_limits.maxColorAttachments, vk_limits.maxFragmentOutputAttachments)
    max_sampled := min(
        vk_limits.maxPerStageDescriptorSampledImages,
        vk_limits.maxDescriptorSetSampledImages / 2,
    )
    max_uniforms := min(
        vk_limits.maxPerStageDescriptorUniformBuffers,
        vk_limits.maxDescriptorSetUniformBuffers / 2,
    )
    max_samplers := min(
        vk_limits.maxPerStageDescriptorSamplers,
        vk_limits.maxDescriptorSetSamplers / 2,
    )

    out.limits = {
        max_texture_dimension_1d                            = vk_limits.maxImageDimension1D,
        max_texture_dimension_2d                            = min(
            min(vk_limits.maxImageDimension2D, vk_limits.maxImageDimensionCube),
            min(vk_limits.maxFramebufferWidth, vk_limits.maxFramebufferHeight),
        ),
        max_texture_dimension_3d                            = vk_limits.maxImageDimension3D,
        max_texture_array_layers                            = vk_limits.maxImageArrayLayers,
        max_bind_groups                                     = vk_limits.maxBoundDescriptorSets,
        max_bind_groups_plus_vertex_buffers                 = max(
            u32(max(vk_limits.maxVertexInputBindings, 0)) + vk_limits.maxBoundDescriptorSets,
            vk_limits.maxBoundDescriptorSets,
        ),
        max_bindings_per_bind_group                         = max(1000, max_per_set),
        max_dynamic_uniform_buffers_per_pipeline_layout     = min(
            vk_limits.maxDescriptorSetUniformBuffersDynamic,
            max_uniforms,
        ),
        max_dynamic_storage_buffers_per_pipeline_layout     = min(
            vk_limits.maxDescriptorSetStorageBuffersDynamic,
            max_storage_buffers,
        ),
        max_sampled_textures_per_shader_stage               = max_sampled,
        max_samplers_per_shader_stage                       = max_samplers,
        max_storage_buffers_per_shader_stage                = max_storage_buffers,
        max_storage_textures_per_shader_stage               = max_storage_textures,
        max_uniform_buffers_per_shader_stage                = max_uniforms,
        max_uniform_buffer_binding_size                     = min(
            u64(vk_limits.maxUniformBufferRange),
            u64(0x7FFF_FFFF),
        ),
        max_storage_buffer_binding_size                     = min(
            u64(vk_limits.maxStorageBufferRange),
            u64(0x7FFF_FFFF),
        ) & ~u64(127),
        min_uniform_buffer_offset_alignment                 = u32(
            max(vk_limits.minUniformBufferOffsetAlignment, 32),
        ),
        min_storage_buffer_offset_alignment                 = u32(
            max(vk_limits.minStorageBufferOffsetAlignment, 32),
        ),
        max_vertex_buffers                                  = vk_limits.maxVertexInputBindings,
        max_buffer_size                                     = portable_max_buffer_size,
        max_vertex_attributes                               = vk_limits.maxVertexInputAttributes,
        max_vertex_buffer_array_stride                      = vk_limits.maxVertexInputBindingStride & ~u32(3),
        max_inter_stage_shader_variables                    = min(
            vk_limits.maxVertexOutputComponents,
            vk_limits.maxFragmentInputComponents,
        ) /
            4 - 1,
        max_color_attachments                               = max_colors,
        max_color_attachment_bytes_per_sample               = max_colors * 32,
        max_compute_workgroup_storage_size                  = vk_limits.maxComputeSharedMemorySize,
        max_compute_invocations_per_workgroup               = min(
            vk_limits.maxComputeWorkGroupInvocations,
            vk_limits.maxComputeWorkGroupSize[0] *
            vk_limits.maxComputeWorkGroupSize[1] *
            vk_limits.maxComputeWorkGroupSize[2],
        ),
        max_compute_workgroup_size_x                        = min(
            vk_limits.maxComputeWorkGroupSize[0],
            vk_limits.maxComputeWorkGroupInvocations,
        ),
        max_compute_workgroup_size_y                        = min(
            vk_limits.maxComputeWorkGroupSize[1],
            vk_limits.maxComputeWorkGroupInvocations,
        ),
        max_compute_workgroup_size_z                        = min(
            vk_limits.maxComputeWorkGroupSize[2],
            vk_limits.maxComputeWorkGroupInvocations,
        ),
        max_compute_workgroups_per_dimension                = min(
            min(vk_limits.maxComputeWorkGroupCount[0], vk_limits.maxComputeWorkGroupCount[1]),
            vk_limits.maxComputeWorkGroupCount[2],
        ),
        max_immediate_size                                  = min(
            vk_limits.maxPushConstantsSize,
            256,
        ),
        max_non_sampler_bindings                            = max(
            u32(1_000_000),
            max(1000, max_per_set),
        ),
        max_binding_array_elements_per_shader_stage         = max_binding_array_elements,
        max_binding_array_sampler_elements_per_shader_stage = max_sampler_binding_array_elements,
    }

    out.alignments = {
        buffer_copy_offset     = u64(vk_limits.optimalBufferCopyOffsetAlignment),
        buffer_copy_pitch      = u64(vk_limits.optimalBufferCopyRowPitchAlignment),
        raw_tlas_instance_size = 64,
    }

    if has_robust_buffer_access2 {
        if props, props_ok := out.vk_properties.robustness2.?; props_ok {
            out.alignments.uniform_bounds_check_alignment = u64(
                props.robustUniformBufferAccessSizeAlignment,
            )
        }
    } else {
        out.alignments.uniform_bounds_check_alignment = 1
    }

    add_ref(vk_instance_get_impl(instance, loc))
    return out, true
}

// Fill the feature structs a device is created with, from what the application
// requested and what the adapter actually supports: a feature is enabled only
// when it is both requested and available, and a struct that ends up nil is not
// chained.
vk_fill_device_features :: proc(
    out: ^VK_Physical_Device_Features,
    requested: []Feature_Name,
    probe: ^VK_Physical_Device_Features,
    loc := #caller_location,
) {
    pick :: #force_inline proc(wanted: bool, supported: b32) -> b32 {
        return wanted ? supported : b32(false)
    }

    // Core features.
    out.core.shaderInt16 = pick(has_features(requested, {.Shader_I16}), probe.core.shaderInt16)
    out.core.shaderInt64 = pick(has_features(requested, {.Shader_Int64}), probe.core.shaderInt64)
    out.core.shaderFloat64 = pick(has_features(requested, {.Shader_F64}), probe.core.shaderFloat64)
    out.core.shaderClipDistance = pick(
        has_features(requested, {.Clip_Distances}),
        probe.core.shaderClipDistance,
    )
    out.core.shaderCullDistance = pick(
        has_features(requested, {.Clip_Distances}),
        probe.core.shaderCullDistance,
    )
    out.core.dualSrcBlend = pick(
        has_features(requested, {.Dual_Source_Blending}),
        probe.core.dualSrcBlend,
    )
    out.core.geometryShader = pick(
        has_features(requested, {.Primitive_Index}),
        probe.core.geometryShader,
    )
    out.core.textureCompressionBC = pick(
        has_features(requested, {.Texture_Compression_BC}),
        probe.core.textureCompressionBC,
    )
    out.core.textureCompressionETC2 = pick(
        has_features(requested, {.Texture_Compression_ETC2}),
        probe.core.textureCompressionETC2,
    )
    out.core.textureCompressionASTC_LDR = pick(
        has_features(requested, {.Texture_Compression_ASTC}),
        probe.core.textureCompressionASTC_LDR,
    )
    out.core.drawIndirectFirstInstance = pick(
        has_features(requested, {.Indirect_First_Instance}),
        probe.core.drawIndirectFirstInstance,
    )
    out.core.pipelineStatisticsQuery = pick(
        has_features(requested, {.Pipeline_Statistics_Query}),
        probe.core.pipelineStatisticsQuery,
    )
    // Anisotropic sampling is a device feature, not a WebGPU one; every sampler
    // the API can describe is allowed to use it when the device has it.
    out.core.samplerAnisotropy = probe.core.samplerAnisotropy

    // VK_KHR_shader_float16_int8.
    if f, ok := probe.shader_float16_int8.?; ok {
        want_f16 := has_features(requested, {.Shader_F16})
        want_i16 := has_features(requested, {.Shader_I16})
        if (want_f16 && f.shaderFloat16) || (want_i16 && f.shaderInt8) {
            out.shader_float16_int8 = vk.PhysicalDeviceShaderFloat16Int8Features {
                sType         = .PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES,
                shaderFloat16 = pick(want_f16, f.shaderFloat16),
                shaderInt8    = pick(want_i16, f.shaderInt8),
            }
        }
    }

    // VK_KHR_16bit_storage, implied by the 16-bit shader feature.
    if f, ok := probe._16bit_storage.?; ok {
        if has_features(requested, {.Shader_F16}) || has_features(requested, {.Shader_I16}) {
            out._16bit_storage = vk.PhysicalDevice16BitStorageFeatures {
                sType                              = .PHYSICAL_DEVICE_16BIT_STORAGE_FEATURES,
                storageBuffer16BitAccess           = f.storageBuffer16BitAccess,
                uniformAndStorageBuffer16BitAccess = f.uniformAndStorageBuffer16BitAccess,
                storagePushConstant16              = f.storagePushConstant16,
                storageInputOutput16               = f.storageInputOutput16,
            }
        }
    }

    // VK_KHR_multiview.
    if f, ok := probe.multiview.?; ok {
        if has_features(requested, {.Multiview}) ||
           has_features(requested, {.Selective_Multiview}) {
            out.multiview = vk.PhysicalDeviceMultiviewFeaturesKHR {
                sType                       = .PHYSICAL_DEVICE_MULTIVIEW_FEATURES,
                multiview                   = f.multiview,
                multiviewGeometryShader     = f.multiviewGeometryShader,
                multiviewTessellationShader = f.multiviewTessellationShader,
            }
        }
    }

    // VK_EXT_texture_compression_astc_hdr.
    if f, ok := probe.astc_hdr.?; ok {
        if has_features(requested, {.Texture_Compression_Astc_Hdr}) &&
           f.textureCompressionASTC_HDR {
            out.astc_hdr = vk.PhysicalDeviceTextureCompressionASTCHDRFeaturesEXT {
                sType                      = .PHYSICAL_DEVICE_TEXTURE_COMPRESSION_ASTC_HDR_FEATURES_EXT,
                textureCompressionASTC_HDR = true,
            }
        }
    }

    // VK_KHR_shader_atomic_int64.
    if f, ok := probe.shader_atomic_int64.?; ok {
        if has_features(requested, {.Shader_Int64_Atomic_Min_Max}) ||
           has_features(requested, {.Shader_Int64_Atomic_All_Ops}) {
            out.shader_atomic_int64 = vk.PhysicalDeviceShaderAtomicInt64Features {
                sType                    = .PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES,
                shaderBufferInt64Atomics = f.shaderBufferInt64Atomics,
                shaderSharedInt64Atomics = f.shaderSharedInt64Atomics,
            }
        }
    }

    // VK_EXT_shader_image_atomic_int64.
    if f, ok := probe.shader_image_atomic_int64.?; ok {
        if has_features(requested, {.Texture_Int64_Atomic}) {
            out.shader_image_atomic_int64 = vk.PhysicalDeviceShaderImageAtomicInt64FeaturesEXT {
                sType                   = .PHYSICAL_DEVICE_SHADER_IMAGE_ATOMIC_INT64_FEATURES_EXT,
                shaderImageInt64Atomics = f.shaderImageInt64Atomics,
            }
        }
    }

    // VK_EXT_shader_atomic_float.
    if f, ok := probe.shader_atomic_float.?; ok {
        if has_features(requested, {.Shader_Float32_Atomic}) {
            out.shader_atomic_float = vk.PhysicalDeviceShaderAtomicFloatFeaturesEXT {
                sType                        = .PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_FEATURES_EXT,
                shaderBufferFloat32Atomics   = f.shaderBufferFloat32Atomics,
                shaderBufferFloat32AtomicAdd = f.shaderBufferFloat32AtomicAdd,
                shaderSharedFloat32Atomics   = f.shaderSharedFloat32Atomics,
                shaderSharedFloat32AtomicAdd = f.shaderSharedFloat32AtomicAdd,
                shaderImageFloat32Atomics    = f.shaderImageFloat32Atomics,
                shaderImageFloat32AtomicAdd  = f.shaderImageFloat32AtomicAdd,
            }
        }
    }

    // VK_KHR_fragment_shader_barycentric.
    if f, ok := probe.shader_barycentrics.?; ok {
        if has_features(requested, {.Shader_Barycentrics}) && f.fragmentShaderBarycentric {
            out.shader_barycentrics = vk.PhysicalDeviceFragmentShaderBarycentricFeaturesKHR {
                sType                     = .PHYSICAL_DEVICE_FRAGMENT_SHADER_BARYCENTRIC_FEATURES_KHR,
                fragmentShaderBarycentric = true,
            }
        }
    }

    // VK_EXT_subgroup_size_control.
    if f, ok := probe.subgroup_size_control.?; ok {
        if has_features(requested, {.Subgroup_Size_Control}) ||
           has_features(requested, {.Subgroup}) {
            out.subgroup_size_control = vk.PhysicalDeviceSubgroupSizeControlFeatures {
                sType                = .PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES,
                subgroupSizeControl  = f.subgroupSizeControl,
                computeFullSubgroups = f.computeFullSubgroups,
            }
        }
    }

    // VK_KHR_cooperative_matrix.
    if f, ok := probe.cooperative_matrix.?; ok {
        if has_features(requested, {.Cooperative_Matrix}) && f.cooperativeMatrix {
            out.cooperative_matrix = vk.PhysicalDeviceCooperativeMatrixFeaturesKHR {
                sType             = .PHYSICAL_DEVICE_COOPERATIVE_MATRIX_FEATURES_KHR,
                cooperativeMatrix = true,
            }
        }
    }

    // VK_KHR_maintenance4.
    if f, ok := probe.maintenance4.?; ok && f.maintenance4 {
        out.maintenance4 = vk.PhysicalDeviceMaintenance4FeaturesKHR {
            sType        = .PHYSICAL_DEVICE_MAINTENANCE_4_FEATURES,
            maintenance4 = true,
        }
    }

    // Acceleration structures and ray tracing. All three are required as a
    // set: a device that can build structures must also expose buffer
    // addresses.
    wants_ray_tracing :=
        has_features(requested, {.Ray_Query}) ||
        has_features(requested, {.Ray_Tracing_Pipelines}) ||
        has_features(requested, {.Ray_Hit_Vertex_Return}) ||
        has_features(requested, {.Extended_Acceleration_Structure_Vertex_Formats})
    if wants_ray_tracing {
        if f, ok := probe.acceleration_structure.?; ok && f.accelerationStructure {
            out.acceleration_structure = vk.PhysicalDeviceAccelerationStructureFeaturesKHR {
                sType                 = .PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR,
                accelerationStructure = true,
            }
        }
        if f, ok := probe.buffer_device_address.?; ok && f.bufferDeviceAddress {
            out.buffer_device_address = vk.PhysicalDeviceBufferDeviceAddressFeaturesKHR {
                sType               = .PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES_KHR,
                bufferDeviceAddress = true,
            }
        }
        if has_features(requested, {.Ray_Query}) {
            if f, ok := probe.ray_query.?; ok && f.rayQuery {
                out.ray_query = vk.PhysicalDeviceRayQueryFeaturesKHR {
                    sType    = .PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR,
                    rayQuery = true,
                }
            }
        }
        if has_features(requested, {.Ray_Tracing_Pipelines}) {
            if f, ok := probe.ray_tracing_pipeline.?; ok && f.rayTracingPipeline {
                out.ray_tracing_pipeline = vk.PhysicalDeviceRayTracingPipelineFeaturesKHR {
                    sType              = .PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR,
                    rayTracingPipeline = true,
                }
            }
        }
        if has_features(requested, {.Ray_Hit_Vertex_Return}) {
            if f, ok := probe.position_fetch.?; ok && f.rayTracingPositionFetch {
                out.position_fetch = vk.PhysicalDeviceRayTracingPositionFetchFeaturesKHR {
                    sType                   = .PHYSICAL_DEVICE_RAY_TRACING_POSITION_FETCH_FEATURES_KHR,
                    rayTracingPositionFetch = true,
                }
            }
        }
    }

    // Mesh shaders.
    if f, ok := probe.mesh_shader.?; ok {
        want_mesh := has_features(requested, {.Mesh_Shader})
        want_multiview := has_features(requested, {.Mesh_Shader_Multiview})
        if want_mesh || want_multiview {
            out.mesh_shader = vk.PhysicalDeviceMeshShaderFeaturesEXT {
                sType               = .PHYSICAL_DEVICE_MESH_SHADER_FEATURES_EXT,
                taskShader          = pick(want_mesh, f.taskShader),
                meshShader          = pick(want_mesh, f.meshShader),
                multiviewMeshShader = pick(want_multiview, f.multiviewMeshShader),
            }
        }
    }
}

vk_adapter_info_free_members :: proc(
    adapter_info: Adapter_Info,
    allocator := context.allocator,
    loc := #caller_location,
) {
    context.allocator = allocator
    delete(adapter_info.name)
    delete(adapter_info.device_pci_bus_id)
    delete(adapter_info.driver)
    delete(adapter_info.driver_info)
}

vk_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
    impl := vk_adapter_get_impl(adapter, loc)
    return impl.limits
}

vk_adapter_has_feature :: proc(
    adapter: Adapter,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    impl := vk_adapter_get_impl(adapter, loc)
    _, found := slice.binary_search(impl.features[:], feature)
    return found
}

vk_adapter_get_features :: proc(adapter: Adapter, loc := #caller_location) -> Features {
    impl := vk_adapter_get_impl(adapter, loc)
    return impl.features
}

vk_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
) {
    impl := vk_adapter_get_impl(adapter, loc)

    context.allocator = allocator

    props := impl.vk_properties.properties

    info.name = strings.clone(byte_arr_str(&props.deviceName))

    info.vendor = props.vendorID
    info.device = props.deviceID

    switch props.deviceType {
    case .OTHER:
        info.device_type = .Unknown
    case .INTEGRATED_GPU:
        info.device_type = .Integrated_Gpu
    case .DISCRETE_GPU:
        info.device_type = .Discrete_Gpu
    case .VIRTUAL_GPU:
        info.device_type = .Virtual_Gpu
    case .CPU:
        info.device_type = .Cpu
    }

    if props, props_ok := impl.vk_properties.pci_bus_info.?; props_ok {
        info.device_pci_bus_id = fmt.aprintf(
            "%04x:%02x:%02x.%d",
            props.pciDomain,
            props.pciBus,
            props.pciDevice,
            props.pciFunction,
        )
    }

    if props, props_ok := impl.vk_properties.driver.?; props_ok {
        info.driver = strings.clone(byte_arr_str(&props.driverName))
        info.driver_info = strings.clone(byte_arr_str(&props.driverInfo))
    }

    info.backend = .Vulkan

    if props, props_ok := impl.vk_properties.subgroup_size_control.?; props_ok {
        info.subgroup_min_size = props.minSubgroupSize
        info.subgroup_max_size = props.maxSubgroupSize
    }

    return
}

@(require_results)
vk_adapter_create_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device {
    // impl := vk_adapter_get_impl(adapter, loc)

    device, device_ok := vk_create_device(adapter, descriptor, loc)
    if !device_ok {
        log.error("VULKAN: Failed to create logical device")
        return {}
    }

    // Success
    return device
}

vk_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    impl := vk_adapter_get_impl(adapter, loc)
    add_ref(impl)
}

vk_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    impl := vk_adapter_get_impl(adapter, loc)
    return impl.label
}

vk_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
    impl := vk_adapter_get_impl(adapter, loc)
    if impl.label != "" {
        delete(impl.label, impl.allocator)
    }
    impl.label = ""
    if label != "" {
        impl.label = strings.clone(label, impl.allocator)
    }
}

vk_adapter_release_internal :: proc(impl: ^VK_Adapter_Impl, loc := #caller_location) {
    context.allocator = impl.allocator
    delete(impl.vk_properties.extensions)
    delete(impl.vk_queue_families)
    delete(impl.arena_buf)
    delete(impl.label)
    vk_instance_release(impl.instance)
}

vk_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    impl := vk_adapter_get_impl(adapter, loc)
    if release_ref(impl) {
        vk_adapter_release_internal(impl)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// VK_Adapter_Impl private procedures
// -----------------------------------------------------------------------------

vk_adapter_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> (
    caps: Texture_Format_Capabilities,
) {
    impl := vk_adapter_get_impl(adapter, loc)

    sync.guard(&impl.format_caps_mtx)
    if impl.format_caps_ready[format] {
        return impl.format_caps[format]
    }

    caps = vk_adapter_compute_format_capabilities(impl, format, loc)
    impl.format_caps[format] = caps
    impl.format_caps_ready[format] = true
    return
}

vk_adapter_compute_format_capabilities :: proc(
    impl: ^VK_Adapter_Impl,
    format: Texture_Format,
    loc := #caller_location,
) -> (
    caps: Texture_Format_Capabilities,
) {
    vk_format := vk_conv_to_format(impl.caps, format)

    properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(impl.vk_physical_device, vk_format, &properties)

    features := properties.optimalTilingFeatures

    if .SAMPLED_IMAGE in features {
        caps |= {.Sampled}
    }
    if .SAMPLED_IMAGE_FILTER_LINEAR in features {
        caps |= {.Sampled_Linear}
    }
    if .SAMPLED_IMAGE_FILTER_MINMAX in features {
        caps |= {.Sampled_Minmax}
    }
    if .STORAGE_IMAGE in features {
        caps |= {.Storage_Read_Write, .Storage_Write_Only, .Storage_Read_Only, .Storage_Atomic}
    }
    if .STORAGE_IMAGE_ATOMIC in features {
        caps |= {.Storage_Atomic}
    }
    if .COLOR_ATTACHMENT in features {
        caps |= {.Color_Attachment}
    }
    if .COLOR_ATTACHMENT_BLEND in features {
        caps |= {.Color_Attachment_Blend}
    }
    if .DEPTH_STENCIL_ATTACHMENT in features {
        caps |= {.Depth_Stencil_Attachment}
    }
    if .TRANSFER_SRC in features {
        caps |= {.Copy_Src}
    }
    if .TRANSFER_DST in features {
        caps |= {.Copy_Dst}
    }
    if .STORAGE_IMAGE_ATOMIC in features {
        caps |= {.Storage_Atomic}
    }

    // Vulkan is very permissive about MSAA
    if !texture_format_is_compressed(format, loc) {
        caps |= {.Multisample_Resolve}
    }

    // get the supported sample counts
    format_aspect := texture_format_aspects_from(format)
    limits := impl.vk_properties.limits

    sample_flags: vk.SampleCountFlags

    if .Depth in format_aspect {
        sample_flags = limits.framebufferDepthSampleCounts & limits.sampledImageDepthSampleCounts
    } else if .Stencil in format_aspect {
        sample_flags =
            limits.framebufferStencilSampleCounts & limits.sampledImageStencilSampleCounts
    } else {
        // Color or planar (YUV) formats: take the first aspect bit, We've
        // already excluded Depth/Stencil above, so this can only be Color,
        // Plane0, Plane1, or Plane2.
        first_aspect: Texture_Aspect
        switch {
        case .Color in format_aspect:
            first_aspect = .All
        case .Plane0 in format_aspect:
            first_aspect = .Plane0
        case .Plane1 in format_aspect:
            first_aspect = .Plane1
        case .Plane2 in format_aspect:
            first_aspect = .Plane2
        case:
            panic("Texture format has no recognized aspect", loc)
        }

        sample_type := texture_format_sample_type(format, first_aspect, {}, loc)

        #partial switch sample_type {
        case .Float, .Unfilterable_Float:
            sample_flags =
                limits.framebufferColorSampleCounts & limits.sampledImageColorSampleCounts
        case .Sint, .Uint:
            sample_flags = limits.sampledImageIntegerSampleCounts
        case:
            panic("Invalid texture sample type for multisample count query", loc)
        }
    }

    if ._2 in sample_flags {caps |= {.Multisample_X2}}
    if ._4 in sample_flags {caps |= {.Multisample_X4}}
    if ._8 in sample_flags {caps |= {.Multisample_X8}}
    if ._16 in sample_flags {caps |= {.Multisample_X16}}

    return
}
