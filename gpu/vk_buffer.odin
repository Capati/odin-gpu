#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:sync"

// Vendor
import "lib/vma"
import gpua "allocator"
import vk "vendor:vulkan"

VK_Buffer_Handle :: distinct hm.Handle64

VK_Buffer_Impl :: struct {
    // Base
    using base:          Buffer_Impl,

    // Backend
    vma_allocation_info: vma.AllocationInfo,
    vma_allocation:      vma.Allocation,
    gpu_allocation:      gpua.VK_Allocation,
    vk_buffer:           vk.Buffer,
    vk_size:             vk.DeviceSize,
    handle:              VK_Buffer_Handle,
    vk_buffer_flags:     vk.BufferUsageFlags,
    vk_mem_flags:        vk.MemoryPropertyFlags,
    destroyed:           bool,
}

vk_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    impl := vk_device_get_impl(device, loc)

    desc := pre_device_create_buffer(device, descriptor, loc)

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

    should_map := .Map_Write in desc.usage

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

        vma_alloc_info.usage          = .AUTO
        vma_alloc_info.minAlignment   = 16
        vma_alloc_info.memoryTypeBits = impl.valid_memory_type_bits

        vma_allocation: vma.Allocation
        vma_allocation_info: vma.AllocationInfo
        vk_check(vma.CreateBuffer(
            impl.vma_allocator,
            vk_info,
            vma_alloc_info,
            &vk_buffer,
            &vma_allocation,
            &vma_allocation_info,
        ))

        if .HOST_VISIBLE in mem_flags {
            alloc_mem_flags: vk.MemoryPropertyFlags
            vma.GetAllocationMemoryProperties(
                impl.vma_allocator, vma_allocation, &alloc_mem_flags)
            is_coherent_memory = .HOST_COHERENT in alloc_mem_flags

            if .MAPPED in vma_alloc_info.flags {
                vk_check(vma.MapMemory(impl.vma_allocator, vma_allocation, &mapped_ptr))
            }
        }
    } else {
        // Create buffer
        vk_check(impl.fp.CreateBuffer(impl.vk_device, &vk_info, nil, &vk_buffer))

        requirements: vk.MemoryRequirements
        impl.fp.GetBufferMemoryRequirements(impl.vk_device, vk_buffer, &requirements)

        masked_requirements := requirements
        masked_requirements.memoryTypeBits &= impl.valid_memory_type_bits
        assert(masked_requirements.memoryTypeBits != 0,
            "VULKAN: no valid memory type for buffer allocation", loc)

        alloc_desc := gpua.VK_Allocation_Create_Desc{
            name              = desc.label,
            requirements      = masked_requirements,
            location          = vk_buffer_usage_to_location(desc.usage),
            linear            = true, // buffers are always linear
            allocation_scheme = gpua.VK_ALLOCATION_SCHEME_MANAGED,
        }

        gpu_allocation: gpua.VK_Allocation
        gpua.gpu_alloc_check(gpua.vk_allocator_allocate(
            &impl.gpu_allocator, alloc_desc, &gpu_allocation, loc))

        alloc_mem_flags := gpu_allocation.memory_properties
        is_coherent_memory = .HOST_COHERENT in alloc_mem_flags

        vk_check(impl.fp.BindBufferMemory(
            impl.vk_device,
            vk_buffer,
            gpu_allocation.device_memory,
            vk.DeviceSize(gpu_allocation.offset)))

        if should_map {
            assert(.HOST_VISIBLE in alloc_mem_flags,
                ".Map_Write buffer did not receive host-visible memory", loc)
            mapped_ptr = gpu_allocation.mapped_ptr
        }
    }

    buffer_impl, buffer_handle := add_impl(&impl.buffers, VK_Buffer_Impl {
        map_state       = Buffer_Map_State_Idle{},
        device          = device,
        vk_buffer       = vk_buffer,
        size            = desc.size,
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

    post_device_create_buffer(device, out, desc, loc)

    return out
}

@(require_results)
vk_buffer_get_public_impl :: #force_inline proc "contextless" (
    buffer: Buffer,
    loc := #caller_location,
) -> ^Buffer_Impl {
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
    impl := vk_buffer_get_impl(buffer, loc)

    if impl.destroyed {
        return
    }

    #partial switch _ in impl.map_state {
    case Buffer_Map_State_Init,
         Buffer_Map_State_Active,
         Buffer_Pending_Mapping:
        vk_buffer_unmap(buffer, loc)
    case Buffer_Map_State_Idle:
    }

    impl.destroyed = true

    device_impl := vk_device_get_impl(impl.device, loc)
    vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
        VK_Deferred_Buffer {
            buffer         = impl.vk_buffer,
            vma_allocation = impl.vma_allocation,
            gpu_allocation = impl.gpu_allocation,
        })
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

