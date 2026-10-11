package gltf

// Core
import "core:slice"

// Returns the bytes of `view` inside its buffer, or nil if the buffer has not been
// loaded or the range does not fit.
//
// `load_buffers` publishes this in `Buffer_View.data`, so a caller holding a
// bufferView can use that directly; this recomputes it for the cases where a
// buffer was filled in after the fact.
@(private)
buffer_view_data :: proc(view: ^Buffer_View) -> []byte {
    if view.buffer == nil || view.buffer.data == nil {
        return nil
    }
    data := view.buffer.data
    if view.offset < 0 || view.size < 0 || view.offset > len(data) {
        return nil
    }
    if view.size > len(data) - view.offset {
        return nil
    }
    return data[view.offset:view.offset + view.size]
}

// accessor_element returns the address of element `index` of `accessor`, or nil
// if it is not backed by loaded data.
@(private)
accessor_element :: proc(accessor: ^Accessor, index: int) -> []byte {
    if index < 0 || index >= accessor.count {
        return nil
    }
    if accessor.buffer_view == nil || accessor.buffer_view.data == nil {
        return nil
    }
    data := accessor.buffer_view.data
    if accessor.offset < 0 || accessor.stride <= 0 || accessor.offset > len(data) {
        return nil
    }
    remaining := len(data) - accessor.offset
    if index > remaining / accessor.stride {
        return nil
    }
    offset := accessor.offset + accessor.stride * index
    return data[offset:]
}

// sparse_element returns the address of the sparse value for `index`, or nil if
// the accessor's sparse overlay does not cover `index`.
@(private)
sparse_element :: proc(accessor: ^Accessor, index: int) -> []byte {
    sparse := &accessor.sparse
    if !accessor.has_sparse || sparse.count <= 0 {
        return nil
    }
    indices_data := buffer_view_data(sparse.indices_buffer_view)
    values_data := buffer_view_data(sparse.values_buffer_view)
    if indices_data == nil || values_data == nil {
        return nil
    }

    // The sparse index component is one of three unsigned integers, so it is
    // packed with no stride of its own; only the byte offset applies.
    index_size := component_size(sparse.indices_component_type)
    if index_size == 0 {
        return nil
    }
    // Sparse values are tightly packed: unlike a bufferView's stride, the
    // accessor's stride does not apply to them.  Reusing the accessor stride
    // for both reads the wrong offset for every sparse accessor whose
    // stride is not the element size.
    element_size := element_size(accessor.type, accessor.component_type)
    if element_size == 0 {
        return nil
    }
    value_data_size := element_data_size(accessor.type, accessor.component_type)
    if !strided_range_fits(
           len(indices_data),
           sparse.indices_byte_offset,
           index_size,
           sparse.count,
           index_size,
       ) ||
       !strided_range_fits(
               len(values_data),
               sparse.values_byte_offset,
               element_size,
               sparse.count,
               value_data_size,
           ) {
        return nil
    }

    // The specification requires the indices to be strictly increasing, which is
    // what makes this binary search correct.
    low, high := 0, sparse.count - 1
    for low <= high {
        middle := low + (high - low) / 2
        offset := sparse.indices_byte_offset + middle * index_size
        if offset < 0 || offset + index_size > len(indices_data) {
            return nil
        }
        entry := read_component(indices_data[offset:], sparse.indices_component_type)
        if int(entry) == index {
            value_offset := sparse.values_byte_offset + middle * element_size
            return values_data[value_offset:]
        }
        if int(entry) < index {
            low = middle + 1
        } else {
            high = middle - 1
        }
    }
    return nil
}

