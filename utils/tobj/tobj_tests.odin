package tobj

// Core
import "core:mem"
import "core:path/filepath"
import "core:testing"

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

// A material loader that always fails to find anything -- used by tests
// that don't care about materials but still exercise the `mtllib`/`usemtl`
// path in the OBJ.
@(private = "file")
no_material_loader :: proc(
    filename: string,
    userdata: rawptr,
    allocator := context.allocator,
    loc := #caller_location,
) -> (MTL_Load_Result, Maybe(Error)) {
    return MTL_Load_Result{}, Error.Open_File_Failed
}

@(private = "file")
expect_no_leaks :: proc(t: ^testing.T, track: ^mem.Tracking_Allocator, loc := #caller_location) {
    if len(track.allocation_map) > 0 {
        for _, entry in track.allocation_map {
            testing.expectf(t, false,
                "leaked %d bytes, allocated at %v", entry.size, entry.location, loc = loc)
        }
    }
    if len(track.bad_free_array) > 0 {
        for entry in track.bad_free_array {
            testing.expectf(t, false, "bad free at %v", entry.location, loc = loc)
        }
    }
}

// -----------------------------------------------------------------------
// Leak detection
// -----------------------------------------------------------------------

@(test)
test_no_leaks_basic_load :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        src := "o first\n" +
            "v 0 0 0\n" +
            "v 1 0 0\n" +
            "v 0 1 0\n" +
            "vt 0 0\n" +
            "vt 1 0\n" +
            "vt 0 1\n" +
            "vn 0 0 1\n" +
            "f 1/1/1 2/2/1 3/3/1\n" +
            "o second\n" +
            "v 2 2 2\n" +
            "v 3 2 2\n" +
            "v 2 3 2\n" +
            "f 4 5 6\n"

        models, materials, mtl_err, err := load_obj_bytes(transmute([]byte)src)
        testing.expect(t, err == nil, "expected no error")
        testing.expect(t, mtl_err == nil, "expected no mtl error")

        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_with_materials :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        mtl_src := "newmtl red\n" +
            "Kd 1 0 0\n" +
            "map_Kd -blendu off wood.png\n" +
            "newmtl blue\n" +
            "Kd 0 0 1\n" +
            "custom_param foo bar\n"

        mtl_loader :: proc(
            filename: string,
            userdata: rawptr,
            allocator := context.allocator,
            loc := #caller_location,
        ) -> (MTL_Load_Result, Maybe(Error)) {
            src := cast(^string)userdata
            return load_mtl_bytes(transmute([]byte)src^, allocator, loc)
        }

        obj_src := "mtllib mats.mtl\n" +
            "v 0 0 0\n" +
            "v 1 0 0\n" +
            "v 0 1 0\n" +
            "v 2 2 0\n" +
            "v 3 2 0\n" +
            "v 2 3 0\n" +
            "usemtl red\n" +
            "f 1 2 3\n" +
            "usemtl blue\n" +
            "f 4 5 6\n"

        mtl_src_copy := mtl_src
        loader_info := Material_Loader_Callback_Info{
            callback = mtl_loader,
            userdata = &mtl_src_copy,
        }

        models, materials, mtl_err, err := load_obj_bytes(transmute([]byte)obj_src, loader_info)
        testing.expect(t, err == nil, "expected no error")
        testing.expect(t, mtl_err == nil, "expected no mtl error")

        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_on_error_path :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        // Malformed after a valid, name-bearing object -- exercises that
        // `models_destroy` (called via the `err != nil` defer inside
        // load_obj_reader) still frees everything that was allocated up to
        // the point of failure, including the cloned object name.
        src := "o first\n" +
            "v 0 0 0\n" +
            "f 1 2 3\n" // out-of-bounds indices -> Face_Vertex_Out_Of_Bounds

        models, materials, _, err := load_obj_bytes(transmute([]byte)src)
        testing.expect(t, err != nil, "expected an error")

        // The proc's own `defer if err != nil { models_destroy(...) }`
        // already ran models_destroy internally before returning, but
        // `models`/`materials` are still safe to pass here since a failed
        // load returns them as their zero value (nil slices).
        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}

// -----------------------------------------------------------------------
// v: position parsing (plain, w-scaling, vertex color)
// -----------------------------------------------------------------------

