package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/createBindGroup.spec.ts`:
// entry count/kind, buffer usage/alignment/
// range/min-size, texture usage/shape/sample type, sampler comparison type,
// storage-texture shape, resource state and device ownership.

cts_bg_layout :: proc(
    device: gpu.Device,
    entry: gpu.Bind_Group_Layout_Entry,
) -> gpu.Bind_Group_Layout {
    entries := [1]gpu.Bind_Group_Layout_Entry{entry}
    return gpu.device_create_bind_group_layout(device, {entries = entries[:]})
}

cts_bg_errors :: proc(
    device: gpu.Device,
    layout: gpu.Bind_Group_Layout,
    entries: []gpu.Bind_Group_Entry,
) -> int {
    before := cts_errors()
    group := gpu.device_create_bind_group(device, {layout = layout, entries = entries})
    errors := cts_errors() - before
    if group != {} {
        gpu.bind_group_release(group)
    }
    return errors
}

cts_bg_buffer_entry :: proc(buffer: gpu.Buffer, offset: u64, size: u64) -> gpu.Bind_Group_Entry {
    return {
        binding  = 0,
        resource = gpu.Buffer_Binding{buffer = buffer, offset = offset, size = size},
    }
}

cts_bg_texture_entry :: proc(view: gpu.Texture_View) -> gpu.Bind_Group_Entry {
    return {binding = 0, resource = view}
}

cts_bg_sampler_entry :: proc(sampler: gpu.Sampler) -> gpu.Bind_Group_Entry {
    return {binding = 0, resource = sampler}
}

cts_bg_buffer_layout :: proc(type: gpu.Buffer_Binding_Type, min_size := u64(0)) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = 0,
        visibility = {.Fragment},
        type       = gpu.Buffer_Binding_Layout{type = type, min_binding_size = min_size},
    }
}

cts_bg_texture_layout :: proc(
    sample_type: gpu.Texture_Sample_Type,
    dimension: gpu.Texture_View_Dimension,
    multisampled := false,
) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = 0,
        visibility = {.Fragment},
        type       = gpu.Texture_Binding_Layout {
            sample_type    = sample_type,
            view_dimension = dimension,
            multisampled   = multisampled,
        },
    }
}

cts_bg_sampler_layout :: proc(type: gpu.Sampler_Binding_Type) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = 0,
        visibility = {.Fragment},
        type       = gpu.Sampler_Binding_Layout{type = type},
    }
}

cts_bg_storage_layout :: proc(format: gpu.Texture_Format) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = 0,
        visibility = {.Fragment},
        type       = gpu.Storage_Texture_Binding_Layout {
            access         = .Write_Only,
            format         = format,
            view_dimension = .D2,
        },
    }
}

@(test)
cts_create_bind_group_count_and_kind :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_bg_layout(f.device, cts_bg_buffer_layout(.Uniform))
    testing.expect(t, layout != {}, "failed to create the layout")
    defer gpu.bind_group_layout_release(layout)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform, .Copy_Dst}})
    defer gpu.buffer_release(buffer)

    matching := cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{matching}),
        false, "one entry matching the layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, nil), true,
        "no entry for the layout's binding")

    wrong_kind := matching
    wrong_kind.resource = gpu.Sampler{}
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{wrong_kind}),
        true, "a sampler where the layout wants a buffer")

    other_binding := matching
    other_binding.binding = 1
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{other_binding}),
        true, "an entry for an undeclared binding")
}

@(test)
cts_create_bind_group_buffer_rules :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_bg_layout(f.device, cts_bg_buffer_layout(.Uniform))
    testing.expect(t, layout != {}, "failed to create the layout")
    defer gpu.bind_group_layout_release(layout)
    usable := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform, .Copy_Dst}})
    copy_only := gpu.device_create_buffer(f.device, {size = 256, usage = {.Copy_Dst}})
    defer gpu.buffer_release(usable)
    defer gpu.buffer_release(copy_only)

    row :: proc(t: ^testing.T, f: CTS_Fixture, layout: gpu.Bind_Group_Layout,
        entry: gpu.Bind_Group_Entry, should_fail: bool, what: string) {
        cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{entry}),
            should_fail, what)
    }
    row(t, f, layout, cts_bg_buffer_entry(usable, 0, gpu.WHOLE_SIZE), false,
        "uniform buffer with uniform usage")
    row(t, f, layout, cts_bg_buffer_entry(copy_only, 0, gpu.WHOLE_SIZE), true,
        "buffer without uniform usage")
    row(t, f, layout, cts_bg_buffer_entry(usable, 240, 32), true,
        "range past the buffer's end")
    row(t, f, layout, cts_bg_buffer_entry(usable, 2, 16), true,
        "offset past the binding alignment")
    row(t, f, layout, cts_bg_buffer_entry(usable, 0, 16), false, "16-byte range")
}

@(test)
cts_create_bind_group_min_binding_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_bg_layout(f.device, cts_bg_buffer_layout(.Uniform, 32))
    testing.expect(t, layout != {}, "failed to create the layout")
    defer gpu.bind_group_layout_release(layout)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform, .Copy_Dst}})
    defer gpu.buffer_release(buffer)

    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 32)}), false,
        "range exactly min_binding_size")
    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, 16)}), true,
        "range under min_binding_size")
    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)}), false,
        "the rest of the buffer")
}

@(test)
cts_create_bind_group_texture_rules :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Float, .D2))
    sint_layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Sint, .D2))
    array_layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Float, .D2_Array))
    testing.expect(t, layout != {} && sint_layout != {} && array_layout != {},
        "failed to create the layouts")
    defer gpu.bind_group_layout_release(layout)
    defer gpu.bind_group_layout_release(sint_layout)
    defer gpu.bind_group_layout_release(array_layout)
    sampled := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    copy_only := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Copy_Src})
    defer gpu.texture_release(sampled)
    defer gpu.texture_release(copy_only)
    view := gpu.texture_create_view(sampled, {})
    copy_view := gpu.texture_create_view(copy_only, {})
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(copy_view)

    entry := cts_bg_texture_entry(view)
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{entry}),
        false, "sampled texture with the texture usage")
    entry = cts_bg_texture_entry(copy_view)
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{entry}),
        true, "view without the texture usage")
    entry = cts_bg_texture_entry(view)
    cts_expect_outcome(t, cts_bg_errors(f.device, sint_layout, []gpu.Bind_Group_Entry{entry}),
        true, "sint layout binding a float view")
    cts_expect_outcome(t, cts_bg_errors(f.device, array_layout, []gpu.Bind_Group_Entry{entry}),
        true, "2d-array layout binding a 2d view")
}

@(test)
cts_create_bind_group_multisampled :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    ms_layout := cts_bg_layout(f.device,
        cts_bg_texture_layout(.Unfilterable_Float, .D2, true))
    plain_layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Float, .D2))
    testing.expect(t, ms_layout != {} && plain_layout != {}, "failed to create the layouts")
    defer gpu.bind_group_layout_release(ms_layout)
    defer gpu.bind_group_layout_release(plain_layout)
    multisampled := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 4,
        {.Texture_Binding, .Render_Attachment})
    single := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    defer gpu.texture_release(multisampled)
    defer gpu.texture_release(single)
    ms_view := gpu.texture_create_view(multisampled, {})
    single_view := gpu.texture_create_view(single, {})
    defer gpu.texture_view_release(ms_view)
    defer gpu.texture_view_release(single_view)

    cts_expect_outcome(t, cts_bg_errors(f.device, ms_layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(ms_view)}), false,
        "multisampled view with a multisampled layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, ms_layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(single_view)}), true,
        "single-sample view with a multisampled layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, plain_layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(ms_view)}), true,
        "multisampled view with a plain layout")
}

@(test)
cts_create_bind_group_sampler_type :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    comparison := gpu.device_create_sampler(f.device, {compare = .Less, mag_filter = .Linear})
    filtering := gpu.device_create_sampler(f.device, {mag_filter = .Linear})
    defer gpu.sampler_release(comparison)
    defer gpu.sampler_release(filtering)
    comparison_layout := cts_bg_layout(f.device, cts_bg_sampler_layout(.Comparison))
    filtering_layout := cts_bg_layout(f.device, cts_bg_sampler_layout(.Filtering))
    non_filtering_layout := cts_bg_layout(f.device, cts_bg_sampler_layout(.Non_Filtering))
    testing.expect(t, comparison_layout != {} && filtering_layout != {} &&
        non_filtering_layout != {}, "failed to create the layouts")
    defer gpu.bind_group_layout_release(comparison_layout)
    defer gpu.bind_group_layout_release(filtering_layout)
    defer gpu.bind_group_layout_release(non_filtering_layout)

    cts_expect_outcome(t, cts_bg_errors(f.device, comparison_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(comparison)}), false,
        "comparison sampler with a comparison layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, comparison_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(filtering)}), true,
        "filtering sampler with a comparison layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, filtering_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(comparison)}), true,
        "comparison sampler with a filtering layout")
    cts_expect_outcome(t, cts_bg_errors(f.device, non_filtering_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(comparison)}), true,
        "comparison sampler with a non-filtering layout")
}

@(test)
cts_create_bind_group_storage_texture :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    layout := cts_bg_layout(f.device, cts_bg_storage_layout(.R32_Uint))
    sint_layout := cts_bg_layout(f.device, cts_bg_storage_layout(.R32_Sint))
    testing.expect(t, layout != {} && sint_layout != {}, "failed to create the layouts")
    defer gpu.bind_group_layout_release(layout)
    defer gpu.bind_group_layout_release(sint_layout)
    texture := cts_rp_texture(f.device, .R32_Uint, 4, 4, 1, 1, 1, {.Storage_Binding})
    defer gpu.texture_release(texture)
    view := gpu.texture_create_view(texture, {})
    defer gpu.texture_view_release(view)

    entry := cts_bg_texture_entry(view)
    cts_expect_outcome(t, cts_bg_errors(f.device, layout, []gpu.Bind_Group_Entry{entry}),
        false, "storage texture with matching format")
    cts_expect_outcome(t, cts_bg_errors(f.device, sint_layout, []gpu.Bind_Group_Entry{entry}),
        true, "R32_SINT layout binding an R32_UINT view")

    chained := cts_rp_texture(f.device, .R32_Uint, 8, 8, 1, 3, 1, {.Storage_Binding})
    defer gpu.texture_release(chained)
    chained_view := gpu.texture_create_view(chained, {})
    defer gpu.texture_view_release(chained_view)
    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(chained_view)}), true,
        "storage view of three mips")
}

@(test)
cts_create_bind_group_resource_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    buffer_layout := cts_bg_layout(f.device, cts_bg_buffer_layout(.Uniform))
    texture_layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Float, .D2))
    testing.expect(t, buffer_layout != {} && texture_layout != {},
        "failed to create the layouts")
    defer gpu.bind_group_layout_release(buffer_layout)
    defer gpu.bind_group_layout_release(texture_layout)

    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform, .Copy_Dst}})
    entry := cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)
    gpu.buffer_release(buffer)
    cts_expect_outcome(t, cts_bg_errors(f.device, buffer_layout,
        []gpu.Bind_Group_Entry{entry}), true, "a released buffer")

    texture := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    view := gpu.texture_create_view(texture, {})
    defer gpu.texture_view_release(view)
    texture_entry := cts_bg_texture_entry(view)
    gpu.texture_destroy(texture)
    cts_expect_outcome(t, cts_bg_errors(f.device, texture_layout,
        []gpu.Bind_Group_Entry{texture_entry}), true,
        "a released texture behind a live view")
    gpu.texture_release(texture)
}

@(test)
cts_create_bind_group_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    layout := cts_bg_layout(f.device, cts_bg_buffer_layout(.Uniform))
    other_layout := cts_bg_layout(other, cts_bg_buffer_layout(.Uniform))
    defer gpu.bind_group_layout_release(layout)
    defer gpu.bind_group_layout_release(other_layout)
    buffer := gpu.device_create_buffer(f.device, {size = 256, usage = {.Uniform, .Copy_Dst}})
    other_buffer := gpu.device_create_buffer(other, {size = 256, usage = {.Uniform, .Copy_Dst}})
    defer gpu.buffer_release(buffer)
    defer gpu.buffer_release(other_buffer)

    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)}), false,
        "group built entirely on this device")
    cts_expect_outcome(t, cts_bg_errors(f.device, other_layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(buffer, 0, gpu.WHOLE_SIZE)}), true,
        "layout from another device")
    cts_expect_outcome(t, cts_bg_errors(f.device, layout,
        []gpu.Bind_Group_Entry{cts_bg_buffer_entry(other_buffer, 0, gpu.WHOLE_SIZE)}), true,
        "buffer from another device")

    sampler_layout := cts_bg_layout(f.device, cts_bg_sampler_layout(.Filtering))
    defer gpu.bind_group_layout_release(sampler_layout)
    sampler := gpu.device_create_sampler(f.device, {mag_filter = .Linear})
    other_sampler := gpu.device_create_sampler(other, {mag_filter = .Linear})
    defer gpu.sampler_release(sampler)
    defer gpu.sampler_release(other_sampler)
    cts_expect_outcome(t, cts_bg_errors(f.device, sampler_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(sampler)}), false,
        "this device's sampler")
    cts_expect_outcome(t, cts_bg_errors(f.device, sampler_layout,
        []gpu.Bind_Group_Entry{cts_bg_sampler_entry(other_sampler)}), true,
        "sampler from another device")

    texture_layout := cts_bg_layout(f.device, cts_bg_texture_layout(.Float, .D2))
    defer gpu.bind_group_layout_release(texture_layout)
    texture := cts_rp_texture(f.device, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    other_texture := cts_rp_texture(other, .RGBA8_Unorm, 4, 4, 1, 1, 1, {.Texture_Binding})
    defer gpu.texture_release(texture)
    defer gpu.texture_release(other_texture)
    view := gpu.texture_create_view(texture, {})
    other_view := gpu.texture_create_view(other_texture, {})
    defer gpu.texture_view_release(view)
    defer gpu.texture_view_release(other_view)
    cts_expect_outcome(t, cts_bg_errors(f.device, texture_layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(view)}), false,
        "this device's texture view")
    cts_expect_outcome(t, cts_bg_errors(f.device, texture_layout,
        []gpu.Bind_Group_Entry{cts_bg_texture_entry(other_view)}), true,
        "texture view from another device")
}
