struct _MatrixStorage_float4x4_ColMajorstd430_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Model_std430_0
{
    @align(16) matrix_0 : _MatrixStorage_float4x4_ColMajorstd430_0,
    @align(16) invTr_0 : _MatrixStorage_float4x4_ColMajorstd430_0,
};

@binding(0) @group(1) var<storage, read> models_0 : array<Model_std430_0>;

struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_1 : array<vec4<f32>, i32(4)>,
};

struct Camera_VS_std140_0
{
    @align(16) proj_view_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(0) var<uniform> camera_vs_0 : Camera_VS_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) normal_0 : vec3<f32>,
    @location(1) world_pos_0 : vec3<f32>,
    @location(2) uv0_0 : vec2<f32>,
    @location(3) uv1_0 : vec2<f32>,
    @location(4) tangent_0 : vec3<f32>,
    @location(5) bitangent_0 : vec3<f32>,
    @location(6) color_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) normal_1 : vec3<f32>,
    @location(2) uv0_1 : vec2<f32>,
    @location(3) uv1_1 : vec2<f32>,
    @location(4) tangent_1 : vec4<f32>,
    @location(5) color_1 : vec4<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0, @builtin(instance_index) instance_id_0 : u32) -> VertexOutput_0
{
    var model_0 : Model_std430_0 = models_0[instance_id_0];
    var _S2 : mat4x4<f32> = mat4x4<f32>(model_0.matrix_0.data_0[i32(0)][i32(0)], model_0.matrix_0.data_0[i32(1)][i32(0)], model_0.matrix_0.data_0[i32(2)][i32(0)], model_0.matrix_0.data_0[i32(3)][i32(0)], model_0.matrix_0.data_0[i32(0)][i32(1)], model_0.matrix_0.data_0[i32(1)][i32(1)], model_0.matrix_0.data_0[i32(2)][i32(1)], model_0.matrix_0.data_0[i32(3)][i32(1)], model_0.matrix_0.data_0[i32(0)][i32(2)], model_0.matrix_0.data_0[i32(1)][i32(2)], model_0.matrix_0.data_0[i32(2)][i32(2)], model_0.matrix_0.data_0[i32(3)][i32(2)], model_0.matrix_0.data_0[i32(0)][i32(3)], model_0.matrix_0.data_0[i32(1)][i32(3)], model_0.matrix_0.data_0[i32(2)][i32(3)], model_0.matrix_0.data_0[i32(3)][i32(3)]);
    var world_position_0 : vec4<f32> = (((vec4<f32>(_S1.position_1, 1.0f)) * (_S2)));
    var output_0 : VertexOutput_0;
    output_0.position_0 = (((world_position_0) * (mat4x4<f32>(camera_vs_0.proj_view_0.data_1[i32(0)][i32(0)], camera_vs_0.proj_view_0.data_1[i32(1)][i32(0)], camera_vs_0.proj_view_0.data_1[i32(2)][i32(0)], camera_vs_0.proj_view_0.data_1[i32(3)][i32(0)], camera_vs_0.proj_view_0.data_1[i32(0)][i32(1)], camera_vs_0.proj_view_0.data_1[i32(1)][i32(1)], camera_vs_0.proj_view_0.data_1[i32(2)][i32(1)], camera_vs_0.proj_view_0.data_1[i32(3)][i32(1)], camera_vs_0.proj_view_0.data_1[i32(0)][i32(2)], camera_vs_0.proj_view_0.data_1[i32(1)][i32(2)], camera_vs_0.proj_view_0.data_1[i32(2)][i32(2)], camera_vs_0.proj_view_0.data_1[i32(3)][i32(2)], camera_vs_0.proj_view_0.data_1[i32(0)][i32(3)], camera_vs_0.proj_view_0.data_1[i32(1)][i32(3)], camera_vs_0.proj_view_0.data_1[i32(2)][i32(3)], camera_vs_0.proj_view_0.data_1[i32(3)][i32(3)]))));
    var _S3 : vec3<f32> = normalize((((vec4<f32>(_S1.normal_1, 0.0f)) * (mat4x4<f32>(model_0.invTr_0.data_0[i32(0)][i32(0)], model_0.invTr_0.data_0[i32(1)][i32(0)], model_0.invTr_0.data_0[i32(2)][i32(0)], model_0.invTr_0.data_0[i32(3)][i32(0)], model_0.invTr_0.data_0[i32(0)][i32(1)], model_0.invTr_0.data_0[i32(1)][i32(1)], model_0.invTr_0.data_0[i32(2)][i32(1)], model_0.invTr_0.data_0[i32(3)][i32(1)], model_0.invTr_0.data_0[i32(0)][i32(2)], model_0.invTr_0.data_0[i32(1)][i32(2)], model_0.invTr_0.data_0[i32(2)][i32(2)], model_0.invTr_0.data_0[i32(3)][i32(2)], model_0.invTr_0.data_0[i32(0)][i32(3)], model_0.invTr_0.data_0[i32(1)][i32(3)], model_0.invTr_0.data_0[i32(2)][i32(3)], model_0.invTr_0.data_0[i32(3)][i32(3)])))).xyz);
    output_0.normal_0 = _S3;
    output_0.world_pos_0 = world_position_0.xyz;
    output_0.uv0_0 = _S1.uv0_1;
    output_0.uv1_0 = _S1.uv1_1;
    var _S4 : vec3<f32> = normalize((((vec4<f32>(_S1.tangent_1.xyz, 0.0f)) * (_S2))).xyz);
    output_0.tangent_0 = _S4;
    output_0.bitangent_0 = cross(_S3, _S4) * vec3<f32>(_S1.tangent_1.w);
    output_0.color_0 = _S1.color_1;
    return output_0;
}

