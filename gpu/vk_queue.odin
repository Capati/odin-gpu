#+build !js
package gpu

// Core
import "base:intrinsics"
import "base:runtime"
import "core:math"
import "core:mem"
import "core:os"
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
    using base: _Queue_Impl,

    // Vulkan-only: the temporary list names the staging ring's private types.
    deferred_writes: VK_Deferred_Writes,

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
vk_queue_get_internal_impl :: #force_inline proc "contextless" (
    queue: Queue,
    loc := #caller_location,
) -> ^_Queue_Impl {
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
    device_impl.fp.GetDeviceQueue(device_impl.vk_device, family_index, 0, &self.graphics_queue)
    // Recorded for future queue-family ownership transfers.
    self.graphics_family_index = family_index
    vk_deferred_writes_init(&self.deferred_writes, device, device_impl.allocator, loc)
}

vk_queue_uninit :: proc(self: ^VK_Queue_Default_Impl) {
    vk_deferred_writes_uinit(&self.deferred_writes)
}

// Drops writes recorded but never submitted, before the device starts tearing
// down. The scratch encoder and staging buffers are released through the normal
// deferred path, which still has a live submit context and deletion queue.
vk_queue_abandon_pending_writes :: proc(self: ^VK_Queue_Default_Impl, loc := #caller_location) {
    if self.deferred_writes.active != nil {
        batch := self.deferred_writes.active
        if batch.encoder != {} {
            vk_command_encoder_release(batch.encoder)
            batch.encoder = {}
        }

        // Nothing will record these writes, so drop the destination holds.
        for buffer in batch.buffers {
            if buffer == {} {
                continue
            }
            vk_buffer_release(buffer, loc)
        }
        clear(&batch.buffers)
        clear(&batch.buffer_bits)
        for texture in batch.textures {
            if texture == {} {
                continue
            }
            vk_texture_release(texture, loc)
        }
        clear(&batch.textures)
        clear(&batch.texture_bits)

        for &entry in batch.temp {
            switch t in entry {
            case Flushed_Staging_Buffer:
                // Never submitted, so there is nothing to wait on: destroy it
                // through the deferred deleter's body directly.
                impl := vk_buffer_get_impl(t.buffer, loc)
                device_impl := vk_device_get_impl(impl.device, loc)
                res := VK_Deferred_Buffer {
                    buffer         = impl.vk_buffer,
                    tracker_index  = impl.tracker_index,
                    vma_allocation = impl.vma_allocation,
                    gpu_allocation = impl.gpu_allocation,
                    init           = impl.init,
                }
                vk_deferred_destroy_buffer(&device_impl.deferred, &res, loc)
                vk_label_remove(&device_impl.labels, .Buffer, pack_handle(impl.handle))
                remove_handle_impl(&device_impl.buffers, impl.handle)
            case VK_Staging_Reclaim:
            // The copy never runs; `vk_staging_uninit` destroys the rings.
            }
        }
        clear(&batch.temp)
    }
    self.deferred_writes.flushing = nil
}

vk_queue_on_submitted_work_done :: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    // Host writes are queue work too: flush them first so the future covers
    // them, instead of resolving at the last submission made before the writes
    // were recorded.
    _ = vk_queue_flush_pending_writes(impl.device, loc)
    submitter := &device_impl.submitter

    // Everything already queued resolves at the last submission value.
    target: u64
    completed: u64
    {
        sync.shared_guard(&submitter.mtx)
        if submitter.next_submission_value > 1 {
            target = submitter.next_submission_value - 1
        }
        completed = vk_fence_get_value(&submitter.submission_fence, loc)
    }

    if target == 0 || target <= completed {
        if callback_info.callback != nil {
            callback_info.callback(.Success, "", callback_info.userdata1, callback_info.userdata2)
        }
        return {}
    }

    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
    instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)
    id := intrinsics.atomic_add(&instance_impl.current_future_id, 1)
    {
        sync.guard(&instance_impl.future_mtx)
        instance_impl.pending_futures[id] = {
            resolve = vk_queue_work_done_resolve,
            wait = vk_queue_work_done_wait,
            userdata = Future_Data_For_Work_Done {
                device        = impl.device,
                value         = target,
                callback_info = callback_info,
            },
            poll = true,
            ready = false,
        }
    }

    sync.guard(&submitter.mtx)
    append(&submitter.work_done, VK_Work_Done_Entry{value = target, future_id = id})
    return {id = id}
}

VK_Work_Done_Entry :: struct {
    value:     u64,
    future_id: u64,
}

vk_queue_work_done_resolve :: proc(userdata: Future_Data) {
    #partial switch data in userdata {
    case Future_Data_For_Work_Done:
        if data.callback_info.callback != nil {
            data.callback_info.callback(
                .Success,
                "",
                data.callback_info.userdata1,
                data.callback_info.userdata2,
            )
        }
    case:
        unreachable()
    }
}

vk_queue_work_done_wait :: proc(userdata: Future_Data, timeout_ns: u64) -> bool {
    #partial switch data in userdata {
    case Future_Data_For_Work_Done:
        device_impl := vk_device_get_impl(data.device)
        if vk_fence_wait_value(
            &device_impl.submitter.submission_fence,
            data.value,
            timeout_ns,
            &device_impl.submitter.mtx,
        ) {
            vk_submit_context_purge(&device_impl.submitter)
            return true
        }
    }
    return false
}

vk_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Queue, pack_handle(impl.handle))
}

vk_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Queue, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(
        device_impl.fp,
        .QUEUE,
        uintptr(device_impl.queue.graphics_queue),
        label,
        loc,
    )
}

@(require_results)
vk_queue_get_timestamp_period :: proc(queue: Queue, loc := #caller_location) -> f32 {
    impl := vk_queue_get_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
    return adapter_impl.vk_properties.limits.timestampPeriod
}

vk_queue_get_native_metal_command_queue :: proc(queue: Queue, loc := #caller_location) -> rawptr {
    return nil
}

vk_pending_writes_flush :: proc(
    pw: ^VK_Deferred_Writes,
    device: Device,
    loc := #caller_location,
) -> VK_Submit_Handle {
    // Serialize the detach -> submit -> drain window. Queue writes do not take
    // this lock, so recording overlaps the previous flush.
    sync.guard(&pw.flush_mtx)

    batch, pending := vk_deferred_writes_take_batch(pw, loc)
    if !pending {
        return {}
    }
    defer vk_deferred_writes_recycle_batch(pw, batch, loc)

    device_impl := vk_device_get_impl(device, loc)
    encoder_impl := vk_command_encoder_get_impl(batch.encoder, loc)

    // A queue write to a swapchain image still has to wait on its acquire and
    // signal the present pool. The batch's texture array is the only place that
    // knows which images it touched, because the scratch encoder records raw
    // transitions without a command-buffer tracker.
    extra_touches: VK_Swapchain_Touch_List
    for texture in batch.textures {
        if texture == {} ||
           !dhm_is_valid(&device_impl.textures, unpack_handle(VK_Texture_Handle, texture.handle)) {
            continue
        }
        texture_impl := vk_texture_get_impl(texture, loc)
        if !texture_impl.is_swapchain {
            continue
        }
        touch := VK_Swapchain_Touch {
            surface = texture_impl.surface,
            image   = texture_impl.swapchain_index,
        }
        duplicate := false
        for existing in extra_touches {
            if existing == touch {
                duplicate = true
                break
            }
        }
        if !duplicate {
            append(&extra_touches, touch)
        }
    }

    // The deferred encoder accumulates raw copy/transition commands; issue them
    // now, before the buffer is closed and submitted.
    vk_execute_pending(device, encoder_impl.cmdbuf, loc)

    // Claimed from the submit context and detached, so recording is single-owner.
    handle := vk_submit_context_submit_extra(
        &device_impl.submitter,
        encoder_impl.cmdbuf,
        extra_touches[:],
        loc,
    )

    // The submission resolved every destination handle. Dropping the refs pins
    // the deferred destroy to this submission. The destination arrays stay
    // populated until `recycle_batch`, so `contains_buffer` keeps refusing
    // direct host writes until the flush has fully submitted.
    if handle != {} {
        for buffer in batch.buffers {
            if buffer == {} {
                continue
            }
            vk_buffer_release_after(buffer, handle, loc)
        }
        for texture in batch.textures {
            if texture == {} {
                continue
            }
            vk_texture_release_after(texture, handle, loc)
        }
    } else {
        for buffer in batch.buffers {
            if buffer == {} {
                continue
            }
            vk_buffer_release(buffer, loc)
        }
        for texture in batch.textures {
            if texture == {} {
                continue
            }
            vk_texture_release(texture, loc)
        }
    }

    // Staging reservations are promoted with the submission value that actually
    // consumes them. Flushed staging buffers are released after the submit.
    if handle != {} {
        submit_value := encoder_impl.cmdbuf.submit_value
        sync.lock(&device_impl.staging_mtx)
        for entry in batch.temp {
            switch t in entry {
            case VK_Staging_Reclaim:
                append(&device_impl.staging_reclaims, VK_Staging_Reclaim {
                    value   = submit_value,
                    ring    = t.ring,
                    abs_end = t.abs_end,
                })
            case Flushed_Staging_Buffer:
            }
        }
        sync.unlock(&device_impl.staging_mtx)
    }
    for entry in batch.temp {
        switch t in entry {
        case Flushed_Staging_Buffer:
            vk_buffer_release(t.buffer, loc)
        case VK_Staging_Reclaim:
        }
    }
    clear(&batch.temp)

    encoder_impl.is_encoding = false
    vk_command_encoder_release(batch.encoder, loc)
    batch.encoder = {}
    return handle
}

