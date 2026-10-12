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

max_mip_levels :: #force_inline proc "contextless" (width, height: u32) -> u32 {
    max_dim := max(width, height)
    return u32(1 + math.floor(math.log2(f32(max_dim))))
}

is_multiple_of :: #force_inline proc "contextless" (#any_int lhs, rhs: int) -> bool {
    return lhs == 0 || lhs % rhs == 0
}

align :: proc "contextless" (
    value: $T,
    alignment: T,
    loc := #caller_location,
) -> T where intr.type_is_numeric(T) {
    assert_contextless(value <= max(T) - (alignment - 1), loc = loc)
    assert_contextless(math.is_power_of_two(int(alignment)), loc = loc)
    assert_contextless(alignment != 0, loc = loc)
    alignment_t := T(alignment)
    return (value + (alignment_t - 1)) & ~(alignment_t - 1)
}

// Aligns the given size to the specified alignment.
@(require_results)
align_size :: #force_inline proc "contextless" (#any_int size, align: u64) -> u64 {
    return (size + (align - 1)) & ~(align - 1)
}

// Check if the given value is aligned to the specified alignment.
@(require_results)
is_aligned :: #force_inline proc "contextless" (#any_int value, align: u64) -> bool {
    return (value & (align - 1)) == 0
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
