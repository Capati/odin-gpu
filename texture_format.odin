package gpu

// Underlying texture data format.
//
// If there is a conversion in the format (such as srgb -> linear), the
// conversion listed here is for loading from texture in a shader.When writing
// to the texture, the opposite conversion takes place.
Texture_Format :: enum {
    // WebGPU
    Undefined,

    // Normal 8 bit formats
    R8_Unorm,
    R8_Snorm,
    R8_Uint,
    R8_Sint,

    // Normal 16 bit formats
    R16_Uint,
    R16_Sint,
    R16_Unorm,
    R16_Snorm,
    R16_Float,
    Rg8_Unorm,
    Rg8_Snorm,
    Rg8_Uint,
    Rg8_Sint,

    // Normal 32 bit formats
    R32_Uint,
    R32_Sint,
    R32_Float,
    Rg16_Uint,
    Rg16_Sint,
    Rg16_Unorm,
    Rg16_Snorm,
    Rg16_Float,
    Rgba8_Unorm,
    Rgba8_Unorm_Srgb,
    Rgba8_Snorm,
    Rgba8_Uint,
    Rgba8_Sint,
    Bgra8_Unorm,
    Bgra8_Unorm_Srgb,

    // Packed 32 bit formats
    Rgb9e5_Ufloat,
    Rgb10a2_Uint,
    Rgb10a2_Unorm,
    Rg11b10_Ufloat,

    // Normal 64 bit formats
    R64_Uint,
    Rg32_Uint,
    Rg32_Sint,
    Rg32_Float,
    Rgba16_Uint,
    Rgba16_Sint,
    Rgba16_Unorm,
    Rgba16_Snorm,
    Rgba16_Float,

    // Normal 128 bit formats
    Rgba32_Uint,
    Rgba32_Sint,
    Rgba32_Float,

    // Depth and stencil formats
    Stencil8,
    Depth16_Unorm,
    Depth24_Plus,
    Depth24_Plus_Stencil8,
    Depth32_Float,
    Depth32_Float_Stencil8,

    /// YUV 4:2:0 chroma subsampled format.
    NV12,

    /// YUV 4:2:0 chroma subsampled format.
    P010,

    // BC Compressed textures
    Bc1_Rgba_Unorm,
    Bc1_Rgba_Unorm_Srgb,
    Bc2_Rgba_Unorm,
    Bc2_Rgba_Unorm_Srgb,
    Bc3_Rgba_Unorm,
    Bc3_Rgba_Unorm_Srgb,
    Bc4_R_Unorm,
    Bc4_R_Snorm,
    Bc5_Rg_Unorm,
    Bc5_Rg_Snorm,
    Bc6_hRgb_Ufloat,
    Bc6_hRgb_Float,
    Bc7_Rgba_Unorm,
    Bc7_Rgba_Unorm_Srgb,

    // ETC Compressed textures
    Etc2_Rgb8_Unorm,
    Etc2_Rgb8_Unorm_Srgb,
    Etc2_Rgb8A1_Unorm,
    Etc2_Rgb8A1_Unorm_Srgb,
    Etc2_Rgba8_Unorm,
    Etc2_Rgba8_Unorm_Srgb,
    Eac_R11_Unorm,
    Eac_R11_Snorm,
    Eac_Rg11_Unorm,
    Eac_Rg11_Snorm,

    // ASTC Compressed textures
    Astc_4x4_Unorm,
    Astc_4x4_Unorm_Srgb,
    Astc_4x4_Unorm_Hdr,
    Astc_5x4_Unorm,
    Astc_5x4_Unorm_Srgb,
    Astc_5x4_Unorm_Hdr,
    Astc_5x5_Unorm,
    Astc_5x5_Unorm_Srgb,
    Astc_5x5_Unorm_Hdr,
    Astc_6x5_Unorm,
    Astc_6x5_Unorm_Srgb,
    Astc_6x5_Unorm_Hdr,
    Astc_6x6_Unorm,
    Astc_6x6_Unorm_Srgb,
    Astc_6x6_Unorm_Hdr,
    Astc_8x5_Unorm,
    Astc_8x5_Unorm_Srgb,
    Astc_8x5_Unorm_Hdr,
    Astc_8x6_Unorm,
    Astc_8x6_Unorm_Srgb,
    Astc_8x6_Unorm_Hdr,
    Astc_8x8_Unorm,
    Astc_8x8_Unorm_Srgb,
    Astc_8x8_Unorm_Hdr,
    Astc_10x5_Unorm,
    Astc_10x5_Unorm_Srgb,
    Astc_10x5_Unorm_Hdr,
    Astc_10x6_Unorm,
    Astc_10x6_Unorm_Srgb,
    Astc_10x6_Unorm_Hdr,
    Astc_10x8_Unorm,
    Astc_10x8_Unorm_Srgb,
    Astc_10x8_Unorm_Hdr,
    Astc_10x10_Unorm,
    Astc_10x10_Unorm_Srgb,
    Astc_10x10_Unorm_Hdr,
    Astc_12x10_Unorm,
    Astc_12x10_Unorm_Srgb,
    Astc_12x10_Unorm_Hdr,
    Astc_12x12_Unorm,
    Astc_12x12_Unorm_Srgb,
    Astc_12x12_Unorm_Hdr,
}

// Texture format capability flags.
Format_Aspects :: bit_set[Format_Aspect; u64]
Format_Aspect :: enum {
    Color,
    Depth,
    Stencil,
    Plane0,
    Plane1,
    Plane2,
}

TEXTURE_ASPECTS_DEPTH_STENCIL :: Format_Aspects{ .Depth, .Stencil }

format_aspects_from :: proc "contextless" (format: Texture_Format) -> Format_Aspects {
    #partial switch format {
    case .Stencil8: return { .Stencil }
    case .Depth16_Unorm,. Depth32_Float, .Depth24_Plus: return { .Depth }
    case .Depth32_Float_Stencil8, .Depth24_Plus_Stencil8: return TEXTURE_ASPECTS_DEPTH_STENCIL
    case .NV12, .P010: return { .Plane0, .Plane1 }
    }
    return { .Color }
}

format_aspect_get_aspect_index :: proc(aspect: Texture_Aspect, loc := #caller_location) -> u32 {
    assert(aspect != .Undefined, "Invalid texture aspect", loc)
    #partial switch aspect {
    case .All, .Depth_Only, .Plane0: return 0
    case .Plane1, .Stencil_Only: return 1
    case .Plane2: return 2
    case:
        unreachable()
    }
}

// Texture format capability flags.
Texture_Format_Capabilities :: bit_set[Texture_Format_Capability; u32]
Texture_Format_Capability :: enum {
    Sampled,
    Sampled_Linear,
    Sampled_Minmax,
    Storage_Read_Only,
    Storage_Write_Only,
    Storage_Read_Write,
    Storage_Atomic,
    Color_Attachment,
    Color_Attachment_Blend,
    Depth_Stencil_Attachment,
    Multisample_X2,
    Multisample_X4,
    Multisample_X8,
    Multisample_X16,
    Multisample_Resolve,
    Copy_Src,
    Copy_Dst,
}

// Feature flags for a texture format.
Texture_Format_Feature_Flags :: bit_set[Texture_Format_Feature_Flag; u64]
Texture_Format_Feature_Flag :: enum {
    Filterable,
    Multisample_X2,
    Multisample_X4,
    Multisample_X8,
    Multisample_X16,
    Multisample_Resolve,
    Storage_Read_Only,
    Storage_Write_Only,
    Storage_Read_Write,
    Storage_Atomic,
    Blendable,
}

