#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 2 0
struct Uniforms_0
{
    uint offset_0;
};


layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    uint offset_0;
}uniforms_0;

#line 10
uint state_0;


uint pcg_hash_0(uint input_0)
{
    uint _S1 = input_0 * 747796405U + 2891336453U;

#line 15
    state_0 = _S1;
    uint word_0 = ((_S1 >> ((_S1 >> 28U) + 4U)) ^ _S1) * 277803737U;
    return (word_0 >> 22U) ^ word_0;
}


#line 38
layout(location = 0)
out vec4 entryPointParam_fs_main_color_0;



struct FSOutput_0
{
    vec4 color_0;
};


void main()
{



    uint pcg_0 = pcg_hash_0(uint(512.0 * gl_FragCoord.y + gl_FragCoord.x) + uniforms_0.offset_0);
    float v_0 = float(pcg_0) * 2.32830643653869629e-10;

#line 51
    FSOutput_0 output_0;

#line 57
    output_0.color_0 = vec4(v_0, v_0, v_0, 1.0);

#line 57
    entryPointParam_fs_main_color_0 = output_0.color_0;

#line 57
    return;
}

