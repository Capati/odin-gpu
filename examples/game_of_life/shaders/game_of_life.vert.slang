// Vertex stage: no vertex buffer. One instanced quad per cell, positioned from
// the generation the compute pass just wrote. Dead cells collapse to a
// degenerate quad outside the clip volume so they cost no fragments.

struct GridParams
{
    uint2 size;
    float2 resolution;
};

[[vk::binding(0, 0)]]
ConstantBuffer<GridParams> params : register(b0);

[[vk::binding(1, 0)]]
StructuredBuffer<uint> grid : register(t1);

struct VSOut
{
    float4 color : COLOR;
    float4 pos   : SV_Position;
};

#if defined(__SPIRV__) || defined(__GLSL__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
    #define INSTANCE_ID_SEMANTIC SV_VulkanInstanceID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
    #define INSTANCE_ID_SEMANTIC SV_InstanceID
#endif

[shader("vertex")]
VSOut vs_main(uint vid : VERTEX_ID_SEMANTIC, uint iid : INSTANCE_ID_SEMANTIC)
{
    VSOut output;

    uint cells = params.size.x * params.size.y;
    if (iid >= cells || grid[iid] == 0)
    {
        // Outside the clip volume: the rasteriser drops it entirely.
        output.pos   = float4(2.0, 2.0, 2.0, 1.0);
        output.color = float4(0.0, 0.0, 0.0, 1.0);
        return output;
    }

    float2 corners[6] = {
        float2(-1.0, -1.0), float2(1.0, -1.0), float2(1.0, 1.0),
        float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0),
    };

    float2 cell_xy = float2(iid % params.size.x, iid / params.size.x);
    float2 cell_size = params.resolution / float2(params.size);

    // A small inset keeps the cells readable as a grid rather than a solid block.
    float2 centre = (cell_xy + 0.5) * cell_size;
    float2 pixel = centre + corners[vid] * cell_size * 0.5;

    output.pos = float4(
        pixel.x / params.resolution.x * 2.0 - 1.0,
        1.0 - pixel.y / params.resolution.y * 2.0,
        0.0,
        1.0);

    // Hue from the cell position, so the pattern's structure is readable without
    // tracking a per-cell age.
    float3 hue = 0.5 + 0.5 * cos(6.28318 * (float3(cell_xy.x, cell_xy.y, cell_xy.x + cell_xy.y) / 24.0
                                        + float3(0.0, 0.33, 0.67)));
    output.color = float4(0.35 + 0.65 * hue, 1.0);
    return output;
}
