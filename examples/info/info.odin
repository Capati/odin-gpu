/*
Example - Info

Prints the library version and the selected adapter information.
*/
package info

// Core
import "core:fmt"

// Local packages
import "../../gpu"

main :: proc() {
    fmt.printf("Version: %s\n\n", gpu.VERSION_STRING)

    instance := gpu.create_instance(context.allocator)
    if instance == {} {
        fmt.eprintln("Failed to create instance")
        return
    }
    defer gpu.instance_release(instance)

    adapter := gpu.instance_create_adapter(instance)
    if adapter == {} {
        fmt.eprintln("No adapters available")
        return
    }
    defer gpu.adapter_release(adapter)

    info := gpu.adapter_get_info(adapter)
    defer gpu.adapter_info_free_members(info)

    fmt.println("Selected adapter:\n")
    fmt.printf("  Name: %s\n", info.name if info.name != "" else "Unknown device")
    fmt.printf("  Backend: %v\n", info.backend)
    fmt.printf("  Device type: %v\n", info.device_type)
    if info.driver != "" {
        fmt.printf("  Driver: %s\n", info.driver)
        if info.driver_info != "" {
            fmt.printf("  Driver info: %s\n", info.driver_info)
        }
    }
}
