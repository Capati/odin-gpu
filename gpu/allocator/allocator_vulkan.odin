#+build !js
package gpu_allocator

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

// -----------------------------------------------------------------------
// VK_Allocation
// -----------------------------------------------------------------------

VK_Allocation :: struct {
    chunk_id:             u64,
    offset:               u64,
    size:                 u64,
    memory_block_index:   int,
    memory_type_index:    int,
    device_memory:        vk.DeviceMemory,
    mapped_ptr:           rawptr,
    dedicated_allocation: bool,
    memory_properties:    vk.MemoryPropertyFlags,
    name:                 [ALLOCATION_NAME_LENGTH]u8,
}

vk_allocation_is_null :: proc(a: ^VK_Allocation) -> bool {
    return a.chunk_id == 0
}

vk_allocation_mapped_slice :: proc(a: ^VK_Allocation) -> []byte {
    if a.mapped_ptr == nil {
        return nil
    }
    return ([^]byte)(a.mapped_ptr)[:a.size]
}

// -----------------------------------------------------------------------
// VK_Memory_Block
// -----------------------------------------------------------------------

VK_Memory_Block :: struct {
    device_memory: vk.DeviceMemory,
    size:          u64,
    mapped_ptr:    rawptr,
    sub_allocator: Sub_Allocator,
    dedicated:     bool,
}

@(private="file")
@(optimization_mode="favor_size")
vk_memory_block_ptr :: proc "contextless" (
    memory_blocks: []Maybe(VK_Memory_Block),
    #any_int index: int,
) -> (
    block: ^VK_Memory_Block,
    err: Allocator_Error,
) #no_bounds_check {
    if m, m_ok := &memory_blocks[index].?; m_ok {
        return m, .None
    }
    return nil, .Internal
}

vk_memory_block_new :: proc(
    device: vk.Device,
    fp: VK_Functions,
    size: u64,
    mem_type_index: int,
    mapped: bool,
    buffer_device_address: bool,
    scheme: VK_Allocation_Scheme,
    requires_personal_block: bool,
    block: ^VK_Memory_Block,
    backing_allocator: runtime.Allocator,
) -> (
    err: Allocator_Error,
) {
    flags_info := vk.MemoryAllocateFlagsInfo{
        sType = .MEMORY_ALLOCATE_FLAGS_INFO,
        flags = {.DEVICE_ADDRESS},
    }
    dedicated_info := vk.MemoryDedicatedAllocateInfo{
        sType = .MEMORY_DEDICATED_ALLOCATE_INFO,
    }

    alloc_info := vk.MemoryAllocateInfo{
        sType           = .MEMORY_ALLOCATE_INFO,
        allocationSize  = vk.DeviceSize(size),
        memoryTypeIndex = u32(mem_type_index),
    }

    if buffer_device_address {
        flags_info.pNext = alloc_info.pNext
        alloc_info.pNext = &flags_info
    }

    switch scheme.kind {
    case .Dedicated_Buffer:
        dedicated_info.buffer = scheme.buffer
        dedicated_info.pNext = alloc_info.pNext
        alloc_info.pNext = &dedicated_info
    case .Dedicated_Image:
        dedicated_info.image = scheme.image
        dedicated_info.pNext = alloc_info.pNext
        alloc_info.pNext = &dedicated_info
    case .Gpu_Allocator_Managed:
        // nothing extra to chain
    }

    device_memory: vk.DeviceMemory
    alloc_result := fp.AllocateMemory(device, &alloc_info, nil, &device_memory)
    if alloc_result != .SUCCESS {
        if alloc_result == .ERROR_OUT_OF_DEVICE_MEMORY {
            return .Out_Of_Memory
        }
        log.errorf("unexpected error in vkAllocateMemory: %v", alloc_result)
        return .Internal
    }

    defer if err != .None {
        fp.FreeMemory(device, device_memory, nil)
    }

    mapped_ptr: rawptr
    if mapped {
        map_result := fp.MapMemory(
            device, device_memory, 0, vk.DeviceSize(vk.WHOLE_SIZE), {}, &mapped_ptr)
        if map_result != .SUCCESS {
            log.errorf("failed to map memory: %v", map_result)
            return .Failed_To_Map
        }
        if mapped_ptr == nil {
            log.error("vkMapMemory returned a null pointer")
            return .Failed_To_Map
        }
    }

    sub_allocator: Sub_Allocator
    dedicated := scheme.kind != .Gpu_Allocator_Managed
    if dedicated || requires_personal_block {
        sub_allocator = Dedicated_Block_Allocator{}
        dedicated_block_allocator_init(
            &sub_allocator.(Dedicated_Block_Allocator),
            size,
            backing_allocator)
    } else {
        sub_allocator = Free_List_Allocator{}
        free_list_allocator_init(
            &sub_allocator.(Free_List_Allocator),
            size,
            backing_allocator)
    }

    block^ = {
        device_memory = device_memory,
        size          = size,
        mapped_ptr    = mapped_ptr,
        sub_allocator = sub_allocator,
        dedicated     = dedicated,
    }

    return .None
}

