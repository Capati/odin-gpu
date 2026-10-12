#+build !js
package application

import "core:testing"
import la "core:math/linalg"

@(test)
camera_init_sets_c_defaults :: proc(t: ^testing.T) {
    camera: Camera
    camera_init(&camera)

    testing.expect_value(t, camera.type, Camera_Type.Look_At)
    testing.expect_value(t, camera.rotation_speed, 0.25)
    testing.expect_value(t, camera.movement_speed, 1.0)
    testing.expect_value(t, camera.pan_speed, 0.003)
    testing.expect_value(t, camera.zoom_speed, 0.0015)
    testing.expect_value(t, camera.wheel_speed, 0.02)
    testing.expect_value(t, camera.smoothing_tau, 0.1)
    testing.expect(t, !camera.updated)
    testing.expect(t, !camera.flip_y)
}

@(test)
camera_mouse_drag_rotates_from_press_position :: proc(t: ^testing.T) {
    camera: Camera
    camera_init(&camera)

    camera_on_input_event(&camera, Mouse_Button_Event{
        button = .Left,
        pos    = {10, 20},
        action = .Pressed,
    })
    camera_on_input_event(&camera, Mouse_Motion_Event{pos = {18, 24}})

    // With smoothing enabled the deltas are accumulated (scaled by the 0.25
    // default rotation_speed) and applied by camera_update.
    testing.expect_value(t, camera.pending_rotate.x, 1.0) // 4 px * 0.25
    testing.expect_value(t, camera.pending_rotate.y, -2.0) // -8 px * 0.25
    testing.expect_value(t, camera.rotation.x, 0.0)

    camera_update(&camera, 5.0) // large dt: alpha ~ 1, whole delta applied

    testing.expect_value(t, camera.rotation.x, 1.0)
    testing.expect_value(t, camera.rotation.y, 2.0)
    testing.expect(t, camera.updated)
    testing.expect(t, camera.pending_rotate == la.Vector3f32{0, 0, 0})

    camera_on_input_event(&camera, Mouse_Button_Event{
        button = .Left,
        pos    = {18, 24},
        action = .Released,
    })
}

@(test)
camera_mouse_drag_rotates_immediately_without_smoothing :: proc(t: ^testing.T) {
    camera: Camera
    camera_init(&camera)
    camera.smoothing_tau = 0
    camera.rotation_speed = 1 // legacy default

    camera_on_input_event(&camera, Mouse_Button_Event{
        button = .Left,
        pos    = {10, 20},
        action = .Pressed,
    })
    camera_on_input_event(&camera, Mouse_Motion_Event{pos = {18, 24}})

    testing.expect_value(t, camera.rotation.x, 4.0)
    testing.expect_value(t, camera.rotation.y, 8.0)
    testing.expect(t, camera.updated)

    camera_on_input_event(&camera, Mouse_Button_Event{
        button = .Left,
        pos    = {18, 24},
        action = .Released,
    })
}

@(test)
camera_reset_mouse_input_clears_pending_deltas :: proc(t: ^testing.T) {
    camera: Camera
    camera_init(&camera)

    camera_on_input_event(&camera, Mouse_Button_Event{
        button = .Left,
        pos    = {10, 20},
        action = .Pressed,
    })
    camera_on_input_event(&camera, Mouse_Motion_Event{pos = {18, 24}})

    camera_reset_mouse_input(&camera)
    testing.expect(t, camera.pending_rotate == la.Vector3f32{})
    testing.expect(t, camera.pending_translate == la.Vector3f32{})
    testing.expect(t, !camera.mouse_buttons.left)
    testing.expect(t, !camera.has_mouse_position)
}

@(test)
camera_first_person_keyboard_moves_forward :: proc(t: ^testing.T) {
    camera: Camera
    camera_init(&camera)
    camera.type = .First_Person
    camera_on_input_event(&camera, Key_Event{key = .W, action = .Pressed})
    camera_update(&camera, 2.0)

    testing.expect_value(t, camera.position.x, 0.0)
    testing.expect_value(t, camera.position.y, 0.0)
    testing.expect_value(t, camera.position.z, 2.0)
    testing.expect(t, camera.updated)

    camera_on_input_event(&camera, Key_Event{key = .W, action = .Released})
    testing.expect(t, !camera_moving(&camera))
}

@(test)
camera_clip_space_conversion_round_trips_identity :: proc(t: ^testing.T) {
    projection := la.MATRIX4F32_IDENTITY
    camera_projection_matrix_convert_clip_space_near_z(
        &projection,
        .Zero,
        .Negative_One,
    )
    testing.expect_value(t, projection[2, 2], 0.5)
    testing.expect_value(t, projection[2, 3], 0.5)

    camera_projection_matrix_convert_clip_space_near_z(
        &projection,
        .Negative_One,
        .Zero,
    )
    for y in 0..<4 {
        for x in 0..<4 {
            expected := f32(1) if y == x else f32(0)
            testing.expect_value(t, projection[y, x], expected)
        }
    }
}
