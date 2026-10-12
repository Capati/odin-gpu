package gpu

// Handle to a rendering (graphics) pipeline.
//
// A `RenderPipeline` object represents a graphics pipeline and its stages,
// bindings, vertex buffers and targets. It can be created with
// `device_create_render_pipeline`.
//
// Corresponds to [WebGPU
// `GPURenderPipeline`](https://gpuweb.github.io/gpuweb/#render-pipeline).
Render_Pipeline :: distinct Handle

// Describes a blend component of a `Blend_State`.
//
// Corresponds to [WebGPU `GPUBlendComponent`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpublendcomponent).
Blend_Component :: struct {
    // Multiplier for the source, which is produced by the fragment shader.
    operation:  Blend_Operation,
    // Multiplier for the destination, which is stored in the target.
    src_factor: Blend_Factor,
    // The binary operation applied to the source and destination,
    // multiplied by their respective factors.
    dst_factor: Blend_Factor,
}

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

// Describe the blend state of a render pipeline,
// within `Color_Target_State`.
//
// Corresponds to [WebGPU `GPUBlendState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpublendstate).
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
    color = {
        src_factor = .Src_Alpha,
        dst_factor = .One_Minus_Src_Alpha,
        operation = .Add,
    },
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

// Describes the state of primitive assembly and rasterization in a render pipeline.
//
// Corresponds to [WebGPU `GPUPrimitiveState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuprimitivestate).
Primitive_State :: struct {
    // The primitive topology used to interpret vertices.
    topology:           Primitive_Topology,
    // When drawing strip topologies with indices, this is the required format
    // for the index buffer. This has no effect on non-indexed or non-strip
    // draws.
    //
    // This is required for indexed drawing with strip topology and must match
    // index buffer format, as primitive restart is always enabled in all
    // backends and individual strips will be separated with the index value
    // `0xFFFF` when using `Uint16`, or `0xFFFFFFFF` when using `Uint32`.
    strip_index_format: Index_Format,
    // The face to consider the front for the purpose of culling and stencil operations.
    front_face:         Front_Face,
    // The face culling mode.
    cull_mode:          Cull_Mode,
    // If set to true, the polygon depth is not clipped to 0-1 before rasterization.
    //
    // Enabling this requires `Depth_Clip_Control` to be enabled.
    unclipped_depth:    bool,
    // Controls the way each polygon is rasterized. Can be either `Fill`
    // (default), `Line` or `Point`
    //
    // Setting this to `Line` requires `Polygon_Mode_Line` feature to be enabled.
    //
    // Setting this to `Point` requires `Polygon_Mode_Point` feature to be enabled.
    polygon_mode:       Polygon_Mode,
    // If set to true, the primitives are rendered with conservative
    // overestimation. I.e. any rastered pixel touched by it is filled. Only
    // valid for `Fill`.
    //
    // Enabling this requires `Conservative_Rasterization` feature to be
    // enabled.
    conservative:       bool,
}

// Describes the multi-sampling state of a render pipeline.
//
// Corresponds to [WebGPU `GPUMultisampleState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpumultisamplestate).
Multisample_State :: struct {
    // The number of samples calculated per pixel (for MSAA). For
    // non-multisampled textures, this should be `1`
    count:                     u32,
    // Bitmask that restricts the samples of a pixel modified by this pipeline.
    // All samples can be enabled using the value `max(u32)`
    mask:                      u32,
    // When enabled, produces another sample mask per pixel based on the alpha
    // output value, that is ANDed with the sample mask and the primitive
    // coverage to restrict the set of samples affected by a primitive.
    //
    // The implicit mask produced for alpha of zero is guaranteed to be zero,
    // and for alpha of one is guaranteed to be all 1-s.
    alpha_to_coverage_enabled: bool,
}

DEFAULT_MULTISAMPLE_STATE :: Multisample_State {
    count                     = 1,
    mask                      = max(u32),
    alpha_to_coverage_enabled = false,
}

// Describes stencil state in a render pipeline.
//
// If you are not using stencil state, set this to `STENCIL_FACE_STATE_IGNORE`.
//
// Corresponds to [WebGPU `GPUStencilFaceState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpustencilfacestate).
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

// Returns `true` if the face state doesn't mutate the target values.
stencil_face_is_read_only :: #force_inline proc "contextless" (
    self: Stencil_Face_State,
) -> bool {
    return (self.pass_op == .Keep &&
            self.depth_fail_op == .Keep &&
            self.fail_op == .Keep)
}

