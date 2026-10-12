struct Viewport_std140_0
{
    @align(16) x_0 : f32,
    @align(4) y_0 : f32,
    @align(8) w_0 : f32,
    @align(4) h_0 : f32,
};

@binding(0) @group(0) var<uniform> viewport_0 : Viewport_std140_0;
const kUV_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( vec2<f32>(1.0f, 0.0f), vec2<f32>(1.0f, 1.0f), vec2<f32>(0.0f, 1.0f), vec2<f32>(1.0f, 0.0f), vec2<f32>(0.0f, 1.0f), vec2<f32>(0.0f, 0.0f) );
const kPos_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( vec2<f32>(1.0f, 1.0f), vec2<f32>(1.0f, -1.0f), vec2<f32>(-1.0f, -1.0f), vec2<f32>(1.0f, 1.0f), vec2<f32>(-1.0f, -1.0f), vec2<f32>(-1.0f, 1.0f) );
struct VertexOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) fragUV_0 : vec2<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex_0 : u32) -> VertexOutput_0
{
    var _S1 : vec4<f32> = vec4<f32>(kPos_0[vertexIndex_0], 0.0f, 1.0f);
    var position_1 : vec4<f32> = _S1;
    position_1[i32(0)] = _S1.x * viewport_0.w_0 + (viewport_0.x_0 + viewport_0.w_0 - 1.0f + viewport_0.x_0) * _S1.w;
    position_1[i32(1)] = position_1.y * viewport_0.h_0 + (viewport_0.y_0 + viewport_0.h_0 - 1.0f + viewport_0.y_0) * position_1.w;
    var output_0 : VertexOutput_0;
    output_0.position_0 = position_1;
    output_0.fragUV_0 = kUV_0[vertexIndex_0];
    return output_0;
}

