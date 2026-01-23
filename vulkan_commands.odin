#+build !js
package gpu

// Core
import sa "core:container/small_array"

// Vendor
import vk "vendor:vulkan"

vk_execute_begin_render_pass :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Begin_Render_Pass,
    loc := #caller_location,
) {
    vk_rendering_attachments: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.RenderingAttachmentInfo)

    color_attachments := sa.slice(&cmd.color_attachments)
    for &attachment in color_attachments {
        assert(attachment.view != nil, "Invalid color attachment view", loc)

        color_tex_view := get_impl(Vulkan_Texture_View_Impl, attachment.view, loc)
        color_tex := get_impl(Vulkan_Texture_Impl, color_tex_view.texture, loc)

        // Retain user owned texture for command buffer lifetime
        if color_tex.is_owning_vk_image {
            vk_deletion_queue_push(&cmd_buf.resources, color_tex)
        }

        // Transition main color attachment
        vk_transition_to_color_attachment(cmd_buf, color_tex, loc)

        has_resolve := attachment.resolve_target != nil
        resolve_tex: ^Vulkan_Texture_Impl
        samples := color_tex.vk_samples

        if has_resolve {
            resolve_tex_view := get_impl(Vulkan_Texture_View_Impl, attachment.resolve_target, loc)
            resolve_tex = get_impl(Vulkan_Texture_Impl, resolve_tex_view.texture, loc)

            assert(resolve_tex.vk_extent.width == cmd.width &&
                   resolve_tex.vk_extent.height == cmd.height,
               "Resolve target must match framebuffer dimensions", loc)
            assert(resolve_tex.vk_samples == {._1}, "Resolve target must be single-sampled", loc)

            vk_transition_to_color_attachment(cmd_buf, resolve_tex, loc)
            vk_deletion_queue_push(&cmd_buf.resources, resolve_tex)
        }

        clear_value_f32 := [4]f32{
            f32(attachment.ops.clear_value.x),
            f32(attachment.ops.clear_value.y),
            f32(attachment.ops.clear_value.z),
            f32(attachment.ops.clear_value.w),
        }

        sa.push_back(&vk_rendering_attachments, vk.RenderingAttachmentInfo{
            sType              = .RENDERING_ATTACHMENT_INFO,
            imageView          = color_tex.vk_image_view,
            imageLayout        = .COLOR_ATTACHMENT_OPTIMAL,
            resolveMode        = has_resolve && samples != {._1} ? { .AVERAGE } : {},
            resolveImageView   = has_resolve ? resolve_tex.vk_image_view : {},
            resolveImageLayout = has_resolve ? .COLOR_ATTACHMENT_OPTIMAL : .UNDEFINED,
            loadOp             = vk_conv_to_attachment_load_op(attachment.ops.load),
            storeOp            = vk_conv_to_attachment_store_op(attachment.ops.store),
            clearValue         = { color = { float32 = clear_value_f32 } },
        })
    }

    // Depth-stencil attachment
    has_depth: bool
    has_stencil: bool
    vk_depth_attachment: vk.RenderingAttachmentInfo
    vk_stencil_attachment: vk.RenderingAttachmentInfo

    if depth_stencil, ok := cmd.depth_stencil_attachment.?; ok {
        assert(depth_stencil.view != nil, "Invalid depth attachment view", loc)

        view_impl := get_impl(Vulkan_Texture_View_Impl, depth_stencil.view, loc)
        texture_impl := get_impl(Vulkan_Texture_Impl, view_impl.texture, loc)

        // Retain texture
        vk_deletion_queue_push(&cmd_buf.resources, texture_impl)

        // Determine/validate dimensions
        assert(texture_impl.vk_extent.width == cmd.width &&
               texture_impl.vk_extent.height == cmd.height,
           "Depth/stencil attachment must match framebuffer dimensions", loc)

        has_depth = texture_format_has_depth_aspect(view_impl.format)
        has_stencil = texture_format_has_stencil_aspect(view_impl.format)

        aspect_mask: vk.ImageAspectFlags
        if has_depth   { aspect_mask += {.DEPTH}   }
        if has_stencil { aspect_mask += {.STENCIL} }

        subresource_range := vk.ImageSubresourceRange{
            aspectMask     = aspect_mask,
            baseMipLevel   = 0,
            levelCount     = texture_impl.mip_level_count,
            baseArrayLayer = 0,
            layerCount     = texture_impl.array_layer_count,
        }

        vk_texture_transition_layout(
            texture_impl,
            cmd_buf.vk_cmd_buf,
            .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            subresource_range,
        )

        // Full depth-stencil clear value
        depth_clear_val := has_depth   ? depth_stencil.depth_ops.clear_value   : 0.0
        stencil_clear_val := has_stencil ? depth_stencil.stencil_ops.clear_value : 0
        full_ds_clear := vk.ClearDepthStencilValue{
            depth   = depth_clear_val,
            stencil = stencil_clear_val,
        }
        ds_clear_value := vk.ClearValue{ depthStencil = full_ds_clear }

        if has_depth {
            depth_load : vk.AttachmentLoadOp = depth_stencil.depth_ops.read_only \
                ? .LOAD : vk_conv_to_attachment_load_op(depth_stencil.depth_ops.load)
            depth_store : vk.AttachmentStoreOp = depth_stencil.depth_ops.read_only \
                ? .DONT_CARE : vk_conv_to_attachment_store_op(depth_stencil.depth_ops.store)

            vk_depth_attachment = vk.RenderingAttachmentInfo{
                sType       = .RENDERING_ATTACHMENT_INFO,
                imageView   = view_impl.vk_image_view,
                imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                loadOp      = depth_load,
                storeOp     = depth_store,
                clearValue  = ds_clear_value,
            }
        }

        // Stencil aspect
        if has_stencil {
            stencil_load : vk.AttachmentLoadOp = depth_stencil.stencil_ops.read_only \
                ? .LOAD      : vk_conv_to_attachment_load_op(depth_stencil.stencil_ops.load)
            stencil_store : vk.AttachmentStoreOp = depth_stencil.stencil_ops.read_only \
                ? .DONT_CARE : vk_conv_to_attachment_store_op(depth_stencil.stencil_ops.store)

            vk_stencil_attachment = vk.RenderingAttachmentInfo{
                sType       = .RENDERING_ATTACHMENT_INFO,
                imageView   = view_impl.vk_image_view,
                imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
                loadOp      = stencil_load,
                storeOp     = stencil_store,
                clearValue  = ds_clear_value,
            }
        }
    }

    assert(cmd.width > 0 && cmd.height > 0,
        "Invalid framebuffer dimensions, no valid attachments provided", loc)

    scissor := vk.Rect2D{
        offset = { 0, 0 },
        extent = { cmd.width, cmd.height },
    }

    rendering_info := vk.RenderingInfo{
        sType                = .RENDERING_INFO,
        renderArea           = scissor,
        layerCount           = 1,
        viewMask             = 0,
        colorAttachmentCount = u32(sa.len(vk_rendering_attachments)),
        pColorAttachments    = raw_data(sa.slice(&vk_rendering_attachments)),
        pDepthAttachment     = has_depth   ? &vk_depth_attachment   : nil,
        pStencilAttachment   = has_stencil ? &vk_stencil_attachment : nil,
    }

    vk.CmdBeginRendering(cmd_buf.vk_cmd_buf, &rendering_info)

    // Default viewport/scissor
    vk_render_pass_set_viewport_impl(
        render_pass = Render_Pass(cmd_buf),
        x           = 0.0,
        y           = 0.0,
        width       = f32(cmd.width),
        height      = f32(cmd.height),
        min_depth   = 0.0,
        max_depth   = 1.0,
    )

    vk_render_pass_set_scissor_rect_impl(
        render_pass = Render_Pass(cmd_buf),
        x           = 0,
        y           = 0,
        width       = cmd.width,
        height      = cmd.height,
    )

    // Improved dynamic state defaults
    depth_store_op := has_depth ? vk_depth_attachment.storeOp : .DONT_CARE

    vk.CmdSetDepthTestEnable(cmd_buf.vk_cmd_buf, b32(has_depth))
    vk.CmdSetDepthWriteEnable(cmd_buf.vk_cmd_buf, b32(has_depth && depth_store_op == .STORE))
    vk.CmdSetDepthCompareOp(cmd_buf.vk_cmd_buf, .LESS)
    vk.CmdSetDepthBiasEnable(cmd_buf.vk_cmd_buf, false)

    if has_stencil {
        vk.CmdSetStencilTestEnable(cmd_buf.vk_cmd_buf, true)
    }
    vk.CmdSetStencilReference(cmd_buf.vk_cmd_buf, {.FRONT, .BACK}, 0)
}

