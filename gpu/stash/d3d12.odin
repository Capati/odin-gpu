#+build windows
package gpu

d3d12_set_procedures :: proc() {
    // Global procedures
    get_instance_features = d3d12_get_instance_features
    get_instance_limits = d3d12_get_instance_limits
    has_instance_feature = d3d12_has_instance_feature

    // Procedures of Adapter
    adapter_get_features = d3d12_adapter_get_features
    adapter_get_info = d3d12_adapter_get_info
    adapter_create_device = d3d12_adapter_create_device
    adapter_add_ref = d3d12_adapter_add_ref
    adapter_release = d3d12_adapter_release

    // Private procedures of Adapter
    adapter_texture_format_capabilities = d3d12_adapter_texture_format_capabilities

    // Procedures of Bind_Group
    bind_group_set_label = d3d12_bind_group_set_label
    bind_group_add_ref = d3d12_bind_group_add_ref
    bind_group_release = d3d12_bind_group_release
    bind_group_layout_set_label = d3d12_bind_group_layout_set_label
    bind_group_layout_add_ref = d3d12_bind_group_layout_add_ref
    bind_group_layout_release = d3d12_bind_group_layout_release

    // Procedures of Buffer
    buffer_destroy = d3d12_buffer_destroy
    buffer_get_const_mapped_range = d3d12_buffer_get_const_mapped_range
    buffer_get_mapped_range = d3d12_buffer_get_mapped_range
    buffer_get_map_state = d3d12_buffer_get_map_state
    buffer_get_size = d3d12_buffer_get_size
    buffer_get_usage = d3d12_buffer_get_usage
    buffer_map_async = d3d12_buffer_map_async
    buffer_map_sync = d3d12_buffer_map_sync
    buffer_read_mapped_range = d3d12_buffer_read_mapped_range
    buffer_set_label = d3d12_buffer_set_label
    buffer_unmap = d3d12_buffer_unmap
    buffer_write_mapped_range = d3d12_buffer_write_mapped_range
    buffer_add_ref = d3d12_buffer_add_ref
    buffer_release = d3d12_buffer_release

    // Procedures of Command_Buffer
    command_buffer_set_label = d3d12_command_buffer_set_label
    command_buffer_add_ref = d3d12_command_buffer_add_ref
    command_buffer_release = d3d12_command_buffer_release

    // Procedures of Command_Encoder
    command_encoder_begin_compute_pass = d3d12_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass = d3d12_command_encoder_begin_render_pass
    command_encoder_clear_buffer = d3d12_command_encoder_clear_buffer
    command_encoder_copy_buffer_to_buffer = d3d12_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture = d3d12_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer = d3d12_command_encoder_copy_texture_to_buffer
    command_encoder_copy_texture_to_texture = d3d12_command_encoder_copy_texture_to_texture
    command_encoder_finish = d3d12_command_encoder_finish
    command_encoder_insert_debug_marker = d3d12_command_encoder_insert_debug_marker
    command_encoder_pop_debug_group = d3d12_command_encoder_pop_debug_group
    command_encoder_push_debug_group = d3d12_command_encoder_push_debug_group
    command_encoder_resolve_query_set = d3d12_command_encoder_resolve_query_set
    command_encoder_set_label = d3d12_command_encoder_set_label
    command_encoder_write_timestamp = d3d12_command_encoder_write_timestamp
    command_encoder_add_ref = d3d12_command_encoder_add_ref
    command_encoder_release = d3d12_command_encoder_release

    // Procedures of Compute_Pass
    compute_pass_dispatch_workgroups = d3d12_compute_pass_dispatch_workgroups
    compute_pass_dispatch_workgroups_indirect =
        d3d12_compute_pass_dispatch_workgroups_indirect
    compute_pass_end = d3d12_compute_pass_end
    compute_pass_insert_debug_marker = d3d12_compute_pass_insert_debug_marker
    compute_pass_pop_debug_group = d3d12_compute_pass_pop_debug_group
    compute_pass_push_debug_group = d3d12_compute_pass_push_debug_group
    compute_pass_set_bind_group = d3d12_compute_pass_set_bind_group
    compute_pass_set_immediates = d3d12_compute_pass_set_immediates
    compute_pass_set_label = d3d12_compute_pass_set_label
    compute_pass_set_pipeline = d3d12_compute_pass_set_pipeline
    compute_pass_add_ref = d3d12_compute_pass_add_ref
    compute_pass_release = d3d12_compute_pass_release

    // Procedures of Compute_Pipeline
    compute_pipeline_get_bind_group_layout = d3d12_compute_pipeline_get_bind_group_layout
    compute_pipeline_set_label = d3d12_compute_pipeline_set_label
    compute_pipeline_add_ref = d3d12_compute_pipeline_add_ref
    compute_pipeline_release = d3d12_compute_pipeline_release

    // Procedures of Device
    device_create_bind_group        = d3d12_device_create_bind_group
    device_create_bind_group_layout      = d3d12_device_create_bind_group_layout
    device_create_buffer            = d3d12_device_create_buffer
    device_create_command_encoder        = d3d12_device_create_command_encoder
    device_create_compute_pipeline       = d3d12_device_create_compute_pipeline
    device_create_compute_pipeline_async = d3d12_device_create_compute_pipeline_async
    device_create_pipeline_layout        = d3d12_device_create_pipeline_layout
    device_create_query_set              = d3d12_device_create_query_set
    device_create_render_bundle_encoder  = d3d12_device_create_render_bundle_encoder
    device_create_render_pipeline        = d3d12_device_create_render_pipeline
    device_create_render_pipeline_async  = d3d12_device_create_render_pipeline_async
    device_create_sampler                = d3d12_device_create_sampler
    device_create_shader_module          = d3d12_device_create_shader_module
    device_create_texture                = d3d12_device_create_texture
    device_destroy                       = d3d12_device_destroy
    device_get_adapter_info              = d3d12_device_get_adapter_info
    device_get_lost_future               = d3d12_device_get_lost_future
    device_get_queue                     = d3d12_device_get_queue
    device_pop_error_scope               = d3d12_device_pop_error_scope
    device_push_error_scope              = d3d12_device_push_error_scope
    device_set_label                     = d3d12_device_set_label
    device_add_ref                       = d3d12_device_add_ref
    device_release                       = d3d12_device_release

    // Procedures of External_Texture
    external_texture_set_label = d3d12_external_texture_set_label
    external_texture_add_ref = d3d12_external_texture_add_ref
    external_texture_release = d3d12_external_texture_release

    // Procedures of Instance
    instance_create_surface = d3d12_instance_create_surface
    instance_get_wgsl_language_features = d3d12_instance_get_wgsl_language_features
    instance_has_wgsl_language_feature = d3d12_instance_has_wgsl_language_feature
    instance_process_events = d3d12_instance_process_events
    instance_create_adapter = d3d12_instance_create_adapter
    instance_wait_any = d3d12_instance_wait_any
    instance_add_ref = d3d12_instance_add_ref
    instance_release = d3d12_instance_release

    // Procedures of Pipeline_Layout
    pipeline_layout_set_label = d3d12_pipeline_layout_set_label
    pipeline_layout_add_ref = d3d12_pipeline_layout_add_ref
    pipeline_layout_release = d3d12_pipeline_layout_release

    // Procedures of Query_Set
    query_set_destroy = d3d12_query_set_destroy
    query_set_get_count = d3d12_query_set_get_count
    query_set_get_type = d3d12_query_set_get_type
    query_set_set_label = d3d12_query_set_set_label
    query_set_add_ref = d3d12_query_set_add_ref
    query_set_release = d3d12_query_set_release

    // Procedures of Queue
    queue_on_submitted_work_done = d3d12_queue_on_submitted_work_done
    queue_set_label = d3d12_queue_set_label
    queue_submit = d3d12_queue_submit
    // queue_write_buffer_raw = d3d12_queue_write_buffer_raw
    // queue_write_buffer_bytes = d3d12_queue_write_buffer_bytes
    queue_write_texture = d3d12_queue_write_texture
    queue_add_ref = d3d12_queue_add_ref
    queue_release = d3d12_queue_release

    // Procedures of Render_Bundle
    render_bundle_set_label = d3d12_render_bundle_set_label
    render_bundle_add_ref = d3d12_render_bundle_add_ref
    render_bundle_release = d3d12_render_bundle_release

    // Procedures of Render_Bundle_Encoder
    render_bundle_encoder_draw = d3d12_render_bundle_encoder_draw
    render_bundle_encoder_draw_indexed = d3d12_render_bundle_encoder_draw_indexed
    render_bundle_encoder_draw_indexed_indirect = d3d12_render_bundle_encoder_draw_indexed_indirect
    render_bundle_encoder_draw_indirect = d3d12_render_bundle_encoder_draw_indirect
    render_bundle_encoder_finish = d3d12_render_bundle_encoder_finish
    render_bundle_encoder_insert_debug_marker = d3d12_render_bundle_encoder_insert_debug_marker
    render_bundle_encoder_pop_debug_group = d3d12_render_bundle_encoder_pop_debug_group
    render_bundle_encoder_push_debug_group = d3d12_render_bundle_encoder_push_debug_group
    render_bundle_encoder_set_bind_group = d3d12_render_bundle_encoder_set_bind_group
    render_bundle_encoder_set_immediates = d3d12_render_bundle_encoder_set_immediates
    render_bundle_encoder_set_index_buffer = d3d12_render_bundle_encoder_set_index_buffer
    render_bundle_encoder_set_label = d3d12_render_bundle_encoder_set_label
    render_bundle_encoder_set_pipeline = d3d12_render_bundle_encoder_set_pipeline
    render_bundle_encoder_set_vertex_buffer = d3d12_render_bundle_encoder_set_vertex_buffer
    render_bundle_encoder_add_ref = d3d12_render_bundle_encoder_add_ref
    render_bundle_encoder_release = d3d12_render_bundle_encoder_release

    // Procedures of Render_Pass
    render_pass_begin_occlusion_query = d3d12_render_pass_begin_occlusion_query
    render_pass_draw = d3d12_render_pass_draw
    render_pass_draw_indexed = d3d12_render_pass_draw_indexed
    render_pass_draw_indexed_indirect = d3d12_render_pass_draw_indexed_indirect
    render_pass_draw_indirect = d3d12_render_pass_draw_indirect
    render_pass_end = d3d12_render_pass_end
    render_pass_end_occlusion_query = d3d12_render_pass_end_occlusion_query
    render_pass_execute_bundles = d3d12_render_pass_execute_bundles
    render_pass_insert_debug_marker = d3d12_render_pass_insert_debug_marker
    render_pass_pop_debug_group = d3d12_render_pass_pop_debug_group
    render_pass_push_debug_group = d3d12_render_pass_push_debug_group
    render_pass_set_bind_group = d3d12_render_pass_set_bind_group
    render_pass_set_blend_constant = d3d12_render_pass_set_blend_constant
    render_pass_set_immediates = d3d12_render_pass_set_immediates
    render_pass_set_index_buffer = d3d12_render_pass_set_index_buffer
    render_pass_set_label = d3d12_render_pass_set_label
    render_pass_set_pipeline = d3d12_render_pass_set_pipeline
    render_pass_set_scissor_rect = d3d12_render_pass_set_scissor_rect
    render_pass_set_stencil_reference = d3d12_render_pass_set_stencil_reference
    render_pass_set_vertex_buffer = d3d12_render_pass_set_vertex_buffer
    render_pass_set_viewport = d3d12_render_pass_set_viewport
    render_pass_add_ref = d3d12_render_pass_add_ref
    render_pass_release = d3d12_render_pass_release

    // Procedures of Render_Pipeline
    render_pipeline_get_bind_group_layout = d3d12_render_pipeline_get_bind_group_layout
    render_pipeline_set_label = d3d12_render_pipeline_set_label
    render_pipeline_add_ref = d3d12_render_pipeline_add_ref
    render_pipeline_release = d3d12_render_pipeline_release

    // Procedures of Sampler
    sampler_set_label = d3d12_sampler_set_label
    sampler_add_ref = d3d12_sampler_add_ref
    sampler_release = d3d12_sampler_release

    // Procedures of Shader_Module
    shader_module_get_compilation_info = d3d12_shader_module_get_compilation_info
    shader_module_set_label = d3d12_shader_module_set_label
    shader_module_add_ref = d3d12_shader_module_add_ref
    shader_module_release = d3d12_shader_module_release

    // Procedures of Supported_Features
    supported_features_free_members = d3d12_supported_features_free_members

    // Procedures of Supported_Instance_Features
    supported_instance_features_free_members = d3d12_supported_instance_features_free_members

    // Procedures of Supported_WGSL_Language_Features
    supported_wgsl_language_features_free_members =
        d3d12_supported_wgsl_language_features_free_members

    // Procedures of Surface
    surface_configure = d3d12_surface_configure
    surface_get_capabilities = d3d12_surface_get_capabilities
    surface_get_current_texture = d3d12_surface_get_current_texture
    surface_present = d3d12_surface_present
    surface_set_label = d3d12_surface_set_label
    surface_unconfigure = d3d12_surface_unconfigure
    surface_add_ref = d3d12_surface_add_ref
    surface_release = d3d12_surface_release
    surface_capabilities_free_members = d3d12_surface_capabilities_free_members

    // Procedures of Texture
    texture_create_view = d3d12_texture_create_view
    texture_destroy = d3d12_texture_destroy
    texture_get_depth_or_array_layers = d3d12_texture_get_depth_or_array_layers
    texture_get_descriptor = d3d12_texture_get_descriptor
    texture_get_dimension = d3d12_texture_get_dimension
    texture_get_format = d3d12_texture_get_format
    texture_get_height = d3d12_texture_get_height
    texture_get_mip_level_count = d3d12_texture_get_mip_level_count
    texture_get_sample_count = d3d12_texture_get_sample_count
    texture_get_texture_binding_view_dimension = d3d12_texture_get_texture_binding_view_dimension
    texture_get_usage = d3d12_texture_get_usage
    texture_get_width = d3d12_texture_get_width
    texture_set_label = d3d12_texture_set_label
    texture_add_ref = d3d12_texture_add_ref
    texture_release = d3d12_texture_release

    // Procedures of Texture_View
    texture_view_set_label = d3d12_texture_view_set_label
    texture_view_add_ref = d3d12_texture_view_add_ref
    texture_view_release = d3d12_texture_view_release
}

