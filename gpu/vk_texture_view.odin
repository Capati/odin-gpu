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
    using base: _Texture_View_Impl,

    // Backend
    vk_image_view:         vk.ImageView,
    vk_image_view_storage: vk.ImageView,
    handle:                VK_Texture_View_Handle,
    is_owning_vk_view:     bool,
    is_swapchain:          bool,
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

vk_texture_view_get_internal_impl :: #force_inline proc "contextless" (
    texture_view: Texture_View,
    loc := #caller_location,
) -> ^_Texture_View_Impl {
    return vk_texture_view_get_impl(texture_view, loc)
}

@(require_results)
vk_texture_view_get_if_valid :: #force_inline proc "contextless" (
    device_impl: ^VK_Device_Impl,
    texture_view: Texture_View,
) -> ^VK_Texture_View_Impl {
    if texture_view == {} {
        return nil
    }
    return dhm_get_if_valid(
        &device_impl.texture_views,
        unpack_handle(VK_Texture_View_Handle, texture_view.handle),
    )
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
            aspectMask     = aspect_mask,
            baseMipLevel   = base_level,
            levelCount     = num_levels > 0 ? num_levels : self.num_levels,
            baseArrayLayer = base_layer,
            layerCount     = num_layers,
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

@(require_results)
vk_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View {
    device_impl := vk_device_get_impl(texture.device, loc)
    if !dhm_is_valid(&device_impl.textures, unpack_handle(VK_Texture_Handle, texture.handle)) {
        gpu_report_validation_error(texture.device, "texture is not a live handle", loc)
        return {}
    }

    impl := vk_texture_get_impl(texture, loc)

    descriptor_copy := descriptor
    desc, ok := _resolve_texture_view_descriptor(texture, impl.device, descriptor_copy, loc)
    if !ok {
        return {}
    }

    if impl.is_owning_vk_image {
        key := VK_Swapchain_View_Key {
            format      = desc.format,
            dimension   = desc.dimension,
            aspect      = desc.range.aspect,
            swizzle     = desc.swizzle,
            mip_start   = desc.range.base_mip_level,
            mip_count   = desc.range.mip_level_count,
            layer_start = desc.range.base_array_layer,
            layer_count = desc.range.array_layer_count,
        }
        surface_impl := vk_surface_get_impl(impl.surface)
        sync.guard(&surface_impl.mtx)
        for entry in impl.swapchain_views {
            if entry.key == key {
                texture_view_add_ref(entry.view, loc)
                return entry.view
            }
        }

        adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
        vk_image_view := vk_texture_create_image_view(
            impl,
            type = vk_conv_to_image_view_type(desc.dimension),
            format = vk_conv_to_format(adapter_impl.caps, desc.format),
            aspect_mask = vk_conv_to_image_aspect_flags(desc.range.aspect, desc.format),
            base_level = desc.range.base_mip_level,
            num_levels = desc.range.mip_level_count,
            base_layer = desc.range.base_array_layer,
            num_layers = desc.range.array_layer_count,
            components = vk_conv_component_swizzle(desc.swizzle),
            debug_name = desc.label,
        )
        _, texture_view_handle := add_impl(&device_impl.texture_views, VK_Texture_View_Impl {
                device = impl.device,
                texture = texture,
                vk_image_view = vk_image_view,
                is_owning_vk_view = true,
                is_swapchain = true,
                format = desc.format,
                dimension = desc.dimension,
                usage = desc.usage,
                public_usage = descriptor.usage == {} ? impl.public_usage : descriptor.usage,
                aspect = desc.range.aspect,
                swizzle = desc.swizzle,
                selector = {
                    mip_start   = desc.range.base_mip_level,
                    mip_count   = desc.range.mip_level_count,
                    layer_start = desc.range.base_array_layer,
                    layer_count = desc.range.array_layer_count,
                },
            })
        view := new_handle(Texture_View, impl.device, texture_view_handle)
        vk_label_set(
            &device_impl.labels,
            .Texture_View,
            pack_handle(texture_view_handle),
            desc.label,
        )
        if len(impl.swapchain_views) < VK_MAX_SWAPCHAIN_IMAGE_VIEWS {
            // The cache keeps one ref; the caller gets another.
            append(&impl.swapchain_views, VK_Swapchain_View{key = key, view = view})
            texture_view_add_ref(view, loc)
        } else {
            // Degenerate callers cannot grow the table: hand out a normal owning
            // view that releases its Vulkan object instead of caching it.
            view_impl := vk_texture_view_get_impl(view, loc)
            view_impl.is_owning_vk_view = false
        }
        return view
    } else {
        adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

        vk_image_view := vk_texture_create_image_view(
            impl,
            type = vk_conv_to_image_view_type(desc.dimension),
            format = vk_conv_to_format(adapter_impl.caps, desc.format),
            aspect_mask = vk_conv_to_image_aspect_flags(desc.range.aspect, desc.format),
            base_level = desc.range.base_mip_level,
            num_levels = desc.range.mip_level_count,
            base_layer = desc.range.base_array_layer,
            num_layers = desc.range.array_layer_count,
            components = vk_conv_component_swizzle(desc.swizzle),
            debug_name = desc.label,
        )

        _, texture_view_handle := add_impl(
            &device_impl.texture_views,
            VK_Texture_View_Impl {
                device = impl.device,
                texture = texture,
                vk_image_view = vk_image_view,
                is_swapchain = false,
                format = desc.format,
                dimension = desc.dimension,
                usage = desc.usage,
                public_usage = descriptor.usage == {} ? impl.public_usage : descriptor.usage,
                aspect = desc.range.aspect,
                swizzle = desc.swizzle,
                // The tracker selector is count-based, matching the descriptor.
                selector = {
                    mip_start   = desc.range.base_mip_level,
                    mip_count   = desc.range.mip_level_count,
                    layer_start = desc.range.base_array_layer,
                    layer_count = desc.range.array_layer_count,
                },
            },
        )

        vk_texture_add_ref(texture, loc)
        vk_label_set(
            &device_impl.labels,
            .Texture_View,
            pack_handle(texture_view_handle),
            desc.label,
        )

        return new_handle(Texture_View, impl.device, texture_view_handle)
    }
}

vk_texture_view_get_texture :: proc(
    texture_view: Texture_View,
    loc := #caller_location,
) -> Texture {
    return vk_texture_view_get_impl(texture_view, loc).texture
}

vk_texture_view_get_label :: proc(texture_view: Texture_View, loc := #caller_location) -> string {
    impl := vk_texture_view_get_impl(texture_view, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Texture_View, pack_handle(impl.handle))
}

vk_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    impl := vk_texture_view_get_impl(texture_view, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Texture_View, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .IMAGE_VIEW, impl.vk_image_view, label, loc)
}

