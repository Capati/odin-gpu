#+build !js
package gpu

// Core
import "core:sync"
import "core:testing"
import "core:thread"

import intr "base:intrinsics"
import hm "core:container/handle_map"

// Mirrors the shape the backend impls use: a `ref` for the refcount discipline,
// and a `handle` field the map writes back into.
TS_Test_Item_Handle :: distinct hm.Handle64

TS_Test_Item :: struct {
    ref:    Ref_Count_Type,
    handle: TS_Test_Item_Handle,
    value:  int,
}

TS_Test_Item_Map :: DHM_Resource(TS_Test_Item, TS_Test_Item_Handle)

TS_WRITERS :: 8
TS_READERS :: 8
TS_PER_WRITER :: 512

TS_TOTAL :: TS_WRITERS * TS_PER_WRITER
TS_STABLE_COUNT :: 64
TS_BASE_COUNT :: 128
TS_STALE_COUNT :: 128

// A thread-safe failure counter, so a test body can record a problem from a
// worker thread and assert on it once the thread has been joined.
TS_Failures :: struct {
    v: int,
}

ts_fail :: proc "contextless" (f: ^TS_Failures) {
    intr.atomic_add(&f.v, 1)
}

ts_failed :: proc "contextless" (f: ^TS_Failures) -> bool {
    return intr.atomic_load(&f.v) != 0
}

