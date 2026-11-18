#+build !js
package vk_bench

// Core
import "base:runtime"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:sync"
import "core:thread"
import "core:time"

// Local
import gpu "../../gpu"

VERT_SPIRV_BYTES :: #load("../../examples/render_bundles/shaders/SPIRV/render_bundles.vert.spv")
FRAG_SPIRV_BYTES :: #load("../../examples/render_bundles/shaders/SPIRV/render_bundles.frag.spv")

// Minimal compute shader: `void main() {}` at local size 1, with group 0 binding 0 storage buffer.
COMPUTE_SPIRV :: []u32 {
    0x07230203, 0x00010000, 0x00000000, 0x00000005, 0x00000000,
    0x00020011, 1,
    0x0003000E, 0, 1,
    0x0005000F, 5, 3, 0x6E69616D, 0,
    0x00060010, 3, 17, 1, 1, 1,
    0x00020013, 1,
    0x00030021, 2, 1,
    0x00050036, 1, 3, 0, 2,
    0x000200F8, 4,
    0x000100FD,
    0x00010038,
}

TARGET_SIZE   :: 256
COLOR_FORMAT  :: gpu.Texture_Format.RGBA8_Unorm
DEPTH_FORMAT  :: gpu.Texture_Format.Depth24Plus
MESH_VARIANTS :: 5
IN_FLIGHT_MAX :: 2

Vertex :: struct {
    pos:    [3]f32,
    normal: [3]f32,
    uv:     [2]f32,
}

Frame_Uniforms :: struct #align(16) {
    view_projection: linalg.Matrix4x4f32,
}

Object_Uniforms :: struct #align(16) {
    model: linalg.Matrix4x4f32,
}

Bench_Config :: struct {
    bench:   string,
    count:   int,
    frames:  int,
    bundle:  bool,
    shared:  bool,
    passes:  int,
    threads: int,
    // Per-draw sub-operation for `--bench state`: which recording call to
    // repeat in isolation, so a change can be attributed to one setter.
    op:      string,
    // Allocation instrumentation: count Odin heap allocations per measured
    // frame and report the call sites that produce them.
    track_allocs: bool,
    alloc_top:    int,
    // Positive control for the allocation instrument; see `alloc_tracker.odin`.
    alloc_selftest: bool,
}

Bench_Context :: struct {
    instance:     gpu.Instance,
    adapter:      gpu.Adapter,
    device:       gpu.Device,
    queue:        gpu.Queue,
    adapter_info: gpu.Adapter_Info,
}

spirv_words :: proc(bytes: []u8) -> []u32 {
    words := make([]u32, len(bytes) / 4, context.temp_allocator)
    for i in 0 ..< len(words) {
        base := i * 4
        words[i] =
            u32(bytes[base]) |
            (u32(bytes[base + 1]) << 8) |
            (u32(bytes[base + 2]) << 16) |
            (u32(bytes[base + 3]) << 24)
    }
    return words
}

parse_args :: proc() -> Bench_Config {
    cfg := Bench_Config {
        bench   = "draw_overhead",
        count   = 5000,
        frames  = 400,
        bundle  = true,
        shared  = false,
        passes  = 8,
        threads = 4,
        op      = "bind_group",
        alloc_top = 12,
    }
    args := os.args[1:]
    i := 0
    for i + 1 < len(args) {
        key := args[i]
        val := args[i + 1]
        switch key {
        case "--bench":
            cfg.bench = val
            i += 2
        case "--count", "--asteroids", "--dispatches":
            if n, ok := strconv.parse_int(val); ok && n >= 0 {
                cfg.count = n
            }
            i += 2
        case "--frames":
            if n, ok := strconv.parse_int(val); ok && n >= 8 {
                cfg.frames = n
            }
            i += 2
        case "--bundle":
            cfg.bundle = (val == "1" || val == "true")
            i += 2
        case "--shared", "--shared-binds":
            cfg.shared = (val == "1" || val == "true")
            i += 2
        case "--passes":
            if n, ok := strconv.parse_int(val); ok && n >= 1 {
                cfg.passes = n
            }
            i += 2
        case "--threads":
            if n, ok := strconv.parse_int(val); ok && n >= 1 {
                cfg.threads = clamp(n, 1, 16)
            }
            i += 2
        case "--op":
            cfg.op = val
            i += 2
        case "--track-allocs":
            cfg.track_allocs = (val == "1" || val == "true")
            i += 2
        case "--alloc-top":
            if n, ok := strconv.parse_int(val); ok && n >= 0 {
                cfg.alloc_top = n
            }
            i += 2
        case "--alloc-selftest":
            cfg.alloc_selftest = (val == "1" || val == "true")
            i += 2
        case:
            i += 1
        }
    }
    return cfg
}

bench_error_cb :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    context = runtime.default_context()
    fmt.eprintfln("VK_BENCH VALIDATION ERROR [%v]: %s", type, message)
    os.exit(2)
}

init_bench_context :: proc() -> Bench_Context {
    ctx: Bench_Context
    ctx.instance = gpu.create_instance(context.allocator, {backends = {.Vulkan}})
    assert(ctx.instance != nil, "failed to create Vulkan instance")

    ctx.adapter = gpu.instance_create_adapter(ctx.instance, {
        power_preference = .High_Performance,
    })
    assert(ctx.adapter != {}, "failed to create Vulkan adapter")

    ctx.adapter_info = gpu.adapter_get_info(ctx.adapter)

    limits := gpu.adapter_get_limits(ctx.adapter)
    ctx.device = gpu.adapter_create_device(ctx.adapter, {
        required_limits = limits,
        uncaptured_error_callback_info = {callback = bench_error_cb},
    })
    assert(ctx.device != nil, "failed to create Vulkan device")

    ctx.queue = gpu.device_get_queue(ctx.device)
    assert(ctx.queue != {}, "failed to get default queue")
    return ctx
}

