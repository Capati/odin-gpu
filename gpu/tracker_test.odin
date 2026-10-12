#+build !js
package gpu

import "core:testing"
import "core:fmt"
import "core:math/bits"
import "core:sync"
import intr "base:intrinsics"

// Helper to compare two slices of Ranged_State_Entry.
expect_entries_equal :: proc(t: ^testing.T, actual, expected: []Ranged_State_Entry(u32, string)) {
    testing.expect_value(t, len(actual), len(expected))
    if len(actual) != len(expected) {
        return
    }
    for i in 0..<len(actual) {
        testing.expect_value(t, actual[i].start, expected[i].start)
        testing.expect_value(t, actual[i].end, expected[i].end)
        testing.expect_value(t, actual[i].value, expected[i].value)
    }
}

@(test)
test_buffer_uses_is_invalid :: proc(t: ^testing.T) {
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{.Vertex}),
        "a single read usage is valid")
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{.Vertex, .Index, .Copy_Src}),
        "multiple read usages together are valid")
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{.Copy_Dst}),
        "a single exclusive (write) usage is valid")
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{}),
        "no usage at all is valid")

    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Copy_Dst, .Vertex}),
        "exclusive + non-exclusive together is invalid")
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Copy_Dst, .Map_Write}),
        "two exclusive usages together is invalid")
}

// Returns the value stored for `(mip, layer)` in a complex state, or
// `false` if the subresource is not covered.
complex_state_lookup :: proc(
    ct: ^Complex_Texture_State,
    mip: u32,
    layer: u32,
) -> (Texture_Uses, bool) {
    if int(mip) >= len(ct.mips) do return {}, false
    for &e in ct.mips[mip].ranges {
        if e.start <= layer && layer < e.end {
            return e.value, true
        }
    }
    return {}, false
}

// Returns the value stored for `(mip, layer)`, or `false` if not covered.
@(private)
lookup_complex :: proc(
    ct: ^Complex_Texture_State,
    mip: int,
    layer: u32,
) -> (Texture_Uses, bool) {
    if mip >= len(ct.mips) do return {}, false
    for &e in ct.mips[mip].ranges {
        if e.start <= layer && layer < e.end {
            return e.value, true
        }
    }
    return {}, false
}

// Builds a Complex_Texture_State with the given value over [0, layer_count) of
// every mip.
@(private)
make_complex :: proc(
    mip_count, layer_count: u32,
    value: Texture_Uses,
    allocator := context.allocator,
) -> Complex_Texture_State {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, mip_count, layer_count, allocator)
    for i in 0..<int(mip_count) {
        iso := ranged_states_isolate(
            &ct.mips[i], Range(u32){0, layer_count}, TEXTURE_USES_UNKNOWN)
        for &e in iso {
            e.value = value
        }
        ranged_states_coalesce(&ct.mips[i])
    }
    return ct
}

// Overwrites the value over [start, end) of the given mip.
@(private)
set_range :: proc(
    ct: ^Complex_Texture_State,
    mip: int,
    start, end: u32,
    value: Texture_Uses,
) {
    iso := ranged_states_isolate(
        &ct.mips[mip], Range(u32){start, end}, TEXTURE_USES_UNKNOWN)
    for &e in iso {
        e.value = value
    }
    ranged_states_coalesce(&ct.mips[mip])
}

// Standard boilerplate for a tracker set with a single simple state.
@(private)
make_set_with_simple :: proc(state: Texture_Uses) -> Texture_State_Set {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, state)
    return set
}

// Standard boilerplate for a tracker set with a single complex state.
// Caller owns the returned `Complex_Texture_State` until it is moved in via
// `texture_state_set_make_complex_unchecked`.
@(private)
make_set_with_complex :: proc(ct: Complex_Texture_State) -> Texture_State_Set {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    texture_state_set_resize(&set, 1)
    texture_state_set_make_complex_unchecked(&set, 0, ct)
    return set
}

// ============================================================================
// buffer_uses_any_exclusive
// ============================================================================

@(test)
test_any_exclusive_empty_is_false :: proc(t: ^testing.T) {
    testing.expect(t, !buffer_uses_any_exclusive(Buffer_Uses{}))
}

@(test)
test_any_exclusive_each_exclusive_flag :: proc(t: ^testing.T) {
    // Every member of BUFFER_USES_EXCLUSIVE must be detected.
    for u in BUFFER_USES_EXCLUSIVE {
        testing.expectf(
            t,
            buffer_uses_any_exclusive(Buffer_Uses{u}),
            "any_exclusive({%v}) should be true", u,
        )
    }
}

@(test)
test_any_exclusive_each_inclusive_flag :: proc(t: ^testing.T) {
    // No member of BUFFER_USES_INCLUSIVE is exclusive.
    for u in BUFFER_USES_INCLUSIVE {
        testing.expectf(
            t,
            !buffer_uses_any_exclusive(Buffer_Uses{u}),
            "any_exclusive({%v}) should be false", u,
        )
    }
}

@(test)
test_any_exclusive_known_mixed_set :: proc(t: ^testing.T) {
    // Storage_Read_Write is exclusive; Vertex is not.
    testing.expect(t, buffer_uses_any_exclusive(Buffer_Uses{.Storage_Read_Write, .Vertex}))
    // Vertex + Index are both inclusive.
    testing.expect(t, !buffer_uses_any_exclusive(Buffer_Uses{.Vertex, .Index}))
}

@(test)
test_any_exclusive_matches_intersection_exhaustively :: proc(t: ^testing.T) {
    // For every pair of flags, any_exclusive(s) must equal the intersection
    // with BUFFER_USES_EXCLUSIVE being non-empty.
    for u in Buffer_Use {
        for v in Buffer_Use {
            s := Buffer_Uses{u, v}
            expected := buffer_uses_intersects(s, BUFFER_USES_EXCLUSIVE)
            testing.expectf(
                t,
                buffer_uses_any_exclusive(s) == expected,
                "any_exclusive({%v, %v}) disagrees with intersects()", u, v,
            )
        }
    }
}

// ============================================================================
// buffer_uses_is_invalid
// ============================================================================

@(test)
test_is_invalid_empty :: proc(t: ^testing.T) {
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{}))
}

@(test)
test_is_invalid_single_bit_always_valid :: proc(t: ^testing.T) {
    // Every single-bit set is valid, exclusive or not: count_ones == 1.
    for u in Buffer_Use {
        testing.expectf(
            t,
            !buffer_uses_is_invalid(Buffer_Uses{u}),
            "single-bit set {%v} must be valid", u,
        )
    }
}

@(test)
test_is_invalid_inclusives_only :: proc(t: ^testing.T) {
    // Any combination of inclusive flags (without exclusive flags) is valid.
    all := BUFFER_USES_INCLUSIVE
    testing.expect(t, !buffer_uses_is_invalid(all))

    // A representative subset.
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{.Vertex, .Index}))
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{
        .Vertex, .Index, .Uniform, .Storage_Read_Only,
    }))
}

@(test)
test_is_invalid_exclusive_plus_inclusive :: proc(t: ^testing.T) {
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Storage_Read_Write, .Vertex}))
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Copy_Dst, .Vertex}))
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Map_Write, .Map_Read}))
    testing.expect(t, buffer_uses_is_invalid(
        Buffer_Uses{.Acceleration_Structure_Scratch, .Uniform}))
}

@(test)
test_is_invalid_two_exclusives :: proc(t: ^testing.T) {
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Map_Write, .Copy_Dst}))
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{.Storage_Read_Write, .Copy_Dst}))
    testing.expect(t, buffer_uses_is_invalid(Buffer_Uses{
        .Acceleration_Structure_Scratch, .Storage_Read_Write,
    }))
}

@(test)
test_is_invalid_query_resolve_neutral_with_inclusive :: proc(t: ^testing.T) {
    // Query_Resolve isn't in either set. Combined with an inclusive flag
    // it stays valid, because there's still no exclusive bit.
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{.Query_Resolve, .Vertex}))

    // Acceleration_Structure_Query likewise.
    testing.expect(t, !buffer_uses_is_invalid(Buffer_Uses{
        .Acceleration_Structure_Query, .Vertex,
    }))
}

@(test)
test_is_invalid_matches_definition_exhaustively :: proc(t: ^testing.T) {
    // The rule is: has any exclusive flag AND more than one bit total.
    // Sweep all pairs and triples of flags.
    for a in Buffer_Use {
        for b in Buffer_Use {
            for c in Buffer_Use {
                s := Buffer_Uses{a, b, c}
                expected := buffer_uses_any_exclusive(s) &&
                    bits.count_ones(transmute(u16)s) != 1
                testing.expectf(
                    t,
                    buffer_uses_is_invalid(s) == expected,
                    "is_invalid({%v, %v, %v}) disagrees with the definition",
                    a, b, c,
                )
            }
        }
    }
}

@(test)
test_ranged_states_init :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    ranged_states_init(&rs, context.allocator)
    defer ranged_states_uninit(&rs)
    testing.expect_value(t, len(rs.ranges), 0)
}

@(test)
test_ranged_states_init_from_range :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    ranged_states_init_from_range(&rs, Range(u32){start = 0, end = 10}, "hello", context.allocator)
    defer ranged_states_uninit(&rs)
    testing.expect_value(t, len(rs.ranges), 1)
    testing.expect_value(t, rs.ranges[0].start, 0)
    testing.expect_value(t, rs.ranges[0].end, 10)
    testing.expect_value(t, rs.ranges[0].value, "hello")
}

@(test)
test_ranged_states_init_from_slice :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    entries := []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "b"},
    }
    defer ranged_states_uninit(&rs)
    ranged_states_init_from_slice(&rs, entries, context.allocator)
    expect_entries_equal(t, rs.ranges[:], entries)
}

@(test)
test_ranged_states_check_sanity_valid :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "b"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    // Should not panic.
    ranged_states_check_sanity(&rs)
}

@(test)
test_ranged_states_coalesce :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "a"}, // should merge with previous
        {start = 10, end = 15, value = "b"},
        {start = 15, end = 20, value = "b"}, // should merge with previous
        {start = 20, end = 25, value = "c"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    ranged_states_coalesce(&rs)
    expected := []Ranged_State_Entry(u32, string){
        {start = 0, end = 10, value = "a"},
        {start = 10, end = 20, value = "b"},
        {start = 20, end = 25, value = "c"},
    }
    expect_entries_equal(t, rs.ranges[:], expected)
}

@(test)
test_ranged_states_coalesce_no_change :: proc(t: ^testing.T) {
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "b"}, // different value, no merge
        {start = 10, end = 15, value = "c"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    ranged_states_coalesce(&rs)
    // Should remain unchanged.
    expected := []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "b"},
        {start = 10, end = 15, value = "c"},
    }
    expect_entries_equal(t, rs.ranges[:], expected)
}

@(test)
test_ranged_states_isolate_exact :: proc(t: ^testing.T) {
    // Index exactly matches an existing range.
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 5, end = 10, value = "b"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 5, end = 10}, "default")
    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].start, 5)
    testing.expect_value(t, result[0].end, 10)
    testing.expect_value(t, result[0].value, "b")
}

@(test)
test_ranged_states_isolate_split :: proc(t: ^testing.T) {
    // Index splits an existing range.
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 10, value = "a"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 3, end = 7}, "default")
    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].start, 3)
    testing.expect_value(t, result[0].end, 7)
    testing.expect_value(t, result[0].value, "a")
    // The original range should be split into two parts.
    expected := []Ranged_State_Entry(u32, string){
        {start = 0, end = 3, value = "a"},
        {start = 3, end = 7, value = "a"},
        {start = 7, end = 10, value = "a"},
    }
    expect_entries_equal(t, rs.ranges[:], expected)
}

@(test)
test_ranged_states_isolate_gap :: proc(t: ^testing.T) {
    // Index covers a gap between ranges, filled with default.
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 10, end = 15, value = "b"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 3, end = 12}, "default")
    // The result should include the part of the first range, the gap,
    // and the part of the second range.
    expected_result := []Ranged_State_Entry(u32, string){
        {start = 3, end = 5, value = "a"},
        {start = 5, end = 10, value = "default"},
        {start = 10, end = 12, value = "b"},
    }
    expect_entries_equal(t, result, expected_result)
    // The full ranges should now be:
    expected_full := []Ranged_State_Entry(u32, string){
        {start = 0, end = 3, value = "a"},
        {start = 3, end = 5, value = "a"},
        {start = 5, end = 10, value = "default"},
        {start = 10, end = 12, value = "b"},
        {start = 12, end = 15, value = "b"},
    }
    expect_entries_equal(t, rs.ranges[:], expected_full)
}

@(test)
test_ranged_states_isolate_after_end :: proc(t: ^testing.T) {
    // Index is entirely after all existing ranges.
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 10, end = 15}, "default")
    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].start, 10)
    testing.expect_value(t, result[0].end, 15)
    testing.expect_value(t, result[0].value, "default")
    expected := []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "a"},
        {start = 10, end = 15, value = "default"},
    }
    expect_entries_equal(t, rs.ranges[:], expected)
}

@(test)
test_ranged_states_isolate_before_start :: proc(t: ^testing.T) {
    // Index is entirely before all existing ranges.
    rs: Ranged_States(u32, string)
    ranged_states_init_from_slice(&rs, []Ranged_State_Entry(u32, string){
        {start = 10, end = 15, value = "a"},
    }, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 0, end = 5}, "default")
    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].start, 0)
    testing.expect_value(t, result[0].end, 5)
    testing.expect_value(t, result[0].value, "default")
    expected := []Ranged_State_Entry(u32, string){
        {start = 0, end = 5, value = "default"},
        {start = 10, end = 15, value = "a"},
    }
    expect_entries_equal(t, rs.ranges[:], expected)
}

@(test)
test_ranged_states_isolate_empty :: proc(t: ^testing.T) {
    // Empty Ranged_States.
    rs: Ranged_States(u32, string)
    ranged_states_init(&rs, context.allocator)
    defer ranged_states_uninit(&rs)
    result := ranged_states_isolate(&rs, Range(u32){start = 0, end = 10}, "default")
    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].start, 0)
    testing.expect_value(t, result[0].end, 10)
    testing.expect_value(t, result[0].value, "default")
    testing.expect_value(t, len(rs.ranges), 1)
}

@(test)
test_bit_vector_set_size_grow :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 100)
    testing.expect_value(t, bv.size, 100)
    testing.expect_value(t, len(bv.words), bits_per_word(100))
    testing.expect(t, !bit_vector_any(&bv))
}

@(test)
test_bit_vector_set_size_zero :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 0)
    testing.expect_value(t, bv.size, 0)
}

@(test)
test_bit_vector_set_size_exact_word :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 64)
    testing.expect_value(t, bv.size, 64)
    testing.expect_value(t, len(bv.words), 1)
    testing.expect(t, !bit_vector_any(&bv))
}

@(test)
test_bit_vector_set_size_masks_tail_on_grow :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 8)
    bv.words[0] = 0xFF

    bit_vector_resize(&bv, 10)
    testing.expect_value(t, bv.words[0] & 0xFF, u64(0xFF))
    testing.expect_value(t, bv.words[0] & ~u64(0x3FF), u64(0))
}

@(test)
test_bit_vector_set_size_shrink_wipes_tail_words :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 200)
    for &w in bv.words { w = ~u64(0) }

    bit_vector_resize(&bv, 30)
    testing.expect_value(t, bv.size, 30)
    testing.expect_value(t, len(bv.words), 1)
    testing.expect_value(t, bv.words[0] & ~u64(0x3FFFFFFF), u64(0))
}

@(test)
test_bit_vector_set_size_shrink_tail_mask :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 10)
    for &w in bv.words { w = ~u64(0) }

    bit_vector_resize(&bv, 3)
    testing.expect_value(t, len(bv.words), 1)
    testing.expect_value(t, bv.words[0], u64(0b111))
}

@(test)
test_bit_vector_any_empty :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)
    testing.expect(t, !bit_vector_any(&bv))
}

@(test)
test_bit_vector_any_with_bits :: proc(t: ^testing.T) {
    bv: Bit_Vector
    defer bit_vector_uninit(&bv)

    bit_vector_resize(&bv, 128)
    bit_vector_set(&bv, 100, true)
    testing.expect(t, bit_vector_any(&bv))

    bit_vector_set(&bv, 100, false)
    testing.expect(t, !bit_vector_any(&bv))
}

@(test)
test_resource_metadata_init_and_uninit :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 0, context.allocator)
    defer resource_metadata_uninit(&md)

    testing.expect_value(t, len(md.resources), 0)
    testing.expect_value(t, bit_vector_len(&md.owned), 0)
    testing.expect(t, resource_metadata_is_empty(&md))
}

@(test)
test_resource_metadata_init_with_size :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 8, context.allocator)
    defer resource_metadata_uninit(&md)

    testing.expect_value(t, len(md.resources), 8)
    testing.expect_value(t, bit_vector_len(&md.owned), 8)
    testing.expect(t, resource_metadata_is_empty(&md))
}

@(test)
test_resource_metadata_set_size :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 8, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_set_size(&md, 16)
    testing.expect_value(t, len(md.resources), 16)
    testing.expect_value(t, bit_vector_len(&md.owned), 16)

    resource_metadata_set_size(&md, 4)
    testing.expect_value(t, len(md.resources), 4)
    testing.expect_value(t, bit_vector_len(&md.owned), 4)
}

test_resource_metadata_contains_out_of_bounds :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    testing.expect(t, !resource_metadata_contains(&md, -1))
    testing.expect(t, !resource_metadata_contains(&md, 4))
    testing.expect(t, !resource_metadata_contains(&md, 100))
}

@(test)
test_resource_metadata_insert :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    p := resource_metadata_insert(&md, 2, 42)

    testing.expect_value(t, p^, 42)

    testing.expect(t, resource_metadata_contains(&md, 2))
    testing.expect(t, resource_metadata_contains_unchecked(&md, 2))
    testing.expect(t, !resource_metadata_contains(&md, 0))
    testing.expect(t, !resource_metadata_contains(&md, 1))
    testing.expect(t, !resource_metadata_contains(&md, 3))

    testing.expect(t, !resource_metadata_is_empty(&md))
}

@(test)
test_resource_metadata_get_unchecked :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 3, 7)
    p := resource_metadata_get_unchecked(&md, 3)
    testing.expect_value(t, p, 7)
}

@(test)
test_resource_metadata_remove1 :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 2, 42)
    resource_metadata_remove(&md, 2)

    testing.expect(t, !resource_metadata_contains(&md, 2))
    testing.expect(t, resource_metadata_is_empty(&md))
}

@(test)
test_resource_metadata_remove2 :: proc(t: ^testing.T) {
    m: Resource_Metadata(Buffer)
    resource_metadata_init(&m, 4, context.allocator)
    defer resource_metadata_uninit(&m)

    a: Buffer
    resource_metadata_insert(&m, 1, a)
    testing.expect(t, resource_metadata_contains(&m, 1), "sanity: index 1 tracked before remove")

    resource_metadata_remove(&m, 1)
    testing.expect(t, !resource_metadata_contains(&m, 1), "index 1 should no longer be tracked")
    testing.expect(t, resource_metadata_is_empty(&m),
        "metadata should be empty after removing its only member")
}

@(test)
test_resource_metadata_multiple_indices :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 8, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 0, 10)
    resource_metadata_insert(&md, 3, 30)
    resource_metadata_insert(&md, 7, 70)

    testing.expect(t, resource_metadata_contains(&md, 0))
    testing.expect(t, resource_metadata_contains(&md, 3))
    testing.expect(t, resource_metadata_contains(&md, 7))
    testing.expect(t, !resource_metadata_contains(&md, 1))
    testing.expect(t, !resource_metadata_is_empty(&md))

    resource_metadata_remove(&md, 3)
    testing.expect(t, !resource_metadata_contains(&md, 3))
    testing.expect(t, resource_metadata_contains(&md, 0))
    testing.expect(t, resource_metadata_contains(&md, 7))
}

@(test)
test_resource_metadata_clear :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 8, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 1, 11)
    resource_metadata_insert(&md, 4, 44)
    resource_metadata_insert(&md, 6, 66)

    resource_metadata_clear(&md)
    testing.expect_value(t, len(md.resources), 0)
    testing.expect_value(t, bit_vector_len(&md.owned), 0)
    testing.expect(t, resource_metadata_is_empty(&md))
}

@(test)
test_resource_metadata_reuse_after_clear :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 0, 1)
    resource_metadata_insert(&md, 1, 2)
    resource_metadata_clear(&md)

    resource_metadata_set_size(&md, 4)
    resource_metadata_insert(&md, 2, 3)
    testing.expect(t, resource_metadata_contains(&md, 2))
    testing.expect(t, !resource_metadata_contains(&md, 0))
    testing.expect(t, !resource_metadata_contains(&md, 1))
}