// Sample count supported by a given texture format.
//
// returns `true` if `count` is a supported sample count.
texture_format_feature_flags_sample_count_supported :: proc "contextless" (
    self: Texture_Format_Feature_Flags,
    count: u32,
) -> bool {
    switch count {
    case 1: return true
    case 2: return .Multisample_X2 in self
    case 4: return .Multisample_X4 in self
    case 8: return .Multisample_X8 in self
    case 16: return .Multisample_X16 in self
    }
    return false
}

// Features supported by a given texture format.
Texture_Format_Features :: struct {
    // Valid bits for `Texture_Descriptor.usage` provided for format creation.
    allowed_usages: Texture_Usages,
    // Additional property flags for the format.
    flags:          Texture_Format_Feature_Flags,
}

// ASTC block dimensions
Astc_Block :: enum {
    // 4x4 block compressed texture. 16 bytes per block (8 bit/px).
    B4x4,
    // 5x4 block compressed texture. 16 bytes per block (6.4 bit/px).
    B5x4,
    // 5x5 block compressed texture. 16 bytes per block (5.12 bit/px).
    B5x5,
    // 6x5 block compressed texture. 16 bytes per block (4.27 bit/px).
    B6x5,
    // 6x6 block compressed texture. 16 bytes per block (3.56 bit/px).
    B6x6,
    // 8x5 block compressed texture. 16 bytes per block (3.2 bit/px).
    B8x5,
    // 8x6 block compressed texture. 16 bytes per block (2.67 bit/px).
    B8x6,
    // 8x8 block compressed texture. 16 bytes per block (2 bit/px).
    B8x8,
    // 10x5 block compressed texture. 16 bytes per block (2.56 bit/px).
    B10x5,
    // 10x6 block compressed texture. 16 bytes per block (2.13 bit/px).
    B10x6,
    // 10x8 block compressed texture. 16 bytes per block (1.6 bit/px).
    B10x8,
    // 10x10 block compressed texture. 16 bytes per block (1.28 bit/px).
    B10x10,
    // 12x10 block compressed texture. 16 bytes per block (1.07 bit/px).
    B12x10,
    // 12x12 block compressed texture. 16 bytes per block (0.89 bit/px).
    B12x12,
}

// ASTC RGBA channel
Astc_Channel :: enum {
    // 8 bit integer RGBA, [0, 255] converted to/from linear-color float [0, 1] in shader.
    //
    // `Features{ .Texture_Compression_Astc }` must be enabled to use this channel.
    Unorm,
    // 8 bit integer RGBA, Srgb-color [0, 255] converted to/from linear-color
    // float [0, 1] in shader.
    //
    // `Features{ .Texture_Compression_Astc }` must be enabled to use this channel.
    Unorm_Srgb,
    // floating-point RGBA, linear-color float can be outside of the [0, 1] range.
    //
    // `Features{ .Texture_Compression_Astc_Hdr }` must be enabled to use this channel.
    Hdr,
}

// The largest number that can be returned by `texture_format_target_pixel_byte_cost`.
TEXTURE_FORMAT_MAX_TARGET_PIXEL_BYTE_COST :: 16

// Returns the aspect-specific format of the original format
texture_format_aspect_specific_format :: proc "contextless" (
    self: Texture_Format,
    aspect: Texture_Aspect,
) -> Maybe(Texture_Format) {
    #partial switch self {
    case .Stencil8:
        if aspect == .Stencil_Only {
            return self
        }

    case .Depth16_Unorm, .Depth24_Plus, .Depth32_Float:
        if aspect == .Depth_Only {
            return self
        }

    case .Depth24_Plus_Stencil8:
        #partial switch aspect {
        case .Stencil_Only: return .Stencil8
        case .Depth_Only: return .Depth24_Plus
        }

    case .Depth32_Float_Stencil8:
        #partial switch aspect {
        case .Stencil_Only: return .Stencil8
        case .Depth_Only: return .Depth32_Float
        }

    case .NV12:
        #partial switch aspect {
        case .Plane0: return .R8_Unorm
        case .Plane1: return .Rg8_Unorm
        }

    case .P010:
        #partial switch aspect {
        case .Plane0: return .R16_Unorm
        case .Plane1: return .Rg16_Unorm
        }
    }

    // Views to multi-planar formats must specify the plane
    if aspect == .All && !texture_format_is_multi_planar_format(self) {
        return self
    }

    return nil
}

// Returns `true` if `format` is a depth or stencil component of the given
// combined depth-stencil format
texture_format_is_depth_stencil_component :: proc "contextless" (
    format, combined_format: Texture_Format,
) -> bool {
    return(
        combined_format == .Depth24_Plus_Stencil8 &&
            (format == .Depth24_Plus || format == .Stencil8) ||
        combined_format == .Depth32_Float_Stencil8 &&
            (format == .Depth32_Float || format == .Stencil8) \
    )
}

// Check if the format is a depth and/or stencil format.
//
// Returns `true` for ANY format that has depth OR stencil.
texture_format_is_depth_stencil_format :: proc "contextless" (format: Texture_Format) -> bool {
    #partial switch format {
    case .Stencil8,
         .Depth16_Unorm,
         .Depth24_Plus,
         .Depth24_Plus_Stencil8,
         .Depth32_Float,
         .Depth32_Float_Stencil8:
        return true
    }
    return false
}

// Returns `true` if the format is a combined depth-stencil format
texture_format_is_combined_depth_stencil_format :: proc "contextless" (self: Texture_Format) -> bool {
    #partial switch self {
    case .Depth24_Plus_Stencil8, .Depth32_Float_Stencil8: return true
    }
    return false
}

// Returns `true` if the format is a multi-planar format.
texture_format_is_multi_planar_format :: proc "contextless" (format: Texture_Format) -> bool {
    return texture_format_planes(format) > 1
}

// Returns the number of planes a multi-planar format has.
texture_format_planes :: proc "contextless" (format: Texture_Format) -> u32 {
    #partial switch format {
    case .NV12: return 2
    case .P010: return 2
    }
    return 0
}

// Returns `true` if the format has a color aspect.
texture_format_has_color_aspect :: proc "contextless" (format: Texture_Format) -> bool {
    return !texture_format_is_depth_stencil_format(format)
}

// Returns `true` if the format has a depth aspect.
texture_format_has_depth_aspect :: proc "contextless" (format: Texture_Format) -> bool {
    #partial switch format {
    case .Depth16_Unorm, .Depth24_Plus, .Depth32_Float,
         .Depth24_Plus_Stencil8, .Depth32_Float_Stencil8:
        return true
    }
    return false
}

 // Returns `true` if the format has a stencil aspect.
texture_format_has_stencil_aspect :: proc "contextless" (self: Texture_Format) -> bool {
    #partial switch self {
    case .Stencil8, .Depth24_Plus_Stencil8, .Depth32_Float_Stencil8:
        return true
    }
    return false
}

// Returns the size multiple requirement for a texture using this format.
texture_format_size_multiple_requirement :: proc "contextless" (format: Texture_Format) -> (u32, u32) {
    #partial switch format {
    case .NV12: return 2, 2
    case .P010: return 2, 2
    }
    return texture_format_block_dimensions(format)
}

