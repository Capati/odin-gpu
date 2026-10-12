#+build !js
package gpu

// Core
import "base:runtime"
import "core:slice"
import "core:sync"
import "core:time"

import intr "base:intrinsics"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_MAX_SWAPCHAIN_IMAGES :: 16
VK_MAX_ACQUIRE_SLOTS    :: VK_MAX_SWAPCHAIN_IMAGES

// One acquire slot per swapchain image, rotated each frame. `semaphore` is
// signaled by acquire and waited on by the next submit. Waiting `submit_wait`
// proves the old acquire retired, so no acquire fence is needed.
VK_Acquire_Slot :: struct {
    semaphore:   vk.Semaphore,
    submit_wait: VK_Submit_Handle,
}

VK_Surface_Impl :: struct {
    instance:             Instance,
    device:               Device,
    config:               Surface_Configuration,
    swapchain_textures:   [dynamic;VK_MAX_SWAPCHAIN_IMAGES]Texture,
    swapchain_views:      [dynamic;VK_MAX_SWAPCHAIN_IMAGES]Texture_View,
    acquire_slots:        [dynamic;VK_MAX_ACQUIRE_SLOTS]VK_Acquire_Slot,
    allocator:            runtime.Allocator,
    vk_swapchain:         vk.SwapchainKHR,
    vk_surface:           vk.SurfaceKHR,
    acquire_cursor:       u32,
    num_swapchain_images: u32,
    current_image_index:  u32,
    ref:                  Ref_Count_Type,
    get_next_image:       bool,
    // Windows-only acquire fence for DXGI pacing. Null elsewhere.
    acquire_fence:        vk.Fence,
    // Past presented submits, oldest first. Caps in-flight frames to latency.
    // Plain dynamic: length follows latency, freed on unconfigure/release.
    submit_history:       [dynamic]VK_Submit_Handle,
    // Per-image present pools. Grow-only; freed at release after idle.
    present_pools: [dynamic; VK_MAX_SWAPCHAIN_IMAGES]VK_Present_Pool,
    // Guards acquire/present/configure. Lock order: surface -> submit, never reverse.
    mtx:                  sync.Mutex,
    frame_cond:           sync.Cond,
}

// Present semaphores per image. `sems[0..count]` wait at the next present.
// Present collects the prefix and resets `count`, so reuse is safe by host
// order. (VUID-vkQueueSubmit-pSignalSemaphores-00067). Grow-only; freed at
// release after idle.
VK_Present_Pool :: struct {
    sems:  [dynamic]vk.Semaphore,
    count: u32,
}

// One acquire whose semaphore has been signaled but not yet waited on.
VK_Pending_Acquire :: struct {
    surface: Surface,
    image:   u32,
    sem:     vk.Semaphore,
}

// One swapchain image touched by a submission.
VK_Swapchain_Touch :: struct {
    surface: Surface,
    image:   u32,
}

VK_Swapchain_Touch_List :: [dynamic; VK_MAX_SWAPCHAIN_IMAGES]VK_Swapchain_Touch

// Lists images touched by `buf`. No locks held; surface lock never needed here.
// Output is bounded by VK_MAX_SWAPCHAIN_IMAGES; asserts loud on overflow
// (fixed-capacity appends drop silently past capacity).
vk_surface_scan_swapchain_touches :: proc(
    buf: ^VK_Command_Buffer_Impl,
    touches: ^VK_Swapchain_Touch_List,
    loc := #caller_location,
) {
    md := &buf.tracker.textures.metadata
    it := resource_metadata_indices(md)
    base := len(touches)
    found := 0
    for index in bit_vector_iterator_next(&it) {
        texture := md.resources[index]
        if texture == {} {
            continue
        }
        texture_impl := vk_texture_get_impl(texture, loc)
        if !texture_impl.is_swapchain {
            continue
        }
        found += 1
        append(touches, {
            surface = texture_impl.surface,
            image   = texture_impl.swapchain_index,
        })
    }
    assert(found == len(touches) - base)
}

// Records a pending acquire. Surface lock held; takes submitter lock.
vk_surface_arm_acquire :: proc(
    submitter: ^VK_Submit_Context,
    surface: Surface,
    image: u32,
    sem: vk.Semaphore,
    loc := #caller_location,
) {
    sync.guard(&submitter.mtx)
    append(&submitter.pending_acquires, VK_Pending_Acquire{
        surface = surface,
        image   = image,
        sem     = sem,
    })
}

// Takes the pending acquire for (surface, image). Holds `submitter.mtx`.
vk_surface_take_pending_locked :: proc(
    submitter: ^VK_Submit_Context,
    touch: VK_Swapchain_Touch,
    loc := #caller_location,
) -> (
    sem: vk.Semaphore,
    ok: bool,
) {
    for i in 0 ..< len(submitter.pending_acquires) {
        entry := &submitter.pending_acquires[i]
        if entry.surface == touch.surface && entry.image == touch.image {
            sem = entry.sem
            ordered_remove(&submitter.pending_acquires, i)
            return sem, true
        }
    }
    return {}, false
}

