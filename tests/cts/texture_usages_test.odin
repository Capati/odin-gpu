package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/resource_usages/texture/in_render_common`
// and `in_render_misc`: texture
// usage is tracked per subresource (mip, layer, aspect), so a rendered cell
// conflicts with a sampled or written view that reaches the same cell, while
// disjoint cells and separate passes do not.

CTS_TU_Group :: struct {
    layout: gpu.Bind_Group_Layout,
    group:  gpu.Bind_Group,
}

cts_tu_sampled_group :: proc(
    f: CTS_Fixture,
    view: gpu.Texture_View,
    dimension: gpu.Texture_View_Dimension,
    sample_type: gpu.Texture_Sample_Type = .Unfilterable_Float,
) -> CTS_TU_Group {
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_texture(0, {.Fragment}, sample_type, dimension),
    })
    group := cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = view}})
    return {layout = layout, group = group}
}

cts_tu_storage_group :: proc(
    f: CTS_Fixture,
    view: gpu.Texture_View,
    dimension: gpu.Texture_View_Dimension = .D2,
) -> CTS_TU_Group {
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        {binding = 0, visibility = {.Fragment}, type = gpu.Storage_Texture_Binding_Layout{
            access = .Write_Only, format = .R32_Float, view_dimension = dimension}},
    })
    group := cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = view}})
    return {layout = layout, group = group}
}

cts_tu_group_free :: proc(group: ^CTS_TU_Group) {
    if group.group != {} {
        gpu.bind_group_release(group.group)
    }
    if group.layout != {} {
        gpu.bind_group_layout_release(group.layout)
    }
}

cts_tu_texture :: proc(f: CTS_Fixture, usage: gpu.Texture_Usages) -> gpu.Texture {
    return cts_rp_texture(f.device, .R32_Float, 16, 16, 3, 3, 1, usage)
}

cts_tu_view :: proc(
    texture: gpu.Texture,
    mip: u32,
    layer: u32,
    aspect: gpu.Texture_Aspect,
) -> gpu.Texture_View {
    return gpu.texture_create_view(texture, {
        dimension         = .D2,
        base_mip_level    = mip,
        mip_level_count   = 1,
        base_array_layer  = layer,
        array_layer_count = 1,
        aspect            = aspect,
    })
}

@(test)
cts_texture_usage_color_attachments :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Render_Attachment})
    defer gpu.texture_release(texture)
    layer0 := cts_rp_view(texture, 0, 1, 0, 1)
    layer1 := cts_rp_view(texture, 0, 1, 1, 1)
    mip1 := cts_rp_view(texture, 1, 1, 0, 1)
    defer gpu.texture_view_release(layer0)
    defer gpu.texture_view_release(layer1)
    defer gpu.texture_view_release(mip1)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            cts_rp_color(layer0), cts_rp_color(layer0),
        },
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "the same subresource twice")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            cts_rp_color(layer0), cts_rp_color(layer1),
        },
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "different layers")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(layer0)},
    })
    gpu.render_pass_end(pass)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(layer0)},
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "the same cell in two passes")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(layer0)},
    })
    gpu.render_pass_end(pass)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(mip1)},
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "different mips in two passes")
}

@(test)
cts_texture_usage_color_attachment_and_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Render_Attachment, .Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    attachment := cts_rp_view(texture, 0, 1, 0, 1)
    sampled_same := cts_rp_view(texture, 0, 1, 0, 1)
    sampled_mip1 := cts_rp_view(texture, 1, 1, 0, 1)
    sampled_layer1 := cts_rp_view(texture, 0, 1, 1, 1)
    sampled_layers := cts_rp_view(texture, 0, 1, 0, 2)
    storage_same := cts_rp_view(texture, 0, 1, 0, 1)
    storage_layer1 := cts_rp_view(texture, 0, 1, 1, 1)
    defer gpu.texture_view_release(attachment)
    defer gpu.texture_view_release(sampled_same)
    defer gpu.texture_view_release(sampled_mip1)
    defer gpu.texture_view_release(sampled_layer1)
    defer gpu.texture_view_release(sampled_layers)
    defer gpu.texture_view_release(storage_same)
    defer gpu.texture_view_release(storage_layer1)

    sampled := cts_tu_sampled_group(f, sampled_same, .D2)
    sampled_next_mip := cts_tu_sampled_group(f, sampled_mip1, .D2)
    sampled_next_layer := cts_tu_sampled_group(f, sampled_layer1, .D2)
    sampled_two_layers := cts_tu_sampled_group(f, sampled_layers, .D2_Array)
    storage := cts_tu_storage_group(f, storage_same)
    storage_next_layer := cts_tu_storage_group(f, storage_layer1)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&sampled_next_mip)
    defer cts_tu_group_free(&sampled_next_layer)
    defer cts_tu_group_free(&sampled_two_layers)
    defer cts_tu_group_free(&storage)
    defer cts_tu_group_free(&storage_next_layer)

    Row :: struct {group: ^CTS_TU_Group, fail: bool}
    rows := [6]Row{
        {&sampled, true}, {&sampled_next_layer, false}, {&sampled_next_mip, false},
        {&sampled_two_layers, true}, {&storage, true}, {&storage_next_layer, false},
    }
    for row in rows {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(attachment)},
        })
        gpu.render_pass_set_bind_group(pass, 0, row.group.group, nil)
        gpu.render_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, row.fail,
            "attachment and bind group row")
    }

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(attachment)},
    })
    gpu.render_pass_end(pass)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(sampled_layer1)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false,
        "attachment and sampled binding in two passes")
}

cts_tu_ds_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    attachment: gpu.Texture_View,
    group: gpu.Bind_Group,
    depth_read_only, stencil_read_only: bool,
    fail: bool,
) {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    depth := cts_rp_depth(attachment)
    if depth_read_only {
        depth.depth_read_only = true
        depth.depth_ops = {}
    } else {
        depth.depth_ops = {load = .Load, store = .Store}
    }
    if stencil_read_only {
        depth.stencil_read_only = true
        depth.stencil_ops = {}
    } else {
        depth.stencil_ops = {load = .Load, store = .Store}
    }
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        depth_stencil_attachment = &depth,
    })
    if group != {} {
        gpu.render_pass_set_bind_group(pass, 0, group, nil)
    }
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, fail,
        fmt.tprintf("ds row depth_ro=%v stencil_ro=%v", depth_read_only, stencil_read_only))
}

@(test)
cts_texture_usage_depth_stencil_attachment_and_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 3, 3, 1,
        {.Render_Attachment, .Texture_Binding})
    defer gpu.texture_release(texture)
    attachment := cts_tu_view(texture, 0, 0, .All)
    depth_same := cts_tu_view(texture, 0, 0, .Depth_Only)
    depth_mip1 := cts_tu_view(texture, 1, 0, .Depth_Only)
    depth_layer1 := cts_tu_view(texture, 0, 1, .Depth_Only)
    stencil_same := cts_tu_view(texture, 0, 0, .Stencil_Only)
    defer gpu.texture_view_release(attachment)
    defer gpu.texture_view_release(depth_same)
    defer gpu.texture_view_release(depth_mip1)
    defer gpu.texture_view_release(depth_layer1)
    defer gpu.texture_view_release(stencil_same)

    depth_group := cts_tu_sampled_group(f, depth_same, .D2, .Depth)
    depth_mip1_group := cts_tu_sampled_group(f, depth_mip1, .D2, .Depth)
    depth_layer1_group := cts_tu_sampled_group(f, depth_layer1, .D2, .Depth)
    stencil_group := cts_tu_sampled_group(f, stencil_same, .D2, .Uint)
    defer cts_tu_group_free(&depth_group)
    defer cts_tu_group_free(&depth_mip1_group)
    defer cts_tu_group_free(&depth_layer1_group)
    defer cts_tu_group_free(&stencil_group)

    cts_tu_ds_row(t, f, attachment, depth_group.group, false, false, true)
    cts_tu_ds_row(t, f, attachment, depth_group.group, true, false, false)
    cts_tu_ds_row(t, f, attachment, stencil_group.group, true, false, true)
    cts_tu_ds_row(t, f, attachment, stencil_group.group, false, true, false)
    cts_tu_ds_row(t, f, attachment, depth_mip1_group.group, false, false, false)
    cts_tu_ds_row(t, f, attachment, depth_layer1_group.group, false, false, false)

    color_texture := cts_rp_texture(f.device, .RGBA8_Unorm)
    defer gpu.texture_release(color_texture)
    color_view := cts_rp_view(color_texture)
    defer gpu.texture_view_release(color_view)
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    depth := cts_rp_depth(attachment)
    depth.depth_ops = {load = .Load, store = .Store}
    depth.stencil_ops = {load = .Load, store = .Store}
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        depth_stencil_attachment = &depth,
    })
    gpu.render_pass_end(pass)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)},
    })
    gpu.render_pass_set_bind_group(pass, 0, depth_group.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "depth attachment and sample in two passes")
}

@(test)
cts_texture_usage_multiple_bind_groups :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    sampled_cell := cts_rp_view(texture, 0, 1, 0, 1)
    storage_cell := cts_rp_view(texture, 0, 1, 0, 1)
    storage_layer := cts_rp_view(texture, 0, 1, 1, 1)
    storage_mip := cts_rp_view(texture, 1, 1, 0, 1)
    sampled_layers := cts_rp_view(texture, 0, 1, 0, 2)
    defer gpu.texture_view_release(sampled_cell)
    defer gpu.texture_view_release(storage_cell)
    defer gpu.texture_view_release(storage_layer)
    defer gpu.texture_view_release(storage_mip)
    defer gpu.texture_view_release(sampled_layers)

    sampled := cts_tu_sampled_group(f, sampled_cell, .D2)
    storage := cts_tu_storage_group(f, storage_cell)
    storage_layer_group := cts_tu_storage_group(f, storage_layer)
    storage_mip_group := cts_tu_storage_group(f, storage_mip)
    sampled_layers_group := cts_tu_sampled_group(f, sampled_layers, .D2_Array)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)
    defer cts_tu_group_free(&storage_layer_group)
    defer cts_tu_group_free(&storage_mip_group)
    defer cts_tu_group_free(&sampled_layers_group)

    color_texture := cts_rp_texture(f.device, .R32_Float)
    defer gpu.texture_release(color_texture)
    color_view := cts_rp_view(color_texture)
    defer gpu.texture_view_release(color_view)

    Row :: struct {first, second: gpu.Bind_Group, fail: bool}
    rows := [7]Row{
        {sampled.group, storage.group, true},
        {sampled.group, sampled.group, false},
        {storage.group, storage.group, false},
        {sampled.group, storage_layer_group.group, false},
        {sampled.group, storage_mip_group.group, false},
        {sampled_layers_group.group, storage_layer_group.group, true},
        {sampled.group, storage.group, false},
    }
    for row, index in rows {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        if index == 6 {
            pass := gpu.command_encoder_begin_render_pass(encoder, {
                color_attachments = []gpu.Render_Pass_Color_Attachment{
                    cts_rp_color(color_view),
                },
            })
            gpu.render_pass_set_bind_group(pass, 0, row.first, nil)
            gpu.render_pass_end(pass)
            pass = gpu.command_encoder_begin_render_pass(encoder, {
                color_attachments = []gpu.Render_Pass_Color_Attachment{
                    cts_rp_color(color_view),
                },
            })
            gpu.render_pass_set_bind_group(pass, 1, row.second, nil)
            gpu.render_pass_end(pass)
        } else {
            pass := gpu.command_encoder_begin_render_pass(encoder, {
                color_attachments = []gpu.Render_Pass_Color_Attachment{
                    cts_rp_color(color_view),
                },
            })
            gpu.render_pass_set_bind_group(pass, 0, row.first, nil)
            gpu.render_pass_set_bind_group(pass, 1, row.second, nil)
            gpu.render_pass_end(pass)
        }
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, row.fail, "multiple bind group row")
    }
}

@(test)
cts_texture_usage_depth_stencil_in_groups :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 3, 3, 1,
        {.Texture_Binding})
    defer gpu.texture_release(texture)
    depth_cell := cts_tu_view(texture, 0, 0, .Depth_Only)
    stencil_cell := cts_tu_view(texture, 0, 0, .Stencil_Only)
    depth_mip1 := cts_tu_view(texture, 1, 0, .Depth_Only)
    depth_layer1 := cts_tu_view(texture, 0, 1, .Depth_Only)
    defer gpu.texture_view_release(depth_cell)
    defer gpu.texture_view_release(stencil_cell)
    defer gpu.texture_view_release(depth_mip1)
    defer gpu.texture_view_release(depth_layer1)

    depth_group := cts_tu_sampled_group(f, depth_cell, .D2, .Depth)
    stencil_group := cts_tu_sampled_group(f, stencil_cell, .D2, .Uint)
    depth_mip1_group := cts_tu_sampled_group(f, depth_mip1, .D2, .Depth)
    depth_layer1_group := cts_tu_sampled_group(f, depth_layer1, .D2, .Depth)
    defer cts_tu_group_free(&depth_group)
    defer cts_tu_group_free(&stencil_group)
    defer cts_tu_group_free(&depth_mip1_group)
    defer cts_tu_group_free(&depth_layer1_group)

    color_texture := cts_rp_texture(f.device, .R32_Float)
    defer gpu.texture_release(color_texture)
    color_view := cts_rp_view(color_texture)
    defer gpu.texture_view_release(color_view)

    Row :: struct {groups: [3]gpu.Bind_Group, count: int}
    rows := [3]Row{
        {{depth_group.group, stencil_group.group, {}}, 2},
        {{depth_group.group, depth_group.group, {}}, 2},
        {{depth_group.group, depth_mip1_group.group, depth_layer1_group.group}, 3},
    }
    for row in rows {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)},
        })
        groups := row.groups
        for group, index in groups[:row.count] {
            gpu.render_pass_set_bind_group(pass, u32(index), group, nil)
        }
        gpu.render_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, false, "depth/stencil bind group row")
    }
}

cts_tu_rebind_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    target: gpu.Texture_View,
    first, second, replacement: gpu.Bind_Group,
) {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, first, nil)
    gpu.render_pass_set_bind_group(pass, 1, second, nil)
    gpu.render_pass_set_bind_group(pass, 1, replacement, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    _ = before
}

@(test)
cts_texture_usage_same_index_color :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    layer0 := cts_rp_view(texture, 0, 1, 0, 1)
    layers12 := cts_rp_view(texture, 0, 1, 1, 2)
    defer gpu.texture_view_release(layer0)
    defer gpu.texture_view_release(layers12)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)

    sampled0 := cts_tu_sampled_group(f, layer0, .D2)
    storage0 := cts_tu_storage_group(f, layer0)
    sampled12 := cts_tu_sampled_group(f, layers12, .D2_Array)
    storage12 := cts_tu_storage_group(f, layers12, .D2_Array)
    defer cts_tu_group_free(&sampled0)
    defer cts_tu_group_free(&storage0)
    defer cts_tu_group_free(&sampled12)
    defer cts_tu_group_free(&storage12)

    Row :: struct {first, second, replacement: gpu.Bind_Group, fail: bool}
    rows := [4]Row{
        {sampled0.group, sampled0.group, sampled12.group, false},
        {sampled0.group, storage0.group, sampled12.group, true},
        {storage0.group, storage0.group, storage12.group, false},
        {storage0.group, sampled0.group, sampled12.group, true},
    }
    for row in rows {
        before := cts_errors()
        cts_tu_rebind_row(t, f, target, row.first, row.second, row.replacement)
        cts_expect_outcome(t, cts_errors() - before, row.fail, "same-index rebind row")
    }
}

@(test)
cts_texture_usage_same_index_depth :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    depth_stencil := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 1, 1, 1,
        {.Texture_Binding, .Render_Attachment})
    defer gpu.texture_release(depth_stencil)
    attachment := cts_tu_view(depth_stencil, 0, 0, .All)
    depth_view := cts_tu_view(depth_stencil, 0, 0, .Depth_Only)
    stencil_view := cts_tu_view(depth_stencil, 0, 0, .Stencil_Only)
    defer gpu.texture_view_release(attachment)
    defer gpu.texture_view_release(depth_view)
    defer gpu.texture_view_release(stencil_view)
    depth_group := cts_tu_sampled_group(f, depth_view, .D2, .Depth)
    stencil_group := cts_tu_sampled_group(f, stencil_view, .D2, .Uint)
    defer cts_tu_group_free(&depth_group)
    defer cts_tu_group_free(&stencil_group)

    color_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(color_texture)
    color_view := cts_tu_view(color_texture, 0, 0, .All)
    defer gpu.texture_view_release(color_view)
    valid_group := cts_tu_sampled_group(f, color_view, .D2)
    defer cts_tu_group_free(&valid_group)

    Row :: struct {group: gpu.Bind_Group, read_only: bool}
    rows := [4]Row{
        {depth_group.group, false},
        {depth_group.group, true},
        {stencil_group.group, false},
        {stencil_group.group, true},
    }
    for row in rows {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        depth := cts_rp_depth(attachment)
        if row.read_only {
            depth.depth_read_only = true
            depth.stencil_read_only = true
            depth.depth_ops = {}
            depth.stencil_ops = {}
        } else {
            depth.depth_ops = {load = .Load, store = .Store}
            depth.stencil_ops = {load = .Load, store = .Store}
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            depth_stencil_attachment = &depth,
        })
        gpu.render_pass_set_bind_group(pass, 0, row.group, nil)
        gpu.render_pass_set_bind_group(pass, 0, valid_group.group, nil)
        gpu.render_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, !row.read_only,
            "same-index depth rebind row")
    }
}

cts_tu_unused_render_row :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    first, second: gpu.Bind_Group,
    pipeline: gpu.Render_Pipeline,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, first, nil)
    gpu.render_pass_set_bind_group(pass, 1, second, nil)
    gpu.render_pass_set_pipeline(pass, pipeline)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    return cts_errors() - before
}

@(test)
cts_texture_usage_unused_bind_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)

    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    targets := [1]gpu.Color_Target_State {
        {format = .R32_Float, write_mask = gpu.COLOR_WRITES_ALL},
    }
    sampled_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{sampled.layout})
    storage_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{storage.layout})
    defer gpu.pipeline_layout_release(sampled_layout)
    defer gpu.pipeline_layout_release(storage_layout)
    sampled_pipeline := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, sampled_layout)
    storage_pipeline := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, storage_layout)
    defer gpu.render_pipeline_release(sampled_pipeline)
    defer gpu.render_pipeline_release(storage_pipeline)

    Row :: struct {first, second: gpu.Bind_Group, pipeline: gpu.Render_Pipeline, fail: bool}
    rows := [4]Row{
        {sampled.group, storage.group, sampled_pipeline, true},
        {storage.group, sampled.group, storage_pipeline, true},
        {sampled.group, sampled.group, sampled_pipeline, false},
        {storage.group, storage.group, storage_pipeline, false},
    }
    for row in rows {
        errors := cts_tu_unused_render_row(f, target, row.first, row.second, row.pipeline)
        cts_expect_outcome(t, errors, row.fail, "unused group render row")
    }

    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Storage, .Uniform}})
    defer gpu.buffer_release(buffer)
    compute := gpu.Shader_Stages{.Compute}
    storage_bgl := cts_pb_buffer_layout(f.device, compute, .Storage, false)
    uniform_bgl := cts_pb_buffer_layout(f.device, compute, .Uniform, false)
    defer gpu.bind_group_layout_release(storage_bgl)
    defer gpu.bind_group_layout_release(uniform_bgl)
    storage_group := cts_pb_group(f.device, storage_bgl,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 16)})
    uniform_group := cts_pb_group(f.device, uniform_bgl,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 16)})
    defer gpu.bind_group_release(storage_group)
    defer gpu.bind_group_release(uniform_group)
    one_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{storage_bgl})
    two_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{storage_bgl, uniform_bgl})
    defer gpu.pipeline_layout_release(one_layout)
    defer gpu.pipeline_layout_release(two_layout)
    one_pipeline := cts_pb_compute_pipeline(f.device, one_layout)
    two_pipeline := cts_pb_compute_pipeline(f.device, two_layout)
    defer gpu.compute_pipeline_release(one_pipeline)
    defer gpu.compute_pipeline_release(two_pipeline)

    run_compute :: proc(
        t: ^testing.T,
        f: CTS_Fixture,
        pipeline: gpu.Compute_Pipeline,
        second_slot: u32,
        first, second: gpu.Bind_Group,
    ) -> int {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_bind_group(pass, 0, first, nil)
        gpu.compute_pass_set_bind_group(pass, second_slot, second, nil)
        gpu.compute_pass_set_pipeline(pass, pipeline)
        gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
        gpu.compute_pass_end(pass)
        cts_ru_finish(f, encoder)
        return cts_errors() - before
    }

    errors := run_compute(t, f, one_pipeline, 2, storage_group, uniform_group)
    cts_expect_outcome(t, errors, false, "compute group at an undeclared slot")
    errors = run_compute(t, f, two_pipeline, 1, storage_group, uniform_group)
    cts_expect_outcome(t, errors, true, "compute conflict through declared slots")
}

cts_tu_copy :: proc(f: CTS_Fixture, texture: gpu.Texture, buffer: gpu.Buffer, from: bool) {
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    encoder := gpu.device_create_command_encoder(f.device)
    if from {
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    } else {
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    }
    cts_ru_finish(f, encoder)
}

@(test)
cts_texture_usage_copy_and_pass :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Copy_Src, .Copy_Dst, .Texture_Binding, .Storage_Binding, .Render_Attachment})
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(texture)
    defer gpu.texture_release(target_texture)
    attachment := cts_rp_view(texture)
    target := cts_rp_view(target_texture)
    sampled_view := cts_rp_view(texture)
    storage_view := cts_rp_view(texture)
    defer gpu.texture_view_release(attachment)
    defer gpu.texture_view_release(target)
    defer gpu.texture_view_release(sampled_view)
    defer gpu.texture_view_release(storage_view)
    sampled := cts_tu_sampled_group(f, sampled_view, .D2)
    storage := cts_tu_storage_group(f, storage_view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Copy_Src, .Copy_Dst}})
    defer gpu.buffer_release(buffer)

    // Copy then pass, or pass then copy: a copy is its own scope.
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(attachment)},
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "copy then attachment")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "copy then sampled pass")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, storage.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "copy then storage pass")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_end(pass)
    gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "sampled pass then copy")
}

cts_tu_view_usage :: proc(
    texture: gpu.Texture,
    usage: gpu.Texture_Usages,
) -> gpu.Texture_View {
    return gpu.texture_create_view(texture, {
        dimension         = .D2,
        usage             = usage,
        mip_level_count   = 1,
        array_layer_count = 1,
    })
}

@(test)
cts_texture_usage_view_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Texture_Binding, .Storage_Binding, .Render_Attachment, .Copy_Src})
    defer gpu.texture_release(texture)
    copy_only := cts_tu_view_usage(texture, {.Copy_Src})
    sampled_only := cts_tu_view_usage(texture, {.Texture_Binding})
    storage_only := cts_tu_view_usage(texture, {.Storage_Binding})
    attachment_ok := cts_tu_view_usage(texture, {.Render_Attachment})
    no_attachment := cts_tu_view_usage(texture, {.Texture_Binding})
    defer gpu.texture_view_release(copy_only)
    defer gpu.texture_view_release(sampled_only)
    defer gpu.texture_view_release(storage_only)
    defer gpu.texture_view_release(attachment_ok)
    defer gpu.texture_view_release(no_attachment)

    make_sampled :: proc(t: ^testing.T, f: CTS_Fixture, view: gpu.Texture_View) {
        before := cts_errors()
        layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
            cts_layout_texture(0, {.Fragment}, .Unfilterable_Float, .D2),
        })
        group := gpu.device_create_bind_group(f.device, {
            layout = layout,
            entries = []gpu.Bind_Group_Entry{{binding = 0, resource = view}},
        })
        cts_expect_outcome(t, cts_errors() - before, false, "sampled view usage")
        if group != {} {
            gpu.bind_group_release(group)
        }
        gpu.bind_group_layout_release(layout)
    }

    before := cts_errors()
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_texture(0, {.Fragment}, .Unfilterable_Float, .D2),
    })
    group := cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = copy_only}})
    testing.expect(t, group == {}, "a sampled group over a copy-only view")
    if group != {} {
        gpu.bind_group_release(group)
    }
    gpu.bind_group_layout_release(layout)
    make_sampled(t, f, sampled_only)

    before = cts_errors()
    layout = cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        {binding = 0, visibility = {.Fragment}, type = gpu.Storage_Texture_Binding_Layout{
            access = .Write_Only, format = .R32_Float, view_dimension = .D2}},
    })
    group = cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = sampled_only}})
    testing.expect(t, group == {}, "a storage group over a sampled-only view")
    if group != {} {
        gpu.bind_group_release(group)
    }
    gpu.bind_group_layout_release(layout)

    before = cts_errors()
    layout = cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        {binding = 0, visibility = {.Fragment}, type = gpu.Storage_Texture_Binding_Layout{
            access = .Write_Only, format = .R32_Float, view_dimension = .D2}},
    })
    group = cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = storage_only}})
    cts_expect_outcome(t, cts_errors() - before, false, "storage group over storage view")
    if group != {} {
        gpu.bind_group_release(group)
    }
    gpu.bind_group_layout_release(layout)

    before = cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            cts_rp_color(no_attachment),
        },
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "attachment view without render usage")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            cts_rp_color(attachment_ok),
        },
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "attachment view with render usage")
}

cts_tu_pass_with_group :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    group: gpu.Bind_Group,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    if group != {} {
        gpu.render_pass_set_bind_group(pass, 0, group, nil)
    }
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    return cts_errors() - before
}

@(test)
cts_texture_usage_scope_basic_render :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)
    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_set_bind_group(pass, 1, storage.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "two conflicting groups, no draw")

    errors := cts_tu_pass_with_group(f, target, sampled.group)
    cts_expect_outcome(t, errors, false, "one sampled group, no draw")
    errors = cts_tu_pass_with_group(f, target, storage.group)
    cts_expect_outcome(t, errors, false, "one storage group, no draw")
    errors = cts_tu_pass_with_group(f, target, {})
    cts_expect_outcome(t, errors, false, "no group, no draw")
    errors = cts_tu_pass_with_group(f, target, sampled.group)
    cts_expect_outcome(t, errors, false, "sampled group bound alone")
}

cts_tu_split_pass_row :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    first, second: gpu.Bind_Group,
    pipeline0, pipeline1: gpu.Render_Pipeline,
    split, draw: bool,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_pipeline(pass, pipeline0)
    gpu.render_pass_set_bind_group(pass, 0, first, nil)
    if draw {
        gpu.render_pass_draw(pass, 3, 1, 0, 0)
    }
    if split {
        gpu.render_pass_end(pass)
        pass = gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
        })
    }
    gpu.render_pass_set_pipeline(pass, pipeline1)
    gpu.render_pass_set_bind_group(pass, 0, second, nil)
    if draw {
        gpu.render_pass_draw(pass, 3, 1, 0, 0)
    }
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    return cts_errors() - before
}

@(test)
cts_texture_usage_scope_pass_boundary :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)
    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    targets := [1]gpu.Color_Target_State {
        {format = .R32_Float, write_mask = gpu.COLOR_WRITES_ALL},
    }
    sampled_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{sampled.layout})
    storage_layout := cts_pb_pipeline_layout(f.device,
        []gpu.Bind_Group_Layout{storage.layout})
    defer gpu.pipeline_layout_release(sampled_layout)
    defer gpu.pipeline_layout_release(storage_layout)
    sampled_pipeline := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, sampled_layout)
    storage_pipeline := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, storage_layout)
    defer gpu.render_pipeline_release(sampled_pipeline)
    defer gpu.render_pipeline_release(storage_pipeline)

    errors := cts_tu_split_pass_row(f, target, sampled.group, storage.group,
        sampled_pipeline, storage_pipeline, false, false)
    cts_expect_outcome(t, errors, true, "two groups in one pass, no draws")
    errors = cts_tu_split_pass_row(f, target, sampled.group, storage.group,
        sampled_pipeline, storage_pipeline, false, true)
    cts_expect_outcome(t, errors, true, "two groups in one pass, with draws")
    errors = cts_tu_split_pass_row(f, target, sampled.group, storage.group,
        sampled_pipeline, storage_pipeline, true, false)
    cts_expect_outcome(t, errors, false, "two groups in two passes, no draws")
    errors = cts_tu_split_pass_row(f, target, sampled.group, storage.group,
        sampled_pipeline, storage_pipeline, true, true)
    cts_expect_outcome(t, errors, false, "two groups in two passes, with draws")
}

cts_tu_visibility_group :: proc(
    f: CTS_Fixture,
    sampled_view, storage_view: gpu.Texture_View,
    read_vis, write_vis: gpu.Shader_Stages,
) -> CTS_TU_Group {
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_texture(0, read_vis, .Unfilterable_Float, .D2),
        {binding = 1, visibility = write_vis, type = gpu.Storage_Texture_Binding_Layout{
            access = .Write_Only, format = .R32_Float, view_dimension = .D2}},
    })
    group := cts_pb_group(f.device, layout, []gpu.Bind_Group_Entry{
        {binding = 0, resource = sampled_view},
        {binding = 1, resource = storage_view},
    })
    return {layout = layout, group = group}
}

@(test)
cts_texture_usage_visibility_storage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    other := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    defer gpu.texture_release(other)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    other_view := cts_rp_view(other, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(other_view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)

    fragment := gpu.Shader_Stages{.Fragment}
    compute := gpu.Shader_Stages{.Compute}
    same_fragment := cts_tu_visibility_group(f, view, view, fragment, fragment)
    different_fragment := cts_tu_visibility_group(f, view, other_view, fragment, fragment)
    same_compute := cts_tu_visibility_group(f, view, view, fragment, compute)
    different_compute := cts_tu_visibility_group(f, view, other_view, fragment, compute)
    defer cts_tu_group_free(&same_fragment)
    defer cts_tu_group_free(&different_fragment)
    defer cts_tu_group_free(&same_compute)
    defer cts_tu_group_free(&different_compute)

    errors := cts_tu_pass_with_group(f, target, same_fragment.group)
    cts_expect_outcome(t, errors, true, "one texture sampled and written, fragment")
    errors = cts_tu_pass_with_group(f, target, different_fragment.group)
    cts_expect_outcome(t, errors, false, "two textures, fragment")
    errors = cts_tu_pass_with_group(f, target, same_compute.group)
    cts_expect_outcome(t, errors, true, "one texture sampled and written, compute binding")
    errors = cts_tu_pass_with_group(f, target, different_compute.group)
    cts_expect_outcome(t, errors, false, "two textures, compute binding")
}

@(test)
cts_texture_usage_visibility_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Render_Attachment})
    other := cts_tu_texture(f, {.Render_Attachment})
    defer gpu.texture_release(texture)
    defer gpu.texture_release(other)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    other_view := cts_rp_view(other, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(other_view)

    sampled := cts_tu_sampled_group(f, view, .D2)
    compute_group := cts_tu_sampled_group(f, view, .D2)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&compute_group)
    // Replace the compute group's layout visibility with compute.
    gpu.bind_group_release(compute_group.group)
    gpu.bind_group_layout_release(compute_group.layout)
    compute_group.layout = cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_texture(0, {.Compute}, .Unfilterable_Float, .D2),
    })
    compute_group.group = cts_pb_group(f.device, compute_group.layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = view}})

    errors := cts_tu_pass_with_group(f, view, sampled.group)
    cts_expect_outcome(t, errors, true, "sampled and attached in one pass")
    errors = cts_tu_pass_with_group(f, other_view, sampled.group)
    cts_expect_outcome(t, errors, false, "sampled while another is attached")
    errors = cts_tu_pass_with_group(f, view, compute_group.group)
    cts_expect_outcome(t, errors, true, "attached and sampled by a compute binding")
    errors = cts_tu_pass_with_group(f, other_view, compute_group.group)
    cts_expect_outcome(t, errors, false, "other attached, compute sampled")
}

cts_tu_two_use_row :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    first, second: gpu.Bind_Group,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, first, nil)
    gpu.render_pass_set_bind_group(pass, 1, second, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    return cts_errors() - before
}

@(test)
cts_texture_usage_unused_bindings_in_pipeline :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)
    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    targets := [1]gpu.Color_Target_State {
        {format = .R32_Float, write_mask = gpu.COLOR_WRITES_ALL},
    }
    unused_pipeline := cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
    defer gpu.render_pipeline_release(unused_pipeline)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_set_bind_group(pass, 1, storage.group, nil)
    gpu.render_pass_set_pipeline(pass, unused_pipeline)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "unused groups with a draw")
    errors := cts_tu_pass_with_group(f, target, sampled.group)
    cts_expect_outcome(t, errors, false, "unused sampled group without a draw")
    errors = cts_tu_pass_with_group(f, target, storage.group)
    cts_expect_outcome(t, errors, false, "unused storage group without a draw")
}

cts_tu_bundle_row :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    bundle_group: gpu.Bind_Group,
    direct_group: gpu.Bind_Group,
    direct_slot: u32,
) -> int {
    before := cts_errors()
    formats := [1]gpu.Texture_Format{.R32_Float}
    bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
        color_formats = formats[:], sample_count = 1,
    })
    gpu.render_bundle_encoder_set_bind_group(bundle_encoder, 0, bundle_group, nil)
    bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
    gpu.render_bundle_encoder_release(bundle_encoder)
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    if direct_group != {} {
        gpu.render_pass_set_bind_group(pass, direct_slot, direct_group, nil)
    }
    if bundle != {} {
        gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
    }
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    if bundle != {} {
        gpu.render_bundle_release(bundle)
    }
    return cts_errors() - before
}

@(test)
cts_texture_usage_bindings_in_bundle :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)
    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    errors := cts_tu_bundle_row(f, target, sampled.group, sampled.group, 1)
    cts_expect_outcome(t, errors, false, "two sampled bindings, one bundled")
    errors = cts_tu_bundle_row(f, target, sampled.group, storage.group, 1)
    cts_expect_outcome(t, errors, true, "bundled sampled and storage binding")
    errors = cts_tu_bundle_row(f, target, storage.group, storage.group, 1)
    cts_expect_outcome(t, errors, false, "two storage bindings, one bundled")

    before := cts_errors()
    formats := [1]gpu.Texture_Format{.R32_Float}
    bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
        color_formats = formats[:], sample_count = 1,
    })
    gpu.render_bundle_encoder_set_bind_group(bundle_encoder, 0, storage.group, nil)
    bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
    gpu.render_bundle_encoder_release(bundle_encoder)
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(view)},
    })
    gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "bundled storage against attachment")
    gpu.render_bundle_release(bundle)

    errors = cts_tu_bundle_row(f, target, sampled.group, {}, 0)
    cts_expect_outcome(t, errors, false, "bundled sampled with another attachment")
}

@(test)
cts_texture_usage_replaced_binding :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    first_texture := cts_tu_texture(f, {.Texture_Binding})
    defer gpu.texture_release(first_texture)
    second_texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(second_texture)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    first_view := cts_rp_view(first_texture, 0, 1, 0, 1)
    second_view := cts_rp_view(second_texture, 0, 1, 0, 1)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(first_view)
    defer gpu.texture_view_release(second_view)
    defer gpu.texture_view_release(target)
    sampled_first := cts_tu_sampled_group(f, first_view, .D2)
    sampled_second := cts_tu_sampled_group(f, second_view, .D2)
    storage_second := cts_tu_storage_group(f, second_view)
    defer cts_tu_group_free(&sampled_first)
    defer cts_tu_group_free(&sampled_second)
    defer cts_tu_group_free(&storage_second)

    replaced_row :: proc(
        t: ^testing.T,
        f: CTS_Fixture,
        target: gpu.Texture_View,
        group0, second, replacement: gpu.Bind_Group,
        draw: bool,
    ) {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
        })
        gpu.render_pass_set_bind_group(pass, 0, group0, nil)
        gpu.render_pass_set_bind_group(pass, 1, second, nil)
        if draw {
            targets := [1]gpu.Color_Target_State {
                {format = .R32_Float, write_mask = gpu.COLOR_WRITES_ALL},
            }
            pipeline := cts_make_render_pipeline_full(f.device, targets[:], nil, 1)
            gpu.render_pass_set_pipeline(pass, pipeline)
            gpu.render_pass_draw(pass, 3, 1, 0, 0)
            gpu.render_pipeline_release(pipeline)
        }
        gpu.render_pass_set_bind_group(pass, 0, replacement, nil)
        gpu.render_pass_end(pass)
        cts_ru_finish(f, encoder)
        _ = t
    }

    Row :: struct {second, replacement: gpu.Bind_Group, draw, fail: bool}
    rows := [4]Row{
        {sampled_second.group, sampled_second.group, false, false},
        {sampled_second.group, sampled_second.group, true, false},
        {storage_second.group, sampled_second.group, false, true},
        {storage_second.group, sampled_second.group, true, true},
    }
    for row in rows {
        before := cts_errors()
        replaced_row(t, f, target, sampled_first.group, row.second, row.replacement, row.draw)
        cts_expect_outcome(t, cts_errors() - before, row.fail, "replaced binding row")
    }
}

@(test)
cts_texture_usage_combination_aspect :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 3, 3, 1,
        {.Texture_Binding, .Render_Attachment})
    defer gpu.texture_release(texture)
    attachment := cts_tu_view(texture, 0, 0, .All)
    depth_cell := cts_tu_view(texture, 0, 0, .Depth_Only)
    stencil_cell := cts_tu_view(texture, 0, 0, .Stencil_Only)
    depth_mip1 := cts_tu_view(texture, 1, 0, .Depth_Only)
    depth_layer1 := cts_tu_view(texture, 0, 1, .Depth_Only)
    defer gpu.texture_view_release(attachment)
    defer gpu.texture_view_release(depth_cell)
    defer gpu.texture_view_release(stencil_cell)
    defer gpu.texture_view_release(depth_mip1)
    defer gpu.texture_view_release(depth_layer1)
    color_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(color_texture)
    color_target := cts_rp_view(color_texture)
    defer gpu.texture_view_release(color_target)

    depth := cts_tu_sampled_group(f, depth_cell, .D2, .Depth)
    stencil := cts_tu_sampled_group(f, stencil_cell, .D2, .Uint)
    depth_next_mip := cts_tu_sampled_group(f, depth_mip1, .D2, .Depth)
    depth_next_layer := cts_tu_sampled_group(f, depth_layer1, .D2, .Depth)
    defer cts_tu_group_free(&depth)
    defer cts_tu_group_free(&stencil)
    defer cts_tu_group_free(&depth_next_mip)
    defer cts_tu_group_free(&depth_next_layer)

    errors := cts_tu_two_use_row(f, color_target, depth.group, stencil.group)
    cts_expect_outcome(t, errors, false, "depth and stencil aspects sampled together")
    errors = cts_tu_two_use_row(f, color_target, depth.group, depth.group)
    cts_expect_outcome(t, errors, false, "one depth cell sampled twice")
    errors = cts_tu_two_use_row(f, color_target, depth.group, depth_next_mip.group)
    cts_expect_outcome(t, errors, false, "two depth mips sampled")
    cts_tu_ds_row(t, f, attachment, depth.group, false, false, true)
    cts_tu_ds_row(t, f, attachment, stencil.group, false, false, true)
    cts_tu_ds_row(t, f, attachment, depth.group, true, false, false)
    cts_tu_ds_row(t, f, attachment, depth_next_layer.group, false, false, false)
}

@(test)
cts_texture_usage_no_dispatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_tu_texture(f, {.Texture_Binding, .Storage_Binding})
    defer gpu.texture_release(texture)
    view := cts_rp_view(texture, 0, 1, 0, 1)
    defer gpu.texture_view_release(view)
    sampled := cts_tu_sampled_group(f, view, .D2)
    storage := cts_tu_storage_group(f, view)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)

    for row in 0 ..< 3 {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        if row != 2 {
            gpu.compute_pass_set_bind_group(pass, 0, sampled.group, nil)
        }
        if row != 1 {
            gpu.compute_pass_set_bind_group(pass, 1, storage.group, nil)
        }
        gpu.compute_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, false, "compute bindings without dispatch")
    }
}

@(test)
cts_texture_usage_combination_color :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 3, 3, 1,
        {.Texture_Binding, .Storage_Binding, .Render_Attachment})
    defer gpu.texture_release(texture)
    cell := cts_rp_view(texture, 0, 1, 0, 1)
    next_mip := cts_rp_view(texture, 1, 1, 0, 1)
    next_layer := cts_rp_view(texture, 0, 1, 1, 1)
    all_mips := cts_rp_view(texture, 0, 3, 0, 1)
    defer gpu.texture_view_release(cell)
    defer gpu.texture_view_release(next_mip)
    defer gpu.texture_view_release(next_layer)
    defer gpu.texture_view_release(all_mips)
    target_texture := cts_rp_texture(f.device, .R32_Float, 16, 16, 1, 1, 1,
        {.Render_Attachment})
    defer gpu.texture_release(target_texture)
    target := cts_rp_view(target_texture)
    defer gpu.texture_view_release(target)

    sampled := cts_tu_sampled_group(f, cell, .D2)
    storage := cts_tu_storage_group(f, cell)
    sampled_mip1 := cts_tu_sampled_group(f, next_mip, .D2)
    storage_mip1 := cts_tu_storage_group(f, next_mip)
    sampled_layer1 := cts_tu_sampled_group(f, next_layer, .D2)
    storage_layer1 := cts_tu_storage_group(f, next_layer)
    sampled_chain := cts_tu_sampled_group(f, all_mips, .D2)
    defer cts_tu_group_free(&sampled)
    defer cts_tu_group_free(&storage)
    defer cts_tu_group_free(&sampled_mip1)
    defer cts_tu_group_free(&storage_mip1)
    defer cts_tu_group_free(&sampled_layer1)
    defer cts_tu_group_free(&storage_layer1)
    defer cts_tu_group_free(&sampled_chain)

    Row :: struct {first, second: gpu.Bind_Group, fail: bool}
    rows := [6]Row{
        {sampled.group, storage.group, true},
        {sampled.group, storage_mip1.group, false},
        {sampled.group, storage_layer1.group, false},
        {sampled_chain.group, storage_mip1.group, true},
        {sampled.group, sampled_mip1.group, false},
        {storage.group, storage_mip1.group, false},
    }
    for row in rows {
        errors := cts_tu_two_use_row(f, target, row.first, row.second)
        cts_expect_outcome(t, errors, row.fail, "color combination row")
    }

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(cell)},
    })
    gpu.render_pass_set_bind_group(pass, 0, storage.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "storage binding and attachment")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(next_layer)},
    })
    gpu.render_pass_set_bind_group(pass, 0, sampled.group, nil)
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, false, "sampled binding and other layer")

    before = cts_errors()
    encoder = gpu.device_create_command_encoder(f.device)
    pass = gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{
            cts_rp_color(cell), cts_rp_color(cell),
        },
    })
    gpu.render_pass_end(pass)
    cts_ru_finish(f, encoder)
    cts_expect_outcome(t, cts_errors() - before, true, "cell attached twice")
}
