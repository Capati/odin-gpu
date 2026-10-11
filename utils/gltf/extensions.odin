package gltf

// Core
import "base:runtime"
import "core:encoding/json"
import "core:strings"

// Extension payloads are not part of the base schema, so they are read out of
// the raw `json.Value` subtree that `extensions` was parsed into. Each parser
// here is tolerant in the way the specification is: an absent member takes its
// schema default, an unrecognised member is ignored, and a member with the
// wrong JSON type is reported as `Error.Invalid_Gltf` instead of being
// silently zeroed.

KHR_LIGHTS_PUNCTUAL :: "KHR_lights_punctual"
KHR_TEXTURE_TRANSFORM :: "KHR_texture_transform"
KHR_DRACO_MESH_COMPRESSION :: "KHR_draco_mesh_compression"
KHR_MATERIALS_VARIANTS :: "KHR_materials_variants"
KHR_MATERIALS_UNLIT :: "KHR_materials_unlit"
KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS :: "KHR_materials_pbrSpecularGlossiness"
KHR_MATERIALS_CLEARCOAT :: "KHR_materials_clearcoat"
KHR_MATERIALS_TRANSMISSION :: "KHR_materials_transmission"
KHR_MATERIALS_VOLUME :: "KHR_materials_volume"
KHR_MATERIALS_IOR :: "KHR_materials_ior"
KHR_MATERIALS_SPECULAR :: "KHR_materials_specular"
KHR_MATERIALS_SHEEN :: "KHR_materials_sheen"
KHR_MATERIALS_EMISSIVE_STRENGTH :: "KHR_materials_emissive_strength"
KHR_MATERIALS_IRIDESCENCE :: "KHR_materials_iridescence"
KHR_MATERIALS_DIFFUSE_TRANSMISSION :: "KHR_materials_diffuse_transmission"
KHR_MATERIALS_ANISOTROPY :: "KHR_materials_anisotropy"
KHR_MATERIALS_DISPERSION :: "KHR_materials_dispersion"
EXT_MESH_GPU_INSTANCING :: "EXT_mesh_gpu_instancing"
EXT_MESHOPT_COMPRESSION :: "EXT_meshopt_compression"
KHR_MESHOPT_COMPRESSION :: "KHR_meshopt_compression"
EXT_TEXTURE_WEBP :: "EXT_texture_webp"
EXT_TEXTURE_BASISU :: "EXT_texture_basisu"

// -----------------------------------------------------------------------------
// helpers
// -----------------------------------------------------------------------------

// Reads a JSON number member into `dest`, leaving it untouched when the member is
// absent. Returns false if the member is not a number.
@(private)
read_float_ext :: proc(object: json.Object, name: string, dest: ^f32) -> bool {
    value, present := member(object, name)
    if !present {
        return true
    }
    #partial switch v in value {
    case json.Float:
        dest^ = f32(v)
        return true
    case json.Integer:
        dest^ = f32(v)
        return true
    case:
        return false
    }
}

// Reads a JSON number array member into `dest`, leaving it untouched when the
// member is absent.  Returns false if the member is not an array of numbers, or is
// longer than `dest`.
@(private)
read_float_array :: proc(object: json.Object, name: string, dest: []f32) -> bool {
    array, present := member_array(object, name)
    if !present {
        return true
    }
    return fill_float_array(array, dest)
}

// extension_payload returns the object payload of the extension named `name`,
// if it is present and is an object.
@(private)
extension_payload :: proc(extensions: json.Value, name: string) -> (json.Object, bool) {
    object, ok := as_object(extensions)
    if !ok {
        return nil, false
    }
    return member_object(object, name)
}

// -----------------------------------------------------------------------------
// attribute names
// -----------------------------------------------------------------------------

