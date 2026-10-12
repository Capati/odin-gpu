#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
layout(location = 0)
out vec2 entryPointParam_vs_main_coord_0;


#line 1
struct VSOut_0
{
    vec2 coord_0;
    vec4 pos_0;
};


#line 13
void main()
{

#line 13
    uint _S1 = uint(gl_VertexIndex);


    const vec2 _S2 = vec2(-1.0, -1.0);

    const vec2 _S3 = vec2(1.0, 1.0);

#line 15
    const vec2  data_0[6] = { _S2, vec2(1.0, -1.0), _S3, _S2, vec2(-1.0, 1.0), _S3 };

#line 27
    VSOut_0 out_0;
    out_0.pos_0 = vec4(data_0[_S1], 0.0, 1.0);
    out_0.coord_0[0] = (data_0[_S1].x + 1.0) / 2.0;
    out_0.coord_0[1] = (1.0 - data_0[_S1].y) / 2.0;

    VSOut_0 _S4 = out_0;

#line 32
    entryPointParam_vs_main_coord_0 = out_0.coord_0;

#line 32
    gl_Position = _S4.pos_0;

#line 32
    return;
}