vk_memory_block_destroy :: proc(
    self: ^VK_Memory_Block,
    device: vk.Device,
    fp: VK_Functions,
    loc := #caller_location,
) {
    assert(self != nil, "Invalid VK memory block", loc)
    if self.mapped_ptr != nil {
        fp.UnmapMemory(device, self.device_memory)
    }
    fp.FreeMemory(device, self.device_memory, nil)
    sub_allocator_destroy(&self.sub_allocator)
    self^ = {}
}

// -----------------------------------------------------------------------
// VK_Memory_Type
// -----------------------------------------------------------------------

VK_Memory_Type :: struct {
    memory_blocks:         [dynamic]Maybe(VK_Memory_Block),
    memory_properties:     vk.MemoryPropertyFlags,
    memory_type_index:     int,
    heap_index:            int,
    mappable:              bool,
    active_general_blocks: int,
    buffer_device_address: bool,
    allocator:             runtime.Allocator,
    // Protects memory_blocks and every sub-allocator it contains. Each memory
    // type is independent, so allocations using different memory types proceed
    // concurrently. All entry points acquire this before accessing block state.
    mtx:                   sync.RW_Mutex,
}

vk_memory_type_allocate :: proc(
    self: ^VK_Memory_Type,
    device: vk.Device,
    fp: VK_Functions,
    desc: VK_Allocation_Create_Desc,
    granularity: u64,
    allocation_sizes: Allocation_Sizes,
    allocation: ^VK_Allocation,
) -> (
    err: Allocator_Error,
) {
    sync.guard(&self.mtx)
    return vk_memory_type_allocate_locked(
        self, device, fp, desc, granularity, allocation_sizes, allocation)
}

