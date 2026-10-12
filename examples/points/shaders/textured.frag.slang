struct VSOutput
{
    [[ vk::location(0) ]] float2 texcoord : TEXCOORD0;
};

[[ vk::binding(1, 0) ]]
SamplerState s : register(s1, space0);

[[ vk::binding(2, 0) ]]
Texture2D<float4> t : register(t2, space0);

[shader("fragment")]
float4 fs_main(VSOutput vsOut) : SV_Target0
{
    float4 color = t.Sample(s, vsOut.texcoord);
    if (color.a < 0.1)
    {
        discard;
    }
    return color;
}
