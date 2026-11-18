#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:mem"
import "core:sync"

// Vendor
import gpua "allocator"
import "lib/vma"
import vk "vendor:vulkan"

VK_Buffer_Handle :: distinct hm.Handle64

VK_Buffer_Impl :: struct {
    // Base
    using base:          _Buffer_Impl,
    vk_buffer:           vk.Buffer,
    vk_size:             vk.DeviceSize,
    handle:              VK_Buffer_Handle,
    public_usage:        Buffer_Usages,
    vk_buffer_flags:     vk.BufferUsageFlags,
    vk_mem_flags:        vk.MemoryPropertyFlags,
    destroyed:           bool,
    // A public release may leave only deferred-write holds. The handle must
    // stay alive until the flush resolves it, but the object is logically
    // destroyed for validation.
    deferred_holds:      Ref_Count_Type,
    destroy_enqueued:    bool,
    vma_allocation_info: vma.AllocationInfo,
    vma_allocation:      vma.Allocation,
    gpu_allocation:      gpua.VK_Allocation,
}

@(require_results)
vk_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    impl := vk_device_get_impl(device, loc)

    desc, ok := pre_device_create_buffer(device, descriptor, loc)
    if !ok {
        return {}
    }

    vk_buffer_flags := vk_conv_to_buffer_usage_flags(desc.usage)
    mem_flags := vk_infer_memory_flags(desc.usage)

    vk_info := vk.BufferCreateInfo {
        sType                 = .BUFFER_CREATE_INFO,
        pNext                 = nil,
        flags                 = {},
        size                  = vk.DeviceSize(desc.size),
        usage                 = vk_buffer_flags,
        sharingMode           = .EXCLUSIVE,
        queueFamilyIndexCount = 0,
        pQueueFamilyIndices   = nil,
    }

    is_coherent_memory: bool
    mapped_ptr: rawptr
    vk_buffer: vk.Buffer

    should_map := .Map_Write in desc.usage || .Map_Read in desc.usage

    when USE_VMA {
        vma_alloc_info: vma.AllocationCreateInfo

        // Initialize vma.AllocationCreateInfo for host-visible memory
        if .HOST_VISIBLE in mem_flags {
            vma_alloc_info = {
                flags          = {.HOST_ACCESS_RANDOM},
                requiredFlags  = mem_flags,
                preferredFlags = {.HOST_COHERENT, .HOST_CACHED},
            }

            // Persistent mapping, only when requested at creation
            if should_map {
                vma_alloc_info.flags += {.MAPPED}
            }
        }

        vma_alloc_info.usage = .AUTO
        vma_alloc_info.minAlignment = 16
        vma_alloc_info.memoryTypeBits = impl.valid_memory_type_bits

        vma_allocation: vma.Allocation
        vma_allocation_info: vma.AllocationInfo
        if res := vma.CreateBuffer(
            impl.vma_allocator,
            vk_info,
            vma_alloc_info,
            &vk_buffer,
            &vma_allocation,
            &vma_allocation_info,
        ); res != .SUCCESS {
            vk_try(device, res, "vmaCreateBuffer", loc)
            return {}
        }

        if .HOST_VISIBLE in mem_flags {
            alloc_mem_flags: vk.MemoryPropertyFlags
            vma.GetAllocationMemoryProperties(impl.vma_allocator, vma_allocation, &alloc_mem_flags)
            is_coherent_memory = .HOST_COHERENT in alloc_mem_flags

            if .MAPPED in vma_alloc_info.flags {
                if res := vma.MapMemory(impl.vma_allocator, vma_allocation, &mapped_ptr);
                   res != .SUCCESS {
                    vk_try(device, res, "vmaMapMemory", loc)
                    vma.DestroyBuffer(impl.vma_allocator, vk_buffer, vma_allocation)
                    return {}
                }
            }
        }
    } else {
        // Create buffer
        if res := impl.fp.CreateBuffer(impl.vk_device, &vk_info, nil, &vk_buffer);
           res != .SUCCESS {
            vk_try(device, res, "vkCreateBuffer", loc)
            return {}
        }

        requirements: vk.MemoryRequirements
        impl.fp.GetBufferMemoryRequirements(impl.vk_device, vk_buffer, &requirements)

        masked_requirements := requirements
        masked_requirements.memoryTypeBits &= impl.valid_memory_type_bits
        assert(
            masked_requirements.memoryTypeBits != 0,
            "VULKAN: no valid memory type for buffer allocation",
            loc,
        )

        alloc_desc := gpua.VK_Allocation_Create_Desc {
            name              = desc.label,
            requirements      = masked_requirements,
            location          = vk_buffer_usage_to_location(desc.usage),
            linear            = true, // buffers are always linear
            allocation_scheme = gpua.VK_ALLOCATION_SCHEME_MANAGED,
        }

        gpu_allocation: gpua.VK_Allocation
        gpua.gpu_alloc_check(
            gpua.vk_allocator_allocate(&impl.gpu_allocator, alloc_desc, &gpu_allocation, loc),
        )

        alloc_mem_flags := gpu_allocation.memory_properties
        is_coherent_memory = .HOST_COHERENT in alloc_mem_flags

        if res := impl.fp.BindBufferMemory(
            impl.vk_device,
            vk_buffer,
            gpu_allocation.device_memory,
            vk.DeviceSize(gpu_allocation.offset),
        ); res != .SUCCESS {
            vk_try(device, res, "vkBindBufferMemory", loc)
            // Leave nothing behind: the buffer exists but is unusable.
            impl.fp.DestroyBuffer(impl.vk_device, vk_buffer, nil)
            gpua.vk_allocator_free(&impl.gpu_allocator, &gpu_allocation)
            return {}
        }

        if should_map {
            ensure(
                .HOST_VISIBLE in alloc_mem_flags,
                "mappable buffer did not receive host-visible memory",
                loc,
            )
            mapped_ptr = gpu_allocation.mapped_ptr
        }
    }

    buffer_impl, buffer_handle := add_impl(&impl.buffers, VK_Buffer_Impl {
            map_state       = Buffer_Map_State_Idle{},
            device          = device,
            vk_buffer       = vk_buffer,
            size            = desc.size,
            visible_size    = descriptor.size,
            public_usage    = descriptor.usage,
            vk_size         = vk.DeviceSize(desc.size),
            mapped_ptr      = mapped_ptr,
            vk_buffer_flags = vk_buffer_flags,
            vk_mem_flags    = mem_flags,
            usage           = desc.usage,
            is_coherent     = is_coherent_memory,
        })

    when USE_VMA {
        buffer_impl.vma_allocation = vma_allocation
        buffer_impl.vma_allocation_info = vma_allocation_info
    } else {
        buffer_impl.gpu_allocation = gpu_allocation
    }

    out := new_handle(Buffer, device, buffer_handle)
    vk_label_set(&impl.labels, .Buffer, pack_handle(buffer_handle), descriptor.label)

    buffer_init_tracker_init(&buffer_impl.init, impl.allocator, u64(desc.size))

    if !post_device_create_buffer(device, out, desc, loc) {
        vk_buffer_release(out, loc)
        return {}
    }

    return out
}

