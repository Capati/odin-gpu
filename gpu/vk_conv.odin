#+build !js
package gpu

// Vendor
import gpua "allocator"
import vk "vendor:vulkan"

vk_conv_to_format :: proc(caps: VK_Private_Capabilities, format: Texture_Format) -> vk.Format {
    switch format {
    case .R8_Unorm:              return .R8_UNORM
    case .R8_Snorm:              return .R8_SNORM
    case .R8_Uint:               return .R8_UINT
    case .R8_Sint:               return .R8_SINT
    case .R16_Uint:              return .R16_UINT
    case .R16_Sint:              return .R16_SINT
    case .R16_Unorm:             return .R16_UNORM
    case .R16_Snorm:             return .R16_SNORM
    case .R16_Float:             return .R16_SFLOAT
    case .RG8_Unorm:             return .R8G8_UNORM
    case .RG8_Snorm:             return .R8G8_SNORM
    case .RG8_Uint:              return .R8G8_UINT
    case .RG8_Sint:              return .R8G8_SINT
    case .RG16_Unorm:            return .R16G16_UNORM
    case .RG16_Snorm:            return .R16G16_SNORM
    case .R32_Uint:              return .R32_UINT
    case .R32_Sint:              return .R32_SINT
    case .R32_Float:             return .R32_SFLOAT
    case .RG16_Uint:             return .R16G16_UINT
    case .RG16_Sint:             return .R16G16_SINT
    case .RG16_Float:            return .R16G16_SFLOAT
    case .RGBA8_Unorm:           return .R8G8B8A8_UNORM
    case .RGBA8_Unorm_Srgb:      return .R8G8B8A8_SRGB
    case .BGRA8_Unorm_Srgb:      return .B8G8R8A8_SRGB
    case .RGBA8_Snorm:           return .R8G8B8A8_SNORM
    case .BGRA8_Unorm:           return .B8G8R8A8_UNORM
    case .RGBA8_Uint:            return .R8G8B8A8_UINT
    case .RGBA8_Sint:            return .R8G8B8A8_SINT
    case .RGB10A2_Uint:          return .A2B10G10R10_UINT_PACK32
    case .RGB10A2_Unorm:         return .A2B10G10R10_UNORM_PACK32
    case .RG11B10_Ufloat:        return .B10G11R11_UFLOAT_PACK32
    case .RG32_Uint:             return .R32G32_UINT
    case .RG32_Sint:             return .R32G32_SINT
    case .RG32_Float:            return .R32G32_SFLOAT
    case .RGBA16_Uint:           return .R16G16B16A16_UINT
    case .RGBA16_Sint:           return .R16G16B16A16_SINT
    case .RGBA16_Unorm:          return .R16G16B16A16_UNORM
    case .RGBA16_Snorm:          return .R16G16B16A16_SNORM
    case .RGBA16_Float:          return .R16G16B16A16_SFLOAT
    case .RGBA32_Uint:           return .R32G32B32A32_UINT
    case .RGBA32_Sint:           return .R32G32B32A32_SINT
    case .RGBA32_Float:          return .R32G32B32A32_SFLOAT
    case .Depth32_Float:         return .D32_SFLOAT
    case .Depth32Float_Stencil8: return .D32_SFLOAT_S8_UINT

    case .Depth24Plus:
        return caps.texture_d24 ? .X8_D24_UNORM_PACK32 : .D32_SFLOAT

    case .Depth24Plus_Stencil8:
        return caps.texture_d24_s8 ? .D24_UNORM_S8_UINT : .D32_SFLOAT_S8_UINT

    case .Stencil8:
        if (caps.texture_s8) {
            return .S8_UINT
        } else if (caps.texture_d24_s8) {
            return .D24_UNORM_S8_UINT
        } else {
            return .D32_SFLOAT_S8_UINT
        }

    case .Depth16_Unorm:         return .D16_UNORM
    case .NV12:                  return .G8_B8R8_2PLANE_420_UNORM
    case .P010:                  return .G10X6_B10X6R10X6_2PLANE_420_UNORM_3PACK16
    case .RGB9E5_Ufloat:         return .E5B9G9R9_UFLOAT_PACK32
    case .BC1RGBA_Unorm:         return .BC1_RGBA_UNORM_BLOCK
    case .BC1RGBA_Unorm_Srgb:    return .BC1_RGBA_SRGB_BLOCK
    case .BC2RGBA_Unorm:         return .BC2_UNORM_BLOCK
    case .BC2RGBA_Unorm_Srgb:    return .BC2_SRGB_BLOCK
    case .BC3RGBA_Unorm:         return .BC3_UNORM_BLOCK
    case .BC3RGBA_Unorm_Srgb:    return .BC3_SRGB_BLOCK
    case .BC4R_Unorm:            return .BC4_UNORM_BLOCK
    case .BC4R_Snorm:            return .BC4_SNORM_BLOCK
    case .BC5RG_Unorm:           return .BC5_UNORM_BLOCK
    case .BC5RG_Snorm:           return .BC5_SNORM_BLOCK
    case .BC6HRGB_Ufloat:        return .BC6H_UFLOAT_BLOCK
    case .BC6HRGB_Float:         return .BC6H_SFLOAT_BLOCK
    case .BC7RGBA_Unorm:         return .BC7_UNORM_BLOCK
    case .BC7RGBA_Unorm_Srgb:    return .BC7_SRGB_BLOCK
    case .ETC2RGB8_Unorm:        return .ETC2_R8G8B8_UNORM_BLOCK
    case .ETC2RGB8_Unorm_Srgb:   return .ETC2_R8G8B8_SRGB_BLOCK
    case .ETC2RGB8A1_Unorm:      return .ETC2_R8G8B8A1_UNORM_BLOCK
    case .ETC2RGB8A1_Unorm_Srgb: return .ETC2_R8G8B8A1_SRGB_BLOCK
    case .ETC2RGBA8_Unorm:       return .ETC2_R8G8B8A8_UNORM_BLOCK
    case .ETC2RGBA8_Unorm_Srgb:  return .ETC2_R8G8B8A8_SRGB_BLOCK
    case .EACR11_Unorm:          return .EAC_R11_UNORM_BLOCK
    case .EACR11_Snorm:          return .EAC_R11_SNORM_BLOCK
    case .EACRG11_Unorm:         return .EAC_R11G11_UNORM_BLOCK
    case .EACRG11_Snorm:         return .EAC_R11G11_SNORM_BLOCK

    case .ASTC4x4_Unorm:         return .ASTC_4x4_UNORM_BLOCK
    case .ASTC5x4_Unorm:         return .ASTC_5x4_UNORM_BLOCK
    case .ASTC5x5_Unorm:         return .ASTC_5x5_UNORM_BLOCK
    case .ASTC6x5_Unorm:         return .ASTC_6x5_UNORM_BLOCK
    case .ASTC6x6_Unorm:         return .ASTC_6x6_UNORM_BLOCK
    case .ASTC8x5_Unorm:         return .ASTC_8x5_UNORM_BLOCK
    case .ASTC8x6_Unorm:         return .ASTC_8x6_UNORM_BLOCK
    case .ASTC8x8_Unorm:         return .ASTC_8x8_UNORM_BLOCK
    case .ASTC10x5_Unorm:        return .ASTC_10x5_UNORM_BLOCK
    case .ASTC10x6_Unorm:        return .ASTC_10x6_UNORM_BLOCK
    case .ASTC10x8_Unorm:        return .ASTC_10x8_UNORM_BLOCK
    case .ASTC10x10_Unorm:       return .ASTC_10x10_UNORM_BLOCK
    case .ASTC12x10_Unorm:       return .ASTC_12x10_UNORM_BLOCK
    case .ASTC12x12_Unorm:       return .ASTC_12x12_UNORM_BLOCK
    case .ASTC4x4_Unorm_Srgb:    return .ASTC_4x4_SRGB_BLOCK
    case .ASTC5x4_Unorm_Srgb:    return .ASTC_5x4_SRGB_BLOCK
    case .ASTC5x5_Unorm_Srgb:    return .ASTC_5x5_SRGB_BLOCK
    case .ASTC6x5_Unorm_Srgb:    return .ASTC_6x5_SRGB_BLOCK
    case .ASTC6x6_Unorm_Srgb:    return .ASTC_6x6_SRGB_BLOCK
    case .ASTC8x5_Unorm_Srgb:    return .ASTC_8x5_SRGB_BLOCK
    case .ASTC8x6_Unorm_Srgb:    return .ASTC_8x6_SRGB_BLOCK
    case .ASTC8x8_Unorm_Srgb:    return .ASTC_8x8_SRGB_BLOCK
    case .ASTC10x5_Unorm_Srgb:   return .ASTC_10x5_SRGB_BLOCK
    case .ASTC10x6_Unorm_Srgb:   return .ASTC_10x6_SRGB_BLOCK
    case .ASTC10x8_Unorm_Srgb:   return .ASTC_10x8_SRGB_BLOCK
    case .ASTC10x10_Unorm_Srgb:  return .ASTC_10x10_SRGB_BLOCK
    case .ASTC12x10_Unorm_Srgb:  return .ASTC_12x10_SRGB_BLOCK
    case .ASTC12x12_Unorm_Srgb:  return .ASTC_12x12_SRGB_BLOCK

    case .Undefined:             return .UNDEFINED
    }
    unreachable()
}