// Pooled signal semaphore for (surface, image). Holds `submitter.mtx`.
vk_surface_present_pool_alloc_locked :: proc(
    surface: Surface,
    image: u32,
    fp: VK_Device_VTable,
    loc := #caller_location,
) -> vk.Semaphore {
    impl := vk_surface_get_impl(surface, loc)
    assert(image < VK_MAX_SWAPCHAIN_IMAGES, loc = loc)
    // Grow-only; freed at release after idle.
    for u32(len(impl.present_pools)) <= image {
        append(&impl.present_pools, VK_Present_Pool{})
    }
    pool := &impl.present_pools[image]
    sem: vk.Semaphore
    if pool.count < u32(len(pool.sems)) {
        sem = pool.sems[pool.count]
    } else {
        sem = vk_utils_create_semaphore(fp, "Semaphore: swapchain-present", loc)
        append(&pool.sems, sem)
    }
    pool.count += 1
    return sem
}

// True if the image has queued signals. Shared lock; hint only.
vk_surface_present_pool_has_signals :: proc(
    impl: ^VK_Surface_Impl,
    submitter: ^VK_Submit_Context,
    image: u32,
) -> bool {
    sync.shared_guard(&submitter.mtx)
    return image < u32(len(impl.present_pools)) &&
        impl.present_pools[image].count > 0
}

// Presents this image's signals atomically under the submitter lock.
// (VUID-vkQueueSubmit-pSignalSemaphores-00067). Keeps the prefix on failure.
vk_surface_present_pool_queue_present :: proc(
    impl: ^VK_Surface_Impl,
    submitter: ^VK_Submit_Context,
    image: u32,
    present_info: ^vk.PresentInfoKHR,
    loc := #caller_location,
) -> (
    result: vk.Result,
    last_submit: VK_Submit_Handle,
) {
    device_impl := vk_device_get_impl(submitter.device, loc)
    sync.guard(&submitter.mtx)
    assert(image < u32(len(impl.present_pools)), loc = loc)
    pool := &impl.present_pools[image]
    assert(pool.count > 0, "present image has no queued signal semaphore", loc)

    // Safe to alias: lock held across present, count reset after.
    present_info.waitSemaphoreCount = u32(pool.count)
    present_info.pWaitSemaphores = raw_data(pool.sems[:pool.count])
    result = device_impl.fp.QueuePresentKHR(submitter.queue, present_info)

    last_submit = submitter.last_submit_handle
    if result == .SUCCESS || result == .SUBOPTIMAL_KHR {
        pool.count = 0
    }
    return
}

// Drops pending acquires at teardown. Takes submitter lock; may hold surface lock.
vk_surface_purge_pending :: proc(
    submitter: ^VK_Submit_Context,
    impl: ^VK_Surface_Impl,
    loc := #caller_location,
) {
    // Public handle is the impl pointer.
    surface := Surface(rawptr(impl))
    sync.guard(&submitter.mtx)
    for i := len(submitter.pending_acquires) - 1; i >= 0; i -= 1 {
        if submitter.pending_acquires[i].surface == surface {
            ordered_remove(&submitter.pending_acquires, i)
        }
    }
}

// Destroys pooled semaphores. Needs idle + surface lock; takes submitter lock.
// Pools persist across reconfigure; only destroyed here.
vk_surface_present_pools_destroy :: proc(
    impl: ^VK_Surface_Impl,
    device_impl: ^VK_Device_Impl,
    loc := #caller_location,
) {
    submitter := &device_impl.submitter
    sync.guard(&submitter.mtx)
    for &pool in impl.present_pools {
        for sem in pool.sems {
            device_impl.fp.DestroySemaphore(device_impl.vk_device, sem, nil)
        }
        delete(pool.sems)
        pool.sems = nil
        pool.count = 0
    }
}

// Slot used by the current frame; cursor already moved past it.
vk_surface_acquired_slot :: #force_inline proc "contextless" (
    impl: ^VK_Surface_Impl,
) -> u32 #no_bounds_check {
    return (impl.acquire_cursor + u32(len(impl.acquire_slots)) - 1) % u32(len(impl.acquire_slots))
}

VK_Surface_Texture_Handle :: distinct hm.Handle64

VK_Surface_Texture :: struct {
    using base: Surface_Texture,
    handle:     VK_Surface_Texture_Handle,
}

@(require_results)
vk_surface_get_impl :: #force_inline proc "contextless" (
    surface: Surface,
    loc := #caller_location,
) -> ^VK_Surface_Impl {
    assert_contextless(surface != nil, "invalid surface", loc)
    return cast(^VK_Surface_Impl)surface
}

