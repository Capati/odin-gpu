/*
Example - Pristine Grid

A simple WebGPU implementation of the "Pristine Grid" technique described in
this wonderful little blog post:

https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8

Ref:

- https://github.com/toji/pristine-grid-webgpu
- https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8
*/
package pristine_grid

// Core
import "core:log"
import "core:math"
import "core:mem"

import la "core:math/linalg"

// Vendor
import mu "vendor:microui"

// Local packages
import "../../gpu"
import app "../framework"
import mur "../../utils/microui"

TITLE :: "Pristine Grid"
SAMPLE_COUNT :: 4

LABEL_WIDTH     :: 25
SLIDER_WIDTH    :: 200
UI_WINDOW_WIDTH :: SLIDER_WIDTH + LABEL_WIDTH + 24

// Grid options.
CLEAR_COLOR :: [4]f32{0.0, 0.0, 0.2, 1.0}
LINE_COLOR  :: [4]f32{1.0, 1.0, 1.0, 1.0}
BASE_COLOR  :: [4]f32{0.0, 0.0, 0.0, 1.0}
LINE_WIDTH  :: [2]f32{0.05, 0.05}

Vertex :: struct {
    position: [3]f32,
    uv:       [2]f32,
}

// Must match the Camera block in shaders/pristine_grid.slang.
Camera_Uniforms :: struct {
    projection_matrix: la.Matrix4f32,
    view_matrix:       la.Matrix4f32,
    camera_position:   [3]f32,
    time:              f32,
}

// Must match the GridArgs block in shaders/pristine_grid.slang.
Grid_Uniforms :: struct {
    line_color: [4]f32,
    base_color: [4]f32,
    line_width: [2]f32,
    padding:    [2]f32,
}

State :: struct {
    // Orbit interaction (left-drag orbits, middle-drag pans, right-drag and
    // the wheel zoom) comes from the framework camera. Projection stays on
    // the explicit ZO helper below.
    camera:          app.Camera,
    camera_uniforms: Camera_Uniforms,
    projection:      la.Matrix4f32,
    grid_uniforms:   Grid_Uniforms,
    total_time:      f32,

    // Editable grid options in display units (0-255 bytes per channel;
    // converted to 0-1 floats on upload).
    settings: struct {
        clear_color: [4]u8,
        line_color:  [4]u8,
        base_color:  [4]u8,
        line_width:  [2]f32,
    },

    mu_ctx:      mu.Context,
    mu_renderer: mur.Renderer,

    vertices:             gpu.Buffer,
    indices:              gpu.Buffer,
    frame_uniform_buffer: gpu.Buffer,
    uniform_buffer:       gpu.Buffer,

    frame_bind_group_layout: gpu.Bind_Group_Layout,
    bind_group_layout:       gpu.Bind_Group_Layout,
    frame_bind_group:        gpu.Bind_Group,
    bind_group:              gpu.Bind_Group,
    pipeline:                gpu.Render_Pipeline,

    msaa_color: struct {
        texture: gpu.Texture,
        view:    gpu.Texture_View,
    },
    depth_texture: app.Depth_Stencil_Texture,

    // Cache the render pass descriptor
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

update_projection_matrix :: proc(ctx: ^app.Application) {
    aspect := f32(ctx.width) / f32(ctx.height)
    state.projection = la.matrix4_perspective(math.PI / 2.0, aspect, 0.01, 128.0)
}

update_camera_uniforms :: proc() {
    state.camera_uniforms.view_matrix = state.camera.matrices.view
    state.camera_uniforms.camera_position = state.camera.position
    state.camera_uniforms.projection_matrix = state.projection
    state.camera_uniforms.time = state.total_time
}

u8_to_unit :: #force_inline proc "contextless" (c: [4]u8) -> [4]f32 {
    return {f32(c[0]) / 255, f32(c[1]) / 255, f32(c[2]) / 255, f32(c[3]) / 255}
}

unit_to_u8 :: #force_inline proc "contextless" (c: [4]f32) -> [4]u8 {
    convert :: proc "contextless" (x: f32) -> u8 { return u8(clamp(x, 0, 1) * 255) }
    return {convert(c[0]), convert(c[1]), convert(c[2]), convert(c[3])}
}

update_grid_uniforms :: proc() {
    clear := u8_to_unit(state.settings.clear_color)
    state.rpass.colors[0].ops.clear_value = {
        f64(clear[0]),
        f64(clear[1]),
        f64(clear[2]),
        f64(clear[3]),
    }
    state.grid_uniforms.line_color = u8_to_unit(state.settings.line_color)
    state.grid_uniforms.base_color = u8_to_unit(state.settings.base_color)
    state.grid_uniforms.line_width = state.settings.line_width
}

