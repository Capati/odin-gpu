struct GridArgs_std140_0
{
    @align(16) lineColor_0 : vec4<f32>,
    @align(16) baseColor_0 : vec4<f32>,
    @align(16) lineWidth_0 : vec2<f32>,
    @align(8) padding_0 : vec2<f32>,
};

@binding(0) @group(1) var<uniform> gridArgs_0 : GridArgs_std140_0;
fn PristineGrid_0( uv_0 : vec2<f32>,  lineWidth_1 : vec2<f32>) -> f32
{
    var uvDDXY_0 : vec4<f32> = vec4<f32>(dpdx(uv_0), dpdy(uv_0));
    var uvDeriv_0 : vec2<f32> = vec2<f32>(length(uvDDXY_0.xz), length(uvDDXY_0.yw));
    var invertLine_0 : vec2<bool> = lineWidth_1 > vec2<f32>(0.5f);
    var _S1 : vec2<f32> = vec2<f32>(1.0f);
    var targetWidth_0 : vec2<f32> = select(lineWidth_1, _S1 - lineWidth_1, invertLine_0);
    var drawWidth_0 : vec2<f32> = clamp(targetWidth_0, uvDeriv_0, vec2<f32>(0.5f));
    var lineAA_0 : vec2<f32> = uvDeriv_0 * vec2<f32>(1.5f);
    var _S2 : vec2<f32> = vec2<f32>(2.0f);
    var gridUV_0 : vec2<f32> = abs(fract(uv_0) * _S2 - _S1);
    var grid2_0 : vec2<f32> = mix(smoothstep(drawWidth_0 + lineAA_0, drawWidth_0 - lineAA_0, select(_S1 - gridUV_0, gridUV_0, invertLine_0)) * saturate(targetWidth_0 / drawWidth_0), targetWidth_0, saturate(uvDeriv_0 * _S2 - _S1));
    var grid2_1 : vec2<f32> = select(grid2_0, _S1 - grid2_0, invertLine_0);
    return mix(grid2_1.x, 1.0f, grid2_1.y);
}

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) uv_1 : vec2<f32>,
};

@fragment
fn fs_main( _S3 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S4 : pixelOutput_0 = pixelOutput_0( mix(gridArgs_0.baseColor_0, gridArgs_0.lineColor_0, vec4<f32>((PristineGrid_0(_S3.uv_1, gridArgs_0.lineWidth_0) * gridArgs_0.lineColor_0.w))) );
    return _S4;
}