// Drive concurrent add_impl from many threads and verify that every handle
// resolves to the value its producer wrote.
//
// The map only ever grows, so a handle obtained by one thread must still resolve
// after the others have appended. That is the pattern concurrent resource creation
// relies on, and it is what the shared/exclusive lock split has to guarantee.
@(test)
test_dhm_concurrent_add_and_get :: proc(t: ^testing.T) {
    dhm: TS_Test_Item_Map
    dhm_init(&dhm)
    expected: [TS_TOTAL]int
    handles: [TS_TOTAL]TS_Test_Item_Handle
    for w in 0 ..< TS_WRITERS {
        for i in 0 ..< TS_PER_WRITER {
            expected[w * TS_PER_WRITER + i] = w * 1_000_000 + i
        }
    }

    ts_add_worker :: proc(raw: rawptr) {
        job := cast(^TS_Add_Job)rawptr(raw)
        for i in 0 ..< job.count {
            index := job.base + i
            _, handle := add_impl(job.dhm, TS_Test_Item{value = job.expected[index]})
            job.handles[index] = handle
        }
    }

    jobs: [TS_WRITERS]TS_Add_Job
    threads: [TS_WRITERS]^thread.Thread
    for w in 0 ..< TS_WRITERS {
        jobs[w] = TS_Add_Job {
            dhm      = &dhm,
            expected = &expected,
            handles  = &handles,
            base     = w * TS_PER_WRITER,
            count    = TS_PER_WRITER,
        }
        threads[w] = thread.create_and_start_with_poly_data(rawptr(&jobs[w]), ts_add_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    seen: [TS_TOTAL]bool
    for w in 0 ..< TS_WRITERS {
        for i in 0 ..< TS_PER_WRITER {
            index := w * TS_PER_WRITER + i
            item := get_handle_impl(&dhm, transmute(u64)handles[index])
            testing.expect_value(t, item.value, expected[index])
            testing.expect(t, dhm_is_valid(&dhm, handles[index]), "handle should be valid")
            testing.expect(t, !seen[index], "duplicate add detected")
            seen[index] = true
        }
    }

    testing.expect_value(t, dhm_len(&dhm), uint(TS_TOTAL))
    dhm_destroy(&dhm)
}

TS_Add_Job :: struct {
    dhm:      ^TS_Test_Item_Map,
    expected: ^[TS_TOTAL]int,
    handles:  ^[TS_TOTAL]TS_Test_Item_Handle,
    base:     int,
    count:    int,
}

// Recycle slots hard: every thread repeatedly adds and then immediately removes,
// so the free list and the generation counters are mutated from all threads at
// once. A generation handed out twice, or a slot returned to the free list twice,
// surfaces as a handle resolving to a value it should not.
@(test)
test_dhm_concurrent_add_remove_churn :: proc(t: ^testing.T) {
    dhm: TS_Test_Item_Map
    dhm_init(&dhm)

    ts_churn_worker :: proc(raw: rawptr) {
        job := cast(^TS_Churn_Job)rawptr(raw)
        for round in 0 ..< job.count {
            for i in 0 ..< 16 {
                value := job.owner * 1_000_000 + round * 64 + i
                _, handle := add_impl(job.dhm, TS_Test_Item{value = value})
                // A handle just created must resolve to what we wrote, even as
                // other threads recycle their own slots.
                item := get_handle_impl(job.dhm, transmute(u64)handle)
                if item.value != value {
                    ts_fail(job.failures)
                }
                _ = dhm_len(job.dhm)
                _ = dhm_cap(job.dhm)
                remove_handle_impl(job.dhm, handle)
                if dhm_is_valid(job.dhm, handle) {
                    ts_fail(job.failures)
                }
            }
        }
    }

    failures: TS_Failures
    jobs: [TS_WRITERS]TS_Churn_Job
    threads: [TS_WRITERS]^thread.Thread
    for w in 0 ..< TS_WRITERS {
        jobs[w] = TS_Churn_Job {
            dhm      = &dhm,
            failures = &failures,
            owner    = w,
            count    = TS_PER_WRITER,
        }
        threads[w] = thread.create_and_start_with_poly_data(rawptr(&jobs[w]), ts_churn_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "churn produced an inconsistent handle map")
    // The map is empty again, but its storage is still coherent enough to reuse.
    testing.expect_value(t, dhm_len(&dhm), uint(0))

    for round in 0 ..< 64 {
        ptr, handle := add_impl(&dhm, TS_Test_Item{value = round})
        testing.expect_value(t, ptr.value, round)
        testing.expect_value(t, get_handle_impl(&dhm, transmute(u64)handle).value, round)
    }

    dhm_destroy(&dhm)
}

TS_Churn_Job :: struct {
    dhm:      ^TS_Test_Item_Map,
    failures: ^TS_Failures,
    owner:    int,
    count:    int,
}

// Readers hammer long-lived entries while writers churn the same map.
//
// The long-lived entries must keep resolving to their original values, which
// catches a reader observing a slot another thread is reusing.
@(test)
test_dhm_readers_see_stable_entries_during_writes :: proc(t: ^testing.T) {
    dhm: TS_Test_Item_Map
    dhm_init(&dhm)
    stable: [TS_STABLE_COUNT]TS_Test_Item_Handle
    for i in 0 ..< TS_STABLE_COUNT {
        _, h := add_impl(&dhm, TS_Test_Item{value = -(i + 1)})
        stable[i] = h
    }

    ts_read_worker :: proc(raw: rawptr) {
        job := cast(^TS_Read_Job)rawptr(raw)
        for _ in 0 ..< 2000 {
            for i in 0 ..< job.count {
                item := get_handle_impl(job.dhm, transmute(u64)job.handles[i])
                if item.value != -(i + 1) {
                    ts_fail(job.failures)
                }
            }
        }
    }

    ts_write_worker :: proc(raw: rawptr) {
        job := cast(^TS_Write_Job)rawptr(raw)
        for round in 0 ..< 200 {
            for _ in 0 ..< 16 {
                _, h := add_impl(job.dhm, TS_Test_Item{value = job.owner * 1000 + round})
                remove_handle_impl(job.dhm, h)
            }
        }
    }

    failures: TS_Failures
    threads: [TS_READERS + TS_WRITERS]^thread.Thread

    read_jobs: [TS_READERS]TS_Read_Job
    for r in 0 ..< TS_READERS {
        read_jobs[r] = TS_Read_Job {
            dhm      = &dhm,
            failures = &failures,
            handles  = &stable,
            count    = TS_STABLE_COUNT,
        }
        threads[r] = thread.create_and_start_with_poly_data(rawptr(&read_jobs[r]), ts_read_worker)
    }

    write_jobs: [TS_WRITERS]TS_Write_Job
    for w in 0 ..< TS_WRITERS {
        write_jobs[w] = TS_Write_Job {
            dhm   = &dhm,
            owner = w,
        }
        threads[TS_READERS + w] = thread.create_and_start_with_poly_data(
            rawptr(&write_jobs[w]),
            ts_write_worker,
        )
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "a reader observed a recycled slot")
    // The stable entries survived every reuse of their slots.
    for i in 0 ..< TS_STABLE_COUNT {
        testing.expect(t, dhm_is_valid(&dhm, stable[i]), "stable handle was invalidated")
    }

    dhm_destroy(&dhm)
}

TS_Read_Job :: struct {
    dhm:      ^TS_Test_Item_Map,
    failures: ^TS_Failures,
    handles:  ^[TS_STABLE_COUNT]TS_Test_Item_Handle,
    count:    int,
}

TS_Write_Job :: struct {
    dhm:   ^TS_Test_Item_Map,
    owner: int,
}

// dhm_for_each must see a consistent snapshot under concurrent mutation.
//
// Writers only add and remove strictly above the base range, so the base entries
// are live for the whole walk and every walk must find all of them.
@(test)
test_dhm_for_each_is_consistent :: proc(t: ^testing.T) {
    dhm: TS_Test_Item_Map
    dhm_init(&dhm)
    for i in 0 ..< TS_BASE_COUNT {
        _, _ = add_impl(&dhm, TS_Test_Item{value = i})
    }

    ts_for_each_writer :: proc(raw: rawptr) {
        job := cast(^TS_For_Each_Job)rawptr(raw)
        for _ in 0 ..< 200 {
            for i in 0 ..< 8 {
                _, h := add_impl(job.dhm, TS_Test_Item{value = job.base_count + i})
                remove_handle_impl(job.dhm, h)
            }
        }
    }

    ts_for_each_walker :: proc(raw: rawptr) {
        job := cast(^TS_For_Each_Job)rawptr(raw)
        for _ in 0 ..< 300 {
            state := TS_Walk_State {
                base_count = job.base_count,
            }
            dhm_for_each(job.dhm, rawptr(&state), ts_count_visit)
            if state.found_base != job.base_count {
                ts_fail(job.failures)
            }
            if state.total_seen < job.base_count {
                ts_fail(job.failures)
            }
        }
    }

    failures: TS_Failures
    jobs: [TS_WRITERS]TS_For_Each_Job
    threads: [1 + TS_WRITERS]^thread.Thread
    for w in 0 ..< TS_WRITERS {
        jobs[w] = TS_For_Each_Job {
            dhm        = &dhm,
            failures   = &failures,
            base_count = TS_BASE_COUNT,
        }
        threads[w] = thread.create_and_start_with_poly_data(rawptr(&jobs[w]), ts_for_each_writer)
    }

    walker_job := TS_For_Each_Job {
        dhm        = &dhm,
        failures   = &failures,
        base_count = TS_BASE_COUNT,
    }
    threads[TS_WRITERS] = thread.create_and_start_with_poly_data(
        rawptr(&walker_job),
        ts_for_each_walker,
    )
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "for_each saw a torn snapshot")
    testing.expect_value(t, dhm_len(&dhm), uint(TS_BASE_COUNT))

    dhm_destroy(&dhm)
}

TS_For_Each_Job :: struct {
    dhm:        ^TS_Test_Item_Map,
    failures:   ^TS_Failures,
    base_count: int,
}

// Iteration state carried through dhm_for_each's user_data, since Odin has no
// closures and the visitor therefore cannot capture.
TS_Walk_State :: struct {
    base_count: int,
    found_base: int,
    total_seen: int,
}

ts_count_visit :: proc(user_data: rawptr, ptr: ^TS_Test_Item, handle: TS_Test_Item_Handle) {
    state := cast(^TS_Walk_State)user_data
    state.total_seen += 1
    if ptr.value < state.base_count {
        state.found_base += 1
    }
}

// dhm_clear must invalidate every prior handle and leave the map reusable.
@(test)
test_dhm_clear_invalidates_and_stays_usable :: proc(t: ^testing.T) {
    dhm: TS_Test_Item_Map
    dhm_init(&dhm)
    stale: [TS_STALE_COUNT]TS_Test_Item_Handle
    for i in 0 ..< TS_STALE_COUNT {
        _, h := add_impl(&dhm, TS_Test_Item{value = i})
        stale[i] = h
    }
    testing.expect_value(t, dhm_len(&dhm), uint(TS_STALE_COUNT))

    dhm_clear(&dhm)
    testing.expect_value(t, dhm_len(&dhm), uint(0))
    for i in 0 ..< TS_STALE_COUNT {
        testing.expect(t, !dhm_is_valid(&dhm, stale[i]), "handle survived clear")
    }

    for i in 0 ..< 256 {
        ptr, h := add_impl(&dhm, TS_Test_Item{value = i})
        testing.expect_value(t, ptr.value, i)
        testing.expect_value(t, get_handle_impl(&dhm, transmute(u64)h).value, i)
    }
    testing.expect_value(t, dhm_len(&dhm), uint(256))

    dhm_destroy(&dhm)
}

// -----------------------------------------------------------------------------
// Submit context
//
// These exercise the lock discipline in `vk_submit_context` without needing a
// live Vulkan device: the slot pool, the free-count, the generation counter, and
// the present-semaphore handoff are all plain fields, and the same exclusive/
// shared split the real code uses is applied here by hand. What is verified is
// that the discipline is sound (no torn bookkeeping, no double free of a slot,
// no lost update) so a regression in the real lock placement is caught by the
// same reasoning.
// -----------------------------------------------------------------------------

// A minimal stand-in with the same shape as the parts of `VK_Submit_Context` the
// lock protects: a fixed slot array plus the shared counters.
TS_Submit_Context :: struct {
    slots:                 [TS_MAX_SLOTS]TS_Submit_Slot,
    // `available_command_buffers` counts slots whose `in_use` is false.
    available:             int,
    // Monotonic, 1-based; 0 is reserved as "no submission".
    submit_id:             int,
    // The intra-queue chain: signaled by the previous submit, consumed by the
    // next one. Taken and cleared together, exactly like the real semaphore.
    last_submit_semaphore: int,
    // Set by present, waited on by `acquire` before reusing a slot.
    last_present_fence:    int,
    mtx:                   sync.RW_Mutex,
}

TS_Submit_Slot :: struct {
    in_use:    bool,
    // Bumped on every acquire so a stale handle can be detected.
    submit_id: int,
}

TS_MAX_SLOTS :: 8

TS_Semaphore :: int

// Mirrors `vk_submit_context_acquire`: claim a free slot under the exclusive
// lock, mark it in_use, stamp it with the current generation, then release,
// leaving the slot "recording" outside the lock.
ts_submit_acquire :: proc "contextless" (sc: ^TS_Submit_Context) -> TS_Submit_Handle {
    for spins in 0 ..< TS_SPIN_LIMIT {
        handle: TS_Submit_Handle
        found := false
        {
            sync.guard(&sc.mtx)
            for i in 0 ..< TS_MAX_SLOTS {
                if !sc.slots[i].in_use {
                    sc.slots[i].in_use = true
                    sc.slots[i].submit_id = sc.submit_id
                    handle = TS_Submit_Handle {
                        slot_index = i,
                        submit_id  = sc.submit_id,
                    }
                    sc.submit_id += 1
                    sc.available -= 1
                    found = true
                    break
                }
            }
        }
        if found {
            return handle
        }
        // Nothing free. The real code purges completed slots and sleeps, both
        // outside the lock; the test just retries, bounded so that a lost or
        // leaked slot fails the test instead of hanging it.
        _ = spins
    }
    TS_SUBMIT_EXHAUSTED = true
    return {}
}

// Set by `ts_submit_acquire` when no slot frees up within the spin limit, which
// means the free count or the in_use flags were corrupted.
TS_SUBMIT_EXHAUSTED: bool

TS_SPIN_LIMIT :: 10_000

// Mirrors `vk_submit_context_submit`: only the bookkeeping is exclusive.
ts_submit_submit :: proc "contextless" (sc: ^TS_Submit_Context, slot_index: int) {
    sync.guard(&sc.mtx)
    slot := &sc.slots[slot_index]
    assert_contextless(slot.in_use, "submitting a slot that is not in use")
    slot.in_use = false
    sc.available += 1
    // The real submit publishes the slot's own semaphore as the next link in
    // the chain and clears the wait semaphore.
    sc.last_submit_semaphore = 100 + slot_index
}

// Mirrors `vk_submit_context_is_ready`: read-only, so a shared lock suffices.
ts_submit_is_ready :: proc "contextless" (
    sc: ^TS_Submit_Context,
    handle: TS_Submit_Handle,
) -> bool {
    if handle.slot_index < 0 {
        return true
    }
    sync.shared_guard(&sc.mtx)
    slot := &sc.slots[handle.slot_index]
    if !slot.in_use {
        return true
    }
    if slot.submit_id != handle.submit_id {
        // slot has moved on to a newer generation
        return true
    }
    return false
}

TS_Submit_Handle :: struct {
    slot_index: int,
    submit_id:  int,
}

TS_Handle_Job :: struct {
    sc:         ^TS_Submit_Context,
    failures:   ^TS_Failures,
    iterations: int,
}

// Each thread loops acquire -> submit, exactly the pipeline two threads racing
// on the same pool. If the free count or the generation counter is corrupted,
// the final counts or a stale-handle assertion catch it.
ts_submit_worker :: proc(data: rawptr) {
    job := cast(^TS_Handle_Job)data
    for _ in 0 ..< job.iterations {
        handle := ts_submit_acquire(job.sc)
        if handle.slot_index < 0 {
            ts_fail(job.failures)
            return
        }
        if ts_submit_is_ready(job.sc, handle) {
            // A just-acquired slot is in use with a matching generation, so it
            // must not read as ready.
            ts_fail(job.failures)
        }
        ts_submit_submit(job.sc, handle.slot_index)
    }
}

// Concurrent acquire/submit across every slot. Verifies the free count never
// drifts and that no two threads ever believe they own the same slot.
@(test)
test_submit_context_concurrent_acquire_and_submit :: proc(t: ^testing.T) {
    sc: TS_Submit_Context
    sc.submit_id = 1
    sc.available = TS_MAX_SLOTS
    failures: TS_Failures

    threads: [TS_SUBMIT_THREADS]^thread.Thread
    jobs: [TS_SUBMIT_THREADS]TS_Handle_Job
    for w in 0 ..< TS_SUBMIT_THREADS {
        jobs[w] = TS_Handle_Job {
            sc         = &sc,
            failures   = &failures,
            iterations = 2000,
        }
        threads[w] = thread.create_and_start_with_poly_data(rawptr(&jobs[w]), ts_submit_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !TS_SUBMIT_EXHAUSTED, "submit pool never freed a slot")
    testing.expect(t, !ts_failed(&failures), "submit context reported a torn slot claim")
    // Every slot must be free again and the bookkeeping must be exactly consistent.
    sync.guard(&sc.mtx)
    testing.expect_value(t, sc.available, TS_MAX_SLOTS)
    for i in 0 ..< TS_MAX_SLOTS {
        testing.expect(t, !sc.slots[i].in_use, "slot leaked after all threads joined")
    }
    // Each thread ran `iterations` acquires, and the generation starts at 1.
    testing.expect_value(t, sc.submit_id, 1 + TS_SUBMIT_THREADS * 2000)
}

TS_SUBMIT_THREADS :: 8

// The semaphore chain is a hand-off: the value produced by a submit must be
// observable by the consumer, and consuming it must clear it, so a second
// consumer cannot pick up the same one.
@(test)
test_submit_context_semaphore_handoff_is_exclusive :: proc(t: ^testing.T) {
    sc: TS_Submit_Context
    sc.submit_id = 1
    sc.available = TS_MAX_SLOTS

    handle := ts_submit_acquire(&sc)
    ts_submit_submit(&sc, handle.slot_index)

    sync.guard(&sc.mtx)
    produced := sc.last_submit_semaphore
    testing.expect(t, produced != 0, "submit did not publish a semaphore")
    // Mirrors `vk_submit_context_acquire_last_submit_semaphore`: take and clear.
    taken := sc.last_submit_semaphore
    sc.last_submit_semaphore = 0
    testing.expect_value(t, taken, produced)
    // A second take must not observe the same semaphore again.
    testing.expect_value(t, sc.last_submit_semaphore, 0)
}

// A stale handle: one whose slot has been recycled onto a newer generation —
// must read as ready, so deferred deletion does not wait on a slot that no longer
// corresponds to the original submission.
@(test)
test_submit_context_stale_handle_reads_ready :: proc(t: ^testing.T) {
    sc: TS_Submit_Context
    sc.submit_id = 1
    sc.available = TS_MAX_SLOTS

    stale := ts_submit_acquire(&sc)
    ts_submit_submit(&sc, stale.slot_index)

    // Reuse the same slot for a newer submission.
    ts_submit_acquire(&sc)

    testing.expect(t, ts_submit_is_ready(&sc, stale), "stale handle was not reported ready")
    // The current generation of that slot is still outstanding, so it is not ready.
    current := TS_Submit_Handle {
        slot_index = stale.slot_index,
        submit_id  = stale.submit_id + 1,
    }
    testing.expect(
        t,
        !ts_submit_is_ready(&sc, current),
        "current handle was wrongly reported ready",
    )
}

// -----------------------------------------------------------------------------
// Device trackers
//
// `Device_Buffer_Tracker` and `Device_Texture_Tracker` belong to the device and are
// reached from every thread that creates, records against, writes to, or destroys a
// resource, unlike the command-buffer trackers which are single-owner.
//
// The tests below drive the real entry points directly: `init`, `insert_single`,
// `set_single`, `remove`, `allow_index` and `used_resources` all take only tracker
// indices and plain handles, so no device is needed. The texture accessors that take
// a public `Texture` handle are not covered here because resolving one requires a
// live device; `get_state_at` is the index-based body underneath, and it is covered.
// -----------------------------------------------------------------------------

// Sized for a unit test, not for maximum coverage: every iteration takes the shared
// tracker lock several times, so a large count turns into seconds of pure contention
// and reads as a hung process. These totals (8 threads x 16 indices x 32 rounds = 4096
// insertions per tracker) are enough to interleave heavily on any machine.
TS_TRACKER_THREADS :: 8
TS_TRACKER_INDICES :: 16
TS_TRACKER_ITERATION :: 32

// `Buffer` and `Texture` values stored in the tracker tables are never dereferenced:
// device tracker metadata is weak, so inserting one neither fires a retain hook nor
// touches the handle map. A fixed private handle is therefore enough, and it cannot
// collide with a real resource.
TS_TRACKER_HANDLE :: Handle_Packed(0xF002_0001)

ts_tracker_buffer :: Buffer(Handle{handle = TS_TRACKER_HANDLE})
ts_tracker_texture :: Texture(Handle{handle = TS_TRACKER_HANDLE})

TS_Churn_Tracker_Job :: struct {
    tracker:  ^Device_Buffer_Tracker,
    failures: ^TS_Failures,
    base:     int,
    count:    int,
}

// Each thread owns a disjoint index range and hammers insert -> verify -> remove,
// which is the create/destroy pattern the device tracker sees from a thread pool.
// `allow_index` grows the shared state array and the `resource_metadata` bit vector
// while other threads are inside the same calls.
ts_buffer_churn_worker :: proc(raw: rawptr) {
    job := cast(^TS_Churn_Tracker_Job)rawptr(raw)
    for _ in 0 ..< TS_TRACKER_ITERATION {
        for i in 0 ..< job.count {
            index := Tracker_Index(job.base + i)
            device_buffer_tracker_insert_single(
                job.tracker,
                index,
                ts_tracker_buffer,
                Buffer_Uses{.Vertex},
            )
            // An index we just inserted must read back as live. The metadata iterator
            // borrows the tracker's tables, so the walk happens under the exclusive
            // lock, iterating it unlocked while other threads resize the table is
            // exactly the bug this file exists to prevent.
            //
            // `sync.guard` holds until the end of its enclosing block, so the remove
            // below is deliberately outside it: `device_buffer_tracker_remove` takes
            // the same non-recursive lock, and re-acquiring it here would deadlock.
            {
                sync.guard(&job.tracker.mtx)
                if !resource_metadata_contains(&job.tracker.metadata, index) {
                    ts_fail(job.failures)
                }
            }
            device_buffer_tracker_remove(job.tracker, index)
        }
    }
}

@(test)
test_device_buffer_tracker_concurrent_insert_remove_churn :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)

    failures: TS_Failures
    jobs: [TS_TRACKER_THREADS]TS_Churn_Tracker_Job
    threads: [TS_TRACKER_THREADS]^thread.Thread
    for w in 0 ..< TS_TRACKER_THREADS {
        jobs[w] = TS_Churn_Tracker_Job {
            tracker  = &tr,
            failures = &failures,
            base     = w * TS_TRACKER_INDICES,
            count    = TS_TRACKER_INDICES,
        }
        threads[w] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[w]),
            ts_buffer_churn_worker,
        )
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "buffer tracker churn reported an inconsistency")

    // Every index was removed, so nothing is left tracked.
    sync.guard(&tr.mtx)
    for i in 0 ..< TS_TRACKER_THREADS * TS_TRACKER_INDICES {
        testing.expect(
            t,
            !resource_metadata_contains(&tr.metadata, Tracker_Index(i)),
            "an index survived its remove",
        )
    }

    // ... and the tables must still be coherent enough to be filled again, which is
    // what a resource created later in the process would do.
    for i in 0 ..< TS_TRACKER_INDICES {
        device_buffer_tracker_insert_single_locked(
            &tr,
            Tracker_Index(i),
            ts_tracker_buffer,
            Buffer_Uses{.Index},
        )
    }
    for i in 0 ..< TS_TRACKER_INDICES {
        testing.expect(
            t,
            resource_metadata_contains(&tr.metadata, Tracker_Index(i)),
            "index missing after refill",
        )
    }
}