// Returns the dimension of a [block](https://gpuweb.github.io/gpuweb/#texel-block) of texels.
//
// Uncompressed formats have a block dimension of `(1, 1)`.
texture_format_block_dimensions :: proc "contextless" (format: Texture_Format) -> (u32, u32) {
    switch format {
    case .R8_Unorm,
         .R8_Snorm,
         .R8_Uint,
         .R8_Sint,
         .R16_Uint,
         .R16_Sint,
         .R16_Unorm,
         .R16_Snorm,
         .R16_Float,
         .Rg8_Unorm,
         .Rg8_Snorm,
         .Rg8_Uint,
         .Rg8_Sint,
         .R32_Uint,
         .R32_Sint,
         .R32_Float,
         .Rg16_Uint,
         .Rg16_Sint,
         .Rg16_Unorm,
         .Rg16_Snorm,
         .Rg16_Float,
         .Rgba8_Unorm,
         .Rgba8_Unorm_Srgb,
         .Rgba8_Snorm,
         .Rgba8_Uint,
         .Rgba8_Sint,
         .Bgra8_Unorm,
         .Bgra8_Unorm_Srgb,
         .Rgb9e5_Ufloat,
         .Rgb10a2_Uint,
         .Rgb10a2_Unorm,
         .Rg11b10_Ufloat,
         .R64_Uint,
         .Rg32_Uint,
         .Rg32_Sint,
         .Rg32_Float,
         .Rgba16_Uint,
         .Rgba16_Sint,
         .Rgba16_Unorm,
         .Rgba16_Snorm,
         .Rgba16_Float,
         .Rgba32_Uint,
         .Rgba32_Sint,
         .Rgba32_Float,
         .Stencil8,
         .Depth16_Unorm,
         .Depth24_Plus,
         .Depth24_Plus_Stencil8,
         .Depth32_Float,
         .Depth32_Float_Stencil8,
         .NV12,
         .P010:
        return 1, 1

    case .Bc1_Rgba_Unorm,
         .Bc1_Rgba_Unorm_Srgb,
         .Bc2_Rgba_Unorm,
         .Bc2_Rgba_Unorm_Srgb,
         .Bc3_Rgba_Unorm,
         .Bc3_Rgba_Unorm_Srgb,
         .Bc4_R_Unorm,
         .Bc4_R_Snorm,
         .Bc5_Rg_Unorm,
         .Bc5_Rg_Snorm,
         .Bc6_hRgb_Ufloat,
         .Bc6_hRgb_Float,
         .Bc7_Rgba_Unorm,
         .Bc7_Rgba_Unorm_Srgb:
        return 4, 4

    case .Etc2_Rgb8_Unorm,
         .Etc2_Rgb8_Unorm_Srgb,
         .Etc2_Rgb8A1_Unorm,
         .Etc2_Rgb8A1_Unorm_Srgb,
         .Etc2_Rgba8_Unorm,
         .Etc2_Rgba8_Unorm_Srgb,
         .Eac_R11_Unorm,
         .Eac_R11_Snorm,
         .Eac_Rg11_Unorm,
         .Eac_Rg11_Snorm:
        return 4, 4

    case .Astc_4x4_Unorm,
         .Astc_4x4_Unorm_Srgb,
         .Astc_4x4_Unorm_Hdr:
        return 4, 4
    case .Astc_5x4_Unorm,
         .Astc_5x4_Unorm_Srgb,
         .Astc_5x4_Unorm_Hdr:
        return 5, 4
    case .Astc_5x5_Unorm,
         .Astc_5x5_Unorm_Srgb,
         .Astc_5x5_Unorm_Hdr:
        return 5, 5
    case .Astc_6x5_Unorm,
         .Astc_6x5_Unorm_Srgb,
         .Astc_6x5_Unorm_Hdr:
        return 6, 5
    case .Astc_6x6_Unorm,
         .Astc_6x6_Unorm_Srgb,
         .Astc_6x6_Unorm_Hdr:
        return 6, 6
    case .Astc_8x5_Unorm,
         .Astc_8x5_Unorm_Srgb,
         .Astc_8x5_Unorm_Hdr:
        return 8, 5
    case .Astc_8x6_Unorm,
         .Astc_8x6_Unorm_Srgb,
         .Astc_8x6_Unorm_Hdr:
        return 8, 6
    case .Astc_8x8_Unorm,
         .Astc_8x8_Unorm_Srgb,
         .Astc_8x8_Unorm_Hdr:
        return 8, 8
    case .Astc_10x5_Unorm,
         .Astc_10x5_Unorm_Srgb,
         .Astc_10x5_Unorm_Hdr:
        return 10, 5
    case .Astc_10x6_Unorm,
         .Astc_10x6_Unorm_Srgb,
         .Astc_10x6_Unorm_Hdr:
        return 10, 6
    case .Astc_10x8_Unorm,
         .Astc_10x8_Unorm_Srgb,
         .Astc_10x8_Unorm_Hdr:
        return 10, 8
    case .Astc_10x10_Unorm,
         .Astc_10x10_Unorm_Srgb,
         .Astc_10x10_Unorm_Hdr:
        return 10, 10
    case .Astc_12x10_Unorm,
         .Astc_12x10_Unorm_Srgb,
         .Astc_12x10_Unorm_Hdr:
        return 12, 10
    case .Astc_12x12_Unorm,
         .Astc_12x12_Unorm_Srgb,
         .Astc_12x12_Unorm_Hdr:
        return 12, 12

    case .Undefined:
        return 0, 0
    }
    unreachable()
}

// Returns `true` for compressed formats.
texture_format_is_compressed :: proc "contextless" (format: Texture_Format) -> bool {
    a, b := texture_format_block_dimensions(format)
    return a != 1 && b != 1
}

// Returns `true` for BCn compressed formats.
texture_format_is_bcn :: proc "contextless" (format: Texture_Format) -> bool {
    return texture_format_required_features(format) == { .Texture_Compression_Bc }
}

// Returns `true` for Astc compressed formats.
texture_format_is_astc :: proc "contextless" (format: Texture_Format) -> bool {
    required_features := texture_format_required_features(format)
    return required_features & { .Texture_Compression_Astc, .Texture_Compression_Astc_Hdr } != {}
}

