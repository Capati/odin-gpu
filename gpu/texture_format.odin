package gpu

// Core
import "core:slice"

Texture_Format :: enum i32 {
    // WebGPU
    Undefined,
    R8_Unorm,
    R8_Snorm,
    R8_Uint,
    R8_Sint,
    R16_Unorm,
    R16_Snorm,
    R16_Uint,
    R16_Sint,
    R16_Float,
    RG8_Unorm,
    RG8_Snorm,
    RG8_Uint,
    RG8_Sint,
    R32_Float,
    R32_Uint,
    R32_Sint,
    RG16_Unorm,
    RG16_Snorm,
    RG16_Uint,
    RG16_Sint,
    RG16_Float,
    RGBA8_Unorm,
    RGBA8_Unorm_Srgb,
    RGBA8_Snorm,
    RGBA8_Uint,
    RGBA8_Sint,
    BGRA8_Unorm,
    BGRA8_Unorm_Srgb,
    RGB10A2_Uint,
    RGB10A2_Unorm,
    RG11B10_Ufloat,
    RGB9E5_Ufloat,
    RG32_Float,
    RG32_Uint,
    RG32_Sint,
    RGBA16_Unorm,
    RGBA16_Snorm,
    RGBA16_Uint,
    RGBA16_Sint,
    RGBA16_Float,
    RGBA32_Float,
    RGBA32_Uint,
    RGBA32_Sint,
    Stencil8,
    Depth16_Unorm,
    Depth24Plus,
    Depth24Plus_Stencil8,
    Depth32_Float,
    Depth32Float_Stencil8,
    BC1RGBA_Unorm,
    BC1RGBA_Unorm_Srgb,
    BC2RGBA_Unorm,
    BC2RGBA_Unorm_Srgb,
    BC3RGBA_Unorm,
    BC3RGBA_Unorm_Srgb,
    BC4R_Unorm,
    BC4R_Snorm,
    BC5RG_Unorm,
    BC5RG_Snorm,
    BC6HRGB_Ufloat,
    BC6HRGB_Float,
    BC7RGBA_Unorm,
    BC7RGBA_Unorm_Srgb,
    ETC2RGB8_Unorm,
    ETC2RGB8_Unorm_Srgb,
    ETC2RGB8A1_Unorm,
    ETC2RGB8A1_Unorm_Srgb,
    ETC2RGBA8_Unorm,
    ETC2RGBA8_Unorm_Srgb,
    EACR11_Unorm,
    EACR11_Snorm,
    EACRG11_Unorm,
    EACRG11_Snorm,
    ASTC4x4_Unorm,
    ASTC4x4_Unorm_Srgb,
    ASTC5x4_Unorm,
    ASTC5x4_Unorm_Srgb,
    ASTC5x5_Unorm,
    ASTC5x5_Unorm_Srgb,
    ASTC6x5_Unorm,
    ASTC6x5_Unorm_Srgb,
    ASTC6x6_Unorm,
    ASTC6x6_Unorm_Srgb,
    ASTC8x5_Unorm,
    ASTC8x5_Unorm_Srgb,
    ASTC8x6_Unorm,
    ASTC8x6_Unorm_Srgb,
    ASTC8x8_Unorm,
    ASTC8x8_Unorm_Srgb,
    ASTC10x5_Unorm,
    ASTC10x5_Unorm_Srgb,
    ASTC10x6_Unorm,
    ASTC10x6_Unorm_Srgb,
    ASTC10x8_Unorm,
    ASTC10x8_Unorm_Srgb,
    ASTC10x10_Unorm,
    ASTC10x10_Unorm_Srgb,
    ASTC12x10_Unorm,
    ASTC12x10_Unorm_Srgb,
    ASTC12x12_Unorm,
    ASTC12x12_Unorm_Srgb,

    // Native
    NV12,
    P010,
}

// Returns the aspect-specific format of the original format.
texture_format_aspect_specific_format :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect,
    loc := #caller_location,
) -> Texture_Format {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .Stencil8:
        if aspect == .Stencil_Only {
            return format
        }
    case .Depth16_Unorm, .Depth24Plus, .Depth32_Float:
        if aspect == .Depth_Only {
            return format
        }
    case .Depth24Plus_Stencil8:
        if aspect == .Stencil_Only {
            return .Stencil8
        }
        if aspect == .Depth_Only {
            return .Depth24Plus
        }
    case .Depth32Float_Stencil8:
        if aspect == .Stencil_Only {
            return .Stencil8
        }
        if aspect == .Depth_Only {
            return .Depth32_Float
        }
    case .NV12:
        if aspect == .Plane0 {
            return .R8_Unorm
        }
        if aspect == .Plane1 {
            return .RG8_Unorm
        }
    case .P010:
        if aspect == .Plane0 {
            return .R16_Unorm
        }
        if aspect == .Plane1 {
            return .RG16_Unorm
        }
    }

    // views to multi-planar formats must specify the plane
    if aspect == .All && !texture_format_is_multi_planar(format) {
        return format
    }

    return .Undefined
}

// Returns true if `format` is a depth or stencil component of the given
// combined depth-stencil format.
texture_format_is_depth_stencil_component :: proc "contextless" (
    format: Texture_Format,
    combined_format: Texture_Format,
    loc := #caller_location,
) -> bool {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch combined_format {
    case .Depth24Plus_Stencil8:
        return format == .Depth24Plus || format == .Stencil8
    case .Depth32Float_Stencil8:
        return format == .Depth32_Float || format == .Stencil8
    }
    return false
}

// Returns `true` if the format is a depth and/or stencil format.
texture_format_is_depth_stencil_format :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    channels := texture_format_channels(format, loc)
    return card(channels & TEXTURE_CHANNEL_DEPTH_STENCIL) > 0
}

// Returns `true` if the format is a combined depth-stencil format
texture_format_is_combined_depth_stencil_format :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    channels := texture_format_channels(format, loc)
    return (channels & TEXTURE_CHANNEL_DEPTH_STENCIL) == TEXTURE_CHANNEL_DEPTH_STENCIL
}

// Returns `true` if the format is a multi-planar format.
texture_format_is_multi_planar :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return texture_format_planes(format, loc) != 0
}

// Returns the number of planes a multi-planar format has.
texture_format_planes :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> u32 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .NV12:
        return 2
    case .P010:
        return 2
    case:
        return 0
    }
}

