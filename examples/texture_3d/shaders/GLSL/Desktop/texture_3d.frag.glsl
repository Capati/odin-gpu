#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 49 0
layout(binding = 2)
uniform texture3D texColor_0;


#line 46
layout(binding = 1)
uniform sampler texSampler_0;


#line 13409 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 13409
layout(location = 0)
in vec3 input_fragUV_0;


#line 13409
layout(location = 1)
in vec3 input_fragNormal_0;


#line 13409
layout(location = 2)
in vec3 input_viewVec_0;


#line 13409
layout(location = 3)
in vec3 input_lightVec_0;


#line 60 0
void main()
{
    float value_0 = (texture(sampler3D(texColor_0,texSampler_0), (input_fragUV_0))).x;

    vec3 normal_0 = normalize(input_fragNormal_0);
    vec3 light_0 = normalize(input_lightVec_0);

#line 65
    entryPointParam_fs_main_0 = vec4(vec3(max(dot(normal_0, light_0), 0.0) * value_0 + pow(max(dot(reflect(- light_0, normal_0), normalize(input_viewVec_0)), 0.0), 16.0) * value_0), 1.0);

#line 65
    return;
}

