#+build !js
package gl

// Core
import "base:runtime"
import "core:mem"
import "core:strings"

// Vendor
import gl "vendor:OpenGL"

Context :: struct {
    using base: ContextBase,
}

@private
ctx: Context

Set_Proc_Address_Type :: gl.Set_Proc_Address_Type

// -----------------------------------------------------------------------------
// Missing functions
// -----------------------------------------------------------------------------

glGenQueriesEXT: proc "c" (n: i32, ids: [^]u32)
glDebugMessageCallbackKHR: proc "c" (
    callback:   debug_proc_t,
    user_param: rawptr)
glDeleteQueriesEXT: proc "c" (n: i32, ids: [^]u32)
glBeginQueryEXT: proc "c" (target: u32, id: u32)
glGenVertexArraysAPPLE: proc "c" (n: i32, arrays: [^]u32)
glGenVertexArraysOES: proc "c" (n: i32, arrays: [^]u32)
glBindVertexArrayAPPLE: proc "c" (array: u32)
glBindVertexArrayOES: proc "c" (array: u32)
glDeleteVertexArraysOES: proc "c" (n: i32, arrays: [^]u32)
glDeleteVertexArraysAPPLE: proc "c" (n: i32, arrays: [^]u32)

glObjectLabelKHRType :: #type proc "c" (
    identifier: u32,
    name: u32,
    length: i32,
    label: cstring)
glObjectLabelKHR: #type proc "c" (
    identifier: u32,
    name: u32,
    length: i32,
    label: cstring)

glFramebufferTexture2DMultisampleEXT: proc "c" (
    target:     u32,
    attachment: u32,
    textarget:  u32,
    texture:    u32,
    level:      i32,
    samples:    i32,
)

// Load EXT and KHR function pointers missing from the bindings.
load_ext_khr_functions :: proc(set_proc_address: gl.Set_Proc_Address_Type) {
    set_proc_address(&glBeginQueryEXT, "glBeginQueryEXT")
    set_proc_address(&glBindVertexArrayAPPLE, "glBindVertexArrayAPPLE")
    set_proc_address(&glBindVertexArrayOES, "glBindVertexArrayOES")
    set_proc_address(&glDebugMessageCallbackKHR, "glDebugMessageCallbackKHR")
    set_proc_address(&glDeleteQueriesEXT, "glDeleteQueriesEXT")
    set_proc_address(&glDeleteVertexArraysAPPLE, "glDeleteVertexArraysAPPLE")
    set_proc_address(&glDeleteVertexArraysOES, "glDeleteVertexArraysOES")
    set_proc_address(&glFramebufferTexture2DMultisampleEXT, "glFramebufferTexture2DMultisampleEXT")
    set_proc_address(&glGenQueriesEXT, "glGenQueriesEXT")
    set_proc_address(&glGenVertexArraysAPPLE, "glGenVertexArraysAPPLE")
    set_proc_address(&glGenVertexArraysOES, "glGenVertexArraysOES")
    set_proc_address(&glObjectLabelKHR, "glObjectLabelKHR")
}

// -----------------------------------------------------------------------------
// Context
// -----------------------------------------------------------------------------

init_context :: proc(
    major, minor: int,
    set_proc_address: gl.Set_Proc_Address_Type,
    loc := #caller_location,
) -> (ok: bool) {
    gl.load_up_to(major, minor, set_proc_address)
    load_ext_khr_functions(set_proc_address)

    assert(gl.GetString != nil,
        "Reading gl.VERSION failed. Make sure there is a valid GL context currently active.", loc)

    ctx.allocator = runtime.default_allocator()

    version_str := string(gl.GetString(gl.VERSION))
    ctx.version = version_parse(version_str, ctx.allocator) or_return

    // Initialize an arena allocator with enough space to clone the supported
    // extensions strings.
    ctx.arena_buf = make([]byte, 256 * mem.Kilobyte, ctx.allocator)
    defer if !ok { delete(ctx.arena_buf) }
    mem.arena_init(&ctx.arena, ctx.arena_buf)

    ctx.extensions = make(ExtensionSet, ctx.allocator)

    buf_allocator := mem.arena_allocator(&ctx.arena)
    if ctx.version.major >= 3 {
        num_extensions: i32
        gl.GetIntegerv(gl.NUM_EXTENSIONS, &num_extensions)
        for i in 0..< num_extensions {
            ext_cstr := gl.GetStringi(gl.EXTENSIONS, u32(i))
            ext := strings.clone_from_cstring(ext_cstr, buf_allocator)
            ctx.extensions[ext] = {}
        }
    }

    return true
}

deinit_context :: proc() {
    context.allocator = ctx.allocator
    delete(ctx.extensions)
    delete(ctx.arena_buf)
}

supports_debug :: proc "contextless" () -> bool {
    if "GL_KHR_debug" in ctx.extensions {
        return true
    } else if ctx.version.is_embedded {
        // GL ES >= 3.2
        return ctx.version.major == 3 && ctx.version.minor >= 2
    } else {
        // GL >= 4.3
        return ctx.version.major == 4 && ctx.version.minor >= 3
    }
}

// -----------------------------------------------------------------------------
// API
// -----------------------------------------------------------------------------

create_framebuffer :: proc "contextless" () -> Framebuffer {
    name: u32 = ---
    gl.GenFramebuffers(1, &name)
    return Framebuffer(name)
}

create_named_framebuffer :: proc "contextless" () -> Framebuffer {
    name: u32 = ---
    gl.CreateFramebuffers(1, &name)
    return Framebuffer(name)
}

is_framebuffer :: proc "contextless" (framebuffer: Framebuffer) -> bool {
    return gl.IsFramebuffer(u32(framebuffer))
}

create_query :: proc "contextless" () -> Query {
    name: u32 = ---
    if gl.GenQueries != nil {
        gl.GenQueries(1, &name)
    } else {
        glGenQueriesEXT(1, &name)
    }
    return Query(name)
}

create_renderbuffer :: proc "contextless" () -> Renderbuffer {
    name: u32 = ---
    gl.GenRenderbuffers(1, &name)
    return Renderbuffer(name)
}

is_renderbuffer :: proc "contextless" (renderbuffer: Renderbuffer) -> bool {
    return gl.IsRenderbuffer(u32(renderbuffer))
}

create_sampler :: proc "contextless" () -> Sampler {
    name: u32 = ---
    gl.GenSamplers(1, &name)
    return Sampler(name)
}

create_shader :: proc "contextless" (shader_type: u32) -> Shader {
    return Shader(gl.CreateShader(shader_type))
}

is_shader :: proc "contextless" (shader: Shader) -> bool {
    return gl.IsShader(u32(shader))
}

create_texture :: proc "contextless" () -> Texture {
    name: u32 = ---
    gl.GenTextures(1, &name)
    return Texture(name)
}

create_named_texture :: proc "contextless" (target: u32) -> Texture {
    name: u32 = ---
    gl.CreateTextures(target, 1, &name)
    return Texture(name)
}

is_texture :: proc "contextless" (texture: Texture) -> bool {
    return gl.IsTexture(u32(texture))
}

delete_shader :: proc "contextless" (shader: Shader) {
    gl.DeleteShader(u32(shader))
}

shader_source :: proc "contextless" (shader: Shader, source: string) {
    length := i32(len(source))
    shader_source := cstring(raw_data(source))
    gl.ShaderSource(u32(shader), 1, &shader_source, &length)
}

compile_shader :: proc "contextless" (shader: Shader) {
    gl.CompileShader(u32(shader))
}

get_shader_completion_status :: proc "contextless" (shader: Shader) -> bool {
    status: i32
    gl.GetShaderiv(u32(shader), COMPLETION_STATUS, &status)
    return status == 1
}

get_shader_compile_status :: proc "contextless" (shader: Shader) -> bool {
    status: i32
    gl.GetShaderiv(u32(shader), COMPILE_STATUS, &status)
    return status == 1
}

