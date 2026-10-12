struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct SLANG_ParameterGroup_Uniforms_std140_0
{
    @align(16) mvpMat_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(0) var<uniform> Uniforms_0 : SLANG_ParameterGroup_Uniforms_std140_0;
struct VertexOut_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) color_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) color_1 : vec3<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOut_0
{
    var output_0 : VertexOut_0;
    output_0.position_0 = (((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(Uniforms_0.mvpMat_0.data_0[i32(0)][i32(0)], Uniforms_0.mvpMat_0.data_0[i32(1)][i32(0)], Uniforms_0.mvpMat_0.data_0[i32(2)][i32(0)], Uniforms_0.mvpMat_0.data_0[i32(3)][i32(0)], Uniforms_0.mvpMat_0.data_0[i32(0)][i32(1)], Uniforms_0.mvpMat_0.data_0[i32(1)][i32(1)], Uniforms_0.mvpMat_0.data_0[i32(2)][i32(1)], Uniforms_0.mvpMat_0.data_0[i32(3)][i32(1)], Uniforms_0.mvpMat_0.data_0[i32(0)][i32(2)], Uniforms_0.mvpMat_0.data_0[i32(1)][i32(2)], Uniforms_0.mvpMat_0.data_0[i32(2)][i32(2)], Uniforms_0.mvpMat_0.data_0[i32(3)][i32(2)], Uniforms_0.mvpMat_0.data_0[i32(0)][i32(3)], Uniforms_0.mvpMat_0.data_0[i32(1)][i32(3)], Uniforms_0.mvpMat_0.data_0[i32(2)][i32(3)], Uniforms_0.mvpMat_0.data_0[i32(3)][i32(3)]))));
    output_0.color_0 = vec4<f32>(_S1.color_1, 1.0f);
    return output_0;
}

