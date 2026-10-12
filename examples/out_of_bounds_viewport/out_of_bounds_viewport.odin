/*
Example - Out-of-bounds Viewport

The spec doesn't let you set the viewport's values to be out-of-bounds.
Therefore, the viewport's values need to be clamped to the screen-size, which
means the viewport values can't be defined in a way that makes the viewport
go off the screen. This example shows how to render a viewport out-of-bounds.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/out_of_bounds_viewport.c
- https://babylonjs.medium.com/how-to-simulate-out-of-bounds-viewports-when-using-webgpu-or-babylonnative-2280637c0660
*/
package out_of_bounds_viewport

// Core
import "base:runtime"
import "core:image"
import "core:log"
import "core:mem"

import _ "core:image/png"

// Local packages
import "../../gpu"
import app "../framework"
import mu "vendor:microui"
import mur "../../utils/microui" /* microui renderer */

TITLE :: "Out-of-bounds Viewport"

LABEL_WIDTH     :: 50
SLIDER_WIDTH    :: 200
UI_WINDOW_WIDTH :: SLIDER_WIDTH + LABEL_WIDTH + 24

Viewport_Params :: struct {
    x:      f32,
    y:      f32,
    width:  f32,
    height: f32,
}

State :: struct {
    texture: app.Texture,
    uniform_buffer: gpu.Buffer,
    viewport_params: Viewport_Params,
    bind_group_layout: gpu.Bind_Group_Layout,
    bind_group: gpu.Bind_Group,
    pipeline: gpu.Render_Pipeline,
    mu_ctx: mu.Context,
    mu_renderer: mur.Renderer,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_texture :: proc (ctx: ^app.Application) {
    ta := context.temp_allocator
    data, data_ok := app.load_file("assets/textures/Di-3d.png", ta)
    assert(data_ok)
    img, img_err := image.load_from_bytes(data, {.alpha_add_if_missing}, ta)
    assert(img_err == nil)
    app.texture_init(&state.texture, {
        size = {
            width = u32(img.width),
            height = u32(img.height),
            depth_or_array_layers = 1,
        },
        format = .RGBA8_Unorm,
        pixels = gpu.to_bytes(img.pixels),
    })
}

// Update uniform buffer with current viewport parameters
update_uniform_buffer :: proc(ctx: ^app.Application) {
    gpu.queue_write_buffer(
        ctx.queue,
        state.uniform_buffer,
        0,
        gpu.to_bytes(state.viewport_params),
    )
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    state.viewport_params = {
        x      = 0.0,
        y      = 0.0,
        width  = 1.0,
        height = 1.0,
    }

    uniform_buffer_size := u64(size_of(Viewport_Params))
    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = uniform_buffer_size,
    })

    update_uniform_buffer(ctx)
}

init_bind_group_layout :: proc (ctx: ^app.Application) {
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device,{
        label = TITLE + " - Bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout{
                    type              = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size  = u64(size_of(Viewport_Params)),
                },
            },
            {
                binding    = 1,
                visibility = {.Fragment},
                type       = gpu.Texture_Binding_Layout{
                    sample_type    = .Float,
                    view_dimension = .D2,
                    multisampled   = false,
                },
            },
            {
                binding    = 2,
                visibility = {.Fragment},
                type       = gpu.Sampler_Binding_Layout{
                    type = .Filtering,
                },
            },
        },
    })
}

init_bind_group :: proc (ctx: ^app.Application) {
    if state.bind_group != {} {
        gpu.bind_group_release(state.bind_group)
    }

    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
            {
                binding  = 1,
                resource = state.texture.view,
            },
            {
                binding  = 2,
                resource = state.texture.sampler,
            },
        },
    })
}

init_pipeline :: proc (ctx: ^app.Application) {
    // Cleanup existing pipeline
    if state.pipeline != {} {
        gpu.render_pipeline_release(state.pipeline)
    }

    SHADER_NAME :: "out_of_bounds_viewport"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)

    // Create pipeline
    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = TITLE + " - Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
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
            cull_mode = .None,
        },
        multisample = gpu.DEFAULT_MULTISAMPLE_STATE,
    })
}

init_microui :: proc(ctx: ^app.Application) {
    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device = ctx.device,
        target_format = ctx.render_format,
        pipeline_multisample_state = gpu.DEFAULT_MULTISAMPLE_STATE,
    })

    mur.resize(&state.mu_renderer, ctx.width, ctx.height)
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.1, 0.2, 0.3, 1.0},
    }

    state.rpass.descriptor = {
        label             = TITLE + "Render Pass",
        color_attachments = state.rpass.colors[:],
    }

    init_texture(ctx)
    init_uniform_buffer(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipeline(ctx)
    init_microui(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.bind_group)
    gpu.bind_group_layout_release(state.bind_group_layout)
    gpu.buffer_release(state.uniform_buffer)
    app.texture_uninit(&state.texture)
}

slider_row :: proc(value: ^f32, low, high: f32, label: string) -> bool {
    changed := .CHANGE in mu.slider(&state.mu_ctx, value, low, high, 0.01, "%.2f")
    mu.label(&state.mu_ctx, label)
    return changed
}

update :: proc(ctx: ^app.Application, dt: f32) {
    uniforms_changed: bool

    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Viewport Parameters", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        mu.layout_row(&state.mu_ctx, {-LABEL_WIDTH, -1}, 0)

        uniforms_changed |= slider_row(&state.viewport_params.x,      -0.5, 0.5, "X")
        uniforms_changed |= slider_row(&state.viewport_params.y,      -0.5, 0.5, "Y")
        uniforms_changed |= slider_row(&state.viewport_params.width,   0.0, 2.0, "Width")
        uniforms_changed |= slider_row(&state.viewport_params.height,  0.0, 2.0, "Height")
    }
    mu.end(&state.mu_ctx)

    if uniforms_changed {
        update_uniform_buffer(ctx)
    }
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
    gpu.render_pass_set_bind_group(rpass, 0, state.bind_group)
    gpu.render_pass_draw(rpass, 6, 1, 0, 0)

    // Render ui overlay on top
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
