#+build !js
package gpu

// Core
import "core:sync"

// Vendor
import vk "vendor:vulkan"

// Direct render pass recording: every call issues its Vulkan command immediately
// into the isolated pass buffer. The transit buffer (query resets, pre-pass
// barriers, beginning timestamp) is assembled at end and submitted immediately
// before the pass.

vk_render_pass_flush_bind_groups :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_flush_bind_groups(
        device_impl,
        encoder_impl.cmdbuf,
        &impl.bind_group_slots,
        impl.active_layout,
        impl.active_layout_impl,
        .GRAPHICS,
        loc,
    )
}

// Emits the vertex bindings queued since the last draw, grouped into
// contiguous slot runs so N `set_vertex_buffer` calls become one driver call
// when the slots are adjacent (the common case).
vk_render_pass_flush_vertex_buffers :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    loc := #caller_location,
) {
    mask := impl.vertex_dirty_mask
    if mask == 0 {
        return
    }

    device_impl := vk_device_get_impl(impl.device)

    buffers: [MAX_VERTEX_BUFFERS]vk.Buffer
    offsets: [MAX_VERTEX_BUFFERS]vk.DeviceSize

    slot: u32
    for slot < MAX_VERTEX_BUFFERS {
        if (mask & (u32(1) << slot)) == 0 {
            slot += 1
            continue
        }

        first := slot
        count: u32
        for slot < MAX_VERTEX_BUFFERS && (mask & (u32(1) << slot)) != 0 {
            buffers[count] = impl.vertex_buffers[slot]
            offsets[count] = vk.DeviceSize(impl.vertex_offsets[slot])
            count += 1
            slot += 1
        }

        device_impl.fp.CmdBindVertexBuffers(
            encoder_impl.cmdbuf.current_cmdbuf,
            first,
            count,
            raw_data(buffers[:count]),
            raw_data(offsets[:count]),
        )
    }

    impl.vertex_dirty_mask = 0
}

vk_render_pass_flush_state :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    loc := #caller_location,
) {
    vk_render_pass_flush_bind_groups(impl, encoder_impl, loc)
    vk_render_pass_flush_vertex_buffers(impl, encoder_impl, loc)
}

vk_render_pass_write_timestamp :: proc(
    render_pass: Render_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    vk_record_write_timestamp(device_impl, encoder_impl.cmdbuf, query_set, query_index, loc = loc)
    vk_render_pass_track_query_use(impl, query_set, query_index, loc)
}

vk_render_pass_begin_occlusion_query :: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
) {
    if render_pass == {} {
        return
    }
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    if impl.occlusion_query_set == {} {
        gpu_report_validation_error(impl.device, "render pass has no occlusion query set", loc)
        return
    }

    set_live := dhm_is_valid(
        &device_impl.query_sets,
        unpack_handle(VK_Query_Set_Handle, impl.occlusion_query_set.handle),
    )
    if !gpu_validate(impl.device, set_live, "occlusion query set is not a live set", loc) {
        return
    }

    set_impl := vk_query_set_get_impl(impl.occlusion_query_set, loc)

    valid := gpu_validate(
        impl.device,
        set_impl.type == .Occlusion,
        "occlusion queries require an OCCLUSION query set",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        query_index < set_impl.count,
        "occlusion query index is out of bounds",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        impl.active_query_set == {},
        "cannot begin an occlusion query inside another",
        loc,
    )
    reused := false
    for used in encoder_impl.cmdbuf.pass_occlusion_used {
        if used == query_index {
            reused = true
            break
        }
    }
    valid &= gpu_validate(
        impl.device,
        !reused,
        "a query slot can only be used once per render pass",
        loc,
    )
    if !valid {
        return
    }

    append(&encoder_impl.cmdbuf.pass_occlusion_used, query_index)

    device_impl.fp.CmdBeginQuery(
        encoder_impl.cmdbuf.current_cmdbuf,
        set_impl.vk_query_pool,
        query_index,
        {},
    )

    impl.active_query_set = impl.occlusion_query_set
    impl.active_query_index = query_index
    vk_render_pass_track_query_use(impl, impl.occlusion_query_set, query_index, loc)
}

vk_render_pass_end_occlusion_query :: proc(render_pass: Render_Pass, loc := #caller_location) {
    if render_pass == {} {
        return
    }
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    if impl.active_query_set == {} {
        gpu_report_validation_error(impl.device, "no occlusion query is open", loc)
        return
    }

    vk_record_end_query(
        device_impl,
        encoder_impl.cmdbuf,
        impl.active_query_set,
        impl.active_query_index,
        loc,
    )
    impl.active_query_set = {}
}

vk_render_pass_begin_pipeline_statistics_query :: proc(
    render_pass: Render_Pass,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
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
    }

    set_impl := vk_query_set_get_impl(query_set, loc)
    device_impl.fp.CmdBeginQuery(
        encoder_impl.cmdbuf.current_cmdbuf,
        set_impl.vk_query_pool,
        query_index,
        {},
    )

    impl.active_query_set = query_set
    impl.active_query_index = query_index
    vk_render_pass_track_query_use(impl, query_set, query_index, loc)
}

vk_render_pass_end_pipeline_statistics_query :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
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

