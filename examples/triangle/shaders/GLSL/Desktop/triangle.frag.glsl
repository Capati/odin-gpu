#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 8 0
layout(location = 0)
out vec4 entryPointParam_fs_main_color_0;


#line 8
layout(location = 0)
in vec4 input_color_0;


#line 24
struct FragmentOutput_0
{
    vec4 color_0;
};


void main()
{
    FragmentOutput_0 output_0;
    output_0.color_0 = input_color_0;

#line 33
    entryPointParam_fs_main_color_0 = output_0.color_0;

#line 33
    return;
}

