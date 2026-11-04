package gpu

// Core
import "base:runtime"

// Encodes a series of GPU operations.
//
// A command encoder can record `Render_Pass`es, `Compute_Pass`es, and transfer
// operations between driver-managed resources like `Buffer`s and `Texture`s.
//
// When finished recording, call `command_encoder_finish` to obtain a
// `Command_Buffer` which may be submitted for execution.
//
// Corresponds to [WebGPU
// `GPUCommandEncoder`](https://gpuweb.github.io/gpuweb/#command-encoder).
Command_Encoder :: distinct Handle

// Describes a `Command_Encoder`.
//
// For use with `device_create_command_encoder`.
//
// Corresponds to [WebGPU `GPUCommandEncoderDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpucommandencoderdescriptor).
Command_Encoder_Descriptor :: struct {
    // Debug label of this command encoder.
    label: string,
}

// View of a buffer which can be used to copy to/from a texture.
//
// Corresponds to [WebGPU `GPUTexelCopyBufferInfo`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuimagecopybuffer).
Texel_Copy_Buffer_Info :: struct {
    // The buffer to be copied to/from.
    buffer: Buffer,
    // The layout of the texture data in this buffer.
    layout: Texel_Copy_Buffer_Layout,
}

DEFAULT_TEXEL_COPY_BUFFER_INFO :: Texel_Copy_Buffer_Info {
    layout = DEFAULT_TEXEL_COPY_BUFFER_LAYOUT,
    buffer = {},
}

// View of a texture which can be used to copy to/from a buffer/texture.
//
// Corresponds to [WebGPU `GPUTexelCopyTextureInfo`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuimagecopytexture).
Texel_Copy_Texture_Info :: struct {
    // The texture to be copied to/from.
    texture:   Texture,
    // The target mip level of the texture.
    mip_level: u32,
    // The base texel of the texture in the selected `mip_level`. Together with
    // the `copy_size` argument to copy functions, defines the sub-region of the
    // texture to copy.
    origin:    Origin_3D,
    // The copy aspect.
    aspect:    Texture_Aspect,
}

// Subresource range within an image.
Image_Subresource_Range :: struct {
    // Aspect of the texture. Color textures must be `Texture_Aspect.All`.
    aspect:            Texture_Aspect,
    // Base mip level.
    base_mip_level:    u32,
    // Mip level count.
    //
    // A value of `0` includes the remaining mip levels, but at least one.
    // Otherwise, `base_mip_level + mip_level_count` must be less than or equal
    // to the underlying texture mip count.
    mip_level_count:   u32,
    // Base array layer.
    base_array_layer:  u32,
    // Layer count.
    //
    // A value of `0` includes the remaining array layers, but at least one.
    // Otherwise, `base_array_layer + array_layer_count` must be less than or
    // equal to the underlying array layer count.
    array_layer_count: u32,
}

// Creates a command encoder.
//
// Returns `{}` if the backend cannot create one.
device_create_command_encoder: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor = {},
    loc := #caller_location,
) -> Command_Encoder

// Clears every texel in `range` to zero.
//
// Unlike `command_encoder_clear_buffer`, the texture does not need the
// `Copy_Dst` usage. The subresource range must be in bounds.
command_encoder_clear_texture: proc(
    command_encoder: Command_Encoder,
    texture: Texture,
    range: Image_Subresource_Range,
    loc := #caller_location,
)

// Begins a compute pass.
//
// Only one pass may be recording at a time; mutating the encoder while the
// pass is active is invalid.
command_encoder_begin_compute_pass: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass

// Begins a render pass.
//
// Only one pass may be recording at a time; mutating the encoder while the
// pass is active is invalid.
command_encoder_begin_render_pass: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass

// Clears a buffer range to zero.
//
// The buffer must have the `Copy_Dst` usage. `offset` and `size` must be
// multiples of 4 and the range must lie within the buffer; `WHOLE_SIZE` means
// "from `offset` to the end".
command_encoder_clear_buffer: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

// Internal zero-fill used for allocation padding. It records the clear without
// the public range/usage validation; the caller owns tracker transitions and
// initialization bookkeeping.
_command_encoder_clear_buffer_internal: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

// Copies a buffer range into another buffer.
//
// Both offsets and `size` must be multiples of 4 and the ranges must stay in
// bounds. Source needs `Copy_Src`, destination needs `Copy_Dst`; copying a
// buffer onto itself is invalid.
command_encoder_copy_buffer_to_buffer: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
)

// Copies a buffer region into a texture.
//
// `source.layout` describes the buffer rows; `bytes_per_row` must be a multiple
// of 256 and the buffer range must contain the described data.
command_encoder_copy_buffer_to_texture: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
)

// Copies a texture region into a buffer.
//
// `destination.layout` describes the buffer rows; `bytes_per_row` must be a
// multiple of 256 and the buffer range must fit the described data.
command_encoder_copy_texture_to_buffer: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
)

// Copies one texture region into another.
//
// The textures must be copy-compatible; depth and multisampled textures must be
// copied in full, and both ranges must stay in bounds.
command_encoder_copy_texture_to_texture: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
)

// Finishes recording and returns a command buffer ready for submission.
//
// The encoder is consumed; further recording calls are invalid.
command_encoder_finish: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer

// Inserts a debug marker at this point in the command stream.
command_encoder_insert_debug_marker: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
)

// Ends the most recent debug group started by
// `command_encoder_push_debug_group`.
command_encoder_pop_debug_group: proc(command_encoder: Command_Encoder, loc := #caller_location)

// Starts a debug group with `group_label`.
command_encoder_push_debug_group: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
)

// Copies `query_count` query results starting at `first_query` into
// `destination`.
//
// `destination_offset` must be a multiple of 256 and the destination needs the
// `Query_Resolve` usage. Each result occupies 8 bytes.
command_encoder_resolve_query_set: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
)

// Writes a timestamp for `query_set` at `query_index`.
//
// Requires timestamp queries inside encoders on the device.
command_encoder_write_timestamp: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

// Returns the `Command_Encoder`'s debug label.
//
// The string is owned by the `Command_Encoder` and stays valid until the next
// `command_encoder_set_label()` or until the `Command_Encoder` is released.
command_encoder_get_label: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string

// Sets the `Command_Encoder`'s debug label.
//
// The `Command_Encoder` keeps its own copy of `label`, so the caller may
// release its copy immediately after this call.
command_encoder_set_label: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
)

// Increments the command encoder's reference count.
command_encoder_add_ref: proc(command_encoder: Command_Encoder, loc := #caller_location)

// Decrements the command encoder's reference count, destroying it when it
// reaches zero.
command_encoder_release: proc(command_encoder: Command_Encoder, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Command_Encoder_Impl :: struct {
    device:         Device,
    command_buffer: Command_Buffer,
    ref:            Ref_Count_Type,
    is_encoding:    bool,
    is_computing:   bool,
    is_rendering:   bool,
}

_command_encoder_get_impl: proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^_Command_Encoder_Impl

// Temporary allocator used during the recording of this command encoder.
//
// The allocator is reset when the command buffer's completion fence signals.
_command_encoder_arena_allocator: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> runtime.Allocator

_command_encoder_transition_buffers: proc(
    command_encoder: Command_Encoder,
    barriers: []Buffer_State_Transition,
    loc := #caller_location,
)