destroy_bench_context :: proc(ctx: ^Bench_Context) {
    _ = gpu.device_poll(ctx.device, true, nil)
    gpu.adapter_info_free_members(ctx.adapter_info)
    gpu.queue_release(ctx.queue)
    gpu.device_release(ctx.device)
    gpu.adapter_release(ctx.adapter)
    gpu.instance_release(ctx.instance)
}

report_samples :: proc(ctx: ^Bench_Context, tag_mode: string, count: int, samples: []f64) {
    info := ctx.adapter_info
    fmt.printfln(
        "MEASURE-GPU-ADAPTER %s %v %s",
        info.name if info.name != "" else "unknown",
        info.backend,
        info.driver if info.driver != "" else "unknown",
    )

    if len(samples) == 0 {
        fmt.printfln("MEASURE-GPU %s %d 0.0 0.0 0", tag_mode, count)
        return
    }

    sorted := make([]f64, len(samples))
    defer delete(sorted)
    copy(sorted, samples)
    slice.sort(sorted)

    median := sorted[len(sorted) / 2]
    p95 := sorted[min(len(sorted) - 1, int(f64(len(sorted)) * 0.95))]

    fmt.printfln(
        "MEASURE-GPU %s %d %.1f %.1f %d",
        tag_mode,
        count,
        median,
        p95,
        len(sorted),
    )

    quarter := len(samples) / 4
    if quarter == 0 {
        return
    }

    pct := proc(sorted: []f64, p: f64) -> f64 {
        return sorted[min(len(sorted) - 1, int(f64(len(sorted) - 1) * p))]
    }
    fmt.printfln(
        "MEASURE-GPU-DIST p5=%.1f p25=%.1f p50=%.1f p75=%.1f p95=%.1f max=%.1f",
        pct(sorted, 0.05),
        pct(sorted, 0.25),
        pct(sorted, 0.50),
        pct(sorted, 0.75),
        pct(sorted, 0.95),
        sorted[len(sorted) - 1],
    )

    block := make([]f64, quarter)
    defer delete(block)

    q_medians: [4]f64
    for q in 0 ..< 4 {
        copy(block, samples[q * quarter : q * quarter + quarter])
        slice.sort(block)
        q_medians[q] = block[quarter / 2]
    }

    tail_mean := (q_medians[2] + q_medians[3]) / 2.0
    drift := abs(q_medians[3] - q_medians[2]) / max(tail_mean, 1e-9)
    fmt.printfln(
        "MEASURE-GPU-QUARTERS %.1f %.1f %.1f %.1f %s",
        q_medians[0],
        q_medians[1],
        q_medians[2],
        q_medians[3],
        "settled" if drift <= 0.05 else "NOT-SETTLED",
    )
}

// -----------------------------------------------------------------------------
// Shared Scene Resources for Render Benchmarks
// -----------------------------------------------------------------------------

Scene_Resources :: struct {
    color_targets: [2]gpu.Texture,
    color_views:   [2]gpu.Texture_View,
    depth_tex:     gpu.Texture,
    depth_view:    gpu.Texture_View,

    sampled_tex:   gpu.Texture,
    sampled_view:  gpu.Texture_View,
    sampler:       gpu.Sampler,

    vertex_buffers: [MESH_VARIANTS]gpu.Buffer,
    index_buffers:  [MESH_VARIANTS]gpu.Buffer,

    group0_layout:   gpu.Bind_Group_Layout,
    group1_layout:   gpu.Bind_Group_Layout,
    dynamic_layout:  gpu.Bind_Group_Layout,
    pipeline_layout: gpu.Pipeline_Layout,
    dyn_pipe_layout: gpu.Pipeline_Layout,
    pipeline:        gpu.Render_Pipeline,
    dyn_pipeline:    gpu.Render_Pipeline,

    frame_ubo:        gpu.Buffer,
    frame_bind_group: gpu.Bind_Group,

    object_ubos:   []gpu.Buffer,
    object_groups: []gpu.Bind_Group,

    dynamic_ubo:   gpu.Buffer,
    dynamic_group: gpu.Bind_Group,
    dyn_stride:    u32,
}

