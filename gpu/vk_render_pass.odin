#+build !js
package gpu

// Core
import hm "core:container/handle_map"
import "core:mem/virtual"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Framebuffer_Cache_Texture_View :: struct {
    texture_view: Texture_View,
    depth_slice:  u32,
}

VK_Framebuffer_Key :: struct {
    width:            u32,
    height:           u32,
    attachment_count: u32,
    texture_views:    [MAX_ATTACHMENT_COUNT]VK_Framebuffer_Cache_Texture_View,
}

VK_Framebuffer_Cache :: struct {
    using key:      VK_Framebuffer_Key,
    vk_framebuffer: vk.Framebuffer,
    attachments:    [MAX_ATTACHMENT_COUNT]vk.ImageView,
}

VK_Framebuffer_Cache_Map :: map[VK_Framebuffer_Key]VK_Framebuffer_Cache

vk_framebuffer_query_set_extent :: proc(
    query: ^VK_Framebuffer_Cache,
    width: u32,
    height: u32,
) {
    query.width = width
    query.height = height
}

vk_framebuffer_query_add_attachment :: proc(
    query: ^VK_Framebuffer_Cache,
    texture_view: Texture_View,
    image_view: vk.ImageView,
    depth_slice: u32 = 0,
) {
    idx := query.attachment_count
    query.texture_views[idx] = VK_Framebuffer_Cache_Texture_View{
        texture_view = texture_view,
        depth_slice  = depth_slice,
    }
    query.attachments[idx] = image_view
    query.attachment_count += 1
}

VK_Attachment_Key :: struct {
    format:   vk.Format,
    // Layout the attachment is in when the pass begins. The tracker-driven
    // barriers emitted before `CmdBeginRenderPass` have already moved the
    // image here, and it is also the subpass layout.
    layout:   vk.ImageLayout,
    // Layout the attachment is transitioned to by the render pass itself.
    // Differs from `layout` for swapchain images, which end in `.PRESENT_SRC`
    // so no separate post-pass barrier is needed.
    final_layout: vk.ImageLayout,
    load_op:  Load_Op,
    store_op: Store_Op,
}

VK_Color_Attachment_Key :: struct {
    using base: VK_Attachment_Key,
    resolve:    VK_Attachment_Key,
}

VK_Depth_Stencil_Attachment_Key :: struct {
    using base:       VK_Attachment_Key,
    stencil_load_op:  Load_Op,
    stencil_store_op: Store_Op,
}

VK_Render_Pass_Key :: struct {
    colors:            [MAX_COLOR_ATTACHMENTS]VK_Color_Attachment_Key,
    depth_stencil:     VK_Depth_Stencil_Attachment_Key,
    sample_count:      u32,
    multiview_mask:    u32,
    depth_read_only:   bool,
    stencil_read_only: bool,
}

VK_Render_Pass_Handle :: distinct hm.Handle64

VK_Render_Pass_Impl :: struct {
    // base #subtype
    using base: Render_Pass_Impl,
    // Backend
    handle:     VK_Render_Pass_Handle,
}

