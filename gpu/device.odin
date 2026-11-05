package gpu

// Core
import "base:runtime"

// Open connection to a graphics and/or compute device.
//
// Responsible for the creation of most rendering and compute resources.
// These are then used in commands, which are submitted to a `Queue`.
//
// A device may be requested from an adapter with `adapter_create_device()`.
//
// Threading: a device, its queue and any surface created from its instance are
// driven by one thread at a time. Resources keep their atomic refcounts, and the
// handle tables stay internally synchronized, but tracker state is not.
//
// Corresponds to [WebGPU `GPUDevice`](https://gpuweb.github.io/gpuweb/#gpu-device).
Device :: distinct rawptr

// Describes a `Device`.
//
// For use with `adapter_create_device`.
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
    // Describes the default `Queue` and its debug label.
    default_queue:                         Queue_Descriptor,
    // Information used to register a device-lost callback.
    //
    // The callback runs when the device is lost or destroyed. It may be nil.
    lost_callback_info:                    Device_Lost_Callback_Info,
    // Information used to register an uncaptured-error callback.
    //
    // The callback runs for errors not captured by an active error scope. It
    // may be nil.
    uncaptured_error_callback_info:        Uncaptured_Error_Callback_Info,
    // Whether API tracing for debugging is enabled,
    // and where the trace is written if so.
    //
    // Current backends accept this field but do not implement tracing.
    trace_path:                            string,
    // Hints for memory allocation strategies.
    //
    // Current backends accept this field but may ignore it.
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
    //
    // Only meaningful with `Memory_Hints.Manual`; current backends ignore it.
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
    // usage and performance by specifying the allocation configuration in
    // `Device_Descriptor.suballocated_device_memory_block_size`.
    Manual,
}

// Optional compatibility-mode storage limits.
Compatibility_Mode_Limits :: struct {
    // Maximum storage buffers in the vertex stage.
    max_storage_buffers_in_vertex_stage:    u32,
    // Maximum storage textures in the vertex stage.
    max_storage_textures_in_vertex_stage:   u32,
    // Maximum storage buffers in the fragment stage.
    max_storage_buffers_in_fragment_stage:  u32,
    // Maximum storage textures in the fragment stage.
    max_storage_textures_in_fragment_stage: u32,
}

DEFAULT_COMPATIBILITY_MODE_LIMITS :: Compatibility_Mode_Limits {
    max_storage_buffers_in_vertex_stage    = LIMIT_U32_UNDEFINED,
    max_storage_textures_in_vertex_stage   = LIMIT_U32_UNDEFINED,
    max_storage_buffers_in_fragment_stage  = LIMIT_U32_UNDEFINED,
    max_storage_textures_in_fragment_stage = LIMIT_U32_UNDEFINED,
}

// Polls the device for completed work.
//
// With `wait = true`, blocks until all in-flight work completes, or until the
// submission identified by `submission_index` completes when that pointer is
// non-nil and non-zero. With `wait = false`, checks completion without
// blocking.
//
// `submission_index` may be nil, in which case every submission is covered.
// Returns true when no submitted work remains in flight.
device_poll: proc(
    device: Device,
    wait: bool,
    submission_index: ^Submission_Index,
    loc := #caller_location,
) -> bool

