#+build linux
package application

// Core
import "vendor:glfw"

// Local packages
import "../../gpu"

window_get_gpu_surface :: proc(instance: gpu.Instance, loc := #caller_location) -> gpu.Surface {
    descriptor: gpu.Surface_Descriptor
    wayland_source: gpu.Surface_Source_Wayland_Surface
    x11_source: gpu.Surface_Source_Xlib_Window
    switch glfw.GetPlatform() {
    case glfw.PLATFORM_WAYLAND:
        descriptor.label = "Wayland Surface"
        wayland_source.display = glfw.GetWaylandDisplay()
        wayland_source.surface = glfw.GetWaylandWindow(g_ctx.os.window)
        descriptor.source = wayland_source
    case glfw.PLATFORM_X11:
        descriptor.label = "Xlib Window"
        x11_source.display = glfw.GetX11Display()
        x11_source.window  = u64(glfw.GetX11Window(g_ctx.os.window))
        descriptor.source = x11_source
    case:
        panic("Unsupported platform", loc)
    }
    return gpu.instance_create_surface(instance, descriptor, loc)
}