@(private = "file")
// Caller must hold `self.mtx` exclusively.
vk_memory_type_allocate_locked :: proc(
    self: ^VK_Memory_Type,
    device: vk.Device,
    fp: VK_Functions,
    desc: VK_Allocation_Create_Desc,
    granularity: u64,
    allocation_sizes: Allocation_Sizes,
    allocation: ^VK_Allocation,
) -> (
    err: Allocator_Error,
) {
    allocation_type := Allocation_Type.Non_Linear
    if desc.linear {
        allocation_type = .Linear
    }

    is_host := .HOST_VISIBLE in self.memory_properties
    memblock_size := allocation_sizes_get_memblock_size(
        allocation_sizes, is_host, self.active_general_blocks)

    size := u64(desc.requirements.size)
    alignment := u64(desc.requirements.alignment)

    dedicated_allocation := desc.allocation_scheme.kind != .Gpu_Allocator_Managed
    requires_personal_block := size > memblock_size

    current_name := len(desc.name) > 0 ? desc.name : "<Unnamed vk allocation>"

    // Dedicated / oversized allocations always get their own block
    if dedicated_allocation || requires_personal_block {
        new_block: VK_Memory_Block
        vk_memory_block_new(
            device,
            fp,
            size,
            self.memory_type_index,
            self.mappable,
            self.buffer_device_address,
            desc.allocation_scheme,
            requires_personal_block,
            &new_block,
            self.allocator,
        ) or_return

        defer if err != .None {
            vk_memory_block_destroy(&new_block, device, fp)
        }

        block_index := -1
        for i in 0 ..< len(self.memory_blocks) {
            if _, occupied := self.memory_blocks[i].?; !occupied {
                block_index = i
                break
            }
        }
        if block_index < 0 {
            append(&self.memory_blocks, new_block)
            block_index = len(self.memory_blocks) - 1
        } else {
            self.memory_blocks[block_index] = new_block
        }

        mem_block := vk_memory_block_ptr(self.memory_blocks[:], block_index) or_return

        offset, chunk_id := sub_allocator_allocate(
            &mem_block.sub_allocator,
            size,
            alignment,
            allocation_type,
            granularity,
            current_name) or_return

        allocation^ = {
            chunk_id             = chunk_id,
            offset               = offset,
            size                 = size,
            memory_block_index   = block_index,
            memory_type_index    = self.memory_type_index,
            device_memory        = mem_block.device_memory,
            mapped_ptr           = mem_block.mapped_ptr,
            memory_properties    = self.memory_properties,
            dedicated_allocation = dedicated_allocation,
        }

        str_copy_to_array(allocation.name[:], current_name)

        return .None
    }

    // General allocations: try to fit into an existing shared block, searching
    // newest-first. Tracks the highest empty slot while scanning for reuse if a
    // new block is needed.
    empty_block_index := -1
    for i := len(self.memory_blocks) - 1; i >= 0; i -= 1 {
        mem_block, mb_err := vk_memory_block_ptr(self.memory_blocks[:], i)
        if mb_err != .None {
            if empty_block_index < 0 {
                empty_block_index = i
            }
            continue // empty slot
        }
        if !sub_allocator_supports_general_allocations(&mem_block.sub_allocator) {
            continue // dedicated/oversized block, cannot host shared allocations
        }

        offset, chunk_id, alloc_err := sub_allocator_allocate(
            &mem_block.sub_allocator,
            size,
            alignment,
            allocation_type,
            granularity,
            current_name)
        if alloc_err == .None {
            mapped_ptr: rawptr
            if mem_block.mapped_ptr != nil {
                mapped_ptr = rawptr(uintptr(mem_block.mapped_ptr) + uintptr(offset))
            }
            allocation^ = {
                chunk_id             = chunk_id,
                offset               = offset,
                size                 = size,
                memory_block_index   = i,
                memory_type_index    = self.memory_type_index,
                device_memory        = mem_block.device_memory,
                memory_properties    = self.memory_properties,
                mapped_ptr           = mapped_ptr,
                dedicated_allocation = false,
            }
            str_copy_to_array(allocation.name[:], current_name)
            return .None
        } else if alloc_err != .Out_Of_Memory {
            return alloc_err // a real error, not just "this block is full"
        }
        // else: block is full, keep searching.
    }

    // No existing block had room: grow a new shared block,
    // reusing the empty slot found during the scan above when available.
    new_block: VK_Memory_Block
    vk_memory_block_new(
        device,
        fp,
        memblock_size,
        self.memory_type_index,
        self.mappable,
        self.buffer_device_address,
        desc.allocation_scheme,
        false,
        &new_block,
        self.allocator,
    ) or_return

    new_block_index: int
    if empty_block_index >= 0 {
        self.memory_blocks[empty_block_index] = new_block
        new_block_index = empty_block_index
    } else {
        append(&self.memory_blocks, new_block)
        new_block_index = len(self.memory_blocks) - 1
    }

    self.active_general_blocks += 1

    mem_block := vk_memory_block_ptr(self.memory_blocks[:], new_block_index) or_return

    offset, chunk_id, alloc_err := sub_allocator_allocate(
        &mem_block.sub_allocator,
        size,
        alignment,
        allocation_type,
        granularity,
        current_name)
    if alloc_err != .None {
        // A fresh block sized specifically for this allocation failing is a
        // bug in the allocator, not a real out-of-memory condition.
        log.errorf("allocation that must succeed failed (this is a bug): %v", alloc_err)
        return .Internal
    }

    mapped_ptr: rawptr
    if mem_block.mapped_ptr != nil {
        mapped_ptr = rawptr(uintptr(mem_block.mapped_ptr) + uintptr(offset))
    }

    allocation^ = {
        chunk_id             = chunk_id,
        offset               = offset,
        size                 = size,
        memory_block_index   = new_block_index,
        memory_type_index    = self.memory_type_index,
        device_memory        = mem_block.device_memory,
        mapped_ptr           = mapped_ptr,
        memory_properties    = self.memory_properties,
        dedicated_allocation = false,
    }

    str_copy_to_array(allocation.name[:], current_name)

    return .None
}

