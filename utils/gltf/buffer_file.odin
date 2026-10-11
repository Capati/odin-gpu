#+build !js
package gltf

import "core:mem"
import "core:os"

// Reads an external buffer URI on native targets. Browser builds use the
// Options.read_file hook instead.
@(private)
read_buffer_file :: proc(path: string, allocator: mem.Allocator) -> ([]byte, Error) {
    contents, read_err := os.read_entire_file(path, allocator)
    if read_err == nil {
        return contents, .None
    }
    general, is_general := read_err.(os.General_Error)
    if is_general && general == .Not_Exist {
        return nil, .File_Not_Found
    }
    return nil, .Io_Error
}
