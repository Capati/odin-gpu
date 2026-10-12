#+private
package gpu

// Core
import "core:slice"
import "core:sync"

import intr "base:intrinsics"

Color_Attachments :: [dynamic; MAX_COLOR_ATTACHMENTS]Render_Pass_Color_Attachment
Color_Formats     :: [dynamic; MAX_COLOR_ATTACHMENTS]Texture_Format

Render_Pass_Descriptor_Impl :: struct {
    label:                    string,
    color_attachments:        Color_Attachments,
    color_formats:            Color_Formats,
    depth_stencil_attachment: Maybe(Render_Pass_Depth_Stencil_Attachment),
    multiview_mask:           Maybe(u32),
    timestamp_writes:         Maybe(Render_Pass_Timestamp_Writes),
    ds_uses:                  Texture_Uses,
    occlusion_query_set:      Query_Set,
    depth_stencil:            Render_Bundle_Depth_Stencil,
    has_depth_stencil:        bool,
    sample_count:             u32,
    width:                    u32,
    height:                   u32,
}

resolve_render_pass_descriptor :: proc(
    device: Device,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass_Descriptor_Impl {
    device_impl := device_get_public_impl(device, loc)

    max_color_attachments := min(MAX_COLOR_ATTACHMENTS, device_impl.limits.max_color_attachments)
    assert(u32(len(descriptor.color_attachments)) <= max_color_attachments,
        "color attachment count exceeds device limit", loc)

    fb_width, fb_height: u32
    rpass_data: Render_Pass_Descriptor_Impl
    rpass_data.label = descriptor.label

    // Copy color attachments
    for &color in descriptor.color_attachments {
        assert(color.view != {}, "Invalid color attachment view", loc)

        append(&rpass_data.color_attachments, color)

        view_impl := texture_view_get_public_impl(color.view, loc)
        size := texture_get_size(view_impl.texture, loc)

        // The framebuffer dimensions must match the attachment view's
        // subresource. A view selecting mip level N covers extent >> N, but
        // `texture_get_size` returns the whole texture's base extent.
        if base_mip := view_impl.selector.mips.start; base_mip > 0 {
            size.width  >>= base_mip
            size.height >>= base_mip
        }

        texture_impl := texture_get_public_impl(view_impl.texture, loc)
        append(&rpass_data.color_formats, texture_impl.format)
        rpass_data.sample_count = texture_impl.sample_count

        if fb_width > 0 {
            assert(size.width == fb_width,
                "All attachments should have the same width", loc)
        }
        if fb_height > 0 {
            assert(size.height == fb_height,
                "All attachments should have the same height", loc)
        }

        fb_width  = size.width
        fb_height = size.height
    }

    // set depth stencil
    if descriptor.depth_stencil_attachment != nil {
        ds := descriptor.depth_stencil_attachment^
        rpass_data.depth_stencil_attachment = ds

        ds_view_impl := texture_view_get_public_impl(ds.view, loc)
        ds_texture_impl := texture_get_public_impl(ds_view_impl.texture, loc)

        dim := ds_texture_impl.size
        if base_mip := ds_view_impl.selector.mips.start; base_mip > 0 {
            dim.width  >>= base_mip
            dim.height >>= base_mip
        }
        if fb_width > 0 {
            assert(dim.width == fb_width,
                "All attachments should have the same width", loc)
        }
        if fb_height > 0 {
            assert(dim.height == fb_height,
                "All attachments should have the same height", loc)
        }
        fb_width = dim.width
        fb_height = dim.height

        has_depth := texture_format_has_depth_aspect(ds_texture_impl.format)
        has_stencil := texture_format_has_stencil_aspect(ds_texture_impl.format)

        rpass_data.has_depth_stencil = true
        rpass_data.depth_stencil = Render_Bundle_Depth_Stencil {
            depth_stencil_format = ds_texture_impl.format,
            depth_read_only      = ds.depth_read_only,
            stencil_read_only    = ds.stencil_read_only,
        }
        if rpass_data.sample_count == 0 {
            rpass_data.sample_count = ds_texture_impl.sample_count
        }

        ds_uses: Texture_Uses
        if has_depth {
            if ds.depth_read_only {
                ds_uses |= {.Depth_Read}
            } else {
                ds_uses |= {.Depth_Write}
            }
        }
        if has_stencil {
            if ds.stencil_read_only {
                ds_uses |= {.Stencil_Read}
            } else {
                ds_uses |= {.Stencil_Write}
            }
        }

        rpass_data.ds_uses = ds_uses

        if has_depth && !ds.depth_read_only {
            assert(ds.depth_ops.load != .Undefined,
                "depth_load_op must be provided when format has a depth aspect " +
                "and depth_read_only is false", loc)
            assert(ds.depth_ops.store != .Undefined,
                "depth_store_op must be provided when format has a depth aspect " +
                "and depth_read_only is false", loc)
        }

        if has_stencil && !ds.stencil_read_only {
            assert(ds.stencil_ops.load != .Undefined,
                "stencil_load_op must be provided when format has a stencil aspect " +
                "and stencil_read_only is false", loc)
            assert(ds.stencil_ops.store != .Undefined,
                "stencil_store_op must be provided when format has a stencil aspect " +
                "and stencil_read_only is false", loc)
        }
    }

    assert(fb_width != 0, "Invalid framebuffer width", loc)
    assert(fb_height != 0, "Invalid framebuffer height", loc)

    rpass_data.width = fb_width
    rpass_data.height = fb_height

    rpass_data.occlusion_query_set = descriptor.occlusion_query_set

    if descriptor.timestamp_writes != nil {
        rpass_data.timestamp_writes = descriptor.timestamp_writes^
    }

    return rpass_data
}

Buffer_Descriptor_Impl :: struct {
    label:              string,
    size:               u64,
    tail_start:         u64,
    usage:              Buffer_Uses,
    memory_flags:       Memory_Flags,
    mapped_at_creation: bool,
}

pre_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer_Descriptor_Impl {
    assert(device != {}, "invalid device", loc)
    assert(descriptor.usage != {}, "buffer usage cannot be empty", loc)

    device_impl := device_get_public_impl(device, loc)

    assert(descriptor.size <= device_impl.limits.max_buffer_size,
        "buffer size exceeds the device limit", loc)

    if buffer_usage_intersects(descriptor.usage, {.Blas_Input, .Tlas_Input}) {
        assert(has_features(device_impl.features, {.Ray_Query}),
            "ray tracing buffer usage requires the [Ray_Query] feature", loc)
    }

    if .Index in descriptor.usage && buffer_usage_intersects(
            descriptor.usage, {.Vertex, .Uniform, .Indirect, .Storage}) {
        assert(.Unrestricted_Index_Buffer in device_impl.dl_features,
            "index buffers with other usages require [Unrestricted_Index_Buffer]", loc)
    }

    if !has_features(device_impl.features, {.Mappable_Primary_Buffers}) {
        write_mismatch := .Map_Write in descriptor.usage &&
            descriptor.usage &~ {.Map_Write, .Copy_Src} != {}
        ensure(!write_mismatch, "[Map_Write] used with something other than [Copy_Src]", loc)
        read_mismatch := .Map_Read in descriptor.usage &&
            descriptor.usage &~ {.Map_Read, .Copy_Dst} != {}
        ensure(!read_mismatch, "[Map_Read] used with something other than [Copy_Dst]", loc)
    }

    usage := map_buffer_usage(descriptor.usage)

    if .Indirect in descriptor.usage {
        usage |= {.Storage_Read_Only, .Storage_Read_Write}
    }

    if .Query_Resolve in descriptor.usage {
        usage |= BUFFER_USES_TIMESTAMP_NORMALIZATION
    }

    if descriptor.mapped_at_creation {
        ensure(is_multiple_of(descriptor.size, COPY_BUFFER_ALIGNMENT), "Unaligned size", loc)
        assert(.Map_Read not_in descriptor.usage || .Map_Write in descriptor.usage,
            "mapped_at_creation with Map_Read (and no Map_Write) is not meaningful, there is " +
            "nothing to read from a freshly created buffer", loc)
        if .Map_Write not_in descriptor.usage {
            // we are going to be copying into it, internally
            usage |= {.Copy_Dst}
        }
    } else {
        // We are required to zero out (initialize) all memory. This is done
        // on demand using buffer_clear which requires write transfer usage
        usage |= {.Copy_Dst}
    }

    // Buffer sizes are subject to a few constraints:
    //
    // - Applications may request any byte-aligned size.
    // - Vertex buffers get an extra byte to allow simulating an empty range at
    //   the end, which Vulkan does not natively support.
    // - The final size must be a non-zero multiple of 4.
    //
    // Since initialization operates in 4-byte units, we eagerly zero-initialize
    // any bytes beyond the application-visible range.
    actual_size: u64
    if descriptor.size == 0 {
        actual_size = COPY_BUFFER_ALIGNMENT
    } else if .Vertex in descriptor.usage {
        actual_size = descriptor.size + 1
    } else {
        actual_size = descriptor.size
    }

    // round UP, from actual_size
    actual_size = align_size(actual_size, COPY_BUFFER_ALIGNMENT)
    // round DOWN, from ORIGINAL descriptor.size
    tail_start := descriptor.size &~ (COPY_BUFFER_ALIGNMENT - 1)
    assert(actual_size - 4 <= tail_start)

    return {
        label              = descriptor.label,
        size               = actual_size,
        usage              = usage,
        tail_start         = tail_start,
        mapped_at_creation = descriptor.mapped_at_creation,
        memory_flags       = {},
    }
}

post_device_create_buffer :: proc(
    device: Device,
    buffer: Buffer,
    descriptor: Buffer_Descriptor_Impl,
    loc := #caller_location,
) {
    device_impl := device_get_public_impl(device, loc)
    buffer_impl := buffer_get_public_impl(buffer, loc)

    buffer_impl.tracker_index = shared_tracker_index_allocator_alloc(
    &device_impl.tracker_indices.buffers)

    init_buffer_tail :: proc(
        buffer: Buffer,
        buffer_impl: ^Buffer_Impl,
        tail_start, actual_size: u64,
    ) {
        ptr := buffer_map_sync(buffer, .Write, uint(tail_start), uint(actual_size - tail_start))
        assert(ptr != nil)
        // The buffer tail is valid and aligned.
        (^u32)(ptr)^ = 0
        if !buffer_impl.is_coherent {
            buffer_flush_mapped_ranges(buffer, uint(tail_start), uint(actual_size))
        }
        buffer_unmap(buffer)
    }

    tail_start := descriptor.tail_start
    actual_size := descriptor.size

    buffer_use: Buffer_Uses
    if !descriptor.mapped_at_creation {
        if tail_start == descriptor.size {
            // No tail init necessary
        } else if .Map_Write in descriptor.usage {
            // Tail init by mapping
            init_buffer_tail(buffer, buffer_impl, tail_start, actual_size)
        } else {
            queue := device_get_queue(device, loc)
            defer queue_release(queue)

            queue_impl := queue_get_public_impl(queue, loc)

            // The buffer has padding past its application-visible size, and
            // can't be zeroed through a map. Schedule the fill into the next
            // queue submission, so the padding is defined before any aligned
            // copy can read it.
            device_buffer_tracker_insert_single(
                &device_impl.trackers.buffers, buffer_impl.tracker_index, buffer, {.Copy_Dst})
            deferred_writes_clear_buffer(
                &queue_impl.deferred_writes,
                buffer, tail_start, actual_size - tail_start, loc)

            return
        }
    } else if .Map_Write in descriptor.usage {
        // Mapped-at-creation with Map_Write. Tail init by mapping, then map the
        // application-visible portion separately, don't expose the tail to the app.
        if tail_start != actual_size {
            init_buffer_tail(buffer, buffer_impl, tail_start, actual_size)
        }
        map_size := buffer_impl.size
        mapping: Buffer_Mapping
        if map_size == 0 {
            mapping = {ptr = nil, is_coherent = true} // dangling
        } else {
            mapping.ptr = buffer_map_sync(buffer, .Write, 0, uint(map_size))
        }
        buffer_impl.map_state = Buffer_Map_State_Active {
            ptr         = mapping.ptr,
            is_coherent = mapping.is_coherent,
            range       = {0, map_size},
            mode        = .Write,
        }
        buffer_use = {.Map_Write}
    } else {
        // Mapped-at-creation without Map_Write. Zero-initialize a staging buffer
        // covering the entire buffer (including tail); a single mapping is fine
        // since get_mapped_range only exposes the application-visible range.
        staging_buffer: Staging_Buffer
        staging_buffer_init(&staging_buffer, device, actual_size)
        staging_buffer_write_zeros(&staging_buffer)
        // buffer_initialization_status_drain(buffer, 0, actual_size)

        buffer_impl.map_state = Buffer_Map_State_Init {
            staging_buffer = staging_buffer,
        }
        buffer_use = {.Copy_Dst}
    }

    device_buffer_tracker_insert_single(
        &device_impl.trackers.buffers,
        buffer_impl.tracker_index,
        buffer,
        buffer_use,
    )
}

resolve_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    impl := queue_get_public_impl(queue, loc)
    device_impl := device_get_public_impl(impl.device, loc)
    buffer_impl := buffer_get_public_impl(buffer, loc)

    data_bytes := slice.bytes_from_ptr(data, int(size))
    data_size := u64(size)

    assert(offset % 4 == 0 && data_size % 4 == 0,
        "write_buffer offset/size must be 4-byte aligned", loc)

    // TODO: skip staging buffer if host visible is available

    staging_buffer: Staging_Buffer
    staging_buffer_init(&staging_buffer, impl.device, data_size, loc)
    staging_buffer_write(&staging_buffer, data_bytes)
    flushed_staging_buffer := staging_buffer_flush(&staging_buffer)

    barriers: [dynamic; 2]Buffer_Barrier
    append(&barriers, Buffer_Barrier{
        buffer = flushed_staging_buffer.buffer,
        usage = {
            from = {.Map_Write},
            to   = {.Copy_Src},
        },
    })

    if transition, transition_ok := device_buffer_tracker_set_single(
        &device_impl.trackers.buffers,
        buffer_impl.tracker_index,
        buffer, {.Copy_Dst},
    ); transition_ok {
        append(&barriers, Buffer_Barrier{
            buffer = buffer,
            usage = transition.usage,
        })
    }

    deferred_writes := &impl.deferred_writes

    // Held across the whole record: there is a single scratch encoder, so this is
    // what keeps a concurrent queue write from recording into it at the same time.
    // The tracker lock taken above is a leaf and has already been released.
    sync.guard(&deferred_writes.mtx)

    encoder := deferred_writes_activate_locked(deferred_writes, loc)

    command_encoder_transition_buffers(encoder, barriers[:])
    command_encoder_copy_buffer_to_buffer(
        command_encoder    = encoder,
        source             = flushed_staging_buffer.buffer,
        source_offset      = 0,
        destination        = buffer,
        destination_offset = offset,
        size               = flushed_staging_buffer.size,
    )

    deferred_writes_insert_buffer_locked(deferred_writes, buffer)
    deferred_writes_consume_locked(deferred_writes, flushed_staging_buffer)
}

