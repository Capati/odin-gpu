/*
Example - Fractal Cube

Renders a rotating cube that samples the previous frame, producing a fractal
feedback effect.
*/
package fractal_cube

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"
import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Fractal Cube"

State :: struct {
    vertex_buffer:      gpu.Buffer,
    index_buffer:       gpu.Buffer,
    render_pipeline:    gpu.Render_Pipeline,
    uniform_buffer:     gpu.Buffer,
    bind_group_layout:  gpu.Bind_Group_Layout,
    bind_group:         gpu.Bind_Group,
    projection_matrix:  la.Matrix4f32,
    depth_texture:      app.Depth_Stencil_Texture,

    // Centered square-crop factors for the full-frame feedback texture.
    // (1,1) at square windows; shrinks U when wider than tall and V when
    // taller than wide so faces stay undistorted.
    uv_scale:           [2]f32,

    // The frame's rendering results are copied into this texture and sampled
    // on the next frame.
    cube_texture:       gpu.Texture,
    cube_view:          gpu.Texture_View,
    sampler:            gpu.Sampler,

    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    state.vertex_buffer = gpu.device_create_buffer_with_data(
        ctx.device,
        {
            label = TITLE + " - Vertex Data",
            usage = {.Vertex, .Copy_Dst},
        },
        gpu.to_bytes(CUBE_VERTEX_DATA),
    )

    state.index_buffer = gpu.device_create_buffer_with_data(
        ctx.device,
        {
            label = TITLE + " - Index Buffer",
            usage = {.Index, .Copy_Dst},
        },
        gpu.to_bytes(CUBE_INDICES_DATA),
    )

    vertex_buffer_layout := gpu.Vertex_Buffer_Layout {
        array_stride = size_of(Vertex),
        step_mode    = .Vertex,
        attributes   = {
            {format = .Float32x4, offset = 0, shader_location = 0},
            {
                format = .Float32x2,
                offset = u64(offset_of(Vertex, tex_coords)),
                shader_location = 1,
            },
        },
    }

    vert_shader := app.load_shader(ctx.device, #directory, "fractal_cube.vert")
    defer gpu.shader_module_release(vert_shader)
    frag_shader := app.load_shader(ctx.device, #directory, "fractal_cube.frag")
    defer gpu.shader_module_release(frag_shader)

    state.bind_group_layout = gpu.device_create_bind_group_layout(
        ctx.device,
        {
            label = TITLE + " - Bind Group Layout",
            entries = {
                {
                    binding = 0,
                    visibility = {.Vertex, .Fragment},
                    type = gpu.Buffer_Binding_Layout {
                        type = .Uniform,
                        has_dynamic_offset = false,
                        min_binding_size = size_of(Fractal_Uniforms),
                    },
                },
                {
                    binding = 1,
                    visibility = {.Fragment},
                    type = gpu.Texture_Binding_Layout {
                        sample_type = .Float,
                        view_dimension = .D2,
                        multisampled = false,
                    },
                },
                {
                    binding = 2,
                    visibility = {.Fragment},
                    type = gpu.Sampler_Binding_Layout {
                        type = .Filtering,
                    },
                },
            },
        },
    )

    layout := gpu.device_create_pipeline_layout(
        ctx.device,
        {label = TITLE + " - Pipeline Layout", bind_group_layouts = {state.bind_group_layout}},
    )
    defer gpu.pipeline_layout_release(layout)

    depth_stencil := app.create_depth_stencil_state(
        {format = app.DEFAULT_DEPTH_FORMAT, depth_write_enabled = true, depth_compare = .Less},
    )
    state.render_pipeline = gpu.device_create_render_pipeline(
        ctx.device,
        {
            label = TITLE + " - Render Pipeline",
            layout = layout,
            vertex = {
                module = vert_shader,
                entry_point = "vs_main",
                buffers = {vertex_buffer_layout},
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
            primitive = {
                topology   = .Triangle_List,
                front_face = .CCW,
                // Backface culling since the cube is solid piece of geometry.
                // Faces pointing away from the camera will be occluded by faces
                // pointing toward the camera.
                cull_mode  = .Back,
            },
            // Enable depth testing so that the fragment closest to the camera
            // is rendered in front.
            depth_stencil = &depth_stencil,
            multisample = {count = 1, mask = max(u32)},
        },
    )

    state.uniform_buffer = gpu.device_create_buffer(
        ctx.device,
        {
            label = TITLE + " - Uniform Buffer",
            size  = size_of(Fractal_Uniforms),
            usage = {.Uniform, .Copy_Dst},
        },
    )
    update_uv_scale(ctx)

    create_cube_texture(ctx, ctx.width, ctx.height)

    sampler_descriptor := gpu.DEFAULT_SAMPLER_DESCRIPTOR
    sampler_descriptor.mag_filter = .Linear
    sampler_descriptor.min_filter = .Linear
    state.sampler = gpu.device_create_sampler(ctx.device, sampler_descriptor)

    create_fractal_bind_group(ctx)

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {}
    state.rpass.colors[0].ops = {
        load  = .Clear,
        store = .Store,
        // The clear color serves as the initial background and seed for the
        // fractal generation. The mid-gray value (0.5, 0.5, 0.5) provides a
        // neutral starting point for the fractal algorithm. In the fractal
        // shader, values near 0.5 can significantly influence the initial
        // pattern generation. The specific threshold of 0.01 used in the
        // shader depends on this base gray color. Changing this value can
        // dramatically alter the initial fractal distribution and appearance.
        clear_value = {0.5, 0.5, 0.5, 1},
    }
    state.rpass.descriptor = {
        label                    = TITLE + " - Render pass",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }

    init_depth_texture(ctx)
    set_projection_matrix(ctx, ctx.width, ctx.height)
    return true
}

// Mirrors the `Uniforms` block in shaders/fractal_cube.slang (std140:
// mat4 + vec2 + trailing pad).
Fractal_Uniforms :: struct {
    transform: la.Matrix4f32,
    uv_scale:  [2]f32,
    _pad:      [2]f32,
}

compute_uv_scale :: proc(width, height: u32) -> [2]f32 {
    if width == 0 || height == 0 {
        return {1, 1}
    }
    w, h := f32(width), f32(height)
    if w >= h {
        return {h / w, 1}
    }
    return {1, w / h}
}

update_uv_scale :: proc(ctx: ^app.Application) {
    state.uv_scale = compute_uv_scale(ctx.width, ctx.height)
    gpu.queue_write_buffer(
        queue = ctx.queue,
        buffer = state.uniform_buffer,
        offset = u64(offset_of(Fractal_Uniforms, uv_scale)),
        data = gpu.to_bytes(state.uv_scale),
    )
}

create_cube_texture :: proc(ctx: ^app.Application, width, height: u32) {
    state.cube_texture = gpu.device_create_texture(
        ctx.device,
        {
            label = "Fractal Cube Texture",
            usage = {.Texture_Binding, .Copy_Dst, .Render_Attachment},
            format = ctx.render_format,
            dimension = .D2,
            mip_level_count = 1,
            sample_count = 1,
            size = {
                width = width,
                height = height,
                depth_or_array_layers = 1,
            },
        },
    )

    state.cube_view = gpu.texture_create_view(
        state.cube_texture,
        {
            format            = ctx.render_format,
            dimension         = .D2,
            base_mip_level    = 0,
            mip_level_count   = 1,
            base_array_layer  = 0,
            array_layer_count = 1,
            aspect            = .All,
        },
    )
}

recreate_cube_texture :: proc(ctx: ^app.Application, width, height: u32) {
    destroy_cube_texture()
    create_cube_texture(ctx, width, height)
}

destroy_cube_texture :: proc() {
    if state.cube_texture != {} {
        gpu.texture_release(state.cube_texture)
    }
    if state.cube_view != {} {
        gpu.texture_view_release(state.cube_view)
    }
}

create_fractal_bind_group :: proc(ctx: ^app.Application) {
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
                        size = gpu.buffer_get_size(state.uniform_buffer),
                    },
                },
                {
                    binding = 1,
                    resource = state.cube_view,
                },
                {
                    binding = 2,
                    resource = state.sampler,
                },
            },
        },
    )
}

