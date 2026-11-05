package gpu

// Core
import "core:math"

// Handle to a sampler.
//
// A `Sampler` object defines how a pipeline will sample from a `Texture_View`.
// Samplers define image filters (including anisotropy) and address (wrapping)
// modes, among other things. See the documentation for `Sampler_Descriptor`
// for more information.
//
// It can be created with `device_create_sampler`.
//
// Corresponds to [WebGPU
// `GPUSampler`](https://gpuweb.github.io/gpuweb/#sampler-interface).
Sampler :: distinct Handle

// Color variation to use when sampler addressing mode is `Address_Mode.Clamp_To_Border`.
Sampler_Border_Color :: enum i32 {
    Undefined,
    // [0, 0, 0, 0]
    Transparent_Black,
    // [0, 0, 0, 1]
    Opaque_Black,
    // [1, 1, 1, 1]
    Opaque_White,
    // On the Metal backend, this is equivalent to `Transparent_Black` for
    // textures that have an alpha component, and equivalent to `Opaque_Black`
    // for textures that do not have an alpha component. On other backends, this
    // is equivalent to `Transparent_Black`. Requires
    // `Address_Mode_Clamp_To_Zero` feature. Not supported on the web.
    Zero,
}

// Describes a `Sampler`.
//
// For use with `device_create_sampler`.
//
// Corresponds to [WebGPU `GPUSamplerDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpusamplerdescriptor).
Sampler_Descriptor :: struct {
    // Debug label of the sampler.
    label:            string,
    // How to deal with out of bounds accesses in the u (i.e. x) direction
    address_mode_u:   Address_Mode,
    // How to deal with out of bounds accesses in the v (i.e. y) direction
    address_mode_v:   Address_Mode,
    // How to deal with out of bounds accesses in the w (i.e. z) direction
    address_mode_w:   Address_Mode,
    // How to filter the texture when it needs to be magnified (made larger)
    mag_filter:       Filter_Mode,
    // How to filter the texture when it needs to be minified (made smaller)
    min_filter:       Filter_Mode,
    // How to filter between mip map levels
    mipmap_filter:    Mipmap_Filter_Mode,
    // Minimum level of detail (i.e. mip level) to use
    lod_min_clamp:    f32,
    // Maximum level of detail (i.e. mip level) to use.
    lod_max_clamp:    f32,
    // If this is enabled, this is a comparison sampler using the given comparison function.
    compare:          Compare_Function,
    // Zero (the zero value) resolves to 1 so partial descriptors stay usable.
    // Any other value must be at least 1; when it is greater than 1, all
    // filter modes must be linear.
    anisotropy_clamp: u16,
    // Border color to use when `address_mode` is `Clamp_To_Border`
    border_color:     Sampler_Border_Color,
}

// Default sampler descriptor: clamp-to-edge, nearest filtering, LOD 0..32,
// no comparison, anisotropy 1, transparent-black border.
DEFAULT_SAMPLER_DESCRIPTOR :: Sampler_Descriptor {
    label            = "",
    address_mode_u   = .Clamp_To_Edge,
    address_mode_v   = .Clamp_To_Edge,
    address_mode_w   = .Clamp_To_Edge,
    mag_filter       = .Nearest,
    min_filter       = .Nearest,
    mipmap_filter    = .Nearest,
    lod_min_clamp    = 0.0,
    lod_max_clamp    = 32.0,
    compare          = .Undefined,
    anisotropy_clamp = 1,
    border_color     = .Undefined,
}

// Creates a sampler.
//
// The descriptor is validated for finite/ordered LOD clamps, the
// anisotropy/filter rule, and the `Address_Mode_Clamp_To_Border` /
// `Address_Mode_Clamp_To_Zero` features. Invalid descriptors are reported
// through the device's validation path and return `{}`.
device_create_sampler: proc(
    device: Device,
    descriptor: Sampler_Descriptor = DEFAULT_SAMPLER_DESCRIPTOR,
    loc := #caller_location,
) -> Sampler

// Returns the sampler's debug label.
//
// The string is owned by the sampler and stays valid until the next
// `sampler_set_label()` or until the sampler is released.
sampler_get_label: proc(sampler: Sampler, loc := #caller_location) -> string

// Sets the sampler's debug label.
//
// The sampler keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
sampler_set_label: proc(sampler: Sampler, label: string, loc := #caller_location)

// Increments the sampler's reference count.
sampler_add_ref: proc(sampler: Sampler, loc := #caller_location)

// Decrements the sampler's reference count, destroying it when it reaches zero.
sampler_release: proc(sampler: Sampler, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Sampler_Impl :: struct {
    ref:        Ref_Count_Type,
    comparison: bool,
    filtering:  bool,
}

_sampler_get_impl: proc "contextless" (sampler: Sampler, loc := #caller_location) -> ^_Sampler_Impl

_Sampler_Descriptor_Impl :: struct {
    lod_max_clamp:    f32,
    anisotropy_clamp: u16,
}

// Backend-independent sampler resolution: defaults, finite/order checks and the
// anisotropy/filter rule. Backends consume the resolved values.
_resolve_sampler_descriptor :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> (
    _Sampler_Descriptor_Impl,
    bool,
) {
    valid := true
    if descriptor.address_mode_u == .Clamp_To_Border ||
       descriptor.address_mode_v == .Clamp_To_Border ||
       descriptor.address_mode_w == .Clamp_To_Border {
        valid &= gpu_validate(
            device,
            device_has_feature(device, .Address_Mode_Clamp_To_Border),
            "Clamp_To_Border requires the [Address_Mode_Clamp_To_Border] feature",
            loc,
        )
    }
    if descriptor.border_color == .Zero {
        valid &= gpu_validate(
            device,
            device_has_feature(device, .Address_Mode_Clamp_To_Zero),
            "border color Zero requires the [Address_Mode_Clamp_To_Zero] feature",
            loc,
        )
    }
    lod_max := descriptor.lod_max_clamp
    valid &= gpu_validate(
        device,
        !math.is_nan(descriptor.lod_min_clamp) &&
        !math.is_inf(descriptor.lod_min_clamp) &&
        !math.is_nan(lod_max) &&
        !math.is_inf(lod_max) &&
        descriptor.lod_min_clamp >= 0 &&
        lod_max >= 0 &&
        descriptor.lod_min_clamp <= lod_max,
        "sampler lodMinClamp/lodMaxClamp must be finite, non-negative and ordered",
        loc,
    )
    anisotropy := descriptor.anisotropy_clamp
    if anisotropy == 0 {
        // Treat zero as the WebGPU default (1), so partial descriptor literals
        // remain usable.
        anisotropy = 1
    }
    valid &= gpu_validate(
        device,
        anisotropy >= 1,
        "sampler anisotropyClamp must be at least 1",
        loc,
    )
    if anisotropy > 1 {
        valid &= gpu_validate(
            device,
            descriptor.min_filter == .Linear &&
            descriptor.mag_filter == .Linear &&
            descriptor.mipmap_filter == .Linear,
            "anisotropic sampling requires linear filters",
            loc,
        )
    }
    if !valid {
        return {}, false
    }
    return {lod_max_clamp = lod_max, anisotropy_clamp = anisotropy}, true
}
