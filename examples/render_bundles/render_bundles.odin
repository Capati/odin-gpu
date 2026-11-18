/*
Example - Render Bundles

A ring of asteroids orbiting a planet, drawn a few thousand times per frame with
one draw call each. That is deliberately wasteful — instancing would collapse it
to one call — because the point is to measure the cost of *issuing* many commands
and then show what a `Render_Bundle` saves.

The scene is recorded by the same code either way:

- `render_bundle_encoder_*` into a `Render_Bundle`, created once and executed
  with `render_pass_execute_bundles`, or
- `render_pass_*` directly, re-interpreting and re-validating every command on
  every frame.

Toggle between them at runtime and the picture is identical; only the CPU cost of
recording differs. Bundles are immutable once finished, so changing how many
asteroids are drawn means rebuilding the bundle — that limitation is the reason
they suit static command streams and not, say, occlusion culling.

This is the first example to use the render-bundle API. Everything else in the
repo — including the CTS bundle tests — only validated bundle descriptors; no
example executed one.

The planet and asteroid textures are generated procedurally rather than loaded,
so the example does not depend on the asset submodule. The sphere generator in
`sphere.odin` is a port of the reference sample's `meshes/sphere.ts`.

Ref:

- https://webgpu.github.io/webgpu-samples/?sample=renderBundles
- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/render_bundles.c
*/
package render_bundles

// Core
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:slice"
import "core:time"

// Vendor
import mu "vendor:microui"

// Local packages
import "../../gpu"
import app "../framework"
import mur "../../utils/microui"

TITLE :: "Render Bundles"

// The reference uses 4 * 16 bytes for a bare mat4; group 0 holds the frame
// view-projection and group 1 holds this object's model matrix.
Frame_Uniforms :: struct #align(16) {
    view_projection: linalg.Matrix4x4f32,
}

Object_Uniforms :: struct #align(16) {
    model: linalg.Matrix4x4f32,
}

// Slider bounds. The range is wide because the point is to feel the per-draw
// cost climb; the default sits low enough that a debug build stays responsive.
ASTEROID_MIN     :: 250
ASTEROID_MAX     :: 5000
ASTEROID_DEFAULT :: 1000
ASTEROID_STEP    :: 250

// Weight of each new sample in the rolling average of `record_us`. 1/128 settles
// within roughly a second at 60 Hz, which is enough to read a stable number
// without making a slider drag unusable.
RECORD_AVERAGE_WEIGHT :: 1.0 / 128.0

// Diagnostic variant: every draw uses the *same* bind group, vertex buffer and
// index buffer, so the per-draw binds are redundant. Identical draw count, so the
// difference against the normal scene is the cost of deriving a bind per draw
// rather than of dispatching a draw.
SHARED_BINDS :: #config(SHARED_BINDS, false)

// Five asteroid meshes are reused with different transforms, exactly as in the
// reference; the visual variety comes from `randomness` and the rotations.
ASTEROID_VARIANTS :: 5

// Ring placement: radius range and vertical scatter, in world units.
RING_INNER :: 1.25
RING_OUTER :: 2.95
RING_FLATTEN :: 0.015

// Texture size for the two procedural maps.
TEXTURE_SIZE :: 256

DEPTH_FORMAT :: app.DEFAULT_DEPTH_FORMAT

Texture_Map :: struct {
    texture: gpu.Texture,
    view:    gpu.Texture_View,
    sampler: gpu.Sampler,
}

// One drawable: shared mesh, its own transform buffer, and a bind group binding
// that buffer plus the texture. The reference allocates one of these per
// asteroid, which is what makes the per-draw bind group the varying state.
Object :: struct {
    mesh:           ^Sphere_Mesh,
    uniform_buffer: gpu.Buffer,
    bind_group:     gpu.Bind_Group,
}

