#+build !js
package gpu

// Core
import intr "base:intrinsics"
import hm "core:container/handle_map"
import "core:slice"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Query_Set_Handle :: distinct hm.Handle64

// Bytes one query result occupies; the resolve destination stride's unit.
VK_QUERY_RESULT_SIZE :: 8

VK_Query_Set_Impl :: struct {
    // Base
    using base: _Query_Set_Impl,

    // Backend
    handle:            VK_Query_Set_Handle,
    count:             u32,
    // Result slots one query occupies; a resolve's destination stride.
    results_per_query: u32,
    vk_query_pool:     vk.QueryPool,
    // Which slots hold a result. A slot no command buffer wrote is unavailable in
    // Vulkan, so a resolve answers it with zeros instead of reading it.
    slots:             Memory_Init_Tracker,
    tracker_index:     Tracker_Index,
}

@(require_results)
vk_create_query_set :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set {
    impl := vk_device_get_impl(device, loc)

    resolved, ok := _resolve_query_set_descriptor(device, descriptor, loc)
    if !ok {
        return {}
    }

    // WebGPU's count may be zero (a set no query can name); Vulkan's pool size
    // must be greater than zero, so it gets one unused slot.
    vk_query_count := resolved.count
    if vk_query_count == 0 {
        vk_query_count = 1
    }

    statistics: vk.QueryPipelineStatisticFlags
    if resolved.type == .Pipeline_Statistics {
        statistics = vk_query_pipeline_statistics(descriptor.pipeline_statistics)
    }

    create_info := vk.QueryPoolCreateInfo {
        sType              = .QUERY_POOL_CREATE_INFO,
        queryType          = vk_query_type(resolved.type),
        queryCount         = vk_query_count,
        pipelineStatistics = statistics,
    }

    vk_query_pool: vk.QueryPool
    if res := impl.fp.CreateQueryPool(impl.vk_device, &create_info, nil, &vk_query_pool);
       res != .SUCCESS {
        vk_try(device, res, "vkCreateQueryPool", loc)
        return {}
    }

    tracker_index := shared_tracker_index_allocator_alloc(&impl.tracker_indices.query_sets)

    query_set_impl, query_set_handle := add_impl(&impl.query_sets, VK_Query_Set_Impl {
        device            = device,
        type              = resolved.type,
        count             = resolved.count,
        results_per_query = resolved.results_per_query,
        vk_query_pool     = vk_query_pool,
        tracker_index     = tracker_index,
    })

    memory_init_tracker_init(&query_set_impl.slots, impl.allocator, resolved.count)

    vk_label_set(&impl.labels, .Query_Set, pack_handle(query_set_handle), descriptor.label)

    return new_handle(Query_Set, device, query_set_handle)
}

@(require_results)
vk_query_set_get_impl :: #force_inline proc "contextless" (
    query_set: Query_Set,
    loc := #caller_location,
) -> ^VK_Query_Set_Impl {
    device_impl := vk_device_get_impl(query_set.device, loc)
    return get_handle_impl(&device_impl.query_sets, query_set.handle, loc)
}

@(require_results)
vk_query_set_get_internal_impl :: #force_inline proc "contextless" (
    query_set: Query_Set,
    loc := #caller_location,
) -> ^_Query_Set_Impl {
    return vk_query_set_get_impl(query_set, loc)
}

vk_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
    if query_set == {} {
        return
    }
    device_impl := vk_device_get_impl(query_set.device, loc)
    if dhm_is_valid(
        &device_impl.query_sets,
        unpack_handle(VK_Query_Set_Handle, query_set.handle),
    ) {
        sync.guard(&device_impl.trackers_mtx)
        device_impl.destroyed_query_sets[query_set] = true
        intr.atomic_add(&device_impl.destroyed_resources, 1)
    }
    vk_query_set_release(query_set, loc)
}

vk_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
    return vk_query_set_get_impl(query_set, loc).count
}

vk_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
    return vk_query_set_get_impl(query_set, loc).type
}

vk_query_set_get_label :: proc(query_set: Query_Set, loc := #caller_location) -> string {
    impl := vk_query_set_get_impl(query_set, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Query_Set, pack_handle(impl.handle))
}

vk_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
    impl := vk_query_set_get_impl(query_set, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Query_Set, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .QUERY_POOL, impl.vk_query_pool, label, loc)
}

vk_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
    impl := vk_query_set_get_impl(query_set, loc)
    add_ref(impl, loc)
}

