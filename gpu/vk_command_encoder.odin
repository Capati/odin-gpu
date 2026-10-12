#+build !js
package gpu

// Core
import "base:runtime"
import "core:mem/virtual"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Command_Encoder_Temp :: struct {
    marker:          []u8,
    buffer_barriers: [dynamic]vk.BufferMemoryBarrier,
    image_barriers:  [dynamic]vk.ImageMemoryBarrier,
}

VK_Command_Encoder_Handle :: distinct hm.Handle64

VK_Command_Encoder_Impl :: struct {
    using base: Command_Encoder_Impl,

    // Device sued to create this encoder.
    cmdbuf:     ^VK_Command_Buffer_Impl,
    // What kind of pass we are currently within (compute or render).
    bind_point: vk.PipelineBindPoint,
    // The internal handle to the command encoders pool.
    handle:     VK_Command_Encoder_Handle,
}

VK_Command_Encoder_Wrapper :: struct {
    device:     Device,
    slot_index: u32,
    handle:     VK_Command_Encoder_Handle,
    ref:        Ref_Count_Type,
}

vk_create_command_encoder :: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor,
    loc := #caller_location,
) -> Command_Encoder {
    impl := vk_device_get_impl(device, loc)

    cmdbuf := vk_submit_context_acquire(&impl.submitter, loc)

    encoder_impl, encoder_handle := add_impl(&impl.command_encoders, VK_Command_Encoder_Impl {
        device       = device,
        cmdbuf       = cmdbuf,
        is_encoding  = true,
        is_rendering = false,
        is_computing = false,
    })

    command_encoder := new_handle(Command_Encoder, device, encoder_handle)

    // wrapper.encoder is a weak back-reference for lookups only
    _, cmdbuf_handle := add_impl(&impl.command_buffers, VK_Command_Buffer_Wrapper {
        device       = device,
        encoder      = command_encoder,
        buffer_index = cmdbuf.submit_handle.buffer_index,
    })

    command_buffer := new_handle(Command_Buffer, device, cmdbuf_handle)
    encoder_impl.command_buffer = command_buffer // the one strong, owning ref

    return command_encoder
}

@(require_results)
vk_command_encoder_get_public_impl :: #force_inline proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^Command_Encoder_Impl {
    return vk_command_encoder_get_impl(command_encoder, loc)
}

@(require_results)
vk_command_encoder_get_impl :: #force_inline proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^VK_Command_Encoder_Impl {
    device_impl := vk_device_get_impl(command_encoder.device, loc)
    return get_handle_impl(&device_impl.command_encoders, command_encoder.handle, loc)
}

// Records a buffer's usage for a command encoded outside any pass, into the
// command buffer's global scope. A conflict here means the same buffer is being
// used two ways that cannot be ordered, which WebGPU rejects outright.
vk_command_encoder_track_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    uses: Buffer_Uses,
    conflict_message: string,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    err := buffer_usage_scope_merge_single(
        &impl.cmdbuf.global_scope.buffers,
        buffer_tracker_index(buffer, loc),
        buffer,
        uses,
        loc,
    )
    assert(err == nil, conflict_message, loc)
}

vk_command_encoder_begin_compute_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass {
    unimplemented(loc = loc)
}

