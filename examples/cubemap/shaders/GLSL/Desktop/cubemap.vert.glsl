#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 23 0
layout(location = 0)
out vec4 entryPointParam_vs_main_direction_0;


#line 23
struct VertexOutput_0
{
    vec4 position_0;
    vec4 direction_0;
};




void main()
{

#line 32
    uint _S1 = uint(gl_VertexIndex);



    const vec2  pos_0[3] = { vec2(-1.0, -1.0), vec2(-1.0, 3.0), vec2(3.0, -1.0) };

#line 33
    VertexOutput_0 output_0;

#line 46
    output_0.position_0 = vec4(pos_0[_S1], 0.0, 1.0);
    output_0.direction_0 = vec4(pos_0[_S1], -1.0, 1.0);
    VertexOutput_0 _S2 = output_0;

#line 48
    gl_Position = output_0.position_0;

#line 48
    entryPointParam_vs_main_direction_0 = _S2.direction_0;

#line 48
    return;
}