write_uniforms :: proc(ctx: ^app.Application) {
    gpu.queue_write_buffer(ctx.queue, state.frame_uniform_buffer, 0, gpu.to_bytes(state.camera_uniforms))
    gpu.queue_write_buffer(ctx.queue, state.uniform_buffer, 0, gpu.to_bytes(state.grid_uniforms))
}

init_vertex_and_index_buffers :: proc(ctx: ^app.Application) {
    VERTICES := [4]Vertex{
        {position = {-20.0, -0.5, -20.0}, uv = {0.0, 0.0}},
        {position = {20.0, -0.5, -20.0}, uv = {200.0, 0.0}},
        {position = {-20.0, -0.5, 20.0}, uv = {0.0, 200.0}},
        {position = {20.0, -0.5, 20.0}, uv = {200.0, 200.0}},
    }
    state.vertices = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, VERTICES[:])

    INDICES := [6]u16{0, 1, 2, 1, 3, 2}
    state.indices = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Index buffer",
        usage = {.Index, .Copy_Dst},
    }, INDICES[:])
}

init_uniform_buffers :: proc(ctx: ^app.Application) {
    state.frame_uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Frame uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = size_of(Camera_Uniforms),
    })
    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Grid uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = size_of(Grid_Uniforms),
    })
}

init_bind_group_layouts :: proc(ctx: ^app.Application) {
    // Frame bind group layout (camera uniforms, visible to both stages).
    state.frame_bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Frame bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex, .Fragment},
                type = gpu.Buffer_Binding_Layout {
                    type              = .Uniform,
                    min_binding_size  = size_of(Camera_Uniforms),
                },
            },
        },
    })

    // Grid bind group layout (grid uniforms, fragment only).
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Grid bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Fragment},
                type = gpu.Buffer_Binding_Layout {
                    type              = .Uniform,
                    min_binding_size  = size_of(Grid_Uniforms),
                },
            },
        },
    })
}

init_bind_groups :: proc(ctx: ^app.Application) {
    state.frame_bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Frame bind group",
        layout = state.frame_bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding {
                    buffer = state.frame_uniform_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })

    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Grid bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding {
                    buffer = state.uniform_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })
}

init_render_targets :: proc(ctx: ^app.Application) {
    // MSAA color texture (resolved to the swapchain every frame).
    if SAMPLE_COUNT > 1 {
        state.msaa_color.texture = gpu.device_create_texture(ctx.device, {
            label           = TITLE + " - MSAA color texture",
            size            = {width = ctx.width, height = ctx.height, depth_or_array_layers = 1},
            mip_level_count = 1,
            sample_count    = SAMPLE_COUNT,
            dimension       = .D2,
            format          = ctx.render_format,
            usage           = {.Render_Attachment},
        })
        state.msaa_color.view = gpu.texture_create_view(state.msaa_color.texture)
    }

    // Depth texture.
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format       = app.DEFAULT_DEPTH_FORMAT,
        width        = ctx.width,
        height       = ctx.height,
        sample_count = SAMPLE_COUNT,
    })
}

