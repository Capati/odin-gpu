#+build !js
package gpu

// Core
import "core:sync"

// Vendor
import vk "vendor:vulkan"

// What the begin-recording helper hands back to the pass object.
VK_Render_Pass_Begin_State :: struct {
    vk_render_pass:   vk.RenderPass,
    vk_framebuffer:   vk.Framebuffer,
    present_textures: [MAX_ATTACHMENT_COUNT]Texture,
    present_count:    u32,
}

vk_render_pass_begin_record :: proc(
    device: Device,
    cmdbuf: ^VK_Command_Buffer_Impl,
    rpass: ^Begin_Render_Pass_Cmd,
    loc := #caller_location,
) -> VK_Render_Pass_Begin_State {
    device_impl := vk_device_get_impl(device, loc)

    rp_key: VK_Render_Pass_Key
    fb_query: VK_Framebuffer_Cache

    vk_clear_values: [dynamic; MAX_ATTACHMENT_COUNT]vk.ClearValue
    present_textures: [dynamic; MAX_ATTACHMENT_COUNT]Texture

    for &color, i in rpass.color_attachments {
        assert(color.view != {}, "Invalid color attachment view", rpass.loc)

        view_impl := vk_texture_view_get_impl(color.view, rpass.loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, rpass.loc)

        if texture_impl.is_swapchain {
            append(&present_textures, view_impl.texture)
        }

        // All attachments in a render pass must share a sample count.
        assert(
            i == 0 || rp_key.sample_count == texture_impl.sample_count,
            "All color attachments must have the same sample count",
            rpass.loc,
        )
        rp_key.sample_count = texture_impl.sample_count

        // A swapchain image must be left ready for presentation, and the render
        // pass is the only place that knows the pass has ended, so it performs
        // the transition itself.
        color_final_layout: vk.ImageLayout = .COLOR_ATTACHMENT_OPTIMAL

        rp_key.colors[i].base = {
            format       = texture_impl.vk_image_format,
            layout       = .COLOR_ATTACHMENT_OPTIMAL,
            final_layout = color_final_layout,
            load_op      = color.ops.load,
            store_op     = color.ops.store,
        }

        append(&vk_clear_values, vk.ClearValue {
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
            resolve_view_impl := vk_texture_view_get_impl(color.resolve_target, rpass.loc)
            resolve_texture_impl := vk_texture_get_impl(resolve_view_impl.texture, rpass.loc)

            resolve_width := max(
                u32(1),
                u32(resolve_texture_impl.vk_extent.width) >> resolve_view_impl.selector.mip_start,
            )
            resolve_height := max(
                u32(1),
                u32(resolve_texture_impl.vk_extent.height) >> resolve_view_impl.selector.mip_start,
            )

            assert(
                resolve_width == rpass.width && resolve_height == rpass.height,
                "Resolve target must match framebuffer dimensions",
                rpass.loc,
            )
            assert(
                resolve_texture_impl.vk_samples == {._1},
                "Resolve target must be single-sampled",
                rpass.loc,
            )

            if resolve_texture_impl.is_swapchain {
                append(&present_textures, resolve_view_impl.texture)
            }

            // A swapchain resolve target still has to end presentable,
            // otherwise the resolved image is never handed to the display.
            resolve_final_layout: vk.ImageLayout =
                (resolve_texture_impl.is_swapchain ? .COLOR_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL)

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
                &fb_query,
                color.resolve_target,
                resolve_view_impl.vk_image_view,
            )
        }
    }

    // Depth-stencil attachment
    has_depth: bool
    has_stencil: bool
    depth_clear: vk.ClearValue

    if ds, has_ds := rpass.depth_stencil_attachment.?; has_ds {
        assert(ds.view != {}, "Invalid depth attachment view", rpass.loc)

        ds_view_impl := vk_texture_view_get_impl(ds.view, rpass.loc)
        ds_texture_impl := vk_texture_get_impl(ds_view_impl.texture, rpass.loc)
        has_depth = texture_format_has_depth_aspect(ds_texture_impl.format)
        has_stencil = texture_format_has_stencil_aspect(ds_texture_impl.format)

        depth_read_only := ds.depth_read_only
        stencil_read_only := ds.stencil_read_only

        aspect_mask: vk.ImageAspectFlags
        if has_depth {aspect_mask += {.DEPTH}}
        if has_stencil {aspect_mask += {.STENCIL}}

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

        depth_load_op := Load_Op.Dont_Care
        depth_store_op := Store_Op.Discard
        stencil_load_op := Load_Op.Dont_Care
        stencil_store_op := Store_Op.Discard

        if has_depth {
            depth_load_op = depth_read_only ? .Load : ds.depth_ops.load
            depth_store_op = depth_read_only ? .Discard : ds.depth_ops.store
        }
        if has_stencil {
            stencil_load_op = stencil_read_only ? .Load : ds.stencil_ops.load
            stencil_store_op = stencil_read_only ? .Discard : ds.stencil_ops.store
        }

        rp_key.depth_stencil = {
            base = {
                format       = ds_texture_impl.vk_image_format,
                layout       = ds_layout,
                final_layout = ds_layout,
                load_op      = depth_load_op,
                store_op     = depth_store_op,
            },
            stencil_load_op = stencil_load_op,
            stencil_store_op = stencil_store_op,
        }
        rp_key.depth_read_only = depth_read_only
        rp_key.stencil_read_only = stencil_read_only

        // If there are no color attachments, the sample count has to come from
        // the DS attachment.
        if len(rpass.color_attachments) == 0 {
            rp_key.sample_count = ds_texture_impl.sample_count
        } else {
            assert(
                rp_key.sample_count == ds_texture_impl.sample_count,
                "Depth-stencil attachment sample count must match color attachments",
                rpass.loc,
            )
        }

        depth_clear.depthStencil = {
            depth   = has_depth && !ds.depth_read_only ? ds.depth_ops.clear_value : 0.0,
            stencil = has_stencil && !ds.stencil_read_only ? ds.stencil_ops.clear_value : 0,
        }
        append(&vk_clear_values, depth_clear)

        vk_framebuffer_query_add_attachment(&fb_query, ds.view, ds_view_impl.vk_image_view)
    }

    vk_render_pass := vk_render_pass_cache_get_or_create(device_impl, rp_key, rpass.loc)

    vk_framebuffer_query_set_extent(&fb_query, rpass.width, rpass.height)

    vk_framebuffer := vk_framebuffer_cache_get_or_create(
        device_impl,
        &fb_query,
        vk_render_pass,
        rpass.width,
        rpass.height,
        rpass.loc,
    )

    begin_info := vk.RenderPassBeginInfo {
        sType = .RENDER_PASS_BEGIN_INFO,
        renderPass = vk_render_pass,
        framebuffer = vk_framebuffer,
        renderArea = {offset = {0, 0}, extent = {rpass.width, rpass.height}},
        clearValueCount = u32(len(vk_clear_values)),
        pClearValues = raw_data(vk_clear_values[:]),
    }

    // Queries a pass uses have to be reset before it begins, and a reset cannot
    // be recorded inside a pass. The commands are all finalized by now, so scan
    // them once (stopping at the pass end) and reset each run of used slots.
    query_uses := &cmdbuf.scan_query_uses
    clear(query_uses)

    scan := cmdbuf.commands.iterator
    SCAN: for curr in array_iterate_by_ptr(&scan) {
        #partial switch &cmd in curr {
        case Write_Timestamp_Cmd:
            vk_query_use_append(query_uses, cmd.query_set, cmd.query_index)

        case Begin_Occlusion_Query_Cmd:
            vk_query_use_append(query_uses, rpass.occlusion_query_set, cmd.query_index)

        case Begin_Pipeline_Statistics_Query_Cmd:
            vk_query_use_append(query_uses, cmd.query_set, cmd.query_index)

        case Render_Pass_End_Cmd:
            break SCAN
        }
    }

    if timestamp_writes, has_timestamps := rpass.timestamp_writes.?; has_timestamps {
        vk_query_use_append(
            query_uses,
            timestamp_writes.query_set,
            timestamp_writes.beginning_of_pass_write_index,
        )
        vk_query_use_append(
            query_uses,
            timestamp_writes.query_set,
            timestamp_writes.end_of_pass_write_index,
        )
    }

    vk_encode_query_resets(device_impl, cmdbuf.current_cmdbuf, query_uses^[:], rpass.loc)

    // Emit transitions computed at `render_pass_end` before recording the pass.
    // They cover its full usage scope and transition resources from the state
    // left by previous scopes to the state required by this pass.
    vk_encode_barriers(
        device_impl,
        cmdbuf,
        rpass.texture_transitions,
        rpass.buffer_transitions,
        rpass.loc,
    )

    device_impl.fp.CmdBeginRenderPass(cmdbuf.current_cmdbuf, &begin_info, .INLINE)

    // Call default commands for the dynamic state
    device_impl.fp.CmdSetLineWidth(cmdbuf.current_cmdbuf, 1.0)
    device_impl.fp.CmdSetDepthBounds(cmdbuf.current_cmdbuf, 0.0, 1.0)
    device_impl.fp.CmdSetStencilReference(cmdbuf.current_cmdbuf, {.FRONT, .BACK}, 0)
    device_impl.fp.CmdSetBlendConstants(cmdbuf.current_cmdbuf, &{0.0, 0.0, 0.0, 0.0})
    device_impl.fp.CmdSetViewport(cmdbuf.current_cmdbuf, 0, 1, &vk.Viewport {
            x        = 0.0,
            y        = f32(rpass.height),
            width    = f32(rpass.width),
            height   = -f32(rpass.height),
            minDepth = 0.0,
            maxDepth = 1.0,
        })
    device_impl.fp.CmdSetScissor(cmdbuf.current_cmdbuf, 0, 1, &vk.Rect2D {
            offset = {0, 0},
            extent = {rpass.width, rpass.height},
        })

    state: VK_Render_Pass_Begin_State
    state.vk_render_pass = vk_render_pass
    state.vk_framebuffer = vk_framebuffer
    state.present_count = u32(len(present_textures))
    for texture, i in present_textures {
        state.present_textures[i] = texture
    }
    return state
}

