package gltf

// Checks a parsed document for the inconsistencies the schema forbids but the
// parser cannot catch on its own, and returns the first one it finds.
//
// Parsing resolves every index reference, so a document that comes out of `parse`
// has all of its pointers set. What is left are the constraints that involve two
// members at once: a bufferView that runs past the end of its buffer, an
// accessor's stride that is too small for its element type, a primitive whose
// attributes disagree about how many vertices they have, a scene that lists a node
// which somebody else already claimed as a child.
//
// `validate` must be called after `load_buffers` for the checks that read actual
// index data; the structural ones hold either way.
validate :: proc(document: ^Document) -> Maybe(Error) {
    if document == nil {
        return .Invalid_Argument
    }

    // Re-derive the parent links so that a caller who validated a document
    // straight out of `parse` still gets a usable `Node.parent` and the tree
    // checks below have something to look at.
    link_parents(document)

    validate_accessors(document) or_return
    validate_buffer_views(document) or_return
    validate_meshes(document) or_return
    validate_nodes(document) or_return
    validate_scenes(document) or_return
    validate_skins(document) or_return
    validate_animations(document) or_return
    validate_variants(document) or_return

    return nil
}

// Checks each accessor's element layout, its extent inside its bufferView, and its
// sparse overlay.
@(private)
validate_accessors :: proc(document: ^Document) -> Maybe(Error) {
    for &accessor in document.accessors {
        if accessor.component_type == .Invalid || accessor.type == .Invalid {
            return .Invalid_Gltf
        }
        element_size := element_size(accessor.type, accessor.component_type)
        if element_size == 0 {
            return .Unsupported_Accessor_Layout
        }
        // Accessor.count has a minimum of 1 in glTF 2.0.
        if accessor.count <= 0 || accessor.offset < 0 {
            return .Invalid_Gltf
        }
        // A stride below the element size would make consecutive elements
        // overlap. A stride above it is legal and is how the schema expresses
        // interleaved vertex attributes.
        if accessor.stride < element_size {
            return .Invalid_Gltf
        }
        if accessor.has_min && accessor.has_max {
            for component in 0 ..< num_components(accessor.type) {
                if accessor.min[component] > accessor.max[component] {
                    return .Invalid_Gltf
                }
            }
        }

        view := accessor.buffer_view
        if view != nil &&
           !strided_range_fits(
                   view.size,
                   accessor.offset,
                   accessor.stride,
                   accessor.count,
                   element_data_size(accessor.type, accessor.component_type),
               ) {
            return .Invalid_Gltf
        }

        if !accessor.has_sparse {
            continue
        }
        sparse := &accessor.sparse
        if sparse.count <= 0 ||
           sparse.count > accessor.count ||
           sparse.indices_byte_offset < 0 ||
           sparse.values_byte_offset < 0 {
            return .Invalid_Gltf
        }
        // Only the three unsigned integer types may index an overlay.
        #partial switch sparse.indices_component_type {
        case .Unsigned_Byte, .Unsigned_Short, .Unsigned_Int:
        case:
            return .Invalid_Gltf
        }
        if sparse.indices_buffer_view == nil || sparse.values_buffer_view == nil {
            return .Invalid_Gltf
        }
        // Sparse index/value data is tightly packed and is not vertex attribute
        // data; its bufferViews cannot declare byteStride.
        if sparse.indices_buffer_view.stride != 0 || sparse.values_buffer_view.stride != 0 {
            return .Invalid_Gltf
        }

        index_size := component_size(sparse.indices_component_type)
        if !strided_range_fits(
            sparse.indices_buffer_view.size,
            sparse.indices_byte_offset,
            index_size,
            sparse.count,
            index_size,
        ) {
            return .Invalid_Gltf
        }
        // Sparse values are tightly packed: the accessor's stride does not
        // apply to them.
        if !strided_range_fits(
            sparse.values_buffer_view.size,
            sparse.values_byte_offset,
            element_size,
            sparse.count,
            element_data_size(accessor.type, accessor.component_type),
        ) {
            return .Invalid_Gltf
        }

        // What is left can only be checked against bytes that have been loaded:
        // every overlay index has to be inside the accessor, and the
        // specification requires the indices to be strictly increasing, which
        // is what lets `read_float` binary search them.
        indices_data := buffer_view_data(sparse.indices_buffer_view)
        if indices_data == nil {
            continue
        }
        previous := -1
        for i in 0 ..< sparse.count {
            offset := sparse.indices_byte_offset + i * index_size
            if offset + index_size > len(indices_data) {
                break
            }
            index := int(component_read_uint(indices_data[offset:], sparse.indices_component_type))
            if index <= previous || index >= accessor.count {
                return .Invalid_Gltf
            }
            previous = index
        }
    }
    return nil
}

