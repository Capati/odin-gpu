#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 11 0
struct SimParams_0
{
    vec2 resolution_0;
    float time_0;
    float delta_0;
    uint count_0;
    float size_0;
    vec2 pad_0;
};


layout(binding = 0)
layout(std140) uniform block_SimParams_0
{
    vec2 resolution_0;
    float time_0;
    float delta_0;
    uint count_0;
    float size_0;
    vec2 pad_0;
}params_0;

#line 5
struct Particle_0
{
    vec2 pos_0;
    vec2 vel_0;
};


#line 25
layout(std430, binding = 1) buffer StructuredBuffer_Particle_t_0 {
    Particle_0 _data[];
} particles_0;

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main()
{

#line 31
    uint i_0 = gl_GlobalInvocationID.x;
    if(i_0 >= (params_0.count_0))
    {
        return;
    }

    Particle_0 p_0 = particles_0._data[uint(i_0)];

    vec2 _S1 = p_0.pos_0 + p_0.vel_0 * params_0.delta_0;

#line 39
    p_0.pos_0 = _S1;


    if((_S1.x) < 0.0)
    {

#line 42
        p_0.pos_0[0] = - p_0.pos_0.x;

#line 42
        p_0.vel_0[0] = - p_0.vel_0.x;

#line 42
    }
    if((p_0.pos_0.x) > 1.0)
    {

#line 43
        p_0.pos_0[0] = 2.0 - p_0.pos_0.x;

#line 43
        p_0.vel_0[0] = - p_0.vel_0.x;

#line 43
    }
    if((p_0.pos_0.y) < 0.0)
    {

#line 44
        p_0.pos_0[1] = - p_0.pos_0.y;

#line 44
        p_0.vel_0[1] = - p_0.vel_0.y;

#line 44
    }
    if((p_0.pos_0.y) > 1.0)
    {

#line 45
        p_0.pos_0[1] = 2.0 - p_0.pos_0.y;

#line 45
        p_0.vel_0[1] = - p_0.vel_0.y;

#line 45
    }



    vec2 _S2 = (p_0.vel_0 + vec2(- p_0.vel_0.y, p_0.vel_0.x) * (0.80000001192092896 * params_0.delta_0)) * (1.0 - 0.25 * params_0.delta_0);

#line 48
    p_0.vel_0 = _S2;

    float speed_0 = length(_S2);
    if(speed_0 > 0.5)
    {
        p_0.vel_0 = p_0.vel_0 * (0.5 / speed_0);

#line 51
    }

#line 56
    particles_0._data[uint(i_0)] = p_0;
    return;
}

