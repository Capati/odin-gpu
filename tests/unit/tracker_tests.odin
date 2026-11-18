#+build !js
package unit_tests

import "core:testing"
import gpu "../../gpu"

// Tests for the resource-state tracker.
//
// The two Vulkan-specific cases (layout and access mapping) belong to the Vulkan
// backend and are not covered here.

@(private = "file")
test_buffer :: proc(index: gpu.Tracker_Index) -> gpu.Buffer {
    return gpu.new_handle_packed(gpu.Buffer, gpu.Device(nil), gpu.Handle_Packed(u64(u32(index))))
}

@(private = "file")
test_texture_handle :: proc(index: gpu.Tracker_Index, generation: u32 = 1) -> gpu.Texture {
    packed := u64(generation) << 32 | u64(u32(index))
    return gpu.new_handle_packed(gpu.Texture, gpu.Device(nil), gpu.Handle_Packed(packed))
}

@(private = "file")
test_tracked_texture :: proc(
    index: gpu.Tracker_Index,
    mips, layers: u32,
    generation: u32 = 1,
) -> gpu.Tracked_Texture {
    return gpu.tracked_texture(index, test_texture_handle(index, generation), mips, layers)
}

@(private = "file")
test_texture_view :: proc(index: gpu.Tracker_Index) -> gpu.Texture_View {
    return gpu.new_handle_packed(gpu.Texture_View, gpu.Device(nil), gpu.Handle_Packed(u64(u32(index))))
}

@(private = "file")
test_query_set :: proc(index: gpu.Tracker_Index) -> gpu.Query_Set {
    return gpu.new_handle_packed(gpu.Query_Set, gpu.Device(nil), gpu.Handle_Packed(u64(u32(index))))
}

@(private = "file")
test_bind_group :: proc(index: gpu.Tracker_Index) -> gpu.Bind_Group {
    return gpu.new_handle_packed(gpu.Bind_Group, gpu.Device(nil), gpu.Handle_Packed(u64(u32(index))))
}

@(private = "file")
test_blas :: proc(index: u32) -> gpu.Blas {
    return gpu.Blas(rawptr(uintptr(index)))
}

@(private = "file")
mip_range :: proc(mip: u32, layers: u32) -> gpu.Texture_Selector {
    return {mip_start = mip, mip_count = 1, layer_start = 0, layer_count = layers}
}

@(private = "file")
layer_range :: proc(mip: u32, layer: u32, count: u32) -> gpu.Texture_Selector {
    return {mip_start = mip, mip_count = 1, layer_start = layer, layer_count = count}
}

// The use a complex state holds for one subresource.
@(private = "file")
value_of :: proc(state: ^gpu.Complex_Texture_State, mip: u32, layer: u32) -> gpu.Texture_Uses {
    for &range in state.mips[mip].ranges {
        if layer >= range.start && layer < range.end {
            return range.value
        }
    }
    return gpu.TEXTURE_USES_UNKNOWN
}

// -----------------------------------------------------------------------------
// Metadata
// -----------------------------------------------------------------------------

@(test)
test_metadata_membership :: proc(t: ^testing.T) {
    meta: gpu.Resource_Metadata(u32)
    gpu.resource_metadata_init(&meta, context.allocator)
    defer gpu.resource_metadata_free(&meta)

    testing.expect(t, !gpu.resource_metadata_contains(&meta, 3))
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 0)
    testing.expect(t, gpu.resource_metadata_is_empty(&meta))

    gpu.resource_metadata_insert(&meta, 3, 300)
    testing.expect(t, gpu.resource_metadata_contains(&meta, 3))
    testing.expect_value(t, gpu.resource_metadata_get(&meta, 3), 300)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)
    testing.expect(t, !gpu.resource_metadata_is_empty(&meta))

    // Re-inserting a member overwrites its payload without counting it twice.
    gpu.resource_metadata_insert(&meta, 3, 301)
    testing.expect_value(t, gpu.resource_metadata_get(&meta, 3), 301)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)

    // A neighbour is independent.
    gpu.resource_metadata_insert(&meta, 4, 400)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 2)

    gpu.resource_metadata_remove(&meta, 3)
    testing.expect(t, !gpu.resource_metadata_contains(&meta, 3))
    testing.expect(t, gpu.resource_metadata_contains(&meta, 4))
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)

    // Removing twice is a no-op.
    gpu.resource_metadata_remove(&meta, 3)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)

    gpu.resource_metadata_remove(&meta, 4)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 0)
    testing.expect(t, gpu.resource_metadata_is_empty(&meta))
}

@(test)
test_metadata_grows_on_demand :: proc(t: ^testing.T) {
    meta: gpu.Resource_Metadata(u32)
    gpu.resource_metadata_init(&meta, context.allocator)
    defer gpu.resource_metadata_free(&meta)

    // No `set_size` first: the first contact with a high index grows the bit words
    // and the payload table together.
    gpu.resource_metadata_insert(&meta, 1000, 1)
    testing.expect(t, gpu.resource_metadata_contains(&meta, 1000))
    testing.expect_value(t, gpu.resource_metadata_get(&meta, 1000), 1)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)
    testing.expect(t, !gpu.resource_metadata_contains(&meta, 999))
    testing.expect(t, !gpu.resource_metadata_contains(&meta, 1001))
}

@(test)
test_metadata_set_size_and_clear :: proc(t: ^testing.T) {
    meta: gpu.Resource_Metadata(u32)
    gpu.resource_metadata_init(&meta, context.allocator)
    defer gpu.resource_metadata_free(&meta)

    // `set_size` presizes for indices below it without making any a member.
    gpu.resource_metadata_set_size(&meta, 130)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 0)
    testing.expect(t, !gpu.resource_metadata_contains(&meta, 129))

    gpu.resource_metadata_insert(&meta, 129, 7)
    testing.expect(t, gpu.resource_metadata_contains(&meta, 129))
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)

    // `clear` drops the members but keeps the storage usable.
    gpu.resource_metadata_clear(&meta)
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 0)
    testing.expect(t, !gpu.resource_metadata_contains(&meta, 129))
    gpu.resource_metadata_insert(&meta, 1, 2)
    testing.expect(t, gpu.resource_metadata_contains(&meta, 1))
    testing.expect_value(t, gpu.resource_metadata_count(&meta), 1)
}

@(test)
test_metadata_owned_indices :: proc(t: ^testing.T) {
    meta: gpu.Resource_Metadata(u32)
    gpu.resource_metadata_init(&meta, context.allocator)
    defer gpu.resource_metadata_free(&meta)

    // Members on both sides of a word boundary and one two hundred indices in, so
    // the iteration has to skip whole empty words.
    members := []u32{0, 63, 64, 129, 200}
    for member in members {
        gpu.resource_metadata_insert(&meta, gpu.Tracker_Index(member), member * 10)
    }

    iter: gpu.Metadata_Index_Iterator(u32)
    gpu.metadata_index_iterator_init(&iter, &meta)

    i := 0
    index: gpu.Tracker_Index
    for gpu.metadata_index_iterator_next(&iter, &index) {
        testing.expect(t, i < len(members), "iterated more members than expected")
        testing.expect_value(t, u32(index), members[i])
        testing.expect_value(t, gpu.resource_metadata_get(&meta, index), members[i] * 10)
        i += 1
    }
    testing.expect_value(t, i, len(members))

    // An empty set iterates nothing.
    gpu.resource_metadata_clear(&meta)
    gpu.metadata_index_iterator_init(&iter, &meta)
    testing.expect(t, !gpu.metadata_index_iterator_next(&iter, &index))
}

@(test)
test_metadata_owned_indices_after_removal :: proc(t: ^testing.T) {
    meta: gpu.Resource_Metadata(u32)
    gpu.resource_metadata_init(&meta, context.allocator)
    defer gpu.resource_metadata_free(&meta)

    for member in ([]u32{1, 65, 130}) {
        gpu.resource_metadata_insert(&meta, gpu.Tracker_Index(member), member)
    }

    // Removing a middle member must not disturb iteration of the rest: the bit is
    // cleared, the neighbouring words are untouched.
    gpu.resource_metadata_remove(&meta, 65)

    iter: gpu.Metadata_Index_Iterator(u32)
    gpu.metadata_index_iterator_init(&iter, &meta)

    expected := []u32{1, 130}
    i := 0
    index: gpu.Tracker_Index
    for gpu.metadata_index_iterator_next(&iter, &index) {
        testing.expect(t, i < len(expected), "iterated more members than expected")
        testing.expect_value(t, u32(index), expected[i])
        i += 1
    }
    testing.expect_value(t, i, len(expected))
}

// -----------------------------------------------------------------------------
// Range
// -----------------------------------------------------------------------------

@(private = "file")
range_set_base :: proc(rs: ^gpu.Ranged_States(u32)) {
    clear(&rs.ranges)
    append(&rs.ranges, gpu.Ranged_Entry(u32){start = 1, end = 4, value = 9})
    append(&rs.ranges, gpu.Ranged_Entry(u32){start = 4, end = 5, value = 9})
    append(&rs.ranges, gpu.Ranged_Entry(u32){start = 5, end = 7, value = 1})
    append(&rs.ranges, gpu.Ranged_Entry(u32){start = 8, end = 9, value = 1})
}