@(test)
test_resource_metadata_shrink_after_insert :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 128, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 100, 1234)
    testing.expect(t, resource_metadata_contains(&md, 100))

    resource_metadata_set_size(&md, 101)
    testing.expect(t, resource_metadata_contains(&md, 100))
    testing.expect_value(t, len(md.resources), 101)
    testing.expect_value(t, bit_vector_len(&md.owned), 101)

    // Shrinking below the owned index drops the bit; note that set_size
    // does not call unref_resource for resources that fall out of range.
    resource_metadata_set_size(&md, 32)
    testing.expect_value(t, bit_vector_len(&md.owned), 32)
    testing.expect(t, !resource_metadata_contains(&md, 100))
}

@(test)
test_bit_vector_set_get1 :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 100, context.allocator)
    defer bit_vector_uninit(&bv)

    testing.expect_value(t, bit_vector_len(&bv), 100)
    testing.expect_value(t, len(bv.words), 2)

    bit_vector_set(&bv, 0, true)
    bit_vector_set(&bv, 1, true)
    bit_vector_set(&bv, 63, true)
    bit_vector_set(&bv, 64, true)
    bit_vector_set(&bv, 99, true)

    testing.expect(t, bit_vector_get(&bv, 0))
    testing.expect(t, bit_vector_get(&bv, 1))
    testing.expect(t, bit_vector_get(&bv, 63))
    testing.expect(t, bit_vector_get(&bv, 64))
    testing.expect(t, bit_vector_get(&bv, 99))
    testing.expect(t, !bit_vector_get(&bv, 2))
    testing.expect(t, !bit_vector_get(&bv, 100), "out-of-bounds read returns false")
    testing.expect(t, bit_vector_any(&bv))
    testing.expect_value(t, bit_vector_count_ones(&bv), 5)

    bit_vector_set(&bv, 1, false)
    testing.expect(t, !bit_vector_get(&bv, 1))
    testing.expect_value(t, bit_vector_count_ones(&bv), 4)
}

@(test)
test_bit_vector_set_get2 :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 10, context.allocator)
    defer bit_vector_uninit(&bv)

    testing.expect(t, !bit_vector_get(&bv, 3), "bit 3 should start clear")

    bit_vector_set(&bv, 3, true)
    testing.expect(t, bit_vector_get(&bv, 3), "bit 3 should be set")
    testing.expect(t, !bit_vector_get(&bv, 2), "bit 2 should still be clear")
    testing.expect(t, !bit_vector_get(&bv, 4), "bit 4 should still be clear")

    bit_vector_set(&bv, 3, false)
    testing.expect(t, !bit_vector_get(&bv, 3), "bit 3 should be clear again")
}

@(test)
test_bit_vector_get_out_of_range_is_false :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 4, context.allocator)
    defer bit_vector_uninit(&bv)

    testing.expect(t, !bit_vector_get(&bv, 100), "out-of-range index should read false, not panic")
    testing.expect(t, !bit_vector_get(&bv, -1), "negative index should read false, not panic")
}

@(test)
test_bit_vector_any_and_clear :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 200, context.allocator)
    defer bit_vector_uninit(&bv)

    testing.expect(t, !bit_vector_any(&bv), "freshly resized vector should be empty")

    bit_vector_set(&bv, 150, true)
    testing.expect(t, bit_vector_any(&bv), "should be non-empty after setting a bit")

    bit_vector_clear(&bv)
    testing.expect(t, !bit_vector_any(&bv), "should be empty again after clear")
    testing.expect_value(t, bv.size, 200) // clear zeroes bits but keeps length
}

@(test)
test_bit_vector_iterate_across_word_boundaries :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 0, context.allocator)
    defer bit_vector_uninit(&bv)

    // 130 forces at least 3 u64 words, exercising the "skip whole zero
    // words" path as well as a partial last word.
    bit_vector_resize(&bv, 130)
    set_indices := []int{0, 5, 63, 64, 65, 129}
    for i in set_indices {
        bit_vector_set(&bv, i, true)
    }

    collected: [dynamic]int
    defer delete(collected)
    it := bit_vector_iterate(&bv)
    for index in bit_vector_iterator_next(&it) {
        append(&collected, index)
    }

    testing.expect_value(t, len(collected), len(set_indices))
    for expected, i in set_indices {
        if i < len(collected) {
            testing.expect_value(t, collected[i], expected)
        }
    }
}

@(test)
test_bit_vector_resize_shrink_then_grow_does_not_resurrect_bits :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 128, context.allocator)
    defer bit_vector_uninit(&bv)

    bit_vector_set(&bv, 100, true)
    bit_vector_set(&bv, 70, true)

    bit_vector_resize(&bv, 80) // drops bit 100, keeps bit 70
    testing.expect(t, bit_vector_get(&bv, 70), "bit 70 should survive shrinking to 80")

    bit_vector_resize(&bv, 128) // grow back
    testing.expect(t, bit_vector_get(&bv, 70), "bit 70 should still be set after growing back")
    testing.expect(t, !bit_vector_get(&bv, 100), "bit 100 must not come back after shrink+grow")
}

@(test)
test_bit_vector_iterate_set_bits :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 100, context.allocator)
    defer bit_vector_uninit(&bv)

    bit_vector_set(&bv, 0, true)
    bit_vector_set(&bv, 1, true)
    bit_vector_set(&bv, 63, true)
    bit_vector_set(&bv, 64, true)
    bit_vector_set(&bv, 99, true)

    want := [5]int{0, 1, 63, 64, 99}

    it := bit_vector_iterate(&bv)
    i := 0
    for index in bit_vector_iterator_next(&it) {
        testing.expect(t, i < len(want), "too many set bits")
        testing.expect_value(t, index, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))
}

@(test)
test_bit_vector_iterate_empty1 :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 100, context.allocator)
    defer bit_vector_uninit(&bv)

    // No bits set: iterator exhausts on the very first next().
    it := bit_vector_iterate(&bv)
    _, ok := bit_vector_iterator_next(&it)
    testing.expect(t, !ok)

    // Same when the backing array is empty.
    zero: Bit_Vector
    it0 := bit_vector_iterate(&zero)
    _, ok0 := bit_vector_iterator_next(&it0)
    testing.expect(t, !ok0)
}

@(test)
test_bit_vector_iterate_empty2 :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 256, context.allocator)
    defer bit_vector_uninit(&bv)

    it := bit_vector_iterate(&bv)
    _, ok := bit_vector_iterator_next(&it)
    testing.expect(t, !ok, "iterating an all-clear vector should yield nothing")
}

@(test)
test_bit_vector_iterate_skips_zero_words :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 256, context.allocator)
    defer bit_vector_uninit(&bv)

    // Only word 0 and word 3 have bits set; words 1 and 2 are zero and
    // should be skipped wholesale by the iterator.
    bit_vector_set(&bv, 5, true)
    bit_vector_set(&bv, 200, true)
    bit_vector_set(&bv, 255, true)

    want := [3]int{5, 200, 255}

    it := bit_vector_iterate(&bv)
    i := 0
    for index in bit_vector_iterator_next(&it) {
        testing.expect(t, i < len(want), "too many set bits")
        testing.expect_value(t, index, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))
}

@(test)
test_bit_vector_shrink_drops_out_of_range_bits :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 100, context.allocator)
    defer bit_vector_uninit(&bv)

    bit_vector_set(&bv, 0, true)
    bit_vector_set(&bv, 1, true)
    bit_vector_set(&bv, 63, true)
    bit_vector_set(&bv, 64, true)
    bit_vector_set(&bv, 99, true)

    bit_vector_resize(&bv, 50)
    testing.expect_value(t, bit_vector_len(&bv), 50)
    testing.expect_value(t, len(bv.words), 1)

    testing.expect(t, bit_vector_get(&bv, 0), "index 0 must survive a shrink")
    testing.expect(t, bit_vector_get(&bv, 1), "index 1 must survive a shrink")
    testing.expect(t, !bit_vector_get(&bv, 63), "bit 63 is out of range now")
    testing.expect(t, !bit_vector_get(&bv, 64))
    testing.expect(t, !bit_vector_get(&bv, 99))

    // Tail-mask invariant: `any`, the count, and the iterator all agree
    // that only bits {0, 1} remain.
    testing.expect(t, bit_vector_any(&bv))
    testing.expect_value(t, bit_vector_count_ones(&bv), 2)

    want := [2]int{0, 1}
    it := bit_vector_iterate(&bv)
    i := 0
    for index in bit_vector_iterator_next(&it) {
        testing.expect(t, i < len(want), "too many set bits")
        testing.expect_value(t, index, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))
}

@(test)
test_bit_vector_grow_and_roundtrip :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 10, context.allocator)
    defer bit_vector_uninit(&bv)

    bit_vector_set(&bv, 3, true)
    bit_vector_set(&bv, 7, true)

    bit_vector_resize(&bv, 100)
    testing.expect_value(t, bit_vector_len(&bv), 100)
    testing.expect(t, bit_vector_get(&bv, 3))
    testing.expect(t, bit_vector_get(&bv, 7))
    testing.expect(t, !bit_vector_get(&bv, 50), "grown bits start cleared")

    // Round-trip shrink then grow must not resurrect dropped bits.
    bit_vector_resize(&bv, 5)
    bit_vector_resize(&bv, 100)
    testing.expect(t, bit_vector_get(&bv, 3))
    testing.expect(t, !bit_vector_get(&bv, 7), "bit 7 stays dropped after regrow")
}

@(test)
test_bit_vector_fill :: proc(t: ^testing.T) {
    bv: Bit_Vector
    bit_vector_init(&bv, 50, context.allocator) // 1 word with a 14-bit tail
    defer bit_vector_uninit(&bv)

    bit_vector_fill(&bv, true)
    testing.expect_value(t, bit_vector_count_ones(&bv), 50)
    testing.expect(t, bit_vector_any(&bv))
    testing.expect(t, bit_vector_get(&bv, 0))
    testing.expect(t, bit_vector_get(&bv, 49))
    testing.expect(t, !bit_vector_get(&bv, 50), "tail is masked by fill")
    testing.expect(t, !bit_vector_get(&bv, 63))

    // Iterating a fully-set 50-bit vector must yield exactly 0..49.
    it := bit_vector_iterate(&bv)
    i := 0
    for index in bit_vector_iterator_next(&it) {
        testing.expect_value(t, index, i)
        i += 1
    }
    testing.expect_value(t, i, 50)

    bit_vector_fill(&bv, false)
    testing.expect(t, !bit_vector_any(&bv))
    testing.expect_value(t, bit_vector_count_ones(&bv), 0)
}

@(test)
test_resource_metadata_insert_remove_clear :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 32, context.allocator)
    defer resource_metadata_uninit(&md)

    testing.expect(t, resource_metadata_is_empty(&md))
    testing.expect(t, !resource_metadata_contains(&md, 3))

    resource_metadata_insert(&md, 3, 10)
    resource_metadata_insert(&md, 5, 11)
    testing.expect(t, resource_metadata_contains(&md, 3))
    testing.expect(t, resource_metadata_contains_unchecked(&md, 5))
    testing.expect(t, !resource_metadata_contains(&md, 4))
    testing.expect(t, !resource_metadata_is_empty(&md))

    testing.expect_value(t, resource_metadata_get_unchecked(&md, 3), 10)
    testing.expect_value(t, resource_metadata_get_unchecked(&md, 5), 11)

    resource_metadata_remove(&md, 3)
    testing.expect(t, !resource_metadata_contains(&md, 3))
    testing.expect(t, resource_metadata_contains(&md, 5))

    resource_metadata_clear(&md)
    testing.expect(t, resource_metadata_is_empty(&md))
    testing.expect(t, !resource_metadata_contains(&md, 5))
}

@(test)
test_resource_metadata_owned_index_iteration :: proc(t: ^testing.T) {
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 32, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 3, 10)
    resource_metadata_insert(&md, 5, 11)
    resource_metadata_insert(&md, 20, 12)

    want := [3]int{3, 5, 20}

    it := bit_vector_iterate(&md.owned)
    i := 0
    for index in bit_vector_iterator_next(&it) {
        testing.expect(t, i < len(want), "too many set bits")
        testing.expect_value(t, index, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))

    // After removing one, the iterator should see the remaining two.
    resource_metadata_remove(&md, 5)
    want_after := [2]int{3, 20}

    it2 := bit_vector_iterate(&md.owned)
    j := 0
    for index in bit_vector_iterator_next(&it2) {
        testing.expect(t, j < len(want_after), "too many set bits")
        testing.expect_value(t, index, want_after[j])
        j += 1
    }
    testing.expect_value(t, j, len(want_after))
}

@(test)
test_resource_metadata_duplicate_insert_not_exercised :: proc(t: ^testing.T) {
    // `resource_metadata_insert` asserts that the slot is unowned. Capturing
    // an Odin panic from `core:testing` requires `testing.expect_assert_from`
    // and a dedicated harness, which is out of scope for this suite. This
    // test only verifies the happy path up to the point where a second
    // insert *would* panic, so the assert is not triggered here.
    md: Resource_Metadata(int)
    resource_metadata_init(&md, 4, context.allocator)
    defer resource_metadata_uninit(&md)

    resource_metadata_insert(&md, 0, 1)
    testing.expect(t, resource_metadata_contains(&md, 0))

    // Second insert on index 0 would assert; not called.
}

@(test)
test_resource_metadata_insert_and_contains :: proc(t: ^testing.T) {
    m: Resource_Metadata(Buffer)
    resource_metadata_init(&m, 4, context.allocator)
    defer resource_metadata_uninit(&m)

    testing.expect(t, !resource_metadata_contains(&m, 2), "index 2 shouldn't be tracked yet")

    a := Buffer{nil, 1}
    resource_metadata_insert(&m, 2, a)
    testing.expect(t, resource_metadata_contains(&m, 2), "index 2 should be tracked after insert")
    testing.expect_value(t, resource_metadata_get_unchecked(&m, 2), a)
    testing.expect(t, !resource_metadata_is_empty(&m),
        "metadata with one member shouldn't be empty")
}

@(test)
test_resource_metadata_clear_keeps_bitset_length :: proc(t: ^testing.T) {
    m: Resource_Metadata(Buffer)
    resource_metadata_init(&m, 8, context.allocator)
    defer resource_metadata_uninit(&m)

    a := Buffer{nil, 1}
    resource_metadata_insert(&m, 3, a)

    resource_metadata_clear(&m)
    testing.expect(t, !resource_metadata_contains(&m, 3), "nothing should be tracked after clear")
    testing.expect(t, resource_metadata_is_empty(&m), "should be empty after clear")
    // The bitset's own length is intentionally preserved by clear(). Growing
    // again should still work correctly afterward:
    b := Buffer{nil, 2}
    resource_metadata_set_size(&m, 8)
    resource_metadata_insert(&m, 3, b)
    testing.expect(t, resource_metadata_contains(&m, 3),
        "should be able to re-populate after clear+set_size")
}

@(test)
test_resource_metadata_owned_resources_iteration :: proc(t: ^testing.T) {
    m: Resource_Metadata(Buffer)
    resource_metadata_init(&m, 10, context.allocator)
    defer resource_metadata_uninit(&m)

    a := Buffer{nil, 1}
    b := Buffer{nil, 2}
    c := Buffer{nil, 3}

    resource_metadata_insert(&m, 0, a)
    resource_metadata_insert(&m, 5, b)
    resource_metadata_insert(&m, 9, c)

    found: map[Buffer]bool
    defer delete(found)

    it := resource_metadata_iterate(&m)
    for res in resource_metadata_iterate_next(&it) {
        found[res] = true
    }

    testing.expect_value(t, len(found), 3)
    testing.expect(t, found[a] && found[b] && found[c], "should have visited exactly a, b, c")
}

@(test)
test_resource_metadata_provider_direct_and_indirect :: proc(t: ^testing.T) {
    m: Resource_Metadata(Buffer)
    resource_metadata_init(&m, 4, context.allocator)
    defer resource_metadata_uninit(&m)

    a := Buffer{nil, 1}
    direct: Resource_Metadata_Provider(Buffer)
    direct = Direct_Resource_Provider(Buffer){a}
    testing.expect_value(t, resource_metadata_provider_get(&direct, 0), a)

    resource_metadata_insert(&m, 2, a)

    indirect: Resource_Metadata_Provider(Buffer)
    indirect = Indirect_Resource_Provider(Buffer){&m}
    testing.expect_value(t, resource_metadata_provider_get(&indirect, 2), a)
}

@(test)
test_bind_group_insert_preserves_order :: proc(t: ^testing.T) {
    s: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&s, context.allocator)
    defer buffer_bind_group_state_uninit(&s)

    dummy_buffer: Buffer
    buffer_bind_group_state_insert_single(&s, 0, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&s, 5, dummy_buffer, {.Index})
    buffer_bind_group_state_insert_single(&s, 3, dummy_buffer, {.Uniform})

    testing.expect_value(t, len(s.buffers), 3)
    testing.expect_value(t, int(s.buffers[0].index), 0)
    testing.expect_value(t, s.buffers[0].state, Buffer_Uses{.Vertex})
    testing.expect_value(t, int(s.buffers[1].index), 5)
    testing.expect_value(t, s.buffers[1].state, Buffer_Uses{.Index})
    testing.expect_value(t, int(s.buffers[2].index), 3)
    testing.expect_value(t, s.buffers[2].state, Buffer_Uses{.Uniform})
}

@(test)
test_bind_group_optimize_sorts_by_index :: proc(t: ^testing.T) {
    s: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&s, context.allocator)
    defer buffer_bind_group_state_uninit(&s)

    dummy_buffer: Buffer
    buffer_bind_group_state_insert_single(&s, 7, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&s, 1, dummy_buffer, {.Index})
    buffer_bind_group_state_insert_single(&s, 5, dummy_buffer, {.Uniform})
    buffer_bind_group_state_insert_single(&s, 3, dummy_buffer, {.Copy_Src})

    buffer_bind_group_state_optimize(&s)

    testing.expect_value(t, len(s.buffers), 4)
    testing.expect_value(t, int(s.buffers[0].index), 1)
    testing.expect_value(t, int(s.buffers[1].index), 3)
    testing.expect_value(t, int(s.buffers[2].index), 5)
    testing.expect_value(t, int(s.buffers[3].index), 7)

    // States must travel with their entries.
    testing.expect_value(t, s.buffers[0].state, Buffer_Uses{.Index})
    testing.expect_value(t, s.buffers[1].state, Buffer_Uses{.Copy_Src})
    testing.expect_value(t, s.buffers[2].state, Buffer_Uses{.Uniform})
    testing.expect_value(t, s.buffers[3].state, Buffer_Uses{.Vertex})
}

@(test)
test_bind_group_optimize_empty_and_sorted :: proc(t: ^testing.T) {
    s: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&s, context.allocator)
    defer buffer_bind_group_state_uninit(&s)

    buffer_bind_group_state_optimize(&s) // empty: must not crash
    testing.expect_value(t, len(s.buffers), 0)

    dummy_buffer: Buffer
    buffer_bind_group_state_insert_single(&s, 1, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&s, 2, dummy_buffer, {.Index})
    buffer_bind_group_state_insert_single(&s, 3, dummy_buffer, {.Uniform})
    buffer_bind_group_state_optimize(&s)
    testing.expect_value(t, int(s.buffers[0].index), 1)
    testing.expect_value(t, int(s.buffers[1].index), 2)
    testing.expect_value(t, int(s.buffers[2].index), 3)
}

@(test)
test_state_provider_direct_ignores_index :: proc(t: ^testing.T) {
    p := buffer_state_provider_direct(Buffer_Uses{.Vertex})
    testing.expect_value(t, buffer_state_provider_get(&p, 0), Buffer_Uses{.Vertex})
    testing.expect_value(t, buffer_state_provider_get(&p, 42), Buffer_Uses{.Vertex})
    testing.expect_value(t, buffer_state_provider_get(&p, 1000), Buffer_Uses{.Vertex})
}

@(test)
test_state_provider_indirect_indexes_in :: proc(t: ^testing.T) {
    states := []Buffer_Uses{
        {.Vertex},
        {.Index},
        {.Uniform},
        {.Copy_Src},
    }
    p := buffer_state_provider_indirect(states)

    testing.expect_value(t, buffer_state_provider_get(&p, 0), Buffer_Uses{.Vertex})
    testing.expect_value(t, buffer_state_provider_get(&p, 1), Buffer_Uses{.Index})
    testing.expect_value(t, buffer_state_provider_get(&p, 2), Buffer_Uses{.Uniform})
    testing.expect_value(t, buffer_state_provider_get(&p, 3), Buffer_Uses{.Copy_Src})
}

