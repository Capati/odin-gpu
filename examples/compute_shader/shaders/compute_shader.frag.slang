struct FSIn
{
    float4 color : COLOR;
};

[shader("fragment")]
float4 fs_main(FSIn input) : SV_Target
{
    return input.color;
}