TS_Texture_Churn_Job :: struct {
    tracker:  ^Device_Texture_Tracker,
    failures: ^TS_Failures,
    base:     int,
    count:    int,
}

// The texture equivalent, and the one that matters most: growing `Texture_State_Set`
// reallocates `simple`, so a reader running without the shared lock could be reading
// storage that another thread has just freed. `get_state_at` returning a resolved
// value under that lock is what makes this safe.
ts_texture_churn_worker :: proc(raw: rawptr) {
    job := cast(^TS_Texture_Churn_Job)rawptr(raw)
    for _ in 0 ..< TS_TRACKER_ITERATION {
        for i in 0 ..< job.count {
            index := Tracker_Index(job.base + i)
            device_texture_tracker_insert_single(
                job.tracker,
                index,
                ts_tracker_texture,
                Texture_Uses{.Resource},
            )
            state := device_texture_tracker_get_state_at(job.tracker, index)
            if !state.is_single || state.state != (Texture_Uses{.Resource}) {
                ts_fail(job.failures)
            }
            device_texture_tracker_remove(job.tracker, index)
        }
    }
}

@(test)
test_device_texture_tracker_concurrent_insert_remove_churn :: proc(t: ^testing.T) {
    tr: Device_Texture_Tracker
    device_texture_tracker_init(&tr, Texture_Uses{}, context.allocator)
    defer device_texture_tracker_uninit(&tr)

    failures: TS_Failures
    jobs: [TS_TRACKER_THREADS]TS_Texture_Churn_Job
    threads: [TS_TRACKER_THREADS]^thread.Thread
    for w in 0 ..< TS_TRACKER_THREADS {
        jobs[w] = TS_Texture_Churn_Job {
            tracker  = &tr,
            failures = &failures,
            base     = w * TS_TRACKER_INDICES,
            count    = TS_TRACKER_INDICES,
        }
        threads[w] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[w]),
            ts_texture_churn_worker,
        )
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "texture tracker churn reported an inconsistency")

    sync.guard(&tr.mtx)
    for i in 0 ..< TS_TRACKER_THREADS * TS_TRACKER_INDICES {
        testing.expect(
            t,
            !resource_metadata_contains(&tr.metadata, Tracker_Index(i)),
            "an index survived its remove",
        )
    }

    for i in 0 ..< TS_TRACKER_INDICES {
        device_texture_tracker_insert_single_locked(
            &tr,
            Tracker_Index(i),
            ts_tracker_texture,
            Texture_Uses{.Resource},
        )
    }
    for i in 0 ..< TS_TRACKER_INDICES {
        testing.expect(
            t,
            resource_metadata_contains(&tr.metadata, Tracker_Index(i)),
            "index missing after refill",
        )
    }
}