vk_conv_from_format :: proc(format: vk.Format) -> Texture_Format {
    #partial switch format {
    case .R8_UNORM:                  return .R8_Unorm
    case .R8_SNORM:                  return .R8_Snorm
    case .R8_UINT:                   return .R8_Uint
    case .R8_SINT:                   return .R8_Sint
    case .R16_UINT:                  return .R16_Uint
    case .R16_SINT:                  return .R16_Sint
    case .R16_UNORM:                 return .R16_Unorm
    case .R16_SNORM:                 return .R16_Snorm
    case .R16_SFLOAT:                return .R16_Float
    case .R8G8_UNORM:                return .RG8_Unorm
    case .R8G8_SNORM:                return .RG8_Snorm
    case .R8G8_UINT:                 return .RG8_Uint
    case .R8G8_SINT:                 return .RG8_Sint
    case .R16G16_UNORM:              return .RG16_Unorm
    case .R16G16_SNORM:              return .RG16_Snorm
    case .R32_UINT:                  return .R32_Uint
    case .R32_SINT:                  return .R32_Sint
    case .R32_SFLOAT:                return .R32_Float
    case .R16G16_UINT:               return .RG16_Uint
    case .R16G16_SINT:               return .RG16_Sint
    case .R16G16_SFLOAT:             return .RG16_Float
    case .R8G8B8A8_UNORM:            return .RGBA8_Unorm
    case .R8G8B8A8_SRGB:             return .RGBA8_Unorm_Srgb
    case .B8G8R8A8_SRGB:             return .BGRA8_Unorm_Srgb
    case .R8G8B8A8_SNORM:            return .RGBA8_Snorm
    case .B8G8R8A8_UNORM:            return .BGRA8_Unorm
    case .R8G8B8A8_UINT:             return .RGBA8_Uint
    case .R8G8B8A8_SINT:             return .RGBA8_Sint
    case .A2B10G10R10_UINT_PACK32:   return .RGB10A2_Uint
    case .A2B10G10R10_UNORM_PACK32:  return .RGB10A2_Unorm
    case .B10G11R11_UFLOAT_PACK32:   return .RG11B10_Ufloat
    case .R32G32_UINT:               return .RG32_Uint
    case .R32G32_SINT:               return .RG32_Sint
    case .R32G32_SFLOAT:             return .RG32_Float
    case .R16G16B16A16_UINT:         return .RGBA16_Uint
    case .R16G16B16A16_SINT:         return .RGBA16_Sint
    case .R16G16B16A16_UNORM:        return .RGBA16_Unorm
    case .R16G16B16A16_SNORM:        return .RGBA16_Snorm
    case .R16G16B16A16_SFLOAT:       return .RGBA16_Float
    case .R32G32B32A32_UINT:         return .RGBA32_Uint
    case .R32G32B32A32_SINT:         return .RGBA32_Sint
    case .R32G32B32A32_SFLOAT:       return .RGBA32_Float
    case .D32_SFLOAT:                return .Depth32_Float
    case .D32_SFLOAT_S8_UINT:        return .Depth32Float_Stencil8

    case .X8_D24_UNORM_PACK32:       return .Depth24Plus
    case .D24_UNORM_S8_UINT:         return .Depth24Plus_Stencil8
    case .S8_UINT:                   return .Stencil8

    case .D16_UNORM:                 return .Depth16_Unorm
    case .E5B9G9R9_UFLOAT_PACK32:    return .RGB9E5_Ufloat
    case .BC1_RGBA_UNORM_BLOCK:      return .BC1RGBA_Unorm
    case .BC1_RGBA_SRGB_BLOCK:       return .BC1RGBA_Unorm_Srgb
    case .BC2_UNORM_BLOCK:           return .BC2RGBA_Unorm
    case .BC2_SRGB_BLOCK:            return .BC2RGBA_Unorm_Srgb
    case .BC3_UNORM_BLOCK:           return .BC3RGBA_Unorm
    case .BC3_SRGB_BLOCK:            return .BC3RGBA_Unorm_Srgb
    case .BC4_UNORM_BLOCK:           return .BC4R_Unorm
    case .BC4_SNORM_BLOCK:           return .BC4R_Snorm
    case .BC5_UNORM_BLOCK:           return .BC5RG_Unorm
    case .BC5_SNORM_BLOCK:           return .BC5RG_Snorm
    case .BC6H_UFLOAT_BLOCK:         return .BC6HRGB_Ufloat
    case .BC6H_SFLOAT_BLOCK:         return .BC6HRGB_Float
    case .BC7_UNORM_BLOCK:           return .BC7RGBA_Unorm
    case .BC7_SRGB_BLOCK:            return .BC7RGBA_Unorm_Srgb
    case .ETC2_R8G8B8_UNORM_BLOCK:   return .ETC2RGB8_Unorm
    case .ETC2_R8G8B8_SRGB_BLOCK:    return .ETC2RGB8_Unorm_Srgb
    case .ETC2_R8G8B8A1_UNORM_BLOCK: return .ETC2RGB8A1_Unorm
    case .ETC2_R8G8B8A1_SRGB_BLOCK:  return .ETC2RGB8A1_Unorm_Srgb
    case .ETC2_R8G8B8A8_UNORM_BLOCK: return .ETC2RGBA8_Unorm
    case .ETC2_R8G8B8A8_SRGB_BLOCK:  return .ETC2RGBA8_Unorm_Srgb
    case .EAC_R11_UNORM_BLOCK:       return .EACR11_Unorm
    case .EAC_R11_SNORM_BLOCK:       return .EACR11_Snorm
    case .EAC_R11G11_UNORM_BLOCK:    return .EACRG11_Unorm
    case .EAC_R11G11_SNORM_BLOCK:    return .EACRG11_Snorm

    case .ASTC_4x4_UNORM_BLOCK:      return .ASTC4x4_Unorm
    case .ASTC_5x4_UNORM_BLOCK:      return .ASTC5x4_Unorm
    case .ASTC_5x5_UNORM_BLOCK:      return .ASTC5x5_Unorm
    case .ASTC_6x5_UNORM_BLOCK:      return .ASTC6x5_Unorm
    case .ASTC_6x6_UNORM_BLOCK:      return .ASTC6x6_Unorm
    case .ASTC_8x5_UNORM_BLOCK:      return .ASTC8x5_Unorm
    case .ASTC_8x6_UNORM_BLOCK:      return .ASTC8x6_Unorm
    case .ASTC_8x8_UNORM_BLOCK:      return .ASTC8x8_Unorm
    case .ASTC_10x5_UNORM_BLOCK:     return .ASTC10x5_Unorm
    case .ASTC_10x6_UNORM_BLOCK:     return .ASTC10x6_Unorm
    case .ASTC_10x8_UNORM_BLOCK:     return .ASTC10x8_Unorm
    case .ASTC_10x10_UNORM_BLOCK:    return .ASTC10x10_Unorm
    case .ASTC_12x10_UNORM_BLOCK:    return .ASTC12x10_Unorm
    case .ASTC_12x12_UNORM_BLOCK:    return .ASTC12x12_Unorm
    case .ASTC_4x4_SRGB_BLOCK:       return .ASTC4x4_Unorm_Srgb
    case .ASTC_5x4_SRGB_BLOCK:       return .ASTC5x4_Unorm_Srgb
    case .ASTC_5x5_SRGB_BLOCK:       return .ASTC5x5_Unorm_Srgb
    case .ASTC_6x5_SRGB_BLOCK:       return .ASTC6x5_Unorm_Srgb
    case .ASTC_6x6_SRGB_BLOCK:       return .ASTC6x6_Unorm_Srgb
    case .ASTC_8x5_SRGB_BLOCK:       return .ASTC8x5_Unorm_Srgb
    case .ASTC_8x6_SRGB_BLOCK:       return .ASTC8x6_Unorm_Srgb
    case .ASTC_8x8_SRGB_BLOCK:       return .ASTC8x8_Unorm_Srgb
    case .ASTC_10x5_SRGB_BLOCK:      return .ASTC10x5_Unorm_Srgb
    case .ASTC_10x6_SRGB_BLOCK:      return .ASTC10x6_Unorm_Srgb
    case .ASTC_10x8_SRGB_BLOCK:      return .ASTC10x8_Unorm_Srgb
    case .ASTC_10x10_SRGB_BLOCK:     return .ASTC10x10_Unorm_Srgb
    case .ASTC_12x10_SRGB_BLOCK:     return .ASTC12x10_Unorm_Srgb
    case .ASTC_12x12_SRGB_BLOCK:     return .ASTC12x12_Unorm_Srgb

    case .G8_B8R8_2PLANE_420_UNORM:
        return .NV12
    case .G10X6_B10X6R10X6_2PLANE_420_UNORM_3PACK16:
        return .P010

    case:
        return .Undefined
    }
}

