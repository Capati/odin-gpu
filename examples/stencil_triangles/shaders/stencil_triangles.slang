struct VertexOutput {
    float4 position: SV_Position;
};

[shader("vertex")]
VertexOutput vs_main(float4 position: POSITION) {
    VertexOutput result;
    result.position = position;
    return result;
}

[shader("fragment")]
float4 fs_main(VertexOutput vertex): SV_Target {
    return float4(0.97, 0.88, 0.21, 1.0);
}
