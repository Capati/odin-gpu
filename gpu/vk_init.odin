#+build !js
package gpu

// Vendor
import vk "vendor:vulkan"

vk_init_texture_selector :: #force_inline proc "contextless" (
    range: Texture_Init_Range,
) -> Texture_Selector {
    return {
        mip_start   = range.mip_start,
        mip_count   = range.mip_end - range.mip_start,
        layer_start = range.layer_start,
        layer_count = range.layer_end - range.layer_start,
    }
}

vk_init_subresource_range :: proc(
    format: Texture_Format,
    selector: Texture_Selector,
    aspect: Texture_Aspect,
) -> vk.ImageSubresourceRange {
    return {
        aspectMask     = vk_conv_to_image_aspect_flags(aspect, format),
        baseMipLevel   = selector.mip_start,
        levelCount     = selector.mip_count,
        baseArrayLayer = selector.layer_start,
        layerCount     = selector.layer_count,
    }
}

// Clears a range whose layout is already `TRANSFER_DST_OPTIMAL`. Formats a clear
// command cannot address (compressed, multi-planar) keep their contents.
@(private)
vk_init_clear_texture_range :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: vk.CommandBuffer,
    texture_impl: ^VK_Texture_Impl,
    selector: Texture_Selector,
    aspect: Texture_Aspect,
    loc := #caller_location,
) {
    if texture_format_is_compressed(texture_impl.format) ||
       texture_format_is_multi_planar(texture_impl.format) {
        return
    }

    range := vk_init_subresource_range(texture_impl.format, selector, aspect)
    if texture_impl.dimension == .D3 {
        range.baseArrayLayer = 0
        range.layerCount = 1
    }

    if texture_format_has_depth_aspect(texture_impl.format) ||
       texture_format_has_stencil_aspect(texture_impl.format) {
        value := vk.ClearDepthStencilValue {
            depth   = 0,
            stencil = 0,
        }
        device_impl.fp.CmdClearDepthStencilImage(
            cmdbuf,
            texture_impl.vk_image,
            .TRANSFER_DST_OPTIMAL,
            &value,
            1,
            &range,
        )
        return
    }

    value: vk.ClearColorValue
    device_impl.fp.CmdClearColorImage(
        cmdbuf,
        texture_impl.vk_image,
        .TRANSFER_DST_OPTIMAL,
        &value,
        1,
        &range,
    )
}

// Drains the undefined ranges of one aspect slot and clears them. The caller
// guarantees the image is in `TRANSFER_DST_OPTIMAL`.
@(private)
vk_init_clear_texture_undefined_per_slot :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    texture_impl: ^VK_Texture_Impl,
    range: Texture_Init_Range,
    aspect: Texture_Aspect,
    loc := #caller_location,
) {
    aspects := init_tracked_aspects(texture_impl.format, aspect)
    for i in 0 ..< aspects.count {
        clear(&cmdbuf.init_texture_ranges)
        texture_init_tracker_drain_uninitialized(
            &texture_impl.init,
            range,
            &cmdbuf.init_texture_ranges,
            aspects.slots[i],
        )
        clear_aspect := init_aspect_for_slot(texture_impl.format, aspects.slots[i])
        for missing in cmdbuf.init_texture_ranges {
            vk_init_clear_texture_range(
                device_impl,
                cmdbuf.current_cmdbuf,
                texture_impl,
                vk_init_texture_selector(missing),
                clear_aspect,
                loc,
            )
        }
    }
    clear(&cmdbuf.init_texture_ranges)
}

@(private)
vk_init_transfer_write_barrier :: proc(device_impl: ^VK_Device_Impl, cmdbuf: vk.CommandBuffer) {
    barrier := vk.MemoryBarrier {
        sType         = .MEMORY_BARRIER,
        srcAccessMask = {.TRANSFER_WRITE},
        dstAccessMask = {.TRANSFER_WRITE},
    }
    device_impl.fp.CmdPipelineBarrier(
        cmdbuf,
        {.TRANSFER},
        {.TRANSFER},
        {},
        1,
        &barrier,
        0,
        nil,
        0,
        nil,
    )
}

@(private)
vk_init_fill_buffer_holes :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    buffer: Buffer,
    buffer_impl: ^VK_Buffer_Impl,
    start, end: u64,
    loc := #caller_location,
) {
    clear(&cmdbuf.init_buffer_ranges)
    buffer_init_tracker_drain_uninitialized(
        &buffer_impl.init,
        start,
        end,
        &cmdbuf.init_buffer_ranges,
    )

    if len(cmdbuf.init_buffer_ranges) == 0 {
        return
    }

    for hole in cmdbuf.init_buffer_ranges {
        fill_start := hole.start & ~u64(3)
        fill_end := (hole.end + 3) & ~u64(3)
        if fill_end > u64(buffer_impl.vk_size) {
            fill_end = u64(buffer_impl.vk_size)
        }
        if fill_start >= fill_end {
            continue
        }
        device_impl.fp.CmdFillBuffer(
            cmdbuf.current_cmdbuf,
            buffer_impl.vk_buffer,
            vk.DeviceSize(fill_start),
            vk.DeviceSize(fill_end - fill_start),
            0,
        )
    }
    vk_init_transfer_write_barrier(device_impl, cmdbuf.current_cmdbuf)
    clear(&cmdbuf.init_buffer_ranges)
}