vk_memory_type_free :: proc(
    self: ^VK_Memory_Type,
    allocation: ^VK_Allocation,
    device: vk.Device,
    fp: VK_Functions,
    loc := #caller_location,
) -> Allocator_Error {
    sync.guard(&self.mtx)
    return vk_memory_type_free_locked(self, allocation, device, fp, loc)
}

@(private = "file")
// Caller must hold `self.mtx` exclusively.
vk_memory_type_free_locked :: proc(
    self: ^VK_Memory_Type,
    allocation: ^VK_Allocation,
    device: vk.Device,
    fp: VK_Functions,
    loc := #caller_location,
) -> Allocator_Error {
    assert(allocation != nil, "Invalid allocation object", loc)

    block_idx := allocation.memory_block_index

    mem_block := vk_memory_block_ptr(self.memory_blocks[:], block_idx) or_return
    sub_allocator_free(&mem_block.sub_allocator, allocation.chunk_id, loc) or_return

    // Destroy the block once it's empty, unless it's a shared block and the
    // only one left, so there's always at least one ready for reuse.
    is_dedicated_or_not_last_general_block :=
        !sub_allocator_supports_general_allocations(
            &mem_block.sub_allocator) || self.active_general_blocks > 1

    if sub_allocator_is_empty(&mem_block.sub_allocator) && is_dedicated_or_not_last_general_block {
        block_copy := mem_block^
        if sub_allocator_supports_general_allocations(&block_copy.sub_allocator) {
            self.active_general_blocks -= 1
        }
        self.memory_blocks[block_idx] = nil
        vk_memory_block_destroy(&block_copy, device, fp)
    }

    allocation^ = {}

    return .None
}

// -----------------------------------------------------------------------
// VK_Allocator
// -----------------------------------------------------------------------

VK_Functions :: struct {
    GetPhysicalDeviceMemoryProperties: vk.ProcGetPhysicalDeviceMemoryProperties,
    GetPhysicalDeviceProperties:       vk.ProcGetPhysicalDeviceProperties,
    AllocateMemory:                    vk.ProcAllocateMemory,
    FreeMemory:                        vk.ProcFreeMemory,
    MapMemory:                         vk.ProcMapMemory,
    UnmapMemory:                       vk.ProcUnmapMemory,
}

// Bind Vulkan procedures to GPU allocator.
create_vulkan_functions :: proc (loc := #caller_location) -> VK_Functions {
    // Basic validation
    assert(vk.GetPhysicalDeviceMemoryProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceMemoryProperties] function", loc)
    assert(vk.GetPhysicalDeviceProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceProperties] function", loc)
    assert(vk.AllocateMemory != nil, "VULKAN: invalid [VkAllocateMemory] function", loc)
    assert(vk.FreeMemory != nil, "VULKAN: invalid [VkFreeMemory] function", loc)
    assert(vk.MapMemory != nil, "VULKAN: invalid [VkMapMemory] function", loc)
    assert(vk.UnmapMemory != nil, "VULKAN: invalid [VkUnmapMemory] function", loc)
    return {
        GetPhysicalDeviceMemoryProperties = vk.GetPhysicalDeviceMemoryProperties,
        GetPhysicalDeviceProperties       = vk.GetPhysicalDeviceProperties,
        AllocateMemory                    = vk.AllocateMemory,
        FreeMemory                        = vk.FreeMemory,
        MapMemory                         = vk.MapMemory,
        UnmapMemory                       = vk.UnmapMemory,
    }
}