vk_conv_from_present_mode :: proc(mode: vk.PresentModeKHR) -> Present_Mode {
    #partial switch (mode) {
    case .IMMEDIATE:
        return .Immediate
    case .MAILBOX:
        return .Mailbox
    case .FIFO:
        return .Fifo
    case .FIFO_RELAXED:
        return .Fifo_Relaxed
    case:
        // Modes that aren't exposed yet.
        return .Fifo
    }
}

vk_conv_from_image_usage_flags :: proc(
    caps: VK_Private_Capabilities,
    flags: vk.ImageUsageFlags,
) -> Texture_Usages {
    usages: Texture_Usages
    if .TRANSFER_SRC in flags {
        usages |= {.Copy_Src}
    }
    if .TRANSFER_DST in flags {
        usages |= {.Copy_Dst}
    }
    if .SAMPLED in flags {
        usages |= {.Texture_Binding}
    }
    if .COLOR_ATTACHMENT in flags {
        usages |= {.Render_Attachment}
    }
    if .DEPTH_STENCIL_ATTACHMENT in flags {
        usages |= {.Render_Attachment}
    }
    if .STORAGE in flags {
        usages |= {.Storage_Binding}
        // if caps.shader_image_atomic_int64.features.shaderImageInt64Atomics {
        //     usages |= {.Storage_Atomic}
        // }
    }
    if .TRANSIENT_ATTACHMENT in flags {
        usages |= {.Transient_Attachment}
    }
    return usages
}