// Returns the underlying Metal device on the Metal backend, otherwise nil.
device_get_native_metal_device: proc(device: Device, loc := #caller_location) -> rawptr

// Returns the adapter that created the device.
//
// The returned handle is borrowed from the device; do not release it.
device_get_adapter: proc(device: Device, loc := #caller_location) -> Adapter

// Returns the instance that created the device.
//
// The returned handle is borrowed from the device; do not release it.
device_get_instance: proc(device: Device, loc := #caller_location) -> Instance

// Starts a capture in the attached graphics debugger.
//
// Returns `false` when no capture API is available or the backend does not
// support captures. The Vulkan and browser backends currently return `false`.
device_start_graphics_debugger_capture: proc(device: Device, loc := #caller_location) -> bool

// Stops the current graphics-debugger capture.
//
// A no-op when no capture API is available or no capture is active.
device_stop_graphics_debugger_capture: proc(device: Device, loc := #caller_location)

// Marks the device as destroyed and resolves its lost-device future.
//
// Resources are released when their references drop; the device itself is
// freed by `device_release()`. Calling this more than once is harmless.
device_destroy: proc(device: Device, loc := #caller_location)

// Returns information about the adapter that created the device.
//
// The returned `Adapter_Info` owns its strings; release them with
// `adapter_info_free_members()`. The status is `.Success` when the info is
// valid.
device_get_adapter_info: proc(device: Device, loc := #caller_location) -> (Adapter_Info, Status)

// Returns the features enabled on the device.
//
// This is exactly the `required_features` set from the descriptor.
device_get_features: proc(device: Device, loc := #caller_location) -> Features

// Returns the limits enabled on the device.
//
// This is exactly the `required_limits` set from the descriptor.
device_get_limits: proc(device: Device, loc := #caller_location) -> Limits

// Returns a future that resolves when the device is lost or destroyed.
//
// Only one future exists per device. If the device is already lost, the
// returned future is empty (id `0`) and is treated as already complete.
device_get_lost_future: proc(device: Device, loc := #caller_location) -> Future

// Returns the device's default queue.
//
// The caller owns a queue reference; release it with `queue_release()`.
device_get_queue: proc(device: Device, loc := #caller_location) -> Queue

// Reports whether the device has a feature enabled.
//
// A feature must have been requested in `Device_Descriptor.required_features`;
// adapter support alone is not enough.
device_has_feature: proc(device: Device, feature: Feature_Name, loc := #caller_location) -> bool

// Reports whether this device has all `features` enabled.
//
// A feature must have been requested in `Device_Descriptor.required_features`;
// adapter support alone is not enough.
device_has_features :: proc(
    device: Device,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    for f in features {
        if !device_has_feature(device, f) {
            return false
        }
    }
    return true
}

// Pops the innermost error scope and returns a future for its result.
//
// The callback receives `.Error` when the scope stack is empty. On backends
// that report errors synchronously the callback runs before this returns and
// the future is empty.
device_pop_error_scope: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future

// Pushes an error scope onto the device's error-scope stack.
//
// Errors reported while the scope is active are captured by the innermost
// matching scope. Scopes must be popped in reverse order.
device_push_error_scope: proc(device: Device, filter: Error_Filter, loc := #caller_location)

// Returns the backend that created the device.
device_backend: proc(device: Device, loc := #caller_location) -> Backend_Type

// Reports whether the device uses an embedded (in-process) backend.
device_is_embedded: proc(device: Device, loc := #caller_location) -> bool

// Sets the callback invoked when the device is lost or destroyed.
//
// Replaces the callback supplied in `Device_Descriptor`.
device_set_lost_callback: proc(
    device: Device,
    callback_info: Device_Lost_Callback_Info,
    loc := #caller_location,
)

// Sets the callback invoked for errors not captured by an error scope.
//
// Replaces the callback supplied in `Device_Descriptor`.
device_set_uncaptured_error_callback: proc(
    device: Device,
    callback_info: Uncaptured_Error_Callback_Info,
    loc := #caller_location,
)

// Returns the `Device`'s debug label.
//
// The string is owned by the `Device` and stays valid until the next
// `device_set_label()` or until the `Device` is released.
device_get_label: proc(device: Device, loc := #caller_location) -> string

// Sets the `Device`'s debug label.
//
// The `Device` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
device_set_label: proc(device: Device, label: string, loc := #caller_location)

// Increments the device's reference count.
device_add_ref: proc(device: Device, loc := #caller_location)

// Decrements the device's reference count, destroying it when it reaches zero.
device_release: proc(device: Device, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Device_Impl :: struct {
    instance:                  Instance,
    adapter:                   Adapter,
    limits:                    Limits,
    features:                  Features,
    dl_features:               Downlevel_Features,
    trackers:                  Device_Tracker,
    tracker_indices:           Tracker_Index_Allocators,
    alignments:                Alignments,
    backend:                   Backend_Type,
    is_embedded:               bool,
    allocator:                 runtime.Allocator,
    ref:                       Ref_Count_Type,
    uncaptured_error_callback: Uncaptured_Error_Callback_Info,
}

// Returns the concrete implementation behind a `Device` handle.
_device_get_internal_impl: proc "contextless" (
    device: Device,
    loc := #caller_location,
) -> ^_Device_Impl

// Backend hook used by the shared validation/reporting path. Returns true when
// an active error scope accepted the error; false lets `gpu_report_error` fall
// through to the uncaptured-error callback or the log.
_device_capture_error_scope: proc(
    device: Device,
    error_type: Error_Type,
    message: string,
    loc := #caller_location,
) -> bool
