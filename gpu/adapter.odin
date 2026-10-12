package gpu

// Core
import "core:slice"

// Handle to a physical graphics and/or compute device.
//
// Adapters can be created using `instance_request_adapter`
// or other `Instance` methods.
//
// Adapters can be used to open a connection to the corresponding `Device`
// on the host system by using `adapter_request_device`.
//
// Does not have to be kept alive.
//
// Corresponds to [WebGPU `GPUAdapter`](https://gpuweb.github.io/gpuweb/#gpu-adapter).
Adapter :: distinct rawptr

@private
Adapter_Impl :: struct {
    instance:   Instance,
    features:   Features,
    limits:     Limits,
    alignments: Alignments,
}

@private
adapter_get_public_impl: proc "contextless" (
    adapter: Adapter,
    loc := #caller_location,
) -> ^Adapter_Impl

// Status code delivered to the callback of `adapter_request_device()`.
Request_Device_Status :: enum i32 {
    // A device was successfully created. The callback receives a valid `Device`.
    Success,
    // The callback was cancelled (for example because the last external
    // reference to the instance was dropped).
    Callback_Cancelled,
    // Device creation failed (validation error, unsupported features/limits,
    // out-of-memory, internal error, etc.).
    Error,
}

// Information about an adapter.
Adapter_Info :: struct {
    // Adapter name.
    name:              string,
    // Backend specific vendor ID of the adapter
    //
    // This generally is a 16-bit PCI vendor ID in the least significant bytes
    // of this field. However, more significant bytes may be non-zero if the
    // backend uses a different representation.
    //
    // - For `Vulkan`, the `VkPhysicalDeviceProperties.vendorID`
    //   is used, which is a superset of PCI IDs.
    vendor:            u32,
    // Backend specific device ID of the adapter
    //
    // This generally is a 16-bit PCI device ID in the least significant bytes
    // of this field. However, more significant bytes may be non-zero if the
    // backend uses a different representation.
    //
    // - For `Vulkan`, the `VkPhysicalDeviceProperties.deviceID` is used, which
    //   is a superset of PCI IDs.
    device:            u32,
    // Type of device
    device_type:       Device_Type,
    // Backend specific PCI bus ID of the adapter.
    //
    // - For `Vulkan`, `VkPhysicalDevicePCIBusInfoPropertiesEXT` is used, if
    //   available, in the form `bus.device.function`, e.g. `0000:01:00.0`.
    device_pci_bus_id: string,
    // Driver name
    driver:            string,
    // Driver info.
    driver_info:       string,
    // Backend used for device.
    backend:           Backend_Type,
    // Minimum possible size of a subgroup on this adapter. Will
    // never be lower than `MINIMUM_SUBGROUP_MIN_SIZE`.
    //
    // This will vary from device to device. Typical values are listed below.
    //
    // - NVIDIA: 32
    // - AMD GCN/Vega: 64
    // - AMD RDNA+: 32
    // - Intel: 8 or 16
    // - Qualcomm: 64
    // - WARP: 4
    // - lavapipe: 8
    subgroup_min_size: u32,
    // Maximum possible size of a subgroup on this adapter. Will
    // never be higher than `MAXIMUM_SUBGROUP_MAX_SIZE`.
    //
    // This will vary from device to device. Typical values are listed below:
    //
    // - NVIDIA: 32
    // - AMD GCN/Vega: 64
    // - AMD RDNA+: 64
    // - Intel: 16 or 32
    // - Qualcomm: 128
    // - WARP: 4 or 128
    // - lavapipe: 8
    subgroup_max_size: u32,
}

// The features supported by this adapter that can be used to create devices.
adapter_get_features: proc(adapter: Adapter, loc := #caller_location) -> Features

adapter_get_info: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> Adapter_Info

adapter_info_free_members :: proc(
    adapter_info: Adapter_Info,
    allocator := context.allocator,
    loc := #caller_location,
) {
    context.allocator = allocator
    delete(adapter_info.name)
    delete(adapter_info.device_pci_bus_id)
    delete(adapter_info.driver)
    delete(adapter_info.driver_info)
}

adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
    impl := adapter_get_public_impl(adapter, loc)
    return impl.limits
}

adapter_has_feature :: proc(
    adapter: Adapter,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    if feature == {} {
        return true
    }
    impl := adapter_get_public_impl(adapter, loc)
    _, found := slice.binary_search(impl.features[:], feature)
    return found
}

adapter_create_device: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device

adapter_add_ref: proc(adapter: Adapter, loc := #caller_location)

adapter_release: proc(adapter: Adapter, loc := #caller_location)
