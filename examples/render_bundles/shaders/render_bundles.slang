// Textured sphere lit by a single static directional light.
//
// `uniforms` (group 0) holds the frame view-projection and is rebound once per
// pass; `model` (group 1) holds this object's transform and is what the per-draw
// bind group supplies. Two groups is what the reference sample uses, and it is
// what makes the render-bundle experiment meaningful: every draw differs only in
// bind group 1, vertex buffer and index buffer.

struct FrameUniforms {
    float4x4 view_projection;
};

[[vk::binding(0, 0)]]
cbuffer frame_uniforms : register(b0) {
    FrameUniforms frame;
};

[[vk::binding(0, 1)]]
cbuffer model_uniforms : register(b1) {
    float4x4 model;
};

struct VertexInput {
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float2 uv       : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float3 normal   : NORMAL;
    float2 uv       : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    float4 world = mul(model, float4(input.position, 1.0));
    output.position = mul(frame.view_projection, world);
    // Uniform scale only, so the upper 3x3 rotates the normal without an
    // inverse-transpose.
    output.normal = mul((float3x3)model, input.normal);
    output.uv = input.uv;
    return output;
}

// Sampler and texture are bound as separate resources, matching the WebGPU
// bind-group layout: texture at 1, sampler at 2. A combined `Sampler2D` is what
// GLSL needs; the desktop path defines `USE_COMBINED_SAMPLER`.
#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(1, 1)]]
Sampler2D mesh_texture : register(t1);

#else

[[vk::binding(1, 1)]]
Texture2D mesh_texture : register(t1);

[[vk::binding(2, 1)]]
SamplerState mesh_sampler : register(s2);

#endif

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target {
#if defined(USE_COMBINED_SAMPLER)
    float4 texel = mesh_texture.Sample(input.uv);
#else
    float4 texel = mesh_texture.Sample(mesh_sampler, input.uv);
#endif

    // Very simple lighting, matching the reference: a static direction plus a
    // small ambient term.
    float3 light_direction = normalize(float3(1.0, 1.0, 1.0));
    float3 ambient = float3(0.05, 0.05, 0.05);
    float3 light = saturate(ambient + max(dot(normalize(input.normal), light_direction), 0.0));

    return float4(texel.rgb * light, texel.a);
}