@(require_results)
vk_buffer_get_internal_impl :: #force_inline proc "contextless" (
    buffer: Buffer,
    loc := #caller_location,
) -> ^_Buffer_Impl {
    return vk_buffer_get_impl(buffer, loc)
}

@(require_results)
vk_buffer_get_impl :: #force_inline proc "contextless" (
    buffer: Buffer,
    loc := #caller_location,
) -> ^VK_Buffer_Impl {
    assert_contextless(buffer != {}, "invalid buffer", loc)
    device_impl := vk_device_get_impl(buffer.device, loc)
    return get_handle_impl(&device_impl.buffers, buffer.handle, loc)
}

vk_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        return
    }

    if impl.destroyed {
        return
    }

    #partial switch _ in impl.map_state {
    case Buffer_Map_State_Init, Buffer_Map_State_Active, Buffer_Pending_Mapping:
        vk_buffer_unmap(buffer, loc)
    case Buffer_Map_State_Idle:
    }

    impl.destroyed = true
    intr.atomic_add(&device_impl.destroyed_resources, 1)

    vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, VK_Deferred_Buffer {
        buffer         = impl.vk_buffer,
        tracker_index  = impl.tracker_index,
        vma_allocation = impl.vma_allocation,
        gpu_allocation = impl.gpu_allocation,
        init           = impl.init,
    })
    impl.destroy_enqueued = true
}

vk_buffer_flush_mapped_ranges :: proc(
    buffer: Buffer,
    offset: uint,
    size: uint,
    loc := #caller_location,
) {
    impl := vk_buffer_get_impl(buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    if impl.is_coherent {
        return
    }

    mask := device_impl.non_coherent_atom_size_mask

    when USE_VMA {
        aligned_offset := vk.DeviceSize(offset) & ~mask
        aligned_size := (vk.DeviceSize(size) + mask) & ~mask

        vk_check(
            vma.FlushAllocation(
                device_impl.vma_allocator,
                impl.vma_allocation,
                aligned_offset,
                aligned_size,
            ),
        )
    } else {
        base_offset := vk.DeviceSize(impl.gpu_allocation.offset) + vk.DeviceSize(offset)
        aligned_offset := base_offset & ~mask
        aligned_size := (vk.DeviceSize(size) + mask) & ~mask

        range := vk.MappedMemoryRange {
            sType  = .MAPPED_MEMORY_RANGE,
            memory = impl.gpu_allocation.device_memory,
            offset = aligned_offset,
            size   = aligned_size,
        }
        vk_check(device_impl.fp.FlushMappedMemoryRanges(device_impl.vk_device, 1, &range))
    }
}

vk_buffer_get_mapped_range_active :: proc(
    impl: ^VK_Buffer_Impl,
    offset: uint = 0,
    range_size: u64,
    loc := #caller_location,
) -> rawptr {
    #partial switch &state in impl.map_state {
    case Buffer_Map_State_Active:
        ensure(offset <= uint(state.range.end), "out of bounds start offset overrun", loc)
        ensure(offset >= uint(state.range.start), "out of bounds start offset underrun", loc)
        ensure(
            uint(range_size) <= uint(state.range.end) - offset,
            "out of bounds end offset overrun",
            loc,
        )
        relative_offset := offset - uint(state.range.start)
        return rawptr(uintptr(state.ptr) + uintptr(relative_offset))
    case:
        unreachable()
    }
}

