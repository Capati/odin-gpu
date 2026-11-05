package gpu

// In-progress recording of a compute pass.
//
// It can be created with `command_encoder_begin_compute_pass`.
//
// Corresponds to [WebGPU `GPUComputePassEncoder`](
// https://gpuweb.github.io/gpuweb/#compute-pass-encoder).
Compute_Pass :: distinct Handle

// Describes a `Compute_Pass`.
//
// For use with `command_encoder_begin_compute_pass`.
Compute_Pass_Descriptor :: struct {
    // Debug label of the compute pass.
    label:            string,
    // Timestamp writes for the beginning and end of the pass, if any.
    //
    // Requires timestamp queries.
    timestamp_writes: ^Render_Pass_Timestamp_Writes,
}

// Begins a pipeline-statistics query at `query_index`.
compute_pass_begin_pipeline_statistics_query: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

// Ends the active pipeline-statistics query.
compute_pass_end_pipeline_statistics_query: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
)

// Writes a timestamp into `query_set` at `query_index`.
compute_pass_write_timestamp: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

// Dispatches `workgroup_count_x * y * z` workgroups.
compute_pass_dispatch_workgroups: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
)

// Dispatches workgroups using arguments read from `indirect_buffer`.
compute_pass_dispatch_workgroups_indirect: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
)

// Ends the compute pass and resumes recording on the command encoder.
compute_pass_end: proc(compute_pass: Compute_Pass, loc := #caller_location)

// Inserts a debug marker at this point in the pass.
compute_pass_insert_debug_marker: proc(
    compute_pass: Compute_Pass,
    marker_label: string,
    loc := #caller_location,
)

// Ends the most recent debug group.
compute_pass_pop_debug_group: proc(compute_pass: Compute_Pass, loc := #caller_location)

// Starts a debug group.
compute_pass_push_debug_group: proc(
    compute_pass: Compute_Pass,
    group_label: string,
    loc := #caller_location,
)

// Binds `group` at `group_index`.
//
// `dynamic_offsets` supplies one offset per dynamic binding in the group.
compute_pass_set_bind_group: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
)

// Sets push-constant data at `offset`.
compute_pass_set_immediates: proc(
    compute_pass: Compute_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

// Sets the active compute pipeline.
compute_pass_set_pipeline: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
)

// Returns the `Compute_Pass`'s debug label.
//
// The string is owned by the `Compute_Pass` and stays valid until the next
// `compute_pass_set_label()` or until the `Compute_Pass` is released.
compute_pass_get_label: proc(compute_pass: Compute_Pass, loc := #caller_location) -> string

// Sets the `Compute_Pass`'s debug label.
//
// The `Compute_Pass` keeps its own copy of `label`, so the caller may release
// its copy immediately after this call.
compute_pass_set_label: proc(compute_pass: Compute_Pass, label: string, loc := #caller_location)

// Increments the compute pass's reference count.
compute_pass_add_ref: proc(compute_pass: Compute_Pass, loc := #caller_location)

// Decrements the compute pass's reference count, destroying it when it reaches
// zero.
compute_pass_release: proc(compute_pass: Compute_Pass, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Compute_Pass_Impl :: struct {
    device:  Device,
    encoder: Command_Encoder,
    ref:     Ref_Count_Type,
}

_compute_pass_get_internal_impl: proc "contextless" (
    compute_pass: Compute_Pass,
    loc := #caller_location,
) -> ^_Compute_Pass_Impl