@(test)
test_v_plain_position :: proc(t: ^testing.T) {
    src := "v 1.0 2.0 3.0\n" +
        "f 1 1 1\n"

    models, materials, mtl_err, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    testing.expect_value(t, len(mesh.positions), 3)
    testing.expect_value(t, mesh.positions[0], f32(1.0))
    testing.expect_value(t, mesh.positions[1], f32(2.0))
    testing.expect_value(t, mesh.positions[2], f32(3.0))
}

@(test)
test_v_w_scales_position :: proc(t: ^testing.T) {
    // v x y z w -> position divided by w
    src := "v 2.0 4.0 6.0 2.0\n" +
        "f 1 1 1\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    testing.expect_value(t, mesh.positions[0], f32(1.0))
    testing.expect_value(t, mesh.positions[1], f32(2.0))
    testing.expect_value(t, mesh.positions[2], f32(3.0))
}

@(test)
test_v_zero_w_is_error :: proc(t: ^testing.T) {
    src := "v 1.0 2.0 3.0 0.0\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Scaling_By_Zero_Error)
}

@(test)
test_v_vertex_color :: proc(t: ^testing.T) {
    // v x y z r g b -> vertex color, position unaffected
    src := "v 1.0 2.0 3.0 0.25 0.5 0.75\n" +
        "f 1 1 1\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    testing.expect_value(t, mesh.positions[0], f32(1.0))
    testing.expect_value(t, mesh.positions[1], f32(2.0))
    testing.expect_value(t, mesh.positions[2], f32(3.0))
    testing.expect_value(t, len(mesh.vertex_color), 3)
    testing.expect_value(t, mesh.vertex_color[0], f32(0.25))
    testing.expect_value(t, mesh.vertex_color[1], f32(0.5))
    testing.expect_value(t, mesh.vertex_color[2], f32(0.75))
}

@(test)
test_v_two_trailing_values_is_error :: proc(t: ^testing.T) {
    // Neither the w-form (1 extra) nor the color form (3 extra): must error.
    src := "v 1.0 2.0 3.0 4.0 5.0\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Color_Parse_Error)
}

// -----------------------------------------------------------------------
// Triangulation
// -----------------------------------------------------------------------

@(test)
test_triangulate_quad :: proc(t: ^testing.T) {
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 1 1 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3 4\n"

    load_options := Load_Options{ triangulate = true }
    reader_buf := transmute([]byte)src

    models, materials, _, err := load_obj_bytes(reader_buf, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    // Quad triangulates to 2 triangles == 6 indices, and face_arities is
    // empty since every face ends up arity-3.
    testing.expect_value(t, len(mesh.indices), 6)
    testing.expect_value(t, len(mesh.face_arities), 0)
}

@(test)
test_no_triangulate_quad_keeps_arity :: proc(t: ^testing.T) {
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 1 1 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3 4\n"

    load_options := Load_Options{ triangulate = false }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.indices), 4)
    testing.expect_value(t, len(mesh.face_arities), 1)
    testing.expect_value(t, mesh.face_arities[0], u32(4))
}

@(test)
test_triangulate_polygon_fan :: proc(t: ^testing.T) {
    // A pentagon should fan-triangulate into 3 triangles (9 indices).
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 2 1 0\n" +
        "v 1 2 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3 4 5\n"

    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.indices), 9)
    testing.expect_value(t, len(mesh.face_arities), 0)
}

// -----------------------------------------------------------------------
// Points / lines: ignore_points / ignore_lines
// -----------------------------------------------------------------------

@(test)
test_ignore_points_discards_point_entirely :: proc(t: ^testing.T) {
    // A single-index face (`f 1`) parses to a Point face.
    src := "v 0 0 0\nf 1\n"

    load_options := Load_Options{ triangulate = false, ignore_points = true }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    // Point is ignored entirely: no vertex data, no face_arities entry.
    testing.expect_value(t, len(mesh.positions), 0)
    testing.expect_value(t, len(mesh.indices), 0)
    testing.expect_value(t, len(mesh.face_arities), 0)
}

@(test)
test_keep_points_records_arity_when_not_triangulated :: proc(t: ^testing.T) {
    src := "v 0 0 0\nf 1\n"

    load_options := Load_Options{ triangulate = false, ignore_points = false }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.positions), 3)
    testing.expect_value(t, len(mesh.indices), 1)
    testing.expect_value(t, len(mesh.face_arities), 1)
    testing.expect_value(t, mesh.face_arities[0], u32(1))
}

