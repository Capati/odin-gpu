package application

// Interleaved vertex buffer for a textured, colored unit cube.
// Vertex layout (10 f32 / 40 bytes): [ pos.xyzw | color.rgba | uv.xy ]
Cube_Mesh :: struct {
    vertex_size:     u64, // 40
    position_offset: u64, // 0
    color_offset:    u64, // 16
    uv_offset:       u64, // 32
    vertex_count:    u64, // 36 (6 faces × 2 tris × 3 verts)
    vertex_array:    [360]f32,
}

// Fills cube_mesh with a unit cube (-1..1 per axis, origin-centered).
//
// - Colors derived from position, for visual distinction without a texture.
// - UVs are standard 0..1 per face.
// - Triangles wound CCW when viewed from outside (default front-facing).
cube_mesh_init :: proc "contextless" (cube_mesh: ^Cube_Mesh) {
    cube_mesh^ = {
        vertex_size     = 4 * 10,
        position_offset = 0,
        color_offset    = 4 * 4,
        uv_offset       = 4 * 8,
        vertex_count    = 36,
        vertex_array    = {
            // Bottom face (-Y)
             1, -1,  1, 1,     1, 0, 1, 1,     0, 1,
            -1, -1,  1, 1,     0, 0, 1, 1,     1, 1,
            -1, -1, -1, 1,     0, 0, 0, 1,     1, 0,
             1, -1, -1, 1,     1, 0, 0, 1,     0, 0,
             1, -1,  1, 1,     1, 0, 1, 1,     0, 1,
            -1, -1, -1, 1,     0, 0, 0, 1,     1, 0,

            // Right face (+X)
             1,  1,  1, 1,     1, 1, 1, 1,     0, 1,
             1, -1,  1, 1,     1, 0, 1, 1,     1, 1,
             1, -1, -1, 1,     1, 0, 0, 1,     1, 0,
             1,  1, -1, 1,     1, 1, 0, 1,     0, 0,
             1,  1,  1, 1,     1, 1, 1, 1,     0, 1,
             1, -1, -1, 1,     1, 0, 0, 1,     1, 0,

            // Top face (+Y)
            -1,  1,  1, 1,     0, 1, 1, 1,     0, 1,
             1,  1,  1, 1,     1, 1, 1, 1,     1, 1,
             1,  1, -1, 1,     1, 1, 0, 1,     1, 0,
            -1,  1, -1, 1,     0, 1, 0, 1,     0, 0,
            -1,  1,  1, 1,     0, 1, 1, 1,     0, 1,
             1,  1, -1, 1,     1, 1, 0, 1,     1, 0,

            // Left face (-X)
            -1, -1,  1, 1,     0, 0, 1, 1,     0, 1,
            -1,  1,  1, 1,     0, 1, 1, 1,     1, 1,
            -1,  1, -1, 1,     0, 1, 0, 1,     1, 0,
            -1, -1, -1, 1,     0, 0, 0, 1,     0, 0,
            -1, -1,  1, 1,     0, 0, 1, 1,     0, 1,
            -1,  1, -1, 1,     0, 1, 0, 1,     1, 0,

            // Front face (+Z)
             1,  1,  1, 1,     1, 1, 1, 1,     0, 1,
            -1,  1,  1, 1,     0, 1, 1, 1,     1, 1,
            -1, -1,  1, 1,     0, 0, 1, 1,     1, 0,
            -1, -1,  1, 1,     0, 0, 1, 1,     1, 0,
             1, -1,  1, 1,     1, 0, 1, 1,     0, 0,
             1,  1,  1, 1,     1, 1, 1, 1,     0, 1,

            // Back face (-Z)
             1, -1, -1, 1,     1, 0, 0, 1,     0, 1,
            -1, -1, -1, 1,     0, 0, 0, 1,     1, 1,
            -1,  1, -1, 1,     0, 1, 0, 1,     1, 0,
             1,  1, -1, 1,     1, 1, 0, 1,     0, 0,
             1, -1, -1, 1,     1, 0, 0, 1,     0, 1,
            -1,  1, -1, 1,     0, 1, 0, 1,     1, 0,
        },
    }
}

// Init cube (extents -1..1) using indexed drawing.
//
// - 8 shared vertices (3 f32 each), 36 indices (u32), 8 RGBA colors (u8 each).
// - Index order per face: 2 triangles, wound CCW when viewed from outside.
// - color_array[i] is derived from vertex_array[i], mapped (-1..1 → 0..255),
//   with alpha = 255.
Indexed_Cube_Mesh :: struct {
    vertex_count: u64, // 8
    index_count:  u64, // 36 (2 tris × 3 verts × 6 faces)
    color_count:  u64, // 8
    vertex_array: [3 * 8]f32,
    index_array:  [2 * 3 * 6]u32,
    color_array:  [4 * 8]u8,
}

// Fills cube_mesh with vertices, indices, and
// position-derived vertex colors (mapped -1..1 → 0..255, alpha = 255).
indexed_cube_mesh_init :: proc "contextless" (cube_mesh: ^Indexed_Cube_Mesh) {
    cube_mesh^ = {
        vertex_count = 8,
        index_count = 2 * 3 * 6,
        color_count = 8,
        vertex_array = {
            -1.0, -1.0, -1.0, // 0
             1.0, -1.0, -1.0, // 1
             1.0, -1.0,  1.0, // 2
            -1.0, -1.0,  1.0, // 3
            -1.0,  1.0, -1.0, // 4
             1.0,  1.0, -1.0, // 5
             1.0,  1.0,  1.0, // 6
            -1.0,  1.0,  1.0, // 7
        },
        index_array = {
            // BOTTOM
            0, 1, 2, /* */  0, 2, 3,
            // TOP
            4, 5, 6,  /* */  4, 6, 7,
            // FRONT
            3, 2, 6,  /* */  3, 6, 7,
            // BACK
            1, 0, 4,  /* */  1, 4, 5,
            // LEFT
            3, 0, 7,  /* */  0, 7, 4,
            // RIGHT
            2, 1, 6,  /* */  1, 6, 5,
        },
    }

    x, y, z: f32
    for i : u8 = 0; i < 8; i += 1 {
        x = cube_mesh.vertex_array[3 * i + 0]
        y = cube_mesh.vertex_array[3 * i + 1]
        z = cube_mesh.vertex_array[3 * i + 2]

        cube_mesh.color_array[4 * i + 0] = 255 * (u8(x) + 1) / 2
        cube_mesh.color_array[4 * i + 1] = 255 * (u8(y) + 1) / 2
        cube_mesh.color_array[4 * i + 2] = 255 * (u8(z) + 1) / 2
        cube_mesh.color_array[4 * i + 3] = 255
    }
}
