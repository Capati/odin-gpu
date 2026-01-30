#+build js
package gpu

// Vendor
import "vendor:wgpu"

wgpu_conv_from_adapter_type :: #force_inline proc "contextless" (adapter_type: wgpu.AdapterType) -> Device_Type {
    #partial switch adapter_type {
    case .DiscreteGPU:   return .Discrete_Gpu
    case .IntegratedGPU: return .Integrated_Gpu
    case .CPU:           return .Cpu
    case:
        return .Other
    }
}

wgpu_conv_from_backend_type :: #force_inline proc "contextless" (backend_type: wgpu.BackendType) -> Backend {
    switch backend_type {
    case .Undefined, .Null:  return .Null
    case .WebGPU:            return .WebGPU
    case .D3D11:             return .Dx11
    case .D3D12:             return .Dx12
    case .Metal:             return .Metal
    case .Vulkan:            return .Vulkan
    case .OpenGL, .OpenGLES: return .Gl
    }
    unreachable()
}

wgpu_conv_from_feature_names :: #force_inline proc "contextless" (features: []wgpu.FeatureName) -> (ret: Features) {
    for &f in features {
        switch f {
        // WebGPU
        case .DepthClipControl:
            ret += { .Depth_Clip_Control }
        case .Depth32FloatStencil8:
            ret += { .Depth32_Float_Stencil8 }
        case .TimestampQuery:
            ret += { .Timestamp_Query }
        case .TextureCompressionBC:
            ret += { .Texture_Compression_BC }
        case .TextureCompressionBCSliced3D:
            ret += { .Texture_Compression_BC_Sliced_3D }
        case .TextureCompressionETC2:
            ret += { .Texture_Compression_ETC2 }
        case .TextureCompressionASTC:
            ret += { .Texture_Compression_ASTC }
        case .TextureCompressionASTCSliced3D:
            ret += { .Texture_Compression_ASTC_Sliced_3D }
        case .IndirectFirstInstance:
            ret += { .Indirect_First_Instance }
        case .ShaderF16:
            ret += { .Shader_F16 }
        case .RG11B10UfloatRenderable:
            ret += { .Rg11B10_Ufloat_Renderable }
        case .BGRA8UnormStorage:
            ret += { .Bgra8_Unorm_Storage }
        case .Float32Filterable:
            ret += { .Float32_Filterable }
        case .Float32Blendable:
            ret += { .Float32_Blendable }
        case .ClipDistances:
            ret += { .Clip_Distances }
        case .DualSourceBlending:
            ret += { .Dual_Source_Blending }

        // Native
        case .PushConstants:
            ret += { .Push_Constants }
        case .TextureAdapterSpecificFormatFeatures:
            ret += { .Texture_Adapter_Specific_Format_Features }
        case .MultiDrawIndirectCount:
            ret += { .Multi_Draw_Indirect_Count }
        case .VertexWritableStorage:
            ret += { .Vertex_Writable_Storage }
        case .TextureBindingArray:
            ret += { .Texture_Binding_Array }
        case .SampledTextureAndStorageBufferArrayNonUniformIndexing:
            ret += { .Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing }
        case .PipelineStatisticsQuery:
            ret += { .Pipeline_Statistics_Query }
        case .StorageResourceBindingArray:
            ret += { .Storage_Resource_Binding_Array }
        case .PartiallyBoundBindingArray:
            ret += { .Partially_Bound_Binding_Array }
        case .TextureFormat16bitNorm:
            ret += { .Texture_Format_16Bit_Norm }
        case .TextureCompressionAstcHdr:
            ret += { .Texture_Compression_ASTC_Hdr }
        case .MappablePrimaryBuffers:
            ret += { .Mappable_Primary_Buffers }
        case .BufferBindingArray:
            ret += { .Buffer_Binding_Array }
        case .PolygonModeLine:
            ret += { .Polygon_Mode_Line }
        case .PolygonModePoint:
            ret += { .Polygon_Mode_Point }
        case .ConservativeRasterization:
            ret += { .Conservative_Rasterization }
        case .UniformBufferAndStorageTextureArrayNonUniformIndexing:
            ret += { .Uniform_Buffer_And_Storage_Texture_Array_Non_Uniform_Indexing }
        case .SpirvShaderPassthrough:
            ret += { .Spirv_Shader_Passthrough }
        case .VertexAttribute64bit:
            ret += { .Vertex_Attribute_64Bit }
        case .TextureFormatNv12:
            ret += { .Texture_Format_Nv12 }
        case .RayQuery:
            ret += { .Ray_Query }
        case .ShaderF64:
            ret += { .Shader_F64 }
        case .ShaderI16:
            ret += { .Shader_I16 }
        case .ShaderPrimitiveIndex:
            ret += { .Shader_Primitive_Index }
        case .ShaderEarlyDepthTest:
            ret += { .Shader_Early_Depth_Test }
        case .Subgroup:
            ret += { .Subgroup }
        case .SubgroupVertex:
            ret += { .Subgroup_Vertex }
        case .SubgroupBarrier:
            ret += { .Subgroup_Barrier }
        case .TimestampQueryInsideEncoders:
            ret += { .Timestamp_Query_Inside_Encoders }
        case .TimestampQueryInsidePasses:
            ret += { .Timestamp_Query_Inside_Passes }
        case .ShaderInt64:
            ret += { .Shader_Int64 }
        case .Undefined:
            continue
        }
    }
    return
}

