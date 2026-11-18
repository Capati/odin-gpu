#+build !js
package gpu

// Core
import "base:runtime"

// Vendor
import vk "vendor:vulkan"

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

    device_impl.fp.CmdFillBuffer(
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

// Opens a buffer whose submission position is not decided yet. A render pass
// uses it because its barriers are recorded after the pass but must be
// submitted before it.
vk_command_buffer_begin_isolated :: proc(
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    vk_command_buffer_close_recording(cmdbuf, loc)
    device_impl := vk_device_get_impl(cmdbuf.device, loc)
    cmdbuf.isolated_cmdbuf = vk_command_buffer_allocate_recording(device_impl, cmdbuf, loc)
    cmdbuf.current_cmdbuf = cmdbuf.isolated_cmdbuf
}

// One bind group slot's state within a render pass.
//
// `setBindGroup` assigns sticky state: the group is validated at draw time, so
// it may be set before a pipeline. The descriptor set is bound lazily once the
// pipeline layout is known.
VK_Bind_Group_Slot :: struct {
    group:            Bind_Group,
    dynamic_offsets:  []u32,
    // Pipeline layout this group was last bound against. Comparison is by
    // handle, so structurally equal layouts re-bind (the safe direction).
    bound_layout:     Pipeline_Layout,
    assigned:         bool,
    // Raw descriptor set, cached at assignment so the per-draw flush skips the
    // handle probe. Valid while the pass holds the binding's reference.
    descriptor_set:   vk.DescriptorSet,
    // Resolved impl, cached at assignment; draw-time validation reads it
    // instead of probing the handle map.
    group_impl:       ^VK_Bind_Group_Impl,
    // Layout this group was last validated against. Groups and layouts are
    // immutable, so a repeat verdict is skipped; reset when the group changes.
    validated_layout: Pipeline_Layout,
}

// Binds every slot not yet bound against `layout` and rebinds slots bound under
// a different layout. The resolved impl is passed in, so no handles are resolved
// in the steady state.
vk_flush_bind_groups :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    slots: ^[MAX_BIND_GROUPS]VK_Bind_Group_Slot,
    layout: Pipeline_Layout,
    layout_impl: ^VK_Pipeline_Layout_Impl,
    bind_point: vk.PipelineBindPoint = .GRAPHICS,
    loc: runtime.Source_Code_Location,
) {
    // Nothing to bind against. Reaching here means a draw or a pipeline bind with
    // no pipeline bound, which is invalid usage regardless.
    if layout == {} {
        return
    }

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

            set_descriptor_sets[count] = run_slot.descriptor_set
            append(&cmdbuf.bind_offsets_scratch, ..run_slot.dynamic_offsets)
            run_slot.bound_layout = layout
            count += 1
            slot_index += 1
        }

        device_impl.fp.CmdBindDescriptorSets(
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
