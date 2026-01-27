struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) normal_0 : vec3<f32>,
    @location(1) color_0 : vec3<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(vec3<f32>(0.80000001192092896f, 0.80000001192092896f, 0.80000001192092896f) * vec3<f32>((0.30000001192092896f + max(0.0f, dot(normalize(_S1.normal_0), normalize(vec3<f32>(0.5f, 1.0f, -0.5f)))) * 0.69999998807907104f)), 1.0f) );
    return _S2;
}

