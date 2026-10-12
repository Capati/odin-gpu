/*
Example - Textured Cube

This example shows how to generate a texture on the GPU (a Mandelbrot
fractal, rendered into an R8_Unorm texture) and sample it onto a cube,
using a false-color gradient to visualize escape-time values.

Ref:

- https://github.com/gfx-rs/wgpu/tree/trunk/examples/features/src/cube
*/
package textured_cube

// Core
import "core:log"
import "core:math"
import "core:mem"
import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Textured Cube"
TEXEL_SIZE :: 256

State :: struct {
    cube_mesh:         app.Cube_Mesh,
    vertices:          gpu.Buffer,
    indices:           gpu.Buffer,
    cube: struct {
        bind_group:        struct {
            handle:   gpu.Bind_Group,
            is_dirty: bool,
        },
        bind_group_layout: gpu.Bind_Group_Layout,
        view_mtx: struct {
            model_view_projection: la.Matrix4x4f32,
        },
    },
    uniform_buffer_vs: gpu.Buffer,
    view_matrices: struct {
        projection: la.Matrix4x4f32,
        view:       la.Matrix4x4f32,
    },
    texture: struct {
        handle:  gpu.Texture,
        view:    gpu.Texture_View,
        sampler: gpu.Sampler,
    },
    depth_texture: app.Depth_Stencil_Texture,
    pipeline: gpu.Render_Pipeline,

    // Cache the render pass descriptor
    rpass: struct {
        colors:                    [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment:  gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:                gpu.Render_Pass_Descriptor,
    },
}

state: State

// Prepare the cube geometry
init_cube_mesh :: proc(ctx: ^app.Application) {
    app.cube_mesh_init(&state.cube_mesh)
}

// Create a vertex buffer from the cube data
init_vertex_buffer :: proc(ctx: ^app.Application) {
    state.vertices = gpu.device_create_buffer_with_data(
        ctx.device, {
        label = TITLE + " - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, state.cube_mesh.vertex_array[:])
}

// Generates a Mandelbrot escape-time texture (R8_Unorm) and samples it onto the cube.
// Kept as-is from the original example: TEXEL_SIZE x TEXEL_SIZE, complex plane
// mapped to roughly [-2, 1] x [-1, 1], 255 max iterations before bailout.
create_texels :: proc() -> (texels: [TEXEL_SIZE * TEXEL_SIZE]u8) {
    for id := 0; id < (TEXEL_SIZE * TEXEL_SIZE); id += 1 {
        cx := 3.0 * f32(id % TEXEL_SIZE) / f32(TEXEL_SIZE - 1) - 2.0
        cy := 2.0 * f32(id / TEXEL_SIZE) / f32(TEXEL_SIZE - 1) - 1.0
        x, y, count := f32(cx), f32(cy), u8(0)
        for count < 0xFF && x * x + y * y < 4.0 {
            old_x := x
            x = x * x - y * y + cx
            y = 2.0 * old_x * y + cy
            count += 1
        }
        texels[id] = count
    }
    return
}

init_texture :: proc(ctx: ^app.Application) {
    texture_extent := gpu.Extent_3D {
        width                  = TEXEL_SIZE,
        height                 = TEXEL_SIZE,
        depth_or_array_layers  = 1,
    }

    state.texture.handle = gpu.device_create_texture(ctx.device, {
        label           = TITLE + " - Mandelbrot texture",
        size            = texture_extent,
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = .R8_Unorm,
        usage           = {.Texture_Binding, .Copy_Dst},
    })

    state.texture.view = gpu.texture_create_view(state.texture.handle)

    texels := create_texels()

    gpu.queue_write_texture(
        ctx.queue,
        {
            texture   = state.texture.handle,
            mip_level = 0,
            origin    = {},
            aspect    = .All,
        },
        gpu.to_bytes(texels),
        {
            offset          = 0,
            bytes_per_row   = TEXEL_SIZE,
            rows_per_image  = TEXEL_SIZE,
        },
        texture_extent,
    )

    sampler_desc := gpu.DEFAULT_SAMPLER_DESCRIPTOR
    state.texture.sampler = gpu.device_create_sampler(ctx.device, sampler_desc)
}

init_depth_texture :: proc(ctx: ^app.Application) {
    // Release current texture if any
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
        state.depth_texture = {}
    }
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format       = app.DEFAULT_DEPTH_FORMAT,
        width        = ctx.width,
        height       = ctx.height,
        sample_count = 1,
    })
}


