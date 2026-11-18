package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/query_set/{create,destroy}.spec.ts`
//.

@(test)
cts_query_set_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    timestamp_device: gpu.Device
    if gpu.adapter_has_feature(f.adapter, .Timestamp_Query) {
        descriptor := gpu.Device_Descriptor{}
        descriptor.required_features = []gpu.Feature_Name{.Timestamp_Query}
        timestamp_device = cts_make_device(f.adapter, descriptor)
    }
    defer if timestamp_device != nil {
        gpu.device_release(timestamp_device)
    }

    counts := [3]u32{0, 4096, 4097}
    rows := 0
    any_accepted := false
    any_refused := false

    for timestamp in ([2]bool{false, true}) {
        if timestamp && timestamp_device == nil {
            continue
        }
        target := timestamp ? timestamp_device : f.device
        for count in counts {
            valid := count > 0 && count <= 4096

            before := cts_errors()
            set := gpu.device_create_query_set(target, {
                type  = timestamp ? .Timestamp : .Occlusion,
                count = count,
            })
            errors := cts_errors() - before
            cts_expect_outcome(t, errors, !valid,
                fmt.tprintf("%s count %d", timestamp ? "timestamp" : "occlusion", count))
            if set != {} {
                gpu.query_set_release(set)
            }

            any_accepted = any_accepted || valid
            any_refused = any_refused || !valid
            rows += 1
        }
    }

    cts_require_rows(t, rows, 3, "count")
    cts_require_both(t, any_accepted, any_refused, "count")
}

@(test)
cts_query_set_destroy_twice :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := gpu.device_create_query_set(f.device, {
        type  = .Occlusion,
        count = 1,
    })
    testing.expect(t, set != {}, "failed to create the query set")

    before := cts_errors()
    gpu.query_set_release(set)
    gpu.query_set_release(set)
    cts_expect_outcome(t, cts_errors() - before, false, "destroy a query set twice")
}

@(test)
cts_query_set_destroy_invalid :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    before := cts_errors()
    gpu.query_set_release({})
    cts_expect_outcome(t, cts_errors() - before, false, "destroy an invalid query set")
}