// Splits a glTF attribute semantic into its `Attribute_Type` and set index,
// following the same rules as the C original: the text before the first `_` names
// the semantic, the text after it is the index, and a leading `_` marks an
// application-specific semantic.
@(private)
parse_attribute_type :: proc(name: string) -> (type: Attribute_Type, index: int) {
    if len(name) == 0 || name[0] == '_' {
        return .Custom, 0
    }
    head := name
    rest := ""
    if underscore := strings.index_byte(name, '_'); underscore >= 0 {
        head = name[:underscore]
        rest = name[underscore + 1:]
    }

    switch head {
    case "POSITION":
        type = .Position
    case "NORMAL":
        type = .Normal
    case "TANGENT":
        type = .Tangent
    case "TEXCOORD":
        type = .Texcoord
    case "COLOR":
        type = .Color
    case "JOINTS":
        type = .Joints
    case "WEIGHTS":
        type = .Weights
    case:
        // An unrecognised semantic with an index is still useful to a caller
        // that wants to look it up by name, so report it as custom rather than
        // invalid.
        return .Custom, 0
    }

    if rest == "" {
        return type, 0
    }
    parsed, ok := parse_uint(rest)
    if !ok {
        return .Custom, 0
    }
    return type, parsed
}

// -------------------------------------------------------- attribute objects ---

// sorted_keys returns the keys of `object` in ascending order.
//
// Extension payloads name attributes in a JSON object, and `core:encoding/json`
// stores that as a Go map whose iteration order is unspecified; sorting is what
// makes `Attribute` order reproducible across runs.
@(private)
sorted_keys :: proc(object: json.Object, allocator := context.allocator) -> [dynamic]string {
    keys := make([dynamic]string, 0, len(object), allocator)
    for key in object {
        append(&keys, key)
    }
    sort_strings_small(keys[:])
    return keys
}

// parse_attribute_object converts a `{SEMANTIC: n}` JSON object into a
// name-sorted `Attribute` slice.
//
// `resolve_accessors` selects what `n` means.  For a primitive's `attributes`
// and for EXT_mesh_gpu_instancing it is a glTF accessor index and is resolved
// into a pointer; for KHR_draco_mesh_compression it is a Draco attribute id
// which has no glTF accessor to point at, so it is kept in
// `Attribute.index`.
@(private)
parse_attribute_object :: proc(
    p: ^Parser,
    object: json.Object,
    resolve_accessors: bool,
) -> (
    []Attribute,
    bool,
) {
    if object == nil {
        return nil, true
    }

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = context.allocator == ta)
    keys := sorted_keys(object, ta)

    attributes := make([]Attribute, len(keys), p.allocator)
    values := make([]int, len(keys), p.allocator)
    for key, i in keys {
        value, found := member_int(object, key)
        if !found {
            return nil, false
        }
        type, index := parse_attribute_type(key)
        attributes[i] = Attribute{key, type, index, nil}
        values[i] = value
    }

    if resolve_accessors {
        if !resolve_attribute_accessors(attributes, values, p.document.accessors) {
            return nil, false
        }
    } else {
        for i in 0 ..< len(attributes) {
            attributes[i].index = values[i]
        }
    }
    return attributes, true
}

// ------------------------------------------------------- mesh gpu instancing ---

@(private)
parse_mesh_gpu_instancing :: proc(p: ^Parser, object: json.Object) -> (Mesh_Gpu_Instancing, bool) {
    attributes_object, ok := member_object(object, "attributes")
    if !ok {
        return Mesh_Gpu_Instancing{}, false
    }
    // EXT_mesh_gpu_instancing uses the same `{SEMANTIC: accessorIndex}` shape as
    // a primitive's attributes.
    attributes, parsed := parse_attribute_object(p, attributes_object, true)
    if !parsed {
        return Mesh_Gpu_Instancing{}, false
    }
    return Mesh_Gpu_Instancing{attributes = attributes}, true
}

// --------------------------------------------------------------- node: lights ---

