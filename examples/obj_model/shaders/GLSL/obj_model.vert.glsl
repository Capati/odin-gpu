#version 450
layout(row_major) uniform;
layout(row_major) buffer;

#line 16 0
struct MyUniforms_natural_0
{
    mat4x4 projectionMatrix_0;
    mat4x4 viewMatrix_0;
    mat4x4 modelMatrix_0;
};


#line 20
layout(binding = 0)
layout(std140) uniform block_MyUniforms_natural_0
{
    mat4x4 projectionMatrix_0;
    mat4x4 viewMatrix_0;
    mat4x4 modelMatrix_0;
}uMyUniforms_0;

#line 1
layout(location = 0)
out vec3 entryPointParam_vs_main_normal_0;


#line 1
layout(location = 1)
out vec3 entryPointParam_vs_main_color_0;


#line 1
layout(location = 0)
in vec3 input_position_0;


#line 1
layout(location = 1)
in vec3 input_normal_0;


#line 1
layout(location = 2)
in vec3 input_color_0;




struct VertexOutput_0
{
    vec4 position_0;
    vec3 normal_0;
    vec3 color_0;
};


#line 23
void main()
{

#line 23
    mat4x4 _S1 = uMyUniforms_0.modelMatrix_0;
    VertexOutput_0 output_0;



    output_0.position_0 = (((((((((vec4(input_position_0, 1.0)) * (uMyUniforms_0.modelMatrix_0)))) * (uMyUniforms_0.viewMatrix_0)))) * (uMyUniforms_0.projectionMatrix_0)));


    output_0.normal_0 = (((vec4(input_normal_0, 0.0)) * (_S1))).xyz;
    output_0.color_0 = input_color_0;

    VertexOutput_0 _S2 = output_0;

#line 34
    gl_Position = output_0.position_0;

#line 34
    entryPointParam_vs_main_normal_0 = _S2.normal_0;

#line 34
    entryPointParam_vs_main_color_0 = _S2.color_0;

#line 34
    return;
}