// read_component reads one scalar of `component_type` out of `data`.
@(private)
read_component :: proc(data: []byte, component_type: Component_Type) -> u32 {
    if len(data) < component_size(component_type) {
        return 0
    }
    switch component_type {
    case .Byte:
        return u32((^i8)(raw_data(data))^)
    case .Unsigned_Byte:
        return u32(data[0])
    case .Short:
        return u32((^i16)(raw_data(data))^)
    case .Unsigned_Short:
        return u32((^u16)(raw_data(data))^)
    case .Unsigned_Int:
        return (^u32)(raw_data(data))^
    case .Float:
        return u32((^f32)(raw_data(data))^)
    case .Invalid:
        return 0
    }
    return 0
}

// component_read_float reads one scalar, applying `normalized` conversion when
// the accessor is a normalized integer accessor.
@(private)
component_read_float :: proc(
    data: []byte,
    component_type: Component_Type,
    normalized: bool,
) -> f32 {
    if component_type == .Float {
        return (^f32)(raw_data(data))^
    }
    if !normalized {
        return f32(i32(read_component(data, component_type)))
    }
    // The glTF normalization ranges, as listed in the specification's accessor
    // section.  Note that 32-bit integer components have no normalized form.
    #partial switch component_type {
    case .Byte:
        return max(f32((^i8)(raw_data(data))^) / 127.0, -1)
    case .Unsigned_Byte:
        return f32(data[0]) / 255.0
    case .Short:
        return max(f32((^i16)(raw_data(data))^) / 32767.0, -1)
    case .Unsigned_Short:
        return f32((^u16)(raw_data(data))^) / 65535.0
    case:
        return 0
    }
}

// component_read_uint reads one unsigned scalar, which is how indices are read.
@(private)
component_read_uint :: proc(data: []byte, component_type: Component_Type) -> u32 {
    return read_component(data, component_type)
}

// element_read_floats reads one element out of `data` into `out`.
//
// `out` must have room for `num_components` floats.  Returns false if `data`
// is too short for the element.
@(private)
element_read_floats :: proc(
    data: []byte,
    type: Element_Type,
    component_type: Component_Type,
    normalized: bool,
    out: []f32,
) -> bool {
    count := num_components(type)
    element_size := element_data_size(type, component_type)
    if element_size == 0 || len(out) < count || len(data) < element_size {
        return false
    }

    // Three matrix layouts need the 4-byte column padding of the specification's
    // "data alignment" rules; everything else is tightly packed.
    size := component_size(component_type)
    switch {
    case type == .Mat2 && size == 1:
        out[0] = component_read_float(data[0:], component_type, normalized)
        out[1] = component_read_float(data[1:], component_type, normalized)
        out[2] = component_read_float(data[4:], component_type, normalized)
        out[3] = component_read_float(data[5:], component_type, normalized)
        return true
    case type == .Mat3 && size == 1:
        for column in 0 ..< 3 {
            for row in 0 ..< 3 {
                out[column * 3 + row] = component_read_float(
                    data[column * 4 + row:],
                    component_type,
                    normalized,
                )
            }
        }
        return true
    case type == .Mat3 && size == 2:
        for column in 0 ..< 3 {
            for row in 0 ..< 3 {
                out[column * 3 + row] = component_read_float(
                    data[column * 8 + row * 2:],
                    component_type,
                    normalized,
                )
            }
        }
        return true
    }

    for i in 0 ..< count {
        out[i] = component_read_float(data[i * size:], component_type, normalized)
    }
    return true
}

// element_read_uints reads one element of integers out of `data` into `out`.
// Matrix element types are rejected, since an integer matrix has no meaning.
@(private)
element_read_uints :: proc(
    data: []byte,
    type: Element_Type,
    component_type: Component_Type,
    out: []u32,
) -> bool {
    #partial switch type {
    case .Mat2, .Mat3, .Mat4:
        return false
    case:
    }
    count := num_components(type)
    size := component_size(component_type)
    if size == 0 || len(out) < count || len(data) < size * count {
        return false
    }
    for i in 0 ..< count {
        out[i] = component_read_uint(data[i * size:], component_type)
    }
    return true
}

