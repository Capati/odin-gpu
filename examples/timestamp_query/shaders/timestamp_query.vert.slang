// Fullscreen triangle from the vertex index, no vertex buffer.

struct VSOut
{
    float2 uv  : TEXCOORD0;
    float4 pos : SV_Position;
};

#if defined(__SPIRV__) || defined(__GLSL__)
    #define VERTEX_ID_SEMANTIC SV_VulkanVertexID
#else
    #define VERTEX_ID_SEMANTIC SV_VertexID
#endif

[shader("vertex")]
VSOut vs_main(uint vid : VERTEX_ID_SEMANTIC)
{
    // Oversized triangle covering the viewport.
    float2 pos[3] = {
        float2(-1.0, -3.0),
        float2(-1.0,  1.0),
        float2( 3.0,  1.0),
    };

    VSOut output;
    output.pos = float4(pos[vid], 0.0, 1.0);
    output.uv  = pos[vid] * 0.5 + 0.5;
    return output;
}
