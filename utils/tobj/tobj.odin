package tobj

// Core
import "base:runtime"
import "core:bufio"
import "core:bytes"
import "core:log"
import "core:strconv"
import "core:strings"
import os "core:os/os2"

MISSING_INDEX :: max(uint)

// Possible errors that may occur while loading `OBJ` and `MTL` files.
Error :: enum {
    None,
    Open_File_Failed,
    Read_Error,
    Unrecognized_Character,
    Parse_Value_Error,
    Position_Parse_Error,
    Normal_Parse_Error,
    Texcoord_Parse_Error,
    Face_Parse_Error,
    Material_Parse_Error,
    Invalid_Object_Name,
    Invalid_Polygon,
    Face_Vertex_Out_Of_Bounds,
    Face_Texcoord_Out_Of_Bounds,
    Face_Normal_Out_Of_Bounds,
    Face_Color_Out_Of_Bounds,
    Invalid_Load_Option_Config,
    Generic_Failure,
}

// A mesh made up of triangles loaded from some `OBJ` file.
Mesh :: struct {
    // Flattened 3 component floating point vectors, storing positions of
    // vertices in the mesh.
    positions:    [dynamic]f32,
    // Flattened 3 component floating point vectors, storing the color
    // associated with the vertices in the mesh.
    //
    // Most meshes do not have vertex colors. If no vertex colors are specified
    // this will be empty.
    vertex_color: [dynamic]f32,
    // Flattened 3 component floating point vectors, storing normals of vertices
    // in the mesh.
    //
    // Not all meshes have normals. If no normals are specified this will be empty.
    normals:      [dynamic]f32,
    // Flattened 2 component floating point vectors, storing texture coordinates
    // of vertices in the mesh.
    //
    // Not all meshes have texture coordinates. If no texture coordinates are
    // specified this will be empty.
    texcoords:    [dynamic]f32,
    // Indices for vertices of each face. If loaded with
    // `Load_Options.triangulate` set to `true` each face in the mesh is a triangle.
    //
    // Otherwise `face_arities` indicates how many indices are used by each face.
    indices:      [dynamic]u32,
    // The number of vertices (arity) of each face. *Empty* if loaded with
    // `triangulate` set to `true` or if the mesh constists *only* of triangles.
    //
    // The offset for the starting index of a face can be found by iterating
    // through the `face_arities` until reaching the desired face, accumulating
    // the number of vertices used so far.
    face_arities: [dynamic]u32,
    // Optional material id associated with this mesh. The material id indexes
    // into the list of Materials loaded from the associated `MTL` file
    material_id:  Maybe(uint),
}

// Options for processing the mesh during loading.
//
// Passed to `load_obj()`.
Load_Options :: struct {
    // Triangulate all faces.
    //
    // * Points (one point) and lines (two points) are blown up to zero area
    //   triangles via point duplication. Except if `ignore_points` or
    //   `ignore_lines` is/are set to `true`, resp.
    //
    // * The resulting `Mesh`'s `face_arities` will be empty as all faces are
    //   guranteed to have arity `3`.
    //
    // * Only polygons that are trivially convertible to triangle fans are
    //   supported. Arbitrary polygons may not behave as expected. The best
    //   solution would be to convert your mesh to solely consist of triangles
    //   in your modeling software.
    triangulate:   bool,
    // Ignore faces containing only a single vertex (points).
    //
    // This is usually what you want if you do *not* intend to make special use
    // of the point data (e.g. as particles etc.).
    //
    // Polygon meshes that contain faces with one vertex only usually do so
    // because of bad topology.
    ignore_points: bool,
    // Ignore faces containing only two vertices (lines).
    //
    // This is usually what you want if you do *not* intend to make special use
    // of the line data (e.g. as wires/ropes etc.).
    //
    // Polygon meshes that contains faces with two vertices only usually do so
    // because of bad topology.
    ignore_lines:  bool,
}

// Typical `Load_Options` for using meshes in a GPU/relatime context.
//
// Faces are *triangulated* and *degenerate faces* (points & lines) are *discarded*.
DEFAULT_LOAD_OPTIONS :: Load_Options {
    triangulate   = true,
    ignore_points = true,
    ignore_lines  = true,
}

// A named model within the file.
//
// Associates some mesh with a name that was specified with an `o` or `g`
// keyword in the `OBJ` file.
Model :: struct {
    mesh: Mesh,
    name: string,
}

// Supported texture options.
Texture_Options :: struct {
    blendu:  bool,
    blendv:  bool,
    boost:   f32,
    mm:      struct {
        base: f32,
        gain: f32,
    },
    o:       [3]f32,
    s:       [3]f32,
    t:       [3]f32,
    texres:  Maybe(int),
    clamp:   bool,
    bm:      Maybe(f32),
    imfchan: Maybe(enum u8 {
        R, G, B, M, L, Z,
    }),
}

