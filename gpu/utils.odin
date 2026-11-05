package gpu

// Core
import "core:math"
import "core:strings"
import "core:slice"
import intr "base:intrinsics"

@(require_results)
byte_arr_str :: #force_inline proc "contextless" (arr: ^[$N]byte) -> string {
    return strings.truncate_to_byte(string(arr[:]), 0)
}

max_mip_levels :: #force_inline proc "contextless" (
    width, height: u32,
    depth: u32 = 1,
) -> u32 {
    max_dim := max(width, max(height, depth))
    return u32(1 + math.floor(math.log2(f32(max_dim))))
}

is_multiple_of :: #force_inline proc "contextless" (#any_int lhs, rhs: int) -> bool {
    return lhs == 0 || lhs % rhs == 0
}

// Aligns the given size up to the specified alignment. An alignment of 0 or 1
// leaves the value unchanged.
//
// Kept here rather than routed through `core:mem`: its integer helpers take
// `int`/`uint`, which are 32 bits on the `js_wasm32` target, while every size
// this backend aligns is a `u64`.
@(require_results)
align_size :: #force_inline proc "contextless" (#any_int size, align: u64) -> u64 {
    if align <= 1 {
        return size
    }
    return (size + (align - 1)) & ~(align - 1)
}

clone_to_cstring_buf :: #force_inline proc "contextless" (
    buf: []byte,
    s: string,
    loc := #caller_location,
) -> cstring {
    assert_contextless(len(buf) >= len(s) + 1, "buf too small for string", loc)
    slice.zero(buf)
    copy(buf, s)
    buf[len(s)] = 0
    return cstring(&buf[0])
}

str_copy_to_array :: proc "contextless" (dst: []u8, src: string) -> int {
    n := min(len(src), len(dst)-1)
    copy(dst[:n], src[:n])
    dst[n] = 0
    return n
}

str_from_array :: proc "contextless" (src: []u8) -> string {
    for b, i in src {
        if b == 0 {
            return string(src[:i])
        }
    }
    return string(src[:])
}
