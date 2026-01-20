#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 5 "examples/09_fractal_cube/shaders/fractal_cube.slang"
struct vs_main_Result_0
{
    float4 position_0 [[position]];
    float2 tex_coord_0 [[user(TEXCOORD)]];
    float4 frag_position_0 [[user(TEXCOORD_1)]];
};


#line 5
struct vertexInput_0
{
    float4 position_1 [[attribute(0)]];
    float2 tex_coord_1 [[attribute(1)]];
};


#line 5
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 5
struct Uniforms_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 transform_0;
};

struct VertexOutput_0
{
    float4 position_2;
    float2 tex_coord_2;
    float4 frag_position_1;
};


#line 10
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]], Uniforms_natural_0 constant* uniforms_0 [[buffer(0)]])
{

#line 21
    thread VertexOutput_0 output_0;
    (&output_0)->position_2 = (((_S1.position_1) * (matrix<float,int(4),int(4)> (uniforms_0->transform_0.data_0[int(0)][int(0)], uniforms_0->transform_0.data_0[int(1)][int(0)], uniforms_0->transform_0.data_0[int(2)][int(0)], uniforms_0->transform_0.data_0[int(3)][int(0)], uniforms_0->transform_0.data_0[int(0)][int(1)], uniforms_0->transform_0.data_0[int(1)][int(1)], uniforms_0->transform_0.data_0[int(2)][int(1)], uniforms_0->transform_0.data_0[int(3)][int(1)], uniforms_0->transform_0.data_0[int(0)][int(2)], uniforms_0->transform_0.data_0[int(1)][int(2)], uniforms_0->transform_0.data_0[int(2)][int(2)], uniforms_0->transform_0.data_0[int(3)][int(2)], uniforms_0->transform_0.data_0[int(0)][int(3)], uniforms_0->transform_0.data_0[int(1)][int(3)], uniforms_0->transform_0.data_0[int(2)][int(3)], uniforms_0->transform_0.data_0[int(3)][int(3)]))));
    (&output_0)->tex_coord_2 = _S1.tex_coord_1;
    (&output_0)->frag_position_1 = float4(0.5)  * (_S1.position_1 + float4(1.0, 1.0, 1.0, 1.0));

#line 24
    thread vs_main_Result_0 _S2;

#line 24
    (&_S2)->position_0 = output_0.position_2;

#line 24
    (&_S2)->tex_coord_0 = output_0.tex_coord_2;

#line 24
    (&_S2)->frag_position_0 = output_0.frag_position_1;

#line 24
    return _S2;
}

