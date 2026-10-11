package gltf

// Core
import "core:strings"

// The number of scalars `accessor.min`/`accessor.max` can hold, i.e. one MAT4.
MAX_ACCESSOR_MIN_MAX :: 16

// The largest signed integer on this target. It guards scalar-count
// calculations exposed by accessor unpack helpers.
MAX_INT_VALUE :: int((~uint(0)) >> 1)

// Bounds how far `node_transform_world` walks up the parent chain.  The glTF
// schema forbids a node from being its own ancestor, but a malformed file can
// still contain a cycle, and an unbounded walk would hang.
MAX_NODE_DEPTH :: 64

// Returns the number of scalars in one element of `type`: 1 for SCALAR, 3 for
// VEC3, 4 for MAT2, 9 for MAT3, 16 for MAT4.
//
// Returns 0 for `Element_Type.Invalid`.
num_components :: proc "contextless" (type: Element_Type) -> int {
    switch type {
    case .Scalar:
        return 1
    case .Vec2:
        return 2
    case .Vec3:
        return 3
    case .Vec4, .Mat2:
        return 4
    case .Mat3:
        return 9
    case .Mat4:
        return 16
    case .Invalid:
        return 0
    }
    return 0
}

// Returns the size in bytes of one scalar of `component_type`, or 0 for
// `Component_Type.Invalid`.
@(private)
component_size :: proc "contextless" (component_type: Component_Type) -> int {
    switch component_type {
    case .Byte, .Unsigned_Byte:
        return 1
    case .Short, .Unsigned_Short:
        return 2
    case .Unsigned_Int, .Float:
        return 4
    case .Invalid:
        return 0
    }
    return 0
}

// Returns the size in bytes of one tightly packed element of
// `type`/`component_type`, accounting for the 4-byte column padding that glTF
// requires for matrix types (MAT2 of BYTE is 8 bytes, MAT3 of SHORT is 24 bytes,
// MAT3 of FLOAT is 36 bytes).
//
// Returns 0 if either argument is invalid.
element_size :: proc "contextless" (type: Element_Type, component_type: Component_Type) -> int {
    size := component_size(component_type)
    if size == 0 || type == .Invalid {
        return 0
    }
    // A matrix column is `rows * size` bytes, padded out to a multiple of 4.
    #partial switch type {
    case .Mat2:
        if size == 1 {
            return 8
        }
    case .Mat3:
        if size == 1 || size == 2 {
            return 12 * size
        }
    }
    return size * num_components(type)
}

// Returns the number of bytes touched when reading one element.  For a padded
// matrix column, glTF requires the *next* column (or element) to begin at a 4-byte
// boundary, but there is no padding after the final column.  element_size remains
// the padded stride; this smaller tail size is used for bounds checks and the last
// element of a view.
@(private)
element_data_size :: proc "contextless" (
    type: Element_Type,
    component_type: Component_Type,
) -> int {
    size := component_size(component_type)
    switch {
    case type == .Mat2 && size == 1:
        return 6
    case type == .Mat3 && size == 1:
        return 11
    case type == .Mat3 && size == 2:
        return 22
    }
    return element_size(type, component_type)
}

// Sorts short string lists (extension names, variant keys) with insertion sort,
// which beats quick_sort's recursion and indirect calls for the 0-4 element lists
// that dominate glTF documents.
@(private)
sort_strings_small :: proc(names: []string) {
    if len(names) < 2 {
        return
    }
    for i in 1 ..< len(names) {
        tmp := names[i]
        j := i - 1
        for j >= 0 && strings.compare(names[j], tmp) > 0 {
            names[j + 1] = names[j]
            j -= 1
        }
        names[j + 1] = tmp
    }
}
