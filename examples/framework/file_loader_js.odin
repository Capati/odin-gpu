#+build js
package framework

// Core
import "base:runtime"
import "core:mem"
import "core:log"

LOAD_FILE_BUFFER_SIZE :: #config(RL_LOAD_FILE_BUFFER_SIZE, 1 * mem.Megabyte)

foreign import "js_utils"

@(default_calling_convention = "contextless")
foreign js_utils {
    js_load_file_sync :: proc(path: string, buffer: [^]u8, buffer_size: int) -> int ---
}

load_file :: proc(filename: string, allocator := context.allocator) -> (data: []u8, ok: bool) {
    log.infof("Loading: %s", filename)

    // Create temporary buffer
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    temp_buffer := make([]u8, LOAD_FILE_BUFFER_SIZE, ta)

    // Load file into buffer
    length := js_load_file_sync(filename, raw_data(temp_buffer), len(temp_buffer))

    if length <= 0 {
        log.errorf("Failed to load file: %s", filename)
        return
    }

    // Copy to final buffer
    data = make([]u8, length, allocator)
    copy(data, temp_buffer[:length])

    return data, true
}
