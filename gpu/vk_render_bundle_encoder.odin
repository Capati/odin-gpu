#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle_Encoder
// -----------------------------------------------------------------------------

VK_Render_Bundle_Encoder_Handle :: distinct hm.Handle64

VK_Render_Bundle_Encoder_Impl :: struct {
    using base: _Render_Bundle_Encoder_Impl,
    handle:     VK_Render_Bundle_Encoder_Handle,

    // The compact replay stream (see `vk_bundle_commands.odin`); transferred to
    // the bundle by `vk_render_bundle_encoder_finish`.
    commands: Bundle_Command_Allocator,

    // Usage of every command recorded so far, tallied at encode so
    // `execute_bundles` can merge the whole bundle into the pass scope in one
    // step instead of re-deriving it per replayed bind.
    scope: Render_Bundle_Scope,
}

@(require_results)
vk_create_render_bundle_encoder :: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder {
    device_impl := vk_device_get_impl(device, loc)

    valid := true
    limits := _device_get_internal_impl(device, loc).limits
    valid &= gpu_validate(
        device,
        u32(len(descriptor.color_formats)) <= limits.max_color_attachments,
        "bundle declares too many color attachments",
        loc,
    )
    valid &= gpu_validate(
        device,
        len(descriptor.color_formats) > 0 || descriptor.depth_stencil != nil,
        "bundle requires at least one attachment",
        loc,
    )
    sample_count := max(u32(1), descriptor.sample_count)
    valid &= gpu_validate(
        device,
        sample_count == 1 || sample_count == 4,
        "bundle sample count must be 1 or 4",
        loc,
    )

    attachment_bytes: u32
    for format in descriptor.color_formats {
        features, ok := device_describe_format_features(device, format, loc)
        valid &= gpu_validate(
            device,
            ok &&
            .Render_Attachment in features.allowed_usages &&
            !texture_format_is_depth_stencil_format(format),
            "bundle color format cannot be used as a render attachment",
            loc,
        )
        alignment := texture_format_target_component_alignment(format, loc)
        cost := texture_format_target_pixel_byte_cost(format, loc)
        if alignment > 0 {
            attachment_bytes = (attachment_bytes + alignment - 1) / alignment * alignment + cost
        }
    }
    valid &= gpu_validate(
        device,
        attachment_bytes <= limits.max_color_attachment_bytes_per_sample,
        "bundle color attachments exceed the bytes-per-sample budget",
        loc,
    )

    if descriptor.depth_stencil != nil {
        format := descriptor.depth_stencil.depth_stencil_format
        features, ok := device_describe_format_features(device, format, loc)
        valid &= gpu_validate(
            device,
            ok &&
            texture_format_is_depth_stencil_format(format) &&
            .Render_Attachment in features.allowed_usages,
            "bundle depth/stencil format is not renderable",
            loc,
        )
    }

    if !valid {
        // C3 keeps the handle valid but records nothing, so recording verbs and
        // finish behave as no-ops instead of reporting a second time.
    }

    encoder_impl, encoder_handle := add_impl(
        &device_impl.render_bundle_encoders,
        VK_Render_Bundle_Encoder_Impl {
            device       = device,
            is_encoding  = true,
            failed       = !valid,
            sample_count = sample_count,
        },
    )
    encoder_impl.color_count = min(u32(len(descriptor.color_formats)), u32(MAX_COLOR_ATTACHMENTS))
    if valid {
        for format, i in descriptor.color_formats[:encoder_impl.color_count] {
            encoder_impl.color_formats[i] = format
        }
        if descriptor.depth_stencil != nil {
            encoder_impl.depth_stencil = descriptor.depth_stencil^
            encoder_impl.has_depth_stencil = true
        }
    }
    bundle_command_allocator_init(&encoder_impl.commands, device_impl.allocator)
    render_bundle_scope_init(&encoder_impl.scope, device_impl.allocator)
    encoder_impl.immediate_data.allocator = device_impl.allocator
    // No pre-reserve: `set_immediates` grows to the high-water mark on first
    // use, so a bundle that never uses push constants allocates nothing here
    // instead of paying a fixed 4 KiB per bundle.
    encoder_impl.pipelines.allocator = device_impl.allocator
    encoder_impl.bind_groups.allocator = device_impl.allocator
    encoder_impl.buffers.allocator = device_impl.allocator

    vk_label_set(
        &device_impl.labels,
        .Render_Bundle_Encoder,
        pack_handle(encoder_handle),
        descriptor.label,
    )

    return new_handle(Render_Bundle_Encoder, device, encoder_handle)
}

