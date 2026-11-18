package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/texture/destroy.spec.ts`:
// destroying a
// texture twice is valid, and a destroyed color or depth/stencil attachment is
// refused. The CTS's `invalid_texture` row has no counterpart here because an
// invalid descriptor hands back no handle.

cts_td_texture :: proc(device: gpu.Device, format: gpu.Texture_Format) -> gpu.Texture {
    return gpu.device_create_texture(device, {
        usage           = {.Copy_Dst, .Render_Attachment},
        dimension       = .D2,
        format          = format,
        size            = {width = 16, height = 16, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
}

@(test)
cts_texture_destroy_base :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_td_texture(f.device, .RGBA8_Unorm)
    before := cts_errors()
    gpu.texture_release(texture)
    cts_expect_outcome(t, cts_errors() - before, false, "destroy a texture")
}

@(test)
cts_texture_destroy_twice :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_td_texture(f.device, .RGBA8_Unorm)
    before := cts_errors()
    gpu.texture_release(texture)
    gpu.texture_release(texture)
    cts_expect_outcome(t, cts_errors() - before, false, "destroy a texture twice")
}

@(test)
cts_texture_destroy_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    formats := [3]gpu.Texture_Format{.Depth24Plus_Stencil8, .Depth32_Float, .Stencil8}
    aspects := [3]gpu.Texture_Aspect{.All, .Depth_Only, .Stencil_Only}
    rows := 0
    accepted := false
    refused := false
    for format, aspect_index in formats {
        aspect := aspects[aspect_index]
        has_depth := format == .Depth24Plus_Stencil8 || format == .Depth32_Float
        has_stencil := format == .Depth24Plus_Stencil8 || format == .Stencil8
        for color_state in 0 ..< 3 {
            for depth_state in 0 ..< 3 {
                color := cts_td_texture(f.device, .RGBA8_Unorm)
                depth := cts_td_texture(f.device, format)
                color_view := gpu.texture_create_view(color)
                depth_view := gpu.texture_create_view(depth, {aspect = aspect})
                if color_state == 1 {
                    gpu.texture_destroy(color)
                }
                if depth_state == 1 {
                    gpu.texture_destroy(depth)
                }

                before := cts_errors()
                color_attachment := gpu.Render_Pass_Color_Attachment {
                    view = color_view, ops = {load = .Clear, store = .Store},
                }
                depth_attachment := gpu.Render_Pass_Depth_Stencil_Attachment {
                    view = depth_view,
                }
                if has_depth {
                    depth_attachment.depth_ops = {load = .Clear, store = .Discard}
                }
                if has_stencil {
                    depth_attachment.stencil_ops = {load = .Clear, store = .Discard}
                }
                encoder := gpu.device_create_command_encoder(f.device)
                pass := gpu.command_encoder_begin_render_pass(encoder, {
                    color_attachments      = []gpu.Render_Pass_Color_Attachment{color_attachment},
                    depth_stencil_attachment = &depth_attachment,
                })
                gpu.render_pass_end(pass)
                command_buffer := gpu.command_encoder_finish(encoder)
                gpu.command_encoder_release(encoder)
                if color_state == 2 {
                    gpu.texture_destroy(color)
                }
                if depth_state == 2 {
                    gpu.texture_destroy(depth)
                }

                queue := gpu.device_get_queue(f.device)
                if command_buffer != {} {
                    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
                    gpu.command_buffer_release(command_buffer)
                }
                gpu.queue_release(queue)
                errors := cts_errors() - before

                valid := color_state == 0 && depth_state == 0
                cts_expect_outcome(t, errors, !valid,
                    "destroyed color/depth attachment")
                accepted = accepted || valid
                refused = refused || !valid
                rows += 1

                gpu.texture_view_release(color_view)
                gpu.texture_view_release(depth_view)
                gpu.texture_release(color)
                gpu.texture_release(depth)
            }
        }
    }
    testing.expect_value(t, rows, 27)
    testing.expect(t, accepted, "the valid rows were all refused")
    testing.expect(t, refused, "the destroyed rows were all accepted")
}