// -----------------------------------------------------------------------------
// Global procedures
// -----------------------------------------------------------------------------

d3d12_create_instance :: proc(
    descriptor: ^Instance_Descriptor = nil,
    loc := #caller_location,
) -> Instance {
    unimplemented(loc = loc)
}

d3d12_get_instance_features :: proc(loc := #caller_location) -> Instance_Features {
    unimplemented(loc = loc)
}

d3d12_get_instance_limits :: proc(loc := #caller_location) -> (limits: Instance_Limits) {
    unimplemented(loc = loc)
}

d3d12_has_instance_feature :: proc(feature: Instance_Feature_Name, loc := #caller_location) -> bool {
    unimplemented(loc = loc)
}

d3d12_set_log_callback :: proc(callback: Log_Callback, userdata: rawptr, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_set_log_level :: proc(level: Log_Level, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_get_version :: proc(loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Adapter
// -----------------------------------------------------------------------------

d3d12_adapter_get_features :: proc(adapter: Adapter, loc := #caller_location) -> Features {
    unimplemented(loc = loc)
}

d3d12_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
) {
    unimplemented(loc = loc)
}

d3d12_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
    unimplemented(loc = loc)
}

d3d12_adapter_has_feature :: proc(
    adapter: Adapter,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

d3d12_adapter_create_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device {
    unimplemented(loc = loc)
}

d3d12_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Adapter private procedures
// -----------------------------------------------------------------------------

d3d12_adapter_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> (caps: Texture_Format_Capabilities) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Adapter_Info
// -----------------------------------------------------------------------------

d3d12_adapter_info_free_members :: proc(
    adapter_info: Adapter_Info,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Bind_Group
// -----------------------------------------------------------------------------

d3d12_bind_group_set_label :: proc(Bind_Group: Bind_Group, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_bind_group_add_ref :: proc(Bind_Group: Bind_Group, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_bind_group_release :: proc(Bind_Group: Bind_Group, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Bind_Group_Layout
// -----------------------------------------------------------------------------

d3d12_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Buffer
// -----------------------------------------------------------------------------

d3d12_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_buffer_get_const_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    unimplemented(loc = loc)
}

d3d12_buffer_get_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    unimplemented(loc = loc)
}

d3d12_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    unimplemented(loc = loc)
}

d3d12_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    unimplemented(loc = loc)
}

d3d12_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    unimplemented(loc = loc)
}

d3d12_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_buffer_map_sync :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    loc := #caller_location,
) -> rawptr {
    unimplemented(loc = loc)
}

