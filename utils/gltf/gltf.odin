package gltf

// Core
import "core:mem"

import la "core:math/linalg"

// Error describes why a load or validation failed.
Error :: enum {
    None = 0,
    // The input was too small or a buffer/bufferView was shorter than the
    // data addressed by an accessor.
    Data_Too_Short,
    // The magic/version of a GLB, or a `file_type` that disagrees with the
    // detected format.
    Unknown_Format,
    // The JSON payload is not well formed.
    Invalid_Json,
    // The document is not a valid glTF 2.0 document: missing `asset`,
    // out of range indices, bad enum strings, ...
    Invalid_Gltf,
    // A required member was missing, or a member was present but not of the
    // type the schema requires.
    Invalid_Schema,
    // `Options` were rejected.
    Invalid_Options,
    // A referenced file could not be opened.
    File_Not_Found,
    // A file could be opened but not read.
    Io_Error,
    // An allocation failed.
    Out_Of_Memory,
    // The document declares a glTF version older than 2.0.
    Legacy_Gltf,
    // A required argument was nil or otherwise unusable.
    Invalid_Argument,
    // An index passed to a reader was outside the accessor's `count`.
    Index_Out_Of_Range,
    // A component type and element type combination is not a valid glTF
    // accessor (for example `MAT4` of `UNSIGNED_BYTE`).
    Unsupported_Accessor_Layout,
}

// The container format of a document.
File_Type :: enum {
    Invalid = 0,
    Gltf,
    Glb,
}

// The intended GPU buffer a bufferView feeds.
Buffer_View_Target :: enum {
    Invalid              = 0,
    Array_Buffer         = 34962,
    Element_Array_Buffer = 34963,
}

// Identifies a well known vertex attribute semantic.
Attribute_Type :: enum {
    Invalid = 0,
    Position,
    Normal,
    Tangent,
    Texcoord,
    Color,
    Joints,
    Weights,
    Custom,
}

// The scalar type of an accessor element.
Component_Type :: enum {
    Invalid = 0,
    Byte, // 5120 - signed 8-bit
    Unsigned_Byte, // 5121
    Short, // 5122 - signed 16-bit
    Unsigned_Short, // 5123
    Unsigned_Int, // 5125
    Float, // 5126
}

// The shape of an accessor element.
Element_Type :: enum {
    Invalid = 0,
    Scalar,
    Vec2,
    Vec3,
    Vec4,
    Mat2,
    Mat3,
    Mat4,
}

// How a primitive's indices are assembled into geometry.
Primitive_Mode :: enum {
    Invalid = 0,
    Points,
    Lines,
    Line_Loop,
    Line_Strip,
    Triangles,
    Triangle_Strip,
    Triangle_Fan,
}

// Used in `material.alphaMode`.
Alpha_Mode :: enum {
    Opaque = 0,
    Mask,
    Blend,
}

// The property an animation channel drives.
Animation_Path :: enum {
    Invalid = 0,
    Translation,
    Rotation,
    Scale,
    Weights,
    // KHR_animation_pointer addresses a property by JSON pointer instead of
    // naming a node property.
    Pointer,
}

// Interpolation is `animation.sampler.interpolation`.
Interpolation :: enum {
    Linear = 0,
    Step,
    Cubic_Spline,
}

// The projection of a camera.
Camera_Type :: enum {
    Invalid = 0,
    Perspective,
    Orthographic,
}

// The KHR_lights_punctual light kind.
Light_Type :: enum {
    Invalid = 0,
    Directional,
    Point,
    Spot,
}

// The sampler magnification/minification filter. `Undefined` means the member
// was absent, which per the schema leaves filtering implementation defined.
Filter_Type :: enum {
    Undefined              = 0,
    Nearest                = 9728,
    Linear                 = 9729,
    Nearest_Mipmap_Nearest = 9984,
    Linear_Mipmap_Nearest  = 9985,
    Nearest_Mipmap_Linear  = 9986,
    Linear_Mipmap_Linear   = 9987,
}

// The sampler wrap mode.
Wrap_Mode :: enum {
    Repeat          = 10497,
    Clamp_To_Edge   = 33071,
    Mirrored_Repeat = 33648,
}

