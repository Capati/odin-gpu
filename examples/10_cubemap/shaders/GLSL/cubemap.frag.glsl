#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 37 0
layout(binding = 1)
uniform samplerCube mySampler_0;


#line 977 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 977
layout(location = 1)
in vec4 input_fragPosition_0;


#line 50 0
void main()
{


    vec3 _S1 = input_fragPosition_0.xyz - vec3(0.5, 0.5, 0.5);

#line 54
    vec3 cubemapVec_0 = _S1;

#line 59
    cubemapVec_0[2] = - _S1.z;

#line 59
    entryPointParam_fs_main_0 = (texture((mySampler_0), (cubemapVec_0)));

#line 59
    return;
}

