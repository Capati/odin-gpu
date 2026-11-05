package gpu

// Pre-prepared reusable bundle of GPU operations.
//
// It only supports a handful of render commands, but it makes them reusable.
// Executing a `Render_Bundle` is often more efficient than issuing the
// underlying commands manually.
//
// It can be created by use of a `Render_Bundle_Encoder`, and executed onto a
// `Command_Encoder` using `render_pass_execute_bundles`.
//
// Corresponds to [WebGPU
// `GPURenderBundle`](https://gpuweb.github.io/gpuweb/#render-bundle).
Render_Bundle :: distinct Handle

// Describes a `Render_Bundle`.
//
// For use with `render_bundle_encoder_finish`.
//
// Corresponds to [WebGPU `GPURenderBundleDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderbundledescriptor).
Render_Bundle_Descriptor :: struct {
    // Debug label of the render bundle.
    label: string,
}

// Creates a render bundle encoder for recording reusable render commands.
device_create_render_bundle_encoder: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder

// Returns the render bundle's debug label.
//
// The string is owned by the render bundle and stays valid until the next
// `render_bundle_set_label()` or until the render bundle is released.
render_bundle_get_label: proc(render_bundle: Render_Bundle, loc := #caller_location) -> string

// Sets the render bundle's debug label.
//
// The render bundle keeps its own copy of `label`, so the caller may release
// its copy immediately after this call.
render_bundle_set_label: proc(render_bundle: Render_Bundle, label: string, loc := #caller_location)

// Increments the render bundle's reference count.
render_bundle_add_ref: proc(render_bundle: Render_Bundle, loc := #caller_location)

// Decrements the render bundle's reference count, destroying it when it reaches
// zero.
render_bundle_release: proc(render_bundle: Render_Bundle, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Render_Bundle_Impl :: struct {
    device:            Device,
    ref:               Ref_Count_Type,
    commands:          Command_Allocator,
    immediate_data:    [dynamic]u8,
    color_formats:     [MAX_COLOR_ATTACHMENTS]Texture_Format,
    color_count:       u32,
    depth_stencil:     Render_Bundle_Depth_Stencil,
    has_depth_stencil: bool,
    sample_count:      u32,
    // Resources named by the recorded commands stay alive until the bundle is
    // released, even if the application drops its own handle.
    pipelines:         [dynamic]Render_Pipeline,
    bind_groups:       [dynamic]Bind_Group,
    buffers:           [dynamic]Buffer,
}

// Returns the concrete implementation behind a render bundle handle.
_render_bundle_get_internal_impl: proc "contextless" (
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> ^_Render_Bundle_Impl
