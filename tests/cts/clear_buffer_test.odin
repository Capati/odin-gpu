package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/encoding/cmds/clearBuffer.spec.ts`
//.

CTS_MAX_SAFE_MULTIPLE_OF_8 :: u64(0x1F_FFFF_FFFF_FFF8)

cts_run_clear :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    buffer: gpu.Buffer,
    offset: u64,
    size: u64,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    gpu.command_encoder_clear_buffer(encoder, buffer, offset, size)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_clear_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    valid := gpu.device_create_buffer(f.device, {size = 8, usage = {.Copy_Dst}})
    errors := cts_run_clear(t, f, valid, 0, 8)
    cts_expect_outcome(t, errors ? 1 : 0, false, "clearBuffer over a valid buffer")
    gpu.buffer_release(valid)

    destroyed := gpu.device_create_buffer(f.device, {size = 8, usage = {.Copy_Dst}})
    gpu.buffer_release(destroyed)
    errors = cts_run_clear(t, f, destroyed, 0, 8)
    cts_expect_outcome(t, errors ? 1 : 0, true, "clearBuffer over a destroyed buffer")

    errors = cts_run_clear(t, f, {}, 0, 8)
    cts_expect_outcome(t, errors ? 1 : 0, true, "clearBuffer over an invalid buffer")
}

@(test)
cts_clear_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    if other == nil {
        return
    }
    defer gpu.device_release(other)

    buffer := gpu.device_create_buffer(other, {size = 8, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)
    errors := cts_run_clear(t, f, buffer, 0, 8)
    cts_expect_outcome(t, errors ? 1 : 0, true,
        "clearBuffer over another device's buffer")
}

@(test)
cts_clear_buffer_default_args :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)

    cts_expect_outcome(t, cts_run_clear(t, f, buffer, 0, gpu.WHOLE_SIZE) ? 1 : 0,
        false, "clearBuffer with no offset and no size")
    cts_expect_outcome(t, cts_run_clear(t, f, buffer, 4, gpu.WHOLE_SIZE) ? 1 : 0,
        false, "clearBuffer from offset 4 to the end")
    cts_expect_outcome(t, cts_run_clear(t, f, buffer, 0, 8) ? 1 : 0,
        false, "clearBuffer without an offset and 8 bytes")
}

@(test)
cts_clear_buffer_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        usage:    gpu.Buffer_Usages,
        accepted: bool,
        what:     string,
    }
    rows := [5]Row{
        {{.Copy_Dst}, true, "COPY_DST"},
        {{.Copy_Src}, false, "COPY_SRC"},
        {{.Vertex}, false, "VERTEX"},
        {{.Uniform}, false, "UNIFORM"},
        {{.Copy_Dst, .Vertex}, true, "COPY_DST | VERTEX"},
    }

    for row in rows {
        buffer := gpu.device_create_buffer(f.device, {size = 16, usage = row.usage})
        defer gpu.buffer_release(buffer)
        errors := cts_run_clear(t, f, buffer, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("clearBuffer over a %s buffer", row.what))
    }
}

@(test)
cts_clear_buffer_size_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        size:     u64,
        has_size: bool,
        accepted: bool,
    }
    rows := [7]Row{
        {0, true, true},
        {2, true, false},
        {4, true, true},
        {5, true, false},
        {8, true, true},
        {20, true, false},
        {0, false, true},
    }

    for row in rows {
        size := row.has_size ? row.size : gpu.WHOLE_SIZE
        what: string
        if row.has_size {
            what = fmt.tprintf("clearBuffer of %d bytes", row.size)
        } else {
            what = "clearBuffer with an absent size"
        }
        errors := cts_run_clear(t, f, buffer, 0, size)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, what)
    }
}

@(test)
cts_clear_buffer_offset_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        offset:   u64,
        accepted: bool,
    }
    rows := [7]Row{
        {0, true},
        {2, false},
        {4, true},
        {5, false},
        {8, true},
        {20, false},
        {0, true},
    }

    for row in rows {
        errors := cts_run_clear(t, f, buffer, row.offset, 8)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("clearBuffer at offset %d", row.offset))
    }
}

@(test)
cts_clear_buffer_overflow :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        offset: u64,
        size:   u64,
    }
    rows := [4]Row{
        {0, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {16, CTS_MAX_SAFE_MULTIPLE_OF_8},
        {CTS_MAX_SAFE_MULTIPLE_OF_8, 16},
        {CTS_MAX_SAFE_MULTIPLE_OF_8, CTS_MAX_SAFE_MULTIPLE_OF_8},
    }

    for row in rows {
        errors := cts_run_clear(t, f, buffer, row.offset, row.size)
        cts_expect_outcome(t, errors ? 1 : 0, true,
            fmt.tprintf("clearBuffer of %d bytes at offset %d", row.size, row.offset))
    }
}

@(test)
cts_clear_buffer_out_of_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer := gpu.device_create_buffer(f.device, {size = 32, usage = {.Copy_Dst}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        offset:   u64,
        size:     u64,
        accepted: bool,
    }
    rows := [8]Row{
        {0, 32, true},
        {0, 36, false},
        {32, 0, true},
        {32, 4, false},
        {36, 4, false},
        {36, 0, false},
        {20, 16, false},
        {20, 12, true},
    }

    any_accepted := false
    any_refused := false
    for row in rows {
        errors := cts_run_clear(t, f, buffer, row.offset, row.size)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
            fmt.tprintf("clearBuffer of %d bytes at offset %d on a 32-byte buffer",
                row.size, row.offset))
        any_accepted = any_accepted || row.accepted
        any_refused = any_refused || !row.accepted
    }
    cts_require_both(t, any_accepted, any_refused, "out_of_bounds")
}
