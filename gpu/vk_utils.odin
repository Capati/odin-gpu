#+build !js
package gpu

// Core
import "core:fmt"
import "core:log"
import "core:slice"

// Vendor
import vk "vendor:vulkan"

// Misc
// Create utils
// Memory allocation/barrier
// Image layout transition

// -----------------------------------------------------------------------------
// Misc
// -----------------------------------------------------------------------------

vk_check :: proc(result: vk.Result, loc := #caller_location) {
    if result != .SUCCESS {
        log.panicf("Vulkan API call failed: %v", result, location = loc)
    }
}

vk_has_layer_property :: proc(props: []vk.LayerProperties, ext: string) -> bool {
    for &p in props {
        layer_name := byte_arr_str(&p.layerName)
        if layer_name == ext {
            return true
        }
    }
    return false
}

vk_has_layer_name :: proc(layers: []string, ext: string) -> bool {
    for layer_name in layers {
        if layer_name == ext {
            return true
        }
    }
    return false
}

vk_has_layer :: proc {
    vk_has_layer_property,
    vk_has_layer_name,
}

vk_has_extension_property :: proc(props: []vk.ExtensionProperties, ext: string) -> bool {
    for &p in props {
        ext_name := byte_arr_str(&p.extensionName)
        if ext_name == ext {
            return true
        }
    }
    return false
}

vk_has_extension_property_dyn :: proc(
    props: [dynamic]vk.ExtensionProperties,
    ext: string,
) -> bool {
    return #force_inline vk_has_extension_property(props[:], ext)
}

vk_has_extension_name :: proc(extensions: []string, ext: string) -> (found: bool) {
    _, found = slice.binary_search(extensions[:], ext)
    return
}

vk_has_extension_name_dyn :: proc(extensions: [dynamic]string, ext: string) -> (found: bool) {
    return #force_inline vk_has_extension_name(extensions[:], ext)
}

vk_has_extension :: proc {
    vk_has_extension_property,
    vk_has_extension_property_dyn,
    vk_has_extension_name,
    vk_has_extension_name_dyn,
}

// Finds the first queue which supports the desired operations.
//
// Returns `vk.QUEUE_FAMILY_IGNORED` if none is found.
vk_get_first_queue_index :: proc(
    families: []vk.QueueFamilyProperties,
    desired_flags: vk.QueueFlags,
) -> u32 {
    index := vk.QUEUE_FAMILY_IGNORED

    for f, queue_index in families {
        if (f.queueFlags & desired_flags) == desired_flags {
            return u32(queue_index)
        }
    }

    return index
}

// Finds the first queue which supports presenting.
//
// Returns `vk.QUEUE_FAMILY_IGNORED` if none is found.
vk_get_present_queue_index :: proc(
    families: []vk.QueueFamilyProperties,
    vk_physical_device: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
) -> u32 {
    if surface == 0 {return vk.QUEUE_FAMILY_IGNORED}
    for _, queue_index in families {
        present_support: b32
        if vk.GetPhysicalDeviceSurfaceSupportKHR(
               vk_physical_device,
               u32(queue_index),
               surface,
               &present_support,
           ) !=
           .SUCCESS {
            continue // skip bad query, don't give up entirely
        }
        if present_support {
            return u32(queue_index)
        }
    }
    return vk.QUEUE_FAMILY_IGNORED
}

vk_find_queue_family_index :: proc(
    families: []vk.QueueFamilyProperties,
    flags: vk.QueueFlags,
) -> (
    index: u32,
) {
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
        q := find_dedicated_queue_family_index(families, flags, {.GRAPHICS})
        if q != vk.QUEUE_FAMILY_IGNORED {
            return q
        }
    }

    // Try to find dedicated transfer queue: first prefer transfer-only
    // (no graphics, no compute), then relax to just "not graphics".
    if .TRANSFER in flags {
        q := find_dedicated_queue_family_index(families, flags, {.GRAPHICS, .COMPUTE})
        if q != vk.QUEUE_FAMILY_IGNORED {
            return q
        }
        q = find_dedicated_queue_family_index(families, flags, {.GRAPHICS})
        if q != vk.QUEUE_FAMILY_IGNORED {
            return q
        }
    }

    // Fall back to any suitable queue (no avoidance)
    return find_dedicated_queue_family_index(families, flags, {})
}

