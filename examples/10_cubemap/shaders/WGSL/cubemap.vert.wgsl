struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) modelViewProjectionMatrix_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(0) var<uniform> uniforms_0 : Uniforms_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) fragUV_0 : vec2<f32>,
    @location(1) fragPosition_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec4<f32>,
    @location(1) uv_0 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.position_0 = (((_S1.position_1) * (mat4x4<f32>(uniforms_0.modelViewProjectionMatrix_0.data_0[i32(0)][i32(0)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(1)][i32(0)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(2)][i32(0)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(3)][i32(0)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(0)][i32(1)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(1)][i32(1)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(2)][i32(1)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(3)][i32(1)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(0)][i32(2)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(1)][i32(2)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(2)][i32(2)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(3)][i32(2)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(0)][i32(3)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(1)][i32(3)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(2)][i32(3)], uniforms_0.modelViewProjectionMatrix_0.data_0[i32(3)][i32(3)]))));
    output_0.fragUV_0 = _S1.uv_0;
    output_0.fragPosition_0 = vec4<f32>(0.5f) * (_S1.position_1 + vec4<f32>(1.0f, 1.0f, 1.0f, 1.0f));
    return output_0;
}

