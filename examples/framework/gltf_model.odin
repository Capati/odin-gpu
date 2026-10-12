/*
Gltf_Model: CPU-side glTF 2.0 model.

The model owns the parsed geometry, materials, textures (as CPU RGBA pixels),
nodes, animations and preset cameras, and is agnostic of any rendering API
(no gpu import). A rendering backend reads the numbers out of Gltf_Model and
uploads them.
*/

package application

// Core
import "base:runtime"
import "core:encoding/base64"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"

// Local packages
import "../../utils/gltf"
import la "core:math/linalg"

// Texture slot indices, in bind-group order. The example device layer keeps its
// own TEXTURE_SLOT_* constants with the same values; Gltf_Material.slots is
// indexed by these.
Gltf_Texture_Slot_Base_Color :: 0
Gltf_Texture_Slot_Metallic_Roughness :: 1
Gltf_Texture_Slot_Normal :: 2
Gltf_Texture_Slot_Occlusion :: 3
Gltf_Texture_Slot_Emissive :: 4
Gltf_Texture_Slot_Count :: 5

// -----------------------------------------------------------------------------
// math helpers
// -----------------------------------------------------------------------------

@(private = "file")
normalize3 :: proc(v: [3]f32) -> [3]f32 {
    length_squared := v.x * v.x + v.y * v.y + v.z * v.z
    if length_squared <= 1e-20 {
        return {0, 0, 1}
    }
    inv_length := 1 / math.sqrt(length_squared)
    return {v.x * inv_length, v.y * inv_length, v.z * inv_length}
}

@(private = "file")
length3 :: proc(v: [3]f32) -> f32 {
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
}

@(private = "file")
cross3 :: proc(a, b: [3]f32) -> [3]f32 {
    return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x}
}

// Transforms a point by a column-major matrix, dividing through by w when the
// matrix is projective.
@(private = "file")
transform_point :: proc(m: la.Matrix4f32, p: [3]f32) -> [3]f32 {
    result: [3]f32
    for axis in 0 ..< 3 {
        result[axis] = m[0][axis] * p.x + m[1][axis] * p.y + m[2][axis] * p.z + m[3][axis]
    }
    w := m[0][3] * p.x + m[1][3] * p.y + m[2][3] * p.z + m[3][3]
    if math.abs(w) > 1e-8 && math.abs(w - 1) > 1e-8 {
        result /= w
    }
    return result
}

// Inverse-transpose of a world matrix, or identity for a singular one (a collapsed
// node transform produces infinities when used for normals).
gltf_model_inverse_transpose_or_identity :: proc(m: la.Matrix4f32) -> la.Matrix4f32 {
    if math.abs(la.matrix4_determinant(m)) <= 1e-8 {
        return la.MATRIX4F32_IDENTITY
    }
    return la.matrix4_inverse_transpose(m)
}

// -----------------------------------------------------------------------------
// attributes
// -----------------------------------------------------------------------------

@(private = "file")
GLTF_VERTEX_COLOR_WHITE :: [4]f32{1, 1, 1, 1}

@(private = "file")
read_vec3 :: proc(accessor: ^gltf.Accessor, index: int, fallback: [3]f32) -> [3]f32 {
    if accessor == nil {
        return fallback
    }
    result: [3]f32
    if !gltf_read_attribute_floats(accessor, index, result[:]) {
        return fallback
    }
    return result
}

@(private = "file")
read_vec2 :: proc(accessor: ^gltf.Accessor, index: int) -> [2]f32 {
    if accessor == nil {
        return {}
    }
    result: [2]f32
    if !gltf_read_attribute_floats(accessor, index, result[:]) {
        return {}
    }
    return result
}

@(private = "file")
read_vec4 :: proc(accessor: ^gltf.Accessor, index: int, fallback: [4]f32) -> [4]f32 {
    if accessor == nil {
        return fallback
    }
    result: [4]f32
    if !gltf_read_attribute_floats(accessor, index, result[:]) {
        return fallback
    }
    return result
}

// COLOR_0 may be VEC3 or VEC4 and is frequently normalized integer data, which
// `gltf.Read_Float` already scales into 0..1.
@(private = "file")
read_color :: proc(accessor: ^gltf.Accessor, index: int) -> [4]f32 {
    if accessor == nil {
        return GLTF_VERTEX_COLOR_WHITE
    }
    result := GLTF_VERTEX_COLOR_WHITE
    if accessor.type == .Vec4 {
        if !gltf_read_attribute_floats(accessor, index, result[:]) {
            return GLTF_VERTEX_COLOR_WHITE
        }
        return result
    }
    rgb: [3]f32
    if !gltf_read_attribute_floats(accessor, index, rgb[:]) {
        return GLTF_VERTEX_COLOR_WHITE
    }
    result.xyz = rgb
    return result
}

// -----------------------------------------------------------------------------
// state links
// -----------------------------------------------------------------------------

@(private = "file")
Loader :: struct {
    document:  ^gltf.Document,
    allocator: mem.Allocator,
}

@(private = "file")
mesh_index_of :: proc(document: ^gltf.Document, mesh: ^gltf.Mesh) -> int {
    if mesh == nil {
        return -1
    }
    for index in 0 ..< len(document.meshes) {
        if &document.meshes[index] == mesh {
            return index
        }
    }
    return -1
}

