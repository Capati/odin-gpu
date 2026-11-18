// Lit cube with a per-object transform and colour.
//
// The normal is rotated by the world matrix (no non-uniform scaling, so the
// upper 3x3 is enough and an inverse-transpose is not needed).

struct Uniforms {
    float4x4 world_view_projection;
    float4x4 world;
    float4 color;
};

[[vk::binding(0, 0)]]
cbuffer uniforms : register(b0) {
    Uniforms u;
};

struct VertexOut {
    float3 normal : NORMAL;
    float4 position : SV_Position;
};

[shader("vertex")]
VertexOut vs_main(
    float3 position : POSITION,
    float3 normal : NORMAL
) {
    VertexOut output;
    output.position = mul(u.world_view_projection, float4(position, 1.0));
    output.normal = mul((float3x3)u.world, normal);
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOut input) : SV_Target {
    float3 light_direction = normalize(float3(4.0, 10.0, 6.0));
    float light = saturate(dot(normalize(input.normal), light_direction) * 0.5 + 0.5);
    return float4(u.color.rgb * light, u.color.a);
}
