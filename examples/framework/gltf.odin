package application

// Core
import "core:log"
import "core:mem"

// Local packages
import "../../utils/gltf"

// Gltf_Document keeps the pure-Odin document pointer behind the framework's
// existing load/unload API.
Gltf_Document :: struct {
    data:             ^gltf.Document,
    source_data:      []byte,
    external_buffers: [][]byte,
    allocator:        mem.Allocator,
}

// Gltf_Read_State owns the file payloads returned through gltf's external
// buffer hook until gltf_unload is called.
@(private = "file")
Gltf_Read_State :: struct {
    allocator:        mem.Allocator,
    external_buffers: [][]byte,
    count:            int,
}

@(private = "file")
gltf_read_external_buffer :: proc(path: string, user_data: rawptr) -> ([]byte, gltf.Error) {
    state := cast(^Gltf_Read_State)user_data
    if state == nil || state.count >= len(state.external_buffers) {
        return nil, .Invalid_Argument
    }
    data, ok := load_file(path, state.allocator)
    if !ok {
        return nil, .File_Not_Found
    }
    state.external_buffers[state.count] = data
    state.count += 1
    return data, .None
}

@(private = "file")
gltf_release_external_buffers :: proc(buffers: [][]byte, allocator: mem.Allocator) {
    for data in buffers {
        if data != nil {
            delete(data, allocator)
        }
    }
    if buffers != nil {
        delete(buffers, allocator)
    }
}

// gltf_load parses a .gltf or .glb file, loads its buffers, and validates the
// resulting document.  The caller must pair success with gltf_unload.
gltf_load :: proc(
    filename: string,
    allocator := context.allocator,
) -> (
    document: Gltf_Document,
    err: gltf.Error,
) {
    source_data, ok := load_file(filename, allocator)
    if !ok {
        return {}, .File_Not_Found
    }

    parsed, parse_err := gltf.parse(source_data, {allocator = allocator})
    if parse_err != .None {
        delete(source_data, allocator)
        log.errorf("gltf: failed to parse '%s': %v", filename, parse_err)
        return {}, parse_err
    }
    parsed.file_name = filename

    external_buffers := make([][]byte, len(parsed.buffers), allocator)
    read_state := Gltf_Read_State {
        allocator        = allocator,
        external_buffers = external_buffers,
    }
    buffer_options := gltf.Options {
        read_file = gltf_read_external_buffer,
        user_data = rawptr(&read_state),
    }

    buffer_err := gltf.load_buffers(parsed, buffer_options)
    if buffer_err != .None {
        gltf.destroy(parsed)
        gltf_release_external_buffers(external_buffers, allocator)
        delete(source_data, allocator)
        log.errorf("gltf: failed to load buffers for '%s': %v", filename, buffer_err)
        return {}, buffer_err
    }

    if validation_err := gltf.validate(parsed); validation_err != nil {
        validation_error := validation_err.?
        gltf.destroy(parsed)
        gltf_release_external_buffers(external_buffers, allocator)
        delete(source_data, allocator)
        log.errorf("gltf: validation failed for '%s': %v", filename, validation_error)
        return {}, validation_error
    }

    return {
            data = parsed,
            source_data = source_data,
            external_buffers = external_buffers,
            allocator = allocator,
        },
        .None
}

// gltf_unload releases the document and its arena-owned data.
gltf_unload :: proc(document: ^Gltf_Document) {
    assert(document != nil)
    gltf.destroy(document.data)
    gltf_release_external_buffers(document.external_buffers, document.allocator)
    if document.source_data != nil {
        delete(document.source_data, document.allocator)
    }
    document^ = {}
}

gltf_find_attribute :: proc(
    primitive: ^gltf.Primitive,
    attribute_type: gltf.Attribute_Type,
) -> ^gltf.Accessor {
    assert(primitive != nil)
    return gltf.find_accessor(primitive, attribute_type)
}

gltf_read_attribute_floats :: proc(
    accessor: ^gltf.Accessor,
    element_index: int,
    output: []f32,
) -> bool {
    assert(accessor != nil)
    return gltf.read_float(accessor, element_index, output)
}

gltf_read_index :: proc(accessor: ^gltf.Accessor, element_index: int) -> u32 {
    assert(accessor != nil)
    return gltf.read_index(accessor, element_index)
}
