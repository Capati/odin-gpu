#+build !js
package gpu

// Core
import intr "base:intrinsics"
import "base:runtime"
import "core:sync"

// One temporary owned by a flush batch.
VK_Flush_Temp :: union {
    VK_Staging_Reclaim,
    Flushed_Staging_Buffer,
}

// Everything one queue submission needs while it is recording and flushing.
VK_Flush_Batch :: struct {
    encoder:            Command_Encoder,
    temp:               [dynamic]VK_Flush_Temp,
    buffers:            [dynamic]Buffer,
    buffer_bits:        [dynamic]u64,
    textures:           [dynamic]Texture,
    texture_bits:       [dynamic]u64,
    // Staging rings whose barrier this batch has already recorded.
    transitioned_rings: [dynamic]^VK_Staging_Ring,
}

// Resources queued for the next queue submission.
VK_Deferred_Writes :: struct {
    device:    Device,
    allocator: runtime.Allocator,
    active:    ^VK_Flush_Batch,
    spare:     ^VK_Flush_Batch,
    // The batch currently being flushed. Kept visible so `contains_buffer`
    // still refuses a direct host write until the flush has submitted.
    flushing:  ^VK_Flush_Batch,
    mtx:       sync.RW_Mutex,
    flush_mtx: sync.Mutex,
}

vk_deferred_writes_init :: proc(
    self: ^VK_Deferred_Writes,
    device: Device,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    self.device = device
    self.allocator = allocator
    self.active = vk_deferred_writes_batch_create(self, loc)
}

vk_deferred_writes_uinit :: proc(self: ^VK_Deferred_Writes, loc := #caller_location) {
    assert(self != nil, loc = loc)
    if self.active != nil {
        vk_deferred_writes_batch_destroy(self, self.active)
        self.active = nil
    }
    if self.spare != nil {
        vk_deferred_writes_batch_destroy(self, self.spare)
        self.spare = nil
    }
    if self.flushing != nil {
        if self.flushing != self.active && self.flushing != self.spare {
            vk_deferred_writes_batch_destroy(self, self.flushing)
        }
        self.flushing = nil
    }
}

vk_deferred_writes_batch_create :: proc(
    self: ^VK_Deferred_Writes,
    loc := #caller_location,
) -> ^VK_Flush_Batch {
    batch := new(VK_Flush_Batch, self.allocator)
    batch.temp.allocator = self.allocator
    batch.buffers.allocator = self.allocator
    batch.buffer_bits.allocator = self.allocator
    batch.textures.allocator = self.allocator
    batch.texture_bits.allocator = self.allocator
    batch.transitioned_rings.allocator = self.allocator
    return batch
}

vk_deferred_writes_batch_destroy :: proc(
    self: ^VK_Deferred_Writes,
    batch: ^VK_Flush_Batch,
    loc := #caller_location,
) {
    delete(batch.temp)
    delete(batch.buffers)
    delete(batch.buffer_bits)
    delete(batch.textures)
    delete(batch.texture_bits)
    delete(batch.transitioned_rings)
    free(batch, self.allocator)
}

// Grow a dense bitset so `index` has a word, with the same power-of-two
// overshoot as `Resource_Metadata`. The index is a dense tracker index.
//
// Batches are reused across flushes and `clear` keeps their capacity, so this
// must grow in place: reallocating whenever `len` is short would put a fresh
// allocation and free in every frame's flush path.
vk_deferred_bitmap_grow :: proc(bits: ^[dynamic]u64, index: u32) {
    words := int(index / 64 + 1)
    if cap(bits^) < words {
        new_cap := words
        if new_cap < cap(bits^) * 2 {
            new_cap = cap(bits^) * 2
        }
        if new_cap < 4 {
            new_cap = 4
        }
        reserve(bits, new_cap)
    }
    if len(bits^) < words {
        // Words behind the old length still hold the previous batch's bits
        // because `clear` only drops the length, so zero them explicitly.
        old_len := len(bits^)
        resize(bits, words)
        for i in old_len ..< words {
            bits^[i] = 0
        }
    }
}

