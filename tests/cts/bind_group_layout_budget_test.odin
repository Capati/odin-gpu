package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the remaining CTS `createBindGroupLayout` / `createPipelineLayout`
// rules: per-stage resource budgets,
// dynamic-offset budgets, pipeline-layout aggregation/null slots/count/device,
// storage-texture dimension/format/access and binding-type presence.

cts_layout_create :: proc(
    device: gpu.Device,
    entries: []gpu.Bind_Group_Layout_Entry,
) -> gpu.Bind_Group_Layout {
    return gpu.device_create_bind_group_layout(device, {entries = entries})
}

cts_pipeline_layout_errors :: proc(
    device: gpu.Device,
    layouts: []gpu.Bind_Group_Layout,
) -> int {
    before := cts_errors()
    layout := gpu.device_create_pipeline_layout(device, {bind_group_layouts = layouts})
    errors := cts_errors() - before
    if layout != {} {
        gpu.pipeline_layout_release(layout)
    }
    return errors
}

@(test)
cts_bind_group_layout_max_dynamic_buffers :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    uniform := limits.max_dynamic_uniform_buffers_per_pipeline_layout
    storage := limits.max_dynamic_storage_buffers_per_pipeline_layout

    uniform_at := make([]gpu.Bind_Group_Layout_Entry, uniform, context.temp_allocator)
    for i in 0 ..< uniform {
        uniform_at[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_at), false,
        "dynamic uniform buffers at the limit")

    uniform_over := make([]gpu.Bind_Group_Layout_Entry, uniform + 1, context.temp_allocator)
    for i in 0 ..< len(uniform_over) {
        uniform_over[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_over), true,
        "one dynamic uniform buffer past the limit")

    storage_at := make([]gpu.Bind_Group_Layout_Entry, storage, context.temp_allocator)
    for i in 0 ..< storage {
        storage_at[i] = cts_layout_buffer(u32(i), {.Compute}, .Storage, true)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, storage_at), false,
        "dynamic storage buffers at the limit")

    storage_over := make([]gpu.Bind_Group_Layout_Entry, storage + 1, context.temp_allocator)
    for i in 0 ..< len(storage_over) {
        storage_over[i] = cts_layout_buffer(u32(i), {.Compute}, .Storage, true)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, storage_over), true,
        "one dynamic storage buffer past the limit")

    for i in 0 ..< uniform {
        uniform_at[i].visibility = {.Vertex, .Fragment, .Compute}
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_at), false,
        "the dynamic uniform budget seen from three stages")
}

@(test)
cts_bind_group_layout_per_stage_budget :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    uniform := limits.max_uniform_buffers_per_shader_stage
    storage := limits.max_storage_buffers_per_shader_stage

    uniform_at := make([]gpu.Bind_Group_Layout_Entry, uniform, context.temp_allocator)
    for i in 0 ..< uniform {
        uniform_at[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_at), false,
        "uniform buffers at the per-stage limit")

    uniform_over := make([]gpu.Bind_Group_Layout_Entry, uniform + 1, context.temp_allocator)
    for i in 0 ..< len(uniform_over) {
        uniform_over[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_over), true,
        "one uniform buffer past the per-stage limit")

    for i in 0 ..< uniform {
        uniform_at[i].visibility = {.Vertex, .Fragment}
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, uniform_at), false,
        "the per-stage uniform limit seen from two stages")

    storage_at := make([]gpu.Bind_Group_Layout_Entry, storage, context.temp_allocator)
    for i in 0 ..< storage {
        storage_at[i] = cts_layout_buffer(u32(i), {.Compute}, .Storage)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, storage_at), false,
        "storage buffers at the per-stage limit")

    storage_over := make([]gpu.Bind_Group_Layout_Entry, storage + 1, context.temp_allocator)
    for i in 0 ..< len(storage_over) {
        storage_over[i] = cts_layout_buffer(u32(i), {.Compute}, .Storage)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, storage_over), true,
        "one storage buffer past the per-stage limit")

    mixed := make([]gpu.Bind_Group_Layout_Entry, uniform + storage, context.temp_allocator)
    for i in 0 ..< uniform {
        mixed[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    for i in 0 ..< storage {
        mixed[uniform + i] = cts_layout_buffer(u32(uniform + i), {.Compute}, .Storage)
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, mixed), false,
        "each class at its own limit in one layout")
}

