#+build !js
package gpu

// Core
import "base:runtime"
import hm "core:container/handle_map"
import "core:mem/virtual"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Command_Encoder_Temp :: struct {
    marker:          []u8,
    buffer_barriers: [dynamic]vk.BufferMemoryBarrier,
    image_barriers:  [dynamic]vk.ImageMemoryBarrier,
}

VK_Command_Encoder_Handle :: distinct hm.Handle64

VK_Command_Encoder_Impl :: struct {
    using base: _Command_Encoder_Impl,

    // Device sued to create this encoder.
    cmdbuf:            ^VK_Command_Buffer_Impl,
    // What kind of pass we are currently within (compute or render).
    bind_point:        vk.PipelineBindPoint,
    // The internal handle to the command encoders pool.
    handle:            VK_Command_Encoder_Handle,
    debug_group_depth: u32,
    // A refused pass begin or an invalid pass end poisons the recording: every
    // later `finish` is refused, though a pass may still be opened and closed.
    invalid:           bool,
}

VK_Command_Encoder_Wrapper :: struct {
    device:     Device,
    slot_index: u32,
    handle:     VK_Command_Encoder_Handle,
    ref:        Ref_Count_Type,
}

@(require_results)
vk_create_command_encoder :: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor,
    loc := #caller_location,
) -> Command_Encoder {
    impl := vk_device_get_impl(device, loc)

    cmdbuf := vk_submit_context_acquire(&impl.submitter, loc)
    vk_command_buffer_begin_recording(cmdbuf, loc)

    encoder_impl, encoder_handle := add_impl(&impl.command_encoders, VK_Command_Encoder_Impl {
        device       = device,
        cmdbuf       = cmdbuf,
        is_encoding  = true,
        is_rendering = false,
        is_computing = false,
    })

    command_encoder := new_handle(Command_Encoder, device, encoder_handle)
    vk_label_set(&impl.labels, .Command_Encoder, pack_handle(encoder_handle), descriptor.label)

    // wrapper.encoder is a weak back-reference for lookups only
    _, cmdbuf_handle := add_impl(&impl.command_buffers, VK_Command_Buffer_Wrapper {
        device       = device,
        encoder      = command_encoder,
        buffer_index = cmdbuf.submit_handle.buffer_index,
        submit_id    = cmdbuf.submit_handle.submit_id,
    })

    command_buffer := new_handle(Command_Buffer, device, cmdbuf_handle)
    encoder_impl.command_buffer = command_buffer // the one strong, owning ref

    return command_encoder
}

@(require_results)
vk_command_encoder_get_internal_impl :: #force_inline proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^_Command_Encoder_Impl {
    return vk_command_encoder_get_impl(command_encoder, loc)
}

@(require_results)
vk_command_encoder_get_impl :: #force_inline proc "contextless" (
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> ^VK_Command_Encoder_Impl {
    device_impl := vk_device_get_impl(command_encoder.device, loc)
    return get_handle_impl(&device_impl.command_encoders, command_encoder.handle, loc)
}

// Records a buffer's usage for a command encoded outside any pass, into the
// command buffer's global scope. A conflict here means the same buffer is being
// used two ways that cannot be ordered, which WebGPU rejects outright.
vk_command_encoder_track_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    uses: Buffer_Uses,
    conflict_message: string,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    ok := buffer_usage_scope_merge_single(
        &impl.cmdbuf.global_scope.buffers,
        _buffer_tracker_index(buffer, loc),
        buffer,
        uses,
    )
    assert(ok, conflict_message, loc)
}

// Timestamp writes: feature, a live timestamp set on this device, and distinct
// in-range slots when both are present.
vk_timestamp_writes_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    writes: Render_Pass_Timestamp_Writes,
    loc := #caller_location,
) -> bool {
    if writes.query_set == {} {
        gpu_report_validation_error(device, "timestamp writes must name a query set", loc)
        return false
    }
    if !has_features(device_impl.features[:], {.Timestamp_Query}) {
        gpu_report_validation_error(
            device,
            "timestamp writes require the [Timestamp_Query] feature",
            loc,
        )
        return false
    }
    query_set_device := vk_device_get_impl(writes.query_set.device, loc)
    set_impl := dhm_get_if_valid(
        &query_set_device.query_sets,
        unpack_handle(VK_Query_Set_Handle, writes.query_set.handle),
    )
    if set_impl == nil {
        gpu_report_validation_error(device, "query set is not a live query set", loc)
        return false
    }
    if set_impl.device != device {
        gpu_report_validation_error(device, "query set belongs to another device", loc)
        return false
    }
    if set_impl.type != .Timestamp {
        gpu_report_validation_error(device, "query set has the wrong type for timestamps", loc)
        return false
    }
    begin := writes.beginning_of_pass_write_index
    end := writes.end_of_pass_write_index
    if begin != QUERY_SET_INDEX_UNDEFINED && begin >= set_impl.count {
        gpu_report_validation_error(device, "timestamp beginning index is past the query set", loc)
        return false
    }
    if end != QUERY_SET_INDEX_UNDEFINED && end >= set_impl.count {
        gpu_report_validation_error(device, "timestamp end index is past the query set", loc)
        return false
    }
    if begin != QUERY_SET_INDEX_UNDEFINED && end != QUERY_SET_INDEX_UNDEFINED && begin == end {
        gpu_report_validation_error(device, "timestamp writes must use different slots", loc)
        return false
    }
    return true
}

