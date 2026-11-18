package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/setIndexBuffer.spec.ts`:
// buffer state/usage/device, offset alignment
// to the index size, and the binding range, on both render encoder kinds.

cts_index_bind :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: uint,
    buffer: gpu.Buffer,
    format: gpu.Index_Format,
    offset, size: u64,
) -> bool {
    before := cts_errors()
    if kind == 1 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        gpu.render_bundle_encoder_set_index_buffer(encoder, buffer, format, offset, size)
        bundle := gpu.render_bundle_encoder_finish(encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
        gpu.render_bundle_encoder_release(encoder)
    } else {
        encoder := gpu.device_create_command_encoder(f.device)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Load, store = .Store}},
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        gpu.render_pass_set_index_buffer(pass, buffer, format, offset, size)
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    }
    return cts_errors() - before > 0
}

@(test)
cts_render_index_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for kind in 0 ..< 2 {
        for state in 0 ..< 3 {
            buffer: gpu.Buffer
            switch state {
            case 0:
                buffer = gpu.device_create_buffer(f.device, {size = 16, usage = {.Index}})
            case 1:
                buffer = {}
            case:
                buffer = gpu.device_create_buffer(f.device, {size = 16, usage = {.Index}})
                gpu.buffer_release(buffer)
            }
            errors := cts_index_bind(t, f, view, uint(kind), buffer, .Uint32, 0, gpu.WHOLE_SIZE)
            cts_expect_outcome(t, errors ? 1 : 0, state != 0, "index buffer state row")
            if state == 0 {
                gpu.buffer_release(buffer)
            }
        }
    }
}

@(test)
cts_render_index_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for kind in 0 ..< 2 {
        for mismatched in 0 ..< 2 {
            device := mismatched != 0 ? other : f.device
            buffer := gpu.device_create_buffer(device, {size = 16, usage = {.Index}})
            errors := cts_index_bind(t, f, view, uint(kind), buffer, .Uint32, 0, gpu.WHOLE_SIZE)
            cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0, "index buffer device row")
            gpu.buffer_release(buffer)
        }
    }
}

@(test)
cts_render_index_buffer_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        usage:    gpu.Buffer_Usages,
        accepted: bool,
    }
    rows := [3]Row{
        {{.Index}, true},
        {{.Copy_Dst}, false},
        {{.Copy_Dst, .Index}, true},
    }
    for kind in 0 ..< 2 {
        for row in rows {
            buffer := gpu.device_create_buffer(f.device, {size = 16, usage = row.usage})
            errors := cts_index_bind(t, f, view, uint(kind), buffer, .Uint32, 0, gpu.WHOLE_SIZE)
            cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "index buffer usage row")
            gpu.buffer_release(buffer)
        }
    }
}

@(test)
cts_render_index_buffer_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Index}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        format:   gpu.Index_Format,
        offset:   u64,
        accepted: bool,
    }
    rows := [6]Row{
        {.Uint16, 0, true},
        {.Uint16, 1, false},
        {.Uint16, 2, true},
        {.Uint32, 0, true},
        {.Uint32, 2, false},
        {.Uint32, 4, true},
    }
    for kind in 0 ..< 2 {
        for row in rows {
            errors := cts_index_bind(
                t, f, view, uint(kind), buffer, row.format, row.offset, gpu.WHOLE_SIZE)
            cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "index offset alignment row")
        }
    }
}

@(test)
cts_render_index_buffer_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Index}})
    defer gpu.buffer_release(buffer)

    Row :: struct {
        offset:   u64,
        size:     u64,
        has_size: bool,
        accepted: bool,
    }
    rows := [15]Row{
        {0, 0, true, true},
        {0, 1, true, true},
        {0, 4, true, true},
        {0, 5, true, true},
        {0, 256, true, true},
        {0, 260, true, false},
        {4, 256, true, false},
        {4, 252, true, true},
        {252, 4, true, true},
        {256, 1, true, false},
        {0, 0, false, true},
        {4, 0, false, true},
        {252, 0, false, true},
        {256, 0, false, true},
        {260, 0, false, false},
    }
    for kind in 0 ..< 2 {
        for row in rows {
            size := row.has_size ? row.size : gpu.WHOLE_SIZE
            errors := cts_index_bind(
                t, f, view, uint(kind), buffer, .Uint32, row.offset, size)
            cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "index range row")
        }
    }
}
