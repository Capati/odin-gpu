#+build linux
package framework

// Core
import "vendor:glfw"

// Local packages
import gpu "../../"

window_get_gpu_surface :: proc(instance: gpu.Instance, loc := #caller_location) -> gpu.Surface {
    descriptor: gpu.Surface_Descriptor
    switch glfw.GetPlatform() {
    case glfw.PLATFORM_WAYLAND:
        descriptor.label = "Wayland Surface"
        descriptor.target = gpu.Surface_Source_Wayland_Surface {
            display = glfw.GetWaylandDisplay(),
            surface = glfw.GetWaylandWindow(ctx.os.window),
        }
    case glfw.PLATFORM_X11:
        descriptor.label = "Xlib Window"
        descriptor.target = gpu.Surface_Source_Xlib_Window {
            display = glfw.GetX11Display(),
            window  = u64(glfw.GetX11Window(ctx.os.window)),
        }
    case:
        panic("Unsupported platform", loc)
    }
    return gpu.instance_create_surface(instance, descriptor, loc)
}