// Checks each bufferView against its buffer, and checks the meshopt compression
// extension's own layout constraints.
@(private)
validate_buffer_views :: proc(document: ^Document) -> Maybe(Error) {
    for &view in document.buffer_views {
        if view.offset < 0 || view.size < 0 {
            return .Invalid_Gltf
        }
        if view.stride != 0 && view.target == .Element_Array_Buffer {
            return .Invalid_Gltf
        }
        // A bufferView without a buffer is legal JSON but has no payload.
        // Nothing can be read through it, so leave it be.
        if view.buffer != nil {
            if view.offset > view.buffer.size || view.size > view.buffer.size - view.offset {
                return .Invalid_Gltf
            }
        }
        if !view.has_meshopt {
            continue
        }
        compression := &view.meshopt
        if compression.buffer == nil {
            return .Invalid_Gltf
        }
        if compression.offset < 0 || compression.size < 0 {
            return .Invalid_Gltf
        }
        if compression.offset > compression.buffer.size ||
           compression.size > compression.buffer.size - compression.offset {
            return .Invalid_Gltf
        }
        if compression.stride <= 0 || compression.count < 0 {
            return .Invalid_Gltf
        }
        // The compressed payload describes the same elements the bufferView
        // does, so the two strides have to agree when the bufferView has one.
        if view.stride != 0 && compression.stride != view.stride {
            return .Invalid_Gltf
        }
        if !product_equals(compression.stride, compression.count, view.size) {
            return .Invalid_Gltf
        }
        switch compression.mode {
        case .Attributes:
            if compression.stride % 4 != 0 || compression.stride > 256 {
                return .Invalid_Gltf
            }
        case .Triangles:
            if compression.count % 3 != 0 {
                return .Invalid_Gltf
            }
            if compression.stride != 2 && compression.stride != 4 {
                return .Invalid_Gltf
            }
            if compression.filter != .None {
                return .Invalid_Gltf
            }
        case .Indices:
            if compression.stride != 2 && compression.stride != 4 {
                return .Invalid_Gltf
            }
            if compression.filter != .None {
                return .Invalid_Gltf
            }
        }
        // Each post filter decodes a fixed-width element, which pins the stride.
        switch compression.filter {
        case .Octahedral:
            if compression.stride != 4 && compression.stride != 8 {
                return .Invalid_Gltf
            }
        case .Quaternion:
            if compression.stride != 8 {
                return .Invalid_Gltf
            }
        case .Color:
            if compression.stride != 4 && compression.stride != 8 {
                return .Invalid_Gltf
            }
        case .None, .Exponential:
        }
    }
    return nil
}

// Checks whether `count` elements of `element_size` bytes, separated by `stride`,
// fit in a `total_size` byte range starting at `offset`. It works by dividing the
// available bytes instead of multiplying attacker - controlled values, avoiding
// overflow in malformed documents.
@(private)
strided_range_fits :: proc "contextless" (
    total_size, offset, stride, count, element_size: int,
) -> bool {
    if total_size < 0 || offset < 0 || stride <= 0 || count < 0 || element_size < 0 {
        return false
    }
    if offset > total_size {
        return false
    }
    available := total_size - offset
    if count == 0 {
        return true
    }
    if element_size > available {
        return false
    }
    remaining := available - element_size
    return count - 1 <= remaining / stride
}

// Compares a non-negative product with a known non-negative value without
// overflowing while computing the product.
@(private)
product_equals :: proc "contextless" (a, b, value: int) -> bool {
    if a < 0 || b < 0 || value < 0 {
        return false
    }
    if a == 0 || b == 0 {
        return value == 0
    }
    if a > value / b {
        return false
    }
    return a * b == value
}

