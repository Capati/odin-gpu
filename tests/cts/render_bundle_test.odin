package cts

// Core
import "core:testing"
import "core:fmt"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/render_bundle.spec.ts`:
// what `executeBundles` requires of each
// bundle -- its device, color formats/count/order, depth format, per-aspect
// read-only state and sample count, all against the executing pass.

cts_rb_depth_attachment :: proc(
    view: gpu.Texture_View,
    format: gpu.Texture_Format,
    depth_read_only: bool,
    stencil_read_only: bool,
) -> gpu.Render_Pass_Depth_Stencil_Attachment {
    has_depth := gpu.texture_format_has_depth_aspect(format)
    has_stencil := gpu.texture_format_has_stencil_aspect(format)
    attachment := gpu.Render_Pass_Depth_Stencil_Attachment {
        view                = view,
        depth_read_only     = has_depth && depth_read_only,
        stencil_read_only   = has_stencil && stencil_read_only,
    }
    if has_depth && !depth_read_only {
        attachment.depth_ops = {load = .Clear, store = .Store}
    }
    if has_stencil && !stencil_read_only {
        attachment.stencil_ops = {load = .Clear, store = .Store}
    }
    return attachment
}

cts_rb_run_color_formats :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    bundle_formats: []gpu.Texture_Format,
    pass_formats: []gpu.Texture_Format,
    compatible: bool,
) {
    bundle := cts_make_bundle(f.device, bundle_formats, nil, 1)
    defer gpu.render_bundle_release(bundle)

    textures: [8]gpu.Texture
    views: [8]gpu.Texture_View
    attachments: [8]gpu.Render_Pass_Color_Attachment
    defer for i in 0 ..< len(pass_formats) {
        gpu.texture_view_release(views[i])
        gpu.texture_release(textures[i])
    }
    for format, i in pass_formats {
        textures[i] = cts_rp_texture(f.device, format, 4, 4)
        views[i] = cts_rp_view(textures[i])
        attachments[i] = cts_rp_color(views[i])
    }

    errors := cts_execute_bundles_row(
        t, f, attachments[:len(pass_formats)], nil, []gpu.Render_Bundle{bundle})
    cts_expect_outcome(t, errors ? 1 : 0, !compatible, "bundle color formats row")
}

@(test)
cts_render_bundle_empty_list :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
    errors := cts_execute_bundles_row(t, f, attachments[:], nil, nil)
    cts_expect_outcome(t, errors ? 1 : 0, false, "executeBundles with an empty list")
}

@(test)
cts_render_bundle_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}

    for first_mismatched in 0 ..< 2 {
        for second_mismatched in 0 ..< 2 {
            first := cts_make_bundle(first_mismatched != 0 ? other : f.device, formats[:], nil, 1)
            second := cts_make_bundle(second_mismatched != 0 ? other : f.device, formats[:], nil, 1)
            errors := cts_execute_bundles_row(
                t, f, attachments[:], nil, []gpu.Render_Bundle{first, second})
            cts_expect_outcome(t, errors ? 1 : 0,
                first_mismatched != 0 || second_mismatched != 0,
                "executeBundles with bundles from this/another device")
            gpu.render_bundle_release(first)
            gpu.render_bundle_release(second)
        }
    }
}

@(test)
cts_render_bundle_color_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    two := [3]gpu.Texture_Format{.BGRA8_Unorm, .RG8_Unorm, .RGBA8_Unorm}
    other := [2]gpu.Texture_Format{.BGRA8_Unorm, .BGRA8_Unorm}
    swapped := [2]gpu.Texture_Format{.RG8_Unorm, .BGRA8_Unorm}

    cts_rb_run_color_formats(t, f, two[:2], two[:2], true)
    cts_rb_run_color_formats(t, f, two[:2], other[:], false)
    cts_rb_run_color_formats(t, f, two[:2], swapped[:], false)
    cts_rb_run_color_formats(t, f, two[:], two[:2], false)
    cts_rb_run_color_formats(t, f, two[:2], two[:], false)
}

cts_rb_run_depth_formats :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    bundle_format: gpu.Texture_Format,
    pass_format: gpu.Texture_Format,
    compatible: bool,
) {
    depth := gpu.Render_Bundle_Depth_Stencil{depth_stencil_format = bundle_format}
    bundle := cts_make_bundle(f.device, nil, &depth, 1)
    defer gpu.render_bundle_release(bundle)

    texture := cts_rp_texture(f.device, pass_format, 4, 4)
    view := cts_rp_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    attachment := cts_rb_depth_attachment(view, pass_format, false, false)
    errors := cts_execute_bundles_row(
        t, f, nil, &attachment, []gpu.Render_Bundle{bundle})
    cts_expect_outcome(t, errors ? 1 : 0, !compatible, "bundle depth format row")
}

@(test)
cts_render_bundle_depth_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_rb_run_depth_formats(t, f, .Depth24Plus, .Depth24Plus, true)
    cts_rb_run_depth_formats(t, f, .Depth24Plus, .Depth16_Unorm, false)
    cts_rb_run_depth_formats(t, f, .Depth24Plus, .Depth24Plus_Stencil8, false)
    cts_rb_run_depth_formats(t, f, .Stencil8, .Depth24Plus_Stencil8, false)
}

cts_rb_run_readonly :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    bundle_depth_ro: bool,
    bundle_stencil_ro: bool,
    pass_depth_ro: bool,
    pass_stencil_ro: bool,
) {
    depth := gpu.Render_Bundle_Depth_Stencil {
        depth_stencil_format = format,
        depth_read_only      = bundle_depth_ro,
        stencil_read_only    = bundle_stencil_ro,
    }
    bundle := cts_make_bundle(f.device, nil, &depth, 1)
    defer gpu.render_bundle_release(bundle)

    texture := cts_rp_texture(f.device, format, 4, 4)
    view := cts_rp_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    attachment := cts_rb_depth_attachment(view, format, pass_depth_ro, pass_stencil_ro)
    has_depth := gpu.texture_format_has_depth_aspect(format)
    has_stencil := gpu.texture_format_has_stencil_aspect(format)
    norm_bundle_depth := !has_depth || bundle_depth_ro
    norm_bundle_stencil := !has_stencil || bundle_stencil_ro
    norm_pass_depth := !has_depth || pass_depth_ro
    norm_pass_stencil := !has_stencil || pass_stencil_ro
    compatible := (!norm_pass_depth || norm_bundle_depth == norm_pass_depth) &&
        (!norm_pass_stencil || norm_bundle_stencil == norm_pass_stencil)

    errors := cts_execute_bundles_row(
        t, f, nil, &attachment, []gpu.Render_Bundle{bundle})
    cts_expect_outcome(t, errors ? 1 : 0, !compatible,
        fmt.tprintf("bundle read-only row %v bundle=%v/%v pass=%v/%v",
            format, bundle_depth_ro, bundle_stencil_ro, pass_depth_ro, pass_stencil_ro))
}

@(test)
cts_render_bundle_readonly :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    formats := [3]gpu.Texture_Format {
        .Depth24Plus_Stencil8, .Depth32_Float, .Stencil8,
    }
    for format in formats {
        for bundle_depth in 0 ..< 2 {
            for bundle_stencil in 0 ..< 2 {
                for pass_depth in 0 ..< 2 {
                    for pass_stencil in 0 ..< 2 {
                        cts_rb_run_readonly(t, f, format,
                            bundle_depth != 0, bundle_stencil != 0,
                            pass_depth != 0, pass_stencil != 0)
                    }
                }
            }
        }
    }
}

@(test)
cts_render_bundle_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        bundle, pass: u32,
    }
    rows := [4]Row{{1, 1}, {4, 4}, {4, 1}, {1, 4}}
    formats := [1]gpu.Texture_Format{.BGRA8_Unorm}

    for row in rows {
        bundle := cts_make_bundle(f.device, formats[:], nil, row.bundle)
        texture := cts_rp_texture(f.device, .BGRA8_Unorm, 4, 4, 1, 1, row.pass)
        view := cts_rp_view(texture)
        attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}
        errors := cts_execute_bundles_row(
            t, f, attachments[:], nil, []gpu.Render_Bundle{bundle})
        cts_expect_outcome(t, errors ? 1 : 0, row.bundle != row.pass,
            "bundle/pass sample count row")
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
        gpu.render_bundle_release(bundle)
    }
}