// Bind Vulkan procedures to GPU allocator.
create_device_vulkan_functions :: proc (
    fp: vk.Device_VTable,
    loc := #caller_location,
) -> VK_Functions {
    // Basic validation
    assert(vk.GetPhysicalDeviceMemoryProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceMemoryProperties] function", loc)
    assert(vk.GetPhysicalDeviceProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceProperties] function", loc)
    assert(fp.AllocateMemory != nil, "VULKAN: invalid [VkAllocateMemory] function", loc)
    assert(fp.FreeMemory != nil, "VULKAN: invalid [VkFreeMemory] function", loc)
    assert(fp.MapMemory != nil, "VULKAN: invalid [VkMapMemory] function", loc)
    assert(fp.UnmapMemory != nil, "VULKAN: invalid [VkUnmapMemory] function", loc)
    return {
        GetPhysicalDeviceMemoryProperties = vk.GetPhysicalDeviceMemoryProperties,
        GetPhysicalDeviceProperties       = vk.GetPhysicalDeviceProperties,
        AllocateMemory                    = fp.AllocateMemory,
        FreeMemory                        = fp.FreeMemory,
        MapMemory                         = fp.MapMemory,
        UnmapMemory                       = fp.UnmapMemory,
    }
}

VK_Allocator :: struct {
    memory_types:             [dynamic]VK_Memory_Type,
    memory_heaps:             [dynamic]vk.MemoryHeap,
    device:                   vk.Device,
    fp:                       VK_Functions,
    buffer_image_granularity: u64,
    debug_settings:           Allocator_Debug_Settings,
    allocation_sizes:         Allocation_Sizes,
    allocator:                runtime.Allocator,
}

VK_Allocator_Create_Desc :: struct {
    physical_device:       vk.PhysicalDevice,
    device:                vk.Device,
    vulkan_functions:      VK_Functions,
    debug_settings:        Allocator_Debug_Settings,
    buffer_device_address: bool,
    allocation_sizes:      Allocation_Sizes,
}

VK_Allocation_Scheme_Kind :: enum {
    // Memory for this resource is allocated/managed by gpu_allocator
    Gpu_Allocator_Managed,
    // Driver-managed dedicated allocation for a specific buffer
    Dedicated_Buffer,
    // Driver-managed dedicated allocation for a specific image
    Dedicated_Image,
}

VK_Allocation_Scheme :: struct {
    kind:   VK_Allocation_Scheme_Kind,
    // valid when kind == .Dedicated_Buffer
    buffer: vk.Buffer,
    // valid when kind == .Dedicated_Image
    image:  vk.Image,
}

VK_ALLOCATION_SCHEME_MANAGED :: VK_Allocation_Scheme {
    kind = .Gpu_Allocator_Managed,
}

vk_allocation_scheme_dedicated_buffer :: proc "contextless" (
    buffer: vk.Buffer,
) -> VK_Allocation_Scheme {
    return { kind = .Dedicated_Buffer, buffer = buffer }
}

vk_allocation_scheme_dedicated_image :: proc "contextless" (
    image: vk.Image,
) -> VK_Allocation_Scheme {
    return { kind = .Dedicated_Image, image = image }
}

VK_Allocation_Create_Desc :: struct {
    name:              string,
    requirements:      vk.MemoryRequirements,
    location:          Memory_Location,
    // true for buffers / linear textures, false for tiled (regular) textures
    linear:            bool,
    allocation_scheme: VK_Allocation_Scheme,
}

