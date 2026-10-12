struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) direction_0 : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex_0 : u32) -> VertexOutput_0
{
    var pos_0 : array<vec2<f32>, i32(3)> = array<vec2<f32>, i32(3)>( vec2<f32>(-1.0f, -1.0f), vec2<f32>(-1.0f, 3.0f), vec2<f32>(3.0f, -1.0f) );
    var output_0 : VertexOutput_0;
    output_0.position_0 = vec4<f32>(pos_0[vertexIndex_0], 0.0f, 1.0f);
    output_0.direction_0 = vec4<f32>(pos_0[vertexIndex_0], -1.0f, 1.0f);
    return output_0;
}

