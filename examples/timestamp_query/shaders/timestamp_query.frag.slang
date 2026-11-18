// A deliberately expensive fragment shader: the pass has to do measurable GPU
// work or the timestamp delta would be lost in timer granularity.

// Scalars, not a `float3`: inside a constant buffer a vector member is aligned
// to 16 bytes, which would pad this block to 32 and disagree with the 16-byte
// `Time_Params` the host declares. WebGPU validates that mismatch
// (`minBindingSize`), Vulkan happens not to.
struct TimeParams
{
    float time;
    float pad0;
    float pad1;
    float pad2;
};

[[vk::binding(0, 0)]]
ConstantBuffer<TimeParams> params : register(b0);

struct FSIn
{
    float2 uv : TEXCOORD0;
};

[shader("fragment")]
float4 fs_main(FSIn input) : SV_Target
{
    // Iterated fractal distance field. The iteration count is fixed, so the cost
    // per pixel is stable and the timestamp readout tracks resolution rather than
    // drifting with the animation.
    float2 c = (input.uv - 0.5) * 3.0;
    float2 z = c;
    float  t = 0.0;

    for (int i = 0; i < 64; i++)
    {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        t += exp(-8.0 * length(z));
    }

    float3 hue = 0.5 + 0.5 * cos(6.28318 * (t * 0.15 + params.time + float3(0.0, 0.33, 0.67)));
    return float4(hue * 0.8, 1.0);
}
