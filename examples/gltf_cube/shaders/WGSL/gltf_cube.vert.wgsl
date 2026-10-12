struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

@binding(0) @group(0) var<uniform> mvp_0 : _MatrixStorage_float4x4_ColMajorstd140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) normal_0 : vec3<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) normal_1 : vec3<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.position_0 = (((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(mvp_0.data_0[i32(0)][i32(0)], mvp_0.data_0[i32(1)][i32(0)], mvp_0.data_0[i32(2)][i32(0)], mvp_0.data_0[i32(3)][i32(0)], mvp_0.data_0[i32(0)][i32(1)], mvp_0.data_0[i32(1)][i32(1)], mvp_0.data_0[i32(2)][i32(1)], mvp_0.data_0[i32(3)][i32(1)], mvp_0.data_0[i32(0)][i32(2)], mvp_0.data_0[i32(1)][i32(2)], mvp_0.data_0[i32(2)][i32(2)], mvp_0.data_0[i32(3)][i32(2)], mvp_0.data_0[i32(0)][i32(3)], mvp_0.data_0[i32(1)][i32(3)], mvp_0.data_0[i32(2)][i32(3)], mvp_0.data_0[i32(3)][i32(3)]))));
    output_0.normal_0 = _S1.normal_1;
    return output_0;
}

