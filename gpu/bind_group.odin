package gpu

// Handle to a binding group.
//
// A `Bind_Group` represents the set of resources bound to the bindings
// described by a `Bind_Group_Layout`. It can be created with
// `device_create_bind_group`. A `Bind_Group` can be bound to a particular
// `Render_Pass` with `render_pass_set_bind_group`, or to a `Compute_Pass` with
// `compute_pass_set_bind_group`.
//
// Corresponds to [WebGPU
// `GPUBindGroup`](https://gpuweb.github.io/gpuweb/#gpubindgroup).
Bind_Group :: distinct Handle

@private
Bind_Group_Impl :: struct {
    device: Device,
    layout: Bind_Group_Layout,
    used:   Bind_Group_States,
    ref:    Ref_Count_Type,
}

@private
bind_group_get_public_impl: proc "contextless" (
    bind_group: Bind_Group,
    loc := #caller_location,
) -> ^Bind_Group_Impl

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
    // `render_pass_set_bind_group` or `compute_pass_set_bind_group`.
    //
    // If the buffer was created with `Uniform` usage, then this offset must be
    // a multiple of `min_uniform_buffer_offset_alignment` limit.
    //
    // If the buffer was created with `Storage` usage, then this offset must be
    // a multiple of `min_storage_buffer_offset_alignment` limit.
    offset: u64,
    // Size of the binding in bytes, or `WHOLE_SIZE` for using the rest of the buffer.
    size: u64,
}

// Resource to be bound by a `Bind_Group` for use with a pipeline.
//
// The pipeline’s `Bind_Group_Layout` must contain a matching `Binding_Type`.
//
// Corresponds to [WebGPU `GPUBindingResource`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpubindingresource).
Binding_Resource :: union {
    Buffer_Binding,
    []Buffer_Binding,
    Sampler,
    []Sampler,
    Texture_View,
    []Texture_View,
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
    label:         string,
    // The `Bind_Group_Layout` that corresponds to this bind group.
    layout:        Bind_Group_Layout,
    // The resources to bind to this bind group.
    entries:       []Bind_Group_Entry,
}

// Creates a new `Bind_Group`.
device_create_bind_group: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group

bind_group_set_label: proc(bind_group: Bind_Group, label: string, loc := #caller_location)

bind_group_add_ref: proc(bind_group: Bind_Group, loc := #caller_location)

bind_group_release: proc(bind_group: Bind_Group, loc := #caller_location)