d3d12_buffer_read_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    unimplemented(loc = loc)
}

d3d12_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_buffer_write_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    unimplemented(loc = loc)
}

d3d12_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Command_Buffer
// -----------------------------------------------------------------------------

d3d12_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of D3d12_Command_Encoder_Impl
// -----------------------------------------------------------------------------

d3d12_command_encoder_begin_compute_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass {
    unimplemented(loc = loc)
}

d3d12_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    unimplemented(loc = loc)
}

d3d12_command_encoder_clear_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_copy_buffer_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_copy_buffer_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_copy_texture_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_copy_texture_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer {
    unimplemented(loc = loc)
}

d3d12_command_encoder_insert_debug_marker :: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_pop_debug_group :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_push_debug_group :: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_resolve_query_set :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_write_timestamp :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Compute_Pass
// -----------------------------------------------------------------------------

d3d12_compute_pass_dispatch_workgroups :: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_dispatch_workgroups_indirect :: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_end :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_insert_debug_marker :: proc(
    compute_pass: Compute_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_pop_debug_group :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_push_debug_group :: proc(
    compute_pass: Compute_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_set_bind_group :: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_set_immediates :: proc(
    compute_pass: Compute_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_set_label :: proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_set_pipeline :: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_add_ref :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pass_release :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Compute_Pipeline
// -----------------------------------------------------------------------------

d3d12_compute_pipeline_get_bind_group_layout :: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

d3d12_compute_pipeline_set_label :: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_compute_pipeline_add_ref :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_compute_pipeline_release :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of D3d12_Device_Impl
// -----------------------------------------------------------------------------

d3d12_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
    unimplemented(loc = loc)
}

d3d12_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    unimplemented(loc = loc)
}

d3d12_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

d3d12_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    unimplemented(loc = loc)
}

