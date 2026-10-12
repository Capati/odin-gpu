#+build !js
package application

import "base:runtime"
import "core:path/filepath"

// Turns a glTF image URI that points at an external file into a filesystem
// path beside the document. This is the only place `core:path/filepath` is
// needed, and it is kept in this native-only file because `core:os` (which
// `filepath` drags in) does not exist under js/wasm. The js build has no local
// filesystem anyway, so its stub just echoes the URI back; `data:` URIs are
// consumed before this path is reached.
resolve_image_uri_path :: proc(
    document_file: string,
    uri: string,
    allocator: runtime.Allocator,
) -> (string, runtime.Allocator_Error) {
    return filepath.join({filepath.dir(document_file), uri}, allocator)
}