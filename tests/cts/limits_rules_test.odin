package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/limits/*` rules that are creation-time
// checks: per-stage resource budgets, dynamic
// buffer budgets, maxBindGroups and maxBindingsPerBindGroup, each on a device
// with a deliberately small requested limit.

cts_limits_device :: proc(
    f: CTS_Fixture,
    limits: gpu.Limits,
) -> (gpu.Device, bool) {
    descriptor := gpu.Device_Descriptor{required_limits = limits}
    device := cts_make_device(f.adapter, descriptor)
    return device, device != nil
}

cts_limits_base :: proc() -> gpu.Limits {
    return gpu.DEFAULT_LIMITS
}

@(test)
cts_limit_max_resources_per_stage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_uniform_buffers_per_shader_stage = 4
    limits.max_storage_buffers_per_shader_stage = 2
    limits.max_samplers_per_shader_stage = 3
    limits.max_sampled_textures_per_shader_stage = 5
    limits.max_storage_textures_per_shader_stage = 2
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    check :: proc(
        t: ^testing.T,
        device: gpu.Device,
        entry_of: proc(binding: u32) -> gpu.Bind_Group_Layout_Entry,
        at: u32,
        over: u32,
        what: string,
    ) {
        entries_at := make([]gpu.Bind_Group_Layout_Entry, at, context.temp_allocator)
        for i in 0 ..< at {
            entries_at[i] = entry_of(u32(i))
        }
        cts_expect_outcome(t, cts_layout_errors(device, entries_at), false, what)
        entries_over := make([]gpu.Bind_Group_Layout_Entry, over, context.temp_allocator)
        for i in 0 ..< over {
            entries_over[i] = entry_of(u32(i))
        }
        cts_expect_outcome(t, cts_layout_errors(device, entries_over), true, what)
    }

    check(t, device, proc(binding: u32) -> gpu.Bind_Group_Layout_Entry {
        return cts_layout_buffer(binding, {.Compute}, .Uniform)
    }, 4, 5, "uniform buffer per-stage budget")
    check(t, device, proc(binding: u32) -> gpu.Bind_Group_Layout_Entry {
        return cts_layout_buffer(binding, {.Compute}, .Storage)
    }, 2, 3, "storage buffer per-stage budget")
    check(t, device, proc(binding: u32) -> gpu.Bind_Group_Layout_Entry {
        return cts_layout_sampler(binding, {.Compute})
    }, 3, 4, "sampler per-stage budget")
    check(t, device, proc(binding: u32) -> gpu.Bind_Group_Layout_Entry {
        return cts_layout_texture(binding, {.Compute}, .Float, .D2)
    }, 5, 6, "sampled texture per-stage budget")
    check(t, device, proc(binding: u32) -> gpu.Bind_Group_Layout_Entry {
        return cts_layout_storage(binding, {.Compute}, .Write_Only, .RGBA8_Unorm)
    }, 2, 3, "storage texture per-stage budget")
}

@(test)
cts_limit_max_dynamic_buffers :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_dynamic_uniform_buffers_per_pipeline_layout = 2
    limits.max_dynamic_storage_buffers_per_pipeline_layout = 1
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    uniform_three := make([]gpu.Bind_Group_Layout_Entry, 3, context.temp_allocator)
    for i in 0 ..< 3 {
        uniform_three[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    cts_expect_outcome(t, cts_layout_errors(device, uniform_three[:2]), false,
        "two dynamic uniform buffers at the budget")
    cts_expect_outcome(t, cts_layout_errors(device, uniform_three[:]), true,
        "three dynamic uniform buffers past the budget")

    storage_two := make([]gpu.Bind_Group_Layout_Entry, 2, context.temp_allocator)
    for i in 0 ..< 2 {
        storage_two[i] = cts_layout_buffer(u32(i), {.Compute}, .Storage, true)
    }
    cts_expect_outcome(t, cts_layout_errors(device, storage_two[:1]), false,
        "one dynamic storage buffer at the budget")
    cts_expect_outcome(t, cts_layout_errors(device, storage_two[:]), true,
        "two dynamic storage buffers past the budget")
}

@(test)
cts_limit_max_bind_groups :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_bind_groups = 2
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    empty := cts_layout_create(device, nil)
    if empty == {} {
        return
    }
    defer gpu.bind_group_layout_release(empty)
    cts_expect_outcome(t, cts_pipeline_layout_errors(device,
        []gpu.Bind_Group_Layout{empty, empty}), false,
        "two bind groups at the budget")
    cts_expect_outcome(t, cts_pipeline_layout_errors(device,
        []gpu.Bind_Group_Layout{empty, empty, empty}), true,
        "three bind groups past the budget")
}

@(test)
cts_limit_color_attachment_bytes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_color_attachment_bytes_per_sample = 8
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)
    fixture := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = device}

    texture_a := cts_rp_texture(device, .RGBA8_Unorm, 4, 4)
    texture_b := cts_rp_texture(device, .RGBA8_Unorm, 4, 4)
    view_a := cts_rp_view(texture_a)
    view_b := cts_rp_view(texture_b)
    defer gpu.texture_release(texture_a)
    defer gpu.texture_release(texture_b)
    defer gpu.texture_view_release(view_a)
    defer gpu.texture_view_release(view_b)

    one := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view_a)}
    cts_expect_outcome(t, cts_try_render_pass(t, fixture, {
        color_attachments = one[:],
    }) ? 1 : 0, false, "one RGBA8 attachment at the budget")

    two := [2]gpu.Render_Pass_Color_Attachment{cts_rp_color(view_a), cts_rp_color(view_b)}
    cts_expect_outcome(t, cts_try_render_pass(t, fixture, {
        color_attachments = two[:],
    }) ? 1 : 0, true, "two RGBA8 attachments over the budget")
}

@(test)
cts_limit_compute_workgroups :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_compute_workgroups_per_dimension = 4
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)
    fixture := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = device}
    pipeline := cts_make_compute_pipeline(device)
    if pipeline == {} {
        return
    }
    defer gpu.compute_pipeline_release(pipeline)

    cts_expect_outcome(t, cts_compute_run(t, fixture, pipeline, {4, 4, 4}, {}, false) ? 1 : 0,
        false, "dispatch at the workgroup limit")
    overs := [3][3]u32{{5, 1, 1}, {1, 5, 1}, {1, 1, 5}}
    for sizes in overs {
        cts_expect_outcome(t, cts_compute_run(t, fixture, pipeline, sizes, {}, false) ? 1 : 0,
            true, "dispatch one workgroup past the limit")
    }
}

@(test)
cts_limit_uniform_binding_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_uniform_buffer_binding_size = 64
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    uniform_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Uniform))
    storage_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Storage))
    defer gpu.bind_group_layout_release(uniform_layout)
    defer gpu.bind_group_layout_release(storage_layout)
    buffer := gpu.device_create_buffer(device, {size = 256, usage = {.Uniform, .Storage}})
    defer gpu.buffer_release(buffer)

    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 64)}), false,
        "uniform range at the binding-size limit")
    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 68)}), true,
        "uniform range past the binding-size limit")
    cts_expect_outcome(t, cts_bg_errors(device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 68)}), false,
        "storage range past the uniform limit")
}

@(test)
cts_limit_storage_binding_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_storage_buffer_binding_size = 64
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    uniform_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Uniform))
    storage_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Storage))
    defer gpu.bind_group_layout_release(uniform_layout)
    defer gpu.bind_group_layout_release(storage_layout)
    buffer := gpu.device_create_buffer(device, {size = 256, usage = {.Uniform, .Storage}})
    defer gpu.buffer_release(buffer)

    cts_expect_outcome(t, cts_bg_errors(device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 64)}), false,
        "storage range at the binding-size limit")
    cts_expect_outcome(t, cts_bg_errors(device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 68)}), true,
        "storage range past the binding-size limit")
    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 68)}), false,
        "uniform range past the storage limit")
}

@(test)
cts_limit_dynamic_offset_range :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_buffer(0, {.Compute}, .Uniform, true),
    })
    defer gpu.bind_group_layout_release(layout)
    buffer := gpu.device_create_buffer(f.device, {size = 512, usage = {.Uniform}})
    defer gpu.buffer_release(buffer)
    group := cts_pb_group(f.device, layout,
        []gpu.Bind_Group_Entry{{binding = 0, resource = gpu.Buffer_Binding{
            buffer = buffer, offset = 0, size = 512}}})
    defer gpu.bind_group_release(group)

    run :: proc(t: ^testing.T, f: CTS_Fixture, group: gpu.Bind_Group, offset: u32, fail: bool) {
        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_bind_group(pass, 0, group, []u32{offset})
        gpu.compute_pass_end(pass)
        cts_ru_finish(f, encoder)
        cts_expect_outcome(t, cts_errors() - before, fail, "dynamic offset row")
    }

    run(t, f, group, 0, false)
    run(t, f, group, 256, true)
}

@(test)
cts_limit_buffer_offset_alignments :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.min_uniform_buffer_offset_alignment = 512
    limits.min_storage_buffer_offset_alignment = 1024
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    uniform_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Uniform))
    storage_layout := cts_bg_layout(device, cts_bg_buffer_layout(.Storage))
    defer gpu.bind_group_layout_release(uniform_layout)
    defer gpu.bind_group_layout_release(storage_layout)
    buffer := gpu.device_create_buffer(device, {size = 2048, usage = {.Uniform, .Storage}})
    defer gpu.buffer_release(buffer)

    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 16)}), false, "offset 0")
    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 512, 16)}), false,
        "uniform offset at the alignment")
    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 256, 16)}), true,
        "uniform offset under the alignment")
    cts_expect_outcome(t, cts_bg_errors(device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 1024, 16)}), false,
        "storage offset at the alignment")
    cts_expect_outcome(t, cts_bg_errors(device, storage_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 512, 16)}), true,
        "storage offset under the alignment")
    cts_expect_outcome(t, cts_bg_errors(device, uniform_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 512, 16)}), false,
        "uniform offset the storage alignment would refuse")
}

cts_limits_vertex_pipeline :: proc(
    device: gpu.Device,
    attribute_count: u32,
    stride: u64,
) -> gpu.Render_Pipeline {
    attributes := make([]gpu.Vertex_Attribute, attribute_count, context.temp_allocator)
    for i in 0 ..< attribute_count {
        attributes[i] = {
            format          = .Float32,
            offset          = u64(i) * 4,
            shader_location = i,
        }
    }
    layouts := [1]gpu.Vertex_Buffer_Layout {
        {array_stride = stride, step_mode = .Vertex, attributes = attributes},
    }
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    return cts_make_render_pipeline_full(
        device, targets[:], nil, 1, .Triangle_List, .Undefined, layouts[:])
}

@(test)
cts_limit_vertex_attributes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    count := limits.max_vertex_attributes

    pipeline := cts_limits_vertex_pipeline(f.device, count, u64(count) * 4)
    cts_expect_outcome(t, pipeline != {} ? 0 : 1, false,
        "as many attributes as the device allows")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }

    pipeline = cts_limits_vertex_pipeline(f.device, count + 1, u64(count + 1) * 4)
    cts_expect_outcome(t, pipeline != {} ? 0 : 1, true,
        "one attribute past the device limit")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }
}

@(test)
cts_limit_vertex_array_stride :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    stride := u64(limits.max_vertex_buffer_array_stride)

    pipeline := cts_limits_vertex_pipeline(f.device, 1, stride)
    cts_expect_outcome(t, pipeline != {} ? 0 : 1, false,
        "array stride at the device limit")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }

    pipeline = cts_limits_vertex_pipeline(f.device, 1, stride + 4)
    cts_expect_outcome(t, pipeline != {} ? 0 : 1, true,
        "array stride one step past the device limit")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }
}

@(test)
cts_limit_max_color_attachments :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_color_attachments = 4
    limits.max_color_attachment_bytes_per_sample = 64
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)
    fixture := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = device}

    textures: [5]gpu.Texture
    views: [5]gpu.Texture_View
    attachments: [5]gpu.Render_Pass_Color_Attachment
    defer for i in 0 ..< 5 {
        gpu.texture_view_release(views[i])
        gpu.texture_release(textures[i])
    }
    for i in 0 ..< 5 {
        textures[i] = cts_rp_texture(device, .RGBA8_Unorm, 4, 4)
        views[i] = cts_rp_view(textures[i])
        attachments[i] = cts_rp_color(views[i])
    }

    cts_expect_outcome(t, cts_try_render_pass(t, fixture, {
        color_attachments = attachments[:4],
    }) ? 1 : 0, false, "a pass at max_color_attachments")
    cts_expect_outcome(t, cts_try_render_pass(t, fixture, {
        color_attachments = attachments[:],
    }) ? 1 : 0, true, "a pass past max_color_attachments")
}

@(test)
cts_limit_max_bindings_per_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := cts_limits_base()
    limits.max_bindings_per_bind_group = 4
    device, ok := cts_limits_device(f, limits)
    if !ok {
        return
    }
    defer gpu.device_release(device)

    four := make([]gpu.Bind_Group_Layout_Entry, 4, context.temp_allocator)
    for i in 0 ..< 4 {
        four[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    cts_expect_outcome(t, cts_layout_errors(device, four[:]), false,
        "four bindings at the budget")

    five := make([]gpu.Bind_Group_Layout_Entry, 5, context.temp_allocator)
    for i in 0 ..< 5 {
        five[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    cts_expect_outcome(t, cts_layout_errors(device, five[:]), true,
        "five bindings past the budget")

    one := [1]gpu.Bind_Group_Layout_Entry{cts_layout_buffer(4, {.Compute}, .Uniform)}
    cts_expect_outcome(t, cts_layout_errors(device, one[:]), true,
        "a binding number at the budget")
}
