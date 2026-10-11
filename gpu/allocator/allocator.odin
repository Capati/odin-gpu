/*
GPU Memory allocator.

Ref:

https://docs.rs/gpu-allocator
*/
#+build !js
package gpu_allocator

// Core
import "base:runtime"
import "core:log"
import "core:mem"

ALLOCATION_NAME_LENGTH :: 128

// -----------------------------------------------------------------------
// Errors
// -----------------------------------------------------------------------

Allocator_Error :: enum byte {
    None,
    Out_Of_Memory,
    Failed_To_Map,
    No_Compatible_Memory_Type_Found,
    Invalid_Allocation_Create_Desc,
    Invalid_Allocator_Create_Desc,
    Internal,
}

// -----------------------------------------------------------------------
// Memory location
// -----------------------------------------------------------------------

// Where an allocation should live in GPU/CPU memory.
Memory_Location :: enum {
    // Let the driver decide the best location.
    Unknown,
    // GPU-only accessible memory. Most allocations should live here.
    Gpu_Only,
    // Useful for uploading data to the GPU and for constant buffers.
    Cpu_To_Gpu,
    // Useful for CPU readback of data.
    Gpu_To_Cpu,
}

// -----------------------------------------------------------------------
// Debug settings
// -----------------------------------------------------------------------

Allocator_Debug_Settings :: struct {
    log_memory_information: bool,
    log_leaks_on_shutdown:  bool,
    store_stack_traces:     bool, // NOTE: currently unused (no-ops)
    log_allocations:        bool,
    log_frees:              bool,
    log_stack_traces:       bool,
}

DEFAULT_ALLOCATOR_DEBUG_SETTINGS :: Allocator_Debug_Settings {
    log_memory_information = false,
    log_leaks_on_shutdown  = true,
    store_stack_traces     = false,
    log_allocations        = false,
    log_frees              = false,
    log_stack_traces       = false,
}

// -----------------------------------------------------------------------
// Allocation_Sizes
// -----------------------------------------------------------------------

MEMBLOCK_MB :: 1 * mem.Megabyte

// Controls the size of the shared memory blocks the allocator creates.
//
// Clamped between 4MB and 256MB, rounded up to the nearest multiple of 4MB.
// Only applies to shared blocks that can hold multiple sub-allocations —
// an allocation that doesn't fit gets its own dedicated block regardless of
// these limits.
Allocation_Sizes :: struct {
    min_device_memblock_size: u64,
    max_device_memblock_size: u64,
    min_host_memblock_size:   u64,
    max_host_memblock_size:   u64,
}

DEFAULT_ALLOCATION_SIZES :: Allocation_Sizes {
    min_device_memblock_size = 256 * MEMBLOCK_MB,
    max_device_memblock_size = 256 * MEMBLOCK_MB,
    min_host_memblock_size   = 64 * MEMBLOCK_MB,
    max_host_memblock_size   = 64 * MEMBLOCK_MB,
}

// Sets the minimum device and host memory block sizes; the maximums start out
// equal to the minimums (fixed-size blocks) until raised via
// `allocation_sizes_with_max_device_memblock_size` /
// `allocation_sizes_with_max_host_memblock_size`.
allocation_sizes_new :: proc(device_memblock_size, host_memblock_size: u64) -> Allocation_Sizes {
    device := allocation_sizes_adjust(device_memblock_size, "Device")
    host := allocation_sizes_adjust(host_memblock_size, "Host")
    return Allocation_Sizes{
        min_device_memblock_size = device,
        max_device_memblock_size = device,
        min_host_memblock_size   = host,
        max_host_memblock_size   = host,
    }
}

allocation_sizes_with_max_device_memblock_size :: proc(
    sizes: Allocation_Sizes,
    size: u64,
) -> Allocation_Sizes {
    sizes := sizes
    adjusted := allocation_sizes_adjust(size, "Device")
    sizes.max_device_memblock_size = max(adjusted, sizes.min_device_memblock_size)
    return sizes
}