// Returns the required features (if any) in order to use the texture.
texture_format_required_features :: proc "contextless" (self: Texture_Format) -> Features {
    switch self {
    case .R8_Unorm,
         .R8_Snorm,
         .R8_Uint,
         .R8_Sint,
         .R16_Uint,
         .R16_Sint,
         .R16_Float,
         .Rg8_Unorm,
         .Rg8_Snorm,
         .Rg8_Uint,
         .Rg8_Sint,
         .R32_Uint,
         .R32_Sint,
         .R32_Float,
         .Rg16_Uint,
         .Rg16_Sint,
         .Rg16_Float,
         .Rgba8_Unorm,
         .Rgba8_Unorm_Srgb,
         .Rgba8_Snorm,
         .Rgba8_Uint,
         .Rgba8_Sint,
         .Bgra8_Unorm,
         .Bgra8_Unorm_Srgb,
         .Rgb9e5_Ufloat,
         .Rgb10a2_Uint,
         .Rgb10a2_Unorm,
         .Rg11b10_Ufloat,
         .Rg32_Uint,
         .Rg32_Sint,
         .Rg32_Float,
         .Rgba16_Uint,
         .Rgba16_Sint,
         .Rgba16_Float,
         .Rgba32_Uint,
         .Rgba32_Sint,
         .Rgba32_Float,
         .Stencil8,
         .Depth16_Unorm,
         .Depth24_Plus,
         .Depth24_Plus_Stencil8,
         .Depth32_Float:
        return {}

    case .R64_Uint:
        return { .Texture_Int64_Atomic }

    case .Depth32_Float_Stencil8:
        return { .Depth32_Float_Stencil8 }

    case .NV12:
        return { .Texture_Format_Nv12 }

    case .P010:
        return { .Texture_Format_P010 }

    case .R16_Unorm,
         .R16_Snorm,
         .Rg16_Unorm,
         .Rg16_Snorm,
         .Rgba16_Unorm,
         .Rgba16_Snorm:
        return { .Texture_Format_16Bit_Norm }

    case .Bc1_Rgba_Unorm,
         .Bc1_Rgba_Unorm_Srgb,
         .Bc2_Rgba_Unorm,
         .Bc2_Rgba_Unorm_Srgb,
         .Bc3_Rgba_Unorm,
         .Bc3_Rgba_Unorm_Srgb,
         .Bc4_R_Unorm,
         .Bc4_R_Snorm,
         .Bc5_Rg_Unorm,
         .Bc5_Rg_Snorm,
         .Bc6_hRgb_Ufloat,
         .Bc6_hRgb_Float,
         .Bc7_Rgba_Unorm,
         .Bc7_Rgba_Unorm_Srgb:
        return { .Texture_Compression_Bc }

    case .Etc2_Rgb8_Unorm,
         .Etc2_Rgb8_Unorm_Srgb,
         .Etc2_Rgb8A1_Unorm,
         .Etc2_Rgb8A1_Unorm_Srgb,
         .Etc2_Rgba8_Unorm,
         .Etc2_Rgba8_Unorm_Srgb,
         .Eac_R11_Unorm,
         .Eac_R11_Snorm,
         .Eac_Rg11_Unorm,
         .Eac_Rg11_Snorm:
        return { .Texture_Compression_Etc2 }

    case .Astc_4x4_Unorm_Hdr,
         .Astc_5x4_Unorm_Hdr,
         .Astc_5x5_Unorm_Hdr,
         .Astc_6x5_Unorm_Hdr,
         .Astc_6x6_Unorm_Hdr,
         .Astc_8x5_Unorm_Hdr,
         .Astc_8x6_Unorm_Hdr,
         .Astc_8x8_Unorm_Hdr,
         .Astc_10x5_Unorm_Hdr,
         .Astc_10x6_Unorm_Hdr,
         .Astc_10x8_Unorm_Hdr,
         .Astc_10x10_Unorm_Hdr,
         .Astc_12x10_Unorm_Hdr,
         .Astc_12x12_Unorm_Hdr:
        return { .Texture_Compression_Astc_Hdr }

    case .Astc_4x4_Unorm,
         .Astc_4x4_Unorm_Srgb,
         .Astc_5x4_Unorm,
         .Astc_5x4_Unorm_Srgb,
         .Astc_5x5_Unorm,
         .Astc_5x5_Unorm_Srgb,
         .Astc_6x5_Unorm,
         .Astc_6x5_Unorm_Srgb,
         .Astc_6x6_Unorm,
         .Astc_6x6_Unorm_Srgb,
         .Astc_8x5_Unorm,
         .Astc_8x5_Unorm_Srgb,
         .Astc_8x6_Unorm,
         .Astc_8x6_Unorm_Srgb,
         .Astc_8x8_Unorm,
         .Astc_8x8_Unorm_Srgb,
         .Astc_10x5_Unorm,
         .Astc_10x5_Unorm_Srgb,
         .Astc_10x6_Unorm,
         .Astc_10x6_Unorm_Srgb,
         .Astc_10x8_Unorm,
         .Astc_10x8_Unorm_Srgb,
         .Astc_10x10_Unorm,
         .Astc_10x10_Unorm_Srgb,
         .Astc_12x10_Unorm,
         .Astc_12x10_Unorm_Srgb,
         .Astc_12x12_Unorm,
         .Astc_12x12_Unorm_Srgb:
        return { .Texture_Compression_Astc }

    case .Undefined:
        return {}
    }
    unreachable()
}