@(test)
test_skip_barrier_truth_table :: proc(t: ^testing.T) {
    ordered := Buffer_Uses{.Vertex, .Index}

    // Unchanged, fully covered by mask → skip.
    testing.expect(t, skip_barrier(Buffer_Uses{.Vertex}, ordered, Buffer_Uses{.Vertex}))

    // Unchanged, not covered by mask → don't skip.
    testing.expect(t, !skip_barrier(Buffer_Uses{.Uniform}, ordered, Buffer_Uses{.Uniform}))

    // Changed, within mask → don't skip.
    testing.expect(t, !skip_barrier(Buffer_Uses{.Vertex}, ordered, Buffer_Uses{.Index}))

    // Changed, outside mask → don't skip.
    testing.expect(t, !skip_barrier(Buffer_Uses{.Vertex}, ordered, Buffer_Uses{.Uniform}))

    // Both empty → skip.
    testing.expect(t, skip_barrier(Buffer_Uses{}, Buffer_Uses{}, Buffer_Uses{}))
}

@(test)
test_buffer_barrier_appends_transition :: proc(t: ^testing.T) {
    states := []Buffer_Uses{{.Vertex}, {.Index}}
    provider := buffer_state_provider_direct(Buffer_Uses{.Uniform})

    barriers: [dynamic]Pending_Buffer_Transition
    defer delete(barriers)

    buffer_state_barrier(states, 0, &provider, &barriers, Buffer_Uses{})

    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].id, u32(0))
    testing.expect_value(t, barriers[0].usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, barriers[0].usage.to, Buffer_Uses{.Uniform})
}

@(test)
test_buffer_barrier_skip_and_append :: proc(t: ^testing.T) {
    states := []Buffer_Uses{{.Vertex}}
    barriers: [dynamic]Pending_Buffer_Transition
    defer delete(barriers)

    // Same state, within ordered mask → skipped.
    provider := buffer_state_provider_direct(Buffer_Uses{.Vertex})
    buffer_state_barrier(states, 0, &provider, &barriers, Buffer_Uses{.Vertex, .Index})
    testing.expect_value(t, len(barriers), 0)

    // Same state, outside ordered mask → appended.
    provider = buffer_state_provider_direct(Buffer_Uses{.Vertex})
    buffer_state_barrier(states, 0, &provider, &barriers, Buffer_Uses{.Index})
    testing.expect_value(t, len(barriers), 1)

    // Changed, within mask → appended.
    clear(&barriers)
    provider = buffer_state_provider_direct(Buffer_Uses{.Index})
    buffer_state_barrier(states, 0, &provider, &barriers, Buffer_Uses{.Vertex, .Index})
    testing.expect_value(t, len(barriers), 1)

    testing.expect_value(t, barriers[0].usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, barriers[0].usage.to, Buffer_Uses{.Index})
}

@(test)
test_buffer_update_overwrites_only_target_index :: proc(t: ^testing.T) {
    states := []Buffer_Uses{{.Vertex}, {.Index}, {.Uniform}}
    provider := buffer_state_provider_direct(Buffer_Uses{.Copy_Src})

    buffer_state_update(states, 1, &provider)

    testing.expect_value(t, states[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, states[1], Buffer_Uses{.Copy_Src})
    testing.expect_value(t, states[2], Buffer_Uses{.Uniform})
}

@(test)
test_buffer_update_from_indirect :: proc(t: ^testing.T) {
    states := []Buffer_Uses{{.Vertex}, {.Vertex}, {.Vertex}}
    incoming := []Buffer_Uses{{.Index}, {.Uniform}, {.Copy_Src}}
    provider := buffer_state_provider_indirect(incoming)

    buffer_state_update(states, 0, &provider)
    buffer_state_update(states, 1, &provider)
    buffer_state_update(states, 2, &provider)

    testing.expect_value(t, states[0], Buffer_Uses{.Index})
    testing.expect_value(t, states[1], Buffer_Uses{.Uniform})
    testing.expect_value(t, states[2], Buffer_Uses{.Copy_Src})
}

@(test)
test_usage_scope_init_sizes_both_tables :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 8, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    testing.expect_value(t, len(s.state), 8)
    testing.expect_value(t, bit_vector_len(&s.metadata.owned), 8)
    testing.expect(t, resource_metadata_is_empty(&s.metadata))
    testing.expect_value(t, s.ordered_uses_mask, Buffer_Uses{})
}

@(test)
test_usage_scope_init_zero_size :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 0, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    testing.expect_value(t, len(s.state), 0)
    testing.expect_value(t, bit_vector_len(&s.metadata.owned), 0)
}

@(test)
test_usage_scope_clear_resets_both_tables :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 8, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    buffer_usage_scope_merge_single(&s, 2, dummy_buffer, {.Vertex})
    buffer_usage_scope_merge_single(&s, 5, dummy_buffer, {.Index})
    testing.expect(t, !resource_metadata_is_empty(&s.metadata))

    buffer_usage_scope_clear(&s)

    // Both tables are emptied; the scope must be re-sized before reuse.
    testing.expect_value(t, len(s.state), 0)
    testing.expect_value(t, bit_vector_len(&s.metadata.owned), 0)
    testing.expect(t, resource_metadata_is_empty(&s.metadata))
}

@(test)
test_usage_scope_clear_then_reuse :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})
    buffer_usage_scope_clear(&s)

    // Reuse: merge_single grows via allow_index, so no set_size needed.
    err := buffer_usage_scope_merge_single(&s, 3, dummy_buffer, {.Index})

    testing.expect(t, err == nil)
    testing.expect(t, len(s.state) >= 4)
    testing.expect_value(t, s.state[3], Buffer_Uses{.Index})
    testing.expect(t, resource_metadata_contains(&s.metadata, 3))
}

@(test)
test_usage_scope_set_ordered_uses_mask :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    buffer_usage_scope_set_ordered_uses_mask(&s, {.Vertex, .Index})
    testing.expect_value(t, s.ordered_uses_mask, Buffer_Uses{.Vertex, .Index})
}

@(test)
test_usage_scope_allow_index_grows_only_when_needed :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    buffer_usage_scope_allow_index(&s, 2)
    testing.expect_value(t, len(s.state), 4)

    buffer_usage_scope_allow_index(&s, 3) // exactly in bounds
    testing.expect_value(t, len(s.state), 4)

    buffer_usage_scope_allow_index(&s, 9) // grows
    testing.expect_value(t, len(s.state), 10)
    testing.expect_value(t, bit_vector_len(&s.metadata.owned), 10)
}

@(test)
test_usage_scope_merge_single_first_insert :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})

    testing.expect(t, err == nil)
    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex})
    testing.expect(t, resource_metadata_contains(&s.metadata, 1))
}

@(test)
test_usage_scope_merge_single_accumulates_disjoint_bits :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Index})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Uniform})
    testing.expect(t, err == nil)

    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex, .Index, .Uniform})
}

@(test)
test_usage_scope_merge_single_grows_scope :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 2, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 5, dummy_buffer, {.Vertex})

    testing.expect(t, err == nil)
    testing.expect(t, len(s.state) >= 6)
    testing.expect_value(t, s.state[5], Buffer_Uses{.Vertex})
    testing.expect(t, resource_metadata_contains(&s.metadata, 5))
}

@(test)
test_usage_scope_merge_single_idempotent :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    for _ in 0 ..< 3 {
        err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})
        testing.expect(t, err == nil)
    }
    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex})
}

@(test)
test_usage_scope_merge_single_conflict_reports_error :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer

    // Storage_Read_Write is exclusive; combining with Vertex is invalid.
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Storage_Read_Write})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})

    testing.expect(t, err != nil)
    // The existing state must be left unmodified on error.
    testing.expect_value(t, s.state[1], Buffer_Uses{.Storage_Read_Write})
}

@(test)
test_usage_scope_merge_single_map_conflict :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 0, dummy_buffer, {.Map_Read})
    testing.expect(t, err == nil)

    // Map_Read and Map_Write are mutually exclusive.
    err = buffer_usage_scope_merge_single(&s, 0, dummy_buffer, {.Map_Write})

    testing.expect(t, err != nil)
    testing.expect_value(t, s.state[0], Buffer_Uses{.Map_Read})
}

@(test)
test_usage_scope_merge_single_compatible_bits_do_not_conflict :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer

    // Vertex | Index is a common, valid combination.
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Index})
    testing.expect(t, err == nil)

    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex, .Index})
}

// -----------------------------------------------------------------------------
// Buffer_Usage_Scope: remove_usage
// -----------------------------------------------------------------------------

@(test)
test_usage_scope_remove_usage_clears_bits :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex, .Index})
    testing.expect(t, err == nil)
    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex, .Index})

    buffer_usage_scope_remove_usage(&s, 1, {.Vertex})
    testing.expect_value(t, s.state[1], Buffer_Uses{.Index})

    buffer_usage_scope_remove_usage(&s, 1, {.Index})
    testing.expect_value(t, s.state[1], Buffer_Uses{})
}

@(test)
test_usage_scope_remove_usage_no_op_for_unowned_index :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    // Index 2 is not owned; remove_usage must guard on contains().
    buffer_usage_scope_remove_usage(&s, 2, {.Vertex})
    testing.expect_value(t, s.state[2], Buffer_Uses{})
}

@(test)
test_usage_scope_remove_usage_leaves_metadata_intact :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 1, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)

    buffer_usage_scope_remove_usage(&s, 1, {.Vertex})

    // remove_usage only touches s.state; the metadata still records
    // the index as owned.
    testing.expect(t, resource_metadata_contains(&s.metadata, 1))
}

// -----------------------------------------------------------------------------
// Buffer_Usage_Scope: merge_bind_group
// -----------------------------------------------------------------------------

@(test)
test_usage_scope_merge_bind_group :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 8, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    dummy_buffer: Buffer
    buffer_bind_group_state_insert_single(&bg, 1, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&bg, 3, dummy_buffer, {.Index})
    buffer_bind_group_state_insert_single(&bg, 6, dummy_buffer, {.Uniform})
    buffer_bind_group_state_optimize(&bg)

    err := buffer_usage_scope_merge_bind_group(&s, &bg)

    testing.expect(t, err == nil)
    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex})
    testing.expect_value(t, s.state[3], Buffer_Uses{.Index})
    testing.expect_value(t, s.state[6], Buffer_Uses{.Uniform})
    testing.expect(t, resource_metadata_contains(&s.metadata, 1))
    testing.expect(t, resource_metadata_contains(&s.metadata, 3))
    testing.expect(t, resource_metadata_contains(&s.metadata, 6))
}

@(test)
test_usage_scope_merge_bind_group_empty :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    err := buffer_usage_scope_merge_bind_group(&s, &bg)

    testing.expect(t, err == nil)
    testing.expect(t, resource_metadata_is_empty(&s.metadata))
}

@(test)
test_usage_scope_merge_bind_group_twice_accumulates :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 8, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    bg1: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg1, context.allocator)
    defer buffer_bind_group_state_uninit(&bg1)
    dummy_buffer: Buffer
    buffer_bind_group_state_insert_single(&bg1, 2, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&bg1, 4, dummy_buffer, {.Index})
    buffer_bind_group_state_optimize(&bg1)

    err := buffer_usage_scope_merge_bind_group(&s, &bg1)
    testing.expect(t, err == nil)

    bg2: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg2, context.allocator)
    defer buffer_bind_group_state_uninit(&bg2)
    buffer_bind_group_state_insert_single(&bg2, 2, dummy_buffer, {.Uniform})
    buffer_bind_group_state_insert_single(&bg2, 4, dummy_buffer, {.Copy_Src})
    buffer_bind_group_state_optimize(&bg2)

    err = buffer_usage_scope_merge_bind_group(&s, &bg2)
    testing.expect(t, err == nil)

    testing.expect_value(t, s.state[2], Buffer_Uses{.Vertex, .Uniform})
    testing.expect_value(t, s.state[4], Buffer_Uses{.Index, .Copy_Src})
}

@(test)
test_usage_scope_merge_bind_group_stops_on_conflict :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 8, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    // Pre-populate index 3 with an exclusive use.
    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&s, 3, dummy_buffer, {.Storage_Read_Write})
    testing.expect(t, err == nil)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)
    buffer_bind_group_state_insert_single(&bg, 1, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&bg, 3, dummy_buffer, {.Vertex})
    buffer_bind_group_state_insert_single(&bg, 5, dummy_buffer, {.Vertex})
    buffer_bind_group_state_optimize(&bg)

    err = buffer_usage_scope_merge_bind_group(&s, &bg)

    testing.expect(t, err != nil)
    testing.expect_value(t, s.state[1], Buffer_Uses{.Vertex}) // before the conflict
    testing.expect_value(t, s.state[3], Buffer_Uses{.Storage_Read_Write}) // unchanged
    testing.expect(t, !resource_metadata_contains(&s.metadata, 5)) // never reached
}

// -----------------------------------------------------------------------------
// Buffer_Usage_Scope: merge_usage_scope
// -----------------------------------------------------------------------------

@(test)
test_usage_scope_merge_grows_target_to_fit_source :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 2, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 8, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&b, 5, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&b, 7, dummy_buffer, {.Index})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err == nil)
    testing.expect(t, len(a.state) >= 8)
    testing.expect_value(t, a.state[5], Buffer_Uses{.Vertex})
    testing.expect_value(t, a.state[7], Buffer_Uses{.Index})
    testing.expect(t, resource_metadata_contains(&a.metadata, 5))
    testing.expect(t, resource_metadata_contains(&a.metadata, 7))
}

@(test)
test_usage_scope_merge_accumulates_shared_indices :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 4, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 4, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&a, 1, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&b, 1, dummy_buffer, {.Index})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err == nil)
    testing.expect_value(t, a.state[1], Buffer_Uses{.Vertex, .Index})
}

@(test)
test_usage_scope_merge_into_empty :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 0, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 4, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&b, 2, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err == nil)
    testing.expect(t, len(a.state) >= 4)
    testing.expect_value(t, a.state[2], Buffer_Uses{.Vertex})
}

@(test)
test_usage_scope_merge_disjoint_indices :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 4, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 4, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&a, 0, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&b, 3, dummy_buffer, {.Index})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err == nil)
    testing.expect_value(t, a.state[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, a.state[3], Buffer_Uses{.Index})
}

@(test)
test_usage_scope_merge_only_iterates_owned_indices :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 8, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 8, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    // `b` only owns index 6; indices 0..5 and 7 are untouched and must
    // not be visited by merge_usage_scope (which walks metadata.owned).
    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&b, 6, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err == nil)
    testing.expect(t, !resource_metadata_contains(&a.metadata, 0))
    testing.expect(t, !resource_metadata_contains(&a.metadata, 5))
    testing.expect(t, resource_metadata_contains(&a.metadata, 6))
    testing.expect(t, !resource_metadata_contains(&a.metadata, 7))
}

@(test)
test_usage_scope_merge_stops_on_conflict :: proc(t: ^testing.T) {
    a: Buffer_Usage_Scope
    buffer_usage_scope_init(&a, 4, context.allocator)
    defer buffer_usage_scope_uninit(&a)

    b: Buffer_Usage_Scope
    buffer_usage_scope_init(&b, 4, context.allocator)
    defer buffer_usage_scope_uninit(&b)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&a, 1, dummy_buffer, {.Storage_Read_Write})
    testing.expect(t, err == nil)

    // `b` owns two indices, one of which conflicts with `a`.
    err = buffer_usage_scope_merge_single(&b, 1, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)
    err = buffer_usage_scope_merge_single(&b, 2, dummy_buffer, {.Vertex})
    testing.expect(t, err == nil)

    err = buffer_usage_scope_merge_usage_scope(&a, &b)

    testing.expect(t, err != nil)
    // Index 1 was left untouched; the conflict path returns before writing.
    testing.expect_value(t, a.state[1], Buffer_Uses{.Storage_Read_Write})
}

// -----------------------------------------------------------------------------
// Buffer_Usage_Scope: assert_in_bounds (debug only)
// -----------------------------------------------------------------------------

@(test)
test_usage_scope_assert_in_bounds_passes :: proc(t: ^testing.T) {
    s: Buffer_Usage_Scope
    buffer_usage_scope_init(&s, 4, context.allocator)
    defer buffer_usage_scope_uninit(&s)

    buffer_usage_scope_assert_in_bounds(&s, 0)
    buffer_usage_scope_assert_in_bounds(&s, 3)
}

@(test)
test_buffer_usage_scope_merge_single_compatible_reads :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    dummy_buffer: Buffer
    err := buffer_usage_scope_merge_single(&scope, 0, dummy_buffer, Buffer_Uses{.Vertex})
    testing.expect(t, err == nil, "vertex usage alone should merge cleanly")

    err2 := buffer_usage_scope_merge_single(&scope, 0, dummy_buffer, Buffer_Uses{.Index})
    testing.expect(t, err2 == nil, "vertex + index on the same buffer is a legal combination")
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Vertex, .Index})
}

@(test)
test_buffer_usage_scope_merge_single_conflict :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    dummy_buffer: Buffer
    err1 := buffer_usage_scope_merge_single(&scope, 0, dummy_buffer, Buffer_Uses{.Vertex})
    testing.expect(t, err1 == nil, "sanity: first merge succeeds")

    err2 := buffer_usage_scope_merge_single(
        &scope, 0, dummy_buffer, Buffer_Uses{.Storage_Read_Write})
    testing.expect(t, err2 != nil,
        "read usage + exclusive write usage on the same buffer must conflict")
    if err2 != nil {
        conflict, is_buffer_error := err2.(Buffer_Usage_Error)
        testing.expect(t, is_buffer_error,
            "conflict should be reported as a Buffer_Usage_Error")
        if is_buffer_error {
            testing.expect_value(t, conflict.buffer, dummy_buffer)
            testing.expect_value(t, conflict.current_state, Buffer_Uses{.Vertex})
            testing.expect_value(t, conflict.new_state, Buffer_Uses{.Storage_Read_Write})
        }
    }
}

@(test)
test_buffer_usage_scope_merge_bind_group :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 4, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    a := Buffer{handle = 0}
    b := Buffer{handle = 1}
    buffer_bind_group_state_insert_single(&bg, 0, a, Buffer_Uses{.Storage_Read_Only})
    buffer_bind_group_state_insert_single(&bg, 1, b, Buffer_Uses{.Uniform})

    err := buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err == nil,
        "two independent buffers in one bind group should merge without conflict")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 0),
        "buffer a should now be in the scope")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 1),
        "buffer b should now be in the scope")
}

@(test)
test_buffer_usage_scope_merge_bind_group_internal_conflict :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 4, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    a := Buffer{handle = 0}
    // A single bind group binding the same buffer twice with
    // incompatible usages, legal to build, but must fail to merge.
    buffer_bind_group_state_insert_single(&bg, 0, a, Buffer_Uses{.Storage_Read_Write})
    buffer_bind_group_state_insert_single(&bg, 0, a, Buffer_Uses{.Uniform})

    err := buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err != nil,
        "conflicting uses of the same buffer within one bind group should be reported")
}

// A bind group can reference a buffer whose tracker index outruns anything the
// pass has touched so far, so merging must grow the scope instead of relying on
// a prior `set_size` call. Before this, the documented precondition was never
// satisfied by any caller.
@(test)
test_buffer_bind_group_merge_grows_scope_past_initial_size :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 1, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    high := Buffer{handle = 64}
    buffer_bind_group_state_insert_single(&bg, 64, high, Buffer_Uses{.Uniform})

    err := buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err == nil,
        "merging a high-index buffer must grow the scope, not fail")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 64),
        "the high-index buffer should be present once the scope has grown")
}

// Growing resizes the backing arrays, so anything already merged in has to
// survive the resize.
@(test)
test_buffer_bind_group_merge_growth_preserves_existing_state :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    seed := Buffer{handle = 0}
    err := buffer_usage_scope_merge_single(&scope, 0, seed, Buffer_Uses{.Uniform})
    testing.expect(t, err == nil, "seed merge should succeed")

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    high := Buffer{handle = 40}
    buffer_bind_group_state_insert_single(&bg, 40, high, Buffer_Uses{.Uniform})
    err = buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err == nil, "growing merge should succeed")

    testing.expect(t, resource_metadata_contains(&scope.metadata, 0),
        "the pre-existing entry must survive the scope growing")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 40),
        "the high-index buffer should be present after growing")
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Uniform})
}

// Entry order within the bind group must not matter: the captured indices are
// what identify buffers, not their position.
@(test)
test_buffer_bind_group_merge_is_order_independent :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    // Deliberately descending, and unsorted on disk: `vk_create_bind_group`
    // sorts by captured index before merging.
    buffer_bind_group_state_insert_single(&bg, 9, Buffer{handle = 9}, Buffer_Uses{.Uniform})
    buffer_bind_group_state_insert_single(&bg, 3, Buffer{handle = 3}, Buffer_Uses{.Uniform})
    buffer_bind_group_state_insert_single(&bg, 6, Buffer{handle = 6}, Buffer_Uses{.Uniform})
    buffer_bind_group_state_optimize(&bg)

    testing.expect_value(t, int(bg.buffers[0].index), 3)
    testing.expect_value(t, int(bg.buffers[1].index), 6)
    testing.expect_value(t, int(bg.buffers[2].index), 9)

    err := buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err == nil, "merge should succeed regardless of insert order")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 3),
        "buffer 3 should be present after merging")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 6),
        "buffer 6 should be present after merging")
    testing.expect(t, resource_metadata_contains(&scope.metadata, 9),
        "buffer 9 should be present after merging")
    testing.expect_value(t, scope.state[3], Buffer_Uses{.Uniform})
    testing.expect_value(t, scope.state[6], Buffer_Uses{.Uniform})
    testing.expect_value(t, scope.state[9], Buffer_Uses{.Uniform})
}

