#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
struct Uniforms_0
{
    mat4x4 transform_0;
    vec2 uv_scale_0;
    vec2 _pad_0;
};


#line 19
layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4 transform_0;
    vec2 uv_scale_0;
    vec2 _pad_0;
}uniforms_0;

#line 39
layout(binding = 1)
uniform sampler2D r_color_0;


#line 11763 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 11763
layout(location = 0)
in vec2 input_tex_coord_0;


#line 11763
layout(location = 1)
in vec4 input_frag_position_0;


#line 52 0
void main()
{



    const vec2 _S1 = vec2(0.5, 0.5);



    vec4 texColor_0 = (texture((r_color_0), ((input_tex_coord_0 - _S1) * uniforms_0.uv_scale_0 * 0.80000001192092896 + _S1)));

#line 61
    float f_0;

#line 67
    if((length(texColor_0.xyz - vec3(0.5, 0.5, 0.5))) < 0.00999999977648258)
    {

#line 67
        f_0 = 0.0;

#line 67
    }
    else
    {

#line 67
        f_0 = 1.0;

#line 67
    }

#line 67
    entryPointParam_fs_main_0 = f_0 * texColor_0 + (1.0 - f_0) * input_frag_position_0;

#line 67
    return;
}

