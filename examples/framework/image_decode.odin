package application

// Core
import "core:log"
import "core:image"
import "base:runtime"

import _ "core:image/jpeg"
import _ "core:image/png"

Decoded_Image :: struct {
    width:    int,
    height:   int,
    channels: int,
    pixels:   []byte,
}

@(require_results)
decode_image_bytes :: proc(
    encoded: []u8,
    allocator: runtime.Allocator,
) -> (
    decoded: Decoded_Image,
    ok: bool,
) #optional_ok {
    img, err := image.load_from_bytes(encoded, {.alpha_add_if_missing}, allocator)
    if err != nil {
        log.errorf("Failed to load image from bytes: %v", err)
        return
    }

    width := img.width
    height := img.height
    if img.channels != 4 {
        image.destroy(img, allocator)
        log.errorf("Failed to load image from bytes: decoded %dx%dx%d",
            width, height, img.channels)
        return
    }

    // Copy the decoded pixels out before destroying the image
    pixels := make([]byte, len(img.pixels), allocator)
    copy(pixels, img.pixels[:])
    image.destroy(img, allocator)

    decoded = {
        width    = width,
        height   = height,
        channels = 4,
        pixels   = pixels,
    }

    return decoded, true
}
