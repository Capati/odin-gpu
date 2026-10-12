/*
Example - glTF Cube

Loads the first mesh primitive from a small glTF 2.0 asset through the
framework's pure-Odin glTF helper and renders its POSITION/NORMAL attributes
and indices. Materials and scene-node transforms are intentionally kept out
of this first loader example.
*/
package gltf_cube

// Core
import "base:runtime"
import "core:log"
import la "core:math/linalg"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "glTF Cube"
GLTF_PATH :: "assets/models/cube.gltf"
MODEL_SCALE :: 0.15

Vertex :: struct {
    position: [3]f32,
    normal:   [3]f32,
}

State :: struct {
    vertices:          gpu.Buffer,
    indices:           gpu.Buffer,
    index_count:       u32,
    uniform_buffer:    gpu.Buffer,
    bind_group_layout: gpu.Bind_Group_Layout,
    bind_group:        gpu.Bind_Group,
    pipeline:          gpu.Render_Pipeline,
    camera:            app.Camera,
    mvp:               la.Matrix4f32,
    depth_texture:     app.Depth_Stencil_Texture,
    rpass:             struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_gltf_mesh :: proc(ctx: ^app.Application) {
    document, load_err := app.gltf_load(GLTF_PATH, context.temp_allocator)
    assert(load_err == .None, "failed to load cube.gltf")
    defer app.gltf_unload(&document)

    assert(document.data != nil && len(document.data.meshes) > 0, "cube.gltf has no meshes")
    mesh := &document.data.meshes[0]
    assert(len(mesh.primitives) > 0, "cube.gltf mesh has no primitives")
    primitive := &mesh.primitives[0]

    position_accessor := app.gltf_find_attribute(primitive, .Position)
    normal_accessor := app.gltf_find_attribute(primitive, .Normal)
    indices_accessor := primitive.indices
    assert(position_accessor != nil, "glTF primitive has no POSITION attribute")
    assert(normal_accessor != nil, "glTF primitive has no NORMAL attribute")
    assert(indices_accessor != nil, "glTF primitive has no indices")
    assert(
        position_accessor.count == normal_accessor.count,
        "glTF POSITION and NORMAL counts differ",
    )

    vertices := make([]Vertex, position_accessor.count, context.temp_allocator)
    for i in 0 ..< len(vertices) {
        vertex := &vertices[i]
        assert(
            app.gltf_read_attribute_floats(position_accessor, i, vertex.position[:]),
            "failed to read glTF POSITION",
        )
        assert(
            app.gltf_read_attribute_floats(normal_accessor, i, vertex.normal[:]),
            "failed to read glTF NORMAL",
        )
    }

    indices := make([]u32, indices_accessor.count, context.temp_allocator)
    for i in 0 ..< len(indices) {
        indices[i] = app.gltf_read_index(indices_accessor, i)
    }
    state.index_count = u32(len(indices))

    state.vertices = gpu.device_create_buffer_with_data(
        ctx.device,
        {label = TITLE + " - glTF vertex buffer", usage = {.Vertex, .Copy_Dst}},
        vertices,
    )
    state.indices = gpu.device_create_buffer_with_data(
        ctx.device,
        {label = TITLE + " - glTF index buffer", usage = {.Index, .Copy_Dst}},
        indices,
    )
}

update_mvp :: proc(ctx: ^app.Application, dt: f32) {
    app.camera_update(&state.camera, dt)

    projection := state.camera.matrices.perspective
    app.camera_projection_matrix_convert_clip_space_near_z(&projection, .Zero, .Negative_One)
    model := la.matrix4_scale_f32({MODEL_SCALE, MODEL_SCALE, MODEL_SCALE})
    state.mvp = projection * state.camera.matrices.view * model

    gpu.queue_write_buffer(
        queue = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data = gpu.to_bytes(state.mvp),
    )
}

init_camera :: proc(ctx: ^app.Application) {
    app.camera_init(&state.camera)
    state.camera.type = .Look_At
    app.camera_set_position(&state.camera, {0, 0, -4})
    app.camera_set_rotation(&state.camera, {20, 20, 0})
    app.camera_set_perspective(&state.camera, 55, f32(ctx.width) / f32(ctx.height), 0.1, 100)

    state.uniform_buffer = gpu.device_create_buffer(
        ctx.device,
        {
            label = TITLE + " - MVP uniform buffer",
            usage = {.Uniform, .Copy_Dst},
            size = size_of(la.Matrix4f32),
        },
    )
    update_mvp(ctx, 0)
}

init_depth_texture :: proc(ctx: ^app.Application) {
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
    }
    app.depth_stencil_texture_init(
        &state.depth_texture,
        ctx.device,
        {
            format = app.DEFAULT_DEPTH_FORMAT,
            width = ctx.width,
            height = ctx.height,
            sample_count = 1,
        },
    )
}

