#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
layout(location = 0)
out vec4 entryPointParam_vs_main_color_0;


#line 2
layout(location = 0)
in vec3 input_position_0;


#line 2
layout(location = 1)
in vec4 input_color_0;




struct VertexOutput_0
{
    vec4 position_0;
    vec4 color_0;
};


void main()
{
    VertexOutput_0 output_0;
    output_0.color_0 = input_color_0;
    output_0.position_0 = vec4(input_position_0, 1.0);
    VertexOutput_0 _S1 = output_0;

#line 20
    gl_Position = output_0.position_0;

#line 20
    entryPointParam_vs_main_color_0 = _S1.color_0;

#line 20
    return;
}

