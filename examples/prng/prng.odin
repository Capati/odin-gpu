/*
Example - Pseudorandom Number Generation

An example demonstrating pseudorandom number generation on the GPU. A
32-bit PCG hash is used which is fast enough to be useful for real-time,
while also being high-quality enough for almost any graphics use-case.

A pseudorandom number generator (PRNG), also known as a deterministic random
bit generator (DRBG), is an algorithm for generating a sequence of numbers
whose properties approximate the properties of sequences of random numbers.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/prng.c
- https://en.wikipedia.org/wiki/Pseudorandom_number_generator
- https://github.com/wwwtyro/webgpu-prng-example
- https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
*/
package prng

// Core
import "core:log"
import "core:math"
import "core:math/rand"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Pseudorandom Number Generation"

Vertex :: struct {
    position: [2]f32,
}

UBO :: struct #align(16) {
    offset: u32,
    _pad:   [3]u32,
}

State :: struct {
    vertices: gpu.Buffer,
    uniform_buffer: gpu.Buffer,
    uniform_bind_group_layout: gpu.Bind_Group_Layout,
    uniform_bind_group: gpu.Bind_Group,
    pipeline: gpu.Render_Pipeline,
    ubo: UBO,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

@(rodata)
VERTICES := []Vertex{
    {{-1.0, -1.0}},
    {{ 1.0, -1.0}},
    {{ 1.0,  1.0}},
    {{-1.0, -1.0}},
    {{ 1.0,  1.0}},
    {{-1.0,  1.0}},
}

init_vertex_buffer :: proc(ctx: ^app.Application) {
    state.vertices = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Quad - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, VERTICES)
}

// Upload the uniform buffer to the GPU
update_uniform_buffer :: proc(ctx: ^app.Application) {
    state.ubo.offset = u32(math.round_f32(rand.float32() * 4294967295.0))

    gpu.queue_write_buffer(
        ctx.queue,
        state.uniform_buffer,
        0,
        gpu.to_bytes(state.ubo),
    )
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(UBO)),
    })

    update_uniform_buffer(ctx)
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    // Bind group layout
    state.uniform_bind_group_layout = gpu.device_create_bind_group_layout(ctx.device,{
        label = TITLE + " - Bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Fragment},
                type       = gpu.Buffer_Binding_Layout{
                    type              = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size  = u64(size_of(UBO)),
                },
            },
        },
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    if state.uniform_bind_group != {} {
        gpu.bind_group_release(state.uniform_bind_group)
    }

    state.uniform_bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Bind group",
        layout = state.uniform_bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })
}

init_pipelines :: proc(ctx: ^app.Application) {
    // Cleanup existing pipeline
    if state.pipeline != {} {
        gpu.render_pipeline_release(state.pipeline)
    }

    SHADER_NAME :: "prng"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.uniform_bind_group_layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)

    // Create pipeline
    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = TITLE + " - Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = u64(size_of(Vertex)),
                    step_mode    = .Vertex,
                    attributes   = {
                        {format = .Float32x2, offset = 0, shader_location = 0},
                    },
                },
            },
        },
        fragment = &{
            module = frag_shader_module,
            entry_point = "fs_main",
            targets = {
                {
                    format = ctx.render_format,
                    blend = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_List,
            front_face = .CCW,
            cull_mode = .Back,
        },
        multisample = gpu.DEFAULT_MULTISAMPLE_STATE,
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.125, 0.125, 0.250, 1.0},
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render Pass",
        color_attachments = state.rpass.colors[:],
    }

    init_vertex_buffer(ctx)
    init_uniform_buffer(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.uniform_bind_group)
    gpu.bind_group_layout_release(state.uniform_bind_group_layout)
    gpu.buffer_release(state.uniform_buffer)
    gpu.buffer_release(state.vertices)
}

update :: proc(ctx: ^app.Application, dt: f32) {
    update_uniform_buffer(ctx)
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip { return true }
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, state.pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, state.uniform_bind_group)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertices)
    gpu.render_pass_draw(rpass, u32(len(VERTICES)), 1, 0, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    #partial switch ev in event {
        case app.Resize_Event:
            resize(ctx, ev.width, ev.height)
    }
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = {.Level, .Terminal_Color},
        )
        defer log.destroy_console_logger(context.logger)

        when ODIN_OS != .JS {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)

            defer {
                if len(track.allocation_map) > 0 {
                    log.errorf("=== %v allocations not freed: ===", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        log.warnf("- %v bytes @ %v", entry.size, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }
    }

    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