// Validate a vertex-buffer binding: slot budget, live buffer, same device,
// `Vertex` usage, 4-byte offset alignment, and a range inside the buffer.
// Returns the effective bound size (the rest of the buffer for `WHOLE_SIZE`).
vk_vertex_binding_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) -> (
    effective_size: u64,
    ok: bool,
) {
    if buffer == {} {
        gpu_report_validation_error(device, "vertex buffer is not a live buffer", loc)
        return 0, false
    }
    // Check the handle's own device field first. A handle from another device
    // can name a live slot in this device's map (the DHM key is not
    // device-qualified), which would otherwise be accepted.
    if buffer.device != device {
        gpu_report_validation_error(device, "vertex buffer belongs to another device", loc)
        return 0, false
    }
    limits := _device_get_internal_impl(device, loc).limits
    if slot >= limits.max_vertex_buffers {
        gpu_report_validation_error(device, "vertex buffer slot exceeds the limit", loc)
        return 0, false
    }
    buffer_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, buffer.handle),
    )
    if buffer_impl == nil {
        gpu_report_validation_error(device, "vertex buffer is not a live buffer", loc)
        return 0, false
    }
    if buffer_impl.destroyed {
        gpu_report_validation_error(device, "vertex buffer has been destroyed", loc)
        return 0, false
    }
    if buffer_impl.device != device {
        gpu_report_validation_error(device, "vertex buffer belongs to another device", loc)
        return 0, false
    }
    if .Vertex not_in buffer_impl.public_usage {
        gpu_report_validation_error(device, "vertex buffer requires the [Vertex] usage", loc)
        return 0, false
    }
    if offset % 4 != 0 {
        gpu_report_validation_error(device, "vertex buffer offset must be 4-byte aligned", loc)
        return 0, false
    }
    visible := buffer_impl.visible_size
    if offset > visible {
        gpu_report_validation_error(device, "vertex buffer offset is outside the buffer", loc)
        return 0, false
    }
    remaining := visible - offset
    if size == WHOLE_SIZE {
        return remaining, true
    }
    if size > remaining {
        gpu_report_validation_error(device, "vertex buffer range is outside the buffer", loc)
        return 0, false
    }
    return size, true
}

// The byte span a draw reaches for one vertex slot: `stride * (count - 1) +
// lastAttributeEnd`, where `count` includes the first index. An empty range reads
// nothing.
@(require_results)
vk_vertex_range_fits :: proc "contextless" (
    stride, last: u64,
    count: u64,
    bound_size: u64,
) -> bool {
    if count == 0 {
        return true
    }
    return stride * (count - 1) + last <= bound_size
}

// Check the vertex-rate range (host `draw` only) and the instance-rate range
// (host `draw` and `drawIndexed`) of every slot the pipeline reads.
@(require_results)
vk_render_pass_vertex_ranges_ok :: proc(
    impl: ^VK_Render_Pass_Impl,
    pipeline_impl: ^VK_Render_Pipeline_Impl,
    first_vertex, vertex_count, first_instance, instance_count: u32,
    check_vertex: bool,
    loc := #caller_location,
) -> bool {
    for slot in 0 ..< MAX_VERTEX_BUFFERS {
        if (pipeline_impl.vertex_mask & (u32(1) << u32(slot))) == 0 {
            continue
        }
        count := u64(0)
        if pipeline_impl.vertex_step[slot] == .Vertex {
            if !check_vertex {
                continue
            }
            count = u64(first_vertex) + u64(vertex_count)
        } else {
            count = u64(first_instance) + u64(instance_count)
        }
        if !vk_vertex_range_fits(
            pipeline_impl.vertex_stride[slot],
            pipeline_impl.vertex_last[slot],
            count,
            impl.vertex_sizes[slot],
        ) {
            gpu_report_validation_error(
                impl.device,
                "draw reads past the bound vertex buffer",
                loc,
            )
            return false
        }
    }
    return true
}

vk_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_draw_impl(
        impl,
        impl.cached_encoder,
        vertex_count,
        instance_count,
        first_vertex,
        first_instance,
        loc,
    )
}

// Shared by the public call and bundle replay. The replay loop resolves the
// pass impl once for the whole walk, so the draw must not re-resolve the handle
// per command; everything below the entry is identical for both callers.
vk_render_pass_draw_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "No render pipeline bound", loc)
        return
    }
    pipeline_impl := impl.active_pipeline_impl
    // These checks are not skipped during bundle replay: the bundle's recorded
    // commands are static, but the pass can disturb its slots between bundles,
    // so the state a replayed draw actually runs under is only known here. The
    // CTS mismatch/equivalence tests fail when this is skipped.
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            impl.active_layout_impl,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }
    for i in 0 ..< MAX_VERTEX_BUFFERS {
        if (pipeline_impl.vertex_mask & (u32(1) << u32(i))) != 0 && !impl.vertex_slots[i] {
            gpu_report_validation_error(
                impl.device,
                "draw requires every vertex slot the pipeline declares",
                loc,
            )
            return
        }
    }
    if !vk_render_pass_vertex_ranges_ok(
        impl,
        pipeline_impl,
        first_vertex,
        vertex_count,
        first_instance,
        instance_count,
        true,
        loc,
    ) {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    device_impl.fp.CmdDraw(
        encoder_impl.cmdbuf.current_cmdbuf,
        vertex_count,
        instance_count,
        first_vertex,
        first_instance,
    )
}

vk_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_draw_indexed_impl(
        impl,
        impl.cached_encoder,
        index_count,
        instance_count,
        first_index,
        base_vertex,
        first_instance,
        loc,
    )
}

vk_render_pass_draw_indexed_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "No render pipeline bound", loc)
        return
    }

    if !impl.has_index_buffer {
        gpu_report_validation_error(impl.device, "drawIndexed requires an index buffer", loc)
        return
    }
    pipeline_impl := impl.active_pipeline_impl
    // Not skipped during a bundle replay; see `vk_render_pass_draw`.
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            impl.active_layout_impl,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }
    for i in 0 ..< MAX_VERTEX_BUFFERS {
        if (pipeline_impl.vertex_mask & (u32(1) << u32(i))) != 0 && !impl.vertex_slots[i] {
            gpu_report_validation_error(
                impl.device,
                "drawIndexed requires every vertex slot the pipeline declares",
                loc,
            )
            return
        }
    }
    if !vk_render_pass_vertex_ranges_ok(
        impl,
        pipeline_impl,
        0,
        0,
        first_instance,
        instance_count,
        false,
        loc,
    ) {
        return
    }
    index_size := u64(impl.index_format == .Uint16 ? 2 : 4)
    is_strip := pipeline_impl.topology == .Triangle_Strip || pipeline_impl.topology == .Line_Strip
    if is_strip &&
       (pipeline_impl.strip_index_format == .Undefined ||
               pipeline_impl.strip_index_format != impl.index_format) {
        gpu_report_validation_error(
            impl.device,
            "index format does not match the pipeline's strip index format",
            loc,
        )
        return
    }
    available := impl.index_buffer_size / index_size
    if u64(index_count) + u64(first_index) > available {
        gpu_report_validation_error(impl.device, "drawIndexed index range is out of bounds", loc)
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    device_impl.fp.CmdDrawIndexed(
        encoder_impl.cmdbuf.current_cmdbuf,
        index_count,
        instance_count,
        first_index,
        base_vertex,
        first_instance,
    )
}

