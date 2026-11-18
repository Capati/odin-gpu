struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct SLANG_ParameterGroup_model_uniforms_std140_0
{
    @align(16) model_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(1) var<uniform> model_uniforms_0 : SLANG_ParameterGroup_model_uniforms_std140_0;
struct FrameUniforms_std140_0
{
    @align(16) view_projection_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

struct SLANG_ParameterGroup_frame_uniforms_std140_0
{
    @align(16) frame_0 : FrameUniforms_std140_0,
};

@binding(0) @group(0) var<uniform> frame_uniforms_0 : SLANG_ParameterGroup_frame_uniforms_std140_0;
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) normal_0 : vec3<f32>,
    @location(1) uv_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) normal_1 : vec3<f32>,
    @location(2) uv_1 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VertexOutput_0
{
    var output_0 : VertexOutput_0;
    output_0.position_0 = ((((((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(model_uniforms_0.model_0.data_0[i32(0)][i32(0)], model_uniforms_0.model_0.data_0[i32(1)][i32(0)], model_uniforms_0.model_0.data_0[i32(2)][i32(0)], model_uniforms_0.model_0.data_0[i32(3)][i32(0)], model_uniforms_0.model_0.data_0[i32(0)][i32(1)], model_uniforms_0.model_0.data_0[i32(1)][i32(1)], model_uniforms_0.model_0.data_0[i32(2)][i32(1)], model_uniforms_0.model_0.data_0[i32(3)][i32(1)], model_uniforms_0.model_0.data_0[i32(0)][i32(2)], model_uniforms_0.model_0.data_0[i32(1)][i32(2)], model_uniforms_0.model_0.data_0[i32(2)][i32(2)], model_uniforms_0.model_0.data_0[i32(3)][i32(2)], model_uniforms_0.model_0.data_0[i32(0)][i32(3)], model_uniforms_0.model_0.data_0[i32(1)][i32(3)], model_uniforms_0.model_0.data_0[i32(2)][i32(3)], model_uniforms_0.model_0.data_0[i32(3)][i32(3)]))))) * (mat4x4<f32>(frame_uniforms_0.frame_0.view_projection_0.data_0[i32(0)][i32(0)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(1)][i32(0)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(2)][i32(0)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(3)][i32(0)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(0)][i32(1)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(1)][i32(1)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(2)][i32(1)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(3)][i32(1)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(0)][i32(2)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(1)][i32(2)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(2)][i32(2)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(3)][i32(2)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(0)][i32(3)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(1)][i32(3)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(2)][i32(3)], frame_uniforms_0.frame_0.view_projection_0.data_0[i32(3)][i32(3)]))));
    var _S2 : mat4x4<f32> = mat4x4<f32>(model_uniforms_0.model_0.data_0[i32(0)][i32(0)], model_uniforms_0.model_0.data_0[i32(1)][i32(0)], model_uniforms_0.model_0.data_0[i32(2)][i32(0)], model_uniforms_0.model_0.data_0[i32(3)][i32(0)], model_uniforms_0.model_0.data_0[i32(0)][i32(1)], model_uniforms_0.model_0.data_0[i32(1)][i32(1)], model_uniforms_0.model_0.data_0[i32(2)][i32(1)], model_uniforms_0.model_0.data_0[i32(3)][i32(1)], model_uniforms_0.model_0.data_0[i32(0)][i32(2)], model_uniforms_0.model_0.data_0[i32(1)][i32(2)], model_uniforms_0.model_0.data_0[i32(2)][i32(2)], model_uniforms_0.model_0.data_0[i32(3)][i32(2)], model_uniforms_0.model_0.data_0[i32(0)][i32(3)], model_uniforms_0.model_0.data_0[i32(1)][i32(3)], model_uniforms_0.model_0.data_0[i32(2)][i32(3)], model_uniforms_0.model_0.data_0[i32(3)][i32(3)]);
    output_0.normal_0 = (((_S1.normal_1) * (mat3x3<f32>(_S2[i32(0)].xyz, _S2[i32(1)].xyz, _S2[i32(2)].xyz))));
    output_0.uv_0 = _S1.uv_1;
    return output_0;
}

