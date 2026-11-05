package gpu

// Handle to a texture on the GPU.
//
// It can be created with `device_create_texture()` and freed with
// `texture_release()`. `texture_destroy()` releases the native image early while
// keeping the handle valid.
//
// Use `texture_create_view()` to bind a texture or use it as a render target.
//
// Corresponds to [WebGPU `GPUTexture`](https://gpuweb.github.io/gpuweb/#texture-interface).
Texture :: distinct Handle

// Describes a `Texture`.
//
// For use with `device_create_texture()`.
//
// Corresponds to [WebGPU `GPUTextureDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gputexturedescriptor).
Texture_Descriptor :: struct {
    // Debug label of the texture.
    label:           string,
    // Size of the texture. All components must be greater than zero. For a
    // regular 1D/2D texture, the unused sizes will be 1. For 2DArray textures,
    // Z is the number of 2D textures in that array.
    size:            Extent_3D,
    // Mip count of texture. For a texture with no extra mips, this must be 1.
    // `0` is treated as 1.
    mip_level_count: u32,
    // Sample count of texture. `0` and `1` both mean a single sample; the only
    // multisampled value supported is 4.
    sample_count:    u32,
    // Dimensions of the texture. `.Undefined` is treated as `.D2`.
    dimension:       Texture_Dimension,
    // Format of the texture.
    format:          Texture_Format,
    // Allowed usages of the texture. If used in other ways, the operation will panic.
    usage:           Texture_Usages,
    // Specifies what view formats will be allowed when calling
    // `texture_create_view` on this texture.
    //
    // View formats of the same format as the texture are always allowed.
    //
    // Note: currently, only the srgb-ness is allowed to change. (ex:
    // `RGBA8_Unorm` texture + `RGBA8_Unorm_Srgb` view)
    view_formats:    []Texture_Format,
}

// Default texture descriptor: one mip level, one sample, no usage or formats.
DEFAULT_TEXTURE_DESCRIPTOR :: Texture_Descriptor {
    label           = "",
    size            = DEFAULT_EXTENT_3D,
    mip_level_count = 1,
    sample_count    = 1,
    dimension       = .Undefined,
    format          = .Undefined,
    usage           = {},
    view_formats    = {},
}

// Returns the number of array layers stored by a texture descriptor.
//
// 1D and 3D textures have one layer; 2D textures use
// `size.depth_or_array_layers`.
texture_descriptor_array_layer_count :: #force_inline proc "contextless" (
    self: Texture_Descriptor,
    loc := #caller_location,
) -> u32 {
    assert_contextless(self.dimension != .Undefined, "Invalid texture dimension", loc)
    #partial switch self.dimension {
    case .D1, .D3:
        return 1
    case .D2:
        return self.size.depth_or_array_layers
    }
    unreachable()
}

// Creates a texture.
//
// The descriptor is validated against the device limits, the format's allowed
// usages, and the dimension/multisampling rules. `dimension == .Undefined` is
// treated as `.D2`; zero `mip_level_count` and `sample_count` mean 1.
//
// Compressed textures must have block-aligned dimensions; 3D compressed
// textures additionally require the corresponding sliced-3D feature. Invalid
// descriptors are reported through the device's validation path and return `{}`.
device_create_texture: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture

// Returns the underlying Metal texture on the Metal backend, otherwise nil.
texture_get_native_metal_texture: proc(texture: Texture, loc := #caller_location) -> rawptr

// Creates a view of the texture.
//
// View formats must be the texture's own format or one listed in its
// `view_formats`; the view dimension must be compatible with the texture
// dimension, and mip/layer ranges must fit. The view holds a reference to the
// texture; release it with `texture_view_release()`.
texture_create_view: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View

// Releases the texture's native image as soon as possible.
//
// The handle stays valid until `texture_release()`, matching WebGPU semantics.
// Calling this more than once is harmless.
texture_destroy: proc(texture: Texture, loc := #caller_location)

// Returns the depth or array-layer count specified when creating the texture.
texture_get_depth_or_array_layers: proc(texture: Texture, loc := #caller_location) -> u32

// Returns the descriptor the texture was created with.
//
// The returned `view_formats` slice is borrowed from the texture and must not be
// freed. On the browser backend the label and `view_formats` are not recoverable
// and come back empty.
texture_get_descriptor: proc(texture: Texture, loc := #caller_location) -> Texture_Descriptor

// Returns the texture dimension.
texture_get_dimension: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension

// Returns the texture format.
texture_get_format: proc(texture: Texture, loc := #caller_location) -> Texture_Format

// Returns the height specified when creating the texture.
texture_get_height: proc(texture: Texture, loc := #caller_location) -> u32

// Returns the mip level count specified when creating the texture.
texture_get_mip_level_count: proc(texture: Texture, loc := #caller_location) -> u32

// Returns the sample count specified when creating the texture.
texture_get_sample_count: proc(texture: Texture, loc := #caller_location) -> u32

// Returns the size specified when creating the texture.
texture_get_size: proc(texture: Texture, loc := #caller_location) -> Extent_3D

// Returns the default view dimension for binding this texture.
//
// This is derived from the texture dimension: `.D1`, `.D3`, `.D2`, `.D2_Array`,
// or (for square, layer-count-multiple-of-6 textures) `.Cube` / `.Cube_Array`.
texture_get_texture_binding_view_dimension: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_View_Dimension

// Returns the usage flags specified when creating the texture.
texture_get_usage: proc(texture: Texture, loc := #caller_location) -> Texture_Usages

// Returns the width specified when creating the texture.
texture_get_width: proc(texture: Texture, loc := #caller_location) -> u32

// Returns the texture's debug label.
//
// The string is owned by the texture and stays valid until the next
// `texture_set_label()` or until the texture is released.
texture_get_label: proc(texture: Texture, loc := #caller_location) -> string

// Sets the texture's debug label.
//
// The texture keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
texture_set_label: proc(texture: Texture, label: string, loc := #caller_location)

// Increments the texture's reference count.
texture_add_ref: proc(texture: Texture, loc := #caller_location)

// Decrements the texture's reference count, destroying it when it reaches zero.
texture_release: proc(texture: Texture, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private
// -----------------------------------------------------------------------------

_Texture_Descriptor_Impl :: struct {
    using desc:     Texture_Descriptor,
    internal_usage: Texture_Uses,
    memory_flags:   Memory_Flags,
}

_Texture_Impl :: struct {
    using desc_impl: _Texture_Descriptor_Impl,
    device:          Device,
    tracker_index:   Tracker_Index,
    full_range:      Texture_Selector,
    destroyed:       bool,
    ref:             Ref_Count_Type,
}

_texture_get_internal_impl: proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> ^_Texture_Impl

_texture_tracker_index :: proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> Tracker_Index {
    impl := _texture_get_internal_impl(texture, loc)
    return impl.tracker_index
}

_resolve_texture_descriptor :: proc(
    device: Device,
    desc: ^Texture_Descriptor,
    loc := #caller_location,
) -> (
    _Texture_Descriptor_Impl,
    bool,
) {
    valid := true
    if desc.dimension == .Undefined {
        desc.dimension = .D2
    }
    valid &= gpu_validate(device, desc.format != .Undefined, "Invalid texture format", loc)
    valid &= gpu_validate(device, desc.usage != {}, "Texture usage flags are not set", loc)
    valid &= gpu_validate(device, desc.dimension != .Undefined, "Invalid texture dimension", loc)
    valid &= gpu_validate(device, desc.size.width > 0, "Texture width must be greater than 0", loc)
    valid &= gpu_validate(
        device,
        desc.size.height > 0,
        "Texture height must be greater than 0",
        loc,
    )
    valid &= gpu_validate(
        device,
        desc.size.depth_or_array_layers > 0,
        "Texture depth/layers must be greater than 0",
        loc,
    )

    // Zero means "the default", which is one sample.
    sample_count := desc.sample_count
    if sample_count == 0 {
        sample_count = 1
    }

    // Zero means "the default", which is one mip level.
    mip_level_count := desc.mip_level_count
    if mip_level_count == 0 {
        mip_level_count = 1
    }

    limits := _device_get_internal_impl(device, loc).limits
    #partial switch desc.dimension {
    case .D1:
        valid &= gpu_validate(
            device,
            desc.size.width <= limits.max_texture_dimension_1d,
            "1D texture width exceeds max_texture_dimension_1d",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.height == 1 && desc.size.depth_or_array_layers == 1,
            "1D textures must have height and depth/array layers of 1",
            loc,
        )
    case .D2:
        valid &= gpu_validate(
            device,
            desc.size.width <= limits.max_texture_dimension_2d,
            "2D texture width exceeds max_texture_dimension_2d",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.height <= limits.max_texture_dimension_2d,
            "2D texture height exceeds max_texture_dimension_2d",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.depth_or_array_layers <= limits.max_texture_array_layers,
            "2D texture array layers exceed max_texture_array_layers",
            loc,
        )
    case .D3:
        valid &= gpu_validate(
            device,
            desc.size.width <= limits.max_texture_dimension_3d,
            "3D texture width exceeds max_texture_dimension_3d",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.height <= limits.max_texture_dimension_3d,
            "3D texture height exceeds max_texture_dimension_3d",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.depth_or_array_layers <= limits.max_texture_dimension_3d,
            "3D texture depth exceeds max_texture_dimension_3d",
            loc,
        )
    }

    // Validate mip levels don't exceed maximum possible
    max_depth := desc.dimension == .D3 ? desc.size.depth_or_array_layers : 1
    max_levels := max_mip_levels(desc.size.width, desc.size.height, max_depth)
    valid &= gpu_validate(
        device,
        mip_level_count <= max_levels,
        "Mip level count exceeds maximum possible for this texture size",
        loc,
    )

    // Format-specific feature validation
    format_features, format_features_ok := device_describe_format_features(
        device,
        desc.format,
        loc,
    )
    valid &= gpu_validate(device, format_features_ok, "Missing format features", loc)
    valid &= gpu_validate(
        device,
        (desc.usage & format_features.allowed_usages) == desc.usage,
        "Requested usage flags are not supported for this format on this device",
        loc,
    )

    if desc.dimension == .D3 && texture_format_is_compressed(desc.format) {
        required := texture_format_required_features(desc.format, loc)
        features := device_get_features(device, loc)
        sliced_ok := false
        if required == .Texture_Compression_BC {
            sliced_ok = has_features(features[:], {.Texture_Compression_BC_Sliced_3D})
        } else if required == .Texture_Compression_ASTC {
            sliced_ok = has_features(features[:], {.Texture_Compression_ASTC_Sliced_3D})
        }
        valid &= gpu_validate(
            device,
            sliced_ok,
            "3D compressed textures require the sliced-3D feature",
            loc,
        )
    }

    if desc.dimension != .D2 {
        valid &= gpu_validate(
            device,
            !texture_format_is_depth_stencil_format(desc.format),
            "Depth textures can only be 2D",
            loc,
        )
    }

    if desc.dimension != .D2 && desc.dimension != .D3 {
        valid &= gpu_validate(
            device,
            !texture_format_is_compressed(desc.format),
            "Compressed textures can only be 2D or 3D",
            loc,
        )
        valid &= gpu_validate(
            device,
            .Render_Attachment not_in desc.usage,
            "Renderable textures can only be 2D or 3D",
            loc,
        )
    }

    // Validate multisampling constraints
    if sample_count > 1 {
        valid &= gpu_validate(
            device,
            mip_level_count == 1,
            "Multisampled textures must have exactly 1 mip level",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.dimension == .D2,
            "Only 2D textures can be multisampled",
            loc,
        )
        valid &= gpu_validate(
            device,
            desc.size.depth_or_array_layers == 1,
            "Multisampled textures must have a single layer",
            loc,
        )
        valid &= gpu_validate(
            device,
            .Storage_Binding not_in desc.usage,
            "Multisampled textures cannot be storage bindings",
            loc,
        )
        valid &= gpu_validate(device, sample_count == 4, "Only 4x multisampling is supported", loc)
    }

    for view_format in desc.view_formats {
        view_features, view_ok := device_describe_format_features(device, view_format, loc)
        valid &= gpu_validate(device, view_ok, "Unsupported texture view format", loc)
        valid &= gpu_validate(
            device,
            view_features.allowed_usages & desc.usage == desc.usage,
            "View format does not support the texture's usages",
            loc,
        )
        valid &= gpu_validate(
            device,
            texture_format_remove_srgb_suffix(view_format) ==
            texture_format_remove_srgb_suffix(desc.format),
            "Texture view format is not compatible with the texture format",
            loc,
        )
    }

    if texture_format_is_compressed(desc.format) {
        block_width, block_height := texture_format_block_dimensions(desc.format)

        valid &= gpu_validate(
            device,
            is_multiple_of(desc.size.width, block_width),
            "Texture width is not multiple of block width",
            loc,
        )
        valid &= gpu_validate(
            device,
            is_multiple_of(desc.size.height, block_height),
            "Texture height is not multiple of block height",
            loc,
        )

        if desc.dimension == .D3 {
            if texture_format_is_bcn(desc.format) {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Texture_Compression_BC_Sliced_3D),
                    "Only BCn formats with Sliced 3D feature can be used for 3D textures",
                    loc,
                )
            } else if texture_format_is_astc(desc.format, loc) {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Texture_Compression_ASTC_Sliced_3D),
                    "Only Astc formats with Sliced 3D feature can be used for 3D textures",
                    loc,
                )
            } else {
                valid &= gpu_validate(device, false, "Invalid compressed dimension", loc)
            }
        }
    }

    if !valid {
        return {}, false
    }

    internal_usage := map_texture_usage_for_texture(desc^, format_features)

    internal_desc := _Texture_Descriptor_Impl {
        label           = desc.label,
        size            = desc.size,
        mip_level_count = mip_level_count,
        sample_count    = sample_count,
        dimension       = desc.dimension,
        format          = desc.format,
        usage           = desc.usage,
        internal_usage  = internal_usage,
        memory_flags    = {},
        view_formats    = desc.view_formats,
    }

    return internal_desc, true
}