vk_surface_configure :: proc(
    surface: Surface,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    assert(config.device != nil, "Invalid device", loc)
    // Zero size means minimized: keep the old swapchain, report Outdated next acquire.
    if config.width == 0 || config.height == 0 {
        return
    }

    impl := vk_surface_get_impl(surface, loc)
    sync.guard(&impl.mtx)
    // Abandons only when no presenter arrives.
    if !vk_surface_wait_for_present_timeout_locked(impl) {
        vk_surface_abandon_frame_locked(impl, loc)
    }
    device_impl := vk_device_get_impl(config.device, loc)
    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    surface_capabilities: vk.SurfaceCapabilitiesKHR
    vk_check(vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
        adapter_impl.vk_physical_device, impl.vk_surface, &surface_capabilities))

    find_extent :: proc(
        capabilities: vk.SurfaceCapabilitiesKHR,
        desired_width, desired_height: u32,
    ) -> vk.Extent2D {
        if capabilities.currentExtent.width != max(u32) {
            return capabilities.currentExtent
        }

        actual_extent: vk.Extent2D = {desired_width, desired_height}

        actual_extent.width  = clamp(
            actual_extent.width,
            capabilities.minImageExtent.width,
            capabilities.maxImageExtent.width)
        actual_extent.height = clamp(
            actual_extent.height,
            capabilities.minImageExtent.height,
            capabilities.maxImageExtent.height)

        return actual_extent
    }

    caps := vk_surface_fill_capabilities(
        surface, device_impl.adapter, surface_capabilities, ta, loc)
    assert(slice.contains(caps.formats, config.format), "VULKAN: Unsupported surface format", loc)

    // Image count is latency + 1, clamped to the surface range.
    image_count := max(
        intr.saturating_add(config.desired_maximum_frame_latency, 1),
        surface_capabilities.minImageCount,
    )

    if surface_capabilities.maxImageCount > 0 {
        image_count = min(image_count, surface_capabilities.maxImageCount)
    }

    image_format := vk_conv_to_format(adapter_impl.caps, config.format)
    image_color_space := vk_conv_to_color_space(config.color_space, loc)
    image_extent := find_extent(surface_capabilities, config.width, config.height)
    // Zero extent can't back a swapchain; keep old, report Outdated.
    if image_extent.width == 0 || image_extent.height == 0 {
        return
    }
    // Platform may force extent (Wayland/HiDPI); store actual size.
    impl.config = config
    impl.config.width = image_extent.width
    impl.config.height = image_extent.height
    image_usage := vk_conv_to_image_usage_flags(config.usage, config.format)
    composite_alpha := vk_conv_to_composite_alpha_flags(config.alpha_mode)
    present_mode := vk_conv_to_present_mode(config.present_mode)

    flags: vk.SwapchainCreateFlagsKHR

    if len(config.view_formats) > 0 {
        flags |= {.MUTABLE_FORMAT}
        // TODO
    }

    info := vk.SwapchainCreateInfoKHR{
        sType                 = .SWAPCHAIN_CREATE_INFO_KHR,
        pNext                 = nil,
        flags                 = flags,
        surface               = impl.vk_surface,
        minImageCount         = image_count,
        imageFormat           = image_format,
        imageColorSpace       = image_color_space,
        imageExtent           = image_extent,
        imageArrayLayers      = 1,
        imageUsage            = image_usage,
        imageSharingMode      = .EXCLUSIVE,
        queueFamilyIndexCount = {},
        pQueueFamilyIndices   = {},
        preTransform          = surface_capabilities.currentTransform,
        compositeAlpha        = composite_alpha,
        presentMode           = present_mode,
        clipped               = true,
        oldSwapchain          = {}, // assigned below
    }

    // Create-before-destroy: new swapchain first, teardown after.
    is_reconfigure := impl.vk_swapchain != {}
    if !is_reconfigure {
        // First configure pins the device for the surface lifetime.
        impl.device = config.device
        vk_device_add_ref(impl.device)
    } else {
        assert(impl.device == config.device, "surface reconfigure with different device", loc)
        info.oldSwapchain = impl.vk_swapchain
    }

    // Old wrappers stay alive across Create.
    new_swapchain: vk.SwapchainKHR
    vk_check(vk.CreateSwapchainKHR(device_impl.vk_device, &info, nil, &new_swapchain))
    if info.oldSwapchain != {} {
        old_swapchain := info.oldSwapchain
        impl.vk_swapchain = new_swapchain
        info.oldSwapchain = {}
        // Retire old-image work, purge stale acquires, then destroy old
        // wrappers. Present semaphores survive: host order keeps reuse valid
        // across swapchains.
        vk_surface_purge_pending(&device_impl.submitter, impl, loc)
        vk_swapchain_destroy_resources(impl, loc)
        device_impl.fp.DestroySwapchainKHR(device_impl.vk_device, old_swapchain, nil)
    } else {
        impl.vk_swapchain = new_swapchain
    }

    get_images :: proc(
        device: vk.Device,
        swapchain: vk.SwapchainKHR,
    ) -> (
        images: []vk.Image,
    ) {
        // Clamped to what we can represent.
        image_count: u32 = 0
        vk_check(vk.GetSwapchainImagesKHR(device, swapchain, &image_count, nil))
        image_count = min(image_count, VK_MAX_SWAPCHAIN_IMAGES)

        images = make([]vk.Image, image_count, context.temp_allocator)

        vk_check(vk.GetSwapchainImagesKHR(device, swapchain, &image_count, raw_data(images)))

        return
    }

    // Swapchain images and per-image wrappers.
    swapchain_images := get_images(device_impl.vk_device, impl.vk_swapchain)
    impl.num_swapchain_images = u32(len(swapchain_images))
    assert(impl.num_swapchain_images > 0, loc = loc)

    for vk_image, image_index in swapchain_images {
        texture_impl, texture_handle := add_impl(&device_impl.textures, VK_Texture_Impl{
            usage              = config.usage,
            dimension          = .D2,
            size               = {image_extent.width, image_extent.height, 1},
            format             = config.format,
            mip_level_count    = 1,
            sample_count       = 1,
            vk_extent          = {image_extent.width, image_extent.height, 1},
            device             = config.device,
            surface            = surface,
            vk_image           = vk_image,
            vk_usage_flags     = image_usage,
            vk_type            = .D2,
            vk_image_format    = image_format,
            vk_samples         = {._1},
            num_levels         = 1,
            num_layers         = 1,
            is_owning_vk_image = true,
            is_swapchain       = true,
            swapchain_index    = u32(image_index),
        })

        texture := new_handle(Texture, config.device, texture_handle)

        texture_impl.tracker_index = shared_tracker_index_allocator_alloc(
            &device_impl.tracker_indices.textures)
        texture_impl.full_range = Texture_Selector{
            mips   = Range(u32){0, 1},
            layers = Range(u32){0, 1},
        }

        device_texture_tracker_insert_single(
            &device_impl.trackers.textures,
            texture_impl.tracker_index,
            texture,
            {.Uninitialized},
            loc)

        vk_image_view := vk_texture_create_image_view(texture_impl,
            type        = .D2,
            format      = image_format,
            aspect_mask = {.COLOR},
            base_level  = 0,
        )

        _, texture_view_handle := add_impl(&device_impl.texture_views, VK_Texture_View_Impl {
            device            = config.device,
            texture           = texture,
            vk_image_view     = vk_image_view,
            format            = config.format,
            dimension         = .D2,
            aspect            = .All,
            // Mip 0, layer 0.
            selector = {
                mips ={ 0, 1 },
                layers ={ 0, 1 },
            },
            is_owning_vk_view = true,
            is_swapchain      = true,
        })

        texture_view := new_handle(Texture_View, config.device, texture_view_handle)
        texture_impl.texture_view = texture_view

        append(&impl.swapchain_textures, texture)
        append(&impl.swapchain_views, texture_view)
    }

    // One slot per image; more would let the CPU run ahead and miss vsync.
    num_acquire_slots := min(impl.num_swapchain_images, VK_MAX_ACQUIRE_SLOTS)
    for _ in 0 ..< num_acquire_slots {
        append(&impl.acquire_slots, VK_Acquire_Slot{
            semaphore = vk_utils_create_semaphore(
                device_impl.fp, "Semaphore: swapchain-acquire", loc),
        })
    }

    // Windows-only acquire fence for DXGI pacing.
    when ODIN_OS == .Windows {
        impl.acquire_fence = vk_utils_create_fence(
            device_impl.fp, "Fence: swapchain-acquire", loc = loc)
    }

    impl.acquire_cursor = 0
    impl.get_next_image = true
}