vk_buffer_get_const_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    ptr, ok := vk_buffer_get_mapped_range_checked(buffer, offset, size, false, loc)
    if !ok {
        return nil
    }
    return ptr
}

@(require_results)
vk_buffer_get_mapped_range_checked :: proc(
    buffer: Buffer,
    offset: uint,
    size: uint,
    writable: bool,
    loc := #caller_location,
) -> (
    rawptr,
    bool,
) {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        gpu_report_validation_error(buffer.device, "buffer is not a live handle", loc)
        return nil, false
    }

    if impl.destroyed {
        gpu_report_validation_error(buffer.device, "buffer has been destroyed", loc)
        return nil, false
    }

    mapped_start, mapped_end: u64
    base: rawptr
    switch &state in impl.map_state {
    case Buffer_Map_State_Init:
        // Mapped-at-creation buffers are always writable.
        mapped_start = 0
        mapped_end = impl.visible_size
        base = state.staging_buffer.ptr

    case Buffer_Map_State_Active:
        // A read-only mapping only exposes read-only ranges. Const ranges are
        // valid for either mapping mode.
        if writable && state.mode == .Read {
            gpu_report_validation_error(
                buffer.device,
                "buffer is mapped for reading only; use buffer_get_const_mapped_range",
                loc,
            )
            return nil, false
        }
        mapped_start = state.range.start
        mapped_end = state.range.end
        base = state.ptr

    case Buffer_Pending_Mapping:
        gpu_report_validation_error(buffer.device, "buffer is waiting on a pending mapping", loc)
        return nil, false
    case Buffer_Map_State_Idle:
        gpu_report_validation_error(buffer.device, "buffer is not mapped", loc)
        return nil, false
    }

    valid := true
    valid &= gpu_validate(
        buffer.device,
        offset % 8 == 0,
        "mapped range offset must be a multiple of 8",
        loc,
    )
    valid &= gpu_validate(
        buffer.device,
        size == WHOLE_MAP_SIZE || size % 4 == 0,
        "mapped range size must be a multiple of 4",
        loc,
    )

    resolved_size := u64(size)
    if (size == 0 || size == WHOLE_MAP_SIZE) && u64(offset) <= impl.visible_size {
        // An unspecified size means "to the end of the buffer"; the mapped
        // region check below then rejects requests a partial mapping does not
        // cover.
        resolved_size = impl.visible_size - u64(offset)
    }
    valid &= gpu_validate(
        buffer.device,
        u64(offset) >= mapped_start &&
        u64(offset) <= mapped_end &&
        resolved_size <= mapped_end - u64(offset),
        "mapped range is outside the mapped region",
        loc,
    )
    if !valid {
        return nil, false
    }

    return rawptr(uintptr(base) + uintptr(u64(offset) - mapped_start)), true
}

vk_buffer_get_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    ptr, ok := vk_buffer_get_mapped_range_checked(buffer, offset, size, true, loc)
    if !ok {
        return nil
    }
    return ptr
}

vk_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        return .Unmapped
    }
    switch state in impl.map_state {
    case Buffer_Map_State_Active:
        return .Mapped
    case Buffer_Map_State_Init:
        return .Mapped
    case Buffer_Pending_Mapping:
        return .Pending
    case Buffer_Map_State_Idle:
        return .Unmapped
    }
    return .Unmapped
}

vk_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    impl := vk_buffer_get_impl(buffer, loc)
    return impl.visible_size
}

vk_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    impl := vk_buffer_get_impl(buffer, loc)
    return unmap_buffer_usage(impl.usage)
}

