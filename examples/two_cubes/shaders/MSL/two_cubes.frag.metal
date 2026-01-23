#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 1 "examples/07_two_cubes/shaders/two_cubes.slang"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 1
struct pixelInput_0
{
    float2 tex_coords_0 [[user(TEXCOORD)]];
    float4 color_0 [[user(COLOR)]];
};


#line 26
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]])
{

#line 26
    pixelOutput_0 _S2 = { _S1.color_0 };
    return _S2;
}

