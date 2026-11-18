package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/image_copy/layout_related.spec.ts`
//. Only the
// `copyBufferToTexture` / `copyTextureToBuffer` rows are ported; the
// `writeTexture` rows are still open.

cts_layout_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    aspect: gpu.Texture_Aspect,
    width, height, layers: u32,
    buffer_size, offset: u64,
    bytes_per_row, rows_per_image: u32,
    copy_width, copy_height, copy_layers: u32,
    buffer_to_texture: bool,
) -> bool {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Copy_Src, .Copy_Dst},
        dimension       = .D2,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the layout texture")
    buffer := gpu.device_create_buffer(f.device, {
        size = buffer_size, usage = {.Copy_Src, .Copy_Dst},
    })
    testing.expect(t, buffer != {}, "failed to create the layout buffer")

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    image := gpu.Texel_Copy_Texture_Info{texture = texture, aspect = aspect}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {
            offset         = offset,
            bytes_per_row  = bytes_per_row,
            rows_per_image = rows_per_image,
        },
    }
    copy_size := gpu.Extent_3D {
        width                 = copy_width,
        height                = copy_height,
        depth_or_array_layers = copy_layers,
    }
    if buffer_to_texture {
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, copy_size)
    } else {
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, copy_size)
    }

    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    gpu.buffer_release(buffer)
    gpu.texture_release(texture)
    return errors > 0
}

cts_write_texture_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    width, height, layers: u32,
    data_len, offset: u64,
    bytes_per_row, rows_per_image: u32,
    copy_width, copy_height, copy_layers: u32,
) -> bool {
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Copy_Dst},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the write texture")
    queue := gpu.device_get_queue(f.device)
    defer gpu.queue_release(queue)

    data := make([]u8, int(data_len), context.temp_allocator)
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    layout := gpu.Texel_Copy_Buffer_Layout{
        offset         = offset,
        bytes_per_row  = bytes_per_row,
        rows_per_image = rows_per_image,
    }
    size := gpu.Extent_3D {
        width                 = copy_width,
        height                = copy_height,
        depth_or_array_layers = copy_layers,
    }

    before := cts_errors()
    gpu.queue_write_texture(queue, image, data, layout, size)
    errors := cts_errors() - before
    gpu.texture_release(texture)
    return errors > 0
}

@(test)
cts_layout_write_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    U := gpu.COPY_STRIDE_UNDEFINED
    Row :: struct {
        width, height:  u32,
        layers:         u32,
        data_len:       u64,
        offset:         u64,
        bytes_per_row:  u32,
        rows_per_image: u32,
        copy_width:     u32,
        copy_height:    u32,
        copy_layers:    u32,
        accepted:       bool,
    }
    rows := [7]Row{
        {4, 4, 1, 2400, 1, 256, 4, 4, 4, 1, true},
        {64, 4, 1, 8192, 0, 128, 4, 32, 4, 1, true},
        {64, 4, 1, 8192, 0, 384, 4, 64, 2, 1, true},
        {64, 4, 1, 8192, 0, 1, 4, 32, 4, 1, false},
        {64, 4, 1, 8192, 0, U, U, 64, 2, 1, false},
        {16, 4, 1, 832, 0, 256, 4, 16, 4, 1, true},
        {16, 4, 1, 831, 0, 256, 4, 16, 4, 1, false},
    }

    for row in rows {
        errors := cts_write_texture_row(t, f, row.width, row.height, row.layers,
            row.data_len, row.offset, row.bytes_per_row, row.rows_per_image,
            row.copy_width, row.copy_height, row.copy_layers)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "writeTexture layout row")
    }
}

@(test)
cts_layout_rows_per_image :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    U := gpu.COPY_STRIDE_UNDEFINED
    Row :: struct {
        format:             gpu.Texture_Format,
        width, height:      u32,
        layers:             u32,
        bytes_per_row:      u32,
        rows_per_image:     u32,
        copy_width:         u32,
        copy_height:        u32,
        copy_layers:        u32,
        accepted:           bool,
    }
    rows := [7]Row{
        {.RGBA8_Unorm, 4, 4, 1, 256, 1, 4, 2, 1, false},
        {.RGBA8_Unorm, 4, 4, 1, 256, 2, 4, 2, 1, true},
        {.RGBA8_Unorm, 4, 4, 2, 256, U, 4, 2, 2, false},
        {.RGBA8_Unorm, 4, 4, 2, 256, 0, 4, 2, 2, false},
        {.RGBA8_Unorm, 4, 4, 2, 256, 2, 4, 2, 2, true},
        {.RGBA8_Unorm, 4, 4, 2, 256, 5, 4, 2, 2, true},
        {.RG8_Unorm, 8, 8, 2, 256, 7, 8, 4, 2, true},
    }

    any_accepted := false
    any_refused := false
    for row in rows {
        errors := cts_layout_row(t, f, row.format, .All, row.width, row.height,
            row.layers, 8192, 0, row.bytes_per_row, row.rows_per_image,
            row.copy_width, row.copy_height, row.copy_layers, false)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "rowsPerImage row")
        any_accepted = any_accepted || row.accepted
        any_refused = any_refused || !row.accepted
    }
    cts_require_both(t, any_accepted, any_refused, "rows_per_image_alignment")
}

@(test)
cts_layout_offset_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        format:   gpu.Texture_Format,
        aspect:   gpu.Texture_Aspect,
        width:    u32,
        height:   u32,
        offset:   u64,
        accepted: bool,
    }
    rows := [7]Row{
        {.RGBA8_Unorm, .All, 4, 4, 0, true},
        {.RGBA8_Unorm, .All, 4, 4, 4, true},
        {.RGBA8_Unorm, .All, 4, 4, 2, false},
        {.RG8_Unorm, .All, 8, 4, 2, true},
        {.RG8_Unorm, .All, 8, 4, 1, false},
        {.Depth24Plus_Stencil8, .Stencil_Only, 4, 4, 4, true},
        {.Depth24Plus_Stencil8, .Stencil_Only, 4, 4, 1, false},
    }

    for row in rows {
        errors := cts_layout_row(t, f, row.format, row.aspect, row.width, row.height,
            1, 2400, row.offset, 256, 4, row.width, row.height, 1, false)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "offset alignment row")
    }
}

@(test)
cts_layout_bytes_per_row :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    U := gpu.COPY_STRIDE_UNDEFINED
    Row :: struct {
        width, height:  u32,
        layers:         u32,
        bytes_per_row:  u32,
        rows_per_image: u32,
        copy_width:     u32,
        copy_height:    u32,
        copy_layers:    u32,
        accepted:       bool,
    }
    rows := [7]Row{
        {64, 4, 1, 256, 4, 64, 4, 1, true},
        {64, 4, 1, 128, 4, 32, 4, 1, false},
        {64, 4, 1, 384, 4, 64, 2, 1, false},
        {128, 4, 1, 256, 4, 128, 2, 1, false},
        {64, 4, 1, U, U, 64, 1, 1, true},
        {64, 4, 1, U, U, 64, 2, 1, false},
        {64, 4, 2, 256, U, 64, 2, 2, false},
    }

    for row in rows {
        errors := cts_layout_row(t, f, .RGBA8_Unorm, .All, row.width, row.height,
            row.layers, 8192, 0, row.bytes_per_row, row.rows_per_image,
            row.copy_width, row.copy_height, row.copy_layers, false)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "bytesPerRow row")
    }
}

@(test)
cts_layout_required_bytes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Shape :: struct {
        format:        gpu.Texture_Format,
        aspect:        gpu.Texture_Aspect,
        width, height: u32,
        layers:        u32,
        offset:        u64,
        bytes_per_row: u32,
        rows_per_image: u32,
        copy_width:    u32,
        copy_height:   u32,
        copy_layers:   u32,
        required:      u64,
    }
    shapes := [5]Shape{
        {.RGBA8_Unorm, .All, 16, 4, 1, 0, 256, 4, 16, 4, 1, 832},
        {.RGBA8_Unorm, .All, 16, 4, 1, 0, 512, 4, 16, 4, 1, 1600},
        {.RGBA8_Unorm, .All, 16, 4, 2, 0, 256, 8, 16, 4, 2, 2880},
        {.RGBA8_Unorm, .All, 16, 4, 1, 44, 256, 4, 16, 4, 1, 876},
        {.Depth24Plus_Stencil8, .Stencil_Only, 4, 4, 1, 0, 256, 4, 4, 4, 1, 772},
    }

    for shape in shapes {
        errors := cts_layout_row(t, f, shape.format, shape.aspect,
            shape.width, shape.height, shape.layers, shape.required,
            shape.offset, shape.bytes_per_row, shape.rows_per_image,
            shape.copy_width, shape.copy_height, shape.copy_layers, false)
        cts_expect_outcome(t, errors ? 1 : 0, false, "exactly required bytes")

        errors = cts_layout_row(t, f, shape.format, shape.aspect,
            shape.width, shape.height, shape.layers, shape.required - 1,
            shape.offset, shape.bytes_per_row, shape.rows_per_image,
            shape.copy_width, shape.copy_height, shape.copy_layers, false)
        cts_expect_outcome(t, errors ? 1 : 0, true, "one byte less than required")
    }
}

@(test)
cts_layout_overflow :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    errors := cts_layout_row(t, f, .RGBA8_Unorm, .All, 1, 1, 1, 10000, 0,
        1 << 31, 1 << 31, 1, 1, 1, false)
    cts_expect_outcome(t, errors ? 1 : 0, false, "one image, no overflow")

    errors = cts_layout_row(t, f, .RGBA8_Unorm, .All, 1, 1, 16, 10000, 0,
        1 << 31, 1 << 31, 1, 1, 16, false)
    cts_expect_outcome(t, errors ? 1 : 0, true, "sixteen images overflow")
}

@(test)
cts_layout_bound_on_offset :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        buffer_size: u64,
        offset:      u64,
        buffer_to_texture: bool,
        accepted:    bool,
    }
    rows := [5]Row{
        {4, 0, false, true},
        {4, 4, false, true},
        {4, 8, false, false},
        {12, 8, true, true},
        {8, 12, true, false},
    }

    for row in rows {
        errors := cts_layout_row(t, f, .RGBA8_Unorm, .All, 4, 4, 1,
            row.buffer_size, row.offset, 0, gpu.COPY_STRIDE_UNDEFINED,
            0, 0, 0, row.buffer_to_texture)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "empty copy offset bound")
    }
}
