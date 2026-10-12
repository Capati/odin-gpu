struct VSOut_0
{
    @location(0) coord_0 : vec2<f32>,
    @builtin(position) pos_0 : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx_0 : u32) -> VSOut_0
{
    const _S1 : vec2<f32> = vec2<f32>(-1.0f, -1.0f);
    const _S2 : vec2<f32> = vec2<f32>(1.0f, 1.0f);
    var data_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( _S1, vec2<f32>(1.0f, -1.0f), _S2, _S1, vec2<f32>(-1.0f, 1.0f), _S2 );
    var out_0 : VSOut_0;
    out_0.pos_0 = vec4<f32>(data_0[idx_0], 0.0f, 1.0f);
    out_0.coord_0[i32(0)] = (data_0[idx_0].x + 1.0f) / 2.0f;
    out_0.coord_0[i32(1)] = (1.0f - data_0[idx_0].y) / 2.0f;
    return out_0;
}

