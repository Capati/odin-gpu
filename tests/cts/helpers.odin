package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Counts refusals delivered through the device's uncaptured-error callback.
// Each test runner thread owns one test, so a thread-local counter keeps
// concurrently running tests from seeing each other's refusals.
@(thread_local)
g_cts_errors: int

@(thread_local)
g_cts_last_error: string

cts_error_callback :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    g_cts_errors += 1
    g_cts_last_error = message
}

CTS_Fixture :: struct {
    instance: gpu.Instance,
    adapter:  gpu.Adapter,
    device:   gpu.Device,
}

cts_make_fixture :: proc(descriptor := gpu.Device_Descriptor{}) -> CTS_Fixture {
    instance := gpu.create_instance(context.allocator, {backends = {.Vulkan}})
    assert(instance != nil, "failed to create instance")

    adapter := gpu.instance_create_adapter(instance, {})
    assert(adapter != {}, "failed to create adapter")

    device := cts_make_device(adapter, descriptor)
    assert(device != nil, "failed to create device")

    g_cts_errors = 0
    return {instance = instance, adapter = adapter, device = device}
}

cts_make_device :: proc(
    adapter: gpu.Adapter,
    descriptor := gpu.Device_Descriptor{},
) -> gpu.Device {
    desc := descriptor
    if desc.required_limits == {} {
        desc.required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS
    }
    if desc.uncaptured_error_callback_info.callback == nil {
        desc.uncaptured_error_callback_info = {
            callback = cts_error_callback,
        }
    }
    return gpu.adapter_create_device(adapter, desc)
}

cts_destroy_fixture :: proc(f: CTS_Fixture) {
    gpu.device_release(f.device)
    gpu.adapter_release(f.adapter)
    gpu.instance_release(f.instance)
}

cts_errors :: proc() -> int {
    return g_cts_errors
}

cts_expect_outcome :: proc(t: ^testing.T, errors: int, should_fail: bool, what: string) {
    if should_fail {
        testing.expectf(t, errors > 0,
            "%s: expected a validation error, the port accepted it", what)
    } else {
        testing.expectf(t, errors == 0,
            "%s: unexpected validation error (%d reported: %s)",
            what, errors, g_cts_last_error)
    }
}

cts_require_rows :: proc(t: ^testing.T, actual, minimum: int, what: string) {
    testing.expectf(t, actual >= minimum,
        "%s: the table has %d rows, expected at least %d", what, actual, minimum)
}

cts_require_both :: proc(t: ^testing.T, any_accepted, any_refused: bool, what: string) {
    testing.expectf(t, any_accepted, "%s: the table has no accepted row", what)
    testing.expectf(t, any_refused, "%s: the table has no refused row", what)
}

// Runs `create` while measuring the refusals it reports. Returns the created
// handle (empty when refused) and the number of errors.
cts_measure_buffer_create :: proc(
    t: ^testing.T,
    device: gpu.Device,
    descriptor: gpu.Buffer_Descriptor,
) -> (
    gpu.Buffer,
    int,
) {
    before := cts_errors()
    buffer := gpu.device_create_buffer(device, descriptor)
    testing.expect(t, device != nil, "invalid device")
    return buffer, cts_errors() - before
}

cts_usage_bits :: proc(usage: gpu.Buffer_Usages) -> u64 {
    return transmute(u64)usage
}

cts_bogus_usage :: proc() -> gpu.Buffer_Usages {
    return transmute(gpu.Buffer_Usages)(u64(0x4000_0000))
}

cts_buffer_usage_pair_valid :: proc(usage: gpu.Buffer_Usages) -> bool {
    raw := cts_usage_bits(usage)
    if raw == 0 {
        return false
    }
    if raw & 0x4000_0000 != 0 {
        return false
    }
    read_pair := gpu.Buffer_Usages{.Map_Read, .Copy_Dst}
    write_pair := gpu.Buffer_Usages{.Map_Write, .Copy_Src}
    if .Map_Read in usage && raw &~ cts_usage_bits(read_pair) != 0 {
        return false
    }
    if .Map_Write in usage && raw &~ cts_usage_bits(write_pair) != 0 {
        return false
    }
    return true
}

cts_core_buffer_usages :: proc() -> [10]gpu.Buffer_Usages {
    return {
        {.Map_Read},
        {.Map_Write},
        {.Copy_Src},
        {.Copy_Dst},
        {.Index},
        {.Vertex},
        {.Uniform},
        {.Storage},
        {.Indirect},
        {.Query_Resolve},
    }
}