@(require_results)
vk_conv_from_color_space :: proc(cs: vk.ColorSpaceKHR) -> (Surface_Color_Space, bool) {
    #partial switch cs {
    case .SRGB_NONLINEAR:
        return .Srgb, true
    case .EXTENDED_SRGB_LINEAR_EXT:
        return .Extended_Srgb_Linear, true
    case .EXTENDED_SRGB_NONLINEAR_EXT:
        return .Extended_Srgb, true
    case .DISPLAY_P3_NONLINEAR_EXT:
        return .Display_P3, true
    case .DISPLAY_P3_LINEAR_EXT:
        return .Extended_Display_P3, true
    case .HDR10_ST2084_EXT:
        return .Bt2100_Pq, true
    case .HDR10_HLG_EXT:
        return .Bt2100_Hlg, true
    case:
        return {}, false
    }
}

vk_conv_to_color_space :: proc(
    color_space: Surface_Color_Space,
    loc := #caller_location,
) -> vk.ColorSpaceKHR {
    assert(color_space != .Extended_Display_P3,
        "`Extended_Display_P3` is never reported in the Vulkan surface capabilities", loc)
    #partial switch color_space {
    case .Srgb: return .SRGB_NONLINEAR
    case .Extended_Srgb_Linear: return .EXTENDED_SRGB_LINEAR_EXT
    case .Extended_Srgb: return .EXTENDED_SRGB_NONLINEAR_EXT
    case .Display_P3: return .DISPLAY_P3_NONLINEAR_EXT
    case .Bt2100_Pq: return .HDR10_ST2084_EXT
    case .Bt2100_Hlg: return .HDR10_HLG_EXT
    case:
        unreachable()
    }
}

vk_conv_to_image_usage_flags_from_uses :: proc(
    uses: Texture_Uses,
    loc := #caller_location,
) -> (flags: vk.ImageUsageFlags) {
    if .Copy_Src in uses {
        flags |= {.TRANSFER_SRC}
    }
    if .Copy_Dst in uses {
        flags |= {.TRANSFER_DST}
    }
    if .Resource in uses {
        flags |= {.SAMPLED}
    }
    if .Color_Target in uses {
        flags |= {.COLOR_ATTACHMENT}
    }
    if uses & {.Depth_Read, .Depth_Write, .Stencil_Read, .Stencil_Write} != {} {
        flags |= {.DEPTH_STENCIL_ATTACHMENT}
    }
    if uses & {
        .Storage_Read_Only,
        .Storage_Write_Only,
        .Storage_Read_Write,
        .Storage_Atomic} != {} {
        flags |= {.STORAGE}
    }
    if .Transient in uses {
        flags |= {.TRANSIENT_ATTACHMENT}
    }
    return
}

vk_conv_to_image_usage_flags_from_usages :: proc(
    usage: Texture_Usages,
    format: Texture_Format,
    loc := #caller_location,
) -> vk.ImageUsageFlags {
    flags: vk.ImageUsageFlags
    if (.Copy_Src in usage) {
        flags |= {.TRANSFER_SRC}
    }
    if (.Copy_Dst in usage) {
        flags |= {.TRANSFER_DST}
    }
    if (.Texture_Binding in usage) {
        flags |= {.SAMPLED}
    }
    if (.Storage_Binding in usage) {
        flags |= {.STORAGE}
    }
    if (.Storage_Atomic in usage) {
        flags |= {.STORAGE}
    }
    if (.Transient_Attachment in usage) {
        flags |= {.TRANSIENT_ATTACHMENT}
    }
    if (.Render_Attachment in usage) {
        if texture_format_is_depth_stencil_format(format, loc) {
            flags |= {.DEPTH_STENCIL_ATTACHMENT}
        } else {
            flags |= {.COLOR_ATTACHMENT}
        }
    }
    return flags
}

vk_conv_to_image_usage_flags :: proc {
    vk_conv_to_image_usage_flags_from_uses,
    vk_conv_to_image_usage_flags_from_usages,
}

vk_conv_to_composite_alpha_flags :: proc "contextless" (
    mode: Composite_Alpha_Mode,
) -> vk.CompositeAlphaFlagsKHR {
    switch mode {
    case .Opaque:          return {.OPAQUE}
    case .Premultiplied:   return {.PRE_MULTIPLIED}
    case .Unpremultiplied: return {.POST_MULTIPLIED}
    case .Inherit:         return {.INHERIT}
    case .Auto:            return {.OPAQUE}
    }
    unreachable()
}

