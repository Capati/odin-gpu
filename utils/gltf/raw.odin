package gltf

// Core
import "core:encoding/json"

// This file is the schema-shaped mirror of the glTF 2.0 JSON document. It is
// filled by the streaming readers in `reader.odin`; the public `Document`
// graph is built from it by `convert.odin`.
//
// Three conventions run through all of these structs:
//
//   - Optional members are `Maybe(T)`. This is load bearing: an absent member
//     and a `0` member must stay distinguishable, since `0` is a valid value
//     for every member with a non-zero schema default and a valid index for
//     every index-valued member.
//   - Members whose type is an enum string are kept as `string` and converted
//     by an explicit switch in `enum.odin`, which also reports an unknown
//     value instead of silently mapping it to zero.
//   - `extras` and `extensions` are kept as `json.Value`; `extensions` is read
//     with the small accessor layer in `value.odin`.

// -----------------------------------------------------------------------------
// Asset
// -----------------------------------------------------------------------------

Raw_Asset :: struct {
    name:        string,
    copyright:   string,
    generator:   string,
    version:     string,
    min_version: string,
    extras:      json.Value,
    extensions:  json.Value,
}

// -----------------------------------------------------------------------------
// buffer view
// -----------------------------------------------------------------------------

Raw_Buffer_View :: struct {
    name:        string,
    buffer:      int,
    byte_offset: int,
    byte_length: int,
    byte_stride: int,
    target:      int,
    extras:      json.Value,
    extensions:  json.Value,
}

// -----------------------------------------------------------------------------
// buffer
// -----------------------------------------------------------------------------

Raw_Buffer :: struct {
    name:        string,
    byte_length: int,
    uri:         string,
    extras:      json.Value,
    extensions:  json.Value,
}

// -----------------------------------------------------------------------------
// accessor
// -----------------------------------------------------------------------------

Raw_Sparse_Indices :: struct {
    buffer_view:    int,
    byte_offset:    int,
    component_type: int,
}

Raw_Sparse_Values :: struct {
    buffer_view: int,
    byte_offset: int,
}

Raw_Sparse :: struct {
    count:   int,
    indices: Raw_Sparse_Indices,
    values:  Raw_Sparse_Values,
}

Raw_Accessor :: struct {
    name:           string,
    buffer_view:    Maybe(int),
    byte_offset:    int,
    component_type: int,
    normalized:     bool,
    count:          int,
    type:           string,
    min:            []f32,
    max:            []f32,
    sparse:         Maybe(Raw_Sparse),
    extras:         json.Value,
    extensions:     json.Value,
}

// -----------------------------------------------------------------------------
// images
// -----------------------------------------------------------------------------

Raw_Image :: struct {
    name:        string,
    uri:         string,
    mime_type:   string,
    buffer_view: Maybe(int),
    extras:      json.Value,
    extensions:  json.Value,
}

// -----------------------------------------------------------------------------
// samplers
// -----------------------------------------------------------------------------

Raw_Sampler :: struct {
    name:       string,
    mag_filter: int,
    min_filter: int,
    wrap_s:     int,
    wrap_t:     int,
    extras:     json.Value,
    extensions: json.Value,
}

// -----------------------------------------------------------------------------
// textures
// -----------------------------------------------------------------------------

Raw_Texture :: struct {
    name:       string,
    sampler:    Maybe(int),
    source:     Maybe(int),
    extras:     json.Value,
    extensions: json.Value,
}

// -----------------------------------------------------------------------------
// material
// -----------------------------------------------------------------------------

Raw_Texture_Info :: struct {
    index:      int,
    tex_coord:  int,
    scale:      Maybe(f32),
    strength:   Maybe(f32),
    // Extensions is normally only KHR_texture_transform.
    extensions: json.Value,
    extras:     json.Value,
}

