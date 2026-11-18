package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/capability_checks/features/
// texture_formats.spec.ts`:
// an optional
// format is refused by every entry point until the device requests its feature.

cts_optional_formats := [13]struct {
    format:  gpu.Texture_Format,
    feature: gpu.Feature_Name,
}{
    {.BC1RGBA_Unorm, .Texture_Compression_BC},
    {.BC3RGBA_Unorm_Srgb, .Texture_Compression_BC},
    {.BC4R_Unorm, .Texture_Compression_BC},
    {.BC6HRGB_Ufloat, .Texture_Compression_BC},
    {.BC7RGBA_Unorm, .Texture_Compression_BC},
    {.ETC2RGB8_Unorm, .Texture_Compression_ETC2},
    {.EACRG11_Unorm, .Texture_Compression_ETC2},
    {.ASTC4x4_Unorm, .Texture_Compression_ASTC},
    {.ASTC12x12_Unorm_Srgb, .Texture_Compression_ASTC},
    {.Depth32Float_Stencil8, .Depth32_Float_Stencil8},
    {.R16_Unorm, .Texture_Format_16Bit_Norm},
    {.RGBA16_Snorm, .Texture_Format_16Bit_Norm},
    {.NV12, .Texture_Format_Nv12},
}

cts_capability_device :: proc(
    f: CTS_Fixture,
    feature: gpu.Feature_Name,
) -> (gpu.Device, bool) {
    if !gpu.adapter_has_feature(f.adapter, feature) {
        return nil, false
    }
    descriptor := gpu.Device_Descriptor{}
    descriptor.required_features = []gpu.Feature_Name{feature}
    return cts_make_device(f.adapter, descriptor), true
}

cts_capability_texture_errors :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    dimension: gpu.Texture_Dimension,
    width, height, depth: u32,
    with_view_formats: bool,
) -> int {
    descriptor := gpu.Texture_Descriptor {
        usage           = {.Texture_Binding},
        dimension       = dimension,
        format          = format,
        size            = {width = width, height = height, depth_or_array_layers = depth},
        mip_level_count = 1,
        sample_count    = 1,
    }
    if with_view_formats {
        view_formats := [1]gpu.Texture_Format{format}
        descriptor.view_formats = view_formats[:]
    }
    before := cts_errors()
    texture := gpu.device_create_texture(device, descriptor)
    errors := cts_errors() - before
    if texture != {} {
        gpu.texture_release(texture)
    }
    return errors
}

cts_capability_extent :: proc(format: gpu.Texture_Format) -> (u32, u32) {
    block_width, block_height := gpu.texture_format_block_dimensions(format)
    return max(u32(1), block_width), max(u32(1), block_height)
}

cts_capability_layout_errors :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    access: gpu.Storage_Texture_Access,
) -> int {
    entry := cts_layout_storage(0, {.Compute}, access, format)
    return cts_layout_errors(device, []gpu.Bind_Group_Layout_Entry{entry})
}

cts_capability_view_errors :: proc(
    device: gpu.Device,
    base: gpu.Texture,
    format: gpu.Texture_Format,
) -> int {
    before := cts_errors()
    view := gpu.texture_create_view(base, {format = format})
    errors := cts_errors() - before
    if view != {} {
        gpu.texture_view_release(view)
    }
    return errors
}

cts_capability_depth_pipeline_errors :: proc(device: gpu.Device) -> int {
    targets := [1]gpu.Color_Target_State {
        {format = .RGBA8_Unorm, write_mask = gpu.COLOR_WRITES_ALL},
    }
    depth := gpu.Depth_Stencil_State {
        format              = .Depth32Float_Stencil8,
        depth_compare       = .Always,
        depth_write_enabled = false,
    }
    before := cts_errors()
    pipeline := cts_make_render_pipeline_full(device, targets[:], &depth, 1)
    errors := cts_errors() - before
    if pipeline != {} {
        gpu.render_pipeline_release(pipeline)
    }
    return errors
}

