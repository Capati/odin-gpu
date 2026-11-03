#+build !js
package vulkan_tests

import "core:testing"
import vk "vendor:vulkan"

import gpu "../../gpu"

// The helper's temporary frame must not own storage that the caller's
// `matched` array grows into. The test drives the cache through the package's
// private temp allocator, so it validates backend internals directly.
@(test)
test_vk_framebuffer_cache_nested_temp_guard :: proc(t: ^testing.T) {
    device_impl: gpu.VK_Device_Impl
    device_impl.framebuffer_cache.allocator = context.allocator
    defer delete(device_impl.framebuffer_cache)

    view := gpu.new_handle_packed(gpu.Texture_View, gpu.Device(nil), gpu.Handle_Packed(1))
    key := gpu.VK_Framebuffer_Key{width = 1, height = 1, attachment_count = 1}
    key.texture_views[0].texture_view = view
    expected := vk.Framebuffer(uintptr(0x1000))
    device_impl.framebuffer_cache[key] = {
        key            = key,
        vk_framebuffer = expected,
    }

    ta := gpu.default_temp_allocator()
    gpu.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    matched: [dynamic]vk.Framebuffer
    matched.allocator = ta
    gpu.vk_framebuffer_cache_remove_view(
        &device_impl, view, &matched, owns_temp_guard = false)

    testing.expect_value(t, len(matched), 1)
    testing.expect_value(t, matched[0], expected)

    // If the ignored guard freed the array's storage, this reuse overwrites it.
    scratch := make([]u8, 64, ta)
    for &byte in scratch {
        byte = 0xAA
    }
    testing.expect_value(t, matched[0], expected)
}
