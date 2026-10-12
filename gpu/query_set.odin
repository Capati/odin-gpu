package gpu

// Handle to a query set.
//
// A `Query_Set` is an opaque, mutable storage location for the results of
// queries: which are small pieces of information extracted from other
// operations such as render passes. See `Query_Type` for what types of
// information can be collected.
//
// Each query writes data into one or more result slots in the `Query_Set`,
// which must be created with a sufficient number of slots for that usage. Each
// result slot is a an unsigned 64-bit number.
//
// Using queries consists of the following steps:
//
// 1. Create a `Query_Set` of the appropriate type and number of query result
//    slots using `device_create_query_set()`.
// 2. Pass the `Query_Set` to the commands which will write to it. See
//    `Query_Type` for the possible commands.
// 3. Execute the command `command_encoder_resolve_query_set()`. This converts
//    the opaque data stored in a `Query_Set` into `u64`s stored in a `Buffer`.
// 4. Make use of that buffer, such as by copying its contents to the CPU or
//    reading it from a compute shader.
//
// Corresponds to [WebGPU
// `GPUQuerySet`](https://gpuweb.github.io/gpuweb/#queryset).
Query_Set :: distinct Handle

// Describes a `Query_Set`.
//
// For use with `device_create_query_set`.
//
// Corresponds to [WebGPU `GPUQuerySetDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuquerysetdescriptor).
Query_Set_Descriptor :: struct {
    // Debug label for the query set.
    label:               string,
    // Kind of query that this query set should contain.
    type:                Query_Type,
    // Total number of query result slots the set contains. Must not be zero.
    // Must not be greater than `QUERY_SET_MAX_QUERIES`.
    count:               u32,
    // A pipeline statistics query records information about the execution of pipelines.
    pipeline_statistics: []Pipeline_Statistics_Types,
}

device_create_query_set: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set

query_set_destroy: proc(query_set: Query_Set, loc := #caller_location)

query_set_get_count: proc(query_set: Query_Set, loc := #caller_location) -> u32

query_set_get_type: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type

query_set_set_label: proc(query_set: Query_Set, label: string, loc := #caller_location)

query_set_add_ref: proc(query_set: Query_Set, loc := #caller_location)

query_set_release: proc(query_set: Query_Set, loc := #caller_location)
