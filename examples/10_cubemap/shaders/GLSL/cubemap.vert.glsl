#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
struct Uniforms_natural_0
{
    mat4x4 modelViewProjectionMatrix_0;
};


#line 17
layout(binding = 0)
layout(std140) uniform block_Uniforms_natural_0
{
    mat4x4 modelViewProjectionMatrix_0;
}uniforms_0;

#line 5
layout(location = 0)
out vec2 entryPointParam_vs_main_fragUV_0;


#line 5
layout(location = 1)
out vec4 entryPointParam_vs_main_fragPosition_0;


#line 5
layout(location = 0)
in vec4 input_position_0;


#line 5
layout(location = 1)
in vec2 input_uv_0;



struct VertexOutput_0
{
    vec4 position_0;
    vec2 fragUV_0;
    vec4 fragPosition_0;
};




void main()
{

#line 21
    VertexOutput_0 output_0;
    output_0.position_0 = (((input_position_0) * (uniforms_0.modelViewProjectionMatrix_0)));
    output_0.fragUV_0 = input_uv_0;
    output_0.fragPosition_0 = 0.5 * (input_position_0 + vec4(1.0, 1.0, 1.0, 1.0));
    VertexOutput_0 _S1 = output_0;

#line 25
    gl_Position = output_0.position_0;

#line 25
    entryPointParam_vs_main_fragUV_0 = _S1.fragUV_0;

#line 25
    entryPointParam_vs_main_fragPosition_0 = _S1.fragPosition_0;

#line 25
    return;
}

