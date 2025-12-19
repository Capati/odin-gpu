#+build darwin
package framework

// Core
import NS "core:sys/darwin/Foundation"
import CA "vendor:darwin/QuartzCore"
import "vendor:glfw"

// Local packages
import gpu "../../"

window_get_gpu_surface :: proc(instance: gpu.Instance, loc := #caller_location) -> gpu.Surface {
    nativeWindow := (^NS.Window)(glfw.GetCocoaWindow(ctx.os.window))

    metalLayer := CA.MetalLayer.layer()
    defer metalLayer->release()

    nativeWindow->contentView()->setLayer(metalLayer)

    descriptor := gpu.Surface_Descriptor {
        label = "Metal Layer",
        target = gpu.SurfaceSourceMetalLayer{layer = metalLayer},
    }

    return gpu.instance_create_surface(instance, descriptor, loc)
}