vk_utils_supports_format :: proc(
    pd: vk.PhysicalDevice,
    format: vk.Format,
    tiling: vk.ImageTiling,
    features: vk.FormatFeatureFlags,
) -> bool {
    properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(pd, format, &properties)
    #partial switch tiling {
    case .LINEAR:
        return features & properties.linearTilingFeatures != {}
    case .OPTIMAL:
        return features & properties.optimalTilingFeatures != {}
    case:
        return false
    }
    unreachable()
}

vk_setup_pnext_chain :: proc(
    structure: ^$T,
    structs: []^vk.BaseOutStructure,
    loc := #caller_location,
) {
    structure.pNext = nil
    if len(structs) == 0 {
        return
    }

    for i := 0; i < len(structs) - 1; i += 1 {
        when ODIN_DEBUG {
            assert(structs[i].sType != .APPLICATION_INFO, loc = loc)
        }
        structs[i].pNext = structs[i + 1]
    }

    when ODIN_DEBUG {
        assert(structs[len(structs) - 1].sType != .APPLICATION_INFO, loc = loc)
    }
    structs[len(structs) - 1].pNext = nil

    structure.pNext = structs[0]
}

vk_debug_callback :: proc "system" (
    messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
    messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
    pUserData: rawptr,
) -> b32 {
    instance_impl := cast(^VK_Instance_Impl)pUserData
    context = instance_impl.ctx

    // `log.Level` and `Log_Level` share the least-verbose-first ordering, so
    // both levels are derived from the same severity test.
    level: log.Level
    gpu_level: Log_Level
    if .ERROR in messageSeverity {
        level = .Error
        gpu_level = .Error
    } else if .WARNING in messageSeverity {
        level = .Warning
        gpu_level = .Warn
    } else if .INFO in messageSeverity {
        level = .Info
        gpu_level = .Info
    } else {
        // `.VERBOSE`, and anything added after this, lands here -- as it did
        // before a callback sink existed.
        level = .Debug
        gpu_level = .Debug
    }

    message := fmt.tprintf(
        "[%s] - %s\n%s",
        messageTypes,
        pCallbackData.pMessageIdName != nil ? pCallbackData.pMessageIdName : "(no id)",
        pCallbackData.pMessage != nil ? pCallbackData.pMessage : "(no message)",
    )

    // Installing a callback takes ownership of these messages: `g_log_level`
    // then decides which ones it receives, and nothing leaks through to `log.*`.
    // With no callback installed this is exactly the previous behaviour, so
    // `context.logger` remains the sole authority over `log.*` output.
    if g_log_callback != nil {
        if gpu_level <= g_log_level {
            g_log_callback(gpu_level, message, g_log_callback_userdata)
        }
    } else {
        log.logf(level, "%s", message)
    }

    return false
}

vk_supports_format :: proc "contextless" (
    pd: vk.PhysicalDevice,
    format: vk.Format,
    tiling: vk.ImageTiling,
    features: vk.FormatFeatureFlags,
) -> bool {
    properties: vk.FormatProperties
    vk.GetPhysicalDeviceFormatProperties(pd, format, &properties)
    #partial switch tiling {
    case .LINEAR:
        return features & properties.linearTilingFeatures != {}
    case .OPTIMAL:
        return features & properties.optimalTilingFeatures != {}
    case:
        return false
    }
}

is_float32_filterable_supported :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .R32_SFLOAT,
        .R32G32_SFLOAT,
        .R32G32B32A32_SFLOAT,
    }

    for vk_format in FORMATS {
        if (!vk_supports_format(pd, vk_format, .OPTIMAL, {.SAMPLED_IMAGE_FILTER_LINEAR})) {
            return false
        }
    }

    return true
}

