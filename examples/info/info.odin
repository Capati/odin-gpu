package info

// Core
import "base:runtime"
import "core:fmt"

// Local packages
import gpu "../../"

main :: proc() {
    version := gpu.get_version()

    fmt.printf("Version: %d.%d.%d\n\n", version.major, version.minor, version.patch)

    instance := gpu.create_instance()
    defer gpu.release(instance)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    adapters := gpu.instance_enumerate_adapters(instance, ta)
    if len(adapters) == 0 {
        fmt.eprintln("No adapters available")
        return
    }
    defer {
        for a in adapters { gpu.release(a) }
    }

    fmt.println("Available adapter(s):\n")

    for a in adapters {
        info := gpu.adapter_get_info(a, ta)
        gpu.adapter_info_print(info)
    }

    gpu.instance_request_adapter(instance, { callback = on_adapter })

    on_adapter :: proc "c" (
        status: gpu.Request_Adapter_Status,
        adapter: gpu.Adapter,
        message: string,
        userdata1: rawptr,
        userdata2: rawptr,
    ) {
        context = runtime.default_context()

        if status != .Success || adapter == nil {
            fmt.eprintfln("Request adapter failure: [%v] %s", status, message)
        }

        defer gpu.release(adapter)

        runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

        fmt.println("\nSelected adapter:\n")
        info := gpu.adapter_get_info(adapter, context.temp_allocator)
        gpu.adapter_info_print(info)
    }
}