// Fetches capabilities once; configure reuses the result.
vk_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    impl := vk_surface_get_impl(surface, loc)
    adapter_impl := vk_adapter_get_impl(adapter, loc)

    surface_caps: vk.SurfaceCapabilitiesKHR
    if vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
            adapter_impl.vk_physical_device, impl.vk_surface, &surface_caps) != .SUCCESS {
        return
    }

    return vk_surface_fill_capabilities(surface, adapter, surface_caps, allocator, loc)
}

// Fills `caps` from one query; caller owns the output.
vk_surface_fill_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    surface_caps: vk.SurfaceCapabilitiesKHR,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    impl := vk_surface_get_impl(surface, loc)
    adapter_impl := vk_adapter_get_impl(adapter, loc)

    // Temp allocator for raw query buffers.
    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    physical_device := adapter_impl.vk_physical_device

    // Supported formats.
    format_count: u32
    res := vk.GetPhysicalDeviceSurfaceFormatsKHR(
        physical_device, impl.vk_surface, &format_count, nil)
    if res != .SUCCESS || format_count == 0 {
        return
    }

    vk_formats := make([]vk.SurfaceFormatKHR, format_count, ta)
    res = vk.GetPhysicalDeviceSurfaceFormatsKHR(
        physical_device, impl.vk_surface, &format_count, raw_data(vk_formats))
    if res != .SUCCESS {
        return
    }

    // Supported present modes.
    present_mode_count: u32
    res = vk.GetPhysicalDeviceSurfacePresentModesKHR(
        physical_device, impl.vk_surface, &present_mode_count, nil)
    if res != .SUCCESS || present_mode_count == 0 {
        return
    }

    vk_present_modes := make([]vk.PresentModeKHR, present_mode_count, ta)
    res = vk.GetPhysicalDeviceSurfacePresentModesKHR(
        physical_device, impl.vk_surface, &present_mode_count, raw_data(vk_present_modes))
    if res != .SUCCESS {
        return
    }

    // Texture formats.
    formats := make([dynamic]Texture_Format, 0, format_count, allocator)

    for vk_format in vk_formats {
        format := vk_conv_from_format(vk_format.format)
        if format != .Undefined {
            append(&formats, format)
        }
    }

    // sRGB formats first.
    slice.stable_sort_by(formats[:], proc(a, b: Texture_Format) -> bool {
        a_srgb := texture_format_is_srgb(a)
        b_srgb := texture_format_is_srgb(b)
        if a_srgb != b_srgb {
            return a_srgb
        }
        return false
    })

    // Formats and color spaces.
    format_capabilities := make([]Surface_Format_Capabilities, len(formats), allocator)

    for format, i in formats {
        color_spaces: Surface_Color_Spaces

        for vk_format in vk_formats {
            if vk_conv_from_format(vk_format.format) != format {
                continue
            }
            if color_space, ok := vk_conv_from_color_space(vk_format.colorSpace); ok {
                color_spaces += {color_space}
            }
        }

        assert(color_spaces != {}, "surface format with no supported color spaces")

        format_capabilities[i] = Surface_Format_Capabilities {
            format       = format,
            color_spaces = color_spaces,
        }
    }

    // Present modes.
    present_modes := make([dynamic]Present_Mode, 0, present_mode_count, allocator)

    for &vk_present_mode in vk_present_modes {
        mode := vk_conv_from_present_mode(vk_present_mode)
        if !slice.contains(present_modes[:], mode) {
            append(&present_modes, mode)
        }
    }

    // Alpha modes.
    alpha_modes := make([dynamic]Composite_Alpha_Mode, 0, 4, allocator)

    if .OPAQUE in surface_caps.supportedCompositeAlpha {
        append(&alpha_modes, Composite_Alpha_Mode.Opaque)
    }
    if .PRE_MULTIPLIED in surface_caps.supportedCompositeAlpha {
        append(&alpha_modes, Composite_Alpha_Mode.Premultiplied)
    }
    if .POST_MULTIPLIED in surface_caps.supportedCompositeAlpha {
        append(&alpha_modes, Composite_Alpha_Mode.Unpremultiplied)
    }
    if .INHERIT in surface_caps.supportedCompositeAlpha {
        append(&alpha_modes, Composite_Alpha_Mode.Inherit)
    }

    // Usage flags.
    caps.usages = vk_conv_from_image_usage_flags(
        adapter_impl.caps,
        surface_caps.supportedUsageFlags,
    )

    caps.formats = formats[:]
    caps.format_capabilities = format_capabilities[:]
    caps.present_modes = present_modes[:]
    caps.alpha_modes = alpha_modes[:]

    return
}

