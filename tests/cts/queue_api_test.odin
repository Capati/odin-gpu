package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the upstream WebGPU CTS `api/validation/queue/writeBuffer`,
// `writeTexture`, and `submit` specs. The port's host-write entry points are
// byte-oriented (`queue_write_buffer_bytes` and a raw size), so the CTS's
// typed-array element offset/size semantics collapse to byte offsets here.

cts_qapi_buffer :: proc(f: CTS_Fixture, size: u64, usage: gpu.Buffer_Usages) -> gpu.Buffer {
    return gpu.device_create_buffer(f.device, {size = size, usage = usage})
}

cts_qapi_write :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    buffer: gpu.Buffer,
    offset: u64,
    data: []u8,
    fail: bool,
) {
    queue := gpu.device_get_queue(f.device)
    before := cts_errors()
    gpu.queue_write_buffer_bytes(queue, buffer, offset, data)
    gpu.queue_release(queue)
    cts_expect_outcome(t, cts_errors() - before, fail, "writeBuffer row")
}

@(test)
cts_queue_write_buffer_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    data := [16]u8{}
    live := cts_qapi_buffer(f, 16, {.Copy_Dst})
    defer gpu.buffer_release(live)
    cts_qapi_write(t, f, live, 0, data[:], false)

    before := cts_errors()
    queue := gpu.device_get_queue(f.device)
    gpu.queue_write_buffer_bytes(queue, {}, 0, data[:])
    gpu.queue_release(queue)
    cts_expect_outcome(t, cts_errors() - before, true, "invalid write buffer")

    dead := cts_qapi_buffer(f, 16, {.Copy_Dst})
    gpu.buffer_destroy(dead)
    defer gpu.buffer_release(dead)
    cts_qapi_write(t, f, dead, 0, data[:], true)
}

@(test)
cts_queue_write_buffer_ranges :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    buffer := cts_qapi_buffer(f, 16, {.Copy_Dst})
    defer gpu.buffer_release(buffer)
    data := [16]u8{}

    cts_qapi_write(t, f, buffer, 0, data[:16], false)
    cts_qapi_write(t, f, buffer, 8, data[:16], true)
    cts_qapi_write(t, f, buffer, 3, data[:8], true)
    cts_qapi_write(t, f, buffer, 0, data[:4], false)
    cts_qapi_write(t, f, buffer, 16, data[:0], false)
    cts_qapi_write(t, f, buffer, 20, data[:0], true)
    cts_qapi_write(t, f, buffer, 0, data[:3], true)
    cts_qapi_write(t, f, buffer, 0, data[:8], false)
}

@(test)
cts_queue_write_buffer_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    data := [16]u8{}
    Row :: struct {usage: gpu.Buffer_Usages, accepted: bool}
    rows := [4]Row{
        {{.Copy_Dst}, true},
        {{.Storage}, false},
        {{.Storage, .Copy_Src}, false},
        {{.Storage, .Copy_Dst}, true},
    }
    for row in rows {
        buffer := cts_qapi_buffer(f, 16, row.usage)
        cts_qapi_write(t, f, buffer, 0, data[:], !row.accepted)
        gpu.buffer_release(buffer)
    }
}

@(test)
cts_queue_write_buffer_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    data := [16]u8{}
    for mismatched in 0 ..< 2 {
        buffer := gpu.device_create_buffer(mismatched != 0 ? other : f.device, {
            size = 16, usage = {.Copy_Dst},
        })
        cts_qapi_write(t, f, buffer, 0, data[:], mismatched != 0)
        gpu.buffer_release(buffer)
    }
}

cts_qapi_texture :: proc(f: CTS_Fixture, samples: u32, usage: gpu.Texture_Usages) -> gpu.Texture {
    return gpu.device_create_texture(f.device, {
        usage           = usage,
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 16, height = 16, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = samples,
    })
}

