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
    float2 uv_0 [[user(TEXCOORD)]];
    float4 color_0 [[user(COLOR)]];
};


#line 90
struct KernelContext_0
{
    texture2d<float, access::sample> r_color_texture_0;
    sampler r_color_sampler_0;
};


#line 42 "utils/microui/shaders/microui.slang"
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texture2d<float, access::sample> r_color_texture_1 [[texture(1)]], sampler r_color_sampler_1 [[sampler(2)]])
{

#line 42
    KernelContext_0 kernelContext_0;

#line 42
    (&kernelContext_0)->r_color_texture_0 = r_color_texture_1;

#line 42
    (&kernelContext_0)->r_color_sampler_0 = r_color_sampler_1;

#line 42
    pixelOutput_0 _S2 = { (((&kernelContext_0)->r_color_texture_0).sample((r_color_sampler_1), (_S1.uv_0))) * _S1.color_0 };

    return _S2;
}

