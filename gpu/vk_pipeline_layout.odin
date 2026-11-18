#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:slice"

// Vendor
import vk "vendor:vulkan"

VK_Pipeline_Layout_Handle :: distinct hm.Handle64

VK_Pipeline_Layout_Impl :: struct {
    using base:              _Pipeline_Layout_Impl,
    raw:                     vk.PipelineLayout,
    bind_group_layouts:      [MAX_BIND_GROUPS]Bind_Group_Layout,
    bind_group_layout_count: u32,
    // Bitset of the set indexes whose child layout declares at least one entry.
    // A slot outside this mask never requires a bind group, so the per-draw
    // flush skips resolving its child layout.
    nonempty_slots_mask:     u32,
    // Resolved impls of `bind_group_layouts`, filled once at creation.
    bind_group_layout_impls: [MAX_BIND_GROUPS]^VK_Bind_Group_Layout_Impl,
    handle:                  VK_Pipeline_Layout_Handle,
    borrows:                 u32,
}

@(require_results)
vk_pipeline_layout_get_impl :: #force_inline proc "contextless" (
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> ^VK_Pipeline_Layout_Impl {
    device_impl := vk_device_get_impl(pipeline_layout.device, loc)
    return get_handle_impl(&device_impl.pipeline_layouts, pipeline_layout.handle, loc)
}

@(require_results)
vk_pipeline_layout_get_internal_impl :: proc "contextless" (
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> ^_Pipeline_Layout_Impl {
    return vk_pipeline_layout_get_impl(pipeline_layout, loc)
}

// Aggregate every layout's resource classes and dynamic-offset counts against
// the pipeline-wide limits. A null layout is legal and occupies its group slot.
@(require_results)
vk_pipeline_layout_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> bool {
    valid := true
    limits := _device_get_internal_impl(device, loc).limits
    valid &= gpu_validate(
        device,
        u32(len(descriptor.bind_group_layouts)) <= limits.max_bind_groups,
        "pipeline layout exceeds max_bind_groups",
        loc,
    )
    valid &= gpu_validate(
        device,
        descriptor.immediate_size % 4 == 0,
        "pipeline layout immediate size must be 4-byte aligned",
        loc,
    )
    valid &= gpu_validate(
        device,
        descriptor.immediate_size <= limits.max_immediate_size,
        "pipeline layout immediate size exceeds max_immediate_size",
        loc,
    )

    uniform_counts: [3]u32
    storage_counts: [3]u32
    sampled_counts: [3]u32
    sampler_counts: [3]u32
    storage_texture_counts: [3]u32
    dynamic_uniform: u32
    dynamic_storage: u32

    for bgl in descriptor.bind_group_layouts {
        if bgl == {} {
            continue
        }
        if !dhm_is_valid(
            &device_impl.bind_group_layouts,
            unpack_handle(VK_Bind_Group_Layout_Handle, bgl.handle),
        ) {
            gpu_report_validation_error(
                device,
                "pipeline layout names a non-live bind group layout",
                loc,
            )
            valid = false
            continue
        }
        layout_impl := vk_bind_group_layout_get_impl(bgl, loc)
        if intr.atomic_load_explicit(&layout_impl.ref, .Relaxed) == 0 {
            gpu_report_validation_error(
                device,
                "pipeline layout names a released bind group layout",
                loc,
            )
            valid = false
            continue
        }
        if layout_impl.device != device {
            gpu_report_validation_error(device, "bind group layout belongs to another device", loc)
            valid = false
            continue
        }
        for _, entry in layout_impl.entries {
            array_count := entry.count == 0 ? 1 : entry.count
            #partial switch t in entry.type {
            case Buffer_Binding_Layout:
                if t.has_dynamic_offset {
                    if t.type == .Uniform {
                        dynamic_uniform += array_count
                    } else {
                        dynamic_storage += array_count
                    }
                }
                for stage in 0 ..< 3 {
                    if vk_stage_visible(entry.visibility, stage) {
                        if t.type == .Uniform {
                            uniform_counts[stage] += array_count
                        } else {
                            storage_counts[stage] += array_count
                        }
                    }
                }
            case Texture_Binding_Layout:
                for stage in 0 ..< 3 {
                    if vk_stage_visible(entry.visibility, stage) {
                        sampled_counts[stage] += array_count
                    }
                }
            case Sampler_Binding_Layout:
                for stage in 0 ..< 3 {
                    if vk_stage_visible(entry.visibility, stage) {
                        sampler_counts[stage] += array_count
                    }
                }
            case Storage_Texture_Binding_Layout:
                for stage in 0 ..< 3 {
                    if vk_stage_visible(entry.visibility, stage) {
                        storage_texture_counts[stage] += array_count
                    }
                }
            case:
            }
        }
    }

    for stage in 0 ..< 3 {
        valid &= gpu_validate(
            device,
            uniform_counts[stage] <= limits.max_uniform_buffers_per_shader_stage,
            "pipeline layout has too many uniform buffers for a stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            storage_counts[stage] <= limits.max_storage_buffers_per_shader_stage,
            "pipeline layout has too many storage buffers for a stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            sampled_counts[stage] <= limits.max_sampled_textures_per_shader_stage,
            "pipeline layout has too many sampled textures for a stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            sampler_counts[stage] <= limits.max_samplers_per_shader_stage,
            "pipeline layout has too many samplers for a stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            storage_texture_counts[stage] <= limits.max_storage_textures_per_shader_stage,
            "pipeline layout has too many storage textures for a stage",
            loc,
        )
    }
    valid &= gpu_validate(
        device,
        dynamic_uniform <= limits.max_dynamic_uniform_buffers_per_pipeline_layout,
        "pipeline layout has too many dynamic uniform buffers",
        loc,
    )
    valid &= gpu_validate(
        device,
        dynamic_storage <= limits.max_dynamic_storage_buffers_per_pipeline_layout,
        "pipeline layout has too many dynamic storage buffers",
        loc,
    )

    return valid
}

