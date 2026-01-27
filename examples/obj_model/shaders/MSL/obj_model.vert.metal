#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 1 "examples/obj_model/shaders/obj_model.slang"
struct vs_main_Result_0
{
    float4 position_0 [[position]];
    float3 normal_0 [[user(NORMAL)]];
    float3 color_0 [[user(COLOR)]];
};


#line 1
struct vertexInput_0
{
    float3 position_1 [[attribute(0)]];
    float3 normal_1 [[attribute(1)]];
    float3 color_1 [[attribute(2)]];
};


#line 1
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 1
struct MyUniforms_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 projectionMatrix_0;
    _MatrixStorage_float4x4_ColMajornatural_0 viewMatrix_0;
    _MatrixStorage_float4x4_ColMajornatural_0 modelMatrix_0;
};


#line 7
struct VertexOutput_0
{
    float4 position_2;
    float3 normal_2;
    float3 color_2;
};


#line 7
[[vertex]] vs_main_Result_0 vs_main(vertexInput_0 _S1 [[stage_in]], MyUniforms_natural_0 constant* uMyUniforms_0 [[buffer(0)]])
{

#line 7
    matrix<float,int(4),int(4)>  _S2 = matrix<float,int(4),int(4)> (uMyUniforms_0->modelMatrix_0.data_0[int(0)][int(0)], uMyUniforms_0->modelMatrix_0.data_0[int(1)][int(0)], uMyUniforms_0->modelMatrix_0.data_0[int(2)][int(0)], uMyUniforms_0->modelMatrix_0.data_0[int(3)][int(0)], uMyUniforms_0->modelMatrix_0.data_0[int(0)][int(1)], uMyUniforms_0->modelMatrix_0.data_0[int(1)][int(1)], uMyUniforms_0->modelMatrix_0.data_0[int(2)][int(1)], uMyUniforms_0->modelMatrix_0.data_0[int(3)][int(1)], uMyUniforms_0->modelMatrix_0.data_0[int(0)][int(2)], uMyUniforms_0->modelMatrix_0.data_0[int(1)][int(2)], uMyUniforms_0->modelMatrix_0.data_0[int(2)][int(2)], uMyUniforms_0->modelMatrix_0.data_0[int(3)][int(2)], uMyUniforms_0->modelMatrix_0.data_0[int(0)][int(3)], uMyUniforms_0->modelMatrix_0.data_0[int(1)][int(3)], uMyUniforms_0->modelMatrix_0.data_0[int(2)][int(3)], uMyUniforms_0->modelMatrix_0.data_0[int(3)][int(3)]);

#line 24
    thread VertexOutput_0 output_0;



    (&output_0)->position_2 = (((((((((float4(_S1.position_1, 1.0)) * (_S2)))) * (matrix<float,int(4),int(4)> (uMyUniforms_0->viewMatrix_0.data_0[int(0)][int(0)], uMyUniforms_0->viewMatrix_0.data_0[int(1)][int(0)], uMyUniforms_0->viewMatrix_0.data_0[int(2)][int(0)], uMyUniforms_0->viewMatrix_0.data_0[int(3)][int(0)], uMyUniforms_0->viewMatrix_0.data_0[int(0)][int(1)], uMyUniforms_0->viewMatrix_0.data_0[int(1)][int(1)], uMyUniforms_0->viewMatrix_0.data_0[int(2)][int(1)], uMyUniforms_0->viewMatrix_0.data_0[int(3)][int(1)], uMyUniforms_0->viewMatrix_0.data_0[int(0)][int(2)], uMyUniforms_0->viewMatrix_0.data_0[int(1)][int(2)], uMyUniforms_0->viewMatrix_0.data_0[int(2)][int(2)], uMyUniforms_0->viewMatrix_0.data_0[int(3)][int(2)], uMyUniforms_0->viewMatrix_0.data_0[int(0)][int(3)], uMyUniforms_0->viewMatrix_0.data_0[int(1)][int(3)], uMyUniforms_0->viewMatrix_0.data_0[int(2)][int(3)], uMyUniforms_0->viewMatrix_0.data_0[int(3)][int(3)]))))) * (matrix<float,int(4),int(4)> (uMyUniforms_0->projectionMatrix_0.data_0[int(0)][int(0)], uMyUniforms_0->projectionMatrix_0.data_0[int(1)][int(0)], uMyUniforms_0->projectionMatrix_0.data_0[int(2)][int(0)], uMyUniforms_0->projectionMatrix_0.data_0[int(3)][int(0)], uMyUniforms_0->projectionMatrix_0.data_0[int(0)][int(1)], uMyUniforms_0->projectionMatrix_0.data_0[int(1)][int(1)], uMyUniforms_0->projectionMatrix_0.data_0[int(2)][int(1)], uMyUniforms_0->projectionMatrix_0.data_0[int(3)][int(1)], uMyUniforms_0->projectionMatrix_0.data_0[int(0)][int(2)], uMyUniforms_0->projectionMatrix_0.data_0[int(1)][int(2)], uMyUniforms_0->projectionMatrix_0.data_0[int(2)][int(2)], uMyUniforms_0->projectionMatrix_0.data_0[int(3)][int(2)], uMyUniforms_0->projectionMatrix_0.data_0[int(0)][int(3)], uMyUniforms_0->projectionMatrix_0.data_0[int(1)][int(3)], uMyUniforms_0->projectionMatrix_0.data_0[int(2)][int(3)], uMyUniforms_0->projectionMatrix_0.data_0[int(3)][int(3)]))));


    (&output_0)->normal_2 = (((float4(_S1.normal_1, 0.0)) * (_S2))).xyz;
    (&output_0)->color_2 = _S1.color_1;

#line 32
    thread vs_main_Result_0 _S3;

#line 32
    (&_S3)->position_0 = output_0.position_2;

#line 32
    (&_S3)->normal_0 = output_0.normal_2;

#line 32
    (&_S3)->color_0 = output_0.color_2;

#line 32
    return _S3;
}

