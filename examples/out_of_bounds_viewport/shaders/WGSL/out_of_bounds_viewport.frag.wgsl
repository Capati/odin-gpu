@binding(1) @group(0) var myTexture_0 : texture_2d<f32>;

@binding(2) @group(0) var mySampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) fragUV_0 : vec2<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>((textureSample((myTexture_0), (mySampler_0), (vec2<f32>(0.01250000018626451f * floor(_S1.fragUV_0.x / 0.01250000018626451f), 0.01250000018626451f * floor(_S1.fragUV_0.y / 0.01250000018626451f))))).xyz, 1.0f) );
    return _S2;
}

