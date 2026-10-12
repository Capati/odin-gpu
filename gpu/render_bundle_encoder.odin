package gpu

// Encodes a series of GPU operations into a reusable "render bundle".
//
// It only supports a handful of render commands, but it makes them reusable. It
// can be created with `device_create_render_bundle_encoder`. It can be executed
// onto a `Command_Encoder` using `render_pass_execute_bundles`.
//
// Executing a `Render_Bundle` is often more efficient than issuing the
// underlying commands manually.
//
// Corresponds to [WebGPU `GPURenderBundleEncoder`](
// https://gpuweb.github.io/gpuweb/#gpurenderbundleencoder).
Render_Bundle_Encoder :: distinct rawptr

// Describes the depth/stencil attachment for render bundles.
//
// Corresponds to a portion of [WebGPU `GPURenderBundleEncoderDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderbundleencoderdescriptor).
Render_Bundle_Depth_Stencil :: struct {
    // Format of the attachment.
    depth_stencil_format: Texture_Format,
    // If the depth aspect of the depth stencil attachment is going to be
    // written to.
    //
    // This must match the `Render_Pass_Depth_Stencil_Attachment.depth_ops` of
    // the renderpass this render bundle is executed in. If `depth_ops` is
    // valid, this must be false, otherwise this must be true.
    depth_read_only:      bool,
    // If the stencil aspect of the depth stencil attachment is going to be
    // written to.
    //
    // This must match the `Render_Pass_Depth_Stencil_Attachment.stencil_ops` of
    // the renderpass this render bundle is executed in. If `depth_ops` is
    // valid, this must be false,otherwise this must be true.
    stencil_read_only:    bool,
}

// Describes a `Render_Bundle_Encoder`.
//
// For use with `device_create_render_bundle_encoder`.
//
// Corresponds to [WebGPU `GPURenderBundleEncoderDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderbundleencoderdescriptor).
Render_Bundle_Encoder_Descriptor :: struct {
    // Debug label of the render bundle encoder.
    label:         string,
    // The formats of the color attachments that this render bundle is capable
    // to rendering to. This must match the formats of the color attachments in
    // the render pass this render bundle is executed in.
    color_formats: []Texture_Format,
    // Information about the depth attachment that this render bundle is capable
    // to rendering to. This must match the format of the depth attachments in
    // the render pass this render bundle is executed in.
    depth_stencil: ^Render_Bundle_Depth_Stencil,
    // Sample count this render bundle is capable of rendering to. This must
    // match the pipelines and the render passes it is used in.
    sample_count:  u32,
    // If this render bundle will rendering to multiple array layers in the
    // attachments at the same time.
    multiview:     u32,
}

render_bundle_encoder_draw: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
)

render_bundle_encoder_draw_indexed: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
)

render_bundle_encoder_draw_indexed_indirect: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

render_bundle_encoder_draw_indirect: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

render_bundle_encoder_finish: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    descriptor: Render_Bundle_Descriptor = {},
    loc := #caller_location,
) -> Render_Bundle

render_bundle_encoder_insert_debug_marker: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    marker_label: string,
    loc := #caller_location,
)

render_bundle_encoder_pop_debug_group: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
)

render_bundle_encoder_push_debug_group: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_label: string,
    loc := #caller_location,
)

render_bundle_encoder_set_bind_group: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
)

render_bundle_encoder_set_immediates: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

render_bundle_encoder_set_index_buffer: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

render_bundle_encoder_set_label: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    label: string,
    loc := #caller_location,
)

render_bundle_encoder_set_pipeline: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    pipeline: Render_Pipeline,
    loc := #caller_location,
)

render_bundle_encoder_set_vertex_buffer: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

render_bundle_encoder_add_ref: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
)

render_bundle_encoder_release: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
)
