package gpu

// Core
import "base:runtime"
import intr "base:intrinsics"

Descriptor_Base :: struct {
    label: string,
}

Handle_Base :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    allocator: runtime.Allocator,
}

@(require_results)
get_impl :: #force_inline proc "contextless" (
    $T: typeid,
    handle: $H,
    loc: runtime.Source_Code_Location,
) -> ^T {
    assert_contextless(handle != nil, loc = loc)
    return cast(^T)handle
}

@(require_results)
instance_new_impl :: #force_inline proc(
    $T: typeid,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
    }

    return impl
}

// Creates a new handle object associated with the given `instance`.
@(require_results)
instance_new_handle :: #force_inline proc(
    $T: typeid,
    instance: Instance,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "instance"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(instance != nil, loc = loc)

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.instance = instance
    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
        instance_add_ref(instance, loc)
    }

    return impl
}

// Creates a new handle object associated with the given `Adapter`.
@(require_results)
adapter_new_handle :: #force_inline proc(
    $T: typeid,
    adapter: Adapter,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "adapter"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(adapter != nil, loc = loc)

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.adapter = adapter
    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
        adapter_add_ref(adapter, loc)
    }

    return impl
}

// Creates a new handle object associated with the given `Command_Encoder`.
@(require_results)
command_encoder_new_handle :: #force_inline proc(
    $T: typeid,
    encoder: Command_Encoder,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "encoder"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(encoder != nil, loc = loc)

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.encoder = encoder
    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
        command_encoder_add_ref(encoder, loc)
    }

    return impl
}

// Creates a new handle object associated with the given `Texture`.
@(require_results)
texture_new_handle :: #force_inline proc(
    $T: typeid,
    texture: Texture,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "texture"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(texture != nil, loc = loc)

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.texture = texture
    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
        texture_add_ref(texture, loc)
    }

    return impl
}

// Creates a new handle object associated with the given `Device`.
@(require_results)
device_new_handle :: #force_inline proc(
    $T: typeid,
    device: Device,
    allocator: runtime.Allocator,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "device"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(device != nil, loc = loc)

    impl := new(T, allocator)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.device = device
    impl.allocator = allocator

    if init_ref {
        ref_count_init(&impl.ref, loc)
        device_add_ref(device, loc)
    }

    return impl
}

release :: proc {
    adapter_release,
    bind_group_release,
    bind_group_layout_release,
    buffer_release,
    command_buffer_release,
    command_encoder_release,
    compute_pass_release,
    device_release,
    instance_release,
    pipeline_layout_release,
    // query_set_release,
    queue_release,
    render_pass_release,
    render_pipeline_release,
    sampler_release,
    shader_module_release,
    surface_release,
    // surface_texture_release,
    texture_release,
    texture_view_release,
}
