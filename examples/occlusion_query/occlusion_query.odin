/*
Example - Occlusion Query

Six coloured cubes orbit a common centre. Each cube is drawn inside its own
occlusion query, and the results are resolved and read back to report which cubes
are actually visible this frame.

Occlusion queries count the fragments that pass the depth test, so a cube hidden
behind another reports zero even though it was submitted. This is the standard
building block for GPU-driven visibility culling.

This is the second `Query_Set` example. Unlike `timestamp_query`, which measures a
render pass from outside, this one scopes a query *inside* a pass, around a draw:

- `device_create_query_set` with `Query_Type.Occlusion`
- `Render_Pass_Descriptor.occlusion_query_set`
- `render_pass_begin_occlusion_query` / `render_pass_end_occlusion_query`
- `command_encoder_resolve_query_set` + map, to read the counts back

Ref:

- https://webgpu/webgpu-samples/tree/main/src/sample/occlusionQuery
*/
package occlusion_query

// Core
import "core:fmt"
import "core:math"
import "core:math/linalg"

// Vendor
import mu "vendor:microui"

// Local packages
import "../../gpu"
import app "../framework"
import mur "../../utils/microui"

TITLE :: "Occlusion Query"

// Side of each visible-cube colour swatch in the settings panel.
SWATCH_SIZE :: 28

// Fixed panel width. The swatch row is packed tight to the left inside it; the
// width does not follow how many cubes happen to be visible.
UI_WINDOW_WIDTH :: SWATCH_SIZE * CUBE_COUNT + 8 * 2

DEPTH_FORMAT :: app.DEFAULT_DEPTH_FORMAT

// One cube per cardinal offset on the three axes.
CUBE_COUNT :: 6

// Query results are 8 bytes each, and the buffer holding them needs
// `Query_Resolve`; the copy destination needs `Map_Read` and `Copy_Dst`.
QUERY_RESULT_SIZE :: 8
RESULT_COUNT :: CUBE_COUNT
RESOLVE_SIZE :: u64(RESULT_COUNT * QUERY_RESULT_SIZE)

// Orbit radius and cube half-extent, in world units.
ORBIT_RADIUS :: 10.0
CUBE_EXTENT :: 1.0

// Camera distance range, matching the reference sample: the eye dollies between
// these, which is what eventually brings all six cubes into view. A fixed close
// distance clips the ones behind the eye, so only four ever show.
CAMERA_NEAR :: 5.0
CAMERA_FAR :: 40.0

// Scales every animated quantity, so the whole camera move slows or speeds up
// together. 0.7 is noticeably gentler than the reference sample's pace.
ANIMATION_SPEED :: 0.7

// Values shared with the shader; must match `Uniforms`.
Uniforms :: struct #align(16) {
    world_view_projection: linalg.Matrix4x4f32,
    world:                 linalg.Matrix4x4f32,
    color:                 [4]f32,
}

Vertex :: struct {
    position: [3]f32,
    normal:   [3]f32,
}

// A cube's per-frame state: where it orbits, and the query slot it owns.
Object :: struct {
    color:           [4]f32,
    direction:       linalg.Vector3f32,
    uniforms:        Uniforms,
    uniform_buffer:  gpu.Buffer,
    bind_group:      gpu.Bind_Group,
    // Last resolved fragment count: 0 means fully occluded this frame.
    visible_fragments: u64,
}