init_scene_resources :: proc(ctx: ^Bench_Context, count: int) -> Scene_Resources {
    res: Scene_Resources
    obj_count := max(1, count + 1)

    for i in 0 ..< 2 {
        res.color_targets[i] = gpu.device_create_texture(ctx.device, {
            label           = "bench color target",
            size            = {TARGET_SIZE, TARGET_SIZE, 1},
            mip_level_count = 1,
            sample_count    = 1,
            dimension       = .D2,
            format          = COLOR_FORMAT,
            usage           = {.Render_Attachment, .Texture_Binding, .Copy_Src},
        })
        res.color_views[i] = gpu.texture_create_view(res.color_targets[i])
    }

    res.depth_tex = gpu.device_create_texture(ctx.device, {
        label           = "bench depth target",
        size            = {TARGET_SIZE, TARGET_SIZE, 1},
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = DEPTH_FORMAT,
        usage           = {.Render_Attachment},
    })
    res.depth_view = gpu.texture_create_view(res.depth_tex)

    tex_pixels: [16 * 16 * 4]u8
    for &b, idx in tex_pixels {
        b = u8(idx & 0xFF)
    }
    res.sampled_tex = gpu.device_create_texture(ctx.device, {
        label           = "bench sampled tex",
        size            = {16, 16, 1},
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = COLOR_FORMAT,
        usage           = {.Texture_Binding, .Copy_Dst},
    })
    gpu.queue_write_texture(
        ctx.queue,
        {texture = res.sampled_tex, aspect = .All},
        tex_pixels[:],
        {bytes_per_row = 16 * 4, rows_per_image = 16},
        {16, 16, 1},
    )
    res.sampled_view = gpu.texture_create_view(res.sampled_tex)
    res.sampler = gpu.device_create_sampler(ctx.device, {
        mag_filter       = .Linear,
        min_filter       = .Linear,
        mipmap_filter    = .Linear,
        address_mode_u   = .Repeat,
        address_mode_v   = .Repeat,
        anisotropy_clamp = 1,
    })

    verts := [3]Vertex {
        {pos = {-0.02, -0.02, 0.5}, normal = {0, 0, 1}, uv = {0, 0}},
        {pos = { 0.02, -0.02, 0.5}, normal = {0, 0, 1}, uv = {1, 0}},
        {pos = { 0.00,  0.02, 0.5}, normal = {0, 0, 1}, uv = {0.5, 1}},
    }
    indices := [4]u16{0, 1, 2, 0}

    for v in 0 ..< MESH_VARIANTS {
        res.vertex_buffers[v] = gpu.device_create_buffer_with_data(ctx.device, {
            label = "bench vb",
            usage = {.Vertex, .Copy_Dst},
        }, verts[:])
        res.index_buffers[v] = gpu.device_create_buffer_with_data(ctx.device, {
            label = "bench ib",
            usage = {.Index, .Copy_Dst},
        }, indices[:])
    }

    res.group0_layout = gpu.device_create_bind_group_layout(ctx.device, {
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout {
                    type             = .Uniform,
                    min_binding_size = size_of(Frame_Uniforms),
                },
            },
        },
    })

    res.group1_layout = gpu.device_create_bind_group_layout(ctx.device, {
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout {
                    type             = .Uniform,
                    min_binding_size = size_of(Object_Uniforms),
                },
            },
            {
                binding    = 1,
                visibility = {.Fragment},
                type       = gpu.Texture_Binding_Layout {
                    sample_type    = .Float,
                    view_dimension = .D2,
                },
            },
            {
                binding    = 2,
                visibility = {.Fragment},
                type       = gpu.Sampler_Binding_Layout{type = .Filtering},
            },
        },
    })

    res.dynamic_layout = gpu.device_create_bind_group_layout(ctx.device, {
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout {
                    type               = .Uniform,
                    has_dynamic_offset = true,
                    min_binding_size   = size_of(Object_Uniforms),
                },
            },
            {
                binding    = 1,
                visibility = {.Fragment},
                type       = gpu.Texture_Binding_Layout {
                    sample_type    = .Float,
                    view_dimension = .D2,
                },
            },
            {
                binding    = 2,
                visibility = {.Fragment},
                type       = gpu.Sampler_Binding_Layout{type = .Filtering},
            },
        },
    })

    res.pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        bind_group_layouts = {res.group0_layout, res.group1_layout},
    })
    res.dyn_pipe_layout = gpu.device_create_pipeline_layout(ctx.device, {
        bind_group_layouts = {res.group0_layout, res.dynamic_layout},
    })

    vert_mod := gpu.device_create_shader_module(ctx.device, {
        source = gpu.Shader_Source_SPIRV{code = spirv_words(VERT_SPIRV_BYTES)},
    })
    frag_mod := gpu.device_create_shader_module(ctx.device, {
        source = gpu.Shader_Source_SPIRV{code = spirv_words(FRAG_SPIRV_BYTES)},
    })
    defer gpu.shader_module_release(vert_mod)
    defer gpu.shader_module_release(frag_mod)

    ds_state := gpu.Depth_Stencil_State {
        format              = DEPTH_FORMAT,
        depth_write_enabled = true,
        depth_compare       = .Less,
        stencil             = {
            front = {compare = .Always, fail_op = .Keep, depth_fail_op = .Keep, pass_op = .Keep},
            back  = {compare = .Always, fail_op = .Keep, depth_fail_op = .Keep, pass_op = .Keep},
        },
    }
    vb_attrs := [3]gpu.Vertex_Attribute {
        {format = .Float32x3, offset = 0, shader_location = 0},
        {format = .Float32x3, offset = 12, shader_location = 1},
        {format = .Float32x2, offset = 24, shader_location = 2},
    }
    vb_layouts := [1]gpu.Vertex_Buffer_Layout {
        {
            array_stride = size_of(Vertex),
            step_mode    = .Vertex,
            attributes   = vb_attrs[:],
        },
    }
    color_targets := [1]gpu.Color_Target_State {
        {format = COLOR_FORMAT, write_mask = gpu.COLOR_WRITES_ALL},
    }
    frag_state := gpu.Fragment_State {
        module      = frag_mod,
        entry_point = "fs_main",
        targets     = color_targets[:],
    }

    pipe_desc := gpu.Render_Pipeline_Descriptor {
        layout = res.pipeline_layout,
        vertex = {
            module      = vert_mod,
            entry_point = "vs_main",
            buffers     = vb_layouts[:],
        },
        fragment = &frag_state,
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .None,
        },
        depth_stencil = &ds_state,
        multisample   = {count = 1, mask = max(u32)},
    }
    res.pipeline = gpu.device_create_render_pipeline(ctx.device, pipe_desc)

    pipe_desc.layout = res.dyn_pipe_layout
    res.dyn_pipeline = gpu.device_create_render_pipeline(ctx.device, pipe_desc)

    res.frame_ubo = gpu.device_create_buffer_with_data(ctx.device, {
        usage = {.Uniform, .Copy_Dst},
    }, Frame_Uniforms{view_projection = linalg.MATRIX4F32_IDENTITY})

    res.frame_bind_group = gpu.device_create_bind_group(ctx.device, {
        layout  = res.group0_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding {
                    buffer = res.frame_ubo,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })

    res.object_ubos = make([]gpu.Buffer, obj_count)
    res.object_groups = make([]gpu.Bind_Group, obj_count)
    ident := Object_Uniforms{model = linalg.MATRIX4F32_IDENTITY}
    for i in 0 ..< obj_count {
        res.object_ubos[i] = gpu.device_create_buffer_with_data(ctx.device, {
            usage = {.Uniform, .Copy_Dst},
        }, ident)
        res.object_groups[i] = gpu.device_create_bind_group(ctx.device, {
            layout  = res.group1_layout,
            entries = {
                {
                    binding  = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = res.object_ubos[i],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
                {binding = 1, resource = res.sampled_view},
                {binding = 2, resource = res.sampler},
            },
        })
    }

    limits := gpu.device_get_limits(ctx.device)
    res.dyn_stride = max(u32(size_of(Object_Uniforms)), limits.min_uniform_buffer_offset_alignment)
    dyn_total_size := u64(res.dyn_stride) * u64(obj_count)
    res.dynamic_ubo = gpu.device_create_buffer(ctx.device, {
        size  = dyn_total_size,
        usage = {.Uniform, .Copy_Dst},
    })
    res.dynamic_group = gpu.device_create_bind_group(ctx.device, {
        layout  = res.dynamic_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding {
                    buffer = res.dynamic_ubo,
                    offset = 0,
                    size   = size_of(Object_Uniforms),
                },
            },
            {binding = 1, resource = res.sampled_view},
            {binding = 2, resource = res.sampler},
        },
    })

    return res
}

