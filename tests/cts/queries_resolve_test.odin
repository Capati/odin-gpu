package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS
// `api/validation/encoding/queries/resolveQuerySet.spec.ts`.

CTS_QUERY_COUNT :: u32(2)

cts_make_occlusion_set :: proc(f: CTS_Fixture, count: u32) -> gpu.Query_Set {
    set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = count})
    assert(set != {}, "failed to create the query set")
    return set
}

cts_make_resolve_buffer :: proc(f: CTS_Fixture, size: u64) -> gpu.Buffer {
    buffer := gpu.device_create_buffer(f.device, {size = size, usage = {.Query_Resolve}})
    assert(buffer != {}, "failed to create the resolve buffer")
    return buffer
}

cts_run_resolve :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    set: gpu.Query_Set,
    first_query: u32,
    query_count: u32,
    destination: gpu.Buffer,
    destination_offset: u64,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    gpu.command_encoder_resolve_query_set(
        encoder, set, first_query, query_count, destination, destination_offset)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_resolve_query_set_states :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    State :: enum {
        Valid,
        Invalid,
        Destroyed,
    }
    any_accepted := false
    any_refused := false

    for set_state in ([3]State{.Valid, .Invalid, .Destroyed}) {
        for buffer_state in ([3]State{.Valid, .Invalid, .Destroyed}) {
            set := gpu.Query_Set{}
            destination := gpu.Buffer{}
            if set_state != .Invalid {
                set = cts_make_occlusion_set(f, CTS_QUERY_COUNT)
                if set_state == .Destroyed {
                    gpu.query_set_release(set)
                }
            }
            if buffer_state != .Invalid {
                destination = cts_make_resolve_buffer(f, u64(CTS_QUERY_COUNT) * 8)
                if buffer_state == .Destroyed {
                    gpu.buffer_release(destination)
                }
            }

            should_fail := set_state != .Valid || buffer_state != .Valid
            errors := cts_run_resolve(t, f, set, 0, 1, destination, 0)
            cts_expect_outcome(t, errors ? 1 : 0, should_fail,
                fmt.tprintf("resolve over a %v set into a %v buffer",
                    set_state, buffer_state))

            if set_state == .Valid {
                gpu.query_set_release(set)
            }
            if buffer_state == .Valid {
                gpu.buffer_release(destination)
            }
            any_accepted = any_accepted || !should_fail
            any_refused = any_refused || should_fail
        }
    }
    cts_require_both(t, any_accepted, any_refused, "queryset_and_destination_buffer_state")
}

@(test)
cts_resolve_query_set_range :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := cts_make_occlusion_set(f, CTS_QUERY_COUNT)
    defer gpu.query_set_release(set)
    destination := cts_make_resolve_buffer(f, u64(CTS_QUERY_COUNT) * 8)
    defer gpu.buffer_release(destination)

    Row :: struct {
        first_query: u32,
        query_count: u32,
        accepted:    bool,
    }
    rows := [4]Row{
        {0, CTS_QUERY_COUNT, true},
        {0, CTS_QUERY_COUNT + 1, false},
        {1, CTS_QUERY_COUNT, false},
        {CTS_QUERY_COUNT, 1, false},
    }

    for row in rows {
        errors := cts_run_resolve(t, f, set, row.first_query, row.query_count,
            destination, 0)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("resolve of %d queries from %d",
                row.query_count, row.first_query))
    }
}

@(test)
cts_resolve_query_set_destination_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := cts_make_occlusion_set(f, CTS_QUERY_COUNT)
    defer gpu.query_set_release(set)

    storage := gpu.device_create_buffer(f.device, {
        size = u64(CTS_QUERY_COUNT) * 8, usage = {.Storage},
    })
    defer gpu.buffer_release(storage)
    errors := cts_run_resolve(t, f, set, 0, CTS_QUERY_COUNT, storage, 0)
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve into a STORAGE buffer")

    resolve := cts_make_resolve_buffer(f, u64(CTS_QUERY_COUNT) * 8)
    defer gpu.buffer_release(resolve)
    errors = cts_run_resolve(t, f, set, 0, CTS_QUERY_COUNT, resolve, 0)
    cts_expect_outcome(t, errors ? 1 : 0, false, "resolve into a QUERY_RESOLVE buffer")
}

@(test)
cts_resolve_query_set_offset_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := cts_make_occlusion_set(f, CTS_QUERY_COUNT)
    defer gpu.query_set_release(set)
    destination := cts_make_resolve_buffer(f, 512)
    defer gpu.buffer_release(destination)

    for offset in ([4]u64{0, 128, 256, 384}) {
        errors := cts_run_resolve(t, f, set, 0, CTS_QUERY_COUNT, destination, offset)
        cts_expect_outcome(t, errors ? 1 : 0, offset % 256 != 0,
            fmt.tprintf("resolve at destination offset %d", offset))
    }
}

@(test)
cts_resolve_query_set_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        query_count: u32,
        buffer_size: u64,
        offset:      u64,
        accepted:    bool,
    }
    rows := [5]Row{
        {2, 16, 0, true},
        {3, 16, 0, false},
        {2, 16, 256, false},
        {2, 272, 256, true},
        {2, 264, 256, false},
    }

    for row in rows {
        set := cts_make_occlusion_set(f, row.query_count)
        destination := cts_make_resolve_buffer(f, row.buffer_size)
        errors := cts_run_resolve(t, f, set, 0, row.query_count,
            destination, row.offset)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("%d queries into %d bytes at offset %d",
                row.query_count, row.buffer_size, row.offset))
        gpu.query_set_release(set)
        gpu.buffer_release(destination)
    }
}

@(test)
cts_resolve_query_set_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    if other == nil {
        return
    }
    defer gpu.device_release(other)

    other_fixture := CTS_Fixture {
        instance = f.instance,
        adapter  = f.adapter,
        device   = other,
    }

    for set_mismatched in ([2]bool{false, true}) {
        for buffer_mismatched in ([2]bool{false, true}) {
            set := cts_make_occlusion_set(set_mismatched ? other_fixture : f, 1)
            destination := cts_make_resolve_buffer(buffer_mismatched ? other_fixture : f, 8)
            defer gpu.query_set_release(set)
            defer gpu.buffer_release(destination)

            errors := cts_run_resolve(t, f, set, 0, 1, destination, 0)
            cts_expect_outcome(t, errors ? 1 : 0,
                set_mismatched || buffer_mismatched,
                fmt.tprintf("resolve with setMismatched=%v bufferMismatched=%v",
                    set_mismatched, buffer_mismatched))
        }
    }
}