@(private = "file")
range_set :: proc(rs: ^gpu.Ranged_States(u32), starts, ends, values: []u32) {
    clear(&rs.ranges)
    for start, i in starts {
        append(&rs.ranges, gpu.Ranged_Entry(u32){start = start, end = ends[i], value = values[i]})
    }
}

@(private = "file")
range_expect :: proc(t: ^testing.T, rs: ^gpu.Ranged_States(u32), starts, ends, values: []u32) {
    gpu.ranged_states_check_sanity(rs)
    testing.expect_value(t, gpu.ranged_states_len(rs), len(starts))
    for &entry, i in rs.ranges {
        testing.expect_value(t, entry.start, starts[i])
        testing.expect_value(t, entry.end, ends[i])
        testing.expect_value(t, entry.value, values[i])
    }
}

// How many entries the isolate run covers: from `first` while the entry starts
// below `hi`.
@(private = "file")
range_run_len :: proc(rs: ^gpu.Ranged_States(u32), first: int, hi: u32) -> int {
    n := 0
    for i := first; i < len(rs.ranges) && rs.ranges[i].start < hi; i += 1 {
        n += 1
    }
    return n
}

// Isolate, then assign every covered entry: the shape a scope merge uses.
@(private = "file")
range_assign_run :: proc(rs: ^gpu.Ranged_States(u32), lo, hi: u32, value: u32) {
    i := gpu.ranged_states_isolate(rs, lo, hi, 0)
    for ; i < len(rs.ranges) && rs.ranges[i].start < hi; i += 1 {
        rs.ranges[i].value = value
    }
}

@(test)
test_range_sanity :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set(&rs, []u32{1, 4, 5, 8}, []u32{4, 5, 7, 9}, []u32{9, 9, 1, 1})
    testing.expect(t, gpu.ranged_states_is_sane(&rs))
    gpu.ranged_states_check_sanity(&rs)
    testing.expect_value(t, gpu.ranged_states_len(&rs), 4)

    // An entry with start == end covers nothing.
    range_set(&rs, []u32{1, 5}, []u32{4, 5}, []u32{9, 9})
    testing.expect(t, !gpu.ranged_states_is_sane(&rs), "an empty entry must be detected")

    // Entries that overlap.
    range_set(&rs, []u32{1, 3}, []u32{4, 5}, []u32{9, 9})
    testing.expect(t, !gpu.ranged_states_is_sane(&rs), "overlapping entries must be detected")

    // Entries out of order.
    range_set(&rs, []u32{4, 1}, []u32{5, 4}, []u32{9, 9})
    testing.expect(t, !gpu.ranged_states_is_sane(&rs), "unordered entries must be detected")
}

@(test)
test_range_coalesce :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    gpu.ranged_states_coalesce(&rs)
    // (1..4) and (4..5) agree and touch; (5..7) and (8..9) agree but do not.
    range_expect(t, &rs, []u32{1, 5, 8}, []u32{5, 7, 9}, []u32{9, 1, 1})

    // Coalescing again changes nothing.
    gpu.ranged_states_coalesce(&rs)
    range_expect(t, &rs, []u32{1, 5, 8}, []u32{5, 7, 9}, []u32{9, 1, 1})

    // A single entry is left alone, and so is an empty sequence.
    gpu.ranged_states_set_single(&rs, 2, 3, 4)
    gpu.ranged_states_coalesce(&rs)
    range_expect(t, &rs, []u32{2}, []u32{3}, []u32{4})
    gpu.ranged_states_clear(&rs)
    gpu.ranged_states_coalesce(&rs)
    testing.expect_value(t, gpu.ranged_states_len(&rs), 0)
}

@(test)
test_range_isolate_inside_an_entry :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    // The range is already one entry: no split, the list is untouched.
    first := gpu.ranged_states_isolate(&rs, 4, 5, 0)
    testing.expect_value(t, first, 1)
    testing.expect_value(t, range_run_len(&rs, first, 5), 1)
    range_expect(t, &rs, []u32{1, 4, 5, 8}, []u32{4, 5, 7, 9}, []u32{9, 9, 1, 1})
}

@(test)
test_range_isolate_covering_gaps :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    // [0,6) starts before the sequence and ends inside an entry: the head gap is
    // filled, the straddling entries are split at both ends.
    first := gpu.ranged_states_isolate(&rs, 0, 6, 0)
    testing.expect_value(t, first, 0)
    testing.expect_value(t, range_run_len(&rs, first, 6), 4)
    range_expect(
        t,
        &rs,
        []u32{0, 1, 4, 5, 6, 8},
        []u32{1, 4, 5, 6, 7, 9},
        []u32{0, 9, 9, 1, 1, 1},
    )
}

@(test)
test_range_isolate_across_a_gap :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    // [6,9) starts inside an entry, crosses the [7,8) gap and ends on a boundary:
    // both sides are split and the gap is filled.
    first := gpu.ranged_states_isolate(&rs, 6, 9, 0)
    testing.expect_value(t, first, 3)
    testing.expect_value(t, range_run_len(&rs, first, 9), 3)
    range_expect(
        t,
        &rs,
        []u32{1, 4, 5, 6, 7, 8},
        []u32{4, 5, 6, 7, 8, 9},
        []u32{9, 9, 1, 1, 0, 1},
    )
}

@(test)
test_range_isolate_past_the_end :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    // The sequence ends before `lo`: one entry is appended.
    first := gpu.ranged_states_isolate(&rs, 9, 11, 0)
    testing.expect_value(t, first, 4)
    testing.expect_value(t, range_run_len(&rs, first, 11), 1)
    range_expect(
        t,
        &rs,
        []u32{1, 4, 5, 8, 9},
        []u32{4, 5, 7, 9, 11},
        []u32{9, 9, 1, 1, 0},
    )

    // And a range that starts exactly where the sequence ends, with the default
    // value reused for the tail.
    tail: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&tail, context.allocator)
    defer gpu.ranged_states_free(&tail)
    range_set_base(&tail)
    first = gpu.ranged_states_isolate(&tail, 8, 10, 1)
    testing.expect_value(t, first, 3)
    testing.expect_value(t, range_run_len(&tail, first, 10), 2)
    range_expect(t, &tail, []u32{1, 4, 5, 8, 9}, []u32{4, 5, 7, 9, 10}, []u32{9, 9, 1, 1, 1})
}

@(test)
test_range_isolate_assigns_the_run :: proc(t: ^testing.T) {
    rs: gpu.Ranged_States(u32)
    gpu.ranged_states_init(&rs, context.allocator)
    defer gpu.ranged_states_free(&rs)

    range_set_base(&rs)
    range_assign_run(&rs, 0, 6, 5)
    // Everything in [0,6) is the new value; the parts beyond keep theirs, and
    // nothing is coalesced behind the caller's back.
    range_expect(
        t,
        &rs,
        []u32{0, 1, 4, 5, 6, 8},
        []u32{1, 4, 5, 6, 7, 9},
        []u32{5, 5, 5, 5, 1, 1},
    )
}

// -----------------------------------------------------------------------------
// Buffer
// -----------------------------------------------------------------------------

@(test)
test_buffer_tracker_first_touch :: proc(t: ^testing.T) {
    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)

    gpu.buffer_tracker_set_single(&tracker, 3, test_buffer(3), gpu.BUFFER_USES_COPY_DST)

    // A buffer the transcript has never seen needs no barrier: the device state is
    // the pre-barrier's business.
    testing.expect_value(t, len(tracker.temp), 0)
    testing.expect(t, gpu.buffer_tracker_contains(&tracker, 3))
    testing.expect_value(t, tracker.start[3], gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, tracker.end[3], gpu.BUFFER_USES_COPY_DST)
}

@(test)
test_buffer_tracker_transition :: proc(t: ^testing.T) {
    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)

    gpu.buffer_tracker_set_single(&tracker, 3, test_buffer(3), gpu.BUFFER_USES_COPY_DST)
    gpu.buffer_tracker_set_single(&tracker, 3, test_buffer(3), gpu.BUFFER_USES_UNIFORM)

    testing.expect_value(t, len(tracker.temp), 1)
    testing.expect_value(t, tracker.temp[0].buffer, test_buffer(3))
    testing.expect_value(t, tracker.temp[0].from, gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, tracker.temp[0].to, gpu.BUFFER_USES_UNIFORM)
    // `start` keeps the state the transcript is entered in; only `end` moves.
    testing.expect_value(t, tracker.start[3], gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, tracker.end[3], gpu.BUFFER_USES_UNIFORM)

    gpu.buffer_tracker_clear_pending(&tracker)
    testing.expect_value(t, len(tracker.temp), 0)
}

@(test)
test_buffer_tracker_skips_ordered :: proc(t: ^testing.T) {
    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)

    gpu.buffer_tracker_set_single(&tracker, 1, test_buffer(1), gpu.BUFFER_USES_UNIFORM)

    // An unchanged state drawn only from the ordered set needs nothing.
    gpu.buffer_tracker_set_single(&tracker, 1, test_buffer(1), gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, len(tracker.temp), 0)

    // An unchanged state that is *not* ordered still emits: the hardware does not
    // order two exclusive accesses for free.
    gpu.buffer_tracker_set_single(&tracker, 1, test_buffer(1), gpu.BUFFER_USES_COPY_DST)
    gpu.buffer_tracker_clear_pending(&tracker)
    gpu.buffer_tracker_set_single(&tracker, 1, test_buffer(1), gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, len(tracker.temp), 1)
    testing.expect_value(t, tracker.temp[0].from, gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, tracker.temp[0].to, gpu.BUFFER_USES_COPY_DST)
}

