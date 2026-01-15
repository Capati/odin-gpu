package gpu

// Core
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:reflect"
import intr "base:intrinsics"

_ :: reflect

// Integral type used for `Buffer` offsets and sizes.
Buffer_Address :: u64

// Integral type used for `Buffer_Slice` sizes.
Buffer_Size :: u64

// Integral type used for binding locations in shaders.
//
// Used in `Vertex_Attribute`s.
Shader_Location :: u32

// Integral type used for dynamic bind group offsets.
Dynamic_Offset :: u32

Flags :: u64

// Buffer-texture copies must have `bytes_per_row` aligned to this number.
//
// This doesn't apply to `queue_write_texture`, only to `queue_copy_buffer_to_texture()`
// and `queue_copy_texture_to_buffer()`.
COPY_BYTES_PER_ROW_ALIGNMENT: u32 : 256

// An [offset into the query resolve buffer] has to be aligned to this.
QUERY_RESOLVE_BUFFER_ALIGNMENT: Buffer_Address : 256

// Buffer to buffer copy as well as buffer clear offsets and sizes must be
// aligned to this number.
COPY_BUFFER_ALIGNMENT: Buffer_Address : 4

/* Buffer alignment mask to calculate proper size. */
COPY_BUFFER_ALIGNMENT_MASK :: COPY_BUFFER_ALIGNMENT - 1

// Minimum alignment of buffer mappings.
//
// The range passed to `buffer_map_async()` or `buffer_get_mapped_range()` must
// be at least this aligned.
MAP_ALIGNMENT: Buffer_Address : 8

// Vertex buffer offsets and strides have to be a multiple of this number.
VERTEX_ALIGNMENT: Buffer_Address : 4

// Vertex buffer strides have to be a multiple of this number.
VERTEX_STRIDE_ALIGNMENT: Buffer_Address : 4

// Ranges of writes to push constant storage must be at least this aligned.
PUSH_CONSTANT_ALIGNMENT: u32 : 4

// Maximum queries in a `Query_Set_Descriptor`.
QUERY_SET_MAX_QUERIES: u32 : 4096

// Size in bytes of a single piece of query data.
QUERY_SIZE: u32 : 8

// Indicates no query set index is specified. For more info.
QUERY_SET_INDEX_UNDEFINED :: max(u32)

MAX_CONCURRENT_SHADER_STAGES :: 3
MAX_ANISOTROPY               :: 16
MAX_BIND_GROUPS              :: 8
MAX_VERTEX_BUFFERS           :: 16
MAX_MIP_LEVELS               :: 16

ARRAY_LAYER_COUNT_UNDEFINED :: max(u32)
COPY_STRIDE_UNDEFINED :: max(u32)
DEPTH_SLICE_UNDEFINED :: max(u32)
LIMIT_U32_UNDEFINED :: max(u32)
LIMIT_U64_UNDEFINED :: max(u64)
MIP_LEVEL_COUNT_UNDEFINED :: max(u32)
WHOLE_MAP_SIZE :: max(uint)
WHOLE_SIZE :: max(u64)

MAX_COLOR_ATTACHMENTS :: #config(MAX_COLOR_ATTACHMENTS, 8)

// 8 color + 8 resolve + 1 depth = 17
MAX_ATTACHMENT_COUNT  :: MAX_COLOR_ATTACHMENTS * 2 + 1

MAX_COMMAND_ENCODERS :: #config(MAX_COMMAND_ENCODERS, 256)

MAX_BUFFER_SIZE :: 0x80000000 // 2GB

MAX_INTER_STAGE_SHADER_VARIABLES :: 16  // Conservative limit for compatibility

Status :: enum {
    Success,
    Error,
}

// Backends supported by the GPU.
Backend :: enum {
    Null,
    Vulkan,
    Metal,
    Dx11,
    Dx12,
    Gl,
    WebGPU,
}

// Represents the backends that the GPU will use.
Backends :: bit_set[Backend;Flags]

// All supported apis.
BACKENDS_ALL :: Backends{.Vulkan, .Metal, .Dx11, .Dx12, .WebGPU, .Gl}

// All the apis that the GPU offers first tier of support for.
BACKENDS_PRIMARY :: Backends{.Vulkan, .Metal, .Dx12, .WebGPU}

// All the apis that the GPU offers second tier of support for. These may be
// unsupported/still experimental.
BACKENDS_SECONDARY :: Backends{.Dx11, .Gl}

// Power Preference when choosing a physical adapter.
Power_Preference :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Power usage is not considered when choosing an adapter.
    None,
    // Adapter that uses the least possible power. This is often an integrated GPU.
    Low_Power,
    // Adapter that has the highest performance. This is often a discrete GPU.
    High_Performance,
}

// Options for requesting adapter.
Request_Adapter_Options :: struct {
    // Power preference for the adapter.
    power_preference:       Power_Preference,
    // Indicates that only a fallback adapter can be returned. This is generally
    // a "software" implementation on the system.
    force_fallback_adapter: bool,
    // Surface that is required to be presentable with the requested adapter.
    // This does not create the surface, only guarantees that the adapter can
    // present to said surface. For WebGL, this is strictly required, as an
    // adapter can not be created without a surface.
    compatible_surface:     Surface,
}

REQUEST_ADAPTER_OPTIONS_DEFAULT :: Request_Adapter_Options {
    power_preference       = .None,
    force_fallback_adapter = false,
    compatible_surface     = nil,
}

// Collections of shader features a device supports if they support less than
// WebGPU normally allows
Shader_Model :: enum {
    Sm2,
    Sm4,
    Sm5,
}

// Supported physical device types.
Device_Type :: enum {
    // Other or Unknown.
    Other,
    // Integrated GPU with shared CPU/GPU memory.
    Integrated_Gpu,
    // Discrete GPU with separate CPU/GPU memory.
    Discrete_Gpu,
    // Virtual / Hosted.
    Virtual_Gpu,
    // Cpu / Software Rendering.
    Cpu,
}

// Information about an adapter.
Adapter_Info :: struct {
    // Adapter name.
    name:        string,
    // Backend-specific vendor ID of the adapter.
    //
    // This generally is a 16-bit PCI vendor ID in the least significant bytes
    // of this field. However, more significant bytes may be non-zero if the
    // backend uses a different representation.
    vendor:      u32,
    // Backend-specific device ID of the adapter.
    //
    // This generally is a 16-bit PCI device ID in the least significant bytes
    // of this field. However, more significant bytes may be non-zero if the
    // backend uses a different representation.
    device:      u32,
    // Type of device.
    device_type: Device_Type,
    // Driver name.
    driver:      string,
    // Driver info.
    driver_info: string,
    // Backend used for device.
    backend:     Backend,
}

Memory_Hints_Type :: enum {
    Performace,
    Memory,
    Manual,
}

// Hints to the device about the memory allocation strategy.
//
// Some backends may ignore these hints.
Memory_Hints :: struct {
    type:   Memory_Hints_Type,
    manual: struct {
        suballocated_device_memory_block_size: Range(u64),
    },
}

// Controls API call tracing and specifies where the trace is written.
Trace :: struct {
    enabled:   bool,
    directory: string,
}

// Describes a `Device`.
//
// For use with `adapter_request_device`.
Device_Descriptor :: struct {
    label:                          string,
    required_features:              Features,
    required_limits:                Limits,
    device_lost_callback_info:      Device_Lost_Callback_Info,
    uncaptured_error_callback_info: Uncaptured_Error_Callback_Info,
    memory_hints:                   Memory_Hints,
    trace:                          Trace,
}

// Order in which texture data is laid out in memory.
Texture_Data_Order :: enum {
    // The texture is laid out densely in memory as:
    //
    // - `Layer0Mip0 Layer0Mip1 Layer0Mip2`
    // - `Layer1Mip0 Layer1Mip1 Layer1Mip2`
    // - `Layer2Mip0 Layer2Mip1 Layer2Mip2`
    //
    // This is the layout used by dds files.
    Layer_Major,
    // The texture is laid out densely in memory as:
    //
    // - `Layer0Mip0 Layer1Mip0 Layer2Mip0`
    // - `Layer0Mip1 Layer1Mip1 Layer2Mip1`
    // - `Layer0Mip2 Layer1Mip2 Layer2Mip2`
    //
    // This is the layout used by ktx and ktx2 files.
    Mip_Major,
}

// Dimensions of a particular texture view.
Texture_View_Dimension :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    D1,
    D2,
    D2_Array,
    Cube,
    Cube_Array,
    D3,
}

// Get the texture dimension required of this texture view dimension.
texture_view_dimension_compatible_texture_dimension :: proc(
    self: Texture_View_Dimension,
) -> Texture_Dimension {
    #partial switch self {
    case .D1:
        return .D1
    case .D2, .D2_Array, .Cube, .Cube_Array:
        return .D2
    case .D3:
        return .D3
    }
    unreachable()
}

// Get the texture view dimension required of this texture dimension.
texture_dimension_compatible_texture_view_dimension :: proc(
    self: Texture_Dimension,
    array_layer_count: u32,
) -> Texture_View_Dimension {
    #partial switch self {
    case .D1:
        return .D1
    case .D2:
        if array_layer_count == 1 {
            return .D2
        } else {
            return .D2_Array
        }
    case .D3:
        return .D3
    case:
        unreachable()
    }
}

describe_uses :: proc(
    desc: Texture_View_Descriptor,
    format_features: Texture_Format_Features,
    loc := #caller_location,
) -> Texture_Uses {
    allowed_format_usages := format_features.allowed_usages

    if .Render_Attachment in desc.usage {
        assert(
            .Render_Attachment in allowed_format_usages,
            "Texture View format not renderable",
            loc,
        )
    }

    if .Storage_Binding in desc.usage {
        assert(.Storage_Binding in allowed_format_usages, "Texture View format not storage", loc)
    }

    // filter the usages based on the other criteria
    format_aspects := texture_format_aspects(desc.format)
    resolved_uses := texture_usage_map_uses(desc.usage, format_aspects, format_features.flags)
    mask_copy := ~Texture_Uses{.Copy_Src, .Copy_Dst}
    mask_dimension: Texture_Uses
    #partial switch desc.dimension {
    case .Cube, .Cube_Array:
        mask_dimension = {.Resource}
    case .D3:
        mask_dimension = {.Resource, .Storage_Read_Only, .Storage_Write_Only, .Storage_Read_Write}
    case:
        mask_dimension = TEXTURE_USES_ALL
    }
    mask_mip_level: Texture_Uses
    if desc.mip_level_count == 1 {
        mask_mip_level = TEXTURE_USES_ALL
    } else {
        mask_mip_level = {.Resource}
    }

    return resolved_uses & mask_copy & mask_dimension & mask_mip_level
}

// Alpha blend factor.
//
// Values using `Src1` require `Features{ .Dual_Source_Blending }` and can only
// be used with the first render target.
//
// For further details on how the blend factors are applied, see the analogous
// functionality in OpenGL:
//
// https://www.khronos.org/opengl/wiki/Blending#Blending_Parameters
Blend_Factor :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // 0.0
    Zero,
    // 1.0
    One,
    // S.component
    Src,
    // 1.0 - S.component
    One_Minus_Src,
    // S.alpha
    Src_Alpha,
    // 1.0 - S.alpha
    One_Minus_Src_Alpha,
    // D.component
    Dst,
    // 1.0 - D.component
    One_Minus_Dst,
    // D.alpha
    Dst_Alpha,
    // 1.0 - D.alpha
    One_Minus_Dst_Alpha,
    // min(S.alpha, 1.0 - D.alpha)
    Src_Alpha_Saturated,
    // Constant
    Constant,
    // 1.0 - Constant
    One_Minus_Constant,
    // S1.component
    Src1,
    // 1.0 - S1.component
    One_Minus_Src1,
    // S1.alpha
    Src1_Alpha,
    // 1.0 - S1.alpha
    One_Minus_Src1_Alpha,
}

// Returns `true` if the blend factor references the second blend source.
//
// Note that the usage of those blend factors require `Features{ .Dual_Source_Blending }`.
blend_factor_ref_second_blend_source :: proc(self: Blend_Factor) -> bool {
    #partial switch self {
    case .Src1, .One_Minus_Src1, .Src1_Alpha, .One_Minus_Src1_Alpha:
        return true
    }
    return false
}

// Alpha blend operation.
//
// For further details on how the blend operations are applied, see
// the analogous functionality in OpenGL:
//
// https://www.khronos.org/opengl/wiki/Blending#Blend_Equations.
Blend_Operation :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Src + Dst
    Add,
    // Src - Dst
    Subtract,
    // Dst - Src
    Reverse_Subtract,
    // min(Src, Dst)
    Min,
    // max(Src, Dst)
    Max,
}

// Describes a blend component of a `Blend_State`.
Blend_Component :: struct {
    // The binary operation applied to the source and destination,
    // multiplied by their respective factors.
    operation:  Blend_Operation,
    // Multiplier for the source, which is produced by the fragment shader.
    src_factor: Blend_Factor,
    // Multiplier for the destination, which is stored in the target.
    dst_factor: Blend_Factor,
}

// Standard blending state that blends source and destination based on source alpha.
BLEND_COMPONENT_NORMAL :: Blend_Component {
    operation  = .Add,
    src_factor = .Src_Alpha,
    dst_factor = .One_Minus_Src_Alpha,
}

// Default blending state that replaces destination with the source.
BLEND_COMPONENT_REPLACE :: Blend_Component {
    src_factor = .One,
    dst_factor = .Zero,
    operation  = .Add,
}

// Blend state of `(1 * src) + ((1 - src_alpha) * dst)`.
BLEND_COMPONENT_OVER :: Blend_Component {
    src_factor = .One,
    dst_factor = .One_Minus_Src_Alpha,
    operation  = .Add,
}

BLEND_COMPONENT_DEFAULT :: BLEND_COMPONENT_REPLACE

// Returns `true` if the state relies on the constant color, which is set
// independently on a render command encoder.
blend_component_uses_constant :: proc(self: Blend_Component) -> bool {
    return(
        self.src_factor == .Constant ||
        self.src_factor == .One_Minus_Constant ||
        self.dst_factor == .Constant ||
        self.dst_factor == .One_Minus_Constant \
    )
}

// Describe the blend state of a render pipeline, within `Color_Target_State`.
Blend_State :: struct {
    // Color equation.
    color: Blend_Component,
    // Alpha equation.
    alpha: Blend_Component,
}

// Blend mode that does no color blending, just overwrites the output with the
// contents of the shader.
@(rodata)
BLEND_STATE_REPLACE := Blend_State {
    color = BLEND_COMPONENT_REPLACE,
    alpha = BLEND_COMPONENT_REPLACE,
}

// Blend mode that does standard alpha blending with non-premultiplied alpha.
@(rodata)
BLEND_STATE_ALPHA_BLENDING := Blend_State {
    color = {src_factor = .Src_Alpha, dst_factor = .One_Minus_Src_Alpha, operation = .Add},
    alpha = BLEND_COMPONENT_OVER,
}

// Blend mode that does standard alpha blending with premultiplied alpha.
@(rodata)
BLEND_STATE_PREMULTIPLIED_ALPHA_BLENDING := Blend_State {
    color = BLEND_COMPONENT_OVER,
    alpha = BLEND_COMPONENT_OVER,
}

/* Uses alpha blending for both color and alpha channels. */
@(rodata)
BLEND_STATE_NORMAL := Blend_State {
    color = BLEND_COMPONENT_NORMAL,
    alpha = BLEND_COMPONENT_NORMAL,
}

// Primitive type the input mesh is composed of.
Primitive_Topology :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Vertex data is a list of points. Each vertex is a new point.
    Point_List,
    // Vertex data is a list of lines. Each pair of vertices composes a new line.
    //
    // Vertices `0 1 2 3` create two lines `0 1` and `2 3`
    Line_List,
    // Vertex data is a strip of lines. Each set of two adjacent vertices form a line.
    //
    // Vertices `0 1 2 3` create three lines `0 1`, `1 2`, and `2 3`.
    Line_Strip,
    // Vertex data is a list of triangles. Each set of 3 vertices composes a new triangle.
    //
    // Vertices `0 1 2 3 4 5` create two triangles `0 1 2` and `3 4 5`
    Triangle_List,
    // Vertex data is a triangle strip. Each set of three adjacent vertices form a triangle.
    //
    // Vertices `0 1 2 3 4 5` create four triangles `0 1 2`, `2 1 3`, `2 3 4`, and `4 3 5`
    Triangle_Strip,
}

// Returns true for strip topologies.
primitive_topology_is_strip :: proc(self: Primitive_Topology) -> bool {
    #partial switch self {
    case .Point_List, .Line_List, .Triangle_List:
        return false
    case .Line_Strip, .Triangle_Strip:
        return true
    }
    unreachable()
}

// Vertex winding order which classifies the "front" face of a triangle.
Front_Face :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Triangles with vertices in counter clockwise order are considered the front face.
    //
    // This is the default with right handed coordinate spaces.
    Ccw,
    // Triangles with vertices in clockwise order are considered the front face.
    //
    // This is the default with left handed coordinate spaces.
    Cw,
}

// Face of a vertex.
Face :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // No face culling
    None,
    // Front face
    Front,
    // Back face
    Back,
}

// Type of drawing mode for polygons
Polygon_Mode :: enum {
    // Polygons are filled
    Fill,
    // Polygons are drawn as line segments
    Line,
    // Polygons are drawn as points
    Point,
}

// Describes the state of primitive assembly and rasterization in a render pipeline.
Primitive_State :: struct {
    // The primitive topology used to interpret vertices.
    topology:           Primitive_Topology,
    // When drawing strip topologies with indices, this is the required format
    // for the index buffer. This has no effect on non-indexed or non-strip draws.
    //
    // Specifying this value enables primitive restart, allowing individual
    // strips to be separated with the index value `0xFFFF` when using `Uint16`,
    // or `0xFFFFFFFF` when using `Uint32`.
    strip_index_format: Index_Format,
    // The face to consider the front for the purpose of culling and stencil operations.
    front_face:         Front_Face,
    // The face culling mode.
    cull_mode:          Face,
    // If set to true, the polygon depth is not clipped to 0-1 before rasterization.
    //
    // Enabling this requires `Features{ .Depth_Clip_Control }` to be enabled.
    unclipped_depth:    bool,
    // Controls the way each polygon is rasterized. Can be either `Fill`
    // (default), `Line` or `Point`
    //
    // Setting this to `Line` requires `Features{ .Polygon_Mode_Line }` to be enabled.
    //
    // Setting this to `Point` requires `Features{ .Polygon_Mode_Point }` to be enabled.
    polygon_mode:       Polygon_Mode,
    // If set to true, the primitives are rendered with conservative
    // overestimation. I.e. any rastered pixel touched by it is filled. Only
    // valid for `[PolygonMode::Fill`!
    //
    // Enabling this requires `Features{ .Conservative_Rasterization }` to be enabled.
    conservative:       bool,
}

PRIMITIVE_STATE_DEFAULT :: Primitive_State {
    topology  = .Triangle_List,
    front_face = .Ccw,
    cull_mode  = .None,
}

// Describes the multi-sampling state of a render pipeline.
Multisample_State :: struct {
    // The number of samples calculated per pixel (for MSAA). For
    // non-multisampled textures, this should be `1`
    count:                     u32,
    // Bitmask that restricts the samples of a pixel modified by this pipeline.
    // All samples can be enabled using the value `!0`
    mask:                      u32,
    // When enabled, produces another sample mask per pixel based on the alpha
    // output value, that is ANDed with the sample mask and the primitive
    // coverage to restrict the set of samples affected by a primitive.
    //
    // The implicit mask produced for alpha of zero is guaranteed to be zero,
    // and for alpha of one is guaranteed to be all 1-s.
    alpha_to_coverage_enabled: bool,
}

MULTISAMPLE_STATE_DEFAULT :: Multisample_State {
    count                     = 1,
    mask                      = max(u32),
    alpha_to_coverage_enabled = false,
}


// Color write mask. Disabled color channels will not be written to.
Color_Writes :: bit_set[Color_Write;Flags]
Color_Write :: enum u32 {
    // Enable red channel writes
    Red,
    // Enable green channel writes
    Green,
    // Enable blue channel writes
    Blue,
    // Enable alpha channel writes
    Alpha,
}

// No color writes.
COLOR_WRITES_NONE :: Color_Writes{}

// Enable red, green, and blue channel writes
COLOR_WRITES_COLOR :: Color_Writes{.Red, .Green, .Blue}

// Enable writes to all channels.
COLOR_WRITES_ALL :: Color_Writes{.Red, .Green, .Blue, .Alpha}

// Enable writes to all channels.
COLOR_WRITES_DEFAULT :: COLOR_WRITES_ALL

