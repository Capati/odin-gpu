package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/setBindGroup.spec.ts`:
// group device ownership, dynamic
// offset count/alignment/range, and the group slot budget.

cts_sb_submit :: proc(f: CTS_Fixture, command_buffer: gpu.Command_Buffer) {
    if command_buffer == {} {
        return
    }
    queue := gpu.device_get_queue(f.device)
    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
    gpu.queue_release(queue)
    gpu.command_buffer_release(command_buffer)
}

cts_sb_run :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: uint,
    index: u32,
    group: gpu.Bind_Group,
    offsets: []u32,
) -> bool {
    before := cts_errors()
    switch kind {
    case 0:
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_bind_group(pass, index, group, offsets)
        gpu.compute_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        cts_sb_submit(f, command_buffer)
        gpu.command_encoder_release(encoder)
    case 1:
        encoder := gpu.device_create_command_encoder(f.device)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Load, store = .Store}},
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        gpu.render_pass_set_bind_group(pass, index, group, offsets)
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        cts_sb_submit(f, command_buffer)
        gpu.command_encoder_release(encoder)
    case:
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        gpu.render_bundle_encoder_set_bind_group(bundle_encoder, index, group, offsets)
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        gpu.render_bundle_encoder_release(bundle_encoder)

        encoder := gpu.device_create_command_encoder(f.device)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Load, store = .Store}},
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        if bundle != {} {
            gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        cts_sb_submit(f, command_buffer)
        gpu.command_encoder_release(encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
    }
    return cts_errors() - before > 0
}

cts_sb_stage :: proc(kind: uint) -> gpu.Shader_Stages {
    return kind == 0 ? gpu.Shader_Stages{.Compute} : gpu.Shader_Stages{.Fragment}
}

@(test)
cts_set_bind_group_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for kind in 0 ..< 3 {
        for mismatched in 0 ..< 2 {
            source := mismatched != 0 ? other : f.device
            has_dynamic := kind == 2
            entry := cts_layout_buffer(0, cts_sb_stage(uint(kind)), .Uniform, has_dynamic)
            layout := cts_layout_create(source, []gpu.Bind_Group_Layout_Entry{entry})
            buffer := gpu.device_create_buffer(source, {size = 4, usage = {.Uniform}})
            group := gpu.device_create_bind_group(source, {
                layout  = layout,
                entries = []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)},
            })
            offsets := has_dynamic ? []u32{0} : []u32{}
            errors := cts_sb_run(t, f, view, uint(kind), 0, group, offsets)
            cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0, "setBindGroup device row")
            if group != {} {
                gpu.bind_group_release(group)
            }
            gpu.buffer_release(buffer)
            if layout != {} {
                gpu.bind_group_layout_release(layout)
            }
        }
    }
}

@(test)
cts_set_bind_group_offsets_unexpected :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    for kind in 0 ..< 3 {
        entry := cts_layout_buffer(0, cts_sb_stage(uint(kind)), .Uniform)
        layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{entry})
        buffer := gpu.device_create_buffer(f.device, {size = 4, usage = {.Uniform}})
        group := gpu.device_create_bind_group(f.device, {
            layout  = layout,
            entries = []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)},
        })
        errors := cts_sb_run(t, f, view, uint(kind), 0, group, []u32{0})
        cts_expect_outcome(t, errors ? 1 : 0, true, "offsets for a group with no dynamic binding")
        gpu.bind_group_release(group)
        gpu.buffer_release(buffer)
        gpu.bind_group_layout_release(layout)
    }
}

@(test)
cts_set_bind_group_dynamic_offsets :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        offsets:  [3]u32,
        count:    int,
        accepted: bool,
    }
    rows := [11]Row{
        {{256, 0, 0}, 2, true},
        {{1, 2, 0}, 2, false},
        {{256, 0, 0}, 3, false},
        {{256, 0, 0}, 1, false},
        {{256, 0, 0}, 0, false},
        {{512, 0, 0}, 2, false},
        {{1024, 0, 0}, 2, false},
        {{max(u32), 0, 0}, 2, false},
        {{0, 512, 0}, 2, false},
        {{0, 1024, 0}, 2, false},
        {{0, max(u32), 0}, 2, false},
    }

    for kind in 0 ..< 3 {
        for use_storage in 0 ..< 2 {
            stage := cts_sb_stage(uint(kind))
            entries := [2]gpu.Bind_Group_Layout_Entry {
                cts_layout_buffer(0, stage, .Uniform, true),
                cts_layout_buffer(1, stage, use_storage != 0 ? .Storage : .Uniform, true),
            }
            layout := cts_layout_create(f.device, entries[:])
            uniform_buffer := gpu.device_create_buffer(f.device, {size = 520, usage = {.Uniform}})
            second_buffer := gpu.device_create_buffer(f.device, {
                size = 520, usage = use_storage != 0 ? gpu.Buffer_Usages{.Storage} :
                    gpu.Buffer_Usages{.Uniform},
            })
            group := gpu.device_create_bind_group(f.device, {
                layout = layout,
                entries = []gpu.Bind_Group_Entry{
                    cts_bg_buffer_entry(uniform_buffer, 0, 12),
                    {binding = 1, resource = gpu.Buffer_Binding{
                        buffer = second_buffer, offset = 0, size = 12}},
                },
            })
            for row in rows {
                offsets := row.offsets
                errors := cts_sb_run(t, f, view, uint(kind), 0, group,
                    offsets[:row.count])
                cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "dynamic offset row")
            }
            gpu.bind_group_release(group)
            gpu.buffer_release(uniform_buffer)
            gpu.buffer_release(second_buffer)
            gpu.bind_group_layout_release(layout)
        }
    }
}

@(test)
cts_set_bind_group_state_and_index :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    limits := gpu.device_get_limits(f.device)

    for kind in 0 ..< 3 {
        indices := [3]u32{1, limits.max_bind_groups - 1, limits.max_bind_groups}
        for state in 0 ..< 3 {
            for texture in 0 ..< 2 {
                for index in indices {
                    stage := cts_sb_stage(uint(kind))
                    layout: gpu.Bind_Group_Layout
                    group: gpu.Bind_Group
                    buffer: gpu.Buffer
                    resource: gpu.Texture
                    resource_view: gpu.Texture_View
                    if state != 1 {
                        if texture != 0 {
                            layout = cts_layout_create(f.device,
                                []gpu.Bind_Group_Layout_Entry{
                                    cts_layout_texture(index, stage, .Float, .D2),
                                })
                            resource = cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1,
                                {.Texture_Binding})
                            resource_view = gpu.texture_create_view(resource)
                            group = gpu.device_create_bind_group(f.device, {
                                layout = layout,
                                entries = []gpu.Bind_Group_Entry{
                                    {binding = index, resource = resource_view},
                                },
                            })
                        } else {
                            layout = cts_layout_create(f.device,
                                []gpu.Bind_Group_Layout_Entry{
                                    cts_layout_buffer(index, stage, .Uniform),
                                })
                            buffer = gpu.device_create_buffer(f.device, {
                                size = 4, usage = {.Uniform},
                            })
                            group = gpu.device_create_bind_group(f.device, {
                                layout = layout,
                                entries = []gpu.Bind_Group_Entry{
                                    {binding = index, resource = gpu.Buffer_Binding{
                                        buffer = buffer, size = gpu.WHOLE_SIZE}},
                                },
                            })
                        }
                        if state == 2 {
                            if texture != 0 {
                                gpu.texture_destroy(resource)
                            } else {
                                gpu.buffer_destroy(buffer)
                            }
                        }
                    }
                    errors := cts_sb_run(t, f, view, uint(kind), index, group, nil)
                    // A null group unbinds the slot; a destroyed resource makes
                    // the group unusable. An index at or past max_bind_groups is
                    // always invalid.
                    cts_expect_outcome(t, errors ? 1 : 0,
                        state == 2 || index >= limits.max_bind_groups,
                        fmt.tprintf("kind %d state %d tex %d idx %d", kind, state, texture,
                            index))
                    if group != {} {
                        gpu.bind_group_release(group)
                    }
                    if state != 2 {
                        if texture != 0 {
                            if resource != {} {
                                gpu.texture_release(resource)
                            }
                        } else if buffer != {} {
                            gpu.buffer_release(buffer)
                        }
                    } else if texture != 0 {
                        if resource != {} {
                            gpu.texture_release(resource)
                        }
                    } else if buffer != {} {
                        gpu.buffer_release(buffer)
                    }
                    if resource_view != {} {
                        gpu.texture_view_release(resource_view)
                    }
                    if layout != {} {
                        gpu.bind_group_layout_release(layout)
                    }
                }
            }
        }
    }
}

@(test)
cts_set_bind_group_buffer_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)

    Row :: struct {
        offset:   u32,
        accepted: bool,
    }
    rows := [5]Row{
        {256, true},
        {128, false},
        {384, false},
        {512, true},
        {258, false},
    }
    types := [3]gpu.Buffer_Binding_Type{.Uniform, .Storage, .Read_Only_Storage}
    for kind in 0 ..< 3 {
        for type in types {
            stage := cts_sb_stage(uint(kind))
            entry := cts_layout_buffer(0, stage, type, true)
            layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{entry})
            usage: gpu.Buffer_Usages = {.Uniform}
            if type != .Uniform {
                usage = {.Storage}
            }
            buffer := gpu.device_create_buffer(f.device, {size = 768, usage = usage})
            group := gpu.device_create_bind_group(f.device, {
                layout  = layout,
                entries = []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 12)},
            })
            for row in rows {
                errors := cts_sb_run(t, f, view, uint(kind), 0, group, []u32{row.offset})
                cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "dynamic offset alignment row")
            }
            gpu.bind_group_release(group)
            gpu.buffer_release(buffer)
            gpu.bind_group_layout_release(layout)
        }
    }
}