@(test)
test_keep_points_triangulated_becomes_degenerate_triangle :: proc(t: ^testing.T) {
    src := "v 0 0 0\nf 1\n"

    load_options := Load_Options{ triangulate = true, ignore_points = false }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    // Triangulated point duplicates to a degenerate zero-area triangle: 3
    // indices, all referencing the same (deduplicated) vertex, no arity
    // entries since triangulate implies arity-3 uniformly.
    testing.expect_value(t, len(mesh.indices), 3)
    testing.expect_value(t, len(mesh.face_arities), 0)
    testing.expect_value(t, mesh.indices[0], u32(0))
    testing.expect_value(t, mesh.indices[1], u32(0))
    testing.expect_value(t, mesh.indices[2], u32(0))
}

@(test)
test_ignore_lines_discards_line_entirely :: proc(t: ^testing.T) {
    src := "v 0 0 0\nv 1 0 0\nf 1 2\n"

    load_options := Load_Options{ triangulate = false, ignore_lines = true }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.positions), 0)
    testing.expect_value(t, len(mesh.indices), 0)
    testing.expect_value(t, len(mesh.face_arities), 0)
}

@(test)
test_keep_lines_records_arity_when_not_triangulated :: proc(t: ^testing.T) {
    src := "v 0 0 0\nv 1 0 0\nf 1 2\n"

    load_options := Load_Options{ triangulate = false, ignore_lines = false }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.positions), 6)
    testing.expect_value(t, len(mesh.indices), 2)
    testing.expect_value(t, len(mesh.face_arities), 1)
    testing.expect_value(t, mesh.face_arities[0], u32(2))
}

// -----------------------------------------------------------------------
// Normals / texcoords, shared/indexed vertices
// -----------------------------------------------------------------------

@(test)
test_normals_and_texcoords :: proc(t: ^testing.T) {
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "vt 0 0\n" +
        "vt 1 0\n" +
        "vt 0 1\n" +
        "vn 0 0 1\n" +
        "f 1/1/1 2/2/1 3/3/1\n"

    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.positions), 9)
    testing.expect_value(t, len(mesh.texcoords), 6)
    testing.expect_value(t, len(mesh.normals), 9)
    testing.expect_value(t, len(mesh.indices), 3)
}

@(test)
test_shared_vertex_indices_are_deduplicated :: proc(t: ^testing.T) {
    // Two triangles sharing an edge (4 unique vertex/vt/vn combos, 6 face
    // corners) should collapse to 4 unique entries in the index map.
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 1 1 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3\n" +
        "f 1 3 4\n"

    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj_bytes(transmute([]byte)src, load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.positions), 12) // 4 unique verts * 3
    testing.expect_value(t, len(mesh.indices), 6)     // 2 triangles * 3
}

// -----------------------------------------------------------------------
// Objects / groups splitting models
// -----------------------------------------------------------------------

@(test)
test_object_keyword_splits_models :: proc(t: ^testing.T) {
    src := "o first\n" +
        "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3\n" +
        "o second\n" +
        "v 2 2 2\n" +
        "v 3 2 2\n" +
        "v 2 3 2\n" +
        "f 4 5 6\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 2)
    testing.expect_value(t, models[0].name, "first")
    testing.expect_value(t, models[1].name, "second")
}

@(test)
test_unnamed_object_default_name :: proc(t: ^testing.T) {
    src := "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, models[0].name, "unnamed_object")
}

// -----------------------------------------------------------------------
// Materials: usemtl / material_id, and graceful mtllib failure
// -----------------------------------------------------------------------

@(test)
test_no_usemtl_leaves_material_id_nil :: proc(t: ^testing.T) {
    src := "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    _, has_mat := models[0].mesh.material_id.(uint)
    testing.expect(t, !has_mat, "expected material_id to be nil when no usemtl was given")
}

@(test)
test_missing_mtllib_does_not_abort_obj_load :: proc(t: ^testing.T) {
    src := "mtllib missing.mtl\n" +
        "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "f 1 2 3\n"

    loader_info := Material_Loader_Callback_Info{
        callback = no_material_loader,
    }

    models, materials, mtl_err, err := load_obj_bytes(transmute([]byte)src, loader_info)
    defer models_destroy(models)
    defer materials_destroy(materials)

    // The OBJ load itself must still succeed...
    testing.expect(t, err == nil, "expected the OBJ load to succeed despite a bad mtllib")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, len(materials), 0)

    // ...but the MTL failure must be surfaced to the caller.
    got_mtl_err, has_mtl_err := mtl_err.(Error)
    testing.expect(t, has_mtl_err, "expected mtl_err to be set")
    testing.expect_value(t, got_mtl_err, Error.Open_File_Failed)
}

