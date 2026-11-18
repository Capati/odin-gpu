package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS
// `api/validation/image_copy/buffer_texture_copies.spec.ts`:
// buffer/texture state,
// device, usage and sample-count rules. The `writeTexture` and layout-boundary
// tables are not ported yet.

cts_buffer_texture_copy_buffer :: proc(
    f: CTS_Fixture,
    size: u64,
    usage: gpu.Buffer_Usages,
) -> gpu.Buffer {
    buffer := gpu.device_create_buffer(f.device, {size = size, usage = usage})
    assert(buffer != {}, "failed to create the copy buffer")
    return buffer
}

cts_run_buffer_texture_copy :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    texture: gpu.Texture,
    buffer: gpu.Buffer,
    size: gpu.Extent_3D,
    buffer_to_texture: bool,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {
            bytes_per_row  = size.height > 1 ? 256 : gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = size.height > 1 ? size.height : gpu.COPY_STRIDE_UNDEFINED,
        },
    }
    if buffer_to_texture {
        copy_size := size
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, copy_size)
    } else {
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    }

    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_run_buffer_texture_copy_layout :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    texture: gpu.Texture,
    buffer: gpu.Buffer,
    size: gpu.Extent_3D,
    layout: gpu.Texel_Copy_Buffer_Layout,
    buffer_to_texture: bool,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{buffer = buffer, layout = layout}
    if buffer_to_texture {
        copy_size := size
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, copy_size)
    } else {
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    }

    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_depth_aspect_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    aspect: gpu.Texture_Aspect,
    kind: uint,
) -> bool {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Copy_Src, .Copy_Dst},
        dimension       = .D2,
        format          = format,
        size            = {width = 1, height = 1, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the depth/stencil texture")
    buffer := cts_buffer_texture_copy_buffer(f, 32, {.Copy_Src, .Copy_Dst})

    before := cts_errors()
    image := gpu.Texel_Copy_Texture_Info{texture = texture, aspect = aspect}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {
            bytes_per_row  = gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = gpu.COPY_STRIDE_UNDEFINED,
        },
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}

    switch kind {
    case 0:
        encoder := gpu.device_create_command_encoder(f.device)
        copy_size := size
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, copy_size)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    case 1:
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    case:
        queue := gpu.device_get_queue(f.device)
        data := make([]u8, 4096, context.temp_allocator)
        gpu.queue_write_texture(queue, image, data, linear.layout, size)
        gpu.queue_release(queue)
    }

    errors := cts_errors() - before
    gpu.buffer_release(buffer)
    gpu.texture_release(texture)
    return errors > 0
}

@(test)
cts_buffer_texture_depth_aspects :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    formats := [5]gpu.Texture_Format{
        .Depth24Plus,
        .Depth24Plus_Stencil8,
        .Depth16_Unorm,
        .Depth32_Float,
        .Stencil8,
    }
    aspects := [3]gpu.Texture_Aspect{.All, .Depth_Only, .Stencil_Only}

    any_accepted := false
    any_refused := false
    for format in formats {
        for aspect in aspects {
            for kind in 0 ..< 3 {
                supported := gpu.texture_format_depth_stencil_copy_supported(
                    format, aspect, kind != 1)
                errors := cts_depth_aspect_row(t, f, format, aspect, uint(kind))
                cts_expect_outcome(t, errors ? 1 : 0, !supported,
                    "depth/stencil aspect row")
                any_accepted = any_accepted || supported
                any_refused = any_refused || !supported
            }
        }
    }
    cts_require_both(t, any_accepted, any_refused, "depth_stencil_aspects")
}

