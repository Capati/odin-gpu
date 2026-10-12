struct Material_Uniforms_std140_0
{
    @align(16) base_color_factor_0 : vec4<f32>,
    @align(16) emissive_factor_0 : vec4<f32>,
    @align(16) pbr_factors_0 : vec4<f32>,
    @align(16) alpha_0 : vec4<f32>,
    @align(16) texcoord_bits_0 : u32,
};

@binding(11) @group(1) var<uniform> material_uniforms_0 : Material_Uniforms_std140_0;
@binding(2) @group(1) var base_color_texture_0 : texture_2d<f32>;

@binding(1) @group(1) var base_color_sampler_0 : sampler;

@binding(4) @group(1) var metallic_roughness_texture_0 : texture_2d<f32>;

@binding(3) @group(1) var metallic_roughness_sampler_0 : sampler;

@binding(6) @group(1) var normal_texture_0 : texture_2d<f32>;

@binding(5) @group(1) var normal_sampler_0 : sampler;

@binding(8) @group(1) var occlusion_texture_0 : texture_2d<f32>;

@binding(7) @group(1) var occlusion_sampler_0 : sampler;

@binding(10) @group(1) var emissive_texture_0 : texture_2d<f32>;

@binding(9) @group(1) var emissive_sampler_0 : sampler;

struct Camera_FS_std140_0
{
    @align(16) eye_0 : vec4<f32>,
};

@binding(1) @group(0) var<uniform> camera_fs_0 : Camera_FS_std140_0;
fn material_uv_0( slot_0 : i32,  uv0_0 : vec2<f32>,  uv1_0 : vec2<f32>) -> vec2<f32>
{
    var _S1 : vec2<f32>;
    if((((((material_uniforms_0.texcoord_bits_0) >> (u32(slot_0)))) & (u32(1)))) != u32(0))
    {
        _S1 = uv1_0;
    }
    else
    {
        _S1 = uv0_0;
    }
    return _S1;
}

fn sample_base_color_0( uv_0 : vec2<f32>) -> vec4<f32>
{
    return (textureSample((base_color_texture_0), (base_color_sampler_0), (uv_0)));
}

fn linear_sample_0( value_0 : vec4<f32>) -> vec4<f32>
{
    return vec4<f32>(pow(value_0.xyz, vec3<f32>(2.20000004768371582f, 2.20000004768371582f, 2.20000004768371582f)), value_0.w);
}

fn sample_metallic_roughness_0( uv_1 : vec2<f32>) -> vec4<f32>
{
    return (textureSample((metallic_roughness_texture_0), (metallic_roughness_sampler_0), (uv_1)));
}

fn sample_normal_0( uv_2 : vec2<f32>) -> vec4<f32>
{
    return (textureSample((normal_texture_0), (normal_sampler_0), (uv_2)));
}

fn sample_occlusion_0( uv_3 : vec2<f32>) -> vec4<f32>
{
    return (textureSample((occlusion_texture_0), (occlusion_sampler_0), (uv_3)));
}

fn sample_emissive_0( uv_4 : vec2<f32>) -> vec4<f32>
{
    return (textureSample((emissive_texture_0), (emissive_sampler_0), (uv_4)));
}

fn brdf_0( color_0 : vec3<f32>,  metallic_0 : f32,  roughness_0 : f32,  l_0 : vec3<f32>,  v_0 : vec3<f32>,  n_0 : vec3<f32>) -> vec3<f32>
{
    var h_0 : vec3<f32> = normalize(l_0 + v_0);
    var ndotl_0 : f32 = clamp(dot(n_0, l_0), 0.0f, 1.0f);
    var ndotv_0 : f32 = abs(dot(n_0, v_0));
    var ndoth_0 : f32 = clamp(dot(n_0, h_0), 0.0f, 1.0f);
    var f0_0 : vec3<f32> = vec3<f32>(0.03999999910593033f);
    var _S2 : vec3<f32> = vec3<f32>(1.0f);
    var specular_color_0 : vec3<f32> = mix(f0_0, color_0, vec3<f32>(metallic_0));
    var f_0 : vec3<f32> = specular_color_0 + (vec3<f32>(clamp(max(max(specular_color_0.x, specular_color_0.y), specular_color_0.z) * 25.0f, 0.0f, 1.0f)) - specular_color_0) * vec3<f32>(pow(1.0f - clamp(dot(v_0, h_0), 0.0f, 1.0f), 5.0f));
    var r2_0 : f32 = roughness_0 * roughness_0;
    var r4_0 : f32 = r2_0 * r2_0;
    var _S3 : f32 = 1.0f - r4_0;
    var temp_0 : f32 = ndoth_0 * ndoth_0 * (r2_0 - 1.0f) + 1.0f;
    return vec3<f32>(ndotl_0) * ((_S2 - f_0) / vec3<f32>(3.14159274101257324f) * (color_0 * (_S2 - f0_0) * vec3<f32>((1.0f - metallic_0))) + max(f_0 * vec3<f32>((2.0f * ndotl_0 / (ndotl_0 + sqrt(r4_0 + _S3 * ndotl_0 * ndotl_0)) * (2.0f * ndotv_0 / (ndotv_0 + sqrt(r4_0 + _S3 * ndotv_0 * ndotv_0))))) * vec3<f32>((r2_0 / (3.14159274101257324f * temp_0 * temp_0))) / vec3<f32>((4.0f * max(ndotl_0 * ndotv_0, 0.00009999999747379f))), vec3<f32>(0.0f))) * vec3<f32>(2.0f) + color_0 * vec3<f32>(0.10000000149011612f);
}

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) normal_0 : vec3<f32>,
    @location(1) world_pos_0 : vec3<f32>,
    @location(2) uv0_1 : vec2<f32>,
    @location(3) uv1_1 : vec2<f32>,
    @location(4) tangent_0 : vec3<f32>,
    @location(5) bitangent_0 : vec3<f32>,
    @location(6) color_1 : vec4<f32>,
};

