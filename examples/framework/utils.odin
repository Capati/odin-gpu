package application

// Core
import "core:math"
import intr "base:intrinsics"
import la "core:math/linalg"

// Note: Models centered on (0, 0, 0) will be halfway inside the clipping area.
// This is for when you aren't using a camera matrix.
OPEN_GL_TO_WGPU_MATRIX :: la.Matrix4f32 {
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.5, 0.5,
    0.0, 0.0, 0.0, 1.0,
}

create_view_projection_matrix :: proc "contextless" (aspect: f32) -> la.Matrix4f32 {
    // 72 deg FOV (2 * PI / 5 radians)
    projection := la.matrix4_perspective_f32(2 * math.PI / 5, aspect, 1.0, 100.0)
    view := la.matrix4_look_at_f32(
        eye = {1.1, 1.1, 1.1},
        centre = {0.0, 0.0, 0.0},
        up = {0.0, 1.0, 0.0},
    )
    return OPEN_GL_TO_WGPU_MATRIX * projection * view
}

value_or :: #force_inline proc "contextless" (val, def: $T) -> T
        where intr.type_is_comparable(T) {
    return def if val == {} else val
}

perspective_zo :: proc "contextless" (
    fovy, aspect, near, far: f32,
) -> (m: la.Matrix4f32) #no_bounds_check {
    tan_half_fovy := math.tan(0.5 * fovy)
    m[0, 0] = 1 / (aspect * tan_half_fovy)
    m[1, 1] = 1 / tan_half_fovy
    m[2, 2] = far / (near - far)
    m[2, 3] = (near * far) / (near - far)
    m[3, 2] = -1
    return
}