// Returns the format features guaranteed by the WebGPU spec.
//
// Additional features are available if
// `Features{.Texture_Adapter_Specific_Format_Features}` is enabled.
texture_format_guaranteed_format_features :: proc "contextless" (
    format: Texture_Format,
    device_features: Features,
) -> (tff: Texture_Format_Features) {
    // Multisampling
    none: Texture_Format_Feature_Flags
    msaa := Texture_Format_Feature_Flags{ .Multisample_X4 }
    msaa_resolve := Texture_Format_Feature_Flags{ .Multisample_Resolve }

    s_ro_wo := Texture_Format_Feature_Flags{ .Storage_Read_Only, .Storage_Write_Only }
    s_all := Texture_Format_Feature_Flags{ .Storage_Read_Write }

    // Flags
    basic := Texture_Usages{ .Copy_Src, .Copy_Dst, .Texture_Binding }
    attachment := basic + Texture_Usages{ .Render_Attachment }
    storage := basic + Texture_Usages{ .Storage_Binding }
    binding := basic + Texture_Usages{ .Texture_Binding }
    all_flags := attachment + storage + binding
    atomic_64 := storage + binding
    if .Texture_Atomic in device_features {
        atomic_64 += { .Storage_Atomic }
    }
    atomic := attachment + atomic_64
    rg11b10f_f: Texture_Format_Feature_Flags
    rg11b10f_u: Texture_Usages
    if .Rg11B10_Ufloat_Renderable in device_features {
        rg11b10f_f = msaa_resolve
        rg11b10f_u = attachment
    } else {
        rg11b10f_f = msaa
        rg11b10f_u = basic
    }
    bgra8unorm_f := msaa_resolve
    bgra8unorm := attachment
    if .Bgra8_Unorm_Storage in device_features {
        bgra8unorm_f |= {.Storage_Write_Only}
        bgra8unorm |= {.Storage_Binding}
    }

    u: Texture_Usages
    f: Texture_Format_Feature_Flags

    #partial switch format {
    case .R8_Unorm:               f = msaa_resolve           ; u = attachment
    case .R8_Snorm:               f = none                   ; u = basic
    case .R8_Uint:                f = msaa                   ; u = attachment
    case .R8_Sint:                f = msaa                   ; u = attachment
    case .R16_Uint:               f = msaa                   ; u = attachment
    case .R16_Sint:               f = msaa                   ; u = attachment
    case .R16_Float:              f = msaa_resolve           ; u = attachment
    case .Rg8_Unorm:              f = msaa_resolve           ; u = attachment
    case .Rg8_Snorm:              f =         none           ; u = basic
    case .Rg8_Uint:               f =         msaa           ; u = attachment
    case .Rg8_Sint:               f =         msaa           ; u = attachment
    case .R32_Uint:               f =        s_all           ; u = atomic
    case .R32_Sint:               f =        s_all           ; u = atomic
    case .R32_Float:              f = msaa | s_all           ; u = all_flags
    case .Rg16_Uint:              f =         msaa           ; u = attachment
    case .Rg16_Sint:              f =         msaa           ; u = attachment
    case .Rg16_Float:             f = msaa_resolve           ; u = attachment
    case .Rgba8_Unorm:            f = msaa_resolve | s_ro_wo ; u = all_flags
    case .Rgba8_Unorm_Srgb:       f = msaa_resolve           ; u = attachment
    case .Rgba8_Snorm:            f =      s_ro_wo           ; u = storage
    case .Rgba8_Uint:             f =         msaa | s_ro_wo ; u = all_flags
    case .Rgba8_Sint:             f =         msaa | s_ro_wo ; u = all_flags
    case .Bgra8_Unorm:            f = bgra8unorm_f           ; u = bgra8unorm
    case .Bgra8_Unorm_Srgb:       f = msaa_resolve           ; u = attachment
    case .Rgb10a2_Uint:           f =         msaa           ; u = attachment
    case .Rgb10a2_Unorm:          f = msaa_resolve           ; u = attachment
    case .Rg11b10_Ufloat:         f =   rg11b10f_f           ; u = rg11b10f_u
    case .R64_Uint:               f =      s_ro_wo           ; u = atomic_64
    case .Rg32_Uint:              f =      s_ro_wo           ; u = all_flags
    case .Rg32_Sint:              f =      s_ro_wo           ; u = all_flags
    case .Rg32_Float:             f =      s_ro_wo           ; u = all_flags
    case .Rgba16_Uint:            f =         msaa | s_ro_wo ; u = all_flags
    case .Rgba16_Sint:            f =         msaa | s_ro_wo ; u = all_flags
    case .Rgba16_Float:           f = msaa_resolve | s_ro_wo ; u = all_flags
    case .Rgba32_Uint:            f =      s_ro_wo           ; u = all_flags
    case .Rgba32_Sint:            f =      s_ro_wo           ; u = all_flags
    case .Rgba32_Float:           f =      s_ro_wo           ; u = all_flags

    case .Stencil8:               f = msaa                   ; u = attachment
    case .Depth16_Unorm:          f = msaa                   ; u = attachment
    case .Depth24_Plus:           f = msaa                   ; u = attachment
    case .Depth24_Plus_Stencil8:  f = msaa                   ; u = attachment
    case .Depth32_Float:          f = msaa                   ; u = attachment
    case .Depth32_Float_Stencil8: f = msaa                   ; u = attachment

    case .NV12:                   f = none                   ; u = binding
    case .P010:                   f = none                   ; u = binding

    case .R16_Unorm:              f = msaa | s_ro_wo         ; u = storage
    case .R16_Snorm:              f = msaa | s_ro_wo         ; u = storage
    case .Rg16_Unorm:             f = msaa | s_ro_wo         ; u = storage
    case .Rg16_Snorm:             f = msaa | s_ro_wo         ; u = storage
    case .Rgba16_Unorm:           f = msaa | s_ro_wo         ; u = storage
    case .Rgba16_Snorm:           f = msaa | s_ro_wo         ; u = storage

    case .Rgb9e5_Ufloat:          f = none                   ; u = basic

    case .Bc1_Rgba_Unorm:         f = none                   ; u = basic
    case .Bc1_Rgba_Unorm_Srgb:    f = none                   ; u = basic
    case .Bc2_Rgba_Unorm:         f = none                   ; u = basic
    case .Bc2_Rgba_Unorm_Srgb:    f = none                   ; u = basic
    case .Bc3_Rgba_Unorm:         f = none                   ; u = basic
    case .Bc3_Rgba_Unorm_Srgb:    f = none                   ; u = basic
    case .Bc4_R_Unorm:            f = none                   ; u = basic
    case .Bc4_R_Snorm:            f = none                   ; u = basic
    case .Bc5_Rg_Unorm:           f = none                   ; u = basic
    case .Bc5_Rg_Snorm:           f = none                   ; u = basic
    case .Bc6_hRgb_Ufloat:        f = none                   ; u = basic
    case .Bc6_hRgb_Float:         f = none                   ; u = basic
    case .Bc7_Rgba_Unorm:         f = none                   ; u = basic
    case .Bc7_Rgba_Unorm_Srgb:    f = none                   ; u = basic

    case .Etc2_Rgb8_Unorm:        f = none                   ; u = basic
    case .Etc2_Rgb8_Unorm_Srgb:   f = none                   ; u = basic
    case .Etc2_Rgb8A1_Unorm:      f = none                   ; u = basic
    case .Etc2_Rgb8A1_Unorm_Srgb: f = none                   ; u = basic
    case .Etc2_Rgba8_Unorm:       f = none                   ; u = basic
    case .Etc2_Rgba8_Unorm_Srgb:  f = none                   ; u = basic
    case .Eac_R11_Unorm:          f = none                   ; u = basic
    case .Eac_R11_Snorm:          f = none                   ; u = basic
    case .Eac_Rg11_Unorm:         f = none                   ; u = basic
    case .Eac_Rg11_Snorm:         f = none                   ; u = basic

    // Undefined and Astc
    case:                         f = none                   ; u = basic
    }

    // Get whether the format is filterable, taking features into account
    sample_type1 := texture_format_sample_type(format, .Undefined, device_features)
    is_filterable := sample_type1 == .Float

    // Features that enable filtering don't affect blendability
    sample_type2 := texture_format_sample_type(format, .Undefined, nil)
    is_blendable := sample_type2 == .Float

    if is_filterable {
        f += {.Filterable}
    }
    if is_blendable {
        f += {.Blendable}
    }
    if .Storage_Atomic in u {
        f += {.Storage_Atomic}
    }

    return {
        allowed_usages = u,
        flags = f,
    }
}