@(test)
test_usemtl_splits_model_on_material_change :: proc(t: ^testing.T) {
    mtl_src := "newmtl red\n" +
        "Kd 1 0 0\n" +
        "newmtl blue\n" +
        "Kd 0 0 1\n"

    mtl_loader :: proc(
        filename: string,
        userdata: rawptr,
        allocator := context.allocator,
        loc := #caller_location,
    ) -> (MTL_Load_Result, Maybe(Error)) {
        src := cast(^string)userdata
        res, err := load_mtl_bytes(transmute([]byte)src^, allocator, loc)
        return res, err
    }

    obj_src := "mtllib mats.mtl\n" +
        "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "v 2 2 0\n" +
        "v 3 2 0\n" +
        "v 2 3 0\n" +
        "usemtl red\n" +
        "f 1 2 3\n" +
        "usemtl blue\n" +
        "f 4 5 6\n"

    mtl_src_copy := mtl_src
    loader_info := Material_Loader_Callback_Info{
        callback = mtl_loader,
        userdata = &mtl_src_copy,
    }

    models, materials, mtl_err, err := load_obj_bytes(transmute([]byte)obj_src, loader_info)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")
    testing.expect_value(t, len(materials), 2)

    // A material change on a fresh object with no faces yet must NOT split
    // into an extra empty model -- only the switch mid-face-accumulation
    // (here, between the two `usemtl` calls) should.
    testing.expect_value(t, len(models), 2)

    id0, ok0 := models[0].mesh.material_id.(uint)
    id1, ok1 := models[1].mesh.material_id.(uint)
    testing.expect(t, ok0 && ok1, "expected both models to have a material id")
    testing.expect_value(t, id0, uint(0)) // "red"
    testing.expect_value(t, id1, uint(1)) // "blue"
}

// -----------------------------------------------------------------------
// MTL parsing
// -----------------------------------------------------------------------

@(test)
test_mtl_basic_colors_and_scalars :: proc(t: ^testing.T) {
    src := "newmtl mymat\n" +
        "Ka 0.1 0.2 0.3\n" +
        "Kd 0.4 0.5 0.6\n" +
        "Ks 0.7 0.8 0.9\n" +
        "Ns 96.0\n" +
        "Ni 1.5\n" +
        "d 0.5\n" +
        "illum 2\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(res.materials), 1)

    mat := res.materials[0]
    testing.expect_value(t, mat.name, "mymat")
    testing.expect_value(t, mat.ambient, [3]f32{0.1, 0.2, 0.3})
    testing.expect_value(t, mat.diffuse, [3]f32{0.4, 0.5, 0.6})
    testing.expect_value(t, mat.specular, [3]f32{0.7, 0.8, 0.9})
    testing.expect_value(t, mat.shininess, f32(96.0))
    testing.expect_value(t, mat.optical_density, f32(1.5))
    testing.expect_value(t, mat.dissolve, f32(0.5))
    testing.expect_value(t, mat.illumination_model, u8(2))
}

@(test)
test_mtl_multiple_materials :: proc(t: ^testing.T) {
    src := "newmtl a\n" +
        "Kd 1 0 0\n" +
        "newmtl b\n" +
        "Kd 0 1 0\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(res.materials), 2)
    testing.expect_value(t, res.materials[0].name, "a")
    testing.expect_value(t, res.materials[1].name, "b")
    testing.expect_value(t, res.mat_map["a"], uint(0))
    testing.expect_value(t, res.mat_map["b"], uint(1))
}

@(test)
test_mtl_texture_with_options :: proc(t: ^testing.T) {
    src := "newmtl mymat\n" +
        "map_Kd -blendu off -bm 0.5 wood.png\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(res.materials), 1)

    tex := res.materials[0].diffuse_texture
    testing.expect_value(t, tex.name, "wood.png")
    testing.expect_value(t, tex.blendu, false)

    bm, bm_ok := tex.bm.(f32)
    testing.expect(t, bm_ok, "expected -bm to be set")
    testing.expect_value(t, bm, f32(0.5))
}

