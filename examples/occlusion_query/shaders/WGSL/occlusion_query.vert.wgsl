struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) world_view_projection_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) world_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) color_0 : vec4<f32>,
};

struct SLANG_ParameterGroup_uniforms_std140_0
{
    @align(16) u_0 : Uniforms_std140_0,
};

@binding(0) @group(0) var<uniform> uniforms_0 : SLANG_ParameterGroup_uniforms_std140_0;
struct VertexOut_0
{
    @location(0) normal_0 : vec3<f32>,
    @builtin(position) position_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) normal_1 : vec3<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOut_0
{
    var output_0 : VertexOut_0;
    output_0.position_0 = (((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(uniforms_0.u_0.world_view_projection_0.data_0[i32(0)][i32(0)], uniforms_0.u_0.world_view_projection_0.data_0[i32(1)][i32(0)], uniforms_0.u_0.world_view_projection_0.data_0[i32(2)][i32(0)], uniforms_0.u_0.world_view_projection_0.data_0[i32(3)][i32(0)], uniforms_0.u_0.world_view_projection_0.data_0[i32(0)][i32(1)], uniforms_0.u_0.world_view_projection_0.data_0[i32(1)][i32(1)], uniforms_0.u_0.world_view_projection_0.data_0[i32(2)][i32(1)], uniforms_0.u_0.world_view_projection_0.data_0[i32(3)][i32(1)], uniforms_0.u_0.world_view_projection_0.data_0[i32(0)][i32(2)], uniforms_0.u_0.world_view_projection_0.data_0[i32(1)][i32(2)], uniforms_0.u_0.world_view_projection_0.data_0[i32(2)][i32(2)], uniforms_0.u_0.world_view_projection_0.data_0[i32(3)][i32(2)], uniforms_0.u_0.world_view_projection_0.data_0[i32(0)][i32(3)], uniforms_0.u_0.world_view_projection_0.data_0[i32(1)][i32(3)], uniforms_0.u_0.world_view_projection_0.data_0[i32(2)][i32(3)], uniforms_0.u_0.world_view_projection_0.data_0[i32(3)][i32(3)]))));
    var _S2 : mat4x4<f32> = mat4x4<f32>(uniforms_0.u_0.world_0.data_0[i32(0)][i32(0)], uniforms_0.u_0.world_0.data_0[i32(1)][i32(0)], uniforms_0.u_0.world_0.data_0[i32(2)][i32(0)], uniforms_0.u_0.world_0.data_0[i32(3)][i32(0)], uniforms_0.u_0.world_0.data_0[i32(0)][i32(1)], uniforms_0.u_0.world_0.data_0[i32(1)][i32(1)], uniforms_0.u_0.world_0.data_0[i32(2)][i32(1)], uniforms_0.u_0.world_0.data_0[i32(3)][i32(1)], uniforms_0.u_0.world_0.data_0[i32(0)][i32(2)], uniforms_0.u_0.world_0.data_0[i32(1)][i32(2)], uniforms_0.u_0.world_0.data_0[i32(2)][i32(2)], uniforms_0.u_0.world_0.data_0[i32(3)][i32(2)], uniforms_0.u_0.world_0.data_0[i32(0)][i32(3)], uniforms_0.u_0.world_0.data_0[i32(1)][i32(3)], uniforms_0.u_0.world_0.data_0[i32(2)][i32(3)], uniforms_0.u_0.world_0.data_0[i32(3)][i32(3)]);
    output_0.normal_0 = (((_S1.normal_1) * (mat3x3<f32>(_S2[i32(0)].xyz, _S2[i32(1)].xyz, _S2[i32(2)].xyz))));
    return output_0;
}