vk_is_float32_blendable_supported :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .R32_SFLOAT,
        .R32G32_SFLOAT,
        .R32G32B32A32_SFLOAT,
    }

    for vk_format in FORMATS {
        if (!vk_supports_format(pd, vk_format, .OPTIMAL, {.COLOR_ATTACHMENT_BLEND})) {
            return false
        }
    }

    return true
}

vk_is_format_16bit_norm_supported :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .R16_UNORM,
        .R16_SNORM,
        .R16G16_UNORM,
        .R16G16_SNORM,
        .R16G16B16A16_UNORM,
        .R16G16B16A16_SNORM,
    }

    features := vk.FormatFeatureFlags {
        .SAMPLED_IMAGE,
        .STORAGE_IMAGE,
        .TRANSFER_SRC,
        .TRANSFER_DST,
    }

    for vk_format in FORMATS {
        if (!vk_supports_format(pd, vk_format, .OPTIMAL, features)) {
            return false
        }
    }

    return true
}

supports_astc_3d :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .ASTC_4x4_UNORM_BLOCK,
        .ASTC_4x4_SRGB_BLOCK,
        .ASTC_5x4_UNORM_BLOCK,
        .ASTC_5x4_SRGB_BLOCK,
        .ASTC_5x5_UNORM_BLOCK,
        .ASTC_5x5_SRGB_BLOCK,
        .ASTC_6x5_UNORM_BLOCK,
        .ASTC_6x5_SRGB_BLOCK,
        .ASTC_6x6_UNORM_BLOCK,
        .ASTC_6x6_SRGB_BLOCK,
        .ASTC_8x5_UNORM_BLOCK,
        .ASTC_8x5_SRGB_BLOCK,
        .ASTC_8x6_UNORM_BLOCK,
        .ASTC_8x6_SRGB_BLOCK,
        .ASTC_8x8_UNORM_BLOCK,
        .ASTC_8x8_SRGB_BLOCK,
        .ASTC_10x5_UNORM_BLOCK,
        .ASTC_10x5_SRGB_BLOCK,
        .ASTC_10x6_UNORM_BLOCK,
        .ASTC_10x6_SRGB_BLOCK,
        .ASTC_10x8_UNORM_BLOCK,
        .ASTC_10x8_SRGB_BLOCK,
        .ASTC_10x10_UNORM_BLOCK,
        .ASTC_10x10_SRGB_BLOCK,
        .ASTC_12x10_UNORM_BLOCK,
        .ASTC_12x10_SRGB_BLOCK,
        .ASTC_12x12_UNORM_BLOCK,
        .ASTC_12x12_SRGB_BLOCK,
    }

    for vk_format in FORMATS {
        properties: vk.ImageFormatProperties
        res := vk.GetPhysicalDeviceImageFormatProperties(
            pd, vk_format, .D3, .OPTIMAL, {.SAMPLED}, {}, &properties)
        if res != .SUCCESS {
            return false
        }
    }

    return true
}

// -----------------------------------------------------------------------------
// Create utils
// -----------------------------------------------------------------------------

@(disabled = !ODIN_DEBUG)
vk_utils_set_debug_object_name :: proc(
    device: VK_Device_VTable,
    type: vk.ObjectType,
    #any_int handle: vk.NonDispatchableHandle,
    name: string,
    loc := #caller_location,
) {
    if len(name) == 0 || device.fp.SetDebugUtilsObjectNameEXT == nil {
        return
    }

    name_buf: [256]byte
    ni := vk.DebugUtilsObjectNameInfoEXT {
        sType        = .DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
        objectType   = type,
        objectHandle = u64(handle),
        pObjectName  = clone_to_cstring_buf(name_buf[:], name, loc),
    }

    vk_check(device.fp.SetDebugUtilsObjectNameEXT(device.vk_device, &ni), loc = loc)
}

vk_utils_create_semaphore :: proc(
    device: VK_Device_VTable,
    debug_name: string,
    loc := #caller_location,
) -> (
    semaphore: vk.Semaphore,
) {
    ci := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
    }

    vk_check(device.fp.CreateSemaphore(device.vk_device, &ci, nil, &semaphore), loc = loc)
    vk_utils_set_debug_object_name(device, .SEMAPHORE, semaphore, debug_name, loc)

    return
}