// Returns the subsampling factor for the indicated plane of a multi-planar format.
texture_format_subsampling_factors :: proc "contextless" (
    format: Texture_Format,
    plane: u32,
    loc := #caller_location,
) -> (u32, u32) {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .NV12, .P010:
        switch plane {
        case 0:
            return 1, 1
        case 1:
            return 2, 2
        case:
            panic_contextless("plane is not valid for this format, " +
                "or was not specified for a multi-planar format", loc)
        }
    }
    return 1, 1
}

// Represents the different format channels of a texture format.
Texture_Channel :: enum i32 {
    // Texture format contains a `red` channel.
    Red,
    // Texture format contains a `green` channel.
    Green,
    // Texture format contains a `blue` channel.
    Blue,
    // Texture format contains a `alpha` channel.
    Alpha,
    // Texture format contains a `stencil` channel.
    Stencil,
    // Texture format contains a `depth` channel.
    Depth,
    // Texture format contains a `luminance` channel.
    Luminance,
    // Texture format contains a `blue-difference` channel.
    Chrominance_Blue,
    // Texture format contains a `red-difference` channel.
    Chrominance_Red,
}

// Represents the different format channels of a texture format.
Texture_Channels                      :: bit_set[Texture_Channel;u16]

// Texture format contains channels for `red`.
TEXTURE_CHANNEL_R                     :: Texture_Channels{.Red}

// Texture format contains channels for `red` and `green`.
TEXTURE_CHANNEL_RG                    :: Texture_Channels{.Red, .Green}

// Texture format contains channels for `red`, `green` and `blue`.
TEXTURE_CHANNEL_RGB                   :: Texture_Channels{.Red, .Green, .Blue}

// Texture format contains channels for `red`, `green`, `blue` and `alpha`.
TEXTURE_CHANNEL_RGBA                  :: Texture_Channels{.Red, .Green, .Blue, .Alpha}

// Texture format contains channels for `depth`.
TEXTURE_CHANNEL_DEPTH                 :: Texture_Channels{.Depth}

// Texture format contains channels for `stencil`.
TEXTURE_CHANNEL_STENCIL               :: Texture_Channels{.Stencil}

// Texture format contains channels for `depth` and `stencil`.
TEXTURE_CHANNEL_DEPTH_STENCIL         :: Texture_Channels{.Depth, .Stencil}

// Texture format contains a `luminance` (`Y`), `blue-difference` (`Cb`) and
// `red-difference` (`Cr`) channel.
TEXTURE_CHANNEL_LUMINANCE_CHROMINANCE :: Texture_Channels {
    .Luminance,
    .Chrominance_Blue,
    .Chrominance_Red,
}

// Returns a `Texture_Channels` where the texture format contains.
//
// Returns the respective channels.
texture_format_channels :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Channels {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm,
         .R8_Snorm,
         .R8_Uint,
         .R8_Sint,
         .R16_Uint,
         .R16_Sint,
         .R16_Unorm,
         .R16_Snorm,
         .R32_Uint,
         .R32_Sint,
         .R32_Float,
         .R16_Float,
         .BC4R_Unorm,
         .BC4R_Snorm,
         .EACR11_Unorm,
         .EACR11_Snorm:
        return TEXTURE_CHANNEL_R

    case .RG8_Unorm,
         .RG8_Snorm,
         .RG8_Uint,
         .RG8_Sint,
         .RG16_Uint,
         .RG16_Sint,
         .RG16_Unorm,
         .RG16_Snorm,
         .RG16_Float,
         .RG32_Uint,
         .RG32_Sint,
         .RG32_Float,
         .BC5RG_Unorm,
         .BC5RG_Snorm,
         .EACRG11_Unorm,
         .EACRG11_Snorm:
        return TEXTURE_CHANNEL_RG

    case .RGB9E5_Ufloat,
         .RG11B10_Ufloat,
         .BC6HRGB_Ufloat,
         .BC6HRGB_Float,
         .ETC2RGB8_Unorm,
         .ETC2RGB8_Unorm_Srgb:
        return TEXTURE_CHANNEL_RGB

    case .RGBA8_Unorm,
         .RGBA8_Unorm_Srgb,
         .RGBA8_Snorm,
         .RGBA8_Uint,
         .RGBA8_Sint,
         .BGRA8_Unorm,
         .BGRA8_Unorm_Srgb,
         .RGB10A2_Uint,
         .RGB10A2_Unorm,
         .RGBA16_Uint,
         .RGBA16_Sint,
         .RGBA16_Unorm,
         .RGBA16_Snorm,
         .RGBA16_Float,
         .RGBA32_Uint,
         .RGBA32_Sint,
         .RGBA32_Float,
         .BC1RGBA_Unorm,
         .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm,
         .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm,
         .BC3RGBA_Unorm_Srgb,
         .BC7RGBA_Unorm,
         .BC7RGBA_Unorm_Srgb,
         .ETC2RGB8A1_Unorm,
         .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm,
         .ETC2RGBA8_Unorm_Srgb:
        return TEXTURE_CHANNEL_RGBA

    case .ASTC4x4_Unorm,
         .ASTC4x4_Unorm_Srgb,
         .ASTC5x4_Unorm,
         .ASTC5x4_Unorm_Srgb,
         .ASTC5x5_Unorm,
         .ASTC5x5_Unorm_Srgb,
         .ASTC6x5_Unorm,
         .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm,
         .ASTC6x6_Unorm_Srgb,
         .ASTC8x5_Unorm,
         .ASTC8x5_Unorm_Srgb,
         .ASTC8x6_Unorm,
         .ASTC8x6_Unorm_Srgb,
         .ASTC8x8_Unorm,
         .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm,
         .ASTC10x5_Unorm_Srgb,
         .ASTC10x6_Unorm,
         .ASTC10x6_Unorm_Srgb,
         .ASTC10x8_Unorm,
         .ASTC10x8_Unorm_Srgb,
         .ASTC10x10_Unorm,
         .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm,
         .ASTC12x10_Unorm_Srgb,
         .ASTC12x12_Unorm,
         .ASTC12x12_Unorm_Srgb:
        return TEXTURE_CHANNEL_RGBA

    case .Stencil8:
        return TEXTURE_CHANNEL_STENCIL

    case .Depth16_Unorm, .Depth24Plus, .Depth32_Float:
        return TEXTURE_CHANNEL_DEPTH

    case .Depth24Plus_Stencil8, .Depth32Float_Stencil8:
        return TEXTURE_CHANNEL_DEPTH_STENCIL

    case .NV12, .P010:
        return TEXTURE_CHANNEL_LUMINANCE_CHROMINANCE
    }
    unreachable()
}

