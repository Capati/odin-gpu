/*
Example - Timestamp Query

Measures GPU frame time with timestamp queries: the render pass writes a
timestamp at its start and end, the encoder resolves the pair into a buffer, and
the CPU reads it back to display the elapsed GPU milliseconds.

This is the first example to use `Query_Set` at all. It covers the whole
lifecycle that no other example exercises:

- `device_create_query_set` for a timestamp set
- `Render_Pass_Timestamp_Writes` on the render pass descriptor
- `command_encoder_resolve_query_set` into a `Query_Resolve` buffer
- mapping that buffer back and scaling raw ticks by the queue's timestamp period

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/timestamp_query.c
- https://webgpu/webgpu-samples/tree/main/src/sample/timestampQuery
*/
package timestamp_query

// Core
import "core:fmt"
import "core:math"
import "core:time"

// Vendor
import mu "vendor:microui"

// Local packages
import "../../gpu"
import app "../framework"
import mur "../../utils/microui"

TITLE :: "Timestamp Query"

LABEL_WIDTH     :: 110
SLIDER_WIDTH    :: 200
UI_WINDOW_WIDTH :: SLIDER_WIDTH + LABEL_WIDTH + 24

// Two slots: beginning and end of the render pass.
TIMESTAMP_COUNT :: 2

// Resolved results are 8 bytes each. The destination offset must be a multiple
// of 256, and the readback buffer needs `Map_Read`, so it is padded to that
// alignment rather than sized exactly.
QUERY_RESULT_SIZE :: 8
READBACK_SIZE :: 256

// A resolve may not run in the frame that wrote the timestamps if the GPU is a
// frame behind, so the value shown is the previous frame's. Averaging over a
// short window keeps the readout from flickering.
SAMPLE_WINDOW :: 20

// Time uniform shared with the fragment shader; must match `TimeParams`, which
// declares four scalars on purpose — a `float3` would be 16-byte aligned inside
// the constant buffer and pad the block to 32.
Time_Params :: struct #align(16) {
    time: f32,
    pad:  [3]f32,
}