@(require_results)
vk_render_bundle_encoder_get_impl :: #force_inline proc "contextless" (
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) -> ^VK_Render_Bundle_Encoder_Impl {
    device_impl := vk_device_get_impl(render_bundle_encoder.device, loc)
    return get_handle_impl(&device_impl.render_bundle_encoders, render_bundle_encoder.handle, loc)
}

@(require_results)
vk_render_bundle_encoder_get_internal_impl :: #force_inline proc "contextless" (
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) -> ^_Render_Bundle_Encoder_Impl {
    return vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
}

vk_render_bundle_encoder_draw :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Draw_Cmd, loc)
    cmd.vertex_count = vertex_count
    cmd.instance_count = instance_count
    cmd.first_vertex = first_vertex
    cmd.first_instance = first_instance
}

vk_render_bundle_encoder_draw_indexed :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }
    if !vk_bundle_strip_index_ok(impl, loc) {
        return
    }
    if impl.has_index_buffer {
        index_size := u64(impl.index_format == .Uint16 ? 2 : 4)
        if u64(index_count) + u64(first_index) > impl.index_buffer_size / index_size {
            gpu_report_validation_error(
                impl.device,
                "drawIndexed index range is out of bounds",
                loc,
            )
            return
        }
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Draw_Indexed_Cmd, loc)
    cmd.index_count = index_count
    cmd.instance_count = instance_count
    cmd.first_index = first_index
    cmd.base_vertex = base_vertex
    cmd.first_instance = first_instance
}

vk_bundle_strip_index_ok :: proc(
    impl: ^VK_Render_Bundle_Encoder_Impl,
    loc := #caller_location,
) -> bool {
    if impl.active_pipeline == {} || !impl.has_index_buffer {
        return true
    }
    pipeline_impl := vk_render_pipeline_get_impl(impl.active_pipeline, loc)
    is_strip := pipeline_impl.topology == .Triangle_Strip || pipeline_impl.topology == .Line_Strip
    if is_strip &&
       (pipeline_impl.strip_index_format == .Undefined ||
               pipeline_impl.strip_index_format != impl.index_format) {
        gpu_report_validation_error(
            impl.device,
            "index format does not match the pipeline's strip index format",
            loc,
        )
        return false
    }
    return true
}

vk_render_bundle_encoder_draw_indexed_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    if !vk_bundle_strip_index_ok(impl, loc) {
        return
    }
    if !vk_indirect_binding_validate(
        impl.device,
        device_impl,
        indirect_buffer,
        indirect_offset,
        20,
        loc,
    ) {
        return
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Draw_Indirect_Cmd, loc)
    cmd.buffer = indirect_buffer
    cmd.offset = indirect_offset
    cmd.family = .Draw_Indexed
    append(&impl.buffers, indirect_buffer)
    vk_buffer_add_ref(indirect_buffer, loc)
    vk_render_bundle_encoder_note_indirect(impl, indirect_buffer, loc)
}

vk_render_bundle_encoder_draw_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    if !vk_indirect_binding_validate(
        impl.device,
        device_impl,
        indirect_buffer,
        indirect_offset,
        16,
        loc,
    ) {
        return
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Draw_Indirect_Cmd, loc)
    cmd.buffer = indirect_buffer
    cmd.offset = indirect_offset
    cmd.family = .Draw
    append(&impl.buffers, indirect_buffer)
    vk_buffer_add_ref(indirect_buffer, loc)
    vk_render_bundle_encoder_note_indirect(impl, indirect_buffer, loc)
}

// An indirect draw reads its arguments from a buffer, so that buffer is part of
// the bundle's usage even though no vertex or index binding names it.
vk_render_bundle_encoder_note_indirect :: proc(
    impl: ^VK_Render_Bundle_Encoder_Impl,
    buffer: Buffer,
    loc := #caller_location,
) {
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    conflict: Usage_Conflict
    if !usage_scope_add_buffer(
        &impl.scope,
        buffer_impl.tracker_index,
        buffer,
        {.Indirect},
        &conflict,
    ) {
        gpu_report_validation_error(
            impl.device,
            "conflicting buffer usages in a render bundle",
            loc,
        )
        impl.failed = true
    }
}

