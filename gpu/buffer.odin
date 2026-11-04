package gpu

// Core
import intr "base:intrinsics"

// Handle to a GPU-accessible buffer.
//
// A `Buffer` is a GPU memory allocation of untyped bytes. A single buffer can
// hold multiple independent pieces of data at different offsets (for example
// vertices and indices for one or more meshes).
//
// Created with `device_create_buffer()` or `device_create_buffer_with_data()`.
// Every buffer starts fully zeroed.
//
// Data can be supplied by:
//
// - creating the buffer with `mapped_at_creation`, then writing through
//   `buffer_get_mapped_range()` and calling `buffer_unmap()`;
// - mapping it later with `buffer_map_async()` (the buffer needs `Map_Read` or
//   `Map_Write`) and accessing the mapped range;
// - copying from another buffer or a texture with a `Command_Encoder`;
// - `queue_write_buffer()` / `queue_write_texture()`.
//
// # Mapping
//
// At any time either the CPU or the GPU has access to a buffer's contents,
// never both. While a buffer is mapped it may not be used by submitted GPU
// work. Mapping a buffer at creation is the simplest way to initialize data
// that never changes. `buffer_map_async()` maps a range later and completes
// through the returned `Future`; `buffer_unmap()` makes the buffer available to
// the GPU again and terminates any pending mapping.
//
// A mapped range must be within the mapped region, start at a multiple of
// `MAP_ALIGNMENT`, and have a length that is a multiple of 4. Only access
// mapped memory while the buffer is mapped.
//
// On the browser backend, mapping and unmapping involve copies between
// WebAssembly memory and the browser's GPU buffers.
//
// Corresponds to [WebGPU
// `GPUBuffer`](https://gpuweb.github.io/gpuweb/#buffer-interface).
Buffer :: distinct Handle

// Different ways that you can use a buffer.
Buffer_Usage :: enum i32 {
    // Allow a buffer to be mapped for reading using `buffer_map_async` +
    // `buffer_get_mapped_range`. This does not include creating a buffer with
    // `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Mappable_Primary_Buffers` feature isn't enabled, the only other usage
    // a buffer may have is `Copy_Dst`.
    Map_Read,
    // Allow a buffer to be mapped for writing using `buffer_map_async` +
    // `buffer_get_mapped_range`. This does not include creating a buffer with
    // `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Mappable_Primary_Buffers` feature isn't enabled, the only other usage
    // a buffer may have is `Copy_Src`.
    Map_Write,
    // Allow a buffer to be the source buffer for a
    // `command_encoder_copy_buffer_to_buffer` or
    // `command_encoder_copy_buffer_to_texture` operation.
    Copy_Src,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_copy_buffer_to_buffer`,
    // `command_encoder_copy_texture_to_buffer`, `command_encoder_clear_buffer`
    // or `queue_write_buffer` operation.
    Copy_Dst,
    // Allow a buffer to be the index buffer in a draw operation.
    Index,
    // Allow a buffer to be the vertex buffer in a draw operation.
    Vertex,
    // Allow a buffer to be a `Buffer_Binding_Type.Uniform` inside a bind group.
    Uniform,
    // Allow a buffer to be a `Buffer_Binding_Type.Storage` inside a bind group.
    Storage,
    // Allow a buffer to be the indirect buffer in an indirect draw call.
    Indirect,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_resolve_query_set` operation.
    Query_Resolve,
    // Allows a buffer to be used as input for a bottom level acceleration
    // structure build.
    Blas_Input,
    // Allows a buffer to be used as input for a top level acceleration
    // structure build.
    Tlas_Input,
}

// Different ways that you can use a buffer.
//
// The usages determine what kind of memory the buffer is allocated from and
// what actions the buffer can partake in.
//
// Specifying only usages the application will actually perform may increase
// performance. Additionally, some backends restrict `Index` buffers that also
// have other usages; see `Unrestricted_Index_Buffer`.
//
// Corresponds to [WebGPU `GPUBufferUsageFlags`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpubufferusageflags).
Buffer_Usages :: bit_set[Buffer_Usage;Flags]

