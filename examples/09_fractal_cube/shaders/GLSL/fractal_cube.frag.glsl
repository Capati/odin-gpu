#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 37 0
layout(binding = 1)
uniform sampler2D r_color_0;


#line 11009 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 11009
layout(location = 0)
in vec2 input_tex_coord_0;


#line 11009
layout(location = 1)
in vec4 input_frag_position_0;


#line 50 0
void main()
{


    vec4 texColor_0 = (texture((r_color_0), (input_tex_coord_0 * 0.80000001192092896 + vec2(0.10000000149011612, 0.10000000149011612))));

#line 54
    float f_0;

#line 60
    if((length(texColor_0.xyz - vec3(0.5, 0.5, 0.5))) < 0.00999999977648258)
    {

#line 60
        f_0 = 0.0;

#line 60
    }
    else
    {

#line 60
        f_0 = 1.0;

#line 60
    }

#line 60
    entryPointParam_fs_main_0 = f_0 * texColor_0 + (1.0 - f_0) * input_frag_position_0;

#line 60
    return;
}

