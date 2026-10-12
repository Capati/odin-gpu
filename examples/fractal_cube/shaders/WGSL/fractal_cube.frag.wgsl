struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) transform_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) uv_scale_0 : vec2<f32>,
    @align(8) _pad_0 : vec2<f32>,
};

@binding(0) @group(0) var<uniform> uniforms_0 : Uniforms_std140_0;
@binding(1) @group(0) var r_color_texture_0 : texture_2d<f32>;

@binding(2) @group(0) var r_color_sampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) tex_coord_0 : vec2<f32>,
    @location(1) frag_position_0 : vec4<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    const _S2 : vec2<f32> = vec2<f32>(0.5f, 0.5f);
    var texColor_0 : vec4<f32> = (textureSample((r_color_texture_0), (r_color_sampler_0), ((_S1.tex_coord_0 - _S2) * uniforms_0.uv_scale_0 * vec2<f32>(0.80000001192092896f) + _S2)));
    var f_0 : f32;
    if((length(texColor_0.xyz - vec3<f32>(0.5f, 0.5f, 0.5f))) < 0.00999999977648258f)
    {
        f_0 = 0.0f;
    }
    else
    {
        f_0 = 1.0f;
    }
    var _S3 : pixelOutput_0 = pixelOutput_0( vec4<f32>(f_0) * texColor_0 + vec4<f32>((1.0f - f_0)) * _S1.frag_position_0 );
    return _S3;
}