destroy_scene_resources :: proc(ctx: ^Bench_Context, res: ^Scene_Resources) {
    _ = gpu.device_poll(ctx.device, true, nil)

    gpu.bind_group_release(res.dynamic_group)
    gpu.buffer_release(res.dynamic_ubo)

    for i in 0 ..< len(res.object_groups) {
        gpu.bind_group_release(res.object_groups[i])
        gpu.buffer_release(res.object_ubos[i])
    }
    delete(res.object_groups)
    delete(res.object_ubos)

    gpu.bind_group_release(res.frame_bind_group)
    gpu.buffer_release(res.frame_ubo)

    gpu.render_pipeline_release(res.dyn_pipeline)
    gpu.render_pipeline_release(res.pipeline)
    gpu.pipeline_layout_release(res.dyn_pipe_layout)
    gpu.pipeline_layout_release(res.pipeline_layout)
    gpu.bind_group_layout_release(res.dynamic_layout)
    gpu.bind_group_layout_release(res.group1_layout)
    gpu.bind_group_layout_release(res.group0_layout)

    for v in 0 ..< MESH_VARIANTS {
        gpu.buffer_release(res.index_buffers[v])
        gpu.buffer_release(res.vertex_buffers[v])
    }

    gpu.sampler_release(res.sampler)
    gpu.texture_view_release(res.sampled_view)
    gpu.texture_release(res.sampled_tex)

    gpu.texture_view_release(res.depth_view)
    gpu.texture_release(res.depth_tex)

    for i in 0 ..< 2 {
        gpu.texture_view_release(res.color_views[i])
        gpu.texture_release(res.color_targets[i])
    }
}

record_draws_pass :: proc(rpass: gpu.Render_Pass, res: ^Scene_Resources, count: int, shared: bool) {
    gpu.render_pass_set_pipeline(rpass, res.pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, res.frame_bind_group)

    gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
    gpu.render_pass_set_index_buffer(rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])
    gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)

    for i in 0 ..< count {
        if shared {
            gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])
            gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
            gpu.render_pass_set_index_buffer(rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
        } else {
            variant := i % MESH_VARIANTS
            gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[i + 1])
            gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[variant])
            gpu.render_pass_set_index_buffer(rpass, res.index_buffers[variant], .Uint16, 0, gpu.WHOLE_SIZE)
        }
        gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
    }
}

