package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `api/validation/compute_pipeline.spec.ts` and
// `getBindGroupLayout.spec.ts`, limited to the rows expressible without WGSL
// reflection: basic creation, invalid/foreign shader modules, foreign pipeline
// layouts, and the bind-group-layout index range on an explicit layout. The
// override/limits/resource-compatibility rows need a WGSL frontend.

@(test)
cts_compute_pipeline_basic :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    before := cts_errors()
    pipeline := cts_make_compute_pipeline(f.device)
    cts_expect_outcome(t, cts_errors() - before, false, "valid compute pipeline")
    testing.expect(t, pipeline != {}, "compute pipeline was refused")
    if pipeline != {} {
        gpu.compute_pipeline_release(pipeline)
    }
}

@(test)
cts_compute_pipeline_invalid_module :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    before := cts_errors()
    pipeline := gpu.device_create_compute_pipeline(f.device, {
        module = {}, entry_point = "main",
    })
    cts_expect_outcome(t, cts_errors() - before, true, "compute pipeline with no module")
    testing.expect(t, pipeline == {}, "an empty shader module was accepted")
}

@(test)
cts_compute_pipeline_module_device :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    for mismatched in 0 ..< 2 {
        module := gpu.device_create_shader_module(mismatched != 0 ? other : f.device, {
            source = gpu.Shader_Source_SPIRV{code = COMPUTE_SPIRV},
        })
        before := cts_errors()
        pipeline := gpu.device_create_compute_pipeline(f.device, {
            module = module, entry_point = "main",
        })
        cts_expect_outcome(t, cts_errors() - before, mismatched != 0,
            "compute pipeline shader module device")
        if pipeline != {} {
            gpu.compute_pipeline_release(pipeline)
        }
        gpu.shader_module_release(module)
    }
}

@(test)
cts_compute_pipeline_layout_device :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    for mismatched in 0 ..< 2 {
        layout := gpu.device_create_pipeline_layout(mismatched != 0 ? other : f.device, {
            bind_group_layouts = nil,
        })
        module := gpu.device_create_shader_module(f.device, {
            source = gpu.Shader_Source_SPIRV{code = COMPUTE_SPIRV},
        })
        before := cts_errors()
        pipeline := gpu.device_create_compute_pipeline(f.device, {
            layout = layout, module = module, entry_point = "main",
        })
        cts_expect_outcome(t, cts_errors() - before, mismatched != 0,
            "compute pipeline layout device")
        if pipeline != {} {
            gpu.compute_pipeline_release(pipeline)
        }
        gpu.shader_module_release(module)
        gpu.pipeline_layout_release(layout)
    }
}

@(test)
cts_get_bind_group_layout_index :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_layout_create(f.device, nil)
    defer gpu.bind_group_layout_release(layout)
    pipeline_layout := gpu.device_create_pipeline_layout(f.device, {
        bind_group_layouts = []gpu.Bind_Group_Layout{layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    pipeline := cts_make_render_pipeline_full(
        f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, pipeline_layout)
    testing.expect(t, pipeline != {}, "failed to create the render pipeline")
    defer gpu.render_pipeline_release(pipeline)
    limits := gpu.device_get_limits(f.device)
    for index in 0 ..< 6 {
        before := cts_errors()
        _ = gpu.render_pipeline_get_bind_group_layout(pipeline, u32(index))
        cts_expect_outcome(t, cts_errors() - before,
            u32(index) >= limits.max_bind_groups, "getBindGroupLayout index row")
    }
}
