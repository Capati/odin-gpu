#+build !js
package gpu

// Core
import intr "base:intrinsics"
import "base:runtime"
import hm "core:container/handle_map"
import "core:slice"

// Vendor
import vk "vendor:vulkan"

// A buffer slot in a resolved bind group: the segment to bind, and whether the
// binding declared it as storage.
Bind_Group_Impl_Buffer :: struct {
    binding:    Buffer_Binding,
    is_storage: bool,
}

// A texture view slot in a resolved bind group, and whether the binding declared
// it as storage.
Bind_Group_Impl_Texture_View :: struct {
    view:       Texture_View,
    is_storage: bool,
}

// One binding of a resolved bind group. `resource_index` is the offset of this
// binding's first resource in the flattened list named by `type`; there is one
// resource per descriptor, so a binding covers
// `[resource_index, resource_index + binding_array_size)`.
Bind_Group_Impl_Entry :: struct {
    binding:            u32,
    type:               Binding_Type,
    binding_array_size: u32,
    resource_index:     int,
}

VK_Buffer_Access :: struct {
    buffer:     Buffer,
    is_storage: bool,
}

VK_Texture_View_Access :: struct {
    texture_view: Texture_View,
    is_storage:   bool,
    // Resolved at bind-group creation (the loop already resolved it for the
    // descriptor write). The group holds a reference on the view, so the impl
    // outlives every use of this cache. Recording paths that only need the
    // view's parent texture, selector or aspect read this instead of probing
    // the handle map once per bind.
    view_impl:    ^VK_Texture_View_Impl,
}

VK_Dynamic_Binding :: struct {
    key:     u32,
    binding: Buffer_Binding,
    type:    Buffer_Binding_Type,
}

VK_Bind_Group_Handle :: distinct hm.Handle64

VK_Bind_Group_Impl :: struct {
    // Base
    using base: _Bind_Group_Impl,

    descriptor_set:       VK_Descriptor_Set,
    buffers:              []VK_Buffer_Access,
    samplers:             []Sampler,
    texture_views:        []VK_Texture_View_Access,
    // What this bind group requires to be initialized, resolved once at creation.
    buffer_init_actions:  []Buffer_Init_Action,
    texture_init_actions: []Texture_Init_Action,
    dynamic_bindings:     []VK_Dynamic_Binding,
    // Resolved impl of `base.layout`, cached at creation. The group borrows its
    // layout for its own lifetime and both are immutable afterwards, so the
    // draw-time equivalence check against the pipeline layout's children does
    // not need to re-probe the handle map per draw.
    layout_impl:          ^VK_Bind_Group_Layout_Impl,
    handle:               VK_Bind_Group_Handle,
}

// Resolves the ranges a bind group reads that may still be undefined. The actions
// are recorded when the group is bound and applied at submit, so a group that is
// created and never used costs nothing beyond these lists.
@(private = "file")
vk_collect_bind_group_init_actions :: proc(
    bind_buffers: []Bind_Group_Impl_Buffer,
    bind_texture_views: []Bind_Group_Impl_Texture_View,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> (
    buffer_actions: []Buffer_Init_Action,
    texture_actions: []Texture_Init_Action,
) {
    buffers := make([dynamic]Buffer_Init_Action, 0, len(bind_buffers), allocator)
    textures := make([dynamic]Texture_Init_Action, 0, len(bind_texture_views), allocator)

    for slot in bind_buffers {
        buffer_impl := vk_buffer_get_impl(slot.binding.buffer, loc)
        start := slot.binding.offset
        if start >= buffer_impl.size {
            continue
        }
        end := buffer_impl.size
        if slot.binding.size != WHOLE_SIZE {
            end = start + min(slot.binding.size, buffer_impl.size - start)
        }
        if start >= end {
            continue
        }
        append(&buffers, Buffer_Init_Action {
            buffer = slot.binding.buffer,
            range = {start = start, end = end},
            kind = .Needs_Initialized_Memory,
        })
    }

    for slot in bind_texture_views {
        view_impl := vk_texture_view_get_impl(slot.view, loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, loc)
        // A swapchain image is defined by the presentation engine; clearing it
        // would fight the frame the surface already produced.
        if texture_impl.is_swapchain {
            continue
        }
        selector := view_impl.selector
        append(&textures, Texture_Init_Action {
            texture = view_impl.texture,
            range = {
                mip_start   = selector.mip_start,
                mip_end     = selector.mip_start + selector.mip_count,
                layer_start = selector.layer_start,
                layer_end   = selector.layer_start + selector.layer_count,
            },
            kind = .Needs_Initialized_Memory,
            aspect = view_impl.aspect,
        })
    }

    return buffers[:], textures[:]
}

// Equivalent layouts define the same entries by binding, visibility and
// resource class. Handles may differ; the impl variant skips handle probes.
@(require_results)
@(private = "file")
vk_bind_group_layout_equivalent :: proc(a, b: Bind_Group_Layout, loc := #caller_location) -> bool {
    if a == {} || b == {} {
        return a == b
    }
    return vk_bind_group_layout_equivalent_impls(
        vk_bind_group_layout_get_impl(a, loc),
        vk_bind_group_layout_get_impl(b, loc),
    )
}

@(require_results)
@(private = "file")
vk_bind_group_layout_equivalent_impls :: proc(a_impl, b_impl: ^VK_Bind_Group_Layout_Impl) -> bool {
    // Layouts are immutable, and the common case is the exact object the
    // pipeline layout was built from; identity avoids the per-binding walk.
    // Distinct but structurally equal layouts still take it.
    if a_impl == b_impl {
        return true
    }
    if len(a_impl.entries) != len(b_impl.entries) {
        return false
    }
    for binding, a_entry in a_impl.entries {
        b_entry, found := b_impl.entries[binding]
        if !found || a_entry.visibility != b_entry.visibility {
            return false
        }
        #partial switch a_type in a_entry.type {
        case Buffer_Binding_Layout:
            b_type, ok := b_entry.type.(Buffer_Binding_Layout)
            if !ok || a_type != b_type {
                return false
            }
        case Sampler_Binding_Layout:
            b_type, ok := b_entry.type.(Sampler_Binding_Layout)
            if !ok || a_type != b_type {
                return false
            }
        case Texture_Binding_Layout:
            b_type, ok := b_entry.type.(Texture_Binding_Layout)
            if !ok || a_type != b_type {
                return false
            }
        case Storage_Texture_Binding_Layout:
            b_type, ok := b_entry.type.(Storage_Texture_Binding_Layout)
            if !ok || a_type != b_type {
                return false
            }
        case External_Texture_Binding_Layout:
            b_type, ok := b_entry.type.(External_Texture_Binding_Layout)
            if !ok || a_type != b_type {
                return false
            }
        case:
            return false
        }
    }
    return true
}