// State of the stencil operation (fixed-pipeline stage).
//
// For use in `DepthStencilState`.
Stencil_State :: struct {
    // Front face mode.
    front:      Stencil_Face_State,
    // Back face mode.
    back:       Stencil_Face_State,
    // Stencil values are AND'd with this mask when reading and writing from the
    // stencil buffer. Only low 8 bits are used.
    read_mask:  u32,
    // Stencil values are AND'd with this mask when writing to the stencil
    // buffer. Only low 8 bits are used.
    write_mask: u32,
}

// Returns `true` if the stencil test is enabled.
stencil_state_is_enabled :: #force_inline proc "contextless" (self: Stencil_State) -> b32 {
    return (self.front.compare != .Always ||
            self.front.fail_op != .Keep ||
            self.front.depth_fail_op != .Keep ||
            self.front.pass_op != .Keep ||
            self.back.compare != .Always ||
            self.back.fail_op != .Keep ||
            self.back.depth_fail_op != .Keep ||
            self.back.pass_op != .Keep)
}

// Returns true if the state doesn't mutate the target values.
stencil_state_is_read_only :: proc(self: Stencil_State, cull_mode: Maybe(Face)) -> bool {
    // The rules are defined in step 7 of the
    // "Device timeline initialization steps" subsection of the
    // "Render Pipeline Creation" section of WebGPU (link to the section:
    // https://gpuweb.github.io/gpuweb/#render-pipeline-creation)

    if self.write_mask == 0 {
        return true
    }

    front_ro: bool
    back_ro: bool

    if mode, ok := cull_mode.?; ok {
        front_ro = mode == .Front || stencil_face_state_is_read_only(self.front)
        back_ro = mode == .Back || stencil_face_state_is_read_only(self.back)
    } else {
        front_ro = stencil_face_state_is_read_only(self.front)
        back_ro = stencil_face_state_is_read_only(self.back)
    }

    return front_ro && back_ro
}

// Returns true if the stencil state uses the reference value for testing.
stencil_state_needs_ref_value :: proc(self: Stencil_State) -> bool {
    return(
        stencil_face_state_needs_ref_value(self.front) ||
        stencil_face_state_needs_ref_value(self.back) \
    )
}

// Describes the biasing setting for the depth target.
//
// For use in `Depth_Stencil_State`.
Depth_Bias_State :: struct {
    // Constant depth biasing factor, in basic units of the depth format.
    constant:    i32,
    // Slope depth biasing factor.
    slope_scale: f32,
    // Depth bias clamp value (absolute).
    clamp:       f32,
}

// Returns true if the depth biasing is enabled.
depth_bias_state_is_enabled :: proc(self: Depth_Bias_State) -> bool {
    return self.constant != 0 || self.slope_scale != 0.0
}

// Operation to perform to the output attachment at the start of a render pass.
Load_Op :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Loads the specified value for this attachment into the render pass.
    //
    // On some GPU hardware (primarily mobile), "clear" is significantly cheaper
    // because it avoids loading data from main memory into tile-local memory.
    //
    // On other GPU hardware, there isn’t a significant difference.
    //
    // As a result, it is recommended to use "clear" rather than "load" in cases
    // where the initial value doesn’t matter
    // (e.g. the render target will be cleared using a skybox).
    Clear,
    // Loads the existing value for this attachment into the render pass.
    Load,
}

// Operation to perform to the output attachment at the end of a render pass.
Store_Op :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Stores the resulting value of the render pass for this attachment.
    Store,
    // Discards the resulting value of the render pass for this attachment.
    //
    // The attachment will be treated as uninitialized afterwards.
    // (If only either Depth or Stencil texture-aspects is set to `Discard`,
    // the respective other texture-aspect will be preserved.)
    //
    // This can be significantly faster on tile-based render hardware.
    //
    // Prefer this if the attachment is not read by subsequent passes.
    Discard,
}

// Pair of load and store operations for an attachment aspect.
Operations :: struct($T: typeid) {
    // How data should be read through this attachment.
    load:        Load_Op,
    // Whether data will be written to through this attachment.
    //
    // Note that resolve textures (if specified) are always written to,
    // regardless of this setting.
    store:       Store_Op,
    // For use with load.clear.
    clear_value: T,
}

// Describes the depth/stencil state in a render pipeline.
Depth_Stencil_State :: struct {
    // Format of the depth/stencil buffer, must be special depth format. Must
    // match the format of the depth/stencil attachment in
    // `command_encoder_begin_render_pass`.
    format:              Texture_Format,
    // If disabled, depth will not be written to.
    depth_write_enabled: bool,
    // Comparison function used to compare depth values in the depth test.
    depth_compare:       Compare_Function,
    // Stencil state.
    stencil:             Stencil_State,
    // Depth bias state.
    bias:                Depth_Bias_State,
}

// Returns `true` if the depth testing is enabled.
depth_stencil_state_is_depth_enabled :: proc(self: Depth_Stencil_State) -> bool {
    return self.depth_compare != .Always || self.depth_write_enabled
}

// Returns `true` if the state doesn't mutate the depth buffer.
depth_stencil_state_is_depth_read_only :: proc(self: Depth_Stencil_State) -> bool {
    return !self.depth_write_enabled
}

// Returns `true` if the state doesn't mutate the stencil.
depth_stencil_state_is_stencil_read_only :: proc(
    self: Depth_Stencil_State,
    cull_mode: Maybe(Face),
) -> bool {
    return stencil_state_is_read_only(self.stencil, cull_mode)
}

// Returns `true` if the state doesn't mutate either depth or stencil of the target.
depth_stencil_state_is_read_only :: proc(
    self: Depth_Stencil_State,
    cull_mode: Maybe(Face),
) -> bool {
    return(
        depth_stencil_state_is_depth_read_only(self) &&
        depth_stencil_state_is_stencil_read_only(self, cull_mode) \
    )
}

// Format of indices used with pipeline.
Index_Format :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Indices are 16 bit unsigned integers.
    Uint16,
    // Indices are 32 bit unsigned integers.
    Uint32,
}

// Returns the size in bytes of the index format
index_format_byte_size :: proc(self: Index_Format) -> uint {
    #partial switch self {
    case .Uint16:
        return 2
    case .Uint32:
        return 4
    }
    return 0
}

// Operation to perform on the stencil value.
Stencil_Operation :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Keep stencil value unchanged.
    Keep,
    // Set stencil value to zero.
    Zero,
    // Replace stencil value with value provided in most recent call to
    // `render_pass_set_stencil_reference`.
    Replace,
    // Bitwise inverts stencil value.
    Invert,
    // Increments stencil value by one, clamping on overflow.
    Increment_Clamp,
    // Decrements stencil value by one, clamping on underflow.
    Decrement_Clamp,
    // Increments stencil value by one, wrapping on overflow.
    Increment_Wrap,
    // Decrements stencil value by one, wrapping on underflow.
    Decrement_Wrap,
}

// Describes stencil state in a render pipeline.
//
// If you are not using stencil state, set this to `STENCIL_FACE_STATE_IGNORE`.
Stencil_Face_State :: struct {
    // Comparison function that determines if the fail_op or pass_op is used on
    // the stencil buffer.
    compare:       Compare_Function,
    // Operation that is performed when stencil test fails.
    fail_op:       Stencil_Operation,
    // Operation that is performed when depth test fails but stencil test succeeds.
    depth_fail_op: Stencil_Operation,
    // Operation that is performed when stencil test success.
    pass_op:       Stencil_Operation,
}

// Ignore the stencil state for the face.
STENCIL_FACE_STATE_IGNORE :: Stencil_Face_State {
    compare       = .Always,
    fail_op       = .Keep,
    depth_fail_op = .Keep,
    pass_op       = .Keep,
}

// Ignore the stencil state for the face.
STENCIL_FACE_STATE_DEFAULT :: STENCIL_FACE_STATE_IGNORE

// Returns true if the face state uses the reference value for testing or operation.
stencil_face_state_needs_ref_value :: proc(self: Stencil_Face_State) -> bool {
    return(
        compare_function_needs_ref_value(self.compare) ||
        self.fail_op == .Replace ||
        self.depth_fail_op == .Replace ||
        self.pass_op == .Replace \
    )
}

// Returns true if the face state doesn't mutate the target values.
stencil_face_state_is_read_only :: proc(self: Stencil_Face_State) -> bool {
    return self.pass_op == .Keep && self.depth_fail_op == .Keep && self.fail_op == .Keep
}

// Comparison function used for depth and stencil operations.
Compare_Function :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Function never passes
    Never,
    // Function passes if new value less than existing value
    Less,
    // Function passes if new value is equal to existing value. When using
    // this compare function, make sure to mark your Vertex Shader's `@builtin(position)`
    // output as `@invariant` to prevent artifacting.
    Equal,
    // Function passes if new value is less than or equal to existing value
    Less_Equal,
    // Function passes if new value is greater than existing value
    Greater,
    // Function passes if new value is not equal to existing value. When using
    // this compare function, make sure to mark your Vertex Shader's `@builtin(position)`
    // output as `@invariant` to prevent artifacting.
    Not_Equal,
    // Function passes if new value is greater than or equal to existing value
    Greater_Equal,
    // Function always passes
    Always,
}

// Returns true if the comparison depends on the reference value.
compare_function_needs_ref_value :: proc(self: Compare_Function) -> bool {
    #partial switch self {
    case .Never, .Always:
        return true
    }
    return false
}

// Whether a vertex buffer is indexed by vertex or by instance.
Vertex_Step_Mode :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Vertex data is advanced every vertex.
    Vertex,
    // Vertex data is advanced every instance.
    Instance,
}

// Vertex Format for a `Vertex_Attribute` (input).
Vertex_Format :: enum {
    // One unsigned byte (u8). `u32` in shaders.
    Uint8,
    // Two unsigned bytes (u8). `vec2<u32>` in shaders.
    Uint8x2,
    // Four unsigned bytes (u8). `vec4<u32>` in shaders.
    Uint8x4,
    // One signed byte (i8). `i32` in shaders.
    Sint8,
    // Two signed bytes (i8). `vec2<i32>` in shaders.
    Sint8x2,
    // Four signed bytes (i8). `vec4<i32>` in shaders.
    Sint8x4,
    // One unsigned byte (u8). [0, 255] converted to float [0, 1] `f32` in shaders.
    Unorm8,
    // Two unsigned bytes (u8). [0, 255] converted to float [0, 1] `vec2<f32>` in shaders.
    Unorm8x2,
    // Four unsigned bytes (u8). [0, 255] converted to float [0, 1] `vec4<f32>` in shaders.
    Unorm8x4,
    // One signed byte (i8). [&minus;127, 127] converted to float [&minus;1, 1]
    // `f32` in shaders.
    Snorm8,
    // Two signed bytes (i8). [&minus;127, 127] converted to float [&minus;1, 1]
    // `vec2<f32>` in shaders.
    Snorm8x2,
    // Four signed bytes (i8). [&minus;127, 127] converted to float [&minus;1,
    // 1] `vec4<f32>` in shaders.
    Snorm8x4,
    // One unsigned short (u16). `u32` in shaders.
    Uint16,
    // Two unsigned shorts (u16). `vec2<u32>` in shaders.
    Uint16x2,
    // Four unsigned shorts (u16). `vec4<u32>` in shaders.
    Uint16x4,
    // One signed short (u16). `i32` in shaders.
    Sint16,
    // Two signed shorts (i16). `vec2<i32>` in shaders.
    Sint16x2,
    // Four signed shorts (i16). `vec4<i32>` in shaders.
    Sint16x4,
    // One unsigned short (u16). [0, 65535] converted to float [0, 1] `f32` in shaders.
    Unorm16,
    // Two unsigned shorts (u16). [0, 65535] converted to float [0, 1]
    // `vec2<f32>` in shaders.
    Unorm16x2,
    // Four unsigned shorts (u16). [0, 65535] converted to float [0, 1]
    // `vec4<f32>` in shaders.
    Unorm16x4,
    // One signed short (i16). [&minus;32767, 32767] converted to float
    // [&minus;1, 1] `f32` in shaders.
    Snorm16,
    // Two signed shorts (i16). [&minus;32767, 32767] converted to float
    // [&minus;1, 1] `vec2<f32>` in shaders.
    Snorm16x2,
    // Four signed shorts (i16). [&minus;32767, 32767] converted to float
    // [&minus;1, 1] `vec4<f32>` in shaders.
    Snorm16x4,
    // One half-precision float. `f32` in shaders.
    Float16,
    // Two half-precision floats. `vec2<f32>` in shaders.
    Float16x2,
    // Four half-precision floats. `vec4<f32>` in shaders.
    Float16x4,
    // One single-precision float (f32). `f32` in shaders.
    Float32,
    // Two single-precision floats (f32). `vec2<f32>` in shaders.
    Float32x2,
    // Three single-precision floats (f32). `vec3<f32>` in shaders.
    Float32x3,
    // Four single-precision floats (f32). `vec4<f32>` in shaders.
    Float32x4,
    // One unsigned int (u32). `u32` in shaders.
    Uint32,
    // Two unsigned ints (u32). `vec2<u32>` in shaders.
    Uint32x2,
    // Three unsigned ints (u32). `vec3<u32>` in shaders.
    Uint32x3,
    // Four unsigned ints (u32). `vec4<u32>` in shaders.
    Uint32x4,
    // One signed int (i32). `i32` in shaders.
    Sint32,
    // Two signed ints (i32). `vec2<i32>` in shaders.
    Sint32x2,
    // Three signed ints (i32). `vec3<i32>` in shaders.
    Sint32x3,
    // Four signed ints (i32). `vec4<i32>` in shaders.
    Sint32x4,
    // One double-precision float (f64). `f32` in shaders. Requires
    // `Features{ .Vertex_Attribute_64Bit }`.
    Float64,
    // Two double-precision floats (f64). `vec2<f32>` in shaders. Requires
    // `Features{ .Vertex_Attribute_64Bit }`.
    Float64x2,
    // Three double-precision floats (f64). `vec3<f32>` in shaders. Requires
    // `Features{ .Vertex_Attribute_64Bit }`.
    Float64x3,
    // Four double-precision floats (f64). `vec4<f32>` in shaders. Requires
    // `Features{ .Vertex_Attribute_64Bit }`.
    Float64x4,
    // Three unsigned 10-bit integers and one 2-bit integer, packed into a
    // 32-bit integer (u32). [0, 1024] converted to float [0, 1] `vec4<f32>` in
    // shaders.
    Unorm10_10_10_2,
    // Four unsigned 8-bit integers, packed into a 32-bit integer (u32). [0,
    // 255] converted to float [0, 1] `vec4<f32>` in shaders.
    Unorm8x4Bgra,
}

// Returns the byte size of the format.
vertex_format_size :: proc(self: Vertex_Format) -> u64 {
    switch self {
    case .Uint8, .Sint8, .Unorm8, .Snorm8:
        return 1

    case .Uint8x2, .Sint8x2, .Unorm8x2, .Snorm8x2, .Uint16, .Sint16, .Unorm16, .Snorm16, .Float16:
        return 2

    case .Uint8x4,
         .Sint8x4,
         .Unorm8x4,
         .Snorm8x4,
         .Uint16x2,
         .Sint16x2,
         .Unorm16x2,
         .Snorm16x2,
         .Float16x2,
         .Float32,
         .Uint32,
         .Sint32,
         .Unorm10_10_10_2,
         .Unorm8x4Bgra:
        return 4

    case .Uint16x4,
         .Sint16x4,
         .Unorm16x4,
         .Snorm16x4,
         .Float16x4,
         .Float32x2,
         .Uint32x2,
         .Sint32x2,
         .Float64:
        return 8

    case .Float32x3, .Uint32x3, .Sint32x3:
        return 12

    case .Float32x4, .Uint32x4, .Sint32x4, .Float64x2:
        return 16

    case .Float64x3:
        return 24

    case .Float64x4:
        return 32
    }
    unreachable()
}

// Returns the size read by an acceleration structure build of the vertex format.
// This is slightly different from `vertex_format_size` because the alpha component
// of 4-component formats are not read in an acceleration structure build, allowing
// for a smaller stride.
vertex_format_min_acceleration_structure_vertex_stride :: proc(self: Vertex_Format) -> u64 {
    #partial switch self {
    case .Float16x2, .Snorm16x2:
        return 4
    case .Float32x3:
        return 12
    case .Float32x2:
        return 8
    // This is the minimum value from DirectX > A16 component is ignored, other
    // data can be packed there, such as setting vertex stride to 6 bytes
    //
    // https://microsoft.github.io/DirectX-Specs/d3d/Raytracing.html#d3d12_raytracing_geometry_triangles_desc
    //
    // Vulkan does not express a minimum stride.
    case .Float16x4, .Snorm16x4:
        return 6
    }
    unreachable()
}

// Returns the alignment required for `Blas_Triangle_Geometry.vertex_stride`.
vertex_format_acceleration_structure_stride_alignment :: proc(self: Vertex_Format) -> u64 {
    #partial switch self {
    case .Float16x4, .Float16x2, .Snorm16x4, .Snorm16x2:
        return 2
    case .Float32x2, .Float32x3:
        return 4
    }
    unreachable()
}

// Different ways that you can use a buffer.
//
// The usages determine what kind of memory the buffer is allocated from and
// what actions the buffer can partake in.
//
// Specifying only usages the application will actually perform may increase
// performance.
Buffer_Usages :: bit_set[Buffer_Usage;Flags]
Buffer_Usage :: enum u32 {
    // Allow a buffer to be mapped for reading using `buffer_map_async` +
    // `buffer_get_mapped_range`. This does not include creating a buffer with
    // `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Features{ .Mappable_Primary_Buffers }` isn't enabled, the only other
    // usage a buffer may have is `Copy_Dst`.
    Map_Read,
    // Allow a buffer to be mapped for writing using `buffer_map_async` +
    // `buffer_get_mapped_range`. This does not include creating a buffer
    // with `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Features{ .Mappable_Primary_Buffers }` feature isn't enabled, the
    // only other usage a buffer may have is `Copy_Src`.
    Map_Write,
    // Allow a buffer to be the source buffer for a
    // `command_encoder_copy_buffer_to_buffer` or
    // `command_encoder_copy_buffer_to_texture` operation.
    Copy_Src,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_copy_buffer_to_buffer`,
    // `command_encoder_copy_texture_to_buffer`,
    // `command_encoder_clear_buffer` or `queue_write_buffer` operation.
    Copy_Dst,
    // Allow a buffer to be the index buffer in a draw operation.
    Index,
    // Allow a buffer to be the vertex buffer in a draw operation.
    Vertex,
    // Allow a buffer to be a `Buffer_Binding_Type.Uniform` inside a bind group.
    Uniform,
    // Allow a buffer to be a `Buffer_Binding_Type.Storage` inside a bind group.
    Storage,
    // Allow a buffer to be the indirect buffer in an indirect draw call.
    Indirect,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_resolve_query_set` operation.
    Query_Resolve,
    // Allows a buffer to be used as input for a bottom level acceleration structure build
    Blas_Input,
    // Allows a buffer to be used as input for a top level acceleration structure build
    Tlas_Input,
}

// Similar to `Buffer_Usages`, but used only for `command_encoder_transition_resources`.
Buffer_Uses :: bit_set[Buffer_Use;u16]
Buffer_Use :: enum u16 {
    // The argument to a read-only mapping.
    Map_Read,
    // The argument to a write-only mapping.
    Map_Write,
    // The source of a hardware copy.
    // cbindgen:ignore
    Copy_Src,
    // The destination of a hardware copy.
    // cbindgen:ignore
    Copy_Dst,
    // The index buffer used for drawing.
    Index,
    // A vertex buffer used for drawing.
    Vertex,
    // A uniform buffer bound in a bind group.
    Uniform,
    // A read-only storage buffer used in a bind group.
    // cbindgen:ignore
    Storage_Read_Only,
    // A read-write buffer used in a bind group.
    // cbindgen:ignore
    Storage_Read_Write,
    // The indirect or count buffer in a indirect draw or dispatch.
    Indirect,
    // A buffer used to store query results.
    Query_Resolve,
    // Buffer used for acceleration structure building.
    Acceleration_Structure_Scratch,
    // Buffer used for bottom level acceleration structure building.
    Bottom_Level_Acceleration_Structure_Input,
    // Buffer used for top level acceleration structure building.
    Top_Level_Acceleration_Structure_Input,
    // A buffer used to store the compacted size of an acceleration structure
    Acceleration_Structure_Query,
}

// The combination of states that a buffer may be in _at the same time_.
BUFER_USES_INCLUSIVE :: Buffer_Uses {
    .Map_Read,
    .Copy_Src,
    .Index,
    .Vertex,
    .Uniform,
    .Storage_Read_Only,
    .Indirect,
    .Bottom_Level_Acceleration_Structure_Input,
    .Top_Level_Acceleration_Structure_Input,
}

// The combination of states that a buffer must exclusively be in.
BUFER_USES_EXCLUSIVE :: Buffer_Uses {
    .Map_Write,
    .Copy_Dst,
    .Storage_Read_Write,
    .Acceleration_Structure_Scratch,
}