@(rodata)
WGPU_CONV_TO_FEATURE_NAME_LUT := [Feature]wgpu.FeatureName {
    .Undefined                                                     = .Undefined,
    .Depth_Clip_Control                                            = .DepthClipControl,
    .Depth32_Float_Stencil8                                        = .Depth32FloatStencil8,
    .Timestamp_Query                                               = .TimestampQuery,
    .Texture_Compression_BC                                        = .TextureCompressionBC,
    .Texture_Compression_BC_Sliced_3D                              = .TextureCompressionBCSliced3D,
    .Texture_Compression_ETC2                                      = .TextureCompressionETC2,
    .Texture_Compression_ASTC                                      = .TextureCompressionASTC,
    .Texture_Compression_ASTC_Sliced_3D                            = .TextureCompressionASTCSliced3D,
    .Indirect_First_Instance                                       = .IndirectFirstInstance,
    .Shader_F16                                                    = .ShaderF16,
    .Rg11B10_Ufloat_Renderable                                     = .RG11B10UfloatRenderable,
    .Bgra8_Unorm_Storage                                           = .BGRA8UnormStorage,
    .Float32_Filterable                                            = .Float32Filterable,
    .Float32_Blendable                                             = .Float32Blendable,
    .Clip_Distances                                                = .ClipDistances,
    .Dual_Source_Blending                                          = .DualSourceBlending,
    .Push_Constants                                                = .PushConstants,
    .Texture_Adapter_Specific_Format_Features                      = .TextureAdapterSpecificFormatFeatures,
    .Multi_Draw_Indirect_Count                                     = .MultiDrawIndirectCount,
    .Vertex_Writable_Storage                                       = .VertexWritableStorage,
    .Texture_Binding_Array                                         = .TextureBindingArray,
    .Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing = .SampledTextureAndStorageBufferArrayNonUniformIndexing,
    .Pipeline_Statistics_Query                                     = .PipelineStatisticsQuery,
    .Storage_Resource_Binding_Array                                = .StorageResourceBindingArray,
    .Partially_Bound_Binding_Array                                 = .PartiallyBoundBindingArray,
    .Texture_Format_16Bit_Norm                                     = .TextureFormat16bitNorm,
    .Texture_Compression_ASTC_Hdr                                  = .TextureCompressionAstcHdr,
    .Mappable_Primary_Buffers                                      = .MappablePrimaryBuffers,
    .Buffer_Binding_Array                                          = .BufferBindingArray,
    .Uniform_Buffer_And_Storage_Texture_Array_Non_Uniform_Indexing = .UniformBufferAndStorageTextureArrayNonUniformIndexing,
    .Address_Mode_Clamp_To_Zero                                    = .Undefined,
    .Address_Mode_Clamp_To_Border                                  = .Undefined,
    .Polygon_Mode_Line                                             = .PolygonModeLine,
    .Polygon_Mode_Point                                            = .PolygonModePoint,
    .Conservative_Rasterization                                    = .ConservativeRasterization,
    .Clear_Texture                                                 = .Undefined,
    .Spirv_Shader_Passthrough                                      = .SpirvShaderPassthrough,
    .Multiview                                                     = .Undefined,
    .Vertex_Attribute_64Bit                                        = .VertexAttribute64bit,
    .Texture_Format_Nv12                                           = .TextureFormatNv12,
    .Texture_Format_P010                                           = .Undefined,
    .Ray_Query                                                     = .RayQuery,
    .Shader_F64                                                    = .ShaderF64,
    .Shader_I16                                                    = .ShaderI16,
    .Shader_Primitive_Index                                        = .ShaderPrimitiveIndex,
    .Shader_Early_Depth_Test                                       = .ShaderEarlyDepthTest,
    .Subgroup                                                      = .Subgroup,
    .Subgroup_Vertex                                               = .SubgroupVertex,
    .Subgroup_Barrier                                              = .SubgroupBarrier,
    .Timestamp_Query_Inside_Encoders                               = .TimestampQueryInsideEncoders,
    .Timestamp_Query_Inside_Passes                                 = .TimestampQueryInsidePasses,
    .Shader_Int64                                                  = .ShaderInt64,
    .Texture_Atomic                                                = .Undefined,
    .Texture_Int64_Atomic                                          = .Undefined,
}