vk_create_render_pass :: proc(
    device_impl: ^VK_Device_Impl,
    key: ^VK_Render_Pass_Key,
    loc := #caller_location,
) -> vk.RenderPass {
    attachments:  [dynamic;MAX_ATTACHMENT_COUNT]vk.AttachmentDescription
    refs_color:   [dynamic;MAX_COLOR_ATTACHMENTS]vk.AttachmentReference
    refs_resolve: [dynamic;MAX_COLOR_ATTACHMENTS]vk.AttachmentReference

    ref_depth:   vk.AttachmentReference
    has_depth:   bool
    has_resolve: bool

    samples := vk_conv_to_sample_count_flags(key.sample_count)

    // Used for holes in the color / resolve lists. Layout must be UNDEFINED
    // for ATTACHMENT_UNUSED references or the validation layers complain.
    unused := vk.AttachmentReference{
        attachment = vk.ATTACHMENT_UNUSED,
        layout     = .UNDEFINED,
    }

    // Effective color count = highest populated slot + 1.  Holes below that are
    // preserved as `unused` references so the subpass layout matches the cache
    // key exactly (i.e. we don't silently truncate on a gap).
    color_count: int
    for &color_key, i in key.colors {
        if color_key.format != .UNDEFINED {
            color_count = i + 1
        }
    }

    // Color attachments
    for i in 0 ..< color_count {
        color_key := &key.colors[i]

        if color_key.format == .UNDEFINED {
            append(&refs_color,   unused)
            append(&refs_resolve, unused)
            continue
        }

        attachment_idx := u32(len(attachments))

        append(&attachments, vk.AttachmentDescription{
            format         = color_key.format,
            samples        = samples,
            loadOp         = vk_conv_to_attachment_load_op(color_key.load_op),
            storeOp        = vk_conv_to_attachment_store_op(color_key.store_op),
            stencilLoadOp  = .DONT_CARE,
            stencilStoreOp = .DONT_CARE,
            initialLayout  = color_key.layout,
            finalLayout    = color_key.final_layout,
        })

        append(&refs_color, vk.AttachmentReference{
            attachment = attachment_idx,
            layout     = color_key.layout,
        })

        // Resolve target
        if color_key.resolve.format != .UNDEFINED {
            has_resolve = true
            resolve_idx := u32(len(attachments))

            append(&attachments, vk.AttachmentDescription{
                format         = color_key.resolve.format,
                samples        = {._1},
                loadOp         = vk_conv_to_attachment_load_op(color_key.resolve.load_op),
                storeOp        = vk_conv_to_attachment_store_op(color_key.resolve.store_op),
                stencilLoadOp  = .DONT_CARE,
                stencilStoreOp = .DONT_CARE,
                initialLayout  = color_key.resolve.layout,
                finalLayout    = color_key.resolve.final_layout,
            })

            append(&refs_resolve, vk.AttachmentReference{
                attachment = resolve_idx,
                layout     = color_key.resolve.layout,
            })
        } else {
            append(&refs_resolve, unused)
        }
    }

    // Depth / stencil attachment
    if key.depth_stencil.format != .UNDEFINED {
        depth_idx := u32(len(attachments))
        has_depth = true

        depth_load_op    := vk_conv_to_attachment_load_op(key.depth_stencil.load_op)
        depth_store_op   := vk_conv_to_attachment_store_op(key.depth_stencil.store_op)
        stencil_load_op  := vk_conv_to_attachment_load_op(key.depth_stencil.stencil_load_op)
        stencil_store_op := vk_conv_to_attachment_store_op(key.depth_stencil.stencil_store_op)

        // Read-only DS attachments must not be written to. If the device
        // advertises STORE_OP_NONE (VK_KHR_maintenance5 / Vulkan 1.3) we can
        // say so precisely; otherwise fall back to STORE the driver still
        // won't write anything because the subpass is read-only.
        store_op_for_read_only := device_impl.caps.store_op_none \
            ? vk.AttachmentStoreOp.NONE : vk.AttachmentStoreOp.STORE

        if key.depth_read_only   { depth_store_op   = store_op_for_read_only }
        if key.stencil_read_only { stencil_store_op = store_op_for_read_only }

        append(&attachments, vk.AttachmentDescription{
            format         = key.depth_stencil.format,
            samples        = samples,
            loadOp         = depth_load_op,
            storeOp        = depth_store_op,
            stencilLoadOp  = stencil_load_op,
            stencilStoreOp = stencil_store_op,
            initialLayout  = key.depth_stencil.layout,
            finalLayout    = key.depth_stencil.final_layout,
        })

        ref_depth = vk.AttachmentReference{
            attachment = depth_idx,
            layout     = key.depth_stencil.layout,
        }
    }

    // Subpass
    subpass := vk.SubpassDescription{
        pipelineBindPoint       = .GRAPHICS,
        colorAttachmentCount    = u32(len(refs_color)),
        pColorAttachments       = raw_data(refs_color[:]),
        pResolveAttachments     = has_resolve ? raw_data(refs_resolve[:]) : nil,
        pDepthStencilAttachment = has_depth  ? &ref_depth            : nil,
    }

    // Create info
    create_info := vk.RenderPassCreateInfo{
        sType           = .RENDER_PASS_CREATE_INFO,
        attachmentCount = u32(len(attachments)),
        pAttachments    = raw_data(attachments[:]),
        subpassCount    = 1,
        pSubpasses      = &subpass,
    }

    // Multiview (VK_KHR_multiview / Vulkan 1.1 core).  viewMasks and
    // correlationMasks each get one entry per subpass; we have one subpass, and
    // we use the same mask for both.
    view_masks: u32
    multiview_info: vk.RenderPassMultiviewCreateInfo
    if key.multiview_mask != 0 {
        view_masks = key.multiview_mask

        multiview_info = vk.RenderPassMultiviewCreateInfo{
            sType                = .RENDER_PASS_MULTIVIEW_CREATE_INFO,
            subpassCount         = 1,
            pViewMasks           = &view_masks,
            correlationMaskCount = 1,
            pCorrelationMasks    = &view_masks,
        }
        create_info.pNext = &multiview_info
    }

    vk_render_pass: vk.RenderPass
    vk_check(vk.CreateRenderPass(device_impl.vk_device, &create_info, nil, &vk_render_pass))

    return vk_render_pass
}

