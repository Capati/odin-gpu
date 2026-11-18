package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/beginComputePass.spec.ts`:
// timestamp writes must name a live
// timestamp set on this device, with distinct in-range slots.

cts_compute_feature_device :: proc(
    f: CTS_Fixture,
    features: []gpu.Feature_Name,
) -> (gpu.Device, bool) {
    for feature in features {
        if !gpu.adapter_has_feature(f.adapter, feature) {
            return nil, false
        }
    }
    descriptor := gpu.Device_Descriptor{}
    descriptor.required_features = features
    return cts_make_device(f.adapter, descriptor), true
}

cts_try_compute_pass :: proc(
    t: ^testing.T,
    device: gpu.Device,
    descriptor: gpu.Compute_Pass_Descriptor,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_compute_pass(encoder, descriptor)
    gpu.compute_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_begin_compute_pass_query_type :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    features := [2]gpu.Feature_Name{.Timestamp_Query, .Pipeline_Statistics_Query}
    device, have := cts_compute_feature_device(f, features[:])
    if !have {
        return
    }
    defer gpu.device_release(device)

    occlusion := gpu.device_create_query_set(device, {type = .Occlusion, count = 2})
    timestamp := gpu.device_create_query_set(device, {type = .Timestamp, count = 2})
    statistics := gpu.device_create_query_set(device, {
        type = .Pipeline_Statistics,
        count = 2,
        pipeline_statistics = []gpu.Pipeline_Statistics_Types{.Vertex_Shader_Invocations},
    })
    defer gpu.query_set_release(occlusion)
    defer gpu.query_set_release(timestamp)
    defer gpu.query_set_release(statistics)

    Row :: struct {
        set:      gpu.Query_Set,
        accepted: bool,
    }
    rows := [3]Row{{occlusion, false}, {timestamp, true}, {statistics, false}}
    for row in rows {
        writes := gpu.Render_Pass_Timestamp_Writes {
            query_set                     = row.set,
            beginning_of_pass_write_index = 0,
            end_of_pass_write_index       = 1,
        }
        errors := cts_try_compute_pass(t, device, {timestamp_writes = &writes})
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "timestamp query type row")
    }
}

@(test)
cts_begin_compute_pass_invalid_set :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_compute_feature_device(
        f, []gpu.Feature_Name{.Timestamp_Query})
    if !have {
        return
    }
    defer gpu.device_release(device)

    timestamp := gpu.device_create_query_set(device, {type = .Timestamp, count = 1})
    defer gpu.query_set_release(timestamp)

    valid := gpu.Render_Pass_Timestamp_Writes {
        query_set                     = timestamp,
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = gpu.QUERY_SET_INDEX_UNDEFINED,
    }
    errors := cts_try_compute_pass(t, device, {timestamp_writes = &valid})
    cts_expect_outcome(t, errors ? 1 : 0, false, "timestamp writes over a valid set")

    empty := gpu.Render_Pass_Timestamp_Writes {
        query_set                     = {},
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = gpu.QUERY_SET_INDEX_UNDEFINED,
    }
    errors = cts_try_compute_pass(t, device, {timestamp_writes = &empty})
    cts_expect_outcome(t, errors ? 1 : 0, true, "timestamp writes over a missing set")
}

@(test)
cts_begin_compute_pass_query_index :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_compute_feature_device(
        f, []gpu.Feature_Name{.Timestamp_Query})
    if !have {
        return
    }
    defer gpu.device_release(device)

    timestamp := gpu.device_create_query_set(device, {type = .Timestamp, count = 2})
    defer gpu.query_set_release(timestamp)

    values := [5]u32{0, 1, 2, 3, gpu.QUERY_SET_INDEX_UNDEFINED}
    for first in values {
        for last in values {
            valid := true
            if first != gpu.QUERY_SET_INDEX_UNDEFINED &&
                last != gpu.QUERY_SET_INDEX_UNDEFINED && first == last {
                valid = false
            }
            if first != gpu.QUERY_SET_INDEX_UNDEFINED && first >= 2 {
                valid = false
            }
            if last != gpu.QUERY_SET_INDEX_UNDEFINED && last >= 2 {
                valid = false
            }
            writes := gpu.Render_Pass_Timestamp_Writes {
                query_set                     = timestamp,
                beginning_of_pass_write_index = first,
                end_of_pass_write_index       = last,
            }
            errors := cts_try_compute_pass(t, device, {timestamp_writes = &writes})
            cts_expect_outcome(t, errors ? 1 : 0, !valid, "timestamp slot row")
        }
    }
}

@(test)
cts_begin_compute_pass_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    features := []gpu.Feature_Name{.Timestamp_Query}
    device, have := cts_compute_feature_device(f, features)
    if !have {
        return
    }
    defer gpu.device_release(device)
    other, other_ok := cts_compute_feature_device(f, features)
    if !other_ok {
        return
    }
    defer gpu.device_release(other)

    for mismatched in 0 ..< 2 {
        set := gpu.device_create_query_set(
            mismatched != 0 ? other : device, {type = .Timestamp, count = 1})
        writes := gpu.Render_Pass_Timestamp_Writes {
            query_set                     = set,
            beginning_of_pass_write_index = 0,
            end_of_pass_write_index       = gpu.QUERY_SET_INDEX_UNDEFINED,
        }
        errors := cts_try_compute_pass(t, device, {timestamp_writes = &writes})
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "timestamp set device mismatch")
        gpu.query_set_release(set)
    }
}