// The combination of all usages that the are guaranteed to be be ordered by the
// hardware. If a usage is ordered, then if the buffer state doesn't change
// between draw calls, there are no barriers needed for synchronization.
BUFER_USES_ORDERED :: BUFER_USES_INCLUSIVE + {.Map_Write}

// A buffer transition for use with `command_encoder_transition_resources`.
Buffer_Transition :: struct($T: typeid) {
    // The buffer to transition.
    buffer: T,
    // The new state to transition to.
    state:  Buffer_Uses,
}

// Describes a `Buffer`.
Buffer_Descriptor :: struct {
    // Debug label of a buffer. This will show up in graphics debuggers for easy
    // identification.
    label:              string,
    // Size of a buffer, in bytes.
    size:               Buffer_Address,
    // Usages of a buffer. If the buffer is used in any way that isn't specified
    // here, the operation will panic.
    //
    // Specifying only usages the application will actually perform may increase
    // performance. Additionally, on the WebGL backend, there are restrictions
    // on `Buffer_Usages.Index`.
    usage:              Buffer_Usages,
    // Allows a buffer to be mapped immediately after they are made. It does not
    // have to be `Buffer_Usages.Map_Read` or `Buffer_Usages.Map_Write`, all
    // buffers are allowed to be mapped at creation.
    //
    // If this is `true`, `size` must be a multiple of `COPY_BUFFER_ALIGNMENT`.
    mapped_at_creation: bool,
}

// Describes a `Command_Encoder`.
Command_Encoder_Descriptor :: struct {
    // Debug label for the command encoder. This will show up in graphics
    // debuggers for easy identification.
    label: string,
}

// Timing and queueing with which frames are actually displayed to the user.
//
// Use this as part of a `Surface_Configuration` to control the behavior of
// `surface_texture_present()`.
//
// Some modes are only supported by some backends. You can use one of the
// `Auto*` modes, `Fifo`, or choose one of the supported modes from
// `Surface_Capabilities.present_modes`.
Present_Mode :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Presentation frames are kept in a First-In-First-Out queue approximately
    // 3 frames long. Every vertical blanking period, the presentation engine
    // will pop a frame off the queue to display. If there is no frame to
    // display, it will present the same frame again until the next vblank.
    //
    // When a present command is executed on the GPU, the presented image is
    // added on the queue.
    //
    // Calls to `surface_get_current_texture()` will block until there is a spot
    // in the queue.
    //
    // * **Tearing:** No tearing will be observed.
    // * **Supported on**: All platforms.
    // * **Also known as**: "Vsync On"
    //
    // This is the default value for `Present_Mode`. If you don't know what mode
    // to choose, choose this mode.
    Fifo,

    // Presentation frames are kept in a First-In-First-Out queue approximately
    // 3 frames long. Every vertical blanking period, the presentation engine
    // will pop a frame off the queue to display. If there is no frame to
    // display, it will present the same frame until there is a frame in the
    // queue. The moment there is a frame in the queue, it will immediately pop
    // the frame off the queue.
    //
    // When a present command is executed on the GPU, the presented image is
    // added on the queue.
    //
    // Calls to `surface_get_current_texture()` will block until there is a
    // spot in the queue.
    //
    // * **Tearing**: Tearing will be observed if frames last more than one
    //   vblank as the front buffer.
    // * **Supported on**: AMD on Vulkan.
    // * **Also known as**: "Adaptive Vsync"
    Fifo_Relaxed,

    // Presentation frames are not queued at all. The moment a present command
    // is executed on the GPU, the presented image is swapped onto the front buffer
    // immediately.
    //
    // * **Tearing**: Tearing can be observed.
    // * **Supported on**: Most platforms except older DX12 and Wayland.
    // * **Also known as**: "Vsync Off"
    Immediate,

    // Presentation frames are kept in a single-frame queue. Every vertical
    // blanking period, the presentation engine will pop a frame from the queue.
    // If there is no frame to display, it will present the same frame again
    // until the next vblank.
    //
    // When a present command is executed on the GPU, the frame will be put into
    // the queue. If there was already a frame in the queue, the new frame will
    // _replace_ the old frame on the queue.
    //
    // * **Tearing**: No tearing will be observed.
    // * **Supported on**: DX12 on Windows 10, NVidia on Vulkan and Wayland on
    //   Vulkan.
    // * **Also known as**: "Fast Vsync"
    Mailbox,
}

PRESENT_MODE_DEFAULT :: Present_Mode.Fifo

// Specifies how the alpha channel of the textures should be handled during
// compositing.
Composite_Alpha_Mode :: enum {
    // Chooses either `Opaque` or `Inherit` automatically，depending on the
    // `alpha_mode` that the current surface can support.
    Auto,
    // The alpha channel, if it exists, of the textures is ignored in the
    // compositing process. Instead, the textures is treated as if it has a
    // constant alpha of 1.0.
    Opaque,
    // The alpha channel, if it exists, of the textures is respected in the
    // compositing process. The non-alpha channels of the textures are
    // expected to already be multiplied by the alpha channel by the
    // application.
    Pre_Multiplied,
    // The alpha channel, if it exists, of the textures is respected in the
    // compositing process. The non-alpha channels of the textures are not
    // expected to already be multiplied by the alpha channel by the
    // application; instead, the compositor will multiply the non-alpha
    // channels of the texture by the alpha channel during compositing.
    Post_Multiplied,
    // The alpha channel, if it exists, of the textures is unknown for processing
    // during compositing. Instead, the application is responsible for setting
    // the composite alpha blending mode using native WSI command. If not set,
    // then a platform-specific default will be used.
    Inherit,
}

// Different ways that you can use a texture.
//
// The usages determine what kind of memory the texture is allocated from and what
// actions the texture can partake in.
Texture_Usages :: bit_set[Texture_Usage;u32]
Texture_Usage :: enum u32 {
    // WebGPU features:
    //
    // Allows a texture to be the source in a
    // `command_encoder_copy_texture_to_buffer` or
    // `command_encoder_copy_texture_to_texture` operation.
    Copy_Src,
    // Allows a texture to be the destination in a
    // `command_encoder_copy_buffer_to_texture`,
    // `command_encoder_copy_texture_to_texture`, or `Queue::write_texture`
    // operation.
    Copy_Dst,
    // Allows a texture to be a `BindingType::Texture` in a bind group.
    Texture_Binding,
    // Allows a texture to be a `BindingType::StorageTexture` in a bind group.
    Storage_Binding,
    // Allows a texture to be an output attachment of a render pass.
    Render_Attachment,

    // Native Features:
    //
    // Allows a texture to be used with image atomics.
    // Requires `Features{ .Texture_Atomic }`.
    Storage_Atomic = 16,
}

// Similar to `Texture_Usages`, but used only for `command_encoder_transition_resources`.
Texture_Uses :: bit_set[Texture_Use;u16]
Texture_Use :: enum u16 {
    // The texture is in unknown state.
    Uninitialized,
    // Ready to present image to the surface.
    Present,
    // The source of a hardware copy.
    Copy_Src,
    // The destination of a hardware copy.
    Copy_Dst,
    // Read-only sampled or fetched resource.
    Resource,
    // The color target of a renderpass.
    Color_Target,
    // Read-only depth stencil usage.
    Depth_Stencil_Read,
    // Read-write depth stencil usage
    Depth_Stencil_Write,
    // Read-only storage texture usage. Corresponds to a UAV in d3d, so is
    // exclusive, despite being read only.
    Storage_Read_Only,
    // Write-only storage texture usage.
    Storage_Write_Only,
    // Read-write storage texture usage.
    Storage_Read_Write,
    // Image atomic enabled storage.
    Storage_Atomic,
    // Flag used by the tracker to say a texture is in different states for
    // every sub-resource
    Complex,
    // Flag used by the tracker to say that the tracker does not know the state
    // of the sub-resource. This is different from `.Uninitialized` as that says
    // the tracker does know, but the texture has not been initialized.
    Unknown,
}

// The combination of states that a texture may be in _at the same time_.
TEXTURE_USES_INCLUSIVE :: Texture_Uses{.Copy_Src, .Resource, .Depth_Stencil_Read}

// The combination of states that a texture must exclusively be in.
TEXTURE_USES_EXCLUSIVE :: Texture_Uses {
    .Copy_Dst,
    .Color_Target,
    .Depth_Stencil_Write,
    .Storage_Read_Only,
    .Storage_Write_Only,
    .Storage_Read_Write,
    .Storage_Atomic,
    .Present,
}

// The combination of all usages that the are guaranteed to be be ordered by the
// hardware. If a usage is ordered, then if the texture state doesn't change
// between draw calls, there are no barriers needed for synchronization.
TEXTURE_USES_ORDERED :: Texture_Uses {
    .Copy_Src,
    .Resource,
    .Depth_Stencil_Read,
    .Color_Target,
    .Depth_Stencil_Write,
    .Storage_Read_Only,
}

TEXTURE_USES_ALL :: Texture_Uses {
    .Uninitialized,
    .Present,
    .Copy_Src,
    .Copy_Dst,
    .Resource,
    .Color_Target,
    .Depth_Stencil_Read,
    .Depth_Stencil_Write,
    .Storage_Read_Only,
    .Storage_Write_Only,
    .Storage_Read_Write,
    .Storage_Atomic,
    .Complex,
    .Unknown,
}

texture_usage_map_uses :: proc(
    usage: Texture_Usages,
    aspect: Format_Aspects,
    flags: Texture_Format_Feature_Flags,
) -> (
    u: Texture_Uses,
) {
    if .Copy_Src in usage {
        u += {.Copy_Src}
    }
    if .Copy_Dst in usage {
        u += {.Copy_Dst}
    }
    if .Texture_Binding in usage {
        u += {.Resource}
    }
    if .Storage_Binding in usage {
        if .Storage_Read_Only in flags {
            u += {.Storage_Read_Only}
        }
        if .Storage_Write_Only in flags {
            u += {.Storage_Write_Only}
        }
        if .Storage_Read_Write in flags {
            u += {.Storage_Read_Write}
        }
    }
    is_color := .Color in aspect
    if .Render_Attachment in usage && is_color {
        u += {.Color_Target}
    }
    if .Render_Attachment in usage && !is_color {
        u += {.Depth_Stencil_Read, .Depth_Stencil_Write}
    }
    if .Storage_Atomic in usage {
        u += {.Storage_Atomic}
    }
    return
}

// A texture transition for use with `command_encoder_transition_resources`.
Texture_Transition :: struct($T: typeid) {
    // The texture to transition.
    texture:  T,
    // An optional selector to transition only part of the texture.
    //
    // If None, the entire texture will be transitioned.
    selector: Maybe(Texture_Selector),
    // The new state to transition to.
    state:    Texture_Uses,
}

// Specifies a particular set of subresources in a texture.
Texture_Selector :: struct {
    // Range of mips to use.
    mips:   Range(u32),
    // Range of layers to use.
    layers: Range(u32),
}

// Defines the capabilities of a given surface and adapter.
Surface_Capabilities :: struct {
    // List of supported formats to use with the given adapter. The first format
    // in the slice is preferred.
    //
    // Returns an empty slice if the surface is incompatible with the adapter.
    formats:       []Texture_Format,
    // List of supported presentation modes to use with the given adapter.
    //
    // Returns an empty slice if the surface is incompatible with the adapter.
    present_modes: []Present_Mode,
    // List of supported alpha modes to use with the given adapter.
    //
    // Will return at least one element, `.Opaque` or `.Inherit`.
    alpha_modes:   []Composite_Alpha_Mode,
    // Bitflag of supported texture usages for the surface to use with the given adapter.
    //
    // The usage `Texture_Usages{ .Render_Attachment }` is guaranteed.
    usages:        Texture_Usages,
}

// Configures a `Surface` for presentation.
Surface_Configuration :: struct {
    // The usage of the swap chain. The only usage guaranteed to be supported is
    // `Texture_Usages{ .Render_Attachment }`.
    usage:                         Texture_Usages,
    // The texture format of the swap chain. The only formats that are
    // guaranteed are `Texture_Format.Bgra8_Unorm` and
    // `Texture_Format.Bgra8_Unorm_Srgb`.
    format:                        Texture_Format,
    // Width of the swap chain. Must be the same size as the surface, and nonzero.
    //
    // If this is not the same size as the underlying surface (e.g. if it is
    // set once, and the window is later resized), the behaviour is defined
    // but platform-specific, and may change in the future (currently macOS
    // scales the surface, other platforms may do something else).
    width:                         u32,
    // Height of the swap chain. Must be the same size as the surface, and nonzero.
    //
    // If this is not the same size as the underlying surface (e.g. if it is
    // set once, and the window is later resized), the behaviour is defined
    // but platform-specific, and may change in the future (currently macOS
    // scales the surface, other platforms may do something else).
    height:                        u32,
    // Presentation mode of the swap chain. Fifo is the only mode guaranteed to
    // be supported. `Fifo_Relaxed`, `Immediate`, and `Mailbox` will crash if
    // unsupported, while `Auto_Vsync` and `Auto_No_Vsync` will gracefully do a
    // designed sets of fallbacks if their primary modes are unsupported.
    present_mode:                  Present_Mode,
    // Desired maximum number of frames that the presentation engine should
    // queue in advance.
    //
    // This is a hint to the backend implementation and will always be clamped
    // to the supported range. As a consequence, either the maximum frame
    // latency is set directly on the swap chain, or waits on present are
    // scheduled to avoid exceeding the maximum frame latency if supported, or
    // the swap chain size is set to (max-latency + 1).
    //
    // Defaults to 2 when created via `surface_get_default_config`.
    //
    // Typical values range from 3 to 1, but higher values are possible:
    //
    // * Choose 2 or higher for potentially smoother frame display, as it allows
    //   to be at least one frame to be queued up. This typically avoids
    //   starving the GPU's work queue. Higher values are useful for achieving a
    //   constant flow of frames to the display under varying load.
    // * Choose 1 for low latency from frame recording to frame display. ⚠️ If
    //   the backend does not support waiting on present, this will cause the
    //   CPU to wait for the GPU to finish all work related to the previous
    //   frame when calling `surface_get_current_texture`, causing CPU-GPU
    //   serialization (i.e. when `surface_get_current_texture` returns, the
    //   GPU might be idle). It is currently not possible to query this.
    // * A value of 0 is generally not supported and always clamped to a higher value.
    desired_maximum_frame_latency: u32,
    // Specifies how the alpha channel of the textures should be handled during
    // compositing.
    alpha_mode:                    Composite_Alpha_Mode,
    // Specifies what view formats will be allowed when calling
    // `texture_create_view` on the texture returned by
    // `surface_get_current_texture`.
    //
    // View formats of the same format as the texture are always allowed.
    //
    // Note: currently, only the srgb-ness is allowed to change. (ex:
    // `Rgba8_Unorm` texture + `Rgba8_Unorm_Srgb` view)
    view_formats:                  []Texture_Format,
}

// Status of the received surface image.
Surface_Status :: enum {
    // No issues.
    Good,
    // The swap chain is operational, but it does no longer perfectly
    // match the surface. A re-configuration is needed.
    Suboptimal,
    // Unable to get the next frame, timed out.
    Timeout,
    // The surface under the swap chain has changed.
    Outdated,
    // The surface under the swap chain is lost.
    Lost,
    // The surface status is not known since `surface_get_current_texture`
    // previously failed.
    Unknown,
}

// Nanosecond timestamp used by the presentation engine.
Presentation_Timestamp :: u128

// A timestamp that is invalid due to the platform not having a timestamp system.
INVALID_TIMESTAMP :: max(u128)

// RGBA double precision color.
Color :: [4]f64

COLOR_TRANSPARENT :: Color{0.0, 0.0, 0.0, 0.0}
COLOR_BLACK :: Color{0.0, 0.0, 0.0, 1.0}
COLOR_WHITE :: Color{1.0, 1.0, 1.0, 1.0}
COLOR_RED :: Color{1.0, 0.0, 0.0, 1.0}
COLOR_GREEN :: Color{0.0, 1.0, 0.0, 1.0}
COLOR_BLUE :: Color{0.0, 0.0, 1.0, 1.0}

// Dimensionality of a texture.
Texture_Dimension :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // 1D texture
    D1,
    // 2D texture
    D2,
    // 3D texture
    D3,
}

texture_dimension_to_view_dimension :: proc(
    dimension: Texture_Dimension,
) -> Texture_View_Dimension {
    switch dimension {
    case .D1:        return .D1
    case .D2:        return .D2
    case .D3:        return .D3
    case .Undefined: return .Undefined
    }
    unreachable()
}

// Origin of a copy from a 2D image.
Origin_2D :: [2]u32

// Zero origin.
ORIDIN_2D_ZERO :: Origin_2D{}

// Adds the third dimension to this origin
origin_2d_to_3d :: proc(self: Origin_2D, z: u32) -> Origin_3D {
    return {self.x, self.y, z}
}

// Origin of a copy to/from a texture.
Origin_3D :: [3]u32

// Zero origin.
ORIDIN_3D_ZERO :: Origin_3D{}

// Removes the third dimension from this origin
origin_3d_to_2d :: proc(self: Origin_3D) -> Origin_2D {
    return {self.x, self.y}
}

// Extent of a texture related operation.
Extent_3D :: struct {
    // Width of the extent
    width:                 u32,
    // Height of the extent
    height:                u32,
    // The depth of the extent or the number of array layers
    depth_or_array_layers: u32,
}

DEPTH_DEFAULT :: 1

EXTENT_3D_DEFAULT :: Extent_3D{1, 1, 1}

// Calculates the [physical size] backing a texture of the given format and extent.
// This includes padding to the block width and height of the format.
//
// This is the texture extent that you must upload at when uploading to _mipmaps_
// of compressed textures.
//
// [physical size]: https://gpuweb.github.io/gpuweb/#physical-miplevel-specific-texture-extent
extent_3d_physical_size :: proc(self: Extent_3D, format: Texture_Format) -> (extent: Extent_3D) {
    block_width, block_height := texture_format_block_dimensions(format)

    extent.width = ((self.width + block_width - 1) / block_width) * block_width
    extent.height = ((self.height + block_height - 1) / block_height) * block_height
    extent.depth_or_array_layers = self.depth_or_array_layers

    return
}

// Calculates the maximum possible count of mipmaps.
//
// Treats the depth as part of the mipmaps. If calculating
// for a `D2_Array` texture, which does not mipmap depth, set depth to 1.
extent_3d_max_mips :: proc(self: Extent_3D, dimension: Texture_Dimension) -> (max_dim: u32) {
    switch dimension {
    case .Undefined:
        return 0
    case .D1:
        return 1
    case .D2:
        max_dim = max(self.width, self.height)
    case .D3:
        max_dim = max(self.width, max(self.height, self.depth_or_array_layers))
    }
    return 32 - intr.count_leading_zeros(max_dim)
}

// Calculates the extent at a given mip level.
// Does *not* account for memory size being a multiple of block size.
//
// https://gpuweb.github.io/gpuweb/#logical-miplevel-specific-texture-extent
extent_3d_mip_level_size :: proc(
    self: Extent_3D,
    level: u32,
    dimension: Texture_Dimension,
) -> (
    extent: Extent_3D,
) {
    extent.width = max(1, self.width >> level)

    #partial switch dimension {
    case .D1:
        extent.height = 1
    case:
        extent.height = max(1, self.height >> level)
    }

    #partial switch dimension {
    case .D1:
        extent.depth_or_array_layers = 1
    case .D2:
        extent.depth_or_array_layers = self.depth_or_array_layers
    case .D3:
        extent.depth_or_array_layers = max(1, self.depth_or_array_layers >> level)
    }

    return
}

// Describes a `Texture_View`.
//
// For use with `texture_create_view()`.
Texture_View_Descriptor :: struct {
    // Debug label of the texture view. This will show up in graphics debuggers
    // for easy identification.
    label:             string,
    // Format of the texture view. Either must be the same as the texture format
    // or in the list of `view_formats` in the texture's descriptor.
    format:            Texture_Format,
    // The dimension of the texture view. For 1D textures, this must be `D1`.
    // For 2D textures it must be one of `D2`, `D2Array`, `Cube`, and
    // `CubeArray`. For 3D textures it must be `D3`
    dimension:         Texture_View_Dimension,
    // The allowed usage(s) for the texture view. Must be a subset of the usage
    // flags of the texture. If not provided, defaults to the full set of usage
    // flags of the texture.
    usage:             Texture_Usages,
    // Aspect of the texture. Color textures must be `Texture_Aspect>All`.
    aspect:            Texture_Aspect,
    // Base mip level.
    base_mip_level:    u32,
    // Mip level count. If `count`, `base_mip_level + count` must be less or
    // equal to underlying texture mip count. If `0`, considered to include the
    // rest of the mipmap levels, but at least 1 in total.
    mip_level_count:   u32,
    // Base array layer.
    base_array_layer:  u32,
    // Layer count. If `count`, `base_array_layer + count` must be less or equal
    // to the underlying array count. If `0`, considered to include the rest of
    // the array layers, but at least 1 in total.
    array_layer_count: u32,
}

