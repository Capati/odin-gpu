package cts

// Core
import "core:fmt"
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/createTexture.spec.ts`.

cts_expect_texture :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    descriptor: gpu.Texture_Descriptor,
    should_fail: bool,
    what: string,
) {
    before := cts_errors()
    texture := gpu.device_create_texture(f.device, descriptor)
    errors := cts_errors() - before
    if texture != {} {
        gpu.texture_release(texture)
    }

    if should_fail {
        testing.expectf(t, errors > 0 && texture == {},
            "%s: accepted, expected a validation error", what)
    } else {
        testing.expectf(t, errors == 0 && texture != {},
            "%s: refused (%d errors)", what, errors)
    }
}

cts_texture_desc :: proc(
    format: gpu.Texture_Format,
    dimension: gpu.Texture_Dimension,
    width, height, layers, mips, samples: u32,
    usage: gpu.Texture_Usages,
) -> gpu.Texture_Descriptor {
    return {
        usage           = usage,
        dimension       = dimension,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = mips,
        sample_count    = samples,
    }
}

cts_plain :: proc(format: gpu.Texture_Format, width, height: u32) -> gpu.Texture_Descriptor {
    return cts_texture_desc(format, .D2, width, height, 1, 1, 1, {.Texture_Binding})
}

cts_max_mip_count :: proc(width, height, layers: u32) -> u32 {
    largest := max(width, max(height, layers))
    count := u32(1)
    for largest > 1 {
        largest >>= 1
        count += 1
    }
    return count
}

@(test)
cts_create_texture_zero_size_and_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 4, 4), false,
        "a 4x4 rgba8unorm texture")
    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 0, 4), true, "zero width")
    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 4, 0), true, "zero height")

    zero_layers := cts_plain(.RGBA8_Unorm, 4, 4)
    zero_layers.size.depth_or_array_layers = 0
    cts_expect_texture(t, f, zero_layers, true, "zero depthOrArrayLayers")

    zero_mips := cts_plain(.RGBA8_Unorm, 4, 4)
    zero_mips.mip_level_count = 0
    cts_expect_texture(t, f, zero_mips, false, "zero mipLevelCount means one mip")

    zero_usage := cts_plain(.RGBA8_Unorm, 4, 4)
    zero_usage.usage = {}
    cts_expect_texture(t, f, zero_usage, true, "zero usage")
}

@(test)
cts_create_texture_dimension_and_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 4, 4), false, "rgba8unorm 2d")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D1, 4, 1, 1, 1, 1, {.Texture_Binding}),
        false, "rgba8unorm 1d")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D3, 4, 4, 4, 1, 1, {.Texture_Binding}),
        false, "rgba8unorm 3d")

    cts_expect_texture(t, f, cts_plain(.Depth24Plus_Stencil8, 4, 4), false,
        "depth24plus-stencil8 2d")
    cts_expect_texture(t, f,
        cts_texture_desc(.Depth24Plus_Stencil8, .D1, 4, 1, 1, 1, 1, {.Texture_Binding}),
        true, "depth24plus-stencil8 1d")
    cts_expect_texture(t, f,
        cts_texture_desc(.Depth24Plus_Stencil8, .D3, 4, 4, 4, 1, 1, {.Texture_Binding}),
        true, "depth24plus-stencil8 3d")
}

@(test)
cts_create_texture_mip_bound :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Shape :: struct {
        dimension: gpu.Texture_Dimension,
        width:     u32,
        height:    u32,
        layers:    u32,
    }
    shapes := [4]Shape{
        {.D2, 32, 32, 1},
        {.D2, 32, 8, 1},
        {.D1, 32, 1, 1},
        {.D3, 32, 32, 32},
    }
    for shape in shapes {
        at_max := cts_max_mip_count(shape.width, shape.height, shape.layers)
        what := fmt.tprintf("%v %dx%dx%d", shape.dimension,
            shape.width, shape.height, shape.layers)

        cts_expect_texture(t, f,
            cts_texture_desc(.RGBA8_Unorm, shape.dimension,
                shape.width, shape.height, shape.layers, at_max, 1, {.Texture_Binding}),
            false, fmt.tprintf("%s: %d mips", what, at_max))

        cts_expect_texture(t, f,
            cts_texture_desc(.RGBA8_Unorm, shape.dimension,
                shape.width, shape.height, shape.layers, at_max + 1, 1, {.Texture_Binding}),
            true, fmt.tprintf("%s: %d mips", what, at_max + 1))
    }

    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D2, 32, 32, 64, 7, 1, {.Texture_Binding}),
        true, "32x32x64 with 7 mips")

    overflow := cts_plain(.RGBA8_Unorm, 32, 32)
    overflow.mip_level_count = 100
    cts_expect_texture(t, f, overflow, true, "100 mip levels on 32x32")
}

@(test)
cts_create_texture_sample_count_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usage := gpu.Texture_Usages{.Texture_Binding, .Render_Attachment}
    renderable := [4]gpu.Texture_Format{
        .RGBA8_Unorm,
        .BGRA8_Unorm,
        .RGBA16_Float,
        .Depth24Plus,
    }
    for format in renderable {
        cts_expect_texture(t, f,
            cts_texture_desc(format, .D2, 4, 4, 1, 1, 1, usage),
            false, fmt.tprintf("%v, 1 sample", format))
        cts_expect_texture(t, f,
            cts_texture_desc(format, .D2, 4, 4, 1, 1, 4, usage),
            false, fmt.tprintf("%v, 4 samples", format))
    }

    for format in ([2]gpu.Texture_Format{.RGBA8_Unorm, .Depth24Plus}) {
        cts_expect_texture(t, f,
            cts_texture_desc(format, .D2, 4, 4, 1, 1, 2, usage),
            true, fmt.tprintf("%v, 2 samples", format))
        cts_expect_texture(t, f,
            cts_texture_desc(format, .D2, 4, 4, 1, 1, 3, usage),
            true, fmt.tprintf("%v, 3 samples", format))
    }

    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D2, 8, 8, 1, 3, 4, usage),
        true, "4 samples with 3 mips")
}

@(test)
cts_create_texture_sample_count_dimension :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    usage := gpu.Texture_Usages{.Texture_Binding, .Render_Attachment}
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D2, 4, 4, 1, 1, 4, usage),
        false, "multisampled 2d")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D1, 4, 1, 1, 1, 4, usage),
        true, "multisampled 1d")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D2, 4, 4, 4, 1, 4, usage),
        true, "multisampled 2d array")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D2, 4, 4, 6, 1, 4, usage),
        true, "multisampled 6-layer array")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D3, 4, 4, 4, 1, 4, usage),
        true, "multisampled 3d")
}

@(test)
cts_create_texture_smallest :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 1, 1), false, "1x1")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D3, 1, 1, 1, 1, 1, {.Texture_Binding}),
        false, "1x1x1")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D1, 1, 1, 1, 1, 1, {.Texture_Binding}),
        false, "1d of width 1")
    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 0, 1), true, "zero width")
}

@(test)
cts_create_texture_size_limits :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_texture_dimension_1d = 64
    limits.max_texture_dimension_2d = 64
    limits.max_texture_dimension_3d = 16
    limits.max_texture_array_layers = 8
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 64, 64), false, "2d at the limit")
    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 65, 64), true,
        "2d past the width limit")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D1, 64, 1, 1, 1, 1, {.Texture_Binding}),
        false, "1d at the limit")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D1, 65, 1, 1, 1, 1, {.Texture_Binding}),
        true, "1d past the limit")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D3, 16, 16, 16, 1, 1, {.Texture_Binding}),
        false, "3d at the limit")
    cts_expect_texture(t, f,
        cts_texture_desc(.RGBA8_Unorm, .D3, 17, 16, 16, 1, 1, {.Texture_Binding}),
        true, "3d past the limit")

    layers_at := cts_plain(.RGBA8_Unorm, 4, 4)
    layers_at.size.depth_or_array_layers = 8
    cts_expect_texture(t, f, layers_at, false, "8 array layers at the limit")

    layers_past := cts_plain(.RGBA8_Unorm, 4, 4)
    layers_past.size.depth_or_array_layers = 9
    cts_expect_texture(t, f, layers_past, true, "9 array layers past the limit")
}

@(test)
cts_create_texture_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_texture(t, f, cts_plain(.RGBA8_Unorm, 4, 4), false,
        "rgba8unorm texture binding")

    render := cts_plain(.RGBA8_Unorm, 4, 4)
    render.usage = {.Render_Attachment}
    cts_expect_texture(t, f, render, false, "rgba8unorm render attachment")

    render_1d := cts_texture_desc(
        .RGBA8_Unorm, .D1, 4, 1, 1, 1, 1, {.Render_Attachment})
    cts_expect_texture(t, f, render_1d, true, "1d render attachment")

    storage := cts_plain(.R32_Uint, 4, 4)
    storage.usage = {.Storage_Binding}
    cts_expect_texture(t, f, storage, false, "r32uint storage binding")

    storage_rgba := cts_plain(.RGBA8_Unorm, 4, 4)
    storage_rgba.usage = {.Storage_Binding}
    cts_expect_texture(t, f, storage_rgba, false, "rgba8unorm storage binding")

    depth_render := cts_plain(.Depth24Plus, 4, 4)
    depth_render.usage = {.Render_Attachment}
    cts_expect_texture(t, f, depth_render, false, "depth24plus render attachment")

    copies := cts_plain(.RGBA8_Unorm, 4, 4)
    copies.usage = {.Copy_Src, .Copy_Dst}
    cts_expect_texture(t, f, copies, false, "copy source and destination")

    multisampled_storage := cts_texture_desc(
        .R32_Uint, .D2, 4, 4, 1, 1, 4, {.Storage_Binding})
    cts_expect_texture(t, f, multisampled_storage, true, "multisampled storage")
}

@(test)
cts_create_texture_view_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    srgb := [1]gpu.Texture_Format{.RGBA8_Unorm_Srgb}
    with_srgb := cts_plain(.RGBA8_Unorm, 4, 4)
    with_srgb.view_formats = srgb[:]
    cts_expect_texture(t, f, with_srgb, false,
        "rgba8unorm with an sRGB view format")

    snorm := [1]gpu.Texture_Format{.RGBA8_Snorm}
    with_snorm := cts_plain(.RGBA8_Unorm, 4, 4)
    with_snorm.view_formats = snorm[:]
    cts_expect_texture(t, f, with_snorm, true,
        "rgba8unorm with an incompatible view format")

    own := [1]gpu.Texture_Format{.RGBA8_Unorm}
    with_own := cts_plain(.RGBA8_Unorm, 4, 4)
    with_own.view_formats = own[:]
    cts_expect_texture(t, f, with_own, false, "rgba8unorm listing its own format")

    srgb_texture := cts_plain(.RGBA8_Unorm_Srgb, 4, 4)
    srgb_texture.view_formats = own[:]
    cts_expect_texture(t, f, srgb_texture, false,
        "rgba8unorm-srgb with a linear view format")
}

@(test)
cts_create_texture_compressed_dimensions :: proc(t: ^testing.T) {
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

    bc_fixture := CTS_Fixture {
        instance = f.instance,
        adapter  = f.adapter,
        device   = dev,
    }

    cts_expect_texture(t, bc_fixture, cts_plain(.BC1RGBA_Unorm, 8, 8), false, "bc1 2d")
    cts_expect_texture(t, bc_fixture,
        cts_texture_desc(.BC1RGBA_Unorm, .D3, 8, 8, 8, 1, 1, {.Texture_Binding}),
        true, "bc1 3d without the sliced-3D feature")
    cts_expect_texture(t, bc_fixture,
        cts_texture_desc(.BC1RGBA_Unorm, .D1, 8, 1, 1, 1, 1, {.Texture_Binding}),
        true, "bc1 1d")
    cts_expect_texture(t, bc_fixture, cts_plain(.BC1RGBA_Unorm, 2, 2), true,
        "bc1 smaller than one texel block")
}