@(require_results)
vk_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        gpu_report_validation_error(buffer.device, "buffer is not a live handle", loc)
        return {}
    }

    if impl.destroyed {
        gpu_report_validation_error(buffer.device, "buffer has been destroyed", loc)
        return {}
    }

    valid := true
    if mode == .Read {
        valid &= gpu_validate(
            buffer.device,
            .Map_Read in impl.usage,
            "map_async(READ) requires the [Map_Read] usage",
            loc,
        )
    } else {
        valid &= gpu_validate(
            buffer.device,
            .Map_Write in impl.usage,
            "map_async(WRITE) requires the [Map_Write] usage",
            loc,
        )
    }

    #partial switch _ in impl.map_state {
    case Buffer_Map_State_Idle:
    case:
        valid &= gpu_validate(
            buffer.device,
            false,
            "buffer already has a mapping or a pending mapping",
            loc,
        )
    }

    valid &= gpu_validate(
        buffer.device,
        offset % 8 == 0,
        "map_async offset must be a multiple of 8",
        loc,
    )
    valid &= gpu_validate(
        buffer.device,
        size == WHOLE_MAP_SIZE || size % 4 == 0,
        "map_async size must be a multiple of 4",
        loc,
    )

    resolved_size := u64(size)
    if (size == 0 || size == WHOLE_MAP_SIZE) && u64(offset) <= impl.visible_size {
        resolved_size = impl.visible_size - u64(offset)
    }
    valid &= gpu_validate(
        buffer.device,
        u64(offset) <= impl.visible_size && resolved_size <= impl.visible_size - u64(offset),
        "map_async range is out of bounds",
        loc,
    )

    if !valid {
        return {}
    }

    // Pending host writes are queue work: submit them before the mapping so the
    // copy is ordered ahead of the host read.
    _, _ = vk_queue_flush_writes_for_buffer(buffer.device, buffer, loc)

    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
    instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)

    id := intr.atomic_add(&instance_impl.current_future_id, 1)

    impl.map_state = Buffer_Pending_Mapping {
        range = {u64(offset), u64(offset) + resolved_size},
        op = {mode = mode},
        future_id = id,
        parent_buffer = buffer,
    }
    intr.atomic_add(&device_impl.mapped_buffers, 1)

    sync.guard(&instance_impl.future_mtx)
    instance_impl.pending_futures[id] = {
        resolve = vk_buffer_map_sync_resolve,
        wait = vk_buffer_map_wait,
        userdata = Future_Data_For_Map_Buffer_Async {
            buffer        = buffer,
            mode          = mode,
            offset        = offset,
            size          = uint(resolved_size),
            callback_info = callback_info,
            loc           = loc,
            future_id     = id,
        },
        poll = true,
        ready = false,
    }
    sync.cond_broadcast(&instance_impl.future_cond)

    return {id}
}

// Waits for the queue to finish the work that may still be using the buffer. The
// `last_submit_handle` covers the pending-write flush performed by
// `vk_buffer_map_async` and any later submission.
vk_buffer_map_wait :: proc(userdata: Future_Data, timeout_ns: u64) -> bool {
    #partial switch data in userdata {
    case Future_Data_For_Map_Buffer_Async:
        device_impl := vk_device_get_impl(data.buffer.device)
        handle := device_impl.submitter.last_submit_handle
        if handle != {} &&
           !vk_submit_context_wait_timeout(&device_impl.submitter, handle, timeout_ns) {
            return false
        }
        vk_submit_context_purge(&device_impl.submitter)

        // Poll futures resolve only after their producer sets `ready`; the wait
        // callback is what advances this one, so publish readiness here.
        adapter_impl := vk_adapter_get_impl(device_impl.adapter)
        instance_impl := vk_instance_get_impl(adapter_impl.instance)
        sync.guard(&instance_impl.future_mtx)
        if pending, ok := instance_impl.pending_futures[data.future_id]; ok {
            pending.ready = true
            instance_impl.pending_futures[data.future_id] = pending
        }
        sync.cond_broadcast(&instance_impl.future_cond)
        return true
    }
    return false
}

