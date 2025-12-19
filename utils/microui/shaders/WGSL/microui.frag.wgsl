@binding(1) @group(0) var r_color_texture_0 : texture_2d<f32>;

@binding(2) @group(0) var r_color_sampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) uv_0 : vec2<f32>,
    @location(1) color_0 : vec4<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( (textureSample((r_color_texture_0), (r_color_sampler_0), (_S1.uv_0))) * _S1.color_0 );
    return _S2;
}

