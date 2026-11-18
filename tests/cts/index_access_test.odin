package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/index_access.spec.ts`:
// `firstIndex + indexCount` against
// the bound index buffer, including zero-sized buffers and 32-bit overflow.

cts_run_indexed_draw :: proc(
    f: CTS_Fixture,
    view: gpu.Texture_View,
    pipeline: gpu.Render_Pipeline,
    index_buffer: gpu.Buffer,
    binding_size: u64,
    index_count, instance_count, first_index: u32,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Clear, store = .Store}},
    }
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline)
    gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint32, 0, binding_size)
    gpu.render_pass_draw_indexed(pass, index_count, instance_count, first_index, 0, 0)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

@(test)
cts_index_access_out_of_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_render_target(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm, .Triangle_Strip, .Uint32)
    testing.expect(t, pipeline != {}, "failed to create the strip pipeline")
    defer gpu.render_pipeline_release(pipeline)

    index_buffer := gpu.device_create_buffer(f.device, {
        size  = 24,
        usage = {.Index},
    })
    testing.expect(t, index_buffer != {}, "failed to create the index buffer")
    defer gpu.buffer_release(index_buffer)

    Row :: struct {
        index_count: u32,
        first_index: u32,
    }
    rows := [13]Row{
        {6, 0},
        {5, 1},
        {1, 5},
        {0, 6},
        {0, 7},
        {7, 0},
        {6, 1},
        {1, 6},
        {6, 10000},
        {10000, 0},
        {max(u32), max(u32)},
        {max(u32), 2},
        {2, max(u32)},
    }
    instance_counts := [2]u32{1, 10000}

    any_accepted := false
    any_refused := false
    for row in rows {
        accepted := u64(row.index_count) + u64(row.first_index) <= 6
        for instances in instance_counts {
            errors := cts_run_indexed_draw(
                f, view, pipeline, index_buffer, 24,
                row.index_count, instances, row.first_index)
            cts_expect_outcome(t, errors ? 1 : 0, !accepted, "drawIndexed bounds row")
            any_accepted = any_accepted || accepted
            any_refused = any_refused || !accepted
        }
    }
    cts_require_both(t, any_accepted, any_refused, "index_access")
}

@(test)
cts_index_access_zero_sized :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_render_target(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm, .Triangle_Strip, .Uint32)
    testing.expect(t, pipeline != {}, "failed to create the strip pipeline")
    defer gpu.render_pipeline_release(pipeline)

    index_buffer := gpu.device_create_buffer(f.device, {
        size  = 0,
        usage = {.Index},
    })
    testing.expect(t, index_buffer != {}, "failed to create the empty index buffer")
    defer gpu.buffer_release(index_buffer)

    rows := [4][2]u32{{3, 1}, {0, 1}, {3, 0}, {0, 0}}
    instance_counts := [2]u32{1, 10000}

    for row in rows {
        accepted := row[0] == 0 && row[1] == 0
        for instances in instance_counts {
            errors := cts_run_indexed_draw(
                f, view, pipeline, index_buffer, gpu.WHOLE_SIZE,
                row[0], instances, row[1])
            cts_expect_outcome(t, errors ? 1 : 0, !accepted,
                "drawIndexed on an empty index buffer")
        }
    }
}