@(require_results)
vk_buffer_get_mapped_range_size :: proc(
    impl: ^VK_Buffer_Impl,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> u64 {
    allocated_size: u64
    #partial switch state in impl.map_state {
    case Buffer_Map_State_Active:
        allocated_size = u64(state.range.end)
    case Buffer_Pending_Mapping:
        allocated_size = u64(state.range.end)
    case Buffer_Map_State_Init:
        allocated_size = impl.size
    case:
        panic("mapped range size requested while buffer is not mapped", loc)
    }

    return resolve_mapped_range_size(allocated_size, size, offset, loc)
}

vk_buffer_get_mapped_range_active :: proc(
    impl: ^VK_Buffer_Impl,
    offset: uint = 0,
    range_size: u64,
    loc := #caller_location,
) -> rawptr {
    #partial switch &state in impl.map_state {
    case Buffer_Map_State_Active:
        assert(offset <= uint(state.range.end), "out of bounds start offset overrun", loc)
        assert(offset >= uint(state.range.start), "out of bounds start offset underrun", loc)
        assert(
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
    impl := vk_buffer_get_impl(buffer, loc)
    assert(!impl.destroyed, "buffer has been destroyed", loc)

    range_size := vk_buffer_get_mapped_range_size(impl, offset, size, loc)

    switch &state in impl.map_state {
    case Buffer_Map_State_Init:
        panic("const mapped range requested on a write-staged buffer", loc)

    case Buffer_Map_State_Active:
        return vk_buffer_get_mapped_range_active(impl, offset, range_size, loc)

    case Buffer_Pending_Mapping:
        panic("buffer is waiting on GPU sync before it can be mapped", loc)

    case Buffer_Map_State_Idle:
        panic("buffer is not mapped", loc)
    }

    unreachable()
}

vk_buffer_get_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    impl := vk_buffer_get_impl(buffer, loc)
    assert(!impl.destroyed, "buffer has been destroyed", loc)

    range_size := vk_buffer_get_mapped_range_size(impl, offset, size, loc)

    switch &state in impl.map_state {
    case Buffer_Map_State_Init:
        staging_impl := vk_buffer_get_impl(state.staging_buffer.buffer, loc)
        assert(offset <= uint(staging_impl.size), "map start offset overrun", loc)
        assert(u64(offset) + range_size <= staging_impl.size, "map end offset overrun", loc)
        return rawptr(uintptr(state.staging_buffer.ptr) + uintptr(offset))

    case Buffer_Map_State_Active:
        return vk_buffer_get_mapped_range_active(impl, offset, range_size, loc)

    case Buffer_Pending_Mapping:
        panic("buffer is waiting on GPU sync before it can be mapped", loc)

    case Buffer_Map_State_Idle:
        panic("buffer is not mapped", loc)
    }

    unreachable()
}

vk_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    unimplemented(loc = loc)
}

vk_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    impl := vk_buffer_get_impl(buffer, loc)
    return impl.size
}

vk_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    unimplemented(loc = loc)
}

vk_buffer_is_coherent :: proc(buffer: Buffer, loc := #caller_location) -> bool {
    impl := vk_buffer_get_impl(buffer, loc)
    return impl.is_coherent
}