@(test)
test_buffer_scope_merge_and_conflict :: proc(t: ^testing.T) {
    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)

    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses

    // Two inclusive uses combine.
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 2, test_buffer(2), gpu.BUFFER_USES_UNIFORM, &current, &added))
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 2, test_buffer(2), gpu.BUFFER_USES_COPY_SRC, &current, &added))
    testing.expect_value(t, scope.state[2], gpu.BUFFER_USES_UNIFORM | gpu.BUFFER_USES_COPY_SRC)

    // An exclusive use on a non-empty state is the conflict the scope exists to
    // catch, reported as what it had and what it was offered.
    testing.expect(t, !gpu.buffer_usage_scope_merge_single(&scope, 2, test_buffer(2), gpu.BUFFER_USES_COPY_DST, &current, &added))
    testing.expect_value(t, current, gpu.BUFFER_USES_UNIFORM | gpu.BUFFER_USES_COPY_SRC)
    testing.expect_value(t, added, gpu.BUFFER_USES_COPY_DST)
    // The failed merge leaves the state untouched.
    testing.expect_value(t, scope.state[2], gpu.BUFFER_USES_UNIFORM | gpu.BUFFER_USES_COPY_SRC)
    testing.expect_value(t, gpu.resource_metadata_count(&scope.metadata), 1)
}

@(test)
test_buffer_scope_merge_scope :: proc(t: ^testing.T) {
    target: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&target, context.allocator)
    defer gpu.buffer_usage_scope_free(&target)
    source: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&source, context.allocator)
    defer gpu.buffer_usage_scope_free(&source)

    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses

    testing.expect(t, gpu.buffer_usage_scope_merge_single(&source, 1, test_buffer(1), gpu.BUFFER_USES_UNIFORM, &current, &added))
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&source, 40, test_buffer(40), gpu.BUFFER_USES_VERTEX, &current, &added))

    testing.expect(t, gpu.buffer_usage_scope_merge_usage_scope(&target, &source, &current, &added))
    testing.expect_value(t, gpu.resource_metadata_count(&target.metadata), 2)
    testing.expect_value(t, target.state[1], gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, target.state[40], gpu.BUFFER_USES_VERTEX)

    // A second merge of the same scope unions rather than duplicating.
    testing.expect(t, gpu.buffer_usage_scope_merge_usage_scope(&target, &source, &current, &added))
    testing.expect_value(t, gpu.resource_metadata_count(&target.metadata), 2)
    testing.expect_value(t, target.state[1], gpu.BUFFER_USES_UNIFORM)
}

@(test)
test_buffer_scope_remove_usage :: proc(t: ^testing.T) {
    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)

    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 5, test_buffer(5), gpu.BUFFER_USES_UNIFORM, &current, &added))
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 5, test_buffer(5), gpu.BUFFER_USES_INDIRECT, &current, &added))

    // Removing one use keeps the other, and the member.
    gpu.buffer_usage_scope_remove_usage(&scope, 5, gpu.BUFFER_USES_INDIRECT)
    testing.expect(t, gpu.resource_metadata_contains(&scope.metadata, 5))
    testing.expect_value(t, scope.state[5], gpu.BUFFER_USES_UNIFORM)

    // Removing the last use drops the member.
    gpu.buffer_usage_scope_remove_usage(&scope, 5, gpu.BUFFER_USES_UNIFORM)
    testing.expect(t, !gpu.resource_metadata_contains(&scope.metadata, 5))
    testing.expect_value(t, gpu.resource_metadata_count(&scope.metadata), 0)
}

@(test)
test_buffer_bind_group_state :: proc(t: ^testing.T) {
    group: gpu.Buffer_Bind_Group_State
    gpu.buffer_bind_group_state_init(&group, context.allocator)
    defer gpu.buffer_bind_group_state_free(&group)

    gpu.buffer_bind_group_state_insert_single(&group, 7, test_buffer(7), gpu.BUFFER_USES_UNIFORM)
    gpu.buffer_bind_group_state_insert_single(&group, 2, test_buffer(2), gpu.BUFFER_USES_COPY_SRC)
    gpu.buffer_bind_group_state_insert_single(&group, 5, test_buffer(5), gpu.BUFFER_USES_VERTEX)
    // A second binding of the same buffer is kept: the group may legally hold
    // conflicting uses, and the merge is where they surface.
    gpu.buffer_bind_group_state_insert_single(&group, 7, test_buffer(7), gpu.BUFFER_USES_COPY_SRC)
    testing.expect_value(t, gpu.buffer_bind_group_state_len(&group), 4)

    gpu.buffer_bind_group_state_optimize(&group)
    testing.expect_value(t, group.buffers[0].index, 2)
    testing.expect_value(t, group.buffers[1].index, 5)
    testing.expect_value(t, group.buffers[2].index, 7)
    testing.expect_value(t, group.buffers[3].index, 7)

    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)
    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses
    // Both uses of buffer 7 are inclusive, so they combine.
    testing.expect(t, gpu.buffer_usage_scope_merge_bind_group(&scope, &group, &current, &added))
    testing.expect_value(t, gpu.resource_metadata_count(&scope.metadata), 3)
    testing.expect_value(t, scope.state[7], gpu.BUFFER_USES_UNIFORM | gpu.BUFFER_USES_COPY_SRC)

    // A group holding one buffer read and written is the conflict the merge must
    // report.
    conflicting: gpu.Buffer_Bind_Group_State
    gpu.buffer_bind_group_state_init(&conflicting, context.allocator)
    defer gpu.buffer_bind_group_state_free(&conflicting)
    gpu.buffer_bind_group_state_insert_single(&conflicting, 9, test_buffer(9), gpu.BUFFER_USES_UNIFORM)
    gpu.buffer_bind_group_state_insert_single(&conflicting, 9, test_buffer(9), gpu.BUFFER_USES_STORAGE_READ_WRITE)
    testing.expect(t, !gpu.buffer_usage_scope_merge_bind_group(&scope, &conflicting, &current, &added))
    testing.expect_value(t, current, gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, added, gpu.BUFFER_USES_STORAGE_READ_WRITE)
}

@(test)
test_buffer_tracker_from_scope :: proc(t: ^testing.T) {
    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)

    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 1, test_buffer(1), gpu.BUFFER_USES_UNIFORM, &current, &added))
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 9, test_buffer(9), gpu.BUFFER_USES_VERTEX, &current, &added))

    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)

    gpu.buffer_tracker_set_from_usage_scope(&tracker, &scope)
    testing.expect_value(t, gpu.resource_metadata_count(&tracker.metadata), 2)
    testing.expect(t, gpu.buffer_tracker_contains(&tracker, 1))
    testing.expect_value(t, tracker.start[1], gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, tracker.end[1], gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, len(tracker.temp), 0)

    // A second application over the same state needs nothing.
    gpu.buffer_tracker_set_from_usage_scope(&tracker, &scope)
    testing.expect_value(t, len(tracker.temp), 0)
}

@(test)
test_buffer_tracker_sparse_moves_and_removes :: proc(t: ^testing.T) {
    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)

    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 1, test_buffer(1), gpu.BUFFER_USES_UNIFORM, &current, &added))
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 9, test_buffer(9), gpu.BUFFER_USES_VERTEX, &current, &added))

    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)

    take := []gpu.Tracker_Index{9}
    gpu.buffer_tracker_set_and_remove_from_usage_scope_sparse(&tracker, &scope, take)

    // Adopted and removed from the scope...
    testing.expect(t, gpu.buffer_tracker_contains(&tracker, 9))
    testing.expect_value(t, tracker.end[9], gpu.BUFFER_USES_VERTEX)
    testing.expect(t, !gpu.resource_metadata_contains(&scope.metadata, 9))
    // ...leaving the members the caller did not name alone.
    testing.expect(t, gpu.resource_metadata_contains(&scope.metadata, 1))
    testing.expect(t, !gpu.buffer_tracker_contains(&tracker, 1))
}

@(test)
test_device_buffer_tracker_grows_on_demand :: proc(t: ^testing.T) {
    device: gpu.Device_Buffer_Tracker
    gpu.device_buffer_tracker_init(&device, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.device_buffer_tracker_free(&device)
    out: [dynamic]gpu.Buffer_State_Transition
    defer delete(out)

    // No presize: the first contact with a high index grows the state table.
    gpu.device_buffer_tracker_set_single(&device, 1000, test_buffer(1000), gpu.BUFFER_USES_UNIFORM, &out)
    testing.expect(t, gpu.resource_metadata_contains(&device.metadata, 1000))
    testing.expect_value(t, device.current[1000], gpu.BUFFER_USES_UNIFORM)
    // The move out of the zero state is a real transition.
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.BUFFER_USES_UNINITIALIZED)
    testing.expect_value(t, out[0].to, gpu.BUFFER_USES_UNIFORM)
}

