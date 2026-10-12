package gpu

// Core
import intr "base:intrinsics"

// Handle to a GPU-accessible buffer.
//
// A `Buffer` is a memory allocation for use by the GPU. The contents of buffers
// are untyped bytes; it is up to the application to specify the interpretation
// of the bytes when the buffer is used, in ways such as `Vertex_Buffer_Layout`.
// A single buffer can be used to hold multiple independent pieces of data at
// different offsets (e.g. both vertices and indices for one or more meshes).
//
// A `Buffer`'s bytes have "interior mutability": functions like
// `queue_write_buffer` or mapping a buffer for writing.
//
// Created with `device_create_buffer()` or `device_create_buffer_witth_data()`.
//
// Corresponds to [WebGPU
// `GPUBuffer`](https://gpuweb.github.io/gpuweb/#buffer-interface).
Buffer :: distinct Handle

@private
Buffer_Impl :: struct {
    device:        Device,
    size:          u64,
    tracker_index: Tracker_Index,
    map_state:     Buffer_Map_State_Impl,
    usage:         Buffer_Uses,
    mapped_ptr:    rawptr,
    is_coherent:   bool,
    ref:           Ref_Count_Type,
}

@private
buffer_get_public_impl: proc "contextless" (
    buffer: Buffer,
    loc := #caller_location,
) -> ^Buffer_Impl

@private
buffer_tracker_index :: proc "contextless" (
    buffer: Buffer,
    loc := #caller_location,
) -> Tracker_Index {
    impl := buffer_get_public_impl(buffer, loc)
    return impl.tracker_index
}

// Describes a `Buffer`.
//
// For use with `device_create_buffer`.
//
// Corresponds to [WebGPU `GPUBufferDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubufferdescriptor).
Buffer_Descriptor :: struct {
    // Debug label of a buffer. This will show up in graphics debuggers for easy
    // identification.
    label:              string,
    // Usages of a buffer. If the buffer is used in any way that isn’t specified
    // here, the operation will panic.
    //
    // Specifying only usages the application will actually perform may increase
    // performance. Additionally, on the WebGL backend, there are restrictions
    // on `Index`.
    usage:              Buffer_Usages,
    // Size of a buffer, in bytes.
    size:               u64,
    // Allows a buffer to be mapped immediately after they are made. It does not
    // have to be `Map_Read` or `Map_Write`, all buffers are allowed to be
    // mapped at creation.
    //
    // If this is true, size must be a multiple of `COPY_BUFFER_ALIGNMENT`.
    mapped_at_creation: bool,
}

device_create_buffer: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer

// Describes a `Buffer` with data.
Buffer_Data_Descriptor :: struct {
    // Debug label of a buffer.
    label: string,
    // Usages of a buffer. If the buffer is used in any way that isn't specified
    // here, the operation will panic.
    //
    // Specifying only usages the application will actually perform may increase
    // performance. Additionally, on the WebGL backend, there are restrictions
    // on `Buffer_Usages.Index`.
    usage: Buffer_Usages,
}

// Creates a new `Buffer` with data from a slice.
device_create_buffer_with_data_slice :: proc(
    device: Device,
    descriptor: Buffer_Data_Descriptor,
    data: []$T,
    loc := #caller_location,
) -> (
    buf: Buffer,
) {
    size := u64(size_of(T) * len(data))
    buf = device_create_buffer(device, {
        label              = descriptor.label,
        usage              = descriptor.usage,
        size               = size,
        mapped_at_creation = true,
    })

    mapping := buffer_get_mapped_range_slice(buf, 0, T, len(data))
    copy(mapping, data)

    buffer_unmap(buf)
    return
}

// Creates a new `Buffer` with data from any type that is not sliceable.
device_create_buffer_with_data_typed :: proc(
    device: Device,
    descriptor: Buffer_Data_Descriptor,
    data: $T,
    loc := #caller_location,
) -> (
    buf: Buffer,
) where !intr.type_is_sliceable(T) {
    buf = device_create_buffer(device, &Buffer_Descriptor{
        label              = descriptor.label,
        usage              = descriptor.usage,
        size               = size_of(T),
        mapped_at_creation = true,
    })

    mapping := buffer_get_mapped_range_typed(buf, 0, T)
    mapping^ = data

    buffer_unmap(buf)
    return
}

