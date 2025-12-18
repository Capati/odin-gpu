package shared

// Core
import "core:mem"

_ :: mem

// Handle provides a safe reference to an object in the pool.
Handle :: u64

Internal_Handle :: struct #packed {
    index: u32,
    gen:   u32,
}

#assert(size_of(Handle) == size_of(Internal_Handle))

from_handle :: #force_inline proc "contextless" (handle: Internal_Handle) -> Handle {
    return transmute(Handle)handle
}

to_handle :: #force_inline proc "contextless" (#any_int handle: Handle) -> Internal_Handle {
    return transmute(Internal_Handle)handle
}

@(require_results)
handle_from_ptr :: proc "contextless" (ptr: rawptr) -> Internal_Handle {
    ptr_val := uintptr(ptr)
    index := u32(ptr_val & 0xffffffff)
    gen := u32((ptr_val >> 32) & 0xffffffff)
    return {index = index, gen = gen}
}

@(require_results)
handle_is_empty :: #force_inline proc "contextless" (self: Internal_Handle) -> bool {
    return self.gen == 0
}

@(require_results)
handle_is_valid :: #force_inline proc "contextless" (self: Internal_Handle) -> bool {
    return self.gen != 0
}

@(require_results)
handle_index :: #force_inline proc "contextless" (self: Internal_Handle) -> u32 {
    return self.index
}

@(require_results)
handle_gen :: #force_inline proc "contextless" (self: Internal_Handle) -> u32 {
    return self.gen
}

LIST_END_SENTINEL :: 0xffffffff

Pool_Entry :: struct($T: typeid) {
    obj:       T,
    gen:       u32,
    next_free: u32,
}

Pool :: struct($T: typeid) {
    free_list_head: u32,
    num_objects:    u32,
    objects:        [dynamic]Pool_Entry(T),
    allocator:      mem.Allocator,
}

// Initializes a pool to its default state.
pool_set_defaults :: proc(self: ^$T/Pool) {
    self.free_list_head = LIST_END_SENTINEL
}

// Initialize a new pool of handles.
pool_init :: proc(self: ^$P/Pool($T), allocator := context.allocator) {
    assert(self != nil, "Invalid pool")
    self.objects = make([dynamic]Pool_Entry(T), allocator)
    self.allocator = allocator
    pool_set_defaults(self)
}

@(require_results)
pool_create :: proc(self: ^$P/Pool($T), obj: T) -> Internal_Handle {
    idx: u32

    // If there are free entries in the free list
    if self.free_list_head != LIST_END_SENTINEL {
        // Reuse the first free entry
        idx = self.free_list_head
        // Update free list head to point to next free entry
        self.free_list_head = self.objects[idx].next_free
        // Copy the new object into the reused entry
        self.objects[idx].obj = obj
    } else {
        // No free entries, append a new entry to the end of the array
        idx = u32(len(self.objects))
        append(&self.objects, Pool_Entry(T){obj, 1, LIST_END_SENTINEL})
    }

    // Increment active object count
    self.num_objects += 1

    // Return a handle to the newly created object
    return {index = idx, gen = self.objects[idx].gen}
}

// Retrieves a pointer to an object using its handle.
@(require_results)
pool_get :: proc "contextless" (
    self: ^$P/Pool($T),
    handle: Internal_Handle,
    loc := #caller_location,
) -> ^T #no_bounds_check {
    if handle_is_empty(handle) {
        return nil
    }

    index := handle.index

    // Validate handle's index is within pool bounds
    assert_contextless(index < u32(len(self.objects)), "handle out of bounds", loc)
    // Validate handle's generation matches current object generation
    assert_contextless(handle.gen == self.objects[index].gen, "accessing deleted object", loc)

    // Return pointer to the object
    return &self.objects[index].obj
}

// Retrieves an object pointer directly by index.
@(require_results)
pool_get_from_index :: proc "contextless" (self: ^$P/Pool($T), index: u32) -> ^T {
    // Get handle for the index
    handle := pool_get_handle(self, index)
    // Retrieve object using the handle
    return pool_get(self, handle)
}

// Generates a handle for an object at a specific index.
@(require_results)
pool_get_handle :: proc "contextless" (
    self: ^$P/Pool($T),
    #any_int index: u32,
    loc := #caller_location,
) -> Internal_Handle #no_bounds_check {
    // Validate index is within pool bounds
    assert_contextless(index < u32(len(self.objects)), "handle out of bounds", loc)

    // Return empty handle if index is out of bounds
    if index >= u32(len(self.objects)) {
        return {}
    }

    // Return handle with current generation
    return {index, self.objects[index].gen}
}

// Finds the handle of a specific object in the pool
@(require_results)
pool_find_handle :: proc "contextless" (self: ^$P/Pool($T), obj: ^T) -> Internal_Handle {
    // Return empty handle for nil object
    if obj == nil {
        return {}
    }

    // Iterate through all pool entries
    for idx := 0; idx < len(self.objects); idx += 1 {
        // Check if object pointer matches
        if &self.objects[idx].obj == obj {
            return {u32(idx), self.objects[idx].gen}
        }
    }

    // Return empty handle if object not found
    return {}
}

// Destroys an object in the pool, making its slot available for reuse.
pool_remove :: proc "contextless" (
    self: ^$P/Pool($T),
    handle: Internal_Handle,
    loc := #caller_location,
) #no_bounds_check {
    if handle_is_empty(handle) {
        return
    }

    // Ensure pool is not empty before destroying
    assert_contextless(self.num_objects > 0, "double deletion", loc)

    index := handle.index

    // Validate handle's index is within pool bounds
    assert_contextless(index < u32(len(self.objects)), "handle out of bounds", loc)
    // Validate handle's generation matches current object generation
    assert_contextless(handle.gen == self.objects[index].gen, "double deletion", loc)

    // Clear the object to its zero value
    self.objects[index].obj = T{}

    // Increment generation to invalidate existing handles
    self.objects[index].gen += 1

    // Add this entry to the free list
    self.objects[index].next_free = self.free_list_head
    self.free_list_head = index

    // Decrement active object count
    self.num_objects -= 1
}

// Get the number of valid objects in the pool.
pool_len :: proc "contextless" (self: ^$T/Pool) -> u32 {
    return self.num_objects
}

// Check if pool is empty.
pool_is_empty :: proc "contextless" (self: ^$T/Pool) -> bool {
    return self.num_objects == 0
}

// Clears all objects from the pool.
pool_clear :: proc "contextless" (self: ^$T/Pool) {
    clear(&self.objects)
    self.free_list_head = LIST_END_SENTINEL
    self.num_objects = 0
}

// Deletes the pool, freeing all associated memory.
pool_destroy :: proc(self: ^$T/Pool) {
    context.allocator = self.allocator
    pool_clear(self)
    delete(self.objects)
}
