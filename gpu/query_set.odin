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

// WebGPU's default limit; the backend sizes its Vulkan pool from it.
QUERY_SET_MAX_QUERIES :: 4096

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

// Creates a query set.
//
// `count` must be between 1 and `QUERY_SET_MAX_QUERIES`. Timestamp and
// pipeline-statistics sets require their corresponding device features.
//
// Returns `{}` when the descriptor is invalid.
device_create_query_set: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set

// Releases the query set's native resources as soon as possible.
//
// The handle stays valid until `query_set_release()`.
query_set_destroy: proc(query_set: Query_Set, loc := #caller_location)

// Returns the number of query slots in the set.
query_set_get_count: proc(query_set: Query_Set, loc := #caller_location) -> u32

// Returns the kind of query stored in the set.
query_set_get_type: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type

// Returns the query set's debug label.
//
// The string is owned by the query set and stays valid until the next
// `query_set_set_label()` or until the query set is released.
query_set_get_label: proc(query_set: Query_Set, loc := #caller_location) -> string

// Sets the query set's debug label.
//
// The query set keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
query_set_set_label: proc(query_set: Query_Set, label: string, loc := #caller_location)

// Increments the query set's reference count.
query_set_add_ref: proc(query_set: Query_Set, loc := #caller_location)

// Decrements the query set's reference count, destroying it when it reaches
// zero.
query_set_release: proc(query_set: Query_Set, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Query_Set_Impl :: struct {
    device: Device,
    type:   Query_Type,
    ref:    Ref_Count_Type,
}

// Returns the concrete implementation behind a query set handle.
_query_set_get_internal_impl: proc "contextless" (
    query_set: Query_Set,
    loc := #caller_location,
) -> ^_Query_Set_Impl

_Query_Set_Descriptor_Impl :: struct {
    type:              Query_Type,
    count:             u32,
    results_per_query: u32,
}

// Backend-independent query-set validation and result-layout resolution.
_resolve_query_set_descriptor :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> (
    _Query_Set_Descriptor_Impl,
    bool,
) {
    if !gpu_validate(
        device,
        descriptor.count > 0,
        "query set count must be greater than zero",
        loc,
    ) {
        return {}, false
    }
    if !gpu_validate(
        device,
        descriptor.count <= QUERY_SET_MAX_QUERIES,
        "query set count exceeds maxQueryCount",
        loc,
    ) {
        return {}, false
    }
    if descriptor.type == .Timestamp &&
       !gpu_validate(
               device,
               device_has_feature(device, .Timestamp_Query),
               "timestamp queries require the [Timestamp_Query] feature",
               loc,
           ) {
        return {}, false
    }

    results_per_query: u32 = 1
    if descriptor.type == .Pipeline_Statistics {
        if !gpu_validate(
            device,
            device_has_feature(device, .Pipeline_Statistics_Query),
            "pipeline-statistics queries require the [Pipeline_Statistics_Query] feature",
            loc,
        ) {
            return {}, false
        }
        if !gpu_validate(
            device,
            len(descriptor.pipeline_statistics) > 0,
            "pipeline-statistics queries require at least one statistic",
            loc,
        ) {
            return {}, false
        }
        results_per_query = u32(len(descriptor.pipeline_statistics))
    }

    return {
            type              = descriptor.type,
            count             = descriptor.count,
            results_per_query = results_per_query,
        }, true
}
