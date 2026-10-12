#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 37 0
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 37
layout(location = 0)
in vec3 input_normal_0;


#line 44
void main()
{

#line 44
    entryPointParam_fs_main_0 = vec4(vec3(0.80000001192092896, 0.80000001192092896, 0.80000001192092896) * vec3(0.30000001192092896 + max(0.0, dot(normalize(input_normal_0), normalize(vec3(0.5, 1.0, -0.5)))) * 0.69999998807907104), 1.0);

#line 44
    return;
}