wgpu_conv_from_limits :: proc "contextless" (
    raw_limits: wgpu.Limits,
) -> (
    limits: Limits,
) {
    limits = {
        max_texture_dimension_1d                        = raw_limits.maxTextureDimension1D,
        max_texture_dimension_2d                        = raw_limits.maxTextureDimension2D,
        max_texture_dimension_3d                        = raw_limits.maxTextureDimension3D,
        max_texture_array_layers                        = raw_limits.maxTextureArrayLayers,
        max_bind_groups                                 = raw_limits.maxBindGroups,
        max_bind_groups_plus_vertex_buffers             = raw_limits.maxBindGroupsPlusVertexBuffers,
        max_bindings_per_bind_group                     = raw_limits.maxBindingsPerBindGroup,
        max_dynamic_uniform_buffers_per_pipeline_layout = raw_limits.maxDynamicUniformBuffersPerPipelineLayout,
        max_dynamic_storage_buffers_per_pipeline_layout = raw_limits.maxDynamicStorageBuffersPerPipelineLayout,
        max_sampled_textures_per_shader_stage           = raw_limits.maxSampledTexturesPerShaderStage,
        max_samplers_per_shader_stage                   = raw_limits.maxSamplersPerShaderStage,
        max_storage_buffers_per_shader_stage            = raw_limits.maxStorageBuffersPerShaderStage,
        max_storage_textures_per_shader_stage           = raw_limits.maxStorageTexturesPerShaderStage,
        max_uniform_buffers_per_shader_stage            = raw_limits.maxUniformBuffersPerShaderStage,
        max_uniform_buffer_binding_size                 = raw_limits.maxUniformBufferBindingSize,
        max_storage_buffer_binding_size                 = raw_limits.maxStorageBufferBindingSize,
        min_uniform_buffer_offset_alignment             = raw_limits.minUniformBufferOffsetAlignment,
        min_storage_buffer_offset_alignment             = raw_limits.minStorageBufferOffsetAlignment,
        max_vertex_buffers                              = raw_limits.maxVertexBuffers,
        max_buffer_size                                 = raw_limits.maxBufferSize,
        max_vertex_attributes                           = raw_limits.maxVertexAttributes,
        max_vertex_buffer_array_stride                  = raw_limits.maxVertexBufferArrayStride,
        max_inter_stage_shader_variables                = raw_limits.maxInterStageShaderVariables,
        max_color_attachments                           = raw_limits.maxColorAttachments,
        max_color_attachment_bytes_per_sample           = raw_limits.maxColorAttachmentBytesPerSample,
        max_compute_workgroup_storage_size              = raw_limits.maxComputeWorkgroupStorageSize,
        max_compute_invocations_per_workgroup           = raw_limits.maxComputeInvocationsPerWorkgroup,
        max_compute_workgroup_size_x                    = raw_limits.maxComputeWorkgroupSizeX,
        max_compute_workgroup_size_y                    = raw_limits.maxComputeWorkgroupSizeY,
        max_compute_workgroup_size_z                    = raw_limits.maxComputeWorkgroupSizeZ,
        max_compute_workgroups_per_dimension            = raw_limits.maxComputeWorkgroupsPerDimension,
    }

    return
}

wgpu_conv_to_buffer_usage_flags :: #force_inline proc "contextless" (
    usages: Buffer_Usages,
) -> (ret: wgpu.BufferUsageFlags) {
    if .Map_Read in usages { ret += { .MapRead }}
    if .Map_Write in usages { ret += { .MapWrite }}
    if .Copy_Src in usages { ret += { .CopySrc }}
    if .Copy_Dst in usages { ret += { .CopyDst }}
    if .Index in usages { ret += { .Index }}
    if .Vertex in usages { ret += { .Vertex }}
    if .Uniform in usages { ret += { .Uniform }}
    if .Storage in usages { ret += { .Storage }}
    if .Indirect in usages { ret += { .Indirect }}
    if .Query_Resolve in usages { ret += { .QueryResolve }}
    return
}

wgpu_conv_from_buffer_usage_flags :: #force_inline proc "contextless" (
    usages: wgpu.BufferUsageFlags,
) -> (ret: Buffer_Usages) {
    if .MapRead in usages { ret += { .Map_Read }}
    if .MapWrite in usages { ret += { .Map_Write }}
    if .CopySrc in usages { ret += { .Copy_Src }}
    if .CopyDst in usages { ret += { .Copy_Dst }}
    if .Index in usages { ret += { .Index }}
    if .Vertex in usages { ret += { .Vertex }}
    if .Uniform in usages { ret += { .Uniform }}
    if .Storage in usages { ret += { .Storage }}
    if .Indirect in usages { ret += { .Indirect }}
    if .QueryResolve in usages { ret += { .Query_Resolve }}
    return
}

