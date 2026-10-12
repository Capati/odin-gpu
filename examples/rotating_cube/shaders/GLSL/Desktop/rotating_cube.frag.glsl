#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 37 0
layout(binding = 1)
uniform sampler2D myTexture_0;


#line 1092 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 1092
layout(location = 0)
in vec2 input_frag_uv_0;


#line 1092
layout(location = 1)
in vec4 input_frag_position_0;


#line 50 0
void main()
{

#line 50
    entryPointParam_fs_main_0 = (texture((myTexture_0), (input_frag_uv_0))) * input_frag_position_0;

#line 50
    return;
}

