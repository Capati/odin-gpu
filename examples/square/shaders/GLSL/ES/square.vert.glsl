#version 300 es

layout(location = 0) in vec3 input_position;
layout(location = 1) in vec4 input_color;
out vec4 input_color_1;

void main()
{
    gl_Position = vec4(input_position, 1.0);
    input_color_1 = input_color;
}

