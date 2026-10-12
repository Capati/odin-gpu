#+build !js
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"
import "core:sync"
import "core:time"

import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_MAX_SUBMIT_WAITS   :: VK_MAX_ACQUIRE_SLOTS + 1
VK_MAX_SUBMIT_SIGNALS :: VK_MAX_ACQUIRE_SLOTS + 1

VK_Queue_Handle :: distinct hm.Handle64

VK_Queue_Default_Impl :: struct {
    // base #subtype
    using base:            Queue_Impl,

    // Backend (single-queue for now: compute/transfer share this queue)
    graphics_queue:        vk.Queue,
    graphics_family_index: u32,
}

VK_Queue_Impl :: struct {
    device:        Device,
    defaut_handle: VK_Queue_Handle,
    handle:        VK_Queue_Handle,
    ref:           Ref_Count_Type,
}

@(require_results)
vk_queue_get_wrapper_impl :: #force_inline proc "contextless" (
    queue: Queue,
    loc := #caller_location,
) -> ^VK_Queue_Impl {
    device_impl := vk_device_get_impl(queue.device, loc)
    return get_handle_impl(&device_impl.queues, queue.handle, loc)
}

@(require_results)
vk_queue_get_public_impl :: #force_inline proc "contextless" (
    queue: Queue,
    loc := #caller_location,
) -> ^Queue_Impl {
    return vk_queue_get_impl(queue, loc)
}

@(require_results)
vk_queue_get_impl :: #force_inline proc "contextless" (
    queue: Queue,
    loc := #caller_location,
) -> ^VK_Queue_Default_Impl {
    device_impl := vk_device_get_impl(queue.device, loc)
    return &device_impl.queue
}

vk_queue_init :: proc(
    self: ^VK_Queue_Default_Impl,
    family_index: u32,
    device: Device,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(device, loc)
    self.device = device
    device_impl.fp.GetDeviceQueue(
        device_impl.vk_device, family_index, 0, &self.graphics_queue)
    // Recorded for future queue-family ownership transfers.
    self.graphics_family_index = family_index
    deferred_writes_init(&self.deferred_writes, device, device_impl.allocator, loc)
}

vk_queue_uinit :: proc(self: ^VK_Queue_Default_Impl) {
    deferred_writes_uinit(&self.deferred_writes)
}

vk_queue_on_submitted_work_done :: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

vk_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_pending_writes_flush :: proc(pw: ^Deferred_Writes, device: Device, loc := #caller_location) {
    // Detach under the lock, drain without it. Submit must not hold
    // `Deferred_Writes.mtx`: other threads need it for fresh encoders.
    command_encoder: Command_Encoder
    temp_resources: [dynamic]Temp_Resource
    {
        sync.guard(&pw.mtx)
        if !deferred_writes_take_pending_locked(pw, &command_encoder, &temp_resources) {
            return
        }
    }

    device_impl := vk_device_get_impl(device, loc)
    encoder_impl := vk_command_encoder_get_impl(command_encoder, loc)

    // Claimed from the submit context and detached, so recording is single-owner.
    vk_record_commands(device, encoder_impl.cmdbuf, loc)
    vk_submit_context_submit(&device_impl.submitter, encoder_impl.cmdbuf, loc)

    for res in temp_resources {
        switch v in res {
        case Flushed_Staging_Buffer:
            vk_buffer_release(v.buffer)
        }
    }
    delete(temp_resources)

    encoder_impl.is_encoding = false
    vk_command_encoder_release(command_encoder, loc)
}

vk_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    impl := vk_queue_get_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    vk_pending_writes_flush(&device_impl.queue.deferred_writes, impl.device, loc)

    for cmdbuf in commands {
        cmdbuf_impl := vk_command_buffer_get_impl(cmdbuf, loc)
        vk_record_commands(impl.device, cmdbuf_impl, loc)
        vk_submit_context_submit(&device_impl.submitter, cmdbuf_impl, loc)
    }

    vk_deferred_process(&device_impl.deferred, &device_impl.submitter, loc)
}

