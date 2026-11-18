package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/createRenderBundleEncoder.spec.ts`:
// attachment count, bytes-per-sample
// budget, "at least one attachment", renderable formats and depth/stencil
// read-only combinations.

cts_create_bundle_fixture :: proc() -> CTS_Fixture {
    return cts_make_fixture(gpu.Device_Descriptor{required_limits = gpu.DEFAULT_LIMITS})
}

cts_bundle_create_errors :: proc(
    device: gpu.Device,
    formats: []gpu.Texture_Format,
    depth_stencil: ^gpu.Render_Bundle_Depth_Stencil,
    sample_count: u32 = 1,
) -> int {
    descriptor := gpu.Render_Bundle_Encoder_Descriptor {
        color_formats = formats,
        depth_stencil = depth_stencil,
        sample_count  = sample_count,
    }
    before := cts_errors()
    encoder := gpu.device_create_render_bundle_encoder(device, descriptor)
    errors := cts_errors() - before
    if encoder != {} {
        gpu.render_bundle_encoder_release(encoder)
    }
    return errors
}

@(test)
cts_create_bundle_max_color_attachments :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    max_attachments := gpu.device_get_limits(f.device).max_color_attachments
    formats: [9]gpu.Texture_Format
    for i in 0 ..< len(formats) {
        formats[i] = .R8_Unorm
    }

    counts := [3]u32{1, max_attachments, max_attachments + 1}
    for count in counts {
        errors := cts_bundle_create_errors(f.device, formats[:count], nil)
        cts_expect_outcome(t, errors, count > max_attachments,
            "bundle color attachment count")
    }
}

@(test)
cts_create_bundle_sample_count :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
    rows := [5]u32{0, 1, 2, 3, 4}
    for count in rows {
        errors := cts_bundle_create_errors(f.device, formats[:], nil, count)
        accepted := count == 0 || count == 1 || count == 4
        cts_expect_outcome(t, errors, !accepted, "bundle sample count row")
    }
}

@(test)
cts_create_bundle_bytes_per_sample :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        format:   gpu.Texture_Format,
        count:    u32,
        accepted: bool,
    }
    rows := [6]Row{
        {.RGBA8_Unorm, 4, true},
        {.RGBA8_Unorm, 5, false},
        {.R8_Unorm, 8, true},
        {.R32_Float, 8, true},
        {.RGBA32_Float, 2, true},
        {.RGBA32_Float, 3, false},
    }
    for row in rows {
        formats: [8]gpu.Texture_Format
        for i in 0 ..< row.count {
            formats[i] = row.format
        }
        errors := cts_bundle_create_errors(f.device, formats[:row.count], nil)
        cts_expect_outcome(t, errors, !row.accepted, "bundle bytes-per-sample row")
    }
}

@(test)
cts_create_bundle_bytes_per_sample_unaligned :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    padded := [5]gpu.Texture_Format{
        .R8_Unorm, .R32_Float, .RGBA8_Unorm, .RGBA32_Float, .R8_Unorm,
    }
    compact := [5]gpu.Texture_Format{
        .R32_Float, .RGBA8_Unorm, .RGBA32_Float, .R8_Unorm, .R8_Unorm,
    }
    cts_expect_outcome(t, cts_bundle_create_errors(f.device, padded[:], nil), true,
        "r8unorm before r32float is padded over the budget")
    cts_expect_outcome(t, cts_bundle_create_errors(f.device, compact[:], nil), false,
        "r8unorm last fits the budget")
}

@(test)
cts_create_bundle_empty_colors :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_outcome(t, cts_bundle_create_errors(f.device, nil, nil), true,
        "no color and no depth attachment")

    depth := gpu.Render_Bundle_Depth_Stencil {
        depth_stencil_format = .Depth24Plus_Stencil8,
    }
    cts_expect_outcome(t, cts_bundle_create_errors(f.device, nil, &depth), false,
        "depth-only bundle")
}

@(test)
cts_create_bundle_format_rows :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        format:   gpu.Texture_Format,
        color:    bool,
        accepted: bool,
    }
    rows := [9]Row{
        {.RGBA8_Unorm, true, true},
        {.R8_Unorm, true, true},
        {.BC1RGBA_Unorm, true, false},
        {.Depth24Plus, true, false},
        {.Depth24Plus, false, true},
        {.Depth24Plus_Stencil8, false, true},
        {.Stencil8, false, true},
        {.RGBA8_Unorm, false, false},
        {.BC1RGBA_Unorm, false, false},
    }
    for row in rows {
        if row.color {
            formats := [1]gpu.Texture_Format{row.format}
            errors := cts_bundle_create_errors(f.device, formats[:], nil)
            cts_expect_outcome(t, errors, !row.accepted, "bundle color format row")
        } else {
            depth := gpu.Render_Bundle_Depth_Stencil {
                depth_stencil_format = row.format,
            }
            errors := cts_bundle_create_errors(f.device, nil, &depth)
            cts_expect_outcome(t, errors, !row.accepted, "bundle depth format row")
        }
    }
}

@(test)
cts_create_bundle_depth_read_only :: proc(t: ^testing.T) {
    f := cts_create_bundle_fixture()
    defer cts_destroy_fixture(f)

    formats := [3]gpu.Texture_Format{
        .Depth24Plus_Stencil8, .Depth32_Float, .Stencil8,
    }
    for format in formats {
        for depth_read_only in 0 ..< 2 {
            for stencil_read_only in 0 ..< 2 {
                depth := gpu.Render_Bundle_Depth_Stencil {
                    depth_stencil_format = format,
                    depth_read_only      = depth_read_only != 0,
                    stencil_read_only    = stencil_read_only != 0,
                }
                errors := cts_bundle_create_errors(f.device, nil, &depth)
                cts_expect_outcome(t, errors, false,
                    "bundle depth/stencil read-only combination")
            }
        }
    }
}
