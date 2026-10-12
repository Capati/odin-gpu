#version 460
#extension GL_ARB_shader_draw_parameters : require
layout(row_major) uniform;
layout(row_major) buffer;

#line 6 0
struct Uniforms_0
{
    mat4x4 matrix_0;
    vec2 resolution_0;
    float size_0;
};


#line 20
layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4 matrix_0;
    vec2 resolution_0;
    float size_0;
}uni_0;

#line 22
const vec2  points_0[6] = { vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(-1.0, 1.0), vec2(1.0, -1.0), vec2(1.0, 1.0) };

#line 13092 1
layout(location = 0)
out vec2 entryPointParam_vs_main_texcoord_0;


#line 13092
layout(location = 0)
in vec4 vert_position_0;


#line 13 0
struct VSOutput_0
{
    vec4 position_0;
    vec2 texcoord_0;
};


#line 38
void main()
{

#line 38
    uint _S1 = uint(gl_VertexIndex - gl_BaseVertex);

#line 43
    vec4 clipPos_0 = (((vert_position_0) * (uni_0.matrix_0)));

#line 40
    VSOutput_0 vsOut_0;

#line 48
    vsOut_0.position_0 = clipPos_0 + vec4(points_0[_S1] * uni_0.size_0 / uni_0.resolution_0 * clipPos_0.w, 0.0, 0.0);
    vsOut_0.texcoord_0 = points_0[_S1] * 0.5 + 0.5;
    VSOutput_0 _S2 = vsOut_0;

#line 50
    gl_Position = vsOut_0.position_0;

#line 50
    entryPointParam_vs_main_texcoord_0 = _S2.texcoord_0;

#line 50
    return;
}

