package shared

// Core
import "core:bytes"
import "core:log"
import "core:reflect"
import "core:slice"

FromBytes :: slice.reinterpret

when ODIN_DEBUG {
    @(private = "file")
    _can_be_bytes :: proc(T: typeid) -> bool {
        id := reflect.typeid_core(T)
        kind := reflect.type_kind(id)

        for kind == .Array || kind == .Enumerated_Array {
            id = reflect.typeid_elem(id)
            id = reflect.typeid_core(id)
            kind = reflect.type_kind(id)
        }

        #partial switch kind {
        case .Struct:
            res := true
            for ti in reflect.struct_field_types(id) {
                res &&= _can_be_bytes(ti.id)
            }
            return res

        case .Union:
            res := true
            for ti in type_info_of(id).variant.(reflect.Type_Info_Union).variants {
                res &&= _can_be_bytes(ti.id)
            }
            return res

        case .Slice,
             .Dynamic_Array,
             .Map,
             .Pointer,
             .Multi_Pointer,
             .String,
             .Procedure,
             .Type_Id,
             .Any,
             .Soa_Pointer,
             .Simd_Vector:
            return false
        }

        return true
    }

    // Convert [dynamic] array to bytes.
    dynamic_array_to_bytes :: proc(arr: $T/[dynamic]$E, loc := #caller_location) -> []u8 {
        if _can_be_bytes(E) {
            return dynamic_array_to_bytes_contextless(arr)
        } else {
            log.panicf("Cannot fully convert [dynamic] to bytes: %v", typeid_of(T), location = loc)
        }
    }

    // Convert slice to bytes.
    slice_to_bytes :: proc(s: $T/[]$E, loc := #caller_location) -> []u8 {
        if _can_be_bytes(E) {
            return slice_to_bytes_contextless(s)
        } else {
            log.panicf("Cannot fully convert [slice] to bytes: %v", typeid_of(T), location = loc)
        }
    }

    // Convert any to bytes.
    any_to_bytes :: proc(v: any, loc := #caller_location) -> []u8 {
        if _can_be_bytes(v.id) {
            return any_to_bytes_contextless(v)
        } else {
            log.panicf("Cannot fully convert [any] to bytes: %v", v.id, location = loc)
        }
    }
} else {
    slice_to_bytes :: slice_to_bytes_contextless
    dynamic_array_to_bytes :: dynamic_array_to_bytes_contextless
    any_to_bytes :: any_to_bytes_contextless
}

// Compile time panic stub.
map_to_bytes :: proc "contextless" (m: $T/map[$K]$V) -> []u8 {
    #panic("Cannot fully convert [map] to bytes")
}

// Convert buffer stream to bytes.
buffer_stream_to_bytes :: #force_inline proc "contextless" (
    b: bytes.Buffer,
    loc := #caller_location,
) -> []u8 #no_bounds_check {
    return b.buf[b.off:]
}

// Convert [dynamic] array to bytes.
dynamic_array_to_bytes_contextless :: #force_inline proc "contextless" (
    arr: $T/[dynamic]$E,
    loc := #caller_location,
) -> []u8 {
    return slice.to_bytes(arr[:])
}

// Convert slice to bytes.
slice_to_bytes_contextless :: #force_inline proc "contextless" (
    s: $T/[]$E,
    loc := #caller_location,
) -> []u8 {
    return slice.to_bytes(s)
}

// Convert any to bytes.
any_to_bytes_contextless :: #force_inline proc "contextless" (
    v: any,
    loc := #caller_location,
) -> []u8 #no_bounds_check {
    sz: int
    if ti := type_info_of(v.id); ti != nil {
        sz = ti.size
    }
    return ([^]byte)(v.data)[:sz]
}

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
