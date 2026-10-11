/*
This is a vector (a variable-sized array), optimized for the case when the array is small.

It contains some number of elements in-place, which allows it to avoid heap allocation
when the actual number of elements is below that threshold. This allows normal "small"
cases to be fast without losing generality for large inputs.

Example:

    v: Small_Vector(int, 8)
    small_vector_init(&v, context.allocator)
    defer small_vector_destroy(&v)

    small_vector_push_back(&v, 42)
*/
package gpu

// Core
import "base:runtime"

Small_Vector :: struct($T: typeid, $N: int) {
    count:         int,
    static_array:  [N]T,       // Used when count <= N
    dynamic_array: [dynamic]T, // Used when count > N
}

small_vector_init :: proc(
    v: ^Small_Vector($T, $N),
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(v != nil, loc = loc)
    v.count = 0
    v.dynamic_array.allocator = allocator
}

small_vector_init_count :: proc(
    v: ^Small_Vector($T, $N),
    count: int,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(v != nil, loc = loc)
    assert(count >= 0, loc = loc)
    v.count = count
    if count > N {
        v.dynamic_array = make([dynamic]T, count, allocator)
    } else {
        v.dynamic_array = make([dynamic]T, 0, allocator)
    }
}

small_vector_uninit :: proc(v: ^Small_Vector($T, $N), loc := #caller_location) {
    assert(v != nil, loc = loc)
    delete(v.dynamic_array)
    v.count = 0
}

small_vector_len :: proc (v: ^Small_Vector($T, $N), loc := #caller_location) -> int {
    assert(v != nil, loc = loc)
    return v.count
}

small_vector_empty :: proc (v: ^Small_Vector($T, $N), loc := #caller_location)  -> bool {
    assert(v != nil, loc = loc)
    return small_vector_len(v) == 0
}

small_vector_slice :: proc (v: ^Small_Vector($T, $N), loc := #caller_location) -> []T {
    assert(v != nil, loc = loc)
    if v.count > N {
        return v.dynamic_array[:]
    }
    return v.static_array[:v.count]
}

small_vector_front :: proc (v: ^Small_Vector($T, $N), loc := #caller_location) -> ^T {
    assert(v != nil, loc = loc)
    assert(v.count > 0, loc = loc)
    return &small_vector_slice(v)[0]
}

small_vector_back :: proc (v: ^Small_Vector($T, $N), loc := #caller_location) -> ^T {
    assert(v != nil, loc = loc)
    assert(v.count > 0, loc = loc)
    return &small_vector_slice(v)[v.count - 1]
}

small_vector_get :: proc (
    v: ^Small_Vector($T, $N),
    index: int,
    loc := #caller_location,
) -> ^T {
    assert(v != nil, loc = loc)
    assert(index >= 0 && index < v.count, loc = loc)
    return &small_vector_slice(v)[index]
}

small_vector_pop_front :: proc(v: ^Small_Vector($T, $N), loc := #caller_location) {
    assert(v != nil, loc = loc)
    assert(v.count > 0, loc = loc)
    small_vector_remove(v, 0)
}

small_vector_pop_back :: proc(v: ^Small_Vector($T, $N), loc := #caller_location) {
    assert(v != nil, loc = loc)
    assert(v.count > 0, loc = loc)
    small_vector_resize(v, v.count - 1)
}

small_vector_push_front :: proc(v: ^Small_Vector($T, $N), src: T, loc := #caller_location) {
    assert(v != nil, loc = loc)
    small_vector_insert(v, 0, src)
}

small_vector_push_back :: proc(v: ^Small_Vector($T, $N), src: T, loc := #caller_location) {
    assert(v != nil, loc = loc)
    new_index := small_vector_len(v)
    small_vector_resize(v, new_index + 1)
    small_vector_slice(v)[new_index] = src
}

small_vector_resize :: proc(
    v: ^Small_Vector($T, $N),
    new_count: int,
    free_memory := false,
    loc := #caller_location,
) {
    assert(v != nil, loc = loc)
    assert(new_count >= 0, loc = loc)

    if new_count > N && v.count > N {
        // Any direction, staying in dynamic_array
        resize(&v.dynamic_array, new_count)
        if free_memory {
            shrink(&v.dynamic_array, new_count)
        }
    } else if new_count > N && v.count <= N {
        // Growing, moving from static_array to dynamic_array
        resize(&v.dynamic_array, new_count)
        if v.count > 0 {
            copy(v.dynamic_array[:], v.static_array[:v.count])
        }
    } else if new_count <= N && v.count > N {
        // Shrinking, moving from dynamic_array to static_array
        if new_count > 0 {
            copy(v.static_array[:new_count], v.dynamic_array[:new_count])
        }
        resize(&v.dynamic_array, 0)
        if free_memory {
            shrink(&v.dynamic_array, N)
        }
    } else {
        // Any direction, staying in static_array - nothing to do here
    }
    v.count = new_count
}

small_vector_clear :: proc(
    v: ^Small_Vector($T, $N),
    free_memory := false,
    loc := #caller_location,
) {
    assert(v != nil, loc = loc)
    clear(&v.dynamic_array)
    if free_memory {
        shrink(&v.dynamic_array, N)
    }
    v.count = 0
}

small_vector_insert :: proc(
    v: ^Small_Vector($T, $N),
    index: int,
    src: T,
    loc := #caller_location,
) {
    assert(v != nil, loc = loc)
    assert(index >= 0 && index <= v.count, loc = loc)
    old_count := small_vector_len(v)
    small_vector_resize(v, old_count + 1)
    data_ptr := small_vector_slice(v)
    if index < old_count {
        // Shift [index, old_count) right by one.
        copy(data_ptr[index + 1:], data_ptr[index:old_count])
    }
    data_ptr[index] = src
}

small_vector_remove :: proc(v: ^Small_Vector($T, $N), index: int, loc := #caller_location) {
    assert(v != nil, loc = loc)
    assert(index >= 0 && index < v.count, loc = loc)
    old_count := small_vector_len(v)
    if index < old_count - 1 {
        data_ptr := small_vector_slice(v)
        // Shift [index+1, old_count) left by one.
        copy(data_ptr[index:], data_ptr[index + 1:old_count])
    }
    small_vector_resize(v, old_count - 1)
}
