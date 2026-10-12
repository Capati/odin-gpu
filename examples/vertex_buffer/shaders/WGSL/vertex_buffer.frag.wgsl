struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) color_0 : f32,
};

@fragment
fn fs_main( _S1 : pixelInput_0) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(_S1.color_0, _S1.color_0, abs(_S1.color_0), 1.0f) );
    return _S2;
}

