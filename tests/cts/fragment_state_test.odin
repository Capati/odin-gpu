package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `render_pipeline/fragment_state.spec.ts`:
// color targets
// must be renderable color formats, the target count is bounded by both
// max_color_attachments and the fixed attachment capacity, and a complete
// pipeline needs a color target or a depth/stencil attachment.

cts_fragment_pipeline :: proc(
    t: ^testing.T,
    device: gpu.Device,
    targets: []gpu.Color_Target_State,
    depth: ^gpu.Depth_Stencil_State,
) -> (gpu.Render_Pipeline, bool) {
    vertex, fragment := cts_render_validation_modules(device)
    fragment_state := gpu.Fragment_State {
        module      = fragment,
        entry_point = "fs_main",
        targets     = targets,
    }
    pipeline, failed := cts_try_render_pipeline(t, device, {
        vertex        = {module = vertex, entry_point = "vs_main"},
        fragment      = &fragment_state,
        depth_stencil = depth,
    })
    gpu.shader_module_release(vertex)
    gpu.shader_module_release(fragment)
    return pipeline, failed
}

@(test)
cts_render_pipeline_fragment_targets :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    rows := [3]struct {
        format:  gpu.Texture_Format,
        failure: bool,
        what:    string,
    } {
        {.RGBA8_Unorm, false, "rgba8unorm color target"},
        {.Depth32_Float, true, "depth32float color target"},
        {.Stencil8, true, "stencil8 color target"},
    }
    for row in rows {
        targets := [1]gpu.Color_Target_State {
            {format = row.format, write_mask = gpu.COLOR_WRITES_ALL},
        }
        pipeline, failed := cts_fragment_pipeline(t, f.device, targets[:], nil)
        cts_expect_outcome(t, failed ? 1 : 0, row.failure, row.what)
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_render_pipeline_max_color_attachments :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    limit := gpu.device_get_limits(f.device).max_color_attachments
    for count in ([2]u32{limit, limit + 1}) {
        targets := make([]gpu.Color_Target_State, count, context.temp_allocator)
        for &target in targets {
            target = {format = .RG8_Unorm, write_mask = gpu.COLOR_WRITES_ALL}
        }
        pipeline, failed := cts_fragment_pipeline(t, f.device, targets, nil)
        cts_expect_outcome(t, failed ? 1 : 0, count > limit,
            "render pipeline color target count limit")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_render_pipeline_fragment_target_blend :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    blend := gpu.BLEND_STATE_NORMAL
    for has_blend in 0 ..< 2 {
        targets := [1]gpu.Color_Target_State {
            {
                format     = .R32_Uint,
                write_mask = gpu.COLOR_WRITES_ALL,
                blend      = has_blend != 0 ? &blend : nil,
            },
        }
        pipeline, failed := cts_fragment_pipeline(t, f.device, targets[:], nil)
        cts_expect_outcome(t, failed ? 1 : 0, has_blend != 0,
            "blending an r32uint target")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_render_pipeline_zero_targets_with_depth :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    depth := gpu.DEFAULT_DEPTH_STENCIL_STATE
    depth.format = .Depth32_Float
    depth.depth_compare = .Always
    depth.depth_write_enabled = false

    pipeline, failed := cts_fragment_pipeline(t, f.device, nil, &depth)
    cts_expect_outcome(t, failed ? 1 : 0, false,
        "zero color targets with a depth attachment")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }
}
