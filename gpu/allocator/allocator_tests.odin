#+build !js
package gpu_allocator

import "base:intrinsics"
import "core:mem"
import "core:testing"
import "core:thread"
import vk "vendor:vulkan"

CONCURRENT_MEMORY_TYPE_THREADS :: 8
CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD :: 64

Concurrent_Memory_Type_Job :: struct {
    memory_type:     ^VK_Memory_Type,
    allocations:     ^[CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD]VK_Allocation,
    allocated_count: int,
    failures:        ^int,
    desc:            VK_Allocation_Create_Desc,
    allocation_sizes: Allocation_Sizes,
}

concurrent_memory_type_allocate_worker :: proc(raw: rawptr) {
    job := cast(^Concurrent_Memory_Type_Job)raw
    for i in 0 ..< CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD {
        allocation: VK_Allocation
        err := vk_memory_type_allocate(
            job.memory_type,
            nil,
            {},
            job.desc,
            1,
            job.allocation_sizes,
            &allocation)
        if err != .None {
            intrinsics.atomic_add(job.failures, 1)
            break
        }
        job.allocations[i] = allocation
        job.allocated_count += 1
    }
}

concurrent_memory_type_free_worker :: proc(raw: rawptr) {
    job := cast(^Concurrent_Memory_Type_Job)raw
    for i in 0 ..< job.allocated_count {
        if err := vk_memory_type_free(
            job.memory_type, &job.allocations[i], nil, {}); err != .None {
            intrinsics.atomic_add(job.failures, 1)
        }
    }
}

@(test)
test_align_up :: proc(t: ^testing.T) {
    testing.expect_value(t, align_up(0, 16), 0)
    testing.expect_value(t, align_up(1, 16), 16)
    testing.expect_value(t, align_up(16, 16), 16)
    testing.expect_value(t, align_up(17, 16), 32)
    testing.expect_value(t, align_up(100, 64), 128)
}

@(test)
test_align_down :: proc(t: ^testing.T) {
    testing.expect_value(t, align_down(0, 16), 0)
    testing.expect_value(t, align_down(15, 16), 0)
    testing.expect_value(t, align_down(16, 16), 16)
    testing.expect_value(t, align_down(31, 16), 16)
}

@(private = "file")
expect_no_leaks :: proc(t: ^testing.T, track: ^mem.Tracking_Allocator, loc := #caller_location) {
    if len(track.allocation_map) > 0 {
        for _, entry in track.allocation_map {
            testing.expectf(
                t,
                false,
                "leaked %d bytes, allocated at %v",
                entry.size,
                entry.location,
                loc = loc,
            )
        }
    }
    if len(track.bad_free_array) > 0 {
        for entry in track.bad_free_array {
            testing.expectf(t, false, "bad free at %v", entry.location, loc = loc)
        }
    }
}

@(test)
test_allocation_sizes_defaults :: proc(t: ^testing.T) {
    sizes := DEFAULT_ALLOCATION_SIZES
    testing.expect_value(t, sizes.min_device_memblock_size, 256 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.max_device_memblock_size, 256 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.min_host_memblock_size, 64 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.max_host_memblock_size, 64 * MEMBLOCK_MB)
}

@(test)
test_allocation_sizes_clamp_low :: proc(t: ^testing.T) {
    // below the 4MB floor gets clamped up to it
    sizes := allocation_sizes_new(1 * MEMBLOCK_MB, 1 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.min_device_memblock_size, 4 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.min_host_memblock_size, 4 * MEMBLOCK_MB)
}

@(test)
test_allocation_sizes_clamp_high :: proc(t: ^testing.T) {
    // above the 256MB ceiling gets clamped down to it
    sizes := allocation_sizes_new(1024 * MEMBLOCK_MB, 1024 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.min_device_memblock_size, 256 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.min_host_memblock_size, 256 * MEMBLOCK_MB)
}

