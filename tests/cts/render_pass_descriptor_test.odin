package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/render_pass/render_pass_descriptor.spec.ts`:
// what a render-pass descriptor
// may attach, its shape rules and the resolve target's shape/format/usage.

cts_rp_texture :: proc(
    device: gpu.Device,
    format: gpu.Texture_Format,
    width: u32 = 16,
    height: u32 = 16,
    layers: u32 = 1,
    mips: u32 = 1,
    samples: u32 = 1,
    usage: gpu.Texture_Usages = {.Render_Attachment},
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

cts_rp_view :: proc(
    texture: gpu.Texture,
    mip: u32 = 0,
    mip_count: u32 = 1,
    layer: u32 = 0,
    layer_count: u32 = 1,
) -> gpu.Texture_View {
    return gpu.texture_create_view(texture, {
        dimension         = layer_count == 1 ? .D2 : .D2_Array,
        base_mip_level    = mip,
        mip_level_count   = mip_count,
        base_array_layer  = layer,
        array_layer_count = layer_count,
    })
}

cts_rp_color :: proc(view: gpu.Texture_View) -> gpu.Render_Pass_Color_Attachment {
    return {view = view, ops = {load = .Clear, store = .Store}}
}

cts_rp_depth :: proc(view: gpu.Texture_View) -> gpu.Render_Pass_Depth_Stencil_Attachment {
    return {
        view        = view,
        depth_ops   = {load = .Clear, store = .Store},
        stencil_ops = {load = .Clear, store = .Store},
    }
}

@(test)
cts_render_pass_one_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color_texture, depth_texture: gpu.Texture
    color_view, depth_view: gpu.Texture_View
    defer gpu.texture_release(color_texture)
    defer gpu.texture_release(depth_texture)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)
    color_texture = cts_rp_texture(f.device, .RGBA8_Unorm)
    depth_texture = cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    color_view = cts_rp_view(color_texture)
    depth_view = cts_rp_view(depth_texture)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}
    errors := cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, false, "one color attachment")

    depth := cts_rp_depth(depth_view)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth})
    cts_expect_outcome(t, errors ? 1 : 0, false, "one depth/stencil attachment")
}

@(test)
cts_render_pass_empty_attachments :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color_texture := cts_rp_texture(f.device, .RGBA8_Unorm)
    depth_texture := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(color_texture)
    defer gpu.texture_release(depth_texture)
    color_view := cts_rp_view(color_texture)
    depth_view := cts_rp_view(depth_texture)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)

    errors := cts_try_render_pass(t, f, {})
    cts_expect_outcome(t, errors ? 1 : 0, true, "no attachments")

    depth := cts_rp_depth(depth_view)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth})
    cts_expect_outcome(t, errors ? 1 : 0, false, "only a depth/stencil attachment")

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_view)}
    errors = cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, false, "only a color attachment")
}

@(test)
cts_render_pass_same_size :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color1 := cts_rp_texture(f.device, .RGBA8_Unorm, 1, 1)
    color2 := cts_rp_texture(f.device, .RGBA8_Unorm, 1, 1)
    color_big := cts_rp_texture(f.device, .RGBA8_Unorm, 2, 2)
    depth1 := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 1, 1)
    depth_big := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 2, 2)
    defer gpu.texture_release(color1)
    defer gpu.texture_release(color2)
    defer gpu.texture_release(color_big)
    defer gpu.texture_release(depth1)
    defer gpu.texture_release(depth_big)

    color1_view := cts_rp_view(color1)
    color2_view := cts_rp_view(color2)
    color_big_view := cts_rp_view(color_big)
    depth1_view := cts_rp_view(depth1)
    depth_big_view := cts_rp_view(depth_big)
    defer gpu.texture_view_release(color1_view)
    defer gpu.texture_view_release(color2_view)
    defer gpu.texture_view_release(color_big_view)
    defer gpu.texture_view_release(depth1_view)
    defer gpu.texture_view_release(depth_big_view)

    attachments := [2]gpu.Render_Pass_Color_Attachment{
        cts_rp_color(color1_view), cts_rp_color(color2_view),
    }
    depth := cts_rp_depth(depth1_view)
    errors := cts_try_render_pass(t, f, {
        color_attachments = attachments[:],
        depth_stencil_attachment = &depth,
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "attachments of one size")

    attachments = {cts_rp_color(color1_view), cts_rp_color(color_big_view)}
    errors = cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, true, "color attachments of different sizes")

    attachments = {cts_rp_color(color1_view), cts_rp_color(color2_view)}
    depth_big_desc := cts_rp_depth(depth_big_view)
    errors = cts_try_render_pass(t, f, {
        color_attachments = attachments[:],
        depth_stencil_attachment = &depth_big_desc,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "depth/stencil attachment of another size")
}

@(test)
cts_render_pass_color_depth_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)
    color_view := cts_rp_view(color)
    depth_view := cts_rp_view(depth)
    defer gpu.texture_view_release(color_view)
    defer gpu.texture_view_release(depth_view)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(depth_view)}
    errors := cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, true,
        "depth/stencil texture as a color attachment")

    depth_desc := cts_rp_depth(color_view)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_desc})
    cts_expect_outcome(t, errors ? 1 : 0, true,
        "color texture as the depth/stencil attachment")
}

@(test)
cts_render_pass_layer_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 10, 1)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 10, 1)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)

    color_five := cts_rp_view(color, 0, 1, 0, 5)
    color_first := cts_rp_view(color, 0, 1, 0, 1)
    depth_five := cts_rp_view(depth, 0, 1, 0, 5)
    depth_last := cts_rp_view(depth, 0, 1, 9, 1)
    defer gpu.texture_view_release(color_five)
    defer gpu.texture_view_release(color_first)
    defer gpu.texture_view_release(depth_five)
    defer gpu.texture_view_release(depth_last)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_five)}
    errors := cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, true, "color view of five layers")

    attachments = {cts_rp_color(color_first)}
    errors = cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, false, "color view of one layer")

    depth_five_desc := cts_rp_depth(depth_five)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_five_desc})
    cts_expect_outcome(t, errors ? 1 : 0, true, "depth view of five layers")

    depth_last_desc := cts_rp_depth(depth_last)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_last_desc})
    cts_expect_outcome(t, errors ? 1 : 0, false, "depth view of the last layer")
}

@(test)
cts_render_pass_mip_level_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color := cts_rp_texture(f.device, .RGBA8_Unorm, 32, 32, 1, 4)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 32, 32, 1, 4)
    defer gpu.texture_release(color)
    defer gpu.texture_release(depth)

    color_two := cts_rp_view(color, 0, 2, 0, 1)
    color_first := cts_rp_view(color, 0, 1, 0, 1)
    depth_two := cts_rp_view(depth, 0, 2, 0, 1)
    depth_last := cts_rp_view(depth, 3, 1, 0, 1)
    defer gpu.texture_view_release(color_two)
    defer gpu.texture_view_release(color_first)
    defer gpu.texture_view_release(depth_two)
    defer gpu.texture_view_release(depth_last)

    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_two)}
    errors := cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, true, "color view of two mip levels")

    attachments = {cts_rp_color(color_first)}
    errors = cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, false, "color view of one mip level")

    depth_two_desc := cts_rp_depth(depth_two)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_two_desc})
    cts_expect_outcome(t, errors ? 1 : 0, true, "depth view of two mip levels")

    depth_last_desc := cts_rp_depth(depth_last)
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_last_desc})
    cts_expect_outcome(t, errors ? 1 : 0, false, "depth view of the last mip level")
}

@(test)
cts_render_pass_sample_counts :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    single := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1)
    multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    defer gpu.texture_release(single)
    defer gpu.texture_release(multi)
    single_view := cts_rp_view(single)
    multi_view := cts_rp_view(multi)
    defer gpu.texture_view_release(single_view)
    defer gpu.texture_view_release(multi_view)

    attachment := cts_rp_color(multi_view)
    errors := cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "multisampled attachment without resolve")

    attachments := [2]gpu.Render_Pass_Color_Attachment{
        cts_rp_color(single_view), cts_rp_color(multi_view),
    }
    errors = cts_try_render_pass(t, f, {color_attachments = attachments[:]})
    cts_expect_outcome(t, errors ? 1 : 0, true, "attachments of different sample counts")

    attachment = cts_rp_color(single_view)
    attachment.resolve_target = single_view
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target on a single-sampled attachment")

    attachment = cts_rp_color(multi_view)
    attachment.resolve_target = multi_view
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "multisampled resolve target")

    attachment = cts_rp_color(multi_view)
    attachment.resolve_target = single_view
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "single-sampled resolve target")
}

@(test)
cts_render_pass_resolve_shape :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    target := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 2, 2, 1)
    defer gpu.texture_release(multi)
    defer gpu.texture_release(target)

    multi_view := cts_rp_view(multi)
    target_one := cts_rp_view(target, 0, 1, 0, 1)
    target_two_layers := cts_rp_view(target, 0, 1, 0, 2)
    target_two_mips := cts_rp_view(target, 0, 2, 0, 1)
    defer gpu.texture_view_release(multi_view)
    defer gpu.texture_view_release(target_one)
    defer gpu.texture_view_release(target_two_layers)
    defer gpu.texture_view_release(target_two_mips)

    attachment := cts_rp_color(multi_view)
    attachment.resolve_target = target_one
    errors := cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "resolve target of one mip and layer")

    attachment.resolve_target = target_two_layers
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target of two layers")

    attachment.resolve_target = target_two_mips
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target of two mip levels")
}

@(test)
cts_render_pass_query_sets :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    device, have_timestamp := cts_feature_device(f, .Timestamp_Query)
    if !have_timestamp {
        return
    }
    defer gpu.device_release(device)
    feature_fixture := CTS_Fixture {
        instance = f.instance,
        adapter  = f.adapter,
        device   = device,
    }

    color := cts_rp_texture(device, .RGBA8_Unorm)
    defer gpu.texture_release(color)
    view := cts_rp_view(color)
    defer gpu.texture_view_release(view)
    attachments := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(view)}

    occlusion := gpu.device_create_query_set(device, {type = .Occlusion, count = 2})
    timestamp := gpu.device_create_query_set(device, {type = .Timestamp, count = 2})
    defer gpu.query_set_release(occlusion)
    defer gpu.query_set_release(timestamp)

    writes := gpu.Render_Pass_Timestamp_Writes {
        query_set                     = timestamp,
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = 1,
    }
    errors := cts_try_render_pass(t, feature_fixture, {
        color_attachments = attachments[:],
        timestamp_writes  = &writes,
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "timestamp writes over both slots")

    writes.beginning_of_pass_write_index = 2
    writes.end_of_pass_write_index = gpu.QUERY_SET_INDEX_UNDEFINED
    errors = cts_try_render_pass(t, feature_fixture, {
        color_attachments = attachments[:],
        timestamp_writes  = &writes,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "timestamp slot past the set")

    writes.beginning_of_pass_write_index = 1
    writes.end_of_pass_write_index = 1
    errors = cts_try_render_pass(t, feature_fixture, {
        color_attachments = attachments[:],
        timestamp_writes  = &writes,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "timestamp slot written twice")

    writes.query_set = occlusion
    writes.beginning_of_pass_write_index = 0
    writes.end_of_pass_write_index = gpu.QUERY_SET_INDEX_UNDEFINED
    errors = cts_try_render_pass(t, feature_fixture, {
        color_attachments = attachments[:],
        timestamp_writes  = &writes,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "occlusion set used for timestamp writes")

    errors = cts_try_render_pass(t, feature_fixture, {
        color_attachments   = attachments[:],
        occlusion_query_set = timestamp,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "timestamp set used as occlusion set")

    errors = cts_try_render_pass(t, feature_fixture, {
        color_attachments   = attachments[:],
        occlusion_query_set = occlusion,
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "occlusion set used as occlusion set")
}

@(test)
cts_render_pass_depth_ops :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    combined := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    depth_only := cts_rp_texture(f.device, .Depth24Plus)
    defer gpu.texture_release(combined)
    defer gpu.texture_release(depth_only)
    combined_view := cts_rp_view(combined)
    depth_only_view := cts_rp_view(depth_only)
    defer gpu.texture_view_release(combined_view)
    defer gpu.texture_view_release(depth_only_view)

    check :: proc(
        t: ^testing.T,
        f: CTS_Fixture,
        attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        should_fail: bool,
        what: string,
    ) {
        local := attachment
        errors := cts_try_render_pass(t, f, {depth_stencil_attachment = &local})
        cts_expect_outcome(t, errors ? 1 : 0, should_fail, what)
    }

    check(t, f, {view = combined_view}, true,
        "writable depth/stencil attachment without ops")
    check(t, f, {view = combined_view, depth_read_only = true, stencil_read_only = true},
        false, "read-only depth/stencil attachment without ops")
    check(t, f, {
        view             = combined_view,
        depth_read_only  = true,
        stencil_read_only = true,
        depth_ops        = {load = .Load, store = .Store},
    }, true, "read-only attachment carrying depth ops")
    check(t, f, {
        view      = depth_only_view,
        depth_ops = {load = .Load, store = .Store},
    }, false, "depth-only attachment with only depth ops")
    check(t, f, {
        view        = combined_view,
        depth_ops   = {load = .Load},
        stencil_ops = {load = .Load, store = .Store},
    }, true, "writable depth aspect without a store op")
    check(t, f, {
        view            = combined_view,
        depth_read_only = true,
        depth_ops       = {store = .Store},
        stencil_ops     = {load = .Load, store = .Store},
    }, true, "read-only depth aspect carrying a store op")
    check(t, f, {
        view            = combined_view,
        depth_read_only = true,
        stencil_ops     = {load = .Load, store = .Store},
    }, false, "read-only depth with writable stencil ops")
}

@(test)
cts_render_pass_depth_clear_value :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(depth)
    view := cts_rp_view(depth)
    defer gpu.texture_view_release(view)

    values := [6]f32{-1, 0, 0.5, 1, 1.5, 42}
    expected := [6]bool{true, false, false, false, true, true}
    for value, i in values {
        attachment := gpu.Render_Pass_Depth_Stencil_Attachment {
            view        = view,
            depth_ops   = {load = .Clear, store = .Store, clear_value = value},
            stencil_ops = {load = .Clear, store = .Store},
        }
        errors := cts_try_render_pass(t, f, {depth_stencil_attachment = &attachment})
        cts_expect_outcome(t, errors ? 1 : 0, expected[i], "depth clear value row")
    }

    attachment := gpu.Render_Pass_Depth_Stencil_Attachment {
        view        = view,
        depth_ops   = {load = .Load, store = .Store, clear_value = 1.5},
        stencil_ops = {load = .Clear, store = .Store},
    }
    errors := cts_try_render_pass(t, f, {depth_stencil_attachment = &attachment})
    cts_expect_outcome(t, errors ? 1 : 0, false, "out-of-range clear value with a load op")
}

@(test)
cts_render_pass_resolve_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    other_format := cts_rp_texture(f.device, .BGRA8_Unorm, 16, 16, 1, 1, 1)
    bigger := cts_rp_texture(f.device, .RGBA8_Unorm, 32, 32, 1, 2, 1)
    no_usage := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1,
        {.Texture_Binding})
    defer gpu.texture_release(multi)
    defer gpu.texture_release(other_format)
    defer gpu.texture_release(bigger)
    defer gpu.texture_release(no_usage)

    multi_view := cts_rp_view(multi)
    other_view := cts_rp_view(other_format)
    bigger_mip0 := cts_rp_view(bigger, 0, 1, 0, 1)
    bigger_mip1 := cts_rp_view(bigger, 1, 1, 0, 1)
    no_usage_view := cts_rp_view(no_usage)
    defer gpu.texture_view_release(multi_view)
    defer gpu.texture_view_release(other_view)
    defer gpu.texture_view_release(bigger_mip0)
    defer gpu.texture_view_release(bigger_mip1)
    defer gpu.texture_view_release(no_usage_view)

    attachment := cts_rp_color(multi_view)
    attachment.resolve_target = other_view
    errors := cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target of another format")

    attachment.resolve_target = bigger_mip0
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target of another size")

    attachment.resolve_target = bigger_mip1
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "resolve target at the matching mip")

    attachment.resolve_target = no_usage_view
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "resolve target without the render usage")
}

@(test)
cts_render_pass_one_depth_stencil_attachment :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    depth := cts_rp_texture(f.device, .Depth24Plus_Stencil8)
    defer gpu.texture_release(depth)
    view := cts_rp_view(depth)
    defer gpu.texture_view_release(view)
    attachment := cts_rp_depth(view)
    errors := cts_try_render_pass(t, f, {depth_stencil_attachment = &attachment})
    cts_expect_outcome(t, errors ? 1 : 0, false, "one depth/stencil attachment")
}

@(test)
cts_render_pass_depth_sample_counts :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    color_single := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1)
    color_multi := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 4)
    ds_single := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 1, 1, 1)
    ds_multi := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 1, 1, 4)
    defer gpu.texture_release(color_single)
    defer gpu.texture_release(color_multi)
    defer gpu.texture_release(ds_single)
    defer gpu.texture_release(ds_multi)
    color_single_view := cts_rp_view(color_single)
    color_multi_view := cts_rp_view(color_multi)
    ds_single_view := cts_rp_view(ds_single)
    ds_multi_view := cts_rp_view(ds_multi)
    defer gpu.texture_view_release(color_single_view)
    defer gpu.texture_view_release(color_multi_view)
    defer gpu.texture_view_release(ds_single_view)
    defer gpu.texture_view_release(ds_multi_view)

    colors_multi := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_multi_view)}
    colors_single := [1]gpu.Render_Pass_Color_Attachment{cts_rp_color(color_single_view)}
    depth_single := cts_rp_depth(ds_single_view)
    depth_multi := cts_rp_depth(ds_multi_view)
    errors := cts_try_render_pass(t, f, {
        color_attachments = colors_multi[:], depth_stencil_attachment = &depth_single,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "multisample color, single-sample depth")
    errors = cts_try_render_pass(t, f, {
        color_attachments = colors_single[:], depth_stencil_attachment = &depth_multi,
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "single-sample color, multisample depth")
    errors = cts_try_render_pass(t, f, {
        color_attachments = colors_multi[:], depth_stencil_attachment = &depth_multi,
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "multisampled color and depth")
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth_multi})
    cts_expect_outcome(t, errors ? 1 : 0, false, "multisampled depth alone")
}

@(test)
cts_render_pass_color_transient_ops :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    transient := cts_rp_texture(f.device, .RGBA8_Unorm, 16, 16, 1, 1, 1,
        {.Render_Attachment, .Transient_Attachment})
    plain := cts_rp_texture(f.device, .RGBA8_Unorm)
    defer gpu.texture_release(transient)
    defer gpu.texture_release(plain)
    transient_view := cts_rp_view(transient)
    plain_view := cts_rp_view(plain)
    defer gpu.texture_view_release(transient_view)
    defer gpu.texture_view_release(plain_view)

    attachment := cts_rp_color(transient_view)
    attachment.ops.store = .Discard
    errors := cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "transient clear/discard")

    attachment = cts_rp_color(transient_view)
    attachment.ops.load = .Load
    attachment.ops.store = .Discard
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "transient load")

    attachment = cts_rp_color(transient_view)
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, true, "transient store")

    attachment = cts_rp_color(plain_view)
    attachment.ops.load = .Load
    errors = cts_try_render_pass(t, f, {
        color_attachments = []gpu.Render_Pass_Color_Attachment{attachment},
    })
    cts_expect_outcome(t, errors ? 1 : 0, false, "non-transient load and store")
}

@(test)
cts_render_pass_depth_transient_ops :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    transient := cts_rp_texture(f.device, .Depth24Plus_Stencil8, 16, 16, 1, 1, 1,
        {.Render_Attachment, .Transient_Attachment})
    defer gpu.texture_release(transient)
    view := cts_rp_view(transient)
    defer gpu.texture_view_release(view)

    depth := cts_rp_depth(view)
    depth.depth_ops.store = .Discard
    depth.stencil_ops.store = .Discard
    errors := cts_try_render_pass(t, f, {depth_stencil_attachment = &depth})
    cts_expect_outcome(t, errors ? 1 : 0, false, "transient depth clear/discard")

    depth = cts_rp_depth(view)
    depth.depth_ops.load = .Load
    depth.depth_ops.store = .Discard
    depth.stencil_ops.store = .Discard
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth})
    cts_expect_outcome(t, errors ? 1 : 0, true, "transient depth load")

    depth = cts_rp_depth(view)
    depth.depth_ops.store = .Discard
    depth.stencil_ops.store = .Store
    errors = cts_try_render_pass(t, f, {depth_stencil_attachment = &depth})
    cts_expect_outcome(t, errors ? 1 : 0, true, "transient stencil store")
}
