/*
Example - Coordinate System

Illustrates the coordinate systems used in WebGPU. WebGPU's coordinate
systems match DirectX and Metal's coordinate systems in a graphics pipeline.
Y-axis is up in normalized device coordinate (NDC): point(-1.0, -1.0) in NDC
is located at the bottom-left corner of NDC. This example has several options
for changing relevant pipeline state, and displaying meshes with WebGPU or
Vulkan style coordinates.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/coordinate_system.c
- https://gpuweb.github.io/gpuweb/
- https://github.com/gpuweb/gpuweb/issues/416
- https://github.com/SaschaWillems/Vulkan/blob/master/examples/negativeviewportheight/negativeviewportheight.cpp
*/
package coordinate_system

// Core
import "base:runtime"
import "core:fmt"
import "core:image"
import "core:log"
import "core:mem"

import _ "core:image/png"

// Vendor
import "../../gpu"
import app "../framework"
import mu "vendor:microui"
import mur "../../utils/microui" /* microui renderer */

TITLE :: "Coordinate System"
CLIENT_WIDTH :: 650
CLIENT_HEIGHT :: 650

UI_WINDOW_WIDTH :: 230

QUAD_ITEMS :: []mur.Combobox_Item(Quad_Kind){
    { "WebGPU (Y Positive)", .WebGPU_Y_Up },
    { "Vulkan (Y Negative)", .VK_Y_Down },
}

WIND_ORDER_ITEMS :: []mur.Combobox_Item(gpu.Front_Face){
    { "Clock Wise", .CW },
    { "Counter Clock Wise", .CCW },
}

CULL_MODE_ITEMS :: []mur.Combobox_Item(gpu.Cull_Mode){
    { "None", .None },
    { "Front", .Front },
    { "Back", .Back },
}

Vertex :: struct {
    pos: [3]f32,
    uv: [2]f32,
}

Texture_Kind :: enum u8 {
    CW,
    CCW,
}

Quad_Kind :: enum u8 {
    WebGPU_Y_Up,
    VK_Y_Down,
}

State :: struct {
    textures: [Texture_Kind]struct {
        file: string,
        size: [2]u32,
        texture: app.Texture,
    },
    quad: struct {
        vertices: [Quad_Kind]gpu.Buffer,
        indices:  [Texture_Kind]gpu.Buffer,
    },
    bind_group_layout: gpu.Bind_Group_Layout,
    pipeline_layout: gpu.Pipeline_Layout,
    bind_groups: [Texture_Kind]gpu.Bind_Group,
    pipeline: gpu.Render_Pipeline,
    mu_ctx: mu.Context,
    mu_renderer: mur.Renderer,
    settings: struct {
        winding_order: gpu.Front_Face,
        cull_mode: gpu.Cull_Mode,
        quad_type: Quad_Kind,
    },
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
    pipeline_needs_rebuild: bool,
}

state: State

init_textures :: proc(ctx: ^app.Application) {
    ta := context.temp_allocator
    for &it in state.textures {
        data, data_ok := app.load_file(it.file, ta)
        assert(data_ok)
        img, img_err := image.load_from_bytes(data, {.alpha_add_if_missing}, ta)
        assert(img_err == nil)
        it.size = {u32(img.width), u32(img.height)}
        app.texture_init(&it.texture, {
            size = {
                width = u32(img.width),
                height = u32(img.height),
                depth_or_array_layers = 1,
            },
            format = .RGBA8_Unorm,
            pixels = gpu.to_bytes(img.pixels),
        })
    }
}

init_quad_vertex_buffers :: proc(ctx: ^app.Application, width, height: u32) {
    quad_vertices :: proc(half: [2]f32, y_sign: f32) -> [4]Vertex {
        return {
            {pos = {-half.x, -half.y * y_sign, 1.0}, uv = {0.0, 1.0}},
            {pos = {-half.x,  half.y * y_sign, 1.0}, uv = {0.0, 0.0}},
            {pos = { half.x,  half.y * y_sign, 1.0}, uv = {1.0, 0.0}},
            {pos = { half.x, -half.y * y_sign, 1.0}, uv = {1.0, 1.0}},
        }
    }

    // Both textures are drawn with the same vertex buffer, so use the first one's size
    tex := state.textures[.CW].size
    tex_aspect := f32(tex.x) / f32(tex.y)
    win_aspect := f32(width) / f32(height)

    half := [2]f32{1, 1}
    if tex_aspect > win_aspect {
        half.y = win_aspect / tex_aspect
    } else {
        half.x = tex_aspect / win_aspect
    }

    for kind in Quad_Kind {
        if state.quad.vertices[kind] != {} {
            gpu.buffer_release(state.quad.vertices[kind])
        }
    }

    verts_y_up   := quad_vertices(half,  1)
    verts_y_down := quad_vertices(half, -1)

    state.quad.vertices[.WebGPU_Y_Up] = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Quad vertices buffer - Y up",
        usage = {.Vertex, .Copy_Dst},
    }, verts_y_up[:])

    state.quad.vertices[.VK_Y_Down] = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Quad vertices buffer - Y down",
        usage = {.Vertex, .Copy_Dst},
    }, verts_y_down[:])
}