wgpu_conv_to_origin_3d :: #force_inline proc "contextless" (origin: Origin_3D) -> wgpu.Origin3D {
    return { origin.x, origin.y, origin.z }
}

wgpu_conv_to_texture_aspect :: #force_inline proc "contextless" (aspect: Texture_Aspect) -> wgpu.TextureAspect {
    #partial switch aspect {
    case .All: return .All
    case .Stencil_Only: return .StencilOnly
    case .Depth_Only: return .DepthOnly
    case:
        return .Undefined
    }
}

wgpu_conv_to_shader_stage_flags :: #force_inline proc "contextless" (
    stages: Shader_Stages,
) -> (ret: wgpu.ShaderStageFlags) {
    if .Vertex in stages { ret += { .Vertex }}
    if .Fragment in stages { ret += { .Fragment }}
    if .Compute in stages { ret += { .Compute }}
    return
}

@(rodata)
WGPU_CONV_TO_TEXTURE_FORMAT_LUT := [Texture_Format]wgpu.TextureFormat {
    .Undefined              = .Undefined,

    // Normal 8 bit formats
    .R8_Unorm               = .R8Unorm,
    .R8_Snorm               = .R8Snorm,
    .R8_Uint                = .R8Uint,
    .R8_Sint                = .R8Sint,

    // Normal 16 bit formats
    .R16_Uint               = .R16Uint,
    .R16_Sint               = .R16Sint,
    .R16_Unorm              = .R16Unorm,
    .R16_Snorm              = .R16Snorm,
    .R16_Float              = .R16Float,
    .Rg8_Unorm              = .RG8Unorm,
    .Rg8_Snorm              = .RG8Snorm,
    .Rg8_Uint               = .RG8Uint,
    .Rg8_Sint               = .RG8Sint,

    // Normal 32 bit formats
    .R32_Uint               = .R32Uint,
    .R32_Sint               = .R32Sint,
    .R32_Float              = .R32Float,
    .Rg16_Uint              = .RG16Uint,
    .Rg16_Sint              = .RG16Sint,
    .Rg16_Unorm             = .Rg16Unorm,
    .Rg16_Snorm             = .Rg16Snorm,
    .Rg16_Float             = .RG16Float,
    .Rgba8_Unorm            = .RGBA8Unorm,
    .Rgba8_Unorm_Srgb       = .RGBA8UnormSrgb,
    .Rgba8_Snorm            = .RGBA8Snorm,
    .Rgba8_Uint             = .RGBA8Uint,
    .Rgba8_Sint             = .RGBA8Sint,
    .Bgra8_Unorm            = .BGRA8Unorm,
    .Bgra8_Unorm_Srgb       = .BGRA8UnormSrgb,

    // Packed 32 bit formats
    .Rgb9e5_Ufloat          = .RGB9E5Ufloat,
    .Rgb10a2_Uint           = .RGB10A2Uint,
    .Rgb10a2_Unorm          = .RGB10A2Unorm,
    .Rg11b10_Ufloat         = .RG11B10Ufloat,

    // Normal 64 bit formats
    .R64_Uint               = .Undefined,
    .Rg32_Uint              = .RG32Uint,
    .Rg32_Sint              = .RG32Sint,
    .Rg32_Float             = .RG32Float,
    .Rgba16_Uint            = .RGBA16Uint,
    .Rgba16_Sint            = .RGBA16Sint,
    .Rgba16_Unorm           = .Rgba16Unorm,
    .Rgba16_Snorm           = .Rgba16Snorm,
    .Rgba16_Float           = .RGBA16Float,

    // Normal 128 bit formats
    .Rgba32_Uint            = .RGBA32Uint,
    .Rgba32_Sint            = .RGBA32Sint,
    .Rgba32_Float           = .RGBA32Float,

    // Depth and stencil formats
    .Stencil8               = .Stencil8,
    .Depth16_Unorm          = .Depth16Unorm,
    .Depth24_Plus           = .Depth24Plus,
    .Depth24_Plus_Stencil8  = .Depth24PlusStencil8,
    .Depth32_Float          = .Depth32Float,
    .Depth32_Float_Stencil8 = .Depth32FloatStencil8,

    /// YUV 4:2:0 chroma subsampled format.
    .NV12                   = .NV12,

    /// YUV 4:2:0 chroma subsampled format.
    .P010                   = .P010,

    // BC Compressed textures
    .Bc1_Rgba_Unorm         = .BC1RGBAUnorm,
    .Bc1_Rgba_Unorm_Srgb    = .BC1RGBAUnormSrgb,
    .Bc2_Rgba_Unorm         = .BC2RGBAUnorm,
    .Bc2_Rgba_Unorm_Srgb    = .BC2RGBAUnormSrgb,
    .Bc3_Rgba_Unorm         = .BC3RGBAUnorm,
    .Bc3_Rgba_Unorm_Srgb    = .BC3RGBAUnormSrgb,
    .Bc4_R_Unorm            = .BC4RUnorm,
    .Bc4_R_Snorm            = .BC4RSnorm,
    .Bc5_Rg_Unorm           = .BC5RGUnorm,
    .Bc5_Rg_Snorm           = .BC5RGSnorm,
    .Bc6_hRgb_Ufloat        = .BC6HRGBUfloat,
    .Bc6_hRgb_Float         = .BC6HRGBFloat,
    .Bc7_Rgba_Unorm         = .BC7RGBAUnorm,
    .Bc7_Rgba_Unorm_Srgb    = .BC7RGBAUnormSrgb,

    // ETC Compressed textures
    .Etc2_Rgb8_Unorm        = .ETC2RGB8Unorm,
    .Etc2_Rgb8_Unorm_Srgb   = .ETC2RGB8UnormSrgb,
    .Etc2_Rgb8A1_Unorm      = .ETC2RGB8A1Unorm,
    .Etc2_Rgb8A1_Unorm_Srgb = .ETC2RGB8A1UnormSrgb,
    .Etc2_Rgba8_Unorm       = .ETC2RGBA8Unorm,
    .Etc2_Rgba8_Unorm_Srgb  = .ETC2RGBA8UnormSrgb,
    .Eac_R11_Unorm          = .EACR11Unorm,
    .Eac_R11_Snorm          = .EACR11Snorm,
    .Eac_Rg11_Unorm         = .EACRG11Unorm,
    .Eac_Rg11_Snorm         = .EACRG11Snorm,

    // ASTC Compressed textures
    .Astc_4x4_Unorm         = .ASTC4x4Unorm,
    .Astc_4x4_Unorm_Srgb    = .ASTC4x4UnormSrgb,
    .Astc_4x4_Unorm_Hdr     = .Undefined,
    .Astc_5x4_Unorm         = .ASTC5x4Unorm,
    .Astc_5x4_Unorm_Srgb    = .ASTC5x4UnormSrgb,
    .Astc_5x4_Unorm_Hdr     = .Undefined,
    .Astc_5x5_Unorm         = .ASTC5x5Unorm,
    .Astc_5x5_Unorm_Srgb    = .ASTC5x5UnormSrgb,
    .Astc_5x5_Unorm_Hdr     = .Undefined,
    .Astc_6x5_Unorm         = .ASTC6x5Unorm,
    .Astc_6x5_Unorm_Srgb    = .ASTC6x5UnormSrgb,
    .Astc_6x5_Unorm_Hdr     = .Undefined,
    .Astc_6x6_Unorm         = .ASTC6x6Unorm,
    .Astc_6x6_Unorm_Srgb    = .ASTC6x6UnormSrgb,
    .Astc_6x6_Unorm_Hdr     = .Undefined,
    .Astc_8x5_Unorm         = .ASTC8x5Unorm,
    .Astc_8x5_Unorm_Srgb    = .ASTC8x5UnormSrgb,
    .Astc_8x5_Unorm_Hdr     = .Undefined,
    .Astc_8x6_Unorm         = .ASTC8x6Unorm,
    .Astc_8x6_Unorm_Srgb    = .ASTC8x6UnormSrgb,
    .Astc_8x6_Unorm_Hdr     = .Undefined,
    .Astc_8x8_Unorm         = .ASTC8x8Unorm,
    .Astc_8x8_Unorm_Srgb    = .ASTC8x8UnormSrgb,
    .Astc_8x8_Unorm_Hdr     = .Undefined,
    .Astc_10x5_Unorm        = .ASTC10x5Unorm,
    .Astc_10x5_Unorm_Srgb   = .ASTC10x5UnormSrgb,
    .Astc_10x5_Unorm_Hdr    = .Undefined,
    .Astc_10x6_Unorm        = .ASTC10x6Unorm,
    .Astc_10x6_Unorm_Srgb   = .ASTC10x6UnormSrgb,
    .Astc_10x6_Unorm_Hdr    = .Undefined,
    .Astc_10x8_Unorm        = .ASTC10x8Unorm,
    .Astc_10x8_Unorm_Srgb   = .ASTC10x8UnormSrgb,
    .Astc_10x8_Unorm_Hdr    = .Undefined,
    .Astc_10x10_Unorm       = .ASTC10x10Unorm,
    .Astc_10x10_Unorm_Srgb  = .ASTC10x10UnormSrgb,
    .Astc_10x10_Unorm_Hdr   = .Undefined,
    .Astc_12x10_Unorm       = .ASTC12x10Unorm,
    .Astc_12x10_Unorm_Srgb  = .ASTC12x10UnormSrgb,
    .Astc_12x10_Unorm_Hdr   = .Undefined,
    .Astc_12x12_Unorm       = .ASTC12x12Unorm,
    .Astc_12x12_Unorm_Srgb  = .ASTC12x12UnormSrgb,
    .Astc_12x12_Unorm_Hdr   = .Undefined,
}

