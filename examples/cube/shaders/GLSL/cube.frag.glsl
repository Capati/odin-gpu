#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 1
layout(location = 0)
in vec4 fragData_color_0;


#line 23
void main()
{

#line 23
    entryPointParam_fs_main_0 = fragData_color_0;

#line 23
    return;
}

