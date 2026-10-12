package application

// Core
import "core:math"
import la "core:math/linalg"

Camera_Type :: enum {
    Look_At,
    First_Person,
}

Camera_Keys :: struct {
    left, right, up, down: bool,
}

Camera_Mouse_Buttons :: struct {
    left, middle, right: bool,
}

// Basic look-at/orbit or first-person camera. Matrix/vector storage uses
// core:math/linalg so examples can pass the matrices directly to GPU uniforms.
Camera :: struct {
    rotation:       la.Vector3f32,
    position:       la.Vector3f32,
    view_pos:       la.Vector4f32,
    type:           Camera_Type,
    fov:            f32, // degrees, matching the C camera API
    znear:          f32,
    zfar:           f32,
    rotation_speed: f32, // orbit degrees per pixel (mouse left-drag)
    movement_speed: f32,
    pan_speed:      f32, // world units per pixel (middle-drag)
    zoom_speed:     f32, // world units per pixel (right-drag)
    wheel_speed:    f32, // world units per wheel notch
    // Exponential mouse smoothing time constant in seconds. When <= 0 raw
    // deltas are applied immediately (legacy behavior); otherwise
    // camera_on_input_event accumulates them and camera_update eases them in
    // frame-independently each frame.
    smoothing_tau:  f32,
    updated:        bool,
    flip_y:         bool,
    invert_dx:      bool,
    invert_dy:      bool,
    matrices: struct {
        perspective: la.Matrix4f32,
        view:        la.Matrix4f32,
    },
    keys:                Camera_Keys,
    mouse_buttons:       Camera_Mouse_Buttons,
    last_mouse_position: [2]f32,
    has_mouse_position:  bool,
    // Accumulated mouse deltas not yet applied by camera_update (see
    // smoothing_tau).
    pending_rotate:      la.Vector3f32,
    pending_translate:   la.Vector3f32,
}

Camera_Clip_Space_Near_Z :: enum {
    Negative_One, // OpenGL-style clip-space Z range [-1, 1]
    Zero,         // WebGPU/D3D/Vulkan-style clip-space Z range [0, 1]
}

camera_init :: proc(camera: ^Camera) {
    assert(camera != nil)
    camera^ = {
        type           = .Look_At,
        rotation_speed = 0.25,
        movement_speed = 1,
        pan_speed      = 0.003,
        zoom_speed     = 0.0015,
        wheel_speed    = 0.02,
        smoothing_tau  = 0.1,
        updated        = false,
        flip_y         = false,
    }
}

// Handles mouse gestures and WASD/arrow-key movement. Mouse positions in the
// framework are absolute, so the camera stores the previous cursor position to
// derive the deltas consumed by the C version's input-event API.
camera_on_input_event :: proc(camera: ^Camera, event: Event) {
    assert(camera != nil)

    #partial switch ev in event {
    case Key_Event:
        if ev.action == .None {
            return
        }
        camera_set_key(camera, ev.key, ev.action == .Pressed)

    case Mouse_Button_Event:
        pressed := ev.action == .Pressed
        #partial switch ev.button {
        case .Left:   camera.mouse_buttons.left   = pressed
        case .Middle: camera.mouse_buttons.middle = pressed
        case .Right:  camera.mouse_buttons.right  = pressed
        case:
        }
        // Start dragging from the press position instead of jumping from the
        // last unrelated cursor position.
        camera.last_mouse_position = ev.pos
        camera.has_mouse_position = true

    case Mouse_Motion_Event:
        if !camera.has_mouse_position {
            camera.last_mouse_position = ev.pos
            camera.has_mouse_position = true
            return
        }

        delta := [2]f32{
            ev.pos[0] - camera.last_mouse_position[0],
            ev.pos[1] - camera.last_mouse_position[1],
        }
        camera.last_mouse_position = ev.pos
        inv_dx: f32 = 1.0 if !camera.invert_dx else -1.0
        inv_dy: f32 = 1.0 if !camera.invert_dy else -1.0

        rotate := la.Vector3f32{0, 0, 0}
        translate := la.Vector3f32{0, 0, 0}
        if camera.mouse_buttons.left {
            // Orbit: 1 full degree per pixel is the old aggressive default;
            // rotation_speed now defaults to a calmer 0.25.
            rotate = {
                delta.y * inv_dx * camera.rotation_speed,
                -delta.x * inv_dy * camera.rotation_speed,
                0,
            }
        } else if camera.mouse_buttons.middle {
            translate = {
                -delta.x * inv_dx * camera.pan_speed,
                -delta.y * inv_dy * camera.pan_speed,
                0,
            }
        }
        if camera.mouse_buttons.right {
            translate += {0, 0, delta.y * inv_dy * camera.zoom_speed}
        }
        camera_apply_mouse_delta(camera, rotate, translate)

    case Mouse_Wheel_Event:
        camera_apply_mouse_delta(camera, {}, {0, 0, -ev[1] * camera.wheel_speed})
    }
}

