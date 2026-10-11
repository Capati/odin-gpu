#+build !js
package gltf

// Core
import "core:encoding/base64"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:testing"
import la "core:math/linalg"

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

@(private = "file")
expect_no_leaks :: proc(t: ^testing.T, track: ^mem.Tracking_Allocator, loc := #caller_location) {
    if len(track.allocation_map) > 0 {
        for _, entry in track.allocation_map {
            testing.expectf(
                t,
                false,
                "leaked %d bytes, allocated at %v",
                entry.size,
                entry.location,
                loc = loc,
            )
        }
    }
    if len(track.bad_free_array) > 0 {
        for entry in track.bad_free_array {
            testing.expectf(t, false, "bad free at %v", entry.location, loc = loc)
        }
    }
}

// concat joins the fragments of one fixture string.
//
// This compiler only accepts `+` between constant strings, so a fixture that
// embeds a computed value -- a base64 payload, a version string, a byte length
// -- has to be assembled through the allocator.
@(private = "file")
concat :: proc(parts: ..string) -> string {
    joined, join_err := strings.concatenate(parts, context.temp_allocator)
    if join_err != nil {
        return ""
    }
    return joined
}

// int_string renders a small non-negative integer, which the fixtures need for
// their `byteLength` members.
@(private = "file")
int_string :: proc(value: int) -> string {
    buffer: [20]byte
    digits := strconv.write_int(buffer[:], i64(value), 10)
    return strings.clone(digits, context.temp_allocator)
}

// math_approx compares two floats with a tolerance, for the transform tests.
@(private = "file")
math_approx :: proc(a, b: f32) -> bool {
    difference := a - b
    if difference < 0 {
        difference = -difference
    }
    return difference < 0.0001
}

// parse_ok parses `text` and fails the test if it does not.
@(private = "file")
parse_ok :: proc(t: ^testing.T, text: string, loc := #caller_location) -> ^Document {
    document, err := parse_string(text)
    testing.expectf(t, err == .None, "parse failed: %v", err, loc = loc)
    if err != .None {
        log.errorf("parse_ok received error %v for JSON: %s", err, text)
        panic("parse_ok: parse failed")
    }
    return document
}

// parse_fails parses `text`, fails the test if it succeeds, and checks that the
// error is exactly `expected`.
@(private = "file")
parse_fails :: proc(t: ^testing.T, text: string, expected: Error, loc := #caller_location) {
    document, err := parse_string(text)
    defer destroy(document)
    if err == .None {
        testing.expectf(t, false, "expected parse to fail with %v", expected, loc = loc)
        return
    }
    testing.expectf(
        t,
        err == expected,
        "expected parse to report %v, got %v",
        expected,
        err,
        loc = loc,
    )
}

// validator_base_fixture returns a path to a copied positive fixture from the
// glTF-Validator repository's `test/base/data` corpus, checked into the
// assets submodule under models/gltf_validator (submodule checkout required).
@(private = "file")
validator_base_fixture :: proc(category, filename: string) -> string {
    path, _ := filepath.join(
        {#directory, "..", "..", "examples", "build", "assets", "models", "gltf_validator", "base", "data", category, filename},
        context.temp_allocator,
    )
    return path
}

@(private = "file")
validator_extension_fixture :: proc(extension, category, filename: string) -> string {
    path, _ := filepath.join(
        {#directory, "..", "..", "examples", "build", "assets", "models", "gltf_validator", "ext", extension, "data", category, filename},
        context.temp_allocator,
    )
    return path
}

@(private = "file")
load_validator_extension_fixture :: proc(
    t: ^testing.T,
    extension, category, filename: string,
) -> ^Document {
    path := validator_extension_fixture(extension, category, filename)
    document, parse_err := parse_file(path)
    if parse_err != .None {
        testing.expectf(t, false, "%s/%s: parse failed with %v", extension, filename, parse_err)
        panic("extension fixture parse failed")
    }
    if buffer_err := load_buffers(document); buffer_err != .None {
        destroy(document)
        testing.expectf(
            t,
            false,
            "%s/%s: buffer loading failed with %v",
            extension,
            filename,
            buffer_err,
        )
        panic("extension fixture buffer load failed")
    }
    if validation_err := validate(document); validation_err != nil {
        destroy(document)
        testing.expectf(
            t,
            false,
            "%s/%s: validation failed with %v",
            extension,
            filename,
            validation_err.?,
        )
        panic("extension fixture validation failed")
    }
    return document
}

// expect_valid checks that `validate` finds nothing wrong with `document`.
@(private = "file")
expect_valid :: proc(t: ^testing.T, document: ^Document, loc := #caller_location) {
    if validate(document) != nil {
        testing.expectf(t, false, "expected the document to validate", loc = loc)
    }
}

// expect_invalid checks that `validate` rejects `document` with exactly
// `expected`.
@(private = "file")
expect_invalid :: proc(
    t: ^testing.T,
    document: ^Document,
    expected: Error,
    loc := #caller_location,
) {
    actual, has_error := validate(document).?
    if !has_error || actual != expected {
        testing.expectf(
            t,
            false,
            "expected validate to report %v, got %v",
            expected,
            actual,
            loc = loc,
        )
    }
}

@(private = "file")
expect_unpacked_floats :: proc(t: ^testing.T, accessor: ^Accessor, expected: []f32) {
    actual := make([]f32, accessor_float_count(accessor), context.temp_allocator)
    testing.expect_value(t, unpack_floats(accessor, actual), len(expected))
    testing.expect_value(t, len(actual), len(expected))
    for i in 0 ..< min(len(actual), len(expected)) {
        testing.expectf(
            t,
            math_approx(actual[i], expected[i]),
            "accessor float %d: expected %v, got %v",
            i,
            expected[i],
            actual[i],
        )
    }
}

// data_uri wraps `payload` in a base64 `data:` URI.
@(private = "file")
data_uri :: proc(payload: []byte) -> (string, bool) {
    encoded, encode_err := base64.encode(payload, allocator = context.temp_allocator)
    if encode_err != nil {
        return "", false
    }
    joined, join_err := strings.concatenate(
        {`data:application/octet-stream;base64,`, encoded},
        context.temp_allocator,
    )
    if join_err != nil {
        return "", false
    }
    return joined, true
}

// float_payload lays `values` out as consecutive little-endian `f32`s.
@(private = "file")
float_payload :: proc(values: ..f32) -> []byte {
    bytes := make([]byte, 4 * len(values), context.temp_allocator)
    floats := transmute([]f32)bytes
    for value, i in values {
        floats[i] = value
    }
    return bytes
}

// three_positions is the 36 byte vertex buffer most of the accessor fixtures
// use: a triangle's worth of positions.
@(private = "file")
three_positions :: proc() -> []byte {
    bytes := float_payload(0, 0, 0, 1, 0, 0, 0, 1, 0)
    return bytes
}

// sparse_payload packs three base positions followed by one sparse entry:
// index 1 (u16) and a replacement VEC3 of (9, 9, 9).
@(private = "file")
sparse_payload :: proc() -> []byte {
    payload := make([]byte, 50, context.temp_allocator)
    copy(payload[:36], three_positions())
    put_u16(payload, 36, 1)
    replacement := float_payload(9, 9, 9)
    copy(payload[38:], replacement)
    return payload
}

// put_u16 writes a little-endian `u16` into `bytes`.
@(private = "file")
put_u16 :: proc(bytes: []byte, offset: int, value: u16) {
    bytes[offset + 0] = byte(value)
    bytes[offset + 1] = byte(value >> 8)
}

// put_u32 writes a little-endian `u32` into `bytes`.
@(private = "file")
put_u32 :: proc(bytes: []byte, offset: int, value: u32) {
    bytes[offset + 0] = byte(value)
    bytes[offset + 1] = byte(value >> 8)
    bytes[offset + 2] = byte(value >> 16)
    bytes[offset + 3] = byte(value >> 24)
}

// build_glb assembles a GLB container from a JSON chunk and an optional BIN
// chunk, padding both to the required 4 byte boundary.
@(private = "file")
build_glb :: proc(text: string, bin: []byte) -> []byte {
    allocator := context.temp_allocator
    length := len(text)
    json_padding := (GLB_ALIGNMENT - length % GLB_ALIGNMENT) % GLB_ALIGNMENT
    bin_length := len(bin)
    bin_padding := (GLB_ALIGNMENT - bin_length % GLB_ALIGNMENT) % GLB_ALIGNMENT

    total := GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE + length + json_padding
    if bin != nil {
        total += GLB_CHUNK_HEADER_SIZE + bin_length + bin_padding
    }

    out := make([]byte, total, allocator)
    put_u32(out, 0, GLB_MAGIC)
    put_u32(out, 4, 2)
    put_u32(out, 8, u32(total))

    put_u32(out, GLB_HEADER_SIZE, u32(length + json_padding))
    put_u32(out, GLB_HEADER_SIZE + 4, GLB_CHUNK_JSON)
    copy(out[GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE:], text)
    // The JSON chunk is padded with spaces, as the GLB 2.0 specification asks,
    // so that the result stays a valid JSON document.
    for i in 0 ..< json_padding {
        out[GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE + length + i] = ' '
    }

    if bin != nil {
        offset := GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE + length + json_padding
        put_u32(out, offset, u32(bin_length + bin_padding))
        put_u32(out, offset + 4, GLB_CHUNK_BIN)
        copy(out[offset + GLB_CHUNK_HEADER_SIZE:], bin)
    }
    return out
}

// positions_json is a document with one bufferView holding three VEC3 floats
// and one accessor over it.  `buffer` is the JSON text of the `buffers[0]`
// member.
@(private = "file")
positions_json :: proc(buffer: string) -> string {
    return concat(
        `{"asset":{"version":"2.0","generator":"test"},"buffers":[`,
        buffer,
        `],`,
        `"bufferViews":[{"buffer":0,"byteOffset":0,"byteLength":36}],`,
        `"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"}]}`,
    )
}

// -----------------------------------------------------------------------
// Asset and version
// -----------------------------------------------------------------------

@(test)
test_minimal_document :: proc(t: ^testing.T) {
    document := parse_ok(t, `{"asset":{"version":"2.0","generator":"unit test"}}`)
    defer destroy(document)

    testing.expect_value(t, document.asset.version, "2.0")
    testing.expect_value(t, document.asset.generator, "unit test")
    testing.expect_value(t, document.asset.copyright, "")
    testing.expect_value(t, document.file_type, File_Type.Gltf)
    testing.expect_value(t, document.scene, nil)
    // Every collection exists, just empty.
    testing.expect_value(t, len(document.nodes), 0)
    testing.expect_value(t, document.extras.data, "")
}

@(test)
test_version_1_is_legacy :: proc(t: ^testing.T) {
    // A float comparison against 2 reaches this answer but accepts "1.10"
    // as 1.1 while also accepting "2.0-beta" by accident.
    parse_fails(t, `{"asset":{"version":"1.0"}}`, .Legacy_Gltf)
}

@(test)
test_version_2_x_is_accepted :: proc(t: ^testing.T) {
    versions := []string{"2.0", "2", "2.1", "2.42"}
    for version in versions {
        document := parse_ok(t, concat(concat(`{"asset":{"version":"`, version, `"}}`)))
        destroy(document)
    }
}

@(test)
test_version_3_is_rejected :: proc(t: ^testing.T) {
    // The data model here is 2.0's, so a 3.x document would be misread rather
    // than understood.
    parse_fails(t, `{"asset":{"version":"3.0"}}`, .Invalid_Gltf)
}

@(test)
test_missing_version_is_rejected :: proc(t: ^testing.T) {
    parse_fails(t, `{"asset":{}}`, .Invalid_Gltf)
    parse_fails(t, `{}`, .Invalid_Gltf)
}

@(test)
test_malformed_json_is_reported_as_json :: proc(t: ^testing.T) {
    parse_fails(t, `not json at all`, .Invalid_Json)
}

@(test)
test_wrong_member_type_is_reported_as_schema :: proc(t: ^testing.T) {
    // Well formed JSON that does not match the schema is a different failure
    // from JSON that does not parse.
    parse_fails(t, `{"asset":{"version":"2.0"},"nodes":[{"children":[0,"x"]}]}`, .Invalid_Schema)
}

@(test)
test_out_of_range_index_is_rejected :: proc(t: ^testing.T) {
    parse_fails(
        t,
        `{"asset":{"version":"2.0"},"meshes":[{"primitives":[{"attributes":{"POSITION":7}}]}]}`,
        .Invalid_Gltf,
    )
}

@(test)
test_unknown_primitive_mode_is_rejected :: proc(t: ^testing.T) {
    parse_fails(
        t,
        `{"asset":{"version":"2.0"},"meshes":[{"primitives":[{"mode":99,"attributes":{}}]}]}`,
        .Invalid_Gltf,
    )
}

@(test)
test_primitive_mode_zero_maps_to_points :: proc(t: ^testing.T) {
    // glTF's wire value 0 is POINTS. Primitive_Mode.Invalid is an internal
    // sentinel; its ordinal does not change the explicit wire-value mapping.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` + `"meshes":[{"primitives":[{"mode":0,"attributes":{}}]}]}`,
    )
    defer destroy(document)
    testing.expect_value(t, document.meshes[0].primitives[0].mode, Primitive_Mode.Points)
}

// -----------------------------------------------------------------------
// Defaults and ordering
// -----------------------------------------------------------------------

@(test)
test_defaults_follow_the_schema :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"samplers":[{}],` +
        `"materials":[{}],` +
        `"meshes":[{"primitives":[{"attributes":{"POSITION":0}}],"weights":[0.5]}],` +
        `"accessors":[{"componentType":5126,"count":1,"type":"VEC3"}],` +
        `"nodes":[{}]}`,
    )
    defer destroy(document)

    sampler := &document.samplers[0]
    testing.expect_value(t, sampler.mag_filter, Filter_Type.Undefined)
    testing.expect_value(t, sampler.min_filter, Filter_Type.Undefined)
    testing.expect_value(t, sampler.wrap_s, Wrap_Mode.Repeat)
    testing.expect_value(t, sampler.wrap_t, Wrap_Mode.Repeat)

    material := &document.materials[0]
    testing.expect_value(t, material.alpha_mode, Alpha_Mode.Opaque)
    testing.expect_value(t, material.alpha_cutoff, 0.5)
    testing.expect_value(t, material.pbr.base_color_factor, [4]f32{1, 1, 1, 1})
    testing.expect_value(t, material.pbr.metallic_factor, 1.0)
    testing.expect_value(t, material.pbr.roughness_factor, 1.0)
    testing.expect_value(t, material.emissive_factor, [3]f32{0, 0, 0})

    // `mode` defaults to TRIANGLES.
    testing.expect_value(t, document.meshes[0].primitives[0].mode, Primitive_Mode.Triangles)
    // An unmentioned scale is the identity.
    testing.expect_value(t, document.nodes[0].scale, [3]f32{1, 1, 1})
    testing.expect_value(t, document.nodes[0].has_scale, false)
}

@(test)
test_attribute_semantics_are_ordered :: proc(t: ^testing.T) {
    // The attributes come out of a JSON object, whose iteration order is
    // unspecified, so they are sorted by semantic name to keep a document's
    // primitive layout reproducible from one run to the next.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[` +
        `{"componentType":5126,"count":1,"type":"VEC4"},` +
        `{"componentType":5126,"count":1,"type":"VEC3"},` +
        `{"componentType":5126,"count":1,"type":"VEC3"}],` +
        `"meshes":[{"primitives":[{"attributes":` +
        `{"TEXCOORD_0":1,"POSITION":2,"NORMAL":0}}]}]}`,
    )
    defer destroy(document)

    attributes := document.meshes[0].primitives[0].attributes
    testing.expect_value(t, len(attributes), 3)
    testing.expect_value(t, attributes[0].type, Attribute_Type.Normal)
    testing.expect_value(t, attributes[1].type, Attribute_Type.Position)
    testing.expect_value(t, attributes[2].type, Attribute_Type.Texcoord)
    testing.expect_value(t, attributes[2].index, 0)
    testing.expect(t, attributes[0].data == &document.accessors[0])
    testing.expect(t, attributes[1].data == &document.accessors[2])
    testing.expect(t, attributes[2].data == &document.accessors[1])
}

