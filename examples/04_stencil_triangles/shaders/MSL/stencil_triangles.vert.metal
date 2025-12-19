#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 6 "examples/04_stencil_triangles/shaders/stencil_triangles.slang"
struct vs_main_Result_0
{
    float4 position_0 [[position]];
};


#line 6
struct vertexInput_0
{
    float4 position_1 [[attribute(0)]];
};


#line 1
struct VertexOutput_0
{
    float4 position_2;
};


#line 1
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]])
{

#line 7
    thread VertexOutput_0 result_0;
    (&result_0)->position_2 = _S1.position_1;

#line 8
    thread vs_main_Result_0 _S2;

#line 8
    (&_S2)->position_0 = result_0.position_2;

#line 8
    return _S2;
}