// Returns `true` if the format has a color aspect
texture_format_has_color_aspect :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return card(texture_format_channels(format, loc) & TEXTURE_CHANNEL_RGBA) > 0
}

// Returns `true` if the format has a depth aspect
texture_format_has_depth_aspect :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return .Depth in texture_format_channels(format, loc)
}

// Returns `true` if the format has a stencil aspect
texture_format_has_stencil_aspect :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return .Stencil in texture_format_channels(format, loc)
}

// Returns the size multiple requirement for a texture using this format.
texture_format_size_multiple_requirement :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> (width: u32, height: u32) {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .NV12: return 2, 2
    case .P010: return 2, 2
    }
    return texture_format_block_dimensions(format)
}

// Returns the dimensions of a block of texels.
//
// Uncompressed formats have a block dimension of (1, 1).
texture_format_block_dimensions :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> (width: u32, height: u32) {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC4R_Unorm, .BC4R_Snorm,
         .BC5RG_Unorm, .BC5RG_Snorm,
         .BC6HRGB_Ufloat, .BC6HRGB_Float,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb,
         .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb,
         .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb,
         .EACR11_Unorm, .EACR11_Snorm,
         .EACRG11_Unorm, .EACRG11_Snorm:
        return 4, 4

    case .ASTC4x4_Unorm, .ASTC4x4_Unorm_Srgb:
        return 4, 4
    case .ASTC5x4_Unorm, .ASTC5x4_Unorm_Srgb:
        return 5, 4
    case .ASTC5x5_Unorm, .ASTC5x5_Unorm_Srgb:
        return 5, 5
    case .ASTC6x5_Unorm, .ASTC6x5_Unorm_Srgb:
        return 6, 5
    case .ASTC6x6_Unorm, .ASTC6x6_Unorm_Srgb:
        return 6, 6
    case .ASTC8x5_Unorm, .ASTC8x5_Unorm_Srgb:
        return 8, 5
    case .ASTC8x6_Unorm, .ASTC8x6_Unorm_Srgb:
        return 8, 6
    case .ASTC8x8_Unorm, .ASTC8x8_Unorm_Srgb:
        return 8, 8
    case .ASTC10x5_Unorm, .ASTC10x5_Unorm_Srgb:
        return 10, 5
    case .ASTC10x6_Unorm, .ASTC10x6_Unorm_Srgb:
        return 10, 6
    case .ASTC10x8_Unorm, .ASTC10x8_Unorm_Srgb:
        return 10, 8
    case .ASTC10x10_Unorm, .ASTC10x10_Unorm_Srgb:
        return 10, 10
    case .ASTC12x10_Unorm, .ASTC12x10_Unorm_Srgb:
        return 12, 10
    case .ASTC12x12_Unorm, .ASTC12x12_Unorm_Srgb:
        return 12, 12
    }
    return 1, 1
}

// Returns true for compressed formats.
texture_format_is_compressed :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    w, h := texture_format_block_dimensions(format, loc)
    return w != 1 || h != 1
}

// Returns true for BCn compressed formats.
texture_format_is_bcn :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return texture_format_required_features(format, loc) == .Texture_Compression_BC
}

// Returns true for ASTC compressed formats.
texture_format_is_astc :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    features := texture_format_required_features(format, loc)
    return features == .Texture_Compression_ASTC
}

// Returns the required features (if any) in order to use the texture.
texture_format_required_features :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> Feature_Name {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .Depth32Float_Stencil8:
        return .Depth32_Float_Stencil8

    case .NV12:
        return .Texture_Format_Nv12
    case .P010:
        return .Texture_Format_P010

    case .R16_Unorm, .R16_Snorm,
         .RG16_Unorm, .RG16_Snorm,
         .RGBA16_Unorm, .RGBA16_Snorm:
        return .Texture_Format_16Bit_Norm

    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC4R_Unorm, .BC4R_Snorm,
         .BC5RG_Unorm, .BC5RG_Snorm,
         .BC6HRGB_Ufloat, .BC6HRGB_Float,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb:
        return .Texture_Compression_BC

    case .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb,
         .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb,
         .EACR11_Unorm, .EACR11_Snorm,
         .EACRG11_Unorm, .EACRG11_Snorm:
        return .Texture_Compression_ETC2

    case .ASTC4x4_Unorm, .ASTC5x4_Unorm, .ASTC5x5_Unorm, .ASTC6x5_Unorm, .ASTC6x6_Unorm,
         .ASTC8x5_Unorm, .ASTC8x6_Unorm, .ASTC8x8_Unorm, .ASTC10x5_Unorm, .ASTC10x6_Unorm,
         .ASTC10x8_Unorm, .ASTC10x10_Unorm, .ASTC12x10_Unorm, .ASTC12x12_Unorm:
        return .Texture_Compression_ASTC

    case .ASTC4x4_Unorm_Srgb, .ASTC5x4_Unorm_Srgb, .ASTC5x5_Unorm_Srgb, .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm_Srgb, .ASTC8x5_Unorm_Srgb, .ASTC8x6_Unorm_Srgb, .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm_Srgb, .ASTC10x6_Unorm_Srgb, .ASTC10x8_Unorm_Srgb, .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm_Srgb, .ASTC12x12_Unorm_Srgb:
        return .Texture_Compression_ASTC
    }
    return {}
}