vk_utils_create_semaphore_timeline :: proc(
    device: VK_Device_VTable,
    #any_int initial_value: u64,
    debug_name: string,
    loc := #caller_location,
) -> (
    semaphore: vk.Semaphore,
) {
    semaphore_type_create_info := vk.SemaphoreTypeCreateInfo {
        sType         = .SEMAPHORE_TYPE_CREATE_INFO,
        semaphoreType = .TIMELINE,
        initialValue  = initial_value,
    }

    ci := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
        pNext = &semaphore_type_create_info,
    }

    vk_check(device.fp.CreateSemaphore(device.vk_device, &ci, nil, &semaphore))
    vk_utils_set_debug_object_name(device, .SEMAPHORE, semaphore, debug_name, loc)

    return
}

vk_utils_create_fence :: proc(
    device: VK_Device_VTable,
    debug_name: string,
    signaled := false,
    loc := #caller_location,
) -> (
    fence: vk.Fence,
) {
    ci := vk.FenceCreateInfo {
        sType = .FENCE_CREATE_INFO,
        flags = signaled ? {.SIGNALED} : {},
    }

    vk_check(device.fp.CreateFence(device.vk_device, &ci, nil, &fence), loc = loc)
    vk_utils_set_debug_object_name(device, .FENCE, fence, debug_name, loc)

    return
}

// -----------------------------------------------------------------------------
// Memory allocation/barrier
// -----------------------------------------------------------------------------

vk_utils_find_memory_type :: proc(
    vk_physical_device: vk.PhysicalDevice,
    memory_type_bits: u32,
    flags: vk.MemoryPropertyFlags,
    loc := #caller_location,
) -> (
    index:      u32,
    mem_flags:  vk.MemoryPropertyFlags,
) {
    props: vk.PhysicalDeviceMemoryProperties
    vk.GetPhysicalDeviceMemoryProperties(vk_physical_device, &props)

    for i: u32 = 0; i < props.memoryTypeCount; i += 1 {
        has_properties := (props.memoryTypes[i].propertyFlags & flags) == flags
        if (memory_type_bits & (1 << i) != {}) && has_properties {
            return i, props.memoryTypes[i].propertyFlags
        }
    }

    assert(false, loc = loc)

    return {}, {}
}

vk_utils_allocate_memory :: proc(
    vk_physical_device: vk.PhysicalDevice,
    device: vk.Device,
    mem_requirements: ^vk.MemoryRequirements,
    props: vk.MemoryPropertyFlags,
    allocate_flags: vk.MemoryAllocateFlags,
    out_mem_flags: ^vk.MemoryPropertyFlags,
    out_memory: ^vk.DeviceMemory,
    loc := #caller_location,
) -> vk.Result {
    assert(mem_requirements != nil, loc = loc)

    memory_type_index, memory_type_flags := vk_utils_find_memory_type(
        vk_physical_device,
        mem_requirements.memoryTypeBits,
        props,
        loc,
    )

    ai := vk.MemoryAllocateInfo {
        sType           = .MEMORY_ALLOCATE_INFO,
        allocationSize  = mem_requirements.size,
        memoryTypeIndex = memory_type_index,
    }

    memory_allocate_flags_info := vk.MemoryAllocateFlagsInfo {
        sType = .MEMORY_ALLOCATE_FLAGS_INFO,
        flags = allocate_flags,
    }
    if allocate_flags != {} {
        ai.pNext = &memory_allocate_flags_info
    }

    result := vk.AllocateMemory(device, &ai, nil, out_memory)
    if result == .SUCCESS && out_mem_flags != nil {
        out_mem_flags^ = memory_type_flags
    }

    return result
}

vk_utils_is_coherent_memory :: #force_inline proc "contextless" (
    mem_props: vk.PhysicalDeviceMemoryProperties,
    memory_type_bits: u32,
) -> bool #no_bounds_check {
    for i in 0 ..< mem_props.memoryTypeCount {
        if memory_type_bits & (1 << i) != 0 {
            if .HOST_COHERENT in mem_props.memoryTypes[i].propertyFlags {
                return true
            }
        }
    }
    return false
}

