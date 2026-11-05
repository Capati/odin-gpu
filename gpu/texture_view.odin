package gpu

// Core
import intr "base:intrinsics"

// Handle to a texture view.
//
// A `Texture_View` object refers to a `Texture`, or a subset of its layers and
// mip levels, and specifies an interpretation of the texture’s texels, which is
// needed to use a texture as a binding in a `Bind_Group` or as an attachment in
// a `Render_Pass`. It can be created using `texture_create_view()`, which
// accepts a `Texture_View_Descriptor` specifying the properties of the view.
//
// Corresponds to [WebGPU
// `GPUTextureView`](https://gpuweb.github.io/gpuweb/#gputextureview).
Texture_View :: distinct Handle

// Describes a `Texture_View`.
//
// For use with `texture_create_view()`.
//
// Corresponds to [WebGPU `GPUTextureViewDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gputextureviewdescriptor).
Texture_View_Descriptor :: struct {
    // Debug label of the texture view.
    label:             string,
    // Format of the texture view. Either must be the same as the texture format
    // or in the list of `view_formats` in the texture's descriptor.
    format:            Texture_Format,
    // The dimension of the texture view. For 1D textures, this must be `D1`.
    // For 2D textures it must be one of `D2`, `D2_Array`, `Cube`, and
    // `Cube_Array`. For 3D textures it must be `D3`.
    //
    // `Undefined` (the zero value) resolves from the texture's dimension.
    dimension:         Texture_View_Dimension,
    // The allowed usage(s) for the texture view. Must be a subset of the usage
    // flags of the texture. If not provided, defaults to the full set of usage
    // flags of the texture.
    usage:             Texture_Usages,
    // Aspect of the texture. Color textures must be `All`.
    aspect:            Texture_Aspect,
    // Base mip level.
    base_mip_level:    u32,
    // Mip level count.
    //
    // If non-zero, `base_mip_level + mip_level_count` must be less than or equal
    // to the underlying texture mip count. If zero or
    // `MIP_LEVEL_COUNT_UNDEFINED`, includes all remaining mipmap levels, but at
    // least 1 in total.
    mip_level_count:   u32,
    // Base array layer.
    base_array_layer:  u32,
    // Layer count.
    //
    // If non-zero, `base_array_layer + array_layer_count` must be less or equal
    // to the underlying array count. If zero or `ARRAY_LAYER_COUNT_UNDEFINED`,
    // includes the rest of the array layers, but at least 1 in total.
    array_layer_count: u32,
    // Component swizzle. Requires the `Texture_Component_Swizzle` feature when
    // any component is not `Undefined`.
    swizzle:           Texture_Component_Swizzle,
}

// Default texture view descriptor: inherit the texture's format, dimension,
// usage, and full mip/layer ranges.
DEFAULT_TEXTURE_VIEW_DESCRIPTOR :: Texture_View_Descriptor {
    label             = "",
    format            = .Undefined,
    dimension         = .Undefined,
    base_mip_level    = 0,
    mip_level_count   = MIP_LEVEL_COUNT_UNDEFINED,
    base_array_layer  = 0,
    array_layer_count = ARRAY_LAYER_COUNT_UNDEFINED,
    aspect            = .All,
    usage             = {},
    swizzle           = {},
}