vk_render_bundle_encoder_finish :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    descriptor: Render_Bundle_Descriptor,
    loc := #caller_location,
) -> Render_Bundle {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return {}
    }
    if !impl.is_encoding {
        gpu_report_validation_error(
            impl.device,
            "finishing a render bundle encoder that is not encoding",
            loc,
        )
        return {}
    }

    if impl.debug_group_depth != 0 {
        gpu_report_validation_error(
            impl.device,
            "debug group stack was not popped before the bundle ended",
            loc,
        )
        impl.debug_group_depth = 0
    }

    impl.is_encoding = false
    device_impl := vk_device_get_impl(impl.device, loc)

    // The encoder is consumed by finishing: its command list and its usage tally
    // become the bundle's, so no copy and no per-command refs.
    bundle_impl, bundle_handle := add_impl(&device_impl.render_bundles, VK_Render_Bundle_Impl {
            device            = impl.device,
            commands          = impl.commands,
            immediate_data    = impl.immediate_data,
            color_formats     = impl.color_formats,
            color_count       = impl.color_count,
            depth_stencil     = impl.depth_stencil,
            has_depth_stencil = impl.has_depth_stencil,
            sample_count      = impl.sample_count,
            pipelines         = impl.pipelines,
            bind_groups       = impl.bind_groups,
            buffers           = impl.buffers,
            scope             = impl.scope,
        })
    impl.commands = {}
    impl.immediate_data = {}
    impl.pipelines = nil
    impl.bind_groups = nil
    impl.buffers = nil
    impl.scope = {}

    // The command list and its pipelines/groups are immutable from here, so the
    // verdict holds for the bundle's life; `execute_bundles` reads the flag
    // instead of walking thousands of commands per frame.
    bundle_impl.bind_groups_valid = vk_render_bundle_bind_groups_validate(
        impl.device,
        bundle_impl,
        loc,
    )

    vk_label_set(&device_impl.labels, .Render_Bundle, pack_handle(bundle_handle), descriptor.label)

    return new_handle(Render_Bundle, impl.device, bundle_handle)
}

// Debug markers and groups are accepted but not emitted; see the command encoder.
vk_render_bundle_encoder_insert_debug_marker :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
    }
}

vk_render_bundle_encoder_pop_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }
    if impl.debug_group_depth == 0 {
        gpu_report_validation_error(impl.device, "debug group stack underflow", loc)
        return
    }
    impl.debug_group_depth -= 1
}

vk_render_bundle_encoder_push_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }
    impl.debug_group_depth += 1
}

vk_render_bundle_encoder_set_bind_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    bind_group_impl, offsets_ok := vk_bind_group_offsets_validate(
        impl.device,
        device_impl,
        group,
        group_index,
        dynamic_offsets,
        loc,
    )
    if !offsets_ok {
        return
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Set_Bind_Group_Cmd, loc)
    cmd.index = group_index
    cmd.dynamic_offsets = dynamic_offsets
    cmd.bind_group = group
    if group != {} {
        append(&impl.bind_groups, group)
        vk_bind_group_add_ref(group, loc)

        // Fold this group's resources into the bundle's usage tally. Conflicts are
        // reported here, at record time, so executing the bundle never has to
        // re-check them.
        cmd.group_impl = bind_group_impl
        conflict: Usage_Conflict
        if !render_bundle_scope_merge_bind_group(&impl.scope, &bind_group_impl.used, &conflict) {
            gpu_report_validation_error(
                impl.device,
                "conflicting buffer or texture usages in a render bundle",
                loc,
            )
            impl.failed = true
            return
        }
    }
}

vk_render_bundle_encoder_set_immediates :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    // The bundle owns its command list, so the bytes live as long as it does.
    start := len(impl.immediate_data)
    if size > 0 {
        if start + int(size) > cap(impl.immediate_data) {
            reserve(&impl.immediate_data, start + int(size))
        }
        source := cast([^]u8)data
        append(&impl.immediate_data, ..source[:size])
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Set_Immediates_Cmd, loc)
    cmd.offset = offset
    cmd.data = impl.immediate_data[start:]
}