// Shared lookup, create outside the lock, then publish under exclusive access.
// If another thread won the race to insert the same key, discard our unused
// Vulkan object after dropping the cache lock.
vk_render_pass_cache_lookup :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Render_Pass_Key,
) -> (
    cached: vk.RenderPass,
    found: bool,
) {
    sync.shared_guard(&device_impl.render_pass_cache_mtx)
    return device_impl.render_pass_cache[key]
}

vk_render_pass_cache_insert_if_absent :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Render_Pass_Key,
    candidate: vk.RenderPass,
) -> (
    result: vk.RenderPass,
    inserted: bool,
) {
    sync.guard(&device_impl.render_pass_cache_mtx)
    if cached, found := device_impl.render_pass_cache[key]; found {
        return cached, false
    }
    device_impl.render_pass_cache[key] = candidate
    return candidate, true
}

vk_render_pass_cache_get_or_create :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Render_Pass_Key,
    loc := #caller_location,
) -> vk.RenderPass {
    if cached, found := vk_render_pass_cache_lookup(device_impl, key); found {
        return cached
    }

    key_copy := key
    created := vk_create_render_pass(device_impl, &key_copy, loc)
    result, inserted := vk_render_pass_cache_insert_if_absent(device_impl, key, created)
    if !inserted {
        device_impl.fp.DestroyRenderPass(device_impl.vk_device, created, nil)
    }
    return result
}

vk_framebuffer_cache_lookup :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Framebuffer_Key,
) -> (
    cached: VK_Framebuffer_Cache,
    found: bool,
) {
    sync.shared_guard(&device_impl.framebuffer_cache_mtx)
    return device_impl.framebuffer_cache[key]
}

vk_framebuffer_cache_insert_if_absent :: proc(
    device_impl: ^VK_Device_Impl,
    candidate: VK_Framebuffer_Cache,
) -> (
    result: vk.Framebuffer,
    inserted: bool,
) {
    sync.guard(&device_impl.framebuffer_cache_mtx)
    if cached, found := device_impl.framebuffer_cache[candidate.key]; found {
        return cached.vk_framebuffer, false
    }
    device_impl.framebuffer_cache[candidate.key] = candidate
    return candidate.vk_framebuffer, true
}

vk_framebuffer_cache_get_or_create :: proc(
    device_impl: ^VK_Device_Impl,
    query: ^VK_Framebuffer_Cache,
    render_pass: vk.RenderPass,
    width, height: u32,
    loc := #caller_location,
) -> vk.Framebuffer {
    if cached, found := vk_framebuffer_cache_lookup(device_impl, query.key); found {
        return cached.vk_framebuffer
    }

    framebuffer_info := vk.FramebufferCreateInfo{
        sType           = .FRAMEBUFFER_CREATE_INFO,
        renderPass      = render_pass,
        attachmentCount = query.attachment_count,
        pAttachments    = raw_data(query.attachments[:query.attachment_count]),
        width           = width,
        height          = height,
        layers          = 1,
    }
    created: vk.Framebuffer
    vk_check(device_impl.fp.CreateFramebuffer(
        device_impl.vk_device, &framebuffer_info, nil, &created), loc = loc)

    query.vk_framebuffer = created
    result, inserted := vk_framebuffer_cache_insert_if_absent(device_impl, query^)
    if !inserted {
        device_impl.fp.DestroyFramebuffer(device_impl.vk_device, created, nil)
    }
    return result
}

@(require_results)
vk_render_pass_get_public_impl :: #force_inline proc "contextless" (
    render_pass: Render_Pass,
    loc := #caller_location,
) -> ^Render_Pass_Impl {
    return vk_render_pass_get_impl(render_pass, loc)
}

@(require_results)
vk_render_pass_get_impl :: #force_inline proc "contextless" (
    render_pass: Render_Pass,
    loc := #caller_location,
) -> ^VK_Render_Pass_Impl {
    device_impl := vk_device_get_impl(render_pass.device, loc)
    return get_handle_impl(&device_impl.render_passes, render_pass.handle, loc)
}

vk_render_pass_begin_occlusion_query :: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Draw_Cmd, loc)

    cmd.vertex_count = vertex_count
    cmd.instance_count = instance_count
    cmd.first_vertex = first_vertex
    cmd.first_instance = first_instance
}

vk_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Draw_Indexed_Cmd, loc)

    cmd.index_count = index_count
    cmd.instance_count = instance_count
    cmd.first_index = first_index
    cmd.base_vertex = base_vertex
    cmd.first_instance = first_instance
}

