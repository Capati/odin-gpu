struct VertexOut {
    float4 position : SV_Position;
    float2 tex_coords : TEXCOORD0;
    float4 color : COLOR0;
};

[[vk::binding(0, 0)]]
cbuffer Uniforms : register(b0) {
    float4x4 modelViewProjectionMatrix;
};

[shader("vertex")]
VertexOut vs_main(
    float4 position : POSITION,
    float4 color : COLOR,
    float2 uv : TEXCOORD
) {
    VertexOut output;
    output.position = mul(modelViewProjectionMatrix, position);
    output.tex_coords = uv;
    output.color = color;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOut fragData) : SV_Target {
    return fragData.color;
}
