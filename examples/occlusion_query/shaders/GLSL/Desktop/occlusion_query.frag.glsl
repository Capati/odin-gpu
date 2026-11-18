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

#line 14019 1
float saturate_0(float x_0)
{

#line 14027
    return clamp(x_0, 0.0, 1.0);
}


#line 14027
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 14027
layout(location = 0)
in vec3 input_normal_0;


#line 34 0
void main()
{

#line 34
    entryPointParam_fs_main_0 = vec4(uniforms_0.u_0.color_0.xyz * saturate_0(dot(normalize(input_normal_0), normalize(vec3(4.0, 10.0, 6.0))) * 0.5 + 0.5), uniforms_0.u_0.color_0.w);

#line 34
    return;
}

