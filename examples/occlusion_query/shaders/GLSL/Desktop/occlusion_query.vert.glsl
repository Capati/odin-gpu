#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 6 0
struct Uniforms_0
{
    mat4x4 world_view_projection_0;
    mat4x4 world_0;
    vec4 color_0;
};

struct SLANG_ParameterGroup_uniforms_0
{
    Uniforms_0 u_0;
};


#line 13
layout(binding = 0)
layout(std140) uniform block_SLANG_ParameterGroup_uniforms_0
{
    Uniforms_0 u_0;
}uniforms_0;

#line 13092 1
layout(location = 0)
out vec3 entryPointParam_vs_main_normal_0;


#line 13092
layout(location = 0)
in vec3 position_0;


#line 13092
layout(location = 1)
in vec3 normal_0;


#line 17 0
struct VertexOut_0
{
    vec3 normal_1;
    vec4 position_1;
};

void main()
{


    VertexOut_0 output_0;
    output_0.position_1 = (((vec4(position_0, 1.0)) * (uniforms_0.u_0.world_view_projection_0)));
    output_0.normal_1 = (((normal_0) * (mat3x3(uniforms_0.u_0.world_0[0].xyz, uniforms_0.u_0.world_0[1].xyz, uniforms_0.u_0.world_0[2].xyz))));
    VertexOut_0 _S1 = output_0;

#line 30
    entryPointParam_vs_main_normal_0 = output_0.normal_1;

#line 30
    gl_Position = _S1.position_1;

#line 30
    return;
}

