#+build !js
package gpu

// Core
import intr "base:intrinsics"
import "base:runtime"
import hm "core:container/handle_map"
import "core:fmt"
import "core:mem/virtual"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Command_Buffer_Handle :: distinct hm.Handle64

VK_Command_Buffer_Impl :: struct {
    // public base #subtype
    using base: _Command_Buffer_Impl,

    // Backend
    vk_cmdbuf:           vk.CommandBuffer,
    vk_cmdbuf_allocated: vk.CommandBuffer,
    vk_pool:             vk.CommandPool,
    // The closed buffers of this recording, in submission order.
    command_buffers:     [dynamic]vk.CommandBuffer,
    // Buffers allocated by splits in the current recording.
    extra_cmdbufs:       [dynamic]vk.CommandBuffer,
    // Buffers retired by a previous recording, reset and reused instead of
    // freed/reallocated on every pass.
    cmdbuf_pool:         [dynamic]vk.CommandBuffer,
    // The buffer currently open for recording, or `{}` when all are closed.
    current_cmdbuf:      vk.CommandBuffer,
    // The open buffer while a pass is isolated from the submission sequence.
    isolated_cmdbuf:     vk.CommandBuffer,
    // Whether this recording's initial device-to-start barriers were emitted.
    did_prepare:         bool,
    // WebGPU invalidates a command buffer as soon as it is passed to submit,
    // whether that submission succeeds or is refused.
    submitted:           bool,
    vk_semaphore:        vk.Semaphore,
    submit_handle:       VK_Submit_Handle,
    // The value this recording's submission signals on the fence arm. Assigned
    // at submit, so concurrent encoders never share a value.
    submit_value:        u64,

    // Recording scratch reused across frames; sized once, cleared per use.
    scan_query_uses:          [dynamic]Query_Set_Write,
    initial_buffers:          [dynamic]Buffer_State_Transition,
    initial_textures:         [dynamic]Texture_State_Transition,
    image_barriers:           [dynamic]vk.ImageMemoryBarrier,
    buffer_barriers:          [dynamic]vk.BufferMemoryBarrier,
    pass_buffer_transitions:  [dynamic]Buffer_State_Transition,
    pass_texture_transitions: [dynamic]Texture_State_Transition,
    init_texture_ranges:      [dynamic]Texture_Init_Range,
    init_buffer_ranges:       [dynamic]Buffer_Init_Range,
    // Occlusion query slots already begun in the current render pass.
    pass_occlusion_used:      [dynamic]u32,
    // Dynamic offsets gathered for one multi-set `CmdBindDescriptorSets`.
    bind_offsets_scratch:     [dynamic]u32,

    // Per-recording scratch state
    temp_arena: virtual.Arena,
}

VK_Command_Buffer_Wrapper :: struct {
    device:       Device,
    encoder:      Command_Encoder,
    buffer_index: u32,
    // Slot generation this recording was acquired for. A command buffer handle
    // may outlive its submission; by the time it is released or submitted
    // again, the slot can belong to an unrelated recording.
    submit_id:    u32,
    handle:       VK_Command_Buffer_Handle,
    ref:          Ref_Count_Type,
}

