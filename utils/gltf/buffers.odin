package gltf

// Core
import "core:encoding/base64"
import "core:mem"
import "core:strings"

// Resolves the payload of every buffer and republishes each bufferView's byte
// range.
//
// It must be called before any accessor can be read; `parse` only builds the
// graph.  It is not called automatically because loading external files is a
// policy decision (see `Options.read_file`).
//
// On failure no buffer is left half-loaded: payloads are resolved into local
// variables first and only committed once all of them are known to be good.
load_buffers :: proc(document: ^Document, options := Options{}) -> Error {
    if document == nil {
        return .Invalid_Argument
    }
    resolved, options_err := resolve_options(options)
    if options_err != .None {
        return options_err
    }
    allocator := document_arena_allocator(&document.arena)

    // A GLB's BIN chunk is the payload of the first buffer, provided that
    // buffer does not name its own URI.
    if document.file_type == .Glb &&
       len(document.bin) > 0 &&
       len(document.buffers) > 0 &&
       document.buffers[0].data == nil &&
       document.buffers[0].uri == "" {
        size := document.buffers[0].size
        if size == 0 {
            // `byteLength` was absent; the chunk is the payload as written.
            size = len(document.bin)
        }
        if size > len(document.bin) {
            return .Data_Too_Short
        }
        document.buffers[0].data = document.bin[:size]
    }

    base := resolved.base_directory
    if base == "" {
        base = directory_of(document.file_name)
    }

    // Resolve everything before committing, so a failure half way through does
    // not leave a document with some buffers loaded and others not.
    loaded := make([][]byte, len(document.buffers), allocator)
    for &buffer, index in document.buffers {
        if buffer.data != nil {
            loaded[index] = buffer.data
            continue
        }
        if buffer.uri == "" {
            // A buffer with neither a URI nor a GLB payload stays empty; whether
            // that is an error depends on what references it.
            continue
        }
        data, err := resolve_buffer(
            &buffer,
            base,
            allocator,
            resolved.read_file,
            resolved.user_data,
        )
        if err != .None {
            return err
        }
        loaded[index] = data
    }

    for &buffer, index in document.buffers {
        buffer.data = loaded[index]
    }

    // Publish each bufferView's range so that accessor reads never have to walk
    // back up to the buffer.
    for &view in document.buffer_views {
        view.data = buffer_view_data(&view)
    }

    link_parents(document)
    return .None
}

// Loads one buffer's payload into freshly allocated memory.
//
// Recording ownership on the buffer *before* checking whether the load succeeded
// would leave a failed load claiming memory it never received. Here nothing is
// written back to `buffer` at all: the caller commits the result only on success.
@(private)
resolve_buffer :: proc(
    buffer: ^Buffer,
    base: string,
    allocator: mem.Allocator,
    read_file: proc(path: string, user_data: rawptr) -> ([]byte, Error),
    user_data: rawptr,
) -> (
    []byte,
    Error,
) {
    data: []byte

    if strings.has_prefix(buffer.uri, "data:") {
        decoded, err := decode_data_uri(buffer.uri, allocator)
        if err != .None {
            return nil, err
        }
        data = decoded
    } else {
        if strings.contains(buffer.uri, "://") && read_file == nil {
            // Fetching over the network is out of scope for this package; a
            // caller that wants it can install Options.read_file.
            return nil, .Unknown_Format
        }
        if base == "" && read_file == nil {
            // With no file name and no explicit base directory there is nothing
            // to resolve a relative URI against.
            return nil, .Unknown_Format
        }
        relative := decode_uri(buffer.uri, allocator)
        path := combine_path(base, relative, allocator)
        if read_file != nil {
            read, err := read_file(path, user_data)
            if err != .None {
                return nil, err
            }
            data = read
        } else {
            contents, read_err := read_buffer_file(path, allocator)
            if read_err != nil {
                return nil, read_err
            }
            data = contents
        }
    }

    // The payload has to cover the declared length; a shorter one would make
    // every accessor that points into it read out of bounds.  A longer one is
    // kept as it is: a buffer's payload is the file, not just its first
    // `byteLength` bytes, and the validator is what bounds every bufferView.
    if buffer.size > 0 && len(data) < buffer.size {
        return nil, .Data_Too_Short
    }
    return data, .None
}

