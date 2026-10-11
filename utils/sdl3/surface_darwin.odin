#+build darwin
package gpu_sdl3

// Vendor
import sdl "vendor:sdl3"
import "../../gpu"

get_surface_descriptor :: proc "c" (window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    view := sdl.Metal_CreateView(window)
    layer := sdl.Metal_GetLayer(view)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Metal_Layer {
        layer = layer,
    }

    return
}