@(private)
vk_command_buffer_init :: proc(
    buf: ^VK_Command_Buffer_Impl,
    device: Device,
    queue_family_index: u32,
    #any_int buffer_index: u32,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(device, loc)

    buf.device = device
    buf.submit_handle.buffer_index = buffer_index

    // One pool per slot: Vulkan requires a command pool not be used
    // concurrently with any command buffer allocated from it, so parallel
    // encoders cannot share one. This mirrors one recording context per pool.
    pool_info := vk.CommandPoolCreateInfo {
        sType            = .COMMAND_POOL_CREATE_INFO,
        flags            = {.RESET_COMMAND_BUFFER, .TRANSIENT},
        queueFamilyIndex = queue_family_index,
    }
    vk_check(
        device_impl.fp.CreateCommandPool(device_impl.vk_device, &pool_info, nil, &buf.vk_pool),
        loc = loc,
    )
    name_buffer: [64]u8
    vk_utils_set_debug_object_name(
        device_impl.fp,
        .COMMAND_POOL,
        buf.vk_pool,
        fmt.bprintf(name_buffer[:], "command pool slot %d", buffer_index),
        loc,
    )

    buf.command_buffers.allocator = allocator
    buf.extra_cmdbufs.allocator = allocator
    buf.cmdbuf_pool.allocator = allocator

    buf.scan_query_uses.allocator = allocator
    buf.initial_buffers.allocator = allocator
    buf.initial_textures.allocator = allocator
    buf.image_barriers.allocator = allocator
    buf.buffer_barriers.allocator = allocator
    buf.pass_buffer_transitions.allocator = allocator
    buf.pass_texture_transitions.allocator = allocator
    buf.init_texture_ranges.allocator = allocator
    buf.init_buffer_ranges.allocator = allocator
    buf.pass_occlusion_used.allocator = allocator
    buf.bind_offsets_scratch.allocator = allocator
    reserve(&buf.command_buffers, 4)
    reserve(&buf.extra_cmdbufs, 4)
    reserve(&buf.cmdbuf_pool, 4)
    reserve(&buf.scan_query_uses, 16)
    reserve(&buf.initial_buffers, 16)
    reserve(&buf.initial_textures, 16)
    reserve(&buf.image_barriers, 16)
    reserve(&buf.buffer_barriers, 16)
    reserve(&buf.pass_buffer_transitions, 16)
    reserve(&buf.pass_texture_transitions, 16)
    reserve(&buf.init_texture_ranges, 16)
    reserve(&buf.init_buffer_ranges, 16)
    reserve(&buf.pass_occlusion_used, 8)
    reserve(&buf.bind_offsets_scratch, 16)

    command_allocator_init(&buf.commands, allocator)

    tracker_init(
        &buf.tracker,
        allocator,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
    )

    buf.vk_semaphore = vk_utils_create_semaphore(device_impl.fp, "Semaphore: submit-context", loc)

    cmdbuf_allocate_info := vk.CommandBufferAllocateInfo {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = buf.vk_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }

    vk_check(
        device_impl.fp.AllocateCommandBuffers(
            device_impl.vk_device,
            &cmdbuf_allocate_info,
            &buf.vk_cmdbuf_allocated,
        ),
    )

    arena_err := virtual.arena_init_growing(&buf.temp_arena)
    ensure(arena_err == nil)

    usage_scope_pool_init(
        &buf.scope_pool,
        allocator,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
    )
    usage_scope_init(&buf.pass_scope, allocator)
    usage_scope_init(&buf.global_scope, allocator)
    usage_scope_set_ordered_uses_masks(
        &buf.pass_scope,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
    )
    usage_scope_set_ordered_uses_masks(
        &buf.global_scope,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
    )
}

@(private)
vk_command_buffer_uninit :: proc(buf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    usage_scope_free(&buf.global_scope)
    usage_scope_free(&buf.pass_scope)
    usage_scope_pool_free(&buf.scope_pool)
    device_impl := vk_device_get_impl(buf.device, loc)
    device_impl.fp.DestroySemaphore(device_impl.vk_device, buf.vk_semaphore, nil)
    // The pool is destroyed after every slot is uninitialized; drop the split
    // buffers explicitly so nothing dangles.
    if len(buf.extra_cmdbufs) > 0 {
        device_impl.fp.FreeCommandBuffers(
            device_impl.vk_device,
            buf.vk_pool,
            u32(len(buf.extra_cmdbufs)),
            raw_data(buf.extra_cmdbufs),
        )
    }
    if len(buf.cmdbuf_pool) > 0 {
        device_impl.fp.FreeCommandBuffers(
            device_impl.vk_device,
            buf.vk_pool,
            u32(len(buf.cmdbuf_pool)),
            raw_data(buf.cmdbuf_pool),
        )
    }
    delete(buf.command_buffers)
    delete(buf.extra_cmdbufs)
    delete(buf.cmdbuf_pool)
    delete(buf.scan_query_uses)
    delete(buf.initial_buffers)
    delete(buf.initial_textures)
    delete(buf.image_barriers)
    delete(buf.buffer_barriers)
    delete(buf.pass_buffer_transitions)
    delete(buf.pass_texture_transitions)
    delete(buf.init_texture_ranges)
    delete(buf.init_buffer_ranges)
    delete(buf.pass_occlusion_used)
    delete(buf.bind_offsets_scratch)
    command_allocator_destroy(&buf.commands)
    tracker_free(&buf.tracker)
    virtual.arena_destroy(&buf.temp_arena) // also zeroes the arena

    // Frees `vk_cmdbuf_allocated` with the pool.
    device_impl.fp.DestroyCommandPool(device_impl.vk_device, buf.vk_pool, nil)
    buf.vk_pool = {}
}