@(private = "file")
node_index_of :: proc(document: ^gltf.Document, node: ^gltf.Node) -> int {
    if node == nil {
        return -1
    }
    for index in 0 ..< len(document.nodes) {
        if &document.nodes[index] == node {
            return index
        }
    }
    return -1
}

@(private = "file")
texture_index_of :: proc(document: ^gltf.Document, texture: ^gltf.Texture) -> int {
    if texture == nil {
        return -1
    }
    for index in 0 ..< len(document.textures) {
        if &document.textures[index] == texture {
            return index
        }
    }
    return -1
}

// -----------------------------------------------------------------------------
// materials
// -----------------------------------------------------------------------------

// The device-independent form of a material's texture reference: indices and
// texcoord set numbers instead of parsed pointers.
Gltf_Texture_Slot :: struct {
    texture:            int, // index into Gltf_Model.textures, -1 when unset
    tex_coord:          int, // the TEXCOORD set the texture is sampled with
    transform_texcoord: int, // KHR_texture_transform tex coord override
    scale:              f32, // normal / occlusion scale (other slots unused)
}

// PBR material. `slots` is the five texture slots in bind-group order (base
// color, MR, normal, occlusion, emissive). Index 0 of Gltf_Model.materials is
// the synthesized default.
Gltf_Material :: struct {
    base_color_factor:     [4]f32,
    metallic_factor:       f32,
    roughness_factor:      f32,
    emissive_factor:       [3]f32,
    emissive_strength:     f32, // KHR_materials_emissive_strength, 1 when absent
    has_emissive_strength: bool,
    alpha_mode:            gltf.Alpha_Mode,
    alpha_cutoff:          f32,
    double_sided:          bool,
    slots:                 [Gltf_Texture_Slot_Count]Gltf_Texture_Slot,
}

// The default material synthesized for a primitive that names none.
@(private = "file")
default_material :: proc() -> Gltf_Material {
    result := Gltf_Material {
        base_color_factor = {1, 1, 1, 1},
        metallic_factor   = 1,
        roughness_factor  = 1,
        emissive_strength = 1,
        alpha_mode        = .Opaque,
        alpha_cutoff      = 0.5,
    }
    for &slot in result.slots {
        slot.texture = -1
    }
    return result
}

// Material slot index, offset by one so that zero means "the default material".
@(private = "file")
material_slot :: proc(document: ^gltf.Document, material: ^gltf.Material) -> int {
    if material == nil {
        return 0
    }
    for index in 0 ..< len(document.materials) {
        if &document.materials[index] == material {
            return index + 1
        }
    }
    return 0
}

@(private = "file")
texture_slot_from_view :: proc(
    document: ^gltf.Document,
    view: gltf.Texture_View,
) -> Gltf_Texture_Slot {
    result: Gltf_Texture_Slot
    result.texture = -1
    if view.texture == nil {
        return result
    }
    result.texture = texture_index_of(document, view.texture)
    result.tex_coord = view.tex_coord
    result.transform_texcoord = view.transform.tex_coord
    result.scale = view.scale
    return result
}

@(private = "file")
gltf_material_from_document :: proc(
    document: ^gltf.Document,
    material: ^gltf.Material,
) -> Gltf_Material {
    result := Gltf_Material {
        base_color_factor     = material.pbr.base_color_factor,
        metallic_factor       = material.pbr.metallic_factor,
        roughness_factor      = material.pbr.roughness_factor,
        emissive_factor       = material.emissive_factor,
        emissive_strength     = material.emissive_strength.strength if material.has_emissive_strength else 1,
        has_emissive_strength = material.has_emissive_strength,
        alpha_mode            = material.alpha_mode,
        alpha_cutoff          = material.alpha_cutoff,
        double_sided          = material.double_sided,
    }
    result.slots[Gltf_Texture_Slot_Base_Color] = texture_slot_from_view(
        document,
        material.pbr.base_color_texture,
    )
    result.slots[Gltf_Texture_Slot_Metallic_Roughness] = texture_slot_from_view(
        document,
        material.pbr.metallic_roughness_texture,
    )
    result.slots[Gltf_Texture_Slot_Normal] = texture_slot_from_view(
        document,
        material.normal_texture,
    )
    result.slots[Gltf_Texture_Slot_Occlusion] = texture_slot_from_view(
        document,
        material.occlusion_texture,
    )
    result.slots[Gltf_Texture_Slot_Emissive] = texture_slot_from_view(
        document,
        material.emissive_texture,
    )
    return result
}

@(private = "file")
build_materials :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    model.materials = make([dynamic]Gltf_Material, 0, len(document.materials) + 1, model.allocator)
    append(&model.materials, default_material())
    for index in 0 ..< len(document.materials) {
        append(&model.materials, gltf_material_from_document(document, &document.materials[index]))
    }
}

// -----------------------------------------------------------------------------
// textures
// -----------------------------------------------------------------------------

// Raw sampler parameters from the document, kept as glTF enums so the backend
// applies its own defaults.
Gltf_Sampler :: struct {
    mag_filter: gltf.Filter_Type,
    min_filter: gltf.Filter_Type,
    wrap_s:     gltf.Wrap_Mode,
    wrap_t:     gltf.Wrap_Mode,
}

// One document texture with decoded CPU RGBA pixels.
Gltf_Texture :: struct {
    pixels:  []u8, // owned, RGBA8; nil until decoded
    width:   u32,
    height:  u32,
    decoded: bool,
    sampler: Gltf_Sampler,
}