@(test)
test_texcoord_set_index_is_parsed :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[{"componentType":5126,"count":1,"type":"VEC2"}],` +
        `"meshes":[{"primitives":[{"attributes":{"TEXCOORD_3":0}}]}]}`,
    )
    defer destroy(document)

    primitive := &document.meshes[0].primitives[0]
    attribute := primitive.attributes[0]
    testing.expect_value(t, attribute.type, Attribute_Type.Texcoord)
    testing.expect_value(t, attribute.index, 3)
    testing.expect(t, find_accessor(primitive, .Texcoord, 3) != nil)
    testing.expect(t, find_accessor(primitive, .Texcoord, 0) == nil)
}

// -----------------------------------------------------------------------
// Buffers: data URIs
// -----------------------------------------------------------------------

@(test)
test_data_uri_buffer_is_decoded :: proc(t: ^testing.T) {
    payload := three_positions()
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(t, concat(positions_json(concat(`{"byteLength":36,"uri":"`, uri, `"}`))))
    defer destroy(document)

    testing.expect_value(t, document.buffers[0].size, 36)
    // Nothing is fetched until the caller asks for it.
    testing.expect(t, document.buffers[0].data == nil)

    testing.expect_value(t, load_buffers(document), Error.None)
    testing.expect_value(t, len(document.buffers[0].data), 36)
    testing.expect_value(t, len(document.buffer_views[0].data), 36)

    out: [3]f32
    testing.expect(t, read_float(&document.accessors[0], 1, out[:]))
    testing.expect_value(t, out, [3]f32{1, 0, 0})
}

@(test)
test_base64_padding_is_accepted :: proc(t: ^testing.T) {
    // One and two leftover bytes both produce `=` padding, which must not be
    // treated as an invalid character: the whole buffer would be rejected.
    lengths := []int{1, 2, 3, 4, 5}
    for length in lengths {
        payload := three_positions()[:length]
        uri, ok := data_uri(payload)
        testing.expect(t, ok)

        declaration := concat(`{"byteLength":`, int_string(length), `,"uri":"`, uri, `"}`)
        document := parse_ok(
            t,
            concat(concat(`{"asset":{"version":"2.0"},"buffers":[`, declaration, `]}`)),
        )
        testing.expectf(
            t,
            load_buffers(document) == Error.None,
            "expected the padded payload of %d bytes to decode",
            length,
        )
        destroy(document)
    }
}

@(test)
test_plain_data_uri_buffer_is_decoded :: proc(t: ^testing.T) {
    // The non-base64 form is percent-encoded, not base64.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":4,"uri":"data:application/octet-stream,%00%01%02%03"}]}`,
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.None)
    expected := [4]byte{0, 1, 2, 3}
    testing.expect_value(t, len(document.buffers[0].data), len(expected))
    for want, i in expected {
        testing.expectf(
            t,
            document.buffers[0].data[i] == want,
            "byte %d: expected %d, got %d",
            i,
            want,
            document.buffers[0].data[i],
        )
    }
}

@(test)
test_truncated_buffer_is_reported :: proc(t: ^testing.T) {
    // Taking exactly `byteLength` bytes without comparing counts reads past
    // a short payload. The two are always compared.
    payload := three_positions()[:8]
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(t, concat(positions_json(concat(`{"byteLength":36,"uri":"`, uri, `"}`))))
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.Data_Too_Short)
}

@(test)
test_relative_buffer_without_a_base_is_unknown :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` + `"buffers":[{"byteLength":36,"uri":"model.bin"}]}`,
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.Unknown_Format)
}

// Used in `recording_reader` to keeps its notes in.  The hook gets
// it back through the `user_data` argument rather than closing over it, which
// keeps it a plain top level procedure.
@(private = "file")
Loader_State :: struct {
    payload:   []byte,
    requested: string,
}

@(private = "file")
recording_reader :: proc(path: string, user_data: rawptr) -> ([]byte, Error) {
    state := cast(^Loader_State)user_data
    state.requested = path
    return state.payload, .None
}

@(test)
test_read_file_hook_resolves_a_relative_uri :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":36,"uri":"sub/geometry%20data.bin"}]}`,
    )
    defer destroy(document)

    state := Loader_State {
        payload = three_positions(),
    }
    options := Options {
        read_file = recording_reader,
        user_data = rawptr(&state),
    }

    testing.expect_value(t, load_buffers(document, options), Error.None)
    // The percent escape is decoded, and the hook sees the relative URI.
    testing.expect_value(t, state.requested, "sub/geometry data.bin")
    testing.expect_value(t, len(document.buffers[0].data), 36)
}

@(test)
test_buffer_uri_with_a_scheme_is_left_to_the_caller :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":36,"uri":"https://example.invalid/model.bin"}]}`,
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.Unknown_Format)
}

// -----------------------------------------------------------------------
// GLB
// -----------------------------------------------------------------------

@(test)
test_glb_bin_chunk_is_buffer_zero :: proc(t: ^testing.T) {
    payload := three_positions()
    glb := build_glb(positions_json(`{"byteLength":36}`), payload)

    document, err := parse(glb)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)

    testing.expect_value(t, document.file_type, File_Type.Glb)
    testing.expect_value(t, len(document.bin), len(payload))

    testing.expect_value(t, load_buffers(document), Error.None)
    // The buffer's payload is a view into the BIN chunk, not a copy of it.
    testing.expect_value(t, len(document.buffers[0].data), len(payload))
    testing.expect_value(t, document.buffers[0].uri, "")

    out: [3]f32
    testing.expect(t, read_float(&document.accessors[0], 2, out[:]))
    testing.expect_value(t, out, [3]f32{0, 1, 0})
}

@(test)
test_glb_without_a_bin_chunk_leaves_the_buffer_empty :: proc(t: ^testing.T) {
    glb := build_glb(positions_json(`{"byteLength":36}`), nil)
    document, err := parse(glb)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)

    testing.expect_value(t, len(document.bin), 0)
    testing.expect_value(t, load_buffers(document), Error.None)
    testing.expect(t, document.buffers[0].data == nil)
}

@(test)
test_glb_bad_magic_is_invalid_json :: proc(t: ^testing.T) {
    glb := build_glb(`{"asset":{"version":"2.0"}}`, nil)
    put_u32(glb, 0, 0xDEADBEEF)

    document, err := parse(glb, {file_type = .Glb})
    defer destroy(document)
    testing.expect_value(t, err, Error.Unknown_Format)
}

@(test)
test_glb_version_1_is_legacy :: proc(t: ^testing.T) {
    glb := build_glb(`{"asset":{"version":"2.0"}}`, nil)
    put_u32(glb, 4, 1)

    document, err := parse(glb)
    defer destroy(document)
    testing.expect_value(t, err, Error.Legacy_Gltf)
}

@(test)
test_glb_unaligned_chunk_length_is_rejected :: proc(t: ^testing.T) {
    // The GLB 2.0 specification requires every chunk length to be a multiple
    // of 4. Reading the next chunk header from wherever the JSON chunk ends
    // misreads a file that violates this instead of refusing it.
    text := `{"asset":{"version":"2.0"}}`
    glb := build_glb(text, nil)
    put_u32(glb, GLB_HEADER_SIZE, u32(len(text)))

    document, err := parse(glb)
    defer destroy(document)
    testing.expect_value(t, err, Error.Invalid_Gltf)
}

