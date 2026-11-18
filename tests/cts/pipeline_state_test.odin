package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/render_pipeline/` state files: depth/stencil aspect rules, depth-bias
// topology, multisample count, alpha-to-coverage, float32 blending and
// unclipped depth. Rows that need an optional `depthWriteEnabled` cannot be
// expressed by this API's `bool` field and are not ported.

cts_pipeline_state_accepted :: proc(
    device: gpu.Device,
    targets: []gpu.Color_Target_State,
    primitive: ^gpu.Primitive_State,
    multisample: ^gpu.Multisample_State,
    depth_stencil: ^gpu.Depth_Stencil_State,
) -> bool {
    vertex_module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_VERT_BYTES)},
    })
    fragment_module := gpu.device_create_shader_module(device, {
        source = gpu.Shader_Source_SPIRV{code = cts_spirv_words(TRIANGLE_FRAG_BYTES)},
    })
    if vertex_module == {} || fragment_module == {} {
        return false
    }
    defer gpu.shader_module_release(vertex_module)
    defer gpu.shader_module_release(fragment_module)

    fragment := gpu.Fragment_State {
        module      = fragment_module,
        entry_point = "fs_main",
        targets     = targets,
    }
    descriptor := gpu.Render_Pipeline_Descriptor {
        vertex = {
            module      = vertex_module,
            entry_point = "vs_main",
        },
        primitive = primitive != nil ? primitive^ : gpu.Primitive_State {
            topology = .Triangle_List,
        },
        multisample = multisample != nil ? multisample^ : gpu.DEFAULT_MULTISAMPLE_STATE,
        depth_stencil = depth_stencil,
        fragment = &fragment,
    }
    pipeline := gpu.device_create_render_pipeline(device, descriptor)
    if pipeline == {} {
        return false
    }
    gpu.render_pipeline_release(pipeline)
    return true
}

cts_pipeline_state_row :: proc(
    t: ^testing.T,
    device: gpu.Device,
    targets: []gpu.Color_Target_State,
    primitive: ^gpu.Primitive_State,
    multisample: ^gpu.Multisample_State,
    depth_stencil: ^gpu.Depth_Stencil_State,
    should_fail: bool,
    what: string,
) {
    accepted := cts_pipeline_state_accepted(
        device, targets, primitive, multisample, depth_stencil)
    cts_expect_outcome(t, accepted ? 0 : 1, should_fail, what)
}

cts_plain_target :: proc(format: gpu.Texture_Format) -> [1]gpu.Color_Target_State {
    return {{format = format, write_mask = gpu.COLOR_WRITES_ALL}}
}

cts_depth_state :: proc(format: gpu.Texture_Format) -> gpu.Depth_Stencil_State {
    return {
        format              = format,
        depth_compare       = .Always,
        depth_write_enabled = false,
    }
}

@(test)
cts_pipeline_depth_stencil_format :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)

    red := cts_depth_state(.RGBA8_Unorm)
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &red, true,
        "depth/stencil state names a color format")
    depth_only := cts_depth_state(.Depth24Plus)
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &depth_only, false,
        "depth24plus state")
    combined := cts_depth_state(.Depth24Plus_Stencil8)
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &combined, false,
        "depth24plus-stencil8 state")
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, nil, false,
        "no depth/stencil state")
}

@(test)
cts_pipeline_depth_write_enabled_optional :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    targets := cts_plain_target(.RGBA8_Unorm)
    depth := cts_depth_state(.Depth24Plus)
    depth.depth_write_enabled = false
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &depth, false,
        "depthWriteEnabled false on a depth format")
    depth.depth_write_enabled = true
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &depth, false,
        "depthWriteEnabled true on a depth format")
    stencil := cts_depth_state(.Stencil8)
    stencil.depth_write_enabled = true
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &stencil, true,
        "depthWriteEnabled true on a format without a depth aspect")
}

@(test)
cts_pipeline_depth_stencil_aspects :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)

    stencil_only := cts_depth_state(.Stencil8)
    stencil_only.depth_compare = .Less
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &stencil_only, true,
        "depth test on a stencil-only format")

    stencil_only = cts_depth_state(.Stencil8)
    stencil_only.depth_compare = .Undefined
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &stencil_only, false,
        "absent depth test on a stencil-only format")

    stencil_only = cts_depth_state(.Stencil8)
    stencil_only.depth_write_enabled = true
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &stencil_only, true,
        "depth writes on a stencil-only format")

    depth_only := cts_depth_state(.Depth24Plus)
    depth_only.stencil.front.compare = .Less
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &depth_only, true,
        "stencil test on a depth-only format")

    depth_only = cts_depth_state(.Depth24Plus)
    depth_only.stencil.front.pass_op = .Zero
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &depth_only, true,
        "stencil write on a depth-only format")

    combined := cts_depth_state(.Depth24Plus_Stencil8)
    combined.depth_compare = .Less
    combined.stencil.front.compare = .Less
    combined.stencil.back.fail_op = .Zero
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &combined, false,
        "depth and stencil state on a combined format")
}

@(test)
cts_pipeline_depth_compare_optional :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)

    write := gpu.Depth_Stencil_State {
        format              = .Depth24Plus,
        depth_compare       = .Undefined,
        depth_write_enabled = true,
    }
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &write, true,
        "depth write without a depth compare")

    test := write
    test.depth_write_enabled = false
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &test, false,
        "depth test without a depth compare")

    combined := gpu.Depth_Stencil_State {
        format              = .Depth24Plus_Stencil8,
        depth_compare       = .Undefined,
        depth_write_enabled = false,
    }
    combined.stencil.front.depth_fail_op = .Zero
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &combined, true,
        "stencil depth-fail op without a depth compare")

    combined.depth_compare = .Always
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &combined, false,
        "stencil depth-fail op with a depth compare")

    keep := gpu.Depth_Stencil_State {
        format              = .Depth24Plus_Stencil8,
        depth_compare       = .Undefined,
        depth_write_enabled = false,
    }
    keep.stencil.front.compare = .Equal
    cts_pipeline_state_row(t, f.device, targets[:], nil, nil, &keep, false,
        "stencil test with keep ops and no depth compare")
}

@(test)
cts_pipeline_depth_bias_topology :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)
    depth := cts_depth_state(.Depth24Plus)
    depth.depth_write_enabled = true
    depth.depth_compare = .Less_Equal

    line := gpu.Primitive_State{topology = .Line_List}
    triangle := gpu.Primitive_State{topology = .Triangle_List}
    point := gpu.Primitive_State{topology = .Point_List}

    cts_pipeline_state_row(t, f.device, targets[:], &line, nil, &depth, false,
        "line pipeline without depth bias")

    biased := depth
    biased.bias.constant = -1
    biased.bias.slope_scale = 1
    biased.bias.clamp = 0.5
    cts_pipeline_state_row(t, f.device, targets[:], &triangle, nil, &biased, false,
        "depth bias on a triangle topology")
    cts_pipeline_state_row(t, f.device, targets[:], &line, nil, &biased, true,
        "depth bias on a line topology")
    cts_pipeline_state_row(t, f.device, targets[:], &point, nil, &biased, true,
        "depth bias on a point topology")
}

@(test)
cts_pipeline_multisample_count :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)
    counts := [6]u32{0, 1, 2, 4, 8, 1024}
    expected := [6]bool{false, false, true, false, true, true}
    for count, i in counts {
        multisample := gpu.Multisample_State {
            count = count,
            mask  = max(u32),
        }
        cts_pipeline_state_row(t, f.device, targets[:], nil, &multisample, nil,
            expected[i], "pipeline sample count row")
    }
}

@(test)
cts_pipeline_alpha_to_coverage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)
    multi := gpu.Multisample_State {
        count                     = 4,
        mask                      = max(u32),
        alpha_to_coverage_enabled = true,
    }
    cts_pipeline_state_row(t, f.device, targets[:], nil, &multi, nil, false,
        "alpha-to-coverage at four samples")

    single := multi
    single.count = 1
    cts_pipeline_state_row(t, f.device, targets[:], nil, &single, nil, true,
        "alpha-to-coverage at one sample")

    no_alpha := cts_plain_target(.R8_Unorm)
    cts_pipeline_state_row(t, f.device, no_alpha[:], nil, &multi, nil, true,
        "alpha-to-coverage into a format without alpha")

    cts_pipeline_state_row(t, f.device, targets[:], nil, &multi, nil, false,
        "alpha-to-coverage into an alpha format")

    depth := cts_depth_state(.Depth32_Float)
    cts_pipeline_state_row(t, f.device, nil, nil, &multi, &depth, true,
        "alpha-to-coverage without a first color target")

    off := multi
    off.alpha_to_coverage_enabled = false
    cts_pipeline_state_row(t, f.device, targets[:], nil, &off, nil, false,
        "four samples without alpha-to-coverage")
}

@(test)
cts_pipeline_float32_blendable :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    formats := [3]gpu.Texture_Format{.R32_Float, .RG32_Float, .RGBA32_Float}
    blend := gpu.BLEND_STATE_NORMAL
    for format in formats {
        blended := [1]gpu.Color_Target_State {
            {format = format, write_mask = gpu.COLOR_WRITES_ALL, blend = &blend},
        }
        cts_pipeline_state_row(t, f.device, blended[:], nil, nil, nil, true,
            "blending a float32 target without the feature")

        plain := cts_plain_target(format)
        cts_pipeline_state_row(t, f.device, plain[:], nil, nil, nil, false,
            "a float32 target with no blending")
    }

    featured, have_feature := cts_feature_device(f, .Float32_Blendable)
    if !have_feature {
        return
    }
    defer gpu.device_release(featured)
    for format in formats {
        blended := [1]gpu.Color_Target_State {
            {format = format, write_mask = gpu.COLOR_WRITES_ALL, blend = &blend},
        }
        cts_pipeline_state_row(t, featured, blended[:], nil, nil, nil, false,
            "blending a float32 target with the feature")
    }
}

@(test)
cts_pipeline_unclipped_depth :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    targets := cts_plain_target(.RGBA8_Unorm)
    unclipped := gpu.Primitive_State {
        topology        = .Triangle_List,
        unclipped_depth = true,
    }
    cts_pipeline_state_row(t, f.device, targets[:], &unclipped, nil, nil, true,
        "unclipped depth without the feature")

    clipped := gpu.Primitive_State{topology = .Triangle_List}
    cts_pipeline_state_row(t, f.device, targets[:], &clipped, nil, nil, false,
        "clipped depth")
}
