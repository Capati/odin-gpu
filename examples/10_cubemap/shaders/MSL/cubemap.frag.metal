#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 90 "core"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 2305 "core.meta.slang"
struct pixelInput_0
{
    float2 fragUV_0 [[user(TEXCOORD)]];
    float4 fragPosition_0 [[user(TEXCOORD_1)]];
};


#line 2305
struct KernelContext_0
{
    texturecube<float, access::sample> myTexture_0;
    sampler mySampler_0;
};


#line 50 "examples/10_cubemap/shaders/cubemap.slang"
[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texturecube<float, access::sample> myTexture_1 [[texture(1)]], sampler mySampler_1 [[sampler(2)]])
{

#line 50
    KernelContext_0 kernelContext_0;

#line 50
    (&kernelContext_0)->myTexture_0 = myTexture_1;

#line 50
    (&kernelContext_0)->mySampler_0 = mySampler_1;



    float3 _S2 = _S1.fragPosition_0.xyz - float3(0.5, 0.5, 0.5);

#line 54
    thread float3 cubemapVec_0 = _S2;

#line 59
    cubemapVec_0.z = - _S2.z;

#line 59
    pixelOutput_0 _S3 = { (((&kernelContext_0)->myTexture_0).sample((mySampler_1), (cubemapVec_0))) };

#line 64
    return _S3;
}

