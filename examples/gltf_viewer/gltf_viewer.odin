/*
Example - glTF Viewer

Instanced glTF renderer: scene graph, per-mesh instancing, animation,
preset cameras + orbit camera.

Ref:

- https://github.com/JiyuHuang/webgpu-gltf-viewer
- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/gltf_viewer.c

TODO:

- IBL
*/
package gltf_viewer2

// Core
import "core:log"
import "core:mem"
import "base:runtime"

// Vendor
import "../../gpu"

// Local packages
import app "../framework"
import "../../utils/gltf"
import la "core:math/linalg"

TITLE :: "glTF Viewer"

// The model rendered by this example.
MODEL_PATH :: "assets/models/DamagedHelmet.glb"

INSTANCE_CAPACITY :: 64

TEXTURE_SLOT_BASE_COLOR :: 0
TEXTURE_SLOT_METALLIC_ROUGHNESS :: 1
TEXTURE_SLOT_NORMAL :: 2
TEXTURE_SLOT_OCCLUSION :: 3
TEXTURE_SLOT_EMISSIVE :: 4
TEXTURE_SLOT_COUNT :: 5

// 128 bytes, mirrors `struct Model { column_major float4x4 matrix; float4x4
// invTr; }` in gltf_viewer2.slang.
Model_Instance :: struct #align (16) {
    matrix4: la.Matrix4f32,
    inv_tr:  la.Matrix4f32,
}

// 80 bytes, mirrors Material_Uniforms in gltf_viewer2.slang.
Material_Uniforms :: struct #align (16) {
    base_color_factor: [4]f32,
    emissive_factor:   [4]f32,
    pbr_factors:       [4]f32, // x metallic, y roughness, z normal scale, w occlusion strength
    alpha:             [4]f32, // x alpha cutoff, y alpha mode, z double sided, w has normal map
    texcoord_bits:     u32,
    _pad:              [3]f32,
}

GPU_Texture :: struct {
    texture: gpu.Texture,
    view:    gpu.Texture_View,
    sampler: gpu.Sampler,
    owns:    bool,
}

GPU_Material :: struct {
    uniform_buffer: gpu.Buffer,
    textures:       [TEXTURE_SLOT_COUNT]GPU_Texture,
    alpha_mode:     gltf.Alpha_Mode,
    double_sided:   bool,
}

Draw_Item :: struct {
    mesh:           int,
    primitive:      int, // index into scene.model.meshes[mesh].primitives
    bind_group:     gpu.Bind_Group,
    instance_count: u32,
}

// The device half of a model mesh: the per-mesh instance storage buffer and
// the live instance list uploaded from the framework's Gltf_Model. The CPU
// geometry (primitives, vertices, indices) lives in scene.model.
Mesh_Device :: struct {
    instances:      [dynamic]Model_Instance,
    buffer:         gpu.Buffer,
    instance_count: u32,
}

// The scene a backend draws: the CPU-owned framework model plus the GPU
// resources built from it (vertex/index buffers, per-mesh instance buffers,
// material uniforms, cached textures and the pre-built draw lists).
Model_Scene :: struct {
    allocator:        mem.Allocator,
    model:            app.Gltf_Model,
    vertex_buffer:    gpu.Buffer,
    index_buffer:     gpu.Buffer,
    meshes:           [dynamic]Mesh_Device,
    materials:        [dynamic]GPU_Material,
    texture_cache:    [dynamic]GPU_Texture,
    default_textures: [TEXTURE_SLOT_COUNT]GPU_Texture,
    opaque:           [dynamic]Draw_Item,
    blended:          [dynamic]Draw_Item,
}

