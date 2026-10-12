// #+build !js
#+private
package gpu

// Core
import "base:runtime"
import "core:mem"

import intr "base:intrinsics"
import xar "core:container/xar"

Draw_Command_Family :: enum {
    Draw,
    Draw_Indexed,
    Draw_Mesh_Tasks,
}

Begin_Render_Pass_Cmd :: struct {
    color_attachments:        Color_Attachments,
    depth_stencil_attachment: Maybe(Render_Pass_Depth_Stencil_Attachment),
    multiview_mask:           Maybe(u32),
    timestamp_writes:         Maybe(Render_Pass_Timestamp_Writes),
    occlusion_query_set:      Query_Set,
    width:                    u32,
    height:                   u32,
    render_pass:              Render_Pass,
    // Transitions from the states left by the previous scopes in this command
    // buffer into the states this pass requires. They are only known once the
    // whole pass scope has folded (at `render_pass_end`), at which point they
    // are drained from the command buffer tracker into these lists so the
    // recorder can emit them right before `vkCmdBeginRenderPass`, which
    // finishes the pass, records the transitions in a separate transit command
    // buffer, and jams it in just before the pass.
    buffer_transitions:  []Pending_Buffer_Transition,
    texture_transitions: []Pending_Texture_Transition,
    loc:                 runtime.Source_Code_Location,
}

Render_Pass_End_Cmd :: struct {
    loc: runtime.Source_Code_Location,
}

Begin_Compute_Pass_Cmd :: struct {
    timestamp_writes: Render_Pass_Timestamp_Writes,
    loc:              runtime.Source_Code_Location,
}

Set_Bind_Group_Cmd :: struct {
    index:           u32,
    dynamic_offsets: []u32,
    bind_group:      Bind_Group,
    loc:             runtime.Source_Code_Location,
}

Set_Render_Pipeline_Cmd :: struct {
    pipeline: Render_Pipeline,
    loc:      runtime.Source_Code_Location,
}

Set_Index_Buffer_Cmd :: struct {
    buffer:       Buffer,
    index_format: Index_Format,
    offset:       u64,
    size:         u64,
    loc:          runtime.Source_Code_Location,
}

Set_Vertex_Buffer_Cmd :: struct {
    slot:   u32,
    buffer: Buffer,
    offset: u64,
    size:   u64,
    loc:    runtime.Source_Code_Location,
}

Set_Blend_Constant_Cmd :: struct {
    color: Color,
    loc:   runtime.Source_Code_Location,
}

Set_Stencil_Reference_Cmd :: struct {
    reference: u32,
    loc:       runtime.Source_Code_Location,
}

Set_Viewport_Cmd :: struct {
    x:         f32,
    y:         f32,
    width:     f32,
    height:    f32,
    min_depth: f32,
    max_depth: f32,
    loc:       runtime.Source_Code_Location,
}

Set_Scissor_Cmd :: struct {
    x:      u32,
    y:      u32,
    width:  u32,
    height: u32,
    loc:    runtime.Source_Code_Location,
}

Set_Immediate_Cmd :: struct {
    offset:        u32,
    size_bytes:    u32,
    values_offset: u32,
    loc:           runtime.Source_Code_Location,
}

Draw_Cmd :: struct {
    vertex_count:   u32,
    instance_count: u32,
    first_vertex:   u32,
    first_instance: u32,
    loc:            runtime.Source_Code_Location,
}

Draw_Indexed_Cmd :: struct {
    index_count:    u32,
    instance_count: u32,
    first_index:    u32,
    base_vertex:    i32,
    first_instance: u32,
    loc:            runtime.Source_Code_Location,
}

Draw_Mesh_Tasks_Cmd :: struct {
    group_count: [3]u32,
    loc:         runtime.Source_Code_Location,
}

Draw_Indirect_Cmd :: struct {
    buffer:                Buffer,
    offset:                u64,
    count:                 u32,
    family:                Draw_Command_Family,
    vertex_or_index_limit: u64,
    instance_limit:        u64,
    loc:                   runtime.Source_Code_Location,
}

Multi_Draw_Indirect_Count_Cmd :: struct {
    buffer:              Buffer,
    offset:              u64,
    count_buffer:        Buffer,
    count_buffer_offset: u64,
    max_count:           u32,
    family:              Draw_Command_Family,
    loc:                 runtime.Source_Code_Location,
}

