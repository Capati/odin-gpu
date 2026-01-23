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
    var texColor_0 : vec4<f32> = (textureSample((r_color_texture_0), (r_color_sampler_0), (_S1.tex_coord_0 * vec2<f32>(0.80000001192092896f) + vec2<f32>(0.10000000149011612f, 0.10000000149011612f))));
    var f_0 : f32;
    if((length(texColor_0.xyz - vec3<f32>(0.5f, 0.5f, 0.5f))) < 0.00999999977648258f)
    {
        f_0 = 0.0f;
    }
    else
    {
        f_0 = 1.0f;
    }
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(f_0) * texColor_0 + vec4<f32>((1.0f - f_0)) * _S1.frag_position_0 );
    return _S2;
}

