struct Uniforms {
    column_major float4x4 modelViewProjectionMatrix[16];
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0, space0);

#if defined(__SPIRV__) || defined(__GLSL__)
    #define INSTANCE_ID_SEMANTIC SV_VulkanInstanceID
#else
    #define INSTANCE_ID_SEMANTIC SV_InstanceID
#endif

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
VertexOutput vs_main(VertexInput input, uint instance_idx : INSTANCE_ID_SEMANTIC) {
    VertexOutput output;
    output.position      = mul(uniforms.modelViewProjectionMatrix[instance_idx], input.position);
    output.frag_uv       = input.uv;
    output.frag_position = 0.5 * (input.position + float4(1.0));
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