Push_Debug_Group_Cmd :: struct {
    label: string,
    loc:   runtime.Source_Code_Location,
}

Pop_Debug_Group_Cmd :: struct {
    loc: runtime.Source_Code_Location,
}

Insert_Debug_Marker_Cmd :: struct {
    label: string,
    loc:   runtime.Source_Code_Location,
}

Write_Timestamp_Cmd :: struct {
    query_set:   Query_Set,
    query_index: u32,
    loc:         runtime.Source_Code_Location,
}

Begin_Occlusion_Query_Cmd :: struct {
    query_index: u32,
    loc:         runtime.Source_Code_Location,
}

End_Occlusion_Query_Cmd :: struct {
    loc: runtime.Source_Code_Location,
}

Begin_Pipeline_Statistics_Query_Cmd :: struct {
    query_set:   Query_Set,
    query_index: u32,
    loc:         runtime.Source_Code_Location,
}

End_Pipeline_Statistics_Query_Cmd :: struct {
    loc: runtime.Source_Code_Location,
}

Execute_Bundle_Cmd :: struct {
    bundle: Render_Bundle,
    loc:    runtime.Source_Code_Location,
}

Copy_Buffer_To_Buffer_Cmd :: struct {
    src:        Buffer,
    src_offset: u64,
    dst:        Buffer,
    dst_offset: u64,
    size:       u64,
    loc:        runtime.Source_Code_Location,
}

Copy_Buffer_To_Texture_Cmd :: struct {
    src:  Texel_Copy_Buffer_Info,
    dst:  Texel_Copy_Texture_Info,
    size: Extent_3D,
    loc:  runtime.Source_Code_Location,
}

Copy_Texture_To_Buffer_Cmd :: struct {
    src:  Texel_Copy_Texture_Info,
    dst:  Texel_Copy_Buffer_Info,
    size: Extent_3D,
    loc:  runtime.Source_Code_Location,
}

Copy_Texture_To_Texture_Cmd :: struct {
    src:  Texel_Copy_Texture_Info,
    dst:  Texel_Copy_Texture_Info,
    size: Extent_3D,
    loc:  runtime.Source_Code_Location,
}

Clear_Buffer_Cmd :: struct {
    dst:    Buffer,
    offset: u64,
    size:   u64,
    loc:    runtime.Source_Code_Location,
}

Clear_Texture_Cmd :: struct {
    dst:               Texture,
    subresource_range: Image_Subresource_Range,
    loc:               runtime.Source_Code_Location,
}

Build_Acceleration_Structures_Cmd :: struct {
    // TODO
    loc: runtime.Source_Code_Location,
}

Resolve_Query_Set_Cmd :: struct {
    query_set:          Query_Set,
    start_query:        u32,
    query_count:        u32,
    destination:        Buffer,
    destination_offset: u64,
    loc:                runtime.Source_Code_Location,
}

Buffer_Transition :: struct {
    buffer: Buffer,
    state:  Buffer_Uses,
}

Texture_Transition :: struct {
    texture:  Texture,
    selector: Maybe(Image_Subresource_Range),
    state:    Texture_Uses,
}

Transition_Buffer_Cmd :: struct {
    buffer:     Buffer,
    state_from: Buffer_Uses,
    state_to:   Buffer_Uses,
    loc:        runtime.Source_Code_Location,
}

Transition_Texture_Cmd :: struct {
    texture:       Texture,
    selector:      Maybe(Image_Subresource_Range),
    state_from:    Texture_Uses,
    state_to:      Texture_Uses,
    force_barrier: bool,
    loc:           runtime.Source_Code_Location,
}

Transition_Resources_Cmd :: struct {
    buffer_transitions:  []Buffer_Transition,
    texture_transitions: []Texture_Transition,
    loc:                 runtime.Source_Code_Location,
}

