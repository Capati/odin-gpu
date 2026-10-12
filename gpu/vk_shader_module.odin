#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Shader_Module_Handle :: distinct hm.Handle64

VK_Shader_Module_Impl :: struct {
    device:           Device,
    vk_shader_module: vk.ShaderModule,
    handle:           VK_Shader_Module_Handle,
    ref:              Ref_Count_Type,
}

@(require_results)
vk_shader_module_get_impl :: #force_inline proc "contextless" (
    shader_module: Shader_Module,
    loc := #caller_location,
) -> ^VK_Shader_Module_Impl {
    device_impl := vk_device_get_impl(shader_module.device, loc)
    return get_handle_impl(&device_impl.shader_modules, shader_module.handle, loc)
}

vk_shader_module_get_compilation_info :: proc(
    shader_module: Shader_Module,
    callback_info: Compilation_Info_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

vk_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := vk_shader_module_get_impl(shader_module, loc)
    add_ref(impl, loc)
}

vk_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := vk_shader_module_get_impl(shader_module, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk.DestroyShaderModule(device_impl.vk_device, impl.vk_shader_module, nil)
        remove_handle_impl(&device_impl.shader_modules, impl.handle)
    }
}
