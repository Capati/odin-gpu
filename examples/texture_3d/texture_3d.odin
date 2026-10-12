/*
Example - 3D Texture

Demonstrates 3D texture loading and generation using Perlin noise. A 3D noise
texture is procedurally generated on the CPU using fractal Perlin noise and
uploaded to the GPU as a 3D texture. The depth slice through the volume is
animated over time, showing a smoothly changing cross-section of the noise field
rendered on a lit quad.

Features:

- Procedural 3D Perlin noise generation (fractal noise with 6 octaves)
- 3D texture creation and upload (R8Unorm, 128x128x128)
- Animated depth slice through the 3D volume
- Phong lighting (diffuse + specular)
- GUI button to regenerate the noise texture
- Camera interaction (LookAt orbit) via mouse

Ref:

- https://github.com/SaschaWillems/Vulkan/blob/master/examples/texture3d
- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/texture_3d.c
*/
package texture_3d

// Core
import "core:log"
import "core:math"
import "core:mem"
import la "core:math/linalg"

// Local packages
import "../../gpu"
import app "../framework"
import mu "vendor:microui"
import mur "../../utils/microui"

TITLE :: "3D Texture"

NOISE_TEX_WIDTH  :: 128
NOISE_TEX_HEIGHT :: 128
NOISE_TEX_DEPTH  :: 128
NOISE_TEX_SIZE   :: NOISE_TEX_WIDTH * NOISE_TEX_HEIGHT * NOISE_TEX_DEPTH
NOISE_OCTAVES    :: 6
NOISE_PERSISTENCE :: 0.5
NOISE_SCALE      :: 8.0
UI_WINDOW_WIDTH  :: 240

Perlin_Noise :: struct {
    permutations: [512]int,
}

Vertex :: struct {
    position: [3]f32,
    uv:       [2]f32,
    normal:   [3]f32,
}

Uniforms :: struct {
    projection: la.Matrix4f32,
    model_view: la.Matrix4f32,
    view_pos:   [4]f32,
    depth:      f32,
    _padding:   [3]f32,
}

State :: struct {
    // vertex / index buffers
    vertices:       gpu.Buffer,
    indices:        gpu.Buffer,

    // Uniform data
    uniform_buffer: gpu.Buffer,
    texture: struct {
        handle:  gpu.Texture,
        view:    gpu.Texture_View,
        sampler: gpu.Sampler,
    },
    bind_group_layout: gpu.Bind_Group_Layout,
    bind_group:        gpu.Bind_Group,
    pipeline:          gpu.Render_Pipeline,
    camera:            app.Camera,
    uniforms:          Uniforms,
    depth_texture:     app.Depth_Stencil_Texture,
    noise_seed:        u64,
    mu_ctx:            mu.Context,
    mu_renderer:       mur.Renderer,

    // Render pass
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

perlin_fade :: #force_inline proc "contextless" (t: f32) -> f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
}

perlin_lerp :: #force_inline proc "contextless" (t, a, b: f32) -> f32 {
    return a + t * (b - a)
}

perlin_grad :: #force_inline proc "contextless" (hash: int, x, y, z: f32) -> f32 {
    h := hash & 15
    u := x if h < 8 else y
    v := y if h < 4 else (x if h == 12 || h == 14 else z)
    return (u if (h & 1) == 0 else -u) + (v if (h & 2) == 0 else -v)
}

perlin_noise_init :: proc "contextless" (noise: ^Perlin_Noise, seed: u64) {
    lookup: [256]int
    for i in 0..<len(lookup) {
        lookup[i] = i
    }

    // Seeded xorshift + Fisher-Yates keeps this example repeatable.
    rng := seed
    if rng == 0 {
        rng = 1
    }
    for i := len(lookup) - 1; i > 0; i -= 1 {
        rng ~= rng << 13
        rng ~= rng >> 7
        rng ~= rng << 17
        j := int(rng % u64(i + 1))
        lookup[i], lookup[j] = lookup[j], lookup[i]
    }

    for i in 0..<len(lookup) {
        noise.permutations[i] = lookup[i]
        noise.permutations[256 + i] = lookup[i]
    }
}

