package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/render_pass/resolve.spec.ts`:
// the rules a color attachment's resolve
// target must satisfy, collapsed to one row per boundary.

cts_resolve_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    attachments: []gpu.Render_Pass_Color_Attachment,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments,
    })
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

@(test)
cts_render_pass_resolve_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    attachment := gpu.Texture_Usages{.Render_Attachment, .Copy_Src}

    ms := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 4, attachment)
    single := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 1, attachment)
    mip_chain := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 2, 1, attachment)
    ms_small := cts_rp_texture(f.device, .RGBA8_Unorm, 2, 2, 1, 1, 4, attachment)
    layered := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 2, 1, 1, attachment)
    bgra_ms := cts_rp_texture(f.device, .BGRA8_Unorm, 8, 8, 1, 1, 4, attachment)
    bgra_target := cts_rp_texture(f.device, .BGRA8_Unorm, 8, 8, 1, 1, 1, attachment)
    srgb_ms := cts_rp_texture(f.device, .RGBA8_Unorm_Srgb, 8, 8, 1, 1, 4, attachment)
    bigger := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1, attachment)
    copy_only := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 1, {.Copy_Src})
    transient := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 1,
        {.Render_Attachment, .Transient_Attachment})
    other := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 4, attachment)
    other_target := cts_rp_texture(f.device, .RGBA8_Unorm, 8, 8, 1, 1, 1, attachment)
    defer gpu.texture_release(ms)
    defer gpu.texture_release(single)
    defer gpu.texture_release(mip_chain)
    defer gpu.texture_release(ms_small)
    defer gpu.texture_release(layered)
    defer gpu.texture_release(bgra_ms)
    defer gpu.texture_release(bgra_target)
    defer gpu.texture_release(srgb_ms)
    defer gpu.texture_release(bigger)
    defer gpu.texture_release(copy_only)
    defer gpu.texture_release(transient)
    defer gpu.texture_release(other)
    defer gpu.texture_release(other_target)

    ms_view := cts_rp_view(ms)
    single_view := cts_rp_view(single)
    ms_small_view := cts_rp_view(ms_small)
    mip1 := cts_rp_view(mip_chain, 1, 1, 0, 1)
    two_mips := cts_rp_view(mip_chain, 0, 2, 0, 1)
    layer1 := cts_rp_view(layered, 0, 1, 1, 1)
    two_layers := cts_rp_view(layered, 0, 1, 0, 2)
    bgra_ms_view := cts_rp_view(bgra_ms)
    bgra_target_view := cts_rp_view(bgra_target)
    srgb_ms_view := cts_rp_view(srgb_ms)
    bigger_view := cts_rp_view(bigger)
    copy_only_view := cts_rp_view(copy_only)
    transient_view := cts_rp_view(transient)
    other_view := cts_rp_view(other)
    other_target_view := cts_rp_view(other_target)
    defer gpu.texture_view_release(ms_view)
    defer gpu.texture_view_release(single_view)
    defer gpu.texture_view_release(ms_small_view)
    defer gpu.texture_view_release(mip1)
    defer gpu.texture_view_release(two_mips)
    defer gpu.texture_view_release(layer1)
    defer gpu.texture_view_release(two_layers)
    defer gpu.texture_view_release(bgra_ms_view)
    defer gpu.texture_view_release(bgra_target_view)
    defer gpu.texture_view_release(srgb_ms_view)
    defer gpu.texture_view_release(bigger_view)
    defer gpu.texture_view_release(copy_only_view)
    defer gpu.texture_view_release(transient_view)
    defer gpu.texture_view_release(other_view)
    defer gpu.texture_view_release(other_target_view)

    row :: proc(
        t: ^testing.T,
        f: CTS_Fixture,
        color: gpu.Texture_View,
        resolve: gpu.Texture_View,
        should_fail: bool,
        what: string,
    ) {
        attachment := cts_rp_color(color)
        attachment.resolve_target = resolve
        errors := cts_resolve_row(t, f, []gpu.Render_Pass_Color_Attachment{attachment})
        cts_expect_outcome(t, errors ? 1 : 0, should_fail, what)
    }

    row(t, f, ms_view, single_view, false, "multisampled attachment with a resolve target")
    {
        first := cts_rp_color(ms_view)
        first.resolve_target = single_view
        second := cts_rp_color(other_view)
        second.resolve_target = other_target_view
        errors := cts_resolve_row(t, f, []gpu.Render_Pass_Color_Attachment{first, second})
        cts_expect_outcome(t, errors ? 1 : 0, false, "two attachments, each resolving")
    }
    row(t, f, single_view, single_view, true, "single-sampled attachment with a resolve target")
    row(t, f, ms_view, ms_view, true, "multisampled resolve target")
    row(t, f, ms_view, copy_only_view, true, "resolve target without render usage")
    row(t, f, ms_view, transient_view, true, "resolve target with transient usage")
    row(t, f, ms_small_view, mip1, false, "resolve target at a matching non-zero mip")
    row(t, f, ms_small_view, two_mips, true, "resolve target of two mip levels")
    row(t, f, ms_view, layer1, false, "resolve target at a non-zero layer")
    row(t, f, ms_view, two_layers, true, "resolve target of two layers")
    row(t, f, bgra_ms_view, bgra_target_view, false, "matching bgra8unorm formats")
    row(t, f, bgra_ms_view, single_view, true, "bgra8unorm into rgba8unorm")
    row(t, f, srgb_ms_view, single_view, true, "rgba8unorm-srgb into rgba8unorm")
    row(t, f, ms_view, bigger_view, true, "resolve target of another size")
}
