/*
Example - Stencil Triangles

This example renders two different sized triangles to display three same sized
triangles, by demonstrating the use of stencil buffers.

First it draws a small "mask" triangle, which sets the stencil buffer at every
pixel to 1.

Then, it draws a larger "outer" triangle which only touches pixels where the
stencil buffer is less than 1.
*/
package stencil_triangles

// Core
import "core:log"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE         :: "Stencil Triangles"
CLIENT_WIDTH  :: 640
CLIENT_HEIGHT :: 480

STENCIL_FORMAT :: gpu.Texture_Format.Stencil8

State :: struct {
    outer_vertex_buffer: gpu.Buffer,
    mask_vertex_buffer:  gpu.Buffer,
    outer_pipeline:      gpu.Render_Pipeline,
    mask_pipeline:       gpu.Render_Pipeline,
    depth_view:          gpu.Texture_View,

    // Cache the render pass descriptor
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        depth:      gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_vertex_buffer :: proc(ctx: ^app.Application) {
    outer_vertices := []Vertex{vertex(-1.0, -1.0), vertex(1.0, -1.0), vertex(0.0, 1.0)}
    vertex_buffer_desc := gpu.Buffer_Data_Descriptor {
        label = "Colored cube - Vertex buffer",
        usage = {.Vertex},
    }
    state.outer_vertex_buffer = gpu.device_create_buffer_with_data(
        ctx.device, vertex_buffer_desc, outer_vertices)

    mask_vertices := []Vertex{vertex(-0.5, 0.0), vertex(0.0, -1.0), vertex(0.5, 0.0)}
    mask_vertex_buffer_desc := gpu.Buffer_Data_Descriptor {
        label = "Mask Vertex Buffer",
        usage = {.Vertex},
    }
    state.mask_vertex_buffer = gpu.device_create_buffer_with_data(
        ctx.device, mask_vertex_buffer_desc, mask_vertices)
}

Vertex :: struct {
    pos: [4]f32,
}

vertex :: proc(x, y: f32) -> Vertex {
    return {pos = {x, y, 0.0, 1.0}}
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "stencil_triangles"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    // Vertex layout
    vertex_buffers := [1]gpu.Vertex_Buffer_Layout{{
        array_stride = size_of(Vertex),
        step_mode    = .Vertex,
        attributes   = {
            {
                format = .Float32x4,
                offset = 0,
                shader_location = 0,
            },
        },
    }}

    // Common pipeline state with base depth-stencil for stencil masking (writes
    // stencil, ignores depth)
    depth_stencil_state := gpu.Depth_Stencil_State{
        format = STENCIL_FORMAT,
        depth_write_enabled = false,
        depth_compare = .Always,
        stencil = {
            front = {
                compare = .Always,
                fail_op = .Keep,
                depth_fail_op = .Keep,
                pass_op = .Replace,  // Write stencil value on every fragment
            },
            back = gpu.STENCIL_FACE_STATE_IGNORE,
            read_mask = max(u32),
            write_mask = max(u32),
        },
    }

    // Fragment state with no color writes (mask pass only writes stencil)
    fragment_state := gpu.Fragment_State{
        module = frag_shader_module,
        entry_point = "fs_main",
        targets = {{
            format = ctx.config.format,
            write_mask = {}, // No color output
        }},
    }

    // Base pipeline descriptor (shared between both pipelines)
    pipeline_descriptor := gpu.Render_Pipeline_Descriptor{
        label = TITLE + " Render Pipeline",
        vertex = {
            module = vert_shader_module,
            entry_point = "vs_main",
            buffers = vertex_buffers[:],
        },
        fragment = &fragment_state,
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .Back,
        },
        depth_stencil = &depth_stencil_state,
        multisample = gpu.DEFAULT_MULTISAMPLE_STATE,
    }

    // Pipeline 1 (Mask)
    //
    // Writes stencil values to mark regions, renders nothing to color

    pipeline_descriptor.label = "Mask Pipeline"
    state.mask_pipeline = gpu.device_create_render_pipeline(ctx.device, pipeline_descriptor)

    // Pipeline 2 (Outer)
    //
    // Renders color only where stencil doesn't match (masked regions)

    // Modify depth-stencil: read stencil, but don't write to it
    depth_stencil_state.stencil.front.compare = .Not_Equal  // Render where stencil != reference
    depth_stencil_state.stencil.write_mask = 0              // Prevent overwriting stencil

    // Modify fragment: enable color writes
    fragment_state.targets[0].write_mask = gpu.COLOR_WRITES_ALL

    // Update descriptor and create pipeline
    pipeline_descriptor.label = "Outer Pipeline"
    pipeline_descriptor.depth_stencil = &depth_stencil_state
    pipeline_descriptor.fragment = &fragment_state

    state.outer_pipeline = gpu.device_create_render_pipeline(ctx.device, pipeline_descriptor)
}

init_stencil_buffer :: proc(ctx: ^app.Application, width, height: u32) {
    stencil_texture := gpu.device_create_texture(ctx.device, {
        label = "Stencil buffer",
        size = {
            width = width,
            height = height,
            depth_or_array_layers = 1,
        },
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = STENCIL_FORMAT,
        usage           = {.Render_Attachment},
    })
    defer gpu.texture_release(stencil_texture)

    state.depth_view = gpu.texture_create_view(stencil_texture, {
        format            = STENCIL_FORMAT,
        dimension         = .D2,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .Stencil_Only,
    })

    state.rpass.depth = {
        view = state.depth_view,
        depth_ops = {
            clear_value = 1.0,
        },
        stencil_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 0.0,
        },
    }

    state.rpass.descriptor.depth_stencil_attachment = &state.rpass.depth
}

recreate_stencil_buffer :: proc(ctx: ^app.Application, width, height: u32) {
    destroy_stencil_buffer(ctx)
    init_stencil_buffer(ctx, width, height)
}

destroy_stencil_buffer :: proc(ctx: ^app.Application) {
    gpu.texture_view_release(state.depth_view)
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    init_vertex_buffer(ctx)
    init_pipeline(ctx)

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, { 0.1, 0.2, 0.3, 1.0 }},
    }

    state.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = nil, // Assigned later
    }

    init_stencil_buffer(ctx, ctx.config.width, ctx.config.height)

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

    gpu.render_pass_set_stencil_reference(render_pass, 1)

    gpu.render_pass_set_pipeline(render_pass, state.mask_pipeline)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, state.mask_vertex_buffer)
    gpu.render_pass_draw(render_pass, 3, 1, 0, 0)

    gpu.render_pass_set_pipeline(render_pass, state.outer_pipeline)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, state.outer_vertex_buffer)
    gpu.render_pass_draw(render_pass, 3, 1, 0, 0)

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
        recreate_stencil_buffer(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    destroy_stencil_buffer(ctx)
    gpu.render_pipeline_release(state.outer_pipeline)
    gpu.render_pipeline_release(state.mask_pipeline)
    gpu.buffer_release(state.mask_vertex_buffer)
    gpu.buffer_release(state.outer_vertex_buffer)
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
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