vk_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []u8,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    impl := vk_queue_get_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    texture_impl := vk_texture_get_impl(destination.texture, loc)

    if write_size.width == 0 ||
        write_size.height == 0 ||
        write_size.depth_or_array_layers == 0 {
        return
    }

    // 3D textures pack depth slices in one layer; layers count slices here.
    is_3d := texture_impl.dimension == .D3

    block_width, block_height := texture_format_block_dimensions(texture_impl.format)
    width_in_blocks  := write_size.width / block_width
    height_in_blocks := write_size.height / block_height

    block_size := texture_format_block_copy_size(texture_impl.format, destination.aspect)
    bytes_in_last_row := width_in_blocks * block_size

    bytes_per_row := data_layout.bytes_per_row
    if bytes_per_row == 0 {
        bytes_per_row = bytes_in_last_row
    }

    rows_per_image := data_layout.rows_per_image
    if rows_per_image == 0 {
        rows_per_image = height_in_blocks
    }

    // Staging row pitch must align to block size and driver pitch.
    pitch_alignment := math.lcm(
        max(u64(1), device_impl.alignments.buffer_copy_pitch),
        max(u64(1), u64(block_size)))
    stage_bytes_per_row := u32(mem.align_forward_uint(
        uint(bytes_in_last_row), uint(pitch_alignment)))

    // 3D uses one array layer with N slices; 2D arrays copy per layer.
    staging_slice_count := write_size.depth_or_array_layers
    array_layer_count := is_3d ? 1 : staging_slice_count

    staging_buffer: Staging_Buffer
    stage_size :=
        u64(stage_bytes_per_row) *
        u64(rows_per_image) *
        u64(staging_slice_count)
    staging_buffer_init(&staging_buffer, impl.device, stage_size, loc)

    if stage_bytes_per_row == bytes_per_row {
        // Rows already pitched: bulk copy, padding untouched. Fail loud on
        // short input instead of copying a prefix over a stale tail.
        assert(int(data_layout.offset) + int(stage_size) <= len(data), loc = loc)
        staging_buffer_write(&staging_buffer, data[int(data_layout.offset):], loc)
    } else {
        // Repack rows with padding.
        for slice in 0 ..< u64(staging_slice_count) {
            rows_offset := slice * u64(rows_per_image)
            for row in rows_offset ..< (rows_offset + u64(height_in_blocks)) {
                src_offset := data_layout.offset + row * u64(bytes_per_row)
                dst_offset := row * u64(stage_bytes_per_row)
                staging_buffer_write_with_offset(
                    &staging_buffer, data,
                    int(src_offset), int(dst_offset),
                    uint(bytes_in_last_row), loc)
            }
        }
    }

    flushed_staging_buffer := staging_buffer_flush(&staging_buffer, loc)

    deferred_writes := &device_impl.queue.deferred_writes

    // One scratch encoder: hold the lock while recording so concurrent
    // writes/unmaps can't interleave. Order: Deferred_Writes -> device tracker.
    sync.guard(&deferred_writes.mtx)

    encoder := deferred_writes_activate_locked(deferred_writes, loc)
    encoder_impl := vk_command_encoder_get_impl(encoder, loc)

    staging_barriers: [dynamic;1]Buffer_Barrier
    append(&staging_barriers, Buffer_Barrier {
        buffer = flushed_staging_buffer.buffer,
        usage  = {
            from = {.Map_Write},
            to   = {.Copy_Src},
        },
    })
    command_encoder_transition_buffers(encoder, staging_barriers[:], loc)

    // Move destination to `Copy_Dst`, one barrier per part.
    base_layer := is_3d ? 0 : destination.origin.z
    selector := Texture_Selector {
        mips   = Range(u32){destination.mip_level, destination.mip_level + 1},
        layers = Range(u32){base_layer, base_layer + array_layer_count},
    }

    transitions := device_texture_tracker_set_single(
        &device_impl.trackers.textures,
        destination.texture,
        selector,
        {.Copy_Dst},
        command_encoder_arena_allocator(encoder, loc),
        loc)

    for &transition in transitions {
        cmd := command_allocator_allocate(
            &encoder_impl.cmdbuf.commands, Transition_Texture_Cmd, loc)
        cmd.texture  = destination.texture
        cmd.selector = Image_Subresource_Range {
            aspect            = destination.aspect,
            base_mip_level    = transition.selector.mips.start,
            mip_level_count   = transition.selector.mips.end - transition.selector.mips.start,
            base_array_layer  = transition.selector.layers.start,
            array_layer_count =
                transition.selector.layers.end - transition.selector.layers.start,
        }
        // `from` is the tracker state when `set_single` ran; don't re-read at record time.
        cmd.state_from   = transition.usage.from
        cmd.state_to     = transition.usage.to
        cmd.force_barrier = transition.usage.from != TEXTURE_USES_UNKNOWN
    }

    // One region covers all layers: contiguous from base_layer with identical
    // extents, and the explicit row pitch/height stride matches Vulkan's
    // per-layer offset rule. 3D keeps depth slices in a single layer.
    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Copy_Buffer_To_Texture_Cmd, loc)
    cmd.src = Texel_Copy_Buffer_Info {
        buffer = flushed_staging_buffer.buffer,
        layout = {
            offset         = 0,
            bytes_per_row  = stage_bytes_per_row,
            rows_per_image = rows_per_image,
        },
    }
    layer_dst := destination
    if !is_3d {
        layer_dst.origin.z = base_layer
    }
    cmd.dst  = layer_dst
    cmd.size = Extent_3D {
        width                 = write_size.width,
        height                = write_size.height,
        depth_or_array_layers = is_3d ? write_size.depth_or_array_layers : array_layer_count,
    }

    deferred_writes_insert_texture_locked(deferred_writes, destination.texture)
    deferred_writes_consume_locked(deferred_writes, flushed_staging_buffer)
}