State :: struct {
    allocator:              mem.Allocator,
    camera:                 app.Camera,
    use_user_camera:        bool,
    camera_index:           int,
    aspect:                 f32,
    camera_proj_view_buffer: gpu.Buffer,
    camera_eye_buffer:      gpu.Buffer,
    camera_layout:          gpu.Bind_Group_Layout,
    camera_bind_group:      gpu.Bind_Group,
    material_layout:        gpu.Bind_Group_Layout,
    pipeline_layout:        gpu.Pipeline_Layout,
    pipeline_opaque:       gpu.Render_Pipeline, // opaque, cull back
    pipeline_opaque_none:  gpu.Render_Pipeline, // opaque, double sided
    pipeline_blend:        gpu.Render_Pipeline, // blend, double sided
    pipeline_blend_culled: gpu.Render_Pipeline, // blend, cull back
    scene:                  Model_Scene,
    model_loaded:           bool,
    total_time:             f64,
    depth_texture:          app.Depth_Stencil_Texture,
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

@(export)
init :: proc(ctx: ^app.Application) -> bool {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    state.allocator = ctx.allocator
    state.aspect = f32(ctx.width) / f32(ctx.height) if ctx.height > 0 else 1
    state.use_user_camera = true
    state.camera_index = 0

    app.camera_init(&state.camera)
    state.camera.type = .Look_At

    create_layouts(ctx)
    create_camera_resources(ctx)
    create_pipelines(ctx)
    create_depth_texture(ctx)
    create_render_pass(ctx)

    if !load_model(ctx, MODEL_PATH) {
        log.errorf("Failed to load default model %s", MODEL_PATH)
        return false
    }
    frame_user_camera(ctx)
    return true
}

create_depth_texture :: proc(ctx: ^app.Application) {
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format = app.DEFAULT_DEPTH_FORMAT,
        width = ctx.width,
        height = ctx.height,
        sample_count = ctx.desc.sample_count,
    })
}

create_render_pass :: proc(ctx: ^app.Application) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].view = {}
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = {0, 0, 0, 0},
    }
    state.rpass.descriptor = {
        label = TITLE + " - render pass",
        color_attachments = state.rpass.colors[:],
        depth_stencil_attachment = &state.depth_texture.descriptor,
    }
}

@(export)
resize :: proc(ctx: ^app.Application, width: u32, height: u32) -> bool {
    state.aspect = f32(width) / f32(height) if height > 0 else 1
    app.depth_stencil_texture_uninit(&state.depth_texture)
    app.depth_stencil_texture_init(&state.depth_texture, ctx.device, {
        format = app.DEFAULT_DEPTH_FORMAT,
        width = width,
        height = height,
        sample_count = ctx.desc.sample_count,
    })
    state.rpass.descriptor.depth_stencil_attachment = &state.depth_texture.descriptor
    if state.use_user_camera {
        app.camera_update_aspect_ratio(&state.camera, state.aspect)
    }
    return true
}

cycle_camera :: proc() {
    app.camera_reset_mouse_input(&state.camera)
    if len(state.scene.model.preset_cameras) == 0 {
        log.warnf("No preset cameras defined by the model")
        return
    }
    if state.use_user_camera {
        // Enter the preset list at its first camera.
        state.use_user_camera = false
        state.camera_index = 0
    } else {
        // Advance through the presets, then back to the user camera.
        state.camera_index += 1
        if state.camera_index >= len(state.scene.model.preset_cameras) {
            state.use_user_camera = true
            state.camera_index = 0
            log.infof("Camera switched; user camera again")
            return
        }
    }
    log.infof(
        "Camera switched; preset %d/%d",
        state.camera_index + 1,
        len(state.scene.model.preset_cameras),
    )
}

@(export)
event :: proc(ctx: ^app.Application, event: app.Event) {
    app.camera_on_input_event(&state.camera, event)

    #partial switch ev in event {
    case app.Key_Event:
        if ev.action == .Pressed {
            #partial switch ev.key {
            case .C:
                cycle_camera()
            case:
            }
        }
    case app.Resize_Event:
        resize(ctx, ev.width, ev.height)
    case:
    }
}

@(export)
iterate :: proc(ctx: ^app.Application, dt: f32) -> bool {
    state.total_time += f64(dt)
    update_camera(ctx, &state, dt)
    update_scene_animations(ctx, &state, f32(state.total_time))

    frame := app.get_current_frame()
    if frame.skip {
        return true
    }
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view
    encoder := gpu.device_create_command_encoder(ctx.device, {label = TITLE + " - encoder"})
    defer gpu.command_encoder_release(encoder)

    pass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(pass)

    scene := &state.scene
    if scene.vertex_buffer != {} {
        gpu.render_pass_set_vertex_buffer(pass, 0, scene.vertex_buffer, 0, gpu.WHOLE_SIZE)
    }
    if scene.index_buffer != {} {
        gpu.render_pass_set_index_buffer(pass, scene.index_buffer, .Uint32, 0, gpu.WHOLE_SIZE)
    }
    gpu.render_pass_set_bind_group(pass, 0, state.camera_bind_group)

    draw_items(ctx, pass, scene, &state, scene.opaque[:])
    draw_items(ctx, pass, scene, &state, scene.blended[:])

    gpu.render_pass_end(pass)

    cmd := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmd)

    gpu.queue_submit(ctx.queue, {cmd})
    gpu.surface_texture_present(frame)
    return true
}

