float PristineGrid(float2 uv, float2 lineWidth) {
    float4 uvDDXY = float4(ddx(uv), ddy(uv));
    float2 uvDeriv = float2(length(uvDDXY.xz), length(uvDDXY.yw));
    bool2 invertLine = lineWidth > 0.5;
    float2 targetWidth = invertLine ? 1.0 - lineWidth : lineWidth;
    float2 drawWidth = clamp(targetWidth, uvDeriv, 0.5);
    float2 lineAA = uvDeriv * 1.5;
    float2 gridUV = abs(fract(uv) * 2.0 - 1.0);
    gridUV = invertLine ? gridUV : 1.0 - gridUV;
    float2 grid2 = smoothstep(drawWidth + lineAA, drawWidth - lineAA, gridUV);
    grid2 *= saturate(targetWidth / drawWidth);
    grid2 = lerp(grid2, targetWidth, saturate(uvDeriv * 2.0 - 1.0));
    grid2 = invertLine ? 1.0 - grid2 : grid2;
    return lerp(grid2.x, 1.0, grid2.y);
}

struct Camera {
    float4x4 projection;
    float4x4 view;
    float3 position;
    float time;
};

struct GridArgs {
    float4 lineColor;
    float4 baseColor;
    float2 lineWidth;
    float2 padding;
};

struct VertexInput {
    float3 position : POSITION;
    float2 uv : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Camera> camera : register(b0);

[[vk::binding(0, 1)]]
ConstantBuffer<GridArgs> gridArgs : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(mul(camera.projection, camera.view), float4(input.position, 1.0));
    output.uv = input.uv;
    return output;
}

[shader("fragment")]
float4 fs_main(VertexOutput input) : SV_Target {
    float grid = PristineGrid(input.uv, gridArgs.lineWidth);
    return lerp(gridArgs.baseColor, gridArgs.lineColor, grid * gridArgs.lineColor.a);
}
