/*
Example - Points

This example shows how to render points of various sizes using a quad and
instancing.

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/points.c
- https://github.com/webgpu/webgpu-samples/tree/main/sample/points
- https://webgpufundamentals.org/webgpu/lessons/webgpu-points.html
*/
package points

// Core
import "core:log"
import "core:mem"
import "core:time"
import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"
import mu "vendor:microui"
import mur "../../utils/microui" /* microui renderer */

TITLE :: "Points"

MAX_VERTICES_COUNT :: 1000
MAX_VERTICES_LEN   :: MAX_VERTICES_COUNT * 3
TEXTURE_SIZE       :: 64
DEPTH_FORMAT       :: gpu.Texture_Format.Depth24Plus

LABEL_WIDTH     :: 50
SLIDER_WIDTH    :: 200
UI_WINDOW_WIDTH :: SLIDER_WIDTH + LABEL_WIDTH + 24

UBO_VS :: struct #align(16) {
    mat:        la.Matrix4x4f32,
    resolution: [2]f32,
    size:       f32,
}

View_Info :: struct {
    fov:                    f32, // radians
    position:               la.Vector3f32,
    target:                 la.Vector3f32,
    up_vector:              la.Vector3f32,
    projection_matrix:      la.Matrix4x4f32,
    view_matrix:            la.Matrix4x4f32,
    view_projection_matrix: la.Matrix4x4f32,
}

Vertex_Kind :: enum u8 {
    Distance_Sized_Points,
    Fixed_Size_Points,
}

Fragment_Kind :: enum u8 {
    Orange,
    Textured,
}

State :: struct {
    ubo_vs: UBO_VS,
    view_info: View_Info,
    vertex_buffer: gpu.Buffer,
    uniform_buffer_vs: gpu.Buffer,
    texture: app.Texture,
    depth_texture: struct {
        texture: app.Texture,
        width: u32,
        height: u32,
    },
    num_samples: u32,
    uniform_bind_group: gpu.Bind_Group,
    bind_group_layout: gpu.Bind_Group_Layout,
    render_pipelines: [2][2]gpu.Render_Pipeline, // [fixed_size][textured]
    settings: struct {
        fixed_size: bool,
        textured:   bool,
        size:       f32,
    },
    start: time.Tick,
    mu_ctx: mu.Context,
    mu_renderer: mur.Renderer,
    rpass: struct {
        colors: [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

@(optimization_mode="favor_size")
create_fibonacci_sphere_vertices :: proc "contextless" (
    num_samples: u32, radius: f32, vertices: []f32,
) #no_bounds_check {
    n := min(num_samples, u32(MAX_VERTICES_COUNT))
    increment := f32(la.PI) * (3.0 - la.sqrt(f32(5.0)))
    for i in 0 ..< n {
        offset := 2.0 / f32(n)
        y := f32(i) * offset - 1.0 + offset / 2.0
        r := la.sqrt(1.0 - y * y)
        phi := f32(i % n) * increment
        x := la.cos(phi) * r
        z := la.sin(phi) * r
        vertices[i * 3 + 0] = x * radius
        vertices[i * 3 + 1] = y * radius
        vertices[i * 3 + 2] = z * radius
    }
}

init_vertex_buffer :: proc(ctx: ^app.Application) {
    vertex_data: [MAX_VERTICES_LEN]f32
    create_fibonacci_sphere_vertices(state.num_samples, 1.0, vertex_data[:])

    state.vertex_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Vertex buffer - Vertices",
        usage = {.Vertex, .Copy_Dst},
    }, vertex_data[:])
}

update_uniform_buffer_data :: proc(ctx: ^app.Application) {
    // Get current timestamp
    now := f32(time.duration_seconds(time.tick_since(state.start)))

    // Set the size in the uniform values
    state.ubo_vs.size = state.settings.size

    width  := f32(ctx.width)
    height := f32(ctx.height)

    vi := &state.view_info

    // Set the matrix value
    vi.projection_matrix = la.matrix4_perspective_f32(
        vi.fov,
        width / height,
        0.1,
        50.0,
    )
    vi.view_matrix = la.matrix4_look_at_f32(
        vi.position,
        vi.target,
        vi.up_vector,
    )
    vi.view_projection_matrix = vi.projection_matrix * vi.view_matrix

    state.ubo_vs.mat =
        vi.view_projection_matrix *
        la.matrix4_rotate_f32(now, {0, 1, 0}) *
        la.matrix4_rotate_f32(now * 0.1, {1, 0, 0})

    // Set the resolution in the uniform values
    state.ubo_vs.resolution = {width, height}
}