// Describes a `Texture`.
Texture_Descriptor :: struct {
    // Debug label of the texture. This will show up in graphics debuggers for
    // easy identification.
    label:           string,
    // Size of the texture. All components must be greater than zero. For a
    // regular 1D/2D texture, the unused sizes will be 1. For `D2_Array` textures,
    // Z is the number of 2D textures in that array.
    size:            Extent_3D,
    // Mip count of texture. For a texture with no extra mips, this must be 1.
    mip_level_count: u32,
    // Sample count of texture. If this is not 1, texture must have
    // Binding_Type.Texture.multisampled` set to true.
    sample_count:    u32,
    // Dimensions of the texture.
    dimension:       Texture_Dimension,
    // Format of the texture.
    format:          Texture_Format,
    // Allowed usages of the texture. If used in other ways, the operation will
    // panic.
    usage:           Texture_Usages,
    // Specifies what view formats will be allowed when calling
    // `Texture::create_view` on this texture.
    //
    // View formats of the same format as the texture are always allowed.
    //
    // Note: currently, only the srgb-ness is allowed to change. (ex:
    // `Rgba8_Unorm` texture + `Rgba8_Unorm_Srgb` view)
    view_formats:    []Texture_Format,
}

@(disabled = !ODIN_DEBUG)
texture_descriptor_validade :: proc(
    self: Texture_Descriptor,
    device_features: Features = {},
    loc := #caller_location,
) {
    // Basic validation
    assert(self.format != .Undefined, "Invalid texture format", loc)
    assert(self.dimension != .Undefined, "Invalid texture dimension", loc)
    assert(self.size.width > 0, "Texture width must be greater than 0", loc)
    assert(self.size.height > 0, "Texture height must be greater than 0", loc)
    assert(self.size.depth_or_array_layers > 0, "Texture depth/layers must be greater than 0", loc)
    assert(self.mip_level_count > 0, "Mip level count must be at least 1", loc)
    assert(self.sample_count > 0, "Sample count must be at least 1", loc)

    // Validate mip levels don't exceed maximum possible
    max_mip_levels := max_mip_levels(self.size.width, self.size.height)
    assert(self.mip_level_count <= max_mip_levels,
           "Mip level count exceeds maximum possible for this texture size", loc)

    // Format-specific feature validation
    format_info := texture_format_guaranteed_format_features(self.format, device_features)
    assert((self.usage & format_info.allowed_usages) == self.usage,
           "Requested usage flags are not supported for this format on this device", loc)

    // Validate multisampling constraints
    if self.sample_count > 1 {
        assert(self.mip_level_count == 1, "Multisampled textures must have exactly 1 mip level", loc)
        assert(self.dimension != .D3,  "3D textures cannot be multisampled", loc)
    }
}

// Calculates the extent at a given mip level.
texture_descriptor_mip_level_size :: proc(self: Texture_Descriptor, level: u32) -> Extent_3D {
    if level >= self.mip_level_count {
        return {}
    }
    return extent_3d_mip_level_size(self.size, level, self.dimension)
}

// Computes the render extent of this texture.
//
// https://gpuweb.github.io/gpuweb/#abstract-opdef-compute-render-extent
texture_descriptor_compute_render_extent :: proc(
    self: Texture_Descriptor,
    mip_level: u32,
) -> Extent_3D {
    return {
        width = max(1, self.size.width >> mip_level),
        height = max(1, self.size.height >> mip_level),
        depth_or_array_layers = 1,
    }
}

// Returns the number of array layers.
//
// https://gpuweb.github.io/gpuweb/#abstract-opdef-array-layer-count
texture_descriptor_get_array_layer_count :: proc(self: Texture_Descriptor) -> u32 {
    #partial switch self.dimension {
    case .D1, .D3:
        return 1
    case .D2:
        return self.size.depth_or_array_layers
    }
    unreachable()
}

// Selects a subset of the data a `Texture` holds.
//
// Used in texture views and texture copy operations.
Texture_Aspect :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Depth, Stencil, and Color.
    All,
    // Stencil.
    Stencil_Only,
    // Depth.
    Depth_Only,
    // Plane 0.
    Plane0,
    // Plane 1.
    Plane1,
    // Plane 2.
    Plane2,
}

// How edges should be handled in texture addressing.
Address_Mode :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Clamp the value to the edge of the texture
    //
    // -0.25 -> 0.0,
    // 1.25  -> 1.0
    Clamp_To_Edge,
    // Repeat the texture in a tiling fashion
    //
    // -0.25 -> 0.75,
    // 1.25 -> 0.25
    Repeat,
    // Repeat the texture, mirroring it every repeat
    //
    // -0.25 -> 0.25,
    // 1.25 -> 0.75
    Mirror_Repeat,
    // Clamp the value to the border of the texture.
    // Requires feature `Features{ .Address_Mode_Clamp_To_Border }`
    //
    // -0.25 -> border,
    // 1.25 -> border
    Clamp_To_Border,
}

// Texel mixing mode when sampling between texels.
Filter_Mode :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Nearest neighbor sampling.
    //
    // This creates a pixelated effect.
    Nearest,
    // Linear Interpolation
    //
    // This makes textures smooth but blurry.
    Linear,
}

// Texel mixing mode when sampling between texels.
Mipmap_Filter_Mode :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Nearest neighbor sampling.
    //
    // Return the value of the texel nearest to the texture coordinates.
    Nearest,
    // Linear Interpolation
    //
    // Select two texels in each dimension and return a linear interpolation
    // between their values.
    Linear,
}

// A range of push constant memory to pass to a shader stage.
Push_Constant_Range :: struct {
    // Stage push constant range is visible from. Each stage can only be served
    // by at most one range. One range can serve multiple stages however.
    stages: Shader_Stages,
    // Range in push constant memory to use for the stage. Must be less than
    // `Limits::max_push_constant_size`. Start and end must be aligned to the 4s.
    range:  Range(u32),
}

// Describes a `Command_Buffer`.
Command_Buffer_Descriptor :: struct {
    label: string,
}

// Describes the depth/stencil attachment for render bundles.
Render_Bundle_Depth_Stencil :: struct {
    // Format of the attachment.
    format:            Texture_Format,
    // If the depth aspect of the depth stencil attachment is going to be
    // written to.
    //
    // This must match the `Render_Pass_Depth_Stencil_Attachment.depth_ops` of
    // the renderpass this render bundle is executed in. If `depth_ops` is set,
    // this must be false. If it is not set, this must be true.
    depth_read_only:   bool,

    // If the stencil aspect of the depth stencil attachment is going to be
    // written to.
    //
    // This must match the `Render_Pass_Depth_Stencil_Attachment.stencil_ops` of
    // the renderpass this render bundle is executed in. If `depth_ops` is
    // set, this must be false. If it is not set, this must be true.
    stencil_read_only: bool,
}

// Describes a `Render_Bundle`.
Render_Bundle_Descriptor :: struct {
    // Debug label of the render bundle encoder. This will show up in graphics
    // debuggers for easy identification.
    label: string,
}

/*
Layout of a texture in a buffer's memory.

The bytes per row and rows per image can be hard to figure out so here are some examples:

    | Resolution | Format | Bytes per block | Pixels per block | Bytes per row | Rows per image |
    | 256x256    | RGBA8  | 4  | 1 * 1 * 1 | 256 * 4 = Some(1024)                   | None                   |
    | 32x16x8    | RGBA8  | 4  | 1 * 1 * 1 | 32 * 4 = 128 padded to 256 = Some(256) | None                   |
    | 256x256    | BC3    | 16 | 4 * 4 * 1 | 16 * (256 / 4) = 1024 = Some(1024)     | None                   |
    | 64x64x8    | BC3    | 16 | 4 * 4 * 1 | 16 * (64 / 4) = 256 = Some(256)        | 64 / 4 = 16 = Some(16) |
*/
Texel_Copy_Buffer_Layout :: struct {
    // Offset into the buffer that is the start of the texture. Must be a
    // multiple of texture block size. For non-compressed textures, this is 1.
    offset:         Buffer_Address,
    // Bytes per "row" in an image.
    //
    // A row is one row of pixels or of compressed blocks in the x direction.
    //
    // This value is required if there are multiple rows (i.e. height or depth
    // is more than one pixel or pixel block for compressed textures)
    //
    // Must be a multiple of 256 for `command_encoder_copy_buffer_to_texture`
    // and `command_encoder_copy_texture_to_buffer`. You must manually pad the
    // image such that this is a multiple of 256. It will not affect the image
    // data.
    //
    // `queue_write_texture` does not have this requirement.
    //
    // Must be a multiple of the texture block size. For non-compressed
    // textures, this is 1.
    bytes_per_row:  u32,
    // "Rows" that make up a single "image".
    //
    // A row is one row of pixels or of compressed blocks in the x direction.
    //
    // An image is one layer in the z direction of a 3D image or 2DArray texture.
    //
    // The amount of rows per image may be larger than the actual amount of rows of data.
    //
    // Required if there are multiple images (i.e. the depth is more than one).
    rows_per_image: u32,
}

// Specific type of a buffer binding.
Buffer_Binding_Type :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // A buffer for uniform values.
    Uniform,
    // A storage buffer.
    Storage,
    // A read only storage buffer, can only be read in the shader.
    Read_Only_Storage,
}

// Specific type of a sample in a texture binding.
Texture_Sample_Type :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // Sampling returns floats.
    Float,
    // Sampling returns floats, the texture can't be sampled with a filtering sampler.
    Unfilterable_Float,
    // Sampling does the depth reference comparison.
    Depth,
    // Sampling returns signed integers.
    Sint,
    // Sampling returns unsigned integers.
    Uint,
}

// Specific type of a sample in a texture binding.
//
// For use in `Binding_Type.StorageTexture`.
Storage_Texture_Access :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // The texture can only be written in the shader and it:
    // - may or may not be annotated with `write` (WGSL).
    // - must be annotated with `writeonly` (GLSL).
    Write_Only,
    // The texture can only be read in the shader and it must be annotated with
    // `read` (WGSL) or `readonly` (GLSL).
    //
    // `Features.{ .Texture_Adapter_Specific_Format_Features }` must be enabled to
    // use this access mode. This is a native-only extension.
    Read_Only,
    // The texture can be both read and written in the shader and must be
    // annotated with `read_write` in WGSL.
    //
    // `Features.{ .Texture_Adapter_Specific_Format_Features }` must be enabled to
    // use this access mode.  This is a nonstandard, native-only extension.
    Read_Write,
    // The texture can be both read and written in the shader via atomics and
    // must be annotated with `read_write` in WGSL.
    //
    // `Features.{ .Texture_Adapter_Specific_Format_Features }` must be enabled to
    // use this access mode.  This is a nonstandard, native-only extension.
    Atomic,
}

// Specific type of a sampler binding.
//
// For use in `Binding_Type.Sampler`.
Sampler_Binding_Type :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // The sampling result is produced based on more than a single color sample
    // from a texture, e.g. when bilinear interpolation is enabled.
    Filtering,
    // The sampling result is produced based on a single color sample from a texture.
    Non_Filtering,
    // Use as a comparison sampler instead of a normal sampler. For more info
    // take a look at the analogous functionality in OpenGL:
    //
    // https://www.khronos.org/opengl/wiki/Sampler_Object#Comparison_mode.
    Comparison,
}

// A buffer binding.
//
// For use in `Binding_Type`.
Buffer_Binding_Layout :: struct {
    type:               Buffer_Binding_Type,
    has_dynamic_offset: bool,
    min_binding_size:   u64,
}

// A sampler that can be used to sample a texture.
//
// For use in `Binding_Type`.
Sampler_Binding_Layout :: struct {
    type: Sampler_Binding_Type,
}

// A texture binding.
//
// For use in `Binding_Type`.
Texture_Binding_Layout :: struct {
    sample_type:    Texture_Sample_Type,
    view_dimension: Texture_View_Dimension,
    multisampled:   bool,
}

// A storage texture binding.
//
// For use in `Binding_Type`.
Storage_Texture_Binding_Layout :: struct {
    access:         Storage_Texture_Access,
    format:         Texture_Format,
    view_dimension: Texture_View_Dimension,
}

// A ray-tracing acceleration structure binding.
//
// For use in `Binding_Type`.
Acceleration_Structure_Binding_Layout :: struct {
    vertex_return: bool,
}

// Specific type of a binding.
//
// For use in `Bind_Group_Layout_Entry`.
Binding_Type :: union {
    Buffer_Binding_Layout,
    Sampler_Binding_Layout,
    Texture_Binding_Layout,
    Storage_Texture_Binding_Layout,
    Acceleration_Structure_Binding_Layout,
}

// Describes a single binding inside a bind group.
Bind_Group_Layout_Entry :: struct {
    // Binding index. Must match shader index and be unique inside a `Bind_Group_Layout`.
    binding:    u32,
    // Which shader stages can see this binding.
    visibility: Shader_Stages,
    // The type of the binding
    type:       Binding_Type,
    // If the binding is an array of multiple resources.
    count:      u32,
}

// Describes a `BindGroupLayout`.
//
// For use with `device_create_bind_group_layout`.
Bind_Group_Layout_Descriptor :: struct {
    label:   string,
    entries: []Bind_Group_Layout_Entry,
}

// View of a buffer which can be used to copy to/from a texture.
Texel_Copy_Buffer_Info :: struct {
    // The buffer to be copied to/from.
    buffer: Buffer,
    // The layout of the texture data in this buffer.
    layout: Texel_Copy_Buffer_Layout,
}

// View of a texture which can be used to copy to/from a buffer/texture.
Texel_Copy_Texture_Info :: struct {
    // The texture to be copied to/from.
    texture:   Texture,
    // The target mip level of the texture.
    mip_level: u32,
    // The base texel of the texture in the selected `mip_level`. Together
    // with the `copy_size` argument to copy procedures, defines the
    // sub-region of the texture to copy.
    origin:    Origin_3D,
    // The copy aspect.
    aspect:    Texture_Aspect,
}

// Subresource range within an image
Image_Subresource_Range :: struct {
    // Aspect of the texture. Color textures must be `Texture_Aspect.All`.
    aspect:            Texture_Aspect,
    // Base mip level.
    base_mip_level:    u32,
    // Mip level count. If set, `base_mip_level + count` must be less
    // or equal to underlying texture mip count. If not set, considered to
    // include the rest of the mipmap levels, but at least 1 in total.
    mip_level_count:   u32,
    // Base array layer.
    base_array_layer:  u32,
    // Layer count. If set, `base_array_layer + count` must be less or
    // equal to the underlying array count. If not set, considered to include the
    // rest of the array layers, but at least 1 in total.
    array_layer_count: u32,
}

// Color variation to use when sampler addressing mode is `Address_Mode.Clamp_To_Border`.
Sampler_Border_Color :: enum {
    // Indicates no value is passed for this argument.
    Undefined,
    // [0, 0, 0, 0]
    Transparent_Black,
    // [0, 0, 0, 1]
    Opaque_Black,
    // [1, 1, 1, 1]
    Opaque_White,

    // On the Metal backend, this is equivalent to `Transparent_Black` for
    // textures that have an alpha component, and equivalent to `Opaque_Black`
    // for textures that do not have an alpha component. On other backends,
    // this is equivalent to `Transparent_Black`. Requires
    // `Features{ .Address_Mode_Clamp_To_Zero }`. Not supported on the web.
    Zero,
}

// Describes how to create a `QuerySet`.
Query_Set_Descriptor :: struct {
    // Debug label for the query set.
    label: string,
    // Kind of query that this query set should contain.
    type:  Query_Type,
    // Total count of queries the set contains. Must not be zero.
    // Must not be greater than `QUERY_SET_MAX_QUERIES`.
    count: u32,
}

// Type of query contained in a `Query_Set`.
Query_Type :: enum {
    // Query returns a single 64-bit number, serving as an occlusion boolean.
    Occlusion,
    // Query returns up to 5 64-bit numbers based on the given flags.
    //
    // See `Pipeline_Statistics_Types`'s documentation for more information
    // on how they get resolved.
    //
    // `Features{ .Pipeline_Statistics_Query }` must be enabled to use this query type.
    Pipeline_Statistics,
    // Query returns a 64-bit number indicating the GPU-timestamp
    // where all previous commands have finished executing.
    //
    // Must be multiplied by `Queue::get_timestamp_period`[Qgtp] to get
    // the value in nanoseconds. Absolute values have no meaning,
    // but timestamps can be subtracted to get the time it takes
    // for a string of operations to complete.
    //
    // `Features{ .Timestamp_Query }` must be enabled to use this query type.
    Timestamp,
}

// Flags for which pipeline data should be recorded in a query.
//
// Used in `Query_Type`.
//
// The amount of values written when resolved depends on the amount of flags
// set. For example, if 3 flags are set, 3 64-bit values will be written per
// query.
//
// The order they are written is the order they are declared in these bitflags.
// For example, if you enabled `CLIPPER_PRIMITIVES_OUT` and
// `COMPUTE_SHADER_INVOCATIONS`, it would write 16 bytes, the first 8 bytes
// being the primitive out value, the last 8 bytes being the compute shader
// invocation count.
Pipeline_Statistics_Types :: bit_set[Pipeline_Statistics_Type;u8]
Pipeline_Statistics_Type :: enum u8 {
    // Amount of times the vertex shader is ran. Accounts for
    // the vertex cache when doing indexed rendering.
    Vertex_Shader_Invocations,
    // Amount of times the clipper is invoked. This
    // is also the amount of triangles output by the vertex shader.
    Clipper_Invocations,
    // Amount of primitives that are not culled by the clipper.
    // This is the amount of triangles that are actually on screen
    // and will be rasterized and rendered.
    Clipper_Primitives_Out,
    // Amount of times the fragment shader is ran. Accounts for
    // fragment shaders running in 2x2 blocks in order to get
    // derivatives.
    Fragment_Shader_Invocations,
    // Amount of times a compute shader is invoked. This will
    // be equivalent to the dispatch count times the workgroup size.
    Compute_Shader_Invocations,
}

// Describes a `Query_Type`.
Query_Type_Descriptor :: struct {
    // Type of query contained in a `Query_Set`.
    type:                Query_Type,
    // For use when type is `Pipeline_Statistics`.
    pipeline_statistics: Pipeline_Statistics_Types,
}

// Argument buffer layout for `draw_indirect` commands.
Draw_Indirect_Args :: struct {
    // The number of vertices to draw.
    vertex_count:   u32,
    // The number of instances to draw.
    instance_count: u32,
    // The Index of the first vertex to draw.
    first_vertex:   u32,
    // The instance ID of the first instance to draw.
    //
    // Has to be 0, unless `Features{ .Indirect_First_Instance }` is enabled.
    first_instance: u32,
}

// Argument buffer layout for `draw_indexed_indirect` commands.
Draw_Indexed_Indirect_Args :: struct {
    // The number of indices to draw.
    index_count:    u32,
    // The number of instances to draw.
    instance_count: u32,
    // The first index within the index buffer.
    first_index:    u32,
    // The value added to the vertex index before indexing into the vertex buffer.
    base_vertex:    i32,
    // The instance ID of the first instance to draw.
    //
    // Has to be 0, unless `Features{ .Indirect_First_Instance }` is enabled.
    first_instance: u32,
}

// Argument buffer layout for `dispatch_indirect` commands.
Dispatch_Indirect_Args :: struct {
    // The number of work groups in X dimension.
    x: u32,
    // The number of work groups in Y dimension.
    y: u32,
    // The number of work groups in Z dimension.
    z: u32,
}

// Describes how shader bound checks should be performed.
Shader_Runtime_Checks :: struct {
    // Enforce bounds checks in shaders, even if the underlying driver doesn't
    // support doing so natively.
    //
    // When this is `true`, `gpu` promises that shaders can only read or write
    // the accessible region of a bindgroup's buffer bindings. If the underlying
    // graphics platform cannot implement these bounds checks itself, `gpu`
    // will inject bounds checks before presenting the shader to the platform.
    //
    // When this is `false`, `gpu` only enforces such bounds checks if the
    // underlying platform provides a way to do so itself. `gpu` does not
    // itself add any bounds checks to generated shader code.
    //
    // Note that `gpu` users may try to initialize only those portions of
    // buffers that they anticipate might be read from. Passing `false` here may
    // allow shaders to see wider regions of the buffers than expected, making
    // such deferred initialization visible to the application.
    bounds_checks:       bool,
    // If false, the caller MUST ensure that all passed shaders do not contain
    // any infinite loops.
    //
    // If it does, backend compilers MAY treat such a loop as unreachable code
    // and draw conclusions about other safety-critical code paths. This option
    // SHOULD NOT be disabled when running untrusted code.
    force_loop_bounding: bool,
}