vk_buffer_map_sync_resolve :: proc(userdata: Future_Data) {
    #partial switch data in userdata {
    case Future_Data_For_Map_Buffer_Async:
        #force_inline vk_buffer_map_sync(data.buffer, data.mode, data.offset, data.size, data.loc)
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

vk_buffer_map_sync :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    loc := #caller_location,
) -> rawptr {
    impl := vk_buffer_get_impl(buffer, loc)
    assert(!impl.destroyed, "buffer has been destroyed", loc)

    device_impl := vk_device_get_impl(impl.device, loc)

    #partial switch state in impl.map_state {
    case Buffer_Map_State_Active:
        return impl.mapped_ptr
    }

    // resolve an unspecified size sentinel to an actual size
    resolved_size := size
    if resolved_size == WHOLE_MAP_SIZE || resolved_size == 0 {
        ensure(u64(offset) <= impl.visible_size, "offset out of bounds", loc)
        resolved_size = uint(impl.visible_size) - offset
    }

    when USE_VMA {
        vk_check(vma.MapMemory(device_impl.vma_allocator, impl.vma_allocation, &impl.mapped_ptr))
    } else {
        ensure(
            impl.gpu_allocation.mapped_ptr != nil,
            "buffer's memory is not host-visible/mapped",
            loc,
        )
        impl.mapped_ptr = rawptr(uintptr(impl.gpu_allocation.mapped_ptr) + uintptr(offset))
    }

    if mode == .Read && !impl.is_coherent {
        when USE_VMA {
            vk_check(
                vma.InvalidateAllocation(
                    device_impl.vma_allocator,
                    impl.vma_allocation,
                    0,
                    vk.DeviceSize(vk.WHOLE_SIZE),
                ),
            )
        } else {
            range := vk.MappedMemoryRange {
                sType  = .MAPPED_MEMORY_RANGE,
                memory = impl.gpu_allocation.device_memory,
                offset = vk.DeviceSize(impl.gpu_allocation.offset) + vk.DeviceSize(offset),
                size   = vk.DeviceSize(resolved_size),
            }
            vk_check(device_impl.fp.InvalidateMappedMemoryRanges(device_impl.vk_device, 1, &range))
        }
    }

    // The counter tracks buffers that are not `Idle`, so only the `Idle` ->
    // `Active` edge adds. Resolving a pending mapping, and re-mapping a
    // created-with-mapping buffer, are already counted; adding again would
    // leave the count permanently high and silently disable the per-submit
    // fast path for the rest of the device's life.
    was_idle := vk_buffer_is_unmapped(impl)
    impl.map_state = Buffer_Map_State_Active {
        mapping = {ptr = impl.mapped_ptr, is_coherent = impl.is_coherent},
        range = {u64(offset), u64(offset) + u64(resolved_size)},
        mode = mode,
    }
    if was_idle {
        intr.atomic_add(&device_impl.mapped_buffers, 1)
    }

    return impl.mapped_ptr
}

@(require_results)
vk_buffer_read_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    src, ok := vk_buffer_get_mapped_range_checked(buffer, offset, size, false, loc)
    if !ok {
        return .Error
    }
    copy(([^]u8)(data)[:size], ([^]u8)(src)[:size])
    return .Success
}

vk_buffer_get_label :: proc(buffer: Buffer, loc := #caller_location) -> string {
    impl := vk_buffer_get_impl(buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Buffer, pack_handle(impl.handle))
}

vk_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    impl := vk_buffer_get_impl(buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Buffer, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .BUFFER, impl.vk_buffer, label, loc)
}

vk_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        return
    }

    if impl.destroyed {
        return
    }

    mapping := impl.map_state
    impl.map_state = Buffer_Map_State_Idle{}
    impl.mapped_ptr = nil

    // One decrement for the one buffer leaving a non-idle state, whichever it
    // was. Every add site is an `Idle` -> non-idle transition, so keeping the
    // decrement in one place keeps the counts balanced.
    #partial switch _ in mapping {
    case Buffer_Map_State_Idle:
    case:
        assert(
            intr.atomic_load_explicit(&device_impl.mapped_buffers, .Relaxed) > 0,
            "mapped_buffers underflow",
            loc,
        )
        intr.atomic_sub(&device_impl.mapped_buffers, 1)
    }

    switch &state in mapping {
    case Buffer_Map_State_Idle:
        return
    case Buffer_Map_State_Init:
        staging_buffer := staging_buffer_flush(&state.staging_buffer, loc)

        transition_src := Buffer_State_Transition {
            buffer = staging_buffer.buffer,
            from   = {.Map_Write},
            to     = {.Copy_Src},
        }

        transition_dst := Buffer_State_Transition {
            buffer = buffer,
            from   = {},
            to     = {.Copy_Dst},
        }

        deferred_writes := &device_impl.queue.deferred_writes

        // Held across the whole record: there is a single scratch encoder, so this
        // is what keeps a concurrent unmap or queue write from recording into it
        // at the same time.
        sync.guard(&deferred_writes.mtx)

        encoder := vk_deferred_writes_activate_locked(deferred_writes, loc)

        _command_encoder_transition_buffers(encoder, {transition_src, transition_dst})
        // Internal copy of the whole allocation (including padding), so it
        // cannot go through the public copy validation.
        encoder_impl := vk_command_encoder_get_impl(encoder, loc)
        region := vk.BufferCopy {
            srcOffset = 0,
            dstOffset = 0,
            size      = vk.DeviceSize(staging_buffer.size),
        }
        staging_impl := vk_buffer_get_impl(state.staging_buffer.buffer, loc)
        device_impl.fp.CmdCopyBuffer(
            encoder_impl.cmdbuf.current_cmdbuf,
            staging_impl.vk_buffer,
            impl.vk_buffer,
            1,
            &region,
        )
        buffer_init_tracker_mark_initialized(&impl.init, 0, staging_buffer.size)

        vk_deferred_writes_insert_buffer_locked(deferred_writes, buffer)
        vk_deferred_writes_consume_locked(deferred_writes, staging_buffer)

    case Buffer_Pending_Mapping:
        // Mapping was requested but never resolved: abandon it and drop its
        // pending future so it is not reported as leaked at instance teardown.
        if state.future_id != 0 {
            adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
            instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)
            sync.guard(&instance_impl.future_mtx)
            delete_key(&instance_impl.pending_futures, state.future_id)
            state.future_id = 0
        }
        return

    case Buffer_Map_State_Active:
        vk_buffer_flush_mapped_ranges(buffer, 0, uint(impl.size))
        when USE_VMA {
            vma.UnmapMemory(device_impl.vma_allocator, impl.vma_allocation)
        } else {
            // no-op: the memory block stays persistently mapped for its lifetime;
            // vk_memory_block_destroy is the only thing that unmaps it.
        }
    }
}