State :: struct {
    objects:        [CUBE_COUNT]Object,
    vertex_buffer:  gpu.Buffer,
    index_buffer:   gpu.Buffer,
    index_count:    u32,

    bind_group_layout: gpu.Bind_Group_Layout,
    pipeline_layout:   gpu.Pipeline_Layout,
    pipeline:          gpu.Render_Pipeline,

    // Occlusion queries, one slot per cube.
    query_set:       gpu.Query_Set,
    resolve_buffer:  gpu.Buffer,
    readback_buffer: gpu.Buffer,
    supported:       bool,

    // Animation clock, in seconds. Drives the camera rotation and dolly.
    time:            f32,
    animation:       bool,
    // Number of cubes whose last resolved query reported fragments.
    visible_count:   int,

    depth_texture:   app.Depth_Stencil_Texture,

    mu_ctx:          mu.Context,
    mu_renderer:     mur.Renderer,

    // Cache the render pass descriptor
    rpass:           struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

// A unit cube centred on the origin, 24 vertices (4 per face) so each face has a
// flat normal, with 36 indices.
@(rodata)
CUBE_VERTICES := [24]Vertex {
    {{ 1,  1, -1}, { 1,  0,  0}}, {{ 1,  1,  1}, { 1,  0,  0}},
    {{ 1, -1,  1}, { 1,  0,  0}}, {{ 1, -1, -1}, { 1,  0,  0}},
    {{-1,  1,  1}, {-1,  0,  0}}, {{-1,  1, -1}, {-1,  0,  0}},
    {{-1, -1, -1}, {-1,  0,  0}}, {{-1, -1,  1}, {-1,  0,  0}},
    {{-1,  1,  1}, { 0,  1,  0}}, {{ 1,  1,  1}, { 0,  1,  0}},
    {{ 1,  1, -1}, { 0,  1,  0}}, {{-1,  1, -1}, { 0,  1,  0}},
    {{-1, -1, -1}, { 0, -1,  0}}, {{ 1, -1, -1}, { 0, -1,  0}},
    {{ 1, -1,  1}, { 0, -1,  0}}, {{-1, -1,  1}, { 0, -1,  0}},
    {{ 1,  1,  1}, { 0,  0,  1}}, {{-1,  1,  1}, { 0,  0,  1}},
    {{-1, -1,  1}, { 0,  0,  1}}, {{ 1, -1,  1}, { 0,  0,  1}},
    {{-1,  1, -1}, { 0,  0, -1}}, {{ 1,  1, -1}, { 0,  0, -1}},
    {{ 1, -1, -1}, { 0,  0, -1}}, {{-1, -1, -1}, { 0,  0, -1}},
}

@(rodata)
CUBE_INDICES := [36]u16 {
    0,  1,  2,  0,  2,  3, // +x
    4,  5,  6,  4,  6,  7, // -x
    8,  9, 10,  8, 10, 11, // +y
    12, 13, 14, 12, 14, 15, // -y
    16, 17, 18, 16, 18, 19, // +z
    20, 21, 22, 20, 22, 23, // -z
}

init_query_resources :: proc(ctx: ^app.Application) {
    // Occlusion queries are core WebGPU, unlike timestamps: no feature gate.
    state.supported = true

    state.query_set = gpu.device_create_query_set(ctx.device, {
        label = TITLE + " - Occlusion query set",
        type  = .Occlusion,
        count = RESULT_COUNT,
    })
    assert(state.query_set != {}, "failed to create the occlusion query set")

    state.resolve_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Resolve buffer",
        usage = {.Query_Resolve, .Copy_Src},
        size  = RESOLVE_SIZE,
    })

    // Result buffers must be a multiple of 4 in size; the resolve destination
    // offset must be 256-aligned, which `0` satisfies.
    state.readback_buffer = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Readback buffer",
        usage = {.Map_Read, .Copy_Dst},
        size  = RESOLVE_SIZE,
    })
}

init_geometry :: proc(ctx: ^app.Application) {
    state.vertex_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Cube vertex buffer",
        usage = {.Vertex, .Copy_Dst},
    }, CUBE_VERTICES[:])

    state.index_buffer = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Cube index buffer",
        usage  = {.Index, .Copy_Dst},
    }, CUBE_INDICES[:])
    state.index_count = u32(len(CUBE_INDICES))
}

