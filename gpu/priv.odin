// #+build !js
#+private
package gpu

// Core
import intr "base:intrinsics"

ver_pack :: #force_inline proc "contextless" (major, minor: u32) -> u32 {
    return major * 100 + minor
}

Ref_Count_Type :: distinct u32

init_ref :: #force_inline proc "contextless" (
    obj: ^$T,
    loc := #caller_location,
) where intr.type_has_field(T, "ref") {
    assert_contextless(obj.ref == 0, "[init_ref]: already initialized", loc)
    intr.atomic_add(&obj.ref, 1)
}

add_ref :: #force_inline proc "contextless" (
    obj: ^$T,
    loc := #caller_location,
) where intr.type_has_field(T, "ref") {
    assert_contextless(obj.ref > 0, "[add_ref]: underflow", loc)
    intr.atomic_add(&obj.ref, 1)
}

@(require_results)
release_ref :: #force_inline proc "contextless" (
    obj: ^$T,
    loc := #caller_location,
) -> bool where intr.type_has_field(T, "ref") {
    assert_contextless(obj.ref > 0, "[release_ref]: underflow", loc)
    return intr.atomic_sub(&obj.ref, 1) == 1 // Was this the last reference?
}

map_buffer_usage :: #force_inline proc "contextless" (
    usage: Buffer_Usages,
) -> (
    u: Buffer_Uses,
) {
    if .Map_Read in usage {
        u |= {.Map_Read}
    }
    if .Map_Write in usage {
        u |= {.Map_Write}
    }
    if .Copy_Src in usage {
        u |= {.Copy_Src}
    }
    if .Copy_Dst in usage {
        u |= {.Copy_Dst}
    }
    if .Index in usage {
        u |= {.Index}
    }
    if .Vertex in usage {
        u |= {.Vertex}
    }
    if .Uniform in usage {
        u |= {.Uniform}
    }
    if .Storage in usage {
        u |= {.Storage_Read_Only, .Storage_Read_Write}
    }
    if .Indirect in usage {
        u |= {.Indirect}
    }
    if .Query_Resolve in usage {
        u |= {.Query_Resolve}
    }
    return u
}

unmap_buffer_usage :: proc(usage: Buffer_Uses) -> (u: Buffer_Usages) {
    if .Map_Read in usage {
        u += {.Map_Read}
    }
    if .Map_Write in usage {
        u += {.Map_Write}
    }
    if .Copy_Src in usage {
        u += {.Copy_Src}
    }
    if .Copy_Dst in usage {
        u += {.Copy_Dst}
    }
    if .Index in usage {
        u += {.Index}
    }
    if .Vertex in usage {
        u += {.Vertex}
    }
    if .Uniform in usage {
        u += {.Uniform}
    }
    if usage & {.Storage_Read_Only, .Storage_Read_Write} != {} {
        u += {.Storage}
    }
    if .Indirect in usage {
        u += {.Indirect}
    }
    if .Query_Resolve in usage {
        u += {.Query_Resolve}
    }
    return
}

Memory_Flags :: bit_set[Memory_Flag;u32]
Memory_Flag :: enum {
    Transient,
    Prefer_Coherent,
}

Buffer_Map_Operation :: struct {
    mode:     Map_Mode,
    callback: Maybe(Buffer_Map_Callback),
}

Buffer_Pending_Mapping :: struct {
    range:         Range(u64),
    op:            Buffer_Map_Operation,
    // hold the parent alive while the mapping is active
    parent_buffer: Buffer,
}

// Mapped at creation.
Buffer_Map_State_Init :: struct {
    staging_buffer: Staging_Buffer,
}

// Waiting for GPU to be done before mapping.
Buffer_Map_State_Waiting :: Buffer_Pending_Mapping

Buffer_Mapping :: struct {
    ptr:         rawptr,
    is_coherent: bool,
}

Memory_Range :: Range(u64)

// Mapped
Buffer_Map_State_Active :: struct {
    using mapping: Buffer_Mapping,
    range:         Memory_Range,
    mode:          Map_Mode,
}

// Not mapped
Buffer_Map_State_Idle :: struct {}

Buffer_Map_State_Impl :: union #no_nil {
    Buffer_Map_State_Init,
    Buffer_Map_State_Waiting,
    Buffer_Map_State_Active,
    Buffer_Map_State_Idle,
}

