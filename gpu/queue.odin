package gpu

// Handle to a command queue on a device.
//
// A `Queue` executes recorded `Command_Buffer` objects and provides host-side
// copies into buffers and textures. It can be created by calling
// `device_get_queue()`.
//
// Host writes (`queue_write_buffer`, `queue_write_texture`) are staged
// immediately, but they are not submitted to the GPU until the next
// `queue_submit()`. Submitting an empty command list is a valid way to flush
// them.
//
// Corresponds to [WebGPU
// `GPUQueue`](https://gpuweb.github.io/gpuweb/#gpu-queue).
Queue :: distinct Handle

// Describes the default `Queue`.
//
// Supplied through `Device_Descriptor.default_queue`.
Queue_Descriptor :: struct {
    // Debug label for the queue. Used by graphics debuggers and validation.
    label: string,
}

// Layout of a texture in a buffer's memory.
//
// Corresponds to [WebGPU `GPUTexelCopyBufferLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuimagedatalayout).
Texel_Copy_Buffer_Layout :: struct {
    // Offset into the buffer that is the start of the texture. Must be a
    // multiple of texture block size. For non-compressed textures, this is 1.
    //
    // `queue_write_texture` does not require this alignment.
    offset:         u64,
    // Bytes per "row" in an image.
    //
    // A row is one row of pixels or of compressed blocks in the x direction.
    //
    // This value is required if there are multiple rows or layers (i.e. height
    // is more than one pixel or pixel block, or depth is more than one).
    // `0` and `COPY_STRIDE_UNDEFINED` mean "unspecified".
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
    // `0` and `COPY_STRIDE_UNDEFINED` mean "unspecified"; when specified, the
    // value must be at least the copy height in blocks.
    rows_per_image: u32,
}

// Default texel copy layout: no offset and unspecified row/image strides.
DEFAULT_TEXEL_COPY_BUFFER_LAYOUT :: Texel_Copy_Buffer_Layout {
    offset         = 0,
    bytes_per_row  = COPY_STRIDE_UNDEFINED,
    rows_per_image = COPY_STRIDE_UNDEFINED,
}

// Submits `commands` and returns an identifier for the submission.
//
// This has the same behavior as `queue_submit()`, but also returns an opaque
// `Submission_Index`. Backends without submission indices (the browser) return
// `0`.
queue_submit_for_index: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index

// Returns the number of nanoseconds represented by one tick of a timestamp
// query.
//
// Returns zero if timestamp queries are unsupported. The browser backend
// reports timestamps in nanoseconds already, so it always returns `1.0`.
queue_get_timestamp_period: proc(queue: Queue, loc := #caller_location) -> f32

// Returns the underlying Metal command queue.
//
// Only meaningful on the Metal backend; returns `nil` on other backends.
queue_get_native_metal_command_queue: proc(queue: Queue, loc := #caller_location) -> rawptr

// Registers a callback for when the most recent `queue_submit()` finishes
// executing on the GPU.
//
// The returned `Future` resolves at the same time. Completion requires another
// `queue_submit()` or a wait through `instance_wait_any()`.
queue_on_submitted_work_done: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future

// Submits the given command buffers for execution.
//
// Pending host writes (`queue_write_buffer`, `queue_write_texture`) are
// submitted first. Every command buffer must belong to the queue's device and
// may only be submitted once. A rejected submission is reported through the
// device's validation errors and submits nothing; the command buffers are still
// consumed.
//
// Submitting an empty list is valid and flushes pending host writes.
queue_submit: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location)

// Copies `size` bytes from `data` into `buffer` at `offset`.
//
// The buffer must have the `Copy_Dst` usage, must not be mapped, and both
// `offset` and `size` must be multiples of 4. The range must lie within the
// buffer.
//
// The data is copied into staging memory immediately (the caller may reuse
// `data` after the call), but it is not submitted to the GPU until the next
// `queue_submit()`.
queue_write_buffer_raw: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
)

// Copies `data` into `buffer` at `offset`.
//
// See `queue_write_buffer_raw` for the requirements and submission behavior.
queue_write_buffer_bytes :: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: []u8,
    loc := #caller_location,
) {
    #force_inline queue_write_buffer_raw(queue, buffer, offset, raw_data(data), len(data), loc)
}

queue_write_buffer :: proc {
    queue_write_buffer_raw,
    queue_write_buffer_bytes,
}

// Copies `data` into a texture.
//
// The texture must have the `Copy_Dst` usage and must not be multisampled.
// `destination` selects the mip level, origin, and aspect; `write_size` is the
// size of the written region in texels and must fit inside that mip level.
// `data_layout` describes the source memory layout, and `data` must contain the
// whole described region.
//
// `bytes_per_row` is required when the copy spans multiple rows or layers, and
// `rows_per_image` is required when it spans multiple layers. Unlike
// command-buffer copies, `queue_write_texture` does not require a 256-byte row
// pitch.
//
// A zero-sized write is a no-op. The data is staged immediately and submitted
// on the next `queue_submit()`.
queue_write_texture: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []u8,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
)

// Returns the `Queue`'s debug label.
//
// The string is owned by the `Queue` and stays valid until the next
// `queue_set_label()` or until the `Queue` is released.
queue_get_label: proc(queue: Queue, loc := #caller_location) -> string

// Sets the `Queue`'s debug label.
//
// The `Queue` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
queue_set_label: proc(queue: Queue, label: string, loc := #caller_location)

// Increments the queue's reference count.
queue_add_ref: proc(queue: Queue, loc := #caller_location)

// Decrements the queue's reference count, destroying it when it reaches zero.
queue_release: proc(queue: Queue, loc := #caller_location)
