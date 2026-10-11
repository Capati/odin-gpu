package gltf

// Core
import "core:mem"
import "core:strings"

// The GLB container: a 12 byte header followed by length-prefixed chunks.
// Chunks are 4 byte aligned and the JSON chunk must come first.
GLB_MAGIC :: 0x46546C67 // "glTF"
GLB_CHUNK_JSON :: 0x4E4F534A // "JSON"
GLB_CHUNK_BIN :: 0x004E4942 // "BIN\0"

GLB_HEADER_SIZE :: 12
// GLB_ALIGNMENT is the 4 byte boundary every chunk's payload must end on.
GLB_ALIGNMENT :: 4
GLB_CHUNK_HEADER_SIZE :: 8

// Allocates a `Document` together with the growing arena that backs it.
//
// The arena starts small and grows in blocks as it fills. Native builds use
// virtual-memory blocks; JS builds use the target's dynamic allocator. The
// Document object itself uses `allocator`; the arena and file bytes are both
// released by `destroy`.
@(private)
document_alloc :: proc(
    allocator: mem.Allocator,
    minimum_block_size: uint = 32 * 1024,
) -> (
    ^Document,
    mem.Allocator_Error,
) {
    document, err := new(Document, allocator)
    if err != nil {
        return nil, err
    }
    if arena_err := document_arena_init(&document.arena, allocator, minimum_block_size);
       arena_err != nil {
        mem.free(rawptr(document), allocator)
        return nil, arena_err
    }
    document.document_allocator = allocator
    return document, nil
}

// Releases everything owned by `document`: every string and slice in its graph and
// every buffer payload it loaded.  It is safe to call on a nil document.
//
// The bytes that `Document.json` and `Document.bin` point into are *not* copied by
// `parse`, so the caller's own buffer must outlive the document.
// `Document.file_data` is the exception: `parse_file` reads it into the document's
// own allocator and `destroy` hands it back.
destroy :: proc(document: ^Document) {
    if document == nil {
        return
    }
    if document.file_allocator.procedure != nil && document.file_data != nil {
        delete(document.file_data, document.file_allocator)
        document.file_data = nil
    }
    document_allocator := document.document_allocator
    document_arena_destroy(&document.arena)
    mem.free(rawptr(document), document_allocator)
}

// The mutable state threaded through the conversion pass.
@(private)
Parser :: struct {
    document:  ^Document,
    // Everything allocated during conversion comes from it.
    allocator: mem.Allocator,
}

// Fills in the defaults for `options`.
@(private)
resolve_options :: proc(options: Options) -> (Options, Error) {
    resolved := options
    if resolved.allocator.procedure == nil {
        resolved.allocator = context.allocator
    }
    switch resolved.file_type {
    case .Invalid, .Gltf, .Glb:
        return resolved, .None
    case:
        return {}, .Invalid_Options
    }
}

// Reads a `.gltf` (JSON) or `.glb` (binary) document from `data`.
//
// `data` is not copied: the returned document points its name, URI and
// `extras`-free strings at the parsed JSON, and a GLB's `Document.bin` at the
// binary chunk.  `data` must therefore stay alive and must not be appended to for
// as long as the document is in use.
//
// On success the caller owns the document and must call `destroy` on it.
parse :: proc(data: []byte, options := Options{}) -> (document: ^Document, err: Error) {
    resolved, options_err := resolve_options(options)
    if options_err != .None {
        return nil, options_err
    }
    if len(data) == 0 {
        return nil, .Data_Too_Short
    }
    if len(data) < 4 {
        if resolved.file_type == .Glb && !is_glb_prefix(data) {
            return nil, .Unknown_Format
        }
        if is_glb_prefix(data) {
            return nil, .Data_Too_Short
        }
        return parse_json(data, data, .Gltf, nil, resolved)
    }

    magic, _ := read_u32(data, 0)
    if magic == GLB_MAGIC {
        if resolved.file_type == .Gltf {
            return nil, .Unknown_Format
        }
        return parse_glb(data, resolved)
    }
    if resolved.file_type == .Glb {
        return nil, .Unknown_Format
    }
    return parse_json(data, data, .Gltf, nil, resolved)
}

