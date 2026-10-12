package gpu

// Handle to a pipeline layout.
//
// A `Pipeline_Layout` object describes the available binding groups of a
// pipeline. It can be created with `device_create_pipeline_layout`.
//
// Corresponds to [WebGPU
// `GPUPipelineLayout`](https://gpuweb.github.io/gpuweb/#gpupipelinelayout).
Pipeline_Layout :: distinct Handle

// Describes a `Pipeline_Layout`.
//
// For use with `device_create_pipeline_layout`.
//
// Corresponds to [WebGPU `GPUPipelineLayoutDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpupipelinelayoutdescriptor).
Pipeline_Layout_Descriptor :: struct {
    // Debug label of the pipeline layout. This will show up in graphics
    // debuggers for easy identification.
    label:              string,
    // Bind groups that this pipeline uses. The first entry will provide all the
    // bindings for "set = 0", second entry will provide all the bindings for
    // "set = 1" etc.
    bind_group_layouts: []Bind_Group_Layout,
    // The number of bytes of immediate data that are allocated for use in the
    // shader. The `var<immediate>`s in the shader attached to this pipeline
    // must be equal or smaller than this size.
    //
    // If this value is non-zero, `Immediates` must be enabled.
    immediate_size:     u32,
}

// Advanced options for use when a pipeline is compiled
//
// This implements `Default`, and for most users can be set to `Default::default()`
Pipeline_Compilation_Options :: struct {
    // Specifies the values of pipeline-overridable constants in the shader module.
    //
    // If an `@id` attribute was specified on the declaration,
    // the key must be the pipeline constant ID as a decimal ASCII number; if not,
    // the key must be the constant's identifier name.
    //
    // If the given constant is specified more than once, the last value specified is used.
    //
    // The value may represent any of shader's concrete scalar types.
    constants:                        []Constant_Entry,
    // Whether workgroup scoped memory will be initialized with zero values for this stage.
    //
    // This is required by the WebGPU spec, but may have overhead which can be avoided
    // for cross-platform applications
    zero_initialize_workgroup_memory: bool,
}

// A key-value pair used to override a pipeline-overridable constant in a shader.
//
// Corresponds to [`GPUConstantEntry`](https://www.w3.org/TR/webgpu/#dictdef-gpuconstantentry)
// (the entry type of the `constants` dictionary).
Constant_Entry :: struct {
    // Name of the pipeline-overridable constant as declared in the shader
    // (the identifier after `@id` or the explicit override name).
    key:   string,
    // Value to assign to the constant. Will be converted to the constant's
    // type in the shader (bool, i32, u32, f32, or f16).
    value: f64,
}

device_create_pipeline_layout: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout

pipeline_layout_set_label: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
)

pipeline_layout_add_ref: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location)

pipeline_layout_release: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location)
