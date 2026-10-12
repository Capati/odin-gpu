package gpu

// Features that are not guaranteed to be supported.
//
// These are either part of the webgpu standard, or are extension features
// supported by the implementation when targeting native.
//
// If you want to use a feature, you need to first verify that the adapter
// supports the feature. If the adapter does not support the feature, requesting
// a device with it enabled will panic.
//
// Corresponds to [WebGPU `GPUFeatureName`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpufeaturename).
Feature_Name :: enum i32 {
    // By default, polygon depth is clipped to 0-1 range before/during
    // rasterization. Anything outside of that range is rejected, and
    // respective fragments are not touched.
    //
    // With this extension, we can disabling clipping. That allows shadow map
    // occluders to be rendered into a tighter depth range.
    //
    // Supported platforms:
    //
    // - desktops
    // - some mobile chips
    // - WebGPU
    //
    // This is a web and native feature.
    Depth_Clip_Control,

    // Allows for explicit creation of textures of format
    // `Depth32_Float_Stencil8`
    //
    // Supported platforms:
    //
    // - Vulkan (mostly)
    // - DX12
    // - Metal
    // - OpenGL
    // - WebGPU
    //
    // This is a web and native feature.
    Depth32_Float_Stencil8,

    // Enables BCn family of compressed textures. All BCn textures use 4x4 pixel
    // blocks with 8 or 16 bytes per block.
    //
    // Compressed textures sacrifice some quality in exchange for significantly
    // reduced bandwidth usage.
    //
    // Support for this feature guarantees availability of texture usages
    // `{.Copy_Src, .Copy_Dst, .Texture_Binding}` for BCn formats.
    // `Texture_Adapter_Specific_Format_Features` feature may enable
    // additional usages.
    //
    // This feature guarantees availability of sliced-3d textures for BC formats
    // when combined with `Texture_Compression_BC_Sliced_3D`.
    //
    // Supported Platforms:
    //
    // - desktops
    // - Mobile (All Apple9 and some Apple7 and Apple8 devices)
    // - WebGPU
    //
    // This is a web and native feature.
    Texture_Compression_BC,

    // Allows the 3d dimension for textures with BC compressed formats.
    //
    // This feature must be used in combination with `Texture_Compression_BC` to
    // enable 3D textures with BC compression. It does not enable the BC formats
    // by itself.
    //
    // Supported Platforms:
    //
    // - desktops
    // - Mobile (All Apple9 and some Apple7 and Apple8 devices)
    // - WebGPU
    //
    // This is a web and native feature.
    Texture_Compression_BC_Sliced_3D,

    // Enables ETC family of compressed textures. All ETC textures use 4x4 pixel
    // blocks. ETC2 RGB and RGBA1 are 8 bytes per block. RTC2 RGBA8 and EAC are
    // 16 bytes per block.
    //
    // Compressed textures sacrifice some quality in exchange for significantly
    // reduced bandwidth usage.
    //
    // Support for this feature guarantees availability of texture usages
    // `Copy_Src`, `Copy_Dst` and `Texture_Binding` for ETC2 formats.
    // `Texture_Adapter_Specific_Format_Features` feature may enable additional
    // usages.
    //
    // Supported Platforms:
    //
    // - Vulkan on Intel
    // - Mobile (some)
    // - WebGPU
    //
    // This is a web and native feature.
    Texture_Compression_ETC2,

    // Enables ASTC family of compressed textures. ASTC textures use pixel
    // blocks varying from 4x4 to 12x12. Blocks are always 16 bytes.
    //
    // Compressed textures sacrifice some quality in exchange for significantly
    // reduced bandwidth usage.
    //
    // Support for this feature guarantees availability of texture usages
    // `Copy_Src`, `Copy_Dst` and `Texture_Binding` for ASTC formats with
    // Unorm/Unorm_Srgb channel type. `Texture_Adapter_Specific_Format_Features`
    // feature may enable additional usages.
    //
    // This feature does not guarantee availability of sliced 3d textures for
    // ASTC formats. If available, 3d support can be enabled by
    // `Texture_Compression_ASTC_Sliced_3D` feature.
    //
    // Supported Platforms:
    //
    // - Vulkan on Intel
    // - Mobile (some)
    // - WebGPU
    //
    // This is a web and native feature.
    Texture_Compression_ASTC,

    // Allows the 3d dimension for textures with ASTC compressed formats.
    //
    // This feature must be used in combination with `Texture_Compression_ASTC` to
    // enable 3D textures with ASTC compression. It does not enable the ASTC
    // formats by itself.
    //
    // Supported Platforms:
    //
    // - Vulkan (some)
    // - Metal on Apple3+
    // - OpenGL/WebGL (some)
    // - WebGPU
    //
    // Not Supported:
    //
    // - DX12
    //
    // This is a web and native feature.
    Texture_Compression_ASTC_Sliced_3D,

    // Enables use of Timestamp Queries. These queries tell the current gpu
    // timestamp when all work before the query is finished.
    //
    // This feature allows the use of
    // - `Render_Pass_Descriptor.timestamp_writes`
    // - `Compute_Pass_Descriptor.timestamp_writes` to write out timestamps.
    //
    // For arbitrary timestamp write commands on encoders refer to
    // `Timestamp_Query_Inside_Encoders` feature. For arbitrary timestamp write
    // commands on passes refer to `Timestamp_Query_Inside_Passes` feature.
    //
    // They must be resolved using `command_encoder_resolve_query_set` into a
    // buffer, then the result must be multiplied by the timestamp period
    // `queue_get_timestamp_period` to get the timestamp in nanoseconds.
    // Multiple timestamps can then be diffed to get the time for operations
    // between them to finish.
    //
    // Supported Platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    // - OpenGL (with GL_ARB_timer_query)
    // - WebGPU
    //
    // This is a web and native feature.
    Timestamp_Query,

    // Allows non-zero value for the `first_instance` member in indirect draw
    // calls.
    //
    // If this feature is not enabled, and the `first_instance` member is
    // non-zero, the behavior may be:
    //
    // - The draw call is ignored.
    // - The draw call is executed as if the `first_instance` is zero.
    // - The draw call is executed with the correct `first_instance` value.
    //
    // Supported Platforms:
    //
    // - Vulkan (mostly)
    // - DX12
    // - Metal on Apple3+ or Mac1+
    // - OpenGL (Desktop 4.2+ with ARB_shader_draw_parameters only)
    // - WebGPU
    //
    // Not Supported:
    //
    // - OpenGL ES / WebGL
    //
    // This is a web and native feature.
    Indirect_First_Instance,

    // Allows shaders to use 16-bit floating point types. You may use them
    // uniform buffers, storage buffers, and local variables. You may not use
    // them in immediates.
    //
    // In order to use this in WGSL shaders, you must add `enable f16;` to the
    // top of your shader, before any global items.
    //
    // Supported Platforms:
    //
    // - Vulkan
    // - Metal
    // - DX12
    // - WebGPU
    //
    // This is a web and native feature.
    Shader_F16,

    // Allows for usage of textures of format `RG11B10_Ufloat`
    // as a render target
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    // - WebGPU
    //
    // This is a web and native feature.
    RG11B10_Ufloat_Renderable,

    // Allows the texture usages `Storage_Binding` usage on textures with
    // format `BGRA8_Unorm`.
    //
    // Supported Platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    // - WebGPU
    //
    // This is a web and native feature.
    BGRA8_Unorm_Storage,

    // Allows textures with formats "r32float", "rg32float", and "rgba32float"
    // to be filterable.
    //
    // Supported Platforms:
    //
    // - Vulkan (mainly on Desktop GPUs)
    // - DX12
    // - Metal on macOS or Apple9+ GPUs, optional on iOS/iPadOS with Apple7/8
    //   GPUs
    // - GL with one of
    //   `GL_ARB_color_buffer_float`/`GL_EXT_color_buffer_float`/`OES_texture_float_linear`
    // - WebGPU
    //
    // This is a web and native feature.
    Float32_Filterable,

    // Allows textures with formats "r32float", "rg32float", and "rgba32float"
    // to be blendable.
    //
    // Supported Platforms:
    //
    // - Vulkan
    // - WebGPU
    Float32_Blendable,

    // Allows the use of clip distances in shader.
    //
    // Supported platforms:
    //
    // - Vulkan (mainly on Desktop GPUs)
    // - Metal
    // - GL (Desktop or `GL_EXT_clip_cull_distance`)
    // - WebGPU
    //
    // This is a web and native feature.
    Clip_Distances,

    // Allows two outputs from a shader to be used for blending. Note that
    // dual-source blending doesn't support multiple render targets.
    //
    // For more info see the OpenGL ES extension `GL_EXT_blend_func_extended`.
    //
    // Supported platforms:
    //
    // - OpenGL ES (with `GL_EXT_blend_func_extended`)
    // - Metal (with MSL 1.2+)
    // - Vulkan (with dualSrcBlend)
    // - DX12
    // - WebGPU
    //
    // This is a web and native feature.
    Dual_Source_Blending,

    Subgroups,
    Texture_Formats_Tier1,
    Texture_Formats_Tier2,
    Primitive_Index,
    Texture_Component_Swizzle,
    Subgroup_Size_Control,

    // Native
    Immediates,
    Texture_Adapter_Specific_Format_Features,
    Multi_Draw_Indirect_Count,
    Vertex_Writable_Storage,
    Texture_Binding_Array,
    Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
    Pipeline_Statistics_Query,
    Storage_Resource_Binding_Array,
    Partially_Bound_Binding_Array,
    Texture_Format_16Bit_Norm,
    Texture_Compression_Astc_Hdr,
    Mappable_Primary_Buffers,
    Buffer_Binding_Array,
    Storage_Texture_Array_Non_Uniform_Indexing,
    Address_Mode_Clamp_To_Zero,
    Address_Mode_Clamp_To_Border,
    Polygon_Mode_Line,
    Polygon_Mode_Point,
    Conservative_Rasterization,
    Clear_Texture,
    Multiview,
    Vertex_Attribute64Bit,
    Texture_Format_Nv12,
    Ray_Query,
    Shader_F64,
    Shader_I16,
    Shader_Early_Depth_Test,
    Subgroup,
    Subgroup_Vertex,
    Subgroup_Barrier,
    Timestamp_Query_Inside_Encoders,
    Timestamp_Query_Inside_Passes,
    Shader_Int64,
    Shader_Float32_Atomic,
    Texture_Atomic,
    Texture_Format_P010,
    Pipeline_Cache,
    Shader_Int64_Atomic_Min_Max,
    Shader_Int64_Atomic_All_Ops,
    Texture_Int64_Atomic,
    Uniform_Buffer_Binding_Arrays,
    Shader_Barycentrics,
    Selective_Multiview,
    Multisample_Array,
    Cooperative_Matrix,
    Shader_Per_Vertex,
    Shader_Draw_Index,
    Acceleration_Structure_Binding_Array,
    Memory_Decoration_Coherent,
    Memory_Decoration_Volatile,
}

FEATURE_COUNT :: len(Feature_Name)

Features :: [dynamic; FEATURE_COUNT]Feature_Name

INDEXING_FEATURES :: []Feature_Name {
    .Texture_Binding_Array,
    .Buffer_Binding_Array,
    .Storage_Resource_Binding_Array,
    .Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
    .Storage_Texture_Array_Non_Uniform_Indexing,
    .Uniform_Buffer_Binding_Arrays,
    .Partially_Bound_Binding_Array,
}
