#+private
package gpu

// Core
import "base:runtime"

TEMP_ALLOCATOR_BACKING_SIZE: int : #config(GPU_TEMP_ALLOCATOR_BACKING_SIZE, 4 * runtime.Megabyte)

Temp_Allocator :: struct {
    arena: runtime.Arena,
}

@(thread_local, private="file")
g_temp_allocator: Temp_Allocator

@(thread_local, private="file")
g_temp_allocator_initialized: bool

temp_allocator_init :: proc(
    self: ^Temp_Allocator,
    size: int,
    backing_allocator: runtime.Allocator,
) {
    _ = runtime.arena_init(&self.arena, uint(size), backing_allocator)
}

temp_allocator_destroy :: proc "contextless" (self: ^Temp_Allocator) {
    if self != nil {
        runtime.arena_destroy(&self.arena)
        self^ = {}
    }
}

@(private="file")
temp_allocator_proc :: proc(
    allocator_data: rawptr,
    mode: runtime.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr,
    old_size: int,
    loc := #caller_location,
) -> (data: []byte, err: runtime.Allocator_Error) {
    s := (^Temp_Allocator)(allocator_data)
    return runtime.arena_allocator_proc(
        &s.arena, mode, size, alignment, old_memory, old_size, loc)
}

@(require_results)
temp_allocator :: proc(temp: ^Temp_Allocator) -> runtime.Allocator {
    return runtime.Allocator{
        procedure = temp_allocator_proc,
        data      = temp,
    }
}

@(require_results)
default_temp_allocator :: #force_inline proc "contextless" () -> runtime.Allocator {
    return runtime.Allocator{
        procedure = temp_allocator_proc,
        data      = &g_temp_allocator,
    }
}

@(private="file")
ensure_temp_allocator_init :: proc "contextless" () {
    if !g_temp_allocator_initialized {
        context = runtime.default_context()
        temp_allocator_init(
            &g_temp_allocator,
            TEMP_ALLOCATOR_BACKING_SIZE,
            context.allocator)
        g_temp_allocator_initialized = true
    }
}

@(init, private="file")
_init_temp_allocator :: proc "contextless" () {
    ensure_temp_allocator_init()
}

@(fini, private="file")
_destroy_temp_allocator :: proc "contextless" () {
    if g_temp_allocator_initialized {
        temp_allocator_destroy(&g_temp_allocator)
        g_temp_allocator_initialized = false
    }
}

@(require_results)
temp_allocator_begin :: proc(s: ^Temp_Allocator, loc := #caller_location) -> runtime.Arena_Temp {
    return runtime.arena_temp_begin(&s.arena, loc)
}

temp_allocator_end :: proc(temp: runtime.Arena_Temp, loc := #caller_location) {
    runtime.arena_temp_end(temp, loc)
}

@(deferred_out=temp_allocator_end)
DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD :: #force_inline proc(
    ignore := false,
    loc := #caller_location,
) -> (runtime.Arena_Temp, runtime.Source_Code_Location) {
    if ignore {
        return {}, loc
    } else {
        ensure_temp_allocator_init()
        return temp_allocator_begin(&g_temp_allocator, loc), loc
    }
}

@(deferred_out=temp_allocator_end)
default_temp_allocator_temp_guard :: #force_inline proc(
    self: ^Temp_Allocator,
    ignore := false,
    loc := #caller_location,
) -> (runtime.Arena_Temp, runtime.Source_Code_Location) {
    if ignore {
        return {}, loc
    } else {
        return temp_allocator_begin(self, loc), loc
    }
}
