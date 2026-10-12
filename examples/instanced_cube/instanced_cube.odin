/*
Example - Instanced Cube

This example shows the use of instancing.

Ref:

- https://github.com/austinEng/webgpu-samples/blob/main/src/sample/instancedCube
- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/instanced_cube.c
*/
package instanced_cube

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"
import "core:time"
import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Instanced Cube"

// The cubes are laid out on a 4x4 grid, one model matrix per instance.
X_COUNT       :: 4
Y_COUNT       :: 4
NUM_INSTANCES :: X_COUNT * Y_COUNT

State :: struct {
    cube_mesh:     app.Cube_Mesh,
    vertices:      gpu.Buffer,
    uniform_buffer: gpu.Buffer,
    bind_group:     gpu.Bind_Group,
    bind_group_layout: gpu.Bind_Group_Layout,
    pipeline:      gpu.Render_Pipeline,
    depth_texture: app.Depth_Stencil_Texture,
    start:         time.Tick,

    view_matrices: struct {
        projection: la.Matrix4f32,
        view:       la.Matrix4f32,
        model:      [NUM_INSTANCES]la.Matrix4f32,
    },
    // One pre-multiplied matrix per instance, laid out to match the shader's
    // `array<mat4x4f, 16>` uniform.
    model_view_projection: [NUM_INSTANCES]la.Matrix4f32,

    // Cache the render pass descriptor
    rpass: struct {
        colors:                   [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:               gpu.Render_Pass_Descriptor,
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

init_view_matrices :: proc(ctx: ^app.Application) {
    aspect_ratio := f32(ctx.width) / f32(ctx.height)

    // Projection matrix
    state.view_matrices.projection = app.perspective_zo(
        la.TAU / 5.0, aspect_ratio, 1.0, 100.0)

    // View matrix: pull the camera back far enough to frame the whole grid
    state.view_matrices.view =
        la.MATRIX4F32_IDENTITY * la.matrix4_translate_f32({0.0, 0.0, -12.0})
}

// One model matrix per grid cell, on the XY plane
init_model_matrices :: proc() {
    step :: 4.0

    for x in 0 ..< X_COUNT {
        for y in 0 ..< Y_COUNT {
            i := x * Y_COUNT + y
            state.view_matrices.model[i] =
                la.MATRIX4F32_IDENTITY * la.matrix4_translate_f32({
                step * (f32(x) - f32(X_COUNT) / 2.0 + 0.5),
                step * (f32(y) - f32(Y_COUNT) / 2.0 + 0.5),
                0.0,
            })
        }
    }
}

init_uniform_buffers :: proc(ctx: ^app.Application) {
    // Uniform buffer: one 4x4 matrix per instance
    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Camera view matrices - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = NUM_INSTANCES * size_of(la.Matrix4f32),
    })
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Bind group layout",
        entries = {
            {
                // All instances' transform matrices
                binding = 0,
                visibility = {.Vertex},
                type = gpu.Buffer_Binding_Layout {
                    type = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size = NUM_INSTANCES * size_of(la.Matrix4f32),
                },
            },
        },
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Uniform - Buffer bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })
}

init_depth_texture :: proc(ctx: ^app.Application) {
    // Release current texture if any
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
        state.depth_texture = {}
    }
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format = app.DEFAULT_DEPTH_FORMAT,
        width = ctx.width,
        height = ctx.height,
        sample_count = 1,
    })
}

init_pipelines :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "instanced_cube"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    // Color blend state
    blend_state := app.create_blend_state(enable_blend = true)

    // Depth stencil state
    depth_stencil_state := app.create_depth_stencil_state({
        format = app.DEFAULT_DEPTH_FORMAT,
        depth_write_enabled = true,
    })

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
            buffers = {
                {
                    array_stride = state.cube_mesh.vertex_size,
                    step_mode = .Vertex,
                    attributes = {
                        // Position
                        {
                            format = .Float32x4,
                            offset = state.cube_mesh.position_offset,
                            shader_location = 0,
                        },
                        // UV
                        {
                            format = .Float32x2,
                            offset = state.cube_mesh.uv_offset,
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
                    format = ctx.config.format,
                    blend = &blend_state,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_List,
            front_face = .CCW,
            cull_mode = .Back,
        },
        depth_stencil = &depth_stencil_state,
        multisample = {
            count = 1,
            mask  = max(u32),
        },
    })
}

update_transformation_matrix :: proc() {
    now := f32(time.duration_seconds(time.tick_since(state.start)))

    for x in 0 ..< X_COUNT {
        for y in 0 ..< Y_COUNT {
            i := x * Y_COUNT + y

            // Each cube tumbles on an axis that depends on its grid position.
            // The axis is (sin, cos, 0), which is already unit length.
            // The rotation is applied in the cube's own space, so the grid
            // position is kept.
            model := state.view_matrices.model[i] *
                la.matrix4_rotate_f32(1.0, {
                math.sin((f32(x) + 0.5) * now),
                math.cos((f32(y) + 0.5) * now),
                0.0,
            })

            mvp := state.view_matrices.view * model
            mvp = state.view_matrices.projection * mvp

            // No correction matrix needed
            state.model_view_projection[i] = mvp

            // // Fold in the GL -> WebGPU depth convention change, as
            // // `create_view_projection_matrix` does for single-matrix examples.
            // state.model_view_projection[i] = app.OPEN_GL_TO_WGPU_MATRIX * mvp
        }
    }
}

update_uniform_buffers :: proc(ctx: ^app.Application) {
    update_transformation_matrix()

    gpu.queue_write_buffer(
        queue  = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.model_view_projection[:]),
    )
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {} // assigned later
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.1, 0.2, 0.3, 1.0},
    }

    state.rpass.depth_stencil_attachment = {
        view = {}, // assigned later
        depth_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 1.0,
        },
        stencil_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 0.0,
        },
    }

    state.rpass.descriptor = {
        label                    = TITLE + " - Render Pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }

    init_cube_mesh(ctx)
    init_vertex_buffer(ctx)
    init_view_matrices(ctx)
    init_model_matrices()
    init_uniform_buffers(ctx)
    init_depth_texture(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipelines(ctx)

    state.start = time.tick_now()

    return true
}

update :: proc(ctx: ^app.Application, dt: f32) {
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

    // Record render commands
    gpu.render_pass_set_pipeline(rpass, state.pipeline)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertices, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_bind_group(rpass, 0, state.bind_group)
    // One draw for every cube; the vertex shader picks its matrix from instance_idx
    gpu.render_pass_draw(
        rpass,
        u32(state.cube_mesh.vertex_count),
        NUM_INSTANCES,
        0,
        0,
    )
    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    init_depth_texture(ctx)

    // The projection depends on the aspect ratio
    aspect_ratio := f32(width) / f32(height)
    state.view_matrices.projection = app.perspective_zo(
        la.TAU / 5.0, aspect_ratio, 1.0, 100.0)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    #partial switch ev in event {
        case app.Resize_Event:
            resize(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.bind_group)
    gpu.bind_group_layout_release(state.bind_group_layout)
    app.depth_stencil_texture_uninit(&state.depth_texture)
    gpu.buffer_release(state.uniform_buffer)
    gpu.buffer_release(state.vertices)
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = { .Level, .Terminal_Color },
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
