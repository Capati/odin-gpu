package gpu

// Core
import "base:runtime"

// Opaque handle representing a pending asynchronous operation.
//
// Returned by procedures such as `buffer_map_async`,
// `queue_on_submitted_work_done`, etc.
// Can be waited on with `instance_wait_any()`.
Future :: struct {
    // Implementation-defined identifier for the asynchronous operation.
    // A value of `0` typically indicates an invalid / empty future.
    id: u64,
}

Future_Wait_Info :: struct {
    future:    Future,
    completed: bool,
}

Future_Data_For_Map_Buffer_Async :: struct #all_or_none {
    buffer:        Buffer,
    mode:          Map_Mode,
    offset:        uint,
    size:          uint,
    callback_info: Buffer_Map_Callback_Info,
    loc:           runtime.Source_Code_Location,
    // Set by the map wait so it can mark the pending future ready once the
    // queue work using the buffer has finished.
    future_id:     u64,
}

// Resolves when the device is lost. The callback is the one registered in the
// device descriptor, if any.
Future_Data_For_Lost_Device :: struct #all_or_none {
    device:        Device,
    reason:        Device_Lost_Reason,
    message:       string,
    callback_info: Device_Lost_Callback_Info,
}

// Resolves when all work submitted before the registration completes.
Future_Data_For_Work_Done :: struct #all_or_none {
    device:        Device,
    value:         u64,
    callback_info: Queue_Work_Done_Callback_Info,
}

Future_Data :: union #no_nil {
    Future_Data_For_Map_Buffer_Async,
    Future_Data_For_Lost_Device,
    Future_Data_For_Work_Done,
}

Future_Impl :: struct #all_or_none {
    resolve:  proc(userdata: Future_Data),
    // Called by `instance_wait_any` while this future is pending. Returns true
    // when the future became ready, false when the timeout elapsed.
    wait:     proc(userdata: Future_Data, timeout_ns: u64) -> bool,
    userdata: Future_Data,
    // `poll` futures are resolved by their producer. `instance_wait_any` calls
    // `wait` to advance them and only resolves them once `ready` is set.
    poll:     bool,
    ready:    bool,
}
