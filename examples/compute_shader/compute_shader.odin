/*
Example - Compute Shader

A compute shader integrates a particle field in an in-place storage buffer, and
a render pass then draws that buffer as instanced quads in the same frame. This
is the first example to use compute at all: it exercises compute pipeline
creation, a compute pass, read/write storage bindings, and the compute-to-vertex
barrier the tracker emits between the two passes.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/compute_shader.c
- https://webgpufundamentals.org/webgpu/lessons/webgpu-compute-shaders.html
*/
package compute_shader

// Core
import "core:math"
import "core:time"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Compute Shader"
CLIENT_WIDTH :: 640
CLIENT_HEIGHT :: 480

// One workgroup of 64 threads per dispatch, matching `numthreads(64, 1, 1)`.
WORKGROUP_SIZE :: 64
DISPATCH_COUNT :: 32
PARTICLE_COUNT :: WORKGROUP_SIZE * DISPATCH_COUNT

// Quad extent in pixels; the vertex shader converts it to NDC.
PARTICLE_SIZE :: 6.0

// Values shared with both shaders; the layout must match `SimParams` in
// `compute_shader.comp.slang` / `compute_shader.vert.slang` exactly.
Sim_Params :: struct #align(16) {
    resolution: [2]f32,
    time:       f32,
    delta:      f32,
    count:      u32,
    size:       f32,
    pad:        [2]f32,
}

Particle :: struct {
    pos: [2]f32,
    vel: [2]f32,
}

State :: struct {
    particles_buffer:        gpu.Buffer,
    params_buffer:           gpu.Buffer,
    compute_bind_group:      gpu.Bind_Group,
    render_bind_group:       gpu.Bind_Group,
    compute_layout:          gpu.Bind_Group_Layout,
    render_layout:           gpu.Bind_Group_Layout,
    compute_pipeline_layout: gpu.Pipeline_Layout,
    render_pipeline_layout:  gpu.Pipeline_Layout,
    compute_pipeline:        gpu.Compute_Pipeline,
    render_pipeline:         gpu.Render_Pipeline,
    particle_count:          u32,
    params:                  Sim_Params,
    start:                   time.Tick,

    // Cache the render pass descriptor
    rpass:                   struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_particles :: proc(ctx: ^app.Application) {
    particles: [PARTICLE_COUNT]Particle

    // Deterministic scatter with varied speeds so the swirl has something to act
    // on. Golden-ratio stepping keeps the initial field from forming bands.
    for &particle, index in particles {
        angle := f32(index) * 2.39996323
        radius := math.sqrt(f32(index) / f32(PARTICLE_COUNT))
        particle.pos = {
            0.5 + 0.5 * radius * math.cos(angle),
            0.5 + 0.5 * radius * math.sin(angle),
        }
        particle.vel = {
            0.25 * math.sin(angle * 3.0),
            0.25 * math.cos(angle * 3.0),
        }
    }

    state.particles_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Particles storage buffer",
        usage = {.Storage, .Copy_Dst},
    }, particles[:])
}

init_params_buffer :: proc(ctx: ^app.Application) {
    state.params_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Simulation params",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(Sim_Params)),
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    // Two layouts, because a read/write storage buffer may not be visible from
    // the vertex stage without the `Vertex_Writable_Storage` feature. The
    // compute shader needs read/write; the render pipeline only reads, so it
    // gets a `.Read_Only_Storage` view of the same buffer.
    state.compute_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Compute bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Compute},
                type       = gpu.Buffer_Binding_Layout{
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Sim_Params)),
                },
            },
            {
                binding    = 1,
                visibility = {.Compute},
                type       = gpu.Buffer_Binding_Layout{
                    type = .Storage,
                },
            },
        },
    })

    state.render_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Render bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout{
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Sim_Params)),
                },
            },
            {
                binding    = 1,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout{
                    type = .Read_Only_Storage,
                },
            },
        },
    })

    state.compute_bind_group = gpu.device_create_bind_group(ctx.device, {
        label   = TITLE + " - Compute bind group",
        layout  = state.compute_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.params_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
            {
                binding  = 1,
                resource = gpu.Buffer_Binding{
                    buffer = state.particles_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })

    state.render_bind_group = gpu.device_create_bind_group(ctx.device, {
        label   = TITLE + " - Render bind group",
        layout  = state.render_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.params_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
            {
                binding  = 1,
                resource = gpu.Buffer_Binding{
                    buffer = state.particles_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })
}

init_pipelines :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "compute_shader"

    comp_shader := app.load_shader_entry(
        ctx.device, #directory, SHADER_NAME + ".comp", "cs_main", .Compute)
    defer gpu.shader_module_release(comp_shader)

    vert_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader)

    frag_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader)

    state.compute_pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Compute pipeline layout",
        bind_group_layouts = {state.compute_layout},
    })

    state.render_pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Render pipeline layout",
        bind_group_layouts = {state.render_layout},
    })

    state.compute_pipeline = gpu.device_create_compute_pipeline(ctx.device, {
        label       = TITLE + " - Compute pipeline",
        layout      = state.compute_pipeline_layout,
        module      = comp_shader,
        entry_point = "cs_main",
    })

    state.render_pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render pipeline",
        layout = state.render_pipeline_layout,
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
    state.particle_count = PARTICLE_COUNT
    state.params.count = state.particle_count
    state.params.size = PARTICLE_SIZE

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, {0.02, 0.02, 0.05, 1.0}},
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    init_particles(ctx)
    init_params_buffer(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)

    state.start = time.tick_now()

    return true
}

update_params :: proc(ctx: ^app.Application, dt: f32) {
    state.params.resolution = {f32(ctx.width), f32(ctx.height)}
    state.params.time = f32(time.duration_seconds(time.tick_since(state.start)))
    // Clamp so a long stall does not launch every particle out of the field.
    state.params.delta = math.clamp(dt, 0.0, 1.0 / 15.0)

    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.params_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.params),
    )
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update_params(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    // Simulate first. The tracker emits the compute-to-vertex barrier at the
    // start of the render pass below, because the storage buffer is read as a
    // vertex-stage resource there.
    cpass := gpu.command_encoder_begin_compute_pass(encoder, {
        label = TITLE + " - Compute pass",
    })
    defer gpu.compute_pass_release(cpass)

    gpu.compute_pass_set_pipeline(cpass, state.compute_pipeline)
    gpu.compute_pass_set_bind_group(cpass, 0, state.compute_bind_group)
    gpu.compute_pass_dispatch_workgroups(cpass, DISPATCH_COUNT, 1, 1)
    gpu.compute_pass_end(cpass)

    state.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, state.render_pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, state.render_bind_group)
    // No vertex buffer: positions come from the storage buffer.
    gpu.render_pass_draw(rpass, 6, state.particle_count, 0, 0)
    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
}

quit :: proc(ctx: ^app.Application) {
    gpu.render_pipeline_release(state.render_pipeline)
    gpu.compute_pipeline_release(state.compute_pipeline)
    gpu.pipeline_layout_release(state.render_pipeline_layout)
    gpu.pipeline_layout_release(state.compute_pipeline_layout)
    gpu.bind_group_release(state.render_bind_group)
    gpu.bind_group_release(state.compute_bind_group)
    gpu.bind_group_layout_release(state.render_layout)
    gpu.bind_group_layout_release(state.compute_layout)
    gpu.buffer_release(state.params_buffer)
    gpu.buffer_release(state.particles_buffer)
}

main :: proc() {
    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
