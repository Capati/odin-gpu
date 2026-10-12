package gpu

// Core
import "core:slice"
// import "core:sync"

// dhm_resource_add :: proc(self: ^$D/DHM_Resource($T, $Handle_Type), )

Downlevel_Feature :: enum u32 {
    // The device supports compiling and using compute shaders.
    //
    // WebGL2, and GLES3.0 devices do not support compute.
    Compute_Shaders,
    // Supports binding storage buffers and textures to fragment shaders.
    Fragment_Writable_Storage,
    // Supports indirect drawing and dispatching.
    //
    // `Compute_Shaders` must be present for this flag.
    //
    // WebGL2, GLES 3.0, and Metal on Apple1/Apple2 GPUs do not support indirect.
    Indirect_Execution,
    // Supports non-zero `base_vertex` parameter to direct indexed draw calls.
    //
    // Indirect calls, if supported, always support non-zero `base_vertex`.
    //
    // Supported by:
    //
    // - Vulkan
    // - DX12
    // - Metal on Apple3+ or Mac1+
    // - OpenGL 3.2+
    // - OpenGL ES 3.2
    Base_Vertex,
    // Supports reading from a depth/stencil texture while using it as a read-only
    // depth/stencil attachment.
    //
    // The WebGL2 and GLES backends do not support RODS.
    Read_Only_Depth_Stencil,
    // Supports textures with mipmaps which have a non power of two size.
    Non_Power_Of_Two_Mipmapped_Textures,
    // Supports textures that are cube arrays.
    Cube_Array_Textures,
    // Supports comparison samplers.
    Comparison_Samplers,
    // Supports different blend operations per color attachment.
    Independent_Blend,
    // Supports storage buffers in vertex shaders.
    Vertex_Storage,

    // Supports samplers with anisotropic filtering. Note this isn't actually required by
    // WebGPU, the implementation is allowed to completely ignore aniso clamp. This flag is
    // here for native backends so they can communicate to the user of aniso is enabled.
    //
    // All backends and all devices support anisotropic filtering.
    Anisotropic_Filtering,

    // Supports storage buffers in fragment shaders.
    Fragment_Storage,

    // Supports sample-rate shading.
    Multisampled_Shading,

    // Supports copies between depth textures and buffers.
    //
    // GLES/WebGL don't support this.
    Depth_Texture_And_Buffer_Copies,

    // Supports all the texture usages described in WebGPU. If this isn't
    // supported, you should call `get_texture_format_features` to get how you
    // can use textures of a given format
    Webgpu_Texture_Format_Support,

    // Supports buffer bindings with sizes that aren't a multiple of 16.
    //
    // WebGL doesn't support this.
    Buffer_Bindings_Not_16_Byte_Aligned,

    // Supports buffers to combine usages `Index` with usages other than
    // `Copy_Dst` and `Copy_Src`. Furthermore, in absence of this feature it is
    // not allowed to copy index buffers from/to buffers with a set of usage
    // flags containing `Vertex`, `Uniform`, `Storage` or `Indirect`.
    //
    // WebGL doesn't support this.
    Unrestricted_Index_Buffer,

    // Supports full 32-bit range indices (2^32-1 as opposed to 2^24-1 without this flag)
    //
    // Corresponds to Vulkan's `VkPhysicalDeviceFeatures.fullDrawIndexUint32`
    Full_Draw_Index_Uint32,

    // Supports depth bias clamping
    //
    // Corresponds to Vulkan's `VkPhysicalDeviceFeatures.depthBiasClamp`
    Depth_Bias_Clamp,

    // Supports specifying which view format values are allowed when
    // create_view() is called on a texture.
    //
    // The WebGL and GLES backends doesn't support this.
    View_Formats,

    // With this feature not present, there are the following restrictions on
    // `queue_copy_external_image_to_texture`:
    //
    // - `Copy_External_Image_Source_Info.origin` must be zero.
    // - `Copy_External_Image_Dest_Info.color_space` must be srgb.
    //
    // If the source is an `Image_Bitmap`:
    //
    //  - `Copy_External_Image_Source_Info.flip_y` must be false.
    //  - `Copy_External_Image_Dest_Info.premultiplied_alpha` must be false.
    //
    // WebGL doesn't support this. WebGPU does.
    Unrestricted_External_Texture_Copies,

    // Supports specifying which view formats are allowed when calling create_view on the texture returned by
    // `Surface::get_current_texture`.
    //
    // The GLES/WebGL and Vulkan on Android doesn't support this.
    Surface_View_Formats,

    // If this is true, calls to `command_encoder_resolve_query_set` will be
    // performed on the queue timeline.
    //
    // If this is false, calls to `command_encoder_resolve_query_set` will be
    // performed on the device (i.e. cpu) timeline and will block that timeline
    // until the query has data. You may work around this limitation by waiting
    // until the submit whose queries you are resolving is fully finished
    // (through use of `queue.on_submitted_work_done`) and only then submitting
    // the resolve_query_set command. The queries will be guaranteed finished,
    // so will not block.
    //
    // Supported by:
    //
    // - Vulkan,
    // - DX12
    // - Metal
    // - OpenGL 4.4+
    //
    // Not Supported by:
    //
    // - GL ES / WebGL
    Nonblocking_Query_Resolve,

    // Allows shaders to use `quantizeToF16`, `pack2x16float`, and `unpack2x16float`, which
    // operate on `f16`-precision values stored in `f32`s.
    //
    // Not supported by Vulkan on Mesa when `Shader_F16` feature is absent.
    Shader_F16_In_F32,

    // Supports features introduced in MSL 2.1.
    Msl2_1,

    // The adapter supports the WebGPU texture compression requirement:
    // BC || (ETC2 && ASTC).
    //
    // See https://www.w3.org/TR/webgpu/#adapter-capability-guarantees.
    Texture_Compression,

    // Supports `@interpolate(linear)` (a.k.a. `noperspective`) on shader inter-stage
    // variables.
    //
    // GLSL ES has no `noperspective` qualifier, so the GLES backend only supports this
    // on desktop OpenGL, not on GLES/WebGL2.
    Linear_Interpolation,
}

// Binary flags listing features that may or may not be present on downlevel adapters.
Downlevel_Features :: distinct bit_set[Downlevel_Feature;u32]

has_features :: proc(
    available: []Feature_Name,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    for feature in features {
        _, found := slice.binary_search(available, feature)
        if !found {
            return false
        }
    }
    return true
}

has_any_features :: proc(
    available: []Feature_Name,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    for feature in features {
        if _, found := slice.binary_search(available, feature); found {
            return true
        }
    }
    return false
}