// The EXT_meshopt_compression payload kind.
Meshopt_Compression_Mode :: enum {
    Attributes = 0,
    Triangles  = 1,
    Indices    = 2,
}

// The EXT_meshopt_compression post filter.
Meshopt_Compression_Filter :: enum {
    None = 0,
    Octahedral,
    Quaternion,
    Exponential,
    Color,
}

// Holds the raw JSON of an object's `extras` member, or "" when the object had
// none. `Extras.data` is compact, deterministic JSON text (object keys sorted)
// owned by the document's arena.
Extras :: struct {
    data: string,
}

// Extension member that this package does not interpret, kept verbatim.
// `Extension.data` is the extension's payload as compact, deterministic JSON
// text owned by the document's arena.
Extension :: struct {
    name: string,
    data: string,
}

// The KHR_texture_transform. `tex_coord` mirrors `Texture_View.tex_coord`: the
// extension lets a texture info override which coordinate set it samples.
Texture_Transform :: struct {
    offset:    [2]f32,
    rotation:  f32,
    scale:     [2]f32,
    tex_coord: int,
}

// References a texture and the texture coordinate set it is sampled with.
// `scale` is only meaningful for occlusion, where it multiplies the sampled
// value.
Texture_View :: struct {
    texture:   ^Texture,
    tex_coord: int,
    scale:     f32,
    transform: Texture_Transform,
}

// The core glTF 2.0 material model.
Pbr_Metallic_Roughness :: struct {
    base_color_factor:          [4]f32,
    base_color_texture:         Texture_View,
    metallic_factor:            f32,
    roughness_factor:           f32,
    metallic_roughness_texture: Texture_View,
}

// The legacy (glTF 1.0) material model. A glTF 2.0 document must not use it.
Pbr_Specular_Glossiness :: struct {
    diffuse_factor:              [4]f32,
    diffuse_texture:             Texture_View,
    specular_factor:             [3]f32,
    glossiness_factor:           f32,
    specular_glossiness_texture: Texture_View,
}

// The KHR_materials_clearcoat.
Clearcoat :: struct {
    clearcoat_factor:            f32,
    clearcoat_texture:           Texture_View,
    clearcoat_roughness_factor:  f32,
    clearcoat_roughness_texture: Texture_View,
    clearcoat_normal_texture:    Texture_View,
}

// The KHR_materials_transmission.
Transmission :: struct {
    transmission_factor:  f32,
    transmission_texture: Texture_View,
}

// The KHR_materials_volume.
Volume :: struct {
    thickness_factor:     f32,
    thickness_texture:    Texture_View,
    attenuation_distance: f32,
    attenuation_color:    [3]f32,
}

// The KHR_materials_sheen.
Sheen :: struct {
    sheen_color_factor:      [3]f32,
    sheen_color_texture:     Texture_View,
    sheen_roughness_factor:  f32,
    sheen_roughness_texture: Texture_View,
}

// The KHR_materials_ior.
IOR :: struct {
    ior: f32,
}

// Specular is KHR_materials_specular.
Specular :: struct {
    specular_factor:        f32,
    specular_color_factor:  [3]f32,
    specular_texture:       Texture_View,
    specular_color_texture: Texture_View,
}

// Iridescence is KHR_materials_iridescence.
Iridescence :: struct {
    iridescence_factor:  f32,
    iridescence_texture: Texture_View,
    ior:                 f32,
    thickness_min:       f32,
    thickness_max:       f32,
    thickness_texture:   Texture_View,
}

// The KHR_materials_diffuse_transmission.
Diffuse_Transmission :: struct {
    diffuse_transmission_factor:  f32,
    diffuse_transmission_texture: Texture_View,
    color_factor:                 [3]f32,
    color_texture:                Texture_View,
}

// The KHR_materials_anisotropy.
Anisotropy :: struct {
    strength: f32,
    rotation: f32,
    texture:  Texture_View,
}

// The KHR_materials_emissive_strength.
Emissive_Strength :: struct {
    strength: f32,
}

// The KHR_materials_dispersion.
Dispersion :: struct {
    dispersion: f32,
}

// Binds a KHR_materials_variants variant to a material.
Material_Mapping :: struct {
    variant:  int,
    material: ^Material,
    extras:   Extras,
}