// Flushes every recorded host write. Returns the submission handle, or an empty
// handle when nothing was recorded.
@(require_results)
vk_queue_flush_pending_writes :: proc(
    device: Device,
    loc := #caller_location,
) -> VK_Submit_Handle {
    device_impl := vk_device_get_impl(device, loc)
    return vk_pending_writes_flush(&device_impl.queue.deferred_writes, device, loc)
}

// Flushes the pending batch only when it contains a write to `buffer`. The whole
// batch is submitted, not just the matching write: there is a single encoder.
@(require_results)
vk_queue_flush_writes_for_buffer :: proc(
    device: Device,
    buffer: Buffer,
    loc := #caller_location,
) -> (
    handle: VK_Submit_Handle,
    flushed: bool,
) {
    device_impl := vk_device_get_impl(device, loc)
    if !vk_deferred_writes_contains_buffer(&device_impl.queue.deferred_writes, buffer) {
        return {}, false
    }
    return vk_pending_writes_flush(&device_impl.queue.deferred_writes, device, loc), true
}

vk_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    _ = vk_queue_submit_impl(queue, commands, loc)
}

vk_queue_submit_for_index :: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index {
    return vk_queue_submit_impl(queue, commands, loc)
}

// Claims the one allowed submission for `buf`. Returns false if another thread
// already claimed it. The flag stays set even if submission later fails, which
// is WebGPU's invalidation rule.
vk_submit_context_mark_submitted :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
) -> bool {
    sync.guard(&self.mtx)
    if buf.submitted {
        return false
    }
    buf.submitted = true
    return true
}

vk_queue_submit_impl :: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index {
    impl := vk_queue_get_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    last := vk_pending_writes_flush(&device_impl.queue.deferred_writes, impl.device, loc)

    valid := true
    // Fast duplicate detection for one submission. A submission rarely lists
    // more than a couple of buffers, so an inline open-addressed set covers it
    // with no allocation; larger lists fall back to a linear scan below.
    VK_INLINE_SUBMIT_CMDBUFS :: 64
    seen_slots: [VK_INLINE_SUBMIT_CMDBUFS]u64
    // Strictly less, so the open-addressed table always has a free slot.
    seen_inline := len(commands) < VK_INLINE_SUBMIT_CMDBUFS
    for cmdbuf, index in commands {
        if cmdbuf == {} {
            gpu_report_validation_error(
                impl.device,
                "submit contains an invalid command buffer",
                loc,
            )
            valid = false
            continue
        }
        if cmdbuf.device != impl.device {
            gpu_report_validation_error(
                impl.device,
                "submitted command buffer belongs to another device",
                loc,
            )
            valid = false
        }
        // Duplicate check: open addressing for the common small submission,
        // linear scan for the rare oversized one.
        duplicate := false
        if seen_inline {
            mask := u64(VK_INLINE_SUBMIT_CMDBUFS - 1)
            key := cmdbuf.handle
            slot := int(key & mask)
            for {
                if seen_slots[slot] == 0 {
                    seen_slots[slot] = key
                    break
                }
                if seen_slots[slot] == key {
                    duplicate = true
                    break
                }
                slot = (slot + 1) & int(mask)
            }
        } else {
            for prior in commands[:index] {
                if prior == cmdbuf {
                    duplicate = true
                    break
                }
            }
        }
        if duplicate {
            gpu_report_validation_error(
                impl.device,
                "submit lists the same command buffer twice",
                loc,
            )
            valid = false
        }
        if !dhm_is_valid(
            &device_impl.command_buffers,
            unpack_handle(VK_Command_Buffer_Handle, cmdbuf.handle),
        ) {
            gpu_report_validation_error(
                impl.device,
                "submit contains an invalid command buffer",
                loc,
            )
            valid = false
            continue
        }
        // The handle may be old enough that its slot was purged and reused.
        if !vk_command_buffer_is_current(cmdbuf, loc) {
            gpu_report_validation_error(
                impl.device,
                "command buffer has already been submitted",
                loc,
            )
            valid = false
            continue
        }
        cmdbuf_impl := vk_command_buffer_get_impl(cmdbuf, loc)
        if !vk_submit_context_mark_submitted(&device_impl.submitter, cmdbuf_impl) {
            gpu_report_validation_error(
                impl.device,
                "command buffer has already been submitted",
                loc,
            )
            valid = false
        }
    }

    live := true
    for cmdbuf in commands {
        if cmdbuf == {} {
            continue
        }
        if !dhm_is_valid(
            &device_impl.command_buffers,
            unpack_handle(VK_Command_Buffer_Handle, cmdbuf.handle),
        ) {
            continue
        }
        if !vk_command_buffer_is_current(cmdbuf, loc) {
            continue
        }
        cmdbuf_impl := vk_command_buffer_get_impl(cmdbuf, loc)
        live = vk_command_buffer_resources_live(cmdbuf_impl, loc) && live
    }
    if !valid || !live {
        // A refused submission records nothing, but the command buffer still
        // owns the refs it took while recording. Drop them here so a caller that
        // releases the buffer does not leak bind groups, views or pipelines.
        for cmdbuf in commands {
            if cmdbuf == {} {
                continue
            }
            if !dhm_is_valid(
                &device_impl.command_buffers,
                unpack_handle(VK_Command_Buffer_Handle, cmdbuf.handle),
            ) {
                continue
            }
            if !vk_command_buffer_is_current(cmdbuf, loc) {
                continue
            }
            cmdbuf_impl := vk_command_buffer_get_impl(cmdbuf, loc)
            groups := vk_command_buffer_take_bind_group_refs(cmdbuf_impl)
            for group in groups {
                vk_bind_group_release(group, loc)
            }
            delete(groups)
            views := vk_command_buffer_take_view_refs(cmdbuf_impl)
            for view in views {
                vk_texture_view_release(view, loc)
            }
            delete(views)
            pipelines := vk_command_buffer_take_render_pipeline_refs(cmdbuf_impl)
            for pipeline in pipelines {
                vk_render_pipeline_release(pipeline, loc)
            }
            delete(pipelines)
            bundles := vk_command_buffer_take_bundle_refs(cmdbuf_impl)
            for bundle in bundles {
                vk_render_bundle_release(bundle, loc)
            }
            delete(bundles)
        }
        return Submission_Index(vk_submit_handle_pack(last))
    }

    for cmdbuf in commands {
        if cmdbuf == {} {
            continue
        }
        cmdbuf_impl := vk_command_buffer_get_impl(cmdbuf, loc)
        last = vk_submit_context_submit(&device_impl.submitter, cmdbuf_impl, loc)
        cmdbuf_impl.submitted = true
    }

    vk_deferred_process(&device_impl.deferred, &device_impl.submitter, loc)
    return Submission_Index(vk_submit_handle_pack(last))
}

