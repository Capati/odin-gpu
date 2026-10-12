#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 13 0
layout(binding = 0)
uniform texture2D textureColor_0;


#line 14
layout(binding = 1)
uniform sampler samplerColor_0;


#line 2251 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 2251
layout(location = 0)
in vec2 input_uv_0;


#line 26 0
void main()
{

#line 26
    entryPointParam_fs_main_0 = (texture(sampler2D(textureColor_0,samplerColor_0), (input_uv_0)));

#line 26
    return;
}