vk_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    add_ref(impl, loc)
}

vk_queue_release :: proc(queue: Queue, loc := #caller_location) {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        remove_handle_impl(&device_impl.queues, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// Submit Context
// -----------------------------------------------------------------------------

VK_Submit_Handle :: struct {
    buffer_index: u32,
    submit_id:    u32,
}

// Lock-free packed handle: purge holds `mtx` while resetting, which routes back
// here, so taking `mtx` would self-deadlock (RW_Mutex is not recursive).
vk_submit_handle_pack :: #force_inline proc "contextless" (h: VK_Submit_Handle) -> u64 {
    return u64(h.buffer_index) | (u64(h.submit_id) << 32)
}

vk_submit_handle_unpack :: #force_inline proc "contextless" (v: u64) -> VK_Submit_Handle {
    return VK_Submit_Handle{buffer_index = u32(v & 0xFFFFFFFF), submit_id = u32(v >> 32)}
}

VK_Submit_Context :: struct {
    buffers:                   [MAX_COMMAND_BUFFERS]VK_Command_Buffer_Impl,

    device:                    Device,
    queue:                     vk.Queue,
    command_pool:              vk.CommandPool,
    queue_family_index:        u32,

    last_submit_handle:        VK_Submit_Handle,
    // Packed `VK_Submit_Handle`, atomically accessed; see `vk_submit_handle_pack`.
    next_submit_handle:        u64,

    // intra-queue chain:      signaled by the previous submit, waited by the next
    last_submit_semaphore:     vk.SemaphoreSubmitInfo,
    // Pending acquire waits keyed by (surface, image). First submit touching
    // an image consumes its entry. Surface lock ranks above submitter lock.
    pending_acquires:          [dynamic]VK_Pending_Acquire,

    available_command_buffers: u32,
    submit_counter:            u32,

    allocator:                 runtime.Allocator,
    in_flight:                 [dynamic]^VK_Command_Buffer_Impl,

    reclaim_pool:              [dynamic]^VK_Submit_Context_Reclaim_Batch,
    // Guards only the pool's pointer list, never held across release calls.
    reclaim_pool_mtx:          sync.Mutex,

    // Guards slot bookkeeping and the semaphore chain. Released for recording
    // (parallel encoders) and blocking waits. Held across QueueSubmit/Present.
    mtx:                       sync.RW_Mutex,
    buffer_available_mtx:      sync.Mutex,
    buffer_available_cond:     sync.Cond,
}

