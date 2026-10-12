struct Uniforms_std140_0
{
    @align(16) offset_0 : u32,
};

@binding(0) @group(0) var<uniform> uniforms_0 : Uniforms_std140_0;
var<private> state_0 : u32;

fn pcg_hash_0( input_0 : u32) -> u32
{
    var _S1 : u32 = input_0 * u32(747796405) + u32(2891336453);
    state_0 = _S1;
    var word_0 : u32 = ((((_S1 >> ((((_S1 >> (u32(28)))) + u32(4))))) ^ (_S1))) * u32(277803737);
    return (((word_0 >> (u32(22)))) ^ (word_0));
}

struct FSOutput_0
{
    @location(0) color_0 : vec4<f32>,
};

@fragment
fn fs_main(@builtin(position) position_0 : vec4<f32>) -> FSOutput_0
{
    var pcg_0 : u32 = pcg_hash_0(u32(512.0f * position_0.y + position_0.x) + uniforms_0.offset_0);
    var v_0 : f32 = f32(pcg_0) * 2.32830643653869629e-10f;
    var output_0 : FSOutput_0;
    output_0.color_0 = vec4<f32>(v_0, v_0, v_0, 1.0f);
    return output_0;
}