@(test)
test_device_buffer_tracker_applies_a_transcript :: proc(t: ^testing.T) {
    device: gpu.Device_Buffer_Tracker
    gpu.device_buffer_tracker_init(&device, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.device_buffer_tracker_free(&device)
    out: [dynamic]gpu.Buffer_State_Transition
    defer delete(out)

    gpu.device_buffer_tracker_set_single(&device, 4, test_buffer(4), gpu.BUFFER_USES_COPY_DST, &out)
    clear(&out)

    tracker: gpu.Buffer_Tracker
    gpu.buffer_tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.buffer_tracker_free(&tracker)
    gpu.buffer_tracker_set_single(&tracker, 4, test_buffer(4), gpu.BUFFER_USES_UNIFORM)

    gpu.device_buffer_tracker_set_from_tracker_and_drain_transitions(&device, &tracker, &out)

    // One transition, from the device state to the transcript's entry state.
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, out[0].to, gpu.BUFFER_USES_UNIFORM)
    // The device advances to the transcript's exit state.
    testing.expect_value(t, device.current[4], gpu.BUFFER_USES_UNIFORM)
}

@(test)
test_device_buffer_tracker_applies_a_scope :: proc(t: ^testing.T) {
    device: gpu.Device_Buffer_Tracker
    gpu.device_buffer_tracker_init(&device, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.device_buffer_tracker_free(&device)
    out: [dynamic]gpu.Buffer_State_Transition
    defer delete(out)

    gpu.device_buffer_tracker_set_single(&device, 2, test_buffer(2), gpu.BUFFER_USES_COPY_DST, &out)
    clear(&out)

    scope: gpu.Buffer_Usage_Scope
    gpu.buffer_usage_scope_init(&scope, context.allocator)
    defer gpu.buffer_usage_scope_free(&scope)
    current: gpu.Buffer_Uses
    added: gpu.Buffer_Uses
    testing.expect(t, gpu.buffer_usage_scope_merge_single(&scope, 2, test_buffer(2), gpu.BUFFER_USES_UNIFORM, &current, &added))

    gpu.device_buffer_tracker_set_from_usage_scope_and_drain_transitions(&device, &scope, &out)
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.BUFFER_USES_COPY_DST)
    testing.expect_value(t, out[0].to, gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, device.current[2], gpu.BUFFER_USES_UNIFORM)
}

@(test)
test_device_buffer_tracker_forget :: proc(t: ^testing.T) {
    device: gpu.Device_Buffer_Tracker
    gpu.device_buffer_tracker_init(&device, context.allocator, gpu.BUFFER_USES_ORDERED)
    defer gpu.device_buffer_tracker_free(&device)
    out: [dynamic]gpu.Buffer_State_Transition
    defer delete(out)

    gpu.device_buffer_tracker_set_single(&device, 6, test_buffer(6), gpu.BUFFER_USES_UNIFORM, &out)
    testing.expect(t, gpu.resource_metadata_contains(&device.metadata, 6))

    // A released handle forgets its state, so a buffer created into the same index
    // later cannot inherit it.
    gpu.device_buffer_tracker_forget(&device, 6)
    testing.expect(t, !gpu.resource_metadata_contains(&device.metadata, 6))
    testing.expect_value(t, gpu.resource_metadata_count(&device.metadata), 0)
}

// -----------------------------------------------------------------------------
// Texture
// -----------------------------------------------------------------------------

@(test)
test_texture_tracker_first_touch_and_transition :: proc(t: ^testing.T) {
    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)

    texture := test_tracked_texture(3, 1, 1)
    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_COPY_DST)
    testing.expect_value(t, len(tracker.temp), 0)

    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, len(tracker.temp), 1)
    testing.expect_value(t, tracker.temp[0].from, gpu.TEXTURE_USES_COPY_DST)
    testing.expect_value(t, tracker.temp[0].to, gpu.TEXTURE_USES_RESOURCE)
    // The transcript is entered in the first state and left in the second.
    testing.expect_value(t, tracker.start.simple[3], gpu.TEXTURE_USES_COPY_DST)
    testing.expect_value(t, tracker.end.simple[3], gpu.TEXTURE_USES_RESOURCE)
}

@(test)
test_texture_tracker_per_mip :: proc(t: ^testing.T) {
    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)

    texture := test_tracked_texture(1, 2, 1)
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(0, 1), gpu.TEXTURE_USES_COLOR_TARGET)
    // A subrange on first contact makes the state complex, with the untouched mip
    // left unknown.
    testing.expect(t, gpu.texture_state_set_is_complex(&tracker.end, 1))
    end_state := gpu.texture_state_set_complex_at(&tracker.end, 1)
    testing.expect_value(t, value_of(end_state, 0, 0), gpu.TEXTURE_USES_COLOR_TARGET)
    testing.expect_value(t, value_of(end_state, 1, 0), gpu.TEXTURE_USES_UNKNOWN)

    gpu.texture_tracker_set_single(&tracker, texture, mip_range(0, 1), gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, len(tracker.temp), 1)
    testing.expect_value(t, tracker.temp[0].selector.mip_start, 0)
    testing.expect_value(t, tracker.temp[0].selector.mip_count, 1)
    testing.expect_value(t, tracker.temp[0].from, gpu.TEXTURE_USES_COLOR_TARGET)
    testing.expect_value(t, tracker.temp[0].to, gpu.TEXTURE_USES_RESOURCE)
}

@(test)
test_texture_tracker_late_first_use_fixes_up_start :: proc(t: ^testing.T) {
    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)

    texture := test_tracked_texture(1, 2, 1)
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(0, 1), gpu.TEXTURE_USES_RESOURCE)
    // Mip 1 is met for the first time here. Its transition is skipped (nothing was
    // known), but the *start* state has to learn the use, or the submission's
    // pre-barrier would never take the image there.
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(1, 1), gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, len(tracker.temp), 0)

    end_state := gpu.texture_state_set_complex_at(&tracker.end, 1)
    start_state := gpu.texture_state_set_complex_at(&tracker.start, 1)
    testing.expect_value(t, value_of(end_state, 1, 0), gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, value_of(start_state, 0, 0), gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, value_of(start_state, 1, 0), gpu.TEXTURE_USES_RESOURCE)
}

@(test)
test_texture_tracker_skips_ordered_and_aspects :: proc(t: ^testing.T) {
    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)

    texture := test_tracked_texture(2, 1, 1)
    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_RESOURCE)
    // An unchanged ordered state needs nothing.
    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, len(tracker.temp), 0)

    // Sampling the other read-only aspect is the same access: no barrier.
    gpu.texture_tracker_set_single(
        &tracker,
        texture,
        texture.full,
        gpu.TEXTURE_USES_RESOURCE | gpu.TEXTURE_USES_DEPTH_SAMPLED,
    )
    gpu.texture_tracker_clear_pending(&tracker)
    gpu.texture_tracker_set_single(
        &tracker,
        texture,
        texture.full,
        gpu.TEXTURE_USES_RESOURCE | gpu.TEXTURE_USES_STENCIL_SAMPLED,
    )
    testing.expect_value(t, len(tracker.temp), 0)

    // A real difference still emits.
    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_COPY_SRC)
    testing.expect_value(t, len(tracker.temp), 1)
}

@(test)
test_texture_scope_conflict :: proc(t: ^testing.T) {
    scope: gpu.Texture_Usage_Scope
    gpu.texture_usage_scope_init(&scope, context.allocator)
    defer gpu.texture_usage_scope_free(&scope)

    texture := test_tracked_texture(1, 1, 1)
    at: gpu.Texture_Selector
    current: gpu.Texture_Uses
    added: gpu.Texture_Uses

    testing.expect(t, gpu.texture_usage_scope_merge_single(&scope, texture, false, {}, gpu.TEXTURE_USES_RESOURCE, &at, &current, &added))
    // A color target may not share the pass with a sampled read.
    testing.expect(t, !gpu.texture_usage_scope_merge_single(&scope, texture, false, {}, gpu.TEXTURE_USES_COLOR_TARGET, &at, &current, &added))
    testing.expect_value(t, current, gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, added, gpu.TEXTURE_USES_COLOR_TARGET)
    testing.expect_value(t, at.mip_count, 1)
    testing.expect_value(t, at.layer_count, 1)
    // The rejected merge left the state alone.
    testing.expect_value(t, scope.set.simple[1], gpu.TEXTURE_USES_RESOURCE)

    // Two reads combine.
    testing.expect(t, gpu.texture_usage_scope_merge_single(&scope, texture, false, {}, gpu.TEXTURE_USES_COPY_SRC, &at, &current, &added))
    testing.expect_value(t, scope.set.simple[1], gpu.TEXTURE_USES_RESOURCE | gpu.TEXTURE_USES_COPY_SRC)
}