vk_render_pass_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_draw_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_end :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    impl.is_rendering = false
    encoder_impl.is_rendering = false

    cmdbuf := encoder_impl.cmdbuf
    scope := &cmdbuf.pass_scope

    _ = command_allocator_allocate(&cmdbuf.commands, Render_Pass_End_Cmd, loc)

    vk_command_buffer_fold_usage_scope(cmdbuf, scope, loc)

    // Backfill barriers computed during the fold into the pass's begin command.
    // The recorder emits them immediately before `vkCmdBeginRenderPass`, when
    // they're safe to issue.
    temp_allocator := virtual.arena_allocator(&cmdbuf.temp_arena)
    begin := impl.begin_cmd
    begin.buffer_transitions = buffer_tracker_drain_transitions(
        &cmdbuf.tracker.buffers, temp_allocator, loc)
    begin.texture_transitions = texture_tracker_drain_transitions(
        &cmdbuf.tracker.textures, temp_allocator, loc)
}

vk_render_pass_end_occlusion_query :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_execute_bundles :: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_insert_debug_marker :: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_pop_debug_group :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_push_debug_group :: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)
    assert(group_index < MAX_BIND_GROUPS, "Bind group index out of range", loc)

    bind_group_impl := vk_bind_group_get_impl(group, loc)
    err := usage_scope_merge_bind_group(
        &encoder_impl.cmdbuf.pass_scope, &bind_group_impl.used, loc)
    assert(err == nil, "usage conflict in bind group", loc)

    // The command stores the handle and resolves it later during command-buffer
    // recording. Keep the bind group alive until this command buffer is reclaimed.
    vk_bind_group_add_ref(group, loc)
    stateless_tracker_insert_single(&encoder_impl.cmdbuf.tracker.bind_groups, group, loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Set_Bind_Group_Cmd, loc)

    // cmd.render_pass = render_pass_encoder
    cmd.index = group_index
    cmd.dynamic_offsets = {} // TODO
    cmd.bind_group = group
    cmd.loc = loc
}

vk_render_pass_set_blend_constant_impl :: proc(
    vk_cmdbuf: vk.CommandBuffer,
    color: Color,
    loc := #caller_location,
) {
    color := [4]f32{f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
    vk.CmdSetBlendConstants(vk_cmdbuf, &color)
}

vk_render_pass_set_blend_constant :: proc(
    render_pass: Render_Pass,
    color: Color,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Set_Blend_Constant_Cmd, loc)

    // cmd.render_pass = render_pass_encoder
    cmd.color = color
}

vk_render_pass_set_immediates :: proc(
    render_pass: Render_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    err := buffer_usage_scope_merge_single(
        &encoder_impl.cmdbuf.pass_scope.buffers,
        buffer_tracker_index(buffer, loc),
        buffer,
        {.Index},
        loc,
    )
    assert(err == nil, "usage conflict in index buffer", loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Set_Index_Buffer_Cmd, loc)

    // cmd.render_pass = render_pass
    cmd.buffer = buffer
    cmd.index_format = format
    cmd.offset = offset
    cmd.size = size
}

vk_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    vk_render_pipeline_add_ref(pipeline, loc)
    stateless_tracker_insert_single(
        &encoder_impl.cmdbuf.tracker.render_pipelines, pipeline, loc)

    cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Set_Render_Pipeline_Cmd, loc)

    // cmd.render_pass = render_pass
    cmd.pipeline = pipeline
}

vk_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Set_Scissor_Cmd, loc)

    // cmd.render_pass = render_pass_encoder
    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
}

vk_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(&encoder_impl.cmdbuf.commands, Set_Viewport_Cmd, loc)

    // cmd.render_pass = render_pass_encoder
    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
    cmd.min_depth = min_depth
    cmd.max_depth = max_depth
}

vk_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Set_Stencil_Reference_Cmd, loc)

    // cmd.render_pass = render_pass_encoder
    cmd.reference = reference
}

vk_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)

    assert(impl.is_rendering, "Expected an active render pass", loc)

    // Vertex data is read during draws, so it merges into the pass scope the same
    // way bind group resources do.
    err := buffer_usage_scope_merge_single(
        &encoder_impl.cmdbuf.pass_scope.buffers,
        buffer_tracker_index(buffer, loc),
        buffer,
        {.Vertex},
        loc,
    )
    assert(err == nil, "usage conflict in vertex buffer", loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmdbuf.commands, Set_Vertex_Buffer_Cmd, loc)

    cmd.slot = slot
    cmd.buffer = buffer
    cmd.offset = offset
    cmd.size = size
}

vk_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    add_ref(impl, loc)
}

vk_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    if release_ref(impl, loc) {
        if impl.is_rendering {
            // Releasing an open pass abandons its encoder. Do not leave a live
            // encoder pointing at a render pass that has been removed.
            encoder_impl := vk_command_encoder_get_impl(impl.encoder, loc)
            impl.is_rendering = false
            encoder_impl.is_rendering = false
            encoder_impl.is_encoding = false
        }
        vk_command_encoder_release(impl.encoder, loc)
        device_impl := vk_device_get_impl(impl.device, loc)
        remove_handle_impl(&device_impl.render_passes, impl.handle)
    }
}
