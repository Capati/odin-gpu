#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:sync"

// Vendor
import gpua "allocator"
import "lib/vma"
import vk "vendor:vulkan"

VK_Texture_Memory_Allocation :: union {
    gpua.VK_Allocation,
    vma.Allocation,
}

VK_Texture_Handle :: distinct hm.Handle64

VK_Swapchain_View_Key :: struct {
    format:      Texture_Format,
    dimension:   Texture_View_Dimension,
    aspect:      Texture_Aspect,
    swizzle:     Texture_Component_Swizzle,
    mip_start:   u32,
    mip_count:   u32,
    layer_start: u32,
    layer_count: u32,
}

VK_MAX_SWAPCHAIN_IMAGE_VIEWS :: 4

VK_Swapchain_View :: struct {
    key:  VK_Swapchain_View_Key,
    view: Texture_View,
}

VK_Texture_Impl :: struct {
    using base:            _Texture_Impl,
    allocation:            VK_Texture_Memory_Allocation,
    vk_format_properties:  vk.FormatProperties,
    vk_extent:             vk.Extent3D,
    surface:               Surface,
    mapped_ptr:            rawptr,
    // Hot fields for the barrier / pass path.
    vk_image:              vk.Image,
    vk_usage_flags:        vk.ImageUsageFlags,
    vk_type:               vk.ImageType,
    vk_image_format:       vk.Format,
    vk_samples:            vk.SampleCountFlags,
    num_levels:            u32,
    num_layers:            u32,
    handle:                VK_Texture_Handle,
    is_owning_vk_image:    bool,
    is_resolve_attachment: bool,
    is_depth_format:       bool,
    is_stencil_format:     bool,
    is_swapchain:          bool,
    public_usage:          Texture_Usages,
    // See `VK_Buffer_Impl.deferred_holds`.
    deferred_holds:        Ref_Count_Type,
    destroy_enqueued:      bool,
    // Swapchain image position. Only meaningful when is_swapchain is set;
    // lets later phases resolve (surface, image) from the texture alone
    // without taking the surface lock.
    swapchain_index:       u32,
    // Cold from the barrier path: only the swapchain-view cache and the global
    // init tracker. They stay reachable via `base`/`init` when needed, but live
    // after the hot fields so the common barrier reads do not pull them in.
    swapchain_views:       [dynamic; VK_MAX_SWAPCHAIN_IMAGE_VIEWS]VK_Swapchain_View,
    // Memory-initialisation state: which subresources hold defined contents.
    init:                  Texture_Init_Tracker,
}