@(test)
test_allocation_sizes_rounds_to_4mb_multiple :: proc(t: ^testing.T) {
    sizes := allocation_sizes_new(10 * MEMBLOCK_MB, 10 * MEMBLOCK_MB) // not a multiple of 4MB
    testing.expect_value(t, sizes.min_device_memblock_size, 12 * MEMBLOCK_MB)
}

@(test)
test_allocation_sizes_max_respects_min_floor :: proc(t: ^testing.T) {
    sizes := allocation_sizes_new(64 * MEMBLOCK_MB, 64 * MEMBLOCK_MB)
    // asking for a max lower than the min should still clamp up to the min, not down
    sizes = allocation_sizes_with_max_device_memblock_size(sizes, 8 * MEMBLOCK_MB)
    testing.expect_value(t, sizes.max_device_memblock_size, 64 * MEMBLOCK_MB)
}

@(test)
test_allocation_sizes_memblock_growth :: proc(t: ^testing.T) {
    sizes := allocation_sizes_new(8 * MEMBLOCK_MB, 8 * MEMBLOCK_MB)
    sizes = allocation_sizes_with_max_device_memblock_size(sizes, 256 * MEMBLOCK_MB)

    // doubles each time up to the max, then stays capped
    testing.expect_value(
        t,
        allocation_sizes_get_memblock_size(sizes, false, 0),
        8 * MEMBLOCK_MB,
    )
    testing.expect_value(
        t,
        allocation_sizes_get_memblock_size(sizes, false, 1),
        16 * MEMBLOCK_MB,
    )
    testing.expect_value(
        t,
        allocation_sizes_get_memblock_size(sizes, false, 2),
        32 * MEMBLOCK_MB,
    )
    testing.expect_value(
        t,
        allocation_sizes_get_memblock_size(sizes, false, 5),
        256 * MEMBLOCK_MB,
    )
    // stays capped
    testing.expect_value(
        t,
        allocation_sizes_get_memblock_size(sizes, false, 100),
        256 * MEMBLOCK_MB,
    )
}

@(test)
test_has_granularity_conflict :: proc(t: ^testing.T) {
    testing.expect(t, !has_granularity_conflict(.Free, .Linear), "Free never conflicts")
    testing.expect(
        t,
        !has_granularity_conflict(.Linear, .Free),
        "Free never conflicts (order swapped)",
    )
    testing.expect(
        t,
        !has_granularity_conflict(.Linear, .Linear),
        "same type never conflicts",
    )
    testing.expect(
        t,
        !has_granularity_conflict(.Non_Linear, .Non_Linear),
        "same type never conflicts",
    )
    testing.expect(
        t,
        has_granularity_conflict(.Linear, .Non_Linear),
        "different resource types conflict",
    )
    testing.expect(
        t,
        has_granularity_conflict(.Non_Linear, .Linear),
        "different resource types conflict (order swapped)",
    )
}

@(test)
test_is_on_same_page :: proc(t: ^testing.T) {
    // page size 256: [0, 100) ends at byte 99, on page 0 (0..255)
    testing.expect(t, is_on_same_page(0, 100, 200, 256), "200 is still within page 0")
    testing.expect(t, !is_on_same_page(0, 100, 300, 256), "300 is on page 1")
    testing.expect(t, is_on_same_page(0, 100, 255, 256), "255 is the last byte of page 0")
    testing.expect(t, !is_on_same_page(0, 100, 256, 256), "256 is the first byte of page 1")
}

@(test)
test_free_list_init_state :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    testing.expect_value(t, fl.size, 1024)
    testing.expect_value(t, fl.allocated, 0)
    testing.expect_value(t, len(fl.chunks), 1)
    testing.expect_value(t, len(fl.free_chunks), 1)
}

@(test)
test_free_list_simple_allocate :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    offset, id, err := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, offset, 0)
    testing.expect(t, id != 0, "chunk id should be non-zero")
    testing.expect_value(t, fl.allocated, 100)
}

@(test)
test_free_list_out_of_memory :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 100, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, _, err := free_list_allocator_allocate(&fl, 200, 1, .Linear, 1, "too_big")
    testing.expect_value(t, err, Allocator_Error.Out_Of_Memory)
    // failed allocation must not have side effects
    testing.expect_value(t, fl.allocated, 0)

    // the block should still be fully usable afterwards
    _, _, err2 := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "fits")
    testing.expect_value(t, err2, Allocator_Error.None)
}

