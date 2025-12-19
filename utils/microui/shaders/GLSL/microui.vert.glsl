#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
struct Uniforms_natural_0
{
    mat4x4 transform_0;
};


#line 18
layout(binding = 0)
layout(std140) uniform block_Uniforms_natural_0
{
    mat4x4 transform_0;
}uniforms_0;

#line 5
layout(location = 0)
out vec2 entryPointParam_vs_main_uv_0;


#line 5
layout(location = 1)
out vec4 entryPointParam_vs_main_color_0;


#line 5
layout(location = 0)
in vec2 input_position_0;


#line 5
layout(location = 1)
in vec2 input_uv_0;


#line 5
layout(location = 2)
in vec4 input_color_0;




struct VertexOutput_0
{
    vec4 position_0;
    vec2 uv_0;
    vec4 color_0;
};




void main()
{

#line 22
    VertexOutput_0 output_0;
    output_0.position_0 = (((vec4(input_position_0, 0.0, 1.0)) * (uniforms_0.transform_0)));
    output_0.uv_0 = input_uv_0;
    output_0.color_0 = input_color_0;
    VertexOutput_0 _S1 = output_0;

#line 26
    gl_Position = output_0.position_0;

#line 26
    entryPointParam_vs_main_uv_0 = _S1.uv_0;

#line 26
    entryPointParam_vs_main_color_0 = _S1.color_0;

#line 26
    return;
}