init_objects :: proc(ctx: ^app.Application) {
    // The six cube colours and the cardinal directions they orbit along.
    directions := [CUBE_COUNT]linalg.Vector3f32 {
        {-1,  0,  0}, { 1,  0,  0},
        { 0, -1,  0}, { 0,  1,  0},
        { 0,  0, -1}, { 0,  0,  1},
    }
    colors := [CUBE_COUNT][4]f32 {
        {1.0, 0.0, 0.0, 1.0},
        {1.0, 1.0, 0.0, 1.0},
        {0.0, 0.5, 0.0, 1.0},
        {1.0, 0.6, 0.0, 1.0},
        {0.0, 0.0, 1.0, 1.0},
        {0.5, 0.0, 0.5, 1.0},
    }

    for index in 0 ..< CUBE_COUNT {
        object := &state.objects[index]
        object.direction = directions[index]
        object.color = colors[index]
        object.uniforms.color = colors[index]

        object.uniform_buffer = gpu.device_create_buffer(ctx.device, {
            label = TITLE + " - Cube uniforms",
            usage = {.Uniform, .Copy_Dst},
            size  = u64(size_of(Uniforms)),
        })

        object.bind_group = gpu.device_create_bind_group(ctx.device, {
            label   = TITLE + " - Cube bind group",
            layout  = state.bind_group_layout,
            entries = {
                {
                    binding  = 0,
                    resource = gpu.Buffer_Binding{
                        buffer = object.uniform_buffer,
                        offset = 0,
                        size   = gpu.WHOLE_SIZE,
                    },
                },
            },
        })
    }
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "occlusion_query"

    vert_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader)

    frag_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader)

    state.bind_group_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Bind group layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex, .Fragment},
                type       = gpu.Buffer_Binding_Layout{
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Uniforms)),
                },
            },
        },
    })

    state.pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.bind_group_layout},
    })

    depth_stencil_state := app.create_depth_stencil_state({
        format              = DEPTH_FORMAT,
        depth_write_enabled = true,
    })
    depth_stencil_state.depth_compare = .Less

    state.pipeline = gpu.device_create_render_pipeline(ctx.device, {
        label  = TITLE + " - Render pipeline",
        layout = state.pipeline_layout,
        vertex = {
            module      = vert_shader,
            entry_point = "vs_main",
            buffers     = {
                {
                    array_stride = size_of(Vertex),
                    step_mode    = .Vertex,
                    attributes   = {
                        {
                            format          = .Float32x3,
                            offset          = u64(offset_of(Vertex, position)),
                            shader_location = 0,
                        },
                        {
                            format          = .Float32x3,
                            offset          = u64(offset_of(Vertex, normal)),
                            shader_location = 1,
                        },
                    },
                },
            },
        },
        fragment = &gpu.Fragment_State{
            module      = frag_shader,
            entry_point = "fs_main",
            targets     = {
                {
                    format     = ctx.render_format,
                    blend      = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            // The camera orbits, so the parallax is easier to read with both
            // faces drawn; the depth test still resolves the ordering.
            cull_mode  = .None,
        },
        depth_stencil = &depth_stencil_state,
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    })
}

init_depth_texture :: proc(ctx: ^app.Application) {
    if state.depth_texture.texture != {} {
        app.depth_stencil_texture_uninit(&state.depth_texture)
    }

    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format       = DEPTH_FORMAT,
        width        = ctx.width,
        height       = ctx.height,
        sample_count = 1,
    })

    state.rpass.depth_stencil_attachment = {
        view      = state.depth_texture.view,
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
    state.animation = true

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, {0.5, 0.5, 0.5, 1.0}},
    }

    init_query_resources(ctx)
    init_geometry(ctx)
    init_pipeline(ctx)
    init_objects(ctx)
    init_depth_texture(ctx)

    state.rpass.descriptor = {
        label                    = TITLE + " - Render pass descriptor",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.rpass.depth_stencil_attachment,
        // A pass must name its query set for `render_pass_begin_occlusion_query`
        // to have a slot to write.
        occlusion_query_set      = state.query_set,
    }

    mu.init(&state.mu_ctx)
    state.mu_ctx.text_width = mu.default_atlas_text_width
    state.mu_ctx.text_height = mu.default_atlas_text_height

    mur.init(&state.mu_renderer, {
        device                     = ctx.device,
        target_format              = ctx.render_format,
        depth_stencil_format       = DEPTH_FORMAT,
        pipeline_multisample_state = {count = 1, mask = max(u32)},
    })
    mur.resize(&state.mu_renderer, ctx.width, ctx.height)

    return true
}