get_shader_info_log :: proc "contextless" (shader: Shader, buf: []u8) -> string {
    length: i32
    gl.GetShaderiv(u32(shader), INFO_LOG_LENGTH, &length)
    if length == 0 {
        return ""
    }
    gl.GetShaderInfoLog(u32(shader), length, &length, raw_data(buf))
    return string(buf[:length])
}

get_shader_precision_format :: proc "contextless" (
    shader_type: u32,
    precision_mode: u32,
) -> ShaderPrecisionFormat {
    if gl.GetShaderPrecisionFormat != nil {
        range: [2]i32
        precision: i32
        gl.GetShaderPrecisionFormat(shader_type, precision_mode, raw_data(range[:]), &precision)
        if range[1] != 0 {
            return {
                range_min = range[0],
                range_max = range[1],
                precision = precision,
            }
        }
    }
    return {}
}

get_tex_image :: proc "contextless" (
    target: u32,
    level: i32,
    format: u32,
    type: u32,
    pixels: PixelPackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(p)
    }
    gl.GetTexImage(target, level, format, type, ptr)
}

create_program :: proc() -> Program {
    return Program(gl.CreateProgram())
}

is_program :: proc(program: Program) -> bool {
    return gl.IsProgram(u32(program))
}

delete_program :: proc(program: Program) {
    gl.DeleteProgram(u32(program))
}

attach_shader :: proc "contextless" (program: Program, shader: Shader) {
    gl.AttachShader(u32(program), u32(shader))
}

detach_shader :: proc "contextless" (program: Program, shader: Shader) {
    gl.DetachShader(u32(program), u32(shader))
}

link_program :: proc "contextless" (program: Program) {
    gl.LinkProgram(u32(program))
}

validate_program :: proc "contextless" (program: Program) {
    gl.ValidateProgram(u32(program))
}

get_program_completion_status :: proc "contextless" (program: Program) -> bool {
    status: i32
    gl.GetProgramiv(u32(program), COMPLETION_STATUS, &status)
    return status == 1
}

get_program_link_status :: proc "contextless" (program: Program) -> bool {
    status: i32
    gl.GetProgramiv(u32(program), LINK_STATUS, &status)
    return status == 1
}

get_program_validate_status :: proc "contextless" (program: Program) -> bool {
    status: i32
    gl.GetProgramiv(u32(program), VALIDATE_STATUS, &status)
    return status == 1
}

get_program_parameter_i32 :: proc "contextless" (program: Program, parameter: u32) -> i32 {
    value: i32
    gl.GetProgramiv(u32(program), parameter, &value)
    return value
}

get_program_info_log :: proc "contextless" (program: Program, buf: []u8) -> string {
    length: i32
    gl.GetProgramiv(u32(program), INFO_LOG_LENGTH, &length)
    if length == 0 {
        return ""
    }
    gl.GetProgramInfoLog(u32(program), length, &length, raw_data(buf))
    return string(buf[:length])
}

get_program_resource_i32_alloc :: proc(
    program: u32,
    interface: u32,
    index: u32,
    properties: []u32,
    allocator := context.allocator,
) -> []i32 {
    // query the number of output parameters first
    length: i32
    gl.GetProgramResourceiv(
        program,
        interface,
        index,
        i32(len(properties)),
        raw_data(properties),
        0,
        &length,
        nil,
    )

    // get the parameter values
    params := make([]i32, length, allocator)
    gl.GetProgramResourceiv(
        program,
        interface,
        index,
        i32(len(properties)),
        raw_data(properties),
        length,
        &length,
        raw_data(params),
    )
    return params
}

get_program_resource_i32_buf :: proc "contextless" (
    program: u32,
    interface: u32,
    index: u32,
    properties: []u32,
    buf: []i32,
) -> []i32 {
    length: i32
    gl.GetProgramResourceiv(
        program, interface, index,
        i32(len(properties)), raw_data(properties),
        0, &length, nil,
    )
    gl.GetProgramResourceiv(
        program, interface, index,
        i32(len(properties)), raw_data(properties),
        i32(len(buf)), &length, raw_data(buf),
    )
    return buf[:length]
}

get_program_resource_i32 :: proc {
    get_program_resource_i32_alloc,
    get_program_resource_i32_buf,
}

program_uniform_1_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
) {
    gl.ProgramUniform1i(u32(program), location, x)
}

program_uniform_2_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
) {
    gl.ProgramUniform2i(u32(program), location, x, y)
}

program_uniform_3_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
    z: i32,
) {
    gl.ProgramUniform3i(u32(program), location, x, y, z)
}

program_uniform_4_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
    z: i32,
    w: i32,
) {
    gl.ProgramUniform4i(u32(program), location, x, y, z, w)
}

program_uniform_1_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    gl.ProgramUniform1iv(u32(program), location, i32(len(v)), raw_data(v))
}

program_uniform_2_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    gl.ProgramUniform2iv(
        u32(program),
        location,
        i32(len(v)) / 2,
        raw_data(v),
    )
}

program_uniform_3_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    gl.ProgramUniform3iv(
        u32(program),
        location,
        i32(len(v)) / 3,
        raw_data(v),
    )
}

program_uniform_4_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    gl.ProgramUniform4iv(
        u32(program),
        location,
        i32(len(v)) / 4,
        raw_data(v),
    )
}

program_uniform_1_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
) {
    gl.ProgramUniform1ui(u32(program), location, x)
}

program_uniform_2_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
) {
    gl.ProgramUniform2ui(u32(program), location, x, y)
}

program_uniform_3_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
    z: u32,
) {
    gl.ProgramUniform3ui(u32(program), location, x, y, z)
}

program_uniform_4_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
    z: u32,
    w: u32,
) {
    gl.ProgramUniform4ui(u32(program), location, x, y, z, w)
}

program_uniform_1_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    gl.ProgramUniform1uiv(u32(program), location, i32(len(v)), raw_data(v))
}

program_uniform_2_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    gl.ProgramUniform2uiv(
        u32(program),
        location,
        i32(len(v)) / 2,
        raw_data(v),
    )
}

program_uniform_3_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    gl.ProgramUniform3uiv(
        u32(program),
        location,
        i32(len(v)) / 3,
        raw_data(v),
    )
}

program_uniform_4_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    gl.ProgramUniform4uiv(
        u32(program),
        location,
        i32(len(v)) / 4,
        raw_data(v),
    )
}

program_uniform_1_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
) {
    gl.ProgramUniform1f(u32(program), location, x)
}

program_uniform_2_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
) {
    gl.ProgramUniform2f(u32(program), location, x, y)
}

program_uniform_3_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
    z: f32,
) {
    gl.ProgramUniform3f(u32(program), location, x, y, z)
}

program_uniform_4_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
    z: f32,
    w: f32,
) {
    gl.ProgramUniform4f(u32(program), location, x, y, z, w)
}

program_uniform_1_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    gl.ProgramUniform1fv(u32(program), location, i32(len(v)), raw_data(v))
}

program_uniform_2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    gl.ProgramUniform2fv(
        u32(program),
        location,
        i32(len(v)) / 2,
        raw_data(v),
    )
}

program_uniform_3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    gl.ProgramUniform3fv(
        u32(program),
        location,
        i32(len(v)) / 3,
        raw_data(v),
    )
}

program_uniform_4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    gl.ProgramUniform4fv(
        u32(program),
        location,
        i32(len(v)) / 4,
        raw_data(v),
    )
}

