#+build !js
package gpu

// Core
import "base:runtime"

// Vendor
import vk "vendor:vulkan"

vk_conv_to_polygon_mode :: #force_inline proc "contextless" (mode: Polygon_Mode) -> vk.PolygonMode {
    switch mode {
    case .Fill:  return .FILL
    case .Line:  return .LINE
    case .Point: return .POINT
    case:
        return .FILL
    }
}

vk_conv_to_cull_mode_flags :: #force_inline proc "contextless" (mode: Face) -> vk.CullModeFlags {
    #partial switch mode {
    case .None:  return {}
    case .Front: return { .FRONT }
    case .Back:  return { .BACK }
    case:
        return { .BACK }
    }
}

vk_conv_to_primitive_topology :: proc(topology: Primitive_Topology) -> vk.PrimitiveTopology {
    #partial switch topology {
    case .Point_List:     return .POINT_LIST
    case .Line_List:      return .LINE_LIST
    case .Line_Strip:     return .LINE_STRIP
    case .Triangle_List:  return .TRIANGLE_LIST
    case .Triangle_Strip: return .TRIANGLE_STRIP
    case:
        return .TRIANGLE_LIST
    }
}

vk_conv_to_compare_op :: #force_inline proc "contextless" (func: Compare_Function) -> vk.CompareOp {
    #partial switch func {
    case .Never:         return .NEVER
    case .Less:          return .LESS
    case .Equal:         return .EQUAL
    case .Less_Equal:    return .LESS_OR_EQUAL
    case .Greater:       return .GREATER
    case .Not_Equal:     return .NOT_EQUAL
    case .Greater_Equal: return .GREATER_OR_EQUAL
    case .Always:        return .ALWAYS
    case: return .LESS
    }
}

vk_conv_to_stencil_op :: #force_inline proc "contextless" (op: Stencil_Operation) -> vk.StencilOp {
    switch op {
    case .Undefined:       return .KEEP
    case .Keep:            return .KEEP
    case .Zero:            return .ZERO
    case .Replace:         return .REPLACE
    case .Invert:          return .INVERT
    case .Increment_Clamp: return .INCREMENT_AND_CLAMP
    case .Decrement_Clamp: return .DECREMENT_AND_CLAMP
    case .Increment_Wrap:  return .INCREMENT_AND_WRAP
    case .Decrement_Wrap:  return .DECREMENT_AND_WRAP
    case:
        return .KEEP
    }
}

vk_conv_to_stencil_front_op_state :: #force_inline proc "contextless" (
    state: Stencil_State,
) -> vk.StencilOpState {
    return {
        failOp      = vk_conv_to_stencil_op(state.front.fail_op),
        passOp      = vk_conv_to_stencil_op(state.front.pass_op),
        depthFailOp = vk_conv_to_stencil_op(state.front.depth_fail_op),
        compareOp   = vk_conv_to_compare_op(state.front.compare),
        compareMask = state.read_mask,
        writeMask   = state.write_mask,
        reference   = 0, // Set dynamically
    }
}

vk_conv_to_stencil_back_op_state :: #force_inline proc "contextless" (
    state: Stencil_State,
) -> vk.StencilOpState {
    return {
        failOp      = vk_conv_to_stencil_op(state.back.fail_op),
        passOp      = vk_conv_to_stencil_op(state.back.pass_op),
        depthFailOp = vk_conv_to_stencil_op(state.back.depth_fail_op),
        compareOp   = vk_conv_to_compare_op(state.back.compare),
        compareMask = state.read_mask,
        writeMask   = state.write_mask,
        reference   = 0, // Set dynamically
    }
}

vk_conv_to_color_component_flags :: #force_inline proc "contextless" (
    writes: Color_Writes,
) -> (
    flags: vk.ColorComponentFlags,
) {
    if .Red in writes {flags += {.R}}
    if .Green in writes {flags += {.G}}
    if .Blue in writes {flags += {.B}}
    if .Alpha in writes {flags += {.A}}
    return
}

vk_conv_to_blend_factor :: #force_inline proc "contextless" (
    blend_factor: Blend_Factor,
) -> vk.BlendFactor {
    switch blend_factor {
    case .Undefined:            return .ZERO
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
    case:
        return .ZERO
    }
}

vk_conv_to_blend_op :: #force_inline proc "contextless" (blend_op: Blend_Operation) -> vk.BlendOp {
    switch blend_op {
    case .Undefined:        return .ADD
    case .Add:              return .ADD
    case .Subtract:         return .SUBTRACT
    case .Reverse_Subtract: return .REVERSE_SUBTRACT
    case .Min:              return .MIN
    case .Max:              return .MAX
    case:
        return .ADD
    }
}

vk_conv_to_vertex_step_mode :: #force_inline proc "contextless" (
    mode: Vertex_Step_Mode,
) -> vk.VertexInputRate {
    #partial switch mode {
    case .Vertex:   return .VERTEX
    case .Instance: return .INSTANCE
    case: return .VERTEX
    }
}