// A refused begin still hands back a pass (WebGPU's invalid pass encoder). The
// tombstone reports when it is ended and poisons the encoder for `finish`.
@(require_results)
vk_command_encoder_fail_compute_pass :: proc(
    impl: ^VK_Command_Encoder_Impl,
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> Compute_Pass {
    impl.invalid = true
    device_impl := vk_device_get_impl(impl.device, loc)
    _, handle := add_impl(&device_impl.computer_passes, VK_Compute_Pass_Impl {
        base = _Compute_Pass_Impl{device = impl.device, encoder = command_encoder},
        cached_encoder = impl,
        cached_cmdbuf = impl.cmdbuf,
        is_invalid = true,
    })
    compute_pass := new_handle(Compute_Pass, impl.device, handle)
    // Every returned pass owns one reference on its encoder, refused ones
    // included: `vk_compute_pass_release` drops it unconditionally.
    vk_command_encoder_add_ref(command_encoder, loc)
    return compute_pass
}

@(require_results)
vk_command_encoder_fail_render_pass :: proc(
    impl: ^VK_Command_Encoder_Impl,
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> Render_Pass {
    impl.invalid = true
    device_impl := vk_device_get_impl(impl.device, loc)
    _, handle := add_impl(&device_impl.render_passes, VK_Render_Pass_Impl {
        base = _Render_Pass_Impl{device = impl.device, encoder = command_encoder},
        cached_encoder = impl,
        cached_cmdbuf = impl.cmdbuf,
        is_invalid = true,
    })
    render_pass := new_handle(Render_Pass, impl.device, handle)
    // Every returned pass owns one reference on its encoder, refused ones
    // included: `vk_render_pass_release` drops it unconditionally.
    vk_command_encoder_add_ref(command_encoder, loc)
    return render_pass
}

@(require_results)
vk_command_encoder_begin_compute_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    cmdbuf_impl := vk_command_buffer_get_impl(impl.command_buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return vk_command_encoder_fail_compute_pass(impl, command_encoder, loc)
    }
    if impl.is_rendering {
        gpu_report_validation_error(impl.device, "command encoder is rendering", loc)
        return vk_command_encoder_fail_compute_pass(impl, command_encoder, loc)
    }
    if impl.is_computing {
        gpu_report_validation_error(impl.device, "command encoder is computing", loc)
        return vk_command_encoder_fail_compute_pass(impl, command_encoder, loc)
    }

    if descriptor.timestamp_writes != nil &&
       !vk_timestamp_writes_validate(impl.device, device_impl, descriptor.timestamp_writes^, loc) {
        return vk_command_encoder_fail_compute_pass(impl, command_encoder, loc)
    }

    // The pass's usage scope starts clean; its transitions are folded at end.
    buffer_usage_scope_clear(&cmdbuf_impl.pass_scope.buffers)
    texture_usage_scope_clear(&cmdbuf_impl.pass_scope.textures)

    // Initial device-to-start barriers go into the main buffer, before the pass
    // buffer is isolated.
    vk_command_encoder_prepare(cmdbuf_impl, loc)
    vk_command_buffer_begin_isolated(cmdbuf_impl, loc)

    _, compute_pass_handle := add_impl(&device_impl.computer_passes, VK_Compute_Pass_Impl {
        base = _Compute_Pass_Impl {
            device  = impl.device,
            encoder = command_encoder,
        },
        is_computing = true,
        bind_groups_dirty = true,
        cached_encoder = impl,
        cached_cmdbuf = cmdbuf_impl,
        timestamp_writes = (descriptor.timestamp_writes != nil ? descriptor.timestamp_writes^ : {}),
    })

    impl.bind_point = .COMPUTE
    impl.is_computing = true

    compute_pass := new_handle(Compute_Pass, impl.device, compute_pass_handle)
    vk_command_encoder_add_ref(command_encoder, loc)

    vk_label_set(
        &device_impl.labels,
        .Compute_Pass,
        pack_handle(compute_pass_handle),
        descriptor.label,
    )

    return compute_pass
}

// Every handle a render-pass descriptor names must belong to this device. The
// pass refused here leaves the command encoder untouched, so ending the returned
// (empty) pass is a no-op and `finish` still succeeds.
@(require_results)
vk_render_pass_descriptor_validate :: proc(
    device: Device,
    device_impl: ^VK_Device_Impl,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> bool {
    valid := true

    view_valid :: proc(
        device: Device,
        device_impl: ^VK_Device_Impl,
        view: Texture_View,
        loc := #caller_location,
    ) -> bool {
        view_impl: ^VK_Texture_View_Impl
        if view != {} {
            view_device := vk_device_get_impl(view.device, loc)
            view_impl = dhm_get_if_valid(
                &view_device.texture_views,
                unpack_handle(VK_Texture_View_Handle, view.handle),
            )
        }
        if view_impl == nil {
            gpu_report_validation_error(device, "attachment view is not a live view", loc)
            return false
        }
        if view_impl.device != device {
            gpu_report_validation_error(device, "attachment view belongs to another device", loc)
            return false
        }
        if vk_texture_get_impl(view_impl.texture, loc).destroyed {
            gpu_report_validation_error(device, "attachment texture has been destroyed", loc)
            return false
        }
        if .Render_Attachment not_in view_impl.public_usage {
            gpu_report_validation_error(
                device,
                "attachment view is missing the [Render_Attachment] usage",
                loc,
            )
            return false
        }
        features, ok := device_describe_format_features(device, view_impl.format, loc)
        if !ok || .Render_Attachment not_in features.allowed_usages {
            gpu_report_validation_error(
                device,
                "attachment format cannot be used as a render attachment",
                loc,
            )
            return false
        }
        return true
    }

    for color in descriptor.color_attachments {
        valid &= view_valid(device, device_impl, color.view, loc)
        if color.resolve_target != {} {
            valid &= view_valid(device, device_impl, color.resolve_target, loc)
        }
    }
    if descriptor.depth_stencil_attachment != nil {
        valid &= view_valid(device, device_impl, descriptor.depth_stencil_attachment.view, loc)
    }

    query_valid :: proc(
        device: Device,
        device_impl: ^VK_Device_Impl,
        set: Query_Set,
        kind: Query_Type,
        check_type: bool,
        loc := #caller_location,
    ) -> bool {
        if set == {} {
            return true
        }
        query_set_device := vk_device_get_impl(set.device, loc)
        set_impl := dhm_get_if_valid(
            &query_set_device.query_sets,
            unpack_handle(VK_Query_Set_Handle, set.handle),
        )
        if set_impl == nil {
            gpu_report_validation_error(device, "query set is not a live query set", loc)
            return false
        }
        if set_impl.device != device {
            gpu_report_validation_error(device, "query set belongs to another device", loc)
            return false
        }
        if check_type && set_impl.type != kind {
            gpu_report_validation_error(device, "query set has the wrong type for the pass", loc)
            return false
        }
        return true
    }

    valid &= query_valid(
        device,
        device_impl,
        descriptor.occlusion_query_set,
        .Occlusion,
        true,
        loc,
    )
    if descriptor.timestamp_writes != nil {
        timestamp := descriptor.timestamp_writes^
        if timestamp.query_set != {} {
            valid &= vk_timestamp_writes_validate(device, device_impl, timestamp, loc)
        }
    }

    if descriptor.color_attachments == nil && descriptor.depth_stencil_attachment == nil {
        gpu_report_validation_error(device, "render pass has no attachments", loc)
        valid = false
    }

    width, height: u32
    have_size := false
    color_samples: u32
    color_attachment_bytes: u32
    limits := _device_get_internal_impl(device, loc).limits

    for color in descriptor.color_attachments {
        view_impl := vk_texture_view_get_impl(color.view, loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, loc)
        if texture_impl.destroyed {
            gpu_report_validation_error(device, "color attachment texture has been destroyed", loc)
            valid = false
        }
        if .Transient_Attachment in texture_impl.public_usage &&
           (color.ops.load != .Clear || color.ops.store != .Discard) {
            gpu_report_validation_error(
                device,
                "a transient color attachment must clear on load and discard on store",
                loc,
            )
            valid = false
        }
        alignment := texture_format_target_component_alignment(view_impl.format, loc)
        cost := texture_format_target_pixel_byte_cost(view_impl.format, loc)
        if alignment > 0 {
            color_attachment_bytes =
                (color_attachment_bytes + alignment - 1) / alignment * alignment + cost
        }
        if texture_format_is_depth_stencil_format(view_impl.format) {
            gpu_report_validation_error(
                device,
                "depth/stencil format cannot be a color attachment",
                loc,
            )
            valid = false
        }
        if view_impl.selector.mip_count != 1 {
            gpu_report_validation_error(
                device,
                "color attachment view must cover one mip level",
                loc,
            )
            valid = false
        }
        if view_impl.selector.layer_count != 1 {
            gpu_report_validation_error(
                device,
                "color attachment view must cover one array layer",
                loc,
            )
            valid = false
        }
        attachment_width := max(
            u32(1),
            u32(texture_impl.vk_extent.width) >> view_impl.selector.mip_start,
        )
        attachment_height := max(
            u32(1),
            u32(texture_impl.vk_extent.height) >> view_impl.selector.mip_start,
        )
        if !have_size {
            width, height, have_size = attachment_width, attachment_height, true
        } else if attachment_width != width || attachment_height != height {
            gpu_report_validation_error(
                device,
                "render pass attachments must have the same size",
                loc,
            )
            valid = false
        }

        if color_samples == 0 {
            color_samples = texture_impl.sample_count
        } else if texture_impl.sample_count != color_samples {
            gpu_report_validation_error(
                device,
                "render pass color attachments must have the same sample count",
                loc,
            )
            valid = false
        }

        if color.resolve_target != {} {
            resolve_impl := vk_texture_view_get_impl(color.resolve_target, loc)
            resolve_texture := vk_texture_get_impl(resolve_impl.texture, loc)
            if resolve_texture.destroyed {
                gpu_report_validation_error(
                    device,
                    "resolve target texture has been destroyed",
                    loc,
                )
                valid = false
            }
            if texture_impl.sample_count == 1 {
                gpu_report_validation_error(
                    device,
                    "a single-sampled attachment cannot have a resolve target",
                    loc,
                )
                valid = false
            }
            if resolve_texture.sample_count != 1 {
                gpu_report_validation_error(device, "resolve target must be single-sampled", loc)
                valid = false
            }
            if resolve_impl.selector.mip_count != 1 || resolve_impl.selector.layer_count != 1 {
                gpu_report_validation_error(
                    device,
                    "resolve target must cover one mip level and one layer",
                    loc,
                )
                valid = false
            }
            resolve_width := max(
                u32(1),
                u32(resolve_texture.vk_extent.width) >> resolve_impl.selector.mip_start,
            )
            resolve_height := max(
                u32(1),
                u32(resolve_texture.vk_extent.height) >> resolve_impl.selector.mip_start,
            )
            if resolve_width != attachment_width || resolve_height != attachment_height {
                gpu_report_validation_error(
                    device,
                    "resolve target must match the attachment size",
                    loc,
                )
                valid = false
            }
            if resolve_impl.format != view_impl.format {
                gpu_report_validation_error(
                    device,
                    "resolve target format must match the attachment format",
                    loc,
                )
                valid = false
            }
            if .Render_Attachment not_in resolve_texture.public_usage {
                gpu_report_validation_error(
                    device,
                    "resolve target requires the [Render_Attachment] usage",
                    loc,
                )
                valid = false
            }
            if .Transient_Attachment in resolve_texture.public_usage {
                gpu_report_validation_error(
                    device,
                    "resolve target cannot have the [Transient_Attachment] usage",
                    loc,
                )
                valid = false
            }
        }
    }

    valid &= gpu_validate(
        device,
        color_attachment_bytes <= limits.max_color_attachment_bytes_per_sample,
        "render pass color attachments exceed the bytes-per-sample budget",
        loc,
    )
    valid &= gpu_validate(
        device,
        u32(len(descriptor.color_attachments)) <= limits.max_color_attachments,
        "render pass declares too many color attachments",
        loc,
    )

    if descriptor.depth_stencil_attachment != nil {
        depth_view := descriptor.depth_stencil_attachment.view
        view_impl := vk_texture_view_get_impl(depth_view, loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, loc)
        if texture_impl.destroyed {
            gpu_report_validation_error(
                device,
                "depth/stencil attachment texture has been destroyed",
                loc,
            )
            valid = false
        }
        if .Transient_Attachment in texture_impl.public_usage {
            aspects := texture_format_aspects_from(view_impl.format)
            if .Depth in aspects &&
               (descriptor.depth_stencil_attachment.depth_ops.load != .Clear ||
                       descriptor.depth_stencil_attachment.depth_ops.store != .Discard) {
                gpu_report_validation_error(
                    device,
                    "a transient depth attachment must clear and discard",
                    loc,
                )
                valid = false
            }
            if .Stencil in aspects &&
               (descriptor.depth_stencil_attachment.stencil_ops.load != .Clear ||
                       descriptor.depth_stencil_attachment.stencil_ops.store != .Discard) {
                gpu_report_validation_error(
                    device,
                    "a transient stencil attachment must clear and discard",
                    loc,
                )
                valid = false
            }
        }
        if !texture_format_is_depth_stencil_format(view_impl.format) {
            gpu_report_validation_error(
                device,
                "depth/stencil attachment must use a depth/stencil format",
                loc,
            )
            valid = false
        }
        if view_impl.selector.mip_count != 1 {
            gpu_report_validation_error(
                device,
                "depth/stencil attachment view must cover one mip level",
                loc,
            )
            valid = false
        }
        if view_impl.selector.layer_count != 1 {
            gpu_report_validation_error(
                device,
                "depth/stencil attachment view must cover one array layer",
                loc,
            )
            valid = false
        }
        depth_width := max(
            u32(1),
            u32(texture_impl.vk_extent.width) >> view_impl.selector.mip_start,
        )
        depth_height := max(
            u32(1),
            u32(texture_impl.vk_extent.height) >> view_impl.selector.mip_start,
        )
        if have_size {
            if depth_width != width || depth_height != height {
                gpu_report_validation_error(
                    device,
                    "depth/stencil attachment must match the color attachment size",
                    loc,
                )
                valid = false
            }
            if color_samples != 0 && texture_impl.sample_count != color_samples {
                gpu_report_validation_error(
                    device,
                    "depth/stencil attachment must match the color sample count",
                    loc,
                )
                valid = false
            }
        }

        depth_ops := descriptor.depth_stencil_attachment.depth_ops
        stencil_ops := descriptor.depth_stencil_attachment.stencil_ops
        depth_present := .Depth in texture_format_aspects_from(view_impl.format)
        stencil_present := .Stencil in texture_format_aspects_from(view_impl.format)

        if depth_present {
            if descriptor.depth_stencil_attachment.depth_read_only {
                if depth_ops.load != .Undefined || depth_ops.store != .Undefined {
                    gpu_report_validation_error(
                        device,
                        "read-only depth aspect must not provide load/store ops",
                        loc,
                    )
                    valid = false
                }
            } else if depth_ops.load == .Undefined || depth_ops.store == .Undefined {
                gpu_report_validation_error(
                    device,
                    "writable depth aspect requires load and store ops",
                    loc,
                )
                valid = false
            }
            if depth_ops.load == .Clear &&
               (depth_ops.clear_value < 0 || depth_ops.clear_value > 1) {
                gpu_report_validation_error(
                    device,
                    "depth clear value must be between 0 and 1",
                    loc,
                )
                valid = false
            }
        }

        if stencil_present {
            if descriptor.depth_stencil_attachment.stencil_read_only {
                if stencil_ops.load != .Undefined || stencil_ops.store != .Undefined {
                    gpu_report_validation_error(
                        device,
                        "read-only stencil aspect must not provide load/store ops",
                        loc,
                    )
                    valid = false
                }
            } else if stencil_ops.load == .Undefined || stencil_ops.store == .Undefined {
                gpu_report_validation_error(
                    device,
                    "writable stencil aspect requires load and store ops",
                    loc,
                )
                valid = false
            }
            if stencil_ops.load == .Clear && stencil_ops.clear_value > 255 {
                gpu_report_validation_error(
                    device,
                    "stencil clear value must be between 0 and 255",
                    loc,
                )
                valid = false
            }
        }
    }

    return valid
}

@(require_results)
vk_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    cmdbuf_impl := vk_command_buffer_get_impl(impl.command_buffer, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    // Basic state validation
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return vk_command_encoder_fail_render_pass(impl, command_encoder, loc)
    }
    if impl.is_computing {
        gpu_report_validation_error(impl.device, "command encoder is computing", loc)
        return vk_command_encoder_fail_render_pass(impl, command_encoder, loc)
    }
    if impl.is_rendering {
        gpu_report_validation_error(impl.device, "command encoder is rendering", loc)
        return vk_command_encoder_fail_render_pass(impl, command_encoder, loc)
    }

    if !vk_render_pass_descriptor_validate(impl.device, device_impl, descriptor, loc) {
        return vk_command_encoder_fail_render_pass(impl, command_encoder, loc)
    }

    desc := _resolve_render_pass_descriptor(impl.device, descriptor, loc)
    clear(&cmdbuf_impl.pass_occlusion_used)

    scope_merge :: proc(
        device: Device,
        scope: ^Usage_Scope,
        view: Texture_View,
        uses: Texture_Uses,
        loc := #caller_location,
    ) {
        view_impl := vk_texture_view_get_impl(view, loc)
        at: Texture_Selector
        current: Texture_Uses
        added: Texture_Uses
        tracked := vk_tracked_texture(
            view_impl.texture,
            vk_texture_get_impl(view_impl.texture, loc),
        )
        ok := texture_usage_scope_merge_single(
            &scope.textures,
            tracked,
            true,
            view_impl.selector,
            uses,
            &at,
            &current,
            &added,
        )
        if !ok {
            gpu_report_validation_error(device, "texture usage conflict in render pass", loc)
        }
    }

    scope := &cmdbuf_impl.pass_scope

    for &color, color_index in desc.color_attachments {
        // A view may appear more than once across the attachments (or as both an
        // attachment and a resolve target); hold one reference per view.
        if _, inserted := stateless_tracker_insert_single(&cmdbuf_impl.tracker.views, color.view);
           inserted {
            vk_texture_view_add_ref(color.view, loc)
        }
        color_view_impl := vk_texture_view_get_impl(color.view, loc)
        for prior in desc.color_attachments[:color_index] {
            prior_impl := vk_texture_view_get_impl(prior.view, loc)
            if prior_impl.texture == color_view_impl.texture &&
               texture_selector_overlaps(prior_impl.selector, color_view_impl.selector) {
                gpu_report_validation_error(
                    impl.device,
                    "one texture subresource is attached more than once",
                    loc,
                )
            }
        }
        scope_merge(impl.device, scope, color.view, {.Color_Target}, loc)
        if color.resolve_target != {} {
            if _, inserted := stateless_tracker_insert_single(
                &cmdbuf_impl.tracker.views,
                color.resolve_target,
            ); inserted {
                vk_texture_view_add_ref(color.resolve_target, loc)
            }
            scope_merge(impl.device, scope, color.resolve_target, {.Color_Target}, loc)
        }
    }

    if ds, ds_ok := desc.depth_stencil_attachment.?; ds_ok {
        if _, inserted := stateless_tracker_insert_single(&cmdbuf_impl.tracker.views, ds.view);
           inserted {
            vk_texture_view_add_ref(ds.view, loc)
        }
        scope_merge(impl.device, scope, ds.view, desc.ds_uses, loc)
    }

    cmd := Begin_Render_Pass_Cmd {
        color_attachments        = desc.color_attachments,
        depth_stencil_attachment = desc.depth_stencil_attachment,
        multiview_mask           = desc.multiview_mask,
        timestamp_writes         = desc.timestamp_writes,
        occlusion_query_set      = desc.occlusion_query_set,
        width                    = desc.width,
        height                   = desc.height,
    }

    // Initial device-to-start barriers go into the main buffer, before the pass
    // buffer is isolated.
    vk_command_encoder_prepare(cmdbuf_impl, loc)
    vk_command_buffer_begin_isolated(cmdbuf_impl, loc)

    // Acquired swapchain images have undefined contents; re-enter the attachment
    // layout in this buffer, immediately before the pass begins.
    for &color in desc.color_attachments {
        if color.view == {} {
            continue
        }
        view_impl := vk_texture_view_get_impl(color.view, loc)
        texture_impl := vk_texture_get_impl(view_impl.texture, loc)
        if texture_impl.is_swapchain {
            vk_record_transition_texture(
                device_impl,
                cmdbuf_impl.current_cmdbuf,
                view_impl.texture,
                nil,
                TEXTURE_USES_UNINITIALIZED,
                {.Color_Target},
                false,
                loc,
            )
        }
    }

    begin_state := vk_render_pass_begin_record(impl.device, cmdbuf_impl, &cmd, loc)

    rpass_impl, rpass_handle := add_impl(&device_impl.render_passes, VK_Render_Pass_Impl {
            base = _Render_Pass_Impl {
                device            = impl.device,
                encoder           = command_encoder,
                color_formats     = desc.color_formats,
                depth_stencil     = desc.depth_stencil,
                has_depth_stencil = desc.has_depth_stencil,
                sample_count      = desc.sample_count,
                is_rendering      = true,
            },
            cached_encoder = impl,
            cached_cmdbuf = cmdbuf_impl,
            bind_groups_dirty = true,
            occlusion_query_set = cmd.occlusion_query_set,
        })
    if timestamp_writes, has_timestamps := cmd.timestamp_writes.?; has_timestamps {
        rpass_impl.timestamp_writes = timestamp_writes
    }
    rpass_impl.present_textures = begin_state.present_textures
    rpass_impl.present_count = begin_state.present_count
    if ds, ds_ok := desc.depth_stencil_attachment.?; ds_ok {
        ds_view_impl := vk_texture_view_get_impl(ds.view, loc)
        rpass_impl.depth_texture = ds_view_impl.texture
        rpass_impl.depth_selector = ds_view_impl.selector
        rpass_impl.depth_uses = desc.ds_uses
    }
    rpass_impl.width = desc.width
    rpass_impl.height = desc.height

    impl.bind_point = .GRAPHICS
    impl.is_rendering = true

    rpass := new_handle(Render_Pass, impl.device, rpass_handle)
    vk_command_encoder_add_ref(command_encoder, loc)

    return rpass
}

vk_command_encoder_clear_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    buffer_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, buffer.handle),
    )
    if buffer_impl == nil {
        gpu_report_validation_error(impl.device, "buffer is not a live handle", loc)
        return
    }
    if buffer_impl.destroyed {
        gpu_report_validation_error(impl.device, "buffer has been destroyed", loc)
        return
    }
    if buffer.device != impl.device {
        gpu_report_validation_error(impl.device, "buffer belongs to another device", loc)
        return
    }

    valid := gpu_validate(
        impl.device,
        .Copy_Dst in buffer_impl.public_usage,
        "clear_buffer requires the [Copy_Dst] usage",
        loc,
    )

    resolved_size := size
    if resolved_size == WHOLE_SIZE && offset <= buffer_impl.visible_size {
        resolved_size = buffer_impl.visible_size - offset
    }
    valid &= gpu_validate(
        impl.device,
        offset % 4 == 0,
        "clear_buffer offset must be a multiple of 4",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        resolved_size % 4 == 0,
        "clear_buffer size must be a multiple of 4",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        offset <= buffer_impl.visible_size && resolved_size <= buffer_impl.visible_size - offset,
        "clear_buffer range is out of bounds",
        loc,
    )
    if !valid {
        return
    }

    // A clear writes the destination, exactly as a copy into it would.
    vk_command_encoder_track_buffer(
        command_encoder,
        buffer,
        {.Copy_Dst},
        "buffer usage conflict in clear_buffer",
        loc,
    )

    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)
    vk_flush_pending_transitions(device_impl, impl.cmdbuf, loc)

    vk_record_clear_buffer(
        device_impl,
        impl.cmdbuf.current_cmdbuf,
        Clear_Buffer_Cmd{dst = buffer, offset = offset, size = resolved_size},
        loc,
    )

    clear_end := offset + resolved_size
    buffer_init_tracker_mark_initialized(&buffer_impl.init, offset, clear_end)
}