vk_execute_render_pass_set_pipeline :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Set_Render_Pipeline,
    loc := #caller_location,
) {
    pipeline_impl := get_impl(Vulkan_Render_Pipeline_Impl, cmd.pipeline, loc)
    cmd_buf.current_pipeline_graphics = pipeline_impl
    vk_deletion_queue_push(&cmd_buf.resources, pipeline_impl)
    vk.CmdBindPipeline(cmd_buf.vk_cmd_buf, .GRAPHICS, pipeline_impl.vk_pipeline)
}

vk_execute_render_pass_set_bind_group :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Set_Bind_Group,
    loc := #caller_location,
) {
    group_impl := get_impl(Vulkan_Bind_Group_Impl, cmd.group, loc)

    // Bind the descriptor set
    vk.CmdBindDescriptorSets(
        cmd_buf.vk_cmd_buf,
        .GRAPHICS,
        cmd_buf.current_pipeline_graphics.pipeline_layout.vk_pipeline_layout,
        cmd.group_index,
        1,
        &group_impl.vk_descriptor_set,
        u32(len(cmd.dynamic_offsets)),
        raw_data(cmd.dynamic_offsets) if len(cmd.dynamic_offsets) > 0 else nil,
    )

    vk_deletion_queue_push(&cmd_buf.resources, group_impl)
}