Raw_Pbr :: struct {
    base_color_factor:          Maybe([4]f32),
    base_color_texture:         Maybe(Raw_Texture_Info),
    metallic_factor:            Maybe(f32),
    roughness_factor:           Maybe(f32),
    metallic_roughness_texture: Maybe(Raw_Texture_Info),
    extras:                     json.Value,
}

Raw_Specular_Glossiness :: struct {
    diffuse_factor:              Maybe([4]f32),
    diffuse_texture:             Maybe(Raw_Texture_Info),
    specular_factor:             Maybe([3]f32),
    glossiness_factor:           Maybe(f32),
    specular_glossiness_texture: Maybe(Raw_Texture_Info),
    extras:                      json.Value,
}

Raw_Clearcoat :: struct {
    clearcoat_factor:            Maybe(f32),
    clearcoat_texture:           Maybe(Raw_Texture_Info),
    clearcoat_roughness_factor:  Maybe(f32),
    clearcoat_roughness_texture: Maybe(Raw_Texture_Info),
    clearcoat_normal_texture:    Maybe(Raw_Texture_Info),
    extras:                      json.Value,
    extensions:                  json.Value,
}

Raw_Transmission :: struct {
    transmission_factor:  Maybe(f32),
    transmission_texture: Maybe(Raw_Texture_Info),
    extras:               json.Value,
    extensions:           json.Value,
}

Raw_Volume :: struct {
    thickness_factor:     Maybe(f32),
    thickness_texture:    Maybe(Raw_Texture_Info),
    attenuation_distance: Maybe(f32),
    attenuation_color:    Maybe([3]f32),
    extras:               json.Value,
    extensions:           json.Value,
}

