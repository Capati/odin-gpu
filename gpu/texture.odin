package gpu

// Handle to a texture on the GPU.
//
// It can be created with `device_create_texture`.
//
// Corresponds to [WebGPU `GPUTexture`](https://gpuweb.github.io/gpuweb/#texture-interface).
Texture :: distinct Handle

@private
Texture_Impl :: struct {
    using desc_impl: Texture_Descriptor_Impl,
    device:          Device,
    tracker_index:   Tracker_Index,
    full_range:      Texture_Selector,
    ref:             Ref_Count_Type,
}

@private
texture_get_public_impl: proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> ^Texture_Impl

@private
texture_tracker_index :: proc "contextless" (
    texture: Texture,
    loc := #caller_location,
) -> Tracker_Index {
    impl := texture_get_public_impl(texture, loc)
    return impl.tracker_index
}

// Describes a `Texture`.
//
// Corresponds to [WebGPU `GPUTextureDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gputexturedescriptor).
Texture_Descriptor :: struct {
    // Debug label of the texture.
    label:           string,
    // Size of the texture. All components must be greater than zero. For a
    // regular 1D/2D texture, the unused sizes will be 1. For 2DArray textures,
    // Z is the number of 2D textures in that array.
    size:            Extent_3D,
    // Mip count of texture. For a texture with no extra mips, this must be 1.
    mip_level_count: u32,
    // Sample count of texture. If this is not 1, texture must have `Binding_Type.Texture.multisampled` set to true.
    sample_count:    u32,
    // Dimensions of the texture.
    dimension:       Texture_Dimension,
    // Format of the texture.
    format:          Texture_Format,
    // Allowed usages of the texture. If used in other ways, the operation will panic.
    usage:           Texture_Usages,
    // Specifies what view formats will be allowed when calling
    // `texture_create_view` on this texture.
    //
    // View formats of the same format as the texture are always allowed.
    //
    // Note: currently, only the srgb-ness is allowed to change. (ex:
    // `RGBA8_Unorm` texture + `RGBA8_Unorm_Srgb` view)
    view_formats:    []Texture_Format,
}

DEFAULT_TEXTURE_DESCRIPTOR :: Texture_Descriptor {
    label           = "",
    size            = DEFAULT_EXTENT_3D,
    mip_level_count = 1,
    sample_count    = 1,
    dimension       = .Undefined,
    format          = .Undefined,
    usage           = {},
    view_formats    = {},
}

texture_descriptor_array_layer_count :: #force_inline proc "contextless" (
    self: Texture_Descriptor, loc := #caller_location,
) -> u32 {
    assert_contextless(self.dimension != .Undefined, "Invalid texture dimension", loc)
    #partial switch self.dimension {
    case .D1, .D3: return 1
    case .D2:      return self.size.depth_or_array_layers
    }
    unreachable()
}

device_create_texture: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture

texture_get_native_metal_texture: proc(texture: Texture, loc := #caller_location) -> rawptr

texture_create_view: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View

texture_destroy: proc(texture: Texture, loc := #caller_location)

texture_get_depth_or_array_layers: proc(texture: Texture, loc := #caller_location) -> u32

texture_get_dimension: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension

texture_get_format: proc(texture: Texture, loc := #caller_location) -> Texture_Format

texture_get_height: proc(texture: Texture, loc := #caller_location) -> u32

texture_get_mip_level_count: proc(texture: Texture, loc := #caller_location) -> u32

texture_get_sample_count: proc(texture: Texture, loc := #caller_location) -> u32

texture_get_size: proc(texture: Texture, loc := #caller_location) -> Extent_3D

texture_get_texture_binding_view_dimension: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_View_Dimension

texture_get_usage: proc(texture: Texture, loc := #caller_location) -> Texture_Usages

texture_get_width: proc(texture: Texture, loc := #caller_location) -> u32

texture_set_label: proc(texture: Texture, label: string, loc := #caller_location)

texture_add_ref: proc(texture: Texture, loc := #caller_location)

texture_release: proc(texture: Texture, loc := #caller_location)