vk_submit_context_init :: proc(
    self: ^VK_Submit_Context,
    device: Device,
    queue_family_index: u32,
    allocator := context.allocator,
    loc := #caller_location,
) {
    self.allocator = allocator
    self.device = device
    self.queue_family_index = queue_family_index

    device_impl := vk_device_get_impl(device, loc)
    device_impl.fp.GetDeviceQueue(device_impl.vk_device, queue_family_index, 0, &self.queue)

    DEFAULT_SEMAPHORE_SUBMIT_INFO :: vk.SemaphoreSubmitInfo {
        sType     = .SEMAPHORE_SUBMIT_INFO,
        stageMask = {.ALL_COMMANDS},
    }
    self.last_submit_semaphore = DEFAULT_SEMAPHORE_SUBMIT_INFO
    self.pending_acquires = make([dynamic]VK_Pending_Acquire, 0, 4, allocator)

    self.available_command_buffers = MAX_COMMAND_BUFFERS
    self.submit_counter = 1 // 0 reserved as "no submission"
    self.in_flight = {}
    self.buffer_available_mtx = {}
    self.buffer_available_cond = {}

    command_pool_info := vk.CommandPoolCreateInfo {
        sType            = .COMMAND_POOL_CREATE_INFO,
        flags            = {.RESET_COMMAND_BUFFER, .TRANSIENT},
        queueFamilyIndex = queue_family_index,
    }
    vk_check(device_impl.fp.CreateCommandPool(
        device_impl.vk_device, &command_pool_info, nil, &self.command_pool))

    for &buf, i in self.buffers {
        vk_command_buffer_init(&buf, device, self.command_pool, i, self.allocator, loc)
    }
}

vk_submit_context_uninit :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    device_impl := vk_device_get_impl(self.device, loc)
    // wait_all locks itself; blocking waits must not exclude others.
    vk_submit_context_wait_all(self, loc)
    for &buf in self.buffers {
        vk_command_buffer_uninit(&buf)
    }
    delete(self.pending_acquires)
    delete(self.in_flight)

    for b in self.reclaim_pool {
        // Batches must come back drained; a full batch here means a caller
        // skipped the release step and its refs would leak.
        assert(
            len(b.bind_group_refs) == 0 &&
            len(b.view_refs) == 0 &&
            len(b.render_pipeline_refs) == 0, loc = loc)
        delete(b.bind_group_refs)
        delete(b.view_refs)
        delete(b.render_pipeline_refs)
        free(b, self.allocator)
    }
    delete(self.reclaim_pool)

    device_impl.fp.DestroyCommandPool(device_impl.vk_device, self.command_pool, nil)
}

@(private = "file")
vk_submit_context_drain_refs :: proc(dst: ^[dynamic]$T, src: ^[dynamic]T) {
    if len(src^) > 0 {
        append(dst, ..src[:])
        assert(len(dst) <= VK_RECLAIM_BATCH_CAP)
        clear(src)
    }
}

// Reclaims finished buffers, oldest first. Holds `mtx` exclusively.
// Sanity bound for pooled batch arrays: one purge reclaims at most
// MAX_COMMAND_BUFFERS buffers, each touching at most a swapchain of images.
VK_RECLAIM_BATCH_CAP :: MAX_COMMAND_BUFFERS * VK_MAX_SWAPCHAIN_IMAGES
VK_Submit_Context_Reclaim_Batch :: struct {
    bind_group_refs:      [dynamic]Bind_Group,
    view_refs:            [dynamic]Texture_View,
    render_pipeline_refs: [dynamic]Render_Pipeline,
}

reclaim_batch_acquire :: proc(self: ^VK_Submit_Context) -> ^VK_Submit_Context_Reclaim_Batch {
    sync.guard(&self.reclaim_pool_mtx)
    if n := len(self.reclaim_pool); n > 0 {
        b := self.reclaim_pool[n - 1]
        resize(&self.reclaim_pool, n - 1)
        return b
    }
    // Cold path: only hit on the first N concurrent callers ever seen.
    b := new(VK_Submit_Context_Reclaim_Batch, self.allocator)
    b.bind_group_refs      = make([dynamic]Bind_Group, 0, self.allocator)
    b.view_refs            = make([dynamic]Texture_View, 0, self.allocator)
    b.render_pipeline_refs = make([dynamic]Render_Pipeline, 0, self.allocator)
    return b
}