perlin_noise_sample :: proc "contextless" (noise: ^Perlin_Noise, x, y, z: f32) -> f32 {
    xf, yf, zf := math.floor(x), math.floor(y), math.floor(z)
    X, Y, Z := int(xf) & 255, int(yf) & 255, int(zf) & 255

    x0, y0, z0 := x - xf, y - yf, z - zf

    u, v, w := perlin_fade(x0), perlin_fade(y0), perlin_fade(z0)

    A := noise.permutations[X] + Y
    AA := noise.permutations[A] + Z
    AB := noise.permutations[A + 1] + Z
    B := noise.permutations[X + 1] + Y
    BA := noise.permutations[B] + Z
    BB := noise.permutations[B + 1] + Z

    return perlin_lerp(
        w,
        perlin_lerp(
            v,
            perlin_lerp(
                u,
                perlin_grad(noise.permutations[AA], x0, y0, z0),
                perlin_grad(noise.permutations[BA], x0 - 1, y0, z0),
            ),
            perlin_lerp(
                u,
                perlin_grad(noise.permutations[AB], x0, y0 - 1, z0),
                perlin_grad(noise.permutations[BB], x0 - 1, y0 - 1, z0),
            ),
        ),
        perlin_lerp(
            v,
            perlin_lerp(
                u,
                perlin_grad(noise.permutations[AA + 1], x0, y0, z0 - 1),
                perlin_grad(noise.permutations[BA + 1], x0 - 1, y0, z0 - 1),
            ),
            perlin_lerp(
                u,
                perlin_grad(noise.permutations[AB + 1], x0, y0 - 1, z0 - 1),
                perlin_grad(noise.permutations[BB + 1], x0 - 1, y0 - 1, z0 - 1),
            ),
        ),
    )
}

fractal_noise :: proc "contextless" (noise: ^Perlin_Noise, x, y, z: f32) -> f32 {
    sum: f32 = 0
    frequency: f32 = 1
    amplitude: f32 = 1
    max_value: f32 = 0

    for _ in 0..<NOISE_OCTAVES {
        sum += perlin_noise_sample(noise, x * frequency, y * frequency, z * frequency) * amplitude
        max_value += amplitude
        amplitude *= NOISE_PERSISTENCE
        frequency *= 2
    }

    return (sum / max_value + 1) * 0.5
}

@(optimization_mode="favor_size")
generate_noise_slice :: proc "contextless" (
    noise: ^Perlin_Noise, data: []u8, z: int,
) #no_bounds_check {
    nz := f32(z) / f32(NOISE_TEX_DEPTH) * NOISE_SCALE

    for y in 0..<NOISE_TEX_HEIGHT {
        ny := f32(y) / f32(NOISE_TEX_HEIGHT) * NOISE_SCALE
        row := (z * NOISE_TEX_HEIGHT + y) * NOISE_TEX_WIDTH
        for x in 0..<NOISE_TEX_WIDTH {
            nx := f32(x) / f32(NOISE_TEX_WIDTH) * NOISE_SCALE
            value := fractal_noise(noise, nx, ny, nz)
            data[row + x] = u8(clamp(value, 0, 1) * 255)
        }
    }
}

generate_noise_texture :: proc(ctx: ^app.Application, seed: u64) {
    data := make([]u8, NOISE_TEX_SIZE, context.allocator)
    defer delete(data)

    noise: Perlin_Noise
    perlin_noise_init(&noise, seed)
    generate_noise_texture_data(&noise, data)

    gpu.queue_write_texture(
        queue       = ctx.queue,
        destination = {
            texture   = state.texture.handle,
            mip_level = 0,
            origin    = {},
            aspect    = .All,
        },
        data_layout = {
            offset          = 0,
            bytes_per_row   = NOISE_TEX_WIDTH,
            rows_per_image  = NOISE_TEX_HEIGHT,
        },
        write_size = {NOISE_TEX_WIDTH, NOISE_TEX_HEIGHT, NOISE_TEX_DEPTH},
        data       = data,
    )
}