// Texture format capability flags.
Texture_Format_Capabilities :: bit_set[Texture_Format_Capabilities_Flags; u32]
Texture_Format_Capabilities_Flags :: enum u32 {
    // Format can be sampled.
    Sampled,
    // Format can be sampled with a linear sampler.
    Sampled_Linear,
    // Format can be sampled with a min/max reduction sampler.
    Sampled_Minmax,

    // Format can be used as storage with read-only access.
    Storage_Read_Only,
    // Format can be used as storage with write-only access.
    Storage_Write_Only,
    // Format can be used as storage with both read and write access.
    Storage_Read_Write,
    // Format can be used as storage with atomics.
    Storage_Atomic,

    // Format can be used as color and input attachment.
    Color_Attachment,
    // Format can be used as color (with blending) and input attachment.
    Color_Attachment_Blend,
    // Format can be used as depth-stencil and input attachment.
    Depth_Stencil_Attachment,

    // Format can be multisampled by x2.
    Multisample_X2,
    // Format can be multisampled by x4.
    Multisample_X4,
    // Format can be multisampled by x8.
    Multisample_X8,
    // Format can be multisampled by x16.
    Multisample_X16,

    // Format can be used for render pass resolve targets.
    Multisample_Resolve,

    // Format can be copied from.
    Copy_Src,
    // Format can be copied to.
    Copy_Dst,
}

// Texture format capability flags.
Format_Aspects :: bit_set[Texture_Format_Aspect;u8]
Texture_Format_Aspect :: enum {
    Color,
    Depth,
    Stencil,
    Plane0,
    Plane1,
    Plane2,
}

map_texture_usage :: proc(
    usage: Texture_Usages,
    aspect: Format_Aspects,
    flags: Texture_Format_Feature_Flags,
    loc := #caller_location,
) -> (u: Texture_Uses) {
    if .Copy_Src in usage { u |= {.Copy_Src} }
    if .Copy_Dst in usage { u |= {.Copy_Dst} }
    if .Texture_Binding in usage { u |= {.Resource} }
    if .Storage_Binding in usage {
        if .Storage_Read_Only in flags { u |= {.Storage_Read_Only} }
        if .Storage_Write_Only in flags { u |= {.Storage_Write_Only} }
        if .Storage_Read_Write in flags { u |= {.Storage_Read_Write} }
    }
    is_color := aspect & {.Color, .Plane0,  .Plane1,  .Plane2} != {}
    if .Render_Attachment in usage && is_color {
        { u |= {.Color_Target} }
    }
    if .Render_Attachment in usage && !is_color {
        { u |= {.Depth_Write, .Depth_Read, .Stencil_Write, .Stencil_Read} }
    }
    if .Storage_Atomic in usage { u |= {.Storage_Atomic} }
    if .Transient_Attachment in usage { u |= {.Transient} }
    return
}

texture_format_aspects_from :: proc(format: Texture_Format) -> Format_Aspects {
    #partial switch format {
    case .Stencil8:
        return {.Stencil}
    case .Depth16_Unorm, .Depth32_Float, .Depth24Plus:
        return {.Depth}
    case .Depth32Float_Stencil8, .Depth24Plus_Stencil8:
        return {.Depth, .Stencil}
    case .NV12, .P010:
        return {.Plane0, .Plane1}
    case:
        return {.Color}
    }
}

map_texture_usage_for_texture :: proc(
    desc: Texture_Descriptor,
    format_features: Texture_Format_Features,
    loc := #caller_location,
) -> (uses: Texture_Uses) {
    // Enforce having Copy_Dst/Depth_Stencil_Write/Color_Target otherwise we
    // wouldn't be able to initialize the texture.
    uses = map_texture_usage(
        desc.usage, texture_format_aspects_from(desc.format), format_features.flags, loc)

    if texture_format_is_depth_stencil_format(desc.format, loc) {
        uses |= {.Depth_Write, .Stencil_Write}
    } else if .Copy_Dst in desc.usage {
        uses |= {.Copy_Dst}
    } else if .Render_Attachment in format_features.allowed_usages && desc.dimension == .D2 {
        uses |= {.Color_Target}
    } else {
        uses |= {.Copy_Dst}
    }
    return
}

adapter_texture_format_capabilities: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities

