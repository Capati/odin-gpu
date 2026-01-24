#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 2 "examples/blend/shaders/blend.slang"
struct vs_main_Result_0
{
    float4 position_0 [[position]];
    float4 color_0 [[user(COLOR)]];
};


#line 2
struct vertexInput_0
{
    float4 position_1 [[attribute(0)]];
    float4 color_1 [[attribute(1)]];
};

struct VertexOutput_0
{
    float4 position_2;
    float4 color_2;
};


#line 8
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]])
{

#line 17
    thread VertexOutput_0 output_0;
    (&output_0)->color_2 = _S1.color_1;
    (&output_0)->position_2 = _S1.position_1;

#line 19
    thread vs_main_Result_0 _S2;

#line 19
    (&_S2)->position_0 = output_0.position_2;

#line 19
    (&_S2)->color_0 = output_0.color_2;

#line 19
    return _S2;
}