vk_conv_to_vertex_format :: #force_inline proc "contextless" (
    format: Vertex_Format,
) -> vk.Format {
    switch format {
    case .Uint8:           return .R8_UINT
    case .Uint8x2:         return .R8G8_UINT
    case .Uint8x4:         return .R8G8B8A8_UINT
    case .Sint8:           return .R8_SINT
    case .Sint8x2:         return .R8G8_SINT
    case .Sint8x4:         return .R8G8B8A8_SINT
    case .Unorm8:          return .R8_UNORM
    case .Unorm8x2:        return .R8G8_UNORM
    case .Unorm8x4:        return .R8G8B8A8_UNORM
    case .Unorm8x4Bgra:    return .B8G8R8A8_UNORM
    case .Snorm8:          return .R8_SNORM
    case .Snorm8x2:        return .R8G8_SNORM
    case .Snorm8x4:        return .R8G8B8A8_SNORM
    case .Uint16:          return .R16_UINT
    case .Uint16x2:        return .R16G16_UINT
    case .Uint16x4:        return .R16G16B16A16_UINT
    case .Sint16:          return .R16_SINT
    case .Sint16x2:        return .R16G16_SINT
    case .Sint16x4:        return .R16G16B16A16_SINT
    case .Unorm16:         return .R16_UNORM
    case .Unorm16x2:       return .R16G16_UNORM
    case .Unorm16x4:       return .R16G16B16A16_UNORM
    case .Snorm16:         return .R16_SNORM
    case .Snorm16x2:       return .R16G16_SNORM
    case .Snorm16x4:       return .R16G16B16A16_SNORM
    case .Float16:         return .R16_SFLOAT
    case .Float16x2:       return .R16G16_SFLOAT
    case .Float16x4:       return .R16G16B16A16_SFLOAT
    case .Float32:         return .R32_SFLOAT
    case .Float32x2:       return .R32G32_SFLOAT
    case .Float32x3:       return .R32G32B32_SFLOAT
    case .Float32x4:       return .R32G32B32A32_SFLOAT
    case .Uint32:          return .R32_UINT
    case .Uint32x2:        return .R32G32_UINT
    case .Uint32x3:        return .R32G32B32_UINT
    case .Uint32x4:        return .R32G32B32A32_UINT
    case .Sint32:          return .R32_SINT
    case .Sint32x2:        return .R32G32_SINT
    case .Sint32x3:        return .R32G32B32_SINT
    case .Sint32x4:        return .R32G32B32A32_SINT
    case .Float64:         return .R64_SFLOAT
    case .Float64x2:       return .R64G64_SFLOAT
    case .Float64x3:       return .R64G64B64_SFLOAT
    case .Float64x4:       return .R64G64B64A64_SFLOAT
    case .Unorm10_10_10_2: return .A2R10G10B10_UNORM_PACK32
    case:
        return .UNDEFINED
    }
}

vk_conv_to_front_face :: #force_inline proc "contextless" (face: Front_Face) -> vk.FrontFace {
    #partial switch face {
    case .Ccw: return .COUNTER_CLOCKWISE
    case .Cw:  return .CLOCKWISE
    case:
        return .COUNTER_CLOCKWISE
    }
}

vk_conv_to_attachment_store_op :: #force_inline proc "contextless" (
    op: Store_Op,
) -> vk.AttachmentStoreOp {
    #partial switch op {
    case .Store:   return .STORE
    case .Discard: return .DONT_CARE
    case:
        return .NONE
    }
}

vk_conv_to_attachment_load_op :: #force_inline proc "contextless" (
    op: Load_Op,
) -> vk.AttachmentLoadOp {
    #partial switch op {
    case .Load:  return .LOAD
    case .Clear: return .CLEAR
    case:
        return .NONE
    }
}

vk_conv_to_sample_count_flags :: #force_inline proc "contextless" (
    samples: u32,
    loc := #caller_location,
) -> vk.SampleCountFlags {
    switch samples {
    case 1:  return { ._1 }
    case 2:  return { ._2 }
    case 4:  return { ._4 }
    case 8:  return { ._8 }
    case 16: return { ._16 }
    case 32: return { ._32 }
    case 64: return { ._64 }
    case:
        panic_contextless("Invalid sample count", loc)
    }
}

vk_texture_view_dimension_to_vk_image_view_type :: #force_inline proc "contextless" (
    dimension: Texture_View_Dimension,
) -> vk.ImageViewType {
    #partial switch dimension {
    case .D1:         return .D1
    case .D2:         return .D2
    case .D2_Array:   return .D2_ARRAY
    case .Cube:       return .CUBE
    case .Cube_Array: return .CUBE_ARRAY
    case .D3:         return .D3
    }
    unreachable()
}