Command :: union {
    Begin_Render_Pass_Cmd,
    Render_Pass_End_Cmd,
    Begin_Compute_Pass_Cmd,
    Set_Bind_Group_Cmd,
    Set_Render_Pipeline_Cmd,
    Set_Index_Buffer_Cmd,
    Set_Vertex_Buffer_Cmd,
    Set_Blend_Constant_Cmd,
    Set_Stencil_Reference_Cmd,
    Set_Viewport_Cmd,
    Set_Scissor_Cmd,
    Set_Immediate_Cmd,
    Draw_Cmd,
    Draw_Indexed_Cmd,
    Draw_Mesh_Tasks_Cmd,
    Draw_Indirect_Cmd,
    Multi_Draw_Indirect_Count_Cmd,
    Push_Debug_Group_Cmd,
    Pop_Debug_Group_Cmd,
    Insert_Debug_Marker_Cmd,
    Write_Timestamp_Cmd,
    Begin_Occlusion_Query_Cmd,
    End_Occlusion_Query_Cmd,
    Begin_Pipeline_Statistics_Query_Cmd,
    End_Pipeline_Statistics_Query_Cmd,
    Execute_Bundle_Cmd,
    Copy_Buffer_To_Buffer_Cmd,
    Copy_Buffer_To_Texture_Cmd,
    Copy_Texture_To_Buffer_Cmd,
    Copy_Texture_To_Texture_Cmd,
    Clear_Buffer_Cmd,
    Clear_Texture_Cmd,
    Build_Acceleration_Structures_Cmd,
    Resolve_Query_Set_Cmd,
    // Transition_Resources_Cmd,
    Transition_Buffer_Cmd,
    Transition_Texture_Cmd,
}

COMMAND_ALLOCATOR_SHIFT :: #config(COMMAND_ALLOCATOR_SHIFT, 8)

Command_Allocator :: struct {
    data:      xar.Array(Command, COMMAND_ALLOCATOR_SHIFT),
    iterator:  xar.Array_Iterator(Command, COMMAND_ALLOCATOR_SHIFT),
    allocator: runtime.Allocator,
}

command_allocator_init :: proc(
    self: ^Command_Allocator,
    allocator := context.allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    xar.array_init(&self.data, allocator)
    command_allocator_iterator_reset(self)
}

command_allocator_destroy :: proc(self: ^Command_Allocator, loc := #caller_location) {
    assert(self != nil, loc = loc)
    context.allocator = self.allocator
    xar.destroy(&self.data)
}

command_allocator_reset :: proc(self: ^Command_Allocator, loc := #caller_location) {
    assert(self != nil, loc = loc)
    xar.clear(&self.data)
    command_allocator_iterator_reset(self)
}

command_allocator_iterator_reset :: proc(self: ^Command_Allocator, loc := #caller_location) {
    assert(self != nil, loc = loc)
    self.iterator = xar.array_iterator(&self.data)
}

command_allocator_is_empty :: proc(self: ^Command_Allocator, loc := #caller_location) -> bool {
    assert(self != nil, loc = loc)
    return xar.len(self.data) == 0
}

@(require_results)
command_allocator_allocate :: proc(
    self: ^Command_Allocator,
    $T: typeid,
    loc := #caller_location,
) -> (
    cmd: ^T,
    err: mem.Allocator_Error,
) where intr.type_is_variant_of(Command, T) #optional_allocator_error {
    assert(self != nil, loc = loc)
    union_cmd := xar.push_back_elem_and_get_ptr(&self.data, Command(T{})) or_return
    cmd = &union_cmd.(T)
    cmd.loc = loc
    return
}

command_allocator_allocate_cmd :: proc(
    self: ^Command_Allocator,
    cmd: $T,
    loc := #caller_location,
) -> (
    result: ^T,
    err: mem.Allocator_Error,
) where intr.type_is_variant_of(Command, T) #optional_allocator_error {
    assert(self != nil, loc = loc)
    union_cmd := xar.push_back_elem_and_get_ptr(&self.data, Command(cmd)) or_return
    result = &union_cmd.(T)
    result.loc = loc
    return
}

array_iterate_by_ptr :: proc(
    it: ^xar.Array_Iterator($T, $SHIFT),
) -> (
    val: ^T,
    idx: int,
    ok: bool,
) {
    if it.idx >= it.xar.len {
        // it.idx = 0
        return
    }
    val = xar.array_get_ptr(it.xar, it.idx)
    idx = it.idx
    it.idx += 1
    return val, idx, true
}
