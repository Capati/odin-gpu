package gpu

// Core
import "base:runtime"

import "core:sync"

// Resources queued for the next queue submission: the scratch command encoder,
// the staging buffers it references, and the destination buffers/textures it
// touches. Every field is mutated by whichever call performs a queue write,
// buffer unmap, or buffer clear, and drained by the next submit.
Deferred_Writes :: struct {
    device:               Device,
    command_encoder:      Command_Encoder,
    // Staging buffers whose queued writes are recorded and that must survive
    // until the submission consuming them retires. Destroyed buffers, textures,
    // and query sets are parked by `VK_Deferred_Deletor` (gpu/vk_resource.odin)
    // against the submission they were last used in instead; there is no
    // scratch-buffer path because uploads use the staging ring.
    staging_buffers:       [dynamic]Flushed_Staging_Buffer,
    // Spare backing for `staging_buffers`. The flush path moves the active batch
    // out and swaps in the spare, so the next batch reuses the previously drained
    // storage instead of allocating a fresh array per submit (see
    // `deferred_writes_take_pending_locked`).
    staging_buffers_spare: [dynamic]Flushed_Staging_Buffer,
    // Dense membership bitmap keyed by buffer tracker index. `Tracker_Index` is
    // dense by construction, and `Resource_Metadata.owned` already implements
    // exactly this pattern; a hash map keyed by a dense integer pays a hash +
    // node chase per `queue_write` where a bitmap word is one cache line. Words
    // are grown on demand with the same power-of-two overshoot as
    // `Resource_Metadata`.
    dst_buffer_bits:      [dynamic]u64,
    // Pending textures are stored as handles, not bits: the flush needs to
    // enumerate them to propagate swapchain touches (acquire waits and present
    // signals) for images written by `queue_write_texture`.
    dst_textures:         map[Tracker_Index]Texture,
    mtx:                  sync.RW_Mutex,
}

deferred_writes_init :: proc(
    self: ^Deferred_Writes,
    device: Device,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    self.device = device
    self.staging_buffers.allocator = allocator
    self.staging_buffers_spare.allocator = allocator
    self.dst_buffer_bits.allocator = allocator
    self.dst_textures.allocator = allocator
}

// No lock is taken here: `uinit` runs at device teardown, when no other thread can
// still be holding `mtx`, and taking it would only hide an ordering bug.
deferred_writes_uinit :: proc(self: ^Deferred_Writes, loc := #caller_location) {
    assert(self != nil, loc = loc)
    delete(self.staging_buffers)
    delete(self.staging_buffers_spare)
    delete(self.dst_buffer_bits)
    delete(self.dst_textures)
}

// Grow a dense bitmap so `index` has a word, in one allocation with power-of-
// two overshoot (mirrors `resource_metadata_grow_to`).
@(private = "file")
deferred_bitmap_grow :: proc(bits: ^[dynamic]u64, index: Tracker_Index) {
    i := u32(index)
    words := i / 64 + 1
    if u32(len(bits^)) < words {
        new_size := words
        if new_size < u32(len(bits^)) * 2 {
            new_size = u32(len(bits^)) * 2
        }
        if new_size < 4 {
            new_size = 4
        }
        new_bits := make([dynamic]u64, new_size, bits.allocator)
        copy(new_bits[:], bits^[:])
        delete(bits^)
        bits^ = new_bits
    }
}

@(private = "file")
deferred_bitmap_set :: proc(bits: ^[dynamic]u64, index: Tracker_Index) {
    deferred_bitmap_grow(bits, index)
    bits^[u32(index) / 64] |= 1 << (u32(index) % 64)
}

@(private = "file")
deferred_bitmap_contains :: proc(bits: ^[dynamic]u64, index: Tracker_Index) -> bool {
    if u32(index) >= u32(len(bits^)) * 64 {
        return false
    }
    return (bits^[u32(index) / 64] & (1 << (u32(index) % 64))) != 0
}

// Exclusive-lock body. Callers already hold `mtx`.
deferred_writes_insert_buffer_locked :: proc(self: ^Deferred_Writes, buffer: Buffer) {
    deferred_bitmap_set(&self.dst_buffer_bits, _buffer_tracker_index(buffer))
}

// Exclusive-lock body. Callers already hold `mtx`.
deferred_writes_insert_texture_locked :: proc(self: ^Deferred_Writes, texture: Texture) {
    self.dst_textures[_texture_tracker_index(texture)] = texture
}