Constant_Entry :: struct {
    key:   string,
    value: f64,
}

Queue_Descriptor :: struct {
    label: string,
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------

Proc_Create_Instance :: #type proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> Instance

create_instance_impl: Proc_Create_Instance

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


// Handle to a physical graphics and/or compute device.
//
// Adapters can be created using `instance_request_adapter`.
//
// Adapters can be used to open a connection to the corresponding `Device` on
// the host system by using `adapter_request_device`.
Adapter :: distinct rawptr

Adapter_Base :: struct {
    label:          String_Buffer_Small,
    ref:            Ref_Count,
    instance:       Instance,
    allocator:      runtime.Allocator,
    backend:        Backend,
    shader_formats: Shader_Formats,
    type:           Device_Type,
    features:       Features,
    limits:         Limits,
}

Proc_Adapter_Get_Info :: #type proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> Adapter_Info

Proc_Adapter_Info_Free_Members :: #type proc(self: Adapter_Info, allocator := context.allocator)

// Get info about the adapter itself as `string`.
adapter_info_string :: proc(info: Adapter_Info, allocator := context.allocator) -> (str: string) {
    sb: strings.Builder
    err: runtime.Allocator_Error

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)
    if sb, err = strings.builder_make(ta); err != nil {
        return
    }
    defer strings.builder_destroy(&sb)

    device_name := info.name if info.name != "" else "Unknown device"
    strings.write_string(&sb, device_name)
    strings.write_byte(&sb, '\n')

    strings.write_string(&sb, "  - Driver: ")
    if info.driver != "" {
        strings.write_string(&sb, info.driver)
    }
    if info.driver_info != "" {
        if info.driver != "" {
            strings.write_string(&sb, ", ")
        }
        strings.write_string(&sb, info.driver_info)
    }
    strings.write_byte(&sb, '\n')

    adapter_type: string
    switch info.device_type {
    case .Discrete_Gpu:
        adapter_type = "Discrete GPU with separate CPU/GPU memory"
    case .Integrated_Gpu:
        adapter_type = "Integrated GPU with shared CPU/GPU memory"
    case .Cpu:
        adapter_type = "Cpu / Software Rendering"
    case .Virtual_Gpu:
        adapter_type = "Virtual / Hosted"
    case .Other:
        adapter_type = "Unknown"
    }
    strings.write_string(&sb, "  - Type: ")
    strings.write_string(&sb, adapter_type)
    strings.write_byte(&sb, '\n')

    backend: string
    #partial switch info.backend {
    case .Null:
        backend = "Empty"
    case .WebGPU:
        backend = "WebGPU in the browser"
    case .Dx12:
        backend = "Direct3D-12"
    case .Dx11:
        backend = "Direct3D-11"
    case .Metal:
        backend = "Metal API"
    case .Vulkan:
        backend = "Vulkan API"
    case .Gl:
        backend = "OpenGL/OpenGLES"
    }
    strings.write_string(&sb, "  - Backend: ")
    strings.write_string(&sb, backend)

    if str, err = strings.clone(strings.to_string(sb), allocator); err != nil {
        return
    }

    return
}

// Print info about the adapter itself.
adapter_info_print_info :: proc(info: Adapter_Info) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    fmt.printfln("%s", adapter_info_string(info, context.temp_allocator))
}

// Print info about the adapter itself.
adapter_info_print_adapter :: proc(adapter: Adapter) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    ta := context.temp_allocator
    info := adapter_get_info(adapter, ta)
    fmt.printfln("%s", adapter_info_string(info, ta))
}

// Print info about the adapter itself.
adapter_info_print :: proc {
    adapter_info_print_info,
    adapter_info_print_adapter,
}

Proc_Adapter_Get_Features :: #type proc(adapter: Adapter, loc := #caller_location) -> Features

Proc_Adapter_Has_Feature :: #type proc(
    adapter: Adapter,
    features: Features,
    loc := #caller_location,
) -> bool

Proc_Adapter_Get_Limits :: #type proc(adapter: Adapter, loc := #caller_location) -> Limits

Proc_Adapter_Request_Device :: #type proc(
    adapter: Adapter,
    descriptor: Maybe(Device_Descriptor),
    callback_info: Request_Device_Callback_Info,
    loc := #caller_location,
)

Proc_Adapter_Get_Texture_Format_Capabilities :: #type proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities

Proc_Adapter_Get_Label :: #type proc(adapter: Adapter, loc := #caller_location) -> string

Proc_Adapter_Set_Label :: #type proc(adapter: Adapter, label: string, loc := #caller_location)

Proc_Adapter_Add_Ref :: #type proc(adapter: Adapter, loc := #caller_location)

Proc_Adapter_Release :: #type proc(adapter: Adapter, loc := #caller_location)

// Requests a connection to a physical device, creating a logical device.
adapter_get_info: Proc_Adapter_Get_Info

// Release the `Adapter_Info` resources (remove the allocated strings).
adapter_info_free_members: Proc_Adapter_Info_Free_Members

// The features which can be used to create devices on this adapter.
adapter_get_features: Proc_Adapter_Get_Features

// Check if the Adapter supports the given set of feature flags.
adapter_has_feature: Proc_Adapter_Has_Feature

// Get the best limits which can be used to create devices on this adapter.
adapter_get_limits: Proc_Adapter_Get_Limits

// Requests a connection to a physical device, creating a logical device.
adapter_request_device: Proc_Adapter_Request_Device

adapter_get_texture_format_capabilities: Proc_Adapter_Get_Texture_Format_Capabilities

// Returns the features supported for a given texture format by this adapter.
adapter_get_texture_format_features :: proc(
    adapter: Adapter,
    format: Texture_Format,
) -> (
    features: Texture_Format_Features,
) {
    adapter_features := adapter_get_features(adapter)
    return texture_format_guaranteed_format_features(format, adapter_features)
}

// Get the `Adapter` debug label.
adapter_get_label: Proc_Adapter_Get_Label

// Set the `Adapter` debug label.
adapter_set_label: Proc_Adapter_Set_Label

// Increase the `Adapter` reference count.
adapter_add_ref: Proc_Adapter_Add_Ref

// Release the `Adapter` resources, use to decrease the reference count.
adapter_release: Proc_Adapter_Release

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------


// Handle to a binding group layout.
//
// A `Bind_Group_Layout` is a handle to the GPU-side layout of a binding group. It
// can be used to create a `Bind_Group_Descriptor` object, which in turn can be used
// to create a `Bind_Group` object with `device_create_bind_group`. A series of
// `Bind_Group_Layout`s can also be used to create a `Pipeline_Layout_Descriptor`,
// which can be used to create a `Pipeline_Layout`.
//
// It can be created with `device_create_bind_group_layout`.
Bind_Group_Layout :: distinct rawptr

Bind_Group_Layout_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
}

Proc_Bind_Group_Layout_Get_Label :: #type proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string

Proc_Bind_Group_Layout_Set_Label :: #type proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
)

Proc_Bind_Group_Layout_Add_Ref :: #type proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
)

Proc_Bind_Group_Layout_Release :: #type proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
)

// Get the `Bind_Group_Layout` debug label.
bind_group_layout_get_label: Proc_Bind_Group_Layout_Get_Label

// Set the `Bind_Group_Layout` debug label.
bind_group_layout_set_label: Proc_Bind_Group_Layout_Set_Label

// Increase the `Bind_Group_Layout` reference count.
bind_group_layout_add_ref: Proc_Bind_Group_Layout_Add_Ref

// Release the `Bind_Group_Layout` resources, use to decrease the reference count.
bind_group_layout_release: Proc_Bind_Group_Layout_Release

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------


// Handle to a binding group.
//
// A `Bind_Group` represents the set of resources bound to the bindings
// described by a `Bind_Group_Layout`. It can be created with
// `device_create_bind_group`. A `Bind_Group` can be bound to a particular
// `Render_Pass` with `render_pass_set_bind_group`, or to a `Compute_Pass` with
// `compute_pass_set_bind_group`.
Bind_Group :: distinct rawptr

Bind_Group_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
}

// Describes the segment of a buffer to bind.
Buffer_Binding :: struct {
    buffer: Buffer,
    offset: u64,
    size:   u64,
}

// Resource that can be bound to a pipeline.
Binding_Resource :: union {
    Buffer_Binding,
    Sampler,
    Texture_View,
    []Buffer_Binding,
    []Sampler,
    []Texture_View,
}

// An element of a `Bind_Group_Descriptor`, consisting of a bindable resource
// and the slot to bind it to.
Bind_Group_Entry :: struct {
    binding:  u32,
    resource: Binding_Resource,
}

// Describes a group of bindings and the resources to be bound.
//
// For use with `device_create_bind_group`.
Bind_Group_Descriptor :: struct {
    label:   string,
    layout:  Bind_Group_Layout,
    entries: []Bind_Group_Entry,
}

Proc_Bind_Group_Get_Label :: #type proc(bind_group: Bind_Group, loc := #caller_location) -> string

Proc_Bind_Group_Set_Label :: #type proc(
    bind_group: Bind_Group,
    label: string,
    loc := #caller_location,
)

Proc_Bind_Group_Add_Ref :: #type proc(bind_group: Bind_Group, loc := #caller_location)

Proc_Bind_Group_Release :: #type proc(bind_group: Bind_Group, loc := #caller_location)

// Get the `Bind_Group` debug label.
bind_group_get_label: Proc_Bind_Group_Get_Label

// Set the `Bind_Group` debug label.
bind_group_set_label: Proc_Bind_Group_Set_Label

// Increase the `Bind_Group` reference count.
bind_group_add_ref: Proc_Bind_Group_Add_Ref

// Release the `Bind_Group` resources, use to decrease the reference count.
bind_group_release: Proc_Bind_Group_Release

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------


// Handle to a GPU-accessible buffer.
//
// Created with `device_create_buffer` or `device_create_buffer_with_data`.
Buffer :: distinct rawptr

Buffer_Base :: struct {
    label:              String_Buffer_Small,
    ref:                Ref_Count,
    device:             Device,
    allocator:          runtime.Allocator,
    size:               Buffer_Address,
    usage:              Buffer_Usages,
    mapped_at_creation: bool,
    map_state:          Buffer_Map_State,
    mapped_ptr:         rawptr,
    mapped_range:       Range(Buffer_Address),
}

Buffer_Map_State :: enum {
    Unmapped,
    Pending_Map,
    Mapped_For_Read,
    Mapped_For_Write,
    Mapped_For_Read_Write,
    Mapped_At_Creation,
    Host_Mapped_Persistent,
    Shared_Memory_NoAccess,
    Destroyed,
}

// Type of buffer mapping.
Map_Modes :: bit_set[Map_Mode;Flags]
Map_Mode :: enum {
    // Map only for reading.
    Read,
    // Map only for writing.
    Write,
}

Map_Async_Status :: enum {
    Success,
    Instance_Dropped,
    Error,
    Aborted,
    Unknown,
}

Buffer_Map_Callback :: #type proc(
    status: Map_Async_Status,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Buffer_Map_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Buffer_Map_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

Proc_Buffer_Destroy :: #type proc(buffer: Buffer, loc := #caller_location)

Proc_Buffer_Get_Const_Mapped_Range :: #type proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr

Proc_Buffer_Get_Map_State :: #type proc(
    buffer: Buffer,
    loc := #caller_location,
) -> Buffer_Map_State

Proc_Buffer_Get_Mapped_Range :: #type proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr

Proc_Buffer_Get_Size :: #type proc(buffer: Buffer, loc := #caller_location) -> u64

Proc_Buffer_Get_Usage :: #type proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages

Proc_Buffer_Map_Async :: #type proc(
    buffer: Buffer,
    mode: Map_Modes,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future

Proc_Buffer_Unmap :: #type proc(buffer: Buffer, loc := #caller_location)

Proc_Buffer_Get_Label :: #type proc(buffer: Buffer, loc := #caller_location) -> string

Proc_Buffer_Set_Label :: #type proc(buffer: Buffer, label: string, loc := #caller_location)

Proc_Buffer_Add_Ref :: #type proc(buffer: Buffer, loc := #caller_location)

Proc_Buffer_Release :: #type proc(buffer: Buffer, loc := #caller_location)

// Return the binding resource for the entire buffer.
buffer_as_entire_binding :: proc(buffer: Buffer) -> Binding_Resource {
    return buffer_as_entire_buffer_binding(buffer)
}

// Return the binding view of the entire buffer.
buffer_as_entire_buffer_binding :: proc(buffer: Buffer) -> Buffer_Binding {
    return {buffer = buffer, offset = 0, size = WHOLE_SIZE}
}

// Destroy the associated native resources as soon as possible.
buffer_destroy: Proc_Buffer_Destroy

// Returns the current map state for this `Buffer`.
buffer_get_map_state: Proc_Buffer_Get_Map_State

when ODIN_OS != .JS {
    // This is used for both const and mut versions.
    buffer_get_mapped_range_impl :: proc(
        buffer: Buffer,
        #any_int offset: uint,
        #any_int size: uint,
        loc := #caller_location,
    ) -> rawptr {
        impl := get_impl(Buffer_Base, buffer, loc)

        // Check if buffer is not mapped
        assert(impl.map_state != .Unmapped, "buffer is not mapped", loc)

        // Validate offset is within mapped range
        assert(offset >= uint(impl.mapped_range.start),
            "Offset is before the start of the mapped range", loc)

        // Determine actual size to return
        actual_size := size
        if size == WHOLE_MAP_SIZE {
            // Return from offset to end of buffer
            actual_size = uint(impl.size) - offset
        }

        // Calculate the end of the requested range
        request_end := offset + actual_size
        mapped_end := uint(impl.mapped_range.start + impl.mapped_range.end)

        // Validate requested range is within the mapped region
        assert(request_end <= mapped_end, "Requested range exceeds the mapped range", loc)
        // Validate size doesn't exceed buffer size
        assert(offset + actual_size <= uint(impl.size), "Requested range exceeds buffer size", loc)

        // Calculate pointer offset from the mapped base
        offset_from_mapped_base := Buffer_Address(offset) - impl.mapped_range.start
        result_ptr := rawptr(uintptr(impl.mapped_ptr) + uintptr(offset_from_mapped_base))

        return result_ptr
    }

    buffer_get_const_mapped_range :: proc(
        buffer: Buffer,
        #any_int offset: uint,
        #any_int size: uint,
        loc := #caller_location,
    ) -> rawptr {
        impl := get_impl(Buffer_Base, buffer, loc)

        // Validate write access
        assert(
            impl.map_state != .Mapped_For_Write &&
            impl.map_state != .Mapped_For_Read_Write &&
            impl.map_state != .Mapped_At_Creation,
            "Buffer must be not mapped with write access to get an immutable mapped range", loc)

        return buffer_get_mapped_range_impl(buffer, offset, size, loc)
    }

    buffer_get_mapped_range :: proc(
        buffer: Buffer,
        #any_int offset: uint,
        #any_int size: uint,
        loc := #caller_location,
    ) -> rawptr {
        impl := get_impl(Buffer_Base, buffer, loc)

        // Validate write access
        assert(
            impl.map_state == .Mapped_For_Write ||
            impl.map_state == .Mapped_For_Read_Write ||
            impl.map_state == .Mapped_At_Creation,
            "Buffer must be mapped with write access to get a mutable mapped range", loc)

        return buffer_get_mapped_range_impl(buffer, offset, size, loc)
    }
}

buffer_get_mapped_range_slice :: proc(
    buffer: Buffer,
    #any_int offset: uint,
    $T: typeid,
    #any_int length: uint,
    loc := #caller_location,
) -> []T {
    return ([^]T)(buffer_get_mapped_range(buffer, offset, size_of(T) * length, loc))[:length]
}

// Returns the length of the buffer allocation in bytes.

// This is always equal to the `size` that was specified when creating the buffer.
buffer_get_size: Proc_Buffer_Get_Size

// Returns the allowed usages for this `Buffer`.

// This is always equal to the `usage` that was specified when creating the buffer.
buffer_get_usage: Proc_Buffer_Get_Usage

// Map the buffer. Buffer is ready to map once the callback is called.

// For the callback to complete, either `queue_submit` or `device_poll` must be
// called elsewhere in the runtime, possibly integrated into an event loop or run
// on a separate thread.

// The callback will be called on the thread that first calls the above functions
// after the gpu work has completed. There are no restrictions on the code you can
// run in the callback, however on native the call to the function will not
// complete until the callback returns, so prefer keeping callbacks short and used
// to set flags, send messages, etc.
buffer_map_async: Proc_Buffer_Map_Async

// Unmaps the buffer from host memory.

// This terminates the effect of all previous `map_async` operations and makes the
// buffer available for use by the GPU again.
buffer_unmap: Proc_Buffer_Unmap

// Get the `Buffer` debug label.
buffer_get_label: Proc_Buffer_Get_Label

// Set the `Buffer` debug label.
buffer_set_label: Proc_Buffer_Set_Label

// Increase the `Buffer` reference count.
buffer_add_ref: Proc_Buffer_Add_Ref

// Release the `Buffer` resources, use to decrease the reference count.
buffer_release: Proc_Buffer_Release

// -----------------------------------------------------------------------------
// Command Buffer procedures
// -----------------------------------------------------------------------------


// Handle to a command buffer on the GPU.
//
// A `Command_Buffer` represents a complete sequence of commands that may be
// submitted to a command queue with `queue_submit`. A `Command_Buffer` is
// obtained by recording a series of commands to a `Command_Encoder` and then
// calling `command_encoder_finish`.
Command_Buffer :: distinct rawptr

Command_Buffer_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    encoder:   Command_Encoder,
    allocator: runtime.Allocator,
}

Proc_Command_Buffer_Get_Label :: #type proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string

Proc_Command_Buffer_Set_Label :: #type proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
)

Proc_Command_Buffer_Add_Ref :: #type proc(command_buffer: Command_Buffer, loc := #caller_location)

Proc_Command_Buffer_Release :: #type proc(command_buffer: Command_Buffer, loc := #caller_location)

// Get the `Command_Buffer` debug label.
command_buffer_get_label: Proc_Command_Buffer_Get_Label

// Set the `Command_Buffer` debug label.
command_buffer_set_label: Proc_Command_Buffer_Set_Label

// Increase the `Command_Buffer` reference count.
command_buffer_add_ref: Proc_Command_Buffer_Add_Ref

// Release the `Command_Buffer` resources, use to decrease the reference count.
command_buffer_release: Proc_Command_Buffer_Release

// -----------------------------------------------------------------------------
// Command Encoder procedures
// -----------------------------------------------------------------------------


// Encodes a series of GPU operations.
//
// A command encoder can record `Render_Pass`es, `Compute_Pass`es, and transfer
// operations between driver-managed resources like `Buffer`s and `Texture`s.
//
// When finished recording, call `command_encoder_finish` to obtain a
// `Command_Buffer` which may be submitted for execution.
Command_Encoder :: distinct rawptr

Command_Encoder_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
    encoding:  bool,
}

Proc_Command_Encoder_Begin_Compute_Pass :: #type proc(
    encoder: Command_Encoder,
    descriptor: Maybe(Compute_Pass_Descriptor) = nil,
    loc := #caller_location,
) -> Compute_Pass

Proc_Command_Encoder_Begin_Render_Pass :: #type proc(
    encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass

Proc_Command_Encoder_Copy_Buffer_To_Buffer :: #type proc(
    encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
)

Proc_Command_Encoder_Copy_Buffer_To_Texture :: #type proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
)

Proc_Command_Encoder_Copy_Texture_To_Buffer :: #type proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Texture_Info,
    destination: ^Texel_Copy_Buffer_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
)

Proc_Command_Encoder_Copy_Texture_To_Texture :: #type proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Texture_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
)

Proc_Command_Encoder_Clear_Buffer :: #type proc(
    encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

Proc_Command_Encoder_Resolve_Query_Set :: #type proc(
    encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
)

Proc_Command_Encoder_Write_Timestamp :: #type proc(
    encoder: Command_Encoder,
    querySet: Query_Set,
    queryIndex: u32,
    loc := #caller_location,
)

Proc_Command_Encoder_Finish :: #type proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer

Proc_Command_Encoder_Get_Label :: #type proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> string

Proc_Command_Encoder_Set_Label :: #type proc(
    encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
)

Proc_Command_Encoder_Add_Ref :: #type proc(encoder: Command_Encoder, loc := #caller_location)

Proc_Command_Encoder_Release :: #type proc(encoder: Command_Encoder, loc := #caller_location)

// Begins recording of a compute pass.
//
// This procedure returns a `Compute_Pass` object which records a single compute pass.
//
// As long as the returned `Compute_Pass` has not ended, any mutating operation on
// this command encoder causes an error and invalidates it.
command_encoder_begin_compute_pass: Proc_Command_Encoder_Begin_Compute_Pass