Raw_Ior :: struct {
    ior:        Maybe(f32),
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Specular :: struct {
    specular_factor:        Maybe(f32),
    specular_color_factor:  Maybe([3]f32),
    specular_texture:       Maybe(Raw_Texture_Info),
    specular_color_texture: Maybe(Raw_Texture_Info),
    extras:                 json.Value,
    extensions:             json.Value,
}

Raw_Sheen :: struct {
    sheen_color_factor:      Maybe([3]f32),
    sheen_color_texture:     Maybe(Raw_Texture_Info),
    sheen_roughness_factor:  Maybe(f32),
    sheen_roughness_texture: Maybe(Raw_Texture_Info),
    extras:                  json.Value,
    extensions:              json.Value,
}

Raw_Emissive_Strength :: struct {
    strength:   Maybe(f32),
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Iridescence :: struct {
    iridescence_factor:  Maybe(f32),
    iridescence_texture: Maybe(Raw_Texture_Info),
    ior:                 Maybe(f32),
    thickness_min:       Maybe(f32),
    thickness_max:       Maybe(f32),
    thickness_texture:   Maybe(Raw_Texture_Info),
    extras:              json.Value,
    extensions:          json.Value,
}

Raw_Diffuse_Transmission :: struct {
    diffuse_transmission_factor:  Maybe(f32),
    diffuse_transmission_texture: Maybe(Raw_Texture_Info),
    color_factor:                 Maybe([3]f32),
    color_texture:                Maybe(Raw_Texture_Info),
    extras:                       json.Value,
    extensions:                   json.Value,
}

Raw_Anisotropy :: struct {
    strength:   Maybe(f32),
    rotation:   Maybe(f32),
    texture:    Maybe(Raw_Texture_Info),
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Dispersion :: struct {
    dispersion: Maybe(f32),
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Material :: struct {
    name:              string,
    pbr:               Maybe(Raw_Pbr),
    normal_texture:    Maybe(Raw_Texture_Info),
    occlusion_texture: Maybe(Raw_Texture_Info),
    emissive_texture:  Maybe(Raw_Texture_Info),
    emissive_factor:   Maybe([3]f32),
    alpha_mode:        string,
    alpha_cutoff:      Maybe(f32),
    double_sided:      bool,
    extras:            json.Value,
    extensions:        json.Value,
}

// -----------------------------------------------------------------------------
// mesh
// -----------------------------------------------------------------------------

Raw_Attribute :: struct {
    name:  string,
    index: int,
}

Raw_Primitive :: struct {
    attributes: []Raw_Attribute,
    indices:    Maybe(int),
    material:   Maybe(int),
    mode:       Maybe(int),
    targets:    [][]Raw_Attribute,
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Mesh :: struct {
    name:       string,
    primitives: []Raw_Primitive,
    weights:    []f32,
    extras:     json.Value,
    extensions: json.Value,
}

// -----------------------------------------------------------------------------
// skin
// -----------------------------------------------------------------------------

Raw_Skin :: struct {
    name:                  string,
    inverse_bind_matrices: Maybe(int),
    skeleton:              Maybe(int),
    joints:                []int,
    extras:                json.Value,
    extensions:            json.Value,
}

// -----------------------------------------------------------------------------
// camera
// -----------------------------------------------------------------------------

Raw_Camera_Perspective :: struct {
    aspect_ratio: Maybe(f32),
    yfov:         f32,
    zfar:         Maybe(f32),
    znear:        f32,
    extras:       json.Value,
}

Raw_Camera_Orthographic :: struct {
    xmag:   f32,
    ymag:   f32,
    zfar:   f32,
    znear:  f32,
    extras: json.Value,
}

Raw_Camera :: struct {
    name:         string,
    type:         string,
    perspective:  Maybe(Raw_Camera_Perspective),
    orthographic: Maybe(Raw_Camera_Orthographic),
    extras:       json.Value,
    extensions:   json.Value,
}

// -----------------------------------------------------------------------------
// node
// -----------------------------------------------------------------------------

Raw_Node :: struct {
    name:        string,
    children:    []int,
    mesh:        Maybe(int),
    camera:      Maybe(int),
    skin:        Maybe(int),
    matrix_:     Maybe([16]f32),
    translation: Maybe([3]f32),
    rotation:    Maybe([4]f32),
    scale:       Maybe([3]f32),
    weights:     []f32,
    extras:      json.Value,
    extensions:  json.Value,
}

// -----------------------------------------------------------------------------
// scene
// -----------------------------------------------------------------------------

Raw_Scene :: struct {
    name:       string,
    nodes:      []int,
    extras:     json.Value,
    extensions: json.Value,
}

// -----------------------------------------------------------------------------
// animation
// -----------------------------------------------------------------------------

Raw_Animation_Sampler :: struct {
    input:         int,
    output:        int,
    interpolation: string,
    extras:        json.Value,
    extensions:    json.Value,
}

Raw_Animation_Channel :: struct {
    sampler:    int,
    target:     struct {
        node:       Maybe(int),
        path:       string,
        extensions: json.Value,
    },
    extras:     json.Value,
    extensions: json.Value,
}

Raw_Animation :: struct {
    name:       string,
    channels:   []Raw_Animation_Channel,
    samplers:   []Raw_Animation_Sampler,
    extras:     json.Value,
    extensions: json.Value,
}

// -----------------------------------------------------------------------------
// root
// -----------------------------------------------------------------------------

Raw_Root :: struct {
    asset:               Raw_Asset,
    scenes:              []Raw_Scene,
    scene:               Maybe(int),
    nodes:               []Raw_Node,
    meshes:              []Raw_Mesh,
    accessors:           []Raw_Accessor,
    buffer_views:        []Raw_Buffer_View,
    buffers:             []Raw_Buffer,
    materials:           []Raw_Material,
    textures:            []Raw_Texture,
    images:              []Raw_Image,
    samplers:            []Raw_Sampler,
    cameras:             []Raw_Camera,
    animations:          []Raw_Animation,
    skins:               []Raw_Skin,
    extensions_used:     []string,
    extensions_required: []string,
    extras:              json.Value,
    extensions:          json.Value,
}