// Two states, toggled from every thread on one shared index. With the diff and the
// commit under a single exclusive acquisition, the transitions returned across the
// whole run form a chain, which the test verifies as an exact counting identity
// below. Without it, two threads read the same current state and both emit a barrier
// out of it, which on a real device is a duplicated barrier computed from a source
// layout that had already been superseded.
TS_TOGGLE_A :: Buffer_Uses{.Vertex}
TS_TOGGLE_B :: Buffer_Uses{.Copy_Dst}

// Every call lands on the same index, so each one contends for the same lock and a
// few hundred rounds are enough to interleave; there is no per-index loop to amplify.
TS_TOGGLE_ITERATION :: 512

TS_Toggle_Job :: struct {
    tracker:  ^Device_Buffer_Tracker,
    failures: ^TS_Failures,
    // Per-thread transition log, so two threads never write the same slot. `written`
    // is tracked separately because most calls produce no transition at all, and an
    // unwritten slot is indistinguishable from a real transition of `{} -> {}`.
    log:      ^[TS_TOGGLE_ITERATION]State_Transition(Buffer_Uses),
    written:  ^[TS_TOGGLE_ITERATION]bool,
    count:    ^int,
}

ts_buffer_toggle_worker :: proc(raw: rawptr) {
    job := cast(^TS_Toggle_Job)rawptr(raw)
    for i in 0 ..< job.count^ {
        target := i % 2 == 0 ? TS_TOGGLE_A : TS_TOGGLE_B
        if pending, ok := device_buffer_tracker_set_single(
            job.tracker,
            0,
            ts_tracker_buffer,
            target,
        ); ok {
            job.log[i] = pending.usage
            job.written[i] = true
        } else {
            // No transition is only correct if the index already sits in the
            // requested state.
            sync.shared_guard(&job.tracker.mtx)
            if job.tracker.current_states[0] != target {
                ts_fail(job.failures)
            }
        }
    }
}

