package gpu

// In-progress recording of a compute pass.
//
// It can be created with `command_encoder_begin_compute_pass`.
//
// Corresponds to [WebGPU `GPUComputePassEncoder`](
// https://gpuweb.github.io/gpuweb/#compute-pass-encoder).
Compute_Pass :: distinct rawptr

Compute_Pass_Descriptor :: struct {
    label:            string,
    timestamp_writes: ^Render_Pass_Timestamp_Writes,
}

compute_pass_begin_pipeline_statistics_query: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

compute_pass_end_pipeline_statistics_query: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)

compute_pass_write_timestamp: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

compute_pass_dispatch_workgroups: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
)

compute_pass_dispatch_workgroups_indirect: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

compute_pass_end: proc(compute_pass: Compute_Pass, loc := #caller_location)

compute_pass_insert_debug_marker: proc(
    compute_pass: Compute_Pass,
    marker_label: string,
    loc := #caller_location,
)

compute_pass_pop_debug_group: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)

compute_pass_push_debug_group: proc(
    compute_pass: Compute_Pass,
    group_label: string,
    loc := #caller_location,
)

compute_pass_set_bind_group: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
)

compute_pass_set_immediates: proc(
    compute_pass: Compute_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

compute_pass_set_label: proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
)

compute_pass_set_pipeline: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
)

compute_pass_add_ref: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)

compute_pass_release: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)