wgpu_conv_from_texture_format :: proc(format: wgpu.TextureFormat) -> Texture_Format {
    switch format {
    case .Undefined: return .Undefined

    // Normal 8 bit formats
    case .R8Unorm: return .R8_Unorm
    case .R8Snorm: return .R8_Snorm
    case .R8Uint: return .R8_Uint
    case .R8Sint: return .R8_Sint

    // Normal 16 bit formats
    case .R16Uint: return .R16_Uint
    case .R16Sint: return .R16_Sint
    case .R16Unorm: return .R16_Unorm
    case .R16Snorm: return .R16_Snorm
    case .R16Float: return .R16_Float
    case .RG8Unorm: return .Rg8_Unorm
    case .RG8Snorm: return .Rg8_Snorm
    case .RG8Uint: return .Rg8_Uint
    case .RG8Sint: return .Rg8_Sint

    // Normal 32 bit formats
    case .R32Uint: return .R32_Uint
    case .R32Sint: return .R32_Sint
    case .R32Float: return .R32_Float
    case .RG16Uint: return .Rg16_Uint
    case .RG16Sint: return .Rg16_Sint
    case .Rg16Unorm: return .Rg16_Unorm
    case .Rg16Snorm: return .Rg16_Snorm
    case .RG16Float: return .Rg16_Float
    case .RGBA8Unorm: return .Rgba8_Unorm
    case .RGBA8UnormSrgb: return .Rgba8_Unorm_Srgb
    case .RGBA8Snorm: return .Rgba8_Snorm
    case .RGBA8Uint: return .Rgba8_Uint
    case .RGBA8Sint: return .Rgba8_Sint
    case .BGRA8Unorm: return .Bgra8_Unorm
    case .BGRA8UnormSrgb: return .Bgra8_Unorm_Srgb

    // Packed 32 bit formats
    case .RGB9E5Ufloat: return .Rgb9e5_Ufloat
    case .RGB10A2Uint: return .Rgb10a2_Uint
    case .RGB10A2Unorm: return .Rgb10a2_Unorm
    case .RG11B10Ufloat: return .Rg11b10_Ufloat

    // Normal 64 bit formats
    // case .R64Uint: return .R64_Uint
    case .RG32Uint: return .Rg32_Uint
    case .RG32Sint: return .Rg32_Sint
    case .RG32Float: return .Rg32_Float
    case .RGBA16Uint: return .Rgba16_Uint
    case .RGBA16Sint: return .Rgba16_Sint
    case .Rgba16Unorm: return .Rgba16_Unorm
    case .Rgba16Snorm: return .Rgba16_Snorm
    case .RGBA16Float: return .Rgba16_Float

    // Normal 128 bit formats
    case .RGBA32Uint: return .Rgba32_Uint
    case .RGBA32Sint: return .Rgba32_Sint
    case .RGBA32Float: return .Rgba32_Float

    // Depth and stencil formats
    case .Stencil8: return .Stencil8
    case .Depth16Unorm: return .Depth16_Unorm
    case .Depth24Plus: return .Depth24_Plus
    case .Depth24PlusStencil8: return .Depth24_Plus_Stencil8
    case .Depth32Float: return .Depth32_Float
    case .Depth32FloatStencil8: return .Depth32_Float_Stencil8

    /// YUV 4:2:0 chroma subsampled format.
    case .NV12: return .NV12

    /// YUV 4:2:0 chroma subsampled format.
    case .P010: return .P010

    // BC Compressed textures
    case .BC1RGBAUnorm: return .Bc1_Rgba_Unorm
    case .BC1RGBAUnormSrgb: return .Bc1_Rgba_Unorm_Srgb
    case .BC2RGBAUnorm: return .Bc2_Rgba_Unorm
    case .BC2RGBAUnormSrgb: return .Bc2_Rgba_Unorm_Srgb
    case .BC3RGBAUnorm: return .Bc3_Rgba_Unorm
    case .BC3RGBAUnormSrgb: return .Bc3_Rgba_Unorm_Srgb
    case .BC4RUnorm: return .Bc4_R_Unorm
    case .BC4RSnorm: return .Bc4_R_Snorm
    case .BC5RGUnorm: return .Bc5_Rg_Unorm
    case .BC5RGSnorm: return .Bc5_Rg_Snorm
    case .BC6HRGBUfloat: return .Bc6_hRgb_Ufloat
    case .BC6HRGBFloat: return .Bc6_hRgb_Float
    case .BC7RGBAUnorm: return .Bc7_Rgba_Unorm
    case .BC7RGBAUnormSrgb: return .Bc7_Rgba_Unorm_Srgb

    // ETC Compressed textures
    case .ETC2RGB8Unorm: return .Etc2_Rgb8_Unorm
    case .ETC2RGB8UnormSrgb: return .Etc2_Rgb8_Unorm_Srgb
    case .ETC2RGB8A1Unorm: return .Etc2_Rgb8A1_Unorm
    case .ETC2RGB8A1UnormSrgb: return .Etc2_Rgb8A1_Unorm_Srgb
    case .ETC2RGBA8Unorm: return .Etc2_Rgba8_Unorm
    case .ETC2RGBA8UnormSrgb: return .Etc2_Rgba8_Unorm_Srgb
    case .EACR11Unorm: return .Eac_R11_Unorm
    case .EACR11Snorm: return .Eac_R11_Snorm
    case .EACRG11Unorm: return .Eac_Rg11_Unorm
    case .EACRG11Snorm: return .Eac_Rg11_Snorm

    // ASTC Compressed textures
    case .ASTC4x4Unorm: return .Astc_4x4_Unorm
    case .ASTC4x4UnormSrgb: return .Astc_4x4_Unorm_Srgb
    // case .Astc_4x4_Unorm_Hdr: return .Astc_4x4_Unorm_Hdr
    case .ASTC5x4Unorm: return .Astc_5x4_Unorm
    case .ASTC5x4UnormSrgb: return .Astc_5x4_Unorm_Srgb
    // case .Astc_5x4_Unorm_Hdr: return .Astc_5x4_Unorm_Hdr
    case .ASTC5x5Unorm: return .Astc_5x5_Unorm
    case .ASTC5x5UnormSrgb: return .Astc_5x5_Unorm_Srgb
    // case .Astc_5x5_Unorm_Hdr: return .Astc_5x5_Unorm_Hdr
    case .ASTC6x5Unorm: return .Astc_6x5_Unorm
    case .ASTC6x5UnormSrgb: return .Astc_6x5_Unorm_Srgb
    // case .Astc_6x5_Unorm_Hdr: return .Astc_6x5_Unorm_Hdr
    case .ASTC6x6Unorm: return .Astc_6x6_Unorm
    case .ASTC6x6UnormSrgb: return .Astc_6x6_Unorm_Srgb
    // case .Astc_6x6_Unorm_Hdr: return .Astc_6x6_Unorm_Hdr
    case .ASTC8x5Unorm: return .Astc_8x5_Unorm
    case .ASTC8x5UnormSrgb: return .Astc_8x5_Unorm_Srgb
    // case .Astc_8x5_Unorm_Hdr: return .Astc_8x5_Unorm_Hdr
    case .ASTC8x6Unorm: return .Astc_8x6_Unorm
    case .ASTC8x6UnormSrgb: return .Astc_8x6_Unorm_Srgb
    // case .Astc_8x6_Unorm_Hdr: return .Astc_8x6_Unorm_Hdr
    case .ASTC8x8Unorm: return .Astc_8x8_Unorm
    case .ASTC8x8UnormSrgb: return .Astc_8x8_Unorm_Srgb
    // case .Astc_8x8_Unorm_Hdr: return .Astc_8x8_Unorm_Hdr
    case .ASTC10x5Unorm: return .Astc_10x5_Unorm
    case .ASTC10x5UnormSrgb: return .Astc_10x5_Unorm_Srgb
    // case .Astc_10x5_Unorm_Hdr: return .Astc_10x5_Unorm_Hdr
    case .ASTC10x6Unorm: return .Astc_10x6_Unorm
    case .ASTC10x6UnormSrgb: return .Astc_10x6_Unorm_Srgb
    // case .Astc_10x6_Unorm_Hdr: return .Astc_10x6_Unorm_Hdr
    case .ASTC10x8Unorm: return .Astc_10x8_Unorm
    case .ASTC10x8UnormSrgb: return .Astc_10x8_Unorm_Srgb
    // case .Astc_10x8_Unorm_Hdr: return .Astc_10x8_Unorm_Hdr
    case .ASTC10x10Unorm: return .Astc_10x10_Unorm
    case .ASTC10x10UnormSrgb: return .Astc_10x10_Unorm_Srgb
    // case .Astc_10x10_Unorm_Hdr: return .Astc_10x10_Unorm_Hdr
    case .ASTC12x10Unorm: return .Astc_12x10_Unorm
    case .ASTC12x10UnormSrgb: return .Astc_12x10_Unorm_Srgb
    // case .Astc_12x10_Unorm_Hdr: return .Astc_12x10_Unorm_Hdr
    case .ASTC12x12Unorm: return .Astc_12x12_Unorm
    case .ASTC12x12UnormSrgb: return .Astc_12x12_Unorm_Srgb
    // case .Astc_12x12_Unorm_Hdr: return .Astc_12x12_Unorm_Hdr
    }
    unreachable()
}