init_bind_group :: proc(ctx: ^app.Application) {
    state.bind_group_layout = gpu.device_create_bind_group_layout(
        ctx.device,
        {
            label = TITLE + " - Bind group layout",
            entries = {
                {
                    binding = 0,
                    visibility = {.Vertex},
                    type = gpu.Buffer_Binding_Layout {
                        type = .Uniform,
                        has_dynamic_offset = false,
                        min_binding_size = size_of(la.Matrix4f32),
                    },
                },
            },
        },
    )

    state.bind_group = gpu.device_create_bind_group(
        ctx.device,
        {
            label = TITLE + " - Bind group",
            layout = state.bind_group_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = state.uniform_buffer,
                        offset = 0,
                        size = size_of(la.Matrix4f32),
                    },
                },
            },
        },
    )
}

init_pipeline :: proc(ctx: ^app.Application) {
    vert_shader := app.load_shader(ctx.device, #directory, "gltf_cube.vert")
    defer gpu.shader_module_release(vert_shader)
    frag_shader := app.load_shader(ctx.device, #directory, "gltf_cube.frag")
    defer gpu.shader_module_release(frag_shader)

    layout := gpu.device_create_pipeline_layout(
        ctx.device,
        {label = TITLE + " - Pipeline layout", bind_group_layouts = {state.bind_group_layout}},
    )
    defer gpu.pipeline_layout_release(layout)

    depth_stencil := app.create_depth_stencil_state(
        {format = app.DEFAULT_DEPTH_FORMAT, depth_write_enabled = true},
    )
    state.pipeline = gpu.device_create_render_pipeline(
        ctx.device,
        {
            label = TITLE + " - Render pipeline",
            layout = layout,
            vertex = {
                module = vert_shader,
                entry_point = "vs_main",
                buffers = {
                    {
                        array_stride = size_of(Vertex),
                        step_mode = .Vertex,
                        attributes = {
                            {format = .Float32x3, offset = 0, shader_location = 0},
                            {format = .Float32x3, offset = 12, shader_location = 1},
                        },
                    },
                },
            },
            fragment = &gpu.Fragment_State {
                module = frag_shader,
                entry_point = "fs_main",
                targets = {
                    {
                        format = ctx.render_format,
                        blend = &gpu.BLEND_STATE_NORMAL,
                        write_mask = gpu.COLOR_WRITES_ALL,
                    },
                },
            },
            primitive = {topology = .Triangle_List, front_face = .CCW, cull_mode = .None},
            depth_stencil = &depth_stencil,
            multisample = {count = 1, mask = max(u32)},
        },
    )
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    init_gltf_mesh(ctx)
    init_camera(ctx)
    init_depth_texture(ctx)
    init_bind_group(ctx)
    init_pipeline(ctx)

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {}
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.04, 0.06, 0.1, 1},
    }
    state.rpass.descriptor = {
        label                    = TITLE + " - Render pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }
    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update_mvp(ctx, dt)
    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view
    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(pass)

    gpu.render_pass_set_pipeline(pass, state.pipeline)
    gpu.render_pass_set_vertex_buffer(pass, 0, state.vertices, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_index_buffer(pass, state.indices, .Uint32, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_bind_group(pass, 0, state.bind_group)
    gpu.render_pass_draw_indexed(pass, state.index_count, 1, 0, 0, 0)

    gpu.render_pass_end(pass)

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)

    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 {return}
    app.camera_update_aspect_ratio(&state.camera, f32(width) / f32(height))
    init_depth_texture(ctx)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.camera_on_input_event(&state.camera, event)
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
    gpu.buffer_release(state.indices)
    gpu.buffer_release(state.vertices)
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

    app.run(
        app.Application_Descriptor {
            title = TITLE,
            init_cb = init,
            iterate_cb = iterate,
            quit_cb = quit,
            event_cb = event,
        },
    )
}