record_draws_bundle :: proc(enc: gpu.Render_Bundle_Encoder, res: ^Scene_Resources, count: int, shared: bool) {
    gpu.render_bundle_encoder_set_pipeline(enc, res.pipeline)
    gpu.render_bundle_encoder_set_bind_group(enc, 0, res.frame_bind_group)

    gpu.render_bundle_encoder_set_vertex_buffer(enc, 0, res.vertex_buffers[0], 0, gpu.WHOLE_SIZE)
    gpu.render_bundle_encoder_set_index_buffer(enc, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
    gpu.render_bundle_encoder_set_bind_group(enc, 1, res.object_groups[0])
    gpu.render_bundle_encoder_draw_indexed(enc, 3, 1, 0, 0, 0)

    for i in 0 ..< count {
        if shared {
            gpu.render_bundle_encoder_set_bind_group(enc, 1, res.object_groups[0])
            gpu.render_bundle_encoder_set_vertex_buffer(enc, 0, res.vertex_buffers[0], 0, gpu.WHOLE_SIZE)
            gpu.render_bundle_encoder_set_index_buffer(enc, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
        } else {
            variant := i % MESH_VARIANTS
            gpu.render_bundle_encoder_set_bind_group(enc, 1, res.object_groups[i + 1])
            gpu.render_bundle_encoder_set_vertex_buffer(enc, 0, res.vertex_buffers[variant], 0, gpu.WHOLE_SIZE)
            gpu.render_bundle_encoder_set_index_buffer(enc, res.index_buffers[variant], .Uint16, 0, gpu.WHOLE_SIZE)
        }
        gpu.render_bundle_encoder_draw_indexed(enc, 3, 1, 0, 0, 0)
    }
}

// -----------------------------------------------------------------------------
// Benchmark 1: Draw Overhead (Bundle & Manual, Unique & Shared Binds)
// -----------------------------------------------------------------------------

run_draw_overhead :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, cfg.count)
    defer destroy_scene_resources(ctx, &res)

    bundle: gpu.Render_Bundle
    if cfg.bundle {
        color_formats := [1]gpu.Texture_Format{COLOR_FORMAT}
        ds := gpu.Render_Bundle_Depth_Stencil{depth_stencil_format = DEPTH_FORMAT}
        b_enc := gpu.device_create_render_bundle_encoder(ctx.device, {
            color_formats = color_formats[:],
            depth_stencil = &ds,
            sample_count  = 1,
        })
        record_draws_bundle(b_enc, &res, cfg.count, cfg.shared)
        bundle = gpu.render_bundle_encoder_finish(b_enc)
        gpu.render_bundle_encoder_release(b_enc)
    }
    defer if bundle != {} {
        gpu.render_bundle_release(bundle)
    }

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index
    frame_uni := Frame_Uniforms{view_projection = linalg.MATRIX4F32_IDENTITY}

    colors := [1]gpu.Render_Pass_Color_Attachment {
        {
            view        = res.color_views[0],
            depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
            ops         = {.Clear, .Store, {0, 0, 0, 1}},
        },
    }
    ds_att := gpu.Render_Pass_Depth_Stencil_Attachment {
        view      = res.depth_view,
        depth_ops = {.Clear, .Store, 1.0},
    }
    pass_desc := gpu.Render_Pass_Descriptor {
        color_attachments        = colors[:],
        depth_stencil_attachment = &ds_att,
    }

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        gpu.queue_write_buffer_raw(ctx.queue, res.frame_ubo, 0, &frame_uni, size_of(Frame_Uniforms))

        encoder := gpu.device_create_command_encoder(ctx.device)
        rpass := gpu.command_encoder_begin_render_pass(encoder, pass_desc)

        t0 := time.tick_now()
        if cfg.bundle {
            gpu.render_pass_execute_bundles(rpass, {bundle})
        } else {
            record_draws_pass(rpass, &res, cfg.count, cfg.shared)
        }
        gpu.render_pass_end(rpass)
        cmdbuf := gpu.command_encoder_finish(encoder)
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, {cmdbuf})
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        gpu.command_buffer_release(cmdbuf)
        gpu.render_pass_release(rpass)
        gpu.command_encoder_release(encoder)

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    mode_name := "bundle" if cfg.bundle else "manual"
    report_samples(ctx, mode_name, cfg.count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 2: Dynamic Uniforms (Per-Draw WriteBuffer vs Dynamic Offset)
// -----------------------------------------------------------------------------

run_dynamic_uniforms :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, cfg.count)
    defer destroy_scene_resources(ctx, &res)

    obj_count := max(1, cfg.count)
    staging_blob := make([]u8, int(res.dyn_stride) * obj_count)
    defer delete(staging_blob)

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index
    ident := Object_Uniforms{model = linalg.MATRIX4F32_IDENTITY}

    colors := [1]gpu.Render_Pass_Color_Attachment {
        {
            view        = res.color_views[0],
            depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
            ops         = {.Clear, .Store, {0, 0, 0, 1}},
        },
    }
    ds_att := gpu.Render_Pass_Depth_Stencil_Attachment {
        view      = res.depth_view,
        depth_ops = {.Clear, .Store, 1.0},
    }
    pass_desc := gpu.Render_Pass_Descriptor {
        color_attachments        = colors[:],
        depth_stencil_attachment = &ds_att,
    }

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        t0 := time.tick_now()

        if cfg.shared {
            // Single bulk queue_write_buffer + dynamic offsets per draw
            gpu.queue_write_buffer_raw(
                ctx.queue,
                res.dynamic_ubo,
                0,
                raw_data(staging_blob),
                len(staging_blob),
            )
        } else {
            // N individual queue_write_buffer calls
            for i in 0 ..< cfg.count {
                gpu.queue_write_buffer_raw(
                    ctx.queue,
                    res.object_ubos[i],
                    0,
                    &ident,
                    size_of(Object_Uniforms),
                )
            }
        }

        encoder := gpu.device_create_command_encoder(ctx.device)
        rpass := gpu.command_encoder_begin_render_pass(encoder, pass_desc)

        if cfg.shared {
            gpu.render_pass_set_pipeline(rpass, res.dyn_pipeline)
            gpu.render_pass_set_bind_group(rpass, 0, res.frame_bind_group)
            gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
            gpu.render_pass_set_index_buffer(rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
            for i in 0 ..< cfg.count {
                dyn_off := [1]u32{u32(i) * res.dyn_stride}
                gpu.render_pass_set_bind_group(rpass, 1, res.dynamic_group, dyn_off[:])
                gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
            }
        } else {
            record_draws_pass(rpass, &res, cfg.count, false)
        }

        gpu.render_pass_end(rpass)
        cmdbuf := gpu.command_encoder_finish(encoder)
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, {cmdbuf})
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        gpu.command_buffer_release(cmdbuf)
        gpu.render_pass_release(rpass)
        gpu.command_encoder_release(encoder)

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    mode_name := "dyn_offset" if cfg.shared else "write_buffer"
    report_samples(ctx, mode_name, cfg.count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 3: Multi-Pass Barriers & Transitions
// -----------------------------------------------------------------------------

run_multipass :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, cfg.count)
    defer destroy_scene_resources(ctx, &res)

    // Two bind groups that sample color_views[0] and color_views[1] respectively,
    // forcing a Color_Target <-> Resource layout transition between each pass.
    pass_sample_groups: [2]gpu.Bind_Group
    for i in 0 ..< 2 {
        pass_sample_groups[i] = gpu.device_create_bind_group(ctx.device, {
            layout  = res.group1_layout,
            entries = {
                {
                    binding  = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = res.object_ubos[0],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
                {binding = 1, resource = res.color_views[i]},
                {binding = 2, resource = res.sampler},
            },
        })
    }
    defer for i in 0 ..< 2 {
        gpu.bind_group_release(pass_sample_groups[i])
    }

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        t0 := time.tick_now()
        encoder := gpu.device_create_command_encoder(ctx.device)

        for p in 0 ..< cfg.passes {
            dst_idx := p % 2
            src_idx := (p + 1) % 2

            colors := [1]gpu.Render_Pass_Color_Attachment {
                {
                    view        = res.color_views[dst_idx],
                    depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
                    ops         = {.Clear, .Store, {0, 0, 0, 1}},
                },
            }
            ds_att := gpu.Render_Pass_Depth_Stencil_Attachment {
                view      = res.depth_view,
                depth_ops = {.Clear, .Store, 1.0},
            }
            rpass := gpu.command_encoder_begin_render_pass(encoder, {
                color_attachments        = colors[:],
                depth_stencil_attachment = &ds_att,
            })

            gpu.render_pass_set_pipeline(rpass, res.pipeline)
            gpu.render_pass_set_bind_group(rpass, 0, res.frame_bind_group)
            gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
            gpu.render_pass_set_index_buffer(rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
            gpu.render_pass_set_bind_group(rpass, 1, pass_sample_groups[src_idx])
            gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)

            for d in 0 ..< cfg.count {
                variant := d % MESH_VARIANTS
                gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[d + 1])
                gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[variant])
                gpu.render_pass_set_index_buffer(rpass, res.index_buffers[variant], .Uint16, 0, gpu.WHOLE_SIZE)
                gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
            }

            gpu.render_pass_end(rpass)
            gpu.render_pass_release(rpass)
        }

        cmdbuf := gpu.command_encoder_finish(encoder)
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, {cmdbuf})
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        gpu.command_buffer_release(cmdbuf)
        gpu.command_encoder_release(encoder)

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    report_samples(ctx, "multipass", cfg.passes * cfg.count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 4: Compute Dispatch & Scope Folding
// -----------------------------------------------------------------------------

run_compute :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    bgl := gpu.device_create_bind_group_layout(ctx.device, {
        entries = {
            {
                binding    = 0,
                visibility = {.Compute},
                type       = gpu.Buffer_Binding_Layout {
                    type             = .Storage,
                    min_binding_size = 64,
                },
            },
        },
    })
    defer gpu.bind_group_layout_release(bgl)

    pl := gpu.device_create_pipeline_layout(ctx.device, {
        bind_group_layouts = {bgl},
    })
    defer gpu.pipeline_layout_release(pl)

    cs_mod := gpu.device_create_shader_module(ctx.device, {
        source = gpu.Shader_Source_SPIRV{code = COMPUTE_SPIRV},
    })
    defer gpu.shader_module_release(cs_mod)

    cp := gpu.device_create_compute_pipeline(ctx.device, {
        layout      = pl,
        module      = cs_mod,
        entry_point = "main",
    })
    defer gpu.compute_pipeline_release(cp)

    PING_PONG :: 4
    storage_bufs: [PING_PONG]gpu.Buffer
    storage_groups: [PING_PONG]gpu.Bind_Group
    init_data: [16]u32
    for i in 0 ..< PING_PONG {
        storage_bufs[i] = gpu.device_create_buffer_with_data(ctx.device, {
            usage = {.Storage, .Copy_Dst},
        }, init_data[:])
        storage_groups[i] = gpu.device_create_bind_group(ctx.device, {
            layout  = bgl,
            entries = {
                {
                    binding  = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = storage_bufs[i],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
            },
        })
    }
    defer for i in 0 ..< PING_PONG {
        gpu.bind_group_release(storage_groups[i])
        gpu.buffer_release(storage_bufs[i])
    }

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        t0 := time.tick_now()
        encoder := gpu.device_create_command_encoder(ctx.device)
        cpass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_set_pipeline(cpass, cp)

        for d in 0 ..< cfg.count {
            gpu.compute_pass_set_bind_group(cpass, 0, storage_groups[d % PING_PONG])
            gpu.compute_pass_dispatch_workgroups(cpass, 1, 1, 1)
        }

        gpu.compute_pass_end(cpass)
        cmdbuf := gpu.command_encoder_finish(encoder)
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, {cmdbuf})
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        gpu.command_buffer_release(cmdbuf)
        gpu.compute_pass_release(cpass)
        gpu.command_encoder_release(encoder)

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    report_samples(ctx, "compute", cfg.count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 5: Parallel Command Encoding
// -----------------------------------------------------------------------------

Parallel_Worker :: struct {
    ctx:         ^Bench_Context,
    res:         ^Scene_Resources,
    color_tex:   gpu.Texture,
    color_view:  gpu.Texture_View,
    depth_tex:   gpu.Texture,
    depth_view:  gpu.Texture_View,
    start_index: int,
    draw_count:  int,
    shared:      bool,
    start_bar:   ^sync.Barrier,
    done_bar:    ^sync.Barrier,
    stop:        bool,
    out_cmdbuf:  gpu.Command_Buffer,
}

parallel_worker_proc :: proc(w: ^Parallel_Worker) {
    context = runtime.default_context()
    // Function scope: a `context` assignment inside a block is reverted at the
    // block's end.
    context.allocator = alloc_tracker_enabled() ? alloc_tracker_allocator() : context.allocator

    colors := [1]gpu.Render_Pass_Color_Attachment {
        {
            view        = w.color_view,
            depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
            ops         = {.Clear, .Store, {0, 0, 0, 1}},
        },
    }
    ds_att := gpu.Render_Pass_Depth_Stencil_Attachment {
        view      = w.depth_view,
        depth_ops = {.Clear, .Store, 1.0},
    }
    pass_desc := gpu.Render_Pass_Descriptor {
        color_attachments        = colors[:],
        depth_stencil_attachment = &ds_att,
    }

    for {
        sync.barrier_wait(w.start_bar)
        if w.stop {
            return
        }

        encoder := gpu.device_create_command_encoder(w.ctx.device)
        rpass := gpu.command_encoder_begin_render_pass(encoder, pass_desc)

        gpu.render_pass_set_pipeline(rpass, w.res.pipeline)
        gpu.render_pass_set_bind_group(rpass, 0, w.res.frame_bind_group)

        for i in 0 ..< w.draw_count {
            if w.shared {
                gpu.render_pass_set_bind_group(rpass, 1, w.res.object_groups[0])
                gpu.render_pass_set_vertex_buffer(rpass, 0, w.res.vertex_buffers[0])
                gpu.render_pass_set_index_buffer(rpass, w.res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
            } else {
                idx := w.start_index + i
                variant := idx % MESH_VARIANTS
                gpu.render_pass_set_bind_group(rpass, 1, w.res.object_groups[idx + 1])
                gpu.render_pass_set_vertex_buffer(rpass, 0, w.res.vertex_buffers[variant])
                gpu.render_pass_set_index_buffer(rpass, w.res.index_buffers[variant], .Uint16, 0, gpu.WHOLE_SIZE)
            }
            gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
        }

        gpu.render_pass_end(rpass)
        w.out_cmdbuf = gpu.command_encoder_finish(encoder)

        gpu.render_pass_release(rpass)
        gpu.command_encoder_release(encoder)

        sync.barrier_wait(w.done_bar)
    }
}

run_parallel_encode :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, cfg.count)
    defer destroy_scene_resources(ctx, &res)

    t_count := clamp(cfg.threads, 1, 16)
    draws_per_thread := cfg.count / t_count

    start_bar, done_bar: sync.Barrier
    sync.barrier_init(&start_bar, t_count + 1)
    sync.barrier_init(&done_bar, t_count + 1)

    workers := make([]Parallel_Worker, t_count)
    threads := make([]^thread.Thread, t_count)
    cmdbufs := make([]gpu.Command_Buffer, t_count)
    defer {
        delete(cmdbufs)
        delete(threads)
        delete(workers)
    }

    for i in 0 ..< t_count {
        ctex := gpu.device_create_texture(ctx.device, {
            size            = {TARGET_SIZE, TARGET_SIZE, 1},
            mip_level_count = 1,
            sample_count    = 1,
            dimension       = .D2,
            format          = COLOR_FORMAT,
            usage           = {.Render_Attachment},
        })
        dtex := gpu.device_create_texture(ctx.device, {
            size            = {TARGET_SIZE, TARGET_SIZE, 1},
            mip_level_count = 1,
            sample_count    = 1,
            dimension       = .D2,
            format          = DEPTH_FORMAT,
            usage           = {.Render_Attachment},
        })
        workers[i] = Parallel_Worker {
            ctx         = ctx,
            res         = &res,
            color_tex   = ctex,
            color_view  = gpu.texture_create_view(ctex),
            depth_tex   = dtex,
            depth_view  = gpu.texture_create_view(dtex),
            start_index = i * draws_per_thread,
            draw_count  = draws_per_thread,
            shared      = cfg.shared,
            start_bar   = &start_bar,
            done_bar    = &done_bar,
        }
        threads[i] = thread.create_and_start_with_poly_data(&workers[i], parallel_worker_proc)
    }

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        t0 := time.tick_now()
        sync.barrier_wait(&start_bar)
        sync.barrier_wait(&done_bar)

        for i in 0 ..< t_count {
            cmdbufs[i] = workers[i].out_cmdbuf
        }
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, cmdbufs[:])
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        for i in 0 ..< t_count {
            gpu.command_buffer_release(cmdbufs[i])
        }

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    for i in 0 ..< t_count {
        workers[i].stop = true
    }
    sync.barrier_wait(&start_bar)
    for i in 0 ..< t_count {
        thread.join(threads[i])
        thread.destroy(threads[i])
        gpu.texture_view_release(workers[i].depth_view)
        gpu.texture_release(workers[i].depth_tex)
        gpu.texture_view_release(workers[i].color_view)
        gpu.texture_release(workers[i].color_tex)
    }

    report_samples(ctx, "parallel", draws_per_thread * t_count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 6: Isolated Per-Draw Sub-Operation
// -----------------------------------------------------------------------------

// Repeats exactly one recording call `count` times inside a single render pass,
// with the rest of the pipeline state bound once. A regression that scales with
// the draw count can then be attributed to one setter instead of the whole
// draw bundle.
run_state :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, cfg.count)
    defer destroy_scene_resources(ctx, &res)

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    in_flight: [IN_FLIGHT_MAX]gpu.Submission_Index

    colors := [1]gpu.Render_Pass_Color_Attachment {
        {
            view        = res.color_views[0],
            depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
            ops         = {.Clear, .Store, {0, 0, 0, 1}},
        },
    }
    ds_att := gpu.Render_Pass_Depth_Stencil_Attachment {
        view      = res.depth_view,
        depth_ops = {.Clear, .Store, 1.0},
    }
    pass_desc := gpu.Render_Pass_Descriptor {
        color_attachments        = colors[:],
        depth_stencil_attachment = &ds_att,
    }

    for frame in 0 ..< cfg.frames {
        slot := frame % IN_FLIGHT_MAX
        if in_flight[slot] != 0 {
            _ = gpu.device_poll(ctx.device, true, &in_flight[slot])
        }

        encoder := gpu.device_create_command_encoder(ctx.device)
        rpass := gpu.command_encoder_begin_render_pass(encoder, pass_desc)

        gpu.render_pass_set_pipeline(rpass, res.pipeline)
        gpu.render_pass_set_bind_group(rpass, 0, res.frame_bind_group)
        gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
        gpu.render_pass_set_index_buffer(rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
        gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])

        t0 := time.tick_now()
        switch cfg.op {
        case "bind_group":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])
            }
        case "vertex":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
            }
        case "index":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_set_index_buffer(
                    rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
            }
        case "draw":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
            }
        case "bind_draw":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])
                gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
            }
        case "all":
            for _ in 0 ..< cfg.count {
                gpu.render_pass_set_bind_group(rpass, 1, res.object_groups[0])
                gpu.render_pass_set_vertex_buffer(rpass, 0, res.vertex_buffers[0])
                gpu.render_pass_set_index_buffer(
                    rpass, res.index_buffers[0], .Uint16, 0, gpu.WHOLE_SIZE)
                gpu.render_pass_draw_indexed(rpass, 3, 1, 0, 0, 0)
            }
        case:
            panic("--op must be bind_group, vertex, index, draw, bind_draw or all")
        }
        gpu.render_pass_end(rpass)
        cmdbuf := gpu.command_encoder_finish(encoder)
        in_flight[slot] = gpu.queue_submit_for_index(ctx.queue, {cmdbuf})
        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0

        gpu.command_buffer_release(cmdbuf)
        gpu.render_pass_release(rpass)
        gpu.command_encoder_release(encoder)

        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    report_samples(ctx, cfg.op, cfg.count, samples[:])
}

