#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:slice"

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
    using base: _Bind_Group_Layout_Impl,

    raw:                     vk.DescriptorSetLayout,
    desc_count:              VK_Descriptor_Counts,
    binding_map:             []VK_Binding_Info,
    handle:                  VK_Bind_Group_Layout_Handle,
    ref:                     Ref_Count_Type,
    borrows:                 u32,
    contains_binding_arrays: bool,
}

// Index 0 = vertex, 1 = fragment, 2 = compute.
@(require_results)
vk_stage_visible :: proc "contextless" (visibility: Shader_Stages, stage: int) -> bool {
    switch stage {
    case 0:
        return .Vertex in visibility
    case 1:
        return .Fragment in visibility
    case 2:
        return .Compute in visibility
    }
    return false
}

@(require_results)
vk_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := vk_device_get_impl(device, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // A storage texture binding needs a format the device may use as a storage
    // image (which can be feature-gated, e.g. bgra8unorm). The layout also
    // enforces unique in-budget binding numbers, non-empty visibility and the
    // vertex-stage write restrictions.
    valid := true
    limits := _device_get_internal_impl(device, loc).limits
    entries := descriptor.entries
    for entry, index in descriptor.entries {
        normalized := entry
        #partial switch &t in normalized.type {
        case Texture_Binding_Layout:
            if t.view_dimension == .Undefined {
                t.view_dimension = .D2
                normalized.type = t
            }
        case Storage_Texture_Binding_Layout:
            if t.view_dimension == .Undefined {
                t.view_dimension = .D2
                normalized.type = t
            }
        }
        if normalized.type != entry.type {
            if raw_data(entries) == raw_data(descriptor.entries) {
                copied_entries := make([]Bind_Group_Layout_Entry, len(descriptor.entries), ta)
                copy(copied_entries, descriptor.entries)
                entries = copied_entries
            }
            entries[index] = normalized
        }
    }
    valid &= gpu_validate(
        device,
        u64(len(entries)) <= u64(limits.max_bindings_per_bind_group),
        "bind group layout has more entries than max_bindings_per_bind_group",
        loc,
    )
    has_binding_array: bool
    for entry in entries {
        if entry.count != 0 {
            has_binding_array = true
            break
        }
    }
    seen := make([dynamic]u32, 0, len(entries), ta)
    uniform_counts: [3]u32
    storage_counts: [3]u32
    sampled_counts: [3]u32
    sampler_counts: [3]u32
    storage_texture_counts: [3]u32
    array_elements: [3]u32
    array_sampler_elements: [3]u32
    dynamic_uniform: u32
    dynamic_storage: u32
    for entry in entries {
        array_count := entry.count == 0 ? 1 : entry.count
        for previous in seen {
            if previous == entry.binding {
                gpu_report_validation_error(
                    device,
                    "bind group layout declares a binding twice",
                    loc,
                )
                valid = false
            }
        }
        append(&seen, entry.binding)
        valid &= gpu_validate(
            device,
            entry.binding < limits.max_bindings_per_bind_group,
            "binding index exceeds max_bindings_per_bind_group",
            loc,
        )
        valid &= gpu_validate(
            device,
            entry.visibility != {},
            "bind group layout entry is not visible from any stage",
            loc,
        )

        #partial switch t in entry.type {
        case Storage_Texture_Binding_Layout:
            format := t.format
            if format == .Undefined {
                format = .RGBA8_Unorm
            }
            access := t.access
            if access == .Undefined {
                access = .Write_Only
            }
            features, ok := device_describe_format_features(device, format, loc)
            supported := ok && .Storage_Binding in features.allowed_usages
            #partial switch access {
            case .Read_Only:
                supported = supported && .Storage_Read_Only in features.flags
            case .Write_Only:
                supported = supported && .Storage_Write_Only in features.flags
            case .Read_Write:
                // Read-write storage needs the tier-2 format set, which this
                // backend does not expose.
                supported = false
            case:
                supported = false
            }
            valid &= gpu_validate(
                device,
                supported,
                "storage texture format/access is not supported by this device",
                loc,
            )
            valid &= gpu_validate(
                device,
                t.view_dimension != .Cube && t.view_dimension != .Cube_Array,
                "a cube view cannot be a storage texture",
                loc,
            )
            if .Vertex in entry.visibility && access != .Read_Only {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Vertex_Writable_Storage),
                    "a writable storage texture visible from the vertex stage requires Vertex_Writable_Storage",
                    loc,
                )
            }
            if entry.count != 0 {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Texture_Binding_Array),
                    "storage texture arrays require the Texture_Binding_Array feature",
                    loc,
                )
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Storage_Resource_Binding_Array),
                    "storage texture arrays require the Storage_Resource_Binding_Array feature",
                    loc,
                )
            }
            for stage in 0 ..< 3 {
                if vk_stage_visible(entry.visibility, stage) {
                    storage_texture_counts[stage] += array_count
                    if entry.count != 0 {
                        array_elements[stage] += array_count
                    }
                }
            }
        case Texture_Binding_Layout:
            if t.multisampled {
                valid &= gpu_validate(
                    device,
                    t.view_dimension == .D2,
                    "a multisampled texture binding must be 2D",
                    loc,
                )
                valid &= gpu_validate(
                    device,
                    t.sample_type != .Float,
                    "a multisampled texture binding cannot be filtered float",
                    loc,
                )
            }
            if entry.count != 0 {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Texture_Binding_Array),
                    "texture binding arrays require the Texture_Binding_Array feature",
                    loc,
                )
            }
            for stage in 0 ..< 3 {
                if vk_stage_visible(entry.visibility, stage) {
                    sampled_counts[stage] += array_count
                    if entry.count != 0 {
                        array_elements[stage] += array_count
                    }
                }
            }
        case Sampler_Binding_Layout:
            if entry.count != 0 {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Texture_Binding_Array),
                    "sampler binding arrays require the Texture_Binding_Array feature",
                    loc,
                )
            }
            for stage in 0 ..< 3 {
                if vk_stage_visible(entry.visibility, stage) {
                    sampler_counts[stage] += array_count
                    if entry.count != 0 {
                        array_sampler_elements[stage] += array_count
                    }
                }
            }
        case Buffer_Binding_Layout:
            valid &= gpu_validate(
                device,
                t.type != .Undefined && t.type != .Binding_Not_Used,
                "buffer binding layout must name a buffer type",
                loc,
            )
            if .Vertex in entry.visibility && t.type == .Storage {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Vertex_Writable_Storage),
                    "a writable storage buffer visible from the vertex stage requires Vertex_Writable_Storage",
                    loc,
                )
            }
            if entry.count != 0 {
                valid &= gpu_validate(
                    device,
                    device_has_feature(device, .Buffer_Binding_Array),
                    "buffer binding arrays require the Buffer_Binding_Array feature",
                    loc,
                )
                if t.type == .Storage || t.type == .Read_Only_Storage {
                    valid &= gpu_validate(
                        device,
                        device_has_feature(device, .Storage_Resource_Binding_Array),
                        "storage buffer arrays require the Storage_Resource_Binding_Array feature",
                        loc,
                    )
                }
            }
            if has_binding_array {
                valid &= gpu_validate(
                    device,
                    !t.has_dynamic_offset,
                    "a layout with a binding array cannot use dynamic offsets",
                    loc,
                )
                if entry.count == 0 {
                    // Non-array uniform buffers cannot share a layout with a
                    // binding array. Uniform buffer arrays are allowed.
                    valid &= gpu_validate(
                        device,
                        t.type != .Uniform,
                        "a layout with a binding array cannot use uniform buffers",
                        loc,
                    )
                }
            }
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
                    if entry.count != 0 {
                        array_elements[stage] += array_count
                    }
                }
            }
        case External_Texture_Binding_Layout:
            valid &= gpu_validate(
                device,
                entry.count == 0,
                "external texture bindings cannot be arrays",
                loc,
            )
            gpu_report_validation_error(
                device,
                "external texture bindings are not supported by the Vulkan backend",
                loc,
            )
            valid = false
        case:
            gpu_report_validation_error(device, "bind group layout entry has no binding type", loc)
            valid = false
        }
    }

    for stage in 0 ..< 3 {
        valid &= gpu_validate(
            device,
            array_elements[stage] <= limits.max_binding_array_elements_per_shader_stage,
            "too many binding array elements for a shader stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            array_sampler_elements[stage] <=
            limits.max_binding_array_sampler_elements_per_shader_stage,
            "too many sampler binding array elements for a shader stage",
            loc,
        )
    }

    for stage in 0 ..< 3 {
        valid &= gpu_validate(
            device,
            uniform_counts[stage] <= limits.max_uniform_buffers_per_shader_stage,
            "too many uniform buffers for a shader stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            storage_counts[stage] <= limits.max_storage_buffers_per_shader_stage,
            "too many storage buffers for a shader stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            sampled_counts[stage] <= limits.max_sampled_textures_per_shader_stage,
            "too many sampled textures for a shader stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            sampler_counts[stage] <= limits.max_samplers_per_shader_stage,
            "too many samplers for a shader stage",
            loc,
        )
        valid &= gpu_validate(
            device,
            storage_texture_counts[stage] <= limits.max_storage_textures_per_shader_stage,
            "too many storage textures for a shader stage",
            loc,
        )
    }
    valid &= gpu_validate(
        device,
        dynamic_uniform <= limits.max_dynamic_uniform_buffers_per_pipeline_layout,
        "too many dynamic uniform buffers",
        loc,
    )
    valid &= gpu_validate(
        device,
        dynamic_storage <= limits.max_dynamic_storage_buffers_per_pipeline_layout,
        "too many dynamic storage buffers",
        loc,
    )
    if !valid {
        return {}
    }

    vk_bindings := make([dynamic]vk.DescriptorSetLayoutBinding, ta)
    vk_binding_flags := make([dynamic]vk.DescriptorBindingFlags, ta)

    binding_map := make([dynamic]VK_Binding_Info, impl.allocator)

    next_binding: u32
    contains_binding_arrays: bool
    desc_count: VK_Descriptor_Counts

    for &entry in entries {
        if entry.count != 0 {
            contains_binding_arrays = true
        }

        flags: vk.DescriptorBindingFlags
        if entry.count != 0 {
            // Vulkan has no separate sampler update-after-bind feature:
            // standalone SAMPLER bindings are covered by
            // descriptorBindingSampledImageUpdateAfterBind (VUID 03006).
            // The adapter requires that feature and the device enables it.
            flags += {.UPDATE_AFTER_BIND}
            if device_has_feature(device, .Partially_Bound_Binding_Array) {
                flags += {.PARTIALLY_BOUND}
            }
        }

        count := max(1, entry.count)

        append(&vk_bindings, vk.DescriptorSetLayoutBinding {
            binding            = next_binding,
            descriptorType     = vk_conv_to_descriptor_type(entry),
            descriptorCount    = count,
            stageFlags         = vk_conv_to_shader_stage_flags(entry.visibility),
            pImmutableSamplers = nil,
        })
        append(&vk_binding_flags, flags)
        append(&binding_map, VK_Binding_Info {
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
            return {}
        case:
            panic("Invalid bind group layout entry", loc)
        }
    }

    layout_flags: vk.DescriptorSetLayoutCreateFlags
    if contains_binding_arrays {
        layout_flags = {.UPDATE_AFTER_BIND_POOL}
    }

    binding_flag_info := vk.DescriptorSetLayoutBindingFlagsCreateInfo {
        sType         = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
        bindingCount  = u32(len(vk_binding_flags)),
        pBindingFlags = raw_data(vk_binding_flags),
    }

    vk_info := vk.DescriptorSetLayoutCreateInfo {
        sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        pNext        = &binding_flag_info,
        flags        = layout_flags,
        bindingCount = u32(len(vk_bindings)),
        pBindings    = raw_data(vk_bindings),
    }

    vk_layout: vk.DescriptorSetLayout
    if res := impl.fp.CreateDescriptorSetLayout(impl.vk_device, &vk_info, nil, &vk_layout);
       res != .SUCCESS {
        vk_try(device, res, "vkCreateDescriptorSetLayout", loc)
        return {}
    }

    bgl_impl, bgl_handle := add_impl(&impl.bind_group_layouts, VK_Bind_Group_Layout_Impl {
        base = _Bind_Group_Layout_Impl {
            device  = device,
            entries = make(map[u32]Bind_Group_Layout_Entry, impl.allocator),
        },
        raw = vk_layout,
        desc_count = desc_count,
        contains_binding_arrays = contains_binding_arrays,
        binding_map = binding_map[:],
    })

    // Keyed by the binding number the application wrote, so the public layer can
    // resolve a `Bind_Group_Entry.binding` without knowing about the backend.
    for &entry in entries {
        bgl_impl.entries[entry.binding] = entry
    }
    slice.sort_by(bgl_impl.binding_map[:], proc(a, b: VK_Binding_Info) -> bool {
        return a.key < b.key
    })

    // register with the descriptor allocator so alloc() can find its bucket
    vk_descriptor_allocator_register_layout(&impl.descriptor, VK_Descriptor_Layout_Info {
        raw                     = bgl_impl.raw,
        desc_count              = bgl_impl.desc_count,
        contains_binding_arrays = bgl_impl.contains_binding_arrays,
    })

    vk_label_set(&impl.labels, .Bind_Group_Layout, pack_handle(bgl_handle), descriptor.label)
    return new_handle(Bind_Group_Layout, device, bgl_handle)
}

