package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/pipeline_bindgroup.spec.ts`:
// a pipeline layout requires a group
// in every non-empty slot, bound groups must be definition-equivalent to the
// child layout, empty layouts never require groups, and extra slots are ignored.

cts_pb_buffer_layout :: proc(
    device: gpu.Device,
    visibility: gpu.Shader_Stages,
    type: gpu.Buffer_Binding_Type,
    has_dynamic: bool,
) -> gpu.Bind_Group_Layout {
    return cts_layout_create(device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_buffer(0, visibility, type, has_dynamic),
    })
}

cts_pb_pipeline_layout :: proc(
    device: gpu.Device,
    children: []gpu.Bind_Group_Layout,
) -> gpu.Pipeline_Layout {
    return gpu.device_create_pipeline_layout(device, {bind_group_layouts = children})
}

cts_pb_compute_pipeline :: proc(device: gpu.Device, layout: gpu.Pipeline_Layout) -> gpu.Compute_Pipeline {
    module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = COMPUTE_SPIRV},
    })
    if module == {} {
        return {}
    }
    defer gpu.shader_module_release(module)
    return gpu.device_create_compute_pipeline(device, {
        layout = layout, module = module, entry_point = "main",
    })
}

cts_pb_render_pipeline :: proc(device: gpu.Device, layout: gpu.Pipeline_Layout) -> gpu.Render_Pipeline {
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    return cts_make_render_pipeline_full(
        device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, layout)
}

cts_pb_group :: proc(
    device: gpu.Device,
    layout: gpu.Bind_Group_Layout,
    entries: []gpu.Bind_Group_Entry,
) -> gpu.Bind_Group {
    if layout == {} {
        return {}
    }
    return gpu.device_create_bind_group(device, {layout = layout, entries = entries})
}

cts_pb_finish :: proc(device: gpu.Device, command_buffer: gpu.Command_Buffer) {
    if command_buffer == {} {
        return
    }
    queue := gpu.device_get_queue(device)
    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
    gpu.queue_release(queue)
    gpu.command_buffer_release(command_buffer)
}

// Run one validation arm. `present[i]` selects groups to bind at slot `i`;
// `dynamic_count` is the number of dynamic offsets each group needs.
cts_pb_run :: proc(
    device: gpu.Device,
    view: gpu.Texture_View,
    kind: int,
    pipeline_layout: gpu.Pipeline_Layout,
    groups: []gpu.Bind_Group,
    present: []bool,
    dynamic_count: int,
    do_call: bool,
) -> int {
    before := cts_errors()
    offset_storage: [4][3]u32
    switch kind {
    case 0:
        pipeline := cts_pb_compute_pipeline(device, pipeline_layout)
        defer if pipeline != {} { gpu.compute_pipeline_release(pipeline) }
        encoder := gpu.device_create_command_encoder(device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_pipeline(pass, pipeline)
        for group, i in groups {
            if i >= len(present) || !present[i] {
                continue
            }
            offsets := offset_storage[i][:dynamic_count]
            gpu.compute_pass_set_bind_group(pass, u32(i), group, offsets)
        }
        if do_call {
            gpu.compute_pass_dispatch_workgroups(pass, 1, 1, 1)
        }
        gpu.compute_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        cts_pb_finish(device, command_buffer)
    case 1:
        pipeline := cts_pb_render_pipeline(device, pipeline_layout)
        defer if pipeline != {} { gpu.render_pipeline_release(pipeline) }
        encoder := gpu.device_create_command_encoder(device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{
                {view = view, ops = {load = .Load, store = .Store}},
            },
        })
        gpu.render_pass_set_pipeline(pass, pipeline)
        for group, i in groups {
            if i >= len(present) || !present[i] {
                continue
            }
            offsets := offset_storage[i][:dynamic_count]
            gpu.render_pass_set_bind_group(pass, u32(i), group, offsets)
        }
        if do_call {
            gpu.render_pass_draw(pass, 3, 1, 0, 0)
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        cts_pb_finish(device, command_buffer)
    case:
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(device, {
            color_formats = formats[:], sample_count = 1,
        })
        bundle_pipeline := cts_pb_render_pipeline(device, pipeline_layout)
        defer if bundle_pipeline != {} { gpu.render_pipeline_release(bundle_pipeline) }
        gpu.render_bundle_encoder_set_pipeline(bundle_encoder, bundle_pipeline)
        for group, i in groups {
            if i >= len(present) || !present[i] {
                continue
            }
            offsets := offset_storage[i][:dynamic_count]
            gpu.render_bundle_encoder_set_bind_group(bundle_encoder, u32(i), group, offsets)
        }
        if do_call {
            gpu.render_bundle_encoder_draw(bundle_encoder, 3, 1, 0, 0)
        }
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        gpu.render_bundle_encoder_release(bundle_encoder)

        encoder := gpu.device_create_command_encoder(device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{
                {view = view, ops = {load = .Load, store = .Store}},
            },
        })
        if bundle != {} {
            gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        cts_pb_finish(device, command_buffer)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
    }
    return cts_errors() - before
}

cts_pb_view :: proc(device: gpu.Device) -> (gpu.Texture, gpu.Texture_View) {
    texture := gpu.device_create_texture(device, {
        usage           = {.Render_Attachment},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    return texture, gpu.texture_create_view(texture)
}

@(test)
cts_pipeline_bindgroup_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)

    Row :: struct {set0, set1, unused, success: bool}
    rows := [5]Row{
        {true, true, true, true},
        {true, true, false, true},
        {true, false, true, false},
        {false, true, true, false},
        {false, false, false, false},
    }
    for kind in 0 ..< 3 {
        for row, row_index in rows {
            for has_dynamic in 0 ..< 2 {
                visibility := kind == 0 ? gpu.Shader_Stages{.Compute} :
                    gpu.Shader_Stages{.Fragment}
                type := kind == 0 ? gpu.Buffer_Binding_Type.Storage : .Uniform
                layout0 := cts_pb_buffer_layout(f.device, visibility, type, has_dynamic != 0)
                layout1 := cts_pb_buffer_layout(f.device, visibility, type, has_dynamic != 0)
                children := [2]gpu.Bind_Group_Layout{layout0, layout1}
                pipeline_layout := cts_pb_pipeline_layout(f.device, children[:])
                buffer := gpu.device_create_buffer(f.device, {
                    size = 16, usage = kind == 0 ? gpu.Buffer_Usages{.Storage} :
                        gpu.Buffer_Usages{.Uniform},
                })
                groups: [3]gpu.Bind_Group
                present: [3]bool
                if row.set0 {
                    groups[0] = cts_pb_group(f.device, layout0,
                        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)})
                    present[0] = true
                }
                if row.set1 {
                    groups[1] = cts_pb_group(f.device, layout1,
                        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)})
                    present[1] = true
                }
                if row.unused {
                    groups[2] = cts_pb_group(f.device, layout1,
                        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)})
                    present[2] = true
                }
                for call_arm in 0 ..< 2 {
                    errors := cts_pb_run(f.device, view, kind, pipeline_layout,
                        groups[:], present[:], has_dynamic != 0 ? 1 : 0, call_arm == 1)
                    cts_expect_outcome(t, errors, call_arm == 1 && !row.success,
                        fmt.tprintf("mismatch kind %d row %d dynamic %d call %d", kind,
                            row_index, has_dynamic, call_arm))
                }
                for group, i in groups {
                    if present[i] {
                        gpu.bind_group_release(group)
                    }
                }
                gpu.buffer_release(buffer)
                gpu.pipeline_layout_release(pipeline_layout)
                gpu.bind_group_layout_release(layout1)
                gpu.bind_group_layout_release(layout0)
            }
        }
    }
}

cts_pb_run_empty :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: int,
    use_null: bool,
    set_count: int,
    call: bool,
) {
    group_layout := cts_layout_create(f.device, nil)
    children: [4]gpu.Bind_Group_Layout
    if !use_null {
        for i in 0 ..< 4 {
            children[i] = group_layout
        }
    }
    pipeline_layout := cts_pb_pipeline_layout(f.device, children[:])
    empty_group := cts_pb_group(f.device, group_layout, nil)
    groups: [4]gpu.Bind_Group
    present: [4]bool
    for i in 0 ..< set_count {
        groups[i] = empty_group
        present[i] = true
    }
    errors := cts_pb_run(f.device, view, kind, pipeline_layout, groups[:], present[:], 0, call)
    cts_expect_outcome(t, errors, false, "empty bind group layouts")
    gpu.bind_group_release(empty_group)
    gpu.pipeline_layout_release(pipeline_layout)
    gpu.bind_group_layout_release(group_layout)
}

@(test)
cts_pipeline_bindgroup_empty_compute :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for use_null in 0 ..< 2 {
        for call in 0 ..< 2 {
            for set_count in ([3]int{0, 3, 4}) {
                cts_pb_run_empty(t, f, {}, 0, use_null != 0, set_count, call != 0)
            }
        }
    }
}

@(test)
cts_pipeline_bindgroup_empty_render :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    for use_null in 0 ..< 2 {
        for call in 0 ..< 2 {
            for set_count in ([3]int{0, 3, 4}) {
                cts_pb_run_empty(t, f, view, 1, use_null != 0, set_count, call != 0)
            }
        }
    }
}

cts_pb_run_equivalence :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: int,
    group: gpu.Bind_Group,
    pipeline_child: gpu.Bind_Group_Layout,
    dynamic_count: int,
    success: bool,
) {
    children := [1]gpu.Bind_Group_Layout{pipeline_child}
    pipeline_layout := cts_pb_pipeline_layout(f.device, children[:])
    groups: [3]gpu.Bind_Group
    present: [3]bool
    groups[0] = group
    present[0] = true
    for call_arm in 0 ..< 2 {
        errors := cts_pb_run(f.device, view, kind, pipeline_layout, groups[:], present[:],
            dynamic_count, call_arm == 1)
        cts_expect_outcome(t, errors, call_arm == 1 && !success,
            fmt.tprintf("equivalence kind %d success %v call %d", kind, success, call_arm))
    }
    gpu.pipeline_layout_release(pipeline_layout)
}

@(test)
cts_pipeline_bindgroup_equivalence_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    types := [3]gpu.Buffer_Binding_Type{.Uniform, .Read_Only_Storage, .Storage}
    for kind in 0 ..< 3 {
        visibility := kind == 0 ? gpu.Shader_Stages{.Compute} : gpu.Shader_Stages{.Fragment}
        group_layout := cts_pb_buffer_layout(f.device, visibility, .Uniform, false)
        buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Uniform}})
        group := cts_pb_group(f.device, group_layout,
            []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)})
        for type in types {
            child := cts_pb_buffer_layout(f.device, visibility, type, false)
            cts_pb_run_equivalence(t, f, view, kind, group, child, 0, type == .Uniform)
            gpu.bind_group_layout_release(child)
        }
        gpu.bind_group_release(group)
        gpu.buffer_release(buffer)
        gpu.bind_group_layout_release(group_layout)
    }
}

@(test)
cts_pipeline_bindgroup_equivalence_sampler :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    types := [3]gpu.Sampler_Binding_Type{.Filtering, .Non_Filtering, .Comparison}
    for kind in 0 ..< 2 {
        visibility := kind == 0 ? gpu.Shader_Stages{.Compute} : gpu.Shader_Stages{.Fragment}
        for group_type in types {
            group_layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
                {binding = 0, visibility = visibility,
                    type = gpu.Sampler_Binding_Layout{type = group_type}},
            })
            sampler := gpu.device_create_sampler(f.device, {
                compare = group_type == .Comparison ? .Always : .Undefined,
            })
            group := cts_pb_group(f.device, group_layout,
                []gpu.Bind_Group_Entry{{binding = 0, resource = sampler}})
            for pipeline_type in types {
                child := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
                    {binding = 0, visibility = visibility,
                        type = gpu.Sampler_Binding_Layout{type = pipeline_type}},
                })
                cts_pb_run_equivalence(t, f, view, kind, group, child, 0,
                    group_type == pipeline_type)
                gpu.bind_group_layout_release(child)
            }
            gpu.bind_group_release(group)
            gpu.sampler_release(sampler)
            gpu.bind_group_layout_release(group_layout)
        }
    }
}

cts_pb_bindings_case :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: int,
    group_bindings, pipeline_bindings: []u32,
    has_dynamic: bool,
) {
    visibility := kind == 0 ? gpu.Shader_Stages{.Compute} : gpu.Shader_Stages{.Fragment}
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform}})
    group_entries := make([]gpu.Bind_Group_Layout_Entry, len(group_bindings), context.temp_allocator)
    concrete := make([]gpu.Bind_Group_Entry, len(group_bindings), context.temp_allocator)
    for binding, i in group_bindings {
        group_entries[i] = cts_layout_buffer(binding, visibility, .Uniform, has_dynamic)
        concrete[i] = {binding = binding, resource = gpu.Buffer_Binding{
            buffer = buffer, offset = 0, size = gpu.WHOLE_SIZE}}
    }
    group_layout := cts_layout_create(f.device, group_entries)
    group := cts_pb_group(f.device, group_layout, concrete)

    pipeline_entries := make([]gpu.Bind_Group_Layout_Entry, len(pipeline_bindings),
        context.temp_allocator)
    for binding, i in pipeline_bindings {
        pipeline_entries[i] = cts_layout_buffer(binding, visibility, .Uniform, has_dynamic)
    }
    child := cts_layout_create(f.device, pipeline_entries)

    success := len(group_bindings) == len(pipeline_bindings)
    for binding in group_bindings {
        found := false
        for other in pipeline_bindings {
            if other == binding {
                found = true
            }
        }
        success = success && found
    }
    cts_pb_run_equivalence(t, f, view, kind, group, child,
        has_dynamic ? len(group_bindings) : 0, success)

    gpu.bind_group_layout_release(child)
    gpu.bind_group_release(group)
    gpu.buffer_release(buffer)
    gpu.bind_group_layout_release(group_layout)
}

@(test)
cts_pipeline_bindgroup_equivalence_bindings :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    all := [3]u32{0, 1, 2}
    shifted := [3]u32{0, 1, 3}
    pair := [2]u32{0, 2}
    reversed := [2]u32{2, 0}
    fewer := [2]u32{0, 1}
    one := [1]u32{0}
    for kind in 0 ..< 2 {
        cts_pb_bindings_case(t, f, view, kind, all[:], all[:], false)
        cts_pb_bindings_case(t, f, view, kind, all[:], shifted[:], false)
        cts_pb_bindings_case(t, f, view, kind, pair[:], pair[:], false)
        cts_pb_bindings_case(t, f, view, kind, pair[:], reversed[:], false)
        cts_pb_bindings_case(t, f, view, kind, all[:], fewer[:], false)
        cts_pb_bindings_case(t, f, view, kind, fewer[:], all[:], false)
        cts_pb_bindings_case(t, f, view, kind, one[:], one[:], true)
        cts_pb_bindings_case(t, f, view, kind, one[:], one[:], false)
    }
}

@(test)
cts_pipeline_bindgroup_equivalence_visibility :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    all_visibilities := [7]gpu.Shader_Stages{
        {.Vertex}, {.Fragment}, {.Compute}, {.Vertex, .Fragment},
        {.Vertex, .Compute}, {.Fragment, .Compute}, {.Vertex, .Fragment, .Compute},
    }
    render_visibilities := [3]gpu.Shader_Stages{
        {.Vertex}, {.Fragment}, {.Vertex, .Fragment},
    }
    compute_visibility := gpu.Shader_Stages{.Compute}
    for group_visibility in all_visibilities {
        buffer := gpu.device_create_buffer(f.device, {size = 16, usage = {.Uniform}})
        group_layout := cts_pb_buffer_layout(f.device, group_visibility, .Uniform, false)
        group := cts_pb_group(f.device, group_layout,
            []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)})
        child := cts_pb_buffer_layout(f.device, compute_visibility, .Uniform, false)
        cts_pb_run_equivalence(t, f, view, 0, group, child, 0,
            group_visibility == compute_visibility)
        gpu.bind_group_layout_release(child)
        for pipeline_visibility in render_visibilities {
            child = cts_pb_buffer_layout(f.device, pipeline_visibility, .Uniform, false)
            cts_pb_run_equivalence(t, f, view, 1, group, child, 0,
                group_visibility == pipeline_visibility)
            gpu.bind_group_layout_release(child)
        }
        gpu.bind_group_release(group)
        gpu.buffer_release(buffer)
        gpu.bind_group_layout_release(group_layout)
    }
}

cts_pb_resource :: enum {
    Buffer,
    Sampler,
    Texture,
    Storage_Texture,
}

cts_pb_resource_entry :: proc(
    resource: cts_pb_resource,
    visibility: gpu.Shader_Stages,
) -> gpu.Bind_Group_Layout_Entry {
    switch resource {
    case .Buffer:
        return cts_layout_buffer(0, visibility, .Uniform, false)
    case .Sampler:
        return {binding = 0, visibility = visibility,
            type = gpu.Sampler_Binding_Layout{type = .Filtering}}
    case .Texture:
        return cts_layout_texture(0, visibility, .Float, .D2)
    case .Storage_Texture:
        return {binding = 0, visibility = visibility,
            type = gpu.Storage_Texture_Binding_Layout{
                access = .Write_Only, format = .R32_Float, view_dimension = .D2}}
    }
    return {}
}

cts_pb_resource_case :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    kind: int,
    group_resource, pipeline_resource: cts_pb_resource,
) {
    visibility := kind == 0 ? gpu.Shader_Stages{.Compute} : gpu.Shader_Stages{.Fragment}
    group_layout := cts_layout_create(f.device,
        []gpu.Bind_Group_Layout_Entry{cts_pb_resource_entry(group_resource, visibility)})
    buffer: gpu.Buffer
    sampler: gpu.Sampler
    texture: gpu.Texture
    texture_view: gpu.Texture_View
    entry: gpu.Bind_Group_Entry
    switch group_resource {
    case .Buffer:
        buffer = gpu.device_create_buffer(f.device, {size = 16, usage = {.Uniform}})
        entry = cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)
    case .Sampler:
        sampler = gpu.device_create_sampler(f.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
        entry = {binding = 0, resource = sampler}
    case .Texture:
        texture = cts_open_texture(f.device, {.Texture_Binding})
        texture_view = gpu.texture_create_view(texture)
        entry = {binding = 0, resource = texture_view}
    case .Storage_Texture:
        texture = gpu.device_create_texture(f.device, {
            usage           = {.Storage_Binding},
            dimension       = .D2,
            format          = .R32_Float,
            size            = {width = 8, height = 8, depth_or_array_layers = 1},
            mip_level_count = 1,
            sample_count    = 1,
        })
        texture_view = gpu.texture_create_view(texture)
        entry = {binding = 0, resource = texture_view}
    }
    group := cts_pb_group(f.device, group_layout, []gpu.Bind_Group_Entry{entry})
    child := cts_layout_create(f.device,
        []gpu.Bind_Group_Layout_Entry{cts_pb_resource_entry(pipeline_resource, visibility)})
    cts_pb_run_equivalence(t, f, view, kind, group, child, 0,
        group_resource == pipeline_resource)
    gpu.bind_group_layout_release(child)
    gpu.bind_group_release(group)
    if texture_view != {} {
        gpu.texture_view_release(texture_view)
    }
    if texture != {} {
        gpu.texture_release(texture)
    }
    if sampler != {} {
        gpu.sampler_release(sampler)
    }
    if buffer != {} {
        gpu.buffer_release(buffer)
    }
    gpu.bind_group_layout_release(group_layout)
}

@(test)
cts_pipeline_bindgroup_equivalence_resources :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    target, view := cts_pb_view(f.device)
    defer gpu.texture_release(target)
    defer gpu.texture_view_release(view)
    resources := [4]cts_pb_resource{.Buffer, .Sampler, .Texture, .Storage_Texture}
    for kind in 0 ..< 2 {
        for group_resource in resources {
            for pipeline_resource in resources {
                cts_pb_resource_case(t, f, view, kind, group_resource, pipeline_resource)
            }
        }
    }
}
