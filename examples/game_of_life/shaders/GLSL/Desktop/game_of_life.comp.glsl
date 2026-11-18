#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 4 0
struct GridParams_0
{
    uvec2 size_0;
    vec2 resolution_0;
};


layout(binding = 0)
layout(std140) uniform block_GridParams_0
{
    uvec2 size_0;
    vec2 resolution_0;
}params_0;

#line 14
layout(std430, binding = 1) readonly buffer StructuredBuffer_uint_t_0 {
    uint _data[];
} src_0;
layout(std430, binding = 2) buffer StructuredBuffer_uint_t_1 {
    uint _data[];
} dst_0;



layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;
void main()
{

#line 25
    uvec2 cell_0 = gl_GlobalInvocationID.xy;

#line 25
    bool alive_0;
    if((cell_0.x) >= (params_0.size_0.x))
    {

#line 26
        alive_0 = true;

#line 26
    }
    else
    {

#line 26
        alive_0 = (cell_0.y) >= (params_0.size_0.y);

#line 26
    }

#line 26
    if(alive_0)
    {
        return;
    }

    ivec2 _S1 = ivec2(params_0.size_0);
    ivec2 _S2 = ivec2(cell_0);

#line 32
    int dy_0 = -1;

#line 32
    uint neighbours_0 = 0U;



    for(;;)
    {

#line 36
        if(dy_0 <= 1)
        {
        }
        else
        {

#line 36
            break;
        }

#line 36
        int dx_0 = -1;

#line 36
        uint neighbours_1 = neighbours_0;

        for(;;)
        {

#line 38
            if(dx_0 <= 1)
            {
            }
            else
            {

#line 38
                break;
            }
            if(dx_0 == 0)
            {

#line 40
                alive_0 = dy_0 == 0;

#line 40
            }
            else
            {

#line 40
                alive_0 = false;

#line 40
            }

#line 40
            if(alive_0)
            {
                dx_0 = dx_0 + 1;

#line 38
                continue;
            }

#line 44
            ivec2 n_0 = (_S2 + ivec2(dx_0, dy_0) + _S1) % _S1;

#line 44
            neighbours_1 = neighbours_1 + src_0._data[uint(n_0.y * _S1.x + n_0.x)];

#line 38
            dx_0 = dx_0 + 1;

#line 38
        }

#line 36
        dy_0 = dy_0 + 1;

#line 36
        neighbours_0 = neighbours_1;

#line 36
    }

#line 49
    int _S3 = _S2.y * _S1.x + _S2.x;

#line 49
    uint self_0 = src_0._data[uint(_S3)];


    if(neighbours_0 == 3U)
    {

#line 52
        alive_0 = true;

#line 52
    }
    else
    {

#line 52
        if(self_0 != 0U)
        {

#line 52
            alive_0 = neighbours_0 == 2U;

#line 52
        }
        else
        {

#line 52
            alive_0 = false;

#line 52
        }

#line 52
    }

    if(alive_0)
    {

#line 54
        dy_0 = 1;

#line 54
    }
    else
    {

#line 54
        dy_0 = 0;

#line 54
    }

#line 54
    dst_0._data[uint(_S3)] = uint(dy_0);
    return;
}