@(test)
test_glb_unknown_chunk_is_skipped :: proc(t: ^testing.T) {
    // The specification requires a client to ignore chunks it does not know;
    // they are skipped.
    payload := three_positions()
    text := positions_json(`{"byteLength":36}`)
    json_length := len(text)
    json_padding := (GLB_ALIGNMENT - json_length % GLB_ALIGNMENT) % GLB_ALIGNMENT
    extra_length := 4

    total :=
        GLB_HEADER_SIZE +
        GLB_CHUNK_HEADER_SIZE +
        json_length +
        json_padding +
        GLB_CHUNK_HEADER_SIZE +
        extra_length +
        GLB_CHUNK_HEADER_SIZE +
        len(payload)

    glb := make([]byte, total, context.temp_allocator)
    put_u32(glb, 0, GLB_MAGIC)
    put_u32(glb, 4, 2)
    put_u32(glb, 8, u32(total))
    put_u32(glb, GLB_HEADER_SIZE, u32(json_length + json_padding))
    put_u32(glb, GLB_HEADER_SIZE + 4, GLB_CHUNK_JSON)
    copy(glb[GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE:], text)
    for i in 0 ..< json_padding {
        glb[GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE + json_length + i] = ' '
    }

    // An unrecognised chunk between the two real ones.
    offset := GLB_HEADER_SIZE + GLB_CHUNK_HEADER_SIZE + json_length + json_padding
    put_u32(glb, offset, u32(extra_length))
    put_u32(glb, offset + 4, 0x12345678)
    offset += GLB_CHUNK_HEADER_SIZE + extra_length

    put_u32(glb, offset, u32(len(payload)))
    put_u32(glb, offset + 4, GLB_CHUNK_BIN)
    copy(glb[offset + GLB_CHUNK_HEADER_SIZE:], payload)

    document, err := parse(glb)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    out: [3]f32
    testing.expect(t, read_float(&document.accessors[0], 0, out[:]))
    testing.expect_value(t, out, [3]f32{0, 0, 0})
}

// -----------------------------------------------------------------------
// Accessors
// -----------------------------------------------------------------------

@(test)
test_accessor_layout_and_stride :: proc(t: ^testing.T) {
    uri, ok := data_uri(three_positions())
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":36,"uri":"`,
                uri,
                `"}],`,
                // A stride of 16 for a 12 byte element makes the two views overlap,
                // which is legal and is what an interleaved vertex buffer looks like.
                `"bufferViews":[{"buffer":0,"byteLength":36,"byteStride":16}],`,
                `"accessors":[`,
                `{"bufferView":0,"componentType":5126,"count":2,"type":"VEC3"},`,
                `{"bufferView":0,"componentType":5126,"count":1,"type":"VEC3"}]}`,
            ),
        ),
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.None)
    testing.expect_value(t, document.accessors[0].stride, 16)
    // The view's explicit byteStride applies to both accessors.
    testing.expect_value(t, document.accessors[1].stride, 16)
    testing.expect_value(t, element_size(.Vec3, .Float), 12)
    testing.expect_value(t, num_components(.Vec3), 3)
    testing.expect_value(t, accessor_float_count(&document.accessors[0]), 6)
}

@(test)
test_accessor_index_out_of_range :: proc(t: ^testing.T) {
    uri, ok := data_uri(three_positions())
    testing.expect(t, ok)

    declaration := concat(`{"byteLength":36,"uri":"`, uri, `"}`)
    text := positions_json(declaration)
    document := parse_ok(t, text)
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    out: [3]f32
    testing.expect(t, !read_float(&document.accessors[0], 3, out[:]))
    testing.expect(t, !read_float(&document.accessors[0], -1, out[:]))
    // A destination that is too small is refused rather than written past.
    testing.expect(t, !read_float(&document.accessors[0], 0, out[:2]))
}

@(test)
test_normalized_integer_components :: proc(t: ^testing.T) {
    payload := make([]byte, 8, context.temp_allocator)
    payload[0] = 0x80 // -128 as an i8
    payload[1] = 0xFF // -1 as an i8, the second half of the VEC2
    put_u16(payload, 2, 0x8000) // -32768 as an i16

    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":8,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":8}],`,
                `"accessors":[`,
                `{"bufferView":0,"componentType":5120,"count":1,"type":"VEC2","normalized":true},`,
                `{"bufferView":0,"byteOffset":2,"componentType":5122,"count":1,"type":"SCALAR","normalized":true}]}`,
            ),
        ),
    )
    defer destroy(document)

    // Vectors have packed components; only matrix columns are padded.  The
    // second accessor starts directly after the two-byte VEC2.
    testing.expect_value(t, load_buffers(document), Error.None)
    testing.expect_value(t, element_size(.Vec2, .Byte), 2)

    out: [2]f32
    testing.expect(t, read_float(&document.accessors[0], 0, out[:]))
    testing.expect_value(t, out, [2]f32{-1.0, f32(-1) / 127.0})

    // -32768 normalized is clamped to -1.
    scalar: [1]f32
    testing.expect(t, read_float(&document.accessors[1], 0, scalar[:]))
    testing.expect_value(t, scalar[0], -1.0)

}

@(test)
test_mat3_of_bytes_uses_column_padding :: proc(t: ^testing.T) {
    // A MAT3 of UNSIGNED_BYTE is three columns of three bytes, each padded out
    // to four, which makes an element 12 bytes rather than 9.
    payload := make([]byte, 12, context.temp_allocator)
    for i in 0 ..< 12 {
        // Byte 3, 7 and 11 are column padding and carry no value.
        payload[i] = byte(i + 1)
    }

    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":12,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":12}],`,
                `"accessors":[{"bufferView":0,"componentType":5121,"count":1,"type":"MAT3"}]}`,
            ),
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    testing.expect_value(t, element_size(.Mat3, .Unsigned_Byte), 12)
    out: [9]f32
    testing.expect(t, read_float(&document.accessors[0], 0, out[:]))
    expected := [9]f32{1, 2, 3, 5, 6, 7, 9, 10, 11}
    for want, i in expected {
        testing.expectf(t, out[i] == want, "out[%d]: expected %v, got %v", i, want, out[i])
    }
}

@(test)
test_mat2_of_bytes_uses_column_padding :: proc(t: ^testing.T) {
    payload := make([]byte, 8, context.temp_allocator)
    payload[0] = 1
    payload[1] = 2
    payload[4] = 3 // bytes 2-3 are column padding
    payload[5] = 4

    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":8,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":8}],`,
                `"accessors":[{"bufferView":0,"componentType":5121,"count":1,"type":"MAT2"}]}`,
            ),
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    testing.expect_value(t, element_size(.Mat2, .Unsigned_Byte), 8)
    out: [4]f32
    testing.expect(t, read_float(&document.accessors[0], 0, out[:]))
    testing.expect_value(t, out, [4]f32{1, 2, 3, 4})
}

@(test)
test_sparse_accessor_overlay :: proc(t: ^testing.T) {
    // 36 bytes of base VEC3 data, then one u16 sparse index, then one VEC3
    // sparse value.
    payload := sparse_payload()
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":50,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[`,
                `
{"buffer":0,"byteOffset":0,"byteLength":36},`,
                `{"buffer":0,"byteOffset":36,"byteLength":2},`,
                `{"buffer":0,"byteOffset":38,"byteLength":12}],`,
                `"accessors":[`,
                `{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"},`,
                `{"componentType":5126,"count":3,"type":"VEC3","sparse":{"count":1,`,
                `
"indices":{"bufferView":1,"componentType":5123},`,
                `
"values":{"bufferView":2}}}]}`,
            ),
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)

    base := &document.accessors[0]
    sparse := &document.accessors[1]
    testing.expect_value(t, base.has_sparse, false)
    testing.expect_value(t, sparse.has_sparse, true)

    // The overlay replaces element 1 and leaves the others alone.
    out: [3]f32
    testing.expect(t, read_float(sparse, 1, out[:]))
    testing.expect_value(t, out, [3]f32{9, 9, 9})
    testing.expect(t, read_float(sparse, 0, out[:]))
    testing.expect_value(t, out, [3]f32{0, 0, 0})
    testing.expect(t, read_float(sparse, 2, out[:]))
    testing.expect_value(t, out, [3]f32{0, 0, 0})

    // The accessor has no bufferView, so its base reads as zeros and the whole
    // thing has to come out of the overlay.
    unpacked := make([]f32, 9, context.temp_allocator)
    testing.expect_value(t, unpack_floats(sparse, unpacked), 9)
    testing.expect_value(t, unpacked[0], 0.0)
    testing.expect_value(t, unpacked[3], 9.0)
    testing.expect_value(t, unpacked[4], 9.0)
}

@(test)
test_sparse_unpack_uses_packed_values_stride :: proc(t: ^testing.T) {
    // Sparse values use packed element size, not the byteStride on the
    // accessor's unrelated base bufferView (see issues #295/#304).
    payload := make([]byte, 54, context.temp_allocator)
    indices_offset := 28
    values_offset := 30
    put_u16(payload, 24, 0) // bytes 24-27 finish the second base stride slot
    payload[indices_offset] = 0
    payload[indices_offset + 1] = 1
    replacement := float_payload(1, 2, 3, 4, 5, 6)
    copy(payload[values_offset:], replacement)
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":54,"uri":"`,
            uri,
            `"}],`,
            `"bufferViews":[{"buffer":0,"byteLength":28,"byteStride":16},`,
            `{"buffer":0,"byteOffset":28,"byteLength":2},`,
            `{"buffer":0,"byteOffset":30,"byteLength":24}],`,
            `"accessors":[{"bufferView":0,"componentType":5126,"count":2,"type":"VEC3",`,
            `"sparse":{"count":2,"indices":{"bufferView":1,"componentType":5121},`,
            `"values":{"bufferView":2}}}]}`,
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)

    expect_unpacked_floats(t, &document.accessors[0], []f32{1, 2, 3, 4, 5, 6})
}