State :: struct {
    // Shared geometry. The planet mesh is index 0 for clarity at the call site.
    planet_mesh:  Sphere_Mesh,
    planet_vertex: gpu.Buffer,
    planet_index:  gpu.Buffer,
    planet_object: Object,

    asteroid_meshes:  [ASTEROID_VARIANTS]Sphere_Mesh,
    asteroid_vertex:  [ASTEROID_VARIANTS]gpu.Buffer,
    asteroid_index:   [ASTEROID_VARIANTS]gpu.Buffer,

    // All asteroid slots exist up front, so changing the draw count only has to
    // rebuild the bundle — no allocation mid-run, no lazy growth bookkeeping.
    asteroids: [ASTEROID_MAX]Object,

    frame_uniforms: gpu.Buffer,
    frame_bind_group: gpu.Bind_Group,

    group0_layout: gpu.Bind_Group_Layout,
    group1_layout: gpu.Bind_Group_Layout,
    pipeline_layout: gpu.Pipeline_Layout,
    pipeline: gpu.Render_Pipeline,

    planet_map:   Texture_Map,
    asteroid_map: Texture_Map,

    // The bundle is rebuilt whenever the draw count changes.
    bundle:        gpu.Render_Bundle,
    bundle_objects: int,

    depth_texture: app.Depth_Stencil_Texture,

    settings: struct {
        use_bundle: bool,
        asteroids:  int,
    },

    start: time.Tick,

    // Last measured CPU time spent recording the scene, in microseconds. This is
    // the number a bundle is meant to move: same GPU work, less CPU to submit it.
    //
    // Averaged over a short window, not shown per frame: one frame's recording
    // time swings by 50% (timer granularity, scheduler noise), so a single sample
    // is not a measurement. `record_us` is the rolling mean.
    record_us:      f64,
    record_samples: int,

    mu_ctx:      mu.Context,
    mu_renderer: mur.Renderer,

    rpass: struct {
        colors:                   [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:               gpu.Render_Pass_Descriptor,
    },
}

state: State

UI_WINDOW_WIDTH :: 260
LABEL_WIDTH     :: 110

// -----------------------------------------------------------------------------
// Geometry
// -----------------------------------------------------------------------------

init_geometry :: proc(ctx: ^app.Application) {
    state.planet_mesh = create_sphere_mesh(1.0, 32, 16, 0)

    state.planet_vertex = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Planet vertices",
        usage = {.Vertex, .Copy_Dst},
    }, state.planet_mesh.vertices)

    state.planet_index = gpu.device_create_buffer_with_data(ctx.device, {
        label = TITLE + " - Planet indices",
        usage = {.Index, .Copy_Dst},
    }, state.planet_mesh.indices)

    // The data is in GPU buffers now; the CPU copies would otherwise leak.
    sphere_mesh_free(&state.planet_mesh)

    // The five asteroid meshes differ in radius and tessellation, matching the
    // reference; the smallest ones are cheap enough to keep thousands on screen.
    radii := [ASTEROID_VARIANTS]f32 {0.01, 0.013, 0.017, 0.02, 0.03}

    for variant in 0 ..< ASTEROID_VARIANTS {
        width, height: u32 = 8, 6
        if variant == ASTEROID_VARIANTS - 1 {
            width, height = 16, 8
        }

        mesh := create_sphere_mesh(radii[variant], width, height, 0.15)
        state.asteroid_meshes[variant] = mesh

        state.asteroid_vertex[variant] = gpu.device_create_buffer_with_data(ctx.device, {
            label = TITLE + " - Asteroid vertices",
            usage = {.Vertex, .Copy_Dst},
        }, mesh.vertices)

        state.asteroid_index[variant] = gpu.device_create_buffer_with_data(ctx.device, {
            label = TITLE + " - Asteroid indices",
            usage = {.Index, .Copy_Dst},
        }, mesh.indices)

        // Uploaded; keep only the index count. `state.asteroid_meshes` holds the
        // freed (zeroed) struct, so the draw reads `index_count`.
        sphere_mesh_free(&state.asteroid_meshes[variant])
    }
}

// -----------------------------------------------------------------------------
// Procedural textures
// -----------------------------------------------------------------------------