vk_command_buffer_barrier :: proc "contextless" (
    device: ^VK_Device_Impl,
    command_buffer: vk.CommandBuffer,
    buffer: vk.Buffer,
    state_from: Buffer_Uses,
    state_to: Buffer_Uses,
    offset: vk.DeviceSize = 0,
    size: vk.DeviceSize = vk.DeviceSize(WHOLE_SIZE),
    loc := #caller_location,
) {
    src_stage, src_access := vk_conv_buffer_uses_to_barrier(state_from, device.queue_flags)
    dst_stage, dst_access := vk_conv_buffer_uses_to_barrier(state_to, device.queue_flags)

    // Note: this is done so that we never end up with empty stage flags
    if src_stage == {} {
        src_stage = {.TOP_OF_PIPE}
    }
    if dst_stage == {} {
        dst_stage = {.BOTTOM_OF_PIPE}
    }

    barrier := vk.BufferMemoryBarrier {
        sType               = .BUFFER_MEMORY_BARRIER,
        srcAccessMask       = src_access,
        dstAccessMask       = dst_access,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        buffer              = buffer,
        offset              = offset,
        size                = size,
    }

    device.fp.CmdPipelineBarrier(
        commandBuffer            = command_buffer,
        srcStageMask             = src_stage,
        dstStageMask             = dst_stage,
        dependencyFlags          = {},
        memoryBarrierCount       = 0,
        pMemoryBarriers          = nil,
        bufferMemoryBarrierCount = 1,
        pBufferMemoryBarriers    = &barrier,
        imageMemoryBarrierCount  = 0,
        pImageMemoryBarriers     = nil,
    )
}

// -----------------------------------------------------------------------------
// Image layout transition
// -----------------------------------------------------------------------------

vk_image_usage_flags_is_sampled :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .SAMPLED in self
}

vk_image_usage_flags_is_storage :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .STORAGE in self
}

vk_image_usage_flags_is_color_attachment :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .COLOR_ATTACHMENT in self
}

vk_image_usage_flags_is_depth_attachment :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .DEPTH_STENCIL_ATTACHMENT in self
}

vk_image_usage_flags_is_attachment :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .COLOR_ATTACHMENT in self || .DEPTH_STENCIL_ATTACHMENT in self
}

VK_Stage_Access :: struct {
    stage:  vk.PipelineStageFlags,
    access: vk.AccessFlags,
}

vk_image_layout_get_stage_access :: #force_inline proc "contextless" (
    layout: vk.ImageLayout,
    queue_flags: vk.QueueFlags,
    loc := #caller_location,
) -> VK_Stage_Access {
    shader_stages := vk_shader_stages(queue_flags)

    #partial switch layout {
    case .UNDEFINED:
        return {stage = {.TOP_OF_PIPE}, access = {}}
    case .COLOR_ATTACHMENT_OPTIMAL:
        return {
            stage = {.COLOR_ATTACHMENT_OUTPUT},
            access = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
        }
    case .DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .DEPTH_ATTACHMENT_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .DEPTH_STENCIL_READ_ONLY_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .SHADER_READ},
        }
    case .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {
                .DEPTH_STENCIL_ATTACHMENT_READ,
                .DEPTH_STENCIL_ATTACHMENT_WRITE,
                .SHADER_READ,
            },
        }
    case .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL:
        return {
            stage = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {
                .DEPTH_STENCIL_ATTACHMENT_READ,
                .DEPTH_STENCIL_ATTACHMENT_WRITE,
                .SHADER_READ,
            },
        }
    case .SHADER_READ_ONLY_OPTIMAL:
        return {
            stage = shader_stages,
            access = {.SHADER_READ},
        }
    case .TRANSFER_SRC_OPTIMAL:
        return {stage = {.TRANSFER}, access = {.TRANSFER_READ}}
    case .TRANSFER_DST_OPTIMAL:
        return {stage = {.TRANSFER}, access = {.TRANSFER_WRITE}}
    case .GENERAL:
        return {
            stage = {.COMPUTE_SHADER, .TRANSFER},
            access = {.SHADER_READ, .SHADER_WRITE, .TRANSFER_READ, .TRANSFER_WRITE},
        }
    case .PRESENT_SRC_KHR:
        return {stage = {.BOTTOM_OF_PIPE}, access = {}}
    case:
        panic_contextless("Unsupported image layout transition!", loc)
    }
}

