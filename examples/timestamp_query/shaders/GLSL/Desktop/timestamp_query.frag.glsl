#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 8 0
struct TimeParams_0
{
    float time_0;
    float pad0_0;
    float pad1_0;
    float pad2_0;
};


layout(binding = 0)
layout(std140) uniform block_TimeParams_0
{
    float time_0;
    float pad0_0;
    float pad1_0;
    float pad2_0;
}params_0;
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 25
layout(location = 0)
in vec2 input_uv_0;


#line 25
void main()
{



    vec2 c_0 = (input_uv_0 - 0.5) * 3.0;

#line 30
    vec2 z_0 = c_0;

#line 30
    int i_0 = 0;

#line 30
    float t_0 = 0.0;



    for(;;)
    {

#line 34
        if(i_0 < 64)
        {
        }
        else
        {

#line 34
            break;
        }
        float _S1 = z_0.x;

#line 36
        float _S2 = z_0.y;

#line 36
        vec2 z_1 = vec2(_S1 * _S1 - _S2 * _S2, 2.0 * _S1 * _S2) + c_0;
        float t_1 = t_0 + exp(-8.0 * length(z_1));

#line 34
        int _S3 = i_0 + 1;

#line 34
        z_0 = z_1;

#line 34
        i_0 = _S3;

#line 34
        t_0 = t_1;

#line 34
    }

#line 34
    entryPointParam_fs_main_0 = vec4((0.5 + 0.5 * cos(6.28318023681640625 * (t_0 * 0.15000000596046448 + params_0.time_0 + vec3(0.0, 0.33000001311302185, 0.67000001668930054)))) * 0.80000001192092896, 1.0);

#line 34
    return;
}