// Begins recording of a render pass.
//
// This procedure returns a `Render_Pass` object which records a single render pass.
//
// As long as the returned  `Render_Pass` has not ended, any mutating operation on
// this command encoder causes an error and invalidates it.
command_encoder_begin_render_pass: Proc_Command_Encoder_Begin_Render_Pass

// Copy data from one buffer to another.
command_encoder_copy_buffer_to_buffer: Proc_Command_Encoder_Copy_Buffer_To_Buffer

// Copy data from a buffer to a texture.
command_encoder_copy_buffer_to_texture: Proc_Command_Encoder_Copy_Buffer_To_Texture

// Copy data from a texture to a buffer.
command_encoder_copy_texture_to_buffer: Proc_Command_Encoder_Copy_Texture_To_Buffer

// Copy data from one texture to another.
command_encoder_copy_texture_to_texture: Proc_Command_Encoder_Copy_Texture_To_Texture

// Clears buffer to zero.
command_encoder_clear_buffer: Proc_Command_Encoder_Clear_Buffer

// Resolves a query set, writing the results into the supplied destination buffer.
//
// Occlusion and timestamp queries are 8 bytes each. For pipeline statistics queries.
//
// `destination_offset` must be aligned to `QUERY_RESOLVE_BUFFER_ALIGNMENT`.
command_encoder_resolve_query_set: Proc_Command_Encoder_Resolve_Query_Set

// Issue a timestamp command at this point in the queue. The timestamp will be
// written to the specified query set, at the specified index.
//
// Must be multiplied by `queue_get_timestamp_period` to get the value in
// nanoseconds. Absolute values have no meaning, but timestamps can be
// subtracted to get the time it takes for a string of operations to complete.
command_encoder_write_timestamp: Proc_Command_Encoder_Write_Timestamp

// Finishes recording and returns a `Command_Buffer` that can be submitted for execution.
command_encoder_finish: Proc_Command_Encoder_Finish

// Get the `Command_Encoder` debug label.
command_encoder_get_label: Proc_Command_Encoder_Get_Label

// Set the `Command_Encoder` debug label.
command_encoder_set_label: Proc_Command_Encoder_Set_Label

// Increase the `Command_Encoder` reference count.
command_encoder_add_ref: Proc_Command_Encoder_Add_Ref

// Release the `Command_Encoder` resources, use to decrease the reference count.
command_encoder_release: Proc_Command_Encoder_Release

// -----------------------------------------------------------------------------
// Compute Pass procedures
// -----------------------------------------------------------------------------


// In-progress recording of a compute pass.
//
// It can be created with `command_encoder_begin_compute_pass`.
Compute_Pass :: distinct rawptr

Compute_Pass_Timestamp_Writes :: struct {
    query_set:                     Query_Set,
    beginning_of_pass_write_index: u32,
    end_of_pass_write_index:       u32,
}

Compute_Pass_Descriptor :: struct {
    label:            string,
    timestamp_writes: ^Compute_Pass_Timestamp_Writes,
}

Proc_Compute_Pass_Dispatch_Workgroups :: #type proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
)

Proc_Compute_Pass_Dispatch_Workgroups_Indirect :: #type proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

Proc_Compute_Pass_End :: #type proc(compute_pass: Compute_Pass, loc := #caller_location)

Proc_Compute_Pass_Insert_Debug_Marker :: #type proc(
    compute_pass: Compute_Pass,
    markerLabel: string,
    loc := #caller_location,
)

Proc_Compute_Pass_Pop_Debug_Group :: #type proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)

Proc_Compute_Pass_Push_Debug_Group :: #type proc(
    compute_pass: Compute_Pass,
    groupLabel: string,
    loc := #caller_location,
)

Proc_Compute_Pass_Set_Bind_Group :: #type proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
)

Proc_Compute_Pass_Set_Pipeline :: #type proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
)

Proc_Compute_Pass_Get_Label :: #type proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) -> string

Proc_Compute_Pass_Set_Label :: #type proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
)

Proc_Compute_Pass_Add_Ref :: #type proc(compute_pass: Compute_Pass, loc := #caller_location)

Proc_Compute_Pass_Release :: #type proc(compute_pass: Compute_Pass, loc := #caller_location)

compute_pass_dispatch_workgroups: Proc_Compute_Pass_Dispatch_Workgroups

compute_pass_dispatch_workgroups_indirect: Proc_Compute_Pass_Dispatch_Workgroups_Indirect

compute_pass_end: Proc_Compute_Pass_End

compute_pass_insert_debug_marker: Proc_Compute_Pass_Insert_Debug_Marker

compute_pass_pop_debug_group: Proc_Compute_Pass_Pop_Debug_Group

compute_pass_push_debug_group: Proc_Compute_Pass_Push_Debug_Group

compute_pass_set_bind_group: Proc_Compute_Pass_Set_Bind_Group

compute_pass_set_pipeline: Proc_Compute_Pass_Set_Pipeline

// Get the `Compute_Pass` debug label.
compute_pass_get_label: Proc_Compute_Pass_Get_Label

// Set the `Compute_Pass` debug label.
compute_pass_set_label: Proc_Compute_Pass_Set_Label

// Increase the `Compute_Pass` reference count.
compute_pass_add_ref: Proc_Compute_Pass_Add_Ref

// Release the `Compute_Pass` resources, use to decrease the reference count.
compute_pass_release: Proc_Compute_Pass_Release

// -----------------------------------------------------------------------------
// Compute Pipeline procedures
// -----------------------------------------------------------------------------


Compute_Pipeline :: distinct rawptr

Proc_Compute_Pipeline_Get_Bind_Group_Layout :: #type proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

Proc_Compute_Pipeline_Get_Label :: #type proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> string

Proc_Compute_Pipeline_Set_Label :: #type proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
)

Proc_Compute_Pipeline_Add_Ref :: #type proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
)

Proc_Compute_Pipeline_Release :: #type proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
)

// Get an object representing the bind group layout at a given index.
//
// If this pipeline was created with a default layout, then bind groups created
// with the returned `Bind_Group_Layout` can only be used with this pipeline.
//
// This procedure will assert if there is no bind group layout at `index`.
compute_pipeline_get_bind_group_layout: Proc_Compute_Pipeline_Get_Bind_Group_Layout

// Get the `Compute_Pipeline` debug label.
compute_pipeline_get_label: Proc_Compute_Pipeline_Get_Label

// Set the `Compute_Pipeline` debug label.
compute_pipeline_set_label: Proc_Compute_Pipeline_Set_Label

// Increase the `Compute_Pipeline` reference count.
compute_pipeline_add_ref: Proc_Compute_Pipeline_Add_Ref

// Release the `Compute_Pipeline` resources, use to decrease the reference count.
compute_pipeline_release: Proc_Compute_Pipeline_Release

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------


// Open connection to a graphics and/or compute device.
//
// Responsible for the creation of most rendering and compute resources. These
// are then used in commands, which are submitted to a `Queue`.
//
// A device may be requested from an adapter with `adapter_request_device`.
Device :: distinct rawptr

Device_Base :: struct {
    label:          String_Buffer_Small,
    ref:            Ref_Count,
    allocator:      runtime.Allocator,
    adapter:        Adapter,
    queue:          Queue,
    backend:        Backend,
    shader_formats: Shader_Formats,
    features:       Features,
    limits:         Limits,
}

Proc_Device_Create_Bind_Group :: #type proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group

Proc_Device_Create_Bind_Group_Layout :: #type proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout

Proc_Device_Create_Buffer :: #type proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer

Proc_Device_Create_Command_Encoder :: #type proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder

Proc_Device_Create_Pipeline_Layout :: #type proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout

Proc_Device_Create_Texture :: #type proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture

Proc_Device_Create_Sampler :: #type proc(
    device: Device,
    descriptor: Sampler_Descriptor = SAMPLER_DESCRIPTOR_DEFAULT,
    loc := #caller_location,
) -> Sampler

Proc_Device_Get_Queue :: #type proc(device: Device, loc := #caller_location) -> Queue

Proc_Device_Create_Shader_Module :: #type proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module

Proc_Device_Create_Render_Pipeline :: #type proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline

Proc_Device_Get_Features :: #type proc(device: Device, loc := #caller_location) -> Features

Proc_Device_Get_Limits :: #type proc(device: Device, loc := #caller_location) -> Limits

Proc_Device_Get_Label :: #type proc(device: Device, loc := #caller_location) -> string

Proc_Device_Set_Label :: #type proc(device: Device, label: string, loc := #caller_location)

Proc_Device_Add_Ref :: #type proc(device: Device, loc := #caller_location)

Proc_Device_Release :: #type proc(device: Device, loc := #caller_location)

// Creates a new `Bind_Group`.
device_create_bind_group: Proc_Device_Create_Bind_Group

// Creates a new `Bind_Group_Layout`.
device_create_bind_group_layout: Proc_Device_Create_Bind_Group_Layout

// Creates a new `Buffer`.
device_create_buffer: Proc_Device_Create_Buffer

// Describes a `Buffer` when allocating data.
Buffer_Data_Descriptor :: struct {
    // Debug label of a buffer. This will show up in graphics debuggers for easy
    // identification.
    label: string,
    // Usages of a buffer. If the buffer is used in any way that isn't specified
    // here, the operation will panic.
    usage: Buffer_Usages,
}

// Creates a new `Buffer` with data from a slice.
device_create_buffer_with_data_slice :: proc(
    device: Device,
    descriptor: Buffer_Data_Descriptor,
    data: []$T,
    loc := #caller_location,
) -> (
    buf: Buffer,
) {
    // Skip mapping if the buffer is zero sized
    if data == nil || len(data) == 0 {
        desc: Buffer_Descriptor = {
            label              = descriptor.label,
            // size               = GL_DEFAULT_BUFFER_SIZE,
            size               = 0,
            usage              = descriptor.usage,
            mapped_at_creation = false,
        }
        return device_create_buffer(device, desc, loc)
    }

    // Valid vulkan usage is
    // 1. buffer size must be a multiple of COPY_BUFFER_ALIGNMENT.
    // 2. buffer size must be greater than 0.
    // Therefore we round the value up to the nearest multiple, and ensure it's at least
    // COPY_BUFFER_ALIGNMENT.

    unpadded_size := u64(size_of(T) * len(data))
    padded_size := align(unpadded_size, COPY_BUFFER_ALIGNMENT)

    desc := Buffer_Descriptor {
        label              = descriptor.label,
        usage              = descriptor.usage,
        size               = padded_size,
        mapped_at_creation = true, // Make the buffer CPU-owned at creation
    }

    buf = device_create_buffer(device, desc, loc)

    // Synchronously and immediately map a buffer for write
    mapping := buffer_get_mapped_range_slice(buf, 0, T, len(data), loc)
    copy(mapping, data)

    buffer_unmap(buf, loc) // Transfer ownership back to the GPU
    return
}

// Creates a new `Buffer` with data from any type that is not sliceable.
device_create_buffer_with_data_typed :: proc(
    device: Device,
    descriptor: Buffer_Data_Descriptor,
    data: $T,
    loc := #caller_location,
) -> (
    buf: Buffer,
) where !intr.type_is_sliceable(T) {
    bytes := to_bytes(data, loc)

    desc := Buffer_Data_Descriptor {
        label = descriptor.label,
        usage = descriptor.usage,
    }

    return device_create_buffer_with_data_slice(device, desc, bytes[:], loc)
}

// Creates a new `Buffer` with data.
device_create_buffer_with_data :: proc {
    device_create_buffer_with_data_slice,
    device_create_buffer_with_data_typed,
}

// Creates an empty `Command_Encoder`
device_create_command_encoder: Proc_Device_Create_Command_Encoder

// Creates a `Pipeline_Layout`.
device_create_pipeline_layout: Proc_Device_Create_Pipeline_Layout

// Creates a `Texture`.
device_create_texture: Proc_Device_Create_Texture

// Creates a new `Sampler`.
//
// `descriptor` specifies the behavior of the sampler.
device_create_sampler: Proc_Device_Create_Sampler

// Get a handle to a command queue on the device.
device_get_queue: Proc_Device_Get_Queue

// Creates a new `Shader_Module`.
device_create_shader_module: Proc_Device_Create_Shader_Module

// Creates a new `Render_Pipeline`.
device_create_render_pipeline: Proc_Device_Create_Render_Pipeline

// The features enabled on this device.
device_get_features: Proc_Device_Get_Features

// The current limits on this device.
device_get_limits: Proc_Device_Get_Limits

@(require_results)
device_get_texture_format_features :: proc(
    device: Device,
    format: Texture_Format,
) -> Texture_Format_Features {
    impl := cast(^Device_Base)device
    format_features := adapter_get_texture_format_features(impl.adapter, format)
    #partial switch format {
    case .R32_Float, .Rg32_Float, .Rgba32_Float:
        if .Float32_Filterable in impl.features {
            format_features.flags -= {.Filterable}
        }
    }
    return format_features
}

@(require_results)
device_describe_format_features :: proc(
    device: Device,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Features {
    impl := cast(^Device_Base)device
    required_features := texture_format_required_features(format)
    assert(required_features - impl.features == {}, "Missing device features", loc)
    if .Texture_Adapter_Specific_Format_Features in impl.features {
        return device_get_texture_format_features(device, format)
    } else {
        return texture_format_guaranteed_format_features(format, impl.features)
    }
}

// Get the current backend.
device_get_backend :: proc(device: Device) -> Backend {
    when ODIN_OS != .JS {
        impl := cast(^Device_Base)device
        return impl.backend
    } else {
        return .WebGPU
    }
}

// Get the shader formats that is compatible for the current backend.
device_get_backend_shader_formats :: proc(device: Device) -> Shader_Formats {
    when ODIN_OS != .JS {
        impl := cast(^Device_Base)device
        return impl.shader_formats
    } else {
        return { .Wgsl }
    }
}

// Get the `Device` debug label.
device_get_label: Proc_Device_Get_Label

// Set the `Device` debug label.
device_set_label: Proc_Device_Set_Label

// Increase the `Device` reference count.
device_add_ref: Proc_Device_Add_Ref

// Release the `Device` resources, use to decrease the reference count.
device_release: Proc_Device_Release

// -----------------------------------------------------------------------------
// Instance procedures
// -----------------------------------------------------------------------------


// Context for all other GPU objects.
//
// This is the first thing you create when using GPU. Its primary use is to
// create `Adapter`s and `Surface`s.
Instance :: distinct rawptr

Instance_Base :: struct {
    label:          String_Buffer_Small,
    ref:            Ref_Count,
    ctx:            runtime.Context,
    allocator:      runtime.Allocator,
    flags:          Instance_Flags,
    backend:        Backend,
    // Types of shader model supported by the current backend
    shader_formats: Shader_Formats,
}

Instance_Flag :: enum {
    Debug,
    Validation,
}

// Instance debugging flags.
Instance_Flags :: bit_set[Instance_Flag;Flags]
INSTANCE_FLAGS_DEFAULT :: Instance_Flags{}

// Configuration for the OpenGL/OpenGLES backend.
//
// Part of `Backend_Options`.
Gl_Backend_Options :: struct {
    major_version: i32,
    minor_version: i32,
    core_profile:  bool,
}

// The Fxc compiler (default) is old, slow and unmaintained.
//
// However, it doesn’t require any additional .dlls to be shipped with the application.
Dx12_Compiler_Fxc :: struct {}

// DXC shader model.
Dxc_Shader_Model :: enum {
    V6_0,
    V6_1,
    V6_2,
    V6_3,
    V6_4,
    V6_5,
    V6_6,
    V6_7,
}

// The Dxc compiler is new, fast and maintained.
//
// However, it requires `dxcompiler.dll` to be shipped with the application.
// These files can be downloaded from
// [Microsoft](https://github.com/microsoft/DirectXShaderCompiler/releases).
//
// Minimum supported version:
// [v1.8.2502](https://github.com/microsoft/DirectXShaderCompiler/releases/tag/v1.8.2502)
//
// It also requires WDDM 2.1 (Windows 10 version 1607).
Dx12_Compiler_Dxc :: struct {
    dxc_path:         string,
    max_shader_model: Dxc_Shader_Model,
}

// Selects which DX12 shader compiler to use.
Dx12_Compiler :: union {
    Dx12_Compiler_Fxc,
    Dx12_Compiler_Dxc,
}

Dx12_Backend_Options :: struct {
    shader_compiler: Dx12_Compiler,
}

// Options that are passed to a given backend.
Backend_Options :: struct {
    gl:   Gl_Backend_Options,
    dx12: Dx12_Backend_Options,
}

// Options for creating an instance.
Instance_Descriptor :: struct {
    label:           string,
    backends:        Backends,
    flags:           Instance_Flags,
    backend_options: Backend_Options,
    headless:        bool,
}

INSTANCE_DESCRIPTOR_DEFAULT :: Instance_Descriptor {
    backends = BACKENDS_PRIMARY,
    flags    = INSTANCE_FLAGS_DEFAULT,
}

when ODIN_OS == .JS {
    GPU_PLATFORM_BACKENDS :: Backends{ .WebGPU }
} else when ODIN_OS == .Windows {
    GPU_PLATFORM_BACKENDS :: Backends{ .Dx12, .Dx11, .Vulkan, .Gl }
} else when ODIN_OS == .Linux {
    GPU_PLATFORM_BACKENDS :: Backends{ .Vulkan, .Gl }
} else when ODIN_OS == .Darwin {
    GPU_PLATFORM_BACKENDS :: Backends{ .Metal, .Vulkan } // Vulkan with MontenVK
} else {
    GPU_PLATFORM_BACKENDS :: Backends{ .Gl }
}

GPU_BACKEND_TYPE_STR :: #config(GPU_BACKEND_TYPE, "")

// Initialize the GPU context and create a new GPU instance.
@(require_results)
create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> Instance {
    desc := descriptor.? or_else INSTANCE_DESCRIPTOR_DEFAULT

    // Try to read the config to see if a backend type should be used
    when GPU_BACKEND_TYPE_STR != "" {
        backends := Backends{}
        {
            backend, backend_ok := reflect.enum_from_name(Backend, GPU_BACKEND_TYPE_STR)
            if backend_ok {
                backends = { backend }
                log.warnf("Backend type selected with [GPU_BACKEND_TYPE_STR]: %v", backend)
            } else {
                log.errorf(
                    "Backend type %v is invalid, " +
                    "possible values are from [Backends] (case sensitive): " +
                    "\n\tVulkan,\n\tMetal,\n\tDx11,\n\tDX12,\n\tGl,\n\tWebGPU",
                    GPU_BACKEND_TYPE_STR,
                    location = loc,
                )
                return nil
            }
        }
    } else {
        backends := desc.backends if desc.backends != {} else BACKENDS_ALL
    }

    requested_backends := backends & GPU_PLATFORM_BACKENDS
    if requested_backends == {} {
        log.error("No supported backends requested for this platform", location = loc)
        return nil
    }

    backend: Backend
    shader_formats: Shader_Formats

    when ODIN_OS == .JS {
        if .WebGPU in requested_backends {
            webgpu_init(allocator)
            backend = .WebGPU
            shader_formats = { .Wgsl }
        }
    } else when ODIN_OS == .Windows {
        // TODO: Dx12 should be the priority
        requested_backends -= { .Dx12 }
        if .Dx12 in requested_backends {
            // d3d12_init(allocator)
            // backend = .Dx12
            // shader_formats = { .Dxil, .Dxbc }
        } else if .Dx11 in requested_backends {
            d3d11_init(allocator)
            backend = .Dx11
            shader_formats = { .Dxbc }
        } else if .Gl in requested_backends {
            gl_init(allocator)
            backend = .Gl
            shader_formats = { .Glsl }
        }
    } else when ODIN_OS == .Linux {
        // TODO: Vulkan should be the priority
        requested_backends -= { .Vulkan }
        if .Vulkan in requested_backends {
            // vulkan_init(allocator)
            // backend = .Vulkan
            // shader_formats = { .Spirv }
        } else if .Gl in requested_backends {
            gl_init(allocator)
            backend = .Gl
            shader_formats = { .Glsl }
        }
    } else when ODIN_OS == .Darwin {
        // if .Metal in requested_backends {
        //     metal_init(allocator)
        //     backend = .Metal
        //     shader_formats = {.Msl, .Metallib}
        // }
        unimplemented("Metal backend is not implemented")
    } else {
        unimplemented("Unsupported platform!")
    }

    assert(backend != .Null)

    // Ensure procedures pointer are valid
    check_interface_procedures()

    instance := create_instance_impl(desc, allocator, loc)

    instance_impl := cast(^Instance_Base)instance
    instance_impl.backend = backend
    instance_impl.shader_formats = shader_formats

    return instance
}

Proc_Instance_Create_Surface :: #type proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface

Proc_Instance_Request_Adapter :: #type proc(
    instance: Instance,
    options: Maybe(Request_Adapter_Options),
    callback_info: Request_Adapter_Callback_Info,
    loc := #caller_location,
)