// The `materials[i]`.
Material :: struct {
    name:                     string,
    extensions:               []Extension,
    extras:                   Extras,
    pbr:                      Pbr_Metallic_Roughness,
    normal_texture:           Texture_View,
    occlusion_texture:        Texture_View,
    emissive_texture:         Texture_View,
    emissive_factor:          [3]f32,
    alpha_mode:               Alpha_Mode,
    alpha_cutoff:             f32,
    double_sided:             bool,
    unlit:                    bool,

    // Extension payloads.
    //
    // The `has*` flags record whether the extension was present in the file,
    // which is otherwise only visible by scanning `Material.extensions`.
    has_specular_glossiness:  bool,
    specular_glossiness:      Pbr_Specular_Glossiness,
    has_clearcoat:            bool,
    clearcoat:                Clearcoat,
    has_transmission:         bool,
    transmission:             Transmission,
    has_volume:               bool,
    volume:                   Volume,
    has_ior:                  bool,
    ior:                      IOR,
    has_specular:             bool,
    specular:                 Specular,
    has_sheen:                bool,
    sheen:                    Sheen,
    has_emissive_strength:    bool,
    emissive_strength:        Emissive_Strength,
    has_iridescence:          bool,
    iridescence:              Iridescence,
    has_diffuse_transmission: bool,
    diffuse_transmission:     Diffuse_Transmission,
    has_anisotropy:           bool,
    anisotropy:               Anisotropy,
    has_dispersion:           bool,
    dispersion:               Dispersion,
}

// The one `primitive.targets[i]`: a set of attributes that replace the base
// attributes when the target weights are applied.
Morph_Target :: struct {
    attributes: []Attribute,
}

// The KHR_draco_mesh_compression.
Draco_Mesh_Compression :: struct {
    buffer_view: ^Buffer_View,
    attributes:  []Attribute,
}

// The EXT_mesh_gpu_instancing.
Mesh_Gpu_Instancing :: struct {
    attributes: []Attribute,
}

// Binds one accessor to one semantic. `texCoord` and `Color` semantics carry a
// set index in `Attribute.index`.
Attribute :: struct {
    name:  string,
    type:  Attribute_Type,
    index: int,
    data:  ^Accessor,
}

// The one drawable part of a `Mesh`.
Primitive :: struct {
    attributes: []Attribute,
    indices:    ^Accessor,
    material:   ^Material,
    mode:       Primitive_Mode,
    targets:    []Morph_Target,
    extras:     Extras,
    extensions: []Extension,

    // KHR_draco_mesh_compression.
    //
    // When present the primitive's accessors are still parsed; decoding the
    // compressed payload is up to the caller.
    draco:      Draco_Mesh_Compression,
    has_draco:  bool,

    // KHR_materials_variants.
    mappings:   []Material_Mapping,
}

// The `meshes[i]`.
Mesh :: struct {
    name:         string,
    primitives:   []Primitive,
    weights:      []f32,
    target_names: []string,
    extras:       Extras,
    extensions:   []Extension,
}

// The `buffers[i]`. `Buffer.data` is nil until `load_buffers` has run (or
// immediately for a GLB's implicit buffer 0, which points into `Document.bin`).
Buffer :: struct {
    name:       string,
    size:       int,
    uri:        string,
    data:       []byte,
    extras:     Extras,
    extensions: []Extension,
}

// The EXT_meshopt_compression.
Meshopt_Compression :: struct {
    buffer: ^Buffer,
    offset: int,
    size:   int,
    stride: int,
    count:  int,
    mode:   Meshopt_Compression_Mode,
    filter: Meshopt_Compression_Filter,
}

// The `bufferViews[i]`.
Buffer_View :: struct {
    name:        string,
    buffer:      ^Buffer,
    offset:      int,
    size:        int,
    stride:      int, // 0 means "tightly packed"
    target:      Buffer_View_Target,
    extras:      Extras,
    extensions:  []Extension,

    // Data is set by `load_buffers`; it is a view into `Buffer.data`.
    data:        []byte,
    // Means EXT_meshopt_compression was present.
    //
    // The payload is kept verbatim in `Buffer_View.extensions`; decompressing
    // it requires the `meshoptimizer` library and is not attempted here.
    has_meshopt: bool,
    meshopt:     Meshopt_Compression,
}

