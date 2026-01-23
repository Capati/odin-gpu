#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 13 "examples/06_rotating_cube/shaders/rotating_cube.slang"
struct vs_main_Result_0
{
    float4 position_0 [[position]];
    float2 tex_coords_0 [[user(TEXCOORD)]];
    float4 color_0 [[user(COLOR)]];
};


#line 13
struct vertexInput_0
{
    float4 position_1 [[attribute(0)]];
    float4 color_1 [[attribute(1)]];
    float2 uv_0 [[attribute(2)]];
};


#line 13
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 13
struct SLANG_ParameterGroup_Uniforms_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 modelViewProjectionMatrix_0;
};


#line 1
struct VertexOut_0
{
    float4 position_2;
    float2 tex_coords_1;
    float4 color_2;
};


#line 1
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]], SLANG_ParameterGroup_Uniforms_natural_0 constant* Uniforms_0 [[buffer(0)]])
{

#line 18
    thread VertexOut_0 output_0;
    (&output_0)->position_2 = (((_S1.position_1) * (matrix<float,int(4),int(4)> (Uniforms_0->modelViewProjectionMatrix_0.data_0[int(0)][int(0)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(1)][int(0)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(2)][int(0)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(3)][int(0)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(0)][int(1)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(1)][int(1)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(2)][int(1)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(3)][int(1)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(0)][int(2)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(1)][int(2)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(2)][int(2)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(3)][int(2)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(0)][int(3)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(1)][int(3)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(2)][int(3)], Uniforms_0->modelViewProjectionMatrix_0.data_0[int(3)][int(3)]))));
    (&output_0)->tex_coords_1 = _S1.uv_0;
    (&output_0)->color_2 = _S1.color_1;

#line 21
    thread vs_main_Result_0 _S2;

#line 21
    (&_S2)->position_0 = output_0.position_2;

#line 21
    (&_S2)->tex_coords_0 = output_0.tex_coords_1;

#line 21
    (&_S2)->color_0 = output_0.color_2;

#line 21
    return _S2;
}

