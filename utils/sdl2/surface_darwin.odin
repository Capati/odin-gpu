#+build darwin
package gpu_sdl2

// Vendor
import NS "core:sys/darwin/Foundation"

// Vendor
import CA "vendor:darwin/QuartzCore"
import sdl "vendor:sdl2"
import "../../gpu"

get_surface_descriptor :: proc(window: ^sdl.Window) -> (descriptor: gpu.Surface_Descriptor) {
    wmInfo := get_sys_info(window)

    nativeWindow := (^NS.Window)(wmInfo.info.cocoa.window)

    metalLayer := CA.MetalLayer.layer()
    defer metalLayer->release()

    nativeWindow->contentView()->setLayer(metalLayer)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Metal_Layer {
        layer = metalLayer,
    }

    return
}
