struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

@fragment
fn fs_main(@builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S1 : pixelOutput_0 = pixelOutput_0( vec4<f32>(0.97000002861022949f, 0.87999999523162842f, 0.20999999344348907f, 1.0f) );
    return _S1;
}

