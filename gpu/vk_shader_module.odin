#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Shader_Module_Handle :: distinct hm.Handle64

VK_Shader_Module_Impl :: struct {
    using base:       _Shader_Module_Impl,
    vk_shader_module: vk.ShaderModule,
    handle:           VK_Shader_Module_Handle,
}

@(require_results)
vk_shader_module_get_impl :: #force_inline proc "contextless" (
    shader_module: Shader_Module,
    loc := #caller_location,
) -> ^VK_Shader_Module_Impl {
    device_impl := vk_device_get_impl(shader_module.device, loc)
    return get_handle_impl(&device_impl.shader_modules, shader_module.handle, loc)
}

@(require_results)
vk_shader_module_get_internal_impl :: proc "contextless" (
    shader_module: Shader_Module,
    loc := #caller_location,
) -> ^_Shader_Module_Impl {
    if shader_module == {} {
        return nil
    }
    device_impl := vk_device_get_impl(shader_module.device, loc)
    impl := dhm_get_if_valid(
        &device_impl.shader_modules,
        unpack_handle(VK_Shader_Module_Handle, shader_module.handle),
    )
    if impl == nil {
        return nil
    }
    return impl
}

@(require_results)
vk_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    impl := vk_device_get_impl(device, loc)

    #partial switch source in descriptor.source {
    case Shader_Source_SPIRV:
        if !gpu_validate(device, len(source.code) > 0, "shader code is empty", loc) {
            return {}
        }
        if !gpu_validate(
            device,
            len(source.code) >= 5,
            "shader bytecode is too small to be valid SPIR-V",
            loc,
        ) {
            return {}
        }

        create_info := vk.ShaderModuleCreateInfo {
            sType    = .SHADER_MODULE_CREATE_INFO,
            codeSize = len(source.code) * size_of(u32),
            pCode    = raw_data(source.code),
        }

        vk_shader_module: vk.ShaderModule
        if res := impl.fp.CreateShaderModule(impl.vk_device, &create_info, nil, &vk_shader_module);
           res != .SUCCESS {
            vk_try(device, res, "vkCreateShaderModule", loc)
            return {}
        }

        _, shader_module_handle := add_impl(&impl.shader_modules, VK_Shader_Module_Impl {
            device           = device,
            vk_shader_module = vk_shader_module,
        })
        vk_label_set(
            &impl.labels,
            .Shader_Module,
            pack_handle(shader_module_handle),
            descriptor.label,
        )

        return new_handle(Shader_Module, device, shader_module_handle)
    case:
        gpu_report_validation_error(device, "unsupported shader module source", loc)
        return {}
    }

    unreachable()
}

@(require_results)
vk_create_shader_module_spirv :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor_SpirV,
    loc := #caller_location,
) -> Shader_Module {
    return vk_device_create_shader_module(device, {
            label = descriptor.label,
            source = Shader_Source_SPIRV{code = descriptor.source},
        }, loc)
}

@(require_results)
vk_shader_module_get_compilation_info :: proc(
    shader_module: Shader_Module,
    callback_info: Compilation_Info_Callback_Info,
    loc := #caller_location,
) -> Future {
    // SPIR-V is validated by the Vulkan implementation when a pipeline is created,
    // not when the module is; there are no compilation messages to report. An
    // empty future id is already complete (`instance_wait_any` completes ids it
    // does not know).
    return {}
}

vk_shader_module_get_label :: proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string {
    impl := vk_shader_module_get_impl(shader_module, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Shader_Module, pack_handle(impl.handle))
}

vk_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    impl := vk_shader_module_get_impl(shader_module, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Shader_Module, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(
        device_impl.fp,
        .SHADER_MODULE,
        impl.vk_shader_module,
        label,
        loc,
    )
}

vk_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := vk_shader_module_get_impl(shader_module, loc)
    add_ref(impl, loc)
}

vk_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := vk_shader_module_get_impl(shader_module, loc)
    if release_ref(impl, loc) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_deferred_add_resource(
            &device_impl.deferred,
            &device_impl.submitter,
            VK_Deferred_Shader_Module{module = impl.vk_shader_module},
        )
        vk_label_remove(&device_impl.labels, .Shader_Module, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.shader_modules, impl.handle)
    }
}