@(test)
test_sparse_oob_index_is_rejected_and_unpack_is_bounded :: proc(t: ^testing.T) {
    // A malformed sparse index must not write past the output array even
    // if the caller unpacks before validating (see issue #292).
    payload := make([]byte, 5, context.temp_allocator)
    payload[0] = 4 // accessor.count is only 1
    copy(payload[1:], float_payload(9))
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":5,"uri":"`,
            uri,
            `"}],`,
            `"bufferViews":[{"buffer":0,"byteLength":1},`,
            `{"buffer":0,"byteOffset":1,"byteLength":4}],`,
            `"accessors":[{"componentType":5126,"count":1,"type":"SCALAR",`,
            `"sparse":{"count":1,"indices":{"bufferView":0,"componentType":5121},`,
            `"values":{"bufferView":1}}}]}`,
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    unpacked: [1]f32
    testing.expect_value(t, unpack_floats(&document.accessors[0], unpacked[:]), 1)
    testing.expect_value(t, unpacked[0], 0.0)
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_sparse_count_overflow_rejected_without_iteration :: proc(t: ^testing.T) {
    // Sparse buffer extents must be checked without multiplying
    // attacker-controlled counts by component size (see issue #287).
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":4}],`,
            `"bufferViews":[{"buffer":0,"byteLength":4},{"buffer":0,"byteLength":4}],`,
            `"accessors":[{"componentType":5126,"count":1,"type":"SCALAR",`,
            `"sparse":{"count":4611686018427387904,`,
            `"indices":{"bufferView":0,"componentType":5125},`,
            `"values":{"bufferView":1}}}]}`,
        ),
    )
    defer destroy(document)
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_dense_accessor_count_overflow_rejected :: proc(t: ^testing.T) {
    // A dense accessor extent that would overflow a machine-size
    // multiplication must fail validation instead of wrapping to a small
    // buffer requirement (see issue #301).
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":12,"uri":"data:application/octet-stream;base64,AAAAAAAAAAAAAAAA"}],`,
            `"bufferViews":[{"buffer":0,"byteLength":12}],`,
            `"accessors":[{"bufferView":0,"componentType":5126,`,
            `"count":4611686018427387904,"type":"VEC3"}]}`,
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    testing.expect_value(t, accessor_float_count(&document.accessors[0]), 0)
    out: [3]f32
    testing.expect(t, !read_float(&document.accessors[0], 500, out[:]))
    testing.expect_value(t, unpack_floats(&document.accessors[0], out[:]), 3)
    testing.expect_value(t, out, [3]f32{0, 0, 0})
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_sparse_declared_view_cannot_escape_short_buffer :: proc(t: ^testing.T) {
    // A huge declared sparse bufferView over a tiny loaded buffer must be
    // rejected before reading the sparse index data (see issue #299).
    count_text :: "2147483647"
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":1,"uri":"data:application/octet-stream;base64,AA=="}],`,
            `"bufferViews":[{"buffer":0,"byteLength":8589934588},`,
            `{"buffer":0,"byteLength":25769803764}],`,
            `"accessors":[{"componentType":5126,"count":4,"type":"VEC3",`,
            `"sparse":{"count":`,
            count_text,
            `,"indices":{"bufferView":0,"componentType":5125},`,
            `"values":{"bufferView":1}}}]}`,
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_unpack_indices :: proc(t: ^testing.T) {
    payload := make([]byte, 12, context.temp_allocator)
    put_u16(payload, 0, 2)
    put_u16(payload, 2, 0)
    put_u16(payload, 4, 1)
    put_u16(payload, 6, 2)
    put_u16(payload, 8, 1)
    put_u16(payload, 10, 0)

    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":12,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":12}],`,
                `"accessors":[{"bufferView":0,"componentType":5123,"count":6,"type":"SCALAR"}]}`,
            ),
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)

    indices := make([]u32, 6, context.temp_allocator)
    testing.expect_value(t, unpack_indices(&document.accessors[0], indices), 6)
    expected := [6]u32{2, 0, 1, 2, 1, 0}
    for want, i in expected {
        testing.expectf(
            t,
            indices[i] == want,
            "indices[%d]: expected %d, got %d",
            i,
            want,
            indices[i],
        )
    }
    // A destination smaller than the accessor is filled as far as it goes.
    testing.expect_value(t, unpack_indices(&document.accessors[0], indices[:2]), 2)
    // A nil destination only reports the count.
    testing.expect_value(t, unpack_indices(&document.accessors[0], nil), 6)
}

// -----------------------------------------------------------------------
// Node graph and transforms
// -----------------------------------------------------------------------

@(test)
test_parent_links_and_world_transform :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"scenes":[{"nodes":[0]}],"scene":0,`,
            `"nodes":[`,
            `
{"name":"parent","translation":[10,0,0],"rotation":[0,0,0.70710678,0.70710678],"children":[1]},`,
            `{"name":"child","translation":[1,0,0]}]}`,
        ),
    )
    defer destroy(document)

    parent := &document.nodes[0]
    child := &document.nodes[1]
    testing.expect(t, child.parent == parent)
    testing.expect_value(t, parent.parent, nil)
    testing.expect(t, document.scene.nodes[0] == parent)
    expect_valid(t, document)

    local := node_transform_local(child)
    testing.expect_value(t, local[3][0], 1.0)
    testing.expect_value(t, local[3][1], 0.0)
    testing.expect_value(t, local[0][0], 1.0)

    // world = parent * local, so the child's translation is turned by the
    // parent's rotation before the parent's own translation is added.  Adding
    // only the parent's translation to the child's is wrong for
    // any parent that rotates or scales.
    world := node_transform_world(child)
    testing.expectf(t, math_approx(world[3][0], 10.0), "world x: got %v", world[3][0])
    testing.expectf(t, math_approx(world[3][1], 1.0), "world y: got %v", world[3][1])
    testing.expectf(t, math_approx(world[3][2], 0.0), "world z: got %v", world[3][2])

    // Nothing transforms the root itself.
    parent_world := node_transform_world(parent)
    testing.expect_value(t, parent_world[3][0], 10.0)
}

@(test)
test_node_matrix_wins_over_trs :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"nodes":[{"matrix":[`,
            `
2,0,0,0, 0,3,0,0, 0,0,4,0, 5,6,7,1],`,
            `"translation":[99,99,99]}]}`,
        ),
    )
    defer destroy(document)

    testing.expect_value(t, document.nodes[0].has_matrix, true)
    local := node_transform_local(&document.nodes[0])
    testing.expect_value(t, local[0][0], 2.0)
    testing.expect_value(t, local[1][1], 3.0)
    testing.expect_value(t, local[2][2], 4.0)
    testing.expect_value(t, local[3][0], 5.0)
    testing.expect_value(t, local[3][1], 6.0)
    testing.expect_value(t, local[3][2], 7.0)
}

@(test)
test_identity_node_transform :: proc(t: ^testing.T) {
    document := parse_ok(t, `{"asset":{"version":"2.0"},"nodes":[{}]}`)
    defer destroy(document)

    expected := la.MATRIX4F32_IDENTITY
    testing.expect_value(t, node_transform_local(&document.nodes[0]), expected)
    testing.expect_value(t, node_transform_world(&document.nodes[0]), expected)
}

// -----------------------------------------------------------------------
// Validation
// -----------------------------------------------------------------------

@(test)
test_validate_buffer_view_past_the_buffer :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":4}],` +
        `"bufferViews":[{"buffer":0,"byteOffset":2,"byteLength":8}]}`,
    )
    defer destroy(document)

    // A too-short buffer is `Invalid_Gltf` here, which
    // describes the input rather than the document.
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_accessor_with_no_elements :: proc(t: ^testing.T) {
    // The glTF schema requires accessor.count >= 1. In particular, accepting
    // zero would make a `stride * (count - 1)` validation underflow.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":4}],` +
        `"bufferViews":[{"buffer":0,"byteLength":4}],` +
        `"accessors":[{"bufferView":0,"componentType":5126,"count":0,"type":"VEC3"}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_accessor_extent :: proc(t: ^testing.T) {
    // Two VEC3 floats need 24 bytes, and the view only offers 20.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"buffers":[{"byteLength":20}],` +
        `"bufferViews":[{"buffer":0,"byteLength":20}],` +
        `"accessors":[{"bufferView":0,"componentType":5126,"count":2,"type":"VEC3"}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_index_outside_the_vertex_count :: proc(t: ^testing.T) {
    // The attributes describe three vertices, and the last index names a
    // fourth.  This one is checked only once the data has
    // been loaded.
    uri, ok := data_uri(float_payload(0, 1, 2, 0, 0, 0))
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":12,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":12}],`,
                `"accessors":[`,
                `
{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"},`,
                `
{"bufferView":0,"componentType":5123,"count":3,"type":"SCALAR"}],`,
                `"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1}]}]}`,
            ),
        ),
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.None)
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_large_uint32_mesh_index :: proc(t: ^testing.T) {
    // Keep UNSIGNED_INT indices unsigned during comparison; casting 0xffffffff
    // to `int` would wrap on 32-bit targets and could make it look in range.
    payload := make([]byte, 4, context.temp_allocator)
    put_u32(payload, 0, 0xFFFFFFFF)
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":4,"uri":"`,
            uri,
            `"}],`,
            `"bufferViews":[{"buffer":0,"byteLength":4}],`,
            `"accessors":[{"componentType":5126,"count":3,"type":"VEC3"},`,
            `{"bufferView":0,"componentType":5125,"count":1,"type":"SCALAR"}],`,
            `"meshes":[{"primitives":[{"attributes":{"POSITION":0},"indices":1}]}]}`,
        ),
    )
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_primitive_attribute_count_mismatch :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"accessors":[`,
            `
{"componentType":5126,"count":3,"type":"VEC3"},`,
            `
{"componentType":5126,"count":4,"type":"VEC3"}],`,
            `"meshes":[{"primitives":[{"attributes":{"POSITION":0,"NORMAL":1}}]}]}`,
        ),
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_node_cycle :: proc(t: ^testing.T) {
    // A cycle is malformed, and a two-pointer walk that advances one pointer
    // by two steps at a time never meets on a cycle of odd length.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"nodes":[{"children":[2]},{"children":[0]},{"children":[1]}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_node_with_two_parents :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` + `"nodes":[{"children":[2]},{"children":[2]},{}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_node_listed_twice_by_one_parent :: proc(t: ^testing.T) {
    document := parse_ok(t, `{"asset":{"version":"2.0"},` + `"nodes":[{"children":[1,1]},{}]}`)
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_scene_must_list_root_nodes :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"scenes":[{"nodes":[1]}],"scene":0,` +
        `"nodes":[{"children":[1]},{}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_skin_bind_matrix_arity :: proc(t: ^testing.T) {
    // Two joints, but only one inverse bind matrix.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[{"componentType":5126,"count":1,"type":"MAT4"}],` +
        `"nodes":[{},{}],` +
        `"skins":[{"joints":[0,1],"inverseBindMatrices":0}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_animation_track_arity :: proc(t: ^testing.T) {
    // Two keyframes produce two output values for a translation, not three.
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"accessors":[`,
            `
{"componentType":5126,"count":2,"type":"SCALAR","min":[0],"max":[1]},`,
            `
{"componentType":5126,"count":3,"type":"VEC3"}],`,
            `"nodes":[{}],`,
            `"animations":[{"channels":[{"sampler":0,"target":{"node":0,"path":"translation"}}],`,
            `
"samplers":[{"input":0,"output":1}]}]}`,
        ),
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_validate_accessor_min_after_max :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[{"componentType":5126,"count":1,"type":"VEC3",` +
        `
"min":[1,1,1],"max":[0,0,0]}]}`,
    )
    defer destroy(document)

    expect_invalid(t, document, .Invalid_Gltf)
}

@(test)
test_accessor_min_max_arity_is_enforced :: proc(t: ^testing.T) {
    // A VEC3 accessor may not claim four bounds.
    parse_fails(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[{"componentType":5126,"count":1,"type":"VEC3","min":[0,0,0,0]}]}`,
        .Invalid_Gltf,
    )
}

@(test)
test_validate_accepts_a_consistent_document :: proc(t: ^testing.T) {
    uri, ok := data_uri(three_positions())
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            concat(
                `{"asset":{"version":"2.0"},`,
                `"buffers":[{"byteLength":36,"uri":"`,
                uri,
                `"}],`,
                `"bufferViews":[{"buffer":0,"byteLength":36}],`,
                `"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3",`,
                `
"min":[0,0,0],"max":[1,1,0]}],`,
                `"scenes":[{"nodes":[0]}],"scene":0,`,
                `"nodes":[{"mesh":0}],`,
                `"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}]}`,
            ),
        ),
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)
}

@(test)
test_validate_nil_document :: proc(t: ^testing.T) {
    expect_invalid(t, nil, .Invalid_Argument)
    testing.expect_value(t, load_buffers(nil), Error.Invalid_Argument)
}

// -----------------------------------------------------------------------
// Extras and extensions
// -----------------------------------------------------------------------