vk_buffer_write_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    dst, ok := vk_buffer_get_mapped_range_checked(buffer, offset, size, true, loc)
    if !ok {
        return .Error
    }
    copy(([^]u8)(dst)[:size], ([^]u8)(data)[:size])
    vk_buffer_flush_mapped_ranges(buffer, offset, size, loc)
    return .Success
}

vk_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    impl := vk_buffer_get_impl(buffer, loc)
    add_ref(impl, loc)
}

// A buffer is usable by a submission or a queue write only when no map is
// active, pending or created-with-mapping.
vk_buffer_is_unmapped :: proc(impl: ^VK_Buffer_Impl) -> bool {
    #partial switch _ in impl.map_state {
    case Buffer_Map_State_Idle:
        return true
    case:
        return false
    }
}

vk_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    vk_buffer_release_impl(buffer, {}, false, loc)
}

// Releases a buffer whose last use is the submission named by `wait_on`.
@(private)
vk_buffer_release_after :: proc(
    buffer: Buffer,
    wait_on: VK_Submit_Handle,
    loc := #caller_location,
) {
    impl := vk_buffer_get_impl(buffer, loc)
    intr.atomic_sub(&impl.deferred_holds, 1)
    vk_buffer_release_impl(buffer, wait_on, true, loc)
}

@(private = "file")
vk_buffer_release_impl :: proc(
    buffer: Buffer,
    wait_on: VK_Submit_Handle,
    have_wait_on: bool,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(buffer.device, loc)
    impl := dhm_get_if_valid(&device_impl.buffers, unpack_handle(VK_Buffer_Handle, buffer.handle))
    if impl == nil {
        return
    }
    // Unmap before dropping the last app reference: vk_buffer_unmap may queue a
    // deferred copy and take a hold needing a live refcount. Holds aren't
    // owners, so test for "only non-hold reference", not ref == 1; otherwise we
    // skip the unmap, mark the buffer destroyed while still mapped, and leak
    // mapped_buffers.
    ref_count := intr.atomic_load_explicit(&impl.ref, .Acquire)
    holds := intr.atomic_load_explicit(&impl.deferred_holds, .Acquire)
    last_owner := ref_count == holds + 1
    did_unmap := false
    if last_owner && !impl.destroyed {
        switch _ in impl.map_state {
        case Buffer_Map_State_Init, Buffer_Map_State_Active, Buffer_Pending_Mapping:
            vk_buffer_unmap(buffer, loc)
            did_unmap = true
        case Buffer_Map_State_Idle:
        // nothing mapped, nothing to do
        }
    }

    last := release_ref(impl, loc)

    // A public release that leaves only deferred-write holds still means the
    // application is done with the buffer. Mark it destroyed for validation;
    // the handle survives until the flush drops the holds.
    if !have_wait_on &&
       !impl.destroyed &&
       intr.atomic_load_explicit(&impl.ref, .Acquire) ==
           intr.atomic_load_explicit(&impl.deferred_holds, .Acquire) {
        impl.destroyed = true
        intr.atomic_add(&device_impl.destroyed_resources, 1)
    }

    if last {
        if !impl.destroy_enqueued {
            if !impl.destroyed {
                if !did_unmap && intr.atomic_load_explicit(&impl.ref, .Acquire) > 0 {
                    switch _ in impl.map_state {
                    case Buffer_Map_State_Init, Buffer_Map_State_Active, Buffer_Pending_Mapping:
                        vk_buffer_unmap(buffer, loc)
                    case Buffer_Map_State_Idle:
                    // nothing mapped, nothing to do
                    }
                }
            }

            // Unmapping may have queued a deferred copy and taken a hold. That
            // hold owns the final release; removing the handle here would make
            // the flush unable to resolve it.
            if intr.atomic_load_explicit(&impl.ref, .Acquire) != 0 {
                return
            }

            deferred := VK_Deferred_Buffer {
                buffer         = impl.vk_buffer,
                tracker_index  = impl.tracker_index,
                vma_allocation = impl.vma_allocation,
                gpu_allocation = impl.gpu_allocation,
                init           = impl.init,
            }
            if have_wait_on {
                vk_deferred_add_resource_after(&device_impl.deferred, deferred, wait_on, loc)
            } else {
                vk_deferred_add_resource(
                    &device_impl.deferred,
                    &device_impl.submitter,
                    deferred,
                    loc,
                )
            }
            impl.destroy_enqueued = true
        }

        vk_label_remove(&device_impl.labels, .Buffer, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.buffers, impl.handle)
    }
}

