package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS
// `api/validation/encoding/cmds/copyTextureToTexture.spec.ts`.

cts_copy_texture :: proc(
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    width, height, layers, mips, samples: u32,
    usage: gpu.Texture_Usages,
) -> gpu.Texture {
    texture := gpu.device_create_texture(f.device, {
        usage           = usage,
        dimension       = .D2,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = mips,
        sample_count    = samples,
    })
    assert(texture != {}, "failed to create the copy texture")
    return texture
}

cts_run_copy_texture :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    source: gpu.Texture,
    destination: gpu.Texture,
    copy_size: gpu.Extent_3D,
    source_mip: u32 = 0,
    destination_mip: u32 = 0,
    source_origin: gpu.Origin_3D = {0, 0, 0},
    destination_origin: gpu.Origin_3D = {0, 0, 0},
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    gpu.command_encoder_copy_texture_to_texture(
        encoder,
        {texture = source, mip_level = source_mip, origin = source_origin},
        {texture = destination, mip_level = destination_mip, origin = destination_origin},
        copy_size,
    )
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_copy_extent :: proc(width, height, layers: u32) -> gpu.Extent_3D {
    return {width = width, height = height, depth_or_array_layers = layers}
}

@(test)
cts_copy_texture_valid :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    source := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    destination := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    defer gpu.texture_release(source)
    defer gpu.texture_release(destination)

    errors := cts_run_copy_texture(t, f, source, destination, cts_copy_extent(4, 4, 1))
    cts_expect_outcome(t, errors ? 1 : 0, false, "rgba8unorm to itself")
}

@(test)
cts_copy_texture_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        source_usage:      gpu.Texture_Usages,
        destination_usage: gpu.Texture_Usages,
        accepted:          bool,
    }
    rows := [4]Row{
        {{.Copy_Dst}, {.Copy_Src, .Copy_Dst}, false},
        {{.Copy_Src, .Copy_Dst}, {.Copy_Src}, false},
        {{.Copy_Src, .Copy_Dst}, {.Copy_Dst}, true},
        {{.Copy_Src, .Render_Attachment}, {.Copy_Dst, .Render_Attachment}, true},
    }

    for row in rows {
        source := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, row.source_usage)
        destination := cts_copy_texture(
            f, .RGBA8_Unorm, 4, 4, 1, 1, 1, row.destination_usage)
        defer gpu.texture_release(source)
        defer gpu.texture_release(destination)

        errors := cts_run_copy_texture(t, f, source, destination, cts_copy_extent(4, 4, 1))
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "copy texture usage row")
    }
}

@(test)
cts_copy_texture_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        source_format:      gpu.Texture_Format,
        destination_format: gpu.Texture_Format,
        accepted:           bool,
    }
    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    render := gpu.Texture_Usages{.Copy_Src, .Copy_Dst, .Render_Attachment}
    rows := [5]Row{
        {.RGBA8_Unorm, .RGBA8_Unorm_Srgb, true},
        {.RGBA8_Unorm, .RGBA8_Snorm, false},
        {.RGBA8_Unorm, .RG8_Unorm, false},
        {.Depth24Plus_Stencil8, .Depth24Plus_Stencil8, true},
        {.Stencil8, .Depth24Plus_Stencil8, false},
    }

    for row in rows {
        row_usage := usage
        if row.source_format == .Depth24Plus_Stencil8 ||
           row.source_format == .Stencil8 ||
           row.destination_format == .Depth24Plus_Stencil8 {
            row_usage = render
        }
        source := cts_copy_texture(f, row.source_format, 4, 4, 1, 1, 1, row_usage)
        destination := cts_copy_texture(
            f, row.destination_format, 4, 4, 1, 1, 1, row_usage)
        defer gpu.texture_release(source)
        defer gpu.texture_release(destination)

        errors := cts_run_copy_texture(t, f, source, destination, cts_copy_extent(4, 4, 1))
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "copy texture format row")
    }
}

@(test)
cts_copy_texture_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    single := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    multi := gpu.Texture_Usages{.Copy_Src, .Copy_Dst, .Render_Attachment}

    Row :: struct {
        source_samples:      u32,
        destination_samples: u32,
        accepted:            bool,
    }
    rows := [4]Row{
        {1, 1, true},
        {4, 4, true},
        {1, 4, false},
        {4, 1, false},
    }

    for row in rows {
        source := cts_copy_texture(f, .RGBA8_Unorm, 2, 2, 1, 1, row.source_samples,
            row.source_samples > 1 ? multi : single)
        destination := cts_copy_texture(
            f, .RGBA8_Unorm, 2, 2, 1, 1, row.destination_samples,
            row.destination_samples > 1 ? multi : single)
        defer gpu.texture_release(source)
        defer gpu.texture_release(destination)

        errors := cts_run_copy_texture(t, f, source, destination, cts_copy_extent(2, 2, 1))
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "copy texture sample count row")
    }
}

