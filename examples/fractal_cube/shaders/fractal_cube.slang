struct Uniforms {
    float4x4 transform;
    float2 uv_scale;
    float2 _pad;
};

struct VertexInput {
    float4 position : POSITION;
    float2 tex_coord : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(uniforms.transform, input.position);
    output.tex_coord = input.tex_coord;
    output.frag_position = 0.5 * (input.position + float4(1.0, 1.0, 1.0, 1.0));
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(1, 0)]]
Sampler2D r_color : register(t1);

#else

[[vk::binding(1, 0)]]
Texture2D r_color_texture : register(t1);

[[vk::binding(2, 0)]]
SamplerState r_color_sampler : register(s2);

#endif

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    float4 texColor;

    // Centered crop of the full-frame feedback texture to a square aspect
    // (uv_scale updated on resize), then the historical 80% zoom.
    float2 uv = (input.tex_coord - float2(0.5, 0.5)) * uniforms.uv_scale;
    uv = uv * 0.8 + float2(0.5, 0.5);

#if defined(USE_COMBINED_SAMPLER)
    texColor = r_color.Sample(uv);
#else
    texColor = r_color_texture.Sample(r_color_sampler, uv);
#endif

    // The threshold of 0.01 used in the shader depends on the base gray color
    float f = length(texColor.rgb - float3(0.5, 0.5, 0.5)) < 0.01 ? 0.0 : 1.0;
    return f * texColor + (1.0 - f) * input.frag_position;
}
