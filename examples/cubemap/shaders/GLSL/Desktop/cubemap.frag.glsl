#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 9 0
struct Uniforms_0
{
    mat4x4 viewDirectionProjectionInverse_0;
};


#line 29
layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4 viewDirectionProjectionInverse_0;
}uniforms_0;

#line 55
layout(binding = 2)
uniform textureCube myTexture_0;


#line 52
layout(binding = 1)
uniform sampler mySampler_0;


#line 2251 1
layout(location = 0)
out vec4 entryPointParam_fs_main_color_0;


#line 2251
layout(location = 0)
in vec4 input_direction_0;


#line 57 0
struct FragmentOutput_0
{
    vec4 color_0;
};

void main()
{


    vec4 t_0 = (((input_direction_0) * (uniforms_0.viewDirectionProjectionInverse_0)));

#line 63
    FragmentOutput_0 output_0;

#line 68
    output_0.color_0 = (texture(samplerCube(myTexture_0,mySampler_0), (normalize(t_0.xyz / t_0.w))));

#line 68
    entryPointParam_fs_main_color_0 = output_0.color_0;

#line 68
    return;
}