// Feature flags for a texture format.
Texture_Format_Feature_Flags :: bit_set[Texture_Format_Feature_Flag; u32]
Texture_Format_Feature_Flag :: enum u32 {
    // If not present, the texture can't be sampled with a filtering sampler.
    // This may overwrite TextureSampleType.Float
    Filterable,
    // Allows [`TextureDescriptor.sample_count`] to be `2`.
    Multisample_X2,
    // Allows [`TextureDescriptor.sample_count`] to be `4`.
    Multisample_X4,
    // Allows [`TextureDescriptor.sample_count`] to be `8`.
    Multisample_X8,
    // Allows [`TextureDescriptor.sample_count`] to be `16`.
    Multisample_X16,
    // Allows a texture of this format to back a view passed as `resolve_target`
    // to a render pass for an automatic driver-implemented resolve.
    Multisample_Resolve,
    // When used as a STORAGE texture, then a texture with this format can be bound with
    // [`StorageTextureAccess.ReadOnly`].
    Storage_Read_Only,
    // When used as a STORAGE texture, then a texture with this format can be bound with
    // [`StorageTextureAccess.WriteOnly`].
    Storage_Write_Only,
    // When used as a STORAGE texture, then a texture with this format can be bound with
    // [`StorageTextureAccess.ReadWrite`].
    Storage_Read_Write,
    // When used as a STORAGE texture, then a texture with this format can be bound with
    // [`StorageTextureAccess.Atomic`].
    Storage_Atomic,
    // If not present, the texture can't be blended into the render target.
    Blendable,
}

// Features supported by a given texture format
//
// Features are defined by WebGPU specification unless
// [`Features.TextureAdapterSpecificFormatFeatures`] is enabled.
Texture_Format_Features :: struct {
    allowed_usages: Texture_Usages,
    flags:          Texture_Format_Feature_Flags,
}

// Returns the format features guaranteed by the WebGPU spec.
//
// Additional features are available if
// Feature_Name.Texture_Adapter_Specific_Format_Features is enabled on the device.
texture_format_guaranteed_format_features :: proc "contextless" (
    format: Texture_Format,
    device_features: []Feature_Name,
    loc := #caller_location,
) -> Texture_Format_Features {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    none          := Texture_Format_Feature_Flags{}
    msaa          := Texture_Format_Feature_Flags{.Multisample_X4}
    msaa_resolve  := msaa + {.Multisample_Resolve}
    s_ro_wo       := Texture_Format_Feature_Flags{.Storage_Read_Only, .Storage_Write_Only}
    s_all         := s_ro_wo + {.Storage_Read_Write}

    basic      := Texture_Usages{.Copy_Src, .Copy_Dst, .Texture_Binding}
    attachment := basic + {.Render_Attachment, .Transient_Attachment}
    storage    := basic + {.Storage_Binding}
    binding    := Texture_Usages{.Texture_Binding}
    all_flags  := attachment + storage + binding

    atomic_64: Texture_Usages
    if slice.contains(device_features, Feature_Name.Texture_Atomic) {
        atomic_64 = storage + binding + {.Storage_Atomic}
    } else {
        atomic_64 = storage + binding
    }
    atomic := attachment + atomic_64

    rg11b10f_f:Texture_Format_Feature_Flags
    rg11b10f_u: Texture_Usages
    if slice.contains(device_features, Feature_Name.RG11B10_Ufloat_Renderable) {
        rg11b10f_f, rg11b10f_u = msaa_resolve, attachment
    } else {
        rg11b10f_f, rg11b10f_u = msaa, basic
    }

    bgra8unorm_f: Texture_Format_Feature_Flags
    bgra8unorm:   Texture_Usages
    if slice.contains(device_features, Feature_Name.BGRA8_Unorm_Storage) {
        bgra8unorm_f = msaa_resolve + {.Storage_Write_Only}
        bgra8unorm   = attachment + {.Storage_Binding}
    } else {
        bgra8unorm_f = msaa_resolve
        bgra8unorm   = attachment
    }

    flags: Texture_Format_Feature_Flags
    allowed_usages: Texture_Usages

    #partial switch format {
    case .R8_Unorm:              flags, allowed_usages = msaa_resolve, attachment
    case .R8_Snorm:              flags, allowed_usages = none, basic
    case .R8_Uint:               flags, allowed_usages = msaa, attachment
    case .R8_Sint:               flags, allowed_usages = msaa, attachment
    case .R16_Uint:              flags, allowed_usages = msaa, attachment
    case .R16_Sint:              flags, allowed_usages = msaa, attachment
    case .R16_Float:             flags, allowed_usages = msaa_resolve, attachment
    case .RG8_Unorm:             flags, allowed_usages = msaa_resolve, attachment
    case .RG8_Snorm:             flags, allowed_usages = none, basic
    case .RG8_Uint:              flags, allowed_usages = msaa, attachment
    case .RG8_Sint:              flags, allowed_usages = msaa, attachment
    case .R32_Uint:              flags, allowed_usages = s_all, atomic
    case .R32_Sint:              flags, allowed_usages = s_all, atomic
    case .R32_Float:             flags, allowed_usages = msaa + s_all, all_flags
    case .RG16_Uint:             flags, allowed_usages = msaa, attachment
    case .RG16_Sint:             flags, allowed_usages = msaa, attachment
    case .RG16_Float:            flags, allowed_usages = msaa_resolve, attachment
    case .RGBA8_Unorm:           flags, allowed_usages = msaa_resolve + s_ro_wo, all_flags
    case .RGBA8_Unorm_Srgb:      flags, allowed_usages = msaa_resolve, attachment
    case .RGBA8_Snorm:           flags, allowed_usages = s_ro_wo, storage
    case .RGBA8_Uint:            flags, allowed_usages = msaa + s_ro_wo, all_flags
    case .RGBA8_Sint:            flags, allowed_usages = msaa + s_ro_wo, all_flags
    case .BGRA8_Unorm:           flags, allowed_usages = bgra8unorm_f, bgra8unorm
    case .BGRA8_Unorm_Srgb:      flags, allowed_usages = msaa_resolve, attachment
    case .RGB10A2_Uint:          flags, allowed_usages = msaa, attachment
    case .RGB10A2_Unorm:         flags, allowed_usages = msaa_resolve, attachment
    case .RG11B10_Ufloat:        flags, allowed_usages = rg11b10f_f, rg11b10f_u
    case .RG32_Uint:             flags, allowed_usages = s_ro_wo, all_flags
    case .RG32_Sint:             flags, allowed_usages = s_ro_wo, all_flags
    case .RG32_Float:            flags, allowed_usages = s_ro_wo, all_flags
    case .RGBA16_Uint:           flags, allowed_usages = msaa + s_ro_wo, all_flags
    case .RGBA16_Sint:           flags, allowed_usages = msaa + s_ro_wo, all_flags
    case .RGBA16_Float:          flags, allowed_usages = msaa_resolve + s_ro_wo, all_flags
    case .RGBA32_Uint:           flags, allowed_usages = s_ro_wo, all_flags
    case .RGBA32_Sint:           flags, allowed_usages = s_ro_wo, all_flags
    case .RGBA32_Float:          flags, allowed_usages = s_ro_wo, all_flags

    case .Stencil8:              flags, allowed_usages = msaa, attachment
    case .Depth16_Unorm:         flags, allowed_usages = msaa, attachment
    case .Depth24Plus:           flags, allowed_usages = msaa, attachment
    case .Depth24Plus_Stencil8:  flags, allowed_usages = msaa, attachment
    case .Depth32_Float:         flags, allowed_usages = msaa, attachment
    case .Depth32Float_Stencil8: flags, allowed_usages = msaa, attachment

    // We only support sampling nv12 and p010 textures until we
    // implement transfer plane data.
    case .NV12:                  flags, allowed_usages = none, binding
    case .P010:                  flags, allowed_usages = none, binding

    case .R16_Unorm:             flags, allowed_usages = msaa + s_ro_wo, storage
    case .R16_Snorm:             flags, allowed_usages = msaa + s_ro_wo, storage
    case .RG16_Unorm:            flags, allowed_usages = msaa + s_ro_wo, storage
    case .RG16_Snorm:            flags, allowed_usages = msaa + s_ro_wo, storage
    case .RGBA16_Unorm:          flags, allowed_usages = msaa + s_ro_wo, storage
    case .RGBA16_Snorm:          flags, allowed_usages = msaa + s_ro_wo, storage

    case .RGB9E5_Ufloat:         flags, allowed_usages = none, basic

    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC4R_Unorm, .BC4R_Snorm,
         .BC5RG_Unorm, .BC5RG_Snorm,
         .BC6HRGB_Ufloat, .BC6HRGB_Float,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb:
        flags, allowed_usages = none, basic

    case .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb,
         .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb,
         .EACR11_Unorm, .EACR11_Snorm,
         .EACRG11_Unorm, .EACRG11_Snorm:
        flags, allowed_usages = none, basic

    case .ASTC4x4_Unorm, .ASTC4x4_Unorm_Srgb, .ASTC5x4_Unorm, .ASTC5x4_Unorm_Srgb,
         .ASTC5x5_Unorm, .ASTC5x5_Unorm_Srgb, .ASTC6x5_Unorm, .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm, .ASTC6x6_Unorm_Srgb, .ASTC8x5_Unorm, .ASTC8x5_Unorm_Srgb,
         .ASTC8x6_Unorm, .ASTC8x6_Unorm_Srgb, .ASTC8x8_Unorm, .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm, .ASTC10x5_Unorm_Srgb, .ASTC10x6_Unorm, .ASTC10x6_Unorm_Srgb,
         .ASTC10x8_Unorm, .ASTC10x8_Unorm_Srgb, .ASTC10x10_Unorm, .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm, .ASTC12x10_Unorm_Srgb, .ASTC12x12_Unorm, .ASTC12x12_Unorm_Srgb:
        flags, allowed_usages = none, basic
    }

    // Filterable / blendable / storage-atomic derived flags
    sample_type1 := texture_format_sample_type(format, .All, device_features, loc)
    is_filterable := sample_type1 == .Float

    sample_type2 := texture_format_sample_type(format, .All, {}, loc)
    is_blendable := sample_type2 == .Float ||
        (slice.contains(device_features, Feature_Name.Float32_Blendable) &&
         (format == .R32_Float || format == .RG32_Float || format == .RGBA32_Float))

    if is_filterable {
        flags += {.Filterable}
    } else {
        flags -= {.Filterable}
    }
    if is_blendable {
        flags += {.Blendable}
    } else {
        flags -= {.Blendable}
    }
    if .Storage_Atomic in allowed_usages {
        flags += {.Storage_Atomic}
    } else {
        flags -= {.Storage_Atomic}
    }

    return Texture_Format_Features{allowed_usages = allowed_usages, flags = flags}
}