vk_render_bundle_encoder_set_index_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    effective_size, valid := vk_index_binding_validate(
        impl.device,
        device_impl,
        buffer,
        format,
        offset,
        size,
        loc,
    )
    if !valid {
        return
    }
    impl.index_format = format
    impl.has_index_buffer = true
    impl.index_buffer_size = effective_size

    cmd := bundle_command_allocate(&impl.commands, Bundle_Set_Index_Buffer_Cmd, loc)
    cmd.buffer = buffer
    cmd.index_format = format
    cmd.offset = offset
    // Store the validated size: replay does not re-run the validation, so it
    // must not have to re-derive `WHOLE_SIZE` either.
    cmd.size = effective_size
    append(&impl.buffers, buffer)
    vk_buffer_add_ref(buffer, loc)

    buffer_impl := vk_buffer_get_impl(buffer, loc)
    cmd.buffer_impl = buffer_impl
    conflict: Usage_Conflict
    if !usage_scope_add_buffer(
        &impl.scope,
        buffer_impl.tracker_index,
        buffer,
        {.Index},
        &conflict,
    ) {
        gpu_report_validation_error(
            impl.device,
            "conflicting buffer usages in a render bundle",
            loc,
        )
        impl.failed = true
    }
}

vk_render_bundle_encoder_get_label :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) -> string {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Render_Bundle_Encoder, pack_handle(impl.handle))
}

vk_render_bundle_encoder_set_label :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    label: string,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    // A bundle encoder is a recorded command list; it has no Vulkan object to name.
    vk_label_set(&device_impl.labels, .Render_Bundle_Encoder, pack_handle(impl.handle), label)
}

vk_render_bundle_encoder_set_pipeline :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    if !dhm_is_valid(
        &device_impl.render_pipelines,
        unpack_handle(VK_Render_Pipeline_Handle, pipeline.handle),
    ) {
        gpu_report_validation_error(impl.device, "set pipeline is not a live render pipeline", loc)
        return
    }
    pipeline_impl := vk_render_pipeline_get_impl(pipeline, loc)
    if pipeline_impl.device != impl.device {
        gpu_report_validation_error(impl.device, "set pipeline belongs to another device", loc)
        return
    }
    impl.active_pipeline = pipeline

    cmd := bundle_command_allocate(&impl.commands, Bundle_Set_Pipeline_Cmd, loc)
    cmd.pipeline = pipeline
    cmd.pipeline_impl = pipeline_impl
    cmd.layout_impl =
        pipeline_impl.layout != {} ? vk_pipeline_layout_get_impl(pipeline_impl.layout, loc) : nil
    append(&impl.pipelines, pipeline)
    vk_render_pipeline_add_ref(pipeline, loc)
}

vk_render_bundle_encoder_set_vertex_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if impl.failed {
        return
    }
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "render bundle encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    effective_size, valid := vk_vertex_binding_validate(
        impl.device,
        device_impl,
        slot,
        buffer,
        offset,
        size,
        loc,
    )
    if !valid {
        return
    }

    cmd := bundle_command_allocate(&impl.commands, Bundle_Set_Vertex_Buffer_Cmd, loc)
    cmd.slot = slot
    cmd.buffer = buffer
    cmd.offset = offset
    cmd.size = effective_size
    append(&impl.buffers, buffer)
    vk_buffer_add_ref(buffer, loc)

    buffer_impl := vk_buffer_get_impl(buffer, loc)
    cmd.buffer_impl = buffer_impl
    conflict: Usage_Conflict
    if !usage_scope_add_buffer(
        &impl.scope,
        buffer_impl.tracker_index,
        buffer,
        {.Vertex},
        &conflict,
    ) {
        gpu_report_validation_error(
            impl.device,
            "conflicting buffer usages in a render bundle",
            loc,
        )
        impl.failed = true
    }
}

vk_render_bundle_encoder_add_ref :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    add_ref(impl, loc)
}

vk_render_bundle_encoder_release :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    impl := vk_render_bundle_encoder_get_impl(render_bundle_encoder, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        for pipeline in impl.pipelines {
            vk_render_pipeline_release(pipeline, loc)
        }
        for bind_group in impl.bind_groups {
            vk_bind_group_release(bind_group, loc)
        }
        for buffer in impl.buffers {
            vk_buffer_release(buffer, loc)
        }
        delete(impl.pipelines)
        delete(impl.bind_groups)
        delete(impl.buffers)
        // Freed only if this encoder was never finished; finishing hands the
        // scope to the bundle and clears it here.
        render_bundle_scope_free(&impl.scope)
        if impl.is_encoding {
            bundle_command_allocator_destroy(&impl.commands, loc)
            delete(impl.immediate_data)
        }
        vk_label_remove(&device_impl.labels, .Render_Bundle_Encoder, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.render_bundle_encoders, impl.handle)
    }
}