// Validate a host texture write. Unlike the copy commands, writes have no
// block-size offset alignment and no 256-byte row-pitch requirement; the layout
// is still bounded by the data length and the texture's subresources.
vk_queue_write_texture_validate :: proc(
    device_impl: ^VK_Device_Impl,
    texture_impl: ^VK_Texture_Impl,
    destination: Texel_Copy_Texture_Info,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    data_len: int,
    loc := #caller_location,
) -> bool {
    device := Device(device_impl)
    valid := gpu_validate(
        device,
        destination.texture.device == device,
        "write texture belongs to another device",
        loc,
    )
    valid &= gpu_validate(device, !texture_impl.destroyed, "write texture has been destroyed", loc)
    valid &= gpu_validate(
        device,
        .Copy_Dst in texture_impl.public_usage,
        "write texture requires the [Copy_Dst] usage",
        loc,
    )
    valid &= gpu_validate(
        device,
        texture_impl.sample_count == 1,
        "multisampled textures cannot be written from the host",
        loc,
    )
    valid &= gpu_validate(
        device,
        destination.mip_level < texture_impl.num_levels,
        "write mip level is out of bounds",
        loc,
    )

    aspect_ok := texture_format_depth_stencil_copy_supported(
        texture_impl.format,
        destination.aspect,
        true,
    )
    #partial switch destination.aspect {
    case .Plane0, .Plane1, .Plane2:
        aspect_ok = true
    case:
    }
    valid &= gpu_validate(
        device,
        aspect_ok,
        "write aspect is not valid for the texture format",
        loc,
    )
    if !valid {
        return false
    }

    mip_width := max(u32(1), u32(texture_impl.vk_extent.width) >> destination.mip_level)
    mip_height := max(u32(1), u32(texture_impl.vk_extent.height) >> destination.mip_level)
    mip_depth := max(u32(1), u32(texture_impl.vk_extent.depth) >> destination.mip_level)

    valid &= gpu_validate(
        device,
        destination.origin.x + write_size.width <= mip_width &&
        destination.origin.y + write_size.height <= mip_height,
        "write rectangle is out of bounds",
        loc,
    )
    if texture_impl.dimension == .D3 {
        valid &= gpu_validate(
            device,
            destination.origin.z + write_size.depth_or_array_layers <= mip_depth,
            "write depth is out of bounds",
            loc,
        )
    } else {
        valid &= gpu_validate(
            device,
            destination.origin.z + write_size.depth_or_array_layers <= texture_impl.num_layers,
            "write layers are out of bounds",
            loc,
        )
    }

    block_width, block_height := texture_format_block_dimensions(texture_impl.format)
    block_size := texture_format_block_copy_size(texture_impl.format, destination.aspect)
    width_blocks := u64((write_size.width + block_width - 1) / block_width)
    height_blocks := u64((write_size.height + block_height - 1) / block_height)
    layers := u64(write_size.depth_or_array_layers)
    bytes_in_last_row := width_blocks * u64(block_size)

    if texture_format_is_compressed(texture_impl.format) {
        valid &= gpu_validate(
            device,
            destination.origin.x % block_width == 0 &&
            destination.origin.y % block_height == 0 &&
            write_size.width % block_width == 0 &&
            write_size.height % block_height == 0,
            "compressed write rectangle must be block aligned",
            loc,
        )
    }

    offset := u64(data_layout.offset)
    valid &= gpu_validate(
        device,
        offset <= u64(data_len),
        "write data offset is out of bounds",
        loc,
    )

    defined_pitch :=
        data_layout.bytes_per_row != 0 && data_layout.bytes_per_row != COPY_STRIDE_UNDEFINED
    defined_rows :=
        data_layout.rows_per_image != 0 && data_layout.rows_per_image != COPY_STRIDE_UNDEFINED

    bytes_per_row := u64(data_layout.bytes_per_row)
    if !defined_pitch {
        valid &= gpu_validate(
            device,
            height_blocks <= 1 && layers <= 1,
            "write bytesPerRow is required for a multi-row or multi-layer write",
            loc,
        )
        bytes_per_row = bytes_in_last_row
    } else {
        valid &= gpu_validate(
            device,
            bytes_per_row >= bytes_in_last_row,
            "write bytesPerRow is smaller than a row",
            loc,
        )
    }

    rows_per_image := u64(data_layout.rows_per_image)
    if !defined_rows {
        valid &= gpu_validate(
            device,
            layers <= 1,
            "write rowsPerImage is required for a multi-image write",
            loc,
        )
        rows_per_image = height_blocks
    } else {
        valid &= gpu_validate(
            device,
            rows_per_image >= height_blocks,
            "write rowsPerImage is smaller than the write height",
            loc,
        )
    }

    if valid {
        required := u128(offset)
        if layers > 1 {
            required += u128(bytes_per_row) * u128(rows_per_image) * u128(layers - 1)
        }
        if height_blocks > 1 {
            required += u128(bytes_per_row) * u128(height_blocks - 1)
        }
        required += u128(bytes_in_last_row)
        valid &= gpu_validate(
            device,
            required <= u128(data_len),
            "write data is too small for the layout",
            loc,
        )
    }

    return valid
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
    texture_impl := dhm_get_if_valid(
        &device_impl.textures,
        unpack_handle(VK_Texture_Handle, destination.texture.handle),
    )
    if texture_impl == nil {
        gpu_report_validation_error(impl.device, "write texture is not a live texture", loc)
        return
    }

    if !vk_queue_write_texture_validate(
        device_impl,
        texture_impl,
        destination,
        data_layout,
        write_size,
        len(data),
        loc,
    ) {
        return
    }

    if write_size.width == 0 || write_size.height == 0 || write_size.depth_or_array_layers == 0 {
        return
    }

    // 3D textures pack depth slices in one layer; layers count slices here.
    is_3d := texture_impl.dimension == .D3

    block_width, block_height := texture_format_block_dimensions(texture_impl.format)
    width_in_blocks := write_size.width / block_width
    height_in_blocks := write_size.height / block_height

    block_size := texture_format_block_copy_size(texture_impl.format, destination.aspect)
    bytes_in_last_row := width_in_blocks * block_size

    bytes_per_row := data_layout.bytes_per_row
    if bytes_per_row == 0 || bytes_per_row == COPY_STRIDE_UNDEFINED {
        bytes_per_row = bytes_in_last_row
    }

    rows_per_image := data_layout.rows_per_image
    if rows_per_image == 0 || rows_per_image == COPY_STRIDE_UNDEFINED {
        rows_per_image = height_in_blocks
    }

    // Staging row pitch must align to block size and driver pitch.
    pitch_alignment := math.lcm(
        max(u64(1), device_impl.alignments.buffer_copy_pitch),
        max(u64(1), u64(block_size)),
    )
    stage_bytes_per_row := u32(
        mem.align_forward_uint(uint(bytes_in_last_row), uint(pitch_alignment)),
    )

    // 3D uses one array layer with N slices; 2D arrays copy per layer.
    staging_slice_count := write_size.depth_or_array_layers
    array_layer_count := is_3d ? 1 : staging_slice_count

    stage_size := u64(stage_bytes_per_row) * u64(rows_per_image) * u64(staging_slice_count)

    reservation, reserved := vk_staging_reserve(device_impl, stage_size, u64(block_size), loc)
    ensure(reserved, "failed to reserve staging for texture write", loc)

    if stage_bytes_per_row == bytes_per_row {
        // Rows already pitched: bulk copy, padding untouched. Fail loud on
        // short input instead of copying a prefix over a stale tail.
        ensure(int(data_layout.offset) + int(stage_size) <= len(data), loc = loc)
        vk_staging_write(reservation, raw_data(data), data_layout.offset, 0, stage_size, loc)
    } else {
        // Repack rows with padding.
        for slice in 0 ..< u64(staging_slice_count) {
            rows_offset := slice * u64(rows_per_image)
            for row in rows_offset ..< (rows_offset + u64(height_in_blocks)) {
                src_offset := data_layout.offset + row * u64(bytes_per_row)
                dst_offset := row * u64(stage_bytes_per_row)
                vk_staging_write(
                    reservation,
                    raw_data(data),
                    src_offset,
                    dst_offset,
                    u64(bytes_in_last_row),
                    loc,
                )
            }
        }
    }
    vk_staging_flush(reservation, loc)

    deferred_writes := &device_impl.queue.deferred_writes

    // One scratch encoder: hold the lock while recording so concurrent
    // writes/unmaps can't interleave. Order: VK_Deferred_Writes -> device tracker.
    sync.guard(&deferred_writes.mtx)

    encoder := vk_deferred_writes_activate_locked(deferred_writes, loc)
    encoder_impl := vk_command_encoder_get_impl(encoder, loc)

    vk_deferred_writes_ring_ready_locked(deferred_writes, reservation.ring)

    // Move destination to `Copy_Dst`, one barrier per part.
    base_layer := is_3d ? 0 : destination.origin.z
    selector := Texture_Selector {
        mip_start   = destination.mip_level,
        mip_count   = 1,
        layer_start = base_layer,
        layer_count = array_layer_count,
    }

    transitions: [dynamic]Texture_State_Transition
    transitions.allocator = _command_encoder_arena_allocator(encoder, loc)
    {
        sync.guard(&device_impl.trackers_mtx)
        device_texture_tracker_set_single(
            &device_impl.trackers.textures,
            vk_tracked_texture(destination.texture, vk_texture_get_impl(destination.texture, loc)),
            selector,
            {.Copy_Dst},
            &transitions,
        )
    }

    for &transition in transitions {
        cmd := command_allocator_allocate(
            &encoder_impl.cmdbuf.commands,
            Transition_Texture_Cmd,
            loc,
        )
        cmd.texture = transition.texture
        cmd.selector = Image_Subresource_Range {
            aspect            = destination.aspect,
            base_mip_level    = transition.selector.mip_start,
            mip_level_count   = transition.selector.mip_count,
            base_array_layer  = transition.selector.layer_start,
            array_layer_count = transition.selector.layer_count,
        }
        // `from` is the tracker state when `set_single` ran; don't re-read at record time.
        cmd.state_from = transition.from
        cmd.state_to = transition.to
        cmd.force_barrier = transition.from != TEXTURE_USES_UNKNOWN
    }

    // One region covers all layers: contiguous from base_layer with identical
    // extents, and the explicit row pitch/height stride matches Vulkan's
    // per-layer offset rule. 3D keeps depth slices in a single layer.
    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands,
        Copy_Buffer_To_Texture_Cmd,
        loc,
    )
    cmd.src = Texel_Copy_Buffer_Info {
        buffer = reservation.ring.buffer,
        layout = {
            offset         = reservation.offset,
            bytes_per_row  = stage_bytes_per_row,
            rows_per_image = rows_per_image,
        },
    }
    layer_dst := destination
    if !is_3d {
        layer_dst.origin.z = base_layer
    }
    cmd.dst = layer_dst
    cmd.size = Extent_3D {
        width                 = write_size.width,
        height                = write_size.height,
        depth_or_array_layers = is_3d ? write_size.depth_or_array_layers : array_layer_count,
    }

    vk_deferred_writes_insert_texture_locked(deferred_writes, destination.texture)
    vk_deferred_writes_defer_staging_locked(deferred_writes, reservation)
}

