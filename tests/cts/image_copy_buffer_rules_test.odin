package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/image_copy/buffer_related.spec.ts`:
// buffer existence, device
// ownership, copy usage, and the row pitch/method alignment. Host `writeTexture`
// has no 256-byte pitch requirement, while command copies do.

cts_bc_texture :: proc(f: CTS_Fixture) -> gpu.Texture {
    return gpu.device_create_texture(f.device, {
        usage           = {.Copy_Src, .Copy_Dst},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 8, height = 8, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
}

cts_bc_finish :: proc(f: CTS_Fixture, encoder: gpu.Command_Encoder, submit: bool) {
    cb := gpu.command_encoder_finish(encoder)
    if cb != {} {
        gpu.command_buffer_release(cb)
    }
    gpu.command_encoder_release(encoder)
}

cts_bc_row :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    kind: int,
    usage: gpu.Buffer_Usages,
    pitch, rows_image, width, height, layers: u32,
    destroy_buffer: bool,
    fail: bool,
) {
    fmt.printfln("ROW kind=%d pitch=%d rows=%d w=%d h=%d", kind, pitch, rows_image, width, height)
    texture := cts_bc_texture(f)
    defer gpu.texture_release(texture)
    buffer := gpu.device_create_buffer(f.device, {size = 2048, usage = usage})
    defer gpu.buffer_release(buffer)
    if destroy_buffer {
        gpu.buffer_destroy(buffer)
    }
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = buffer,
        layout = {bytes_per_row = pitch, rows_per_image = rows_image},
    }
    size := gpu.Extent_3D{width = width, height = height, depth_or_array_layers = layers}

    before := cts_errors()
    switch kind {
    case 0:
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
        cts_bc_finish(f, encoder, !fail)
    case 1:
        encoder := gpu.device_create_command_encoder(f.device)
        gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
        cts_bc_finish(f, encoder, !fail)
    case:
        byte_pitch := pitch != gpu.COPY_STRIDE_UNDEFINED ? pitch : width * 4
        data := make([]u8, int(byte_pitch) * int(height), context.temp_allocator)
        queue := gpu.device_get_queue(f.device)
        gpu.queue_write_texture(queue, image, data, linear.layout, size)
        gpu.queue_release(queue)
    }
    cts_expect_outcome(t, cts_errors() - before, fail,
        fmt.tprintf("kind %d pitch %d rows %d size %dx%d", kind, pitch, rows_image,
            width, height))
}

@(test)
cts_image_copy_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_bc_row(t, f, 0, {.Copy_Src, .Copy_Dst}, 256, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 0, {.Copy_Src, .Copy_Dst}, 256, 4, 4, 4, 1, true, true)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 256, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 256, 4, 4, 4, 1, true, true)
}

@(test)
cts_image_copy_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    for kind in 0 ..< 2 {
        for mismatched in 0 ..< 2 {
            texture := cts_bc_texture(f)
            defer gpu.texture_release(texture)
            buffer := gpu.device_create_buffer(mismatched != 0 ? other : f.device, {
                size = 2048, usage = {.Copy_Src, .Copy_Dst},
            })
            defer gpu.buffer_release(buffer)
            image := gpu.Texel_Copy_Texture_Info{texture = texture}
            linear := gpu.Texel_Copy_Buffer_Info{
                buffer = buffer,
                layout = {bytes_per_row = 256, rows_per_image = 4},
            }
            size := gpu.Extent_3D{width = 4, height = 4, depth_or_array_layers = 1}
            before := cts_errors()
            encoder := gpu.device_create_command_encoder(f.device)
            if kind == 0 {
                gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
            } else {
                gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
            }
            cts_ru_finish(f, encoder)
            cts_expect_outcome(t, cts_errors() - before, mismatched != 0,
                "buffer copy device row")
        }
    }
}

@(test)
cts_image_copy_buffer_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_bc_row(t, f, 0, {.Copy_Src}, 256, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 0, {.Copy_Dst}, 256, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 1, {.Copy_Dst}, 256, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 1, {.Copy_Src}, 256, 4, 4, 4, 1, false, true)
}

@(test)
cts_image_copy_buffer_bytes_per_row :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 256, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 255, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 257, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 2, {.Copy_Src, .Copy_Dst}, 255, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 2, {.Copy_Src, .Copy_Dst}, 257, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 0, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 2, {.Copy_Src, .Copy_Dst}, 1, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 1, 4, 4, 4, 1, false, true)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, gpu.COPY_STRIDE_UNDEFINED,
        gpu.COPY_STRIDE_UNDEFINED, 4, 1, 1, false, false)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, gpu.COPY_STRIDE_UNDEFINED,
        gpu.COPY_STRIDE_UNDEFINED, 4, 2, 1, false, true)
    cts_bc_row(t, f, 1, {.Copy_Src, .Copy_Dst}, 512, 4, 4, 4, 1, false, false)
    cts_bc_row(t, f, 2, {.Copy_Src, .Copy_Dst}, gpu.COPY_STRIDE_UNDEFINED,
        gpu.COPY_STRIDE_UNDEFINED, 4, 2, 1, false, true)
}
