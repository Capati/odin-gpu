#+build !js
package gpu

// Core
import "core:mem/virtual"
import "core:slice"
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

    src_stage, src_access :=
        vk_conv_buffer_uses_to_barrier(state_from, device_impl.queue_flags)
    dst_stage, dst_access :=
        vk_conv_buffer_uses_to_barrier(state_to, device_impl.queue_flags)

    // Note: this is done so that we never end up with empty stage flags
    if src_stage == {} { src_stage = {.TOP_OF_PIPE} }
    if dst_stage == {} { dst_stage = {.BOTTOM_OF_PIPE} }

    barrier := vk.BufferMemoryBarrier {
        sType               = .BUFFER_MEMORY_BARRIER,
        srcAccessMask       = src_access,
        dstAccessMask       = dst_access,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        buffer              = buffer_impl.vk_buffer,
        offset              = 0,
        size                = vk.DeviceSize(vk.WHOLE_SIZE),
    }

    device_impl.fp.CmdPipelineBarrier(
        commandBuffer            = vk_cmdbuf,
        srcStageMask             = src_stage,
        dstStageMask             = dst_stage,
        dependencyFlags          = {},
        memoryBarrierCount       = 0,
        pMemoryBarriers          = nil,
        bufferMemoryBarrierCount = 1,
        pBufferMemoryBarriers    = &barrier,
        imageMemoryBarrierCount  = 0,
        pImageMemoryBarriers     = nil,
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

    old_layout := vk_conv_texture_uses_to_image_layout(state_from, texture_impl.format)
    new_layout := vk_conv_texture_uses_to_image_layout(state_to, texture_impl.format)

    if old_layout != new_layout {
        vk_texture_transition_layout(
            device_impl,
            texture_impl,
            vk_cmdbuf,
            state_from,
            state_to,
            subresource_range,
            loc)
    } else if force_barrier {
        // Same layout on both sides, but the caller still needs the barrier for
        // its execution/memory dependency.
        vk_texture_barrier(
            device_impl,
            texture_impl,
            vk_cmdbuf,
            new_layout,
            subresource_range,
            loc)
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
    assert(cmd.size % 4 == 0 && cmd.offset + cmd.size <= dst_impl.size,
        "Clear range is out of bounds", loc)

    vk.CmdFillBuffer(
        vk_cmdbuf,
        dst_impl.vk_buffer,
        vk.DeviceSize(cmd.offset),
        vk.DeviceSize(cmd.size),
        0,
    )
}

// One bind group slot's state within a render pass.
//
// WebGPU treats `setBindGroup` as assignment of sticky state, not as an
// immediate binding: the group is validated against the bound pipeline at draw
// time, so a group may be set before any pipeline is bound. `vkCmdBindDescriptorSets`
// takes the `VkPipelineLayout` as a parameter and does not require a bound
// pipeline either, but we cannot know the layout until one is set, so we record
// the intent here and emit the descriptor set binding lazily.
VK_Bind_Group_Slot :: struct {
    group:          Bind_Group,
    dynamic_offsets: []u32,
    // The pipeline layout this group was last bound against. A group bound
    // under a different layout is not guaranteed to be compatible with the
    // draws that follow, so it is re-bound.
    //
    // Comparison is by handle, and this backend caches no pipeline layouts, so
    // two structurally identical layouts compare unequal and over-trigger a
    // re-bind. That is the safe direction: re-binding a compatible descriptor
    // set is always legal, whereas skipping one is a validation error.
    bound_layout:   Pipeline_Layout,
    assigned:       bool,
}

// The layout descriptor sets have to be bound against: that of the pipeline
// bound in this pass, or an empty handle if none is bound yet. A pipeline bound
// but never drawn with never reaches a flush, so resolving lazily costs nothing
// on that path.
@(private = "file")
vk_active_pipeline_layout :: proc(
    pipeline: Render_Pipeline,
    loc: runtime.Source_Code_Location,
) -> Pipeline_Layout {
    if pipeline == {} {
        return {}
    }
    return vk_render_pipeline_get_impl(pipeline, loc).layout
}

// Binds every layout slot not yet bound against `layout`. Called before each
// draw to ensure all groups are bound and rebind those bound under a different
// pipeline layout.
@(private = "file")
vk_flush_bind_groups :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    slots: ^[MAX_BIND_GROUPS]VK_Bind_Group_Slot,
    layout: Pipeline_Layout,
    loc: runtime.Source_Code_Location,
) {
    // Nothing to bind against. Reaching here means a draw or a pipeline bind
    // with no pipeline bound, which is invalid usage regardless.
    if layout == {} {
        return
    }

    layout_impl := vk_pipeline_layout_get_impl(layout, loc)
    set_count := len(layout_impl.bind_group_layouts) // use whatever your impl stores

    for &slot, i in slots {
        if i >= set_count {
            // Not part of this layout. Keep the assignment (WebGPU semantics), but
            // Vulkan considers these sets disturbed by the layout change, so make
            // sure a later pipeline with more sets re-binds them.
            slot.bound_layout = {}
            continue
        }

        // The layout declares this set, so a draw without a group here is
        // invalid usage in WebGPU (missing bind group).
        assert(slot.assigned, "Missing bind group for a set declared by the pipeline layout", loc)

        if slot.bound_layout == layout {
            continue
        }

        group_impl := vk_bind_group_get_impl(slot.group, loc)
        vk.CmdBindDescriptorSets(
            cmdbuf.vk_cmdbuf, .GRAPHICS, layout_impl.raw,
            u32(i), 1, &group_impl.descriptor_set.raw,
            u32(len(slot.dynamic_offsets)),
            raw_data(slot.dynamic_offsets) if len(slot.dynamic_offsets) > 0 else nil,
        )
        slot.bound_layout = layout
    }
}