vk_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    cmdbuf_impl := vk_command_buffer_get_impl(impl.command_buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    // Basic state validation
    assert(impl.is_encoding, "Command encoder is finished", loc)
    assert(impl.is_computing == false, "Command encoder is in compute state", loc)
    assert(impl.is_rendering == false, "Command encoder is already rendering", loc)

    desc := resolve_render_pass_descriptor(impl.device, descriptor, loc)

    scope_merge :: proc(
        scope: ^Usage_Scope,
        view: Texture_View,
        uses: Texture_Uses,
        loc := #caller_location,
    ) {
        view_impl := vk_texture_view_get_impl(view, loc)
        err := texture_usage_scope_merge_single(
            &scope.textures, view_impl.texture, view_impl.selector, uses)
        assert(err == nil, "texture usage conflict in render pass", loc)
    }

    scope := &cmdbuf_impl.pass_scope

    for &color in desc.color_attachments {
        vk_tracker_texture_view_add_ref(color.view, loc)
        stateless_tracker_insert_single(&cmdbuf_impl.tracker.views, color.view, loc)
        scope_merge(scope, color.view, {.Color_Target}, loc)
        if color.resolve_target != {} {
            vk_tracker_texture_view_add_ref(color.resolve_target, loc)
            stateless_tracker_insert_single(
                &cmdbuf_impl.tracker.views, color.resolve_target, loc)
            scope_merge(scope, color.resolve_target, {.Color_Target}, loc)
        }
    }

    if ds, ds_ok := desc.depth_stencil_attachment.?; ds_ok {
        vk_tracker_texture_view_add_ref(ds.view, loc)
        stateless_tracker_insert_single(&cmdbuf_impl.tracker.views, ds.view, loc)
        scope_merge(scope, ds.view, desc.ds_uses, loc)
    }

    cmd := command_allocator_allocate(&cmdbuf_impl.commands, Begin_Render_Pass_Cmd, loc)
    cmd.color_attachments = desc.color_attachments
    cmd.depth_stencil_attachment = desc.depth_stencil_attachment
    cmd.multiview_mask = desc.multiview_mask
    cmd.timestamp_writes = desc.timestamp_writes
    cmd.occlusion_query_set = desc.occlusion_query_set
    cmd.width = desc.width
    cmd.height = desc.height

    _, rpass_handle := add_impl(&device_impl.render_passes, VK_Render_Pass_Impl {
        device            = impl.device,
        encoder           = command_encoder,
        begin_cmd         = cmd,
        color_formats     = desc.color_formats,
        depth_stencil     = desc.depth_stencil,
        has_depth_stencil = desc.has_depth_stencil,
        sample_count      = desc.sample_count,
        is_rendering      = true,
    })

    impl.bind_point = .GRAPHICS
    impl.is_rendering = true

    rpass := new_handle(Render_Pass, impl.device, rpass_handle)
    vk_command_encoder_add_ref(command_encoder, loc)

    cmd.render_pass = rpass

    return rpass
}

vk_command_encoder_clear_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    assert(impl.is_encoding, "Command encoder is finished", loc)

    // A clear writes the destination, exactly as a copy into it would.
    vk_command_encoder_track_buffer(
        command_encoder, buffer, {.Copy_Dst},
        "buffer usage conflict in clear_buffer", loc)

    cmd := command_allocator_allocate(&impl.cmdbuf.commands, Clear_Buffer_Cmd, loc)
    cmd.dst    = buffer
    cmd.offset = offset
    cmd.size   = size
}

vk_command_encoder_copy_buffer_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    // device_impl := vk_device_get_impl(impl.device, loc)

    assert(impl.is_encoding, "Command encoder is finished", loc)

    // Recorded outside any pass, so this lands in the command buffer's global
    // scope. Source and destination are ordered, not concurrent, but they are
    // still distinct resources: a self-copy is a genuine Copy_Src/Copy_Dst
    // conflict and is rejected.
    vk_command_encoder_track_buffer(
        command_encoder, source, {.Copy_Src},
        "buffer usage conflict in copy_buffer_to_buffer", loc)
    vk_command_encoder_track_buffer(
        command_encoder, destination, {.Copy_Dst},
        "buffer usage conflict in copy_buffer_to_buffer", loc)

    copy := command_allocator_allocate(
        &impl.cmdbuf.commands, Copy_Buffer_To_Buffer_Cmd, loc)

    copy.src = source
    copy.src_offset = source_offset
    copy.dst = destination
    copy.dst_offset = destination_offset
    copy.size = size
}

