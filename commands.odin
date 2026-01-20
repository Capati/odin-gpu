package gpu

// Core
import "base:runtime"
import "core:mem"
import sa "core:container/small_array"

Command_Timestamp_Writes :: struct {
    query_set:                     ^Query_Set,
    beginning_of_pass_write_index: u32,
    end_of_pass_write_index:       u32,
}

Command_Begin_Compute_Pass :: struct {
    timestamp_writes: Command_Timestamp_Writes,
    label:            string,
}

Command_Begin_Render_Pass :: struct {
    render_pass:              Render_Pass,
    color_attachments:        sa.Small_Array(MAX_COLOR_ATTACHMENTS, Render_Pass_Color_Attachment),
    depth_stencil_attachment: Maybe(Render_Pass_Depth_Stencil_Attachment),
    width:                    u32,
    height:                   u32,
}

Command_Render_Pass_Set_Render_Pipeline :: struct {
    render_pass: Render_Pass,
    pipeline:    Render_Pipeline,
}

Command_Render_Pass_Set_Bind_Group :: struct {
    render_pass:     Render_Pass,
    group_index:     u32,
    group:           Bind_Group,
    dynamic_offsets: []u32,
}

Command_Render_Pass_Set_Vertex_Buffer :: struct {
    render_pass: Render_Pass,
    pipeline:    Render_Pipeline,
    slot:        u32,
    buffer:      Buffer,
    offset:      u64,
    size:        u64,
}

Command_Render_Pass_Set_Index_Buffer :: struct {
    render_pass: Render_Pass,
    buffer:      Buffer,
    format:      Index_Format,
    offset:      u64,
    size:        u64,
}

Command_Render_Pass_Set_Scissor_Rect :: struct {
    x:      u32,
    y:      u32,
    width:  u32,
    height: u32,
}

Command_Render_Pass_Set_Viewport :: struct {
    x:         f32,
    y:         f32,
    width:     f32,
    height:    f32,
    min_depth: f32,
    max_depth: f32,
}

Command_Render_Pass_Set_Stencil_Reference :: struct {
    render_pass: Render_Pass,
    pipeline:    Render_Pipeline,
    reference:   u32,
}

Command_Render_Pass_Draw :: struct {
    render_pass:    Render_Pass,
    pipeline:       Render_Pipeline,
    vertex_count:   u32,
    instance_count: u32,
    first_vertex:   u32,
    first_instance: u32,
}

Command_Render_Pass_Draw_Indexed :: struct {
    render_pass:    Render_Pass,
    index_count:    u32,
    instance_count: u32,
    first_index:    u32,
    vertex_offset:  i32,
    first_instance: u32,
}

Command_Render_Pass_End :: struct {
    render_pass: Render_Pass,
}

Command_Copy_Buffer_To_Buffer :: struct {
    source:             Buffer,
    source_offset:      u64,
    destination:        Buffer,
    destination_offset: u64,
    size:               u64,
}

Command_Copy_Buffer_To_Texture :: struct {
    source:      Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size:   Extent_3D,
}

Command_Copy_Texture_To_Texture :: struct {
    source:      Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size:   Extent_3D,
}

Command_Finish :: struct {
    cmd_buf: Command_Buffer,
}

// All possible command types.
Command :: union #no_nil {
    Command_Begin_Render_Pass,
    Command_Render_Pass_Set_Render_Pipeline,
    Command_Render_Pass_Set_Bind_Group,
    Command_Render_Pass_Set_Vertex_Buffer,
    Command_Render_Pass_Set_Index_Buffer,
    Command_Render_Pass_Set_Scissor_Rect,
    Command_Render_Pass_Set_Viewport,
    Command_Render_Pass_Set_Stencil_Reference,
    Command_Render_Pass_Draw,
    Command_Render_Pass_Draw_Indexed,
    Command_Copy_Buffer_To_Buffer,
    Command_Copy_Buffer_To_Texture,
    Command_Copy_Texture_To_Texture,
    Command_Render_Pass_End,
    Command_Finish,
}

Command_Allocator :: struct {
    data:      [dynamic]Command,
    allocator: runtime.Allocator,
}

// Initialize a `Command_Allocator`.
command_allocator_init :: proc(
    self: ^Command_Allocator,
    allocator := context.allocator,
    loc := #caller_location,
) {
    assert(self != nil, loc = loc)
    self.data = make([dynamic]Command, allocator)
    reserve(&self.data, 16)
}

command_allocator_destroy :: proc(self: ^Command_Allocator, loc := #caller_location) {
    assert(self != nil, loc = loc)
    context.allocator = self.allocator
    delete(self.data)
}

command_allocator_reset :: proc(self: ^Command_Allocator, loc := #caller_location) {
    assert(self != nil, loc = loc)
    clear(&self.data)
}

command_allocator_is_empty :: proc(self: ^Command_Allocator, loc := #caller_location) -> bool {
    assert(self != nil, loc = loc)
    return len(self.data) == 0
}

command_allocator_allocate :: proc(
    self: ^Command_Allocator,
    $T: typeid,
    loc := #caller_location,
) -> (
    cmd: ^T,
    err: mem.Allocator_Error,
) #optional_allocator_error {
    assert(self != nil, loc = loc)
    append(&self.data, T{}) or_return
    return cast(^T)&self.data[len(self.data) - 1], nil
}