vk_allocator_init :: proc(
    self: ^VK_Allocator,
    desc: VK_Allocator_Create_Desc,
    backing_allocator: runtime.Allocator,
    loc := #caller_location,
) -> Allocator_Error {
    assert(self != nil, "VULKAN: Invalid [out] allocator", loc)

    if desc.device == nil || desc.physical_device == nil {
        return .Invalid_Allocator_Create_Desc
    }

    assert(desc.vulkan_functions.GetPhysicalDeviceMemoryProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceMemoryProperties] function", loc)
    assert(desc.vulkan_functions.GetPhysicalDeviceProperties != nil,
        "VULKAN: invalid [VkGetPhysicalDeviceProperties] function", loc)
    assert(desc.vulkan_functions.AllocateMemory != nil,
        "VULKAN: invalid [VkAllocateMemory] function", loc)
    assert(desc.vulkan_functions.FreeMemory != nil,
        "VULKAN: invalid [VkFreeMemory] function", loc)
    assert(desc.vulkan_functions.MapMemory != nil,
        "VULKAN: invalid [VkMapMemory] function", loc)
    assert(desc.vulkan_functions.UnmapMemory != nil,
        "VULKAN: invalid [VkUnmapMemory] function", loc)

    self.device = desc.device
    self.fp = desc.vulkan_functions
    self.debug_settings = desc.debug_settings
    self.allocation_sizes = desc.allocation_sizes
    self.allocator = backing_allocator

    mem_props: vk.PhysicalDeviceMemoryProperties
    self.fp.GetPhysicalDeviceMemoryProperties(desc.physical_device, &mem_props)

    memory_type_count := int(mem_props.memoryTypeCount)
    memory_heap_count := int(mem_props.memoryHeapCount)

    if desc.debug_settings.log_memory_information {
        log.debugf("VULKAN: memory type count: %d", memory_type_count)
        log.debugf("VULKAN: memory heap count: %d", memory_heap_count)
        for i in 0 ..< memory_type_count {
            mtp := mem_props.memoryTypes[i]
            log.debugf("VULKAN: memory type[%d]: prop flags: %v, heap[%d]",
                i, mtp.propertyFlags, mtp.heapIndex)
        }
        for i in 0 ..< memory_heap_count {
            heap := mem_props.memoryHeaps[i]
            log.debugf("VULKAN: heap[%d] flags: %v, size: %d MiB",
                i, heap.flags, heap.size / (1024 * 1024))
        }
    }

    self.memory_types = make([dynamic]VK_Memory_Type, 0, memory_type_count, backing_allocator)
    for i in 0 ..< memory_type_count {
        vk_mt := mem_props.memoryTypes[i]
        mt := VK_Memory_Type{
            memory_properties     = vk_mt.propertyFlags,
            memory_type_index     = i,
            heap_index            = int(vk_mt.heapIndex),
            mappable              = .HOST_VISIBLE in vk_mt.propertyFlags,
            active_general_blocks = 0,
            buffer_device_address = desc.buffer_device_address,
            allocator             = backing_allocator,
        }
        mt.memory_blocks.allocator = backing_allocator
        append(&self.memory_types, mt)
    }

    self.memory_heaps = make([dynamic]vk.MemoryHeap, 0, memory_heap_count, backing_allocator)
    for i in 0 ..< memory_heap_count {
        append(&self.memory_heaps, mem_props.memoryHeaps[i])
    }

    physical_device_properties: vk.PhysicalDeviceProperties
    self.fp.GetPhysicalDeviceProperties(desc.physical_device, &physical_device_properties)

    self.buffer_image_granularity  = u64(physical_device_properties.limits.bufferImageGranularity)

    return .None
}

