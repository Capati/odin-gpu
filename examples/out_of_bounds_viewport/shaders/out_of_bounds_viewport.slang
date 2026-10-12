struct Viewport
{
    float x;
    float y;
    float w;
    float h;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Viewport> viewport : register(b0, space0);

[[vk::binding(1, 0)]]
Texture2D<float4> myTexture : register(t1, space0);

[[vk::binding(2, 0)]]
SamplerState mySampler : register(s2, space0);

struct VertexOutput
{
    float4 position : SV_Position;
    float2 fragUV   : TEXCOORD0;
};

static const float2 kPos[6] = {
    float2( 1.0,  1.0), float2( 1.0, -1.0), float2(-1.0, -1.0),
    float2( 1.0,  1.0), float2(-1.0, -1.0), float2(-1.0,  1.0),
};

static const float2 kUV[6] = {
    float2(1.0, 0.0), float2(1.0, 1.0), float2(0.0, 1.0),
    float2(1.0, 0.0), float2(0.0, 1.0), float2(0.0, 0.0),
};

#if defined(__SPIRV__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
#endif

[shader("vertex")]
VertexOutput vs_main(uint vertexIndex : VERTEX_ID_SEMANTIC)
{
    float4 position = float4(kPos[vertexIndex], 0.0, 1.0);

    position.x = position.x * viewport.w
               + (viewport.x + viewport.w - 1.0 + viewport.x) * position.w;
    position.y = position.y * viewport.h
               + (viewport.y + viewport.h - 1.0 + viewport.y) * position.w;

    VertexOutput output;
    output.position = position;
    output.fragUV   = kUV[vertexIndex];
    return output;
}

[shader("fragment")]
float4 fs_main(float2 fragUV : TEXCOORD0) : SV_Target0
{
    const float dx = 8.0 / 640.0;
    const float dy = 8.0 / 640.0;
    float2 uv = float2(dx * floor(fragUV.x / dx), dy * floor(fragUV.y / dy));

    float3 color = myTexture.Sample(mySampler, uv).rgb;

    return float4(color, 1.0);
}
