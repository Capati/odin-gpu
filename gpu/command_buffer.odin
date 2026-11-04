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

// Describes a `Command_Buffer`.
//
// Corresponds to [WebGPU `GPUCommandBufferDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpucommandbufferdescriptor).
Command_Buffer_Descriptor :: struct {
    // Debug label of this command buffer.
    label: string,
}

// Returns the `Command_Buffer`'s debug label.
//
// The string is owned by the `Command_Buffer` and stays valid until the next
// `command_buffer_set_label()` or until the `Command_Buffer` is released.
command_buffer_get_label: proc(command_buffer: Command_Buffer, loc := #caller_location) -> string

// Sets the `Command_Buffer`'s debug label.
//
// The `Command_Buffer` keeps its own copy of `label`, so the caller may release
// its copy immediately after this call.
command_buffer_set_label: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
)

// Increments the command buffer's reference count.
command_buffer_add_ref: proc(command_buffer: Command_Buffer, loc := #caller_location)

// Decrements the command buffer's reference count, destroying it when it reaches
// zero.
command_buffer_release: proc(command_buffer: Command_Buffer, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Command_Buffer_Impl :: struct {
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

_command_buffer_get_impl: proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^_Command_Buffer_Impl

// Temporary allocator used during the recording of this command buffer.
//
// The allocator is reset when the command buffer's completion fence signals.
_command_buffer_arena_allocator: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> runtime.Allocator