vk_command_encoder_clear_buffer_internal :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_record_clear_buffer(
        device_impl,
        impl.cmdbuf.current_cmdbuf,
        Clear_Buffer_Cmd{dst = buffer, offset = offset, size = size},
        loc,
    )
}

// Copy recorded by the internal queue-write path, where the caller has already
// validated the ranges and the buffers are known live:
//
// - the destination's `-> Copy_Dst` transition goes through the *device* tracker
//   (one barrier the first time a buffer is written in this batch, none after),
//   instead of the command buffer's usage scope, which the public copy path folds
//   on every call. Folding a scope that grows by one entry per copy made the
//   batch O(n^2) in the number of uploads: 2000 uploads re-walked up to 2000
//   entries each time.
// - init holes are still filled per range, because a repeated write to a
//   different offset still has to define the bytes it covers.
vk_command_encoder_copy_buffer_internal :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    dst_impl := vk_buffer_get_impl(destination, loc)
    src_impl := vk_buffer_get_impl(source, loc)

    barriers: [1]Buffer_State_Transition
    transitioned: [dynamic]Buffer_State_Transition
    transitioned.allocator = context.temp_allocator
    defer delete(transitioned)

    {
        sync.guard(&device_impl.trackers_mtx)
        device_buffer_tracker_set_single(
            &device_impl.trackers.buffers,
            dst_impl.tracker_index,
            destination,
            {.Copy_Dst},
            &transitioned,
        )
    }
    if len(transitioned) > 0 {
        vk_encode_barriers(device_impl, impl.cmdbuf, nil, transitioned[:], loc)
    }
    _ = barriers

    vk_init_fill_buffer_holes(
        device_impl,
        impl.cmdbuf,
        destination,
        dst_impl,
        destination_offset,
        destination_offset + size,
        loc,
    )

    region := vk.BufferCopy {
        srcOffset = vk.DeviceSize(source_offset),
        dstOffset = vk.DeviceSize(destination_offset),
        size      = vk.DeviceSize(size),
    }
    device_impl.fp.CmdCopyBuffer(
        impl.cmdbuf.current_cmdbuf,
        src_impl.vk_buffer,
        dst_impl.vk_buffer,
        1,
        &region,
    )
}