vk_deferred_bitmap_contains :: proc(bits: ^[dynamic]u64, index: u32) -> bool {
    if index >= u32(len(bits^)) * 64 {
        return false
    }
    return (bits^[index / 64] & (1 << (index % 64))) != 0
}

vk_deferred_bitmap_set :: proc(bits: ^[dynamic]u64, index: u32) {
    vk_deferred_bitmap_grow(bits, index)
    bits^[index / 64] |= 1 << (index % 64)
}

// Ensure a dense array has a zeroed slot for `index`, then store `value`.
vk_deferred_dense_set :: proc(list: ^[dynamic]$T, index: u32, value: T) {
    for u32(len(list^)) <= index {
        append(list, T{})
    }
    list^[index] = value
}

// Exclusive-lock body. Callers already hold `mtx`.
vk_deferred_writes_insert_buffer_locked :: proc(
    self: ^VK_Deferred_Writes,
    buffer: Buffer,
    loc := #caller_location,
) {
    ensure(self.active != nil, "no active flush batch", loc)
    impl := vk_buffer_get_impl(buffer, loc)
    index := u32(impl.tracker_index)
    if vk_deferred_bitmap_contains(&self.active.buffer_bits, index) {
        return
    }
    vk_deferred_dense_set(&self.active.buffers, index, buffer)
    vk_deferred_bitmap_set(&self.active.buffer_bits, index)
    intr.atomic_add(&impl.deferred_holds, 1)
    add_ref(impl, loc)
}

// Exclusive-lock body. Callers already hold `mtx`.
vk_deferred_writes_insert_texture_locked :: proc(
    self: ^VK_Deferred_Writes,
    texture: Texture,
    loc := #caller_location,
) {
    ensure(self.active != nil, "no active flush batch", loc)
    impl := vk_texture_get_impl(texture, loc)
    index := u32(impl.tracker_index)
    if vk_deferred_bitmap_contains(&self.active.texture_bits, index) {
        return
    }
    vk_deferred_dense_set(&self.active.textures, index, texture)
    vk_deferred_bitmap_set(&self.active.texture_bits, index)
    intr.atomic_add(&impl.deferred_holds, 1)
    add_ref(impl, loc)
}

// Exclusive-lock body. Callers already hold `mtx` and have recorded the copy
// that reads this reservation into the scratch encoder.
vk_deferred_writes_defer_staging_locked :: proc(
    self: ^VK_Deferred_Writes,
    reservation: VK_Staging_Reservation,
    loc := #caller_location,
) {
    ensure(self.active != nil, "no active flush batch", loc)
    append(
        &self.active.temp,
        VK_Flush_Temp(
            VK_Staging_Reclaim {
                value   = 0, // assigned when the batch is submitted
                ring    = reservation.ring,
                abs_end = reservation.abs_end,
            },
        ),
    )
}

// Records the staging ring's `Map_Write -> Copy_Src` barrier unless this batch
// already did. Caller must hold `mtx` for the whole recording operation.
vk_deferred_writes_ring_ready_locked :: proc(self: ^VK_Deferred_Writes, ring: ^VK_Staging_Ring) {
    ensure(self.active != nil, "no active flush batch")
    for existing in self.active.transitioned_rings {
        if existing == ring {
            return
        }
    }
    append(&self.active.transitioned_rings, ring)
    barriers := [1]Buffer_State_Transition {
        {buffer = ring.buffer, from = {.Map_Write}, to = {.Copy_Src}},
    }
    _command_encoder_transition_buffers(self.active.encoder, barriers[:])
}

vk_deferred_writes_contains_buffer :: proc(self: ^VK_Deferred_Writes, buffer: Buffer) -> bool {
    index := u32(_buffer_tracker_index(buffer))
    sync.shared_guard(&self.mtx)
    if self.active != nil && vk_deferred_bitmap_contains(&self.active.buffer_bits, index) {
        return true
    }
    if self.flushing != nil && vk_deferred_bitmap_contains(&self.flushing.buffer_bits, index) {
        return true
    }
    return false
}

