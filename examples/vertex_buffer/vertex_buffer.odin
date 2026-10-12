/*
Example - Vertex Buffer

Generates procedural triangle geometry with subdivision and renders it using
a vertex buffer. Shows how to create and upload vertex data to the GPU.
*/
package vertex_buffer

// Core
import "core:log"
import "core:math"
import "core:mem"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Vertex Buffer"
CLIENT_WIDTH :: 1280
CLIENT_HEIGHT :: 720

RECURSION_LIMIT :: 7
MAX_VERTICES    :: 156248

Vec2f :: [2]f32
Vertex :: struct { pos: Vec2f, color: f32 }

State :: struct {
    buffer: gpu.Buffer,
    pipeline: gpu.Render_Pipeline,
    vertices: struct {
        backing: [MAX_VERTICES]Vertex,
        count:   int,
    },
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

avg :: #force_inline proc "contextless" (a, b: Vec2f) -> Vec2f {
    return {(a.x + b.x) * 0.5, (a.y + b.y) * 0.5}
}

avg8 :: #force_inline proc "contextless" (a, b: Vec2f) -> Vec2f {
    return {a.x * 0.8 + b.x * 0.2, a.y * 0.8 + b.y * 0.2}
}

write_vertices :: proc "contextless" (data: [8]Vertex) {
    off := state.vertices.count
    for i in 0 ..< 8 {
        state.vertices.backing[off + i] = data[i]
    }
    state.vertices.count += 8
}

divide :: proc "contextless" (v0, v1, v2: Vec2f, recursion_limit: int) {
    if min(v0.x, v1.x, v2.x) > 1.0 { return }
    if min(v0.y, v1.y, v2.y) > 1.0 { return }
    if max(v0.x, v1.x, v2.x) < -1.0 { return }
    if max(v0.y, v1.y, v2.y) < -1.0 { return }

    w1 := avg(v0, v2)
    w2 := avg8(v1, v2)
    w0 := avg(v2, w2)
    w3 := avg(v0, w2)

    color_fac: f32
    if recursion_limit == 3 {
        color_fac = 0.7
    } else {
        color_fac = 0.4
    }

    COLOR :: proc "contextless" (color_fac: f32, z: Vec2f) -> f32 {
        return color_fac * (z.y * -1.0 + 0.3 + z.x + math.sin(z.x * 5.0) * 0.3)
    }

    data := [8]Vertex{
        {v0, COLOR(color_fac, v0)},
        {w2, COLOR(color_fac, w2)},
        {w2, COLOR(color_fac, w2)},
        {w1, COLOR(color_fac, w1)},
        {w1, COLOR(color_fac, w1)},
        {w0, COLOR(color_fac, w0)},
        {w1, COLOR(color_fac, w1)},
        {w3, COLOR(color_fac, w3)},
    }
    write_vertices(data)

    if recursion_limit - 1 > 0 {
        divide(w2, v1, v0, recursion_limit - 1)
        divide(w3, v0, w1, recursion_limit - 1)
        divide(w3, w2, w1, recursion_limit - 1)
        divide(w0, w1, w2, recursion_limit - 1)
        divide(w0, w1, v2, recursion_limit - 1)
    }
}

create_geometry :: proc(ctx: ^app.Application) {
    v := [3]Vec2f{
        {-4.0, -4.0},
        {-4.0,  4.0},
        {12.0, -4.0},
    }

    viewport_x_scale := f32(ctx.height) / f32(ctx.width)
    scaled := [3]Vec2f{
        {v[0].x * viewport_x_scale, v[0].y},
        {v[1].x * viewport_x_scale, v[1].y},
        {v[2].x * viewport_x_scale, v[2].y},
    }

    divide(scaled[0], scaled[1], scaled[2], RECURSION_LIMIT)

    vertex_data_size := u64(size_of(Vertex)) * u64(state.vertices.count)

    state.buffer = gpu.device_create_buffer(ctx.device, {
        label = "Geometry - " + TITLE,
        usage = {.Copy_Dst, .Vertex},
        size  = vertex_data_size,
    })

    gpu.queue_write_buffer(
        ctx.queue, state.buffer, 0, &state.vertices.backing, uint(vertex_data_size))
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "vertex_buffer"

    // Load shaders
    vert_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader_module)

    frag_shader_module := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader_module)

    vertex_attributes := [2]gpu.Vertex_Attribute{
        {format = .Float32x2, offset = 0, shader_location = 0},
        {format = .Float32,   offset = u64(offset_of(Vertex, color)), shader_location = 1},
    }
    vertex_buffer_layout := gpu.Vertex_Buffer_Layout{
        array_stride = u64(size_of(Vertex)),
        step_mode    = .Vertex,
        attributes   = vertex_attributes[:],
    }
    vertex_buffer_layouts := [1]gpu.Vertex_Buffer_Layout{vertex_buffer_layout}

    rp_desc := gpu.Render_Pipeline_Descriptor{
        label  = "Vertex buffer - Render pipeline",
        vertex = {
            module      = vert_shader_module,
            entry_point = "vs_main",
            buffers     = vertex_buffer_layouts[:],
        },
        fragment = &{
            entry_point = "fs_main",
            module = frag_shader_module,
            targets = {
                {
                    format     = ctx.render_format,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology  = .Line_List,
            front_face = .CCW,
            cull_mode  = .Back,
        },
        multisample = {
            count = 1,
            mask  = max(u32),
        },
    }

    state.pipeline = gpu.device_create_render_pipeline(ctx.device, rp_desc)
    assert(state.pipeline != {})
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = gpu.COLOR_BLACK,
    }

    state.rpass.descriptor = {
        label             = "Render Pass - " + TITLE,
        color_attachments = state.rpass.colors[:],
    }

    create_geometry(ctx)
    init_pipeline(ctx)

    return true
}

quit :: proc(ctx: ^app.Application) {
    gpu.buffer_release(state.buffer)
    gpu.render_pipeline_release(state.pipeline)
}

update :: proc(ctx: ^app.Application, dt: f32) {
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
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.buffer)
    gpu.render_pass_draw(rpass, u32(state.vertices.count), 1, 0, 0)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
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
