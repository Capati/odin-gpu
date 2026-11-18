// Vertex stage: no vertex buffer. One instanced quad per particle, positioned
// from the storage buffer the compute shader wrote earlier in the same frame.

struct Particle
{
    float2 pos;
    float2 vel;
};

struct SimParams
{
    float2 resolution;
    float  time;
    float  delta;
    uint   count;
    float  size;
    float2 pad;
};

[[vk::binding(0, 0)]]
ConstantBuffer<SimParams> params : register(b0);

[[vk::binding(1, 0)]]
StructuredBuffer<Particle> particles : register(t1);

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
    Particle p = particles[iid];

    float2 corners[6] = {
        float2(-1.0, -1.0), float2(1.0, -1.0), float2(1.0, 1.0),
        float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, 1.0),
    };
    float2 corner = corners[vid];

    // One pixel is 2 / resolution in NDC, so `size` pixels is `size / resolution`.
    float2 half_extent = params.size / params.resolution;

    float2 center = float2(p.pos.x * 2.0 - 1.0, 1.0 - p.pos.y * 2.0);
    float2 pos    = center + corner * half_extent;

    // Hue from the position the compute pass produced, brightness from speed, so
    // both outputs of the simulation are visible at a glance. The damping in the
    // compute shader leaves most velocities near the same magnitude, which is
    // why speed alone is a weak cue.
    float3 hue = 0.5 + 0.5 * cos(6.28318 * (p.pos.xyx + float3(0.0, 0.33, 0.67)));
    float  speed = saturate(length(p.vel) * 4.0);

    VSOut output;
    output.pos   = float4(pos, 0.0, 1.0);
    output.color = float4(hue * (0.45 + 0.55 * speed), 1.0);
    return output;
}