@(test)
cts_pipeline_layout_per_stage_budget :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    uniform := limits.max_uniform_buffers_per_shader_stage

    maxed_entries := make([]gpu.Bind_Group_Layout_Entry, uniform, context.temp_allocator)
    for i in 0 ..< uniform {
        maxed_entries[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform)
    }
    maxed := cts_layout_create(f.device, maxed_entries)
    one_entry := [1]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Uniform),
    }
    one := cts_layout_create(f.device, one_entry[:])
    half := cts_layout_create(f.device, one_entry[:])
    testing.expect(t, maxed != {} && one != {} && half != {}, "failed to create layouts")
    defer gpu.bind_group_layout_release(maxed)
    defer gpu.bind_group_layout_release(one)
    defer gpu.bind_group_layout_release(half)

    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        maxed,
    }), false, "one layout at the per-stage limit")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        maxed, one,
    }), true, "one uniform buffer past the per-stage limit")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        half, half,
    }), false, "two layouts that each fit")
}

@(test)
cts_pipeline_layout_array_budget :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    if !gpu.adapter_has_feature(f.adapter, .Buffer_Binding_Array) {
        return
    }
    limits := gpu.adapter_get_limits(f.adapter)
    uniform := limits.max_uniform_buffers_per_shader_stage
    if uniform < 2 ||
       limits.max_binding_array_elements_per_shader_stage < uniform {
        return
    }

    descriptor := gpu.Device_Descriptor {
        required_features = {.Buffer_Binding_Array},
        required_limits   = limits,
    }
    device := cts_make_device(f.adapter, descriptor)
    if device == nil {
        return
    }
    defer gpu.device_release(device)

    entry := cts_layout_buffer(0, {.Compute}, .Uniform)
    entry.count = uniform
    layout := cts_layout_create(device, []gpu.Bind_Group_Layout_Entry{entry})
    testing.expect(t, layout != {}, "failed to create the array layout")
    if layout == {} {
        return
    }
    defer gpu.bind_group_layout_release(layout)

    cts_expect_outcome(t, cts_pipeline_layout_errors(device, []gpu.Bind_Group_Layout {
        layout,
    }), false, "one binding array at the per-stage limit")
    cts_expect_outcome(t, cts_pipeline_layout_errors(device, []gpu.Bind_Group_Layout {
        layout, layout,
    }), true, "two binding arrays past the per-stage limit")
}

@(test)
cts_pipeline_layout_dynamic_budget :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    uniform := gpu.device_get_limits(f.device).max_dynamic_uniform_buffers_per_pipeline_layout
    half := uniform / 2

    first_entries := make([]gpu.Bind_Group_Layout_Entry, half, context.temp_allocator)
    for i in 0 ..< half {
        first_entries[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    second_entries := make([]gpu.Bind_Group_Layout_Entry, uniform - half, context.temp_allocator)
    for i in 0 ..< len(second_entries) {
        second_entries[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    extra_entries := [1]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Uniform, true),
    }
    first := cts_layout_create(f.device, first_entries)
    second := cts_layout_create(f.device, second_entries)
    extra := cts_layout_create(f.device, extra_entries[:])
    testing.expect(t, first != {} && second != {} && extra != {},
        "failed to create layouts")
    defer gpu.bind_group_layout_release(first)
    defer gpu.bind_group_layout_release(second)
    defer gpu.bind_group_layout_release(extra)

    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        first, second,
    }), false, "dynamic buffers at the pipeline limit")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        first, second, extra,
    }), true, "one dynamic buffer past the pipeline budget")
}

