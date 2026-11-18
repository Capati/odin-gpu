#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 4 0
struct Particle_0
{
    vec2 pos_0;
    vec2 vel_0;
};


#line 24
layout(std430, binding = 1) readonly buffer StructuredBuffer_Particle_t_0 {
    Particle_0 _data[];
} particles_0;

#line 10
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

#line 14019 1
float saturate_0(float x_0)
{

#line 14027
    return clamp(x_0, 0.0, 1.0);
}


#line 26 0
layout(location = 0)
out vec4 entryPointParam_vs_main_color_0;


#line 26
struct VSOut_0
{
    vec4 color_0;
    vec4 pos_1;
};


#line 41
void main()
{
    Particle_0 p_0 = particles_0._data[uint(uint(gl_InstanceIndex))];


    const vec2 _S1 = vec2(-1.0, -1.0);

#line 46
    const vec2 _S2 = vec2(1.0, 1.0);

#line 45
    const vec2  corners_0[6] = { _S1, vec2(1.0, -1.0), _S2, _S1, vec2(-1.0, 1.0), _S2 };

#line 61
    vec3 hue_0 = 0.5 + 0.5 * cos(6.28318023681640625 * (p_0.pos_0.xyx + vec3(0.0, 0.33000001311302185, 0.67000001668930054)));
    float speed_0 = saturate_0(length(p_0.vel_0) * 4.0);

    VSOut_0 output_0;
    output_0.pos_1 = vec4(vec2(p_0.pos_0.x * 2.0 - 1.0, 1.0 - p_0.pos_0.y * 2.0) + corners_0[uint(gl_VertexIndex)] * (params_0.size_0 / params_0.resolution_0), 0.0, 1.0);
    output_0.color_0 = vec4(hue_0 * (0.44999998807907104 + 0.55000001192092896 * speed_0), 1.0);
    VSOut_0 _S3 = output_0;

#line 67
    entryPointParam_vs_main_color_0 = output_0.color_0;

#line 67
    gl_Position = _S3.pos_1;

#line 67
    return;
}

