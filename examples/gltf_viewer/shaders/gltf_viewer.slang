// --------------------------------------------------------------------------
// glTF Viewer 2 - instanced PBR shading, ported 1:1 from the TypeScript
// WebGPU glTF viewer (src/shaders/vert.wgsl.ts / frag.wgsl.ts).
//
// group(0) is the camera, shared by every draw:
//   0 projView (uniform, vertex stage)
//   1 eye     (uniform, fragment stage, world-space eye position)
// group(1) is the per-(mesh, material) resources:
//   0  models           (read-only storage; [INSTANCE_CAPACITY] Model)
//   1/2  base color          sampler/texture (sRGB)
//   3/4  metallic-roughness  sampler/texture (linear)
//   5/6  normal              sampler/texture (linear)
//   7/8  occlusion           sampler/texture (linear)
//   9/10 emissive            sampler/texture (sRGB)
//   11 material uniforms (constant buffer)
//
// Differences from the WGSL references:
//   - the models array is a storage buffer instead of a uniform with a
//     hard-coded instance count (the, so all
//     primitives share one shader and one pipeline layout
//   - every texture slot is always bound (the CPU uploads 1x1 default
//     textures), so no presence flags or generated shaders are needed: the
//     flat default normal (0.5, 0.5, 1) decodes to (0, 0, 1) and reduces to
//     `normalize(vNormal)` exactly
//   - the fragment samples all five slots up front, in uniform control flow,
//     before the alpha-mask discard
// --------------------------------------------------------------------------

static const int INSTANCE_CAPACITY = 64;

// SV_InstanceID maps to a draw-parameter builtin on SPIR-V/GLSL targets, which
// drags in the `DrawParameters` SPIR-V capability (and a validation error on
// devices that do not enable shaderDrawParameters). SV_VulkanInstanceID maps
// to gl_InstanceIndex instead. Same trick as instanced_cube.
#if defined(__SPIRV__) || defined(__GLSL__)
    #define INSTANCE_ID_SEMANTIC SV_VulkanInstanceID
#else
    #define INSTANCE_ID_SEMANTIC SV_InstanceID
#endif

