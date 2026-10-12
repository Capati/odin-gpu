package gpu

// Generic function pointer type (no arguments, no return value).
Proc :: #type proc "contextless" ()

// Callback invoked when an asynchronous buffer map operation completes.
Buffer_Map_Callback :: #type proc "contextless" (
    status: Map_Async_Status,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when shader module compilation info is available.
Compilation_Info_Callback :: #type proc "contextless" (
    status: Compilation_Info_Request_Status,
    compilationInfo: ^Compilation_Info,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when asynchronous compute pipeline creation finishes.
Create_Compute_Pipeline_Async_Callback :: #type proc "contextless" (
    status: Create_Pipeline_Async_Status,
    pipeline: Compute_Pipeline,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when asynchronous render pipeline creation finishes.
Create_Render_Pipeline_Async_Callback :: #type proc "contextless" (
    status: Create_Pipeline_Async_Status,
    pipeline: Render_Pipeline,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when a device is lost.
Device_Lost_Callback :: #type proc "contextless" (
    device: ^Device,
    reason: Device_Lost_Reason,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when an error scope is popped.
Pop_Error_Scope_Callback :: #type proc "contextless" (
    status: Pop_Error_Scope_Status,
    type: Error_Type,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when all previously submitted queue work has completed.
Queue_Work_Done_Callback :: #type proc "contextless" (
    status: Queue_Work_Done_Status,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when an adapter request completes.
Request_Adapter_Callback :: #type proc "contextless" (
    status: Request_Adapter_Status,
    adapter: Adapter,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked when a device request completes.
Request_Device_Callback :: #type proc "contextless" (
    status: Request_Device_Status,
    device: Device,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

// Callback invoked for uncaptured errors on a device.
Uncaptured_Error_Callback :: #type proc "contextless" (
    device: ^Device,
    type: Error_Type,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Log_Level :: enum i32 {
    Off,
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

// Callback invoked when a log message is called.
Log_Callback :: #type proc "contextless" (level: Log_Level, message: string, userdata: rawptr)

// Information used to register a buffer-map callback. Passed to
// `buffer_map_async()`.
Buffer_Map_Callback_Info :: struct {
    // When the callback is allowed to be fired.
    mode:      Callback_Mode,
    // Procedure to invoke on completion.
    callback:  Buffer_Map_Callback,
    // User data passed to the callback.
    userdata1: rawptr,
    // User data passed to the callback.
    userdata2: rawptr,
}

// Information used to register a compilation-info callback.
// Passed to `shader_module_get_compilation_info`.
Compilation_Info_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Compilation_Info_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register an async compute-pipeline creation callback.
// Passed to `device_create_compute_pipeline_async`.
Create_Compute_Pipeline_Async_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Create_Compute_Pipeline_Async_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register an async render-pipeline creation callback.
// Passed to `device_create_render_pipeline_async`.
Create_Render_Pipeline_Async_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Create_Render_Pipeline_Async_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register a device-lost callback. Supplied in
// `Device_Descriptor.device_lost_callback_info`.
Device_Lost_Callback_Info :: struct {
    callback:  Device_Lost_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register an error-scope pop callback.
// Passed to `device_pop_error_scope`.
Pop_Error_Scope_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Pop_Error_Scope_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register a queue work-done callback.
// Passed to `queue_on_submitted_work_done`.
Queue_Work_Done_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Queue_Work_Done_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register an adapter-request callback.
// Passed to `instance_request_adapter`.
Request_Adapter_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Request_Adapter_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register a device-request callback.
// Passed to `adapter_request_device`.
Request_Device_Callback_Info :: struct {
    mode:      Callback_Mode,
    callback:  Request_Device_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

// Information used to register an uncaptured-error callback. Supplied in
// `Device_Descriptor.uncaptured_error_callback_info`.
Uncaptured_Error_Callback_Info :: struct {
    callback:  Uncaptured_Error_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}