@(test)
test_mtl_texture_filename_with_spaces :: proc(t: ^testing.T) {
    src := "newmtl mymat\n" +
        "map_Kd my wood texture.png\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, res.materials[0].diffuse_texture.name, "my wood texture.png")
}

@(test)
test_mtl_unknown_param_stored :: proc(t: ^testing.T) {
    src := "newmtl mymat\n" +
        "Tr 0.2\n" +
        "custom_flag\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    mat := res.materials[0]
    testing.expect_value(t, mat.unknown_param["Tr"], "0.2")
    testing.expect_value(t, mat.unknown_param["custom_flag"], "")
}

@(test)
test_mtl_missing_newmtl_name_is_error :: proc(t: ^testing.T) {
    src := "newmtl \n" +
        "Kd 1 0 0\n"

    res, err := load_mtl_bytes(transmute([]byte)src)
    defer material_load_result_destroy(res)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Invalid_Object_Name)
}

// -----------------------------------------------------------------------
// Face index parsing: relative indices, malformed faces
// -----------------------------------------------------------------------

@(test)
test_face_negative_relative_indices :: proc(t: ^testing.T) {
    // Relative indices count back from the last vertex/texcoord/normal
    // parsed so far, matching -1 == most recently declared.
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "f -3 -2 -1\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, len(models[0].mesh.indices), 3)
}

@(test)
test_face_out_of_bounds_index_is_error :: proc(t: ^testing.T) {
    src := "v 0 0 0\n" +
        "f 1 2 3\n" // only 1 vertex declared, indices 2 and 3 don't exist

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Face_Vertex_Out_Of_Bounds)
}

@(test)
test_face_malformed_token_is_error :: proc(t: ^testing.T) {
    src := "v 0 0 0\n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "f 1 2 notanumber\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Face_Parse_Error)
}

// -----------------------------------------------------------------------
// Comments and blank lines are ignored
// -----------------------------------------------------------------------

@(test)
test_comments_and_blank_lines_ignored :: proc(t: ^testing.T) {
    src := "# a comment\n" +
        "\n" +
        "v 0 0 0\n" +
        "  \n" +
        "v 1 0 0\n" +
        "v 0 1 0\n" +
        "# another comment\n" +
        "f 1 2 3\n"

    models, materials, _, err := load_obj_bytes(transmute([]byte)src)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, len(models[0].mesh.positions), 9)
}

// -----------------------------------------------------------------------------
// Fixture tests
// -----------------------------------------------------------------------------

default_material_loader :: proc(
    filename: string,
    userdata: rawptr,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    res: MTL_Load_Result,
    err: Maybe(Error),
) {
    mtl_path, _ := filepath.join({"obj", filename}, allocator)
    defer delete(mtl_path, allocator)
    return load_mtl(mtl_path, allocator, loc)
}

@(test)
test_cornell_box_loads :: proc(t: ^testing.T) {
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error loading cornell_box.obj")
    testing.expect(t, mtl_err == nil, "expected both mtllib files to load successfully")

    // floor, light, ceiling, back_wall, front_wall, green_wall, red_wall,
    // short_block, tall_block -- 9 named objects.
    testing.expect_value(t, len(models), 9)

    names := [9]string{
        "floor", "light", "ceiling", "back_wall", "front_wall",
        "green_wall", "red_wall", "short_block", "tall_block",
    }
    for name, i in names {
        testing.expectf(t, models[i].name == name,
            "expected models[%d].name to be %s, got %s", i, name, models[i].name)
    }

    // white, red (cornell_box.mtl) + blue, light, green (cornell_box2.mtl)
    testing.expect_value(t, len(materials), 5)
}

@(test)
test_cornell_box_texture_filenames_with_spaces :: proc(t: ^testing.T) {
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    red := get_material_by_name(materials, "red")
    mat, has_mat := red.?
    testing.expect(t, has_mat, "expected to find material 'red'")
    if has_mat {
        testing.expect_value(t, mat.ambient_texture.name, "this ambient texture has spaces.jpg")
        testing.expect_value(t, mat.diffuse_texture.name, "this diffuse texture has spaces.jpg")
        testing.expect_value(t, mat.specular_texture.name, "this specular texture has spaces.jpg")
        testing.expect_value(t, mat.normal_texture.name, "this normal texture has spaces.jpg")
        testing.expect_value(t, mat.shininess_texture.name, "this shininess texture has spaces.jpg")
        testing.expect_value(t, mat.dissolve_texture.name, "this dissolve texture has spaces.jpg")
        testing.expect_value(t, mat.illumination_model, u8(2))
    }
}

