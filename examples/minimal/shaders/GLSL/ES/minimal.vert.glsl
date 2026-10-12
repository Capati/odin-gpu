#version 300 es

out vec2 coord;

void main() {
    vec2 data[6] = vec2[6](
        vec2(-1.0, -1.0),
        vec2(1.0, -1.0),
        vec2(1.0, 1.0),
        vec2(-1.0, -1.0),
        vec2(-1.0, 1.0),
        vec2(1.0, 1.0)
    );

    vec2 pos = data[gl_VertexID];
    gl_Position = vec4(pos, 0.0, 1.0);
    coord.x = (pos.x + 1.0) / 2.0;
    coord.y = (1.0 - pos.y) / 2.0;
}
