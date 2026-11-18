package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/limits.spec.ts`:
// the limit invariants every backend
// must uphold.

cts_power_of_two :: proc(value: u32) -> bool {
    return value != 0 && value & (value - 1) == 0
}

cts_texture_accepted :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    descriptor: gpu.Texture_Descriptor,
) -> bool {
    before := cts_errors()
    texture := gpu.device_create_texture(f.device, descriptor)
    accepted := cts_errors() == before
    if texture != {} {
        gpu.texture_release(texture)
    }
    testing.expect(t, accepted == (texture != {}),
        "a texture's validation verdict and handle disagree")
    return accepted
}

cts_plain_texture :: proc(
    dimension: gpu.Texture_Dimension,
    width, height, layers: u32,
) -> gpu.Texture_Descriptor {
    return {
        usage           = {.Texture_Binding},
        dimension       = dimension,
        format          = .RGBA8_Unorm,
        size            = {width = width, height = height, depth_or_array_layers = layers},
        mip_level_count = 1,
        sample_count    = 1,
    }
}

@(test)
cts_limits_max_buffer_size :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_buffer_size = 4096
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    small, small_errors := cts_measure_buffer_create(t, f.device, {
        size = 4, usage = {.Copy_Src},
    })
    testing.expect(t, small_errors == 0 && small != {}, "a 4-byte buffer")
    if small != {} {
        gpu.buffer_release(small)
    }

    at, at_errors := cts_measure_buffer_create(t, f.device, {
        size = 4096, usage = {.Copy_Src},
    })
    testing.expect(t, at_errors == 0 && at != {},
        "a buffer of exactly max_buffer_size")
    if at != {} {
        gpu.buffer_release(at)
    }

    over, over_errors := cts_measure_buffer_create(t, f.device, {
        size = 4100, usage = {.Copy_Src},
    })
    testing.expect(t, over_errors > 0 && over == {},
        "one 4-byte step past max_buffer_size")
}

@(test)
cts_limits_max_texture_dimension_1d :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_texture_dimension_1d = 256
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    testing.expect(t,
        cts_texture_accepted(t, f, cts_plain_texture(.D1, 256, 1, 1)),
        "a 1d texture of exactly max_texture_dimension_1d")
    testing.expect(t,
        !cts_texture_accepted(t, f, cts_plain_texture(.D1, 257, 1, 1)),
        "a 1d texture one texel past the limit")
    testing.expect(t,
        cts_texture_accepted(t, f, cts_plain_texture(.D2, 257, 1, 1)),
        "a 2d texture 257 wide")
}

@(test)
cts_limits_max_texture_dimension_2d :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_texture_dimension_2d = 64
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D2, 64, 1, 1)),
        "a 64x1 texture")
    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D2, 1, 64, 1)),
        "a 1x64 texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D2, 65, 1, 1)),
        "a 65x1 texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D2, 1, 65, 1)),
        "a 1x65 texture")
    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D1, 65, 1, 1)),
        "a 1d texture 65 wide")
}

@(test)
cts_limits_max_texture_dimension_3d :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_texture_dimension_3d = 32
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D3, 32, 32, 32)),
        "a 32x32x32 texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D3, 33, 32, 32)),
        "a 33-wide 3d texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D3, 32, 33, 32)),
        "a 33-high 3d texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D3, 32, 32, 33)),
        "a 33-deep 3d texture")
}

@(test)
cts_limits_max_texture_array_layers :: proc(t: ^testing.T) {
    limits := gpu.DEFAULT_DOWNLEVEL_LIMITS
    limits.max_texture_array_layers = 4
    f := cts_make_fixture(gpu.Device_Descriptor{required_limits = limits})
    defer cts_destroy_fixture(f)

    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D2, 4, 4, 4)),
        "a four-layer array texture")
    testing.expect(t, !cts_texture_accepted(t, f, cts_plain_texture(.D2, 4, 4, 5)),
        "a five-layer array texture")
    testing.expect(t, cts_texture_accepted(t, f, cts_plain_texture(.D3, 4, 4, 5)),
        "a 4x4x5 3d texture")
}

@(test)
cts_limits_invariants :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    adapter_limits := gpu.adapter_get_limits(f.adapter)
    defaults := gpu.DEFAULT_LIMITS

    testing.expect(t,
        defaults.max_uniform_buffer_binding_size <= defaults.max_buffer_size,
        "the default uniform binding size exceeds the default max_buffer_size")
    testing.expect(t,
        defaults.max_storage_buffer_binding_size <= defaults.max_buffer_size,
        "the default storage binding size exceeds the default max_buffer_size")
    testing.expect(t,
        adapter_limits.max_uniform_buffer_binding_size <= adapter_limits.max_buffer_size,
        "the adapter's uniform binding size exceeds its max_buffer_size")
    testing.expect(t,
        adapter_limits.max_storage_buffer_binding_size <= adapter_limits.max_buffer_size,
        "the adapter's storage binding size exceeds its max_buffer_size")

    testing.expect(t, cts_power_of_two(defaults.min_uniform_buffer_offset_alignment),
        "the default uniform offset alignment is not a power of two")
    testing.expect(t, cts_power_of_two(defaults.min_storage_buffer_offset_alignment),
        "the default storage offset alignment is not a power of two")
    testing.expect(t, cts_power_of_two(adapter_limits.min_uniform_buffer_offset_alignment),
        "the adapter's uniform offset alignment is not a power of two")
    testing.expect(t, cts_power_of_two(adapter_limits.min_storage_buffer_offset_alignment),
        "the adapter's storage offset alignment is not a power of two")

    testing.expect(t, defaults.min_uniform_buffer_offset_alignment >= 32,
        "the default uniform offset alignment is below 32")
    testing.expect(t, defaults.min_storage_buffer_offset_alignment >= 32,
        "the default storage offset alignment is below 32")
    testing.expect(t, adapter_limits.min_uniform_buffer_offset_alignment >= 32,
        "the adapter's uniform offset alignment is below 32")
    testing.expect(t, adapter_limits.min_storage_buffer_offset_alignment >= 32,
        "the adapter's storage offset alignment is below 32")
}
