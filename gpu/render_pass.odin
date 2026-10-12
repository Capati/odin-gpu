package gpu

// In-progress recording of a render pass: a list of render commands in a
// `Command_Encoder`.
//
// It can be created with `command_encoder_begin_render_pass()`, whose
// `Render_Pass_Descriptor` specifies the attachments (textures) that will be
// rendered to.
//
// Most of the methods on `Render_Pass` serve one of two purposes, identifiable
// by their names:
//
// - `draw_*()`: Drawing (that is, encoding a render command, which, when
//   executed by the GPU, will rasterize something and execute shaders).
// - `set_*()`: Setting part of the render state for future drawing commands.
//
// A render pass may contain any number of drawing commands, and before/between
// each command the render state may be updated however you wish; each drawing
// command will be executed using the render state that has been set when the
// `draw_*()` function is called.
//
// Corresponds to [WebGPU `GPURenderPassEncoder`](
// https://gpuweb.github.io/gpuweb/#render-pass-encoder).
Render_Pass :: distinct Handle

@private
Render_Pass_Impl :: struct {
    device:            Device,
    encoder:           Command_Encoder,
    ref:               Ref_Count_Type,
    // The command recording the start of this pass, which the pass's texture
    // transitions are recorded in.
    begin_cmd:         ^Begin_Render_Pass_Cmd,
    // The attachments of this pass, recorded so that the render bundles
    // executed within it can be checked for compatibility. A format of
    // `Undefined` means there is no attachment in that slot.
    color_formats:     [dynamic; MAX_COLOR_ATTACHMENTS]Texture_Format,
    depth_stencil:     Render_Bundle_Depth_Stencil,
    has_depth_stencil: bool,
    sample_count:      u32,
    is_rendering:      bool,
}

@private
render_pass_get_public_impl: proc "contextless" (
    render_pass: Render_Pass,
    loc := #caller_location,
) -> ^Render_Pass_Impl

// Describes the timestamp writes of a render pass.
//
// For use with `Render_Pass_Descriptor`. At least one of
// `beginning_of_pass_write_index` and `end_of_pass_write_index` must be valid..
//
// Corresponds to [WebGPU `GPURenderPassTimestampWrite`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderpasstimestampwrites).
Render_Pass_Timestamp_Writes :: struct {
    query_set:                     Query_Set,
    beginning_of_pass_write_index: u32,
    end_of_pass_write_index:       u32,
}

DEFAULT_PASS_TIMESTAMP_WRITES :: Render_Pass_Timestamp_Writes {
    query_set                     = {},
    beginning_of_pass_write_index = QUERY_SET_INDEX_UNDEFINED,
    end_of_pass_write_index       = QUERY_SET_INDEX_UNDEFINED,
}

// Describes a color attachment to a `Render_Pass`.
//
// For use with `Render_Pass_Descriptor`.
//
// Corresponds to [WebGPU `GPURenderPassColorAttachment`](
// https://gpuweb.github.io/gpuweb/#color-attachments).
Render_Pass_Color_Attachment :: struct {
    // The view to use as an attachment.
    view:           Texture_View,
    // The depth slice index of a 3D view. It must not be provided if the view
    // is not 3D.
    depth_slice:    u32,
    // The view that will receive the resolved output if multisampling is used.
    //
    // If set, it is always written to, regardless of how `ops` is configured.
    resolve_target: Texture_View,
    // What operations will be performed on this color attachment.
    ops:            Operations(Color),
}

DEFAULT_RENDER_PASS_COLOR_ATTACHMENT :: Render_Pass_Color_Attachment {
    view           = {},
    depth_slice    = DEPTH_SLICE_UNDEFINED,
    resolve_target = {},
}