// The sparse overlay of an `Accessor`.
Accessor_Sparse :: struct {
    count:                  int,
    indices_buffer_view:    ^Buffer_View,
    indices_byte_offset:    int,
    indices_component_type: Component_Type,
    values_buffer_view:     ^Buffer_View,
    values_byte_offset:     int,
}

// The `accessors[i]`. `stride` is always non-zero after parsing: it falls back
// to the tightly packed element size.
Accessor :: struct {
    name:           string,
    component_type: Component_Type,
    type:           Element_Type,
    offset:         int,
    count:          int,
    stride:         int,
    buffer_view:    ^Buffer_View,
    min:            [16]f32,
    max:            [16]f32,
    sparse:         Accessor_Sparse,
    extras:         Extras,
    extensions:     []Extension,
    has_max:        bool,
    has_sparse:     bool,
    normalized:     bool,
    has_min:        bool,
}

// The `images[i]`. Exactly one of `Image.uri` (external or data URI)
// and `Image.buffer_view` (GLB/embedded binary chunk) is set.
Image :: struct {
    name:        string,
    uri:         string,
    buffer_view: ^Buffer_View,
    mime_type:   string,
    extras:      Extras,
    extensions:  []Extension,
}

// The `samplers[i]`.
Sampler :: struct {
    name:       string,
    mag_filter: Filter_Type, // Filter_Type.Undefined when absent
    min_filter: Filter_Type, // Filter_Type.Undefined when absent
    wrap_s:     Wrap_Mode, // Repeat when absent
    wrap_t:     Wrap_Mode, // Repeat when absent
    extras:     Extras,
    extensions: []Extension,
}

// The `textures[i]`. `Texture.source` is the fallback image; the
// BasisU/WebP images take precedence when present.
Texture :: struct {
    name:          string,
    source:        ^Image,
    sampler:       ^Sampler,
    extras:        Extras,
    extensions:    []Extension,
    basisu_source: ^Image,
    webp_source:   ^Image,
    has_basisu:    bool,
    has_webp:      bool,
}

// The `skins[i]`.
Skin :: struct {
    name:                  string,
    joints:                []^Node,
    skeleton:              ^Node,
    inverse_bind_matrices: ^Accessor,
    extras:                Extras,
    extensions:            []Extension,
}

// The perspective projection.
Camera_Perspective :: struct {
    aspect_ratio:     f32,
    yfov:             f32,
    zfar:             f32,
    znear:            f32,
    has_zfar:         bool,
    has_aspect_ratio: bool,
}

// The orthographic projection.
Camera_Orthographic :: struct {
    xmag:  f32,
    ymag:  f32,
    zfar:  f32,
    znear: f32,
}

// The `cameras[i]`.
Camera :: struct {
    name:         string,
    type:         Camera_Type,
    perspective:  Camera_Perspective,
    orthographic: Camera_Orthographic,
    extras:       Extras,
    extensions:   []Extension,
}

// The KHR_lights_punctual light, reached through `Node.light`.
Light :: struct {
    name:                  string,
    color:                 [3]f32,
    intensity:             f32,
    type:                  Light_Type,
    range:                 f32, // 0 when absent, meaning "infinite"
    spot_inner_cone_angle: f32,
    spot_outer_cone_angle: f32,
    extras:                Extras,
    extensions:            []Extension,
}

// The `nodes[i]`. When neither `matrix` nor any of
// `translation`/`rotation`/`scale` is present the node is the identity.
Node :: struct {
    name:               string,
    children:           []^Node,
    mesh:               ^Mesh,
    camera:             ^Camera,
    skin:               ^Skin,
    matrix_:            la.Matrix4f32,
    has_matrix:         bool,
    translation:        [3]f32,
    has_translation:    bool,
    rotation:           [4]f32,
    has_rotation:       bool,
    scale:              [3]f32,
    has_scale:          bool,
    weights:            []f32,
    light:              ^Light,
    has_gpu_instancing: bool,
    gpu_instancing:     Mesh_Gpu_Instancing,
    extras:             Extras,
    extensions:         []Extension,

    // Parent is the node that lists this node in its Children.  It is nil for
    // a root node, and is linked once the whole node list exists.
    parent:             ^Node,
}

