#+build !js
package gpu

// Core
import "base:runtime"
import "core:mem/virtual"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Command_Buffer_Handle :: distinct hm.Handle64

VK_Command_Buffer_Impl :: struct {
    // public base #subtype
    using base:          Command_Buffer_Impl,

    // Backend
    vk_cmdbuf:           vk.CommandBuffer,
    vk_cmdbuf_allocated: vk.CommandBuffer,
    vk_fence:            vk.Fence,
    vk_semaphore:        vk.Semaphore,
    submit_handle:       VK_Submit_Handle,

    // Per-recording scratch state
    temp_arena:          virtual.Arena,
}

VK_Command_Buffer_Wrapper :: struct {
    device:       Device,
    encoder:      Command_Encoder,
    buffer_index: u32,
    handle:       VK_Command_Buffer_Handle,
    ref:          Ref_Count_Type,
}

vk_command_buffer_init :: proc(
    buf: ^VK_Command_Buffer_Impl,
    device: Device,
    command_pool: vk.CommandPool,
    #any_int buffer_index: u32,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(device, loc)

    buf.device = device
    buf.submit_handle.buffer_index = buffer_index

    command_allocator_init(&buf.commands, allocator)

    tracker_init(
        &buf.tracker,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
        allocator)

    buf.vk_semaphore = vk_utils_create_semaphore(
        device_impl.fp, "Semaphore: submit-context", loc)
    buf.vk_fence = vk_utils_create_fence(
        device_impl.fp, "Fence: submit-context", signaled = false)

    cmdbuf_allocate_info := vk.CommandBufferAllocateInfo {
        sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
        commandPool        = command_pool,
        level              = .PRIMARY,
        commandBufferCount = 1,
    }

    vk_check(device_impl.fp.AllocateCommandBuffers(
        device_impl.vk_device, &cmdbuf_allocate_info, &buf.vk_cmdbuf_allocated))

    arena_err := virtual.arena_init_growing(&buf.temp_arena)
    assert(arena_err == nil)

    usage_scope_pool_init(&buf.scope_pool, allocator, loc)
    usage_scope_init(
        &buf.pass_scope,
        &buf.scope_pool,
        &device_impl.tracker_indices,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
        allocator,
        loc,
    )
    usage_scope_init(
        &buf.global_scope,
        &buf.scope_pool,
        &device_impl.tracker_indices,
        VK_BUFFER_ORDERED_USES_MASK,
        VK_TEXTURE_ORDERED_USES_MASK,
        allocator,
        loc,
    )
}

vk_command_buffer_uninit :: proc(buf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    usage_scope_uninit(&buf.global_scope)
    usage_scope_uninit(&buf.pass_scope)
    usage_scope_pool_uninit(&buf.scope_pool)
    device_impl := vk_device_get_impl(buf.device, loc)
    device_impl.fp.DestroyFence(device_impl.vk_device, buf.vk_fence, nil)
    device_impl.fp.DestroySemaphore(device_impl.vk_device, buf.vk_semaphore, nil)
    command_allocator_destroy(&buf.commands)
    tracker_uninit(&buf.tracker)
    virtual.arena_destroy(&buf.temp_arena) // also zeroes the arena
}

// Folds a finished usage scope into the command buffer's tracker and empties
// it, so the scope can be reused. Folding rather than overwriting matters: two
// scopes touching the same resource with conflicting uses produce a barrier
// between them, not a lost update.
vk_command_buffer_fold_usage_scope :: proc(
    buf: ^VK_Command_Buffer_Impl,
    scope: ^Usage_Scope,
    loc := #caller_location,
) {
    assert(buf != nil, loc = loc)
    assert(scope != nil, loc = loc)

    buffer_tracker_set_from_usage_scope(&buf.tracker.buffers,  &scope.buffers)
    texture_tracker_set_from_usage_scope(&buf.tracker.textures, &scope.textures)

    buffer_usage_scope_clear(&scope.buffers)
    texture_usage_scope_clear(&scope.textures)
}

// Transfers ownership of the bind-group reference list out of a completed
// command buffer. The caller must hold the submit-context lock; it must release
// the returned references after dropping that lock, because the last release
// can acquire the deferred-deletion lock.
vk_command_buffer_take_bind_group_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Bind_Group {
    return stateless_tracker_take(&buf.tracker.bind_groups)
}

vk_command_buffer_take_view_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Texture_View {
    return stateless_tracker_take(&buf.tracker.views)
}

vk_command_buffer_take_render_pipeline_refs :: proc(
    buf: ^VK_Command_Buffer_Impl,
) -> [dynamic]Render_Pipeline {
    return stateless_tracker_take(&buf.tracker.render_pipelines)
}

// Resets a completed submission or cancels an unsubmitted recording, leaving
// the command buffer ready for reuse. The caller must detach stateless resource
// refs and release them after unlocking the submit context. Once reset and
// tracker cleanup finish, the caller clears `vk_cmdbuf` under the context mutex.
vk_command_buffer_reset :: proc(buf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    device_impl := vk_device_get_impl(buf.device, loc)

    vk_check(device_impl.fp.ResetCommandBuffer(buf.vk_cmdbuf, {}), loc = loc)

    tracker_clear(&buf.tracker, loc)

    // Clear commands here, each recording appends,so otherwise the array grows
    // for the buffer's lifetime and scales with runtime.
    command_allocator_reset(&buf.commands, loc)

    // Per-recording scratch: free every block after the first, reset offset to 0.
    virtual.arena_check_temp(&buf.temp_arena, loc) // catches any Arena_Temp left open
    virtual.arena_free_all(&buf.temp_arena)

    // Both scopes are owned by this command buffer for its whole lifetime,
    // clear their tables in place rather than dropping to the pool.
    buffer_usage_scope_clear(&buf.pass_scope.buffers, loc)
    texture_usage_scope_clear(&buf.pass_scope.textures, loc)
    buffer_usage_scope_clear(&buf.global_scope.buffers, loc)
    texture_usage_scope_clear(&buf.global_scope.textures, loc)
}

@(require_results)
vk_command_buffer_get_public_impl :: #force_inline proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^Command_Buffer_Impl {
    return vk_command_buffer_get_impl(command_buffer, loc)
}

@(require_results)
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
vk_command_buffer_get_wrapper :: #force_inline proc "contextless" (
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> ^VK_Command_Buffer_Wrapper {
    device_impl := vk_device_get_impl(command_buffer.device, loc)
    return get_handle_impl(&device_impl.command_buffers, command_buffer.handle, loc)
}

vk_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    add_ref(wrapper)
}

vk_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wrapper := vk_command_buffer_get_wrapper(command_buffer, loc)
    if release_ref(wrapper) {
        device_impl := vk_device_get_impl(wrapper.device, loc)
        cmdbuf := &device_impl.submitter.buffers[wrapper.buffer_index]
        if cmdbuf.is_active {
            vk_submit_context_cancel_active(&device_impl.submitter, cmdbuf, loc)
        }
        // wrapper.encoder is weak, nothing to release here.
        remove_handle_impl(&device_impl.command_buffers, wrapper.handle)
    }
}

// -----------------------------------------------------------------------------
// @private procedures
// -----------------------------------------------------------------------------

vk_command_buffer_arena_allocator :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> runtime.Allocator {
    impl := vk_command_buffer_get_impl(command_buffer, loc)
    return virtual.arena_allocator(&impl.temp_arena)
}