@(private = "file")
build_textures :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    model.textures = make([dynamic]Gltf_Texture, len(document.textures), model.allocator)
    for &tex in model.textures {
        tex.sampler.wrap_s = .Repeat
        tex.sampler.wrap_t = .Repeat
    }
    for index in 0 ..< len(document.textures) {
        if sampler := document.textures[index].sampler; sampler != nil {
            model.textures[index].sampler.mag_filter = sampler.mag_filter
            model.textures[index].sampler.min_filter = sampler.min_filter
            model.textures[index].sampler.wrap_s = sampler.wrap_s
            model.textures[index].sampler.wrap_t = sampler.wrap_t
        }
    }
}

// Hex nibble value for percent-decoded URIs.
@(private = "file")
hex_value :: proc(c: u8) -> (value: int, ok: bool) {
    if c >= '0' && c <= '9' do return int(c - '0'), true
    if c >= 'a' && c <= 'f' do return int(c - 'a') + 10, true
    if c >= 'A' && c <= 'F' do return int(c - 'A') + 10, true
    return 0, false
}

@(private = "file")
decode_uri_bytes :: proc(text: string, allocator: runtime.Allocator) -> []byte {
    result := make([dynamic]byte, 0, len(text), allocator)
    for index := 0; index < len(text); {
        if text[index] == '%' && index + 2 < len(text) {
            high, high_ok := hex_value(text[index + 1])
            low, low_ok := hex_value(text[index + 2])
            if high_ok && low_ok {
                append(&result, byte(high * 16 + low))
                index += 3
                continue
            }
        }
        append(&result, text[index])
        index += 1
    }
    return result[:]
}

// Reads an `images[i]` payload, either from its buffer view or from its URI.
// Buffer views return a borrowed slice into the document; URIs return bytes
// allocated with `loader.allocator` that the caller must free.
@(private = "file")
load_image_bytes :: proc(loader: ^Loader, image: ^gltf.Image) -> []byte {
    if image == nil {
        return nil
    }
    if view := image.buffer_view; view != nil {
        if view.data != nil {
            return view.data
        }
        if view.buffer != nil && view.buffer.data != nil {
            return view.buffer.data[view.offset:view.offset + view.size]
        }
        return nil
    }
    if image.uri == "" {
        return nil
    }

    if strings.has_prefix(image.uri, "data:") {
        comma := strings.index_byte(image.uri, ',')
        if comma < 0 {
            return nil
        }
        payload := image.uri[comma + 1:]
        if strings.has_suffix(image.uri[:comma], ";base64") {
            decoded, err := base64.decode(payload, allocator = loader.allocator)
            return decoded if err == nil else nil
        }
        return decode_uri_bytes(payload, loader.allocator)
    }

    uri := transmute(string)decode_uri_bytes(image.uri, loader.allocator)
    path, err := resolve_image_uri_path(loader.document.file_name, uri, loader.allocator)
    if err != .None {
        delete(uri, loader.allocator)
        return nil
    }
    data, ok := load_file(path, loader.allocator)
    delete(path, loader.allocator)
    delete(uri, loader.allocator)
    return data if ok else nil
}

// Decodes the textures referenced by at least one material slot, storing RGBA
// pixels in the model. This is the same set a backend resolving the five slots
// would touch, so decoding happens eagerly-here-at-load.
@(private = "file")
decode_textures :: proc(loader: ^Loader, model: ^Gltf_Model) {
    referenced := make([]bool, len(model.textures), loader.allocator)
    defer delete(referenced, loader.allocator)
    for &material in model.materials {
        for &slot in material.slots {
            if slot.texture >= 0 && slot.texture < len(referenced) {
                referenced[slot.texture] = true
            }
        }
    }

    document := loader.document
    for index in 0 ..< len(model.textures) {
        if !referenced[index] {
            continue
        }
        texture := &model.textures[index]
        image := document.textures[index].source
        if image == nil {
            continue
        }
        encoded := load_image_bytes(loader, image)
        if encoded == nil {
            continue
        }
        // Only URI payloads are owned; buffer views alias the document.
        owns_encoded := image.buffer_view == nil
        encoded_count := len(encoded)
        decoded, reason, ok := decode_image_bytes(encoded, loader.allocator)
        if owns_encoded {
            delete(encoded, loader.allocator)
        }
        if !ok || decoded.channels != 4 {
            log.warnf(
                "Could not decode texture %d: %d bytes (%s); falling back to the material factors",
                index,
                encoded_count,
                reason,
            )
            continue
        }
        texture.pixels = decoded.pixels
        texture.width = u32(decoded.width)
        texture.height = u32(decoded.height)
        texture.decoded = true
    }
}

// -----------------------------------------------------------------------------
// geometry
// -----------------------------------------------------------------------------

// Per-vertex layout: 0 position, 1 normal, 2 uv0, 3 uv1, 4 tangent, 5 color. 72 bytes
// interleaved, one shared buffer.
Gltf_Vertex :: struct {
    position: [3]f32,
    normal:   [3]f32,
    uv0:      [2]f32,
    uv1:      [2]f32,
    color:    [4]f32,
    tangent:  [4]f32,
}