// A buffer slot in a resolved bind group: the segment to bind, and whether the
// binding declared it as storage.
Bind_Group_Impl_Buffer :: struct {
    binding:   Buffer_Binding,
    is_storage: bool,
}

// A texture view slot in a resolved bind group, and whether the binding declared
// it as storage.
Bind_Group_Impl_Texture_View :: struct {
    view:       Texture_View,
    is_storage: bool,
}

// One binding of a resolved bind group. `resource_index` is the offset of this
// binding's first resource in the flattened list named by `type`; there is one
// resource per descriptor, so a binding covers
// `[resource_index, resource_index + binding_array_size)`.
Bind_Group_Impl_Entry :: struct {
    binding:            u32,
    type:               Binding_Type,
    binding_array_size: u32,
    resource_index:     int,
}

// A fully resolved bind group.
//
// The public layer in `device_create_bind_group` turns a `Bind_Group_Descriptor`
// into one of these: every binding is validated against its layout entry, the
// internal tracker usage of each resource is derived, and the flattened resource
// lists are built. Backends consume only this, never the original descriptor,
// and never re-derive usage or re-validate counts.
//
// Ownership of `used` passes to the backend; the flattened lists are read-only to
// it and are freed by the caller.
Bind_Group_Descriptor_Impl :: struct {
    label:         string,
    layout:        Bind_Group_Layout,
    entries:       []Bind_Group_Impl_Entry,
    buffers:       []Bind_Group_Impl_Buffer,
    samplers:      []Sampler,
    texture_views: []Bind_Group_Impl_Texture_View,
    // Tracker state, merged into the pass scope when the bind group is bound.
    used:          Bind_Group_States,
}

