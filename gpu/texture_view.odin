package gpu

// Handle to a texture view.
//
// A `Texture_View` object refers to a `Texture`, or a subset of its layers and
// mip levels, and specifies an interpretation of the texture’s texels, which is
// needed to use a texture as a binding in a `Bind_Group` or as an attachment in
// a `Render_Pass`. It can be created using `texture_create_view()`, which
// accepts a `Texture_View_Descriptor` specifying the properties of the view.
//
// Corresponds to [WebGPU
// `GPUTextureView`](https://gpuweb.github.io/gpuweb/#gputextureview).
Texture_View :: distinct Handle

@private
Texture_View_Impl :: struct {
    texture:  Texture,
    device:   Device,
    selector: Texture_Selector,
    format:   Texture_Format,
    dimension: Texture_View_Dimension,
    usage:    Texture_Uses,
    aspect:   Texture_Aspect,
    ref:      Ref_Count_Type,
}

@private
texture_view_get_public_impl: proc "contextless" (
    texture_view: Texture_View,
    loc := #caller_location,
) -> ^Texture_View_Impl

// Describes a `Texture_View`.
//
// For use with `texture_create_view()`.
//
// Corresponds to [WebGPU `GPUTextureViewDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gputextureviewdescriptor).
Texture_View_Descriptor :: struct {
    // Debug label of the texture view.
    label:             string,
    // Format of the texture view. Either must be the same as the texture format
    // or in the list of `view_formats` in the texture's descriptor.
    format:            Texture_Format,
    // The dimension of the texture view. For 1D textures, this must be `D1`.
    // For 2D textures it must be one of `D2`, `D2_Array`, `Cube`, and
    // `Cube_Array`. For 3D textures it must be `D3`
    dimension:         Texture_View_Dimension,
    // The allowed usage(s) for the texture view. Must be a subset of the usage
    // flags of the texture. If not provided, defaults to the full set of usage
    // flags of the texture.
    usage:             Texture_Usages,
    // Aspect of the texture. Color textures must be `All`.
    aspect:            Texture_Aspect,
    // Base mip level.
    base_mip_level:    u32,
    // Mip level count.
    //
    // If non-zero, `base_mip_level + mip_level_count` must be less than or equal
    // to the underlying texture mip count. If zero, includes all remaining mipmap
    // levels, but at least 1 in total.
    mip_level_count:   u32,
    // Base array layer.
    base_array_layer:  u32,
    // Layer count.
    //
    // If non-zero, `base_array_layer + array_layer_count` must be less or equal
    // to the underlying array count. If zero, considered to include the rest
    // of the array layers, but at least 1 in total.
    array_layer_count: u32,
}

DEFAULT_TEXTURE_VIEW_DESCRIPTOR :: Texture_View_Descriptor {
    label             = "",
    format            = .Undefined,
    dimension         = .D2,
    base_mip_level    = 0,
    mip_level_count   = MIP_LEVEL_COUNT_UNDEFINED,
    base_array_layer  = 0,
    array_layer_count = ARRAY_LAYER_COUNT_UNDEFINED,
    aspect            = .All,
    usage             = {},
}

texture_view_set_label: proc(texture_view: Texture_View, label: string, loc := #caller_location)

texture_view_add_ref: proc(texture_view: Texture_View, loc := #caller_location)

texture_view_release: proc(texture_view: Texture_View, loc := #caller_location)