// Returns the sample type compatible with this format and aspect.
//
// Returns .Undefined only if this is a combined depth-stencil format or a
// multi-planar format and Texture_Aspect.All (or .Undefined) was provided.
texture_format_sample_type :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect = .All,
    device_features: []Feature_Name,
    loc := #caller_location,
) -> Texture_Sample_Type {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm, .R8_Snorm, .RG8_Unorm, .RG8_Snorm,
         .RGBA8_Unorm, .RGBA8_Unorm_Srgb, .RGBA8_Snorm,
         .BGRA8_Unorm, .BGRA8_Unorm_Srgb,
         .R16_Float, .RG16_Float, .RGBA16_Float,
         .RGB10A2_Unorm, .RG11B10_Ufloat:
        return .Float

    case .R32_Float, .RG32_Float, .RGBA32_Float:
        return slice.contains(device_features, Feature_Name.Float32_Filterable) \
            ? .Float : .Unfilterable_Float

    case .R8_Uint, .RG8_Uint, .RGBA8_Uint,
         .R16_Uint, .RG16_Uint, .RGBA16_Uint,
         .R32_Uint, .RG32_Uint, .RGBA32_Uint,
         .RGB10A2_Uint:
        return .Uint

    case .R8_Sint, .RG8_Sint, .RGBA8_Sint,
         .R16_Sint, .RG16_Sint, .RGBA16_Sint,
         .R32_Sint, .RG32_Sint, .RGBA32_Sint:
        return .Sint

    case .Stencil8:
        return .Uint
    case .Depth16_Unorm, .Depth24Plus, .Depth32_Float:
        return .Depth
    case .Depth24Plus_Stencil8, .Depth32Float_Stencil8:
        #partial switch aspect {
        case .Depth_Only:
            return .Depth
        case .Stencil_Only:
            return .Uint
        }
        return .Undefined

    case .NV12, .P010:
        #partial switch aspect {
        case .Plane0, .Plane1:
            return .Unfilterable_Float
        }
        return .Undefined

    case .R16_Unorm, .R16_Snorm, .RG16_Unorm, .RG16_Snorm,
         .RGBA16_Unorm, .RGBA16_Snorm:
        return .Float

    case .RGB9E5_Ufloat:
        return .Float

    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC4R_Unorm, .BC4R_Snorm,
         .BC5RG_Unorm, .BC5RG_Snorm,
         .BC6HRGB_Ufloat, .BC6HRGB_Float,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb:
        return .Float

    case .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb,
         .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb,
         .EACR11_Unorm, .EACR11_Snorm,
         .EACRG11_Unorm, .EACRG11_Snorm:
        return .Float

    case .ASTC4x4_Unorm, .ASTC4x4_Unorm_Srgb, .ASTC5x4_Unorm, .ASTC5x4_Unorm_Srgb,
         .ASTC5x5_Unorm, .ASTC5x5_Unorm_Srgb, .ASTC6x5_Unorm, .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm, .ASTC6x6_Unorm_Srgb, .ASTC8x5_Unorm, .ASTC8x5_Unorm_Srgb,
         .ASTC8x6_Unorm, .ASTC8x6_Unorm_Srgb, .ASTC8x8_Unorm, .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm, .ASTC10x5_Unorm_Srgb, .ASTC10x6_Unorm, .ASTC10x6_Unorm_Srgb,
         .ASTC10x8_Unorm, .ASTC10x8_Unorm_Srgb, .ASTC10x10_Unorm, .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm, .ASTC12x10_Unorm_Srgb, .ASTC12x12_Unorm, .ASTC12x12_Unorm_Srgb:
        return .Float
    }
    return .Undefined
}

