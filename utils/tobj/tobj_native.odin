#+build !js
package tobj

// Core
import "core:bufio"
import "core:log"
import os "core:os/os2"

// Load the various objects specified in the `OBJ` file and any associated `MTL` file.
//
// Inputs:
//
// - `filename` - The path of a `OBJ` file.
// - `material_loader_info` - Callback information used when a texture is found.
// - `load_options` - Governs on-the-fly processing of the mesh during loading.
// - `allocator` - The allocator used to allocate data for models and materials.
//
// Returns:
//
// - `models` - All the models loaded from the file.
// - `materials` - All materials from referenced material libraries.
// - `err` - A error that may occur while loading `OBJ` and `MTL` files., `nil` otherwise.
load_obj_filename :: proc(
    filename: string,
    material_loader_info: Material_Loader_Callback_Info = {},
    load_options := DEFAULT_LOAD_OPTIONS,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    models: []Model,
    materials: []Material,
    err: Maybe(Error),
) {
    file_handle, open_err := os.open(filename)
    if open_err != nil {
        log.errorf("load_obj - failed to open '%s' due to [%v]", filename, open_err)
        err = .Open_File_Failed
        return
    }
    defer os.close(file_handle)

    reader: bufio.Reader
    bufio.reader_init(&reader, os.to_stream(file_handle), allocator = allocator)
    defer bufio.reader_destroy(&reader)

    return load_obj_reader(&reader, material_loader_info, load_options, allocator, loc)
}

// Load the various objects specified in the `OBJ` file and any associated `MTL` file.
load_obj :: proc {
    load_obj_reader,
    load_obj_bytes,
    load_obj_filename,
}

// Load the materials defined in a `MTL` file.
//
// Inputs:
//
// - `filename` - The path of a `MTL` file.
// - `allocator` - The allocator used to allocate data for materials.
//
// Returns:
//
// - `res` - Contains all the materials loaded from the file and a map of `MTL`
//   name to index.
// - `err` - A error that may occur while loading `MTL` files., `nil` otherwise.
load_mtl_filename :: proc(
    filename: string,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    res: MTL_Load_Result,
    err: Maybe(Error),
) {
    file_handle, open_err := os.open(filename)
    if open_err != nil {
        log.errorf("load_mtl - failed to open '%s' due to [%v]", filename, open_err)
        err = .Open_File_Failed
        return
    }
    defer os.close(file_handle)

    reader: bufio.Reader
    bufio.reader_init(&reader, os.to_stream(file_handle), allocator = allocator)
    defer bufio.reader_destroy(&reader)

    return load_mtl_reader(&reader, allocator, loc)
}

// Load the materials defined in a `MTL`.
load_mtl :: proc {
    load_mtl_reader,
    load_mtl_bytes,
    load_mtl_filename,
}
