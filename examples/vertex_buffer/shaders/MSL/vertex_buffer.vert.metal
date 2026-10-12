#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 7 "examples/vertex_buffer/vertex_buffer.slang"
struct vs_main_Result_0
{
    float4 pos_0 [[position]];
    float color_0 [[user(COLOR)]];
};


#line 1
struct vertexInput_0
{
    float2 pos_1 [[attribute(0)]];
    float color_1 [[attribute(1)]];
};

struct VSOutput_0
{
    float4 pos_2;
    float color_2;
};


#line 7
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]])
{

#line 16
    thread VSOutput_0 output_0;
    (&output_0)->pos_2 = float4(_S1.pos_1, 0.0, 1.0);
    (&output_0)->color_2 = _S1.color_1;

#line 18
    thread vs_main_Result_0 _S2;

#line 18
    (&_S2)->pos_0 = output_0.pos_2;

#line 18
    (&_S2)->color_0 = output_0.color_2;

#line 18
    return _S2;
}