@(test)
cts_buffer_texture_copy_bytes_per_row :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    U := gpu.COPY_STRIDE_UNDEFINED
    Kind :: enum {
        ToBuffer,
        Write,
    }
    Row :: struct {
        kind:           Kind,
        bytes_per_row:  u32,
        rows_per_image: u32,
        copy_height:    u32,
        accepted:       bool,
    }
    rows := [12]Row{
        {.ToBuffer, 256, 4, 4, true},
        {.ToBuffer, 255, 4, 4, false},
        {.ToBuffer, 257, 4, 4, false},
        {.Write, 255, 4, 4, true},
        {.Write, 257, 4, 4, true},
        {.ToBuffer, 0, 4, 4, false},
        {.Write, 1, 4, 4, false},
        {.ToBuffer, 1, 4, 4, false},
        {.ToBuffer, U, U, 1, true},
        {.ToBuffer, U, U, 2, false},
        {.ToBuffer, 512, 4, 4, true},
        {.Write, U, U, 2, false},
    }

    for row in rows {
        texture := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1,
            {.Copy_Src, .Copy_Dst})
        buffer := cts_buffer_texture_copy_buffer(f, 2048, {.Copy_Src, .Copy_Dst})
        size := gpu.Extent_3D {
            width                 = 4,
            height                = row.copy_height,
            depth_or_array_layers = 1,
        }
        layout := gpu.Texel_Copy_Buffer_Layout{
            bytes_per_row  = row.bytes_per_row,
            rows_per_image = row.rows_per_image,
        }

        errors: bool
        if row.kind == .Write {
            data_len := u64(4 * 4 * row.copy_height)
            if row.bytes_per_row != U && row.bytes_per_row != 0 {
                data_len = u64(row.bytes_per_row) * u64(row.copy_height)
            }
            errors = cts_write_texture_row(t, f, 4, 4, 1, data_len, 0,
                row.bytes_per_row, row.rows_per_image, 4, row.copy_height, 1)
        } else {
            errors = cts_run_buffer_texture_copy_layout(
                t, f, texture, buffer, size, layout, false)
        }
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "bytesPerRow alignment row")
        gpu.buffer_release(buffer)
        gpu.texture_release(texture)
    }
}

cts_ds_copy_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    aspect: gpu.Texture_Aspect,
    buffer: gpu.Buffer,
    layout: gpu.Texel_Copy_Buffer_Layout,
    size: gpu.Extent_3D,
    kind: uint,
) -> bool {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Copy_Src, .Copy_Dst},
        dimension       = .D2,
        format          = format,
        size            = {
            width                 = size.width,
            height                = size.height,
            depth_or_array_layers = size.depth_or_array_layers,
        },
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the depth/stencil texture")

    before := cts_errors()
    image := gpu.Texel_Copy_Texture_Info{texture = texture, aspect = aspect}
    linear := gpu.Texel_Copy_Buffer_Info{buffer = buffer, layout = layout}
    switch kind {
    case 0:
        encoder := gpu.device_create_command_encoder(f.device)
        copy_size := size
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, copy_size)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    case 1:
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
    case:
        queue := gpu.device_get_queue(f.device)
        data := make([]u8, 4096, context.temp_allocator)
        gpu.queue_write_texture(queue, image, data, layout, size)
        gpu.queue_release(queue)
    }

    errors := cts_errors() - before
    gpu.texture_release(texture)
    return errors > 0
}

cts_ds_texel_size :: proc(format: gpu.Texture_Format, aspect: gpu.Texture_Aspect) -> u64 {
    #partial switch format {
    case .Depth16_Unorm:
        return 2
    case .Depth32_Float:
        return 4
    case .Depth32Float_Stencil8:
        return aspect == .Stencil_Only ? 1 : 4
    case .Depth24Plus_Stencil8, .Stencil8:
        return 1
    }
    return 0
}