// Creates a new `Bind_Group`.
resolve_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Descriptor_Impl {
    assert(device != {}, "Invalid device", loc)
    assert(descriptor.layout != {}, "Invalid bind group layout", loc)

    device_impl := device_get_public_impl(device, loc)
    layout_impl := bind_group_layout_get_public_impl(descriptor.layout, loc)

    assert(len(descriptor.entries) == len(layout_impl.entries),
        "Bindings number mismatch", loc)

    ta := default_temp_allocator()

    // Capacity hint only: every binding contributes at most one of each kind.
    entry_capacity := len(descriptor.entries)

    // Ownership of `desc_impl.used` passes to the bind group. The flattened
    // resource lists are only read by the backend, so they are freed here.
    entries       := make([dynamic]Bind_Group_Impl_Entry, 0, entry_capacity, ta)
    buffers       := make([dynamic]Bind_Group_Impl_Buffer, 0, entry_capacity, ta)
    samplers      := make([dynamic]Sampler, 0, entry_capacity, ta)
    texture_views := make([dynamic]Bind_Group_Impl_Texture_View, 0, entry_capacity, ta)

    desc_impl := Bind_Group_Descriptor_Impl {
        label  = descriptor.label,
        layout = descriptor.layout,
    }

    bind_group_state_init(&desc_impl.used, device_impl.allocator, loc)

    for entry in descriptor.entries {
        layout_entry, declared := layout_impl.entries[entry.binding]
        assert(declared, "Bind group entry has no matching layout entry", loc)

        resolved := Bind_Group_Impl_Entry {
            binding            = entry.binding,
            type               = layout_entry.type,
            binding_array_size = max(1, layout_entry.count),
        }
        expected_count := int(resolved.binding_array_size)

        switch r in entry.resource {
        case Buffer_Binding:
            assert(r.buffer != {}, "invalid buffer", loc)
            assert(expected_count == 1, "buffer binding expects a single resource", loc)
            uses, is_storage := bind_group_buffer_internal_use(layout_entry, loc)
            resolved.resource_index = len(buffers)
            append(&buffers, Bind_Group_Impl_Buffer{binding = r, is_storage = is_storage})
            buffer_bind_group_state_insert_single(
                &desc_impl.used.buffers, buffer_tracker_index(r.buffer), r.buffer, uses, loc)

        case []Buffer_Binding:
            assert(expected_count == len(r),
                "buffer binding array size does not match layout", loc)
            uses, is_storage := bind_group_buffer_internal_use(layout_entry, loc)
            resolved.resource_index = len(buffers)
            for bb in r {
                assert(bb.buffer != {}, "invalid buffer", loc)
                append(&buffers, Bind_Group_Impl_Buffer{binding = bb, is_storage = is_storage})
                buffer_bind_group_state_insert_single(
                    &desc_impl.used.buffers, buffer_tracker_index(bb.buffer), bb.buffer, uses, loc)
            }

        case Sampler:
            assert(r != {}, "invalid sampler", loc)
            assert(expected_count == 1, "sampler binding expects a single resource", loc)
            resolved.resource_index = len(samplers)
            append(&samplers, r)

        case []Sampler:
            assert(expected_count == len(r),
                "sampler binding array size does not match layout", loc)
            resolved.resource_index = len(samplers)
            for smp in r {
                assert(smp != {}, "invalid sampler", loc)
                append(&samplers, smp)
            }

        case Texture_View:
            assert(r != {}, "invalid texture view", loc)
            assert(expected_count == 1, "texture view binding expects a single resource", loc)
            uses, is_storage := bind_group_view_internal_use(layout_entry, loc)
            resolved.resource_index = len(texture_views)
            append(&texture_views,
                Bind_Group_Impl_Texture_View{view = r, is_storage = is_storage})
            texture_view_bind_group_state_insert_single(
                &desc_impl.used.views,
                texture_tracker_index(texture_view_get_public_impl(r, loc).texture),
                r, uses, loc)

        case []Texture_View:
            assert(expected_count == len(r),
                "texture view binding array size does not match layout", loc)
            uses, is_storage := bind_group_view_internal_use(layout_entry, loc)
            resolved.resource_index = len(texture_views)
            for tv in r {
                assert(tv != {}, "invalid texture view", loc)
                append(&texture_views,
                    Bind_Group_Impl_Texture_View{view = tv, is_storage = is_storage})
                texture_view_bind_group_state_insert_single(
                    &desc_impl.used.views,
                    texture_tracker_index(texture_view_get_public_impl(tv, loc).texture),
                    tv, uses, loc)
            }

        case:
            panic("Unsupported bind group entry resource", loc)
        }

        append(&entries, resolved)
    }

    desc_impl.entries = entries[:]
    desc_impl.buffers = buffers[:]
    desc_impl.samplers = samplers[:]
    desc_impl.texture_views = texture_views[:]

    bind_group_states_optimize(&desc_impl.used, loc)

    return desc_impl
}

