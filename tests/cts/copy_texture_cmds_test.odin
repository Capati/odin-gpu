package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/copyTextureToTexture`
// plus the block-alignment rows from
// `image_copy/copy_texture.spec.ts`:
// resource state/device, mip, usage, sample
// count, multisample alignment, format/aspect compatibility, per-side ranges,
// same-texture overlap, and compressed block alignment. Validation happens while
// recording, so the rows count the copy call and finish.

cts_ct_texture :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    width, height, layers, mips, samples: u32,
    usage: gpu.Texture_Usages,
) -> gpu.Texture {
    return gpu.device_create_texture(device, {
        usage           = usage,
        dimension       = .D2,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = mips,
        sample_count    = samples,
    })
}

cts_ct_errors :: proc(
    device: gpu.Device,
    source: gpu.Texel_Copy_Texture_Info,
    destination: gpu.Texel_Copy_Texture_Info,
    size: gpu.Extent_3D,
) -> int {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(device)
    gpu.command_encoder_copy_texture_to_texture(encoder, source, destination, size)
    cb := gpu.command_encoder_finish(encoder)
    if cb != {} {
        gpu.command_buffer_release(cb)
    }
    gpu.command_encoder_release(encoder)
    return cts_errors() - before
}

cts_ct_expect :: proc(t: ^testing.T, errors: int, fail: bool, what: string) {
    cts_expect_outcome(t, errors, fail, what)
}

@(test)
cts_copy_texture_cmds_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    for source_state in 0 ..< 3 {
        for destination_state in 0 ..< 3 {
            source: gpu.Texture
            destination: gpu.Texture
            if source_state != 1 {
                source = cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1,
                    {.Copy_Src, .Copy_Dst})
            }
            if destination_state != 1 {
                destination = cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1,
                    {.Copy_Src, .Copy_Dst})
            }
            if source_state == 2 {
                gpu.texture_destroy(source)
            }
            if destination_state == 2 {
                gpu.texture_destroy(destination)
            }
            errors := cts_ct_errors(f.device, {texture = source},
                {texture = destination}, {width = 1, height = 1,
                    depth_or_array_layers = 1})
            cts_ct_expect(t, errors, source_state != 0 || destination_state != 0,
                "texture copy state row")
            if source != {} {
                gpu.texture_release(source)
            }
            if destination != {} {
                gpu.texture_release(destination)
            }
        }
    }
}

@(test)
cts_copy_texture_cmds_device :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    defer gpu.device_release(other)
    for source_other in 0 ..< 2 {
        for destination_other in 0 ..< 2 {
            source := cts_ct_texture(source_other != 0 ? other : f.device,
                .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Copy_Src})
            destination := cts_ct_texture(destination_other != 0 ? other : f.device,
                .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Copy_Dst})
            errors := cts_ct_errors(f.device, {texture = source},
                {texture = destination}, {width = 1, height = 1,
                    depth_or_array_layers = 1})
            cts_ct_expect(t, errors, source_other != 0 || destination_other != 0,
                "texture copy device row")
            gpu.texture_release(source)
            gpu.texture_release(destination)
        }
    }
}

cts_ct_mip_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    source_levels, destination_levels, source_mip, destination_mip: u32,
) {
    source := cts_ct_texture(device, .RGBA8_Unorm, 32, 1, 1, source_levels, 1,
        {.Copy_Src})
    destination := cts_ct_texture(device, .RGBA8_Unorm, 32, 1, 1, destination_levels, 1,
        {.Copy_Dst})
    errors := cts_ct_errors(device, {texture = source, mip_level = source_mip},
        {texture = destination, mip_level = destination_mip},
        {width = 1, height = 1, depth_or_array_layers = 1})
    cts_ct_expect(t, errors, source_mip >= source_levels || destination_mip >= destination_levels,
        "texture copy mip row")
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_mips :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_mip_row(t, f.device, 1, 1, 0, 0)
    cts_ct_mip_row(t, f.device, 1, 1, 1, 0)
    cts_ct_mip_row(t, f.device, 1, 1, 0, 1)
    cts_ct_mip_row(t, f.device, 3, 3, 2, 0)
    cts_ct_mip_row(t, f.device, 3, 3, 3, 0)
    cts_ct_mip_row(t, f.device, 3, 3, 0, 3)
}

@(test)
cts_copy_texture_cmds_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    Row :: struct {source, destination: gpu.Texture_Usages, accepted: bool}
    rows := [5]Row{
        {{.Copy_Src}, {.Copy_Dst}, true},
        {{.Copy_Src, .Texture_Binding}, {.Copy_Dst}, true},
        {{.Texture_Binding}, {.Copy_Dst}, false},
        {{.Copy_Src}, {.Render_Attachment}, false},
        {{.Copy_Src}, {.Copy_Dst, .Render_Attachment}, true},
    }
    for row in rows {
        source := cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, row.source)
        destination := cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1,
            row.destination)
        errors := cts_ct_errors(f.device, {texture = source}, {texture = destination},
            {width = 1, height = 1, depth_or_array_layers = 1})
        cts_ct_expect(t, errors, !row.accepted, "texture copy usage row")
        gpu.texture_release(source)
        gpu.texture_release(destination)
    }
}

@(test)
cts_copy_texture_cmds_sample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    counts := [2]u32{1, 4}
    for source_count in counts {
        for destination_count in counts {
            source := cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, source_count,
                {.Copy_Src, .Render_Attachment})
            destination := cts_ct_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1,
                destination_count, {.Copy_Dst, .Render_Attachment})
            errors := cts_ct_errors(f.device, {texture = source},
                {texture = destination}, {width = 4, height = 4,
                    depth_or_array_layers = 1})
            cts_ct_expect(t, errors, source_count != destination_count,
                "texture copy sample count row")
            gpu.texture_release(source)
            gpu.texture_release(destination)
        }
    }
}

cts_ct_multisample_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    source_x, source_y, destination_x, destination_y, width, height: u32,
    accepted: bool,
) {
    source := cts_ct_texture(device, .RGBA8_Unorm, 32, 16, 1, 1, 4,
        {.Copy_Src, .Render_Attachment})
    destination := cts_ct_texture(device, .RGBA8_Unorm, 32, 16, 1, 1, 4,
        {.Copy_Dst, .Render_Attachment})
    errors := cts_ct_errors(device,
        {texture = source, origin = {source_x, source_y, 0}},
        {texture = destination, origin = {destination_x, destination_y, 0}},
        {width = width, height = height, depth_or_array_layers = 1})
    cts_ct_expect(t, errors, !accepted,
        fmt.tprintf("multisample src(%d,%d) dst(%d,%d) %dx%d", source_x, source_y,
            destination_x, destination_y, width, height))
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_multisampled :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_multisample_row(t, f.device, 0, 0, 0, 0, 32, 16, true)
    cts_ct_multisample_row(t, f.device, 1, 0, 0, 0, 31, 16, false)
    cts_ct_multisample_row(t, f.device, 0, 1, 0, 0, 32, 15, false)
    cts_ct_multisample_row(t, f.device, 1, 1, 0, 0, 16, 8, false)
    cts_ct_multisample_row(t, f.device, 0, 0, 1, 0, 31, 16, false)
}

@(test)
cts_copy_texture_cmds_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    Row :: struct {source, destination: gpu.Texture_Format, accepted: bool}
    rows := [5]Row{
        {.RGBA8_Unorm, .RGBA8_Unorm, true},
        {.RGBA8_Unorm_Srgb, .RGBA8_Unorm, true},
        {.BGRA8_Unorm_Srgb, .BGRA8_Unorm, true},
        {.RGBA8_Unorm, .BGRA8_Unorm, false},
        {.RGBA8_Unorm, .RG8_Unorm, false},
    }
    for row in rows {
        source := cts_ct_texture(f.device, row.source, 4, 4, 1, 1, 1, {.Copy_Src})
        destination := cts_ct_texture(f.device, row.destination, 4, 4, 1, 1, 1,
            {.Copy_Dst})
        errors := cts_ct_errors(f.device, {texture = source}, {texture = destination},
            {width = 4, height = 4, depth_or_array_layers = 1})
        cts_ct_expect(t, errors, !row.accepted, "texture copy format row")
        gpu.texture_release(source)
        gpu.texture_release(destination)
    }
}

cts_ct_depth_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    format: gpu.Texture_Format,
    source_mip, destination_mip, source_x, source_y, width, height: u32,
    accepted: bool,
) {
    source := cts_ct_texture(device, format, 64, 64, 1, 3, 1, {.Copy_Src})
    destination := cts_ct_texture(device, format, 64, 64, 1, 3, 1, {.Copy_Dst})
    errors := cts_ct_errors(device,
        {texture = source, mip_level = source_mip,
            origin = {source_x, source_y, 0}},
        {texture = destination, mip_level = destination_mip},
        {width = width, height = height, depth_or_array_layers = 1})
    cts_ct_expect(t, errors, !accepted,
        fmt.tprintf("depth fmt %d mips %d/%d origin %d,%d size %dx%d", format,
            source_mip, destination_mip, source_x, source_y, width, height))
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_depth_stencil :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_depth_row(t, f.device, .Depth32_Float, 0, 0, 0, 0, 64, 64, true)
    cts_ct_depth_row(t, f.device, .Depth32_Float, 1, 1, 0, 0, 32, 32, true)
    cts_ct_depth_row(t, f.device, .Depth32_Float, 0, 0, 1, 0, 64, 64, false)
    cts_ct_depth_row(t, f.device, .Depth32_Float, 1, 0, 0, 0, 32, 32, false)
    cts_ct_depth_row(t, f.device, .Depth32_Float, 0, 0, 0, 0, 63, 64, false)
    cts_ct_depth_row(t, f.device, .Depth24Plus_Stencil8, 0, 0, 0, 0, 64, 64, true)
    cts_ct_depth_row(t, f.device, .Depth24Plus_Stencil8, 0, 0, 0, 1, 64, 63, false)
    cts_ct_depth_row(t, f.device, .Stencil8, 2, 2, 0, 0, 16, 16, true)
}

cts_ct_range_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    origin_x, origin_y, origin_z, width, height, depth, source_mip, destination_mip: u32,
    accepted: bool,
) {
    source := cts_ct_texture(device, .RGBA8_Unorm, 16, 8, 3, 4, 1, {.Copy_Src})
    destination := cts_ct_texture(device, .RGBA8_Unorm, 16, 8, 3, 4, 1, {.Copy_Dst})
    errors := cts_ct_errors(device, {texture = source, mip_level = source_mip},
        {texture = destination, mip_level = destination_mip,
            origin = {origin_x, origin_y, origin_z}},
        {width = width, height = height, depth_or_array_layers = depth})
    cts_ct_expect(t, errors, !accepted, "texture copy range row")
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_ranges :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_range_row(t, f.device, 0, 0, 0, 16, 8, 3, 0, 0, true)
    cts_ct_range_row(t, f.device, 1, 0, 0, 15, 8, 3, 0, 0, true)
    cts_ct_range_row(t, f.device, 0, 1, 0, 16, 7, 3, 0, 0, true)
    cts_ct_range_row(t, f.device, 0, 0, 1, 16, 8, 2, 0, 0, true)
    cts_ct_range_row(t, f.device, 0, 0, 2, 16, 8, 2, 0, 0, false)
    cts_ct_range_row(t, f.device, 0, 0, 0, 16, 8, 4, 0, 0, false)
    cts_ct_range_row(t, f.device, 0, 0, 0, 8, 4, 2, 1, 0, true)
    cts_ct_range_row(t, f.device, 0, 0, 0, 16, 8, 1, 1, 0, false)
    cts_ct_range_row(t, f.device, 0, 0, 0, 4, 2, 1, 2, 2, true)
}

cts_ct_same_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    source_layer, destination_layer, depth: u32,
    accepted: bool,
) {
    texture := cts_ct_texture(device, .RGBA8_Unorm, 16, 16, 7, 1, 1,
        {.Copy_Src, .Copy_Dst})
    errors := cts_ct_errors(device, {texture = texture, origin = {0, 0, source_layer}},
        {texture = texture, origin = {0, 0, destination_layer}},
        {width = 16, height = 16, depth_or_array_layers = depth})
    cts_ct_expect(t, errors, !accepted,
        fmt.tprintf("same texture layers %d->%d depth %d", source_layer,
            destination_layer, depth))
    gpu.texture_release(texture)
}

@(test)
cts_copy_texture_cmds_same_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_same_row(t, f.device, 0, 2, 1, true)
    cts_ct_same_row(t, f.device, 2, 0, 1, true)
    cts_ct_same_row(t, f.device, 0, 4, 3, true)
    cts_ct_same_row(t, f.device, 0, 2, 3, false)
    cts_ct_same_row(t, f.device, 2, 0, 3, false)
    cts_ct_same_row(t, f.device, 0, 0, 1, false)
}

cts_ct_aspect_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    format: gpu.Texture_Format,
    source_aspect, destination_aspect: gpu.Texture_Aspect,
    accepted: bool,
) {
    source := cts_ct_texture(device, format, 16, 8, 1, 1, 1, {.Copy_Src})
    destination := cts_ct_texture(device, format, 16, 8, 1, 1, 1, {.Copy_Dst})
    errors := cts_ct_errors(device,
        {texture = source, aspect = source_aspect},
        {texture = destination, aspect = destination_aspect},
        {width = 16, height = 8, depth_or_array_layers = 1})
    cts_ct_expect(t, errors, !accepted,
        fmt.tprintf("aspects format %d %d->%d", format, source_aspect, destination_aspect))
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_aspects :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_ct_aspect_row(t, f.device, .RGBA8_Unorm, .All, .All, true)
    cts_ct_aspect_row(t, f.device, .RGBA8_Unorm, .Depth_Only, .All, false)
    cts_ct_aspect_row(t, f.device, .RGBA8_Unorm, .All, .Stencil_Only, false)
    cts_ct_aspect_row(t, f.device, .Depth24Plus, .All, .All, true)
    cts_ct_aspect_row(t, f.device, .Depth24Plus, .Depth_Only, .Depth_Only, true)
    cts_ct_aspect_row(t, f.device, .Depth24Plus, .All, .Stencil_Only, false)
    cts_ct_aspect_row(t, f.device, .Depth24Plus_Stencil8, .Depth_Only, .All, false)
    cts_ct_aspect_row(t, f.device, .Depth24Plus_Stencil8, .All, .All, true)
    cts_ct_aspect_row(t, f.device, .Stencil8, .Stencil_Only, .Stencil_Only, true)
    cts_ct_aspect_row(t, f.device, .Stencil8, .Depth_Only, .All, false)
}

cts_ct_compressed_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    source_mip, destination_mip, origin_x, origin_y, width, height: u32,
    accepted: bool,
) {
    source := cts_ct_texture(device, .BC1RGBA_Unorm, 60, 48, 3, 4, 1, {.Copy_Src})
    destination := cts_ct_texture(device, .BC1RGBA_Unorm, 60, 48, 3, 4, 1, {.Copy_Dst})
    errors := cts_ct_errors(device, {texture = source, mip_level = source_mip},
        {texture = destination, mip_level = destination_mip,
            origin = {origin_x, origin_y, 0}},
        {width = width, height = height, depth_or_array_layers = 1})
    cts_ct_expect(t, errors, !accepted,
        fmt.tprintf("compressed mips %d/%d origin %d,%d size %dx%d", source_mip,
            destination_mip, origin_x, origin_y, width, height))
    gpu.texture_release(source)
    gpu.texture_release(destination)
}

@(test)
cts_copy_texture_cmds_compressed :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_feature_device(f, .Texture_Compression_BC)
    if !have {
        return
    }
    defer gpu.device_release(device)
    cts_ct_compressed_row(t, device, 0, 0, 0, 0, 60, 48, true)
    cts_ct_compressed_row(t, device, 1, 0, 0, 0, 32, 24, true)
    cts_ct_compressed_row(t, device, 0, 0, 4, 0, 56, 48, true)
    cts_ct_compressed_row(t, device, 0, 0, 1, 0, 56, 48, false)
    cts_ct_compressed_row(t, device, 0, 0, 0, 1, 60, 44, false)
    cts_ct_compressed_row(t, device, 0, 0, 0, 0, 59, 48, false)
    cts_ct_compressed_row(t, device, 0, 0, 4, 0, 60, 48, false)
    cts_ct_compressed_row(t, device, 2, 2, 0, 0, 16, 12, true)
}

@(test)
cts_copy_texture_origin_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_feature_device(f, .Texture_Compression_BC)
    if !have {
        return
    }
    defer gpu.device_release(device)
    Row :: struct {x, y, width, height: u32, fail: bool}
    rows := [3]Row{
        {4, 4, 8, 8, false},
        {2, 0, 8, 8, true},
        {0, 2, 8, 8, true},
    }
    for row in rows {
        source := cts_ct_texture(device, .BC1RGBA_Unorm, 16, 16, 1, 1, 1, {.Copy_Src})
        destination := cts_ct_texture(device, .BC1RGBA_Unorm, 16, 16, 1, 1, 1,
            {.Copy_Dst})
        errors := cts_ct_errors(device,
            {texture = source, origin = {row.x, row.y, 0}},
            {texture = destination},
            {width = row.width, height = row.height, depth_or_array_layers = 1})
        cts_ct_expect(t, errors, row.fail, "compressed origin alignment")
        gpu.texture_release(source)
        gpu.texture_release(destination)
    }
}

@(test)
cts_copy_texture_size_alignment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    device, have := cts_feature_device(f, .Texture_Compression_BC)
    if !have {
        return
    }
    defer gpu.device_release(device)
    Row :: struct {width, height: u32, fail: bool}
    rows := [3]Row{{8, 8, false}, {6, 8, true}, {8, 6, true}}
    for row in rows {
        source := cts_ct_texture(device, .BC1RGBA_Unorm, 16, 16, 1, 1, 1, {.Copy_Src})
        destination := cts_ct_texture(device, .BC1RGBA_Unorm, 16, 16, 1, 1, 1,
            {.Copy_Dst})
        errors := cts_ct_errors(device, {texture = source}, {texture = destination},
            {width = row.width, height = row.height, depth_or_array_layers = 1})
        cts_ct_expect(t, errors, row.fail, "compressed size alignment")
        gpu.texture_release(source)
        gpu.texture_release(destination)
    }
}
