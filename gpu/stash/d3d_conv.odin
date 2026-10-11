#+build windows
#+private
package gpu

// // Vendor
// import "vendor:directx/dxgi"

// d3d_conv_to_dxgi_format :: proc "contextless" (
//     format: Texture_Format, loc := #caller_location,
// ) -> dxgi.FORMAT {
//     assert_contextless(format != .Undefined, "Invalid texture format", loc)

//     #partial switch format {
//     case .R8_Unorm:              return .R8_UNORM
//     case .R8_Snorm:              return .R8_SNORM
//     case .R8_Uint:               return .R8_UINT
//     case .R8_Sint:               return .R8_SINT

//     case .R16_Unorm:             return .R16_UNORM
//     case .R16_Snorm:             return .R16_SNORM
//     case .R16_Uint:              return .R16_UINT
//     case .R16_Sint:              return .R16_SINT
//     case .R16_Float:             return .R16_FLOAT

//     case .RG8_Unorm:             return .R8G8_UNORM
//     case .RG8_Snorm:             return .R8G8_SNORM
//     case .RG8_Uint:              return .R8G8_UINT
//     case .RG8_Sint:              return .R8G8_SINT

//     case .R32_Float:             return .R32_FLOAT
//     case .R32_Uint:              return .R32_UINT
//     case .R32_Sint:              return .R32_SINT

//     case .RG16_Unorm:            return .R16G16_UNORM
//     case .RG16_Snorm:            return .R16G16_SNORM
//     case .RG16_Uint:             return .R16G16_UINT
//     case .RG16_Sint:             return .R16G16_SINT
//     case .RG16_Float:            return .R16G16_FLOAT

//     case .RGBA8_Unorm:           return .R8G8B8A8_UNORM
//     case .RGBA8_Unorm_Srgb:      return .R8G8B8A8_UNORM_SRGB
//     case .RGBA8_Snorm:           return .R8G8B8A8_SNORM
//     case .RGBA8_Uint:            return .R8G8B8A8_UINT
//     case .RGBA8_Sint:            return .R8G8B8A8_SINT

//     case .BGRA8_Unorm:           return .B8G8R8A8_UNORM
//     case .BGRA8_Unorm_Srgb:      return .B8G8R8A8_UNORM_SRGB

//     case .RGB10A2_Uint:          return .R10G10B10A2_UINT
//     case .RGB10A2_Unorm:         return .R10G10B10A2_UNORM
//     case .RG11B10_Ufloat:        return .R11G11B10_FLOAT
//     case .RGB9E5_Ufloat:         return .R9G9B9E5_SHAREDEXP

//     case .RG32_Float:            return .R32G32_FLOAT
//     case .RG32_Uint:             return .R32G32_UINT
//     case .RG32_Sint:             return .R32G32_SINT

//     case .RGBA16_Unorm:          return .R16G16B16A16_UNORM
//     case .RGBA16_Snorm:          return .R16G16B16A16_SNORM
//     case .RGBA16_Uint:           return .R16G16B16A16_UINT
//     case .RGBA16_Sint:           return .R16G16B16A16_SINT
//     case .RGBA16_Float:          return .R16G16B16A16_FLOAT

//     case .RGBA32_Float:          return .R32G32B32A32_FLOAT
//     case .RGBA32_Uint:           return .R32G32B32A32_UINT
//     case .RGBA32_Sint:           return .R32G32B32A32_SINT

//     // Depth / Stencil
//     case .Stencil8:              return .D24_UNORM_S8_UINT
//     case .Depth16_Unorm:         return .D16_UNORM
//     case .Depth24Plus:           return .D24_UNORM_S8_UINT
//     case .Depth24Plus_Stencil8:  return .D24_UNORM_S8_UINT
//     case .Depth32_Float:         return .D32_FLOAT
//     case .Depth32Float_Stencil8: return .D32_FLOAT_S8X24_UINT

