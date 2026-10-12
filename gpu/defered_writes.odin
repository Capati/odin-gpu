package gpu

// Core
import "base:runtime"

import "core:sync"

// A texture or buffer to be freed soon.
//
// This is just a tagged raw texture or buffer, generally about to be added to
// some other more specific container like:
//
//   - `Deferred_Writes.temp_resources`: resources used by queue writes and
//     unmaps, waiting to be folded in with the next queue submission.
//
//   - Active_Submission.temp_resources: temporary resources used by a queue
//     submission, to be freed when it completes
Temp_Resource :: union {
    Flushed_Staging_Buffer,
    // Scratch_Buffer,
    // Destroyed_Buffer,
    // Destroyed_Texture,
    // Destroyed_Query_Set,
}

// Resources queued for the next queue submission: the scratch command encoder,
// the staging buffers it references, and the destination buffers/textures it
// touches. Every field is mutated by whichever thread performs a queue write,
// buffer unmap, or buffer clear, and drained by whichever thread next submits.
//
// `mtx` therefore guards all of it. Ordering: this is an outer lock relative to
// the device trackers, since `deferred_writes_clear_buffer` calls into
// `device_buffer_tracker_set_single` while draining. It is never held while
// acquiring the submit-context lock, `vk_pending_writes_flush` drains the state
// under this lock, releases it, and only then records and submits.
Deferred_Writes :: struct {
    device:          Device,
    command_encoder: Command_Encoder,
    temp_resources:  [dynamic]Temp_Resource,
    dst_buffers:     map[Tracker_Index]Buffer,
    dst_textures:    map[Tracker_Index]Texture,
    copied_blas_s:   map[Tracker_Index]Blas,
    instance_flags:  Instance_Flags,
    mtx:             sync.RW_Mutex,
}

deferred_writes_init :: proc(
    self: ^Deferred_Writes,
    device: Device,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    self.device = device
    self.temp_resources.allocator = allocator
    self.dst_buffers.allocator = allocator
    self.dst_textures.allocator = allocator
    self.copied_blas_s.allocator = allocator
}

// No lock is taken here: `uinit` runs at device teardown, when no other thread can
// still be holding `mtx`, and taking it would only hide an ordering bug.
deferred_writes_uinit :: proc(self: ^Deferred_Writes, loc := #caller_location) {
    assert(self != nil, loc = loc)
    delete(self.temp_resources)
    delete(self.dst_buffers)
    delete(self.dst_textures)
    delete(self.copied_blas_s)
}

deferred_writes_insert_buffer :: proc(self: ^Deferred_Writes, buffer: Buffer) {
    sync.guard(&self.mtx)
    deferred_writes_insert_buffer_locked(self, buffer)
}

// Exclusive-lock body of `deferred_writes_insert_buffer`.
deferred_writes_insert_buffer_locked :: proc(self: ^Deferred_Writes, buffer: Buffer) {
    self.dst_buffers[buffer_tracker_index(buffer)] = buffer
}

deferred_writes_insert_texture :: proc(self: ^Deferred_Writes, texture: Texture) {
    sync.guard(&self.mtx)
    deferred_writes_insert_texture_locked(self, texture)
}

// Exclusive-lock body of `deferred_writes_insert_texture`.
deferred_writes_insert_texture_locked :: proc(self: ^Deferred_Writes, texture: Texture) {
    self.dst_textures[texture_tracker_index(texture)] = texture
}

// deferred_writes_insert_blas :: proc(self: ^Deferred_Writes, blas: Blas) {
//     self.copied_blas_s[blas_tracker_index(blas)] = blas
// }

deferred_writes_contains_buffer :: proc(self: ^Deferred_Writes, buffer: Buffer) -> bool {
    index := buffer_tracker_index(buffer)
    sync.shared_guard(&self.mtx)
    return index in self.dst_buffers
}

deferred_writes_contains_texture :: proc(self: ^Deferred_Writes, texture: Texture) -> bool {
    index := texture_tracker_index(texture)
    sync.shared_guard(&self.mtx)
    return index in self.dst_textures
}

deferred_writes_consume_temp :: proc(self: ^Deferred_Writes, resource: Temp_Resource) {
    sync.guard(&self.mtx)
    deferred_writes_consume_temp_locked(self, resource)
}

// Exclusive-lock body of `deferred_writes_consume_temp`.
deferred_writes_consume_temp_locked :: proc(self: ^Deferred_Writes, resource: Temp_Resource) {
    append(&self.temp_resources, resource)
}

