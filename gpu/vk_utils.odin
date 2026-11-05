#+build !js
package gpu

// Core
import "core:fmt"
import "core:log"
import "core:slice"

// Vendor
import vk "vendor:vulkan"

// -----------------------------------------------------------------------------
// Misc
// -----------------------------------------------------------------------------

// Aborts on a Vulkan failure. Reserved for calls whose failure leaves the
// process with no coherent state to continue from; anything a caller can react
// to belongs in `vk_try`.
vk_check :: proc(result: vk.Result, loc := #caller_location) {
    if result != .SUCCESS {
        log.panicf("Vulkan API call failed: %v", result, location = loc)
    }
}

// Maps a Vulkan result onto the API's error taxonomy. `Error_Type.No_Error` is
// the zero value, which is what makes `vk_try` usable with `or_return`.
vk_result_to_error :: proc(result: vk.Result) -> Error_Type {
    #partial switch result {
    case .SUCCESS:
        return .No_Error
    case .ERROR_OUT_OF_HOST_MEMORY, .ERROR_OUT_OF_DEVICE_MEMORY:
        return .Out_Of_Memory
    case .ERROR_VALIDATION_FAILED:
        return .Validation
    }
    return .Internal
}

// Runs a Vulkan call, reports any failure through the device's error path (error
// scope, then uncaptured-error callback, then the log) and returns the error so
// the caller can propagate it:
//
//     vk_try(device, vk.CreateBuffer(...), "create buffer") or_return
//
// Device loss is fatal rather than returned: every later call on the device is
// meaningless, so trapping names the cause instead of failing one call at a time.
vk_try :: proc(
    device: Device,
    result: vk.Result,
    message: string,
    loc := #caller_location,
) -> (
    err: Error_Type,
) {
    if result == .SUCCESS {
        return .No_Error
    }
    if result == .ERROR_DEVICE_LOST {
        ensure(false, "Vulkan device lost", loc = loc)
    }
    err = vk_result_to_error(result)
    gpu_report_error(device, err, message, loc)
    return
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

vk_has_extension_property :: proc(props: []vk.ExtensionProperties, ext: string) -> bool {
    for &p in props {
        ext_name := byte_arr_str(&p.extensionName)
        if ext_name == ext {
            return true
        }
    }
    return false
}

@(require_results)
vk_has_extension_property_dyn :: proc(
    props: [dynamic]vk.ExtensionProperties,
    ext: string,
) -> bool {
    return #force_inline vk_has_extension_property(props[:], ext)
}

@(require_results)
vk_has_extension_name :: proc(extensions: []string, ext: string) -> (found: bool) {
    _, found = slice.binary_search(extensions[:], ext)
    return
}

vk_has_extension :: proc {
    vk_has_extension_property,
    vk_has_extension_property_dyn,
    vk_has_extension_name,
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

@(require_results)
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
        return features & properties.linearTilingFeatures == features
    case .OPTIMAL:
        return features & properties.optimalTilingFeatures == features
    case:
        return false
    }
}

@(require_results)
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

@(require_results)
vk_is_float32_filterable :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .R32_SFLOAT,
        .R32G32_SFLOAT,
        .R32G32B32A32_SFLOAT,
    }

    for vk_format in FORMATS {
        if !vk_supports_format(pd, vk_format, .OPTIMAL, {.SAMPLED_IMAGE_FILTER_LINEAR}) {
            return false
        }
    }

    return true
}

@(require_results)
vk_is_float32_blendable :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
    FORMATS :: []vk.Format {
        .R32_SFLOAT,
        .R32G32_SFLOAT,
        .R32G32B32A32_SFLOAT,
    }

    for vk_format in FORMATS {
        if !vk_supports_format(pd, vk_format, .OPTIMAL, {.COLOR_ATTACHMENT_BLEND}) {
            return false
        }
    }

    return true
}

@(require_results)
vk_supports_bgra8_unorm_storage :: proc "contextless" (
    pd: vk.PhysicalDevice,
    api_version: u32,
) -> bool {
    if api_version < vk.API_VERSION_1_3 || vk.GetPhysicalDeviceFormatProperties2 == nil {
        return false
    }

    properties3 := vk.FormatProperties3 {
        sType = .FORMAT_PROPERTIES_3,
    }
    properties2 := vk.FormatProperties2 {
        sType = .FORMAT_PROPERTIES_2,
        pNext = &properties3,
    }
    vk.GetPhysicalDeviceFormatProperties2(pd, .B8G8R8A8_UNORM, &properties2)

    features := properties2.formatProperties.optimalTilingFeatures
    return(
        .STORAGE_IMAGE in features &&
        .STORAGE_WRITE_WITHOUT_FORMAT in properties3.optimalTilingFeatures \
    )
}

@(require_results)
vk_supports_astc_3d :: proc "contextless" (pd: vk.PhysicalDevice) -> bool {
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
            pd,
            vk_format,
            .D3,
            .OPTIMAL,
            {.SAMPLED},
            {},
            &properties,
        )
        if res != .SUCCESS {
            return false
        }
    }

    return true
}

@(require_results)
vk_image_usage_flags_is_depth_attachment :: #force_inline proc "contextless" (
    self: vk.ImageUsageFlags,
) -> bool {
    return .DEPTH_STENCIL_ATTACHMENT in self
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

