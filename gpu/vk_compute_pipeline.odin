#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
// import vk "vendor:vulkan"

VK_Compute_Pipeline_Handle :: distinct hm.Handle64

VK_Compute_Pipeline_Impl :: struct {
    handle: VK_Compute_Pipeline_Handle,
    ref:    Ref_Count_Type,
}

vk_create_compute_pipeline :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline {
    unimplemented(loc = loc)
}

vk_create_compute_pipeline_async :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

vk_compute_pipeline_get_bind_group_layout :: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

vk_compute_pipeline_set_label :: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_compute_pipeline_add_ref :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_compute_pipeline_release :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}
