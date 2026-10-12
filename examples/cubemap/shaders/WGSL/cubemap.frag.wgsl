struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct Uniforms_std140_0
{
    @align(16) viewDirectionProjectionInverse_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
};

@binding(0) @group(0) var<uniform> uniforms_0 : Uniforms_std140_0;
@binding(2) @group(0) var myTexture_0 : texture_cube<f32>;

@binding(1) @group(0) var mySampler_0 : sampler;

struct FragmentOutput_0
{
    @location(0) color_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) direction_0 : vec4<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> FragmentOutput_0
{
    var t_0 : vec4<f32> = (((_S1.direction_0) * (mat4x4<f32>(uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(0)][i32(0)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(1)][i32(0)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(2)][i32(0)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(3)][i32(0)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(0)][i32(1)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(1)][i32(1)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(2)][i32(1)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(3)][i32(1)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(0)][i32(2)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(1)][i32(2)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(2)][i32(2)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(3)][i32(2)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(0)][i32(3)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(1)][i32(3)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(2)][i32(3)], uniforms_0.viewDirectionProjectionInverse_0.data_0[i32(3)][i32(3)]))));
    var output_0 : FragmentOutput_0;
    output_0.color_0 = (textureSample((myTexture_0), (mySampler_0), (normalize(t_0.xyz / vec3<f32>(t_0.w)))));
    return output_0;
}