@(test)
test_extras_are_compact_and_sorted :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"nodes":[{"name":"a","extras":{"zeta":1,"alpha":[true,null,"x"],"mu":{"b":2,"a":1}}}]}`,
    )
    defer destroy(document)

    // `extras` is re-serialised from a JSON object, whose iteration order is
    // unspecified, so the keys are sorted and the value is compact.  Two runs
    // over the same document produce the same string.
    testing.expect_value(
        t,
        document.nodes[0].extras.data,
        `{"alpha":[true,null,"x"],"mu":{"a":1,"b":2},"zeta":1}`,
    )
    // A member the file did not mention is an empty Extras, not a nil one.
    testing.expect_value(t, document.nodes[0].extras.data != "", true)
}

@(test)
test_extras_explicit_null_is_empty :: proc(t: ^testing.T) {
    document := parse_ok(t, `{"asset":{"version":"2.0"},"nodes":[{"extras":null}]}`)
    defer destroy(document)

    testing.expect_value(t, document.nodes[0].extras.data, "")
}

@(test)
test_unknown_extensions_are_kept_and_sorted :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` + `"extensionsUsed":["Z_extension","A_extension"]}`,
    )
    defer destroy(document)

    testing.expect_value(t, len(document.extensions_used), 2)
    testing.expect_value(t, document.extensions_used[0], "A_extension")
    testing.expect_value(t, document.extensions_used[1], "Z_extension")

    nodes := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` + `"nodes":[{"extensions":{"Z_x":{"b":1},"A_y":{"a":2}}}]}`,
    )
    defer destroy(nodes)

    testing.expect_value(t, len(nodes.nodes[0].extensions), 2)
    testing.expect_value(t, nodes.nodes[0].extensions[0].name, "A_y")
    testing.expect_value(t, nodes.nodes[0].extensions[0].data, `{"a":2}`)
    testing.expect_value(t, nodes.nodes[0].extensions[1].name, "Z_x")
    testing.expect_value(t, nodes.nodes[0].extensions[1].data, `{"b":1}`)
}

@(test)
test_khr_lights_punctual :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"extensionsUsed":["KHR_lights_punctual"],`,
            `"nodes":[`,
            `
{"name":"lamp","extensions":{"KHR_lights_punctual":{"light":0}}},`,
            `
{"name":"bulb","extensions":{"KHR_lights_punctual":{"light":1}}}],`,
            `"extensions":{"KHR_lights_punctual":{"lights":[`,
            `
{"type":"spot","color":[1,0.5,0],"intensity":3,"spot":`,
            `
{"innerConeAngle":0.1,"outerConeAngle":0.5}},`,
            `
{"type":"directional"}]}}}`,
        ),
    )
    defer destroy(document)

    testing.expect_value(t, len(document.lights), 2)
    spot := &document.lights[0]
    testing.expect_value(t, spot.type, Light_Type.Spot)
    testing.expect_value(t, spot.color, [3]f32{1, 0.5, 0})
    testing.expect_value(t, spot.intensity, 3.0)
    testing.expect_value(t, spot.spot_inner_cone_angle, 0.1)
    testing.expect_value(t, spot.spot_outer_cone_angle, 0.5)

    // A light with no `spot` block falls back to the schema's outer cone angle.
    bulb := &document.lights[1]
    testing.expect_value(t, bulb.type, Light_Type.Directional)
    testing.expect_value(t, bulb.spot_outer_cone_angle, DEFAULT_SPOT_OUTER_CONE_ANGLE)
    testing.expect_value(t, bulb.spot_inner_cone_angle, 0.0)
    testing.expect_value(t, bulb.intensity, 1.0)
    testing.expect_value(t, bulb.color, [3]f32{1, 1, 1})

    testing.expect(t, document.nodes[0].light == spot)
    testing.expect(t, document.nodes[1].light == bulb)
}

@(test)
test_khr_texture_transform :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"textures":[{"source":0}],"images":[{"uri":"data:image/png;base64,AA=="}],` +
        `"materials":[{"pbrMetallicRoughness":{"baseColorTexture":{"index":0,` +
        `
"extensions":{"KHR_texture_transform":{"offset":[0.25,0.5],` +
        `
"rotation":0.785,"scale":[3,4],"texCoord":1}}}}}]}`,
    )
    defer destroy(document)

    view := document.materials[0].pbr.base_color_texture
    testing.expect(t, view.texture == &document.textures[0])
    testing.expect_value(t, view.transform.offset, [2]f32{0.25, 0.5})
    testing.expect_value(t, view.transform.rotation, 0.785)
    testing.expect_value(t, view.transform.scale, [2]f32{3, 4})
    testing.expect_value(t, view.transform.tex_coord, 1)
    // The transform's own `texCoord` is the one that applies, and it is
    // absent here, so the texture reference keeps its default.
    testing.expect_value(t, view.tex_coord, 0)
}

@(test)
test_khr_materials_defaults :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"materials":[{"extensions":{` +
        `
"KHR_materials_clearcoat":{},` +
        `
"KHR_materials_transmission":{},` +
        `
"KHR_materials_ior":{},` +
        `
"KHR_materials_iridescence":{},` +
        `
"KHR_materials_emissive_strength":{}}}]}`,
    )
    defer destroy(document)

    material := &document.materials[0]
    testing.expect_value(t, material.has_clearcoat, true)
    testing.expect_value(t, material.clearcoat.clearcoat_factor, 0.0)
    testing.expect_value(t, material.has_transmission, true)
    testing.expect_value(t, material.transmission.transmission_factor, 0.0)
    testing.expect_value(t, material.has_ior, true)
    testing.expect_value(t, material.ior.ior, 1.5)
    testing.expect_value(t, material.has_iridescence, true)
    testing.expect_value(t, material.iridescence.ior, 1.3)
    testing.expect_value(t, material.iridescence.thickness_min, 100.0)
    testing.expect_value(t, material.iridescence.thickness_max, 400.0)
    testing.expect_value(t, material.has_emissive_strength, true)
    testing.expect_value(t, material.emissive_strength.strength, 1.0)
}

@(test)
test_khr_draco_attribute_ids_are_not_accessors :: proc(t: ^testing.T) {
    // KHR_draco_mesh_compression maps a semantic to a Draco attribute id rather
    // than to an accessor, so the ids must not be resolved against the accessor
    // list -- and there is no accessor 0 here to resolve them against.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"extensionsUsed":["KHR_draco_mesh_compression"],` +
        `"buffers":[{"byteLength":4}],"bufferViews":[{"buffer":0,"byteLength":4}],` +
        `"meshes":[{"primitives":[{"attributes":{},"extensions":{` +
        `
"KHR_draco_mesh_compression":{"bufferView":0,` +
        `
"attributes":{"POSITION":0,"NORMAL":1}}}}]}]}`,
    )
    defer destroy(document)

    primitive := &document.meshes[0].primitives[0]
    testing.expect_value(t, primitive.has_draco, true)
    testing.expect(t, primitive.draco.buffer_view == &document.buffer_views[0])
    testing.expect_value(t, len(primitive.draco.attributes), 2)
    testing.expect_value(t, primitive.draco.attributes[0].type, Attribute_Type.Normal)
    testing.expect_value(t, primitive.draco.attributes[0].index, 1)
    testing.expect_value(t, primitive.draco.attributes[1].type, Attribute_Type.Position)
    testing.expect_value(t, primitive.draco.attributes[1].index, 0)
    // Nothing was resolved, so there is no accessor to point at.
    testing.expect(t, primitive.draco.attributes[0].data == nil)
}

// -----------------------------------------------------------------------
// File based parsing
// -----------------------------------------------------------------------

@(test)
test_parse_file_resolves_relative_buffers :: proc(t: ^testing.T) {
    directory, create_err := os.make_directory_temp("", "gltf_test", context.temp_allocator)
    testing.expectf(t, create_err == nil, "could not create a temporary directory")
    defer os.remove_all(directory)

    payload := three_positions()
    binary_path, _ := filepath.join({directory, `payload.bin`}, context.temp_allocator)
    testing.expectf(
        t,
        os.write_entire_file(binary_path, payload) == nil,
        "could not write the buffer payload",
    )

    path, _ := filepath.join({directory, `model.gltf`}, context.temp_allocator)
    testing.expectf(
        t,
        os.write_entire_file(path, positions_json(`{"byteLength":36,"uri":"payload.bin"}`)) == nil,
        "could not write the document",
    )

    document, err := parse_file(path)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)

    testing.expect_value(t, document.file_name, path)
    testing.expect(t, document.file_data != nil)
    testing.expect_value(t, load_buffers(document), Error.None)

    out: [3]f32
    testing.expect(t, read_float(&document.accessors[0], 2, out[:]))
    testing.expect_value(t, out, [3]f32{0, 1, 0})
}

@(test)
test_parse_file_missing :: proc(t: ^testing.T) {
    document, err := parse_file(`definitely/not/here.gltf`)
    defer destroy(document)
    testing.expect_value(t, err, Error.File_Not_Found)
}

@(test)
test_file_type_can_be_forced :: proc(t: ^testing.T) {
    text := `{"asset":{"version":"2.0"}}`

    // Forcing the container format is honoured even when the magic says
    // otherwise.
    document, err := parse_string(text, {file_type = File_Type.Glb})
    defer destroy(document)
    testing.expect_value(t, err, Error.Unknown_Format)

    forced, forced_err := parse(transmute([]byte)text, {file_type = File_Type.Gltf})
    defer destroy(forced)
    testing.expect_value(t, forced_err, Error.None)
}

// -----------------------------------------------------------------------
// Leak detection
// -----------------------------------------------------------------------

@(test)
test_no_leaks_gltf :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        uri, ok := data_uri(three_positions())
        testing.expect(t, ok)

        document := parse_ok(
            t,
            concat(positions_json(concat(`{"byteLength":36,"uri":"`, uri, `"}`))),
        )
        testing.expect_value(t, load_buffers(document), Error.None)
        expect_valid(t, document)
        destroy(document)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_glb :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        glb := build_glb(positions_json(`{"byteLength":36}`), three_positions())

        document, err := parse(glb)
        testing.expect_value(t, err, Error.None)
        testing.expect_value(t, load_buffers(document), Error.None)
        destroy(document)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_sparse_and_extensions :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        payload := sparse_payload()
        uri, ok := data_uri(payload)
        testing.expect(t, ok)

        document := parse_ok(
            t,
            concat(
                concat(
                    `{"asset":{"version":"2.0"},`,
                    `"extensionsUsed":["KHR_lights_punctual"],`,
                    `"buffers":[{"byteLength":50,"uri":"`,
                    uri,
                    `"}],`,
                    `"bufferViews":[`,
                    `
{"buffer":0,"byteOffset":0,"byteLength":36},`,
                    `
{"buffer":0,"byteOffset":36,"byteLength":2},`,
                    `
{"buffer":0,"byteOffset":38,"byteLength":12}],`,
                    `"accessors":[{"componentType":5126,"count":3,"type":"VEC3","sparse":{"count":1,`,
                    `
"indices":{"bufferView":1,"componentType":5123},"values":{"bufferView":2}}}],`,
                    `"nodes":[{"extras":{"b":2,"a":1},"extensions":`,
                    `
{"KHR_lights_punctual":{"light":0}}}],`,
                    `"extensions":{"KHR_lights_punctual":{"lights":[{"type":"point"}]}}}`,
                ),
            ),
        )
        testing.expect_value(t, load_buffers(document), Error.None)
        expect_valid(t, document)
        destroy(document)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_mesh_target_names :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)
        document := parse_ok(
            t,
            concat(
                `{"asset":{"version":"2.0"},`,
                `"accessors":[{"componentType":5126,"count":1,"type":"VEC3"},`,
                `{"componentType":5126,"count":1,"type":"VEC3"}],`,
                `"meshes":[{"extras":{"targetNames":["smile"]},`,
                `"primitives":[{"attributes":{"POSITION":0},`,
                `"targets":[{"POSITION":1}]}]}]}`,
            ),
        )
        testing.expect_value(t, len(document.meshes[0].target_names), 1)
        destroy(document)
    }

    expect_no_leaks(t, &track)
}