vk_image_usage_to_texture_usages :: #force_inline proc "contextless" (
    flags: vk.ImageUsageFlags,
) -> (usages: Texture_Usages) {
    if .TRANSFER_SRC in flags do usages += {.Copy_Src}
    if .TRANSFER_DST in flags do usages += {.Copy_Dst}
    if .SAMPLED in flags do usages += {.Texture_Binding}
    if .STORAGE in flags do usages += {.Storage_Binding}
    if .COLOR_ATTACHMENT in flags do usages += {.Render_Attachment}
    return
}

vk_texture_usage_to_vk :: #force_inline proc "contextless" (
    usages: Texture_Usages,
) -> (flags: vk.ImageUsageFlags) {
    if .Copy_Src in usages do flags += {.TRANSFER_SRC}
    if .Copy_Dst in usages do flags += {.TRANSFER_DST}
    if .Texture_Binding in usages do flags += {.SAMPLED}
    if .Storage_Binding in usages do flags += {.STORAGE}
    if .Render_Attachment in usages do flags += {.COLOR_ATTACHMENT}
    return
}

vk_composite_alpha_flags_to_slice :: #force_inline proc(
    flags: vk.CompositeAlphaFlagsKHR,
    allocator: runtime.Allocator,
) -> (
    modes: []Composite_Alpha_Mode,
) {
    alpha_modes := make([dynamic]Composite_Alpha_Mode, allocator)
    if .OPAQUE in flags {
        append(&alpha_modes, Composite_Alpha_Mode.Opaque)
    }
    if .PRE_MULTIPLIED in flags {
        append(&alpha_modes, Composite_Alpha_Mode.Pre_Multiplied)
    }
    if .POST_MULTIPLIED in flags {
        append(&alpha_modes, Composite_Alpha_Mode.Post_Multiplied)
    }
    if .INHERIT in flags {
        append(&alpha_modes, Composite_Alpha_Mode.Inherit)
    }
    return alpha_modes[:]
}

vk_composite_alpha_mode_to_vk_flags :: #force_inline proc "contextless" (
    self: Composite_Alpha_Mode,
) -> (
    flags: vk.CompositeAlphaFlagsKHR,
) {
    #partial switch self {
    case .Auto, .Opaque:   return {.OPAQUE}
    case .Pre_Multiplied:   return {.PRE_MULTIPLIED}
    case .Post_Multiplied: return {.POST_MULTIPLIED}
    case .Inherit:         return {.INHERIT}
    }
    return
}

vk_conv_from_present_mode :: #force_inline proc "contextless" (
    vk_present_mode: vk.PresentModeKHR,
) -> Present_Mode {
    #partial switch vk_present_mode {
    case .FIFO:         return .Fifo
    case .FIFO_RELAXED: return .Fifo_Relaxed
    case .IMMEDIATE:    return .Immediate
    case .MAILBOX:      return .Mailbox
    case:
        return .Fifo
    }
}

vk_conv_to_present_mode :: #force_inline proc "contextless" (
    present_mode: Present_Mode,
) -> vk.PresentModeKHR {
    #partial switch present_mode {
    case .Fifo:         return .FIFO
    case .Fifo_Relaxed: return .FIFO_RELAXED
    case .Immediate:    return .IMMEDIATE
    case .Mailbox:      return .MAILBOX
    case:
        return .FIFO
    }
}

Vulkan_Stage_Acess :: struct {
    stage:  vk.PipelineStageFlags2,
    access: vk.AccessFlags2,
}

vk_get_pipeline_stage_access :: #force_inline proc "contextless" (
    layout: vk.ImageLayout,
    loc := #caller_location,
) -> Vulkan_Stage_Acess {
    #partial switch layout {
    case .UNDEFINED:
        return {
            stage = { .TOP_OF_PIPE },
            access = {}, // none
        }
    case .COLOR_ATTACHMENT_OPTIMAL:
        return {
            stage = { .COLOR_ATTACHMENT_OUTPUT },
            access = { .COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE },
        }
    case .DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage = { .LATE_FRAGMENT_TESTS, .EARLY_FRAGMENT_TESTS },
            access = { .DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE },
        }
    case .SHADER_READ_ONLY_OPTIMAL:
        return {
            stage = { .FRAGMENT_SHADER, .COMPUTE_SHADER, .PRE_RASTERIZATION_SHADERS },
            access = { .SHADER_READ },
        }
    case .TRANSFER_SRC_OPTIMAL:
        return {
            stage = { .TRANSFER },
            access = { .TRANSFER_READ },
        }
    case .TRANSFER_DST_OPTIMAL:
        return {
            stage = { .TRANSFER },
            access = { .TRANSFER_WRITE },
        }
    case .GENERAL:
        return {
            stage = { .COMPUTE_SHADER, .TRANSFER },
            access = { .MEMORY_READ, .MEMORY_WRITE, .TRANSFER_WRITE },
        }
    case .PRESENT_SRC_KHR:
        return {
            stage = { .COLOR_ATTACHMENT_OUTPUT, .COMPUTE_SHADER },
            access = { .SHADER_WRITE },
        }
    case:
        panic_contextless("Unsupported image layout transition!", loc)
    }
}