d3d12_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor,
    loc := #caller_location,
) -> Command_Encoder {
    unimplemented(loc = loc)
}

d3d12_device_create_compute_pipeline :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline {
    unimplemented(loc = loc)
}

d3d12_device_create_compute_pipeline_async :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    unimplemented(loc = loc)
}

d3d12_device_create_query_set :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set {
    unimplemented(loc = loc)
}

d3d12_device_create_render_bundle_encoder :: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder {
    unimplemented(loc = loc)
}

d3d12_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    unimplemented(loc = loc)
}

d3d12_device_create_render_pipeline_async :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    callback_info: Create_Render_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    unimplemented(loc = loc)
}

d3d12_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    unimplemented(loc = loc)
}

d3d12_device_create_texture :: proc(
    device: Device,
    _descriptor_: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    unimplemented(loc = loc)
}

d3d12_device_destroy :: proc(device: Device, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_device_get_adapter_info :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
    status: Status,
) {
    unimplemented(loc = loc)
}

d3d12_device_get_features :: proc(
    device: Device,
    allocator := context.allocator,
    loc := #caller_location,
) -> []Feature_Name {
    unimplemented(loc = loc)
}

d3d12_device_get_features_view :: proc(
    device: Device,
    loc := #caller_location,
) -> []Feature_Name {
    unimplemented(loc = loc)
}