// Applies mouse deltas immediately when smoothing is disabled, or accumulates
// them for camera_update to ease in otherwise.
camera_apply_mouse_delta :: proc(camera: ^Camera, rotate, translate: la.Vector3f32) {
    assert(camera != nil)
    if camera.smoothing_tau > 0 {
        camera.pending_rotate += rotate
        camera.pending_translate += translate
    } else {
        camera_rotate(camera, rotate)
        camera_translate(camera, translate)
    }
}

camera_update :: proc(camera: ^Camera, delta_time: f32) {
    assert(camera != nil)
    camera.updated = false

    // Ease accumulated mouse deltas in for every camera type; the sections
    // below only handle first-person keyboard/gamepad movement.
    apply_smoothed_mouse_input(camera, delta_time)

    if camera.type != .First_Person || !camera_moving(camera) {
        return
    }

    front := camera_front(camera.rotation)
    right := la.normalize(la.cross(front, la.Vector3f32{0, 1, 0}))
    move_speed := delta_time * camera.movement_speed

    if camera.keys.up {
        camera.position += front * move_speed
    }
    if camera.keys.down {
        camera.position -= front * move_speed
    }
    if camera.keys.left {
        camera.position -= right * move_speed
    }
    if camera.keys.right {
        camera.position += right * move_speed
    }
    camera_update_view_matrix(camera)
}

// Applies a frame-independent fraction of the mouse deltas accumulated by
// camera_on_input_event so the camera eases toward the target instead of
// stepping by raw event deltas. No-op when smoothing is disabled.
apply_smoothed_mouse_input :: proc(camera: ^Camera, delta_time: f32) {
    assert(camera != nil)
    if camera.smoothing_tau <= 0 {
        return
    }
    if camera.pending_rotate == {} && camera.pending_translate == {} {
        return
    }
    alpha := 1.0 - math.exp(-delta_time / camera.smoothing_tau)
    rotate := camera.pending_rotate * alpha
    translate := camera.pending_translate * alpha
    camera_rotate(camera, rotate)
    camera_translate(camera, translate)
    camera.pending_rotate -= rotate
    camera.pending_translate -= translate
}

// Gamepad layout: left stick
// moves, right stick rotates. Returns true when the camera changed.
camera_update_pad :: proc(
    camera: ^Camera,
    axis_left, axis_right: [2]f32,
    delta_time: f32,
) -> bool {
    assert(camera != nil)
    if camera.type != .First_Person {
        return false
    }

    dead_zone: f32 = 0.0015
    range: f32 = 1.0 - dead_zone
    front := camera_front(camera.rotation)
    changed := false
    move_speed := delta_time * camera.movement_speed * 2.0
    rotation_speed := delta_time * camera.movement_speed * 50.0

    if math.abs(axis_left[1]) > dead_zone {
        amount := (math.abs(axis_left[1]) - dead_zone) / range
        direction: f32 = 1.0 if axis_left[1] > 0 else -1.0
        camera.position -= front * (amount * direction * move_speed)
        changed = true
    }
    if math.abs(axis_left[0]) > dead_zone {
        amount := (math.abs(axis_left[0]) - dead_zone) / range
        direction: f32 = 1.0 if axis_left[0] > 0 else -1.0
        right := la.normalize(la.cross(front, la.Vector3f32{0, 1, 0}))
        camera.position += right * (amount * direction * move_speed)
        changed = true
    }
    if math.abs(axis_right[0]) > dead_zone {
        amount := (math.abs(axis_right[0]) - dead_zone) / range
        direction: f32 = 1.0 if axis_right[0] > 0 else -1.0
        camera.rotation.y += amount * direction * rotation_speed
        changed = true
    }
    if math.abs(axis_right[1]) > dead_zone {
        amount := (math.abs(axis_right[1]) - dead_zone) / range
        direction: f32 = 1.0 if axis_right[1] > 0 else -1.0
        camera.rotation.x -= amount * direction * rotation_speed
        changed = true
    }

    if changed {
        camera_update_view_matrix(camera)
    }
    return changed
}

