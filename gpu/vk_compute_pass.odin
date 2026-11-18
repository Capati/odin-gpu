#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Compute_Pass_Handle :: distinct hm.Handle64

VK_COMPUTE_PASS_MAX_QUERY_USES :: 16

VK_Compute_Pass_Impl :: struct {
    using base: _Compute_Pass_Impl,

    // Recording-time caches; valid only while this pass is open.
    cached_encoder: ^VK_Command_Encoder_Impl,
    cached_cmdbuf:  ^VK_Command_Buffer_Impl,

    layout:             Pipeline_Layout,
    bind_group_slots:   [MAX_BIND_GROUPS]VK_Bind_Group_Slot,
    // Revalidate bound groups only when the pipeline or a slot changed.
    bind_groups_dirty:  bool,
    timestamp_writes:   Render_Pass_Timestamp_Writes,
    active_query_set:   Query_Set,
    active_query_index: u32,
    used_queries:       [VK_COMPUTE_PASS_MAX_QUERY_USES]Query_Set_Write,
    used_query_count:   u32,
    is_computing:       bool,
    active_pipeline:    Compute_Pipeline,
    debug_group_depth:  u32,
    // A tombstone for a refused `begin_compute_pass`; see the render pass.
    is_invalid:         bool,
    handle:             VK_Compute_Pass_Handle,
}

// Record a query slot this pass used, so its reset is encoded before the pass.
vk_compute_pass_track_query_use :: proc(
    impl: ^VK_Compute_Pass_Impl,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    if query_set == {} {
        return
    }
    for i in 0 ..< impl.used_query_count {
        use := impl.used_queries[i]
        if use.query_set == query_set && use.index == query_index {
            return
        }
    }
    ensure(
        impl.used_query_count < VK_COMPUTE_PASS_MAX_QUERY_USES,
        "too many query uses in one compute pass",
        loc,
    )
    impl.used_queries[impl.used_query_count] = Query_Set_Write {
        query_set = query_set,
        index     = query_index,
    }
    impl.used_query_count += 1
}

// Merge the groups bound for this dispatch into a fresh usage scope: compute
// passes scope per dispatch, so state setters contribute nothing on their own.
vk_compute_pass_merge_usage :: proc(
    impl: ^VK_Compute_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> bool {
    scope := &encoder_impl.cmdbuf.pass_scope
    usage_scope_clear(scope)
    declared: u32
    if pipeline_layout != {} {
        declared = vk_pipeline_layout_get_impl(pipeline_layout, loc).bind_group_layout_count
    }
    for slot, index in impl.bind_group_slots {
        if !slot.assigned || u32(index) >= declared {
            continue
        }
        group_impl := vk_bind_group_get_impl(slot.group, loc)
        conflict: Usage_Conflict
        if !usage_scope_merge_bind_group(scope, &group_impl.used, &conflict) {
            gpu_report_validation_error(
                impl.device,
                "conflicting buffer or texture usages in one dispatch",
                loc,
            )
            usage_scope_clear(scope)
            return false
        }
    }
    vk_command_buffer_fold_usage_scope(encoder_impl.cmdbuf, scope, loc)
    return true
}

vk_compute_pass_dispatch_workgroups :: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "dispatch requires a compute pipeline", loc)
        return
    }
    pipeline_impl := vk_compute_pipeline_get_impl(impl.active_pipeline, loc)
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            pipeline_impl.layout != {} ? vk_pipeline_layout_get_impl(pipeline_impl.layout, loc) : nil,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }
    if !vk_compute_pass_merge_usage(impl, encoder_impl, pipeline_impl.layout, loc) {
        return
    }
    limits := _device_get_internal_impl(impl.device, loc).limits
    max_workgroups := limits.max_compute_workgroups_per_dimension
    if workgroup_count_x > max_workgroups ||
       workgroup_count_y > max_workgroups ||
       workgroup_count_z > max_workgroups {
        gpu_report_validation_error(
            impl.device,
            "dispatch workgroup count exceeds the per-dimension limit",
            loc,
        )
        return
    }
    vk_flush_bind_groups(
        device_impl,
        encoder_impl.cmdbuf,
        &impl.bind_group_slots,
        impl.layout,
        impl.layout != {} ? vk_pipeline_layout_get_impl(impl.layout, loc) : nil,
        .COMPUTE,
        loc,
    )

    device_impl.fp.CmdDispatch(
        encoder_impl.cmdbuf.current_cmdbuf,
        workgroup_count_x,
        workgroup_count_y,
        workgroup_count_z,
    )
}