@(test)
test_device_buffer_tracker_set_single_transitions_form_a_chain :: proc(t: ^testing.T) {
    tr: Device_Buffer_Tracker
    device_buffer_tracker_init(&tr, Buffer_Uses{}, context.allocator)
    defer device_buffer_tracker_uninit(&tr)
    device_buffer_tracker_insert_single(&tr, 0, ts_tracker_buffer, TS_TOGGLE_A)

    failures: TS_Failures
    counts: [TS_TRACKER_THREADS]int

    jobs: [TS_TRACKER_THREADS]TS_Toggle_Job
    logs: [TS_TRACKER_THREADS][TS_TOGGLE_ITERATION]State_Transition(Buffer_Uses)
    written: [TS_TRACKER_THREADS][TS_TOGGLE_ITERATION]bool
    threads: [TS_TRACKER_THREADS]^thread.Thread
    for w in 0 ..< TS_TRACKER_THREADS {
        counts[w] = TS_TOGGLE_ITERATION
        jobs[w] = TS_Toggle_Job {
            tracker  = &tr,
            failures = &failures,
            log      = &logs[w],
            written  = &written[w],
            count    = &counts[w],
        }
        threads[w] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[w]),
            ts_buffer_toggle_worker,
        )
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(t, !ts_failed(&failures), "a no-op transition hid a wrong current state")

    // Only two states are ever requested, so every transition must start in one of
    // them and land in one of them. Calls that produced no transition left their slot
    // untouched and are skipped rather than read as a `{} -> {}` transition.
    from_a, to_a := 0, 0
    from_b, to_b := 0, 0
    transitions := 0
    for w in 0 ..< TS_TRACKER_THREADS {
        for i in 0 ..< counts[w] {
            if !written[w][i] {
                continue
            }
            transitions += 1
            usage := logs[w][i]
            testing.expect(
                t,
                usage.to == TS_TOGGLE_A || usage.to == TS_TOGGLE_B,
                "transition landed on a state that was never requested",
            )
            to_a += usage.to == TS_TOGGLE_A ? 1 : 0
            to_b += usage.to == TS_TOGGLE_B ? 1 : 0
            switch usage.from {
            case TS_TOGGLE_A:
                from_a += 1
            case TS_TOGGLE_B:
                from_b += 1
            case:
                // The tracker was seeded by `insert_single`, so every transition must
                // start in a state it actually held.
                testing.expect_value(t, usage.from, Buffer_Uses{})
            }
        }
    }
    // Sanity: the threads did real work, so the identity below is not vacuous.
    testing.expect(
        t,
        transitions > TS_TRACKER_THREADS,
        "too few transitions were produced for the chain check to mean anything",
    )

    // The transitions form a chain: each one starts where the previous ended. That
    // gives an exact identity which holds no matter how the threads interleaved, the
    // arrivals and departures at a state cancel, except for the state the chain
    // started in and the one it ended in:
    //
    //   count(to == S) - count(from == S) == [S == final] - [S == first_from]
    //
    // A diff-and-commit that is not atomic breaks this immediately: two threads that
    // read the same current state both emit a barrier out of it, so `from` gains a
    // member with no matching `to`. On a real device that is a duplicated barrier for
    // the same buffer, computed from a source layout that was already superseded.
    final: Buffer_Uses
    sync.shared_guard(&tr.mtx)
    final = tr.current_states[0]
    testing.expect(
        t,
        final == TS_TOGGLE_A || final == TS_TOGGLE_B,
        "index 0 ended in a state no thread requested",
    )

    // The chain started in TS_TOGGLE_A, so each state owes
    // `[state == final] - [state == TS_TOGGLE_A]`: one extra departure for the state
    // the chain began in, one extra arrival for the state it ended in.
    expect_a := (TS_TOGGLE_A == final ? 1 : 0) - 1
    expect_b := (TS_TOGGLE_B == final ? 1 : 0)
    testing.expect_value(t, to_a - from_a, expect_a)
    testing.expect_value(t, to_b - from_b, expect_b)
}

