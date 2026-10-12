/* -------------------------------------------------------------------------- *
 * Model loading (device layer): uploads a framework Gltf_Model to the GPU and
 * keeps the per-mesh instancing, material uniform buffers, texture cache and
 * draw items. All parsing, decoding and CPU scene math lives in the framework
 * (gltf_model.odin); this file only makes gpu.* calls.
 * -------------------------------------------------------------------------- */

package gltf_viewer2

// Core
import "core:fmt"
import "core:log"

// Vendor
import "../../gpu"

// Local packages
import app "../framework"
import "../../utils/gltf"

gltf_filter :: proc(value: gltf.Filter_Type, fallback: gpu.Filter_Mode) -> gpu.Filter_Mode {
    #partial switch value {
    case .Nearest, .Nearest_Mipmap_Nearest, .Nearest_Mipmap_Linear:
        return .Nearest
    case .Linear, .Linear_Mipmap_Nearest, .Linear_Mipmap_Linear:
        return .Linear
    case .Undefined:
        return fallback
    }
    return fallback
}

gltf_address_mode :: proc(value: gltf.Wrap_Mode) -> gpu.Address_Mode {
    #partial switch value {
    case .Clamp_To_Edge:
        return .Clamp_To_Edge
    case .Mirrored_Repeat:
        return .Mirror_Repeat
    case .Repeat:
        return .Repeat
    }
    return .Repeat
}

// Sampler for a glTF texture. Undefined filters mean "implementation defined",
// which WGSL leaves linear; the defaults below are the linear/Repeat ones.
sampler_descriptor_for :: proc(texture: ^app.Gltf_Texture) -> gpu.Sampler_Descriptor {
    result := gpu.DEFAULT_SAMPLER_DESCRIPTOR
    result.address_mode_u = .Repeat
    result.address_mode_v = .Repeat
    result.mag_filter = .Linear
    result.min_filter = .Linear
    result.mipmap_filter = .Linear
    result.address_mode_u = gltf_address_mode(texture.sampler.wrap_s)
    result.address_mode_v = gltf_address_mode(texture.sampler.wrap_t)
    result.mag_filter = gltf_filter(texture.sampler.mag_filter, .Linear)
    result.min_filter = gltf_filter(texture.sampler.min_filter, .Linear)
    return result
}

// ---------------------------------------------------------------- textures --

// 1x1 solid texture, no mipmaps.
create_solid_texture :: proc(
    ctx: ^app.Application,
    pixel: [4]u8,
    label: string,
) -> GPU_Texture {
    extent := gpu.Extent_3D {
        width                 = 1,
        height                = 1,
        depth_or_array_layers = 1,
    }
    texel := pixel
    texture := gpu.device_create_texture(
        ctx.device,
        {
            label = label,
            size = extent,
            mip_level_count = 1,
            sample_count = 1,
            dimension = .D2,
            format = .RGBA8_Unorm,
            usage = {.Texture_Binding, .Copy_Dst},
        },
    )
    gpu.queue_write_texture(
        queue = ctx.queue,
        destination = {texture = texture, mip_level = 0, aspect = .All},
        data = texel[:],
        data_layout = {offset = 0, bytes_per_row = 4, rows_per_image = 1},
        write_size = extent,
    )
    return {
        texture = texture,
        view = gpu.texture_create_view(texture),
        sampler = gpu.device_create_sampler(
            ctx.device,
            {
                address_mode_u = .Repeat,
                address_mode_v = .Repeat,
                address_mode_w = .Repeat,
                mag_filter = .Linear,
                min_filter = .Linear,
                mipmap_filter = .Linear,
                lod_min_clamp = 0,
                lod_max_clamp = 0,
                compare = .Undefined,
                anisotropy_clamp = 1,
            },
        ),
        owns = true,
    }
}

init_default_textures :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    white := [4]u8{255, 255, 255, 255}
    scene.default_textures[TEXTURE_SLOT_BASE_COLOR] = create_solid_texture(
        ctx,
        white,
        TITLE + " - default base color",
    )
    scene.default_textures[TEXTURE_SLOT_METALLIC_ROUGHNESS] = create_solid_texture(
        ctx,
        white,
        TITLE + " - default metallic roughness",
    )
    // (0.5, 0.5, 1) is the flat tangent-space normal: it decodes to (0, 0, 1),
    // so the always-sampled normal map branch reduces to `normalize(vNormal)`.
    scene.default_textures[TEXTURE_SLOT_NORMAL] = create_solid_texture(
        ctx,
        {128, 128, 255, 255},
        TITLE + " - default normal",
    )
    scene.default_textures[TEXTURE_SLOT_OCCLUSION] = create_solid_texture(
        ctx,
        white,
        TITLE + " - default occlusion",
    )
    scene.default_textures[TEXTURE_SLOT_EMISSIVE] = create_solid_texture(
        ctx,
        {0, 0, 0, 255},
        TITLE + " - default emissive",
    )
}

