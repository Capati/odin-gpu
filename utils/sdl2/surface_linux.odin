#+build linux
package gpu_sdl2

// Vendor
import sdl "vendor:sdl2"
import "../../gpu"

get_surface_descriptor :: proc(window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    wmInfo := get_sys_info(window)

    // Setup surface information
    if wmInfo.subsystem == .WAYLAND {
        descriptor.source = gpu.Surface_Source_Wayland_Surface {
            display = wmInfo.info.wl.display,
            surface = wmInfo.info.wl.surface,
        }
    } else if wmInfo.subsystem == .X11 {
        descriptor.source = gpu.Surface_Source_Xlib_Window {
            display = wmInfo.info.x11.display,
            window  = cast(u64)wmInfo.info.x11.window,
        }
    }

    return
}