// Writes a buffer through CPU access when that is safely observable:
// host-visible and persistently mapped, with no pending write to this buffer
// and no submission in flight. Returns false when the caller must stage.
vk_queue_try_write_buffer_host_visible :: proc(
    device_impl: ^VK_Device_Impl,
    buffer: Buffer,
    buffer_impl: ^VK_Buffer_Impl,
    offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> bool {
    if .HOST_VISIBLE not_in buffer_impl.vk_mem_flags {
        return false
    }
    if vk_deferred_writes_contains_buffer(&device_impl.queue.deferred_writes, buffer) {
        return false
    }
    // Direct CPU writes must not race a submission that can still read the
    // buffer. Buffer-specific submission tracking would be more precise;
    // requiring an idle queue is the conservative version.
    if !vk_submit_context_is_ready(
        &device_impl.submitter,
        device_impl.submitter.last_submit_handle,
    ) {
        return false
    }

    temporary_map := buffer_impl.mapped_ptr == nil
    mapped := buffer_impl.mapped_ptr
    if temporary_map {
        mapped = vk_buffer_map_sync(buffer, .Write, 0, WHOLE_MAP_SIZE, loc)
    }

    destination := rawptr(uintptr(mapped) + uintptr(offset))
    mem.copy(destination, data, int(size))
    if temporary_map {
        // Unmap flushes non-coherent mappings over the whole allocation.
        vk_buffer_unmap(buffer, loc)
    } else if !buffer_impl.is_coherent {
        vk_buffer_flush_mapped_ranges(buffer, uint(offset), size, loc)
    }
    buffer_init_tracker_mark_initialized(&buffer_impl.init, offset, offset + u64(size))
    return true
}

vk_queue_write_buffer_raw :: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    impl := vk_queue_get_impl(queue, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    if buffer == {} ||
       !dhm_is_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle)) {
        gpu_report_validation_error(impl.device, "write buffer is not a live buffer", loc)
        return
    }
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    if buffer.device != impl.device {
        gpu_report_validation_error(impl.device, "write buffer belongs to another device", loc)
        return
    }
    if buffer_impl.destroyed {
        gpu_report_validation_error(impl.device, "write buffer has been destroyed", loc)
        return
    }
    if .Copy_Dst not_in buffer_impl.public_usage {
        gpu_report_validation_error(impl.device, "write buffer requires the [Copy_Dst] usage", loc)
        return
    }
    if !vk_buffer_is_unmapped(buffer_impl) {
        gpu_report_validation_error(impl.device, "cannot write a mapped buffer", loc)
        return
    }
    if offset % 4 != 0 || u64(size) % 4 != 0 {
        gpu_report_validation_error(
            impl.device,
            "write_buffer offset and size must be 4-byte aligned",
            loc,
        )
        return
    }
    if offset > buffer_impl.visible_size || u64(size) > buffer_impl.visible_size - offset {
        gpu_report_validation_error(impl.device, "write_buffer range is out of bounds", loc)
        return
    }
    if size == 0 {
        return
    }

    if vk_queue_try_write_buffer_host_visible(
        device_impl,
        buffer,
        buffer_impl,
        offset,
        data,
        size,
        loc,
    ) {
        return
    }

    reservation, reserved := vk_staging_reserve(device_impl, u64(size), 4, loc)
    ensure(reserved, "failed to reserve staging for buffer write", loc)
    vk_staging_write(reservation, data, 0, 0, u64(size), loc)
    vk_staging_flush(reservation, loc)

    deferred_writes := &device_impl.queue.deferred_writes
    sync.guard(&deferred_writes.mtx)

    encoder := vk_deferred_writes_activate_locked(deferred_writes, loc)
    vk_deferred_writes_ring_ready_locked(deferred_writes, reservation.ring)
    vk_command_encoder_copy_buffer_internal(
        encoder,
        reservation.ring.buffer,
        reservation.offset,
        buffer,
        offset,
        u64(size),
        loc,
    )
    vk_deferred_writes_insert_buffer_locked(deferred_writes, buffer)
    vk_deferred_writes_defer_staging_locked(deferred_writes, reservation)
}

vk_device_poll :: proc(
    device: Device,
    wait: bool,
    submission_index: ^Submission_Index,
    loc := #caller_location,
) -> bool {
    impl := vk_device_get_impl(device, loc)
    submitter := &impl.submitter

    if submission_index != nil && submission_index^ != 0 {
        handle := vk_submit_handle_unpack(u64(submission_index^))
        if wait {
            return vk_submit_context_wait_timeout(submitter, handle, max(u64), loc)
        }
        return vk_submit_context_is_ready(submitter, handle, loc = loc)
    }

    if wait {
        vk_submit_context_wait_all(submitter, loc)
        return true
    }

    vk_submit_context_purge(submitter, loc)
    return vk_submit_context_is_ready(submitter, submitter.last_submit_handle, loc = loc)
}

vk_device_get_native_metal_device :: proc(device: Device, loc := #caller_location) -> rawptr {
    return nil
}

vk_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    add_ref(impl, loc)
}