//     // BC compressed formats
//     case .BC1RGBA_Unorm:         return .BC1_UNORM
//     case .BC1RGBA_Unorm_Srgb:    return .BC1_UNORM_SRGB
//     case .BC2RGBA_Unorm:         return .BC2_UNORM
//     case .BC2RGBA_Unorm_Srgb:    return .BC2_UNORM_SRGB
//     case .BC3RGBA_Unorm:         return .BC3_UNORM
//     case .BC3RGBA_Unorm_Srgb:    return .BC3_UNORM_SRGB
//     case .BC4R_Unorm:            return .BC4_UNORM
//     case .BC4R_Snorm:            return .BC4_SNORM
//     case .BC5RG_Unorm:           return .BC5_UNORM
//     case .BC5RG_Snorm:           return .BC5_SNORM
//     case .BC6HRGB_Ufloat:        return .BC6H_UF16
//     case .BC6HRGB_Float:         return .BC6H_SF16
//     case .BC7RGBA_Unorm:         return .BC7_UNORM
//     case .BC7RGBA_Unorm_Srgb:    return .BC7_UNORM_SRGB

//     case .NV12:                  return .NV12
//     case .P010:                  return .P010

//     case .ETC2RGB8_Unorm,
//          .ETC2RGB8_Unorm_Srgb,
//          .ETC2RGB8A1_Unorm,
//          .ETC2RGB8A1_Unorm_Srgb,
//          .ETC2RGBA8_Unorm,
//          .ETC2RGBA8_Unorm_Srgb:
//         panic_contextless("D3D: ETC2 texture format is not supported", loc)

//     case .EACR11_Unorm,
//          .EACR11_Snorm,
//          .EACRG11_Unorm,
//          .EACRG11_Snorm:
//         panic_contextless("D3D: EAC texture format is not supported", loc)

//     case .ASTC4x4_Unorm,
//          .ASTC4x4_Unorm_Srgb,
//          .ASTC5x4_Unorm,
//          .ASTC5x4_Unorm_Srgb,
//          .ASTC5x5_Unorm,
//          .ASTC5x5_Unorm_Srgb,
//          .ASTC6x5_Unorm,
//          .ASTC6x5_Unorm_Srgb,
//          .ASTC6x6_Unorm,
//          .ASTC6x6_Unorm_Srgb,
//          .ASTC8x5_Unorm,
//          .ASTC8x5_Unorm_Srgb,
//          .ASTC8x6_Unorm,
//          .ASTC8x6_Unorm_Srgb,
//          .ASTC8x8_Unorm,
//          .ASTC8x8_Unorm_Srgb,
//          .ASTC10x5_Unorm,
//          .ASTC10x5_Unorm_Srgb,
//          .ASTC10x6_Unorm,
//          .ASTC10x6_Unorm_Srgb,
//          .ASTC10x8_Unorm,
//          .ASTC10x8_Unorm_Srgb,
//          .ASTC10x10_Unorm,
//          .ASTC10x10_Unorm_Srgb,
//          .ASTC12x10_Unorm,
//          .ASTC12x10_Unorm_Srgb,
//          .ASTC12x12_Unorm,
//          .ASTC12x12_Unorm_Srgb:
//         panic_contextless("D3D: ASTC texture format is not supported", loc)

//     case:
//         unreachable()
//     }
// }

// d3d_conv_to_dxgi_format_typeless :: proc "contextless" (
//     format: Texture_Format, loc := #caller_location,
// ) -> dxgi.FORMAT {
//     assert_contextless(format != .Undefined, "Invalid texture format", loc)

//     #partial switch format {
//     case .R8_Unorm,
//          .R8_Snorm,
//          .R8_Uint,
//          .R8_Sint:
//         return .R8_TYPELESS

//     case .R16_Unorm,
//          .R16_Snorm,
//          .R16_Uint,
//          .R16_Sint,
//          .R16_Float,
//          .Depth16_Unorm:
//         return .R16_TYPELESS

//     case .RG8_Unorm,
//          .RG8_Snorm,
//          .RG8_Uint,
//          .RG8_Sint:
//         return .R8G8_TYPELESS

//     case .R32_Uint,
//          .R32_Sint,
//          .R32_Float:
//         return .R32_TYPELESS

//     case .RG16_Unorm,
//          .RG16_Snorm,
//          .RG16_Uint,
//          .RG16_Sint,
//          .RG16_Float:
//         return .R16G16_TYPELESS

//     case .RGBA8_Unorm,
//          .RGBA8_Unorm_Srgb,
//          .RGBA8_Snorm,
//          .RGBA8_Uint,
//          .RGBA8_Sint:
//         return .R8G8B8A8_TYPELESS

//     case .BGRA8_Unorm,
//          .BGRA8_Unorm_Srgb:
//         return .B8G8R8A8_TYPELESS

//     case .RGB10A2_Uint,
//          .RGB10A2_Unorm:
//         return .R10G10B10A2_TYPELESS

