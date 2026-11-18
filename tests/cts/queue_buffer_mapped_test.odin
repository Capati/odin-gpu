package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/queue/buffer_mapped.spec.ts`:
// a mapped, pending or mapped-at-creation buffer
// refuses queue writes and submissions, while recording into a command buffer
// is legal and only the state at submit matters. Content assertions are omitted;
// the validation verdict is preserved.

cts_qm_buffer :: proc(f: CTS_Fixture, size: u64, usage: gpu.Buffer_Usages) -> gpu.Buffer {
    return gpu.device_create_buffer(f.device, {size = size, usage = usage})
}

cts_qm_submit :: proc(t: ^testing.T, f: CTS_Fixture, cb: gpu.Command_Buffer, fail: bool, what: string) {
    before := cts_errors()
    if cb != {} {
        queue := gpu.device_get_queue(f.device)
        gpu.queue_submit(queue, []gpu.Command_Buffer{cb})
        gpu.queue_release(queue)
        gpu.command_buffer_release(cb)
    }
    cts_expect_outcome(t, cts_errors() - before, fail, what)
}

@(test)
cts_queue_mapped_write_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    queue := gpu.device_get_queue(f.device)
    defer gpu.queue_release(queue)
    buffer := cts_qm_buffer(f, 16, {.Map_Read, .Copy_Dst})
    defer gpu.buffer_release(buffer)
    value := u64(11)
    gpu.queue_write_buffer_raw(queue, buffer, 0, &value, 8)

    gpu.buffer_map_sync(buffer, .Read, 0, 0)
    value = 33
    before := cts_errors()
    gpu.queue_write_buffer_raw(queue, buffer, 0, &value, 8)
    cts_expect_outcome(t, cts_errors() - before, true, "write into a mapped buffer")
    gpu.buffer_unmap(buffer)

    value = 44
    before = cts_errors()
    gpu.queue_write_buffer_raw(queue, buffer, 0, &value, 8)
    cts_expect_outcome(t, cts_errors() - before, false, "write after unmapping")
}

cts_qm_copy :: proc(f: CTS_Fixture, source, destination: gpu.Buffer) -> gpu.Command_Buffer {
    encoder := gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_buffer_to_buffer(encoder, source, 0, destination, 0, 8)
    cb := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return cb
}

@(test)
cts_queue_mapped_copy_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    source := cts_qm_buffer(f, 16, {.Copy_Src, .Copy_Dst})
    dest := cts_qm_buffer(f, 16, {.Map_Read, .Copy_Dst})
    defer gpu.buffer_release(source)
    defer gpu.buffer_release(dest)

    gpu.buffer_map_sync(dest, .Read, 0, 0)
    cb := cts_qm_copy(f, source, dest)
    cts_qm_submit(t, f, cb, true, "copy into a mapped destination")
    gpu.buffer_unmap(dest)

    cb = cts_qm_copy(f, source, dest)
    cts_qm_submit(t, f, cb, false, "copy after unmapping")

    pending := cts_qm_buffer(f, 16, {.Map_Read, .Copy_Dst})
    defer gpu.buffer_release(pending)
    gpu.buffer_map_async(pending, .Read, 0, 0, {})
    cb = cts_qm_copy(f, source, pending)
    cts_qm_submit(t, f, cb, true, "copy into a pending mapping")
    gpu.buffer_unmap(pending)

    late := cts_qm_buffer(f, 16, {.Map_Read, .Copy_Dst})
    defer gpu.buffer_release(late)
    gpu.buffer_map_sync(late, .Read, 0, 0)
    cb = cts_qm_copy(f, source, late)
    gpu.buffer_unmap(late)
    cts_qm_submit(t, f, cb, false, "copy recorded mapped, submitted unmapped")
}

@(test)
cts_queue_mapped_copy_buffer_to_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_qt_texture(f.device, {.Copy_Dst, .Copy_Src})
    defer gpu.texture_release(texture)
    source := cts_qm_buffer(f, 4, {.Map_Write, .Copy_Src})
    defer gpu.buffer_release(source)
    gpu.buffer_map_sync(source, .Write, 0, 0)

    encoder := gpu.device_create_command_encoder(f.device)
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = source,
        layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
    }
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    cb := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    cts_qm_submit(t, f, cb, true, "copy from a mapped buffer")
    gpu.buffer_unmap(source)

    encoder = gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_buffer_to_texture(encoder, linear, image, size)
    cb = gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    cts_qm_submit(t, f, cb, false, "copy after unmapping")
}

@(test)
cts_queue_mapped_copy_texture_to_buffer :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    texture := cts_qt_texture(f.device, {.Copy_Dst, .Copy_Src})
    defer gpu.texture_release(texture)
    dest := cts_qm_buffer(f, 8, {.Map_Read, .Copy_Dst})
    defer gpu.buffer_release(dest)
    gpu.buffer_map_sync(dest, .Read, 0, 0)

    encoder := gpu.device_create_command_encoder(f.device)
    image := gpu.Texel_Copy_Texture_Info{texture = texture}
    linear := gpu.Texel_Copy_Buffer_Info{
        buffer = dest,
        layout = {bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
            rows_per_image = gpu.COPY_STRIDE_UNDEFINED},
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    cb := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    cts_qm_submit(t, f, cb, true, "copy into a mapped destination")
    gpu.buffer_unmap(dest)

    encoder = gpu.device_create_command_encoder(f.device)
    gpu.command_encoder_copy_texture_to_buffer(encoder, image, linear, size)
    cb = gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    cts_qm_submit(t, f, cb, false, "copy after unmapping")
}

@(test)
cts_queue_mapped_at_creation :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    queue := gpu.device_get_queue(f.device)
    defer gpu.queue_release(queue)
    buffer := gpu.device_create_buffer(f.device, {
        size = 16, usage = {.Map_Read, .Copy_Dst}, mapped_at_creation = true,
    })
    defer gpu.buffer_release(buffer)
    other := cts_qm_buffer(f, 16, {.Copy_Dst, .Copy_Src})
    defer gpu.buffer_release(other)

    value := u64(66)
    before := cts_errors()
    gpu.queue_write_buffer_raw(queue, buffer, 0, &value, 8)
    cts_expect_outcome(t, cts_errors() - before, true, "write into a mapped-at-creation buffer")
    cb := cts_qm_copy(f, other, buffer)
    cts_qm_submit(t, f, cb, true, "copy into a mapped-at-creation buffer")

    gpu.buffer_unmap(buffer)
    value = 88
    before = cts_errors()
    gpu.queue_write_buffer_raw(queue, buffer, 0, &value, 8)
    cts_expect_outcome(t, cts_errors() - before, false, "write after unmapping")
    cb = cts_qm_copy(f, other, buffer)
    cts_qm_submit(t, f, cb, false, "copy after unmapping")
}
