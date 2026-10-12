#+build !js
package gpu

// Core
import hm "core:container/handle_map"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Texture_View_Handle :: distinct hm.Handle64

VK_Texture_View_Impl :: struct {
    // Base
    using base:            Texture_View_Impl,

    // Backend
    vk_image_view:         vk.ImageView,
    vk_image_view_storage: vk.ImageView,
    handle:                VK_Texture_View_Handle,
    is_owning_vk_view:     bool,
    is_swapchain:          bool,
}

vk_texture_view_get_public_impl :: #force_inline proc "contextless" (
    texture_view: Texture_View,
    loc := #caller_location,
) -> ^Texture_View_Impl {
    return vk_texture_view_get_impl(texture_view, loc)
}

@(require_results)
vk_texture_view_get_impl :: #force_inline proc "contextless" (
    texture_view: Texture_View,
    loc := #caller_location,
) -> ^VK_Texture_View_Impl {
    assert_contextless(texture_view != {}, "invalid texture view", loc)
    device_impl := vk_device_get_impl(texture_view.device, loc)
    return get_handle_impl(&device_impl.texture_views, texture_view.handle, loc)
}

vk_texture_create_image_view :: proc(
    self: ^VK_Texture_Impl,
    type: vk.ImageViewType,
    format: vk.Format,
    aspect_mask: vk.ImageAspectFlags,
    base_level: u32,
    num_levels: u32 = vk.REMAINING_MIP_LEVELS,
    base_layer: u32 = 0,
    num_layers: u32 = 1,
    components: vk.ComponentMapping = {}, // .IDENTITY
    ycbcr: ^vk.SamplerYcbcrConversionInfo = nil,
    debug_name := "",
    loc := #caller_location,
) -> (
    vk_image_view: vk.ImageView,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    image_view_create_info := vk.ImageViewCreateInfo {
        sType = .IMAGE_VIEW_CREATE_INFO,
        pNext = ycbcr,
        image = self.vk_image,
        viewType = type,
        format = format,
        components = components,
        subresourceRange = {
            aspectMask = aspect_mask,
            baseMipLevel = base_level,
            levelCount = num_levels > 0 ? num_levels : self.num_levels,
            baseArrayLayer = base_layer,
            layerCount = num_layers,
        },
    }

    vk_check(
        device_impl.fp.CreateImageView(
            device_impl.vk_device,
            &image_view_create_info,
            nil,
            &vk_image_view,
        ),
        loc = loc,
    )
    vk_utils_set_debug_object_name(device_impl.fp, .IMAGE_VIEW, vk_image_view, debug_name, loc)

    return
}

vk_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := vk_texture_view_get_impl(texture_view, loc)
    add_ref(impl, loc)
}

// Swapchain texture views are owned and removed by the surface, not by their
// trackers. Tracker cleanup may run after swapchain teardown has invalidated the
// handle, so those entries are deliberately ignored here.
vk_tracker_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := vk_texture_view_get_impl(texture_view, loc)
    if !impl.is_owning_vk_view {
        add_ref(impl, loc)
    }
}

vk_tracker_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    device_impl := vk_device_get_impl(texture_view.device, loc)
    impl, ok := hm.dynamic_get(
        &device_impl.texture_views.resources,
        unpack_handle(VK_Texture_View_Handle, texture_view.handle),
    )
    if !ok || impl.is_owning_vk_view {
        return
    }
    vk_texture_view_release(texture_view, loc)
}

vk_framebuffer_cache_invalidate_view :: proc(
    device_impl: ^VK_Device_Impl,
    view: Texture_View,
    loc := #caller_location,
) {
    // Single pass: collect every framebuffer referencing this view, then
    // retire them. Restarting the scan per match was O(n^2) lock churn once
    // the cache grew large.
    matched: [dynamic]vk.Framebuffer
    matched.allocator = context.temp_allocator
    {
        sync.guard(&device_impl.framebuffer_cache_mtx)
        stale_keys: [dynamic]VK_Framebuffer_Key
        stale_keys.allocator = context.temp_allocator
        for key, cache in device_impl.framebuffer_cache {
            for i in 0 ..< cache.attachment_count {
                if cache.texture_views[i].texture_view == view {
                    append(&matched, cache.vk_framebuffer)
                    append(&stale_keys, key)
                    break
                }
            }
        }
        for key in stale_keys {
            delete_key(&device_impl.framebuffer_cache, key)
        }
    }

    for framebuffer in matched {
        vk_deferred_add_resource(
            &device_impl.deferred, &device_impl.submitter, framebuffer)
    }
}

vk_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := vk_texture_view_get_impl(texture_view, loc)

    if impl.is_owning_vk_view {
        return
    }

    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)

        vk_framebuffer_cache_invalidate_view(device_impl, texture_view, loc)

        vk_deferred_add_resource(
            &device_impl.deferred, &device_impl.submitter, impl.vk_image_view)
        if impl.vk_image_view_storage != 0 {
            vk_deferred_add_resource(
                &device_impl.deferred, &device_impl.submitter, impl.vk_image_view_storage)
        }

        vk_texture_release(impl.texture)
        remove_handle_impl(&device_impl.texture_views, impl.handle)
    }
}