@(require_results)
vk_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    impl := vk_device_get_impl(device, loc)

    if !vk_pipeline_layout_validate(device, impl, descriptor, loc) {
        return {}
    }

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vk_set_layouts := make([]vk.DescriptorSetLayout, len(descriptor.bind_group_layouts), ta)
    device_impl := vk_device_get_impl(device, loc)
    nonempty_slots_mask: u32
    for bgl, i in descriptor.bind_group_layouts {
        if bgl == {} {
            vk_set_layouts[i] = device_impl.vk_empty_descriptor_set_layout
            continue
        }
        bgl_impl := vk_bind_group_layout_get_impl(bgl, loc)
        vk_set_layouts[i] = bgl_impl.raw
        if len(bgl_impl.entries) > 0 && i < MAX_BIND_GROUPS {
            nonempty_slots_mask |= 1 << u32(i)
        }
        vk_bind_group_layout_borrow(bgl)
    }

    push_constant_ranges: []vk.PushConstantRange
    push_constant_range: vk.PushConstantRange
    if descriptor.immediate_size != 0 {
        push_constant_range = vk.PushConstantRange {
            stageFlags = vk.ShaderStageFlags_ALL,
            offset     = 0,
            size       = descriptor.immediate_size,
        }
        push_constant_ranges = slice.from_ptr(&push_constant_range, 1)
    }

    vk_info := vk.PipelineLayoutCreateInfo {
        sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
        flags                  = {},
        setLayoutCount         = u32(len(vk_set_layouts)),
        pSetLayouts            = raw_data(vk_set_layouts),
        pushConstantRangeCount = u32(len(push_constant_ranges)),
        pPushConstantRanges    = raw_data(push_constant_ranges),
    }

    vk_layout: vk.PipelineLayout
    if res := impl.fp.CreatePipelineLayout(impl.vk_device, &vk_info, nil, &vk_layout);
       res != .SUCCESS {
        vk_try(device, res, "vkCreatePipelineLayout", loc)
        return {}
    }

    layout_impl, pl_handle := add_impl(&impl.pipeline_layouts, VK_Pipeline_Layout_Impl {
        device                  = device,
        raw                     = vk_layout,
        bind_group_layout_count = u32(len(descriptor.bind_group_layouts)),
        nonempty_slots_mask     = nonempty_slots_mask,
    })
    copy(
        layout_impl.bind_group_layouts[:layout_impl.bind_group_layout_count],
        descriptor.bind_group_layouts,
    )

    // Resolve the child-layout impls once here: the creation loop above
    // already probed each non-null child for its descriptor set layout, and
    // the borrow keeps them alive for this layout's lifetime, so the per-draw
    // validation and flush paths never need to.
    for i in 0 ..< layout_impl.bind_group_layout_count {
        child := layout_impl.bind_group_layouts[i]
        if child != {} {
            layout_impl.bind_group_layout_impls[i] = vk_bind_group_layout_get_impl(child, loc)
        }
    }

    vk_label_set(&impl.labels, .Pipeline_Layout, pack_handle(pl_handle), descriptor.label)
    return new_handle(Pipeline_Layout, device, pl_handle)
}

vk_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Pipeline_Layout, pack_handle(impl.handle))
}

vk_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Pipeline_Layout, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .PIPELINE_LAYOUT, impl.raw, label, loc)
}

vk_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    add_ref(impl, loc)
}

vk_pipeline_layout_borrow :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    if pipeline_layout == {} {
        return
    }
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    impl.borrows += 1
}

vk_pipeline_layout_destroy_if_unused :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    if intr.atomic_load_explicit(&impl.ref, .Relaxed) > 0 || impl.borrows > 0 {
        return
    }
    device_impl := vk_device_get_impl(impl.device, loc)
    for bgl in impl.bind_group_layouts[:impl.bind_group_layout_count] {
        if bgl != {} {
            vk_bind_group_layout_drop_borrow(bgl, loc)
        }
    }
    vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, impl.raw)
    vk_label_remove(&device_impl.labels, .Pipeline_Layout, pack_handle(impl.handle))
    remove_handle_impl(&device_impl.pipeline_layouts, impl.handle)
}

vk_pipeline_layout_drop_borrow :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    if pipeline_layout == {} {
        return
    }
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    if impl.borrows > 0 {
        impl.borrows -= 1
    }
    vk_pipeline_layout_destroy_if_unused(pipeline_layout, loc)
}

vk_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := vk_pipeline_layout_get_impl(pipeline_layout, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_label_remove(&device_impl.labels, .Pipeline_Layout, pack_handle(impl.handle))
        vk_pipeline_layout_destroy_if_unused(pipeline_layout, loc)
    }
}
