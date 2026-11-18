/*
Sphere mesh generation, ported from the reference sample's `meshes/sphere.ts`.

The reference builds a UV sphere with `widthSegments` around and `heightSegments`
pole to pole. Poles are welded (every vertex on a pole row shares the position of
the row's first vertex), and `randomness` jitters each non-pole radius, which is
how the asteroid meshes get an irregular silhouette from the same generator.

Each vertex is position (3 floats) + normal (3) + uv (2), so the stride is 32
bytes and the three attributes sit at 0, 12 and 24.
*/
package render_bundles

// Core
import "core:math"
import "core:math/rand"

VERTEX_STRIDE :: 8 * 4

Sphere_Mesh :: struct {
    vertices: []f32,
    indices:  []u16,
    // Kept separately so callers can free `vertices`/`indices` once they are in a
    // GPU buffer and still know how many indices to draw.
    index_count: u32,
}

// Frees the CPU-side arrays, keeping `index_count`. Call after the data is in a
// GPU buffer; the draw only needs the count, so the arrays do not need to outlive
// the upload.
sphere_mesh_free :: proc(mesh: ^Sphere_Mesh) {
    delete(mesh.vertices)
    delete(mesh.indices)
    mesh.vertices = nil
    mesh.indices = nil
}

// The reference leaves the normal unwritten between rows, which is why its
// normals lag one vertex behind. Writing it per vertex is the intended result and
// is what the lighting here relies on.
create_sphere_mesh :: proc(
    radius: f32,
    width_segments: u32,
    height_segments: u32,
    randomness: f32,
) -> Sphere_Mesh {
    width := max(u32(3), width_segments)
    height := max(u32(2), height_segments)

    vertex_count := (width + 1) * (height + 1)
    vertices := make([]f32, vertex_count * 8)

    // Indices: two triangles per quad, minus the degenerate ones at each pole.
    index_count := int(width * height * 6)
    indices := make([dynamic]u16, 0, index_count)

    // `grid[iy][ix]` is the vertex index for that lattice point.
    grid := make([]u16, vertex_count)
    defer delete(grid)

    first_vertex: [3]f32
    vertex: [3]f32

    next_index := u16(0)

    for iy in 0 ..= height {
        v := f32(iy) / f32(height)

        // Poles get a half-texel offset so the seam texture is not squeezed.
        u_offset: f32
        if iy == 0 {
            u_offset = 0.5 / f32(width)
        } else if iy == height {
            u_offset = -0.5 / f32(width)
        }

        for ix in 0 ..= width {
            u := f32(ix) / f32(width)

            // Poles reuse one position all the way around, so the seam closes.
            if ix == width {
                vertex = first_vertex
            } else if ix == 0 || (iy != 0 && iy != height) {
                rr := radius + (rand.float32() - 0.5) * 2 * randomness * radius

                vertex = {
                    -rr * math.cos(u * math.PI * 2) * math.sin(v * math.PI),
                    rr * math.cos(v * math.PI),
                    rr * math.sin(u * math.PI * 2) * math.sin(v * math.PI),
                }

                if ix == 0 {
                    first_vertex = vertex
                }
            }

            offset := int(next_index) * 8
            vertices[offset + 0] = vertex.x
            vertices[offset + 1] = vertex.y
            vertices[offset + 2] = vertex.z

            // On a sphere centred at the origin the position is already the
            // normal direction; normalising covers the jittered asteroids.
            length := math.sqrt(vertex.x * vertex.x + vertex.y * vertex.y + vertex.z * vertex.z)
            if length > 0 {
                vertices[offset + 3] = vertex.x / length
                vertices[offset + 4] = vertex.y / length
                vertices[offset + 5] = vertex.z / length
            }

            vertices[offset + 6] = u + u_offset
            vertices[offset + 7] = 1 - v

            grid[int(iy) * int(width + 1) + int(ix)] = next_index
            next_index += 1
        }
    }

    row_stride := int(width + 1)
    for iy in 0 ..< int(height) {
        for ix in 0 ..< int(width) {
            a := grid[iy * row_stride + ix + 1]
            b := grid[iy * row_stride + ix]
            c := grid[(iy + 1) * row_stride + ix]
            d := grid[(iy + 1) * row_stride + ix + 1]

            // The top row only emits one triangle per quad, the bottom row the
            // other, so the poles do not get degenerate faces.
            if iy != 0 {
                append(&indices, a, b, d)
            }
            if iy != int(height) - 1 {
                append(&indices, b, c, d)
            }
        }
    }

    return {
        vertices    = vertices,
        indices     = indices[:],
        index_count = u32(len(indices)),
    }
}