vk_render_pass_draw_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_draw_indirect_impl(
        impl,
        impl.cached_encoder,
        indirect_buffer,
        indirect_offset,
        loc,
    )
}

vk_render_pass_draw_indirect_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "No render pipeline bound", loc)
        return
    }
    pipeline_impl := impl.active_pipeline_impl
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            impl.active_layout_impl,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }

    if !vk_indirect_binding_validate(
        impl.device,
        device_impl,
        indirect_buffer,
        indirect_offset,
        size_of(vk.DrawIndirectCommand),
        loc,
    ) {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(indirect_buffer, loc)
    device_impl.fp.CmdDrawIndirect(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(indirect_offset),
        1,
        u32(size_of(vk.DrawIndirectCommand)),
    )
}

vk_render_pass_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_draw_indexed_indirect_impl(
        impl,
        impl.cached_encoder,
        indirect_buffer,
        indirect_offset,
        loc,
    )
}

vk_render_pass_draw_indexed_indirect_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} {
        gpu_report_validation_error(impl.device, "No render pipeline bound", loc)
        return
    }
    pipeline_impl := impl.active_pipeline_impl
    if impl.bind_groups_dirty {
        if !vk_pipeline_bind_groups_validate(
            impl.device,
            pipeline_impl.layout,
            impl.active_layout_impl,
            impl.bind_group_slots[:],
            loc,
        ) {
            return
        }
        impl.bind_groups_dirty = false
    }

    if !vk_indirect_binding_validate(
        impl.device,
        device_impl,
        indirect_buffer,
        indirect_offset,
        size_of(vk.DrawIndexedIndirectCommand),
        loc,
    ) {
        return
    }
    is_strip := pipeline_impl.topology == .Triangle_Strip || pipeline_impl.topology == .Line_Strip
    if is_strip &&
       (pipeline_impl.strip_index_format == .Undefined ||
               (impl.has_index_buffer && pipeline_impl.strip_index_format != impl.index_format)) {
        gpu_report_validation_error(
            impl.device,
            "index format does not match the pipeline's strip index format",
            loc,
        )
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(indirect_buffer, loc)
    device_impl.fp.CmdDrawIndexedIndirect(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(indirect_offset),
        1,
        u32(size_of(vk.DrawIndexedIndirectCommand)),
    )
}

vk_render_pass_multi_draw_indirect :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    assert(impl.active_pipeline != {}, "No render pipeline bound", loc)
    if count == 0 {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    device_impl.fp.CmdDrawIndirect(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(offset),
        count,
        u32(size_of(vk.DrawIndirectCommand)),
    )
}

vk_render_pass_multi_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    assert(impl.active_pipeline != {}, "No render pipeline bound", loc)
    if count == 0 {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    device_impl.fp.CmdDrawIndexedIndirect(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(offset),
        count,
        u32(size_of(vk.DrawIndexedIndirectCommand)),
    )
}

vk_render_pass_multi_draw_indirect_count :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count_buffer: Buffer,
    count_buffer_offset: u64,
    max_count: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    assert(impl.active_pipeline != {}, "No render pipeline bound", loc)
    if max_count == 0 {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    count_impl := vk_buffer_get_impl(count_buffer, loc)
    device_impl.fp.CmdDrawIndirectCount(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(offset),
        count_impl.vk_buffer,
        vk.DeviceSize(count_buffer_offset),
        max_count,
        u32(size_of(vk.DrawIndirectCommand)),
    )
}

vk_render_pass_multi_draw_indexed_indirect_count :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    offset: u64,
    count_buffer: Buffer,
    count_buffer_offset: u64,
    max_count: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    assert(impl.active_pipeline != {}, "No render pipeline bound", loc)
    if max_count == 0 {
        return
    }

    vk_render_pass_flush_state(impl, encoder_impl, loc)
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    count_impl := vk_buffer_get_impl(count_buffer, loc)
    device_impl.fp.CmdDrawIndexedIndirectCount(
        encoder_impl.cmdbuf.current_cmdbuf,
        buffer_impl.vk_buffer,
        vk.DeviceSize(offset),
        count_impl.vk_buffer,
        vk.DeviceSize(count_buffer_offset),
        max_count,
        u32(size_of(vk.DrawIndexedIndirectCommand)),
    )
}

// Replay entry point for a bundle's `setBindGroup`. Usage, refs and pair
// validation were settled at encode/finish; what remains is the slot assignment
// and the flush caches. Takes the impl directly; the public setter would probe
// the pass handle per command.
vk_replay_bind_group :: #force_inline proc(
    impl: ^VK_Render_Pass_Impl,
    group_index: u32,
    group: Bind_Group,
    group_impl: ^VK_Bind_Group_Impl,
    dynamic_offsets: []u32,
) {
    if group_impl == nil {
        // WebGPU allows clearing a slot; a bundle that recorded a nil handle has
        // no impl to resolve, and the slot is cleared without touching caches.
        impl.bind_group_slots[group_index] = {}
        impl.bind_groups_dirty = true
        return
    }

    slot := &impl.bind_group_slots[group_index]
    // Only invalidate the flush cache when the group changes: the cache is keyed
    // on the layout, so re-clearing it would force a redundant
    // `CmdBindDescriptorSets` for a group reused across draws.
    if slot.group_impl != group_impl {
        slot.bound_layout = {}
        // The descriptor set and impl come from the command: the encoder resolved
        // them when it merged this group's usage, so replay probes no handle map
        // and takes no shared lock.
        slot.descriptor_set = group_impl.descriptor_set.raw
        slot.group_impl = group_impl
        // A new group has not been validated against any layout yet.
        slot.validated_layout = {}
    }
    slot.group = group
    slot.dynamic_offsets = dynamic_offsets
    slot.assigned = true
    impl.bind_groups_dirty = true
}

