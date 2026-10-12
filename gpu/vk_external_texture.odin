#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
// import vk "vendor:vulkan"

VK_External_Texture_Handle :: distinct hm.Handle64

VK_External_Texture_Impl :: struct {
    handle: VK_External_Texture_Handle,
    ref:    Ref_Count_Type,
}

vk_external_texture_set_label :: proc(
    external_texture: External_Texture,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_external_texture_add_ref :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_external_texture_release :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}