@(test)
test_texture_invalid_depth_stencil_table :: proc(t: ^testing.T) {
    // One aspect written while the other is read is legal.
    testing.expect(t, !gpu.texture_uses_is_invalid(gpu.TEXTURE_USES_DEPTH_WRITE | gpu.TEXTURE_USES_STENCIL_READ))
    testing.expect(t, !gpu.texture_uses_is_invalid(gpu.TEXTURE_USES_STENCIL_WRITE | gpu.TEXTURE_USES_DEPTH_READ))
    // A written aspect may also be sampled when the other one is read.
    testing.expect(
        t,
        !gpu.texture_uses_is_invalid(
            gpu.TEXTURE_USES_DEPTH_WRITE |
            gpu.TEXTURE_USES_RESOURCE |
            gpu.TEXTURE_USES_STENCIL_READ |
            gpu.TEXTURE_USES_STENCIL_SAMPLED,
        ),
    )
    // Two writes on one aspect are not a real state.
    testing.expect(
        t,
        gpu.texture_uses_is_invalid(
            gpu.TEXTURE_USES_DEPTH_WRITE |
            gpu.TEXTURE_USES_RESOURCE |
            gpu.TEXTURE_USES_STENCIL_READ |
            gpu.TEXTURE_USES_DEPTH_SAMPLED,
        ),
    )
    // An exclusive use never combines.
    testing.expect(t, gpu.texture_uses_is_invalid(gpu.TEXTURE_USES_COLOR_TARGET | gpu.TEXTURE_USES_RESOURCE))
    testing.expect(t, gpu.texture_uses_is_invalid(gpu.TEXTURE_USES_COPY_DST | gpu.TEXTURE_USES_RESOURCE))
    testing.expect(t, !gpu.texture_uses_is_invalid(gpu.TEXTURE_USES_RESOURCE | gpu.TEXTURE_USES_COPY_SRC))
}

@(test)
test_texture_promotion_preserves_the_rest :: proc(t: ^testing.T) {
    texture := test_tracked_texture(1, 1, 4)

    scope: gpu.Texture_Usage_Scope
    gpu.texture_usage_scope_init(&scope, context.allocator)
    defer gpu.texture_usage_scope_free(&scope)
    at: gpu.Texture_Selector
    current: gpu.Texture_Uses
    added: gpu.Texture_Uses

    // The whole texture is a copy source...
    testing.expect(t, gpu.texture_usage_scope_merge_single(&scope, texture, false, {}, gpu.TEXTURE_USES_COPY_SRC, &at, &current, &added))
    // ...and one layer is also sampled: promoting to a complex state must keep the
    // other three layers where they were.
    testing.expect(
        t,
        gpu.texture_usage_scope_merge_single(
            &scope,
            texture,
            true,
            layer_range(0, 0, 1),
            gpu.TEXTURE_USES_RESOURCE,
            &at,
            &current,
            &added,
        ),
    )

    testing.expect(t, gpu.texture_state_set_is_complex(&scope.set, 1))
    state := gpu.texture_state_set_complex_at(&scope.set, 1)
    testing.expect_value(t, value_of(state, 0, 0), gpu.TEXTURE_USES_COPY_SRC | gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, value_of(state, 0, 1), gpu.TEXTURE_USES_COPY_SRC)
    testing.expect_value(t, value_of(state, 0, 3), gpu.TEXTURE_USES_COPY_SRC)
}

@(test)
test_texture_complex_collapses_to_simple :: proc(t: ^testing.T) {
    texture := test_tracked_texture(1, 2, 1)

    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)

    gpu.texture_tracker_set_single(&tracker, texture, mip_range(0, 1), gpu.TEXTURE_USES_COLOR_TARGET)
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(1, 1), gpu.TEXTURE_USES_COPY_SRC)
    testing.expect(t, gpu.texture_state_set_is_complex(&tracker.end, 1))

    // One use over the whole texture collapses it again.
    gpu.texture_tracker_set_single(&tracker, texture, texture.full, gpu.TEXTURE_USES_RESOURCE)
    testing.expect(t, !gpu.texture_state_set_is_complex(&tracker.end, 1))
    testing.expect_value(t, tracker.end.simple[1], gpu.TEXTURE_USES_RESOURCE)
    // Both mips moved, so both are named by the transitions.
    testing.expect(t, len(tracker.temp) >= 1)
}

@(test)
test_texture_device_tracker_grows_on_demand :: proc(t: ^testing.T) {
    device: gpu.Device_Texture_Tracker
    gpu.device_texture_tracker_init(&device, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_texture_tracker_free(&device)
    out: [dynamic]gpu.Texture_State_Transition
    defer delete(out)

    texture := test_tracked_texture(1000, 1, 1)
    gpu.device_texture_tracker_set_single(&device, texture, texture.full, gpu.TEXTURE_USES_RESOURCE, &out)
    testing.expect(t, gpu.resource_metadata_contains(&device.metadata, 1000))
    // The move out of the zero state is a real transition.
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.TEXTURE_USES_UNINITIALIZED)
    testing.expect_value(t, out[0].to, gpu.TEXTURE_USES_RESOURCE)
}

@(test)
test_texture_device_tracker_applies_a_transcript :: proc(t: ^testing.T) {
    texture := test_tracked_texture(4, 2, 1)

    device: gpu.Device_Texture_Tracker
    gpu.device_texture_tracker_init(&device, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_texture_tracker_free(&device)
    out: [dynamic]gpu.Texture_State_Transition
    defer delete(out)
    gpu.device_texture_tracker_set_single(&device, texture, texture.full, gpu.TEXTURE_USES_COPY_DST, &out)
    clear(&out)

    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(0, 1), gpu.TEXTURE_USES_RESOURCE)

    gpu.device_texture_tracker_set_from_tracker_and_drain_transitions(&device, &tracker, &out)
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.TEXTURE_USES_COPY_DST)
    testing.expect_value(t, out[0].to, gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, out[0].selector.mip_start, 0)
    testing.expect_value(t, out[0].selector.mip_count, 1)
}

@(test)
test_texture_device_forget_frees_the_subresource_table :: proc(t: ^testing.T) {
    texture := test_tracked_texture(2, 2, 2)

    device: gpu.Device_Texture_Tracker
    gpu.device_texture_tracker_init(&device, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_texture_tracker_free(&device)
    out: [dynamic]gpu.Texture_State_Transition
    defer delete(out)

    gpu.device_texture_tracker_set_single(&device, texture, mip_range(0, 2), gpu.TEXTURE_USES_RESOURCE, &out)
    testing.expect(t, gpu.texture_state_set_is_complex(&device.current, 2))
    testing.expect(t, gpu.resource_metadata_contains(&device.metadata, 2))

    gpu.device_texture_tracker_forget(&device, texture.index)
    testing.expect(t, !gpu.resource_metadata_contains(&device.metadata, 2))
    testing.expect(t, !gpu.texture_state_set_is_complex(&device.current, 2))
}

// A pool slot is not an identity. A release recycles the slot (and `forget` drops
// the entry), but the state array keeps the old texture's layout in that cell; the
// next texture to land there must start from nothing, or its first submission
// would skip the entry barrier and run in whatever layout the previous image was
// left in.
@(test)
test_texture_device_tracker_does_not_inherit_a_recycled_slot :: proc(t: ^testing.T) {
    device: gpu.Device_Texture_Tracker
    gpu.device_texture_tracker_init(&device, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_texture_tracker_free(&device)
    out: [dynamic]gpu.Texture_State_Transition
    defer delete(out)

    first := test_tracked_texture(7, 1, 1, 1)
    gpu.device_texture_tracker_set_single(&device, first, first.full, gpu.TEXTURE_USES_COLOR_TARGET, &out)
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.TEXTURE_USES_UNINITIALIZED)
    clear(&out)

    // The handle dies and the slot is handed out again: same index, next
    // generation, which is exactly what a release followed by a create produces.
    gpu.device_texture_tracker_forget(&device, first.index)
    second := test_tracked_texture(7, 1, 1, 2)

    gpu.device_texture_tracker_set_single(&device, second, second.full, gpu.TEXTURE_USES_COPY_SRC, &out)
    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.TEXTURE_USES_UNINITIALIZED)
    testing.expect_value(t, out[0].to, gpu.TEXTURE_USES_COPY_SRC)

    // The diagnostics answer per resource, never per slot.
    testing.expect_value(t, gpu.device_texture_tracker_state_at(&device, second.index, second.texture), gpu.TEXTURE_USES_COPY_SRC)
    testing.expect_value(t, gpu.device_texture_tracker_state_at(&device, first.index, first.texture), gpu.TEXTURE_USES_UNKNOWN)
    testing.expect_value(
        t,
        gpu.device_texture_tracker_subresource_state(&device, first.index, first.texture, 0, 0),
        gpu.TEXTURE_USES_UNKNOWN,
    )
}

