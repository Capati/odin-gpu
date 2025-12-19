#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 35 0
layout(binding = 1)
uniform sampler2D r_color_0;


#line 977 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 977
layout(location = 0)
in vec2 input_uv_0;


#line 977
layout(location = 1)
in vec4 input_color_0;


#line 38 0
void main()
{

#line 38
    entryPointParam_fs_main_0 = (texture((r_color_0), (input_uv_0))) * input_color_0;

#line 38
    return;
}

