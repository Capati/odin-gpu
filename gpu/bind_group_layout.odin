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

// Specific type of a buffer binding.
//
// Corresponds to [WebGPU `GPUBufferBindingType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpubufferbindingtype).
Buffer_Binding_Type :: enum i32 {
    // Indicates that this `Buffer_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // A buffer for uniform values.
    Uniform,
    // A storage buffer.
    Storage,
    // A storage buffer that can only be read in the shader.
    Read_Only_Storage,
}

// A buffer binding.
//
// Corresponds to [WebGPU `GPUBufferBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpubufferbindinglayout).
Buffer_Binding_Layout :: struct {
    // Sub-type of the buffer binding.
    //
    // Must be `.Uniform`, `.Storage` or `.Read_Only_Storage`.
    type:               Buffer_Binding_Type,
    // Indicates that the binding has a dynamic offset.
    //
    // One offset must be passed to `render_pass_set_bind_group`,
    // `compute_pass_set_bind_group` or `render_bundle_encoder_set_bind_group`
    // for each dynamic binding in increasing order of binding number.
    has_dynamic_offset: bool,
    // The minimum size for a `Buffer_Binding` matching this entry, in bytes.
    //
    // If this is not `0`:
    //
    // - When calling `device_create_bind_group`, the resource at this bind
    //   point must be a `Buffer_Binding` whose effective size is at least
    //   `size`.
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

// Specific type of a sampler binding.
//
// For use in `Binding_Type.Sampler`.
//
// Corresponds to [WebGPU `GPUSamplerBindingType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpusamplerbindingtype).
Sampler_Binding_Type :: enum i32 {
    // Indicates that this `Sampler_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // The sampling result is produced based on more than a single color sample
    // from a texture, e.g. when bilinear interpolation is enabled.
    Filtering,
    // The sampling result is produced based on a single color sample from a texture.
    Non_Filtering,
    // Use as a comparison sampler instead of a normal sampler. For more info
    // take a look at the analogous functionality in OpenGL:
    //
    // https://www.khronos.org/opengl/wiki/Sampler_Object#Comparison_mode.
    Comparison,
}

// A sampler that can be used to sample a texture.
//
// Corresponds to [WebGPU `GPUSamplerBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpusamplerbindinglayout).
Sampler_Binding_Layout :: struct {
    // Specific type of a sampler binding.
    //
    // `.Undefined` accepts any non-comparison sampler. `.Non_Filtering`
    // requires a sampler without linear filtering.
    type: Sampler_Binding_Type,
}

// Specific type of a sample in a texture binding.
//
// Corresponds to [WebGPU `GPUTextureSampleType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gputexturesampletype).
Texture_Sample_Type :: enum i32 {
    // Indicates that this `Texture_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // Sampling returns floating-point values. Compatible with filtering samplers.
    Float,
    // Sampling returns floating-point values, but the texture cannot be sampled
    // with a filtering sampler.
    Unfilterable_Float,
    // Sampling does the depth reference comparison.
    //
    // This is also compatible with a non-filtering sampler.
    Depth,
    // Sampling returns signed integers.
    Sint,
    // Sampling returns unsigned integers.
    Uint,
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
    // True if the texture has a sample count greater than 1.
    //
    // If this is true, the texture must be declared as
    // `texture_multisampled_2d` or `texture_depth_multisampled_2d` in the
    // shader and read with `textureLoad`.
    multisampled:   bool,
}

// Specific type of a sample in a texture binding.
//
// For use in `Binding_Type.Storage_Texture`.
//
// Corresponds to [WebGPU `GPUStorageTextureAccess`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpustoragetextureaccess).
Storage_Texture_Access :: enum i32 {
    // Indicates that this `Storage_Texture_Binding_Layout` member of its
    // parent `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // The texture can only be written in the shader.
    Write_Only,
    // The texture can only be read in the shader.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to
    // use this access mode. This is a native-only extension.
    Read_Only,
    // The texture can be both read and written in the shader.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to use
    // this access mode.  This is a nonstandard, native-only extension.
    Read_Write,
    // The texture can be both read and written in the shader via atomics.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to
    // use this access mode.  This is a nonstandard, native-only extension.
    Atomic,
}

// A storage texture.
//
// The shader must declare the same format and access on the storage texture
// global. In WGSL the format must be one of the storage texel formats.
//
// Corresponds to [WebGPU `GPUStorageTextureBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpustoragetexturebindinglayout).
Storage_Texture_Binding_Layout :: struct {
    // Allowed access to this texture.
    //
    // `.Undefined` behaves as `.Write_Only`. `.Read_Only`, `.Read_Write` and
    // `.Atomic` require the `Texture_Adapter_Specific_Format_Features` feature.
    // The Vulkan backend does not support `.Read_Write` or `.Atomic`.
    access:         Storage_Texture_Access,
    // Format of the texture.
    //
    // `.Undefined` behaves as `.RGBA8_Unorm`. The format must support
    // `Storage_Binding` with the requested `access`.
    format:         Texture_Format,
    // Dimension of the texture view used by the binding.
    //
    // Cube and cube-array views cannot be storage textures.
    view_dimension: Texture_View_Dimension,
}

// An external texture binding.
//
// Corresponds to [WebGPU `GPUExternalTextureBindingLayout`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuexternaltexturebindinglayout).
//
// Requires the `External_Texture` feature. External texture bindings cannot be
// arrays, and the Vulkan backend does not support them.
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
    // Binding index. Must match the shader's binding index and be unique inside
    // a `Bind_Group_Layout`. A binding index of 1 is written as
    // `@group(0) @binding(1)` in the shader.
    binding:    u32,
    // Which shader stages can see this binding.
    visibility: Shader_Stages,
    // The type of the binding.
    type:       Binding_Type,
    // If the binding is an array of multiple resources. Corresponds to
    // `binding_array<T>` in the shader.
    //
    // `0` means the binding is not an array. A non-zero `count` requires the
    // matching device feature:
    //
    // - `Texture_Binding_Layout` and `Sampler_Binding_Layout`:
    //   `Texture_Binding_Array`.
    // - `Buffer_Binding_Layout`: `Buffer_Binding_Array`.
    // - `Buffer_Binding_Layout` with `.Storage` or `.Read_Only_Storage`:
    //   `Buffer_Binding_Array` and `Storage_Resource_Binding_Array`.
    // - `Storage_Texture_Binding_Layout`: `Texture_Binding_Array` and
    //   `Storage_Resource_Binding_Array`.
    // - `External_Texture_Binding_Layout`: arrays are not supported.
    //
    // A bind group must provide exactly `count` resources for the binding. When
    // `Partially_Bound_Binding_Array` is enabled, `count` is an upper bound
    // instead, and the bind group may provide between 1 and `count` resources.
    //
    // When any binding in the layout is an array, no `Buffer_Binding_Layout` in
    // the same layout may set `has_dynamic_offset`, and none may use
    // `Buffer_Binding_Type.Uniform`.
    //
    // Array elements count towards
    // `Limits.max_binding_array_elements_per_shader_stage` (all types except
    // samplers) and
    // `Limits.max_binding_array_sampler_elements_per_shader_stage` (samplers).
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

// Creates a `Bind_Group_Layout` from `descriptor`.
device_create_bind_group_layout: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout

// Returns the `Bind_Group_Layout`'s debug label.
//
// The string is owned by the `Bind_Group_Layout` and stays valid until the next
// `bind_group_layout_set_label()` or until the `Bind_Group_Layout` is released.
bind_group_layout_get_label: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string

// Sets the `Bind_Group_Layout`'s debug label.
//
// The `Bind_Group_Layout` keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
bind_group_layout_set_label: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
)

// Increments the reference count of `bind_group_layout`.
bind_group_layout_add_ref: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location)

// Releases `bind_group_layout`, destroying it when its reference count reaches zero.
bind_group_layout_release: proc(bind_group_layout: Bind_Group_Layout, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Bind_Group_Layout_Impl :: struct {
    device:  Device,
    entries: map[u32]Bind_Group_Layout_Entry,
}

// Returns the concrete implementation behind a `Bind_Group_Layout` handle.
_bind_group_layout_get_impl: proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^_Bind_Group_Layout_Impl