// Records a cache entry for a texture that could not be created. The fallback
// is a shared default that the scene release drops on its own, so the cached
// copy drops its ownership claim to avoid a double release.
cache_fallback :: proc(entry: ^GPU_Texture, fallback: GPU_Texture) -> GPU_Texture {
    entry^ = fallback
    entry^.owns = false
    return entry^
}

// Uploads a decoded core texture as a single-level RGBA8_Unorm texture.
upload_texture :: proc(
    ctx: ^app.Application,
    texture: ^app.Gltf_Texture,
    sampler: ^gpu.Sampler_Descriptor,
    label: string,
) -> GPU_Texture {
    if texture == nil || !texture.decoded || texture.pixels == nil {
        return {}
    }
    width := u32(texture.width)
    height := u32(texture.height)
    gpu_texture := gpu.device_create_texture(
        ctx.device,
        {
            label = label,
            size = {width, height, 1},
            mip_level_count = 1,
            sample_count = 1,
            dimension = .D2,
            format = .RGBA8_Unorm,
            usage = {.Texture_Binding, .Copy_Dst},
        },
    )
    gpu.queue_write_texture(
        queue = ctx.queue,
        destination = {texture = gpu_texture, mip_level = 0, aspect = .All},
        data = texture.pixels,
        data_layout = {
            offset = 0,
            bytes_per_row = width * 4,
            rows_per_image = height,
        },
        write_size = {width, height, 1},
    )
    return {
        texture = gpu_texture,
        view = gpu.texture_create_view(gpu_texture),
        sampler = gpu.device_create_sampler(ctx.device, sampler^),
        owns = true,
    }
}

// Resolves a material texture slot to a GPU texture, caching the uploaded
// result per glTF texture so a texture shared by two materials is uploaded
// once. Textures that could not be decoded fall back to the per-slot default.
resolve_texture :: proc(
    ctx: ^app.Application,
    scene: ^Model_Scene,
    slot: app.Gltf_Texture_Slot,
    fallback: GPU_Texture,
) -> GPU_Texture {
    if slot.texture < 0 || slot.texture >= len(scene.model.textures) {
        return fallback
    }
    index := slot.texture
    entry := &scene.texture_cache[index]
    if entry.texture != {} {
        return entry^
    }

    texture := &scene.model.textures[index]
    if !texture.decoded || texture.pixels == nil {
        return cache_fallback(entry, fallback)
    }

    sampler := sampler_descriptor_for(texture)
    result := upload_texture(
        ctx,
        texture,
        &sampler,
        fmt.tprintf(TITLE + " - texture %d", index),
    )
    if result.texture == {} {
        return cache_fallback(entry, fallback)
    }
    entry^ = result
    return result
}

// --------------------------------------------------------------- materials --

// Packs a core material into the shader's 80-byte uniform block. The math is
// unchanged from the pre-refactor implementation; factors and texcoord bits are
// recomputed from the slot data.
material_uniforms :: proc(material: ^app.Gltf_Material) -> Material_Uniforms {
    result := Material_Uniforms {
        base_color_factor = {1, 1, 1, 1},
        emissive_factor   = {0, 0, 0, 1},
        pbr_factors       = {1, 1, 1, 1},
        alpha             = {0.5, f32(gltf.Alpha_Mode.Opaque), 0, 0},
    }
    if material == nil {
        return result
    }

    result.base_color_factor = material.base_color_factor
    result.emissive_factor = {
        material.emissive_factor.x,
        material.emissive_factor.y,
        material.emissive_factor.z,
        // KHR_materials_emissive_strength, default 1.0 when absent.
        material.emissive_strength,
    }

    has_normal_map := material.slots[TEXTURE_SLOT_NORMAL].texture >= 0
    occlusion_strength := f32(0)
    if material.slots[TEXTURE_SLOT_OCCLUSION].texture >= 0 {
        occlusion_strength = material.slots[TEXTURE_SLOT_OCCLUSION].scale
    }
    result.pbr_factors = {
        material.metallic_factor,
        material.roughness_factor,
        material.slots[TEXTURE_SLOT_NORMAL].scale if has_normal_map else 0,
        occlusion_strength,
    }
    result.alpha = {
        material.alpha_cutoff,
        f32(material.alpha_mode),
        f32(1) if material.double_sided else 0,
        f32(1) if has_normal_map else 0,
    }

    bits: u32
    for slot in 0 ..< TEXTURE_SLOT_COUNT {
        view := material.slots[slot]
        if view.texture >= 0 && view.transform_texcoord == 1 {
            bits |= u32(1) << uint(slot)
        }
    }
    result.texcoord_bits = bits
    return result
}

