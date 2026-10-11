struct Uniforms {
    float4x4 transform;
};

struct VertexInput {
    float2 position : POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(uniforms.transform, float4(input.position, 0.0, 1.0));
    output.uv = input.uv;
    output.color = input.color;
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

[[vk::binding(1, 0)]]
Texture2D r_color_texture : register(t1);

[[vk::binding(2, 0)]]
SamplerState r_color_sampler : register(s2);

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    float4 atlas_color = r_color_texture.Sample(r_color_sampler, input.uv);
    return atlas_color * input.color;
}