// One draw per primitive. Indices carry absolute vertex offsets (they were
// baked at load time), so base_vertex is always zero. Double-sided opaque
// items use the unculled pipeline; everything blended uses the blend pipeline.
draw_items :: proc(
    ctx: ^app.Application,
    pass: gpu.Render_Pass,
    scene: ^Model_Scene,
    state: ^State,
    items: []Draw_Item,
) {
    for &d in items {
        m := &scene.model.meshes[d.mesh]
        p := m.primitives[d.primitive]

        pipeline := state.pipeline_opaque
        material := &scene.materials[p.material]
        if material.alpha_mode == .Blend {
            // Picks cull mode from `double_sided` for blended pipelines, so single-sided
            // blended geometry still culls.
            pipeline = state.pipeline_blend if material.double_sided else state.pipeline_blend_culled
        } else if material.double_sided {
            pipeline = state.pipeline_opaque_none
        }
        gpu.render_pass_set_pipeline(pass, pipeline)
        gpu.render_pass_set_bind_group(pass, 1, d.bind_group)
        gpu.render_pass_draw_indexed(
            pass,
            p.index_count,
            d.instance_count,
            p.first_index,
            0,
            0,
        )
    }
}

@(export)
quit :: proc(ctx: ^app.Application) {
    unload_model(&state)
    app.depth_stencil_texture_uninit(&state.depth_texture)
    release_pipeline_resources(&state)
    release_camera_resources(&state)
}

// ------------------------------------------------------------ layouts & pipelines

create_layouts :: proc(ctx: ^app.Application) {
    // Group 0: camera. b0 = projected view matrix, b1 = eye position.
    state.camera_layout = gpu.device_create_bind_group_layout(
        ctx.device,
        {
            label = TITLE + " - camera bind group layout",
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
                {
                    binding = 1,
                    visibility = {.Fragment},
                    type = gpu.Buffer_Binding_Layout {
                        type = .Uniform,
                        has_dynamic_offset = false,
                        min_binding_size = 4 * size_of(f32),
                    },
                },
            },
        },
    )

    // Group 1: per-primitive. b0 = instance matrices (storage), b1/b2..b9/b10 =
    // five sampler/texture pairs, b11 = material uniforms.
    material_entries := make(
        [dynamic]gpu.Bind_Group_Layout_Entry,
        0,
        1 + TEXTURE_SLOT_COUNT * 2 + 1,
        context.temp_allocator,
    )
    append(
        &material_entries,
        gpu.Bind_Group_Layout_Entry {
            binding = 0,
            visibility = {.Vertex},
            type = gpu.Buffer_Binding_Layout {
                type = .Read_Only_Storage,
                has_dynamic_offset = false,
                min_binding_size = u64(INSTANCE_CAPACITY) * u64(size_of(Model_Instance)),
            },
        },
    )
    for slot in 0 ..< TEXTURE_SLOT_COUNT {
        append(
            &material_entries,
            gpu.Bind_Group_Layout_Entry {
                binding = u32(1 + slot * 2),
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout {type = .Filtering},
            },
        )
        append(
            &material_entries,
            gpu.Bind_Group_Layout_Entry {
                binding = u32(2 + slot * 2),
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout {
                    sample_type    = .Float,
                    view_dimension = .D2,
                    multisampled   = false,
                },
            },
        )
    }
    append(
        &material_entries,
        gpu.Bind_Group_Layout_Entry {
            binding = u32(1 + TEXTURE_SLOT_COUNT * 2),
            visibility = {.Fragment},
            type = gpu.Buffer_Binding_Layout {
                type = .Uniform,
                has_dynamic_offset = false,
                min_binding_size = size_of(Material_Uniforms),
            },
        },
    )
    state.material_layout = gpu.device_create_bind_group_layout(
        ctx.device,
        {
            label = TITLE + " - material bind group layout",
            entries = material_entries[:],
        },
    )

    state.pipeline_layout = gpu.device_create_pipeline_layout(
        ctx.device,
        {
            label = TITLE + " - pipeline layout",
            bind_group_layouts = {state.camera_layout, state.material_layout},
        },
    )
}

