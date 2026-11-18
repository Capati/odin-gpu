package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/queue/destroyed/texture.spec.ts`:
// a destroyed texture may not be
// used by a later submission, whether it appears as a copy operand, a bind-group
// resource or a render-pass attachment. Pixel assertions are omitted;
// the verdicts are the validation outcomes.

cts_qt_texture :: proc(
    device: gpu.Device,
    usage: gpu.Texture_Usages,
    samples: u32 = 1,
    format: gpu.Texture_Format = .RGBA8_Unorm,
    size: u32 = 1,
) -> gpu.Texture {
    return gpu.device_create_texture(device, {
        usage           = usage,
        dimension       = .D2,
        format          = format,
        size            = {width = size, height = size, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = samples,
    })
}

cts_qt_submit :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    command_buffer: gpu.Command_Buffer,
    should_fail: bool,
    what: string,
) {
    before := cts_errors()
    queue := gpu.device_get_queue(f.device)
    gpu.queue_submit(queue, []gpu.Command_Buffer{command_buffer})
    gpu.queue_release(queue)
    cts_expect_outcome(t, cts_errors() - before, should_fail, what)
    gpu.command_buffer_release(command_buffer)
}

cts_qt_copy_texel :: proc(
    f: CTS_Fixture,
    source, destination: gpu.Texture,
) -> gpu.Command_Buffer {
    encoder := gpu.device_create_command_encoder(f.device)
    src := gpu.Texel_Copy_Texture_Info{texture = source}
    dst := gpu.Texel_Copy_Texture_Info{texture = destination}
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    gpu.command_encoder_copy_texture_to_texture(encoder, src, dst, size)
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

@(test)
cts_queue_destroyed_texture_write :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    queue := gpu.device_get_queue(f.device)
    defer gpu.queue_release(queue)
    data := [4]u8{255, 0, 0, 255}
    layout := gpu.Texel_Copy_Buffer_Layout{
        bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
        rows_per_image = gpu.COPY_STRIDE_UNDEFINED,
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}

    live := cts_qt_texture(f.device, {.Copy_Dst, .Copy_Src})
    before := cts_errors()
    gpu.queue_write_texture(queue, {texture = live}, data[:], layout, size)
    cts_expect_outcome(t, cts_errors() - before, false, "write into a live texture")
    gpu.texture_release(live)

    dead := cts_qt_texture(f.device, {.Copy_Dst, .Copy_Src})
    gpu.texture_destroy(dead)
    before = cts_errors()
    gpu.queue_write_texture(queue, {texture = dead}, data[:], layout, size)
    cts_expect_outcome(t, cts_errors() - before, true, "write into a destroyed texture")
    gpu.texture_release(dead)
}

@(test)
cts_queue_destroyed_texture_copy_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    for row in 0 ..< 4 {
        source := cts_qt_texture(f.device, {.Copy_Src, .Copy_Dst})
        destination := cts_qt_texture(f.device, {.Copy_Src, .Copy_Dst})
        command_buffer := cts_qt_copy_texel(f, source, destination)
        if row == 1 || row == 3 {
            gpu.texture_destroy(source)
        }
        if row == 2 || row == 3 {
            gpu.texture_destroy(destination)
        }
        cts_qt_submit(t, f, command_buffer, row != 0, "destroyed texture-to-texture copy")
        gpu.texture_release(source)
        gpu.texture_release(destination)
    }
}

@(test)
cts_queue_destroyed_texture_copy_buffer_to_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        buffer := gpu.device_create_buffer(f.device, {size = 4, usage = {.Copy_Src}})
        texture := cts_qt_texture(f.device, {.Copy_Dst})
        encoder := gpu.device_create_command_encoder(f.device)
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = buffer,
            layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
        }
        image := gpu.Texel_Copy_Texture_Info{texture = texture}
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.buffer_destroy(buffer)
        }
        cts_qt_submit(t, f, command_buffer, row == 1, "destroyed buffer-to-texture copy")
        gpu.buffer_release(buffer)
        gpu.texture_release(texture)
    }
}

@(test)
cts_queue_destroyed_texture_copy_texture_to_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        texture := cts_qt_texture(f.device, {.Copy_Src})
        buffer := gpu.device_create_buffer(f.device, {size = 4, usage = {.Copy_Dst}})
        encoder := gpu.device_create_command_encoder(f.device)
        image := gpu.Texel_Copy_Texture_Info{texture = texture}
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = buffer,
            layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
        }
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.texture_destroy(texture)
        }
        cts_qt_submit(t, f, command_buffer, row == 1, "destroyed texture-to-buffer copy")
        gpu.texture_release(texture)
        gpu.buffer_release(buffer)
    }
}

cts_qt_record_bind_group :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    group: gpu.Bind_Group,
    kind: int,
) -> gpu.Command_Buffer {
    if kind == 0 {
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_bind_group(pass, 0, group, nil)
        gpu.compute_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        return command_buffer
    }
    attachments := []gpu.Render_Pass_Color_Attachment{
        {view = target, ops = {load = .Clear, store = .Store}},
    }
    if kind == 2 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:], sample_count = 1,
        })
        gpu.render_bundle_encoder_set_bind_group(bundle_encoder, 0, group, nil)
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        gpu.render_bundle_encoder_release(bundle_encoder)
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = attachments,
        })
        gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        gpu.render_bundle_release(bundle)
        return command_buffer
    }
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = attachments,
    })
    gpu.render_pass_set_bind_group(pass, 0, group, nil)
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

@(test)
cts_queue_destroyed_texture_bind_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for storage in 0 ..< 2 {
        layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
            storage == 0 ? cts_layout_texture(0, {.Compute, .Fragment}, .Float, .D2) :
                {binding = 0, visibility = {.Compute, .Fragment},
                 type = gpu.Storage_Texture_Binding_Layout{
                    access = .Write_Only, format = .RGBA8_Unorm, view_dimension = .D2}},
        })
        usage: gpu.Texture_Usages = storage == 0 ? {.Texture_Binding} : {.Storage_Binding}
        for kind in 0 ..< 3 {
            target := cts_qt_texture(f.device, {.Render_Attachment})
            target_view := gpu.texture_create_view(target)

            live := cts_qt_texture(f.device, usage)
            live_view := gpu.texture_create_view(live)
            live_group := cts_pb_group(f.device, layout,
                []gpu.Bind_Group_Entry{{binding = 0, resource = live_view}})
            command_buffer := cts_qt_record_bind_group(f, target_view, live_group, kind)
            cts_qt_submit(t, f, command_buffer, false, "live bind group texture")
            gpu.bind_group_release(live_group)
            gpu.texture_view_release(live_view)
            gpu.texture_release(live)

            dead := cts_qt_texture(f.device, usage)
            dead_view := gpu.texture_create_view(dead)
            dead_group := cts_pb_group(f.device, layout,
                []gpu.Bind_Group_Entry{{binding = 0, resource = dead_view}})
            command_buffer = cts_qt_record_bind_group(f, target_view, dead_group, kind)
            gpu.texture_destroy(dead)
            cts_qt_submit(t, f, command_buffer, true, "destroyed bind group texture")
            gpu.bind_group_release(dead_group)
            gpu.texture_view_release(dead_view)
            gpu.texture_release(dead)
            gpu.texture_view_release(target_view)
            gpu.texture_release(target)
        }
        gpu.bind_group_layout_release(layout)
    }
}

@(test)
cts_queue_destroyed_texture_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 4 {
        color := cts_qt_texture(f.device, {.Render_Attachment}, 4, .RGBA8_Unorm, 4)
        resolve := cts_qt_texture(f.device, {.Render_Attachment}, 1, .RGBA8_Unorm, 4)
        depth := cts_qt_texture(f.device, {.Render_Attachment}, 4, .Depth32_Float, 4)
        color_view := gpu.texture_create_view(color)
        resolve_view := gpu.texture_create_view(resolve)
        depth_view := gpu.texture_create_view(depth)
        color_attachment := gpu.Render_Pass_Color_Attachment{
            view = color_view, resolve_target = resolve_view,
            ops = {load = .Clear, store = .Store},
        }
        depth_attachment := cts_rp_depth(depth_view)
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{color_attachment},
            depth_stencil_attachment = &depth_attachment,
        })
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)

        switch row {
        case 1: gpu.texture_destroy(color)
        case 2: gpu.texture_destroy(resolve)
        case 3: gpu.texture_destroy(depth)
        }
        cts_qt_submit(t, f, command_buffer, row != 0, "destroyed render attachment")
        gpu.texture_view_release(color_view)
        gpu.texture_view_release(resolve_view)
        gpu.texture_view_release(depth_view)
        gpu.texture_release(color)
        gpu.texture_release(resolve)
        gpu.texture_release(depth)
    }
}

cts_qb_buffer :: proc(f: CTS_Fixture, size: u64, usage: gpu.Buffer_Usages) -> gpu.Buffer {
    return gpu.device_create_buffer(f.device, {size = size, usage = usage})
}

cts_qb_copy_buffer :: proc(f: CTS_Fixture, source, destination: gpu.Buffer) -> gpu.Command_Buffer {
    encoder := gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_buffer_to_buffer(encoder, source, 0, destination, 0, 4)
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

@(test)
cts_queue_destroyed_buffer_write :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    queue := gpu.device_get_queue(f.device)
    defer gpu.queue_release(queue)
    value := u32(0x11223344)

    live := cts_qb_buffer(f, 4, {.Copy_Dst, .Map_Read})
    before := cts_errors()
    gpu.queue_write_buffer_raw(queue, live, 0, &value, 4)
    cts_expect_outcome(t, cts_errors() - before, false, "write into a live buffer")
    gpu.buffer_release(live)

    dead := cts_qb_buffer(f, 4, {.Copy_Dst, .Map_Read})
    gpu.buffer_destroy(dead)
    before = cts_errors()
    gpu.queue_write_buffer_raw(queue, dead, 0, &value, 4)
    cts_expect_outcome(t, cts_errors() - before, true, "write into a destroyed buffer")
    gpu.buffer_release(dead)
}

@(test)
cts_queue_destroyed_buffer_copy :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    source := cts_qb_buffer(f, 4, {.Copy_Src, .Copy_Dst})
    destination := cts_qb_buffer(f, 4, {.Copy_Dst})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(destination)

    for row in 0 ..< 4 {
        src := source
        dst := destination
        if row == 1 || row == 3 {
            src = cts_qb_buffer(f, 4, {.Copy_Src})
        }
        if row == 2 || row == 3 {
            dst = cts_qb_buffer(f, 4, {.Copy_Dst})
        }
        command_buffer := cts_qb_copy_buffer(f, src, dst)
        if row == 1 || row == 3 {
            gpu.buffer_destroy(src)
        }
        if row == 2 || row == 3 {
            gpu.buffer_destroy(dst)
        }
        cts_qt_submit(t, f, command_buffer, row != 0, "destroyed buffer-to-buffer copy")
        if row == 1 || row == 3 {
            gpu.buffer_release(src)
        }
        if row == 2 || row == 3 {
            gpu.buffer_release(dst)
        }
    }
}

@(test)
cts_queue_destroyed_buffer_copy_buffer_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        buffer := cts_qb_buffer(f, 4, {.Copy_Src})
        texture := cts_qt_texture(f.device, {.Copy_Dst})
        encoder := gpu.device_create_command_encoder(f.device)
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = buffer,
            layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
        }
        image := gpu.Texel_Copy_Texture_Info{texture = texture}
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.buffer_destroy(buffer)
        }
        cts_qt_submit(t, f, command_buffer, row == 1, "destroyed buffer-to-texture copy")
        gpu.buffer_release(buffer)
        gpu.texture_release(texture)
    }
}

@(test)
cts_queue_destroyed_buffer_copy_texture_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        texture := cts_qt_texture(f.device, {.Copy_Src})
        buffer := cts_qb_buffer(f, 4, {.Copy_Dst})
        encoder := gpu.device_create_command_encoder(f.device)
        image := gpu.Texel_Copy_Texture_Info{texture = texture}
        linear := gpu.Texel_Copy_Buffer_Info{
            buffer = buffer,
            layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
                rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
        }
        size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.buffer_destroy(buffer)
        }
        cts_qt_submit(t, f, command_buffer, row == 1, "destroyed texture-to-buffer copy")
        gpu.texture_release(texture)
        gpu.buffer_release(buffer)
    }
}

@(test)
cts_queue_destroyed_buffer_bind_group :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_layout_create(f.device, []gpu.Bind_Group_Layout_Entry{
        cts_layout_buffer(0, {.Vertex, .Compute}, .Uniform),
    })
    defer gpu.bind_group_layout_release(layout)
    for kind in 0 ..< 3 {
        target := cts_qt_texture(f.device, {.Render_Attachment}, 1, .RGBA8_Unorm, 4)
        target_view := gpu.texture_create_view(target)

        live := cts_qb_buffer(f, 4, {.Uniform})
        live_group := cts_pb_group(f.device, layout,
            []gpu.Bind_Group_Entry{cts_bg_buffer_entry(live, 0, gpu.WHOLE_SIZE)})
        command_buffer := cts_qt_record_bind_group(f, target_view, live_group, kind)
        cts_qt_submit(t, f, command_buffer, false, "live bind group buffer")
        gpu.bind_group_release(live_group)
        gpu.buffer_release(live)

        dead := cts_qb_buffer(f, 4, {.Uniform})
        dead_group := cts_pb_group(f.device, layout,
            []gpu.Bind_Group_Entry{cts_bg_buffer_entry(dead, 0, gpu.WHOLE_SIZE)})
        command_buffer = cts_qt_record_bind_group(f, target_view, dead_group, kind)
        gpu.buffer_destroy(dead)
        cts_qt_submit(t, f, command_buffer, true, "destroyed bind group buffer")
        gpu.bind_group_release(dead_group)
        gpu.buffer_release(dead)
        gpu.texture_view_release(target_view)
        gpu.texture_release(target)
    }
}

cts_qb_record_vertex :: proc(
    f: CTS_Fixture,
    target: gpu.Texture_View,
    buffer: gpu.Buffer,
    kind: int,
    index: bool,
) -> gpu.Command_Buffer {
    if kind == 1 {
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:], sample_count = 1,
        })
        if index {
            gpu.render_bundle_encoder_set_index_buffer(bundle_encoder, buffer, .Uint16, 0, 2)
        } else {
            gpu.render_bundle_encoder_set_vertex_buffer(bundle_encoder, 0, buffer, 0,
                gpu.WHOLE_SIZE)
        }
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        gpu.render_bundle_encoder_release(bundle_encoder)
        encoder := gpu.device_create_command_encoder(f.device)
        pass := gpu.command_encoder_begin_render_pass(encoder, {
            color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
        })
        gpu.render_pass_execute_bundles(pass, []gpu.Render_Bundle{bundle})
        gpu.render_pass_end(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        gpu.render_bundle_release(bundle)
        return command_buffer
    }
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_render_pass(encoder, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{cts_rp_color(target)},
    })
    if index {
        gpu.render_pass_set_index_buffer(pass, buffer, .Uint16, 0, 2)
    } else {
        gpu.render_pass_set_vertex_buffer(pass, 0, buffer, 0, gpu.WHOLE_SIZE)
    }
    gpu.render_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return command_buffer
}

cts_qb_vertex_rows :: proc(t: ^testing.T, f: CTS_Fixture, index: bool) {
    for kind in 0 ..< 2 {
        target := cts_qt_texture(f.device, {.Render_Attachment}, 1, .RGBA8_Unorm, 4)
        target_view := gpu.texture_create_view(target)
        usage: gpu.Buffer_Usages = index ? {.Index} : {.Vertex}

        live := cts_qb_buffer(f, 4, usage)
        command_buffer := cts_qb_record_vertex(f, target_view, live, kind, index)
        cts_qt_submit(t, f, command_buffer, false, "live vertex/index buffer")
        gpu.buffer_release(live)

        dead := cts_qb_buffer(f, 4, usage)
        command_buffer = cts_qb_record_vertex(f, target_view, dead, kind, index)
        gpu.buffer_destroy(dead)
        cts_qt_submit(t, f, command_buffer, true, "destroyed vertex/index buffer")
        gpu.buffer_release(dead)
        gpu.texture_view_release(target_view)
        gpu.texture_release(target)
    }
}

@(test)
cts_queue_destroyed_buffer_vertex :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_qb_vertex_rows(t, f, false)
}

@(test)
cts_queue_destroyed_buffer_index :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_qb_vertex_rows(t, f, true)
}

@(test)
cts_queue_destroyed_buffer_resolve :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for row in 0 ..< 2 {
        set := gpu.device_create_query_set(f.device, {type = .Occlusion, count = 1})
        results := cts_qb_buffer(f, 8, {.Query_Resolve, .Copy_Src})
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_resolve_query_set(encoder, set, 0, 1, results, 0)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_encoder_release(encoder)
        if row == 1 {
            gpu.buffer_destroy(results)
        }
        cts_qt_submit(t, f, command_buffer, row == 1, "resolve into a destroyed buffer")
        gpu.query_set_release(set)
        gpu.buffer_release(results)
    }
}
