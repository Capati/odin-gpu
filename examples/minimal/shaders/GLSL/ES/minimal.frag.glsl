#version 300 es
precision mediump float;

in vec2 coord;
out vec4 fragColor;

void main() {
    fragColor = vec4(coord.x, coord.y, 0.5, 1.0);
}