// -----------------------------------------------------------------------------
// Benchmark 7: Per-call resource churn
//
// Nothing here is per-frame work in this benchmark's other suites — they create
// their resources once. This suite exists to measure what an application pays
// per call when it *does* recreate resources: bind groups, texture views, render
// bundles, texture uploads and readback mappings. Run it with `--track-allocs 1`
// to attribute the cost to call sites.
// -----------------------------------------------------------------------------

run_churn :: proc(ctx: ^Bench_Context, cfg: Bench_Config) {
    res := init_scene_resources(ctx, max(cfg.count, 2))
    defer destroy_scene_resources(ctx, &res)

    readback := gpu.device_create_buffer(ctx.device, {
        size  = 256,
        usage = {.Map_Read, .Copy_Dst},
    })
    defer gpu.buffer_release(readback)

    op_name := cfg.op
    pixel: [4 * 4 * 4]u8

    warmup := cfg.frames / 4
    samples := make([dynamic]f64, 0, cfg.frames - warmup)
    defer delete(samples)

    for frame in 0 ..< cfg.frames {
        t0 := time.tick_now()

        switch op_name {
        case "bind_group":
            for _ in 0 ..< cfg.count {
                group := gpu.device_create_bind_group(ctx.device, {
                    layout  = res.group1_layout,
                    entries = {
                        {
                            binding  = 0,
                            resource = gpu.Buffer_Binding {
                                buffer = res.object_ubos[0],
                                offset = 0,
                                size   = gpu.WHOLE_SIZE,
                            },
                        },
                        {binding = 1, resource = res.sampled_view},
                        {binding = 2, resource = res.sampler},
                    },
                })
                gpu.bind_group_release(group)
            }

        case "view":
            for _ in 0 ..< cfg.count {
                view := gpu.texture_create_view(res.sampled_tex)
                gpu.texture_view_release(view)
            }

        case "bundle":
            for _ in 0 ..< cfg.count {
                color_formats := [1]gpu.Texture_Format{COLOR_FORMAT}
                ds := gpu.Render_Bundle_Depth_Stencil{depth_stencil_format = DEPTH_FORMAT}
                enc := gpu.device_create_render_bundle_encoder(ctx.device, {
                    color_formats = color_formats[:],
                    depth_stencil = &ds,
                    sample_count  = 1,
                })
                record_draws_bundle(enc, &res, 4, true)
                bundle := gpu.render_bundle_encoder_finish(enc)
                gpu.render_bundle_release(bundle)
                gpu.render_bundle_encoder_release(enc)
            }

        case "texture_write":
            for _ in 0 ..< cfg.count {
                gpu.queue_write_texture(
                    ctx.queue,
                    {texture = res.sampled_tex, aspect = .All},
                    pixel[:],
                    {bytes_per_row = 4 * 4, rows_per_image = 4},
                    {4, 4, 1},
                )
            }
            // Pending writes are submissions: flush them so staging stays
            // bounded and the next frame starts from the same state.
            submission := gpu.queue_submit_for_index(ctx.queue, {})
            _ = gpu.device_poll(ctx.device, true, &submission)

        case "map_readback":
            for _ in 0 ..< cfg.count {
                future := gpu.buffer_map_async(readback, .Read, 0, 256, {})
                if future.id == 0 {
                    continue
                }
                info := gpu.Future_Wait_Info{future = future}
                _ = gpu.instance_wait_any(ctx.instance, []^gpu.Future_Wait_Info{&info})
                _ = gpu.buffer_get_const_mapped_range(readback, 0, 256)
                gpu.buffer_unmap(readback)
            }

        case:
            fmt.eprintfln("unknown churn op '%s'", op_name)
            os.exit(1)
        }

        elapsed_us := f64(time.duration_nanoseconds(time.tick_since(t0))) / 1000.0
        if frame >= warmup {
            alloc_tracker_begin_measure()
            append(&samples, elapsed_us)
        }
    }

    report_samples(ctx, fmt.tprintf("churn/%s", op_name), cfg.count, samples[:])
}

main :: proc() {
    cfg := parse_args()
    if cfg.track_allocs {
        alloc_tracker_install(context.allocator, cfg.alloc_selftest)
    }
    // Odin restores `context` at the end of the block it was assigned in, so an
    // assignment inside the `if` above would be undone before any callee runs.
    // Select at function scope.
    context.allocator = cfg.track_allocs ? alloc_tracker_allocator() : context.allocator
    ctx := init_bench_context()
    defer destroy_bench_context(&ctx)

    switch cfg.bench {
    case "draw_overhead":
        run_draw_overhead(&ctx, cfg)
    case "dynamic_uniforms":
        run_dynamic_uniforms(&ctx, cfg)
    case "multipass":
        run_multipass(&ctx, cfg)
    case "compute":
        run_compute(&ctx, cfg)
    case "parallel_encode":
        run_parallel_encode(&ctx, cfg)
    case "state":
        run_state(&ctx, cfg)
    case "churn":
        run_churn(&ctx, cfg)
    case:
        fmt.eprintfln("unknown benchmark '%s'", cfg.bench)
        os.exit(1)
    }

    if cfg.track_allocs {
        alloc_tracker_report(cfg.bench, cfg.frames - cfg.frames / 4, cfg.alloc_top)
    }
}