// A subresource the device has never recorded is `Uninitialized`, not the `Unknown`
// marker: the marker is bookkeeping ("this set says nothing"), which the barrier
// primitives skip â€” right for a transcript, wrong for the device, where "nothing
// was ever recorded" means the image is still `UNDEFINED`. Without the distinction
// only the first subresource a texture's first submission touched ever leaves
// `UNDEFINED`, which is what a multiplexed attachment exposed.
@(test)
test_texture_device_tracker_transitions_unknown_subresources :: proc(t: ^testing.T) {
    device: gpu.Device_Texture_Tracker
    gpu.device_texture_tracker_init(&device, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_texture_tracker_free(&device)
    out: [dynamic]gpu.Texture_State_Transition
    defer delete(out)

    // A 2x2 grid: mip 0 and 1, layers 0 and 1, as one texture.
    texture := test_tracked_texture(5, 2, 2)
    // The first submission touches mip 0 / layer 0 only, which leaves the other
    // three subresources as `Unknown` fillers in the device's state.
    gpu.device_texture_tracker_set_single(&device, texture, mip_range(0, 1), gpu.TEXTURE_USES_COLOR_TARGET, &out)
    testing.expect(t, gpu.texture_state_set_is_complex(&device.current, 5))
    clear(&out)

    // A second submission uses mip 1 / layer 0: it must be transitioned out of
    // `UNDEFINED`, even though the device's state says `Unknown` there.
    tracker: gpu.Texture_Tracker
    gpu.texture_tracker_init(&tracker, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&tracker)
    gpu.texture_tracker_set_single(&tracker, texture, mip_range(1, 1), gpu.TEXTURE_USES_COPY_SRC)
    gpu.device_texture_tracker_set_from_tracker_and_drain_transitions(&device, &tracker, &out)

    testing.expect_value(t, len(out), 1)
    testing.expect_value(t, out[0].from, gpu.TEXTURE_USES_UNINITIALIZED)
    testing.expect_value(t, out[0].to, gpu.TEXTURE_USES_COPY_SRC)
    testing.expect_value(t, out[0].selector.mip_start, 1)
    testing.expect_value(t, out[0].selector.layer_start, 0)

    // A transcript's `Unknown` keeps its own meaning: the recorder never touched
    // the subresource, so it derives nothing for it.
    recorder: gpu.Texture_Tracker
    gpu.texture_tracker_init(&recorder, context.allocator, gpu.TEXTURE_USES_ORDERED)
    defer gpu.texture_tracker_free(&recorder)
    gpu.texture_tracker_set_single(&recorder, texture, mip_range(0, 1), gpu.TEXTURE_USES_RESOURCE)
    gpu.texture_tracker_insert_or_barrier_update(
        &recorder,
        5,
        texture,
        gpu.texture_state_provider_selector(mip_range(0, 1), gpu.TEXTURE_USES_COPY_SRC),
        nil,
    )
    // The recorder's second use of the same subresource moved it; nothing was
    // derived for the subresources it never named.
    for transition in recorder.temp {
        testing.expect(t, transition.selector.mip_start == 0 && transition.selector.layer_count == 1)
    }
}

@(test)
test_texture_selector_equals :: proc(t: ^testing.T) {
    a := mip_range(1, 2)
    b := mip_range(1, 2)
    c := mip_range(0, 2)
    testing.expect(t, gpu.texture_selector_equals(a, b))
    testing.expect(t, !gpu.texture_selector_equals(a, c))
}

// -----------------------------------------------------------------------------
// Memory initialisation
// -----------------------------------------------------------------------------

@(private = "file")
init_range :: proc(mip: u32, mip_count: u32, layer: u32, layer_count: u32) -> gpu.Texture_Init_Range {
    return {
        mip_start = mip,
        mip_end = mip + mip_count,
        layer_start = layer,
        layer_end = layer + layer_count,
    }
}

@(private = "file")
expect_range :: proc(t: ^testing.T, range: ^gpu.Texture_Init_Range, mip: u32, layer_start: u32, layer_end: u32) {
    testing.expect_value(t, range.mip_start, mip)
    testing.expect_value(t, range.mip_end, mip + 1)
    testing.expect_value(t, range.layer_start, layer_start)
    testing.expect_value(t, range.layer_end, layer_end)
}

@(test)
test_texture_init_starts_undefined :: proc(t: ^testing.T) {
    init: gpu.Texture_Init_Tracker
    gpu.texture_init_tracker_init(&init, context.allocator, 2, 4)
    defer gpu.texture_init_tracker_free(&init)

    testing.expect(t, !gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 0, 1)))
    testing.expect(t, !gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 2, 0, 4)))
    testing.expect(t, !gpu.texture_init_tracker_is_partially_initialized(&init, init_range(0, 2, 0, 4)))
}

@(test)
test_texture_init_marks_a_range :: proc(t: ^testing.T) {
    init: gpu.Texture_Init_Tracker
    gpu.texture_init_tracker_init(&init, context.allocator, 2, 4)
    defer gpu.texture_init_tracker_free(&init)

    gpu.texture_init_tracker_mark_initialized(&init, init_range(0, 1, 1, 2))
    // Mip 0, layers 1..3 are defined; nothing else is.
    testing.expect(t, gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 1, 2)))
    testing.expect(t, gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 2, 1)))
    testing.expect(t, !gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 0, 3)))
    testing.expect(t, !gpu.texture_init_tracker_check_is_initialized(&init, init_range(1, 1, 1, 2)))
    testing.expect(t, gpu.texture_init_tracker_is_partially_initialized(&init, init_range(0, 2, 0, 4)))
}

@(test)
test_texture_init_drains_undefined_ranges :: proc(t: ^testing.T) {
    init: gpu.Texture_Init_Tracker
    gpu.texture_init_tracker_init(&init, context.allocator, 1, 4)
    defer gpu.texture_init_tracker_free(&init)

    gpu.texture_init_tracker_mark_initialized(&init, init_range(0, 1, 0, 2))

    // Layers 2..4 are the undefined part, and draining defines them.
    missing: [dynamic]gpu.Texture_Init_Range
    defer delete(missing)
    gpu.texture_init_tracker_drain_uninitialized(&init, init_range(0, 1, 0, 4), &missing)
    testing.expect_value(t, len(missing), 1)
    expect_range(t, &missing[0], 0, 2, 4)
    testing.expect(t, gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 0, 4)))

    // Draining the same range again finds nothing undefined.
    clear(&missing)
    gpu.texture_init_tracker_drain_uninitialized(&init, init_range(0, 1, 0, 4), &missing)
    testing.expect_value(t, len(missing), 0)
}

@(test)
test_texture_init_drain_splits_around_defined_layers :: proc(t: ^testing.T) {
    init: gpu.Texture_Init_Tracker
    gpu.texture_init_tracker_init(&init, context.allocator, 1, 4)
    defer gpu.texture_init_tracker_free(&init)

    gpu.texture_init_tracker_mark_initialized(&init, init_range(0, 1, 1, 1))
    gpu.texture_init_tracker_mark_initialized(&init, init_range(0, 1, 3, 1))

    missing: [dynamic]gpu.Texture_Init_Range
    defer delete(missing)
    gpu.texture_init_tracker_drain_uninitialized(&init, init_range(0, 1, 0, 4), &missing)
    testing.expect_value(t, len(missing), 2)
    expect_range(t, &missing[0], 0, 0, 1)
    expect_range(t, &missing[1], 0, 2, 3)
    testing.expect(t, gpu.texture_init_tracker_check_is_initialized(&init, init_range(0, 1, 0, 4)))
}

@(test)
test_texture_init_out_of_range_marks_nothing :: proc(t: ^testing.T) {
    init: gpu.Texture_Init_Tracker
    gpu.texture_init_tracker_init(&init, context.allocator, 1, 1)
    defer gpu.texture_init_tracker_free(&init)

    // A range past the texture is not initialized and cannot be marked.
    testing.expect(t, !gpu.texture_init_tracker_check_is_initialized(&init, init_range(1, 1, 0, 1)))
    gpu.texture_init_tracker_mark_initialized(&init, init_range(1, 1, 0, 1))
    testing.expect(t, !gpu.texture_init_tracker_is_partially_initialized(&init, init_range(0, 2, 0, 2)))

    missing: [dynamic]gpu.Texture_Init_Range
    defer delete(missing)
    gpu.texture_init_tracker_drain_uninitialized(&init, init_range(0, 1, 0, 1), &missing)
    testing.expect_value(t, len(missing), 1)
}

@(test)
test_tracker_records_init_actions :: proc(t: ^testing.T) {
    tracker: gpu.Tracker
    gpu.tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&tracker)

    texture := test_texture_handle(3)
    gpu.tracker_record_init(&tracker, texture, init_range(0, 1, 0, 2), .Implicitly_Initialized)
    gpu.tracker_record_init(&tracker, texture, init_range(0, 1, 0, 1), .Needs_Initialized_Memory)
    // Actions are applied in order at submit; the list only records them.
    testing.expect_value(t, len(tracker.init_actions), 2)

    gpu.tracker_clear(&tracker)
    testing.expect_value(t, len(tracker.init_actions), 0)
}

@(private = "file")
expect_hole :: proc(t: ^testing.T, hole: ^gpu.Buffer_Init_Range, start: u64, end: u64) {
    testing.expect_value(t, hole.start, start)
    testing.expect_value(t, hole.end, end)
}

@(test)
test_buffer_init_starts_undefined :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 64)
    defer gpu.buffer_init_tracker_free(&init)

    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 1))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 64))
}

@(test)
test_buffer_init_marking_is_precise :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 64)
    defer gpu.buffer_init_tracker_free(&init)

    gpu.buffer_init_tracker_mark_initialized(&init, 16, 32)
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 16, 32))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 32))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 16, 64))

    // A write inside one hole splits it in two.
    gpu.buffer_init_tracker_mark_initialized(&init, 8, 24)
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 8, 32))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 8))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 32, 64))

    // A write covering a hole entirely removes it.
    gpu.buffer_init_tracker_mark_initialized(&init, 0, 8)
    gpu.buffer_init_tracker_mark_initialized(&init, 32, 64)
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 0, 64))
}

