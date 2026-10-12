#version 300 es
precision mediump float;
precision highp int;

in highp vec4 input_color_1;
layout(location = 0) out highp vec4 entryPointParam_fs_main_color;

void main()
{
    entryPointParam_fs_main_color = input_color_1;
}

