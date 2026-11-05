package gpu

// Core
import "core:slice"

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
        operation  = .Add,
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
stencil_face_is_read_only :: #force_inline proc "contextless" (self: Stencil_Face_State) -> bool {
    return self.pass_op == .Keep && self.depth_fail_op == .Keep && self.fail_op == .Keep
}

// Returns true if the face state uses the reference value for testing or operation.
stencil_face_needs_ref_value :: proc "contextless" (self: Stencil_Face_State) -> bool {
    return(
        compare_function_needs_ref_value(self.compare) ||
        self.fail_op == .Replace ||
        self.depth_fail_op == .Replace ||
        self.pass_op == .Replace \
    )
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
    read_mask  = 0xFFFFFFFF,
    write_mask = 0xFFFFFFFF,
}

// Returns true if the stencil test is enabled.
stencil_state_is_enabled :: proc "contextless" (self: Stencil_State) -> bool {
    return(
        (self.front != STENCIL_FACE_STATE_IGNORE || self.back != STENCIL_FACE_STATE_IGNORE) &&
        (self.read_mask != 0 || self.write_mask != 0) \
    )
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
    return stencil_face_needs_ref_value(self.front) || stencil_face_needs_ref_value(self.back)
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
    format:     Texture_Format,
    // The blending that is used for this pipeline.
    blend:      ^Blend_State,
    // Mask which enables/disables writes to different color/alpha channel.
    write_mask: Color_Writes,
}

DEFAULT_COLOR_TARGET_STATE :: Color_Target_State {
    format     = .Undefined,
    blend      = nil,
    write_mask = COLOR_WRITES_ALL,
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
    //
    // An empty handle requests a default layout inferred from the shader.
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
    array_stride: u64,
    // How often this vertex buffer is "stepped" forward.
    step_mode:    Vertex_Step_Mode,
    // The list of attributes which comprise a single vertex.
    attributes:   []Vertex_Attribute,
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

// Creates a render pipeline.
//
// An empty `layout` requests a default layout inferred from the shaders. Invalid
// descriptors are reported through the device's validation path and return `{}`.
device_create_render_pipeline: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline

// Creates a render pipeline asynchronously.
//
// The returned `Future` resolves when compilation finishes; `callback_info`
// receives the resulting pipeline and status.
device_create_render_pipeline_async: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    callback_info: Create_Render_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future

// Returns the pipeline's bind group layout at `group_index`.
//
// Groups created from this layout are only usable with this pipeline when it
// uses a default layout. An out-of-range index is reported as a validation
// error and returns `{}`.
render_pipeline_get_bind_group_layout: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

// Returns the render pipeline's debug label.
//
// The string is owned by the render pipeline and stays valid until the next
// `render_pipeline_set_label()` or until the render pipeline is released.
render_pipeline_get_label: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string

// Sets the render pipeline's debug label.
//
// The render pipeline keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
render_pipeline_set_label: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
)

