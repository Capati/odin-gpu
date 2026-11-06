#+build !js
package gpu

// Core
import intr "base:intrinsics"

// Vendor
import vk "vendor:vulkan"

// Vulkan resource-state encoding.
//
// The tracker speaks in abstract use sets; this file turns them into the image
// layouts, access masks, pipeline stages and memory barriers Vulkan needs. It is
// the only place that maps a use set to a barrier, so a layout or access change
// lands in one file.

VK_Stage_Access :: struct {
    stage:  vk.PipelineStageFlags,
    access: vk.AccessFlags,
}

@(private = "file")
vk_image_layout_get_stage_access :: #force_inline proc "contextless" (
    layout: vk.ImageLayout,
    queue_flags: vk.QueueFlags,
    loc := #caller_location,
) -> VK_Stage_Access {
    shader_stages := vk_shader_stages(queue_flags)

    #partial switch layout {
    case .UNDEFINED:
        return {stage = {.TOP_OF_PIPE}, access = {}}
    case .COLOR_ATTACHMENT_OPTIMAL:
        return {
            stage  = {.COLOR_ATTACHMENT_OUTPUT},
            access = {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
        }
    case .DEPTH_STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .DEPTH_ATTACHMENT_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS},
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        }
    case .DEPTH_STENCIL_READ_ONLY_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {.DEPTH_STENCIL_ATTACHMENT_READ, .SHADER_READ},
        }
    case .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {
                .DEPTH_STENCIL_ATTACHMENT_READ,
                .DEPTH_STENCIL_ATTACHMENT_WRITE,
                .SHADER_READ,
            },
        }
    case .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL:
        return {
            stage  = {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS} | shader_stages,
            access = {
                .DEPTH_STENCIL_ATTACHMENT_READ,
                .DEPTH_STENCIL_ATTACHMENT_WRITE,
                .SHADER_READ,
            },
        }
    case .SHADER_READ_ONLY_OPTIMAL:
        return {
            stage  = shader_stages,
            access = {.SHADER_READ},
        }
    case .TRANSFER_SRC_OPTIMAL:
        return {stage = {.TRANSFER}, access = {.TRANSFER_READ}}
    case .TRANSFER_DST_OPTIMAL:
        return {stage = {.TRANSFER}, access = {.TRANSFER_WRITE}}
    case .GENERAL:
        return {
            stage  = {.COMPUTE_SHADER, .TRANSFER},
            access = {.SHADER_READ, .SHADER_WRITE, .TRANSFER_READ, .TRANSFER_WRITE},
        }
    case .PRESENT_SRC_KHR:
        return {stage = {.BOTTOM_OF_PIPE}, access = {}}
    case:
        panic_contextless("Unsupported image layout transition!", loc)
    }
}

vk_access_for_texture_uses :: proc "contextless" (uses: Texture_Uses) -> vk.AccessFlags {
    access: vk.AccessFlags
    if .Copy_Dst in uses {
        access |= {.TRANSFER_WRITE}
    }
    if .Copy_Src in uses {
        access |= {.TRANSFER_READ}
    }
    if uses & (Texture_Uses{.Resource, .Depth_Sampled, .Stencil_Sampled}) != {} {
        access |= {.SHADER_READ}
    }
    if .Storage_Read_Only in uses {
        access |= {.SHADER_READ}
    }
    if .Storage_Write_Only in uses {
        access |= {.SHADER_WRITE}
    }
    if uses & (Texture_Uses{.Storage_Read_Write, .Storage_Atomic}) != {} {
        access |= {.SHADER_READ, .SHADER_WRITE}
    }
    if .Color_Target in uses {
        access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }
    if uses & {.Depth_Read, .Depth_Write, .Stencil_Read, .Stencil_Write} != {} {
        // Read uses also write when store-op-none is unsupported: the read-only
        // aspect still stores at pass end.
        access |= {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}
    }
    return access
}

