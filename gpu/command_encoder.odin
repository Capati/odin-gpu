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

@private
Command_Encoder_Impl :: struct {
    device:         Device,
    command_buffer: Command_Buffer,
    ref:            Ref_Count_Type,
    is_encoding:    bool,
    is_computing:   bool,
    is_rendering:   bool,
}

@private
command_encoder_get_public_impl: proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^Command_Encoder_Impl

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

device_create_command_encoder: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor = {},
    loc := #caller_location,
) -> Command_Encoder

command_encoder_clear_texture: proc(
    command_encoder: Command_Encoder,
    texture: Texture,
    range: Image_Subresource_Range,
    loc := #caller_location,
)

command_encoder_begin_compute_pass: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass

command_encoder_begin_render_pass: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass

command_encoder_clear_buffer: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
)

command_encoder_copy_buffer_to_buffer: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
)

command_encoder_copy_buffer_to_texture: proc(
    command_encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
)

command_encoder_copy_texture_to_buffer: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
)

command_encoder_copy_texture_to_texture: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
)

command_encoder_finish: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer

command_encoder_insert_debug_marker: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
)

command_encoder_pop_debug_group: proc(command_encoder: Command_Encoder, loc := #caller_location)

command_encoder_push_debug_group: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
)

command_encoder_resolve_query_set: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
)

command_encoder_set_label: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
)

command_encoder_write_timestamp: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
)

command_encoder_add_ref: proc(command_encoder: Command_Encoder, loc := #caller_location)

command_encoder_release: proc(command_encoder: Command_Encoder, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private
// -----------------------------------------------------------------------------

// Temporary allocator used during the recording of this command encoder.
//
// The allocator is reset when the command buffer's completion fence signals.
@private
command_encoder_arena_allocator: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> runtime.Allocator

@private
command_encoder_transition_buffers: proc(
    command_encoder: Command_Encoder,
    barriers: []Buffer_Barrier,
    loc := #caller_location,
)
