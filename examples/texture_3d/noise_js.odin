#+build js
package texture_3d

// JavaScript targets do not support core:thread. Generate the volume serially
// using the same per-slice routine as the native worker implementation.
generate_noise_texture_data :: proc(noise: ^Perlin_Noise, data: []u8) {
    for z in 0..<NOISE_TEX_DEPTH {
        generate_noise_slice(noise, data, z)
    }
}
