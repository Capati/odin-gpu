package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/createBindGroupLayout.spec.ts`:
// unique in-budget binding numbers,
// non-empty visibility, vertex-stage write restrictions and multisampled
// texture shape.

cts_layout_buffer :: proc(
    binding: u32,
    visibility: gpu.Shader_Stages,
    type: gpu.Buffer_Binding_Type,
    has_dynamic := false,
) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = binding,
        visibility = visibility,
        type       = gpu.Buffer_Binding_Layout{type = type, has_dynamic_offset = has_dynamic},
    }
}

cts_layout_sampler :: proc(
    binding: u32,
    visibility: gpu.Shader_Stages,
) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = binding,
        visibility = visibility,
        type       = gpu.Sampler_Binding_Layout{type = .Filtering},
    }
}

cts_layout_texture :: proc(
    binding: u32,
    visibility: gpu.Shader_Stages,
    sample_type: gpu.Texture_Sample_Type,
    dimension: gpu.Texture_View_Dimension,
    multisampled := false,
) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = binding,
        visibility = visibility,
        type       = gpu.Texture_Binding_Layout {
            sample_type    = sample_type,
            view_dimension = dimension,
            multisampled   = multisampled,
        },
    }
}

cts_layout_storage :: proc(
    binding: u32,
    visibility: gpu.Shader_Stages,
    access: gpu.Storage_Texture_Access,
    format: gpu.Texture_Format,
    dimension := gpu.Texture_View_Dimension.D2,
) -> gpu.Bind_Group_Layout_Entry {
    return {
        binding    = binding,
        visibility = visibility,
        type       = gpu.Storage_Texture_Binding_Layout {
            access         = access,
            format         = format,
            view_dimension = dimension,
        },
    }
}

cts_layout_errors :: proc(
    device: gpu.Device,
    entries: []gpu.Bind_Group_Layout_Entry,
) -> int {
    before := cts_errors()
    layout := gpu.device_create_bind_group_layout(device, {entries = entries})
    errors := cts_errors() - before
    if layout != {} {
        gpu.bind_group_layout_release(layout)
    }
    return errors
}

@(test)
cts_bind_group_layout_duplicates :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    unique := [2]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Storage),
        cts_layout_buffer(1, {.Compute}, .Storage),
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, unique[:]), false,
        "two distinct bindings")

    twice := [2]gpu.Bind_Group_Layout_Entry {
        cts_layout_buffer(0, {.Compute}, .Storage),
        cts_layout_buffer(0, {.Compute}, .Uniform),
    }
    cts_expect_outcome(t, cts_layout_errors(f.device, twice[:]), true,
        "binding 0 declared twice")
}

@(test)
cts_bind_group_layout_binding_limit :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    max := gpu.device_get_limits(f.device).max_bindings_per_bind_group
    first := [1]gpu.Bind_Group_Layout_Entry{cts_layout_buffer(0, {.Compute}, .Storage)}
    last := [1]gpu.Bind_Group_Layout_Entry{cts_layout_buffer(max - 1, {.Compute}, .Storage)}
    past := [1]gpu.Bind_Group_Layout_Entry{cts_layout_buffer(max, {.Compute}, .Storage)}
    cts_expect_outcome(t, cts_layout_errors(f.device, first[:]), false, "binding 0")
    cts_expect_outcome(t, cts_layout_errors(f.device, last[:]), false,
        "the last binding the device allows")
    cts_expect_outcome(t, cts_layout_errors(f.device, past[:]), true,
        "one binding past the budget")
}

@(test)
cts_bind_group_layout_visibility :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry

    entry[0] = cts_layout_buffer(0, {.Vertex}, .Uniform)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "uniform buffer in the vertex stage")
    entry[0] = cts_layout_sampler(0, {.Vertex})
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "sampler in the vertex stage")
    entry[0] = cts_layout_texture(0, {.Vertex}, .Float, .D2)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "sampled texture in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Vertex}, .Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "writable storage buffer in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Vertex}, .Read_Only_Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "read-only storage buffer in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Fragment}, .Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "writable storage buffer in the fragment stage")
    entry[0] = cts_layout_storage(0, {.Vertex}, .Read_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "read-only storage texture in the vertex stage")
    entry[0] = cts_layout_storage(0, {.Fragment}, .Write_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "write-only storage texture in the fragment stage")
    entry[0] = cts_layout_buffer(0, {}, .Uniform)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "entry visible from no stage")
}

@(test)
cts_bind_group_layout_vertex_buffer_type :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry

    entry[0] = cts_layout_buffer(0, {.Vertex}, .Uniform)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "uniform buffer in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Vertex}, .Read_Only_Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "read-only storage buffer in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Vertex}, .Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "storage buffer in the vertex stage")
    entry[0] = cts_layout_buffer(0, {.Vertex, .Fragment}, .Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "storage buffer in vertex and fragment")
    entry[0] = cts_layout_buffer(0, {.Fragment}, .Storage)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "storage buffer in the fragment stage")
}

@(test)
cts_bind_group_layout_vertex_storage_access :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry

    entry[0] = cts_layout_storage(0, {.Vertex}, .Read_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "read-only storage texture in the vertex stage")
    entry[0] = cts_layout_storage(0, {.Vertex}, .Write_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "write-only storage texture in the vertex stage")
    entry[0] = cts_layout_storage(0, {.Vertex}, .Read_Write, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "read-write storage texture in the vertex stage")
    entry[0] = cts_layout_storage(0, {.Vertex}, .Undefined, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "default-access storage texture in the vertex stage")
    entry[0] = cts_layout_storage(0, {.Fragment}, .Write_Only, .RGBA8_Unorm)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "write-only storage texture in the fragment stage")
}

@(test)
cts_bind_group_layout_multisampled :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    entry: [1]gpu.Bind_Group_Layout_Entry

    entry[0] = cts_layout_texture(0, {.Compute}, .Uint, .D2, true)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "multisampled 2d uint texture")
    entry[0] = cts_layout_texture(0, {.Compute}, .Float, .D2, true)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "multisampled float texture")
    entry[0] = cts_layout_texture(0, {.Compute}, .Uint, .D2_Array, true)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "multisampled 2d-array texture")
    entry[0] = cts_layout_texture(0, {.Compute}, .Uint, .D1, true)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), true,
        "multisampled 1d texture")
    entry[0] = cts_layout_texture(0, {.Compute}, .Float, .D2_Array)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "single-sample 2d-array texture")
    entry[0] = cts_layout_texture(0, {.Compute}, .Float, .D2)
    cts_expect_outcome(t, cts_layout_errors(f.device, entry[:]), false,
        "single-sample 2d texture")
}
