#+build !js
package gltf

// Core
import "core:mem"
import "core:os"

// Reads and parses a `.gltf` or `.glb` from disk.  The file's bytes are owned by
// the document, so the caller does not have to keep them alive, and
// `Document.file_name` records `path` for `load_buffers` to resolve relative URIs
// against.
parse_file :: proc(path: string, options := Options{}) -> (document: ^Document, err: Error) {
    resolved, options_err := resolve_options(options)
    if options_err != .None {
        return nil, options_err
    }

    data, read_err := read_file_uninitialized(path, resolved.allocator)
    if read_err != nil {
        return nil, .File_Not_Found
    }
    parsed, parse_err := parse(data, resolved)
    if parse_err != .None {
        delete(data, resolved.allocator)
        return nil, parse_err
    }
    parsed.file_name = path
    parsed.file_data = data
    parsed.file_allocator = resolved.allocator
    return parsed, .None
}

// Reads a file without the zero-fill that os.read_entire_file pays for via
// make([]byte, size). For multi-MB GLBs the memset is a measurable fraction of
// parse_file; the bytes are fully overwritten by the read, so the zeroing is pure
// overhead (like malloc vs calloc).
@(private)
read_file_uninitialized :: proc(path: string, allocator: mem.Allocator) -> ([]byte, os.Error) {
    f, open_err := os.open(path)
    if open_err != nil {
        return nil, open_err
    }
    defer os.close(f)
    size, size_err := os.file_size(f)
    if size_err != nil || size <= 0 {
        // Unknown size or empty: fall back to the stdlib path.
        // File is already open; reopen via path for simplicity (rare).
        return os.read_entire_file(path, allocator)
    }
    buf, alloc_err := mem.alloc_bytes(int(size), 1, allocator)
    if alloc_err != nil {
        return nil, alloc_err
    }
    total := 0
    for total < len(buf) {
        n, read_err := os.read(f, buf[total:])
        total += n
        if read_err != nil {
            if read_err == .EOF {
                break
            }
            mem.free_bytes(buf, allocator)
            return nil, read_err
        }
        if n == 0 {
            break
        }
    }
    return buf[:total], nil
}