Proc_Instance_Enumarate_Adapters :: #type proc(
    instance: Instance,
    allocator := context.allocator,
    loc := #caller_location,
) -> []Adapter

Proc_Instance_Get_Label :: #type proc(instance: Instance, loc := #caller_location) -> string

Proc_Instance_Set_Label :: #type proc(instance: Instance, label: string, loc := #caller_location)

Proc_Instance_Add_Ref :: #type proc(instance: Instance, loc := #caller_location)

Proc_Instance_Release :: #type proc(instance: Instance, loc := #caller_location)

// Creates a surface from a target.
instance_create_surface: Proc_Instance_Create_Surface

// Retrieves an `Adapter` which matches the given `Request_Adapter_Options`.
//
// Some options are "soft", so treated as non-mandatory. Others are "hard".
//
// If no adapters are found that suffice all the "hard" options, `nil` is returned.
instance_request_adapter: Proc_Instance_Request_Adapter

// Retrieves all available `Adapters` for the current backend.
instance_enumarate_adapters: Proc_Instance_Enumarate_Adapters

// Get the current backend.
instance_get_backend :: proc(instance: Instance) -> Backend {
    impl := cast(^Instance_Base)instance
    return impl.backend
}

// Get the shader formats that is compatible for the current backend.
instance_get_backend_shader_formats :: proc(instance: Instance) -> Shader_Formats {
    impl := cast(^Instance_Base)instance
    return impl.shader_formats
}

// Get the `Instance` debug label.
instance_get_label: Proc_Instance_Get_Label

// Set the `Instance` debug label.
instance_set_label: Proc_Instance_Set_Label

// Increase the `Instance` reference count.
instance_add_ref: Proc_Instance_Add_Ref

// Release the `Instance` resources, use to decrease the reference count.
instance_release: Proc_Instance_Release

// -----------------------------------------------------------------------------
// Query Set procedures
// -----------------------------------------------------------------------------

Query_Set :: distinct rawptr

// -----------------------------------------------------------------------------
// Pipeline Layout procedures
// -----------------------------------------------------------------------------

// Handle to a pipeline layout.
//
// A `Pipeline_Layout` object describes the available binding groups of a pipeline.
// It can be created with `device_create_pipeline_layout`.
Pipeline_Layout :: distinct rawptr

Pipeline_Layout_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
}

// Describes a `Pipe_lineLayout`.
//
// For use with `device_create_pipeline_layout`.
Pipeline_Layout_Descriptor :: struct {
    label:                string,
    bind_group_layouts:   []Bind_Group_Layout,
    push_constant_ranges: []Push_Constant_Range,
}

Proc_Pipeline_Layout_Get_Label :: #type proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string

Proc_Pipeline_Layout_Set_Label :: #type proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
)

Proc_Pipeline_Layout_Add_Ref :: #type proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
)

Proc_Pipeline_Layout_Release :: #type proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
)

// Get the `Pipeline_Layout` debug label.
pipeline_layout_get_label: Proc_Pipeline_Layout_Get_Label

// Set the `Pipeline_Layout` debug label.
pipeline_layout_set_label: Proc_Pipeline_Layout_Set_Label

// Increase the `Pipeline_Layout` reference count.
pipeline_layout_add_ref: Proc_Pipeline_Layout_Add_Ref

// Release the `Pipeline_Layout` resources, use to decrease the reference count.
pipeline_layout_release: Proc_Pipeline_Layout_Release

// -----------------------------------------------------------------------------
// Surface procedures
// -----------------------------------------------------------------------------


// Handle to a presentable surface.
//
// A `Surface` represents a platform-specific surface (e.g. a window) onto which
// rendered images may be presented. A `Surface` may be created with the
// procedure `instance_create_surface`.
//
// This type is unique to the API. In the WebGPU specification,
// [`GPUCanvasContext`](https://gpuweb.github.io/gpuweb/#canvas-context) serves
// a similar role.
Surface :: distinct rawptr

Surface_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    instance:  Instance,
    allocator: runtime.Allocator,
    config:    Surface_Configuration,
}

Surface_Source_Android_Native_Window :: struct {
    window: rawptr,
}

Surface_Source_Canvas_HTML_Selector :: struct {
    selector: string,
}

Surface_Source_Metal_Layer :: struct {
    layer: rawptr,
}

Surface_Source_Wayland_Surface :: struct {
    display: rawptr,
    surface: rawptr,
}

Surface_Source_Windows_HWND :: struct {
    hinstance: rawptr,
    hwnd:      rawptr,
}

Surface_Source_Xcb_Window :: struct {
    connection: rawptr,
    window:     u32,
}

Surface_Source_Xlib_Window :: struct {
    display: rawptr,
    window:  u64,
}

// Describes a surface target.
Surface_Descriptor :: struct {
    label:  string,
    target: union {
        Surface_Source_Android_Native_Window,
        Surface_Source_Canvas_HTML_Selector,
        Surface_Source_Metal_Layer,
        Surface_Source_Wayland_Surface,
        Surface_Source_Windows_HWND,
        Surface_Source_Xcb_Window,
        Surface_Source_Xlib_Window,
        // SurfaceSourceSwapChainPanel,
    },
}

// Surface procedures
Proc_Surface_Get_Capabilities :: #type proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> Surface_Capabilities

Proc_Surface_Capabilities_Free_Members :: #type proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
)

Proc_Surface_Configure :: #type proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
)

Proc_Surface_Get_Current_Texture :: #type proc(
    surface: Surface,
    loc := #caller_location,
) -> Surface_Texture

Proc_Surface_Present :: #type proc(surface: Surface, loc := #caller_location)

Proc_Surface_Get_Label :: #type proc(surface: Surface, loc := #caller_location) -> string

Proc_Surface_Set_Label :: #type proc(surface: Surface, label: string, loc := #caller_location)

Proc_Surface_Add_Ref :: #type proc(surface: Surface, loc := #caller_location)

Proc_Surface_Release :: #type proc(surface: Surface, loc := #caller_location)

// Returns the capabilities of the surface when used with the given adapter.
//
// Returns `false` if surface is incompatible with the adapter.
surface_get_capabilities: Proc_Surface_Get_Capabilities

// Free the allocated surface capabilities.
surface_capabilities_free_members: Proc_Surface_Capabilities_Free_Members

// Initializes the `Surface` for presentation.
//
// **Panics**
//
// - A old `Surface_Texture` is still alive referencing an old surface.
// - Texture format requested is unsupported on the surface.
// - `config.width` or `config.height` is zero.
surface_configure: Proc_Surface_Configure

// Returns the next texture to be presented by the swapchain for drawing.
//
// In order to present the `Surface_Texture` returned by this procedure, first a
// `queue_submit` needs to be done with some work rendering to this texture.
// Then `surface_texture_present` needs to be called.
//
// If a `Surface_Texture` referencing this surface is alive when the swapchain
// is recreated, recreating the swapchain will panic.
surface_get_current_texture: Proc_Surface_Get_Current_Texture

// Schedule presentation on the surface.
//
// Needs to be called after any work on the texture is scheduled via `queue_submit`.
surface_present: Proc_Surface_Present

// Get the `Surface` debug label.
surface_get_label: Proc_Surface_Get_Label

// Set the `Surface` debug label.
surface_set_label: Proc_Surface_Set_Label

// Increase the `Surface` reference count.
surface_add_ref: Proc_Surface_Add_Ref

// Release the `Surface` resources, use to decrease the reference count.
surface_release: Proc_Surface_Release

// -----------------------------------------------------------------------------
// Surface Texture procedures
// -----------------------------------------------------------------------------

Surface_Error :: enum {
    None,
    Timeout,
    Outdated,
    Lost,
    Out_Of_Memory,
    Other,
}

// Status of the received surface image.
Surface_Texture_Status :: enum {
    Success_Optimal,
    Success_Suboptimal,
    Timeout,
    Outdated,
    Lost,
    Out_Of_Memory,
    Device_Lost,
    Error,
}

// Surface texture that can be rendered to.
//
// Result of a successful call to `surface_get_current_texture`.
Surface_Texture :: struct {
    surface:   Surface,
    // Accessible view of the frame.
    texture:   Texture,
    status:    Surface_Texture_Status,
    presented: bool,
}

// Schedule this texture to be presented on the owning surface.
//
// Needs to be called after any work on the texture is scheduled via `queue_submit`.
surface_texture_present :: proc(surface_texture: Surface_Texture, loc := #caller_location) {
    surface_present(surface_texture.surface, loc)
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------


// Handle to a command queue on a device.
//
// A `Queue` executes recorded `Command_Buffer` objects and provides convenience
// methods for writing to `queue_write_buffer` and `queue_write_texture`.
//
// It can be created by calling `device_get_queue`.
Queue :: distinct rawptr

Queue_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    adapter:   Adapter,
    device:    Device,
    allocator: runtime.Allocator,
}

Proc_Queue_Submit :: #type proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location)

Proc_Queue_Write_Buffer :: #type proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

Proc_Queue_Write_Texture :: #type proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
)

Proc_Queue_Get_Label :: #type proc(queue: Queue, loc := #caller_location) -> string

Proc_Queue_Set_Label :: #type proc(queue: Queue, label: string, loc := #caller_location)

Proc_Queue_Add_Ref :: #type proc(queue: Queue, loc := #caller_location)

Proc_Queue_Release :: #type proc(queue: Queue, loc := #caller_location)

// Submits a series of finished command buffers for execution.
queue_submit: Proc_Queue_Submit

@(private)
queue_write_buffer_impl: Proc_Queue_Write_Buffer

queue_write_buffer_slice :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: []$T,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid buffer", loc)
    size := uint(size_of(T) * len(data))
    queue_write_buffer_impl(queue, buffer, buffer_offset, raw_data(data), size, loc)
}

queue_write_buffer_typed :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: $T,
    loc := #caller_location,
) where !intr.type_is_sliceable(T) {
    assert(buffer != nil, "Invalid buffer", loc)
    bytes := to_bytes(data, loc)
    queue_write_buffer_slice(queue, buffer, buffer_offset, bytes, loc)
}

// Write of some data into a `buffer` starting at `offset`.
//
// This procedure fails if `data` overruns the size of `buffer` starting at `offset`.
queue_write_buffer :: proc {
    queue_write_buffer_slice,
    queue_write_buffer_typed,
}

// Write of some data into a texture.
//
// - `data` contains the texels to be written, which must be in the same format as
//   the texture.
// - `dataLayout` describes the memory layout of data, which does not necessarily
//   have to have tightly packed rows.
// - `texture` specifies the texture to write into, and the location within the
//   texture (coordinate offset, mip level) that will be overwritten.
// - `size` is the size, in texels, of the region to be written.
//
// This procedure fails if `size` overruns the size of `texture`, or if `data` is too short.
queue_write_texture: Proc_Queue_Write_Texture

// Get the `Queue` debug label.
queue_get_label: Proc_Queue_Get_Label

// Set the `Queue` debug label.
queue_set_label: Proc_Queue_Set_Label

// Increase the `Queue` reference count.
queue_add_ref: Proc_Queue_Add_Ref

// Release the `Queue` resources, use to decrease the reference count.
queue_release: Proc_Queue_Release

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------


// Handle to a sampler.
//
// A `Sampler` object defines how a pipeline will sample from a `Texture_View`.
// Samplers define image filters (including anisotropy) and address (wrapping)
// modes, among other things. See the documentation for `Sampler_Descriptor` for
// more information.
//
// It can be created with `device_create_sampler`.
Sampler :: distinct rawptr

Sampler_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
}

// Describes a `Sampler`.
//
// For use with `device_create_sampler`.
Sampler_Descriptor :: struct {
    // Debug label of the sampler. This will show up in graphics debuggers for
    // easy identification.
    label:            string,
    // How to deal with out of bounds accesses in the u (i.e. x) direction
    address_mode_u:   Address_Mode,
    // How to deal with out of bounds accesses in the v (i.e. y) direction
    address_mode_v:   Address_Mode,
    // How to deal with out of bounds accesses in the w (i.e. z) direction
    address_mode_w:   Address_Mode,
    // How to filter the texture when it needs to be magnified (made larger)
    mag_filter:       Filter_Mode,
    // How to filter the texture when it needs to be minified (made smaller)
    min_filter:       Filter_Mode,
    // How to filter between mip map levels
    mipmap_filter:    Mipmap_Filter_Mode,
    // Minimum level of detail (i.e. mip level) to use
    lod_min_clamp:    f32,
    // Maximum level of detail (i.e. mip level) to use
    lod_max_clamp:    f32,
    // If this is enabled, this is a comparison sampler using the given comparison function.
    compare:          Compare_Function,
    // Must be at least 1. If this is not 1, all filter modes must be linear.
    anisotropy_clamp: u16,
    // Border color to use when `address_mode` is `Address_Mode.ClampToBorder`
    border_color:     Sampler_Border_Color,
}

SAMPLER_DESCRIPTOR_DEFAULT :: Sampler_Descriptor {
    address_mode_u   = .Clamp_To_Edge,
    address_mode_v   = .Clamp_To_Edge,
    address_mode_w   = .Clamp_To_Edge,
    mag_filter       = .Nearest,
    min_filter       = .Nearest,
    mipmap_filter    = .Nearest,
    lod_min_clamp    = 0.0,
    lod_max_clamp    = 32.0,
    compare          = .Undefined,
    anisotropy_clamp = 1,
    border_color     = .Undefined,
}

Proc_Sampler_Get_Label :: #type proc(sampler: Sampler, loc := #caller_location) -> string

Proc_Sampler_Set_Label :: #type proc(sampler: Sampler, label: string, loc := #caller_location)

Proc_Sampler_Add_Ref :: #type proc(sampler: Sampler, loc := #caller_location)

Proc_Sampler_Release :: #type proc(sampler: Sampler, loc := #caller_location)

// Get the `Sampler` debug label.
sampler_get_label: Proc_Sampler_Get_Label

// Set the `Sampler` debug label.
sampler_set_label: Proc_Sampler_Set_Label

// Increase the `Sampler` reference count.
sampler_add_ref: Proc_Sampler_Add_Ref

// Release the `Sampler` resources, use to decrease the reference count.
sampler_release: Proc_Sampler_Release

// -----------------------------------------------------------------------------
// Texture procedures
// -----------------------------------------------------------------------------


// Handle to a texture on the GPU.
//
// It can be created with `device_create_texture`.
Texture :: distinct rawptr

Texture_Base :: struct {
    label:             String_Buffer_Small,
    ref:               Ref_Count,
    device:            Device,
    allocator:         runtime.Allocator,
    usage:             Texture_Usages,
    dimension:         Texture_Dimension,
    size:              Extent_3D,
    format:            Texture_Format,
    mip_level_count:   u32,
    sample_count:      u32,
    array_layer_count: u32,
    is_swapchain:      bool,
}

Proc_Texture_Create_View :: #type proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View

Proc_Texture_Get_Depth_Or_Array_Layers :: #type proc(
    texture: Texture,
    loc := #caller_location,
) -> u32

Proc_Texture_Get_Dimension :: #type proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Dimension

// Make an `Texel_Copy_Texture_Info` representing the whole texture with the given origin.
@(require_results)
texture_as_image_copy :: proc(self: Texture, origin: Origin_3D = {}) -> Texel_Copy_Texture_Info {
    return {texture = self, mip_level = 0, origin = origin, aspect = .All}
}

Proc_Texture_Get_Format :: #type proc(texture: Texture, loc := #caller_location) -> Texture_Format

Proc_Texture_Get_Height :: #type proc(texture: Texture, loc := #caller_location) -> u32

Proc_Texture_Get_Mip_Level_Count :: #type proc(texture: Texture, loc := #caller_location) -> u32

Proc_Texture_Get_Sample_Count :: #type proc(texture: Texture, loc := #caller_location) -> u32

Proc_Texture_Get_Usage :: #type proc(texture: Texture, loc := #caller_location) -> Texture_Usages

Proc_Texture_Get_Width :: #type proc(texture: Texture, loc := #caller_location) -> u32

Proc_Texture_Get_Size :: #type proc(texture: Texture, loc := #caller_location) -> Extent_3D

Proc_Texture_Get_Descriptor :: #type proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor

Proc_Texture_Get_Label :: #type proc(texture: Texture, loc := #caller_location) -> string

Proc_Texture_Set_Label :: #type proc(texture: Texture, label: string, loc := #caller_location)

Proc_Texture_Add_Ref :: #type proc(texture: Texture, loc := #caller_location)

Proc_Texture_Release :: #type proc(texture: Texture, loc := #caller_location)

@(private)
texture_create_view_impl: Proc_Texture_Create_View

// Creates a view of this texture.
@(require_results)
texture_create_view :: proc(
    texture: Texture,
    descriptor: Maybe(Texture_View_Descriptor) = nil,
    loc := #caller_location,
) -> Texture_View {
    desc := descriptor.? or_else {base_mip_level = 0, base_array_layer = 0, aspect = .All}

    texture_descriptor := texture_get_descriptor(texture, loc)

    // Resolve format
    if desc.format == .Undefined {
        desc.format =
            texture_format_aspect_specific_format(
                texture_descriptor.format,
                desc.aspect,
            ).? or_else texture_descriptor.format
    }

    // Resolve mip_level_count
    if desc.mip_level_count == 0 {
        desc.mip_level_count = max(1, texture_descriptor.mip_level_count - desc.base_mip_level)
    }

    texture_array_layer_count := texture_descriptor_get_array_layer_count(texture_descriptor)

    // Resolve dimension
    if desc.dimension == .Undefined {
        desc.dimension = texture_dimension_compatible_texture_view_dimension(
            texture_descriptor.dimension,
            texture_array_layer_count,
        )
    }

    // Resolve array_layer_count
    if desc.array_layer_count == 0 {
        switch desc.dimension {
        case .D1, .D2, .D3:
            desc.array_layer_count = 1
        case .Cube:
            desc.array_layer_count = 6
        case .D2_Array, .Cube_Array:
            desc.array_layer_count = max(1, texture_array_layer_count - desc.base_array_layer)
        case .Undefined:
            unreachable()
        }
    }

    // Resolve usage
    if desc.usage == {} {
        desc.usage = texture_descriptor.usage
    }

    return texture_create_view_impl(texture, desc, loc)
}

// Returns the depth or array layers of this `Texture`.
//
// This is always equal to the `array_layer_count` that was specified when creating the texture.
texture_get_depth_or_array_layers: Proc_Texture_Get_Depth_Or_Array_Layers

// Returns the dimension of this `Texture`.
//
// This is always equal to the `dimension` that was specified when creating the texture.
texture_get_dimension: Proc_Texture_Get_Dimension

// Returns the format of this `Texture`.
//
// This is always equal to the `format` that was specified when creating the texture.
texture_get_format: Proc_Texture_Get_Format

// Returns the height of this `Texture`.
//
// This is always equal to the `size.height` that was specified when creating the texture.
texture_get_height: Proc_Texture_Get_Height

// Returns the mip_level_count of this `Texture`.
//
// This is always equal to the `mip_level_count` that was specified when
// creating the texture.
texture_get_mip_level_count: Proc_Texture_Get_Mip_Level_Count

// Returns the sample_count of this `Texture`.
//
// This is always equal to the `sample_count` that was specified when
// creating the texture.
texture_get_sample_count: Proc_Texture_Get_Sample_Count

// Returns the allowed usages of this `Texture`.
//
// This is always equal to the `usage` that was specified when creating the texture.
texture_get_usage: Proc_Texture_Get_Usage

// Returns the width of this `Texture`.
//
// This is always equal to the `size.width` that was specified when creating the texture.
texture_get_width: Proc_Texture_Get_Width

// Returns the size of this `Texture`.
//
// This is always equal to the `size` that was specified when creating the texture.
texture_get_size: Proc_Texture_Get_Size

// Returns the descriptor of this `Texture`.
//
// This is always equal to the `descriptor` that was specified when
// creating the texture.
texture_get_descriptor: Proc_Texture_Get_Descriptor

// Get the `Texture` debug label.
texture_get_label: Proc_Texture_Get_Label

// Set the `Texture` debug label.
texture_set_label: Proc_Texture_Set_Label

// Increase the `Texture` reference count.
texture_add_ref: Proc_Texture_Add_Ref

// Release the `Texture` resources, use to decrease the reference count.
texture_release: Proc_Texture_Release

// -----------------------------------------------------------------------------
// Texture View procedures
// -----------------------------------------------------------------------------


// Handle to a texture view.
//
// A `Texture_View` object describes a texture and associated metadata needed by
// a `Render_Pipeline` or `Bind_Group`.
Texture_View :: distinct rawptr