@(test)
test_no_leaks_on_error_paths :: proc(t: ^testing.T) {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    defer mem.tracking_allocator_destroy(&track)

    {
        context.allocator = mem.tracking_allocator(&track)

        // A document that parses and then fails validation has to give back
        // everything it allocated on the way there.
        document := parse_ok(
            t,
            `{"asset":{"version":"2.0"},` +
            `"buffers":[{"byteLength":4}],` +
            `"bufferViews":[{"buffer":0,"byteOffset":2,"byteLength":8}]}`,
        )
        expect_invalid(t, document, .Invalid_Gltf)
        destroy(document)

        // ...and so does one that fails part way through the conversion, after
        // some of the collections have already been filled in.
        half := parse_ok(
            t,
            `{"asset":{"version":"2.0"},` +
            `"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],` +
            `"accessors":[{"componentType":5126,"count":1,"type":"VEC3"}]}`,
        )
        destroy(half)

        failed, err := parse_string(
            `{"asset":{"version":"2.0"},` +
            `"meshes":[{"primitives":[{"attributes":{"POSITION":9}}]}]}`,
        )
        destroy(failed)
        testing.expect_value(t, err, Error.Invalid_Gltf)

        // ...and so does one whose second buffer cannot be fetched after the
        // first one already has been.
        short, short_err := parse_string(
            `{"asset":{"version":"2.0"},` +
            `"buffers":[{"byteLength":4,"uri":"data:application/octet-stream;base64,AAAA"}]}`,
        )
        defer destroy(short)
        testing.expect_value(t, short_err, Error.None)
        testing.expect_value(t, load_buffers(short), Error.Data_Too_Short)
    }

    expect_no_leaks(t, &track)
}

// These fixtures mirror the positive object/accessor cases in the
// glTF-Validator repository's test/base/base_test.dart. They live in the
// assets submodule (models/gltf_validator), so these tests require that
// checkout to be present.

@(test)
test_validator_base_asset :: proc(t: ^testing.T) {
    document := parse_ok(
        t,
        `{"asset":{"copyright":"Khronos Group Inc.",` +
        `"generator":"glTF 2.0 Validator test suite","version":"2.0",` +
        `"minVersion":"2.0"}}`,
    )
    defer destroy(document)

    testing.expect_value(t, document.asset.copyright, "Khronos Group Inc.")
    testing.expect_value(t, document.asset.generator, "glTF 2.0 Validator test suite")
    testing.expect_value(t, document.asset.version, "2.0")
    testing.expect_value(t, document.asset.min_version, "2.0")
}

Validator_Base_Fixture :: struct {
    Category: string,
    Filename: string,
}

// test_validator_base_valid_corpus mirrors the positive object fixtures read
// by glTF-Validator's base_test.dart.  The fixture files live in the assets
// submodule under models/gltf_validator/base/data, including their small
// external buffer/image dependencies.
@(test)
test_validator_base_valid_corpus :: proc(t: ^testing.T) {
    fixtures := []Validator_Base_Fixture {
        {"asset", "valid.gltf"},
        {"buffer", "valid.gltf"},
        {"buffer_view", "valid.gltf"},
        {"camera", "valid.gltf"},
        {"image", "valid.gltf"},
        {"sampler", "valid.gltf"},
        {"texture", "valid.gltf"},
        {"material", "valid.gltf"},
        {"accessor", "valid.gltf"},
        {"accessor_data", "get_elements.gltf"},
        {"accessor_data", "get_elements_matrix.gltf"},
        {"accessor_data", "get_elements_sparse.gltf"},
        {"mesh", "valid.gltf"},
        {"node", "valid.gltf"},
        {"skin", "valid.gltf"},
        {"scene", "valid.gltf"},
        {"animation", "valid.gltf"},
        {"root", "valid.gltf"},
        {"root", "named_objects.gltf"},
    }

    for fixture in fixtures {
        path := validator_base_fixture(fixture.Category, fixture.Filename)
        document, parse_err := parse_file(path)
        if parse_err != .None {
            testing.expectf(t, false, "%s: parse failed with %v", fixture.Filename, parse_err)
            continue
        }

        buffer_err := load_buffers(document)
        if buffer_err != .None {
            testing.expectf(
                t,
                false,
                "%s: buffer loading failed with %v",
                fixture.Filename,
                buffer_err,
            )
            destroy(document)
            continue
        }

        validation_err := validate(document)
        if validation_err != nil {
            testing.expectf(
                t,
                false,
                "%s: validation failed with %v",
                fixture.Filename,
                validation_err.?,
            )
        }
        destroy(document)
    }
}

Validator_Extension_Fixture :: struct {
    Extension: string,
    Category:  string,
    Filename:  string,
}

@(test)
test_validator_extension_valid_corpus :: proc(t: ^testing.T) {
    fixtures := []Validator_Extension_Fixture {
        {"EXT_texture_webp", "image", "valid.gltf"},
        {"EXT_texture_webp", "texture", "valid.gltf"},
        {"KHR_animation_pointer", "animation/channel/target", "valid.gltf"},
        {"KHR_lights_punctual", "light", "valid.gltf"},
        {"KHR_lights_punctual", "node", "valid.gltf"},
        {"KHR_materials_anisotropy", "material", "valid.gltf"},
        {"KHR_materials_clearcoat", "material", "valid.gltf"},
        {"KHR_materials_clearcoat", "material", "valid_with_tangent.gltf"},
        {"KHR_materials_dispersion", "material", "valid.gltf"},
        {"KHR_materials_emissive_strength", "material", "valid.gltf"},
        {"KHR_materials_ior", "material", "valid.gltf"},
        {"KHR_materials_iridescence", "material", "valid.gltf"},
        {"KHR_materials_pbrSpecularGlossiness", "material", "valid.gltf"},
        {"KHR_materials_sheen", "material", "valid.gltf"},
        {"KHR_materials_specular", "material", "valid.gltf"},
        {"KHR_materials_transmission", "material", "valid.gltf"},
        {"KHR_materials_unlit", "material", "valid.gltf"},
        {"KHR_materials_variants", "variant", "valid.gltf"},
        {"KHR_materials_variants", "primitive", "valid.gltf"},
        {"KHR_materials_volume", "material", "valid.gltf"},
        {"KHR_mesh_quantization", "primitive", "valid.gltf"},
        {"KHR_node_visibility", "node", "valid.gltf"},
        {"KHR_texture_transform", "textureInfo", "valid.gltf"},
    }

    for fixture in fixtures {
        path := validator_extension_fixture(fixture.Extension, fixture.Category, fixture.Filename)
        document, parse_err := parse_file(path)
        if parse_err != .None {
            testing.expectf(
                t,
                false,
                "%s/%s: parse failed with %v",
                fixture.Extension,
                fixture.Filename,
                parse_err,
            )
            continue
        }

        buffer_err := load_buffers(document)
        if buffer_err != .None {
            testing.expectf(
                t,
                false,
                "%s/%s: buffer loading failed with %v",
                fixture.Extension,
                fixture.Filename,
                buffer_err,
            )
            destroy(document)
            continue
        }

        validation_err := validate(document)
        if validation_err != nil {
            testing.expectf(
                t,
                false,
                "%s/%s: validation failed with %v",
                fixture.Extension,
                fixture.Filename,
                validation_err.?,
            )
        }
        destroy(document)
    }
}

@(test)
test_validator_extension_punctual_light_values :: proc(t: ^testing.T) {
    lights := load_validator_extension_fixture(t, "KHR_lights_punctual", "light", "valid.gltf")
    defer destroy(lights)

    testing.expect_value(t, len(lights.lights), 1)
    light := &lights.lights[0]
    testing.expect_value(t, light.type, Light_Type.Spot)
    testing.expect_value(t, light.intensity, 2.45)
    testing.expect_value(t, light.color, [3]f32{0.75, 0.3, 1})
    testing.expect_value(t, light.range, 10.0)
    testing.expect_value(t, light.spot_inner_cone_angle, 0.2)
    testing.expect_value(t, light.spot_outer_cone_angle, 1.0)

    node_document := load_validator_extension_fixture(
        t,
        "KHR_lights_punctual",
        "node",
        "valid.gltf",
    )
    defer destroy(node_document)
    testing.expect(t, node_document.nodes[0].light == &node_document.lights[0])
}

@(test)
test_validator_extension_clearcoat_fields :: proc(t: ^testing.T) {
    document := load_validator_extension_fixture(
        t,
        "KHR_materials_clearcoat",
        "material",
        "valid.gltf",
    )
    defer destroy(document)

    material := &document.materials[0]
    testing.expect(t, material.has_clearcoat)
    testing.expect_value(t, material.clearcoat.clearcoat_factor, 0.5)
    testing.expect(t, material.clearcoat.clearcoat_texture.texture == &document.textures[0])
    testing.expect_value(t, material.clearcoat.clearcoat_roughness_factor, 1.0)
    testing.expect(
        t,
        material.clearcoat.clearcoat_roughness_texture.texture == &document.textures[1],
    )
    testing.expect(t, material.clearcoat.clearcoat_normal_texture.texture == &document.textures[2])
    testing.expect_value(t, material.clearcoat.clearcoat_normal_texture.scale, 1.5)
}

@(test)
test_validator_extension_material_values :: proc(t: ^testing.T) {
    anisotropy := load_validator_extension_fixture(
        t,
        "KHR_materials_anisotropy",
        "material",
        "valid.gltf",
    )
    defer destroy(anisotropy)
    testing.expect(t, anisotropy.materials[0].has_anisotropy)
    testing.expect_value(t, anisotropy.materials[0].anisotropy.strength, 0.0)
    testing.expect_value(t, anisotropy.materials[0].anisotropy.rotation, 0.0)
    testing.expect(t, anisotropy.materials[0].anisotropy.texture.texture == nil)
    testing.expect_value(t, anisotropy.materials[1].anisotropy.strength, 0.5)
    testing.expect_value(t, anisotropy.materials[1].anisotropy.rotation, 1.5)
    testing.expect(
        t,
        anisotropy.materials[1].anisotropy.texture.texture == &anisotropy.textures[0],
    )

    dispersion := load_validator_extension_fixture(
        t,
        "KHR_materials_dispersion",
        "material",
        "valid.gltf",
    )
    defer destroy(dispersion)
    testing.expect_value(t, dispersion.materials[0].dispersion.dispersion, 1.0)
    testing.expect_value(t, dispersion.materials[1].dispersion.dispersion, 1.0)
    testing.expect_value(t, dispersion.materials[2].dispersion.dispersion, 0.0)

    emissive := load_validator_extension_fixture(
        t,
        "KHR_materials_emissive_strength",
        "material",
        "valid.gltf",
    )
    defer destroy(emissive)
    testing.expect_value(t, emissive.materials[0].emissive_strength.strength, 2.0)
    testing.expect_value(t, emissive.materials[1].emissive_strength.strength, 1.0)
    testing.expect_value(t, emissive.materials[2].emissive_strength.strength, 0.0)

    iridescence := load_validator_extension_fixture(
        t,
        "KHR_materials_iridescence",
        "material",
        "valid.gltf",
    )
    defer destroy(iridescence)
    testing.expect_value(t, iridescence.materials[0].iridescence.ior, 1.3)
    testing.expect_value(t, iridescence.materials[0].iridescence.thickness_min, 100.0)
    testing.expect_value(t, iridescence.materials[0].iridescence.thickness_max, 400.0)
    testing.expect_value(t, iridescence.materials[1].iridescence.iridescence_factor, 0.5)
    testing.expect_value(t, iridescence.materials[1].iridescence.ior, 2.0)
    testing.expect_value(t, iridescence.materials[1].iridescence.thickness_min, 150.0)
    testing.expect_value(t, iridescence.materials[1].iridescence.thickness_max, 450.0)

    sheen := load_validator_extension_fixture(t, "KHR_materials_sheen", "material", "valid.gltf")
    defer destroy(sheen)
    testing.expect_value(t, sheen.materials[0].sheen.sheen_color_factor, [3]f32{0.5, 0, 1})
    testing.expect(t, sheen.materials[0].sheen.sheen_color_texture.texture == &sheen.textures[0])
    testing.expect_value(t, sheen.materials[0].sheen.sheen_roughness_factor, 1.0)
    testing.expect(
        t,
        sheen.materials[0].sheen.sheen_roughness_texture.texture == &sheen.textures[1],
    )

    specular_glossiness := load_validator_extension_fixture(
        t,
        "KHR_materials_pbrSpecularGlossiness",
        "material",
        "valid.gltf",
    )
    defer destroy(specular_glossiness)
    testing.expect(t, specular_glossiness.materials[0].has_specular_glossiness)
    testing.expect_value(
        t,
        specular_glossiness.materials[0].specular_glossiness.diffuse_factor,
        [4]f32{0.1, 0.2, 0.3, 0.4},
    )
    testing.expect(
        t,
        specular_glossiness.materials[0].specular_glossiness.diffuse_texture.texture ==
        &specular_glossiness.textures[0],
    )
    testing.expect_value(
        t,
        specular_glossiness.materials[0].specular_glossiness.specular_factor,
        [3]f32{0.5, 0.6, 0.7},
    )
    testing.expect_value(
        t,
        specular_glossiness.materials[0].specular_glossiness.glossiness_factor,
        0.8,
    )
    testing.expect(
        t,
        specular_glossiness.materials[0].specular_glossiness.specular_glossiness_texture.texture ==
        &specular_glossiness.textures[1],
    )

    unlit := load_validator_extension_fixture(t, "KHR_materials_unlit", "material", "valid.gltf")
    defer destroy(unlit)
    testing.expect(t, unlit.materials[0].unlit)

    specular := load_validator_extension_fixture(
        t,
        "KHR_materials_specular",
        "material",
        "valid.gltf",
    )
    defer destroy(specular)
    testing.expect_value(t, specular.materials[0].specular.specular_factor, 1.0)
    testing.expect_value(t, specular.materials[0].specular.specular_color_factor, [3]f32{1, 1, 1})
    testing.expect_value(t, specular.materials[1].specular.specular_factor, 0.5)
    testing.expect_value(
        t,
        specular.materials[1].specular.specular_color_factor,
        [3]f32{1.5, 0, 0.5},
    )
    testing.expect(
        t,
        specular.materials[1].specular.specular_texture.texture == &specular.textures[0],
    )
    testing.expect(
        t,
        specular.materials[1].specular.specular_color_texture.texture == &specular.textures[1],
    )

    transmission := load_validator_extension_fixture(
        t,
        "KHR_materials_transmission",
        "material",
        "valid.gltf",
    )
    defer destroy(transmission)
    testing.expect_value(t, transmission.materials[0].transmission.transmission_factor, 0.5)
    testing.expect(
        t,
        transmission.materials[0].transmission.transmission_texture.texture ==
        &transmission.textures[0],
    )

    volume := load_validator_extension_fixture(t, "KHR_materials_volume", "material", "valid.gltf")
    defer destroy(volume)
    testing.expect_value(t, volume.materials[0].volume.attenuation_color, [3]f32{1, 1, 1})
    testing.expect_value(t, volume.materials[0].volume.thickness_factor, 0.0)
    testing.expect_value(t, volume.materials[1].volume.attenuation_color, [3]f32{0, 0.5, 0})
    testing.expect_value(t, volume.materials[1].volume.attenuation_distance, 10.0)
    testing.expect_value(t, volume.materials[1].volume.thickness_factor, 3.0)
    testing.expect(t, volume.materials[1].volume.thickness_texture.texture == &volume.textures[0])
}