allocation_sizes_with_max_host_memblock_size :: proc(
    sizes: Allocation_Sizes,
    size: u64,
) -> Allocation_Sizes {
    sizes := sizes
    adjusted := allocation_sizes_adjust(size, "Host")
    sizes.max_host_memblock_size = max(adjusted, sizes.min_host_memblock_size)
    return sizes
}

@(private)
allocation_sizes_adjust :: proc(size: u64, kind: string) -> u64 {
    size := size
    if size < 4 * MEMBLOCK_MB do size = 4 * MEMBLOCK_MB
    if size > 256 * MEMBLOCK_MB do size = 256 * MEMBLOCK_MB

    if size % (4 * MEMBLOCK_MB) == 0 {
        return size
    }

    val := size / (4 * MEMBLOCK_MB) + 1
    new_size := val * 4 * MEMBLOCK_MB
    log.warnf("%s memory block size must be a multiple of 4MB, clamping to %dMB",
        kind, new_size / MEMBLOCK_MB)
    return new_size
}

// Chooses the size of the next shared memory block for a memory type, given how
// many general-purpose blocks it already has. Doubles from `min` toward `max` as
// allocation count grows.
allocation_sizes_get_memblock_size :: proc "contextless" (
    self: Allocation_Sizes,
    is_host: bool,
    count: int,
) -> u64 {
    min_size := is_host ? self.min_host_memblock_size : self.min_device_memblock_size
    max_size := is_host ? self.max_host_memblock_size : self.max_device_memblock_size

    shift := u64(min(count, 7))
    result := min_size << shift
    if result > max_size {
        result = max_size
    }

    return result
}

// -----------------------------------------------------------------------
// Allocation_Type + reports (reconstructed: see file header note)
// -----------------------------------------------------------------------

Allocation_Type :: enum {
    // sentinel used internally by sub-allocators for an unused chunk
    Free,
    Linear,
    Non_Linear,
}

Allocation_Report :: struct {
    name:   [ALLOCATION_NAME_LENGTH]u8,
    offset: u64,
    size:   u64,
}

Allocation_Range :: struct {
    start: int,
    end:   int,
}

Memory_Block_Report :: struct {
    size:        u64,
    allocations: Allocation_Range,
}

Allocator_Report :: struct {
    allocations:           [dynamic]Allocation_Report,
    blocks:                [dynamic]Memory_Block_Report,
    total_allocated_bytes: u64,
    total_capacity_bytes:  u64,
}

allocator_report_destroy :: proc(r: ^Allocator_Report) {
    delete(r.allocations)
    delete(r.blocks)
}

USE_BEST_FIT :: #config(GPU_USE_BEST_FIT, true)

is_on_same_page :: proc "contextless" (offset_a, size_a, offset_b, page_size: u64) -> bool {
    end_a := offset_a + size_a - 1
    end_page_a := align_down(end_a, page_size)
    start_page_b := align_down(offset_b, page_size)
    return end_page_a == start_page_b
}

has_granularity_conflict :: proc "contextless" (type_a, type_b: Allocation_Type) -> bool {
    if type_a == .Free || type_b == .Free {
        return false
    }
    return type_a != type_b
}

// -----------------------------------------------------------------------
// Free_List_Allocator
// -----------------------------------------------------------------------

Memory_Chunk :: struct {
    chunk_id:        u64,
    size:            u64,
    offset:          u64,
    allocation_type: Allocation_Type,
    name:            [ALLOCATION_NAME_LENGTH]u8,
    next:            u64,
    prev:            u64,
}

// Unsynchronized sub-allocator. Callers must serialize operations on an instance;
// Vulkan memory types provide that serialization with their per-type RW_Mutex.
Free_List_Allocator :: struct {
    size:             u64,
    allocated:        u64,
    chunk_id_counter: u64,
    chunks:           map[u64]Memory_Chunk,
    free_chunks:      map[u64]bool, // set of free chunk ids
    allocator:        runtime.Allocator,
}

