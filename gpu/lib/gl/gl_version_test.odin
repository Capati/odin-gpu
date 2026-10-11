#+build !js
package gl

// Core
import "core:testing"

@(test)
test_version_parse :: proc(t: ^testing.T) {
    context.allocator = context.temp_allocator

    // error cases
    _, ok := version_parse("1")
    testing.expect(t, !ok, "\"1\" should fail")

    _, ok  = version_parse("1.")
    testing.expect(t, !ok, "\"1.\" should fail")

    _, ok  = version_parse("1 h3l1o. W0rld")
    testing.expect(t, !ok)

    _, ok  = version_parse("1. h3l1o. W0rld")
    testing.expect(t, !ok)

    check :: proc(t: ^testing.T, src: string, expected: Version) {
        got, ok := version_parse(src)
        testing.expect(t, ok, src)
        testing.expect_value(t, got, expected)
    }

    check(t, "1.2.3",
        {major=1, minor=2, revision=3, vendor_info=""})
    check(t, "1.2",
        {major=1, minor=2, revision=0, vendor_info=""})
    check(t, "1.2 h3l1o. W0rld",
        {major=1, minor=2, vendor_info="h3l1o. W0rld"})
    check(t, "1.2.h3l1o. W0rld",
        {major=1, minor=2, vendor_info="W0rld"})
    check(t, "1.2. h3l1o. W0rld",
        {major=1, minor=2, vendor_info="h3l1o. W0rld"})
    check(t, "1.2.3.h3l1o. W0rld",
        {major=1, minor=2, revision=3, vendor_info="W0rld"})
    check(t, "1.2.3 h3l1o. W0rld",
        {major=1, minor=2, revision=3, vendor_info="h3l1o. W0rld"})
    check(t, "OpenGL ES 3.1",
        {major=3, minor=1, is_embedded=true, vendor_info=""})
    check(t, "OpenGL ES 2.0 Google Nexus",
        {major=2, minor=0, is_embedded=true, vendor_info="Google Nexus"})
    check(t, "GLSL ES 1.1",
        {major=1, minor=1, is_embedded=true, vendor_info=""})
    check(t, "OpenGL ES GLSL ES 3.20",
        {major=3, minor=2, is_embedded=true, vendor_info=""})
    // WebGL 2.0 → OpenGL ES 3.0
    check(t, "WebGL 2.0 (OpenGL ES 3.0 Chromium)",
        {major=3, minor=0, is_embedded=true, vendor_info="(OpenGL ES 3.0 Chromium)"})
    check(t, "WebGL GLSL ES 3.00 (OpenGL ES GLSL ES 3.0 Chromium)",
        {major=3, minor=0, is_embedded=true, vendor_info="(OpenGL ES GLSL ES 3.0 Chromium)"})
}
