#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 13 0
layout(binding = 1)
uniform texture2D myTexture_0;

layout(binding = 2)
uniform sampler mySampler_0;


#line 2251 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 2251
layout(location = 0)
in vec2 fragUV_0;


#line 57 0
void main()
{

#line 57
    entryPointParam_fs_main_0 = vec4((texture(sampler2D(myTexture_0,mySampler_0), (vec2(0.01250000018626451 * floor(fragUV_0.x / 0.01250000018626451), 0.01250000018626451 * floor(fragUV_0.y / 0.01250000018626451))))).xyz, 1.0);

#line 57
    return;
}