free_list_allocator_init :: proc(
    self: ^Free_List_Allocator,
    size: u64,
    backing_allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(self != nil, "Invalid free list allocator object", loc)
    self^ = {} // reset memory
    self.size = size
    self.chunk_id_counter = 2 // id 1 is taken by the initial chunk below
    self.chunks = make(map[u64]Memory_Chunk, backing_allocator)
    self.free_chunks = make(map[u64]bool, backing_allocator)
    self.allocator = backing_allocator
    self.chunks[1] = Memory_Chunk{
        chunk_id = 1,
        size = size,
        offset = 0,
        allocation_type = .Free,
    }
    self.free_chunks[1] = true
}

free_list_allocator_uninit :: proc(self: ^Free_List_Allocator, loc := #caller_location) {
    assert(self != nil, "Invalid free list allocator object", loc)
    context.allocator = self.allocator
    delete(self.chunks)
    delete(self.free_chunks)
    self^ = {} // reset memory
}

@(private)
free_list_next_chunk_id :: proc(
    self: ^Free_List_Allocator,
    loc := #caller_location,
) -> (
    id: u64,
    err: Allocator_Error,
) {
    assert(self != nil, "Invalid free list allocator object", loc)
    if self.chunk_id_counter == max(u64) {
        return 0, .Out_Of_Memory // end of the id counter, no more allocations possible
    }
    id = self.chunk_id_counter
    self.chunk_id_counter += 1
    return id, .None
}

// Merges `chunk_right` into `chunk_left` and removes `chunk_right`.
@(private)
free_list_merge_chunks :: proc(
    self: ^Free_List_Allocator,
    chunk_left, chunk_right: u64,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "Invalid free list allocator object", loc)
    right, right_ok := self.chunks[chunk_right]
    if !right_ok {
        return .Internal
    }
    delete_key(&self.chunks, chunk_right)
    delete_key(&self.free_chunks, chunk_right)

    left, left_ok := self.chunks[chunk_left]
    if !left_ok {
        return .Internal
    }
    left.next = right.next
    left.size += right.size
    self.chunks[chunk_left] = left

    if right.next != 0 {
        right_next, ok := self.chunks[right.next]
        if !ok {
            return .Internal
        }
        right_next.prev = chunk_left
        self.chunks[right.next] = right_next
    }

    return .None
}