// Emit the barriers moving every resource this command buffer uses from the state
// the device was left in to the state the buffer starts from. The device state is
// only read: it advances at submit, once this recording is queued.
vk_record_commands_emit_initial_barriers :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    initial_buffers := &cmdbuf.initial_buffers
    clear(initial_buffers)
    initial_textures := &cmdbuf.initial_textures
    clear(initial_textures)

    // The device state is read here, but `prepare` also grows and rewrites it,
    // so recording takes the exclusive lock. Recording into the command buffer
    // itself stays outside it.
    {
        sync.guard(&device_impl.trackers_mtx)

        index: Tracker_Index
        it_b: Metadata_Index_Iterator(Buffer)
        metadata_index_iterator_init(&it_b, &cmdbuf.tracker.buffers.metadata)
        for metadata_index_iterator_next(&it_b, &index) {
            buffer := resource_metadata_get(&cmdbuf.tracker.buffers.metadata, index)
            device_buffer_tracker_prepare(&device_impl.trackers.buffers, index, buffer)
            provider := Buffer_State_Provider {
                state = cmdbuf.tracker.buffers.start[:],
            }
            buffer_barrier(
                device_impl.trackers.buffers.current[:],
                index,
                buffer,
                provider,
                initial_buffers,
                device_impl.trackers.buffers.ordered,
            )
        }

        it_t: Metadata_Index_Iterator(Tracked_Texture)
        metadata_index_iterator_init(&it_t, &cmdbuf.tracker.textures.metadata)
        for metadata_index_iterator_next(&it_t, &index) {
            texture := resource_metadata_get(&cmdbuf.tracker.textures.metadata, index)
            device_texture_tracker_prepare(&device_impl.trackers.textures, index, texture)
            texture_barrier(
                &device_impl.trackers.textures.current,
                index,
                texture,
                texture_state_provider_set(&cmdbuf.tracker.textures.start),
                initial_textures,
                device_impl.trackers.textures.ordered,
                true,
            )
        }
    }

    vk_encode_barriers(device_impl, cmdbuf, initial_textures^[:], initial_buffers^[:], loc)
}

