package gltf

// Core
import "base:runtime"
import "core:encoding/json"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"

// `extras` and unrecognised extension payloads are kept as text so that a
// caller can re-read them without this package having to understand them.
//
// `core:encoding/json.unparse` is not used for that: it is not guaranteed to
// be stable across Odin versions, it cannot round-trip every `json.Value`, and
// it iterates object keys in map order.  The writer below is compact,
// deterministic (object keys are sorted) and total, so the same document
// always produces byte-identical `extras` text.

// json_write writes `value` to `builder` as compact JSON.
@(private)
json_write :: proc(builder: ^strings.Builder, value: json.Value) {
    #partial switch v in value {
    case json.Integer:
        strings.write_i64(builder, v, 10)
    case json.Float:
        // JSON has no encoding for infinity or NaN; emit null so that the
        // result stays parseable.
        f := f64(v)
        if f != f || f > 3.4e38 || f < -3.4e38 {
            strings.write_string(builder, "null")
        } else {
            // 'g' with precision -1 is the shortest round-trippable form, and
            // its output (`1e+100`, `0.5`, `-3`) is valid JSON.
            buf: [32]byte
            n := len(strconv.generic_ftoa(buf[:], f, 'g', -1, 64))
            strings.write_bytes(builder, buf[:n])
        }
    case json.Boolean:
        strings.write_string(builder, "true" if v else "false")
    case json.String:
        json_write_string(builder, v)
    case json.Array:
        strings.write_byte(builder, '[')
        for elem, i in v {
            if i > 0 {
                strings.write_byte(builder, ',')
            }
            json_write(builder, elem)
        }
        strings.write_byte(builder, ']')
    case json.Object:
        ta := context.temp_allocator
        runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = context.allocator == ta)
        keys := make([dynamic]string, 0, len(v), ta)
        for key in v {
            append(&keys, key)
        }
        sort_strings_small(keys[:])
        strings.write_byte(builder, '{')
        for key, i in keys {
            if i > 0 {
                strings.write_byte(builder, ',')
            }
            json_write_string(builder, key)
            strings.write_byte(builder, ':')
            json_write(builder, v[key])
        }
        strings.write_byte(builder, '}')
    case json.Null:
        strings.write_string(builder, "null")
    }
}

@(private)
json_write_string :: proc(builder: ^strings.Builder, value: string) {
    strings.write_byte(builder, '"')
    for c in value {
        switch c {
        case '"':
            strings.write_string(builder, `\"`)
        case '\\':
            strings.write_string(builder, `\\`)
        case '\b':
            strings.write_string(builder, `\b`)
        case '\f':
            strings.write_string(builder, `\f`)
        case '\n':
            strings.write_string(builder, `\n`)
        case '\r':
            strings.write_string(builder, `\r`)
        case '\t':
            strings.write_string(builder, `\t`)
        case:
            if c < ' ' {
                strings.write_string(builder, `\u00`)
                hex: string = "0123456789abcdef"
                nibble := (c >> 4) & 0xF
                strings.write_byte(builder, hex[nibble])
                nibble = c & 0xF
                strings.write_byte(builder, hex[nibble])
            } else {
                // Multi-byte runes go through untouched.
                strings.write_rune(builder, c)
            }
        }
    }
    strings.write_byte(builder, '"')
}

// json_to_text renders `value` into a string owned by `allocator`.
@(private)
json_to_text :: proc(value: json.Value, allocator: mem.Allocator) -> string {
    builder: strings.Builder
    strings.builder_init(&builder, allocator)
    json_write(&builder, value)
    return strings.to_string(builder)
}

// make_extras converts a parsed `extras` member into an `Extras`.  An absent
// member and an explicit JSON null both yield an empty `Extras`, so
// `Extras.data == ""` means "no extras".
@(private)
make_extras :: #force_inline proc(value: json.Value, allocator: mem.Allocator) -> Extras {
    if value == nil {
        return {}
    }
    #partial switch v in value {
    case json.Null:
        return {}
    case:
        return Extras{json_to_text(value, allocator)}
    }
}

// parse_extensions converts a parsed `extensions` member into a slice sorted
// by extension name, so that iteration order does not depend on map ordering.
//
// Extension names in `known` are skipped: their payload is interpreted into
// typed fields instead, and `Extension` is only for the leftovers.
//
// The nil fast path is inlined so the 2000+ calls for documents without
// extensions pay only a compare+branch, not a call.
@(private)
parse_extensions :: #force_inline proc(
    value: json.Value,
    allocator: mem.Allocator,
    known: []string = nil,
) -> []Extension {
    if value == nil {
        return nil
    }
    return parse_extensions_slow(value, allocator, known)
}

@(private)
parse_extensions_slow :: proc(
    value: json.Value,
    allocator: mem.Allocator,
    known: []string = nil,
) -> []Extension {
    object, is_object := value.(json.Object)
    if !is_object {
        return nil
    }
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = context.allocator == ta)
    names := make([dynamic]string, 0, len(object), ta)
    for name in object {
        if slice.contains(known, name) {
            continue
        }
        append(&names, name)
    }
    sort_strings_small(names[:])

    out := make([]Extension, len(names), allocator)
    for name, i in names {
        out[i] = Extension{name, json_to_text(object[name], allocator)}
    }
    return out
}

// The extension names this package interprets.  They are filtered out of the
// generic `Extension` list because their payload ends up in typed fields
// instead.
@(private, rodata)
KNOWN_EXTENSIONS := []string {
    "EXT_mesh_gpu_instancing",
    "EXT_meshopt_compression",
    "EXT_texture_basisu",
    "EXT_texture_webp",
    "KHR_draco_mesh_compression",
    "KHR_lights_punctual",
    "KHR_materials_anisotropy",
    "KHR_materials_clearcoat",
    "KHR_materials_dispersion",
    "KHR_materials_diffuse_transmission",
    "KHR_materials_emissive_strength",
    "KHR_materials_ior",
    "KHR_materials_iridescence",
    "KHR_materials_sheen",
    "KHR_materials_specular",
    "KHR_materials_transmission",
    "KHR_materials_unlit",
    "KHR_materials_variants",
    "KHR_materials_volume",
    "KHR_meshopt_compression",
    "KHR_texture_transform",
}

// extension_is_known reports whether this package interprets `name`.
@(private)
extension_is_known :: proc(name: string) -> bool {
    return slice.contains(KNOWN_EXTENSIONS, name)
}