Buffer_Descriptor_Impl :: struct {
    label:              string,
    size:               u64,
    visible_size:       u64,
    tail_start:         u64,
    usage:              Buffer_Uses,
    memory_flags:       Memory_Flags,
    mapped_at_creation: bool,
}

@(require_results)
pre_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> (
    Buffer_Descriptor_Impl,
    bool,
) {
    assert(device != {}, "invalid device", loc)

    valid := true
    valid &= gpu_validate(device, descriptor.usage != {}, "buffer usage cannot be empty", loc)
    valid &= gpu_validate(
        device,
        !(.Map_Read in descriptor.usage && .Map_Write in descriptor.usage),
        "buffer cannot be both [Map_Read] and [Map_Write]",
        loc,
    )

    known_usages: Buffer_Usages
    for usage in Buffer_Usage {
        known_usages += {usage}
    }
    valid &= gpu_validate(
        device,
        descriptor.usage &~ known_usages == {},
        "buffer usage contains a bit the API does not define",
        loc,
    )

    device_impl := _device_get_internal_impl(device, loc)

    valid &= gpu_validate(
        device,
        descriptor.size <= device_impl.limits.max_buffer_size,
        "buffer size exceeds the device limit",
        loc,
    )

    if buffer_usage_intersects(descriptor.usage, {.Blas_Input, .Tlas_Input}) {
        valid &= gpu_validate(
            device,
            has_features(device_impl.features[:], {.Ray_Query}),
            "ray tracing buffer usage requires the [Ray_Query] feature",
            loc,
        )
    }

    if .Index in descriptor.usage &&
       buffer_usage_intersects(descriptor.usage, {.Vertex, .Uniform, .Indirect, .Storage}) {
        valid &= gpu_validate(
            device,
            .Unrestricted_Index_Buffer in device_impl.dl_features,
            "index buffers with other usages require [Unrestricted_Index_Buffer]",
            loc,
        )
    }

    if !has_features(device_impl.features[:], {.Mappable_Primary_Buffers}) {
        write_mismatch :=
            .Map_Write in descriptor.usage && descriptor.usage &~ {.Map_Write, .Copy_Src} != {}
        valid &= gpu_validate(
            device,
            !write_mismatch,
            "[Map_Write] used with something other than [Copy_Src]",
            loc,
        )
        read_mismatch :=
            .Map_Read in descriptor.usage && descriptor.usage &~ {.Map_Read, .Copy_Dst} != {}
        valid &= gpu_validate(
            device,
            !read_mismatch,
            "[Map_Read] used with something other than [Copy_Dst]",
            loc,
        )
    }

    usage := map_buffer_usage(descriptor.usage)

    if .Indirect in descriptor.usage {
        usage |= {.Storage_Read_Only, .Storage_Read_Write}
    }

    if .Query_Resolve in descriptor.usage {
        usage |= BUFFER_USES_TIMESTAMP_NORMALIZATION
    }

    if descriptor.mapped_at_creation {
        valid &= gpu_validate(
            device,
            is_multiple_of(descriptor.size, COPY_BUFFER_ALIGNMENT),
            "Unaligned size",
            loc,
        )
        if .Map_Write not_in descriptor.usage {
            // we are going to be copying into it, internally
            usage |= {.Copy_Dst}
        }
    } else {
        // We are required to zero out (initialize) all memory. This is done
        // on demand using buffer_clear which requires write transfer usage
        usage |= {.Copy_Dst}
    }

    if !valid {
        return {}, false
    }

    // Buffer sizes are subject to a few constraints:
    //
    // - Applications may request any byte-aligned size.
    // - Vertex buffers get an extra byte to allow simulating an empty range at
    //   the end, which Vulkan does not natively support.
    // - The final size must be a non-zero multiple of 4.
    //
    // Since initialization operates in 4-byte units, we eagerly zero-initialize
    // any bytes beyond the application-visible range.
    actual_size: u64
    if descriptor.size == 0 {
        actual_size = COPY_BUFFER_ALIGNMENT
    } else if .Vertex in descriptor.usage {
        actual_size = descriptor.size + 1
    } else {
        actual_size = descriptor.size
    }

    // round UP, from actual_size
    actual_size = align_size(actual_size, COPY_BUFFER_ALIGNMENT)
    // round DOWN, from ORIGINAL descriptor.size
    tail_start := descriptor.size &~ (COPY_BUFFER_ALIGNMENT - 1)
    assert(actual_size - 4 <= tail_start)

    return {
            label              = descriptor.label,
            size               = actual_size,
            visible_size       = descriptor.size,
            usage              = usage,
            tail_start         = tail_start,
            mapped_at_creation = descriptor.mapped_at_creation,
            memory_flags       = {},
        }, true
}

