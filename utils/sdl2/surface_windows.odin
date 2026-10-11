#+build windows
package gpu_sdl2

// Vendor
import sdl "vendor:sdl2"
import "../../gpu"

get_surface_descriptor :: proc(window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    wmInfo := get_sys_info(window)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Windows_HWND {
        hinstance = wmInfo.info.win.hinstance,
        hwnd      = wmInfo.info.win.window,
    }

    return
}