vk_conv_to_buffer_usage_flags :: #force_inline proc "contextless" (usage: Buffer_Usages) -> vk.BufferUsageFlags {
    ret: vk.BufferUsageFlags

    if .Map_Read in usage {
        ret += { .TRANSFER_DST }
    }
    if .Map_Write in usage {
        ret += { .TRANSFER_SRC }
    }
    if .Copy_Src in usage {
        ret += { .TRANSFER_SRC }
    }
    if .Copy_Dst in usage {
        ret += { .TRANSFER_DST }
    }
    if .Index in usage {
        ret += { .INDEX_BUFFER }
    }
    if .Vertex in usage {
        ret += { .VERTEX_BUFFER }
    }
    if .Uniform in usage {
        ret += { .UNIFORM_BUFFER }
    }
    if .Storage in usage {
        ret += { .STORAGE_BUFFER }
    }
    if .Indirect in usage {
        ret += { .INDIRECT_BUFFER }
    }
    if .Query_Resolve in usage {
        ret += { .TRANSFER_DST }
    }
    if .Blas_Input in usage {
        ret += { .ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_KHR, .SHADER_DEVICE_ADDRESS }
    }
    if .Tlas_Input in usage {
        ret += { .ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_KHR, .SHADER_DEVICE_ADDRESS }
    }

    return ret
}

vk_conv_to_descriptor_type :: #force_inline proc "contextless" (
    entry: Bind_Group_Layout_Entry,
    loc := #caller_location,
) -> vk.DescriptorType {
    switch &type in entry.type {
    case Buffer_Binding_Layout:
        #partial switch type.type {
        case .Uniform: return .UNIFORM_BUFFER
        case .Storage: return .STORAGE_BUFFER
        case .Read_Only_Storage: return .STORAGE_BUFFER
        case:
            panic_contextless("Invalid buffer binding type", loc)
        }
    case Sampler_Binding_Layout:
        return .SAMPLER
    case Texture_Binding_Layout:
        return .SAMPLED_IMAGE
    case Storage_Texture_Binding_Layout:
        return .STORAGE_IMAGE
    case Acceleration_Structure_Binding_Layout:
        return .ACCELERATION_STRUCTURE_KHR
    }
    unreachable()
}

vk_conv_to_stage_flags :: #force_inline proc "contextless" (stage: Shader_Stages) -> vk.ShaderStageFlags {
    ret: vk.ShaderStageFlags
    if .Vertex in stage { ret += { .VERTEX } }
    if .Fragment in stage { ret += { .FRAGMENT } }
    if .Compute in stage { ret += { .COMPUTE } }
    if .Task in stage { ret += { .TASK_EXT } }
    if .Mesh in stage { ret += { .MESH_EXT } }
    return ret
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

vk_conv_to_image_aspect_flags :: #force_inline proc "contextless" (
    aspect: Texture_Aspect,
    format: Texture_Format,
    loc := #caller_location,
) -> vk.ImageAspectFlags {
    assert_contextless(aspect != .Undefined, "Invalid texture aspect", loc)

    depth := texture_format_has_depth_aspect(format)
    stencil := texture_format_has_stencil_aspect(format)

    #partial switch aspect {
    case .All:
        if depth && stencil { return { .DEPTH, .STENCIL } }
        if depth { return { .DEPTH } }
        if stencil { return { .DEPTH } }
        return { .COLOR }
    case .Depth_Only: return { .DEPTH }
    case .Stencil_Only: return { .STENCIL }
    case .Plane0: return { .PLANE_0 }
    case .Plane1: return { .PLANE_1 }
    case .Plane2: return { .PLANE_2 }
    case:
        unreachable()
    }
}

vk_conv_to_sampler_address_mode :: #force_inline proc "contextless" (
    mode: Address_Mode,
    loc := #caller_location,
) -> vk.SamplerAddressMode {
    assert_contextless(mode != .Undefined, "Invalid sampler address mode", loc)

    #partial switch mode {
    case .Clamp_To_Edge: return .CLAMP_TO_EDGE
    case .Repeat: return .REPEAT
    case .Mirror_Repeat: return .MIRRORED_REPEAT
    case .Clamp_To_Border: return .CLAMP_TO_BORDER
    case:
        unreachable()
    }
}

