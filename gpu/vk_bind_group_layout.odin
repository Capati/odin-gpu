#+build !js
package gpu

// Core
import "core:slice"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Bind_Group_Layout_Handle :: distinct hm.Handle64

VK_Binding_Info :: struct {
    key:                u32,
    binding:            u32,
    binding_array_size: u32,
}

VK_Bind_Group_Layout_Impl :: struct {
    // Base
    using base: Bind_Group_Layout_Impl,

    // Backend
    raw:                     vk.DescriptorSetLayout,
    desc_count:              VK_Descriptor_Counts,
    binding_map:             []VK_Binding_Info,
    handle:                  VK_Bind_Group_Layout_Handle,
    ref:                     Ref_Count_Type,
    contains_binding_arrays: bool,
}

vk_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := vk_device_get_impl(device, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    vk_bindings := make([dynamic]vk.DescriptorSetLayoutBinding, ta)
    vk_binding_flags := make([dynamic]vk.DescriptorBindingFlags, ta)

    binding_map := make([dynamic]VK_Binding_Info, impl.allocator)

    next_binding: u32
    contains_binding_arrays: bool
    desc_count: VK_Descriptor_Counts

    for &entry in descriptor.entries {
        if entry.count != 0 {
            contains_binding_arrays = true
        }

        // partially_bound := .Partially_Bound in descriptor.flags  // see open question below
        flags: vk.DescriptorBindingFlags
        // if partially_bound && entry.count != 0 {
        //     flags += {.PARTIALLY_BOUND}
        // }
        if entry.count != 0 {
            flags += {.UPDATE_AFTER_BIND}
        }

        count := max(1, entry.count)

        append(&vk_bindings, vk.DescriptorSetLayoutBinding{
            binding            = next_binding,
            descriptorType     = vk_conv_to_descriptor_type(entry),
            descriptorCount    = count,
            stageFlags         = vk_conv_to_shader_stage_flags(entry.visibility),
            pImmutableSamplers = nil,
        })
        append(&vk_binding_flags, flags)
        append(&binding_map, VK_Binding_Info{
            key                = entry.binding,
            binding            = next_binding,
            binding_array_size = count,
        })
        next_binding += 1

        switch t in entry.type {
        case Buffer_Binding_Layout:
            #partial switch t.type {
            case .Uniform:
                if t.has_dynamic_offset {
                    desc_count.uniform_buffer_dynamic += count
                } else {
                    desc_count.uniform_buffer += count
                }
            case .Storage, .Read_Only_Storage:
                if t.has_dynamic_offset {
                    desc_count.storage_buffer_dynamic += count
                } else {
                    desc_count.storage_buffer += count
                }
            case .Undefined:
                panic("Invalid buffer binding layout", loc)
            }
        case Sampler_Binding_Layout:
            desc_count.sampler += count
        case Texture_Binding_Layout:
            desc_count.sampled_image += count
        case Storage_Texture_Binding_Layout:
            desc_count.storage_image += count
        case External_Texture_Binding_Layout:
            panic("External texture bindings not yet supported", loc)
        case:
            panic("Invalid bind group layout entry", loc)
        }
    }

    layout_flags: vk.DescriptorSetLayoutCreateFlags
    if contains_binding_arrays {
        layout_flags = {.UPDATE_AFTER_BIND_POOL}
    }

    binding_flag_info := vk.DescriptorSetLayoutBindingFlagsCreateInfo{
        sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
        bindingCount  = u32(len(vk_binding_flags)),
        pBindingFlags = raw_data(vk_binding_flags),
    }

    vk_info := vk.DescriptorSetLayoutCreateInfo{
        sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        pNext        = &binding_flag_info,
        flags        = layout_flags,
        bindingCount = u32(len(vk_bindings)),
        pBindings    = raw_data(vk_bindings),
    }

    vk_layout: vk.DescriptorSetLayout
    vk_check(impl.fp.CreateDescriptorSetLayout(impl.vk_device, &vk_info, nil, &vk_layout))

    bgl_impl, bgl_handle := add_impl(&impl.bind_group_layouts, VK_Bind_Group_Layout_Impl {
        base = {
            device  = device,
            entries = make(map[u32]Bind_Group_Layout_Entry, impl.allocator),
        },
        raw                     = vk_layout,
        desc_count              = desc_count,
        contains_binding_arrays = contains_binding_arrays,
        binding_map             = binding_map[:],
    })

    // Keyed by the binding number the application wrote, so the public layer can
    // resolve a `Bind_Group_Entry.binding` without knowing about the backend.
    for &entry in descriptor.entries {
        bgl_impl.base.entries[entry.binding] = entry
    }
    slice.sort_by(bgl_impl.binding_map[:], proc(a, b: VK_Binding_Info) -> bool {
        return a.key < b.key
    })

    // register with the descriptor allocator so alloc() can find its bucket
    vk_descriptor_allocator_register_layout(&impl.descriptor,
        VK_Descriptor_Layout_Info{
            raw                     = bgl_impl.raw,
            desc_count              = bgl_impl.desc_count,
            contains_binding_arrays = bgl_impl.contains_binding_arrays,
        })

    return new_handle(Bind_Group_Layout, device, bgl_handle)
}

@(require_results)
vk_bind_group_layout_get_impl :: #force_inline proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^VK_Bind_Group_Layout_Impl {
    device_impl := vk_device_get_impl(bind_group_layout.device, loc)
    return get_handle_impl(&device_impl.bind_group_layouts, bind_group_layout.handle, loc)
}

@(require_results)
vk_bind_group_layout_get_public_impl :: #force_inline proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^Bind_Group_Layout_Impl {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    return &impl.base
}

vk_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    add_ref(impl, loc)
}

vk_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)

        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
            VK_Deferred_Bind_Group_Layout{
                allocator = &device_impl.descriptor,
                layout = VK_Descriptor_Layout_Info{
                    raw                      = impl.raw,
                    desc_count               = impl.desc_count,
                    contains_binding_arrays  = impl.contains_binding_arrays,
                },
            },
        )

        delete(impl.base.entries)
        delete(impl.binding_map, device_impl.allocator)
        remove_handle_impl(&device_impl.bind_group_layouts, impl.handle)
    }
}