vk_texture_transition_layout :: proc(
    device: ^VK_Device_Impl,
    texture: ^VK_Texture_Impl,
    vk_command_buffer: vk.CommandBuffer,
    state_from: Texture_Uses,
    state_to: Texture_Uses,
    subresource_range: vk.ImageSubresourceRange,
    loc := #caller_location,
) {
    // Both layouts come from the tracker states, so they are always specific
    // (`.ATTACHMENT_OPTIMAL` never appears) and never need normalizing.
    old_image_layout := vk_conv_texture_uses_to_image_layout(state_from, texture.format)
    new_image_layout := vk_conv_texture_uses_to_image_layout(state_to, texture.format)

    if old_image_layout == new_image_layout {
        return // no-op
    }

    is_depth_attachment := vk_image_usage_flags_is_depth_attachment(texture.vk_usage_flags)

    src := vk_image_layout_get_stage_access(old_image_layout, device.queue_flags)
    dst := vk_image_layout_get_stage_access(new_image_layout, device.queue_flags)

    if is_depth_attachment && texture.is_resolve_attachment {
        // https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#renderpass-resolve-operations
        src.stage |= {.COLOR_ATTACHMENT_OUTPUT}
        dst.stage |= {.COLOR_ATTACHMENT_OUTPUT}
        src.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
        dst.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }

    barrier := vk.ImageMemoryBarrier {
        sType               = .IMAGE_MEMORY_BARRIER,
        srcAccessMask       = src.access,
        dstAccessMask       = dst.access,
        oldLayout           = old_image_layout,
        newLayout           = new_image_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = texture.vk_image,
        subresourceRange    = subresource_range,
    }

    device.fp.CmdPipelineBarrier(
        commandBuffer            = vk_command_buffer,
        srcStageMask             = src.stage,
        dstStageMask             = dst.stage,
        dependencyFlags          = {},
        memoryBarrierCount       = 0,
        pMemoryBarriers          = nil,
        bufferMemoryBarrierCount = 0,
        pBufferMemoryBarriers    = nil,
        imageMemoryBarrierCount  = 1,
        pImageMemoryBarriers     = &barrier,
    )
}

vk_texture_barrier :: proc "contextless" (
    device: ^VK_Device_Impl,
    texture: ^VK_Texture_Impl,
    vk_command_buffer: vk.CommandBuffer,
    layout: vk.ImageLayout,
    subresource_range: vk.ImageSubresourceRange,
    loc := #caller_location,
) {
    is_depth_attachment := vk_image_usage_flags_is_depth_attachment(texture.vk_usage_flags)

    resolved_layout := layout
    if resolved_layout == .ATTACHMENT_OPTIMAL {
        resolved_layout = is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
    }

    stage_access := vk_image_layout_get_stage_access(resolved_layout, device.queue_flags)

    if is_depth_attachment && texture.is_resolve_attachment {
        stage_access.stage |= {.COLOR_ATTACHMENT_OUTPUT}
        stage_access.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }

    barrier := vk.ImageMemoryBarrier {
        sType               = .IMAGE_MEMORY_BARRIER,
        srcAccessMask       = stage_access.access,
        dstAccessMask       = stage_access.access,
        oldLayout           = resolved_layout,
        newLayout           = resolved_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = texture.vk_image,
        subresourceRange    = subresource_range,
    }

    vk.CmdPipelineBarrier(
        commandBuffer            = vk_command_buffer,
        srcStageMask             = stage_access.stage,
        dstStageMask             = stage_access.stage,
        dependencyFlags          = {},
        memoryBarrierCount       = 0,
        pMemoryBarriers          = nil,
        bufferMemoryBarrierCount = 0,
        pBufferMemoryBarriers    = nil,
        imageMemoryBarrierCount  = 1,
        pImageMemoryBarriers     = &barrier,
    )
}
