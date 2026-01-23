#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
struct Uniforms_natural_0
{
    mat4x4 transform_0;
};


#line 16
layout(binding = 0)
layout(std140) uniform block_Uniforms_natural_0
{
    mat4x4 transform_0;
}uniforms_0;

#line 5
layout(location = 0)
out vec2 entryPointParam_vs_main_tex_coord_0;


#line 5
layout(location = 0)
in vec4 input_position_0;


#line 5
layout(location = 1)
in vec2 input_tex_coord_0;



struct VertexOutput_0
{
    vec4 position_0;
    vec2 tex_coord_0;
};




void main()
{

#line 20
    VertexOutput_0 output_0;
    output_0.tex_coord_0 = input_tex_coord_0;
    output_0.position_0 = (((input_position_0) * (uniforms_0.transform_0)));
    VertexOutput_0 _S1 = output_0;

#line 23
    gl_Position = output_0.position_0;

#line 23
    entryPointParam_vs_main_tex_coord_0 = _S1.tex_coord_0;

#line 23
    return;
}

