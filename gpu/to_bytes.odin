package gpu

// Core
import "core:bytes"
import "core:log"
import "core:mem"
import "core:reflect"
import "core:slice"

// Reinterpret a byte slice as a slice of `T`. Inverse of `to_bytes`.
// Usage: `from_bytes([]f32, bytes)`.
from_bytes :: slice.reinterpret

// Convert a slice to bytes.
//
// In debug builds the element type is inspected with reflection; types holding
// indirections (pointers, slices, strings, maps, dynamic arrays, interfaces,
// procedures) panic instead of producing a slice of dangling bytes.
slice_to_bytes :: #force_inline proc(s: $T/[]$E, loc := #caller_location) -> []u8 {
    when ODIN_DEBUG {
        _check_to_bytes(E, loc)
    }
    return slice.to_bytes(s)
}

// Convert [dynamic] array to bytes.
dynamic_array_to_bytes :: #force_inline proc(
    arr: $T/[dynamic]$E,
    loc := #caller_location,
) -> []u8 {
    when ODIN_DEBUG {
        _check_to_bytes(E, loc)
    }
    return slice.to_bytes(arr[:])
}

// Convert any to bytes.
any_to_bytes :: proc(v: any, loc := #caller_location) -> []u8 {
    when ODIN_DEBUG {
        _check_to_bytes(v.id, loc)
    }
    return mem.any_to_bytes(v)
}

// Convert the unread portion of a byte buffer to bytes.
buffer_stream_to_bytes :: #force_inline proc "contextless" (b: bytes.Buffer) -> []u8 {
    return b.buf[b.off:]
}

// Maps cannot be reinterpreted as bytes. Instantiating this is a compile-time error.
map_to_bytes :: proc "contextless" (m: $T/map[$K]$V) -> []u8 {
    #panic("Cannot fully convert [map] to bytes")
}

// Contextless variants: no type validation, usable from "contextless" procedures.
slice_to_bytes_contextless :: slice.to_bytes

dynamic_array_to_bytes_contextless :: #force_inline proc "contextless" (
    arr: $T/[dynamic]$E,
) -> []u8 {
    return slice.to_bytes(arr[:])
}

any_to_bytes_contextless :: mem.any_to_bytes

to_bytes :: proc {
    slice_to_bytes,
    buffer_stream_to_bytes,
    dynamic_array_to_bytes,
    map_to_bytes,
    any_to_bytes,
}

to_bytes_contextless :: proc {
    slice_to_bytes_contextless,
    buffer_stream_to_bytes,
    dynamic_array_to_bytes_contextless,
    map_to_bytes,
    any_to_bytes_contextless,
}

@(private)
_check_to_bytes :: proc(T: typeid, loc := #caller_location) {
    if !_can_be_bytes(T) {
        log.panicf("Cannot fully convert %v to bytes: type holds indirections", T, location = loc)
    }
}

@(private)
_can_be_bytes :: proc(T: typeid) -> bool {
    if T == nil {
        return true
    }

    id := reflect.typeid_core(T)
    kind := reflect.type_kind(id)

    for kind == .Array || kind == .Enumerated_Array {
        id = reflect.typeid_core(reflect.typeid_elem(id))
        kind = reflect.type_kind(id)
    }

    #partial switch kind {
    case .Struct:
        for field in reflect.struct_field_types(id) {
            if !_can_be_bytes(field.id) {
                return false
            }
        }
        return true

    case .Union:
        if info, ok := type_info_of(id).variant.(reflect.Type_Info_Union); ok {
            for variant in info.variants {
                if !_can_be_bytes(variant.id) {
                    return false
                }
            }
        }
        return true

    case .Slice,
         .Dynamic_Array,
         .Map,
         .Pointer,
         .Multi_Pointer,
         .String,
         .Procedure,
         .Type_Id,
         .Any,
         .Soa_Pointer:
        return false
    }

    return true
}
