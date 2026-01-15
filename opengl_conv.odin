#+build windows, linux
package gpu

// Vendor
import gl "vendor:OpenGL"

Vertex_Format_Info :: struct {
    components:  i32,
    type:        u32,
    normalized:  bool,
    is_integer:  bool,
}

gl_get_vertex_format_info :: #force_inline proc "contextless" (format: Vertex_Format) -> Vertex_Format_Info {
    #partial switch format {
    case .Uint8x2:   return {2, gl.UNSIGNED_BYTE, false, true}
    case .Uint8x4:   return {4, gl.UNSIGNED_BYTE, false, true}
    case .Sint8x2:   return {2, gl.BYTE, false, true}
    case .Sint8x4:   return {4, gl.BYTE, false, true}
    case .Unorm8x2:  return {2, gl.UNSIGNED_BYTE, true, false}
    case .Unorm8x4:  return {4, gl.UNSIGNED_BYTE, true, false}
    case .Snorm8x2:  return {2, gl.BYTE, true, false}
    case .Snorm8x4:  return {4, gl.BYTE, true, false}
    case .Uint16x2:  return {2, gl.UNSIGNED_SHORT, false, true}
    case .Uint16x4:  return {4, gl.UNSIGNED_SHORT, false, true}
    case .Sint16x2:  return {2, gl.SHORT, false, true}
    case .Sint16x4:  return {4, gl.SHORT, false, true}
    case .Unorm16x2: return {2, gl.UNSIGNED_SHORT, true, false}
    case .Unorm16x4: return {4, gl.UNSIGNED_SHORT, true, false}
    case .Snorm16x2: return {2, gl.SHORT, true, false}
    case .Snorm16x4: return {4, gl.SHORT, true, false}
    case .Float16x2: return {2, gl.HALF_FLOAT, false, false}
    case .Float16x4: return {4, gl.HALF_FLOAT, false, false}
    case .Float32:   return {1, gl.FLOAT, false, false}
    case .Float32x2: return {2, gl.FLOAT, false, false}
    case .Float32x3: return {3, gl.FLOAT, false, false}
    case .Float32x4: return {4, gl.FLOAT, false, false}
    case .Uint32:    return {1, gl.UNSIGNED_INT, false, true}
    case .Uint32x2:  return {2, gl.UNSIGNED_INT, false, true}
    case .Uint32x3:  return {3, gl.UNSIGNED_INT, false, true}
    case .Uint32x4:  return {4, gl.UNSIGNED_INT, false, true}
    case .Sint32:    return {1, gl.INT, false, true}
    case .Sint32x2:  return {2, gl.INT, false, true}
    case .Sint32x3:  return {3, gl.INT, false, true}
    case .Sint32x4:  return {4, gl.INT, false, true}
    case:
        return {4, gl.FLOAT, false, false}
    }
}

gl_get_primitive_mode :: #force_inline proc "contextless" (topology: Primitive_Topology) -> u32 {
    #partial switch topology {
    case .Point_List:     return gl.POINTS
    case .Line_List:      return gl.LINES
    case .Line_Strip:     return gl.LINE_STRIP
    case .Triangle_List:  return gl.TRIANGLES
    case .Triangle_Strip: return gl.TRIANGLE_STRIP
    case:
        return gl.TRIANGLES
    }
}

gl_get_front_face :: #force_inline proc "contextless" (face: Front_Face) -> u32 {
    // Note that we invert winding direction in OpenGL. Because Y axis is up in
    // OpenGL, which is different from WebGPU and other backends (Y axis is down).
    return face == .Ccw ? gl.CCW : gl.CW
}

gl_get_cull_enabled :: #force_inline proc "contextless" (mode: Face) -> bool {
    return mode != .Undefined && mode != .None
}

gl_get_cull_face :: #force_inline proc "contextless" (mode: Face) -> u32 {
    #partial switch mode {
    case .Front: return gl.FRONT
    case .Back:  return gl.BACK
    }
    unreachable()
}

gl_depth_test_enabled :: #force_inline proc "contextless" (ds: ^Depth_Stencil_State) -> bool {
    return ds.depth_compare != .Always || ds.depth_write_enabled
}

gl_stencil_test_enabled :: #force_inline proc "contextless" (ds: ^Depth_Stencil_State) -> bool {
    return ds.stencil.front != {} || ds.stencil.back != {}
}