// Cheap value-noise so the maps are not flat colour. Deterministic on purpose, so
// the two runs look the same.
hash_noise :: proc(x, y: int, seed: u32) -> f32 {
    n := u32(x) * 374761393 + u32(y) * 668265263 + seed * 2246822519
    n = (n ~ (n >> 13)) * 1274126177
    n = n ~ (n >> 16)
    return f32(n & 0xFFFF) / 65535.0
}

// Smoothly interpolated noise at a coarse grid, scaled to `cells`.
value_noise :: proc(u, v: f32, cells: int, seed: u32) -> f32 {
    fx, fy := u * f32(cells), v * f32(cells)
    x0, y0 := int(math.floor(fx)), int(math.floor(fy))
    tx, ty := fx - f32(x0), fy - f32(y0)

    // Smoothstep, so cell edges do not show as seams.
    sx := tx * tx * (3 - 2 * tx)
    sy := ty * ty * (3 - 2 * ty)

    n00 := hash_noise(x0, y0, seed)
    n10 := hash_noise(x0 + 1, y0, seed)
    n01 := hash_noise(x0, y0 + 1, seed)
    n11 := hash_noise(x0 + 1, y0 + 1, seed)

    top := n00 + (n10 - n00) * sx
    bottom := n01 + (n11 - n01) * sx
    return top + (bottom - top) * sy
}

// Banded, warm-toned map for the planet: latitude bands with noise mixed in, so
// the sphere's rotation reads even though the texture is static.
create_planet_texels :: proc() -> []u8 {
    pixels := make([]u8, TEXTURE_SIZE * TEXTURE_SIZE * 4)

    for y in 0 ..< TEXTURE_SIZE {
        v := f32(y) / f32(TEXTURE_SIZE - 1)

        for x in 0 ..< TEXTURE_SIZE {
            u := f32(x) / f32(TEXTURE_SIZE - 1)

            // Latitude bands, warped by noise so they are not perfect rings.
            warp := value_noise(u, v, 8, 7) * 0.25
            band := math.sin((v + warp) * math.PI * 9) * 0.5 + 0.5
            grain := value_noise(u, v, 32, 11) * 0.25

            warm := 0.55 + band * 0.45
            value := clamp(warm + grain, 0, 1)

            offset := (y * TEXTURE_SIZE + x) * 4
            pixels[offset + 0] = u8(value * 235)
            pixels[offset + 1] = u8(value * 205)
            pixels[offset + 2] = u8(value * 150)
            pixels[offset + 3] = 255
        }
    }

    return pixels
}

// Grey, cratered map for the asteroids. Overlapping dark rings approximate
// craters; at these on-screen sizes that is all the detail that survives.
create_asteroid_texels :: proc() -> []u8 {
    pixels := make([]u8, TEXTURE_SIZE * TEXTURE_SIZE * 4)

    CRATERS :: 24

    for y in 0 ..< TEXTURE_SIZE {
        v := f32(y) / f32(TEXTURE_SIZE - 1)

        for x in 0 ..< TEXTURE_SIZE {
            u := f32(x) / f32(TEXTURE_SIZE - 1)

            base := 0.45 + value_noise(u, v, 16, 23) * 0.35

            crater := f32(0)
            for c in 0 ..< CRATERS {
                cx := hash_noise(c, 0, 41)
                cy := hash_noise(c, 1, 43)
                radius := 0.02 + hash_noise(c, 2, 47) * 0.06

                dx, dy := u - cx, v - cy
                distance := math.sqrt(dx * dx + dy * dy)

                if distance < radius {
                    // Dark floor, brighter rim right at the edge.
                    depth := 1 - distance / radius
                    crater -= depth * 0.35
                    if distance > radius * 0.82 {
                        crater += 0.25
                    }
                }
            }

            value := clamp(base + crater, 0, 1)

            offset := (y * TEXTURE_SIZE + x) * 4
            pixels[offset + 0] = u8(value * 210)
            pixels[offset + 1] = u8(value * 210)
            pixels[offset + 2] = u8(value * 220)
            pixels[offset + 3] = 255
        }
    }

    return pixels
}