// The number of bytes one texel block occupies during an image copy, if applicable.
//
// Returns 0 if any of the following are true:
//
//  - the format is a combined depth-stencil and no aspect was provided (.Undefined)
//  - the format is a multi-planar format and no aspect was provided (.Undefined)
//  - the format is .Depth24Plus
//  - the format is .Depth24Plus_Stencil8 and aspect is depth-only
texture_format_block_copy_size :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect = .All,
    loc := #caller_location,
) -> u32 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm, .R8_Snorm, .R8_Uint, .R8_Sint:
        return 1

    case .RG8_Unorm, .RG8_Snorm, .RG8_Uint, .RG8_Sint,
         .R16_Unorm, .R16_Snorm, .R16_Uint, .R16_Sint, .R16_Float:
        return 2

    case .RGBA8_Unorm, .RGBA8_Unorm_Srgb, .RGBA8_Snorm, .RGBA8_Uint, .RGBA8_Sint,
         .BGRA8_Unorm, .BGRA8_Unorm_Srgb,
         .RG16_Unorm, .RG16_Snorm, .RG16_Uint, .RG16_Sint, .RG16_Float,
         .R32_Uint, .R32_Sint, .R32_Float,
         .RGB9E5_Ufloat, .RGB10A2_Uint, .RGB10A2_Unorm, .RG11B10_Ufloat:
        return 4

    case .RGBA16_Unorm, .RGBA16_Snorm, .RGBA16_Uint, .RGBA16_Sint, .RGBA16_Float,
         .RG32_Uint, .RG32_Sint, .RG32_Float:
        return 8

    case .RGBA32_Uint, .RGBA32_Sint, .RGBA32_Float:
        return 16

    case .Stencil8:
        return 1
    case .Depth16_Unorm:
        return 2
    case .Depth32_Float:
        return 4
    case .Depth24Plus:
        return 0
    case .Depth24Plus_Stencil8:
        #partial switch aspect {
        case .Depth_Only:
            return 0
        case .Stencil_Only:
            return 1
        }
        return 0
    case .Depth32Float_Stencil8:
        #partial switch aspect {
        case .Depth_Only:
            return 4
        case .Stencil_Only:
            return 1
        }
        return 0

    case .NV12:
        #partial switch aspect {
        case .Plane0: return 1
        case .Plane1: return 2
        }
        return 0

    case .P010:
        #partial switch aspect {
        case .Plane0: return 2
        case .Plane1: return 4
        }
        return 0

    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb, .BC4R_Unorm, .BC4R_Snorm:
        return 8
    case .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC5RG_Unorm, .BC5RG_Snorm,
         .BC6HRGB_Ufloat, .BC6HRGB_Float,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb:
        return 16

    case .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb,
         .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .EACR11_Unorm, .EACR11_Snorm:
        return 8
    case .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb,
         .EACRG11_Unorm, .EACRG11_Snorm:
        return 16

    case .ASTC4x4_Unorm, .ASTC4x4_Unorm_Srgb, .ASTC5x4_Unorm, .ASTC5x4_Unorm_Srgb,
         .ASTC5x5_Unorm, .ASTC5x5_Unorm_Srgb, .ASTC6x5_Unorm, .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm, .ASTC6x6_Unorm_Srgb, .ASTC8x5_Unorm, .ASTC8x5_Unorm_Srgb,
         .ASTC8x6_Unorm, .ASTC8x6_Unorm_Srgb, .ASTC8x8_Unorm, .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm, .ASTC10x5_Unorm_Srgb, .ASTC10x6_Unorm, .ASTC10x6_Unorm_Srgb,
         .ASTC10x8_Unorm, .ASTC10x8_Unorm_Srgb, .ASTC10x10_Unorm, .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm, .ASTC12x10_Unorm_Srgb, .ASTC12x12_Unorm, .ASTC12x12_Unorm_Srgb:
        return 16
    }
    return 0
}

// The largest number that can be returned by `texture_format_target_pixel_byte_cost`.
MAX_TARGET_PIXEL_BYTE_COST :: 16

// The number of bytes occupied per pixel in a color attachment.
texture_format_target_pixel_byte_cost :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> u32 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm, .R8_Snorm, .R8_Uint, .R8_Sint:
        return 1

    case .RG8_Unorm, .RG8_Snorm, .RG8_Uint, .RG8_Sint,
         .R16_Uint, .R16_Sint, .R16_Unorm, .R16_Snorm, .R16_Float:
        return 2

    case .RGBA8_Uint, .RGBA8_Sint,
         .RG16_Uint, .RG16_Sint, .RG16_Unorm, .RG16_Snorm, .RG16_Float,
         .R32_Uint, .R32_Sint, .R32_Float:
        return 4

    // Despite being 4 bytes per pixel, these are 8 bytes per pixel in the table
    case .RGBA8_Unorm, .RGBA8_Unorm_Srgb, .RGBA8_Snorm,
         .BGRA8_Unorm, .BGRA8_Unorm_Srgb,
         .RGBA16_Uint, .RGBA16_Sint, .RGBA16_Unorm, .RGBA16_Snorm, .RGBA16_Float,
         .RG32_Uint, .RG32_Sint, .RG32_Float,
         .RGB10A2_Uint, .RGB10A2_Unorm, .RG11B10_Ufloat:
        return 8

    case .RGBA32_Uint, .RGBA32_Sint, .RGBA32_Float:
        return 16
    }
    return 0
}

