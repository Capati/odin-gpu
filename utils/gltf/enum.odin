package gltf

// Core
import "core:math"

// Enum-typed glTF members arrive here as plain `int` (or `string` for the
// handful of members that are string-enumed in the schema) and are converted
// by these explicit switches. An unrecognised value is an error rather than
// being mapped onto the zero value, which would silently turn an unsupported
// rendering mode into "points".

// The default outer cone angle of a punctual spot light, as mandated by
// KHR_lights_punctual: PI/4.
DEFAULT_SPOT_OUTER_CONE_ANGLE :: 0.78539816

// The default `iridescenceThicknessMinimum`/`Maximum`, from
// KHR_materials_iridescence.
DEFAULT_IRIDESCENCE_THICKNESS_MIN :: 100.0
DEFAULT_IRIDESCENCE_THICKNESS_MAX :: 400.0

// The default `attenuationDistance`, from KHR_materials_volume.  The schema
// default is effectively "infinite", and FLT_MAX is what the C original used.
DEFAULT_ATTENUATION_DISTANCE :: 3.402823466e+38

// The largest value glTF permits for an index or a byte offset.  Anything
// larger is a corrupt or hostile file, and bounding it keeps the index
// arithmetic in `accessor.odin` from overflowing.
MAX_GLTF_INDEX :: 0x7FFFFFFF

@(private)
component_type_from_int :: proc "contextless" (value: int) -> Maybe(Component_Type) {
    switch value {
    case 5120:
        return .Byte
    case 5121:
        return .Unsigned_Byte
    case 5122:
        return .Short
    case 5123:
        return .Unsigned_Short
    case 5125:
        return .Unsigned_Int
    case 5126:
        return .Float
    case:
        return nil
    }
}

@(private)
element_type_from_string :: proc(value: string) -> Maybe(Element_Type) {
    switch value {
    case "SCALAR":
        return Element_Type.Scalar
    case "VEC2":
        return Element_Type.Vec2
    case "VEC3":
        return Element_Type.Vec3
    case "VEC4":
        return Element_Type.Vec4
    case "MAT2":
        return Element_Type.Mat2
    case "MAT3":
        return Element_Type.Mat3
    case "MAT4":
        return Element_Type.Mat4
    case:
        return nil
    }
}

@(private)
buffer_view_target_from_int :: proc "contextless" (value: int) -> Maybe(Buffer_View_Target) {
    switch value {
    case 0:
        return .Invalid
    case 34962:
        return .Array_Buffer
    case 34963:
        return .Element_Array_Buffer
    case:
        return nil
    }
}

@(private)
primitive_mode_from_int :: proc "contextless" (value: int) -> Maybe(Primitive_Mode) {
    switch value {
    case 0:
        return .Points
    case 1:
        return .Lines
    case 2:
        return .Line_Loop
    case 3:
        return .Line_Strip
    case 4:
        return .Triangles
    case 5:
        return .Triangle_Strip
    case 6:
        return .Triangle_Fan
    case:
        return nil
    }
}

@(private)
alpha_mode_from_string :: proc "contextless" (value: string) -> Maybe(Alpha_Mode) {
    switch value {
    case "":
        return Alpha_Mode.Opaque
    case "OPAQUE":
        return Alpha_Mode.Opaque
    case "MASK":
        return Alpha_Mode.Mask
    case "BLEND":
        return Alpha_Mode.Blend
    case:
        return nil
    }
}

@(private)
animation_path_from_string :: proc "contextless" (value: string) -> Maybe(Animation_Path) {
    switch value {
    case "translation":
        return Animation_Path.Translation
    case "rotation":
        return Animation_Path.Rotation
    case "scale":
        return Animation_Path.Scale
    case "weights":
        return Animation_Path.Weights
    case "pointer":
        return Animation_Path.Pointer
    case:
        return nil
    }
}

@(private)
interpolation_from_string :: proc "contextless" (value: string) -> Maybe(Interpolation) {
    switch value {
    case "":
        // LINEAR is the schema default.
        return Interpolation.Linear
    case "LINEAR":
        return Interpolation.Linear
    case "STEP":
        return Interpolation.Step
    case "CUBICSPLINE":
        return Interpolation.Cubic_Spline
    case:
        return nil
    }
}

@(private)
camera_type_from_string :: proc "contextless" (value: string) -> Maybe(Camera_Type) {
    switch value {
    case "perspective":
        return Camera_Type.Perspective
    case "orthographic":
        return Camera_Type.Orthographic
    case:
        return nil
    }
}

@(private)
light_type_from_string :: proc "contextless" (value: string) -> Maybe(Light_Type) {
    switch value {
    case "directional":
        return Light_Type.Directional
    case "point":
        return Light_Type.Point
    case "spot":
        return Light_Type.Spot
    case:
        return nil
    }
}

@(private)
filter_type_from_int :: proc "contextless" (value: int) -> Maybe(Filter_Type) {
    switch value {
    case 0:
        return Filter_Type.Undefined
    case 9728:
        return Filter_Type.Nearest
    case 9729:
        return Filter_Type.Linear
    case 9984:
        return Filter_Type.Nearest_Mipmap_Nearest
    case 9985:
        return Filter_Type.Linear_Mipmap_Nearest
    case 9986:
        return Filter_Type.Nearest_Mipmap_Linear
    case 9987:
        return Filter_Type.Linear_Mipmap_Linear
    case:
        return nil
    }
}

@(private)
wrap_mode_from_int :: proc "contextless" (value: int) -> Maybe(Wrap_Mode) {
    switch value {
    case 0, 10497:
        // REPEAT is the schema default, so 0 means "absent".
        return Wrap_Mode.Repeat
    case 33071:
        return Wrap_Mode.Clamp_To_Edge
    case 33648:
        return Wrap_Mode.Mirrored_Repeat
    case:
        return nil
    }
}

@(private)
meshopt_mode_from_string :: proc "contextless" (value: string) -> Maybe(Meshopt_Compression_Mode) {
    switch value {
    case "":
        return Meshopt_Compression_Mode.Attributes
    case "ATTRIBUTES":
        return Meshopt_Compression_Mode.Attributes
    case "TRIANGLES":
        return Meshopt_Compression_Mode.Triangles
    case "INDICES":
        return Meshopt_Compression_Mode.Indices
    case:
        return nil
    }
}

@(private)
meshopt_filter_from_string :: proc "contextless" (
    value: string,
) -> Maybe(Meshopt_Compression_Filter) {
    switch value {
    case "":
        return Meshopt_Compression_Filter.None
    case "NONE":
        return Meshopt_Compression_Filter.None
    case "OCTAHEDRAL":
        return Meshopt_Compression_Filter.Octahedral
    case "QUATERNION":
        return Meshopt_Compression_Filter.Quaternion
    case "EXPONENTIAL":
        return Meshopt_Compression_Filter.Exponential
    case "COLOR":
        return Meshopt_Compression_Filter.Color
    case:
        return nil
    }
}

// Validates an index-valued member.
@(private)
checked_index :: proc "contextless" (index: int) -> Maybe(int) {
    if index < 0 || index > MAX_GLTF_INDEX {
        return nil
    }
    return index
}

// Rejects NaN and infinity in members where the schema requires a finite number.
// Strict JSON cannot produce either, but a caller can hand-build a `Document`.
@(private)
is_finite :: #force_inline proc "contextless" (value: f32) -> bool {
    return !math.is_nan(value) && !math.is_inf(value)
}
