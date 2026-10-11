package gpu_sdl2

// Vendor
import sdl "vendor:sdl2"
import "../../gpu"

@(private)
get_sys_info :: proc(window: ^sdl.Window) -> (wmInfo: sdl.SysWMinfo) {
    sdl.GetVersion(&wmInfo.version)
    ensure_contextless(bool(sdl.GetWindowWMInfo(window, &wmInfo)))
    return
}

create_surface :: proc (
    window: ^sdl.Window,
    instance: gpu.Instance,
) -> gpu.Surface {
    descriptor := get_surface_descriptor(window)
    return gpu.instance_create_surface(instance, descriptor)
}