@(test)
test_free_list_sequential_offsets :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    off_a, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    off_b, id_b, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "b")
    off_c, id_c, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "c")

    testing.expect_value(t, off_a, 0)
    testing.expect_value(t, off_b, 100)
    testing.expect_value(t, off_c, 200)
    testing.expect(t, id_a != id_b && id_b != id_c && id_a != id_c, "chunk ids must be distinct")
    testing.expect_value(t, fl.allocated, 300)
}

@(test)
test_free_list_alignment_padding :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    // first alloc is already aligned, consumes exactly [0, 10)
    off_a, _, _ := free_list_allocator_allocate(&fl, 10, 64, .Linear, 1, "a")
    testing.expect_value(t, off_a, 0)

    // second alloc needs 64-alignment: padding (54 bytes) must be absorbed
    // into the new chunk rather than returned as a usable offset
    off_b, _, err := free_list_allocator_allocate(&fl, 10, 64, .Linear, 1, "b")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, off_b, 64)
}

@(test)
test_free_list_perfect_fit_reuses_chunk :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 200, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    // first allocation splits the block
    _, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    // second allocation exactly fills what's left (padding=0,
    // aligned_size==chunk.size) -> should hit the "reuse in place" branch, not
    // the split branch.
    before := len(fl.chunks)
    off_b, id_b, err := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "b")
    after := len(fl.chunks)

    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, off_b, 100)
    testing.expect_value(t, after, before) // no new chunk record created
    testing.expect(t, id_a != id_b, "still a distinct allocation from `a`")
    testing.expect_value(t, len(fl.free_chunks), 0) // block is now fully used
}

@(test)
test_free_list_granularity_conflict_bumps_offset :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    GRANULARITY :: 256

    // a Linear allocation occupying [0, 100)
    off_a, _, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, GRANULARITY, "linear")
    testing.expect_value(t, off_a, 0)

    // a Non_Linear allocation right after it would alias page 0 with the Linear
    // one -> must be pushed to the next GRANULARITY boundary (256), not packed
    // at offset 100.
    off_b, _, err := free_list_allocator_allocate(
        &fl,
        50,
        1,
        .Non_Linear,
        GRANULARITY,
        "non_linear",
    )
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, off_b, 256)
}

@(test)
test_free_list_granularity_no_conflict_same_type :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    GRANULARITY :: 256

    _, _, _ = free_list_allocator_allocate(&fl, 100, 1, .Linear, GRANULARITY, "linear_1")
    // same resource type right after -> no bump needed, packs tightly at 100
    off_b, _, err := free_list_allocator_allocate(
        &fl,
        50,
        1,
        .Linear,
        GRANULARITY,
        "linear_2",
    )
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, off_b, 100)
}

@(test)
test_free_list_free_and_reallocate :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    testing.expect_value(t, fl.allocated, 100)

    err := free_list_allocator_free(&fl, id_a)
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, fl.allocated, 0)

    // space should be fully reusable
    off, _, err2 := free_list_allocator_allocate(&fl, 1024, 1, .Linear, 1, "full")
    testing.expect_value(t, err2, Allocator_Error.None)
    testing.expect_value(t, off, 0)
}

@(test)
test_free_list_free_invalid_id :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    err := free_list_allocator_free(&fl, 0)
    testing.expect_value(t, err, Allocator_Error.Internal)

    err2 := free_list_allocator_free(&fl, 12345) // never handed out
    testing.expect_value(t, err2, Allocator_Error.Internal)
}

