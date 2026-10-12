package gpu

// Handle to an external texture on the GPU.
//
// It can be created with `device_create_external_texture`.
//
// Corresponds to [WebGPU
// `GPUExternalTexture`](https://gpuweb.github.io/gpuweb/#gpuexternaltexture).
External_Texture :: distinct Handle

external_texture_set_label: proc(
    external_texture: External_Texture,
    label: string,
    loc := #caller_location,
)

external_texture_add_ref: proc(external_texture: External_Texture, loc := #caller_location)

external_texture_release: proc(external_texture: External_Texture, loc := #caller_location)
