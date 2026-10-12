#+build js
package application

// Core
import "core:fmt"
import "core:image"
import "base:runtime"

import _ "core:image/jpeg"
import _ "core:image/png"

// Decoded RGBA pixels plus dimensions, allocated with the caller's allocator.
Decoded_Image :: struct {
    width:    int,
    height:   int,
    channels: int,
    pixels:   []byte,
}

// The web build cannot link vendor:stb/image, so only core:image (which
// compiles to wasm) is used here. Progressive JPEGs are rejected by the core
// decoder; the fallback is the per-slot default texture.
decode_image_bytes :: proc(
    encoded: []u8,
    allocator: runtime.Allocator,
) -> (decoded: Decoded_Image, reason: string, ok: bool) {
    img, err := image.load_from_bytes(encoded, {.alpha_add_if_missing}, allocator)
    if err != nil {
        return {}, fmt.tprint(err), false
    }
    width := img.width
    height := img.height
    if img.channels != 4 {
        image.destroy(img, allocator)
        return {}, fmt.aprintf("decoded %dx%dx%d", width, height, img.channels), false
    }
    // Copy the decoded pixels out before destroying the image: core:image does
    // not free its decoder-allocated buffers on its own.
    pixels := make([]byte, len(img.pixels.buf), allocator)
    copy(pixels, img.pixels.buf[:])
    image.destroy(img, allocator)
    return {
        width    = width,
        height   = height,
        channels = 4,
        pixels   = pixels,
    }, "", true
}