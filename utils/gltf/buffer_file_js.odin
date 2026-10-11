#+build js
package gltf

import "core:mem"

// Has no browser filesystem equivalent. Web callers can supply Options.read_file
// (for example, backed by fetch) or use data URIs.
@(private)
read_buffer_file :: proc(path: string, allocator: mem.Allocator) -> ([]byte, Error) {
    _ = path
    _ = allocator
    return nil, .Unknown_Format
}
