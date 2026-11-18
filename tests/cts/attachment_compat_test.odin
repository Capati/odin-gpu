package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/render_pass/attachment_compatibility.spec.ts`:
// a pass's attachments, a bundle's
// declaration and a pipeline's targets must agree on color formats, color count,
// sample count and depth presence/format.

cts_make_bundle :: proc(
    device: gpu.Device,
    color_formats: []gpu.Texture_Format,
    depth_stencil: ^gpu.Render_Bundle_Depth_Stencil,
    sample_count: u32,
) -> gpu.Render_Bundle {
    descriptor := gpu.Render_Bundle_Encoder_Descriptor {
        color_formats = color_formats,
        depth_stencil = depth_stencil,
        sample_count  = sample_count,
    }
    encoder := gpu.device_create_render_bundle_encoder(device, descriptor)
    bundle := gpu.render_bundle_encoder_finish(encoder)
    gpu.render_bundle_encoder_release(encoder)
    return bundle
}

cts_execute_bundles_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    colors: []gpu.Render_Pass_Color_Attachment,
    depth: ^gpu.Render_Pass_Depth_Stencil_Attachment,
    bundles: []gpu.Render_Bundle,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments        = colors,
        depth_stencil_attachment = depth,
    })
    gpu.render_pass_execute_bundles(pass, bundles)
    gpu.render_pass_end(pass)
    // A pass holds a reference on its encoder; without this release the encoder
    // never drops to zero, its command buffer is never cancelled, and the bundle
    // reference `execute_bundles` took is never dropped.
    gpu.render_pass_release(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

cts_pipeline_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    colors: []gpu.Render_Pass_Color_Attachment,
    depth: ^gpu.Render_Pass_Depth_Stencil_Attachment,
    pipeline: gpu.Render_Pipeline,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments        = colors,
        depth_stencil_attachment = depth,
    })
    gpu.render_pass_set_pipeline(pass, pipeline)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    gpu.render_pass_release(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

@(test)
cts_compat_bundle_color_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_rp_texture(f.device, .RGBA8_Uint)
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture)
    defer gpu.texture_view_release(view)

    matching_formats := [1]gpu.Texture_Format{.RGBA8_Uint}
    other_formats := [1]gpu.Texture_Format{.R16_Uint}
    matching := cts_make_bundle(f.device, matching_formats[:], nil, 1)
    other := cts_make_bundle(f.device, other_formats[:], nil, 1)
    defer gpu.render_bundle_release(matching)
    defer gpu.render_bundle_release(other)

    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
    errors := cts_execute_bundles_row(t, f, colors[:], nil, []gpu.Render_Bundle{matching})
    cts_expect_outcome(t, errors ? 1 : 0, false, "bundle color format matches")
    errors = cts_execute_bundles_row(t, f, colors[:], nil, []gpu.Render_Bundle{other})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle color format differs")
}

@(test)
cts_compat_bundle_color_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_rp_texture(f.device, .RGBA8_Uint)
    second := cts_rp_texture(f.device, .RGBA8_Uint)
    defer gpu.texture_release(texture)
    defer gpu.texture_release(second)
    view := cts_rp_view(texture)
    second_view := cts_rp_view(second)
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(second_view)

    one_format := [1]gpu.Texture_Format{.RGBA8_Uint}
    two_formats := [2]gpu.Texture_Format{.RGBA8_Uint, .RGBA8_Uint}
    bundle_one := cts_make_bundle(f.device, one_format[:], nil, 1)
    bundle_two := cts_make_bundle(f.device, two_formats[:], nil, 1)
    defer gpu.render_bundle_release(bundle_one)
    defer gpu.render_bundle_release(bundle_two)

    one_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
    two_colors := [2]gpu.Render_Pass_Color_Attachment{
        cts_rp_color(view), cts_rp_color(second_view),
    }

    errors := cts_execute_bundles_row(t, f, one_color[:], nil,
        []gpu.Render_Bundle{bundle_one})
    cts_expect_outcome(t, errors ? 1 : 0, false, "bundle and pass with one color")
    errors = cts_execute_bundles_row(t, f, one_color[:], nil,
        []gpu.Render_Bundle{bundle_two})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle two colors, pass one")
    errors = cts_execute_bundles_row(t, f, two_colors[:], nil,
        []gpu.Render_Bundle{bundle_one})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle one color, pass two")
}

@(test)
cts_compat_bundle_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    single := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1)
    multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    defer gpu.texture_release(single)
    defer gpu.texture_release(multi)
    single_view := cts_rp_view(single)
    multi_view := cts_rp_view(multi)
    defer gpu.texture_view_release(single_view)
    defer gpu.texture_view_release(multi_view)

    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
    bundle_single := cts_make_bundle(f.device, formats[:], nil, 1)
    bundle_multi := cts_make_bundle(f.device, formats[:], nil, 4)
    defer gpu.render_bundle_release(bundle_single)
    defer gpu.render_bundle_release(bundle_multi)

    single_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(single_view)}
    multi_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(multi_view)}

    errors := cts_execute_bundles_row(t, f, single_color[:], nil,
        []gpu.Render_Bundle{bundle_single})
    cts_expect_outcome(t, errors ? 1 : 0, false, "single bundle and single pass")
    errors = cts_execute_bundles_row(t, f, multi_color[:], nil,
        []gpu.Render_Bundle{bundle_single})
    cts_expect_outcome(t, errors ? 1 : 0, true, "single bundle and multi pass")
    errors = cts_execute_bundles_row(t, f, single_color[:], nil,
        []gpu.Render_Bundle{bundle_multi})
    cts_expect_outcome(t, errors ? 1 : 0, true, "multi bundle and single pass")
    errors = cts_execute_bundles_row(t, f, multi_color[:], nil,
        []gpu.Render_Bundle{bundle_multi})
    cts_expect_outcome(t, errors ? 1 : 0, false, "multi bundle and multi pass")
}

@(test)
cts_compat_bundle_depth_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)
    color_view := cts_rp_view(color)
    depth_view := cts_rp_view(depth)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)

    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
    matching := gpu.Render_Bundle_Depth_Stencil{depth_stencil_format = .Depth24Plus_Stencil8}
    other := gpu.Render_Bundle_Depth_Stencil{depth_stencil_format = .Depth32_Float}
    bundle_matching := cts_make_bundle(f.device, formats[:], &matching, 1)
    bundle_other := cts_make_bundle(f.device, formats[:], &other, 1)
    bundle_none := cts_make_bundle(f.device, formats[:], nil, 1)
    defer gpu.render_bundle_release(bundle_matching)
    defer gpu.render_bundle_release(bundle_other)
    defer gpu.render_bundle_release(bundle_none)

    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}
    depth_desc := cts_rp_depth(depth_view)

    errors := cts_execute_bundles_row(t, f, colors[:], &depth_desc,
        []gpu.Render_Bundle{bundle_matching})
    cts_expect_outcome(t, errors ? 1 : 0, false, "bundle depth format matches")
    errors = cts_execute_bundles_row(t, f, colors[:], &depth_desc,
        []gpu.Render_Bundle{bundle_other})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle depth format differs")
    errors = cts_execute_bundles_row(t, f, colors[:], &depth_desc,
        []gpu.Render_Bundle{bundle_none})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle without depth, pass with one")
    errors = cts_execute_bundles_row(t, f, colors[:], nil,
        []gpu.Render_Bundle{bundle_matching})
    cts_expect_outcome(t, errors ? 1 : 0, true, "bundle with depth, pass without one")
}

@(test)
cts_compat_pipeline_color_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_rp_texture(f.device, .RGBA8_Unorm)
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture)
    defer gpu.texture_view_release(view)
    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}

    matching_targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    other_targets := [1]gpu.Color_Target_State {
        {format = .R16_Uint, write_mask = gpu.COLOR_WRITES_ALL},
    }
    matching := cts_make_render_pipeline_full(f.device, matching_targets[:], nil, 1)
    other := cts_make_render_pipeline_full(f.device, other_targets[:], nil, 1)
    defer gpu.render_pipeline_release(matching)
    defer gpu.render_pipeline_release(other)

    errors := cts_pipeline_row(t, f, colors[:], nil, matching)
    cts_expect_outcome(t, errors ? 1 : 0, false, "pipeline color format matches")
    errors = cts_pipeline_row(t, f, colors[:], nil, other)
    cts_expect_outcome(t, errors ? 1 : 0, true, "pipeline color format differs")
}

@(test)
cts_compat_pipeline_color_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_rp_texture(f.device, .RGBA8_Uint)
    second := cts_rp_texture(f.device, .RGBA8_Uint)
    defer gpu.texture_release(texture)
    defer gpu.texture_release(second)
    view := cts_rp_view(texture)
    second_view := cts_rp_view(second)
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(second_view)

    one_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
    two_colors := [2]gpu.Render_Pass_Color_Attachment{
        cts_rp_color(view), cts_rp_color(second_view),
    }
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Uint, write_mask = gpu.COLOR_WRITES_ALL},
    }
    pipeline := cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
    defer gpu.render_pipeline_release(pipeline)

    errors := cts_pipeline_row(t, f, one_color[:], nil, pipeline)
    cts_expect_outcome(t, errors ? 1 : 0, false, "pipeline and pass with one color")
    errors = cts_pipeline_row(t, f, two_colors[:], nil, pipeline)
    cts_expect_outcome(t, errors ? 1 : 0, true, "one-target pipeline, two-color pass")
}

@(test)
cts_compat_pipeline_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    single := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1)
    multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    defer gpu.texture_release(single)
    defer gpu.texture_release(multi)
    single_view := cts_rp_view(single)
    multi_view := cts_rp_view(multi)
    defer gpu.texture_view_release(single_view)
    defer gpu.texture_view_release(multi_view)

    single_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(single_view)}
    multi_color := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(multi_view)}
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    pipeline_single := cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
    pipeline_multi := cts_make_render_pipeline_full(f.device, targets[:], nil, 4)
    defer gpu.render_pipeline_release(pipeline_single)
    defer gpu.render_pipeline_release(pipeline_multi)

    errors := cts_pipeline_row(t, f, single_color[:], nil, pipeline_single)
    cts_expect_outcome(t, errors ? 1 : 0, false, "single pipeline and single pass")
    errors = cts_pipeline_row(t, f, single_color[:], nil, pipeline_multi)
    cts_expect_outcome(t, errors ? 1 : 0, true, "multi pipeline and single pass")
    errors = cts_pipeline_row(t, f, multi_color[:], nil, pipeline_single)
    cts_expect_outcome(t, errors ? 1 : 0, true, "single pipeline and multi pass")
    errors = cts_pipeline_row(t, f, multi_color[:], nil, pipeline_multi)
    cts_expect_outcome(t, errors ? 1 : 0, false, "multi pipeline and multi pass")
}

@(test)
cts_compat_pipeline_depth_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)
    color_view := cts_rp_view(color)
    depth_view := cts_rp_view(depth)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)

    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}
    depth_desc := cts_rp_depth(depth_view)

    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    matching := gpu.Depth_Stencil_State {
        format              = .Depth24Plus_Stencil8,
        depth_compare       = .Always,
        depth_write_enabled = false,
    }
    other := gpu.Depth_Stencil_State {
        format              = .Depth32_Float,
        depth_compare       = .Always,
        depth_write_enabled = false,
    }
    pipeline_matching := cts_make_render_pipeline_full(f.device, targets[:], &matching, 1)
    pipeline_other := cts_make_render_pipeline_full(f.device, targets[:], &other, 1)
    pipeline_none := cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
    defer gpu.render_pipeline_release(pipeline_matching)
    defer gpu.render_pipeline_release(pipeline_other)
    defer gpu.render_pipeline_release(pipeline_none)

    errors := cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_matching)
    cts_expect_outcome(t, errors ? 1 : 0, false, "pipeline depth format matches")
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_other)
    cts_expect_outcome(t, errors ? 1 : 0, true, "pipeline depth format differs")
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_none)
    cts_expect_outcome(t, errors ? 1 : 0, true, "pipeline without depth, pass with one")
    errors = cts_pipeline_row(t, f, colors[:], nil, pipeline_matching)
    cts_expect_outcome(t, errors ? 1 : 0, true, "pipeline with depth, pass without one")
}

@(test)
cts_compat_pipeline_read_only_write_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)
    color_view := cts_rp_view(color)
    depth_view := cts_rp_view(depth)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)

    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    writing := gpu.Depth_Stencil_State {
        format = .Depth24Plus_Stencil8, depth_compare = .Always, depth_write_enabled = true,
    }
    testing := gpu.Depth_Stencil_State {
        format = .Depth24Plus_Stencil8, depth_compare = .Always, depth_write_enabled = false,
    }
    pipeline_writing := cts_make_render_pipeline_full(f.device, targets[:], &writing, 1)
    pipeline_testing := cts_make_render_pipeline_full(f.device, targets[:], &testing, 1)
    defer gpu.render_pipeline_release(pipeline_writing)
    defer gpu.render_pipeline_release(pipeline_testing)

    depth_desc := cts_rp_depth(depth_view)
    errors := cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_testing)
    cts_expect_outcome(t, errors ? 1 : 0, false, "depth-testing pipeline, writable depth")

    depth_desc = cts_rp_depth(depth_view)
    depth_desc.depth_read_only = true
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_writing)
    cts_expect_outcome(t, errors ? 1 : 0, true, "depth-writing pipeline, read-only depth")

    depth_desc = cts_rp_depth(depth_view)
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_writing)
    cts_expect_outcome(t, errors ? 1 : 0, false, "depth-writing pipeline, writable depth")

    zero_ops := gpu.Stencil_Face_State {
        compare = .Always, fail_op = .Zero, depth_fail_op = .Zero, pass_op = .Zero,
    }
    stencil_write := gpu.Depth_Stencil_State {
        format              = .Depth24Plus_Stencil8,
        depth_compare       = .Always,
        depth_write_enabled = false,
        stencil             = {front = zero_ops, back = zero_ops, read_mask = 0xff,
            write_mask = 0xff},
    }
    pipeline_stencil := cts_make_render_pipeline_full(f.device, targets[:], &stencil_write, 1)
    defer gpu.render_pipeline_release(pipeline_stencil)

    depth_desc = cts_rp_depth(depth_view)
    depth_desc.stencil_read_only = true
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_stencil)
    cts_expect_outcome(t, errors ? 1 : 0, true, "stencil-writing pipeline, read-only stencil")

    depth_desc = cts_rp_depth(depth_view)
    errors = cts_pipeline_row(t, f, colors[:], &depth_desc, pipeline_stencil)
    cts_expect_outcome(t, errors ? 1 : 0, false, "stencil-writing pipeline, writable stencil")
}

@(test)
cts_compat_bundle_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)

    color := cts_rp_texture(f.device, .RGBA8_Unorm)
    defer gpu.texture_release(color)
    color_view := cts_rp_view(color)
    defer gpu.texture_view_release(color_view)
    colors := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}

    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
    own_bundle := cts_make_bundle(f.device, formats[:], nil, 1)
    foreign_bundle := cts_make_bundle(other, formats[:], nil, 1)
    defer gpu.render_bundle_release(own_bundle)
    defer gpu.render_bundle_release(foreign_bundle)

    errors := cts_execute_bundles_row(t, f, colors[:], nil,
        []gpu.Render_Bundle{foreign_bundle})
    cts_expect_outcome(t, errors ? 1 : 0, true, "a bundle from another device")
    errors = cts_execute_bundles_row(t, f, colors[:], nil, []gpu.Render_Bundle{own_bundle})
    cts_expect_outcome(t, errors ? 1 : 0, false, "a bundle from this device")
}
