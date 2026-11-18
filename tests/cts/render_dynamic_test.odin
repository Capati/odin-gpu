package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/dynamic_state.spec.ts`:
// viewport extent/depth-range bounds,
// scissor bounds, and the unconstrained blend-constant/stencil-reference setters.

cts_dynamic_target :: proc(f: CTS_Fixture, width: u32, height: u32) -> (gpu.Texture, gpu.Texture_View) {
    texture := cts_rp_texture(f.device, .RGBA8_Unorm, width, height)
    return texture, cts_rp_view(texture)
}

cts_run_viewport :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    x, y, width, height, min_depth, max_depth: f32,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Load, store = .Store}},
    }
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_viewport(pass, x, y, width, height, min_depth, max_depth)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

cts_run_scissor :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    x, y, width, height: u32,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Load, store = .Store}},
    }
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_scissor_rect(pass, x, y, width, height)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

@(test)
cts_dynamic_viewport_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        width, height: f32,
        accepted:      bool,
    }
    rows := [5]Row{
        {0, 0, true},
        {-1, 0, false},
        {0, -1, false},
        {1, -1, false},
        {-1, 1, false},
    }
    for row in rows {
        errors := cts_run_viewport(t, f, view, 0, 0, row.width, row.height, 0, 1)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "viewport extent row")
    }
}

@(test)
cts_dynamic_viewport_depth_range :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        min, max: f32,
        accepted: bool,
    }
    rows := [8]Row{
        {0, 1, true},
        {1, 1, true},
        {0.3, 0.7, true},
        {0.7, 0.7, true},
        {0.3, 0.3, true},
        {-0.1, 1, false},
        {0, 1.1, false},
        {0.5, 0.49999, false},
    }
    for row in rows {
        errors := cts_run_viewport(t, f, view, 0, 0, 1, 1, row.min, row.max)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "viewport depth row")
    }
}

@(test)
cts_dynamic_viewport_bounds :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    bound := f32(gpu.device_get_limits(f.device).max_texture_dimension_2d)
    Row :: struct {
        om, od, sd: f32,
        accepted:   bool,
    }
    rows := [11]Row{
        {0, 0, 0, true},
        {-1, 0, 0, true},
        {-2, 0, 0, true},
        {1, -1, 0, true},
        {0, -1, 0, true},
        {0, 1, 0, true},
        {1, 0, -1, true},
        {-2, -1, 0, false},
        {1, 0, 0, false},
        {1, 1, -1, false},
        {0, 0, 1, false},
    }
    for axis in 0 ..< 2 {
        for row in rows {
            offset := bound * row.om + row.od
            extent := bound + row.sd
            errors: bool
            if axis == 0 {
                errors = cts_run_viewport(t, f, view, offset, 0, extent, bound, 0, 1)
            } else {
                errors = cts_run_viewport(t, f, view, 0, offset, bound, extent, 0, 1)
            }
            cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "viewport bound row")
        }
    }
}

@(test)
cts_dynamic_viewport_exceeds_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    for size in ([2]u32{3, 8}) {
        texture, view := cts_dynamic_target(f, size, size)
        errors := cts_run_viewport(t, f, view, 0, 0, f32(size + 1), f32(size + 1), 0, 1)
        cts_expect_outcome(t, errors ? 1 : 0, false, "viewport larger than the attachment")
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
    }
}

@(test)
cts_dynamic_scissor_nonnegative :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        x, y, width, height: u32,
        accepted:            bool,
    }
    rows := [5]Row{
        {0, 0, 0, 0, true},
        {max(u32), 0, 0, 0, false},
        {0, max(u32), 0, 0, false},
        {0, 0, max(u32), 0, false},
        {0, 0, 0, max(u32), false},
    }
    for row in rows {
        errors := cts_run_scissor(t, f, view, row.x, row.y, row.width, row.height)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "scissor nonnegative row")
    }
}

@(test)
cts_dynamic_scissor_contained :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    sizes := [4][2]u32{{3, 5}, {5, 3}, {1024, 1}, {1, 1024}}
    offsets := [9][4]i32{
        {0, 0, 0, 0},
        {1, 0, -1, 0},
        {0, 1, 0, -1},
        {0, 0, -1, 0},
        {0, 0, 0, -1},
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1},
    }
    for size in sizes {
        texture, view := cts_dynamic_target(f, size[0], size[1])
        for offset in offsets {
            x := offset[0]
            y := offset[1]
            width := i32(size[0]) + offset[2]
            height := i32(size[1]) + offset[3]
            accepted := x >= 0 && y >= 0 && width >= 0 && height >= 0 &&
                u64(x) + u64(width) <= u64(size[0]) &&
                u64(y) + u64(height) <= u64(size[1])
            errors := cts_run_scissor(
                t, f, view, u32(x), u32(y), u32(width), u32(height))
            cts_expect_outcome(t, errors ? 1 : 0, !accepted, "scissor contained row")
        }
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
    }
}

@(test)
cts_dynamic_set_blend_constant :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Load, store = .Store}},
    }
    colors := [3]gpu.Color {
        {1, 1, 1, 1},
        {-1, -1, -1, -1},
        {9007199254740991, -9007199254740991, -0, 100000},
    }
    for color in colors {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        gpu.render_pass_set_blend_constant(pass, color)
        gpu.render_pass_end(pass)
        cb := gpu.command_encoder_finish(encoder)
        cts_expect_outcome(t, cts_errors() - before, false, "blend constant value")
        if cb != {} {
            gpu.command_buffer_release(cb)
        }
        gpu.command_encoder_release(encoder)
    }
}

@(test)
cts_dynamic_set_stencil_reference :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_dynamic_target(f, 16, 16)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Load, store = .Store}},
    }
    references := [4]u32{1, 0, 1000, max(u32)}
    for reference in references {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        gpu.render_pass_set_stencil_reference(pass, reference)
        gpu.render_pass_end(pass)
        cb := gpu.command_encoder_finish(encoder)
        cts_expect_outcome(t, cts_errors() - before, false, "stencil reference value")
        if cb != {} {
            gpu.command_buffer_release(cb)
        }
        gpu.command_encoder_release(encoder)
    }
}