vk_conv_to_present_mode :: #force_inline proc "contextless" (
    mode: Present_Mode,
    loc := #caller_location,
) -> vk.PresentModeKHR {
    #partial switch mode {
    case .Immediate:    return .IMMEDIATE
    case .Mailbox:      return .MAILBOX
    case .Fifo:         return .FIFO
    case .Fifo_Relaxed: return .FIFO_RELAXED
    case:
        panic_contextless("VULKAN: Unsupported present mode", loc)
    }
    unreachable()
}

vk_conv_to_attachment_store_op :: #force_inline proc "contextless" (
    op: Store_Op,
    loc := #caller_location,
) -> vk.AttachmentStoreOp {
    assert_contextless(op != .Undefined, "VULKAN: Invalid store operation", loc)
    #partial switch op {
    case .Store:   return .STORE
    case .Discard: return .DONT_CARE
    }
    unreachable()
}

vk_conv_to_attachment_load_op :: #force_inline proc "contextless" (
    op: Load_Op,
    loc := #caller_location,
) -> vk.AttachmentLoadOp {
    assert_contextless(op != .Undefined, "VULKAN: Invalid load operation", loc)
    #partial switch op {
    case .Load:      return .LOAD
    case .Clear:     return .CLEAR
    case .Dont_Care: return .DONT_CARE
    }
    unreachable()
}

vk_conv_to_vertex_step_mode :: proc "contextless" (
    mode: Vertex_Step_Mode,
    loc := #caller_location,
) -> vk.VertexInputRate {
    switch mode {
    case .Vertex:   return .VERTEX
    case .Instance: return .INSTANCE
    case:
        unreachable()
    }
}

vk_conv_to_vertex_format :: proc(vertex_format: Vertex_Format) -> vk.Format {
    switch vertex_format {
    case .Uint8:
        return .R8_UINT
    case .Uint8x2:
        return .R8G8_UINT
    case .Uint8x4:
        return .R8G8B8A8_UINT
    case .Sint8:
        return .R8_SINT
    case .Sint8x2:
        return .R8G8_SINT
    case .Sint8x4:
        return .R8G8B8A8_SINT
    case .Unorm8:
        return .R8_UNORM
    case .Unorm8x2:
        return .R8G8_UNORM
    case .Unorm8x4:
        return .R8G8B8A8_UNORM
    case .Snorm8:
        return .R8_SNORM
    case .Snorm8x2:
        return .R8G8_SNORM
    case .Snorm8x4:
        return .R8G8B8A8_SNORM
    case .Uint16:
        return .R16_UINT
    case .Uint16x2:
        return .R16G16_UINT
    case .Uint16x4:
        return .R16G16B16A16_UINT
    case .Sint16:
        return .R16_SINT
    case .Sint16x2:
        return .R16G16_SINT
    case .Sint16x4:
        return .R16G16B16A16_SINT
    case .Unorm16:
        return .R16_UNORM
    case .Unorm16x2:
        return .R16G16_UNORM
    case .Unorm16x4:
        return .R16G16B16A16_UNORM
    case .Snorm16:
        return .R16_SNORM
    case .Snorm16x2:
        return .R16G16_SNORM
    case .Snorm16x4:
        return .R16G16B16A16_SNORM
    case .Float16:
        return .R16_SFLOAT
    case .Float16x2:
        return .R16G16_SFLOAT
    case .Float16x4:
        return .R16G16B16A16_SFLOAT
    case .Float32:
        return .R32_SFLOAT
    case .Float32x2:
        return .R32G32_SFLOAT
    case .Float32x3:
        return .R32G32B32_SFLOAT
    case .Float32x4:
        return .R32G32B32A32_SFLOAT
    case .Uint32:
        return .R32_UINT
    case .Uint32x2:
        return .R32G32_UINT
    case .Uint32x3:
        return .R32G32B32_UINT
    case .Uint32x4:
        return .R32G32B32A32_UINT
    case .Sint32:
        return .R32_SINT
    case .Sint32x2:
        return .R32G32_SINT
    case .Sint32x3:
        return .R32G32B32_SINT
    case .Sint32x4:
        return .R32G32B32A32_SINT
    // case .Float64:
    //     return .R64_SFLOAT
    // case .Float64x2:
    //     return .R64G64_SFLOAT
    // case .Float64x3:
    //     return .R64G64B64_SFLOAT
    // case .Float64x4:
    //     return .R64G64B64A64_SFLOAT
    case .Unorm10_10_10_2:
        return .A2B10G10R10_UNORM_PACK32
    case .Unorm8x4BGRA:
        return .B8G8R8A8_UNORM
    }
    unreachable()
}

vk_conv_to_primitive_topology :: proc "contextless" (
    topology: Primitive_Topology,
    loc := #caller_location,
) -> vk.PrimitiveTopology {
    switch topology {
    case .Point_List:     return .POINT_LIST
    case .Line_List:      return .LINE_LIST
    case .Line_Strip:     return .LINE_STRIP
    case .Triangle_List:  return .TRIANGLE_LIST
    case .Triangle_Strip: return .TRIANGLE_STRIP
    case:
        unreachable()
    }
}

vk_conv_to_polygon_mode :: proc "contextless" (mode: Polygon_Mode) -> vk.PolygonMode {
    switch mode {
    case .Fill:  return .FILL
    case .Line:  return .LINE
    case .Point: return .POINT
    }
    unreachable()
}

vk_conv_to_front_face :: proc "contextless" (
    front_face: Front_Face,
    loc := #caller_location,
) -> vk.FrontFace {
    switch front_face {
    case .CW:  return .CLOCKWISE
    case .CCW: return .COUNTER_CLOCKWISE
    }
    unreachable()
}

vk_conv_to_cull_mode_flags :: proc "contextless" (
    mode: Cull_Mode,
    loc := #caller_location,
) -> vk.CullModeFlags {
    switch mode {
    case .Front: return {.FRONT}
    case .Back:  return {.BACK}
    case .None:  return vk.CullModeFlags_NONE
    }
    unreachable()
}

