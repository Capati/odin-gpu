#+build !js
package unit_tests

import "core:testing"
import gpu "../../gpu"

@(test)
test_limits_check_ordering :: proc(t: ^testing.T) {
    base := gpu.DEFAULT_DOWNLEVEL_LIMITS
    testing.expect(t, gpu.limits_check(base, base), "identical limits must fit")

    higher_max := base
    higher_max.max_texture_dimension_1d *= 2
    testing.expect(t, !gpu.limits_check(higher_max, base),
        "a larger maximum than the adapter supports must not fit")

    lower_max := base
    lower_max.max_texture_dimension_1d /= 2
    testing.expect(t, gpu.limits_check(lower_max, base),
        "a smaller maximum than the adapter supports must fit")

    looser_alignment := base
    looser_alignment.min_uniform_buffer_offset_alignment *= 2
    testing.expect(t, gpu.limits_check(looser_alignment, base),
        "a looser minimum alignment must fit")

    tighter_alignment := base
    tighter_alignment.min_uniform_buffer_offset_alignment /= 2
    testing.expect(t, !gpu.limits_check(tighter_alignment, base),
        "a tighter minimum alignment than the adapter supports must not fit")
}
