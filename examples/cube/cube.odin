/*
Example - Colored Cube

This example demonstrates how to render a colored cube.
*/
package cube

// Core
import "core:log"
import "core:mem"

import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"

CLIENT_WIDTH    :: 640
CLIENT_HEIGHT   :: 480
EXAMPLE_TITLE   :: "Cube"
DEPTH_FORMAT    :: gpu.Texture_Format.Depth24Plus
COLOR_DARK_GRAY :: gpu.Color{0.6, 0.6, 0.6, 1.0}

State :: struct {
    render_pipeline:   gpu.Render_Pipeline,
    vertex_buffer:     gpu.Buffer,
    uniform_buffer:    gpu.Buffer,
    bind_group:        gpu.Bind_Group,
    bind_group_layout: gpu.Bind_Group_Layout,
    depth_view:        gpu.Texture_View,

    // Cache the render pass descriptor
    rpass: struct {
        colors:                   [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:               gpu.Render_Pass_Descriptor,
    },
}

state: State

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "cube"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = EXAMPLE_TITLE + " Bind Group Layout",
        entries = {
            {
                binding = 0,
                visibility = {.Vertex},
                type = gpu.Buffer_Binding_Layout{
                    type = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size = size_of(la.Matrix4f32),
                },
            },
        },
    })

    pipeline_layout := gpu.device_create_pipeline_layout(ctx.device, {
        label = EXAMPLE_TITLE + " Pipeline Layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(pipeline_layout)

    // Create the triangle pipeline
    state.render_pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label = EXAMPLE_TITLE + " Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        { format = .Float32x3, offset = 0, shader_location = 0 },
                        {
                            format = .Float32x3,
                            offset = u64(offset_of(Vertex, color)),
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
                    blend = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology = .Triangle_List,
            front_face = .CCW,
            cull_mode = .Back,
        },
        // Enable depth testing so that the fragment closest to the camera
        // is rendered in front.
        depth_stencil = &{
            format = DEPTH_FORMAT,
            depth_write_enabled = true,
            depth_compare = .Less,
            stencil = {
                front = {
                    compare = .Always,
                    fail_op = .Keep,
                    depth_fail_op = .Keep,
                    pass_op = .Keep,
                },
                back = {
                    compare = .Always,
                    fail_op = .Keep,
                    depth_fail_op = .Keep,
                    pass_op = .Keep,
                },
                read_mask = max(u32),
                write_mask = max(u32),
            },
        },
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    })
}

init_vertex_buffer :: proc(ctx: ^app.Application) {
    vertex_buffer_desc := gpu.Buffer_Data_Descriptor {
        label = "Cube - Vertex buffer",
        usage = {.Vertex},
    }
    state.vertex_buffer = gpu.device_create_buffer_with_data(
        ctx.device, vertex_buffer_desc, vertex_data)
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    aspect := f32(ctx.config.width) / f32(ctx.config.height)
    mvp_mat := app.create_view_projection_matrix(aspect)

    state.uniform_buffer = gpu.device_create_buffer_with_data(ctx.device,
        {
            label = "Uniform buffer",
            usage = {.Uniform, .Copy_Dst},
        },
        gpu.to_bytes(mvp_mat),
    )

    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    size = gpu.WHOLE_SIZE,
                },
            },
        },
    })
}

init_depth_framebuffer :: proc(ctx: ^app.Application) {
    adapter_features := gpu.adapter_get_features(ctx.adapter)
    format_features :=
        gpu.texture_format_guaranteed_format_features(DEPTH_FORMAT, adapter_features[:])

    // Check if render attachment is supported
    assert(.Render_Attachment in format_features.allowed_usages,
           "Depth format does not support render attachment")

    width, height := app.get_framebuffer_size()

    texture := gpu.device_create_texture(ctx.device, {
        size            = { width, height, 1 },
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = DEPTH_FORMAT,
        usage           = { .Copy_Src, .Copy_Dst, .Render_Attachment },
    })
    defer gpu.texture_release(texture)

    state.depth_view = gpu.texture_create_view(texture)

    // Setup depth stencil attachment
    state.rpass.depth_stencil_attachment = {
        view              = state.depth_view,
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
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    init_pipeline(ctx)
    init_vertex_buffer(ctx)
    init_uniform_buffer(ctx)

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = { .Clear, .Store, COLOR_DARK_GRAY },
    }

    state.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.rpass.depth_stencil_attachment,
    }

    init_depth_framebuffer(ctx)

    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    render_pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(render_pass)

    // Sets the active render pipeline
    gpu.render_pass_set_pipeline(render_pass, state.render_pipeline)
    // Sets the active bind group
    gpu.render_pass_set_bind_group(render_pass, 0, state.bind_group)
    // Bind the vertex buffer (contain position & colors)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, state.vertex_buffer)
    // Draws primitives in the range of vertices
    gpu.render_pass_draw(render_pass, u32(len(vertex_data)), 1, 0, 0)
    // Record the end of the render pass
    gpu.render_pass_end(render_pass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_present(ctx.surface)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    #partial switch ev in event {
        case app.Resize_Event:
            resize(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    gpu.texture_view_release(state.depth_view)
    gpu.bind_group_layout_release(state.bind_group_layout)
    gpu.bind_group_release(state.bind_group)
    gpu.buffer_release(state.uniform_buffer)
    gpu.buffer_release(state.vertex_buffer)
    gpu.render_pipeline_release(state.render_pipeline)
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    gpu.texture_view_release(state.depth_view)
    init_depth_framebuffer(ctx)

    // Update uniform buffer with new aspect ratio
    aspect := f32(width) / f32(height)
    new_matrix := app.create_view_projection_matrix(aspect)
    gpu.queue_write_buffer_bytes(
        ctx.queue, state.uniform_buffer, 0, gpu.to_bytes(new_matrix))
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = { .Level, .Terminal_Color })
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
        title      = EXAMPLE_TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
