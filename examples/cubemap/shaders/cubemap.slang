struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

struct VertexInput {
    float4 position : POSITION;
    float2 uv : TEXCOORD0;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 fragUV : TEXCOORD0;
    float4 fragPosition : TEXCOORD1;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    output.position = mul(uniforms.modelViewProjectionMatrix, input.position);
    output.fragUV = input.uv;
    output.fragPosition = 0.5 * (input.position + float4(1.0, 1.0, 1.0, 1.0));
    return output;
}

struct FragmentInput {
    float4 position : SV_Position;
    float2 fragUV : TEXCOORD0;
    float4 fragPosition : TEXCOORD1;
};

#if defined(USE_COMBINED_SAMPLER)

[[vk::binding(1, 0)]]
SamplerCube mySampler : register(t1);

#else

[[vk::binding(1, 0)]]
TextureCube myTexture : register(t1);

[[vk::binding(2, 0)]]
SamplerState mySampler : register(s2);

#endif

[shader("fragment")]
float4 fs_main(FragmentInput input) : SV_Target {
    // Our camera and the skybox cube are both centered at (0, 0, 0)
    // so we can use the cube geometry position to get viewing vector to sample
    // the cube texture. The magnitude of the vector doesn't matter.
    float3 cubemapVec = input.fragPosition.xyz - float3(0.5, 0.5, 0.5);

    // When viewed from the inside, cubemaps are left-handed (z away from viewer),
    // but common camera matrix convention results in a right-handed world space
    // (z toward viewer), so we have to flip it.
    cubemapVec.z = -cubemapVec.z;

#if defined(USE_COMBINED_SAMPLER)
    return mySampler.Sample(cubemapVec);
#else
    return myTexture.Sample(mySampler, cubemapVec);
#endif
}
