package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `capability_checks/features/query_types.spec.ts`:
// // timestamp query sets and timestamp writes require the `Timestamp_Query`
// feature. Occlusion sets are always available.

cts_query_set_errors :: proc(device: gpu.Device, type: gpu.Query_Type) -> int {
    before := cts_errors()
    set := gpu.device_create_query_set(device, {type = type, count = 2})
    errors := cts_errors() - before
    if set != {} {
        gpu.query_set_release(set)
    }
    return errors
}

@(test)
cts_query_types_create_query_set :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_outcome(t, cts_query_set_errors(f.device, .Occlusion), false,
        "occlusion query set")
    cts_expect_outcome(t, cts_query_set_errors(f.device, .Timestamp), true,
        "timestamp query set without the feature")

    featured, have_feature := cts_feature_device(f, .Timestamp_Query)
    if !have_feature {
        return
    }
    defer gpu.device_release(featured)
    cts_expect_outcome(t, cts_query_set_errors(featured, .Occlusion), false,
        "occlusion query set with the timestamp feature")
    cts_expect_outcome(t, cts_query_set_errors(featured, .Timestamp), false,
        "timestamp query set with the feature")
}

cts_timestamp_compute_errors :: proc(device: gpu.Device, set: gpu.Query_Set) -> int {
    writes := gpu.Render_Pass_Timestamp_Writes {
        query_set                     = set,
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = 1,
    }
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(device)
    pass := gpu.command_encoder_begin_compute_pass(encoder, {
        timestamp_writes = &writes,
    })
    gpu.compute_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before
}

@(test)
cts_query_types_timestamp :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    for feature_enabled in 0 ..< 2 {
        device := f.device
        featured: gpu.Device
        if feature_enabled != 0 {
            have := false
            featured, have = cts_feature_device(f, .Timestamp_Query)
            if !have {
                continue
            }
            device = featured
        }
        defer if feature_enabled != 0 {
            gpu.device_release(featured)
        }

        type := feature_enabled != 0 ? gpu.Query_Type.Timestamp : .Occlusion
        set := gpu.device_create_query_set(device, {type = type, count = 2})
        testing.expect(t, set != {}, "failed to create the timestamp query set")
        if set == {} {
            continue
        }

        cts_expect_outcome(t, cts_timestamp_compute_errors(device, set),
            feature_enabled == 0, "compute pass timestamp writes")

        texture, view := cts_attachment_texture(device, .RGBA8_Unorm, 1)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Clear, store = .Discard}},
        }
        writes := gpu.Render_Pass_Timestamp_Writes {
            query_set                     = set,
            beginning_of_pass_write_index = 0,
            end_of_pass_write_index       = 1,
        }
        fixture := CTS_Fixture {
            instance = f.instance,
            adapter  = f.adapter,
            device   = device,
        }
        errors := cts_try_render_pass(t, fixture, {
            color_attachments = attachments[:],
            timestamp_writes  = &writes,
        })
        cts_expect_outcome(t, errors ? 1 : 0, feature_enabled == 0,
            "render pass timestamp writes")

        gpu.texture_view_release(view)
        gpu.texture_release(texture)
        gpu.query_set_release(set)
    }
}
