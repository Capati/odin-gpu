package gpu

// Features that are not guaranteed to be supported.
//
// These are either part of the webgpu standard, or are extension features
// supported by wgpu when targeting native.
//
// If you want to use a feature, you need to first verify that the adapter
// supports the feature. If the adapter does not support the feature, requesting
// a device with it enabled will panic.
Features :: bit_set[Feature; u128]
Feature :: enum i32 {
    // Webgpu
    Depth_Clip_Control,
    Depth32_Float_Stencil8,
    Texture_Compression_Bc,
    Texture_Compression_Bc_Sliced_3D,
    Texture_Compression_Etc2,
    Texture_Compression_Astc,
    Texture_Compression_Astc_Sliced_3D,
    Timestamp_Query,
    Indirect_First_Instance,
    Shader_F16,
    Rg11B10_Ufloat_Renderable,
    Bgra8_Unorm_Storage,
    Float32_Filterable,
    Float32_Blendable,
    Clip_Distances,
    Dual_Source_Blending,
    // Subgroups,
    // Texture_Formats_Tier1,
    // Texture_Formats_Tier2,
    // Primitive_Index,
    // Texture_Component_Swizzle,

    // Native
    Shader_Float32_Atomic,
    Texture_Format_16Bit_Norm,
    Texture_Compression_Astc_Hdr,
    Texture_Adapter_Specific_Format_Features,
    Pipeline_Statistics_Query,
    Timestamp_Query_Inside_Encoders,
    Timestamp_Query_Inside_Passes,
    Mappable_Primary_Buffers,
    Texture_Binding_Array,
    Buffer_Binding_Array,
    Storage_Resource_Binding_Array,
    Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
    Storage_Texture_Array_Non_Uniform_Indexing,
    Partially_Bound_Binding_Array,
    Multi_Draw_Indirect_Count,
    Push_Constants,
    Address_Mode_Clamp_To_Zero,
    Address_Mode_Clamp_To_Border,
    Polygon_Mode_Line,
    Polygon_Mode_Point,
    Conservative_Rasterization,
    Vertex_Writable_Storage,
    Clear_Texture,
    Multiview,
    Vertex_Attribute_64Bit,
    Texture_Atomic,
    Texture_Format_Nv12,
    Texture_Format_P010,
    External_Texture,
    Experimental_Ray_Query,
    Shader_F64,
    Shader_I16,
    Shader_Primitive_Index,
    Shader_Early_Depth_Test,
    Shader_Int64,
    Subgroup,
    Subgroup_Vertex,
    Subgroup_Barrier,
    Pipeline_Cache,
    Shader_Int64_Atomic_Min_Max,
    Shader_Int64_Atomic_All_Ops,
    Vulkan_Google_Display_Timing,
    Vulkan_External_Memory_Win32,
    Texture_Int64_Atomic,
    Uniform_Buffer_Binding_Arrays,
    Experimental_Mesh_Shader,
    Experimental_Ray_Hit_Vertex_Return,
    Experimental_Mesh_Shader_Multiview,
    Extended_Acceleration_Structure_Vertex_Formats,
    Experimental_Passthrough_Shaders,
}

MAX_FEATURES :: len(Feature)
