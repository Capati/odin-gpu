#+build js
package gpu

// Core
import "base:runtime"

g_js_context: runtime.Context

@(private = "file", init)
js_init_allocator :: proc "contextless" () {
    if g_js_context.allocator.procedure == nil {
        g_js_context = runtime.default_context()
    }
}

@(private = "file", export)
js_alloc :: proc "contextless" (size: i32) -> [^]byte {
    context = g_js_context
    bytes, err := runtime.mem_alloc(int(size), 16)
    assert(err == nil, "js_alloc failed")
    return raw_data(bytes)
}

@(private = "file", export)
js_free :: proc "contextless" (ptr: rawptr) {
    context = g_js_context
    err := free(ptr)
    assert(err == nil, "js_free failed")
}
