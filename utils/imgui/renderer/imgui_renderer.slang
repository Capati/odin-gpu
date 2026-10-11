struct Uniforms
{
    column_major float4x4 mvp;
    float gamma;
};

[[vk::binding(0, 0)]] ConstantBuffer<Uniforms> uniforms : register(b0, space0);
[[vk::binding(1, 0)]] SamplerState samplerState : register(s0, space0);
[[vk::binding(0, 1)]] Texture2D<float4> tex : register(t0, space1);

struct VertexInput
{
    [[vk::location(0)]] float2 position : POSITION;
    [[vk::location(1)]] float2 uv       : TEXCOORD0;
    [[vk::location(2)]] float4 color    : COLOR0;
};

struct VertexOutput
{
    float4 position : SV_Position;
    [[vk::location(0)]] float4 color : COLOR0;
    [[vk::location(1)]] float2 uv    : TEXCOORD0;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input)
{
    VertexOutput output;
    output.position = mul(uniforms.mvp, float4(input.position, 0.0, 1.0));
    output.color = input.color;
    output.uv = input.uv;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target
{
    float4 color = input.color * tex.Sample(samplerState, input.uv);
    float3 correctedColor = pow(color.rgb, float3(1.0));
    return float4(correctedColor, color.a);
}
