// #+build !js
package gpu

// Core
import "core:sync"

import intr "base:intrinsics"
import hm "core:container/handle_map"
import xar "core:container/xar"

DHM :: hm.Dynamic_Handle_Map

/*
A `DHM_Resource` is a general-purpose, thread-safe container of `T` addressed by
`H` handles, layered directly on `core:container/handle_map`.

Thread safety

All access is serialized on `mtx`. `mtx` is a read-write mutex: structural
mutation (`add_impl`, `remove_handle_impl`, `dhm_clear`, `dhm_init`,
`dhm_destroy`) takes the exclusive lock, while read-only access
(`get_handle_impl`, `dhm_len`, `dhm_cap`, `dhm_is_valid`, `dhm_for_each`)
takes the shared lock, so concurrent readers do not block each other.

The lock protects the map's *structure* -- the item array, the free list and
the generation counters. It does not and cannot protect the contents of a
`T`; that is the job of the value's own synchronization, normally the
atomic refcount in `Ref_Count_Type`.

Pointer stability

Element addresses are stable for the lifetime of the map. The backing
`xar.Array` never moves an existing element, so a `^T` handed out by
`add_impl` or `get_handle_impl` stays valid and continues to denote the
same slot even if the handle is later removed and the slot reused for an
unrelated item. A pointer alone is therefore not a lifetime guard: use it
only while holding a live reference to the object.

Initialization

`dhm_init` must be called with the allocator that will own the backing
storage. If it is skipped, `xar` lazily adopts `context.allocator` on first
append, and `context.allocator` is thread-local -- two threads could then
allocate the same map's storage from different allocators.
*/
DHM_Resource :: struct($T: typeid, $H: typeid) {
    #subtype resources: DHM(T, H),
    mtx: sync.RW_Mutex,
}

Handle_Packed :: u64

Handle :: struct {
    device: Device,
    handle: Handle_Packed,
}

unpack_handle :: #force_inline proc "contextless" ($T: typeid, h: Handle_Packed) -> T {
    return transmute(T)h
}

pack_handle :: #force_inline proc "contextless" (h: $T/hm.Handle64) -> Handle_Packed {
    return transmute(Handle_Packed)h
}

new_handle :: #force_inline proc "contextless" (
        $T: typeid, device: Device, h: $H/hm.Handle64) -> T {
    return (T)({ device, pack_handle(h) })
}

new_handle_packed :: #force_inline proc "contextless" (
        $T: typeid, device: Device, h: Handle_Packed) -> T {
    return (T)({ device, h })
}

/*
Insert `item` into the map and return a stable pointer to it along with its new
handle. The returned handle is not yet published to any other thread, so the
caller may keep writing through `ptr` without holding the lock, provided the
handle is not handed out before that initialization finishes.
*/
@(require_results)
add_impl :: proc(
    self: ^$D/DHM_Resource($T, $Handle_Type),
    item: T,
    loc := #caller_location,
) -> (
    ptr: ^T,
    handle: Handle_Type,
) where intr.type_has_field(T, "ref") {
    sync.guard(&self.mtx)

    m := &self.resources
    idx: int

    if xar.len(m.unused_items) > 0 {
        idx = int(xar.pop(&m.unused_items))
        ptr = xar.get_ptr_unsafe(&m.items, idx)

        prev_gen := ptr.handle.gen
        ptr^ = item

        new_gen := auto_cast (prev_gen + 1)
        if new_gen == 0 {
            // never let a reused slot land back on the invalid generation
            new_gen = 1
        }
        ptr.handle.gen = new_gen
    } else {
        if xar.len(m.items) == 0 {
            // index 0 is permanently reserved as the always-invalid
            // "null handle" slot
            xar.append(&m.items, T{}, loc)
        }
        xar.append(&m.items, item, loc)
        idx = xar.len(m.items) - 1
        ptr = xar.get_ptr_unsafe(&m.items, idx)
        ptr.handle.gen = 1
    }

    ptr.handle.idx = auto_cast idx
    init_ref(ptr)

    handle = ptr.handle

    return
}

