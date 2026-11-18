package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS
// `api/validation/encoding/cmds/copyBufferToBuffer.spec.ts`.

cts_run_copy :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    source: gpu.Buffer,
    source_offset: u64,
    destination: gpu.Buffer,
    destination_offset: u64,
    size: u64,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    gpu.command_encoder_copy_buffer_to_buffer(
        encoder, source, source_offset, destination, destination_offset, size)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_copy_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    State :: enum {
        Valid,
        Invalid,
        Destroyed,
    }
    any_accepted := false
    any_refused := false

    for source_state in ([3]State{.Valid, .Invalid, .Destroyed}) {
        for destination_state in ([3]State{.Valid, .Invalid, .Destroyed}) {
            source := gpu.Buffer{}
            destination := gpu.Buffer{}
            if source_state != .Invalid {
                source = gpu.device_create_buffer(f.device, {
                    size = 16, usage = {.Copy_Src, .Copy_Dst},
                })
                if source_state == .Destroyed {
                    gpu.buffer_release(source)
                }
            }
            if destination_state != .Invalid {
                destination = gpu.device_create_buffer(f.device, {
                    size = 16, usage = {.Copy_Src, .Copy_Dst},
                })
                if destination_state == .Destroyed {
                    gpu.buffer_release(destination)
                }
            }

            should_fail := source_state != .Valid || destination_state != .Valid
            errors := cts_run_copy(t, f, source, 0, destination, 0, 8)
            cts_expect_outcome(t, errors ? 1 : 0, should_fail,
                fmt.tprintf("copy from %v to %v", source_state, destination_state))

            if source_state == .Valid {
                gpu.buffer_release(source)
            }
            if destination_state == .Valid {
                gpu.buffer_release(destination)
            }
            any_accepted = any_accepted || !should_fail
            any_refused = any_refused || should_fail
        }
    }

    cts_require_both(t, any_accepted, any_refused, "buffer_state")
}

@(test)
cts_copy_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    if other == nil {
        return
    }
    defer gpu.device_release(other)

    for source_mismatched in ([2]bool{false, true}) {
        for destination_mismatched in ([2]bool{false, true}) {
            if !source_mismatched && !destination_mismatched {
                // Covered by the control row below.
            }
            source := gpu.device_create_buffer(source_mismatched ? other : f.device, {
                size = 16, usage = {.Copy_Src},
            })
            destination := gpu.device_create_buffer(
                destination_mismatched ? other : f.device, {
                    size = 16, usage = {.Copy_Dst},
                })
            defer gpu.buffer_release(source)
            defer gpu.buffer_release(destination)

            mismatch := source_mismatched || destination_mismatched
            errors := cts_run_copy(t, f, source, 0, destination, 0, 8)
            cts_expect_outcome(t, errors ? 1 : 0, mismatch,
                fmt.tprintf("copy with srcMismatched=%v dstMismatched=%v",
                    source_mismatched, destination_mismatched))
        }
    }
}

@(test)
cts_copy_buffer_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        usage:    gpu.Buffer_Usages,
        accepted: bool,
    }
    rows := [5]Row{
        {{.Copy_Src, .Vertex}, true},
        {{.Copy_Src}, true},
        {{.Copy_Dst}, false},
        {{.Copy_Src, .Copy_Dst}, true},
        {{.Index}, false},
    }

    for row, i in rows {
        source := gpu.device_create_buffer(f.device, {size = 16, usage = row.usage})
        destination := gpu.device_create_buffer(f.device, {
            size = 16, usage = {.Copy_Dst},
        })
        defer gpu.buffer_release(source)
        defer gpu.buffer_release(destination)

        errors := cts_run_copy(t, f, source, 0, destination, 0, 8)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("copyBufferToBuffer with source usage row %d", i))
    }
}