// Checks the morph target arity and the attribute counts of every primitive.
@(private)
validate_meshes :: proc(document: ^Document) -> Maybe(Error) {
    for &mesh in document.meshes {
        if len(mesh.primitives) == 0 {
            // An empty mesh is legal; the arity checks below all compare against
            // the first primitive, so there is nothing to compare.
            continue
        }
        // All primitives of a mesh share one morph target count.
        targets := len(mesh.primitives[0].targets)
        if len(mesh.weights) > 0 && len(mesh.weights) != targets {
            return .Invalid_Gltf
        }
        if len(mesh.target_names) > 0 && len(mesh.target_names) != targets {
            return .Invalid_Gltf
        }

        for &primitive in mesh.primitives {
            if primitive.mode == .Invalid {
                return .Invalid_Gltf
            }
            if len(primitive.targets) != targets {
                return .Invalid_Gltf
            }
            // A primitive with no attributes draws nothing, and there is no
            // vertex count to check the rest of the primitive against.
            if len(primitive.attributes) == 0 {
                return .Invalid_Gltf
            }
            first := primitive.attributes[0].data
            if first == nil || first.count == 0 {
                return .Invalid_Gltf
            }
            // Every attribute of a primitive describes the same vertex count,
            // and so does every attribute of every morph target.
            for attribute in primitive.attributes {
                if attribute.data == nil || attribute.data.count != first.count {
                    return .Invalid_Gltf
                }
            }
            for target in primitive.targets {
                for attribute in target.attributes {
                    if attribute.data == nil || attribute.data.count != first.count {
                        return .Invalid_Gltf
                    }
                }
            }

            if indices := primitive.indices; indices != nil {
                // An index accessor is a tightly packed array of unsigned
                // integers, and every one of them has to name a vertex.
                #partial switch indices.component_type {
                case .Unsigned_Byte, .Unsigned_Short, .Unsigned_Int:
                case:
                    return .Invalid_Gltf
                }
                if indices.type != .Scalar {
                    return .Invalid_Gltf
                }
                if indices.stride != component_size(indices.component_type) {
                    return .Invalid_Gltf
                }
                if index_accessor_exceeds_vertex_count(indices, first.count) {
                    return .Invalid_Gltf
                }
            }

            for mapping in primitive.mappings {
                if mapping.variant < 0 || mapping.variant >= len(document.variants) {
                    return .Invalid_Gltf
                }
            }
        }
    }
    return nil
}

// Checks each node's morph weights and its GPU instancing attributes.
@(private)
validate_nodes :: proc(document: ^Document) -> Maybe(Error) {
    for &node in document.nodes {
        if len(node.weights) > 0 &&
           node.mesh != nil &&
           len(node.mesh.primitives) > 0 &&
           len(node.weights) != len(node.mesh.primitives[0].targets) {
            return .Invalid_Gltf
        }
        if !node.has_gpu_instancing {
            continue
        }
        if node.mesh == nil {
            return .Invalid_Gltf
        }
        // Instancing adds one translation/rotation/scale set per instance on
        // top of the mesh's own vertices, so the attributes have to agree on an
        // instance count but need not agree with the mesh's vertex count.
        if len(node.gpu_instancing.attributes) == 0 {
            return .Invalid_Gltf
        }
        first := node.gpu_instancing.attributes[0].data
        if first == nil {
            return .Invalid_Gltf
        }
        for attribute in node.gpu_instancing.attributes {
            if attribute.data == nil || attribute.data.count != first.count {
                return .Invalid_Gltf
            }
        }
    }
    if err := validate_node_tree(document); err != nil {
        return err
    }
    return nil
}

// Checks that the node graph is a forest.
//
// The schema makes it a tree: every node has at most one parent, no node is its
// own ancestor, and a node may not appear twice in one `children` list.
@(private)
validate_node_tree :: proc(document: ^Document) -> Maybe(Error) {
    // Node.parent holds whichever parent was seen last, so a child that
    // comes back pointing somewhere else was claimed by a second parent.
    for &node in document.nodes {
        for child, i in node.children {
            if child == nil || child.parent != &node {
                return .Invalid_Gltf
            }
            // A parent that lists the same child twice is malformed too, and
            // comparing within the list catches it without a side table.
            for earlier in node.children[:i] {
                if earlier == child {
                    return .Invalid_Gltf
                }
            }
        }
    }

    // Walk each chain up to the root, remembering where it has been.  The walk
    // is bounded by MAX_NODE_DEPTH so that a cycle terminates instead of
    // hanging.
    for &node in document.nodes {
        seen: [MAX_NODE_DEPTH]^Node
        count := 0
        current: ^Node = &node
        for current != nil && count < MAX_NODE_DEPTH {
            for i in 0 ..< count {
                if seen[i] == current {
                    return .Invalid_Gltf
                }
            }
            seen[count] = current
            count += 1
            current = current.parent
        }
    }
    return nil
}