vk_command_encoder_clear_texture :: proc(
    command_encoder: Command_Encoder,
    texture: Texture,
    range: Image_Subresource_Range,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    texture_impl := vk_texture_get_impl(texture, loc)
    mip_count := range.mip_level_count
    if mip_count == 0 {
        mip_count = texture_impl.num_levels - range.base_mip_level
    }
    layer_count := range.array_layer_count
    if layer_count == 0 {
        layer_count = texture_impl.num_layers - range.base_array_layer
    }

    selector := Texture_Selector {
        mip_start   = range.base_mip_level,
        mip_count   = mip_count,
        layer_start = range.base_array_layer,
        layer_count = layer_count,
    }

    vk_command_encoder_record_texture_transition(
        impl,
        texture,
        range.base_mip_level,
        range.base_array_layer,
        layer_count,
        range.aspect,
        {.Copy_Dst},
        loc,
    )

    vk_init_clear_texture_range(
        vk_device_get_impl(impl.device, loc),
        impl.cmdbuf.current_cmdbuf,
        texture_impl,
        selector,
        range.aspect,
        loc,
    )

    init_range := Texture_Init_Range {
        mip_start   = range.base_mip_level,
        mip_end     = range.base_mip_level + mip_count,
        layer_start = range.base_array_layer,
        layer_end   = range.base_array_layer + layer_count,
    }
    aspects := init_tracked_aspects(texture_impl.format, range.aspect)
    for i in 0 ..< aspects.count {
        texture_init_tracker_mark_initialized(&texture_impl.init, init_range, aspects.slots[i])
    }
}