// Describes a depth/stencil attachment to a `Render_Pass`.
//
// For use with `Render_Pass_Descriptor`.
//
// Corresponds to [WebGPU `GPURenderPassDepthStencilAttachment`](
// https://gpuweb.github.io/gpuweb/#depth-stencil-attachments).
Render_Pass_Depth_Stencil_Attachment :: struct {
    // The view to use as an attachment.
    view:              Texture_View,
    // What operations will be performed on the depth part of the attachment.
    depth_ops:         Operations(f32),
    // What operations will be performed on the stencil part of the attachment.
    stencil_ops:       Operations(u32),
    // If the depth aspect of the depth stencil attachment is read-only.
    //
    // If this is `false` (the depth aspect is writable), `depth_ops` must be
    // provided with valid load/store ops. If this is `true`, `depth_ops` is not
    // required, since the depth aspect will not be written to.
    depth_read_only:   bool,
    // If the stencil aspect of the depth stencil attachment is read-only.
    //
    // If this is `false` (the stencil aspect is writable), `stencil_ops` must
    // be provided with valid load/store ops. If this is `true`, `stencil_ops`
    // is not required, since the stencil aspect will not be written to.
    stencil_read_only: bool,
}

Render_Pass_Max_Draw_Count :: struct {
    max_draw_count: u64,
}

Request_Adapter_WebXR_Options :: struct {
    xr_compatible: bool,
}

// Describes the attachments of a render pass.
//
// For use with `command_encoder_begin_render_pass`.
//
// Corresponds to [WebGPU `GPURenderPassDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderpassdescriptor).
Render_Pass_Descriptor :: struct {
    // Debug label of the render pass.
    label:                    string,
    // The color attachments of the render pass.
    color_attachments:        []Render_Pass_Color_Attachment,
    // The depth and stencil attachment of the render pass, if any.
    depth_stencil_attachment: ^Render_Pass_Depth_Stencil_Attachment,
    // Defines which timestamp values will be written for this pass, and where
    // to write them to.
    //
    // Requires `Timestamp_Query` feature to be enabled.
    timestamp_writes:         ^Render_Pass_Timestamp_Writes,
    // Defines where the occlusion query results will be stored for this pass.
    occlusion_query_set:      Query_Set,
    // The mask of multiview image layers to use for this render pass. For
    // example, if you wish to render to the first 2 layers, you would use
    // 3=0b11. If you wanted ro render to only the 2nd layer, you would use
    // 2=0b10. If you aren't using multiview this should be `None`.
    //
    // Note that setting bits higher than the number of texture layers is a
    // validation error.
    //
    // This doesn't influence load/store/clear/etc operations, as those are
    // defined for attachments, therefore affecting all attachments. Meaning,
    // this affects only any shaders executed on the `RenderPass`.
    multiview_mask:           u32,
}

render_pass_multi_draw_indirect: proc(
    encoder: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count: u32,
    loc := #caller_location,
)

render_pass_multi_draw_indexed_indirect: proc(
    encoder: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count: u32,
    loc := #caller_location,
)

render_pass_multi_draw_indirect_count: proc(
    encoder: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count_buffer: Buffer,
    count_buffer_offset: u64,
    max_count: u32,
    loc := #caller_location,
)

render_pass_multi_draw_indexed_indirect_count: proc(
    encoder: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count_buffer: Buffer,
    count_buffer_offset: u64,
    max_count: u32,
    loc := #caller_location,
)

render_pass_begin_pipeline_statistics_query: proc(
    render_pass: Render_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

render_pass_end_pipeline_statistics_query: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)

render_pass_write_timestamp: proc(
    render_pass: Render_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

render_pass_begin_occlusion_query: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
)

render_pass_draw: proc(
    render_pass: Render_Pass,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
)

render_pass_draw_indexed: proc(
    render_pass: Render_Pass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
)

render_pass_draw_indexed_indirect: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

render_pass_draw_indirect: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

render_pass_end: proc(render_pass: Render_Pass, loc := #caller_location)

render_pass_end_occlusion_query: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)

render_pass_execute_bundles: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
)

render_pass_insert_debug_marker: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
)

render_pass_pop_debug_group: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)

render_pass_push_debug_group: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
)

render_pass_set_bind_group: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
)

render_pass_set_blend_constant: proc(
    render_pass: Render_Pass,
    color: Color,
    loc := #caller_location,
)

render_pass_set_immediates: proc(
    render_pass: Render_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

render_pass_set_index_buffer: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

render_pass_set_label: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
)

render_pass_set_pipeline: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
)

render_pass_set_scissor_rect: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
)

render_pass_set_stencil_reference: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
)

render_pass_set_vertex_buffer: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE,
    loc := #caller_location,
)

render_pass_set_viewport: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
)

render_pass_add_ref: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)

render_pass_release: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
)
