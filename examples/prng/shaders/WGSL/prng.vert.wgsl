struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec2<f32>,
};

@vertex
fn vs_main( _S1 : vertexInput_0) -> VSOutput_0
{
    var output_0 : VSOutput_0;
    output_0.position_0 = vec4<f32>(_S1.position_1, 0.0f, 1.0f);
    return output_0;
}