program_uniform_matrix_2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix2fv(
        u32(program),
        location,
        i32(len(v)) / 4,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_2x3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix2x3fv(
        u32(program),
        location,
        i32(len(v)) / 6,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_2x4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix2x4fv(
        u32(program),
        location,
        i32(len(v)) / 8,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_3x2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix3x2fv(
        u32(program),
        location,
        i32(len(v)) / 6,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix3fv(
        u32(program),
        location,
        i32(len(v)) / 9,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_3x4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix3x4fv(
        u32(program),
        location,
        i32(len(v)) / 12,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_4x2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix4x2fv(
        u32(program),
        location,
        i32(len(v)) / 8,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_4x3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix4x3fv(
        u32(program),
        location,
        i32(len(v)) / 12,
        transpose,
        raw_data(v),
    )
}

program_uniform_matrix_4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    gl.ProgramUniformMatrix4fv(
        u32(program),
        location,
        i32(len(v)) / 16,
        transpose,
        raw_data(v),
    )
}

program_binary_retrievable_hint :: proc "contextless" (program: Program, value: bool) {
    gl.ProgramParameteri(
        u32(program),
        PROGRAM_BINARY_RETRIEVABLE_HINT,
        i32(value),
    )
}

get_program_binary :: proc (
    program: Program,
    allocator := context.allocator,
) -> ProgramBinary {
    len: i32 = ---
    gl.GetProgramiv(u32(program), PROGRAM_BINARY_LENGTH, &len)

    format: u32
    buffer := make([]u8, len, allocator)

    gl.GetProgramBinary(
        u32(program),
        len,
        nil,
        &format,
        raw_data(buffer),
    )

    return { buffer, format }
}

program_binary :: proc "contextless" (program: Program, binary: ProgramBinary) {
    gl.ProgramBinary(
        u32(program),
        binary.format,
        raw_data(binary.buffer),
        i32(len(binary.buffer)),
    )
}

get_active_uniforms :: proc "contextless" (program: Program) -> u32 {
    count: i32 = ---
    gl.GetProgramiv(u32(program), ACTIVE_UNIFORMS, &count)
    return u32(count)
}

// TODO: get_active_uniforms_parameter - unimplemented

// TODO: get_active_uniform - unimplemented


use_program :: proc "contextless" (program: Program) {
    gl.UseProgram(u32(program))
}

create_buffer :: proc "contextless" () -> Buffer {
    buffer: u32 = ---
    gl.GenBuffers(1, &buffer)
    return Buffer(buffer)
}

// TODO: create_named_buffer - unimplemented

// TODO: is_buffer - unimplemented

bind_buffer :: proc "contextless" (target: u32, buffer: Buffer) {
    gl.BindBuffer(target, u32(buffer))
}

bind_buffer_base :: proc "contextless" (target: u32, index: u32, buffer: Buffer) {
    gl.BindBufferBase(target, index, u32(buffer))
}

bind_buffer_range :: proc "contextless" (
    target: u32,
    index: u32,
    buffer: Buffer,
    offset: i32,
    size: i32,
) {
    gl.BindBufferRange(
        target,
        index,
        u32(buffer),
        int(offset),
        int(size),
    )
}

bind_vertex_buffer :: proc "contextless" (
    binding_index: u32,
    buffer: Buffer,
    offset: i32,
    stride: i32,
) {
    gl.BindVertexBuffer(
        binding_index,
        u32(buffer),
        int(offset),
        stride,
    )
}

bind_framebuffer :: proc "contextless" (target: u32, framebuffer: Framebuffer) {
    gl.BindFramebuffer(target, u32(framebuffer))
}

bind_renderbuffer :: proc "contextless" (target: u32, renderbuffer: Renderbuffer) {
    gl.BindRenderbuffer(target, u32(renderbuffer))
}

blit_framebuffer :: proc "contextless" (
    src_x0: i32,
    src_y0: i32,
    src_x1: i32,
    src_y1: i32,
    dst_x0: i32,
    dst_y0: i32,
    dst_x1: i32,
    dst_y1: i32,
    mask: u32,
    filter: u32,
) {
    gl.BlitFramebuffer(
        src_x0, src_y0, src_x1, src_y1, dst_x0, dst_y0, dst_x1, dst_y1, mask, filter,
    )
}

// TODO: blit_named_framebuffer - unimplemented

create_vertex_array :: proc "contextless" () -> VertexArray {
    vertex_array: u32 = ---
    if gl.GenVertexArrays != nil {
        gl.GenVertexArrays(1, &vertex_array)
    } else {
        when ODIN_OS == .Darwin {
            glGenVertexArraysAPPLE(1, &vertex_array)
        } else {
            glGenVertexArraysOES(1, &vertex_array)
        }
    }
    return VertexArray(vertex_array)
}

// TODO: create_named_vertex_array - unimplemented

delete_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    vertex_array := u32(vertex_array)
    if gl.DeleteVertexArrays != nil {
        gl.DeleteVertexArrays(1, &vertex_array)
    } else {
        when ODIN_OS == .Darwin {
            glDeleteVertexArraysAPPLE(1, &vertex_array)
        } else {
            glDeleteVertexArraysOES(1, &vertex_array)
        }
    }
}

bind_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    if gl.BindVertexArray != nil {
        gl.BindVertexArray(u32(vertex_array))
    } else {
        when ODIN_OS == .Darwin {
            glBindVertexArrayAPPLE(u32(vertex_array))
        } else {
            glBindVertexArrayOES(u32(vertex_array))
        }
    }
}

// clear_color :: proc "contextless" (red: f32, green: f32, blue: f32, alpha: f32) {
//     gl.ClearColor(red, green, blue, alpha)
// }

supports_f64_precision :: proc "contextless" () -> bool {
    return !ctx.version.is_embedded
}

clear_depth_f64 :: proc "contextless" (depth: f64) {
    gl.ClearDepth(depth)
}

clear_depth_f32 :: proc "contextless" (depth: f32) {
    gl.ClearDepthf(depth)
}

clear_depth :: proc "contextless" (depth: f64) {
    if supports_f64_precision() {
        clear_depth_f64(depth)
    } else {
        clear_depth_f32(f32(depth))
    }
}

clear_stencil :: proc "contextless" (stencil: i32) {
    gl.ClearStencil(stencil)
}

clear :: proc "contextless" (mask: u32) {
    gl.Clear(mask)
}

// patch_parameter_i32 :: proc "contextless" (parameter: u32, value: i32) {
//     gl.PatchParameteri(parameter, value)
// }

pixel_store_i32 :: proc "contextless" (parameter: u32, value: i32) {
    gl.PixelStorei(parameter, value)
}

pixel_store_bool :: proc "contextless" (parameter: u32, value: bool) {
    gl.PixelStorei(parameter, i32(value))
}

pixel_store :: proc {
    pixel_store_i32,
    pixel_store_bool,
}

// TODO: get_frag_data_location - unimplemented

// TODO: bind_frag_data_location - unimplemented

buffer_data_size :: proc "contextless" (target: u32, size: i32, usage: u32) {
    gl.BufferData(target, int(size), nil, usage)
}

// TODO: named_buffer_data_size - unimplemented

buffer_data_u8_slice :: proc "contextless" (target: u32, data: []u8, usage: u32) {
    gl.BufferData(
        target,
        int(len(data)),
        raw_data(data),
        usage,
    )
}

buffer_data :: proc {
    buffer_data_size,
    buffer_data_u8_slice,
}

// TODO: named_buffer_data_u8_slice - unimplemented

buffer_sub_data_u8_slice :: proc "contextless" (target: u32, offset: i32, src_data: []u8) {
    gl.BufferSubData(
        target,
        int(offset),
        len(src_data),
        raw_data(src_data),
    )
}

// TODO: named_buffer_sub_data_u8_slice - unimplemented

get_buffer_sub_data :: proc "contextless" (target: u32, offset: i32, dst_data: []u8) {
    gl.GetBufferSubData(
        target,
        int(offset),
        len(dst_data),
        raw_data(dst_data),
    )
}

// tex_buffer :: proc "contextless" (target: u32, internal_format: u32, buffer: Buffer) {
//     gl.TexBuffer(
//         target,
//         internal_format,
//         buffer,
//     )
// }

buffer_storage :: proc "contextless" (target: u32, size: i32, data: []u8, flags: u32) {
    if gl.BufferStorage != nil {
        gl.BufferStorage(target, int(size), raw_data(data), flags)
    }
    // TODO: BufferStorageEXT fallback
}

// TODO: named_buffer_storage - unimplemented

check_framebuffer_status :: proc "contextless" (target: u32) -> u32 {
    return gl.CheckFramebufferStatus(target)
}

// TODO: check_named_framebuffer_status - unimplemented

clear_buffer_i32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []i32) {
    gl.ClearBufferiv(target, i32(draw_buffer), raw_data(values))
}

clear_buffer_u32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []u32) {
    gl.ClearBufferuiv(target, i32(draw_buffer), raw_data(values))
}

clear_buffer_f32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []f32) {
    gl.ClearBufferfv(target, i32(draw_buffer), raw_data(values))
}