vk_command_encoder_copy_buffer_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_copy_texture_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_copy_texture_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    assert(impl.is_encoding, "Command encoder is finished", loc)
    dst_impl := vk_texture_get_impl(destination.texture, loc)

    // Move source and destination into copy layouts with explicit barriers.
    // Derive them from this command buffer's tracker (it already holds the
    // render-pass usage); the device tracker still has last frame's state.
    record_copy_transition :: proc(
        encoder_impl: ^VK_Command_Encoder_Impl,
        encoder: Command_Encoder,
        texture: Texture,
        mip_level: u32,
        base_layer, layer_count: u32,
        aspect: Texture_Aspect,
        uses: Texture_Uses,
        loc := #caller_location,
    ) {
        selector := Texture_Selector {
            mips   = Range(u32){mip_level, mip_level + 1},
            layers = Range(u32){base_layer, base_layer + layer_count},
        }
        // Fold into the command-buffer tracker; the drain below turns the
        // pass-end -> copy step into an explicit barrier.
        texture_tracker_set_single(
            &encoder_impl.cmdbuf.tracker.textures,
            texture,
            selector,
            uses,
            loc,
        )
        transitions := texture_tracker_drain_transitions(
            &encoder_impl.cmdbuf.tracker.textures,
            command_encoder_arena_allocator(encoder, loc),
            loc,
        )
        for &transition in transitions {
            cmd := command_allocator_allocate(
                &encoder_impl.cmdbuf.commands, Transition_Texture_Cmd, loc)
            cmd.texture = texture
            cmd.selector = Image_Subresource_Range {
                aspect            = aspect,
                base_mip_level    = transition.selector.mips.start,
                mip_level_count   = transition.selector.mips.end - transition.selector.mips.start,
                base_array_layer  = transition.selector.layers.start,
                array_layer_count =
                    transition.selector.layers.end - transition.selector.layers.start,
            }
            // `from` is the pass-end state; don't re-read at record time.
            cmd.state_from    = transition.usage.from
            cmd.state_to      = transition.usage.to
            cmd.force_barrier = transition.usage.from != TEXTURE_USES_UNKNOWN
        }
    }

    // Layer coverage mirrors the record side: 3D packs depth slices into one
    // layer, 2D arrays copy base_layer..base_layer+count (see the layerCount
    // computation at the copy record site).
    is_3d := dst_impl.dimension == .D3
    src_layers := u32(1) if is_3d else copy_size.depth_or_array_layers
    dst_layers := u32(1) if is_3d else copy_size.depth_or_array_layers
    record_copy_transition(
        impl, command_encoder,
        source.texture, source.mip_level,
        is_3d ? u32(0) : source.origin.z, src_layers,
        source.aspect, {.Copy_Src}, loc)
    record_copy_transition(
        impl, command_encoder,
        destination.texture, destination.mip_level,
        is_3d ? u32(0) : destination.origin.z, dst_layers,
        destination.aspect, {.Copy_Dst}, loc)

    copy := command_allocator_allocate(
        &impl.cmdbuf.commands, Copy_Texture_To_Texture_Cmd, loc)
    copy.src = source
    copy.dst = destination
    copy.size = copy_size
}

vk_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    assert(impl.is_encoding, "Finishing encoder while not encoding", loc)
    assert(impl.is_computing == false, "Finishing encoder in compute state", loc)
    assert(impl.is_rendering == false, "Finishing encoder in render state", loc)

    impl.is_encoding = false

    // Fold the non-pass commands' usage in now. Passes have already folded
    // theirs at pass end, and every scope is closed by the time the encoder is.
    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)

    // New, independent owner: whoever receives this return value.
    vk_command_buffer_add_ref(impl.command_buffer, loc)

    return impl.command_buffer
}

vk_command_encoder_insert_debug_marker :: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_pop_debug_group :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_push_debug_group :: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_resolve_query_set :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_write_timestamp :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    add_ref(impl)
}

vk_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if release_ref(impl) {
        assert(!impl.is_computing, "Releasing encoder while in compute state", loc)
        assert(!impl.is_rendering, "Releasing encoder while in render state", loc)

        // Dropping an unfinished encoder abandons its unsubmitted command
        // buffer. Its final command-buffer release cancels and recycles the slot.
        impl.is_encoding = false

        vk_command_buffer_release(impl.command_buffer, loc) // drop the one strong ref

        device_impl := vk_device_get_impl(impl.device, loc)
        remove_handle_impl(&device_impl.command_encoders, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// @private procedures
// -----------------------------------------------------------------------------

vk_command_encoder_arena_allocator :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> runtime.Allocator {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    return virtual.arena_allocator(&impl.cmdbuf.temp_arena)
}

vk_command_encoder_transition_buffers :: proc(
    command_encoder: Command_Encoder,
    barriers: []Buffer_Barrier,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    // device_impl := vk_device_get_impl(impl.device, loc)

    assert(impl.is_encoding, "Command encoder is finished", loc)

    for &ba in barriers {
        cmd := command_allocator_allocate(&impl.cmdbuf.commands, Transition_Buffer_Cmd, loc)
        cmd.buffer = ba.buffer
        cmd.state_from = ba.usage.from
        cmd.state_to = ba.usage.to
    }
}
