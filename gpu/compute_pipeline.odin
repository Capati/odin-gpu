package gpu

// Handle to a compute pipeline.
//
// A `Compute_Pipeline` object represents a compute pipeline and its single
// shader stage. It can be created with `device_create_compute_pipeline`.
//
// Corresponds to [WebGPU
// `GPUComputePipeline`](https://gpuweb.github.io/gpuweb/#compute-pipeline).
Compute_Pipeline :: distinct Handle

// Describes a compute pipeline.
//
// For use with `device_create_compute_pipeline`.
//
// Corresponds to [WebGPU `GPUComputePipelineDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpucomputepipelinedescriptor).
Compute_Pipeline_Descriptor :: struct {
    // Debug label of the pipeline.
    label:               string,
    // The layout of bind groups for this pipeline.
    //
    // An empty handle requests a default layout inferred from the shader.
    layout:              Pipeline_Layout,
    // The compiled shader module for this stage.
    module:              Shader_Module,
    // The name of the entry point in the compiled shader to use.
    //
    // If given, there must be a compute shader entry point with this name in
    // `module`. Otherwise, expect exactly one compute shader entry point in
    // `module`, which will be selected.
    entry_point:         string,
    // Advanced options for when this pipeline is compiled
    compilation_options: Pipeline_Compilation_Options,
    // The pipeline cache to use when creating this pipeline.
    cache:               Pipeline_Cache,
}

// Creates a compute pipeline.
//
// An empty `layout` requests a default layout inferred from the shader. Invalid
// descriptors are reported through the device's validation path and return `{}`.
device_create_compute_pipeline: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline

// Creates a compute pipeline asynchronously.
//
// The returned `Future` resolves when compilation finishes; `callback_info`
// receives the resulting pipeline and status.
device_create_compute_pipeline_async: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future

// Returns the pipeline's bind group layout at `group_index`.
//
// Groups created from this layout are only usable with this pipeline when it
// uses a default layout. An out-of-range index is reported as a validation
// error and returns `{}`.
compute_pipeline_get_bind_group_layout: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

// Returns the `Compute_Pipeline`'s debug label.
//
// The string is owned by the `Compute_Pipeline` and stays valid until the next
// `compute_pipeline_set_label()` or until the `Compute_Pipeline` is released.
compute_pipeline_get_label: proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> string

// Sets the `Compute_Pipeline`'s debug label.
//
// The `Compute_Pipeline` keeps its own copy of `label`, so the caller may
// release its copy immediately after this call.
compute_pipeline_set_label: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
)

// Increments the compute pipeline's reference count.
compute_pipeline_add_ref: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location)

// Decrements the compute pipeline's reference count, destroying it when it
// reaches zero.
compute_pipeline_release: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Compute_Pipeline_Impl :: struct {
    device:          Device,
    layout:          Pipeline_Layout,
    ref:             Ref_Count_Type,
    is_empty_layout: bool,
}

_compute_pipeline_get_internal_impl: proc "contextless" (
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> ^_Compute_Pipeline_Impl
