#+build windows
package gpu

// Core
import "core:log"
import intr "base:intrinsics"
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/dxgi"

@(disabled = !ODIN_DEBUG)
d3d_check :: #force_inline proc(
    res: win32.HRESULT,
    message := "Detected D3D error",
    loc := #caller_location,
) {
    if (res >= 0) {
        return
    }

    log.panicf("%v. Error code: %0x", message, u32(res), location = loc)
}

d3d_get_refcount :: proc(obj: ^$T) -> u32 {
    if obj == nil do return 0
    obj->AddRef()
    return obj->Release()
}

d3d_present_mode_to_buffer_count :: proc(mode: Present_Mode) -> u32 {
    switch mode {
    case .Immediate, .Fifo, .Fifo_Relaxed, .Undefined:
        return 2
    case .Mailbox:
        return 3
    }
    unreachable()
}

d3d_present_mode_to_swap_interval :: proc(mode: Present_Mode) -> u32 {
    switch mode {
    case .Immediate, .Mailbox:
        return 0
    case .Fifo, .Fifo_Relaxed, .Undefined:
        return 1
    }
    unreachable()
}

d3d_present_mode_to_swap_chain_flags :: proc(mode: Present_Mode) -> dxgi.SWAP_CHAIN {
    flags := dxgi.SWAP_CHAIN{ .ALLOW_MODE_SWITCH }
    if mode == .Immediate {
        flags += { .ALLOW_TEARING }
    }
    return flags
}

d3d_to_dxgi_usage :: proc(usages: Texture_Usages) -> dxgi.USAGE {
    dxgi_usage := dxgi.USAGE {}
    if .Texture_Binding in usages {
        dxgi_usage += {.SHADER_INPUT}
    }
    if .Storage_Binding in usages {
        dxgi_usage += {.UNORDERED_ACCESS}
    }
    if .Render_Attachment in usages {
        dxgi_usage += {.RENDER_TARGET_OUTPUT}
    }
    return dxgi_usage
}

d3d_dxgi_texture_format :: proc(format: Texture_Format) -> dxgi.FORMAT {
    #partial switch format {
    case .Undefined:              return .UNKNOWN

    case .R8_Unorm:               return .R8_UNORM
    case .R8_Snorm:               return .R8_SNORM
    case .R8_Uint:                return .R8_UINT
    case .R8_Sint:                return .R8_SINT

    case .R16_Unorm:              return .R16_UNORM
    case .R16_Snorm:              return .R16_SNORM
    case .R16_Uint:               return .R16_UINT
    case .R16_Sint:               return .R16_SINT
    case .R16_Float:              return .R16_FLOAT

    case .Rg8_Unorm:              return .R8G8_UNORM
    case .Rg8_Snorm:              return .R8G8_SNORM
    case .Rg8_Uint:               return .R8G8_UINT
    case .Rg8_Sint:               return .R8G8_SINT

    case .R32_Float:              return .R32_FLOAT
    case .R32_Uint:               return .R32_UINT
    case .R32_Sint:               return .R32_SINT

    case .Rg16_Unorm:             return .R16G16_UNORM
    case .Rg16_Snorm:             return .R16G16_SNORM
    case .Rg16_Uint:              return .R16G16_UINT
    case .Rg16_Sint:              return .R16G16_SINT
    case .Rg16_Float:             return .R16G16_FLOAT

    case .Rgba8_Unorm:            return .R8G8B8A8_UNORM
    case .Rgba8_Unorm_Srgb:       return .R8G8B8A8_UNORM_SRGB
    case .Rgba8_Snorm:            return .R8G8B8A8_SNORM
    case .Rgba8_Uint:             return .R8G8B8A8_UINT
    case .Rgba8_Sint:             return .R8G8B8A8_SINT

    case .Bgra8_Unorm:            return .B8G8R8A8_UNORM
    case .Bgra8_Unorm_Srgb:       return .B8G8R8A8_UNORM_SRGB

    case .Rgb10a2_Uint:           return .R10G10B10A2_UINT
    case .Rgb10a2_Unorm:          return .R10G10B10A2_UNORM
    case .Rg11b10_Ufloat:         return .R11G11B10_FLOAT
    case .Rgb9e5_Ufloat:          return .R9G9B9E5_SHAREDEXP

    case .Rg32_Float:             return .R32G32_FLOAT
    case .R64_Uint:               return .R32G32_UINT
    case .Rg32_Uint:              return .R32G32_UINT
    case .Rg32_Sint:              return .R32G32_SINT

    case .Rgba16_Unorm:           return .R16G16B16A16_UNORM
    case .Rgba16_Snorm:           return .R16G16B16A16_SNORM
    case .Rgba16_Uint:            return .R16G16B16A16_UINT
    case .Rgba16_Sint:            return .R16G16B16A16_SINT
    case .Rgba16_Float:           return .R16G16B16A16_FLOAT

    case .Rgba32_Float:           return .R32G32B32A32_FLOAT
    case .Rgba32_Uint:            return .R32G32B32A32_UINT
    case .Rgba32_Sint:            return .R32G32B32A32_SINT

    // Depth / Stencil
    case .Stencil8:               return .D24_UNORM_S8_UINT
    case .Depth16_Unorm:          return .D16_UNORM
    case .Depth24_Plus:           return .D24_UNORM_S8_UINT
    case .Depth24_Plus_Stencil8:  return .D24_UNORM_S8_UINT
    case .Depth32_Float:          return .D32_FLOAT
    case .Depth32_Float_Stencil8: return .D32_FLOAT_S8X24_UINT

    // BC compressed formats
    case .Bc1_Rgba_Unorm:         return .BC1_UNORM
    case .Bc1_Rgba_Unorm_Srgb:    return .BC1_UNORM_SRGB
    case .Bc2_Rgba_Unorm:         return .BC2_UNORM
    case .Bc2_Rgba_Unorm_Srgb:    return .BC2_UNORM_SRGB
    case .Bc3_Rgba_Unorm:         return .BC3_UNORM
    case .Bc3_Rgba_Unorm_Srgb:    return .BC3_UNORM_SRGB
    case .Bc4_R_Unorm:            return .BC4_UNORM
    case .Bc4_R_Snorm:            return .BC4_SNORM
    case .Bc5_Rg_Unorm:           return .BC5_UNORM
    case .Bc5_Rg_Snorm:           return .BC5_SNORM
    case .Bc6_hRgb_Ufloat:        return .BC6H_UF16
    case .Bc6_hRgb_Float:         return .BC6H_SF16
    case .Bc7_Rgba_Unorm:         return .BC7_UNORM
    case .Bc7_Rgba_Unorm_Srgb:    return .BC7_UNORM_SRGB

    case .NV12:                   return .NV12
    case .P010:                   return .P010
    }
    return .UNKNOWN
}

