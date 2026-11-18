// Compute stage: advances the particle field in place. Reads and writes the same
// storage buffer, which is what makes this a read/write storage binding rather
// than a write-only one.

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
RWStructuredBuffer<Particle> particles : register(u1);

[shader("compute")]
[numthreads(64, 1, 1)]
void cs_main(uint3 tid : SV_DispatchThreadID)
{
    uint i = tid.x;
    if (i >= params.count)
    {
        return;
    }

    Particle p = particles[i];

    p.pos += p.vel * params.delta;

    // Reflect off the walls of the unit square.
    if (p.pos.x < 0.0) { p.pos.x = -p.pos.x; p.vel.x = -p.vel.x; }
    if (p.pos.x > 1.0) { p.pos.x = 2.0 - p.pos.x; p.vel.x = -p.vel.x; }
    if (p.pos.y < 0.0) { p.pos.y = -p.pos.y; p.vel.y = -p.vel.y; }
    if (p.pos.y > 1.0) { p.pos.y = 2.0 - p.pos.y; p.vel.y = -p.vel.y; }

    // Gentle swirl plus damping, clamped so the field cannot run away.
    p.vel = (p.vel + float2(-p.vel.y, p.vel.x) * (0.8 * params.delta))
          * (1.0 - 0.25 * params.delta);
    float speed = length(p.vel);
    if (speed > 0.5)
    {
        p.vel *= 0.5 / speed;
    }

    particles[i] = p;
}
