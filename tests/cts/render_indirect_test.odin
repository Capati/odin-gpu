package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/indirect_draw.spec.ts`:
// indirect argument buffer state, usage,
// device, 4-byte offset alignment and struct fit, on both encoder kinds.

cts_indirect_run :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    pipeline: gpu.Render_Pipeline,
    index_buffer: gpu.Buffer,
    indirect_buffer: gpu.Buffer,
    kind: uint,
    indexed: bool,
    offset: u64,
) -> bool {
    before := cts_errors()
    if kind == 1 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
        if indexed {
            gpu.render_bundle_encoder_set_index_buffer(
                encoder, index_buffer, .Uint32, 0, 16)
            gpu.render_bundle_encoder_draw_indexed_indirect(
                encoder, indirect_buffer, offset)
        } else {
            gpu.render_bundle_encoder_draw_indirect(encoder, indirect_buffer, offset)
        }
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
        gpu.render_pass_set_pipeline(pass, pipeline)
        if indexed {
            gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint32, 0, 16)
            gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, offset)
        } else {
            gpu.render_pass_draw_indirect(pass, indirect_buffer, offset)
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    }
    return cts_errors() - before > 0
}

cts_indirect_setup :: proc(f: CTS_Fixture) -> (
    gpu.Texture,
    gpu.Texture_View,
    gpu.Render_Pipeline,
    gpu.Buffer,
) {
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm)
    index_buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Index}})
    return texture, view, pipeline, index_buffer
}

@(test)
cts_indirect_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, pipeline, index_buffer := cts_indirect_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.render_pipeline_release(pipeline)
    defer gpu.buffer_release(index_buffer)

    for kind in 0 ..< 2 {
        for indexed in 0 ..< 2 {
            for state in 0 ..< 3 {
                buffer: gpu.Buffer
                switch state {
                case 0:
                    buffer = gpu.device_create_buffer(f.device, {
                        size = 256, usage = {.Indirect},
                    })
                case 1:
                    buffer = {}
                case:
                    buffer = gpu.device_create_buffer(f.device, {
                        size = 256, usage = {.Indirect},
                    })
                    gpu.buffer_release(buffer)
                }
                errors := cts_indirect_run(t, f, view, pipeline, index_buffer, buffer,
                    uint(kind), indexed != 0, 0)
                cts_expect_outcome(t, errors ? 1 : 0, state != 0, "indirect state row")
                if state == 0 {
                    gpu.buffer_release(buffer)
                }
            }
        }
    }
}

@(test)
cts_indirect_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)
    texture, view, pipeline, index_buffer := cts_indirect_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.render_pipeline_release(pipeline)
    defer gpu.buffer_release(index_buffer)

    for kind in 0 ..< 2 {
        for indexed in 0 ..< 2 {
            for mismatched in 0 ..< 2 {
                device := mismatched != 0 ? other : f.device
                buffer := gpu.device_create_buffer(device, {
                    size = 256, usage = {.Indirect},
                })
                errors := cts_indirect_run(t, f, view, pipeline, index_buffer, buffer,
                    uint(kind), indexed != 0, 0)
                cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
                    "indirect device row")
                gpu.buffer_release(buffer)
            }
        }
    }
}

@(test)
cts_indirect_buffer_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, pipeline, index_buffer := cts_indirect_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.render_pipeline_release(pipeline)
    defer gpu.buffer_release(index_buffer)

    Row :: struct {
        usage:    gpu.Buffer_Usages,
        accepted: bool,
    }
    rows := [3]Row{
        {{.Indirect}, true},
        {{.Copy_Dst}, false},
        {{.Copy_Dst, .Indirect}, true},
    }
    for kind in 0 ..< 2 {
        for indexed in 0 ..< 2 {
            for row in rows {
                buffer := gpu.device_create_buffer(f.device, {size = 256, usage = row.usage})
                errors := cts_indirect_run(t, f, view, pipeline, index_buffer, buffer,
                    uint(kind), indexed != 0, 0)
                cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "indirect usage row")
                gpu.buffer_release(buffer)
            }
        }
    }
}

@(test)
cts_indirect_buffer_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, pipeline, index_buffer := cts_indirect_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.render_pipeline_release(pipeline)
    defer gpu.buffer_release(index_buffer)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Indirect}})
    defer gpu.buffer_release(buffer)

    for kind in 0 ..< 2 {
        for indexed in 0 ..< 2 {
            for offset in ([3]u64{0, 2, 4}) {
                errors := cts_indirect_run(t, f, view, pipeline, index_buffer, buffer,
                    uint(kind), indexed != 0, offset)
                cts_expect_outcome(t, errors ? 1 : 0, offset % 4 != 0,
                    "indirect offset alignment row")
            }
        }
    }
}

@(test)
cts_indirect_buffer_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, pipeline, index_buffer := cts_indirect_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.render_pipeline_release(pipeline)
    defer gpu.buffer_release(index_buffer)

    Row :: struct {
        size, offset: u64,
    }
    rows := [12]Row{
        {0, 0}, {16, 0}, {17, 0}, {15, 0}, {12, 0}, {20, 4},
        {19, 4}, {20, 2}, {20, 3}, {20, 5}, {16, 16}, {16, 20},
    }
    for kind in 0 ..< 2 {
        for indexed in 0 ..< 2 {
            args_size := indexed != 0 ? u64(20) : u64(16)
            for row in rows {
                buffer := gpu.device_create_buffer(f.device, {
                    size = row.size, usage = {.Indirect},
                })
                accepted := row.offset % 4 == 0 && row.offset <= row.size &&
                    args_size <= row.size - row.offset
                errors := cts_indirect_run(t, f, view, pipeline, index_buffer, buffer,
                    uint(kind), indexed != 0, row.offset)
                cts_expect_outcome(t, errors ? 1 : 0, !accepted, "indirect bounds row")
                gpu.buffer_release(buffer)
            }
        }
    }
}