// Create a `Buffer` with data.
device_create_buffer_with_data :: proc {
    device_create_buffer_with_data_slice,
    device_create_buffer_with_data_typed,
}

// Destroy the associated native resources as soon as possible.
buffer_destroy: proc(buffer: Buffer, loc := #caller_location)

buffer_flush_mapped_ranges: proc(
    buffer: Buffer,
    offset: uint,
    size: uint,
    loc := #caller_location,
)

// Gain read only access to the pointer of a mapped `Buffer`.
buffer_get_const_mapped_range: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr

// Gain read/write access to the pointer of a mapped `Buffer`.
buffer_get_mapped_range: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr

texture_get_descriptor: proc(texture: Texture, loc := #caller_location) -> Texture_Descriptor

buffer_get_map_state: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State

// Returns the length of the buffer allocation in bytes.
//
// This is always equal to the `size` that was specified when creating the buffer.
buffer_get_size: proc(buffer: Buffer, loc := #caller_location) -> u64

// Returns the allowed usages for this `Buffer`.
//
// This is always equal to the `usage` that was specified when creating the buffer.
buffer_get_usage: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages

buffer_is_coherent: proc(buffer: Buffer, loc := #caller_location) -> bool

buffer_map_async: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future

buffer_map_sync: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    loc := #caller_location,
) -> rawptr

buffer_read_mapped_range: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status

// Set the `Buffer` debug label.
buffer_set_label: proc(buffer: Buffer, label: string, loc := #caller_location)

// Unmaps the buffer from host memory.
//
// This terminates the effect of all previous `buffer_map_async()` operations
// and makes the buffer available for use by the GPU again.
buffer_unmap: proc(buffer: Buffer, loc := #caller_location)

buffer_write_mapped_range: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status

// Increase the `Buffer` reference counter.
buffer_add_ref: proc(buffer: Buffer, loc := #caller_location)

// Release the `Buffer` resources, use to decrease the reference counter.
buffer_release: proc(buffer: Buffer, loc := #caller_location)

// Gain read only access to the slice bytes of a mapped `Buffer`.
buffer_get_const_mapped_range_bytes :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
) -> []byte {
    return ([^]byte)(buffer_get_const_mapped_range(buffer, offset, size))[:size]
}

// Gain read only access to the typed data of a mapped `Buffer`.
buffer_get_const_mapped_range_typed :: proc(
    buffer: Buffer,
    offset: uint,
    $T: typeid,
) -> ^T where !intr.type_is_sliceable(T) {

    return (^T)(buffer_get_const_mapped_range(buffer, 0, size_of(T)))
}

// Gain read only access to the slice data of a mapped `Buffer`.
buffer_get_const_mapped_range_slice :: proc(
    buffer: Buffer,
    offset: uint,
    length: uint,
    $T: typeid,
) -> []T {
    return ([^]T)(buffer_get_const_mapped_range(buffer, offset, size_of(T) * length))[:length]
}

// Gain read/write access to the slice bytes of a mapped `Buffer`.
buffer_get_mapped_range_bytes :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
) -> []byte {
    return ([^]byte)(buffer_get_mapped_range(buffer, offset, size))[:size]
}

// Gain read/write access to the typed data of a mapped `Buffer`.
buffer_get_mapped_range_typed :: proc(
    buffer: Buffer,
    offset: uint,
    $T: typeid,
) -> ^T where !intr.type_is_sliceable(T) {

    return (^T)(buffer_get_mapped_range(buffer, offset, size_of(T)))
}

// Gain read/write access to the slice data of a mapped `Buffer`.
buffer_get_mapped_range_slice :: proc(
    buffer: Buffer,
    offset: uint,
    $T: typeid,
    length: uint,
) -> []T {
    return ([^]T)(buffer_get_mapped_range(buffer, offset, size_of(T) * length))[:length]
}