vk_queue_release :: proc(queue: Queue, loc := #caller_location) {
    impl := vk_queue_get_wrapper_impl(queue, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_label_remove(&device_impl.labels, .Queue, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.queues, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// Submission fence
// -----------------------------------------------------------------------------

// Which arm a submission fence uses: one device-wide timeline semaphore whose
// counter is the submission value, or the per-submission `VkFence` slots (the
// Vulkan 1.0 fallback, still what slot reclamation uses today).
VK_Fence_Kind :: enum {
    Timeline_Semaphore,
    Fence_Pool,
}

VK_Fence :: struct {
    device:               Device,
    kind:                 VK_Fence_Kind,
    timeline:             vk.Semaphore,
    use_khr_entry_points: bool,
    last_completed:       u64,

    // FENCE_POOL arm.
    all_fences:   [dynamic]^VK_Fence_Pool_Fence,
    active:       [dynamic]VK_Fence_Entry,
    free_fences:  [dynamic]^VK_Fence_Pool_Fence,
    // Reset batch, reused across maintenance passes.
    reset_fences: [dynamic]vk.Fence,
}

VK_Fence_Pool_Fence :: struct {
    vk_fence: vk.Fence,
}

VK_Fence_Entry :: struct {
    fence: ^VK_Fence_Pool_Fence,
    value: u64,
}

vk_fence_pool_create :: proc(
    device_impl: ^VK_Device_Impl,
    loc := #caller_location,
) -> ^VK_Fence_Pool_Fence {
    fence := new(VK_Fence_Pool_Fence, device_impl.allocator)
    create_info := vk.FenceCreateInfo {
        sType = .FENCE_CREATE_INFO,
    }
    vk_check(
        device_impl.fp.CreateFence(device_impl.vk_device, &create_info, nil, &fence.vk_fence),
        loc = loc,
    )
    return fence
}

vk_fence_select_kind :: proc(device: Device, loc := #caller_location) -> VK_Fence_Kind {
    device_impl := vk_device_get_impl(device, loc)
    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)

    if !adapter_impl.caps.timeline_semaphores ||
       adapter_impl.vk_properties.apiVersion < vk.API_VERSION_1_2 {
        return .Fence_Pool
    }
    // Dev-only overrides so both arms can be exercised.
    if _, forced := os.lookup_env("VK_GPU_FORCE_FENCE_POOL", context.allocator); forced {
        return .Fence_Pool
    }
    return .Timeline_Semaphore
}

vk_fence_init :: proc(
    self: ^VK_Fence,
    device: Device,
    kind: VK_Fence_Kind,
    loc := #caller_location,
) {
    self.device = device
    self.kind = kind

    device_impl := vk_device_get_impl(device, loc)
    self.all_fences.allocator = device_impl.allocator
    self.active.allocator = device_impl.allocator
    self.free_fences.allocator = device_impl.allocator
    self.reset_fences.allocator = device_impl.allocator
    reserve(&self.all_fences, 4)
    reserve(&self.active, 4)
    reserve(&self.reset_fences, 16)

    if kind != .Timeline_Semaphore {
        // Pre-create the common in-flight depth so the first frames do not pay
        // `new` + `vkCreateFence` per submission. Deeper pipelines grow the
        // pool in `vk_fence_arm_submission`.
        for _ in 0 ..< 4 {
            fence := vk_fence_pool_create(device_impl, loc)
            append(&self.all_fences, fence)
            append(&self.free_fences, fence)
        }
        return
    }

    // The counter starts at 0 and only counts up: submission N signals N and
    // nothing resets it.
    type_info := vk.SemaphoreTypeCreateInfo {
        sType         = .SEMAPHORE_TYPE_CREATE_INFO,
        semaphoreType = .TIMELINE,
        initialValue  = 0,
    }
    create_info := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
        pNext = &type_info,
    }
    vk_check(
        device_impl.fp.CreateSemaphore(device_impl.vk_device, &create_info, nil, &self.timeline),
        loc = loc,
    )
}

// Arm `value` for the submission being built. The timeline arm signals its
// semaphore; the pool arm hands back a recycled-or-new `VkFence`.
vk_fence_arm_submission :: proc(
    self: ^VK_Fence,
    value: u64,
    signal_semaphores: ^VK_Semaphore_List,
    loc := #caller_location,
) -> vk.Fence {
    if self.kind == .Timeline_Semaphore {
        vk_semaphore_list_push_signal(signal_semaphores, self.timeline, value)
        return {}
    }

    device_impl := vk_device_get_impl(self.device, loc)

    fence: ^VK_Fence_Pool_Fence
    if len(self.free_fences) > 0 {
        fence = self.free_fences[len(self.free_fences) - 1]
        resize(&self.free_fences, len(self.free_fences) - 1)
    } else {
        fence = vk_fence_pool_create(device_impl, loc)
        append(&self.all_fences, fence)
    }

    append(&self.active, VK_Fence_Entry{fence = fence, value = value})
    return fence.vk_fence
}

// The highest submission value known to have completed agree. A non-success
// answer means the device is gone; every outstanding submission then counts as
// complete, which is what Vulkan declares on loss.
vk_fence_get_value :: proc "contextless" (self: ^VK_Fence, loc := #caller_location) -> u64 {
    device_impl := vk_device_get_impl(self.device, loc)

    if self.kind != .Timeline_Semaphore {
        // Ascending values: poll only fences later than the last completion.
        latest := self.last_completed
        for entry in self.active {
            if entry.value <= latest {
                continue
            }
            status := device_impl.fp.GetFenceStatus(device_impl.vk_device, entry.fence.vk_fence)
            if status == .NOT_READY {
                // Submissions complete in order on one queue, so a fence that
                // is not ready proves every later entry is not ready either.
                break
            }
            if status != .SUCCESS {
                return max(u64)
            }
            latest = entry.value
        }
        return latest
    }

    value: u64
    result := device_impl.fp.GetSemaphoreCounterValue(device_impl.vk_device, self.timeline, &value)
    if result != .SUCCESS {
        return max(u64)
    }
    return value
}

// Block until `value` is signalled, at most `timeout_ns` (max waits forever).
// Returns false on timeout; a lost device answers true, since the work can never
// signal but the contract is that it is done.
@(require_results)
vk_fence_wait_value :: proc(
    self: ^VK_Fence,
    value: u64,
    timeout_ns: u64,
    lock: ^sync.RW_Mutex,
    loc := #caller_location,
) -> bool {
    if self.kind != .Timeline_Semaphore {
        // `active` and `last_completed` are owned by the submit context. Hold
        // the shared lock across the wait so `arm`/`maintain` cannot recycle the
        // fence while we are waiting on it. The fence is already submitted, so
        // blocking new submitters cannot prevent it from signalling.
        sync.shared_guard(lock)
        if value <= self.last_completed {
            return true
        }
        device_impl := vk_device_get_impl(self.device, loc)
        // Ascending values: the first fence reaching `value` proves the rest.
        for entry in self.active {
            if entry.value < value {
                continue
            }
            result := device_impl.fp.WaitForFences(
                device_impl.vk_device,
                1,
                &entry.fence.vk_fence,
                true,
                timeout_ns,
            )
            if result == .TIMEOUT {
                return false
            }
            // Lost device counts as done, like the timeline arm.
            return true
        }
        return false
    }

    device_impl := vk_device_get_impl(self.device, loc)
    semaphores := [1]vk.Semaphore{self.timeline}
    values := [1]u64{value}
    wait_info := vk.SemaphoreWaitInfo {
        sType          = .SEMAPHORE_WAIT_INFO,
        semaphoreCount = 1,
        pSemaphores    = &semaphores[0],
        pValues        = &values[0],
    }
    result := device_impl.fp.WaitSemaphores(device_impl.vk_device, &wait_info, timeout_ns)
    if result == .TIMEOUT {
        return false
    }
    return true
}

// Recycle the pool fences that signalled and remember how far the pool is
// complete. Non-blocking; without it the pool creates a fence every submit.
vk_fence_maintain :: proc(self: ^VK_Fence, loc := #caller_location) {
    if self.kind != .Fence_Pool {
        return
    }

    device_impl := vk_device_get_impl(self.device, loc)
    latest := vk_fence_get_value(self, loc)

    base_free := len(self.free_fences)
    for len(self.active) > 0 && self.active[0].value <= latest {
        append(&self.free_fences, self.active[0].fence)
        ordered_remove(&self.active, 0)
    }

    // Only the fences retired now need resetting; the rest were reset when
    // they were retired.
    retired := len(self.free_fences) - base_free
    if retired > 0 {
        clear(&self.reset_fences)
        for i in 0 ..< retired {
            append(&self.reset_fences, self.free_fences[base_free + i].vk_fence)
        }
        result := device_impl.fp.ResetFences(
            device_impl.vk_device,
            u32(retired),
            raw_data(self.reset_fences[:]),
        )
        // A lost device cannot reset fences; they die with it.
        _ = result
    }

    self.last_completed = latest
}

vk_fence_destroy :: proc(self: ^VK_Fence, loc := #caller_location) {
    device_impl := vk_device_get_impl(self.device, loc)

    if self.kind == .Fence_Pool {
        for fence in self.all_fences {
            if fence.vk_fence != {} {
                device_impl.fp.DestroyFence(device_impl.vk_device, fence.vk_fence, nil)
            }
            free(fence, device_impl.allocator)
        }
    } else if self.timeline != {} {
        device_impl.fp.DestroySemaphore(device_impl.vk_device, self.timeline, nil)
        self.timeline = {}
    }

    delete(self.all_fences)
    delete(self.active)
    delete(self.free_fences)
    delete(self.reset_fences)
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
    buffers: [MAX_COMMAND_BUFFERS]VK_Command_Buffer_Impl,

    device:             Device,
    queue:              vk.Queue,
    queue_family_index: u32,

    last_submit_handle: VK_Submit_Handle,
    // Packed `VK_Submit_Handle`, atomically accessed; see `vk_submit_handle_pack`.
    next_submit_handle: u64,

    // intra-queue chain:      signaled by the previous submit, waited by the next
    last_submit_semaphore: vk.SemaphoreSubmitInfo,
    // Pending acquire waits keyed by (surface, image). First submit touching
    // an image consumes its entry. Surface lock ranks above submitter lock.
    pending_acquires:      [dynamic]VK_Pending_Acquire,

    available_command_buffers: u32,
    submit_counter:            u32,
    // Strictly increasing value signalled by each submission; independent of
    // `submit_counter`, which identifies slots/generations.
    next_submission_value:     u64,
    submission_fence:          VK_Fence,

    allocator: runtime.Allocator,
    in_flight: [dynamic]^VK_Command_Buffer_Impl,

    // `queue_on_submitted_work_done` futures waiting on a submission value.
    work_done: [dynamic]VK_Work_Done_Entry,

    reclaim_pool:     [dynamic]^VK_Submit_Context_Reclaim_Batch,
    // Guards only the pool's pointer list, never held across release calls.
    reclaim_pool_mtx: sync.Mutex,

    // Guards slot bookkeeping and the semaphore chain. Released for recording
    // (parallel encoders) and blocking waits. Held across QueueSubmit/Present.
    mtx:                   sync.RW_Mutex,
    buffer_available_mtx:  sync.Mutex,
    buffer_available_cond: sync.Cond,
    // Free-slot indices, mirroring `vk_cmdbuf == {}` slots. The acquire path pops
    // from here instead of scanning 64 large slots. Only
    // `vk_submit_context_purge_locked` writes it, under `mtx`.
    free_slots:            [MAX_COMMAND_BUFFERS]u32,
    free_slots_count:      u32,
    // Scratch storage for `vk_submit_context_purge_locked`'s compaction of
    // `in_flight`. Avoids a per-purge allocation / copy.
    in_flight_scratch:     [dynamic]^VK_Command_Buffer_Impl,
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
    self.work_done = make([dynamic]VK_Work_Done_Entry, 0, 4, allocator)

    self.available_command_buffers = MAX_COMMAND_BUFFERS
    self.submit_counter = 1 // 0 reserved as "no submission"
    self.next_submission_value = 1
    self.in_flight = {}
    self.buffer_available_mtx = {}
    self.buffer_available_cond = {}

    vk_fence_init(&self.submission_fence, device, vk_fence_select_kind(device, loc), loc)

    for &buf, i in self.buffers {
        vk_command_buffer_init(&buf, device, queue_family_index, i, self.allocator, loc)
    }

    // Seed the free-slot stack: every slot is idle at init. The acquire path
    // pops from here (LIFO) instead of scanning 64 ~1.5-2 KiB slots inline.
    self.free_slots_count = MAX_COMMAND_BUFFERS
    for i in 0 ..< MAX_COMMAND_BUFFERS {
        self.free_slots[i] = u32(MAX_COMMAND_BUFFERS - 1 - i)
    }
}

vk_submit_context_uninit :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    // wait_all locks itself; blocking waits must not exclude others.
    vk_submit_context_wait_all(self, loc)
    vk_fence_destroy(&self.submission_fence, loc)
    for &buf in self.buffers {
        vk_command_buffer_uninit(&buf)
    }
    delete(self.pending_acquires)
    delete(self.work_done)
    delete(self.in_flight)

    for b in self.reclaim_pool {
        // Batches must come back drained; a full batch here means a caller
        // skipped the release step and its refs would leak.
        ensure(
            len(b.bind_group_refs) == 0 &&
            len(b.view_refs) == 0 &&
            len(b.render_pipeline_refs) == 0 &&
            len(b.bundle_refs) == 0,
            loc = loc,
        )
        delete(b.bind_group_refs)
        delete(b.view_refs)
        delete(b.render_pipeline_refs)
        delete(b.bundle_refs)
        free(b, self.allocator)
    }
    delete(self.reclaim_pool)
    delete(self.in_flight_scratch)
}

