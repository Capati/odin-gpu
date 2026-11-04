package gpu

// Handle to a binding group.
//
// A `Bind_Group` represents the set of resources bound to the bindings
// described by a `Bind_Group_Layout`. It can be created with
// `device_create_bind_group`, and its entries must match the layout's entries.
//
// A `Bind_Group` can be bound to a `Render_Pass` with
// `render_pass_set_bind_group`, to a `Compute_Pass` with
// `compute_pass_set_bind_group`, or recorded into a `Render_Bundle_Encoder`
// with `render_bundle_encoder_set_bind_group`.
//
// Corresponds to [WebGPU
// `GPUBindGroup`](https://gpuweb.github.io/gpuweb/#gpubindgroup).
Bind_Group :: distinct Handle

// Describes the segment of a buffer to bind.
//
// Corresponds to [WebGPU `GPUBufferBinding`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubufferbinding).
Buffer_Binding :: struct {
    // The buffer to bind.
    buffer: Buffer,
    // Base offset of the buffer, in bytes.
    //
    // If the `has_dynamic_offset` field of this buffer's layout entry is
    // `true`, the offset here will be added to the dynamic offset passed to
    // `render_pass_set_bind_group`, `compute_pass_set_bind_group` or
    // `render_bundle_encoder_set_bind_group`.
    //
    // If the buffer was created with `Uniform` usage, then this offset must be
    // a multiple of `min_uniform_buffer_offset_alignment` limit.
    //
    // If the buffer was created with `Storage` usage, then this offset must be
    // a multiple of `min_storage_buffer_offset_alignment` limit.
    offset: u64,
    // Size of the binding in bytes, or `WHOLE_SIZE` for using the rest of the
    // buffer. A size of `0` is rejected.
    size:   u64,
}

// A single buffer. The layout entry must not be an array.
Buffer_Binding_Resource :: Buffer_Binding

// An array of buffers. The layout entry must be an array and
// `Buffer_Binding_Array` must be enabled.
Buffer_Binding_Array_Resource :: []Buffer_Binding

// A single sampler. The layout entry must not be an array.
Sampler_Binding_Resource :: Sampler

// An array of samplers. The layout entry must be an array and
// `Texture_Binding_Array` must be enabled.
Sampler_Binding_Array_Resource :: []Sampler

// A single sampled or storage texture view. The layout entry must not be an
// array.
Texture_View_Binding_Resource :: Texture_View

// An array of texture views. The layout entry must be an array and
// `Texture_Binding_Array` must be enabled.
Texture_View_Binding_Array_Resource :: []Texture_View

// Resource to be bound by a `Bind_Group` for use with a pipeline.
//
// The pipeline’s `Bind_Group_Layout` must contain a matching `Binding_Type`.
//
// Corresponds to [WebGPU `GPUBindingResource`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpubindingresource).
Binding_Resource :: union {
    Buffer_Binding_Resource,
    Buffer_Binding_Array_Resource,
    Sampler_Binding_Resource,
    Sampler_Binding_Array_Resource,
    Texture_View_Binding_Resource,
    Texture_View_Binding_Array_Resource,
}

// An element of a `Bind_Group_Descriptor`, consisting of a bindable resource
// and the slot to bind it to.
//
// Corresponds to [WebGPU `GPUBindGroupEntry`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubindgroupentry).
Bind_Group_Entry :: struct {
    // Slot for which binding provides resource. Corresponds to an entry of the
    // same binding index in the `Bind_Group_Layout_Descriptor`.
    binding:  u32,
    // Resource to attach to the binding.
    resource: Binding_Resource,
}

// Describes a group of bindings and the resources to be bound.
//
// For use with `device_create_bind_group`.
//
// Corresponds to [WebGPU `GPUBindGroupDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubindgroupdescriptor).
Bind_Group_Descriptor :: struct {
    // Debug label of the bind group.
    label:   string,
    // The `Bind_Group_Layout` that corresponds to this bind group.
    layout:  Bind_Group_Layout,
    // The resources to bind to this bind group. Must contain one entry per
    // binding declared by `layout`, each with the declared binding index.
    entries: []Bind_Group_Entry,
}

// Creates a new `Bind_Group`.
device_create_bind_group: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group

// Returns the `Bind_Group`'s debug label.
//
// The string is owned by the `Bind_Group` and stays valid until the next
// `bind_group_set_label()` or until the `Bind_Group` is released.
bind_group_get_label: proc(bind_group: Bind_Group, loc := #caller_location) -> string

// Sets the `Bind_Group`'s debug label.
//
// The `Bind_Group` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
bind_group_set_label: proc(bind_group: Bind_Group, label: string, loc := #caller_location)

// Increments the reference count of `bind_group`.
bind_group_add_ref: proc(bind_group: Bind_Group, loc := #caller_location)

// Decrements the reference count of `bind_group`, destroying it when the count
// reaches zero.
bind_group_release: proc(bind_group: Bind_Group, loc := #caller_location)