@(test)
cts_copy_texture_mip_level :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    source := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 3, 1, usage)
    destination := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 3, 1, usage)
    defer gpu.texture_release(source)
    defer gpu.texture_release(destination)

    errors := cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(2, 2, 1), 1, 1)
    cts_expect_outcome(t, errors ? 1 : 0, false, "mip 1 of a 3-level chain")

    errors = cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(1, 1, 1), 3, 3)
    cts_expect_outcome(t, errors ? 1 : 0, true, "mip past the chain")

    errors = cts_run_copy_texture(t, f, source, destination, cts_copy_extent(4, 4, 1))
    cts_expect_outcome(t, errors ? 1 : 0, false, "mip 0 of a 3-level chain")
}

@(test)
cts_copy_texture_rectangle :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    source := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    destination := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    defer gpu.texture_release(source)
    defer gpu.texture_release(destination)

    errors := cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(2, 2, 1))
    cts_expect_outcome(t, errors ? 1 : 0, false, "a 2x2 rectangle at the origin")

    errors = cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(2, 2, 1), 0, 0, {2, 2, 0}, {2, 2, 0})
    cts_expect_outcome(t, errors ? 1 : 0, false, "a 2x2 rectangle at (2, 2)")

    errors = cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(5, 2, 1))
    cts_expect_outcome(t, errors ? 1 : 0, true, "a rectangle past the source's width")

    errors = cts_run_copy_texture(t, f, source, destination,
        cts_copy_extent(2, 5, 1))
    cts_expect_outcome(t, errors ? 1 : 0, true, "a rectangle past the source's height")

    array := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    array_dst := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
    defer gpu.texture_release(array)
    defer gpu.texture_release(array_dst)
    errors = cts_run_copy_texture(t, f, array, array_dst, cts_copy_extent(2, 2, 2))
    cts_expect_outcome(t, errors ? 1 : 0, true, "a rectangle past the array layers")
}

@(test)
cts_copy_texture_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    if other == nil {
        return
    }
    defer gpu.device_release(other)

    other_fixture := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = other}
    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}

    for mismatched in ([2]bool{false, true}) {
        source_fixture := mismatched ? other_fixture : f
        source := cts_copy_texture(source_fixture, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
        destination := cts_copy_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, 1, usage)
        defer gpu.texture_release(source)
        defer gpu.texture_release(destination)

        errors := cts_run_copy_texture(t, f, source, destination,
            cts_copy_extent(4, 4, 1))
        cts_expect_outcome(t, errors ? 1 : 0, mismatched,
            mismatched ? "a texture from another device" : "the control copy")
    }
}

@(test)
cts_copy_texture_compressed_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    if !gpu.adapter_has_feature(f.adapter, .Texture_Compression_BC) {
        return
    }
    descriptor := gpu.Device_Descriptor{}
    descriptor.required_features = []gpu.Feature_Name{.Texture_Compression_BC}
    dev := cts_make_device(f.adapter, descriptor)
    testing.expect(t, dev != nil, "failed to create the BC device")
    if dev == nil {
        return
    }
    defer gpu.device_release(dev)

    bc := CTS_Fixture{instance = f.instance, adapter = f.adapter, device = dev}
    usage := gpu.Texture_Usages{.Copy_Src, .Copy_Dst}
    source := cts_copy_texture(bc, .BC1RGBA_Unorm, 16, 16, 1, 1, 1, usage)
    destination := cts_copy_texture(bc, .BC1RGBA_Unorm, 16, 16, 1, 1, 1, usage)
    defer gpu.texture_release(source)
    defer gpu.texture_release(destination)

    errors := cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(8, 8, 1), 0, 0, {4, 4, 0}, {4, 4, 0})
    cts_expect_outcome(t, errors ? 1 : 0, false, "origin (4, 4)")

    errors = cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(8, 8, 1), 0, 0, {2, 0, 0}, {2, 0, 0})
    cts_expect_outcome(t, errors ? 1 : 0, true, "origin x inside a block")

    errors = cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(8, 8, 1), 0, 0, {0, 2, 0}, {0, 2, 0})
    cts_expect_outcome(t, errors ? 1 : 0, true, "origin y inside a block")

    errors = cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(8, 8, 1))
    cts_expect_outcome(t, errors ? 1 : 0, false, "an 8x8 copy")

    errors = cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(6, 8, 1))
    cts_expect_outcome(t, errors ? 1 : 0, true, "a copy 2 texels wide")

    errors = cts_run_copy_texture(t, bc, source, destination,
        cts_copy_extent(8, 6, 1))
    cts_expect_outcome(t, errors ? 1 : 0, true, "a copy 2 texels high")
}
