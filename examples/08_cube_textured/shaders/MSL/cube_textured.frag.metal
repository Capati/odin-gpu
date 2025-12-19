#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 90 "core"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 90
struct pixelInput_0
{
    float2 tex_coord_0 [[user(TEXCOORD)]];
};


#line 90
struct KernelContext_0
{
    texture2d<float, access::sample> r_color_texture_0;
    sampler r_color_sampler_0;
};


#line 38 "examples/08_cube_textured/shaders/cube_textured.slang"
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texture2d<float, access::sample> r_color_texture_1 [[texture(1)]], sampler r_color_sampler_1 [[sampler(2)]])
{

#line 38
    KernelContext_0 kernelContext_0;

#line 38
    (&kernelContext_0)->r_color_texture_0 = r_color_texture_1;

#line 38
    (&kernelContext_0)->r_color_sampler_0 = r_color_sampler_1;

    float v_0 = (((&kernelContext_0)->r_color_texture_0).sample((r_color_sampler_1), (_S1.tex_coord_0))).x;

#line 40
    pixelOutput_0 _S2 = { float4(float3(1.0 - v_0 * 5.0, 1.0 - v_0 * 15.0, 1.0 - v_0 * 50.0), 1.0) };

    return _S2;
}