create_texture_map :: proc(ctx: ^app.Application, texels: []u8, label: string) -> Texture_Map {
    // The texels are only needed for the upload; taking ownership here keeps the
    // call sites free of a matching `delete` for a temporary.
    defer delete(texels)

    extent := gpu.Extent_3D {
        width                 = TEXTURE_SIZE,
        height                = TEXTURE_SIZE,
        depth_or_array_layers = 1,
    }

    texture := gpu.device_create_texture(ctx.device, {
        label           = label,
        size            = extent,
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        usage           = {.Texture_Binding, .Copy_Dst},
    })

    gpu.queue_write_texture(
        ctx.queue,
        {texture = texture, aspect = .All},
        texels,
        {bytes_per_row = TEXTURE_SIZE * 4, rows_per_image = TEXTURE_SIZE},
        extent,
    )

    return {
        texture = texture,
        view    = gpu.texture_create_view(texture),
        // Linear filtering matters here: the asteroids are only a few pixels
        // across, so nearest sampling would make them flicker.
        sampler = gpu.device_create_sampler(ctx.device, {
            label            = label,
            mag_filter       = .Linear,
            min_filter       = .Linear,
            mipmap_filter    = .Linear,
            address_mode_u   = .Repeat,
            address_mode_v   = .Repeat,
            // Must be at least 1: zero is out of range and rejected on the web.
            anisotropy_clamp = 1,
        }),
    }
}

// -----------------------------------------------------------------------------
// Layouts and objects
// -----------------------------------------------------------------------------

init_layouts :: proc(ctx: ^app.Application) {
    state.group0_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Frame layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout {
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Frame_Uniforms)),
                },
            },
        },
    })

    state.group1_layout = gpu.device_create_bind_group_layout(ctx.device, {
        label   = TITLE + " - Object layout",
        entries = {
            {
                binding    = 0,
                visibility = {.Vertex},
                type       = gpu.Buffer_Binding_Layout {
                    type             = .Uniform,
                    min_binding_size = u64(size_of(Object_Uniforms)),
                },
            },
            {
                // Texture at 1, sampler at 2, matching `textured_cube`: the GLSL
                // path compiles the pair as one combined `Sampler2D` at binding
                // 1, which only lines up if the texture takes the lower slot.
                binding    = 1,
                visibility = {.Fragment},
                type       = gpu.Texture_Binding_Layout {
                    sample_type    = .Float,
                    view_dimension = .D2,
                },
            },
            {
                binding    = 2,
                visibility = {.Fragment},
                type       = gpu.Sampler_Binding_Layout {type = .Filtering},
            },
        },
    })

    state.pipeline_layout = gpu.device_create_pipeline_layout(ctx.device, {
        label              = TITLE + " - Pipeline layout",
        bind_group_layouts = {state.group0_layout, state.group1_layout},
    })
}

// Every object gets its own uniform buffer, so the model matrix lives where the
// reference puts it: in the per-draw bind group rather than in a push constant.
create_object :: proc(
    ctx: ^app.Application,
    object: ^Object,
    mesh: ^Sphere_Mesh,
    tex: Texture_Map,
    model: linalg.Matrix4x4f32,
) {
    object.mesh = mesh

    object.uniform_buffer = gpu.device_create_buffer_with_data(
        ctx.device,
        {
            label = TITLE + " - Object uniforms",
            usage = {.Uniform, .Copy_Dst},
        },
        Object_Uniforms{model = model},
    )

    object.bind_group = gpu.device_create_bind_group(ctx.device, {
        label   = TITLE + " - Object bind group",
        layout  = state.group1_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding {
                    buffer = object.uniform_buffer,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
            {binding = 1, resource = tex.view},
            {binding = 2, resource = tex.sampler},
        },
    })
}