// Applies the init actions recorded by a command buffer at submit time, after
// the pending writes have flushed, and returns a one-shot clear buffer to insert
// before the recording's own buffers.
vk_apply_pending_init_actions_at_submit :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    loc := #caller_location,
) -> vk.CommandBuffer {
    if len(cmdbuf.tracker.init_actions) == 0 && len(cmdbuf.tracker.buffer_init_actions) == 0 {
        return {}
    }

    clear_buffer := vk_command_buffer_allocate_recording(device_impl, cmdbuf, loc)
    saved_cmdbuf := cmdbuf.current_cmdbuf
    cmdbuf.current_cmdbuf = clear_buffer

    for action in cmdbuf.tracker.init_actions {
        texture_impl := vk_texture_get_impl(action.texture, loc)
        aspects := init_tracked_aspects(texture_impl.format, action.aspect)

        #partial switch action.kind {
        case .Implicitly_Initialized:
            for i in 0 ..< aspects.count {
                texture_init_tracker_mark_initialized(
                    &texture_impl.init,
                    action.range,
                    aspects.slots[i],
                )
            }
        case .Discarded:
            for i in 0 ..< aspects.count {
                texture_init_tracker_mark_uninitialized(
                    &texture_impl.init,
                    action.range,
                    aspects.slots[i],
                )
            }
        case .Needs_Initialized_Memory:
            for i in 0 ..< aspects.count {
                clear(&cmdbuf.init_texture_ranges)
                texture_init_tracker_drain_uninitialized(
                    &texture_impl.init,
                    action.range,
                    &cmdbuf.init_texture_ranges,
                    aspects.slots[i],
                )
                clear_aspect := init_aspect_for_slot(texture_impl.format, aspects.slots[i])

                for missing in cmdbuf.init_texture_ranges {
                    selector := vk_init_texture_selector(missing)

                    before := [1]Texture_State_Transition {
                        {
                            texture  = action.texture,
                            selector = selector,
                            from     = TEXTURE_USES_UNINITIALIZED,
                            to       = TEXTURE_USES_COPY_DST,
                        },
                    }
                    vk_encode_barriers(device_impl, cmdbuf, before[:], nil, loc)

                    vk_init_clear_texture_range(
                        device_impl,
                        cmdbuf.current_cmdbuf,
                        texture_impl,
                        selector,
                        clear_aspect,
                        loc,
                    )
                }
            }
        }
    }

    for action in cmdbuf.tracker.buffer_init_actions {
        buffer_impl := vk_buffer_get_impl(action.buffer, loc)

        #partial switch action.kind {
        case .Implicitly_Initialized:
            buffer_init_tracker_mark_initialized(
                &buffer_impl.init,
                action.range.start,
                action.range.end,
            )
        case .Discarded:
            buffer_init_tracker_mark_uninitialized(
                &buffer_impl.init,
                action.range.start,
                action.range.end,
            )
        case .Needs_Initialized_Memory:
            clear(&cmdbuf.init_buffer_ranges)
            buffer_init_tracker_drain_uninitialized(
                &buffer_impl.init,
                action.range.start,
                action.range.end,
                &cmdbuf.init_buffer_ranges,
            )
            if len(cmdbuf.init_buffer_ranges) == 0 {
                continue
            }

            before := [1]Buffer_State_Transition {
                {
                    buffer = action.buffer,
                    from   = {},
                    to     = BUFFER_USES_COPY_DST,
                },
            }
            vk_encode_barriers(device_impl, cmdbuf, nil, before[:], loc)

            for hole in cmdbuf.init_buffer_ranges {
                fill_start := hole.start & ~u64(3)
                fill_end := (hole.end + 3) & ~u64(3)
                if fill_end > u64(buffer_impl.vk_size) {
                    fill_end = u64(buffer_impl.vk_size)
                }
                if fill_start >= fill_end {
                    continue
                }
                device_impl.fp.CmdFillBuffer(
                    cmdbuf.current_cmdbuf,
                    buffer_impl.vk_buffer,
                    vk.DeviceSize(fill_start),
                    vk.DeviceSize(fill_end - fill_start),
                    0,
                )
            }
            clear(&cmdbuf.init_buffer_ranges)
        }
    }

    vk_check(device_impl.fp.EndCommandBuffer(clear_buffer), loc = loc)
    cmdbuf.current_cmdbuf = saved_cmdbuf

    clear(&cmdbuf.tracker.init_actions)
    clear(&cmdbuf.tracker.buffer_init_actions)
    return clear_buffer
}