// Returns the sample type compatible with this format and aspect.
//
// Returns `nil` only if this is a combined depth-stencil format or a multi-planar
// format and `Texture_Aspect.All` or no `aspect` was provided.
texture_format_sample_type :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect,
    device_features: Maybe(Features),
) -> Texture_Sample_Type {
    float := Texture_Sample_Type.Float
    unfilterable_float := Texture_Sample_Type.Unfilterable_Float
    float32_sample_type: Texture_Sample_Type
    if features, ok := device_features.?; ok {
        if .Float32_Filterable in features {
            float32_sample_type = .Float
        } else {
            float32_sample_type = .Unfilterable_Float
        }
    } else {
        float32_sample_type = .Unfilterable_Float
    }
    depth := Texture_Sample_Type.Depth
    _uint := Texture_Sample_Type.Uint
    sint := Texture_Sample_Type.Sint

    #partial switch format {
    case .R8_Unorm,
         .R8_Snorm,
         .Rg8_Unorm,
         .Rg8_Snorm,
         .Rgba8_Unorm,
         .Rgba8_Unorm_Srgb,
         .Rgba8_Snorm,
         .Bgra8_Unorm,
         .Bgra8_Unorm_Srgb,
         .R16_Float,
         .Rg16_Float,
         .Rgba16_Float,
         .Rgb10a2_Unorm,
         .Rg11b10_Ufloat: return float

    case .R32_Float, .Rg32_Float, .Rgba32_Float: return float32_sample_type

    case .R8_Uint,
         .Rg8_Uint,
         .Rgba8_Uint,
         .R16_Uint,
         .Rg16_Uint,
         .Rgba16_Uint,
         .R32_Uint,
         .R64_Uint,
         .Rg32_Uint,
         .Rgba32_Uint,
         .Rgb10a2_Uint: return _uint

    case .R8_Sint,
         .Rg8_Sint,
         .Rgba8_Sint,
         .R16_Sint,
         .Rg16_Sint,
         .Rgba16_Sint,
         .R32_Sint,
         .Rg32_Sint,
         .Rgba32_Sint: return sint

    case .Stencil8: return _uint
    case .Depth16_Unorm, .Depth24_Plus, .Depth32_Float: return depth
    case .Depth24_Plus_Stencil8, .Depth32_Float_Stencil8:
        #partial switch aspect {
        case .Depth_Only: return depth
        case .Stencil_Only: return _uint
        case:
            return .Undefined
        }

    case .NV12, .P010:
        #partial switch aspect {
        case .Plane0, .Plane1: return unfilterable_float
        case:
            return .Undefined
        }

    case .R16_Unorm,
         .R16_Snorm,
         .Rg16_Unorm,
         .Rg16_Snorm,
         .Rgba16_Unorm,
         .Rgba16_Snorm: return float

    case .Rgb9e5_Ufloat: return float

    case .Bc1_Rgba_Unorm,
         .Bc1_Rgba_Unorm_Srgb,
         .Bc2_Rgba_Unorm,
         .Bc2_Rgba_Unorm_Srgb,
         .Bc3_Rgba_Unorm,
         .Bc3_Rgba_Unorm_Srgb,
         .Bc4_R_Unorm,
         .Bc4_R_Snorm,
         .Bc5_Rg_Unorm,
         .Bc5_Rg_Snorm,
         .Bc6_hRgb_Ufloat,
         .Bc6_hRgb_Float,
         .Bc7_Rgba_Unorm,
         .Bc7_Rgba_Unorm_Srgb: return float

    case .Etc2_Rgb8_Unorm,
         .Etc2_Rgb8_Unorm_Srgb,
         .Etc2_Rgb8A1_Unorm,
         .Etc2_Rgb8A1_Unorm_Srgb,
         .Etc2_Rgba8_Unorm,
         .Etc2_Rgba8_Unorm_Srgb,
         .Eac_R11_Unorm,
         .Eac_R11_Snorm,
         .Eac_Rg11_Unorm,
         .Eac_Rg11_Snorm: return float

    case .Astc_4x4_Unorm,
         .Astc_4x4_Unorm_Srgb,
         .Astc_4x4_Unorm_Hdr,
         .Astc_5x4_Unorm,
         .Astc_5x4_Unorm_Srgb,
         .Astc_5x4_Unorm_Hdr,
         .Astc_5x5_Unorm,
         .Astc_5x5_Unorm_Srgb,
         .Astc_5x5_Unorm_Hdr,
         .Astc_6x5_Unorm,
         .Astc_6x5_Unorm_Srgb,
         .Astc_6x5_Unorm_Hdr,
         .Astc_6x6_Unorm,
         .Astc_6x6_Unorm_Srgb,
         .Astc_6x6_Unorm_Hdr,
         .Astc_8x5_Unorm,
         .Astc_8x5_Unorm_Srgb,
         .Astc_8x5_Unorm_Hdr,
         .Astc_8x6_Unorm,
         .Astc_8x6_Unorm_Srgb,
         .Astc_8x6_Unorm_Hdr,
         .Astc_8x8_Unorm,
         .Astc_8x8_Unorm_Srgb,
         .Astc_8x8_Unorm_Hdr,
         .Astc_10x5_Unorm,
         .Astc_10x5_Unorm_Srgb,
         .Astc_10x5_Unorm_Hdr,
         .Astc_10x6_Unorm,
         .Astc_10x6_Unorm_Srgb,
         .Astc_10x6_Unorm_Hdr,
         .Astc_10x8_Unorm,
         .Astc_10x8_Unorm_Srgb,
         .Astc_10x8_Unorm_Hdr,
         .Astc_10x10_Unorm,
         .Astc_10x10_Unorm_Srgb,
         .Astc_10x10_Unorm_Hdr,
         .Astc_12x10_Unorm,
         .Astc_12x10_Unorm_Srgb,
         .Astc_12x10_Unorm_Hdr,
         .Astc_12x12_Unorm,
         .Astc_12x12_Unorm_Srgb,
         .Astc_12x12_Unorm_Hdr: return float
    }

    return .Undefined
}

texture_format_block_copy_size :: proc "contextless" (
    format: Texture_Format,
    aspect: Maybe(Texture_Aspect) = nil,
) -> u32 {
    switch format {
    case .R8_Unorm, .R8_Snorm, .R8_Uint, .R8_Sint: return 1

    case .Rg8_Unorm, .Rg8_Snorm, .Rg8_Uint, .Rg8_Sint: return 2
    case .R16_Unorm, .R16_Snorm, .R16_Uint, .R16_Sint, .R16_Float: return 2

    case .Rgba8_Unorm,
         .Rgba8_Unorm_Srgb,
         .Rgba8_Snorm,
         .Rgba8_Uint,
         .Rgba8_Sint,
         .Bgra8_Unorm,
         .Bgra8_Unorm_Srgb: return 4
    case .Rg16_Unorm,
         .Rg16_Snorm,
         .Rg16_Uint,
         .Rg16_Sint,
         .Rg16_Float: return 4
    case .R32_Uint, .R32_Sint, .R32_Float: return 4
    case .Rgb9e5_Ufloat, .Rgb10a2_Uint, .Rgb10a2_Unorm, .Rg11b10_Ufloat: return 4

    case .Rgba16_Unorm,. Rgba16_Snorm,. Rgba16_Uint,. Rgba16_Sint,. Rgba16_Float: return 8
    case .R64_Uint, .Rg32_Uint, .Rg32_Sint, .Rg32_Float: return 8

    case .Rgba32_Uint, .Rgba32_Sint, .Rgba32_Float: return 16

    case .Stencil8: return 1
    case .Depth16_Unorm: return 2
    case .Depth32_Float: return 2
    case .Depth24_Plus: return 0
    case .Depth24_Plus_Stencil8:
        if a, ok := aspect.?; ok {
            #partial switch a {
            case .Depth_Only: return 0
            case .Stencil_Only: return 1
            case: return 0
            }
        }
    case .Depth32_Float_Stencil8:
        if a, ok := aspect.?; ok {
            #partial switch a {
            case .Depth_Only: return 4
            case .Stencil_Only: return 1
            case: return 0
            }
        }

    case .NV12:
        if a, ok := aspect.?; ok {
            #partial switch a {
            case .Plane0: return 1
            case .Plane1: return 2
            case: return 0
            }
        }

    case .P010:
        if a, ok := aspect.?; ok {
            #partial switch a {
            case .Plane0: return 2
            case .Plane1: return 4
            case: return 0
            }
        }

    case .Bc1_Rgba_Unorm, .Bc1_Rgba_Unorm_Srgb, .Bc4_R_Unorm, .Bc4_R_Snorm: return 8

    case .Bc2_Rgba_Unorm,
         .Bc2_Rgba_Unorm_Srgb,
         .Bc3_Rgba_Unorm,
         .Bc3_Rgba_Unorm_Srgb,
         .Bc5_Rg_Unorm,
         .Bc5_Rg_Snorm,
         .Bc6_hRgb_Ufloat,
         .Bc6_hRgb_Float,
         .Bc7_Rgba_Unorm,
         .Bc7_Rgba_Unorm_Srgb: return 16

    case .Etc2_Rgb8_Unorm,
         .Etc2_Rgb8_Unorm_Srgb,
         .Etc2_Rgb8A1_Unorm,
         .Etc2_Rgb8A1_Unorm_Srgb,
         .Eac_R11_Unorm,
         .Eac_R11_Snorm: return 8

    case .Etc2_Rgba8_Unorm,
         .Etc2_Rgba8_Unorm_Srgb,
         .Eac_Rg11_Unorm,
         .Eac_Rg11_Snorm: return 16

    case .Astc_4x4_Unorm,
         .Astc_4x4_Unorm_Srgb,
         .Astc_4x4_Unorm_Hdr,
         .Astc_5x4_Unorm,
         .Astc_5x4_Unorm_Srgb,
         .Astc_5x4_Unorm_Hdr,
         .Astc_5x5_Unorm,
         .Astc_5x5_Unorm_Srgb,
         .Astc_5x5_Unorm_Hdr,
         .Astc_6x5_Unorm,
         .Astc_6x5_Unorm_Srgb,
         .Astc_6x5_Unorm_Hdr,
         .Astc_6x6_Unorm,
         .Astc_6x6_Unorm_Srgb,
         .Astc_6x6_Unorm_Hdr,
         .Astc_8x5_Unorm,
         .Astc_8x5_Unorm_Srgb,
         .Astc_8x5_Unorm_Hdr,
         .Astc_8x6_Unorm,
         .Astc_8x6_Unorm_Srgb,
         .Astc_8x6_Unorm_Hdr,
         .Astc_8x8_Unorm,
         .Astc_8x8_Unorm_Srgb,
         .Astc_8x8_Unorm_Hdr,
         .Astc_10x5_Unorm,
         .Astc_10x5_Unorm_Srgb,
         .Astc_10x5_Unorm_Hdr,
         .Astc_10x6_Unorm,
         .Astc_10x6_Unorm_Srgb,
         .Astc_10x6_Unorm_Hdr,
         .Astc_10x8_Unorm,
         .Astc_10x8_Unorm_Srgb,
         .Astc_10x8_Unorm_Hdr,
         .Astc_10x10_Unorm,
         .Astc_10x10_Unorm_Srgb,
         .Astc_10x10_Unorm_Hdr,
         .Astc_12x10_Unorm,
         .Astc_12x10_Unorm_Srgb,
         .Astc_12x10_Unorm_Hdr,
         .Astc_12x12_Unorm,
         .Astc_12x12_Unorm_Srgb,
         .Astc_12x12_Unorm_Hdr: return 16

    case .Undefined: return 0
    }

    unreachable()
}

