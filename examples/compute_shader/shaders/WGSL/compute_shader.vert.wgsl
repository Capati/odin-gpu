struct Particle_std430_0
{
    @align(8) pos_0 : vec2<f32>,
    @align(8) vel_0 : vec2<f32>,
};

@binding(1) @group(0) var<storage, read> particles_0 : array<Particle_std430_0>;

struct SimParams_std140_0
{
    @align(16) resolution_0 : vec2<f32>,
    @align(8) time_0 : f32,
    @align(4) delta_0 : f32,
    @align(16) count_0 : u32,
    @align(4) size_0 : f32,
    @align(8) pad_0 : vec2<f32>,
};

@binding(0) @group(0) var<uniform> params_0 : SimParams_std140_0;
struct VSOut_0
{
    @location(0) color_0 : vec4<f32>,
    @builtin(position) pos_1 : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vid_0 : u32, @builtin(instance_index) iid_0 : u32) -> VSOut_0
{
    var p_0 : Particle_std430_0 = particles_0[iid_0];
    const _S1 : vec2<f32> = vec2<f32>(-1.0f, -1.0f);
    const _S2 : vec2<f32> = vec2<f32>(1.0f, 1.0f);
    var corners_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( _S1, vec2<f32>(1.0f, -1.0f), _S2, _S1, vec2<f32>(-1.0f, 1.0f), _S2 );
    var _S3 : vec3<f32> = vec3<f32>(0.5f);
    var hue_0 : vec3<f32> = _S3 + _S3 * cos(vec3<f32>(6.28318023681640625f) * (p_0.pos_0.xyx + vec3<f32>(0.0f, 0.33000001311302185f, 0.67000001668930054f)));
    var speed_0 : f32 = saturate(length(p_0.vel_0) * 4.0f);
    var output_0 : VSOut_0;
    output_0.pos_1 = vec4<f32>(vec2<f32>(p_0.pos_0.x * 2.0f - 1.0f, 1.0f - p_0.pos_0.y * 2.0f) + corners_0[vid_0] * (vec2<f32>(params_0.size_0) / params_0.resolution_0), 0.0f, 1.0f);
    output_0.color_0 = vec4<f32>(hue_0 * vec3<f32>((0.44999998807907104f + 0.55000001192092896f * speed_0)), 1.0f);
    return output_0;
}