vk_command_encoder_copy_buffer_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    // device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    valid := true

    src_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, source.handle),
    )
    dst_impl := dhm_get_if_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, destination.handle),
    )
    valid &= gpu_validate(impl.device, src_impl != nil, "copy source is not a live buffer", loc)
    valid &= gpu_validate(
        impl.device,
        dst_impl != nil,
        "copy destination is not a live buffer",
        loc,
    )
    if !valid {
        return
    }

    valid = true
    valid &= gpu_validate(impl.device, !src_impl.destroyed, "copy source has been destroyed", loc)
    valid &= gpu_validate(
        impl.device,
        !dst_impl.destroyed,
        "copy destination has been destroyed",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        source.device == impl.device,
        "copy source belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination.device == impl.device,
        "copy destination belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        source != destination,
        "copying between a buffer and itself is not allowed",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        .Copy_Src in src_impl.public_usage,
        "copy source requires the [Copy_Src] usage",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        .Copy_Dst in dst_impl.public_usage,
        "copy destination requires the [Copy_Dst] usage",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        source_offset % 4 == 0,
        "copy source offset must be a multiple of 4",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination_offset % 4 == 0,
        "copy destination offset must be a multiple of 4",
        loc,
    )
    valid &= gpu_validate(impl.device, size % 4 == 0, "copy size must be a multiple of 4", loc)
    valid &= gpu_validate(
        impl.device,
        source_offset <= src_impl.visible_size && size <= src_impl.visible_size - source_offset,
        "copy source range is out of bounds",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination_offset <= dst_impl.visible_size &&
        size <= dst_impl.visible_size - destination_offset,
        "copy destination range is out of bounds",
        loc,
    )
    if !valid {
        return
    }

    // Recorded outside any pass, so this lands in the command buffer's global
    // scope. Source and destination are ordered, not concurrent.
    vk_command_encoder_track_buffer(
        command_encoder,
        source,
        {.Copy_Src},
        "buffer usage conflict in copy_buffer_to_buffer",
        loc,
    )
    vk_command_encoder_track_buffer(
        command_encoder,
        destination,
        {.Copy_Dst},
        "buffer usage conflict in copy_buffer_to_buffer",
        loc,
    )

    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)
    vk_flush_pending_transitions(device_impl, impl.cmdbuf, loc)

    vk_init_fill_buffer_holes(
        device_impl,
        impl.cmdbuf,
        destination,
        dst_impl,
        destination_offset,
        destination_offset + size,
        loc,
    )

    region := vk.BufferCopy {
        srcOffset = vk.DeviceSize(source_offset),
        dstOffset = vk.DeviceSize(destination_offset),
        size      = vk.DeviceSize(size),
    }
    device_impl.fp.CmdCopyBuffer(
        impl.cmdbuf.current_cmdbuf,
        src_impl.vk_buffer,
        dst_impl.vk_buffer,
        1,
        &region,
    )
}

// Record a texture subresource transition for an explicit copy, emitting the
// tracker's pending transitions as commands the copy will follow.
vk_command_encoder_record_texture_transition :: proc(
    encoder_impl: ^VK_Command_Encoder_Impl,
    texture: Texture,
    mip_level: u32,
    base_layer: u32,
    layer_count: u32,
    aspect: Texture_Aspect,
    uses: Texture_Uses,
    loc := #caller_location,
) {
    selector := Texture_Selector {
        mip_start   = mip_level,
        mip_count   = 1,
        layer_start = base_layer,
        layer_count = layer_count,
    }
    texture_impl := vk_texture_get_impl(texture, loc)
    device_impl := vk_device_get_impl(encoder_impl.device, loc)

    texture_tracker_set_single(
        &encoder_impl.cmdbuf.tracker.textures,
        vk_tracked_texture(texture, texture_impl),
        selector,
        uses,
    )

    // Emit the pending transitions directly; the copy follows them.
    for &transition in encoder_impl.cmdbuf.tracker.textures.temp {
        vk_record_transition_texture(
            device_impl,
            encoder_impl.cmdbuf.current_cmdbuf,
            transition.texture,
            Image_Subresource_Range {
                aspect            = aspect,
                base_mip_level    = transition.selector.mip_start,
                mip_level_count   = transition.selector.mip_count,
                base_array_layer  = transition.selector.layer_start,
                array_layer_count = transition.selector.layer_count,
            },
            transition.from,
            transition.to,
            transition.from != TEXTURE_USES_UNKNOWN,
            loc,
        )
    }
    texture_tracker_clear_pending(&encoder_impl.cmdbuf.tracker.textures)
}

// Shared validation for buffer<->texture copies: handles, device, usage,
// sample count, aspect, mip/rectangle bounds and the linear layout.
vk_texture_buffer_copy_check :: proc(
    device_impl: ^VK_Device_Impl,
    texture: Texture,
    texture_impl: ^VK_Texture_Impl,
    buffer: Buffer,
    buffer_impl: ^VK_Buffer_Impl,
    texture_info: Texel_Copy_Texture_Info,
    buffer_info: Texel_Copy_Buffer_Info,
    size: Extent_3D,
    buffer_to_texture: bool,
    loc := #caller_location,
) -> bool {
    device := Device(device_impl)
    valid := true
    valid &= gpu_validate(device, !texture_impl.destroyed, "copy texture has been destroyed", loc)
    valid &= gpu_validate(device, !buffer_impl.destroyed, "copy buffer has been destroyed", loc)
    valid &= gpu_validate(
        device,
        texture.device == device,
        "copy texture belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        device,
        buffer.device == device,
        "copy buffer belongs to another device",
        loc,
    )

    if buffer_to_texture {
        valid &= gpu_validate(
            device,
            .Copy_Dst in texture_impl.public_usage,
            "copy destination texture requires the [Copy_Dst] usage",
            loc,
        )
        valid &= gpu_validate(
            device,
            .Copy_Src in buffer_impl.public_usage,
            "copy source buffer requires the [Copy_Src] usage",
            loc,
        )
    } else {
        valid &= gpu_validate(
            device,
            .Copy_Src in texture_impl.public_usage,
            "copy source texture requires the [Copy_Src] usage",
            loc,
        )
        valid &= gpu_validate(
            device,
            .Copy_Dst in buffer_impl.public_usage,
            "copy destination buffer requires the [Copy_Dst] usage",
            loc,
        )
    }

    valid &= gpu_validate(
        device,
        texture_impl.sample_count == 1,
        "multisampled textures cannot be copied to or from a buffer",
        loc,
    )
    valid &= gpu_validate(
        device,
        texture_info.mip_level < texture_impl.num_levels,
        "copy mip level is out of bounds",
        loc,
    )

    aspects := texture_format_aspects_from(texture_impl.format)
    aspect_ok := texture_format_depth_stencil_copy_supported(
        texture_impl.format,
        texture_info.aspect,
        buffer_to_texture,
    )
    #partial switch texture_info.aspect {
    case .Plane0, .Plane1, .Plane2:
        aspect_ok = true
    case:
    }
    valid &= gpu_validate(
        device,
        aspect_ok,
        "copy aspect is not valid for the texture format",
        loc,
    )
    if !valid {
        return false
    }

    mip_width := max(u32(1), u32(texture_impl.vk_extent.width) >> texture_info.mip_level)
    mip_height := max(u32(1), u32(texture_impl.vk_extent.height) >> texture_info.mip_level)
    mip_depth := max(u32(1), u32(texture_impl.vk_extent.depth) >> texture_info.mip_level)

    valid &= gpu_validate(
        device,
        texture_info.origin.x + size.width <= mip_width &&
        texture_info.origin.y + size.height <= mip_height,
        "copy rectangle is out of bounds",
        loc,
    )
    if texture_impl.dimension == .D3 {
        valid &= gpu_validate(
            device,
            texture_info.origin.z + size.depth_or_array_layers <= mip_depth,
            "copy depth is out of bounds",
            loc,
        )
    } else {
        valid &= gpu_validate(
            device,
            texture_info.origin.z + size.depth_or_array_layers <= texture_impl.num_layers,
            "copy layers are out of bounds",
            loc,
        )
    }

    layout := buffer_info.layout

    block_width, block_height := texture_format_block_dimensions(texture_impl.format)
    block_size := texture_format_block_copy_size(texture_impl.format, texture_info.aspect)
    width_blocks := u64((size.width + block_width - 1) / block_width)
    height_blocks := u64((size.height + block_height - 1) / block_height)
    layers := u64(size.depth_or_array_layers)
    bytes_in_last_row := width_blocks * u64(block_size)

    offset_alignment := u64(block_size)
    if .Depth in aspects || .Stencil in aspects {
        offset_alignment = max(offset_alignment, 4)
    }
    valid &= gpu_validate(
        device,
        layout.offset % offset_alignment == 0,
        "copy buffer offset is not block aligned",
        loc,
    )

    if texture_format_is_compressed(texture_impl.format) {
        valid &= gpu_validate(
            device,
            texture_info.origin.x % block_width == 0 &&
            texture_info.origin.y % block_height == 0 &&
            size.width % block_width == 0 &&
            size.height % block_height == 0,
            "compressed copy rectangle must be block aligned",
            loc,
        )
    }

    bytes_per_row := u64(layout.bytes_per_row)
    rows_per_image := u64(layout.rows_per_image)
    defined_pitch := layout.bytes_per_row != COPY_STRIDE_UNDEFINED
    defined_rows := layout.rows_per_image != COPY_STRIDE_UNDEFINED

    if defined_pitch {
        valid &= gpu_validate(
            device,
            bytes_per_row % 256 == 0,
            "copy bytesPerRow must be a multiple of 256",
            loc,
        )
        valid &= gpu_validate(
            device,
            bytes_per_row >= bytes_in_last_row,
            "copy bytesPerRow is smaller than a row",
            loc,
        )
        valid &= gpu_validate(
            device,
            bytes_per_row != 0 || height_blocks <= 1,
            "copy bytesPerRow is required for a multi-row copy",
            loc,
        )
    } else {
        valid &= gpu_validate(
            device,
            height_blocks <= 1,
            "copy bytesPerRow is required for a multi-row copy",
            loc,
        )
        bytes_per_row = (bytes_in_last_row + 255) & ~u64(255)
    }
    if !defined_rows {
        valid &= gpu_validate(
            device,
            layers <= 1,
            "copy rowsPerImage is required for a multi-image copy",
            loc,
        )
        rows_per_image = height_blocks
    } else {
        valid &= gpu_validate(
            device,
            rows_per_image >= height_blocks,
            "copy rowsPerImage is smaller than the copy height",
            loc,
        )
    }

    if valid {
        required := u128(layout.offset)
        if layers > 1 {
            required += u128(bytes_per_row) * u128(rows_per_image) * u128(layers - 1)
        }
        if height_blocks > 1 {
            required += u128(bytes_per_row) * u128(height_blocks - 1)
        }
        required += u128(bytes_in_last_row)
        valid &= gpu_validate(
            device,
            required <= u128(buffer_impl.visible_size),
            "copy buffer is too small for the layout",
            loc,
        )
    }

    return valid
}

