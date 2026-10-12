#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
import "lib/vma"
import gpua "allocator"
import vk "vendor:vulkan"

VK_Texture_Memory_Allocation :: union {
    gpua.VK_Allocation,
    vma.Allocation,
}

VK_Texture_Handle :: distinct hm.Handle64

VK_Texture_Impl :: struct {
    using base:            Texture_Impl,
    allocation:            VK_Texture_Memory_Allocation,
    vk_format_properties:  vk.FormatProperties,
    vk_extent:             vk.Extent3D,
    surface:               Surface,
    vk_image:              vk.Image,
    texture_view:          Texture_View,
    mapped_ptr:            rawptr,
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
    // Swapchain image position. Only meaningful when is_swapchain is set;
    // lets later phases resolve (surface, image) from the texture alone
    // without taking the surface lock.
    swapchain_index:       u32,
}

vk_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    impl := vk_device_get_impl(device, loc)
    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

    // Get the descriptor implementation
    desc := resolve_texture_descriptor(device, descriptor, loc)

    // Set create flags
    vk_create_flags: vk.ImageCreateFlags

    // 3D textures used as color targets need 2D array compatible for slice rendering
    if desc.dimension == .D3 && .Color_Target in desc.internal_usage {
        vk_create_flags += {.D2_ARRAY_COMPATIBLE}
    }

    // Cubemap support
    if texture_descriptor_is_cube_compatible(desc) {
        vk_create_flags += { .CUBE_COMPATIBLE }
    }

    // View format reinterpretation requires mutable format
    if len(desc.view_formats) > 0 {
        vk_create_flags += {.MUTABLE_FORMAT}
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
    if view_format_count > 0 {

        vk_view_formats = make([dynamic]vk.Format, 0, view_format_count+1, ta)

        for f in desc.view_formats {
            append(&vk_view_formats, vk_conv_to_format(adapter_impl.caps, f))
        }
        // Include the base format itself
        append(&vk_view_formats, vk_format)

        vk_format_list_info = vk.ImageFormatListCreateInfo{
            sType           = .IMAGE_FORMAT_LIST_CREATE_INFO,
            viewFormatCount = view_format_count,
            pViewFormats    = raw_data(vk_view_formats),
        }
        image_create_info.pNext = &vk_format_list_info
    }

    vk_image: vk.Image

    when USE_VMA {
        vma_alloc_info := vma.AllocationCreateInfo{
            usage          = .AUTO,
            requiredFlags  = {.DEVICE_LOCAL},
            memoryTypeBits = impl.valid_memory_type_bits,
        }
        vma_allocation: vma.Allocation
        vk_check(vma.CreateImage(
            impl.vma_allocator,
            image_create_info,
            vma_alloc_info,
            &vk_image,
            &vma_allocation,
            nil,
        ))
    } else {
        // Create the image
        vk_check(impl.fp.CreateImage(impl.vk_device, &image_create_info, nil, &vk_image))

        // Allocate memory
        requirements: vk.MemoryRequirements
        impl.fp.GetImageMemoryRequirements(impl.vk_device, vk_image, &requirements)

        masked_requirements := requirements
        masked_requirements.memoryTypeBits &= impl.valid_memory_type_bits
        assert(masked_requirements.memoryTypeBits != 0,
            "VULKAN: no valid memory type for image allocation", loc)

        alloc_desc := gpua.VK_Allocation_Create_Desc{
            name              = desc.label,
            requirements      = masked_requirements,
            location          = .Gpu_Only,
            linear            = false,
            allocation_scheme = gpua.VK_ALLOCATION_SCHEME_MANAGED,
        }

        gpu_allocation: gpua.VK_Allocation
        gpua.gpu_alloc_check(gpua.vk_allocator_allocate(
            &impl.gpu_allocator, alloc_desc, &gpu_allocation, loc))

        // Bind memory
        vk_check(impl.fp.BindImageMemory(
            impl.vk_device,
            vk_image,
            gpu_allocation.device_memory,
            vk.DeviceSize(gpu_allocation.offset)))
    }

    assert(vk_image != {}, "VULKAN: Failed to create vk.Image", loc)

    tracker_index := shared_tracker_index_allocator_alloc(
        &impl.tracker_indices.textures)

    texture_impl, texture_handle := add_impl(&impl.textures, VK_Texture_Impl{
        // From descriptor
        desc_impl                  = desc,
        // usage                 = desc.usage,
        // dimension             = desc.dimension,
        // size                  = desc.size,
        // format                = desc.format,
        // mip_level_count       = desc.mip_level_count,
        // sample_count          = desc.sample_count,

        // Backend
        vk_format_properties  = {},
        vk_extent             = vk_extent,
        device                = device,
        tracker_index         = tracker_index,
        full_range            = Texture_Selector{
            mips   = {0, desc.mip_level_count},
            layers = {0, image_create_info.arrayLayers},
        },
        vk_image              = vk_image,
        vk_usage_flags        = vk_image_usage_flags,
        vk_type               = vk_image_type,
        vk_image_format       = vk_format,
        vk_samples            = vk_samples,
        num_levels            = desc.mip_level_count,
        num_layers            = image_create_info.arrayLayers,
        is_owning_vk_image    = false,
        is_resolve_attachment = false,
        is_depth_format       = texture_format_has_depth_aspect(desc.format),
        is_stencil_format     = texture_format_has_stencil_aspect(desc.format),
        is_swapchain          = false,
    })

    when USE_VMA {
        texture_impl.allocation = vma_allocation
    } else {
        texture_impl.allocation = gpu_allocation
    }

    // The image is created with initialLayout .UNDEFINED, so its contents are
    // discarded and every subresource starts in the undefined layout.
    device_texture_tracker_insert_single(
        &impl.trackers.textures,
        texture_impl.tracker_index,
        new_handle(Texture, device, texture_handle),
        {.Uninitialized},
        loc,
    )

    return new_handle(Texture, device, texture_handle)
}