State :: struct {
    query_set:      gpu.Query_Set,
    // GPU-to-GPU destination of the resolve.
    resolve_buffer: gpu.Buffer,
    // Staging copy that is mapped and read.
    readback_buffer: gpu.Buffer,

    timestamp_writes: gpu.Render_Pass_Timestamp_Writes,
    timestamp_period: f32,

    // Whether the device granted `Timestamp_Query`.
    supported:        bool,

    // Rolling average of the measured GPU pass time, in milliseconds.
    // `f64`: a timestamp delta of ~1e8 ns loses too many bits in an `f32`,
    // and summing 20 of them compounds the error.
    samples:          [SAMPLE_WINDOW]f64,
    sample_count:     int,
    sample_next:      int,
    last_gpu_ms:      f64,
    smoothed_gpu_ms:  f64,
    // Raw slots of the last read, shown in the UI so a zero or out-of-order
    // write is visible instead of being silently clamped into a bogus delta.
    last_begin_ticks: u64,
    last_end_ticks:   u64,
    read_count:       int,
    // Whether the last read produced a plausible pass duration. False means a
    // slot was zero or the pair was out of order; the UI says so instead of
    // showing a zero that looks like a real measurement.
    last_valid:       bool,

    // A deliberately shader-heavy fullscreen pass, so the timestamps have
    // measurable work to report.
    pipeline:         gpu.Render_Pipeline,
    bind_group:       gpu.Bind_Group,
    bind_group_layout: gpu.Bind_Group_Layout,
    pipeline_layout:  gpu.Pipeline_Layout,
    params_buffer:    gpu.Buffer,
    params:           Time_Params,
    total_time:       f32,

    mu_ctx:           mu.Context,
    mu_renderer:      mur.Renderer,

    // Cache the render pass descriptor
    rpass:            struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_query_resources :: proc(ctx: ^app.Application) {
    state.supported = gpu.adapter_has_feature(ctx.adapter, .Timestamp_Query)
    if !state.supported {
        return
    }

    state.query_set = gpu.device_create_query_set(ctx.device, {
        label = TITLE + " - Timestamp query set",
        type  = .Timestamp,
        count = TIMESTAMP_COUNT,
    })
    assert(state.query_set != {}, "failed to create the timestamp query set")

    // The resolve writes into a GPU buffer; it must be 256-byte aligned in size
    // so the readback range lines up.
    state.resolve_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Resolve buffer",
        usage = {.Query_Resolve, .Copy_Src},
        size  = READBACK_SIZE,
    })

    state.readback_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Readback buffer",
        usage = {.Map_Read, .Copy_Dst},
        size  = READBACK_SIZE,
    })

    // Timestamps are raw ticks unless the instance enables
    // `Automatic_Timestamp_Normalization`; this app does not, so convert to
    // nanoseconds by the period the queue reports.
    state.timestamp_period = gpu.queue_get_timestamp_period(ctx.queue)

    state.timestamp_writes = {
        query_set                     = state.query_set,
        beginning_of_pass_write_index = 0,
        end_of_pass_write_index       = 1,
    }
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "timestamp_query"

    vert_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader)

    frag_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader)

    state.params_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Time params",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(Time_Params)),
    })

    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Fragment},
                type       = gpu.Buffer_Binding_Layout{
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Time_Params)),
                },
            },
        },
    })

    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label   = TITLE + " - Bind group",
        layout  = state.bind_group_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.params_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })

    state.pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })

    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render pipeline",
        layout = state.pipeline_layout,
        vertex = {
            module      = vert_shader,
            entry_point = "vs_main",
        },
        fragment = &gpu.Fragment_State{
            module      = frag_shader,
            entry_point = "fs_main",
            targets     = {
                {
                    format     = ctx.render_format,
                    blend      = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .None,
        },
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, {0.02, 0.02, 0.05, 1.0}},
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    init_query_resources(ctx)
    init_pipeline(ctx)

    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device                     = ctx.device,
        target_format              = ctx.render_format,
        depth_stencil_format       = {},
        pipeline_multisample_state = {count = 1, mask = max(u32)},
    })
    mur.resize(&state.mu_renderer, ctx.width, ctx.height)

    return true
}

// Map the readback buffer and fold the newest measurement into the average.
read_timestamps :: proc() {
    if !state.supported {
        return
    }

    ptr := gpu.buffer_map_sync(state.readback_buffer, .Read, 0, READBACK_SIZE)
    if ptr == nil {
        return
    }

    // Copy the slots out *before* unmapping. On web `map_sync` returns a pointer
    // to a heap copy that `buffer_unmap` frees, so reading through the returned
    // pointer afterwards is a use-after-free; native keeps the mapping alive, so
    // only the browser showed it.
    results: [TIMESTAMP_COUNT]u64
    src := ([^]u64)(ptr)
    for index in 0 ..< TIMESTAMP_COUNT {
        results[index] = src[index]
    }
    gpu.buffer_unmap(state.readback_buffer)

    begin, end := results[0], results[1]
    state.last_begin_ticks = begin
    state.last_end_ticks = end
    state.read_count += 1

    // WebGPU leaves the timestamp origin implementation-defined and does not
    // promise the two slots come back in order, so compare before subtracting.
    // Subtracting unsigned wraps a small negative into ~2^64, which is how this
    // reported 1.8e12 ms instead of a frame time. `webgpu-samples` checks the
    // same way.
    if end <= begin {
        state.last_valid = false
        return
    }
    delta_ticks := end - begin

    // A single pass cannot plausibly take a second; a larger delta means a slot
    // was not written (the browser leaves it zero) rather than real work.
    if delta_ticks > u64(1_000_000_000) {
        state.last_valid = false
        return
    }

    state.last_valid = true
    state.last_gpu_ms = f64(delta_ticks) * f64(state.timestamp_period) / 1_000_000.0

    state.samples[state.sample_next] = state.last_gpu_ms
    state.sample_next = (state.sample_next + 1) % SAMPLE_WINDOW
    if state.sample_count < SAMPLE_WINDOW {
        state.sample_count += 1
    }

    total: f64
    for i in 0 ..< state.sample_count {
        total += state.samples[i]
    }
    state.smoothed_gpu_ms = total / f64(state.sample_count)
}