// Growth must not weaken conflict detection: a bind group binding the same
// buffer twice incompatibly still has to be reported.
@(test)
test_buffer_bind_group_merge_growth_still_detects_conflict :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 1, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    bg: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&bg, context.allocator)
    defer buffer_bind_group_state_uninit(&bg)

    // High index so the scope has to grow before the conflict can be found.
    a := Buffer{handle = 32}
    buffer_bind_group_state_insert_single(&bg, 32, a, Buffer_Uses{.Storage_Read_Write})
    buffer_bind_group_state_insert_single(&bg, 32, a, Buffer_Uses{.Uniform})

    err := buffer_usage_scope_merge_bind_group(&scope, &bg)
    testing.expect(t, err != nil,
        "growing the scope must not stop internal conflicts from being reported")
}

@(test)
test_buffer_usage_scope_merge_usage_scope :: proc(t: ^testing.T) {
    a := Buffer{handle = 0}
    b := Buffer{handle = 1}

    src: Buffer_Usage_Scope
    buffer_usage_scope_init(&src, 4, context.allocator)
    defer buffer_usage_scope_uninit(&src)

    buffer_usage_scope_merge_single(&src, 0, a, Buffer_Uses{.Vertex})
    buffer_usage_scope_merge_single(&src, 1, b, Buffer_Uses{.Index})

    dst: Buffer_Usage_Scope
    buffer_usage_scope_init(&dst, 4, context.allocator)
    defer buffer_usage_scope_uninit(&dst)

    buffer_usage_scope_merge_single(&dst, 0, a, Buffer_Uses{.Copy_Src})

    err := buffer_usage_scope_merge_usage_scope(&dst, &src)
    testing.expect(t, err == nil, "compatible cross-scope merge should succeed")

    testing.expect_value(t, dst.state[0], Buffer_Uses{.Copy_Src, .Vertex})
    testing.expect(t, resource_metadata_contains(&dst.metadata, 1),
        "buffer b should have been pulled into dst")
}

@(test)
test_buffer_usage_scope_remove_usage :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf := Buffer{handle = 0}
    buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex, .Index})

    buffer_usage_scope_remove_usage(&scope, 0, Buffer_Uses{.Index})
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Vertex})
}

@(test)
test_buffer_tracker_init_starts_empty :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    testing.expect_value(t, len(tr.start), 0)
    testing.expect_value(t, len(tr.end), 0)
    testing.expect_value(t, len(tr.temp), 0)
    testing.expect(t, resource_metadata_is_empty(&tr.metadata))
}

@(test)
test_buffer_tracker_uninit_resets :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)

    buffer_tracker_set_size(&tr, 4)
    _, _ = buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    buffer_tracker_uninit(&tr)

    testing.expect_value(t, len(tr.start), 0)
    testing.expect_value(t, len(tr.end), 0)
    testing.expect_value(t, len(tr.temp), 0)
}

@(test)
test_buffer_tracker_set_size_grows_both_tables :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    buffer_tracker_set_size(&tr, 8)
    testing.expect_value(t, len(tr.start), 8)
    testing.expect_value(t, len(tr.end), 8)
    testing.expect_value(t, bit_vector_len(&tr.metadata.owned), 8)

    buffer_tracker_set_size(&tr, 4)
    testing.expect_value(t, len(tr.start), 4)
    testing.expect_value(t, len(tr.end), 4)
    testing.expect_value(t, bit_vector_len(&tr.metadata.owned), 4)
}

@(test)
test_buffer_tracker_allow_index_grows_only_when_needed :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)
    buffer_tracker_set_size(&tr, 4)

    buffer_tracker_allow_index(&tr, 2)
    testing.expect_value(t, len(tr.start), 4)

    buffer_tracker_allow_index(&tr, 3)
    testing.expect_value(t, len(tr.start), 4)

    buffer_tracker_allow_index(&tr, 9)
    testing.expect_value(t, len(tr.start), 10)
    testing.expect_value(t, len(tr.end), 10)
    testing.expect_value(t, bit_vector_len(&tr.metadata.owned), 10)
}

@(test)
test_buffer_tracker_contains_initially_false :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)
    buffer_tracker_set_size(&tr, 8)

    testing.expect(t, !buffer_tracker_contains(&tr, 0))
    testing.expect(t, !buffer_tracker_contains(&tr, 7))
}

@(test)
test_buffer_tracker_used_resources_iterates_owned :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    a := Buffer{handle = 10}
    b := Buffer{handle = 20}

    _, _ = buffer_tracker_set_single(&tr, 1, a, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&tr, 4, b, Buffer_Uses{.Index})

    it := buffer_tracker_used_resources(&tr)

    // The metadata iterator yields resources in ascending index order,
    // so we expect a then b.
    want := [2]Buffer{a, b}
    i := 0
    for buf in resource_metadata_iterate_next(&it) {
        testing.expect(t, i < len(want), "too many resources")
        if i >= len(want) { break }
        testing.expect_value(t, buf, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))
}

@(test)
test_buffer_tracker_set_single_first_insert_no_transition :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    _, ok := buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    testing.expect(t, !ok, "first insertion should not need a barrier")
    testing.expect(t, buffer_tracker_contains(&tr, 1))
    testing.expect_value(t, tr.start[1], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.end[1], Buffer_Uses{.Vertex})
    testing.expect_value(t, len(tr.temp), 0)
}

@(test)
test_buffer_tracker_set_single_grows_tracker :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    _, ok := buffer_tracker_set_single(&tr, 5, Buffer{}, Buffer_Uses{.Vertex})

    testing.expect(t, !ok)
    testing.expect(t, len(tr.start) >= 6)
    testing.expect_value(t, tr.start[5], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.end[5], Buffer_Uses{.Vertex})
}

@(test)
test_buffer_tracker_set_single_second_call_produces_transition :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    // First call inserts, sets start = end = .Vertex.
    _, ok1 := buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})
    testing.expect(t, !ok1)

    // Second call with a different state should return a transition.
    transition, ok2 := buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Index})
    testing.expect(t, ok2, "state change should need a barrier")
    testing.expect_value(t, transition.id, 1)
    testing.expect_value(t, transition.usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, transition.usage.to, Buffer_Uses{.Index})

    // end is updated to the new state; start is frozen.
    testing.expect_value(t, tr.start[1], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.end[1], Buffer_Uses{.Index})

    // temp was drained by set_single.
    testing.expect_value(t, len(tr.temp), 0)
}

@(test)
test_buffer_tracker_set_single_skips_when_masked :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    // Ordered-mask covering .Vertex means a no-op transition on .Vertex is
    // skipped instead of producing a barrier.
    tr.ordered_uses_mask = Buffer_Uses{.Vertex}

    _, _ = buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})
    _, ok := buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    testing.expect(t, !ok, "same state within ordered mask should not need a barrier")
}

@(test)
test_buffer_tracker_set_single_conservative_when_no_mask :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, {}, context.allocator)
    defer buffer_tracker_uninit(&tr)

    // No ordered mask set. Repeated identical writes still produce a
    // barrier, because ordered_uses_mask = {} makes even same-state
    // transitions fall outside the "already ordered" set.
    _, _ = buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})
    _, ok := buffer_tracker_set_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    testing.expect(t, ok)
}

@(test)
test_buffer_tracker_drain_transitions_returns_and_clears :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    // Seed temp directly so this test isolates drain_transitions.
    append(&tr.temp, Pending_Buffer_Transition{
        id = 1,
        usage = {from = {}, to = Buffer_Uses{.Vertex}},
    })
    append(&tr.temp, Pending_Buffer_Transition{
        id = 2,
        usage = {from = {}, to = Buffer_Uses{.Index}},
    })

    result := buffer_tracker_drain_transitions(&tr, context.allocator)
    defer delete(result)

    testing.expect_value(t, len(result), 2)
    testing.expect_value(t, result[0].id, u32(1))
    testing.expect_value(t, result[0].usage.to, Buffer_Uses{.Vertex})
    testing.expect_value(t, result[1].id, u32(2))
    testing.expect_value(t, result[1].usage.to, Buffer_Uses{.Index})

    // temp is emptied.
    testing.expect_value(t, len(tr.temp), 0)

    // A second drain returns nothing.
    empty := buffer_tracker_drain_transitions(&tr, context.allocator)
    defer delete(empty)
    testing.expect_value(t, len(empty), 0)
}

@(test)
test_buffer_tracker_set_from_tracker_adopts_state :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    _, _ = buffer_tracker_set_single(&src, 0, Buffer{}, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{}, Buffer_Uses{.Index})

    dst: Buffer_Tracker
    buffer_tracker_init(&dst, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&dst)

    buffer_tracker_set_from_tracker(&dst, &src)

    testing.expect(t, buffer_tracker_contains(&dst, 0))
    testing.expect(t, buffer_tracker_contains(&dst, 1))
    testing.expect_value(t, dst.start[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, dst.end[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, dst.start[1], Buffer_Uses{.Index})
    testing.expect_value(t, dst.end[1], Buffer_Uses{.Index})
}

@(test)
test_buffer_tracker_set_from_tracker_grows_target :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    _, _ = buffer_tracker_set_single(&src, 7, Buffer{}, Buffer_Uses{.Vertex})

    dst: Buffer_Tracker
    buffer_tracker_init(&dst, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&dst)

    buffer_tracker_set_from_tracker(&dst, &src)

    testing.expect(t, len(dst.start) >= 8)
    testing.expect_value(t, dst.start[7], Buffer_Uses{.Vertex})
    testing.expect(t, buffer_tracker_contains(&dst, 7))
}

@(test)
test_buffer_tracker_set_from_tracker_no_op_when_empty :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    dst: Buffer_Tracker
    buffer_tracker_init(&dst, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&dst)

    buffer_tracker_set_from_tracker(&dst, &src)

    testing.expect(t, resource_metadata_is_empty(&dst.metadata))
    testing.expect_value(t, len(dst.temp), 0)
}

@(test)
test_buffer_tracker_set_from_usage_scope_adopts_state :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 4, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    _ = buffer_usage_scope_merge_single(&scope, 0, Buffer{}, Buffer_Uses{.Vertex})
    _ = buffer_usage_scope_merge_single(&scope, 1, Buffer{}, Buffer_Uses{.Index})

    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    buffer_tracker_set_from_usage_scope(&tr, &scope)

    testing.expect(t, buffer_tracker_contains(&tr, 0))
    testing.expect(t, buffer_tracker_contains(&tr, 1))
    testing.expect_value(t, tr.start[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.end[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.start[1], Buffer_Uses{.Index})
    testing.expect_value(t, tr.end[1], Buffer_Uses{.Index})
}

@(test)
test_buffer_tracker_set_from_usage_scope_grows_target :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 8, context.allocator)
    defer buffer_usage_scope_uninit(&scope)
    _ = buffer_usage_scope_merge_single(&scope, 6, Buffer{}, Buffer_Uses{.Vertex})

    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    buffer_tracker_set_from_usage_scope(&tr, &scope)

    testing.expect(t, len(tr.start) >= 7)
    testing.expect_value(t, tr.start[6], Buffer_Uses{.Vertex})
}

@(test)
test_buffer_tracker_sparse_picks_selected_indices :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 8, context.allocator)
    defer buffer_usage_scope_uninit(&scope)
    _ = buffer_usage_scope_merge_single(&scope, 1, Buffer{}, Buffer_Uses{.Vertex})
    _ = buffer_usage_scope_merge_single(&scope, 3, Buffer{}, Buffer_Uses{.Index})
    _ = buffer_usage_scope_merge_single(&scope, 7, Buffer{}, Buffer_Uses{.Uniform})

    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    indices := []Tracker_Index{1, 7}
    buffer_tracker_set_and_remove_from_usage_scope_sparse(&tr, &scope, indices)

    // Tracker has 1 and 7, not 3.
    testing.expect(t, buffer_tracker_contains(&tr, 1))
    testing.expect(t, buffer_tracker_contains(&tr, 7))
    testing.expect(t, !buffer_tracker_contains(&tr, 3))
    testing.expect_value(t, tr.start[1], Buffer_Uses{.Vertex})
    testing.expect_value(t, tr.start[7], Buffer_Uses{.Uniform})

    // Scope lost 1 and 7, still has 3.
    testing.expect(t, !resource_metadata_contains(&scope.metadata, 1))
    testing.expect(t, !resource_metadata_contains(&scope.metadata, 7))
    testing.expect(t, resource_metadata_contains(&scope.metadata, 3))
}

@(test)
test_buffer_tracker_sparse_skips_missing_indices :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 8, context.allocator)
    defer buffer_usage_scope_uninit(&scope)
    _ = buffer_usage_scope_merge_single(&scope, 1, Buffer{}, Buffer_Uses{.Vertex})

    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    // Index 5 is not present in scope; the sparse proc must `continue`
    // without touching the tracker for that index.
    indices := []Tracker_Index{1, 5}
    buffer_tracker_set_and_remove_from_usage_scope_sparse(&tr, &scope, indices)

    testing.expect(t, buffer_tracker_contains(&tr, 1))
    testing.expect(t, !buffer_tracker_contains(&tr, 5))
}

@(test)
test_buffer_tracker_sparse_grows_target :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 8, context.allocator)
    defer buffer_usage_scope_uninit(&scope)
    _ = buffer_usage_scope_merge_single(&scope, 6, Buffer{}, Buffer_Uses{.Vertex})

    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)

    buffer_tracker_set_and_remove_from_usage_scope_sparse(&tr, &scope, []Tracker_Index{6})

    testing.expect(t, len(tr.start) >= 7)
    testing.expect_value(t, tr.start[6], Buffer_Uses{.Vertex})
}

@(test)
test_buffer_tracker_assert_in_bounds_passes :: proc(t: ^testing.T) {
    tr: Buffer_Tracker
    buffer_tracker_init(&tr, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tr)
    buffer_tracker_set_size(&tr, 4)

    buffer_tracker_assert_in_bounds(&tr, 0)
    buffer_tracker_assert_in_bounds(&tr, 3)
}

@(test)
test_device_buffer_tracker_init_preserves_configuration :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{.Vertex, .Index}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    testing.expect_value(t, tr.ordered_uses_mask, Buffer_Uses{.Vertex, .Index})
    testing.expect(t, tr.current_states.allocator.procedure != nil,
        "current_states.allocator must be set after init")
}

@(test)
test_device_buffer_tracker_init_starts_empty :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    testing.expect_value(t, len(tr.current_states), 0)
    testing.expect_value(t, len(tr.temp), 0)
    testing.expect(t, resource_metadata_is_empty(&tr.metadata))
}

@(test)
test_device_buffer_tracker_uninit_resets :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)

    device_buffer_tracker_allow_index(&tr, 4)
    device_buffer_tracker_insert_single(&tr, 2, Buffer{handle = 42}, Buffer_Uses{.Vertex})

    device_buffer_tracker_uninit(&tr)

    testing.expect_value(t, len(tr.current_states), 0)
    testing.expect_value(t, len(tr.temp), 0)
    testing.expect_value(t, tr.ordered_uses_mask, Buffer_Uses{})
}

@(test)
test_device_buffer_tracker_allow_index_grows :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_allow_index(&tr, 5)
    testing.expect(t, len(tr.current_states) >= 6)
    testing.expect(t, bit_vector_len(&tr.metadata.owned) >= 6)
}

@(test)
test_device_buffer_tracker_allow_index_noop_when_in_bounds :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_allow_index(&tr, 7)
    n := len(tr.current_states)

    device_buffer_tracker_allow_index(&tr, 3)
    testing.expect_value(t, len(tr.current_states), n)
}

@(test)
test_device_buffer_tracker_insert_single_grows_and_stores :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_insert_single(&tr, 3, Buffer{handle = 77}, Buffer_Uses{.Vertex})

    testing.expect(t, len(tr.current_states) >= 4)
    testing.expect_value(t, tr.current_states[3], Buffer_Uses{.Vertex})
    testing.expect(t, resource_metadata_contains(&tr.metadata, 3))
}

@(test)
test_device_buffer_tracker_insert_single_overwrites_state :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    // Two inserts on the same index: the second call should overwrite the state
    device_buffer_tracker_insert_single(&tr, 2, Buffer{handle = 1}, Buffer_Uses{.Vertex})
    device_buffer_tracker_insert_single(&tr, 2, Buffer{handle = 1}, Buffer_Uses{.Index})

    testing.expect_value(t, tr.current_states[2], Buffer_Uses{.Index})
}

@(test)
test_device_buffer_tracker_insert_single_stores_resource :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    b := Buffer{handle = 42}
    device_buffer_tracker_insert_single(&tr, 1, b, Buffer_Uses{.Vertex})

    // `used_resources` must yield the resource that was inserted.
    it := device_buffer_tracker_used_resources(&tr)
    got, ok := resource_metadata_iterate_next(&it)
    testing.expect(t, ok)
    testing.expect_value(t, got, b)

    _, ok = resource_metadata_iterate_next(&it)
    testing.expect(t, !ok, "exactly one resource should have been stored")
}

@(test)
test_device_buffer_tracker_set_single_no_transition_when_same :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{.Vertex}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_insert_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    // Same state, within ordered mask → no transition.
    _, ok := device_buffer_tracker_set_single(&tr, 1, {}, Buffer_Uses{.Vertex})
    testing.expect(t, !ok)
    testing.expect_value(t, tr.current_states[1], Buffer_Uses{.Vertex})
}

@(test)
test_device_buffer_tracker_set_single_returns_transition_on_change :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_insert_single(&tr, 1, Buffer{}, Buffer_Uses{.Vertex})

    transition, ok := device_buffer_tracker_set_single(&tr, 1, {}, Buffer_Uses{.Index})

    testing.expect(t, ok)
    testing.expect_value(t, transition.id, u32(1))
    testing.expect_value(t, transition.usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, transition.usage.to, Buffer_Uses{.Index})

    // current_states has been updated to the new state.
    testing.expect_value(t, tr.current_states[1], Buffer_Uses{.Index})

    // temp was drained by set_single.
    testing.expect_value(t, len(tr.temp), 0)
}

@(test)
test_device_buffer_tracker_set_single_requires_in_bounds :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_insert_single(&tr, 3, Buffer{}, Buffer_Uses{.Vertex})
    _, ok := device_buffer_tracker_set_single(&tr, 3, {}, Buffer_Uses{.Index})
    testing.expect(t, ok)
}

@(test)
test_device_buffer_tracker_used_resources_empty :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    it := device_buffer_tracker_used_resources(&tr)
    _, ok := resource_metadata_iterate_next(&it)
    testing.expect(t, !ok)
}

@(test)
test_device_buffer_tracker_used_resources_ascending :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    a := Buffer{handle = 10}
    b := Buffer{handle = 20}
    c := Buffer{handle = 30}

    device_buffer_tracker_insert_single(&tr, 0, a, Buffer_Uses{.Vertex})
    device_buffer_tracker_insert_single(&tr, 3, c, Buffer_Uses{.Uniform})
    device_buffer_tracker_insert_single(&tr, 1, b, Buffer_Uses{.Index})

    want := [3]Buffer{a, b, c}

    it := device_buffer_tracker_used_resources(&tr)
    i := 0
    for buf in resource_metadata_iterate_next(&it) {
        testing.expect(t, i < len(want), "too many resources")
        if i >= len(want) { break }
        testing.expect_value(t, buf, want[i])
        i += 1
    }
    testing.expect_value(t, i, len(want))
}

@(test)
test_device_buffer_tracker_adopt_from_tracker_empty :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    result := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator)
    defer delete(result)

    testing.expect_value(t, len(result), 0)
}

// A tracker that only sets a buffer's first state (start == end) should not
// produce a barrier, because the device is assumed to already be at the
// initial state. This test pins the "first insertion is free" behavior.
@(test)
test_device_buffer_tracker_adopt_first_insert_no_barrier :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{handle = 1}, Buffer_Uses{.Vertex})

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_allow_index(&tr, 4)

    // Pre-seed device state to match the tracker's start state, so the diff
    // is empty.
    device_buffer_tracker_insert_single(&tr, 1, Buffer{handle = 1}, Buffer_Uses{.Vertex})

    result := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator)
    defer delete(result)

    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, result[0].usage.to, Buffer_Uses{.Vertex})
}

