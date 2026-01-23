@binding(1) @group(0) var r_color_texture_0 : texture_2d<f32>;

@binding(2) @group(0) var r_color_sampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) tex_coord_0 : vec2<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var v_0 : f32 = (textureSample((r_color_texture_0), (r_color_sampler_0), (_S1.tex_coord_0))).x;
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(vec3<f32>(1.0f - v_0 * 5.0f, 1.0f - v_0 * 15.0f, 1.0f - v_0 * 50.0f), 1.0f) );
    return _S2;
}

