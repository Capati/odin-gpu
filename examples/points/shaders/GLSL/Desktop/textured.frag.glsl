#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 10 0
layout(binding = 2)
uniform texture2D t_0;


#line 7
layout(binding = 1)
uniform sampler s_0;


#line 2251 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 2251
layout(location = 0)
in vec2 vsOut_texcoord_0;


#line 13 0
void main()
{
    vec4 color_0 = (texture(sampler2D(t_0,s_0), (vsOut_texcoord_0)));
    if((color_0.w) < 0.10000000149011612)
    {
        discard;

#line 16
    }

#line 16
    entryPointParam_fs_main_0 = color_0;

#line 16
    return;
}

