package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `api/validation/createPipelineLayout.spec.ts`:
// layout
// count, device ownership, null/empty layouts, dynamic-buffer budget and
// immediate-data size. The two rows that depend on WGSL shader reflection are
// omitted because this port has no WGSL frontend.

@(test)
cts_pipeline_layout_dynamic_max :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    limits := gpu.device_get_limits(f.device)
    max_dynamic := min(limits.max_dynamic_uniform_buffers_per_pipeline_layout,
        limits.max_uniform_buffers_per_shader_stage)
    if max_dynamic == 0 {
        return
    }
    entries := make([]gpu.Bind_Group_Layout_Entry, max_dynamic, context.temp_allocator)
    for i in 0 ..< max_dynamic {
        entries[i] = cts_layout_buffer(u32(i), {.Compute}, .Uniform, true)
    }
    full := cts_layout_create(f.device, entries)
    defer gpu.bind_group_layout_release(full)
    extra := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_buffer(0, {.Compute}, .Uniform, true),
    })
    defer gpu.bind_group_layout_release(extra)

    before := cts_errors()
    layout := gpu.device_create_pipeline_layout(f.device, {
        bind_group_layouts = []gpu.Bind_Group_Layout{full},
    })
    cts_expect_outcome(t, cts_errors() - before, false, "layout at dynamic maximum")
    if layout != {} {
        gpu.pipeline_layout_release(layout)
    }

    before = cts_errors()
    layout = gpu.device_create_pipeline_layout(f.device, {
        bind_group_layouts = []gpu.Bind_Group_Layout{full, extra},
    })
    cts_expect_outcome(t, cts_errors() - before, true, "layout past dynamic maximum")
    if layout != {} {
        gpu.pipeline_layout_release(layout)
    }
}

@(test)
cts_pipeline_layout_count_upstream :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    empty := cts_layout_create(f.device, nil)
    defer gpu.bind_group_layout_release(empty)
    max_groups := gpu.device_get_limits(f.device).max_bind_groups
    children := make([]gpu.Bind_Group_Layout, max_groups, context.temp_allocator)
    for i in 0 ..< max_groups {
        children[i] = empty
    }
    before := cts_errors()
    layout := gpu.device_create_pipeline_layout(f.device, {bind_group_layouts = children})
    cts_expect_outcome(t, cts_errors() - before, false, "layout at max_bind_groups")
    if layout != {} {
        gpu.pipeline_layout_release(layout)
    }

    too_many := make([]gpu.Bind_Group_Layout, max_groups + 1, context.temp_allocator)
    for i in 0 ..< len(too_many) {
        too_many[i] = empty
    }
    before = cts_errors()
    layout = gpu.device_create_pipeline_layout(f.device, {bind_group_layouts = too_many})
    cts_expect_outcome(t, cts_errors() - before, true, "layout past max_bind_groups")
    if layout != {} {
        gpu.pipeline_layout_release(layout)
    }
}

@(test)
cts_pipeline_layout_device_ownership :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    Row :: struct {first, second: bool}
    rows := [3]Row{{false, false}, {true, false}, {false, true}}
    for row in rows {
        first := cts_layout_create(row.first ? other : f.device, nil)
        second := cts_layout_create(row.second ? other : f.device, nil)
        before := cts_errors()
        layout := gpu.device_create_pipeline_layout(f.device, {
            bind_group_layouts = []gpu.Bind_Group_Layout{first, second},
        })
        cts_expect_outcome(t, cts_errors() - before, row.first || row.second,
            "pipeline layout device row")
        if layout != {} {
            gpu.pipeline_layout_release(layout)
        }
        gpu.bind_group_layout_release(first)
        gpu.bind_group_layout_release(second)
    }
}

@(test)
cts_pipeline_layout_null_bind_group_layouts :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    empty := cts_layout_create(f.device, nil)
    defer gpu.bind_group_layout_release(empty)
    non_empty := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_texture(0, {.Compute}, .Float, .D2),
    })
    defer gpu.bind_group_layout_release(non_empty)

    variants := [3]gpu.Bind_Group_Layout{{}, empty, non_empty}
    for count in 1 ..< 5 {
        for variant in variants {
            children := make([]gpu.Bind_Group_Layout, count, context.temp_allocator)
            for i in 0 ..< count {
                children[i] = non_empty
            }
            children[count - 1] = variant
            before := cts_errors()
            layout := gpu.device_create_pipeline_layout(f.device, {
                bind_group_layouts = children,
            })
            cts_expect_outcome(t, cts_errors() - before, false,
                "pipeline layout null/empty/null layouts")
            if layout != {} {
                gpu.pipeline_layout_release(layout)
            }
        }
    }
}

@(test)
cts_pipeline_layout_immediate_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    maximum := gpu.device_get_limits(f.device).max_immediate_size
    sizes := make([dynamic]u32, 0, 10, context.temp_allocator)
    append(&sizes, 0, 4, maximum, 1, 2, 3, 5, maximum + 4)
    for size in sizes {
        before := cts_errors()
        layout := gpu.device_create_pipeline_layout(f.device, {immediate_size = size})
        fail := size % 4 != 0 || size > maximum
        cts_expect_outcome(t, cts_errors() - before, fail, "pipeline layout immediate size")
        if layout != {} {
            gpu.pipeline_layout_release(layout)
        }
    }
}
