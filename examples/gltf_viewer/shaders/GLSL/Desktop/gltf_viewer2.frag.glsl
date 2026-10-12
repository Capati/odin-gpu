#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 64 0
struct Material_Uniforms_0
{
    vec4 base_color_factor_0;
    vec4 emissive_factor_0;
    vec4 pbr_factors_0;
    vec4 alpha_0;
    uint texcoord_bits_0;
};

layout(binding = 11, set = 1)
layout(std140) uniform block_Material_Uniforms_0
{
    vec4 base_color_factor_0;
    vec4 emissive_factor_0;
    vec4 pbr_factors_0;
    vec4 alpha_0;
    uint texcoord_bits_0;
}material_uniforms_0;

#line 77
layout(binding = 2, set = 1)
uniform sampler2D base_color_tex_0;


#line 78
layout(binding = 4, set = 1)
uniform sampler2D metallic_roughness_tex_0;


#line 79
layout(binding = 6, set = 1)
uniform sampler2D normal_tex_0;


#line 80
layout(binding = 8, set = 1)
uniform sampler2D occlusion_tex_0;


#line 81
layout(binding = 10, set = 1)
uniform sampler2D emissive_tex_0;


#line 49
struct Camera_FS_0
{
    vec4 eye_0;
};

layout(binding = 1)
layout(std140) uniform block_Camera_FS_0
{
    vec4 eye_0;
}camera_fs_0;

#line 168
vec2 material_uv_0(int slot_0, vec2 uv0_0, vec2 uv1_0)
{

#line 168
    vec2 _S1;

    if((((material_uniforms_0.texcoord_bits_0) >> uint(slot_0)) & 1U) != 0U)
    {

#line 170
        _S1 = uv1_0;

#line 170
    }
    else
    {

#line 170
        _S1 = uv0_0;

#line 170
    }

#line 170
    return _S1;
}


#line 179
vec4 sample_base_color_0(vec2 uv_0)
{
    return (texture((base_color_tex_0), (uv_0)));
}


#line 175
vec4 linear_sample_0(vec4 value_0)
{

#line 176
    return vec4(pow(value_0.xyz, vec3(2.20000004768371582, 2.20000004768371582, 2.20000004768371582)), value_0.w);
}


#line 187
vec4 sample_metallic_roughness_0(vec2 uv_1)
{
    return (texture((metallic_roughness_tex_0), (uv_1)));
}




vec4 sample_normal_0(vec2 uv_2)
{
    return (texture((normal_tex_0), (uv_2)));
}




vec4 sample_occlusion_0(vec2 uv_3)
{
    return (texture((occlusion_tex_0), (uv_3)));
}




vec4 sample_emissive_0(vec2 uv_4)
{
    return (texture((emissive_tex_0), (uv_4)));
}


#line 223
vec3 brdf_0(vec3 color_0, float metallic_0, float roughness_0, vec3 l_0, vec3 v_0, vec3 n_0)
{
    vec3 h_0 = normalize(l_0 + v_0);

    float ndotl_0 = clamp(dot(n_0, l_0), 0.0, 1.0);
    float ndotv_0 = abs(dot(n_0, v_0));
    float ndoth_0 = clamp(dot(n_0, h_0), 0.0, 1.0);


    const vec3 f0_0 = vec3(0.03999999910593033);

    vec3 specular_color_0 = mix(f0_0, color_0, vec3(metallic_0));

#line 239
    vec3 f_0 = specular_color_0 + (vec3(clamp(max(max(specular_color_0.x, specular_color_0.y), specular_color_0.z) * 25.0, 0.0, 1.0)) - specular_color_0) * pow(1.0 - clamp(dot(v_0, h_0), 0.0, 1.0), 5.0);

    float r2_0 = roughness_0 * roughness_0;
    float r4_0 = r2_0 * r2_0;
    float _S2 = 1.0 - r4_0;



    float temp_0 = ndoth_0 * ndoth_0 * (r2_0 - 1.0) + 1.0;

#line 252
    return ndotl_0 * ((1.0 - f_0) / 3.14159274101257324 * (color_0 * (1.0 - f0_0) * (1.0 - metallic_0)) + max(f_0 * (2.0 * ndotl_0 / (ndotl_0 + sqrt(r4_0 + _S2 * ndotl_0 * ndotl_0)) * (2.0 * ndotv_0 / (ndotv_0 + sqrt(r4_0 + _S2 * ndotv_0 * ndotv_0)))) * (r2_0 / (3.14159274101257324 * temp_0 * temp_0)) / (4.0 * max(ndotl_0 * ndotv_0, 0.00009999999747379)), vec3(0.0))) * 2.0 + color_0 * 0.10000000149011612;
}