vk_command_encoder_copy_buffer_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    impl_device := vk_device_get_impl(impl.device, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    src := source
    dst := destination
    size := copy_size

    src_impl := dhm_get_if_valid(
        &impl_device.buffers,
        unpack_handle(VK_Buffer_Handle, src.buffer.handle),
    )
    if src_impl == nil {
        gpu_report_validation_error(impl.device, "copy source is not a live buffer", loc)
        return
    }
    dst_impl := dhm_get_if_valid(
        &impl_device.textures,
        unpack_handle(VK_Texture_Handle, dst.texture.handle),
    )
    if dst_impl == nil {
        gpu_report_validation_error(impl.device, "copy destination is not a live texture", loc)
        return
    }

    if !vk_texture_buffer_copy_check(
        impl_device,
        dst.texture,
        dst_impl,
        src.buffer,
        src_impl,
        dst,
        src,
        size,
        true,
        loc,
    ) {
        return
    }

    vk_command_encoder_track_buffer(
        command_encoder,
        src.buffer,
        {.Copy_Src},
        "buffer usage conflict in copy_buffer_to_texture",
        loc,
    )
    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)
    vk_flush_pending_transitions(impl_device, impl.cmdbuf, loc)

    is_3d := dst_impl.dimension == .D3
    vk_command_encoder_record_texture_transition(
        impl,
        dst.texture,
        dst.mip_level,
        is_3d ? 0 : dst.origin.z,
        is_3d ? 1 : size.depth_or_array_layers,
        dst.aspect,
        {.Copy_Dst},
        loc,
    )

    dst_layers := u32(1) if is_3d else size.depth_or_array_layers
    dst_base_layer := u32(0) if is_3d else dst.origin.z
    vk_init_clear_texture_undefined_per_slot(
        impl_device,
        impl.cmdbuf,
        dst_impl,
        Texture_Init_Range {
            mip_start   = dst.mip_level,
            mip_end     = dst.mip_level + 1,
            layer_start = dst_base_layer,
            layer_end   = dst_base_layer + dst_layers,
        },
        dst.aspect,
        loc,
    )
    vk_init_transfer_write_barrier(impl_device, impl.cmdbuf.current_cmdbuf)

    block_width, block_height := texture_format_block_dimensions(dst_impl.format)
    block_size := texture_format_block_copy_size(dst_impl.format, dst.aspect)

    copy_region := vk.BufferImageCopy {
        bufferOffset = vk.DeviceSize(src.layout.offset),
        bufferRowLength = u32((src.layout.bytes_per_row / block_size) * block_width),
        bufferImageHeight = u32(src.layout.rows_per_image * block_height),
        imageSubresource = vk.ImageSubresourceLayers {
            aspectMask     = vk_conv_to_image_aspect_flags(dst.aspect, dst_impl.format),
            mipLevel       = dst.mip_level,
            baseArrayLayer = is_3d ? 0 : dst.origin.z,
            layerCount     = is_3d ? 1 : size.depth_or_array_layers,
        },
        imageOffset = vk.Offset3D {
            x = i32(dst.origin.x),
            y = i32(dst.origin.y),
            z = is_3d ? i32(dst.origin.z) : 0,
        },
        imageExtent = vk.Extent3D {
            width  = size.width,
            height = size.height,
            depth  = is_3d ? size.depth_or_array_layers : 1,
        },
    }

    impl_device.fp.CmdCopyBufferToImage(
        impl.cmdbuf.current_cmdbuf,
        src_impl.vk_buffer,
        dst_impl.vk_image,
        .TRANSFER_DST_OPTIMAL,
        1,
        &copy_region,
    )
}

vk_command_encoder_copy_texture_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    impl_device := vk_device_get_impl(impl.device, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    src := source
    dst := destination
    size := copy_size

    src_impl := dhm_get_if_valid(
        &impl_device.textures,
        unpack_handle(VK_Texture_Handle, src.texture.handle),
    )
    if src_impl == nil {
        gpu_report_validation_error(impl.device, "copy source is not a live texture", loc)
        return
    }
    dst_impl := dhm_get_if_valid(
        &impl_device.buffers,
        unpack_handle(VK_Buffer_Handle, dst.buffer.handle),
    )
    if dst_impl == nil {
        gpu_report_validation_error(impl.device, "copy destination is not a live buffer", loc)
        return
    }

    if !vk_texture_buffer_copy_check(
        impl_device,
        src.texture,
        src_impl,
        dst.buffer,
        dst_impl,
        src,
        dst,
        size,
        false,
        loc,
    ) {
        return
    }
    is_3d := src_impl.dimension == .D3
    vk_command_encoder_record_texture_transition(
        impl,
        src.texture,
        src.mip_level,
        is_3d ? 0 : src.origin.z,
        is_3d ? 1 : size.depth_or_array_layers,
        src.aspect,
        {.Copy_Src},
        loc,
    )

    vk_command_encoder_track_buffer(
        command_encoder,
        dst.buffer,
        {.Copy_Dst},
        "buffer usage conflict in copy_texture_to_buffer",
        loc,
    )
    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)
    vk_flush_pending_transitions(impl_device, impl.cmdbuf, loc)

    block_width, block_height := texture_format_block_dimensions(src_impl.format)
    block_size := texture_format_block_copy_size(src_impl.format, src.aspect)

    copy_region := vk.BufferImageCopy {
        bufferOffset = vk.DeviceSize(dst.layout.offset),
        bufferRowLength = u32((dst.layout.bytes_per_row / block_size) * block_width),
        bufferImageHeight = u32(dst.layout.rows_per_image * block_height),
        imageSubresource = vk.ImageSubresourceLayers {
            aspectMask     = vk_conv_to_image_aspect_flags(src.aspect, src_impl.format),
            mipLevel       = src.mip_level,
            baseArrayLayer = is_3d ? 0 : src.origin.z,
            layerCount     = is_3d ? 1 : size.depth_or_array_layers,
        },
        imageOffset = vk.Offset3D {
            x = i32(src.origin.x),
            y = i32(src.origin.y),
            z = is_3d ? i32(src.origin.z) : 0,
        },
        imageExtent = vk.Extent3D {
            width  = size.width,
            height = size.height,
            depth  = is_3d ? size.depth_or_array_layers : 1,
        },
    }

    impl_device.fp.CmdCopyImageToBuffer(
        impl.cmdbuf.current_cmdbuf,
        src_impl.vk_image,
        .TRANSFER_SRC_OPTIMAL,
        dst_impl.vk_buffer,
        1,
        &copy_region,
    )
}