free_list_allocator_allocate :: proc(
    self: ^Free_List_Allocator,
    size, alignment: u64,
    allocation_type: Allocation_Type,
    granularity: u64,
    name: string,
    loc := #caller_location,
) -> (
    offset: u64,
    chunk_id: u64,
    err: Allocator_Error,
) {
    assert(self != nil, "Invalid free list allocator object", loc)

    free_size := self.size - self.allocated
    if size > free_size {
        return 0, 0, .Out_Of_Memory
    }

    best_fit_id: u64
    best_offset: u64
    best_aligned_size: u64
    best_chunk_size: u64

    for id in self.free_chunks {
        chunk, ok := self.chunks[id]
        if !ok {
            return 0, 0, .Internal
        }
        if chunk.size < size {
            continue
        }

        off := u64(mem.align_forward_int(int(chunk.offset), int(alignment)))

        if chunk.prev != 0 {
            prev, prev_ok := self.chunks[chunk.prev]
            if !prev_ok {
                return 0, 0, .Internal
            }
            if is_on_same_page(prev.offset, prev.size, off, granularity) \
                    && has_granularity_conflict(prev.allocation_type, allocation_type) {
                off = u64(mem.align_forward_int(int(off), int(granularity)))
            }
        }

        padding := off - chunk.offset
        aligned_size := padding + size
        if aligned_size > chunk.size {
            continue
        }

        if chunk.next != 0 {
            next, next_ok := self.chunks[chunk.next]
            if !next_ok {
                return 0, 0, .Internal
            }
            if is_on_same_page(off, size, next.offset, granularity) \
                    && has_granularity_conflict(allocation_type, next.allocation_type) {
                continue
            }
        }

        when USE_BEST_FIT {
            if best_fit_id == 0 || chunk.size < best_chunk_size {
                best_fit_id = id
                best_aligned_size = aligned_size
                best_offset = off
                best_chunk_size = chunk.size
            }
        } else {
            best_fit_id = id
            best_aligned_size = aligned_size
            best_offset = off
            best_chunk_size = chunk.size
            break
        }
    }

    if best_fit_id == 0 {
        return 0, 0, .Out_Of_Memory
    }
    first_fit_id := best_fit_id

    result_id: u64

    current_name := len(name) > 0 ? name : "<Unnamed FreeList allocation>"

    if best_chunk_size > best_aligned_size {
        // Peel a new "used" chunk off the front of the matched free chunk;
        // the free chunk shrinks in place and keeps its own id as the
        // trailing remainder.
        new_id, id_err := free_list_next_chunk_id(self)
        if id_err != .None {
            return 0, 0, id_err
        }

        free_chunk, ok := self.chunks[first_fit_id]
        if !ok {
            return 0, 0, .Internal
        }

        new_chunk := Memory_Chunk{
            chunk_id        = new_id,
            size            = best_aligned_size,
            offset          = free_chunk.offset,
            allocation_type = allocation_type,
            prev            = free_chunk.prev,
            next            = first_fit_id,
        }

        str_copy_to_array(new_chunk.name[:], current_name)

        free_chunk.prev = new_id
        free_chunk.offset += best_aligned_size
        free_chunk.size -= best_aligned_size
        self.chunks[first_fit_id] = free_chunk

        if new_chunk.prev != 0 {
            prev_chunk, prev_ok := self.chunks[new_chunk.prev]
            if !prev_ok {
                return 0, 0, .Internal
            }
            prev_chunk.next = new_id
            self.chunks[new_chunk.prev] = prev_chunk
        }

        self.chunks[new_id] = new_chunk
        result_id = new_id
    } else {
        // Perfect fit (padding + size == the free chunk's size): reuse
        // the free chunk's own id instead of splitting.
        chunk, ok := self.chunks[first_fit_id]
        if !ok {
            return 0, 0, .Internal
        }
        chunk.allocation_type = allocation_type
        chunk.name = {}
        str_copy_to_array(chunk.name[:], current_name)
        self.chunks[first_fit_id] = chunk

        delete_key(&self.free_chunks, first_fit_id)
        result_id = first_fit_id
    }

    self.allocated += best_aligned_size
    return best_offset, result_id, .None
}

free_list_allocator_free :: proc(
    self: ^Free_List_Allocator,
    id: u64,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "Invalid free list allocator object", loc)

    if id == 0 { return .Internal }

    chunk, ok := self.chunks[id]
    if !ok { return .Internal }

    chunk.allocation_type = .Free
    chunk.name = {}
    self.allocated -= chunk.size
    self.chunks[id] = chunk
    self.free_chunks[id] = true

    next_id := chunk.next
    prev_id := chunk.prev

    if next_id != 0 {
        next_chunk, next_ok := self.chunks[next_id]
        if next_ok && next_chunk.allocation_type == .Free {
            free_list_merge_chunks(self, id, next_id) or_return
        }
    }

    if prev_id != 0 {
        prev_chunk, prev_ok := self.chunks[prev_id]
        if prev_ok && prev_chunk.allocation_type == .Free {
            free_list_merge_chunks(self, prev_id, id) or_return
        }
    }

    return .None
}

free_list_allocator_rename :: proc(
    self: ^Free_List_Allocator,
    id: u64,
    name: string,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "Invalid free list allocator object", loc)
    if id == 0 { return .Internal }
    chunk, ok := self.chunks[id]
    if !ok { return .Internal }
    if chunk.allocation_type == .Free {
        return .Internal // attempting to rename a freed allocation
    }
    str_copy_to_array(chunk.name[:], name)
    self.chunks[id] = chunk
    return .None
}

