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

// List of possible features a backend can support.
Feature :: enum i32 {
    Undefined,

    // Webgpu
    Depth_Clip_Control,
    Depth32_Float_Stencil8,
    Timestamp_Query,
    Texture_Compression_BC,
    Texture_Compression_BC_Sliced_3D,
    Texture_Compression_ETC2,
    Texture_Compression_ASTC,
    Texture_Compression_ASTC_Sliced_3D,
    Indirect_First_Instance,
    Shader_F16,
    Rg11B10_Ufloat_Renderable,
    Bgra8_Unorm_Storage,
    Float32_Filterable,
    Float32_Blendable,
    Clip_Distances,
    Dual_Source_Blending,

    // Native
    Push_Constants,
    Texture_Adapter_Specific_Format_Features,
    Multi_Draw_Indirect_Count,
    Vertex_Writable_Storage,
    Texture_Binding_Array,
    Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
    Pipeline_Statistics_Query,
    Storage_Resource_Binding_Array,
    Partially_Bound_Binding_Array,
    Texture_Format_16Bit_Norm,
    Texture_Compression_ASTC_Hdr,
    Mappable_Primary_Buffers,
    Buffer_Binding_Array,
    Uniform_Buffer_And_Storage_Texture_Array_Non_Uniform_Indexing,
    Address_Mode_Clamp_To_Zero,
    Address_Mode_Clamp_To_Border,
    Polygon_Mode_Line,
    Polygon_Mode_Point,
    Conservative_Rasterization,
    Clear_Texture,
    Spirv_Shader_Passthrough,
    Multiview,
    Vertex_Attribute_64Bit,
    Texture_Format_Nv12,
    Texture_Format_P010,
    Ray_Query,
    Shader_F64,
    Shader_I16,
    Shader_Primitive_Index,
    Shader_Early_Depth_Test,
    Subgroup,
    Subgroup_Vertex,
    Subgroup_Barrier,
    Timestamp_Query_Inside_Encoders,
    Timestamp_Query_Inside_Passes,
    Shader_Int64,

    // Storage_Texture_Array_Non_Uniform_Indexing,
    Texture_Atomic,
    // External_Texture,
    // Pipeline_Cache,
    // Shader_Int64_Atomic_Min_Max,
    // Shader_Int64_Atomic_All_Ops,
    // Vulkan_Google_Display_Timing,
    // Vulkan_External_Memory_Win32,
    Texture_Int64_Atomic,
    // Uniform_Buffer_Binding_Arrays,
    // Extended_Acceleration_Structure_Vertex_Formats,
}

// Total number of possible features a backend can support.
MAX_FEATURES :: len(Feature)