vk_stage_for_texture_uses :: proc "contextless" (
    uses: Texture_Uses,
    queue_flags: vk.QueueFlags,
) -> vk.PipelineStageFlags {
    stage: vk.PipelineStageFlags
    if uses & (Texture_Uses{.Copy_Src, .Copy_Dst}) != {} {
        stage |= {.TRANSFER}
    }
    shader_stages: Texture_Uses = {
        .Resource,
        .Depth_Sampled,
        .Stencil_Sampled,
        .Storage_Read_Only,
        .Storage_Write_Only,
        .Storage_Read_Write,
        .Storage_Atomic,
    }
    if uses & shader_stages != {} {
        stage |= vk_shader_stages(queue_flags)
    }
    if .Color_Target in uses {
        stage |= {.COLOR_ATTACHMENT_OUTPUT}
    }
    fragment_tests: Texture_Uses = {
        .Depth_Read,
        .Depth_Write,
        .Stencil_Read,
        .Stencil_Write,
    }
    if uses & fragment_tests != {} {
        stage |= {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS}
    }
    if stage == {} {
        stage = {.TOP_OF_PIPE}
    }
    return stage
}

@(private)
vk_texture_transition_layout :: proc(
    device: ^VK_Device_Impl,
    texture: ^VK_Texture_Impl,
    vk_command_buffer: vk.CommandBuffer,
    state_from: Texture_Uses,
    state_to: Texture_Uses,
    subresource_range: vk.ImageSubresourceRange,
    loc := #caller_location,
) {
    // Both layouts come from the tracker states, so they are always specific
    // (`.ATTACHMENT_OPTIMAL` never appears) and never need normalizing.
    old_image_layout := vk_conv_texture_uses_to_image_layout(state_from)
    new_image_layout := vk_conv_texture_uses_to_image_layout(state_to)

    if old_image_layout == new_image_layout {
        return // no-op
    }

    is_depth_attachment := vk_image_usage_flags_is_depth_attachment(texture.vk_usage_flags)

    src_stage := vk_stage_for_texture_uses(state_from, device.queue_flags)
    dst_stage := vk_stage_for_texture_uses(state_to, device.queue_flags)
    src_access := vk_access_for_texture_uses(state_from)
    dst_access := vk_access_for_texture_uses(state_to)

    if is_depth_attachment && texture.is_resolve_attachment {
        // https://registry.khronos.org/vulkan/specs/latest/html/vkspec.html#renderpass-resolve-operations
        src_stage |= {.COLOR_ATTACHMENT_OUTPUT}
        dst_stage |= {.COLOR_ATTACHMENT_OUTPUT}
        src_access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
        dst_access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }

    barrier := vk.ImageMemoryBarrier {
        sType               = .IMAGE_MEMORY_BARRIER,
        srcAccessMask       = src_access,
        dstAccessMask       = dst_access,
        oldLayout           = old_image_layout,
        newLayout           = new_image_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = texture.vk_image,
        subresourceRange    = subresource_range,
    }

    intr.atomic_add(&device.barrier_calls, 1)
    device.fp.CmdPipelineBarrier(
        commandBuffer = vk_command_buffer,
        srcStageMask = src_stage,
        dstStageMask = dst_stage,
        dependencyFlags = {},
        memoryBarrierCount = 0,
        pMemoryBarriers = nil,
        bufferMemoryBarrierCount = 0,
        pBufferMemoryBarriers = nil,
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers = &barrier,
    )
}

