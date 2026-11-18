package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/createView.spec.ts`.

cts_view_texture :: proc(
    f: CTS_Fixture,
    format: gpu.Texture_Format,
    width, height, layers, mips: u32,
    usage: gpu.Texture_Usages,
) -> gpu.Texture {
    texture := gpu.device_create_texture(f.device, {
        usage           = usage,
        dimension       = .D2,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = mips,
        sample_count    = 1,
    })
    assert(texture != {}, "failed to create the view texture")
    return texture
}

cts_expect_view :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    texture: gpu.Texture,
    descriptor: gpu.Texture_View_Descriptor,
    should_fail: bool,
    what: string,
) {
    before := cts_errors()
    view := gpu.texture_create_view(texture, descriptor)
    errors := cts_errors() - before
    if view != {} {
        gpu.texture_view_release(view)
    }

    if should_fail {
        testing.expectf(t, errors > 0 && view == {},
            "%s: accepted, expected a validation error", what)
    } else {
        testing.expectf(t, errors == 0 && view != {},
            "%s: refused (%d errors)", what, errors)
    }
}

@(test)
cts_create_view_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    srgb := [1]gpu.Texture_Format{.RGBA8_Unorm_Srgb}
    texture := gpu.device_create_texture(f.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        view_formats    = srgb[:],
    })
    defer gpu.texture_release(texture)

    cts_expect_view(t, f, texture, {format = .RGBA8_Unorm}, false,
        "the texture's own format")
    cts_expect_view(t, f, texture, {format = .RGBA8_Unorm_Srgb}, false,
        "a listed view format")
    cts_expect_view(t, f, texture, {format = .RGBA8_Snorm}, true,
        "an incompatible format")

    plain := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, {.Texture_Binding})
    defer gpu.texture_release(plain)
    cts_expect_view(t, f, plain, {format = .RGBA8_Unorm_Srgb}, true,
        "a format the texture did not list")
}

@(test)
cts_create_view_dimension :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    array := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 6, 1, {.Texture_Binding})
    defer gpu.texture_release(array)
    cts_expect_view(t, f, array, {dimension = .D2}, false,
        "a 2D view of a 2D array texture")
    cts_expect_view(t, f, array, {dimension = .D2_Array}, false, "a 2D-array view")
    cts_expect_view(t, f, array,
        {dimension = .Cube, array_layer_count = 6}, false,
        "a cube view of six square layers")
    cts_expect_view(t, f, array, {dimension = .D3}, true,
        "a 3D view of a 2D texture")

    volume := gpu.device_create_texture(f.device, {
        usage           = {.Texture_Binding},
        dimension       = .D3,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 4},
        mip_level_count = 1,
    })
    defer gpu.texture_release(volume)
    cts_expect_view(t, f, volume, {dimension = .D3}, false,
        "a 3D view of a 3D texture")
    cts_expect_view(t, f, volume, {dimension = .D2}, true,
        "a 2D view of a 3D texture")
}

@(test)
cts_create_view_aspect :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    combined := cts_view_texture(f, .Depth24Plus_Stencil8, 4, 4, 1, 1,
        {.Texture_Binding, .Render_Attachment})
    defer gpu.texture_release(combined)
    cts_expect_view(t, f, combined, {aspect = .All}, false,
        "all aspects of a combined format")
    cts_expect_view(t, f, combined, {aspect = .Depth_Only}, false, "the depth aspect")
    cts_expect_view(t, f, combined, {aspect = .Stencil_Only}, false,
        "the stencil aspect")

    depth_only := cts_view_texture(f, .Depth32_Float, 4, 4, 1, 1,
        {.Texture_Binding, .Render_Attachment})
    defer gpu.texture_release(depth_only)
    cts_expect_view(t, f, depth_only, {aspect = .Stencil_Only}, true,
        "the stencil aspect of depth32float")

    color := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, {.Texture_Binding})
    defer gpu.texture_release(color)
    cts_expect_view(t, f, color, {aspect = .Depth_Only}, true,
        "the depth aspect of a colour format")
}

@(test)
cts_create_view_array_layers :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 6, 1, {.Texture_Binding})
    defer gpu.texture_release(texture)

    cts_expect_view(t, f, texture,
        {dimension = .D2_Array, array_layer_count = 6}, false, "all six layers")
    cts_expect_view(t, f, texture,
        {dimension = .D2_Array, base_array_layer = 2, array_layer_count = 2}, false,
        "two layers from layer 2")
    cts_expect_view(t, f, texture,
        {dimension = .D2_Array, base_array_layer = 4, array_layer_count = 4}, true,
        "four layers from layer 4")
    cts_expect_view(t, f, texture,
        {dimension = .Cube, array_layer_count = 3}, true,
        "a cube view of three layers")
}

@(test)
cts_create_view_mip_levels :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_view_texture(f, .RGBA8_Unorm, 8, 8, 1, 4, {.Texture_Binding})
    defer gpu.texture_release(texture)

    cts_expect_view(t, f, texture, {mip_level_count = 4}, false, "all four mips")
    cts_expect_view(t, f, texture,
        {base_mip_level = 1, mip_level_count = 2}, false, "two mips from mip 1")
    cts_expect_view(t, f, texture,
        {base_mip_level = 3, mip_level_count = 2}, true,
        "two mips from the last mip")
    cts_expect_view(t, f, texture, {base_mip_level = 4}, true,
        "a base mip past the chain")
}

@(test)
cts_create_view_cube_faces_square :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    square := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 6, 1, {.Texture_Binding})
    defer gpu.texture_release(square)
    cts_expect_view(t, f, square, {dimension = .Cube, array_layer_count = 6}, false,
        "a cube view of a square texture")

    wide := cts_view_texture(f, .RGBA8_Unorm, 4, 8, 6, 1, {.Texture_Binding})
    defer gpu.texture_release(wide)
    cts_expect_view(t, f, wide, {dimension = .Cube, array_layer_count = 6}, true,
        "a cube view of a non-square texture")
}

@(test)
cts_create_view_texture_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 1, 1, {.Texture_Binding})
    cts_expect_view(t, f, texture, {}, false, "a view of a live texture")
    gpu.texture_release(texture)
    cts_expect_view(t, f, texture, {}, true, "a view of a released texture")
}

@(test)
cts_create_view_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    texture := cts_view_texture(f, .RGBA8_Unorm, 4, 4, 1, 1,
        {.Texture_Binding, .Copy_Src})
    defer gpu.texture_release(texture)

    cts_expect_view(t, f, texture, {}, false, "no usage (inherit)")
    cts_expect_view(t, f, texture, {usage = {.Texture_Binding}}, false,
        "texture binding, a subset")
    cts_expect_view(t, f, texture, {usage = {.Texture_Binding, .Copy_Src}}, false,
        "both usages")
    cts_expect_view(t, f, texture, {usage = {.Storage_Binding}}, true,
        "a usage the texture does not have")
}