@fragment
fn fs_main( _S4 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var alpha_mode_0 : f32 = material_uniforms_0.alpha_0.y;
    var double_sided_0 : f32 = material_uniforms_0.alpha_0.z;
    var mr_sample_0 : vec4<f32> = sample_metallic_roughness_0(material_uv_0(i32(1), _S4.uv0_1, _S4.uv1_1));
    var normal_sample_0 : vec4<f32> = sample_normal_0(material_uv_0(i32(2), _S4.uv0_1, _S4.uv1_1));
    var occlusion_sample_0 : vec4<f32> = sample_occlusion_0(material_uv_0(i32(3), _S4.uv0_1, _S4.uv1_1));
    var emissive_sample_0 : vec4<f32> = linear_sample_0(sample_emissive_0(material_uv_0(i32(4), _S4.uv0_1, _S4.uv1_1)));
    var color_2 : vec4<f32> = material_uniforms_0.base_color_factor_0 * linear_sample_0(sample_base_color_0(material_uv_0(i32(0), _S4.uv0_1, _S4.uv1_1))) * _S4.color_1;
    var _S5 : bool;
    if(alpha_mode_0 > 0.5f)
    {
        _S5 = alpha_mode_0 < 1.5f;
    }
    else
    {
        _S5 = false;
    }
    if(_S5)
    {
        _S5 = (color_2.w) < (material_uniforms_0.alpha_0.x);
    }
    else
    {
        _S5 = false;
    }
    if(_S5)
    {
        discard;
    }
    var metallic_1 : f32 = material_uniforms_0.pbr_factors_0.x * mr_sample_0.z;
    var roughness_1 : f32 = clamp(material_uniforms_0.pbr_factors_0.y * mr_sample_0.y, 0.03999999910593033f, 1.0f);
    var normal_1 : vec3<f32> = normalize(_S4.normal_0);
    var _S6 : vec3<f32> = normal_sample_0.xyz * vec3<f32>(2.0f) - vec3<f32>(1.0f);
    var tangent_normal_0 : vec3<f32> = _S6;
    var _S7 : vec2<f32> = _S6.xy * vec2<f32>(material_uniforms_0.pbr_factors_0.z);
    tangent_normal_0.x = _S7.x;
    tangent_normal_0.y = _S7.y;
    var normal_2 : vec3<f32> = normalize(vec3<f32>(tangent_normal_0.x) * _S4.tangent_0 + vec3<f32>(tangent_normal_0.y) * _S4.bitangent_0 + vec3<f32>(tangent_normal_0.z) * normal_1);
    var ao_0 : f32 = 1.0f + material_uniforms_0.pbr_factors_0.w * (occlusion_sample_0.x - 1.0f);
    var emissive_0 : vec3<f32> = material_uniforms_0.emissive_factor_0.xyz * emissive_sample_0.xyz;
    var view_dir_0 : vec3<f32> = normalize(camera_fs_0.eye_0.xyz - _S4.world_pos_0);
    if(double_sided_0 > 0.5f)
    {
        _S5 = (dot(normal_2, view_dir_0)) < 0.0f;
    }
    else
    {
        _S5 = false;
    }
    var normal_3 : vec3<f32>;
    if(_S5)
    {
        normal_3 = (vec3<f32>(0) - normal_2);
    }
    else
    {
        normal_3 = normal_2;
    }
    var _S8 : pixelOutput_0 = pixelOutput_0( vec4<f32>(pow(max(brdf_0(color_2.xyz, metallic_1, roughness_1, normalize(vec3<f32>(2.0f, 4.0f, 3.0f)), view_dir_0, normal_3) * vec3<f32>(ao_0) + emissive_0, vec3<f32>(0.0f)), vec3<f32>(0.45454543828964233f, 0.45454543828964233f, 0.45454543828964233f)), color_2.w) );
    return _S8;
}

