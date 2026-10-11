#+build windows
#+private
package gpu

// // Vendor
// import "vendor:directx/d3d11"

// d3d11_conv_to_buffer_bind_flags :: proc "contextless" (
//     uses: Buffer_Uses,
//     loc := #caller_location,
// ) -> d3d11.BIND_FLAGS {
//     bind_flags: d3d11.BIND_FLAGS

//     if .Vertex in uses {
//         bind_flags += {.VERTEX_BUFFER}
//     }
//     if .Index in uses {
//         bind_flags += {.INDEX_BUFFER}
//     }
//     if .Uniform in uses {
//         bind_flags += {.CONSTANT_BUFFER}
//     }
//     if .Storage_Read_Write in uses {
//         assert_contextless(!buffer_uses_is_mappable(uses),
//             "GPU-writable storage buffer cannot also be mappable", loc)
//         bind_flags += {.UNORDERED_ACCESS}
//     }
//     if .Storage_Read_Only in uses {
//         bind_flags += {.SHADER_RESOURCE}
//     }

//     // D3D11 has no native buffer<->texture copy path. Buffers that exist purely
//     // as CopySrc/CopyDst staging for such copies go through a compute-shader copy
//     // instead, which requires UAV binding.
//     if buffer_uses_is_subset(uses, BUFFER_USES_COPY) {
//         bind_flags += {.UNORDERED_ACCESS}
//     }

//     return bind_flags
// }

// d3d11_conv_to_buffer_misc_flags :: proc "contextless" (
//     uses: Buffer_Uses,
// ) -> d3d11.RESOURCE_MISC_FLAGS {
//     misc_flags: d3d11.RESOURCE_MISC_FLAGS

//     if (uses & (Buffer_Uses{.Storage_Read_Write, .Storage_Read_Only})) != {} {
//         misc_flags += {.BUFFER_ALLOW_RAW_VIEWS}
//     }
//     if .Indirect in uses {
//         misc_flags += {.DRAWINDIRECT_ARGS}
//     }

//     return misc_flags
// }

