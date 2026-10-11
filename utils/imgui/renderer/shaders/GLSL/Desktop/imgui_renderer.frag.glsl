#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 9 0
layout(binding = 0, set = 1)
uniform texture2D tex_0;


#line 8
layout(binding = 1)
uniform sampler samplerState_0;


#line 13429 1
layout(location = 0)
out vec4 entryPointParam_fs_main_0;


#line 13429
layout(location = 0)
in vec4 input_color_0;


#line 13429
layout(location = 1)
in vec2 input_uv_0;


#line 36 0
void main()
{
    vec4 color_0 = input_color_0 * (texture(sampler2D(tex_0,samplerState_0), (input_uv_0)));

#line 38
    entryPointParam_fs_main_0 = vec4(pow(color_0.xyz, vec3(1.0)), color_0.w);

#line 38
    return;
}