// Default texture options peer specs.
DEFAULT_TEXTURE_OPTIONS :: Texture_Options {
    blendu  = true,
    blendv  = true,
    boost   = 0,
    mm      = { base = 0, gain = 1 },
    o       = {0, 0, 0},
    s       = {1, 1, 1},
    t       = {0, 0, 0},
    texres  = nil,
    clamp   = false,
    bm      = nil,
    imfchan = nil,
}

// A named texture within the file and options.
Texture :: struct {
    name:          string,
    using options: Texture_Options,
}

// A material that may be referenced by one or more `Mesh`es.
//
// Standard `MTL` attributes are supported. Any unrecognized parameters will be
// stored as key-value pairs in the `unknown_param`, which maps the unknown
// parameter to the value set for it.
//
// No path is pre-pended to the texture file names specified in the `MTL` file.
Material :: struct {
    // Material name as specified in the `MTL` file.
    name:               string,
    // Ambient color of the material.
    ambient:            [3]f32,
    // Diffuse color of the material.
    diffuse:            [3]f32,
    // Specular color of the material.
    specular:           [3]f32,
    // Material shininess attribute. Also called `glossiness`.
    shininess:          f32,
    // Dissolve attribute is the alpha term for the material. Referred to as
    // dissolve since that's what the `MTL` file format docs refer to it as.
    dissolve:           f32,
    // Optical density also known as index of refraction. Called
    // `optical_density` in the `MTL` specc. Takes on a value between 0.001 and
    // 10.0. 1.0 means light does not bend as it passes through the object.
    optical_density:    f32,
    // Name of the ambient texture file for the material.
    ambient_texture:    Texture,
    // Name of the diffuse texture file for the material.
    diffuse_texture:    Texture,
    // Name of the specular texture file for the material.
    specular_texture:   Texture,
    // Name of the normal map texture file for the material.
    normal_texture:     Texture,
    // Name of the shininess map texture file for the material.
    shininess_texture:  Texture,
    // Name of the alpha/opacity map texture file for the material.
    //
    // Referred to as `dissolve` to match the `MTL` file format specification.
    dissolve_texture:   Texture,
    // The illumnination model to use for this material. The different
    // illumination models are specified in the [`MTL` spec](http://paulbourke.net/dataformats/mtl/).
    illumination_model: u8,
    // Key value pairs of any unrecognized parameters encountered while parsing
    // the material.
    unknown_param:      map[string]string,
}

get_material_by_name :: proc(materials: []Material, name: string) -> Maybe(^Material) {
    for &mat in materials {
        if mat.name == name {
            return &mat
        }
    }
    return nil
}

// Struct storing indices corresponding to the vertex.
//
// Some vertices may not have texture coordinates or normals, 0 is used to
// indicate this as OBJ indices begin at 1
Vertex :: struct {
    v:  uint,
    vt: uint,
    vn: uint,
}

Point :: Vertex

Line :: [2]Vertex

Triangle :: [3]Vertex

Quad :: [4]Vertex

Polygon :: []Vertex

/// Union representing a face, storing indices for the face vertices.
Face :: union {
    Point,
    Line,
    Triangle,
    Quad,
    Polygon,
}

// Map of `MTL` name to index.
Material_Map :: map[string]uint

// Contains all the materials loaded from the file and a map of `MTL` name to index.
MTL_Load_Result :: struct {
    materials: []Material,
    mat_map:   Material_Map,
}

// Callback called by `load_obj` when a texture is found.
Proc_Material_Loader :: #type proc(
    filename: string,
    userdata: rawptr,
    allocator := context.allocator,
    loc := #caller_location,
) -> (MTL_Load_Result, Maybe(Error))

// Callback information used when a texture is found.
Material_Loader_Callback_Info :: struct {
    callback: Proc_Material_Loader,
    userdata: rawptr,
}