// Caps in-flight frames to latency. Bounds latency, not frame rate.
//
// Holds `impl.mtx`.
vk_surface_throttle_latency_locked :: proc(
    impl: ^VK_Surface_Impl,
    device_impl: ^VK_Device_Impl,
    loc := #caller_location,
) {
    latency := impl.config.desired_maximum_frame_latency
    // Floor latency at 1; 0 would serialize every frame.
    latency = max(latency, 1)
    // Drop retired submits, then wait while over latency.
    for len(impl.submit_history) > 0 {
        if !vk_submit_context_is_ready(
                &device_impl.submitter, impl.submit_history[0], loc = loc) {
            break
        }
        ordered_remove(&impl.submit_history, 0)
    }
    // Wait while more than `latency` are outstanding.
    for u32(len(impl.submit_history)) > latency {
        vk_submit_context_wait(
            &device_impl.submitter, impl.submit_history[0], loc)
        ordered_remove(&impl.submit_history, 0)
    }
}

vk_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    surface_texture: Surface_Texture,
) {
    impl := vk_surface_get_impl(surface, loc)
    sync.guard(&impl.mtx)

    surface_texture.surface = surface
    surface_texture.status = .Success
    if impl.vk_swapchain == {} || len(impl.acquire_slots) == 0 {
        surface_texture.status = .Outdated
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

    if impl.get_next_image {
        num_slots := u32(len(impl.acquire_slots))
        slot := &impl.acquire_slots[impl.acquire_cursor]

        // Wait on this slot's last submit; cursor moves only on success.
        timeout_ns := max(u64)
        if slot.submit_wait != {} {
            if !vk_submit_context_wait_timeout(
                    &device_impl.submitter, slot.submit_wait, timeout_ns, loc) {
                surface_texture.status = .Timeout
                return
            }
            slot.submit_wait = {}
        }

        // Enforce the latency cap (mailbox never blocks on its own).
        vk_surface_throttle_latency_locked(impl, device_impl, loc)

        acquire_fence: vk.Fence
        when ODIN_OS == .Windows {
            acquire_fence = impl.acquire_fence
        }

        image_index: u32
        res := vk.AcquireNextImageKHR(
            device_impl.vk_device,
            impl.vk_swapchain,
            timeout_ns,
            slot.semaphore,
            // No fence off Windows: `submit_wait` already covers it.
            acquire_fence,
            &image_index)

        #partial switch res {
        case .SUCCESS:
            surface_texture.status = .Success
        case .SUBOPTIMAL_KHR:
            surface_texture.status = .Suboptimal
        case .TIMEOUT:
            surface_texture.status = .Timeout
            return
        case .NOT_READY, .ERROR_OUT_OF_DATE_KHR:
            surface_texture.status = .Outdated
            return
        case .ERROR_SURFACE_LOST_KHR, .ERROR_DEVICE_LOST:
            surface_texture.status = .Lost
            return
        case:
            vk_check(res, loc = loc)
            return
        }

        // Windows: wait + reset the acquire fence.
        when ODIN_OS == .Windows {
            vk_check(device_impl.fp.WaitForFences(
                device_impl.vk_device, 1, &impl.acquire_fence, true, timeout_ns), loc = loc)
            vk_check(device_impl.fp.ResetFences(
                device_impl.vk_device, 1, &impl.acquire_fence), loc = loc)
        }

        // Intel quirk: bogus image index means Outdated; keep slot for reconfigure.
        if adapter_impl.vk_properties.vendorID == VENDOR_INTEL && image_index > 0x100 {
            device_impl.fp.DestroySemaphore(device_impl.vk_device, slot.semaphore, nil)
            slot.semaphore = vk_utils_create_semaphore(
                device_impl.fp, "Semaphore: swapchain-acquire", loc)
            surface_texture.status = .Outdated
            return
        }

        impl.acquire_cursor      = (impl.acquire_cursor + 1) % num_slots
        impl.current_image_index = image_index
        impl.get_next_image      = false

        // First submit touching this image waits on the acquire.
        vk_surface_arm_acquire(
            &device_impl.submitter, surface, image_index, slot.semaphore, loc)

        assert(image_index < impl.num_swapchain_images, loc = loc)
        surface_texture.texture = impl.swapchain_textures[image_index]

        // Acquired images arrive in present layout. Seed new images here;
        // repeats mid-frame must not clobber app state. Surface lock serializes this.
        cur := device_texture_tracker_get_state(
            &device_impl.trackers.textures, surface_texture.texture, loc)
        if cur.is_single && cur.state == TEXTURE_USES_UNINITIALIZED {
            device_texture_tracker_set_state(
                &device_impl.trackers.textures, surface_texture.texture, {.Uninitialized})
        } else {
            device_texture_tracker_set_state(
                &device_impl.trackers.textures, surface_texture.texture, {.Present})
        }
    } else {
        assert(impl.current_image_index < impl.num_swapchain_images, loc = loc)
        surface_texture.texture = impl.swapchain_textures[impl.current_image_index]
    }

    return
}

