#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 23 "examples/vertex_buffer/vertex_buffer.slang"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 23
struct pixelInput_0
{
    float color_0 [[user(COLOR)]];
};


#line 23
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]])
{

#line 23
    pixelOutput_0 _S2 = { float4(_S1.color_0, _S1.color_0, abs(_S1.color_0), 1.0) };

    return _S2;
}