//     case .RG11B10_Ufloat:
//         return .R11G11B10_FLOAT
//     case .RGB9E5_Ufloat:
//         return .R9G9B9E5_SHAREDEXP

//     case .RG32_Uint,
//          .RG32_Sint,
//          .RG32_Float:
//         return .R32G32_TYPELESS

//     case .RGBA16_Unorm,
//          .RGBA16_Snorm,
//          .RGBA16_Uint,
//          .RGBA16_Sint,
//          .RGBA16_Float:
//         return .R16G16B16A16_TYPELESS

//     case .RGBA32_Uint,
//          .RGBA32_Sint,
//          .RGBA32_Float:
//         return .R32G32B32A32_TYPELESS

//     case .Depth24Plus:
//         return .R24G8_TYPELESS

//     case .Depth32_Float:
//         return .R32_TYPELESS

//     case .Stencil8:
//         return .R24G8_TYPELESS

//     case .Depth24Plus_Stencil8:
//         return .R24G8_TYPELESS

//     case .Depth32Float_Stencil8:
//         return .R32G8X24_TYPELESS

//     case .BC1RGBA_Unorm,
//          .BC1RGBA_Unorm_Srgb:
//         return .BC1_TYPELESS

//     case .BC2RGBA_Unorm,
//          .BC2RGBA_Unorm_Srgb:
//         return .BC2_TYPELESS

//     case .BC3RGBA_Unorm,
//          .BC3RGBA_Unorm_Srgb:
//         return .BC3_TYPELESS

//     case .BC4R_Snorm,
//          .BC4R_Unorm:
//         return .BC4_TYPELESS

//     case .BC5RG_Snorm,
//          .BC5RG_Unorm:
//         return .BC5_TYPELESS

//     case .BC6HRGB_Float,
//          .BC6HRGB_Ufloat:
//         return .BC6H_TYPELESS

//     case .BC7RGBA_Unorm,
//          .BC7RGBA_Unorm_Srgb:
//         return .BC7_TYPELESS

//     case .NV12:
//         panic_contextless("D3D: NV12 typeless texture format is not supported", loc)

//     case .P010:
//         panic_contextless("D3D: P010 typeless texture format is not supported", loc)

//     case .ETC2RGB8_Unorm,
//          .ETC2RGB8_Unorm_Srgb,
//          .ETC2RGB8A1_Unorm,
//          .ETC2RGB8A1_Unorm_Srgb,
//          .ETC2RGBA8_Unorm,
//          .ETC2RGBA8_Unorm_Srgb:
//         panic_contextless("D3D: ETC2 typeless texture format is not supported", loc)

//     case .EACR11_Unorm,
//          .EACR11_Snorm,
//          .EACRG11_Unorm,
//          .EACRG11_Snorm:
//         panic_contextless("D3D: EAC typeless texture format is not supported", loc)

//     case .ASTC4x4_Unorm,
//          .ASTC4x4_Unorm_Srgb,
//          .ASTC5x4_Unorm,
//          .ASTC5x4_Unorm_Srgb,
//          .ASTC5x5_Unorm,
//          .ASTC5x5_Unorm_Srgb,
//          .ASTC6x5_Unorm,
//          .ASTC6x5_Unorm_Srgb,
//          .ASTC6x6_Unorm,
//          .ASTC6x6_Unorm_Srgb,
//          .ASTC8x5_Unorm,
//          .ASTC8x5_Unorm_Srgb,
//          .ASTC8x6_Unorm,
//          .ASTC8x6_Unorm_Srgb,
//          .ASTC8x8_Unorm,
//          .ASTC8x8_Unorm_Srgb,
//          .ASTC10x5_Unorm,
//          .ASTC10x5_Unorm_Srgb,
//          .ASTC10x6_Unorm,
//          .ASTC10x6_Unorm_Srgb,
//          .ASTC10x8_Unorm,
//          .ASTC10x8_Unorm_Srgb,
//          .ASTC10x10_Unorm,
//          .ASTC10x10_Unorm_Srgb,
//          .ASTC12x10_Unorm,
//          .ASTC12x10_Unorm_Srgb,
//          .ASTC12x12_Unorm,
//          .ASTC12x12_Unorm_Srgb:
//         panic_contextless("D3D: ASTC typeless texture format is not supported", loc)

//     case:
//         unreachable()
//     }
// }