vk_command_encoder_copy_texture_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)

    impl_device := vk_device_get_impl(impl.device, loc)
    src_impl := dhm_get_if_valid(
        &impl_device.textures,
        unpack_handle(VK_Texture_Handle, source.texture.handle),
    )
    dst_impl := dhm_get_if_valid(
        &impl_device.textures,
        unpack_handle(VK_Texture_Handle, destination.texture.handle),
    )
    valid := gpu_validate(impl.device, src_impl != nil, "copy source is not a live texture", loc)
    valid &= gpu_validate(
        impl.device,
        dst_impl != nil,
        "copy destination is not a live texture",
        loc,
    )
    if !valid {
        return
    }

    valid = true
    valid &= gpu_validate(impl.device, !src_impl.destroyed, "copy source has been destroyed", loc)
    valid &= gpu_validate(
        impl.device,
        !dst_impl.destroyed,
        "copy destination has been destroyed",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        source.texture.device == impl.device,
        "copy source belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination.texture.device == impl.device,
        "copy destination belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        .Copy_Src in src_impl.public_usage,
        "copy source requires the [Copy_Src] usage",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        .Copy_Dst in dst_impl.public_usage,
        "copy destination requires the [Copy_Dst] usage",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        src_impl.sample_count == dst_impl.sample_count,
        "copy textures must have the same sample count",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        texture_format_remove_srgb_suffix(src_impl.format) ==
        texture_format_remove_srgb_suffix(dst_impl.format),
        "copy textures must have compatible formats",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        source.aspect == destination.aspect,
        "copy source and destination aspects must match",
        loc,
    )

    valid &= gpu_validate(
        impl.device,
        source.mip_level < src_impl.num_levels,
        "copy source mip level is out of bounds",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination.mip_level < dst_impl.num_levels,
        "copy destination mip level is out of bounds",
        loc,
    )

    if valid {
        src_mip_width := max(u32(1), u32(src_impl.vk_extent.width) >> source.mip_level)
        src_mip_height := max(u32(1), u32(src_impl.vk_extent.height) >> source.mip_level)
        src_mip_depth := max(u32(1), u32(src_impl.vk_extent.depth) >> source.mip_level)
        dst_mip_width := max(u32(1), u32(dst_impl.vk_extent.width) >> destination.mip_level)
        dst_mip_height := max(u32(1), u32(dst_impl.vk_extent.height) >> destination.mip_level)
        dst_mip_depth := max(u32(1), u32(dst_impl.vk_extent.depth) >> destination.mip_level)

        if texture_format_is_compressed(src_impl.format) {
            block_width, block_height := texture_format_block_dimensions(src_impl.format)
            src_mip_width = (src_mip_width + block_width - 1) / block_width * block_width
            src_mip_height = (src_mip_height + block_height - 1) / block_height * block_height
            dst_mip_width = (dst_mip_width + block_width - 1) / block_width * block_width
            dst_mip_height = (dst_mip_height + block_height - 1) / block_height * block_height
        }

        if src_impl.sample_count > 1 {
            valid &= gpu_validate(
                impl.device,
                source.origin.x == 0 &&
                source.origin.y == 0 &&
                destination.origin.x == 0 &&
                destination.origin.y == 0 &&
                copy_size.width == src_mip_width &&
                copy_size.height == src_mip_height,
                "a multisampled copy must cover the whole subresource",
                loc,
            )
        }

        if source.texture == destination.texture && source.mip_level == destination.mip_level {
            src_z_end := source.origin.z + copy_size.depth_or_array_layers
            dst_z_end := destination.origin.z + copy_size.depth_or_array_layers
            src_x_end := source.origin.x + copy_size.width
            dst_x_end := destination.origin.x + copy_size.width
            src_y_end := source.origin.y + copy_size.height
            dst_y_end := destination.origin.y + copy_size.height
            if source.origin.z < dst_z_end &&
               destination.origin.z < src_z_end &&
               source.origin.x < dst_x_end &&
               destination.origin.x < src_x_end &&
               source.origin.y < dst_y_end &&
               destination.origin.y < src_y_end {
                gpu_report_validation_error(
                    impl.device,
                    "copy source and destination regions overlap",
                    loc,
                )
                valid = false
            }
        }

        if texture_format_is_depth_stencil_format(src_impl.format) {
            valid &= gpu_validate(
                impl.device,
                source.origin.x == 0 &&
                source.origin.y == 0 &&
                destination.origin.x == 0 &&
                destination.origin.y == 0 &&
                copy_size.width == src_mip_width &&
                copy_size.height == src_mip_height &&
                copy_size.width == dst_mip_width &&
                copy_size.height == dst_mip_height,
                "a depth/stencil copy must cover the whole subresource",
                loc,
            )
        }

        valid &= gpu_validate(
            impl.device,
            source.origin.x + copy_size.width <= src_mip_width &&
            source.origin.y + copy_size.height <= src_mip_height,
            "copy source rectangle is out of bounds",
            loc,
        )
        valid &= gpu_validate(
            impl.device,
            destination.origin.x + copy_size.width <= dst_mip_width &&
            destination.origin.y + copy_size.height <= dst_mip_height,
            "copy destination rectangle is out of bounds",
            loc,
        )

        src_is_3d := src_impl.dimension == .D3
        dst_is_3d := dst_impl.dimension == .D3
        if src_is_3d {
            valid &= gpu_validate(
                impl.device,
                source.origin.z + copy_size.depth_or_array_layers <= src_mip_depth,
                "copy source depth is out of bounds",
                loc,
            )
        } else {
            valid &= gpu_validate(
                impl.device,
                source.origin.z + copy_size.depth_or_array_layers <= src_impl.num_layers,
                "copy source layers are out of bounds",
                loc,
            )
        }
        if dst_is_3d {
            valid &= gpu_validate(
                impl.device,
                destination.origin.z + copy_size.depth_or_array_layers <= dst_mip_depth,
                "copy destination depth is out of bounds",
                loc,
            )
        } else {
            valid &= gpu_validate(
                impl.device,
                destination.origin.z + copy_size.depth_or_array_layers <= dst_impl.num_layers,
                "copy destination layers are out of bounds",
                loc,
            )
        }

        if texture_format_is_compressed(src_impl.format) {
            block_width, block_height := texture_format_block_dimensions(src_impl.format)
            valid &= gpu_validate(
                impl.device,
                source.origin.x % block_width == 0 &&
                source.origin.y % block_height == 0 &&
                destination.origin.x % block_width == 0 &&
                destination.origin.y % block_height == 0,
                "compressed copy origins must be block aligned",
                loc,
            )
            valid &= gpu_validate(
                impl.device,
                copy_size.width % block_width == 0 && copy_size.height % block_height == 0,
                "compressed copy extents must be block aligned",
                loc,
            )
        }
    }

    if !valid {
        return
    }

    // Layer coverage: 3D packs depth slices into one layer, 2D arrays copy
    // base_layer..base_layer+count.
    is_3d := dst_impl.dimension == .D3
    src_layers := u32(1) if is_3d else copy_size.depth_or_array_layers
    dst_layers := u32(1) if is_3d else copy_size.depth_or_array_layers
    vk_command_encoder_record_texture_transition(
        impl,
        source.texture,
        source.mip_level,
        is_3d ? u32(0) : source.origin.z,
        src_layers,
        source.aspect,
        {.Copy_Src},
        loc,
    )
    vk_command_encoder_record_texture_transition(
        impl,
        destination.texture,
        destination.mip_level,
        is_3d ? u32(0) : destination.origin.z,
        dst_layers,
        destination.aspect,
        {.Copy_Dst},
        loc,
    )

    dst_base_layer := u32(0) if is_3d else destination.origin.z
    vk_init_clear_texture_undefined_per_slot(
        impl_device,
        impl.cmdbuf,
        dst_impl,
        Texture_Init_Range {
            mip_start   = destination.mip_level,
            mip_end     = destination.mip_level + 1,
            layer_start = dst_base_layer,
            layer_end   = dst_base_layer + dst_layers,
        },
        destination.aspect,
        loc,
    )
    vk_init_transfer_write_barrier(impl_device, impl.cmdbuf.current_cmdbuf)

    copy_region := vk.ImageCopy {
        srcSubresource = vk.ImageSubresourceLayers {
            aspectMask     = vk_conv_to_image_aspect_flags(source.aspect, src_impl.format),
            mipLevel       = source.mip_level,
            baseArrayLayer = is_3d ? 0 : source.origin.z,
            layerCount     = src_layers,
        },
        srcOffset = vk.Offset3D {
            x = i32(source.origin.x),
            y = i32(source.origin.y),
            z = is_3d ? i32(source.origin.z) : 0,
        },
        dstSubresource = vk.ImageSubresourceLayers {
            aspectMask     = vk_conv_to_image_aspect_flags(destination.aspect, dst_impl.format),
            mipLevel       = destination.mip_level,
            baseArrayLayer = is_3d ? 0 : destination.origin.z,
            layerCount     = dst_layers,
        },
        dstOffset = vk.Offset3D {
            x = i32(destination.origin.x),
            y = i32(destination.origin.y),
            z = is_3d ? i32(destination.origin.z) : 0,
        },
        extent = vk.Extent3D {
            width  = copy_size.width,
            height = copy_size.height,
            depth  = is_3d ? copy_size.depth_or_array_layers : 1,
        },
    }

    device_impl.fp.CmdCopyImage(
        impl.cmdbuf.current_cmdbuf,
        src_impl.vk_image,
        .TRANSFER_SRC_OPTIMAL,
        dst_impl.vk_image,
        .TRANSFER_DST_OPTIMAL,
        1,
        &copy_region,
    )
}