vk_compute_pass_dispatch_workgroups_indirect :: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "dispatch requires a compute pipeline", loc)
        return
    }
    pipeline_impl := vk_compute_pipeline_get_impl(impl.active_pipeline, loc)
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            pipeline_impl.layout != {} ? vk_pipeline_layout_get_impl(pipeline_impl.layout, loc) : nil,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }
    if !vk_compute_pass_merge_usage(impl, encoder_impl, pipeline_impl.layout, loc) {
        return
    }
    if !vk_indirect_binding_validate(
        impl.device,
        device_impl,
        indirect_buffer,
        indirect_offset,
        size_of(vk.DispatchIndirectCommand),
        loc,
    ) {
        return
    }
    vk_flush_bind_groups(
        device_impl,
        encoder_impl.cmdbuf,
        &impl.bind_group_slots,
        impl.layout,
        impl.layout != {} ? vk_pipeline_layout_get_impl(impl.layout, loc) : nil,
        .COMPUTE,
        loc,
    )

    buffer_impl := vk_buffer_get_impl(indirect_buffer, loc)
    device_impl.fp.CmdDispatchIndirect(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(indirect_offset),
    )
}

vk_compute_pass_end :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    if compute_pass == {} {
        return
    }
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if impl.is_invalid {
        gpu_report_validation_error(impl.device, "ending an invalid compute pass", loc)
        encoder_impl.invalid = true
        impl.is_computing = false
        encoder_impl.is_computing = false
        return
    }

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }

    cmdbuf := encoder_impl.cmdbuf

    // Close a query the pass left open.
    if impl.active_query_set != {} {
        vk_record_end_query(
            device_impl,
            cmdbuf,
            impl.active_query_set,
            impl.active_query_index,
            loc,
        )
        impl.active_query_set = {}
    }

    // The descriptor's end timestamp lands after every dispatch it contains.
    if impl.timestamp_writes.query_set != {} {
        vk_record_write_timestamp(
            device_impl,
            cmdbuf,
            impl.timestamp_writes.query_set,
            impl.timestamp_writes.end_of_pass_write_index,
            loc = loc,
        )
    }

    vk_command_buffer_fold_usage_scope(cmdbuf, &cmdbuf.pass_scope, loc)

    clear(&cmdbuf.pass_buffer_transitions)
    append(&cmdbuf.pass_buffer_transitions, ..cmdbuf.tracker.buffers.temp[:])
    buffer_tracker_clear_pending(&cmdbuf.tracker.buffers)

    clear(&cmdbuf.pass_texture_transitions)
    append(&cmdbuf.pass_texture_transitions, ..cmdbuf.tracker.textures.temp[:])
    texture_tracker_clear_pending(&cmdbuf.tracker.textures)

    // Close the pass buffer; the transit buffer is submitted immediately before
    // it and carries everything that must happen before the first dispatch.
    ensure(cmdbuf.isolated_cmdbuf != {}, "compute pass buffer not isolated", loc)
    vk_check(device_impl.fp.EndCommandBuffer(cmdbuf.isolated_cmdbuf), loc = loc)
    cmdbuf.current_cmdbuf = {}

    transit := vk_command_buffer_allocate_recording(device_impl, cmdbuf, loc)
    cmdbuf.current_cmdbuf = transit

    vk_encode_query_resets(device_impl, transit, impl.used_queries[:impl.used_query_count], loc)
    vk_encode_barriers(
        device_impl,
        cmdbuf,
        cmdbuf.pass_texture_transitions[:],
        cmdbuf.pass_buffer_transitions[:],
        loc,
    )
    if impl.timestamp_writes.query_set != {} {
        vk_record_write_timestamp(
            device_impl,
            cmdbuf,
            impl.timestamp_writes.query_set,
            impl.timestamp_writes.beginning_of_pass_write_index,
            {.TOP_OF_PIPE},
            loc,
        )
    }

    vk_check(device_impl.fp.EndCommandBuffer(transit), loc = loc)
    append(&cmdbuf.command_buffers, transit)
    append(&cmdbuf.command_buffers, cmdbuf.isolated_cmdbuf)
    cmdbuf.isolated_cmdbuf = {}

    cmdbuf.current_cmdbuf = vk_command_buffer_allocate_recording(device_impl, cmdbuf, loc)

    if impl.debug_group_depth != 0 {
        gpu_report_validation_error(
            impl.device,
            "debug group stack was not popped before the pass ended",
            loc,
        )
        impl.debug_group_depth = 0
        encoder_impl.invalid = true
    }

    impl.is_computing = false
    encoder_impl.is_computing = false
}

