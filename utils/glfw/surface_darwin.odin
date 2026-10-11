#+build darwin
package wgpu_glfw

// Core
import NS "core:sys/darwin/Foundation"

// Vendor
import CA "vendor:darwin/QuartzCore"
import "vendor:glfw"
import "../../gpu"

get_surface_descriptor :: proc (
    window: glfw.WindowHandle,
) -> (
    descriptor: gpu.Surface_Descriptor,
) {
    nativeWindow := (^NS.Window)(glfw.GetCocoaWindow(window))

    metalLayer := CA.MetalLayer.layer()
    defer metalLayer->release()

    nativeWindow->contentView()->setLayer(metalLayer)

    // Setup surface information
    descriptor.source = gpu.Surface_Source_Metal_Layer {
        layer = metalLayer,
    }

    return
}
