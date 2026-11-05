#+build !js
package gpu

// Core
import "base:runtime"

// Vendor
import vk "vendor:vulkan"

// Command-recording helpers.
//
// These are the pieces shared by every verb: a resource transition (which the
// trackers hand over as abstract use sets), a buffer clear, and the lazy bind
// group flush that turns WebGPU's sticky `setBindGroup` into Vulkan descriptor
// set binds at draw time. Barrier encoding itself lives in `vk_state.odin`; this
// file only resolves handles and calls it.

vk_record_transition_buffer :: proc(
    device_impl: ^VK_Device_Impl,
    vk_cmdbuf: vk.CommandBuffer,
    buffer: Buffer,
    state_from: Buffer_Uses,
    state_to: Buffer_Uses,
    loc := #caller_location,
) {
    buffer_impl := vk_buffer_get_impl(buffer, loc)
    vk_command_buffer_barrier(
        device_impl,
        vk_cmdbuf,
        buffer_impl.vk_buffer,
        state_from,
        state_to,
        0,
        vk.DeviceSize(vk.WHOLE_SIZE),
        loc,
    )
}

vk_record_transition_texture :: proc(
    device_impl: ^VK_Device_Impl,
    vk_cmdbuf: vk.CommandBuffer,
    texture: Texture,
    selector: Maybe(Image_Subresource_Range),
    state_from: Texture_Uses,
    state_to: Texture_Uses,
    force_barrier: bool,
    loc := #caller_location,
) {
    texture_impl := vk_texture_get_impl(texture, loc)

    subresource_range: vk.ImageSubresourceRange
    if sel, has_sel := selector.?; has_sel {
        subresource_range = vk.ImageSubresourceRange {
            aspectMask     = vk_conv_to_image_aspect_flags(sel.aspect, texture_impl.format),
            baseMipLevel   = sel.base_mip_level,
            levelCount     = sel.mip_level_count,
            baseArrayLayer = sel.base_array_layer,
            layerCount     = sel.array_layer_count,
        }
    } else {
        subresource_range = vk.ImageSubresourceRange {
            aspectMask     = vk_conv_to_image_aspect_flags(.All, texture_impl.format),
            baseMipLevel   = 0,
            levelCount     = texture_impl.num_levels,
            baseArrayLayer = 0,
            layerCount     = texture_impl.num_layers,
        }
    }

    old_layout := vk_conv_texture_uses_to_image_layout(state_from)
    new_layout := vk_conv_texture_uses_to_image_layout(state_to)

    if old_layout != new_layout {
        vk_texture_transition_layout(
            device_impl,
            texture_impl,
            vk_cmdbuf,
            state_from,
            state_to,
            subresource_range,
            loc,
        )
    } else if force_barrier {
        // Same layout on both sides, but the caller still needs the barrier for
        // its execution/memory dependency.
        vk_texture_barrier(
            device_impl,
            texture_impl,
            vk_cmdbuf,
            new_layout,
            subresource_range,
            loc,
        )
    }
}

// `vkCmdFillBuffer` requires the offset and size to be multiples of 4.
vk_record_clear_buffer :: proc(
    device_impl: ^VK_Device_Impl,
    vk_cmdbuf: vk.CommandBuffer,
    cmd: Clear_Buffer_Cmd,
    loc := #caller_location,
) {
    dst_impl := vk_buffer_get_impl(cmd.dst, loc)

    assert(is_multiple_of(cmd.offset, 4), "Clear offset must be 4-byte aligned", loc)
    assert(is_multiple_of(cmd.size, 4), "Clear size must be 4-byte aligned", loc)
    ensure(
        cmd.size % 4 == 0 && cmd.offset + cmd.size <= dst_impl.size,
        "Clear range is out of bounds",
        loc,
    )

    vk.CmdFillBuffer(
        vk_cmdbuf,
        dst_impl.vk_buffer,
        vk.DeviceSize(cmd.offset),
        vk.DeviceSize(cmd.size),
        0,
    )
}

// Starts recording into the slot's pooled command buffer, which the submit
// context opened when the encoder was created.
vk_command_buffer_begin_recording :: proc(
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    ensure(cmdbuf.vk_cmdbuf != {}, "command buffer was not acquired", loc)
    clear(&cmdbuf.command_buffers)
    cmdbuf.did_prepare = false
    cmdbuf.current_cmdbuf = cmdbuf.vk_cmdbuf
}

// Ends the open command buffer and appends it to the submission sequence.
vk_command_buffer_close_recording :: proc(
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    if cmdbuf.current_cmdbuf == {} {
        return
    }
    device_impl := vk_device_get_impl(cmdbuf.device, loc)
    vk_check(device_impl.fp.EndCommandBuffer(cmdbuf.current_cmdbuf), loc = loc)
    append(&cmdbuf.command_buffers, cmdbuf.current_cmdbuf)
    cmdbuf.current_cmdbuf = {}
}

// Allocates and opens another primary buffer from the slot's pool. Used when a
// recording has to be split so barriers can be inserted before a pass.
vk_command_buffer_allocate_recording :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) -> vk.CommandBuffer {
    buffer: vk.CommandBuffer
    if len(cmdbuf.cmdbuf_pool) > 0 {
        buffer = pop(&cmdbuf.cmdbuf_pool)
        vk_check(device_impl.fp.ResetCommandBuffer(buffer, {}), loc = loc)
    } else {
        allocate_info := vk.CommandBufferAllocateInfo {
            sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool        = cmdbuf.vk_pool,
            level              = .PRIMARY,
            commandBufferCount = 1,
        }
        vk_check(
            device_impl.fp.AllocateCommandBuffers(device_impl.vk_device, &allocate_info, &buffer),
            loc = loc,
        )
    }

    begin_info := vk.CommandBufferBeginInfo {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = {.ONE_TIME_SUBMIT},
    }
    vk_check(device_impl.fp.BeginCommandBuffer(buffer, &begin_info), loc = loc)

    append(&cmdbuf.extra_cmdbufs, buffer)
    return buffer
}