recreate_fractal_bind_group :: proc(ctx: ^app.Application) {
    if state.bind_group != {} {
        gpu.bind_group_release(state.bind_group)
    }
    create_fractal_bind_group(ctx)
}

update :: proc(ctx: ^app.Application) {
    transformation_matrix := get_transformation_matrix()
    gpu.queue_write_buffer(
        queue = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data = gpu.to_bytes(transformation_matrix),
    )
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx)

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(pass)

    gpu.render_pass_set_pipeline(pass, state.render_pipeline)
    gpu.render_pass_set_bind_group(pass, 0, state.bind_group)
    gpu.render_pass_set_vertex_buffer(pass, 0, state.vertex_buffer, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_set_index_buffer(pass, state.index_buffer, .Uint16, 0, gpu.WHOLE_SIZE)
    gpu.render_pass_draw_indexed(pass, u32(len(CUBE_INDICES_DATA)), 1, 0, 0, 0)

    gpu.render_pass_end(pass)

    copy_size := gpu.texture_get_size(frame.texture)

    // Copy the rendering results from the swapchain into `cube_texture`.
    gpu.command_encoder_copy_texture_to_texture(
        encoder,
        {texture = frame.texture, mip_level = 0, origin = {}, aspect = .All},
        {texture = state.cube_texture, mip_level = 0, origin = {}, aspect = .All},
        {copy_size.width, copy_size.height, 1},
    )

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)

    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    #partial switch ev in event {
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    case:
    }
}

quit :: proc(ctx: ^app.Application) {
    app.depth_stencil_texture_uninit(&state.depth_texture)

    gpu.bind_group_release(state.bind_group)
    gpu.sampler_release(state.sampler)

    destroy_cube_texture()

    gpu.bind_group_layout_release(state.bind_group_layout)
    gpu.buffer_release(state.uniform_buffer)
    gpu.render_pipeline_release(state.render_pipeline)
    gpu.buffer_release(state.index_buffer)
    gpu.buffer_release(state.vertex_buffer)
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 {return}
    init_depth_texture(ctx)
    recreate_cube_texture(ctx, width, height)
    set_projection_matrix(ctx, width, height)
    update_uv_scale(ctx)
    recreate_fractal_bind_group(ctx)
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

set_projection_matrix :: proc(ctx: ^app.Application, width, height: u32) {
    aspect := f32(width) / f32(height)
    state.projection_matrix = la.matrix4_perspective_f32(2 * math.PI / 5, aspect, 1, 100)
    app.camera_projection_matrix_convert_clip_space_near_z(&state.projection_matrix, .Zero, .Negative_One)
}

get_transformation_matrix :: proc() -> (mvp_mat: la.Matrix4f32) {
    view := la.MATRIX4F32_IDENTITY

    // Translate
    view = view * la.matrix4_translate_f32({0, 0, -4})

    // Rotate
    now := f32(app.get_time())
    view = view * la.matrix4_rotate_f32(1.0, {math.sin(now), math.cos(now), 0})

    // Multiply projection and view matrices
    mvp_mat = state.projection_matrix * view
    return
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