@(test)
test_free_list_coalescing_recovers_full_block :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 300, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a") // [0,100)
    _, id_b, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "b") // [100,200)
    _, id_c, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "c") // [200,300), perfect fit

    testing.expect_value(t, fl.allocated, 300)

    // free the middle chunk first: neither neighbor is free yet, so no merge
    testing.expect_value(t, free_list_allocator_free(&fl, id_b), Allocator_Error.None)
    testing.expect_value(t, len(fl.free_chunks), 1)

    // free `a`: merges forward with the now-free `b`
    testing.expect_value(t, free_list_allocator_free(&fl, id_a), Allocator_Error.None)
    testing.expect_value(t, len(fl.free_chunks), 1)

    // free `c`: merges backward into the combined a+b chunk
    testing.expect_value(t, free_list_allocator_free(&fl, id_c), Allocator_Error.None)
    testing.expect_value(t, len(fl.free_chunks), 1)
    testing.expect_value(t, fl.allocated, 0)

    // proof the whole block is one contiguous free span again: a full-size
    // allocation must succeed at offset 0.
    off, _, err := free_list_allocator_allocate(&fl, 300, 1, .Linear, 1, "whole")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, off, 0)
}

@(test)
test_free_list_rename :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, id, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "original")
    err := free_list_allocator_rename(&fl, id, "renamed")
    testing.expect_value(t, err, Allocator_Error.None)

    reports := free_list_allocator_report_allocations(&fl, context.temp_allocator)
    testing.expect_value(t, len(reports), 1)
    testing.expect_value(t, str_from_array(reports[0].name[:]), "renamed")
}

@(test)
test_free_list_rename_freed_chunk_fails :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, id, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    free_list_allocator_free(&fl, id)

    err := free_list_allocator_rename(&fl, id, "too_late")
    testing.expect_value(t, err, Allocator_Error.Internal)
}

@(test)
test_free_list_unnamed_report_fallback :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "")

    reports := free_list_allocator_report_allocations(&fl, context.temp_allocator)
    testing.expect_value(t, len(reports), 1)
    testing.expect_value(
        t,
        str_from_array(reports[0].name[:]),
        "<Unnamed FreeList allocation>",
    )
}

@(test)
test_free_list_report_excludes_free_chunks :: proc(t: ^testing.T) {
    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.temp_allocator)
    defer free_list_allocator_uninit(&fl)

    _, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "b")
    free_list_allocator_free(&fl, id_a)

    reports := free_list_allocator_report_allocations(&fl, context.temp_allocator)
    testing.expect_value(t, len(reports), 1) // only `b` is still live
    testing.expect_value(t, str_from_array(reports[0].name[:]), "b")
}

@(test)
test_free_list_no_leaks :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)
    context.allocator = mem.tracking_allocator(&track)

    fl: Free_List_Allocator
    free_list_allocator_init(&fl, 1024, context.allocator)

    _, id_a, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "a")
    _, id_b, _ := free_list_allocator_allocate(&fl, 100, 1, .Linear, 1, "b")
    free_list_allocator_rename(&fl, id_a, "a_renamed")
    free_list_allocator_free(&fl, id_a)
    _, id_c, _ := free_list_allocator_allocate(&fl, 50, 1, .Non_Linear, 256, "c")

    reports := free_list_allocator_report_allocations(&fl, context.allocator)
    delete(reports)

    free_list_allocator_free(&fl, id_b)
    free_list_allocator_free(&fl, id_c)
    free_list_allocator_uninit(&fl)

    expect_no_leaks(t, &track)
}

@(test)
test_dedicated_allocate_and_free :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 4096, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    offset, id, err := dedicated_block_allocator_allocate(
        &db,
        4096,
        1,
        .Linear,
        1,
        "dedicated",
    )
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, offset, 0)
    testing.expect_value(t, id, 1)
    testing.expect_value(t, db.allocated, 4096)

    err2 := dedicated_block_allocator_free(&db, 1)
    testing.expect_value(t, err2, Allocator_Error.None)
    testing.expect_value(t, db.allocated, 0)
}

@(test)
test_dedicated_size_mismatch_fails :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 4096, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    _, _, err := dedicated_block_allocator_allocate(&db, 2048, 1, .Linear, 1, "wrong_size")
    testing.expect_value(t, err, Allocator_Error.Internal)
    testing.expect_value(t, db.allocated, 0) // must not have partially succeeded
}

