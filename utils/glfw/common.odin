package wgpu_glfw

// Vendor
import "vendor:glfw"
import "../../gpu"

create_surface :: proc (
    window: glfw.WindowHandle,
    instance: gpu.Instance,
) -> gpu.Surface {
    descriptor := get_surface_descriptor(window)
    return gpu.instance_create_surface(instance, descriptor)
}
