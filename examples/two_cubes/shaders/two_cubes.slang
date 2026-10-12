struct Uniforms {
    column_major float4x4 modelViewProjectionMatrix;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0, space0);

struct VertexInput {
    [[vk::location(0)]] float4 position : POSITION;
    [[vk::location(1)]] float2 uv       : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    [[vk::location(0)]] float2 frag_uv       : TEXCOORD0;
    [[vk::location(1)]] float4 frag_position : TEXCOORD1;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position      = mul(uniforms.modelViewProjectionMatrix, input.position);
    output.frag_uv       = input.uv;
    output.frag_position = 0.5 * (input.position + float4(1.0, 1.0, 1.0, 1.0));
    return output;
}

struct FragmentInput {
    [[vk::location(0)]] float2 frag_uv       : TEXCOORD0;
    [[vk::location(1)]] float4 frag_position : TEXCOORD1;
};

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    return input.frag_position;
}
