/* -------------------------------------------------------------------------- *
 * Camera resources and per-frame updates.
 *
 * The user camera is the framework's orbit `Look_At` camera. The preset
 * cameras come from the model's `cameras` + node structure and trail the node
 * transforms, so an animated camera node follows its animation.
 * -------------------------------------------------------------------------- */

package gltf_viewer2

// Core
import "core:log"

// Vendor
import "../../gpu"

// Local packages
import app "../framework"
import la "core:math/linalg"

// Creates the two uniform buffers and the group-0 bind group shared by every
// draw. Requires `state.camera_layout` to exist already (create_layouts).
create_camera_resources :: proc(ctx: ^app.Application) {
    state.camera_proj_view_buffer = gpu.device_create_buffer(
        ctx.device,
        {
            label = TITLE + " - camera proj*view",
            size = size_of(la.Matrix4f32),
            usage = {.Uniform, .Copy_Dst},
        },
    )
    state.camera_eye_buffer = gpu.device_create_buffer(
        ctx.device,
        {
            label = TITLE + " - camera eye",
            size = 4 * size_of(f32),
            usage = {.Uniform, .Copy_Dst},
        },
    )
    state.camera_bind_group = gpu.device_create_bind_group(
        ctx.device,
        {
            label = TITLE + " - camera bind group",
            layout = state.camera_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = state.camera_proj_view_buffer,
                        offset = 0,
                        size = size_of(la.Matrix4f32),
                    },
                },
                {
                    binding = 1,
                    resource = gpu.Buffer_Binding {
                        buffer = state.camera_eye_buffer,
                        offset = 0,
                        size = 4 * size_of(f32),
                    },
                },
            },
        },
    )
}

release_camera_resources :: proc(state: ^State) {
    gpu.bind_group_release(state.camera_bind_group)
    gpu.buffer_release(state.camera_proj_view_buffer)
    gpu.buffer_release(state.camera_eye_buffer)
}

// Frames the loaded model: the orbit camera looks at the scene centre from
// `radius` units away along +Z (so the internal position is the negated
// point). Directly writing `camera.position` bypasses the setter's y-negation.
frame_user_camera :: proc(ctx: ^app.Application) {
    app.camera_reset_mouse_input(&state.camera)
    scene := &state.scene
    radius := max(scene.model.radius, 1e-3)

    state.camera.position = -(scene.model.center + {0, 0, radius})
    app.camera_update_view_matrix(&state.camera)
    app.camera_set_perspective(
        &state.camera,
        60,
        state.aspect,
        radius * 0.01,
        radius * 100,
    )
}

// The eye is `inverse(view) * origin`. For a rigid transform that is the
// translation column of the inverse view, which is what the shader's
// `eyePosition` expects in world space.
eye_from_view :: proc(view: la.Matrix4f32) -> la.Vector4f32 {
    inverse_view := la.matrix4_inverse_f32(view)
    // Column 3 is the translation column.
    return inverse_view[3]
}

// The orthographic projection from glTF camera parameters, in the [0, 1]
// clip-space convention the renderer targets. xmag defaults to ymag * aspect
// per the glTF specification when only the vertical extent is meaningful (the
// parser keeps both, but a hand-made asset may rely on the default).
ortho_projection :: proc(state: ^State, preset: ^app.Gltf_Preset_Camera) -> la.Matrix4f32 {
    result: la.Matrix4f32
    xmag := preset.xmag
    if xmag <= 0 {
        xmag = preset.ymag * state.aspect
    }
    result[0][0] = 1 / xmag
    result[1][1] = 1 / preset.ymag
    // The viewer writes 1/(znear - zfar) and znear/(znear - zfar): in the
    // [0, 1] WebGPU convention the camera looks down -Z, so the near plane at
    // z = -znear must map to 0.
    result[2][2] = 1 / (preset.znear - preset.zfar)
    result[3][2] = preset.znear / (preset.znear - preset.zfar)
    result[3][3] = 1
    return result
}

// Computes this frame's projection and view from whichever camera is active
// and uploads the camera bind group's buffers.
update_camera :: proc(ctx: ^app.Application, state: ^State, dt: f32) {
    scene := &state.scene
    app.camera_update(&state.camera, dt)

    proj: la.Matrix4f32
    view: la.Matrix4f32

    if state.use_user_camera {
        // The framework's perspective matrix is in the OpenGL [-1, 1] near-z
        // convention; convert it to the renderer's [0, 1].
        proj = state.camera.matrices.perspective
        app.camera_projection_matrix_convert_clip_space_near_z(&proj, .Zero, .Negative_One)
        view = state.camera.matrices.view
    } else {
        if state.camera_index < 0 || state.camera_index >= len(scene.model.preset_cameras) {
            log.warnf("Preset camera index %d out of range; using the user camera",
                state.camera_index)
            proj = state.camera.matrices.perspective
            app.camera_projection_matrix_convert_clip_space_near_z(&proj, .Zero, .Negative_One)
            view = state.camera.matrices.view
        } else {
            preset := &scene.model.preset_cameras[state.camera_index]
            global := scene.model.nodes[preset.node].global
            view = la.matrix4_inverse_f32(global)
            if preset.perspective {
                if preset.zfar < 0 {
                    // No far plane in the document: infinite projection.
                    proj = app.camera_perspective_zo(preset.yfov, state.aspect, preset.znear, nil)
                } else {
                    proj = app.camera_perspective_zo(
                        preset.yfov, state.aspect, preset.znear, preset.zfar)
                }
            } else {
                proj = ortho_projection(state, preset)
            }
        }
    }

    eye := eye_from_view(view)
    proj_view := proj * view
    gpu.queue_write_buffer(ctx.queue, state.camera_proj_view_buffer, 0, gpu.to_bytes(proj_view))
    gpu.queue_write_buffer(ctx.queue, state.camera_eye_buffer, 0, gpu.to_bytes(eye))
}
