struct VertexInput
{
    float3 position : TEXCOORD0;
    float4 color    : TEXCOORD1;
};

struct VertexOutput
{
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
};

VertexOutput vs_main(VertexInput input)
{
    VertexOutput output;
    output.position = float4(input.position, 1.0);
    output.color = input.color;
    return output;
}