// Submits a Present transition for the current image. Holds the surface lock.
vk_surface_submit_transition_locked :: proc(
    impl: ^VK_Surface_Impl,
    device_impl: ^VK_Device_Impl,
    loc := #caller_location,
) -> VK_Submit_Handle {
    texture := impl.swapchain_textures[impl.current_image_index]
    texture_impl := vk_texture_get_impl(texture, loc)

    encoder := vk_create_command_encoder(impl.device, {}, loc)
    encoder_impl := vk_command_encoder_get_impl(encoder, loc)
    err := texture_usage_scope_merge_single(
        &encoder_impl.cmdbuf.global_scope.textures,
        texture,
        texture_impl.full_range,
        {.Present},
        loc,
    )
    assert(err == nil, "failed to track surface texture for fallback present", loc)

    command_buffer := vk_command_encoder_finish(encoder, loc = loc)
    cmdbuf_impl := vk_command_buffer_get_impl(command_buffer, loc)
    // Drain emits barriers so signals follow layout transitions.
    vk_record_commands(impl.device, cmdbuf_impl, loc)
    last_submit := vk_submit_context_submit(
        &device_impl.submitter, cmdbuf_impl, loc)

    vk_command_buffer_release(command_buffer, loc)
    vk_command_encoder_release(encoder, loc)
    return last_submit
}