@(test)
test_validator_extension_ior_defaults_and_values :: proc(t: ^testing.T) {
    document := load_validator_extension_fixture(t, "KHR_materials_ior", "material", "valid.gltf")
    defer destroy(document)

    expected := [3]f32{2, 1.5, 0}
    testing.expect_value(t, len(document.materials), len(expected))
    for i in 0 ..< len(expected) {
        testing.expect(t, document.materials[i].has_ior)
        testing.expect_value(t, document.materials[i].ior.ior, expected[i])
    }
}

@(test)
test_validator_extension_texture_transform_values :: proc(t: ^testing.T) {
    document := load_validator_extension_fixture(
        t,
        "KHR_texture_transform",
        "textureInfo",
        "valid.gltf",
    )
    defer destroy(document)

    transform := document.materials[0].emissive_texture.transform
    testing.expect_value(t, transform.offset, [2]f32{0, 1})
    testing.expect_value(t, transform.scale, [2]f32{0.5, 0.5})
    testing.expect(t, math_approx(transform.rotation, 1.57079632679))
    testing.expect_value(t, transform.tex_coord, 1)
}

@(test)
test_validator_extension_variant_mappings :: proc(t: ^testing.T) {
    document := load_validator_extension_fixture(
        t,
        "KHR_materials_variants",
        "primitive",
        "valid.gltf",
    )
    defer destroy(document)

    testing.expect_value(t, len(document.variants), 2)
    testing.expect_value(t, document.variants[0].name, "variant0")
    testing.expect_value(t, document.variants[0].extras.data, `{"id":5}`)
    testing.expect_value(t, document.variants[1].name, "variant1")
    testing.expect_value(t, document.variants[1].extras.data, `{"id":3}`)

    mappings := document.meshes[0].primitives[0].mappings
    testing.expect_value(t, len(mappings), 2)
    testing.expect_value(t, mappings[0].variant, 1)
    testing.expect(t, mappings[0].material == &document.materials[0])
    testing.expect_value(t, mappings[0].extras.data, `{"theme":"regular"}`)
    testing.expect_value(t, mappings[1].variant, 0)
    testing.expect(t, mappings[1].material == &document.materials[1])
    testing.expect_value(t, mappings[1].extras.data, `{"theme":"sheen"}`)
}

@(test)
test_validator_extension_animation_pointer_payload :: proc(t: ^testing.T) {
    document := load_validator_extension_fixture(
        t,
        "KHR_animation_pointer",
        "animation/channel/target",
        "valid.gltf",
    )
    defer destroy(document)

    channels := document.animations[0].channels
    testing.expect_value(t, len(channels), 2)
    for channel in channels {
        testing.expect(t, channel.target_node == nil)
        testing.expect_value(t, channel.target_path, Animation_Path.Pointer)
        testing.expect_value(t, len(channel.target_extensions), 1)
        testing.expect_value(t, channel.target_extensions[0].name, "KHR_animation_pointer")
    }
    testing.expect_value(
        t,
        channels[0].target_extensions[0].data,
        `{"pointer":"/materials/0/pbrMetallicRoughness/baseColorFactor"}`,
    )
}

@(test)
test_validator_extension_unknown_payloads_are_preserved :: proc(t: ^testing.T) {
    visibility := load_validator_extension_fixture(t, "KHR_node_visibility", "node", "valid.gltf")
    defer destroy(visibility)

    testing.expect_value(t, visibility.nodes[0].extensions[0].name, "KHR_node_visibility")
    testing.expect_value(t, visibility.nodes[0].extensions[0].data, `{"visible":false}`)
    testing.expect_value(t, visibility.nodes[1].extensions[0].data, `{"visible":true}`)
    testing.expect_value(t, visibility.nodes[2].extensions[0].data, `{}`)

    webp := load_validator_extension_fixture(t, "EXT_texture_webp", "texture", "valid.gltf")
    defer destroy(webp)
    testing.expect(t, webp.textures[0].has_webp)
    testing.expect(t, webp.textures[0].webp_source == &webp.images[1])
    testing.expect(t, webp.textures[0].source == &webp.images[0])
}

@(test)
test_validator_base_json_and_version_errors :: proc(t: ^testing.T) {
    cases := []struct {
        Category: string,
        Filename: string,
        Expected: Error,
    } {
        {"json", "invalid_syntax.gltf", .Invalid_Json},
        {"json", "invalid_object.gltf", .Invalid_Schema},
        {"json", "empty_file.gltf", .Data_Too_Short},
        {"asset", "1_0_version.gltf", .Legacy_Gltf},
    }

    for test_case in cases {
        path := validator_base_fixture(test_case.Category, test_case.Filename)
        document, err := parse_file(path)
        defer destroy(document)
        testing.expectf(
            t,
            err == test_case.Expected,
            "%s: expected %v, got %v",
            test_case.Filename,
            test_case.Expected,
            err,
        )
    }

    // The parser supports glTF 2.x; the validator reports 2.1 as a warning
    // because its current model targets 2.0, but it remains loadable here.
    path := validator_base_fixture("asset", "2_1_version.gltf")
    document, err := parse_file(path)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)
    testing.expect_value(t, document.asset.version, "2.1")
}

@(test)
test_validator_base_structural_errors :: proc(t: ^testing.T) {
    cases := []struct {
        Category: string,
        Filename: string,
    } {
        {"buffer_view", "invalid_length.gltf"},
        {"buffer_view", "invalid_stride_wrong_target.gltf"},
        {"accessor", "invalid_sparse_count_and_stride.gltf"},
        {"mesh", "accessor_unequal_count.gltf"},
        {"node", "node_loop.gltf"},
    }

    for test_case in cases {
        path := validator_base_fixture(test_case.Category, test_case.Filename)
        document, parse_err := parse_file(path)
        testing.expectf(
            t,
            parse_err == .None,
            "%s: parse failed with %v",
            test_case.Filename,
            parse_err,
        )
        if parse_err != .None {
            destroy(document)
            continue
        }

        buffer_err := load_buffers(document)
        testing.expectf(
            t,
            buffer_err == .None,
            "%s: buffer loading failed with %v",
            test_case.Filename,
            buffer_err,
        )
        if buffer_err == .None {
            expect_invalid(t, document, .Invalid_Gltf)
        }
        destroy(document)
    }
}

@(test)
test_validator_base_accessor_data_values :: proc(t: ^testing.T) {
    // Mirrors the Accessor getElements cases in base_test.dart.
    path := validator_base_fixture("accessor_data", "get_elements.gltf")
    document, err := parse_file(path)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)

    expect_unpacked_floats(t, &document.accessors[0], []f32{0, -5, 27, 0, 10.5, 0.5})
    expect_unpacked_floats(t, &document.accessors[1], []f32{1000, 0.25})
    expect_unpacked_floats(
        t,
        &document.accessors[2],
        []f32{50.0 / 65535.0, 45.0 / 65535.0, 12345.0 / 65535.0, 0},
    )
    expect_unpacked_floats(
        t,
        &document.accessors[3],
        []f32{1.0 / 127.0, 126.0 / 127.0, -1, 0, 50.0 / 127.0, -125.0 / 127.0},
    )
    expect_unpacked_floats(
        t,
        &document.accessors[4],
        []f32 {
            50.0 / 32767.0,
            45.0 / 32767.0,
            12345.0 / 32767.0,
            0,
            -1.0 / 32767.0,
            45.0 / 32767.0,
            12345.0 / 32767.0,
            0,
        },
    )
}

@(test)
test_validator_base_matrix_accessor_values :: proc(t: ^testing.T) {
    // Exercises all four padded matrix layouts from
    // test/base/data/accessor_data/get_elements_matrix.gltf.
    path := validator_base_fixture("accessor_data", "get_elements_matrix.gltf")
    document, err := parse_file(path)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)

    expect_unpacked_floats(t, &document.accessors[0], []f32{1, 2, -3, -4, 5, 6, -7, -8})
    expect_unpacked_floats(t, &document.accessors[1], []f32{-1, -2, 3, 4, -5, -6, 7, 8})
    expect_unpacked_floats(
        t,
        &document.accessors[2],
        []f32{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18},
    )
    expect_unpacked_floats(
        t,
        &document.accessors[3],
        []f32{3, 2, 1, 6, 5, 4, 9, 8, 7, 12, 11, 10, 15, 14, 13, 18, 17, 16},
    )
}

@(test)
test_validator_base_sparse_accessor_values :: proc(t: ^testing.T) {
    // Covers zero-filled accessors, a fully sparse accessor, and a partially
    // overridden unsigned-int accessor from the base accessor-data fixtures.
    path := validator_base_fixture("accessor_data", "get_elements_sparse.gltf")
    document, err := parse_file(path)
    testing.expect_value(t, err, Error.None)
    defer destroy(document)
    testing.expect_value(t, load_buffers(document), Error.None)
    expect_valid(t, document)

    expect_unpacked_floats(t, &document.accessors[0], []f32{0, 0})
    expect_unpacked_floats(t, &document.accessors[1], []f32{0.125, 1024})
    expect_unpacked_floats(t, &document.accessors[2], []f32{70000, 100001, 54321, 200002})
}