// Debug markers and groups are accepted but not emitted; see the command encoder.
vk_compute_pass_insert_debug_marker :: proc(
    compute_pass: Compute_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
    }
}

vk_compute_pass_pop_debug_group :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }
    if impl.debug_group_depth == 0 {
        gpu_report_validation_error(impl.device, "debug group stack underflow", loc)
        impl.is_invalid = true
        return
    }
    impl.debug_group_depth -= 1
}

vk_compute_pass_push_debug_group :: proc(
    compute_pass: Compute_Pass,
    group_label: string,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }
    impl.debug_group_depth += 1
}

vk_compute_pass_set_bind_group :: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
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

    if group == {} {
        impl.bind_group_slots[group_index] = {}
        impl.bind_groups_dirty = true
        return
    }

    // Rebinding the same group (once per dispatch) must not take a second
    // reference: the tracker holds it once, so it releases it once.
    if _, inserted := stateless_tracker_insert_single(
        &encoder_impl.cmdbuf.tracker.bind_groups,
        group,
    ); inserted {
        vk_bind_group_add_ref(group, loc)
    }

    for action in bind_group_impl.buffer_init_actions {
        tracker_record_buffer_init(
            &encoder_impl.cmdbuf.tracker,
            action.buffer,
            action.range,
            action.kind,
        )
    }
    for action in bind_group_impl.texture_init_actions {
        tracker_record_init(
            &encoder_impl.cmdbuf.tracker,
            action.texture,
            action.range,
            action.kind,
            action.aspect,
        )
    }

    slot := &impl.bind_group_slots[group_index]
    slot.group = group
    slot.dynamic_offsets = dynamic_offsets
    slot.assigned = true
    slot.bound_layout = {}
    // See `VK_Bind_Group_Slot.descriptor_set`: the flush reads this instead of
    // probing the handle map per dispatch.
    slot.descriptor_set = bind_group_impl.descriptor_set.raw
    impl.bind_groups_dirty = true
}

vk_compute_pass_set_immediates :: proc(
    compute_pass: Compute_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }
    if impl.layout == {} || size == 0 {
        return
    }

    layout_impl := vk_pipeline_layout_get_impl(impl.layout, loc)
    device_impl.fp.CmdPushConstants(
        encoder_impl.cmdbuf.current_cmdbuf,
        layout_impl.raw,
        {.COMPUTE},
        offset,
        u32(size),
        data,
    )
}

vk_compute_pass_get_label :: proc(compute_pass: Compute_Pass, loc := #caller_location) -> string {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Compute_Pass, pack_handle(impl.handle))
}