vk_execute_render_pass_set_vertex_buffer :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Set_Vertex_Buffer,
    loc := #caller_location,
) {
    buffer_impl := get_impl(Vulkan_Buffer_Impl, cmd.buffer, loc)
    vk_deletion_queue_push(&cmd_buf.resources, buffer_impl)

    vk_offset := vk.DeviceSize(cmd.offset)
    vk_size: vk.DeviceSize

    if cmd.size == WHOLE_SIZE {
        vk_size = buffer_impl.vk_device_size - vk_offset
    } else {
        vk_size = vk.DeviceSize(cmd.size)
        assert(vk_offset + vk_size <= buffer_impl.vk_device_size,
               "Vertex buffer offset + size exceeds buffer capacity", loc)
    }

    vk.CmdBindVertexBuffers2(
        cmd_buf.vk_cmd_buf, cmd.slot, 1, &buffer_impl.vk_buffer, &vk_offset, &vk_size, nil)
}

vk_execute_render_pass_set_index_buffer :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Set_Index_Buffer,
    loc := #caller_location,
) {
    assert(cmd.buffer != nil, "Invalid index buffer", loc)
    buffer_impl := get_impl(Vulkan_Buffer_Impl, cmd.buffer, loc)
    device_impl := get_impl(Vulkan_Device_Impl, buffer_impl.device, loc)
    vk_deletion_queue_push(&cmd_buf.resources, buffer_impl)

    vk_offset := vk.DeviceSize(cmd.offset)
    vk_size: vk.DeviceSize

    if cmd.size == WHOLE_SIZE {
        vk_size = buffer_impl.vk_device_size - vk_offset
    } else {
        vk_size = vk.DeviceSize(cmd.size)
        assert(vk_offset + vk_size <= buffer_impl.vk_device_size,
               "Index buffer offset + size exceeds buffer capacity", loc)
    }

    if device_impl.has_KHR_maintenance5 {
        vk.CmdBindIndexBuffer2KHR(
            cmd_buf.vk_cmd_buf,
            buffer_impl.vk_buffer,
            vk_offset,
            vk_size,
            vk_conv_to_index_type(cmd.format),
        )
    } else {
        vk.CmdBindIndexBuffer(
            cmd_buf.vk_cmd_buf,
            buffer_impl.vk_buffer,
            vk_offset,
            vk_conv_to_index_type(cmd.format),
        )
    }
}

vk_execute_render_set_stencil_reference :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Set_Stencil_Reference,
    loc := #caller_location,
) {
    vk.CmdSetStencilReference(cmd_buf.vk_cmd_buf, { .FRONT, .BACK }, cmd.reference)
}

vk_execute_render_pass_draw :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Draw,
    loc := #caller_location,
) {
    vk.CmdDraw(
        cmd_buf.vk_cmd_buf,
        cmd.vertex_count,
        cmd.instance_count,
        cmd.first_vertex,
        cmd.first_instance,
    )
}