// count_lights returns the number of light definitions in the root
// KHR_lights_punctual extension.
@(private)
count_lights :: proc(extensions: json.Value) -> int {
    payload, ok := extension_payload(extensions, KHR_LIGHTS_PUNCTUAL)
    if !ok {
        return 0
    }
    lights, present := member_array(payload, "lights")
    if !present {
        return 0
    }
    return len(lights)
}

// convert_lights fills the shared light definitions from the root extension.
@(private)
convert_lights :: proc(p: ^Parser, extensions: json.Value, out: []Light) -> Error {
    if len(out) == 0 {
        return .None
    }
    payload, ok := extension_payload(extensions, KHR_LIGHTS_PUNCTUAL)
    if !ok {
        return .Invalid_Gltf
    }
    values, present := member_array(payload, "lights")
    if !present || len(values) != len(out) {
        return .Invalid_Gltf
    }
    for value, i in values {
        object, is_object := value.(json.Object)
        if !is_object || !parse_light(p, object, &out[i]) {
            return .Invalid_Gltf
        }
    }
    return .None
}

@(private)
parse_node_extensions :: proc(
    p: ^Parser,
    extensions: json.Value,
    node: ^Node,
    lights: []Light,
) -> bool {
    object, object_ok := as_object(extensions)
    if !object_ok {
        return true
    }

    if payload, present := member_object(object, KHR_LIGHTS_PUNCTUAL); present {
        index, found := member_int(payload, "light")
        if found {
            if index < 0 || index >= len(lights) {
                return false
            }
            node.light = &lights[index]
        }
    }

    if payload, present := member_object(object, EXT_MESH_GPU_INSTANCING); present {
        instancing, ok := parse_mesh_gpu_instancing(p, payload)
        if !ok {
            return false
        }
        node.gpu_instancing = instancing
        node.has_gpu_instancing = true
    }

    return true
}

// parse_light fills a `Light` from a KHR_lights_punctual payload.
//
// The payload is a full description of the light rather than a reference to a
// shared one, so a light referenced by several nodes is simply described
// several times; the last writer wins.
@(private)
parse_light :: proc(p: ^Parser, object: json.Object, light: ^Light) -> bool {
    type, ok := member_string(object, "type")
    if !ok {
        return false
    }
    kind := light_type_from_string(type)
    if kind == nil {
        return false
    }

    light.type = kind.?
    light.color = {1, 1, 1}
    light.intensity = 1
    light.range = 0
    light.spot_inner_cone_angle = 0
    light.spot_outer_cone_angle = DEFAULT_SPOT_OUTER_CONE_ANGLE
    light.name = ""

    if name, present := member_string(object, "name"); present {
        light.name = name
    }
    if spot, present := member_object(object, "spot"); present {
        if !read_float_ext(spot, "innerConeAngle", &light.spot_inner_cone_angle) {
            return false
        }
        if !read_float_ext(spot, "outerConeAngle", &light.spot_outer_cone_angle) {
            return false
        }
        if light.spot_inner_cone_angle < 0 ||
           light.spot_outer_cone_angle <= light.spot_inner_cone_angle {
            return false
        }
    }
    if !read_float_array(object, "color", light.color[:]) {
        return false
    }
    if !read_float_ext(object, "intensity", &light.intensity) {
        return false
    }
    if !read_float_ext(object, "range", &light.range) {
        return false
    }
    if light.intensity < 0 || light.range < 0 {
        return false
    }
    return true
}

// ------------------------------------------------------- texture: transforms ---

@(private)
parse_texture_transform :: proc(
    p: ^Parser,
    extensions: json.Value,
    transform: ^Texture_Transform,
) -> bool {
    payload, payload_ok := extension_payload(extensions, KHR_TEXTURE_TRANSFORM)
    if !payload_ok {
        return true
    }
    if !read_float_array(payload, "offset", transform.offset[:]) {
        return false
    }
    if !read_float_array(payload, "scale", transform.scale[:]) {
        return false
    }
    if !read_float_ext(payload, "rotation", &transform.rotation) {
        return false
    }
    if tex_coord, tex_coord_ok := member_int(payload, "texCoord"); tex_coord_ok {
        if tex_coord < 0 {
            return false
        }
        transform.tex_coord = tex_coord
    }
    return true
}