clear_buffer :: proc {
    clear_buffer_i32_slice,
    clear_buffer_u32_slice,
    clear_buffer_f32_slice,
}

// clear_buffer_depth_stencil :: proc "contextless" (
//     target: u32,
//     draw_buffer: u32,
//     depth: f32,
//     stencil: i32,
// ) {
//     gl.ClearBufferfi(target, draw_buffer as i32, depth, stencil)
// }

// TODO: clear_named_framebuffer_i32_slice - unimplemented

// TODO: clear_named_framebuffer_u32_slice - unimplemented

// TODO: clear_named_framebuffer_f32_slice - unimplemented

// TODO: clear_named_framebuffer_depth_stencil - unimplemented

// client_wait_sync :: proc "contextless" (fence: Fence, flags: u32, timeout: i32) -> u32 {
//     gl.ClientWaitSync(fence.0, flags, timeout as u64)
// }

// TODO: get_sync_parameter_i32 - unimplemented

// wait_sync :: proc "contextless" (fence: Fence, flags: u32, timeout: u64) {
//     gl.WaitSync(fence.0, flags, timeout)
// }

copy_buffer_sub_data :: proc "contextless" (
    src_target: u32,
    dst_target: u32,
    src_offset: i32,
    dst_offset: i32,
    size: i32,
) {
    gl.CopyBufferSubData(
        src_target,
        dst_target,
        int(src_offset),
        int(dst_offset),
        int(size),
    )
}

// TODO: copy_image_sub_data - unimplemented

// copy_tex_image_2d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     internal_format: u32,
//     x: i32,
//     y: i32,
//     width: i32,
//     height: i32,
//     border: i32,
// ) {
//     gl.CopyTexImage2D(target, level, internal_format, x, y, width, height, border)
// }

copy_tex_sub_image_2d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
) {
    gl.CopyTexSubImage2D(target, level, x_offset, y_offset, x, y, width, height)
}

copy_tex_sub_image_3d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    z_offset: i32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
) {
    gl.CopyTexSubImage3D(
        target, level, x_offset, y_offset, z_offset, x, y, width, height,
    )
}

delete_buffer :: proc "contextless" (buffer: Buffer) {
    buffer := u32(buffer)
    gl.DeleteBuffers(1, &buffer)
}

delete_framebuffer :: proc "contextless" (framebuffer: Framebuffer) {
    framebuffer := u32(framebuffer)
    gl.DeleteFramebuffers(1, &framebuffer)
}

delete_query :: proc "contextless" (query: Query) {
    query := u32(query)
    if gl.DeleteQueries != nil {
        gl.DeleteQueries(1, &query)
    } else {
        glDeleteQueriesEXT(1, &query)
    }
}

delete_renderbuffer :: proc "contextless" (renderbuffer: Renderbuffer) {
    renderbuffer := u32(renderbuffer)
    gl.DeleteRenderbuffers(1, &renderbuffer)
}

delete_sampler :: proc "contextless" (sampler: Sampler) {
    sampler := u32(sampler)
    gl.DeleteSamplers(1, &sampler)
}

delete_sync :: proc "contextless" (fence: Fence) {
    gl.DeleteSync(auto_cast fence)
}

delete_texture :: proc "contextless" (texture: Texture) {
    texture := u32(texture)
    gl.DeleteTextures(1, &texture)
}

disable :: proc "contextless" (parameter: u32) {
    gl.Disable(parameter)
}

disable_draw_buffer :: proc "contextless" (parameter: u32, draw_buffer: u32) {
    gl.Disablei(parameter, draw_buffer)
}

disable_vertex_attrib_array :: proc "contextless" (index: u32) {
    gl.DisableVertexAttribArray(index)
}

dispatch_compute :: proc "contextless" (groups_x: u32, groups_y: u32, groups_z: u32) {
    gl.DispatchCompute(groups_x, groups_y, groups_z)
}

dispatch_compute_indirect :: proc "contextless" (offset: i32) {
    gl.DispatchComputeIndirect(cast(^gl.DispatchIndirectCommand)uintptr(offset))
}

draw_arrays :: proc "contextless" (mode: u32, first: i32, count: i32) {
    gl.DrawArrays(mode, first, count)
}

draw_arrays_instanced :: proc "contextless" (
    mode: u32,
    first: i32,
    count: i32,
    instance_count: i32,
) {
    gl.DrawArraysInstanced(mode, first, count, instance_count)
}

draw_arrays_instanced_base_instance :: proc "contextless" (
    mode: u32,
    first: i32,
    count: i32,
    instance_count: i32,
    base_instance: u32,
) {
    gl.DrawArraysInstancedBaseInstance(
        mode,
        first,
        count,
        instance_count,
        base_instance,
    )
}

draw_arrays_indirect_offset :: proc "contextless" (mode: u32, offset: i32) {
    gl.DrawArraysIndirect(mode, cast(^gl.DrawArraysIndirectCommand)uintptr(offset))
}

// draw_buffer :: proc "contextless" (draw_buffer: u32) {
//     gl.DrawBuffer(draw_buffer)
// }

// TODO: named_framebuffer_draw_buffer - unimplemented

draw_buffers :: proc "contextless" (buffers: []u32) {
    gl.DrawBuffers(i32(len(buffers)), raw_data(buffers))
}

// TODO: named_framebuffer_draw_buffers - unimplemented

// TODO: draw_elements - unimplemented

// TODO: draw_elements_base_vertex - unimplemented

draw_elements_instanced :: proc "contextless" (
    mode: u32,
    count: i32,
    element_type: u32,
    offset: i32,
    instance_count: i32,
) {
    gl.DrawElementsInstanced(
        mode,
        count,
        element_type,
        rawptr(uintptr(offset)),
        instance_count,
    )
}

draw_elements_instanced_base_vertex :: proc "contextless" (
    mode: u32,
    count: i32,
    element_type: u32,
    offset: i32,
    instance_count: i32,
    base_vertex: i32,
) {
    gl.DrawElementsInstancedBaseVertex(
        mode,
        count,
        element_type,
        rawptr(uintptr(offset)),
        instance_count,
        base_vertex,
    )
}

draw_elements_instanced_base_vertex_base_instance :: proc "contextless" (
    mode: u32,
    count: i32,
    element_type: u32,
    offset: i32,
    instance_count: i32,
    base_vertex: i32,
    base_instance: u32,
) {
    gl.DrawElementsInstancedBaseVertexBaseInstance(
        mode,
        count,
        element_type,
        rawptr(uintptr(offset)),
        instance_count,
        base_vertex,
        base_instance,
    )
}

draw_elements_indirect_offset :: proc "contextless" (mode: u32, element_type: u32, offset: i32) {
    gl.DrawElementsIndirect(
        mode,
        element_type,
        cast(^gl.DrawElementsIndirectCommand)uintptr(offset),
    )
}

enable :: proc "contextless" (parameter: u32) {
    gl.Enable(parameter)
}

// is_enabled :: proc "contextless" (parameter: u32) -> bool {
//     gl.IsEnabled(parameter) != 0
// }