#line 252
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 252
layout(location = 0)
in vec3 input_normal_0;


#line 252
layout(location = 1)
in vec3 input_world_pos_0;


#line 252
layout(location = 2)
in vec2 input_uv0_0;


#line 252
layout(location = 3)
in vec2 input_uv1_0;


#line 252
layout(location = 4)
in vec3 input_tangent_0;


#line 252
layout(location = 5)
in vec3 input_bitangent_0;


#line 252
layout(location = 6)
in vec4 input_color_0;


void main()
{

#line 257
    float alpha_mode_0 = material_uniforms_0.alpha_0.y;
    float double_sided_0 = material_uniforms_0.alpha_0.z;

#line 263
    vec4 mr_sample_0 = sample_metallic_roughness_0(material_uv_0(1, input_uv0_0, input_uv1_0));
    vec4 normal_sample_0 = sample_normal_0(material_uv_0(2, input_uv0_0, input_uv1_0));
    vec4 occlusion_sample_0 = sample_occlusion_0(material_uv_0(3, input_uv0_0, input_uv1_0));
    vec4 emissive_sample_0 = linear_sample_0(sample_emissive_0(material_uv_0(4, input_uv0_0, input_uv1_0)));

    vec4 color_1 = material_uniforms_0.base_color_factor_0 * linear_sample_0(sample_base_color_0(material_uv_0(0, input_uv0_0, input_uv1_0))) * input_color_0;

#line 268
    bool _S3;



    if(alpha_mode_0 > 0.5)
    {

#line 272
        _S3 = alpha_mode_0 < 1.5;

#line 272
    }
    else
    {

#line 272
        _S3 = false;

#line 272
    }

#line 272
    if(_S3)
    {

#line 272
        _S3 = (color_1.w) < (material_uniforms_0.alpha_0.x);

#line 272
    }
    else
    {

#line 272
        _S3 = false;

#line 272
    }

#line 272
    if(_S3)
    {

#line 273
        discard;

#line 272
    }



    float metallic_1 = material_uniforms_0.pbr_factors_0.x * mr_sample_0.z;
    float roughness_1 = clamp(material_uniforms_0.pbr_factors_0.y * mr_sample_0.y, 0.03999999910593033, 1.0);

    vec3 normal_0 = normalize(input_normal_0);
    vec3 _S4 = normal_sample_0.xyz * 2.0 - 1.0;

#line 280
    vec3 tangent_normal_0 = _S4;
    tangent_normal_0.xy = _S4.xy * material_uniforms_0.pbr_factors_0.z;
    vec3 normal_1 = normalize(tangent_normal_0.x * input_tangent_0 + tangent_normal_0.y * input_bitangent_0 + tangent_normal_0.z * normal_0);



    float ao_0 = 1.0 + material_uniforms_0.pbr_factors_0.w * (occlusion_sample_0.x - 1.0);

    vec3 emissive_0 = material_uniforms_0.emissive_factor_0.xyz * emissive_sample_0.xyz;

    vec3 view_dir_0 = normalize(camera_fs_0.eye_0.xyz - input_world_pos_0);
    if(double_sided_0 > 0.5)
    {

#line 291
        _S3 = (dot(normal_1, view_dir_0)) < 0.0;

#line 291
    }
    else
    {

#line 291
        _S3 = false;

#line 291
    }

#line 291
    vec3 normal_2;

#line 291
    if(_S3)
    {

#line 291
        normal_2 = - normal_1;

#line 291
    }
    else
    {

#line 291
        normal_2 = normal_1;

#line 291
    }

#line 291
    entryPointParam_fs_main_0 = vec4(pow(max(brdf_0(color_1.xyz, metallic_1, roughness_1, normalize(vec3(2.0, 4.0, 3.0)), view_dir_0, normal_2) * ao_0 + emissive_0, vec3(0.0)), vec3(0.45454543828964233, 0.45454543828964233, 0.45454543828964233)), color_1.w);

#line 291
    return;
}