create_material :: proc(
    ctx: ^app.Application,
    scene: ^Model_Scene,
    material: ^app.Gltf_Material,
) -> GPU_Material {
    uniforms := material_uniforms(material)
    buffer := gpu.device_create_buffer_with_data(
        ctx.device,
        {
            label = "material uniform",
            usage = {.Uniform, .Copy_Dst},
        },
        gpu.to_bytes(uniforms),
    )
    result := GPU_Material {
        uniform_buffer = buffer,
        alpha_mode     = .Opaque,
    }
    if material != nil {
        result.alpha_mode = material.alpha_mode
        result.double_sided = material.double_sided
    }

    for slot in 0 ..< TEXTURE_SLOT_COUNT {
        result.textures[slot] = resolve_texture(
            ctx,
            scene,
            material.slots[slot],
            scene.default_textures[slot],
        )
    }
    return result
}

create_materials :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    model := &scene.model
    scene.texture_cache = make([dynamic]GPU_Texture, 0, len(model.textures), scene.allocator)
    for _ in 0 ..< len(model.textures) {
        append(&scene.texture_cache, GPU_Texture {})
    }

    scene.materials = make([dynamic]GPU_Material, 0, len(model.materials), scene.allocator)
    for index in 0 ..< len(model.materials) {
        append(&scene.materials, create_material(ctx, scene, &model.materials[index]))
    }
}

// --------------------------------------------------------------- geometry --

create_geometry_buffers :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    scene.vertex_buffer = gpu.device_create_buffer_with_data(
        ctx.device,
        {label = TITLE + " - vertex buffer", usage = {.Vertex, .Copy_Dst}},
        scene.model.vertices[:],
    )
    scene.index_buffer = gpu.device_create_buffer_with_data(
        ctx.device,
        {label = TITLE + " - index buffer", usage = {.Index, .Copy_Dst}},
        scene.model.indices[:],
    )
}

// -------------------------------------------------------------- instances --

// One storage buffer per mesh, sized for the shader's fixed instance array,
// plus the instance list rebuilt from the model during uploads.
create_instance_buffers :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    model := &scene.model
    scene.meshes = make([dynamic]Mesh_Device, 0, len(model.meshes), scene.allocator)
    for mesh_index in 0 ..< len(model.meshes) {
        cpu_mesh := &model.meshes[mesh_index]
        count := int(cpu_mesh.instance_count)
        if count > INSTANCE_CAPACITY {
            log.errorf(
                "Mesh %d is instanced %d times; only %d fit the shader's instance array",
                mesh_index,
                count,
                INSTANCE_CAPACITY,
            )
            count = INSTANCE_CAPACITY
        }
        mesh := Mesh_Device {
            instances = make([dynamic]Model_Instance, 0, count, scene.allocator),
            buffer = gpu.device_create_buffer(
                ctx.device,
                {
                    label = fmt.tprintf(TITLE + " - mesh %d instances", mesh_index),
                    size = u64(INSTANCE_CAPACITY) * u64(size_of(Model_Instance)),
                    usage = {.Storage, .Copy_Dst},
                },
            ),
            instance_count = u32(count),
        }
        append(&scene.meshes, mesh)
    }
    upload_instances(ctx, scene)
}

// Fills the per-mesh instance arrays from the current node globals and uploads
// the storage buffers. When the model is static this is called once at load;
// an animated model calls it every frame after the core animation update. Only
// the (clamped) instance count entries are written.
upload_instances :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    model := &scene.model
    for mesh_index in 0 ..< len(scene.meshes) {
        mesh := &scene.meshes[mesh_index]
        if mesh.instance_count == 0 {
            continue
        }
        clear(&mesh.instances)
        cpu_mesh := &model.meshes[mesh_index]
        for i in 0 ..< int(mesh.instance_count) {
            node_index := cpu_mesh.instance_nodes[i]
            global := model.nodes[node_index].global
            append(
                &mesh.instances,
                Model_Instance {
                    matrix4 = global,
                    inv_tr  = app.gltf_model_inverse_transpose_or_identity(global),
                },
            )
        }
        gpu.queue_write_buffer(ctx.queue, mesh.buffer, 0, gpu.to_bytes(mesh.instances[:]))
    }
}

update_scene_animations :: proc(ctx: ^app.Application, state: ^State, t: f32) {
    if !state.model_loaded {
        return
    }
    scene := &state.scene
    if !scene.model.has_animations {
        return
    }
    app.gltf_model_animate_all(&scene.model, t)
    upload_instances(ctx, scene)
}

// --------------------------------------------------------------- draw items --