// One drawable range of a mesh in the shared vertex/index buffers.
Gltf_Primitive :: struct {
    base_vertex: u32,
    first_index: u32,
    index_count: u32,
    material:    int, // index into Gltf_Model.materials
    aabb_min:    [3]f32,
    aabb_max:    [3]f32,
}

Gltf_Mesh :: struct {
    primitives:     [dynamic]Gltf_Primitive,
    instance_nodes: [dynamic]int, // node indices in instance order
    instance_count: u32,
}

// Generates per-corner normals for a primitive that has none: the cross product of
// the triangle's two normalized edges, accumulated per corner and left
// unnormalized (the shader normalizes the interpolated normal).
@(private = "file")
generate_normals :: proc(
    vertices: ^[dynamic]Gltf_Vertex,
    indices: []u32,
    base_vertex, vertex_count: u32,
    first_index, index_count: u32,
) {
    normal_sums := make([][3]f32, int(vertex_count), context.temp_allocator)

    for index := first_index; index + 2 < first_index + index_count; index += 3 {
        i0 := indices[index] - base_vertex
        i1 := indices[index + 1] - base_vertex
        i2 := indices[index + 2] - base_vertex
        v0 := vertices^[base_vertex + i0]
        v1 := vertices^[base_vertex + i1]
        v2 := vertices^[base_vertex + i2]

        dv1 := v1.position - v0.position
        dv2 := v2.position - v0.position
        if length3(dv1) <= 1e-12 || length3(dv2) <= 1e-12 {
            continue
        }
        normal := cross3(normalize3(dv1), normalize3(dv2))
        normal_sums[i0] += normal
        normal_sums[i1] += normal
        normal_sums[i2] += normal
    }

    for index in 0 ..< int(vertex_count) {
        vertices^[base_vertex + u32(index)].normal = normal_sums[index]
    }
}

// Generates per-corner tangents for a primitive that has none: `(dv1 * duv2.y -
// dv2 * duv1.y)` scaled by the (signed) UV cross product, normalized, accumulated
// per corner.
@(private = "file")
generate_tangents :: proc(
    vertices: ^[dynamic]Gltf_Vertex,
    indices: []u32,
    base_vertex, vertex_count: u32,
    first_index, index_count: u32,
) {
    tangent_sums := make([][3]f32, int(vertex_count), context.temp_allocator)

    for index := first_index; index + 2 < first_index + index_count; index += 3 {
        i0 := indices[index] - base_vertex
        i1 := indices[index + 1] - base_vertex
        i2 := indices[index + 2] - base_vertex
        v0 := vertices^[base_vertex + i0]
        v1 := vertices^[base_vertex + i1]
        v2 := vertices^[base_vertex + i2]

        dv1 := v1.position - v0.position
        dv2 := v2.position - v0.position
        duv1 := v1.uv0 - v0.uv0
        duv2 := v2.uv0 - v0.uv0
        scale := duv2.y * duv1.x - duv1.y * duv2.x
        if math.abs(scale) <= 1e-12 {
            continue
        }

        tangent := (dv1 * duv2.y - dv2 * duv1.y) * scale
        if length3(tangent) <= 1e-12 {
            continue
        }
        tangent = normalize3(tangent)
        tangent_sums[i0] += tangent
        tangent_sums[i1] += tangent
        tangent_sums[i2] += tangent
    }

    for index in 0 ..< int(vertex_count) {
        vertex := &vertices^[base_vertex + u32(index)]
        vertex.tangent = {tangent_sums[index].x, tangent_sums[index].y, tangent_sums[index].z, 1}
    }
}

// Appends one primitive to the shared vertex/index arrays. The primitive's
// vertices stay in LOCAL mesh space; the node globals are applied on the GPU
// through instancing.
@(private = "file")
append_primitive :: proc(
    loader: ^Loader,
    model: ^Gltf_Model,
    primitive: ^gltf.Primitive,
    mesh: ^Gltf_Mesh,
) {
    // glTF's default mode is TRIANGLES; the parser leaves `Invalid` for a
    // primitive that named none.
    if primitive.mode != .Triangles && primitive.mode != .Invalid {
        log.warnf("Skipping primitive with unsupported mode %v", primitive.mode)
        return
    }

    positions := gltf.find_accessor(primitive, .Position)
    assert(positions != nil, "glTF primitive has no POSITION accessor")

    normals := gltf.find_accessor(primitive, .Normal)
    if normals != nil {
        assert(normals.count == positions.count, "glTF POSITION and NORMAL counts differ")
    }
    uv0 := gltf.find_accessor(primitive, .Texcoord, 0)
    uv1 := gltf.find_accessor(primitive, .Texcoord, 1)
    colors := gltf.find_accessor(primitive, .Color, 0)
    tangents := gltf.find_accessor(primitive, .Tangent)

    material_idx := material_slot(loader.document, primitive.material)

    base_vertex := u32(len(model.vertices))
    primitive_min: [3]f32 = {max(f32), max(f32), max(f32)}
    primitive_max: [3]f32 = {-max(f32), -max(f32), -max(f32)}

    for index in 0 ..< positions.count {
        position := read_vec3(positions, index, {})

        tangent := [4]f32{1, 0, 0, 1}
        if tangents != nil {
            tangent = read_vec4(tangents, index, {1, 0, 0, 1})
        }

        append(
            &model.vertices,
            Gltf_Vertex {
                position = position,
                normal = read_vec3(normals, index, {0, 0, 1}),
                uv0 = read_vec2(uv0, index),
                uv1 = read_vec2(uv1, index),
                color = read_color(colors, index),
                tangent = tangent,
            },
        )

        for axis in 0 ..< 3 {
            primitive_min[axis] = min(primitive_min[axis], position[axis])
            primitive_max[axis] = max(primitive_max[axis], position[axis])
        }
    }

    first_index := u32(len(model.indices))
    if primitive.indices != nil {
        for index in 0 ..< primitive.indices.count {
            local_index := gltf_read_index(primitive.indices, index)
            assert(local_index < u32(positions.count), "glTF index is out of range")
            append(&model.indices, base_vertex + local_index)
        }
    } else {
        for index in 0 ..< positions.count {
            append(&model.indices, base_vertex + u32(index))
        }
    }
    index_count := u32(len(model.indices)) - first_index

    // Normals whenever the primitive has none, and tangents whenever TANGENT is missing.
    // Tangents need a UV set.
    if normals == nil {
        generate_normals(
            &model.vertices,
            model.indices[:],
            base_vertex,
            u32(positions.count),
            first_index,
            index_count,
        )
    }
    if tangents == nil && uv0 != nil {
        generate_tangents(
            &model.vertices,
            model.indices[:],
            base_vertex,
            u32(positions.count),
            first_index,
            index_count,
        )
    }

    append(
        &mesh.primitives,
        Gltf_Primitive {
            base_vertex = base_vertex,
            first_index = first_index,
            index_count = index_count,
            material = material_idx,
            aabb_min = primitive_min,
            aabb_max = primitive_max,
        },
    )
}