enable_draw_buffer :: proc "contextless" (parameter: u32, draw_buffer: u32) {
    gl.Enablei(parameter, draw_buffer)
}

enable_vertex_array_attrib :: proc "contextless" (vao: VertexArray, index: u32) {
    gl.EnableVertexArrayAttrib(u32(vao), index)
}

enable_vertex_attrib_array :: proc "contextless" (index: u32) {
    gl.EnableVertexAttribArray(index)
}

flush :: proc "contextless" () {
    gl.Flush()
}

framebuffer_renderbuffer :: proc "contextless" (
    target: u32,
    attachment: u32,
    renderbuffer_target: u32,
    renderbuffer: Renderbuffer,
) {
    gl.FramebufferRenderbuffer(
        target,
        attachment,
        renderbuffer_target,
        u32(renderbuffer),
    )
}

// framebuffer_texture :: proc "contextless" (
//     target: u32,
//     attachment: u32,
//     texture: Texture,
//     level: i32,
// ) {
//     gl.FramebufferTexture(
//         target,
//         attachment,
//         texture,
//         level,
//     )
// }

framebuffer_texture_2d :: proc "contextless" (
    target: u32,
    attachment: u32,
    texture_target: u32,
    texture: Texture,
    level: i32,
) {
    gl.FramebufferTexture2D(
        target,
        attachment,
        texture_target,
        u32(texture),
        level,
    )
}

framebuffer_texture_2d_multisample :: proc "contextless" (
    target: u32,
    attachment: u32,
    texture_target: u32,
    texture: Texture,
    level: i32,
    samples: i32,
) {
    glFramebufferTexture2DMultisampleEXT(
        target,
        attachment,
        texture_target,
        u32(texture),
        level,
        samples,
    )
}

framebuffer_texture_3d :: proc "contextless" (
    target: u32,
    attachment: u32,
    texture_target: u32,
    texture: Texture,
    level: i32,
    layer: i32,
) {
    gl.FramebufferTexture3D(
        target,
        attachment,
        texture_target,
        u32(texture),
        level,
        layer,
    )
}

framebuffer_texture_layer :: proc "contextless" (
    target: u32,
    attachment: u32,
    texture: Texture,
    level: i32,
    layer: i32,
) {
    gl.FramebufferTextureLayer(
        target,
        attachment,
        u32(texture),
        level,
        layer,
    )
}

// TODO: named_framebuffer_renderbuffer - unimplemented

// TODO: named_framebuffer_texture - unimplemented

// TODO: named_framebuffer_texture_layer - unimplemented

front_face :: proc "contextless" (value: u32) {
    gl.FrontFace(value)
}

// TODO: get_error - unimplemented


// TODO: get_tex_parameter_i32 - unimplemented

// TODO: get_tex_parameter_f32 - unimplemented

// TODO: get_texture_level_parameter_i32 - unimplemented

// TODO: get_texture_level_parameter_f32 - unimplemented

// TODO: get_tex_level_parameter_i32 - unimplemented

// TODO: get_tex_level_parameter_f32 - unimplemented

// TODO: get_buffer_parameter_i32 - unimplemented

// TODO: get_parameter_bool - unimplemented

// TODO: get_parameter_bool_array - unimplemented

get_parameter_i32 :: proc "contextless" (parameter: u32) -> i32 {
    value: i32 = ---
    gl.GetIntegerv(parameter, &value)
    return value
}

get_parameter_i32_slice :: proc "contextless" (parameter: u32, out: []i32) {
    gl.GetIntegerv(parameter, &out[0])
}

get_parameter_i64 :: proc "contextless" (parameter: u32) -> i64 {
    value: i64 = ---
    gl.GetInteger64v(parameter, &value)
    return value
}

get_parameter_i64_slice :: proc "contextless" (parameter: u32, out: []i64) {
    gl.GetInteger64v(parameter, &out[0])
}

// TODO: get_parameter_indexed_i64 - unimplemented

// TODO: get_parameter_f32 - unimplemented

// get_parameter_f32_slice :: proc "contextless" (parameter: u32, out: []f32) {
//     gl.GetFloatv(parameter, &out[0])
// }

get_parameter_indexed_i32 :: proc "contextless" (parameter: u32, index: u32) -> i32 {
    value: i32 = ---
    gl.GetIntegeri_v(parameter, index, &value)
    return value
}

get_parameter_indexed_string :: proc "contextless" (parameter: u32, index: u32) -> string {
    return string(gl.GetStringi(parameter, index))
}

get_parameter_string :: proc "contextless" (parameter: u32) -> string {
    return string(gl.GetString(parameter))
}

// TODO: get_parameter_buffer - unimplemented

// TODO: get_parameter_framebuffer - unimplemented

// TODO: get_parameter_program - unimplemented

// TODO: get_parameter_renderbuffer - unimplemented

// TODO: get_parameter_sampler - unimplemented

// TODO: get_parameter_texture - unimplemented

// TODO: get_parameter_transform_feedback - unimplemented

// TODO: get_parameter_vertex_array - unimplemented

// TODO: get_renderbuffer_parameter_i32 - unimplemented

// TODO: get_framebuffer_parameter_i32 - unimplemented

// TODO: get_named_framebuffer_parameter_i32 - unimplemented

// TODO: get_framebuffer_attachment_parameter_i32 - unimplemented

// TODO: get_named_framebuffer_attachment_parameter_i32 - unimplemented

// TODO: get_uniform_location - unimplemented

// TODO: get_attrib_location - unimplemented

// TODO: bind_attrib_location - unimplemented

// TODO: get_active_attributes - unimplemented

// TODO: get_active_attribute - unimplemented


// TODO: get_sync_status - unimplemented

// TODO: is_sync - unimplemented

renderbuffer_storage :: proc "contextless" (
    target: u32,
    internal_format: u32,
    width: i32,
    height: i32,
) {
    gl.RenderbufferStorage(target, internal_format, width, height)
}

renderbuffer_storage_multisample :: proc "contextless" (
    target: u32,
    samples: i32,
    internal_format: u32,
    width: i32,
    height: i32,
) {
    gl.RenderbufferStorageMultisample(target, samples, internal_format, width, height)
}

sampler_parameter_f32 :: proc "contextless" (sampler: Sampler, name: u32, value: f32) {
    gl.SamplerParameterf(u32(sampler), name, value)
}

sampler_parameter_f32_slice :: proc "contextless" (sampler: Sampler, name: u32, value: []f32) {
    gl.SamplerParameterfv(u32(sampler), name, raw_data(value))
}

sampler_parameter_i32 :: proc "contextless" (sampler: Sampler, name: u32, value: i32) {
    gl.SamplerParameteri(u32(sampler), name, value)
}

// get_sampler_parameter_i32 :: proc "contextless" (sampler: Sampler, name: u32) -> i32 {
//     value: i32 = ---
//     gl.GetSamplerParameteriv(u32(sampler), name, &value)
//     return value
// }

// TODO: get_sampler_parameter_f32 - unimplemented

// TODO: get_sampler_parameter_f32_slice - unimplemented

// generate_mipmap :: proc "contextless" (target: u32) {
//     gl.GenerateMipmap(target)
// }

// TODO: generate_texture_mipmap - unimplemented

tex_image_1d :: proc "contextless" (
    target: u32,
    level: i32,
    internal_format: i32,
    width: i32,
    border: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TexImage1D(target, level, internal_format, width, border, format, type, ptr)
}

// TODO: compressed_tex_image_1d - unimplemented

tex_image_2d :: proc "contextless" (
    target: u32,
    level: i32,
    internal_format: i32,
    width: i32,
    height: i32,
    border: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TexImage2D(target, level, internal_format, width, height, border, format, type, ptr)
}

