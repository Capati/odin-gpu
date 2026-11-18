/*
Example - Game of Life

Conway's Game of Life driven entirely on the GPU. A compute pass reads the
previous generation and writes the next into a second storage buffer; the two
buffers then swap roles every generation (ping-pong). A render pass draws the
current generation as instanced quads — no readback, no CPU simulation.

This is the second compute example, and the first with *two* compute passes per
frame dispatched from one pass: the simulation runs several generations per frame
so the pattern evolves at a watchable rate.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/game_of_life.c
- https://webgpu/webgpu-samples/tree/main/src/sample/gameOfLife
*/
package game_of_life

// Core
import "core:math/rand"

// Vendor
import mu "vendor:microui"

// Local packages
import "../../gpu"
import app "../framework"
import mur "../../utils/microui"

TITLE :: "Game of Life"

LABEL_WIDTH     :: 80
SLIDER_WIDTH    :: 200
UI_WINDOW_WIDTH :: SLIDER_WIDTH + LABEL_WIDTH + 24

// The grid is square and sized in cells, not pixels.
GRID_SIZE :: 128
CELL_COUNT :: GRID_SIZE * GRID_SIZE

// Must match `BLOCK_SIZE` in `game_of_life.comp.slang`.
BLOCK_SIZE :: 16
DISPATCH_COUNT :: GRID_SIZE / BLOCK_SIZE

// Generations simulated per rendered frame. 1 would be accurate but slow to look
// at; too high and the pattern churns without settling.
GENERATIONS_PER_FRAME :: 1

// Seed density, as a percentage of live cells.
SEED_PERCENT :: 45

// Values shared with both shaders; must match `GridParams` in
// `game_of_life.comp.slang` / `game_of_life.vert.slang`.
Grid_Params :: struct #align(16) {
    size:       [2]u32,
    resolution: [2]f32,
}

State :: struct {
    // Two generations, swapped every step.
    cells:                   [2]gpu.Buffer,
    params_buffer:           gpu.Buffer,
    // One compute group per direction of the swap, because a group binds a fixed
    // pair of buffers.
    compute_groups:          [2]gpu.Bind_Group,
    render_groups:           [2]gpu.Bind_Group,
    compute_layout:          gpu.Bind_Group_Layout,
    render_layout:           gpu.Bind_Group_Layout,
    compute_pipeline_layout: gpu.Pipeline_Layout,
    render_pipeline_layout:  gpu.Pipeline_Layout,
    compute_pipeline:        gpu.Compute_Pipeline,
    render_pipeline:         gpu.Render_Pipeline,
    // Buffer index holding the *current* generation after the last step.
    front:                   int,
    params:                  Grid_Params,

    // Editable simulation options.
    settings: struct {
        // Generations to simulate per rendered frame.
        generations: int,
        // Seed density, as a percentage.
        seed_percent: int,
    },

    mu_ctx:                  mu.Context,
    mu_renderer:             mur.Renderer,

    // Cache the render pass descriptor
    rpass:                   struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

// A random starting generation. Dense enough to keep evolving, but under 50% so
// the first steps do not immediately die back to nothing.
seed_cells :: proc(ctx: ^app.Application, cells: []u32) {
    for &cell in cells {
        cell = rand.uint32() % 100 < u32(state.settings.seed_percent) ? 1 : 0
    }
    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.cells[0],
        offset = 0,
        data   = gpu.to_bytes(cells),
    )
    // Start reading from the freshly seeded buffer.
    state.front = 0
}

init_cells :: proc(ctx: ^app.Application) {
    for index in 0 ..< 2 {
        state.cells[index] = gpu.device_create_buffer(ctx.device, {
            label = TITLE + " - Cell grid storage buffer",
            usage = {.Storage, .Copy_Dst},
            size  = u64(CELL_COUNT * size_of(u32)),
        })
    }

    seed: [CELL_COUNT]u32
    seed_cells(ctx, seed[:])
}