wgpu_conv_to_texture_usage_flags :: #force_inline proc "contextless" (
    usages: Texture_Usages,
) -> (ret: wgpu.TextureUsageFlags) {
    if .Copy_Src in usages {
        ret += { .CopySrc }
    }
    if .Copy_Dst in usages {
        ret += { .CopyDst }
    }
    if .Texture_Binding in usages {
        ret += { .TextureBinding }
    }
    if .Storage_Binding in usages {
        ret += { .StorageBinding }
    }
    if .Render_Attachment in usages {
        ret += { .RenderAttachment }
    }
    return
}

wgpu_conv_from_texture_usage_flags :: #force_inline proc "contextless" (
    usages: wgpu.TextureUsageFlags,
) -> (ret: Texture_Usages) {
    if .CopySrc in usages {
        ret += { .Copy_Src }
    }
    if .CopyDst in usages {
        ret += { .Copy_Dst }
    }
    if .TextureBinding in usages {
        ret += { .Texture_Binding }
    }
    if .StorageBinding in usages {
        ret += { .Storage_Binding }
    }
    if .RenderAttachment in usages {
        ret += { .Render_Attachment }
    }
    return
}

wgpu_conv_to_vertex_format :: #force_inline proc "contextless" (
    format: Vertex_Format,
    loc := #caller_location,
) -> wgpu.VertexFormat {
    switch format {
    case .Uint8:           return .Uint8
    case .Uint8x2:         return .Uint8x2
    case .Uint8x4:         return .Uint8x4
    case .Sint8:           return .Sint8
    case .Sint8x2:         return .Sint8x2
    case .Sint8x4:         return .Sint8x4
    case .Unorm8:          return .Unorm8
    case .Unorm8x2:        return .Unorm8x2
    case .Unorm8x4:        return .Unorm8x4
    case .Snorm8:          return .Snorm8
    case .Snorm8x2:        return .Snorm8x2
    case .Snorm8x4:        return .Snorm8x4
    case .Uint16:          return .Uint16
    case .Uint16x2:        return .Uint16x2
    case .Uint16x4:        return .Uint16x4
    case .Sint16:          return .Sint16
    case .Sint16x2:        return .Sint16x2
    case .Sint16x4:        return .Sint16x4
    case .Unorm16:         return .Unorm16
    case .Unorm16x2:       return .Unorm16x2
    case .Unorm16x4:       return .Unorm16x4
    case .Snorm16:         return .Snorm16
    case .Snorm16x2:       return .Snorm16x2
    case .Snorm16x4:       return .Snorm16x4
    case .Float16:         return .Float16
    case .Float16x2:       return .Float16x2
    case .Float16x4:       return .Float16x4
    case .Float32:         return .Float32
    case .Float32x2:       return .Float32x2
    case .Float32x3:       return .Float32x3
    case .Float32x4:       return .Float32x4
    case .Uint32:          return .Uint32
    case .Uint32x2:        return .Uint32x2
    case .Uint32x3:        return .Uint32x3
    case .Uint32x4:        return .Uint32x4
    case .Sint32:          return .Sint32
    case .Sint32x2:        return .Sint32x2
    case .Sint32x3:        return .Sint32x3
    case .Sint32x4:        return .Sint32x4
    case .Unorm10_10_10_2: return .Unorm10_10_10_2
    case .Unorm8x4Bgra:    return .Unorm8x4BGRA

    case .Float64, .Float64x2, .Float64x3, .Float64x4:
        panic_contextless("WebGPU: Flaot64 format not supported", loc)
    }

    unreachable()
}

wgpu_conv_to_color_write_mask :: #force_inline proc "contextless" (
    writes: Color_Writes,
) -> (ret: wgpu.ColorWriteMaskFlags) {
    if .Red in writes { ret += { .Red } }
    if .Green in writes { ret += { .Green } }
    if .Blue in writes { ret += { .Blue } }
    if .Alpha in writes { ret += { .Alpha } }
    return
}