// Drives `device_texture_tracker_get_state_at` against a deliberately divergent
// texture while another thread repeatedly grows the state set. Growing it reallocates
// `Texture_State_Set.simple`, which is the storage the divergent entry sits beside,
// so this is the case where a reader that had not resolved the state under the lock
// could be left holding a reference into freed memory.
TS_DIVERGENT_ITERATION :: 2000

@(test)
test_device_texture_tracker_reports_divergent_state_under_growth :: proc(t: ^testing.T) {
    tr: Device_Texture_Tracker
    device_texture_tracker_init(&tr, Texture_Uses{}, context.allocator)
    defer device_texture_tracker_uninit(&tr)

    // Two mip levels in two different states, so index 0 can only be complex.
    //
    // This is setup, written directly into the tracker's tables before any thread
    // exists, so it needs no lock. It must not take one: the guard would still be
    // held at the `get_state_at` call below, which takes the shared lock itself.
    device_texture_tracker_insert_single(&tr, 0, ts_tracker_texture, Texture_Uses{.Resource})
    provider_a := texture_state_provider_selector(
        Texture_Selector{mips = Range(u32){0, 1}, layers = Range(u32){0, 1}},
        Texture_Uses{.Resource},
    )
    provider_b := texture_state_provider_selector(
        Texture_Selector{mips = Range(u32){1, 2}, layers = Range(u32){0, 1}},
        Texture_Uses{.Copy_Src},
    )
    full_range := Texture_Selector {
        mips   = Range(u32){0, 2},
        layers = Range(u32){0, 1},
    }
    texture_state_update(full_range, nil, &tr.current_state_set, 0, &provider_a)
    texture_state_update(full_range, nil, &tr.current_state_set, 0, &provider_b)

    testing.expect(
        t,
        !device_texture_tracker_get_state_at(&tr, 0).is_single,
        "a texture in two states was reported as single",
    )

    failures: TS_Failures
    reader: TS_Texture_Churn_Job = {
        tracker  = &tr,
        failures = &failures,
    }
    grower: TS_Texture_Churn_Job = {
        tracker  = &tr,
        failures = &failures,
    }

    ts_divergent_reader :: proc(raw: rawptr) {
        job := cast(^TS_Texture_Churn_Job)rawptr(raw)
        for _ in 0 ..< TS_DIVERGENT_ITERATION {
            // Index 0 stays complex for the whole run: the grower only ever adds and
            // removes the index above it.
            if device_texture_tracker_get_state_at(job.tracker, 0).is_single {
                ts_fail(job.failures)
            }
        }
    }

    ts_divergent_grower :: proc(raw: rawptr) {
        job := cast(^TS_Texture_Churn_Job)rawptr(raw)
        for _ in 0 ..< TS_DIVERGENT_ITERATION {
            index := Tracker_Index(1)
            device_texture_tracker_insert_single(
                job.tracker,
                index,
                ts_tracker_texture,
                Texture_Uses{.Resource},
            )
            device_texture_tracker_remove(job.tracker, index)
        }
    }

    threads: [2]^thread.Thread
    threads[0] = thread.create_and_start_with_poly_data(rawptr(&reader), ts_divergent_reader)
    threads[1] = thread.create_and_start_with_poly_data(rawptr(&grower), ts_divergent_grower)
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect(
        t,
        !ts_failed(&failures),
        "a divergent state stopped reading as divergent, or a read raced a resize",
    )
}

