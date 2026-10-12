package gpu

// Core
import "base:runtime"
import "core:slice"

// Open connection to a graphics and/or compute device.
//
// Responsible for the creation of most rendering and compute resources.
// These are then used in commands, which are submitted to a `Queue`.
//
// A device may be requested from an adapter with `adapter_request_device`.
//
// Corresponds to [WebGPU `GPUDevice`](https://gpuweb.github.io/gpuweb/#gpu-device).
Device :: distinct rawptr

@private
Device_Impl :: struct {
    instance:        Instance,
    adapter:         Adapter,
    limits:          Limits,
    features:        []Feature_Name,
    dl_features:     Downlevel_Features,
    trackers:        Device_Tracker,
    tracker_indices: Tracker_Index_Allocators,
    alignments:      Alignments,
    backend:         Backend_Type,
    is_embedded:     bool,
    allocator:       runtime.Allocator,
    ref:             Ref_Count_Type,
}

@private
device_get_public_impl: proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^Device_Impl

// Describes a `Device`.
//
// For use with `adapter_request_device`.
//
// Corresponds to [WebGPU `GPUDeviceDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpudevicedescriptor).
Device_Descriptor :: struct {
    // Debug label for the device.
    label:                                 string,
    // Specifies the features that are required by the device request.
    // The request will fail if the adapter cannot provide these features.
    //
    // Exactly the specified set of features, and no more or less,
    // will be allowed in validation of API calls on the resulting device.
    required_features:                     []Feature_Name,
    // Specifies the limits that are required by the device request.
    // The request will fail if the adapter cannot provide these limits.
    //
    // Exactly the specified limits, and no better or worse,
    // will be allowed in validation of API calls on the resulting device.
    required_limits:                       Limits,
    // Describes a default `Queue`.
    default_queue:                         Queue_Descriptor,
    // Information used to register a device-lost callback.
    lost_callback_info:                    Device_Lost_Callback_Info,
    // Information used to register an uncaptured-error callback.
    uncaptured_error_callback_info:        Uncaptured_Error_Callback_Info,
    // Whether API tracing for debugging is enabled,
    // and where the trace is written if so.
    trace_path:                            string,
    // Hints for memory allocation strategies.
    memory_hints:                          Memory_Hints,
    // Defines the range of allowed memory block sizes for sub-allocated
    // resources.
    //
    // The backend may attempt to group multiple resources into fewer device
    // memory blocks (sub-allocation) for performance reasons. The start of the
    // provided range specifies the initial memory block size for sub-allocated
    // resources. After running out of space in existing memory blocks, the
    // backend may chose to progressively increase the block size of subsequent
    // allocations up to a limit specified by the end of the range.
    //
    // This does not limit resource sizes. If a resource does not fit in the
    // specified range, it will typically be placed in a dedicated memory block.
    suballocated_device_memory_block_size: Range(u64),
}

// Hints to the device about the memory allocation strategy.
//
// Some backends may ignore these hints.
Memory_Hints :: enum i32 {
    // Favor performance over memory usage (the default value).
    Performance,
    // Favor memory usage over performance.
    Memory_Usage,
    // Applications that have control over the content that is rendered
    // (typically games) may find an optimal compromise between memory
    // usage and performance by specifying the allocation configuration.
    Manual,
}

Supported_Features :: struct {
    features: []Feature_Name,
}

Compatibility_Mode_Limits :: struct {
    max_storage_buffers_in_vertex_stage:    u32,
    max_storage_textures_in_vertex_stage:   u32,
    max_storage_buffers_in_fragment_stage:  u32,
    max_storage_textures_in_fragment_stage: u32,
}

DEFAULT_COMPATIBILITY_MODE_LIMITS :: Compatibility_Mode_Limits {
    max_storage_buffers_in_vertex_stage    = LIMIT_U32_UNDEFINED,
    max_storage_textures_in_vertex_stage   = LIMIT_U32_UNDEFINED,
    max_storage_buffers_in_fragment_stage  = LIMIT_U32_UNDEFINED,
    max_storage_textures_in_fragment_stage = LIMIT_U32_UNDEFINED,
}

device_poll: proc(
    device: Device,
    wait: bool,
    submission_index: ^Submission_Index,
    loc := #caller_location,
) -> bool

device_get_native_metal_device: proc(device: Device, loc := #caller_location) -> rawptr

device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
    impl := device_get_public_impl(device, loc)
    return impl.adapter
}

device_get_instance :: proc(device: Device, loc := #caller_location) -> Instance {
    impl := device_get_public_impl(device, loc)
    return impl.instance
}

device_start_graphics_debugger_capture: proc(device: Device, loc := #caller_location) -> bool

device_stop_graphics_debugger_capture: proc(device: Device, loc := #caller_location)

device_destroy: proc(device: Device, loc := #caller_location)

device_get_adapter_info: proc(device: Device, loc := #caller_location) -> (Adapter_Info, Status)

device_get_features :: proc(
    device: Device,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    features: []Feature_Name,
) {
    impl := device_get_public_impl(device, loc)
    features = make([]Feature_Name, len(impl.features), allocator)
    copy(features, impl.features[:])
    return
}

device_get_features_view :: proc( device: Device, loc := #caller_location)  -> []Feature_Name {
    impl := device_get_public_impl(device, loc)
    return impl.features[:]
}

device_get_limits :: proc(device: Device, loc := #caller_location) -> Limits {
    impl := device_get_public_impl(device, loc)
    return impl.limits
}

device_get_lost_future: proc(device: Device, loc := #caller_location) -> Future

device_get_queue: proc(device: Device, loc := #caller_location) -> Queue

device_has_feature :: proc(
    device: Device,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    if feature == {} {
        return true
    }
    impl := device_get_public_impl(device, loc)
    _, found := slice.binary_search(impl.features, feature)
    return found
}

device_pop_error_scope: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future

device_push_error_scope: proc(device: Device, filter: Error_Filter, loc := #caller_location)

// Get the current active backend.
device_backend: proc(device: Device, loc := #caller_location) -> Backend_Type

// Check for embedded backend.
device_is_embedded: proc(device: Device, loc := #caller_location) -> bool

device_set_label: proc(device: Device, label: string, loc := #caller_location)

device_add_ref: proc(device: Device, loc := #caller_location)

device_release: proc(device: Device, loc := #caller_location)

supported_features_free_members: proc(
    features: []Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
)