// see <https://gpuweb.github.io/gpuweb/#render-target-component-alignment>
texture_format_target_component_alignment :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> u32 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm, .R8_Snorm, .R8_Uint, .R8_Sint,
         .RG8_Unorm, .RG8_Snorm, .RG8_Uint, .RG8_Sint,
         .RGBA8_Unorm, .RGBA8_Unorm_Srgb, .RGBA8_Snorm, .RGBA8_Uint, .RGBA8_Sint,
         .BGRA8_Unorm, .BGRA8_Unorm_Srgb:
        return 1

    case .R16_Uint, .R16_Sint, .R16_Unorm, .R16_Snorm, .R16_Float,
         .RG16_Uint, .RG16_Sint, .RG16_Unorm, .RG16_Snorm, .RG16_Float,
         .RGBA16_Uint, .RGBA16_Sint, .RGBA16_Unorm, .RGBA16_Snorm, .RGBA16_Float:
        return 2

    case .R32_Uint, .R32_Sint, .R32_Float,
         .RG32_Uint, .RG32_Sint, .RG32_Float,
         .RGBA32_Uint, .RGBA32_Sint, .RGBA32_Float,
         .RGB10A2_Uint, .RGB10A2_Unorm, .RG11B10_Ufloat:
        return 4
    }
    return 0
}

// Returns the number of components this format has.
texture_format_components :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> u8 {
    return texture_format_components_with_aspect(format, .All, loc)
}

// Returns the number of components this format has, taking the aspect into account.
//
// The aspect is only relevant for combined depth-stencil formats and multi-planar formats.
texture_format_components_with_aspect :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect,
    loc := #caller_location,
) -> u8 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Unorm, .R8_Snorm, .R8_Uint, .R8_Sint,
         .R16_Unorm, .R16_Snorm, .R16_Uint, .R16_Sint, .R16_Float,
         .R32_Uint, .R32_Sint, .R32_Float:
        return 1

    case .RG8_Unorm, .RG8_Snorm, .RG8_Uint, .RG8_Sint,
         .RG16_Unorm, .RG16_Snorm, .RG16_Uint, .RG16_Sint, .RG16_Float,
         .RG32_Uint, .RG32_Sint, .RG32_Float:
        return 2

    case .RGBA8_Unorm, .RGBA8_Unorm_Srgb, .RGBA8_Snorm, .RGBA8_Uint, .RGBA8_Sint,
         .BGRA8_Unorm, .BGRA8_Unorm_Srgb,
         .RGBA16_Unorm, .RGBA16_Snorm, .RGBA16_Uint, .RGBA16_Sint, .RGBA16_Float,
         .RGBA32_Uint, .RGBA32_Sint, .RGBA32_Float:
        return 4

    case .RGB9E5_Ufloat, .RG11B10_Ufloat:
        return 3
    case .RGB10A2_Uint, .RGB10A2_Unorm:
        return 4

    case .Stencil8, .Depth16_Unorm, .Depth24Plus, .Depth32_Float:
        return 1

    case .Depth24Plus_Stencil8, .Depth32Float_Stencil8:
        #partial switch aspect {
        case .Depth_Only, .Stencil_Only:
            return 1
        }
        return 2

    case .NV12, .P010:
        #partial switch aspect {
        case .Plane0: return 1
        case .Plane1: return 2
        }
        return 3

    case .BC4R_Unorm, .BC4R_Snorm:
        return 1
    case .BC5RG_Unorm, .BC5RG_Snorm:
        return 2
    case .BC6HRGB_Ufloat, .BC6HRGB_Float:
        return 3
    case .BC1RGBA_Unorm, .BC1RGBA_Unorm_Srgb,
         .BC2RGBA_Unorm, .BC2RGBA_Unorm_Srgb,
         .BC3RGBA_Unorm, .BC3RGBA_Unorm_Srgb,
         .BC7RGBA_Unorm, .BC7RGBA_Unorm_Srgb:
        return 4

    case .EACR11_Unorm, .EACR11_Snorm:
        return 1
    case .EACRG11_Unorm, .EACRG11_Snorm:
        return 2
    case .ETC2RGB8_Unorm, .ETC2RGB8_Unorm_Srgb:
        return 3
    case .ETC2RGB8A1_Unorm, .ETC2RGB8A1_Unorm_Srgb,
         .ETC2RGBA8_Unorm, .ETC2RGBA8_Unorm_Srgb:
        return 4

    case .ASTC4x4_Unorm, .ASTC4x4_Unorm_Srgb, .ASTC5x4_Unorm, .ASTC5x4_Unorm_Srgb,
         .ASTC5x5_Unorm, .ASTC5x5_Unorm_Srgb, .ASTC6x5_Unorm, .ASTC6x5_Unorm_Srgb,
         .ASTC6x6_Unorm, .ASTC6x6_Unorm_Srgb, .ASTC8x5_Unorm, .ASTC8x5_Unorm_Srgb,
         .ASTC8x6_Unorm, .ASTC8x6_Unorm_Srgb, .ASTC8x8_Unorm, .ASTC8x8_Unorm_Srgb,
         .ASTC10x5_Unorm, .ASTC10x5_Unorm_Srgb, .ASTC10x6_Unorm, .ASTC10x6_Unorm_Srgb,
         .ASTC10x8_Unorm, .ASTC10x8_Unorm_Srgb, .ASTC10x10_Unorm, .ASTC10x10_Unorm_Srgb,
         .ASTC12x10_Unorm, .ASTC12x10_Unorm_Srgb, .ASTC12x12_Unorm, .ASTC12x12_Unorm_Srgb:
        return 4
    }
    return 0
}