@(require_results)
vk_bind_group_layout_get_internal_impl :: #force_inline proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^_Bind_Group_Layout_Impl {
    return &vk_bind_group_layout_get_impl(bind_group_layout, loc).base
}

@(require_results)
vk_bind_group_layout_get_impl :: #force_inline proc "contextless" (
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> ^VK_Bind_Group_Layout_Impl {
    device_impl := vk_device_get_impl(bind_group_layout.device, loc)
    return get_handle_impl(&device_impl.bind_group_layouts, bind_group_layout.handle, loc)
}

vk_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Bind_Group_Layout, pack_handle(impl.handle))
}

vk_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Bind_Group_Layout, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .DESCRIPTOR_SET_LAYOUT, impl.raw, label, loc)
}

vk_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    add_ref(impl, loc)
}

// A bind group or pipeline layout names this layout without owning a public
// handle. A borrow keeps the Vulkan object alive but not a public handle.
vk_bind_group_layout_borrow :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    if bind_group_layout == {} {
        return
    }
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    impl.borrows += 1
}

vk_bind_group_layout_destroy_if_unused :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    if intr.atomic_load_explicit(&impl.ref, .Relaxed) > 0 || impl.borrows > 0 {
        return
    }
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_deferred_add_resource(
        &device_impl.deferred,
        &device_impl.submitter,
        VK_Deferred_Bind_Group_Layout {
            allocator = &device_impl.descriptor,
            layout = VK_Descriptor_Layout_Info {
                raw                     = impl.raw,
                desc_count              = impl.desc_count,
                contains_binding_arrays = impl.contains_binding_arrays,
            },
        },
    )
    delete(impl.entries)
    delete(impl.binding_map, device_impl.allocator)
    vk_label_remove(&device_impl.labels, .Bind_Group_Layout, pack_handle(impl.handle))
    remove_handle_impl(&device_impl.bind_group_layouts, impl.handle)
}

vk_bind_group_layout_drop_borrow :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    if bind_group_layout == {} {
        return
    }
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    if impl.borrows > 0 {
        impl.borrows -= 1
    }
    vk_bind_group_layout_destroy_if_unused(bind_group_layout, loc)
}

vk_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := vk_bind_group_layout_get_impl(bind_group_layout, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_label_remove(&device_impl.labels, .Bind_Group_Layout, pack_handle(impl.handle))
        vk_bind_group_layout_destroy_if_unused(bind_group_layout, loc)
    }
}