@(test)
test_cornell_box_inline_hash_comment_does_not_break_values :: proc(t: ^testing.T) {
    // `Ka 0 0 0 #there's a comment inline` and `Ks 0 0 0 # this is a
    // comment in line` -- the trailing tokens after the numeric triple
    // must be ignored rather than causing a parse error.
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    white := get_material_by_name(materials, "white")
    mat, has_mat := white.?
    testing.expect(t, has_mat, "expected to find material 'white'")
    if has_mat {
        testing.expect_value(t, mat.ambient, [3]f32{0, 0, 0})
        testing.expect_value(t, mat.diffuse, [3]f32{1, 1, 1})
        testing.expect_value(t, mat.specular, [3]f32{0, 0, 0})
    }

    red := get_material_by_name(materials, "red")
    red_mat, has_red := red.(^Material)
    testing.expect(t, has_red, "expected to find material 'red'")
    if has_red {
        testing.expect_value(t, red_mat.specular, [3]f32{0, 0, 0})
    }
}

@(test)
test_cornell_box_crazy_unknown_param :: proc(t: ^testing.T) {
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    blue := get_material_by_name(materials, "blue")
    mat, has_mat := blue.?
    testing.expect(t, has_mat, "expected to find material 'blue'")
    if has_mat {
        val, has_val := mat.unknown_param["crazy_unknown"]
        testing.expect(t, has_val, "expected 'crazy_unknown' to be stored as an unknown param")
        testing.expect_value(t, val, "Weird stuff here")
    }
}

@(test)
test_cornell_box_map_ns_uppercase_variant :: proc(t: ^testing.T) {
    // cornell_box2.mtl's "green" material uses `map_NS` (all caps) rather
    // than `map_Ns` -- must still populate shininess_texture.
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    green := get_material_by_name(materials, "green")
    mat, has_mat := green.?
    testing.expect(t, has_mat, "expected to find material 'green'")
    if has_mat {
        testing.expect_value(t, mat.shininess_texture.name, "dummy_texture.png")
    }
}

@(test)
test_cornell_box_light_material_dissolve_and_ior :: proc(t: ^testing.T) {
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    light := get_material_by_name(materials, "light")
    mat, has_mat := light.?
    testing.expect(t, has_mat, "expected to find material 'light'")
    if has_mat {
        testing.expect_value(t, mat.ambient, [3]f32{20, 20, 20})
        testing.expect_value(t, mat.optical_density, f32(1.25))
        testing.expect_value(t, mat.dissolve, f32(0.8))
    }
}

@(test)
test_cornell_box_floor_face_counts :: proc(t: ^testing.T) {
    models, materials, mtl_err, err := load_obj("obj/cornell_box.obj", {
        callback = default_material_loader,
    })
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect(t, mtl_err == nil, "expected no mtl error")

    // floor is 3 quads, triangulated -> 6 triangles -> 18 indices.
    floor_mesh := models[0].mesh
    testing.expect_value(t, len(floor_mesh.indices), 18)
    testing.expect_value(t, len(floor_mesh.face_arities), 0)

    _, has_id := floor_mesh.material_id.?
    testing.expect(t, has_id, "expected floor to have a material id")
}

@(test)
test_triangle_fixture :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/triangle.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, models[0].name, "Triangle")
    testing.expect_value(t, len(models[0].mesh.positions), 9)
    testing.expect_value(t, len(models[0].mesh.indices), 3)
}

@(test)
test_triangle_colored_fixture :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/triangle_colored.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, len(mesh.vertex_color), 9)
    testing.expect_value(t, mesh.vertex_color[0], f32(1))
    testing.expect_value(t, mesh.vertex_color[1], f32(0))
    testing.expect_value(t, mesh.vertex_color[2], f32(0))
}

