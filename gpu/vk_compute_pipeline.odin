#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:strings"

// Vendor
import vk "vendor:vulkan"

VK_Compute_Pipeline_Handle :: distinct hm.Handle64

VK_Compute_Pipeline_Impl :: struct {
    using base:  _Compute_Pipeline_Impl,
    vk_pipeline: vk.Pipeline,
    handle:      VK_Compute_Pipeline_Handle,
}

@(require_results)
vk_create_compute_pipeline :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline {
    impl := vk_device_get_impl(device, loc)

    valid := true
    valid &= gpu_validate(
        device,
        descriptor.entry_point != "",
        "compute shader entry point is empty",
        loc,
    )

    if descriptor.module == {} ||
       !dhm_is_valid(
               &impl.shader_modules,
               unpack_handle(VK_Shader_Module_Handle, descriptor.module.handle),
           ) {
        gpu_report_validation_error(device, "compute pipeline shader module is not live", loc)
        valid = false
    } else if vk_shader_module_get_impl(descriptor.module, loc).device != device {
        gpu_report_validation_error(
            device,
            "compute pipeline shader module belongs to another device",
            loc,
        )
        valid = false
    }
    if descriptor.layout != {} {
        if !dhm_is_valid(
            &impl.pipeline_layouts,
            unpack_handle(VK_Pipeline_Layout_Handle, descriptor.layout.handle),
        ) {
            gpu_report_validation_error(device, "compute pipeline layout is not live", loc)
            valid = false
        } else {
            layout_impl := vk_pipeline_layout_get_impl(descriptor.layout, loc)
            if layout_impl.device != device {
                gpu_report_validation_error(
                    device,
                    "compute pipeline layout belongs to another device",
                    loc,
                )
                valid = false
            } else if intr.atomic_load_explicit(&layout_impl.ref, .Relaxed) == 0 {
                gpu_report_validation_error(
                    device,
                    "compute pipeline layout has been released",
                    loc,
                )
                valid = false
            }
        }
    }
    if !valid {
        return {}
    }

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    module_impl := vk_shader_module_get_impl(descriptor.module, loc)

    stage := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = {.COMPUTE},
        module = module_impl.vk_shader_module,
        pName  = strings.clone_to_cstring(descriptor.entry_point, ta),
    }

    vk_pipeline_layout: vk.PipelineLayout
    is_empty_layout: bool

    if descriptor.layout != {} {
        layout_impl := vk_pipeline_layout_get_impl(descriptor.layout, loc)
        vk_pipeline_layout = layout_impl.raw
        vk_pipeline_layout_borrow(descriptor.layout)
    } else {
        is_empty_layout = true
        vk_pipeline_layout = impl.vk_empty_pipeline_layout
    }

    create_info := vk.ComputePipelineCreateInfo {
        sType  = .COMPUTE_PIPELINE_CREATE_INFO,
        flags  = {},
        stage  = stage,
        layout = vk_pipeline_layout,
    }

    vk_pipeline: vk.Pipeline
    if res := vk.CreateComputePipelines(
        impl.vk_device,
        impl.pipeline_cache,
        1,
        &create_info,
        nil,
        &vk_pipeline,
    ); res != .SUCCESS {
        vk_try(device, res, "vkCreateComputePipelines", loc)
        return {}
    }

    _, compute_pipeline_handle := add_impl(&impl.compute_pipelines, VK_Compute_Pipeline_Impl {
        device          = device,
        layout          = descriptor.layout,
        vk_pipeline     = vk_pipeline,
        is_empty_layout = is_empty_layout,
    })

    vk_label_set(
        &impl.labels,
        .Compute_Pipeline,
        pack_handle(compute_pipeline_handle),
        descriptor.label,
    )

    return new_handle(Compute_Pipeline, device, compute_pipeline_handle)
}

@(require_results)
vk_create_compute_pipeline_async :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    pipeline := vk_create_compute_pipeline(device, descriptor, loc)

    if callback_info.callback != nil {
        status := pipeline == {} ? Create_Pipeline_Async_Status.Validation_Error : .Success
        callback_info.callback(
            status,
            pipeline,
            "",
            callback_info.userdata1,
            callback_info.userdata2,
        )
    } else if pipeline != {} {
        // No callback to hand the pipeline to; do not leak it.
        vk_compute_pipeline_release(pipeline, loc)
    }

    // Vulkan pipeline creation is synchronous here; the work is already done.
    return {}
}

@(require_results)
vk_compute_pipeline_get_impl :: #force_inline proc "contextless" (
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> ^VK_Compute_Pipeline_Impl {
    device_impl := vk_device_get_impl(compute_pipeline.device, loc)
    return get_handle_impl(&device_impl.compute_pipelines, compute_pipeline.handle, loc)
}

@(require_results)
vk_compute_pipeline_get_internal_impl :: #force_inline proc "contextless" (
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> ^_Compute_Pipeline_Impl {
    return vk_compute_pipeline_get_impl(compute_pipeline, loc)
}

@(require_results)
vk_compute_pipeline_get_bind_group_layout :: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := vk_compute_pipeline_get_impl(compute_pipeline, loc)
    if impl.layout == {} {
        return {}
    }

    layout_impl := vk_pipeline_layout_get_impl(impl.layout, loc)
    if group_index >= layout_impl.bind_group_layout_count {
        return {}
    }
    return layout_impl.bind_group_layouts[group_index]
}

vk_compute_pipeline_get_label :: proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> string {
    impl := vk_compute_pipeline_get_impl(compute_pipeline, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Compute_Pipeline, pack_handle(impl.handle))
}

vk_compute_pipeline_set_label :: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
) {
    impl := vk_compute_pipeline_get_impl(compute_pipeline, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Compute_Pipeline, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .PIPELINE, impl.vk_pipeline, label, loc)
}

vk_compute_pipeline_add_ref :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    impl := vk_compute_pipeline_get_impl(compute_pipeline, loc)
    add_ref(impl, loc)
}

vk_compute_pipeline_release :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    impl := vk_compute_pipeline_get_impl(compute_pipeline, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        if !impl.is_empty_layout {
            vk_pipeline_layout_drop_borrow(impl.layout)
        }
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, impl.vk_pipeline)
        vk_label_remove(&device_impl.labels, .Compute_Pipeline, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.compute_pipelines, impl.handle)
    }
}
