#+build js
#+private file
package gpu

// Core
import "base:runtime"

g_context: runtime.Context

@(init)
gpu_init_allocator :: proc "contextless" () {
    if g_context.allocator.procedure == nil {
        g_context = runtime.default_context()
    }
}

@(export)
gpu_alloc :: proc "contextless" (size: i32) -> [^]byte {
    context = g_context
    bytes, err := runtime.mem_alloc(int(size), 16)
    assert(err == nil, "gpu_alloc failed")
    return raw_data(bytes)
}

@(export)
gpu_free :: proc "contextless" (ptr: rawptr) {
    context = g_context
    err := free(ptr)
    assert(err == nil, "gpu_free failed")
}