// Validate the bound groups against the pipeline layout's child layouts. Empty
// child layouts impose nothing, and a bound group outside the layout is
// ignored. Child impls are cached; `validated_layout` memoizes the (immutable)
// group/layout verdict and is reset when the slot's group changes.
@(require_results)
vk_pipeline_bind_groups_validate :: proc(
    device: Device,
    pipeline_layout: Pipeline_Layout,
    layout_impl: ^VK_Pipeline_Layout_Impl,
    slots: []VK_Bind_Group_Slot,
    loc := #caller_location,
) -> bool {
    if pipeline_layout == {} {
        return true
    }
    for child, index in layout_impl.bind_group_layouts[:layout_impl.bind_group_layout_count] {
        if child == {} {
            continue
        }
        if int(index) >= len(slots) {
            gpu_report_validation_error(
                device,
                "pipeline layout requires a bind group in this slot",
                loc,
            )
            return false
        }
        slot := &slots[index]
        if slot.validated_layout == pipeline_layout {
            continue
        }
        child_impl := layout_impl.bind_group_layout_impls[index]
        if len(child_impl.entries) == 0 {
            // An empty child layout imposes no requirement; memoize it too.
            slot.validated_layout = pipeline_layout
            continue
        }
        if !slot.assigned {
            gpu_report_validation_error(
                device,
                "pipeline layout requires a bind group in this slot",
                loc,
            )
            return false
        }
        group_impl := slot.group_impl
        if group_impl == nil {
            // Slots constructed without the cache (the bundle-encode walk
            // builds synthetic slots): resolve once here.
            group_impl = vk_bind_group_get_impl(slot.group, loc)
        }
        if !vk_bind_group_layout_equivalent_impls(group_impl.layout_impl, child_impl) {
            gpu_report_validation_error(
                device,
                "bound bind group is incompatible with the pipeline layout",
                loc,
            )
            return false
        }
        slot.validated_layout = pipeline_layout
    }
    return true
}

// Validates the bind, and hands back the resolved impl so the caller does not
// probe the handle map a second time: every recording path needs the impl
// immediately after this for the usage merge, the descriptor set and the init
// actions, and a probe costs a shared-lock acquisition plus a map lookup.
@(require_results)
vk_bind_group_offsets_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    group: Bind_Group,
    group_index: u32,
    offsets: []u32,
    loc := #caller_location,
) -> (
    group_impl: ^VK_Bind_Group_Impl,
    ok: bool,
) {
    limits := _device_get_internal_impl(device, loc).limits
    if group_index >= MAX_BIND_GROUPS || group_index >= limits.max_bind_groups {
        gpu_report_validation_error(device, "bind group index exceeds max_bind_groups", loc)
        return nil, false
    }
    if group == {} {
        if len(offsets) != 0 {
            gpu_report_validation_error(
                device,
                "a null bind group cannot have dynamic offsets",
                loc,
            )
            return nil, false
        }
        return nil, true
    }
    group_device := vk_device_get_impl(group.device, loc)
    group_impl = dhm_get_if_valid(
        &group_device.bind_groups,
        unpack_handle(VK_Bind_Group_Handle, group.handle),
    )
    if group_impl == nil {
        gpu_report_validation_error(device, "bind group is not a live bind group", loc)
        return nil, false
    }
    if group_impl.device != device {
        gpu_report_validation_error(device, "bind group belongs to another device", loc)
        return nil, false
    }
    if len(offsets) != len(group_impl.dynamic_bindings) {
        gpu_report_validation_error(
            device,
            "dynamic offset count does not match the bind group",
            loc,
        )
        return nil, false
    }
    // A bind group's resources cannot become live again once destroyed, and an
    // application only destroys resources after it stops using them, so the scan
    // below is pure repeated work while nothing has ever been destroyed. The
    // counter only increases, so a non-zero reading always takes the full path.
    if intr.atomic_load_explicit(&device_impl.destroyed_resources, .Relaxed) != 0 {
        for buffer_access in group_impl.buffers {
            if vk_buffer_get_impl(buffer_access.buffer, loc).destroyed {
                gpu_report_validation_error(
                    device,
                    "bind group references a destroyed buffer",
                    loc,
                )
                return nil, false
            }
        }
        for view_access in group_impl.texture_views {
            view_impl := vk_texture_view_get_impl(view_access.texture_view, loc)
            if vk_texture_get_impl(view_impl.texture, loc).destroyed {
                gpu_report_validation_error(
                    device,
                    "bind group references a destroyed texture",
                    loc,
                )
                return nil, false
            }
        }
    }
    for binding, i in group_impl.dynamic_bindings {
        buffer_impl := vk_buffer_get_impl(binding.binding.buffer, loc)
        alignment := u64(limits.min_uniform_buffer_offset_alignment)
        if binding.type != .Uniform {
            alignment = u64(limits.min_storage_buffer_offset_alignment)
        }
        if alignment > 0 && u64(offsets[i]) % alignment != 0 {
            gpu_report_validation_error(device, "dynamic offset is not aligned", loc)
            return nil, false
        }
        visible := buffer_impl.visible_size
        bound_size := visible - min(binding.binding.offset, visible)
        if binding.binding.size != WHOLE_SIZE {
            bound_size = binding.binding.size
        }
        end := u128(binding.binding.offset) + u128(offsets[i]) + u128(bound_size)
        if end > u128(visible) {
            gpu_report_validation_error(
                device,
                "dynamic offset pushes the binding past the buffer",
                loc,
            )
            return nil, false
        }
    }
    return group_impl, true
}