vk_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)

    // Replaying a bundle: its usage was tallied at encode time and merged into the
    // pass scope once before the replay began, and `execute_bundles` already took
    // the references and recorded the init actions for every group the bundle
    // names, so nothing is validated or recorded here - only the binding itself.
    if impl.replaying_bundle {
        group_impl: ^VK_Bind_Group_Impl
        if group != {} {
            group_impl = vk_bind_group_get_impl(group, loc)
        }
        vk_replay_bind_group(impl, group_index, group, group_impl, dynamic_offsets)
        return
    }

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

    if impl.depth_texture != {} {
        for access in bind_group_impl.texture_views {
            view_impl := access.view_impl
            if view_impl == nil {
                view_impl = vk_texture_view_get_impl(access.texture_view, loc)
            }
            if view_impl.texture != impl.depth_texture ||
               !texture_selector_overlaps(view_impl.selector, impl.depth_selector) {
                continue
            }
            view_depth := view_impl.aspect == .All || view_impl.aspect == .Depth_Only
            view_stencil := view_impl.aspect == .All || view_impl.aspect == .Stencil_Only
            if (.Depth_Write in impl.depth_uses && view_depth) ||
               (.Stencil_Write in impl.depth_uses && view_stencil) {
                gpu_report_validation_error(
                    impl.device,
                    "a written depth/stencil aspect is bound in this render pass",
                    loc,
                )
                return
            }
        }
    }
    conflict: Usage_Conflict
    merged := usage_scope_merge_bind_group(
        &encoder_impl.cmdbuf.pass_scope,
        &bind_group_impl.used,
        &conflict,
    )
    if !merged {
        gpu_report_validation_error(
            impl.device,
            "conflicting buffer or texture usages in a render pass",
            loc,
        )
        return
    }

    // Rebinding the same group across draws must not take a second reference:
    // the tracker holds it once, so it releases it once.
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
    // Cache here too: `bind_group_impl` is already resolved above for the usage
    // merge, so this is free, and it keeps the flush from probing per draw.
    slot.descriptor_set = bind_group_impl.descriptor_set.raw
    // The draw-time validation reads the impl instead of re-probing, and a
    // newly assigned group has not been validated against any layout yet.
    slot.group_impl = bind_group_impl
    slot.validated_layout = {}
    impl.bind_groups_dirty = true
}

vk_render_pass_set_blend_constant :: proc(
    render_pass: Render_Pass,
    color: Color,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    color := [4]f32{f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
    device_impl.fp.CmdSetBlendConstants(encoder_impl.cmdbuf.current_cmdbuf, &color)
}

vk_render_pass_set_immediates :: proc(
    render_pass: Render_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_set_immediates_impl(impl, impl.cached_encoder, offset, data, size, loc)
}

vk_render_pass_set_immediates_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.active_pipeline == {} || size == 0 {
        return
    }

    pipeline_impl := impl.active_pipeline_impl
    layout_impl := vk_pipeline_layout_get_impl(pipeline_impl.layout, loc)
    device_impl.fp.CmdPushConstants(
        encoder_impl.cmdbuf.current_cmdbuf,
        layout_impl.raw,
        {.VERTEX, .FRAGMENT},
        offset,
        u32(size),
        data,
    )
}

// Validate an indirect-argument buffer: live, same device, `Indirect` usage, a
// 4-byte-aligned offset, and enough room for the 16- or 20-byte argument struct.
vk_indirect_binding_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    buffer: Buffer,
    offset: u64,
    arguments_size: u64,
    loc := #caller_location,
) -> bool {
    buffer_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, buffer.handle),
    )
    if buffer_impl == nil {
        gpu_report_validation_error(device, "indirect buffer is not a live buffer", loc)
        return false
    }
    if buffer_impl.destroyed {
        gpu_report_validation_error(device, "indirect buffer has been destroyed", loc)
        return false
    }
    if buffer_impl.device != device {
        gpu_report_validation_error(device, "indirect buffer belongs to another device", loc)
        return false
    }
    if .Indirect not_in buffer_impl.public_usage {
        gpu_report_validation_error(device, "indirect buffer requires the [Indirect] usage", loc)
        return false
    }
    if offset % 4 != 0 {
        gpu_report_validation_error(device, "indirect buffer offset must be 4-byte aligned", loc)
        return false
    }
    visible := buffer_impl.visible_size
    if offset > visible || arguments_size > visible - offset {
        gpu_report_validation_error(device, "indirect arguments do not fit in the buffer", loc)
        return false
    }
    return true
}

// Validate an index-buffer binding: live buffer, same device, `Index` usage,
// offset aligned to the index size, and a range inside the buffer (an absent
// size means the rest of the buffer). Returns the effective bound size.
@(require_results)
vk_index_binding_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) -> (
    effective_size: u64,
    ok: bool,
) {
    buffer_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, buffer.handle),
    )
    if buffer_impl == nil {
        gpu_report_validation_error(device, "index buffer is not a live buffer", loc)
        return 0, false
    }
    if buffer_impl.destroyed {
        gpu_report_validation_error(device, "index buffer has been destroyed", loc)
        return 0, false
    }
    if buffer_impl.device != device {
        gpu_report_validation_error(device, "index buffer belongs to another device", loc)
        return 0, false
    }
    if .Index not_in buffer_impl.public_usage {
        gpu_report_validation_error(device, "index buffer requires the [Index] usage", loc)
        return 0, false
    }
    index_size := u64(format == .Uint16 ? 2 : 4)
    if offset % index_size != 0 {
        gpu_report_validation_error(
            device,
            "index buffer offset must be aligned to the index size",
            loc,
        )
        return 0, false
    }
    visible := buffer_impl.visible_size
    if offset > visible {
        gpu_report_validation_error(device, "index buffer offset is outside the buffer", loc)
        return 0, false
    }
    remaining := visible - offset
    if size == WHOLE_SIZE {
        return remaining, true
    }
    if size > remaining {
        gpu_report_validation_error(device, "index buffer range is outside the buffer", loc)
        return 0, false
    }
    return size, true
}