// parse_texture_info_object reads a `textureInfo`-shaped JSON object, which is
// what the material extensions use.
@(private)
parse_texture_info_object :: proc(p: ^Parser, object: json.Object) -> (Texture_View, bool) {
    empty := Texture_View {
        scale = 1,
    }
    index, found := member_int(object, "index")
    if !found || index < 0 {
        return empty, false
    }

    tex_coord := 0
    if value, present := member_int(object, "texCoord"); present {
        if value < 0 {
            return empty, false
        }
        tex_coord = value
    }

    view := Texture_View {
        tex_coord = tex_coord,
        scale = 1,
        transform = Texture_Transform{scale = {1, 1}, tex_coord = tex_coord},
    }
    if !read_float_ext(object, "scale", &view.scale) {
        return empty, false
    }
    if !fixup_index_single(Texture, rawptr(&view.texture), index, p.document.textures) {
        return empty, false
    }
    if extensions_value, present := member(object, "extensions"); present {
        if !parse_texture_transform(p, extensions_value, &view.transform) {
            return empty, false
        }
    }
    return view, true
}

// ----------------------------------------------------------- texture: images ---

@(private)
parse_texture_extensions :: proc(p: ^Parser, extensions: json.Value, texture: ^Texture) -> bool {
    object, ok := as_object(extensions)
    if !ok {
        return true
    }
    if payload, present := member_object(object, EXT_TEXTURE_WEBP); present {
        index, found := member_int(payload, "source")
        if !found {
            return false
        }
        if !fixup_index_single(Image, rawptr(&texture.webp_source), index, p.document.images) {
            return false
        }
        texture.has_webp = true
    }
    if payload, present := member_object(object, EXT_TEXTURE_BASISU); present {
        index, found := member_int(payload, "source")
        if !found {
            return false
        }
        if !fixup_index_single(Image, rawptr(&texture.basisu_source), index, p.document.images) {
            return false
        }
        texture.has_basisu = true
    }
    return true
}

// ------------------------------------------------------------- buffer view ---

@(private)
parse_meshopt_compression :: proc(p: ^Parser, extensions: json.Value, view: ^Buffer_View) -> bool {
    object, object_ok := as_object(extensions)
    if !object_ok {
        return true
    }
    payload, payload_ok := member_object(object, EXT_MESHOPT_COMPRESSION)
    if !payload_ok {
        payload, payload_ok = member_object(object, KHR_MESHOPT_COMPRESSION)
        if !payload_ok {
            return true
        }
    }

    compression := Meshopt_Compression {
        mode = Meshopt_Compression_Mode.Attributes,
        filter = Meshopt_Compression_Filter.None,
    }
    if value, ok := member_string(payload, "mode"); ok {
        parsed := meshopt_mode_from_string(value)
        if parsed == nil {
            return false
        }
        compression.mode = parsed.?
    }
    if value, ok := member_string(payload, "filter"); ok {
        parsed := meshopt_filter_from_string(value)
        if parsed == nil {
            return false
        }
        compression.filter = parsed.?
    }
    if value, ok := member_int(payload, "byteOffset"); ok {
        compression.offset = value
    }
    if value, ok := member_int(payload, "byteLength"); ok {
        compression.size = value
    }
    if value, ok := member_int(payload, "byteStride"); ok {
        compression.stride = value
    }
    if value, ok := member_int(payload, "count"); ok {
        compression.count = value
    }
    if compression.offset < 0 ||
       compression.size < 0 ||
       compression.stride < 0 ||
       compression.count < 0 {
        return false
    }

    index, found := member_int(payload, "buffer")
    if !found {
        return false
    }
    if !fixup_index_single(Buffer, rawptr(&compression.buffer), index, p.document.buffers) {
        return false
    }

    view.has_meshopt = true
    view.meshopt = compression
    return true
}