@(private)
vk_texture_barrier :: proc "contextless" (
    device: ^VK_Device_Impl,
    texture: ^VK_Texture_Impl,
    vk_command_buffer: vk.CommandBuffer,
    layout: vk.ImageLayout,
    subresource_range: vk.ImageSubresourceRange,
    loc := #caller_location,
) {
    is_depth_attachment := vk_image_usage_flags_is_depth_attachment(texture.vk_usage_flags)

    resolved_layout := layout
    if resolved_layout == .ATTACHMENT_OPTIMAL {
        resolved_layout =
            is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
    }

    stage_access := vk_image_layout_get_stage_access(resolved_layout, device.queue_flags)

    if is_depth_attachment && texture.is_resolve_attachment {
        stage_access.stage |= {.COLOR_ATTACHMENT_OUTPUT}
        stage_access.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
    }

    barrier := vk.ImageMemoryBarrier {
        sType               = .IMAGE_MEMORY_BARRIER,
        srcAccessMask       = stage_access.access,
        dstAccessMask       = stage_access.access,
        oldLayout           = resolved_layout,
        newLayout           = resolved_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = texture.vk_image,
        subresourceRange    = subresource_range,
    }

    intr.atomic_add(&device.barrier_calls, 1)
    vk.CmdPipelineBarrier(
        commandBuffer = vk_command_buffer,
        srcStageMask = stage_access.stage,
        dstStageMask = stage_access.stage,
        dependencyFlags = {},
        memoryBarrierCount = 0,
        pMemoryBarriers = nil,
        bufferMemoryBarrierCount = 0,
        pBufferMemoryBarriers = nil,
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers = &barrier,
    )
}

// Fuses a set of tracker transitions into one `vkCmdPipelineBarrier`. Stage masks
// are the union of every barrier's stages (slightly over-synchronising); access
// masks stay per barrier.
//
// Transitions that need nothing are dropped here: an unchanged state, an unset
// source and the tracker's `Unknown` marker never reach Vulkan.
@(private)
vk_encode_barriers :: proc(
    device_impl: ^VK_Device_Impl,
    cmdbuf: ^VK_Command_Buffer_Impl,
    texture_transitions: []Texture_State_Transition,
    buffer_transitions: []Buffer_State_Transition,
    loc := #caller_location,
) {
    if len(texture_transitions) == 0 && len(buffer_transitions) == 0 {
        return
    }

    // Scratch lives on the command buffer: no per-frame allocation.
    image_barriers := &cmdbuf.image_barriers
    buffer_barriers := &cmdbuf.buffer_barriers
    clear(image_barriers)
    clear(buffer_barriers)

    src_stage: vk.PipelineStageFlags
    dst_stage: vk.PipelineStageFlags

    for &tr in buffer_transitions {
        if tr.from == {} {
            continue
        }

        buffer_impl := vk_buffer_get_impl(tr.buffer, loc)
        src_part, src_access := vk_conv_buffer_uses_to_barrier(tr.from, device_impl.queue_flags)
        dst_part, dst_access := vk_conv_buffer_uses_to_barrier(tr.to, device_impl.queue_flags)
        skip_dst_access := vk.AccessFlags {
            .TRANSFER_WRITE,
            .SHADER_WRITE,
            .HOST_WRITE,
            .ACCELERATION_STRUCTURE_WRITE_KHR,
        }
        if tr.from == tr.to && dst_access & skip_dst_access == {} {
            continue
        }
        if src_part == {} {
            src_part = {.TOP_OF_PIPE}
        }
        if dst_part == {} {
            dst_part = {.BOTTOM_OF_PIPE}
        }
        src_stage |= src_part
        dst_stage |= dst_part

        append(buffer_barriers, vk.BufferMemoryBarrier {
            sType               = .BUFFER_MEMORY_BARRIER,
            srcAccessMask       = src_access,
            dstAccessMask       = dst_access,
            srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            buffer              = buffer_impl.vk_buffer,
            offset              = 0,
            size                = vk.DeviceSize(vk.WHOLE_SIZE),
        })
    }

    for &tr in texture_transitions {
        if tr.from == tr.to || tr.from == {} || tr.from == TEXTURE_USES_UNKNOWN {
            continue
        }

        texture_impl := vk_texture_get_impl(tr.texture, loc)

        // An acquired swapchain image may still be UNDEFINED (first use after
        // creation) or PRESENT. Vulkan allows oldLayout = UNDEFINED in both
        // cases, while claiming PRESENT against an undefined image is invalid.
        from_state := tr.from
        if texture_impl.is_swapchain && from_state == TEXTURE_USES_PRESENT {
            from_state = TEXTURE_USES_UNINITIALIZED
        }

        old_layout := vk_conv_texture_uses_to_image_layout(from_state)
        new_layout := vk_conv_texture_uses_to_image_layout(tr.to)
        if old_layout == new_layout {
            continue
        }

        src := vk_image_layout_get_stage_access(old_layout, device_impl.queue_flags)
        dst := vk_image_layout_get_stage_access(new_layout, device_impl.queue_flags)
        if vk_image_usage_flags_is_depth_attachment(texture_impl.vk_usage_flags) &&
           texture_impl.is_resolve_attachment {
            src.stage |= {.COLOR_ATTACHMENT_OUTPUT}
            dst.stage |= {.COLOR_ATTACHMENT_OUTPUT}
            src.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
            dst.access |= {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE}
        }
        src_stage |= src.stage
        dst_stage |= dst.stage

        append(image_barriers, vk.ImageMemoryBarrier {
            sType = .IMAGE_MEMORY_BARRIER,
            srcAccessMask = src.access,
            dstAccessMask = dst.access,
            oldLayout = old_layout,
            newLayout = new_layout,
            srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            image = texture_impl.vk_image,
            subresourceRange = {
                aspectMask     = vk_conv_to_image_aspect_flags(.All, texture_impl.format),
                baseMipLevel   = tr.selector.mip_start,
                levelCount     = tr.selector.mip_count,
                baseArrayLayer = tr.selector.layer_start,
                layerCount     = tr.selector.layer_count,
            },
        })
    }

    if len(image_barriers^) == 0 && len(buffer_barriers^) == 0 {
        return
    }
    if src_stage == {} {
        src_stage = {.TOP_OF_PIPE}
    }
    if dst_stage == {} {
        dst_stage = {.BOTTOM_OF_PIPE}
    }

    intr.atomic_add(&device_impl.barrier_calls, 1)
    device_impl.fp.CmdPipelineBarrier(
        commandBuffer = cmdbuf.current_cmdbuf,
        srcStageMask = src_stage,
        dstStageMask = dst_stage,
        dependencyFlags = {},
        memoryBarrierCount = 0,
        pMemoryBarriers = nil,
        bufferMemoryBarrierCount = u32(len(buffer_barriers^)),
        pBufferMemoryBarriers = raw_data(buffer_barriers^[:]) if len(buffer_barriers^) > 0 else nil,
        imageMemoryBarrierCount = u32(len(image_barriers^)),
        pImageMemoryBarriers = raw_data(image_barriers^[:]) if len(image_barriers^) > 0 else nil,
    )
}

