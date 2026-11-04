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
    //
    // This is a web and native feature.
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

    // Allows subgroup operations in compute and fragment shaders.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    //
    // This is a web and native feature.
    Subgroups,
    // Tier 1 texture format capabilities.
    Texture_Formats_Tier1,
    // Tier 2 texture format capabilities.
    Texture_Formats_Tier2,
    // Allows `builtin(primitive_index)` in fragment shaders.
    //
    // Note: enables geometry processing for pipelines using the builtin. This
    // may come with a significant performance impact on some hardware. Other
    // pipelines are not affected.
    //
    // Supported platforms:
    //
    // - Vulkan (with `geometryShader`)
    // - DX12
    // - Metal (some)
    // - OpenGL (some)
    //
    // This is a web and native feature.
    Primitive_Index,
    // Allows component swizzle on texture views.
    Texture_Component_Swizzle,
    // Allows controlling the subgroup size used by shaders.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_subgroup_size_control`)
    //
    // This is a native only feature.
    Subgroup_Size_Control,

    // Native
    // Allows the use of immediate data: small, fast blocks of memory that can
    // be updated inside a render pass, compute pass, or render bundle encoder.
    //
    // Enables `render_pass_encoder.set_immediates`,
    // `compute_pass_encoder.set_immediates`,
    // `render_bundle_encoder.set_immediates`, non-zero `immediate_size` in
    // `Pipeline_Layout`, and non-zero `max_immediate_size` in `Limits`.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    // - Metal
    // - OpenGL (emulated with uniforms)
    // - WebGPU
    //
    // This is a web and native feature.
    Immediates,
    // Enables device-specific texture format features.
    //
    // By default only texture format properties defined by the WebGPU
    // specification are allowed. This feature extends each format to the
    // properties supported by the current device. Without it, read/write
    // storage access is not allowed at all.
    //
    // This feature does not enable additional formats.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Texture_Adapter_Specific_Format_Features,
    // Allows `multi_draw_indirect_count` and
    // `multi_draw_indexed_indirect_count`, which read the actual number of draw
    // calls from a buffer.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan 1.2+ (or `VK_KHR_draw_indirect_count`)
    //
    // This is a native only feature.
    Multi_Draw_Indirect_Count,
    // Enables bindings of writable storage buffers and textures visible to
    // vertex shaders.
    //
    // Note: some tile-based platforms do not support vertex shaders with side
    // effects.
    //
    // Supported platforms:
    //
    // - All
    //
    // This is a native only feature.
    Vertex_Writable_Storage,
    // Allows creating uniform arrays of textures in shaders, indexed by
    // dynamically uniform values.
    //
    // If `Storage_Resource_Binding_Array` is supported as well, storage texture
    // arrays are also allowed.
    //
    // Supported platforms:
    //
    // - DX12
    // - Metal (MSL 2.0+ on macOS 10.13+)
    // - Vulkan
    //
    // This is a native only feature.
    Texture_Binding_Array,
    // Allows shaders to index sampled texture and storage buffer resource
    // arrays with dynamically non-uniform values.
    //
    // Supported platforms:
    //
    // - DX12
    // - Metal (MSL 2.0+ on macOS 10.13+)
    // - Vulkan 1.2+ (or `VK_EXT_descriptor_indexing`)
    //
    // This is a native only feature.
    Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
    // Enables use of pipeline statistics queries, which count operations
    // performed between the start and stop call.
    //
    // They must be resolved into a buffer.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    //
    // This is a native only feature with a proposal for the web.
    Pipeline_Statistics_Query,
    // Allows creating uniform arrays of storage buffers or textures in
    // shaders, if `Buffer_Binding_Array` or `Texture_Binding_Array` is
    // supported respectively.
    //
    // Supported platforms:
    //
    // - Metal (MSL 2.2+ on macOS 10.13+)
    // - Vulkan
    //
    // This is a native only feature.
    Storage_Resource_Binding_Array,
    // Allows bind groups containing arrays with fewer bindings than the
    // `Bind_Group_Layout`.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    //
    // This is a native only feature.
    Partially_Bound_Binding_Array,
    // Enables normalized 16-bit texture formats.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    // - OpenGL (desktop GL 3.3+ for UNORM; GLES/WebGL2 requires
    //   `EXT_texture_norm16`. SNORM color-attachment usage additionally
    //   requires `EXT_render_snorm`.)
    //
    // This is a native only feature.
    Texture_Format_16Bit_Norm,
    // Enables the ASTC HDR family of compressed textures.
    //
    // Support guarantees `Copy_Src`, `Copy_Dst`, and `Texture_Binding` for ASTC
    // formats with the HDR channel type.
    // `Texture_Adapter_Specific_Format_Features` may enable additional usages.
    //
    // Supported platforms:
    //
    // - Metal
    // - Vulkan
    // - OpenGL
    //
    // This is a native only feature.
    Texture_Compression_Astc_Hdr,
    // Removes the WebGPU restriction tying `Map_Read`/`Map_Write` buffer usages
    // to `Copy_Dst`/`Copy_Src` respectively.
    //
    // This is only beneficial when CPU and GPU share memory. Enabling it on
    // other systems can severely hinder performance.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Mappable_Primary_Buffers,
    // Allows creating arrays of uniform buffers in shaders, indexed by
    // dynamically uniform values.
    //
    // If `Storage_Resource_Binding_Array` is supported as well, storage buffer
    // arrays are also allowed.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Buffer_Binding_Array,
    // Allows shaders to index storage texture resource arrays with dynamically
    // non-uniform values.
    //
    // Supported platforms:
    //
    // - DX12
    // - Metal (MSL 2.0+ on macOS 10.13+)
    // - Vulkan 1.2+ (or `VK_EXT_descriptor_indexing`)
    //
    // This is a native only feature.
    Storage_Texture_Array_Non_Uniform_Indexing,
    // Allows `Clamp_To_Border` address mode with a border color of zero.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    // - Metal
    // - OpenGL
    //
    // This is a native only feature.
    Address_Mode_Clamp_To_Zero,
    // Allows `Clamp_To_Border` address mode with a border color other than
    // zero.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    // - Metal (macOS 10.12+)
    // - OpenGL
    //
    // This is a native only feature.
    Address_Mode_Clamp_To_Border,
    // Allows the line polygon mode: drawing triangles as lines (wireframe)
    // instead of filled.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    // - Metal
    //
    // This is a native only feature.
    Polygon_Mode_Line,
    // Allows the point polygon mode: drawing only the vertices of triangles
    // instead of filled.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Polygon_Mode_Point,
    // Allows overestimation-conservative rasterization.
    //
    // Processing of degenerate triangles/lines is hardware-specific. Only
    // triangles are supported.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Conservative_Rasterization,
    // Enables clearing textures to zero.
    //
    // Supported platforms:
    //
    // - All
    //
    // This is a native only feature.
    Clear_Texture,
    // Enables multiview render passes and `builtin(view_index)` in
    // vertex/mesh shaders.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - Metal
    // - DX12
    // - OpenGL (web only)
    //
    // This is a native only feature.
    Multiview,
    // Enables using 64-bit types for vertex attributes.
    //
    // Requires `Shader_F64`.
    //
    // This is a native only feature.
    Vertex_Attribute64Bit,
    // Allows creation of textures with format `NV12`.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    //
    // This is a native only feature.
    Texture_Format_Nv12,
    // Allows ray-tracing queries within shaders.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Ray_Query,
    // Enables 64-bit floating point types in shaders.
    //
    // Note: even when supported by hardware, 64-bit operations are frequently
    // 16 to 64 times slower than 32-bit ones.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Shader_F64,
    // Allows shaders to use `i16` and `u16` 16-bit integer types.
    //
    // Requires the WGSL 16-bit integer extension to be enabled in shaders.
    //
    // Supported platforms:
    //
    // - Vulkan (with `shaderInt16` and `VK_KHR_16bit_storage`)
    // - Metal (always available)
    // - DX12 (with `Native16BitShaderOpsSupported`, SM 6.2+)
    //
    // This is a native only feature.
    Shader_I16,
    // Allows shaders to use the `early_depth_test` attribute on the fragment
    // entry point: force early depth/stencil tests, or provide a conservative
    // depth specifier.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - GLES 3.1+
    //
    // This is a native only feature.
    Shader_Early_Depth_Test,
    // Allows compute and fragment shaders to use subgroup built-ins and
    // perform subgroup operations (except barriers).
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Subgroup,
    // Allows vertex shaders to use subgroup built-ins and perform subgroup
    // operations (except barriers).
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // This is a native only feature.
    Subgroup_Vertex,
    // Allows compute shaders to use the subgroup barrier.
    //
    // Requires `Subgroup`. Without it, enables nothing.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - Metal
    //
    // This is a native only feature.
    Subgroup_Barrier,
    // Allows timestamp queries directly on command encoders.
    //
    // Adapters that support this feature also support `Timestamp_Query`. Both
    // must be requested explicitly to use timestamp queries on command
    // encoders.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal (AMD and Intel, not Apple GPUs)
    // - OpenGL (with `GL_ARB_timer_query`)
    //
    // This is a native only feature.
    Timestamp_Query_Inside_Encoders,
    // Allows timestamp queries directly inside render and compute passes.
    //
    // Requires `Timestamp_Query` and `Timestamp_Query_Inside_Encoders`.
    //
    // This is generally not available on tile-based rasterization GPUs.
    //
    // This is a native only feature with a proposal for the web.
    Timestamp_Query_Inside_Passes,
    // Allows shaders to use `i64` and `u64` types.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12 (DXC only)
    // - Metal (MSL 2.3+)
    //
    // This is a native only feature.
    Shader_Int64,
    // Allows shaders to use f32 atomic load, store, add, sub, and exchange.
    //
    // Supported platforms:
    //
    // - Metal (MSL 3.0+ on Apple7+/Mac2)
    // - Vulkan (with `VK_EXT_shader_atomic_float`)
    //
    // This is a native only feature.
    Shader_Float32_Atomic,
    // Enables image atomic fetch add, and, xor, or, min, and max for `R32Uint`
    // and `R32Sint` textures.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    // - Metal (MSL 3.1+)
    //
    // This is a native only feature.
    Texture_Atomic,
    // Allows creation of textures with format `P010`.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    //
    // This is a native only feature.
    Texture_Format_P010,
    // Allows the use of pipeline cache objects.
    //
    // Supported platforms:
    //
    // - Vulkan
    //
    // Unimplemented platforms:
    //
    // - DX12
    // - Metal
    Pipeline_Cache,
    // Allows shaders to use i64 and u64 atomic min and max.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_shader_atomic_int64`)
    // - DX12 (SM 6.6+)
    // - Metal (MSL 2.4+)
    //
    // This is a native only feature.
    Shader_Int64_Atomic_Min_Max,
    // Allows shaders to use all i64 and u64 atomic operations.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_shader_atomic_int64`)
    // - DX12 (SM 6.6+)
    //
    // This is a native only feature.
    Shader_Int64_Atomic_All_Ops,
    // Enables `R64Uint` image atomic min and max.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_shader_image_atomic_int64`)
    // - DX12 (SM 6.6+)
    // - Metal (MSL 3.1+)
    //
    // This is a native only feature.
    Texture_Int64_Atomic,
    // Allows uniform buffers to be bound as binding arrays: shaders may use
    // `binding_array<UniformBuffer>`, and layout entries may set `count`.
    //
    // Supported platforms:
    //
    // - None yet.
    //
    // Potential platforms:
    //
    // - DX12
    // - Metal
    // - Vulkan 1.2+ (or `VK_EXT_descriptor_indexing`)
    //
    // This is a native only feature.
    Uniform_Buffer_Binding_Arrays,
    // Enables shader barycentric coordinates.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_fragment_shader_barycentric`)
    // - DX12 (SM 6.1+)
    // - Metal (MSL 2.2+)
    //
    // This is a native only feature.
    Shader_Barycentrics,
    // Allows multiview where not all texture array layers are rendered to in a
    // single pass. Requires `Multiview`.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    //
    // Metal supports this in theory, but `view_index` differs, so the feature
    // is not exposed.
    Selective_Multiview,
    // Enables creating texture arrays that are also multisampled.
    //
    // Without this, a texture cannot have both `sample_count` above 1 and
    // `depth_or_array_layers` above 1.
    //
    // Supported platforms:
    //
    // - Vulkan (except `VK_KHR_portability_subset` without
    //   `multisampleArrayImage`)
    // - Metal (macOS 10.14+, iOS 14.0+, tvOS 16.0+, visionOS 1.0+)
    Multisample_Array,
    // Enables cooperative matrix operations: a workgroup collectively loads,
    // stores, and multiply-accumulates small tiles.
    //
    // Current limitation: only 8x8 f32 matrices.
    //
    // Supported platforms:
    //
    // - Metal (MSL 2.3+ on Apple7+/Mac2+)
    // - Vulkan (with `VK_KHR_cooperative_matrix`, if 8x8 f32 is supported)
    //
    // This is a native only feature.
    Cooperative_Matrix,
    // Enables shader per-vertex attributes.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_fragment_shader_barycentric`)
    //
    // This is a native only feature.
    Shader_Per_Vertex,
    // Enables the shader `draw_index` builtin.
    //
    // Supported platforms:
    //
    // - GLES
    // - Vulkan
    //
    // Potential platforms:
    //
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Shader_Draw_Index,
    // Allows creating arrays of acceleration structures in shaders
    // (`binding_array<acceleration_structure, N>`), indexed by dynamically
    // uniform values.
    //
    // Supported platforms:
    //
    // - DX12
    // - Vulkan
    //
    // This is a native only feature.
    Acceleration_Structure_Binding_Array,
    // Enables the `@coherent` memory decoration on storage buffers.
    //
    // Supported backends:
    //
    // - Vulkan
    // - DX12
    // - Metal (3.2+)
    // - GLES (ES 3.1+ / GL 4.3+)
    //
    // This is a native only feature.
    Memory_Decoration_Coherent,
    // Enables the `@volatile` memory decoration on storage buffers.
    //
    // Supported backends:
    //
    // - Vulkan
    // - GLES (ES 3.1+ / GL 4.3+)
    //
    // This is a native only feature.
    Memory_Decoration_Volatile,
    // Allows constructing ray tracing pipelines.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_ray_tracing_pipeline`)
    //
    // This is a native only feature.
    Ray_Tracing_Pipelines,
    // Allows returning the hit triangle's vertex position when tracing with an
    // acceleration structure marked to allow it.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_ray_tracing_position_fetch`)
    //
    // This is a native only feature.
    Ray_Hit_Vertex_Return,
    // Allows using additional vertex formats in bottom-level acceleration
    // structure triangle geometry descriptors.
    //
    // Supported platforms:
    //
    // - Vulkan
    // - DX12
    //
    // This is a native only feature.
    Extended_Acceleration_Structure_Vertex_Formats,
    // Enables mesh shaders and task shaders in mesh shader pipelines.
    //
    // This does not imply support for compiling mesh shaders at runtime.
    // Prefer trusted shader creation with runtime checks off to avoid expensive
    // workgroup-memory zero initialization.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_mesh_shader`)
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Mesh_Shader,
    // Enables point-primitive outputs from mesh shaders.
    //
    // Requires `Mesh_Shader`.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_mesh_shader`)
    // - Metal
    //
    // This is a native only feature.
    Mesh_Shader_Points,
    // Enables multiview in mesh shader pipelines.
    //
    // Requires `Mesh_Shader`.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_mesh_shader`)
    //
    // Potential platforms:
    //
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    Mesh_Shader_Multiview,
    // Allows the creation and use of external textures, and bind group
    // layouts containing external texture bindings.
    //
    // Supported platforms:
    //
    // - DX12
    // - Metal
    //
    // This is a native only feature.
    External_Texture,
    // Allows importing DMA-buf textures on Linux.
    //
    // Requires `VK_EXT_image_drm_format_modifier` for specifying the DRM
    // format modifier and plane layout during import.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_EXT_external_memory_dma_buf` and
    //   `VK_EXT_image_drm_format_modifier`)
    //
    // This is a native only feature.
    Vulkan_External_Memory_Dma_Buf,
    // Allows importing memory using POSIX file descriptors.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_external_memory_fd`)
    //
    // This is a native only feature.
    Vulkan_External_Memory_Fd,
    // Allows importing memory exported by Windows.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_KHR_external_memory_win32`)
    //
    // This is a native only feature.
    Vulkan_External_Memory_Win32,
    // Allows using `VK_GOOGLE_display_timing`.
    //
    // This is used for frame pacing to reduce latency, and is generally only
    // available on Android.
    //
    // Supported platforms:
    //
    // - Vulkan (with `VK_GOOGLE_display_timing`)
    //
    // This is a native only feature.
    Vulkan_Google_Display_Timing,
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
