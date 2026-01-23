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
    @location(0) tex_coord_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec4<f32>,
    @location(1) tex_coord_1 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.tex_coord_0 = _S1.tex_coord_1;
    output_0.position_0 = (((_S1.position_1) * (mat4x4<f32>(uniforms_0.transform_0.data_0[i32(0)][i32(0)], uniforms_0.transform_0.data_0[i32(1)][i32(0)], uniforms_0.transform_0.data_0[i32(2)][i32(0)], uniforms_0.transform_0.data_0[i32(3)][i32(0)], uniforms_0.transform_0.data_0[i32(0)][i32(1)], uniforms_0.transform_0.data_0[i32(1)][i32(1)], uniforms_0.transform_0.data_0[i32(2)][i32(1)], uniforms_0.transform_0.data_0[i32(3)][i32(1)], uniforms_0.transform_0.data_0[i32(0)][i32(2)], uniforms_0.transform_0.data_0[i32(1)][i32(2)], uniforms_0.transform_0.data_0[i32(2)][i32(2)], uniforms_0.transform_0.data_0[i32(3)][i32(2)], uniforms_0.transform_0.data_0[i32(0)][i32(3)], uniforms_0.transform_0.data_0[i32(1)][i32(3)], uniforms_0.transform_0.data_0[i32(2)][i32(3)], uniforms_0.transform_0.data_0[i32(3)][i32(3)]))));
    return output_0;
}

