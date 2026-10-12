struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) projection_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) modelView_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) viewPos_0 : vec4<f32>,
    @align(16) depth_0 : f32,
};

@binding(0) @group(0) var<uniform> ubo_0 : Uniforms_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) fragUV_0 : vec3<f32>,
    @location(1) fragNormal_0 : vec3<f32>,
    @location(2) viewVec_0 : vec3<f32>,
    @location(3) lightVec_0 : vec3<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) uv_0 : vec2<f32>,
    @location(2) normal_0 : vec3<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.fragUV_0 = vec3<f32>(_S1.uv_0, ubo_0.depth_0);
    var viewPosition_0 : vec4<f32> = (((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(ubo_0.modelView_0.data_0[i32(0)][i32(0)], ubo_0.modelView_0.data_0[i32(1)][i32(0)], ubo_0.modelView_0.data_0[i32(2)][i32(0)], ubo_0.modelView_0.data_0[i32(3)][i32(0)], ubo_0.modelView_0.data_0[i32(0)][i32(1)], ubo_0.modelView_0.data_0[i32(1)][i32(1)], ubo_0.modelView_0.data_0[i32(2)][i32(1)], ubo_0.modelView_0.data_0[i32(3)][i32(1)], ubo_0.modelView_0.data_0[i32(0)][i32(2)], ubo_0.modelView_0.data_0[i32(1)][i32(2)], ubo_0.modelView_0.data_0[i32(2)][i32(2)], ubo_0.modelView_0.data_0[i32(3)][i32(2)], ubo_0.modelView_0.data_0[i32(0)][i32(3)], ubo_0.modelView_0.data_0[i32(1)][i32(3)], ubo_0.modelView_0.data_0[i32(2)][i32(3)], ubo_0.modelView_0.data_0[i32(3)][i32(3)]))));
    output_0.position_0 = (((viewPosition_0) * (mat4x4<f32>(ubo_0.projection_0.data_0[i32(0)][i32(0)], ubo_0.projection_0.data_0[i32(1)][i32(0)], ubo_0.projection_0.data_0[i32(2)][i32(0)], ubo_0.projection_0.data_0[i32(3)][i32(0)], ubo_0.projection_0.data_0[i32(0)][i32(1)], ubo_0.projection_0.data_0[i32(1)][i32(1)], ubo_0.projection_0.data_0[i32(2)][i32(1)], ubo_0.projection_0.data_0[i32(3)][i32(1)], ubo_0.projection_0.data_0[i32(0)][i32(2)], ubo_0.projection_0.data_0[i32(1)][i32(2)], ubo_0.projection_0.data_0[i32(2)][i32(2)], ubo_0.projection_0.data_0[i32(3)][i32(2)], ubo_0.projection_0.data_0[i32(0)][i32(3)], ubo_0.projection_0.data_0[i32(1)][i32(3)], ubo_0.projection_0.data_0[i32(2)][i32(3)], ubo_0.projection_0.data_0[i32(3)][i32(3)]))));
    var _S2 : mat4x4<f32> = mat4x4<f32>(ubo_0.modelView_0.data_0[i32(0)][i32(0)], ubo_0.modelView_0.data_0[i32(1)][i32(0)], ubo_0.modelView_0.data_0[i32(2)][i32(0)], ubo_0.modelView_0.data_0[i32(3)][i32(0)], ubo_0.modelView_0.data_0[i32(0)][i32(1)], ubo_0.modelView_0.data_0[i32(1)][i32(1)], ubo_0.modelView_0.data_0[i32(2)][i32(1)], ubo_0.modelView_0.data_0[i32(3)][i32(1)], ubo_0.modelView_0.data_0[i32(0)][i32(2)], ubo_0.modelView_0.data_0[i32(1)][i32(2)], ubo_0.modelView_0.data_0[i32(2)][i32(2)], ubo_0.modelView_0.data_0[i32(3)][i32(2)], ubo_0.modelView_0.data_0[i32(0)][i32(3)], ubo_0.modelView_0.data_0[i32(1)][i32(3)], ubo_0.modelView_0.data_0[i32(2)][i32(3)], ubo_0.modelView_0.data_0[i32(3)][i32(3)]);
    output_0.fragNormal_0 = (((_S1.normal_0) * (mat3x3<f32>(_S2[i32(0)].xyz, _S2[i32(1)].xyz, _S2[i32(2)].xyz))));
    var _S3 : vec3<f32> = viewPosition_0.xyz;
    output_0.lightVec_0 = (vec3<f32>(0) - _S3);
    output_0.viewVec_0 = ubo_0.viewPos_0.xyz - _S3;
    return output_0;
}