vk_surface_present_impl :: proc(impl: ^VK_Surface_Impl, loc := #caller_location) -> Status {
    sync.guard(&impl.mtx)
    if impl.vk_swapchain == {} || impl.get_next_image {
        return .Error
    }
    assert(impl.current_image_index < impl.num_swapchain_images, loc = loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    submitter := &device_impl.submitter

    present_info := vk.PresentInfoKHR {
        sType              = .PRESENT_INFO_KHR,
        swapchainCount     = 1,
        pSwapchains        = &impl.vk_swapchain,
        pImageIndices      = &impl.current_image_index,
    }

    texture := impl.swapchain_textures[impl.current_image_index]
    texture_state := device_texture_tracker_get_state(
        &device_impl.trackers.textures, texture, loc)
    needs_present_transition := !texture_state.is_single ||
        texture_state.state != Texture_Uses{.Present}

    // Present waits on pool signals, never the acquire directly. Ensure one
    // submit touched this image: transition if needed, or a signal-only submit
    // for empty frames.
    if needs_present_transition ||
           !vk_surface_present_pool_has_signals(impl, submitter, impl.current_image_index) {
        vk_surface_submit_transition_locked(impl, device_impl, loc)
    }

    // Present this image's signals; index keeps it safe if retirement lags.
    res, last_submit := vk_surface_present_pool_queue_present(
        impl, submitter, impl.current_image_index, &present_info, loc)

    // Retire the slot so next acquire can proceed; track it for the latency cap.
    impl.acquire_slots[vk_surface_acquired_slot(impl)].submit_wait = last_submit
    // Track for latency cap.
    if last_submit != {} {
        append(&impl.submit_history, last_submit)
    }

    impl.get_next_image = true
    sync.cond_broadcast(&impl.frame_cond)

    #partial switch res {
    case .SUCCESS, .SUBOPTIMAL_KHR:
        return .Success
    case .ERROR_OUT_OF_DATE_KHR, .ERROR_SURFACE_LOST_KHR, .ERROR_DEVICE_LOST:
        return .Error
    case:
        vk_check(res, loc = loc)
        return .Error
    }
}

vk_surface_present :: proc(surface: Surface, loc := #caller_location) -> Status {
    impl := vk_surface_get_impl(surface, loc)
    return vk_surface_present_impl(impl, loc)
}

vk_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_swapchain_destroy_resources :: proc(impl: ^VK_Surface_Impl, loc := #caller_location) {
    assert(impl.vk_swapchain != {}, "Invalid vk.SwapchainKHR", loc)
    assert(impl.device != {}, "Invalid VK_Device_Impl", loc)

    device_impl := vk_device_get_impl(impl.device, loc)

    // No DeviceWaitIdle: wait_all drains without stalling all surfaces.
    vk_submit_context_wait_all(&device_impl.submitter, loc)

    // Textures.
    for texture in impl.swapchain_textures {
        texture_impl := vk_texture_get_impl(texture, loc)
        device_texture_tracker_remove(
            &device_impl.trackers.textures, texture_impl.tracker_index)
        shared_tracker_index_allocator_free(
            &device_impl.tracker_indices.textures, texture_impl.tracker_index, loc)
        remove_handle_impl(&device_impl.textures, texture_impl.handle)
    }

    // Views.
    for view in impl.swapchain_views {
        vk_framebuffer_cache_invalidate_view(device_impl, view, loc)
        view_impl := vk_texture_view_get_impl(view, loc)
        device_impl.fp.DestroyImageView(device_impl.vk_device, view_impl.vk_image_view, nil)
        remove_handle_impl(&device_impl.texture_views, view_impl.handle)
    }

    // Sync objects.
    for &slot in impl.acquire_slots {
        device_impl.fp.DestroySemaphore(device_impl.vk_device, slot.semaphore, nil)
    }

    // Windows fence.
    when ODIN_OS == .Windows {
        if impl.acquire_fence != {} {
            device_impl.fp.DestroyFence(device_impl.vk_device, impl.acquire_fence, nil)
            impl.acquire_fence = {}
        }
    }

    // Reset state.
    //
    // NOTE: present pools survive reconfigure; freed at release.
    clear(&impl.swapchain_textures)
    clear(&impl.swapchain_views)
    clear(&impl.acquire_slots)
    clear(&impl.submit_history)
    impl.acquire_cursor = 0
    impl.current_image_index = 0
    impl.num_swapchain_images = 0
    impl.get_next_image = true
}

vk_surface_unconfigure :: proc(surface: Surface, loc := #caller_location) {
    impl := vk_surface_get_impl(surface, loc)
    sync.guard(&impl.mtx)
    if !vk_surface_wait_for_present_timeout_locked(impl) {
        vk_surface_abandon_frame_locked(impl, loc)
    }
    vk_surface_unconfigure_locked(impl, loc)
}