vk_conv_to_sample_count_flags :: proc "contextless" (
    samples: u32,
    loc := #caller_location,
) -> (
    flags: vk.SampleCountFlags,
) {
    switch samples {
    case 1:  return {._1}
    case 2:  return {._2}
    case 4:  return {._4}
    case 8:  return {._8}
    case 16: return {._16}
    case 32: return {._32}
    case 64: return {._64}
    case:
        panic_contextless("Invalid sample count", loc)
    }
}

vk_conv_to_stencil_op :: proc "contextless" (
    op: Stencil_Operation,
    loc := #caller_location,
) -> vk.StencilOp {
    switch op {
    case .Keep:            return .KEEP
    case .Zero:            return .ZERO
    case .Replace:         return .REPLACE
    case .Invert:          return .INVERT
    case .Increment_Clamp: return .INCREMENT_AND_CLAMP
    case .Increment_Wrap:  return .INCREMENT_AND_WRAP
    case .Decrement_Clamp: return .DECREMENT_AND_CLAMP
    case .Decrement_Wrap:  return .DECREMENT_AND_WRAP
    }
    unreachable()
}

vk_conv_to_compare_op :: proc "contextless" (
    fun: Compare_Function,
    loc := #caller_location,
) -> vk.CompareOp {
    switch fun {
    case .Undefined,
         .Always:        return .ALWAYS
    case .Never:         return .NEVER
    case .Less:          return .LESS
    case .Less_Equal:    return .LESS_OR_EQUAL
    case .Equal:         return .EQUAL
    case .Greater_Equal: return .GREATER_OR_EQUAL
    case .Greater:       return .GREATER
    case .Not_Equal:     return .NOT_EQUAL
    }
    unreachable()
}

vk_conv_to_blend_factor :: proc "contextless" (
    factor: Blend_Factor,
    loc := #caller_location,
) -> vk.BlendFactor {
    assert_contextless(factor != .Undefined, "Invalid blend factor", loc)
    #partial switch factor {
    case .Zero:                 return .ZERO
    case .One:                  return .ONE
    case .Src:                  return .SRC_COLOR
    case .One_Minus_Src:        return .ONE_MINUS_SRC_COLOR
    case .Src_Alpha:            return .SRC_ALPHA
    case .One_Minus_Src_Alpha:  return .ONE_MINUS_SRC_ALPHA
    case .Dst:                  return .DST_COLOR
    case .One_Minus_Dst:        return .ONE_MINUS_DST_COLOR
    case .Dst_Alpha:            return .DST_ALPHA
    case .One_Minus_Dst_Alpha:  return .ONE_MINUS_DST_ALPHA
    case .Src_Alpha_Saturated:  return .SRC_ALPHA_SATURATE
    case .Constant:             return .CONSTANT_COLOR
    case .One_Minus_Constant:   return .ONE_MINUS_CONSTANT_COLOR
    case .Src1:                 return .SRC1_COLOR
    case .One_Minus_Src1:       return .ONE_MINUS_SRC1_COLOR
    case .Src1_Alpha:           return .SRC1_ALPHA
    case .One_Minus_Src1_Alpha: return .ONE_MINUS_SRC1_ALPHA
    }
    unreachable()
}

vk_conv_to_blend_op :: proc "contextless" (
    operation: Blend_Operation,
    loc := #caller_location,
) -> vk.BlendOp {
    switch operation {
    case .Add:              return .ADD
    case .Subtract:         return .SUBTRACT
    case .Reverse_Subtract: return .REVERSE_SUBTRACT
    case .Min:              return .MIN
    case .Max:              return .MAX
    }
    unreachable()
}

vk_conv_to_color_component_flags :: proc "contextless" (
    writes: Color_Writes,
    loc := #caller_location,
) -> (
    flags: vk.ColorComponentFlags,
) {
    if .Red in writes {flags |= {.R}}
    if .Green in writes {flags |= {.G}}
    if .Blue in writes {flags |= {.B}}
    if .Alpha in writes {flags |= {.A}}
    return
}

vk_conv_to_buffer_usage_flags :: #force_inline proc "contextless" (
    usage: Buffer_Uses,
    loc := #caller_location,
) -> (
    flags: vk.BufferUsageFlags,
) {
    if .Copy_Src in usage {
        flags |= {.TRANSFER_SRC}
    }
    if .Copy_Dst in usage {
        flags |= {.TRANSFER_DST}
    }
    if .Uniform in usage {
        flags |= {.UNIFORM_BUFFER}
    }
    if usage & {.Storage_Read_Only, .Storage_Read_Write} != {} {
        flags |= {.STORAGE_BUFFER}
    }
    if .Index in usage {
        flags |= {.INDEX_BUFFER}
    }
    if .Vertex in usage {
        flags |= {.VERTEX_BUFFER}
    }
    if .Indirect in usage {
        flags |= {.INDIRECT_BUFFER}
    }
    if .Acceleration_Structure_Scratch in usage {
        flags += {.STORAGE_BUFFER, .SHADER_DEVICE_ADDRESS}
    }
    accel_input_usage := Buffer_Uses {
        .Bottom_Level_Acceleration_Structure_Input,
        .Top_Level_Acceleration_Structure_Input,
    }
    if usage & accel_input_usage != {} {
        flags += {.ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_KHR, .SHADER_DEVICE_ADDRESS}
    }
    if .Acceleration_Structure_Query in usage {
        flags += {.TRANSFER_DST}
    }
    return
}

vk_infer_memory_flags :: #force_inline proc "contextless" (
    usage: Buffer_Uses,
) -> vk.MemoryPropertyFlags {
    if usage & {.Map_Read, .Map_Write} != {} {
        return {.HOST_VISIBLE}
    }
    return {.DEVICE_LOCAL}
}

vk_shader_stages :: proc "contextless" (
    queue_flags: vk.QueueFlags,
) -> (stages: vk.PipelineStageFlags) {
    if .GRAPHICS in queue_flags {
        stages |= {.VERTEX_SHADER, .FRAGMENT_SHADER}
    }
    if .COMPUTE in queue_flags {
        stages |= {.COMPUTE_SHADER}
    }
    return
}

