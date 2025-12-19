#+build windows
package gpu

// Vendor
import "vendor:directx/d3d11"

D3D11_CONSTANT_BUFFER_ALIGNMENT :: size_of(f32) * 4 * 16  // 256 bytes
D3D11_STORAGE_BUFFER_ALIGNMENT  :: size_of(u32)           // 4 bytes
D3D11_INDIRECT_BUFFER_MIN_SIZE  :: 12                     // Minimum for draw indirect

d3d11_vertex_step_mode :: proc(mode: Vertex_Step_Mode) -> d3d11.INPUT_CLASSIFICATION {
    switch mode {
    case .Vertex:    return .VERTEX_DATA
    case .Instance:  return .INSTANCE_DATA
    case .Undefined:
        return .VERTEX_DATA // Default to vertex data
    }
    unreachable()
}

d3d11_primitive_topology :: proc(topology: Primitive_Topology) -> d3d11.PRIMITIVE_TOPOLOGY {
    switch topology {
    case .Point_List:     return .POINTLIST
    case .Line_List:      return .LINELIST
    case .Line_Strip:     return .LINESTRIP
    case .Triangle_List:  return .TRIANGLELIST
    case .Triangle_Strip: return .TRIANGLESTRIP
    case .Undefined:
        return .TRIANGLELIST // Default to triangle list
    }
    unreachable()
}

d3d11_cull_mode :: proc(face: Face) -> d3d11.CULL_MODE {
    switch face {
    case .None:      return .NONE
    case .Front:     return .FRONT
    case .Back:      return .BACK
    case .Undefined:
        return .NONE  // Default to no culling
    }
    unreachable()
}

d3d11_blend_factor :: proc(factor: Blend_Factor) -> d3d11.BLEND {
    switch factor {
    case .Zero:                 return .ZERO
    case .One:                  return .ONE
    case .Src:                  return .SRC_COLOR
    case .One_Minus_Src:        return .INV_SRC_COLOR
    case .Src_Alpha:            return .SRC_ALPHA
    case .One_Minus_Src_Alpha:  return .INV_SRC_ALPHA
    case .Dst:                  return .DEST_COLOR
    case .One_Minus_Dst:        return .INV_DEST_COLOR
    case .Dst_Alpha:            return .DEST_ALPHA
    case .One_Minus_Dst_Alpha:  return .INV_DEST_ALPHA
    case .Src_Alpha_Saturated:  return .SRC_ALPHA_SAT
    case .Constant:             return .BLEND_FACTOR
    case .One_Minus_Constant:   return .INV_BLEND_FACTOR
    case .Src1:                 return .SRC1_COLOR
    case .One_Minus_Src1:       return .INV_SRC1_COLOR
    case .Src1_Alpha:           return .SRC1_ALPHA
    case .One_Minus_Src1_Alpha: return .INV_SRC1_ALPHA
    case .Undefined:
        return .ONE  // Default to opaque
    }
    unreachable()
}

d3d11_blend_alpha_factor :: proc(factor: Blend_Factor) -> d3d11.BLEND {
    #partial switch factor {
    case .Src:            return .SRC_ALPHA
    case .One_Minus_Src:  return .INV_SRC_ALPHA
    case .Dst:            return .DEST_ALPHA
    case .One_Minus_Dst:  return .INV_DEST_ALPHA
    case .Src1:           return .SRC1_ALPHA
    case .One_Minus_Src1: return .INV_SRC1_ALPHA
    case:
        return d3d11_blend_factor(factor)
    }
    unreachable()
}

d3d11_blend_operation :: proc(operation: Blend_Operation) -> d3d11.BLEND_OP {
    switch operation {
    case .Add:              return .ADD
    case .Subtract:         return .SUBTRACT
    case .Reverse_Subtract: return .REV_SUBTRACT
    case .Min:              return .MIN
    case .Max:              return .MAX
    case .Undefined:
        return .ADD  // Default to additive blending
    }
    unreachable()
}

d3d11_color_write_mask :: proc(color_write_mask: Color_Writes) -> u8 {
    mask: u8
    if .Red in color_write_mask   do mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.RED)
    if .Green in color_write_mask do mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.GREEN)
    if .Blue in color_write_mask  do mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.BLUE)
    if .Alpha in color_write_mask do mask |= 1 << u8(d3d11.COLOR_WRITE_ENABLE.ALPHA)
    return mask
}

