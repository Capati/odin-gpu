package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from upstream `api/validation/error_scope.spec.ts`:
// matching and
// non-matching filters, parent/current scope resolution, and balanced sibling
// and nested stacks. Errors are generated through a validation refusal, so the
// captured type is always `.Validation`.

CTS_Error_State :: struct {
    uncaptured: int,
    last_type:  gpu.Error_Type,
}

CTS_Pop_Result :: struct {
    status:  gpu.Pop_Error_Scope_Status,
    type:    gpu.Error_Type,
    message: string,
}

cts_error_uncaptured_callback :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    state := cast(^CTS_Error_State)userdata1
    state.uncaptured += 1
    state.last_type = type
}

cts_error_pop_callback :: proc "contextless" (
    status: gpu.Pop_Error_Scope_Status,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    result := cast(^CTS_Pop_Result)userdata1
    result.status = status
    result.type = type
    result.message = message
}

cts_error_device :: proc(f: CTS_Fixture, state: ^CTS_Error_State) -> gpu.Device {
    descriptor := gpu.Device_Descriptor{}
    descriptor.uncaptured_error_callback_info = {
        callback  = cts_error_uncaptured_callback,
        userdata1 = state,
    }
    return cts_make_device(f.adapter, descriptor)
}

cts_pop_error_scope :: proc(device: gpu.Device) -> CTS_Pop_Result {
    result: CTS_Pop_Result
    info := gpu.Pop_Error_Scope_Callback_Info {
        callback  = cts_error_pop_callback,
        userdata1 = &result,
    }
    _ = gpu.device_pop_error_scope(device, info)
    return result
}

cts_generate_error :: proc(device: gpu.Device) {
    pipeline := gpu.device_create_compute_pipeline(device, {module = {}, entry_point = "main"})
    if pipeline != {} {
        gpu.compute_pipeline_release(pipeline)
    }
}

@(test)
cts_error_scope_simple :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    gpu.device_push_error_scope(device, .Validation)
    cts_generate_error(device)
    result := cts_pop_error_scope(device)
    testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Success)
    testing.expect_value(t, result.type, gpu.Error_Type.Validation)
    testing.expect(t, result.message != "", "captured error should carry its message")
    testing.expect_value(t, state.uncaptured, 0)

    gpu.device_push_error_scope(device, .Out_Of_Memory)
    cts_generate_error(device)
    result = cts_pop_error_scope(device)
    testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Success)
    testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
    testing.expect_value(t, state.uncaptured, 1)
    testing.expect_value(t, state.last_type, gpu.Error_Type.Validation)
}

@(test)
cts_error_scope_empty :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    result := cts_pop_error_scope(device)
    testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Error)
    testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
}

@(test)
cts_error_scope_parent :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    depths := [3]int{1, 10, 100}
    unmatched := [2]gpu.Error_Filter{.Out_Of_Memory, .Internal}
    for depth in depths {
        gpu.device_push_error_scope(device, .Validation)
        for index in 0 ..< depth {
            gpu.device_push_error_scope(device, unmatched[index % len(unmatched)])
        }
        cts_generate_error(device)
        for _ in 0 ..< depth {
            result := cts_pop_error_scope(device)
            testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
        }
        result := cts_pop_error_scope(device)
        testing.expect_value(t, result.type, gpu.Error_Type.Validation)
    }
    testing.expect_value(t, state.uncaptured, 0)
}

@(test)
cts_error_scope_current :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    filters := [3]gpu.Error_Filter{.Validation, .Out_Of_Memory, .Internal}
    depths := [4]int{1, 10, 100, 1000}
    for depth in depths {
        for index in 0 ..< depth {
            gpu.device_push_error_scope(device, filters[index % len(filters)])
        }
        gpu.device_push_error_scope(device, .Validation)
        cts_generate_error(device)
        result := cts_pop_error_scope(device)
        testing.expect_value(t, result.type, gpu.Error_Type.Validation)
        for _ in 0 ..< depth {
            result = cts_pop_error_scope(device)
            testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
        }
    }
    testing.expect_value(t, state.uncaptured, 0)
}

@(test)
cts_error_scope_balanced_siblings :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    for count in ([4]int{1, 10, 100, 1000}) {
        for _ in 0 ..< count {
            gpu.device_push_error_scope(device, .Validation)
            result := cts_pop_error_scope(device)
            testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Success)
            testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
        }
        result := cts_pop_error_scope(device)
        testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Error)
    }
}

@(test)
cts_error_scope_balanced_nesting :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    state: CTS_Error_State
    device := cts_error_device(f, &state)
    defer gpu.device_release(device)

    for count in ([4]int{1, 10, 100, 1000}) {
        for _ in 0 ..< count {
            gpu.device_push_error_scope(device, .Validation)
        }
        for _ in 0 ..< count {
            result := cts_pop_error_scope(device)
            testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Success)
            testing.expect_value(t, result.type, gpu.Error_Type.No_Error)
        }
        result := cts_pop_error_scope(device)
        testing.expect_value(t, result.status, gpu.Pop_Error_Scope_Status.Error)
    }
}