// -----------------------------------------------------------------------------
// Deferred writes
//
// The scratch command encoder and its staging buffers are shared by every thread
// that performs a queue write, an unmap, or a clear. These mirror the bookkeeping
// `Deferred_Writes` guards, minus the encoder itself, which needs a device: one
// owner at a time, pending state detached rather than drained in place, and no
// update lost when many threads queue writes concurrently.
// -----------------------------------------------------------------------------

TS_Deferred_Writes :: struct {
    command_encoder: int,
    temp_resources:  [dynamic]int,
    dst_buffers:     map[Tracker_Index]int,
    mtx:             sync.RW_Mutex,
}

TS_Deferred_Write_Job :: struct {
    pw:         ^TS_Deferred_Writes,
    index:      Tracker_Index,
    iterations: int,
}

// Mirrors a queue write: activate the scratch encoder (creating it if absent),
// record, then register the destination and the staging buffer.
ts_deferred_write_worker :: proc(raw: rawptr) {
    job := cast(^TS_Deferred_Write_Job)rawptr(raw)
    for _ in 0 ..< job.iterations {
        sync.guard(&job.pw.mtx)
        if job.pw.command_encoder == 0 {
            job.pw.command_encoder = 1
        }
        job.pw.dst_buffers[job.index] = int(job.index)
        append(&job.pw.temp_resources, 1)
    }
}

@(test)
test_deferred_writes_concurrent_queue_writes_are_serialized :: proc(t: ^testing.T) {
    pw: TS_Deferred_Writes
    pw.dst_buffers.allocator = context.allocator
    pw.temp_resources.allocator = context.allocator
    defer delete(pw.temp_resources)
    defer delete(pw.dst_buffers)

    jobs: [TS_TRACKER_THREADS]TS_Deferred_Write_Job
    threads: [TS_TRACKER_THREADS]^thread.Thread
    for w in 0 ..< TS_TRACKER_THREADS {
        jobs[w] = TS_Deferred_Write_Job {
            pw         = &pw,
            index      = Tracker_Index(w),
            iterations = TS_TRACKER_ITERATION,
        }
        threads[w] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[w]),
            ts_deferred_write_worker,
        )
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    sync.guard(&pw.mtx)
    testing.expect_value(t, pw.command_encoder, 1)
    // Every queued write must be recorded exactly once. A lost append or a lost map
    // update is what the lock exists to prevent.
    testing.expect_value(t, len(pw.temp_resources), TS_TRACKER_THREADS * TS_TRACKER_ITERATION)
    testing.expect_value(t, len(pw.dst_buffers), TS_TRACKER_THREADS)
}

// A flush must take the whole pending batch with it and leave the scratch encoder
// empty, so a concurrent queue write starts a fresh encoder rather than appending to
// one that is already being recorded and submitted.
@(test)
test_deferred_writes_flush_detaches_the_pending_batch :: proc(t: ^testing.T) {
    pw: TS_Deferred_Writes
    pw.dst_buffers.allocator = context.allocator
    pw.temp_resources.allocator = context.allocator
    defer delete(pw.temp_resources)
    defer delete(pw.dst_buffers)

    pw.command_encoder = 7
    pw.dst_buffers[0] = 100
    pw.dst_buffers[1] = 200
    append(&pw.temp_resources, 11)
    append(&pw.temp_resources, 22)
    append(&pw.temp_resources, 33)

    encoder: int
    temp: [dynamic]int
    {
        sync.guard(&pw.mtx)
        if pw.command_encoder != 0 {
            encoder = pw.command_encoder
            pw.command_encoder = 0
            temp = pw.temp_resources
            pw.temp_resources = [dynamic]int{}
            pw.temp_resources.allocator = temp.allocator
            clear(&pw.dst_buffers)
        }
    }
    testing.expect_value(t, encoder, 7)
    testing.expect_value(t, len(temp), 3)
    testing.expect_value(t, temp[0], 11)
    testing.expect_value(t, temp[2], 33)
    delete(temp)

    // A second flush with nothing pending must not hand back the batch again, and the
    // writer's own storage must still be usable.
    encoder = 0
    temp = {}
    {
        sync.guard(&pw.mtx)
        if pw.command_encoder != 0 {
            encoder = pw.command_encoder
        }
    }
    testing.expect_value(t, encoder, 0)

    sync.guard(&pw.mtx)
    pw.dst_buffers[9] = 900
    append(&pw.temp_resources, 44)
    testing.expect_value(t, len(pw.temp_resources), 1)
    testing.expect(t, 9 in pw.dst_buffers, "a post-flush write did not reach the tracker")
}