free_list_allocator_report_allocations :: proc(
    self: ^Free_List_Allocator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Allocation_Report {
    assert(self != nil, "Invalid free list allocator object", loc)
    reports := make([dynamic]Allocation_Report, allocator)
    for _, chunk in self.chunks {
        if chunk.allocation_type == .Free {
            continue
        }
        append(&reports, Allocation_Report{
            name = chunk.name,
            offset = chunk.offset,
            size = chunk.size,
        })
    }
    return reports[:]
}

free_list_allocator_report_memory_leaks :: proc(
    self: ^Free_List_Allocator,
    memory_type_index, memory_block_index: int,
    loc := #caller_location,
) {
    assert(self != nil, "Invalid free list allocator object", loc)
    for id, &chunk in self.chunks {
        if chunk.allocation_type == .Free {
            continue
        }
        name := len(chunk.name) > 0 \
            ? str_from_array(chunk.name[:]) \
            : "<Unnamed FreeList allocation>"
        log.warnf("leak detected: {{" +
            "chunk_id: %d, size: 0x%x, " +
            "offset: 0x%x, " +
            "memory type: %d, " +
            "memory block: %d, " +
            "name: %s}}",
            id, chunk.size, chunk.offset, memory_type_index, memory_block_index, name)
    }
}

// -----------------------------------------------------------------------
// Dedicated_Block_Allocator
// -----------------------------------------------------------------------

// Unsynchronized sub-allocator. Callers must serialize operations on an instance;
// Vulkan memory types provide that serialization with their per-type RW_Mutex.
Dedicated_Block_Allocator :: struct {
    size:      u64,
    allocated: u64,
    name:      [ALLOCATION_NAME_LENGTH]u8,
    allocator: runtime.Allocator,
}

dedicated_block_allocator_init :: proc(
    self: ^Dedicated_Block_Allocator,
    size: u64,
    backing_allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(self != nil, "Invalid dedicated block allocator object", loc)
    self.size = size
    self.allocator = backing_allocator
}

dedicated_block_allocator_uninit :: proc(
    self: ^Dedicated_Block_Allocator,
    loc := #caller_location,
) {
    assert(self != nil, "Invalid dedicated block allocator object", loc)
    context.allocator = self.allocator
}

dedicated_block_allocator_allocate :: proc(
    self: ^Dedicated_Block_Allocator,
    size, alignment: u64,
    allocation_type: Allocation_Type,
    granularity: u64,
    name: string,
    loc := #caller_location,
) -> (
    offset: u64,
    chunk_id: u64,
    err: Allocator_Error,
) {
    assert(self != nil, "Invalid dedicated block allocator object", loc)
    if self.allocated != 0 {
        // a dedicated block only ever holds one allocation
        return 0, 0, .Out_Of_Memory
    }
    if self.size != size {
        // dedicated block size must match the allocation size
        return 0, 0, .Internal
    }
    self.allocated = size
    current_name := len(name) > 0 ? name : "<Unnamed Dedicated allocation>"
    str_copy_to_array(self.name[:], current_name)
    // chunk_id 1 is the sentinel for "the one allocation"
    return 0, 1, .None
}

dedicated_block_allocator_free :: proc(
    self: ^Dedicated_Block_Allocator,
    id: u64,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "Invalid dedicated block allocator object", loc)
    if id != 1 {
        return .Internal
    }
    self.allocated = 0
    self.name = {}
    return .None
}

dedicated_block_allocator_rename :: proc(
    self: ^Dedicated_Block_Allocator,
    id: u64,
    name: string,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "Invalid dedicated block allocator object", loc)
    if id != 1 {
        return .Internal
    }
    str_copy_to_array(self.name[:], name)
    return .None
}

