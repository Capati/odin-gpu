package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/buffer/mapping.spec.ts`.

cts_make_mapping_buffer :: proc(
    f: CTS_Fixture,
    size: u64,
    usage: gpu.Buffer_Usages,
) -> gpu.Buffer {
    buffer := gpu.device_create_buffer(f.device, {size = size, usage = usage})
    assert(buffer != {}, "failed to create the mapping buffer")
    return buffer
}

cts_make_mappable :: proc(f: CTS_Fixture, mode: gpu.Map_Mode, size: u64) -> gpu.Buffer {
    usage := mode == .Read ? gpu.Buffer_Usages{.Map_Read} : gpu.Buffer_Usages{.Map_Write}
    return cts_make_mapping_buffer(f, size, usage)
}

cts_map_measure :: proc(
    f: CTS_Fixture,
    buffer: gpu.Buffer,
    mode: gpu.Map_Mode,
    offset, size: u64,
) -> (
    bool,
    gpu.Future,
) {
    before := cts_errors()
    future := gpu.buffer_map_async(buffer, mode, uint(offset), uint(size), {})
    return cts_errors() > before, future
}

cts_map_ok :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    buffer: gpu.Buffer,
    mode: gpu.Map_Mode,
    offset, size: u64,
) {
    errors, future := cts_map_measure(f, buffer, mode, offset, size)
    testing.expect(t, !errors, "a valid map_async was refused")
    if errors {
        return
    }

    info := gpu.Future_Wait_Info{future = future}
    status := gpu.instance_wait_any(f.instance, []^gpu.Future_Wait_Info{&info})
    testing.expect(t, status == .Success, "the mapping future did not resolve")
    testing.expect(t, gpu.buffer_get_map_state(buffer) == .Mapped,
        "the mapping did not resolve")
}

cts_range_errors :: proc(
    t: ^testing.T,
    buffer: gpu.Buffer,
    offset, size: u64,
) -> bool {
    before := cts_errors()
    ptr := gpu.buffer_get_const_mapped_range(buffer, uint(offset), uint(size))
    errors := cts_errors() > before
    if !errors {
        testing.expect(t, ptr != nil, "a valid get_mapped_range came back empty")
    }
    return errors
}

cts_unmap_errors :: proc(t: ^testing.T, buffer: gpu.Buffer) -> bool {
    before := cts_errors()
    gpu.buffer_unmap(buffer)
    return cts_errors() > before
}

@(test)
cts_buffer_map_async_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    any_accepted := false
    any_refused := false
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        for usage in cts_core_buffer_usages() {
            buffer := cts_make_mapping_buffer(f, 16, usage)
            defer gpu.buffer_release(buffer)

            lacks := mode == .Read ? .Map_Read not_in usage : .Map_Write not_in usage
            errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
            cts_expect_outcome(t, errors ? 1 : 0, lacks,
                fmt.tprintf("map %v of usage 0x%x", mode, cts_usage_bits(usage)))
            any_accepted = any_accepted || !lacks
            any_refused = any_refused || lacks
            rows += 1
        }
    }
    cts_require_rows(t, rows, 20, "mapAsync,usage")
    cts_require_both(t, any_accepted, any_refused, "mapAsync,usage")
}

@(test)
cts_buffer_map_async_destroyed :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        gpu.buffer_release(buffer)
        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true, "map_async on a destroyed buffer")
        rows += 1

        buffer = cts_make_mappable(f, mode, 16)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        gpu.buffer_release(buffer)
        errors, _ = cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true,
            "map_async on a destroyed mapped buffer")
        rows += 1
    }
    cts_require_rows(t, rows, 4, "mapAsync,destroyed")
}

@(test)
cts_buffer_map_async_mapped_at_creation :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        usage := mode == .Read ? gpu.Buffer_Usages{.Map_Read} : gpu.Buffer_Usages{.Map_Write}
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = usage, mapped_at_creation = true})
        defer gpu.buffer_release(buffer)

        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true,
            "map_async on a buffer mapped at creation")
        gpu.buffer_unmap(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        gpu.buffer_unmap(buffer)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "mapAsync,state,mappedAtCreation")
}

@(test)
cts_buffer_map_async_state_mapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true, "map_async while mapped")
        gpu.buffer_unmap(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "mapAsync,state,mapped")
}

@(test)
cts_buffer_map_async_state_pending :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)

        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        testing.expect(t, !errors, "the first request was refused")
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Pending,
            "the request resolved early")

        errors, _ = cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true,
            "map_async while a mapping is pending")

        testing.expect(t, !cts_unmap_errors(t, buffer),
            "unmap of a pending mapping was refused")
        cts_map_ok(t, f, buffer, mode, 0, 0)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "mapAsync,state,mappingPending")
}

@(test)
cts_buffer_map_async_size_unspecified_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        buffer_size: u64,
        offset:      u64,
    }
    table := [8]Row{
        {0, 0},
        {0, 1},
        {0, 8},
        {16, 0},
        {16, 8},
        {16, 16},
        {16, 17},
        {16, 24},
    }

    checked := 0
    any_accepted := false
    any_refused := false
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        for row in table {
            buffer := cts_make_mappable(f, mode, row.buffer_size)
            defer gpu.buffer_release(buffer)

            valid := row.offset <= row.buffer_size
            errors, _ := cts_map_measure(f, buffer, mode, row.offset, 0)
            cts_expect_outcome(t, errors ? 1 : 0, !valid,
                fmt.tprintf("buffer %d, offset %d", row.buffer_size, row.offset))
            any_accepted = any_accepted || valid
            any_refused = any_refused || !valid
            checked += 1
        }
    }
    cts_require_rows(t, checked, 16, "mapAsync,sizeUnspecifiedOOB")
    cts_require_both(t, any_accepted, any_refused, "mapAsync,sizeUnspecifiedOOB")
}

@(test)
cts_buffer_map_async_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    offsets := [3]u64{0, 8, 4}
    sizes := [3]u64{0, 4, 2}
    rows := 0
    any_accepted := false
    any_refused := false

    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        for offset in offsets {
            for size in sizes {
                buffer := cts_make_mappable(f, mode, 16)
                defer gpu.buffer_release(buffer)

                valid := offset % 8 == 0 && size % 4 == 0
                errors, _ := cts_map_measure(f, buffer, mode, offset, size)
                cts_expect_outcome(t, errors ? 1 : 0, !valid,
                    fmt.tprintf("offset %d, size %d", offset, size))
                any_accepted = any_accepted || valid
                any_refused = any_refused || !valid
                rows += 1
            }
        }
    }
    cts_require_rows(t, rows, 18, "mapAsync,offsetAndSizeAlignment")
    cts_require_both(t, any_accepted, any_refused, "mapAsync,offsetAndSizeAlignment")
}

@(test)
cts_buffer_map_async_offset_and_size_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        buffer_size: u64,
        offset:      u64,
        size:        u64,
    }
    table := [17]Row{
        {0, 0, 0},
        {0, 0, 4},
        {0, 8, 0},
        {16, 0, 16},
        {16, 8, 16},
        {16, 16, 0},
        {16, 16, 4},
        {16, 8, 0},
        {16, 8, 8},
        {16, 8, 12},
        {1024, 0, 1024},
        {1024, 8, 1024},
        {1024, 1024, 0},
        {1024, 1024, 4},
        {1024, 512, 0},
        {1024, 512, 512},
        {1024, 512, 516},
    }

    checked := 0
    any_accepted := false
    any_refused := false
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        for row in table {
            buffer := cts_make_mappable(f, mode, row.buffer_size)
            defer gpu.buffer_release(buffer)

            valid := row.offset + row.size <= row.buffer_size
            errors, _ := cts_map_measure(f, buffer, mode, row.offset, row.size)
            cts_expect_outcome(t, errors ? 1 : 0, !valid,
                fmt.tprintf("buffer %d, %d..+%d", row.buffer_size, row.offset, row.size))
            any_accepted = any_accepted || valid
            any_refused = any_refused || !valid
            checked += 1
        }
    }
    cts_require_rows(t, checked, 34, "mapAsync,offsetAndSizeOOB")
    cts_require_both(t, any_accepted, any_refused, "mapAsync,offsetAndSizeOOB")
}

@(test)
cts_buffer_get_mapped_range_state_mapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)

        ptr: rawptr
        if mode == .Write {
            ptr = gpu.buffer_get_mapped_range(buffer, 0, 0)
        } else {
            ptr = gpu.buffer_get_const_mapped_range(buffer, 0, 0)
        }
        testing.expect(t, ptr != nil, "the whole mapped range was not handed out")

        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        cts_expect_outcome(t, errors ? 1 : 0, true, "a second map_async while mapped")

        gpu.buffer_unmap(buffer)
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Unmapped)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "getMappedRange,state,mapped")
}

@(test)
cts_buffer_get_mapped_range_state_mapped_at_creation :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usages := [4]gpu.Buffer_Usages{{.Copy_Dst}, {.Map_Read}, {.Map_Write}, {.Copy_Src}}
    rows := 0
    for usage in usages {
        for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
            buffer := gpu.device_create_buffer(
                f.device, {size = 16, usage = usage, mapped_at_creation = true})
            defer gpu.buffer_release(buffer)

            ptr := gpu.buffer_get_mapped_range(buffer, 0, 0)
            testing.expect(t, ptr != nil,
                "a mapped-at-creation buffer handed out no range")

            errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
            cts_expect_outcome(t, errors ? 1 : 0, true,
                "map_async of a buffer mapped at creation")
            gpu.buffer_unmap(buffer)
            rows += 1
        }
    }
    cts_require_rows(t, rows, 8, "getMappedRange,state,mappedAtCreation")
}

@(test)
cts_buffer_get_mapped_range_state_unmapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    {
        buffer := cts_make_mappable(f, .Read, 16)
        defer gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange of a buffer never mapped")
        rows += 1
    }
    {
        buffer := cts_make_mappable(f, .Read, 16)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, .Read, 0, 0)
        gpu.buffer_unmap(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange after unmap")
        rows += 1
    }
    {
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = {.Map_Read}, mapped_at_creation = true})
        defer gpu.buffer_release(buffer)
        gpu.buffer_unmap(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange after a creation mapping was unmapped")
        rows += 1
    }
    cts_require_rows(t, rows, 3, "getMappedRange,state,unmapped")
}

@(test)
cts_buffer_get_mapped_range_state_destroyed :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    {
        buffer := cts_make_mappable(f, .Read, 16)
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange of a destroyed unmapped buffer")
        rows += 1
    }
    {
        buffer := cts_make_mappable(f, .Read, 16)
        cts_map_ok(t, f, buffer, .Read, 0, 0)
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange of a destroyed mapped buffer")
        rows += 1
    }
    {
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = {.Map_Read}, mapped_at_creation = true})
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange of a destroyed creation-mapped buffer")
        rows += 1
    }
    cts_require_rows(t, rows, 3, "getMappedRange,state,destroyed")
}

@(test)
cts_buffer_get_mapped_range_state_pending :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)

        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        testing.expect(t, !errors, "the mapping request was refused")
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Pending)

        cts_expect_outcome(t, cts_range_errors(t, buffer, 0, 0) ? 1 : 0, true,
            "getMappedRange while the mapping is pending")

        _ = cts_unmap_errors(t, buffer)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "getMappedRange,state,mappingPending")
}

@(test)
cts_buffer_get_mapped_range_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    offsets := [3]u64{0, 8, 4}
    sizes := [3]u64{0, 4, 2}
    rows := 0
    any_accepted := false
    any_refused := false

    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 32)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        for offset in offsets {
            for size in sizes {
                valid := offset % 8 == 0 && size % 4 == 0
                errors := cts_range_errors(t, buffer, offset, size)
                cts_expect_outcome(t, errors ? 1 : 0, !valid,
                    fmt.tprintf("offset %d, size %d", offset, size))
                any_accepted = any_accepted || valid
                any_refused = any_refused || !valid
                rows += 1
            }
        }
        gpu.buffer_unmap(buffer)
    }
    cts_require_rows(t, rows, 18, "getMappedRange,offsetAndSizeAlignment,mapped")
    cts_require_both(t, any_accepted, any_refused,
        "getMappedRange,offsetAndSizeAlignment,mapped")
}

@(test)
cts_buffer_get_mapped_range_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    buffer_size := u64(80)
    Map :: struct {
        offset: u64,
        size:   u64,
    }
    maps := [4]Map{
        {0, buffer_size},
        {0, 64},
        {24, 40},
        {24, 0},
    }
    Request :: struct {
        offset: u64,
        size:   u64,
    }
    requests := [10]Request{
        {0, buffer_size},
        {0, buffer_size + 4},
        {8, buffer_size},
        {24, 40},
        {16, 40},
        {24, 44},
        {24, 0},
        {0, 0},
        {buffer_size, 0},
        {32, 40},
    }

    rows := 0
    any_accepted := false
    any_refused := false
    for mapping in maps {
        buffer := cts_make_mappable(f, .Read, buffer_size)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, .Read, mapping.offset, mapping.size)

        map_end :=
            mapping.size != 0 ? mapping.offset + mapping.size : buffer_size
        for request in requests {
            actual_size :=
                request.size != 0 ? request.size : buffer_size - request.offset
            valid :=
                request.offset >= mapping.offset &&
                request.offset <= buffer_size &&
                request.offset + actual_size <= map_end
            errors := cts_range_errors(t, buffer, request.offset, request.size)
            cts_expect_outcome(t, errors ? 1 : 0, !valid,
                fmt.tprintf("map [%d,+%d), range [%d,+%d)",
                    mapping.offset, mapping.size, request.offset, request.size))
            any_accepted = any_accepted || valid
            any_refused = any_refused || !valid
            rows += 1
        }
        gpu.buffer_unmap(buffer)
    }
    cts_require_rows(t, rows, 40, "getMappedRange,sizeAndOffsetOOB,mapped")
    cts_require_both(t, any_accepted, any_refused,
        "getMappedRange,sizeAndOffsetOOB,mapped")
}

@(test)
cts_buffer_unmap_state_unmapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    {
        buffer := cts_make_mapping_buffer(f, 16, {.Map_Read})
        defer gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap of a fresh buffer")
        rows += 1
    }
    {
        buffer := cts_make_mappable(f, .Read, 16)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, .Read, 0, 0)
        gpu.buffer_unmap(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap after a mapping was unmapped")
        rows += 1
    }
    {
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = {.Map_Read}, mapped_at_creation = true})
        defer gpu.buffer_release(buffer)
        gpu.buffer_unmap(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap after a creation mapping was unmapped")
        rows += 1
    }
    cts_require_rows(t, rows, 3, "unmap,state,unmapped")
}

@(test)
cts_buffer_unmap_state_destroyed :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    {
        buffer := cts_make_mapping_buffer(f, 16, {.Map_Read})
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap of a destroyed unmapped buffer")
        rows += 1
    }
    {
        buffer := cts_make_mappable(f, .Read, 16)
        cts_map_ok(t, f, buffer, .Read, 0, 0)
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap of a destroyed mapped buffer")
        rows += 1
    }
    {
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = {.Map_Read}, mapped_at_creation = true})
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap of a destroyed creation-mapped buffer")
        rows += 1
    }
    cts_require_rows(t, rows, 3, "unmap,state,destroyed")
}

@(test)
cts_buffer_unmap_state_mapped_at_creation :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usages := [3]gpu.Buffer_Usages{{.Map_Read}, {.Map_Write}, {.Copy_Dst}}
    rows := 0
    for usage in usages {
        buffer := gpu.device_create_buffer(
            f.device, {size = 16, usage = usage, mapped_at_creation = true})
        defer gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            fmt.tprintf("unmap of a creation mapping, usage 0x%x", cts_usage_bits(usage)))
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Unmapped)
        rows += 1
    }
    cts_require_rows(t, rows, 3, "unmap,state,mappedAtCreation")
}

@(test)
cts_buffer_unmap_state_mapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)
        cts_map_ok(t, f, buffer, mode, 0, 0)
        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap while mapped")
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Unmapped)
        rows += 1
    }
    cts_require_rows(t, rows, 2, "unmap,state,mapped")
}

@(test)
cts_buffer_unmap_state_pending :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for mode in ([2]gpu.Map_Mode{.Read, .Write}) {
        buffer := cts_make_mappable(f, mode, 16)
        defer gpu.buffer_release(buffer)

        errors, _ := cts_map_measure(f, buffer, mode, 0, 16)
        testing.expect(t, !errors, "the mapping request was refused")
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Pending)

        cts_expect_outcome(t, cts_unmap_errors(t, buffer) ? 1 : 0, false,
            "unmap of a pending mapping")
        testing.expect(t, gpu.buffer_get_map_state(buffer) == .Unmapped,
            "the abandoned request was applied")
        rows += 1
    }
    cts_require_rows(t, rows, 2, "unmap,state,mappingPending")
}
