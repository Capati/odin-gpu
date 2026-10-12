/*
Example - Cubemap

This example shows how to render and sample from a cubemap texture.

The example uses a simplified approach: instead of rendering a cube geometry, it
draws a fullscreen triangle and uses the inverse view-projection matrix to
compute the cubemap sampling direction in the fragment shader.

This means:

- No vertex buffers needed
- No depth texture needed
- Only 3 vertices drawn instead of 36

Ref:

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/cubemap.c
- https://github.com/webgpu/webgpu-samples/tree/main/sample/cubemap
*/
package cubemap

// Core
import "base:runtime"
import "core:image"
import "core:log"
import "core:math"
import "core:mem"
import "core:time"
import la "core:math/linalg"

import _ "core:image/jpeg"

// Local packages
import "../../gpu"
import app "../framework"

TITLE :: "Cubemap"
FACE_COUNT :: 6

// Texture layers follow WebGPU's cube-view order: +X, -X, +Y, -Y, +Z, -Z.
CUBEMAP_FACE_PATHS :: [FACE_COUNT]string {
    "./assets/textures/cubemaps/bridge2_px.jpg",
    "./assets/textures/cubemaps/bridge2_nx.jpg",
    "./assets/textures/cubemaps/bridge2_py.jpg",
    "./assets/textures/cubemaps/bridge2_ny.jpg",
    "./assets/textures/cubemaps/bridge2_pz.jpg",
    "./assets/textures/cubemaps/bridge2_nz.jpg",
}

State :: struct {
    cubemap: struct {
        texture: gpu.Texture,
        view:    gpu.Texture_View,
        sampler: gpu.Sampler,
    },
    bind_group:        gpu.Bind_Group,
    bind_group_layout: gpu.Bind_Group_Layout,
    uniform_buffer:    gpu.Buffer,
    pipeline:          gpu.Render_Pipeline,
    projection:        la.Matrix4f32,
    model:             la.Matrix4f32,
    inverse_view_projection: la.Matrix4f32,
    start:             time.Tick,

    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_cubemap_texture :: proc(ctx: ^app.Application) {
    ta := context.temp_allocator

    for path, face in CUBEMAP_FACE_PATHS {
        encoded, ok := app.load_file(path, ta)
        assert(ok, "Failed to load cubemap face")

        decoded, err := image.load_from_bytes(encoded, {.alpha_add_if_missing}, ta)
        assert(err == nil, "Failed to decode cubemap face")
        assert(decoded.channels == 4, "Cubemap faces must decode to RGBA")

        if face == 0 {
            state.cubemap.texture = gpu.device_create_texture(ctx.device, {
                label           = TITLE + " - Cubemap texture",
                size            = {u32(decoded.width), u32(decoded.height), FACE_COUNT},
                mip_level_count = 1,
                sample_count    = 1,
                dimension       = .D2,
                format          = .RGBA8_Unorm,
                usage           = {.Texture_Binding, .Copy_Dst},
            })

            state.cubemap.view = gpu.texture_create_view(state.cubemap.texture, {
                format            = .RGBA8_Unorm,
                dimension         = .Cube,
                base_mip_level    = 0,
                mip_level_count   = 1,
                base_array_layer  = 0,
                array_layer_count = FACE_COUNT,
                aspect            = .All,
            })

            state.cubemap.sampler = gpu.device_create_sampler(ctx.device, {
                address_mode_u   = .Clamp_To_Edge,
                address_mode_v   = .Clamp_To_Edge,
                address_mode_w   = .Clamp_To_Edge,
                mag_filter       = .Linear,
                min_filter       = .Linear,
                mipmap_filter    = .Linear,
                lod_min_clamp    = 0,
                lod_max_clamp    = 1,
                compare          = .Undefined,
                anisotropy_clamp = 1,
            })
        } else {
            assert(
                decoded.width == int(gpu.texture_get_width(state.cubemap.texture)) &&
                decoded.height == int(gpu.texture_get_height(state.cubemap.texture)),
                "Cubemap faces must have matching dimensions",
            )
        }

        // Upload one image to the matching array layer.
        gpu.queue_write_texture(
            queue       = ctx.queue,
            destination = {
                texture   = state.cubemap.texture,
                mip_level = 0,
                origin    = {0, 0, u32(face)},
                aspect    = .All,
            },
            data_layout = {
                offset          = 0,
                bytes_per_row   = u32(decoded.width * 4),
                rows_per_image  = u32(decoded.height),
            },
            write_size = {u32(decoded.width), u32(decoded.height), 1},
            data       = gpu.to_bytes(decoded.pixels),
        )
    }
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    state.projection = la.matrix4_perspective_f32(
        2 * math.PI / 5,
        f32(ctx.width) / f32(ctx.height),
        1.0,
        3000.0,
    )
    state.model = la.MATRIX4F32_IDENTITY

    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Inverse view projection - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = size_of(la.Matrix4f32),
    })
}