create_view_projection_matrix :: proc(ctx: ^app.Application) -> la.Matrix4x4f32 {
    aspect_ratio := f32(ctx.width) / f32(ctx.height)
    projection := la.matrix4_perspective_f32(math.PI / 4, aspect_ratio, 1.0, 10.0)
    view := la.matrix4_look_at_f32(
        eye    = {1.5, -5.0, 3.0},
        centre = {0.0, 0.0, 0.0},
        up     = {0.0, 0.0, 1.0},
    )
    return la.mul(projection, view)
}

update_uniform_buffers :: proc(ctx: ^app.Application) {
    mvp := create_view_projection_matrix(ctx)
    gpu.queue_write_buffer(
        queue  = ctx.queue,
        buffer = state.uniform_buffer_vs,
        offset = 0,
        data   = gpu.to_bytes(mvp),
    )
}

init_uniform_buffers :: proc(ctx: ^app.Application) {
    state.uniform_buffer_vs = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - View projection matrix - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = size_of(la.Matrix4x4f32), // 4x4 matrix
    })

    update_uniform_buffers(ctx)
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    state.cube.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Bind group layout",
        entries = {
            {
                // Transform
                binding    = 0,
                visibility = {.Vertex},
                type = gpu.Buffer_Binding_Layout {
                    type                = .Uniform,
                    has_dynamic_offset  = false,
                    min_binding_size    = size_of(la.Matrix4x4f32),
                },
            },
            {
                // Texture view
                binding    = 1,
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout {
                    sample_type     = .Float,
                    view_dimension  = .D2,
                    multisampled    = false,
                },
            },
            {
                // Sampler
                binding    = 2,
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout {
                    type = .Filtering,
                },
            },
        },
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    if state.cube.bind_group.handle != {} {
        gpu.bind_group_release(state.cube.bind_group.handle)
    }

    state.cube.bind_group.handle = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Cube uniform - Buffer bind group",
        layout = state.cube.bind_group_layout,
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

init_pipelines :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "textured_cube"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    depth_stencil_state := app.create_depth_stencil_state({
        format               = app.DEFAULT_DEPTH_FORMAT,
        depth_write_enabled  = true,
    })

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label               = TITLE + " - Pipeline layout",
        bind_group_layouts  = {state.cube.bind_group_layout},
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
                    array_stride = state.cube_mesh.vertex_size,
                    step_mode    = .Vertex,
                    attributes = {
                        // Position
                        {format = .Float32x4, offset = 0, shader_location = 0},
                        // UV
                        {
                            format          = .Float32x2,
                            offset          = state.cube_mesh.uv_offset,
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
                    blend      = nil, // opaque output, no blending needed
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .Back,
        },
        depth_stencil = &depth_stencil_state,
        multisample = {
            count = 1,
            mask  = max(u32),
        },
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.1, 0.2, 0.3, 1.0},
    }

    state.rpass.depth_stencil_attachment = {
        view = {}, // assigned later
        depth_ops = {
            clear_value = 1.0,
            load        = .Clear,
            store       = .Store,
        },
        stencil_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 0.0,
        },
    }

    state.rpass.descriptor = {
        label                     = TITLE + " - Render Pass",
        color_attachments         = state.rpass.colors[:],
        depth_stencil_attachment  = &state.depth_texture.descriptor,
    }

    init_cube_mesh(ctx)
    init_vertex_buffer(ctx)
    init_uniform_buffers(ctx)
    init_texture(ctx)
    init_depth_texture(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.cube.bind_group.handle)
    gpu.bind_group_layout_release(state.cube.bind_group_layout)
    app.depth_stencil_texture_uninit(&state.depth_texture)
    gpu.sampler_release(state.texture.sampler)
    gpu.texture_view_release(state.texture.view)
    gpu.texture_release(state.texture.handle)
    gpu.buffer_release(state.uniform_buffer_vs)
    gpu.buffer_release(state.vertices)
}

update :: proc(ctx: ^app.Application, dt: f32) {
    // No per-frame updates: camera/projection are static except on resize.
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
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertices, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_bind_group(rpass, 0, state.cube.bind_group.handle)
    gpu.render_pass_draw(rpass, u32(state.cube_mesh.vertex_count), 1, 0, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    update_uniform_buffers(ctx)
    init_depth_texture(ctx)
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

    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
