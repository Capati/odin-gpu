#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 8 0
struct SLANG_ParameterGroup_Uniforms_natural_0
{
    mat4x4 mvpMat_0;
};


#line 7
layout(binding = 0)
layout(std140) uniform block_SLANG_ParameterGroup_Uniforms_natural_0
{
    mat4x4 mvpMat_0;
}Uniforms_0;

#line 12220 1
layout(location = 0)
out vec4 entryPointParam_vs_main_color_0;


#line 12 0
layout(location = 0)
in vec3 position_0;


#line 12
layout(location = 1)
in vec3 color_0;


#line 1
struct VertexOut_0
{
    vec4 position_1;
    vec4 color_1;
};


#line 12
void main()
{


    VertexOut_0 output_0;
    output_0.position_1 = (((vec4(position_0, 1.0)) * (Uniforms_0.mvpMat_0)));
    output_0.color_1 = vec4(color_0, 1.0);
    VertexOut_0 _S1 = output_0;

#line 19
    gl_Position = output_0.position_1;

#line 19
    entryPointParam_vs_main_color_0 = _S1.color_1;

#line 19
    return;
}

