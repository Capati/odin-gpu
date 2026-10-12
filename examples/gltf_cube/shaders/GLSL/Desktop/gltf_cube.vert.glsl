#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
layout(binding = 0)
layout(std140) uniform block_S1_0
{
    mat4x4 _data;
} mvp_0;

#line 4
layout(location = 0)
out vec3 entryPointParam_vs_main_normal_0;


#line 4
layout(location = 0)
in vec3 input_position_0;


#line 4
layout(location = 1)
in vec3 input_normal_0;



struct VertexOutput_0
{
    vec4 position_0;
    vec3 normal_0;
};

void main()
{

#line 16
    VertexOutput_0 output_0;
    output_0.position_0 = (((vec4(input_position_0, 1.0)) * (mvp_0._data)));
    output_0.normal_0 = input_normal_0;
    VertexOutput_0 _S2 = output_0;

#line 19
    gl_Position = output_0.position_0;

#line 19
    entryPointParam_vs_main_normal_0 = _S2.normal_0;

#line 19
    return;
}