// A render pass has one usage scope, and vertex/index bindings contribute to it
// even when no draw follows.
@(require_results)
vk_render_pass_merge_buffer_usage :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    buffer: Buffer,
    buffer_impl: ^VK_Buffer_Impl,
    uses: Buffer_Uses,
    loc := #caller_location,
) -> bool {
    conflict: Usage_Conflict
    if !usage_scope_add_buffer(
        &encoder_impl.cmdbuf.pass_scope,
        buffer_impl.tracker_index,
        buffer,
        uses,
        &conflict,
    ) {
        gpu_report_validation_error(
            impl.device,
            "conflicting buffer or texture usages in a render pass",
            loc,
        )
        return false
    }
    return true
}

vk_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_set_index_buffer_impl(
        impl,
        impl.cached_encoder,
        buffer,
        format,
        offset,
        size,
        !impl.replaying_bundle,
        loc,
    )
}

// `merge_usage` is false during bundle replay: the bundle's tally was merged
// into the pass scope once, before the walk.
vk_render_pass_set_index_buffer_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    merge_usage: bool,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    // Validated on the public path. A bundle replay does not re-run this: the
    // encoder validated the same buffer with the same arguments, the bundle holds
    // a reference so it cannot have been destroyed, and usage/device are
    // immutable - the replay uses the validated result stored in its command.
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
    buffer_impl := vk_buffer_get_impl(buffer, loc)

    if merge_usage {
        if !vk_render_pass_merge_buffer_usage(
            impl,
            encoder_impl,
            buffer,
            buffer_impl,
            {.Index},
            loc,
        ) {
            return
        }
    }

    vk_render_pass_apply_index_buffer(
        impl,
        encoder_impl,
        buffer,
        format,
        offset,
        effective_size,
        buffer_impl,
    )
}

// Everything an index-buffer bind still has to do once validation is behind it.
// Shared by the public path and bundle replay; replay passes the values the
// encoder validated instead of validating again.
vk_render_pass_apply_index_buffer :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    effective_size: u64,
    buffer_impl: ^VK_Buffer_Impl,
) {
    device_impl := vk_device_get_impl(impl.device)
    vk_offset := vk.DeviceSize(offset)

    // Vulkan's index binding is sticky, so re-issuing identical values only costs
    // the driver a validation walk.
    unchanged :=
        impl.has_index_buffer &&
        impl.index_buffer == buffer &&
        impl.index_format == format &&
        impl.index_buffer_offset == offset &&
        impl.index_buffer_size == effective_size

    impl.index_buffer = buffer
    impl.index_format = format
    impl.index_buffer_offset = offset
    impl.index_buffer_size = effective_size
    impl.has_index_buffer = true

    if !unchanged {
        device_impl.fp.CmdBindIndexBuffer(
            encoder_impl.cmdbuf.current_cmdbuf,
            buffer_impl.vk_buffer,
            vk_offset,
            vk_conv_to_index_type(format),
        )
    }
}

vk_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_set_pipeline_impl(
        impl,
        impl.cached_encoder,
        pipeline,
        !impl.replaying_bundle,
        loc,
    )
}

// `check_attachments` is false during bundle replay: the bundle's pipelines were
// checked at encode time and the bundle/pass pair was checked before the walk.
vk_render_pass_set_pipeline_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    pipeline: Render_Pipeline,
    check_attachments: bool,
    loc := #caller_location,
) {
    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    pipeline_impl: ^VK_Render_Pipeline_Impl
    if pipeline != {} {
        pipeline_device := vk_device_get_impl(pipeline.device, loc)
        pipeline_impl = dhm_get_if_valid(
            &pipeline_device.render_pipelines,
            unpack_handle(VK_Render_Pipeline_Handle, pipeline.handle),
        )
    }
    if pipeline_impl == nil {
        gpu_report_validation_error(impl.device, "set pipeline is not a live render pipeline", loc)
        return
    }
    if pipeline_impl.device != impl.device {
        gpu_report_validation_error(impl.device, "set pipeline belongs to another device", loc)
        return
    }

    // Skipped during bundle replay: attachment compatibility was checked when the
    // bundle was encoded and again for the bundle as a whole against this pass, so
    // the per-pipeline comparison cannot change the verdict.
    if check_attachments {
        pass_color_count := u32(len(impl.color_formats))
        compatible :=
            pipeline_impl.sample_count == impl.sample_count &&
            pipeline_impl.color_count == pass_color_count
        if compatible {
            for i in 0 ..< pass_color_count {
                if pipeline_impl.color_formats[i] != impl.color_formats[i] {
                    compatible = false
                    break
                }
            }
        }
        if compatible {
            if pipeline_impl.has_depth_stencil != impl.has_depth_stencil {
                compatible = false
            } else if impl.has_depth_stencil &&
               pipeline_impl.depth_format != impl.depth_stencil.depth_stencil_format {
                compatible = false
            }
        }
        if !compatible {
            gpu_report_validation_error(
                impl.device,
                "render pipeline targets are not compatible with the pass",
                loc,
            )
            return
        }
    }

    vk_render_pass_apply_pipeline(
        impl,
        encoder_impl,
        pipeline,
        pipeline_impl,
        pipeline_impl.layout != {} ? vk_pipeline_layout_get_impl(pipeline_impl.layout, loc) : nil,
    )
}

// The state update and driver call of a pipeline bind, once the pipeline is
// resolved and checked. Shared with bundle replay, which resolved both when the
// bundle was encoded.
vk_render_pass_apply_pipeline :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    pipeline: Render_Pipeline,
    pipeline_impl: ^VK_Render_Pipeline_Impl,
    layout_impl: ^VK_Pipeline_Layout_Impl,
) {
    device_impl := vk_device_get_impl(impl.device)

    // Same pipeline bound twice in one pass: hold one reference.
    if _, inserted := stateless_tracker_insert_single(
        &encoder_impl.cmdbuf.tracker.render_pipelines,
        pipeline,
    ); inserted {
        vk_render_pipeline_add_ref(pipeline)
    }

    device_impl.fp.CmdBindPipeline(
        encoder_impl.cmdbuf.current_cmdbuf,
        .GRAPHICS,
        pipeline_impl.vk_pipeline,
    )
    impl.active_pipeline = pipeline
    impl.active_pipeline_impl = pipeline_impl
    impl.active_layout = pipeline_impl.layout
    // An auto-layout pipeline carries no layout handle; the draw-time
    // validation and the flush check `active_layout == {}` before they read
    // this pointer, so nil here is never dereferenced.
    impl.active_layout_impl = layout_impl
    impl.bind_groups_dirty = true
}

