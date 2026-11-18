#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 53 0
layout(binding = 1, set = 1)
uniform sampler2D mesh_texture_0;


#line 14034 1
vec3 saturate_0(vec3 x_0)
{

#line 14042
    return clamp(x_0, vec3(0.0), vec3(1.0));
}


#line 14042
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 14042
layout(location = 0)
in vec3 input_normal_0;


#line 14042
layout(location = 1)
in vec2 input_uv_0;


#line 66 0
void main()
{
    vec4 texel_0 = (texture((mesh_texture_0), (input_uv_0)));

#line 68
    entryPointParam_fs_main_0 = vec4(texel_0.xyz * saturate_0(vec3(0.05000000074505806, 0.05000000074505806, 0.05000000074505806) + max(dot(normalize(input_normal_0), normalize(vec3(1.0, 1.0, 1.0))), 0.0)), texel_0.w);

#line 68
    return;
}