// Caller must have already drained/cleared the batch's three arrays
// (release_reclaimed_bind_groups does this) before returning it.
reclaim_batch_release :: proc(self: ^VK_Submit_Context, b: ^VK_Submit_Context_Reclaim_Batch) {
    sync.guard(&self.reclaim_pool_mtx)
    append(&self.reclaim_pool, b)
}

vk_submit_context_purge_locked :: proc(
    self: ^VK_Submit_Context,
    reclaimed: ^VK_Submit_Context_Reclaim_Batch,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    // Track how many buffers we've reclaimed in this pass
    reclaimed_count := 0

    // Scan only in-flight buffers (submitted but not yet known finished)
    for i := 0; i < len(self.in_flight); i += 1 {
        buf := self.in_flight[i]
        if buf == nil {
            // Skip compacted entries
            continue
        }

        // Skip if buffer state is invalid (shouldn't happen for in-flight buffers)
        if buf.vk_cmdbuf == {} || buf.is_active {
            continue
        }

        // Zero-timeout fence check: never blocks under the lock.
        result := device_impl.fp.WaitForFences(device_impl.vk_device, 1, &buf.vk_fence, true, 0)
        if result == .SUCCESS {
            // Buffer finished - reclaim it
            vk_submit_context_drain_refs(
                &reclaimed.bind_group_refs, &buf.tracker.bind_groups.resources)
            vk_submit_context_drain_refs(
                &reclaimed.view_refs, &buf.tracker.views.resources)
            vk_submit_context_drain_refs(
                &reclaimed.render_pipeline_refs, &buf.tracker.render_pipelines.resources)

            vk_command_buffer_reset(buf, loc)
            buf.vk_cmdbuf = {}
            self.available_command_buffers += 1
            sync.cond_signal(&self.buffer_available_cond)

            // Mark for compaction (we'll remove nil entries after the loop)
            self.in_flight[i] = nil
            reclaimed_count += 1
        } else if result == .TIMEOUT {
            // Assuming in-order completion: if this buffer isn't done,
            // subsequent ones won't be either (since submitted later)
            break
        } else {
            vk_check(result, loc = loc)
        }
    }

    // Compact in_flight array by removing nil entries
    if reclaimed_count > 0 {
        write_idx := 0
        for read_idx in 0 ..< len(self.in_flight) {
            if self.in_flight[read_idx] != nil {
                self.in_flight[write_idx] = self.in_flight[read_idx]
                write_idx += 1
            }
        }
        resize(&self.in_flight, write_idx)
    }
}

// Release refs after unlocking; bind-group release takes another lock.
// Cleared backings are parked as spares (one per type) instead of freed.
vk_submit_context_release_reclaimed_bind_groups :: proc(
    reclaimed: ^VK_Submit_Context_Reclaim_Batch,
    loc := #caller_location,
) {
    for bind_group in reclaimed.bind_group_refs {
        vk_bind_group_release(bind_group, loc)
    }
    clear(&reclaimed.bind_group_refs)

    for view in reclaimed.view_refs {
        vk_tracker_texture_view_release(view, loc)
    }
    clear(&reclaimed.view_refs)

    for pipeline in reclaimed.render_pipeline_refs {
        vk_render_pipeline_release(pipeline, loc)
    }
    clear(&reclaimed.render_pipeline_refs)
}