@(test)
test_validator_base_camera_sampler_texture_material :: proc(t: ^testing.T) {
    // Combines the valid camera, sampler, texture, and material objects from
    // the validator's base object tests so their cross-references are checked.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"cameras":[{"type":"perspective","perspective":{"znear":1,"zfar":10,"yfov":1,"aspectRatio":1}},` +
        `{"type":"orthographic","orthographic":{"znear":1,"zfar":10,"ymag":1,"xmag":1}}],` +
        `"samplers":[{"magFilter":9728,"minFilter":9987,"wrapS":33071,"wrapT":33648}],` +
        `"images":[{"uri":"data:image/png;base64,AA=="}],` +
        `"textures":[{"sampler":0,"source":0},{},{},{},{}],` +
        `"materials":[{"pbrMetallicRoughness":{"baseColorFactor":[1,0,1,1],` +
        `"baseColorTexture":{"index":0,"texCoord":0},"metallicFactor":0.7,` +
        `"roughnessFactor":0.3,"metallicRoughnessTexture":{"index":1,"texCoord":1}},` +
        `"normalTexture":{"index":2,"texCoord":2,"scale":2.1},` +
        `"occlusionTexture":{"index":3,"texCoord":3,"strength":0.5},` +
        `"emissiveTexture":{"index":4,"texCoord":4},"emissiveFactor":[0,1,0],` +
        `"alphaMode":"MASK","alphaCutoff":0.4,"doubleSided":true}]}`,
    )
    defer destroy(document)

    testing.expect_value(t, document.cameras[0].type, Camera_Type.Perspective)
    testing.expect_value(t, document.cameras[0].perspective.aspect_ratio, 1.0)
    testing.expect_value(t, document.cameras[0].perspective.yfov, 1.0)
    testing.expect_value(t, document.cameras[0].perspective.znear, 1.0)
    testing.expect_value(t, document.cameras[0].perspective.zfar, 10.0)
    testing.expect_value(t, document.cameras[1].type, Camera_Type.Orthographic)
    testing.expect_value(t, document.cameras[1].orthographic.xmag, 1.0)
    testing.expect_value(t, document.cameras[1].orthographic.ymag, 1.0)

    sampler := &document.samplers[0]
    testing.expect_value(t, sampler.mag_filter, Filter_Type.Nearest)
    testing.expect_value(t, sampler.min_filter, Filter_Type.Linear_Mipmap_Linear)
    testing.expect_value(t, sampler.wrap_s, Wrap_Mode.Clamp_To_Edge)
    testing.expect_value(t, sampler.wrap_t, Wrap_Mode.Mirrored_Repeat)
    testing.expect(t, document.textures[0].sampler == sampler)
    testing.expect(t, document.textures[0].source == &document.images[0])

    material := &document.materials[0]
    testing.expect_value(t, material.pbr.base_color_factor, [4]f32{1, 0, 1, 1})
    testing.expect_value(t, material.pbr.metallic_factor, 0.7)
    testing.expect_value(t, material.pbr.roughness_factor, 0.3)
    testing.expect(t, material.pbr.base_color_texture.texture == &document.textures[0])
    testing.expect_value(t, material.pbr.base_color_texture.tex_coord, 0)
    testing.expect(t, material.pbr.metallic_roughness_texture.texture == &document.textures[1])
    testing.expect_value(t, material.pbr.metallic_roughness_texture.tex_coord, 1)
    testing.expect(t, material.normal_texture.texture == &document.textures[2])
    testing.expect_value(t, material.normal_texture.tex_coord, 2)
    testing.expect_value(t, material.normal_texture.scale, 2.1)
    testing.expect(t, material.occlusion_texture.texture == &document.textures[3])
    testing.expect_value(t, material.occlusion_texture.tex_coord, 3)
    testing.expect_value(t, material.occlusion_texture.scale, 0.5)
    testing.expect(t, material.emissive_texture.texture == &document.textures[4])
    testing.expect_value(t, material.emissive_factor, [3]f32{0, 1, 0})
    testing.expect_value(t, material.alpha_mode, Alpha_Mode.Mask)
    testing.expect_value(t, material.alpha_cutoff, 0.4)
    testing.expect_value(t, material.double_sided, true)
}

@(test)
test_validator_base_sparse_accessor :: proc(t: ^testing.T) {
    // Based on test/base/data/accessor/valid.gltf: one VEC3 accessor with a
    // two-element sparse overlay whose indices are UBYTEs.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"accessors":[{"bufferView":0,"byteOffset":0,"type":"VEC3",` +
        `"componentType":5126,"count":4,"min":[0,0,0],"max":[1,1,1],` +
        `"normalized":false,"sparse":{"count":2,` +
        `"indices":{"bufferView":1,"byteOffset":24,"componentType":5121},` +
        `"values":{"bufferView":1,"byteOffset":0}}}],` +
        `"bufferViews":[{"buffer":0,"byteLength":48},` +
        `{"buffer":0,"byteOffset":48,"byteLength":26}],` +
        `"buffers":[{"byteLength":74}]}`,
    )
    defer destroy(document)

    accessor := &document.accessors[0]
    testing.expect_value(t, accessor.type, Element_Type.Vec3)
    testing.expect_value(t, accessor.count, 4)
    testing.expect(t, accessor.has_sparse)
    testing.expect_value(t, accessor.sparse.count, 2)
    testing.expect(t, accessor.sparse.indices_buffer_view == &document.buffer_views[1])
    testing.expect_value(t, accessor.sparse.indices_byte_offset, 24)
    testing.expect_value(t, accessor.sparse.indices_component_type, Component_Type.Unsigned_Byte)
    testing.expect(t, accessor.sparse.values_buffer_view == &document.buffer_views[1])
    testing.expect_value(t, accessor.sparse.values_byte_offset, 0)
    expect_valid(t, document)
}

@(test)
test_validator_base_mat3_unsigned_short_column_alignment :: proc(t: ^testing.T) {
    // MAT3/UNSIGNED_SHORT columns each occupy 8 bytes: 6 data bytes plus 2
    // alignment bytes.  This is the base matrix-accessor case that is easy to
    // accidentally read as nine packed shorts (18 bytes).
    payload := make([]byte, 24, context.temp_allocator)
    source_values := []u16{1, 2, 3, 4, 5, 6, 7, 8, 9}
    for value, index in source_values {
        column := index / 3
        row := index % 3
        put_u16(payload, column * 8 + row * 2, value)
    }
    uri, ok := data_uri(payload)
    testing.expect(t, ok)

    document := parse_ok(
        t,
        concat(
            `{"asset":{"version":"2.0"},`,
            `"buffers":[{"byteLength":24,"uri":"`,
            uri,
            `"}],`,
            `"bufferViews":[{"buffer":0,"byteLength":24}],`,
            `"accessors":[{"type":"MAT3","componentType":5123,"count":1,"bufferView":0}]}`,
        ),
    )
    defer destroy(document)

    testing.expect_value(t, load_buffers(document), Error.None)
    testing.expect_value(t, element_size(.Mat3, .Unsigned_Short), 24)
    expect_valid(t, document)

    values: [9]f32
    testing.expect(t, read_float(&document.accessors[0], 0, values[:]))
    for index in 0 ..< len(values) {
        testing.expect_value(t, values[index], f32(index + 1))
    }
}

@(test)
test_validator_base_mesh_morph_targets :: proc(t: ^testing.T) {
    // Based on test/base/data/mesh/valid.gltf. The semantic maps must resolve
    // each field's accessor independently, including the morph target maps.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"meshes":[{"primitives":[{"attributes":{"POSITION":1,"COLOR_0":4},` +
        `"mode":4,"indices":0,"material":0,"targets":[` +
        `{"POSITION":2,"COLOR_0":5},{"POSITION":3,"COLOR_0":6}]}],` +
        `"weights":[0.7,0.2],"extras":{"targetNames":["raise","lower"]}}],` +
        `"accessors":[{"type":"SCALAR","componentType":5123,"count":6},` +
        `{"type":"VEC3","componentType":5126,"count":4},` +
        `{"type":"VEC3","componentType":5126,"count":4},` +
        `{"type":"VEC3","componentType":5126,"count":4},` +
        `{"type":"VEC3","componentType":5126,"count":4},` +
        `{"type":"VEC3","componentType":5126,"count":4},` +
        `{"type":"VEC3","componentType":5126,"count":4}],` +
        `"materials":[{}]}`,
    )
    defer destroy(document)

    mesh := &document.meshes[0]
    primitive := &mesh.primitives[0]
    testing.expect_value(t, primitive.mode, Primitive_Mode.Triangles)
    testing.expect(t, primitive.indices == &document.accessors[0])
    testing.expect(t, primitive.material == &document.materials[0])
    testing.expect_value(t, len(mesh.weights), 2)
    testing.expect_value(t, mesh.weights[0], 0.7)
    testing.expect_value(t, mesh.weights[1], 0.2)
    testing.expect_value(t, mesh.target_names[0], "raise")
    testing.expect_value(t, mesh.target_names[1], "lower")
    testing.expect(t, find_accessor(primitive, .Position) == &document.accessors[1])
    testing.expect(t, find_accessor(primitive, .Color) == &document.accessors[4])
    testing.expect(t, primitive.targets[0].attributes[0].data == &document.accessors[5])
    testing.expect(t, primitive.targets[0].attributes[1].data == &document.accessors[2])
    testing.expect(t, primitive.targets[1].attributes[0].data == &document.accessors[6])
    testing.expect(t, primitive.targets[1].attributes[1].data == &document.accessors[3])
    expect_valid(t, document)
}

@(test)
test_validator_base_skin_skeleton_can_be_an_ancestor :: proc(t: ^testing.T) {
    // The base validator fixture has a skeleton root at node 0 and joints at
    // nodes 1-3.  The skeleton root is intentionally not itself a joint.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"nodes":[{"children":[1]},{"children":[2,3]},{},{}],` +
        `"accessors":[{"type":"MAT4","componentType":5126,"count":3}],` +
        `"skins":[{"inverseBindMatrices":0,"joints":[1,2,3],"skeleton":0}]}`,
    )
    defer destroy(document)

    skin := &document.skins[0]
    testing.expect(t, skin.skeleton == &document.nodes[0])
    testing.expect(t, skin.joints[0] == &document.nodes[1])
    testing.expect(t, skin.inverse_bind_matrices == &document.accessors[0])
    expect_valid(t, document)
}

@(test)
test_validator_base_animation :: proc(t: ^testing.T) {
    // Based on test/base/data/animation/valid.gltf.
    document := parse_ok(
        t,
        `{"asset":{"version":"2.0"},` +
        `"animations":[{"samplers":[{"input":0,"output":1,"interpolation":"LINEAR"}],` +
        `"channels":[{"sampler":0,"target":{"node":0,"path":"scale"}}]}],` +
        `"accessors":[{"type":"SCALAR","componentType":5126,"count":2,"min":[0],"max":[1]},` +
        `{"type":"VEC3","componentType":5126,"count":2}],"nodes":[{}]}`,
    )
    defer destroy(document)

    animation := &document.animations[0]
    testing.expect(t, animation.channels[0].sampler == &animation.samplers[0])
    testing.expect(t, animation.channels[0].target_node == &document.nodes[0])
    testing.expect_value(t, animation.channels[0].target_path, Animation_Path.Scale)
    testing.expect(t, animation.samplers[0].input == &document.accessors[0])
    testing.expect(t, animation.samplers[0].output == &document.accessors[1])
    testing.expect_value(t, animation.samplers[0].interpolation, Interpolation.Linear)
    expect_valid(t, document)
}