camera_update_view_matrix :: proc(camera: ^Camera) {
    assert(camera != nil)

    flip: f32 = -1.0 if camera.flip_y else 1.0
    rotation := la.MATRIX4F32_IDENTITY
    rotation = rotation * la.matrix4_rotate_f32(
        camera_degrees_to_radians(camera.rotation.x * flip), {1, 0, 0})
    rotation = rotation * la.matrix4_rotate_f32(
        camera_degrees_to_radians(camera.rotation.y), {0, 1, 0})
    rotation = rotation * la.matrix4_rotate_f32(
        camera_degrees_to_radians(camera.rotation.z), {0, 0, 1})

    translation := camera.position
    if camera.flip_y {
        translation.y *= -1
    }
    translation_matrix := la.matrix4_translate_f32(translation)

    if camera.type == .First_Person {
        camera.matrices.view = rotation * translation_matrix
    } else {
        camera.matrices.view = translation_matrix * rotation
    }

    camera.view_pos = {
        -camera.position.x,
        camera.position.y,
        -camera.position.z,
        0,
    }
    camera.updated = true
}

camera_set_position :: proc(camera: ^Camera, position: la.Vector3f32) {
    assert(camera != nil)
    camera.position = {position.x, -position.y, position.z}
    camera_update_view_matrix(camera)
}

camera_set_rotation :: proc(camera: ^Camera, rotation: la.Vector3f32) {
    assert(camera != nil)
    camera.rotation = rotation
    camera_update_view_matrix(camera)
}

camera_rotate :: proc(camera: ^Camera, delta: la.Vector3f32) {
    assert(camera != nil)
    camera.rotation += {delta.x, -delta.y, delta.z}
    camera_update_view_matrix(camera)
}

camera_set_translation :: proc(camera: ^Camera, translation: la.Vector3f32) {
    assert(camera != nil)
    camera.position = translation
    camera_update_view_matrix(camera)
}

camera_translate :: proc(camera: ^Camera, delta: la.Vector3f32) {
    assert(camera != nil)
    camera.position += {-delta.x, delta.y, -delta.z}
    camera_update_view_matrix(camera)
}

camera_set_rotation_speed :: proc(camera: ^Camera, rotation_speed: f32) {
    assert(camera != nil)
    camera.rotation_speed = rotation_speed
}

camera_set_movement_speed :: proc(camera: ^Camera, movement_speed: f32) {
    assert(camera != nil)
    camera.movement_speed = movement_speed
}

// Drops any in-flight mouse drag state so a partially-eased gesture cannot
// bleed into a newly framed model or camera view.
camera_reset_mouse_input :: proc(camera: ^Camera) {
    assert(camera != nil)
    camera.mouse_buttons = {}
    camera.has_mouse_position = false
    camera.pending_rotate = {}
    camera.pending_translate = {}
}

// `fov` is in degrees.
camera_set_perspective :: proc(camera: ^Camera, fov, aspect, znear, zfar: f32) {
    assert(camera != nil)
    camera.fov = fov
    camera.znear = znear
    camera.zfar = zfar
    camera.matrices.perspective = la.matrix4_perspective_f32(
        camera_degrees_to_radians(fov), aspect, znear, zfar)
    if camera.flip_y {
        camera.matrices.perspective[1, 1] *= -1
    }
}

camera_update_aspect_ratio :: proc(camera: ^Camera, aspect: f32) {
    assert(camera != nil)
    camera.matrices.perspective = la.matrix4_perspective_f32(
        camera_degrees_to_radians(camera.fov), aspect, camera.znear, camera.zfar)
    if camera.flip_y {
        camera.matrices.perspective[1, 1] *= -1
    }
}