// Builds every mesh's interleaved vertices and indices, one primitive at a
// time into the shared arrays. No GPU buffers are created here.
@(private = "file")
build_geometry :: proc(loader: ^Loader, model: ^Gltf_Model) -> (vertex_count, index_count: int) {
    document := loader.document
    model.vertices = make([dynamic]Gltf_Vertex, 0, 0, model.allocator)
    model.indices = make([dynamic]u32, 0, 0, model.allocator)
    model.meshes = make([dynamic]Gltf_Mesh, 0, len(document.meshes), model.allocator)

    for mesh_index in 0 ..< len(document.meshes) {
        mesh := Gltf_Mesh {
            primitives = make([dynamic]Gltf_Primitive, 0, 0, model.allocator),
        }
        for primitive_index in 0 ..< len(document.meshes[mesh_index].primitives) {
            append_primitive(
                loader,
                model,
                &document.meshes[mesh_index].primitives[primitive_index],
                &mesh,
            )
        }
        if len(mesh.primitives) == 0 {
            log.warnf("Mesh %d has no drawable primitives", mesh_index)
        }
        append(&model.meshes, mesh)
    }

    return len(model.vertices), len(model.indices)
}

// ------------------------------------------------------------------ nodes --

Gltf_Node :: struct {
    translation: [3]f32,
    rotation:    [4]f32, // xyzw
    scale:       [3]f32,
    matrix4:     la.Matrix4f32,
    has_matrix:  bool,
    animated:    bool,
    global:      la.Matrix4f32,
    children:    []int,
}

@(private = "file")
build_nodes :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    model.nodes = make([dynamic]Gltf_Node, 0, len(document.nodes), model.allocator)
    for index in 0 ..< len(document.nodes) {
        node := &document.nodes[index]
        node_state := Gltf_Node {
            translation = node.translation,
            rotation    = node.rotation if node.has_rotation else {0, 0, 0, 1},
            scale       = node.scale if node.has_scale else {1, 1, 1},
            matrix4     = node.matrix_,
            has_matrix  = node.has_matrix,
            children    = make([]int, len(node.children), model.allocator),
        }
        for child_index in 0 ..< len(node.children) {
            node_state.children[child_index] = node_index_of(document, node.children[child_index])
        }
        append(&model.nodes, node_state)
    }

    // Roots: the default scene's nodes, falling back to every parentless node.
    if document.scene != nil {
        model.roots = make([]int, len(document.scene.nodes), model.allocator)
        for index in 0 ..< len(document.scene.nodes) {
            model.roots[index] = node_index_of(document, document.scene.nodes[index])
        }
    } else {
        root_count := 0
        for &node in document.nodes {
            if node.parent == nil {
                root_count += 1
            }
        }
        model.roots = make([]int, root_count, model.allocator)
        root_index := 0
        for node_index in 0 ..< len(document.nodes) {
            node := &document.nodes[node_index]
            if node.parent == nil {
                model.roots[root_index] = node_index
                root_index += 1
            }
        }
    }
}

@(private = "file")
globals_recursive_static :: proc(
    document: ^gltf.Document,
    model: ^Gltf_Model,
    node_index: int,
    parent: la.Matrix4f32,
) {
    node := &document.nodes[node_index]
    local := gltf.node_transform_local(node)
    node_state := &model.nodes[node_index]
    node_state.global = parent * local
    for child in node_state.children {
        globals_recursive_static(document, model, child, node_state.global)
    }
}

@(private = "file")
compute_globals_static :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    for root in model.roots {
        globals_recursive_static(document, model, root, la.MATRIX4F32_IDENTITY)
    }
}

// ------------------------------------------------------------ animations --