deferred_writes_consume :: proc(self: ^Deferred_Writes, buffer: Flushed_Staging_Buffer) {
    sync.guard(&self.mtx)
    deferred_writes_consume_locked(self, buffer)
}

// Exclusive-lock body of `deferred_writes_consume`.
deferred_writes_consume_locked :: proc(self: ^Deferred_Writes, buffer: Flushed_Staging_Buffer) {
    append(&self.temp_resources, buffer)
}

// Returns the scratch encoder, creating it on first use.
//
// Exclusive-lock body. There is deliberately no locking wrapper: returning the
// encoder would not make concurrent recording safe, because there is exactly one
// scratch encoder. Whoever holds `mtx` owns recording into it, so every operation
// that appends commands to it, `deferred_writes_clear_buffer`, the queue writes,
// and buffer unmap, must take `mtx` once and keep it until it has finished
// recording, using the `_locked` helpers here.
deferred_writes_activate_locked :: proc(
    self: ^Deferred_Writes,
    loc := #caller_location,
) -> Command_Encoder {
    assert(self != nil, loc = loc)
    if self.command_encoder != {} {
        return self.command_encoder
    }
    self.command_encoder = device_create_command_encoder(
        self.device, {label = "(internal) Deferred_Writes"}, loc)
    return self.command_encoder
}

// Detaches the pending batch so the caller can record and submit it without
// holding `mtx`, and returns false when there is nothing pending.
//
// Exclusive-lock body; see `Deferred_Writes` for why recording must not happen
// under this lock. `self` is left empty and usable, so the next queue write starts
// a fresh encoder rather than appending to one already in flight.
deferred_writes_take_pending_locked :: proc(
    self: ^Deferred_Writes,
    command_encoder: ^Command_Encoder,
    temp_resources: ^[dynamic]Temp_Resource,
) -> bool {
    if self.command_encoder == {} {
        return false
    }

    command_encoder^ = self.command_encoder
    self.command_encoder = {}

    // Ownership of the storage moves out with the batch. `self` is left empty but
    // keeps the allocator, so the next append allocates fresh instead of writing into
    // memory the caller is still draining. Zeroing the whole container is what makes
    // that true, assigning only `.allocator` would leave `self` aliasing the batch.
    allocator := temp_resources.allocator
    temp_resources^ = self.temp_resources
    self.temp_resources = [dynamic]Temp_Resource{}
    self.temp_resources.allocator = allocator

    clear(&self.dst_buffers)
    clear(&self.dst_textures)
    return true
}

// Schedules a `vkCmdFillBuffer`-style zeroing of `offset..offset+size` on the
// buffer, folded into the next queue submission.
deferred_writes_clear_buffer :: proc(
    self: ^Deferred_Writes,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    deferred_writes_clear_buffer_locked(self, buffer, offset, size, loc)
}

// Exclusive-lock body of `deferred_writes_clear_buffer`.
deferred_writes_clear_buffer_locked :: proc(
    self: ^Deferred_Writes,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)

    // Nothing to do, and don't touch tracker state for a no-op.
    if size == 0 {
        return
    }

    assert(offset % 4 == 0, "clear offset must be a multiple of 4", loc)
    assert(size % 4 == 0, "clear size must be a multiple of 4", loc)

    device_impl := device_get_public_impl(self.device, loc)
    buffer_impl := buffer_get_public_impl(buffer, loc)

    // Written to avoid u64 overflow in offset + size.
    assert(offset <= buffer_impl.size && size <= buffer_impl.size - offset,
        "clear range out of bounds", loc)
    assert(.Copy_Dst in buffer_impl.usage, "buffer missing Copy_Dst usage", loc)

    encoder := deferred_writes_activate_locked(self, loc)

    barriers: [dynamic; 1]Buffer_Barrier
    if pending, ok := device_buffer_tracker_set_single(
        &device_impl.trackers.buffers,
        buffer_impl.tracker_index,
        buffer,
        {.Copy_Dst},
    ); ok {
        append(&barriers, Buffer_Barrier{buffer = buffer, usage = pending.usage})
    }

    if len(barriers) > 0 {
        command_encoder_transition_buffers(encoder, barriers[:], loc)
    }
    command_encoder_clear_buffer(encoder, buffer, offset, size, loc)

    deferred_writes_insert_buffer_locked(self, buffer)
}