vk_execute_render_pass_draw_indexed :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_Draw_Indexed,
    loc := #caller_location,
) {
    vk.CmdDrawIndexed(
        cmd_buf.vk_cmd_buf,
        cmd.index_count,
        cmd.instance_count,
        cmd.first_index,
        cmd.vertex_offset,
        cmd.first_instance,
    )
}

vk_execute_render_pass_end :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Render_Pass_End,
    cmd_begin_rpass: ^Command_Begin_Render_Pass,
    loc := #caller_location,
) {
    vk.CmdEndRendering(cmd_buf.vk_cmd_buf)

    // Transition swapchain images to PRESENT_SRC_KHR
    color_attachments := sa.slice(&cmd_begin_rpass.color_attachments)
    for attachment in color_attachments {
        texture_view := get_impl(Vulkan_Texture_View_Impl, attachment.view, loc)
        texture := get_impl(Vulkan_Texture_Impl, texture_view.texture, loc)
        if texture.is_swapchain_image {
            subresource_range := vk.ImageSubresourceRange{
                aspectMask     = {.COLOR},
                baseMipLevel   = 0,
                levelCount     = 1,
                baseArrayLayer = 0,
                layerCount     = 1,
            }

            vk_texture_transition_layout(
                texture,
                cmd_buf.vk_cmd_buf,
                .PRESENT_SRC_KHR,
                subresource_range,
            )
        }
    }
}

vk_execute_copy_buffer_to_buffer :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Copy_Buffer_To_Buffer,
    loc := #caller_location,
) {
    src_impl := get_impl(Vulkan_Buffer_Impl, cmd.source, loc)
    dst_impl := get_impl(Vulkan_Buffer_Impl, cmd.destination, loc)

    copy_region := vk.BufferCopy{
        srcOffset = vk.DeviceSize(cmd.source_offset),
        dstOffset = vk.DeviceSize(cmd.destination_offset),
        size = vk.DeviceSize(cmd.size),
    }

    vk.CmdCopyBuffer(
        cmd_buf.vk_cmd_buf,
        src_impl.vk_buffer,
        dst_impl.vk_buffer,
        1,
        &copy_region,
    )

    vk_deletion_queue_push(&cmd_buf.resources, src_impl)
    vk_deletion_queue_push(&cmd_buf.resources, dst_impl)
}

vk_execute_copy_buffer_to_texture :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Copy_Buffer_To_Texture,
    loc := #caller_location,
) {
    assert(cmd.source.buffer != nil, "Invalid source buffer", loc)
    assert(cmd.destination.texture != nil, "Invalid destination texture", loc)

    buffer_impl := get_impl(Vulkan_Buffer_Impl, cmd.source.buffer, loc)
    texture_impl := get_impl(Vulkan_Texture_Impl, cmd.destination.texture, loc)

    // Set up the buffer image copy region
    region := vk_compute_buffer_image_copy_region(
        cmd.source.layout,
        cmd.destination,
        cmd.copy_size,
        loc,
    )

    // Define subresource range for the layout transition
    // Derive it directly from the computed region to keep them in sync
    subresource_range := vk.ImageSubresourceRange{
        aspectMask     = region.imageSubresource.aspectMask,
        baseMipLevel   = region.imageSubresource.mipLevel,
        levelCount     = 1,
        baseArrayLayer = region.imageSubresource.baseArrayLayer,
        layerCount     = region.imageSubresource.layerCount,
    }

    // Transition to TRANSFER_DST_OPTIMAL
    vk_texture_transition_layout(
        texture_impl,
        cmd_buf.vk_cmd_buf,
        .TRANSFER_DST_OPTIMAL,
        subresource_range,
    )

    // Copy buffer to image
    vk.CmdCopyBufferToImage(
        commandBuffer  = cmd_buf.vk_cmd_buf,
        srcBuffer      = buffer_impl.vk_buffer,
        dstImage       = texture_impl.vk_image,
        dstImageLayout = .TRANSFER_DST_OPTIMAL,
        regionCount    = 1,
        pRegions       = &region,
    )

    vk_deletion_queue_push(&cmd_buf.resources, buffer_impl)
    vk_deletion_queue_push(&cmd_buf.resources, texture_impl)
}

