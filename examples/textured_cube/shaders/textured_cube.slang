struct Uniforms {
    float4x4 transform;
};

struct VertexInput {
    float4 position : POSITION;
    float2 tex_coord : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.tex_coord = input.tex_coord;
    output.position = mul(uniforms.transform, input.position);
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
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
    float4 tex;

#if defined(USE_COMBINED_SAMPLER)
    tex = r_color.Sample(input.tex_coord);
#else
    tex = r_color_texture.Sample(r_color_sampler, input.tex_coord);
#endif

    float v = tex.r;
    float3 color = float3(1.0 - (v * 5.0), 1.0 - (v * 15.0), 1.0 - (v * 50.0));
    return float4(color, 1.0);
}
