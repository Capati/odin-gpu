struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

@fragment
fn fs_main() -> pixelOutput_0
{
    var _S1 : pixelOutput_0 = pixelOutput_0( vec4<f32>(1.0f, 0.5f, 0.20000000298023224f, 1.0f) );
    return _S1;
}

