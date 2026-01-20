#+build !js
package gpu

/*
Note: The contents here is not used by the current implementation, but we can
use later for better support.
*/

// Core
import sa "core:container/small_array"

// Vendor
import vk "vendor:vulkan"

Vulkan_Render_Pass_Cache_Query :: struct {
    color_mask:            bit_set[0..<MAX_COLOR_ATTACHMENTS; u8],
    resolve_target_mask:   bit_set[0..<MAX_COLOR_ATTACHMENTS; u8],
    color_formats:         [MAX_COLOR_ATTACHMENTS]vk.Format,
    color_samples:         [MAX_COLOR_ATTACHMENTS]vk.SampleCountFlags,
    color_load_ops:        [MAX_COLOR_ATTACHMENTS]Load_Op,
    color_store_ops:       [MAX_COLOR_ATTACHMENTS]Store_Op,

    color_final_layouts:   [MAX_COLOR_ATTACHMENTS]vk.ImageLayout,

    resolve_formats:       [MAX_COLOR_ATTACHMENTS]vk.Format,
    resolve_final_layouts: [MAX_COLOR_ATTACHMENTS]vk.ImageLayout,

    has_depth_stencil:     bool,
    depth_format:          vk.Format,
    depth_samples:         vk.SampleCountFlags,
    depth_load_op:         Load_Op,
    depth_store_op:        Store_Op,
    stencil_load_op:       Load_Op,
    stencil_store_op:      Store_Op,
    depth_layout:          vk.ImageLayout,
}

Vulkan_Framebuffer_Cache_Texture_View :: struct {
    texture_view: Texture_View,
    depth_slice:  u32,
}

Vulkan_Framebuffer_Key :: struct {
    render_pass:      Render_Pass, // from pool
    width:            u32,
    height:           u32,
    attachment_count: u32,
    texture_views:    [MAX_COLOR_ATTACHMENTS * 2 + 1]Vulkan_Framebuffer_Cache_Texture_View,
}

Vulkan_Framebuffer_Cache :: struct {
    using key:      Vulkan_Framebuffer_Key,
    vk_framebuffer: vk.Framebuffer,
    attachments:    [MAX_COLOR_ATTACHMENTS * 2 + 1]vk.ImageView,
    clear_values:   [MAX_COLOR_ATTACHMENTS + 1]vk.ClearValue,
}

Framebuffer_Cache_Map :: map[Vulkan_Framebuffer_Key]Vulkan_Framebuffer_Cache

vk_framebuffer_query_set_render_pass :: proc(
    query: ^Vulkan_Framebuffer_Cache,
    render_pass: Render_Pass,
    width: u32,
    height: u32,
) {
    query.render_pass = render_pass
    query.width = width
    query.height = height
}

vk_framebuffer_query_add_attachment :: proc(
    query: ^Vulkan_Framebuffer_Cache,
    texture_view: Texture_View,
    image_view: vk.ImageView,
    clear_value: vk.ClearValue,
    depth_slice: u32 = 0,
) {
    idx := query.attachment_count
    query.texture_views[idx] = Vulkan_Framebuffer_Cache_Texture_View{
        texture_view = texture_view,
        depth_slice = depth_slice,
    }
    query.attachments[idx] = image_view
    query.clear_values[idx] = clear_value
    query.attachment_count += 1
}

Vulkan_Resolve_Key :: struct {
    format: vk.Format,
    layout: vk.ImageLayout,
}

Vulkan_Color_Attachment_Key :: struct {
    format:   vk.Format,
    samples:  u32,
    load_op:  Load_Op,
    store_op: Store_Op,
    layout:   vk.ImageLayout,
    resolve:  Vulkan_Resolve_Key,
}

Vulkan_Depth_Stencil_Attachment_Key :: struct {
    format:           vk.Format,
    samples:          u32,
    depth_load_op:    Load_Op,
    depth_store_op:   Store_Op,
    stencil_load_op:  Load_Op,
    stencil_store_op: Store_Op,
    layout:           vk.ImageLayout,
    read_only:        bool,
}

Vulkan_Render_Pass_Key :: struct {
    colors:        [MAX_COLOR_ATTACHMENTS]Vulkan_Color_Attachment_Key,
    depth_stencil: Vulkan_Depth_Stencil_Attachment_Key,
}