// Load the various objects specified in the `OBJ` reader and any associated `MTL` file.
//
// Inputs:
//
// - `reader` - The reader of a `OBJ` file, already initialized.
// - `material_loader_info` - Callback information used when a texture is found.
// - `load_options` - Governs on-the-fly processing of the mesh during loading.
// - `allocator` - The allocator used to allocate data for models and materials.
//
// Returns:
//
// - `models` - All the models loaded from the file.
// - `materials` - All materials from referenced material libraries.
// - `err` - A error that may occur while loading `OBJ` and `MTL` files., `nil` otherwise.
load_obj_reader :: proc(
    reader: ^bufio.Reader,
    material_loader_info: Material_Loader_Callback_Info = {},
    load_options := DEFAULT_LOAD_OPTIONS,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    models: []Model,
    materials: []Material,
    err: Maybe(Error),
) {
    context.allocator = allocator

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    tmp_models: Tmp_Models

    // This models list is owned by the caller
    tmp_models.models.allocator = allocator

    // Other data are exported later
    tmp_models.pos.allocator = ta
    tmp_models.colors.allocator = ta
    tmp_models.texcoord.allocator = ta
    tmp_models.normal.allocator = ta
    tmp_models.faces.allocator = ta

    defer if err != nil {
        models_destroy(tmp_models.models[:])
    }

    tmp_materials: Tmp_Materials

    // This materials list is owned by the caller
    tmp_materials.materials.allocator = allocator

    // Other data are exported later
    tmp_materials.mat_map.allocator = ta

    defer if err != nil {
        materials_destroy(tmp_materials.materials[:])
        // Clean up material map keys
        for key in tmp_materials.mat_map {
            delete(key)
        }
    }

    for {
        line, line_err := bufio.reader_read_string(reader, '\n', ta)
        if line_err != nil {
            if line_err == .EOF {
                // Process last line if it exists and doesn't end with newline
                if len(line) > 0 {
                    parse_obj_line(line,
                        &tmp_models, &tmp_materials,
                        material_loader_info,
                        load_options, allocator, loc) or_return
                }
                break
            }
            log.errorf("Error reading line:", line_err)
            err = .Read_Error
            return
        }

        parse_obj_line(line,
            &tmp_models, &tmp_materials,
            material_loader_info,
            load_options, allocator, loc) or_return
    }

    // For the last object in the file we won't encounter another object name to
    // tell us when it's done, so if we're parsing an object push the last one
    // on the list as well
    if len(tmp_models.faces) > 0 {
        mesh := export_faces(&tmp_models, load_options) or_return
        append(&tmp_models.models, Model{ mesh, tmp_models.name })
    }

    models = tmp_models.models[:]
    materials = tmp_materials.materials[:]

    return
}

// Load the various objects specified in the `OBJ` data and any associated `MTL` file.
//
// Inputs:
//
// - `data` - The raw bytes of a `OBJ` file.
// - `material_loader_info` - Callback information used when a texture is found.
// - `load_options` - Governs on-the-fly processing of the mesh during loading.
// - `allocator` - The allocator used to allocate data for models and materials.
//
// Returns:
//
// - `models` - All the models loaded from the file.
// - `materials` - All materials from referenced material libraries.
// - `err` - A error that may occur while loading `OBJ` and `MTL` files., `nil` otherwise.
load_obj_bytes :: proc(
    data: []byte,
    material_loader_info: Material_Loader_Callback_Info = {},
    load_options := DEFAULT_LOAD_OPTIONS,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    models: []Model,
    materials: []Material,
    err: Maybe(Error),
) {
    reader: bufio.Reader
    bufio.reader_init(&reader, bytes.reader_init(&bytes.Reader{}, data), allocator = allocator)
    defer bufio.reader_destroy(&reader)

    return load_obj_reader(&reader, material_loader_info, load_options, allocator, loc)
}

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

// Load the materials defined in a `MTL` reader.
//
// Inputs:
//
// - `reader` - The reader of a `MTL` file, already initialized.
// - `allocator` - The allocator used to allocate data for materials.
//
// Returns:
//
// - `res` - Contains all the materials loaded from the reader and a map of `MTL`
//   name to index.
// - `err` - A error that may occur while loading `MTL` files., `nil` otherwise.
load_mtl_reader :: proc(
    reader: ^bufio.Reader,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    res: MTL_Load_Result,
    err: Maybe(Error),
) {
    context.allocator = allocator

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    tmp_materials: Tmp_Materials
    tmp_materials.materials.allocator = allocator
    tmp_materials.mat_map.allocator = allocator
    cur_mat: Material

    for {
        line, line_err := bufio.reader_read_string(reader, '\n', ta)
        if line_err != nil {
            if line_err == .EOF {
                // Process last line if it exists and doesn't end with newline
                if len(line) > 0 {
                    parse_mtl_line(line, &tmp_materials, &cur_mat, allocator, loc) or_return
                }
                break
            }
            log.errorf("load_mtl failed - error reading line:", line_err)
            err = .Read_Error
            return
        }

        parse_mtl_line(line, &tmp_materials, &cur_mat, allocator, loc) or_return
    }

    if len(cur_mat.name) != 0 {
        tmp_materials.mat_map[cur_mat.name] = len(tmp_materials.materials)
        append(&tmp_materials.materials, cur_mat)
    }

    res = { tmp_materials.materials[:], tmp_materials.mat_map }

    return
}