vk_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    if u64(x) + u64(width) > u64(impl.width) || u64(y) + u64(height) > u64(impl.height) {
        gpu_report_validation_error(
            impl.device,
            "scissor rectangle is outside the attachment",
            loc,
        )
        return
    }

    device_impl.fp.CmdSetScissor(
        encoder_impl.cmdbuf.current_cmdbuf,
        0,
        1,
        &vk.Rect2D{offset = {i32(x), i32(y)}, extent = {width, height}},
    )
}

vk_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    device_impl.fp.CmdSetStencilReference(
        encoder_impl.cmdbuf.current_cmdbuf,
        {.FRONT, .BACK},
        reference,
    )
}

vk_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64 = 0,
    size: u64 = WHOLE_SIZE,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    vk_render_pass_set_vertex_buffer_impl(
        impl,
        impl.cached_encoder,
        slot,
        buffer,
        offset,
        size,
        !impl.replaying_bundle,
        loc,
    )
}

// `merge_usage` is false during bundle replay; see
// `vk_render_pass_set_index_buffer_impl`.
vk_render_pass_set_vertex_buffer_impl :: proc(
    impl: ^VK_Render_Pass_Impl,
    encoder_impl: ^VK_Command_Encoder_Impl,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    merge_usage: bool,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    // See `vk_render_pass_set_index_buffer_impl`: the public path validates,
    // replay uses the encoder's result.
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
    buffer_impl := vk_buffer_get_impl(buffer, loc)

    if merge_usage {
        if !vk_render_pass_merge_buffer_usage(
            impl,
            encoder_impl,
            buffer,
            buffer_impl,
            {.Vertex},
            loc,
        ) {
            return
        }
    }

    vk_render_pass_apply_vertex_buffer(impl, slot, buffer, offset, effective_size, buffer_impl)
}

// The state update of a vertex-buffer bind, shared with replay. The driver call
// is deferred to the draw's flush through the dirty mask.
vk_render_pass_apply_vertex_buffer :: proc(
    impl: ^VK_Render_Pass_Impl,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    effective_size: u64,
    buffer_impl: ^VK_Buffer_Impl,
) {
    if slot < u32(MAX_VERTEX_BUFFERS) {
        // Skip the rebind when nothing changed. Vulkan keeps vertex bindings sticky
        // for the lifetime of the command buffer, so re-binding identical values is
        // a no-op the driver still has to walk. Bundle encoders prune the same way
        // at finish ("drop redundant SetVertexBuffer commands").
        unchanged :=
            impl.vertex_slots[slot] &&
            impl.vertex_buffers[slot] == buffer_impl.vk_buffer &&
            impl.vertex_offsets[slot] == offset &&
            impl.vertex_sizes[slot] == effective_size

        impl.vertex_slots[slot] = true
        impl.vertex_offsets[slot] = offset
        impl.vertex_sizes[slot] = effective_size
        impl.vertex_buffers[slot] = buffer_impl.vk_buffer
        if !unchanged {
            impl.vertex_dirty_mask |= u32(1) << slot
        }
    }
}

vk_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    if width < 0 || height < 0 {
        gpu_report_validation_error(
            impl.device,
            "viewport width and height must be non-negative",
            loc,
        )
        return
    }
    if min_depth < 0 || min_depth > 1 || max_depth < 0 || max_depth > 1 || max_depth < min_depth {
        gpu_report_validation_error(impl.device, "invalid viewport depth range", loc)
        return
    }
    limits := _device_get_internal_impl(impl.device, loc).limits
    bound := f32(limits.max_texture_dimension_2d)
    if x < -2 * bound ||
       y < -2 * bound ||
       width > bound ||
       height > bound ||
       x + width > 2 * bound - 1 ||
       y + height > 2 * bound - 1 {
        gpu_report_validation_error(
            impl.device,
            "viewport rectangle is outside the allowed bounds",
            loc,
        )
        return
    }

    device_impl.fp.CmdSetViewport(encoder_impl.cmdbuf.current_cmdbuf, 0, 1, &vk.Viewport {
            x        = x,
            y        = y + height,
            width    = width,
            height   = -height,
            minDepth = min_depth,
            maxDepth = max_depth,
        })
}

// The bundle's recorded pipeline/group pairs are validated once at finish; the
// command list and its resources are immutable afterwards, so `execute_bundles`
// only reads the cached verdict.
vk_render_bundle_bind_groups_validate :: proc(
    device: Device,
    bundle: ^VK_Render_Bundle_Impl,
    loc := #caller_location,
) -> bool {
    slots: [MAX_BIND_GROUPS]VK_Bind_Group_Slot
    pipeline_layout: Pipeline_Layout
    pipeline_layout_impl: ^VK_Pipeline_Layout_Impl
    valid := true
    for curr in array_iterate_by_ptr(&bundle.commands.iterator) {
        #partial switch &cmd in curr {
        case Bundle_Set_Pipeline_Cmd:
            pipeline_layout = vk_render_pipeline_get_impl(cmd.pipeline, loc).layout
            pipeline_layout_impl =
                pipeline_layout != {} ? vk_pipeline_layout_get_impl(pipeline_layout, loc) : nil
        case Bundle_Set_Bind_Group_Cmd:
            if cmd.index < MAX_BIND_GROUPS {
                if cmd.bind_group == {} {
                    slots[cmd.index] = {}
                } else {
                    slots[cmd.index] = VK_Bind_Group_Slot {
                        group      = cmd.bind_group,
                        group_impl = cmd.group_impl,
                        assigned   = true,
                    }
                }
            }
        case Bundle_Draw_Cmd, Bundle_Draw_Indexed_Cmd, Bundle_Draw_Indirect_Cmd:
            if !vk_pipeline_bind_groups_validate(
                device,
                pipeline_layout,
                pipeline_layout_impl,
                slots[:],
                loc,
            ) {
                valid = false
            }
        }
    }
    // Leave the iterator rewound whether or not the walk finished early, so the
    // caller can iterate the same commands afterwards. Callers must not rely on
    // this as their *only* rewind: the iterator is shared state and the last
    // walker owns it.
    bundle_command_allocator_iterator_reset(&bundle.commands)
    return valid
}

