package gpu

_webgpu_features_slice_to_flags :: proc "contextless" (features: []Feature) -> (ret: Features) {
    for &f in features {
        #partial switch f {
        // WebGPU
        case .Depth_Clip_Control:
            ret += { .Depth_Clip_Control }
        case .Depth32_Float_Stencil8:
            ret += { .Depth32_Float_Stencil8 }
        case .Texture_Compression_Bc:
            ret += { .Texture_Compression_Bc }
        case .Texture_Compression_Bc_Sliced_3D:
            ret += { .Texture_Compression_Bc_Sliced_3D }
        case .Texture_Compression_Etc2:
            ret += { .Texture_Compression_Etc2 }
        case .Texture_Compression_Astc:
            ret += { .Texture_Compression_Astc }
        case .Texture_Compression_Astc_Sliced_3D:
            ret += { .Texture_Compression_Astc_Sliced_3D }
        case .Timestamp_Query:
            ret += { .Timestamp_Query }
        case .Indirect_First_Instance:
            ret += { .Indirect_First_Instance }
        case .Shader_F16:
            ret += { .Shader_F16 }
        case .Rg11B10_Ufloat_Renderable:
            ret += { .Rg11B10_Ufloat_Renderable }
        case .Bgra8_Unorm_Storage:
            ret += { .Bgra8_Unorm_Storage }
        case .Float32_Filterable:
            ret += { .Float32_Filterable }
        case .Clip_Distances:
            ret += { .Clip_Distances }
        case .Dual_Source_Blending:
            ret += { .Dual_Source_Blending }
        }
    }
    return
}