camera_moving :: proc(camera: ^Camera) -> bool {
    assert(camera != nil)
    return camera.keys.left || camera.keys.right || camera.keys.up || camera.keys.down
}

camera_get_near_clip :: proc(camera: ^Camera) -> f32 {
    assert(camera != nil)
    return camera.znear
}

camera_get_far_clip :: proc(camera: ^Camera) -> f32 {
    assert(camera != nil)
    return camera.zfar
}

// Converts between clip-space conventions using the same conversion matrices
// as the C framework's camera projection helpers.
camera_projection_matrix_convert_clip_space_near_z :: proc(
    projection: ^la.Matrix4f32,
    destination, source: Camera_Clip_Space_Near_Z,
) {
    assert(projection != nil)
    if destination == source {
        return
    }

    OPENGL_TO_WGPU :: la.Matrix4f32{
        1, 0, 0,   0,
        0, 1, 0,   0,
        0, 0, 0.5, 0.5,
        0, 0, 0,   1,
    }
    WGPU_TO_OPENGL :: la.Matrix4f32{
        1, 0, 0,  0,
        0, 1, 0,  0,
        0, 0, 2, -1,
        0, 0, 0,  1,
    }

    if destination == .Zero {
        projection^ = OPENGL_TO_WGPU * projection^
    } else {
        projection^ = WGPU_TO_OPENGL * projection^
    }
}

// The reversed-Z helpers take fovy in radians, like their C counterparts.
camera_perspective_matrix_reversed_z :: proc(
    fovy, aspect, znear, zfar: f32,
) -> (projection: la.Matrix4f32) {
    tan_half_fovy := math.tan(fovy * 0.5)
    range := zfar / (znear - zfar)
    projection[0, 0] = (1 / tan_half_fovy) / aspect
    projection[1, 1] = 1 / tan_half_fovy
    projection[2, 2] = -range - 1
    projection[2, 3] = -znear * range
    projection[3, 2] = -1
    return
}

camera_perspective_matrix_reversed_z_infinite_far :: proc(
    fovy, aspect, znear: f32,
) -> (projection: la.Matrix4f32) {
    tan_half_fovy := math.tan(fovy * 0.5)
    projection[0, 0] = (1 / tan_half_fovy) / aspect
    projection[1, 1] = 1 / tan_half_fovy
    projection[2, 3] = znear
    projection[3, 2] = -1
    return
}

// WebGPU/D3D/Metal [0, 1] projection helper. Pass nil for an infinite far plane.
camera_perspective_zo :: proc(
    fovy, aspect, znear: f32,
    zfar: Maybe(f32),
) -> (projection: la.Matrix4f32) {
    tan_half_fovy := math.tan(fovy * 0.5)
    projection[0, 0] = 1 / (aspect * tan_half_fovy)
    projection[1, 1] = 1 / tan_half_fovy
    projection[3, 2] = -1

    if far, ok := zfar.?; ok && !math.is_inf(far) {
        nf := 1 / (znear - far)
        projection[2, 2] = far * nf
        projection[2, 3] = far * znear * nf
    } else {
        projection[2, 2] = -1
        projection[2, 3] = -znear
    }
    return
}

@(private="file")
camera_set_key :: proc(camera: ^Camera, key: Key, pressed: bool) {
    #partial switch key {
    case .A, .Left:  camera.keys.left  = pressed
    case .D, .Right: camera.keys.right = pressed
    case .W, .Up:    camera.keys.up    = pressed
    case .S, .Down:  camera.keys.down  = pressed
    case:
    }
}

@(private="file")
camera_front :: proc(rotation: la.Vector3f32) -> la.Vector3f32 {
    pitch := camera_degrees_to_radians(rotation.x)
    yaw := camera_degrees_to_radians(rotation.y)
    front := la.Vector3f32{
        -math.cos(pitch) * math.sin(yaw),
         math.sin(pitch),
         math.cos(pitch) * math.cos(yaw),
    }
    return la.normalize(front)
}

@(private="file")
camera_degrees_to_radians :: #force_inline proc(degrees: f32) -> f32 {
    return degrees * (math.PI / 180)
}