// -------------------------------------------------------- primitive: draco ---

@(private)
parse_primitive_extensions :: proc(
    p: ^Parser,
    extensions: json.Value,
    primitive: ^Primitive,
) -> bool {
    object, ok := as_object(extensions)
    if !ok {
        return true
    }

    if payload, present := member_object(object, KHR_DRACO_MESH_COMPRESSION); present {
        index, found := member_int(payload, "bufferView")
        if !found {
            return false
        }
        draco := Draco_Mesh_Compression{}
        if !fixup_index_single(
            Buffer_View,
            rawptr(&draco.buffer_view),
            index,
            p.document.buffer_views,
        ) {
            return false
        }
        // The Draco extension maps semantic names to Draco attribute ids with
        // the same object shape as a primitive's own attributes.  Those ids
        // are not glTF accessor indices, so they are kept in Index.
        attributes_object, has_attributes := member_object(payload, "attributes")
        if !has_attributes {
            return false
        }
        attributes, parsed := parse_attribute_object(p, attributes_object, false)
        if !parsed {
            return false
        }
        draco.attributes = attributes
        primitive.draco = draco
        primitive.has_draco = true
    }

    if payload, present := member_object(object, KHR_MATERIALS_VARIANTS); present {
        mappings_array, has_mappings := member_array(payload, "mappings")
        if !has_mappings {
            return false
        }
        total := 0
        for mapping in mappings_array {
            variants, _ := mapping.(json.Object)
            variant_count, has_variants := member_int_array_len(variants, "variants")
            if !has_variants {
                return false
            }
            total += variant_count
        }
        mappings := make([]Material_Mapping, total, p.allocator)
        out := 0
        for mapping in mappings_array {
            mapping_object, _ := mapping.(json.Object)
            material_index, has_material := member_int(mapping_object, "material")
            list, has_variants := member_array(mapping_object, "variants")
            if !has_variants {
                return false
            }
            for variant_value in list {
                variant_integer, is_integer := variant_value.(json.Integer)
                if !is_integer {
                    return false
                }
                variant, fits_int := json_int_to_int(variant_integer)
                if !fits_int {
                    return false
                }
                mappings[out] = Material_Mapping {
                    variant = variant,
                    material = nil,
                }
                if extras, has_extras := member(mapping_object, "extras"); has_extras {
                    mappings[out].extras = make_extras(extras, p.allocator)
                }
                if has_material {
                    if !fixup_index_single(
                        Material,
                        rawptr(&mappings[out].material),
                        material_index,
                        p.document.materials,
                    ) {
                        return false
                    }
                }
                out += 1
            }
        }
        primitive.mappings = mappings
    }

    return true
}

// ---------------------------------------------------------------- materials ---

