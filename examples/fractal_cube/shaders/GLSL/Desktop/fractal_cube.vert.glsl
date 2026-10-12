#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
struct Uniforms_0
{
    mat4x4 transform_0;
    vec2 uv_scale_0;
    vec2 _pad_0;
};


#line 19
layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4 transform_0;
    vec2 uv_scale_0;
    vec2 _pad_0;
}uniforms_0;

#line 13092 1
layout(location = 0)
out vec2 entryPointParam_vs_main_tex_coord_0;


#line 13092
layout(location = 1)
out vec4 entryPointParam_vs_main_frag_position_0;


#line 13092
layout(location = 0)
in vec4 input_position_0;


#line 13092
layout(location = 1)
in vec2 input_tex_coord_0;


#line 12 0
struct VertexOutput_0
{
    vec4 position_0;
    vec2 tex_coord_0;
    vec4 frag_position_0;
};




void main()
{

#line 23
    VertexOutput_0 output_0;
    output_0.position_0 = (((input_position_0) * (uniforms_0.transform_0)));
    output_0.tex_coord_0 = input_tex_coord_0;
    output_0.frag_position_0 = 0.5 * (input_position_0 + vec4(1.0, 1.0, 1.0, 1.0));
    VertexOutput_0 _S1 = output_0;

#line 27
    gl_Position = output_0.position_0;

#line 27
    entryPointParam_vs_main_tex_coord_0 = _S1.tex_coord_0;

#line 27
    entryPointParam_vs_main_frag_position_0 = _S1.frag_position_0;

#line 27
    return;
}