// @(require_results)
// _vk_command_encoder_begin_render_pass :: proc(
//     encoder: Command_Encoder,
//     descriptor: Render_Pass_Descriptor,
//     loc := #caller_location,
// ) -> Render_Pass {
//     impl := _vk_command_encoder_get_impl(encoder, loc)
//     device_impl := _vk_device_get_impl(impl.device, loc)

//     assert(impl.current != nil, "No active command buffer", loc)
//     assert(impl.current.is_encoding, "Command buffer not encoding", loc)
//     assert(len(descriptor.color_attachments) > 0 || descriptor.depth_stencil_attachment != nil,
//            "Must have at least one attachment", loc)

//     image_views: sa.Small_Array(MAX_ATTACHMENT_COUNT, vk.ImageView)

//     // Track render area from first attachment
//     render_width: u32
//     render_height: u32

//     // Build the cache key
//     key: Vulkan_Render_Pass_Key
//     color_count := 0
//     has_depth := false

//     // Build the framebuffer cache
//     fb_query: Vulkan_Framebuffer_Cache

//     // Color attachments
//     for &attach in descriptor.color_attachments {
//         if attach.view == 0 {
//             continue
//         }

//         view_impl := _vk_texture_view_get_impl(attach.view, loc)
//         texture_impl := _vk_texture_get_impl(view_impl.texture, loc)

//         // Get dimensions from first valid attachment
//         if render_width == 0 {
//             render_width = texture_impl.size.width
//             render_height = texture_impl.size.height
//         }

//         // Determine if this is a swapchain image (for final layout)
//         is_swapchain := texture_impl.is_swapchain_image
//         final_layout := vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL
//         if is_swapchain {
//             final_layout = .PRESENT_SRC_KHR
//         }

//         // Build color attachment key
//         key.colors[color_count] = Vulkan_Color_Attachment_Key{
//             format   = texture_impl.vk_image_format,
//             samples  = _vk_conv_sample_count_flags(texture_impl.vk_samples),
//             load_op  = attach.ops.load,
//             store_op = attach.ops.store,
//             layout   = final_layout,
//         }

//         // Handle resolve target
//         if attach.resolve_target != 0 {
//             resolve_view_impl := _vk_texture_view_get_impl(attach.resolve_target, loc)
//             resolve_texture_impl := _vk_texture_get_impl(resolve_view_impl.texture, loc)

//             is_resolve_swapchain := resolve_texture_impl.is_swapchain_image
//             resolve_final_layout := vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL
//             if is_resolve_swapchain {
//                 resolve_final_layout = .PRESENT_SRC_KHR
//             }

//             key.colors[color_count].resolve = Vulkan_Resolve_Key{
//                 format = resolve_texture_impl.vk_image_format,
//                 layout = resolve_final_layout,
//             }
//         }

//         color_count += 1

//         sa.push_back(&image_views, view_impl.vk_image_view)

//         // Clear value
//         clear_val: vk.ClearValue
//         clear_val.color.float32 = {
//             f32(attach.ops.clear_value.r),
//             f32(attach.ops.clear_value.g),
//             f32(attach.ops.clear_value.b),
//             f32(attach.ops.clear_value.a),
//         }
//         vk_framebuffer_query_add_attachment(
//             &fb_query,
//             attach.view,
//             view_impl.vk_image_view,
//             clear_val,
//         )

//         // Add resolve image view if present
//         if attach.resolve_target != 0 {
//             resolve_view_impl := _vk_texture_view_get_impl(attach.resolve_target, loc)
//             sa.push_back(&image_views, resolve_view_impl.vk_image_view)
//             vk_framebuffer_query_add_attachment(
//                 &fb_query,
//                 attach.resolve_target,
//                 resolve_view_impl.vk_image_view,
//                 vk.ClearValue{},
//             )
//         }
//     }

//     // Depth/stencil attachment
//     if depth_stencil, ok := descriptor.depth_stencil_attachment.?; ok {
//         view_impl := _vk_texture_view_get_impl(depth_stencil.view, loc)
//         texture_impl := _vk_texture_get_impl(view_impl.texture, loc)

//         // Get dimensions if not set yet
//         if render_width == 0 {
//             render_width = texture_impl.size.width
//             render_height = texture_impl.size.height
//         }

//         has_depth = true

//         depth_load := Load_Op.Clear
//         depth_store := Store_Op.Discard
//         stencil_load := Load_Op.Clear
//         stencil_store := Store_Op.Discard
//         depth_read_only := false
//         stencil_read_only := false

