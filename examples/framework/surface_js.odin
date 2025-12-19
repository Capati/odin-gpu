#+build js
package framework

// Local packages
import gpu "../../"

window_get_gpu_surface :: proc(instance: gpu.Instance, loc := #caller_location) -> gpu.Surface {
    descriptor := gpu.Surface_Descriptor {
        label = "Windows HWND",
        target = gpu.Surface_Source_Canvas_HTML_Selector{
            selector = ctx.os.canvas_id,
        },
    }
    return gpu.instance_create_surface(instance, descriptor, loc)
}
