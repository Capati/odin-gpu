package gpu

// Core
import "base:runtime"

// Opaque handle representing a pending asynchronous operation.
//
// Returned by procedures such as `instance_request_adapter`,
// `buffer_map_async`, `queue_on_submitted_work_done`, etc.
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

Future_Data_For_Create_Adapter :: struct #all_or_none {
    instance: Instance,
    info:     Request_Adapter_Callback_Info,
    options:  Request_Adapter_Options,
    loc:      runtime.Source_Code_Location,
}

Future_Data_For_Create_Device :: struct #all_or_none {
    adapter:          Adapter,
    deviceDescriptor: Device_Descriptor,
    callback_info:    Request_Device_Callback_Info,
    loc:              runtime.Source_Code_Location,
}

Future_Data_For_Map_Buffer_Async :: struct #all_or_none {
    buffer:        Buffer,
    mode:          Map_Mode,
    offset:        uint,
    size:          uint,
    callback_info: Buffer_Map_Callback_Info,
    loc:           runtime.Source_Code_Location,
}

Future_Data :: union #no_nil {
    Future_Data_For_Create_Adapter,
    Future_Data_For_Create_Device,
    Future_Data_For_Map_Buffer_Async,
}

Future_Impl :: struct #all_or_none {
    resolve:  proc(userdata: Future_Data),
    userdata: Future_Data,
}