//         if depth_ops, depth_ok := depth_stencil.depth_ops.?; depth_ok {
//             depth_load = depth_ops.load
//             depth_store = depth_ops.store
//             depth_read_only = depth_ops.read_only
//         }

//         if stencil_ops, stencil_ok := depth_stencil.stencil_ops.?; stencil_ok {
//             stencil_load = stencil_ops.load
//             stencil_store = stencil_ops.store
//             stencil_read_only = stencil_ops.read_only
//         }

//         // Determine layout based on read-only flags
//         depth_layout := vk.ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL
//         if depth_read_only && stencil_read_only {
//             depth_layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL
//         } else if depth_read_only {
//             depth_layout = .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL
//         } else if stencil_read_only {
//             depth_layout = .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL
//         }

//         // Build depth/stencil key
//         key.depth_stencil = Vulkan_Depth_Stencil_Attachment_Key{
//             format           = texture_impl.vk_image_format,
//             samples          = _vk_conv_sample_count_flags(texture_impl.vk_samples),
//             depth_load_op    = depth_load,
//             depth_store_op   = depth_store,
//             stencil_load_op  = stencil_load,
//             stencil_store_op = stencil_store,
//             layout           = depth_layout,
//             read_only        = depth_read_only && stencil_read_only,
//         }

//         sa.push_back(&image_views, view_impl.vk_image_view)

//         // Clear value
//         clear_val: vk.ClearValue
//         if depth_ops, depth_ok := depth_stencil.depth_ops.?; depth_ok {
//             clear_val.depthStencil.depth = depth_ops.clear_value
//         } else {
//             clear_val.depthStencil.depth = 1.0
//         }
//         if stencil_ops, stencil_ok := depth_stencil.stencil_ops.?; stencil_ok {
//             clear_val.depthStencil.stencil = stencil_ops.clear_value
//         }
//         vk_framebuffer_query_add_attachment(
//             &fb_query,
//             depth_stencil.view,
//             view_impl.vk_image_view,
//             clear_val,
//         )
//     }

//     assert(render_width > 0 && render_height > 0, "Invalid render area dimensions", loc)

//     vk_render_pass: vk.RenderPass
//     vk_framebuffer: vk.Framebuffer

//     handle: Render_Pass
//     rp_impl: ^VK_Render_Pass_Impl

//     // Look up or create the render pass
//     if cached_handle, found := device_impl.render_passes[key]; found {
//         handle = cached_handle
//         rp_impl = _vk_render_pass_get_impl(handle, loc)
//         vk_render_pass = rp_impl.vk_render_pass
//     } else {
//         vk_render_pass = _vk_create_render_pass(device_impl, &key, loc)
//         handle, rp_impl = _vk_render_pass_new_impl(impl.device, encoder, loc)
//         rp_impl.vk_render_pass = vk_render_pass
//         rp_impl.width = render_width
//         rp_impl.height = render_height
//         device_impl.render_passes[key] = handle
//     }

//     vk_framebuffer_query_set_render_pass(&fb_query, handle, render_width, render_height)

//     if cached_handle, found := device_impl.framebuffers[fb_query.key]; found {
//         vk_framebuffer = cached_handle
//     } else {
//         framebuffer_info := vk.FramebufferCreateInfo{
//             sType           = .FRAMEBUFFER_CREATE_INFO,
//             renderPass      = vk_render_pass,
//             attachmentCount = u32(sa.len(image_views)),
//             pAttachments    = raw_data(sa.slice(&image_views)),
//             width           = render_width,
//             height          = render_height,
//             layers          = 1,
//         }

//         res := vk.CreateFramebuffer(device_impl.vk_device, &framebuffer_info, nil, &vk_framebuffer)
//         vk_check(res, "CreateFramebuffer failed", loc)

//         device_impl.framebuffers[fb_query.key] = vk_framebuffer
//     }

//     // Begin render pass
//     begin_info := vk.RenderPassBeginInfo{
//         sType           = .RENDER_PASS_BEGIN_INFO,
//         renderPass      = vk_render_pass,
//         framebuffer     = vk_framebuffer,
//         renderArea      = vk.Rect2D{
//             offset = {0, 0},
//             extent = {render_width, render_height},
//         },
//         clearValueCount = fb_query.attachment_count,
//         pClearValues    = raw_data(fb_query.clear_values[:]),
//     }