// parse_material_extensions fills the typed extension blocks of a `Material`
// from its `extensions` member.
@(private)
parse_material_extensions :: proc(
    p: ^Parser,
    extensions: json.Value,
    material: ^Material,
) -> bool {
    object, object_ok := as_object(extensions)
    if !object_ok {
        return true
    }

    // KHR_materials_unlit is a bare marker: it has no payload members.
    if _, ok := member(object, KHR_MATERIALS_UNLIT); ok {
        material.unlit = true
    }

    if payload, payload_ok := member_object(object, KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS);
       payload_ok {
        glossiness := Pbr_Specular_Glossiness {
            diffuse_factor = {1, 1, 1, 1},
            specular_factor = {1, 1, 1},
            glossiness_factor = 1,
        }
        if !read_float_array(payload, "diffuseFactor", glossiness.diffuse_factor[:]) ||
           !read_float_array(payload, "specularFactor", glossiness.specular_factor[:]) ||
           !read_float_ext(payload, "glossinessFactor", &glossiness.glossiness_factor) {
            return false
        }
        if value, ok := member_object(payload, "diffuseTexture"); ok {
            view, view_ok := parse_texture_info_object(p, value)
            if !view_ok {
                return false
            }
            glossiness.diffuse_texture = view
        }
        if value, ok := member_object(payload, "specularGlossinessTexture"); ok {
            view, view_ok := parse_texture_info_object(p, value)
            if !view_ok {
                return false
            }
            glossiness.specular_glossiness_texture = view
        }
        material.specular_glossiness = glossiness
        material.has_specular_glossiness = true
    }

    if payload, present := member_object(object, KHR_MATERIALS_CLEARCOAT); present {
        clearcoat := material.clearcoat
        if !read_float_ext(payload, "clearcoatFactor", &clearcoat.clearcoat_factor) ||
           !read_float_ext(
                   payload,
                   "clearcoatRoughnessFactor",
                   &clearcoat.clearcoat_roughness_factor,
               ) {
            return false
        }
        if !parse_extension_texture(p, payload, "clearcoatTexture", &clearcoat.clearcoat_texture) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "clearcoatRoughnessTexture",
            &clearcoat.clearcoat_roughness_texture,
        ) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "clearcoatNormalTexture",
            &clearcoat.clearcoat_normal_texture,
        ) {
            return false
        }
        material.clearcoat = clearcoat
        material.has_clearcoat = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_TRANSMISSION); ok {
        transmission := material.transmission
        if !read_float_ext(payload, "transmissionFactor", &transmission.transmission_factor) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "transmissionTexture",
            &transmission.transmission_texture,
        ) {
            return false
        }
        material.transmission = transmission
        material.has_transmission = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_VOLUME); ok {
        volume := Volume {
            attenuation_distance = DEFAULT_ATTENUATION_DISTANCE,
            attenuation_color = {1, 1, 1},
        }
        if !read_float_ext(payload, "thicknessFactor", &volume.thickness_factor) ||
           !read_float_ext(payload, "attenuationDistance", &volume.attenuation_distance) ||
           !read_float_array(payload, "attenuationColor", volume.attenuation_color[:]) {
            return false
        }
        if !parse_extension_texture(p, payload, "thicknessTexture", &volume.thickness_texture) {
            return false
        }
        material.volume = volume
        material.has_volume = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_IOR); ok {
        ior := IOR {
            ior = 1.5,
        }
        if !read_float_ext(payload, "ior", &ior.ior) {
            return false
        }
        material.ior = ior
        material.has_ior = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_SPECULAR); ok {
        specular := Specular {
            specular_factor = 1,
            specular_color_factor = {1, 1, 1},
        }
        if !read_float_ext(payload, "specularFactor", &specular.specular_factor) ||
           !read_float_array(payload, "specularColorFactor", specular.specular_color_factor[:]) {
            return false
        }
        if !parse_extension_texture(p, payload, "specularTexture", &specular.specular_texture) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "specularColorTexture",
            &specular.specular_color_texture,
        ) {
            return false
        }
        material.specular = specular
        material.has_specular = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_SHEEN); ok {
        sheen := material.sheen
        if !read_float_array(payload, "sheenColorFactor", sheen.sheen_color_factor[:]) ||
           !read_float_ext(payload, "sheenRoughnessFactor", &sheen.sheen_roughness_factor) {
            return false
        }
        if !parse_extension_texture(p, payload, "sheenColorTexture", &sheen.sheen_color_texture) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "sheenRoughnessTexture",
            &sheen.sheen_roughness_texture,
        ) {
            return false
        }
        material.sheen = sheen
        material.has_sheen = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_EMISSIVE_STRENGTH); ok {
        strength := Emissive_Strength {
            strength = 1,
        }
        if !read_float_ext(payload, "emissiveStrength", &strength.strength) {
            return false
        }
        material.emissive_strength = strength
        material.has_emissive_strength = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_IRIDESCENCE); ok {
        iridescence := Iridescence {
            ior = 1.3,
            thickness_min = DEFAULT_IRIDESCENCE_THICKNESS_MIN,
            thickness_max = DEFAULT_IRIDESCENCE_THICKNESS_MAX,
        }
        if !read_float_ext(payload, "iridescenceFactor", &iridescence.iridescence_factor) ||
           !read_float_ext(payload, "iridescenceIor", &iridescence.ior) ||
           !read_float_ext(payload, "iridescenceThicknessMinimum", &iridescence.thickness_min) ||
           !read_float_ext(payload, "iridescenceThicknessMaximum", &iridescence.thickness_max) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "iridescenceTexture",
            &iridescence.iridescence_texture,
        ) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "iridescenceThicknessTexture",
            &iridescence.thickness_texture,
        ) {
            return false
        }
        material.iridescence = iridescence
        material.has_iridescence = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_DIFFUSE_TRANSMISSION); ok {
        transmission := Diffuse_Transmission {
            color_factor = {1, 1, 1},
        }
        if !read_float_ext(
               payload,
               "diffuseTransmissionFactor",
               &transmission.diffuse_transmission_factor,
           ) ||
           !read_float_array(
                   payload,
                   "diffuseTransmissionColorFactor",
                   transmission.color_factor[:],
               ) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "diffuseTransmissionTexture",
            &transmission.diffuse_transmission_texture,
        ) {
            return false
        }
        if !parse_extension_texture(
            p,
            payload,
            "diffuseTransmissionColorTexture",
            &transmission.color_texture,
        ) {
            return false
        }
        material.diffuse_transmission = transmission
        material.has_diffuse_transmission = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_ANISOTROPY); ok {
        anisotropy := material.anisotropy
        if !read_float_ext(payload, "anisotropyStrength", &anisotropy.strength) ||
           !read_float_ext(payload, "anisotropyRotation", &anisotropy.rotation) {
            return false
        }
        if !parse_extension_texture(p, payload, "anisotropyTexture", &anisotropy.texture) {
            return false
        }
        material.anisotropy = anisotropy
        material.has_anisotropy = true
    }

    if payload, ok := member_object(object, KHR_MATERIALS_DISPERSION); ok {
        dispersion := Dispersion {
            dispersion = 1,
        }
        if !read_float_ext(payload, "dispersion", &dispersion.dispersion) {
            return false
        }
        material.dispersion = dispersion
        material.has_dispersion = true
    }

    return true
}