// Returns true if the face state uses the reference value for testing or operation.
stencil_face_needs_ref_value :: proc "contextless" (self: Stencil_Face_State) -> bool {
    return compare_function_needs_ref_value(self.compare) ||
           self.fail_op == .Replace ||
           self.depth_fail_op == .Replace ||
           self.pass_op == .Replace
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

// State of the stencil operation (fixed-pipeline stage).
//
// For use in `Depth_Stencil_State`.
//
// Corresponds to a portion of [WebGPU `GPUDepthStencilState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpudepthstencilstate).
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

DEFAULT_STENCIL_STATE :: Stencil_State {
    read_mask = 0xFFFFFFFF,
    write_mask = 0xFFFFFFFF,
}

// Returns true if the stencil test is enabled.
stencil_state_is_enabled :: proc "contextless" (self: Stencil_State) -> bool {
    return (self.front != STENCIL_FACE_STATE_IGNORE || self.back != STENCIL_FACE_STATE_IGNORE) &&
           (self.read_mask != 0 || self.write_mask != 0)
}

// Returns true if the state doesn't mutate the target values.
stencil_state_is_read_only :: proc "contextless" (
    self: Stencil_State,
    cull_mode: Cull_Mode,
) -> bool {
    // The rules are defined in step 7 of the
    // "Device timeline initialization steps" subsection of the
    // "Render Pipeline Creation" section of WebGPU
    //
    // (link to the section:
    // https://gpuweb.github.io/gpuweb/#render-pipeline-creation)

    if self.write_mask == 0 {
        return true
    }

    front_ro := cull_mode == .Front || stencil_face_is_read_only(self.front)
    back_ro := cull_mode == .Back || stencil_face_is_read_only(self.back)

    return front_ro && back_ro
}

// Returns true if the stencil state uses the reference value for testing.
stencil_state_needs_ref_value :: proc(self: Stencil_State) -> bool {
    return stencil_face_needs_ref_value(self.front) ||
           stencil_face_needs_ref_value(self.back)
}

// Describes the biasing setting for the depth target.
//
// For use in `Depth_Stencil_State`.
//
// Corresponds to a portion of [WebGPU `GPUDepthStencilState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpudepthstencilstate).
Depth_Bias_State :: struct {
    // Constant depth biasing factor, in basic units of the depth format.
    constant:    i32,
    // Slope depth biasing factor.
    slope_scale: f32,
    // Depth bias clamp value (absolute).
    clamp:       f32,
}

// Describes the depth/stencil state in a render pipeline.
//
// Corresponds to [WebGPU `GPUDepthStencilState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpudepthstencilstate).
Depth_Stencil_State :: struct {
    // Format of the depth/stencil buffer, must be special depth format. Must
    // match the format of the depth/stencil attachment in
    // `command_encoder_begin_render_pass`.
    format:              Texture_Format,
    // Whether to write updated depth values to the depth attachment.
    depth_write_enabled: bool,
    // Comparison function used to compare depth values in the depth test.
    depth_compare:       Compare_Function,
    // Stencil state.
    stencil:             Stencil_State,
    // Depth bias state.
    bias:                Depth_Bias_State,
}

DEFAULT_DEPTH_STENCIL_STATE :: Depth_Stencil_State {
    format              = .Undefined,
    depth_write_enabled = false,
    depth_compare       = .Always,
    stencil             = DEFAULT_STENCIL_STATE,
}

// Describes the color state of a render pipeline.
//
// Corresponds to [WebGPU `GPUColorTargetState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpucolortargetstate).
Color_Target_State :: struct {
    // The `Texture_Format` of the image that this pipeline will render to. Must
    // match the format of the corresponding color attachment in
    // `command_encoder_begin_render_pass`.
    format:        Texture_Format,
    // The blending that is used for this pipeline.
    blend:         ^Blend_State,
    // Mask which enables/disables writes to different color/alpha channel.
    write_mask:    Color_Writes,
}

DEFAULT_COLOR_TARGET_STATE :: Color_Target_State {
    format        = .Undefined,
    blend         = nil,
    write_mask    = COLOR_WRITES_ALL,
}

// Describes the vertex processing in a render pipeline.
//
// For use in `Render_Pipeline_Descriptor`.
//
// Corresponds to [WebGPU `GPUVertexState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuvertexstate).
Vertex_State :: struct {
    // The compiled shader module for this stage.
    module:              Shader_Module,
    // The name of the entry point in the compiled shader to use.
    //
    // If given, there must be a vertex-stage shader entry point with this name
    // in `module`. Otherwise, expect exactly one vertex-stage entry point in
    // `module`, which will be selected.
    entry_point:         string,
    // Advanced options for when this pipeline is compiled
    compilation_options: Pipeline_Compilation_Options,
    // The format of any vertex buffers used with this pipeline via
    // `render_pass_set_vertex_buffer()`.
    //
    // The attribute locations and types specified in this layout must match the
    // locations and types of the inputs to the `entry_point` function.
    buffers:             []Vertex_Buffer_Layout,
}

// Describes the fragment processing in a render pipeline.
//
// For use in `Render_Pipeline_Descriptor`.
//
// Corresponds to [WebGPU `GPUFragmentState`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpufragmentstate).
Fragment_State :: struct {
    // The compiled shader module for this stage.
    module:              Shader_Module,
    // The name of the entry point in the compiled shader to use.
    //
    // If given, there must be a fragment shader entry point with this name
    // in `module`. Otherwise, expect exactly one fragment-stage entry point in
    // `module`, which will be selected.
    entry_point:         string,
    // Advanced options for when this pipeline is compiled
    compilation_options: Pipeline_Compilation_Options,
    // The color state of the render targets.
    targets:             []Color_Target_State,
}

// Describes a render (graphics) pipeline.
//
// For use with `device_create_render_pipeline`.
//
// Corresponds to [WebGPU `GPURenderPipelineDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderpipelinedescriptor).
Render_Pipeline_Descriptor :: struct {
    // Debug label of the pipeline.
    label:          string,
    // The layout of bind groups for this pipeline.
    layout:         Pipeline_Layout,
    // The compiled vertex stage, its entry point, and the input buffers layout.
    vertex:         Vertex_State,
    // The properties of the pipeline at the primitive assembly and rasterization level.
    primitive:      Primitive_State,
    // The effect of draw calls on the depth and stencil aspects of the output
    // target, if any.
    depth_stencil:  ^Depth_Stencil_State,
    // The multi-sampling properties of the pipeline.
    multisample:    Multisample_State,
    // The compiled fragment stage, its entry point, and the color targets.
    fragment:       ^Fragment_State,
    // If the pipeline will be used with a multiview render pass, this indicates
    // what multiview mask the render pass will be used with. The masks must
    // match exactly.
    //
    // For example, if you wish to render to the first 2 layers, you would use
    // 3=0b11. If you wanted to render to only the 2nd layer, you would use
    // 2=0b10. If you aren't using multiview this should be `0`.
    multiview_mask: u32,
    // The pipeline cache to use when creating this pipeline.
    cache:          Pipeline_Cache,
}

DEFAULT_RENDER_PIPELINE_DESCRIPTOR :: Render_Pipeline_Descriptor {
    label          = "",
    layout         = {},
    vertex         = {},
    primitive      = {},
    depth_stencil  = nil,
    multisample    = DEFAULT_MULTISAMPLE_STATE,
    fragment       = nil,
    multiview_mask = 0,
    cache          = {},
}

// Specifies an interpretation of the bytes of a vertex buffer as vertex
// attributes.
//
// Use this in a `Render_Pipeline_Descriptor` to describe the format of the
// vertex buffers that are passed to `render_pass_set_vertex_buffer()`.
//
// Corresponds to [WebGPU `GPUVertexBufferLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuvertexbufferlayout).
Vertex_Buffer_Layout :: struct {
    // The stride, in bytes, between elements of this buffer (between vertices).
    //
    // This must be a multiple of `VERTEX_ALIGNMENT`.
    array_stride:  u64,
    // How often this vertex buffer is "stepped" forward.
    step_mode:     Vertex_Step_Mode,
    // The list of attributes which comprise a single vertex.
    attributes:    []Vertex_Attribute,
}

// Vertex inputs (attributes) to shaders.
//
// These are used to specify the individual attributes within a `Vertex_Buffer_Layout`.
// See its documentation for an example.
//
// The `vertex_attr_array` procedure can help create these with appropriate offsets.
//
// Corresponds to [WebGPU `GPUVertexAttribute`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuvertexattribute).
Vertex_Attribute :: struct {
    // Format of the input.
    format:          Vertex_Format,
    // Byte offset of the start of the input.
    offset:          u64,
    // Location for this input. Must match the location in the shader.
    shader_location: u32,
}

device_create_render_pipeline: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline

device_create_render_pipeline_async: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    callback_info: Create_Render_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future

render_pipeline_get_bind_group_layout: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

render_pipeline_set_label: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
)

render_pipeline_add_ref: proc(render_pipeline: Render_Pipeline, loc := #caller_location)

render_pipeline_release: proc(render_pipeline: Render_Pipeline, loc := #caller_location)