@(require_results)
vk_texture_get_public_impl :: #force_inline proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> ^Texture_Impl {
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

vk_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View {
    impl := vk_texture_get_impl(texture, loc)

    if impl.is_owning_vk_image {
        return impl.texture_view
    } else {
        device_impl := vk_device_get_impl(impl.device, loc)
        adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

        desc := resolve_texture_view_descriptor(texture, impl.device, descriptor, loc)

        vk_image_view := vk_texture_create_image_view(impl,
            type        = vk_conv_to_image_view_type(desc.dimension),
            format      = vk_conv_to_format(adapter_impl.caps, desc.format),
            aspect_mask = vk_conv_to_image_aspect_flags(desc.range.aspect, desc.format),
            base_level  = desc.range.base_mip_level,
            num_levels  = desc.range.mip_level_count,
            base_layer  = desc.range.base_array_layer,
            num_layers  = desc.range.array_layer_count,
            // debug_name  = desc.label,
        )

        _, texture_view_handle := add_impl(&device_impl.texture_views, VK_Texture_View_Impl {
            device            = impl.device,
            texture           = texture,
            vk_image_view     = vk_image_view,
            is_swapchain      = false,
            format            = desc.format,
            dimension         = desc.dimension,
            usage             = desc.usage,
            aspect            = desc.range.aspect,
            // `Texture_Selector` uses the tracker's exclusive `[start, end)`
            // convention, not the descriptor's `{start, count}`.
            selector          = {
                mips   = {
                    desc.range.base_mip_level,
                    desc.range.base_mip_level + desc.range.mip_level_count,
                },
                layers = {
                    desc.range.base_array_layer,
                    desc.range.base_array_layer + desc.range.array_layer_count,
                },
            },
        })

        vk_texture_add_ref(texture, loc)

        return new_handle(Texture_View, impl.device, texture_view_handle)
    }
}

vk_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
    unimplemented(loc = loc)
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

vk_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.usage
}

vk_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := vk_texture_get_impl(texture, loc)
    return impl.desc.size.width
}

vk_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)
    add_ref(impl, loc)
}

// Tracker references keep ordinary textures alive until their usage tracker is
// cleared. Swapchain images are externally owned and are removed explicitly by
// swapchain teardown, so tracker retains/releases for them are intentionally
// no-ops. A command-buffer tracker can be cleared after that teardown, so the
// release hook also tolerates the already-removed external texture handle.
vk_tracker_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)
    if !impl.is_owning_vk_image {
        add_ref(impl, loc)
    }
}

vk_tracker_texture_release :: proc(texture: Texture, loc := #caller_location) {
    device_impl := vk_device_get_impl(texture.device, loc)
    impl, ok := hm.dynamic_get(
        &device_impl.textures.resources,
        unpack_handle(VK_Texture_Handle, texture.handle),
    )
    if !ok || impl.is_owning_vk_image {
        return
    }
    vk_texture_release(texture, loc)
}

vk_texture_release :: proc(texture: Texture, loc := #caller_location) {
    impl := vk_texture_get_impl(texture, loc)

    if impl.is_owning_vk_image {
        return
    }

    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
            VK_Deferred_Image{impl.vk_image, impl.tracker_index, impl.allocation})
        remove_handle_impl(&device_impl.textures, impl.handle)
    }
}