@(test)
test_buffer_init_drain_hands_back_the_holes :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 64)
    defer gpu.buffer_init_tracker_free(&init)

    gpu.buffer_init_tracker_mark_initialized(&init, 16, 32)
    holes: [dynamic]gpu.Buffer_Init_Range
    defer delete(holes)
    gpu.buffer_init_tracker_drain_uninitialized(&init, 0, 64, &holes)
    testing.expect_value(t, len(holes), 2)
    expect_hole(t, &holes[0], 0, 16)
    expect_hole(t, &holes[1], 32, 64)
    // Draining counts the whole range as defined.
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 0, 64))

    clear(&holes)
    gpu.buffer_init_tracker_drain_uninitialized(&init, 0, 64, &holes)
    testing.expect_value(t, len(holes), 0)
}

@(test)
test_buffer_init_drain_clamps_to_the_query :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 64)
    defer gpu.buffer_init_tracker_free(&init)

    holes: [dynamic]gpu.Buffer_Init_Range
    defer delete(holes)
    gpu.buffer_init_tracker_drain_uninitialized(&init, 8, 16, &holes)
    testing.expect_value(t, len(holes), 1)
    expect_hole(t, &holes[0], 8, 16)
    // Only the queried part is defined; the rest of the buffer still is not.
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 64))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 16, 32))
}

@(test)
test_buffer_init_discard_reopens_a_range :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 32)
    defer gpu.buffer_init_tracker_free(&init)

    gpu.buffer_init_tracker_mark_initialized(&init, 0, 32)
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 0, 32))
    gpu.buffer_init_tracker_mark_uninitialized(&init, 8, 16)
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 32))
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 8, 16))

    // Touching ranges merge rather than piling up.
    gpu.buffer_init_tracker_mark_uninitialized(&init, 16, 24)
    holes: [dynamic]gpu.Buffer_Init_Range
    defer delete(holes)
    gpu.buffer_init_tracker_drain_uninitialized(&init, 0, 32, &holes)
    testing.expect_value(t, len(holes), 1)
    expect_hole(t, &holes[0], 8, 24)
}

@(test)
test_buffer_init_out_of_range_marks_nothing :: proc(t: ^testing.T) {
    init: gpu.Buffer_Init_Tracker
    gpu.buffer_init_tracker_init(&init, context.allocator, 16)
    defer gpu.buffer_init_tracker_free(&init)

    gpu.buffer_init_tracker_mark_initialized(&init, 8, 64)
    testing.expect(t, gpu.buffer_init_tracker_check_is_initialized(&init, 8, 16))
    // The write stops at the buffer's end, so nothing past it is claimed.
    testing.expect(t, !gpu.buffer_init_tracker_check_is_initialized(&init, 0, 8))

    holes: [dynamic]gpu.Buffer_Init_Range
    defer delete(holes)
    gpu.buffer_init_tracker_drain_uninitialized(&init, 32, 64, &holes)
    testing.expect_value(t, len(holes), 0)
}

// A multi-planar format tracks its planes apart, exactly as a combined
// depth-stencil format tracks its two aspects: the selector names the slot, and
// `All` names both. The mapping is what makes a write to plane 0 leave plane 1
// undefined.
@(test)
test_multi_planar_aspect_slots :: proc(t: ^testing.T) {
    both := gpu.init_tracked_aspects(.NV12, .All)
    testing.expect_value(t, both.count, 2)
    testing.expect_value(t, both.slots[0], gpu.INIT_ASPECT_PRIMARY)
    testing.expect_value(t, both.slots[1], gpu.INIT_ASPECT_PLANE1)
    testing.expect_value(t, gpu.init_aspect_for_slot(.NV12, both.slots[0]), gpu.Texture_Aspect.Plane0)
    testing.expect_value(t, gpu.init_aspect_for_slot(.NV12, both.slots[1]), gpu.Texture_Aspect.Plane1)

    plane0 := gpu.init_tracked_aspects(.NV12, .Plane0)
    testing.expect(t, plane0.count == 1 && plane0.slots[0] == gpu.INIT_ASPECT_PRIMARY)
    plane1 := gpu.init_tracked_aspects(.P010, .Plane1)
    testing.expect(t, plane1.count == 1 && plane1.slots[0] == gpu.INIT_ASPECT_PLANE1)

    // A single-aspect format keeps its one slot whatever the selector says.
    colour := gpu.init_tracked_aspects(.RGBA8_Unorm, .All)
    testing.expect(t, colour.count == 1 && colour.slots[0] == gpu.INIT_ASPECT_PRIMARY)
    testing.expect_value(t, gpu.init_aspect_for_slot(.RGBA8_Unorm, 0), gpu.Texture_Aspect.All)

    // A combined depth-stencil format keeps its depth/stencil split.
    depth_stencil := gpu.init_tracked_aspects(.Depth24Plus_Stencil8, .All)
    testing.expect_value(t, depth_stencil.count, 2)
    testing.expect_value(t, depth_stencil.slots[1], gpu.INIT_ASPECT_STENCIL)
}

// -----------------------------------------------------------------------------
// Tracker
// -----------------------------------------------------------------------------

@(test)
test_usage_scope_merges_and_reports_conflicts :: proc(t: ^testing.T) {
    scope: gpu.Usage_Scope
    gpu.usage_scope_init(&scope, context.allocator)
    defer gpu.usage_scope_free(&scope)

    conflict: gpu.Usage_Conflict
    texture := test_tracked_texture(1, 1, 1)
    buffer := test_buffer(2)

    // Compatible uses accumulate.
    testing.expect(t, gpu.usage_scope_add_texture(&scope, texture, texture.full, gpu.TEXTURE_USES_COPY_SRC, &conflict))
    testing.expect(t, gpu.usage_scope_add_texture(&scope, texture, texture.full, gpu.TEXTURE_USES_RESOURCE, &conflict))
    testing.expect_value(
        t,
        scope.textures.set.simple[1],
        gpu.TEXTURE_USES_COPY_SRC | gpu.TEXTURE_USES_RESOURCE,
    )

    // An exclusive use on a non-empty state is the conflict the scope is for.
    testing.expect(t, !gpu.usage_scope_add_texture(&scope, texture, texture.full, gpu.TEXTURE_USES_COLOR_TARGET, &conflict))
    testing.expect(t, conflict.is_texture)
    testing.expect_value(t, conflict.texture, texture.texture)
    testing.expect_value(
        t,
        conflict.current_texture_use,
        gpu.TEXTURE_USES_COPY_SRC | gpu.TEXTURE_USES_RESOURCE,
    )
    testing.expect_value(t, conflict.new_texture_use, gpu.TEXTURE_USES_COLOR_TARGET)

    testing.expect(t, gpu.usage_scope_add_buffer(&scope, 2, buffer, gpu.BUFFER_USES_UNIFORM, &conflict))
    testing.expect(t, !gpu.usage_scope_add_buffer(&scope, 2, buffer, gpu.BUFFER_USES_COPY_DST, &conflict))
    testing.expect(t, !conflict.is_texture)
    testing.expect_value(t, conflict.buffer, buffer)
    testing.expect_value(t, conflict.current_buffer_use, gpu.BUFFER_USES_UNIFORM)
    testing.expect_value(t, conflict.new_buffer_use, gpu.BUFFER_USES_COPY_DST)
}

@(test)
test_usage_scope_merges_a_bind_group :: proc(t: ^testing.T) {
    group: gpu.Bind_Group_States
    gpu.bind_group_states_init(&group, context.allocator)
    defer gpu.bind_group_states_free(&group)

    buffer := test_buffer(4)
    gpu.buffer_bind_group_state_insert_single(&group.buffers, 4, buffer, gpu.BUFFER_USES_UNIFORM)
    texture := test_tracked_texture(3, 1, 1)
    gpu.texture_view_bind_group_state_insert_single(
        &group.views,
        test_texture_view(9),
        texture,
        texture.full,
        gpu.TEXTURE_USES_RESOURCE,
    )
    gpu.bind_group_states_optimize(&group)

    scope: gpu.Usage_Scope
    gpu.usage_scope_init(&scope, context.allocator)
    defer gpu.usage_scope_free(&scope)
    conflict: gpu.Usage_Conflict
    testing.expect(t, gpu.usage_scope_merge_bind_group(&scope, &group, &conflict))
    testing.expect(t, gpu.resource_metadata_contains(&scope.buffers.metadata, 4))
    testing.expect_value(t, scope.buffers.state[4], gpu.BUFFER_USES_UNIFORM)
    testing.expect(t, gpu.resource_metadata_contains(&scope.textures.metadata, 3))
    testing.expect_value(t, scope.textures.set.simple[3], gpu.TEXTURE_USES_RESOURCE)

    // A second merge is a union, not a duplicate.
    testing.expect(t, gpu.usage_scope_merge_bind_group(&scope, &group, &conflict))
    testing.expect_value(t, gpu.resource_metadata_count(&scope.textures.metadata), 1)
}

