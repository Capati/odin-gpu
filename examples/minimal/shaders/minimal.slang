struct VSOut {
    float2 coord : Coord;
    float4 pos   : SV_Position;
};

#if defined(__SPIRV__) || defined(__GLSL__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
#endif

[shader("vertex")]
VSOut vs_main(uint idx : VERTEX_ID_SEMANTIC)
{
    float2 data[6] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(1.0, 1.0),

        float2(-1.0, -1.0),
        float2(-1.0, 1.0),
        float2(1.0, 1.0),
    };

    float2 pos = data[idx];

    VSOut out;
    out.pos = float4(pos, 0.0, 1.0);
    out.coord.x = (pos.x + 1.0) / 2.0;
    out.coord.y = (1.0 - pos.y) / 2.0;

    return out;
}

[shader("fragment")]
float4 fs_main(float2 coord : Coord) : SV_Target
{
    return float4(coord.x, coord.y, 0.5, 1.0);
}
