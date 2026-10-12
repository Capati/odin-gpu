package gpu

// Handle to a compute pipeline.
//
// A `Compute_Pipeline` object represents a compute pipeline and its single
// shader stage. It can be created with `device_create_compute_pipeline`.
//
// Corresponds to [WebGPU
// `GPUComputePipeline`](https://gpuweb.github.io/gpuweb/#compute-pipeline).
Compute_Pipeline :: distinct rawptr

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

device_create_compute_pipeline: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline

device_create_compute_pipeline_async: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future

compute_pipeline_get_bind_group_layout: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout

compute_pipeline_set_label: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
)

compute_pipeline_add_ref: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location)

compute_pipeline_release: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location)
