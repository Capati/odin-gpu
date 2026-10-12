struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) frag_uv_0 : vec2<f32>,
    @location(1) frag_position_0 : vec4<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( _S1.frag_position_0 );
    return _S2;
}