// Closes the open buffer and opens a fresh one, leaving the closed buffer in the
// submission sequence before whatever is recorded next.
// Opens a buffer whose position in the submission sequence is not decided yet.
// A render pass uses this because the barriers it needs are only known at its
// end, and must be submitted *before* the pass even though they are recorded
// after it.
vk_command_buffer_begin_isolated :: proc(
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    vk_command_buffer_close_recording(cmdbuf, loc)
    device_impl := vk_device_get_impl(cmdbuf.device, loc)
    cmdbuf.isolated_cmdbuf = vk_command_buffer_allocate_recording(device_impl, cmdbuf, loc)
    cmdbuf.current_cmdbuf = cmdbuf.isolated_cmdbuf
}

// Closes the isolated buffer, lets `encode_transit` fill a buffer that is
// submitted immediately before it, and resumes recording in a fresh buffer.
// Transit is skipped when `encode_transit` records nothing.
// One bind group slot's state within a render pass.
//
// WebGPU treats `setBindGroup` as assignment of sticky state, not as an immediate
// binding: the group is validated against the bound pipeline at draw time, so a
// group may be set before any pipeline is bound. `vkCmdBindDescriptorSets` takes
// the `VkPipelineLayout` as a parameter and does not require a bound pipeline
// either, but we cannot know the layout until one is set, so we record the intent
// here and emit the descriptor set binding lazily.
VK_Bind_Group_Slot :: struct {
    group:           Bind_Group,
    dynamic_offsets: []u32,
    // The pipeline layout this group was last bound against. A group bound under
    // a different layout is not guaranteed to be compatible with the draws that
    // follow, so it is re-bound.
    //
    // Comparison is by handle, and this backend caches no pipeline layouts, so
    // two structurally identical layouts compare unequal and over-trigger a
    // re-bind. That is the safe direction: re-binding a compatible descriptor set
    // is always legal, whereas skipping one is a validation error.
    bound_layout:    Pipeline_Layout,
    assigned:        bool,
}

// Binds every layout slot not yet bound against `layout`. Called before each draw
// to ensure all groups are bound and rebind those bound under a different
// pipeline layout. The pass caches the bound pipeline's layout, so no handle is
// resolved here on the steady-state path.
vk_flush_bind_groups :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    slots: ^[MAX_BIND_GROUPS]VK_Bind_Group_Slot,
    layout: Pipeline_Layout,
    bind_point: vk.PipelineBindPoint = .GRAPHICS,
    loc: runtime.Source_Code_Location,
) {
    // Nothing to bind against. Reaching here means a draw or a pipeline bind with
    // no pipeline bound, which is invalid usage regardless.
    if layout == {} {
        return
    }

    layout_impl := vk_pipeline_layout_get_impl(layout, loc)
    set_count := layout_impl.bind_group_layout_count

    // Bind consecutive dirty slots with one call. Dynamic offsets are
    // concatenated in ascending set order, which is what
    // `vkCmdBindDescriptorSets` expects.
    set_descriptor_sets: [MAX_BIND_GROUPS]vk.DescriptorSet
    slot_index: u32
    for slot_index < set_count {
        slot := &slots[slot_index]

        // A slot this layout does not declare, or whose child layout is null or
        // empty, carries no bindings, so WebGPU never requires a group there.
        // The bit test avoids resolving the child layout on every draw.
        if (layout_impl.nonempty_slots_mask & (u32(1) << slot_index)) == 0 {
            // Not part of this layout. Keep the assignment (WebGPU semantics), but
            // Vulkan considers these sets disturbed by the layout change, so make
            // sure a later pipeline with more sets re-binds them.
            slot.bound_layout = {}
            slot_index += 1
            continue
        }

        if slot.bound_layout == layout {
            slot_index += 1
            continue
        }

        first := slot_index
        count: u32
        clear(&cmdbuf.bind_offsets_scratch)

        for slot_index < set_count {
            run_slot := &slots[slot_index]
            if (layout_impl.nonempty_slots_mask & (u32(1) << slot_index)) == 0 ||
               run_slot.bound_layout == layout {
                break
            }
            // The layout declares this set, so a draw without a group here is
            // invalid usage in WebGPU (missing bind group).
            assert(
                run_slot.assigned,
                "Missing bind group for a set declared by the pipeline layout",
                loc,
            )

            group_impl := vk_bind_group_get_impl(run_slot.group, loc)
            set_descriptor_sets[count] = group_impl.descriptor_set.raw
            append(&cmdbuf.bind_offsets_scratch, ..run_slot.dynamic_offsets)
            run_slot.bound_layout = layout
            count += 1
            slot_index += 1
        }

        vk.CmdBindDescriptorSets(
            cmdbuf.current_cmdbuf,
            bind_point,
            layout_impl.raw,
            first,
            count,
            &set_descriptor_sets[0],
            u32(len(cmdbuf.bind_offsets_scratch)),
            raw_data(cmdbuf.bind_offsets_scratch) if len(cmdbuf.bind_offsets_scratch) > 0 else nil,
        )
    }

    // Slots past this layout keep their assignment but are disturbed by the
    // layout change, so a later pipeline with more sets re-binds them.
    for i in int(set_count) ..< MAX_BIND_GROUPS {
        slots[i].bound_layout = {}
    }
}
