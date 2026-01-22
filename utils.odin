package gpu

// Core
import "core:math"
import "core:strings"

_ :: strings

byte_arr_str :: proc(arr: ^[$N]byte) -> string {
    return strings.truncate_to_byte(string(arr[:]), 0)
}

max_mip_levels :: proc(width, height: u32) -> u32 {
    max_dim := max(width, height)
    return u32(1 + math.floor(math.log2(f32(max_dim))))
}

// location information for a vertex in a shader.
Vertex_Location :: struct {
    location: Shader_Location,
    format:   Vertex_Format,
}

// Create an array of `[N]VertexAttribute`, each element representing a vertex
// attribute with a specified shader location and format. The attributes' offsets
// are calculated automatically based on the size of each format.
//
// Arguments:
//
// - `N`: Compile-time constant specifying the number of vertex attributes.
// - `locations`: Specify the shader location and vertex format for each `N` locations.
//
// Example:
//
//     attributes := wgpu.vertex_attr_array(2, {0, .Float32x4}, {1, .Float32x2})
//
// Result in:
//
//     attributes := []VertexAttribute {
//         {format = .Float32x4, offset = 0, shader_location = 0},
//         {
//             format = .Float32x2,
//             offset = 16,
//             shader_location = 1,
//         },
//     },
//
// **Notes**:
//
// - The number of locations provided must match the compile-time constant `N`.
// - Offsets are calculated automatically, assuming tightly packed attributes.
vertex_attr_array :: proc "contextless" (
    $N: int,
    locations: ..Vertex_Location,
) -> (
    attributes: [N]Vertex_Attribute,
) {
    assert_contextless(len(locations) == N,
        "Number of locations must match the generic parameter '$N'")

    offset: u64 = 0

    for v, i in locations {
        format := v.format
        attributes[i] = Vertex_Attribute {
            format          = format,
            offset          = offset,
            shader_location = v.location,
        }
        offset += vertex_format_size(format)
    }

    return
}
