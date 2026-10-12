#+build !js
package gpu

// Core
import "core:slice"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Pipeline_Layout_Handle :: distinct hm.Handle64

VK_Pipeline_Layout_Impl :: struct {
    device:             Device,
    raw:                vk.PipelineLayout,
    bind_group_layouts: []Bind_Group_Layout,
    handle:             VK_Pipeline_Layout_Handle,
    ref:                Ref_Count_Type,
}

@(require_results)
vk_pipeline_layout_get_impl :: #force_inline proc "contextless" (
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> ^VK_Pipeline_Layout_Impl {
    device_impl := vk_device_get_impl(pipeline_layout.device, loc)
    return get_handle_impl(&device_impl.pipeline_layouts, pipeline_layout.handle, loc)
}

vk_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    impl := vk_device_get_impl(device, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vk_set_layouts := make([]vk.DescriptorSetLayout, len(descriptor.bind_group_layouts), ta)
    for bgl, i in descriptor.bind_group_layouts {
        bgl_impl := vk_bind_group_layout_get_impl(bgl, loc)
        vk_set_layouts[i] = bgl_impl.raw
        bind_group_layout_add_ref(bgl)
    }

    push_constant_ranges: []vk.PushConstantRange
    push_constant_range: vk.PushConstantRange
    if descriptor.immediate_size != 0 {
        push_constant_range = vk.PushConstantRange{
            stageFlags = vk.ShaderStageFlags_ALL,
            offset     = 0,
            size       = descriptor.immediate_size,
        }
        push_constant_ranges = slice.from_ptr(&push_constant_range, 1)
    }

    vk_info := vk.PipelineLayoutCreateInfo{
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        flags                  = {},
        setLayoutCount         = u32(len(vk_set_layouts)),
        pSetLayouts            = raw_data(vk_set_layouts),
        pushConstantRangeCount = u32(len(push_constant_ranges)),
        pPushConstantRanges    = raw_data(push_constant_ranges),
    }

    vk_layout: vk.PipelineLayout
    vk_check(impl.fp.CreatePipelineLayout(impl.vk_device, &vk_info, nil, &vk_layout))

    bind_group_layouts :=
        make([]Bind_Group_Layout, len(descriptor.bind_group_layouts), impl.allocator)
    copy(bind_group_layouts, descriptor.bind_group_layouts)

    _, pl_handle := add_impl(&impl.pipeline_layouts, VK_Pipeline_Layout_Impl{
        device              = device,
        raw                 = vk_layout,
        bind_group_layouts  = bind_group_layouts,
    })

    return new_handle(Pipeline_Layout, device, pl_handle)
}

vk_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    add_ref(impl, loc)
}

vk_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, impl.raw)
        for bgl in impl.bind_group_layouts {
            bind_group_layout_release(bgl, loc)
        }
        delete(impl.bind_group_layouts, device_impl.allocator)
        remove_handle_impl(&device_impl.pipeline_layouts, impl.handle)
    }
}
