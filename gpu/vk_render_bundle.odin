#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
// import vk "vendor:vulkan"

VK_Render_Bundle_Handle :: distinct hm.Handle64

VK_Render_Bundle_Impl :: struct {
    handle: VK_Render_Bundle_Handle,
    ref:    Ref_Count_Type,
}

vk_render_bundle_set_label :: proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}