vk_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
    if query_set == {} {
        return
    }
    device_impl := vk_device_get_impl(query_set.device, loc)
    if !dhm_is_valid(
        &device_impl.query_sets,
        unpack_handle(VK_Query_Set_Handle, query_set.handle),
    ) {
        return
    }
    impl := vk_query_set_get_impl(query_set, loc)
    if release_ref(impl) {
        vk_deferred_add_resource(
            &device_impl.deferred,
            &device_impl.submitter,
            VK_Deferred_Query_Set {
                pool = impl.vk_query_pool,
            },
        )
        vk_label_remove(&device_impl.labels, .Query_Set, pack_handle(impl.handle))
        memory_init_tracker_free(&impl.slots)
        shared_tracker_index_allocator_free(
            &device_impl.tracker_indices.query_sets,
            impl.tracker_index,
        )
        remove_handle_impl(&device_impl.query_sets, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// Recording
// -----------------------------------------------------------------------------

// Record a timestamp and count it as a write, so a later resolve in the same
// buffer copies a result rather than zero. Reset the slot immediately before the
// write, outside any pass (`vkCmdResetQueryPool` is illegal inside one): the
// beginning stamp goes into the transit buffer, the ending stamp after
// `vkCmdEndRenderPass`. Resetting a run ahead of a pass wipes earlier writes.
vk_record_write_timestamp :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    query_set: Query_Set,
    query_index: u32,
    stage: vk.PipelineStageFlags = {.BOTTOM_OF_PIPE},
    loc := #caller_location,
) {
    set_impl := vk_query_set_get_impl(query_set, loc)

    device_impl.fp.CmdResetQueryPool(cmdbuf.current_cmdbuf, set_impl.vk_query_pool, query_index, 1)

    device_impl.fp.CmdWriteTimestamp(
        cmdbuf.current_cmdbuf,
        stage,
        set_impl.vk_query_pool,
        query_index,
    )

    query_set_tracker_insert_single(&cmdbuf.tracker.query_sets, set_impl.tracker_index, query_set)
    tracker_record_query_write(&cmdbuf.tracker, query_set, query_index)
}

// Begin a query the pass ends later. Occlusion and pipeline statistics share the
// command; what the pool counts is the set's type.
vk_record_begin_query :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    set_impl := vk_query_set_get_impl(query_set, loc)
    device_impl.fp.CmdBeginQuery(cmdbuf.current_cmdbuf, set_impl.vk_query_pool, query_index, {})
}

// End an open query and count its result as written.
vk_record_end_query :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    set_impl := vk_query_set_get_impl(query_set, loc)
    device_impl.fp.CmdEndQuery(cmdbuf.current_cmdbuf, set_impl.vk_query_pool, query_index)

    query_set_tracker_insert_single(&cmdbuf.tracker.query_sets, set_impl.tracker_index, query_set)
    tracker_record_query_write(&cmdbuf.tracker, query_set, query_index)
}

// Whether `query_set`'s slot `index` is already in the use list. A pass may name
// a slot once, and a reset only has to happen once per slot anyway.
vk_query_use_append :: proc(
    uses: ^[dynamic]Query_Set_Write,
    query_set: Query_Set,
    index: u32,
) -> bool {
    for use in uses {
        if use.query_set == query_set && use.index == index {
            return false
        }
    }
    append(uses, Query_Set_Write{query_set = query_set, index = index})
    return true
}

// Encode the resets a pass's uses need, one `vkCmdResetQueryPool` per run of
// adjacent slots, just before `vkCmdBeginRenderPass` (resets are illegal inside
// a pass). Timestamp slots are skipped: `vk_record_write_timestamp` resets those
// immediately before writing them.
vk_encode_query_resets :: proc(
    device_impl: ^VK_Device_Impl,
    vk_cmdbuf: vk.CommandBuffer,
    uses: []Query_Set_Write,
    loc := #caller_location,
) {
    if len(uses) == 0 {
        return
    }

    // Bounded, stack-resident: query uses per pass are small, and this must not
    // allocate during a frame. Sort once by (set, index) so every reset run is
    // found by a single linear scan instead of repeated pair searches.
    ensure(len(uses) <= 64, "too many query uses in one pass", loc)
    sorted := [64]Query_Set_Write{}
    count := len(uses)
    copy(sorted[:count], uses)
    slice.sort_by(sorted[:count], proc(a, b: Query_Set_Write) -> bool {
        if a.query_set.handle != b.query_set.handle {
            return a.query_set.handle < b.query_set.handle
        }
        return a.index < b.index
    })

    i := 0
    for i < count {
        set := sorted[i].query_set
        first := sorted[i].index
        run := u32(1)
        i += 1
        for i < count && sorted[i].query_set == set && sorted[i].index == first + run {
            run += 1
            i += 1
        }

        set_impl := vk_query_set_get_impl(set, loc)
        if set_impl.type == .Timestamp {
            continue
        }
        device_impl.fp.CmdResetQueryPool(vk_cmdbuf, set_impl.vk_query_pool, first, run)
    }
}