@(require_results)
vk_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    impl := vk_device_get_impl(device, loc)
    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

    // Get the descriptor implementation
    descriptor_copy := descriptor
    desc, ok := _resolve_texture_descriptor(device, &descriptor_copy, loc)
    if !ok {
        return {}
    }

    // The descriptor keeps `view_formats` for later `texture_get_descriptor` and
    // view validation, so own a copy instead of borrowing the caller's slice.
    if len(desc.view_formats) > 0 {
        owned := make([]Texture_Format, len(desc.view_formats), impl.allocator)
        copy(owned, desc.view_formats)
        desc.view_formats = owned
    }
    success := false
    defer if !success && len(desc.view_formats) > 0 {
        delete(desc.view_formats, impl.allocator)
    }

    // Set create flags
    vk_create_flags: vk.ImageCreateFlags

    // 3D textures used as color or depth targets need 2D array compatible for
    // slice rendering.
    if desc.dimension == .D3 &&
       (.Color_Target in desc.internal_usage || .Depth_Write in desc.internal_usage) {
        vk_create_flags += {.D2_ARRAY_COMPATIBLE}
    }

    // Cubemap support
    if texture_descriptor_is_cube_compatible(desc) {
        vk_create_flags += {.CUBE_COMPATIBLE}
    }

    // View format reinterpretation requires mutable format; multi-planar
    // formats also need extended usage for their plane views.
    if len(desc.view_formats) > 0 || texture_format_is_multi_planar(desc.format) {
        vk_create_flags += {.MUTABLE_FORMAT}
    }
    if texture_format_is_multi_planar(desc.format) {
        vk_create_flags += {.EXTENDED_USAGE}
    }

    // Convert Texture_Dimension to vk.ImageType
    vk_image_type := vk_conv_to_image_type(desc.dimension)

    // Convert Texture_Format to vk.Format
    vk_format := vk_conv_to_format(adapter_impl.caps, desc.format)

    // Convert Extent_3D to vk.Extent3D
    vk_extent := vk_conv_to_extent_3d(desc.size, desc.dimension)

    // Convert Texture_Usages to vk.ImageUsageFlags
    vk_image_usage_flags := vk_conv_to_image_usage_flags(desc.internal_usage)

    // Convert sample count to vk.SampleCountFlags
    vk_samples := vk_conv_to_sample_count_flags(desc.sample_count, loc)

    image_create_info := vk.ImageCreateInfo {
        sType         = .IMAGE_CREATE_INFO,
        flags         = vk_create_flags,
        imageType     = vk_image_type,
        format        = vk_format,
        extent        = vk_extent,
        mipLevels     = desc.mip_level_count,
        arrayLayers   = texture_descriptor_array_layer_count(desc, loc),
        samples       = vk_samples,
        tiling        = .OPTIMAL,
        usage         = vk_image_usage_flags,
        sharingMode   = .EXCLUSIVE,
        initialLayout = .UNDEFINED,
    }

    // Build view formats list for pNext chain if needed
    vk_view_formats: [dynamic]vk.Format
    view_format_count := u32(len(desc.view_formats))

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vk_format_list_info: vk.ImageFormatListCreateInfo
    if view_format_count > 0 && adapter_impl.caps.image_format_list {

        vk_view_formats = make([dynamic]vk.Format, 0, view_format_count + 1, ta)

        for f in desc.view_formats {
            append(&vk_view_formats, vk_conv_to_format(adapter_impl.caps, f))
        }
        // Include the base format itself
        append(&vk_view_formats, vk_format)

        vk_format_list_info = vk.ImageFormatListCreateInfo {
            sType           = .IMAGE_FORMAT_LIST_CREATE_INFO,
            viewFormatCount = view_format_count + 1,
            pViewFormats    = raw_data(vk_view_formats),
        }
        image_create_info.pNext = &vk_format_list_info
    }

    vk_image: vk.Image

    when USE_VMA {
        vma_alloc_info := vma.AllocationCreateInfo {
            usage          = .AUTO,
            requiredFlags  = {.DEVICE_LOCAL},
            memoryTypeBits = impl.valid_memory_type_bits,
        }
        vma_allocation: vma.Allocation
        if res := vma.CreateImage(
            impl.vma_allocator,
            image_create_info,
            vma_alloc_info,
            &vk_image,
            &vma_allocation,
            nil,
        ); res != .SUCCESS {
            vk_try(device, res, "vmaCreateImage", loc)
            return {}
        }
    } else {
        // Create the image
        if res := impl.fp.CreateImage(impl.vk_device, &image_create_info, nil, &vk_image);
           res != .SUCCESS {
            vk_try(device, res, "vkCreateImage", loc)
            return {}
        }

        // Allocate memory
        requirements: vk.MemoryRequirements
        impl.fp.GetImageMemoryRequirements(impl.vk_device, vk_image, &requirements)

        masked_requirements := requirements
        masked_requirements.memoryTypeBits &= impl.valid_memory_type_bits
        assert(
            masked_requirements.memoryTypeBits != 0,
            "VULKAN: no valid memory type for image allocation",
            loc,
        )

        alloc_desc := gpua.VK_Allocation_Create_Desc {
            name              = desc.label,
            requirements      = masked_requirements,
            location          = .Gpu_Only,
            linear            = false,
            allocation_scheme = gpua.VK_ALLOCATION_SCHEME_MANAGED,
        }

        gpu_allocation: gpua.VK_Allocation
        gpua.gpu_alloc_check(
            gpua.vk_allocator_allocate(&impl.gpu_allocator, alloc_desc, &gpu_allocation, loc),
        )

        // Bind memory
        if res := impl.fp.BindImageMemory(
            impl.vk_device,
            vk_image,
            gpu_allocation.device_memory,
            vk.DeviceSize(gpu_allocation.offset),
        ); res != .SUCCESS {
            vk_try(device, res, "vkBindImageMemory", loc)
            // Leave nothing behind: the image exists but is unusable.
            impl.fp.DestroyImage(impl.vk_device, vk_image, nil)
            gpua.vk_allocator_free(&impl.gpu_allocator, &gpu_allocation)
            return {}
        }
    }

    ensure(vk_image != {}, "VULKAN: Failed to create vk.Image", loc)

    tracker_index := shared_tracker_index_allocator_alloc(&impl.tracker_indices.textures)

    texture_impl, texture_handle := add_impl(
    &impl.textures,
    VK_Texture_Impl {
        // From descriptor
        desc_impl = desc,

        // Backend
        vk_format_properties = {},
        vk_extent = vk_extent,
        device = device,
        tracker_index = tracker_index,
        full_range = Texture_Selector {
            mip_start   = 0,
            mip_count   = desc.mip_level_count,
            layer_start = 0,
            layer_count = image_create_info.arrayLayers,
        },
        vk_image = vk_image,
        vk_usage_flags = vk_image_usage_flags,
        vk_type = vk_image_type,
        vk_image_format = vk_format,
        vk_samples = vk_samples,
        num_levels = desc.mip_level_count,
        num_layers = image_create_info.arrayLayers,
        is_owning_vk_image = false,
        is_resolve_attachment = false,
        is_depth_format = texture_format_has_depth_aspect(desc.format),
        is_stencil_format = texture_format_has_stencil_aspect(desc.format),
        is_swapchain = false,
        public_usage = desc.usage,
    },
    )

    when USE_VMA {
        texture_impl.allocation = vma_allocation
    } else {
        texture_impl.allocation = gpu_allocation
    }

    // The image is created with initialLayout .UNDEFINED, so its contents are
    // discarded and every subresource starts in the undefined layout.
    aspect_count: u32 = 1
    if texture_format_is_combined_depth_stencil_format(desc.format) {
        aspect_count = 2
    } else if texture_format_is_multi_planar(desc.format) {
        aspect_count = max(1, texture_format_planes(desc.format))
    }
    texture_init_tracker_init(
        &texture_impl.init,
        impl.allocator,
        desc.mip_level_count,
        image_create_info.arrayLayers,
        aspect_count,
    )

    texture_public := new_handle(Texture, device, texture_handle)
    {
        sync.guard(&impl.trackers_mtx)
        device_texture_tracker_insert_single(
            &impl.trackers.textures,
            vk_tracked_texture(texture_public, texture_impl),
            {.Uninitialized},
        )
    }
    vk_label_set(&impl.labels, .Texture, pack_handle(texture_handle), descriptor.label)

    success = true
    return texture_public
}

