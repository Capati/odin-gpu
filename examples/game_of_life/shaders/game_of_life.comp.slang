// Conway's Game of Life: one thread per cell, reading the previous generation
// and writing the next. The grid is toroidal, so the edges wrap.

struct GridParams
{
    uint2 size;
    float2 resolution;
};

[[vk::binding(0, 0)]]
ConstantBuffer<GridParams> params : register(b0);

[[vk::binding(1, 0)]]
StructuredBuffer<uint> src : register(t1);

[[vk::binding(2, 0)]]
RWStructuredBuffer<uint> dst : register(u2);

#define BLOCK_SIZE 16

[shader("compute")]
[numthreads(BLOCK_SIZE, BLOCK_SIZE, 1)]
void cs_main(uint3 tid : SV_DispatchThreadID)
{
    uint2 cell = tid.xy;
    if (cell.x >= params.size.x || cell.y >= params.size.y)
    {
        return;
    }

    int2 dims = int2(params.size);
    int2 p = int2(cell);

    // Count the eight neighbours, wrapping at the edges.
    uint neighbours = 0;
    for (int dy = -1; dy <= 1; dy++)
    {
        for (int dx = -1; dx <= 1; dx++)
        {
            if (dx == 0 && dy == 0)
            {
                continue;
            }
            int2 n = (p + int2(dx, dy) + dims) % dims;
            neighbours += src[n.y * dims.x + n.x];
        }
    }

    uint self = src[p.y * dims.x + p.x];

    // B3/S23: born on three neighbours, survives on two or three.
    bool alive = neighbours == 3 || (self != 0 && neighbours == 2);

    dst[p.y * dims.x + p.x] = alive ? 1 : 0;
}