// Read the previous frame's fragment counts. Runs before recording, so the
// values shown are one frame behind, which is the same tradeoff as the
// timestamp example.
read_query_results :: proc() {
    if !state.supported {
        return
    }

    ptr := gpu.buffer_map_sync(state.readback_buffer, .Read, 0, uint(RESOLVE_SIZE))
    if ptr == nil {
        return
    }

    // Copy out *before* unmapping: on web `map_sync` hands back a heap copy that
    // `buffer_unmap` frees.
    counts: [RESULT_COUNT]u64
    src := ([^]u64)(ptr)
    for index in 0 ..< RESULT_COUNT {
        counts[index] = src[index]
    }
    gpu.buffer_unmap(state.readback_buffer)

    visible := 0
    for index in 0 ..< CUBE_COUNT {
        state.objects[index].visible_fragments = counts[index]
        if counts[index] > 0 {
            visible += 1
        }
    }
    state.visible_count = visible
}

// 0..1 triangle wave, used to dolly the camera back and forth.
ping_pong_sine :: proc(t: f32) -> f32 {
    return math.sin(t * math.PI * 2) * 0.5 + 0.5
}

update :: proc(ctx: ^app.Application, dt: f32) {
    if state.animation {
        state.time += dt
    }
    time := state.time * ANIMATION_SPEED

    aspect := f32(ctx.width) / f32(ctx.height)
    // The reference uses 30°, but at the far end of the dolly that still crops
    // the cubes nearest the viewport edge. 45° keeps all six in frame across the
    // whole animation without changing which ones occlude each other.
    projection := linalg.matrix4_perspective_f32(math.to_radians(f32(45)), aspect, 0.5, 200.0)

    // Camera pose matching the reference sample: rotate about X by `time`, about
    // Y by `0.7 * time`, and dolly between CAMERA_NEAR and CAMERA_FAR. Expressed
    // as a spherical eye position so it composes with `look_at`:
    //   eye = Rx(time) * Ry(0.7 * time) * (0, 0, distance)
    distance := CAMERA_NEAR + (CAMERA_FAR - CAMERA_NEAR) * ping_pong_sine(time * 0.2)
    angle_x := time
    angle_y := time * 0.7

    eye := linalg.Vector3f32 {
        distance * math.sin(angle_y),
        -distance * math.sin(angle_x) * math.cos(angle_y),
        distance * math.cos(angle_x) * math.cos(angle_y),
    }
    view := linalg.matrix4_look_at_f32(eye, {0, 0, 0}, {0, 1, 0})
    view_projection := projection * view

    for index in 0 ..< CUBE_COUNT {
        object := &state.objects[index]

        position := object.direction * ORBIT_RADIUS
        world := linalg.matrix4_translate_f32(position) *
                 linalg.matrix4_scale_f32(CUBE_EXTENT)

        object.uniforms.world = world
        object.uniforms.world_view_projection = view_projection * world

        gpu.queue_write_buffer_bytes(
            queue  = ctx.queue,
            buffer = object.uniform_buffer,
            offset = 0,
            data   = gpu.to_bytes(object.uniforms),
        )
    }
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    // Read the previous frame's counts before recording this one.
    read_query_results()
    update(ctx, dt)
    update_ui(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    state.rpass.depth_stencil_attachment.view = state.depth_texture.view

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, state.pipeline)
    gpu.render_pass_set_vertex_buffer(rpass, 0, state.vertex_buffer)
    gpu.render_pass_set_index_buffer(
        rpass, state.index_buffer, .Uint16, 0, gpu.WHOLE_SIZE)

    for index in 0 ..< CUBE_COUNT {
        gpu.render_pass_set_bind_group(rpass, 0, state.objects[index].bind_group)

        // Scope the query to this one draw. The count is the fragments that pass
        // the depth test, so an occluded cube reports zero.
        if state.supported {
            gpu.render_pass_begin_occlusion_query(rpass, u32(index))
        }
        gpu.render_pass_draw_indexed(rpass, state.index_count, 1, 0, 0, 0)
        if state.supported {
            gpu.render_pass_end_occlusion_query(rpass)
        }
    }

    // Settings UI overlay on top.
    mur.render(&state.mu_renderer, &state.mu_ctx, rpass)

    gpu.render_pass_end(rpass)

    if state.supported {
        gpu.command_encoder_resolve_query_set(
            encoder, state.query_set, 0, RESULT_COUNT, state.resolve_buffer, 0)
        gpu.command_encoder_copy_buffer_to_buffer(
            encoder,
            state.resolve_buffer, 0,
            state.readback_buffer, 0,
            RESOLVE_SIZE,
        )
    }

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

update_ui :: proc(ctx: ^app.Application, dt: f32) {
    // Only the visible cubes get a swatch, packed left in cube order at the fixed
    // panel width.
    visible: [CUBE_COUNT]int
    visible_count := 0
    if state.supported {
        for index in 0 ..< CUBE_COUNT {
            if state.objects[index].visible_fragments > 0 {
                visible[visible_count] = index
                visible_count += 1
            }
        }
    }

    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        mu.checkbox(&state.mu_ctx, "Animate", &state.animation)

        if visible_count > 0 {
            widths: [CUBE_COUNT]i32
            for index in 0 ..< visible_count {
                widths[index] = SWATCH_SIZE
            }

            // `layout_next` advances by `style.spacing` after every item, so a
            // spacing of 0 is what makes the swatches touch. Restored below so
            // the checkbox and any later row keep the normal gap.
            spacing := state.mu_ctx.style.spacing
            state.mu_ctx.style.spacing = 0
            mu.layout_row(&state.mu_ctx, widths[:visible_count], 0)
            for index in 0 ..< visible_count {
                rect := mu.layout_next(&state.mu_ctx)
                colour := state.objects[visible[index]].color
                mu.draw_rect(&state.mu_ctx, rect, mu.Color {
                    u8(clamp(colour[0], 0, 1) * 255),
                    u8(clamp(colour[1], 0, 1) * 255),
                    u8(clamp(colour[2], 0, 1) * 255),
                    255,
                })
            }
            state.mu_ctx.style.spacing = spacing
        }
    }
    mu.end(&state.mu_ctx)
}

resize :: proc(ctx: ^app.Application, width, height: u32) {
    init_depth_texture(ctx)
    mur.resize(&state.mu_renderer, width, height)
}

event :: proc(ctx: ^app.Application, event: app.Event) {
    app.mu_handle_events(&state.mu_ctx, event)
    #partial switch ev in event {
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    }
}

quit :: proc(ctx: ^app.Application) {
    mur.uninit(&state.mu_renderer)
    gpu.render_pipeline_release(state.pipeline)
    gpu.pipeline_layout_release(state.pipeline_layout)
    gpu.bind_group_layout_release(state.bind_group_layout)
    for index in 0 ..< CUBE_COUNT {
        gpu.bind_group_release(state.objects[index].bind_group)
        gpu.buffer_release(state.objects[index].uniform_buffer)
    }
    if state.supported {
        gpu.buffer_release(state.readback_buffer)
        gpu.buffer_release(state.resolve_buffer)
        gpu.query_set_release(state.query_set)
    }
    gpu.buffer_release(state.index_buffer)
    gpu.buffer_release(state.vertex_buffer)
    app.depth_stencil_texture_uninit(&state.depth_texture)
}

main :: proc() {
    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
