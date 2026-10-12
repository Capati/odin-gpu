#+build !js
package application

// Core
import "core:c"
import "core:fmt"
import "core:image"
import "core:mem"
import "base:runtime"

// Third-party
import stbi "vendor:stb/image"

import _ "core:image/jpeg"
import _ "core:image/png"

// Decoded RGBA pixels plus dimensions, allocated with the caller's allocator.
Decoded_Image :: struct {
    width:    int,
    height:   int,
    channels: int,
    pixels:   []byte,
}

// Decodes an encoded image to RGBA. JPEG is handed to vendor:stb/image first,
// whose decoder also accepts progressive (SOF2) frames that core:image rejects;
// the stb result is copied into `allocator` memory and its C buffer freed. Any
// other format, and any stb failure, falls back to core:image with its
// registered plugins. `reason` explains a failure for the caller's warning.
decode_image_bytes :: proc(
    encoded: []u8,
    allocator: runtime.Allocator,
) -> (decoded: Decoded_Image, reason: string, ok: bool) {
    if len(encoded) >= 3 && encoded[0] == 0xFF && encoded[1] == 0xD8 && encoded[2] == 0xFF {
        x, y, file_channels: c.int
        data := stbi.load_from_memory(&encoded[0], c.int(len(encoded)), &x, &y, &file_channels, 4)
        if data != nil {
            pixel_count := int(x) * int(y) * 4
            decoded.pixels = make([]byte, pixel_count, allocator)
            mem.copy(raw_data(decoded.pixels), rawptr(data), pixel_count)
            stbi.image_free(data)
            decoded.width = int(x)
            decoded.height = int(y)
            decoded.channels = 4
            return decoded, "", true
        }
        if r := stbi.failure_reason(); r != nil {
            reason = string(cstring(r))
        } else {
            reason = "stb_image decode failed"
        }
        return {}, reason, false
    }

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