deferred_writes_contains_buffer :: proc(self: ^Deferred_Writes, buffer: Buffer) -> bool {
    index := _buffer_tracker_index(buffer)
    sync.shared_guard(&self.mtx)
    return deferred_bitmap_contains(&self.dst_buffer_bits, index)
}

// Exclusive-lock body. Callers already hold `mtx`.
deferred_writes_consume_locked :: proc(self: ^Deferred_Writes, buffer: Flushed_Staging_Buffer) {
    append(&self.staging_buffers, buffer)
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
    self.command_encoder = device_create_command_encoder(self.device, {}, loc)
    return self.command_encoder
}

// Detaches the pending batch so the caller can record and submit it without
// holding `mtx`, and returns false when there is nothing pending.
//
// Exclusive-lock body; see `Deferred_Writes` for why recording must not happen
// under this lock. `self` is left empty and usable, so the next queue write starts
// a fresh encoder rather than appending to one already in flight.
//
// Destination tracking is drained on both paths: a write that never activated
// the encoder has no queued command left to protect.
deferred_writes_take_pending_locked :: proc(
    self: ^Deferred_Writes,
    command_encoder: ^Command_Encoder,
    staging_buffers: ^[dynamic]Flushed_Staging_Buffer,
    pending_textures: ^map[Tracker_Index]Texture,
) -> bool {
    defer {
        clear(&self.dst_buffer_bits)
        clear(&self.dst_textures)
    }

    if self.command_encoder == {} {
        return false
    }

    command_encoder^ = self.command_encoder
    self.command_encoder = {}

    // Ownership of the staging buffers moves out with the batch. `self` is left
    // empty but reuses a spare backing so the next batch does not allocate fresh
    // while the caller is still draining the previous one. The spare is cleared
    // in place; its capacity is the high-water mark of the last batch.
    allocator := self.staging_buffers.allocator
    staging_buffers^ = self.staging_buffers

    if len(self.staging_buffers_spare) > 0 {
        clear(&self.staging_buffers_spare)
        // Reuse spare for this `self` (capacity kept).
        self.staging_buffers = self.staging_buffers_spare
        self.staging_buffers_spare = {}
        self.staging_buffers_spare.allocator = allocator
    } else {
        // First flush (or spare exhausted): fall back to a fresh empty array.
        // Zeroing the container is what makes this non-aliasing, assigning only
        // `.allocator` would leave `self` aliasing the batch.
        self.staging_buffers = [dynamic]Flushed_Staging_Buffer{}
        self.staging_buffers.allocator = allocator
    }

    // Texture handles move out with the batch so the flush can propagate
    // swapchain touches; the caller deletes the map once the submission has
    // consumed them. A fresh empty map keeps the allocator for the next batch.
    pending_textures^ = self.dst_textures
    self.dst_textures = {}
    self.dst_textures.allocator = allocator

    return true
}

// Schedules a zero fill of `offset..offset+size` on the buffer, folded into the
// next queue submission.
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

    device_impl := _device_get_internal_impl(self.device, loc)
    buffer_impl := _buffer_get_internal_impl(buffer, loc)

    // Written to avoid u64 overflow in offset + size.
    assert(
        offset <= buffer_impl.size && size <= buffer_impl.size - offset,
        "clear range out of bounds",
        loc,
    )
    assert(.Copy_Dst in buffer_impl.usage, "buffer missing Copy_Dst usage", loc)

    encoder := deferred_writes_activate_locked(self, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    barriers := make([dynamic]Buffer_State_Transition, 0, 2, ta)
    defer delete(barriers)
    device_buffer_tracker_set_single(
        &device_impl.trackers.buffers,
        buffer_impl.tracker_index,
        buffer,
        {.Copy_Dst},
        &barriers,
    )

    if len(barriers) > 0 {
        _command_encoder_transition_buffers(encoder, barriers[:], loc)
    }

    // Internal padding clear: bypasses the public clearBuffer validation, which
    // works in terms of the application-visible size and usages.
    _command_encoder_clear_buffer(encoder, buffer, offset, size, loc)
    buffer_init_tracker_mark_initialized(&buffer_impl.init, offset, offset + size)

    deferred_writes_insert_buffer_locked(self, buffer)
}
