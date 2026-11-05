package gpu

// Core
import "base:runtime"

// Handle to a physical graphics and/or compute device.
//
// Adapters can be created using `instance_create_adapter()` or
// `instance_enumerate_adapters()`.
//
// Adapters can be used to open a connection to the corresponding `Device`
// on the host system by using `adapter_create_device()`.
//
// Does not have to be kept alive: a `Device` holds its own reference to the
// adapter it was created from.
//
// Corresponds to [WebGPU `GPUAdapter`](https://gpuweb.github.io/gpuweb/#gpu-adapter).
Adapter :: distinct rawptr

// Supported physical device types.
Device_Type :: enum i32 {
    // Other or Unknown.
    Unknown,
    // Integrated GPU with shared CPU/GPU memory.
    Integrated_Gpu,
    // Discrete GPU with separate CPU/GPU memory.
    Discrete_Gpu,
    // Virtual / Hosted.
    Virtual_Gpu,
    // Cpu / Software Rendering.
    Cpu,
}

// Power preference when choosing a physical adapter.
//
// Corresponds to [WebGPU `GPUPowerPreference`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpupowerpreference).
Power_Preference :: enum i32 {
    // Power usage is not considered when choosing an adapter.
    None,
    // Adapter that uses the least possible power. This is often an integrated GPU.
    Low_Power,
    // Adapter that has the highest performance. This is often a discrete GPU.
    High_Performance,
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

// Get info about the adapter itself.
//
// The strings in the returned `Adapter_Info` are allocated with `allocator`.
// Release them with `adapter_info_free_members()`.
adapter_get_info: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> Adapter_Info

// Frees the strings `adapter_get_info()` allocated in `adapter_info`.
//
// Pass the same `allocator` that was passed to `adapter_get_info()`.
adapter_info_free_members: proc(
    adapter_info: Adapter_Info,
    allocator := context.allocator,
    loc := #caller_location,
)

// The best limits which can be used to create devices on this adapter.
adapter_get_limits: proc(adapter: Adapter, loc := #caller_location) -> Limits

// Reports whether this adapter supports `feature`.
//
// Adapter support does not enable the feature on a device: it must also be
// listed in `Device_Descriptor.required_features` when the device is created.
adapter_has_feature: proc(adapter: Adapter, feature: Feature_Name, loc := #caller_location) -> bool

// Reports whether this adapter supports all `features`.
//
// Adapter support does not enable the feature on a device: it must also be
// listed in `Device_Descriptor.required_features` when the device is created.
adapter_has_features :: proc(
    adapter: Adapter,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    for f in features {
        if !adapter_has_feature(adapter, f) {
            return false
        }
    }
    return true
}

// Requests a connection to a physical device, creating a logical device.
//
// Returns the `Device`. Its default `Queue`, obtained with
// `device_get_queue()`, is the one that executes command buffers.
//
// Per the WebGPU specification, an `Adapter` may only be used once to create a
// device. If another device is wanted, call `instance_create_adapter()` again
// to get a fresh `Adapter`. However, `odin-gpu` does not currently enforce this
// restriction: backends allow repeated calls on the same `Adapter`.
//
// **Failure**
//
// Returns `nil` when:
//
// - `descriptor.required_features` contains a feature the adapter does not
//   advertise through `adapter_get_features()`.
// - `descriptor.required_limits` requests a value better than the one reported
//   by `adapter_get_limits()`.
// - The underlying API fails to create the logical device.
adapter_create_device: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device

// Alias to `adapter_create_device`.
adapter_request_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device {
    return adapter_create_device(adapter, descriptor, loc)
}

// Returns the `Adapter`'s debug label.
//
// The string is owned by the `Adapter` and stays valid until the next
// `adapter_set_label()` or until the `Adapter` is released.
adapter_get_label: proc(adapter: Adapter, loc := #caller_location) -> string

// Sets the `Adapter`'s debug label.
//
// The `Adapter` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
adapter_set_label: proc(adapter: Adapter, label: string, loc := #caller_location)

// Increments the reference count of `adapter`.
adapter_add_ref: proc(adapter: Adapter, loc := #caller_location)

// Releases `adapter`, destroying it when its reference count reaches zero.
adapter_release: proc(adapter: Adapter, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Adapter_Impl :: struct {
    instance:    Instance,
    features:    Features,
    dl_features: Downlevel_Features,
    limits:      Limits,
    alignments:  Alignments,
    ref:         Ref_Count_Type,
    allocator:   runtime.Allocator,
    label:       string,
}

// Returns the concrete implementation behind a `Adapter` handle.
_adapter_get_internal_impl: proc "contextless" (
    adapter: Adapter,
    loc := #caller_location,
) -> ^_Adapter_Impl

_adapter_texture_format_capabilities: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities
