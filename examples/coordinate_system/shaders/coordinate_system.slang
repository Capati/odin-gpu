struct VSInput
{
    [[vk::location(0)]] float3 pos : POSITION;
    [[vk::location(1)]] float2 uv  : TEXCOORD0;
};

struct VSOutput
{
    float4 position : SV_Position;
    [[vk::location(0)]] float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]] Texture2D<float4> textureColor;
[[vk::binding(1, 0)]] SamplerState      samplerColor;

[shader("vertex")]
VSOutput vs_main(VSInput input)
{
    VSOutput output;
    output.uv       = input.uv;
    output.position = float4(input.pos, 1.0);
    return output;
}

[shader("fragment")]
float4 fs_main(VSOutput input) : SV_Target
{
    return textureColor.Sample(samplerColor, input.uv);
}