// Whether any usages in `other` are also set in `self`.
buffer_usage_intersects :: #force_inline proc "contextless" (self, mask: Buffer_Usages) -> bool {
    return (self & mask) != {}
}

// Whether all usages in `other` are also set in `self`.
buffer_usage_contains :: #force_inline proc "contextless" (self, other: Buffer_Usages) -> bool {
    return (self & other) == other
}

// Specific state of a buffer.
Buffer_Map_State :: enum i32 {
    // The buffer is not mapped.
    Unmapped,
    // A mapping of the buffer has been requested, but is pending. It may
    // succeed, or fail validation in `buffer_map_async`.
    Pending,
    // The buffer is mapped.
    Mapped,
}

// Type of buffer mapping.
Map_Mode :: enum i32 {
    // Map only for reading.
    Read,
    // Map only for writing.
    Write,
}

// Types of buffer mapping.
Map_Modes :: bit_set[Map_Mode;Flags]

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
    // performance. Additionally, some backends restrict `Index` buffers that
    // also have other usages; see `Unrestricted_Index_Buffer`.
    usage:              Buffer_Usages,
    // Size of a buffer, in bytes.
    size:               u64,
    // Allows a buffer to be mapped immediately after creation. It does not have
    // to be `Map_Read` or `Map_Write`; all buffers are allowed to be mapped at
    // creation.
    //
    // If this is true, `size` must be a multiple of `COPY_BUFFER_ALIGNMENT`.
    mapped_at_creation: bool,
}

// Creates a new `Buffer`.
//
// Returns an invalid handle (`{}`) and reports through the device's error
// scopes when `usage` is empty or unknown, when `Map_Read` and `Map_Write` are
// combined, when a mapping-related usage is combined with other usages without
// the `Mappable_Primary_Buffers` feature, when the size exceeds the device
// limit, or when a requested usage requires a feature the device lacks.
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
    // performance. Additionally, some backends restrict `Index` buffers that
    // also have other usages; see `Unrestricted_Index_Buffer`.
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
    if buf == {} {
        return
    }
    if len(data) == 0 {
        buffer_unmap(buf)
        return
    }

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
    buf = device_create_buffer(device, Buffer_Descriptor {
        label              = descriptor.label,
        usage              = descriptor.usage,
        size               = size_of(T),
        mapped_at_creation = true,
    })
    if buf == {} {
        return
    }
    if size_of(T) == 0 {
        buffer_unmap(buf)
        return
    }

    mapping := buffer_get_mapped_range_typed(buf, 0, T)
    mapping^ = data

    buffer_unmap(buf)
    return
}

// Create a `Buffer` with data.
//
// The buffer is created mapped, filled from `data`, and then unmapped.
device_create_buffer_with_data :: proc {
    device_create_buffer_with_data_slice,
    device_create_buffer_with_data_typed,
}

// Destroy the associated native resources as soon as possible.
buffer_destroy: proc(buffer: Buffer, loc := #caller_location)

// Flushes host writes in the given range to the GPU.
//
// Only meaningful for mapped buffers backed by non-coherent memory.
buffer_flush_mapped_ranges: proc(buffer: Buffer, offset: uint, size: uint, loc := #caller_location)

// Gain read only access to the pointer of a mapped `Buffer`.
//
// `offset` must be a multiple of `MAP_ALIGNMENT`, `size` must be a multiple of
// 4, and `size == 0` means "until the end of the mapped range". The range must
// lie within the currently mapped region. Returns `nil` when the buffer is not
// mapped or the range is invalid.
buffer_get_const_mapped_range: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = 0,
    loc := #caller_location,
) -> rawptr

// Gain read/write access to the pointer of a mapped `Buffer`.
//
// `offset` must be a multiple of `MAP_ALIGNMENT`, `size` must be a multiple of
// 4, and `size == 0` means "until the end of the mapped range". The range must
// lie within the currently mapped region. Returns `nil` when the buffer is not
// mapped or the range is invalid.
buffer_get_mapped_range: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = 0,
    loc := #caller_location,
) -> rawptr