// Folds a finished usage scope into the command buffer's tracker and empties
// it, so the scope can be reused. Folding rather than overwriting matters: two
// scopes touching the same resource with conflicting uses produce a barrier
// between them, not a lost update.
@(private)
vk_command_buffer_fold_usage_scope :: proc(
    buf: ^VK_Command_Buffer_Impl,
    scope: ^Usage_Scope,
    loc := #caller_location,
) {
    ensure(buf != nil, loc = loc)
    ensure(scope != nil, loc = loc)

    buffer_tracker_set_from_usage_scope(&buf.tracker.buffers, &scope.buffers)
    texture_tracker_set_from_usage_scope(&buf.tracker.textures, &scope.textures)

    buffer_usage_scope_clear(&scope.buffers)
    texture_usage_scope_clear(&scope.textures)
}

// A command buffer may name a resource destroyed or mapped after encoding;
// WebGPU refuses the submission instead of running such work.
@(private)
vk_command_buffer_resources_live :: proc(
    buf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) -> bool {
    device := buf.device
    device_impl := vk_device_get_impl(device, loc)

    // Steady-state fast path: neither state is ever undone, so two zero
    // counters mean there is nothing to scan. A non-zero reading takes the full
    // path, which the CTS destroyed-resource and mapped-buffer tests cover.
    if intr.atomic_load_explicit(&device_impl.destroyed_resources, .Relaxed) == 0 &&
       intr.atomic_load_explicit(&device_impl.mapped_buffers, .Relaxed) == 0 {
        return true
    }

    live := true
    buffers := &buf.tracker.buffers.metadata
    buffer_it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&buffer_it, buffers)
    index: Tracker_Index
    for metadata_index_iterator_next(&buffer_it, &index) {
        buffer := resource_metadata_get(buffers, index)
        buffer_impl := vk_buffer_get_impl(buffer, loc)
        if buffer_impl.destroyed {
            gpu_report_validation_error(
                device,
                "submitted command buffer uses a destroyed buffer",
                loc,
            )
            live = false
        }
        if !vk_buffer_is_unmapped(buffer_impl) {
            gpu_report_validation_error(
                device,
                "submitted command buffer uses a mapped buffer",
                loc,
            )
            live = false
        }
    }
    textures := &buf.tracker.textures.metadata
    texture_it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&texture_it, textures)
    for metadata_index_iterator_next(&texture_it, &index) {
        texture := resource_metadata_get(textures, index).texture
        if vk_texture_get_impl(texture, loc).destroyed {
            gpu_report_validation_error(
                device,
                "submitted command buffer uses a destroyed texture",
                loc,
            )
            live = false
        }
    }
    for view in buf.tracker.views.resources {
        view_impl := vk_texture_view_get_impl(view, loc)
        if vk_texture_get_impl(view_impl.texture, loc).destroyed {
            gpu_report_validation_error(
                device,
                "submitted command buffer uses a destroyed texture",
                loc,
            )
            live = false
        }
    }
    for group in buf.tracker.bind_groups.resources {
        group_impl := vk_bind_group_get_impl(group, loc)
        for buffer_access in group_impl.buffers {
            if vk_buffer_get_impl(buffer_access.buffer, loc).destroyed {
                gpu_report_validation_error(
                    device,
                    "submitted command buffer uses a destroyed buffer",
                    loc,
                )
                live = false
            }
        }
        for view_access in group_impl.texture_views {
            view_impl := view_access.view_impl
            if view_impl == nil {
                view_impl = vk_texture_view_get_impl(view_access.texture_view, loc)
            }
            if vk_texture_get_impl(view_impl.texture, loc).destroyed {
                gpu_report_validation_error(
                    device,
                    "submitted command buffer uses a destroyed texture",
                    loc,
                )
                live = false
            }
        }
    }
    queries := &buf.tracker.query_sets.metadata
    query_it: Metadata_Index_Iterator(Query_Set)
    metadata_index_iterator_init(&query_it, queries)
    has_destroyed_query := false
    {
        sync.shared_guard(&device_impl.trackers_mtx)
        for metadata_index_iterator_next(&query_it, &index) {
            if resource_metadata_get(queries, index) in device_impl.destroyed_query_sets {
                has_destroyed_query = true
                break
            }
        }
    }
    if has_destroyed_query {
        gpu_report_validation_error(
            device,
            "submitted command buffer uses a destroyed query set",
            loc,
        )
        live = false
    }
    return live
}