vk_execute_copy_texture_to_texture :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Copy_Texture_To_Texture,
    loc := #caller_location,
) {
    source_impl := get_impl(Vulkan_Texture_Impl, cmd.source.texture, loc)
    destination_impl := get_impl(Vulkan_Texture_Impl, cmd.destination.texture, loc)

    source_subresource_range := vk.ImageSubresourceRange{
        aspectMask     = vk_conv_to_image_aspect_flags(cmd.source.aspect, source_impl.format),
        baseMipLevel   = cmd.source.mip_level,
        baseArrayLayer = cmd.source.origin.z,
        layerCount     = 1,
        levelCount     = 1,
    }

    // Save original layout to restore later (important for swapchain images)
    old_source_layout := source_impl.vk_image_layout

    // Transition source to TRANSFER_SRC_OPTIMAL
    vk_texture_transition_layout(
        source_impl,
        cmd_buf.vk_cmd_buf,
        .TRANSFER_SRC_OPTIMAL,
        source_subresource_range,
    )

    destination_subresource_range := vk.ImageSubresourceRange{
        aspectMask     = vk_conv_to_image_aspect_flags(cmd.destination.aspect, destination_impl.format),
        baseMipLevel   = cmd.destination.mip_level,
        baseArrayLayer = cmd.destination.origin.z,
        layerCount     = 1,
        levelCount     = 1,
    }

    // Transition destination to TRANSFER_DST_OPTIMAL
    vk_texture_transition_layout(
        destination_impl,
        cmd_buf.vk_cmd_buf,
        .TRANSFER_DST_OPTIMAL,
        destination_subresource_range,
    )

    region := vk.ImageBlit {
        srcSubresource = {
            aspectMask = source_subresource_range.aspectMask,
            mipLevel = cmd.source.mip_level,
            baseArrayLayer = cmd.source.origin.z,
            layerCount = 1,
        },
        srcOffsets = {
            { i32(cmd.source.origin.x), i32(cmd.source.origin.y), i32(cmd.source.origin.z) },
            {
                i32(cmd.source.origin.x + cmd.copy_size.width),
                i32(cmd.source.origin.y + cmd.copy_size.height),
                i32(cmd.source.origin.z + cmd.copy_size.depth_or_array_layers),
            },
        },
        dstSubresource = {
            aspectMask = destination_subresource_range.aspectMask,
            mipLevel = cmd.destination.mip_level,
            baseArrayLayer = cmd.destination.origin.z,
            layerCount = 1,
        },
        dstOffsets = {
            { i32(cmd.destination.origin.x), i32(cmd.destination.origin.y), i32(cmd.destination.origin.z) },
            {
                i32(cmd.destination.origin.x + cmd.copy_size.width),
                i32(cmd.destination.origin.y + cmd.copy_size.height),
                i32(cmd.destination.origin.z + cmd.copy_size.depth_or_array_layers),
            },
        },
    }

    vk.CmdBlitImage(
        commandBuffer  = cmd_buf.vk_cmd_buf,
        srcImage       = source_impl.vk_image,
        srcImageLayout = .TRANSFER_SRC_OPTIMAL,
        dstImage       = destination_impl.vk_image,
        dstImageLayout = .TRANSFER_DST_OPTIMAL,
        regionCount    = 1,
        pRegions       = &region,
        filter         = .NEAREST,
    )

    // Restore source layout if it was a swapchain image (needs to be PRESENT_SRC_KHR)
    if source_impl.is_swapchain_image {
        vk_texture_transition_layout(
            source_impl,
            cmd_buf.vk_cmd_buf,
            old_source_layout,
            source_subresource_range,
        )
    }

    // Transition destination to appropriate final layout
    final_layout: vk.ImageLayout
    if .Storage_Binding in destination_impl.usage {
        final_layout = .GENERAL
    } else {
        final_layout = .SHADER_READ_ONLY_OPTIMAL
    }

    vk_texture_transition_layout(
        destination_impl,
        cmd_buf.vk_cmd_buf,
        final_layout,
        destination_subresource_range,
    )

    vk_deletion_queue_push(&cmd_buf.resources, source_impl)
    vk_deletion_queue_push(&cmd_buf.resources, destination_impl)
}

vk_execute_finish :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    cmd: ^Command_Finish,
    loc := #caller_location,
) {
    vk_check(vk.EndCommandBuffer(cmd_buf.vk_cmd_buf), loc = loc)
}

