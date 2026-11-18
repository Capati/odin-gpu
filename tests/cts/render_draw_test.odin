package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/render/draw.spec.ts`
//, the index-format slice: a strip pipeline's
// `stripIndexFormat` must match the bound index buffer, checked at the draw so a
// rebind or pipeline switch re-dirties the comparison.

cts_draw_indexed_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    view: gpu.Texture_View,
    index_buffer: gpu.Buffer,
    indirect_buffer: gpu.Buffer,
    kind: uint,
    pipeline_first: bool,
    pipeline: gpu.Render_Pipeline,
    index_format: gpu.Index_Format,
    indexed_indirect: bool,
) -> bool {
    before := cts_errors()
    if kind == 1 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        if pipeline_first {
            gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
        }
        gpu.render_bundle_encoder_set_index_buffer(
            encoder, index_buffer, index_format, 0, 400)
        if !pipeline_first {
            gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
        }
        if indexed_indirect {
            gpu.render_bundle_encoder_draw_indexed_indirect(encoder, indirect_buffer, 0)
        } else {
            gpu.render_bundle_encoder_draw_indexed(encoder, 3, 1, 0, 0, 0)
        }
        bundle := gpu.render_bundle_encoder_finish(encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
        gpu.render_bundle_encoder_release(encoder)
    } else {
        encoder := gpu.device_create_command_encoder(f.device)
        attachments := [1]gpu.Render_Pass_Color_Attachment {
            {view = view, ops = {load = .Load, store = .Store}},
        }
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments[:],
        })
        if pipeline_first {
            gpu.render_pass_set_pipeline(pass, pipeline)
        }
        gpu.render_pass_set_index_buffer(pass, index_buffer, index_format, 0, 400)
        if !pipeline_first {
            gpu.render_pass_set_pipeline(pass, pipeline)
        }
        if indexed_indirect {
            gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
        } else {
            gpu.render_pass_draw_indexed(pass, 3, 1, 0, 0, 0)
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    }
    return cts_errors() - before > 0
}

cts_draw_setup :: proc(f: CTS_Fixture) -> (
    gpu.Texture,
    gpu.Texture_View,
    gpu.Buffer,
    gpu.Buffer,
) {
    texture, view := cts_attachment_texture(f.device, .RGBA8_Unorm, 1)
    index_buffer := gpu.device_create_buffer(f.device, {size = 400, usage = {.Index}})
    indirect_buffer := gpu.device_create_buffer(f.device, {size = 20, usage = {.Indirect}})
    return texture, view, index_buffer, indirect_buffer
}

cts_vertex_pipeline :: proc(
    device: gpu.Device,
    stride: u64,
    format: gpu.Vertex_Format,
    attribute_offset: u64,
) -> gpu.Render_Pipeline {
    vertex_attrs := [1]gpu.Vertex_Attribute {
        {format = format, offset = attribute_offset, shader_location = 2},
    }
    instance_attrs := [1]gpu.Vertex_Attribute {
        {format = format, offset = attribute_offset, shader_location = 6},
    }
    layouts: [8]gpu.Vertex_Buffer_Layout
    layouts[1] = {
        array_stride = stride,
        step_mode    = .Vertex,
        attributes   = vertex_attrs[:],
    }
    layouts[7] = {
        array_stride = stride,
        step_mode    = .Instance,
        attributes   = instance_attrs[:],
    }
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    return cts_make_render_pipeline_full(
        device, targets[:], nil, 1, .Triangle_List, .Undefined, layouts[:])
}

cts_vertex_buffer_size :: proc(count: u64, stride: u64, last: u64) -> u64 {
    if count > 0 {
        return stride * (count - 1) + last
    }
    return 0
}

@(test)
cts_render_draw_vertex_buffer_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, index_buffer, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(index_buffer)
    defer gpu.buffer_release(indirect_buffer)

    Row :: struct {
        type:            int,
        vertex_size:     int,
        instance_size:   int,
        first_vertex:    u32,
        vertex_count:    u32,
        first_instance:  u32,
        instance_count:  u32,
        stride:          u64,
        accepted:        bool,
    }
    rows := [12]Row{
        {0, 0, 0, 0, 1, 0, 1, 4, true},
        {0, 1, 0, 0, 1, 0, 1, 4, false},
        {0, 2, 0, 0, 1, 0, 1, 4, false},
        {0, 0, 1, 0, 1, 0, 1, 4, false},
        {0, 0, 2, 0, 1, 0, 1, 4, false},
        {1, 1, 0, 0, 1, 0, 1, 4, true},
        {1, 2, 0, 0, 1, 0, 1, 4, true},
        {1, 0, 1, 0, 1, 0, 1, 4, false},
        {2, 1, 1, 0, 1, 0, 1, 4, true},
        {3, 1, 1, 0, 1, 0, 1, 4, true},
        {0, 1, 0, 0, 0, 0, 0, 4, true},
        {0, 1, 1, 0, 1, 0, 1, 0, false},
    }

    for row in rows {
        last := u64(4)
        vertex_exact := cts_vertex_buffer_size(
            u64(row.first_vertex) + u64(row.vertex_count), row.stride, last)
        instance_exact := cts_vertex_buffer_size(
            u64(row.first_instance) + u64(row.instance_count), row.stride, last)
        vertex_size := row.vertex_size == 0 ? vertex_exact :
            row.vertex_size == 1 ? 0 : vertex_exact - 1
        instance_size := row.instance_size == 0 ? instance_exact :
            row.instance_size == 1 ? 0 : instance_exact - 1

        pipeline := cts_vertex_pipeline(f.device, row.stride, .Float32, 0)
        testing.expect(t, pipeline != {}, "failed to create the vertex pipeline")
        vertex_buffer := gpu.device_create_buffer(f.device, {
            size = 200 + vertex_size, usage = {.Vertex},
        })
        instance_buffer := gpu.device_create_buffer(f.device, {
            size = 200 + instance_size, usage = {.Vertex},
        })

        before := cts_errors()
        encoder := gpu.device_create_command_encoder(f.device)
        attachments := [1]gpu.Render_Pass_Color_Attachment{{view = view, ops = {load = .Load, store = .Store}}}
        pass := gpu.command_encoder_begin_render_pass(encoder, {color_attachments = attachments[:]})
        gpu.render_pass_set_pipeline(pass, pipeline)
        gpu.render_pass_set_vertex_buffer(pass, 1, vertex_buffer, 200, vertex_size)
        gpu.render_pass_set_vertex_buffer(pass, 7, instance_buffer, 200, instance_size)
        switch row.type {
        case 0:
            gpu.render_pass_draw(pass, row.vertex_count, row.instance_count,
                row.first_vertex, row.first_instance)
        case 1:
            gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint16, 0, 400)
            gpu.render_pass_draw_indexed(pass, 100, row.instance_count, 100,
                i32(row.first_vertex), row.first_instance)
        case 2:
            gpu.render_pass_draw_indirect(pass, indirect_buffer, 0)
        case:
            gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
        }
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        errors := cts_errors() - before
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
        cts_expect_outcome(t, errors, !row.accepted, "vertex/instance range row")

        gpu.buffer_release(instance_buffer)
        gpu.buffer_release(vertex_buffer)
        gpu.render_pipeline_release(pipeline)
    }
}

@(test)
cts_render_draw_buffer_binding_overlap :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, index_buffer, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(index_buffer)
    defer gpu.buffer_release(indirect_buffer)

    pipeline := cts_vertex_pipeline(f.device, 16, .Float32x4, 0)
    testing.expect(t, pipeline != {}, "failed to create the overlap pipeline")
    defer gpu.render_pipeline_release(pipeline)
    shared := gpu.device_create_buffer(f.device, {
        size = 8192, usage = {.Vertex, .Index},
    })
    defer gpu.buffer_release(shared)

    offsets := [3]u64{0, 512, 1024}
    for type in 0 ..< 4 {
        for rotation in 0 ..< 2 {
            vertex_offset := offsets[0]
            instance_offset := offsets[1]
            index_offset := offsets[2]
            if rotation == 1 {
                vertex_offset = offsets[2]
                instance_offset = offsets[0]
                index_offset = offsets[1]
            }
            before := cts_errors()
            encoder := gpu.device_create_command_encoder(f.device)
            attachments := [1]gpu.Render_Pass_Color_Attachment{{view = view, ops = {load = .Load, store = .Store}}}
            pass := gpu.command_encoder_begin_render_pass(encoder, {color_attachments = attachments[:]})
            gpu.render_pass_set_pipeline(pass, pipeline)
            gpu.render_pass_set_vertex_buffer(pass, 1, shared, vertex_offset, 3200)
            gpu.render_pass_set_vertex_buffer(pass, 7, shared, instance_offset, 3200)
            if type == 1 || type == 3 {
                gpu.render_pass_set_index_buffer(pass, shared, .Uint16, index_offset, 400)
            }
            switch type {
            case 0:
                gpu.render_pass_draw(pass, 100, 100, 100, 100)
            case 1:
                gpu.render_pass_draw_indexed(pass, 100, 100, 100, 0, 100)
            case 2:
                gpu.render_pass_draw_indirect(pass, indirect_buffer, 0)
            case:
                gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
            }
            gpu.render_pass_end(pass)
            command_buffer := gpu.command_encoder_finish(encoder)
            errors := cts_errors() - before
            if command_buffer != {} {
                gpu.command_buffer_release(command_buffer)
            }
            gpu.command_encoder_release(encoder)
            cts_expect_outcome(t, errors, false, "shared buffer across bindings")
        }
    }
}

@(test)
cts_render_draw_unused_buffers :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, index_buffer, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(index_buffer)
    defer gpu.buffer_release(indirect_buffer)

    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm)
    testing.expect(t, pipeline != {}, "failed to create the default pipeline")
    defer gpu.render_pipeline_release(pipeline)

    Row :: struct {
        small_index, small_vertex, small_instance: bool,
        offset, bound_size:                        u64,
    }
    rows := [3]Row{
        {true, true, false, 0, 1},
        {false, true, true, 4, 0},
        {true, false, false, 0, 0},
    }
    for kind in 0 ..< 2 {
        for pipeline_first in 0 ..< 2 {
            for row in rows {
                for draw_type in 0 ..< 4 {
                    indexed := draw_type == 1 || draw_type == 3
                    if row.small_index && indexed {
                        continue
                    }
                    small := gpu.device_create_buffer(f.device, {
                        size = row.offset + row.bound_size,
                        usage = {.Index, .Vertex},
                    })
                    before := cts_errors()
                    if kind == 1 {
                        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
                        encoder := gpu.device_create_render_bundle_encoder(f.device, {
                            color_formats = formats[:],
                            sample_count  = 1,
                        })
                        if pipeline_first != 0 {
                            gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
                        }
                        if indexed {
                            gpu.render_bundle_encoder_set_index_buffer(
                                encoder, index_buffer, .Uint16, 0, 400)
                        } else if row.small_index {
                            gpu.render_bundle_encoder_set_index_buffer(
                                encoder, small, .Uint16, row.offset, row.bound_size)
                        }
                        if row.small_vertex {
                            gpu.render_bundle_encoder_set_vertex_buffer(
                                encoder, 1, small, row.offset, row.bound_size)
                        }
                        if row.small_instance {
                            gpu.render_bundle_encoder_set_vertex_buffer(
                                encoder, 7, small, row.offset, row.bound_size)
                        }
                        if pipeline_first == 0 {
                            gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
                        }
                        switch draw_type {
                        case 0:
                            gpu.render_bundle_encoder_draw(encoder, 100, 100, 100, 100)
                        case 1:
                            gpu.render_bundle_encoder_draw_indexed(encoder, 100, 100, 100, 0, 100)
                        case 2:
                            gpu.render_bundle_encoder_draw_indirect(encoder, indirect_buffer, 0)
                        case:
                            gpu.render_bundle_encoder_draw_indexed_indirect(
                                encoder, indirect_buffer, 0)
                        }
                        bundle := gpu.render_bundle_encoder_finish(encoder)
                        if bundle != {} {
                            gpu.render_bundle_release(bundle)
                        }
                        gpu.render_bundle_encoder_release(encoder)
                    } else {
                        encoder := gpu.device_create_command_encoder(f.device)
                        attachments := [1]gpu.Render_Pass_Color_Attachment{{view = view, ops = {load = .Load, store = .Store}}}
                        pass := gpu.command_encoder_begin_render_pass(encoder, {color_attachments = attachments[:]})
                        if pipeline_first != 0 {
                            gpu.render_pass_set_pipeline(pass, pipeline)
                        }
                        if indexed {
                            gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint16, 0, 400)
                        } else if row.small_index {
                            gpu.render_pass_set_index_buffer(
                                pass, small, .Uint16, row.offset, row.bound_size)
                        }
                        if row.small_vertex {
                            gpu.render_pass_set_vertex_buffer(
                                pass, 1, small, row.offset, row.bound_size)
                        }
                        if row.small_instance {
                            gpu.render_pass_set_vertex_buffer(
                                pass, 7, small, row.offset, row.bound_size)
                        }
                        if pipeline_first == 0 {
                            gpu.render_pass_set_pipeline(pass, pipeline)
                        }
                        switch draw_type {
                        case 0:
                            gpu.render_pass_draw(pass, 100, 100, 100, 100)
                        case 1:
                            gpu.render_pass_draw_indexed(pass, 100, 100, 100, 0, 100)
                        case 2:
                            gpu.render_pass_draw_indirect(pass, indirect_buffer, 0)
                        case:
                            gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
                        }
                        gpu.render_pass_end(pass)
                        command_buffer := gpu.command_encoder_finish(encoder)
                        if command_buffer != {} {
                            gpu.command_buffer_release(command_buffer)
                        }
                        gpu.command_encoder_release(encoder)
                    }
                    errors := cts_errors() - before
                    cts_expect_outcome(t, errors, false, "unused small buffers")
                    gpu.buffer_release(small)
                }
            }
        }
    }
}

@(test)
cts_render_draw_index_oob :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, setup_index, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(setup_index)
    defer gpu.buffer_release(indirect_buffer)
    pipeline := cts_make_render_pipeline(f.device, .RGBA8_Unorm)
    testing.expect(t, pipeline != {}, "failed to create the default pipeline")
    defer gpu.render_pipeline_release(pipeline)

    Row :: struct {
        buffer_elements, draw_count: u32,
    }
    rows := [2]Row{{10, 10}, {100, 11}}
    for kind in 0 ..< 2 {
        for pipeline_first in 0 ..< 2 {
            for row in rows {
                for format in ([2]gpu.Index_Format{.Uint16, .Uint32}) {
                    element_size := u64(format == .Uint16 ? 2 : 4)
                    for indexed_indirect in 0 ..< 2 {
                        buffer := gpu.device_create_buffer(f.device, {
                            size = u64(row.buffer_elements) * element_size,
                            usage = {.Index},
                        })
                        before := cts_errors()
                        if kind == 1 {
                            formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
                            encoder := gpu.device_create_render_bundle_encoder(f.device, {
                                color_formats = formats[:],
                                sample_count  = 1,
                            })
                            if pipeline_first != 0 {
                                gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
                            }
                            gpu.render_bundle_encoder_set_index_buffer(
                                encoder, buffer, format, 0, 10 * element_size)
                            if pipeline_first == 0 {
                                gpu.render_bundle_encoder_set_pipeline(encoder, pipeline)
                            }
                            if indexed_indirect != 0 {
                                gpu.render_bundle_encoder_draw_indexed_indirect(
                                    encoder, indirect_buffer, 0)
                            } else {
                                gpu.render_bundle_encoder_draw_indexed(
                                    encoder, row.draw_count, 1, 0, 0, 0)
                            }
                            bundle := gpu.render_bundle_encoder_finish(encoder)
                            if bundle != {} {
                                gpu.render_bundle_release(bundle)
                            }
                            gpu.render_bundle_encoder_release(encoder)
                        } else {
                            encoder := gpu.device_create_command_encoder(f.device)
                            attachments := [1]gpu.Render_Pass_Color_Attachment{{view = view, ops = {load = .Load, store = .Store}}}
                            pass := gpu.command_encoder_begin_render_pass(encoder, {color_attachments = attachments[:]})
                            if pipeline_first != 0 {
                                gpu.render_pass_set_pipeline(pass, pipeline)
                            }
                            gpu.render_pass_set_index_buffer(
                                pass, buffer, format, 0, 10 * element_size)
                            if pipeline_first == 0 {
                                gpu.render_pass_set_pipeline(pass, pipeline)
                            }
                            if indexed_indirect != 0 {
                                gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
                            } else {
                                gpu.render_pass_draw_indexed(pass, row.draw_count, 1, 0, 0, 0)
                            }
                            gpu.render_pass_end(pass)
                            command_buffer := gpu.command_encoder_finish(encoder)
                            if command_buffer != {} {
                                gpu.command_buffer_release(command_buffer)
                            }
                            gpu.command_encoder_release(encoder)
                        }
                        errors := cts_errors() - before
                        should_fail := indexed_indirect == 0 && row.draw_count > 10
                        cts_expect_outcome(t, errors, should_fail, "index OOB row")
                        gpu.buffer_release(buffer)
                    }
                }
            }
        }
    }
}

@(test)
cts_render_draw_index_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, index_buffer, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(index_buffer)
    defer gpu.buffer_release(indirect_buffer)

    Row :: struct {
        topology:          gpu.Primitive_Topology,
        strip_index_format: gpu.Index_Format,
        bind_format:       gpu.Index_Format,
        accepted:          bool,
    }
    rows := [7]Row{
        {.Triangle_List, .Undefined, .Uint32, true},
        {.Triangle_List, .Undefined, .Uint16, true},
        {.Triangle_Strip, .Uint32, .Uint32, true},
        {.Triangle_Strip, .Uint32, .Uint16, false},
        {.Triangle_Strip, .Uint16, .Uint16, true},
        {.Line_Strip, .Uint16, .Uint16, true},
        {.Triangle_Strip, .Undefined, .Uint32, false},
    }

    for kind in 0 ..< 2 {
        for pipeline_first in 0 ..< 2 {
            for row in rows {
                pipeline := cts_make_render_pipeline(
                    f.device, .RGBA8_Unorm, row.topology, row.strip_index_format)
                testing.expect(t, pipeline != {}, "failed to create the format pipeline")
                for indexed_indirect in 0 ..< 2 {
                    errors := cts_draw_indexed_row(t, f, view, index_buffer,
                        indirect_buffer, uint(kind), pipeline_first != 0,
                        pipeline, row.bind_format, indexed_indirect != 0)
                    cts_expect_outcome(t, errors ? 1 : 0, !row.accepted,
                        "index format row")
                }
                gpu.render_pipeline_release(pipeline)
            }
        }
    }
}

@(test)
cts_render_draw_index_format_dirtying :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture, view, index_buffer, indirect_buffer := cts_draw_setup(f)
    defer gpu.texture_release(texture)
    defer gpu.texture_view_release(view)
    defer gpu.buffer_release(index_buffer)
    defer gpu.buffer_release(indirect_buffer)

    pipeline_u32 := cts_make_render_pipeline(f.device, .RGBA8_Unorm, .Triangle_Strip, .Uint32)
    pipeline_u16 := cts_make_render_pipeline(f.device, .RGBA8_Unorm, .Triangle_Strip, .Uint16)
    testing.expect(t, pipeline_u32 != {} && pipeline_u16 != {},
        "failed to create the format pipelines")
    defer gpu.render_pipeline_release(pipeline_u32)
    defer gpu.render_pipeline_release(pipeline_u16)

    for kind in 0 ..< 2 {
        for dirty in 0 ..< 3 {
            for indexed_indirect in 0 ..< 2 {
                before := cts_errors()
                if kind == 1 {
                    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
                    encoder := gpu.device_create_render_bundle_encoder(f.device, {
                        color_formats = formats[:],
                        sample_count  = 1,
                    })
                    gpu.render_bundle_encoder_set_pipeline(encoder, pipeline_u32)
                    gpu.render_bundle_encoder_set_index_buffer(
                        encoder, index_buffer, .Uint32, 0, 400)
                    gpu.render_bundle_encoder_draw_indexed(encoder, 3, 1, 0, 0, 0)
                    switch dirty {
                    case 0:
                        gpu.render_bundle_encoder_set_pipeline(encoder, pipeline_u16)
                    case 1:
                        gpu.render_bundle_encoder_set_index_buffer(
                            encoder, index_buffer, .Uint16, 0, 400)
                    case:
                    }
                    if indexed_indirect != 0 {
                        gpu.render_bundle_encoder_draw_indexed_indirect(
                            encoder, indirect_buffer, 0)
                    } else {
                        gpu.render_bundle_encoder_draw_indexed(encoder, 3, 1, 0, 0, 0)
                    }
                    bundle := gpu.render_bundle_encoder_finish(encoder)
                    if bundle != {} {
                        gpu.render_bundle_release(bundle)
                    }
                    gpu.render_bundle_encoder_release(encoder)
                } else {
                    encoder := gpu.device_create_command_encoder(f.device)
                    attachments := [1]gpu.Render_Pass_Color_Attachment {
                        {view = view, ops = {load = .Load, store = .Store}},
                    }
                    pass := gpu.command_encoder_begin_render_pass(encoder, {
                        color_attachments = attachments[:],
                    })
                    gpu.render_pass_set_pipeline(pass, pipeline_u32)
                    gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint32, 0, 400)
                    gpu.render_pass_draw_indexed(pass, 3, 1, 0, 0, 0)
                    switch dirty {
                    case 0:
                        gpu.render_pass_set_pipeline(pass, pipeline_u16)
                    case 1:
                        gpu.render_pass_set_index_buffer(pass, index_buffer, .Uint16, 0, 400)
                    case:
                    }
                    if indexed_indirect != 0 {
                        gpu.render_pass_draw_indexed_indirect(pass, indirect_buffer, 0)
                    } else {
                        gpu.render_pass_draw_indexed(pass, 3, 1, 0, 0, 0)
                    }
                    gpu.render_pass_end(pass)
                    command_buffer := gpu.command_encoder_finish(encoder)
                    if command_buffer != {} {
                        gpu.command_buffer_release(command_buffer)
                    }
                    gpu.command_encoder_release(encoder)
                }
                errors := cts_errors() - before
                cts_expect_outcome(t, errors, dirty != 2, "index format dirtying row")
            }
        }
    }
}