// Reports whether a short byte sequence is the beginning of GLB's little-endian
// magic word. It lets `parse` distinguish a truncated GLB header from a short but
// otherwise valid JSON document such as `{}`.
@(private)
is_glb_prefix :: proc(data: []byte) -> bool {
    for i in 0 ..< len(data) {
        expected := u32(GLB_MAGIC) >> u32(8 * i)
        expected &= 0xFF
        if u32(data[i]) != expected {
            return false
        }
    }
    return len(data) > 0
}

// The `parse` for a string. The string must stay alive for as
// long as the document is in use.
parse_string :: proc(text: string, options := Options{}) -> (document: ^Document, err: Error) {
    return parse(transmute([]byte)text, options)
}

// Reads a little-endian `u32` at `offset`, if it is in bounds.
@(private)
read_u32 :: proc(data: []byte, offset: int) -> (u32, bool) {
    if offset < 0 || offset + 4 > len(data) {
        return 0, false
    }
    return (^u32)(raw_data(data[offset:]))^, true
}

// Parses the binary container.
//
// In two points this follows the GLB 2.0 specification strictly:
//
//   - chunk lengths must be a multiple of 4 and the chunks must be padded;
//     a file that violates this is rejected instead of being misread,
//   - chunks with an unrecognised type are skipped rather than rejected, as
//     the specification requires clients to ignore them.
@(private)
parse_glb :: proc(data: []byte, options: Options) -> (document: ^Document, err: Error) {
    if len(data) < GLB_HEADER_SIZE {
        return nil, .Data_Too_Short
    }
    magic, _ := read_u32(data, 0)
    version, _ := read_u32(data, 4)
    declared_length, _ := read_u32(data, 8)

    if magic != GLB_MAGIC {
        return nil, .Unknown_Format
    }
    if version != 2 {
        return nil, version < 2 ? .Legacy_Gltf : .Unknown_Format
    }
    if int(declared_length) > len(data) {
        return nil, .Data_Too_Short
    }

    chunk_length, chunk_length_ok := read_u32(data, GLB_HEADER_SIZE)
    if !chunk_length_ok {
        return nil, .Data_Too_Short
    }
    chunk_type, _ := read_u32(data, GLB_HEADER_SIZE + 4)
    if chunk_type != GLB_CHUNK_JSON {
        return nil, .Unknown_Format
    }
    if chunk_length % 4 != 0 {
        return nil, .Invalid_Gltf
    }
    json_start := GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE
    if int(chunk_length) > len(data) - json_start {
        return nil, .Data_Too_Short
    }
    json_chunk := data[json_start:json_start + int(chunk_length)]

    // Walk the remaining chunks looking for the first BIN chunk.
    bin: []byte = nil
    offset := json_start + int(chunk_length)
    for offset + GLB_CHUNK_HEADER_SIZE <= len(data) {
        length, ok := read_u32(data, offset)
        if !ok {
            break
        }
        kind, _ := read_u32(data, offset + 4)
        start := offset + GLB_CHUNK_HEADER_SIZE
        if int(length) > len(data) - start {
            return nil, .Data_Too_Short
        }
        if kind == GLB_CHUNK_BIN && bin == nil {
            bin = data[start:start + int(length)]
        }
        // The next chunk starts at the next 4 byte boundary.
        offset = start + (int(length) - int(length) % GLB_ALIGNMENT)
    }

    return parse_json(data, json_chunk, .Glb, bin, options)
}

// Allocates the document, reads a `Raw_Root` out of `json_chunk` with the
// streaming `Reader`, and converts it into the public graph.
//
// `data` is the whole container; only `json_chunk` is scanned, and `data`/`bin`
// are the buffers that the document's strings and `Document.bin` alias.
@(private)
parse_json :: proc(
    data: []byte,
    json_chunk: []byte,
    file_type: File_Type,
    bin: []byte,
    options: Options,
) -> (
    document: ^Document,
    err: Error,
) {
    doc, alloc_err := document_alloc(options.allocator)
    if alloc_err != nil {
        return nil, .Out_Of_Memory
    }

    p := Parser{doc, document_arena_allocator(&doc.arena)}
    doc.file_type = file_type
    doc.json = transmute(string)json_chunk
    doc.bin = bin

    if len(json_chunk) == 0 {
        destroy(doc)
        return nil, .Data_Too_Short
    }

    r := reader_make(json_chunk, p.allocator)
    root := read_root(&r)
    if r.err == .None && rd_next(&r).kind != .EOF {
        rd_fail(&r, .Invalid_Json) // trailing content after the root object
    }
    if r.err != .None {
        destroy(doc)
        return nil, r.err
    }

    if convert_err := convert_root(&p, &root); convert_err != .None {
        destroy(doc)
        return nil, convert_err
    }

    // The parent links are part of the graph rather than something a caller has
    // to ask for, so they are made here and not left to load_buffers.
    link_parents(doc)
    return doc, .None
}