cts_capability_bundle_errors :: proc(device: gpu.Device) -> int {
    formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
    depth := gpu.Render_Bundle_Depth_Stencil {
        depth_stencil_format = .Depth32Float_Stencil8,
    }
    descriptor := gpu.Render_Bundle_Encoder_Descriptor {
        color_formats = formats[:],
        depth_stencil = &depth,
        sample_count  = 1,
    }
    before := cts_errors()
    encoder := gpu.device_create_render_bundle_encoder(device, descriptor)
    errors := cts_errors() - before
    if encoder != {} {
        gpu.render_bundle_encoder_release(encoder)
    }
    return errors
}

@(test)
cts_capability_texture_view_descriptor :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    base := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    defer gpu.texture_release(base)

    any_accepted := false
    any_refused := false
    for row in cts_optional_formats {
        errors := cts_capability_view_errors(f.device, base, row.format)
        cts_expect_outcome(t, errors, true, "optional view format without its feature")
        any_refused = true

        device, have := cts_capability_device(f, row.feature)
        if !have {
            continue
        }
        defer gpu.device_release(device)
        width, height := cts_capability_extent(row.format)
        texture := cts_rp_texture(device, row.format, width, height, 1, 1, 1,
            {.Texture_Binding})
        errors = cts_capability_view_errors(device, texture, row.format)
        gpu.texture_release(texture)
        cts_expect_outcome(t, errors, false, "optional view format with its feature")
        any_accepted = true
    }
    cts_require_both(t, any_accepted, any_refused, "texture_view_descriptor")
}

@(test)
cts_capability_sliced_3d :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    any_accepted := false
    any_refused := false
    Row :: struct {
        format:         gpu.Texture_Format,
        base_feature:   gpu.Feature_Name,
        sliced_feature: gpu.Feature_Name,
    }
    rows := [2]Row{
        {.BC1RGBA_Unorm, .Texture_Compression_BC, .Texture_Compression_BC_Sliced_3D},
        {.ASTC4x4_Unorm, .Texture_Compression_ASTC, .Texture_Compression_ASTC_Sliced_3D},
    }
    for row in rows {
        base_device, have_base := cts_capability_device(f, row.base_feature)
        if !have_base {
            continue
        }
        errors := cts_capability_texture_errors(
            base_device, row.format, .D3, 8, 8, 8, false)
        cts_expect_outcome(t, errors, true, "3D compressed texture without sliced feature")
        gpu.device_release(base_device)
        any_refused = true

        if !gpu.adapter_has_feature(f.adapter, row.sliced_feature) {
            continue
        }
        descriptor := gpu.Device_Descriptor{}
        descriptor.required_features = []gpu.Feature_Name{row.base_feature, row.sliced_feature}
        device := cts_make_device(f.adapter, descriptor)
        if device == nil {
            continue
        }
        errors = cts_capability_texture_errors(device, row.format, .D3, 8, 8, 8, false)
        cts_expect_outcome(t, errors, false, "3D compressed texture with sliced feature")
        gpu.device_release(device)
        any_accepted = true
    }

    etc2, have_etc2 := cts_capability_device(f, .Texture_Compression_ETC2)
    if have_etc2 {
        errors := cts_capability_texture_errors(etc2, .ETC2RGB8_Unorm, .D3, 8, 8, 8, false)
        cts_expect_outcome(t, errors, true, "3D ETC2 with only the base feature")
        gpu.device_release(etc2)
        any_refused = true
    }
    cts_require_both(t, any_accepted, any_refused, "sliced_3d")
}

@(test)
cts_capability_storage_layout :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    Row :: struct {
        format:  gpu.Texture_Format,
        feature: gpu.Feature_Name,
    }
    rows := [2]Row{
        {.R16_Unorm, .Texture_Format_16Bit_Norm},
        {.RGBA16_Snorm, .Texture_Format_16Bit_Norm},
    }
    accesses := [2]gpu.Storage_Texture_Access{.Write_Only, .Read_Only}
    any_accepted := false
    any_refused := false
    for row in rows {
        for access in accesses {
            errors := cts_capability_layout_errors(f.device, row.format, access)
            cts_expect_outcome(t, errors, true,
                "optional storage format without its feature")
            any_refused = true

            device, have := cts_capability_device(f, row.feature)
            if !have {
                continue
            }
            errors = cts_capability_layout_errors(device, row.format, access)
            cts_expect_outcome(t, errors, false,
                "optional storage format with its feature")
            gpu.device_release(device)
            any_accepted = true
        }
    }
    cts_require_both(t, any_accepted, any_refused, "storage_texture_binding_layout")
}

