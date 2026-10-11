package gltf

// Core
import la "core:math/linalg"

// Copies glTF's flat column-major array into Odin's column-major matrix.
@(private)
node_matrix_from_gltf :: proc(values: [16]f32) -> la.Matrix4f32 {
    result: la.Matrix4f32
    for column in 0 ..< 4 {
        for row in 0 ..< 4 {
            result[column][row] = values[column * 4 + row]
        }
    }
    return result
}

// Fills in `Node.parent` for every node that some other node lists in its
// `children`.
//
// A node may legitimately be listed by at most one parent; `validate` reports a
// node with two parents rather than this procedure silently keeping one.
@(private)
link_parents :: proc(document: ^Document) {
    for &node in document.nodes {
        node.parent = nil
    }
    for &node in document.nodes {
        for child in node.children {
            child.parent = &node
        }
    }
}

// Returns the node's own transform as a column-major 4x4 matrix.
//
// A node's transform is either the explicit `matrix` or, when no `matrix` is
// present, the TRS composition `translation * rotation * scale`.  A node with
// neither is the identity. When `matrix` is present the TRS members are ignored,
// as the specification requires.
node_transform_local :: proc(node: ^Node) -> la.Matrix4f32 {
    if node.has_matrix {
        return node.matrix_
    }
    // The defaults are the identity TRS, which is what a node that names none
    // of the three means.
    translation := node.translation
    rotation := node.rotation
    if !node.has_rotation {
        rotation = {0, 0, 0, 1}
    }
    scale := node.scale
    if !node.has_scale {
        scale = {1, 1, 1}
    }

    // Both glTF and core:math/linalg store matrices column-major, and the
    // quaternion component order is x, y, z, w in both representations.
    quaternion := transmute(la.Quaternionf32)rotation
    return la.matrix4_from_trs(translation, quaternion, scale)
}

// Returns the node's transform composed with the transforms of its ancestors, as a
// column-major 4x4 matrix.
//
// The walk up the parent chain is bounded by `MAX_NODE_DEPTH`. A document whose
// nodes form a cycle is invalid, but an unbounded walk would hang rather than
// report anything useful.
node_transform_world :: proc(node: ^Node) -> la.Matrix4f32 {
    result := node_transform_local(node)
    parent := node.parent
    for depth := 0; parent != nil; depth += 1 {
        if depth >= MAX_NODE_DEPTH {
            break
        }
        parent_matrix := node_transform_local(parent)
        result = parent_matrix * result

        parent = parent.parent
    }
    return result
}
