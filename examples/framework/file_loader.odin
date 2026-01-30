#+build !js
package framework

// Core
import "core:log"
import os "core:os/os2"

load_file :: proc(filename: string, allocator := context.allocator) -> (data: []u8, ok: bool) {
    log.infof("Loading: %s", filename)

    out, err := os.read_entire_file(filename, allocator)
    if err != nil {
        log.errorf("Failed to load file [%v]: %s", err, filename)
        return
    }
    return out, true
}