@(private)
vk_command_buffer_barrier :: proc "contextless" (
    device: ^VK_Device_Impl,
    command_buffer: vk.CommandBuffer,
    buffer: vk.Buffer,
    state_from: Buffer_Uses,
    state_to: Buffer_Uses,
    offset: vk.DeviceSize = 0,
    size: vk.DeviceSize = vk.DeviceSize(WHOLE_SIZE),
    loc := #caller_location,
) {
    src_stage, src_access := vk_conv_buffer_uses_to_barrier(state_from, device.queue_flags)
    dst_stage, dst_access := vk_conv_buffer_uses_to_barrier(state_to, device.queue_flags)

    // Note: this is done so that we never end up with empty stage flags
    if src_stage == {} {
        src_stage = {.TOP_OF_PIPE}
    }
    if dst_stage == {} {
        dst_stage = {.BOTTOM_OF_PIPE}
    }

    barrier := vk.BufferMemoryBarrier {
        sType               = .BUFFER_MEMORY_BARRIER,
        srcAccessMask       = src_access,
        dstAccessMask       = dst_access,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        buffer              = buffer,
        offset              = offset,
        size                = size,
    }

    intr.atomic_add(&device.barrier_calls, 1)
    device.fp.CmdPipelineBarrier(
        commandBuffer = command_buffer,
        srcStageMask = src_stage,
        dstStageMask = dst_stage,
        dependencyFlags = {},
        memoryBarrierCount = 0,
        pMemoryBarriers = nil,
        bufferMemoryBarrierCount = 1,
        pBufferMemoryBarriers = &barrier,
        imageMemoryBarrierCount = 0,
        pImageMemoryBarriers = nil,
    )
}