// Checks that each scene lists only root nodes.
@(private)
validate_scenes :: proc(document: ^Document) -> Maybe(Error) {
    for &scene in document.scenes {
        for node in scene.nodes {
            if node == nil || node.parent != nil {
                return .Invalid_Gltf
            }
        }
    }
    return nil
}

// Checks each skin's joint list against its inverse bind matrices.
@(private)
validate_skins :: proc(document: ^Document) -> Maybe(Error) {
    for &skin in document.skins {
        if len(skin.joints) == 0 {
            return .Invalid_Gltf
        }
        for joint in skin.joints {
            if joint == nil {
                return .Invalid_Gltf
            }
        }
        if matrices := skin.inverse_bind_matrices; matrices != nil {
            // One 4x4 matrix per joint, in the same order.
            if matrices.type != .Mat4 {
                return .Invalid_Gltf
            }
            if matrices.count != len(skin.joints) {
                return .Invalid_Gltf
            }
        }
        // `skeleton` is the root of the joint hierarchy and need not itself be
        // listed in `joints`; common layouts use an unskinned ancestor here.
    }
    return nil
}

// Checks that each channel's sampler and its two accessors
// describe a well formed track.
@(private)
validate_animations :: proc(document: ^Document) -> Maybe(Error) {
    for &animation in document.animations {
        for &channel in animation.channels {
            sampler := channel.sampler
            if sampler == nil || sampler.input == nil || sampler.output == nil {
                return .Invalid_Gltf
            }
            // Time is a scalar list of seconds, and it needs a min and a max to
            // be sampled.
            if sampler.input.type != .Scalar || sampler.input.component_type != .Float {
                return .Invalid_Gltf
            }
            if !sampler.input.has_min || !sampler.input.has_max {
                return .Invalid_Gltf
            }

            node := channel.target_node
            if node == nil {
                continue
            }

            // Cubic spline samples carry a value, an in tangent and an out
            // tangent, so three outputs per keyframe.
            values := 1
            if sampler.interpolation == .Cubic_Spline {
                values = 3
            }

            components := 1
            switch channel.target_path {
            case .Translation:
                if sampler.output.type != .Vec3 {
                    return .Invalid_Gltf
                }
            case .Rotation:
                if sampler.output.type != .Vec4 {
                    return .Invalid_Gltf
                }
            case .Scale:
                if sampler.output.type != .Vec3 {
                    return .Invalid_Gltf
                }
            case .Weights:
                // Weights animate one scalar per morph target, so the node needs
                // a mesh with morph targets to animate.
                if node.mesh == nil || len(node.mesh.primitives) == 0 {
                    return .Invalid_Gltf
                }
                components = len(node.mesh.primitives[0].targets)
                if components == 0 || sampler.output.type != .Scalar {
                    return .Invalid_Gltf
                }
            case .Pointer:
            // KHR_animation_pointer supplies the target type through its
            // JSON pointer, so this package cannot constrain the output
            // element shape here.
            case .Invalid:
                return .Invalid_Gltf
            }
            if sampler.input.count * components * values != sampler.output.count {
                return .Invalid_Gltf
            }
        }
    }
    return nil
}

// Checks the KHR_materials_variants extension, which requires
// every variant to be named.
@(private)
validate_variants :: proc(document: ^Document) -> Maybe(Error) {
    for &variant in document.variants {
        if variant.name == "" {
            return .Invalid_Gltf
        }
    }
    return nil
}

// Checks loaded mesh indices without converting an unsigned value to signed `int`
// (which can wrap on 32-bit targets for a large UNSIGNED_INT index). If the bytes
// are not loaded, this check is deferred; structural accessor ranges are still
// validated above.
@(private)
index_accessor_exceeds_vertex_count :: proc(accessor: ^Accessor, vertex_count: int) -> bool {
    if accessor == nil ||
       accessor.buffer_view == nil ||
       accessor.buffer_view.data == nil ||
       accessor.count <= 0 ||
       vertex_count <= 0 {
        return false
    }
    size := component_size(accessor.component_type)
    if size == 0 {
        return false
    }
    for i in 0 ..< accessor.count {
        element := accessor_element(accessor, i)
        if element == nil || len(element) < size {
            // Truncated data; the extent check in validate_accessors is what
            // reports that, and there is nothing useful left to compute here.
            return false
        }
        value := u64(component_read_uint(element, accessor.component_type))
        if value >= u64(vertex_count) {
            return true
        }
    }
    return false
}