init_objects :: proc(ctx: ^app.Application) {
    state.frame_uniforms = gpu.device_create_buffer(ctx.device, {
        label = TITLE + " - Frame uniforms",
        usage = {.Uniform, .Copy_Dst},
        size  = u64(size_of(Frame_Uniforms)),
    })

    state.frame_bind_group = gpu.device_create_bind_group(ctx.device, {
        label   = TITLE + " - Frame bind group",
        layout  = state.group0_layout,
        entries = {
            {
                binding  = 0,
                resource = gpu.Buffer_Binding {
                    buffer = state.frame_uniforms,
                    offset = 0,
                    size   = gpu.WHOLE_SIZE,
                },
            },
        },
    })

    // The planet sits at the origin with an identity transform.
    create_object(
        ctx,
        &state.planet_object,
        &state.planet_mesh,
        state.planet_map,
        linalg.MATRIX4F32_IDENTITY,
    )

    // Place every asteroid now. The ring layout — random radius, random angle, a
    // sliver of vertical scatter — matches the reference, as does randomising
    // each asteroid's orientation after translating it.
    for index in 0 ..< ASTEROID_MAX {
        radius := rand.float32() * (RING_OUTER - RING_INNER) + RING_INNER
        angle := rand.float32() * math.PI * 2

        position := linalg.Vector3f32 {
            math.sin(angle) * radius,
            (rand.float32() - 0.5) * RING_FLATTEN,
            math.cos(angle) * radius,
        }

        model := linalg.matrix4_translate_f32(position)
        model = model * linalg.matrix4_rotate_f32(rand.float32() * math.PI, {1, 0, 0})
        model = model * linalg.matrix4_rotate_f32(rand.float32() * math.PI, {0, 1, 0})

        variant := index % ASTEROID_VARIANTS
        create_object(
            ctx,
            &state.asteroids[index],
            &state.asteroid_meshes[variant],
            state.asteroid_map,
            model,
        )
    }
}

