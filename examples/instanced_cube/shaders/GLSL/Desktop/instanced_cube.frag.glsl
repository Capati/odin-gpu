#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 34 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 34
layout(location = 1)
in vec4 input_frag_position_0;




void main()
{

#line 40
    entryPointParam_fs_main_0 = input_frag_position_0;

#line 40
    return;
}