Texture_Descriptor_Impl :: struct {
    using desc:     Texture_Descriptor,
    internal_usage: Texture_Uses,
    memory_flags:   Memory_Flags,
}

resolve_texture_descriptor :: proc(
    device: Device,
    desc: Texture_Descriptor,
    loc := #caller_location,
) -> Texture_Descriptor_Impl {
    // limits := device_get_limits(device, loc)

    // Basic validation
    assert(desc.format != .Undefined, "Invalid texture format", loc)
    assert(desc.usage != {}, "Texture usage flags are not set", loc)
    assert(desc.dimension != .Undefined, "Invalid texture dimension", loc)
    assert(desc.size.width > 0, "Texture width must be greater than 0", loc)
    assert(desc.size.height > 0, "Texture height must be greater than 0", loc)
    assert(desc.size.depth_or_array_layers > 0,
        "Texture depth/layers must be greater than 0", loc)
    assert(desc.mip_level_count != 0,
        "The mip_level_count specified must be greater than 0", loc)
    assert(desc.sample_count > 0, "Sample count must be at least 1", loc)

    // Validate mip levels don't exceed maximum possible
    max_mip_levels := max_mip_levels(desc.size.width, desc.size.height)
    assert(desc.mip_level_count <= max_mip_levels,
       "Mip level count exceeds maximum possible for this texture size", loc)

    // Format-specific feature validation
    format_features, format_features_ok :=
        device_describe_format_features(device, desc.format, loc)
    assert(format_features_ok, "Missing format features", loc)
    assert((desc.usage & format_features.allowed_usages) == desc.usage,
       "Requested usage flags are not supported for this format on this device", loc)

    // Check the requested texture size against the supported limits.
    // check_texture_dimension_size(
    //     desc.dimension, desc.size, desc.sample_count, dev_impl.limits, loc)

    if desc.dimension != .D2 {
        assert(!texture_format_is_depth_stencil_format(desc.format),
            "Depth textures can only be 2D", loc)
    }

    if desc.dimension != .D2 && desc.dimension != .D3 {
        assert(!texture_format_is_compressed(desc.format),
            "Compressed textures can only be 2D or 3D", loc)
        assert(.Render_Attachment not_in desc.usage,
            "Renderable textures can only be 2D or 3D", loc)
    }

    // Validate multisampling constraints
    if desc.sample_count > 1 {
        assert(desc.mip_level_count == 1,
            "Multisampled textures must have exactly 1 mip level", loc)
        assert(desc.dimension != .D3, "3D textures cannot be multisampled", loc)
    }

    if texture_format_is_compressed(desc.format) {
        block_width, block_height := texture_format_block_dimensions(desc.format)

        assert(is_multiple_of(desc.size.width, block_width),
            "Texture width is not multiple of block width", loc)
        assert(is_multiple_of(desc.size.height, block_height),
            "Texture height is not multiple of block height", loc)

        if desc.dimension == .D3 {
            if texture_format_is_bcn(desc.format) {
                assert(device_has_feature(device, .Texture_Compression_BC_Sliced_3D),
                    "Only BCn formats with Sliced 3D feature can be used for 3D textures", loc)
            } else if texture_format_is_astc(desc.format, loc) {
                assert(device_has_feature(device, .Texture_Compression_ASTC_Sliced_3D),
                    "Only Astc formats with Sliced 3D feature can be used for 3D textures", loc)
            } else {
                panic("Invalid compressed dimension", loc)
            }
        }
    }

    // mips := desc.mip_level_count
    // max_levels_allowed := max_mip_levels()

    internal_usage := map_texture_usage_for_texture(desc, format_features)

    internal_desc := Texture_Descriptor_Impl {
        label           = desc.label,
        size            = desc.size,
        mip_level_count = desc.mip_level_count,
        sample_count    = desc.sample_count,
        dimension       = desc.dimension,
        format          = desc.format,
        usage           = desc.usage,
        internal_usage  = internal_usage,
        memory_flags    = {},
        view_formats    = desc.view_formats,
    }

    return internal_desc
}

