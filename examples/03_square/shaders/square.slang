// Vertex Shader
struct VertexInput
{
    float3 position : POSITION;
    float4 color : COLOR;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float4 color : COLOR;
};

[shader("vertex")]
VertexOutput vs_main(VertexInput input)
{
    VertexOutput output;
    output.color = input.color;
    output.position = float4(input.position, 1.0);
    return output;
}

// Fragment Shader
struct FragmentOutput
{
    float4 color : SV_Target0;
};

[shader("fragment")]
FragmentOutput fs_main(VertexOutput input)
{
    FragmentOutput output;
    output.color = input.color;
    return output;
}