// tex_image_2d_multisample :: proc "contextless" (
//     target: u32,
//     samples: i32,
//     internal_format: i32,
//     width: i32,
//     height: i32,
//     fixed_sample_locations: bool,
// ) {
//     gl.TexImage2DMultisample(
//         target,
//         samples,
//         internal_format as u32,
//         width,
//         height,
//         if fixed_sample_locations { 1 } else { 0 },
//     )
// }

compressed_tex_image_2d :: proc "contextless" (
    target: u32,
    level: i32,
    internal_format: i32,
    width: i32,
    height: i32,
    border: i32,
    image_size: i32,
    pixels: []u8,
) {
    gl.CompressedTexImage2D(
        target,
        level,
        u32(internal_format),
        width,
        height,
        border,
        image_size,
        raw_data(pixels),
    )
}

tex_image_3d :: proc "contextless" (
    target: u32,
    level: i32,
    internal_format: i32,
    width: i32,
    height: i32,
    depth: i32,
    border: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TexImage3D(
        target, level, internal_format, width, height, depth, border, format, type, ptr)
}

// TODO: compressed_tex_image_3d - unimplemented

// tex_storage_1d :: proc "contextless" (target: u32, levels: i32, internal_format: u32, width: i32) {
//     gl.TexStorage1D(target, levels, internal_format, width)
// }

tex_storage_2d :: proc "contextless" (
    target: u32,
    levels: i32,
    internal_format: u32,
    width: i32,
    height: i32,
) {
    gl.TexStorage2D(target, levels, internal_format, width, height)
}

// TODO: texture_storage_2d - unimplemented

tex_storage_2d_multisample :: proc "contextless" (
    target: u32,
    samples: i32,
    internal_format: u32,
    width: i32,
    height: i32,
    fixed_sample_locations: bool,
) {
    gl.TexStorage2DMultisample(
        target,
        samples,
        internal_format,
        width,
        height,
        fixed_sample_locations,
    )
}

tex_storage_3d :: proc "contextless" (
    target: u32,
    levels: i32,
    internal_format: u32,
    width: i32,
    height: i32,
    depth: i32,
) {
    gl.TexStorage3D(target, levels, internal_format, width, height, depth)
}

// TODO: texture_storage_3d - unimplemented

// TODO: get_uniform_i32 - unimplemented

// get_uniform_u32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: []u32,
// ) {
//     gl.GetUniformuiv(u32(program), location.0 as i32, v.as_mut_ptr())
// }

// get_uniform_f32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: []f32,
// ) {
//     gl.GetUniformfv(u32(program), location.0 as i32, v.as_mut_ptr())
// }

// TODO: uniform_1_i32 - unimplemented

// TODO: uniform_2_i32 - unimplemented

// TODO: uniform_3_i32 - unimplemented

// TODO: uniform_4_i32 - unimplemented

// TODO: uniform_1_i32_slice - unimplemented

// TODO: uniform_2_i32_slice - unimplemented

// TODO: uniform_3_i32_slice - unimplemented

// TODO: uniform_4_i32_slice - unimplemented

uniform_1_u32 :: proc "contextless" (location: i32, x: u32) {
    gl.Uniform1ui(location, x)
}

// TODO: uniform_2_u32 - unimplemented

// TODO: uniform_3_u32 - unimplemented

// TODO: uniform_4_u32 - unimplemented

// TODO: uniform_1_u32_slice - unimplemented

// TODO: uniform_2_u32_slice - unimplemented

// TODO: uniform_3_u32_slice - unimplemented

// TODO: uniform_4_u32_slice - unimplemented

// TODO: uniform_1_f32 - unimplemented

// TODO: uniform_2_f32 - unimplemented

// TODO: uniform_3_f32 - unimplemented

// TODO: uniform_4_f32 - unimplemented

// TODO: uniform_1_f32_slice - unimplemented

// TODO: uniform_2_f32_slice - unimplemented

// TODO: uniform_3_f32_slice - unimplemented

// TODO: uniform_4_f32_slice - unimplemented

// TODO: uniform_matrix_2_f32_slice - unimplemented

// TODO: uniform_matrix_2x3_f32_slice - unimplemented

// TODO: uniform_matrix_2x4_f32_slice - unimplemented

// TODO: uniform_matrix_3x2_f32_slice - unimplemented

// TODO: uniform_matrix_3_f32_slice - unimplemented

// TODO: uniform_matrix_3x4_f32_slice - unimplemented

// TODO: uniform_matrix_4x2_f32_slice - unimplemented

// TODO: uniform_matrix_4x3_f32_slice - unimplemented

// TODO: uniform_matrix_4_f32_slice - unimplemented

unmap_buffer :: proc "contextless" (target: u32) {
    gl.UnmapBuffer(target)
}

cull_face :: proc "contextless" (value: u32) {
    gl.CullFace(value)
}

color_mask :: proc "contextless" (red: bool, green: bool, blue: bool, alpha: bool) {
    gl.ColorMask(red, green, blue, alpha)
}

color_mask_draw_buffer :: proc "contextless" (
    draw_buffer: u32,
    red: bool,
    green: bool,
    blue: bool,
    alpha: bool,
) {
    gl.ColorMaski(draw_buffer, red, green, blue, alpha)
}

depth_mask :: proc "contextless" (value: bool) {
    gl.DepthMask(value)
}

blend_color :: proc "contextless" (red: f32, green: f32, blue: f32, alpha: f32) {
    gl.BlendColor(red, green, blue, alpha)
}

line_width :: proc "contextless" (width: f32) {
    gl.LineWidth(width)
}

map_buffer_range :: proc "contextless" (
    target: u32,
    offset: i32,
    length: i32,
    access: u32,
) -> rawptr {
    return gl.MapBufferRange(target, int(offset), int(length), access)
}

flush_mapped_buffer_range :: proc "contextless" (target: u32, offset: i32, length: i32) {
    gl.FlushMappedBufferRange(target, int(offset), int(length))
}

// invalidate_buffer_sub_data :: proc "contextless" (target: u32, offset: i32, length: i32) {
//     gl.InvalidateBufferSubData(target, offset as isize, length as isize)
// }

invalidate_framebuffer :: proc "contextless" (target: u32, attachments: []u32) {
    gl.InvalidateFramebuffer(target, i32(len(attachments)), raw_data(attachments))
}

// invalidate_sub_framebuffer :: proc "contextless" (
//     target: u32,
//     attachments: []u32,
//     x: i32,
//     y: i32,
//     width: i32,
//     height: i32,
// ) {
//     gl.InvalidateSubFramebuffer(
//         target,
//         attachments.len() as i32,
//         attachments.as_ptr(),
//         x,
//         y,
//         width,
//         height,
//     )
// }

polygon_offset :: proc "contextless" (factor: f32, units: f32) {
    gl.PolygonOffset(factor, units)
}

polygon_mode :: proc "contextless" (face: u32, mode: u32) {
    gl.PolygonMode(face, mode)
}

finish :: proc "contextless" () {
    gl.Finish()
}

bind_texture :: proc "contextless" (target: u32, texture: Texture) {
    gl.BindTexture(target, u32(texture))
}

bind_texture_unit :: proc "contextless" (unit: u32, texture: Texture) {
    gl.BindTextureUnit(unit, u32(texture))
}

bind_sampler :: proc "contextless" (unit: u32, sampler: Sampler) {
    gl.BindSampler(unit, u32(sampler))
}

active_texture :: proc "contextless" (unit: u32) {
    gl.ActiveTexture(unit)
}

// TODO: fence_sync - unimplemented

// tex_parameter_f32 :: proc "contextless" (target: u32, parameter: u32, value: f32) {
//     gl.TexParameterf(target, parameter, value)
// }

tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32, value: i32) {
    gl.TexParameteri(target, parameter, value)
}

// TODO: texture_parameter_i32 - unimplemented

// tex_parameter_f32_slice :: proc "contextless" (target: u32, parameter: u32, values: []f32) {
//     gl.TexParameterfv(target, parameter, values.as_ptr())
// }

// TODO: tex_parameter_i32_slice - unimplemented