update_uniform_buffers :: proc(ctx: ^app.Application) {
    // Update the uniform buffer data
    update_uniform_buffer_data(ctx)

    // Copy the uniform values to the GPU
    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.uniform_buffer_vs,
        offset = 0,
        data   = gpu.to_bytes(state.ubo_vs),
    )

    // gpu.queue_write_buffer_raw(
    //     queue  = ctx.queue,
    //     buffer = state.uniform_buffer_vs,
    //     offset = 0,
    //     data   = &state.ubo_vs,
    //     size   = uint(size_of(state.ubo_vs)),
    // )
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    // Create vertex shader uniform buffer block
    state.uniform_buffer_vs = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Vertex shader - Uniform buffer block",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(state.ubo_vs)),
    })

    // Initialize GPU buffer
    update_uniform_buffer_data(ctx)
}

init_texture :: proc(ctx: ^app.Application) {
    // Texture
    texture_desc := gpu.Texture_Descriptor{
        label           = TITLE + " - Quad - Texture",
        usage           = {.Copy_Dst, .Texture_Binding, .Render_Attachment},
        format          = .RGBA8_Unorm,
        dimension       = .D2,
        mip_level_count = 1,
        sample_count    = 1,
        size            = { TEXTURE_SIZE, TEXTURE_SIZE, 1 },
    }
    state.texture.handle = gpu.device_create_texture(ctx.device, texture_desc)
    assert(state.texture.handle != {})

    // Set texture data - create a simple white circle pattern
    data: [TEXTURE_SIZE * TEXTURE_SIZE * 4]u8
    center_x : f32 = TEXTURE_SIZE / 2.0
    center_y : f32 = TEXTURE_SIZE / 2.0

    for y : u32 = 0; y < TEXTURE_SIZE; y += 1 {
        for x : u32 = 0; x < TEXTURE_SIZE; x += 1 {
            index := (y * TEXTURE_SIZE + x) * 4

            // Calculate distance from center
            dx     := f32(x) - center_x
            dy     := f32(y) - center_y
            dist   := la.sqrt(dx * dx + dy * dy)
            radius := TEXTURE_SIZE / f32(2.0)

            // Create a white circle with soft edges
            if dist < radius * 0.8 {
                // White color
                data[index + 0] = 255 // R
                data[index + 1] = 255 // G
                data[index + 2] = 255 // B
                data[index + 3] = 255 // A
            } else {
                // Transparent background
                data[index + 0] = 0
                data[index + 1] = 0
                data[index + 2] = 0
                data[index + 3] = 0
            }
        }
    }

    gpu.queue_write_texture(
        queue = ctx.queue,
        destination = {
            texture   = state.texture.handle,
            mip_level = 0,
            origin    = {0 , 0, 0},
            aspect    = .All,
        },
        data = data[:],
        data_layout = {
            offset         = 0,
            bytes_per_row  = TEXTURE_SIZE * 4,
            rows_per_image = TEXTURE_SIZE,
        },
        write_size = {
            width              = TEXTURE_SIZE,
            height             = TEXTURE_SIZE,
            depth_or_array_layers = 1,
        },
    )

    // Texture view
    view_desc := gpu.Texture_View_Descriptor {
        label             = TITLE + " - Quad - Texture View",
        format            = texture_desc.format,
        dimension         = .D2,
        usage             = texture_desc.usage,
        base_mip_level    = 0,
        mip_level_count   = texture_desc.mip_level_count,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .All,
    }

    state.texture.view = gpu.texture_create_view(state.texture.handle, view_desc)

    // Create a sampler with linear filtering for smooth interpolation
    sampler_desc := gpu.Sampler_Descriptor {
        label            = TITLE + " - Quad - Sampler",
        address_mode_u   = .Clamp_To_Edge,
        address_mode_v   = .Clamp_To_Edge,
        address_mode_w   = .Clamp_To_Edge,
        mag_filter       = .Linear,
        min_filter       = .Linear,
        mipmap_filter    = .Linear,
        anisotropy_clamp = 16,
    }

    state.texture.sampler = gpu.device_create_sampler(ctx.device, sampler_desc)
}