@(test)
cts_capability_depth_stencil_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_expect_outcome(t, cts_capability_depth_pipeline_errors(f.device), true,
        "depth32float-stencil8 pipeline without the feature")

    device, have := cts_capability_device(f, .Depth32_Float_Stencil8)
    if have {
        defer gpu.device_release(device)
        cts_expect_outcome(t, cts_capability_depth_pipeline_errors(device), false,
            "depth32float-stencil8 pipeline with the feature")
    }
}

@(test)
cts_capability_bundle_depth_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    cts_expect_outcome(t, cts_capability_bundle_errors(f.device), true,
        "bundle depth32float-stencil8 without the feature")

    device, have := cts_capability_device(f, .Depth32_Float_Stencil8)
    if have {
        defer gpu.device_release(device)
        cts_expect_outcome(t, cts_capability_bundle_errors(device), false,
            "bundle depth32float-stencil8 with the feature")
    }
}

@(test)
cts_capability_guarantees :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    features := []gpu.Feature_Name {
        .Texture_Compression_BC,
        .Texture_Compression_ETC2,
        .Texture_Compression_ASTC,
        .Texture_Compression_BC_Sliced_3D,
        .Texture_Compression_ASTC_Sliced_3D,
    }
    has_bc := gpu.adapter_has_feature(f.adapter, features[0])
    has_etc2 := gpu.adapter_has_feature(f.adapter, features[1])
    has_astc := gpu.adapter_has_feature(f.adapter, features[2])
    testing.expect(t, has_bc || (has_etc2 && has_astc),
        "the adapter must support BC, or both ETC2 and ASTC")
    if gpu.adapter_has_feature(f.adapter, features[3]) {
        testing.expect(t, has_bc, "BC sliced-3D implies BC")
    }
    if gpu.adapter_has_feature(f.adapter, features[4]) {
        testing.expect(t, has_astc, "ASTC sliced-3D implies ASTC")
    }
}

@(test)
cts_capability_texture_descriptor :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    any_accepted := false
    any_refused := false
    for row in cts_optional_formats {
        width, height := cts_capability_extent(row.format)
        errors := cts_capability_texture_errors(
            f.device, row.format, .D2, width, height, 1, false)
        cts_expect_outcome(t, errors, true, "optional format without its feature")
        any_refused = true

        device, have := cts_capability_device(f, row.feature)
        if !have {
            continue
        }
        defer gpu.device_release(device)
        errors = cts_capability_texture_errors(
            device, row.format, .D2, width, height, 1, false)
        cts_expect_outcome(t, errors, false, "optional format with its feature")
        any_accepted = true
    }
    cts_require_both(t, any_accepted, any_refused, "texture_descriptor")
}

@(test)
cts_capability_texture_view_formats :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    any_accepted := false
    any_refused := false
    for row in cts_optional_formats {
        width, height := cts_capability_extent(row.format)
        errors := cts_capability_texture_errors(
            f.device, row.format, .D2, width, height, 1, true)
        cts_expect_outcome(t, errors, true,
            "optional view format without its feature")
        any_refused = true

        device, have := cts_capability_device(f, row.feature)
        if !have {
            continue
        }
        defer gpu.device_release(device)
        errors = cts_capability_texture_errors(
            device, row.format, .D2, width, height, 1, true)
        cts_expect_outcome(t, errors, false,
            "optional view format with its feature")
        any_accepted = true
    }
    cts_require_both(t, any_accepted, any_refused, "texture_descriptor_view_formats")
}
