#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
// import vk "vendor:vulkan"

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle_Encoder
// -----------------------------------------------------------------------------

VK_Render_Bundle_Encoder_Handle :: distinct hm.Handle64

VK_Render_Bundle_Encoder_Impl :: struct {
    handle: VK_Render_Bundle_Encoder_Handle,
    ref:    Ref_Count_Type,
}

vk_render_bundle_encoder_draw :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_draw_indexed :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_draw_indexed_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_draw_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_finish :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    descriptor: Render_Bundle_Descriptor,
    loc := #caller_location,
) -> Render_Bundle {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_insert_debug_marker :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_pop_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_push_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_bind_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_immediates :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_index_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_label :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_pipeline :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_set_vertex_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_add_ref :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_encoder_release :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}