d3d_dxgi_vertex_format :: proc(format: Vertex_Format, loc := #caller_location) -> dxgi.FORMAT {
    switch format {
    // 8-bit formats
    case .Uint8:     return .R8_UINT
    case .Uint8x2:   return .R8G8_UINT
    case .Uint8x4:   return .R8G8B8A8_UINT
    case .Sint8:     return .R8_SINT
    case .Sint8x2:   return .R8G8_SINT
    case .Sint8x4:   return .R8G8B8A8_SINT
    case .Unorm8:    return .R8_UNORM
    case .Unorm8x2:  return .R8G8_UNORM
    case .Unorm8x4:  return .R8G8B8A8_UNORM
    case .Snorm8:    return .R8_SNORM
    case .Snorm8x2:  return .R8G8_SNORM
    case .Snorm8x4:  return .R8G8B8A8_SNORM

    // 16-bit formats
    case .Uint16:    return .R16_UINT
    case .Uint16x2:  return .R16G16_UINT
    case .Uint16x4:  return .R16G16B16A16_UINT
    case .Sint16:    return .R16_SINT
    case .Sint16x2:  return .R16G16_SINT
    case .Sint16x4:  return .R16G16B16A16_SINT
    case .Unorm16:   return .R16_UNORM
    case .Unorm16x2: return .R16G16_UNORM
    case .Unorm16x4: return .R16G16B16A16_UNORM
    case .Snorm16:   return .R16_SNORM
    case .Snorm16x2: return .R16G16_SNORM
    case .Snorm16x4: return .R16G16B16A16_SNORM

    // 16-bit float formats
    case .Float16:   return .R16_FLOAT
    case .Float16x2: return .R16G16_FLOAT
    case .Float16x4: return .R16G16B16A16_FLOAT

    // 32-bit float formats
    case .Float32:   return .R32_FLOAT
    case .Float32x2: return .R32G32_FLOAT
    case .Float32x3: return .R32G32B32_FLOAT
    case .Float32x4: return .R32G32B32A32_FLOAT

    // 32-bit integer formats
    case .Uint32:    return .R32_UINT
    case .Uint32x2:  return .R32G32_UINT
    case .Uint32x3:  return .R32G32B32_UINT
    case .Uint32x4:  return .R32G32B32A32_UINT
    case .Sint32:    return .R32_SINT
    case .Sint32x2:  return .R32G32_SINT
    case .Sint32x3:  return .R32G32B32_SINT
    case .Sint32x4:  return .R32G32B32A32_SINT

    // 64-bit float formats - NOT SUPPORTED in D3D11 vertex input
    case .Float64, .Float64x2, .Float64x3, .Float64x4:
        log.error("64-bit float vertex formats are not supported by D3D11", location = loc)
        return .UNKNOWN

    // Packed formats
    case .Unorm10_10_10_2: return .R10G10B10A2_UNORM
    case .Unorm8x4Bgra:    return .B8G8R8A8_UNORM
    }

    return .UNKNOWN
}

d3d_dxgi_index_format :: proc(format: Index_Format, loc := #caller_location) -> dxgi.FORMAT {
    #partial switch format {
    case .Uint16: return .R16_UINT
    case .Uint32: return .R32_UINT
    case:
        panic("Invalid index format", loc)
    }
}