@(require_results)
@(private = "file")
vk_bind_group_validate_array_length :: proc(
    device: Device,
    count: u32,
    provided: int,
    is_array_resource: bool,
    loc := #caller_location,
) -> bool {
    if count == 0 {
        if is_array_resource {
            gpu_report_validation_error(
                device,
                "bind group entry kind does not match the layout",
                loc,
            )
            return false
        }
        return true
    }
    if provided == 0 {
        gpu_report_validation_error(
            device,
            "a binding array must provide at least one resource",
            loc,
        )
        return false
    }
    if provided > int(count) {
        gpu_report_validation_error(
            device,
            "binding array has more resources than the layout declares",
            loc,
        )
        return false
    }
    if provided != int(count) && !device_has_feature(device, .Partially_Bound_Binding_Array) {
        gpu_report_validation_error(device, "binding array size does not match the layout", loc)
        return false
    }
    return true
}

@(require_results)
@(private = "file")
vk_bind_group_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> bool {
    valid := true
    limits := _device_get_internal_impl(device, loc).limits

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    layout_impl: ^VK_Bind_Group_Layout_Impl
    if descriptor.layout != {} {
        layout_device := vk_device_get_impl(descriptor.layout.device, loc)
        layout_impl = dhm_get_if_valid(
            &layout_device.bind_group_layouts,
            unpack_handle(VK_Bind_Group_Layout_Handle, descriptor.layout.handle),
        )
    }
    if layout_impl == nil {
        gpu_report_validation_error(device, "bind group layout is not a live layout", loc)
        return false
    }
    if intr.atomic_load_explicit(&layout_impl.ref, .Relaxed) == 0 {
        gpu_report_validation_error(device, "bind group layout has been released", loc)
        return false
    }
    if layout_impl.device != device {
        gpu_report_validation_error(device, "bind group layout belongs to another device", loc)
        return false
    }
    if len(descriptor.entries) != len(layout_impl.entries) {
        gpu_report_validation_error(
            device,
            "bind group entry count does not match the layout",
            loc,
        )
        valid = false
    }

    features := device_get_features(device, loc)
    seen_bindings := make([dynamic]u32, 0, len(descriptor.entries), ta)

    for entry in descriptor.entries {
        for previous in seen_bindings {
            if previous == entry.binding {
                gpu_report_validation_error(device, "bind group entry names a binding twice", loc)
                valid = false
            }
        }
        append(&seen_bindings, entry.binding)

        layout_entry, found := layout_impl.entries[entry.binding]
        if !found {
            gpu_report_validation_error(
                device,
                "bind group entry names a binding the layout does not declare",
                loc,
            )
            valid = false
            continue
        }

        #partial switch resource in entry.resource {
        case Buffer_Binding, []Buffer_Binding:
            layout, is_buffer := layout_entry.type.(Buffer_Binding_Layout)
            if !is_buffer {
                gpu_report_validation_error(
                    device,
                    "bind group entry kind does not match the layout",
                    loc,
                )
                valid = false
                break
            }
            bindings: []Buffer_Binding
            is_array_resource: bool
            #partial switch v in resource {
            case Buffer_Binding:
                bindings = []Buffer_Binding{v}
            case []Buffer_Binding:
                bindings = v
                is_array_resource = true
            case:
            }
            if !vk_bind_group_validate_array_length(
                device,
                layout_entry.count,
                len(bindings),
                is_array_resource,
                loc,
            ) {
                valid = false
            }
            required_usage: Buffer_Usages
            #partial switch layout.type {
            case .Uniform:
                required_usage = {.Uniform}
            case .Storage, .Read_Only_Storage:
                required_usage = {.Storage}
            case .Undefined:
                gpu_report_validation_error(device, "invalid buffer binding layout", loc)
                valid = false
            }
            for binding in bindings {
                buffer_impl: ^VK_Buffer_Impl
                if binding.buffer != {} {
                    buffer_device := vk_device_get_impl(binding.buffer.device, loc)
                    buffer_impl = dhm_get_if_valid(
                        &buffer_device.buffers,
                        unpack_handle(VK_Buffer_Handle, binding.buffer.handle),
                    )
                }
                if buffer_impl == nil {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer is not a live buffer",
                        loc,
                    )
                    valid = false
                    continue
                }
                if buffer_impl.destroyed {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer has been destroyed",
                        loc,
                    )
                    valid = false
                    continue
                }
                if buffer_impl.device != device {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer belongs to another device",
                        loc,
                    )
                    valid = false
                    continue
                }
                if (buffer_impl.public_usage & required_usage) != required_usage {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer is missing the required usage",
                        loc,
                    )
                    valid = false
                }
                alignment := u64(limits.min_uniform_buffer_offset_alignment)
                if layout.type == .Storage || layout.type == .Read_Only_Storage {
                    alignment = u64(limits.min_storage_buffer_offset_alignment)
                }
                if alignment > 0 && binding.offset % alignment != 0 {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer offset is not aligned",
                        loc,
                    )
                    valid = false
                }
                visible := buffer_impl.visible_size
                if binding.offset > visible {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer offset is outside the buffer",
                        loc,
                    )
                    valid = false
                    continue
                }
                bound_size := visible - binding.offset
                if binding.size == 0 {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer size must not be zero",
                        loc,
                    )
                    valid = false
                } else if binding.size != WHOLE_SIZE {
                    if binding.size > bound_size {
                        gpu_report_validation_error(
                            device,
                            "bind group buffer range is outside the buffer",
                            loc,
                        )
                        valid = false
                        continue
                    }
                    bound_size = binding.size
                }
                if (layout.type == .Storage || layout.type == .Read_Only_Storage) &&
                   bound_size % u64(STORAGE_BINDING_SIZE_ALIGNMENT) != 0 {
                    gpu_report_validation_error(
                        device,
                        "storage buffer binding size must be a multiple of 4",
                        loc,
                    )
                    valid = false
                }
                if layout.min_binding_size != 0 && bound_size < layout.min_binding_size {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer range is under min_binding_size",
                        loc,
                    )
                    valid = false
                }
                max_binding_size := limits.max_storage_buffer_binding_size
                if layout.type == .Uniform {
                    max_binding_size = limits.max_uniform_buffer_binding_size
                }
                if max_binding_size != 0 && bound_size > max_binding_size {
                    gpu_report_validation_error(
                        device,
                        "bind group buffer range exceeds the binding-size limit",
                        loc,
                    )
                    valid = false
                }
            }

        case Sampler, []Sampler:
            layout, is_sampler := layout_entry.type.(Sampler_Binding_Layout)
            if !is_sampler {
                gpu_report_validation_error(
                    device,
                    "bind group entry kind does not match the layout",
                    loc,
                )
                valid = false
                break
            }
            samplers: []Sampler
            is_array_resource: bool
            #partial switch v in resource {
            case Sampler:
                samplers = []Sampler{v}
            case []Sampler:
                samplers = v
                is_array_resource = true
            case:
            }
            if !vk_bind_group_validate_array_length(
                device,
                layout_entry.count,
                len(samplers),
                is_array_resource,
                loc,
            ) {
                valid = false
            }
            for sampler in samplers {
                if sampler == {} {
                    gpu_report_validation_error(
                        device,
                        "bind group sampler is not a live sampler",
                        loc,
                    )
                    valid = false
                    continue
                }
                if sampler.device != device {
                    gpu_report_validation_error(
                        device,
                        "bind group sampler belongs to another device",
                        loc,
                    )
                    valid = false
                    continue
                }
                vk_sampler_impl := dhm_get_if_valid(
                    &device_impl.samplers,
                    unpack_handle(VK_Sampler_Handle, sampler.handle),
                )
                if vk_sampler_impl == nil {
                    gpu_report_validation_error(
                        device,
                        "bind group sampler is not a live sampler",
                        loc,
                    )
                    valid = false
                    continue
                }
                info := vk_sampler_impl.create_info
                comparison := info.compareEnable
                filtering :=
                    info.magFilter == .LINEAR ||
                    info.minFilter == .LINEAR ||
                    info.mipmapMode == .LINEAR
                #partial switch layout.type {
                case .Comparison:
                    if !comparison {
                        gpu_report_validation_error(
                            device,
                            "comparison sampler layout requires a comparison sampler",
                            loc,
                        )
                        valid = false
                    }
                case .Non_Filtering:
                    if comparison {
                        gpu_report_validation_error(
                            device,
                            "a non-filtering sampler layout cannot use a comparison sampler",
                            loc,
                        )
                        valid = false
                    } else if filtering {
                        gpu_report_validation_error(
                            device,
                            "a non-filtering sampler layout cannot use a filtering sampler",
                            loc,
                        )
                        valid = false
                    }
                case:
                    if comparison {
                        gpu_report_validation_error(
                            device,
                            "a sampler with comparison enabled requires a comparison layout",
                            loc,
                        )
                        valid = false
                    }
                }
            }

        case Texture_View, []Texture_View:
            views: []Texture_View
            is_array_resource: bool
            #partial switch v in resource {
            case Texture_View:
                views = []Texture_View{v}
            case []Texture_View:
                views = v
                is_array_resource = true
            case:
            }
            if !vk_bind_group_validate_array_length(
                device,
                layout_entry.count,
                len(views),
                is_array_resource,
                loc,
            ) {
                valid = false
            }
            for view in views {
                view_impl: ^VK_Texture_View_Impl
                if view != {} {
                    view_device := vk_device_get_impl(view.device, loc)
                    view_impl = dhm_get_if_valid(
                        &view_device.texture_views,
                        unpack_handle(VK_Texture_View_Handle, view.handle),
                    )
                }
                if view_impl == nil {
                    gpu_report_validation_error(
                        device,
                        "bind group texture view is not a live view",
                        loc,
                    )
                    valid = false
                    continue
                }
                texture_impl := vk_texture_get_impl(view_impl.texture, loc)
                if view_impl.device != device || texture_impl.base.device != device {
                    gpu_report_validation_error(
                        device,
                        "bind group texture belongs to another device",
                        loc,
                    )
                    valid = false
                    continue
                }
                if texture_impl.destroyed {
                    gpu_report_validation_error(
                        device,
                        "bind group texture has been destroyed",
                        loc,
                    )
                    valid = false
                    continue
                }
                aspects := texture_format_aspects_from(view_impl.format)
                if view_impl.aspect == .All && .Depth in aspects && .Stencil in aspects {
                    gpu_report_validation_error(
                        device,
                        "a combined depth-stencil aspect cannot be bound",
                        loc,
                    )
                    valid = false
                    continue
                }
                #partial switch layout in layout_entry.type {
                case Texture_Binding_Layout:
                    if .Texture_Binding not_in view_impl.public_usage {
                        gpu_report_validation_error(
                            device,
                            "texture view is missing the [Texture_Binding] usage",
                            loc,
                        )
                        valid = false
                    }
                    if .Texture_Binding not_in texture_impl.public_usage {
                        gpu_report_validation_error(
                            device,
                            "texture is missing the [Texture_Binding] usage",
                            loc,
                        )
                        valid = false
                    }
                    if view_impl.dimension != layout.view_dimension {
                        gpu_report_validation_error(
                            device,
                            "texture view dimension does not match the layout",
                            loc,
                        )
                        valid = false
                    }
                    if (texture_impl.sample_count > 1) != layout.multisampled {
                        gpu_report_validation_error(
                            device,
                            "texture multisampling does not match the layout",
                            loc,
                        )
                        valid = false
                    }
                    actual := texture_format_sample_type(
                        view_impl.format,
                        view_impl.aspect,
                        features[:],
                    )
                    sample_ok := false
                    #partial switch layout.sample_type {
                    case .Float:
                        sample_ok = actual == .Float
                    case .Unfilterable_Float:
                        sample_ok =
                            actual == .Float || actual == .Unfilterable_Float || actual == .Depth
                    case .Sint, .Uint, .Depth:
                        sample_ok = actual == layout.sample_type
                    case:
                        sample_ok = true
                    }
                    if !sample_ok {
                        gpu_report_validation_error(
                            device,
                            "texture sample type does not match the layout",
                            loc,
                        )
                        valid = false
                    }

                case Storage_Texture_Binding_Layout:
                    if .Storage_Binding not_in view_impl.public_usage {
                        gpu_report_validation_error(
                            device,
                            "texture view is missing the [Storage_Binding] usage",
                            loc,
                        )
                        valid = false
                    }
                    if .Storage_Binding not_in texture_impl.public_usage {
                        gpu_report_validation_error(
                            device,
                            "texture is missing the [Storage_Binding] usage",
                            loc,
                        )
                        valid = false
                    }
                    if view_impl.format != layout.format {
                        gpu_report_validation_error(
                            device,
                            "storage texture format does not match the layout",
                            loc,
                        )
                        valid = false
                    }
                    if view_impl.selector.mip_count != 1 {
                        gpu_report_validation_error(
                            device,
                            "storage texture binding must cover one mip level",
                            loc,
                        )
                        valid = false
                    }
                    if view_impl.swizzle != {} {
                        gpu_report_validation_error(
                            device,
                            "storage texture binding cannot use a component swizzle",
                            loc,
                        )
                        valid = false
                    }
                    if view_impl.dimension != layout.view_dimension {
                        gpu_report_validation_error(
                            device,
                            "storage texture dimension does not match the layout",
                            loc,
                        )
                        valid = false
                    }

                case:
                    gpu_report_validation_error(
                        device,
                        "bind group entry kind does not match the layout",
                        loc,
                    )
                    valid = false
                }
            }

        case:
            gpu_report_validation_error(device, "bind group entry has no resource", loc)
            valid = false
        }
    }

    for binding, _ in layout_impl.entries {
        if !slice.contains(seen_bindings[:], binding) {
            gpu_report_validation_error(
                device,
                "bind group does not provide an entry for every layout binding",
                loc,
            )
            valid = false
        }
    }

    return valid
}