init_quad_buffers :: proc(ctx: ^app.Application) {
    init_quad_vertex_buffers(ctx, ctx.width, ctx.height)

    // Counter clock wise indices
    indices_ccw := [6]u32  {
        2, 1, 0,
        0, 3, 2,
    }
    state.quad.indices[.CCW] = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Quad indices buffer - CCW",
        usage = {.Index, .Copy_Dst},
    }, indices_ccw[:])

    // Clock wise indices
    indices_cw := [6]u32  {
        0, 1, 2,
        2, 3, 0,
    }
    state.quad.indices[.CW] = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Quad indices buffer - CW",
        usage = {.Index, .Copy_Dst},
    }, indices_cw[:])
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Bind group layout",
        entries = {
            {
                // Binding 0 : Fragment shader texture view
                binding = 0,
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout{
                    sample_type = .Float,
                    view_dimension = .D2,
                    multisampled = false,
                },
            },
            {
                // Binding 1: Fragment shader image sampler
                binding = 1,
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout{
                    type = .Filtering,
                },
            },
        },
    })
}

init_pipeline_layout :: proc(ctx: ^app.Application) {
    state.pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
}

init_bind_groups :: proc(ctx: ^app.Application) {
    for kind in Texture_Kind {
        if state.bind_groups[kind] != {} {
            gpu.bind_group_release(state.bind_groups[kind])
        }
        tex := &state.textures[kind].texture
        state.bind_groups[kind] = gpu.device_create_bind_group(ctx.device, {
            label  = fmt.tprintf("%s - Bind Group - %v", TITLE, kind),
            layout = state.bind_group_layout,
            entries = {
                {binding = 0, resource = tex.view},
                {binding = 1, resource = tex.sampler},
            },
        })
    }
}

init_pipeline :: proc(ctx: ^app.Application) {
    // Cleanup existing pipeline
    if state.pipeline != {} {
        gpu.render_pipeline_release(state.pipeline)
    }

    SHADER_NAME :: "coordinate_system"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    // Create pipeline
    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = TITLE + " - Render Pipeline",
        layout = state.pipeline_layout,
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        {format = .Float32x3, offset = 0, shader_location = 0},
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
            front_face = state.settings.winding_order,
            cull_mode = state.settings.cull_mode,
        },
        multisample = {
            count = 1,
            mask = max(u32),
        },
    })

    state.pipeline_needs_rebuild = false
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

    state.textures = {
        .CW = { file = "assets/textures/texture_orientation_cw_rgba.png" },
        .CCW = { file = "assets/textures/texture_orientation_ccw_rgba.png" },
    }

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = gpu.COLOR_BLACK,
    }

    state.rpass.descriptor = {
        label             = TITLE + " - Render Pass",
        color_attachments = state.rpass.colors[:],
    }

    init_textures(ctx)
    init_quad_buffers(ctx)
    init_bind_group_layout(ctx)
    init_pipeline_layout(ctx)
    init_bind_groups(ctx)
    init_pipeline(ctx)
    init_microui(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)

    gpu.render_pipeline_release(state.pipeline)

    for kind in Texture_Kind {
        gpu.bind_group_release(state.bind_groups[kind])
    }

    gpu.pipeline_layout_release(state.pipeline_layout)
    gpu.bind_group_layout_release(state.bind_group_layout)

    for kind in Quad_Kind {
        gpu.buffer_release(state.quad.vertices[kind])
    }

    for kind in Texture_Kind {
        gpu.buffer_release(state.quad.indices[kind])
    }

    for &it in state.textures {
        app.texture_uninit(&it.texture)
    }
}

update :: proc(ctx: ^app.Application, dt: f32) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, TITLE, {50, 65, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        if .ACTIVE in mu.header(&state.mu_ctx, "Scene", {.EXPANDED}) {
            mur.labeled_combobox(
                &state.mu_ctx, "Quad Type", &state.settings.quad_type, QUAD_ITEMS)
        }

        if .ACTIVE in mu.header(&state.mu_ctx, "Pipeline", {.EXPANDED}) {
            if .CHANGE in mur.labeled_combobox(
                &state.mu_ctx,
                "Winding Order",
                &state.settings.winding_order,
                WIND_ORDER_ITEMS,
            ) {
                state.pipeline_needs_rebuild = true
            }

            if .CHANGE in mur.labeled_combobox(
                &state.mu_ctx,
                "Cull Mode",
                &state.settings.cull_mode,
                CULL_MODE_ITEMS,
            ) {
                state.pipeline_needs_rebuild = true
            }
        }
    }
    mu.end(&state.mu_ctx)

    if state.pipeline_needs_rebuild {
        init_pipeline(ctx)
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

    // Bind the rendering pipeline
    gpu.render_pass_set_pipeline(rpass, state.pipeline)

    // Select vertex buffer based on quad type
    vertex_buffer := state.settings.quad_type == .VK_Y_Down \
        ? state.quad.vertices[.VK_Y_Down] : state.quad.vertices[.WebGPU_Y_Up]

    // Render both CW and CCW quads
    for kind in Texture_Kind {
        gpu.render_pass_set_bind_group(rpass, 0, state.bind_groups[kind])
        gpu.render_pass_set_index_buffer(
            rpass, state.quad.indices[kind], .Uint32, 0, gpu.WHOLE_SIZE)
        gpu.render_pass_set_vertex_buffer(rpass, 0, vertex_buffer, 0, gpu.WHOLE_SIZE)
        gpu.render_pass_draw_indexed(rpass, 6, 1, 0, 0, 0)
    }

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
    init_quad_vertex_buffers(ctx, width, height)
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
        width      = CLIENT_WIDTH,
        height     = CLIENT_HEIGHT,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