vk_execute_render_pass_segment :: proc(
    cmd_buf: ^Vulkan_Command_Buffer_Impl,
    commands: []Command,
    loc := #caller_location,
) {
    // Process layout transitions before render pass begins
    for &cmd in commands {
        #partial switch &c in cmd {
        case Command_Render_Pass_Set_Bind_Group:
            group_impl := get_impl(Vulkan_Bind_Group_Impl, c.group, loc)

            for &view in group_impl.texture_views {
                texture_view_impl := get_impl(Vulkan_Texture_View_Impl, view.texture_view, loc)
                texture_impl := get_impl(Vulkan_Texture_Impl, texture_view_impl.texture, loc)

                target_layout : vk.ImageLayout = view.storage ? .GENERAL : .SHADER_READ_ONLY_OPTIMAL

                if texture_impl.vk_image_layout != target_layout {
                    subresource_range := vk.ImageSubresourceRange{
                        aspectMask     = vk_conv_to_image_aspect_flags(
                            texture_view_impl.aspect,
                            texture_impl.format,
                        ),
                        baseMipLevel   = texture_view_impl.base_mip_level,
                        levelCount     = texture_view_impl.mip_level_count,
                        baseArrayLayer = texture_view_impl.base_array_layer,
                        layerCount     = texture_view_impl.array_layer_count,
                    }

                    vk_texture_transition_layout(
                        texture_impl,
                        cmd_buf.vk_cmd_buf,
                        target_layout,
                        subresource_range,
                    )
                }
            }
        }
    }

    cmd_begin_rpass: ^Command_Begin_Render_Pass

    // Execute the render pass commands
    for &cmd in commands {
        #partial switch &c in cmd {
        case Command_Begin_Render_Pass:
            cmd_begin_rpass = &c
            vk_execute_begin_render_pass(cmd_buf, &c, loc)

        case Command_Render_Pass_Set_Render_Pipeline:
            vk_execute_render_pass_set_pipeline(cmd_buf, &c, loc)

        case Command_Render_Pass_Set_Bind_Group:
            vk_execute_render_pass_set_bind_group(cmd_buf, &c, loc)

        case Command_Render_Pass_Set_Vertex_Buffer:
            vk_execute_render_pass_set_vertex_buffer(cmd_buf, &c, loc)

        case Command_Render_Pass_Set_Index_Buffer:
            vk_execute_render_pass_set_index_buffer(cmd_buf, &c, loc)

        case Command_Render_Pass_Set_Stencil_Reference:
            vk_execute_render_set_stencil_reference(cmd_buf, &c, loc)

        case Command_Render_Pass_Draw:
            vk_execute_render_pass_draw(cmd_buf, &c, loc)

        case Command_Render_Pass_Draw_Indexed:
            vk_execute_render_pass_draw_indexed(cmd_buf, &c, loc)

        case Command_Render_Pass_End:
            vk_execute_render_pass_end(cmd_buf, &c, cmd_begin_rpass, loc)
            return

        case:
            unreachable()
        }
    }

    assert(cmd_begin_rpass != nil, loc = loc)
}

vk_record_commands :: proc(cmd_buf: ^Vulkan_Command_Buffer_Impl, loc := #caller_location) {
    commands := &cmd_buf.cmd_allocator.data
    rpass_start := -1

    for &cmd, cmd_idx in commands {
        #partial switch &c in cmd {
        case Command_Begin_Render_Pass:
            assert(rpass_start == -1, "Cannot begin a render pass inside another", loc)
            rpass_start = cmd_idx

        case Command_Render_Pass_End:
            assert(rpass_start >= 0, "Attempt to end a render pass that is not started", loc)
            vk_execute_render_pass_segment(cmd_buf, commands[rpass_start:cmd_idx+1], loc)
            rpass_start = -1

        case Command_Copy_Buffer_To_Buffer:
            vk_execute_copy_buffer_to_buffer(cmd_buf, &c, loc)

        case Command_Copy_Buffer_To_Texture:
            vk_execute_copy_buffer_to_texture(cmd_buf, &c, loc)

        case Command_Copy_Texture_To_Texture:
            vk_execute_copy_texture_to_texture(cmd_buf, &c, loc)

        case Command_Finish:
            vk_execute_finish(cmd_buf, &c, loc)

        case:
            // panic("Unhandled command", loc)
        }
    }

    command_allocator_reset(&cmd_buf.cmd_allocator)
}