vk_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := vk_texture_view_get_impl(texture_view, loc)
    add_ref(impl, loc)
}

vk_framebuffer_cache_remove_view :: proc(
    device_impl: ^VK_Device_Impl,
    view: Texture_View,
    matched: ^[dynamic]vk.Framebuffer,
    owns_temp_guard := true,
    loc := #caller_location,
) {
    sync.guard(&device_impl.framebuffer_cache_mtx)
    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = !owns_temp_guard)
    stale_keys: [dynamic]VK_Framebuffer_Key
    stale_keys.allocator = ta
    for key, cache in device_impl.framebuffer_cache {
        for i in 0 ..< cache.attachment_count {
            if cache.texture_views[i].texture_view == view {
                append(matched, cache.vk_framebuffer)
                append(&stale_keys, key)
                break
            }
        }
    }
    for key in stale_keys {
        delete_key(&device_impl.framebuffer_cache, key)
    }
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
    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    matched.allocator = ta
    vk_framebuffer_cache_remove_view(
        device_impl,
        view,
        &matched,
        owns_temp_guard = false,
        loc = loc,
    )

    for framebuffer in matched {
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, framebuffer)
    }
}

vk_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := vk_texture_view_get_impl(texture_view, loc)

    if impl.is_owning_vk_view {
        if release_ref(impl, loc) {
            device_impl := vk_device_get_impl(impl.device, loc)
            vk_framebuffer_cache_invalidate_view(device_impl, texture_view, loc)
            vk_label_remove(&device_impl.labels, .Texture_View, pack_handle(impl.handle))
            remove_handle_impl(&device_impl.texture_views, impl.handle)
        }
        return
    }

    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)

        vk_framebuffer_cache_invalidate_view(device_impl, texture_view, loc)

        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, impl.vk_image_view)
        if impl.vk_image_view_storage != 0 {
            vk_deferred_add_resource(
                &device_impl.deferred,
                &device_impl.submitter,
                impl.vk_image_view_storage,
            )
        }

        vk_texture_release(impl.texture)
        vk_label_remove(&device_impl.labels, .Texture_View, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.texture_views, impl.handle)
    }
}