vk_format_to_texture_format :: #force_inline proc "contextless" (vk_format: vk.Format) -> Texture_Format {
    #partial switch (vk_format) {
    // WebGPU
    case .UNDEFINED:             return .Undefined
    case .R8_UNORM:              return .R8_Unorm
    case .R8_SNORM:              return .R8_Snorm
    case .R8_UINT:               return .R8_Uint
    case .R8_SINT:               return .R8_Sint
    case .R16_UINT:              return .R16_Uint
    case .R16_SINT:              return .R16_Sint
    case .R16_SFLOAT:            return .R16_Float
    case .R8G8_UNORM:            return .Rg8_Unorm
    case .R8G8_SNORM:            return .Rg8_Snorm
    case .R8G8_UINT:             return .Rg8_Uint
    case .R8G8_SINT:             return .Rg8_Sint
    case .R32_SFLOAT:            return .R32_Float
    case .R32_UINT:              return .R32_Uint
    case .R32_SINT:              return .R32_Sint
    case .R16G16_UINT:           return .Rg16_Uint
    case .R16G16_SINT:           return .Rg16_Sint
    case .R16G16_SFLOAT:         return .Rg16_Float
    case .R8G8B8A8_UNORM:        return .Rgba8_Unorm
    case .R8G8B8A8_SRGB:         return .Rgba8_Unorm_Srgb
    case .R8G8B8A8_SNORM:        return .Rgba8_Snorm
    case .R8G8B8A8_UINT:         return .Rgba8_Uint
    case .R8G8B8A8_SINT:         return .Rgba8_Sint
    case .B8G8R8A8_UNORM:        return .Bgra8_Unorm
    case .B8G8R8A8_SRGB:         return .Bgra8_Unorm_Srgb

    // Depth / stencil
    case .D16_UNORM:             return .Depth16_Unorm
    case .X8_D24_UNORM_PACK32:   return .Depth24_Plus // Approx
    case .D24_UNORM_S8_UINT:     return .Depth24_Plus_Stencil8
    case .D32_SFLOAT:            return .Depth32_Float
    case .D32_SFLOAT_S8_UINT:    return .Depth32_Float_Stencil8

    // BC compressed
    case .BC1_RGBA_UNORM_BLOCK:  return .Bc1_Rgba_Unorm
    case .BC1_RGBA_SRGB_BLOCK:   return .Bc1_Rgba_Unorm_Srgb
    case .BC2_UNORM_BLOCK:       return .Bc2_Rgba_Unorm
    case .BC2_SRGB_BLOCK:        return .Bc2_Rgba_Unorm_Srgb
    case .BC3_UNORM_BLOCK:       return .Bc3_Rgba_Unorm
    case .BC3_SRGB_BLOCK:        return .Bc3_Rgba_Unorm_Srgb
    case .BC4_UNORM_BLOCK:       return .Bc4_R_Unorm
    case .BC4_SNORM_BLOCK:       return .Bc4_R_Snorm
    case .BC5_UNORM_BLOCK:       return .Bc5_Rg_Unorm
    case .BC5_SNORM_BLOCK:       return .Bc5_Rg_Snorm
    case .BC6H_UFLOAT_BLOCK:     return .Bc6_hRgb_Ufloat
    case .BC6H_SFLOAT_BLOCK:     return .Bc6_hRgb_Float
    case .BC7_UNORM_BLOCK:       return .Bc7_Rgba_Unorm
    case .BC7_SRGB_BLOCK:        return .Bc7_Rgba_Unorm_Srgb

    // ETC2 / EAC
    case .ETC2_R8G8B8_UNORM_BLOCK:       return .Etc2_Rgb8_Unorm
    case .ETC2_R8G8B8_SRGB_BLOCK:        return .Etc2_Rgb8_Unorm_Srgb
    case .ETC2_R8G8B8A1_UNORM_BLOCK:     return .Etc2_Rgb8A1_Unorm
    case .ETC2_R8G8B8A1_SRGB_BLOCK:      return .Etc2_Rgb8A1_Unorm_Srgb
    case .ETC2_R8G8B8A8_UNORM_BLOCK:     return .Etc2_Rgba8_Unorm
    case .ETC2_R8G8B8A8_SRGB_BLOCK:      return .Etc2_Rgba8_Unorm_Srgb
    case .EAC_R11_UNORM_BLOCK:           return .Eac_R11_Unorm
    case .EAC_R11_SNORM_BLOCK:           return .Eac_R11_Snorm
    case .EAC_R11G11_UNORM_BLOCK:        return .Eac_Rg11_Unorm
    case .EAC_R11G11_SNORM_BLOCK:        return .Eac_Rg11_Snorm

    // ASTC
    case .ASTC_4x4_UNORM_BLOCK:          return .Astc_4x4_Unorm
    case .ASTC_4x4_SRGB_BLOCK:           return .Astc_4x4_Unorm_Srgb
    case .ASTC_5x4_UNORM_BLOCK:          return .Astc_5x4_Unorm
    case .ASTC_5x4_SRGB_BLOCK:           return .Astc_5x4_Unorm_Srgb
    case .ASTC_5x5_UNORM_BLOCK:          return .Astc_5x5_Unorm
    case .ASTC_5x5_SRGB_BLOCK:           return .Astc_5x5_Unorm_Srgb
    case .ASTC_6x5_UNORM_BLOCK:          return .Astc_6x5_Unorm
    case .ASTC_6x5_SRGB_BLOCK:           return .Astc_6x5_Unorm_Srgb
    case .ASTC_6x6_UNORM_BLOCK:          return .Astc_6x6_Unorm
    case .ASTC_6x6_SRGB_BLOCK:           return .Astc_6x6_Unorm_Srgb
    case .ASTC_8x5_UNORM_BLOCK:          return .Astc_8x5_Unorm
    case .ASTC_8x5_SRGB_BLOCK:           return .Astc_8x5_Unorm_Srgb
    case .ASTC_8x6_UNORM_BLOCK:          return .Astc_8x6_Unorm
    case .ASTC_8x6_SRGB_BLOCK:           return .Astc_8x6_Unorm_Srgb
    case .ASTC_8x8_UNORM_BLOCK:          return .Astc_8x8_Unorm
    case .ASTC_8x8_SRGB_BLOCK:           return .Astc_8x8_Unorm_Srgb
    case .ASTC_10x5_UNORM_BLOCK:         return .Astc_10x5_Unorm
    case .ASTC_10x5_SRGB_BLOCK:          return .Astc_10x5_Unorm_Srgb
    case .ASTC_10x6_UNORM_BLOCK:         return .Astc_10x6_Unorm
    case .ASTC_10x6_SRGB_BLOCK:          return .Astc_10x6_Unorm_Srgb
    case .ASTC_10x8_UNORM_BLOCK:         return .Astc_10x8_Unorm
    case .ASTC_10x8_SRGB_BLOCK:          return .Astc_10x8_Unorm_Srgb
    case .ASTC_10x10_UNORM_BLOCK:        return .Astc_10x10_Unorm
    case .ASTC_10x10_SRGB_BLOCK:         return .Astc_10x10_Unorm_Srgb
    case .ASTC_12x10_UNORM_BLOCK:        return .Astc_12x10_Unorm
    case .ASTC_12x10_SRGB_BLOCK:         return .Astc_12x10_Unorm_Srgb
    case .ASTC_12x12_UNORM_BLOCK:        return .Astc_12x12_Unorm
    case .ASTC_12x12_SRGB_BLOCK:         return .Astc_12x12_Unorm_Srgb

    // NV12 / YUV
    // case .G8_B8R8_2PLANE_420_UNORM:      return .Nv12

    case:
        return .Undefined // Fallback
    }
}

