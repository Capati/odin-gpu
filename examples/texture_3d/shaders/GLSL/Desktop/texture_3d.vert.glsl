#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 1 0
struct Uniforms_0
{
    mat4x4 projection_0;
    mat4x4 modelView_0;
    vec4 viewPos_0;
    float depth_0;
};

layout(binding = 0)
layout(std140) uniform block_Uniforms_0
{
    mat4x4 projection_0;
    mat4x4 modelView_0;
    vec4 viewPos_0;
    float depth_0;
}ubo_0;

#line 13092 1
layout(location = 0)
out vec3 entryPointParam_vs_main_fragUV_0;


#line 13092
layout(location = 1)
out vec3 entryPointParam_vs_main_fragNormal_0;


#line 13092
layout(location = 2)
out vec3 entryPointParam_vs_main_viewVec_0;


#line 13092
layout(location = 3)
out vec3 entryPointParam_vs_main_lightVec_0;


#line 13092
layout(location = 0)
in vec3 input_position_0;


#line 11 0
layout(location = 1)
in vec2 input_uv_0;


#line 11
layout(location = 2)
in vec3 input_normal_0;




struct VertexOutput_0
{
    vec4 position_0;
    vec3 fragUV_0;
    vec3 fragNormal_0;
    vec3 viewVec_0;
    vec3 lightVec_0;
};

void main()
{

#line 27
    VertexOutput_0 output_0;


    output_0.fragUV_0 = vec3(input_uv_0, ubo_0.depth_0);

    vec4 viewPosition_0 = (((vec4(input_position_0, 1.0)) * (ubo_0.modelView_0)));
    output_0.position_0 = (((viewPosition_0) * (ubo_0.projection_0)));



    output_0.fragNormal_0 = (((input_normal_0) * (mat3x3(ubo_0.modelView_0[0].xyz, ubo_0.modelView_0[1].xyz, ubo_0.modelView_0[2].xyz))));


    vec3 _S1 = viewPosition_0.xyz;

#line 40
    output_0.lightVec_0 = - _S1;
    output_0.viewVec_0 = ubo_0.viewPos_0.xyz - _S1;
    VertexOutput_0 _S2 = output_0;

#line 42
    gl_Position = output_0.position_0;

#line 42
    entryPointParam_vs_main_fragUV_0 = _S2.fragUV_0;

#line 42
    entryPointParam_vs_main_fragNormal_0 = _S2.fragNormal_0;

#line 42
    entryPointParam_vs_main_viewVec_0 = _S2.viewVec_0;

#line 42
    entryPointParam_vs_main_lightVec_0 = _S2.lightVec_0;

#line 42
    return;
}

