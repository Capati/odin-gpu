package  gpu_allocator

// Core
import intr "base:intrinsics"
import "core:log"

gpu_alloc_check  :: proc(err: Allocator_Error, loc := #caller_location) {
    if err != .None {
        log.panicf("GPU Allocation Error: %v", err, location = loc)
    }
}

align_down :: proc "contextless" (value: $T, #any_int alignment: u64) -> T
        where intr.type_is_integer(T) {
    return value & ~(T(alignment) - 1)
}

align_up :: proc "contextless" (value: $T, #any_int alignment: u64) -> T
        where intr.type_is_integer(T) {
    return align_down(value + T(alignment) - 1, alignment)
}

// Copies `src` into `dst`, truncating to `len(dst)-1` bytes and NUL-terminating.
// Allocation names longer than ALLOCATION_NAME_LENGTH-1 bytes are truncated
// (the reference uses unbounded strings).
str_copy_to_array :: proc "contextless" (dst: []u8, src: string) -> int {
    n := min(len(src), len(dst)-1)
    copy(dst[:n], src[:n])
    dst[n] = 0
    return n
}

str_from_array :: proc "contextless" (src: []u8) -> string {
    for b, i in src {
        if b == 0 do return string(src[:i])
    }
    return string(src[:])
}