vk_submit_context_drain_refs :: proc(dst: ^[dynamic]$T, src: ^[dynamic]T) {
    if len(src^) > 0 {
        append(dst, ..src[:])
        clear(src)
    }
}

// Reclaims finished buffers, oldest first. Holds `mtx` exclusively.
// No upper bound: a command buffer may reference any number of resources, so the
// arrays are pooled and cleared per release and settle at the per-frame
// high-water mark rather than a leak.
VK_Submit_Context_Reclaim_Batch :: struct {
    bind_group_refs:      [dynamic]Bind_Group,
    view_refs:            [dynamic]Texture_View,
    render_pipeline_refs: [dynamic]Render_Pipeline,
    bundle_refs:          [dynamic]Render_Bundle,
}

vk_reclaim_batch_acquire :: proc(self: ^VK_Submit_Context) -> ^VK_Submit_Context_Reclaim_Batch {
    sync.guard(&self.reclaim_pool_mtx)
    if n := len(self.reclaim_pool); n > 0 {
        b := self.reclaim_pool[n - 1]
        resize(&self.reclaim_pool, n - 1)
        return b
    }
    // Cold path: only hit on the first N concurrent callers ever seen.
    b := new(VK_Submit_Context_Reclaim_Batch, self.allocator)
    b.bind_group_refs = make([dynamic]Bind_Group, 0, self.allocator)
    b.view_refs = make([dynamic]Texture_View, 0, self.allocator)
    b.render_pipeline_refs = make([dynamic]Render_Pipeline, 0, self.allocator)
    b.bundle_refs = make([dynamic]Render_Bundle, 0, self.allocator)
    return b
}

// Caller must have already drained/cleared the batch's three arrays
// (release_reclaimed_bind_groups does this) before returning it.
vk_reclaim_batch_release :: proc(self: ^VK_Submit_Context, b: ^VK_Submit_Context_Reclaim_Batch) {
    sync.guard(&self.reclaim_pool_mtx)
    append(&self.reclaim_pool, b)
}

vk_submit_context_purge_locked :: proc(
    self: ^VK_Submit_Context,
    reclaimed: ^VK_Submit_Context_Reclaim_Batch,
    loc := #caller_location,
) {
    // Track how many buffers we've reclaimed in this pass
    reclaimed_count := 0

    // Read the submission fence once for the whole sweep; both arms answer
    // with the highest completed submission value.
    completion_value := vk_fence_get_value(&self.submission_fence, loc)

    vk_staging_reap(vk_device_get_impl(self.device, loc), completion_value)

    // Work-done futures become resolvable once their value has completed.
    if len(self.work_done) > 0 {
        device_impl := vk_device_get_impl(self.device, loc)
        adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
        instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)
        sync.guard(&instance_impl.future_mtx)
        write := 0
        resolved_any := false
        for entry in self.work_done {
            if entry.value > completion_value {
                self.work_done[write] = entry
                write += 1
                continue
            }
            if pending, ok := instance_impl.pending_futures[entry.future_id]; ok {
                pending.ready = true
                instance_impl.pending_futures[entry.future_id] = pending
                resolved_any = true
            }
        }
        if resolved_any {
            sync.cond_broadcast(&instance_impl.future_cond)
        }
        resize(&self.work_done, write)
    }

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

        // In-order completion: later submissions cannot be done yet.
        if buf.submit_value > completion_value {
            break
        }

        // Buffer finished - reclaim it
        vk_submit_context_drain_refs(
            &reclaimed.bind_group_refs,
            &buf.tracker.bind_groups.resources,
        )
        vk_submit_context_drain_refs(&reclaimed.view_refs, &buf.tracker.views.resources)
        vk_submit_context_drain_refs(
            &reclaimed.render_pipeline_refs,
            &buf.tracker.render_pipelines.resources,
        )
        vk_submit_context_drain_refs(&reclaimed.bundle_refs, &buf.tracker.bundles.resources)

        vk_command_buffer_reset(buf, loc)
        buf.vk_cmdbuf = {}
        self.available_command_buffers += 1
        // Push the reclaimed slot back on the free stack so acquire pops it
        // O(1) instead of scanning 64 slots. We already hold `mtx`; nobody
        // else can see the slot until we release it.
        if self.free_slots_count < MAX_COMMAND_BUFFERS {
            self.free_slots[self.free_slots_count] = buf.submit_handle.buffer_index
            self.free_slots_count += 1
        }
        sync.cond_signal(&self.buffer_available_cond)

        // Reclaim markers are handled by the compaction pass below.
        self.in_flight[i] = nil
        reclaimed_count += 1
    }

    // Recycle the fences whose submissions completed, so the pool reuses them.
    vk_fence_maintain(&self.submission_fence, loc)

    // Compact in_flight array by removing nil entries. Uses a pre-allocated
    // scratch buffer to avoid per-purge allocation / copy.
    if reclaimed_count > 0 {
        write_idx := 0
        for read_idx in 0 ..< len(self.in_flight) {
            if self.in_flight[read_idx] != nil {
                self.in_flight[write_idx] = self.in_flight[read_idx]
                write_idx += 1
            }
        }
        resize(&self.in_flight, write_idx)
        // Note: `in_flight_scratch` is kept for reuse; its capacity is the
        // high-water mark of live buffers. It is freed in uninit.
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
        vk_texture_view_release(view, loc)
    }
    clear(&reclaimed.view_refs)

    for pipeline in reclaimed.render_pipeline_refs {
        vk_render_pipeline_release(pipeline, loc)
    }
    clear(&reclaimed.render_pipeline_refs)

    for bundle in reclaimed.bundle_refs {
        vk_render_bundle_release(bundle, loc)
    }
    clear(&reclaimed.bundle_refs)
}

// Cancels an acquired-but-unsubmitted buffer; publishes it idle under `mtx`.
vk_submit_context_cancel_active :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    ensure(buf.is_active, loc = loc)

    bind_group_refs := vk_command_buffer_take_bind_group_refs(buf)
    view_refs := vk_command_buffer_take_view_refs(buf)
    render_pipeline_refs := vk_command_buffer_take_render_pipeline_refs(buf)
    bundle_refs := vk_command_buffer_take_bundle_refs(buf)

    // No lock held: cleanup may enter deferred deletion.
    vk_command_buffer_reset(buf, loc)

    for bind_group in bind_group_refs {
        vk_bind_group_release(bind_group, loc)
    }
    delete(bind_group_refs)

    for view in view_refs {
        vk_texture_view_release(view, loc)
    }
    delete(view_refs)

    for pipeline in render_pipeline_refs {
        vk_render_pipeline_release(pipeline, loc)
    }
    delete(render_pipeline_refs)

    for bundle in bundle_refs {
        vk_render_bundle_release(bundle, loc)
    }
    delete(bundle_refs)

    sync.guard(&self.mtx)
    ensure(buf.is_active && buf.vk_cmdbuf != {}, loc = loc)
    buf.vk_cmdbuf = {}
    buf.is_active = false
    self.available_command_buffers += 1
    sync.cond_signal(&self.buffer_available_cond)
}

vk_submit_context_purge :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    reclaimed := vk_reclaim_batch_acquire(self)
    defer vk_reclaim_batch_release(self, reclaimed)
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
    reclaimed := vk_reclaim_batch_acquire(self)
    defer vk_reclaim_batch_release(self, reclaimed)

    ACQUIRE_BUFFER: for {
        {
            sync.guard(&self.mtx)

            // Fast path: pop from the free-slot stack O(1). Only fall back to a
            // linear scan (and a purge) if the stack is empty, which happens
            // only when every slot is in flight.
            if self.free_slots_count > 0 {
                self.free_slots_count -= 1
                current = &self.buffers[self.free_slots[self.free_slots_count]]
            }

            if current == nil {
                // All slots busy; reclaim finished ones.
                vk_submit_context_purge_locked(self, reclaimed, loc)
                if self.free_slots_count > 0 {
                    self.free_slots_count -= 1
                    current = &self.buffers[self.free_slots[self.free_slots_count]]
                } else {
                    // Purge reclaimed nothing; fall back to the pre-existing
                    // linear scan as a final check (e.g. a slot was returned by
                    // a path that does not go through purge, such as cancel).
                    for &buf in self.buffers {
                        if buf.vk_cmdbuf == {} {
                            current = &buf
                            break
                        }
                    }
                }
            }

            if current != nil {
                ensure(current.vk_cmdbuf_allocated != {}, loc = loc)

                current.submit_handle.submit_id = self.submit_counter
                self.available_command_buffers -= 1

                current.vk_cmdbuf = current.vk_cmdbuf_allocated
                // Visible under lock so purge skips it.
                current.is_active = true

                // Lock-free publish; see `vk_submit_handle_pack`.
                sync.atomic_store(
                    &self.next_submit_handle,
                    vk_submit_handle_pack(current.submit_handle),
                )
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

    // Fences are recycled and reset by `vk_fence_maintain`.
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

    // Validate the generation under the lock, then wait unlocked on the value.
    submission_value: u64
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
            // No submission exists yet. At teardown the encoder may be
            // abandoned instead of submitted, so treat it as done, matching
            // the recycled-generation rule.
            return true
        }
        submission_value = buf.submit_value
    }

    if vk_fence_wait_value(&self.submission_fence, submission_value, timeout_ns, &self.mtx, loc) {
        vk_submit_context_purge(self, loc)
        return true
    }
    return false
}

vk_submit_context_wait_all :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    last_value: u64
    {
        sync.shared_guard(&self.mtx)
        for &buf in self.buffers {
            if buf.vk_cmdbuf != {} && !buf.is_active {
                last_value = max(last_value, buf.submit_value)
            }
        }
    }
    if last_value > 0 {
        _ = vk_fence_wait_value(&self.submission_fence, last_value, max(u64), &self.mtx, loc)
    }
    vk_submit_context_purge(self, loc)
}

vk_submit_context_is_ready :: proc "contextless" (
    self: ^VK_Submit_Context,
    handle: VK_Submit_Handle,
    fast_check_no_vulkan := false,
    loc := #caller_location,
) -> bool {
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
    if buf.is_active || buf.submit_value == 0 {
        // Claimed but not submitted yet. A resource pinned to this handle must
        // wait for the submission, not treat the zero value as complete.
        return false
    }
    if fast_check_no_vulkan {
        return false
    }

    // Both arms answer with the highest completed submission value.
    return buf.submit_value <= vk_fence_get_value(&self.submission_fence, loc)
}

// DeviceWaitIdle serializes with submit/present; fence waits stay unlocked.
vk_submit_context_device_wait_idle :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    device_impl := vk_device_get_impl(self.device, loc)
    sync.guard(&self.mtx)
    vk_check(device_impl.fp.DeviceWaitIdle(device_impl.vk_device), loc = loc)
}

vk_submit_context_queue_wait_idle :: proc(self: ^VK_Submit_Context, loc := #caller_location) {
    device_impl := vk_device_get_impl(self.device, loc)
    sync.guard(&self.mtx)
    vk_check(device_impl.fp.QueueWaitIdle(device_impl.submitter.queue), loc = loc)
}

// Lock-free: reachable inside the submitter lock; locking would self-deadlock.
vk_submit_context_get_next_submit_handle :: proc(self: ^VK_Submit_Context) -> VK_Submit_Handle {
    return vk_submit_handle_unpack(sync.atomic_load(&self.next_submit_handle))
}

// -----------------------------------------------------------------------------
// Semaphore lists
// -----------------------------------------------------------------------------

// Binary semaphores carry this sentinel instead of a timeline value.
VK_SEMAPHORE_BINARY :: max(u64)

VK_Semaphore_List_Mode :: enum {
    Wait,
    Signal,
}

// A wait or signal list, with the values for any timeline semaphores in it.
// Values stay aligned with semaphores: binary entries use 0 once the value array
// exists.
VK_Semaphore_List :: struct {
    mode:        VK_Semaphore_List_Mode,
    semaphores:  [dynamic; VK_MAX_SUBMIT_SIGNALS]vk.Semaphore,
    values:      [dynamic; VK_MAX_SUBMIT_SIGNALS]u64,
    stage_masks: [dynamic; VK_MAX_SUBMIT_WAITS]vk.PipelineStageFlags,
}

vk_semaphore_list_push_signal :: proc(
    list: ^VK_Semaphore_List,
    semaphore: vk.Semaphore,
    value: u64 = VK_SEMAPHORE_BINARY,
) {
    ensure(list.mode == .Signal, "signal semaphore pushed to a wait list")
    vk_semaphore_list_push_inner(list, semaphore, value)
}

vk_semaphore_list_push_wait :: proc(
    list: ^VK_Semaphore_List,
    semaphore: vk.Semaphore,
    stage: vk.PipelineStageFlags,
    value: u64 = VK_SEMAPHORE_BINARY,
) {
    ensure(list.mode == .Wait, "wait semaphore pushed to a signal list")
    append(&list.stage_masks, stage)
    vk_semaphore_list_push_inner(list, semaphore, value)
}

