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
struct Particle_std430_0
{
    @align(8) pos_0 : vec2<f32>,
    @align(8) vel_0 : vec2<f32>,
};

@binding(1) @group(0) var<storage, read_write> particles_0 : array<Particle_std430_0>;

struct Particle_0
{
     pos_0 : vec2<f32>,
     vel_0 : vec2<f32>,
};

@compute
@workgroup_size(64, 1, 1)
fn cs_main(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var i_0 : u32 = tid_0.x;
    if(i_0 >= (params_0.count_0))
    {
        return;
    }
    var p_0 : Particle_0;
    p_0.pos_0 = particles_0[i_0].pos_0;
    p_0.vel_0 = particles_0[i_0].vel_0;
    var _S1 : vec2<f32> = p_0.pos_0 + p_0.vel_0 * vec2<f32>(params_0.delta_0);
    p_0.pos_0 = _S1;
    if((_S1.x) < 0.0f)
    {
        p_0.pos_0[i32(0)] = - p_0.pos_0.x;
        p_0.vel_0[i32(0)] = - p_0.vel_0.x;
    }
    if((p_0.pos_0.x) > 1.0f)
    {
        p_0.pos_0[i32(0)] = 2.0f - p_0.pos_0.x;
        p_0.vel_0[i32(0)] = - p_0.vel_0.x;
    }
    if((p_0.pos_0.y) < 0.0f)
    {
        p_0.pos_0[i32(1)] = - p_0.pos_0.y;
        p_0.vel_0[i32(1)] = - p_0.vel_0.y;
    }
    if((p_0.pos_0.y) > 1.0f)
    {
        p_0.pos_0[i32(1)] = 2.0f - p_0.pos_0.y;
        p_0.vel_0[i32(1)] = - p_0.vel_0.y;
    }
    var _S2 : vec2<f32> = (p_0.vel_0 + vec2<f32>(- p_0.vel_0.y, p_0.vel_0.x) * vec2<f32>((0.80000001192092896f * params_0.delta_0))) * vec2<f32>((1.0f - 0.25f * params_0.delta_0));
    p_0.vel_0 = _S2;
    var speed_0 : f32 = length(_S2);
    if(speed_0 > 0.5f)
    {
        p_0.vel_0 = p_0.vel_0 * vec2<f32>((0.5f / speed_0));
    }
    particles_0[i_0].pos_0 = p_0.pos_0;
    particles_0[i_0].vel_0 = p_0.vel_0;
    return;
}