vk_conv_buffer_uses_to_barrier :: proc "contextless" (
    uses: Buffer_Uses,
    queue_flags: vk.QueueFlags,
) -> (
    stages: vk.PipelineStageFlags,
    access: vk.AccessFlags,
) {
    shader_stages := vk_shader_stages(queue_flags)

    if .Map_Read in uses {
        stages += {.HOST}
        access += {.HOST_READ}
    }
    if .Map_Write in uses {
        stages += {.HOST}
        access += {.HOST_WRITE}
    }
    if .Copy_Src in uses {
        stages += {.TRANSFER}
        access += {.TRANSFER_READ}
    }
    if .Copy_Dst in uses {
        stages += {.TRANSFER}
        access += {.TRANSFER_WRITE}
    }
    if .Uniform in uses {
        stages += shader_stages
        access += {.UNIFORM_READ}
    }
    if .Storage_Read_Only in uses {
        stages += shader_stages
        access += {.SHADER_READ}
    }
    if .Storage_Read_Write in uses {
        stages += shader_stages
        access += {.SHADER_READ, .SHADER_WRITE}
    }
    if .Index in uses {
        stages += {.VERTEX_INPUT}
        access += {.INDEX_READ}
    }
    if .Vertex in uses {
        stages += {.VERTEX_INPUT}
        access += {.VERTEX_ATTRIBUTE_READ}
    }
    if .Indirect in uses {
        stages += {.DRAW_INDIRECT}
        access += {.INDIRECT_COMMAND_READ}
    }

    acceleration_structure_inputs := Buffer_Uses {
        .Bottom_Level_Acceleration_Structure_Input,
        .Top_Level_Acceleration_Structure_Input,
        .Acceleration_Structure_Scratch,
    }
    if uses & acceleration_structure_inputs != {} {
        stages += {.ACCELERATION_STRUCTURE_BUILD_KHR}
        access += {
            .ACCELERATION_STRUCTURE_READ_KHR,
            .ACCELERATION_STRUCTURE_WRITE_KHR,
            .SHADER_READ,
        }
    }

    if .Acceleration_Structure_Query in uses {
        stages += {.TRANSFER}
        access += {.TRANSFER_WRITE}
    }

    return
}

vk_conv_texture_uses_to_barrier :: proc "contextless" (
    uses: Texture_Uses,
    queue_flags: vk.QueueFlags,
    support_store_op_none: bool,
) -> (
    stages: vk.PipelineStageFlags,
    access: vk.AccessFlags,
) {
    shader_stages := vk_shader_stages(queue_flags)

    if .Copy_Src in uses {
        stages |= {.TRANSFER}
        access |= {.TRANSFER_READ}
    }
    if .Copy_Dst in uses {
        stages |= {.TRANSFER}
        access |= {.TRANSFER_WRITE}
    }
    if .Resource in uses {
        stages |= shader_stages
        access |= {.SHADER_READ}
    }
    if .Color_Target in uses {
        stages |= {.COLOR_ATTACHMENT_OUTPUT}
        access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }

    if uses & {.Depth_Read, .Stencil_Read} != {} {
        stages |= {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS}
        access |= support_store_op_none \
            ? {.DEPTH_STENCIL_ATTACHMENT_READ} \
            : {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}
    }

    if uses & {.Depth_Write, .Stencil_Write} != {} {
        stages |= {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS}
        access |= {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}
    }

    if uses & {.Storage_Read_Only, .Storage_Read_Write, .Storage_Atomic} != {} {
        stages |= shader_stages
        access |= {.SHADER_READ}
    }

    if uses & {.Storage_Write_Only, .Storage_Read_Write, .Storage_Atomic} != {} {
        stages |= shader_stages
        access |= {.SHADER_WRITE}
    }

    if uses == {} || uses == {.Uninitialized} || uses == {.Present} {
        stages |= {.TOP_OF_PIPE}
        access = {}
    }

    return
}

vk_conv_texture_uses_to_image_layout :: proc(
    usage: Texture_Uses,
    format: Texture_Format,
    loc := #caller_location,
) -> vk.ImageLayout {
    is_color := !(texture_format_has_depth_aspect(format) ||
        texture_format_has_stencil_aspect(format))

    switch {
    case usage == { .Uninitialized }:
        return .UNDEFINED
    case usage == { .Copy_Src }:
        return .TRANSFER_SRC_OPTIMAL
    case usage == { .Copy_Dst }:
        return .TRANSFER_DST_OPTIMAL
    case usage == { .Resource } && is_color:
        return .SHADER_READ_ONLY_OPTIMAL
    case usage == { .Color_Target }:
        return .COLOR_ATTACHMENT_OPTIMAL
    case usage == { .Present }:
        return .PRESENT_SRC_KHR
    case is_color:
        return .GENERAL
    case:
        depth_write := .Depth_Write in usage
        stencil_write := .Stencil_Write in usage
        switch {
        case depth_write && stencil_write:
            return .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        case !depth_write && stencil_write:
            return .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL
        case depth_write && !stencil_write:
            return .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL
        case:
            return .DEPTH_STENCIL_READ_ONLY_OPTIMAL
        }
    }
}

is_binding_active :: #force_inline proc "contextless" (v: $T) -> bool {
    return v != T(0) && v != T(1) // Binding_Not_Used = 0, Undefined = 1
}

vk_conv_to_descriptor_type :: proc(entry: Bind_Group_Layout_Entry) -> vk.DescriptorType {
    switch b in entry.type {
    case Buffer_Binding_Layout:
        #partial switch b.type {
        case .Storage, .Read_Only_Storage:
            return .STORAGE_BUFFER_DYNAMIC if b.has_dynamic_offset else .STORAGE_BUFFER
        case .Uniform:
            return .UNIFORM_BUFFER_DYNAMIC if b.has_dynamic_offset else .UNIFORM_BUFFER
        case .Undefined:
            unreachable()
        }
    case Sampler_Binding_Layout:
        return .SAMPLER
    case Texture_Binding_Layout:
        return .SAMPLED_IMAGE
    case Storage_Texture_Binding_Layout:
        return .STORAGE_IMAGE
    case External_Texture_Binding_Layout:
        // no direct VkDescriptorType equivalent
        unreachable()
    }

    unreachable()
}

