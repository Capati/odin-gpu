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
struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) normal_0 : vec3<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(uniforms_0.u_0.color_0.xyz * vec3<f32>(saturate(dot(normalize(_S1.normal_0), normalize(vec3<f32>(4.0f, 10.0f, 6.0f))) * 0.5f + 0.5f)), uniforms_0.u_0.color_0.w) );
    return _S2;
}