gl_get_compare_func :: #force_inline proc "contextless" (func: Compare_Function) -> u32 {
    #partial switch func {
    case .Never:         return gl.NEVER
    case .Less:          return gl.LESS
    case .Equal:         return gl.EQUAL
    case .Less_Equal:    return gl.LEQUAL
    case .Greater:       return gl.GREATER
    case .Not_Equal:     return gl.NOTEQUAL
    case .Greater_Equal: return gl.GEQUAL
    case .Always:        return gl.ALWAYS
    case:                return gl.ALWAYS
    }
}

gl_get_stencil_op :: #force_inline proc "contextless" (op: Stencil_Operation) -> u32 {
    #partial switch op {
    case .Keep:               return gl.KEEP
    case .Zero:               return gl.ZERO
    case .Replace:            return gl.REPLACE
    case .Invert:             return gl.INVERT
    case .Increment_Clamp:    return gl.INCR
    case .Decrement_Clamp:    return gl.DECR
    case .Increment_Wrap:     return gl.INCR_WRAP
    case .Decrement_Wrap:     return gl.DECR_WRAP
    case:                     return gl.KEEP
    }
}

gl_get_blend_factor :: #force_inline proc "contextless" (factor: Blend_Factor, is_color: bool) -> u32 {
    #partial switch factor {
    case .Zero:                      return gl.ZERO
    case .One:                       return gl.ONE
    case .Src:                       return is_color ? gl.SRC_COLOR : gl.SRC_ALPHA
    case .One_Minus_Src:             return is_color ? gl.ONE_MINUS_SRC_COLOR : gl.ONE_MINUS_SRC_ALPHA
    case .Src_Alpha:                 return gl.SRC_ALPHA
    case .One_Minus_Src_Alpha:       return gl.ONE_MINUS_SRC_ALPHA
    case .Dst:                       return is_color ? gl.DST_COLOR : gl.DST_ALPHA
    case .One_Minus_Dst:             return is_color ? gl.ONE_MINUS_DST_COLOR : gl.ONE_MINUS_DST_ALPHA
    case .Dst_Alpha:                 return gl.DST_ALPHA
    case .One_Minus_Dst_Alpha:       return gl.ONE_MINUS_DST_ALPHA
    case .Src_Alpha_Saturated:       return gl.SRC_ALPHA_SATURATE
    case .Constant:                  return is_color ? gl.CONSTANT_COLOR : gl.CONSTANT_ALPHA
    case .One_Minus_Constant:        return is_color ? gl.ONE_MINUS_CONSTANT_COLOR : gl.ONE_MINUS_CONSTANT_ALPHA
    case:                            return gl.ONE
    }
}

gl_get_blend_op :: #force_inline proc "contextless" (op: Blend_Operation) -> u32 {
    #partial switch op {
    case .Add:              return gl.FUNC_ADD
    case .Subtract:         return gl.FUNC_SUBTRACT
    case .Reverse_Subtract: return gl.FUNC_REVERSE_SUBTRACT
    case .Min:              return gl.MIN
    case .Max:              return gl.MAX
    case:                   return gl.FUNC_ADD
    }
}

GL_Format :: struct {
    internal_format: u32,
    format:          u32,
    type:            u32,
    component_type:  enum {
        Float, Int, Uint, DepthStencil,
    },
}

GL_Format_Table :: [Texture_Format]GL_Format

