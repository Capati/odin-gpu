package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/texture/{bgra8unorm_storage,
// float32_filterable}.spec.ts`:
// descriptor rules lifted by optional features.
// The feature arms only run when the adapter offers the feature.

cts_feature_device :: proc(f: CTS_Fixture, feature: gpu.Feature_Name) -> (gpu.Device, bool) {
    if !gpu.adapter_has_feature(f.adapter, feature) {
        return nil, false
    }
    descriptor := gpu.Device_Descriptor{}
    descriptor.required_features = []gpu.Feature_Name{feature}
    return cts_make_device(f.adapter, descriptor), true
}

cts_create_texture_errors :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    sample_count: u32,
    usage: gpu.Texture_Usages,
) -> int {
    descriptor := gpu.Texture_Descriptor {
        usage           = usage,
        dimension       = .D2,
        format          = format,
        size            = {width = 1, height = 1, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = sample_count,
    }
    before := cts_errors()
    texture := gpu.device_create_texture(device, descriptor)
    errors := cts_errors() - before
    if texture != {} {
        gpu.texture_release(texture)
    }
    return errors
}

cts_bgra8_storage_texture_errors :: proc(device: gpu.Device) -> int {
    return cts_create_texture_errors(device, .BGRA8_Unorm, 1, {.Storage_Binding})
}

cts_bgra8_storage_layout_errors :: proc(device: gpu.Device) -> int {
    entries := [1]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Compute},
            type       = gpu.Storage_Texture_Binding_Layout {
                format = .BGRA8_Unorm,
                access = .Write_Only,
            },
        },
    }
    descriptor := gpu.Bind_Group_Layout_Descriptor{entries = entries[:]}
    before := cts_errors()
    layout := gpu.device_create_bind_group_layout(device, descriptor)
    errors := cts_errors() - before
    if layout != {} {
        gpu.bind_group_layout_release(layout)
    }
    return errors
}

@(test)
cts_texture_bgra8unorm_storage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_outcome(t, cts_bgra8_storage_texture_errors(f.device), true,
        "bgra8unorm storage texture without the feature")
    cts_expect_outcome(t, cts_bgra8_storage_layout_errors(f.device), true,
        "bgra8unorm storage layout without the feature")

    featured, have_feature := cts_feature_device(f, .BGRA8_Unorm_Storage)
    if have_feature {
        defer gpu.device_release(featured)
        cts_expect_outcome(t, cts_bgra8_storage_texture_errors(featured), false,
            "bgra8unorm storage texture with the feature")
        cts_expect_outcome(t, cts_bgra8_storage_layout_errors(featured), false,
            "bgra8unorm storage layout with the feature")
    }
}

cts_bundle_errors :: proc(device: gpu.Device, format: gpu.Texture_Format) -> int {
    formats := [1]gpu.Texture_Format{format}
    descriptor := gpu.Render_Bundle_Encoder_Descriptor {
        color_formats = formats[:],
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
cts_texture_rg11b10ufloat_renderable :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    cts_expect_outcome(t, cts_create_texture_errors(f.device, .RG11B10_Ufloat, 1,
        {.Render_Attachment}), true, "render attachment without the feature")
    cts_expect_outcome(t, cts_bundle_errors(f.device, .RG11B10_Ufloat), true,
        "bundle without the feature")

    featured, have_feature := cts_feature_device(f, .RG11B10_Ufloat_Renderable)
    if !have_feature {
        return
    }
    defer gpu.device_release(featured)

    sample_counts := [2]u32{1, 4}
    for sample_count in sample_counts {
        cts_expect_outcome(t, cts_create_texture_errors(featured, .RG11B10_Ufloat,
            sample_count, {.Render_Attachment}), false,
            "render attachment with the feature")
    }

    feature_fixture := CTS_Fixture {
        instance = f.instance,
        adapter  = f.adapter,
        device   = featured,
    }
    texture, view := cts_attachment_texture(featured, .RG11B10_Ufloat, 1)
    attachments := [1]gpu.Render_Pass_Color_Attachment {
        {view = view, ops = {load = .Clear, store = .Store}},
    }
    errors := cts_try_render_pass(t, feature_fixture, {
        color_attachments = attachments[:],
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "single-sampled pass with the feature")
    gpu.texture_view_release(view)
    gpu.texture_release(texture)

    cts_expect_outcome(t, cts_bundle_errors(featured, .RG11B10_Ufloat), false,
        "bundle with the feature")

    pipeline := cts_make_render_pipeline(featured, .RG11B10_Ufloat)
    testing.expect(t, pipeline != {}, "failed to create the RG11B10 pipeline")
    gpu.render_pipeline_release(pipeline)
}

cts_float32_bind_group_errors :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    sample_type: gpu.Texture_Sample_Type,
) -> int {
    texture := gpu.device_create_texture(device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = format,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    if texture == {} {
        return 1
    }
    defer gpu.texture_release(texture)
    view := gpu.texture_create_view(texture, {})
    if view == {} {
        return 1
    }
    defer gpu.texture_view_release(view)

    entries := [1]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Fragment},
            type       = gpu.Texture_Binding_Layout{sample_type = sample_type},
        },
    }
    layout_descriptor := gpu.Bind_Group_Layout_Descriptor{entries = entries[:]}
    before := cts_errors()
    layout := gpu.device_create_bind_group_layout(device, layout_descriptor)
    layout_errors := cts_errors() - before
    if layout == {} {
        return max(layout_errors, 1)
    }
    defer gpu.bind_group_layout_release(layout)

    group_entries := [1]gpu.Bind_Group_Entry {
        {binding = 0, resource = view},
    }
    group_descriptor := gpu.Bind_Group_Descriptor {
        layout  = layout,
        entries = group_entries[:],
    }
    before = cts_errors()
    group := gpu.device_create_bind_group(device, group_descriptor)
    errors := cts_errors() - before
    if group != {} {
        gpu.bind_group_release(group)
    }
    return errors
}

@(test)
cts_texture_float32_filterable :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    formats := [3]gpu.Texture_Format{.R32_Float, .RG32_Float, .RGBA32_Float}
    sample_types := [2]gpu.Texture_Sample_Type{.Float, .Unfilterable_Float}

    featured, have_feature := cts_feature_device(f, .Float32_Filterable)
    defer if featured != nil {
        gpu.device_release(featured)
    }
    if have_feature && featured == nil {
        testing.fail_now(t, "float32 feature advertised but device creation failed")
    }

    any_accepted := false
    any_refused := false
    for format in formats {
        for sample_type in sample_types {
            needs_feature := sample_type == .Float
            errors := cts_float32_bind_group_errors(f.device, format, sample_type)
            cts_expect_outcome(t, errors, needs_feature, "float32 texture binding")
            if needs_feature {
                any_refused = true
            } else {
                any_accepted = true
            }

            if have_feature {
                errors = cts_float32_bind_group_errors(featured, format, sample_type)
                cts_expect_outcome(t, errors, false,
                    "float32 texture binding with the feature")
                any_accepted = true
            }
        }
    }
    cts_require_both(t, any_accepted, any_refused, "float32_filterable")
}