@(test)
cts_copy_buffer_size_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    source := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Src}})
    destination := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(destination)

    Row :: struct {
        size:     u64,
        accepted: bool,
    }
    rows := [5]Row{
        {0, true},
        {2, false},
        {4, true},
        {5, false},
        {8, true},
    }

    for row in rows {
        errors := cts_run_copy(t, f, source, 0, destination, 0, row.size)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("copy of %d bytes", row.size))
    }
}

@(test)
cts_copy_buffer_offset_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    source := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Src}})
    destination := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(destination)

    Row :: struct {
        source_offset:      u64,
        destination_offset: u64,
        accepted:           bool,
    }
    rows := [10]Row{
        {0, 0, true},
        {2, 0, false},
        {4, 0, true},
        {5, 0, false},
        {8, 0, true},
        {0, 2, false},
        {0, 4, true},
        {0, 5, false},
        {0, 8, true},
        {4, 4, true},
    }

    for row in rows {
        errors := cts_run_copy(t, f, source, row.source_offset,
            destination, row.destination_offset, 8)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("copy from %d to %d", row.source_offset, row.destination_offset))
    }
}

@(test)
cts_copy_buffer_overflow :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    source := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Src}})
    destination := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(destination)

    Row :: struct {
        source_offset:      u64,
        destination_offset: u64,
        size:               u64,
    }
    rows := [8]Row{
        {0, 0, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {16, 0, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {0, 16, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {CTS_MAX_SAFE_MULTIPLE_OF_8, 0, 16},
        {0, CTS_MAX_SAFE_MULTIPLE_OF_8, 16},
        {CTS_MAX_SAFE_MULTIPLE_OF_8, 0, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {0, CTS_MAX_SAFE_MULTIPLE_OF_8, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {
            CTS_MAX_SAFE_MULTIPLE_OF_8,
            CTS_MAX_SAFE_MULTIPLE_OF_8,
            CTS_MAX_SAFE_MULTIPLE_OF_8,
        },
    }

    for row in rows {
        errors := cts_run_copy(t, f, source, row.source_offset,
            destination, row.destination_offset, row.size)
        cts_expect_outcome(t, errors ? 1 : 0, true,
            fmt.tprintf("copy of %d bytes at %d/%d",
                row.size, row.source_offset, row.destination_offset))
    }
}

@(test)
cts_copy_buffer_out_of_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    source := gpu.device_create_buffer(f.device, {size = 32, usage = {.Copy_Src}})
    destination := gpu.device_create_buffer(f.device, {size = 32, usage = {.Copy_Dst}})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(destination)

    Row :: struct {
        source_offset:      u64,
        destination_offset: u64,
        size:               u64,
        accepted:           bool,
    }
    rows := [10]Row{
        {0, 0, 32, true},
        {0, 0, 36, false},
        {36, 0, 4, false},
        {0, 36, 4, false},
        {36, 0, 0, false},
        {0, 36, 0, false},
        {20, 0, 16, false},
        {20, 0, 12, true},
        {0, 20, 16, false},
        {0, 20, 12, true},
    }

    any_accepted := false
    any_refused := false
    for row in rows {
        errors := cts_run_copy(t, f, source, row.source_offset,
            destination, row.destination_offset, row.size)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("copy of %d bytes at %d/%d on 32-byte buffers",
                row.size, row.source_offset, row.destination_offset))
        any_accepted = any_accepted || row.accepted
        any_refused = any_refused || !row.accepted
    }
    cts_require_both(t, any_accepted, any_refused, "copy_out_of_bounds")
}

@(test)
cts_copy_buffer_within_same_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {
        size = 16, usage = {.Copy_Src, .Copy_Dst},
    })
    defer gpu.buffer_release(buffer)

    rows := [4][2]u64{
        {0, 8},
        {8, 0},
        {0, 4},
        {4, 0},
    }
    for row, i in rows {
        size := i < 2 ? 4 : 8
        errors := cts_run_copy(t, f, buffer, row[0], buffer, row[1], u64(size))
        cts_expect_outcome(t, errors ? 1 : 0, true,
            fmt.tprintf("copy within one buffer from %d to %d", row[0], row[1]))
    }
}