Texture_View_Base :: struct {
    label:             String_Buffer_Small,
    ref:               Ref_Count,
    device:            Device,
    texture:           Texture,
    allocator:         runtime.Allocator,
    format:            Texture_Format,
    dimension:         Texture_View_Dimension,
    usage:             Texture_Usages,
    aspect:            Texture_Aspect,
    base_mip_level:    u32,
    mip_level_count:   u32,
    base_array_layer:  u32,
    array_layer_count: u32,
    is_swapchain:      bool,
}

Proc_Texture_View_Get_Label :: #type proc(
    texture_view: Texture_View,
    loc := #caller_location,
) -> string

Proc_Texture_View_Set_Label :: #type proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
)

Proc_Texture_View_Add_Ref :: #type proc(texture_view: Texture_View, loc := #caller_location)

Proc_Texture_View_Release :: #type proc(texture_view: Texture_View, loc := #caller_location)

// Get the `Texture_View` debug label.
texture_view_get_label: Proc_Texture_View_Get_Label

// Set the `Texture_View` debug label.
texture_view_set_label: Proc_Texture_View_Set_Label

// Increase the `Texture_View` reference count.
texture_view_add_ref: Proc_Texture_View_Add_Ref

// Release the `Texture_View` resources, use to decrease the reference count.
texture_view_release: Proc_Texture_View_Release

// -----------------------------------------------------------------------------
// Render Pass procedures
// -----------------------------------------------------------------------------


// In-progress recording of a render pass: a list of render commands in a
// `Command_Encoder`.
//
// It can be created with `command_encoder_begin_render_pass`, whose
// `Render_Pass_Descriptor` specifies the attachments (textures) that will be
// rendered to.
//
// Most of the procedures for `Render_Pass` serve one of two purposes,
// identifiable by their names:
//
// * `draw*()`: Drawing (that is, encoding a render command, which, when
//   executed by the GPU, will rasterize something and execute shaders).
// * `set*()`: Setting part of the [render
//   state](https://gpuweb.github.io/gpuweb/#renderstate) for future drawing
//   commands.
//
// A render pass may contain any number of drawing commands, and before/between
// each command the render state may be updated however you wish; each drawing
// command will be executed using the render state that has been set when the
// `draw*()` procedure is called.
Render_Pass :: distinct rawptr

// Describes a color attachment to a `RenderPass`.
//
// For use with `Render_Pass_Descriptor`.
Render_Pass_Color_Attachment :: struct {
    view:           Texture_View,
    resolve_target: Texture_View,
    ops:            Operations(Color),
    depth_slice:    u32,
}

Render_Pass_Depth_Operations :: struct {
    using depth_ops: Operations(f32),
    read_only:       bool,
}

Render_Pass_Stencil_Operations :: struct {
    using stencil_ops: Operations(u32),
    read_only:         bool,
}

// Describes a depth/stencil attachment to a `RenderPass`.
//
// For use with `RenderPassDescriptor`.
Render_Pass_Depth_Stencil_Attachment :: struct {
    view:        Texture_View,
    depth_ops:   Render_Pass_Depth_Operations,
    stencil_ops: Render_Pass_Stencil_Operations,
}

// Describes the timestamp writes of a render pass.
//
// For use with `Render_Pass_Descriptor`. At least one of
// `beginning_of_pass_write_index` and `end_of_pass_write_index` must be valid.
Render_Pass_Timestamp_Writes :: struct {
    query_set:                     ^Query_Set,
    beginning_of_pass_write_index: u32,
    end_of_pass_write_index:       u32,
}

// Describes the attachments of a render pass.
//
// For use with `command_encoder_begin_render_pass`.
Render_Pass_Descriptor :: struct {
    label:                    string,
    color_attachments:        []Render_Pass_Color_Attachment,
    depth_stencil_attachment: ^Render_Pass_Depth_Stencil_Attachment,
    timestamp_writes:         ^Render_Pass_Timestamp_Writes,
    occlusion_query_set:      Query_Set,
}

Proc_Render_Pass_Begin_Occlusion_Query :: #type proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
)

Proc_Render_Pass_Draw_Indexed :: #type proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
)

Proc_Render_Pass_Draw_Indexed_Indirect :: #type proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

Proc_Render_Pass_Draw_Indirect :: #type proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

Proc_Render_Pass_End :: #type proc(render_pass: Render_Pass, loc := #caller_location)

Proc_Render_Pass_End_Occlusion_Query :: #type proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)

Proc_Render_Pass_Execute_Bundles :: #type proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
)

Proc_Render_Pass_Insert_Debug_Marker :: #type proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
)

Proc_Render_Pass_Pop_Debug_Group :: #type proc(render_pass: Render_Pass, loc := #caller_location)

Proc_Render_Pass_Push_Debug_Group :: #type proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
)

Proc_Render_Pass_Set_Bind_Group :: #type proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
)

Proc_Render_Pass_Set_Index_Buffer :: #type proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE,
    loc := #caller_location,
)

Proc_Render_Pass_Set_Pipeline :: #type proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
)

Proc_Render_Pass_Set_Vertex_Buffer :: #type proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE,
    loc := #caller_location,
)

Proc_Render_Pass_Set_Scissor_Rect :: #type proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
)

Proc_Render_Pass_Set_Viewport :: #type proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
)

Render_Pass_Set_Stencil_Reference :: #type proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
)

Proc_Render_Pass_Draw :: #type proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
)

Proc_Render_Pass_Get_Label :: #type proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) -> string

Proc_Render_Pass_Set_Label :: #type proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
)

Proc_Render_Pass_Add_Ref :: #type proc(render_pass: Render_Pass, loc := #caller_location)

Proc_Render_Pass_Release :: #type proc(render_pass: Render_Pass, loc := #caller_location)

// Start a occlusion query on this render pass.
//
// It can be ended with `render_pass_end_occlusion_query`.
// Occlusion queries may not be nested.
render_pass_begin_occlusion_query: Proc_Render_Pass_Begin_Occlusion_Query

// Draws indexed primitives using the active index buffer and the active vertex buffers.
//
// The active index buffer can be set with `render_pass_set_index_buffer` The
// active vertex buffers can be set with `render_pass_set_vertex_buffer`.
//
// Inputs:
//
// - `indices`: The range of indices to draw.
// - `base_vertex`: value added to each index value before indexing into the vertex buffers.
// - `instances`: Range of instances to draw. Use `0..1` if instance buffers are not used.
render_pass_draw_indexed: Proc_Render_Pass_Draw_Indexed

// Draws indexed primitives using the active index buffer and the active vertex
// buffers, based on the contents of the `indirect_buffer`.
//
// This is like calling `render_pass_draw_indexed` but the contents of the call are
// specified in the `indirect_buffer`. The structure expected in `indirect_buffer`
// must conform to `Draw_Indexed_Indirect_Args`.
render_pass_draw_indexed_indirect: Proc_Render_Pass_Draw_Indexed_Indirect

// TODO
render_pass_draw_indirect: Proc_Render_Pass_Draw_Indirect

// Record the end of the render pass.
render_pass_end: Proc_Render_Pass_End

// End the occlusion query on this render pass. It can be started with
// `render_pass_begin_occlusion_query`. Occlusion queries may not be nested.
render_pass_end_occlusion_query: Proc_Render_Pass_End_Occlusion_Query

// TODO
render_pass_execute_bundles: Proc_Render_Pass_Execute_Bundles

// TODO
render_pass_insert_debug_marker: Proc_Render_Pass_Insert_Debug_Marker

// TODO
render_pass_pop_debug_group: Proc_Render_Pass_Pop_Debug_Group

// TODO
render_pass_push_debug_group: Proc_Render_Pass_Push_Debug_Group

// TODO
render_pass_set_bind_group: Proc_Render_Pass_Set_Bind_Group

// Sets the active index buffer.
//
// Subsequent calls to `render_pass_draw_indexed` on this `Render_Pass` will use
// `buffer` as the source index buffer.
render_pass_set_index_buffer: Proc_Render_Pass_Set_Index_Buffer

// Sets the active render pipeline.
//
// Subsequent draw calls will exhibit the behavior defined by `pipeline`.
render_pass_set_pipeline: Proc_Render_Pass_Set_Pipeline

// Assign a vertex buffer to a slot.

// Subsequent calls to `render_pass_draw` and `render_pass_draw_indexed` on this
// `Render_Pass` will use `buffer` as one of the source vertex buffers.

// The `slot` refers to the index of the matching descriptor in
// `Vertex_State.buffers`.
render_pass_set_vertex_buffer: Proc_Render_Pass_Set_Vertex_Buffer

// TODO
render_pass_set_scissor_rect: Proc_Render_Pass_Set_Scissor_Rect

// TODO
render_pass_set_viewport: Proc_Render_Pass_Set_Viewport

// TODO
render_pass_set_stencil_reference: Render_Pass_Set_Stencil_Reference

// Draws primitives from the active vertex buffer(s).
//
// The active vertex buffer(s) can be set with `render_pass_set_vertex_buffer`.
// Does not use an Index Buffer. If you need this see `render_pass_draw_indexed`
//
// Panics if vertices Range is outside of the range of the vertices range of any
// set vertex buffer.
//
// This drawing command uses the current render state, as set by preceding `set*()`
// procedures. It is not affected by changes to the state that are performed after
// it is called.
render_pass_draw: Proc_Render_Pass_Draw

// Get the `Render_Pass` debug label.
render_pass_get_label: Proc_Render_Pass_Get_Label

// Set the `Render_Pass` debug label.
render_pass_set_label: Proc_Render_Pass_Set_Label

// Increase the `Render_Pass` reference count.
render_pass_add_ref: Proc_Render_Pass_Add_Ref

// Release the `Render_Pass` resources, use to decrease the reference count.
render_pass_release: Proc_Render_Pass_Release

// -----------------------------------------------------------------------------
// Render Bundle Procedures
// -----------------------------------------------------------------------------


// Pre-prepared reusable bundle of GPU operations.
//
// It only supports a handful of render commands, but it makes them reusable.
// Executing a `Render_Bundle` is often more efficient than issuing the underlying
// commands manually.
//
// It can be created by use of a `Render_Bundle_Encoder`, and executed onto a
// `Command_Encoder` using `render_pass_execute_bundles`.
Render_Bundle :: distinct rawptr

Proc_Render_Bundle_Get_Label :: #type proc(
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> string

Proc_Render_Bundle_Set_Label :: #type proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
)

Proc_Render_Bundle_Add_Ref :: #type proc(render_bundle: Render_Bundle, loc := #caller_location)

Proc_Render_Bundle_Release :: #type proc(render_bundle: Render_Bundle, loc := #caller_location)

// Get the `Render_Bundle` debug label.
render_bundle_get_label: Proc_Render_Bundle_Get_Label

// Set the `Render_Bundle` debug label.
render_bundle_set_label: Proc_Render_Bundle_Set_Label

// Increase the `Render_Bundle` reference count.
render_bundle_add_ref: Proc_Render_Bundle_Add_Ref

// Release the `Render_Bundle` resources, use to decrease the reference count.
render_bundle_release: Proc_Render_Bundle_Release

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------


// Handle to a compiled shader module.
//
// A `Shader_Module` represents a compiled shader module on the GPU. It can be
// created by passing source code to `device_create_shader_module`. Shader
// modules are used to define programmable stages of a pipeline.
Shader_Module :: distinct rawptr

Shader_Module_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,
}

Shader_Formats :: distinct bit_set[Shader_Format;u32]
Shader_Format :: enum u32 {
    Private, // Shaders for NDA'd platforms.
    Glsl, // GLSL shaders for OpenGL.
    Spirv, // SPIR-V shaders for Vulkan.
    Dxbc, // DXBC SM5_1 shaders for D3D12.
    Dxil, // DXIL SM6_0 shaders for D3D12.
    Msl, // MSL shaders for Metal.
    Metallib, // Precompiled metallib shaders for Metal.
    Wgsl, // WGSL shaders for WebGPU on the web.
}

SHADER_FORMATS_INVALID :: Shader_Formats{}

// Describes the shader stages that a binding will be visible from.
//
// These can be combined so something that is visible from both vertex and
// fragment shaders can be defined as:
//
// `Shader_Stages{ .Vertex, .Fragment }`
Shader_Stages :: bit_set[Shader_Stage;Flags]
Shader_Stage :: enum i32 {
    // Binding is visible from the vertex shader of a render pipeline.
    Vertex,
    // Binding is visible from the fragment shader of a render pipeline.
    Fragment,
    // Binding is visible from the compute shader of a compute pipeline.
    Compute,
    // Binding is visible from the task shader of a mesh pipeline.
    Task,
    // Binding is visible from the mesh shader of a mesh pipeline.
    Mesh,
}

// Binding is not visible from any shader stage.
SHADER_STAGES_NONE :: Shader_Stages{}

// Binding is visible from the vertex and fragment shaders of a render pipeline.
SHADER_STAGES_VERTEX_FRAGMENT :: Shader_Stages{.Vertex, .Fragment}

// Descriptor for use with `device_create_shader_module`.
Shader_Module_Descriptor :: struct {
    label:       string,
    code:        []u8,
    entry_point: string,
    stage:       Shader_Stage,
}

Proc_Shader_Module_Get_Label :: #type proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string

Proc_Shader_Module_Set_Label :: #type proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
)

Proc_Shader_Module_Add_Ref :: #type proc(shader_module: Shader_Module, loc := #caller_location)

Proc_Shader_Module_Release :: #type proc(shader_module: Shader_Module, loc := #caller_location)

// Get the `Shader_Module` debug label.
shader_module_get_label: Proc_Shader_Module_Get_Label

// Set the `Shader_Module` debug label.
shader_module_set_label: Proc_Shader_Module_Set_Label

// Increase the `Shader_Module` reference count.
shader_module_add_ref: Proc_Shader_Module_Add_Ref

// Release the `Shader_Module` resources, use to decrease the reference count.
shader_module_release: Proc_Shader_Module_Release

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------

Render_Pipeline :: distinct rawptr

Render_Pipeline_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    allocator: runtime.Allocator,
    device:    Device,
}

// Vertex inputs (attributes) to shaders.
//
// These are used to specify the individual attributes within a `Vertex_Buffer_Layout`.
// See its documentation for an example.
Vertex_Attribute :: struct {
    // Format of the input
    format:          Vertex_Format,
    // Byte offset of the start of the input
    offset:          Buffer_Address,
    // Location for this input. Must match the location in the shader.
    shader_location: Shader_Location,
}

// Describes how the vertex buffer is interpreted.
//
// For use in `Vertex_State`.
Vertex_Buffer_Layout :: struct {
    array_stride: u64,
    step_mode:    Vertex_Step_Mode,
    attributes:   []Vertex_Attribute,
}

// Describes the vertex processing in a render pipeline.
//
// For use in `Render_Pipeline_Descriptor`.
Vertex_State :: struct {
    module:      Shader_Module,
    entry_point: string,
    constants:   []Constant_Entry,
    buffers:     []Vertex_Buffer_Layout,
}

// Describes the color state of a render pipeline.
Color_Target_State :: struct {
    // The `Texture_Format` of the image that this pipeline will render to.
    // Must match the format of the corresponding color attachment in
    // `command_encoder_begin_render_pass`
    format:     Texture_Format,
    // The blending that is used for this pipeline.
    blend:      ^Blend_State,
    // Mask which enables/disables writes to different color/alpha channel.
    write_mask: Color_Writes,
}

color_target_state_from :: proc(format: Texture_Format) -> Color_Target_State {
    return {format = format, blend = nil, write_mask = COLOR_WRITES_ALL}
}

// Describes the fragment processing in a render pipeline.
//
// For use in `Render_Pipeline_Descriptor`.
Fragment_State :: struct {
    module:      Shader_Module,
    entry_point: string,
    constants:   []Constant_Entry,
    targets:     []Color_Target_State,
}

Render_Pipeline_Descriptor :: struct {
    label:         string,
    layout:        Pipeline_Layout,
    vertex:        Vertex_State,
    primitive:     Primitive_State,
    depth_stencil: ^Depth_Stencil_State,
    multisample:   Multisample_State,
    fragment:      ^Fragment_State,
}

Proc_Render_Pipeline_Get_Bind_Group_Layout :: #type proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

Proc_Render_Pipeline_Get_Label :: #type proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string

Proc_Render_Pipeline_Set_Label :: #type proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
)

Proc_Render_Pipeline_Add_Ref :: #type proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
)

Proc_Render_Pipeline_Release :: #type proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
)

// Get an object representing the bind group layout at a given index.
//
// If this pipeline was created with a default layout, then bind groups created
// with the returned `Bind_Group_Layout` can only be used with this pipeline.
//
// This procedure will assert if there is no bind group layout at `index`.
render_pipeline_get_bind_group_layout: Proc_Render_Pipeline_Get_Bind_Group_Layout

// Get the `Render_Pipeline` debug label.
render_pipeline_get_label: Proc_Render_Pipeline_Get_Label

// Set the `Render_Pipeline` debug label.
render_pipeline_set_label: Proc_Render_Pipeline_Set_Label

// Increase the `Render_Pipeline` reference count.
render_pipeline_add_ref: Proc_Render_Pipeline_Add_Ref

// Release the `Render_Pipeline` resources, use to decrease the reference count.
render_pipeline_release: Proc_Render_Pipeline_Release

@(private)
check_interface_procedures :: proc() {
    // Global procedures
    // assert(_create_instance != nil)

    // // Adapter procedures
    // assert(adapter_get_info != nil)
    // assert(adapter_info_free_members != nil)
    // assert(adapter_get_features != nil)
    // assert(adapter_has_feature != nil)
    // assert(adapter_get_limits != nil)
    // assert(adapter_request_device != nil)
    // assert(adapter_get_texture_format_capabilities != nil)
    // assert(adapter_get_label != nil)
    // assert(adapter_set_label != nil)
    // assert(adapter_add_ref != nil)
    // assert(adapter_release != nil)

    // // Bind Group procedures
    // assert(bind_group_get_label != nil)
    // assert(bind_group_set_label != nil)
    // assert(bind_group_add_ref != nil)
    // assert(bind_group_release != nil)

    // // Bind Group Layout procedures
    // assert(bind_group_layout_get_label != nil)
    // assert(bind_group_layout_set_label != nil)
    // assert(bind_group_layout_add_ref != nil)
    // assert(bind_group_layout_release != nil)

    // // Buffer procedures
    // assert(buffer_destroy != nil)
    // assert(buffer_get_const_mapped_range != nil)
    // assert(buffer_get_map_state != nil)
    // assert(buffer_get_mapped_range != nil)
    // assert(buffer_get_size != nil)
    // assert(buffer_get_usage != nil)
    // assert(buffer_map_async != nil)
    // assert(buffer_unmap != nil)
    // assert(buffer_get_label != nil)
    // assert(buffer_set_label != nil)
    // assert(buffer_add_ref != nil)
    // assert(buffer_release != nil)

    // // Command Buffer procedures
    // assert(command_buffer_get_label != nil)
    // assert(command_buffer_set_label != nil)
    // assert(command_buffer_add_ref != nil)
    // assert(command_buffer_release != nil)

    // Command Encoder procedures
    // assert(command_encoder_begin_compute_pass != nil)
    // assert(command_encoder_begin_render_pass != nil)
    // assert(command_encoder_copy_buffer_to_buffer != nil)
    // assert(command_encoder_copy_buffer_to_texture != nil)
    // assert(command_encoder_copy_texture_to_buffer != nil)
    // assert(command_encoder_copy_texture_to_texture != nil)
    // assert(command_encoder_clear_buffer != nil)
    // assert(command_encoder_resolve_query_set != nil)
    // assert(command_encoder_write_timestamp != nil)
    // assert(command_encoder_finish != nil)
    // assert(command_encoder_get_label != nil)
    // assert(command_encoder_set_label != nil)
    // assert(command_encoder_add_ref != nil)
    // assert(command_encoder_release != nil)

    // // Compute Pass Encoder procedures
    // assert(compute_pass_dispatch_workgroups != nil)
    // assert(compute_pass_dispatch_workgroups_indirect != nil)
    // assert(compute_pass_end != nil)
    // assert(compute_pass_insert_debug_marker != nil)
    // assert(compute_pass_pop_debug_group != nil)
    // assert(compute_pass_push_debug_group != nil)
    // assert(compute_pass_set_bind_group != nil)
    // assert(compute_pass_set_label != nil)
    // assert(compute_pass_set_pipeline != nil)
    // assert(compute_pass_add_ref != nil)
    // assert(compute_pass_release != nil)
    // assert(compute_pass_get_label != nil)
    // assert(compute_pass_set_label != nil)
    // assert(compute_pass_add_ref != nil)
    // assert(compute_pass_release != nil)

    // // Compute Pipeline procedures
    // assert(compute_pipeline_get_bind_group_layout != nil)
    // assert(compute_pipeline_get_label != nil)
    // assert(compute_pipeline_set_label != nil)
    // assert(compute_pipeline_add_ref != nil)
    // assert(compute_pipeline_release != nil)

    // TODO: remain api
}
