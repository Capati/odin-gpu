#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 17 0
struct Camera_0
{
    mat4x4 projection_0;
    mat4x4 view_0;
    vec3 position_0;
    float time_0;
};


#line 42
layout(binding = 0)
layout(std140) uniform block_Camera_0
{
    mat4x4 projection_0;
    mat4x4 view_0;
    vec3 position_0;
    float time_0;
}camera_0;

#line 3112 1
layout(location = 0)
out vec2 entryPointParam_vs_main_uv_0;


#line 3112
layout(location = 0)
in vec3 input_position_0;


#line 3112
layout(location = 1)
in vec2 input_uv_0;


#line 36 0
struct VertexOutput_0
{
    vec4 position_1;
    vec2 uv_0;
};


#line 48
void main()
{

#line 49
    VertexOutput_0 output_0;
    output_0.position_1 = (((vec4(input_position_0, 1.0)) * ((((camera_0.view_0) * (camera_0.projection_0))))));
    output_0.uv_0 = input_uv_0;
    VertexOutput_0 _S1 = output_0;

#line 52
    gl_Position = output_0.position_1;

#line 52
    entryPointParam_vs_main_uv_0 = _S1.uv_0;

#line 52
    return;
}