// d3d_conv_to_vertex_format :: proc(
//     format: Vertex_Format,
//     loc := #caller_location,
// ) -> dxgi.FORMAT {
//     switch format {
//     // 8-bit formats
//     case .Uint8:     return .R8_UINT
//     case .Uint8x2:   return .R8G8_UINT
//     case .Uint8x4:   return .R8G8B8A8_UINT
//     case .Sint8:     return .R8_SINT
//     case .Sint8x2:   return .R8G8_SINT
//     case .Sint8x4:   return .R8G8B8A8_SINT
//     case .Unorm8:    return .R8_UNORM
//     case .Unorm8x2:  return .R8G8_UNORM
//     case .Unorm8x4:  return .R8G8B8A8_UNORM
//     case .Snorm8:    return .R8_SNORM
//     case .Snorm8x2:  return .R8G8_SNORM
//     case .Snorm8x4:  return .R8G8B8A8_SNORM

//     // 16-bit formats
//     case .Uint16:    return .R16_UINT
//     case .Uint16x2:  return .R16G16_UINT
//     case .Uint16x4:  return .R16G16B16A16_UINT
//     case .Sint16:    return .R16_SINT
//     case .Sint16x2:  return .R16G16_SINT
//     case .Sint16x4:  return .R16G16B16A16_SINT
//     case .Unorm16:   return .R16_UNORM
//     case .Unorm16x2: return .R16G16_UNORM
//     case .Unorm16x4: return .R16G16B16A16_UNORM
//     case .Snorm16:   return .R16_SNORM
//     case .Snorm16x2: return .R16G16_SNORM
//     case .Snorm16x4: return .R16G16B16A16_SNORM

//     // 16-bit float formats
//     case .Float16:   return .R16_FLOAT
//     case .Float16x2: return .R16G16_FLOAT
//     case .Float16x4: return .R16G16B16A16_FLOAT

//     // 32-bit float formats
//     case .Float32:   return .R32_FLOAT
//     case .Float32x2: return .R32G32_FLOAT
//     case .Float32x3: return .R32G32B32_FLOAT
//     case .Float32x4: return .R32G32B32A32_FLOAT

//     // 32-bit integer formats
//     case .Uint32:    return .R32_UINT
//     case .Uint32x2:  return .R32G32_UINT
//     case .Uint32x3:  return .R32G32B32_UINT
//     case .Uint32x4:  return .R32G32B32A32_UINT
//     case .Sint32:    return .R32_SINT
//     case .Sint32x2:  return .R32G32_SINT
//     case .Sint32x3:  return .R32G32B32_SINT
//     case .Sint32x4:  return .R32G32B32A32_SINT

//     // Packed formats
//     case .Unorm10_10_10_2: return .R10G10B10A2_UNORM
//     case .Unorm8x4BGRA:    return .B8G8R8A8_UNORM
//     }

//     unreachable()
// }

// d3d_conv_to_index_format :: proc(
//     format: Index_Format, loc := #caller_location,
// ) -> dxgi.FORMAT {
//     #partial switch format {
//     case .Uint16: return .R16_UINT
//     case .Uint32: return .R32_UINT
//     case:
//         panic("Invalid index format", loc)
//     }
// }

// d3d_conv_to_gpu_preference :: proc "contextless" (
//     preference: Power_Preference,
// ) -> dxgi.GPU_PREFERENCE {
//     #partial switch preference {
//     case .Low_Power:
//         return .MINIMUM_POWER
//     case .High_Performance:
//         return .HIGH_PERFORMANCE
//     case:
//         return .UNSPECIFIED
//     }
//     unreachable()
// }

// d3d_conv_to_buffer_count :: proc "contextless" (
//     mode: Present_Mode, loc := #caller_location,
// ) -> u32 {
//     assert_contextless(mode != .Undefined, "Invalid present mode", loc)
//     assert_contextless(mode != .Fifo_Relaxed, "Invalid present mode", loc)

//     #partial switch mode {
//     case .Immediate, .Fifo:
//         return 2
//     case .Mailbox:
//         return 3
//     case:
//         unreachable()
//     }
// }

// d3d_conv_to_swap_chain_flags :: proc "contextless" (
//     mode: Present_Mode,
//     allow_tearing: bool,
// ) -> dxgi.SWAP_CHAIN {
//     flags := dxgi.SWAP_CHAIN{ .ALLOW_MODE_SWITCH }
//     if allow_tearing && mode == .Immediate {
//         flags += { .ALLOW_TEARING }
//     }
//     return flags
// }