cts_qapi_write_texture :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    texture: gpu.Texture,
    fail: bool,
) {
    data := [16]u8{}
    layout := gpu.Texel_Copy_Buffer_Layout{
        bytes_per_row = gpu.COPY_STRIDE_UNDEFINED,
        rows_per_image = gpu.COPY_STRIDE_UNDEFINED,
    }
    size := gpu.Extent_3D{width = 1, height = 1, depth_or_array_layers = 1}
    queue := gpu.device_get_queue(f.device)
    before := cts_errors()
    gpu.queue_write_texture(queue, {texture = texture}, data[:], layout, size)
    gpu.queue_release(queue)
    cts_expect_outcome(t, cts_errors() - before, fail, "writeTexture row")
}

@(test)
cts_queue_write_texture_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    live := cts_qapi_texture(f, 1, {.Copy_Dst})
    defer gpu.texture_release(live)
    cts_qapi_write_texture(t, f, live, false)
    cts_qapi_write_texture(t, f, {}, true)
    dead := cts_qapi_texture(f, 1, {.Copy_Dst})
    gpu.texture_destroy(dead)
    defer gpu.texture_release(dead)
    cts_qapi_write_texture(t, f, dead, true)
}

@(test)
cts_queue_write_texture_usages :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    Row :: struct {usage: gpu.Texture_Usages, accepted: bool}
    rows := [4]Row{
        {{.Copy_Dst}, true},
        {{.Storage_Binding}, false},
        {{.Storage_Binding, .Copy_Src}, false},
        {{.Storage_Binding, .Copy_Dst}, true},
    }
    for row in rows {
        texture := cts_qapi_texture(f, 1, row.usage)
        cts_qapi_write_texture(t, f, texture, !row.accepted)
        gpu.texture_release(texture)
    }
}

@(test)
cts_queue_write_texture_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for samples in ([2]u32{1, 4}) {
        texture := cts_qapi_texture(f, samples, {.Copy_Dst, .Render_Attachment})
        cts_qapi_write_texture(t, f, texture, samples != 1)
        gpu.texture_release(texture)
    }
}

@(test)
cts_queue_write_texture_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : f.device
        texture := gpu.device_create_texture(device, {
            usage           = {.Copy_Dst, .Render_Attachment},
            dimension       = .D2,
            format          = .RGBA8_Unorm,
            size            = {width = 16, height = 16, depth_or_array_layers = 1},
            mip_level_count = 1,
            sample_count    = 1,
        })
        cts_qapi_write_texture(t, f, texture, mismatched != 0)
        gpu.texture_release(texture)
    }
}

cts_qapi_command_buffer :: proc(device: gpu.Device) -> gpu.Command_Buffer {
    encoder := gpu.device_create_command_encoder(device)
    cb := gpu.command_encoder_finish(encoder)
    gpu.command_encoder_release(encoder)
    return cb
}

cts_qapi_submit :: proc(t: ^testing.T, f: CTS_Fixture, commands: []gpu.Command_Buffer, fail: bool) {
    queue := gpu.device_get_queue(f.device)
    before := cts_errors()
    gpu.queue_submit(queue, commands)
    gpu.queue_release(queue)
    cts_expect_outcome(t, cts_errors() - before, fail, "submit row")
}

@(test)
cts_queue_submit_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    Row :: struct {first, second: bool}
    rows := [3]Row{{false, false}, {true, false}, {false, true}}
    for row in rows {
        first := cts_qapi_command_buffer(row.first ? other : f.device)
        second := cts_qapi_command_buffer(row.second ? other : f.device)
        cts_qapi_submit(t, f, []gpu.Command_Buffer{first, second}, row.first || row.second)
        gpu.command_buffer_release(first)
        gpu.command_buffer_release(second)
    }
}

@(test)
cts_queue_submit_duplicate :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cb := cts_qapi_command_buffer(f.device)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{cb, cb}, true)
    gpu.command_buffer_release(cb)
}

@(test)
cts_queue_submit_invalidates :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cb := cts_qapi_command_buffer(f.device)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{cb}, false)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{cb}, true)
    gpu.command_buffer_release(cb)
}

@(test)
cts_queue_submit_invalid_submit_invalidates :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cb := cts_qapi_command_buffer(f.device)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{cb, {}}, true)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{cb}, true)
    gpu.command_buffer_release(cb)

    second := cts_qapi_command_buffer(f.device)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{{}, second}, true)
    cts_qapi_submit(t, f, []gpu.Command_Buffer{second}, true)
    gpu.command_buffer_release(second)
}