init_params_buffer :: proc(ctx: ^app.Application) {
    state.params_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Grid params",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(Grid_Params)),
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    // Same split as `compute_shader`: the compute pass reads one grid and writes
    // the other, so its layout needs writable storage; the vertex shader only
    // reads, and a writable storage buffer may not be visible from the vertex
    // stage without `Vertex_Writable_Storage`.
    state.compute_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Compute bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Compute},
                type       = gpu.Buffer_Binding_Layout{
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Grid_Params)),
                },
            },
            {
                binding    = 1,
                visibility = {.Compute},
                type       = gpu.Buffer_Binding_Layout{
                    type = .Read_Only_Storage,
                },
            },
            {
                binding    = 2,
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
                    min_binding_size = u64(size_of(Grid_Params)),
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

    // compute_groups[i] reads cells[i] and writes cells[1 - i].
    for index in 0 ..< 2 {
        state.compute_groups[index] = gpu.device_create_bind_group(ctx.device, {
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
                        buffer = state.cells[index],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
                {
                    binding  = 2,
                    resource = gpu.Buffer_Binding{
                        buffer = state.cells[1 - index],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
            },
        })

        state.render_groups[index] = gpu.device_create_bind_group(ctx.device, {
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
                        buffer = state.cells[index],
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
            },
        })
    }
}

init_pipelines :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "game_of_life"

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
    state.params.size = {GRID_SIZE, GRID_SIZE}
    state.settings.generations = GENERATIONS_PER_FRAME
    state.settings.seed_percent = SEED_PERCENT

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, {0.02, 0.02, 0.05, 1.0}},
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render pass descriptor",
        color_attachments = state.rpass.colors[:],
    }

    init_cells(ctx)
    init_params_buffer(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)

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

update_params :: proc(ctx: ^app.Application) {
    state.params.resolution = {f32(ctx.width), f32(ctx.height)}

    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.params_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.params),
    )
}

update_ui :: proc(ctx: ^app.Application) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
        mur.slider(&state.mu_ctx, &state.settings.generations, 1, 32, 1, "%.0f")
        mu.label(&state.mu_ctx, "Speed")

        mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
        mur.slider(&state.mu_ctx, &state.settings.seed_percent, 1, 90, 1, "%.0f")
        mu.label(&state.mu_ctx, "Density")

        mu.layout_row(&state.mu_ctx, {-1}, 0)
        if .SUBMIT in mu.button(&state.mu_ctx, "Randomize") {
            // Reseed into cells[0]; `seed_cells` also resets `front` so the next
            // dispatch reads the fresh generation.
            cells: [CELL_COUNT]u32
            seed_cells(ctx, cells[:])
        }
    }
    mu.end(&state.mu_ctx)
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update_params(ctx)
    update_ui(ctx)

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    // Simulate `settings.generations` steps before drawing. Each dispatch flips
    // which buffer holds the current generation.
    cpass := gpu.command_encoder_begin_compute_pass(encoder, {
        label = TITLE + " - Compute pass",
    })
    defer gpu.compute_pass_release(cpass)

    gpu.compute_pass_set_pipeline(cpass, state.compute_pipeline)
    for _ in 0 ..< state.settings.generations {
        gpu.compute_pass_set_bind_group(cpass, 0, state.compute_groups[state.front])
        gpu.compute_pass_dispatch_workgroups(cpass, DISPATCH_COUNT, DISPATCH_COUNT, 1)
        state.front = 1 - state.front
    }
    gpu.compute_pass_end(cpass)

    state.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, state.render_pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, state.render_groups[state.front])
    // No vertex buffer: cell positions come from the storage buffer.
    gpu.render_pass_draw(rpass, 6, CELL_COUNT, 0, 0)

    // Settings UI overlay on top.
    mur.render(&state.mu_renderer, &state.mu_ctx, rpass)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

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
    gpu.render_pipeline_release(state.render_pipeline)
    gpu.compute_pipeline_release(state.compute_pipeline)
    gpu.pipeline_layout_release(state.render_pipeline_layout)
    gpu.pipeline_layout_release(state.compute_pipeline_layout)
    for index in 0 ..< 2 {
        gpu.bind_group_release(state.render_groups[index])
        gpu.bind_group_release(state.compute_groups[index])
        gpu.buffer_release(state.cells[index])
    }
    gpu.bind_group_layout_release(state.render_layout)
    gpu.bind_group_layout_release(state.compute_layout)
    gpu.buffer_release(state.params_buffer)
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
