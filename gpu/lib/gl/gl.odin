package gl

// Core
import "base:runtime"
import "core:mem"
import "core:strconv"
import "core:strings"

ExtensionSet :: map[string]struct{}

Version :: struct {
    major:       u32,
    minor:       u32,
    is_embedded: bool,
    revision:    u32,
    vendor_info: string,
}

ContextBase :: struct {
    version:    Version,
    extensions: ExtensionSet,
    arena_buf:  []byte,
    arena:      mem.Arena,
    allocator:  runtime.Allocator,
}

ShaderPrecisionFormat :: struct {
    // The base 2 log of the absolute value of the minimum value that can be represented
    range_min: i32,
    // The base 2 log of the absolute value of the maximum value that can be represented.
    range_max: i32,
    // The number of bits of precision that can be represented.
    // For integer formats this value is always 0.
    precision: i32,
}

BufferRange :: struct {
    start, end: uintptr,
}

BufferOffset :: uintptr

PixelPackData :: union {
    BufferOffset,
    []u8,
}

PixelUnpackData :: union {
    BufferOffset,
    []u8,
}

CompressedPixelUnpackData :: union {
    BufferRange,
    []u8,
}

ProgramBinary :: struct {
    buffer: []u8,
    format: u32,
}

Shader            :: distinct u32
Program           :: distinct u32
Buffer            :: distinct u32
VertexArray       :: distinct u32
Texture           :: distinct u32
Sampler           :: distinct u32
Fence             :: distinct rawptr
Framebuffer       :: distinct u32
Renderbuffer      :: distinct u32
Query             :: distinct u32
TransformFeedback :: distinct u32
UniformLocation   :: distinct u32

sync_t :: distinct rawptr
debug_proc_t :: #type proc "c" (
    source: u32,
    type: u32,
    id: u32,
    severity: u32,
    length: i32,
    message: cstring,
    userParam: rawptr)

version :: proc "contextless"() -> Version {
    return ctx.version
}

version_pack :: #force_inline proc "contextless" (major, minor: u8) -> int {
    return int(major) * 100 + int(minor)
}

supported_extensions :: proc "contextless" () -> ExtensionSet {
    return ctx.extensions
}

version_parse :: proc(
    src: string,
    allocator := context.allocator,
) -> (
    version: Version,
    ok: bool,
) {
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(
        ignore = allocator == ta || context.allocator == ta)

    s := src

    WEBGL_SIG :: "WebGL "
    ES_SIG    :: " ES "
    GLSL_SIG  :: "GLSL ES "

    is_webgl := strings.has_prefix(s, WEBGL_SIG)
    is_es    := false

    if is_webgl {
        pos := strings.last_index(s, WEBGL_SIG)
        if pos < 0 { pos = 0 }
        s = s[pos + len(WEBGL_SIG):]
        is_es = true
    } else {
        pos := strings.last_index(s, ES_SIG)
        if pos >= 0 {
            s = s[pos + len(ES_SIG):]
            is_es = true
        }
    }

    is_glsl := false
    if pos := strings.index(s, GLSL_SIG); pos >= 0 {
        s = s[pos + len(GLSL_SIG):]
        is_glsl = true
    }

    version_str: string
    vendor_info: string
    if sp := strings.index_byte(s, ' '); sp >= 0 {
        version_str = s[:sp]
        vendor_info = strings.clone(s[sp + 1:], allocator)
    } else {
        version_str = s
        vendor_info = ""
    }

    parts := strings.split(version_str, ".", ta)

    if len(parts) < 2 { return }

    major, major_ok := strconv.parse_uint(parts[0])
    if !major_ok { return }

    minor_s := parts[1]
    if len(minor_s) == 0 { return }
    if minor_s[0] == '0' {
        minor_s = "0"
    } else {
        minor_s = strings.trim_right(minor_s, "0")
    }
    minor, minor_ok := strconv.parse_uint(minor_s)
    if !minor_ok { return }

    revision: u32
    if !is_webgl && len(parts) >= 3 {
        if rev, rev_ok := strconv.parse_uint(parts[2]); rev_ok {
            revision = u32(rev)
        }
    }

    version = {
        major       = u32(major + 1 if is_webgl && !is_glsl else major),
        minor       = u32(minor),
        is_embedded = is_es,
        revision    = revision,
        vendor_info = vendor_info,
    }

    return version, true
}
