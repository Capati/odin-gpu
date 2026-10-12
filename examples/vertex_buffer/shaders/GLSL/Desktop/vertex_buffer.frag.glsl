#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 23 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 23
layout(location = 0)
in float color_0;


#line 23
void main()
{

#line 23
    entryPointParam_fs_main_0 = vec4(color_0, color_0, abs(color_0), 1.0);

#line 23
    return;
}

