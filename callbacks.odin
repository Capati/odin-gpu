package gpu

Future :: struct {
    id: u64,
}

Callback_Mode :: enum i32 {
    Wait_Any_Only,
    Allow_Process_Events,
    Allow_Spontaneos,
}

// "Feature level" for the adapter request.
Feature_Level :: enum {
    Core,
    Compatibility,
}

Request_Device_Status :: enum {
    Success,
    Instance_Dropped,
    Error,
    Unknown,
}

Request_Device_Callback :: #type proc "c" (
    status: Request_Device_Status,
    adapter: Device,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Request_Device_Callback_Info :: struct {
    callback:  Request_Device_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

Device_Lost_Reason :: enum {
    Undefined,
    Unknown,
    Destroyed,
    Instance_Dropped,
    Failed_Creation,
}

Error_Type :: enum {
    NoError,
    Validation,
    Out_Of_Memory,
    Internal,
    Unknown,
}

Device_Lost_Callback :: #type proc "c" (
    device: ^Device,
    reason: Device_Lost_Reason,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Device_Lost_Callback_Info :: struct {
    callback:  Device_Lost_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}

Uncaptured_Error_Callback :: #type proc "c" (
    device: ^Device,
    type: Error_Type,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
)

Uncaptured_Error_Callback_Info :: struct {
    callback:  Uncaptured_Error_Callback,
    userdata1: rawptr,
    userdata2: rawptr,
}