vk_allocator_uninit :: proc(self: ^VK_Allocator) {
    // Destruction requires the caller to have stopped all allocation, free,
    // rename, and report operations using this allocator.
    context.allocator = self.allocator

    if self.debug_settings.log_leaks_on_shutdown {
        vk_allocator_report_memory_leaks(self)
    }

    for mt_i in 0 ..< len(self.memory_types) {
        mt := &self.memory_types[mt_i]
        for block_i in 0 ..< len(mt.memory_blocks) {
            block, err := vk_memory_block_ptr(mt.memory_blocks[:], block_i)
            if err != .None {
                continue
            }
            vk_memory_block_destroy(block, self.device, self.fp)
            mt.memory_blocks[block_i] = nil
        }
        delete(mt.memory_blocks)
    }

    delete(self.memory_types)
    delete(self.memory_heaps)
}

vk_allocator_find_memorytype_index :: proc(
    self: ^VK_Allocator,
    requirements: vk.MemoryRequirements,
    flags: vk.MemoryPropertyFlags,
) -> (
    index: int,
    found: bool,
) {
    for &mt in self.memory_types {
        bit := u64(1) << u64(mt.memory_type_index)
        if bit & u64(requirements.memoryTypeBits) != 0 && (mt.memory_properties & flags) == flags {
            return mt.memory_type_index, true
        }
    }
    return 0, false
}

vk_allocator_allocate :: proc(
    self: ^VK_Allocator,
    desc: VK_Allocation_Create_Desc,
    allocation: ^VK_Allocation,
    loc := #caller_location,
) -> (
    err: Allocator_Error,
) {
    assert(self != nil, "VULKAN: invalid allocator object", loc)
    assert(allocation != nil, "VULKAN: invalid allocation object", loc)

    size := u64(desc.requirements.size)
    alignment := u64(desc.requirements.alignment)

    if size == 0 || !math.is_power_of_two(int(alignment)) {
        return .Invalid_Allocation_Create_Desc
    }

    if self.debug_settings.log_allocations {
        log.debugf("VULKAN: Allocating `%s` of %d bytes with an alignment of %d.",
            desc.name, size, alignment)
    }

    preferred_bits: vk.MemoryPropertyFlags
    switch desc.location {
    case .Gpu_Only:   preferred_bits = {.DEVICE_LOCAL}
    case .Cpu_To_Gpu: preferred_bits = {.HOST_VISIBLE, .HOST_COHERENT, .DEVICE_LOCAL}
    case .Gpu_To_Cpu: preferred_bits = {.HOST_VISIBLE, .HOST_COHERENT, .HOST_CACHED}
    case .Unknown:    preferred_bits = {}
    }

    memory_type_index, found :=
        vk_allocator_find_memorytype_index(self, desc.requirements, preferred_bits)

    if !found {
        required_bits: vk.MemoryPropertyFlags
        switch desc.location {
        case .Gpu_Only:               required_bits = {.DEVICE_LOCAL}
        case .Cpu_To_Gpu, .Gpu_To_Cpu: required_bits = {.HOST_VISIBLE, .HOST_COHERENT}
        case .Unknown:                required_bits = {}
        }
        memory_type_index, found =
            vk_allocator_find_memorytype_index(self, desc.requirements, required_bits)
    }

    if !found {
        return .No_Compatible_Memory_Type_Found
    }

    mt := &self.memory_types[memory_type_index]

    // Skip even trying to create a block if the heap can't fit it, avoids
    // validation-layer noise for allocations that could never succeed.
    if size > u64(self.memory_heaps[mt.heap_index].size) {
        err = .Out_Of_Memory
    } else {
        err = vk_memory_type_allocate(
            mt,
            self.device,
            self.fp,
            desc,
            self.buffer_image_granularity,
            self.allocation_sizes,
            allocation)
    }

    // Cpu_To_Gpu allocations that failed get one retry against a plain
    // host-visible+host-coherent memory type (drops the DEVICE_LOCAL preference).
    if desc.location == .Cpu_To_Gpu && err != .None {
        fallback_bits := vk.MemoryPropertyFlags{.HOST_VISIBLE, .HOST_COHERENT}
        fallback_index, fallback_found :=
        vk_allocator_find_memorytype_index(self, desc.requirements, fallback_bits)
        if !fallback_found {
            return .No_Compatible_Memory_Type_Found
        }
        fallback_mt := &self.memory_types[fallback_index]
        return vk_memory_type_allocate(
            fallback_mt,
            self.device,
            self.fp,
            desc,
            self.buffer_image_granularity,
            self.allocation_sizes,
            allocation)
    }

    return err
}

