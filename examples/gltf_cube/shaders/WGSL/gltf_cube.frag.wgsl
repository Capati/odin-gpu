struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) normal_0 : vec3<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : vec3<f32> = vec3<f32>(0.5f);
    var _S3 : pixelOutput_0 = pixelOutput_0( vec4<f32>(normalize(_S1.normal_0) * _S2 + _S2, 1.0f) );
    return _S3;
}

