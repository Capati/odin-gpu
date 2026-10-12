@binding(2) @group(0) var t_0 : texture_2d<f32>;

@binding(1) @group(0) var s_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) texcoord_0 : vec2<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0) -> pixelOutput_0
{
    var color_0 : vec4<f32> = (textureSample((t_0), (s_0), (_S1.texcoord_0)));
    if((color_0.w) < 0.10000000149011612f)
    {
        discard;
    }
    var _S2 : pixelOutput_0 = pixelOutput_0( color_0 );
    return _S2;
}