vk_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "finishing an encoder that is not encoding", loc)
        return {}
    }
    if impl.is_computing {
        gpu_report_validation_error(impl.device, "finishing an encoder in a compute pass", loc)
        return {}
    }
    if impl.is_rendering {
        gpu_report_validation_error(impl.device, "finishing an encoder in a render pass", loc)
        return {}
    }
    if impl.invalid {
        gpu_report_validation_error(impl.device, "finishing an invalid command encoder", loc)
        return {}
    }

    if impl.debug_group_depth != 0 {
        gpu_report_validation_error(impl.cmdbuf.device, "debug group stack was not popped", loc)
        impl.debug_group_depth = 0
    }

    impl.is_encoding = false

    // Fold the non-pass commands' usage in now. Passes have already folded
    // theirs at pass end, and every scope is closed by the time the encoder is.
    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)

    // New, independent owner: whoever receives this return value.
    vk_command_buffer_add_ref(impl.command_buffer, loc)

    return impl.command_buffer
}

// Debug markers and groups are accepted but not emitted: labels are counted, not
// recorded as Vulkan debug labels.
vk_command_encoder_insert_debug_marker :: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
    }
}

vk_command_encoder_pop_debug_group :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }
    if impl.debug_group_depth == 0 {
        gpu_report_validation_error(impl.cmdbuf.device, "debug group stack underflow", loc)
        return
    }
    impl.debug_group_depth -= 1
}

vk_command_encoder_push_debug_group :: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }
    impl.debug_group_depth += 1
}

vk_command_encoder_resolve_query_set :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    set_live := dhm_is_valid(
        &device_impl.query_sets,
        unpack_handle(VK_Query_Set_Handle, query_set.handle),
    )
    dest_live := dhm_is_valid(
        &device_impl.buffers,
        unpack_handle(VK_Buffer_Handle, destination.handle),
    )
    valid := gpu_validate(impl.device, set_live, "resolve query set is not a live set", loc)
    valid &= gpu_validate(impl.device, dest_live, "resolve destination is not a live buffer", loc)
    if !valid {
        return
    }

    set_impl := vk_query_set_get_impl(query_set, loc)
    dest_impl := vk_buffer_get_impl(destination, loc)
    valid = true
    valid &= gpu_validate(
        impl.device,
        query_set.device == impl.device,
        "resolve query set belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination.device == impl.device,
        "resolve destination belongs to another device",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        !dest_impl.destroyed,
        "resolve destination has been destroyed",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        first_query <= set_impl.count && query_count <= set_impl.count - first_query,
        "resolve query range is out of bounds",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        .Query_Resolve in dest_impl.public_usage,
        "resolve destination requires the [Query_Resolve] usage",
        loc,
    )
    valid &= gpu_validate(
        impl.device,
        destination_offset % 256 == 0,
        "resolve destination offset must be a multiple of 256",
        loc,
    )

    required := u64(query_count) * 8
    valid &= gpu_validate(
        impl.device,
        destination_offset <= dest_impl.visible_size &&
        required <= dest_impl.visible_size - destination_offset,
        "resolve destination range is out of bounds",
        loc,
    )
    if !valid {
        return
    }

    // A resolve writes the destination, exactly as a copy into it would.
    vk_command_encoder_track_buffer(
        command_encoder,
        destination,
        {.Query_Resolve},
        "buffer usage conflict in resolve_query_set",
        loc,
    )

    // Emit the transition this resolve needs. Without it the barrier that moves
    // the destination out of its previous state is left pending, and the
    // `vkCmdCopyQueryPoolResults` write races whatever wrote it before (and any
    // copy that follows races the resolve).
    vk_command_buffer_fold_usage_scope(impl.cmdbuf, &impl.cmdbuf.global_scope, loc)
    vk_flush_pending_transitions(device_impl, impl.cmdbuf, loc)

    vk_record_resolve_query_set(device_impl, impl.cmdbuf, Resolve_Query_Set_Cmd {
            query_set          = query_set,
            start_query        = first_query,
            query_count        = query_count,
            destination        = destination,
            destination_offset = destination_offset,
        }, loc)
    buffer_init_tracker_mark_initialized(
        &dest_impl.init,
        destination_offset,
        destination_offset + u64(query_count) * 8,
    )
}

vk_command_encoder_get_label :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Command_Encoder, pack_handle(impl.handle))
}

vk_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    // An encoder records into a command buffer it does not own, so there is no
    // Vulkan object of its own to name.
    vk_label_set(&device_impl.labels, .Command_Encoder, pack_handle(impl.handle), label)
}

vk_command_encoder_write_timestamp :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    device_impl := vk_device_get_impl(impl.device, loc)
    vk_record_write_timestamp(device_impl, impl.cmdbuf, query_set, query_index, loc = loc)
}

vk_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    add_ref(impl)
}

vk_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)

    if release_ref(impl) {
        ensure(!impl.is_computing, "Releasing encoder while in compute state", loc)
        ensure(!impl.is_rendering, "Releasing encoder while in render state", loc)

        // Dropping an unfinished encoder abandons its unsubmitted command
        // buffer. Its final command-buffer release cancels and recycles the slot.
        impl.is_encoding = false

        device_impl := vk_device_get_impl(impl.device, loc)
        if dhm_is_valid(
            &device_impl.command_buffers,
            unpack_handle(VK_Command_Buffer_Handle, impl.command_buffer.handle),
        ) {
            vk_command_buffer_release(impl.command_buffer, loc)
        }

        vk_label_remove(&device_impl.labels, .Command_Encoder, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.command_encoders, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// @private procedures
// -----------------------------------------------------------------------------

vk_command_encoder_arena_allocator :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> runtime.Allocator {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    return virtual.arena_allocator(&impl.cmdbuf.temp_arena)
}

vk_command_encoder_transition_buffers :: proc(
    command_encoder: Command_Encoder,
    barriers: []Buffer_State_Transition,
    loc := #caller_location,
) {
    impl := vk_command_encoder_get_impl(command_encoder, loc)
    device_impl := vk_device_get_impl(impl.device, loc)

    if !impl.is_encoding {
        gpu_report_validation_error(impl.device, "command encoder has finished", loc)
        return
    }

    vk_encode_barriers(device_impl, impl.cmdbuf, nil, barriers, loc)
}