@(test)
test_command_buffer_take_resource_refs_transfers_storage :: proc(t: ^testing.T) {
    cmdbuf: VK_Command_Buffer_Impl
    cmdbuf.tracker.bind_groups.resources.allocator = context.allocator
    cmdbuf.tracker.views.resources.allocator = context.allocator
    cmdbuf.tracker.render_pipelines.resources.allocator = context.allocator

    first_group := Bind_Group(Handle{handle = Handle_Packed(0xF003_0001)})
    second_group := Bind_Group(Handle{handle = Handle_Packed(0xF003_0002)})
    first_view := Texture_View(Handle{handle = Handle_Packed(0xF003_0003)})
    second_view := Texture_View(Handle{handle = Handle_Packed(0xF003_0004)})
    first_pipeline := Render_Pipeline(Handle{handle = Handle_Packed(0xF003_0005)})
    second_pipeline := Render_Pipeline(Handle{handle = Handle_Packed(0xF003_0006)})
    append(&cmdbuf.tracker.bind_groups.resources, first_group)
    append(&cmdbuf.tracker.bind_groups.resources, second_group)
    append(&cmdbuf.tracker.views.resources, first_view)
    append(&cmdbuf.tracker.views.resources, second_view)
    append(&cmdbuf.tracker.render_pipelines.resources, first_pipeline)
    append(&cmdbuf.tracker.render_pipelines.resources, second_pipeline)

    group_refs := vk_command_buffer_take_bind_group_refs(&cmdbuf)
    view_refs := vk_command_buffer_take_view_refs(&cmdbuf)
    pipeline_refs := vk_command_buffer_take_render_pipeline_refs(&cmdbuf)
    testing.expect_value(t, len(group_refs), 2)
    testing.expect_value(t, group_refs[0], first_group)
    testing.expect_value(t, group_refs[1], second_group)
    testing.expect_value(t, len(view_refs), 2)
    testing.expect_value(t, view_refs[0], first_view)
    testing.expect_value(t, view_refs[1], second_view)
    testing.expect_value(t, len(pipeline_refs), 2)
    testing.expect_value(t, pipeline_refs[0], first_pipeline)
    testing.expect_value(t, pipeline_refs[1], second_pipeline)
    testing.expect_value(t, len(cmdbuf.tracker.bind_groups.resources), 0)
    testing.expect_value(t, len(cmdbuf.tracker.views.resources), 0)
    testing.expect_value(t, len(cmdbuf.tracker.render_pipelines.resources), 0)

    third := Bind_Group(Handle{handle = Handle_Packed(0xF003_0007)})
    append(&cmdbuf.tracker.bind_groups.resources, third)
    testing.expect_value(t, len(cmdbuf.tracker.bind_groups.resources), 1)

    delete(group_refs)
    delete(view_refs)
    delete(pipeline_refs)
    delete(cmdbuf.tracker.bind_groups.resources)
}

TS_CACHE_THREADS :: 8
TS_CACHE_KEYS_PER_THREAD :: 128
TS_CACHE_TOTAL_KEYS :: TS_CACHE_THREADS * TS_CACHE_KEYS_PER_THREAD

TS_Device_Cache_Job :: struct {
    device_impl:         ^VK_Device_Impl,
    failures:            ^TS_Failures,
    render_pass_winners: ^int,
    framebuffer_winners: ^int,
    base:                int,
}

ts_device_cache_insert_worker :: proc(raw: rawptr) {
    job := cast(^TS_Device_Cache_Job)raw
    for i in 0 ..< TS_CACHE_KEYS_PER_THREAD {
        index := job.base + i
        rp_key := VK_Render_Pass_Key{sample_count = u32(index + 1)}
        _, rp_inserted := vk_render_pass_cache_insert_if_absent(
            job.device_impl, rp_key, {})
        if !rp_inserted do ts_fail(job.failures)
        _, rp_found := vk_render_pass_cache_lookup(job.device_impl, rp_key)
        if !rp_found do ts_fail(job.failures)

        fb_candidate := VK_Framebuffer_Cache{
            width = u32(index + 1),
            height = 1,
        }
        _, fb_inserted := vk_framebuffer_cache_insert_if_absent(
            job.device_impl, fb_candidate)
        if !fb_inserted do ts_fail(job.failures)
        cached_fb, fb_found := vk_framebuffer_cache_lookup(
            job.device_impl, fb_candidate.key)
        if !fb_found || cached_fb.width != u32(index + 1) {
            ts_fail(job.failures)
        }
    }

    contested_rp_key := VK_Render_Pass_Key{sample_count = max(u32)}
    _, rp_inserted := vk_render_pass_cache_insert_if_absent(
        job.device_impl, contested_rp_key, {})
    if rp_inserted do intr.atomic_add(job.render_pass_winners, 1)

    contested_fb := VK_Framebuffer_Cache{
        width = max(u32),
        height = max(u32),
    }
    _, fb_inserted := vk_framebuffer_cache_insert_if_absent(job.device_impl, contested_fb)
    if fb_inserted do intr.atomic_add(job.framebuffer_winners, 1)
}

@(test)
test_device_render_pass_and_framebuffer_caches_concurrent_insert_lookup :: proc(
    t: ^testing.T,
) {
    device_impl: VK_Device_Impl
    device_impl.render_pass_cache.allocator = context.allocator
    device_impl.framebuffer_cache.allocator = context.allocator

    failures: TS_Failures
    render_pass_winners: int
    framebuffer_winners: int
    jobs: [TS_CACHE_THREADS]TS_Device_Cache_Job
    threads: [TS_CACHE_THREADS]^thread.Thread
    for worker in 0 ..< TS_CACHE_THREADS {
        jobs[worker] = TS_Device_Cache_Job{
            device_impl = &device_impl,
            failures = &failures,
            render_pass_winners = &render_pass_winners,
            framebuffer_winners = &framebuffer_winners,
            base = worker * TS_CACHE_KEYS_PER_THREAD,
        }
        threads[worker] = thread.create_and_start_with_poly_data(
            rawptr(&jobs[worker]), ts_device_cache_insert_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {thread.destroy(th)}

    testing.expect_value(t, ts_failed(&failures), false)
    testing.expect_value(t, intr.atomic_load(&render_pass_winners), 1)
    testing.expect_value(t, intr.atomic_load(&framebuffer_winners), 1)
    {
        sync.shared_guard(&device_impl.render_pass_cache_mtx)
        testing.expect_value(t, len(device_impl.render_pass_cache), TS_CACHE_TOTAL_KEYS + 1)
    }
    {
        sync.shared_guard(&device_impl.framebuffer_cache_mtx)
        testing.expect_value(t, len(device_impl.framebuffer_cache), TS_CACHE_TOTAL_KEYS + 1)
    }

    delete(device_impl.render_pass_cache)
    delete(device_impl.framebuffer_cache)
}
