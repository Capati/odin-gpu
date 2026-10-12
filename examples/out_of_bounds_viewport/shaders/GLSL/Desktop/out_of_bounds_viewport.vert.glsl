#version 460
#extension GL_ARB_shader_draw_parameters : require
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
struct Viewport_0
{
    float x_0;
    float y_0;
    float w_0;
    float h_0;
};


layout(binding = 0)
layout(std140) uniform block_Viewport_0
{
    float x_0;
    float y_0;
    float w_0;
    float h_0;
}viewport_0;

#line 29
const vec2  kUV_0[6] = { vec2(1.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, 0.0) };

#line 24
const vec2  kPos_0[6] = { vec2(1.0, 1.0), vec2(1.0, -1.0), vec2(-1.0, -1.0), vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(-1.0, 1.0) };

#line 18
layout(location = 0)
out vec2 entryPointParam_vs_main_fragUV_0;


#line 18
struct VertexOutput_0
{
    vec4 position_0;
    vec2 fragUV_0;
};


#line 41
void main()
{

#line 41
    uint _S1 = uint(gl_VertexIndex - gl_BaseVertex);

    vec4 _S2 = vec4(kPos_0[_S1], 0.0, 1.0);

#line 43
    vec4 position_1 = _S2;

    position_1[0] = _S2.x * viewport_0.w_0 + (viewport_0.x_0 + viewport_0.w_0 - 1.0 + viewport_0.x_0) * _S2.w;

    position_1[1] = position_1.y * viewport_0.h_0 + (viewport_0.y_0 + viewport_0.h_0 - 1.0 + viewport_0.y_0) * position_1.w;


    VertexOutput_0 output_0;
    output_0.position_0 = position_1;
    output_0.fragUV_0 = kUV_0[_S1];
    VertexOutput_0 _S3 = output_0;

#line 53
    gl_Position = output_0.position_0;

#line 53
    entryPointParam_vs_main_fragUV_0 = _S3.fragUV_0;

#line 53
    return;
}