Gltf_Animation_Channel :: struct {
    node:   int,
    path:   gltf.Animation_Path,
    interp: gltf.Interpolation,
    comps:  int, // 3 for translation/scale, 4 for rotation
    stride: int,
    times:  []f32,
    values: []f32,
}

Gltf_Animation_Group :: struct {
    length:   f32,
    channels: [dynamic]Gltf_Animation_Channel,
}

@(private = "file")
read_last_float :: proc(accessor: ^gltf.Accessor) -> f32 {
    if accessor == nil || accessor.count == 0 {
        return 0
    }
    result: [1]f32
    if !gltf.read_float(accessor, accessor.count - 1, result[:]) {
        return 0
    }
    return result[0]
}

@(private = "file")
build_animations :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    model.animations = make(
        [dynamic]Gltf_Animation_Group,
        0,
        len(document.animations),
        model.allocator,
    )
    for animation_index in 0 ..< len(document.animations) {
        anim := &document.animations[animation_index]
        group := Gltf_Animation_Group {
            channels = make(
                [dynamic]Gltf_Animation_Channel,
                0,
                len(anim.channels),
                model.allocator,
            ),
        }
        for &sampler in anim.samplers {
            group.length = max(group.length, read_last_float(sampler.input))
        }

        for channel_index in 0 ..< len(anim.channels) {
            channel := &anim.channels[channel_index]
            if channel.sampler == nil || channel.target_node == nil {
                continue
            }
            path := channel.target_path
            if path != .Translation && path != .Rotation && path != .Scale {
                continue
            }
            components := 3
            if path == .Rotation {
                components = 4
            }

            channel_state := Gltf_Animation_Channel {
                node   = node_index_of(document, channel.target_node),
                path   = path,
                interp = channel.sampler.interpolation,
                comps  = components,
                stride = components * (3 if channel.sampler.interpolation == .Cubic_Spline else 1),
                times  = make([]f32, channel.sampler.input.count, model.allocator),
                values = make([]f32, channel.sampler.output.count * components, model.allocator),
            }
            gltf.unpack_floats(channel.sampler.input, channel_state.times)
            gltf.unpack_floats(channel.sampler.output, channel_state.values)

            if channel_state.node >= 0 && channel_state.node < len(model.nodes) {
                model.nodes[channel_state.node].animated = true
                model.has_animations = true
            }
            append(&group.channels, channel_state)
        }

        append(&model.animations, group)
    }
}

// The static local transform of a node state (the TRS composition). Animated
// nodes have their translation/rotation/scale overwritten before this is asked.
@(private = "file")
node_state_local :: proc(node: ^Gltf_Node) -> la.Matrix4f32 {
    if node.has_matrix {
        return node.matrix4
    }
    quaternion := transmute(la.Quaternionf32)node.rotation
    return la.matrix4_from_trs(node.translation, quaternion, node.scale)
}

@(private = "file")
globals_recursive_animated :: proc(model: ^Gltf_Model, node_index: int, parent: la.Matrix4f32) {
    node_state := &model.nodes[node_index]
    node_state.global = parent * node_state_local(node_state)
    for child in node_state.children {
        globals_recursive_animated(model, child, node_state.global)
    }
}

// Samples a channel at its wrap-around time and writes the node's
// translation/rotation/scale.
@(private = "file")
evaluate_channel :: proc(model: ^Gltf_Model, channel: ^Gltf_Animation_Channel, t: f32) {
    count := len(channel.times)
    if count == 0 {
        return
    }
    key := 0
    for key + 1 < count && channel.times[key + 1] <= t {
        key += 1
    }

    node_index := channel.node
    if node_index < 0 || node_index >= len(model.nodes) {
        return
    }
    node := &model.nodes[node_index]

    // STEP and the closing key both use the key's own value.
    if channel.interp == .Step || key + 1 >= count {
        #partial switch channel.path {
        case .Translation:
            node.translation = {
                channel.values[key * channel.stride + 0],
                channel.values[key * channel.stride + 1],
                channel.values[key * channel.stride + 2],
            }
        case .Scale:
            node.scale = {
                channel.values[key * channel.stride + 0],
                channel.values[key * channel.stride + 1],
                channel.values[key * channel.stride + 2],
            }
        case .Rotation:
            quaternion := la.quaternion_normalize(
                transmute(la.Quaternionf32)[4]f32 {
                    channel.values[key * channel.stride + 0],
                    channel.values[key * channel.stride + 1],
                    channel.values[key * channel.stride + 2],
                    channel.values[key * channel.stride + 3],
                },
            )
            node.rotation = transmute([4]f32)quaternion
        case:
        }
        return
    }

    t0 := channel.times[key]
    t1 := channel.times[key + 1]
    delta := t1 - t0
    u := (t - t0) / delta if delta > 0 else 0

    #partial switch channel.path {
    case .Translation, .Scale:
        {
            result: [3]f32
            if channel.interp == .Linear {
                for component in 0 ..< 3 {
                    a := channel.values[key * channel.stride + component]
                    b := channel.values[(key + 1) * channel.stride + component]
                    result[component] = a + (b - a) * u
                }
            } else {
                stride := channel.stride
                offset := channel.comps
                for component in 0 ..< 3 {
                    p0 := channel.values[key * stride + offset + component]
                    p1 := channel.values[(key + 1) * stride + offset + component]
                    m0 := channel.values[key * stride + offset + channel.comps + component] * delta
                    m1 := channel.values[(key + 1) * stride + component] * delta
                    result[component] = hermite(p0, m0, p1, m1, u)
                }
            }
            if channel.path == .Translation {
                node.translation = result
            } else {
                node.scale = result
            }
        }
    case .Rotation:
        {
            quaternion: la.Quaternionf32
            if channel.interp == .Linear {
                q0 := la.quaternion_normalize(
                    transmute(la.Quaternionf32)[4]f32 {
                        channel.values[key * channel.stride + 0],
                        channel.values[key * channel.stride + 1],
                        channel.values[key * channel.stride + 2],
                        channel.values[key * channel.stride + 3],
                    },
                )
                q1 := la.quaternion_normalize(
                    transmute(la.Quaternionf32)[4]f32 {
                        channel.values[(key + 1) * channel.stride + 0],
                        channel.values[(key + 1) * channel.stride + 1],
                        channel.values[(key + 1) * channel.stride + 2],
                        channel.values[(key + 1) * channel.stride + 3],
                    },
                )
                quaternion = la.quaternion_slerp_f32(q0, q1, u)
            } else {
                stride := channel.stride
                offset := channel.comps
                q0: [4]f32
                q1: [4]f32
                m0: [4]f32
                m1: [4]f32
                for component in 0 ..< 4 {
                    q0[component] = channel.values[key * stride + offset + component]
                    q1[component] = channel.values[(key + 1) * stride + offset + component]
                    m0[component] =
                        channel.values[key * stride + offset + channel.comps + component] * delta
                    m1[component] = channel.values[(key + 1) * stride + component] * delta
                }
                result := [4]f32 {
                    hermite(q0[0], m0[0], q1[0], m1[0], u),
                    hermite(q0[1], m0[1], q1[1], m1[1], u),
                    hermite(q0[2], m0[2], q1[2], m1[2], u),
                    hermite(q0[3], m0[3], q1[3], m1[3], u),
                }
                quaternion = la.quaternion_normalize(transmute(la.Quaternionf32)result)
            }
            node.rotation = transmute([4]f32)quaternion
        }
    case:
    }
}