// Returns how many floats one call to `unpack_floats` on `accessor` would
// produce without a `dest` limit.
accessor_float_count :: proc(accessor: ^Accessor) -> int {
    if accessor == nil || accessor.count <= 0 {
        return 0
    }
    components := num_components(accessor.type)
    if components <= 0 || accessor.count > MAX_INT_VALUE / components {
        return 0
    }
    return accessor.count * components
}

// Reads element `index` of `accessor` as floats into `out`.
//
// `out` must have room for `num_components` floats.  A sparse accessor's overlay
// takes precedence over the base data, and an element that is covered by neither
// reads as zeros.  Returns false when `index` is outside the accessor or `out` is
// too small.
read_float :: proc(accessor: ^Accessor, index: int, out: []f32) -> bool {
    if accessor == nil || index < 0 || index >= accessor.count {
        return false
    }
    count := num_components(accessor.type)
    if count <= 0 || len(out) < count {
        return false
    }
    if accessor.has_sparse {
        if element := sparse_element(accessor, index); element != nil {
            if element_read_floats(
                element,
                accessor.type,
                accessor.component_type,
                accessor.normalized,
                out,
            ) {
                return true
            }
        }
    }
    if accessor.buffer_view == nil {
        slice.zero(out[:count])
        return true
    }
    element := accessor_element(accessor, index)
    if element == nil {
        return false
    }
    return element_read_floats(
        element,
        accessor.type,
        accessor.component_type,
        accessor.normalized,
        out,
    )
}

// Reads element `index` of `accessor` as unsigned integers into `out`.
//
// `out` must have room for `num_components` integers. Matrix element types are
// rejected.
read_uint :: proc(accessor: ^Accessor, index: int, out: []u32) -> bool {
    if accessor == nil || index < 0 || index >= accessor.count {
        return false
    }
    count := num_components(accessor.type)
    if count <= 0 || len(out) < count {
        return false
    }
    #partial switch accessor.type {
    case .Mat2, .Mat3, .Mat4:
        return false
    case:
    }
    if accessor.has_sparse {
        if element := sparse_element(accessor, index); element != nil {
            if element_read_uints(element, accessor.type, accessor.component_type, out) {
                return true
            }
        }
    }
    if accessor.buffer_view == nil {
        zero_u32(out[:count])
        return true
    }
    element := accessor_element(accessor, index)
    if element == nil {
        return false
    }
    return element_read_uints(element, accessor.type, accessor.component_type, out)
}

// zero_u32 sets `values` to zero.
@(private)
zero_u32 :: proc(values: []u32) {
    for i in 0 ..< len(values) {
        values[i] = 0
    }
}

// Reads element `index` of `accessor` as a single unsigned integer, which is how
// the index accessor of a primitive is read.
//
// Returns 0 when the accessor does not have a scalar unsigned element type or the
// read failed.
read_index :: proc(accessor: ^Accessor, index: int) -> u32 {
    if accessor == nil || accessor.type != .Scalar || index < 0 || index >= accessor.count {
        return 0
    }
    #partial switch accessor.component_type {
    case .Unsigned_Byte, .Unsigned_Short, .Unsigned_Int:
    case:
        return 0
    }
    if accessor.has_sparse {
        if element := sparse_element(accessor, index); element != nil {
            return component_read_uint(element, accessor.component_type)
        }
    }
    element := accessor_element(accessor, index)
    if element == nil {
        return 0
    }
    return component_read_uint(element, accessor.component_type)
}

