package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/queue/destroyed/query_set.spec.ts`:
// a destroyed query set may not be named
// by a render/compute pass, timestamp write or resolve. The verdict covers the
// whole record-and-submit sequence, since a destroyed set may be refused while
// recording or at submit.

cts_qq_submit :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    command_buffer: gpu.Command_Buffer,
    before: int,
    should_fail: bool,
    what: string,
) {
    if command_buffer != {} {
        queue := gpu.device_get_queue(f.device)
        gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
        gpu.queue_release(queue)
        gpu.command_buffer_release(command_buffer)
    }
    cts_expect_outcome(t, cts_errors() - before, should_fail, what)
}

cts_qq_occlusion_pass :: proc(
    f: CTS_Fixture,
    view: gpu.Texture_View,
    set: gpu.Query_Set,
    use_query: bool,
) -> gpu.Command_Buffer {
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(view)},
        occlusion_query_set = set,
    })
    if use_query {
        gpu.render_pass_begin_occlusion_query(pass, 0)
        gpu.render_pass_end_occlusion_query(pass)
    }
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

cts_qq_occlusion_rows :: proc(t: ^testing.T, f: CTS_Fixture, use_query: bool) {
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for row in 0 ..< 2 {
        set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
        if row == 1 {
            gpu.query_set_destroy(set)
        }
        before := cts_errors()
        command_buffer := cts_qq_occlusion_pass(f, view, set, use_query)
        cts_qq_submit(t, f, command_buffer, before, row == 1, "query set in a pass")
        gpu.query_set_release(set)
    }
}

@(test)
cts_queue_destroyed_query_begin_occlusion :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_qq_occlusion_rows(t, f, true)
}

@(test)
cts_queue_destroyed_query_unused_occlusion :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_qq_occlusion_rows(t, f, false)
}

cts_qq_timestamp_pass :: proc(
    f: CTS_Fixture,
    view: gpu.Texture_View,
    set: gpu.Query_Set,
    render_pass: bool,
) -> gpu.Command_Buffer {
    writes := gpu.Render_Pass_Timestamp_Writes {
        query_set                     = set,
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = gpu.QUERY_SET_INDEX_UNDEFINED,
    }
    encoder := gpu.device_create_command_encoder(f.device)
    if render_pass {
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(view)},
            timestamp_writes = &writes,
        })
        gpu.render_pass_end(pass)
    } else {
        pass := gpu.command_encoder_begin_compute_pass(encoder, {timestamp_writes = &writes})
        gpu.compute_pass_end(pass)
    }
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

@(test)
cts_queue_destroyed_query_timestamps :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_feature_device(f, .Timestamp_Query)
    if !have {
        return
    }
    defer gpu.device_release(device)
    tf := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = device}
    texture, view := cts_attachment_texture(device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for render_pass in 0 ..< 2 {
        for row in 0 ..< 2 {
            set := gpu.device_create_query_set(device, {type = .Timestamp, count = 2})
            if row == 1 {
                gpu.query_set_destroy(set)
            }
            before := cts_errors()
            command_buffer := cts_qq_timestamp_pass(tf, view, set, render_pass != 0)
            cts_qq_submit(t, tf, command_buffer, before, row == 1, "timestamp pass")
            gpu.query_set_release(set)
        }
    }
}

@(test)
cts_queue_destroyed_query_resolve :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
        buffer := gpu.device_create_buffer(f.device, {
            size = 8, usage = {.Query_Resolve, .Copy_Src},
        })
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_resolve_query_set(encoder, set, 0, 1, buffer, 0)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.query_set_destroy(set)
        }
        cts_qq_submit(t, f, command_buffer, before, row == 1, "query set resolve")
        gpu.query_set_release(set)
        gpu.buffer_release(buffer)
    }
}
