// cube_manual.hlsl
struct VertexOut {
    float4 position : SV_Position;
    float4 color : COLOR0;
};

cbuffer Uniforms : register(b0) {
    float4x4 mvpMat;
};

VertexOut vs_main(float3 position : POSITION, float3 color : COLOR) {
    VertexOut output;
    output.position = mul(mvpMat, float4(position, 1.0));
    output.color = float4(color, 1.0);
    return output;
}

float4 fs_main(VertexOut fragData) : SV_Target {
    return fragData.color;
}