vk_compute_pass_set_label :: proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    // A pass only produces commands; it has no Vulkan object to name.
    vk_label_set(&device_impl.labels, .Compute_Pass, pack_handle(impl.handle), label)
}

vk_compute_pass_set_pipeline :: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }

    pipeline_impl: ^VK_Compute_Pipeline_Impl
    if pipeline != {} {
        pipeline_device := vk_device_get_impl(pipeline.device, loc)
        pipeline_impl = dhm_get_if_valid(
            &pipeline_device.compute_pipelines,
            unpack_handle(VK_Compute_Pipeline_Handle, pipeline.handle),
        )
    }
    if pipeline_impl == nil {
        gpu_report_validation_error(
            impl.device,
            "set pipeline is not a live compute pipeline",
            loc,
        )
        return
    }
    if pipeline_impl.device != impl.device {
        gpu_report_validation_error(impl.device, "set pipeline belongs to another device", loc)
        return
    }
    device_impl.fp.CmdBindPipeline(
        encoder_impl.cmdbuf.current_cmdbuf,
        .COMPUTE,
        pipeline_impl.vk_pipeline,
    )
    impl.layout = pipeline_impl.layout
    impl.active_pipeline = pipeline
    impl.bind_groups_dirty = true
}

vk_compute_pass_write_timestamp :: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }

    vk_record_write_timestamp(device_impl, encoder_impl.cmdbuf, query_set, query_index, loc = loc)
    vk_compute_pass_track_query_use(impl, query_set, query_index, loc)
}

vk_compute_pass_begin_pipeline_statistics_query :: proc(
    compute_pass: Compute_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)
    cmdbuf := encoder_impl.cmdbuf

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }

    if impl.active_query_set != {} {
        vk_record_end_query(
            device_impl,
            cmdbuf,
            impl.active_query_set,
            impl.active_query_index,
            loc,
        )
    }

    vk_compute_pass_track_query_use(impl, query_set, query_index, loc)
    set_impl := vk_query_set_get_impl(query_set, loc)
    device_impl.fp.CmdBeginQuery(cmdbuf.current_cmdbuf, set_impl.vk_query_pool, query_index, {})

    impl.active_query_set = query_set
    impl.active_query_index = query_index
}

vk_compute_pass_end_pipeline_statistics_query :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_computing {
        gpu_report_validation_error(impl.device, "compute pass has ended", loc)
        return
    }

    if impl.active_query_set != {} {
        vk_record_end_query(
            device_impl,
            encoder_impl.cmdbuf,
            impl.active_query_set,
            impl.active_query_index,
            loc,
        )
        impl.active_query_set = {}
    }
}

@(require_results)
vk_compute_pass_get_internal_impl :: #force_inline proc "contextless" (
    compute_pass: Compute_Pass,
    loc := #caller_location,
) -> ^_Compute_Pass_Impl {
    return &vk_compute_pass_get_impl(compute_pass, loc).base
}

@(require_results)
vk_compute_pass_get_impl :: #force_inline proc "contextless" (
    compute_pass: Compute_Pass,
    loc := #caller_location,
) -> ^VK_Compute_Pass_Impl {
    device_impl := vk_device_get_impl(compute_pass.device, loc)
    return get_handle_impl(&device_impl.computer_passes, compute_pass.handle, loc)
}

vk_compute_pass_add_ref :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    add_ref(impl, loc)
}

vk_compute_pass_release :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    impl := vk_compute_pass_get_impl(compute_pass, loc)
    if release_ref(impl, loc) {
        if impl.is_computing {
            // Releasing an open pass abandons its encoder; never leave a live
            // encoder pointing at a pass that has been removed.
            encoder_impl := impl.cached_encoder
            impl.is_computing = false
            encoder_impl.is_computing = false
            encoder_impl.is_encoding = false
        }
        vk_command_encoder_release(impl.encoder, loc)
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_label_remove(&device_impl.labels, .Compute_Pass, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.computer_passes, impl.handle)
    }
}