init_pipeline :: proc(ctx: ^app.Application) {
    SHADER_NAME :: "render_bundles"

    vert_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".vert")
    defer gpu.shader_module_release(vert_shader)

    frag_shader := app.load_shader(ctx.device, #directory, SHADER_NAME + ".frag")
    defer gpu.shader_module_release(frag_shader)

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
                    array_stride = VERTEX_STRIDE,
                    step_mode    = .Vertex,
                    attributes   = {
                        {
                            format          = .Float32x3,
                            offset          = 0,
                            shader_location = 0,
                        },
                        {
                            format          = .Float32x3,
                            offset          = 12,
                            shader_location = 1,
                        },
                        {
                            format          = .Float32x2,
                            offset          = 24,
                            shader_location = 2,
                        },
                    },
                },
            },
        },
        fragment = &gpu.Fragment_State {
            module      = frag_shader,
            entry_point = "fs_main",
            targets     = {
                {
                    format     = ctx.render_format,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .CCW,
            // The spheres are solid, so back faces are always hidden.
            cull_mode  = .Back,
        },
        depth_stencil = &depth_stencil_state,
        multisample = {
            count = 1,
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

    // Take the whole attachment from the helper, not just the view: a writable
    // depth aspect requires load and store ops to be set.
    state.rpass.depth_stencil_attachment = state.depth_texture.descriptor
}

// -----------------------------------------------------------------------------
// Scene recording
// -----------------------------------------------------------------------------

// A render bundle is a partial, restricted render pass, so the same command
// sequence can be recorded into either. Modelling that as a union keeps the loop
// below identical for both paths — which is the point of the sample.
Scene_Target :: union {
    gpu.Render_Pass,
    gpu.Render_Bundle_Encoder,
}

target_set_pipeline :: proc(target: Scene_Target, pipeline: gpu.Render_Pipeline) {
    switch value in target {
    case gpu.Render_Pass:
        gpu.render_pass_set_pipeline(value, pipeline)
    case gpu.Render_Bundle_Encoder:
        gpu.render_bundle_encoder_set_pipeline(value, pipeline)
    }
}

target_set_bind_group :: proc(target: Scene_Target, index: u32, group: gpu.Bind_Group) {
    switch value in target {
    case gpu.Render_Pass:
        gpu.render_pass_set_bind_group(value, index, group)
    case gpu.Render_Bundle_Encoder:
        gpu.render_bundle_encoder_set_bind_group(value, index, group)
    }
}

target_set_vertex_buffer :: proc(target: Scene_Target, buffer: gpu.Buffer) {
    switch value in target {
    case gpu.Render_Pass:
        gpu.render_pass_set_vertex_buffer(value, 0, buffer)
    case gpu.Render_Bundle_Encoder:
        gpu.render_bundle_encoder_set_vertex_buffer(value, 0, buffer, 0, gpu.WHOLE_SIZE)
    }
}

target_set_index_buffer :: proc(target: Scene_Target, buffer: gpu.Buffer) {
    switch value in target {
    case gpu.Render_Pass:
        gpu.render_pass_set_index_buffer(value, buffer, .Uint16, 0, gpu.WHOLE_SIZE)
    case gpu.Render_Bundle_Encoder:
        gpu.render_bundle_encoder_set_index_buffer(value, buffer, .Uint16, 0, gpu.WHOLE_SIZE)
    }
}

target_draw_indexed :: proc(target: Scene_Target, index_count: u32) {
    switch value in target {
    case gpu.Render_Pass:
        gpu.render_pass_draw_indexed(value, index_count, 1, 0, 0, 0)
    case gpu.Render_Bundle_Encoder:
        gpu.render_bundle_encoder_draw_indexed(value, index_count, 1, 0, 0, 0)
    }
}

// Records the planet plus `asteroid_count` asteroids. Every draw sets its own
// bind group, vertex buffer and index buffer, because nothing is instanced —
// that per-draw state is exactly what a bundle replays without re-validation.
record_scene :: proc(target: Scene_Target, asteroid_count: int) {
    target_set_pipeline(target, state.pipeline)
    target_set_bind_group(target, 0, state.frame_bind_group)

    // Planet last would z-fight with nothing, but drawing it first mirrors the
    // reference and keeps the asteroid loop a clean range.
    target_set_vertex_buffer(target, state.planet_vertex)
    target_set_index_buffer(target, state.planet_index)
    target_set_bind_group(target, 1, state.planet_object.bind_group)
    target_draw_indexed(target, state.planet_mesh.index_count)

    for index in 0 ..< asteroid_count {
        object := &state.asteroids[index]
        variant := index % ASTEROID_VARIANTS

        when !SHARED_BINDS {
            target_set_bind_group(target, 1, object.bind_group)
            target_set_vertex_buffer(target, state.asteroid_vertex[variant])
            target_set_index_buffer(target, state.asteroid_index[variant])
        } else {
            // Diagnostic: all draws share the planet's group and buffers, so the
            // binds below are the same values every iteration. A correct backend
            // may drop them; ours currently does not, which is exactly what this
            // variant measures.
            target_set_bind_group(target, 1, state.planet_object.bind_group)
            target_set_vertex_buffer(target, state.planet_vertex)
            target_set_index_buffer(target, state.planet_index)
        }
        target_draw_indexed(target, object.mesh.index_count)
    }
}

// Bundles are immutable, so changing the draw count means encoding a new one.
// This is the price of the CPU saving, and the reason the reference rebuilds on
// every slider change.
rebuild_bundle :: proc(ctx: ^app.Application) {
    if state.bundle != {} {
        gpu.render_bundle_release(state.bundle)
        state.bundle = {}
    }

    color_formats := [1]gpu.Texture_Format {ctx.render_format}
    depth_stencil := gpu.Render_Bundle_Depth_Stencil {
        depth_stencil_format = DEPTH_FORMAT,
    }

    encoder := gpu.device_create_render_bundle_encoder(ctx.device, {
        label           = TITLE + " - Scene bundle encoder",
        color_formats   = color_formats[:],
        depth_stencil   = &depth_stencil,
        sample_count    = 1,
    })
    defer gpu.render_bundle_encoder_release(encoder)

    record_scene(encoder, state.settings.asteroids)

    state.bundle = gpu.render_bundle_encoder_finish(encoder, {
        label = TITLE + " - Scene bundle",
    })
    state.bundle_objects = state.settings.asteroids

    // The cost being measured depends on how many draws there are and which path
    // executes them, so an average from before this change is not comparable.
    state.record_samples = 0
}

// -----------------------------------------------------------------------------
// Frame
// -----------------------------------------------------------------------------

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.settings.use_bundle = true
    state.settings.asteroids = ASTEROID_DEFAULT
    state.start = time.tick_now()

    state.rpass.colors[0] = {
        view        = {}, // Assigned later
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        // The reference clears to opaque black; the stars are the asteroids
        // themselves, so a dark clear keeps the ring legible.
        ops         = {.Clear, .Store, {0.0, 0.0, 0.0, 1.0}},
    }

    state.planet_map = create_texture_map(ctx, create_planet_texels(), TITLE + " - Planet")
    state.asteroid_map = create_texture_map(
        ctx, create_asteroid_texels(), TITLE + " - Asteroid")

    init_layouts(ctx)
    init_geometry(ctx)
    init_objects(ctx)
    init_pipeline(ctx)
    init_depth_texture(ctx)

    state.rpass.descriptor = {
        label                    = TITLE + " - Render pass descriptor",
        color_attachments        = state.rpass.colors[:],
        depth_stencil_attachment = &state.rpass.depth_stencil_attachment,
    }

    rebuild_bundle(ctx)

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

// The camera move matches the reference: translate back four units, tilt on Z and
// X so the planet reads as off-axis, then spin slowly on Y.
update_camera :: proc(ctx: ^app.Application) {
    now := f32(time.duration_seconds(time.tick_since(state.start)))

    aspect := f32(ctx.width) / f32(ctx.height)
    projection := linalg.matrix4_perspective_f32(2 * math.PI / 5, aspect, 0.1, 100.0)

    view := linalg.matrix4_translate_f32({0, 0, -4.0})
    view = view * linalg.matrix4_rotate_f32(math.PI * 0.1, {0, 0, 1})
    view = view * linalg.matrix4_rotate_f32(math.PI * 0.1, {1, 0, 0})
    view = view * linalg.matrix4_rotate_f32(now * 0.05, {0, 1, 0})

    gpu.queue_write_buffer_bytes(
        queue  = ctx.queue,
        buffer = state.frame_uniforms,
        offset = 0,
        data   = gpu.to_bytes(Frame_Uniforms{view_projection = projection * view}),
    )
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update_camera(ctx)
    update_ui(ctx)

    frame := app.get_current_frame()
    if frame.skip {return true}
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    state.rpass.colors[0].view = frame.view
    state.rpass.depth_stencil_attachment.view = state.depth_texture.view

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    // Time from the first scene command through submit, not just the record
    // call. A bundle-only implementation may store one execute command while
    // recording and replay the bundle's commands inside submit, so timing the
    // encoder alone would measure command bookkeeping on one side and the
    // actual replay on the other. Spanning submit is the only boundary where
    // both sides are timed for the same work.
    record_start := time.tick_now()

    if state.settings.use_bundle {
        gpu.render_pass_execute_bundles(rpass, {state.bundle})
    } else {
        record_scene(rpass, state.settings.asteroids)
    }

    // The overlay sits between the scene commands and submit, so it cannot be
    // kept out of the span by moving a timestamp - only subtracted from it. It
    // has to be excluded: its command stream changes every frame, so it could
    // never live in a bundle, and no implementation we compare against draws one.
    // Charging it to us would be measuring a different frame.
    overlay_start := time.tick_now()

    mur.render(&state.mu_renderer, &state.mu_ctx, rpass)

    overlay_ns := i64(time.duration_nanoseconds(time.tick_since(overlay_start)))

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})

    // Subtract the overlay. The span has to include submit, and the overlay is
    // written inside the render pass, so the two cannot be separated by moving a
    // timestamp - only by subtracting one. Clamped at zero because both timestamps
    // share a clock and a coarse tick could otherwise produce a negative sample.
    total_ns := time.duration_nanoseconds(time.tick_since(record_start))
    sample := f64(max(i64(0), total_ns - overlay_ns)) / 1000.0

    // Exponential moving average: converges in a few dozen frames and stays
    // stable afterwards. Seeded on the first sample so the readout does not
    // ramp up from zero. Reset by `rebuild_bundle`, since the cost depends on
    // the draw count.
    if state.record_samples == 0 {
        state.record_us = sample
    } else {
        state.record_us += (sample - state.record_us) * RECORD_AVERAGE_WEIGHT
    }
    state.record_samples += 1

    gpu.surface_texture_present(frame)

    return true
}

