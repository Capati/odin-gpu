package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `render_pipeline/{misc,shader_module}.spec.ts`, limited
// to rows that do not need shader reflection: the attachment requirement,
// vertex-only pipelines, and shader-module/pipeline-layout ownership.

cts_render_validation_modules :: proc(
    device: gpu.Device,
) -> (gpu.Shader_Module, gpu.Shader_Module) {
    vertex := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_VERT_BYTES)},
    })
    fragment := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_FRAG_BYTES)},
    })
    return vertex, fragment
}

cts_try_render_pipeline :: proc(
    t: ^testing.T,
    device: gpu.Device,
    descriptor: gpu.Render_Pipeline_Descriptor,
) -> (gpu.Render_Pipeline, bool) {
    before := cts_errors()
    pipeline := gpu.device_create_render_pipeline(device, descriptor)
    failed := cts_errors() - before > 0
    if pipeline == {} && !failed {
        testing.expect(t, false, "render pipeline was refused without reporting an error")
    }
    return pipeline, failed
}

@(test)
cts_render_pipeline_attachment_requirement :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    vertex, fragment := cts_render_validation_modules(f.device)
    defer gpu.shader_module_release(vertex)
    defer gpu.shader_module_release(fragment)
    testing.expect(t, vertex != {} && fragment != {}, "failed to create the modules")

    no_fragment := gpu.Render_Pipeline_Descriptor {
        vertex = {module = vertex, entry_point = "vs_main"},
    }
    pipeline, failed := cts_try_render_pipeline(t, f.device, no_fragment)
    cts_expect_outcome(t, failed ? 1 : 0, true,
        "a pipeline with no color target or depth/stencil attachment")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }

    targets := cts_plain_target(.RGBA8_Unorm)
    fragment_state := gpu.Fragment_State {
        module      = fragment,
        entry_point = "fs_main",
        targets     = targets[:],
    }
    basic := gpu.Render_Pipeline_Descriptor {
        vertex   = {module = vertex, entry_point = "vs_main"},
        fragment = &fragment_state,
    }
    pipeline, failed = cts_try_render_pipeline(t, f.device, basic)
    cts_expect_outcome(t, failed ? 1 : 0, false, "a basic render pipeline")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }

    depth := gpu.DEFAULT_DEPTH_STENCIL_STATE
    depth.format = .Depth32_Float
    depth.depth_compare = .Always
    depth.depth_write_enabled = false
    vertex_only := gpu.Render_Pipeline_Descriptor {
        vertex        = {module = vertex, entry_point = "vs_main"},
        depth_stencil = &depth,
    }
    pipeline, failed = cts_try_render_pipeline(t, f.device, vertex_only)
    cts_expect_outcome(t, failed ? 1 : 0, false,
        "a vertex-only pipeline with a depth attachment")
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }
}

@(test)
cts_render_pipeline_shader_module_ownership :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)

    for mismatched in 0 ..< 3 {
        vertex, fragment := cts_render_validation_modules(f.device)
        foreign_vertex, foreign_fragment := cts_render_validation_modules(other)
        defer gpu.shader_module_release(vertex)
        defer gpu.shader_module_release(fragment)
        defer gpu.shader_module_release(foreign_vertex)
        defer gpu.shader_module_release(foreign_fragment)

        vertex_module := mismatched == 1 ? foreign_vertex : vertex
        fragment_module := mismatched == 2 ? foreign_fragment : fragment
        targets := cts_plain_target(.RGBA8_Unorm)
        fragment_state := gpu.Fragment_State {
            module      = fragment_module,
            entry_point = "fs_main",
            targets     = targets[:],
        }
        pipeline, failed := cts_try_render_pipeline(t, f.device, {
            vertex   = {module = vertex_module, entry_point = "vs_main"},
            fragment = &fragment_state,
        })
        cts_expect_outcome(t, failed ? 1 : 0, mismatched != 0,
            "render pipeline shader module ownership")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_render_pipeline_invalid_shader_module :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    vertex, fragment := cts_render_validation_modules(f.device)
    defer gpu.shader_module_release(vertex)
    defer gpu.shader_module_release(fragment)

    for invalid in 0 ..< 2 {
        vertex_module := invalid == 0 ? gpu.Shader_Module{} : vertex
        fragment_module := invalid == 1 ? gpu.Shader_Module{} : fragment
        targets := cts_plain_target(.RGBA8_Unorm)
        fragment_state := gpu.Fragment_State {
            module      = fragment_module,
            entry_point = "fs_main",
            targets     = targets[:],
        }
        pipeline, failed := cts_try_render_pipeline(t, f.device, {
            vertex   = {module = vertex_module, entry_point = "vs_main"},
            fragment = &fragment_state,
        })
        cts_expect_outcome(t, failed ? 1 : 0, true,
            "render pipeline with an invalid shader module")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_render_pipeline_layout_ownership :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)

    for mismatched in 0 ..< 2 {
        layout := gpu.device_create_pipeline_layout(mismatched != 0 ? other : f.device, {
            bind_group_layouts = nil,
        })
        targets := cts_plain_target(.RGBA8_Unorm)
        pipeline := cts_make_render_pipeline_full(
            f.device, targets[:], nil, 1, .Triangle_List, .Undefined, nil, layout)
        cts_expect_outcome(t, pipeline == {} ? 1 : 0, mismatched != 0,
            "render pipeline layout ownership")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
        gpu.pipeline_layout_release(layout)
    }
}
