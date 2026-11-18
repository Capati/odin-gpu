#+build !js
package gpu

// Core
import hm "core:container/handle_map"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Framebuffer_Cache_Texture_View :: struct {
    texture_view: Texture_View,
    depth_slice:  u32,
}

VK_Framebuffer_Key :: struct {
    render_pass:      vk.RenderPass,
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

vk_framebuffer_query_set_extent :: proc(query: ^VK_Framebuffer_Cache, width: u32, height: u32) {
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
    query.texture_views[idx] = VK_Framebuffer_Cache_Texture_View {
        texture_view = texture_view,
        depth_slice  = depth_slice,
    }
    query.attachments[idx] = image_view
    query.attachment_count += 1
}

VK_Attachment_Key :: struct {
    format:       vk.Format,
    // Layout the attachment is in when the pass begins. The tracker-driven
    // barriers emitted before `CmdBeginRenderPass` have already moved the
    // image here, and it is also the subpass layout.
    layout:       vk.ImageLayout,
    // Layout the attachment is transitioned to by the render pass itself.
    // Differs from `layout` for swapchain images, which end in `.PRESENT_SRC`
    // so no separate post-pass barrier is needed.
    final_layout: vk.ImageLayout,
    load_op:      Load_Op,
    store_op:     Store_Op,
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

VK_RENDER_PASS_CACHE_MAX :: 64

vk_render_pass_order_remove :: proc(
    order: ^[VK_RENDER_PASS_CACHE_MAX]vk.RenderPass,
    count: ^u32,
    render_pass: vk.RenderPass,
) {
    for i in 0 ..< int(count^) {
        if order[i] != render_pass {
            continue
        }
        for j in i ..< int(count^) - 1 {
            order[j] = order[j + 1]
        }
        count^ -= 1
        return
    }
}

VK_Render_Pass_Handle :: distinct hm.Handle64

VK_Render_Pass_Impl :: struct {
    // base #subtype
    using base: _Render_Pass_Impl,
    // Backend
    handle:     VK_Render_Pass_Handle,

    // Recording-time caches. Valid only while this pass is open; the base
    // handle fields remain the source of truth across submit or device loss.
    // The device impl is a plain pointer cast (`vk_device_get_impl`), so it is
    // not cached here: doing so would make the pass and device types depend on
    // each other through the device's pass handle map.
    cached_encoder: ^VK_Command_Encoder_Impl,
    cached_cmdbuf:  ^VK_Command_Buffer_Impl,

    // Direct-recording state.
    active_pipeline:      Render_Pipeline,
    // Resolved impl of `active_pipeline`, cached on pipeline bind so the draw
    // paths do not pay the handle-map probe (a mutex-protected map lookup) per
    // draw. The pass impl is created fresh per `begin_render_pass`, so the
    // pointer starts nil every pass, and the pass's tracker holds a reference
    // for as long as the pass can run, so the impl outlives the cache.
    active_pipeline_impl: ^VK_Render_Pipeline_Impl,
    // Layout of `active_pipeline`, cached so the per-draw bind-group flush does
    // not resolve the pipeline impl again.
    active_layout:        Pipeline_Layout,
    // Resolved impl of `active_layout`, cached on pipeline bind for the same
    // reason as `active_pipeline_impl`: the draw-time bind-group validation and
    // the bind flush need the layout's children and slot mask, and resolving
    // the handle map per draw costs a shared-mutex probe. Read only while this
    // pass records, like the other recording-time caches above.
    active_layout_impl:   ^VK_Pipeline_Layout_Impl,
    // Set when the bound groups or pipeline layout changed since the last draw;
    // draw paths revalidate only while set (see vk_pipeline_bind_groups_validate).
    bind_groups_dirty:    bool,
    index_buffer:         Buffer,
    index_format:         Index_Format,
    index_buffer_size:    u64,
    // Offset of the current index binding, kept so a rebind of identical values can
    // be skipped (`vk_render_pass_set_index_buffer`).
    index_buffer_offset:  u64,
    has_index_buffer:     bool,
    vertex_slots:         [MAX_VERTEX_BUFFERS]bool,
    vertex_offsets:       [MAX_VERTEX_BUFFERS]u64,
    vertex_sizes:         [MAX_VERTEX_BUFFERS]u64,
    // Vulkan handles are emitted lazily, one `CmdBindVertexBuffers` per
    // contiguous dirty run before the next draw, so per-slot WebGPU calls do
    // not each become a driver call.
    vertex_buffers:       [MAX_VERTEX_BUFFERS]vk.Buffer,
    vertex_dirty_mask:    u32,
    bind_group_slots:     [MAX_BIND_GROUPS]VK_Bind_Group_Slot,
    // Set only while `execute_bundles` replays a bundle. The bundle's commands
    // were validated and its resource usage tallied when it was encoded, and the
    // whole tally is merged into the pass once before the replay, so the replayed
    // setters skip re-validating offsets and re-merging usage. Without this a
    // bundle pays validation twice and is slower than recording directly.
    replaying_bundle:     bool,
    timestamp_writes:     Render_Pass_Timestamp_Writes,
    occlusion_query_set:  Query_Set,
    // The depth/stencil attachment and the aspects the pass writes, kept so a
    // sampled/storage group bound to the same subresource can be checked per
    // aspect (the generic usage scope does not carry a view's aspect).
    depth_texture:        Texture,
    depth_selector:       Texture_Selector,
    depth_uses:           Texture_Uses,
    active_query_set:     Query_Set,
    active_query_index:   u32,
    used_queries:         [32]Query_Set_Write,
    used_query_count:     u32,
    present_textures:     [MAX_ATTACHMENT_COUNT]Texture,
    present_count:        u32,
    width:                u32,
    height:               u32,
    debug_group_depth:    u32,
    // A tombstone for a refused `begin_render_pass`: ending it reports misuse
    // and poisons the encoder, but it records nothing.
    is_invalid:           bool,
}

VK_RENDER_PASS_MAX_QUERY_USES :: 32

vk_render_pass_track_query_use :: proc(
    impl: ^VK_Render_Pass_Impl,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    if query_set == {} {
        return
    }
    for i in 0 ..< impl.used_query_count {
        use := impl.used_queries[i]
        if use.query_set == query_set && use.index == query_index {
            return
        }
    }
    ensure(
        impl.used_query_count < VK_RENDER_PASS_MAX_QUERY_USES,
        "too many query uses in one render pass",
        loc,
    )
    impl.used_queries[impl.used_query_count] = Query_Set_Write {
        query_set = query_set,
        index     = query_index,
    }
    impl.used_query_count += 1
}

vk_create_render_pass :: proc(
    device_impl: ^VK_Device_Impl,
    key: ^VK_Render_Pass_Key,
    loc := #caller_location,
) -> vk.RenderPass {
    attachments: [dynamic; MAX_ATTACHMENT_COUNT]vk.AttachmentDescription
    refs_color: [dynamic; MAX_COLOR_ATTACHMENTS]vk.AttachmentReference
    refs_resolve: [dynamic; MAX_COLOR_ATTACHMENTS]vk.AttachmentReference

    ref_depth: vk.AttachmentReference
    has_depth: bool
    has_resolve: bool

    samples := vk_conv_to_sample_count_flags(key.sample_count)

    // Used for holes in the color / resolve lists. Layout must be UNDEFINED
    // for ATTACHMENT_UNUSED references or the validation layers complain.
    unused := vk.AttachmentReference {
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
            append(&refs_color, unused)
            append(&refs_resolve, unused)
            continue
        }

        attachment_idx := u32(len(attachments))

        append(&attachments, vk.AttachmentDescription {
            format         = color_key.format,
            samples        = samples,
            loadOp         = vk_conv_to_attachment_load_op(color_key.load_op),
            storeOp        = vk_conv_to_attachment_store_op(color_key.store_op),
            stencilLoadOp  = .DONT_CARE,
            stencilStoreOp = .DONT_CARE,
            initialLayout  = color_key.layout,
            finalLayout    = color_key.final_layout,
        })

        append(&refs_color, vk.AttachmentReference {
            attachment = attachment_idx,
            layout     = color_key.layout,
        })

        // Resolve target
        if color_key.resolve.format != .UNDEFINED {
            has_resolve = true
            resolve_idx := u32(len(attachments))

            append(&attachments, vk.AttachmentDescription {
                format         = color_key.resolve.format,
                samples        = {._1},
                loadOp         = vk_conv_to_attachment_load_op(color_key.resolve.load_op),
                storeOp        = vk_conv_to_attachment_store_op(color_key.resolve.store_op),
                stencilLoadOp  = .DONT_CARE,
                stencilStoreOp = .DONT_CARE,
                initialLayout  = color_key.resolve.layout,
                finalLayout    = color_key.resolve.final_layout,
            })

            append(&refs_resolve, vk.AttachmentReference {
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

        depth_load_op := vk_conv_to_attachment_load_op(key.depth_stencil.load_op)
        depth_store_op := vk_conv_to_attachment_store_op(key.depth_stencil.store_op)
        stencil_load_op := vk_conv_to_attachment_load_op(key.depth_stencil.stencil_load_op)
        stencil_store_op := vk_conv_to_attachment_store_op(key.depth_stencil.stencil_store_op)

        // Read-only DS attachments must not be written to. If the device
        // advertises STORE_OP_NONE (VK_KHR_maintenance5 / Vulkan 1.3) we can
        // say so precisely; otherwise fall back to STORE the driver still
        // won't write anything because the subpass is read-only.
        store_op_for_read_only :=
            (device_impl.caps.store_op_none ? vk.AttachmentStoreOp.NONE : vk.AttachmentStoreOp.STORE)

        if key.depth_read_only {depth_store_op = store_op_for_read_only}
        if key.stencil_read_only {stencil_store_op = store_op_for_read_only}

        append(&attachments, vk.AttachmentDescription {
            format         = key.depth_stencil.format,
            samples        = samples,
            loadOp         = depth_load_op,
            storeOp        = depth_store_op,
            stencilLoadOp  = stencil_load_op,
            stencilStoreOp = stencil_store_op,
            initialLayout  = key.depth_stencil.layout,
            finalLayout    = key.depth_stencil.final_layout,
        })

        ref_depth = vk.AttachmentReference {
            attachment = depth_idx,
            layout     = key.depth_stencil.layout,
        }
    }

    // Subpass
    subpass := vk.SubpassDescription {
        pipelineBindPoint       = .GRAPHICS,
        colorAttachmentCount    = u32(len(refs_color)),
        pColorAttachments       = raw_data(refs_color[:]),
        pResolveAttachments     = has_resolve ? raw_data(refs_resolve[:]) : nil,
        pDepthStencilAttachment = has_depth ? &ref_depth : nil,
    }

    // Create info
    create_info := vk.RenderPassCreateInfo {
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

        multiview_info = vk.RenderPassMultiviewCreateInfo {
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
@(require_results)
vk_render_pass_cache_lookup :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Render_Pass_Key,
) -> (
    cached: vk.RenderPass,
    found: bool,
) {
    sync.guard(&device_impl.render_pass_cache_mtx)
    cached, found = device_impl.render_pass_cache[key]
    if found {
        vk_render_pass_order_remove(
            &device_impl.render_pass_cache_order,
            &device_impl.render_pass_cache_order_len,
            cached,
        )
        device_impl.render_pass_cache_order[device_impl.render_pass_cache_order_len] = cached
        device_impl.render_pass_cache_order_len += 1
    }
    return
}

@(require_results)
vk_render_pass_cache_insert_if_absent :: proc(
    device_impl: ^VK_Device_Impl,
    key: VK_Render_Pass_Key,
    candidate: vk.RenderPass,
) -> (
    result: vk.RenderPass,
    inserted: bool,
    evicted: vk.RenderPass,
) {
    sync.guard(&device_impl.render_pass_cache_mtx)
    if cached, found := device_impl.render_pass_cache[key]; found {
        return cached, false, {}
    }
    device_impl.render_pass_cache[key] = candidate
    if device_impl.render_pass_cache_order_len == VK_RENDER_PASS_CACHE_MAX {
        oldest := device_impl.render_pass_cache_order[0]
        vk_render_pass_order_remove(
            &device_impl.render_pass_cache_order,
            &device_impl.render_pass_cache_order_len,
            oldest,
        )
        // The order list only carries handles; find the key that owns the
        // evicted handle. Eviction happens at most once per new key after the
        // cache is full, so the scan is not on the per-pass path.
        evicted_key: VK_Render_Pass_Key
        has_evicted_key := false
        for old_key, old_render_pass in device_impl.render_pass_cache {
            if old_render_pass == oldest {
                evicted_key = old_key
                has_evicted_key = true
                break
            }
        }
        if has_evicted_key {
            delete_key(&device_impl.render_pass_cache, evicted_key)
            evicted = oldest
        }
    }
    device_impl.render_pass_cache_order[device_impl.render_pass_cache_order_len] = candidate
    device_impl.render_pass_cache_order_len += 1
    return candidate, true, evicted
}

vk_framebuffer_cache_remove_render_pass :: proc(
    device_impl: ^VK_Device_Impl,
    render_pass: vk.RenderPass,
    loc := #caller_location,
) {
    matched: [dynamic]vk.Framebuffer
    stale_keys: [dynamic]VK_Framebuffer_Key
    matched.allocator = device_impl.allocator
    stale_keys.allocator = device_impl.allocator
    {
        sync.guard(&device_impl.framebuffer_cache_mtx)
        for key, cache in device_impl.framebuffer_cache {
            if key.render_pass == render_pass {
                append(&matched, cache.vk_framebuffer)
                append(&stale_keys, key)
            }
        }
        for key in stale_keys {
            delete_key(&device_impl.framebuffer_cache, key)
        }
    }
    for framebuffer in matched {
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, framebuffer)
    }
    delete(matched)
    delete(stale_keys)
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
    result, inserted, evicted := vk_render_pass_cache_insert_if_absent(device_impl, key, created)
    if !inserted {
        device_impl.fp.DestroyRenderPass(device_impl.vk_device, created, nil)
    } else if evicted != {} {
        vk_framebuffer_cache_remove_render_pass(device_impl, evicted, loc)
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, evicted)
    }
    return result
}

@(require_results)
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

@(require_results)
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
    query.render_pass = render_pass
    if cached, found := vk_framebuffer_cache_lookup(device_impl, query.key); found {
        return cached.vk_framebuffer
    }

    framebuffer_info := vk.FramebufferCreateInfo {
        sType           = .FRAMEBUFFER_CREATE_INFO,
        renderPass      = render_pass,
        attachmentCount = query.attachment_count,
        pAttachments    = raw_data(query.attachments[:query.attachment_count]),
        width           = width,
        height          = height,
        layers          = 1,
    }
    created: vk.Framebuffer
    vk_check(
        device_impl.fp.CreateFramebuffer(device_impl.vk_device, &framebuffer_info, nil, &created),
        loc = loc,
    )

    query.vk_framebuffer = created
    result, inserted := vk_framebuffer_cache_insert_if_absent(device_impl, query^)
    if !inserted {
        device_impl.fp.DestroyFramebuffer(device_impl.vk_device, created, nil)
    }
    return result
}

@(require_results)
vk_render_pass_get_internal_impl :: #force_inline proc "contextless" (
    render_pass: Render_Pass,
    loc := #caller_location,
) -> ^_Render_Pass_Impl {
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

// Debug markers and groups are accepted but not emitted; see the command encoder.
vk_render_pass_insert_debug_marker :: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
    }
}

vk_render_pass_pop_debug_group :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    if impl.debug_group_depth == 0 {
        gpu_report_validation_error(impl.device, "debug group stack underflow", loc)
        impl.is_invalid = true
        return
    }
    impl.debug_group_depth -= 1
}

vk_render_pass_push_debug_group :: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    if !impl.is_rendering {
        gpu_report_validation_error(impl.device, "render pass has ended", loc)
        return
    }
    impl.debug_group_depth += 1
}

vk_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    impl := vk_render_pass_get_impl(render_pass, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Render_Pass, pack_handle(impl.handle))
}

vk_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    impl := vk_render_pass_get_impl(render_pass, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    // A pass only produces commands; it has no Vulkan object to name.
    vk_label_set(&device_impl.labels, .Render_Pass, pack_handle(impl.handle), label)
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
        vk_label_remove(&device_impl.labels, .Render_Pass, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.render_passes, impl.handle)
    }
}
