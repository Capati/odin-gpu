#+build windows
package wgpu_glfw

// Core
import win "core:sys/windows"

// Vendor
import "vendor:glfw"
import "../../gpu"

get_surface_descriptor :: proc (
    window: glfw.WindowHandle,
) -> (
    descriptor: gpu.Surface_Descriptor,
) {
    instance := win.GetModuleHandleW(nil)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Windows_HWND {
        hinstance = instance,
        hwnd      = glfw.GetWin32Window(window),
    }

    return
}
