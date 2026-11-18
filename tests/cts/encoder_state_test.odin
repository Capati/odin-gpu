package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/encoder_state.spec.ts`:
// a refused begin returns an invalid pass whose
// end poisons the encoder, ending a pass out of order reports, an ended pass
// ended twice reports without poisoning the encoder, and a valid pass ending
// with an unpopped debug group poisons it.

CTS_ES_Pass :: struct {
    compute: gpu.Compute_Pass,
    render:  gpu.Render_Pass,
    is_compute: bool,
}

cts_es_begin :: proc(
    encoder: gpu.Command_Encoder,
    view: gpu.Texture_View,
    is_compute: bool,
) -> CTS_ES_Pass {
    if is_compute {
        return {compute = gpu.command_encoder_begin_compute_pass(encoder), is_compute = true}
    }
    return {
        render = gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{
                {view = view, ops = {load = .Load, store = .Store}},
            },
        }),
    }
}

cts_es_end :: proc(pass: CTS_ES_Pass) {
    if pass.is_compute {
        gpu.compute_pass_end(pass.compute)
    } else {
        gpu.render_pass_end(pass.render)
    }
}

cts_es_pop :: proc(pass: CTS_ES_Pass) {
    if pass.is_compute {
        gpu.compute_pass_pop_debug_group(pass.compute)
    } else {
        gpu.render_pass_pop_debug_group(pass.render)
    }
}

@(test)
cts_encoder_state_pass_end_invalid_order :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)

    Ends :: struct {end0, end1, end1_first: bool}
    ends := [5]Ends{
        {}, {end0 = true}, {end1 = true}, {end0 = true, end1 = true},
        {end0 = true, end1 = true, end1_first = true},
    }
    for pass0 in 0 ..< 2 {
        for pass1 in 0 ..< 2 {
            for first_ended in 0 ..< 2 {
                for end_row in ends {
                    encoder := gpu.device_create_command_encoder(f.device)
                    first := cts_es_begin(encoder, view, pass0 != 0)
                    if first_ended != 0 {
                        cts_es_end(first)
                    }
                    before := cts_errors()
                    second := cts_es_begin(encoder, view, pass1 != 0)
                    cts_expect_outcome(t, cts_errors() - before, first_ended == 0,
                        "second begin")
                    if end_row.end0 && end_row.end1 && end_row.end1_first {
                        before = cts_errors()
                        cts_es_end(second)
                        cts_expect_outcome(t, cts_errors() - before, first_ended == 0,
                            "ending the second pass first")
                        before = cts_errors()
                        cts_es_end(first)
                        cts_expect_outcome(t, cts_errors() - before, first_ended != 0,
                            "ending the first pass second")
                    } else {
                        if end_row.end0 {
                            before = cts_errors()
                            cts_es_end(first)
                            cts_expect_outcome(t, cts_errors() - before, first_ended != 0,
                                "ending the first pass")
                        }
                        if end_row.end1 {
                            before = cts_errors()
                            cts_es_end(second)
                            cts_expect_outcome(t, cts_errors() - before, first_ended == 0,
                                "ending the second pass")
                        }
                    }
                    valid_finish := first_ended != 0 && end_row.end1
                    before = cts_errors()
                    command_buffer := gpu.command_encoder_finish(encoder)
                    cts_expect_outcome(t, cts_errors() - before, !valid_finish, "finish")
                    if command_buffer != {} {
                        gpu.command_buffer_release(command_buffer)
                    }
                    gpu.command_encoder_release(encoder)
                }
            }
        }
    }
}

@(test)
cts_encoder_state_call_after_finish :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)

    for call in 0 ..< 5 {
        for pre in 0 ..< 3 {
            for finished in 0 ..< 2 {
                encoder := gpu.device_create_command_encoder(f.device)
                if pre != 0 {
                    prepass := cts_es_begin(encoder, view, pre == 1)
                    cts_es_end(prepass)
                }
                first: gpu.Command_Buffer
                if finished != 0 {
                    first = gpu.command_encoder_finish(encoder)
                }
                switch call {
                case 0:
                    before := cts_errors()
                    pass := gpu.command_encoder_begin_compute_pass(encoder)
                    cts_expect_outcome(t, cts_errors() - before, finished != 0, "begin")
                    before = cts_errors()
                    gpu.compute_pass_end(pass)
                    cts_expect_outcome(t, cts_errors() - before, finished != 0, "end")
                case 1:
                    before := cts_errors()
                    pass := gpu.command_encoder_begin_render_pass(encoder, {
                        color_attachments = []gpu.Render_Pass_Color_Attachment{
                            {view = view, ops = {load = .Load, store = .Store}},
                        },
                    })
                    cts_expect_outcome(t, cts_errors() - before, finished != 0, "begin")
                    before = cts_errors()
                    gpu.render_pass_end(pass)
                    cts_expect_outcome(t, cts_errors() - before, finished != 0, "end")
                case 2, 3:
                    before := cts_errors()
                    second := gpu.command_encoder_finish(encoder)
                    cts_expect_outcome(t, cts_errors() - before, finished != 0,
                        "second finish")
                    if second != {} {
                        gpu.command_buffer_release(second)
                    }
                case:
                    before := cts_errors()
                    gpu.command_encoder_insert_debug_marker(encoder, "")
                    cts_expect_outcome(t, cts_errors() - before, finished != 0, "marker")
                }
                if first != {} {
                    queue := gpu.device_get_queue(f.device)
                    gpu.queue_submit(queue, []gpu.Command_Buffer{first})
                    gpu.queue_release(queue)
                    gpu.command_buffer_release(first)
                }
                if finished == 0 && call != 2 && call != 3 {
                    before := cts_errors()
                    cb := gpu.command_encoder_finish(encoder)
                    cts_expect_outcome(t, cts_errors() - before, false, "trailing finish")
                    if cb != {} {
                        gpu.command_buffer_release(cb)
                    }
                }
                gpu.command_encoder_release(encoder)
            }
        }
    }
}

@(test)
cts_encoder_state_pass_end_none :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    for is_compute in 0 ..< 2 {
        for end_count in 0 ..< 2 {
            encoder := gpu.device_create_command_encoder(f.device)
            pass := cts_es_begin(encoder, view, is_compute != 0)
            for _ in 0 ..< end_count {
                cts_es_end(pass)
            }
            before := cts_errors()
            cb := gpu.command_encoder_finish(encoder)
            cts_expect_outcome(t, cts_errors() - before, end_count == 0, "finish")
            if cb != {} {
                gpu.command_buffer_release(cb)
            }
            gpu.command_encoder_release(encoder)
        }
    }
}

@(test)
cts_encoder_state_pass_end_twice :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    for is_compute in 0 ..< 2 {
        for end_twice in 0 ..< 2 {
            for another in 0 ..< 3 {
                if end_twice == 0 && another != 0 {
                    continue
                }
                encoder := gpu.device_create_command_encoder(f.device)
                pass := cts_es_begin(encoder, view, is_compute != 0)
                cts_es_end(pass)
                if another != 0 {
                    second := cts_es_begin(encoder, view, is_compute != 0)
                    before := cts_errors()
                    cts_es_end(pass)
                    cts_expect_outcome(t, cts_errors() - before, true,
                        "ending the ended pass inside another pass")
                    cts_es_end(second)
                } else if end_twice != 0 {
                    before := cts_errors()
                    cts_es_end(pass)
                    cts_expect_outcome(t, cts_errors() - before, true,
                        "ending the pass twice")
                }
                before := cts_errors()
                cb := gpu.command_encoder_finish(encoder)
                cts_expect_outcome(t, cts_errors() - before, false, "finish")
                if cb != {} {
                    gpu.command_buffer_release(cb)
                }
                gpu.command_encoder_release(encoder)
            }
        }
    }
}

@(test)
cts_encoder_state_invalid_render_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for end_twice in 0 ..< 2 {
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = nil,
        })
        gpu.render_pass_end(pass)
        if end_twice != 0 {
            before := cts_errors()
            gpu.render_pass_end(pass)
            cts_expect_outcome(t, cts_errors() - before, true, "second end")
        }
        before := cts_errors()
        cb := gpu.command_encoder_finish(encoder)
        cts_expect_outcome(t, cts_errors() - before, true, "finish")
        if cb != {} {
            gpu.command_buffer_release(cb)
        }
        gpu.command_encoder_release(encoder)
    }
}

@(test)
cts_encoder_state_pass_begin_invalid_encoder :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    for pass0 in 0 ..< 2 {
        for pass1 in 0 ..< 2 {
            for invalid in 0 ..< 2 {
                encoder := gpu.device_create_command_encoder(f.device)
                first := cts_es_begin(encoder, view, pass0 != 0)
                if invalid != 0 {
                    cts_es_pop(first)
                }
                cts_es_end(first)
                second := cts_es_begin(encoder, view, pass1 != 0)
                cts_es_end(second)
                before := cts_errors()
                cb := gpu.command_encoder_finish(encoder)
                cts_expect_outcome(t, cts_errors() - before, invalid != 0, "finish")
                if cb != {} {
                    gpu.command_buffer_release(cb)
                }
                gpu.command_encoder_release(encoder)
            }
        }
    }
}
