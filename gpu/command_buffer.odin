package gpu

// Core
import "base:runtime"

// Handle to a command buffer on the GPU.
//
// A `Command_Buffer` represents a complete sequence of commands that may be
// submitted to a command queue with `queue_submit`. A `Command_Buffer` is
// obtained by recording a series of commands to a `Command_Encoder` and then
// calling `command_encoder_finish`.
//
// Corresponds to [WebGPU
// `GPUCommandBuffer`](https://gpuweb.github.io/gpuweb/#command-buffer).
Command_Buffer :: distinct Handle

@private
Command_Buffer_Impl :: struct {
    device:       Device,
    commands:     Command_Allocator,
    tracker:      Tracker,
    scope_pool:   Usage_Scope_Pool,
    pass_scope:   Usage_Scope,
    // Usage recorded by commands recorded outside any pass (copies, clears).
    // WebGPU scopes those together for the whole command buffer, separately
    // from the per-pass scope, so a copy either side of a pass is ordered
    // rather than treated as a conflict.
    global_scope: Usage_Scope,
    ref:          Ref_Count_Type,
    is_active:    bool,
}

@private
command_buffer_get_public_impl: proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^Command_Buffer_Impl

// Describes a `Command_Buffer`.
//
// Corresponds to [WebGPU `GPUCommandBufferDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpucommandbufferdescriptor).
Command_Buffer_Descriptor :: struct {
    // Debug label of this command buffer.
    label: string,
}

command_buffer_set_label: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
)

command_buffer_add_ref: proc(command_buffer: Command_Buffer, loc := #caller_location)

command_buffer_release: proc(command_buffer: Command_Buffer, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private procedures
// -----------------------------------------------------------------------------

// Temporary allocator used during the recording of this command buffer.
//
// The allocator is reset when the command buffer's completion fence signals.
command_buffer_arena_allocator: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> runtime.Allocator