// Resolves the relative URI `relative` against the base directory `base`,
// producing a path in `allocator`.
//
// The base loses any trailing separators, so that `"assets/"` and `"assets"` give
// the same answer.  A `relative` that is already absolute, or that carries its own
// scheme, is returned unchanged; the caller has already rejected the scheme case,
// but keeping the check here means the helper is safe on its own.
@(private)
combine_path :: proc(base, relative: string, allocator: mem.Allocator) -> string {
    if relative == "" {
        return base
    }
    if strings.has_prefix(relative, "/") || strings.contains(relative, "://") {
        return relative
    }
    if base == "" {
        return relative
    }
    length := len(base)
    for length > 0 && (base[length - 1] == '/' || base[length - 1] == '\\') {
        length -= 1
    }
    joined := make([]byte, length + 1 + len(relative), allocator)
    copy(joined, base[:length])
    // Forward slashes are accepted by native Windows APIs and are the normal
    // separator in browser-backed read hooks.
    joined[length] = '/'
    copy(joined[length + 1:], relative)
    return transmute(string)joined
}

// Decodes the payload of a `data:` URI.
//
// Both the base64 form and the plain percent-encoded form are accepted. The
// decoder must not treat `=` padding as an invalid character, must not read past
// the end of the string when the payload is truncated, and must compare the number
// of bytes produced against `buffer.byteLength`.
@(private)
decode_data_uri :: proc(uri: string, allocator: mem.Allocator) -> ([]byte, Error) {
    comma := strings.index_byte(uri, ',')
    if comma < 0 {
        return nil, .Invalid_Gltf
    }
    parameters := uri[len("data:"):comma]
    payload := uri[comma + 1:]

    if !strings.has_suffix(parameters, ";base64") {
        return transmute([]byte)decode_uri(payload, allocator), .None
    }

    decoded, decode_err := base64.decode(payload, allocator = allocator)
    if decode_err != nil {
        return nil, .Invalid_Gltf
    }
    return decoded, .None
}

// Percent-decodes `uri` into a string owned by `allocator`.
//
// glTF URIs are percent-encoded RFC 3986 style, so a path such as
// `textures/my%20texture.png` has to become `textures/my texture.png` before it is
// opened.  A malformed escape is copied through verbatim, which leaves the
// resulting path simply not found instead of silently decoding to something else.
@(private)
decode_uri :: proc(uri: string, allocator: mem.Allocator) -> string {
    if !strings.contains(uri, "%") {
        return uri
    }
    // An escape only ever shrinks the string, so the input length is an upper
    // bound on the output.
    decoded := make([]byte, len(uri), allocator)
    write := 0
    for read := 0; read < len(uri); {
        if uri[read] == '%' && read + 2 < len(uri) {
            high, high_ok := hex_value(uri[read + 1])
            low, low_ok := hex_value(uri[read + 2])
            if high_ok && low_ok {
                decoded[write] = byte(high * 16 + low)
                write += 1
                read += 3
                continue
            }
        }
        decoded[write] = uri[read]
        write += 1
        read += 1
    }
    return transmute(string)decoded[:write]
}

// Returns the numeric value of a hexadecimal digit, or -1.
@(private)
hex_value :: proc(c: u8) -> (int, bool) {
    switch {
    case c >= '0' && c <= '9':
        return int(c - '0'), true
    case c >= 'A' && c <= 'F':
        return int(c - 'A') + 10, true
    case c >= 'a' && c <= 'f':
        return int(c - 'a') + 10, true
    }
    return -1, false
}
