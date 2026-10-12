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
Render_Bundle :: distinct rawptr

// Describes a `Render_Bundle`.
//
// For use with `render_bundle_encoder_finish`.
//
// Corresponds to [WebGPU `GPURenderBundleDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpurenderbundledescriptor).
Render_Bundle_Descriptor :: struct {
    // Debug label of the render bundle encoder.
    label: string,
}

device_create_render_bundle_encoder: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder

render_bundle_set_label: proc(render_bundle: Render_Bundle, label: string, loc := #caller_location)

render_bundle_add_ref: proc(render_bundle: Render_Bundle, loc := #caller_location)

render_bundle_release: proc(render_bundle: Render_Bundle, loc := #caller_location)
