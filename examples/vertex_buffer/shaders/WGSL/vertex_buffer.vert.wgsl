struct VSOutput_0
{
    @builtin(position) pos_0 : vec4<f32>,
    @location(0) color_0 : f32,
};

struct vertexInput_0
{
    @location(0) pos_1 : vec2<f32>,
    @location(1) color_1 : f32,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VSOutput_0
{
    var output_0 : VSOutput_0;
    output_0.pos_0 = vec4<f32>(_S1.pos_1, 0.0f, 1.0f);
    output_0.color_0 = _S1.color_1;
    return output_0;
}

