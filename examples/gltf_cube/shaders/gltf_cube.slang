[[vk::binding(0, 0)]]
ConstantBuffer<float4x4> mvp : register(b0);

struct VertexInput {
    float3 position : POSITION;
    float3 normal   : NORMAL;
};

struct VertexOutput {
    float4 position : SV_Position;
    float3 normal   : NORMAL0;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(mvp, float4(input.position, 1.0));
    output.normal = input.normal;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target0 {
    float3 n = normalize(input.normal);
    return float4(n * 0.5 + 0.5, 1.0);
}