vk_render_pass_execute_bundles :: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    encoder_impl := impl.cached_encoder

    for bundle in bundles {
        bundle_impl: ^VK_Render_Bundle_Impl
        if bundle != {} {
            bundle_device := vk_device_get_impl(bundle.device, loc)
            bundle_impl = dhm_get_if_valid(
                &bundle_device.render_bundles,
                unpack_handle(VK_Render_Bundle_Handle, bundle.handle),
            )
        }
        if bundle_impl == nil {
            gpu_report_validation_error(impl.device, "render bundle is not a live bundle", loc)
            continue
        }
        if bundle_impl.device != impl.device {
            gpu_report_validation_error(
                impl.device,
                "render bundle belongs to another device",
                loc,
            )
            continue
        }
        // Not re-walked here: a finished bundle is immutable and keeps every
        // pipeline and bind group it names alive, so whether its commands satisfy
        // their layouts was decided once, at `render_bundle_encoder_finish`. Walking
        // the whole command list on every frame was pure repeated work.
        if !bundle_impl.bind_groups_valid {
            continue
        }

        // The iterator is exhausted by whoever walked it last - the encoder's
        // validation pass during `finish`, or the previous frame's replay - so
        // rewind it before iterating. Validation used to do this as a side effect
        // of running here; now that it does not, it has to be explicit.
        bundle_command_allocator_iterator_reset(&bundle_impl.commands)

        pass_color_count := u32(len(impl.color_formats))
        compatible :=
            bundle_impl.sample_count == impl.sample_count &&
            bundle_impl.color_count == pass_color_count
        if compatible {
            for i in 0 ..< pass_color_count {
                if bundle_impl.color_formats[i] != impl.color_formats[i] {
                    compatible = false
                    break
                }
            }
        }
        if compatible {
            if bundle_impl.has_depth_stencil != impl.has_depth_stencil {
                compatible = false
            } else if impl.has_depth_stencil {
                if bundle_impl.depth_stencil.depth_stencil_format !=
                   impl.depth_stencil.depth_stencil_format {
                    compatible = false
                } else {
                    aspects := texture_format_aspects_from(impl.depth_stencil.depth_stencil_format)
                    if .Depth in aspects &&
                       impl.depth_stencil.depth_read_only &&
                       !bundle_impl.depth_stencil.depth_read_only {
                        compatible = false
                    }
                    if .Stencil in aspects &&
                       impl.depth_stencil.stencil_read_only &&
                       !bundle_impl.depth_stencil.stencil_read_only {
                        compatible = false
                    }
                }
            }
        }
        if !compatible {
            gpu_report_validation_error(
                impl.device,
                "render bundle attachments are not compatible with the pass",
                loc,
            )
            continue
        }

        // No reference on the bundle itself: replay consumes its commands now,
        // so only the resources those commands name must outlive the command
        // buffer, and the replayed setters take those refs.

        // Fold the bundle's whole resource tally into the pass in one step. The
        // bundle computed it while it was encoded, so this single merge replaces
        // the per-`set_bind_group` merges the replay would otherwise repeat.
        conflict: Usage_Conflict
        if !usage_scope_merge_render_bundle(
            &encoder_impl.cmdbuf.pass_scope,
            &bundle_impl.scope,
            &conflict,
        ) {
            gpu_report_validation_error(
                impl.device,
                "conflicting buffer or texture usages between a render bundle and the pass",
                loc,
            )
            continue
        }

        // The commands below were validated when the bundle was recorded, so the
        // replay skips re-validating them. This is the difference between a bundle
        // saving CPU time and costing extra; see the field's comment in
        // `VK_Render_Pass_Impl`.
        impl.replaying_bundle = true
        defer impl.replaying_bundle = false

        // One reference stands for everything the bundle names: execution
        // inserts the bundle, and its groups, pipelines and buffers were
        // referenced at encode. Its usage was merged above, so submit-time
        // validation does not need per-group tracker entries.
        tracker := &encoder_impl.cmdbuf.tracker
        if _, inserted := stateless_tracker_insert_single(&tracker.bundles, bundle); inserted {
            vk_render_bundle_add_ref(bundle, loc)
        }

        // Init actions stay per execute: they describe state this command buffer
        // must establish before the GPU reads those ranges.
        for group in bundle_impl.bind_groups {
            if group == {} {
                continue
            }
            group_impl := vk_bind_group_get_impl(group, loc)
            for action in group_impl.buffer_init_actions {
                tracker_record_buffer_init(tracker, action.buffer, action.range, action.kind)
            }
            for action in group_impl.texture_init_actions {
                tracker_record_init(
                    tracker,
                    action.texture,
                    action.range,
                    action.kind,
                    action.aspect,
                )
            }
        }

        for curr in array_iterate_by_ptr(&bundle_impl.commands.iterator) {
            #partial switch &src in curr {
            case Bundle_Set_Bind_Group_Cmd:
                vk_replay_bind_group(
                    impl,
                    src.index,
                    src.bind_group,
                    src.group_impl,
                    src.dynamic_offsets,
                )

            case Bundle_Set_Pipeline_Cmd:
                vk_render_pass_apply_pipeline(
                    impl,
                    encoder_impl,
                    src.pipeline,
                    src.pipeline_impl,
                    src.layout_impl,
                )

            case Bundle_Set_Index_Buffer_Cmd:
                vk_render_pass_apply_index_buffer(
                    impl,
                    encoder_impl,
                    src.buffer,
                    src.index_format,
                    src.offset,
                    src.size,
                    src.buffer_impl,
                )

            case Bundle_Set_Vertex_Buffer_Cmd:
                vk_render_pass_apply_vertex_buffer(
                    impl,
                    src.slot,
                    src.buffer,
                    src.offset,
                    src.size,
                    src.buffer_impl,
                )

            case Bundle_Set_Immediates_Cmd:
                vk_render_pass_set_immediates_impl(
                    impl,
                    encoder_impl,
                    src.offset,
                    raw_data(src.data) if len(src.data) > 0 else nil,
                    len(src.data),
                    bundle_command_location(&bundle_impl.commands, src.loc),
                )

            case Bundle_Draw_Cmd:
                vk_render_pass_draw_impl(
                    impl,
                    encoder_impl,
                    src.vertex_count,
                    src.instance_count,
                    src.first_vertex,
                    src.first_instance,
                    bundle_command_location(&bundle_impl.commands, src.loc),
                )

            case Bundle_Draw_Indexed_Cmd:
                vk_render_pass_draw_indexed_impl(
                    impl,
                    encoder_impl,
                    src.index_count,
                    src.instance_count,
                    src.first_index,
                    src.base_vertex,
                    src.first_instance,
                    bundle_command_location(&bundle_impl.commands, src.loc),
                )

            case Bundle_Draw_Indirect_Cmd:
                if src.family == .Draw_Indexed {
                    vk_render_pass_draw_indexed_indirect_impl(
                        impl,
                        encoder_impl,
                        src.buffer,
                        src.offset,
                        bundle_command_location(&bundle_impl.commands, src.loc),
                    )
                } else if src.family == .Draw {
                    vk_render_pass_draw_indirect_impl(
                        impl,
                        encoder_impl,
                        src.buffer,
                        src.offset,
                        bundle_command_location(&bundle_impl.commands, src.loc),
                    )
                }
            }
        }
    }
}