// Strips the Srgb suffix from the given texture format.
texture_format_remove_srgb_suffix :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .RGBA8_Unorm_Srgb:      return .RGBA8_Unorm
    case .BGRA8_Unorm_Srgb:      return .BGRA8_Unorm
    case .BC1RGBA_Unorm_Srgb:    return .BC1RGBA_Unorm
    case .BC2RGBA_Unorm_Srgb:    return .BC2RGBA_Unorm
    case .BC3RGBA_Unorm_Srgb:    return .BC3RGBA_Unorm
    case .BC7RGBA_Unorm_Srgb:    return .BC7RGBA_Unorm
    case .ETC2RGB8_Unorm_Srgb:   return .ETC2RGB8_Unorm
    case .ETC2RGB8A1_Unorm_Srgb: return .ETC2RGB8A1_Unorm
    case .ETC2RGBA8_Unorm_Srgb:  return .ETC2RGBA8_Unorm
    case .ASTC4x4_Unorm_Srgb:    return .ASTC4x4_Unorm
    case .ASTC5x4_Unorm_Srgb:    return .ASTC5x4_Unorm
    case .ASTC5x5_Unorm_Srgb:    return .ASTC5x5_Unorm
    case .ASTC6x5_Unorm_Srgb:    return .ASTC6x5_Unorm
    case .ASTC6x6_Unorm_Srgb:    return .ASTC6x6_Unorm
    case .ASTC8x5_Unorm_Srgb:    return .ASTC8x5_Unorm
    case .ASTC8x6_Unorm_Srgb:    return .ASTC8x6_Unorm
    case .ASTC8x8_Unorm_Srgb:    return .ASTC8x8_Unorm
    case .ASTC10x5_Unorm_Srgb:   return .ASTC10x5_Unorm
    case .ASTC10x6_Unorm_Srgb:   return .ASTC10x6_Unorm
    case .ASTC10x8_Unorm_Srgb:   return .ASTC10x8_Unorm
    case .ASTC10x10_Unorm_Srgb:  return .ASTC10x10_Unorm
    case .ASTC12x10_Unorm_Srgb:  return .ASTC12x10_Unorm
    case .ASTC12x12_Unorm_Srgb:  return .ASTC12x12_Unorm
    }
    return format
}

// Adds an Srgb suffix to the given texture format, if the format supports it.
texture_format_add_srgb_suffix :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .RGBA8_Unorm:      return .RGBA8_Unorm_Srgb
    case .BGRA8_Unorm:      return .BGRA8_Unorm_Srgb
    case .BC1RGBA_Unorm:    return .BC1RGBA_Unorm_Srgb
    case .BC2RGBA_Unorm:    return .BC2RGBA_Unorm_Srgb
    case .BC3RGBA_Unorm:    return .BC3RGBA_Unorm_Srgb
    case .BC7RGBA_Unorm:    return .BC7RGBA_Unorm_Srgb
    case .ETC2RGB8_Unorm:   return .ETC2RGB8_Unorm_Srgb
    case .ETC2RGB8A1_Unorm: return .ETC2RGB8A1_Unorm_Srgb
    case .ETC2RGBA8_Unorm:  return .ETC2RGBA8_Unorm_Srgb
    case .ASTC4x4_Unorm:    return .ASTC4x4_Unorm_Srgb
    case .ASTC5x4_Unorm:    return .ASTC5x4_Unorm_Srgb
    case .ASTC5x5_Unorm:    return .ASTC5x5_Unorm_Srgb
    case .ASTC6x5_Unorm:    return .ASTC6x5_Unorm_Srgb
    case .ASTC6x6_Unorm:    return .ASTC6x6_Unorm_Srgb
    case .ASTC8x5_Unorm:    return .ASTC8x5_Unorm_Srgb
    case .ASTC8x6_Unorm:    return .ASTC8x6_Unorm_Srgb
    case .ASTC8x8_Unorm:    return .ASTC8x8_Unorm_Srgb
    case .ASTC10x5_Unorm:   return .ASTC10x5_Unorm_Srgb
    case .ASTC10x6_Unorm:   return .ASTC10x6_Unorm_Srgb
    case .ASTC10x8_Unorm:   return .ASTC10x8_Unorm_Srgb
    case .ASTC10x10_Unorm:  return .ASTC10x10_Unorm_Srgb
    case .ASTC12x10_Unorm:  return .ASTC12x10_Unorm_Srgb
    case .ASTC12x12_Unorm:  return .ASTC12x12_Unorm_Srgb
    }
    return format
}

// Returns true for srgb formats.
texture_format_is_srgb :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    return format != texture_format_remove_srgb_suffix(format, loc)
}

// Returns the theoretical memory footprint of a texture with the given format and dimensions.
//
// Actual memory usage may greatly exceed this value due to alignment and padding.
texture_format_theoretical_memory_footprint :: proc "contextless" (
    format: Texture_Format,
    size: Extent_3D,
    loc := #caller_location,
) -> u64 {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)

    block_width, block_height := texture_format_block_dimensions(format)

    approximate_block_size: u32
    if size_val := texture_format_block_copy_size(format); size_val != 0 {
        approximate_block_size = size_val
    } else {
        #partial switch format {
        case .Depth16_Unorm:
            approximate_block_size = 2
        case .Depth24Plus:
            approximate_block_size = 4
        case .Depth24Plus_Stencil8:
            approximate_block_size = 4
        case .Depth32_Float:
            approximate_block_size = 4
        case .Depth32Float_Stencil8:
            approximate_block_size = 8
        case .Stencil8:
            approximate_block_size = 1
        case .NV12:
            approximate_block_size = 3
        case .P010:
            approximate_block_size = 6
        case:
            panic_contextless("memory footprint for this format is not implemented", loc)
        }
    }

    width_blocks := u64((size.width + block_width - 1) / block_width)
    height_blocks := u64((size.height + block_height - 1) / block_height)

    total_blocks := width_blocks * height_blocks * u64(size.depth_or_array_layers)

    return total_blocks * u64(approximate_block_size)
}

texture_format_is_blit_to_buffer_supported :: proc "contextless" (
    format: Texture_Format,
    loc := #caller_location,
) -> bool {
    assert_contextless(format != .Undefined, "Invalid texture format", loc)
    #partial switch format {
    case .R8_Snorm,
         .R8_Unorm,
         .RG8_Snorm,
         .RG8_Unorm,
         .RGBA8_Snorm,
         .RGBA8_Unorm,
         .BGRA8_Unorm,
         .RGB9E5_Ufloat,
         .RG11B10_Ufloat,
         .R16_Float,
         .RG16_Float,
         .RGBA16_Float,
         .R32_Float,
         .RG32_Float,
         .RGBA32_Float,
         .Depth16_Unorm,
         .Depth24Plus,
         .Depth32_Float,
         .Stencil8,
         .Depth24Plus_Stencil8,
         .Depth32Float_Stencil8:
        return true
    case:
        return false
    }
}
