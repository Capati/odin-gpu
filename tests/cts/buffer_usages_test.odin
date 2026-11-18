package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/resource_usages/buffer/in_pass_encoder`
// and `in_pass_misc` specs: a compute pass
// records one usage scope per dispatch, while a render pass has one scope for the
// whole pass. Conflicts are per buffer, not per byte range.

CTS_RU_Buffer :: struct {
    buffer:   gpu.Buffer,
    uniform:  gpu.Bind_Group_Layout,
    storage:  gpu.Bind_Group_Layout,
    u_group:  gpu.Bind_Group,
    s_group:  gpu.Bind_Group,
    s_group2: gpu.Bind_Group,
    layout:   gpu.Pipeline_Layout,
    storage_layout: gpu.Pipeline_Layout,
    pipeline: gpu.Compute_Pipeline,
    storage_pipeline: gpu.Compute_Pipeline,
}

cts_ru_buffer_setup :: proc(f: CTS_Fixture) -> CTS_RU_Buffer {
    ctx: CTS_RU_Buffer
    ctx.buffer = gpu.device_create_buffer(f.device, {
        size = 512,
        usage = {.Uniform, .Storage, .Copy_Src, .Copy_Dst, .Vertex, .Index},
    })
    compute := gpu.Shader_Stages{.Compute}
    ctx.uniform = cts_pb_buffer_layout(f.device, compute, .Uniform, false)
    ctx.storage = cts_pb_buffer_layout(f.device, compute, .Storage, false)
    ctx.u_group = cts_pb_group(f.device, ctx.uniform,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(ctx.buffer, 0, 256)})
    ctx.s_group = cts_pb_group(f.device, ctx.storage,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(ctx.buffer, 0, 256)})
    ctx.s_group2 = cts_pb_group(f.device, ctx.storage,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(ctx.buffer, 256, 256)})
    ctx.layout = cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{ctx.storage, ctx.uniform})
    ctx.storage_layout = cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{ctx.storage, ctx.storage})
    ctx.pipeline = cts_pb_compute_pipeline(f.device, ctx.layout)
    ctx.storage_pipeline = cts_pb_compute_pipeline(f.device, ctx.storage_layout)
    return ctx
}

cts_ru_buffer_free :: proc(ctx: ^CTS_RU_Buffer) {
    if ctx.storage_pipeline != {} {
        gpu.compute_pipeline_release(ctx.storage_pipeline)
    }
    if ctx.pipeline != {} {
        gpu.compute_pipeline_release(ctx.pipeline)
    }
    gpu.pipeline_layout_release(ctx.storage_layout)
    gpu.pipeline_layout_release(ctx.layout)
    gpu.bind_group_release(ctx.s_group2)
    gpu.bind_group_release(ctx.s_group)
    gpu.bind_group_release(ctx.u_group)
    gpu.bind_group_layout_release(ctx.storage)
    gpu.bind_group_layout_release(ctx.uniform)
    gpu.buffer_release(ctx.buffer)
}

cts_ru_finish :: proc(f: CTS_Fixture, encoder: gpu.Command_Encoder) {
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        queue := gpu.device_get_queue(f.device)
        gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
        gpu.queue_release(queue)
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
}

@(test)
cts_resource_buffer_compute_without_dispatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_buffer_setup(f)
    defer cts_ru_buffer_free(&ctx)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, ctx.pipeline)
    gpu.compute_pass_set_bind_group(pass, 1, ctx.u_group, nil)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false,
        "conflicting groups with no dispatch")
}

@(test)
cts_resource_buffer_compute_one_dispatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_buffer_setup(f)
    defer cts_ru_buffer_free(&ctx)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, ctx.pipeline)
    gpu.compute_pass_set_bind_group(pass, 1, ctx.u_group, nil)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true,
        "a dispatch reading and writing the same buffer")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, ctx.storage_pipeline)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_set_bind_group(pass, 1, ctx.s_group2, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false,
        "two writable storage bindings of the same buffer")
}

@(test)
cts_resource_buffer_compute_two_dispatches :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_buffer_setup(f)
    defer cts_ru_buffer_free(&ctx)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, ctx.pipeline)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_set_bind_group(pass, 1, ctx.u_group, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true,
        "the second dispatch reads and writes the same buffer")
}

@(test)
cts_resource_buffer_reset_before_dispatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_buffer_setup(f)
    defer cts_ru_buffer_free(&ctx)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, ctx.pipeline)
    gpu.compute_pass_set_bind_group(pass, 1, ctx.u_group, nil)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    testing.expect(t, cts_errors() - before >= 2,
        "each dispatch must report the same-scope conflict")
}

@(test)
cts_resource_buffer_copy_then_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_buffer_setup(f)
    defer cts_ru_buffer_free(&ctx)

    dest := gpu.device_create_buffer(f.device, {
        size = 512,
        usage = {.Uniform, .Storage, .Copy_Src, .Copy_Dst, .Vertex, .Index},
    })
    defer gpu.buffer_release(dest)

    before := cts_errors()
    single_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{ctx.storage})
    single_pipeline := cts_pb_compute_pipeline(f.device, single_layout)
    defer gpu.compute_pipeline_release(single_pipeline)
    defer gpu.pipeline_layout_release(single_layout)
    encoder := gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_buffer_to_buffer(encoder, ctx.buffer, 0, dest, 0, 16)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, single_pipeline)
    gpu.compute_pass_set_bind_group(pass, 0, ctx.s_group, nil)
    gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
    gpu.compute_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false,
        "a read-only copy followed by a writable storage dispatch")
}

CTS_RU_RP :: struct {
    target:  gpu.Texture,
    view:    gpu.Texture_View,
    buffer:  gpu.Buffer,
    pipeline: gpu.Render_Pipeline,
}

cts_ru_rp_setup :: proc(f: CTS_Fixture) -> CTS_RU_RP {
    ctx: CTS_RU_RP
    ctx.target = gpu.device_create_texture(f.device, {
        usage           = {.Render_Attachment},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    ctx.view = gpu.texture_create_view(ctx.target)
    ctx.buffer = gpu.device_create_buffer(f.device, {
        size = 512,
        usage = {.Uniform, .Storage, .Copy_Src, .Copy_Dst, .Vertex, .Index},
    })
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    ctx.pipeline = cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
    return ctx
}

cts_ru_rp_free :: proc(ctx: ^CTS_RU_RP) {
    gpu.render_pipeline_release(ctx.pipeline)
    gpu.buffer_release(ctx.buffer)
    gpu.texture_view_release(ctx.view)
    gpu.texture_release(ctx.target)
}

cts_ru_rp_bind :: proc(
    f: CTS_Fixture,
    pass: gpu.Render_Pass,
    buffer: gpu.Buffer,
    slot: u32,
    offset: u64,
    usage: int,
    layout: ^gpu.Bind_Group_Layout,
    group: ^gpu.Bind_Group,
) {
    switch usage {
    case 0, 1:
        visibility := gpu.Shader_Stages{.Fragment}
        type := usage == 0 ? gpu.Buffer_Binding_Type.Uniform : .Storage
        layout^ = cts_pb_buffer_layout(f.device, visibility, type, false)
        group^ = cts_pb_group(f.device, layout^,
            []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, offset, 256)})
        gpu.render_pass_set_bind_group(pass, slot, group^, nil)
    case 2:
        gpu.render_pass_set_vertex_buffer(pass, slot, buffer, offset, 256)
    case:
        gpu.render_pass_set_index_buffer(pass, buffer, .Uint16, offset, 256)
    }
}

cts_ru_rp_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    ctx: ^CTS_RU_RP,
    first, second: int,
    second_offset: u64,
    draw: bool,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            {view = ctx.view, ops = {load = .Clear, store = .Store}},
        },
    })
    layout_a, layout_b: gpu.Bind_Group_Layout
    group_a, group_b: gpu.Bind_Group
    cts_ru_rp_bind(f, pass, ctx.buffer, 0, 0, first, &layout_a, &group_a)
    if draw {
        gpu.render_pass_set_pipeline(pass, ctx.pipeline)
        gpu.render_pass_draw(pass, 3, 1, 0, 0)
    }
    cts_ru_rp_bind(f, pass, ctx.buffer, 1, second_offset, second, &layout_b, &group_b)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    errors := cts_errors() - before
    if group_b != {} {
        gpu.bind_group_release(group_b)
    }
    if group_a != {} {
        gpu.bind_group_release(group_a)
    }
    if layout_b != {} {
        gpu.bind_group_layout_release(layout_b)
    }
    if layout_a != {} {
        gpu.bind_group_layout_release(layout_a)
    }
    return errors
}

@(test)
cts_resource_buffer_render_no_draw :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_rp_setup(f)
    defer cts_ru_rp_free(&ctx)

    Row :: struct {first, second: int, offset: u64, fail: bool}
    rows := [8]Row{
        {0, 0, 0, false},
        {0, 2, 0, false},
        {0, 1, 0, true},
        {1, 0, 0, true},
        {2, 1, 0, true},
        {3, 1, 0, true},
        {1, 1, 0, false},
        {0, 1, 256, true},
    }
    for row in rows {
        errors := cts_ru_rp_row(t, f, &ctx, row.first, row.second, row.offset, false)
        cts_expect_outcome(t, errors, row.fail, "render pass usage row")
    }
    errors := cts_ru_rp_row(t, f, &ctx, 0, 0, 256, false)
    cts_expect_outcome(t, errors, false, "disjoint uniform ranges")
}

@(test)
cts_resource_buffer_render_one_draw :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_rp_setup(f)
    defer cts_ru_rp_free(&ctx)

    errors := cts_ru_rp_row(t, f, &ctx, 0, 1, 0, true)
    cts_expect_outcome(t, errors, true, "draw uniform then bind storage")
    errors = cts_ru_rp_row(t, f, &ctx, 1, 0, 0, true)
    cts_expect_outcome(t, errors, true, "draw storage then bind uniform")
    errors = cts_ru_rp_row(t, f, &ctx, 0, 0, 0, true)
    cts_expect_outcome(t, errors, false, "draw after two uniform bindings")
}

@(test)
cts_resource_buffer_render_two_draws :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_rp_setup(f)
    defer cts_ru_rp_free(&ctx)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            {view = ctx.view, ops = {load = .Clear, store = .Store}},
        },
    })
    gpu.render_pass_set_pipeline(pass, ctx.pipeline)
    layout_u, layout_s: gpu.Bind_Group_Layout
    group_u, group_s: gpu.Bind_Group
    cts_ru_rp_bind(f, pass, ctx.buffer, 0, 0, 0, &layout_u, &group_u)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    cts_ru_rp_bind(f, pass, ctx.buffer, 1, 0, 1, &layout_s, &group_s)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "two draws in one pass")
    gpu.bind_group_release(group_s)
    gpu.bind_group_release(group_u)
    gpu.bind_group_layout_release(layout_s)
    gpu.bind_group_layout_release(layout_u)

    before = cts_errors()
    split := gpu.device_create_command_encoder(f.device)
    first := gpu.command_encoder_begin_render_pass(split, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            {view = ctx.view, ops = {load = .Clear, store = .Store}},
        },
    })
    gpu.render_pass_set_pipeline(first, ctx.pipeline)
    layout_a, layout_b: gpu.Bind_Group_Layout
    group_a, group_b: gpu.Bind_Group
    cts_ru_rp_bind(f, first, ctx.buffer, 0, 0, 0, &layout_a, &group_a)
    gpu.render_pass_draw(first, 3, 1, 0, 0)
    gpu.render_pass_end(first)
    second := gpu.command_encoder_begin_render_pass(split, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            {view = ctx.view, ops = {load = .Clear, store = .Store}},
        },
    })
    gpu.render_pass_set_pipeline(second, ctx.pipeline)
    cts_ru_rp_bind(f, second, ctx.buffer, 0, 0, 1, &layout_b, &group_b)
    gpu.render_pass_draw(second, 3, 1, 0, 0)
    gpu.render_pass_end(second)
    cts_ru_finish(f, split)
    cts_expect_outcome(t, cts_errors() - before, false, "two passes, separate scopes")
    gpu.bind_group_release(group_b)
    gpu.bind_group_release(group_a)
    gpu.bind_group_layout_release(layout_b)
    gpu.bind_group_layout_release(layout_a)
}

@(test)
cts_resource_buffer_bind_group_slots :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ctx := cts_ru_rp_setup(f)
    defer cts_ru_rp_free(&ctx)

    visibility := gpu.Shader_Stages{.Fragment}
    uniform_layout := cts_pb_buffer_layout(f.device, visibility, .Uniform, false)
    storage_layout := cts_pb_buffer_layout(f.device, visibility, .Storage, false)
    defer gpu.bind_group_layout_release(uniform_layout)
    defer gpu.bind_group_layout_release(storage_layout)
    uniform := cts_pb_group(f.device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(ctx.buffer, 0, 256)})
    storage := cts_pb_group(f.device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(ctx.buffer, 0, 256)})
    defer gpu.bind_group_release(uniform)
    defer gpu.bind_group_release(storage)

    layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{uniform_layout})
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    declaring := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, layout)
    defer gpu.render_pipeline_release(declaring)
    defer gpu.pipeline_layout_release(layout)

    Row :: struct {pipeline: gpu.Render_Pipeline, group: gpu.Bind_Group, slot: u32, fail: bool}
    rows := [5]Row{
        {declaring, uniform, 0, false},
        {declaring, {}, 0, true},
        {declaring, storage, 0, true},
        {ctx.pipeline, storage, 1, false},
        {ctx.pipeline, {}, 0, false},
    }
    for row in rows {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{
                {view = ctx.view, ops = {load = .Clear, store = .Store}},
            },
        })
        gpu.render_pass_set_pipeline(pass, row.pipeline)
        if row.group != {} {
            gpu.render_pass_set_bind_group(pass, row.slot, row.group, nil)
        }
        gpu.render_pass_draw(pass, 3, 1, 0, 0)
        gpu.render_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, row.fail, "bind group slot row")
    }
}