vk_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    if render_pass == {} {
        return
    }
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := impl.cached_encoder
    device_impl := vk_device_get_impl(impl.device, loc)

    if impl.is_invalid {
        gpu_report_validation_error(impl.device, "ending an invalid render pass", loc)
        encoder_impl.invalid = true
        impl.is_rendering = false
        encoder_impl.is_rendering = false
        return
    }

    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }

    cmdbuf := encoder_impl.cmdbuf

    // Close a query the pass left open, and report the imbalance.
    if impl.active_query_set != {} {
        gpu_report_validation_error(
            impl.device,
            "occlusion query was not ended before the pass ended",
            loc,
        )
        vk_record_end_query(
            device_impl,
            cmdbuf,
            impl.active_query_set,
            impl.active_query_index,
            loc,
        )
        impl.active_query_set = {}
    }

    device_impl.fp.CmdEndRenderPass(cmdbuf.current_cmdbuf)

    if impl.debug_group_depth != 0 {
        gpu_report_validation_error(
            impl.device,
            "debug group stack was not popped before the pass ended",
            loc,
        )
        impl.debug_group_depth = 0
        encoder_impl.invalid = true
    }

    // The descriptor's end timestamp is written after the pass.
    if impl.timestamp_writes.query_set != {} {
        vk_record_write_timestamp(
            device_impl,
            cmdbuf,
            impl.timestamp_writes.query_set,
            impl.timestamp_writes.end_of_pass_write_index,
            loc = loc,
        )
    }

    // Swapchain images leave the pass in the attachment layout; transition them
    // to PRESENT in a buffer that executes after it.
    for i in 0 ..< impl.present_count {
        vk_record_transition_texture(
            device_impl,
            cmdbuf.current_cmdbuf,
            impl.present_textures[i],
            nil,
            {.Color_Target},
            TEXTURE_USES_PRESENT,
            true,
            loc,
        )
    }

    vk_command_buffer_fold_usage_scope(cmdbuf, &cmdbuf.pass_scope, loc)

    clear(&cmdbuf.pass_buffer_transitions)
    append(&cmdbuf.pass_buffer_transitions, ..cmdbuf.tracker.buffers.temp[:])
    buffer_tracker_clear_pending(&cmdbuf.tracker.buffers)

    clear(&cmdbuf.pass_texture_transitions)
    append(&cmdbuf.pass_texture_transitions, ..cmdbuf.tracker.textures.temp[:])
    texture_tracker_clear_pending(&cmdbuf.tracker.textures)

    // The pass itself moves swapchain images to PRESENT, so record that
    // silently for later commands in this buffer.
    for i in 0 ..< impl.present_count {
        texture := impl.present_textures[i]
        texture_impl := vk_texture_get_impl(texture, loc)
        index := texture_impl.tracker_index

        texture_update(
            nil,
            &cmdbuf.tracker.textures.end,
            index,
            vk_tracked_texture(texture, texture_impl),
            texture_state_provider_single(TEXTURE_USES_PRESENT),
        )

        if !texture_tracker_contains(&cmdbuf.tracker.textures, index) {
            continue
        }
        end_is_present :=
            !texture_state_set_is_complex(&cmdbuf.tracker.textures.end, index) &&
            cmdbuf.tracker.textures.end.simple[u32(index)] == TEXTURE_USES_PRESENT
        if end_is_present {
            sync.guard(&device_impl.trackers_mtx)
            device_texture_tracker_insert_single(
                &device_impl.trackers.textures,
                vk_tracked_texture(texture, texture_impl),
                TEXTURE_USES_PRESENT,
            )
        }
    }

    // Close the pass buffer; transit runs immediately before it.
    ensure(cmdbuf.isolated_cmdbuf != {}, "render pass buffer not isolated", loc)
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

    // Swapchain images are re-acquired each frame with undefined contents; the
    // only valid starting layout is UNDEFINED, so re-enter the attachment layout
    // explicitly regardless of what the tracker believes.
    for i in 0 ..< impl.present_count {
        vk_record_transition_texture(
            device_impl,
            transit,
            impl.present_textures[i],
            nil,
            TEXTURE_USES_UNINITIALIZED,
            {.Color_Target},
            false,
            loc,
        )
    }
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

    impl.is_rendering = false
    encoder_impl.is_rendering = false
}
