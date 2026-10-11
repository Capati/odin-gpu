package gltf

// Core
import "core:encoding/json"
import "core:mem"

// Extension payloads are typed by the glTF schema but the base `Document`
// keeps them as `json.Value`, because the streaming `Reader` has no schema to
// decode them against. These helpers read the handful of member
// shapes the extensions actually use.
//
// Readers return `false` when a member is absent or has the wrong JSON type.
// Most only inspect values in place; the array helpers allocate exactly the
// number of entries present in the JSON array.

// Returns `value` as a JSON object.
@(private)
as_object :: #force_inline proc "contextless" (value: json.Value) -> (json.Object, bool) {
    return value.(json.Object)
}

// Returns the member of `object` named `name`.
@(private)
member :: proc "contextless" (object: json.Object, name: string) -> (json.Value, bool) {
    value, found := object[name]
    if !found {
        return nil, false
    }
    return value, true
}

// Returns a member that must be an object.
@(private)
member_object :: proc "contextless" (object: json.Object, name: string) -> (json.Object, bool) {
    value, found := member(object, name)
    if !found {
        return nil, false
    }
    return as_object(value)
}

// Returns a member that must be an array.
@(private)
member_array :: proc "contextless" (object: json.Object, name: string) -> (json.Array, bool) {
    value, found := member(object, name)
    if !found {
        return nil, false
    }
    return value.(json.Array)
}

// Returns a member that must be a JSON integer.
@(private)
member_int :: proc "contextless" (object: json.Object, name: string) -> (int, bool) {
    value, found := member(object, name)
    if !found {
        return 0, false
    }
    i, is_int := value.(json.Integer)
    if !is_int {
        return 0, false
    }
    return json_int_to_int(i)
}

@(private)
json_int_to_int :: proc "contextless" (value: json.Integer) -> (int, bool) {
    converted := int(value)
    if json.Integer(converted) != value {
        return 0, false
    }
    return converted, true
}

// Returns a member that must be a JSON integer used as an index. A float, a string
// or a missing member all yield `(-1, false)`.
@(private)
member_index :: proc "contextless" (object: json.Object, name: string) -> (int, bool) {
    index, found := member_int(object, name)
    if !found {
        return -1, false
    }
    return index, true
}

// Returns a member that must be a JSON number.
@(private)
member_float :: proc "contextless" (object: json.Object, name: string) -> (f32, bool) {
    value, found := member(object, name)
    if !found {
        return 0, false
    }
    #partial switch v in value {
    case json.Float:
        return f32(v), true
    case json.Integer:
        return f32(v), true
    case:
        return 0, false
    }
}

// Returns a member that must be a JSON boolean.
@(private)
member_bool :: proc "contextless" (object: json.Object, name: string) -> (bool, bool) {
    value, found := member(object, name)
    if !found {
        return false, false
    }
    b, is_bool := value.(json.Boolean)
    if !is_bool {
        return false, false
    }
    return bool(b), true
}

// Returns a member that must be a JSON string.
@(private)
member_string :: proc "contextless" (object: json.Object, name: string) -> (string, bool) {
    value, found := member(object, name)
    if !found {
        return "", false
    }
    s, is_string := value.(json.String)
    if !is_string {
        return "", false
    }
    return string(s), true
}

// Returns a member that must be an array of JSON strings, with the slice header
// allocated from `allocator`. The strings themselves remain views into the
// source JSON, like the other reader-provided string fields.
@(private)
member_string_array :: proc(
    object: json.Object,
    name: string,
    allocator: mem.Allocator,
) -> (
    []string,
    bool,
) {
    array, found := member_array(object, name)
    if !found {
        return nil, false
    }
    out := make([]string, len(array), allocator)
    for element, i in array {
        s, is_string := element.(json.String)
        if !is_string {
            return nil, false
        }
        out[i] = string(s)
    }
    return out, true
}

// Validates that a member is an array of integers that fit in `int`, and returns
// its length.
@(private)
member_int_array_len :: proc "contextless" (object: json.Object, name: string) -> (int, bool) {
    array, found := member_array(object, name)
    if !found {
        return 0, false
    }
    for element in array {
        value, is_int := element.(json.Integer)
        if !is_int {
            return 0, false
        }
        if _, fits_int := json_int_to_int(value); !fits_int {
            return 0, false
        }
    }
    return len(array), true
}

// Copies a JSON number array into a fixed size destination. Missing trailing
// elements are left untouched, so the caller can pre-seed the destination with the
// schema default.  Returns false if the JSON array is longer than `dest` or holds
// a non-number.
@(private)
fill_float_array :: proc "contextless" (array: json.Array, dest: []f32) -> bool {
    if len(array) > len(dest) {
        return false
    }
    for element, i in array {
        #partial switch v in element {
        case json.Float:
            dest[i] = f32(v)
        case json.Integer:
            dest[i] = f32(v)
        case:
            return false
        }
    }
    return true
}

// Reads a JSON number array into a fixed size destination.
//
// A longer array is refused rather than truncated; a shorter one leaves the
// remainder of `dest` at zero, which is what the schema defaults mean for an
// omitted member.
@(private)
as_float_array :: proc "contextless" (value: json.Value, dest: []f32) -> bool {
    array, is_array := value.(json.Array)
    if !is_array {
        return false
    }
    return fill_float_array(array, dest)
}

// Like `as_float_array` with the length the schema requires
// rather than an upper bound.
@(private)
as_float_array_exact :: proc "contextless" (value: json.Value, dest: []f32) -> bool {
    array, is_array := value.(json.Array)
    if !is_array || len(array) != len(dest) {
        return false
    }
    return fill_float_array(array, dest)
}