// Takes ownership of the bind-group refs. Caller holds the submit-context lock
// and releases them after dropping it: the last release can take the
// deferred-deletion lock.
@(require_results)
@(private)
vk_command_buffer_take_bind_group_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Bind_Group {
    return stateless_tracker_take(&buf.tracker.bind_groups)
}

@(require_results)
@(private)
vk_command_buffer_take_view_refs :: proc(buf: ^VK_Command_Buffer_Impl) -> [dynamic]Texture_View {
    return stateless_tracker_take(&buf.tracker.views)
}

@(require_results)
@(private)
vk_command_buffer_take_render_pipeline_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Render_Pipeline {
    return stateless_tracker_take(&buf.tracker.render_pipelines)
}

// One reference on a render bundle stands for every group, pipeline and buffer it
// recorded: the bundle took those refs at encode and holds them until release.
@(require_results)
@(private)
vk_command_buffer_take_bundle_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Render_Bundle {
    return stateless_tracker_take(&buf.tracker.bundles)
}

// Resets a completed submission or cancels an unsubmitted recording, leaving
// the command buffer ready for reuse. The caller must detach stateless resource
// refs and release them after unlocking the submit context. Once reset and
// tracker cleanup finish, the caller clears `vk_cmdbuf` under the context mutex.
@(private)
vk_command_buffer_reset :: proc(buf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    device_impl := vk_device_get_impl(buf.device, loc)

    vk_check(device_impl.fp.ResetCommandBuffer(buf.vk_cmdbuf, {}), loc = loc)

    // Split buffers are no longer referenced by a pending submission. Keep
    // them for the next recording instead of freeing and reallocating every
    // pass; `vk_command_buffer_allocate_recording` resets one before reuse.
    if len(buf.extra_cmdbufs) > 0 {
        append(&buf.cmdbuf_pool, ..buf.extra_cmdbufs[:])
        clear(&buf.extra_cmdbufs)
    }
    clear(&buf.command_buffers)
    buf.current_cmdbuf = {}
    buf.did_prepare = false
    clear(&buf.scan_query_uses)
    clear(&buf.initial_buffers)
    clear(&buf.initial_textures)
    buf.submitted = false
    clear(&buf.image_barriers)
    clear(&buf.buffer_barriers)
    clear(&buf.pass_buffer_transitions)
    clear(&buf.pass_texture_transitions)

    tracker_clear(&buf.tracker)

    // Clear commands here, each recording appends,so otherwise the array grows
    // for the buffer's lifetime and scales with runtime.
    command_allocator_reset(&buf.commands, loc)

    // Per-recording scratch: free every block after the first, reset offset to 0.
    virtual.arena_check_temp(&buf.temp_arena, loc) // catches any Arena_Temp left open
    virtual.arena_free_all(&buf.temp_arena)

    // Both scopes are owned by this command buffer for its whole lifetime,
    // clear their tables in place rather than dropping to the pool.
    buffer_usage_scope_clear(&buf.pass_scope.buffers)
    texture_usage_scope_clear(&buf.pass_scope.textures)
    buffer_usage_scope_clear(&buf.global_scope.buffers)
    texture_usage_scope_clear(&buf.global_scope.textures)
}