uninit_render_targets :: proc() {
    if state.msaa_color.view != {} {
        gpu.texture_view_release(state.msaa_color.view)
        state.msaa_color.view = {}
    }
    if state.msaa_color.texture != {} {
        gpu.texture_release(state.msaa_color.texture)
        state.msaa_color.texture = {}
    }
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
        state.depth_texture = {}
    }
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "pristine_grid"

    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    blend_state := app.create_blend_state(enable_blend = true)

    depth_stencil_state := app.create_depth_stencil_state({
        format              = app.DEFAULT_DEPTH_FORMAT,
        depth_write_enabled = true,
    })

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.frame_bind_group_layout, state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)

    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module      = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode    = .Vertex,
                    attributes = {
                        {
                            format = .Float32x3,
                            offset = u64(offset_of(Vertex, position)),
                            shader_location = 0,
                        },
                        {
                            format = .Float32x2,
                            offset = u64(offset_of(Vertex, uv)),
                            shader_location = 1,
                        },
                    },
                },
            },
        },
        fragment = &{
            module      = frag_shader_module,
            entry_point = "fs_main",
            targets = {
                {
                    format     = ctx.render_format,
                    blend      = &blend_state,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .None,
        },
        depth_stencil = &depth_stencil_state,
        multisample = {
            count = SAMPLE_COUNT,
            mask  = max(u32),
        },
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.0, 0.0, 0.2, 1.0},
    }
    state.rpass.descriptor = {
        label                    = TITLE + " - Render Pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }

    app.camera_init(&state.camera)
    app.camera_set_rotation_speed(&state.camera, 0.57)
    state.camera.position = {0, 0, -1}
    state.camera.rotation = {0, 0, 0}
    app.camera_update_view_matrix(&state.camera)

    // Editable grid options start at the defaults.
    state.settings.clear_color = unit_to_u8(CLEAR_COLOR)
    state.settings.line_color = unit_to_u8(LINE_COLOR)
    state.settings.base_color = unit_to_u8(BASE_COLOR)
    state.settings.line_width = LINE_WIDTH

    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device          = ctx.device,
        target_format   = ctx.render_format,
        depth_stencil_format = app.DEFAULT_DEPTH_FORMAT,
        pipeline_multisample_state = {count = SAMPLE_COUNT, mask = max(u32)},
    })
    mur.resize(&state.mu_renderer, ctx.width, ctx.height)

    init_vertex_and_index_buffers(ctx)
    init_uniform_buffers(ctx)
    init_bind_group_layouts(ctx)
    init_bind_groups(ctx)
    init_render_targets(ctx)
    init_pipeline(ctx)

    update_projection_matrix(ctx)
    update_camera_uniforms()
    update_grid_uniforms()
    write_uniforms(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.frame_bind_group)
    gpu.bind_group_release(state.bind_group)
    gpu.bind_group_layout_release(state.frame_bind_group_layout)
    gpu.bind_group_layout_release(state.bind_group_layout)
    uninit_render_targets()
    gpu.buffer_release(state.frame_uniform_buffer)
    gpu.buffer_release(state.uniform_buffer)
    gpu.buffer_release(state.vertices)
    gpu.buffer_release(state.indices)
}

update :: proc(ctx: ^app.Application, dt: f32) {
    state.total_time += dt

    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        if .ACTIVE in mu.header(&state.mu_ctx, "Clear Color", {.EXPANDED}) {
            mur.color_edit_row(&state.mu_ctx, &state.settings.clear_color)
        }
        if .ACTIVE in mu.header(&state.mu_ctx, "Line Color", {.EXPANDED}) {
            mur.color_edit_row(&state.mu_ctx, &state.settings.line_color)
        }
        if .ACTIVE in mu.header(&state.mu_ctx, "Base Color", {.EXPANDED}) {
            mur.color_edit_row(&state.mu_ctx, &state.settings.base_color)
        }
        if .ACTIVE in mu.header(&state.mu_ctx, "Line Width", {.EXPANDED}) {
            mu.layout_row(&state.mu_ctx, {20, -1}, 0)
            mu.label(&state.mu_ctx, "X")
            mur.slider(&state.mu_ctx, &state.settings.line_width[0], 0.0, 1.0, 0.001, "%.3f")
            mu.layout_row(&state.mu_ctx, {20, -1}, 0)
            mu.label(&state.mu_ctx, "Y")
            mur.slider(&state.mu_ctx, &state.settings.line_width[1], 0.0, 1.0, 0.001, "%.3f")
        }
    }
    mu.end(&state.mu_ctx)

    // Push edited settings into the uniforms
    update_grid_uniforms()

    app.camera_update(&state.camera, dt)
    update_camera_uniforms()
    write_uniforms(ctx)
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip { return true }
    defer app.release_current_frame(&frame)

    // MSAA color resolves into the swapchain view every frame.
    if SAMPLE_COUNT > 1 {
        state.rpass.colors[0].view = state.msaa_color.view
        state.rpass.colors[0].resolve_target = frame.view
    } else {
        state.rpass.colors[0].view = frame.view
        state.rpass.colors[0].resolve_target = {}
    }

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, state.pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, state.frame_bind_group)
    gpu.render_pass_set_bind_group(rpass, 1, state.bind_group)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertices, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_index_buffer(rpass, state.indices, .Uint16, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_draw_indexed(rpass, 6, 1, 0, 0, 0)

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
    uninit_render_targets()
    init_render_targets(ctx)
    update_projection_matrix(ctx)
    mur.resize(&state.mu_renderer, width, height)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.mu_handle_events(&state.mu_ctx, event)
    #partial switch ev in event {
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    case:
        // Orbit only when the pointer is not over the UI
        if !app.mu_wants_mouse(&state.mu_ctx) {
            app.camera_on_input_event(&state.camera, event)
        }
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

    app.run(app.Application_Descriptor{
        title        = TITLE,
        width        = 1280,
        height       = 720,
        sample_count = SAMPLE_COUNT,
        init_cb      = init,
        iterate_cb   = iterate,
        quit_cb      = quit,
        event_cb     = event,
    })
}