// Cancels an acquired-but-unsubmitted buffer; publishes it idle under `mtx`.
vk_submit_context_cancel_active :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    assert(buf.is_active, loc = loc)

    bind_group_refs := vk_command_buffer_take_bind_group_refs(buf)
    view_refs := vk_command_buffer_take_view_refs(buf)
    render_pipeline_refs := vk_command_buffer_take_render_pipeline_refs(buf)

    // No lock held: cleanup may enter deferred deletion.
    vk_command_buffer_reset(buf, loc)

    for bind_group in bind_group_refs {
        vk_bind_group_release(bind_group, loc)
    }
    delete(bind_group_refs)

    for view in view_refs {
        vk_tracker_texture_view_release(view, loc)
    }
    delete(view_refs)

    for pipeline in render_pipeline_refs {
        vk_render_pipeline_release(pipeline, loc)
    }
    delete(render_pipeline_refs)

    sync.guard(&self.mtx)
    assert(buf.is_active && buf.vk_cmdbuf != {}, loc = loc)
    buf.vk_cmdbuf = {}
    buf.is_active = false
    self.available_command_buffers += 1
    sync.cond_signal(&self.buffer_available_cond)
}

vk_submit_context_purge :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    reclaimed := reclaim_batch_acquire(self)
    defer reclaim_batch_release(self, reclaimed)
    {
        sync.guard(&self.mtx)
        vk_submit_context_purge_locked(self, reclaimed, loc)
    }
    vk_submit_context_release_reclaimed_bind_groups(reclaimed, loc)
}

// Bounds a missed wakeup in acquire; the loop re-checks the predicate anyway.
VK_SUBMIT_ACQUIRE_WAIT_TIMEOUT :: 5 * time.Second

// Claims a slot under the lock, records without it. Only bookkeeping is guarded.
vk_submit_context_acquire :: proc(
    self: ^VK_Submit_Context,
    loc := #caller_location,
) -> ^VK_Command_Buffer_Impl {
    device_impl := vk_device_get_impl(self.device, loc)

    current: ^VK_Command_Buffer_Impl
    reclaimed := reclaim_batch_acquire(self)
    defer reclaim_batch_release(self, reclaimed)

    ACQUIRE_BUFFER: for {
        {
            sync.guard(&self.mtx)

            for &buf in self.buffers {
                if buf.vk_cmdbuf == {} {
                    current = &buf
                    break
                }
            }

            if current == nil {
                // All slots busy; reclaim finished ones.
                vk_submit_context_purge_locked(self, reclaimed, loc)
                for &buf in self.buffers {
                    if buf.vk_cmdbuf == {} {
                        current = &buf
                        break
                    }
                }
            }

            if current != nil {
                assert(current.vk_cmdbuf_allocated != {}, loc = loc)

                current.submit_handle.submit_id = self.submit_counter
                self.available_command_buffers -= 1

                current.vk_cmdbuf = current.vk_cmdbuf_allocated
                // Visible under lock so purge skips it.
                current.is_active = true

                // Lock-free publish; see `vk_submit_handle_pack`.
                sync.atomic_store(
                    &self.next_submit_handle, vk_submit_handle_pack(current.submit_handle))
            }
        }

        vk_submit_context_release_reclaimed_bind_groups(reclaimed, loc)
        if current != nil {
            break
        }

        // No buffer free: wait outside `mtx` so purge/submit can reclaim a
        // slot and signal. The timeout bounds a signal missed between the
        // failed check above and this wait; the loop re-checks regardless,
        // so spurious wakeups are harmless.
        sync.mutex_lock(&self.buffer_available_mtx)
        sync.cond_wait_with_timeout(
            &self.buffer_available_cond,
            &self.buffer_available_mtx,
            VK_SUBMIT_ACQUIRE_WAIT_TIMEOUT,
        )
        sync.mutex_unlock(&self.buffer_available_mtx)
    }

    // Keep the fence signaled until reuse; present may still reference it.
    vk_check(device_impl.fp.ResetFences(
        device_impl.vk_device, 1, &current.vk_fence), loc = loc)

    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = {.ONE_TIME_SUBMIT},
    }
    vk_check(device_impl.fp.BeginCommandBuffer(current.vk_cmdbuf, &begin_info), loc = loc)

    return current
}

// Waits for `handle`. Infinite timeout; recycled generations count as done.
vk_submit_context_wait :: proc(
    self: ^VK_Submit_Context,
    handle: VK_Submit_Handle,
    loc := #caller_location,
) {
    if handle == {} {
        vk_submit_context_device_wait_idle(self, loc)
        return
    }
    vk_submit_context_wait_timeout(self, handle, max(u64), loc)
}