@(test)
test_usage_scope_pool_reuses_and_clears :: proc(t: ^testing.T) {
    pool: gpu.Usage_Scope_Pool
    gpu.usage_scope_pool_init(&pool, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.usage_scope_pool_free(&pool)

    first := gpu.usage_scope_pool_acquire(&pool)
    conflict: gpu.Usage_Conflict
    buffer := test_buffer(7)
    testing.expect(t, gpu.usage_scope_add_buffer(first, 7, buffer, gpu.BUFFER_USES_UNIFORM, &conflict))
    testing.expect_value(t, gpu.resource_metadata_count(&first.buffers.metadata), 1)

    gpu.usage_scope_pool_release(&pool, first)
    second := gpu.usage_scope_pool_acquire(&pool)
    // The same scope comes back, cleared but still carrying the policy.
    testing.expect(t, second == first)
    testing.expect_value(t, gpu.resource_metadata_count(&second.buffers.metadata), 0)
    testing.expect_value(t, second.buffers.ordered, gpu.BUFFER_USES_ORDERED)
    gpu.usage_scope_pool_release(&pool, second)
}

@(test)
test_tracker_adopts_a_scope :: proc(t: ^testing.T) {
    scope: gpu.Usage_Scope
    gpu.usage_scope_init(&scope, context.allocator)
    defer gpu.usage_scope_free(&scope)
    conflict: gpu.Usage_Conflict
    texture := test_tracked_texture(1, 1, 1)
    testing.expect(t, gpu.usage_scope_add_texture(&scope, texture, texture.full, gpu.TEXTURE_USES_COPY_DST, &conflict))
    buffer := test_buffer(2)
    testing.expect(t, gpu.usage_scope_add_buffer(&scope, 2, buffer, gpu.BUFFER_USES_COPY_SRC, &conflict))

    tracker: gpu.Tracker
    gpu.tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&tracker)

    gpu.tracker_set_from_usage_scope(&tracker, &scope)
    testing.expect(t, gpu.texture_tracker_contains(&tracker.textures, 1))
    testing.expect_value(t, tracker.textures.start.simple[1], gpu.TEXTURE_USES_COPY_DST)
    testing.expect_value(t, tracker.textures.end.simple[1], gpu.TEXTURE_USES_COPY_DST)
    testing.expect(t, gpu.buffer_tracker_contains(&tracker.buffers, 2))
    // A transcript's first touch never owes itself a barrier.
    testing.expect_value(t, len(tracker.textures.temp), 0)
    testing.expect_value(t, len(tracker.buffers.temp), 0)
}

@(test)
test_device_tracker_applies_a_submission :: proc(t: ^testing.T) {
    device: gpu.Device_Tracker
    gpu.device_tracker_init(&device, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.device_tracker_free(&device)

    texture := test_tracked_texture(1, 1, 1)

    first: gpu.Tracker
    gpu.tracker_init(&first, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&first)
    gpu.texture_tracker_set_single(&first.textures, texture, texture.full, gpu.TEXTURE_USES_COPY_DST)
    gpu.texture_tracker_set_single(&first.textures, texture, texture.full, gpu.TEXTURE_USES_RESOURCE)

    second: gpu.Tracker
    gpu.tracker_init(&second, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&second)
    gpu.texture_tracker_set_single(&second.textures, texture, texture.full, gpu.TEXTURE_USES_PRESENT)

    trackers := []^gpu.Tracker{&first, &second}
    texture_transitions_0: [dynamic]gpu.Texture_State_Transition
    texture_transitions_1: [dynamic]gpu.Texture_State_Transition
    buffer_transitions_0: [dynamic]gpu.Buffer_State_Transition
    buffer_transitions_1: [dynamic]gpu.Buffer_State_Transition
    defer {
        delete(texture_transitions_0)
        delete(texture_transitions_1)
        delete(buffer_transitions_0)
        delete(buffer_transitions_1)
    }
    texture_transitions := []^[dynamic]gpu.Texture_State_Transition{&texture_transitions_0, &texture_transitions_1}
    buffer_transitions := []^[dynamic]gpu.Buffer_State_Transition{&buffer_transitions_0, &buffer_transitions_1}

    gpu.device_tracker_track_submission(&device, trackers, texture_transitions, buffer_transitions)

    // The first command buffer's entry state is where the device starts, so its
    // pre-barrier is the one that takes the image out of its undefined state.
    testing.expect_value(t, len(texture_transitions_0), 1)
    testing.expect_value(t, texture_transitions_0[0].from, gpu.TEXTURE_USES_UNINITIALIZED)
    testing.expect_value(t, texture_transitions_0[0].to, gpu.TEXTURE_USES_COPY_DST)
    // The second one starts where the first ended, and only PRESENT differs.
    testing.expect_value(t, len(texture_transitions_1), 1)
    testing.expect_value(t, texture_transitions_1[0].from, gpu.TEXTURE_USES_RESOURCE)
    testing.expect_value(t, texture_transitions_1[0].to, gpu.TEXTURE_USES_PRESENT)
    // The device ends in the last submission's end state.
    testing.expect_value(
        t,
        gpu.device_texture_tracker_state_at(&device.textures, texture.index, texture.texture),
        gpu.TEXTURE_USES_PRESENT,
    )
}

@(test)
test_tracker_records_stateless_resources :: proc(t: ^testing.T) {
    tracker: gpu.Tracker
    gpu.tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&tracker)

    query_set := test_query_set(3)
    testing.expect_value(t, gpu.query_set_tracker_insert_single(&tracker.query_sets, 3, query_set), query_set)
    testing.expect(t, gpu.query_set_tracker_contains(&tracker.query_sets, 3))
    testing.expect_value(t, gpu.query_set_tracker_count(&tracker.query_sets), 1)
    testing.expect_value(t, tracker.query_sets.size, 4)

    blas := test_blas(5)
    testing.expect_value(t, gpu.blas_tracker_insert_single(&tracker.blas_s, 5, blas), blas)
    testing.expect(t, gpu.blas_tracker_contains(&tracker.blas_s, 5))

    bind_group := test_bind_group(1)
    handed_back, inserted := gpu.stateless_tracker_insert_single(
        &tracker.bind_groups, bind_group)
    testing.expect_value(t, handed_back, bind_group)
    testing.expect(t, inserted)
    testing.expect(t, gpu.stateless_tracker_contains(&tracker.bind_groups, bind_group))
    testing.expect_value(t, gpu.stateless_tracker_len(&tracker.bind_groups), 1)

    // The tracker is a set, not a command log: rebinding the same handle must not
    // grow the list. This is what a compute pass does once per dispatch, and an
    // append-per-bind list is what overran the reclaim batch cap.
    other := test_bind_group(2)
    for _ in 0 ..< 64 {
        _, reinserted := gpu.stateless_tracker_insert_single(&tracker.bind_groups, bind_group)
        testing.expect(t, !reinserted)
    }
    testing.expect_value(t, gpu.stateless_tracker_len(&tracker.bind_groups), 1)

    // A different handle is still recorded, and insertion order is preserved.
    _, other_inserted := gpu.stateless_tracker_insert_single(&tracker.bind_groups, other)
    testing.expect(t, other_inserted)
    testing.expect_value(t, gpu.stateless_tracker_len(&tracker.bind_groups), 2)
    testing.expect_value(t, tracker.bind_groups.resources[0], bind_group)
    testing.expect_value(t, tracker.bind_groups.resources[1], other)

    gpu.tracker_clear(&tracker)
    testing.expect(t, !gpu.stateless_tracker_contains(&tracker.bind_groups, bind_group))
    testing.expect(t, !gpu.stateless_tracker_contains(&tracker.bind_groups, other))
    testing.expect_value(t, gpu.query_set_tracker_count(&tracker.query_sets), 0)
    testing.expect(t, !gpu.blas_tracker_contains(&tracker.blas_s, 5))
    testing.expect_value(t, gpu.stateless_tracker_len(&tracker.bind_groups), 0)
}

// The query-write transcript: a slot is recorded once, an unwritten slot and an
// unwritten set answer false, a range is "all written" only when every slot in it
// was recorded, and a cleared transcript remembers nothing.
@(test)
test_tracker_records_query_writes :: proc(t: ^testing.T) {
    tracker: gpu.Tracker
    gpu.tracker_init(&tracker, context.allocator, gpu.BUFFER_USES_ORDERED, gpu.TEXTURE_USES_ORDERED)
    defer gpu.tracker_free(&tracker)

    first := test_query_set(1)
    second := test_query_set(2)
    testing.expect(t, !gpu.tracker_query_written(&tracker, first, 0))
    gpu.tracker_record_query_write(&tracker, first, 0)
    gpu.tracker_record_query_write(&tracker, first, 0)
    gpu.tracker_record_query_write(&tracker, first, 2)
    testing.expect_value(t, len(tracker.query_set_writes), 2)
    testing.expect(t, gpu.tracker_query_written(&tracker, first, 0))
    testing.expect(t, !gpu.tracker_query_written(&tracker, first, 1))
    testing.expect(t, !gpu.tracker_query_written(&tracker, second, 0))

    testing.expect(t, !gpu.tracker_query_range_written(&tracker, first, 0, 2))
    testing.expect(t, gpu.tracker_query_range_written(&tracker, first, 0, 1))
    testing.expect(t, gpu.tracker_query_range_written(&tracker, first, 2, 3))
    // An empty range is written by definition.
    testing.expect(t, gpu.tracker_query_range_written(&tracker, first, 3, 3))

    gpu.tracker_clear(&tracker)
    testing.expect(t, !gpu.tracker_query_written(&tracker, first, 0))
    testing.expect_value(t, len(tracker.query_set_writes), 0)
}
