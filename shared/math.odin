package shared

// Core
import "core:math"
import intr "base:intrinsics"

_ :: math

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
