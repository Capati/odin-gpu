@binding(1) @group(0) var myTexture_0 : texture_cube<f32>;

@binding(2) @group(0) var mySampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) fragUV_0 : vec2<f32>,
    @location(1) fragPosition_0 : vec4<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : vec3<f32> = _S1.fragPosition_0.xyz - vec3<f32>(0.5f, 0.5f, 0.5f);
    var cubemapVec_0 : vec3<f32> = _S2;
    cubemapVec_0[i32(2)] = - _S2.z;
    var _S3 : pixelOutput_0 = pixelOutput_0( (textureSample((myTexture_0), (mySampler_0), (cubemapVec_0))) );
    return _S3;
}

