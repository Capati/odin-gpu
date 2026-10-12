// #+build !js
package gpu

// Core
import "core:mem"

// A temporary buffer, consumed by the command that uses it.
//
// A `Staging_Buffer` is designed for one-shot uploads of data to the GPU. It
// is always created mapped, and the command that uses it destroys the buffer
// when it is done.
//
// `Staging_Buffer`s can be created with `queue_create_staging_buffer` and
// used with `queue_write_staging_buffer`. They are also used internally by
// operations like `queue_write_texture` that need to upload data to the GPU,
// but that don't belong to any particular command buffer.
Staging_Buffer :: struct {
    buffer: Buffer,
    device: Device,
    size:   u64,
    ptr:    rawptr,
}

staging_buffer_init :: proc(
    self: ^Staging_Buffer,
    device: Device,
    size: u64,
    loc := #caller_location,
) {
    assert(self != nil, "[Staging_Buffer]: [out]object is invalid", loc)
    assert(self.buffer == {} && self.device == nil && self.ptr == nil,
        "[Staging_Buffer]: already initialized", loc)
    assert(device != nil, "[Staging_Buffer]: Invalid device", loc)
    assert(size > 0, "[Staging_Buffer]: size must be > 0", loc)

    stage_desc := Buffer_Descriptor {
        label = "Internal stage buffer",
        size  = size,
        usage = {.Map_Write, .Copy_Src},
    }

    buffer := device_create_buffer(device, stage_desc, loc)
    assert(buffer != {}, "[Staging_Buffer]: failed to create buffer", loc)

    ptr := buffer_map_sync(buffer, .Write, 0, WHOLE_MAP_SIZE, loc)
    assert(ptr != nil, "[Staging_Buffer]: invalid mapped pointer")

    self.buffer = buffer
    self.device = device
    self.size   = size
    self.ptr    = ptr
}

staging_buffer_uninit :: proc(self: ^Staging_Buffer, loc := #caller_location) {
    assert(self != nil, "Invalid staging buffer object", loc)
    assert(self.buffer != {}, "Staging buffer not initialized", loc)
    assert(self.device != nil, "Staging buffer has no device", loc)
    assert(self.ptr == nil, "Staging buffer must be flushed before uninit", loc)

    buffer_destroy(self.buffer, loc)
    self^ = {}
}

staging_buffer_ptr :: #force_inline proc "contextless" (
    self: ^Staging_Buffer,
    loc := #caller_location,
) -> rawptr {
    assert_contextless(self != nil, "Invalid staging buffer object", loc)
    assert_contextless(self.ptr != nil, "Staging buffer pointer is nil", loc)

    return self.ptr
}

staging_buffer_get_data :: #force_inline proc "contextless" (
    self: ^Staging_Buffer,
    loc := #caller_location,
) -> []u8 {
    assert_contextless(self != nil, "Invalid staging buffer object", loc)

    return ([^]u8)(staging_buffer_ptr(self, loc))[:self.size]
}

staging_buffer_write_zeros :: proc "contextless" (self: ^Staging_Buffer, loc := #caller_location) {
    assert_contextless(self != nil, "Invalid staging buffer object", loc)

    mapping := staging_buffer_get_data(self, loc)
    mem.zero_slice(mapping)
}

staging_buffer_write :: proc "contextless" (
    self: ^Staging_Buffer,
    data: []u8,
    loc := #caller_location,
) {
    assert_contextless(self != nil, "Invalid staging buffer object", loc)
    assert_contextless(self.size == 0 || data != nil, "data is nil for non-empty write", loc)

    n := min(int(self.size), len(data))
    assert_contextless(n > 0 || self.size == 0, "nothing to write", loc)

    mem.copy_non_overlapping(staging_buffer_ptr(self, loc), raw_data(data), n)
}

staging_buffer_write_with_offset :: proc "contextless" (
    self: ^Staging_Buffer,
    data: []u8,
    src_offset, dst_offset: int,
    size: uint,
    loc := #caller_location,
) {
    assert_contextless(self != nil, "Invalid staging buffer object", loc)
    assert_contextless(src_offset + int(size) <= len(data),
        "src_offset + size must be in-bounds", loc)

    mem.copy_non_overlapping(
        rawptr(uintptr(self.ptr) + uintptr(dst_offset)),
        rawptr(uintptr(raw_data(data)) + uintptr(src_offset)),
        int(size),
    )
}

Flushed_Staging_Buffer :: struct {
    buffer: Buffer,
    device: Device,
    size:   u64,
}

@(require_results)
staging_buffer_flush :: proc(
    self: ^Staging_Buffer,
    loc := #caller_location,
) -> Flushed_Staging_Buffer {
    assert(self != nil, "Invalid staging buffer object", loc)
    assert(self.buffer != {}, "[Staging_Buffer] not initialized", loc)
    assert(self.ptr != nil, "[Staging_Buffer] pointer is nil (already unmapped?)", loc)

    buffer_flush_mapped_ranges(self.buffer, 0, uint(self.size), loc)
    buffer_unmap(self.buffer, loc)
    self.ptr = nil

    return { self.buffer, self.device, self.size }
}
