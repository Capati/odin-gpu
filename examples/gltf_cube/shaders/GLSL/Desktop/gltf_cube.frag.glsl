#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 9 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 9
layout(location = 0)
in vec3 input_normal_0;


#line 23
void main()
{

#line 23
    entryPointParam_fs_main_0 = vec4(normalize(input_normal_0) * 0.5 + 0.5, 1.0);

#line 23
    return;
}

