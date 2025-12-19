#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 32 0
layout(binding = 1)
uniform texture2D r_color_texture_0;

layout(binding = 2)
uniform sampler r_color_sampler_0;


#line 1882 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 1882
layout(location = 0)
in vec2 input_tex_coord_0;


#line 38 0
void main()
{
    float v_0 = (texture(sampler2D(r_color_texture_0,r_color_sampler_0), (input_tex_coord_0))).x;

#line 40
    entryPointParam_fs_main_0 = vec4(vec3(1.0 - v_0 * 5.0, 1.0 - v_0 * 15.0, 1.0 - v_0 * 50.0), 1.0);

#line 40
    return;
}