update_ui :: proc(ctx: ^app.Application) {
    mu.begin(&state.mu_ctx)
    if mu.begin_window(&state.mu_ctx, "Settings", {10, 10, UI_WINDOW_WIDTH, 0},
            {.NO_CLOSE, .NO_RESIZE, .NO_SCROLL, .AUTO_SIZE}) {
        defer mu.end_window(&state.mu_ctx)

        win := mu.get_current_container(&state.mu_ctx)
        win.rect.w = UI_WINDOW_WIDTH // Fixed width

        // microui sizes an unrow-ed item from `style.size.x` (64px), which clips
        // a label this long; a full-width row is what gives it the space.
        mu.layout_row(&state.mu_ctx, {-1}, 0)
        if .CHANGE in mu.checkbox(&state.mu_ctx, "Use render bundles", &state.settings.use_bundle) {
            // The two paths have different costs; keep an average spanning both
            // from showing a number that belongs to neither.
            state.record_samples = 0
        }

        asteroids := i32(state.settings.asteroids)
        mu.layout_row(&state.mu_ctx, {LABEL_WIDTH, -1}, 0)
        mu.label(&state.mu_ctx, "Asteroids")
        if .CHANGE in mur.slider(&state.mu_ctx, &asteroids, ASTEROID_MIN, ASTEROID_MAX,
                ASTEROID_STEP, "%.0f") {
            // Snap so the slider lands on round numbers rather than wherever the
            // drag ended.
            snapped := (asteroids + ASTEROID_STEP / 2) / ASTEROID_STEP * ASTEROID_STEP
            snapped = clamp(snapped, ASTEROID_MIN, ASTEROID_MAX)

            if int(snapped) != state.settings.asteroids {
                state.settings.asteroids = int(snapped)
                rebuild_bundle(ctx)
            }
        }

        mu.layout_row(&state.mu_ctx, {-1}, 0)
        mode := "bundle" if state.settings.use_bundle else "manual"
        mu.label(&state.mu_ctx, fmt.tprintf("record avg (%s): %.1f us", mode, state.record_us))
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

    gpu.render_bundle_release(state.bundle)

    gpu.render_pipeline_release(state.pipeline)
    gpu.pipeline_layout_release(state.pipeline_layout)
    gpu.bind_group_layout_release(state.group1_layout)
    gpu.bind_group_layout_release(state.group0_layout)

    gpu.bind_group_release(state.frame_bind_group)
    gpu.buffer_release(state.frame_uniforms)

    gpu.bind_group_release(state.planet_object.bind_group)
    gpu.buffer_release(state.planet_object.uniform_buffer)

    for index in 0 ..< ASTEROID_MAX {
        gpu.bind_group_release(state.asteroids[index].bind_group)
        gpu.buffer_release(state.asteroids[index].uniform_buffer)
    }

    gpu.buffer_release(state.planet_index)
    gpu.buffer_release(state.planet_vertex)
    for variant in 0 ..< ASTEROID_VARIANTS {
        gpu.buffer_release(state.asteroid_index[variant])
        gpu.buffer_release(state.asteroid_vertex[variant])
    }

    for tex in ([2]Texture_Map{state.planet_map, state.asteroid_map}) {
        gpu.sampler_release(tex.sampler)
        gpu.texture_view_release(tex.view)
        gpu.texture_release(tex.texture)
    }

    app.depth_stencil_texture_uninit(&state.depth_texture)
}

main :: proc() {
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
