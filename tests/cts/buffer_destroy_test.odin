package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/buffer/destroy.spec.ts`.

@(test)
cts_buffer_destroy_all_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for usage in cts_core_buffer_usages() {
        buffer := gpu.device_create_buffer(f.device, {size = 4, usage = usage})
        testing.expectf(t, buffer != {}, "a buffer of a core usage was refused (0x%x)",
            cts_usage_bits(usage))

        before := cts_errors()
        gpu.buffer_release(buffer)
        cts_expect_outcome(t, cts_errors() - before, false, "destroy a buffer")
        rows += 1
    }
    cts_require_rows(t, rows, 10, "all_usages")
}

@(test)
cts_buffer_destroy_twice :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := 0
    for usage in ([3]gpu.Buffer_Usages{
        {.Copy_Src},
        {.Map_Write, .Copy_Src},
        {.Map_Read, .Copy_Dst},
    }) {
        for mapped in ([2]bool{false, true}) {
            buffer := gpu.device_create_buffer(f.device, {
                size               = 4,
                usage              = usage,
                mapped_at_creation = mapped,
            })
            testing.expect(t, buffer != {}, "a destroy-twice buffer was refused")

            before := cts_errors()
            gpu.buffer_release(buffer)
            gpu.buffer_release(buffer)
            cts_expect_outcome(t, cts_errors() - before, false,
                "destroy a buffer twice")
            rows += 1
        }
    }
    cts_require_rows(t, rows, 6, "twice")
}

@(test)
cts_buffer_destroy_while_mapped :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Usage_Row :: struct {
        usage: gpu.Buffer_Usages,
        mode:  gpu.Map_Mode,
    }
    rows := [5]Usage_Row{
        {{.Copy_Src}, .Read},
        {{.Map_Write, .Copy_Src}, .Write},
        {{.Map_Read, .Copy_Dst}, .Read},
        {{.Map_Write, .Copy_Src}, .Write},
        {{.Map_Read, .Copy_Dst}, .Read},
    }
    count := 0
    for row, index in rows {
        for mapped_at_creation in 0 ..< 2 {
            if mapped_at_creation == 0 && index < 3 && row.mode == .Read {
                continue
            }
            for unmap_before in 0 ..< 2 {
                buffer := gpu.device_create_buffer(f.device, {
                    size               = 4,
                    usage              = row.usage,
                    mapped_at_creation = mapped_at_creation != 0,
                })
                testing.expect(t, buffer != {}, "a mapped-destroy buffer was refused")
                if mapped_at_creation != 0 && index >= 3 {
                    gpu.buffer_unmap(buffer)
                    gpu.buffer_map_sync(buffer, row.mode, 0, 0)
                } else if mapped_at_creation == 0 {
                    gpu.buffer_map_sync(buffer, row.mode, 0, 0)
                }
                if unmap_before != 0 {
                    gpu.buffer_unmap(buffer)
                }
                before := cts_errors()
                gpu.buffer_release(buffer)
                cts_expect_outcome(t, cts_errors() - before, false,
                    "destroy a buffer while mapped")
                count += 1
            }
        }
    }
    testing.expect(t, count > 0, "no mapped destroy rows ran")
}