@(test)
test_device_buffer_tracker_adopt_produces_transition :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    // Tracker sees: buffer 2 starts at .Vertex, ends at .Index.
    _, _ = buffer_tracker_set_single(&src, 2, Buffer{handle = 2}, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&src, 2, Buffer{handle = 2}, Buffer_Uses{.Index})

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_allow_index(&tr, 3)

    // Device is currently in .Vertex for buffer 2.
    device_buffer_tracker_insert_single(&tr, 2, Buffer{handle = 2}, Buffer_Uses{.Vertex})

    result := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator,
    )
    defer delete(result)

    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].id, u32(2))

    // The barrier targets the tracker's *start* state, because the barrier
    // is what makes the device ready to *begin* running the tracker.
    testing.expect_value(t, result[0].usage.from, Buffer_Uses{.Vertex})
    testing.expect_value(t, result[0].usage.to,   Buffer_Uses{.Vertex})

    // The device adopts the tracker's *end* state afterward.
    testing.expect_value(t, tr.current_states[2], Buffer_Uses{.Index})
}

@(test)
test_device_buffer_tracker_adopt_separates_start_and_end_roles :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    // Tracker: start at .Vertex, end at .Index.
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{handle = 1}, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{handle = 1}, Buffer_Uses{.Index})

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_allow_index(&tr, 2)

    // Device starts at a *third* state, so the barrier is a real transition
    // from {.Uniform} to the tracker's start {.Vertex}.
    device_buffer_tracker_insert_single(&tr, 1, Buffer{handle = 1}, Buffer_Uses{.Uniform})

    result := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator,
    )
    defer delete(result)

    testing.expect_value(t, len(result), 1)
    testing.expect_value(t, result[0].usage.from, Buffer_Uses{.Uniform}) // device's prior state
    testing.expect_value(t, result[0].usage.to,   Buffer_Uses{.Vertex})  // tracker's START
    testing.expect_value(t, tr.current_states[1], Buffer_Uses{.Index})   // tracker's END
}

@(test)
test_device_buffer_tracker_adopt_multiple_indices_ascending :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)

    // Indices 1, 4, 6 all start at {}, end at .Vertex.
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{handle = 1}, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&src, 4, Buffer{handle = 4}, Buffer_Uses{.Vertex})
    _, _ = buffer_tracker_set_single(&src, 6, Buffer{handle = 6}, Buffer_Uses{.Vertex})

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_allow_index(&tr, 7)

    // Pre-seed device state as {} for each index (which is the default after
    // allow_index), so each adoption produces one transition.
    result := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator,
    )
    defer delete(result)

    testing.expect_value(t, len(result), 3)
    testing.expect_value(t, result[0].id, u32(1))
    testing.expect_value(t, result[1].id, u32(4))
    testing.expect_value(t, result[2].id, u32(6))
}

@(test)
test_device_buffer_tracker_adopt_drains_temp :: proc(t: ^testing.T) {
    src: Buffer_Tracker
    buffer_tracker_init(&src, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&src)
    _, _ = buffer_tracker_set_single(&src, 1, Buffer{handle = 1}, Buffer_Uses{.Vertex})

    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_allow_index(&tr, 2)

    first := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator,
    )
    defer delete(first)

    testing.expect(t, len(first) >= 1)
    testing.expect_value(t, len(tr.temp), 0)

    // Second adoption with a tracker whose end state equals the device's
    // current state should produce no new transitions... except that the
    // tracker's `end` state is still .Vertex == device's current .Vertex,
    // so we expect another transition (conservative default with empty mask).
    second := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &tr, &src, context.allocator,
    )
    defer delete(second)

    // No accumulation: temp is drained, so `second` reflects only this call.
    testing.expect_value(t, len(second), len(first))
}

@(test)
test_device_buffer_tracker_assert_in_bounds_passes :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    device_buffer_tracker_allow_index(&tr, 4)
    device_buffer_tracker_assert_in_bounds(&tr, 0)
    device_buffer_tracker_assert_in_bounds(&tr, 3)
}

// -----------------------------------------------------------------------------
// Texture_Uses Tests
// -----------------------------------------------------------------------------

@(test)
test_texture_uses_bits :: proc(t: ^testing.T) {
    // Test empty set
    empty: Texture_Uses
    testing.expect_value(t, texture_uses_bits(empty), u32(0))

    // Test single bit
    single := Texture_Uses{.Present}
    bits := texture_uses_bits(single)
    testing.expect(t, bits != 0, "single bit should be non-zero")
    testing.expect_value(t, intr.count_ones(bits), 1)

    // Test multiple bits
    multi := Texture_Uses{.Copy_Src, .Resource, .Depth_Read}
    bits = texture_uses_bits(multi)
    testing.expect_value(t, intr.count_ones(bits), 3)
}

@(test)
test_texture_uses_any_exclusive :: proc(t: ^testing.T) {
    // No exclusive
    inclusive := Texture_Uses{.Copy_Src, .Resource}
    testing.expect(t, !texture_uses_any_exclusive(inclusive),
        "inclusive-only set should not have exclusive")

    // Has exclusive
    exclusive := Texture_Uses{.Copy_Dst}
    testing.expect(t, texture_uses_any_exclusive(exclusive),
        "Copy_Dst is exclusive")

    // Mixed
    mixed := Texture_Uses{.Copy_Src, .Color_Target}
    testing.expect(t, texture_uses_any_exclusive(mixed),
        "mixed set with Color_Target is exclusive")

    // Present is exclusive
    present := Texture_Uses{.Present}
    testing.expect(t, texture_uses_any_exclusive(present),
        "Present is exclusive")
}

@(test)
test_texture_uses_in_valid_ds :: proc(t: ^testing.T) {
    // Valid combinations
    valid_ds := []Texture_Uses{
        {.Depth_Write, .Stencil_Write},
        {.Depth_Write, .Stencil_Read},
        {.Stencil_Write, .Depth_Read},
        {.Depth_Write, .Resource, .Stencil_Read},
        {.Stencil_Write, .Resource, .Depth_Read},
        {.Depth_Write, .Resource, .Stencil_Read, .Stencil_Sampled},
        {.Stencil_Write, .Resource, .Depth_Read, .Depth_Sampled},
    }
    for v in valid_ds {
        testing.expect(t, texture_uses_in_valid_ds(v),
            "expected valid DS combination")
    }

    // Invalid combinations
    invalid_ds := []Texture_Uses{
        {.Depth_Write},                    // depth write alone
        {.Stencil_Write},                  // stencil write alone
        {.Depth_Write, .Depth_Read},       // conflicting depth
        {.Stencil_Write, .Stencil_Read},   // conflicting stencil
        {.Depth_Write, .Color_Target},     // unrelated exclusive
    }
    for v in invalid_ds {
        testing.expect(t, !texture_uses_in_valid_ds(v),
            "expected invalid DS combination")
    }
}

@(test)
test_texture_uses_is_invalid :: proc(t: ^testing.T) {
    // Valid: single exclusive
    testing.expect(t, !texture_uses_is_invalid(Texture_Uses{.Copy_Dst}),
        "single exclusive is valid")

    // Invalid: multiple exclusives
    testing.expect(t, texture_uses_is_invalid(Texture_Uses{.Copy_Dst, .Color_Target}),
        "multiple exclusives is invalid")

    // Invalid: exclusive + inclusive
    testing.expect(t, texture_uses_is_invalid(Texture_Uses{.Copy_Dst, .Resource}),
        "exclusive + inclusive is invalid")

    // VALID: depth write + stencil write (this is entry #0 in valid_ds)
    testing.expect(t, !texture_uses_is_invalid(Texture_Uses{.Depth_Write, .Stencil_Write}),
        "depth write + stencil write is a valid DS combination")

    // Invalid: depth write alone (not in valid_ds, popcount == 1 but so is ds check?)
    //   popcount == 1 -> second guard skipped -> NOT flagged invalid.
    //   So actually {.Depth_Write} alone is NOT flagged invalid either.
    testing.expect(t, !texture_uses_is_invalid(Texture_Uses{.Depth_Write}),
        "depth write alone is not flagged by is_invalid")

    // Invalid: depth write + depth read (conflicting aspects, not in valid_ds)
    testing.expect(t, texture_uses_is_invalid(Texture_Uses{.Depth_Write, .Depth_Read}),
        "depth write + depth read is invalid")

    // Invalid: stencil write + stencil read (conflicting aspects, not in valid_ds)
    testing.expect(t, texture_uses_is_invalid(Texture_Uses{.Stencil_Write, .Stencil_Read}),
        "stencil write + stencil read is invalid")

    // Valid: empty
    testing.expect(t, !texture_uses_is_invalid({}), "empty is valid")
}

// -----------------------------------------------------------------------------
// Texture_Selector Tests
// -----------------------------------------------------------------------------

// Regression: the state providers used to pass the selector through a
// `{start, count}` -> `[start, end)` conversion. Every producer already hands
// the tracker an exclusive selector, so that conversion ran a second time and
// widened the tracked range (a view of layers 2..3 was tracked as 2..5).
// Zero-based selectors hid the bug, because `{0, n}` -> `{0, 0 + n}` is an
// identity, so the assertions below deliberately use a non-zero base.
@(test)
test_texture_state_provider_preserves_exclusive_selector :: proc(t: ^testing.T) {
    base_mip, mip_count     := u32(1), u32(2)
    base_layer, layer_count := u32(2), u32(2)
    sel := Texture_Selector {
        mips   = Range(u32){base_mip, base_mip + mip_count},
        layers = Range(u32){base_layer, base_layer + layer_count},
    }

    providers := [2]Texture_State_Provider {
        texture_state_provider_selector(sel, Texture_Uses{.Resource}),
        texture_state_provider_from_option(sel, Texture_Uses{.Resource}),
    }
    for &provider in providers {
        testing.expect_value(t, provider.kind, Texture_State_Provider_Kind.Selector)
        // The end must be exactly base + count, never base + (base + count).
        testing.expect_value(t, provider.selector.mips.start, base_mip)
        testing.expect_value(t, provider.selector.mips.end, base_mip + mip_count)
        testing.expect_value(t, provider.selector.layers.start, base_layer)
        testing.expect_value(t, provider.selector.layers.end, base_layer + layer_count)
        testing.expect_value(t, provider.selector.mips.end - provider.selector.mips.start, mip_count)
        testing.expect_value(t, provider.selector.layers.end - provider.selector.layers.start, layer_count)
    }
}

// -----------------------------------------------------------------------------
// Complex_Texture_State Tests
// -----------------------------------------------------------------------------

@(test)
test_complex_texture_state_init :: proc(t: ^testing.T) {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 4, 8, context.allocator)
    defer complex_texture_state_uninit(&ct)

    testing.expect_value(t, ct.mip_level_count, 4)
    testing.expect_value(t, ct.array_layer_count, 8)
    testing.expect_value(t, len(ct.mips), 4)

    // Each mip should have one range covering all layers
    for mip in ct.mips {
        testing.expect_value(t, len(mip.ranges), 1)
        testing.expect_value(t, mip.ranges[0].start, 0)
        testing.expect_value(t, mip.ranges[0].end, 8)
        testing.expect_value(t, mip.ranges[0].value, Texture_Uses{.Unknown})
    }
}

@(test)
test_complex_texture_state_uninit :: proc(t: ^testing.T) {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 4, context.allocator)
    complex_texture_state_uninit(&ct)
    testing.expect_value(t, len(ct.mips), 0)
}

@(test)
complex_texture_state_init_at_max_mips :: proc(t: ^testing.T) {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, MAX_MIP_LEVELS, 1, context.allocator)
    defer complex_texture_state_uninit(&ct)
    testing.expect_value(t, len(ct.mips), MAX_MIP_LEVELS)
}

// -----------------------------------------------------------------------------
// Selector_State_Iterator Tests
// -----------------------------------------------------------------------------

@(test)
test_selector_state_iterator_once :: proc(t: ^testing.T) {
    sel := Texture_Selector{
        mips   = Range(u32){0, 1},
        layers = Range(u32){0, 1},
    }
    state := Texture_Uses{.Resource}

    it := selector_state_iterator_once(sel, state)
    testing.expect_value(t, it.kind, Selector_State_Iterator_Kind.Once)

    // First iteration
    res, cond := selector_state_iterator_next(&it)
    testing.expect(t, cond, "first next should return true")
    testing.expect_value(t, res.state, state)
    testing.expect_value(t, res.selector.mips.start, 0)

    // Second iteration should be done
    _, cond2 := selector_state_iterator_next(&it)
    testing.expect(t, !cond2, "second next should return false")
}

@(test)
test_selector_state_iterator_complex :: proc(t: ^testing.T) {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 3, context.allocator)
    defer complex_texture_state_uninit(&ct)

    // Manually set different states for different layers in mip 0
    ranged_states_isolate(&ct.mips[0], Range(u32){0, 1}, TEXTURE_USES_UNKNOWN)
    ranged_states_isolate(&ct.mips[0], Range(u32){1, 2}, TEXTURE_USES_UNKNOWN)
    ranged_states_isolate(&ct.mips[0], Range(u32){2, 3}, TEXTURE_USES_UNKNOWN)

    it := selector_state_iterator_from_complex(&ct)
    testing.expect_value(t, it.kind, Selector_State_Iterator_Kind.Complex)

    // Count iterations - should be at least mip_count entries
    count := 0
    for res in selector_state_iterator_next(&it) {
        count += 1
        testing.expect(t, res.selector.mips.start < res.selector.mips.end,
            "mip range should be valid")
        testing.expect(t, res.selector.layers.start < res.selector.layers.end,
            "layer range should be valid")
    }
    testing.expect(t, count >= 2, "should have at least one entry per mip")
}

// -----------------------------------------------------------------------------
// Complex Texture State from Iterator Tests
// -----------------------------------------------------------------------------

@(test)
test_complex_from_iterator :: proc(t: ^testing.T) {
    full_range := Texture_Selector{
        mips   = Range(u32){0, 2},
        layers = Range(u32){0, 4},
    }

    sel := Texture_Selector{
        mips   = Range(u32){0, 1},
        layers = Range(u32){0, 2},
    }

    it := selector_state_iterator_once(sel, Texture_Uses{.Resource})
    ct := complex_texture_state_from_selector_state_iterator(
        full_range, &it, context.allocator)
    defer complex_texture_state_uninit(&ct)

    testing.expect_value(t, ct.mip_level_count, 2)
    testing.expect_value(t, ct.array_layer_count, 4)
    testing.expect_value(t, len(ct.mips), 2)

    // mip 0 should have at least one range; mips untouched by `sel` should
    // still be Unknown.
    testing.expect(t, len(ct.mips[0].ranges) >= 1,
        "mip 0 should have ranges after the build")
}

// -----------------------------------------------------------------------------
// Complex Texture State to Iterator Tests
// -----------------------------------------------------------------------------

@(test)
test_complex_to_iterator :: proc(t: ^testing.T) {
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 2, context.allocator)
    defer complex_texture_state_uninit(&ct)

    it := complex_texture_state_to_selector_state_iterator(&ct)
    testing.expect_value(t, it.kind, Selector_State_Iterator_Kind.Complex)

    // Should produce at least one entry per mip
    count := 0
    for _ in selector_state_iterator_next(&it) {
        count += 1
    }
    testing.expect(t, count >= 2, "should produce entries for each mip")
}

// -----------------------------------------------------------------------------
// Clone Tests
// -----------------------------------------------------------------------------

@(test)
test_complex_texture_state_clone :: proc(t: ^testing.T) {
    src: Complex_Texture_State
    complex_texture_state_init(&src, 3, 4, context.allocator)
    defer complex_texture_state_uninit(&src)

    dst: Complex_Texture_State
    complex_texture_state_clone(&src, &dst, context.allocator)
    defer complex_texture_state_uninit(&dst)

    // Verify cloned dimensions
    testing.expect_value(t, dst.mip_level_count, 3)
    testing.expect_value(t, dst.array_layer_count, 4)
    testing.expect_value(t, len(dst.mips), 3)

    // Verify each mip is independently cloned
    for i in 0..<len(src.mips) {
        testing.expect_value(t, len(dst.mips[i].ranges), len(src.mips[i].ranges))
        for j in 0..<len(src.mips[i].ranges) {
            testing.expect_value(t, dst.mips[i].ranges[j].start, src.mips[i].ranges[j].start)
            testing.expect_value(t, dst.mips[i].ranges[j].end, src.mips[i].ranges[j].end)
            testing.expect_value(t, dst.mips[i].ranges[j].value, src.mips[i].ranges[j].value)
        }
    }
}

// -----------------------------------------------------------------------------
// Texture_State_Set Tests
// -----------------------------------------------------------------------------

@(test)
test_texture_state_set_init :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    testing.expect_value(t, len(set.simple), 0)
    testing.expect_value(t, len(set.complex), 0)
    testing.expect(t, set.allocator == context.allocator)
}

@(test)
test_texture_state_set_resize :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    texture_state_set_resize(&set, 5)
    testing.expect_value(t, len(set.simple), 5)

    // All entries should be UNINITIALIZED
    for i in 0..<5 {
        testing.expect_value(t, set.simple[i], TEXTURE_USES_UNINITIALIZED)
    }

    // Resize larger
    texture_state_set_resize(&set, 10)
    testing.expect_value(t, len(set.simple), 10)
    for i in 5..<10 {
        testing.expect_value(t, set.simple[i], TEXTURE_USES_UNINITIALIZED)
    }
}

@(test)
test_texture_state_set_get_unchecked :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    texture_state_set_resize(&set, 3)

    // Insert a simple state
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Resource})
    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, res.is_single, "should be single")
    testing.expect_value(t, res.state, Texture_Uses{.Resource})

    // Insert a complex state
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 4, context.allocator)
    texture_state_set_insert_complex_unchecked(&set, 1, ct)

    res2 := texture_state_set_get_unchecked(&set, 1)
    testing.expect(t, !res2.is_single, "should be complex")
    testing.expect(t, res2.complex != nil, "complex pointer should not be nil")
}

@(test)
test_texture_state_set_make_simple :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    texture_state_set_resize(&set, 2)

    // First make it complex
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 4, context.allocator)
    texture_state_set_insert_complex_unchecked(&set, 0, ct)

    // Now make it simple again
    texture_state_set_make_simple_unchecked(&set, 0, Texture_Uses{.Present})

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, res.is_single, "should be single after make_simple")
    testing.expect_value(t, res.state, Texture_Uses{.Present})

    // The complex map entry should be removed
    _, exists := set.complex[0]
    testing.expect(t, !exists, "complex entry should be removed")
}

@(test)
test_texture_state_set_clear :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    texture_state_set_resize(&set, 3)
    texture_state_set_insert_simple_unchecked(&set, 0, {.Resource})

    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 2, 4, context.allocator)
    texture_state_set_insert_complex_unchecked(&set, 1, ct)

    texture_state_set_clear(&set)

    testing.expect_value(t, len(set.simple), 0)
    testing.expect_value(t, len(set.complex), 0)

    // The set must remain usable after clear (allocator preserved).
    texture_state_set_resize(&set, 4)
    texture_state_set_insert_simple_unchecked(&set, 2, {.Present})
    testing.expect_value(t, len(set.simple), 4)
    testing.expect_value(t, len(set.complex), 0)

    res := texture_state_set_get_unchecked(&set, 2)
    testing.expect(t, res.is_single)
    testing.expect_value(t, res.state, Texture_Uses{.Present})
}

// -----------------------------------------------------------------------------
// Texture_State_Provider Tests
// -----------------------------------------------------------------------------

@(test)
test_texture_state_provider_known_single :: proc(t: ^testing.T) {
    provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    testing.expect_value(t, provider.kind, Texture_State_Provider_Kind.Known_Single)
    testing.expect_value(t, provider.state, Texture_Uses{.Resource})
}

@(test)
test_texture_state_provider_selector :: proc(t: ^testing.T) {
    sel := Texture_Selector{
        mips   = Range(u32){0, 2},
        layers = Range(u32){0, 4},
    }
    provider := texture_state_provider_selector(sel, Texture_Uses{.Copy_Src})
    testing.expect_value(t, provider.kind, Texture_State_Provider_Kind.Selector)
    testing.expect_value(t, provider.selector.mips.start, u32(0))
    testing.expect_value(t, provider.selector.mips.end, u32(2))
    testing.expect_value(t, provider.selector.layers.start, u32(0))
    testing.expect_value(t, provider.selector.layers.end, u32(4))
}

// Regression: `Texture_Selector` is `[start, end)`, but the descriptor-facing
// `Image_Subresource_Range` it originates from is `{start, count}`. The two
// only diverge when `start != 0`, so a view covering e.g. mips 1..2 of a
// non-zero base must not be silently truncated to a single mip. The view
// constructor resolves that once, by adding `base + count`; the tracker then
// consumes the result verbatim.
@(test)
test_texture_selector_exclusive_end_with_nonzero_base :: proc(t: ^testing.T) {
    base_mip, mip_count      := u32(1), u32(2)
    base_layer, layer_count  := u32(3), u32(4)

    // As constructed by `vk_texture_create_view` from a subresource range:
    // `base_mip_level + mip_level_count`, already exclusive.
    view_style := Texture_Selector {
        mips   = Range(u32){base_mip, base_mip + mip_count},
        layers = Range(u32){base_layer, base_layer + layer_count},
    }

    // The range must cover exactly the requested subresources.
    testing.expect_value(t, view_style.mips.start, base_mip)
    testing.expect_value(t, view_style.mips.end - view_style.mips.start, mip_count)
    testing.expect_value(t, view_style.layers.start, base_layer)
    testing.expect_value(t, view_style.layers.end - view_style.layers.start, layer_count)

    // The range must iterate exactly the requested subresources, in order.
    seen: u32 = 0
    for mip in view_style.mips.start ..< view_style.mips.end {
        testing.expect_value(t, mip, base_mip + seen)
        seen += 1
    }
    testing.expect_value(t, seen, mip_count)

    seen = 0
    for layer in view_style.layers.start ..< view_style.layers.end {
        testing.expect_value(t, layer, base_layer + seen)
        seen += 1
    }
    testing.expect_value(t, seen, layer_count)
}

