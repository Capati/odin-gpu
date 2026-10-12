package gpu

// Handle to a binding group layout.
//
// A `Bind_Group_Layout` is a handle to the GPU-side layout of a binding group.
// It can be used to create a `Bind_Group_Descriptor` object, which in turn can
// be used to create a `Bind_Group` object with `device_create_bind_group`. A
// series of `Bind_Group_Layout`s can also be used to create a
// `Pipeline_Layout_Descriptor`, which can be used to create a
// `Pipeline_Layout`.
//
// It can be created with `device_create_bind_group_layout`.
//
// Corresponds to [WebGPU `GPUBindGroupLayout`](
// https://gpuweb.github.io/gpuweb/#gpubindgrouplayout).
Bind_Group_Layout :: distinct Handle

Bind_Group_Layout_Impl :: struct {
    device: Device,
    entries: map[u32]Bind_Group_Layout_Entry,
}

@private
bind_group_layout_get_public_impl: proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^Bind_Group_Layout_Impl

// A buffer binding.
//
// Corresponds to [WebGPU `GPUBufferBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubufferbindinglayout).
Buffer_Binding_Layout :: struct {
    // Sub-type of the buffer binding.
    type:               Buffer_Binding_Type,
    // Indicates that the binding has a dynamic offset.
    //
    // One offset must be passed to `render_pass_set_bind_group`
    // for each dynamic binding in increasing order of binding number.
    has_dynamic_offset: bool,
    // The minimum size for a `Buffer_Binding` matching this entry, in bytes.
    //
    // If this is not `0`:
    //
    // - When calling `device_create_bind_group`, the resource at this bind
    //   point must be a `Binding_Resource.Buffer` whose effective size is at
    //   least `size`.
    //
    // - When calling `device_create_render_pipeline` or
    //   `device_create_compute_pipeline`, `size` must be at least the minimum
    //   buffer binding size for the shader module global at this bind point:
    //   large enough to hold the global's value, along with one element of a
    //   trailing runtime-sized array, if present.
    //
    // If this is `0`:
    //
    // - Each draw or dispatch command checks that the buffer range at this bind
    //   point satisfies the minimum buffer binding size.
    min_binding_size:   u64,
}

// A sampler that can be used to sample a texture.
//
// Corresponds to [WebGPU `GPUSamplerBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpusamplerbindinglayout).
Sampler_Binding_Layout :: struct {
    // Specific type of a sampler binding.
    type: Sampler_Binding_Type,
}

// A texture binding layout.
//
// Corresponds to [WebGPU `GPUTextureBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gputexturebindinglayout).
Texture_Binding_Layout :: struct {
    // Sample type of the texture binding.
    sample_type:    Texture_Sample_Type,
    // Dimension of the texture view used by the binding.
    view_dimension: Texture_View_Dimension,
    // True if the texture view is multisampled.
    multisampled:   bool,
}

// A storage texture.
//
// Corresponds to [WebGPU `GPUStorageTextureBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpustoragetexturebindinglayout).
Storage_Texture_Binding_Layout :: struct {
    // Allowed access to this texture.
    access:         Storage_Texture_Access,
    // Format of the texture.
    format:         Texture_Format,
    // Dimension of the texture view that is going to be sampled.
    view_dimension: Texture_View_Dimension,
}

// An external texture binding.
//
// Corresponds to [WebGPU `GPUExternalTextureBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuexternaltexturebindinglayout).
//
// Requires `External_Texture` feature.
External_Texture_Binding_Layout :: struct {
    external_texture: External_Texture,
}

// Type of a binding in a bind group layout.
//
// For each binding in a layout, a `Bind_Group` must provide a
// `Binding_Resource` of the corresponding type.
//
// Corresponds to WebGPU's mutually exclusive fields within
// [`GPUBindGroupLayoutEntry`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubindgrouplayoutentry).
Binding_Type :: union {
    Buffer_Binding_Layout,
    Sampler_Binding_Layout,
    Texture_Binding_Layout,
    Storage_Texture_Binding_Layout,
    External_Texture_Binding_Layout,
}

// Describes a single binding inside a bind group.
//
// Corresponds to [WebGPU `GPUBindGroupLayoutEntry`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubindgrouplayoutentry).
Bind_Group_Layout_Entry :: struct {
    // Binding index. Must match shader index and be unique inside a
    // `Bind_Group_Layout`.
    binding:    u32,
    // Which shader stages can see this binding.
    visibility: Shader_Stages,
    // The type of the binding.
    type:       Binding_Type,
    // If the binding is an array of multiple resources.
    //
    // When this is non-zero the following validation applies:
    //
    // - Count must be of value 1 or greater, this corresponds to the length of
    //   the array of resources that will be bound.
    // - When `type == Binding_Type.Texture`, the feature
    //   `Texture_Binding_Array` must be supported.
    // - When `type == Binding_Type.Sampler`, the feature
    //   `Texture_Binding_Array` must be supported.
    // - When `type == Binding_Type.Buffer`, the feature `Buffer_Binding_Array`
    //   must be supported.
    // - When `type == Binding_Type.Buffer` and `type.type ==
    //   Buffer_Binding_Type_Storage`, the feature
    //   `Storage_Resource_Binding_Array` must be supported.
    // - When `type == Binding_TypeStorageTexture`, the feature
    //   `Storage_Resource_Binding_Array` must be supported.
    // - When any binding in the group is an array, no `Binding_Type.Buffer` in
    //   the group may have `has_dynamic_offset == true`
    // - When any binding in the group is an array, no `Binding_Type.Buffer` in
    //   the group may have `type.type == Buffer_Binding_Type.Uniform`.
    // - If `Partially_Bound_Binding_Array` feature is enabled, the specified
    //   count becomes the upper bound instead.
    count:      u32,
}

// Describes a `Bind_Group_Layout`.
//
// For use with `device_create_bind_group_layout`.
//
// Corresponds to [WebGPU `GPUBindGroupLayoutDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubindgrouplayoutdescriptor).
Bind_Group_Layout_Descriptor :: struct {
    // Debug label of the bind group layout.
    label:   string,
    // Array of entries in this `Bind_Group_Layout`.
    entries: []Bind_Group_Layout_Entry,
}

device_create_bind_group_layout: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout

bind_group_layout_set_label: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
)

bind_group_layout_add_ref: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location)

bind_group_layout_release: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location)