vk_conv_to_shader_stage_flags :: proc(stage: Shader_Stages) -> (flags: vk.ShaderStageFlags) {
    if .Vertex in stage {
        flags += { .VERTEX }
    }
    if .Fragment in stage {
        flags += { .FRAGMENT }
    }
    if .Compute in stage {
        flags += { .COMPUTE }
    }
    // if .Task in stage {
    //     flags += { .TASK_EXT }
    // }
    // if .Mesh in stage {
    //     flags += { .MESH_EXT }
    // }
    return
}

vk_conv_to_index_type :: #force_inline proc "contextless" (
    index_format: Index_Format,
    loc := #caller_location,
) -> vk.IndexType {
    switch index_format {
    case .Uint16: return .UINT16
    case .Uint32: return .UINT32
    case .Undefined:
        panic_contextless("Invalid index format", loc)
    }
    unreachable()
}

vk_conv_to_image_type :: #force_inline proc "contextless" (
    dim: Texture_Dimension, loc := #caller_location,
) -> vk.ImageType {
    assert_contextless(dim != .Undefined, "Invalid texture dimension", loc)
    #partial switch dim {
    case .D1: return .D1
    case .D2: return .D2
    case .D3: return .D3
    }
    unreachable()
}

vk_conv_to_extent_3d :: #force_inline proc "contextless" (
    extent: Extent_3D, dim: Texture_Dimension, loc := #caller_location,
) -> vk.Extent3D {
    assert_contextless(dim != .Undefined, "Invalid texture dimension", loc)
    vk_extent := vk.Extent3D {
        width = extent.width,
        height = extent.height,
    }
    #partial switch dim {
    case .D1, .D2: vk_extent.depth = 1
    case .D3: vk_extent.depth = extent.depth_or_array_layers
    }
    return vk_extent
}

// vk_conv_to_image_usage_flags :: proc(
//     usage: Texture_Usages, format: Texture_Format, loc := #caller_location,
// ) -> (
//     flags: vk.ImageUsageFlags,
// ) {
//     if .Copy_Src         in usage { flags += {.TRANSFER_SRC} }
//     if .Copy_Dst         in usage { flags += {.TRANSFER_DST} }
//     if .Texture_Binding  in usage { flags += {.SAMPLED} }
//     if .Storage_Binding  in usage { flags += {.STORAGE} }
//     if .Storage_Atomic   in usage { flags += {.STORAGE} }
//     if .Transient_Attachment       in usage { flags += {.TRANSIENT_ATTACHMENT} }
//     if .Render_Attachment in usage {
//         if texture_format_is_depth_stencil_format(format) {
//             flags += {.DEPTH_STENCIL_ATTACHMENT}
//         } else {
//             flags += {.COLOR_ATTACHMENT}
//         }
//     }
//     return
// }

vk_conv_to_image_view_type :: proc(
    dim: Texture_View_Dimension, loc := #caller_location,
) -> vk.ImageViewType {
    #partial switch dim {
    case .D1: return .D1
    case .D2: return .D2
    case .D2_Array: return .D2_ARRAY
    case .Cube: return .CUBE
    case .Cube_Array: return .CUBE_ARRAY
    case .D3: return .D3
    }
    unreachable()
}

vk_conv_to_image_aspect_flags :: proc(
    aspect: Texture_Aspect, format: Texture_Format, loc := #caller_location,
) -> vk.ImageAspectFlags {
    depth := texture_format_has_depth_aspect(format)
    stencil := texture_format_has_stencil_aspect(format)

    #partial switch aspect {
    case .All:
        if depth && stencil { return { .DEPTH, .STENCIL } }
        if depth { return { .DEPTH } }
        if stencil { return { .STENCIL } }
        return { .COLOR }
    case .Depth_Only: { return { .DEPTH } }
    case .Stencil_Only: { return { .STENCIL } }
    case .Plane0: { return { .PLANE_0 } }
    case .Plane1: { return { .PLANE_1 } }
    case .Plane2: { return { .PLANE_2 } }
    case:
        unreachable()
    }
}

vk_conv_to_filter :: proc "contextless" (mode: Filter_Mode, loc := #caller_location) -> vk.Filter {
    switch mode {
    case .Nearest: return .NEAREST
    case .Linear: return .LINEAR
    }
    unreachable()
}

vk_cont_to_sampler_filter_mode :: proc "contextless" (
    mode: Mipmap_Filter_Mode,
    loc := #caller_location,
) -> vk.SamplerMipmapMode {
    switch mode {
    case .Nearest: return .NEAREST
    case .Linear: return .LINEAR
    }
    unreachable()
}

vk_conv_to_sampler_address_mode :: proc "contextless" (
    mode: Address_Mode,
    loc := #caller_location,
) -> vk.SamplerAddressMode {
    switch mode {
    case .Clamp_To_Edge: return .CLAMP_TO_EDGE
    case .Repeat: return .REPEAT
    case .Mirror_Repeat: return .MIRRORED_REPEAT
    case .Clamp_To_Border: return .CLAMP_TO_BORDER
    // case .Mirror_Clamp: return .MIRROR_CLAMP_TO_EDGE
    }
    unreachable()
}

vk_buffer_usage_to_location :: proc "contextless" (usage: Buffer_Uses) -> gpua.Memory_Location {
    is_cpu_read := .Map_Read in usage
    is_cpu_write := .Map_Write in usage
    switch {
    case is_cpu_read && is_cpu_write: return .Cpu_To_Gpu
    case is_cpu_read:                 return .Gpu_To_Cpu
    case is_cpu_write:                return .Cpu_To_Gpu
    case:                             return .Gpu_Only
    }
}
