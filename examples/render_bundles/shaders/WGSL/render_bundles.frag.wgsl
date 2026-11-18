@binding(1) @group(1) var mesh_texture_0 : texture_2d<f32>;

@binding(2) @group(1) var mesh_sampler_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) normal_0 : vec3<f32>,
    @location(1) uv_0 : vec2<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var texel_0 : vec4<f32> = (textureSample((mesh_texture_0), (mesh_sampler_0), (_S1.uv_0)));
    var _S2 : pixelOutput_0 = pixelOutput_0( vec4<f32>(texel_0.xyz * saturate(vec3<f32>(0.05000000074505806f, 0.05000000074505806f, 0.05000000074505806f) + vec3<f32>(max(dot(normalize(_S1.normal_0), normalize(vec3<f32>(1.0f, 1.0f, 1.0f))), 0.0f))), texel_0.w) );
    return _S2;
}

