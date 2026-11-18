package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/state_tracking.spec.ts`:
// vertex-buffer bindings are pass state, so a
// pipeline may rely on slots bound before it, and bindings never cross passes.

cts_state_pipeline :: proc(
    device: gpu.Device,
    buffer_count: uint,
) -> gpu.Render_Pipeline {
    layouts := [2]gpu.Vertex_Buffer_Layout{}
    attributes := [2][1]gpu.Vertex_Attribute{}
    for i in 0 ..< buffer_count {
        attributes[i][0] = {
            format          = .Float32x3,
            offset          = 0,
            shader_location = u32(i),
        }
        layouts[i] = {
            array_stride = 12,
            step_mode    = .Vertex,
            attributes   = attributes[i][:],
        }
    }
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    return cts_make_render_pipeline_full(
        device, targets[:], nil, 1, .Triangle_List, .Undefined, layouts[:buffer_count])
}

cts_state_vertex_buffer :: proc(device: gpu.Device) -> gpu.Buffer {
    return gpu.device_create_buffer(device, {size = 256, usage = {.Vertex}})
}

@(test)
cts_render_state_vertex_inherit :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    pipeline_one := cts_state_pipeline(f.device, 1)
    pipeline_two := cts_state_pipeline(f.device, 2)
    testing.expect(t, pipeline_one != {} && pipeline_two != {},
        "failed to create the state pipelines")
    defer gpu.render_pipeline_release(pipeline_one)
    defer gpu.render_pipeline_release(pipeline_two)
    buffer_one := cts_state_vertex_buffer(f.device)
    buffer_two := cts_state_vertex_buffer(f.device)
    defer gpu.buffer_release(buffer_one)
    defer gpu.buffer_release(buffer_two)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_one)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    cts_expect_outcome(t, errors, true, "draw with the declared vertex slot unbound")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_two)
    gpu.render_pass_set_vertex_buffer(pass, 0, buffer_one)
    gpu.render_pass_set_vertex_buffer(pass, 1, buffer_two)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_set_pipeline(pass, pipeline_one)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    command_buffer = gpu.command_encoder_finish(encoder)
    errors = cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    cts_expect_outcome(t, errors, false, "draw after switching to a pipeline with fewer slots")
}

@(test)
cts_render_state_vertex_between_passes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    pipeline_one := cts_state_pipeline(f.device, 1)
    pipeline_two := cts_state_pipeline(f.device, 2)
    testing.expect(t, pipeline_one != {} && pipeline_two != {},
        "failed to create the state pipelines")
    defer gpu.render_pipeline_release(pipeline_one)
    defer gpu.render_pipeline_release(pipeline_two)
    buffer_one := cts_state_vertex_buffer(f.device)
    buffer_two := cts_state_vertex_buffer(f.device)
    defer gpu.buffer_release(buffer_one)
    defer gpu.buffer_release(buffer_two)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_two)
    gpu.render_pass_set_vertex_buffer(pass, 0, buffer_one)
    gpu.render_pass_set_vertex_buffer(pass, 1, buffer_two)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)

    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_one)
    gpu.render_pass_set_vertex_buffer(pass, 0, buffer_one)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    cts_expect_outcome(t, errors, false, "two passes binding their own slots")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_two)
    gpu.render_pass_set_vertex_buffer(pass, 0, buffer_one)
    gpu.render_pass_set_vertex_buffer(pass, 1, buffer_two)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)

    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments[:],
    })
    gpu.render_pass_set_pipeline(pass, pipeline_one)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    command_buffer = gpu.command_encoder_finish(encoder)
    errors = cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    cts_expect_outcome(t, errors, true, "second pass without the declared slot bound")
}