VK_CONV_TO_IMAGE_VIEW_TYPE_LUT := [Texture_View_Dimension]vk.ImageViewType {
    .D1         = .D1,
    .D2         = .D2,
    .D2_Array   = .D2_ARRAY,
    .Cube       = .CUBE,
    .Cube_Array = .CUBE_ARRAY,
    .D3         = .D3,
    .Undefined  = .D2,
}

VK_TEXTURE_FORMAT_TO_VK_FORMAT_LUT := [Texture_Format]vk.Format{
    // WebGPU
    .Undefined               = vk.Format.UNDEFINED,
    .R8_Unorm                = vk.Format.R8_UNORM,
    .R8_Snorm                = vk.Format.R8_SNORM,
    .R8_Uint                 = vk.Format.R8_UINT,
    .R8_Sint                 = vk.Format.R8_SINT,
    .R16_Uint                = vk.Format.R16_UINT,
    .R16_Sint                = vk.Format.R16_SINT,
    .R16_Float               = vk.Format.R16_SFLOAT,
    .Rg8_Unorm               = vk.Format.R8G8_UNORM,
    .Rg8_Snorm               = vk.Format.R8G8_SNORM,
    .Rg8_Uint                = vk.Format.R8G8_UINT,
    .Rg8_Sint                = vk.Format.R8G8_SINT,
    .R32_Float               = vk.Format.R32_SFLOAT,
    .R32_Uint                = vk.Format.R32_UINT,
    .R32_Sint                = vk.Format.R32_SINT,
    .Rg16_Uint               = vk.Format.R16G16_UINT,
    .Rg16_Sint               = vk.Format.R16G16_SINT,
    .Rg16_Float              = vk.Format.R16G16_SFLOAT,
    .Rgba8_Unorm             = vk.Format.R8G8B8A8_UNORM,
    .Rgba8_Unorm_Srgb        = vk.Format.R8G8B8A8_SRGB,
    .Rgba8_Snorm             = vk.Format.R8G8B8A8_SNORM,
    .Rgba8_Uint              = vk.Format.R8G8B8A8_UINT,
    .Rgba8_Sint              = vk.Format.R8G8B8A8_SINT,
    .Bgra8_Unorm             = vk.Format.B8G8R8A8_UNORM,
    .Bgra8_Unorm_Srgb        = vk.Format.B8G8R8A8_SRGB,
    .Rgb10a2_Uint            = vk.Format.A2B10G10R10_UINT_PACK32,   // Closest
    .Rgb10a2_Unorm           = vk.Format.A2B10G10R10_UNORM_PACK32,
    .Rg11b10_Ufloat          = vk.Format.B10G11R11_UFLOAT_PACK32,
    .Rgb9e5_Ufloat           = vk.Format.E5B9G9R9_UFLOAT_PACK32,
    .Rg32_Float              = vk.Format.R32G32_SFLOAT,
    .Rg32_Uint               = vk.Format.R32G32_UINT,
    .Rg32_Sint               = vk.Format.R32G32_SINT,
    .Rgba16_Uint             = vk.Format.R16G16B16A16_UINT,
    .Rgba16_Sint             = vk.Format.R16G16B16A16_SINT,
    .Rgba16_Float            = vk.Format.R16G16B16A16_SFLOAT,
    .Rgba32_Float            = vk.Format.R32G32B32A32_SFLOAT,
    .Rgba32_Uint             = vk.Format.R32G32B32A32_UINT,
    .Rgba32_Sint             = vk.Format.R32G32B32A32_SINT,
    .Stencil8                = vk.Format.S8_UINT,
    .Depth16_Unorm           = vk.Format.D16_UNORM,
    .Depth24_Plus            = vk.Format.X8_D24_UNORM_PACK32,   // Implementation-dependent
    .Depth24_Plus_Stencil8   = vk.Format.D24_UNORM_S8_UINT,
    .Depth32_Float           = vk.Format.D32_SFLOAT,
    .Depth32_Float_Stencil8  = vk.Format.D32_SFLOAT_S8_UINT,

    // BC compressed
    .Bc1_Rgba_Unorm          = vk.Format.BC1_RGBA_UNORM_BLOCK,
    .Bc1_Rgba_Unorm_Srgb     = vk.Format.BC1_RGBA_SRGB_BLOCK,
    .Bc2_Rgba_Unorm          = vk.Format.BC2_UNORM_BLOCK,
    .Bc2_Rgba_Unorm_Srgb     = vk.Format.BC2_SRGB_BLOCK,
    .Bc3_Rgba_Unorm          = vk.Format.BC3_UNORM_BLOCK,
    .Bc3_Rgba_Unorm_Srgb     = vk.Format.BC3_SRGB_BLOCK,
    .Bc4_R_Unorm             = vk.Format.BC4_UNORM_BLOCK,
    .Bc4_R_Snorm             = vk.Format.BC4_SNORM_BLOCK,
    .Bc5_Rg_Unorm            = vk.Format.BC5_UNORM_BLOCK,
    .Bc5_Rg_Snorm            = vk.Format.BC5_SNORM_BLOCK,
    .Bc6_hRgb_Ufloat         = vk.Format.BC6H_UFLOAT_BLOCK,
    .Bc6_hRgb_Float          = vk.Format.BC6H_SFLOAT_BLOCK,
    .Bc7_Rgba_Unorm          = vk.Format.BC7_UNORM_BLOCK,
    .Bc7_Rgba_Unorm_Srgb     = vk.Format.BC7_SRGB_BLOCK,

    // ETC2
    .Etc2_Rgb8_Unorm         = vk.Format.ETC2_R8G8B8_UNORM_BLOCK,
    .Etc2_Rgb8_Unorm_Srgb    = vk.Format.ETC2_R8G8B8_SRGB_BLOCK,
    .Etc2_Rgb8A1_Unorm       = vk.Format.ETC2_R8G8B8A1_UNORM_BLOCK,
    .Etc2_Rgb8A1_Unorm_Srgb  = vk.Format.ETC2_R8G8B8A1_SRGB_BLOCK,
    .Etc2_Rgba8_Unorm        = vk.Format.ETC2_R8G8B8A8_UNORM_BLOCK,
    .Etc2_Rgba8_Unorm_Srgb   = vk.Format.ETC2_R8G8B8A8_SRGB_BLOCK,

    // EAC
    .Eac_R11_Unorm           = vk.Format.EAC_R11_UNORM_BLOCK,
    .Eac_R11_Snorm           = vk.Format.EAC_R11_SNORM_BLOCK,
    .Eac_Rg11_Unorm          = vk.Format.EAC_R11G11_UNORM_BLOCK,
    .Eac_Rg11_Snorm          = vk.Format.EAC_R11G11_SNORM_BLOCK,

    // ASTC
    .Astc_4x4_Unorm          = vk.Format.ASTC_4x4_UNORM_BLOCK,
    .Astc_4x4_Unorm_Srgb     = vk.Format.ASTC_4x4_SRGB_BLOCK,
    .Astc_5x4_Unorm          = vk.Format.ASTC_5x4_UNORM_BLOCK,
    .Astc_5x4_Unorm_Srgb     = vk.Format.ASTC_5x4_SRGB_BLOCK,
    .Astc_5x5_Unorm          = vk.Format.ASTC_5x5_UNORM_BLOCK,
    .Astc_5x5_Unorm_Srgb     = vk.Format.ASTC_5x5_SRGB_BLOCK,
    .Astc_6x5_Unorm          = vk.Format.ASTC_6x5_UNORM_BLOCK,
    .Astc_6x5_Unorm_Srgb     = vk.Format.ASTC_6x5_SRGB_BLOCK,
    .Astc_6x6_Unorm          = vk.Format.ASTC_6x6_UNORM_BLOCK,
    .Astc_6x6_Unorm_Srgb     = vk.Format.ASTC_6x6_SRGB_BLOCK,
    .Astc_8x5_Unorm          = vk.Format.ASTC_8x5_UNORM_BLOCK,
    .Astc_8x5_Unorm_Srgb     = vk.Format.ASTC_8x5_SRGB_BLOCK,
    .Astc_8x6_Unorm          = vk.Format.ASTC_8x6_UNORM_BLOCK,
    .Astc_8x6_Unorm_Srgb     = vk.Format.ASTC_8x6_SRGB_BLOCK,
    .Astc_8x8_Unorm          = vk.Format.ASTC_8x8_UNORM_BLOCK,
    .Astc_8x8_Unorm_Srgb     = vk.Format.ASTC_8x8_SRGB_BLOCK,
    .Astc_10x5_Unorm         = vk.Format.ASTC_10x5_UNORM_BLOCK,
    .Astc_10x5_Unorm_Srgb    = vk.Format.ASTC_10x5_SRGB_BLOCK,
    .Astc_10x6_Unorm         = vk.Format.ASTC_10x6_UNORM_BLOCK,
    .Astc_10x6_Unorm_Srgb    = vk.Format.ASTC_10x6_SRGB_BLOCK,
    .Astc_10x8_Unorm         = vk.Format.ASTC_10x8_UNORM_BLOCK,
    .Astc_10x8_Unorm_Srgb    = vk.Format.ASTC_10x8_SRGB_BLOCK,
    .Astc_10x10_Unorm        = vk.Format.ASTC_10x10_UNORM_BLOCK,
    .Astc_10x10_Unorm_Srgb   = vk.Format.ASTC_10x10_SRGB_BLOCK,
    .Astc_12x10_Unorm        = vk.Format.ASTC_12x10_UNORM_BLOCK,
    .Astc_12x10_Unorm_Srgb   = vk.Format.ASTC_12x10_SRGB_BLOCK,
    .Astc_12x12_Unorm        = vk.Format.ASTC_12x12_UNORM_BLOCK,
    .Astc_12x12_Unorm_Srgb   = vk.Format.ASTC_12x12_SRGB_BLOCK,
    .Astc_4x4_Unorm_Hdr      = vk.Format.ASTC_4x4_SFLOAT_BLOCK,
    .Astc_5x4_Unorm_Hdr      = vk.Format.ASTC_5x4_SFLOAT_BLOCK,
    .Astc_5x5_Unorm_Hdr      = vk.Format.ASTC_5x5_SFLOAT_BLOCK,
    .Astc_6x5_Unorm_Hdr      = vk.Format.ASTC_6x5_SFLOAT_BLOCK,
    .Astc_6x6_Unorm_Hdr      = vk.Format.ASTC_6x6_SFLOAT_BLOCK,
    .Astc_8x5_Unorm_Hdr      = vk.Format.ASTC_8x5_SFLOAT_BLOCK,
    .Astc_8x6_Unorm_Hdr      = vk.Format.ASTC_8x6_SFLOAT_BLOCK,
    .Astc_8x8_Unorm_Hdr      = vk.Format.ASTC_8x8_SFLOAT_BLOCK,
    .Astc_10x5_Unorm_Hdr     = vk.Format.ASTC_10x5_SFLOAT_BLOCK,
    .Astc_10x6_Unorm_Hdr     = vk.Format.ASTC_10x6_SFLOAT_BLOCK,
    .Astc_10x8_Unorm_Hdr     = vk.Format.ASTC_10x8_SFLOAT_BLOCK,
    .Astc_10x10_Unorm_Hdr    = vk.Format.ASTC_10x10_SFLOAT_BLOCK,
    .Astc_12x10_Unorm_Hdr    = vk.Format.ASTC_12x10_SFLOAT_BLOCK,
    .Astc_12x12_Unorm_Hdr    = vk.Format.ASTC_12x12_SFLOAT_BLOCK,

    // Native-only extensions
    .R64_Uint                = vk.Format.R64_UINT,
    .R16_Unorm               = vk.Format.R16_UNORM,
    .R16_Snorm               = vk.Format.R16_SNORM,
    .Rg16_Unorm              = vk.Format.R16G16_UNORM,
    .Rg16_Snorm              = vk.Format.R16G16_SNORM,
    .Rgba16_Unorm            = vk.Format.R16G16B16A16_UNORM,
    .Rgba16_Snorm            = vk.Format.R16G16B16A16_SNORM,
    .NV12                    = vk.Format.G8_B8R8_2PLANE_420_UNORM,
    .P010                    = vk.Format.G10X6_B10X6_R10X6_3PLANE_420_UNORM_3PACK16,
}