// Exclusive-lock body. Callers already hold `mtx`.
vk_deferred_writes_consume_locked :: proc(
    self: ^VK_Deferred_Writes,
    buffer: Flushed_Staging_Buffer,
    loc := #caller_location,
) {
    ensure(self.active != nil, "no active flush batch", loc)
    append(&self.active.temp, VK_Flush_Temp(buffer))
}

// Returns the active batch's scratch encoder, creating it on first use.
//
// Caller must hold `mtx` for the entire recording operation. Each batch has
// exactly one scratch encoder, so a locking wrapper would not make concurrent
// recording safe. All operations that append commands must use the `_locked`
// helpers while holding the mutex.
vk_deferred_writes_activate_locked :: proc(
    self: ^VK_Deferred_Writes,
    loc := #caller_location,
) -> Command_Encoder {
    assert(self != nil, loc = loc)
    if self.active == nil {
        self.active = vk_deferred_writes_batch_create(self, loc)
    }
    if self.active.encoder != {} {
        return self.active.encoder
    }
    self.active.encoder = device_create_command_encoder(self.device, {}, loc)
    return self.active.encoder
}

// Detaches the active batch and promotes the spare to the new recording batch. The
// caller must submit and drain the returned batch, then recycle it.
//
// `flush_mtx` serializes flushes, so one spare is enough to keep recording
// concurrent with submission. The detached batch only needs to be drained, not
// completed, before it can be recycled.
vk_deferred_writes_take_batch :: proc(
    self: ^VK_Deferred_Writes,
    loc := #caller_location,
) -> (
    batch: ^VK_Flush_Batch,
    ok: bool,
) {
    sync.guard(&self.mtx)
    if self.active == nil || self.active.encoder == {} {
        return nil, false
    }
    ensure(self.flushing == nil, "a flush batch is already in flight", loc)

    batch = self.active
    self.flushing = batch

    self.active = self.spare
    self.spare = nil
    if self.active == nil {
        self.active = vk_deferred_writes_batch_create(self, loc)
    }
    return batch, true
}

// Returns a drained batch to the pool. The batch's destination arrays may still
// be populated (the flush releases their refs but leaves presence for
// `contains_buffer` until this point); they are cleared here.
vk_deferred_writes_recycle_batch :: proc(
    self: ^VK_Deferred_Writes,
    batch: ^VK_Flush_Batch,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    ensure(batch.encoder == {}, "flush batch still owns an encoder", loc)
    clear(&batch.temp)
    clear(&batch.buffers)
    clear(&batch.buffer_bits)
    clear(&batch.textures)
    clear(&batch.texture_bits)
    clear(&batch.transitioned_rings)
    if self.flushing == batch {
        self.flushing = nil
    }
    if self.spare == nil {
        self.spare = batch
    } else {
        vk_deferred_writes_batch_destroy(self, batch, loc)
    }
}

// Schedules a zero fill of `offset..offset+size` on the buffer, folded into the
// next queue submission.
vk_deferred_writes_clear_buffer :: proc(
    self: ^VK_Deferred_Writes,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    vk_deferred_writes_clear_buffer_locked(self, buffer, offset, size, loc)
}

// Exclusive-lock body of `vk_deferred_writes_clear_buffer`.
vk_deferred_writes_clear_buffer_locked :: proc(
    self: ^VK_Deferred_Writes,
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

    encoder := vk_deferred_writes_activate_locked(self, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    barriers := make([dynamic]Buffer_State_Transition, 0, 2, ta)
    defer delete(barriers)
    {
        sync.guard(&device_impl.trackers_mtx)
        device_buffer_tracker_set_single(
            &device_impl.trackers.buffers,
            buffer_impl.tracker_index,
            buffer,
            {.Copy_Dst},
            &barriers,
        )
    }

    if len(barriers) > 0 {
        vk_command_encoder_transition_buffers(encoder, barriers[:], loc)
    }

    // Internal padding clear: bypasses the public clearBuffer validation, which
    // works in terms of the application-visible size and usages.
    vk_command_encoder_clear_buffer_internal(encoder, buffer, offset, size, loc)
    buffer_init_tracker_mark_initialized(&buffer_impl.init, offset, offset + size)

    vk_deferred_writes_insert_buffer_locked(self, buffer)
}