// The `scenes[i]`.
Scene :: struct {
    name:       string,
    nodes:      []^Node,
    extras:     Extras,
    extensions: []Extension,
}

// The `animations[i].samplers[j]`.
Animation_Sampler :: struct {
    input:         ^Accessor,
    output:        ^Accessor,
    interpolation: Interpolation,
    extras:        Extras,
    extensions:    []Extension,
}

// The `animations[i].channels[j]`.
Animation_Channel :: struct {
    sampler:           ^Animation_Sampler,
    target_node:       ^Node,
    target_path:       Animation_Path,
    // Extensions attached to the channel target (for example
    // KHR_animation_pointer).
    target_extensions: []Extension,
    extras:            Extras,
    extensions:        []Extension,
}

// The `animations[i]`.
Animation :: struct {
    name:       string,
    channels:   []Animation_Channel,
    samplers:   []Animation_Sampler,
    extras:     Extras,
    extensions: []Extension,
}

// The one entry of the `KHR_materials_variants` root extension.
Material_Variant :: struct {
    name:   string,
    extras: Extras,
}

// The mandatory `asset` object.
Asset :: struct {
    copyright:   string,
    generator:   string,
    version:     string,
    min_version: string,
    extras:      Extras,
    extensions:  []Extension,
}

// Configures `parse`, `parse_file` and `load_buffers`.
Options :: struct {
    // Allocator used for the Document, file bytes, and arena backing on targets
    // without virtual memory. Defaults to `context.allocator` when nil.
    allocator:      mem.Allocator,

    // Force a container format instead of sniffing the magic. `.Invalid`
    // (the default) auto-detects.
    file_type:      File_Type,

    // Resolve `buffer.uri` relative to this directory instead of
    // `Document.file_name`.  Ignored when empty.
    base_directory: string,

    // Hook used by `load_buffers` to obtain an external resource. When nil,
    // native builds read from disk and JS builds cannot resolve external URIs.
    // The returned bytes must be valid until the document is destroyed.
    //
    // The hook takes the same `user_data` the caller passed, rather than
    // closing over its own state, so that a top level procedure is enough:
    //
    //     Read_File :: proc(path: string, user_data: rawptr) -> ([]byte, Error) {
    //         state := cast(^Loader_State) user_data
    //         ...
    //     }
    read_file:      proc(path: string, user_data: rawptr) -> (data: []byte, err: Error),

    // Passed to `Options.read_file` unchanged.
    user_data:      rawptr,
}

// The parsed glTF document.
//
// Slices are allocated at their final size before cross references are
// resolved, so the `Document` graph is fully non-nil wherever the schema
// guarantees a member: only genuinely optional members (and members that were
// absent from the file) are nil.
Document :: struct {
    file_type:           File_Type,
    file_name:           string,
    // The bytes read by `parse_file`; nil for `parse`.
    file_data:           []byte,
    asset:               Asset,
    accessors:           []Accessor,
    animations:          []Animation,
    buffers:             []Buffer,
    buffer_views:        []Buffer_View,
    cameras:             []Camera,
    images:              []Image,
    materials:           []Material,
    meshes:              []Mesh,
    nodes:               []Node,
    samplers:            []Sampler,
    scenes:              []Scene,
    skins:               []Skin,
    textures:            []Texture,

    // Come from KHR_lights_punctual and are referenced by `Node.light`; they
    // are not part of the base schema.
    lights:              []Light,
    // Come from KHR_materials_variants.
    variants:            []Material_Variant,

    // The default scene.
    scene:               ^Scene,
    extensions_used:     []string,
    extensions_required: []string,
    // Holds root extension members that this package does not interpret.
    extensions:          []Extension,
    extras:              Extras,

    // The JSON text of the document: for a `.gltf` the whole input, for a
    // `.glb` just the JSON chunk. It aliases the caller's bytes.
    json:                string,
    // The GLB `BIN` chunk, if any. It aliases the caller's bytes.
    bin:                 []byte,
    arena:               Document_Arena,
    // The allocator `Document.file_data` was read with, so that `destroy` can
    // give it back. It is nil for a document that did not come from
    // `parse_file`.
    file_allocator:      mem.Allocator,
    // Owns the Document object itself; the embedded arena owns the rest of its
    // graph and is destroyed separately.
    document_allocator:  mem.Allocator,
}