d3d11_stencil_op :: proc(op: Stencil_Operation) -> d3d11.STENCIL_OP {
    switch op {
    case .Keep:            return .KEEP
    case .Zero:            return .ZERO
    case .Replace:         return .REPLACE
    case .Increment_Clamp: return .INCR_SAT
    case .Decrement_Clamp: return .DECR_SAT
    case .Invert:          return .INVERT
    case .Increment_Wrap:  return .INCR
    case .Decrement_Wrap:  return .DECR
    case .Undefined:
        return .KEEP  // Default to keep existing value
    }
    unreachable()
}

d3d11_comparison_func :: proc(func: Compare_Function) -> d3d11.COMPARISON_FUNC {
    switch func {
    case .Never:         return .NEVER
    case .Less:          return .LESS
    case .Less_Equal:    return .LESS_EQUAL
    case .Greater:       return .GREATER
    case .Greater_Equal: return .GREATER_EQUAL
    case .Equal:         return .EQUAL
    case .Not_Equal:     return .NOT_EQUAL
    case .Always:        return .ALWAYS
    case .Undefined:
        return .ALWAYS  // Default to always pass
    }
    unreachable()
}

d3d11_stencil_face_state :: proc(state: Stencil_Face_State) -> d3d11.DEPTH_STENCILOP_DESC {
    return {
        StencilFailOp      = d3d11_stencil_op(state.fail_op),
        StencilDepthFailOp = d3d11_stencil_op(state.depth_fail_op),
        StencilPassOp      = d3d11_stencil_op(state.pass_op),
        StencilFunc        = d3d11_comparison_func(state.compare),
    }
}

d3d11_filter_type :: proc(mode: Filter_Mode) -> d3d11.FILTER_TYPE {
    switch mode {
    case .Nearest: return .POINT
    case .Linear:  return .LINEAR
    case .Undefined:
        return .LINEAR // Default to linear
    }
    unreachable()
}

d3d11_mipmap_filter_type :: proc(mode: Mipmap_Filter_Mode) -> d3d11.FILTER_TYPE {
    switch mode {
    case .Nearest: return .POINT
    case .Linear:  return .LINEAR
    case .Undefined:
        return .LINEAR // Default to linear
    }
    unreachable()
}

d3d11_texture_address_mode :: proc(mode: Address_Mode) -> d3d11.TEXTURE_ADDRESS_MODE {
    switch mode {
    case .Repeat:       return .WRAP
    case .Mirror_Repeat: return .MIRROR
    case .Clamp_To_Edge:  return .CLAMP
    case .Clamp_To_Border, .Undefined:
        return .CLAMP // Default to clamp
    }
    unreachable()
}

d3d11_encode_basic_filter :: #force_inline proc(
    min, mag, mip: d3d11.FILTER_TYPE,
    reduction: d3d11.FILTER_REDUCTION_TYPE,
) -> d3d11.FILTER {
    return d3d11.FILTER(
        ((u32(min) & d3d11.FILTER_TYPE_MASK) << d3d11.MIN_FILTER_SHIFT) |
        ((u32(mag) & d3d11.FILTER_TYPE_MASK) << d3d11.MAG_FILTER_SHIFT) |
        ((u32(mip) & d3d11.FILTER_TYPE_MASK) << d3d11.MIP_FILTER_SHIFT) |
        ((u32(reduction) & d3d11.FILTER_REDUCTION_TYPE_MASK) << d3d11.FILTER_REDUCTION_TYPE_SHIFT))
}

d3d11_encode_anisotropic_filter :: #force_inline proc(
    reduction: d3d11.FILTER_REDUCTION_TYPE = .STANDARD,
) -> d3d11.FILTER {
    return d3d11.FILTER(
        u32(d3d11.ANISOTROPIC_FILTERING_BIT) |
        u32(d3d11_encode_basic_filter(
            .LINEAR,
            .LINEAR,
            .LINEAR,
            reduction)))
}

d3d11_buffer_size_alignment :: proc(usage: Buffer_Usages) -> u32 {
    if .Uniform in usage {
        // Each number of constants must be a multiple of 16 shader constants
        return size_of(f32) * 4 * 16 // 256 bytes
    }

    if .Storage in usage || .Copy_Src in usage || .Copy_Dst in usage {
        // Unordered access buffers must be 4-byte aligned
        // Also for Copy_Dst/Copy_Src buffers used in compute shaders
        return size_of(u32)
    }

    return 1
}