@(require_results)
@(private)
vk_command_buffer_get_public_impl :: #force_inline proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^_Command_Buffer_Impl {
    return vk_command_buffer_get_impl(command_buffer, loc)
}

@(require_results)
@(private)
vk_command_buffer_get_impl :: #force_inline proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^VK_Command_Buffer_Impl {
    device_impl := vk_device_get_impl(command_buffer.device, loc)
    wrapper := get_handle_impl(&device_impl.command_buffers, command_buffer.handle, loc)
    cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
    return cmdbuf
}

@(require_results)
@(private = "file")
vk_command_buffer_get_wrapper :: #force_inline proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^VK_Command_Buffer_Wrapper {
    device_impl := vk_device_get_impl(command_buffer.device, loc)
    return get_handle_impl(&device_impl.command_buffers, command_buffer.handle, loc)
}

@(private)
vk_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    device_impl := vk_device_get_impl(wrapper.device, loc)
    return vk_label_get(&device_impl.labels, .Command_Buffer, pack_handle(wrapper.handle))
}

@(private)
vk_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    device_impl := vk_device_get_impl(wrapper.device, loc)
    vk_label_set(&device_impl.labels, .Command_Buffer, pack_handle(wrapper.handle), label)
    cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
    // `vk_cmdbuf` is only live during recording; the allocation outlives it.
    vk_utils_set_debug_object_name(
        device_impl.fp,
        .COMMAND_BUFFER,
        uintptr(cmdbuf.vk_cmdbuf_allocated),
        label,
        loc,
    )
}

@(private)
vk_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    add_ref(wrapper)
}

// True when the wrapper still names the slot generation it was acquired for.
// Once the slot has been purged and reused, an old handle must not cancel,
// submit, or inspect the new recording.
@(private)
vk_command_buffer_is_current :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> bool {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    device_impl := vk_device_get_impl(wrapper.device, loc)
    sync.shared_guard(&device_impl.submitter.mtx)
    cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
    // `vk_cmdbuf == {}` means the slot was purged after its submission; the
    // generation may still match until the slot is acquired again, but the
    // command buffer has already been submitted.
    return cmdbuf.vk_cmdbuf != {} && cmdbuf.submit_handle.submit_id == wrapper.submit_id
}

@(private)
vk_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    if release_ref(wrapper) {
        device_impl := vk_device_get_impl(wrapper.device, loc)
        cancel := false
        {
            sync.shared_guard(&device_impl.submitter.mtx)
            cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
            cancel = cmdbuf.is_active && cmdbuf.submit_handle.submit_id == wrapper.submit_id
        }
        if cancel {
            cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
            vk_submit_context_cancel_active(&device_impl.submitter, cmdbuf, loc)
        }
        // wrapper.encoder is weak, nothing to release here.
        vk_label_remove(&device_impl.labels, .Command_Buffer, pack_handle(wrapper.handle))
        remove_handle_impl(&device_impl.command_buffers, wrapper.handle)
    }
}

// -----------------------------------------------------------------------------
// @private procedures
// -----------------------------------------------------------------------------

@(private)
vk_command_buffer_arena_allocator :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> runtime.Allocator {
    impl := vk_command_buffer_get_impl(command_buffer, loc)
    return virtual.arena_allocator(&impl.temp_arena)
}
