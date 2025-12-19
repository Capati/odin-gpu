#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 36 0
layout(binding = 1)
uniform texture2D r_color_texture_0;

layout(binding = 2)
uniform sampler r_color_sampler_0;


#line 1882 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 1882
layout(location = 0)
in vec2 input_uv_0;


#line 1882
layout(location = 1)
in vec4 input_color_0;


#line 42 0
void main()
{

#line 42
    entryPointParam_fs_main_0 = (texture(sampler2D(r_color_texture_0,r_color_sampler_0), (input_uv_0))) * input_color_0;

#line 42
    return;
}

