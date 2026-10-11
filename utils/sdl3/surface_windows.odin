#+build windows
package gpu_sdl3

// Vendor
import sdl "vendor:sdl3"
import "../../gpu"

get_surface_descriptor :: proc(window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    hinstance := sdl.GetPointerProperty(
        sdl.GetWindowProperties(window),
        sdl.PROP_WINDOW_WIN32_INSTANCE_POINTER,
        nil,
    )
    hwnd := sdl.GetPointerProperty(
        sdl.GetWindowProperties(window),
        sdl.PROP_WINDOW_WIN32_HWND_POINTER,
        nil,
    )

    assert(hwnd != nil)
    assert(hinstance != nil)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Windows_HWND {
        hinstance = hinstance,
        hwnd      = hwnd,
    }

    return
}
