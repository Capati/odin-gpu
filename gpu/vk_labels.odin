#+build !js
package gpu

// Core
import "base:runtime"
import hm "core:container/handle_map"
import "core:strings"

// Label storage for handle-only resources.
//
// A resource handle is a device plus a packed (index, generation) pair. Keying
// the map by the whole packed handle means a recycled slot never inherits the
// previous resource's label: the generation differs. Re-labelling with the same
// string keeps the existing allocation, so a steady-state frame loop does not
// allocate.

VK_Label_Kind :: enum u8 {
    Buffer,
    Texture,
    Texture_View,
    Sampler,
    Bind_Group,
    Bind_Group_Layout,
    Shader_Module,
    Render_Pipeline,
    Compute_Pipeline,
    Pipeline_Layout,
    Query_Set,
    Render_Pass,
    Compute_Pass,
    Render_Bundle,
    Render_Bundle_Encoder,
    Queue,
    Command_Encoder,
    Command_Buffer,
    Surface,
    Count,
}

VK_Label_Key :: struct {
    kind: VK_Label_Kind,
    slot: u32,
}

VK_Label_Entry :: struct {
    // The generation that owns `label`; 0 means the slot is disarmed.
    generation: u32,
    label:      string,
}

VK_Label_Store :: struct {
    entries:   map[VK_Label_Key]VK_Label_Entry,
    allocator: runtime.Allocator,
}

@(private)
vk_label_store_init :: proc(store: ^VK_Label_Store, allocator: runtime.Allocator) {
    store.allocator = allocator
    store.entries = make(map[VK_Label_Key]VK_Label_Entry, allocator)
}

@(private)
vk_label_store_destroy :: proc(store: ^VK_Label_Store) {
    for _, entry in store.entries {
        if entry.label != "" {
            delete(entry.label, store.allocator)
        }
    }
    delete(store.entries)
    store.entries = nil
}

// Records `label` for the resource slot the handle names. The label text is
// reused across generations when it is unchanged; an empty label only disarms
// the current generation. A recycled slot must not inherit a label, so the
// generation is part of the entry rather than the key.
@(private)
vk_label_set :: proc(
    store: ^VK_Label_Store,
    kind: VK_Label_Kind,
    handle: Handle_Packed,
    label: string,
) {
    packed := unpack_handle(hm.Handle64, handle)
    if packed.gen == 0 {
        return
    }
    key := VK_Label_Key {
        kind = kind,
        slot = packed.idx,
    }

    if entry, ok := &store.entries[key]; ok {
        if label == "" {
            // Keep the text for the slot's next object; only disarm this one.
            entry.generation = 0
            return
        }
        if entry.label == label {
            entry.generation = packed.gen
            return
        }
        // Copy before freeing: `label` may be a slice of the existing string.
        copy := strings.clone(label, store.allocator)
        if entry.label != "" {
            delete(entry.label, store.allocator)
        }
        entry.label = copy
        entry.generation = packed.gen
        return
    }

    if label == "" {
        return
    }
    store.entries[key] = {
        generation = packed.gen,
        label      = strings.clone(label, store.allocator),
    }
}

// Disarms the label belonging to this exact handle generation. The string stays
// in the table so the slot's next object can reuse it without allocating.
@(private)
vk_label_remove :: proc(store: ^VK_Label_Store, kind: VK_Label_Kind, handle: Handle_Packed) {
    packed := unpack_handle(hm.Handle64, handle)
    if packed.gen == 0 {
        return
    }
    key := VK_Label_Key {
        kind = kind,
        slot = packed.idx,
    }
    if entry, ok := &store.entries[key]; ok && entry.generation == packed.gen {
        entry.generation = 0
    }
}

// Returns the label belonging to this exact handle generation, or an empty
// string. The returned text is borrowed from the store.
@(private)
vk_label_get :: proc(
    store: ^VK_Label_Store,
    kind: VK_Label_Kind,
    handle: Handle_Packed,
) -> string {
    packed := unpack_handle(hm.Handle64, handle)
    if packed.gen == 0 {
        return ""
    }
    key := VK_Label_Key {
        kind = kind,
        slot = packed.idx,
    }
    if entry, ok := store.entries[key]; ok && entry.generation == packed.gen {
        return entry.label
    }
    return ""
}