build_draw_items :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    model := &scene.model
    scene.opaque = make([dynamic]Draw_Item, 0, 0, scene.allocator)
    scene.blended = make([dynamic]Draw_Item, 0, 0, scene.allocator)

    for mesh_index in 0 ..< len(model.meshes) {
        cpu_mesh := &model.meshes[mesh_index]
        mesh := &scene.meshes[mesh_index]
        if mesh.instance_count == 0 {
            continue
        }
        for primitive_index in 0 ..< len(cpu_mesh.primitives) {
            primitive := &cpu_mesh.primitives[primitive_index]
            material := &scene.materials[primitive.material]

            entries := make(
                []gpu.Bind_Group_Entry,
                1 + TEXTURE_SLOT_COUNT * 2 + 1,
                context.temp_allocator,
            )
            entries[0] = {
                binding = 0,
                resource = gpu.Buffer_Binding {
                    buffer = mesh.buffer,
                    offset = 0,
                    size = u64(INSTANCE_CAPACITY) * u64(size_of(Model_Instance)),
                },
            }
            for slot in 0 ..< TEXTURE_SLOT_COUNT {
                texture := material.textures[slot]
                entries[1 + slot * 2] = {
                    binding = u32(1 + slot * 2),
                    resource = texture.sampler,
                }
                entries[2 + slot * 2] = {
                    binding = u32(2 + slot * 2),
                    resource = texture.view,
                }
            }
            entries[1 + TEXTURE_SLOT_COUNT * 2] = {
                binding = u32(1 + TEXTURE_SLOT_COUNT * 2),
                resource = gpu.Buffer_Binding {
                    buffer = material.uniform_buffer,
                    offset = 0,
                    size = size_of(Material_Uniforms),
                },
            }

            bind_group := gpu.device_create_bind_group(
                ctx.device,
                {
                    label = fmt.tprintf(TITLE + " - mesh %d primitive %d bind group", mesh_index, primitive_index),
                    layout = state.material_layout,
                    entries = entries,
                },
            )
            item := Draw_Item {
                mesh           = mesh_index,
                primitive      = primitive_index,
                bind_group     = bind_group,
                instance_count = mesh.instance_count,
            }
            if material.alpha_mode == .Blend {
                append(&scene.blended, item)
            } else {
                append(&scene.opaque, item)
            }
        }
    }
}

// ------------------------------------------------------------ load/unload --

device_build_scene :: proc(ctx: ^app.Application, scene: ^Model_Scene) {
    init_default_textures(ctx, scene)
    create_geometry_buffers(ctx, scene)
    create_materials(ctx, scene)
    create_instance_buffers(ctx, scene)
    build_draw_items(ctx, scene)
}

// Uploads a freshly parsed framework model to the GPU and rebuilds the scene's
// device resources.
load_model :: proc(ctx: ^app.Application, path: string) -> bool {
    if state.model_loaded {
        unload_model(&state)
    }
    model, ok := app.gltf_model_load(path, state.allocator)
    if !ok {
        return false
    }
    state.scene = Model_Scene {
        allocator = state.allocator,
        model     = model,
    }
    device_build_scene(ctx, &state.scene)
    state.model_loaded = true
    state.total_time = 0
    if len(state.scene.model.preset_cameras) > 0 {
        log.infof("  Press C to switch between the orbit camera and the %d preset camera(s)", len(state.scene.model.preset_cameras))
    }
    return true
}

unload_model :: proc(state: ^State) {
    if !state.model_loaded {
        return
    }
    unload_model_scene(&state.scene)
    state.model_loaded = false
}

release_texture :: proc(texture: GPU_Texture) {
    if !texture.owns {
        return
    }
    gpu.sampler_release(texture.sampler)
    gpu.texture_view_release(texture.view)
    gpu.texture_release(texture.texture)
}

unload_model_scene :: proc(scene: ^Model_Scene) {
    for &item in scene.blended {
        gpu.bind_group_release(item.bind_group)
    }
    for &item in scene.opaque {
        gpu.bind_group_release(item.bind_group)
    }
    delete(scene.blended)
    delete(scene.opaque)

    for &mesh in scene.meshes {
        if mesh.buffer != {} {
            gpu.buffer_release(mesh.buffer)
        }
        delete(mesh.instances)
    }
    delete(scene.meshes)

    for &material in scene.materials {
        if material.uniform_buffer != {} {
            gpu.buffer_release(material.uniform_buffer)
        }
    }
    delete(scene.materials)

    for &entry in scene.texture_cache {
        release_texture(entry)
    }
    delete(scene.texture_cache)

    for &texture in scene.default_textures {
        release_texture(texture)
    }

    if scene.vertex_buffer != {} {
        gpu.buffer_release(scene.vertex_buffer)
    }
    if scene.index_buffer != {} {
        gpu.buffer_release(scene.index_buffer)
    }

    app.gltf_model_unload(&scene.model)
    scene^ = {}
}
