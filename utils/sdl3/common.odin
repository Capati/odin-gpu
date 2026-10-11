package gpu_sdl3

// Vendor
import sdl "vendor:sdl3"
import "../../gpu"

create_surface :: proc(
    window: ^sdl.Window,
    instance: gpu.Instance,
) -> gpu.Surface {
    descriptor := get_surface_descriptor(window)
    return gpu.instance_create_surface(instance, descriptor)
}
