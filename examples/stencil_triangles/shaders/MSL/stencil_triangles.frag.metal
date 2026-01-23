#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 1 "examples/04_stencil_triangles/shaders/stencil_triangles.slang"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 13
[[fragment]] pixelOutput_0 fs_main(float4 position_0 [[position]])
{

#line 13
    pixelOutput_0 _S1 = { float4(0.97000002861022949, 0.87999999523162842, 0.20999999344348907, 1.0) };
    return _S1;
}