dedicated_block_allocator_report_allocations :: proc(
    self: ^Dedicated_Block_Allocator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Allocation_Report {
    reports := make([dynamic]Allocation_Report, allocator, loc = loc)
    if self.allocated != 0 {
        name := len(self.name) > 0 \
            ? str_from_array(self.name[:]) \
            : "<Unnamed Dedicated allocation>"
        append(&reports, Allocation_Report{offset = 0, size = self.size})
        last_report := &reports[len(reports)-1]
        str_copy_to_array(last_report.name[:], name)
    }
    return reports[:]
}

dedicated_block_allocator_report_memory_leaks :: proc(
    self: ^Dedicated_Block_Allocator,
    memory_type_index, memory_block_index: int,
    loc := #caller_location,
) {
    if self.allocated == 0 {
        return
    }
    name := len(self.name) > 0 \
        ? str_from_array(self.name[:]) \
        : "<Unnamed Dedicated allocation>"
    log.warnf(
        "leak detected: {{" +
        "size: 0x%x, " +
        "memory type: %d, " +
        "memory block: %d, " +
        "name: %s, " +
        "dedicated: true}}",
        self.size, memory_type_index, memory_block_index, name)
}

// -----------------------------------------------------------------------
// Sub_Allocator
// -----------------------------------------------------------------------

Sub_Allocator :: union {
    Free_List_Allocator,
    Dedicated_Block_Allocator,
}

sub_allocator_destroy :: proc(self: ^Sub_Allocator, loc := #caller_location) {
    switch &v in self^ {
    case Free_List_Allocator:
        free_list_allocator_uninit(&v, loc)
    case Dedicated_Block_Allocator:
        dedicated_block_allocator_uninit(&v, loc)
    }
}

sub_allocator_allocate :: proc(
    self: ^Sub_Allocator,
    size, alignment: u64,
    allocation_type: Allocation_Type,
    granularity: u64,
    name: string,
    loc := #caller_location,
) -> (
    offset: u64,
    chunk_id: u64,
    err: Allocator_Error,
) {
    switch &v in self^ {
    case Free_List_Allocator:
        return free_list_allocator_allocate(
            &v, size, alignment, allocation_type, granularity, name, loc)
    case Dedicated_Block_Allocator:
        return dedicated_block_allocator_allocate(
            &v, size, alignment, allocation_type, granularity, name, loc)
    }
    return 0, 0, .Internal
}

sub_allocator_free :: proc(
    self: ^Sub_Allocator,
    id: u64,
    loc := #caller_location,
) -> Allocator_Error {
    switch &v in self^ {
    case Free_List_Allocator:
        return free_list_allocator_free(&v, id, loc)
    case Dedicated_Block_Allocator:
        return dedicated_block_allocator_free(&v, id, loc)
    }
    return .Internal
}

sub_allocator_rename_allocation :: proc(
    self: ^Sub_Allocator,
    id: u64,
    name: string,
    loc := #caller_location,
) -> Allocator_Error {
    switch &v in self^ {
    case Free_List_Allocator:
        return free_list_allocator_rename(&v, id, name, loc)
    case Dedicated_Block_Allocator:
        return dedicated_block_allocator_rename(&v, id, name, loc)
    }
    return .Internal
}

sub_allocator_is_empty :: proc(self: ^Sub_Allocator) -> bool {
    switch v in self^ {
    case Free_List_Allocator:
        return v.allocated == 0
    case Dedicated_Block_Allocator:
        return v.allocated == 0
    }
    return true
}

sub_allocator_supports_general_allocations :: proc(sa: ^Sub_Allocator) -> bool {
    switch _ in sa^ {
    case Free_List_Allocator:
        return true
    case Dedicated_Block_Allocator:
        return false
    }
    return false
}

sub_allocator_report_allocations :: proc(
    self: ^Sub_Allocator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Allocation_Report {
    switch &v in self^ {
    case Free_List_Allocator:
        return free_list_allocator_report_allocations(&v, allocator, loc)
    case Dedicated_Block_Allocator:
        return dedicated_block_allocator_report_allocations(&v, allocator, loc)
    }
    unreachable()
}

sub_allocator_report_memory_leaks :: proc(
    self: ^Sub_Allocator,
    memory_type_index, memory_block_index: int,
    loc := #caller_location,
) {
    switch &v in self^ {
    case Free_List_Allocator:
        free_list_allocator_report_memory_leaks(&v, memory_type_index, memory_block_index, loc)
    case Dedicated_Block_Allocator:
        dedicated_block_allocator_report_memory_leaks(
            &v, memory_type_index, memory_block_index, loc)
    }
}

allocator_allocate :: proc {
    free_list_allocator_allocate,
    dedicated_block_allocator_allocate,
}

allocator_free :: proc {
    free_list_allocator_free,
    dedicated_block_allocator_free,
}

allocator_rename :: proc {
    free_list_allocator_rename,
    dedicated_block_allocator_rename,
}
