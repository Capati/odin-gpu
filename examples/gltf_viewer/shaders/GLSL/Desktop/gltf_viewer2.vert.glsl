#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 56 0
struct Model_0
{
    mat4x4 matrix_0;
    mat4x4 invTr_0;
};

layout(std430, binding = 0, set = 1) readonly buffer StructuredBuffer_Model_t_0 {
    Model_0 _data[];
} models_0;

#line 42
struct Camera_VS_0
{
    mat4x4 proj_view_0;
};

layout(binding = 0)
layout(std140) uniform block_Camera_VS_0
{
    mat4x4 proj_view_0;
}camera_vs_0;

#line 8963 1
layout(location = 0)
out vec3 entryPointParam_vs_main_normal_0;


#line 8963
layout(location = 1)
out vec3 entryPointParam_vs_main_world_pos_0;


#line 3120 2
layout(location = 2)
out vec2 entryPointParam_vs_main_uv0_0;


#line 3120
layout(location = 3)
out vec2 entryPointParam_vs_main_uv1_0;


#line 3120
layout(location = 4)
out vec3 entryPointParam_vs_main_tangent_0;


#line 3120
layout(location = 5)
out vec3 entryPointParam_vs_main_bitangent_0;


#line 3120
layout(location = 6)
out vec4 entryPointParam_vs_main_color_0;


#line 3120
layout(location = 0)
in vec3 input_position_0;


#line 3120
layout(location = 1)
in vec3 input_normal_0;


#line 3120
layout(location = 2)
in vec2 input_uv0_0;


#line 3120
layout(location = 3)
in vec2 input_uv1_0;


#line 3120
layout(location = 4)
in vec4 input_tangent_0;


#line 3120
layout(location = 5)
in vec4 input_color_0;


#line 122 0
struct VertexOutput_0
{
    vec4 position_0;
    vec3 normal_0;
    vec3 world_pos_0;
    vec2 uv0_0;
    vec2 uv1_0;
    vec3 tangent_0;
    vec3 bitangent_0;
    vec4 color_0;
};


#line 145
void main()
{
    Model_0 model_0 = models_0._data[uint(uint(gl_InstanceIndex))];

    vec4 world_position_0 = (((vec4(input_position_0, 1.0)) * (model_0.matrix_0)));

#line 146
    VertexOutput_0 output_0;



    output_0.position_0 = (((world_position_0) * (camera_vs_0.proj_view_0)));

    vec3 _S1 = normalize((((vec4(input_normal_0, 0.0)) * (model_0.invTr_0))).xyz);

#line 152
    output_0.normal_0 = _S1;
    output_0.world_pos_0 = world_position_0.xyz;
    output_0.uv0_0 = input_uv0_0;
    output_0.uv1_0 = input_uv1_0;

#line 160
    vec3 _S2 = normalize((((vec4(input_tangent_0.xyz, 0.0)) * (model_0.matrix_0))).xyz);

#line 160
    output_0.tangent_0 = _S2;
    output_0.bitangent_0 = cross(_S1, _S2) * input_tangent_0.w;

    output_0.color_0 = input_color_0;
    VertexOutput_0 _S3 = output_0;

#line 164
    gl_Position = output_0.position_0;

#line 164
    entryPointParam_vs_main_normal_0 = _S3.normal_0;

#line 164
    entryPointParam_vs_main_world_pos_0 = _S3.world_pos_0;

#line 164
    entryPointParam_vs_main_uv0_0 = _S3.uv0_0;

#line 164
    entryPointParam_vs_main_uv1_0 = _S3.uv1_0;

#line 164
    entryPointParam_vs_main_tangent_0 = _S3.tangent_0;

#line 164
    entryPointParam_vs_main_bitangent_0 = _S3.bitangent_0;

#line 164
    entryPointParam_vs_main_color_0 = _S3.color_0;

#line 164
    return;
}