// Resolves a bind group descriptor into the flattened resource lists the
// backend consumes. Every binding is validated against its layout entry, the
// internal tracker usage of each resource is derived, and the lists are built
// in descriptor order.
@(require_results)
vk_resolve_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> (
    entries: []Bind_Group_Impl_Entry,
    buffers: []Bind_Group_Impl_Buffer,
    samplers: []Sampler,
    texture_views: []Bind_Group_Impl_Texture_View,
    used: Bind_Group_States,
) {
    assert(device != {}, "Invalid device", loc)
    assert(descriptor.layout != {}, "Invalid bind group layout", loc)

    device_impl := vk_device_get_impl(device, loc)
    layout_impl := vk_bind_group_layout_get_impl(descriptor.layout, loc)
    partially_bound := device_has_feature(device, .Partially_Bound_Binding_Array)

    assert(len(descriptor.entries) == len(layout_impl.entries), "Bindings number mismatch", loc)

    ta := default_temp_allocator()

    // Capacity hint only: every binding contributes at most one of each kind.
    entry_capacity := len(descriptor.entries)

    // Ownership of `used` passes to the bind group. The flattened resource
    // lists are only read by the backend, so they are freed here.
    entry_list := make([dynamic]Bind_Group_Impl_Entry, 0, entry_capacity, ta)
    buffer_list := make([dynamic]Bind_Group_Impl_Buffer, 0, entry_capacity, ta)
    sampler_list := make([dynamic]Sampler, 0, entry_capacity, ta)
    texture_view_list := make([dynamic]Bind_Group_Impl_Texture_View, 0, entry_capacity, ta)

    bind_group_states_init(&used, device_impl.allocator)

    for entry in descriptor.entries {
        layout_entry, declared := layout_impl.entries[entry.binding]
        assert(declared, "Bind group entry has no matching layout entry", loc)

        resolved := Bind_Group_Impl_Entry {
            binding            = entry.binding,
            type               = layout_entry.type,
            binding_array_size = max(1, layout_entry.count),
        }
        expected_count := int(resolved.binding_array_size)

        switch r in entry.resource {
        case Buffer_Binding:
            assert(r.buffer != {}, "invalid buffer", loc)
            assert(
                expected_count == 1 || partially_bound,
                "buffer binding expects a single resource",
                loc,
            )
            resolved.binding_array_size = 1
            uses, is_storage := bind_group_buffer_internal_use(layout_entry, loc)
            resolved.resource_index = len(buffer_list)
            append(&buffer_list, Bind_Group_Impl_Buffer{binding = r, is_storage = is_storage})
            buffer_bind_group_state_insert_single(
                &used.buffers,
                _buffer_tracker_index(r.buffer),
                r.buffer,
                uses,
            )

        case []Buffer_Binding:
            assert(len(r) > 0, "buffer binding array must not be empty", loc)
            assert(len(r) <= expected_count, "buffer binding array is too long", loc)
            assert(
                partially_bound || len(r) == expected_count,
                "buffer binding array size does not match layout",
                loc,
            )
            resolved.binding_array_size = u32(len(r))
            uses, is_storage := bind_group_buffer_internal_use(layout_entry, loc)
            resolved.resource_index = len(buffer_list)
            for bb in r {
                assert(bb.buffer != {}, "invalid buffer", loc)
                append(&buffer_list, Bind_Group_Impl_Buffer{binding = bb, is_storage = is_storage})
                buffer_bind_group_state_insert_single(
                    &used.buffers,
                    _buffer_tracker_index(bb.buffer),
                    bb.buffer,
                    uses,
                )
            }

        case Sampler:
            assert(r != {}, "invalid sampler", loc)
            assert(
                expected_count == 1 || partially_bound,
                "sampler binding expects a single resource",
                loc,
            )
            resolved.binding_array_size = 1
            resolved.resource_index = len(sampler_list)
            append(&sampler_list, r)

        case []Sampler:
            assert(len(r) > 0, "sampler binding array must not be empty", loc)
            assert(len(r) <= expected_count, "sampler binding array is too long", loc)
            assert(
                partially_bound || len(r) == expected_count,
                "sampler binding array size does not match layout",
                loc,
            )
            resolved.binding_array_size = u32(len(r))
            resolved.resource_index = len(sampler_list)
            for smp in r {
                assert(smp != {}, "invalid sampler", loc)
                append(&sampler_list, smp)
            }

        case Texture_View:
            assert(r != {}, "invalid texture view", loc)
            assert(
                expected_count == 1 || partially_bound,
                "texture view binding expects a single resource",
                loc,
            )
            resolved.binding_array_size = 1
            uses, is_storage := bind_group_view_internal_use(layout_entry, loc)
            resolved.resource_index = len(texture_view_list)
            append(
                &texture_view_list,
                Bind_Group_Impl_Texture_View{view = r, is_storage = is_storage},
            )
            view_impl := vk_texture_view_get_impl(r, loc)
            texture_view_bind_group_state_insert_single(
                &used.views,
                r,
                vk_tracked_texture(view_impl.texture, vk_texture_get_impl(view_impl.texture, loc)),
                view_impl.selector,
                uses,
            )

        case []Texture_View:
            assert(len(r) > 0, "texture view binding array must not be empty", loc)
            assert(len(r) <= expected_count, "texture view binding array is too long", loc)
            assert(
                partially_bound || len(r) == expected_count,
                "texture view binding array size does not match layout",
                loc,
            )
            resolved.binding_array_size = u32(len(r))
            uses, is_storage := bind_group_view_internal_use(layout_entry, loc)
            resolved.resource_index = len(texture_view_list)
            for tv in r {
                assert(tv != {}, "invalid texture view", loc)
                append(
                    &texture_view_list,
                    Bind_Group_Impl_Texture_View{view = tv, is_storage = is_storage},
                )
                view_impl := vk_texture_view_get_impl(tv, loc)
                texture_view_bind_group_state_insert_single(
                    &used.views,
                    tv,
                    vk_tracked_texture(
                        view_impl.texture,
                        vk_texture_get_impl(view_impl.texture, loc),
                    ),
                    view_impl.selector,
                    uses,
                )
            }

        case:
            panic("Unsupported bind group entry resource", loc)
        }

        append(&entry_list, resolved)
    }

    entries = entry_list[:]
    buffers = buffer_list[:]
    samplers = sampler_list[:]
    texture_views = texture_view_list[:]

    bind_group_states_optimize(&used)

    return
}