init_geometry :: proc(ctx: ^app.Application) {
    vertices := [4]Vertex{
        {{ 1,  1, 0}, {1, 0}, {0, 0, 1}},
        {{-1,  1, 0}, {0, 0}, {0, 0, 1}},
        {{-1, -1, 0}, {0, 1}, {0, 0, 1}},
        {{ 1, -1, 0}, {1, 1}, {0, 0, 1}},
    }
    indices := [6]u32{0, 1, 2, 2, 3, 0}

    state.vertices = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, vertices[:])
    state.indices = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Index buffer",
        usage = {.Index, .Copy_Dst},
    }, indices[:])
}

init_noise_texture :: proc(ctx: ^app.Application) {
    state.texture.handle = gpu.device_create_texture(ctx.device, {
        label           = TITLE + " - Perlin noise volume",
        size            = {NOISE_TEX_WIDTH, NOISE_TEX_HEIGHT, NOISE_TEX_DEPTH},
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D3,
        format          = .R8_Unorm,
        usage           = {.Texture_Binding, .Copy_Dst},
    })
    state.texture.view = gpu.texture_create_view(state.texture.handle, {
        format            = .R8_Unorm,
        dimension         = .D3,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .All,
    })
    state.texture.sampler = gpu.device_create_sampler(ctx.device, {
        address_mode_u   = .Clamp_To_Edge,
        address_mode_v   = .Clamp_To_Edge,
        address_mode_w   = .Clamp_To_Edge,
        mag_filter       = .Linear,
        min_filter       = .Linear,
        mipmap_filter    = .Nearest,
        lod_min_clamp    = 0,
        lod_max_clamp    = 1,
        compare          = .Undefined,
        anisotropy_clamp = 1,
    })
    generate_noise_texture(ctx, state.noise_seed)
}

init_microui :: proc(ctx: ^app.Application) {
    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device = ctx.device,
        target_format = ctx.render_format,
        depth_stencil_format = state.depth_texture.format,
        pipeline_multisample_state = gpu.DEFAULT_MULTISAMPLE_STATE,
    })
    mur.resize(&state.mu_renderer, ctx.width, ctx.height)
}

init_camera :: proc(ctx: ^app.Application) {
    app.camera_init(&state.camera)
    state.camera.type = .Look_At
    app.camera_set_position(&state.camera, {0, 0, -2.5})
    app.camera_set_rotation(&state.camera, {0, 15, 0})
    app.camera_set_perspective(
        &state.camera,
        60,
        f32(ctx.width) / f32(ctx.height),
        0.1,
        256,
    )
}

update_projection :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 { return }
    app.camera_update_aspect_ratio(&state.camera, f32(width) / f32(height))
    state.uniforms.projection = state.camera.matrices.perspective
    app.camera_projection_matrix_convert_clip_space_near_z(
        &state.uniforms.projection,
        .Zero,
        .Negative_One,
    )
}

update_uniform_buffer :: proc(ctx: ^app.Application, dt: f32) {
    app.camera_update(&state.camera, dt)
    state.uniforms.model_view = state.camera.matrices.view
    state.uniforms.view_pos = state.camera.view_pos
    state.uniforms.depth += dt * 0.15
    if state.uniforms.depth > 1 {
        state.uniforms.depth -= 1
    }

    gpu.queue_write_buffer(
        queue  = ctx.queue,
        buffer = state.uniform_buffer,
        offset = 0,
        data   = gpu.to_bytes(state.uniforms),
    )
}

init_uniform_buffer :: proc(ctx: ^app.Application) {
    update_projection(ctx, ctx.width, ctx.height)
    state.uniforms.depth = 0
    state.uniform_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Uniform buffer",
        usage = {.Uniform, .Copy_Dst},
        size  = size_of(Uniforms),
    })
    update_uniform_buffer(ctx, 0)
}