init_depth_texture :: proc(ctx: ^app.Application) {
    if state.depth_texture.texture.handle != {} {
        app.texture_uninit(&state.depth_texture.texture)
    }

    // Set texture size
    state.depth_texture.width  = ctx.width
    state.depth_texture.height = ctx.height

    // Create the depth texture
    texture_desc := gpu.Texture_Descriptor{
        label           = TITLE + " - Depth Texture",
        usage           = {.Texture_Binding, .Render_Attachment},
        format          = DEPTH_FORMAT,
        dimension       = .D2,
        mip_level_count = 1,
        sample_count    = 1,
        size            = { state.depth_texture.width, state.depth_texture.height, 1 },
    }
    state.depth_texture.texture.handle =
        gpu.device_create_texture(ctx.device, texture_desc)
    assert(state.depth_texture.texture.handle != {})

    // Create the depth texture view
    view_desc := gpu.Texture_View_Descriptor {
        label             = TITLE + " - Depth Texture View",
        dimension         = .D2,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
    }

    state.depth_texture.texture.view =
        gpu.texture_create_view(state.depth_texture.texture.handle, view_desc)

    state.rpass.depth_stencil_attachment = {
        view = state.depth_texture.texture.view,
        depth_ops = {
            load = .Clear,
            store = .Store,
            clear_value = 1.0,
        },
    }
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    // Bind group layout
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device,{
        label = TITLE + " - Bind group layout",
        entries = {
            {
                // Uniform buffer
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout{
                    type              = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size  = u64(size_of(state.ubo_vs)),
                },
            },
            {
                // Sampler
                binding = 1,
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout {
                    type = .Filtering,
                },
            },
            {
                // Texture view
                binding = 2,
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout {
                    sample_type = .Float,
                    view_dimension = .D2,
                    multisampled = false,
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
        label  = TITLE + " - Uniform buffer - Bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer_vs,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
            {
                binding = 1,
                resource = state.texture.sampler,
            },
            {
                binding = 2,
                resource = state.texture.view,
            },
        },
    })
}

init_pipelines :: proc(ctx: ^app.Application) {
    // Load shaders
    distance_sized_points_vert :=
        app.load_shader(ctx.device, #directory, "distance_sized_points" + ".vert")
    defer gpu.shader_module_release(distance_sized_points_vert)

    fixed_size_points_vert :=
        app.load_shader(ctx.device, #directory, "fixed_size_points" + ".vert")
    defer gpu.shader_module_release(fixed_size_points_vert)

    orange_frag := app.load_shader(ctx.device, #directory, "orange" + ".frag")
    defer gpu.shader_module_release(orange_frag)

    textured_frag := app.load_shader(ctx.device, #directory, "textured" + ".frag")
    defer gpu.shader_module_release(textured_frag)

    vertex_shaders := [2]gpu.Shader_Module {
        distance_sized_points_vert, // [0] fixed_size = false
        fixed_size_points_vert,     // [1] fixed_size = true
    }

    fragment_shaders := [2]gpu.Shader_Module {
        orange_frag,   // [0] textured = false
        textured_frag, // [1] textured = true
    }

    // Color blend state
    blend_state := gpu.Blend_State {
        color = {
            operation  = .Add,
            src_factor = .One,
            dst_factor = .One_Minus_Src_Alpha,
        },
        alpha = {
            operation  = .Add,
            src_factor = .One,
            dst_factor = .One_Minus_Src_Alpha,
        },
    }

    // Depth stencil state
    depth_stencil_state := app.create_depth_stencil_state({
        format = DEPTH_FORMAT,
        depth_write_enabled = true,
    })
    depth_stencil_state.depth_compare = .Less

    // Vertex buffer layout
    instanced_point_attributes := [1]gpu.Vertex_Attribute {
        {
            format          = .Float32x3,
            offset          = 0,
            shader_location = 0,
        },
    }

    instanced_point_layout := gpu.Vertex_Buffer_Layout {
        array_stride = 3 * size_of(f32),
        step_mode    = .Instance,
        attributes   = instanced_point_attributes[:],
    }

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)

    // Make pipelines for each combination
    for fixed_size in 0 ..< 2 {
        for textured in 0 ..< 2 {
            pipeline_desc := gpu.Render_Pipeline_Descriptor {
                label  = TITLE + " - Points - Render pipeline",
                layout = pipeline_layout,
                vertex = {
                    module      = vertex_shaders[fixed_size],
                    entry_point = "vs_main",
                    buffers     = {instanced_point_layout},
                },
                fragment = &{
                    module      = fragment_shaders[textured],
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
                    cull_mode  = .None,
                    front_face = .CCW,
                },
                depth_stencil = &depth_stencil_state,
                multisample = {
                    count = 1,
                    mask  = 0xFFFFFFFF,
                },
            }

            pipeline := gpu.device_create_render_pipeline(ctx.device, pipeline_desc)
            assert(pipeline != {}, "failed to create render pipeline")

            state.render_pipelines[fixed_size][textured] = pipeline
        }
    }
}

init_microui :: proc(ctx: ^app.Application) {
    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device = ctx.device,
        target_format = ctx.render_format,
        depth_stencil_format = DEPTH_FORMAT,
        pipeline_multisample_state = gpu.DEFAULT_MULTISAMPLE_STATE,
    })

    mur.resize(&state.mu_renderer, ctx.width, ctx.height)
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.3, 0.3, 0.3, 1.0},
    }

    state.rpass.descriptor = {
        label                    = TITLE + " - Render Pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.rpass.depth_stencil_attachment,
    }

    state.view_info = {
        fov                    = (90.0 * la.PI) / 180.0,
        position               = {0.0, 0.0, 1.5},
        target                 = {0.0, 0.0, 0.0},
        up_vector              = {0.0, 1.0, 0.0},
        view_matrix            = {},
        projection_matrix      = {},
        view_projection_matrix = {},
    }

    state.num_samples = 1000
    state.settings.size = 10.0

    init_vertex_buffer(ctx)
    init_uniform_buffer(ctx)
    init_texture(ctx)
    init_depth_texture(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)
    init_microui(ctx)

    state.start = time.tick_now()

    return true
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)

    for fixed_size in 0 ..< 2 {
        for textured in 0 ..< 2 {
            gpu.render_pipeline_release(state.render_pipelines[fixed_size][textured])
        }
    }

    gpu.bind_group_release(state.uniform_bind_group)
    gpu.bind_group_layout_release(state.bind_group_layout)
    app.texture_uninit(&state.depth_texture.texture)
    app.texture_uninit(&state.texture)
    gpu.buffer_release(state.uniform_buffer_vs)
    gpu.buffer_release(state.vertex_buffer)
}

update :: proc(ctx: ^app.Application, dt: f32) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        mu.checkbox(&state.mu_ctx, "Fixed size", &state.settings.fixed_size)
        mu.checkbox(&state.mu_ctx, "Textured", &state.settings.textured)

        mu.layout_row(&state.mu_ctx, {-LABEL_WIDTH, -1}, 0)
        mur.slider(&state.mu_ctx, &state.settings.size, 0.0, 80.0, 0.1, "%.1f")
        mu.label(&state.mu_ctx, "Size")
    }
    mu.end(&state.mu_ctx)

    // Update uniform data
    update_uniform_buffers(ctx)
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
    #no_bounds_check pipeline :=
        state.render_pipelines[int(state.settings.fixed_size)] \
                              [int(state.settings.textured)]

    // Record render commands
    gpu.render_pass_set_pipeline(rpass, pipeline)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertex_buffer, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_bind_group(rpass, 0, state.uniform_bind_group)
    gpu.render_pass_draw(rpass, 6, state.num_samples, 0, 0)

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