vk_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future {
    impl := vk_buffer_get_impl(buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    adapter_impl := vk_adapter_get_impl(device_impl.adapter, loc)
    instance_impl := vk_instance_get_impl(adapter_impl.instance, loc)

    id := intr.atomic_add(&instance_impl.current_future_id, 1)
    instance_impl.pending_futures[id] = {
        resolve = vk_buffer_map_sync_resolve,
        userdata = Future_Data_For_Map_Buffer_Async {
            buffer        = buffer,
            mode          = mode,
            offset        = offset,
            size          = size,
            callback_info = callback_info,
            loc           = loc,
        },
    }

    return { id }
}

vk_buffer_map_sync_resolve :: proc(userdata: Future_Data) {
    #partial switch data in userdata {
    case Future_Data_For_Map_Buffer_Async:
        #force_inline vk_buffer_map_sync(
            data.buffer, data.mode, data.offset, data.size, data.loc)
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

    // resolve the WHOLE_MAP_SIZE sentinel to an actual size
    resolved_size := size
    if resolved_size == WHOLE_MAP_SIZE {
        assert(u64(offset) <= impl.size, "offset out of bounds", loc)
        resolved_size = uint(impl.size) - offset
    }

    when USE_VMA {
        vk_check(vma.MapMemory(device_impl.vma_allocator, impl.vma_allocation, &impl.mapped_ptr))
    } else {
        assert(impl.gpu_allocation.mapped_ptr != nil,
            "buffer's memory is not host-visible/mapped", loc)
        impl.mapped_ptr = rawptr(uintptr(impl.gpu_allocation.mapped_ptr) + uintptr(offset))
    }

    if mode == .Read && !impl.is_coherent {
        when USE_VMA {
            vk_check(vma.InvalidateAllocation(
                device_impl.vma_allocator, impl.vma_allocation, 0, vk.DeviceSize(vk.WHOLE_SIZE)))
        } else {
            range := vk.MappedMemoryRange{
                sType  = .MAPPED_MEMORY_RANGE,
                memory = impl.gpu_allocation.device_memory,
                offset = vk.DeviceSize(impl.gpu_allocation.offset) + vk.DeviceSize(offset),
                size   = vk.DeviceSize(resolved_size),
            }
            vk_check(device_impl.fp.InvalidateMappedMemoryRanges(device_impl.vk_device, 1, &range))
        }
    }

    impl.map_state = Buffer_Map_State_Active {
        mapping = { ptr = impl.mapped_ptr, is_coherent = impl.is_coherent },
        range   = { u64(offset), u64(offset) + u64(resolved_size) },
        mode    = mode,
    }

    return impl.mapped_ptr
}

vk_buffer_read_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    unimplemented(loc = loc)
}

vk_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    impl := vk_buffer_get_impl(buffer, loc)
    assert(!impl.destroyed, "buffer has been destroyed", loc)

    device_impl := vk_device_get_impl(impl.device, loc)

    mapping := impl.map_state
    impl.map_state = Buffer_Map_State_Idle{}
    impl.mapped_ptr = nil

    switch &state in mapping {
    case Buffer_Map_State_Init:
        staging_buffer := staging_buffer_flush(&state.staging_buffer, loc)

        // Copy the entire staging buffer, including any
        // zero-initialized padding.
        // region := Buffer_Copy {
        //     src_offset = 0,
        //     dst_offset = 0,
        //     size       = staging_buffer.size,
        // }

        transition_src := Buffer_Barrier {
            buffer = staging_buffer.buffer,
            usage = {
                from = {.Map_Write},
                to = {.Copy_Src},
            },
        }

        transition_dst := Buffer_Barrier {
            buffer = buffer,
            usage = {
                from = {},
                to = {.Copy_Dst},
            },
        }

        deferred_writes := &device_impl.queue.deferred_writes

        // Held across the whole record: there is a single scratch encoder, so this
        // is what keeps a concurrent unmap or queue write from recording into it
        // at the same time.
        sync.guard(&deferred_writes.mtx)

        encoder := deferred_writes_activate_locked(deferred_writes, loc)

        command_encoder_transition_buffers(encoder, {transition_src, transition_dst})
        command_encoder_copy_buffer_to_buffer(
            encoder,
            state.staging_buffer.buffer, 0,
            buffer, 0,
            staging_buffer.size)

        deferred_writes_insert_buffer_locked(deferred_writes, buffer)
        deferred_writes_consume_locked(deferred_writes, staging_buffer)

    case Buffer_Map_State_Idle:
        panic("buffer not mapped", loc)

    case Buffer_Pending_Mapping:
        // Mapping was requested but never resolved
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
    unimplemented(loc = loc)
}

vk_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    impl := vk_buffer_get_impl(buffer, loc)
    add_ref(impl, loc)
}

vk_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    impl := vk_buffer_get_impl(buffer, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)

        if !impl.destroyed {
            switch _ in impl.map_state {
            case Buffer_Map_State_Init,
                 Buffer_Map_State_Active,
                 Buffer_Pending_Mapping:
                vk_buffer_unmap(buffer, loc)
            case Buffer_Map_State_Idle:
                // nothing mapped, nothing to do
            }

            vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
                VK_Deferred_Buffer {
                    buffer         = impl.vk_buffer,
                    tracker_index  = impl.tracker_index,
                    vma_allocation = impl.vma_allocation,
                    gpu_allocation = impl.gpu_allocation,
                })
        }

        remove_handle_impl(&device_impl.buffers, impl.handle)
    }
}
