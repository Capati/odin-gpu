#+build js
package tobj

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
    unimplemented("[load_obj_filename] not supported in WASM environment", loc)
}

// Load the various objects specified in the `OBJ` file and any associated `MTL` file.
load_obj :: proc {
    load_obj_reader,
    load_obj_bytes,
    load_obj_filename,
}

load_mtl_filename :: proc(
    filename: string,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    res: MTL_Load_Result,
    err: Maybe(Error),
) {
    unimplemented("[load_mtl_filename] not supported in WASM environment", loc)
}

// Load the materials defined in a `MTL`.
load_mtl :: proc {
    load_mtl_reader,
    load_mtl_bytes,
    load_mtl_filename,
}