@(require_results)
vk_texture_get_internal_impl :: #force_inline proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> ^_Texture_Impl {
    return vk_texture_get_impl(texture, loc)
}

@(require_results)
vk_texture_get_impl :: #force_inline proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> ^VK_Texture_Impl {
    device_impl := vk_device_get_impl(texture.device, loc)
    return get_handle_impl(&device_impl.textures, texture.handle, loc)
}

vk_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)
    // The handle stays valid until `texture_release` (WebGPU semantics). The
    // image itself is destroyed by the deferred deletor then.
    impl.destroyed = true
    device_impl := vk_device_get_impl(impl.device, loc)
    intr.atomic_add(&device_impl.destroyed_resources, 1)
}

vk_texture_get_depth_or_array_layers :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.size.depth_or_array_layers
}

vk_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc
}

vk_texture_get_dimension :: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.dimension
}

vk_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.format
}

vk_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.size.height
}

vk_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.mip_level_count
}

vk_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.sample_count
}

vk_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.size
}

vk_texture_get_texture_binding_view_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_View_Dimension {
    impl := vk_texture_get_impl(texture, loc)
    desc := impl.desc
    #partial switch desc.dimension {
    case .D1:
        return .D1
    case .D3:
        return .D3
    case .D2:
        layers := desc.size.depth_or_array_layers
        if layers == 1 {
            return .D2
        }
        if texture_descriptor_is_cube_compatible(impl.desc_impl) {
            return layers == 6 ? .Cube : .Cube_Array
        }
        return .D2_Array
    }
    return .D2
}