// Returns the current mapping state of the buffer.
//
// A buffer created with `mapped_at_creation` is `Mapped` until it is unmapped.
// A buffer with a pending `buffer_map_async()` is `Pending`.
buffer_get_map_state: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State

// Returns the size of the buffer in bytes, as requested when creating it.
buffer_get_size: proc(buffer: Buffer, loc := #caller_location) -> u64

// Returns the allowed usages for this `Buffer`.
//
// This is always equal to the `usage` that was specified when creating the buffer.
buffer_get_usage: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages

// Asynchronously maps a range of the buffer for host access.
//
// `mode` must be permitted by the buffer's usages (`Map_Read` for `.Read`,
// `Map_Write` for `.Write`). `offset` must be a multiple of `MAP_ALIGNMENT`,
// `size` must be a multiple of 4, and `size == 0` means "until the end of the
// buffer". The range must lie within the buffer, and the buffer must not
// already be mapped or have a pending mapping.
//
// The mapping completes when the returned `Future` is resolved by a queue
// submission or `instance_wait_any()`, at which point `callback_info` is
// invoked. No callback is invoked if the request fails validation.
buffer_map_async: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future

// Maps a range of the buffer synchronously and returns a pointer to it.
//
// This is a convenience wrapper over `buffer_map_async()` that waits for the
// mapping to complete. `size == 0` means "until the end of the buffer".
buffer_map_sync: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    loc := #caller_location,
) -> rawptr

// Copies data out of a mapped buffer range into `data`.
buffer_read_mapped_range: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status

// Unmaps the buffer from host memory.
//
// This terminates the effect of all previous `buffer_map_async()` operations
// and makes the buffer available for use by the GPU again.
buffer_unmap: proc(buffer: Buffer, loc := #caller_location)

// Copies `data` into a mapped buffer range.
buffer_write_mapped_range: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status

// Gain read only access to the slice bytes of a mapped `Buffer`.
buffer_get_const_mapped_range_bytes :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = 0,
) -> []byte {
    resolved := resolve_mapped_range_size(buffer_get_size(buffer), size, offset)
    return ([^]byte)(buffer_get_const_mapped_range(buffer, offset, uint(resolved)))[:int(resolved)]
}

// Gain read only access to the typed data of a mapped `Buffer`.
buffer_get_const_mapped_range_typed :: proc(
    buffer: Buffer,
    offset: uint,
    $T: typeid,
) -> ^T where !intr.type_is_sliceable(T) {

    return (^T)(buffer_get_const_mapped_range(buffer, offset, size_of(T)))
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
buffer_get_mapped_range_bytes :: proc(buffer: Buffer, offset: uint = 0, size: uint = 0) -> []byte {
    resolved := resolve_mapped_range_size(buffer_get_size(buffer), size, offset)
    return ([^]byte)(buffer_get_mapped_range(buffer, offset, uint(resolved)))[:int(resolved)]
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

// Returns the `Buffer`'s debug label.
//
// The string is owned by the `Buffer` and stays valid until the next
// `buffer_set_label()` or until the `Buffer` is released.
buffer_get_label: proc(buffer: Buffer, loc := #caller_location) -> string

// Sets the `Buffer`'s debug label.
//
// The `Buffer` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
buffer_set_label: proc(buffer: Buffer, label: string, loc := #caller_location)

// Increase the `Buffer` reference counter.
buffer_add_ref: proc(buffer: Buffer, loc := #caller_location)

// Release the `Buffer` resources, use to decrease the reference counter.
buffer_release: proc(buffer: Buffer, loc := #caller_location)