// Load the materials defined in a `MTL` bytes.
//
// Inputs:
//
// - `data` - The raw bytes of a `MTL` file.
// - `allocator` - The allocator used to allocate data for materials.
//
// Returns:
//
// - `res` - Contains all the materials loaded from the data and a map of `MTL`
//   name to index.
// - `err` - A error that may occur while loading `MTL` files., `nil` otherwise.
load_mtl_bytes :: proc(
    data: []byte,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    res: MTL_Load_Result,
    err: Maybe(Error),
) {
    reader: bufio.Reader
    bufio.reader_init(&reader, bytes.reader_init(&bytes.Reader{}, data), allocator = allocator)
    defer bufio.reader_destroy(&reader)

    return load_mtl_reader(&reader, allocator, loc)
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

model_destroy :: proc(model: Model, allocator := context.allocator) {
    context.allocator = allocator
    delete(model.mesh.positions)
    delete(model.mesh.vertex_color)
    delete(model.mesh.normals)
    delete(model.mesh.texcoords)
    delete(model.mesh.indices)
    delete(model.mesh.face_arities)
    delete(model.name)
}

models_destroy :: proc(models: []Model, allocator := context.allocator) {
    for &m in models {
        model_destroy(m, allocator)
    }
    delete(models, allocator)
}

material_destroy :: proc(material: Material, allocator := context.allocator) {
    context.allocator = allocator
    delete(material.name)
    delete(material.ambient_texture.name)
    delete(material.diffuse_texture.name)
    delete(material.specular_texture.name)
    delete(material.normal_texture.name)
    delete(material.shininess_texture.name)
    delete(material.dissolve_texture.name)
    for param, value in material.unknown_param {
        delete(param)
        delete(value)
    }
    delete(material.unknown_param)
}

materials_destroy :: proc(materials: []Material, allocator := context.allocator) {
    for &m in materials {
        material_destroy(m, allocator)
    }
    delete(materials, allocator)
}

material_load_result_destroy :: proc(result: MTL_Load_Result, allocator := context.allocator) {
    context.allocator = allocator

    // Free all materials
    materials_destroy(result.materials)

    // Free all material map keys
    for key in result.mat_map {
        delete(key)
    }
    delete(result.mat_map)
}

destroy :: proc {
    model_destroy,
    models_destroy,
    material_destroy,
    materials_destroy,
    material_load_result_destroy,
}

Tmp_Models :: struct {
    models:   [dynamic]Model,
    pos:      [dynamic]f32,
    colors:   [dynamic]f32,
    texcoord: [dynamic]f32,
    normal:   [dynamic]f32,
    faces:    [dynamic]Face,
    name:     string,
    mat_id:   uint,
}

Tmp_Materials :: struct {
    materials: [dynamic]Material,
    mat_map:   map[string]uint,
    mtl_err:   Maybe(Error),
}

parse_obj_line :: proc(
    line: string,
    models: ^Tmp_Models,
    materials: ^Tmp_Materials,
    material_loader_info: Material_Loader_Callback_Info,
    load_options: Load_Options,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    err: Maybe(Error),
) {
    ta := context.temp_allocator
    context.allocator = allocator

    line_trimmed := strings.trim_right(line, "\r\n")
    if len(line_trimmed) == 0 {
        return
    }

    tokens := strings.fields(line_trimmed, ta)
    if len(tokens) == 0 {
        return
    }

    switch tokens[0] {
    // Ignore empty/comment line
    case "#", "": return

    // Vertex
    case "v":
        if !parse_f32_n(tokens[1:], &models.pos, 3, loc) {
            return .Position_Parse_Error
        }

        // Add vertex colors if present
        if len(tokens) > 4 {
            parse_f32_n(tokens[4:], &models.colors, 3, loc)
        }

    // Vertex texture
    case "vt":
        if !parse_f32_n(tokens[1:], &models.texcoord, 2, loc) {
            return .Texcoord_Parse_Error
        }

    // Vertex normal
    case "vn":
        if !parse_f32_n(tokens[1:], &models.normal, 3, loc) {
            return .Normal_Parse_Error
        }

    // Face
    case "f", "l":
        if !parse_face(
            tokens[1:],
            &models.faces,
            len(models.pos) / 3,
            len(models.texcoord) / 2,
            len(models.normal) / 3,
            loc,
        ) {
            return .Face_Parse_Error
        }

    // Objects and groups
    case "o", "g":
        // If we were already parsing an object then a new object name signals
        // the end of the current one, so push it onto our list of objects
        if len(models.faces) > 0 {
            mesh := export_faces(models, load_options) or_return
            append(&models.models, Model{ mesh, models.name })
        }
        name_view := tokens[1]
        if len(name_view) > 0 {
            models.name = strings.clone(name_view, allocator)
        } else {
            models.name = strings.clone("unnamed_object", allocator)
        }

    // Material
    case "mtllib":
        if material_loader_info.callback != nil {
            mtllib := tokens[1]
            mat := material_loader_info.callback(
                mtllib, material_loader_info.userdata, allocator, loc) or_return
            // Merge the loaded material lib with any currently loaded ones,
            // offsetting the indices of the appended materials by our current length
            mat_offset := uint(len(materials.materials))
            append(&materials.materials, ..mat.materials[:])
            for k, v in mat.mat_map {
                materials.mat_map[k] = v + mat_offset
            }
            delete(mat.mat_map)
            delete(mat.materials)
        } else {
            log.warn("Material loader not set")
        }

    // Use material
    case "usemtl":
        mat_name := cleanup_name(tokens[1])
        if len(mat_name) == 0 {
            err = .Material_Parse_Error
            return
        }
        if new_mat, new_mat_found := materials.mat_map[mat_name]; new_mat_found {
            // As materials are returned per-model, a new material within an object
            // has to emit a new model with the same name but different material
            if models.mat_id != new_mat && len(models.faces) > 0 {
                mesh := export_faces(models, load_options) or_return
                append(&models.models, Model{ mesh, models.name })
            }
            models.mat_id = new_mat
        } else {
            log.warnf("Object [%s] refers to unfound material: %s", models.name, mat_name)
        }
    }

    return
}

parse_mtl_line :: proc(
    line: string,
    materials: ^Tmp_Materials,
    cur_mat: ^Material,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    err: Maybe(Error),
) {
    ta := context.temp_allocator
    context.allocator = allocator

    line_trimmed := strings.trim_right(line, "\r\n")
    if len(line_trimmed) == 0 {
        return
    }

    tokens := strings.fields(line_trimmed, ta)
    if len(tokens) == 0 {
        return
    }

    switch tokens[0] {
    // Ignore empty/comment line
    case "#", "": return

    // Vertex
    case "newmtl":
        // If we were passing a material save it out to our vector
        if len(cur_mat.name) != 0 {
            materials.mat_map[cur_mat.name] = len(materials.materials)
            append(&materials.materials, cur_mat^)
        }
        cur_mat^ = {}
        cur_mat_name := strings.trim_right(line[6:], "\r\n")
        cur_mat_name = strings.trim(cur_mat_name, " ")
        if len(cur_mat_name) == 0 {
            err = .Invalid_Object_Name
            return
        }
        cur_mat.name = strings.clone(cur_mat_name, allocator)

    // Ambient
    case "Ka":
        ok: bool
        if cur_mat.ambient, ok = parse_float3(tokens[1:]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Diffuse
    case "Kd":
        ok: bool
        if cur_mat.diffuse, ok = parse_float3(tokens[1:]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Specular
    case "Ks":
        ok: bool
        if cur_mat.specular, ok = parse_float3(tokens[1:]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Shininess
    case "Ns":
        ok: bool
        if cur_mat.shininess, ok = parse_f32(tokens[1]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Optical density
    case "Ni":
        ok: bool
        if cur_mat.optical_density, ok = parse_f32(tokens[1]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Dissolve
    case "d":
        ok: bool
        if cur_mat.dissolve, ok = parse_f32(tokens[1]); !ok {
            err = .Material_Parse_Error
            return
        }

    // Ambient texture
    case "map_Ka":
        cur_mat.ambient_texture = parse_texture(line_trimmed, allocator) or_return

    // Diffuse texture
    case "map_Kd":
        cur_mat.diffuse_texture = parse_texture(line_trimmed, allocator) or_return

    // Specular texture
    case "map_Ks":
        cur_mat.specular_texture = parse_texture(line_trimmed, allocator) or_return

    // Normal texture
    case "map_Bump":
        cur_mat.normal_texture = parse_texture(line_trimmed, allocator) or_return

    // Shininess texture
    case "map_Ns":
        cur_mat.shininess_texture = parse_texture(line_trimmed, allocator) or_return

    // Normal texture
    case "bump":
        cur_mat.normal_texture = parse_texture(line_trimmed, allocator) or_return

    // Dissolve texture
    case "map_d":
        cur_mat.dissolve_texture = parse_texture(line_trimmed, allocator) or_return

    // Illumination model
    case "illum":
        illum := tokens[1]
        if len(illum) == 0 {
            err = .Material_Parse_Error
            return
        }
        if illumination_model, illum_ok := strconv.parse_int(tokens[1]); illum_ok {
            cur_mat.illumination_model = u8(illumination_model)
        } else {
            err = .Material_Parse_Error
            return
        }

    // Unknown
    case:
        if len(tokens) >= 2 {
            param_name := strings.clone(tokens[0], allocator)
            // Join remaining tokens with spaces, handling empty tokens
            param_value := strings.join(tokens[1:], " ", allocator)
            cur_mat.unknown_param[param_name] = param_value
        } else if len(tokens) == 1 {
            // Handle parameter with no value
            param_name := strings.clone(tokens[0], allocator)
            cur_mat.unknown_param[param_name] = ""
        }
    }

    return
}

parse_texture :: proc(
    line: string,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    texture: Texture,
    err: Maybe(Error),
) {
    texture.options = DEFAULT_TEXTURE_OPTIONS

    ta := context.temp_allocator
    tokens := strings.fields(line, ta, loc)

    if len(tokens) < 2 {
        err = .Material_Parse_Error
        return
    }

    remaining := tokens[1:]
    pos := 0
    n := len(remaining)

    // Parse options (all options must appear before the filename)
    for pos < n && strings.has_prefix(remaining[pos], "-") {
        opt := cleanup_name(remaining[pos])
        pos += 1 // consume the option token

        switch opt {
        case "-blendu", "-blendv", "-clamp":
            if pos >= n {
                log.errorf("Missing bool value for option %s in line:\n\t%s", opt, line)
                err = .Material_Parse_Error
                return
            }
            val := remaining[pos]
            b, ok := parse_bool(val)
            if !ok {
                log.errorf("Invalid bool value '%s' for option %s", val, opt)
                err = .Material_Parse_Error
                return
            }
            switch opt {
            case "-blendu": texture.blendu = b
            case "-blendv": texture.blendv = b
            case "-clamp":  texture.clamp  = b
            }
            pos += 1

        case "-boost":
            if pos >= n {
                log.errorf("Missing float value for -boost")
                err = .Material_Parse_Error
                return
            }
            f, ok := parse_f32(remaining[pos])
            if !ok {
                log.errorf("Invalid float value '%s' for -boost", remaining[pos])
                err = .Material_Parse_Error
                return
            }
            texture.boost = f
            pos += 1

        case "-bm":
            if pos >= n {
                log.errorf("Missing float value for -bm")
                err = .Material_Parse_Error
                return
            }
            f, ok := parse_f32(remaining[pos])
            if !ok {
                log.errorf("Invalid float value '%s' for -bm", remaining[pos])
                err = .Material_Parse_Error
                return
            }
            texture.bm = f
            pos += 1

        case "-texres":
            if pos >= n {
                log.errorf("Missing value for -texres")
                err = .Material_Parse_Error
                return
            }
            res, ok := strconv.parse_int(remaining[pos])
            if !ok {
                log.errorf("Invalid integer value '%s' for -texres", remaining[pos])
                err = .Material_Parse_Error
                return
            }
            texture.texres = res
            pos += 1

        case "-imfchan":
            if pos >= n {
                log.errorf("Missing channel value for -imfchan")
                err = .Material_Parse_Error
                return
            }
            lower := strings.to_lower(remaining[pos], ta)
            switch lower {
            case "r": texture.imfchan = .R
            case "g": texture.imfchan = .G
            case "b": texture.imfchan = .B
            case "m": texture.imfchan = .M
            case "l": texture.imfchan = .L
            case "z": texture.imfchan = .Z
            case:
                log.errorf("Invalid -imfchan value: '%s'", remaining[pos])
                err = .Material_Parse_Error
                return
            }
            pos += 1

        case "-mm":
            if pos + 1 >= n {
                log.errorf("Missing base/gain values for -mm")
                err = .Material_Parse_Error
                return
            }
            base, ok1 := parse_f32(remaining[pos])
            gain, ok2 := parse_f32(remaining[pos + 1])
            if !ok1 || !ok2 {
                log.errorf("Invalid floats for -mm: %s %s", remaining[pos], remaining[pos + 1])
                err = .Material_Parse_Error
                return
            }
            texture.mm = {base, gain}
            pos += 2

        case "-o", "-s", "-t":
            // Defaults per spec
            defaults: [3]f32 = opt == "-s" ? {1, 1, 1} : {0, 0, 0}
            values := defaults
            consumed := 0

            for consumed < 3 && pos < n {
                token := remaining[pos]
                if strings.has_prefix(token, "-") {
                    break // next option
                }
                f, ok := parse_f32(token)
                if !ok {
                    break
                }
                values[consumed] = f
                consumed += 1
                pos += 1
            }

            if consumed == 0 {
                log.errorf("Missing at least one value for option %s", opt)
                err = .Material_Parse_Error
                return
            }

            switch opt {
            case "-o": texture.o = values
            case "-s": texture.s = values
            case "-t": texture.t = values
            }

        case:
            log.errorf("Unknown texture option '%s' in line:\n\t%s", opt, line)
            err = .Material_Parse_Error
            return
        }
    }

    // Everything after options is the filename
    if pos >= n {
        log.errorf("Missing texture filename in line:\n\t%s", line)
        err = .Material_Parse_Error
        return
    }

    raw_filename := strings.join(remaining[pos:], " ", ta)
    trimmed := strings.trim_space(raw_filename)
    if len(trimmed) == 0 {
        log.errorf("Empty texture filename in line:\n\t%s", line)
        err = .Material_Parse_Error
        return
    }

    filename := trimmed
    // Basic quote stripping (handles common "my file.jpg" cases even when split)
    if len(filename) >= 2 && filename[0] == '"' && filename[len(filename) - 1] == '"' {
        filename = filename[1:len(filename) - 1]
    }

    texture.name = strings.clone(filename, allocator, loc)

    return
}

Tmp_Index_Map :: map[Vertex]u32

add_vertex :: proc(
    mesh: ^Mesh,
    index_map: ^Tmp_Index_Map,
    vert: Vertex,
    pos: []f32,
    color: []f32,
    texcoord: []f32,
    normal: []f32,
) -> (
    err: Maybe(Error),
) {
    // Check if vertex already exists in the index map
    if existing_index, found := index_map[vert]; found {
        append(&mesh.indices, existing_index)
        return
    }

    // Add new vertex
    v := vert.v

    // Validate vertex index (OBJ indices should not be MISSING_INDEX for position)
    if v == MISSING_INDEX {
        return .Face_Vertex_Out_Of_Bounds
    }

    // Check bounds and add position
    if v * 3 + 2 >= uint(len(pos)) {
        return .Face_Vertex_Out_Of_Bounds
    }

    append(&mesh.positions, pos[v * 3])
    append(&mesh.positions, pos[v * 3 + 1])
    append(&mesh.positions, pos[v * 3 + 2])

    // Add texcoord if available
    if len(texcoord) > 0 && vert.vt != MISSING_INDEX {
        vt := vert.vt
        if vt * 2 + 1 >= uint(len(texcoord)) {
            return .Face_Texcoord_Out_Of_Bounds
        }
        append(&mesh.texcoords, texcoord[vt * 2])
        append(&mesh.texcoords, texcoord[vt * 2 + 1])
    }

    // Add normal if available
    if len(normal) > 0 && vert.vn != MISSING_INDEX {
        vn := vert.vn
        if vn * 3 + 2 >= uint(len(normal)) {
            return .Face_Normal_Out_Of_Bounds
        }
        append(&mesh.normals, normal[vn * 3])
        append(&mesh.normals, normal[vn * 3 + 1])
        append(&mesh.normals, normal[vn * 3 + 2])
    }

    // Add vertex color if available
    if len(color) > 0 {
        if v * 3 + 2 >= uint(len(color)) {
            return .Face_Color_Out_Of_Bounds
        }
        append(&mesh.vertex_color, color[v * 3])
        append(&mesh.vertex_color, color[v * 3 + 1])
        append(&mesh.vertex_color, color[v * 3 + 2])
    }

    // Add new index and update map
    next := u32(len(index_map))
    append(&mesh.indices, next)
    index_map[vert] = next

    return
}

export_faces :: proc(
    models: ^Tmp_Models,
    load_options: Load_Options,
) -> (
    mesh: Mesh,
    err: Maybe(Error),
) {
    ta := context.temp_allocator

    index_map := make(Tmp_Index_Map, ta)
    mesh.material_id = models.mat_id

    pos := models.pos[:]
    color := models.colors[:]
    texcoord := models.texcoord[:]
    normal := models.normal[:]

    for &f in models.faces {
        switch &v in f {
        case Point:
            if !load_options.ignore_points {
                add_vertex(&mesh, &index_map, v, pos, color, texcoord, normal) or_return
                if load_options.triangulate {
                    add_vertex(&mesh, &index_map, v, pos, color, texcoord, normal) or_return
                    add_vertex(&mesh, &index_map, v, pos, color, texcoord, normal) or_return
                }
            } else {
                append(&mesh.face_arities, 1)
            }

        case Line:
            if !load_options.ignore_lines {
                add_vertex(&mesh, &index_map, v.x, pos, color, texcoord, normal) or_return
                add_vertex(&mesh, &index_map, v.y, pos, color, texcoord, normal) or_return
                if load_options.triangulate {
                    add_vertex(&mesh, &index_map, v.y, pos, color, texcoord, normal) or_return
                }
            } else {
                append(&mesh.face_arities, 2)
            }

        case Triangle:
            add_vertex(&mesh, &index_map, v.x, pos, color, texcoord, normal) or_return
            add_vertex(&mesh, &index_map, v.y, pos, color, texcoord, normal) or_return
            add_vertex(&mesh, &index_map, v.z, pos, color, texcoord, normal) or_return

            if !load_options.triangulate {
                append(&mesh.face_arities, 3)
            }

        case Quad:
            add_vertex(&mesh, &index_map, v.x, pos, color, texcoord, normal) or_return
            add_vertex(&mesh, &index_map, v.y, pos, color, texcoord, normal) or_return
            add_vertex(&mesh, &index_map, v.z, pos, color, texcoord, normal) or_return

            if load_options.triangulate {
                add_vertex(&mesh, &index_map, v.x, pos, color, texcoord, normal) or_return
                add_vertex(&mesh, &index_map, v.z, pos, color, texcoord, normal) or_return
                add_vertex(&mesh, &index_map, v.w, pos, color, texcoord, normal) or_return
            } else {
                add_vertex(&mesh, &index_map, v.w, pos, color, texcoord, normal) or_return
                append(&mesh.face_arities, 4)
            }

        case Polygon:
            if load_options.triangulate {
                if len(v) < 3 {
                    err = .Invalid_Polygon
                    return
                }

                a := v[0]
                b := v[1]

                for i in 2..<len(v) {
                    c := v[i]

                    add_vertex(&mesh, &index_map, a, pos, color, texcoord, normal) or_return
                    add_vertex(&mesh, &index_map, b, pos, color, texcoord, normal) or_return
                    add_vertex(&mesh, &index_map, c, pos, color, texcoord, normal) or_return

                    b = c
                }
            } else {
                for idx in v {
                    add_vertex(&mesh, &index_map, idx, pos, color, texcoord, normal) or_return
                }
                append(&mesh.face_arities, u32(len(v)))
            }
            // Free the polygon slice since it was allocated in parse_face
            delete(v)
        }
    }

    clear(&models.faces)

    return
}

parse_face_indices :: proc(
    face_str: string,
    pos_sz: uint,
    tex_sz: uint,
    norm_sz: uint,
) -> (
    indices: Vertex,
    ok: bool,
) {
    ta := context.temp_allocator

    idx := [3]uint{ MISSING_INDEX, MISSING_INDEX, MISSING_INDEX }

    // Split by '/'
    parts := strings.split(face_str, "/", ta)

    if len(parts) > 3 {
        return {}, false
    }

    for part, i in parts {
        // Skip empty strings (e.g., v//vn case)
        if len(part) == 0 {
            continue
        }

        // Parse the integer
        x, parse_ok := strconv.parse_int(part)
        if !parse_ok {
            return {}, false
        }

        // Handle relative indices (negative values)
        if x < 0 {
            switch i {
            case 0:
                idx[i] = uint(int(pos_sz) + x)
            case 1:
                idx[i] = uint(int(tex_sz) + x)
            case 2:
                idx[i] = uint(int(norm_sz) + x)
            case:
                return // Invalid number of elements
            }
        } else {
            idx[i] = uint(x - 1)
        }
    }

    indices = Vertex{
        v = idx[0],
        vt = idx[1],
        vn = idx[2],
    }

    return indices, true
}

parse_face :: proc(
    tokens: []string,
    faces: ^[dynamic]Face,
    pos_sz: uint,
    tex_sz: uint,
    norm_sz: uint,
    loc := #caller_location,
) -> bool {
    if len(tokens) == 0 {
        return false
    }

    ta := context.temp_allocator
    indices := make([dynamic]Vertex, ta)

    for token in tokens {
        res := parse_face_indices(token, pos_sz, tex_sz, norm_sz) or_return

        // Validate that at least the position index is valid
        if res.v == MISSING_INDEX {
            return false
        }

        append(&indices, res)
    }

    switch len(indices) {
    case 0:
        return false
    case 1:
        append(faces, Point(indices[0]))
    case 2:
        append(faces, Line{ indices[0], indices[1] })
    case 3:
        append(faces, Triangle{ indices[0], indices[1], indices[2] })
    case 4:
        append(faces, Quad{ indices[0], indices[1], indices[2], indices[3] })
    case:
        polygons := make([]Vertex, len(indices))
        copy(polygons[:], indices[:])
        append(faces, Polygon(polygons))
    }

    return true
}

// Parse the float information from the tokens. `tokens` is an slice over the
// float strings. Returns `false` if parsing failed.
parse_f32_n :: proc(tokens: []string, vals: ^[dynamic]f32, n: $N, loc := #caller_location) -> (ok: bool) {
    assert(n > 0, "Invalid number of values")

    initial_len := len(vals)
    values_needed := n

    for token in tokens {
        value, value_ok := strconv.parse_f32(token)
        if !value_ok {
            return
        }

        append(vals, value, loc = loc)
        values_needed -= 1

        if values_needed == 0 {
            return true
        }
    }

    // Check if we got exactly the number of values we needed
    values_parsed := len(vals) - initial_len
    if values_parsed < n {
        return
    }

    return true
}

// Parse the tokens string into a float3 slice.
parse_float3 :: proc(tokens: []string) -> (arr: [3]f32, ok: bool) {
    if len(tokens) < 3 {
        return
    }

    for i in 0 ..< 3 {
        val, val_ok := strconv.parse_f32(tokens[i])
        if !val_ok {
            return
        }
        arr[i] = val
    }

    return arr, true
}

// Parse the string into a float value.
parse_f32 :: #force_inline proc(value_str: string) -> (val: f32, ok: bool) #optional_ok {
    return strconv.parse_f32(value_str)
}

parse_bool :: proc(s: string) -> (val: bool, ok: bool) #optional_ok {
    switch s {
    case "on", "true", "1":  return true, true
    case "off", "false", "0": return false, true
    case: return
    }
}

cleanup_name :: #force_inline proc(str: string) -> string {
    out := strings.trim_right(str, "\r\n")
    out = strings.trim(out, " ")
    return out
}
