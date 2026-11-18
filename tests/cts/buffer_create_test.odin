package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/buffer/create.spec.ts`.

@(test)
cts_buffer_create_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    sizes := [5]u64{0, 2, 4, 6, 8}
    rows := 0
    any_accepted := false
    any_refused := false

    for mapped in ([2]bool{false, true}) {
        for size in sizes {
            valid := !mapped || size % 4 == 0
            buffer, errors := cts_measure_buffer_create(t, f.device, {
                size               = size,
                usage              = {.Copy_Src},
                mapped_at_creation = mapped,
            })
            cts_expect_outcome(t, errors, !valid,
                fmt.tprintf("size %d, mappedAtCreation %v", size, mapped))
            if buffer != {} {
                gpu.buffer_release(buffer)
            }
            any_accepted = any_accepted || valid
            any_refused = any_refused || !valid
            rows += 1
        }
    }

    cts_require_rows(t, rows, 10, "size")
    cts_require_both(t, any_accepted, any_refused, "size")
}

@(test)
cts_buffer_create_limit :: proc(t: ^testing.T) {
    descriptor := gpu.Device_Descriptor{}
    descriptor.required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS
    descriptor.required_limits.max_buffer_size = 4096
    f := cts_make_fixture(descriptor)
    defer cts_destroy_fixture(f)

    limit := u64(4096)
    additions := [3]i64{-1, 0, 1}
    rows := 0
    any_accepted := false
    any_refused := false

    for addition in additions {
        size := u64(i64(limit) + addition)
        valid := size <= limit
        buffer, errors := cts_measure_buffer_create(t, f.device, {
            size  = size,
            usage = {.Copy_Src},
        })
        cts_expect_outcome(t, errors, !valid,
            fmt.tprintf("size %d against maxBufferSize %d", size, limit))
        if buffer != {} {
            gpu.buffer_release(buffer)
        }
        any_accepted = any_accepted || valid
        any_refused = any_refused || !valid
        rows += 1
    }

    cts_require_rows(t, rows, 3, "limit")
    cts_require_both(t, any_accepted, any_refused, "limit")
}

@(test)
cts_buffer_create_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    core := cts_core_buffer_usages()
    options: [12]gpu.Buffer_Usages
    for usage, i in core {
        options[i + 1] = usage
    }
    options[11] = cts_bogus_usage()

    rows := 0
    any_accepted := false
    any_refused := false

    for i in 0 ..< 12 {
        for j in i ..< 12 {
            usage := options[i] | options[j]
            valid := cts_buffer_usage_pair_valid(usage)
            for mapped in ([2]bool{false, true}) {
                buffer, errors := cts_measure_buffer_create(t, f.device, {
                    size               = 8,
                    usage              = usage,
                    mapped_at_creation = mapped,
                })
                cts_expect_outcome(t, errors, !valid,
                    fmt.tprintf("usage 0x%x|0x%x, mappedAtCreation %v",
                        cts_usage_bits(options[i]), cts_usage_bits(options[j]), mapped))
                if buffer != {} {
                    gpu.buffer_release(buffer)
                }
                any_accepted = any_accepted || valid
                any_refused = any_refused || !valid
                rows += 1
            }
        }
    }

    cts_require_rows(t, rows, 100, "usage")
    cts_require_both(t, any_accepted, any_refused, "usage")
}

@(test)
cts_buffer_create_new_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for usage in cts_core_buffer_usages() {
        buffer, errors := cts_measure_buffer_create(t, f.device, {
            size  = 16,
            usage = usage,
        })
        cts_expect_outcome(t, errors, false,
            fmt.tprintf("usage 0x%x", cts_usage_bits(usage)))
        if buffer != {} {
            gpu.buffer_release(buffer)
        }
        rows += 1
    }
    cts_require_rows(t, rows, 10, "new_usages")
}

@(test)
cts_buffer_create_invalid_and_oom :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Oom_Row :: struct {
        usage: gpu.Buffer_Usages,
        size:  u64,
        valid: bool,
    }
    table := [6]Oom_Row{
        {usage = {.Uniform}, size = 16, valid = true},
        {usage = {.Storage}, size = 16, valid = true},
        {usage = {.Map_Write, .Uniform}, size = 16},
        {usage = {.Map_Write, .Uniform}, size = 0x20_0000_0000},
        {usage = {.Map_Read, .Uniform}, size = 16},
        {usage = {.Map_Read, .Uniform}, size = 0x20_0000_0000},
    }

    checked := 0
    any_accepted := false
    any_refused := false

    for row in table {
        buffer, errors := cts_measure_buffer_create(t, f.device, {
            size  = row.size,
            usage = row.usage,
        })
        cts_expect_outcome(t, errors, !row.valid,
            fmt.tprintf("usage 0x%x, size %d", cts_usage_bits(row.usage), row.size))
        if buffer != {} {
            gpu.buffer_release(buffer)
        }
        any_accepted = any_accepted || row.valid
        any_refused = any_refused || !row.valid
        checked += 1
    }

    cts_require_rows(t, checked, 6, "create_invalid_and_oom")
    cts_require_both(t, any_accepted, any_refused, "create_invalid_and_oom")
}
