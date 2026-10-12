#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 36 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 36
layout(location = 0)
in vec2 coord_0;


#line 36
void main()
{

#line 36
    entryPointParam_fs_main_0 = vec4(coord_0.x, coord_0.y, 0.5, 1.0);

#line 36
    return;
}