// Bounded wait sharing the caller timeout. Stale generations count as done.
vk_submit_context_wait_timeout :: proc(
    self: ^VK_Submit_Context,
    handle: VK_Submit_Handle,
    timeout_ns: u64,
    loc := #caller_location,
) -> bool {
    if handle == {} {
        return true
    }
    if vk_submit_context_is_ready(self, handle, loc = loc) {
        return true
    }

    // Snapshot the fence, then wait unlocked.
    device_impl := vk_device_get_impl(self.device, loc)
    fence: vk.Fence
    {
        sync.shared_guard(&self.mtx)
        buf := &self.buffers[handle.buffer_index]
        if buf.vk_cmdbuf == {} {
            return true // slot idle, nothing to wait on
        }
        if buf.submit_handle.submit_id != handle.submit_id {
            return true // recycled, original submission already resolved
        }
        if buf.is_active {
            assert(false, "waiting on a buffer still being recorded", loc)
            return true
        }
        fence = buf.vk_fence
    }

    result := device_impl.fp.WaitForFences(
        device_impl.vk_device, 1, &fence, true, timeout_ns)
    if result == .SUCCESS {
        vk_submit_context_purge(self, loc)
        return true
    }
    if result == .TIMEOUT {
        return false
    }
    vk_check(result, loc = loc)
    return false
}

vk_submit_context_wait_all :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    device_impl := vk_device_get_impl(self.device, loc)

    fences: [dynamic;MAX_COMMAND_BUFFERS]vk.Fence
    {
        sync.shared_guard(&self.mtx)
        for &buf in self.buffers {
            if buf.vk_cmdbuf != {} && !buf.is_active {
                append(&fences, buf.vk_fence)
            }
        }
    }
    // Wait outside the lock.
    if len(fences) > 0 {
        vk_check(device_impl.fp.WaitForFences(
            device_impl.vk_device,
            u32(len(fences)),
            raw_data(fences[:]),
            true,
            max(u64)), loc = loc)
    }
    vk_submit_context_purge(self, loc)
}

vk_submit_context_is_ready :: proc "contextless" (
    self: ^VK_Submit_Context,
    handle: VK_Submit_Handle,
    fast_check_no_vulkan := false,
    loc := #caller_location,
) -> bool {
    device_impl := vk_device_get_impl(self.device, loc)

    assert_contextless(handle.buffer_index < MAX_COMMAND_BUFFERS, loc = loc)
    if handle == {} {
        return true
    }

    // Shared lock is enough: read-only slot check.
    sync.shared_guard(&self.mtx)

    buf := &self.buffers[handle.buffer_index]
    if buf.vk_cmdbuf == {} {
        return true // slot idle, nothing to wait on
    }
    if buf.submit_handle.submit_id != handle.submit_id {
        // Newer generation: already resolved.
        return true
    }
    if fast_check_no_vulkan {
        return false
    }

    // Zero timeout: never blocks under lock.
    result := device_impl.fp.WaitForFences(device_impl.vk_device, 1, &buf.vk_fence, true, 0)
    return result == .SUCCESS
}

// DeviceWaitIdle serializes with submit/present; fence waits stay unlocked.
vk_submit_context_device_wait_idle :: proc(
    self: ^VK_Submit_Context,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)
    sync.guard(&self.mtx)
    vk_check(device_impl.fp.DeviceWaitIdle(device_impl.vk_device), loc = loc)
}

vk_submit_context_queue_wait_idle :: proc(
    self: ^VK_Submit_Context,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)
    sync.guard(&self.mtx)
    vk_check(device_impl.fp.QueueWaitIdle(device_impl.submitter.queue), loc = loc)
}