// Encode the transitions a scope fold left pending, then clear them. Used by
// immediate verbs that need their barriers before their own command.
vk_flush_pending_transitions :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    buffer_transitions := cmdbuf.tracker.buffers.temp[:]
    texture_transitions := cmdbuf.tracker.textures.temp[:]
    if len(buffer_transitions) == 0 && len(texture_transitions) == 0 {
        return
    }

    vk_encode_barriers(device_impl, cmdbuf, texture_transitions, buffer_transitions, loc)

    buffer_tracker_clear_pending(&cmdbuf.tracker.buffers)
    texture_tracker_clear_pending(&cmdbuf.tracker.textures)
}

// Emit this recording's initial barriers once, before its first command.
vk_command_encoder_prepare :: proc(cmdbuf: ^VK_Command_Buffer_Impl, loc := #caller_location) {
    if cmdbuf.did_prepare {
        return
    }
    device_impl := vk_device_get_impl(cmdbuf.device, loc)
    vk_record_commands_emit_initial_barriers(device_impl, cmdbuf, loc)
    cmdbuf.did_prepare = true
}

// Issue every command recorded since the last call, in order. This is what makes
// recording immediate: verbs call it as they go instead of leaving a transcript
// for submit.
vk_execute_pending :: proc(
    device: Device,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    vk_command_encoder_prepare(cmdbuf, loc)
    vk_record_commands_run(device, cmdbuf, loc)
}