// Copy a run of queries into the destination buffer, splitting it into runs of
// written and unwritten slots: written runs are copied from the pool, unwritten
// ones are zero-filled, which is what WebGPU resolves them to.
vk_record_resolve_query_set :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    cmd: Resolve_Query_Set_Cmd,
    loc := #caller_location,
) {
    set_impl := vk_query_set_get_impl(cmd.query_set, loc)
    buffer_impl := vk_buffer_get_impl(cmd.destination, loc)

    stride := u64(set_impl.results_per_query) * VK_QUERY_RESULT_SIZE
    if cmd.query_count == 0 || stride == 0 {
        return
    }

    query_set_tracker_insert_single(
        &cmdbuf.tracker.query_sets,
        set_impl.tracker_index,
        cmd.query_set,
    )

    end := cmd.start_query + cmd.query_count
    first := cmd.start_query
    for first < end {
        initialized :=
            memory_init_tracker_is_initialized(&set_impl.slots, first, first + 1) ||
            tracker_query_written(&cmdbuf.tracker, cmd.query_set, first)

        run_end := first + 1
        for run_end < end {
            next :=
                memory_init_tracker_is_initialized(&set_impl.slots, run_end, run_end + 1) ||
                tracker_query_written(&cmdbuf.tracker, cmd.query_set, run_end)
            if next != initialized {
                break
            }
            run_end += 1
        }

        offset := cmd.destination_offset + u64(first - cmd.start_query) * stride
        if initialized {
            device_impl.fp.CmdCopyQueryPoolResults(
                cmdbuf.current_cmdbuf,
                set_impl.vk_query_pool,
                first,
                run_end - first,
                buffer_impl.vk_buffer,
                vk.DeviceSize(offset),
                vk.DeviceSize(stride),
                {._64, .WAIT},
            )
        } else {
            device_impl.fp.CmdFillBuffer(
                cmdbuf.current_cmdbuf,
                buffer_impl.vk_buffer,
                vk.DeviceSize(offset),
                vk.DeviceSize(u64(run_end - first) * stride),
                0,
            )
        }

        first = run_end
    }
}

// Fold this command buffer's query writes into its sets' slot state, so a later
// submission resolving the same slots sees them as initialized.
vk_commit_query_writes :: proc(cmdbuf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    for write in cmdbuf.tracker.query_set_writes {
        set_impl := vk_query_set_get_impl(write.query_set, loc)
        memory_init_tracker_mark(&set_impl.slots, write.index, write.index + 1, true)
    }
}

// -----------------------------------------------------------------------------
// Conversions
// -----------------------------------------------------------------------------

vk_query_type :: proc(query_type: Query_Type) -> vk.QueryType {
    switch query_type {
    case .Occlusion:
        return .OCCLUSION
    case .Timestamp:
        return .TIMESTAMP
    case .Pipeline_Statistics:
        return .PIPELINE_STATISTICS
    }
    return .OCCLUSION
}

vk_query_pipeline_statistics :: proc(
    statistics: []Pipeline_Statistics_Types,
) -> vk.QueryPipelineStatisticFlags {
    flags: vk.QueryPipelineStatisticFlags
    for statistic in statistics {
        switch statistic {
        case .Vertex_Shader_Invocations:
            flags += {.VERTEX_SHADER_INVOCATIONS}
        case .Clipper_Invocations:
            flags += {.CLIPPING_INVOCATIONS}
        case .Clipper_Primitives_Out:
            flags += {.CLIPPING_PRIMITIVES}
        case .Fragment_Shader_Invocations:
            flags += {.FRAGMENT_SHADER_INVOCATIONS}
        case .Compute_Shader_Invocations:
            flags += {.COMPUTE_SHADER_INVOCATIONS}
        }
    }
    return flags
}