@(test)
cts_buffer_texture_depth_buffer_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Combo :: struct {
        format: gpu.Texture_Format,
        aspect: gpu.Texture_Aspect,
        kind:   uint,
    }
    combos := [5]Combo{
        {.Depth16_Unorm, .Depth_Only, 1},
        {.Stencil8, .Stencil_Only, 1},
        {.Depth24Plus_Stencil8, .Stencil_Only, 1},
        {.Depth16_Unorm, .Depth_Only, 0},
        {.Depth24Plus_Stencil8, .Stencil_Only, 0},
    }
    widths := [3]u32{8, 4, 4}
    heights := [3]u32{1, 4, 4}
    layers := [3]u32{1, 1, 3}

    for combo in combos {
        texel := cts_ds_texel_size(combo.format, combo.aspect)
        for i in 0 ..< 3 {
            row_bytes := texel * u64(widths[i])
            pitch := (row_bytes + 255) / 256 * 256
            minimum := pitch * (u64(heights[i]) * u64(layers[i]) - 1) +
                (row_bytes + 3) / 4 * 4
            layout := gpu.Texel_Copy_Buffer_Layout{
                bytes_per_row  = u32(pitch),
                rows_per_image = heights[i],
            }
            size := gpu.Extent_3D {
                width                 = widths[i],
                height                = heights[i],
                depth_or_array_layers = layers[i],
            }

            exact := cts_buffer_texture_copy_buffer(f, minimum, {.Copy_Src, .Copy_Dst})
            errors := cts_ds_copy_row(t, f, combo.format, combo.aspect, exact,
                layout, size, combo.kind)
            cts_expect_outcome(t, errors ? 1 : 0, false, "exact depth/stencil buffer size")
            gpu.buffer_release(exact)

            small := cts_buffer_texture_copy_buffer(f, minimum - 4, {.Copy_Src, .Copy_Dst})
            errors = cts_ds_copy_row(t, f, combo.format, combo.aspect, small,
                layout, size, combo.kind)
            cts_expect_outcome(t, errors ? 1 : 0, true, "short depth/stencil buffer")
            gpu.buffer_release(small)
        }
    }
}

@(test)
cts_buffer_texture_depth_buffer_offset :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Combo :: struct {
        format: gpu.Texture_Format,
        aspect: gpu.Texture_Aspect,
    }
    combos := [3]Combo{
        {.Depth16_Unorm, .Depth_Only},
        {.Stencil8, .Stencil_Only},
        {.Depth24Plus_Stencil8, .Stencil_Only},
    }
    offsets := [4]u64{1, 2, 4, 6}

    for combo in combos {
        texel := cts_ds_texel_size(combo.format, combo.aspect)
        row_bytes := texel * 4
        pitch := (row_bytes + 255) / 256 * 256
        minimum := pitch * 3 + (row_bytes + 3) / 4 * 4
        size := gpu.Extent_3D{width = 4, height = 4, depth_or_array_layers = 1}

        for offset in offsets {
            layout := gpu.Texel_Copy_Buffer_Layout{
                offset         = offset,
                bytes_per_row  = u32(pitch),
                rows_per_image = 4,
            }
            buffer_size := (minimum + offset + 255) / 256 * 256
            buffer := cts_buffer_texture_copy_buffer(f, buffer_size,
                {.Copy_Src, .Copy_Dst})

            aligned := offset % 4 == 0
            errors := cts_ds_copy_row(t, f, combo.format, combo.aspect, buffer,
                layout, size, 1)
            cts_expect_outcome(t, errors ? 1 : 0, !aligned,
                "depth/stencil copy offset")

            errors = cts_ds_copy_row(t, f, combo.format, combo.aspect, buffer,
                layout, size, 2)
            cts_expect_outcome(t, errors ? 1 : 0, false,
                "depth/stencil write offset")
            gpu.buffer_release(buffer)
        }
    }
}