// Returns the texture this view refers to.
//
// The returned handle is borrowed from the view; do not release it.
texture_view_get_texture: proc(texture_view: Texture_View, loc := #caller_location) -> Texture

// Returns the texture view's debug label.
//
// The string is owned by the texture view and stays valid until the next
// `texture_view_set_label()` or until the texture view is released.
texture_view_get_label: proc(texture_view: Texture_View, loc := #caller_location) -> string

// Sets the texture view's debug label.
//
// The texture view keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
texture_view_set_label: proc(texture_view: Texture_View, label: string, loc := #caller_location)

// Increments the texture view's reference count.
texture_view_add_ref: proc(texture_view: Texture_View, loc := #caller_location)

// Decrements the texture view's reference count, destroying it when it reaches
// zero.
texture_view_release: proc(texture_view: Texture_View, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Texture_View_Impl :: struct {
    texture:      Texture,
    device:       Device,
    selector:     Texture_Selector,
    format:       Texture_Format,
    dimension:    Texture_View_Dimension,
    usage:        Texture_Uses,
    aspect:       Texture_Aspect,
    swizzle:      Texture_Component_Swizzle,
    // The public usage set this view was narrowed to (empty input resolves to
    // the texture's full set).
    public_usage: Texture_Usages,
    ref:          Ref_Count_Type,
}

_texture_view_get_internal_impl: proc "contextless" (
    texture_view: Texture_View,
    loc := #caller_location,
) -> ^_Texture_View_Impl

_Texture_View_Descriptor_Impl :: struct {
    label:     string,
    format:    Texture_Format,
    dimension: Texture_View_Dimension,
    usage:     Texture_Uses,
    range:     Image_Subresource_Range,
    swizzle:   Texture_Component_Swizzle,
}

// Resolve defaults
//
// https://gpuweb.github.io/gpuweb/#abstract-opdef-resolving-gputextureviewdescriptor-defaults
_resolve_texture_view_descriptor :: proc(
    texture: Texture,
    device: Device,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> (
    _Texture_View_Descriptor_Impl,
    bool,
) {
    texture_impl := _texture_get_internal_impl(texture, loc)
    if texture_impl.destroyed {
        gpu_report_validation_error(device, "texture has been destroyed", loc)
        return {}, false
    }

    // Get the texture descriptor to inherit information
    texture_desc := texture_get_descriptor(texture, loc)

    valid := true

    swizzle := descriptor.swizzle
    if swizzle != {} {
        valid &= gpu_validate(
            device,
            has_features(
                _device_get_internal_impl(device, loc).features[:],
                {.Texture_Component_Swizzle},
            ),
            "texture view swizzle requires the [Texture_Component_Swizzle] feature",
            loc,
        )
    }

    // Resolve texture aspect
    aspect := descriptor.aspect
    aspects := texture_format_aspects_from(texture_desc.format)
    aspect_ok := true
    switch aspect {
    case .All:
    case .Depth_Only:
        aspect_ok = .Depth in aspects
    case .Stencil_Only:
        aspect_ok = .Stencil in aspects
    case .Plane0:
        aspect_ok = .Plane0 in aspects
    case .Plane1:
        aspect_ok = .Plane1 in aspects
    case .Plane2:
        aspect_ok = .Plane2 in aspects
    }
    valid &= gpu_validate(
        device,
        aspect_ok,
        "texture aspect is not present in the texture format",
        loc,
    )

    // Resolve texture format
    resolved_format := descriptor.format
    if resolved_format == .Undefined {
        resolved_format = texture_format_aspect_specific_format(texture_desc.format, aspect, loc)
    } else {
        own_format :=
            resolved_format == texture_desc.format ||
            resolved_format ==
                texture_format_aspect_specific_format(texture_desc.format, aspect, loc)
        listed_format := false
        for view_format in texture_desc.view_formats {
            if resolved_format == view_format {
                listed_format = true
                break
            }
        }
        valid &= gpu_validate(
            device,
            own_format || listed_format,
            "texture view format is neither the texture's own nor one of its view formats",
            loc,
        )
    }

    // Resolve texture view dimension
    resolved_dimension := descriptor.dimension
    if resolved_dimension == .Undefined {
        #partial switch texture_desc.dimension {
        case .D1:
            resolved_dimension = .D1
        case .D2:
            if texture_descriptor_array_layer_count(texture_desc) == 1 {
                resolved_dimension = .D2
            } else {
                resolved_dimension = .D2_Array
            }
        case .D3:
            resolved_dimension = .D3
        }
    }
    dimension_ok := false
    #partial switch texture_desc.dimension {
    case .D1:
        dimension_ok = resolved_dimension == .D1
    case .D2:
        dimension_ok =
            resolved_dimension == .D2 ||
            resolved_dimension == .D2_Array ||
            resolved_dimension == .Cube ||
            resolved_dimension == .Cube_Array
    case .D3:
        dimension_ok = resolved_dimension == .D3
    case:
        dimension_ok = true
    }
    valid &= gpu_validate(
        device,
        dimension_ok,
        "texture view dimension is not compatible with the texture dimension",
        loc,
    )

    // Resolve mip level count. `0` and `MIP_LEVEL_COUNT_UNDEFINED` mean "the
    // rest of the mip chain".
    mip_count_unspecified :=
        descriptor.mip_level_count == 0 || descriptor.mip_level_count == MIP_LEVEL_COUNT_UNDEFINED
    resolved_mip_level_count :=
        descriptor.mip_level_count if !mip_count_unspecified else intr.saturating_sub(texture_desc.mip_level_count, descriptor.base_mip_level)
    valid &= gpu_validate(
        device,
        descriptor.base_mip_level <= texture_desc.mip_level_count &&
        resolved_mip_level_count > 0 &&
        resolved_mip_level_count <= texture_desc.mip_level_count - descriptor.base_mip_level,
        "texture view mip range is out of bounds",
        loc,
    )

    // Resolve array layer count. `0` and `ARRAY_LAYER_COUNT_UNDEFINED` mean
    // "the rest of the layers".
    array_count_unspecified :=
        descriptor.array_layer_count == 0 ||
        descriptor.array_layer_count == ARRAY_LAYER_COUNT_UNDEFINED
    resolved_array_layer_count := descriptor.array_layer_count
    if array_count_unspecified {
        #partial switch resolved_dimension {
        case .D1, .D2, .D3:
            resolved_array_layer_count = 1
        case .Cube:
            resolved_array_layer_count = 6
        case .D2_Array, .Cube_Array:
            resolved_array_layer_count = intr.saturating_sub(
                texture_descriptor_array_layer_count(texture_desc),
                descriptor.base_array_layer,
            )
        case:
            unreachable()
        }
    }

    texture_layers := texture_descriptor_array_layer_count(texture_desc)
    valid &= gpu_validate(
        device,
        descriptor.base_array_layer <= texture_layers &&
        resolved_array_layer_count > 0 &&
        resolved_array_layer_count <= texture_layers - descriptor.base_array_layer,
        "texture view layer range is out of bounds",
        loc,
    )

    // A 2D view covering multiple layers is a 2D-array view.
    if resolved_dimension == .D2 && resolved_array_layer_count > 1 {
        resolved_dimension = .D2_Array
    }

    is_cube := resolved_dimension == .Cube || resolved_dimension == .Cube_Array
    if is_cube {
        valid &= gpu_validate(
            device,
            resolved_array_layer_count == 6 ||
            (resolved_dimension == .Cube_Array && resolved_array_layer_count % 6 == 0),
            "cube views must cover whole sets of six layers",
            loc,
        )
        valid &= gpu_validate(
            device,
            descriptor.base_array_layer % 6 == 0,
            "cube views must start at a multiple of six layers",
            loc,
        )
        valid &= gpu_validate(
            device,
            texture_desc.size.width == texture_desc.size.height,
            "cube views require a square texture",
            loc,
        )
    }

    // resolve usage
    resolved_usage: Texture_Usages
    if descriptor.usage == {} {
        resolved_usage = texture_desc.usage
    } else {
        valid &= gpu_validate(
            device,
            texture_desc.usage & descriptor.usage == descriptor.usage,
            "texture view usage must be a subset of the texture's usages",
            loc,
        )
        resolved_usage = descriptor.usage
    }

    if !valid {
        return {}, false
    }

    format_features := device_texture_format_features(device, resolved_format, loc)
    format_aspects := texture_format_aspects_from(resolved_format)
    resolved_uses := map_texture_usage(resolved_usage, format_aspects, format_features.flags, loc)
    mask_copy := Texture_Uses(~(Texture_Uses{.Copy_Src, .Copy_Dst}))
    mask_dimension: Texture_Uses
    #partial switch resolved_dimension {
    case .Cube, .Cube_Array:
        mask_dimension = {.Resource}
    case .D3:
        mask_dimension = {
            .Resource,
            .Storage_Read_Only,
            .Storage_Write_Only,
            .Storage_Read_Write,
        }
    case:
        mask_dimension = ~Texture_Uses{}
    }
    mask_mip := ~Texture_Uses{} if resolved_mip_level_count == 1 else Texture_Uses{.Resource}
    usage := resolved_uses & mask_copy & mask_dimension & mask_mip

    // Use the combined depth-stencil format for the view
    format := resolved_format
    if texture_format_is_depth_stencil_component(format, texture_desc.format, loc) {
        format = texture_desc.format
    }

    // Resolve image sub resource range
    resolved_range := Image_Subresource_Range {
        aspect            = aspect,
        base_mip_level    = descriptor.base_mip_level,
        mip_level_count   = resolved_mip_level_count,
        base_array_layer  = descriptor.base_array_layer,
        array_layer_count = resolved_array_layer_count,
    }

    // Create the final descriptor
    desc_impl := _Texture_View_Descriptor_Impl {
        label     = descriptor.label,
        format    = format,
        dimension = resolved_dimension,
        usage     = usage,
        range     = resolved_range,
        swizzle   = swizzle,
    }

    return desc_impl, true
}