// The standard CUBICSPLINE Hermite basis for parameter u in [0,1]. The tangent
// coefficients are pre-scaled by the key delta by the caller, as the glTF
// specification requires.
@(private = "file")
hermite :: proc(p0, m0, p1, m1, u: f32) -> f32 {
    u2 := u * u
    u3 := u2 * u
    c0 := 2 * u3 - 3 * u2 + 1
    c1 := u3 - 2 * u2 + u
    c2 := -2 * u3 + 3 * u2
    c3 := u3 - u2
    return c0 * p0 + c1 * m0 + c2 * p1 + c3 * m1
}

// Samples every animation group at time `t` and rebuilds the node globals so a
// backend can upload updated instance transforms.
gltf_model_animate_all :: proc(model: ^Gltf_Model, t: f32) {
    if !model.has_animations {
        return
    }
    for &group in model.animations {
        tt := t
        if group.length > 0 {
            tt = t - math.floor(t / group.length) * group.length
        }
        for channel_index in 0 ..< len(group.channels) {
            evaluate_channel(model, &group.channels[channel_index], tt)
        }
    }
    for root in model.roots {
        globals_recursive_animated(model, root, la.MATRIX4F32_IDENTITY)
    }
}

// -------------------------------------------------------------- instances --

@(private = "file")
collect_instance_nodes :: proc(
    model: ^Gltf_Model,
    document: ^gltf.Document,
    node_index: int,
    mesh_index: int,
) {
    node := &document.nodes[node_index]
    // Skinned meshes are skipped: without a skinning path the mesh would be
    // drawn at the joint transform instead of its own.
    if node.mesh != nil && node.skin == nil {
        mi := mesh_index_of(document, node.mesh)
        if mi == mesh_index {
            append(&model.meshes[mesh_index].instance_nodes, node_index)
        }
    }
    for child in model.nodes[node_index].children {
        collect_instance_nodes(model, document, child, mesh_index)
    }
}

// Walks the whole scene tree once, gathering each mesh's instancing nodes.
@(private = "file")
collect_all_instance_nodes :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    for index in 0 ..< len(model.meshes) {
        model.meshes[index].instance_nodes = make([dynamic]int, 0, 0, model.allocator)
        for root in model.roots {
            collect_instance_nodes(model, document, root, index)
        }
        model.meshes[index].instance_count = u32(len(model.meshes[index].instance_nodes))
    }
}

// ---------------------------------------------------------- preset cameras --

Gltf_Preset_Camera :: struct {
    node:        int,
    perspective: bool,
    yfov:        f32,
    znear:       f32,
    zfar:        f32, // < 0 when infinite
    xmag:        f32, // 0 when unknown (derived from ymag * aspect)
    ymag:        f32,
}

@(private = "file")
build_preset_cameras :: proc(document: ^gltf.Document, model: ^Gltf_Model) {
    model.preset_cameras = make([dynamic]Gltf_Preset_Camera, 0, 0, model.allocator)
    for camera_index in 0 ..< len(document.cameras) {
        camera := &document.cameras[camera_index]
        for node_index in 0 ..< len(document.nodes) {
            if document.nodes[node_index].camera != camera {
                continue
            }
            preset := Gltf_Preset_Camera {
                node = node_index,
            }
            switch camera.type {
            case .Perspective:
                preset.perspective = true
                preset.yfov = camera.perspective.yfov
                preset.znear = camera.perspective.znear
                // glTF allows an absent far plane, meaning "infinite".
                preset.zfar = camera.perspective.zfar if camera.perspective.has_zfar else -1
            case .Orthographic:
                preset.perspective = false
                preset.xmag = camera.orthographic.xmag
                preset.ymag = camera.orthographic.ymag
                preset.znear = camera.orthographic.znear
                preset.zfar = camera.orthographic.zfar
            case .Invalid:
                continue
            }
            append(&model.preset_cameras, preset)
        }
    }
}