vk_record_commands_run :: proc(
    device: Device,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) {
    ensure(cmdbuf != nil, "invalid command buffer", loc)

    device_impl := vk_device_get_impl(device, loc)

    // Compute pass state: the bound pipeline's layout and the bind groups
    // assigned to it, flushed before each dispatch.
    compute_layout: Pipeline_Layout
    compute_bind_group_slots: [MAX_BIND_GROUPS]VK_Bind_Group_Slot
    active_compute_query_set: Query_Set
    active_compute_query_index: u32

    LOOP: for curr in array_iterate_by_ptr(&cmdbuf.commands.iterator) {
        #partial switch &cmd in curr {
        case Begin_Compute_Pass_Cmd:
            vk_encode_barriers(
                device_impl,
                cmdbuf,
                cmd.texture_transitions,
                cmd.buffer_transitions,
                cmd.loc,
            )

            compute_layout = {}
            compute_bind_group_slots = {}

            if cmd.timestamp_writes.query_set != {} {
                vk_record_write_timestamp(
                    device_impl,
                    cmdbuf,
                    cmd.timestamp_writes.query_set,
                    cmd.timestamp_writes.beginning_of_pass_write_index,
                    {.TOP_OF_PIPE},
                    cmd.loc,
                )
            }

        case End_Compute_Pass_Cmd:
            compute_layout = {}
            compute_bind_group_slots = {}

        case Set_Compute_Pipeline_Cmd:
            pipeline_impl := vk_compute_pipeline_get_impl(cmd.pipeline, cmd.loc)
            device_impl.fp.CmdBindPipeline(
                cmdbuf.current_cmdbuf,
                .COMPUTE,
                pipeline_impl.vk_pipeline,
            )
            compute_layout = pipeline_impl.layout

        case Set_Bind_Group_Cmd:
            assert(cmd.index < MAX_BIND_GROUPS, "Bind group index out of range", cmd.loc)

            slot := &compute_bind_group_slots[cmd.index]
            if cmd.bind_group == {} {
                slot^ = {}
            } else {
                slot.group = cmd.bind_group
                slot.dynamic_offsets = cmd.dynamic_offsets
                slot.assigned = true
                slot.bound_layout = {}
                // The flush reads the cached set rather than probing per dispatch.
                slot.descriptor_set =
                    vk_bind_group_get_impl(cmd.bind_group, cmd.loc).descriptor_set.raw
            }

        case Dispatch_Workgroups_Cmd:
            vk_flush_bind_groups(
                device_impl,
                cmdbuf,
                &compute_bind_group_slots,
                compute_layout,
                compute_layout != {} ? vk_pipeline_layout_get_impl(compute_layout, cmd.loc) : nil,
                .COMPUTE,
                cmd.loc,
            )
            device_impl.fp.CmdDispatch(
                cmdbuf.current_cmdbuf,
                cmd.workgroup_count_x,
                cmd.workgroup_count_y,
                cmd.workgroup_count_z,
            )

        case Dispatch_Workgroups_Indirect_Cmd:
            vk_flush_bind_groups(
                device_impl,
                cmdbuf,
                &compute_bind_group_slots,
                compute_layout,
                compute_layout != {} ? vk_pipeline_layout_get_impl(compute_layout, cmd.loc) : nil,
                .COMPUTE,
                cmd.loc,
            )
            buffer_impl := vk_buffer_get_impl(cmd.indirect_buffer, cmd.loc)
            device_impl.fp.CmdDispatchIndirect(
                cmdbuf.current_cmdbuf,
                buffer_impl.vk_buffer,
                vk.DeviceSize(cmd.indirect_offset),
            )

        case Set_Immediate_Cmd:
            if compute_layout != {} {
                layout_impl := vk_pipeline_layout_get_impl(compute_layout, cmd.loc)
                device_impl.fp.CmdPushConstants(
                    cmdbuf.current_cmdbuf,
                    layout_impl.raw,
                    {.COMPUTE},
                    cmd.offset,
                    u32(len(cmd.data)),
                    raw_data(cmd.data) if len(cmd.data) > 0 else nil,
                )
            }

        case Push_Debug_Group_Cmd:
            unimplemented(loc = cmd.loc)

        case Pop_Debug_Group_Cmd:
            unimplemented(loc = cmd.loc)

        case Insert_Debug_Marker_Cmd:
            unimplemented(loc = cmd.loc)

        case Write_Timestamp_Cmd:
            vk_record_write_timestamp(
                device_impl,
                cmdbuf,
                cmd.query_set,
                cmd.query_index,
                loc = cmd.loc,
            )

        case Begin_Occlusion_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case End_Occlusion_Query_Cmd:
            unimplemented(loc = cmd.loc)

        case Begin_Pipeline_Statistics_Query_Cmd:
            if active_compute_query_set != {} {
                vk_record_end_query(
                    device_impl,
                    cmdbuf,
                    active_compute_query_set,
                    active_compute_query_index,
                    cmd.loc,
                )
            }
            active_compute_query_set = cmd.query_set
            active_compute_query_index = cmd.query_index
            vk_record_begin_query(
                device_impl,
                cmdbuf,
                active_compute_query_set,
                active_compute_query_index,
                cmd.loc,
            )

        case End_Pipeline_Statistics_Query_Cmd:
            if active_compute_query_set != {} {
                vk_record_end_query(
                    device_impl,
                    cmdbuf,
                    active_compute_query_set,
                    active_compute_query_index,
                    cmd.loc,
                )
                active_compute_query_set = {}
            }

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

            device_impl.fp.CmdCopyBuffer(
                cmdbuf.current_cmdbuf,
                src_impl.vk_buffer,
                dst_impl.vk_buffer,
                1,
                &copy_region,
            )
            buffer_init_tracker_mark_initialized(
                &dst_impl.init,
                cmd.dst_offset,
                cmd.dst_offset + cmd.size,
            )

        case Copy_Buffer_To_Texture_Cmd:
            src_impl := vk_buffer_get_impl(cmd.src.buffer, cmd.loc)
            dst_impl := vk_texture_get_impl(cmd.dst.texture, cmd.loc)

            block_width, block_height := texture_format_block_dimensions(dst_impl.format)
            block_size := texture_format_block_copy_size(dst_impl.format, cmd.dst.aspect)

            is_3d := dst_impl.dimension == .D3

            copy_region := vk.BufferImageCopy {
                bufferOffset = vk.DeviceSize(cmd.src.layout.offset),
                bufferRowLength = (cmd.src.layout.bytes_per_row / block_size) * block_width,
                bufferImageHeight = cmd.src.layout.rows_per_image * block_height,
                imageSubresource = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(
                        cmd.dst.aspect,
                        dst_impl.format,
                    ),
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

            device_impl.fp.CmdCopyBufferToImage(
                cmdbuf.current_cmdbuf,
                src_impl.vk_buffer,
                dst_impl.vk_image,
                .TRANSFER_DST_OPTIMAL,
                1,
                &copy_region,
            )

            dst_layers := u32(1) if is_3d else cmd.size.depth_or_array_layers
            dst_base_layer := u32(0) if is_3d else cmd.dst.origin.z
            init_range := Texture_Init_Range {
                mip_start   = cmd.dst.mip_level,
                mip_end     = cmd.dst.mip_level + 1,
                layer_start = dst_base_layer,
                layer_end   = dst_base_layer + dst_layers,
            }
            aspects := init_tracked_aspects(dst_impl.format, cmd.dst.aspect)
            for i in 0 ..< aspects.count {
                texture_init_tracker_mark_initialized(&dst_impl.init, init_range, aspects.slots[i])
            }

        case Copy_Texture_To_Buffer_Cmd:
            src_impl := vk_texture_get_impl(cmd.src.texture, cmd.loc)
            dst_impl := vk_buffer_get_impl(cmd.dst.buffer, cmd.loc)

            block_width, block_height := texture_format_block_dimensions(src_impl.format)
            block_size := texture_format_block_copy_size(src_impl.format, cmd.src.aspect)

            is_3d := src_impl.dimension == .D3

            copy_region := vk.BufferImageCopy {
                bufferOffset = vk.DeviceSize(cmd.dst.layout.offset),
                bufferRowLength = (cmd.dst.layout.bytes_per_row / block_size) * block_width,
                bufferImageHeight = cmd.dst.layout.rows_per_image * block_height,
                imageSubresource = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(
                        cmd.src.aspect,
                        src_impl.format,
                    ),
                    mipLevel       = cmd.src.mip_level,
                    baseArrayLayer = is_3d ? 0 : cmd.src.origin.z,
                    layerCount     = is_3d ? 1 : cmd.size.depth_or_array_layers,
                },
                imageOffset = vk.Offset3D {
                    x = i32(cmd.src.origin.x),
                    y = i32(cmd.src.origin.y),
                    z = is_3d ? i32(cmd.src.origin.z) : 0,
                },
                imageExtent = vk.Extent3D {
                    width  = cmd.size.width,
                    height = cmd.size.height,
                    depth  = is_3d ? cmd.size.depth_or_array_layers : 1,
                },
            }

            device_impl.fp.CmdCopyImageToBuffer(
                cmdbuf.current_cmdbuf,
                src_impl.vk_image,
                .TRANSFER_SRC_OPTIMAL,
                dst_impl.vk_buffer,
                1,
                &copy_region,
            )

        case Copy_Texture_To_Texture_Cmd:
            src_impl := vk_texture_get_impl(cmd.src.texture, cmd.loc)
            dst_impl := vk_texture_get_impl(cmd.dst.texture, cmd.loc)

            is_3d := dst_impl.dimension == .D3

            copy_region := vk.ImageCopy {
                srcSubresource = vk.ImageSubresourceLayers {
                    aspectMask     = vk_conv_to_image_aspect_flags(
                        cmd.src.aspect,
                        src_impl.format,
                    ),
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
                    aspectMask     = vk_conv_to_image_aspect_flags(
                        cmd.dst.aspect,
                        dst_impl.format,
                    ),
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
            device_impl.fp.CmdCopyImage(
                cmdbuf.current_cmdbuf,
                src_impl.vk_image,
                .TRANSFER_SRC_OPTIMAL,
                dst_impl.vk_image,
                .TRANSFER_DST_OPTIMAL,
                1,
                &copy_region,
            )

        case Clear_Buffer_Cmd:
            vk_record_clear_buffer(device_impl, cmdbuf.current_cmdbuf, cmd, cmd.loc)

        case Clear_Texture_Cmd:
            unimplemented(loc = cmd.loc)

        case Build_Acceleration_Structures_Cmd:
            unimplemented(loc = cmd.loc)

        case Resolve_Query_Set_Cmd:
            vk_record_resolve_query_set(device_impl, cmdbuf, cmd, cmd.loc)

        case Transition_Buffer_Cmd:
            vk_record_transition_buffer(
                device_impl,
                cmdbuf.current_cmdbuf,
                cmd.buffer,
                cmd.state_from,
                cmd.state_to,
                cmd.loc,
            )

        case Transition_Texture_Cmd:
            // Both states were captured at encode time; the device tracker is
            // not read or written here because the initial drain already
            // advanced it to the end state.
            vk_record_transition_texture(
                device_impl,
                cmdbuf.current_cmdbuf,
                cmd.texture,
                cmd.selector,
                cmd.state_from,
                cmd.state_to,
                cmd.force_barrier,
                cmd.loc,
            )
        }
    }

    // Fold this buffer's query writes into their sets, so a later submission
    // resolving the same slots treats them as initialized.
    vk_commit_query_writes(cmdbuf, loc)
}
