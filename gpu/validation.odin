package gpu

// Core
import "core:log"

// Reports an error the way the rest of this port does: through the device's
// error-scope stack first, then its uncaptured-error callback, else the log.
// The caller returns an invalid handle after reporting.
gpu_report_error :: proc(
    device: Device,
    error_type: Error_Type,
    message: string,
    loc := #caller_location,
) {
    if device != nil {
        impl := _device_get_internal_impl(device, loc)
        if _device_capture_error_scope != nil &&
           _device_capture_error_scope(device, error_type, message, loc) {
            return
        }
        if impl.uncaptured_error_callback.callback != nil {
            device_ptr := device
            impl.uncaptured_error_callback.callback(
                &device_ptr,
                error_type,
                message,
                impl.uncaptured_error_callback.userdata1,
                impl.uncaptured_error_callback.userdata2,
            )
            return
        }
    }
    log.errorf("%s", message, location = loc)
}

gpu_report_validation_error :: proc(
    device: Device,
    message: string,
    loc := #caller_location,
) {
    gpu_report_error(device, .Validation, message, loc)
}

// `gpu_validate` reports `message` when `condition` is false and returns the
// condition, so creation entry points can accumulate failures and hand back an
// invalid handle instead of aborting.
gpu_validate :: proc(
    device: Device,
    condition: bool,
    message: string,
    loc := #caller_location,
) -> bool {
    if !condition {
        gpu_report_validation_error(device, message, loc)
    }
    return condition
}