// Increments the render pipeline's reference count.
render_pipeline_add_ref: proc(render_pipeline: Render_Pipeline, loc := #caller_location)

// Decrements the render pipeline's reference count, destroying it when it
// reaches zero.
render_pipeline_release: proc(render_pipeline: Render_Pipeline, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Render_Pipeline_Impl :: struct {
    device:          Device,
    layout:          Pipeline_Layout,
    ref:             Ref_Count_Type,
    is_empty_layout: bool,

    // Target state, compared against the active render pass or bundle before
    // a draw is recorded.
    color_formats:     [MAX_COLOR_ATTACHMENTS]Texture_Format,
    color_count:       u32,
    depth_format:      Texture_Format,
    has_depth_stencil: bool,
    sample_count:      u32,

    // Primitive state used by index-buffer validation at draw time.
    topology:           Primitive_Topology,
    strip_index_format: Index_Format,

    // Vertex layouts, indexed by the binding slot. `vertex_mask` marks the
    // slots that have attributes.
    vertex_stride: [MAX_VERTEX_BUFFERS]u64,
    vertex_step:   [MAX_VERTEX_BUFFERS]Vertex_Step_Mode,
    vertex_last:   [MAX_VERTEX_BUFFERS]u64,
    vertex_mask:   u32,
}

// Returns the concrete implementation behind a render pipeline handle.
_render_pipeline_get_internal_impl: proc "contextless" (
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> ^_Render_Pipeline_Impl

// Backend-independent render-pipeline descriptor validation. Backends resolve
// the shader-module and pipeline-layout handle state through their hooks.
_validate_render_pipeline_descriptor :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> bool {
    valid := true

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vertex_module := _shader_module_get_internal_impl(descriptor.vertex.module, loc)
    valid &= gpu_validate(
        device,
        vertex_module != nil,
        "render pipeline vertex shader module is not live",
        loc,
    )
    if vertex_module != nil && vertex_module.device != device {
        valid &= gpu_validate(
            device,
            false,
            "render pipeline vertex shader module belongs to another device",
            loc,
        )
    }
    valid &= gpu_validate(
        device,
        descriptor.vertex.entry_point != "",
        "render pipeline vertex shader entry point is empty",
        loc,
    )

    if descriptor.fragment != nil {
        frag := descriptor.fragment
        fragment_module := _shader_module_get_internal_impl(frag.module, loc)
        valid &= gpu_validate(
            device,
            fragment_module != nil,
            "render pipeline fragment shader module is not live",
            loc,
        )
        if fragment_module != nil && fragment_module.device != device {
            valid &= gpu_validate(
                device,
                false,
                "render pipeline fragment shader module belongs to another device",
                loc,
            )
        }
        valid &= gpu_validate(
            device,
            frag.entry_point != "",
            "render pipeline fragment shader entry point is empty",
            loc,
        )
    }

    if descriptor.layout != {} {
        layout_state := _pipeline_layout_get_internal_impl(descriptor.layout, loc)
        valid &= gpu_validate(
            device,
            layout_state != nil,
            "render pipeline layout is not live",
            loc,
        )
        if layout_state != nil && layout_state.device != device {
            valid &= gpu_validate(
                device,
                false,
                "render pipeline layout belongs to another device",
                loc,
            )
        }
    }

    has_color := descriptor.fragment != nil && len(descriptor.fragment.targets) > 0
    valid &= gpu_validate(
        device,
        has_color || descriptor.depth_stencil != nil,
        "render pipeline needs a color target or a depth/stencil attachment",
        loc,
    )

    if !valid {
        return {}
    }

    if descriptor.fragment != nil {
        targets_valid := true
        for target in descriptor.fragment.targets {
            features, ok := device_describe_format_features(device, target.format, loc)
            targets_valid &= gpu_validate(
                device,
                ok &&
                texture_format_has_color_aspect(target.format) &&
                .Render_Attachment in features.allowed_usages,
                "pipeline color target is not a renderable color format",
                loc,
            )
            if target.blend != nil {
                targets_valid &= gpu_validate(
                    device,
                    ok && .Blendable in features.flags,
                    "pipeline color target format is not blendable on this device",
                    loc,
                )
                for component in ([2]Blend_Component{target.blend.color, target.blend.alpha}) {
                    if component.operation == .Min || component.operation == .Max {
                        targets_valid &= gpu_validate(
                            device,
                            component.src_factor == .One && component.dst_factor == .One,
                            "min/max blending requires both factors to be One",
                            loc,
                        )
                    }
                }
            }
        }

        targets := descriptor.fragment.targets
        if len(targets) > 1 &&
           .Independent_Blend not_in _device_get_internal_impl(device, loc).dl_features {
            first := targets[0]
            for target in targets[1:] {
                same_blend :=
                    (target.blend == nil && first.blend == nil) ||
                    (target.blend != nil && first.blend != nil && target.blend^ == first.blend^)
                targets_valid &= gpu_validate(
                    device,
                    target.write_mask == first.write_mask && same_blend,
                    "independent blend state requires the [Independent_Blend] feature",
                    loc,
                )
            }
        }

        dual_source := false
        for target, index in targets {
            if target.blend == nil {
                continue
            }
            for component in ([2]Blend_Component{target.blend.color, target.blend.alpha}) {
                if component.src_factor == .Src1 ||
                   component.src_factor == .One_Minus_Src1 ||
                   component.src_factor == .Src1_Alpha ||
                   component.src_factor == .One_Minus_Src1_Alpha ||
                   component.dst_factor == .Src1 ||
                   component.dst_factor == .One_Minus_Src1 ||
                   component.dst_factor == .Src1_Alpha ||
                   component.dst_factor == .One_Minus_Src1_Alpha {
                    dual_source = true
                    targets_valid &= gpu_validate(
                        device,
                        index == 0,
                        "dual-source blending is only allowed on the first target",
                        loc,
                    )
                }
            }
        }
        if dual_source {
            targets_valid &= gpu_validate(
                device,
                device_has_feature(device, .Dual_Source_Blending),
                "dual-source blending requires the [Dual_Source_Blending] feature",
                loc,
            )
        }
        if !targets_valid {
            return false
        }
    }

    valid = true

    limits := _device_get_internal_impl(device, loc).limits
    if descriptor.fragment != nil {
        target_count := len(descriptor.fragment.targets)
        valid &= gpu_validate(
            device,
            target_count <= MAX_COLOR_ATTACHMENTS &&
            u32(target_count) <= limits.max_color_attachments,
            "pipeline color target count exceeds max_color_attachments",
            loc,
        )
    }

    buffer_count := len(descriptor.vertex.buffers)
    valid &= gpu_validate(
        device,
        buffer_count <= MAX_VERTEX_BUFFERS && u32(buffer_count) <= limits.max_vertex_buffers,
        "vertex buffer count exceeds max_vertex_buffers",
        loc,
    )

    seen_locations := make([dynamic]u32, 0, 64, ta)
    attribute_count: u32
    for buffer in descriptor.vertex.buffers {
        valid &= gpu_validate(
            device,
            buffer.array_stride % 4 == 0,
            "vertex array stride must be a multiple of 4",
            loc,
        )
        attribute_count += u32(len(buffer.attributes))
        valid &= gpu_validate(
            device,
            buffer.array_stride <= u64(limits.max_vertex_buffer_array_stride),
            "vertex array stride exceeds max_vertex_buffer_array_stride",
            loc,
        )
        for attribute in buffer.attributes {
            valid &= gpu_validate(
                device,
                attribute.shader_location < limits.max_vertex_attributes,
                "vertex shader location exceeds max_vertex_attributes",
                loc,
            )
            valid &= gpu_validate(
                device,
                !slice.contains(seen_locations[:], attribute.shader_location),
                "vertex shader locations must be unique",
                loc,
            )
            append(&seen_locations, attribute.shader_location)

            size := vertex_format_size(attribute.format)
            valid &= gpu_validate(device, size > 0, "invalid vertex attribute format", loc)
            if size > 0 {
                alignment := min(u64(4), u64(size))
                valid &= gpu_validate(
                    device,
                    attribute.offset % alignment == 0,
                    "vertex attribute offset is not format-aligned",
                    loc,
                )
                if buffer.array_stride != 0 {
                    valid &= gpu_validate(
                        device,
                        attribute.offset + u64(size) <= buffer.array_stride,
                        "vertex attribute extends past the array stride",
                        loc,
                    )
                }
            }
        }
    }
    valid &= gpu_validate(
        device,
        attribute_count <= limits.max_vertex_attributes,
        "vertex attribute count exceeds max_vertex_attributes",
        loc,
    )

    if descriptor.primitive.unclipped_depth {
        valid &= gpu_validate(
            device,
            device_has_feature(device, .Depth_Clip_Control),
            "unclipped depth requires the [Depth_Clip_Control] feature",
            loc,
        )
    }
    if descriptor.primitive.strip_index_format != .Undefined {
        topology := descriptor.primitive.topology
        valid &= gpu_validate(
            device,
            topology == .Triangle_Strip || topology == .Line_Strip,
            "strip index format requires a strip topology",
            loc,
        )
    }

    sample_count := max(u32(1), descriptor.multisample.count)
    valid &= gpu_validate(
        device,
        sample_count == 1 || sample_count == 4,
        "pipeline sample count must be 1 or 4",
        loc,
    )
    if descriptor.multisample.alpha_to_coverage_enabled {
        valid &= gpu_validate(
            device,
            sample_count == 4,
            "alpha-to-coverage requires a sample count of 4",
            loc,
        )
        valid &= gpu_validate(
            device,
            descriptor.fragment != nil && len(descriptor.fragment.targets) > 0,
            "alpha-to-coverage requires a first color target",
            loc,
        )
        if descriptor.fragment != nil && len(descriptor.fragment.targets) > 0 {
            format := descriptor.fragment.targets[0].format
            features, ok := device_describe_format_features(device, format, loc)
            valid &= gpu_validate(
                device,
                ok && .Alpha in texture_format_channels(format) && .Blendable in features.flags,
                "alpha-to-coverage requires an alpha, blendable first target",
                loc,
            )
        }
    }

    if depth := descriptor.depth_stencil; depth != nil {
        aspects := texture_format_aspects_from(depth.format)
        has_depth := .Depth in aspects
        has_stencil := .Stencil in aspects
        depth_features, depth_ok := device_describe_format_features(device, depth.format, loc)
        valid &= gpu_validate(
            device,
            depth_ok && .Render_Attachment in depth_features.allowed_usages,
            "depth/stencil state format is not renderable on this device",
            loc,
        )
        valid &= gpu_validate(
            device,
            has_depth || has_stencil,
            "depth/stencil state must name a depth/stencil format",
            loc,
        )

        stencil_needed := false
        for face in ([2]Stencil_Face_State{depth.stencil.front, depth.stencil.back}) {
            if (face.compare != .Undefined && face.compare != .Always) ||
               face.fail_op != .Keep ||
               face.depth_fail_op != .Keep ||
               face.pass_op != .Keep {
                stencil_needed = true
            }
        }
        depth_test := depth.depth_compare != .Undefined && depth.depth_compare != .Always
        depth_needed :=
            depth_test ||
            depth.depth_write_enabled ||
            depth.stencil.front.depth_fail_op != .Keep ||
            depth.stencil.back.depth_fail_op != .Keep

        valid &= gpu_validate(
            device,
            !depth_needed || has_depth,
            "depth state requires a depth aspect",
            loc,
        )
        valid &= gpu_validate(
            device,
            !stencil_needed || has_stencil,
            "stencil state requires a stencil aspect",
            loc,
        )
        if depth.depth_write_enabled && depth.depth_compare == .Undefined {
            gpu_report_validation_error(device, "depth writes require a depth compare", loc)
            valid = false
        }
        if (depth.stencil.front.depth_fail_op != .Keep ||
               depth.stencil.back.depth_fail_op != .Keep) &&
           depth.depth_compare == .Undefined {
            gpu_report_validation_error(
                device,
                "stencil depth-fail ops require a depth compare",
                loc,
            )
            valid = false
        }

        biased := depth.bias.constant != 0 || depth.bias.slope_scale != 0 || depth.bias.clamp != 0
        if biased {
            topology := descriptor.primitive.topology
            valid &= gpu_validate(
                device,
                topology != .Line_List && topology != .Line_Strip && topology != .Point_List,
                "depth bias requires a triangle topology",
                loc,
            )
        }
    }

    return valid
}