@(test)
test_dedicated_double_allocate_fails :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 1024, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    dedicated_block_allocator_allocate(&db, 1024, 1, .Linear, 1, "first")
    _, _, err := dedicated_block_allocator_allocate(&db, 1024, 1, .Linear, 1, "second")
    testing.expect_value(t, err, Allocator_Error.Out_Of_Memory)
}

@(test)
test_dedicated_free_wrong_id_fails :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 1024, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    dedicated_block_allocator_allocate(&db, 1024, 1, .Linear, 1, "a")
    err := dedicated_block_allocator_free(&db, 999)
    testing.expect_value(t, err, Allocator_Error.Internal)
    testing.expect_value(t, db.allocated, 1024) // rejected free must not mutate state
}

@(test)
test_dedicated_rename :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 1024, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    dedicated_block_allocator_allocate(&db, 1024, 1, .Linear, 1, "original")
    err := dedicated_block_allocator_rename(&db, 1, "renamed")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, str_from_array(db.name[:]), "renamed")

    err2 := dedicated_block_allocator_rename(&db, 999, "nope")
    testing.expect_value(t, err2, Allocator_Error.Internal)
}

@(test)
test_dedicated_report_allocations :: proc(t: ^testing.T) {
    db: Dedicated_Block_Allocator
    dedicated_block_allocator_init(&db, 2048, context.temp_allocator)
    defer dedicated_block_allocator_uninit(&db)

    empty_reports := dedicated_block_allocator_report_allocations(&db, context.temp_allocator)
    testing.expect_value(t, len(empty_reports), 0)

    dedicated_block_allocator_allocate(&db, 2048, 1, .Linear, 1, "")
    reports := dedicated_block_allocator_report_allocations(&db, context.temp_allocator)
    testing.expect_value(t, len(reports), 1)
    testing.expect_value(t, reports[0].size, 2048)
    testing.expect_value(
        t,
        str_from_array(reports[0].name[:]),
        "<Unnamed Dedicated allocation>",
    )
}

@(test)
test_sub_allocator_dispatches_free_list :: proc(t: ^testing.T) {
    sa: Sub_Allocator = Free_List_Allocator{}
    free_list_allocator_init(&sa.(Free_List_Allocator), 1024, context.temp_allocator)
    defer sub_allocator_destroy(&sa)

    testing.expect(
        t,
        sub_allocator_supports_general_allocations(&sa),
        "free list supports general allocations",
    )
    testing.expect(t, sub_allocator_is_empty(&sa), "starts empty")

    _, id, err := sub_allocator_allocate(&sa, 100, 1, .Linear, 1, "a")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect(t, !sub_allocator_is_empty(&sa), "no longer empty after allocating")

    rename_err := sub_allocator_rename_allocation(&sa, id, "renamed")
    testing.expect_value(t, rename_err, Allocator_Error.None)

    reports := sub_allocator_report_allocations(&sa, context.temp_allocator)
    testing.expect_value(t, len(reports), 1)
    testing.expect_value(t, str_from_array(reports[0].name[:]), "renamed")

    free_err := sub_allocator_free(&sa, id)
    testing.expect_value(t, free_err, Allocator_Error.None)
    testing.expect(t, sub_allocator_is_empty(&sa), "empty again after freeing")
}

@(test)
test_sub_allocator_dispatches_dedicated :: proc(t: ^testing.T) {
    sa: Sub_Allocator = Dedicated_Block_Allocator{}
    dedicated_block_allocator_init(
        &sa.(Dedicated_Block_Allocator),
        512,
        context.temp_allocator,
    )
    defer sub_allocator_destroy(&sa)

    testing.expect(
        t,
        !sub_allocator_supports_general_allocations(&sa),
        "dedicated does not support general allocations",
    )

    offset, id, err := sub_allocator_allocate(&sa, 512, 1, .Linear, 1, "dedicated")
    testing.expect_value(t, err, Allocator_Error.None)
    testing.expect_value(t, offset, 0)

    free_err := sub_allocator_free(&sa, id)
    testing.expect_value(t, free_err, Allocator_Error.None)
    testing.expect(t, sub_allocator_is_empty(&sa), "empty again after freeing")
}