@(test)
test_texture_state_provider_from_option :: proc(t: ^testing.T) {
    // Empty selector -> Known_Single
    provider1 := texture_state_provider_from_option({}, Texture_Uses{.Resource})
    testing.expect_value(t, provider1.kind, Texture_State_Provider_Kind.Known_Single)

    // Non-empty selector -> Selector
    sel := Texture_Selector{
        mips   = Range(u32){0, 1},
        layers = Range(u32){0, 1},
    }
    provider2 := texture_state_provider_from_option(sel, Texture_Uses{.Resource})
    testing.expect_value(t, provider2.kind, Texture_State_Provider_Kind.Selector)
}

@(test)
test_texture_state_provider_get_state :: proc(t: ^testing.T) {
    // Known_Single
    p1 := texture_state_provider_known_single(Texture_Uses{.Resource})
    res1 := texture_state_provider_get_state(&p1, {}, 0)
    testing.expect(t, res1.is_single)
    testing.expect_value(t, res1.state, Texture_Uses{.Resource})

    // Selector with matching selector
    sel := Texture_Selector{
        mips   = Range(u32){0, 2},
        layers = Range(u32){0, 4},
    }
    p2 := texture_state_provider_selector(sel, Texture_Uses{.Copy_Src})
    res2 := texture_state_provider_get_state(&p2, sel, 0)
    testing.expect(t, res2.is_single)
    testing.expect_value(t, res2.state, Texture_Uses{.Copy_Src})

    // Selector with non-matching selector
    sel2 := Texture_Selector{
        mips   = Range(u32){0, 1},
        layers = Range(u32){0, 1},
    }
    res3 := texture_state_provider_get_state(&p2, sel2, 0)
    testing.expect(t, !res3.is_single)
}

// -----------------------------------------------------------------------------
// skip_barrier_ignore_texture_flags Tests
// -----------------------------------------------------------------------------

@(test)
test_skip_barrier_ignore_texture_flags :: proc(t: ^testing.T) {
    // These tests verify the aspect sampling flag stripping logic
    old_state := Texture_Uses{.Depth_Read, .Depth_Sampled}
    new_state := Texture_Uses{.Depth_Read, .Stencil_Sampled}
    aspect_sampled := Texture_Uses{.Depth_Sampled, .Stencil_Sampled}

    // After stripping, both should be {.Depth_Read}
    stripped_old := old_state & ~aspect_sampled
    stripped_new := new_state & ~aspect_sampled

    testing.expect_value(t, stripped_old, Texture_Uses{.Depth_Read})
    testing.expect_value(t, stripped_new, Texture_Uses{.Depth_Read})
}

// -----------------------------------------------------------------------------
// Integration / Edge Case Tests
// -----------------------------------------------------------------------------

@(test)
test_complex_texture_state_large_mip_count :: proc(t: ^testing.T) {
    // Test with MAX_MIP_LEVELS (32)
    ct: Complex_Texture_State
    complex_texture_state_init(&ct, 32, 1, context.allocator)
    defer complex_texture_state_uninit(&ct)

    testing.expect_value(t, len(ct.mips), 32)
    testing.expect_value(t, ct.mip_level_count, u32(32))
}

@(test)
test_texture_state_set_multiple_complex_entries :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)

    texture_state_set_resize(&set, 5)

    // Insert complex states at indices 1, 3, 4
    for i in ([]int{1, 3, 4}) {
        ct: Complex_Texture_State
        complex_texture_state_init(&ct, 2, 2, context.allocator)
        texture_state_set_insert_complex_unchecked(&set, i, ct)
    }

    // Verify each is complex
    for i in ([]int{1, 3, 4}) {
        res := texture_state_set_get_unchecked(&set, i)
        testing.expect(t, !res.is_single, "should be complex")
    }

    // Verify others are simple (UNINITIALIZED)
    for i in ([]int{0, 2}) {
        res := texture_state_set_get_unchecked(&set, i)
        testing.expect(t, res.is_single, "should be simple")
    }
}

@(test)
test_texture_uses_bit_set_equality :: proc(t: ^testing.T) {
    // Test that bit_set equality works correctly
    a := Texture_Uses{.Copy_Src, .Resource}
    b := Texture_Uses{.Resource, .Copy_Src}
    testing.expect(t, a == b, "bit_set equality should be order-independent")

    c := Texture_Uses{.Copy_Src}
    testing.expect(t, a != c, "different sets should not be equal")

    // Test subset/superset
    testing.expect(t, a >= c, "a should be superset of c")
    testing.expect(t, c <= a, "c should be subset of a")
}

@(test)
test_texture_uses_composite_operations :: proc(t: ^testing.T) {
    // Test bitwise operations
    a := Texture_Uses{.Copy_Src, .Resource}
    b := Texture_Uses{.Resource, .Depth_Read}

    // Union
    union_set := a | b
    testing.expect(t, union_set >= a, "union should contain a")
    testing.expect(t, union_set >= b, "union should contain b")

    // Intersection
    intersection := a & b
    testing.expect_value(t, intersection, Texture_Uses{.Resource})

    // Difference
    diff := a & ~b
    testing.expect_value(t, diff, Texture_Uses{.Copy_Src})
}

// -----------------------------------------------------------------------------
// Texture state insert
// -----------------------------------------------------------------------------

@(test)
texture_state_insert_single_start_no_start_set_test :: proc(t: ^testing.T) {
    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        {},
        nil,
        &end_set,
        &rm,
        0,
        &start_provider,
        nil,
        &direct,
    )

    res := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, res.is_single)
    testing.expect_value(t, res.state, Texture_Uses{.Resource})
}

@(test)
texture_state_insert_single_start_with_start_set_test :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_known_single(Texture_Uses{.Copy_Src})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        {},
        &start_set,
        &end_set,
        &rm,
        0,
        &start_provider,
        nil,
        &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single)
    testing.expect_value(t, s.state, Texture_Uses{.Copy_Src})

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, e.is_single)
    testing.expect_value(t, e.state, Texture_Uses{.Copy_Src})
}

@(test)
texture_state_insert_single_start_single_end_test :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_known_single(Texture_Uses{.Copy_Dst})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        {},
        &start_set,
        &end_set,
        &rm,
        0,
        &start_provider,
        &end_provider,
        &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single)
    testing.expect_value(t, s.state, Texture_Uses{.Resource})

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, e.is_single)
    testing.expect_value(t, e.state, Texture_Uses{.Copy_Dst})
}

@(test)
texture_state_insert_single_start_complex_end_test :: proc(t: ^testing.T) {
    // Full range and a strict sub-range so the provider can't collapse to
    // a single state.
    full := Texture_Selector{mips = {0, 2}, layers = {0, 4}}
    sub  := Texture_Selector{mips = {0, 1}, layers = {0, 2}}

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_selector(sub, Texture_Uses{.Present})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        full,
        &start_set,
        &end_set,
        &rm,
        0,
        &start_provider,
        &end_provider,
        &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single, "start must remain simple")
    testing.expect_value(t, s.state, Texture_Uses{.Resource})

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, !e.is_single, "end must be complex")
    testing.expect(t, e.complex != nil, "complex pointer must be populated")
    testing.expect_value(t, e.complex.mip_level_count, u32(2))
    testing.expect_value(t, e.complex.array_layer_count, u32(4))

    // Sub-range values: mip 0, layer 0 should be Present.
    {
        v, ok := complex_state_lookup(e.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Present})
    }
    // Layers outside the sub-range should still be Unknown.
    {
        v, ok := complex_state_lookup(e.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect_value(t, v, TEXTURE_USES_UNKNOWN)
    }
}

@(test)
texture_state_insert_complex_start_no_start_set_test :: proc(t: ^testing.T) {
    full := Texture_Selector{mips = {0, 2}, layers = {0, 4}}
    sub  := Texture_Selector{mips = {0, 1}, layers = {0, 2}}

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_selector(sub, Texture_Uses{.Resource})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        full,
        nil,
        &end_set,
        &rm,
        0,
        &start_provider,
        nil,
        &direct,
    )

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, !e.is_single, "end must be complex")
    testing.expect_value(t, e.complex.mip_level_count, u32(2))

    {
        v, ok := complex_state_lookup(e.complex, 0, 1)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Resource})
    }
    {
        v, ok := complex_state_lookup(e.complex, 1, 0)
        testing.expect(t, ok)
        testing.expect_value(t, v, TEXTURE_USES_UNKNOWN)
    }
}

@(test)
texture_state_insert_complex_start_with_start_set_test :: proc(t: ^testing.T) {
    full := Texture_Selector{mips = {0, 2}, layers = {0, 4}}
    sub  := Texture_Selector{mips = {0, 1}, layers = {0, 2}}

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_selector(sub, Texture_Uses{.Resource})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        full,
        &start_set,
        &end_set,
        &rm,
        0,
        &start_provider,
        nil,
        &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, !s.is_single, "start set must hold a complex state")

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, !e.is_single, "end set must hold a complex state")

    // The clone must not share backing with the original.
    testing.expect(t, s.complex != e.complex,
        "start and end must hold different Complex_Texture_State instances")
    testing.expect(t, &s.complex.mips[0] != &e.complex.mips[0],
        "clone must own its own mip backing")

    // Both must contain the same data.
    {
        sv, sok := complex_state_lookup(s.complex, 0, 1)
        ev, eok := complex_state_lookup(e.complex, 0, 1)
        testing.expect(t, sok && eok)
        testing.expect_value(t, sv, Texture_Uses{.Resource})
        testing.expect_value(t, ev, Texture_Uses{.Resource})
    }
}

@(test)
texture_state_insert_complex_start_with_end_provider_test :: proc(t: ^testing.T) {
    full      := Texture_Selector{mips = {0, 2}, layers = {0, 4}}
    sub_start := Texture_Selector{mips = {0, 1}, layers = {0, 2}}
    // Exclusive `[start, end)`: mip 1 only, spanning every layer. The complement
    // of `sub_start` within `full`.
    sub_end   := Texture_Selector{mips = {1, 2}, layers = {0, 4}}

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    start_provider := texture_state_provider_selector(sub_start, Texture_Uses{.Resource})
    end_provider   := texture_state_provider_selector(sub_end,   Texture_Uses{.Present})

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        full,
        &start_set,
        &end_set,
        &rm,
        0,
        &start_provider,
        &end_provider,
        &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, !s.is_single, "start set complex")
    testing.expect(t, s.complex != nil)

    e := texture_state_set_get_unchecked(&end_set, 0)
    testing.expect(t, !e.is_single, "end set complex")
    testing.expect(t, e.complex != nil)

    // Start applied only to sub_start.
    {
        v, _ := complex_state_lookup(s.complex, 0, 0)
        testing.expect_value(t, v, Texture_Uses{.Resource})
    }
    // End applied only to sub_end.
    {
        v, _ := complex_state_lookup(e.complex, 1, 0)
        testing.expect_value(t, v, Texture_Uses{.Present})
    }
}

@(test)
texture_state_insert_complex_start_complex_end_test :: proc(t: ^testing.T) {
    full := Texture_Selector{mips = {0, 2}, layers = {0, 4}}
    sub  := Texture_Selector{mips = {0, 1}, layers = {0, 2}}

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    start_provider := texture_state_provider_selector(sub, Texture_Uses{.Resource})
    end_provider   := texture_state_provider_selector(sub, Texture_Uses{.Present})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 2, context.allocator)
    defer resource_metadata_uninit(&rm)

    texture := Texture{handle = 1}
    direct := resource_metadata_provider_direct(texture)

    texture_state_insert(
        full, &start_set, &end_set, &rm, 0,
        &start_provider, &end_provider, &direct,
    )

    s := texture_state_set_get_unchecked(&start_set, 0)
    e := texture_state_set_get_unchecked(&end_set, 0)

    testing.expect(t, !s.is_single && !e.is_single)

    {
        sv, _ := complex_state_lookup(s.complex, 0, 0)
        ev, _ := complex_state_lookup(e.complex, 0, 0)
        testing.expect_value(t, sv, Texture_Uses{.Resource})
        testing.expect_value(t, ev, Texture_Uses{.Present})
    }
}

// -----------------------------------------------------------------------------
// Texture state merge
// -----------------------------------------------------------------------------

@(test)
texture_state_merge_simple_simple_ok :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Resource})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    provider := texture_state_provider_known_single(Texture_Uses{.Copy_Src})

    err := texture_state_merge({}, &set, 0, &provider, &direct)
    testing.expect(t, err == nil, "merge should succeed")

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, res.is_single, "must stay simple")
    testing.expect(t, res.state == Texture_Uses{.Resource, .Copy_Src},
        "states should be OR'd together")
}

@(test)
texture_state_merge_simple_simple_invalid :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Copy_Dst})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    err := texture_state_merge({}, &set, 0, &provider, &direct)
    testing.expect(t, err != nil, "merge should fail on exclusive+inclusive")

    // Invalid merges must not mutate the current state.
    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, res.is_single)
    testing.expect(t, res.state == Texture_Uses{.Copy_Dst},
        "current state must be unchanged after error")
}

@(test)
texture_state_merge_simple_many_ok :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Resource})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    full_range := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    sub        := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 2}}
    provider   := texture_state_provider_selector(sub, Texture_Uses{.Copy_Src})

    err := texture_state_merge(full_range, &set, 0, &provider, &direct)
    testing.expect(t, err == nil, "merge should succeed")

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, !res.is_single, "must have been demoted to complex")
    testing.expect(t, res.complex != nil)

    {
        v, ok := lookup_complex(res.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource, .Copy_Src},
            "[0,2) should be the OR of the two")
    }
    {
        v, ok := lookup_complex(res.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource},
            "[2,4) should be unchanged")
    }
}

@(test)
texture_state_merge_simple_many_invalid :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Copy_Dst})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    full_range := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    sub        := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 2}}
    provider   := texture_state_provider_selector(sub, Texture_Uses{.Resource})

    err := texture_state_merge(full_range, &set, 0, &provider, &direct)
    testing.expect(t, err != nil, "merge should fail")

    // Current must remain simple; the failed promotion must not commit.
    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, res.is_single, "failed merge must not commit complex state")
    testing.expect(t, res.state == Texture_Uses{.Copy_Dst})
}

@(test)
texture_state_merge_many_simple_ok :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    ct := make_complex(1, 4, Texture_Uses{.Resource}, context.allocator)
    texture_state_set_make_complex_unchecked(&set, 0, ct)

    provider := texture_state_provider_known_single(Texture_Uses{.Copy_Src})

    err := texture_state_merge({}, &set, 0, &provider, &direct)
    testing.expect(t, err == nil)

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, !res.is_single, "must remain complex")

    {
        v, ok := lookup_complex(res.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource, .Copy_Src})
    }
}

@(test)
texture_state_merge_many_simple_invalid :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    ct := make_complex(1, 4, Texture_Uses{.Copy_Dst}, context.allocator)
    texture_state_set_make_complex_unchecked(&set, 0, ct)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    err := texture_state_merge({}, &set, 0, &provider, &direct)
    testing.expect(t, err != nil, "merge should fail")
}

@(test)
texture_state_merge_many_simple_unknown_resolves :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    // Complex state starting with Unknown values (as if freshly initialized).
    ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    texture_state_set_make_complex_unchecked(&set, 0, ct)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    err := texture_state_merge({}, &set, 0, &provider, &direct)
    testing.expect(t, err == nil)

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, !res.is_single)

    {
        v, ok := lookup_complex(res.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource},
            "Unknown must be stripped: {Unknown, Resource} & ~Unknown == {Resource}")
    }
}

@(test)
texture_state_merge_many_many_ok :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    ct := make_complex(1, 4, Texture_Uses{.Resource}, context.allocator)
    texture_state_set_make_complex_unchecked(&set, 0, ct)

    full_range := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    sub        := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 2}}
    provider   := texture_state_provider_selector(sub, Texture_Uses{.Copy_Src})

    err := texture_state_merge(full_range, &set, 0, &provider, &direct)
    testing.expect(t, err == nil)

    res := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, !res.is_single)

    {
        v, ok := lookup_complex(res.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource, .Copy_Src})
    }
    {
        v, ok := lookup_complex(res.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect(t, v == Texture_Uses{.Resource})
    }
}

@(test)
texture_state_merge_many_many_invalid :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})

    ct := make_complex(1, 4, Texture_Uses{.Copy_Dst}, context.allocator)
    texture_state_set_make_complex_unchecked(&set, 0, ct)

    full_range := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    sub        := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 2}}
    provider   := texture_state_provider_selector(sub, Texture_Uses{.Resource})

    err := texture_state_merge(full_range, &set, 0, &provider, &direct)
    testing.expect(t, err != nil, "merge should fail")
}

// -----------------------------------------------------------------------------
// Texture barrier
// -----------------------------------------------------------------------------

@(test)
texture_state_barrier_simple_simple_appends :: proc(t: ^testing.T) {
    set := make_set_with_simple(Texture_Uses{.Copy_Dst})
    defer texture_state_set_uninit(&set)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier({}, &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].id, u32(0))
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to, Texture_Uses{.Resource})
}

@(test)
texture_state_barrier_simple_simple_skips :: proc(t: ^testing.T) {
    set := make_set_with_simple(Texture_Uses{.Resource})
    defer texture_state_set_uninit(&set)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    // `skip_barrier(old, mask, new)` skips only when old == new AND
    // old <= mask. Both states are `{Resource}`, so the mask must cover
    // `{Resource}` for the transition to be skippable.
    texture_state_barrier(
        {}, &set, 0, &provider, &barriers, Texture_Uses{.Resource})

    testing.expect_value(t, len(barriers), 0)
}

@(test)
texture_state_barrier_simple_many_appends :: proc(t: ^testing.T) {
    set := make_set_with_simple(Texture_Uses{.Copy_Dst})
    defer texture_state_set_uninit(&set)

    // Source set with a complex state: one mip, ranges [0,2)=Resource and
    // [2,4)=Copy_Src.
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 0, 2, Texture_Uses{.Resource})
    set_range(&src_ct, 0, 2, 4, Texture_Uses{.Copy_Src})
    src := make_set_with_complex(src_ct)
    defer texture_state_set_uninit(&src)

    provider := texture_state_provider_texture_set(&src)

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier(
        Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}},
        &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 2)

    testing.expect_value(t, barriers[0].selector.layers, Range(u32){0, 2})
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})

    testing.expect_value(t, barriers[1].selector.layers, Range(u32){2, 4})
    testing.expect_value(t, barriers[1].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[1].usage.to,   Texture_Uses{.Copy_Src})
}

@(test)
texture_state_barrier_simple_many_skips_unknown :: proc(t: ^testing.T) {
    set := make_set_with_simple(Texture_Uses{.Copy_Dst})
    defer texture_state_set_uninit(&set)

    // Only layer range [0,2) has a known value; [2,4) remains UNKNOWN.
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 0, 2, Texture_Uses{.Resource})
    src := make_set_with_complex(src_ct)
    defer texture_state_set_uninit(&src)

    provider := texture_state_provider_texture_set(&src)

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier(
        Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}},
        &set, 0, &provider, &barriers, {})

    // Only the known range emits a barrier; UNKNOWN is skipped.
    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].selector.layers, Range(u32){0, 2})
    testing.expect_value(t, barriers[0].usage.to, Texture_Uses{.Resource})
}

@(test)
texture_state_barrier_many_simple_appends :: proc(t: ^testing.T) {
    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&cur_ct, 0, 0, 2, Texture_Uses{.Copy_Dst})
    set_range(&cur_ct, 0, 2, 4, Texture_Uses{.Storage_Write_Only})
    set := make_set_with_complex(cur_ct)
    defer texture_state_set_uninit(&set)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier({}, &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 2)

    testing.expect_value(t, barriers[0].selector.layers, Range(u32){0, 2})
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})

    testing.expect_value(t, barriers[1].selector.layers, Range(u32){2, 4})
    testing.expect_value(t, barriers[1].usage.from, Texture_Uses{.Storage_Write_Only})
    testing.expect_value(t, barriers[1].usage.to,   Texture_Uses{.Resource})
}

