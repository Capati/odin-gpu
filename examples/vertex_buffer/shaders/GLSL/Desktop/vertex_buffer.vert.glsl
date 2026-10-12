#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 7 0
layout(location = 0)
out float entryPointParam_vs_main_color_0;


#line 1
layout(location = 0)
in vec2 input_pos_0;


#line 1
layout(location = 1)
in float input_color_0;




struct VSOutput_0
{
    vec4 pos_0;
    float color_0;
};


void main()
{
    VSOutput_0 output_0;
    output_0.pos_0 = vec4(input_pos_0, 0.0, 1.0);
    output_0.color_0 = input_color_0;
    VSOutput_0 _S1 = output_0;

#line 19
    gl_Position = output_0.pos_0;

#line 19
    entryPointParam_vs_main_color_0 = _S1.color_0;

#line 19
    return;
}

