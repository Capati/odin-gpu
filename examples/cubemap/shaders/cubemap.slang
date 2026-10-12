// Cubemap sampling example.
//
// A fullscreen triangle covers clip space, and the fragment shader uses the
// inverse view-projection matrix to turn each pixel into a cubemap sampling
// direction, so no vertex buffers or depth attachment are needed.
//
// Ref: https://github.com/webgpu/webgpu-samples/tree/main/sample/cubemap

struct Uniforms {
    float4x4 viewDirectionProjectionInverse;
};

#if defined(__SPIRV__) || defined(__GLSL__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
#endif

struct VertexInput {
    uint vertexIndex : VERTEX_ID_SEMANTIC;
};

struct VertexOutput {
    float4 position : SV_Position;
    float4 direction : DIRECTION;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Uniforms> uniforms : register(b0);

[shader("vertex")]
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;

    // A triangle large enough to cover all of clip space.
    float2 pos[3] = {
        float2(-1.0, -1.0),
        float2(-1.0,  3.0),
        float2( 3.0, -1.0),
    };
    float2 p = pos[input.vertexIndex];

    // The position is returned twice: once for SV_Position, once so the
    // fragment shader receives values going from -1,-1 to 1,1 across the
    // entire screen.
    output.position  = float4(p, 0.0, 1.0);
    output.direction = float4(p, -1.0, 1.0);
    return output;
}

[[vk::binding(1, 0)]]
SamplerState mySampler : register(s1);

[[vk::binding(2, 0)]]
TextureCube<float4> myTexture : register(t2);

struct FragmentOutput {
    float4 color : SV_Target0;
};

[shader("fragment")]
FragmentOutput fs_main(VertexOutput input) {
    FragmentOutput output;

    // Orient the direction to the view, then remove the perspective.
    float4 t = mul(uniforms.viewDirectionProjectionInverse, input.direction);
    float3 uvw = normalize(t.xyz / t.w);
    output.color = myTexture.Sample(mySampler, uvw);
    return output;
}