vk_submit_context_get_vk_fence :: proc(
    self: ^VK_Submit_Context,
    handle: VK_Submit_Handle,
) -> vk.Fence {
    if handle == {} {
        return {}
    }
    sync.shared_guard(&self.mtx)
    buf := &self.buffers[handle.buffer_index]
    if buf.vk_cmdbuf == {} {
        return {} // slot idle, nothing to wait on
    }
    if buf.submit_handle.submit_id != handle.submit_id {
        log.debugf("stale submit handle detected: slot=%d requested_id=%d current_id=%d",
            handle.buffer_index, handle.submit_id, buf.submit_handle.submit_id)
        // Newer generation: already resolved.
        return {}
    }
    return buf.vk_fence
}

// Lock-free: reachable inside the submitter lock; locking would self-deadlock.
vk_submit_context_get_next_submit_handle :: proc(self: ^VK_Submit_Context) -> VK_Submit_Handle {
    return vk_submit_handle_unpack(sync.atomic_load(&self.next_submit_handle))
}

vk_submit_context_get_buffer :: #force_inline proc "contextless" (
    self: ^VK_Submit_Context,
    #any_int slot_index: uint,
) -> ^VK_Command_Buffer_Impl  #no_bounds_check {
    return &self.buffers[slot_index]
}

vk_submit_context_submit :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) -> VK_Submit_Handle {
    device_impl := vk_device_get_impl(self.device, loc)

    // Caller owns this buffer between acquire and submit.
    assert(buf.is_active)
    vk_check(device_impl.fp.EndCommandBuffer(buf.vk_cmdbuf), loc = loc)

    // Touched swapchain image
    touches: VK_Swapchain_Touch_List
    vk_surface_scan_swapchain_touches(buf, &touches, loc)

    // Covers QueueSubmit sync, semaphore chain, and pool state. Held across
    // submit so present collects signals only after queuing (VUID-03268).
    sync.guard(&self.mtx)

    // Over-capacity appends drop silently; assert instead of losing a wait/signal.
    assert(len(touches) + 1 <= VK_MAX_SUBMIT_WAITS,
        "too many waits for one submit", loc)
    assert(1 + len(touches) <= VK_MAX_SUBMIT_SIGNALS,
        "too many signal semaphores for one submit", loc)
    wait_semaphores: [dynamic;VK_MAX_SUBMIT_WAITS]vk.Semaphore
    wait_stages:     [dynamic;VK_MAX_SUBMIT_WAITS]vk.PipelineStageFlags
    signal_semaphores: [dynamic;VK_MAX_SUBMIT_SIGNALS]vk.Semaphore

    for touch in touches {
        // First submit per image consumes the acquire wait.
        if sem, ok := vk_surface_take_pending_locked(self, touch, loc); ok {
            append(&wait_semaphores, sem)
            append(&wait_stages, vk.PipelineStageFlags{.ALL_COMMANDS})
        }
        append(&signal_semaphores, vk_surface_present_pool_alloc_locked(
            touch.surface, touch.image, device_impl.fp, loc))
    }
    if self.last_submit_semaphore.semaphore != {} {
        append(&wait_semaphores, self.last_submit_semaphore.semaphore)
        append(&wait_stages, vk.PipelineStageFlags{.ALL_COMMANDS})
    }

    // Chain signal for the next submit.
    append(&signal_semaphores, buf.vk_semaphore)

    cmdbuf := buf.vk_cmdbuf
    submit_info := vk.SubmitInfo {
        sType                = .SUBMIT_INFO,
        waitSemaphoreCount   = u32(len(wait_semaphores)),
        pWaitSemaphores      = raw_data(wait_semaphores[:]),
        pWaitDstStageMask    = raw_data(wait_stages[:]),
        commandBufferCount   = 1,
        pCommandBuffers      = &cmdbuf,
        signalSemaphoreCount = u32(len(signal_semaphores)),
        pSignalSemaphores    = raw_data(signal_semaphores[:]),
    }
    vk_check(device_impl.fp.QueueSubmit(self.queue, 1, &submit_info, buf.vk_fence), loc = loc)
    append(&self.in_flight, buf)

    self.last_submit_semaphore.semaphore = buf.vk_semaphore
    self.last_submit_handle = buf.submit_handle

    buf.is_active = false
    self.submit_counter += 1
    if self.submit_counter == 0 {
        self.submit_counter = 1
    }

    return self.last_submit_handle
}
