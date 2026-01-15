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
) -> ^T where intr.type_has_field(T, "ctx"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {

    impl := new(T, allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.ctx = context
    impl.allocator = allocator
    ref_count_init(&impl.ref, loc)

    return impl
}

// Creates a new handle object associated with the given `instance`.
@(require_results)
instance_new_handle :: #force_inline proc(
    $T: typeid,
    instance: Instance,
    loc: runtime.Source_Code_Location,
) -> ^T where intr.type_has_field(T, "instance"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(instance != nil, loc = loc)

    instance_impl := get_impl(Instance_Base, instance, loc)
    impl := new(T, instance_impl.allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.instance = instance
    impl.allocator = instance_impl.allocator
    ref_count_init(&impl.ref, loc)

    return impl
}

// Creates a new handle object associated with the given `Adapter`.
@(require_results)
adapter_new_handle :: #force_inline proc(
    $T: typeid,
    adapter: Adapter,
    loc: runtime.Source_Code_Location,
) -> ^T where intr.type_has_field(T, "adapter"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(adapter != nil, loc = loc)

    adapter_impl := get_impl(Adapter_Base, adapter, loc)
    impl := new(T, adapter_impl.allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.adapter = adapter
    impl.allocator = adapter_impl.allocator
    ref_count_init(&impl.ref, loc)

    return impl
}

// Creates a new handle object associated with the given `Command_Encoder`.
@(require_results)
command_encoder_new_handle :: #force_inline proc(
    $T: typeid,
    encoder: Command_Encoder,
    loc: runtime.Source_Code_Location,
) -> ^T where intr.type_has_field(T, "encoder"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(encoder != nil, loc = loc)

    encoder_impl := get_impl(Command_Encoder_Base, encoder, loc)
    impl := new(T, encoder_impl.allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.encoder = encoder
    impl.allocator = encoder_impl.allocator
    ref_count_init(&impl.ref, loc)

    return impl
}

// Creates a new handle object associated with the given `Texture`.
@(require_results)
texture_new_handle :: #force_inline proc(
    $T: typeid,
    texture: Texture,
    loc: runtime.Source_Code_Location,
    init_ref := true,
) -> ^T where intr.type_has_field(T, "texture"),
              intr.type_has_field(T, "device"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(texture != nil, loc = loc)

    texture_impl := get_impl(Texture_Base, texture, loc)
    impl := new(T, texture_impl.allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.texture = texture
    impl.device = texture_impl.device
    impl.allocator = texture_impl.allocator
    ref_count_init(&impl.ref, loc)
    texture_add_ref(texture, loc)

    return impl
}

// Creates a new handle object associated with the given `Device`.
@(require_results)
device_new_handle :: #force_inline proc(
    $T: typeid,
    device: Device,
    loc: runtime.Source_Code_Location,
) -> ^T where intr.type_has_field(T, "device"),
              intr.type_has_field(T, "allocator"),
              intr.type_has_field(T, "ref") {
    assert(device != nil, loc = loc)

    device_impl := get_impl(Device_Base, device, loc)
    impl := new(T, device_impl.allocator, loc)
    assert(impl != nil, "Failed to allocate memory", loc)

    impl.device = device
    impl.allocator = device_impl.allocator
    ref_count_init(&impl.ref, loc)

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
