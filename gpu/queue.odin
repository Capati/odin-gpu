package gpu

// Handle to a command queue on a device.
//
// A `Queue` executes recorded `Command_Buffer` objects and provides convenience
// methods for writing to buffers and textures. It can be created by calling
// `device_get_queue`.
//
// Corresponds to [WebGPU
// `GPUQueue`](https://gpuweb.github.io/gpuweb/#gpu-queue).
Queue :: distinct Handle

@private
Queue_Impl :: struct {
    device:          Device,
    deferred_writes: Deferred_Writes,
    ref:             Ref_Count_Type,
}

@private
queue_get_public_impl: proc "contextless" (
    queue: Queue,
    loc := #caller_location,
) -> ^Queue_Impl

// Describes a default `Queue`.
Queue_Descriptor :: struct {
    // Debug label for the queue.
    label: string,
}

// Layout of a texture in a buffer's memory.
//
// Corresponds to [WebGPU `GPUTexelCopyBufferLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuimagedatalayout).
Texel_Copy_Buffer_Layout :: struct {
    // Offset into the buffer that is the start of the texture. Must be a
    // multiple of texture block size. For non-compressed textures, this is 1.
    offset:         u64,
    // Bytes per "row" in an image.
    //
    // A row is one row of pixels or of compressed blocks in the x direction.
    //
    // This value is required if there are multiple rows (i.e. height or depth
    // is more than one pixel or pixel block for compressed textures)
    //
    // Must be a multiple of 256 for `command_encoder_copy_buffer_to_texture`
    // and `command_encoder_copy_texture_to_buffer`. You must manually pad the
    // buffer as if the image width is a multiple of 256. An image of size (500,
    // 500) can be written to a buffer of size (512, 500) with `bytes_per_row`
    // of 512,
    //
    // `queue_write_texture` does not have this requirement.
    //
    // Must be a multiple of the texture block size. For non-compressed
    // textures, this is 1.
    bytes_per_row:  u32,
    // "Rows" that make up a single "image".
    //
    // A row is one row of pixels or of compressed blocks in the x direction.
    //
    // An image is one layer in the z direction of a 3D image or 2D_Array texture.
    //
    // The amount of rows per image may be larger than the actual amount of rows of data.
    //
    // Required if there are multiple images (i.e. the depth is more than one).
    rows_per_image: u32,
}

DEFAULT_TEXEL_COPY_BUFFER_LAYOUT :: Texel_Copy_Buffer_Layout {
    offset         = 0,
    bytes_per_row  = COPY_STRIDE_UNDEFINED,
    rows_per_image = COPY_STRIDE_UNDEFINED,
}

queue_submit_for_index: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index

queue_get_timestamp_period: proc(queue: Queue, loc := #caller_location) -> f32

queue_get_native_metal_command_queue: proc(queue: Queue, loc := #caller_location) -> rawptr

queue_on_submitted_work_done: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future

queue_set_label: proc(queue: Queue, label: string, loc := #caller_location)

queue_submit: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location)

queue_write_buffer_raw: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

queue_write_buffer_bytes :: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: []u8,
    loc := #caller_location,
) {
    #force_inline queue_write_buffer_raw(
        queue, buffer, offset, raw_data(data), len(data), loc)
}

queue_write_buffer :: proc {
    queue_write_buffer_raw,
    queue_write_buffer_bytes,
}

queue_write_texture: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []u8,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
)

queue_add_ref: proc(queue: Queue, loc := #caller_location)

queue_release: proc(queue: Queue, loc := #caller_location)