@(test)
cts_pipeline_layout_null_and_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    one_entry := [1]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Uniform),
    }
    real := cts_layout_create(f.device, one_entry[:])
    testing.expect(t, real != {}, "failed to create the layout")
    defer gpu.bind_group_layout_release(real)
    empty := cts_layout_create(f.device, nil)
    testing.expect(t, empty != {}, "failed to create the empty layout")
    defer gpu.bind_group_layout_release(empty)

    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        gpu.Bind_Group_Layout{}, real,
    }), false, "a null layout leading")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        real, gpu.Bind_Group_Layout{},
    }), false, "a null layout trailing")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        gpu.Bind_Group_Layout{},
    }), false, "only a null layout")
}

@(test)
cts_pipeline_layout_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    empty := cts_layout_create(f.device, nil)
    defer gpu.bind_group_layout_release(empty)
    max_groups := gpu.device_get_limits(f.device).max_bind_groups
    at_limit := make([]gpu.Bind_Group_Layout, max_groups, context.temp_allocator)
    for i in 0 ..< max_groups {
        at_limit[i] = empty
    }
    over := make([]gpu.Bind_Group_Layout, max_groups + 1, context.temp_allocator)
    for i in 0 ..< len(over) {
        over[i] = empty
    }
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, at_limit), false,
        "pipeline layout at max_bind_groups")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, over), true,
        "pipeline layout past max_bind_groups")
}

@(test)
cts_pipeline_layout_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)
    one_entry := [1]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Uniform),
    }
    own := cts_layout_create(f.device, one_entry[:])
    other_layout := cts_layout_create(other, one_entry[:])
    defer gpu.bind_group_layout_release(own)
    defer gpu.bind_group_layout_release(other_layout)

    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {own}),
        false, "this device's layout")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {other_layout}),
        true, "another device's layout")
    cts_expect_outcome(t, cts_pipeline_layout_errors(f.device, []gpu.Bind_Group_Layout {
        own, other_layout,
    }), true, "another device's layout second")
}

@(test)
cts_bind_group_layout_storage_dimension :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm, .D2)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "storage texture with the default dimension")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm, .D2)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false, "2d storage texture")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm, .D2_Array)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "2d-array storage texture")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm, .D3)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false, "3d storage texture")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm, .Cube)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true, "cube storage texture")
    entry[0] = cts_layout_storage(0, {.Compute}, .Read_Only, .RGBA8_Unorm, .Cube_Array)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "cube-array storage texture")
}

@(test)
cts_bind_group_layout_storage_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .R32_Uint)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "r32uint write-only")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "rgba8unorm write-only")
    entry[0] = cts_layout_storage(0, {.Compute}, .Read_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "rgba8unorm read-only")
    entry[0] = cts_layout_storage(0, {.Compute}, .Read_Write, .R32_Uint)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "r32uint read-write")
    entry[0] = cts_layout_storage(0, {.Compute}, .Read_Write, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "rgba8unorm read-write")
    entry[0] = cts_layout_storage(0, {.Compute}, .Write_Only, .Depth24Plus)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "depth format as storage texture")
    entry[0] = cts_layout_storage(0, {.Compute}, .Undefined, .Undefined)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "storage texture with both defaults")
}

@(test)
cts_bind_group_layout_binding_type :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry

    entry[0] = cts_layout_buffer(0, {.Compute}, .Uniform)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "uniform buffer binding")
    entry[0] = cts_layout_sampler(0, {.Compute})
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false, "sampler binding")
    entry[0] = cts_layout_texture(0, {.Compute}, .Unfilterable_Float, .D2)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "sampled texture binding")
    entry[0] = cts_layout_storage(0, {.Compute}, .Read_Only, .R32_Uint)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "storage texture binding")

    empty := [1]gpu.Bind_Group_Layout_Entry {
        {binding = 0, visibility = {.Compute}},
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, empty[:]), true,
        "entry with no binding type")
    empty[0].type = gpu.Buffer_Binding_Layout{type = .Undefined}
    cts_expect_outcome(t, cts_layout_errors(f.device, empty[:]), true,
        "buffer entry with undefined buffer type")
}