vk_record_render_pass :: proc(
    device: Device,
    cmdbuf: ^VK_Command_Buffer_Impl,
    rpass: ^Begin_Render_Pass_Cmd,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(device, loc)

    rp_key: VK_Render_Pass_Key
    fb_query: VK_Framebuffer_Cache

    vk_clear_values:  [dynamic;MAX_ATTACHMENT_COUNT]vk.ClearValue
    present_textures: [dynamic;MAX_ATTACHMENT_COUNT]Texture

    for &color, i in rpass.color_attachments {
        assert(color.view != {}, "Invalid color attachment view", rpass.loc)

        view_impl    := vk_texture_view_get_impl(color.view, rpass.loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, rpass.loc)

        if texture_impl.is_swapchain {
            append(&present_textures, view_impl.texture)
        }

        // All attachments in a render pass must share a sample count.
        assert(i == 0 || rp_key.sample_count == texture_impl.sample_count,
            "All color attachments must have the same sample count", rpass.loc)
        rp_key.sample_count = texture_impl.sample_count

        // A swapchain image must be left ready for presentation, and the render
        // pass is the only place that knows the pass has ended, so it performs
        // the transition itself.
        color_final_layout : vk.ImageLayout = texture_impl.is_swapchain \
            ? .PRESENT_SRC_KHR : .COLOR_ATTACHMENT_OPTIMAL

        rp_key.colors[i].base = {
            format       = texture_impl.vk_image_format,
            layout       = .COLOR_ATTACHMENT_OPTIMAL,
            final_layout = color_final_layout,
            load_op      = color.ops.load,
            store_op     = color.ops.store,
        }

        append(&vk_clear_values, vk.ClearValue{
            color = {
                float32 = {
                    f32(color.ops.clear_value.r),
                    f32(color.ops.clear_value.g),
                    f32(color.ops.clear_value.b),
                    f32(color.ops.clear_value.a),
                },
            },
        })

        vk_framebuffer_query_add_attachment(&fb_query, color.view, view_impl.vk_image_view)

        has_resolve := color.resolve_target != {}
        if has_resolve {
            resolve_view_impl    := vk_texture_view_get_impl(color.resolve_target, rpass.loc)
            resolve_texture_impl := vk_texture_get_impl(resolve_view_impl.texture, rpass.loc)

            assert(
                resolve_texture_impl.vk_extent.width  == rpass.width &&
                resolve_texture_impl.vk_extent.height == rpass.height,
                "Resolve target must match framebuffer dimensions", rpass.loc)
            assert(resolve_texture_impl.vk_samples == {._1},
                "Resolve target must be single-sampled", rpass.loc)

            if resolve_texture_impl.is_swapchain {
                append(&present_textures, resolve_view_impl.texture)
            }

            // A swapchain resolve target still has to end presentable,
            // otherwise the resolved image is never handed to the display.
            resolve_final_layout : vk.ImageLayout = resolve_texture_impl.is_swapchain \
                ? .PRESENT_SRC_KHR : .COLOR_ATTACHMENT_OPTIMAL

            rp_key.colors[i].resolve = {
                format       = resolve_texture_impl.vk_image_format,
                layout       = .COLOR_ATTACHMENT_OPTIMAL,
                final_layout = resolve_final_layout,
                load_op      = color.ops.load,
                store_op     = color.ops.store,
            }

            // Dummy clear value to match 1:1
            append(&vk_clear_values, vk.ClearValue{})

            vk_framebuffer_query_add_attachment(
                &fb_query, color.resolve_target, resolve_view_impl.vk_image_view)
        }
    }

    // Depth-stencil attachment
    has_depth:   bool
    has_stencil: bool
    depth_clear: vk.ClearValue

    if ds, has_ds := rpass.depth_stencil_attachment.?; has_ds {
        assert(ds.view != {}, "Invalid depth attachment view", rpass.loc)

        ds_view_impl    := vk_texture_view_get_impl(ds.view, rpass.loc)
        ds_texture_impl := vk_texture_get_impl(ds_view_impl.texture, rpass.loc)
        has_depth   = texture_format_has_depth_aspect(ds_texture_impl.format)
        has_stencil = texture_format_has_stencil_aspect(ds_texture_impl.format)

        depth_read_only   := ds.depth_read_only
        stencil_read_only := ds.stencil_read_only

        aspect_mask: vk.ImageAspectFlags
        if has_depth   { aspect_mask += {.DEPTH} }
        if has_stencil { aspect_mask += {.STENCIL} }

        ds_layout: vk.ImageLayout
        switch {
        case depth_read_only && stencil_read_only:
            ds_layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL
        case depth_read_only:
            ds_layout = .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL
        case stencil_read_only:
            ds_layout = .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL
        case:
            ds_layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        }

        if ds_texture_impl.is_swapchain {
            append(&present_textures, ds_view_impl.texture)
        }

        depth_load_op    := Load_Op.Dont_Care
        depth_store_op   := Store_Op.Discard
        stencil_load_op  := Load_Op.Dont_Care
        stencil_store_op := Store_Op.Discard

        if has_depth {
            depth_load_op  = depth_read_only   ? .Load    : ds.depth_ops.load
            depth_store_op = depth_read_only   ? .Discard : ds.depth_ops.store
        }
        if has_stencil {
            stencil_load_op  = stencil_read_only ? .Load    : ds.stencil_ops.load
            stencil_store_op = stencil_read_only ? .Discard : ds.stencil_ops.store
        }

        rp_key.depth_stencil = {
            base = {
                format   = ds_texture_impl.vk_image_format,
                layout   = ds_layout,
                final_layout = ds_texture_impl.is_swapchain ? .PRESENT_SRC_KHR : ds_layout,
                load_op  = depth_load_op,
                store_op = depth_store_op,
            },
            stencil_load_op  = stencil_load_op,
            stencil_store_op = stencil_store_op,
        }
        rp_key.depth_read_only   = depth_read_only
        rp_key.stencil_read_only = stencil_read_only

        // If there are no color attachments, the sample count has to come from
        // the DS attachment.
        if len(rpass.color_attachments) == 0 {
            rp_key.sample_count = ds_texture_impl.sample_count
        } else {
            assert(rp_key.sample_count == ds_texture_impl.sample_count,
                "Depth-stencil attachment sample count must match color attachments", rpass.loc)
        }

        depth_clear.depthStencil = {
            depth   = has_depth   && !ds.depth_read_only   ? ds.depth_ops.clear_value   : 0.0,
            stencil = has_stencil && !ds.stencil_read_only ? ds.stencil_ops.clear_value : 0,
        }
        append(&vk_clear_values, depth_clear)

        vk_framebuffer_query_add_attachment(&fb_query, ds.view, ds_view_impl.vk_image_view)
    }

    vk_render_pass := vk_render_pass_cache_get_or_create(device_impl, rp_key, rpass.loc)

    vk_framebuffer_query_set_extent(
        &fb_query, rpass.width, rpass.height)

    vk_framebuffer := vk_framebuffer_cache_get_or_create(
        device_impl, &fb_query, vk_render_pass, rpass.width, rpass.height, rpass.loc)

    begin_info := vk.RenderPassBeginInfo{
        sType           = .RENDER_PASS_BEGIN_INFO,
        renderPass      = vk_render_pass,
        framebuffer     = vk_framebuffer,
        renderArea      = {offset = {0, 0}, extent = {rpass.width, rpass.height}},
        clearValueCount = u32(len(vk_clear_values)),
        pClearValues    = raw_data(vk_clear_values[:]),
    }

    // Emit transitions computed at `render_pass_end` before recording the pass.
    // They cover its full usage scope and transition resources from the state
    // left by previous scopes to the state required by this pass.
    for &tr in rpass.buffer_transitions {
        if tr.usage.from == {} || tr.usage.from == tr.usage.to {
            continue
        }
        buffer := resource_metadata_get_unchecked(&cmdbuf.tracker.buffers.metadata, tr.id)
        vk_record_transition_buffer(
            device_impl,
            cmdbuf.vk_cmdbuf,
            buffer,
            tr.usage.from,
            tr.usage.to,
            rpass.loc)
    }

    for &tr in rpass.texture_transitions {
        if tr.usage.from == TEXTURE_USES_UNKNOWN ||
           tr.usage.from == {} ||
           tr.usage.from == tr.usage.to {
            continue
        }
        texture := resource_metadata_get_unchecked(&cmdbuf.tracker.textures.metadata, tr.id)
        vk_record_transition_texture(
            device_impl,
            cmdbuf.vk_cmdbuf,
            texture,
            Image_Subresource_Range {
                aspect            = .All,
                base_mip_level    = tr.selector.mips.start,
                mip_level_count   = tr.selector.mips.end - tr.selector.mips.start,
                base_array_layer  = tr.selector.layers.start,
                array_layer_count = tr.selector.layers.end - tr.selector.layers.start,
            },
            tr.usage.from,
            tr.usage.to,
            false,
            rpass.loc)
    }

    device_impl.fp.CmdBeginRenderPass(cmdbuf.vk_cmdbuf, &begin_info, .INLINE)

    // Call default commands for the dynamic state
    device_impl.fp.CmdSetLineWidth(cmdbuf.vk_cmdbuf, 1.0)
    device_impl.fp.CmdSetDepthBounds(cmdbuf.vk_cmdbuf, 0.0, 1.0)
    device_impl.fp.CmdSetStencilReference(cmdbuf.vk_cmdbuf, {.FRONT, .BACK}, 0)
    device_impl.fp.CmdSetBlendConstants(cmdbuf.vk_cmdbuf, &{ 0.0, 0.0, 0.0, 0.0 })
    device_impl.fp.CmdSetViewport(cmdbuf.vk_cmdbuf, 0, 1, &vk.Viewport{
        x        = 0.0,
        y        = f32(rpass.height),
        width    = f32(rpass.width),
        height   = -f32(rpass.height),
        minDepth = 0.0,
        maxDepth = 1.0,
    })
    device_impl.fp.CmdSetScissor(cmdbuf.vk_cmdbuf, 0, 1, &vk.Rect2D{
        offset = {0, 0},
        extent = {rpass.width, rpass.height},
    })

    active_pipeline: Render_Pipeline

    // Bind groups assigned in this pass, keyed by slot. They are flushed
    // against the active pipeline's layout immediately before each draw rather
    // than bound where recorded, so `setBindGroup` before `setPipeline` works.
    bind_group_slots: [MAX_BIND_GROUPS]VK_Bind_Group_Slot

    LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
        #partial switch &cmd in curr {
        case Set_Bind_Group_Cmd:
            assert(cmd.index < MAX_BIND_GROUPS, "Bind group index out of range", cmd.loc)

            // Only record the assignment. The descriptor set binding is emitted
            // by `vk_flush_bind_groups` once a pipeline layout is known, so
            // ordering against `setPipeline` does not matter here.
            slot := &bind_group_slots[cmd.index]

            // Re-assigning an identical group changes nothing.
            if slot.assigned &&
               slot.group == cmd.bind_group &&
               len(slot.dynamic_offsets) == len(cmd.dynamic_offsets) &&
               (len(cmd.dynamic_offsets) == 0 ||
                slice.equal(slot.dynamic_offsets, cmd.dynamic_offsets)) {
                break
            }

            slot.group = cmd.bind_group
            slot.dynamic_offsets = cmd.dynamic_offsets
            slot.assigned = true
            // Whatever is bound at this slot now is a different group, so the
            // sticky Vulkan descriptor set is stale and has to be re-bound.
            slot.bound_layout = {}

        case Set_Render_Pipeline_Cmd:
            pipeline_impl := vk_render_pipeline_get_impl(cmd.pipeline, cmd.loc)
            device_impl.fp.CmdBindPipeline(
                cmdbuf.vk_cmdbuf, .GRAPHICS, pipeline_impl.vk_pipeline)
            active_pipeline = cmd.pipeline

            // No flush here: binding an unused pipeline must not rebind
            // descriptor sets left by the last draw against an incompatible
            // layout. The pre-draw flush handles rebinding when the layout
            // actually matters.

        case Set_Index_Buffer_Cmd:
            buffer_impl := vk_buffer_get_impl(cmd.buffer, cmd.loc)

            vk_offset := vk.DeviceSize(cmd.offset)
            vk_size: vk.DeviceSize

            if cmd.size == WHOLE_SIZE {
                vk_size = buffer_impl.vk_size - vk_offset
            } else {
                vk_size = vk.DeviceSize(cmd.size)
            }

            device_impl.fp.CmdBindIndexBuffer(
                cmdbuf.vk_cmdbuf,
                buffer_impl.vk_buffer,
                vk_offset,
                vk_conv_to_index_type(cmd.index_format),
            )

        case Set_Vertex_Buffer_Cmd:
            buffer_impl := vk_buffer_get_impl(cmd.buffer, cmd.loc)

            vk_offset := vk.DeviceSize(cmd.offset)
            vk_size: vk.DeviceSize

            if cmd.size == WHOLE_SIZE {
                vk_size = buffer_impl.vk_size - vk_offset
            } else {
                vk_size = vk.DeviceSize(cmd.size)
            }

            assert(vk_offset + vk_size <= buffer_impl.vk_size,
                "Vertex buffer offset + size exceeds requested buffer size", cmd.loc)

            device_impl.fp.CmdBindVertexBuffers(
                cmdbuf.vk_cmdbuf, cmd.slot, 1, &buffer_impl.vk_buffer, &vk_offset)

        case Set_Blend_Constant_Cmd:
            color := [4]f32{
                f32(cmd.color.r),
                f32(cmd.color.g),
                f32(cmd.color.b),
                f32(cmd.color.a),
            }
            device_impl.fp.CmdSetBlendConstants(cmdbuf.vk_cmdbuf, &color)

        case Set_Stencil_Reference_Cmd:
            device_impl.fp.CmdSetStencilReference(
                cmdbuf.vk_cmdbuf, {.FRONT, .BACK}, cmd.reference)

        case Set_Viewport_Cmd:
            // https://www.saschawillems.de/blog/2019/03/29/flipping-the-vulkan-viewport/
            device_impl.fp.CmdSetViewport(cmdbuf.vk_cmdbuf, 0, 1, &vk.Viewport{
                x        = cmd.x,
                y        = f32(cmd.height),
                width    = f32(cmd.width),
                height   = -f32(cmd.height),
                minDepth = cmd.min_depth,
                maxDepth = cmd.max_depth,
            })

        case Set_Scissor_Cmd:
            device_impl.fp.CmdSetScissor(cmdbuf.vk_cmdbuf, 0, 1, &vk.Rect2D{
                offset = {i32(cmd.x), i32(cmd.y)},
                extent = {cmd.width, cmd.height},
            })

        case Draw_Cmd:
            vk_flush_bind_groups(
                device_impl, cmdbuf, &bind_group_slots,
                vk_active_pipeline_layout(active_pipeline, cmd.loc), cmd.loc)
            device_impl.fp.CmdDraw(
                cmdbuf.vk_cmdbuf,
                cmd.vertex_count,
                cmd.instance_count,
                cmd.first_vertex,
                cmd.first_instance,
            )

        case Draw_Indexed_Cmd:
            vk_flush_bind_groups(
                device_impl, cmdbuf, &bind_group_slots,
                vk_active_pipeline_layout(active_pipeline, cmd.loc), cmd.loc)
            device_impl.fp.CmdDrawIndexed(
                cmdbuf.vk_cmdbuf,
                cmd.index_count,
                cmd.instance_count,
                cmd.first_index,
                i32(cmd.base_vertex),
                cmd.first_instance,
            )

        case Draw_Mesh_Tasks_Cmd:
            unimplemented(loc = rpass.loc)

        case Draw_Indirect_Cmd:
            unimplemented(loc = rpass.loc)

        case Multi_Draw_Indirect_Count_Cmd:
            unimplemented(loc = rpass.loc)

        case Render_Pass_End_Cmd:
            break LOOP

        case:
            unreachable()
        }
    }

    device_impl.fp.CmdEndRenderPass(cmdbuf.vk_cmdbuf)

    // No barrier needed here (the pass did COLOR->PRESENT itself). Only
    // re-assert Present if no later command moved the image elsewhere.
    for &texture in present_textures {
        texture_impl := vk_texture_get_impl(texture, rpass.loc)
        end := texture_state_set_get_unchecked(
            &cmdbuf.tracker.textures.end_set, texture_impl.tracker_index, rpass.loc)
        if end.is_single && end.state == {.Present} {
            device_texture_tracker_set_state(
                &device_impl.trackers.textures, texture, {.Present}, rpass.loc)
        }
    }
}