@(test)
cts_buffer_texture_copy_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    size := gpu.Extent_3D{width = 4, height = 4, depth_or_array_layers = 1}
    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    buffer_usage := gpu.Buffer_Usages{.Copy_Src, .Copy_Dst}

    for buffer_to_texture in ([2]bool{true, false}) {
        texture := cts_copy_texture(f, .RGBA8_Unorm, 16, 16, 1, 1, 1, usage)
        buffer := cts_buffer_texture_copy_buffer(f, 2048, buffer_usage)
        errors := cts_run_buffer_texture_copy(t, f, texture, buffer, size,
            buffer_to_texture)
        cts_expect_outcome(t, errors ? 1 : 0, false, "a copy with a live buffer")
        gpu.buffer_release(buffer)
        gpu.texture_release(texture)

        texture = cts_copy_texture(f, .RGBA8_Unorm, 16, 16, 1, 1, 1, usage)
        buffer = cts_buffer_texture_copy_buffer(f, 2048, buffer_usage)
        gpu.buffer_release(buffer)
        errors = cts_run_buffer_texture_copy(t, f, texture, buffer, size,
            buffer_to_texture)
        cts_expect_outcome(t, errors ? 1 : 0, true, "a copy with a released buffer")
        gpu.texture_release(texture)
    }
}

@(test)
cts_buffer_texture_copy_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    if other == nil {
        return
    }
    defer gpu.device_release(other)

    size := gpu.Extent_3D{width = 4, height = 4, depth_or_array_layers = 1}
    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    buffer_usage := gpu.Buffer_Usages{.Copy_Src, .Copy_Dst}

    for buffer_to_texture in ([2]bool{true, false}) {
        for mismatched in ([2]bool{false, true}) {
            texture := cts_copy_texture(f, .RGBA8_Unorm, 16, 16, 1, 1, 1, usage)
            buffer := gpu.device_create_buffer(
                mismatched ? other : f.device, {size = 2048, usage = buffer_usage})
            errors := cts_run_buffer_texture_copy(t, f, texture, buffer, size,
                buffer_to_texture)
            cts_expect_outcome(t, errors ? 1 : 0, mismatched,
                mismatched ? "a buffer from another device" : "the control copy")
            gpu.buffer_release(buffer)
            gpu.texture_release(texture)
        }
    }
}

@(test)
cts_buffer_texture_copy_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    any_accepted := false
    any_refused := false

    for buffer_to_texture in ([2]bool{true, false}) {
        for texture_usage in ([2]gpu.Texture_Usages{{.Copy_Src}, {.Copy_Dst}}) {
            for buffer_usage in ([2]gpu.Buffer_Usages{{.Copy_Src}, {.Copy_Dst}}) {
                texture := cts_copy_texture(
                    f, .RGBA8_Unorm, 16, 16, 1, 1, 1, texture_usage)
                buffer := cts_buffer_texture_copy_buffer(f, 32, buffer_usage)

                texture_ok :=
                    buffer_to_texture ? .Copy_Dst in texture_usage : .Copy_Src in texture_usage
                buffer_ok :=
                    buffer_to_texture ? .Copy_Src in buffer_usage : .Copy_Dst in buffer_usage
                ok := texture_ok && buffer_ok

                errors := cts_run_buffer_texture_copy(t, f, texture, buffer, size,
                    buffer_to_texture)
                cts_expect_outcome(t, errors ? 1 : 0, !ok, "buffer/texture usage pair")
                gpu.buffer_release(buffer)
                gpu.texture_release(texture)
                any_accepted = any_accepted || ok
                any_refused = any_refused || !ok
            }
        }
    }
    cts_require_both(t, any_accepted, any_refused, "texture_buffer_usages")
}

@(test)
cts_buffer_texture_copy_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    size := gpu.Extent_3D{width = 16, height = 1, depth_or_array_layers = 1}
    for buffer_to_texture in ([2]bool{true, false}) {
        for samples in ([2]u32{1, 4}) {
            usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
            if samples > 1 {
                usage += {.Render_Attachment}
            }
            texture := cts_copy_texture(f, .BGRA8_Unorm, 16, 1, 1, 1, samples, usage)
            buffer := cts_buffer_texture_copy_buffer(f, 64, {.Copy_Src, .Copy_Dst})

            errors := cts_run_buffer_texture_copy(t, f, texture, buffer, size,
                buffer_to_texture)
            cts_expect_outcome(t, errors ? 1 : 0, samples > 1,
                "multisampled buffer/texture copy")
            gpu.buffer_release(buffer)
            gpu.texture_release(texture)
        }
    }
}