@(test)
test_triangle_scaled_fixture :: proc(t: ^testing.T) {
    // Every vertex has `w = 0.5`, so positions are doubled.
    models, materials, _, err := load_obj("obj/triangle_scaled.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    mesh := models[0].mesh

    testing.expect_value(t, mesh.positions[0], f32(0))
    testing.expect_value(t, mesh.positions[3], f32(2)) // second vertex: 1 / 0.5
}

@(test)
test_triangle_scaled_by_zero_fixture_is_error :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/triangle_scaled_by_zero.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Scaling_By_Zero_Error)
}

@(test)
test_triangle_two_additional_floats_is_error :: proc(t: ^testing.T) {
    // `v x y z 0.5 1` -- 2 trailing values, neither the w-form nor the
    // 3-value color form.
    models, materials, _, err := load_obj("obj/triangle_with_two_additional_floats.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Color_Parse_Error)
}

@(test)
test_empty_name_triangle_fixture :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/empty_name_triangle.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, models[0].name, "unnamed_object")
}

@(test)
test_invalid_index_fixture_is_error :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/invalid_index.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Face_Vertex_Out_Of_Bounds)
}

@(test)
test_lines_fixture_triangulated :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj("obj/lines.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)
    testing.expect_value(t, models[0].name, "Lines")
    testing.expect_value(t, len(materials), 0)

    mesh := models[0].mesh

    // Negative indices in the fixture resolve to a closed loop:
    // (0,1), (1,2), (2,0). Triangulated, each line becomes the zero-area
    // triangle (x, y, y). Vertex dedup suppresses only *position* data on
    // repeat visits, never the index emission, so after the first line all
    // vertices are known and are re-emitted by index alone:
    expected := [9]u32{0, 1, 1, 1, 2, 2, 2, 0, 0}
    testing.expect_value(t, len(mesh.indices), len(expected))
    for want, i in expected {
        testing.expectf(t, mesh.indices[i] == want,
            "mesh.indices[%d]: expected %d, got %d", i, want, mesh.indices[i])
    }

    // Dedup kept vertex data compact: 3 unique vertices despite 6 visits.
    testing.expect_value(t, len(mesh.positions), 9)

    // triangulate => uniform arity 3 => no face_arities entries.
    testing.expect_value(t, len(mesh.face_arities), 0)
}

@(test)
test_lines_fixture_raw :: proc(t: ^testing.T) {
    load_options := Load_Options{} // keep lines, no triangulation

    models, _, _, err := load_obj("obj/lines.obj", load_options = load_options)
    defer models_destroy(models)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    // Same loop, un-triangulated: one 2-index line each, dedup still
    // collapsing repeated vertex *data* but not index emissions.
    expected := [6]u32{0, 1, 1, 2, 2, 0}
    testing.expect_value(t, len(mesh.indices), len(expected))
    for want, i in expected {
        testing.expectf(t, mesh.indices[i] == want,
            "mesh.indices[%d]: expected %d, got %d", i, want, mesh.indices[i])
    }
    testing.expect_value(t, len(mesh.positions), 9)
    testing.expect_value(t, len(mesh.face_arities), 3)
    for arity, i in mesh.face_arities {
        testing.expectf(t, arity == 2, "face_arities[%d]: expected 2, got %d", i, arity)
    }
}

@(test)
test_lines_fixture_default_options_drops_all_lines :: proc(t: ^testing.T) {
    // DEFAULT_LOAD_OPTIONS has ignore_lines = true, so an obj made
    // entirely of lines should yield a model with an empty mesh.
    models, materials, _, err := load_obj("obj/lines.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    testing.expect_value(t, len(mesh.positions), 0)
    testing.expect_value(t, len(mesh.indices), 0)
}

@(test)
test_quad_fixture_three_objects :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj("obj/quad.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 3)
    testing.expect_value(t, models[0].name, "Quad")
    testing.expect_value(t, models[1].name, "Quad_face")
    testing.expect_value(t, models[2].name, "Tri_v_vn")
}

@(test)
test_quad_fixture_quad_object_two_triangles :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj("obj/quad.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")

    // Quad: `f 1/1 2/2 3/3` + `f 1/1 3/3 4/4` -- already two triangles as
    // written (not a single 4-vertex face), so triangulate is a no-op here:
    // 2 faces * 3 indices = 6 indices, 4 unique positions, 4 unique
    // texcoords (all sharing normal index 1).
    mesh := models[0].mesh
    testing.expect_value(t, len(mesh.indices), 6)
    testing.expect_value(t, len(mesh.positions), 12) // 4 verts * 3
    testing.expect_value(t, len(mesh.texcoords), 8)  // 4 verts * 2
}