// Holds `impl.mtx`; waiting lets present run. 2s cap so abandoned frames can't
// hang teardown.
VK_SURFACE_PRESENT_WAIT_TIMEOUT :: 2 * time.Second

// False means no presenter is coming. Spurious wakes must re-wait.
vk_surface_wait_for_present_timeout_locked :: proc(
    impl: ^VK_Surface_Impl,
    timeout := VK_SURFACE_PRESENT_WAIT_TIMEOUT,
) -> bool {
    for !impl.get_next_image {
        timed_out := !sync.cond_wait_with_timeout(&impl.frame_cond, &impl.mtx, timeout)
        if impl.get_next_image {
            // Present landed during timeout; honor it.
            return true
        }
        if timed_out {
            return false
        }
        // Spurious wake; wait again.
    }
    return true
}

// Drops an acquired-but-unpresented frame after the wait expired. Empty submit
// consumes the chain wait; teardown purges the acquire later.
vk_surface_abandon_frame_locked :: proc(
    impl: ^VK_Surface_Impl,
    loc := #caller_location,
) {
    if impl.get_next_image {
        return
    }

    // A live frame implies a configured device.
    device_impl := vk_device_get_impl(impl.device, loc)
    encoder := vk_create_command_encoder(impl.device, {}, loc)
    command_buffer := vk_command_encoder_finish(encoder, loc = loc)
    cmdbuf_impl := vk_command_buffer_get_impl(command_buffer, loc)
    // Drain emits barriers so signals follow layout transitions.
    vk_record_commands(impl.device, cmdbuf_impl, loc)
    last_submit := vk_submit_context_submit(
        &device_impl.submitter, cmdbuf_impl, loc)
    vk_command_buffer_release(command_buffer, loc)
    vk_command_encoder_release(encoder, loc)

    impl.acquire_slots[vk_surface_acquired_slot(impl)].submit_wait = last_submit
    if last_submit != {} {
        append(&impl.submit_history, last_submit)
    }
    impl.get_next_image = true
    sync.cond_broadcast(&impl.frame_cond)
}

// Holds `impl.mtx`.
vk_surface_unconfigure_locked :: proc(impl: ^VK_Surface_Impl, loc := #caller_location) {
    if impl.vk_swapchain == {} {
        return
    }

    device := impl.device
    device_impl := vk_device_get_impl(device, loc)
    // Retire work, purge stale acquires while slots are alive.
    vk_submit_context_queue_wait_idle(&device_impl.submitter, loc)
    // Drop stale pending acquires while slot semaphores are alive.
    vk_surface_purge_pending(&device_impl.submitter, impl, loc)
    vk_swapchain_destroy_resources(impl, loc)
    // Pools die here after idle; reconfigure regrows them.
    vk_surface_present_pools_destroy(impl, device_impl, loc)
    device_impl.fp.DestroySwapchainKHR(device_impl.vk_device, impl.vk_swapchain, nil)
    impl.vk_swapchain = {}
    vk_device_release(device, loc)
    impl.device = {}
}

vk_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    impl := vk_surface_get_impl(surface, loc)
    add_ref(impl, loc)
}

vk_surface_release :: proc(surface: Surface, loc := #caller_location) {
    impl := vk_surface_get_impl(surface, loc)
    if release_ref(impl, loc) {
        context.allocator = impl.allocator
        instance_impl := vk_instance_get_impl(impl.instance, loc)
        {
            sync.guard(&impl.mtx)
            if !vk_surface_wait_for_present_timeout_locked(impl) {
                vk_surface_abandon_frame_locked(impl, loc)
            }
            if impl.vk_swapchain != {} {
                vk_surface_unconfigure_locked(impl, loc)
            }
        }
        vk.DestroySurfaceKHR(instance_impl.vk_instance, impl.vk_surface, nil)
        vk_instance_release(impl.instance, loc)

        // Free submit history; other arrays are inline.
        delete(impl.submit_history)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Procedures of Surface_Texture
// -----------------------------------------------------------------------------

vk_surface_texture_present :: proc(texture: Surface_Texture, loc := #caller_location) -> Status {
    impl := vk_surface_get_impl(texture.surface, loc)
    return vk_surface_present_impl(impl, loc)
}

// -----------------------------------------------------------------------------
// Procedures of Surface_Capabilities
// -----------------------------------------------------------------------------

vk_surface_capabilities_free_members :: proc(
    surface_capabilities: Surface_Capabilities,
    allocator := context.allocator,
    loc := #caller_location,
) {
    context.allocator = allocator
    delete(surface_capabilities.formats)
    delete(surface_capabilities.format_capabilities)
    delete(surface_capabilities.present_modes)
    delete(surface_capabilities.alpha_modes)
}
