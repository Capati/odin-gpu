#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
struct Uniforms_0
{
    mat4x4  modelViewProjectionMatrix_0[16];
};

layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4  modelViewProjectionMatrix_0[16];
}uniforms_0;



layout(location = 0)
out vec2 entryPointParam_vs_main_frag_uv_0;


#line 14
layout(location = 1)
out vec4 entryPointParam_vs_main_frag_position_0;


#line 14
layout(location = 0)
in vec4 input_position_0;


#line 14
layout(location = 1)
in vec2 input_uv_0;



struct VertexOutput_0
{
    vec4 position_0;
    vec2 frag_uv_0;
    vec4 frag_position_0;
};

void main()
{

#line 27
    VertexOutput_0 output_0;
    output_0.position_0 = (((input_position_0) * (uniforms_0.modelViewProjectionMatrix_0[uint(gl_InstanceIndex)])));
    output_0.frag_uv_0 = input_uv_0;
    output_0.frag_position_0 = 0.5 * (input_position_0 + vec4(1.0));
    VertexOutput_0 _S1 = output_0;

#line 31
    gl_Position = output_0.position_0;

#line 31
    entryPointParam_vs_main_frag_uv_0 = _S1.frag_uv_0;

#line 31
    entryPointParam_vs_main_frag_position_0 = _S1.frag_position_0;

#line 31
    return;
}

