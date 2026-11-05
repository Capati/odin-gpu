#+build !js
package gpu

// Core
import "core:mem"

VK_STAGING_RING_SIZE      :: u64(4 * 1024 * 1024)
VK_STAGING_RING_ALIGNMENT :: u64(64 * 1024)

VK_Staging_Ring :: struct {
    buffer:       Buffer,
    ptr:          rawptr,
    size:         u64,
    first_offset: u64,
    last_offset:  u64,
    live_count:   u32,
}

VK_Staging_Reclaim :: struct {
    value:   u64,
    ring:    ^VK_Staging_Ring,
    abs_end: u64,
}

VK_Staging_Reservation :: struct {
    ring:   ^VK_Staging_Ring,
    offset: u64,
    size:   u64,
}

vk_staging_create_ring :: proc(
    device_impl: ^VK_Device_Impl,
    size: u64,
    loc := #caller_location,
) -> ^VK_Staging_Ring {
    desc := Buffer_Descriptor {
        label = "VK staging ring",
        size  = size,
        usage = {.Map_Write, .Copy_Src},
    }
    buffer := device_create_buffer(Device(device_impl), desc, loc)
    ensure(buffer != {}, "failed to create staging ring", loc)

    ptr := buffer_map_sync(buffer, .Write, 0, WHOLE_MAP_SIZE, loc)
    ensure(ptr != nil, "failed to map staging ring", loc)

    ring := new(VK_Staging_Ring, device_impl.allocator)
    ring.buffer = buffer
    ring.ptr = ptr
    ring.size = size
    return ring
}

@(require_results)
vk_staging_ring_reserve :: proc(
    ring: ^VK_Staging_Ring,
    reservation, alignment: u64,
    offset: ^u64,
) -> bool {
    start := align_size(ring.last_offset, alignment)
    if start % ring.size + reservation > ring.size {
        start = align_size(start, ring.size)
    }
    end := start + reservation
    if end - ring.first_offset > ring.size {
        return false
    }
    ring.last_offset = end
    ring.live_count += 1
    offset^ = start % ring.size
    return true
}

@(require_results)
vk_staging_reserve :: proc(
    device_impl: ^VK_Device_Impl,
    size, alignment: u64,
    loc := #caller_location,
) -> (
    reservation: VK_Staging_Reservation,
    ok: bool,
) {
    if size == 0 {
        return {}, false
    }
    align := alignment
    if align == 0 {
        align = 1
    }

    target: ^VK_Staging_Ring
    offset: u64
    for ring in device_impl.staging_rings {
        if vk_staging_ring_reserve(ring, size, align, &offset) {
            target = ring
            break
        }
    }

    if target == nil {
        capacity := VK_STAGING_RING_SIZE
        if size > capacity {
            capacity = align_size(size, VK_STAGING_RING_ALIGNMENT)
        }
        target = vk_staging_create_ring(device_impl, capacity, loc)
        append(&device_impl.staging_rings, target)
        reserved := vk_staging_ring_reserve(target, size, align, &offset)
        ensure(reserved, "a fresh staging ring cannot fit its first reservation", loc)
    }

    append(&device_impl.staging_reclaims, VK_Staging_Reclaim {
        value   = device_impl.submitter.next_submission_value + 1,
        ring    = target,
        abs_end = target.last_offset,
    })

    return {ring = target, offset = offset, size = size}, true
}

vk_staging_write :: proc(
    reservation: VK_Staging_Reservation,
    data: rawptr,
    data_offset, ring_offset, size: u64,
    loc := #caller_location,
) {
    ensure(
        ring_offset <= reservation.size && size <= reservation.size - ring_offset,
        "staged write exceeds its reservation",
        loc,
    )
    mem.copy_non_overlapping(
        rawptr(uintptr(reservation.ring.ptr) + uintptr(reservation.offset + ring_offset)),
        rawptr(uintptr(data) + uintptr(data_offset)),
        int(size),
    )
}

vk_staging_flush :: proc(reservation: VK_Staging_Reservation, loc := #caller_location) {
    buffer_flush_mapped_ranges(
        reservation.ring.buffer,
        uint(reservation.offset),
        uint(reservation.size),
        loc,
    )
}

vk_staging_reap :: proc(device_impl: ^VK_Device_Impl, completed: u64) {
    first := 0
    for first < len(device_impl.staging_reclaims) {
        reclaim := device_impl.staging_reclaims[first]
        if reclaim.value > completed {
            break
        }
        first += 1

        ring := reclaim.ring
        ring.first_offset = reclaim.abs_end
        if ring.live_count > 0 {
            ring.live_count -= 1
        }
        if ring.live_count == 0 {
            ring.first_offset = 0
            ring.last_offset = 0
        }
    }

    if first > 0 {
        remaining := len(device_impl.staging_reclaims) - first
        if remaining > 0 {
            mem.copy_non_overlapping(
                raw_data(device_impl.staging_reclaims),
                raw_data(device_impl.staging_reclaims[first:]),
                remaining * size_of(VK_Staging_Reclaim),
            )
        }
        resize(&device_impl.staging_reclaims, remaining)
    }
}

vk_staging_uninit :: proc(device_impl: ^VK_Device_Impl, loc := #caller_location) {
    for ring in device_impl.staging_rings {
        buffer_unmap(ring.buffer, loc)
        buffer_destroy(ring.buffer, loc)
        free(ring, device_impl.allocator)
    }
    delete(device_impl.staging_rings)
    delete(device_impl.staging_reclaims)
    device_impl.staging_rings = nil
    device_impl.staging_reclaims = nil
}