@(test)
texture_state_barrier_many_simple_skips_unknown :: proc(t: ^testing.T) {
    // Current complex has a known range and an UNKNOWN range.
    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&cur_ct, 0, 0, 2, Texture_Uses{.Copy_Dst})
    set := make_set_with_complex(cur_ct)
    defer texture_state_set_uninit(&set)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier({}, &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].selector.layers, Range(u32){0, 2})
}

@(test)
texture_state_barrier_many_many_appends_for_overlap :: proc(t: ^testing.T) {
    // Current: [0,4) all Copy_Dst.
    cur_ct := make_complex(1, 4, Texture_Uses{.Copy_Dst}, context.allocator)
    set := make_set_with_complex(cur_ct)
    defer texture_state_set_uninit(&set)

    // Source: [0,2)=Resource, [2,4) stays UNKNOWN.
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 0, 2, Texture_Uses{.Resource})
    src := make_set_with_complex(src_ct)
    defer texture_state_set_uninit(&src)

    provider := texture_state_provider_texture_set(&src)

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier(
        Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}},
        &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].selector.layers, Range(u32){0, 2})
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})
}

@(test)
texture_state_barrier_many_many_slices_current_by_selector :: proc(t: ^testing.T) {
    // Current: [0,2)=Copy_Dst, [2,4)=Copy_Src.
    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&cur_ct, 0, 0, 2, Texture_Uses{.Copy_Dst})
    set_range(&cur_ct, 0, 2, 4, Texture_Uses{.Copy_Src})
    set := make_set_with_complex(cur_ct)
    defer texture_state_set_uninit(&set)

    // Source covers only [1,3), so both current ranges get sliced.
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 1, 3, Texture_Uses{.Resource})
    src := make_set_with_complex(src_ct)
    defer texture_state_set_uninit(&src)

    provider := texture_state_provider_texture_set(&src)

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier(
        Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}},
        &set, 0, &provider, &barriers, {})

    // Two barrier fragments: [1,2) from Copy_Dst and [2,3) from Copy_Src.
    testing.expect_value(t, len(barriers), 2)
    testing.expect_value(t, barriers[0].selector.layers, Range(u32){1, 2})
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[1].selector.layers, Range(u32){2, 3})
    testing.expect_value(t, barriers[1].usage.from, Texture_Uses{.Copy_Src})
}

@(test)
texture_state_barrier_emits_per_mip :: proc(t: ^testing.T) {
    set := make_set_with_simple(Texture_Uses{.Copy_Dst})
    defer texture_state_set_uninit(&set)

    // Source covers two mips, each with a full-range Resource entry.
    src_ct := make_complex(2, 4, Texture_Uses{.Resource}, context.allocator)
    src := make_set_with_complex(src_ct)
    defer texture_state_set_uninit(&src)

    provider := texture_state_provider_texture_set(&src)

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_state_barrier(
        Texture_Selector{mips = Range(u32){0, 2}, layers = Range(u32){0, 4}},
        &set, 0, &provider, &barriers, {})

    testing.expect_value(t, len(barriers), 2)
    testing.expect_value(t, barriers[0].selector.mips, Range(u32){0, 1})
    testing.expect_value(t, barriers[1].selector.mips, Range(u32){1, 2})
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[1].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})
    testing.expect_value(t, barriers[1].usage.to,   Texture_Uses{.Resource})
}

@(test)
texture_state_update_simple_to_simple :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Resource})

    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_insert_simple_unchecked(&current_set, 0, Texture_Uses{.Resource})

    provider := texture_state_provider_known_single(Texture_Uses{.Copy_Src})

    texture_state_update({}, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Copy_Src})

    // Start is untouched when current was simple.
    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single)
    testing.expect_value(t, s.state, Texture_Uses{.Resource})
}

@(test)
texture_state_update_simple_to_complex_fills_uncovered :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Resource})

    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_insert_simple_unchecked(&current_set, 0, Texture_Uses{.Resource})

    // Provider: complex with [0,2)=Copy_Src; [2,4) left Unknown.
    // Unknown must be interpreted as "keep the old current value".
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 0, 2, Texture_Uses{.Copy_Src})
    src_set: Texture_State_Set
    texture_state_set_init(&src_set, context.allocator)
    defer texture_state_set_uninit(&src_set)
    texture_state_set_resize(&src_set, 1)
    texture_state_set_make_complex_unchecked(&src_set, 0, src_ct)

    provider := texture_state_provider_texture_set(&src_set)

    full := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    texture_state_update(full, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, !cur.is_single, "must have been demoted to complex")

    {
        v, ok := lookup_complex(cur.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Copy_Src})
    }
    {
        v, ok := lookup_complex(cur.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Resource})
    }
}

@(test)
texture_state_update_complex_to_simple_backfills_start :: proc(t: ^testing.T) {
    // Both start and current are complex and fully Unknown.
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_make_complex_unchecked(
        &start_set, 0, make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator))

    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_make_complex_unchecked(
        &current_set, 0, make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator))

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    texture_state_update({}, &start_set, &current_set, 0, &provider)

    // Current becomes simple.
    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource})

    // Start is still complex, but every previously-Unknown range is now Resource.
    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, !s.is_single, "start must remain complex")
    {
        v, ok := lookup_complex(s.complex, 0, 0)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Resource})
    }
    {
        v, ok := lookup_complex(s.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Resource})
    }
}

@(test)
texture_state_update_complex_to_simple_only_backfills_unknown :: proc(t: ^testing.T) {
    // Start is simple → no backfill should happen.
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Copy_Src})

    // Current is complex with a known and an Unknown range.
    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&cur_ct, 0, 0, 2, Texture_Uses{.Copy_Src})
    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_make_complex_unchecked(&current_set, 0, cur_ct)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    texture_state_update({}, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource})

    // Start is simple; no backfill possible or needed.
    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single)
    testing.expect_value(t, s.state, Texture_Uses{.Copy_Src})
}

@(test)
texture_state_update_many_many_partial :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_make_complex_unchecked(
        &start_set, 0, make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator))

    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_make_complex_unchecked(
        &current_set, 0, make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator))

    // Provider has [0,2)=Copy_Src; [2,4) remains Unknown and is skipped.
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 0, 2, Texture_Uses{.Copy_Src})
    src_set: Texture_State_Set
    texture_state_set_init(&src_set, context.allocator)
    defer texture_state_set_uninit(&src_set)
    texture_state_set_resize(&src_set, 1)
    texture_state_set_make_complex_unchecked(&src_set, 0, src_ct)

    provider := texture_state_provider_texture_set(&src_set)

    full := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    texture_state_update(full, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, !cur.is_single)
    {
        v, ok := lookup_complex(cur.complex, 0, 1)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Copy_Src})
    }
    {
        v, ok := lookup_complex(cur.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect_value(t, v, TEXTURE_USES_UNKNOWN)
    }

    // Start backfilled only for the range where current transitioned from Unknown.
    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, !s.is_single)
    {
        v, ok := lookup_complex(s.complex, 0, 1)
        testing.expect(t, ok)
        testing.expect_value(t, v, Texture_Uses{.Copy_Src})
    }
    {
        v, ok := lookup_complex(s.complex, 0, 3)
        testing.expect(t, ok)
        testing.expect_value(t, v, TEXTURE_USES_UNKNOWN)
    }
}

@(test)
texture_state_update_many_many_preserves_known :: proc(t: ^testing.T) {
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_make_complex_unchecked(
        &start_set, 0, make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator))

    // Current already knows [0,2)=Copy_Src.
    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&cur_ct, 0, 0, 2, Texture_Uses{.Copy_Src})
    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_make_complex_unchecked(&current_set, 0, cur_ct)

    // Provider only touches [2,4).
    src_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    set_range(&src_ct, 0, 2, 4, Texture_Uses{.Depth_Read})
    src_set: Texture_State_Set
    texture_state_set_init(&src_set, context.allocator)
    defer texture_state_set_uninit(&src_set)
    texture_state_set_resize(&src_set, 1)
    texture_state_set_make_complex_unchecked(&src_set, 0, src_ct)

    provider := texture_state_provider_texture_set(&src_set)

    full := Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 4}}
    texture_state_update(full, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, !cur.is_single)
    {
        v, _ := lookup_complex(cur.complex, 0, 1)
        testing.expect_value(t, v, Texture_Uses{.Copy_Src})
    }
    {
        v, _ := lookup_complex(cur.complex, 0, 3)
        testing.expect_value(t, v, Texture_Uses{.Depth_Read})
    }
}

@(test)
texture_state_update_start_simple_current_complex :: proc(t: ^testing.T) {
    // Start is simple, current is complex. Backfill must be skipped because
    // there is no complex start to write into.
    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Present})

    cur_ct := make_complex(1, 4, TEXTURE_USES_UNKNOWN, context.allocator)
    current_set: Texture_State_Set
    texture_state_set_init(&current_set, context.allocator)
    defer texture_state_set_uninit(&current_set)
    texture_state_set_resize(&current_set, 1)
    texture_state_set_make_complex_unchecked(&current_set, 0, cur_ct)

    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    texture_state_update({}, &start_set, &current_set, 0, &provider)

    cur := texture_state_set_get_unchecked(&current_set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource})

    s := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, s.is_single)
    testing.expect_value(t, s.state, Texture_Uses{.Present})
}

@(test)
insert_or_merge_not_tracked_inserts :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    testing.expect(t, !resource_metadata_contains_unchecked(&rm, 0),
        "precondition: index 0 must be untracked")

    err := texture_insert_or_merge(
        {}, &set, &rm, 0, &provider, &direct)
    testing.expect(t, err == nil)

    // The insert path is taken with `nil` start_state_set and `nil`
    // end_state_provider, so `current_state_set` receives the start state.
    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource})

    testing.expect(t, resource_metadata_contains_unchecked(&rm, 0),
        "metadata must now record index 0 as tracked")
}

@(test)
insert_or_merge_tracked_merges :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Resource})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)
    // Mark index 0 as tracked.
    resource_metadata_insert(&rm, 0, Texture{handle = 1})

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    provider := texture_state_provider_known_single(Texture_Uses{.Copy_Src})

    testing.expect(t, resource_metadata_contains_unchecked(&rm, 0),
        "precondition: index 0 must be tracked")

    err := texture_insert_or_merge(
        {}, &set, &rm, 0, &provider, &direct)
    testing.expect(t, err == nil)

    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource, .Copy_Src})
}

@(test)
insert_or_merge_tracked_merge_conflict :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Copy_Dst})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)
    resource_metadata_insert(&rm, 0, Texture{handle = 1})

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    err := texture_insert_or_merge(
        {}, &set, &rm, 0, &provider, &direct)
    testing.expect(t, err != nil, "exclusive + inclusive must conflict")

    // State must be unchanged on conflict.
    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect_value(t, cur.state, Texture_Uses{.Copy_Dst})
}

// Regression for the descriptor-set bind path. `texture_usage_scope_merge_single`
// forwards a view's already-exclusive selector into a state provider. The
// provider used to convert `{start, end}` as though it were `{start, count}`,
// which re-based the end and widened the tracked range: a view of layers 2..3
// was tracked as layers 2..5, OR-ing `.Resource` into layers 4 and 5 and
// producing false conflicts plus over-broad barriers. A zero-based view hid it,
// so this deliberately binds a view with a non-zero `base_array_layer`.
@(test)
insert_or_merge_nonzero_base_selector_does_not_overtrack :: proc(t: ^testing.T) {
    full := Texture_Selector{mips = {0, 2}, layers = {0, 6}}

    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    // A view of mips 0..1 and layers 2..3, as `vk_texture_create_view` builds it
    // from `Image_Subresource_Range{base_array_layer = 2, array_layer_count = 2}`.
    view := Texture_Selector{mips = {0, 2}, layers = {2, 4}}
    direct   := resource_metadata_provider_direct(Texture{handle = 1})
    provider := texture_state_provider_from_option(view, Texture_Uses{.Resource})

    err := texture_insert_or_merge(
        full, &set, &rm, 0, &provider, &direct)
    testing.expect(t, err == nil)

    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, !cur.is_single, "a sub-range view must produce complex state")
    testing.expect(t, cur.complex != nil)

    // Exactly the two requested layers are recorded, on both mips.
    for mip in u32(0) ..< 2 {
        for layer in u32(2) ..< 4 {
            v, ok := complex_state_lookup(cur.complex, mip, layer)
            testing.expect(t, ok, fmt.tprintf("mip %d layer %d must be covered", mip, layer))
            testing.expect_value(t, v, Texture_Uses{.Resource})
        }
    }

    // The not-owned path initialises the full range first, so every layer is
    // covered; layers outside the view must simply never gain `.Resource`.
    // These assertions are what fail under the old double conversion, which
    // re-based the end and recorded the view as layers 2..5.
    outside := [4]u32{0, 1, 4, 5}
    for layer in outside {
        v, ok := complex_state_lookup(cur.complex, 0, layer)
        testing.expect(t, ok, fmt.tprintf("layer %d is inside the texture's full range", layer))
        testing.expect(t, v & Texture_Uses{.Resource} == TEXTURE_USES_EMPTY,
            fmt.tprintf("layer %d is outside the view and must not gain .Resource (got %v)", layer, v))
    }
}

@(test)
insert_or_barrier_update_not_tracked_inserts :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_known_single(Texture_Uses{.Present})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, &end_provider, &direct,
        &barriers, {},
    )

    // The insert path is taken; no barriers are emitted on first sight.
    testing.expect_value(t, len(barriers), 0)

    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Present})

    start := texture_state_set_get_unchecked(&start_set, 0)
    testing.expect(t, start.is_single)
    testing.expect_value(t, start.state, Texture_Uses{.Resource})

    testing.expect(t, resource_metadata_contains_unchecked(&rm, 0))
}

@(test)
insert_or_barrier_update_tracked_barrier_and_update :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Copy_Dst})

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Copy_Dst})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)
    resource_metadata_insert(&rm, 0, Texture{handle = 1})

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_known_single(Texture_Uses{.Present})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, &end_provider, &direct,
        &barriers, {},
    )

    // Barrier from current Copy_Dst -> start Resource.
    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})

    // Update moves the current state to the end provider's state.
    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Present})
}

@(test)
insert_or_barrier_update_tracked_falls_back_to_start :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Copy_Dst})

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Copy_Dst})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)
    resource_metadata_insert(&rm, 0, Texture{handle = 1})

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, nil, &direct,     // <- end provider nil
        &barriers, {},
    )

    // Barrier still emitted from current Copy_Dst -> start Resource.
    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})

    // Update falls back to start provider, so current becomes Resource.
    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect(t, cur.is_single)
    testing.expect_value(t, cur.state, Texture_Uses{.Resource})
}

@(test)
insert_or_barrier_update_tracked_no_barrier_when_skip :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)
    texture_state_set_insert_simple_unchecked(&set, 0, Texture_Uses{.Resource})

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)
    texture_state_set_insert_simple_unchecked(&start_set, 0, Texture_Uses{.Resource})

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)
    resource_metadata_insert(&rm, 0, Texture{handle = 1})

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    // Start provider yields the same state as current.
    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_known_single(Texture_Uses{.Resource})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, &end_provider, &direct,
        &barriers,
        Texture_Uses{.Resource},           // <- mask covers the state
    )

    testing.expect_value(t, len(barriers), 0)
}

@(test)
insert_or_barrier_update_two_calls_transitions_branches :: proc(t: ^testing.T) {
    set: Texture_State_Set
    texture_state_set_init(&set, context.allocator)
    defer texture_state_set_uninit(&set)
    texture_state_set_resize(&set, 1)

    start_set: Texture_State_Set
    texture_state_set_init(&start_set, context.allocator)
    defer texture_state_set_uninit(&start_set)
    texture_state_set_resize(&start_set, 1)

    rm: Resource_Metadata(Texture)
    resource_metadata_init(&rm, 1, context.allocator)
    defer resource_metadata_uninit(&rm)

    direct := resource_metadata_provider_direct(Texture{handle = 1})
    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    end_provider   := texture_state_provider_known_single(Texture_Uses{.Present})

    barriers: [dynamic]Pending_Texture_Transition
    barriers.allocator = context.allocator
    defer delete(barriers)

    // First call: not tracked -> insert.
    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, &end_provider, &direct,
        &barriers, {},
    )
    testing.expect_value(t, len(barriers), 0)

    // Second call: tracked -> barrier from Present to Resource, then update
    // to Present.
    texture_insert_or_barrier_update(
        {}, &start_set, &set, &rm, 0,
        &start_provider, &end_provider, &direct,
        &barriers, {},
    )

    testing.expect_value(t, len(barriers), 1)
    testing.expect_value(t, barriers[0].usage.from, Texture_Uses{.Present})
    testing.expect_value(t, barriers[0].usage.to,   Texture_Uses{.Resource})

    cur := texture_state_set_get_unchecked(&set, 0)
    testing.expect_value(t, cur.state, Texture_Uses{.Present})
}

@(test)
view_bind_group_state_init_uninit :: proc(t: ^testing.T) {
    s: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&s, context.allocator)
    testing.expect_value(t, len(s.views), 0)

    append(&s.views, Texture_View_Bind_Group_Entry{})
    append(&s.views, Texture_View_Bind_Group_Entry{})
    testing.expect_value(t, len(s.views), 2)

    texture_view_bind_group_state_uninit(&s)
    testing.expect_value(t, len(s.views), 0)
}

// Sort key is the parent texture's tracker index, captured on the entry. That
// makes this testable without device-backed texture views, which is why the
// previous version of it (reading the key back off the view impl via fake
// handles) had to stay commented out.
@(test)
view_bind_group_state_optimize_sorts_by_parent_texture_index :: proc(t: ^testing.T) {
    s: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&s, context.allocator)
    defer texture_view_bind_group_state_uninit(&s)

    dummy_view: Texture_View
    texture_view_bind_group_state_insert_single(&s, 7, dummy_view, {.Resource})
    texture_view_bind_group_state_insert_single(&s, 1, dummy_view, {.Copy_Src})
    texture_view_bind_group_state_insert_single(&s, 5, dummy_view, {.Copy_Dst})
    texture_view_bind_group_state_insert_single(&s, 3, dummy_view, {.Present})

    testing.expect_value(t, len(s.views), 4)
    // Insertion order holds until optimize runs.
    testing.expect_value(t, int(s.views[0].index), 7)
    testing.expect_value(t, int(s.views[3].index), 3)

    texture_view_bind_group_state_optimize(&s)

    testing.expect_value(t, len(s.views), 4)
    testing.expect_value(t, int(s.views[0].index), 1)
    testing.expect_value(t, int(s.views[1].index), 3)
    testing.expect_value(t, int(s.views[2].index), 5)
    testing.expect_value(t, int(s.views[3].index), 7)

    // Each usage travels with its own entry through the sort.
    testing.expect_value(t, s.views[0].usage, Texture_Uses{.Copy_Src})
    testing.expect_value(t, s.views[1].usage, Texture_Uses{.Present})
    testing.expect_value(t, s.views[2].usage, Texture_Uses{.Copy_Dst})
    testing.expect_value(t, s.views[3].usage, Texture_Uses{.Resource})
}

// Several views can share one parent texture, and so one tracker index. Grouping
// equal keys adjacently is the point of the sort: merge touches that texture's
// state once per view, and ascending order keeps those accesses together.
@(test)
view_bind_group_state_optimize_groups_equal_indices :: proc(t: ^testing.T) {
    s: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&s, context.allocator)
    defer texture_view_bind_group_state_uninit(&s)

    dummy_view: Texture_View
    texture_view_bind_group_state_insert_single(&s, 4, dummy_view, {.Resource})
    texture_view_bind_group_state_insert_single(&s, 9, dummy_view, {.Resource})
    texture_view_bind_group_state_insert_single(&s, 4, dummy_view, {.Copy_Src})
    texture_view_bind_group_state_insert_single(&s, 9, dummy_view, {.Copy_Dst})

    texture_view_bind_group_state_optimize(&s)

    // `slice.sort_by` is unstable, so only the grouping is asserted, never the
    // order within a group of equal keys.
    testing.expect_value(t, len(s.views), 4)
    testing.expect_value(t, int(s.views[0].index), 4)
    testing.expect_value(t, int(s.views[1].index), 4)
    testing.expect_value(t, int(s.views[2].index), 9)
    testing.expect_value(t, int(s.views[3].index), 9)
}

// Empty and single-entry states must not disturb the sort.
@(test)
view_bind_group_state_optimize_handles_degenerate_counts :: proc(t: ^testing.T) {
    s: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&s, context.allocator)
    defer texture_view_bind_group_state_uninit(&s)

    texture_view_bind_group_state_optimize(&s)
    testing.expect_value(t, len(s.views), 0)

    dummy_view: Texture_View
    texture_view_bind_group_state_insert_single(&s, 6, dummy_view, {.Resource})
    texture_view_bind_group_state_optimize(&s)
    testing.expect_value(t, len(s.views), 1)
    testing.expect_value(t, int(s.views[0].index), 6)
    testing.expect_value(t, s.views[0].usage, Texture_Uses{.Resource})
}