tex_sub_image_2d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    width: i32,
    height: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TexSubImage2D(
        target,
        level,
        x_offset,
        y_offset,
        width,
        height,
        format,
        type,
        ptr,
    )
}

texture_sub_image_2d :: proc "contextless" (
    texture: Texture,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    width: i32,
    height: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TextureSubImage2D(
        u32(texture), level, x_offset, y_offset, width, height, format, type, ptr)
}

compressed_tex_sub_image_2d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    width: i32,
    height: i32,
    format: u32,
    pixels: CompressedPixelUnpackData,
) {
    image_size: i32
    ptr: rawptr
    switch p in pixels {
    case []u8:
        image_size = i32(len(p))
        ptr = raw_data(p)
    case BufferRange:
        image_size = i32(p.end - p.start)
        ptr = rawptr(uintptr(p.start))
    }
    gl.CompressedTexSubImage2D(
        target,
        level,
        x_offset,
        y_offset,
        width,
        height,
        format,
        image_size,
        ptr)
}

tex_sub_image_3d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    z_offset: i32,
    width: i32,
    height: i32,
    depth: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TexSubImage3D(
        target, level, x_offset, y_offset, z_offset, width, height, depth, format, type, ptr)
}

texture_sub_image_3d :: proc "contextless" (
    texture: Texture,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    z_offset: i32,
    width: i32,
    height: i32,
    depth: i32,
    format: u32,
    type: u32,
    pixels: PixelUnpackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.TextureSubImage3D(
        u32(texture), level, x_offset, y_offset, z_offset, width, height, depth, format, type, ptr)
}

compressed_tex_sub_image_3d :: proc "contextless" (
    target: u32,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    z_offset: i32,
    width: i32,
    height: i32,
    depth: i32,
    format: u32,
    pixels: CompressedPixelUnpackData,
) {
    image_size: i32
    ptr: rawptr
    switch p in pixels {
    case []u8:
        image_size = i32(len(p))
        ptr = raw_data(p)
    case BufferRange:
        image_size = i32(p.end - p.start)
        ptr = rawptr(uintptr(p.start))
    }
    gl.CompressedTexSubImage3D(
        target,
        level,
        x_offset,
        y_offset,
        z_offset,
        width,
        height,
        depth,
        format,
        image_size,
        ptr)
}

depth_func :: proc "contextless" (func: u32) {
    gl.DepthFunc(func)
}

depth_range_f32 :: proc "contextless" (near: f32, far: f32) {
    gl.DepthRangef(near, far)
}

depth_range_f64 :: proc "contextless" (near: f64, far: f64) {
    gl.DepthRange(near, far)
}

depth_range :: proc "contextless" (near: f64, far: f64) {
    if supports_f64_precision() {
        depth_range_f64(near, far)
    } else {
        depth_range_f32(f32(near), f32(far))
    }
}

// TODO: depth_range_f64_slice - unimplemented

scissor :: proc "contextless" (x: i32, y: i32, width: i32, height: i32) {
    gl.Scissor(x, y, width, height)
}

// TODO: scissor_slice - unimplemented

// TODO: vertex_array_attrib_binding_f32 - unimplemented

// TODO: vertex_array_attrib_format_f32 - unimplemented

// TODO: vertex_array_attrib_format_i32 - unimplemented

// TODO: vertex_array_attrib_format_f64 - unimplemented

// TODO: vertex_array_element_buffer - unimplemented

// TODO: vertex_array_vertex_buffer - unimplemented

vertex_attrib_divisor :: proc "contextless" (index: u32, divisor: u32) {
    gl.VertexAttribDivisor(index, divisor)
}

// get_vertex_attrib_parameter_f32_slice :: proc "contextless" (
//     index: u32,
//     pname: u32,
//     result: []f32,
// ) {
//     gl.GetVertexAttribfv(index, pname, result.as_mut_ptr())
// }

vertex_attrib_pointer :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    normalized: bool,
    stride: i32,
    offset: i32,
) {
    gl.VertexAttribPointer(
        index,
        size,
        data_type,
        normalized,
        stride,
        uintptr(offset),
    )
}

vertex_attrib_pointer_i32 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    stride: i32,
    offset: i32,
) {
    gl.VertexAttribIPointer(
        index,
        size,
        data_type,
        stride,
        uintptr(offset),
    )
}

vertex_attrib_pointer_f64 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    stride: i32,
    offset: i32,
) {
    gl.VertexAttribLPointer(
        index,
        size,
        data_type,
        stride,
        uintptr(offset),
    )
}

vertex_attrib_format_f32 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    normalized: bool,
    relative_offset: u32,
) {
    gl.VertexAttribFormat(index, size, data_type, normalized, relative_offset)
}

vertex_attrib_format_i32 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    relative_offset: u32,
) {
    gl.VertexAttribIFormat(index, size, data_type, relative_offset)
}

// vertex_attrib_format_f64 :: proc "contextless" (
//     index: u32,
//     size: i32,
//     data_type: u32,
//     relative_offset: u32,
// ) {
//     gl.VertexAttribLFormat(index, size, data_type, relative_offset)
// }

// vertex_attrib_1_f32 :: proc "contextless" (index: u32, x: f32) {
//     gl.VertexAttrib1f(index, x)
// }

// vertex_attrib_2_f32 :: proc "contextless" (index: u32, x: f32, y: f32) {
//     gl.VertexAttrib2f(index, x, y)
// }

// vertex_attrib_3_f32 :: proc "contextless" (index: u32, x: f32, y: f32, z: f32) {
//     gl.VertexAttrib3f(index, x, y, z)
// }

// vertex_attrib_4_f32 :: proc "contextless" (index: u32, x: f32, y: f32, z: f32, w: f32) {
//     gl.VertexAttrib4f(index, x, y, z, w)
// }

// vertex_attrib_4_i32 :: proc "contextless" (index: u32, x: i32, y: i32, z: i32, w: i32) {
//     gl.VertexAttribI4i(index, x, y, z, w)
// }

// vertex_attrib_4_u32 :: proc "contextless" (index: u32, x: u32, y: u32, z: u32, w: u32) {
//     gl.VertexAttribI4ui(index, x, y, z, w)
// }

// vertex_attrib_1_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     gl.VertexAttrib1fv(index, raw_data(v))
// }

// vertex_attrib_2_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     gl.VertexAttrib2fv(index, raw_data(v))
// }

// vertex_attrib_3_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     gl.VertexAttrib3fv(index, raw_data(v))
// }

// vertex_attrib_4_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     gl.VertexAttrib4fv(index, raw_data(v))
// }

vertex_attrib_binding :: proc "contextless" (attrib_index: u32, binding_index: u32) {
    gl.VertexAttribBinding(attrib_index, binding_index)
}

vertex_binding_divisor :: proc "contextless" (binding_index: u32, divisor: u32) {
    gl.VertexBindingDivisor(binding_index, divisor)
}

viewport :: proc "contextless" (x: i32, y: i32, width: i32, height: i32) {
    gl.Viewport(x, y, width, height)
}

viewport_f32_slice :: proc "contextless" (first: u32, count: i32, values: [4]f32) {
    values := values
    gl.ViewportArrayv(first, count, &values[0])
}

blend_equation :: proc "contextless" (mode: u32) {
    gl.BlendEquation(mode)
}

blend_equation_draw_buffer :: proc "contextless" (draw_buffer: u32, mode: u32) {
    gl.BlendEquationi(draw_buffer, mode)
}

blend_equation_separate :: proc "contextless" (mode_rgb: u32, mode_alpha: u32) {
    gl.BlendEquationSeparate(mode_rgb, mode_alpha)
}

blend_equation_separate_draw_buffer :: proc "contextless" (
    draw_buffer: u32,
    mode_rgb: u32,
    mode_alpha: u32,
) {
    gl.BlendEquationSeparatei(draw_buffer, mode_rgb, mode_alpha)
}