vk_record_commands :: proc(
    device: Device,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    assert(cmdbuf != nil, "invalid command buffer", loc)

    device_impl := vk_device_get_impl(device, loc)

    temp_allocator := virtual.arena_allocator(&cmdbuf.temp_arena)

    // Emit the transitions needed to move every resource used by this command
    // buffer from the state it was left in by the previous submission to the
    // state this command buffer expects at its start. This also folds the
    // command buffer's final states into the device tracker.
    initial_buffers := device_buffer_tracker_set_from_tracker_and_drain_transitions(
        &device_impl.trackers.buffers,
        &cmdbuf.tracker.buffers,
        temp_allocator,
        loc)

    for &tr in initial_buffers {
        if tr.usage.from == {} || tr.usage.from == tr.usage.to {
            continue
        }
        buffer := resource_metadata_get_unchecked(&cmdbuf.tracker.buffers.metadata, tr.id)
        vk_record_transition_buffer(
            device_impl,
            cmdbuf.vk_cmdbuf,
            buffer,
            tr.usage.from,
            tr.usage.to,
            loc)
    }

    initial_textures := device_texture_tracker_set_from_tracker_and_drain_transitions(
        &device_impl.trackers.textures,
        &cmdbuf.tracker.textures,
        temp_allocator,
        loc)

    for &tr in initial_textures {
        if tr.usage.from == TEXTURE_USES_UNKNOWN || tr.usage.from == {} ||
           tr.usage.from == tr.usage.to {
            continue
        }
        texture := resource_metadata_get_unchecked(&cmdbuf.tracker.textures.metadata, tr.id)
        vk_record_transition_texture(
            device_impl,
            cmdbuf.vk_cmdbuf,
            texture,
            Image_Subresource_Range {
                aspect            = .All,
                base_mip_level    = tr.selector.mips.start,
                mip_level_count   = tr.selector.mips.end - tr.selector.mips.start,
                base_array_layer  = tr.selector.layers.start,
                array_layer_count = tr.selector.layers.end - tr.selector.layers.start,
            },
            tr.usage.from,
            tr.usage.to,
            false,
            loc)
    }

    LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
        #partial switch &cmd in curr {
        case Begin_Render_Pass_Cmd:
            vk_record_render_pass(device, cmdbuf, &cmd, loc)

        case Begin_Compute_Pass_Cmd:
            unimplemented(loc = cmd.loc)

        case Set_Immediate_Cmd:
            unimplemented(loc = cmd.loc)

        case Push_Debug_Group_Cmd:
            unimplemented(loc = cmd.loc)

        case Pop_Debug_Group_Cmd:
            unimplemented(loc = cmd.loc)

        case Insert_Debug_Marker_Cmd:
            unimplemented(loc = cmd.loc)

        case Write_Timestamp_Cmd:
            unimplemented(loc = cmd.loc)

        case Begin_Occlusion_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case End_Occlusion_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case Begin_Pipeline_Statistics_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case End_Pipeline_Statistics_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case Execute_Bundle_Cmd:
            unimplemented(loc = cmd.loc)

        case Copy_Buffer_To_Buffer_Cmd:
            src_impl := vk_buffer_get_impl(cmd.src, cmd.loc)
            dst_impl := vk_buffer_get_impl(cmd.dst, cmd.loc)

            copy_region := vk.BufferCopy {
                srcOffset = vk.DeviceSize(cmd.src_offset),
                dstOffset = vk.DeviceSize(cmd.dst_offset),
                size      = vk.DeviceSize(cmd.size),
            }

            vk.CmdCopyBuffer(
                cmdbuf.vk_cmdbuf,
                src_impl.vk_buffer,
                dst_impl.vk_buffer,
                1,
                &copy_region,
            )

        case Copy_Buffer_To_Texture_Cmd:
            src_impl := vk_buffer_get_impl(cmd.src.buffer, cmd.loc)
            dst_impl := vk_texture_get_impl(cmd.dst.texture, cmd.loc)

            block_width, block_height := texture_format_block_dimensions(dst_impl.format)
            block_size := texture_format_block_copy_size(dst_impl.format, cmd.dst.aspect)

            is_3d := dst_impl.dimension == .D3

            copy_region := vk.BufferImageCopy {
                bufferOffset      = vk.DeviceSize(cmd.src.layout.offset),
                bufferRowLength    = (cmd.src.layout.bytes_per_row / block_size) * block_width,
                bufferImageHeight  = cmd.src.layout.rows_per_image * block_height,
                imageSubresource   = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(cmd.dst.aspect, dst_impl.format),
                    mipLevel       = cmd.dst.mip_level,
                    baseArrayLayer = is_3d ? 0 : cmd.dst.origin.z,
                    layerCount     = is_3d ? 1 : cmd.size.depth_or_array_layers,
                },
                imageOffset = vk.Offset3D {
                    x = i32(cmd.dst.origin.x),
                    y = i32(cmd.dst.origin.y),
                    z = is_3d ? i32(cmd.dst.origin.z) : 0,
                },
                imageExtent = vk.Extent3D {
                    width  = cmd.size.width,
                    height = cmd.size.height,
                    depth  = is_3d ? cmd.size.depth_or_array_layers : 1,
                },
            }

            vk.CmdCopyBufferToImage(
                cmdbuf.vk_cmdbuf,
                src_impl.vk_buffer,
                dst_impl.vk_image,
                .TRANSFER_DST_OPTIMAL,
                1,
                &copy_region,
            )

        case Copy_Texture_To_Buffer_Cmd:
            unimplemented(loc = cmd.loc)

        case Copy_Texture_To_Texture_Cmd:
            src_impl := vk_texture_get_impl(cmd.src.texture, cmd.loc)
            dst_impl := vk_texture_get_impl(cmd.dst.texture, cmd.loc)

            is_3d := dst_impl.dimension == .D3

            copy_region := vk.ImageCopy {
                srcSubresource = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(cmd.src.aspect, src_impl.format),
                    mipLevel       = cmd.src.mip_level,
                    baseArrayLayer = is_3d ? 0 : cmd.src.origin.z,
                    layerCount     = 1,
                },
                srcOffset = vk.Offset3D {
                    x = i32(cmd.src.origin.x),
                    y = i32(cmd.src.origin.y),
                    z = is_3d ? i32(cmd.src.origin.z) : 0,
                },
                dstSubresource = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(cmd.dst.aspect, dst_impl.format),
                    mipLevel       = cmd.dst.mip_level,
                    baseArrayLayer = is_3d ? 0 : cmd.dst.origin.z,
                    layerCount     = 1,
                },
                dstOffset = vk.Offset3D {
                    x = i32(cmd.dst.origin.x),
                    y = i32(cmd.dst.origin.y),
                    z = is_3d ? i32(cmd.dst.origin.z) : 0,
                },
                extent = vk.Extent3D {
                    width  = cmd.size.width,
                    height = cmd.size.height,
                    depth  = is_3d ? cmd.size.depth_or_array_layers : 1,
                },
            }

            // Layouts are guaranteed by our own transitions: the encoder
            // records Copy_Src/Copy_Dst transitions ahead of this command.
            vk.CmdCopyImage(
                cmdbuf.vk_cmdbuf,
                src_impl.vk_image,
                .TRANSFER_SRC_OPTIMAL,
                dst_impl.vk_image,
                .TRANSFER_DST_OPTIMAL,
                1,
                &copy_region,
            )

        case Clear_Buffer_Cmd:
            vk_record_clear_buffer(device_impl, cmdbuf.vk_cmdbuf, cmd, cmd.loc)

        case Clear_Texture_Cmd:
            unimplemented(loc = cmd.loc)

        case Build_Acceleration_Structures_Cmd:
            unimplemented(loc = cmd.loc)

        case Resolve_Query_Set_Cmd:
            unimplemented(loc = cmd.loc)

        case Transition_Buffer_Cmd:
            vk_record_transition_buffer(
                device_impl,
                cmdbuf.vk_cmdbuf,
                cmd.buffer,
                cmd.state_from,
                cmd.state_to,
                cmd.loc)

        case Transition_Texture_Cmd:
            // Both states were captured when the command was encoded, against
            // the device tracker's sequential state. The device tracker is
            // deliberately not read or written here: by the time commands are
            // recorded, the initial drain has already committed it to this
            // command buffer's end state.
            vk_record_transition_texture(
                device_impl,
                cmdbuf.vk_cmdbuf,
                cmd.texture,
                cmd.selector,
                cmd.state_from,
                cmd.state_to,
                cmd.force_barrier,
                cmd.loc)
        }
    }
}
