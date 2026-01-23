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
    float4 frag_position_0 [[user(TEXCOORD_1)]];
};


#line 90
struct KernelContext_0
{
    texture2d<float, access::sample> r_color_texture_0;
    sampler r_color_sampler_0;
};


#line 50 "examples/09_fractal_cube/shaders/fractal_cube.slang"
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texture2d<float, access::sample> r_color_texture_1 [[texture(1)]], sampler r_color_sampler_1 [[sampler(2)]])
{

#line 50
    KernelContext_0 kernelContext_0;

#line 50
    (&kernelContext_0)->r_color_texture_0 = r_color_texture_1;

#line 50
    (&kernelContext_0)->r_color_sampler_0 = r_color_sampler_1;

#line 56
    float4 texColor_0 = (((&kernelContext_0)->r_color_texture_0).sample((r_color_sampler_1), (_S1.tex_coord_0 * float2(0.80000001192092896)  + float2(0.10000000149011612, 0.10000000149011612))));

#line 56
    float f_0;



    if((length(texColor_0.xyz - float3(0.5, 0.5, 0.5))) < 0.00999999977648258)
    {

#line 60
        f_0 = 0.0;

#line 60
    }
    else
    {

#line 60
        f_0 = 1.0;

#line 60
    }

#line 60
    pixelOutput_0 _S2 = { float4(f_0)  * texColor_0 + float4((1.0 - f_0))  * _S1.frag_position_0 };
    return _S2;
}