// Returns the number of components this format has.
texture_format_components :: proc "contextless" (format: Texture_Format) -> u8 {
    return texture_format_components_with_aspect(format, .All)
}

// Returns the number of components this format has taking into account the `aspect`.
//
// The `aspect` is only relevant for combined depth-stencil formats and multi-planar formats.
texture_format_components_with_aspect :: proc "contextless" (
    format: Texture_Format,
    aspect: Texture_Aspect = .All,
) -> u8 {
    switch format {
    case .R8_Unorm,
         .R8_Snorm,
         .R8_Uint,
         .R8_Sint,
         .R16_Unorm,
         .R16_Snorm,
         .R16_Uint,
         .R16_Sint,
         .R16_Float,
         .R32_Uint,
         .R32_Sint,
         .R32_Float,
         .R64_Uint: return 1

    case .Rg8_Unorm,
         .Rg8_Snorm,
         .Rg8_Uint,
         .Rg8_Sint,
         .Rg16_Unorm,
         .Rg16_Snorm,
         .Rg16_Uint,
         .Rg16_Sint,
         .Rg16_Float,
         .Rg32_Uint,
         .Rg32_Sint,
         .Rg32_Float: return 2

    case .Rgba8_Unorm,
         .Rgba8_Unorm_Srgb,
         .Rgba8_Snorm,
         .Rgba8_Uint,
         .Rgba8_Sint,
         .Bgra8_Unorm,
         .Bgra8_Unorm_Srgb,
         .Rgba16_Unorm,
         .Rgba16_Snorm,
         .Rgba16_Uint,
         .Rgba16_Sint,
         .Rgba16_Float,
         .Rgba32_Uint,
         .Rgba32_Sint,
         .Rgba32_Float: return 4

    case .Rgb9e5_Ufloat, .Rg11b10_Ufloat: return 3
    case .Rgb10a2_Uint, .Rgb10a2_Unorm: return 4

    case .Stencil8, .Depth16_Unorm, .Depth24_Plus, .Depth32_Float: return 1

    case .Depth24_Plus_Stencil8, .Depth32_Float_Stencil8:
        #partial switch aspect {
        case .Depth_Only, .Stencil_Only: return 1
        case: return 2
        }

    case .NV12, .P010:
        #partial switch aspect {
        case .Plane0: return 1
        case .Plane1: return 2
        case: return 3
        }

    case .Bc4_R_Unorm, .Bc4_R_Snorm: return  1
    case .Bc5_Rg_Unorm, .Bc5_Rg_Snorm: return  2
    case .Bc6_hRgb_Ufloat, .Bc6_hRgb_Float: return  3

    case .Bc1_Rgba_Unorm,
         .Bc1_Rgba_Unorm_Srgb,
         .Bc2_Rgba_Unorm,
         .Bc2_Rgba_Unorm_Srgb,
         .Bc3_Rgba_Unorm,
         .Bc3_Rgba_Unorm_Srgb,
         .Bc7_Rgba_Unorm,
         .Bc7_Rgba_Unorm_Srgb: return 4

    case .Eac_R11_Unorm, .Eac_R11_Snorm: return 1
    case .Eac_Rg11_Unorm, .Eac_Rg11_Snorm: return 2
    case .Etc2_Rgb8_Unorm, .Etc2_Rgb8_Unorm_Srgb: return 3
    case .Etc2_Rgb8A1_Unorm,
         .Etc2_Rgb8A1_Unorm_Srgb,
         .Etc2_Rgba8_Unorm,
         .Etc2_Rgba8_Unorm_Srgb: return 4

    case .Astc_4x4_Unorm,
         .Astc_4x4_Unorm_Srgb,
         .Astc_4x4_Unorm_Hdr,
         .Astc_5x4_Unorm,
         .Astc_5x4_Unorm_Srgb,
         .Astc_5x4_Unorm_Hdr,
         .Astc_5x5_Unorm,
         .Astc_5x5_Unorm_Srgb,
         .Astc_5x5_Unorm_Hdr,
         .Astc_6x5_Unorm,
         .Astc_6x5_Unorm_Srgb,
         .Astc_6x5_Unorm_Hdr,
         .Astc_6x6_Unorm,
         .Astc_6x6_Unorm_Srgb,
         .Astc_6x6_Unorm_Hdr,
         .Astc_8x5_Unorm,
         .Astc_8x5_Unorm_Srgb,
         .Astc_8x5_Unorm_Hdr,
         .Astc_8x6_Unorm,
         .Astc_8x6_Unorm_Srgb,
         .Astc_8x6_Unorm_Hdr,
         .Astc_8x8_Unorm,
         .Astc_8x8_Unorm_Srgb,
         .Astc_8x8_Unorm_Hdr,
         .Astc_10x5_Unorm,
         .Astc_10x5_Unorm_Srgb,
         .Astc_10x5_Unorm_Hdr,
         .Astc_10x6_Unorm,
         .Astc_10x6_Unorm_Srgb,
         .Astc_10x6_Unorm_Hdr,
         .Astc_10x8_Unorm,
         .Astc_10x8_Unorm_Srgb,
         .Astc_10x8_Unorm_Hdr,
         .Astc_10x10_Unorm,
         .Astc_10x10_Unorm_Srgb,
         .Astc_10x10_Unorm_Hdr,
         .Astc_12x10_Unorm,
         .Astc_12x10_Unorm_Srgb,
         .Astc_12x10_Unorm_Hdr,
         .Astc_12x12_Unorm,
         .Astc_12x12_Unorm_Srgb,
         .Astc_12x12_Unorm_Hdr: return 4

    case .Undefined:
        return 0
    }

    unreachable()
}

Texture_Format_Block_Info :: struct {
    byte_size:     u32,
    width, height: u32,
}

// Get block byte size, width and height from the given format and aspect.
texture_format_block_info :: proc "contextless" (
    format: Texture_Format,
    aspect: Maybe(Texture_Aspect),
) -> Texture_Format_Block_Info {
    size := texture_format_block_copy_size(format, aspect)
    width, height := texture_format_block_dimensions(format)
    return { size, width, height }
}

 // Strips the `Srgb` suffix from the given texture format.