vk_semaphore_list_push_inner :: proc(
    list: ^VK_Semaphore_List,
    semaphore: vk.Semaphore,
    value: u64,
) {
    // A binary semaphore keeps the value array aligned only once it exists.
    if value == VK_SEMAPHORE_BINARY {
        append(&list.semaphores, semaphore)
        if len(list.values) > 0 {
            append(&list.values, 0)
        }
        return
    }

    vk_semaphore_list_pad_values(list)
    append(&list.semaphores, semaphore)
    append(&list.values, value)
}

// Fill the value slots of binary semaphores already in the list, so a timeline
// value can be appended without shifting the alignment.
vk_semaphore_list_pad_values :: proc(list: ^VK_Semaphore_List) {
    for len(list.values) < len(list.semaphores) {
        append(&list.values, 0)
    }
}

// Point `submit_info` at both lists and chain `VkTimelineSemaphoreSubmitInfo`
// only when a timeline semaphore is present.
vk_semaphore_lists_to_submit :: proc(
    wait_semaphores: ^VK_Semaphore_List,
    signal_semaphores: ^VK_Semaphore_List,
    submit_info: ^vk.SubmitInfo,
    timeline_info: ^vk.TimelineSemaphoreSubmitInfo,
) {
    submit_info.pNext = nil

    uses_timeline := len(wait_semaphores.values) > 0 || len(signal_semaphores.values) > 0
    if uses_timeline {
        // A chained timeline struct needs a value slot for every semaphore in
        // each list, even one holding only binary semaphores; binary slots carry
        // 0, which Vulkan ignores.
        vk_semaphore_list_pad_values(wait_semaphores)
        vk_semaphore_list_pad_values(signal_semaphores)

        timeline_info^ = vk.TimelineSemaphoreSubmitInfo {
            sType                     = .TIMELINE_SEMAPHORE_SUBMIT_INFO,
            waitSemaphoreValueCount   = u32(len(wait_semaphores.semaphores)),
            pWaitSemaphoreValues      = raw_data(wait_semaphores.values[:]),
            signalSemaphoreValueCount = u32(len(signal_semaphores.semaphores)),
            pSignalSemaphoreValues    = raw_data(signal_semaphores.values[:]),
        }
        submit_info.pNext = timeline_info
    }

    submit_info.waitSemaphoreCount = u32(len(wait_semaphores.semaphores))
    if len(wait_semaphores.semaphores) > 0 {
        submit_info.pWaitSemaphores = raw_data(wait_semaphores.semaphores[:])
    }
    if len(wait_semaphores.stage_masks) > 0 {
        submit_info.pWaitDstStageMask = raw_data(wait_semaphores.stage_masks[:])
    }

    submit_info.signalSemaphoreCount = u32(len(signal_semaphores.semaphores))
    if len(signal_semaphores.semaphores) > 0 {
        submit_info.pSignalSemaphores = raw_data(signal_semaphores.semaphores[:])
    }
}

vk_submit_context_submit :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) -> VK_Submit_Handle {
    return vk_submit_context_submit_extra(self, buf, nil, loc)
}

// `extra_touches` names images used by commands recorded outside `buf`'s
// tracker, such as a deferred-write copy into a swapchain image.
vk_submit_context_submit_extra :: proc(
    self: ^VK_Submit_Context,
    buf: ^VK_Command_Buffer_Impl,
    extra_touches: []VK_Swapchain_Touch,
    loc := #caller_location,
) -> VK_Submit_Handle {
    device_impl := vk_device_get_impl(self.device, loc)

    // Caller owns this buffer between acquire and submit.
    ensure(buf.is_active)
    vk_command_buffer_close_recording(buf, loc)
    ensure(len(buf.command_buffers) > 0, "nothing to submit", loc)

    // Lock before merging device state: the merge advances the tracker to this
    // recording's end state, so it must run in submission order. Covers
    // QueueSubmit sync, semaphore chain, and pool state. Held across submit so
    // present collects signals only after queuing (VUID-03268).
    sync.guard(&self.mtx)

    // Device-to-recording-start barriers. Direct recording no longer folds
    // these at submit, so compute them here and prepend one transit buffer.
    clear(&buf.initial_buffers)
    clear(&buf.initial_textures)
    {
        sync.guard(&device_impl.trackers_mtx)
        device_buffer_tracker_set_from_tracker_and_drain_transitions(
            &device_impl.trackers.buffers,
            &buf.tracker.buffers,
            &buf.initial_buffers,
        )
        device_texture_tracker_set_from_tracker_and_drain_transitions(
            &device_impl.trackers.textures,
            &buf.tracker.textures,
            &buf.initial_textures,
        )
    }
    if len(buf.initial_buffers) > 0 || len(buf.initial_textures) > 0 {
        barrier_buffer := vk_command_buffer_allocate_recording(device_impl, buf, loc)
        buf.current_cmdbuf = barrier_buffer
        vk_encode_barriers(device_impl, buf, buf.initial_textures[:], buf.initial_buffers[:], loc)
        vk_check(device_impl.fp.EndCommandBuffer(barrier_buffer), loc = loc)
        append(&buf.command_buffers, barrier_buffer)
        // Move the barrier buffer in front of everything already recorded.
        for i := len(buf.command_buffers) - 1; i > 0; i -= 1 {
            buf.command_buffers[i], buf.command_buffers[i - 1] =
                buf.command_buffers[i - 1], buf.command_buffers[i]
        }
        buf.current_cmdbuf = {}
    }

    // Init clears run at submit, after pending writes have marked what they
    // uploaded, so they never wipe fresh contents.
    init_clear := vk_apply_pending_init_actions_at_submit(device_impl, buf, loc)
    if init_clear != {} {
        insert_at := 0
        if len(buf.command_buffers) > 0 {
            insert_at = 1
        }
        injected, _ := inject_at(&buf.command_buffers, insert_at, init_clear)
        ensure(injected, "failed to insert the init-clear buffer", loc)
    }

    // Touched swapchain images
    touches: VK_Swapchain_Touch_List
    vk_surface_scan_swapchain_touches(buf, &touches, loc)
    for touch in extra_touches {
        append(&touches, touch)
    }

    // Over-capacity appends drop silently; assert instead of losing a wait/signal.
    ensure(len(touches) + 1 <= VK_MAX_SUBMIT_WAITS, "too many waits for one submit", loc)
    ensure(
        1 + len(touches) <= VK_MAX_SUBMIT_SIGNALS,
        "too many signal semaphores for one submit",
        loc,
    )
    wait_semaphores: VK_Semaphore_List
    wait_semaphores.mode = .Wait
    signal_semaphores: VK_Semaphore_List
    signal_semaphores.mode = .Signal

    for touch in touches {
        // First submit per image consumes the acquire wait.
        if sem, ok := vk_surface_take_pending_locked(self, touch, loc); ok {
            vk_semaphore_list_push_wait(
                &wait_semaphores,
                sem,
                vk.PipelineStageFlags{.ALL_COMMANDS},
            )
        }
        vk_semaphore_list_push_signal(
            &signal_semaphores,
            vk_surface_present_pool_alloc_locked(touch.surface, touch.image, device_impl.fp, loc),
        )
    }
    if self.last_submit_semaphore.semaphore != {} {
        vk_semaphore_list_push_wait(
            &wait_semaphores,
            self.last_submit_semaphore.semaphore,
            vk.PipelineStageFlags{.ALL_COMMANDS},
        )
    }

    // Chain signal for the next submit.
    vk_semaphore_list_push_signal(&signal_semaphores, buf.vk_semaphore)

    // Arm the submission value: timeline semaphore signal, or a pooled fence.
    // The value is assigned here, under the lock, so two encoders acquired
    // before either submits cannot signal the same value.
    submission_value := self.next_submission_value
    self.next_submission_value += 1
    buf.submit_value = submission_value

    submission_fence := vk_fence_arm_submission(
        &self.submission_fence,
        submission_value,
        &signal_semaphores,
        loc,
    )

    submit_info := vk.SubmitInfo {
        sType              = .SUBMIT_INFO,
        commandBufferCount = u32(len(buf.command_buffers)),
        pCommandBuffers    = raw_data(buf.command_buffers),
    }
    timeline_info: vk.TimelineSemaphoreSubmitInfo
    vk_semaphore_lists_to_submit(
        &wait_semaphores,
        &signal_semaphores,
        &submit_info,
        &timeline_info,
    )
    vk_check(device_impl.fp.QueueSubmit(self.queue, 1, &submit_info, submission_fence), loc = loc)
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
