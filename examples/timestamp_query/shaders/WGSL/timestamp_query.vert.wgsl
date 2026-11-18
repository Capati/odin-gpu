struct VSOut_0
{
    @location(0) uv_0 : vec2<f32>,
    @builtin(position) pos_0 : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vid_0 : u32) -> VSOut_0
{
    var pos_1 : array<vec2<f32>, i32(3)> = array<vec2<f32>, i32(3)>( vec2<f32>(-1.0f, -3.0f), vec2<f32>(-1.0f, 1.0f), vec2<f32>(3.0f, 1.0f) );
    var output_0 : VSOut_0;
    output_0.pos_0 = vec4<f32>(pos_1[vid_0], 0.0f, 1.0f);
    var _S1 : vec2<f32> = vec2<f32>(0.5f);
    output_0.uv_0 = pos_1[vid_0] * _S1 + _S1;
    return output_0;
}

