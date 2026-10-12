#+build !js
package application

import "core:testing"
import "core:math"
import la "core:math/linalg"
import "../../utils/gltf"

// glTF model core tests. Asset paths are relative to the test working
// directory (`examples`), matching the built-in models under `build/assets`.

float_close :: proc(a, b: f32, epsilon := f32(1e-5)) -> bool {
    return math.abs(a - b) <= epsilon
}

@(test)
gltf_model_load_parses_cube :: proc(t: ^testing.T) {
    model, ok := gltf_model_load("build/assets/models/cube.gltf", context.temp_allocator)
    if !testing.expect(t, ok, "cube.gltf loads") {
        return
    }
    defer gltf_model_unload(&model)

    testing.expect_value(t, len(model.vertices), 24)
    testing.expect_value(t, len(model.indices), 36)
    testing.expect_value(t, len(model.meshes), 1)
    testing.expect_value(t, len(model.meshes[0].primitives), 1)
    testing.expect_value(t, int(model.meshes[0].instance_count), 1)
    // materials = 1 synthesized default + 1 from the document.
    testing.expect_value(t, len(model.materials), 2)
    testing.expect_value(t, model.materials[1].double_sided, true)
    mat := model.materials[1]
    testing.expect(t, float_close(mat.base_color_factor.x, 0.8), "base color factor")
    testing.expect(t, float_close(mat.metallic_factor, 0), "metallic factor")
    testing.expect(t, float_close(mat.roughness_factor, 0.5), "roughness factor")
    testing.expect_value(t, len(model.nodes), 3)
    testing.expect_value(t, len(model.textures), 0)
    testing.expect_value(t, len(model.animations), 0)
    testing.expect_value(t, len(model.preset_cameras), 0)
    testing.expect(t, !model.has_animations, "cube is static")

    // The mesh node is instanced once under its rotated parent; the bounds
    // must come out finite and positive.
    testing.expect(t, model.radius > 0, "model radius")
    // The base64 data URI buffer must have parsed: vertex 0's position stays
    // inside the accessor's declared [-5, 5] box.
    p := model.vertices[0].position
    testing.expect(
        t,
        math.abs(p.x) <= 5 && math.abs(p.y) <= 5 && math.abs(p.z) <= 5,
        "vertex 0 position from data URI buffer",
    )
}

@(test)
gltf_model_load_parses_animated_cube_cam :: proc(t: ^testing.T) {
    model, ok := gltf_model_load("build/assets/models/animated_cube_cam.gltf", context.temp_allocator)
    if !testing.expect(t, ok, "animated_cube_cam.gltf loads") {
        return
    }
    defer gltf_model_unload(&model)

    testing.expect_value(t, len(model.animations), 1)
    testing.expect(t, model.has_animations)
    testing.expect_value(t, len(model.animations[0].channels), 1)
    testing.expect_value(t, len(model.preset_cameras), 1)
    testing.expect_value(t, len(model.nodes), 4)
    testing.expect_value(t, int(model.meshes[0].instance_count), 1)

    preset := model.preset_cameras[0]
    testing.expect(t, preset.perspective, "preset camera is perspective")
    testing.expect_value(t, preset.node, 3)
    testing.expect(t, float_close(preset.yfov, 0.7853981634), "preset yfov")
    // The camera node carries its own world translation.
    testing.expect(t, float_close(model.nodes[3].global[3].x, 0), "camera eye x")
    testing.expect(t, float_close(model.nodes[3].global[3].y, 2), "camera eye y")
    testing.expect(t, float_close(model.nodes[3].global[3].z, 12), "camera eye z")
    testing.expect(t, !model.nodes[3].animated, "camera node is not animated")

    // Clock back to the first keyframe: the channel's own first output.
    channel := &model.animations[0].channels[0]
    static_eye := model.nodes[channel.node].global[3]
    gltf_model_animate_all(&model, 0.0)
    testing.expect(
        t,
        float_close(model.nodes[channel.node].translation.x, channel.values[0]) &&
        float_close(model.nodes[channel.node].translation.y, channel.values[1]) &&
        float_close(model.nodes[channel.node].translation.z, channel.values[2]),
        "first keyframe sampled at t=0",
    )
    // Midpoint of the two linear keys: halfway between the keyframes.
    v1 := la.Vector3f32{channel.values[0], channel.values[1], channel.values[2]}
    v2 := la.Vector3f32{channel.values[3], channel.values[4], channel.values[5]}
    expected := (v1 + v2) * 0.5
    gltf_model_animate_all(&model, 1.0)
    testing.expect(
        t,
        float_close(model.nodes[channel.node].translation.x, expected.x) &&
        float_close(model.nodes[channel.node].translation.y, expected.y) &&
        float_close(model.nodes[channel.node].translation.z, expected.z),
        "linear midpoint sampled at t=1",
    )
    testing.expect(t, model.nodes[channel.node].global[3] != static_eye, "animation moved the node")
}

@(test)
gltf_model_default_material_is_first :: proc(t: ^testing.T) {
    model, ok := gltf_model_load("build/assets/models/cube.gltf", context.temp_allocator)
    if !testing.expect(t, ok, "cube.gltf loads") {
        return
    }
    defer gltf_model_unload(&model)

    // Index 0 is the synthesized default: white, opaque, no textures.
    def := model.materials[0]
    testing.expect(t, float_close(def.base_color_factor.x, 1) && float_close(def.base_color_factor.w, 1), "default base color")
    testing.expect_value(t, def.alpha_mode, gltf.Alpha_Mode.Opaque)
    testing.expect_value(t, def.slots[Gltf_Texture_Slot_Base_Color].texture, -1)
    // The primitive's material index must point past the default.
    testing.expect_value(t, model.meshes[0].primitives[0].material, 1)
}