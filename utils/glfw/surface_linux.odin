#+build linux
package wgpu_glfw

// Core
import "vendor:glfw"
import "../../gpu"

get_surface_descriptor :: proc (
    window: glfw.WindowHandle,
) -> (
    descriptor: gpu.Surface_Descriptor,
) {
    switch glfw.GetPlatform() {
    case glfw.PLATFORM_WAYLAND:
        descriptor.source = gpu.Surface_Source_Wayland_Surface {
            display = glfw.GetWaylandDisplay(),
            surface = glfw.GetWaylandWindow(window),
        }
    case glfw.PLATFORM_X11:
        descriptor.source = gpu.Surface_Source_Xlib_Window {
            display = glfw.GetX11Display(),
            window  = u64(glfw.GetX11Window(window)),
        }
    case:
        panic_contextless("Unsupported platform")
    }

    return
}