// Reads `min(dest_len, accessor.count * components)` floats of `accessor` into
// `dest`, applying any sparse overlay, and returns how many were written.
//
// A nil `dest` just reports the count, which is how a caller sizes its buffer.
unpack_floats :: proc(accessor: ^Accessor, dest: []f32) -> int {
    if accessor == nil {
        return 0
    }
    components := num_components(accessor.type)
    if components <= 0 || accessor.count <= 0 {
        return 0
    }
    if dest == nil {
        return accessor_float_count(accessor)
    }
    element_count := min(accessor.count, len(dest) / components)
    float_count := element_count * components

    if accessor.buffer_view == nil {
        // An accessor with no bufferView is defined to be all zeros, apart from
        // whatever the sparse overlay sets.
        for i in 0 ..< element_count * components {
            dest[i] = 0
        }
    } else {
        data := accessor.buffer_view.data
        offset := accessor.offset
        stride := accessor.stride
        // The common case: tightly packed floats can be copied wholesale.
        fast_copy := false
        if accessor.component_type == .Float &&
           stride == components * 4 &&
           data != nil &&
           offset >= 0 &&
           offset <= len(data) {
            remaining := len(data) - offset
            if stride > 0 && element_count <= remaining / stride {
                byte_count := element_count * stride
                copy(dest[:float_count], transmute([]f32)data[offset:offset + byte_count])
                fast_copy = true
            }
        }
        if !fast_copy {
            for i in 0 ..< element_count {
                element := accessor_element(accessor, i)
                if element == nil {
                    return i * components
                }
                if !element_read_floats(
                    element,
                    accessor.type,
                    accessor.component_type,
                    accessor.normalized,
                    dest[i * components:],
                ) {
                    return i * components
                }
            }
        }
    }

    // The sparse overlay is written last, on top of the base data.
    //
    // Using the accessor stride as the values step and writing past the
    // output without bounds checks would corrupt memory.  Both are fixed
    // here: the values are tightly packed, and an index past the end of the
    // accessor is skipped.
    sparse := &accessor.sparse
    if accessor.has_sparse {
        indices_data := buffer_view_data(sparse.indices_buffer_view)
        values_data := buffer_view_data(sparse.values_buffer_view)
        index_size := component_size(sparse.indices_component_type)
        element_size := element_size(accessor.type, accessor.component_type)
        values_size := element_data_size(accessor.type, accessor.component_type)
        if indices_data != nil &&
           values_data != nil &&
           index_size > 0 &&
           element_size > 0 &&
           strided_range_fits(
               len(indices_data),
               sparse.indices_byte_offset,
               index_size,
               sparse.count,
               index_size,
           ) &&
           strided_range_fits(
               len(values_data),
               sparse.values_byte_offset,
               element_size,
               sparse.count,
               values_size,
           ) {
            for i in 0 ..< sparse.count {
                index_offset := sparse.indices_byte_offset + i * index_size
                writer := int(
                    component_read_uint(
                        indices_data[index_offset:],
                        sparse.indices_component_type,
                    ),
                )
                if writer < 0 || writer >= element_count {
                    continue
                }
                value_offset := sparse.values_byte_offset + i * element_size
                element_read_floats(
                    values_data[value_offset:],
                    accessor.type,
                    accessor.component_type,
                    accessor.normalized,
                    dest[writer * components:],
                )
            }
        }
    }

    return element_count * components
}

// Reads `min(len(dest), accessor.count)` unsigned integers of `accessor` into
// `dest`, applying any sparse overlay, and returns how many were written.
unpack_indices :: proc(accessor: ^Accessor, dest: []u32) -> int {
    if accessor == nil || accessor.count <= 0 {
        return 0
    }
    #partial switch accessor.type {
    case .Scalar:
    case:
        return 0
    }
    #partial switch accessor.component_type {
    case .Unsigned_Byte, .Unsigned_Short, .Unsigned_Int:
    case:
        return 0
    }
    if dest == nil {
        return accessor.count
    }
    count := min(len(dest), accessor.count)
    for i in 0 ..< count {
        dest[i] = read_index(accessor, i)
    }
    return count
}

// Returns the accessor bound to semantic `type` and set `index` in `primitive`, or
// nil if the primitive has no such attribute.
find_accessor :: proc(primitive: ^Primitive, type: Attribute_Type, index := 0) -> ^Accessor {
    if primitive == nil {
        return nil
    }
    for attribute in primitive.attributes {
        if attribute.type == type && attribute.index == index {
            return attribute.data
        }
    }
    return nil
}