d3d12_device_get_limits :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    limits: Limits,
    status: Status,
) {
    unimplemented(loc = loc)
}

d3d12_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
    unimplemented(loc = loc)
}

d3d12_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    unimplemented(loc = loc)
}

d3d12_device_has_feature :: proc(
    device: Device,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

d3d12_device_pop_error_scope :: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_device_push_error_scope :: proc(
    device: Device,
    filter: Error_Filter,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_device_backend :: proc(device: Device, loc := #caller_location) -> Backend_Type {
    return .D3D12
}

d3d12_device_is_embedded :: proc(device: Device, loc := #caller_location) -> bool {
    return false
}

d3d12_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_device_add_ref :: proc(device: Device, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_device_release :: proc(device: Device, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of External_Texture
// -----------------------------------------------------------------------------

d3d12_external_texture_set_label :: proc(
    external_texture: External_Texture,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_external_texture_add_ref :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_external_texture_release :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Instance
// -----------------------------------------------------------------------------

d3d12_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    unimplemented(loc = loc)
}

d3d12_instance_get_wgsl_language_features :: proc(
    instance: Instance,
    loc := #caller_location,
) -> Supported_WGSL_Language_Features {
    unimplemented(loc = loc)
}

d3d12_instance_has_wgsl_language_feature :: proc(
    instance: Instance,
    feature: WGSL_Language_Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

d3d12_instance_process_events :: proc(instance: Instance, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_instance_create_adapter :: proc(
    instance: Instance,
    options: Request_Adapter_Options = {},
    loc := #caller_location,
) -> Adapter {
    unimplemented(loc = loc)
}

d3d12_instance_wait_any :: proc(
    instance: Instance,
    futures: []^Future_Wait_Info,
    timeout_ns: u64 = max(u64),
    loc := #caller_location,
) -> Wait_Status {
    unimplemented(loc = loc)
}

d3d12_generate_report :: proc(
    instance: Instance,
    loc := #caller_location,
) -> (
    report: Global_Report,
) {
    unimplemented(loc = loc)
}

d3d12_instance_enumerate_adapters :: proc(
    instance: Instance,
    options: ^Instance_Enumerate_Adapter_Options = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    adapters: []Adapter,
) {
    unimplemented(loc = loc)
}

d3d12_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_instance_release :: proc(instance: Instance, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Pipeline_Layout
// -----------------------------------------------------------------------------

d3d12_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Query_Set
// -----------------------------------------------------------------------------

d3d12_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
    unimplemented(loc = loc)
}

d3d12_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Queue
// -----------------------------------------------------------------------------

d3d12_queue_on_submitted_work_done :: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}
d3d12_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_queue_write_buffer_raw :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_queue_write_buffer_bytes :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: []u8,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []u8,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_queue_submit_for_index :: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index {
    unimplemented(loc = loc)
}

d3d12_queue_get_timestamp_period :: proc(queue: Queue, loc := #caller_location) -> f32 {
    unimplemented(loc = loc)
}

d3d12_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_queue_release :: proc(queue: Queue, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle
// -----------------------------------------------------------------------------

d3d12_render_bundle_set_label :: proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle_Encoder
// -----------------------------------------------------------------------------

d3d12_render_bundle_encoder_draw :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_draw_indexed :: proc(
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

d3d12_render_bundle_encoder_draw_indexed_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_draw_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_finish :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    descriptor: Render_Bundle_Descriptor,
    loc := #caller_location,
) -> Render_Bundle {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_insert_debug_marker :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_pop_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_push_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_bind_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_immediates :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_index_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_label :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_pipeline :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_set_vertex_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_add_ref :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_bundle_encoder_release :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Pass
// -----------------------------------------------------------------------------

d3d12_render_pass_begin_occlusion_query :: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_draw_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_end :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_end_occlusion_query :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_execute_bundles :: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_insert_debug_marker :: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_pop_debug_group :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_push_debug_group :: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_blend_constant :: proc(
    render_pass: Render_Pass,
    color: Color,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_immediates :: proc(
    render_pass: Render_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_add_ref :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pass_release :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Pipeline
// -----------------------------------------------------------------------------

d3d12_render_pipeline_get_bind_group_layout :: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

d3d12_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Sampler
// -----------------------------------------------------------------------------

d3d12_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Shader_Module
// -----------------------------------------------------------------------------

d3d12_shader_module_get_compilation_info :: proc(
    shader_module: Shader_Module,
    callback_info: Compilation_Info_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

d3d12_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_Features
// -----------------------------------------------------------------------------

d3d12_supported_features_free_members :: proc(
    features: []Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_Instance_Features
// -----------------------------------------------------------------------------

d3d12_supported_instance_features_free_members :: proc(
    features: []Instance_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_WGSL_Language_Features
// -----------------------------------------------------------------------------

d3d12_supported_wgsl_language_features_free_members :: proc(
    features: []WGSL_Language_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Surface
// -----------------------------------------------------------------------------

d3d12_surface_configure :: proc(
    surface: Surface,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    unimplemented(loc = loc)
}

d3d12_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    surface_texture: Surface_Texture,
) {
    unimplemented(loc = loc)
}

d3d12_surface_present :: proc(surface: Surface, loc := #caller_location) -> Status {
    unimplemented(loc = loc)
}

d3d12_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_surface_unconfigure :: proc(surface: Surface, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_surface_release :: proc(surface: Surface, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Surface_Capabilities
// -----------------------------------------------------------------------------

d3d12_surface_capabilities_free_members :: proc(
    surface_capabilities: Surface_Capabilities,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Texture
// -----------------------------------------------------------------------------

d3d12_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View {
    unimplemented(loc = loc)
}

d3d12_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_texture_get_depth_or_array_layers :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    unimplemented(loc = loc)
}

d3d12_texture_get_dimension :: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension {
    unimplemented(loc = loc)
}

d3d12_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    unimplemented(loc = loc)
}

d3d12_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_texture_get_texture_binding_view_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_View_Dimension {
    unimplemented(loc = loc)
}

d3d12_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    unimplemented(loc = loc)
}

d3d12_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

d3d12_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_texture_release :: proc(texture: Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Texture_View
// -----------------------------------------------------------------------------

d3d12_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

d3d12_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    unimplemented(loc = loc)
}

d3d12_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    unimplemented(loc = loc)
}
