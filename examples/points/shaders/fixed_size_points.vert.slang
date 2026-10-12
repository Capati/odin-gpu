struct Vertex
{
    [[ vk::location(0) ]] float4 position : POSITION;
};

struct Uniforms
{
    column_major float4x4 matrix;
    float2 resolution;
    float size;
};

struct VSOutput
{
    float4 position : SV_Position;
    [[ vk::location(0) ]] float2 texcoord : TEXCOORD0;
};

[[ vk::binding(0, 0) ]]
ConstantBuffer<Uniforms> uni : register(b0, space0);

static const float2 points[6] = {
    float2(-1, -1),
    float2( 1, -1),
    float2(-1,  1),
    float2(-1,  1),
    float2( 1, -1),
    float2( 1,  1),
};

#if defined(__SPIRV__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
#endif

[shader("vertex")]
VSOutput vs_main(Vertex vert, uint vNdx : VERTEX_ID_SEMANTIC)
{
    VSOutput vsOut;

    float2 pos = points[vNdx];
    float4 clipPos = mul(uni.matrix, vert.position);

    // Fixed-size: constant pixel size regardless of depth (no clipPos.w factor)
    float4 pointPos = float4(pos * uni.size / uni.resolution, 0, 0);

    vsOut.position = clipPos + pointPos;
    vsOut.texcoord = pos * 0.5 + 0.5;
    return vsOut;
}