init_depth_texture :: proc(ctx: ^app.Application) {
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
    }
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format       = app.DEFAULT_DEPTH_FORMAT,
        width        = ctx.width,
        height       = ctx.height,
        sample_count = 1,
    })
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
                    min_binding_size   = size_of(Uniforms),
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
                    view_dimension = .D3,
                    multisampled   = false,
                },
            },
        },
    })
}

init_bind_group :: proc(ctx: ^app.Application) {
    state.bind_group = gpu.device_create_bind_group(ctx.device, {
        label  = TITLE + " - Bind group",
        layout = state.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = state.uniform_buffer,
                    offset = 0,
                    size   = size_of(Uniforms),
                },
            },
            {binding = 1, resource = state.texture.sampler},
            {binding = 2, resource = state.texture.view},
        },
    })
}

init_pipeline :: proc(ctx: ^app.Application) {
    vert_shader := app.load_shader(ctx.device, #directory, "texture_3d.vert")
    defer gpu.shader_module_release(vert_shader)
    frag_shader := app.load_shader(ctx.device, #directory, "texture_3d.frag")
    defer gpu.shader_module_release(frag_shader)

    layout := gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })
    defer gpu.pipeline_layout_release(layout)

    depth_stencil := app.create_depth_stencil_state({
        format              = app.DEFAULT_DEPTH_FORMAT,
        depth_write_enabled = true,
    })
    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render pipeline",
        layout = layout,
        vertex = {
            module      = vert_shader,
            entry_point = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode    = .Vertex,
                    attributes = {
                        {format = .Float32x3, offset = 0, shader_location = 0},
                        {format = .Float32x2, offset = 12, shader_location = 1},
                        {format = .Float32x3, offset = 20, shader_location = 2},
                    },
                },
            },
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
        depth_stencil = &depth_stencil,
        multisample   = {count = 1, mask = max(u32)},
    })
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.noise_seed = 0xC0B3_5EED

    update_projection(ctx, ctx.width, ctx.height)
    init_camera(ctx)
    init_geometry(ctx)
    init_noise_texture(ctx)
    init_uniform_buffer(ctx)
    init_depth_texture(ctx)
    init_bind_group_layout(ctx)
    init_bind_group(ctx)
    init_pipeline(ctx)
    init_microui(ctx)

    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {}
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0, 0, 0, 1},
    }
    state.rpass.descriptor = {
        label                     = TITLE + " - Render pass",
        color_attachments         = state.rpass.colors[:],
        depth_stencil_attachment  = &state.depth_texture.descriptor,
    }

    return true
}

update :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        mu.layout_row(&state.mu_ctx, {-1}, 0)
        if .SUBMIT in mu.button(&state.mu_ctx, "Generate new texture") {
            state.noise_seed += 1
            generate_noise_texture(ctx, state.noise_seed)
        }
    }
    mu.end(&state.mu_ctx)

    update_uniform_buffer(ctx, dt)
    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt) or_return

    frame := app.get_current_frame()
    if frame.skip { return true }
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
    gpu.render_pass_draw_indexed(pass, 6, 1, 0, 0, 0)
    mur.render(&state.mu_renderer, &state.mu_ctx, pass)

    gpu.render_pass_end(pass)

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)

    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)

    return true
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    if height == 0 { return }
    update_projection(ctx, width, height)
    init_depth_texture(ctx)
    mur.resize(&state.mu_renderer, width, height)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.mu_handle_events(&state.mu_ctx, event)
    if !app.mu_wants_mouse(&state.mu_ctx) {
        app.camera_on_input_event(&state.camera, event)
    }
    #partial switch ev in event {
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
    gpu.render_pipeline_release(state.pipeline)
    gpu.bind_group_release(state.bind_group)
    gpu.bind_group_layout_release(state.bind_group_layout)
    app.depth_stencil_texture_uninit(&state.depth_texture)
    gpu.sampler_release(state.texture.sampler)
    gpu.texture_view_release(state.texture.view)
    gpu.texture_release(state.texture.handle)
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

    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
