package main

import "core:c"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

import cgltf "vendor:cgltf"
import gltf "../.."

DEFAULT_MODEL_PATH :: "examples/build/assets/models/DamagedHelmet.glb"
FLOAT_TOLERANCE :: 1e-6

fail :: proc(format: string, args: ..any) {
    fmt.eprint("FAIL: ")
    fmt.eprintfln(format, ..args)
    os.exit(1)
}

cgltf_find_attribute :: proc(primitive: ^cgltf.primitive, kind: cgltf.attribute_type, set: c.int = 0) -> ^cgltf.accessor {
    for &attribute in primitive.attributes {
        if attribute.type == kind && attribute.index == set {
            return attribute.data
        }
    }
    return nil
}

compare_floats :: proc(
    label: string,
    odin_accessor: ^gltf.Accessor,
    cgltf_accessor: ^cgltf.accessor,
) {
    if odin_accessor == nil || cgltf_accessor == nil {
        if odin_accessor != nil || cgltf_accessor != nil {
            fail("%s accessor presence differs (Odin=%v, cgltf=%v)", label, odin_accessor != nil, cgltf_accessor != nil)
        }
        fmt.printfln("%s: absent in both", label)
        return
    }
    if odin_accessor.count != int(cgltf_accessor.count) {
        fail("%s count differs (Odin=%d, cgltf=%d)", label, odin_accessor.count, cgltf_accessor.count)
    }
    component_count := int(gltf.num_components(odin_accessor.type))
    cgltf_component_count := int(cgltf.num_components(cgltf_accessor.type))
    if component_count != cgltf_component_count {
        fail("%s component count differs (Odin=%d, cgltf=%d)", label, component_count, cgltf_component_count)
    }
    value_count := odin_accessor.count * component_count
    odin_values := make([]f32, value_count, context.temp_allocator)
    cgltf_values := make([]f32, value_count, context.temp_allocator)
    odin_written := gltf.unpack_floats(odin_accessor, odin_values)
    cgltf_written := int(cgltf.accessor_unpack_floats(cgltf_accessor, raw_data(cgltf_values), uint(value_count)))
    if odin_written != value_count || cgltf_written != value_count {
        fail("%s unpack count differs (Odin=%d, cgltf=%d, expected=%d)", label, odin_written, cgltf_written, value_count)
    }
    max_difference: f32 = 0
    for i in 0 ..< value_count {
        difference := math.abs(odin_values[i] - cgltf_values[i])
        max_difference = max(max_difference, difference)
        if difference > FLOAT_TOLERANCE {
            fail(
                "%s differs at element %d component %d (Odin=%.9g, cgltf=%.9g, delta=%.9g)",
                label,
                i / component_count,
                i % component_count,
                odin_values[i],
                cgltf_values[i],
                difference,
            )
        }
    }
    fmt.printfln("%s: %d values match (max delta %.9g)", label, value_count, max_difference)
}

compare_indices :: proc(odin_accessor: ^gltf.Accessor, cgltf_accessor: ^cgltf.accessor) {
    if odin_accessor == nil || cgltf_accessor == nil {
        if odin_accessor != nil || cgltf_accessor != nil {
            fail("INDICES accessor presence differs (Odin=%v, cgltf=%v)", odin_accessor != nil, cgltf_accessor != nil)
        }
        fmt.println("INDICES: absent in both; using implicit sequential indices")
        return
    }
    if odin_accessor.count != int(cgltf_accessor.count) {
        fail("INDICES count differs (Odin=%d, cgltf=%d)", odin_accessor.count, cgltf_accessor.count)
    }
    for i in 0 ..< odin_accessor.count {
        odin_index := gltf.read_index(odin_accessor, i)
        cgltf_index := u32(cgltf.accessor_read_index(cgltf_accessor, uint(i)))
        if odin_index != cgltf_index {
            fail("INDICES differs at %d (Odin=%d, cgltf=%d)", i, odin_index, cgltf_index)
        }
    }
    fmt.printfln("INDICES: %d values match exactly", odin_accessor.count)
}

main :: proc() {
    path := DEFAULT_MODEL_PATH
    if len(os.args) > 1 {
        path = os.args[1]
    }

    cgltf_options: cgltf.options
    c_path := strings.clone_to_cstring(path, context.temp_allocator)
    c_data, c_result := cgltf.parse_file(cgltf_options, c_path)
    if c_result != .success || c_data == nil {
        fail("cgltf parse failed for %s: %v", path, c_result)
    }
    defer cgltf.free(c_data)
    if cgltf.load_buffers(cgltf_options, c_data, c_path) != .success {
        fail("cgltf buffer loading failed for %s", path)
    }

    odin_doc, odin_err := gltf.parse_file(path)
    if odin_err != .None {
        fail("custom parser failed for %s: %v", path, odin_err)
    }
    defer gltf.destroy(odin_doc)
    if err := gltf.load_buffers(odin_doc); err != .None {
        fail("custom parser buffer loading failed for %s: %v", path, err)
    }
    if validation_err := gltf.validate(odin_doc); validation_err != nil {
        fail("custom parser validation failed for %s: %v", path, validation_err.?)
    }

    if len(c_data.meshes) == 0 || len(odin_doc.meshes) == 0 ||
       len(c_data.meshes[0].primitives) == 0 || len(odin_doc.meshes[0].primitives) == 0 {
        fail("expected a first mesh primitive in %s", path)
    }
    c_primitive := &c_data.meshes[0].primitives[0]
    odin_primitive := &odin_doc.meshes[0].primitives[0]
    position := cgltf_find_attribute(c_primitive, .position)
    normal := cgltf_find_attribute(c_primitive, .normal)
    texcoord := cgltf_find_attribute(c_primitive, .texcoord)

    fmt.printfln("Comparing first mesh primitive in %s", path)
    if len(c_data.meshes) != len(odin_doc.meshes) {
        fail("mesh count differs (Odin=%d, cgltf=%d)", len(odin_doc.meshes), len(c_data.meshes))
    }
    if len(c_primitive.attributes) != len(odin_primitive.attributes) {
        fail("first primitive attribute count differs (Odin=%d, cgltf=%d)", len(odin_primitive.attributes), len(c_primitive.attributes))
    }
    if position == nil || normal == nil || texcoord == nil {
        fail("cgltf first primitive is missing POSITION, NORMAL, or TEXCOORD_0")
    }
    compare_floats("POSITION", gltf.find_accessor(odin_primitive, .Position), position)
    compare_floats("NORMAL", gltf.find_accessor(odin_primitive, .Normal), normal)
    compare_floats("TEXCOORD_0", gltf.find_accessor(odin_primitive, .Texcoord, 0), texcoord)
    compare_indices(odin_primitive.indices, c_primitive.indices)
    fmt.println("All compared accessors match.")
}
