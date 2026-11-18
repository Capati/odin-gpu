#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 5 0
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

#line 15
layout(std430, binding = 1) readonly buffer StructuredBuffer_uint_t_0 {
    uint _data[];
} grid_0;

#line 17
layout(location = 0)
out vec4 entryPointParam_vs_main_color_0;


#line 17
struct VSOut_0
{
    vec4 color_0;
    vec4 pos_0;
};


#line 32
void main()
{

#line 32
    uint _S1 = uint(gl_VertexIndex);

#line 32
    uint _S2 = uint(gl_InstanceIndex);

    VSOut_0 output_0;

#line 34
    bool _S3;


    if(_S2 >= (params_0.size_0.x * params_0.size_0.y))
    {

#line 37
        _S3 = true;

#line 37
    }
    else
    {

#line 37
        _S3 = (grid_0._data[uint(_S2)]) == 0U;

#line 37
    }

#line 37
    if(_S3)
    {

        output_0.pos_0 = vec4(2.0, 2.0, 2.0, 1.0);
        output_0.color_0 = vec4(0.0, 0.0, 0.0, 1.0);
        VSOut_0 _S4 = output_0;

#line 42
        entryPointParam_vs_main_color_0 = output_0.color_0;

#line 42
        gl_Position = _S4.pos_0;

#line 42
        return;
    }


    const vec2 _S5 = vec2(-1.0, -1.0);

#line 46
    const vec2 _S6 = vec2(1.0, 1.0);

#line 45
    const vec2  corners_0[6] = { _S5, vec2(1.0, -1.0), _S6, _S5, vec2(-1.0, 1.0), _S6 };

#line 50
    uint _S7 = _S2 % params_0.size_0.x;

#line 50
    float _S8 = float(_S7);

#line 50
    uint _S9 = _S2 / params_0.size_0.x;

#line 50
    float _S10 = float(_S9);
    vec2 cell_size_0 = params_0.resolution_0 / vec2(params_0.size_0);



    vec2 pixel_0 = (vec2(_S8, _S10) + 0.5) * cell_size_0 + corners_0[_S1] * cell_size_0 * 0.5;

    output_0.pos_0 = vec4(pixel_0.x / params_0.resolution_0.x * 2.0 - 1.0, 1.0 - pixel_0.y / params_0.resolution_0.y * 2.0, 0.0, 1.0);

#line 67
    output_0.color_0 = vec4(0.34999999403953552 + 0.64999997615814209 * (0.5 + 0.5 * cos(6.28318023681640625 * (vec3(_S8, _S10, _S8 + _S10) / 24.0 + vec3(0.0, 0.33000001311302185, 0.67000001668930054)))), 1.0);
    VSOut_0 _S11 = output_0;

#line 68
    entryPointParam_vs_main_color_0 = output_0.color_0;

#line 68
    gl_Position = _S11.pos_0;

#line 68
    return;
}