create_pipeline :: proc(
    ctx: ^app.Application,
    label: string,
    cull_mode: gpu.Cull_Mode,
    blend: bool,
    depth_write: bool,
    vertex_shader: gpu.Shader_Module,
    fragment_shader: gpu.Shader_Module,
    vertex_buffers: []gpu.Vertex_Buffer_Layout,
) -> gpu.Render_Pipeline {
    depth_stencil := app.create_depth_stencil_state(
        {
            format = app.DEFAULT_DEPTH_FORMAT,
            depth_write_enabled = depth_write,
            depth_compare = .Less,
        },
    )
    target := gpu.Color_Target_State {
        format     = ctx.render_format,
        write_mask = gpu.COLOR_WRITES_ALL,
    }
    if blend {
        target.blend = &gpu.BLEND_STATE_NORMAL
    }

    return gpu.device_create_render_pipeline(
        ctx.device,
        {
            label = label,
            layout = state.pipeline_layout,
            vertex = {module = vertex_shader, entry_point = "vs_main", buffers = vertex_buffers},
            fragment = &gpu.Fragment_State {
                module = fragment_shader,
                entry_point = "fs_main",
                targets = {target},
            },
            primitive = {topology = .Triangle_List, front_face = .CCW, cull_mode = cull_mode},
            depth_stencil = &depth_stencil,
            multisample = {count = 1, mask = max(u32)},
        },
    )
}

create_pipelines :: proc(ctx: ^app.Application) {
    vertex_shader := app.load_shader(ctx.device, #directory, "gltf_viewer2.vert")
    defer gpu.shader_module_release(vertex_shader)
    fragment_shader := app.load_shader(ctx.device, #directory, "gltf_viewer2.frag")
    defer gpu.shader_module_release(fragment_shader)

    vertex_buffers := []gpu.Vertex_Buffer_Layout {
        {
            array_stride = size_of(app.Gltf_Vertex),
            step_mode = .Vertex,
            attributes = {
                {
                    format = .Float32x3,
                    offset = u64(offset_of(app.Gltf_Vertex, position)),
                    shader_location = 0,
                },
                {
                    format = .Float32x3,
                    offset = u64(offset_of(app.Gltf_Vertex, normal)),
                    shader_location = 1,
                },
                {format = .Float32x2, offset = u64(offset_of(app.Gltf_Vertex, uv0)), shader_location = 2},
                {format = .Float32x2, offset = u64(offset_of(app.Gltf_Vertex, uv1)), shader_location = 3},
                {
                    format = .Float32x4,
                    offset = u64(offset_of(app.Gltf_Vertex, tangent)),
                    shader_location = 4,
                },
                {format = .Float32x4, offset = u64(offset_of(app.Gltf_Vertex, color)), shader_location = 5},
            },
        },
    }

    state.pipeline_opaque = create_pipeline(
        ctx,
        TITLE + " - opaque PBR pipeline",
        .Back,
        false,
        true,
        vertex_shader,
        fragment_shader,
        vertex_buffers,
    )
    state.pipeline_opaque_none = create_pipeline(
        ctx,
        TITLE + " - double sided opaque PBR pipeline",
        .None,
        false,
        true,
        vertex_shader,
        fragment_shader,
        vertex_buffers,
    )
    // Transparent primitives blend; depth is still written so later opaque geometry can
    // occlude them, no depth sorting. The cull mode follows `doubleSided`.
    state.pipeline_blend = create_pipeline(
        ctx,
        TITLE + " - double sided transparent PBR pipeline",
        .None,
        true,
        true,
        vertex_shader,
        fragment_shader,
        vertex_buffers,
    )
    state.pipeline_blend_culled = create_pipeline(
        ctx,
        TITLE + " - transparent PBR pipeline",
        .Back,
        true,
        true,
        vertex_shader,
        fragment_shader,
        vertex_buffers,
    )
}

release_pipeline_resources :: proc(state: ^State) {
    gpu.render_pipeline_release(state.pipeline_opaque)
    gpu.render_pipeline_release(state.pipeline_opaque_none)
    gpu.render_pipeline_release(state.pipeline_blend)
    gpu.render_pipeline_release(state.pipeline_blend_culled)
    gpu.pipeline_layout_release(state.pipeline_layout)
    gpu.bind_group_layout_release(state.material_layout)
    gpu.bind_group_layout_release(state.camera_layout)
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
            width = 1280,
            height = 720,
            sample_count = 1,
        },
    )
}