// d3d_conv_to_dxgi_usage :: proc "contextless" (
//     usages: Texture_Usages,
//     format: Texture_Format,
//     loc := #caller_location,
// ) -> dxgi.USAGE {
//     dxgi_usage := dxgi.USAGE {}
//     if .Texture_Binding in usages {
//         dxgi_usage += {.SHADER_INPUT}
//     }
//     if .Copy_Src in usages && texture_format_is_blit_to_buffer_supported(format, loc) {
//         dxgi_usage += {.SHADER_INPUT}
//     }
//     if .Storage_Binding in usages {
//         dxgi_usage += {.UNORDERED_ACCESS}
//     }
//     if .Render_Attachment in usages {
//         dxgi_usage += {.RENDER_TARGET_OUTPUT}
//     }
//     return dxgi_usage
// }

// d3d_present_mode_to_swap_interval :: proc(mode: Present_Mode) -> u32 {
//     switch mode {
//     case .Immediate, .Mailbox:
//         return 0
//     case .Fifo, .Fifo_Relaxed, .Undefined:
//         return 1
//     }
//     unreachable()
// }

// // SRVs and UAVs can't use the depth or typeless formats: see
// // https://microsoft.github.io/DirectX-Specs/d3d/PlanarDepthStencilDDISpec.html#view-creation
// d3d_conv_format_for_srv_uav :: proc(
//     format: Texture_Format,
//     aspect: Format_Aspects,
//     loc := #caller_location,
// ) -> dxgi.FORMAT {
//     assert(format != .Undefined, "Invalid texture format", loc)

//     switch {
//     case format == .Depth16_Unorm && aspect == {.Depth}:
//         return .R16_UNORM

//     case format == .Depth32_Float && aspect == {.Depth}:
//         return .R32_FLOAT

//     case format == .Depth32Float_Stencil8 && aspect == {.Depth}:
//         return .R32_FLOAT_X8X24_TYPELESS

//     case (format == .Depth24Plus || format == .Depth24Plus_Stencil8) && aspect == {.Depth}:
//         return .R24_UNORM_X8_TYPELESS

//     case format == .Depth32Float_Stencil8 && aspect == {.Stencil}:
//         return .X32_TYPELESS_G8X24_UINT

//     case (format == .Stencil8 || format == .Depth24Plus_Stencil8) && aspect == {.Stencil}:
//         return .X24_TYPELESS_G8_UINT

//     case aspect == {.Depth} || aspect == {.Stencil}:
//         // Any other depth/stencil aspect combination has no valid SRV/UAV format.
//         return .UNKNOWN

//     case:
//         return d3d_conv_to_dxgi_format(format, loc)
//     }
// }

// d3d_shader_resource_view_format :: proc(
//     texture_format: Texture_Format,
//     view_format: Texture_Format,
//     aspect: Texture_Aspect,
//     loc := #caller_location,
// ) -> dxgi.FORMAT {
//     assert(aspect != .Undefined, loc = loc)
//     if aspect == .All && texture_format_is_depth_stencil_format(texture_format) {
//         // Depth-stencil textures can't be sampled with both aspects at once.
//         return .UNKNOWN
//     }

//     // Reinterprets a TYPELESS-allocated texture as a single-plane
//     // shader-accessible view.
//     srv_format := d3d_conv_to_dxgi_format(view_format)

//     if texture_format_is_depth_stencil_format(texture_format) {
//         // Depth-stencil formats must be mapped to a compatible
//         // shader-accessible format.
//         #partial switch d3d_conv_to_dxgi_format(texture_format) {
//         case .D32_FLOAT:
//             srv_format = .R32_FLOAT
//         case .D16_UNORM:
//             srv_format = .R16_UNORM
//         case .D24_UNORM_S8_UINT:
//             #partial switch aspect {
//             case .Depth_Only:
//                 srv_format = .R24_UNORM_X8_TYPELESS
//             case .Stencil_Only:
//                 srv_format = .X24_TYPELESS_G8_UINT
//             case:
//                 unreachable()
//             }
//         case .D32_FLOAT_S8X24_UINT:
//             #partial switch aspect {
//             case .Depth_Only:
//                 srv_format = .R32_FLOAT_X8X24_TYPELESS
//             case .Stencil_Only:
//                 srv_format = .X32_TYPELESS_G8X24_UINT
//             case:
//                 unreachable()
//             }
//         case:
//             unreachable()
//         }
//     }

//     return srv_format
// }
