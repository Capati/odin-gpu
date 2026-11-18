#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 3 0
layout(location = 0)
out vec2 entryPointParam_vs_main_uv_0;


#line 3
struct VSOut_0
{
    vec2 uv_0;
    vec4 pos_0;
};


#line 16
void main()
{

#line 16
    uint _S1 = uint(gl_VertexIndex);


    const vec2  pos_1[3] = { vec2(-1.0, -3.0), vec2(-1.0, 1.0), vec2(3.0, 1.0) };

#line 25
    VSOut_0 output_0;
    output_0.pos_0 = vec4(pos_1[_S1], 0.0, 1.0);
    output_0.uv_0 = pos_1[_S1] * 0.5 + 0.5;
    VSOut_0 _S2 = output_0;

#line 28
    entryPointParam_vs_main_uv_0 = output_0.uv_0;

#line 28
    gl_Position = _S2.pos_0;

#line 28
    return;
}

