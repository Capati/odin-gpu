#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 9 0
struct SLANG_ParameterGroup_Uniforms_natural_0
{
    mat4x4 modelViewProjectionMatrix_0;
};


#line 8
layout(binding = 0)
layout(std140) uniform block_SLANG_ParameterGroup_Uniforms_natural_0
{
    mat4x4 modelViewProjectionMatrix_0;
}Uniforms_0;
layout(location = 0)
out vec2 entryPointParam_vs_main_tex_coords_0;


#line 13
layout(location = 1)
out vec4 entryPointParam_vs_main_color_0;


#line 13
layout(location = 0)
in vec4 position_0;


#line 13
layout(location = 1)
in vec4 color_0;


#line 13
layout(location = 2)
in vec2 uv_0;


#line 1
struct VertexOut_0
{
    vec4 position_1;
    vec2 tex_coords_0;
    vec4 color_1;
};


#line 13
void main()
{



    VertexOut_0 output_0;
    output_0.position_1 = (((position_0) * (Uniforms_0.modelViewProjectionMatrix_0)));
    output_0.tex_coords_0 = uv_0;
    output_0.color_1 = color_0;
    VertexOut_0 _S1 = output_0;

#line 22
    gl_Position = output_0.position_1;

#line 22
    entryPointParam_vs_main_tex_coords_0 = _S1.tex_coords_0;

#line 22
    entryPointParam_vs_main_color_0 = _S1.color_1;

#line 22
    return;
}

