package gpu

// Core
import "core:math"
import "core:strings"

_ :: strings

byte_arr_str :: proc(arr: ^[$N]byte) -> string {
    return strings.truncate_to_byte(string(arr[:]), 0)
}

max_mip_levels :: proc(width, height: u32) -> u32 {
    max_dim := max(width, height)
    return u32(1 + math.floor(math.log2(f32(max_dim))))
}
