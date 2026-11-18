package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/encoder_open_state.spec.ts`:
// commands issued on a finished
// encoder or an ended pass are refused, while the same commands on an open
// encoder or pass are accepted.

CTS_OPEN_CTX :: struct {
    target:                      gpu.Texture,
    copy_src:                    gpu.Texture,
    copy_dst:                    gpu.Texture,
    view:                        gpu.Texture_View,
    uniform:                     gpu.Buffer,
    resolve:                     gpu.Buffer,
    vertex:                      gpu.Buffer,
    index:                       gpu.Buffer,
    indirect:                    gpu.Buffer,
    storage:                     gpu.Buffer,
    render_pipeline:             gpu.Render_Pipeline,
    compute_pipeline:            gpu.Compute_Pipeline,
    occlusion:                   gpu.Query_Set,
    render_layout:               gpu.Bind_Group_Layout,
    compute_layout:              gpu.Bind_Group_Layout,
    render_group:                gpu.Bind_Group,
    compute_group:               gpu.Bind_Group,
}

cts_open_texture :: proc(device: gpu.Device, usage: gpu.Texture_Usages) -> gpu.Texture {
    return gpu.device_create_texture(device, {
        usage           = usage,
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 1, height = 1, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
}

cts_open_ctx :: proc(f: CTS_Fixture) -> CTS_OPEN_CTX {
    ctx: CTS_OPEN_CTX
    ctx.target = cts_open_texture(f.device, {.Render_Attachment})
    ctx.view = gpu.texture_create_view(ctx.target)
    ctx.copy_src = cts_open_texture(f.device, {.Copy_Src})
    ctx.copy_dst = cts_open_texture(f.device, {.Copy_Dst})
    ctx.uniform = gpu.device_create_buffer(f.device, {
        size = 64, usage = {.Uniform, .Copy_Src, .Copy_Dst},
    })
    ctx.resolve = gpu.device_create_buffer(f.device, {
        size = 16, usage = {.Query_Resolve, .Copy_Src, .Copy_Dst},
    })
    ctx.vertex = gpu.device_create_buffer(f.device, {
        size = 64, usage = {.Vertex, .Copy_Dst},
    })
    ctx.index = gpu.device_create_buffer(f.device, {
        size = 16, usage = {.Index, .Copy_Dst},
    })
    ctx.indirect = gpu.device_create_buffer(f.device, {
        size = 32, usage = {.Indirect, .Copy_Dst},
    })
    ctx.storage = gpu.device_create_buffer(f.device, {
        size = 16, usage = {.Storage},
    })
    ctx.render_pipeline = cts_state_pipeline(f.device, 1)
    ctx.compute_pipeline = cts_make_compute_pipeline(f.device)
    ctx.occlusion = gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
    ctx.render_layout = cts_layout_create(f.device,
        []gpu.Bind_Group_Layout_Entry{
            cts_layout_buffer(0, {.Vertex, .Fragment}, .Uniform),
        })
    ctx.render_group = gpu.device_create_bind_group(f.device, {
        layout = ctx.render_layout,
        entries = []gpu.Bind_Group_Entry{
            cts_bg_buffer_entry(ctx.uniform, 0, gpu.WHOLE_SIZE),
        },
    })
    ctx.compute_layout = cts_layout_create(f.device,
        []gpu.Bind_Group_Layout_Entry{
            cts_layout_buffer(0, {.Compute}, .Storage),
        })
    ctx.compute_group = gpu.device_create_bind_group(f.device, {
        layout = ctx.compute_layout,
        entries = []gpu.Bind_Group_Entry{
            cts_bg_buffer_entry(ctx.storage, 0, gpu.WHOLE_SIZE),
        },
    })
    return ctx
}

cts_open_ctx_free :: proc(ctx: ^CTS_OPEN_CTX) {
    gpu.bind_group_release(ctx.compute_group)
    gpu.bind_group_release(ctx.render_group)
    gpu.bind_group_layout_release(ctx.compute_layout)
    gpu.bind_group_layout_release(ctx.render_layout)
    gpu.query_set_release(ctx.occlusion)
    gpu.compute_pipeline_release(ctx.compute_pipeline)
    gpu.render_pipeline_release(ctx.render_pipeline)
    gpu.buffer_release(ctx.storage)
    gpu.buffer_release(ctx.indirect)
    gpu.buffer_release(ctx.index)
    gpu.buffer_release(ctx.vertex)
    gpu.buffer_release(ctx.resolve)
    gpu.buffer_release(ctx.uniform)
    gpu.texture_release(ctx.copy_dst)
    gpu.texture_release(ctx.copy_src)
    gpu.texture_view_release(ctx.view)
    gpu.texture_release(ctx.target)
}

// This port reports a `popDebugGroup` with nothing pushed on every encoder
// kind. The rows assert the port's behaviour, as the module comment records.
cts_open_underflow :: proc(cmd: int, pop_cmd: int) -> bool {
    return cmd == pop_cmd
}

cts_open_issue_encoder :: proc(ctx: ^CTS_OPEN_CTX, encoder: gpu.Command_Encoder, cmd: int) {
    switch cmd {
    case 0:
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_end(pass)
    case 1:
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{
                {view = ctx.view, ops = {load = .Load, store = .Store}},
            },
        })
        gpu.render_pass_end(pass)
    case 2:
        gpu.command_encoder_clear_buffer(encoder, ctx.uniform, 0, 16)
    case 3:
        gpu.command_encoder_copy_buffer_to_buffer(encoder, ctx.uniform, 0, ctx.resolve, 0, 16)
    case 4:
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = ctx.uniform,
            layout = {
                bytes_per_row  = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED,
            },
        }
        image := gpu.Texel_Copy_Texture_Info{texture = ctx.copy_dst}
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    case 5:
        image := gpu.Texel_Copy_Texture_Info{texture = ctx.copy_src}
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = ctx.resolve,
            layout = {
                bytes_per_row  = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED,
            },
        }
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    case 6:
        source := gpu.Texel_Copy_Texture_Info{texture = ctx.copy_src}
        destination := gpu.Texel_Copy_Texture_Info{texture = ctx.copy_dst}
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_texture_to_texture(encoder, source, destination, size)
    case 7:
        gpu.command_encoder_insert_debug_marker(encoder, "marker")
    case 8:
        gpu.command_encoder_pop_debug_group(encoder)
    case 9:
        gpu.command_encoder_push_debug_group(encoder, "group")
    case:
        gpu.command_encoder_resolve_query_set(encoder, ctx.occlusion, 0, 1, ctx.resolve, 0)
    }
}

@(test)
cts_encoder_open_state_non_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_open_ctx(f)
    defer cts_open_ctx_free(&ctx)

    for cmd in 0 ..< 11 {
        for finished in 0 ..< 2 {
            encoder := gpu.device_create_command_encoder(f.device)
            first: gpu.Command_Buffer
            if finished != 0 {
                first = gpu.command_encoder_finish(encoder)
            }
            before := cts_errors()
            cts_open_issue_encoder(&ctx, encoder, cmd)
            cts_expect_outcome(t, cts_errors() - before,
                finished != 0 || cts_open_underflow(cmd, 8),
                fmt.tprintf("command %d on a command encoder, finished %d", cmd, finished))
            gpu.command_encoder_release(encoder)
            if first != {} {
                gpu.command_buffer_release(first)
            }
        }
    }
}

cts_open_issue_render :: proc(
    ctx: ^CTS_OPEN_CTX,
    pass: gpu.Render_Pass,
    cmd: int,
) {
    switch cmd {
    case 0: gpu.render_pass_draw(pass, 3, 1, 0, 0)
    case 1: gpu.render_pass_draw_indexed(pass, 3, 1, 0, 0, 0)
    case 2: gpu.render_pass_draw_indirect(pass, ctx.indirect, 0)
    case 3: gpu.render_pass_draw_indexed_indirect(pass, ctx.indirect, 0)
    case 4: gpu.render_pass_set_index_buffer(pass, ctx.index, .Uint32, 0, 12)
    case 5: gpu.render_pass_set_bind_group(pass, 0, ctx.render_group, nil)
    case 6: gpu.render_pass_set_vertex_buffer(pass, 0, ctx.vertex)
    case 7: gpu.render_pass_set_pipeline(pass, ctx.render_pipeline)
    case 8: gpu.render_pass_set_viewport(pass, 0, 0, 1, 1, 0, 1)
    case 9: gpu.render_pass_set_scissor_rect(pass, 0, 0, 1, 1)
    case 10: gpu.render_pass_set_blend_constant(pass, {1, 1, 1, 1})
    case 11: gpu.render_pass_set_stencil_reference(pass, 0)
    case 12: gpu.render_pass_begin_occlusion_query(pass, 0)
    case 13: gpu.render_pass_end_occlusion_query(pass)
    case 14: gpu.render_pass_execute_bundles(pass, nil)
    case 15: gpu.render_pass_push_debug_group(pass, "group")
    case 16: gpu.render_pass_pop_debug_group(pass)
    case: gpu.render_pass_insert_debug_marker(pass, "marker")
    }
}

@(test)
cts_encoder_open_state_render_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_open_ctx(f)
    defer cts_open_ctx_free(&ctx)

    for cmd in 0 ..< 18 {
        for state in 0 ..< 3 {
            encoder := gpu.device_create_command_encoder(f.device)
            pass := gpu.command_encoder_begin_render_pass(encoder, {
                color_attachments = []gpu.Render_Pass_Color_Attachment{
                    {view = ctx.view, ops = {load = .Load, store = .Store}},
                },
                occlusion_query_set = ctx.occlusion,
            })
            gpu.render_pass_set_pipeline(pass, ctx.render_pipeline)
            gpu.render_pass_set_vertex_buffer(pass, 0, ctx.vertex)
            gpu.render_pass_set_index_buffer(pass, ctx.index, .Uint32, 0, 12)
            if cmd == 13 && state == 0 {
                gpu.render_pass_begin_occlusion_query(pass, 0)
            }

            command_buffer: gpu.Command_Buffer
            if state != 0 {
                before_end := cts_errors()
                gpu.render_pass_end(pass)
                cts_expect_outcome(t, cts_errors() - before_end, false,
                    "ending a render pass")
            }
            if state == 2 {
                command_buffer = gpu.command_encoder_finish(encoder)
            }

            before := cts_errors()
            cts_open_issue_render(&ctx, pass, cmd)
            cts_expect_outcome(t, cts_errors() - before,
                state != 0 || cts_open_underflow(cmd, 16),
                fmt.tprintf("command %d on a render pass, state %d", cmd, state))

            if state == 0 {
                if cmd == 12 {
                    gpu.render_pass_end_occlusion_query(pass)
                }
                gpu.render_pass_end(pass)
            }
            if command_buffer == {} {
                command_buffer = gpu.command_encoder_finish(encoder)
            }
            gpu.command_encoder_release(encoder)
            if command_buffer != {} {
                if state == 0 && cmd == 5 {
                    queue := gpu.device_get_queue(f.device)
                    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
                    gpu.queue_release(queue)
                }
                gpu.command_buffer_release(command_buffer)
            }
        }
    }
}

cts_open_issue_bundle :: proc(
    ctx: ^CTS_OPEN_CTX,
    encoder: gpu.Render_Bundle_Encoder,
    cmd: int,
) {
    switch cmd {
    case 0: gpu.render_bundle_encoder_draw(encoder, 3, 1, 0, 0)
    case 1: gpu.render_bundle_encoder_draw_indexed(encoder, 3, 1, 0, 0, 0)
    case 2: gpu.render_bundle_encoder_draw_indirect(encoder, ctx.indirect, 0)
    case 3: gpu.render_bundle_encoder_draw_indexed_indirect(encoder, ctx.indirect, 0)
    case 4: gpu.render_bundle_encoder_set_pipeline(encoder, ctx.render_pipeline)
    case 5: gpu.render_bundle_encoder_set_bind_group(encoder, 0, ctx.render_group, nil)
    case 6: gpu.render_bundle_encoder_set_index_buffer(encoder, ctx.index, .Uint32, 0, 12)
    case 7: gpu.render_bundle_encoder_set_vertex_buffer(encoder, 0, ctx.vertex, 0, gpu.WHOLE_SIZE)
    case 8: gpu.render_bundle_encoder_push_debug_group(encoder, "group")
    case 9: gpu.render_bundle_encoder_pop_debug_group(encoder)
    case: gpu.render_bundle_encoder_insert_debug_marker(encoder, "marker")
    }
}

@(test)
cts_encoder_open_state_render_bundle :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_open_ctx(f)
    defer cts_open_ctx_free(&ctx)

    for cmd in 0 ..< 11 {
        for finished in 0 ..< 2 {
            formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
            encoder := gpu.device_create_render_bundle_encoder(f.device, {
                color_formats = formats[:], sample_count = 1,
            })
            bundle: gpu.Render_Bundle
            if finished == 0 {
                gpu.render_bundle_encoder_set_pipeline(encoder, ctx.render_pipeline)
                gpu.render_bundle_encoder_set_vertex_buffer(encoder, 0, ctx.vertex, 0,
                    gpu.WHOLE_SIZE)
                gpu.render_bundle_encoder_set_index_buffer(encoder, ctx.index, .Uint32, 0, 12)
            } else {
                bundle = gpu.render_bundle_encoder_finish(encoder)
            }
            before := cts_errors()
            cts_open_issue_bundle(&ctx, encoder, cmd)
            expected := finished != 0 || (finished == 0 && cmd == 9)
            cts_expect_outcome(t, cts_errors() - before, expected,
                fmt.tprintf("command %d on a render bundle encoder, finished %d", cmd,
                    finished))
            gpu.render_bundle_encoder_release(encoder)
            if bundle != {} {
                gpu.render_bundle_release(bundle)
            }
        }
    }
}

cts_open_issue_compute :: proc(
    ctx: ^CTS_OPEN_CTX,
    pass: gpu.Compute_Pass,
    cmd: int,
) {
    switch cmd {
    case 0: gpu.compute_pass_set_bind_group(pass, 0, ctx.compute_group, nil)
    case 1: gpu.compute_pass_set_pipeline(pass, ctx.compute_pipeline)
    case 2: gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    case 3: gpu.compute_pass_dispatch_workgroups_indirect(pass, ctx.indirect, 0)
    case 4: gpu.compute_pass_push_debug_group(pass, "group")
    case 5: gpu.compute_pass_pop_debug_group(pass)
    case: gpu.compute_pass_insert_debug_marker(pass, "marker")
    }
}

@(test)
cts_encoder_open_state_compute_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_open_ctx(f)
    defer cts_open_ctx_free(&ctx)

    for cmd in 0 ..< 7 {
        for state in 0 ..< 3 {
            encoder := gpu.device_create_command_encoder(f.device)
            pass := gpu.command_encoder_begin_compute_pass(encoder)
            gpu.compute_pass_set_pipeline(pass, ctx.compute_pipeline)

            command_buffer: gpu.Command_Buffer
            if state != 0 {
                before_end := cts_errors()
                gpu.compute_pass_end(pass)
                cts_expect_outcome(t, cts_errors() - before_end, false,
                    "ending a compute pass")
            }
            if state == 2 {
                command_buffer = gpu.command_encoder_finish(encoder)
            }

            before := cts_errors()
            cts_open_issue_compute(&ctx, pass, cmd)
            cts_expect_outcome(t, cts_errors() - before,
                state != 0 || cts_open_underflow(cmd, 5),
                fmt.tprintf("command %d on a compute pass, state %d", cmd, state))

            if state == 0 {
                gpu.compute_pass_end(pass)
            }
            if command_buffer == {} {
                command_buffer = gpu.command_encoder_finish(encoder)
            }
            gpu.command_encoder_release(encoder)
            if command_buffer != {} {
                if state == 0 && cmd == 0 {
                    queue := gpu.device_get_queue(f.device)
                    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
                    gpu.queue_release(queue)
                }
                gpu.command_buffer_release(command_buffer)
            }
        }
    }
}