update_ui :: proc(ctx: ^app.Application, dt: f32) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        if state.supported {
            buf: [64]u8
            mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
            if state.last_valid {
                mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%.3f ms", state.smoothed_gpu_ms))
            } else {
                mu.label(&state.mu_ctx, "no data")
            }
            mu.label(&state.mu_ctx, "GPU pass (avg)")

            mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
            if state.last_valid {
                mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%.3f ms", state.last_gpu_ms))
            } else {
                mu.label(&state.mu_ctx, "no data")
            }
            mu.label(&state.mu_ctx, "GPU pass (last)")

            mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
            mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%.4f ns", state.timestamp_period))
            mu.label(&state.mu_ctx, "Tick period")

            // Raw slots in hex: a 20-digit decimal does not fit the label buffer,
            // and hex makes it obvious whether a slot is zero, truncated, or on a
            // different time base than the other. The origin is
            // implementation-defined, so absolute values are not durations.
            mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
            mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%x", state.last_begin_ticks))
            mu.label(&state.mu_ctx, "Begin ticks")

            mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
            mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%x", state.last_end_ticks))
            mu.label(&state.mu_ctx, "End ticks")
        } else {
            mu.layout_row(&state.mu_ctx, {-1}, 0)
            mu.label(&state.mu_ctx, "Timestamp_Query is not supported")
        }

        // CPU frame time, for comparison against the GPU pass time.
        mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
        buf: [64]u8
        mu.label(&state.mu_ctx, fmt.bprintf(buf[:], "%.3f ms", dt * 1000.0))
        mu.label(&state.mu_ctx, "CPU frame")
    }
    mu.end(&state.mu_ctx)
}

update_params :: proc(ctx: ^app.Application, dt: f32) {
    state.total_time += dt
    state.params.time = state.total_time

    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.params_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.params),
    )
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    // Read the previous frame's results before recording this one.
    read_timestamps()

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    update_params(ctx, dt)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    // Timestamps are written only when the device granted the feature.
    if state.supported {
        state.rpass.descriptor.timestamp_writes = &state.timestamp_writes
    }

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    // The measured work: a 64-iteration fractal per pixel.
    gpu.render_pass_set_pipeline(rpass, state.pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, state.bind_group)
    gpu.render_pass_draw(rpass, 3, 1, 0, 0)

    // Settings UI overlay on top.
    mur.render(&state.mu_renderer, &state.mu_ctx, rpass)

    gpu.render_pass_end(rpass)

    if state.supported {
        // Resolve the pair into the GPU buffer, then copy it to the mapped one.
        gpu.command_encoder_resolve_query_set(
            encoder, state.query_set, 0, TIMESTAMP_COUNT, state.resolve_buffer, 0)
        gpu.command_encoder_copy_buffer_to_buffer(
            encoder,
            state.resolve_buffer, 0,
            state.readback_buffer, 0,
            u64(TIMESTAMP_COUNT * QUERY_RESULT_SIZE),
        )
    }

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    update_ui(ctx, dt)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    mur.resize(&state.mu_renderer, width, height)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.mu_handle_events(&state.mu_ctx, event)
    #partial switch ev in event {
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
    gpu.render_pipeline_release(state.pipeline)
    gpu.pipeline_layout_release(state.pipeline_layout)
    gpu.bind_group_release(state.bind_group)
    gpu.bind_group_layout_release(state.bind_group_layout)
    gpu.buffer_release(state.params_buffer)
    if state.supported {
        gpu.buffer_release(state.readback_buffer)
        gpu.buffer_release(state.resolve_buffer)
        gpu.query_set_release(state.query_set)
    }
}

main :: proc() {
    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title             = TITLE,
        required_features = []gpu.Feature_Name{.Timestamp_Query},
        init_cb           = init,
        iterate_cb        = iterate,
        quit_cb           = quit,
        event_cb          = event,
    })
}