struct Camera_VS {
    float4x4 proj_view;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Camera_VS> camera_vs : register(b0);

struct Camera_FS {
    float4 eye; // world-space eye position
};

[[vk::binding(1, 0)]]
ConstantBuffer<Camera_FS> camera_fs : register(b1);

struct Model {
    float4x4 matrix;
    float4x4 invTr;
};

[[vk::binding(0, 1)]]
StructuredBuffer<Model> models : register(t0);

struct Material_Uniforms {
    float4 base_color_factor; // rgba
    float4 emissive_factor;   // rgb
    float4 pbr_factors;       // x metallic, y roughness, z normal scale, w occlusion strength
    float4 alpha;             // x alpha cutoff, y alpha mode, z double sided, w has normal map
    uint texcoord_bits;       // bit n set => texture slot n samples uv1
};

[[vk::binding(11, 1)]]
ConstantBuffer<Material_Uniforms> material_uniforms : register(b11);

#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(2, 1)]]  Sampler2D base_color_tex        : register(t2);
[[vk::binding(4, 1)]]  Sampler2D metallic_roughness_tex : register(t4);
[[vk::binding(6, 1)]]  Sampler2D normal_tex             : register(t6);
[[vk::binding(8, 1)]]  Sampler2D occlusion_tex          : register(t8);
[[vk::binding(10, 1)]] Sampler2D emissive_tex           : register(t10);

#else

// The register names must stay distinct from the group(1) resources because DX
// targets share a single register space.
[[vk::binding(1, 1)]]  SamplerState base_color_sampler        : register(s1);
[[vk::binding(2, 1)]]  Texture2D<float4> base_color_texture   : register(t2);
[[vk::binding(3, 1)]]  SamplerState metallic_roughness_sampler : register(s3);
[[vk::binding(4, 1)]]  Texture2D<float4> metallic_roughness_texture : register(t4);
[[vk::binding(5, 1)]]  SamplerState normal_sampler            : register(s5);
[[vk::binding(6, 1)]]  Texture2D<float4> normal_texture       : register(t6);
[[vk::binding(7, 1)]]  SamplerState occlusion_sampler         : register(s7);
[[vk::binding(8, 1)]]  Texture2D<float4> occlusion_texture    : register(t8);
[[vk::binding(9, 1)]]  SamplerState emissive_sampler          : register(s9);
[[vk::binding(10, 1)]] Texture2D<float4> emissive_texture     : register(t10);

#endif

static const float PI = 3.141592653589793;

// Varying / attribute locations.
//
// Slang's WGSL backend ignores [[vk::location]]: it treats a NON-ZERO semantic
// index as a fixed location and fills the remaining slots in declaration
// order. So every semantic here is index-free and the locations come out in
// declaration order on every backend. Keep the declaration order in sync with
// the Odin Vertex_Buffer_Layout:
//
//   0 position, 1 normal, 2 uv0, 3 uv1, 4 tangent, 5 color.
// The [[vk::location]] attributes drive SPIR-V and are harmless elsewhere.
struct VertexInput {
    [[vk::location(0)]] float3 position : POSITION;
    [[vk::location(1)]] float3 normal   : NORMAL;
    [[vk::location(2)]] float2 uv0      : UVSETA;
    [[vk::location(3)]] float2 uv1      : UVSETB;
    [[vk::location(4)]] float4 tangent  : TANGENT;
    [[vk::location(5)]] float4 color    : VCOLOR;
};

// Matches the vertex output: 0 normal, 1 worldPos, 2 uv, 3 uv1,
// 4 tangent, 5 bitangent, 6 color.
struct VertexOutput {
    float4 position                    : SV_Position;
    [[vk::location(0)]] float3 normal    : NORMAL;
    [[vk::location(1)]] float3 world_pos : WORLDPOS;
    [[vk::location(2)]] float2 uv0       : UVSETA;
    [[vk::location(3)]] float2 uv1       : UVSETB;
    [[vk::location(4)]] float3 tangent   : TANGENT;
    [[vk::location(5)]] float3 bitangent : BINORMAL;
    [[vk::location(6)]] float4 color     : VCOLOR;
};

struct FragmentInput {
    float4 position                    : SV_Position;
    [[vk::location(0)]] float3 normal    : NORMAL;
    [[vk::location(1)]] float3 world_pos : WORLDPOS;
    [[vk::location(2)]] float2 uv0       : UVSETA;
    [[vk::location(3)]] float2 uv1       : UVSETB;
    [[vk::location(4)]] float3 tangent   : TANGENT;
    [[vk::location(5)]] float3 bitangent : BINORMAL;
    [[vk::location(6)]] float4 color     : VCOLOR;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input, uint instance_id : INSTANCE_ID_SEMANTIC) {
    VertexOutput output;
    Model model = models[instance_id];

    float4 world_position = mul(model.matrix, float4(input.position, 1.0));
    output.position = mul(camera_vs.proj_view, world_position);

    output.normal = normalize(mul(model.invTr, float4(input.normal, 0.0)).xyz);
    output.world_pos = world_position.xyz;
    output.uv0 = input.uv0;
    output.uv1 = input.uv1;

    // Vertex tangents are always present (generated on the CPU when a model
    // has no TANGENT attribute and a normal map needs one; the default is the
    // axis which makes the flat default normal reduce to the vertex normal).
    output.tangent = normalize(mul(model.matrix, float4(input.tangent.xyz, 0.0)).xyz);
    output.bitangent = cross(output.normal, output.tangent) * input.tangent.w;

    output.color = input.color;
    return output;
}

// Picks the texture coordinate set a slot samples
float2 material_uv(int slot, float2 uv0, float2 uv1) {
    uint bit = (material_uniforms.texcoord_bits >> uint(slot)) & 1u;
    return bit != 0 ? uv1 : uv0;
}

// sRGB textures are decoded with the 2.2 gamma
// power because the swapchain target is linear here.
float4 linear_sample(float4 value) {
    return float4(pow(value.rgb, float3(2.2, 2.2, 2.2)), value.a);
}

float4 sample_base_color(float2 uv) {
#if defined(USE_COMBINED_SAMPLER)
    return base_color_tex.Sample(uv);
#else
    return base_color_texture.Sample(base_color_sampler, uv);
#endif
}

float4 sample_metallic_roughness(float2 uv) {
#if defined(USE_COMBINED_SAMPLER)
    return metallic_roughness_tex.Sample(uv);
#else
    return metallic_roughness_texture.Sample(metallic_roughness_sampler, uv);
#endif
}

float4 sample_normal(float2 uv) {
#if defined(USE_COMBINED_SAMPLER)
    return normal_tex.Sample(uv);
#else
    return normal_texture.Sample(normal_sampler, uv);
#endif
}

float4 sample_occlusion(float2 uv) {
#if defined(USE_COMBINED_SAMPLER)
    return occlusion_tex.Sample(uv);
#else
    return occlusion_texture.Sample(occlusion_sampler, uv);
#endif
}

float4 sample_emissive(float2 uv) {
#if defined(USE_COMBINED_SAMPLER)
    return emissive_tex.Sample(uv);
#else
    return emissive_texture.Sample(emissive_sampler, uv);
#endif
}

// Ported 1:1 from brdf() in frag.wgsl.ts. The specular denominator is clamped
// so a grazing ndotl * ndotv cannot produce NaN/Inf on non-WGSL backends; the
// WGSL reference relies on IEEE behaviour (anything divided by zero saturates
// to the implicit max(..., 0) anyway).
float3 brdf(float3 color, float metallic, float roughness,
            float3 l, float3 v, float3 n) {
    float3 h = normalize(l + v);

    float ndotl = clamp(dot(n, l), 0.0, 1.0);
    float ndotv = abs(dot(n, v));
    float ndoth = clamp(dot(n, h), 0.0, 1.0);
    float vdoth = clamp(dot(v, h), 0.0, 1.0);

    float3 f0 = float3(0.04);
    float3 diffuse_color = color * (1.0 - f0) * (1.0 - metallic);
    float3 specular_color = lerp(f0, color, metallic);

    float reflectance = max(max(specular_color.r, specular_color.g), specular_color.b);
    float3 reflectance0 = specular_color;
    float3 reflectance9 = float3(clamp(reflectance * 25.0, 0.0, 1.0));
    float3 f = reflectance0 + (reflectance9 - reflectance0) * pow(1.0 - vdoth, 5.0);

    float r2 = roughness * roughness;
    float r4 = r2 * r2;
    float attenuation_l = 2.0 * ndotl / (ndotl + sqrt(r4 + (1.0 - r4) * ndotl * ndotl));
    float attenuation_v = 2.0 * ndotv / (ndotv + sqrt(r4 + (1.0 - r4) * ndotv * ndotv));
    float g = attenuation_l * attenuation_v;

    float temp = ndoth * ndoth * (r2 - 1.0) + 1.0;
    float d = r2 / (PI * temp * temp);

    float3 diffuse = (1.0 - f) / PI * diffuse_color;
    float3 specular = max(f * g * d / (4.0 * max(ndotl * ndotv, 1e-4)), float3(0.0));
    return ndotl * (diffuse + specular) * 2.0 + color * 0.1;
}

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target0 {
    float alpha_mode = material_uniforms.alpha.y;
    float double_sided = material_uniforms.alpha.z;

    // All five slots are sampled up front, before any discard, so the implicit
    // texture derivatives stay inside uniform control flow (WebGPU).
    float4 base_color_sample = linear_sample(sample_base_color(material_uv(0, input.uv0, input.uv1)));
    float4 mr_sample = sample_metallic_roughness(material_uv(1, input.uv0, input.uv1));
    float4 normal_sample = sample_normal(material_uv(2, input.uv0, input.uv1));
    float4 occlusion_sample = sample_occlusion(material_uv(3, input.uv0, input.uv1));
    float4 emissive_sample = linear_sample(sample_emissive(material_uv(4, input.uv0, input.uv1)));

    float4 color = material_uniforms.base_color_factor * base_color_sample * input.color;

    // Alpha_Mask: handled in the shader because a per-material pipeline
    // variant would mean one pipeline per cutoff.
    if (alpha_mode > 0.5 && alpha_mode < 1.5 && color.a < material_uniforms.alpha.x) {
        discard;
    }

    float metallic = material_uniforms.pbr_factors.x * mr_sample.b;
    float roughness = clamp(material_uniforms.pbr_factors.y * mr_sample.g, 0.04, 1.0);

    float3 normal = normalize(input.normal);
    float3 tangent_normal = normal_sample.rgb * 2.0 - 1.0;
    tangent_normal.xy *= material_uniforms.pbr_factors.z;
    normal = normalize(tangent_normal.x * input.tangent +
                       tangent_normal.y * input.bitangent +
                       tangent_normal.z * normal);

    float ao = 1.0 + material_uniforms.pbr_factors.w * (occlusion_sample.r - 1.0);

    float3 emissive = material_uniforms.emissive_factor.rgb * emissive_sample.rgb;

    float3 view_dir = normalize(camera_fs.eye.xyz - input.world_pos);
    if (double_sided > 0.5 && dot(normal, view_dir) < 0.0) {
        normal = -normal;
    }

    float3 light_dir = normalize(float3(2.0, 4.0, 3.0));
    float3 rgb = brdf(color.rgb, metallic, roughness, light_dir, view_dir, normal) * ao + emissive;

    // The framework configures the swapchain with a plain unorm format, so the
    // shading happens in linear space and is encoded here.
    rgb = pow(max(rgb, 0.0), float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
    return float4(rgb, color.a);
}
