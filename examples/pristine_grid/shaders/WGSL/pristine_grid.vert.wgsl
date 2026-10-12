struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Camera_std140_0
{
    @align(16) projection_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) view_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) position_0 : vec3<f32>,
    @align(4) time_0 : f32,
};

@binding(0) @group(0) var<uniform> camera_0 : Camera_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_1 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_2 : vec3<f32>,
    @location(1) uv_1 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.position_1 = (((vec4<f32>(_S1.position_2, 1.0f)) * ((((mat4x4<f32>(camera_0.view_0.data_0[i32(0)][i32(0)], camera_0.view_0.data_0[i32(1)][i32(0)], camera_0.view_0.data_0[i32(2)][i32(0)], camera_0.view_0.data_0[i32(3)][i32(0)], camera_0.view_0.data_0[i32(0)][i32(1)], camera_0.view_0.data_0[i32(1)][i32(1)], camera_0.view_0.data_0[i32(2)][i32(1)], camera_0.view_0.data_0[i32(3)][i32(1)], camera_0.view_0.data_0[i32(0)][i32(2)], camera_0.view_0.data_0[i32(1)][i32(2)], camera_0.view_0.data_0[i32(2)][i32(2)], camera_0.view_0.data_0[i32(3)][i32(2)], camera_0.view_0.data_0[i32(0)][i32(3)], camera_0.view_0.data_0[i32(1)][i32(3)], camera_0.view_0.data_0[i32(2)][i32(3)], camera_0.view_0.data_0[i32(3)][i32(3)])) * (mat4x4<f32>(camera_0.projection_0.data_0[i32(0)][i32(0)], camera_0.projection_0.data_0[i32(1)][i32(0)], camera_0.projection_0.data_0[i32(2)][i32(0)], camera_0.projection_0.data_0[i32(3)][i32(0)], camera_0.projection_0.data_0[i32(0)][i32(1)], camera_0.projection_0.data_0[i32(1)][i32(1)], camera_0.projection_0.data_0[i32(2)][i32(1)], camera_0.projection_0.data_0[i32(3)][i32(1)], camera_0.projection_0.data_0[i32(0)][i32(2)], camera_0.projection_0.data_0[i32(1)][i32(2)], camera_0.projection_0.data_0[i32(2)][i32(2)], camera_0.projection_0.data_0[i32(3)][i32(2)], camera_0.projection_0.data_0[i32(0)][i32(3)], camera_0.projection_0.data_0[i32(1)][i32(3)], camera_0.projection_0.data_0[i32(2)][i32(3)], camera_0.projection_0.data_0[i32(3)][i32(3)])))))));
    output_0.uv_0 = _S1.uv_1;
    return output_0;
}

