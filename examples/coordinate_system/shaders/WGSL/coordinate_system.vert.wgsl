struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) pos_0 : vec3<f32>,
    @location(1) uv_1 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VSOutput_0
{
    var output_0 : VSOutput_0;
    output_0.uv_0 = _S1.uv_1;
    output_0.position_0 = vec4<f32>(_S1.pos_0, 1.0f);
    return output_0;
}

