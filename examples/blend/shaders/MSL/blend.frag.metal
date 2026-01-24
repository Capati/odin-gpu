#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 24 "examples/blend/shaders/blend.slang"
struct FragmentOutput_0
{
    float4 color_0 [[color(0)]];
};


#line 24
struct pixelInput_0
{
    float4 color_1 [[user(COLOR)]];
};


[[fragment]] FragmentOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]])
{
    thread FragmentOutput_0 output_0;
    (&output_0)->color_0 = _S1.color_1;
    return output_0;
}