//     vk.CmdBeginRenderPass(impl.current.cmdbuf, &begin_info, .INLINE)

//     return handle
// }

vk_create_render_pass :: proc(
    device_impl: ^Vulkan_Device_Impl,
    key: ^Vulkan_Render_Pass_Key,
    loc := #caller_location,
) -> vk.RenderPass {
    attachments: sa.Small_Array(MAX_ATTACHMENT_COUNT, vk.AttachmentDescription)
    refs_color: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.AttachmentReference)
    refs_resolve: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.AttachmentReference)

    ref_depth: vk.AttachmentReference
    has_depth := false
    has_resolve := false

    // Color attachments
    for &color_key in key.colors {
        if color_key.format == .UNDEFINED {
            break
        }

        attachment_idx := u32(sa.len(attachments))

        sa.push_back(&attachments, vk.AttachmentDescription{
            format         = color_key.format,
            samples        = vk_conv_to_sample_count_flags(color_key.samples),
            loadOp         = vk_conv_to_attachment_load_op(color_key.load_op),
            storeOp        = vk_conv_to_attachment_store_op(color_key.store_op),
            stencilLoadOp  = .DONT_CARE,
            stencilStoreOp = .DONT_CARE,
            initialLayout  = .UNDEFINED,
            finalLayout    = color_key.layout,
        })

        sa.push_back(&refs_color, vk.AttachmentReference{
            attachment = attachment_idx,
            layout     = .COLOR_ATTACHMENT_OPTIMAL,
        })

        // Resolve target
        if color_key.resolve.format != .UNDEFINED {
            has_resolve = true
            resolve_idx := u32(sa.len(attachments))

            sa.push_back(&attachments, vk.AttachmentDescription{
                format         = color_key.resolve.format,
                samples        = {._1},
                loadOp         = .DONT_CARE,
                storeOp        = .STORE,
                stencilLoadOp  = .DONT_CARE,
                stencilStoreOp = .DONT_CARE,
                initialLayout  = .UNDEFINED,
                finalLayout    = color_key.resolve.layout,
            })

            sa.push_back(&refs_resolve, vk.AttachmentReference{
                attachment = resolve_idx,
                layout     = .COLOR_ATTACHMENT_OPTIMAL,
            })
        } else {
            sa.push_back(&refs_resolve, vk.AttachmentReference{
                attachment = vk.ATTACHMENT_UNUSED,
            })
        }
    }

    // Depth/stencil attachment
    if key.depth_stencil.format != .UNDEFINED {
        depth_idx := u32(sa.len(attachments))
        has_depth = true

        sa.push_back(&attachments, vk.AttachmentDescription{
            format         = key.depth_stencil.format,
            samples        = vk_conv_to_sample_count_flags(key.depth_stencil.samples),
            loadOp         = vk_conv_to_attachment_load_op(key.depth_stencil.depth_load_op),
            storeOp        = vk_conv_to_attachment_store_op(key.depth_stencil.depth_store_op),
            stencilLoadOp  = vk_conv_to_attachment_load_op(key.depth_stencil.stencil_load_op),
            stencilStoreOp = vk_conv_to_attachment_store_op(key.depth_stencil.stencil_store_op),
            initialLayout  = .UNDEFINED,
            finalLayout    = key.depth_stencil.layout,
        })

        ref_depth = vk.AttachmentReference{
            attachment = depth_idx,
            layout     = key.depth_stencil.layout,
        }
    }

    // Subpass
    subpass := vk.SubpassDescription{
        pipelineBindPoint       = .GRAPHICS,
        colorAttachmentCount    = u32(sa.len(refs_color)),
        pColorAttachments       = raw_data(sa.slice(&refs_color)),
        pResolveAttachments     = has_resolve ? raw_data(sa.slice(&refs_resolve)) : nil,
        pDepthStencilAttachment = has_depth ? &ref_depth : nil,
    }

    // Create render pass
    create_info := vk.RenderPassCreateInfo{
        sType           = .RENDER_PASS_CREATE_INFO,
        attachmentCount = u32(sa.len(attachments)),
        pAttachments    = raw_data(sa.slice(&attachments)),
        subpassCount    = 1,
        pSubpasses      = &subpass,
    }

    vk_render_pass: vk.RenderPass
    res := vk.CreateRenderPass(device_impl.vk_device, &create_info, nil, &vk_render_pass)
    vk_check(res, "CreateRenderPass failed", loc)

    return vk_render_pass
}
