struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

struct VertexInput {
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 frag_uv : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(uniforms.modelViewProjectionMatrix, input.position);
    output.frag_uv = input.uv;
    output.frag_position = 0.5 * (input.position + float4(1.0, 1.0, 1.0, 1.0));
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 frag_uv : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(1, 0)]]
Sampler2D myTexture : register(t1);

#else

[[vk::binding(1, 0)]]
SamplerState mySampler : register(s1);

[[vk::binding(2, 0)]]
Texture2D myTexture : register(t2);

#endif

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    float4 tex;

#if defined(USE_COMBINED_SAMPLER)
    tex = myTexture.Sample(input.frag_uv);
#else
    tex = myTexture.Sample(mySampler, input.frag_uv);
#endif

    return tex * input.frag_position;
}