blend_func :: proc "contextless" (src: u32, dst: u32) {
    gl.BlendFunc(src, dst)
}

blend_func_draw_buffer :: proc "contextless" (draw_buffer: u32, src: u32, dst: u32) {
    gl.BlendFunci(draw_buffer, src, dst)
}

blend_func_separate :: proc "contextless" (
    src_rgb: u32,
    dst_rgb: u32,
    src_alpha: u32,
    dst_alpha: u32,
) {
    gl.BlendFuncSeparate(
        src_rgb,
        dst_rgb,
        src_alpha,
        dst_alpha,
    )
}

blend_func_separate_draw_buffer :: proc "contextless" (
    draw_buffer: u32,
    src_rgb: u32,
    dst_rgb: u32,
    src_alpha: u32,
    dst_alpha: u32,
) {
    gl.BlendFuncSeparatei(
        draw_buffer,
        src_rgb,
        dst_rgb,
        src_alpha,
        dst_alpha,
    )
}

stencil_func :: proc "contextless" (func: u32, reference: i32, mask: u32) {
    gl.StencilFunc(func, reference, mask)
}

stencil_func_separate :: proc "contextless" (face: u32, func: u32, reference: i32, mask: u32) {
    gl.StencilFuncSeparate(face, func, reference, mask)
}

stencil_mask :: proc "contextless" (mask: u32) {
    gl.StencilMask(mask)
}

stencil_mask_separate :: proc "contextless" (face: u32, mask: u32) {
    gl.StencilMaskSeparate(face, mask)
}

// stencil_op :: proc "contextless" (stencil_fail: u32, depth_fail: u32, pass: u32) {
//     gl.StencilOp(stencil_fail as u32, depth_fail as u32, pass as u32)
// }

stencil_op_separate :: proc "contextless" (
    face: u32,
    stencil_fail: u32,
    depth_fail: u32,
    pass: u32,
) {
    gl.StencilOpSeparate(face, stencil_fail, depth_fail, pass)
}

// TODO: debug_message_control - unimplemented


// TODO: debug_message_insert - unimplemented

debug_message_callback :: proc "contextless" (callback: debug_proc_t, userParam: rawptr) {
    if ctx.version.is_embedded {
        if glDebugMessageCallbackKHR != nil {
            glDebugMessageCallbackKHR(callback, userParam)
        }
    } else {
        gl.DebugMessageCallback(callback, userParam)
    }
}

// TODO: get_debug_message_log - unimplemented


// TODO: push_debug_group - unimplemented

// TODO: pop_debug_group - unimplemented


object_label :: proc "contextless" (#any_int identifier: u32, name: u32, label: string) {
    length := i32(len(label))
    if ctx.version.is_embedded || gl.ObjectLabel == nil {
        if glObjectLabelKHR != nil {
            glObjectLabelKHR(identifier, name, length, cstring(raw_data(label)))
        }
    } else {
        gl.ObjectLabel(identifier, name, length, cstring(raw_data(label)))
    }
}

// TODO: get_object_label - unimplemented

// TODO: object_ptr_label - unimplemented


// TODO: get_object_ptr_label - unimplemented

// TODO: get_uniform_block_index - unimplemented

// TODO: get_uniform_indices - unimplemented


// uniform_block_binding :: proc "contextless" (program: Program, index: u32, binding: u32) {
//     gl.UniformBlockBinding(u32(program), index, binding)
// }

// TODO: get_shader_storage_block_index - unimplemented

// shader_storage_block_binding :: proc "contextless" (
//     program: Program,
//     index: u32,
//     binding: u32,
// ) {
//     gl.ShaderStorageBlockBinding(u32(program), index, binding)
// }

read_buffer :: proc "contextless" (src: u32) {
    gl.ReadBuffer(src)
}

// TODO: named_framebuffer_read_buffer - unimplemented

read_pixels :: proc "contextless" (
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    format: u32,
    gltype: u32,
    pixels: PixelPackData,
) {
    ptr: rawptr
    switch p in pixels {
    case []u8:
        ptr = raw_data(p)
    case BufferOffset:
        ptr = rawptr(uintptr(p))
    }
    gl.ReadPixels(x, y, width, height, format, gltype, ptr)
}

begin_query :: proc "contextless" (target: u32, query: Query) {
    if gl.BeginQuery != nil {
        gl.BeginQuery(target, u32(query))
    } else {
        glBeginQueryEXT(target, u32(query))
    }
}

end_query :: proc "contextless" (target: u32) {
    if gl.EndQuery != nil {
        gl.EndQuery(target)
    } else {
        // gl.EndQueryEXT(target)
    }
}

// query_counter :: proc "contextless" (query: Query, target: u32) {
//     if gl.QueryCounter_is_loaded() {
//         gl.QueryCounter(u32(query), target)
//     } else {
//         gl.QueryCounterEXT(u32(query), target)
//     }
// }

get_query_parameter_u32 :: proc "contextless" (query: Query, parameter: u32) -> u32 {
    value: u32 = ---
    if gl.GetQueryObjectuiv != nil {
        gl.GetQueryObjectuiv(u32(query), parameter, &value)
    } else {
        // gl.GetQueryObjectuivEXT(u32(query), parameter, &value)
    }
    return value
}

get_query_parameter_u64 :: proc "contextless" (query: Query, parameter: u32) -> u64 {
    value: u64 = ---
    if gl.GetQueryObjectui64v != nil {
        gl.GetQueryObjectui64v(u32(query), parameter, &value)
    } else {
        // gl.GetQueryObjectui64vEXT(u32(query), parameter, &value)
    }
    return value
}

get_query_parameter_u64_with_offset :: proc "contextless" (
    query: Query,
    parameter: u32,
    offset: u64,
) {
    offset := offset
    if gl.GetQueryObjectui64v != nil {
        gl.GetQueryObjectui64v(u32(query), parameter, &offset)
    } else {
        // gl.GetQueryObjectui64vEXT(u32(query), parameter, offset)
    }
}

// TODO: create_transform_feedback - unimplemented

// TODO: is_transform_feedback - unimplemented

// TODO: delete_transform_feedback - unimplemented

// TODO: bind_transform_feedback - unimplemented

// begin_transform_feedback :: proc "contextless" (primitive_mode: u32) {
//     gl.BeginTransformFeedback(primitive_mode)
// }

// TODO: end_transform_feedback - unimplemented

// TODO: pause_transform_feedback - unimplemented

// TODO: resume_transform_feedback - unimplemented

// TODO: transform_feedback_varyings - unimplemented


// TODO: get_transform_feedback_varying - unimplemented


memory_barrier :: proc "contextless" (barriers: u32) {
    gl.MemoryBarrier(barriers)
}

memory_barrier_by_region :: proc "contextless" (barriers: u32) {
    gl.MemoryBarrierByRegion(barriers)
}

bind_image_texture :: proc "contextless" (
    unit: u32,
    texture: Texture,
    level: i32,
    layered: bool,
    layer: i32,
    access: u32,
    format: u32,
) {
    gl.BindImageTexture(
        unit,
        u32(texture),
        level,
        layered,
        layer,
        access,
        format,
    )
}

// TODO: get_active_uniform_block_parameter_i32 - unimplemented

// TODO: get_active_uniform_block_parameter_i32_slice - unimplemented


// max_shader_compiler_threads :: proc "contextless" (count: u32) {
//     if gl.MaxShaderCompilerThreadsKHR_is_loaded() {
//         gl.MaxShaderCompilerThreadsKHR(count)
//     } else {
//         gl.MaxShaderCompilerThreadsARB(count)
//     }
// }

// hint :: proc "contextless" (target: u32, mode: u32) {
//     gl.Hint(target, mode)
// }

// sample_coverage :: proc "contextless" (value: f32, invert: bool) {
//     gl.SampleCoverage(value, invert as u8)
// }

// TODO: get_internal_format_i32_slice - unimplemented
