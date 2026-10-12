#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 20 0
layout(location = 0)
in vec2 input_position_0;



struct VSOutput_0
{
    vec4 position_0;
};


void main()
{
    VSOutput_0 output_0;
    output_0.position_0 = vec4(input_position_0, 0.0, 1.0);

#line 34
    gl_Position = output_0.position_0;

#line 34
    return;
}

