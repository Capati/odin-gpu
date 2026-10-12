#+build windows
package application

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:glfw"

// Local packages
import "../../gpu"

window_get_gpu_surface :: proc(instance: gpu.Instance, loc := #caller_location) -> gpu.Surface {
    surface_descriptor := gpu.Surface_Descriptor {
        source    = gpu.Surface_Source_Windows_HWND {
        hinstance = win32.GetModuleHandleW(nil),
        hwnd      = glfw.GetWin32Window(g_ctx.os.window),
        },
    }
    return gpu.instance_create_surface(instance, surface_descriptor, loc)
}
