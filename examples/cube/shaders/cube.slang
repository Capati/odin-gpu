struct VertexOut {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

[[vk::binding(0, 0)]]
cbuffer Uniforms : register(b0) {
    float4x4 mvpMat;
};

[shader("vertex")]
VertexOut vs_main(
    float3 position : POSITION,
    float3 color : COLOR
) {
    VertexOut output;
    output.position = mul(mvpMat, float4(position, 1.0));
    output.color = float4(color, 1.0);
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOut fragData) : SV_Target {
    return fragData.color;
}
