#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 19 0
struct SLANG_ParameterGroup_model_uniforms_0
{
    mat4x4 model_0;
};


#line 19
layout(binding = 0, set = 1)
layout(std140) uniform block_SLANG_ParameterGroup_model_uniforms_0
{
    mat4x4 model_0;
}model_uniforms_0;

#line 9
struct FrameUniforms_0
{
    mat4x4 view_projection_0;
};

struct SLANG_ParameterGroup_frame_uniforms_0
{
    FrameUniforms_0 frame_0;
};


#line 14
layout(binding = 0)
layout(std140) uniform block_SLANG_ParameterGroup_frame_uniforms_0
{
    FrameUniforms_0 frame_0;
}frame_uniforms_0;

#line 13092 1
layout(location = 0)
out vec3 entryPointParam_vs_main_normal_0;


#line 23 0
layout(location = 1)
out vec2 entryPointParam_vs_main_uv_0;


#line 23
layout(location = 0)
in vec3 input_position_0;


#line 23
layout(location = 1)
in vec3 input_normal_0;


#line 23
layout(location = 2)
in vec2 input_uv_0;




struct VertexOutput_0
{
    vec4 position_0;
    vec3 normal_0;
    vec2 uv_0;
};

void main()
{

#line 37
    VertexOutput_0 output_0;

    output_0.position_0 = ((((((vec4(input_position_0, 1.0)) * (model_uniforms_0.model_0)))) * (frame_uniforms_0.frame_0.view_projection_0)));


    output_0.normal_0 = (((input_normal_0) * (mat3x3(model_uniforms_0.model_0[0].xyz, model_uniforms_0.model_0[1].xyz, model_uniforms_0.model_0[2].xyz))));
    output_0.uv_0 = input_uv_0;
    VertexOutput_0 _S1 = output_0;

#line 44
    gl_Position = output_0.position_0;

#line 44
    entryPointParam_vs_main_normal_0 = _S1.normal_0;

#line 44
    entryPointParam_vs_main_uv_0 = _S1.uv_0;

#line 44
    return;
}

