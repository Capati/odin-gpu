#+build js
package application

import "base:runtime"

// The web build cannot read external files; only embedded images (GLB binary
// chunk or `data:` URI) are reachable, and those never reach this path.
resolve_image_uri_path :: proc(
    document_file: string,
    uri: string,
    allocator: runtime.Allocator,
) -> (string, runtime.Allocator_Error) {
    _ = document_file
    _ = allocator
    return uri, .None
}
