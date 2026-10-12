/*
Example - OBJ Model

Loads a Wavefront OBJ model through the `tobj` utility package and renders it
with per-vertex normals and colors. The camera is a framework orbit camera: drag
to orbit, wheel to zoom.
*/
package obj_model

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"

import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"
import "../../utils/tobj"

TITLE :: "OBJ Model"
OBJ_PATH :: "assets/models/pyramid.obj"

My_Uniforms :: struct {
    projection_matrix: la.Matrix4f32,
    view_matrix:       la.Matrix4f32,
    model_matrix:      la.Matrix4f32,
}

Vertex :: struct {
    position: [3]f32,
    normal:   [3]f32,
    color:    [3]f32,
}

State :: struct {
    vertices:          gpu.Buffer,
    vertex_count:      u32,
    uniform_buffer:    gpu.Buffer,
    bind_group_layout: gpu.Bind_Group_Layout,
    bind_group:        gpu.Bind_Group,
    pipeline:          gpu.Render_Pipeline,
    camera:            app.Camera,
    uniforms:          My_Uniforms,
    depth_texture:     app.Depth_Stencil_Texture,
    rpass:             struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

load_geometry_from_obj :: proc() -> (vertices: []Vertex, ok: bool) {
    ta := context.temp_allocator

    obj_bytes, obj_bytes_ok := app.load_file(OBJ_PATH, ta)
    assert(obj_bytes_ok, "failed to load pyramid.obj")

    models, _, _, obj_err := tobj.load_obj_bytes(obj_bytes, allocator = ta)
    assert(obj_err == nil, "failed to parse pyramid.obj")
    assert(len(models) > 0, "pyramid.obj has no models")

    data := make([dynamic]Vertex, ta)
    for &model in models {
        offset := len(data)
        mesh := &model.mesh
        resize(&data, offset + len(mesh.indices))

        // Fill in vertex data for each index.
        for i in 0 ..< len(mesh.indices) {
            idx := mesh.indices[i]

            // Position (Z-up to Y-up so the model stands upright).
            if len(mesh.positions) > 0 {
                data[offset + i].position = {
                    mesh.positions[3 * idx + 0],
                    -mesh.positions[3 * idx + 2],
                    mesh.positions[3 * idx + 1],
                }
            }

            // Normal (same transform as positions).
            if len(mesh.normals) > 0 {
                data[offset + i].normal = {
                    mesh.normals[3 * idx + 0],
                    -mesh.normals[3 * idx + 2],
                    mesh.normals[3 * idx + 1],
                }
            }

            if len(mesh.vertex_color) > 0 {
                data[offset + i].color = {
                    mesh.vertex_color[3 * idx + 0],
                    mesh.vertex_color[3 * idx + 1],
                    mesh.vertex_color[3 * idx + 2],
                }
            } else {
                data[offset + i].color = {1, 1, 1}
            }
        }
    }
    return data[:], true
}

init_geometry :: proc(ctx: ^app.Application) {
    vertices, ok := load_geometry_from_obj()
    assert(ok, "failed to load geometry")
    state.vertex_count = u32(len(vertices))
    assert(state.vertex_count > 0, "pyramid.obj produced no vertices")

    state.vertices = gpu.device_create_buffer_with_data(
        ctx.device,
        {label = TITLE + " - Vertex buffer", usage = {.Vertex, .Copy_Dst}},
        vertices,
    )
}

update_uniforms :: proc(ctx: ^app.Application, dt: f32) {
    app.camera_update(&state.camera, dt)

    state.uniforms.projection_matrix = state.camera.matrices.perspective
    app.camera_projection_matrix_convert_clip_space_near_z(
        &state.uniforms.projection_matrix, .Zero, .Negative_One)
    state.uniforms.view_matrix = state.camera.matrices.view
    // Model stays static; OBJ is Z-up, the camera looks at Y-up.
    state.uniforms.model_matrix = la.matrix4_rotate_f32(-math.PI / 2, {1, 0, 0})

    gpu.queue_write_buffer(
        queue = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data = gpu.to_bytes(state.uniforms),
    )
}

init_camera :: proc(ctx: ^app.Application) {
    app.camera_init(&state.camera)
    state.camera.type = .Look_At
    app.camera_set_position(&state.camera, {0, 0, -2})
    app.camera_set_rotation(&state.camera, {0, -35, 0})
    app.camera_set_perspective(&state.camera, 55, f32(ctx.width) / f32(ctx.height), 0.1, 100)

    state.uniform_buffer = gpu.device_create_buffer(
        ctx.device,
        {
            label = TITLE + " - Uniform buffer",
            usage = {.Uniform, .Copy_Dst},
            size = size_of(My_Uniforms),
        },
    )
    update_uniforms(ctx, 0)
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
                        min_binding_size = size_of(My_Uniforms),
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
                        size = size_of(My_Uniforms),
                    },
                },
            },
        },
    )
}

init_pipeline :: proc(ctx: ^app.Application) {
    vert_shader := app.load_shader(ctx.device, #directory, "obj_model.vert")
    defer gpu.shader_module_release(vert_shader)
    frag_shader := app.load_shader(ctx.device, #directory, "obj_model.frag")
    defer gpu.shader_module_release(frag_shader)

    layout := gpu.device_create_pipeline_layout(ctx.device, {
        label = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(layout)

    depth_stencil := app.create_depth_stencil_state(
        {
            format = app.DEFAULT_DEPTH_FORMAT,
            depth_write_enabled = true,
        },
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
                            {
                                format = .Float32x3,
                                offset = u64(offset_of(Vertex, position)),
                                shader_location = 0,
                            },
                            {
                                format = .Float32x3,
                                offset = u64(offset_of(Vertex, normal)),
                                shader_location = 1,
                            },
                            {
                                format = .Float32x3,
                                offset = u64(offset_of(Vertex, color)),
                                shader_location = 2,
                            },
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

    init_geometry(ctx)
    init_camera(ctx)
    init_depth_texture(ctx)
    init_bind_group(ctx)
    init_pipeline(ctx)

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {}
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.16, 0.16, 0.18, 1},
    }
    state.rpass.descriptor = {
        label                    = TITLE + " - Render pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }
    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update_uniforms(ctx, dt)
    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view
    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(pass)

    gpu.render_pass_set_pipeline(pass, state.pipeline)
    gpu.render_pass_set_bind_group(pass, 0, state.bind_group)
    gpu.render_pass_set_vertex_buffer(pass, 0, state.vertices, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_draw(pass, state.vertex_count, 1, 0, 0)

    gpu.render_pass_end(pass)

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)

    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)

    return true
}

on_resize :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 {return}
    app.camera_update_aspect_ratio(&state.camera, f32(width) / f32(height))
    init_depth_texture(ctx)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.camera_on_input_event(&state.camera, event)
    #partial switch ev in event {
    case app.Resize_Event:
        on_resize(ctx, ev.width, ev.height)
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
