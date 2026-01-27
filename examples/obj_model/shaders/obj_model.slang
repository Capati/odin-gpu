struct VertexInput {
    float3 position : POSITION;
    float3 normal : NORMAL;
    float3 color : COLOR;
};

struct VertexOutput {
    float4 position : SV_POSITION;
    float3 normal : NORMAL;
    float3 color : COLOR;
};

struct MyUniforms {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float4x4 modelMatrix;
};

[[vk::binding(0, 0)]]
ConstantBuffer<MyUniforms> uMyUniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;

    float4 worldPosition = mul(uMyUniforms.modelMatrix, float4(input.position, 1.0));
    float4 viewPosition = mul(uMyUniforms.viewMatrix, worldPosition);
    output.position = mul(uMyUniforms.projectionMatrix, viewPosition);

    // Forward the normal
    output.normal = mul(uMyUniforms.modelMatrix, float4(input.normal, 0.0)).xyz;
    output.color = input.color;

    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float3 normal : NORMAL;
    float3 color : COLOR;
};

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    float3 normal = normalize(input.normal);

    // Gray base color
    float3 baseColor = float3(0.8, 0.8, 0.8);  // Light gray

    // Simple diffuse lighting with ambient
    float3 lightDirection = normalize(float3(0.5, 1.0, -0.5));  // Light from top-right
    float diffuse = max(0.0, dot(normal, lightDirection));

    float ambient = 0.3;  // Ambient light to prevent pure black
    float3 lighting = float3(ambient + diffuse * 0.7);

    float3 color = baseColor * lighting;

    // Gamma correction
    // float3 corrected_color = pow(saturate(color), float3(2.2, 2.2, 2.2));
    return float4(color, 1.0);
}
