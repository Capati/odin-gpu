// Uniform buffer
struct Uniforms
{
    uint offset;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0, space0);

static uint state;

// From https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
uint pcg_hash(uint input)
{
    state = input * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

struct VSInput
{
    [[vk::location(0)]] float2 position : POSITION;
};

struct VSOutput
{
    float4 position : SV_Position;
};

[shader("vertex")]
VSOutput vs_main(VSInput input)
{
    VSOutput output;
    output.position = float4(input.position, 0.0, 1.0);
    return output;
}

struct FSInput
{
    float4 position : SV_Position;
};

struct FSOutput
{
    [[vk::location(0)]] float4 color : SV_Target0;
};

[shader("fragment")]
FSOutput fs_main(FSInput input)
{
    FSOutput output;

    uint seed = uint(512.0 * input.position.y + input.position.x) + uniforms.offset;
    uint pcg = pcg_hash(seed);
    float v = float(pcg) * (1.0 / 4294967295.0);

    output.color = float4(v, v, v, 1.0);
    return output;
}
