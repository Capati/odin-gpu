#+build !js
#+private
package gpu

// Core
import "base:runtime"
import "core:mem"

import intr "base:intrinsics"
import xar "core:container/xar"

// Render-bundle replay stream. Bundles replay once per execute, so the stream is
// sized for that walk: 56-byte commands instead of the 144-byte general union, a
// narrow switch, and a u32 index into per-site locations (40 bytes stored once)
// instead of a copy per command. The walk was ~28% of in-exe in the flat profile.

Bundle_Set_Pipeline_Cmd :: struct {
    loc:           u32,
    pipeline:      Render_Pipeline,
    // Resolved at encode. The encoder already has both for its own checks, and
    // the bundle holds a reference on the pipeline, so they stay valid for the
    // bundle's lifetime. Replay must not probe the handle maps again.
    pipeline_impl: ^VK_Render_Pipeline_Impl,
    layout_impl:   ^VK_Pipeline_Layout_Impl,
}

Bundle_Set_Bind_Group_Cmd :: struct {
    loc:             u32,
    index:           u32,
    dynamic_offsets: []u32,
    bind_group:      Bind_Group,
    // Resolved at encode (the usage merge needs it). Replay reads the descriptor
    // set and the layout identity from it instead of probing per draw.
    group_impl:      ^VK_Bind_Group_Impl,
}

Bundle_Set_Index_Buffer_Cmd :: struct {
    loc:          u32,
    index_format: Index_Format,
    offset:       u64,
    // The effective size computed by encode-time validation; replay must not
    // re-run it (the buffer is validated, referenced and immutable by then).
    size:         u64,
    buffer:       Buffer,
    buffer_impl:  ^VK_Buffer_Impl,
}

Bundle_Set_Vertex_Buffer_Cmd :: struct {
    loc:         u32,
    slot:        u32,
    offset:      u64,
    // Effective size, as for the index buffer.
    size:        u64,
    buffer:      Buffer,
    buffer_impl: ^VK_Buffer_Impl,
}

Bundle_Set_Immediates_Cmd :: struct {
    loc:    u32,
    offset: u32,
    data:   []u8,
}

Bundle_Draw_Cmd :: struct {
    loc:            u32,
    vertex_count:   u32,
    instance_count: u32,
    first_vertex:   u32,
    first_instance: u32,
}

Bundle_Draw_Indexed_Cmd :: struct {
    loc:            u32,
    index_count:    u32,
    instance_count: u32,
    first_index:    u32,
    base_vertex:    i32,
    first_instance: u32,
}

// Only what replay consumes: the recorded `count` and the limit fields are
// encoder-side checks, so they stay in the encoder and out of the stream.
Bundle_Draw_Indirect_Cmd :: struct {
    loc:    u32,
    family: Draw_Command_Family,
    offset: u64,
    buffer: Buffer,
}

Bundle_Command :: union {
    Bundle_Set_Pipeline_Cmd,
    Bundle_Set_Bind_Group_Cmd,
    Bundle_Set_Index_Buffer_Cmd,
    Bundle_Set_Vertex_Buffer_Cmd,
    Bundle_Set_Immediates_Cmd,
    Bundle_Draw_Cmd,
    Bundle_Draw_Indexed_Cmd,
    Bundle_Draw_Indirect_Cmd,
}

Bundle_Command_Allocator :: struct {
    data:      xar.Array(Bundle_Command, COMMAND_ALLOCATOR_SHIFT),
    iterator:  xar.Array_Iterator(Bundle_Command, COMMAND_ALLOCATOR_SHIFT),
    allocator: runtime.Allocator,
    // Deduplicated source locations, indexed by every command's `loc`. A bundle
    // typically records a handful of distinct sites (the scene loop), so this
    // stays tiny while keeping per-command error messages exact.
    locs:      [dynamic]runtime.Source_Code_Location,
}

bundle_command_allocator_init :: proc(
    self: ^Bundle_Command_Allocator,
    allocator := context.allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    xar.array_init(&self.data, allocator)
    self.allocator = allocator
    self.locs.allocator = allocator
    bundle_command_allocator_iterator_reset(self)
}

bundle_command_allocator_destroy :: proc(
    self: ^Bundle_Command_Allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    delete(self.locs)
    xar.destroy(&self.data)
    self^ = {}
}

bundle_command_allocator_is_empty :: proc(
    self: ^Bundle_Command_Allocator,
    loc := #caller_location,
) -> bool {
    assert(self != nil, loc = loc)
    return xar.len(self.data) == 0
}

bundle_command_allocator_iterator_reset :: proc(
    self: ^Bundle_Command_Allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    self.iterator = xar.array_iterator(&self.data)
}

// Appends one command of type `T` and stamps its location index. Mirrors
// `command_allocator_allocate`, narrowed to the bundle stream's variants.
@(require_results)
bundle_command_allocate :: proc(
    self: ^Bundle_Command_Allocator,
    $T: typeid,
    loc: runtime.Source_Code_Location,
) -> (
    cmd: ^T,
    err: mem.Allocator_Error,
) where intr.type_is_variant_of(Bundle_Command, T) #optional_allocator_error {
    assert(self != nil)
    union_cmd := xar.push_back_elem_and_get_ptr(&self.data, Bundle_Command(T{})) or_return
    cmd = &union_cmd.(T)
    cmd.loc = bundle_command_loc_index(self, loc)
    return
}

// The recorded location behind a command's index. Only error paths call this.
bundle_command_location :: #force_inline proc "contextless" (
    self: ^Bundle_Command_Allocator,
    index: u32,
) -> runtime.Source_Code_Location {
    if int(index) < len(self.locs) {
        return self.locs[index]
    }
    return {}
}

@(private = "file")
bundle_command_loc_index :: proc(
    self: ^Bundle_Command_Allocator,
    loc: runtime.Source_Code_Location,
) -> u32 {
    for existing, index in self.locs {
        if existing.file_path == loc.file_path &&
           existing.line == loc.line &&
           existing.column == loc.column &&
           existing.procedure == loc.procedure {
            return u32(index)
        }
    }
    append(&self.locs, loc)
    return u32(len(self.locs) - 1)
}
