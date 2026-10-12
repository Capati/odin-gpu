struct VSInput
{
    [[vk::location(0)]] float2 pos   : POSITION;
    [[vk::location(1)]] float  color : COLOR0;
};

struct VSOutput
{
    float4 pos   : SV_Position;
    [[vk::location(0)]] float color : COLOR0;
};

[shader("vertex")]
VSOutput vs_main(VSInput input)
{
    VSOutput output;
    output.pos   = float4(input.pos, 0.0, 1.0);
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fs_main([[vk::location(0)]] float color : COLOR0) : SV_Target
{
    return float4(color, color, abs(color), 1.0);
}
