#+build linux
package gpu_sdl3

// Vendor
import sdl "vendor:sdl3"
import "../../gpu"

get_surface_descriptor :: proc(window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    switch sdl.GetCurrentVideoDriver() {
    case "wayland":
        display := sdl.GetPointerProperty(
            sdl.GetWindowProperties(window),
            sdl.PROP_WINDOW_WAYLAND_DISPLAY_POINTER,
            nil,
        )
        surface := sdl.GetPointerProperty(
            sdl.GetWindowProperties(window),
            sdl.PROP_WINDOW_WAYLAND_SURFACE_POINTER,
            nil,
        )

        descriptor.source = gpu.Surface_Source_Wayland_Surface {
            display = display,
            surface = surface,
        }
    case "x11":
        display := sdl.GetPointerProperty(
            sdl.GetWindowProperties(window),
            sdl.PROP_WINDOW_X11_DISPLAY_POINTER,
            nil,
        )
        window := cast(u64)sdl.GetNumberProperty(
            sdl.GetWindowProperties(window),
            sdl.PROP_WINDOW_X11_WINDOW_NUMBER,
            0,
        )
        descriptor.source = gpu.Surface_Source_Xlib_Window {
            display = display,
            window  = window,
        }
    case:
        panic_contextless("Unsupported video driver, expected Wayland or X11")
    }

    return
}