@(require_results)
vk_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    impl := vk_device_get_impl(device, loc)

    if !vk_bind_group_validate(device, impl, descriptor, loc) {
        return {}
    }
    layout_impl := vk_bind_group_layout_get_impl(descriptor.layout, loc)

    dynamic_bindings := make(
        [dynamic]VK_Dynamic_Binding,
        0,
        len(descriptor.entries),
        impl.allocator,
    )
    for entry in descriptor.entries {
        layout_entry, found := layout_impl.entries[entry.binding]
        if !found {
            continue
        }
        layout, is_buffer := layout_entry.type.(Buffer_Binding_Layout)
        if !is_buffer || !layout.has_dynamic_offset {
            continue
        }
        #partial switch v in entry.resource {
        case Buffer_Binding:
            append(
                &dynamic_bindings,
                VK_Dynamic_Binding{key = entry.binding, binding = v, type = layout.type},
            )
        case []Buffer_Binding:
            for binding in v {
                append(
                    &dynamic_bindings,
                    VK_Dynamic_Binding{key = entry.binding, binding = binding, type = layout.type},
                )
            }
        case:
        }
    }
    slice.sort_by(dynamic_bindings[:], proc(a, b: VK_Dynamic_Binding) -> bool {
        return a.key < b.key
    })

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    resolved_entries, resolved_buffers, resolved_samplers, resolved_texture_views, used :=
        vk_resolve_bind_group(device, descriptor, loc)

    vk_bind_group_layout_borrow(descriptor.layout)

    vk_descriptor_set := vk_descriptor_allocator_alloc(
        &impl.descriptor,
        VK_Descriptor_Layout_Info {
            raw                     = layout_impl.raw,
            desc_count              = layout_impl.desc_count,
            contains_binding_arrays = layout_impl.contains_binding_arrays,
        },
    )

    buffer_desc_count := len(resolved_buffers)
    image_desc_count := len(resolved_samplers) + len(resolved_texture_views)

    writes := make([]vk.WriteDescriptorSet, len(resolved_entries), ta)
    buffer_infos := make([]vk.DescriptorBufferInfo, buffer_desc_count, ta)
    image_infos := make([]vk.DescriptorImageInfo, image_desc_count, ta)

    buffers := make([dynamic]VK_Buffer_Access, 0, buffer_desc_count, impl.allocator)
    texture_views := make(
        [dynamic]VK_Texture_View_Access,
        0,
        len(resolved_texture_views),
        impl.allocator,
    )
    samplers := make([dynamic]Sampler, 0, len(resolved_samplers), impl.allocator)

    write_idx, buffer_idx, image_idx: int

    for entry in resolved_entries {
        // Application binding numbers are mapped to Vulkan binding numbers when the
        // layout is created; only the lookup is a backend concern.
        layout_index, layout_found := slice.binary_search_by(
            layout_impl.binding_map,
            entry.binding,
            proc(layout_entry: VK_Binding_Info, binding: u32) -> slice.Ordering {
                return slice.cmp(layout_entry.key, binding)
            },
        )
        assert(layout_found, "Failed to find bind group layout entry for binding", loc)
        layout_binding := layout_impl.binding_map[layout_index]

        layout_entry := layout_impl.entries[layout_binding.key]

        assert(entry.binding_array_size > 0, "Empty binding array", loc)
        if device_has_feature(device, .Partially_Bound_Binding_Array) {
            assert(
                entry.binding_array_size <= layout_binding.binding_array_size,
                "Descriptor count exceeds the layout",
                loc,
            )
        } else {
            assert(
                entry.binding_array_size == layout_binding.binding_array_size,
                "Descriptor count mismatch for binding (provided != layout expected)",
                loc,
            )
        }

        end := entry.resource_index + int(entry.binding_array_size)

        writes[write_idx] = vk.WriteDescriptorSet {
            sType           = .WRITE_DESCRIPTOR_SET,
            dstSet          = vk_descriptor_set.raw,
            dstBinding      = layout_binding.binding,
            dstArrayElement = 0,
            descriptorCount = entry.binding_array_size,
            descriptorType  = vk_conv_to_descriptor_type(layout_entry),
        }

        #partial switch t in entry.type {
        case Buffer_Binding_Layout:
            writes[write_idx].pBufferInfo = &buffer_infos[buffer_idx]

            for slot in resolved_buffers[entry.resource_index:end] {
                buffer_impl := vk_buffer_get_impl(slot.binding.buffer, loc)
                buffer_infos[buffer_idx] = vk.DescriptorBufferInfo {
                    buffer = buffer_impl.vk_buffer,
                    offset = vk.DeviceSize(slot.binding.offset),
                    range  = vk.DeviceSize(slot.binding.size),
                }
                append(&buffers, VK_Buffer_Access {
                    buffer     = slot.binding.buffer,
                    is_storage = slot.is_storage,
                })
                vk_buffer_add_ref(slot.binding.buffer)
                buffer_idx += 1
            }

        case Sampler_Binding_Layout:
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for smp in resolved_samplers[entry.resource_index:end] {
                sampler_impl := vk_sampler_get_impl(smp, loc)
                image_infos[image_idx] = vk.DescriptorImageInfo {
                    sampler = sampler_impl.vk_sampler,
                }
                append(&samplers, smp)
                vk_sampler_add_ref(smp)
                image_idx += 1
            }

        case Texture_Binding_Layout, Storage_Texture_Binding_Layout:
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for slot in resolved_texture_views[entry.resource_index:end] {
                tv_impl := vk_texture_view_get_impl(slot.view, loc)
                image_infos[image_idx] = vk.DescriptorImageInfo {
                    imageView   = tv_impl.vk_image_view,
                    imageLayout = vk.ImageLayout.GENERAL if slot.is_storage else .SHADER_READ_ONLY_OPTIMAL,
                }
                append(&texture_views, VK_Texture_View_Access {
                    texture_view = slot.view,
                    is_storage   = slot.is_storage,
                    view_impl    = tv_impl,
                })
                vk_texture_view_add_ref(slot.view)
                image_idx += 1
            }

        case:
            panic("Unsupported bind group entry resource", loc)
        }

        write_idx += 1
    }

    vk.UpdateDescriptorSets(impl.vk_device, u32(write_idx), raw_data(writes), 0, nil)

    buffer_init_actions, texture_init_actions := vk_collect_bind_group_init_actions(
        resolved_buffers,
        resolved_texture_views,
        impl.allocator,
        loc,
    )

    _, handle := add_impl(&impl.bind_groups, VK_Bind_Group_Impl {
            base = _Bind_Group_Impl {
                device = device,
                layout = descriptor.layout,
                used   = used,
            },
            descriptor_set = vk_descriptor_set,
            buffers = buffers[:],
            texture_views = texture_views[:],
            samplers = samplers[:],
            buffer_init_actions = buffer_init_actions,
            texture_init_actions = texture_init_actions,
            dynamic_bindings = dynamic_bindings[:],
            layout_impl = vk_bind_group_layout_get_impl(descriptor.layout, loc),
        })

    vk_label_set(&impl.labels, .Bind_Group, pack_handle(handle), descriptor.label)

    return new_handle(Bind_Group, device, handle)
}

