#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 28 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 28
layout(location = 1)
in vec4 input_frag_position_0;




void main()
{

#line 34
    entryPointParam_fs_main_0 = input_frag_position_0;

#line 34
    return;
}