post_device_create_buffer :: proc(
    device: Device,
    buffer: Buffer,
    descriptor: Buffer_Descriptor_Impl,
    loc := #caller_location,
) -> bool {
    device_impl := _device_get_internal_impl(device, loc)
    buffer_impl := vk_buffer_get_impl(buffer, loc)

    buffer_impl.tracker_index = shared_tracker_index_allocator_alloc(
        &device_impl.tracker_indices.buffers,
    )

    // A CPU-visible buffer starts zero-filled and defined, matching WebGPU's
    // mapped-at-creation guarantee and C3's eager initialisation. Mapping marks
    // the whole allocation initialized.
    zero_buffer_mapping :: proc(buffer: Buffer, buffer_impl: ^VK_Buffer_Impl, size: u64) {
        ptr := buffer_map_sync(buffer, .Write, 0, uint(size))
        assert(ptr != nil)
        mem.set(ptr, 0, int(size))
        if !buffer_impl.is_coherent {
            buffer_flush_mapped_ranges(buffer, 0, uint(size))
        }
        buffer_unmap(buffer)
        buffer_init_tracker_mark_initialized(&buffer_impl.init, 0, size)
    }

    tail_start := descriptor.tail_start
    actual_size := descriptor.size

    buffer_use: Buffer_Uses
    if !descriptor.mapped_at_creation {
        if .Map_Write in descriptor.usage || .Map_Read in descriptor.usage {
            zero_buffer_mapping(buffer, buffer_impl, actual_size)
        } else if tail_start != descriptor.size {
            queue := device_get_queue(device, loc)
            defer queue_release(queue)
            queue_impl := vk_queue_get_impl(queue, loc)

            // The buffer has padding past its application-visible size, and
            // can't be zeroed through a map. Schedule the fill into the next
            // queue submission, so the padding is defined before any aligned
            // copy can read it.
            {
                sync.guard(&device_impl.trackers_mtx)
                device_buffer_tracker_insert_single(
                    &device_impl.trackers.buffers,
                    buffer_impl.tracker_index,
                    buffer,
                    {.Copy_Dst},
                )
            }
            vk_deferred_writes_clear_buffer(
                &queue_impl.deferred_writes,
                buffer,
                tail_start,
                actual_size - tail_start,
                loc,
            )

            return true
        }
    } else if .Map_Write in descriptor.usage {
        // Mapped-at-creation with Map_Write. Zero the whole allocation so
        // unwritten bytes read as zeros, then map the application-visible
        // portion separately, don't expose the tail to the app.
        zero_buffer_mapping(buffer, buffer_impl, actual_size)
        map_size := descriptor.visible_size
        mapping: Buffer_Mapping
        if map_size == 0 {
            mapping = {
                ptr         = nil,
                is_coherent = true,
            } // dangling
            // No mapping call below to count the transition, so count it here.
            intr.atomic_add(&vk_device_get_impl(device, loc).mapped_buffers, 1)
        } else {
            // `buffer_map_sync` counts the `Idle` -> `Active` transition.
            mapping.ptr = buffer_map_sync(buffer, .Write, 0, uint(map_size))
        }
        buffer_impl.map_state = Buffer_Map_State_Active {
            ptr         = mapping.ptr,
            is_coherent = mapping.is_coherent,
            range       = {0, map_size},
            mode        = .Write,
        }
        buffer_use = {.Map_Write}
    } else {
        // Mapped-at-creation without Map_Write. Zero-initialize a staging buffer
        // covering the entire buffer (including tail); a single mapping is fine
        // since get_mapped_range only exposes the application-visible range.
        // Unmapping copies it in and marks the range initialized.
        staging_buffer: Staging_Buffer
        if !staging_buffer_init_or_error(&staging_buffer, device, actual_size, loc) {
            gpu_report_error(
                device,
                .Out_Of_Memory,
                "failed to allocate buffer initialization staging buffer",
                loc,
            )
            return false
        }
        staging_buffer_write_zeros(&staging_buffer)

        buffer_impl.map_state = Buffer_Map_State_Init {
            staging_buffer = staging_buffer,
        }
        intr.atomic_add(&vk_device_get_impl(device, loc).mapped_buffers, 1)
        buffer_use = {.Copy_Dst}
    }

    {
        sync.guard(&device_impl.trackers_mtx)
        device_buffer_tracker_insert_single(
            &device_impl.trackers.buffers,
            buffer_impl.tracker_index,
            buffer,
            buffer_use,
        )
    }
    return true
}