// Enforces glTF 2.0.
//
// This parser only understands 2.0, so an older version is reported as
// `Error.Legacy_Gltf` and a newer one as `Error.Invalid_Gltf`.
@(private)
check_asset_version :: proc(version: string) -> Error {
    if version == "" {
        // `asset` itself is required, and so is `asset.version`.
        return .Invalid_Gltf
    }
    major, ok := parse_major_version(version)
    if !ok {
        return .Invalid_Gltf
    }
    switch {
    case major < 2:
        return .Legacy_Gltf
    case major > 2:
        return .Invalid_Gltf
    case:
        return .None
    }
}

// Returns the leading integer of a dotted glTF version string, so that "2.0",
// "2.1" and "2" all yield 2.
@(private)
parse_major_version :: proc(version: string) -> (int, bool) {
    head := version
    if dot := strings.index_byte(version, '.'); dot >= 0 {
        head = version[:dot]
    }
    head = strings.trim_space(head)
    if head == "" {
        return 0, false
    }
    value := 0
    for c in head {
        if c < '0' || c > '9' {
            return 0, false
        }
        value = value * 10 + int(c - '0')
        if value > 1000 {
            return 0, false
        }
    }
    return value, true
}

// Parses a non-negative decimal integer with no sign, spaces or leading `+`.
@(private)
parse_uint :: proc(text: string) -> (int, bool) {
    if text == "" {
        return 0, false
    }
    value := 0
    for c in text {
        if c < '0' || c > '9' {
            return 0, false
        }
        value = value * 10 + int(c - '0')
        if value > MAX_GLTF_INDEX {
            return 0, false
        }
    }
    return value, true
}

// Resolves a run of index-valued members into pointers into `target`.
//
// `slots` is the address of the first of `len(indices)` *adjacent* `^T` fields,
// which is what lets one helper serve a single optional pointer, a member and its
// array neighbours.
//
// Pointing into `target` is safe because every collection is allocated at its
// final size before any fixup runs, and is never resized afterwards.
@(private)
fixup_indices :: proc($T: typeid, slots: rawptr, indices: []int, target: []T) -> bool {
    if len(indices) == 0 {
        return true
    }
    pointers := ([^]^T)(slots)
    for index, i in indices {
        if index < 0 || index >= len(target) {
            return false
        }
        pointers[i] = &target[index]
    }
    return true
}

// Resolves a single optional index member. `slot` is the address of the `^T` field
// to fill in.
@(private)
fixup_optional :: proc "contextless" ($T: typeid, slot: rawptr, index: Maybe(int), target: []T) -> bool {
    pointer := ([^]^T)(slot)
    if index == nil {
        pointer[0] = nil
        return true
    }
    return fixup_index_single(T, slot, index.?, target)
}

// Resolves one index without the slice-literal allocation that fixup_indices would
// need for a single element. All single-pointer fixups go through here.
@(private)
fixup_index_single :: #force_inline proc "contextless" ($T: typeid, slot: rawptr, index: int, target: []T) -> bool {
    if index < 0 || index >= len(target) {
        return false
    }
    ([^]^T)(slot)[0] = &target[index]
    return true
}

// Allocates a zeroed slice of `n` elements from the arena.
@(private)
alloc_slice :: proc($T: typeid, n: int, allocator: mem.Allocator) -> []T {
    if n <= 0 {
        return nil
    }
    return make([]T, n, allocator)
}

// Returns the directory part of `path`, or "" if it has none.
@(private)
directory_of :: proc(path: string) -> string {
    separator := -1
    for i in 0 ..< len(path) {
        if path[i] == '/' || path[i] == '\\' {
            separator = i
        }
    }
    if separator < 0 {
        return ""
    }
    return path[:separator]
}
