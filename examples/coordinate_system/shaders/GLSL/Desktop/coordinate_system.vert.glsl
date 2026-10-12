#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
layout(location = 0)
out vec2 entryPointParam_vs_main_uv_0;


#line 1
layout(location = 0)
in vec3 input_pos_0;


#line 1
layout(location = 1)
in vec2 input_uv_0;




struct VSOutput_0
{
    vec4 position_0;
    vec2 uv_0;
};


#line 17
void main()
{
    VSOutput_0 output_0;
    output_0.uv_0 = input_uv_0;
    output_0.position_0 = vec4(input_pos_0, 1.0);
    VSOutput_0 _S1 = output_0;

#line 22
    gl_Position = output_0.position_0;

#line 22
    entryPointParam_vs_main_uv_0 = _S1.uv_0;

#line 22
    return;
}

