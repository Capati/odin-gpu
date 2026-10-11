package gltf

// Core
import "core:strings"

import la "core:math/linalg"

// Turns the streaming-reader schema mirror into the public graph.
//
// Every top-level collection is allocated at its final size *before* any cross
// reference is resolved, so that the `^T` pointers stored in the graph stay valid
// for the lifetime of the document.
@(private)
convert_root :: proc(p: ^Parser, root: ^Raw_Root) -> Error {
    document := p.document

    if err := check_asset_version(root.asset.version); err != .None {
        return err
    }

    document.asset = Asset {
        copyright   = root.asset.copyright,
        generator   = root.asset.generator,
        version     = root.asset.version,
        min_version = root.asset.min_version,
        extras      = make_extras(root.asset.extras, p.allocator),
        extensions  = parse_extensions(root.asset.extensions, p.allocator),
    }
    document.extensions_used = root.extensions_used
    document.extensions_required = root.extensions_required
    sort_strings_small(document.extensions_used)
    sort_strings_small(document.extensions_required)
    document.extras = make_extras(root.extras, p.allocator)
    document.extensions = parse_extensions(root.extensions, p.allocator)

    document.buffers = alloc_slice(Buffer, len(root.buffers), p.allocator)
    document.buffer_views = alloc_slice(Buffer_View, len(root.buffer_views), p.allocator)
    document.accessors = alloc_slice(Accessor, len(root.accessors), p.allocator)
    document.images = alloc_slice(Image, len(root.images), p.allocator)
    document.samplers = alloc_slice(Sampler, len(root.samplers), p.allocator)
    document.textures = alloc_slice(Texture, len(root.textures), p.allocator)
    document.materials = alloc_slice(Material, len(root.materials), p.allocator)
    document.meshes = alloc_slice(Mesh, len(root.meshes), p.allocator)
    document.skins = alloc_slice(Skin, len(root.skins), p.allocator)
    document.cameras = alloc_slice(Camera, len(root.cameras), p.allocator)
    document.nodes = alloc_slice(Node, len(root.nodes), p.allocator)
    document.scenes = alloc_slice(Scene, len(root.scenes), p.allocator)
    document.animations = alloc_slice(Animation, len(root.animations), p.allocator)

    // Lights and variants live in extensions, so their sizes are only known
    // after scanning for them.
    document.lights = alloc_slice(Light, count_lights(root.extensions), p.allocator)
    document.variants = alloc_slice(Material_Variant, count_variants(root.extensions), p.allocator)

    convert_buffers(p, root.buffers) or_return
    convert_buffer_views(p, root.buffer_views) or_return
    convert_accessors(p, root.accessors) or_return
    convert_images(p, root.images) or_return
    convert_samplers(p, root.samplers) or_return
    convert_textures(p, root.textures) or_return
    convert_materials(p, root.materials) or_return
    convert_meshes(p, root.meshes) or_return
    convert_skins(p, root.skins) or_return
    convert_cameras(p, root.cameras) or_return
    convert_lights(p, root.extensions, document.lights) or_return
    convert_nodes(p, root.nodes) or_return
    convert_scenes(p, root.scenes) or_return
    convert_animations(p, root.animations) or_return

    if root.scene != nil {
        if !fixup_optional(Scene, rawptr(&document.scene), root.scene.?, document.scenes) {
            return .Invalid_Gltf
        }
    }

    // Link children to their parents so that node_transform_world works without
    // a separate walk.
    for &node in document.nodes {
        for &child in node.children {
            child.parent = &node
        }
    }

    return convert_variants(p, root.extensions, document.variants)
}

// -----------------------------------------------------------------------------
// buffers
// -----------------------------------------------------------------------------

