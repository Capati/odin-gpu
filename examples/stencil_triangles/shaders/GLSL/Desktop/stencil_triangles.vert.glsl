#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 6 0
layout(location = 0)
in vec4 position_0;


#line 1
struct VertexOutput_0
{
    vec4 position_1;
};

void main()
{

#line 7
    VertexOutput_0 result_0;
    result_0.position_1 = position_0;

#line 8
    gl_Position = result_0.position_1;

#line 8
    return;
}