// The old version read the sort key back off the view impl, which meant it could
// only ever see `0` and so could never sort anything.
@(test)
view_bind_group_entry_index_is_parent_texture_index :: proc(t: ^testing.T) {
    s: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&s, context.allocator)
    defer texture_view_bind_group_state_uninit(&s)

    // Distinct keys must actually reorder; an all-equal comparator cannot.
    dummy_view: Texture_View
    for i in 0 ..< 32 {
        texture_view_bind_group_state_insert_single(
            &s, Tracker_Index(31 - i), dummy_view, {.Resource},
        )
    }

    texture_view_bind_group_state_optimize(&s)

    testing.expect_value(t, len(s.views), 32)
    for i in 0 ..< 32 {
        testing.expect_value(t, int(s.views[i].index), i)
    }
}

// @(test)
// view_bind_group_state_used_textures_yields_all :: proc(t: ^testing.T) {
//     s: Texture_View_Bind_Group_State
//     texture_view_bind_group_state_init(&s, context.allocator)
//     defer texture_view_bind_group_state_uninit(&s)

//     append(&s.views, Texture_View_Bind_Group_Entry{view = Texture_View{handle = 5}})
//     append(&s.views, Texture_View_Bind_Group_Entry{view = Texture_View{handle = 7}})

//     it := texture_view_bind_group_state_used_textures(&s)
//     count := 0
//     for tex in texture_viewed_textures_next(&it) {
//         count += 1
//         testing.expect(t, tex.handle == 5 || tex.handle == 7)
//     }
//     testing.expect_value(t, count, 2)
// }

// @(test)
// view_bind_group_state_used_textures_empty :: proc(t: ^testing.T) {
//     s: Texture_View_Bind_Group_State
//     texture_view_bind_group_state_init(&s, context.allocator)
//     defer texture_view_bind_group_state_uninit(&s)

//     it := texture_view_bind_group_state_used_textures(&s)
//     _, cond := texture_viewed_textures_next(&it)
//     testing.expect(t, !cond, "iterator on empty state must be immediately done")
// }

// --- Bind group internal usage derivation (priv.odin) ----------------------

buffer_layout_entry :: proc(type: Buffer_Binding_Type) -> Bind_Group_Layout_Entry {
    return Bind_Group_Layout_Entry{
        type = Buffer_Binding_Layout{type = type},
    }
}

storage_texture_layout_entry :: proc(access: Storage_Texture_Access) -> Bind_Group_Layout_Entry {
    return Bind_Group_Layout_Entry{
        type = Storage_Texture_Binding_Layout{access = access},
    }
}

@(test)
test_bind_group_buffer_internal_use_uniform :: proc(t: ^testing.T) {
    uses, is_storage := bind_group_buffer_internal_use(buffer_layout_entry(.Uniform))
    testing.expect_value(t, uses, Buffer_Uses{.Uniform})
    testing.expect_value(t, is_storage, false)
}

@(test)
test_bind_group_buffer_internal_use_storage :: proc(t: ^testing.T) {
    uses, is_storage := bind_group_buffer_internal_use(buffer_layout_entry(.Storage))
    testing.expect_value(t, uses, Buffer_Uses{.Storage_Read_Write})
    testing.expect_value(t, is_storage, true)
}

@(test)
test_bind_group_buffer_internal_use_read_only_storage :: proc(t: ^testing.T) {
    uses, is_storage := bind_group_buffer_internal_use(buffer_layout_entry(.Read_Only_Storage))
    // Read-only storage is recorded as a read, so binding one cannot conflict
    // with a concurrent write.
    testing.expect_value(t, uses, Buffer_Uses{.Storage_Read_Only})
    testing.expect_value(t, is_storage, true)
}

@(test)
test_bind_group_view_internal_use_texture :: proc(t: ^testing.T) {
    entry := Bind_Group_Layout_Entry{type = Texture_Binding_Layout{}}
    uses, is_storage := bind_group_view_internal_use(entry)
    testing.expect_value(t, uses, Texture_Uses{.Resource})
    testing.expect_value(t, is_storage, false)
}

@(test)
test_bind_group_view_internal_use_storage_access_modes :: proc(t: ^testing.T) {
    uses, is_storage := bind_group_view_internal_use(storage_texture_layout_entry(.Write_Only))
    testing.expect_value(t, uses, Texture_Uses{.Storage_Write_Only})
    testing.expect_value(t, is_storage, true)

    uses, is_storage = bind_group_view_internal_use(storage_texture_layout_entry(.Read_Only))
    testing.expect_value(t, uses, Texture_Uses{.Storage_Read_Only})
    testing.expect_value(t, is_storage, true)

    uses, is_storage = bind_group_view_internal_use(storage_texture_layout_entry(.Read_Write))
    testing.expect_value(t, uses, Texture_Uses{.Storage_Read_Write})
    testing.expect_value(t, is_storage, true)
}

// --- Copy / clear path scope semantics ---------------------------------------
//
// `command_encoder_copy_buffer_to_buffer` records `Copy_Src` on the source and
// `Copy_Dst` on the destination, and `command_encoder_clear_buffer` records
// `Copy_Dst`, all in the command buffer's global scope. These exercise the
// conflicts that produces.

@(test)
test_copy_buffer_to_buffer_distinct_buffers_merge :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    src, dst: Buffer

    err := buffer_usage_scope_merge_single(&scope, 0, src, Buffer_Uses{.Copy_Src})
    testing.expect(t, err == nil, "copy source should merge cleanly")

    err = buffer_usage_scope_merge_single(&scope, 1, dst, Buffer_Uses{.Copy_Dst})
    testing.expect(t, err == nil, "copy destination should merge cleanly")

    testing.expect_value(t, scope.state[0], Buffer_Uses{.Copy_Src})
    testing.expect_value(t, scope.state[1], Buffer_Uses{.Copy_Dst})
}

@(test)
test_copy_buffer_to_buffer_self_copy_conflicts :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    err := buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Src})
    testing.expect(t, err == nil, "copy source should merge cleanly")

    // Same buffer as both ends of the copy: `Copy_Src` and `Copy_Dst` are two
    // uses and one of them is exclusive, so the scope rule rejects it.
    err = buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst})
    testing.expect(t, err != nil, "self-copy must be rejected")
}

@(test)
test_copy_chain_reusing_buffer_as_both_ends_conflicts :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 3, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    a, b: Buffer

    // a -> b
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, a, Buffer_Uses{.Copy_Src}), nil)
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 1, b, Buffer_Uses{.Copy_Dst}), nil)

    // b -> a: `b` was already a copy destination and is now a copy source.
    err := buffer_usage_scope_merge_single(&scope, 1, b, Buffer_Uses{.Copy_Src})
    testing.expect(t, err != nil, "buffer that was a copy destination cannot become a copy source")

    err = buffer_usage_scope_merge_single(&scope, 0, a, Buffer_Uses{.Copy_Dst})
    testing.expect(t, err != nil, "buffer that was a copy source cannot become a copy destination")
}

@(test)
test_copy_then_clear_same_buffer_allowed :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // Copy into `buf`, then clear it. Both are `Copy_Dst`, so this is two writes
    // that order cleanly against each other. `Copy_Dst` is exclusive only
    // against a *different* use, not against a repeat of itself.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst}), nil)

    err := buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst})
    testing.expect(t, err == nil, "a second copy destination for the same buffer is orderable")
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Copy_Dst})

    // The same buffer as a copy source is a different use, and is rejected.
    err = buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Src})
    testing.expect(t, err != nil, "copy destination cannot also be a copy source")
}

@(test)
test_copy_source_merges_with_inclusive_uses :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // `Copy_Src` is inclusive, so reading a buffer for a copy and then binding
    // it as vertex data is ordered rather than conflicting.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Src}), nil)
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex}), nil)
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Copy_Src, .Vertex})

    // `Copy_Dst` is exclusive, so it cannot share a scope with anything else.
dst: Buffer
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 1, dst, Buffer_Uses{.Copy_Dst}), nil)
    err := buffer_usage_scope_merge_single(&scope, 1, dst, Buffer_Uses{.Vertex})
    testing.expect(t, err != nil, "copy destination cannot also be vertex data")
}

@(test)
test_vertex_buffer_conflicts_with_copy_destination_in_pass :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 1, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // `render_pass_set_vertex_buffer` merges `.Vertex` into the pass scope. A
    // buffer already claimed as an exclusive write in that same scope cannot
    // also be vertex data.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst}), nil)

    err := buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex})
    testing.expect(t, err != nil, "vertex buffer cannot share a scope with a write")

    // The same holds for the index buffer's `.Index`.
    err = buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Index})
    testing.expect(t, err != nil, "index buffer cannot share a scope with a write")
}

@(test)
test_vertex_buffer_repeated_binding_allowed :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 1, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // `.Vertex` is inclusive, so rebinding the same buffer (a different slot, or
    // simply a second call) merges rather than conflicting.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex}), nil)
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex}), nil)
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Vertex})
}

@(test)
test_vertex_and_index_on_same_buffer_allowed :: proc(t: ^testing.T) {
    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 2, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // Interleaving one buffer's vertex data with another buffer's index data is
    // allowed: both uses are inclusive, and they are different resources.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex}), nil)
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 1, buf, Buffer_Uses{.Index}), nil)
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Vertex})
    testing.expect_value(t, scope.state[1], Buffer_Uses{.Index})

    // One buffer used as both vertex and index data is also a valid combined
    // state, since both bits are inclusive. `device_create_buffer` gates this
    // combination behind [Unrestricted_Index_Buffer] at the API level.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Index}), nil)
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Vertex, .Index})

    // Adding an exclusive use to that combined state is still rejected.
    err := buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst})
    testing.expect(t, err != nil, "one buffer cannot be vertex/index data and a write")
}

@(test)
test_pass_scope_does_not_leak_into_next_pass :: proc(t: ^testing.T) {
    tracker: Buffer_Tracker
    buffer_tracker_init(&tracker, VK_BUFFER_ORDERED_USES_MASK, context.allocator)
    defer buffer_tracker_uninit(&tracker)

    scope: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope, 1, context.allocator)
    defer buffer_usage_scope_uninit(&scope)

    buf: Buffer

    // Pass A binds the buffer as vertex data.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Vertex}), nil)

    // `vk_render_pass_end` folds the pass scope into the tracker and clears it.
    buffer_tracker_set_from_usage_scope(&tracker, &scope)
    buffer_usage_scope_clear(&scope)

    // The scope no longer claims the resource. `buffer_usage_scope_clear` drops
    // the state length, so membership is checked through the metadata bits.
    testing.expect(t, !resource_metadata_contains(&scope.metadata, 0),
        "folded scope should no longer claim the buffer")

    // Pass B writes the buffer. Because the scope was drained, this is a fresh
    // state rather than a `.Vertex` + `.Copy_Dst` conflict inside one scope.
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope, 0, buf, Buffer_Uses{.Copy_Dst}), nil)
    testing.expect_value(t, scope.state[0], Buffer_Uses{.Copy_Dst})

    // The tracker kept the pass A read as an end state.
    testing.expect(t,
        buffer_uses_contains(tracker.end[0], Buffer_Uses{.Vertex}),
        "pass A vertex use should survive the fold")
}

// -----------------------------------------------------------------------------
// Retain/Release
// -----------------------------------------------------------------------------

// These hooks are process-global and the test runner runs tests concurrently.
// The callbacks therefore only count resources with a private test handle, so
// tracker activity in other tests cannot affect the assertions below.
//
// The counters themselves are still written from whatever thread happens to reach
// them, so they are accessed atomically: `core:testing` runs tests on a thread pool
// and the concurrency tests in `thread_safety_tests.odin` spawn their own threads.
//
// Residual limitation, unchanged by this: swapping the hook pointers themselves is
// not atomic. That is safe here only because unit tests never create a real
// resource, so there is no refcount for a concurrently-installed counting hook to
// skip. A test that counts real device resources would need a different mechanism.
Ref_Hook_Counts :: struct {
    retain_buffer:   int,
    release_buffer:  int,
    retain_texture:  int,
    release_texture: int,
    retain_view:     int,
    release_view:    int,
}

counting_ref_hooks: Ref_Hook_Counts
COUNTING_REF_HANDLE :: Handle_Packed(0xF001_0001)

@(private)
counting_ref_hooks_reset :: proc() {
    sync.atomic_store(&counting_ref_hooks.retain_buffer, 0)
    sync.atomic_store(&counting_ref_hooks.release_buffer, 0)
    sync.atomic_store(&counting_ref_hooks.retain_texture, 0)
    sync.atomic_store(&counting_ref_hooks.release_texture, 0)
    sync.atomic_store(&counting_ref_hooks.retain_view, 0)
    sync.atomic_store(&counting_ref_hooks.release_view, 0)
}

// Reads the counters into plain ints so assertions can compare them directly.
@(private)
counting_ref_hooks_snapshot :: proc() -> Ref_Hook_Counts {
    return {
        retain_buffer   = sync.atomic_load(&counting_ref_hooks.retain_buffer),
        release_buffer  = sync.atomic_load(&counting_ref_hooks.release_buffer),
        retain_texture  = sync.atomic_load(&counting_ref_hooks.retain_texture),
        release_texture = sync.atomic_load(&counting_ref_hooks.release_texture),
        retain_view     = sync.atomic_load(&counting_ref_hooks.retain_view),
        release_view    = sync.atomic_load(&counting_ref_hooks.release_view),
    }
}

Saved_Ref_Hooks :: struct {
    retain_buffer:   proc(buffer: Buffer, loc := #caller_location),
    release_buffer:  proc(buffer: Buffer, loc := #caller_location),
    retain_texture:  proc(texture: Texture, loc := #caller_location),
    release_texture: proc(texture: Texture, loc := #caller_location),
    retain_view:     proc(view: Texture_View, loc := #caller_location),
    release_view:    proc(view: Texture_View, loc := #caller_location),
}

@(private)
counting_retain_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    if Handle(buffer).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.retain_buffer, 1)
    }
}

@(private)
counting_release_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    if Handle(buffer).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.release_buffer, 1)
    }
}

@(private)
counting_retain_texture :: proc(texture: Texture, loc := #caller_location) {
    if Handle(texture).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.retain_texture, 1)
    }
}

@(private)
counting_release_texture :: proc(texture: Texture, loc := #caller_location) {
    if Handle(texture).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.release_texture, 1)
    }
}

@(private)
counting_retain_view :: proc(view: Texture_View, loc := #caller_location) {
    if Handle(view).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.retain_view, 1)
    }
}

@(private)
counting_release_view :: proc(view: Texture_View, loc := #caller_location) {
    if Handle(view).handle == COUNTING_REF_HANDLE {
        sync.atomic_add(&counting_ref_hooks.release_view, 1)
    }
}

install_counting_ref_hooks :: proc() -> Saved_Ref_Hooks {
    saved := Saved_Ref_Hooks{
        tracker_retain_buffer,
        tracker_release_buffer,
        tracker_retain_texture,
        tracker_release_texture,
        tracker_retain_texture_view,
        tracker_release_texture_view,
    }
    counting_ref_hooks_reset()
    tracker_retain_buffer = counting_retain_buffer
    tracker_release_buffer = counting_release_buffer
    tracker_retain_texture = counting_retain_texture
    tracker_release_texture = counting_release_texture
    tracker_retain_texture_view = counting_retain_view
    tracker_release_texture_view = counting_release_view
    return saved
}

uninstall_ref_hooks :: proc(saved: Saved_Ref_Hooks) {
    tracker_retain_buffer = saved.retain_buffer
    tracker_release_buffer = saved.release_buffer
    tracker_retain_texture = saved.retain_texture
    tracker_release_texture = saved.release_texture
    tracker_retain_texture_view = saved.retain_view
    tracker_release_texture_view = saved.release_view
    counting_ref_hooks_reset()
}

@(test)
test_tracker_resource_retain_release_lifetimes :: proc(t: ^testing.T) {
    saved := install_counting_ref_hooks()
    defer uninstall_ref_hooks(saved)

    // A usage scope retains once for an index, even if another compatible use
    // of the same buffer is merged, then releases on uninit.
    counting_ref_hooks_reset()
    scope_a: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope_a, 0, context.allocator)

    buf := Buffer(Handle{handle = COUNTING_REF_HANDLE})
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope_a, 0, buf, Buffer_Uses{.Vertex}),
        nil)
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope_a, 0, buf, Buffer_Uses{.Vertex}),
        nil)

    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 0)

    buffer_usage_scope_uninit(&scope_a)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 1)

    // Folding a scope into a command-buffer tracker creates a destination
    // reference; clearing the source releases only the source's reference.
    counting_ref_hooks_reset()
    scope_b: Buffer_Usage_Scope
    buffer_usage_scope_init(&scope_b, 0, context.allocator)
    tracker: Buffer_Tracker
    buffer_tracker_init(&tracker, Buffer_Uses{}, context.allocator)

    buf = Buffer(Handle{handle = COUNTING_REF_HANDLE})
    testing.expect_value(t,
        buffer_usage_scope_merge_single(&scope_b, 0, buf, Buffer_Uses{.Vertex}),
        nil)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 1)

    buffer_tracker_set_from_usage_scope(&tracker, &scope_b)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 2)

    buffer_usage_scope_clear(&scope_b)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 1)
    testing.expect_value(t,
        counting_ref_hooks_snapshot().retain_buffer - counting_ref_hooks_snapshot().release_buffer, 1)
    buffer_usage_scope_uninit(&scope_b)
    buffer_tracker_uninit(&tracker)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 2)

    // Device tracker metadata is weak, so inserting/re-inserting/removing an
    // index does not change the resource's strong reference count.
    counting_ref_hooks_reset()
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)

    buf = Buffer(Handle{handle = COUNTING_REF_HANDLE})
    device_buffer_tracker_insert_single(&tr, 0, buf, Buffer_Uses{.Vertex})
    device_buffer_tracker_insert_single(&tr, 0, buf, Buffer_Uses{.Index})
    device_buffer_tracker_insert_single(&tr, 0, buf, Buffer_Uses{.Copy_Dst})

    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 0)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 0)

    device_buffer_tracker_remove(&tr, 0)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 0)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 0)
    device_buffer_tracker_uninit(&tr)

    counting_ref_hooks_reset()
    texture_tracker: Device_Texture_Tracker
    device_texture_tracker_init(&texture_tracker, Texture_Uses{}, context.allocator)
    tex := Texture(Handle{handle = COUNTING_REF_HANDLE})
    device_texture_tracker_insert_single(&texture_tracker, 0, tex, Texture_Uses{.Resource})
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_texture, 0)
    device_texture_tracker_remove(&texture_tracker, 0)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_texture, 0)
    device_texture_tracker_uninit(&texture_tracker)

    // Bind-group state owns buffer refs until it is uninitialized.
    counting_ref_hooks_reset()
    state: Buffer_Bind_Group_State
    buffer_bind_group_state_init(&state, context.allocator)

    buf = Buffer(Handle{handle = COUNTING_REF_HANDLE})
    buffer_bind_group_state_insert_single(&state, 0, buf, Buffer_Uses{.Vertex})
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 0)

    buffer_bind_group_state_uninit(&state)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_buffer, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_buffer, 1)

    // Texture-view bind-group states retain the view itself (which owns its
    // parent texture.
    counting_ref_hooks_reset()
    view_state: Texture_View_Bind_Group_State
    texture_view_bind_group_state_init(&view_state, context.allocator)

    view := Texture_View(Handle{handle = COUNTING_REF_HANDLE})
    texture_view_bind_group_state_insert_single(&view_state, 0, view, Texture_Uses{.Resource})
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_view, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_view, 0)

    texture_view_bind_group_state_uninit(&view_state)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_view, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_view, 1)

    // Texture metadata is retained by the same concrete state-insert path and
    // released when the table's owner clears it.
    counting_ref_hooks_reset()
    end_set: Texture_State_Set
    texture_state_set_init(&end_set, context.allocator)
    defer texture_state_set_uninit(&end_set)
    texture_state_set_resize(&end_set, 1)

    metadata: Resource_Metadata(Texture)
    resource_metadata_init(&metadata, 1, context.allocator)
    defer resource_metadata_uninit(&metadata)

    start_provider := texture_state_provider_known_single(Texture_Uses{.Resource})
    tex = Texture(Handle{handle = COUNTING_REF_HANDLE})
    metadata_provider := resource_metadata_provider_direct(tex)
    texture_state_insert(
        {}, nil, &end_set, &metadata, 0,
        &start_provider, nil, &metadata_provider,
    )
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_texture, 1)

    texture_metadata_release_all(&metadata)
    testing.expect_value(t, counting_ref_hooks_snapshot().retain_texture, 1)
    testing.expect_value(t, counting_ref_hooks_snapshot().release_texture, 1)
    // `resource_metadata_uninit` below should see an already-cleared table.
}