@(private)
convert_buffers :: proc(p: ^Parser, raw: []Raw_Buffer) -> Error {
    for &element, i in raw {
        if element.byte_length < 0 {
            return .Invalid_Gltf
        }
        p.document.buffers[i] = Buffer {
            name       = element.name,
            size       = element.byte_length,
            uri        = element.uri,
            extras     = make_extras(element.extras, p.allocator),
            extensions = parse_extensions(element.extensions, p.allocator),
        }
    }
    return .None
}

@(private)
convert_buffer_views :: proc(p: ^Parser, raw: []Raw_Buffer_View) -> Error {
    document := p.document
    for &element, i in raw {
        if element.byte_length < 0 || element.byte_offset < 0 {
            return .Invalid_Gltf
        }
        // byteStride, when present, must be a multiple of 4 in [4, 252].
        if element.byte_stride < 0 {
            return .Invalid_Gltf
        }
        if element.byte_stride != 0 &&
           (element.byte_stride % 4 != 0 || element.byte_stride > 252) {
            return .Invalid_Gltf
        }
        target := buffer_view_target_from_int(element.target)
        if target == nil {
            return .Invalid_Gltf
        }

        view := &document.buffer_views[i]
        view.name = element.name
        view.offset = element.byte_offset
        view.size = element.byte_length
        view.stride = element.byte_stride
        view.target = target.?
        view.extras = make_extras(element.extras, p.allocator)
        view.extensions = parse_extensions(element.extensions, p.allocator, KNOWN_EXTENSIONS)
        if !parse_meshopt_compression(p, element.extensions, view) {
            return .Invalid_Gltf
        }

        if !fixup_index_single(Buffer, rawptr(&view.buffer), element.buffer, document.buffers) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// accessors
// -----------------------------------------------------------------------------

@(private)
convert_accessors :: proc(p: ^Parser, raw: []Raw_Accessor) -> Error {
    document := p.document
    for &element, i in raw {
        if element.count < 0 || element.byte_offset < 0 {
            return .Invalid_Gltf
        }
        component_type := component_type_from_int(element.component_type)
        if component_type == nil {
            return .Invalid_Gltf
        }
        type := element_type_from_string(element.type)
        if type == nil {
            return .Invalid_Gltf
        }
        size := element_size(type.?, component_type.?)
        if size == 0 {
            return .Unsupported_Accessor_Layout
        }

        accessor := &document.accessors[i]
        accessor.name = element.name
        accessor.component_type = component_type.?
        accessor.normalized = element.normalized
        accessor.type = type.?
        accessor.offset = element.byte_offset
        accessor.count = element.count
        accessor.extras = make_extras(element.extras, p.allocator)
        accessor.extensions = parse_extensions(element.extensions, p.allocator)

        if !fixup_optional(
            Buffer_View,
            rawptr(&accessor.buffer_view),
            element.buffer_view,
            document.buffer_views,
        ) {
            return .Invalid_Gltf
        }

        // An accessor's stride is its buffer view's stride when it has one,
        // and the tightly packed element size otherwise.
        if accessor.buffer_view != nil {
            accessor.stride = accessor.buffer_view.stride
        }
        if accessor.stride == 0 {
            accessor.stride = size
        }

        // `min`/`max` must hold exactly one value per component.  Reading up
        // to 16 values while ignoring length mismatch would accept a docstring
        // that claims a MAT4's bounds for a VEC3; it is rejected here.
        components := num_components(accessor.type)
        if element.min != nil {
            if len(element.min) != components {return .Invalid_Gltf}
            copy(accessor.min[:components], element.min)
            accessor.has_min = true
        }
        if element.max != nil {
            if len(element.max) != components {return .Invalid_Gltf}
            copy(accessor.max[:components], element.max)
            accessor.has_max = true
        }

        if element.sparse != nil {
            sparse := element.sparse.?
            if sparse.count < 0 ||
               sparse.indices.byte_offset < 0 ||
               sparse.values.byte_offset < 0 {
                return .Invalid_Gltf
            }
            indices_type := component_type_from_int(sparse.indices.component_type)
            if indices_type == nil {
                return .Invalid_Gltf
            }
            // The schema only allows unsigned index components in a sparse
            // accessor.
            switch indices_type {
            case .Unsigned_Byte, .Unsigned_Short, .Unsigned_Int:
            case:
                return .Invalid_Gltf
            }

            accessor.has_sparse = true
            accessor.sparse.count = sparse.count
            accessor.sparse.indices_byte_offset = sparse.indices.byte_offset
            accessor.sparse.indices_component_type = indices_type.?
            accessor.sparse.values_byte_offset = sparse.values.byte_offset
            if !fixup_index_single(
                Buffer_View,
                rawptr(&accessor.sparse.indices_buffer_view),
                sparse.indices.buffer_view,
                document.buffer_views,
            ) {
                return .Invalid_Gltf
            }
            if !fixup_index_single(
                Buffer_View,
                rawptr(&accessor.sparse.values_buffer_view),
                sparse.values.buffer_view,
                document.buffer_views,
            ) {
                return .Invalid_Gltf
            }
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// images
// -----------------------------------------------------------------------------

@(private)
convert_images :: proc(p: ^Parser, raw: []Raw_Image) -> Error {
    document := p.document
    for &element, i in raw {
        // The schema allows exactly one of `uri` and `bufferView`.
        if (element.uri != "") == (element.buffer_view != nil) {
            return .Invalid_Gltf
        }
        image := &document.images[i]
        image.name = element.name
        image.uri = element.uri
        image.mime_type = element.mime_type
        image.extras = make_extras(element.extras, p.allocator)
        image.extensions = parse_extensions(element.extensions, p.allocator)
        if !fixup_optional(
            Buffer_View,
            rawptr(&image.buffer_view),
            element.buffer_view,
            document.buffer_views,
        ) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// samplers
// -----------------------------------------------------------------------------

@(private)
convert_samplers :: proc(p: ^Parser, raw: []Raw_Sampler) -> Error {
    for &element, i in raw {
        mag_filter := filter_type_from_int(element.mag_filter)
        if mag_filter == nil {
            return .Invalid_Gltf
        }
        min_filter := filter_type_from_int(element.min_filter)
        if min_filter == nil {
            return .Invalid_Gltf
        }
        wrap_s := wrap_mode_from_int(element.wrap_s)
        if wrap_s == nil {
            return .Invalid_Gltf
        }
        wrap_t := wrap_mode_from_int(element.wrap_t)
        if wrap_t == nil {
            return .Invalid_Gltf
        }
        p.document.samplers[i] = Sampler {
            name       = element.name,
            mag_filter = mag_filter.?,
            min_filter = min_filter.?,
            wrap_s     = wrap_s.?,
            wrap_t     = wrap_t.?,
            extras     = make_extras(element.extras, p.allocator),
            extensions = parse_extensions(element.extensions, p.allocator),
        }
    }
    return .None
}


// -----------------------------------------------------------------------------
// textures
// -----------------------------------------------------------------------------

@(private)
convert_textures :: proc(p: ^Parser, raw: []Raw_Texture) -> Error {
    document := p.document
    for &element, i in raw {
        texture := &document.textures[i]
        texture.name = element.name
        texture.extras = make_extras(element.extras, p.allocator)
        texture.extensions = parse_extensions(element.extensions, p.allocator, KNOWN_EXTENSIONS)
        if !fixup_optional(Sampler, rawptr(&texture.sampler), element.sampler, document.samplers) {
            return .Invalid_Gltf
        }
        if !fixup_optional(Image, rawptr(&texture.source), element.source, document.images) {
            return .Invalid_Gltf
        }
        if !parse_texture_extensions(p, element.extensions, texture) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// materials
// -----------------------------------------------------------------------------

@(private)
convert_materials :: proc(p: ^Parser, raw: []Raw_Material) -> Error {
    document := p.document
    for &element, i in raw {
        alpha_mode := alpha_mode_from_string(element.alpha_mode)
        if alpha_mode == nil {
            return .Invalid_Gltf
        }
        cutoff := f32(0.5)
        if element.alpha_cutoff != nil {
            value := element.alpha_cutoff.?
            if !is_finite(value) {
                return .Invalid_Gltf
            }
            cutoff = value
        }

        material := &document.materials[i]
        material.name = element.name
        material.alpha_mode = alpha_mode.?
        material.alpha_cutoff = cutoff
        material.double_sided = element.double_sided
        material.extras = make_extras(element.extras, p.allocator)
        material.extensions = parse_extensions(element.extensions, p.allocator, KNOWN_EXTENSIONS)

        // The schema defaults the whole metallic-roughness block, whether or
        // not the `pbrMetallicRoughness` object is present.
        material.pbr = Pbr_Metallic_Roughness {
            base_color_factor = {1, 1, 1, 1},
            metallic_factor   = 1,
            roughness_factor  = 1,
        }
        if element.pbr != nil {
            pbr := element.pbr.?
            if pbr.base_color_factor != nil {
                material.pbr.base_color_factor = pbr.base_color_factor.?
            }
            if pbr.metallic_factor != nil {
                material.pbr.metallic_factor = pbr.metallic_factor.?
            }
            if pbr.roughness_factor != nil {
                material.pbr.roughness_factor = pbr.roughness_factor.?
            }
            if pbr.base_color_texture != nil {
                material.pbr.base_color_texture = parse_texture_info(p, pbr.base_color_texture.?)
            }
            if pbr.metallic_roughness_texture != nil {
                material.pbr.metallic_roughness_texture = parse_texture_info(
                    p,
                    pbr.metallic_roughness_texture.?,
                )
            }
        }

        if element.normal_texture != nil {
            material.normal_texture = parse_texture_info(p, element.normal_texture.?)
        }
        if element.occlusion_texture != nil {
            material.occlusion_texture = parse_texture_info(p, element.occlusion_texture.?, true)
        }
        if element.emissive_texture != nil {
            material.emissive_texture = parse_texture_info(p, element.emissive_texture.?)
        }
        if element.emissive_factor != nil {
            material.emissive_factor = element.emissive_factor.?
        }

        if !parse_material_extensions(p, element.extensions, material) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// meshes
// -----------------------------------------------------------------------------

@(private)
convert_meshes :: proc(p: ^Parser, raw: []Raw_Mesh) -> Error {
    document := p.document
    for &element, i in raw {
        mesh := &document.meshes[i]
        mesh.name = element.name
        mesh.weights = element.weights
        mesh.extras = make_extras(element.extras, p.allocator)
        mesh.extensions = parse_extensions(element.extensions, p.allocator)

        // targetNames was a glTF 1.0 member; in 2.0 it survives only as an
        // extras convention, so that is where it is looked for.
        if extras_object, estras_ok := as_object(element.extras); estras_ok {
            if names, ok := member_string_array(extras_object, "targetNames", p.allocator); ok {
                mesh.target_names = names
            }
        }

        if err := convert_primitives(p, element.primitives, &mesh.primitives); err != .None {
            return err
        }
    }
    return .None
}

// Allocates and fills a mesh's primitive slice.
//
// The morph target names are a deprecated glTF 1.0 member that shares the
// `extras.targetNames` slot in 2.0, so they are read from there.
@(private)
convert_primitives :: proc(p: ^Parser, raw: []Raw_Primitive, out: ^[]Primitive) -> Error {
    primitives := alloc_slice(Primitive, len(raw), p.allocator)
    out^ = primitives

    for &element, i in raw {
        primitive := &primitives[i]
        // The schema default for primitive.mode is TRIANGLES.
        if element.mode == nil {
            primitive.mode = .Triangles
        } else {
            mode := primitive_mode_from_int(element.mode.?)
            if mode == nil {
                return .Invalid_Gltf
            }
            primitive.mode = mode.?
        }
        primitive.extras = make_extras(element.extras, p.allocator)
        primitive.extensions = parse_extensions(element.extensions, p.allocator, KNOWN_EXTENSIONS)

        if !fixup_optional(
            Accessor,
            rawptr(&primitive.indices),
            element.indices,
            p.document.accessors,
        ) {
            return .Invalid_Gltf
        }
        if !fixup_optional(
            Material,
            rawptr(&primitive.material),
            element.material,
            p.document.materials,
        ) {
            return .Invalid_Gltf
        }

        attributes, attributes_ok := parse_attribute_map(p, element.attributes)
        if !attributes_ok {
            return .Invalid_Gltf
        }
        primitive.attributes = attributes

        targets := alloc_slice(Morph_Target, len(element.targets), p.allocator)
        primitive.targets = targets
        for target, j in element.targets {
            target_attributes, ok := parse_attribute_map(p, target)
            if !ok {
                return .Invalid_Gltf
            }
            targets[j].attributes = target_attributes
        }

        if !parse_primitive_extensions(p, element.extensions, primitive) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// Converts a `{SEMANTIC: accessorIndex}` object into a deterministic, name-sorted
// `Attribute` slice with its accessors resolved.
//
// The map is sorted by name because `core:encoding/json` iterates object keys in
// map order, which would otherwise make attribute order non-deterministic.
@(private)
parse_attribute_map :: proc(p: ^Parser, raw: []Raw_Attribute) -> ([]Attribute, bool) {
    if len(raw) == 0 {return nil, true}

    // Insertion sort: primitives carry 2-5 attributes, where quick_sort's
    // recursion and indirect comparator calls dominate.
    for i in 1 ..< len(raw) {
        tmp := raw[i]
        j := i - 1
        for j >= 0 && strings.compare(raw[j].name, tmp.name) > 0 {
            raw[j + 1] = raw[j]
            j -= 1
        }
        raw[j + 1] = tmp
    }

    accessors := p.document.accessors
    attributes := make([]Attribute, len(raw), p.allocator)
    for entry, i in raw {
        if i > 0 && raw[i - 1].name == entry.name {return nil, false}     // duplicate key
        if entry.index < 0 || entry.index >= len(accessors) {return nil, false}
        type, index := parse_attribute_type(entry.name)
        attributes[i] = Attribute{entry.name, type, index, &accessors[entry.index]}
    }
    return attributes, true
}

// Fills the accessor pointer embedded in each Attribute.  Those fields are not
// contiguous in memory, so a bulk fixup from `&attributes[0].data` would overwrite
// the rest of each Attribute after the first one.
@(private)
resolve_attribute_accessors :: proc(
    attributes: []Attribute,
    indices: []int,
    accessors: []Accessor,
) -> bool {
    if len(attributes) != len(indices) {
        return false
    }
    for i in 0 ..< len(attributes) {
        index := indices[i]
        if index < 0 || index >= len(accessors) {
            return false
        }
        attributes[i].data = &accessors[index]
    }
    return true
}

// -----------------------------------------------------------------------------
// skins
// -----------------------------------------------------------------------------

@(private)
convert_skins :: proc(p: ^Parser, raw: []Raw_Skin) -> Error {
    document := p.document
    for &element, i in raw {
        skin := &document.skins[i]
        skin.name = element.name
        skin.extras = make_extras(element.extras, p.allocator)
        skin.extensions = parse_extensions(element.extensions, p.allocator)

        joints := alloc_slice(^Node, len(element.joints), p.allocator)
        skin.joints = joints
        if !fixup_indices(Node, raw_data(joints), element.joints, document.nodes) {
            return .Invalid_Gltf
        }
        if !fixup_optional(Node, rawptr(&skin.skeleton), element.skeleton, document.nodes) {
            return .Invalid_Gltf
        }
        if !fixup_optional(
            Accessor,
            rawptr(&skin.inverse_bind_matrices),
            element.inverse_bind_matrices,
            document.accessors,
        ) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// cameras
// -----------------------------------------------------------------------------

@(private)
convert_cameras :: proc(p: ^Parser, raw: []Raw_Camera) -> Error {
    for &element, i in raw {
        type := camera_type_from_string(element.type)
        if type == nil {
            return .Invalid_Gltf
        }
        camera := &p.document.cameras[i]
        camera.name = element.name
        camera.type = type.?
        camera.extras = make_extras(element.extras, p.allocator)
        camera.extensions = parse_extensions(element.extensions, p.allocator)

        switch type.? {
        case .Perspective:
            if element.perspective == nil {
                return .Invalid_Gltf
            }
            perspective := element.perspective.?
            if perspective.yfov <= 0 || perspective.znear <= 0 {
                return .Invalid_Gltf
            }
            camera.perspective.yfov = perspective.yfov
            camera.perspective.znear = perspective.znear
            if perspective.aspect_ratio != nil {
                camera.perspective.has_aspect_ratio = true
                camera.perspective.aspect_ratio = perspective.aspect_ratio.?
            }
            if perspective.zfar != nil {
                camera.perspective.has_zfar = true
                camera.perspective.zfar = perspective.zfar.?
            }
        case .Orthographic:
            if element.orthographic == nil {
                return .Invalid_Gltf
            }
            orthographic := element.orthographic.?
            camera.orthographic = Camera_Orthographic {
                xmag  = orthographic.xmag,
                ymag  = orthographic.ymag,
                zfar  = orthographic.zfar,
                znear = orthographic.znear,
            }
        case .Invalid:
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// nodes
// -----------------------------------------------------------------------------

@(private)
convert_nodes :: proc(p: ^Parser, raw: []Raw_Node) -> Error {
    document := p.document
    for &element, i in raw {
        node := &document.nodes[i]
        node.name = element.name
        // Identity defaults are useful to callers inspecting the public node,
        // not just to node_transform_local.
        node.matrix_ = la.MATRIX4F32_IDENTITY
        node.rotation = {0, 0, 0, 1}
        node.scale = {1, 1, 1}
        node.weights = element.weights
        node.extras = make_extras(element.extras, p.allocator)
        node.extensions = parse_extensions(element.extensions, p.allocator, KNOWN_EXTENSIONS)

        if element.matrix_ != nil {
            value := element.matrix_.?
            node.has_matrix = true
            node.matrix_ = node_matrix_from_gltf(value)
        }
        if element.translation != nil {
            translation := element.translation.?
            node.has_translation = true
            node.translation = translation
        }
        if element.rotation != nil {
            rotation := element.rotation.?
            node.has_rotation = true
            node.rotation = rotation
        }
        if element.scale != nil {
            scale := element.scale.?
            node.has_scale = true
            node.scale = scale
        }

        children := alloc_slice(^Node, len(element.children), p.allocator)
        node.children = children
        if !fixup_indices(Node, raw_data(children), element.children, document.nodes) {
            return .Invalid_Gltf
        }
        if !fixup_optional(Mesh, rawptr(&node.mesh), element.mesh, document.meshes) {
            return .Invalid_Gltf
        }
        if !fixup_optional(Camera, rawptr(&node.camera), element.camera, document.cameras) {
            return .Invalid_Gltf
        }
        if !fixup_optional(Skin, rawptr(&node.skin), element.skin, document.skins) {
            return .Invalid_Gltf
        }

        if !parse_node_extensions(p, element.extensions, node, document.lights) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// scenes
// -----------------------------------------------------------------------------

@(private)
convert_scenes :: proc(p: ^Parser, raw: []Raw_Scene) -> Error {
    document := p.document
    for &element, i in raw {
        scene := &document.scenes[i]
        scene.name = element.name
        scene.extras = make_extras(element.extras, p.allocator)
        scene.extensions = parse_extensions(element.extensions, p.allocator)

        nodes := alloc_slice(^Node, len(element.nodes), p.allocator)
        scene.nodes = nodes
        if !fixup_indices(Node, raw_data(nodes), element.nodes, document.nodes) {
            return .Invalid_Gltf
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// animations
// -----------------------------------------------------------------------------

@(private)
convert_animations :: proc(p: ^Parser, raw: []Raw_Animation) -> Error {
    document := p.document
    for &element, i in raw {
        animation := &document.animations[i]
        animation.name = element.name
        animation.extras = make_extras(element.extras, p.allocator)
        animation.extensions = parse_extensions(element.extensions, p.allocator)

        samplers := alloc_slice(Animation_Sampler, len(element.samplers), p.allocator)
        animation.samplers = samplers
        for &sampler_element, j in element.samplers {
            interpolation := interpolation_from_string(sampler_element.interpolation)
            if interpolation == nil {
                return .Invalid_Gltf
            }
            samplers[j].interpolation = interpolation.?
            samplers[j].extras = make_extras(sampler_element.extras, p.allocator)
            samplers[j].extensions = parse_extensions(sampler_element.extensions, p.allocator)
            if !fixup_index_single(
                Accessor,
                rawptr(&samplers[j].input),
                sampler_element.input,
                document.accessors,
            ) {
                return .Invalid_Gltf
            }
            if !fixup_index_single(
                Accessor,
                rawptr(&samplers[j].output),
                sampler_element.output,
                document.accessors,
            ) {
                return .Invalid_Gltf
            }
        }

        channels := alloc_slice(Animation_Channel, len(element.channels), p.allocator)
        animation.channels = channels
        for &channel_element, j in element.channels {
            path := animation_path_from_string(channel_element.target.path)
            if path == nil {
                return .Invalid_Gltf
            }
            channels[j].target_path = path.?
            channels[j].extras = make_extras(channel_element.extras, p.allocator)
            channels[j].extensions = parse_extensions(channel_element.extensions, p.allocator)
            channels[j].target_extensions = parse_extensions(
                channel_element.target.extensions,
                p.allocator,
            )
            if !fixup_index_single(
                Animation_Sampler,
                rawptr(&channels[j].sampler),
                channel_element.sampler,
                samplers,
            ) {
                return .Invalid_Gltf
            }
            if channel_element.target.node != nil {
                node_index := channel_element.target.node.?
                if !fixup_index_single(
                    Node,
                    rawptr(&channels[j].target_node),
                    node_index,
                    document.nodes,
                ) {
                    return .Invalid_Gltf
                }
            }
        }
    }
    return .None
}

// -----------------------------------------------------------------------------
// textures
// -----------------------------------------------------------------------------

// Converts a `textureInfo` object, applying its schema defaults: `texCoord` is 0
// and `scale` is 1.
@(private)
parse_texture_info :: proc(
    p: ^Parser,
    raw: Maybe(Raw_Texture_Info),
    is_occlusion := false,
) -> Texture_View {
    empty := Texture_View {
        scale = 1,
    }
    info, present := raw.?
    if !present || info.index < 0 {
        return empty
    }

    tex_coord := info.tex_coord
    if tex_coord < 0 {
        tex_coord = 0
    }
    view := Texture_View {
        tex_coord = tex_coord,
        scale = 1,
        transform = Texture_Transform{scale = {1, 1}, tex_coord = tex_coord},
    }
    if is_occlusion {
        if info.strength != nil {
            view.scale = info.strength.?
        }
    } else if info.scale != nil {
        view.scale = info.scale.?
    }
    if !fixup_index_single(Texture, rawptr(&view.texture), info.index, p.document.textures) {
        return empty
    }
    if !parse_texture_transform(p, info.extensions, &view.transform) {
        return empty
    }
    return view
}