Texture_View_Descriptor_Impl :: struct {
    label:     string,
    format:    Texture_Format,
    dimension: Texture_View_Dimension,
    usage:     Texture_Uses,
    range:     Image_Subresource_Range,
}

// Resolve defaults
//
// https://gpuweb.github.io/gpuweb/#abstract-opdef-resolving-gputextureviewdescriptor-defaults
resolve_texture_view_descriptor :: proc(
    texture: Texture,
    device: Device,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View_Descriptor_Impl {
    // Get the texture descriptor to inherit information
    texture_desc := texture_get_descriptor(texture, loc)

    // Resolve texture aspect
    aspect := descriptor.aspect

    // Resolve texture format
    resolved_format := descriptor.format
    if resolved_format == .Undefined {
        resolved_format = texture_format_aspect_specific_format(texture_desc.format, aspect, loc)
    }

    // Resolve texture view dimension
    resolved_dimension := descriptor.dimension
    // if resolved_dimension == .Undefined {
    //     assert(texture_desc.dimension != .Undefined, "Invalid texture dimension", loc)
    //     #partial switch texture_desc.dimension {
    //     case .D1: resolved_dimension = .D1
    //     case .D2:
    //         resolved_dimension = .D2 if
    //             texture_descriptor_array_layer_count(texture_desc) == 1 else .D2_Array
    //     case .D3: resolved_dimension = .D3
    //     case:
    //         unreachable()
    //     }
    // }

    // Resolve mip level count
    resolved_mip_level_count :=
        descriptor.mip_level_count if descriptor.mip_level_count != 0 else
        intr.saturating_sub(texture_desc.mip_level_count, descriptor.base_mip_level)

    // Resolve array layer count
    resolved_array_layer_count := descriptor.array_layer_count
    if resolved_array_layer_count == 0 {
        #partial switch resolved_dimension {
        case .D1, .D2, .D3: resolved_array_layer_count = 1
        case .Cube: resolved_array_layer_count = 6
        case .D2_Array, .Cube_Array:
            resolved_array_layer_count =
                intr.saturating_sub(texture_descriptor_array_layer_count(
                    texture_desc), descriptor.base_array_layer)
        case:
            unreachable()
        }
    }

    // resolve usage
    resolved_usage: Texture_Usages
    if descriptor.usage == {} {
        resolved_usage = texture_desc.usage
    } else if texture_desc.usage & descriptor.usage == descriptor.usage {
        resolved_usage = descriptor.usage
    } else {
        panic("Invalid texture usages", loc)
    }

    format_features := device_texture_format_features(device, resolved_format, loc)
    aspects := texture_format_aspects_from(resolved_format)
    resolved_uses := map_texture_usage(resolved_usage, aspects, format_features.flags, loc)
    mask_copy := Texture_Uses(~(Texture_Uses{.Copy_Src, .Copy_Dst}))
    mask_dimension: Texture_Uses
    #partial switch resolved_dimension {
    case .Cube, .Cube_Array: mask_dimension = {.Resource}
    case .D3: mask_dimension = {
        .Resource,
        .Storage_Read_Only,
        .Storage_Write_Only,
        .Storage_Read_Write}
    case: mask_dimension = ~Texture_Uses{}
    }
    mask_mip := ~Texture_Uses{} if resolved_mip_level_count == 1 else Texture_Uses{.Resource}
    usage := resolved_uses & mask_copy & mask_dimension & mask_mip

    // Use the combined depth-stencil format for the view
    format := resolved_format
    if texture_format_is_depth_stencil_component(format, texture_desc.format, loc) {
        format = texture_desc.format
    }

    // Resolve image sub resource range
    resolved_range := Image_Subresource_Range{
        aspect            = aspect,
        base_mip_level    = descriptor.base_mip_level,
        mip_level_count   = resolved_mip_level_count,
        base_array_layer  = descriptor.base_array_layer,
        array_layer_count = resolved_array_layer_count,
    }

    // Create the final descriptor
    desc_impl := Texture_View_Descriptor_Impl {
        label     = descriptor.label,
        format    = format,
        dimension = resolved_dimension,
        usage     = usage,
        range     = resolved_range,
    }

    return desc_impl
}