@(test)
test_quad_fixture_quad_face_object_reuses_shared_pool :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj("obj/quad.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")

    // Quad_face: a single `f 1/1/1 2/2/1 3/3/1 4/4/1` -- a real quad this
    // time, triangulated into 2 triangles == 6 indices. It has no `v`/`vt`/
    // `vn` lines of its own, reusing the ones declared under `Quad`.
    mesh := models[1].mesh
    testing.expect_value(t, len(mesh.indices), 6)
    testing.expect_value(t, len(mesh.normals), 12) // 4 verts * 3, all normal index 1
}

@(test)
test_quad_fixture_tri_v_vn_object :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err := load_obj("obj/quad.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")

    // Tri_v_vn: `f 1//1 2//1 3//1` -- v//vn format, no texcoords.
    mesh := models[2].mesh
    testing.expect_value(t, len(mesh.indices), 3)
    testing.expect_value(t, len(mesh.texcoords), 0)
    testing.expect_value(t, len(mesh.normals), 9)
}

@(test)
test_quad_colored_merge_fixture :: proc(t: ^testing.T) {
    load_options := Load_Options{ triangulate = true }

    models, materials, _, err :=
        load_obj("obj/quad_colored_merge.obj", load_options = load_options)
    defer models_destroy(models)
    defer materials_destroy(materials)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(models), 1)

    mesh := models[0].mesh
    // 6 declared `v` lines, all 6 referenced across the two triangles with
    // distinct vt/vn combos (well, same vn but distinct v index each time)
    // -> 6 unique pool entries -> 6 * 3 = 18 floats.
    testing.expect_value(t, len(mesh.positions), 18)
    testing.expect_value(t, len(mesh.vertex_color), 18)
    testing.expect_value(t, len(mesh.indices), 6)

    // First vertex: position (0,0,0), color (1,0,0).
    testing.expect_value(t, mesh.positions[0], f32(0))
    testing.expect_value(t, mesh.positions[1], f32(0))
    testing.expect_value(t, mesh.positions[2], f32(0))
    testing.expect_value(t, mesh.vertex_color[0], f32(1))
    testing.expect_value(t, mesh.vertex_color[1], f32(0))
    testing.expect_value(t, mesh.vertex_color[2], f32(0))
}

@(test)
test_load_mtl_direct :: proc(t: ^testing.T) {
    res, err := load_mtl("obj/cornell_box.mtl")
    defer material_load_result_destroy(res)

    testing.expect(t, err == nil, "expected no error")
    testing.expect_value(t, len(res.materials), 2)
    testing.expect_value(t, res.materials[0].name, "white")
    testing.expect_value(t, res.materials[1].name, "red")
}

@(test)
test_load_mtl_missing_file_is_error :: proc(t: ^testing.T) {
    res, err := load_mtl("obj/does_not_exist.mtl")
    defer material_load_result_destroy(res)

    got_err, has_err := err.?
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Open_File_Failed)
}

@(test)
test_load_obj_missing_file_is_error :: proc(t: ^testing.T) {
    models, materials, _, err := load_obj("obj/does_not_exist.obj")
    defer models_destroy(models)
    defer materials_destroy(materials)

    got_err, has_err := err.(Error)
    testing.expect(t, has_err, "expected an error")
    testing.expect_value(t, got_err, Error.Open_File_Failed)
}

@(test)
test_no_leaks_cornell_box :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        models, materials, mtl_err, err := load_obj("obj/cornell_box.obj")
        testing.expect(t, err == nil, "expected no error")
        testing.expect(t, mtl_err == nil, "expected no mtl error")

        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_quad :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        load_options := Load_Options{ triangulate = true }
        models, materials, _, err := load_obj("obj/quad.obj", load_options = load_options)
        testing.expect(t, err == nil, "expected no error")

        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_invalid_index_error_path :: proc(t: ^testing.T) {
    // This one must fail (Face_Vertex_Out_Of_Bounds) -- exercises that the
    // error path (mesh_destroy + models_destroy defer + obj_dir cleanup +
    // tmp_materials cleanup) doesn't leak or double-free either.
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        models, materials, _, err := load_obj("obj/invalid_index.obj")
        testing.expect(t, err != nil, "expected an error")

        models_destroy(models)
        materials_destroy(materials)
    }

    expect_no_leaks(t, &track)
}
