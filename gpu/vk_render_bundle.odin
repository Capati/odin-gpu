#+build !js
package gpu

// Core
import hm "core:container/handle_map"

VK_Render_Bundle_Handle :: distinct hm.Handle64

// A finished, immutable list of normalized render commands. Replay appends the
// same commands a pass would record directly, keeping one interpreter for both.
// `scope` is the usage tallied at encode, merged into the pass in one step so
// replay does not re-derive it per command.
VK_Render_Bundle_Impl :: struct {
    using base:        _Render_Bundle_Impl,
    handle:            VK_Render_Bundle_Handle,
    // The compact replay stream (see `vk_bundle_commands.odin`). Backend-agnostic
    // bundles do not carry one: it is a Vulkan replay detail, not part of the
    // public bundle shape.
    commands:          Bundle_Command_Allocator,
    scope:             Render_Bundle_Scope,
    // Whether the recorded commands satisfy their pipeline layouts. Immutable
    // once finished and checked once at finish; `execute_bundles` reads it
    // instead of re-walking the command list every frame.
    bind_groups_valid: bool,
}

@(require_results)
vk_render_bundle_get_impl :: #force_inline proc "contextless" (
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> ^VK_Render_Bundle_Impl {
    device_impl := vk_device_get_impl(render_bundle.device, loc)
    return get_handle_impl(&device_impl.render_bundles, render_bundle.handle, loc)
}

@(require_results)
vk_render_bundle_get_internal_impl :: #force_inline proc "contextless" (
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> ^_Render_Bundle_Impl {
    return vk_render_bundle_get_impl(render_bundle, loc)
}

vk_render_bundle_get_label :: proc(
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> string {
    impl := vk_render_bundle_get_impl(render_bundle, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Render_Bundle, pack_handle(impl.handle))
}

vk_render_bundle_set_label :: proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
) {
    impl := vk_render_bundle_get_impl(render_bundle, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    // A bundle is a recorded command list; it has no Vulkan object to name.
    vk_label_set(&device_impl.labels, .Render_Bundle, pack_handle(impl.handle), label)
}

vk_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    impl := vk_render_bundle_get_impl(render_bundle, loc)
    add_ref(impl, loc)
}

vk_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    impl := vk_render_bundle_get_impl(render_bundle, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        bundle_command_allocator_destroy(&impl.commands, loc)
        delete(impl.immediate_data)
        for pipeline in impl.pipelines {
            vk_render_pipeline_release(pipeline, loc)
        }
        for bind_group in impl.bind_groups {
            vk_bind_group_release(bind_group, loc)
        }
        for buffer in impl.buffers {
            vk_buffer_release(buffer, loc)
        }
        delete(impl.pipelines)
        delete(impl.bind_groups)
        delete(impl.buffers)
        render_bundle_scope_free(&impl.scope)
        vk_label_remove(&device_impl.labels, .Render_Bundle, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.render_bundles, impl.handle)
    }
}