adaper_texture_format_features :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Features {
    caps := adapter_texture_format_capabilities(adapter, format, loc)
    allowed_usages: Texture_Usages

    if .Copy_Src in caps { allowed_usages |= {.Copy_Src} }
    if .Copy_Dst in caps { allowed_usages |= {.Copy_Dst} }

    if .Sampled in caps { allowed_usages |= {.Texture_Binding} }
    if caps & {
        .Storage_Write_Only,
        .Storage_Read_Only,
        .Storage_Read_Write,
        .Storage_Atomic} != {} {
        allowed_usages |= {.Storage_Binding}
    }

    if caps & {.Color_Attachment, .Depth_Stencil_Attachment} != {} {
        allowed_usages |= {.Render_Attachment, .Transient_Attachment}
    }
    if .Storage_Atomic in caps { allowed_usages |= {.Storage_Atomic} }

    flags: Texture_Format_Feature_Flags

    if .Storage_Read_Only      in caps { flags |= {.Storage_Read_Only} }
    if .Storage_Write_Only     in caps { flags |= {.Storage_Write_Only} }
    if .Storage_Read_Write     in caps { flags |= {.Storage_Read_Write} }

    if .Storage_Atomic         in caps { flags |= {.Storage_Atomic} }

    if .Sampled_Linear         in caps { flags |= {.Filterable} }

    if .Color_Attachment_Blend in caps { flags |= {.Blendable} }

    if .Multisample_X2         in caps { flags |= {.Multisample_X2} }
    if .Multisample_X4         in caps { flags |= {.Multisample_X4} }
    if .Multisample_X8         in caps { flags |= {.Multisample_X8} }
    if .Multisample_X16        in caps { flags |= {.Multisample_X16} }

    if .Multisample_Resolve    in caps { flags |= {.Multisample_Resolve} }

    return {
        allowed_usages,
        flags,
    }
}

device_texture_format_features :: proc(
    device: Device,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Features {
    // device_features := device_get_features_view(device, loc)

    adapter := device_get_adapter(device, loc)
    format_features := adaper_texture_format_features(adapter, format, loc)
    if (format == .R32_Float || format == .RG32_Float || format == .RGBA32_Float) &&
            !device_has_feature(device, .Float32_Filterable) {
        format_features.flags -= {.Filterable}
    }
    return format_features
}

device_describe_format_features :: proc(
    device: Device,
    format: Texture_Format,
    loc := #caller_location,
) -> (
    features: Texture_Format_Features,
    ok: bool,
) {
    device_features := device_get_features_view(device, loc)

    required_features := texture_format_required_features(format, loc)
    ok = device_has_feature(device, required_features)

    if device_has_feature(device, .Texture_Adapter_Specific_Format_Features) {
        features = device_texture_format_features(device, format, loc)
    } else {
        features = texture_format_guaranteed_format_features(
            format, device_features, loc)
    }

    return
}

// Derives the internal tracker usage of a buffer bound through this layout entry,
// and whether the binding declared it as storage.
bind_group_buffer_internal_use :: proc(
    entry: Bind_Group_Layout_Entry,
    loc := #caller_location,
) -> (uses: Buffer_Uses, is_storage: bool) {
    layout: Buffer_Binding_Layout
    #partial switch t in entry.type {
    case Buffer_Binding_Layout:
        layout = t
    case:
        panic("Expected uniform buffer, storage buffer or readonly storage buffer", loc)
    }

    is_storage = layout.type == .Storage || layout.type == .Read_Only_Storage

    #partial switch layout.type {
    case .Uniform:           uses = {.Uniform}
    case .Storage:           uses = {.Storage_Read_Write}
    case .Read_Only_Storage: uses = {.Storage_Read_Only}
    case:
        panic("Expected uniform buffer, storage buffer or readonly storage buffer", loc)
    }

    return
}

// Derives the internal tracker usage of a texture view bound through this layout
// entry, and whether the binding declared it as storage.
bind_group_view_internal_use :: proc(
    entry: Bind_Group_Layout_Entry,
    loc := #caller_location,
) -> (uses: Texture_Uses, is_storage: bool) {
    switch t in entry.type {
    case Texture_Binding_Layout:
        uses = {.Resource}
        is_storage = false
    case Storage_Texture_Binding_Layout:
        is_storage = true
        #partial switch t.access {
        case .Write_Only: uses = {.Storage_Write_Only}
        case .Read_Only:  uses = {.Storage_Read_Only}
        case .Read_Write: uses = {.Storage_Read_Write}
        case:             uses = {.Storage_Read_Write}
        }
    case:
        panic("Expected texture or storage texture binding", loc)
    case Buffer_Binding_Layout, Sampler_Binding_Layout, External_Texture_Binding_Layout:
        panic("Expected texture or storage texture binding", loc)
    }

    return
}