update_uniform_buffer :: proc(ctx: ^app.Application) {
    elapsed := f32(time.duration_seconds(time.tick_since(state.start)))
    now := elapsed / 0.8

    // Slowly rotate the view, with a small pitch oscillation.
    view := la.MATRIX4F32_IDENTITY
    view = view * la.matrix4_rotate_f32((math.PI / 10) * math.sin(now), {1, 0, 0})
    view = view * la.matrix4_rotate_f32(now * 0.2, {0, 1, 0})

    view_projection := state.projection * view * state.model
    state.inverse_view_projection = la.matrix4_inverse_f32(view_projection)

    gpu.queue_write_buffer(
        queue  = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.inverse_view_projection),
    )
}

init_bind_group_layout :: proc(ctx: ^app.Application) {
    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label = TITLE + " - Bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex, .Fragment},
                type = gpu.Buffer_Binding_Layout{
                    type               = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size   = size_of(la.Matrix4f32),
                },
            },
            {
                binding    = 1,
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout{type = .Filtering},
            },
            {
                binding    = 2,
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout{
                    sample_type    = .Float,
                    view_dimension = .Cube,
                    multisampled   = false,
                },
            },
        },
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Cubemap bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    offset = 0,
                    size   = size_of(la.Matrix4f32),
                },
            },
            {binding = 1, resource = state.cubemap.sampler},
            {binding = 2, resource = state.cubemap.view},
        },
    })
}

init_pipeline :: proc(ctx: ^app.Application) {
    vert_shader := app.load_shader(ctx.device, #directory, "cubemap.vert")
    defer gpu.shader_module_release(vert_shader)
    frag_shader := app.load_shader(ctx.device, #directory, "cubemap.frag")
    defer gpu.shader_module_release(frag_shader)

    layout := gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(layout)

    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render pipeline",
        layout = layout,
        vertex = {
            module      = vert_shader,
            entry_point = "vs_main",
        },
        fragment = &gpu.Fragment_State{
            module      = frag_shader,
            entry_point = "fs_main",
            targets = {
                {
                    format     = ctx.config.format,
                    blend      = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            cull_mode  = .None,
        },
        multisample = {count = 1, mask = max(u32)},
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0.1, 0.2, 0.3, 1.0},
    }
    state.rpass.descriptor = {
        label             = TITLE + " - Render pass",
        color_attachments = state.rpass.colors[:],
    }

    init_cubemap_texture(ctx)
    init_uniform_buffer(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipeline(ctx)
    state.start = time.tick_now()
    update_uniform_buffer(ctx)
    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    frame := app.get_current_frame()
    if frame.skip { return true }
    defer app.release_current_frame(&frame)

    update_uniform_buffer(ctx)
    state.rpass.colors[0].view = frame.view

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(pass)
    gpu.render_pass_set_pipeline(pass, state.pipeline)
    gpu.render_pass_set_bind_group(pass, 0, state.bind_group)
    gpu.render_pass_draw(pass, 3, 1, 0, 0)
    gpu.render_pass_end(pass)

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)
    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)
    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 { return }
    state.projection = la.matrix4_perspective_f32(
        2 * math.PI / 5,
        f32(width) / f32(height),
        1.0,
        3000.0,
    )
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
    gpu.sampler_release(state.cubemap.sampler)
    gpu.texture_view_release(state.cubemap.view)
    gpu.texture_release(state.cubemap.texture)
    gpu.buffer_release(state.uniform_buffer)
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