// d3d11_conv_to_primitive_topology :: proc "contextless" (
//     topology: Primitive_Topology,
//     loc := #caller_location,
// ) -> d3d11.PRIMITIVE_TOPOLOGY {
//     assert_contextless(topology != .Undefined, "Invalid primitive topology", loc)
//     #partial switch topology {
//     case .Point_List:     return .POINTLIST
//     case .Line_List:      return .LINELIST
//     case .Line_Strip:     return .LINESTRIP
//     case .Triangle_List:  return .TRIANGLELIST
//     case .Triangle_Strip: return .TRIANGLESTRIP
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_cull_mode :: proc "contextless" (
//     face: Cull_Mode, loc := #caller_location,
// ) -> d3d11.CULL_MODE {
//     assert_contextless(face != .Undefined, "Invalid primitive topology", loc)
//     #partial switch face {
//     case .None:  return .NONE
//     case .Front: return .FRONT
//     case .Back:  return .BACK
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_blend :: proc "contextless" (
//     factor: Blend_Factor, loc := #caller_location,
// ) -> d3d11.BLEND {
//     assert_contextless(factor != .Undefined, "Invalid blend factor", loc)
//     #partial switch factor {
//     case .Zero:                 return .ZERO
//     case .One:                  return .ONE
//     case .Src:                  return .SRC_COLOR
//     case .One_Minus_Src:        return .INV_SRC_COLOR
//     case .Src_Alpha:            return .SRC_ALPHA
//     case .One_Minus_Src_Alpha:  return .INV_SRC_ALPHA
//     case .Dst:                  return .DEST_COLOR
//     case .One_Minus_Dst:        return .INV_DEST_COLOR
//     case .Dst_Alpha:            return .DEST_ALPHA
//     case .One_Minus_Dst_Alpha:  return .INV_DEST_ALPHA
//     case .Src_Alpha_Saturated:  return .SRC_ALPHA_SAT
//     case .Constant:             return .BLEND_FACTOR
//     case .One_Minus_Constant:   return .INV_BLEND_FACTOR
//     case .Src1:                 return .SRC1_COLOR
//     case .One_Minus_Src1:       return .INV_SRC1_COLOR
//     case .Src1_Alpha:           return .SRC1_ALPHA
//     case .One_Minus_Src1_Alpha: return .INV_SRC1_ALPHA
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_blend_alpha :: proc "contextless" (
//     factor: Blend_Factor, loc := #caller_location,
// ) -> d3d11.BLEND {
//     #partial switch factor {
//     case .Src:            return .SRC_ALPHA
//     case .One_Minus_Src:  return .INV_SRC_ALPHA
//     case .Dst:            return .DEST_ALPHA
//     case .One_Minus_Dst:  return .INV_DEST_ALPHA
//     case .Src1:           return .SRC1_ALPHA
//     case .One_Minus_Src1: return .INV_SRC1_ALPHA
//     case:
//         return d3d11_conv_to_blend(factor, loc)
//     }
//     unreachable()
// }

// d3d11_conv_to_blend_op :: proc "contextless" (
//     operation: Blend_Operation, loc := #caller_location,
// ) -> d3d11.BLEND_OP {
//     assert_contextless(operation != .Undefined, "Invalid blend operation", loc)
//     #partial switch operation {
//     case .Add:              return .ADD
//     case .Subtract:         return .SUBTRACT
//     case .Reverse_Subtract: return .REV_SUBTRACT
//     case .Min:              return .MIN
//     case .Max:              return .MAX
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_color_write_enable :: #force_inline proc "contextless" (
//     color_write_mask: Color_Writes,
// ) -> (mask: u8) {
//     if .Red in color_write_mask   { mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.RED) }
//     if .Green in color_write_mask { mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.GREEN) }
//     if .Blue in color_write_mask  { mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.BLUE) }
//     if .Alpha in color_write_mask { mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.ALPHA) }
//     return
// }

// d3d11_conv_to_comparison_func :: #force_inline proc "contextless" (
//     func: Compare_Function, loc := #caller_location,
// ) -> d3d11.COMPARISON_FUNC {
//     assert_contextless(func != .Undefined, "Invalid compare function", loc)
//     #partial switch func {
//     case .Never:         return .NEVER
//     case .Less:          return .LESS
//     case .Less_Equal:    return .LESS_EQUAL
//     case .Greater:       return .GREATER
//     case .Greater_Equal: return .GREATER_EQUAL
//     case .Equal:         return .EQUAL
//     case .Not_Equal:     return .NOT_EQUAL
//     case .Always:        return .ALWAYS
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_stencil_op :: #force_inline proc "contextless" (
//     op: Stencil_Operation, loc := #caller_location,
// ) -> d3d11.STENCIL_OP {
//     assert_contextless(op != .Undefined, "Invalid stencil operation", loc)
//     #partial switch op {
//     case .Keep:            return .KEEP
//     case .Zero:            return .ZERO
//     case .Replace:         return .REPLACE
//     case .Increment_Clamp: return .INCR_SAT
//     case .Decrement_Clamp: return .DECR_SAT
//     case .Invert:          return .INVERT
//     case .Increment_Wrap:  return .INCR
//     case .Decrement_Wrap:  return .DECR
//     case:
//         unreachable()
//     }
// }

// d3d11_conv_to_texture_bind_flags :: proc "contextless" (
//     uses: Texture_Uses,
//     format: Texture_Format,
//     loc := #caller_location,
// ) -> d3d11.BIND_FLAGS {
//     bind_flags: d3d11.BIND_FLAGS

//     if .Resource in uses {
//         bind_flags |= {.SHADER_RESOURCE}
//     }
//     if uses & {
//         .Storage_Read_Only,
//         .Storage_Write_Only,
//         .Storage_Read_Write,
//         .Storage_Atomic} != {} {
//         bind_flags |= {.UNORDERED_ACCESS, .SHADER_RESOURCE}
//     }
//     if uses & {.Color_Target, .Depth_Stencil_Read, .Depth_Stencil_Write} != {} {
//         bind_flags |= texture_format_is_depth_stencil_format(format, loc) \
//             ? {.DEPTH_STENCIL} \
//             : {.RENDER_TARGET}
//     }

//     return bind_flags
// }

// d3d11_conv_to_texture_desc :: proc "contextless" (
//     $T: typeid,
//     desc_impl: Texture_Descriptor_Impl,
//     kind: D3D11_Texture_Kind,
//     loc := #caller_location,
// ) -> (desc: T) {
//     when T == d3d11.TEXTURE1D_DESC {
//         desc.Width = desc_impl.size.width
//         desc.ArraySize = desc_impl.size.depth_or_array_layers
//         desc.MiscFlags = {}
//     } else when T == d3d11.TEXTURE2D_DESC {
//         desc.Width = desc_impl.size.width
//         desc.Height = desc_impl.size.height
//         desc.ArraySize = desc_impl.size.depth_or_array_layers
//         desc.SampleDesc.Count = desc_impl.sample_count
//         desc.SampleDesc.Quality = 0
//         desc.MiscFlags = {}
//         if texture_descriptor_is_cube_compatible(desc_impl) {
//             desc.MiscFlags |= {.TEXTURECUBE}
//         }
//     } else when T == d3d11.TEXTURE3D_DESC {
//         desc.Width = desc_impl.size.width
//         desc.Height = desc_impl.size.height
//         desc.Depth = desc_impl.size.depth_or_array_layers
//         desc.MiscFlags = {}
//     } else {
//         #panic("D3D11: unsupported texture desc type")
//     }

//     desc.MipLevels = desc_impl.mip_level_count

//     // To sample from a depth or stencil texture, we need to create a
//     // typeless texture.
//     needs_typeless_format :=
//         texture_format_is_depth_stencil_format(desc_impl.format, loc) &&
//         .Resource in desc_impl.internal_usage

//     // We need to use the typeless format if view format reinterpretation is required.
//     needs_typeless_format |= len(desc_impl.view_formats) > 0

//     // We need to use the typeless format if it's a staging texture for
//     // writing to depth-stencil textures.
//     needs_typeless_format |=
//         texture_format_is_combined_depth_stencil_format(desc_impl.format, loc) &&
//         kind == .Staging

//     desc.Format = needs_typeless_format \
//         ? d3d_conv_to_dxgi_format_typeless(desc_impl.format, loc) \
//         : d3d_conv_to_dxgi_format(desc_impl.format)

//     desc.Usage = kind == .Staging ? .STAGING : .DEFAULT
//     desc.BindFlags = d3d11_conv_to_texture_bind_flags(desc_impl.internal_usage, desc_impl.format)

//     CPU_READ_WRITE_FLAGS :: d3d11.CPU_ACCESS_FLAGS{.READ, .WRITE}
//     desc.CPUAccessFlags = kind == .Staging ? CPU_READ_WRITE_FLAGS : {}

//     return
// }