Buffer_Copy :: struct {
    src_offset: u64,
    dst_offset: u64,
    size:       u64,
}

Texture_Copy_Base :: struct {
    mip_level:   u32,
    array_layer: u32,
    // Origin within a texture.
    // Note:    for 1D and 2D textures, Z must be 0.
    origin:      Origin_3D,
    aspect:      Format_Aspects,
}

Copy_Extent :: struct {
    width:  u32,
    height: u32,
    depth:  u32,
}

Texture_Copy :: struct {
    src_base: Texture_Copy_Base,
    dst_base: Texture_Copy_Base,
    size:     Copy_Extent,
}

Buffer_Texture_Copy :: struct {
    buffer_layout: Texel_Copy_Buffer_Layout,
    texture_base:  Texture_Copy_Base,
    size:          Copy_Extent,
}

map_extent_to_copy_size :: proc(
    extent: Extent_3D, dim: Texture_Dimension, loc := #caller_location,
) -> Copy_Extent {
    assert(dim != .Undefined, "Invalid texture dimension", loc)
    depth: u32
    #partial switch dim {
    case .D1, .D2: depth = 1
    case .D3: depth = extent.depth_or_array_layers
    case:
        unreachable()
    }
    return {
        width = extent.width,
        height = extent.height,
        depth = depth,
    }
}

texture_descriptor_copy_extent :: proc(self: Texture_Descriptor) -> Copy_Extent {
    return map_extent_to_copy_size(self.size, self.dimension)
}

// A D2 texture is cube-compatible if it has square faces and a layer count
// that is a multiple of 6.
texture_descriptor_is_cube_compatible :: #force_inline proc "contextless" (
    self: Texture_Descriptor_Impl,
) -> bool {
    return self.dimension == .D2 &&
           self.size.width == self.size.height &&
           is_multiple_of(self.size.depth_or_array_layers, 6)
}

@(private, require_results)
resolve_mapped_range_size :: proc(
    allocated_size: u64,
    requested_size: uint = WHOLE_MAP_SIZE,
    offset: uint = 0,
    loc := #caller_location,
) -> u64 {
    assert(requested_size != 0, "mapped range size must not be zero", loc)
    assert(is_multiple_of(offset, MAP_ALIGNMENT), "unaligned offset", loc)
    assert(u64(offset) <= allocated_size, "offset past end of mapped range", loc)

    range_size: u64
    if requested_size == WHOLE_MAP_SIZE {
        range_size = intr.saturating_sub(allocated_size, u64(offset))
    } else {
        range_size = u64(requested_size)
        assert(u64(offset) + range_size <= allocated_size,
            "requested range extends past end of mapped range", loc)
    }

    assert(is_multiple_of(range_size, COPY_BUFFER_ALIGNMENT), "unaligned range size", loc)

    return range_size
}

Alignments :: struct {
    // The alignment of the start of the buffer used as a GPU copy source.
    buffer_copy_offset:                         u64,
    // The alignment of the row pitch of the texture data stored in a buffer
    // that is used in a GPU copy operation.
    buffer_copy_pitch:                          u64,
    // The finest alignment of bound range checking for uniform buffers.
    uniform_bounds_check_alignment:             u64,
    // The size of the raw TLAS instance
    raw_tlas_instance_size:                     u32,
    // What the scratch buffer for building an acceleration structure must be
    // aligned to
    ray_tracing_scratch_buffer_alignment:       u32,
    // How large a single piece of group data is. That is, how large the vector
    // returned from `device_get_raytracing_pipeline_group_data` is.
    //
    // If ray tracing pipelines are implemented, this must be non zero.
    ray_tracing_pipeline_group_data_size:       u32,
    // If ray tracing pipelines are implemented, this must be a power of two
    // (and non zero).
    ray_tracing_pipeline_group_data_alignment:  u32,
    // If ray tracing pipelines are implemented, this must be a power of two
    // (and non zero).
    //
    // The offset within `PipelineGroupData` must be a multiple of this
    ray_tracing_pipeline_data_offset_alignment: u32,
}
