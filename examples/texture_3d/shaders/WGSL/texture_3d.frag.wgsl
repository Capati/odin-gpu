@binding(2) @group(0) var texColor_0 : texture_3d<f32>;

@binding(1) @group(0) var texSampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) fragUV_0 : vec3<f32>,
    @location(1) fragNormal_0 : vec3<f32>,
    @location(2) viewVec_0 : vec3<f32>,
    @location(3) lightVec_0 : vec3<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var value_0 : f32 = (textureSample((texColor_0), (texSampler_0), (_S1.fragUV_0))).x;
    var normal_0 : vec3<f32> = normalize(_S1.fragNormal_0);
    var light_0 : vec3<f32> = normalize(_S1.lightVec_0);
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(vec3<f32>((max(dot(normal_0, light_0), 0.0f) * value_0 + pow(max(dot(reflect((vec3<f32>(0) - light_0), normal_0), normalize(_S1.viewVec_0)), 0.0f), 16.0f) * value_0)), 1.0f) );
    return _S2;
}