@(test)
test_memory_type_concurrent_allocate_and_free :: proc(t: ^testing.T) {
    // Seed a reusable block so this exercises the production memory-type lock
    // and sub-allocator maps without requiring a live Vulkan device or callbacks.
    block_size := u64(4 * MEMBLOCK_MB)
    memory_type := VK_Memory_Type{
        memory_type_index = 0,
        active_general_blocks = 1,
        allocator = context.allocator,
    }
    memory_type.memory_blocks = make([dynamic]Maybe(VK_Memory_Block), context.allocator)

    sub_allocator: Sub_Allocator = Free_List_Allocator{}
    free_list_allocator_init(
        &sub_allocator.(Free_List_Allocator), block_size, context.allocator)
    append(&memory_type.memory_blocks, VK_Memory_Block{
        size = block_size,
        sub_allocator = sub_allocator,
    })

    allocation_sizes := Allocation_Sizes{
        min_device_memblock_size = block_size,
        max_device_memblock_size = block_size,
        min_host_memblock_size = block_size,
        max_host_memblock_size = block_size,
    }
    desc := VK_Allocation_Create_Desc{
        name = "concurrent memory type test",
        requirements = vk.MemoryRequirements{
            size = 128,
            alignment = 16,
            memoryTypeBits = 1,
        },
        location = .Unknown,
        linear = true,
        allocation_scheme = VK_ALLOCATION_SCHEME_MANAGED,
    }

    failures: int
    allocations: [CONCURRENT_MEMORY_TYPE_THREADS][CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD]VK_Allocation
    jobs: [CONCURRENT_MEMORY_TYPE_THREADS]Concurrent_Memory_Type_Job
    threads: [CONCURRENT_MEMORY_TYPE_THREADS]^thread.Thread

    for worker in 0 ..< CONCURRENT_MEMORY_TYPE_THREADS {
        jobs[worker] = Concurrent_Memory_Type_Job{
            memory_type = &memory_type,
            allocations = &allocations[worker],
            failures = &failures,
            desc = desc,
            allocation_sizes = allocation_sizes,
        }
        threads[worker] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[worker]), concurrent_memory_type_allocate_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    total_allocations := 0
    for job in jobs {
        total_allocations += job.allocated_count
        testing.expect_value(t, job.allocated_count, CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD)
    }
    testing.expect_value(t, intrinsics.atomic_load(&failures), 0)

    // Every simultaneously-live allocation must own a disjoint range.
    for a in 0 ..< total_allocations {
        allocation_a := allocations[a / CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD][
            a % CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD]
        testing.expect(t, allocation_a.chunk_id != 0, "allocation should have a chunk id")
        for b in a + 1 ..< total_allocations {
            allocation_b := allocations[b / CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD][
                b % CONCURRENT_MEMORY_TYPE_ALLOCS_PER_THREAD]
            no_overlap := allocation_a.offset + allocation_a.size <= allocation_b.offset ||
                allocation_b.offset + allocation_b.size <= allocation_a.offset
            testing.expect(t, no_overlap, "concurrent allocations must not overlap")
        }
    }

    for worker in 0 ..< CONCURRENT_MEMORY_TYPE_THREADS {
        threads[worker] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[worker]), concurrent_memory_type_free_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect_value(t, intrinsics.atomic_load(&failures), 0)
    testing.expect_value(t, memory_type.active_general_blocks, 1)
    if block, block_exists := &memory_type.memory_blocks[0].?; block_exists {
        free_list := &block.sub_allocator.(Free_List_Allocator)
        testing.expect_value(t, free_list.allocated, 0)
        testing.expect_value(t, len(free_list.chunks), 1)
        testing.expect_value(t, len(free_list.free_chunks), 1)
        sub_allocator_destroy(&block.sub_allocator)
    } else {
        testing.expect(t, false, "seed memory block should remain allocated")
    }
    delete(memory_type.memory_blocks)
}
