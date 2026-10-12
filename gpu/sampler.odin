package gpu

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

@private
Sampler_Impl :: struct {
    ref:        Ref_Count_Type,
    comparison: bool,
    filtering:  bool,
}

@private
sampler_get_public_impl: proc "contextless" (
    sampler: Sampler,
    loc := #caller_location,
) -> ^Sampler_Impl

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
    // Maximum level of detail (i.e. mip level) to use
    lod_max_clamp:    f32,
    // If this is enabled, this is a comparison sampler using the given comparison function.
    compare:          Compare_Function,
    // Must be at least 1. If this is not 1, all filter modes must be linear.
    anisotropy_clamp: u16,
    // Border color to use when `address_mode` is `Clamp_To_Border`
    border_color:     Sampler_Border_Color,
}

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

device_create_sampler: proc(
    device: Device,
    descriptor: Sampler_Descriptor = DEFAULT_SAMPLER_DESCRIPTOR,
    loc := #caller_location,
) -> Sampler

// device_create_sampler_impl :: proc(
//     device: Device,
//     descriptor: Sampler_Descriptor = DEFAULT_SAMPLER_DESCRIPTOR,
//     loc := #caller_location,
// ) -> Sampler {
//     device_impl := device_get_public_impl(device, loc)

//     if descriptor.address_mode_u == .ClampToBorder ||
//             descriptor.address_mode_v == .ClampToBorder ||
//             descriptor.address_mode_w == .ClampToBorder {
//         assert("", loc)
//     }

//     return {}
// }

sampler_set_label: proc(sampler: Sampler, label: string, loc := #caller_location)

sampler_add_ref: proc(sampler: Sampler, loc := #caller_location)

sampler_release: proc(sampler: Sampler, loc := #caller_location)
