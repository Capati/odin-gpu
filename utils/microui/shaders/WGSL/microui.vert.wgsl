struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) transform_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(0) var<uniform> uniforms_0 : Uniforms_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
    @location(1) color_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec2<f32>,
    @location(1) uv_1 : vec2<f32>,
    @location(2) color_1 : vec4<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.position_0 = (((vec4<f32>(_S1.position_1, 0.0f, 1.0f)) * (mat4x4<f32>(uniforms_0.transform_0.data_0[i32(0)][i32(0)], uniforms_0.transform_0.data_0[i32(1)][i32(0)], uniforms_0.transform_0.data_0[i32(2)][i32(0)], uniforms_0.transform_0.data_0[i32(3)][i32(0)], uniforms_0.transform_0.data_0[i32(0)][i32(1)], uniforms_0.transform_0.data_0[i32(1)][i32(1)], uniforms_0.transform_0.data_0[i32(2)][i32(1)], uniforms_0.transform_0.data_0[i32(3)][i32(1)], uniforms_0.transform_0.data_0[i32(0)][i32(2)], uniforms_0.transform_0.data_0[i32(1)][i32(2)], uniforms_0.transform_0.data_0[i32(2)][i32(2)], uniforms_0.transform_0.data_0[i32(3)][i32(2)], uniforms_0.transform_0.data_0[i32(0)][i32(3)], uniforms_0.transform_0.data_0[i32(1)][i32(3)], uniforms_0.transform_0.data_0[i32(2)][i32(3)], uniforms_0.transform_0.data_0[i32(3)][i32(3)]))));
    output_0.uv_0 = _S1.uv_1;
    output_0.color_0 = _S1.color_1;
    return output_0;
}

