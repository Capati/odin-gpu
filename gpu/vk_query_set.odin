#+build !js
package gpu

// Core
import hm "core:container/handle_map"

// Vendor
// import vk "vendor:vulkan"

VK_Query_Set_Handle :: distinct hm.Handle64

VK_Query_Set_Impl :: struct {
    handle: VK_Query_Set_Handle,
    ref:    Ref_Count_Type,
}

vk_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

vk_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
    unimplemented(loc = loc)
}

vk_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}