vk_allocator_free :: proc(self: ^VK_Allocator, allocation: ^VK_Allocation) -> Allocator_Error {
    if self.debug_settings.log_frees {
        name := len(allocation.name) > 0 \
            ? str_from_array(allocation.name[:]) : "<null>"
        log.debugf("Freeing `%s`.", name)
    }

    if vk_allocation_is_null(allocation) {
        return .None
    }

    err := vk_memory_type_free(
        &self.memory_types[allocation.memory_type_index],
        allocation,
        self.device,
        self.fp)
    return err
}

vk_allocator_rename_allocation :: proc(
    self: ^VK_Allocator,
    allocation: ^VK_Allocation,
    name: string,
) -> Allocator_Error {
    str_copy_to_array(allocation.name[:], name)

    if vk_allocation_is_null(allocation) {
        return .None
    }

    mt := &self.memory_types[allocation.memory_type_index]
    sync.guard(&mt.mtx)
    mem_block := vk_memory_block_ptr(mt.memory_blocks[:], allocation.memory_block_index) or_return

    return sub_allocator_rename_allocation(&mem_block.sub_allocator, allocation.chunk_id, name)
}

vk_allocator_report_memory_leaks :: proc(self: ^VK_Allocator) {
    for mt_i in 0 ..< len(self.memory_types) {
        mt := &self.memory_types[mt_i]
        sync.shared_guard(&mt.mtx)
        for block_i in 0 ..< len(mt.memory_blocks) {
            block, err := vk_memory_block_ptr(mt.memory_blocks[:], block_i)
            if err != .None {
                continue
            }
            sub_allocator_report_memory_leaks(&block.sub_allocator, mt_i, block_i)
        }
    }
}

vk_allocator_generate_report :: proc(
    self: ^VK_Allocator,
    allocator: runtime.Allocator,
) -> Allocator_Report {
    allocations := make([dynamic]Allocation_Report, allocator)
    blocks := make([dynamic]Memory_Block_Report, allocator)

    total_capacity_bytes: u64
    total_allocated_bytes: u64

    for mt_i in 0 ..< len(self.memory_types) {
        mt := &self.memory_types[mt_i]
        sync.shared_guard(&mt.mtx)
        for block_i in 0 ..< len(mt.memory_blocks) {
            block, err := vk_memory_block_ptr(mt.memory_blocks[:], block_i)
            if err != .None { continue }

            total_capacity_bytes += block.size
            first_allocation := len(allocations)
            block_reports := sub_allocator_report_allocations(&block.sub_allocator, allocator)
            for r in block_reports {
                total_allocated_bytes += r.size
                append(&allocations, r)
            }
            delete(block_reports)
            append(&blocks, Memory_Block_Report{
                size = block.size,
                allocations = Allocation_Range{
                    start = first_allocation,
                    end = len(allocations),
                }})
        }
    }

    return Allocator_Report{
        allocations           = allocations,
        blocks                = blocks,
        total_allocated_bytes = total_allocated_bytes,
        total_capacity_bytes  = total_capacity_bytes,
    }
}

// Current total capacity of memory blocks allocated on the device, in bytes.
vk_allocator_capacity :: proc(self: ^VK_Allocator) -> u64 {
    total: u64
    for mt_i in 0 ..< len(self.memory_types) {
        mt := &self.memory_types[mt_i]
        sync.shared_guard(&mt.mtx)
        for block_i in 0 ..< len(mt.memory_blocks) {
            block, err := vk_memory_block_ptr(mt.memory_blocks[:], block_i)
            if err == .None {
                total += block.size
            }
        }
    }
    return total
}
