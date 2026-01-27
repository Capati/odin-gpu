#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 37 "examples/obj_model/shaders/obj_model.slang"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 37
struct pixelInput_0
{
    float3 normal_0 [[user(NORMAL)]];
    float3 color_0 [[user(COLOR)]];
};


[[fragment]] pixelOutput_0 fs_main(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]])
{

#line 44
    pixelOutput_0 _S2 = { float4(float3(0.80000001192092896, 0.80000001192092896, 0.80000001192092896) * float3((0.30000001192092896 + max(0.0, dot(normalize(_S1.normal_0), normalize(float3(0.5, 1.0, -0.5)))) * 0.69999998807907104)) , 1.0) };

#line 61
    return _S2;
}

