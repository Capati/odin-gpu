struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) matrix_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) resolution_0 : vec2<f32>,
    @align(8) size_0 : f32,
};

@binding(0) @group(0) var<uniform> uni_0 : Uniforms_std140_0;
const points_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( vec2<f32>(-1.0f, -1.0f), vec2<f32>(1.0f, -1.0f), vec2<f32>(-1.0f, 1.0f), vec2<f32>(-1.0f, 1.0f), vec2<f32>(1.0f, -1.0f), vec2<f32>(1.0f, 1.0f) );
struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) texcoord_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec4<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0, @builtin(vertex_index) vNdx_0 : u32) -> VSOutput_0
{
    var vsOut_0 : VSOutput_0;
    vsOut_0.position_0 = (((_S1.position_1) * (mat4x4<f32>(uni_0.matrix_0.data_0[i32(0)][i32(0)], uni_0.matrix_0.data_0[i32(1)][i32(0)], uni_0.matrix_0.data_0[i32(2)][i32(0)], uni_0.matrix_0.data_0[i32(3)][i32(0)], uni_0.matrix_0.data_0[i32(0)][i32(1)], uni_0.matrix_0.data_0[i32(1)][i32(1)], uni_0.matrix_0.data_0[i32(2)][i32(1)], uni_0.matrix_0.data_0[i32(3)][i32(1)], uni_0.matrix_0.data_0[i32(0)][i32(2)], uni_0.matrix_0.data_0[i32(1)][i32(2)], uni_0.matrix_0.data_0[i32(2)][i32(2)], uni_0.matrix_0.data_0[i32(3)][i32(2)], uni_0.matrix_0.data_0[i32(0)][i32(3)], uni_0.matrix_0.data_0[i32(1)][i32(3)], uni_0.matrix_0.data_0[i32(2)][i32(3)], uni_0.matrix_0.data_0[i32(3)][i32(3)])))) + vec4<f32>(points_0[vNdx_0] * vec2<f32>(uni_0.size_0) / uni_0.resolution_0, 0.0f, 0.0f);
    var _S2 : vec2<f32> = vec2<f32>(0.5f);
    vsOut_0.texcoord_0 = points_0[vNdx_0] * _S2 + _S2;
    return vsOut_0;
}

