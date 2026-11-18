package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the upstream WebGPU CTS `api/validation/createSampler.spec.ts`.

@(test)
cts_sampler_lod_clamp :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    values := [7]f32{-4e-30, -1, 0, 0.5, 1, 10, 4e30}
    for minimum in values {
        for maximum in values {
            before := cts_errors()
            sampler := gpu.device_create_sampler(f.device, {
                lod_min_clamp = minimum,
                lod_max_clamp = maximum,
            })
            fail := minimum > maximum || minimum < 0
            cts_expect_outcome(t, cts_errors() - before, fail, "sampler lod clamp row")
            if sampler != {} {
                gpu.sampler_release(sampler)
            }
        }
    }
}

@(test)
cts_sampler_anisotropy :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    values := [8]u16{0, 1, 2, 4, 7, 16, 32, 33}
    filters := [4]gpu.Filter_Mode{.Linear, .Nearest, .Nearest, .Nearest}
    for anisotropy in values {
        for filter, index in filters {
            before := cts_errors()
            sampler := gpu.device_create_sampler(f.device, {
                min_filter       = index == 1 ? filter : .Linear,
                mag_filter       = index == 2 ? filter : .Linear,
                mipmap_filter    = index == 3 ? .Nearest : .Linear,
                anisotropy_clamp = anisotropy,
            })
            // Zero is the port's "unset" value and resolves to 1, so it is
            // accepted. Positive anisotropic values need linear filters.
            fail := anisotropy > 1 && index != 0
            cts_expect_outcome(t, cts_errors() - before, fail, "sampler anisotropy row")
            if sampler != {} {
                gpu.sampler_release(sampler)
            }
        }
    }
}