vk_texture_get_native_metal_texture :: proc(texture: Texture, loc := #caller_location) -> rawptr {
    return nil
}

vk_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.usage
}

vk_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.size.width
}

vk_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    impl := vk_texture_get_impl(texture, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Texture, pack_handle(impl.handle))
}

vk_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Texture, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .IMAGE, impl.vk_image, label, loc)
}

vk_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)
    add_ref(impl, loc)
}

// The full subresource range of a texture, in the tracker's count-based form.
vk_texture_full_selector :: #force_inline proc "contextless" (
    impl: ^VK_Texture_Impl,
) -> Texture_Selector {
    return {
        mip_start   = 0,
        mip_count   = impl.num_levels,
        layer_start = 0,
        layer_count = impl.num_layers,
    }
}

// The tracker entry a texture is addressed by. `Tracked_Texture` carries the
// public handle, because the tracker never dereferences it.
vk_tracked_texture :: #force_inline proc "contextless" (
    texture: Texture,
    impl: ^VK_Texture_Impl,
) -> Tracked_Texture {
    return {
        index   = impl.tracker_index,
        texture = texture,
        full    = vk_texture_full_selector(impl),
    }
}

vk_texture_release :: proc(texture: Texture, loc := #caller_location) {
    vk_texture_release_impl(texture, {}, false, loc)
}

// Releases a texture whose last use is the submission named by `wait_on`.
vk_texture_release_after :: proc(
    texture: Texture,
    wait_on: VK_Submit_Handle,
    loc := #caller_location,
) {
    impl := vk_texture_get_impl(texture, loc)
    intr.atomic_sub(&impl.deferred_holds, 1)
    vk_texture_release_impl(texture, wait_on, true, loc)
}

vk_texture_release_impl :: proc(
    texture: Texture,
    wait_on: VK_Submit_Handle,
    have_wait_on: bool,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(texture.device, loc)
    impl := dhm_get_if_valid(
        &device_impl.textures,
        unpack_handle(VK_Texture_Handle, texture.handle),
    )
    if impl == nil {
        return
    }

    if impl.is_owning_vk_image {
        // Swapchain textures are owned by the surface. A deferred-write hold
        // still took a ref; drop it without touching the surface's handle.
        if have_wait_on {
            _ = release_ref(impl, loc)
        }
        return
    }

    last := release_ref(impl, loc)

    // See `vk_buffer_release_impl`: a public release that leaves only deferred
    // holds is logically destroyed while the handle survives until the flush.
    if !have_wait_on &&
       !impl.destroyed &&
       intr.atomic_load_explicit(&impl.ref, .Acquire) ==
           intr.atomic_load_explicit(&impl.deferred_holds, .Acquire) {
        impl.destroyed = true
        intr.atomic_add(&device_impl.destroyed_resources, 1)
    }

    if last {
        if !impl.destroy_enqueued {
            deferred := VK_Deferred_Image {
                image         = impl.vk_image,
                tracker_index = impl.tracker_index,
                allocation    = impl.allocation,
                init          = impl.init,
            }
            if have_wait_on {
                vk_deferred_add_resource_after(&device_impl.deferred, deferred, wait_on, loc)
            } else {
                vk_deferred_add_resource(
                    &device_impl.deferred,
                    &device_impl.submitter,
                    deferred,
                    loc,
                )
            }
            impl.destroy_enqueued = true
        }
        vk_label_remove(&device_impl.labels, .Texture, pack_handle(impl.handle))
        if len(impl.desc.view_formats) > 0 {
            delete(impl.desc.view_formats, device_impl.allocator)
            impl.desc.view_formats = nil
        }
        remove_handle_impl(&device_impl.textures, impl.handle)
    }
}
