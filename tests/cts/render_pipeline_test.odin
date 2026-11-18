package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/setPipeline.spec.ts`:
// both render encoder kinds refuse an
// empty pipeline and a pipeline that belongs to another device.

cts_render_target :: proc(f: CTS_Fixture) -> (gpu.Texture, gpu.Texture_View) {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Render_Attachment},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    view := gpu.texture_create_view(texture, {})
    return texture, view
}

cts_run_set_pipeline :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: uint,
    pipeline: gpu.Render_Pipeline,
) -> bool {
    before := cts_errors()
    if kind == 1 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        descriptor := gpu.Render_Bundle_Encoder_Descriptor {
            color_formats = formats[:],
            sample_count  = 1,
        }
        encoder := gpu.device_create_render_bundle_encoder(f.device, descriptor)
        testing.expect(t, encoder != {}, "failed to create the bundle encoder")
        gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
        bundle := gpu.render_bundle_encoder_finish(encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
        gpu.render_bundle_encoder_release(encoder)
    } else {
        encoder := gpu.device_create_command_encoder(f.device)
        testing.expect(t, encoder != {}, "failed to create the command encoder")
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Clear, store = .Store}},
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        gpu.render_pass_set_pipeline(pass, pipeline)
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
cts_render_pipeline_invalid :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_render_target(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm)
    testing.expect(t, pipeline != {}, "failed to create the render pipeline")
    defer gpu.render_pipeline_release(pipeline)

    any_accepted := false
    any_refused := false
    for kind in 0 ..< 2 {
        candidates := [2]gpu.Render_Pipeline{pipeline, {}}
        accepted := [2]bool{true, false}
        for candidate, i in candidates {
            errors := cts_run_set_pipeline(t, f, view, uint(kind), candidate)
            cts_expect_outcome(t, errors ? 1 : 0, !accepted[i],
                "setPipeline with a live/empty pipeline")
            any_accepted = any_accepted || accepted[i]
            any_refused = any_refused || !accepted[i]
        }
    }
    cts_require_both(t, any_accepted, any_refused, "invalid_pipeline")
}

@(test)
cts_render_pipeline_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_render_target(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    for kind in 0 ..< 2 {
        for mismatched in 0 ..< 2 {
            device := mismatched != 0 ? other : f.device
            pipeline := cts_make_render_pipeline(device, .RGBA8_Unorm)
            testing.expect(t, pipeline != {}, "failed to create the render pipeline")
            errors := cts_run_set_pipeline(t, f, view, uint(kind), pipeline)
            cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
                "setPipeline with this/another device's pipeline")
            gpu.render_pipeline_release(pipeline)
        }
    }
}
