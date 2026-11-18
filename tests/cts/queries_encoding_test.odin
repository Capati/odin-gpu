package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS
// `api/validation/encoding/queries/{general,begin_end}.spec.ts` and
cts_query_attachment_texture :: proc(f: CTS_Fixture) -> gpu.Texture {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Render_Attachment},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 8, height = 8, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    assert(texture != {}, "failed to create the attachment texture")
    return texture
}

cts_begin_query_pass :: proc(
    encoder: gpu.Command_Encoder,
    view: gpu.Texture_View,
    set: gpu.Query_Set,
) -> gpu.Render_Pass {
    attachments := [1]gpu.Render_Pass_Color_Attachment{{
        view = view,
        ops  = {load = .Load, store = .Store},
    }}
    return gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments   = attachments[:],
        occlusion_query_set = set,
    })
}

cts_run_query_call :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    set: gpu.Query_Set,
    index: u32,
) -> bool {
    texture := cts_query_attachment_texture(f)
    view := gpu.texture_create_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := cts_begin_query_pass(encoder, view, set)
    gpu.render_pass_begin_occlusion_query(pass, index)
    gpu.render_pass_end_occlusion_query(pass)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_run_query_calls :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    set: gpu.Query_Set,
    calls: []int,
) -> bool {
    texture := cts_query_attachment_texture(f)
    view := gpu.texture_create_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := cts_begin_query_pass(encoder, view, set)
    for call in calls {
        if call == -1 {
            gpu.render_pass_end_occlusion_query(pass)
        } else {
            gpu.render_pass_begin_occlusion_query(pass, u32(call))
        }
    }
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_run_two_query_passes :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    set: gpu.Query_Set,
    same_pass: bool,
) -> bool {
    texture := cts_query_attachment_texture(f)
    view := gpu.texture_create_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    pass := cts_begin_query_pass(encoder, view, set)
    gpu.render_pass_begin_occlusion_query(pass, 0)
    gpu.render_pass_end_occlusion_query(pass)
    if same_pass {
        gpu.render_pass_begin_occlusion_query(pass, 0)
        gpu.render_pass_end_occlusion_query(pass)
    }
    gpu.render_pass_end(pass)

    if !same_pass {
        second := cts_begin_query_pass(encoder, view, set)
        gpu.render_pass_begin_occlusion_query(second, 0)
        gpu.render_pass_end_occlusion_query(second)
        gpu.render_pass_end(second)
    }

    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_query_encoding_same_slot_two_passes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 2})
    defer gpu.query_set_release(set)

    errors := cts_run_two_query_passes(t, f, set, false)
    cts_expect_outcome(t, errors ? 1 : 0, false,
        "the same slot in two disjoint passes")
    errors = cts_run_two_query_passes(t, f, set, true)
    cts_expect_outcome(t, errors ? 1 : 0, true,
        "the same slot twice in one pass")
}

@(test)
cts_query_encoding_type :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    errors := cts_run_query_call(t, f, {}, 0)
    cts_expect_outcome(t, errors ? 1 : 0, true, "a pass with no occlusion query set")

    occlusion := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
    defer gpu.query_set_release(occlusion)
    errors = cts_run_query_call(t, f, occlusion, 0)
    cts_expect_outcome(t, errors ? 1 : 0, false, "a pass over an OCCLUSION set")

    if gpu.adapter_has_feature(f.adapter, .Timestamp_Query) {
        descriptor := gpu.Device_Descriptor{}
        descriptor.required_features = []gpu.Feature_Name{.Timestamp_Query}
        timestamp_device := cts_make_device(f.adapter, descriptor)
        if timestamp_device != nil {
            defer gpu.device_release(timestamp_device)
            timestamp_fixture := CTS_Fixture {
                instance = f.instance,
                adapter  = f.adapter,
                device   = timestamp_device,
            }
            timestamp := gpu.device_create_query_set(
                timestamp_device, {type = .Timestamp, count = 1})
            defer gpu.query_set_release(timestamp)
            errors = cts_run_query_call(t, timestamp_fixture, timestamp, 0)
            cts_expect_outcome(t, errors ? 1 : 0, true, "a pass over a TIMESTAMP set")
        }
    }
}

@(test)
cts_query_encoding_invalid_set :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    valid := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
    defer gpu.query_set_release(valid)
    errors := cts_run_query_call(t, f, valid, 0)
    cts_expect_outcome(t, errors ? 1 : 0, false, "a pass over a live OCCLUSION set")

    errors = cts_run_query_call(t, f, {}, 0)
    cts_expect_outcome(t, errors ? 1 : 0, true,
        "a pass over a query set that was never created")
}

@(test)
cts_query_encoding_index :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 2})
    defer gpu.query_set_release(set)

    errors := cts_run_query_call(t, f, set, 0)
    cts_expect_outcome(t, errors ? 1 : 0, false, "query index 0 of a 2-query set")
    errors = cts_run_query_call(t, f, set, 2)
    cts_expect_outcome(t, errors ? 1 : 0, true, "query index 2 of a 2-query set")
}

@(test)
cts_query_encoding_begin_end_balance :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 2})
    defer gpu.query_set_release(set)

    Row :: struct {
        begin: u32,
        end:   u32,
    }
    rows := [5]Row{
        {0, 1},
        {1, 0},
        {1, 1},
        {1, 2},
        {2, 1},
    }

    any_accepted := false
    any_refused := false
    for row in rows {
        calls := make([dynamic]int, 0, int(row.begin + row.end), context.temp_allocator)
        for i in 0 ..< row.begin {
            append(&calls, int(i))
        }
        for _ in 0 ..< row.end {
            append(&calls, -1)
        }

        errors := cts_run_query_calls(t, f, set, calls[:])
        cts_expect_outcome(t, errors ? 1 : 0, row.begin != row.end,
            "occlusion query begin/end balance")
        any_accepted = any_accepted || row.begin == row.end
        any_refused = any_refused || row.begin != row.end
    }
    cts_require_both(t, any_accepted, any_refused, "occlusion_query,begin_end_balance")
}

@(test)
cts_query_encoding_invalid_nesting :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 2})
    defer gpu.query_set_release(set)

    errors := cts_run_query_calls(t, f, set, []int{0, -1, 1, -1})
    cts_expect_outcome(t, errors ? 1 : 0, false, "begin 0, end, begin 1, end")

    errors = cts_run_query_calls(t, f, set, []int{0, 0, -1, -1})
    cts_expect_outcome(t, errors ? 1 : 0, true, "nested begins on the same slot")

    errors = cts_run_query_calls(t, f, set, []int{0, 1, -1, -1})
    cts_expect_outcome(t, errors ? 1 : 0, true, "nested begins on different slots")
}
