package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/beginRenderPass.spec.ts`:
// every handle named by a render-pass
// descriptor must belong to the device the pass is begun on.

cts_attachment_texture :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    sample_count: u32,
) -> (gpu.Texture, gpu.Texture_View) {
    texture := gpu.device_create_texture(device, {
        usage           = {.Render_Attachment},
        dimension       = .D2,
        format          = format,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = sample_count,
    })
    return texture, gpu.texture_create_view(texture, {})
}

cts_try_render_pass :: proc(t: ^testing.T, f: CTS_Fixture, descriptor: gpu.Render_Pass_Descriptor) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_render_pass(encoder, descriptor)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before > 0
}

@(test)
cts_begin_render_pass_color_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    Row :: struct {
        view0, target0, view1, target1: bool,
    }
    rows := [4]Row{
        {},
        {target0 = true, target1 = true},
        {view0 = true, view1 = true},
        {target1 = true},
    }

    for row in rows {
        devices := [4]gpu.Device{f.device, f.device, f.device, f.device}
        if row.view0   { devices[0] = other }
        if row.target0 { devices[1] = other }
        if row.view1   { devices[2] = other }
        if row.target1 { devices[3] = other }

        view0_tex, view0 := cts_attachment_texture(devices[0], .RGBA8_Unorm, 4)
        target0_tex, target0 := cts_attachment_texture(devices[1], .RGBA8_Unorm, 1)
        view1_tex, view1 := cts_attachment_texture(devices[2], .RGBA8_Unorm, 4)
        target1_tex, target1 := cts_attachment_texture(devices[3], .RGBA8_Unorm, 1)

        attachments := [2]gpu.Render_Pass_Color_Attachment {
            {view = view0, resolve_target = target0, ops = {load = .Clear, store = .Store}},
            {view = view1, resolve_target = target1, ops = {load = .Clear, store = .Store}},
        }
        descriptor := gpu.Render_Pass_Descriptor{color_attachments = attachments[:]}
        mismatched := row.view0 || row.target0 || row.view1 || row.target1
        errors := cts_try_render_pass(t, f, descriptor)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched,
            "color attachment device mismatch")

        gpu.texture_view_release(view0)
        gpu.texture_view_release(target0)
        gpu.texture_view_release(view1)
        gpu.texture_view_release(target1)
        gpu.texture_release(view0_tex)
        gpu.texture_release(target0_tex)
        gpu.texture_release(view1_tex)
        gpu.texture_release(target1_tex)
    }
}

@(test)
cts_begin_render_pass_depth_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : f.device
        texture, view := cts_attachment_texture(device, .Depth24Plus_Stencil8, 1)
        attachment := gpu.Render_Pass_Depth_Stencil_Attachment {
            view        = view,
            depth_ops   = {load = .Clear, store = .Store},
            stencil_ops = {load = .Clear, store = .Store},
        }
        descriptor := gpu.Render_Pass_Descriptor {
            depth_stencil_attachment = &attachment,
        }
        errors := cts_try_render_pass(t, f, descriptor)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "depth/stencil attachment device mismatch")
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
    }
}

@(test)
cts_begin_render_pass_occlusion_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : f.device
        set := gpu.device_create_query_set(device, {type = .Occlusion, count = 1})
        testing.expect(t, set != {}, "failed to create the occlusion set")

        texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Clear, store = .Store}},
        }
        descriptor := gpu.Render_Pass_Descriptor {
            color_attachments   = attachments[:],
            occlusion_query_set = set,
        }
        errors := cts_try_render_pass(t, f, descriptor)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "occlusion query set device mismatch")
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
        gpu.query_set_release(set)
    }
}

@(test)
cts_begin_render_pass_timestamp_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    dev, have_feature := cts_feature_device(f, .Timestamp_Query)
    if !have_feature {
        return
    }
    defer gpu.device_release(dev)
    other, other_ok := cts_feature_device(f, .Timestamp_Query)
    defer gpu.device_release(other)
    if !other_ok {
        return
    }

    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : dev
        set := gpu.device_create_query_set(device, {type = .Timestamp, count = 1})
        testing.expect(t, set != {}, "failed to create the timestamp set")

        texture, view := cts_attachment_texture(dev, .RGBA8_Unorm, 1)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Load, store = .Store}},
        }
        writes := gpu.Render_Pass_Timestamp_Writes {
            query_set                     = set,
            beginning_of_pass_write_index = 0,
            end_of_pass_write_index       = gpu.QUERY_SET_INDEX_UNDEFINED,
        }
        descriptor := gpu.Render_Pass_Descriptor {
            color_attachments = attachments[:],
            timestamp_writes  = &writes,
        }
        errors := cts_try_render_pass(t, CTS_Fixture{instance = f.instance, adapter = f.adapter, device = dev}, descriptor)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "timestamp query set device mismatch")
        gpu.texture_view_release(view)
        gpu.texture_release(texture)
        gpu.query_set_release(set)
    }
}