@(require_results)
vk_bind_group_get_internal_impl :: #force_inline proc "contextless" (
    bind_group: Bind_Group,
    loc := #caller_location,
) -> ^_Bind_Group_Impl {
    return &vk_bind_group_get_impl(bind_group, loc).base
}

@(require_results)
vk_bind_group_get_impl :: #force_inline proc "contextless" (
    bind_group: Bind_Group,
    loc := #caller_location,
) -> ^VK_Bind_Group_Impl {
    device_impl := vk_device_get_impl(bind_group.device, loc)
    return get_handle_impl(&device_impl.bind_groups, bind_group.handle, loc)
}

vk_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    impl := vk_bind_group_get_impl(bind_group, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Bind_Group, pack_handle(impl.handle))
}

vk_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    impl := vk_bind_group_get_impl(bind_group, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Bind_Group, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(
        device_impl.fp,
        .DESCRIPTOR_SET,
        impl.descriptor_set.raw,
        label,
        loc,
    )
}

vk_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := vk_bind_group_get_impl(bind_group, loc)
    add_ref(impl, loc)
}

vk_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := vk_bind_group_get_impl(bind_group, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)

        vk_deferred_add_resource(
            &device_impl.deferred,
            &device_impl.submitter,
            VK_Deferred_Descriptor_Set {
                descriptor     = &device_impl.descriptor,
                descriptor_set = impl.descriptor_set,
            },
        )

        for buffer_access in impl.buffers {
            vk_buffer_release(buffer_access.buffer, loc)
        }
        for texture_view_access in impl.texture_views {
            vk_texture_view_release(texture_view_access.texture_view, loc)
        }
        for sampler in impl.samplers {
            vk_sampler_release(sampler, loc)
        }
        vk_bind_group_layout_drop_borrow(impl.layout, loc)

        delete(impl.buffers, device_impl.allocator)
        delete(impl.texture_views, device_impl.allocator)
        delete(impl.samplers, device_impl.allocator)
        delete(impl.buffer_init_actions, device_impl.allocator)
        delete(impl.texture_init_actions, device_impl.allocator)
        delete(impl.dynamic_bindings, device_impl.allocator)

        bind_group_states_free(&impl.used)

        vk_label_remove(&device_impl.labels, .Bind_Group, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.bind_groups, impl.handle)
    }
}
