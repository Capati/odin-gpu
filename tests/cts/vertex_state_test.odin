package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `render_pipeline/vertex_state.spec.ts`, limited to rows
// that need no WGSL reflection: buffer/attribute counts, stride bounds and
// alignment, shader-location bounds and uniqueness, attribute offset alignment,
// and containment inside the stride.

cts_vertex_state_pipeline :: proc(
    t: ^testing.T,
    device: gpu.Device,
    buffers: []gpu.Vertex_Buffer_Layout,
) -> (gpu.Render_Pipeline, bool) {
    targets := cts_plain_target(.RGBA8_Unorm)
    before := cts_errors()
    pipeline := cts_make_render_pipeline_full(
        device, targets[:], nil, 1, .Triangle_List, .Undefined, buffers)
    failed := cts_errors() - before > 0
    if pipeline == {} && !failed {
        testing.expect(t, false, "vertex pipeline was refused without reporting an error")
    }
    return pipeline, failed
}

@(test)
cts_vertex_state_buffer_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    limit := gpu.device_get_limits(f.device).max_vertex_buffers
    for count in ([2]u32{limit, limit + 1}) {
        buffers := make([]gpu.Vertex_Buffer_Layout, count, context.temp_allocator)
        for &buffer in buffers {
            buffer = {array_stride = 0}
        }
        pipeline, failed := cts_vertex_state_pipeline(t, f.device, buffers)
        cts_expect_outcome(t, failed ? 1 : 0, count > limit,
            "vertex buffer count limit")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_vertex_state_attribute_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    limit := gpu.device_get_limits(f.device).max_vertex_attributes
    for count in ([2]u32{limit, limit + 1}) {
        attributes := make([]gpu.Vertex_Attribute, count, context.temp_allocator)
        for &attribute, index in attributes {
            attribute = {
                format          = .Float32,
                offset          = 0,
                shader_location = u32(index),
            }
        }
        buffers := [1]gpu.Vertex_Buffer_Layout{{array_stride = 0, attributes = attributes}}
        pipeline, failed := cts_vertex_state_pipeline(t, f.device, buffers[:])
        cts_expect_outcome(t, failed ? 1 : 0, count > limit,
            "vertex attribute count limit")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_vertex_state_array_stride :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    limit := u64(gpu.device_get_limits(f.device).max_vertex_buffer_array_stride)
    strides := [6]u64{0, 2, 4, limit - 2, limit, limit + 4}
    for stride in strides {
        buffers := [1]gpu.Vertex_Buffer_Layout{{array_stride = stride}}
        pipeline, failed := cts_vertex_state_pipeline(t, f.device, buffers[:])
        cts_expect_outcome(t, failed ? 1 : 0, stride % 4 != 0 || stride > limit,
            "vertex array stride bounds and alignment")
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}

@(test)
cts_vertex_state_attribute_rules :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    limit := gpu.device_get_limits(f.device).max_vertex_attributes
    rows := [7]struct {
        attributes: []gpu.Vertex_Attribute,
        stride:     u64,
        failure:    bool,
        what:       string,
    } {
        {[]gpu.Vertex_Attribute{{.Float32, 0, limit - 1}}, 4, false, "location at the limit"},
        {[]gpu.Vertex_Attribute{{.Float32, 0, limit}}, 4, true, "location past the limit"},
        {
            []gpu.Vertex_Attribute{{.Float32, 0, 0}, {.Float32, 0, 0}},
            4, true, "duplicate shader locations",
        },
        {[]gpu.Vertex_Attribute{{.Float32, 2, 0}}, 16, true, "misaligned offset"},
        {[]gpu.Vertex_Attribute{{.Float32x4, 0, 0}}, 16, false, "attribute filling the stride"},
        {
            []gpu.Vertex_Attribute{{.Float32x4, 4, 0}},
            16, true, "attribute past the stride",
        },
        {[]gpu.Vertex_Attribute{{.Float32, 16, 0}}, 16, true, "offset at the stride end"},
    }
    for row in rows {
        buffers := [1]gpu.Vertex_Buffer_Layout {
            {array_stride = row.stride, attributes = row.attributes},
        }
        pipeline, failed := cts_vertex_state_pipeline(t, f.device, buffers[:])
        cts_expect_outcome(t, failed ? 1 : 0, row.failure, row.what)
        if pipeline != {} {
            gpu.render_pipeline_release(pipeline)
        }
    }
}
