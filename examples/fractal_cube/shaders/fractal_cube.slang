struct Uniforms {
    float4x4 transform;
};

struct VertexInput {
    float4 position : POSITION;
    float2 tex_coord : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(uniforms.transform, input.position);
    output.tex_coord = input.tex_coord;
    output.frag_position = 0.5 * (input.position + float4(1.0, 1.0, 1.0, 1.0));
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 tex_coord : TEXCOORD0;
    float4 frag_position : TEXCOORD1;
};

#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(1, 0)]]
Sampler2D r_color : register(t1);

#else

[[vk::binding(1, 0)]]
Texture2D r_color_texture : register(t1);

[[vk::binding(2, 0)]]
SamplerState r_color_sampler : register(s2);

#endif

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    float4 texColor;

#if defined(USE_COMBINED_SAMPLER)
    texColor = r_color.Sample(input.tex_coord * 0.8 + float2(0.1, 0.1));
#else
    texColor = r_color_texture.Sample(r_color_sampler, input.tex_coord * 0.8 + float2(0.1, 0.1));
#endif

    // The threshold of 0.01 used in the shader depends on the base gray color
    float f = length(texColor.rgb - float3(0.5, 0.5, 0.5)) < 0.01 ? 0.0 : 1.0;
    return f * texColor + (1.0 - f) * input.frag_position;
}