texture_format_remove_srgb_suffix :: proc "contextless" (format: Texture_Format) -> Texture_Format {
    #partial switch format {
    case .Rgba8_Unorm_Srgb:       return .Rgba8_Unorm
    case .Bgra8_Unorm_Srgb:       return .Bgra8_Unorm
    case .Bc1_Rgba_Unorm_Srgb:    return .Bc1_Rgba_Unorm
    case .Bc2_Rgba_Unorm_Srgb:    return .Bc2_Rgba_Unorm
    case .Bc3_Rgba_Unorm_Srgb:    return .Bc3_Rgba_Unorm
    case .Bc7_Rgba_Unorm_Srgb:    return .Bc7_Rgba_Unorm
    case .Etc2_Rgb8_Unorm_Srgb:   return .Etc2_Rgb8_Unorm
    case .Etc2_Rgb8A1_Unorm_Srgb: return .Etc2_Rgb8A1_Unorm
    case .Etc2_Rgba8_Unorm_Srgb:  return .Etc2_Rgba8_Unorm
    case .Astc_4x4_Unorm_Srgb:    return .Astc_4x4_Unorm
    case .Astc_5x4_Unorm_Srgb:    return .Astc_5x4_Unorm
    case .Astc_5x5_Unorm_Srgb:    return .Astc_5x5_Unorm
    case .Astc_6x5_Unorm_Srgb:    return .Astc_6x5_Unorm
    case .Astc_6x6_Unorm_Srgb:    return .Astc_6x6_Unorm
    case .Astc_8x5_Unorm_Srgb:    return .Astc_8x5_Unorm
    case .Astc_8x6_Unorm_Srgb:    return .Astc_8x6_Unorm
    case .Astc_8x8_Unorm_Srgb:    return .Astc_8x8_Unorm
    case .Astc_10x5_Unorm_Srgb:   return .Astc_10x5_Unorm
    case .Astc_10x6_Unorm_Srgb:   return .Astc_10x6_Unorm
    case .Astc_10x8_Unorm_Srgb:   return .Astc_10x8_Unorm
    case .Astc_10x10_Unorm_Srgb:  return .Astc_10x10_Unorm
    case .Astc_12x10_Unorm_Srgb:  return .Astc_12x10_Unorm
    case .Astc_12x12_Unorm_Srgb:  return .Astc_12x12_Unorm
    }
    return format
}

 // Adds an `Srgb` suffix to the given texture format, if the format supports it.
texture_format_add_srgb_suffix :: proc "contextless" (format: Texture_Format) -> Texture_Format {
    #partial switch format {
    case .Rgba8_Unorm:       return .Rgba8_Unorm_Srgb
    case .Bgra8_Unorm:       return .Bgra8_Unorm_Srgb
    case .Bc1_Rgba_Unorm:    return .Bc1_Rgba_Unorm_Srgb
    case .Bc2_Rgba_Unorm:    return .Bc2_Rgba_Unorm_Srgb
    case .Bc3_Rgba_Unorm:    return .Bc3_Rgba_Unorm_Srgb
    case .Bc7_Rgba_Unorm:    return .Bc7_Rgba_Unorm_Srgb
    case .Etc2_Rgb8_Unorm:   return .Etc2_Rgb8_Unorm_Srgb
    case .Etc2_Rgb8A1_Unorm: return .Etc2_Rgb8A1_Unorm_Srgb
    case .Etc2_Rgba8_Unorm:  return .Etc2_Rgba8_Unorm_Srgb
    case .Astc_4x4_Unorm:    return .Astc_4x4_Unorm_Srgb
    case .Astc_5x4_Unorm:    return .Astc_5x4_Unorm_Srgb
    case .Astc_5x5_Unorm:    return .Astc_5x5_Unorm_Srgb
    case .Astc_6x5_Unorm:    return .Astc_6x5_Unorm_Srgb
    case .Astc_6x6_Unorm:    return .Astc_6x6_Unorm_Srgb
    case .Astc_8x5_Unorm:    return .Astc_8x5_Unorm_Srgb
    case .Astc_8x6_Unorm:    return .Astc_8x6_Unorm_Srgb
    case .Astc_8x8_Unorm:    return .Astc_8x8_Unorm_Srgb
    case .Astc_10x5_Unorm:   return .Astc_10x5_Unorm_Srgb
    case .Astc_10x6_Unorm:   return .Astc_10x6_Unorm_Srgb
    case .Astc_10x8_Unorm:   return .Astc_10x8_Unorm_Srgb
    case .Astc_10x10_Unorm:  return .Astc_10x10_Unorm_Srgb
    case .Astc_12x10_Unorm:  return .Astc_12x10_Unorm_Srgb
    case .Astc_12x12_Unorm:  return .Astc_12x12_Unorm_Srgb
    }
    return format
}

 // Returns `true` for srgb formats.
texture_format_is_srgb :: proc "contextless" (format: Texture_Format) -> bool {
    return format != texture_format_remove_srgb_suffix(format)
}

// /* Returns `true` if the format is a multi-planar format.*/
// texture_format_is_multi_planar_format :: proc(self: Texture_Format) -> bool {
//     return texture_format_planes(self) > 1
// }

// /* Returns the number of planes a multi-planar format has.*/
// texture_format_planes :: proc(self: Texture_Format) -> u32 {
//     #partial switch self {
//     case .NV12:
//         return 2
//     }
//     return 0
// }

texture_format_aspects :: proc "contextless" (format: Texture_Format) -> Format_Aspects {
    #partial switch format {
    case .Stencil8:
        return {.Stencil}
    case .Depth16_Unorm, .Depth32_Float, .Depth24_Plus:
        return {.Depth}
    case .Depth32_Float_Stencil8, .Depth24_Plus_Stencil8:
        return {.Depth, .Stencil}
    case .NV12, .P010:
        return {.Plane0, .Plane1}
    case:
        return {.Color}
    }
}

surface_get_format_priority :: proc "contextless" (format: Texture_Format) -> int {
    #partial switch format {
    // Optimal sRGB formats for display (BGRA preferred over RGBA)
    case .Bgra8_Unorm_Srgb: return 6
    case .Rgba8_Unorm_Srgb: return 5 // Slightly lower priority than BGRA

    // Optimal linear formats (BGRA preferred over RGBA)
    case .Bgra8_Unorm: return 4
    case .Rgba8_Unorm: return 3 // Slightly lower priority than BGRA

    // Standard fallback formats
    case .Rgb10a2_Unorm, .Rgba16_Unorm: return 2

    // Less common but usable formats
    case .Rgba16_Float, .Rgba32_Float: return 1

    // Everything else is unsuitable for surface presentation
    case:
        return 0
    }
}

// Calculate bytes per row from the given row width.
texture_format_bytes_per_row :: proc "contextless" (
    format: Texture_Format,
    width: u32,
) -> (
    bytes_per_row: u32,
) {
    block_width, _ := texture_format_block_dimensions(format)
    block_size := texture_format_block_copy_size(format)

    // Calculate the number of blocks for the given width
    blocks_in_width := (width + block_width - 1) / block_width

    // Calculate unaligned bytes per row
    unaligned_bytes_per_row := blocks_in_width * block_size

    // Align to COPY_BYTES_PER_ROW_ALIGNMENT
    bytes_per_row =
        (unaligned_bytes_per_row + COPY_BYTES_PER_ROW_ALIGNMENT - 1) &
        ~(COPY_BYTES_PER_ROW_ALIGNMENT - 1)

    return
}
