#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 34 0
layout(binding = 1)
uniform sampler2D r_color_0;


#line 977 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 977
layout(location = 0)
in vec2 input_tex_coord_0;


#line 47 0
void main()
{

#line 56
    float v_0 = (texture((r_color_0), (input_tex_coord_0))).x;

#line 56
    entryPointParam_fs_main_0 = vec4(vec3(1.0 - v_0 * 5.0, 1.0 - v_0 * 15.0, 1.0 - v_0 * 50.0), 1.0);

#line 56
    return;
}

