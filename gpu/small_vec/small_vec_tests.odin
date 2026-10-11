#+build !js
package gpu

import "core:testing"

// Small_Vector(int, 4) is used throughout: N = 4, so index 0..3 lives in
// static_array, and count > 4 forces a move into dynamic_array.

@(test)
test_init_empty :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    testing.expect(t, small_vector_empty(&v))
    testing.expect_value(t, small_vector_len(&v), 0)
}

@(test)
test_push_back_stays_static :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    small_vector_push_back(&v, 10)
    small_vector_push_back(&v, 20)
    small_vector_push_back(&v, 30)

    testing.expect_value(t, small_vector_len(&v), 3)
    testing.expect_value(t, small_vector_get(&v, 0)^, 10)
    testing.expect_value(t, small_vector_get(&v, 1)^, 20)
    testing.expect_value(t, small_vector_get(&v, 2)^, 30)
    testing.expect_value(t, small_vector_front(&v)^, 10)
    testing.expect_value(t, small_vector_back(&v)^, 30)

    // Should still be backed by static_array (count <= N).
    testing.expect(t, v.count <= 4)
}

@(test)
test_push_back_crosses_into_dynamic :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    // Push 6 elements: fills static (N=4) then spills into dynamic.
    for i in 0 ..< 6 {
        small_vector_push_back(&v, i * 10)
    }

    testing.expect_value(t, small_vector_len(&v), 6)
    for i in 0 ..< 6 {
        testing.expect_value(t, small_vector_get(&v, i)^, i * 10)
    }
    testing.expect_value(t, small_vector_front(&v)^, 0)
    testing.expect_value(t, small_vector_back(&v)^, 50)

    // Data from the pre-spill static portion must have been preserved
    // after the move to dynamic_array.
    data := small_vector_slice(&v)
    testing.expect_value(t, len(data), 6)
    testing.expect_value(t, data[3], 30) // was the last static element
    testing.expect_value(t, data[4], 40) // first dynamic-only element
}

@(test)
test_shrink_back_to_static :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 8 {
        small_vector_push_back(&v, i)
    }
    testing.expect_value(t, small_vector_len(&v), 8)

    // Shrink well below N -> should move data back into static_array.
    small_vector_resize(&v, 2)
    testing.expect_value(t, small_vector_len(&v), 2)
    testing.expect_value(t, small_vector_get(&v, 0)^, 0)
    testing.expect_value(t, small_vector_get(&v, 1)^, 1)

    // Grow again from the static state and confirm correctness.
    small_vector_push_back(&v, 99)
    testing.expect_value(t, small_vector_len(&v), 3)
    testing.expect_value(t, small_vector_get(&v, 2)^, 99)
}

@(test)
test_pop_front_and_back :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 5 {     // 5 > N=4, exercises dynamic path too
        small_vector_push_back(&v, i)
    }

    small_vector_pop_back(&v)
    testing.expect_value(t, small_vector_len(&v), 4)
    testing.expect_value(t, small_vector_back(&v)^, 3)

    small_vector_pop_front(&v)
    testing.expect_value(t, small_vector_len(&v), 3)
    testing.expect_value(t, small_vector_front(&v)^, 1)
    testing.expect_value(t, small_vector_get(&v, 1)^, 2)
    testing.expect_value(t, small_vector_get(&v, 2)^, 3)
}

@(test)
test_push_front :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    small_vector_push_back(&v, 1)
    small_vector_push_back(&v, 2)
    small_vector_push_front(&v, 0)

    testing.expect_value(t, small_vector_len(&v), 3)
    testing.expect_value(t, small_vector_get(&v, 0)^, 0)
    testing.expect_value(t, small_vector_get(&v, 1)^, 1)
    testing.expect_value(t, small_vector_get(&v, 2)^, 2)
}

@(test)
test_insert_middle_static :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    small_vector_push_back(&v, 1)
    small_vector_push_back(&v, 2)
    small_vector_push_back(&v, 4)
    small_vector_insert(&v, 2, 3) // [1,2,4] -> [1,2,3,4]

    testing.expect_value(t, small_vector_len(&v), 4)
    expected := [4]int{1, 2, 3, 4}
    for i in 0 ..< 4 {
        testing.expect_value(t, small_vector_get(&v, i)^, expected[i])
    }
}

@(test)
test_insert_crossing_into_dynamic :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 4 {
        small_vector_push_back(&v, i) // [0,1,2,3], still static
    }
    // Insert a 5th element, forcing the static->dynamic move mid-insert.
    small_vector_insert(&v, 2, 99) // [0,1,99,2,3]

    testing.expect_value(t, small_vector_len(&v), 5)
    expected := [5]int{0, 1, 99, 2, 3}
    for i in 0 ..< 5 {
        testing.expect_value(t, small_vector_get(&v, i)^, expected[i])
    }
}

@(test)
test_remove_middle_dynamic :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 7 {
        small_vector_push_back(&v, i) // [0..6], dynamic (7 > N=4)
    }
    small_vector_remove(&v, 3) // remove value 3 -> [0,1,2,4,5,6]

    testing.expect_value(t, small_vector_len(&v), 6)
    expected := [6]int{0, 1, 2, 4, 5, 6}
    for i in 0 ..< 6 {
        testing.expect_value(t, small_vector_get(&v, i)^, expected[i])
    }
}

@(test)
test_remove_last_element_noop_shift :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    small_vector_push_back(&v, 1)
    small_vector_push_back(&v, 2)
    small_vector_push_back(&v, 3)
    small_vector_remove(&v, 2) // remove last, no shift needed

    testing.expect_value(t, small_vector_len(&v), 2)
    testing.expect_value(t, small_vector_get(&v, 0)^, 1)
    testing.expect_value(t, small_vector_get(&v, 1)^, 2)
}

@(test)
test_clear :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 6 {
        small_vector_push_back(&v, i)
    }
    small_vector_clear(&v)

    testing.expect(t, small_vector_empty(&v))
    testing.expect_value(t, small_vector_len(&v), 0)

    // Vector should still be usable after clearing.
    small_vector_push_back(&v, 42)
    testing.expect_value(t, small_vector_get(&v, 0)^, 42)
}

@(test)
test_clear_free_memory :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 10 {
        small_vector_push_back(&v, i)
    }
    small_vector_clear(&v, true)

    testing.expect(t, small_vector_empty(&v))
    testing.expect_value(t, cap(v.dynamic_array), 4)
}

@(test)
test_iteration_via_data :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init(&v, context.temp_allocator)

    for i in 0 ..< 6 {
        small_vector_push_back(&v, i)
    }

    sum := 0
    for item in small_vector_slice(&v) {
        sum += item
    }
    testing.expect_value(t, sum, 0 + 1 + 2 + 3 + 4 + 5)
}

@(test)
test_init_count_preallocates :: proc(t: ^testing.T) {
    v: Small_Vector(int, 4)
    small_vector_init_count(&v, 10, context.temp_allocator)

    testing.expect_value(t, small_vector_len(&v), 10)
    // Values are zero-initialized.
    for i in 0 ..< 10 {
        testing.expect_value(t, small_vector_get(&v, i)^, 0)
    }
}