@(rodata)
GL_FORMAT_TABLE := [Texture_Format]GL_Format {
    // 8-bit formats
    .R8_Unorm = { gl.R8, gl.RED, gl.UNSIGNED_BYTE, .Float },
    .R8_Snorm = { gl.R8_SNORM, gl.RED, gl.BYTE, .Float },
    .R8_Uint  = { gl.R8UI, gl.RED_INTEGER, gl.UNSIGNED_BYTE, .Uint },
    .R8_Sint  = { gl.R8I, gl.RED_INTEGER, gl.BYTE, .Int },

    // 16-bit formats
    .R16_Uint  = { gl.R16UI, gl.RED_INTEGER, gl.UNSIGNED_SHORT, .Uint },
    .R16_Sint  = { gl.R16I, gl.RED_INTEGER, gl.SHORT, .Int },
    .R16_Unorm = { gl.R16, gl.RED, gl.UNSIGNED_SHORT, .Float },
    .R16_Snorm = { gl.R16_SNORM, gl.RED, gl.SHORT, .Float },
    .R16_Float = { gl.R16F, gl.RED, gl.HALF_FLOAT, .Float },
    .Rg8_Unorm = { gl.RG8, gl.RG, gl.UNSIGNED_BYTE, .Float },
    .Rg8_Snorm = { gl.RG8_SNORM, gl.RG, gl.BYTE, .Float },
    .Rg8_Uint  = { gl.RG8UI, gl.RG_INTEGER, gl.UNSIGNED_BYTE, .Uint },
    .Rg8_Sint  = { gl.RG8I, gl.RG_INTEGER, gl.BYTE, .Int },

    // 32-bit formats
    .R32_Uint         = { gl.R32UI, gl.RED_INTEGER, gl.UNSIGNED_INT, .Uint },
    .R32_Sint         = { gl.R32I, gl.RED_INTEGER, gl.INT, .Int },
    .R32_Float        = { gl.R32F, gl.RED, gl.FLOAT, .Float },
    .Rg16_Uint        = { gl.RG16UI, gl.RG_INTEGER, gl.UNSIGNED_SHORT, .Uint },
    .Rg16_Sint        = { gl.RG16I, gl.RG_INTEGER, gl.SHORT, .Int },
    .Rg16_Unorm       = { gl.RG16, gl.RG, gl.UNSIGNED_SHORT, .Float },
    .Rg16_Snorm       = { gl.RG16_SNORM, gl.RG, gl.SHORT, .Float },
    .Rg16_Float       = { gl.RG16F, gl.RG, gl.HALF_FLOAT, .Float },
    .Rgba8_Unorm      = { gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Rgba8_Unorm_Srgb = { gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Rgba8_Snorm      = { gl.RGBA8_SNORM, gl.RGBA, gl.BYTE, .Float },
    .Rgba8_Uint       = { gl.RGBA8UI, gl.RGBA_INTEGER, gl.UNSIGNED_BYTE, .Uint },
    .Rgba8_Sint       = { gl.RGBA8I, gl.RGBA_INTEGER, gl.BYTE, .Int },
    .Bgra8_Unorm      = { gl.RGBA8, gl.BGRA, gl.UNSIGNED_BYTE, .Float },
    .Bgra8_Unorm_Srgb = { gl.SRGB8_ALPHA8, gl.BGRA, gl.UNSIGNED_BYTE, .Float },

    // Packed 32-bit formats
    .Rgb9e5_Ufloat  = { gl.RGB9_E5, gl.RGB, gl.UNSIGNED_INT_5_9_9_9_REV, .Float },
    .Rgb10a2_Uint   = { gl.RGB10_A2UI, gl.RGBA_INTEGER, gl.UNSIGNED_INT_2_10_10_10_REV, .Uint },
    .Rgb10a2_Unorm  = { gl.RGB10_A2, gl.RGBA, gl.UNSIGNED_INT_2_10_10_10_REV, .Float },
    .Rg11b10_Ufloat = { gl.R11F_G11F_B10F, gl.RGB, gl.UNSIGNED_INT_10F_11F_11F_REV, .Float },

    // 64-bit formats
    .R64_Uint     = { gl.R32UI, gl.RED_INTEGER, gl.UNSIGNED_INT, .Uint },
    .Rg32_Uint    = { gl.RG32UI, gl.RG_INTEGER, gl.UNSIGNED_INT, .Uint },
    .Rg32_Sint    = { gl.RG32I, gl.RG_INTEGER, gl.INT, .Int },
    .Rg32_Float   = { gl.RG32F, gl.RG, gl.FLOAT, .Float },
    .Rgba16_Uint  = { gl.RGBA16UI, gl.RGBA_INTEGER, gl.UNSIGNED_SHORT, .Uint },
    .Rgba16_Sint  = { gl.RGBA16I, gl.RGBA_INTEGER, gl.SHORT, .Int },
    .Rgba16_Unorm = { gl.RGBA16, gl.RGBA, gl.UNSIGNED_SHORT, .Float },
    .Rgba16_Snorm = { gl.RGBA16_SNORM, gl.RGBA, gl.SHORT, .Float },
    .Rgba16_Float = { gl.RGBA16F, gl.RGBA, gl.HALF_FLOAT, .Float },

    // 128-bit formats
    .Rgba32_Uint  = { gl.RGBA32UI, gl.RGBA_INTEGER, gl.UNSIGNED_INT, .Uint },
    .Rgba32_Sint  = { gl.RGBA32I, gl.RGBA_INTEGER, gl.INT, .Int },
    .Rgba32_Float = { gl.RGBA32F, gl.RGBA, gl.FLOAT, .Float },

    // Depth and stencil formats
    .Stencil8               = { gl.STENCIL_INDEX8, gl.STENCIL_INDEX, gl.UNSIGNED_BYTE, .DepthStencil },
    .Depth16_Unorm          = { gl.DEPTH_COMPONENT16, gl.DEPTH_COMPONENT, gl.UNSIGNED_SHORT, .DepthStencil },
    .Depth24_Plus           = { gl.DEPTH_COMPONENT24, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, .DepthStencil },
    .Depth24_Plus_Stencil8  = { gl.DEPTH24_STENCIL8, gl.DEPTH_STENCIL, gl.UNSIGNED_INT_24_8, .DepthStencil },
    .Depth32_Float          = { gl.DEPTH_COMPONENT32F, gl.DEPTH_COMPONENT, gl.FLOAT, .DepthStencil },
    .Depth32_Float_Stencil8 = { gl.DEPTH32F_STENCIL8, gl.DEPTH_STENCIL, gl.FLOAT_32_UNSIGNED_INT_24_8_REV, .DepthStencil },

    // BC compressed formats (requires GL_ARB_texture_compression_bptc / GL_EXT_texture_compression_s3tc)
    .Bc1_Rgba_Unorm      = { GL_COMPRESSED_RGBA_S3TC_DXT1_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc1_Rgba_Unorm_Srgb = { GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc2_Rgba_Unorm      = { GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc2_Rgba_Unorm_Srgb = { GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc3_Rgba_Unorm      = { GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc3_Rgba_Unorm_Srgb = { GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc4_R_Unorm         = { gl.COMPRESSED_RED_RGTC1, gl.RED, gl.UNSIGNED_BYTE, .Float },
    .Bc4_R_Snorm         = { gl.COMPRESSED_SIGNED_RED_RGTC1, gl.RED, gl.BYTE, .Float },
    .Bc5_Rg_Unorm        = { gl.COMPRESSED_RG_RGTC2, gl.RG, gl.UNSIGNED_BYTE, .Float },
    .Bc5_Rg_Snorm        = { gl.COMPRESSED_SIGNED_RG_RGTC2, gl.RG, gl.BYTE, .Float },
    .Bc6_hRgb_Ufloat     = { gl.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT, gl.RGB, gl.FLOAT, .Float },
    .Bc6_hRgb_Float      = { gl.COMPRESSED_RGB_BPTC_SIGNED_FLOAT, gl.RGB, gl.FLOAT, .Float },
    .Bc7_Rgba_Unorm      = { gl.COMPRESSED_RGBA_BPTC_UNORM, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Bc7_Rgba_Unorm_Srgb = { gl.COMPRESSED_SRGB_ALPHA_BPTC_UNORM, gl.RGBA, gl.UNSIGNED_BYTE, .Float },

    // ETC2 compressed formats (OpenGL 4.3+ / ES 3.0+)
    .Etc2_Rgb8_Unorm        = { gl.COMPRESSED_RGB8_ETC2, gl.RGB, gl.UNSIGNED_BYTE, .Float },
    .Etc2_Rgb8_Unorm_Srgb   = { gl.COMPRESSED_SRGB8_ETC2, gl.RGB, gl.UNSIGNED_BYTE, .Float },
    .Etc2_Rgb8A1_Unorm      = { gl.COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Etc2_Rgb8A1_Unorm_Srgb = { gl.COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Etc2_Rgba8_Unorm       = { gl.COMPRESSED_RGBA8_ETC2_EAC, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Etc2_Rgba8_Unorm_Srgb  = { gl.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Eac_R11_Unorm          = { gl.COMPRESSED_R11_EAC, gl.RED, gl.UNSIGNED_BYTE, .Float },
    .Eac_R11_Snorm          = { gl.COMPRESSED_SIGNED_R11_EAC, gl.RED, gl.BYTE, .Float },
    .Eac_Rg11_Unorm         = { gl.COMPRESSED_RG11_EAC, gl.RG, gl.UNSIGNED_BYTE, .Float },
    .Eac_Rg11_Snorm         = { gl.COMPRESSED_SIGNED_RG11_EAC, gl.RG, gl.BYTE, .Float },

    // ASTC compressed formats (requires GL_KHR_texture_compression_astc_ldr/hdr)
    .Astc_4x4_Unorm        = { GL_COMPRESSED_RGBA_ASTC_4x4_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_4x4_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_5x4_Unorm        = { GL_COMPRESSED_RGBA_ASTC_5x4_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_5x4_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_5x5_Unorm        = { GL_COMPRESSED_RGBA_ASTC_5x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_5x5_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_6x5_Unorm        = { GL_COMPRESSED_RGBA_ASTC_6x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_6x5_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_6x6_Unorm        = { GL_COMPRESSED_RGBA_ASTC_6x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_6x6_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x5_Unorm        = { GL_COMPRESSED_RGBA_ASTC_8x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x5_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x6_Unorm        = { GL_COMPRESSED_RGBA_ASTC_8x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x6_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x8_Unorm        = { GL_COMPRESSED_RGBA_ASTC_8x8_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_8x8_Unorm_Srgb   = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x5_Unorm       = { GL_COMPRESSED_RGBA_ASTC_10x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x5_Unorm_Srgb  = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x6_Unorm       = { GL_COMPRESSED_RGBA_ASTC_10x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x6_Unorm_Srgb  = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x8_Unorm       = { GL_COMPRESSED_RGBA_ASTC_10x8_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x8_Unorm_Srgb  = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x10_Unorm      = { GL_COMPRESSED_RGBA_ASTC_10x10_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_10x10_Unorm_Srgb = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_12x10_Unorm      = { GL_COMPRESSED_RGBA_ASTC_12x10_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_12x10_Unorm_Srgb = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_12x12_Unorm      = { GL_COMPRESSED_RGBA_ASTC_12x12_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },
    .Astc_12x12_Unorm_Srgb = { GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR, gl.RGBA, gl.UNSIGNED_BYTE, .Float },

    // HDR ASTC formats (not supported in OpenGL)
    .Astc_4x4_Unorm_Hdr   = {},
    .Astc_5x4_Unorm_Hdr   = {},
    .Astc_5x5_Unorm_Hdr   = {},
    .Astc_6x5_Unorm_Hdr   = {},
    .Astc_6x6_Unorm_Hdr   = {},
    .Astc_8x5_Unorm_Hdr   = {},
    .Astc_8x6_Unorm_Hdr   = {},
    .Astc_8x8_Unorm_Hdr   = {},
    .Astc_10x5_Unorm_Hdr  = {},
    .Astc_10x6_Unorm_Hdr  = {},
    .Astc_10x8_Unorm_Hdr  = {},
    .Astc_10x10_Unorm_Hdr = {},
    .Astc_12x10_Unorm_Hdr = {},
    .Astc_12x12_Unorm_Hdr = {},

    // YUV formats (not supported in standard OpenGL)
    .NV12 = {},
    .P010 = {},

    // Undefined format
    .Undefined = {},
}

// gl_get_internal_format :: proc(format: Texture_Format) -> u32 {
//     switch format {
//     // 8-bit formats
//     case .R8_Unorm:               return gl.R8
//     case .R8_Snorm:               return gl.R8_SNORM
//     case .R8_Uint:                return gl.R8UI
//     case .R8_Sint:                return gl.R8I

//     // 16-bit formats
//     case .R16_Uint:               return gl.R16UI
//     case .R16_Sint:               return gl.R16I
//     case .R16_Unorm:              return gl.R16
//     case .R16_Snorm:              return gl.R16_SNORM
//     case .R16_Float:              return gl.R16F
//     case .Rg8_Unorm:              return gl.RG8
//     case .Rg8_Snorm:              return gl.RG8_SNORM
//     case .Rg8_Uint:               return gl.RG8UI
//     case .Rg8_Sint:               return gl.RG8I

//     // 32-bit formats
//     case .R32_Uint:               return gl.R32UI
//     case .R32_Sint:               return gl.R32I
//     case .R32_Float:              return gl.R32F
//     case .Rg16_Uint:              return gl.RG16UI
//     case .Rg16_Sint:              return gl.RG16I
//     case .Rg16_Unorm:             return gl.RG16
//     case .Rg16_Snorm:             return gl.RG16_SNORM
//     case .Rg16_Float:             return gl.RG16F
//     case .Rgba8_Unorm:            return gl.RGBA8
//     case .Rgba8_Unorm_Srgb:       return gl.SRGB8_ALPHA8
//     case .Rgba8_Snorm:            return gl.RGBA8_SNORM
//     case .Rgba8_Uint:             return gl.RGBA8UI
//     case .Rgba8_Sint:             return gl.RGBA8I
//     case .Bgra8_Unorm:            return gl.RGBA8  // OpenGL doesn't have BGRA internal format
//     case .Bgra8_Unorm_Srgb:       return gl.SRGB8_ALPHA8 // Same for SRGB

//     // Packed 32-bit formats
//     case .Rgb9e5_Ufloat:          return gl.RGB9_E5
//     case .Rgb10a2_Uint:           return gl.RGB10_A2UI
//     case .Rgb10a2_Unorm:          return gl.RGB10_A2
//     case .Rg11b10_Ufloat:         return gl.R11F_G11F_B10F

//     // 64-bit formats
//     case .R64_Uint:               return gl.R32UI  // OpenGL doesn't have R64UI, closest is R32UI
//     case .Rg32_Uint:              return gl.RG32UI
//     case .Rg32_Sint:              return gl.RG32I
//     case .Rg32_Float:             return gl.RG32F
//     case .Rgba16_Uint:            return gl.RGBA16UI
//     case .Rgba16_Sint:            return gl.RGBA16I
//     case .Rgba16_Unorm:           return gl.RGBA16
//     case .Rgba16_Snorm:           return gl.RGBA16_SNORM
//     case .Rgba16_Float:           return gl.RGBA16F

//     // 128-bit formats
//     case .Rgba32_Uint:            return gl.RGBA32UI
//     case .Rgba32_Sint:            return gl.RGBA32I
//     case .Rgba32_Float:           return gl.RGBA32F

//     // Depth and stencil formats
//     case .Stencil8:               return gl.STENCIL_INDEX8
//     case .Depth16_Unorm:          return gl.DEPTH_COMPONENT16
//     case .Depth24_Plus:           return gl.DEPTH_COMPONENT24
//     case .Depth24_Plus_Stencil8:  return gl.DEPTH24_STENCIL8
//     case .Depth32_Float:          return gl.DEPTH_COMPONENT32F
//     case .Depth32_Float_Stencil8: return gl.DEPTH32F_STENCIL8

//     // BC compressed formats (requires GL_ARB_texture_compression_bptc / GL_EXT_texture_compression_s3tc)
//     case .Bc1_Rgba_Unorm:         return GL_COMPRESSED_RGBA_S3TC_DXT1_EXT
//     case .Bc1_Rgba_Unorm_Srgb:    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT
//     case .Bc2_Rgba_Unorm:         return GL_COMPRESSED_RGBA_S3TC_DXT3_EXT
//     case .Bc2_Rgba_Unorm_Srgb:    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT
//     case .Bc3_Rgba_Unorm:         return GL_COMPRESSED_RGBA_S3TC_DXT5_EXT
//     case .Bc3_Rgba_Unorm_Srgb:    return GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT
//     case .Bc4_R_Unorm:            return gl.COMPRESSED_RED_RGTC1
//     case .Bc4_R_Snorm:            return gl.COMPRESSED_SIGNED_RED_RGTC1
//     case .Bc5_Rg_Unorm:           return gl.COMPRESSED_RG_RGTC2
//     case .Bc5_Rg_Snorm:           return gl.COMPRESSED_SIGNED_RG_RGTC2
//     case .Bc6_hRgb_Ufloat:        return gl.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT
//     case .Bc6_hRgb_Float:         return gl.COMPRESSED_RGB_BPTC_SIGNED_FLOAT
//     case .Bc7_Rgba_Unorm:         return gl.COMPRESSED_RGBA_BPTC_UNORM
//     case .Bc7_Rgba_Unorm_Srgb:    return gl.COMPRESSED_SRGB_ALPHA_BPTC_UNORM

//     // ETC2 compressed formats (OpenGL 4.3+ / ES 3.0+)
//     case .Etc2_Rgb8_Unorm:        return gl.COMPRESSED_RGB8_ETC2
//     case .Etc2_Rgb8_Unorm_Srgb:   return gl.COMPRESSED_SRGB8_ETC2
//     case .Etc2_Rgb8A1_Unorm:      return gl.COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2
//     case .Etc2_Rgb8A1_Unorm_Srgb: return gl.COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2
//     case .Etc2_Rgba8_Unorm:       return gl.COMPRESSED_RGBA8_ETC2_EAC
//     case .Etc2_Rgba8_Unorm_Srgb:  return gl.COMPRESSED_SRGB8_ALPHA8_ETC2_EAC
//     case .Eac_R11_Unorm:          return gl.COMPRESSED_R11_EAC
//     case .Eac_R11_Snorm:          return gl.COMPRESSED_SIGNED_R11_EAC
//     case .Eac_Rg11_Unorm:         return gl.COMPRESSED_RG11_EAC
//     case .Eac_Rg11_Snorm:         return gl.COMPRESSED_SIGNED_RG11_EAC

//     // ASTC compressed formats (requires GL_KHR_texture_compression_astc_ldr/hdr)
//     case .Astc_4x4_Unorm:         return GL_COMPRESSED_RGBA_ASTC_4x4_KHR
//     case .Astc_4x4_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR
//     case .Astc_5x4_Unorm:         return GL_COMPRESSED_RGBA_ASTC_5x4_KHR
//     case .Astc_5x4_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR
//     case .Astc_5x5_Unorm:         return GL_COMPRESSED_RGBA_ASTC_5x5_KHR
//     case .Astc_5x5_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR
//     case .Astc_6x5_Unorm:         return GL_COMPRESSED_RGBA_ASTC_6x5_KHR
//     case .Astc_6x5_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR
//     case .Astc_6x6_Unorm:         return GL_COMPRESSED_RGBA_ASTC_6x6_KHR
//     case .Astc_6x6_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR
//     case .Astc_8x5_Unorm:         return GL_COMPRESSED_RGBA_ASTC_8x5_KHR
//     case .Astc_8x5_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR
//     case .Astc_8x6_Unorm:         return GL_COMPRESSED_RGBA_ASTC_8x6_KHR
//     case .Astc_8x6_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR
//     case .Astc_8x8_Unorm:         return GL_COMPRESSED_RGBA_ASTC_8x8_KHR
//     case .Astc_8x8_Unorm_Srgb:    return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR
//     case .Astc_10x5_Unorm:        return GL_COMPRESSED_RGBA_ASTC_10x5_KHR
//     case .Astc_10x5_Unorm_Srgb:   return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR
//     case .Astc_10x6_Unorm:        return GL_COMPRESSED_RGBA_ASTC_10x6_KHR
//     case .Astc_10x6_Unorm_Srgb:   return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR
//     case .Astc_10x8_Unorm:        return GL_COMPRESSED_RGBA_ASTC_10x8_KHR
//     case .Astc_10x8_Unorm_Srgb:   return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR
//     case .Astc_10x10_Unorm:       return GL_COMPRESSED_RGBA_ASTC_10x10_KHR
//     case .Astc_10x10_Unorm_Srgb:  return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR
//     case .Astc_12x10_Unorm:       return GL_COMPRESSED_RGBA_ASTC_12x10_KHR
//     case .Astc_12x10_Unorm_Srgb:  return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR
//     case .Astc_12x12_Unorm:       return GL_COMPRESSED_RGBA_ASTC_12x12_KHR
//     case .Astc_12x12_Unorm_Srgb:  return GL_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR

//     // HDR ASTC formats
//     case .Astc_4x4_Unorm_Hdr,
//          .Astc_5x4_Unorm_Hdr,
//          .Astc_5x5_Unorm_Hdr,
//          .Astc_6x5_Unorm_Hdr,
//          .Astc_6x6_Unorm_Hdr,
//          .Astc_8x5_Unorm_Hdr,
//          .Astc_8x6_Unorm_Hdr,
//          .Astc_8x8_Unorm_Hdr,
//          .Astc_10x5_Unorm_Hdr,
//          .Astc_10x6_Unorm_Hdr,
//          .Astc_10x8_Unorm_Hdr,
//          .Astc_10x10_Unorm_Hdr,
//          .Astc_12x10_Unorm_Hdr,
//          .Astc_12x12_Unorm_Hdr:
//         panic("ASTC HDR formats are not supported in OpenGL")

//     // YUV formats (not standard in OpenGL, would need extensions)
//     case .NV12, .P010:
//         panic("YUV formats (NV12, P010) are not supported in standard OpenGL")

//     case .Undefined:
//         panic("Undefined texture format")
//     }

//     unreachable()
// }

// Query if format supports color rendering.
gl_is_format_renderable :: #force_inline proc "contextless" (internal_format: u32) -> bool {
    color_renderable: i32
    gl.GetInternalformativ(
        gl.TEXTURE_2D,
        internal_format,
        gl.COLOR_RENDERABLE,
        1,
        &color_renderable,
    )
    return bool(color_renderable)
}

gl_get_buffer_storage_flags :: #force_inline proc "contextless" (
    usage: Buffer_Usages,
    mapped_at_creation: bool,
) -> u32 {
    flags: u32 = 0

    // Map access flags
    if .Map_Read in usage {
        flags |= gl.MAP_READ_BIT
    }
    if .Map_Write in usage || mapped_at_creation {
        flags |= gl.MAP_WRITE_BIT
    }

    // Dynamic storage flag (allows updates via glBufferSubData)
    if .Copy_Dst in usage || .Map_Write in usage {
        flags |= gl.DYNAMIC_STORAGE_BIT
    }

    // Persistent mapping for high-performance scenarios
    // Only use persistent mapping if both map read and write are needed
    if .Map_Read in usage && .Map_Write in usage {
        flags |= gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT
    }

    // Client storage hint (keep data in client memory if appropriate)
    // Use for staging/map buffers
    if (.Map_Read in usage || .Map_Write in usage) &&
       !(.Uniform in usage || .Storage in usage || .Vertex in usage || .Index in usage) {
        flags |= gl.CLIENT_STORAGE_BIT
    }

    return flags
}

gl_texture_view_dimension_to_target :: #force_inline proc "contextless" (dimension: Texture_View_Dimension) -> u32 {
    switch dimension {
    case .D1:         return gl.TEXTURE_1D
    case .D2:         return gl.TEXTURE_2D
    case .D2_Array:   return gl.TEXTURE_2D_ARRAY
    case .Cube:       return gl.TEXTURE_CUBE_MAP
    case .Cube_Array: return gl.TEXTURE_CUBE_MAP_ARRAY
    case .D3:         return gl.TEXTURE_3D
    case .Undefined:
        unreachable()
    }
    return gl.TEXTURE_2D
}

gl_texture_dimension_to_target :: #force_inline proc "contextless" (
    dimension: Texture_Dimension,
    sample_count: u32,
    layers: u32,
) -> u32 {
    #partial switch dimension {
    case .D1:
        return layers > 1 ? gl.TEXTURE_1D_ARRAY : gl.TEXTURE_1D

    case .D2:
        if sample_count > 1 {
            return layers > 1 ? gl.TEXTURE_2D_MULTISAMPLE_ARRAY : gl.TEXTURE_2D_MULTISAMPLE
        }
        return layers > 1 ? gl.TEXTURE_2D_ARRAY : gl.TEXTURE_2D

    case .D3:
        return gl.TEXTURE_3D

    case:
        unreachable()
    }
}

gl_get_min_filter :: #force_inline proc "contextless" (min: Filter_Mode, mipmap: Mipmap_Filter_Mode) -> i32 {
    #partial switch min {
    case .Nearest:
        #partial switch mipmap {
        case .Nearest: return gl.NEAREST_MIPMAP_NEAREST
        case .Linear:  return gl.NEAREST_MIPMAP_LINEAR
        }
    case .Linear:
        #partial switch mipmap {
        case .Nearest: return gl.LINEAR_MIPMAP_NEAREST
        case .Linear:  return gl.LINEAR_MIPMAP_LINEAR
        }
    }
    return gl.NEAREST
}

gl_get_mag_filter :: #force_inline proc "contextless" (mag: Filter_Mode) -> i32 {
    #partial switch mag {
    case .Nearest: return gl.NEAREST
    case .Linear:  return gl.LINEAR
    }
    return gl.NEAREST
}

gl_get_address_mode :: #force_inline proc "contextless" (mode: Address_Mode) -> i32 {
    #partial switch mode {
    case .Clamp_To_Edge:   return gl.CLAMP_TO_EDGE
    case .Repeat:          return gl.REPEAT
    case .Mirror_Repeat:   return gl.MIRRORED_REPEAT
    case .Clamp_To_Border: return gl.CLAMP_TO_BORDER
    }
    return gl.CLAMP_TO_EDGE
}

gl_get_compare_function :: #force_inline proc "contextless" (func: Compare_Function) -> i32 {
    switch func {
    case .Never:          return gl.NEVER
    case .Less:           return gl.LESS
    case .Equal:          return gl.EQUAL
    case .Less_Equal:     return gl.LEQUAL
    case .Greater:        return gl.GREATER
    case .Not_Equal:      return gl.NOTEQUAL
    case .Greater_Equal:  return gl.GEQUAL
    case .Always:         return gl.ALWAYS
    case .Undefined:      return gl.NEVER
    }
    return gl.NEVER
}

gl_get_border_color :: #force_inline proc "contextless" (color: Sampler_Border_Color) -> [4]f32 {
    #partial switch color {
    case .Transparent_Black: return {0, 0, 0, 0}
    case .Opaque_Black:      return {0, 0, 0, 1}
    case .Opaque_White:      return {1, 1, 1, 1}
    case .Undefined:         return {0, 0, 0, 0}
    }
    return {0, 0, 0, 0} // Zero
}
