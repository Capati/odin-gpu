package cts

// Local
import gpu "../../gpu"

// A minimal vertex/fragment pair, compiled from the repository's triangle
// example. The vertex shader reads attributes, which the pipeline rows never
// bind: they only need a pipeline object, not a rendered triangle.
TRIANGLE_VERT_BYTES :: #load("../../examples/triangle/shaders/SPIRV/triangle.vert.spv")
TRIANGLE_FRAG_BYTES :: #load("../../examples/triangle/shaders/SPIRV/triangle.frag.spv")

cts_spirv_words :: proc(bytes: []u8) -> []u32 {
    words := make([]u32, len(bytes) / 4, context.temp_allocator)
    for i in 0 ..< len(words) {
        base := i * 4
        words[i] = u32(bytes[base]) |
            u32(bytes[base + 1]) << 8 |
            u32(bytes[base + 2]) << 16 |
            u32(bytes[base + 3]) << 24
    }
    return words
}

// Minimal compute shader: `void main() {}` at local size 1.
COMPUTE_SPIRV :: []u32{
    0x07230203, 0x00010000, 0x00000000, 0x00000005, 0x00000000,
    0x00020011, 1,
    0x0003000E, 0, 1,
    0x0005000F, 5, 3, 0x6E69616D, 0,
    0x00060010, 3, 17, 1, 1, 1,
    0x00020013, 1,
    0x00030021, 2, 1,
    0x00050036, 1, 3, 0, 2,
    0x000200F8, 4,
    0x000100FD,
    0x00010038,
}

cts_make_compute_pipeline :: proc(device: gpu.Device) -> gpu.Compute_Pipeline {
    module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = COMPUTE_SPIRV},
    })
    if module == {} {
        return {}
    }
    defer gpu.shader_module_release(module)
    return gpu.device_create_compute_pipeline(device, {
        module      = module,
        entry_point = "main",
    })
}

cts_make_render_pipeline_full :: proc(
    device: gpu.Device,
    targets: []gpu.Color_Target_State,
    depth_stencil: ^gpu.Depth_Stencil_State,
    sample_count: u32,
    topology: gpu.Primitive_Topology = .Triangle_List,
    strip_index_format: gpu.Index_Format = .Undefined,
    buffers: []gpu.Vertex_Buffer_Layout = nil,
    layout: gpu.Pipeline_Layout = {},
) -> gpu.Render_Pipeline {
    vertex_module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_VERT_BYTES)},
    })
    fragment_module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_FRAG_BYTES)},
    })
    if vertex_module == {} || fragment_module == {} {
        return {}
    }
    defer gpu.shader_module_release(vertex_module)
    defer gpu.shader_module_release(fragment_module)

    fragment := gpu.Fragment_State {
        module      = fragment_module,
        entry_point = "fs_main",
        targets     = targets,
    }
    multisample := gpu.DEFAULT_MULTISAMPLE_STATE
    multisample.count = sample_count
    descriptor := gpu.Render_Pipeline_Descriptor {
        layout = layout,
        vertex = {
            module      = vertex_module,
            entry_point = "vs_main",
            buffers     = buffers,
        },
        primitive = {
            topology           = topology,
            strip_index_format = strip_index_format,
            front_face         = .CCW,
            cull_mode          = .None,
            polygon_mode       = .Fill,
        },
        depth_stencil = depth_stencil,
        multisample   = multisample,
        fragment      = &fragment,
    }
    return gpu.device_create_render_pipeline(device, descriptor)
}

cts_make_render_pipeline :: proc(
    device: gpu.Device,
    color_format: gpu.Texture_Format,
    topology: gpu.Primitive_Topology = .Triangle_List,
    strip_index_format: gpu.Index_Format = .Undefined,
) -> gpu.Render_Pipeline {
    targets := [1]gpu.Color_Target_State {
        {format = color_format, write_mask = gpu.COLOR_WRITES_ALL},
    }
    return cts_make_render_pipeline_full(
        device, targets[:], nil, 1, topology, strip_index_format)
}