// parse_extension_texture reads an optional `textureInfo`-shaped member of an
// extension payload into `dest`.  An absent member leaves `dest` alone.
@(private)
parse_extension_texture :: proc(
    p: ^Parser,
    payload: json.Object,
    name: string,
    dest: ^Texture_View,
) -> bool {
    value, present := member_object(payload, name)
    if !present {
        return true
    }
    view, ok := parse_texture_info_object(p, value)
    if !ok {
        return false
    }
    dest^ = view
    return true
}

// ------------------------------------------------------- materials: variants ---

@(private)
count_variants :: proc(extensions: json.Value) -> int {
    payload, ok := extension_payload(extensions, KHR_MATERIALS_VARIANTS)
    if !ok {
        return 0
    }
    variants, present := member_array(payload, "variants")
    if !present {
        return 0
    }
    return len(variants)
}

@(private)
convert_variants :: proc(p: ^Parser, extensions: json.Value, out: []Material_Variant) -> Error {
    if len(out) == 0 {
        return .None
    }
    payload, payload_ok := extension_payload(extensions, KHR_MATERIALS_VARIANTS)
    if !payload_ok {
        return .Invalid_Gltf
    }
    variants, variants_ok := member_array(payload, "variants")
    if !variants_ok || len(variants) != len(out) {
        return .Invalid_Gltf
    }
    for variant, i in variants {
        object, _ := variant.(json.Object)
        name, ok := member_string(object, "name")
        if !ok {
            return .Invalid_Gltf
        }
        out[i].name = name
        if extras, has_extras := member(object, "extras"); has_extras {
            out[i].extras = make_extras(extras, p.allocator)
        }
    }
    return .None
}
