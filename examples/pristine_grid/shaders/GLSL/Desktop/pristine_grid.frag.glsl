#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 24 0
struct GridArgs_0
{
    vec4 lineColor_0;
    vec4 baseColor_0;
    vec2 lineWidth_0;
    vec2 padding_0;
};


#line 45
layout(binding = 0, set = 1)
layout(std140) uniform block_GridArgs_0
{
    vec4 lineColor_0;
    vec4 baseColor_0;
    vec2 lineWidth_0;
    vec2 padding_0;
}gridArgs_0;

#line 14034 1
vec2 saturate_0(vec2 x_0)
{

#line 14042
    return clamp(x_0, vec2(0.0), vec2(1.0));
}


#line 1 0
float PristineGrid_0(vec2 uv_0, vec2 lineWidth_1)
{

#line 2
    vec4 uvDDXY_0 = vec4(dFdx(uv_0), dFdy(uv_0));
    vec2 uvDeriv_0 = vec2(length(uvDDXY_0.xz), length(uvDDXY_0.yw));
    bvec2 invertLine_0 = greaterThan(lineWidth_1,vec2(0.5));
    vec2 targetWidth_0 = mix(lineWidth_1, 1.0 - lineWidth_1, invertLine_0);
    vec2 drawWidth_0 = clamp(targetWidth_0, uvDeriv_0, vec2(0.5));
    vec2 lineAA_0 = uvDeriv_0 * 1.5;
    vec2 gridUV_0 = abs(fract(uv_0) * 2.0 - 1.0);



    vec2 grid2_0 = mix(smoothstep(drawWidth_0 + lineAA_0, drawWidth_0 - lineAA_0, mix(1.0 - gridUV_0, gridUV_0, invertLine_0)) * saturate_0(targetWidth_0 / drawWidth_0), targetWidth_0, saturate_0(uvDeriv_0 * 2.0 - 1.0));
    vec2 grid2_1 = mix(grid2_0, 1.0 - grid2_0, invertLine_0);
    return mix(grid2_1.x, 1.0, grid2_1.y);
}


#line 14
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 14
layout(location = 0)
in vec2 input_uv_0;


#line 56
void main()
{

#line 56
    entryPointParam_fs_main_0 = mix(gridArgs_0.baseColor_0, gridArgs_0.lineColor_0, vec4(PristineGrid_0(input_uv_0, gridArgs_0.lineWidth_0) * gridArgs_0.lineColor_0.w));

#line 56
    return;
}

