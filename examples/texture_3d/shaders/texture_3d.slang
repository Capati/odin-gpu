struct Uniforms {
    float4x4 projection;
    float4x4 modelView;
    float4 viewPos;
    float depth;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> ubo : register(b0);

struct VertexInput {
    float3 position : POSITION;
    float2 uv       : TEXCOORD0;
    float3 normal   : NORMAL;
};

struct VertexOutput {
    float4 position  : SV_Position;
    float3 fragUV    : TEXCOORD0;
    float3 fragNormal: TEXCOORD1;
    float3 viewVec   : TEXCOORD2;
    float3 lightVec  : TEXCOORD3;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;

    // Add the animated slice coordinate to the quad's 2D texture coordinate.
    output.fragUV = float3(input.uv, ubo.depth);

    float4 viewPosition = mul(ubo.modelView, float4(input.position, 1.0));
    output.position = mul(ubo.projection, viewPosition);

    // The model-view matrix contains only rigid camera transforms here.
    float3x3 normalMatrix = (float3x3)ubo.modelView;
    output.fragNormal = mul(normalMatrix, input.normal);

    // The point light and viewer are both at the view-space origin.
    output.lightVec = -viewPosition.xyz;
    output.viewVec = ubo.viewPos.xyz - viewPosition.xyz;
    return output;
}

[[vk::binding(1, 0)]]
SamplerState texSampler : register(s1);

[[vk::binding(2, 0)]]
Texture3D<float4> texColor : register(t2);

struct FragmentInput {
    float4 position  : SV_Position;
    float3 fragUV    : TEXCOORD0;
    float3 fragNormal: TEXCOORD1;
    float3 viewVec   : TEXCOORD2;
    float3 lightVec  : TEXCOORD3;
};

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target0 {
    // The R8_UNorm volume stores its value in the red channel.
    float value = texColor.Sample(texSampler, input.fragUV).r;

    float3 normal = normalize(input.fragNormal);
    float3 light = normalize(input.lightVec);
    float3 view = normalize(input.viewVec);
    float3 reflected = reflect(-light, normal);

    float diffuse = max(dot(normal, light), 0.0);
    float specular = pow(max(dot(reflected, view), 0.0), 16.0) * value;
    return float4(float3(diffuse * value + specular), 1.0);
}