// ------------------------------------------------------------------ bounds --

// World-space AABB over every instance of every primitive's local box.
@(private = "file")
compute_world_bounds :: proc(model: ^Gltf_Model) {
    for mesh_index in 0 ..< len(model.meshes) {
        mesh := &model.meshes[mesh_index]
        for node_index in mesh.instance_nodes {
            global := model.nodes[node_index].global
            for primitive_index in 0 ..< len(mesh.primitives) {
                primitive := &mesh.primitives[primitive_index]
                for corner in 0 ..< 8 {
                    point: [3]f32
                    for axis in 0 ..< 3 {
                        source :=
                            primitive.aabb_min[axis] if (corner & (1 << uint(axis))) == 0 else primitive.aabb_max[axis]
                        point[axis] = source
                    }
                    world_point := transform_point(global, point)
                    for axis in 0 ..< 3 {
                        model.aabb_min[axis] = min(model.aabb_min[axis], world_point[axis])
                        model.aabb_max[axis] = max(model.aabb_max[axis], world_point[axis])
                    }
                }
            }
        }
    }
}

@(private = "file")
compute_scene_bounds :: proc(model: ^Gltf_Model) {
    if model.aabb_min[0] > model.aabb_max[0] {
        // No geometry: default framing.
        model.center = {}
        model.radius = 1
        return
    }
    model.center = (model.aabb_min + model.aabb_max) * 0.5
    // The viewer frames the model at `radius = |AABB diagonal|` (its user
    // camera eye sits `radius` units away along +Z with yfov = PI / 3).
    model.radius = length3(model.aabb_max - model.aabb_min)
}

// ------------------------------------------------------------ load/unload --

// The loaded, renderer-agnostic model. Owns every array; pair a successful
// gltf_model_load with gltf_model_unload.
Gltf_Model :: struct {
    allocator:      mem.Allocator,
    vertices:       [dynamic]Gltf_Vertex,
    indices:        [dynamic]u32,
    meshes:         [dynamic]Gltf_Mesh,
    materials:      [dynamic]Gltf_Material, // index 0 = synthesized default
    textures:       [dynamic]Gltf_Texture, // parallel to document.textures
    nodes:          [dynamic]Gltf_Node,
    roots:          []int,
    animations:     [dynamic]Gltf_Animation_Group,
    preset_cameras: [dynamic]Gltf_Preset_Camera,
    has_animations: bool,
    aabb_min:       [3]f32,
    aabb_max:       [3]f32,
    radius:         f32,
    center:         [3]f32,
}

gltf_model_load :: proc(path: string, allocator: mem.Allocator) -> (model: Gltf_Model, ok: bool) {
    document_handle, load_err := gltf_load(path, allocator)
    if load_err != .None {
        log.errorf("Failed to load %s: %v", path, load_err)
        return {}, false
    }
    defer gltf_unload(&document_handle)
    document := document_handle.data

    model.allocator = allocator
    model.aabb_min = {max(f32), max(f32), max(f32)}
    model.aabb_max = {-max(f32), -max(f32), -max(f32)}

    loader := Loader {
        document  = document,
        allocator = allocator,
    }

    vertex_count, index_count := build_geometry(&loader, &model)
    build_materials(document, &model)
    build_textures(document, &model)
    decode_textures(&loader, &model)
    build_nodes(document, &model)
    build_animations(document, &model)
    compute_globals_static(document, &model)
    collect_all_instance_nodes(document, &model)
    compute_world_bounds(&model)
    compute_scene_bounds(&model)
    build_preset_cameras(document, &model)

    log.infof(
        "Model %s: %d nodes, %d meshes, %d materials, %d textures, %d vertices, %d indices, %d animations, %d preset cameras",
        path,
        len(model.nodes),
        len(model.meshes),
        len(model.materials) - 1,
        len(model.textures),
        vertex_count,
        index_count,
        len(model.animations),
        len(model.preset_cameras),
    )
    return model, true
}

// Releases everything the model owns and zeroes it.
gltf_model_unload :: proc(model: ^Gltf_Model) {
    a := model.allocator
    for &texture in model.textures {
        if texture.pixels != nil {
            delete(texture.pixels, a)
        }
    }
    delete(model.textures)

    for &mesh in model.meshes {
        delete(mesh.primitives)
        delete(mesh.instance_nodes)
    }
    delete(model.meshes)

    for &group in model.animations {
        for &channel in group.channels {
            delete(channel.times, a)
            delete(channel.values, a)
        }
        delete(group.channels)
    }
    delete(model.animations)

    for &node in model.nodes {
        delete(node.children, a)
    }
    delete(model.nodes)
    delete(model.roots, a)
    delete(model.preset_cameras)
    delete(model.materials)
    delete(model.vertices)
    delete(model.indices)

    model^ = {}
}