/*
Resolve `handle` to its item. The shared lock is held only for the lookup
itself; the returned pointer stays valid after it is released, but dereferencing
it is only safe while the caller holds a live reference to the object.
*/
@(require_results)
get_handle_impl :: #force_inline proc "contextless" (
    self: ^$D/DHM_Resource($T, $Handle_Type),
    handle: u64,
    loc := #caller_location,
) -> ^T {
    sync.shared_guard(&self.mtx)
    return hm.dynamic_get(&self.resources, unpack_handle(Handle_Type, handle)) or_else \
        panic_contextless("invalid handle", loc)
}

/*
Retire `handle` and return its slot to the free list.

The caller is responsible for having already dropped its reference to the item,
so that no thread can still be reading a slot that becomes reusable here.
*/
remove_handle_impl :: proc(
    self: ^$D/DHM_Resource($T, $Handle_Type),
    handle: Handle_Type,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    hm.remove(&self.resources, handle)
}

/*
Initialize the backing storage with `allocator`.

Must be called before any other operation, while no other thread can observe
the map yet.
*/
dhm_init :: proc(
    self: ^$D/DHM_Resource($T, $Handle_Type),
    allocator := context.allocator,
) {
    sync.guard(&self.mtx)
    hm.dynamic_init(&self.resources, allocator)
}

// Release the backing storage. The map must be unreachable by other threads.
dhm_destroy :: proc(self: ^$D/DHM_Resource($T, $Handle_Type)) {
    sync.guard(&self.mtx)
    hm.dynamic_destroy(&self.resources)
}

// Number of live items, excluding the reserved null slot.
@(require_results)
dhm_len :: proc "contextless" (self: ^$D/DHM_Resource($T, $Handle_Type)) -> uint {
    sync.shared_guard(&self.mtx)
    return hm.dynamic_len(self.resources)
}

// Capacity of the backing storage, excluding the reserved null slot.
@(require_results)
dhm_cap :: proc "contextless" (self: ^$D/DHM_Resource($T, $Handle_Type)) -> uint {
    sync.shared_guard(&self.mtx)
    return hm.dynamic_cap(self.resources)
}

// True if `handle` currently denotes a live item.
@(require_results)
dhm_is_valid :: proc "contextless" (
    self: ^$D/DHM_Resource($T, $Handle_Type),
    handle: Handle_Type,
) -> bool {
    sync.shared_guard(&self.mtx)
    return hm.dynamic_is_valid(&self.resources, handle)
}

/*
Drop every item, invalidating all outstanding handles.

The exclusive lock guarantees the map is structurally consistent afterwards, but
it cannot know whether a reader still holds a pointer obtained earlier. Callers
that hand out long-lived pointers must retire them before clearing.
*/
dhm_clear :: proc "contextless" (self: ^$D/DHM_Resource($T, $Handle_Type)) {
    sync.guard(&self.mtx)
    hm.dynamic_clear(&self.resources)
}

/*
Call `visit` for every live item, in slot order, with the shared lock held.

Holding the shared lock for the whole walk keeps the iteration consistent, at
the cost of blocking `add_impl`/`remove_handle_impl` until it finishes. `visit`
must not call back into the same map, and the pointers it receives must not
escape unless the map is known not to be mutated concurrently.

`user_data` is passed through to `visit` unchanged. Odin has no closures, so
this is how a caller carries iteration state; it follows the
`thread.create_and_start_with_poly_data` convention.
*/
dhm_for_each :: proc(
    self: ^$D/DHM_Resource($T, $Handle_Type),
    user_data: rawptr,
    visit: proc(user_data: rawptr, ptr: ^T, handle: Handle_Type),
) {
    sync.shared_guard(&self.mtx)
    it := hm.dynamic_iterator_make(&self.resources)
    for {
        item, handle, ok := hm.dynamic_iterate(&it)
        if !ok { break }
        visit(user_data, item, handle)
    }
}
