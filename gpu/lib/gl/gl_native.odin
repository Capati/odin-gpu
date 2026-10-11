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

// get_active_uniforms_parameter :: proc "contextless" (
//     program: Program,
//     uniforms: []u32,
//     pname: u32,
// ) -> Vec<i32> {
//     let results = vec![0 uniforms.len()]
//     gl.GetActiveUniformsiv(
//         u32(program),
//         uniforms.len() as _,
//         uniforms.as_ptr(),
//         pname,
//         results.as_mut_ptr(),
//     )
//     results
// }

// get_active_uniform :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveUniform> {
//     let uniform_max_size = 0
//     gl.GetProgramiv(
//         u32(program),
//         ACTIVE_UNIFORM_MAX_LENGTH,
//         &uniform_max_size,
//     )

//     let name = string::with_capacity(uniform_max_size as usize)
//     name.extend(std::iter::repeat('\0').take(uniform_max_size as usize))
//     let length = 0
//     let size = 0
//     let utype = 0
//     gl.GetActiveUniform(
//         u32(program),
//         index,
//         uniform_max_size,
//         &length,
//         &size,
//         &utype,
//         name.as_ptr() as *native_gl::GLchar,
//     )
//     name.truncate(length as usize)

//     Some(ActiveUniform { size, utype, name })
// }

use_program :: proc "contextless" (program: Program) {
    gl.UseProgram(u32(program))
}

create_buffer :: proc "contextless" () -> Buffer {
    buffer: u32 = ---
    gl.GenBuffers(1, &buffer)
    return Buffer(buffer)
}

// create_named_buffer :: proc "contextless" (&self) -> Result<Buffer, string> {
//     let buffer = 0
//     gl.CreateBuffers(1, &buffer)
//     NonZeroU32::new(buffer)
//         .map(NativeBuffer)
//         .ok_or_else(|| string::from("Unable to create Buffer object"))
// }

// is_buffer :: proc "contextless" (buffer: Buffer) -> bool {
//     gl.IsBuffer(buffer.0.get()) != 0
// }

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

// blit_named_framebuffer :: proc "contextless" (
//     read_buffer: Option<Framebuffer>,
//     draw_buffer: Option<Framebuffer>,
//     src_x0: i32,
//     src_y0: i32,
//     src_x1: i32,
//     src_y1: i32,
//     dst_x0: i32,
//     dst_y0: i32,
//     dst_x1: i32,
//     dst_y1: i32,
//     mask: u32,
//     filter: u32,
// ) {
//     gl.BlitNamedFramebuffer(
//         read_buffer.map(|f| f.0.get()).unwrap_or(0),
//         draw_buffer.map(|f| f.0.get()).unwrap_or(0),
//         src_x0,
//         src_y0,
//         src_x1,
//         src_y1,
//         dst_x0,
//         dst_y0,
//         dst_x1,
//         dst_y1,
//         mask,
//         filter,
//     )
// }

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

// create_named_vertex_array :: proc "contextless" (&self) -> Result<VertexArray, string> {
//     let vertex_array = 0
//     gl.CreateVertexArrays(1, &vertex_array)
//     NonZeroU32::new(vertex_array)
//         .map(NativeVertexArray)
//         .ok_or_else(|| string::from("Unable to create VertexArray object"))
// }

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

// get_frag_data_location :: proc "contextless" (program: Program, name: &str) -> i32 {
//     let name = CString::new(name).unwrap()
//     gl.GetFragDataLocation(u32(program), name.as_ptr() as *const native_gl::GLchar)
// }

// bind_frag_data_location :: proc "contextless" (
//     program: Program,
//     color_number: u32,
//     name: &str,
// ) {
//     let name = CString::new(name).unwrap()
//     gl.BindFragDataLocation(
//         u32(program),
//         color_number,
//         name.as_ptr() as *const native_gl::GLchar,
//     )
// }

buffer_data_size :: proc "contextless" (target: u32, size: i32, usage: u32) {
    gl.BufferData(target, int(size), nil, usage)
}

// named_buffer_data_size :: proc "contextless" (buffer: Buffer, size: i32, usage: u32) {
//     gl.NamedBufferData(buffer.0.get(), size as isize, std::ptr::null(), usage)
// }

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

// named_buffer_data_u8_slice :: proc "contextless" (buffer: Buffer, data: &[u8], usage: u32) {
//     gl.NamedBufferData(
//         buffer.0.get(),
//         data.len() as isize,
//         data.as_ptr() as *const std::ffi::c_void,
//         usage,
//     )
// }

buffer_sub_data_u8_slice :: proc "contextless" (target: u32, offset: i32, src_data: []u8) {
    gl.BufferSubData(
        target,
        int(offset),
        len(src_data),
        raw_data(src_data),
    )
}

// named_buffer_sub_data_u8_slice :: proc "contextless" (
//     buffer: Buffer,
//     offset: i32,
//     src_data: &[u8],
// ) {
//     gl.NamedBufferSubData(
//         buffer.0.get(),
//         offset as isize,
//         src_data.len() as isize,
//         src_data.as_ptr() as *const std::ffi::c_void,
//     )
// }

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
//     let data = data.map(|p| p.as_ptr()).unwrap_or(std::ptr::null()) as *const std::ffi::c_void
//     if gl.BufferStorage_is_loaded() {
//         gl.BufferStorage(target, size, data, flags)
//     } else {
//         gl.BufferStorageEXT(target, size, data, flags)
//     }
}

// named_buffer_storage :: proc "contextless" (
//     buffer: Buffer,
//     size: i32,
//     data: Option<&[u8]>,
//     flags: u32,
// ) {
//     let data = data.map(|p| p.as_ptr()).unwrap_or(std::ptr::null()) as *const std::ffi::c_void
//     gl.NamedBufferStorage(buffer.0.get(), size as isize, data, flags)
// }

check_framebuffer_status :: proc "contextless" (target: u32) -> u32 {
    return gl.CheckFramebufferStatus(target)
}

// check_named_framebuffer_status :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     target: u32,
// ) -> u32 {
//     gl.CheckNamedFramebufferStatus(framebuffer.map(|f| f.0.get()).unwrap_or(0), target)
// }

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

// clear_named_framebuffer_i32_slice :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     target: u32,
//     draw_buffer: u32,
//     values: &[i32],
// ) {
//     gl.ClearNamedFramebufferiv(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         target,
//         draw_buffer as i32,
//         values.as_ptr(),
//     )
// }

// clear_named_framebuffer_u32_slice :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     target: u32,
//     draw_buffer: u32,
//     values: []u32,
// ) {
//     gl.ClearNamedFramebufferuiv(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         target,
//         draw_buffer as i32,
//         values.as_ptr(),
//     )
// }

// clear_named_framebuffer_f32_slice :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     target: u32,
//     draw_buffer: u32,
//     values: []f32,
// ) {
//     gl.ClearNamedFramebufferfv(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         target,
//         draw_buffer as i32,
//         values.as_ptr(),
//     )
// }

// clear_named_framebuffer_depth_stencil :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     target: u32,
//     draw_buffer: u32,
//     depth: f32,
//     stencil: i32,
// ) {
//     gl.ClearNamedFramebufferfi(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         target,
//         draw_buffer as i32,
//         depth,
//         stencil,
//     )
// }

// client_wait_sync :: proc "contextless" (fence: Fence, flags: u32, timeout: i32) -> u32 {
//     gl.ClientWaitSync(fence.0, flags, timeout as u64)
// }

// get_sync_parameter_i32 :: proc "contextless" (fence: Fence, parameter: u32) -> i32 {
//     let v = 0
//     gl.GetSynciv(fence.0, parameter, 1, ptr::null_mut(), &v)
//     v
// }

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

// copy_image_sub_data :: proc "contextless" (
//     src_name: Texture,
//     src_target: u32,
//     src_level: i32,
//     src_x: i32,
//     src_y: i32,
//     src_z: i32,
//     dst_name: Texture,
//     dst_target: u32,
//     dst_level: i32,
//     dst_x: i32,
//     dst_y: i32,
//     dst_z: i32,
//     src_width: i32,
//     src_height: i32,
//     src_depth: i32,
// ) {
//     gl.CopyImageSubData(
//         src_name.0.get(),
//         src_target,
//         src_level,
//         src_x,
//         src_y,
//         src_z,
//         dst_name.0.get(),
//         dst_target,
//         dst_level,
//         dst_x,
//         dst_y,
//         dst_z,
//         src_width,
//         src_height,
//         src_depth,
//     )
// }

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

// named_framebuffer_draw_buffer :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     draw_buffer: u32,
// ) {
//     gl.NamedFramebufferDrawBuffer(framebuffer.map(|f| f.0.get()).unwrap_or(0), draw_buffer)
// }

draw_buffers :: proc "contextless" (buffers: []u32) {
    gl.DrawBuffers(i32(len(buffers)), raw_data(buffers))
}

// named_framebuffer_draw_buffers :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     buffers: []u32,
// ) {
//     gl.NamedFramebufferDrawBuffers(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         buffers.len() as i32,
//         buffers.as_ptr(),
//     )
// }

// draw_elements :: proc "contextless" (mode: u32, count: i32, element_type: u32, offset: i32) {
//     gl.DrawElements(
//         mode as u32,
//         count,
//         element_type as u32,
//         offset as *const std::ffi::c_void,
//     )
// }

// draw_elements_base_vertex :: proc "contextless" (
//     mode: u32,
//     count: i32,
//     element_type: u32,
//     offset: i32,
//     base_vertex: i32,
// ) {
//     gl.DrawElementsBaseVertex(
//         mode as u32,
//         count,
//         element_type as u32,
//         offset as *const std::ffi::c_void,
//         base_vertex,
//     )
// }

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

// named_framebuffer_renderbuffer :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     attachment: u32,
//     renderbuffer_target: u32,
//     renderbuffer: Renderbuffer,
// ) {
//     gl.NamedFramebufferRenderbuffer(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         attachment,
//         renderbuffer_target,
//         renderbuffer.map(|rb| rb.0.get()).unwrap_or(0),
//     )
// }

// named_framebuffer_texture :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     attachment: u32,
//     texture: Texture,
//     level: i32,
// ) {
//     gl.NamedFramebufferTexture(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         attachment,
//         texture,
//         level,
//     )
// }

// named_framebuffer_texture_layer :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     attachment: u32,
//     texture: Texture,
//     level: i32,
//     layer: i32,
// ) {
//     gl.NamedFramebufferTextureLayer(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         attachment,
//         texture,
//         level,
//         layer,
//     )
// }

front_face :: proc "contextless" (value: u32) {
    gl.FrontFace(value)
}

// get_error :: proc "contextless" (&self) -> u32 {
//     gl.GetError()
// }

// get_tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     let value = 0
//     gl.GetTexParameteriv(target, parameter, &value)
//     value
// }

// get_tex_parameter_f32 :: proc "contextless" (target: u32, parameter: u32) -> f32 {
//     let value = 0.
//     gl.GetTexParameterfv(target, parameter, &value)
//     value
// }

// get_texture_level_parameter_i32 :: proc "contextless" (
//     texture: Texture,
//     level: i32,
//     parameter: u32,
// ) -> i32 {
//     let value = 0
//     gl.GetTextureLevelParameteriv(texture.0.get(), level, parameter, &value)
//     value
// }

// get_texture_level_parameter_f32 :: proc "contextless" (
//     texture: Texture,
//     level: i32,
//     parameter: u32,
// ) -> f32 {
//     let value = 0.0
//     gl.GetTextureLevelParameterfv(texture.0.get(), level, parameter, &value)
//     value
// }

// get_tex_level_parameter_i32 :: proc "contextless" (target: u32, level: i32, parameter: u32) -> i32 {
//     let value = 0
//     gl.GetTexLevelParameteriv(target, level, parameter, &value)
//     value
// }

// get_tex_level_parameter_f32 :: proc "contextless" (target: u32, level: i32, parameter: u32) -> f32 {
//     let value = 0.0
//     gl.GetTexLevelParameterfv(target, level, parameter, &value)
//     value
// }

// get_buffer_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     let value = 0
//     gl.GetBufferParameteriv(target, parameter, &value)
//     value
// }

// get_parameter_bool :: proc "contextless" (parameter: u32) -> bool {
//     let value = 0
//     gl.GetBooleanv(parameter, &value)
//     value != FALSE
// }

// get_parameter_bool_array :: proc "contextless" <const N: usize>(parameter: u32) -> [bool N] {
//     let value = [0 N]
//     gl.GetBooleanv(parameter, &value[0])
//     value.map(|v| v != FALSE)
// }

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

// get_parameter_indexed_i64 :: proc "contextless" (parameter: u32, index: u32) -> i64 {
//     let value = 0
//     gl.GetInteger64i_v(parameter, index, &value)
//     value
// }

// get_parameter_f32 :: proc "contextless" (parameter: u32) -> f32 {
//     let value: f32 = 0.0
//     gl.GetFloatv(parameter, &value)
//     value
// }

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

// get_parameter_buffer :: proc "contextless" (parameter: u32) -> Buffer {
//     self.get_parameter_gl_name(parameter).map(NativeBuffer)
// }

// get_parameter_framebuffer :: proc "contextless" (parameter: u32) -> Option<Framebuffer> {
//     self.get_parameter_gl_name(parameter).map(NativeFramebuffer)
// }

// get_parameter_program :: proc "contextless" (parameter: u32) -> Program {
//     self.get_parameter_gl_name(parameter).map(NativeProgram)
// }

// get_parameter_renderbuffer :: proc "contextless" (parameter: u32) -> Renderbuffer {
//     self.get_parameter_gl_name(parameter)
//         .map(NativeRenderbuffer)
// }

// get_parameter_sampler :: proc "contextless" (parameter: u32) -> Sampler {
//     self.get_parameter_gl_name(parameter).map(NativeSampler)
// }

// get_parameter_texture :: proc "contextless" (parameter: u32) -> Texture {
//     self.get_parameter_gl_name(parameter).map(NativeTexture)
// }

// get_parameter_transform_feedback :: proc "contextless" (
//     parameter: u32,
// ) -> Option<TransformFeedback> {
//     self.get_parameter_gl_name(parameter)
//         .map(NativeTransformFeedback)
// }

// get_parameter_vertex_array :: proc "contextless" (parameter: u32) -> VertexArray {
//     self.get_parameter_gl_name(parameter).map(NativeVertexArray)
// }

// get_renderbuffer_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     let value = 0
//     gl.GetRenderbufferParameteriv(target, parameter, &value)
//     value
// }

// get_framebuffer_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     let value = 0
//     gl.GetFramebufferParameteriv(target, parameter, &value)
//     value
// }

// get_named_framebuffer_parameter_i32 :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     parameter: u32,
// ) -> i32 {
//     let value = 0
//     gl.GetNamedFramebufferParameteriv(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         parameter,
//         &value,
//     )
//     value
// }

// get_framebuffer_attachment_parameter_i32 :: proc "contextless" (
//     target: u32,
//     attachment: u32,
//     parameter: u32,
// ) -> i32 {
//     let value = 0
//     gl.GetFramebufferAttachmentParameteriv(target, attachment, parameter, &value)
//     value
// }

// get_named_framebuffer_attachment_parameter_i32 :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     attachment: u32,
//     parameter: u32,
// ) -> i32 {
//     let value = 0
//     gl.GetNamedFramebufferAttachmentParameteriv(
//         framebuffer.map(|f| f.0.get()).unwrap_or(0),
//         attachment,
//         parameter,
//         &value,
//     )
//     value
// }

// get_uniform_location :: proc "contextless" (
//     program: Program,
//     name: &str,
// ) -> Option<UniformLocation> {
//     let name = CString::new(name).unwrap()
//     let uniform_location =
//         gl.GetUniformLocation(u32(program), name.as_ptr() as *const native_gl::GLchar)
//     if uniform_location < 0 {
//         None
//     } else {
//         Some(NativeUniformLocation(uniform_location as u32))
//     }
// }

// get_attrib_location :: proc "contextless" (program: Program, name: &str) -> Option<u32> {
//     let name = CString::new(name).unwrap()
//     let attrib_location =
//         gl.GetAttribLocation(u32(program), name.as_ptr() as *const native_gl::GLchar)
//     if attrib_location < 0 {
//         None
//     } else {
//         Some(attrib_location as u32)
//     }
// }

// bind_attrib_location :: proc "contextless" (program: Program, index: u32, name: &str) {
//     let name = CString::new(name).unwrap()
//     gl.BindAttribLocation(
//         u32(program),
//         index,
//         name.as_ptr() as *const native_gl::GLchar,
//     )
// }

// get_active_attributes :: proc "contextless" (program: Program) -> u32 {
//     let count = 0
//     gl.GetProgramiv(u32(program), ACTIVE_ATTRIBUTES, &count)
//     count as u32
// }

// get_active_attribute :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveAttribute> {
//     let attribute_max_size = 0
//     gl.GetProgramiv(
//         u32(program),
//         ACTIVE_ATTRIBUTE_MAX_LENGTH,
//         &attribute_max_size,
//     )
//     let name = string::with_capacity(attribute_max_size as usize)
//     name.extend(std::iter::repeat('\0').take(attribute_max_size as usize))
//     let length = 0
//     let size = 0
//     let atype = 0
//     gl.GetActiveAttrib(
//         u32(program),
//         index,
//         attribute_max_size,
//         &length,
//         &size,
//         &atype,
//         name.as_ptr() as *native_gl::GLchar,
//     )

//     name.truncate(length as usize)

//     Some(ActiveAttribute { name, size, atype })
// }

// get_sync_status :: proc "contextless" (fence: Fence) -> u32 {
//     let len = 0
//     let values = [UNSIGNALED as i32]
//     gl.GetSynciv(
//         fence.0,
//         SYNC_STATUS,
//         values.len() as i32,
//         &len,
//         values.as_mut_ptr(),
//     )
//     values[0] as u32
// }

// is_sync :: proc "contextless" (fence: Fence) -> bool {
//     1 == gl.IsSync(fence.0)
// }

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

// get_sampler_parameter_f32 :: proc "contextless" (sampler: Sampler, name: u32) -> f32 {
//     let value = 0.
//     gl.GetSamplerParameterfv(sampler.0.get(), name, &value)
//     value
// }

// get_sampler_parameter_f32_slice :: proc "contextless" (
//     sampler: Sampler,
//     name: u32,
//     out: []f32,
// ) {
//     gl.GetSamplerParameterfv(sampler.0.get(), name, out.as_mut_ptr())
// }

// generate_mipmap :: proc "contextless" (target: u32) {
//     gl.GenerateMipmap(target)
// }

// generate_texture_mipmap :: proc "contextless" (texture: Texture) {
//     gl.GenerateTextureMipmap(texture.0.get())
// }

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

// compressed_tex_image_1d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     internal_format: i32,
//     width: i32,
//     border: i32,
//     image_size: i32,
//     pixels: &[u8],
// ) {
//     gl.CompressedTexImage1D(
//         target,
//         level,
//         internal_format as u32,
//         width,
//         border,
//         image_size,
//         pixels.as_ptr() as *const std::ffi::c_void,
//     )
// }

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

// compressed_tex_image_3d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     internal_format: i32,
//     width: i32,
//     height: i32,
//     depth: i32,
//     border: i32,
//     image_size: i32,
//     pixels: &[u8],
// ) {
//     gl.CompressedTexImage3D(
//         target,
//         level,
//         internal_format as u32,
//         width,
//         height,
//         depth,
//         border,
//         image_size,
//         pixels.as_ptr() as *const std::ffi::c_void,
//     )
// }

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

// texture_storage_2d :: proc "contextless" (
//     texture: Texture,
//     levels: i32,
//     internal_format: u32,
//     width: i32,
//     height: i32,
// ) {
//     gl.TextureStorage2D(texture.0.get(), levels, internal_format, width, height)
// }

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

// texture_storage_3d :: proc "contextless" (
//     texture: Texture,
//     levels: i32,
//     internal_format: u32,
//     width: i32,
//     height: i32,
//     depth: i32,
// ) {
//     gl.TextureStorage3D(
//         texture.0.get(),
//         levels,
//         internal_format,
//         width,
//         height,
//         depth,
//     )
// }

// get_uniform_i32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: &[i32],
// ) {
//     gl.GetUniformiv(u32(program), location.0 as i32, v.as_mut_ptr())
// }

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

// uniform_1_i32 :: proc "contextless" (location: i32, x: i32) {
//     if let Some(loc) = location {
//         gl.Uniform1i(location, x)
//     }
// }

// uniform_2_i32 :: proc "contextless" (location: i32, x: i32, y: i32) {
//     if let Some(loc) = location {
//         gl.Uniform2i(location, x, y)
//     }
// }

// uniform_3_i32 :: proc "contextless" (
//     location: i32,
//     x: i32,
//     y: i32,
//     z: i32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform3i(location, x, y, z)
//     }
// }

// uniform_4_i32 :: proc "contextless" (
//     location: i32,
//     x: i32,
//     y: i32,
//     z: i32,
//     w: i32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform4i(location, x, y, z, w)
//     }
// }

// uniform_1_i32_slice :: proc "contextless" (location: i32, v: &[i32]) {
//     if let Some(loc) = location {
//         gl.Uniform1iv(location, i32(len(v)), raw_data(v))
//     }
// }

// uniform_2_i32_slice :: proc "contextless" (location: i32, v: &[i32]) {
//     if let Some(loc) = location {
//         gl.Uniform2iv(location, i32(len(v)) / 2, raw_data(v))
//     }
// }

// uniform_3_i32_slice :: proc "contextless" (location: i32, v: &[i32]) {
//     if let Some(loc) = location {
//         gl.Uniform3iv(location, i32(len(v)) / 3, raw_data(v))
//     }
// }

// uniform_4_i32_slice :: proc "contextless" (location: i32, v: &[i32]) {
//     if let Some(loc) = location {
//         gl.Uniform4iv(location, i32(len(v)) / 4, raw_data(v))
//     }
// }

uniform_1_u32 :: proc "contextless" (location: i32, x: u32) {
    gl.Uniform1ui(location, x)
}

// uniform_2_u32 :: proc "contextless" (location: i32, x: u32, y: u32) {
//     if let Some(loc) = location {
//         gl.Uniform2ui(location, x, y)
//     }
// }

// uniform_3_u32 :: proc "contextless" (
//     location: i32,
//     x: u32,
//     y: u32,
//     z: u32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform3ui(location, x, y, z)
//     }
// }

// uniform_4_u32 :: proc "contextless" (
//     location: i32,
//     x: u32,
//     y: u32,
//     z: u32,
//     w: u32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform4ui(location, x, y, z, w)
//     }
// }

// uniform_1_u32_slice :: proc "contextless" (location: i32, v: []u32) {
//     if let Some(loc) = location {
//         gl.Uniform1uiv(location, i32(len(v)), raw_data(v))
//     }
// }

// uniform_2_u32_slice :: proc "contextless" (location: i32, v: []u32) {
//     if let Some(loc) = location {
//         gl.Uniform2uiv(location, i32(len(v)) / 2, raw_data(v))
//     }
// }

// uniform_3_u32_slice :: proc "contextless" (location: i32, v: []u32) {
//     if let Some(loc) = location {
//         gl.Uniform3uiv(location, i32(len(v)) / 3, raw_data(v))
//     }
// }

// uniform_4_u32_slice :: proc "contextless" (location: i32, v: []u32) {
//     if let Some(loc) = location {
//         gl.Uniform4uiv(location, i32(len(v)) / 4, raw_data(v))
//     }
// }

// uniform_1_f32 :: proc "contextless" (location: i32, x: f32) {
//     if let Some(loc) = location {
//         gl.Uniform1f(location, x)
//     }
// }

// uniform_2_f32 :: proc "contextless" (location: i32, x: f32, y: f32) {
//     if let Some(loc) = location {
//         gl.Uniform2f(location, x, y)
//     }
// }

// uniform_3_f32 :: proc "contextless" (
//     location: i32,
//     x: f32,
//     y: f32,
//     z: f32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform3f(location, x, y, z)
//     }
// }

// uniform_4_f32 :: proc "contextless" (
//     location: i32,
//     x: f32,
//     y: f32,
//     z: f32,
//     w: f32,
// ) {
//     if let Some(loc) = location {
//         gl.Uniform4f(location, x, y, z, w)
//     }
// }

// uniform_1_f32_slice :: proc "contextless" (location: i32, v: []f32) {
//     if let Some(loc) = location {
//         gl.Uniform1fv(location, i32(len(v)), raw_data(v))
//     }
// }

// uniform_2_f32_slice :: proc "contextless" (location: i32, v: []f32) {
//     if let Some(loc) = location {
//         gl.Uniform2fv(location, i32(len(v)) / 2, raw_data(v))
//     }
// }

// uniform_3_f32_slice :: proc "contextless" (location: i32, v: []f32) {
//     if let Some(loc) = location {
//         gl.Uniform3fv(location, i32(len(v)) / 3, raw_data(v))
//     }
// }

// uniform_4_f32_slice :: proc "contextless" (location: i32, v: []f32) {
//     if let Some(loc) = location {
//         gl.Uniform4fv(location, i32(len(v)) / 4, raw_data(v))
//     }
// }

// uniform_matrix_2_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix2fv(
//             location,
//             i32(len(v)) / 4,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_2x3_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix2x3fv(
//             location,
//             i32(len(v)) / 6,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_2x4_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix2x4fv(
//             location,
//             i32(len(v)) / 8,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_3x2_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix3x2fv(
//             location,
//             i32(len(v)) / 6,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_3_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix3fv(
//             location,
//             i32(len(v)) / 9,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_3x4_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix3x4fv(
//             location,
//             i32(len(v)) / 12,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_4x2_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix4x2fv(
//             location,
//             i32(len(v)) / 8,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_4x3_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix4x3fv(
//             location,
//             i32(len(v)) / 12,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

// uniform_matrix_4_f32_slice :: proc "contextless" (
//     location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     if let Some(loc) = location {
//         gl.UniformMatrix4fv(
//             location,
//             i32(len(v)) / 16,
//             transpose,
//             raw_data(v),
//         )
//     }
// }

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

// fence_sync :: proc "contextless" (condition: u32, flags: u32) -> Result<Fence, string> {
//     Ok(NativeFence(gl.FenceSync(condition as u32, flags)))
// }

// tex_parameter_f32 :: proc "contextless" (target: u32, parameter: u32, value: f32) {
//     gl.TexParameterf(target, parameter, value)
// }

tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32, value: i32) {
    gl.TexParameteri(target, parameter, value)
}

// texture_parameter_i32 :: proc "contextless" (texture: Texture, parameter: u32, value: i32) {
//     gl.TextureParameteri(texture.0.get(), parameter, value)
// }

// tex_parameter_f32_slice :: proc "contextless" (target: u32, parameter: u32, values: []f32) {
//     gl.TexParameterfv(target, parameter, values.as_ptr())
// }

// tex_parameter_i32_slice :: proc "contextless" (target: u32, parameter: u32, values: &[i32]) {
//     gl.TexParameteriv(target, parameter, values.as_ptr())
// }

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

// depth_range_f64_slice :: proc "contextless" (first: u32, count: i32, values: &[[f64 2]]) {
//     gl.DepthRangeArrayv(first, count, values.as_ptr() as *const f64)
// }

scissor :: proc "contextless" (x: i32, y: i32, width: i32, height: i32) {
    gl.Scissor(x, y, width, height)
}

// scissor_slice :: proc "contextless" (first: u32, count: i32, scissors: &[[i32 4]]) {
//     gl.ScissorArrayv(first, count, scissors.as_ptr() as *const i32)
// }

// vertex_array_attrib_binding_f32 :: proc "contextless" (
//     vao: VertexArray,
//     index: u32,
//     binding_index: u32,
// ) {
//     gl.VertexArrayAttribBinding(vao.0.get(), index, binding_index)
// }

// vertex_array_attrib_format_f32 :: proc "contextless" (
//     vao: VertexArray,
//     index: u32,
//     size: i32,
//     data_type: u32,
//     normalized: bool,
//     relative_offset: u32,
// ) {
//     gl.VertexArrayAttribFormat(
//         vao.0.get(),
//         index,
//         size,
//         data_type,
//         normalized as u8,
//         relative_offset,
//     )
// }

// vertex_array_attrib_format_i32 :: proc "contextless" (
//     vao: VertexArray,
//     index: u32,
//     size: i32,
//     data_type: u32,
//     relative_offset: u32,
// ) {
//     gl.VertexArrayAttribIFormat(vao.0.get(), index, size, data_type, relative_offset)
// }

// vertex_array_attrib_format_f64 :: proc "contextless" (
//     vao: VertexArray,
//     index: u32,
//     size: i32,
//     data_type: u32,
//     relative_offset: u32,
// ) {
//     gl.VertexArrayAttribLFormat(vao.0.get(), index, size, data_type, relative_offset)
// }

// vertex_array_element_buffer :: proc "contextless" (
//     vao: VertexArray,
//     buffer: Buffer,
// ) {
//     gl.VertexArrayElementBuffer(vao.0.get(), buffer)
// }

// vertex_array_vertex_buffer :: proc "contextless" (
//     vao: VertexArray,
//     binding_index: u32,
//     buffer: Buffer,
//     offset: i32,
//     stride: i32,
// ) {
//     gl.VertexArrayVertexBuffer(
//         vao.0.get(),
//         binding_index,
//         buffer,
//         offset as isize,
//         stride,
//     )
// }

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

// debug_message_control :: proc "contextless" (
//     source: u32,
//     msg_type: u32,
//     severity: u32,
//     ids: []u32,
//     enabled: bool,
// ) {

//     let ids_ptr = if ids.is_empty() {
//         std::ptr::null()
//     } else {
//         ids.as_ptr()
//     }

//     khr_fallback!(
//         gl.DebugMessageControl_is_loaded,
//         gl.DebugMessageControlKHR,
//         gl.DebugMessageControl(
//             source,
//             msg_type,
//             severity,
//             ids.len() as i32,
//             ids_ptr,
//             enabled as u8,
//         ),
//     )
// }

// debug_message_insert :: proc "contextless" <S>(
//     source: u32,
//     msg_type: u32,
//     id: u32,
//     severity: u32,
//     msg: S,
// ) where
//     S: AsRef<str>,
// {
//     let message = msg.as_ref().as_bytes()
//     let length = message.len() as i32
//     khr_fallback!(
//         gl.DebugMessageInsert_is_loaded,
//         gl.DebugMessageInsertKHR,
//         gl.DebugMessageInsert(
//             source,
//             msg_type,
//             id,
//             severity,
//             length,
//             message.as_ptr() as *const native_gl::GLchar,
//         ),
//     )
// }

debug_message_callback :: proc "contextless" (callback: debug_proc_t, userParam: rawptr) {
    if ctx.version.is_embedded {
        if glDebugMessageCallbackKHR != nil {
            glDebugMessageCallbackKHR(callback, userParam)
        }
    } else {
        gl.DebugMessageCallback(callback, userParam)
    }
}

// get_debug_message_log :: proc "contextless" (count: u32) -> Vec<DebugMessageLogEntry> {
//     let ct = count as usize
//     let sources = Vec::with_capacity(ct)
//     let types = Vec::with_capacity(ct)
//     let ids = Vec::with_capacity(ct)
//     let severities = Vec::with_capacity(ct)
//     let lengths = Vec::with_capacity(ct)
//     let buf_size = (count * MAX_DEBUG_MESSAGE_LENGTH) as i32
//     let message_log = Vec::with_capacity(buf_size as usize)

//     let received = khr_fallback!(
//         gl.GetDebugMessageLog_is_loaded,
//         gl.GetDebugMessageLogKHR,
//         gl.GetDebugMessageLog(
//             count,
//             buf_size,
//             sources.as_mut_ptr(),
//             types.as_mut_ptr(),
//             ids.as_mut_ptr(),
//             severities.as_mut_ptr(),
//             lengths.as_mut_ptr(),
//             message_log.as_mut_ptr(),
//         ),
//     ) as usize

//     sources.set_len(received)
//     types.set_len(received)
//     ids.set_len(received)
//     severities.set_len(received)
//     lengths.set_len(received)
//     message_log.set_len(buf_size as usize)

//     let entries = Vec::new()
//     let offset = 0
//     for i in 0..received {
//         let message =
//             std::ffi::CStr::from_ptr(message_log[offset..].as_ptr()).to_string_lossy()
//         offset += lengths[i] as usize
//         entries.push(DebugMessageLogEntry {
//             source: sources[i],
//             msg_type: types[i],
//             id: ids[i],
//             severity: severities[i],
//             message: message.to_string(),
//         })
//     }

//     entries
// }

// push_debug_group :: proc "contextless" <S>(source: u32, id: u32, message: S)
// where
//     S: AsRef<str>,
// {
//     let msg = message.as_ref().as_bytes()
//     let length = msg.len() as i32
//     khr_fallback!(
//         gl.PushDebugGroup_is_loaded,
//         gl.PushDebugGroupKHR,
//         gl.PushDebugGroup(source, id, length, msg.as_ptr() as *const native_gl::GLchar),
//     )
// }

// pop_debug_group :: proc "contextless" (&self) {
//     khr_fallback!(
//         gl.PopDebugGroup_is_loaded,
//         gl.PopDebugGroupKHR,
//         gl.PopDebugGroup(),
//     )
// }

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

// get_object_label :: proc "contextless" (identifier: u32, name: u32) -> string {
//     let len = 0
//     let label_buf = Vec::with_capacity(self.constants.max_label_length as usize)
//     khr_fallback!(
//         gl.GetObjectLabel_is_loaded,
//         gl.GetObjectLabelKHR,
//         gl.GetObjectLabel(
//             identifier,
//             name,
//             self.constants.max_label_length,
//             &len,
//             label_buf.as_mut_ptr(),
//         ),
//     )
//     label_buf.set_len(len as usize)
//     std::ffi::CStr::from_ptr(label_buf.as_ptr())
//         .to_str()
//         .unwrap()
//         .to_owned()
// }

// object_ptr_label :: proc "contextless" <S>(sync: Fence, label: Option<S>)
// where
//     S: AsRef<str>,
// {

//     match label {
//         Some(l) => {
//             let lbl = l.as_ref().as_bytes()
//             let length = lbl.len() as i32
//             khr_fallback!(
//                 gl.ObjectPtrLabel_is_loaded,
//                 gl.ObjectPtrLabelKHR,
//                 gl.ObjectPtrLabel(
//                     sync.0 as *std::ffi::c_void,
//                     length,
//                     lbl.as_ptr() as *const native_gl::GLchar,
//                 ),
//             )
//         }
//         None => {
//             khr_fallback!(
//                 gl.ObjectPtrLabel_is_loaded,
//                 gl.ObjectPtrLabelKHR,
//                 gl.ObjectPtrLabel(sync.0 as *std::ffi::c_void, 0, std::ptr::null()),
//             )
//         }
//     }
// }

// get_object_ptr_label :: proc "contextless" (sync: Fence) -> string {
//     let len = 0
//     let label_buf = Vec::with_capacity(self.constants.max_label_length as usize)
//     khr_fallback!(
//         gl.GetObjectPtrLabel_is_loaded,
//         gl.GetObjectPtrLabelKHR,
//         gl.GetObjectPtrLabel(
//             sync.0 as *std::ffi::c_void,
//             self.constants.max_label_length,
//             &len,
//             label_buf.as_mut_ptr(),
//         ),
//     )
//     label_buf.set_len(len as usize)
//     std::ffi::CStr::from_ptr(label_buf.as_ptr())
//         .to_str()
//         .unwrap()
//         .to_owned()
// }

// get_uniform_block_index :: proc "contextless" (program: Program, name: &str) -> Option<u32> {
//     let name = CString::new(name).unwrap()
//     let index = gl.GetUniformBlockIndex(u32(program), name.as_ptr())
//     if index == INVALID_INDEX {
//         None
//     } else {
//         Some(index)
//     }
// }

// get_uniform_indices :: proc "contextless" (
//     program: Program,
//     names: &[&str],
// ) -> Vec<Option<u32>> {
//     let c_names = names
//         .iter()
//         .map(|&name| CString::new(name).unwrap())
//         .collect::<Vec<_>>()
//     let c_name_ptrs = c_names.iter().map(|name| name.as_ptr()).collect::<Vec<_>>()

//     let count = names.len()
//     let indices = vec![0 count]
//     gl.GetUniformIndices(
//         u32(program),
//         count as _,
//         c_name_ptrs.as_ptr(),
//         indices.as_mut_ptr(),
//     )
//     indices
//         .iter()
//         .map(|&index| {
//             if index == INVALID_INDEX {
//                 None
//             } else {
//                 Some(index)
//             }
//         })
//         .collect()
// }

// uniform_block_binding :: proc "contextless" (program: Program, index: u32, binding: u32) {
//     gl.UniformBlockBinding(u32(program), index, binding)
// }

// get_shader_storage_block_index :: proc "contextless" (
//     program: Program,
//     name: &str,
// ) -> Option<u32> {
//     let name = CString::new(name).unwrap()
//     let index =
//         gl.GetProgramResourceIndex(u32(program), SHADER_STORAGE_BLOCK, name.as_ptr())
//     if index == INVALID_INDEX {
//         None
//     } else {
//         Some(index)
//     }
// }

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

// named_framebuffer_read_buffer :: proc "contextless" (
//     framebuffer: Option<Framebuffer>,
//     src: u32,
// ) {
//     gl.NamedFramebufferReadBuffer(framebuffer.map(|f| f.0.get()).unwrap_or(0), src)
// }

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

// create_transform_feedback :: proc "contextless" (&self) -> Result<TransformFeedback, string> {
//     let name = 0
//     gl.GenTransformFeedbacks(1, &name)
//     NonZeroU32::new(name)
//         .map(NativeTransformFeedback)
//         .ok_or_else(|| string::from("Unable to create TransformFeedback object"))
// }

// is_transform_feedback :: proc "contextless" (transform_feedback: TransformFeedback) -> bool {
//     gl.IsTransformFeedback(transform_feedback.0.get()) != 0
// }

// delete_transform_feedback :: proc "contextless" (transform_feedback: TransformFeedback) {
//     gl.DeleteTransformFeedbacks(1, &transform_feedback.0.get())
// }

// bind_transform_feedback :: proc "contextless" (
//     target: u32,
//     transform_feedback: Option<TransformFeedback>,
// ) {
//     gl.BindTransformFeedback(target, transform_feedback.map(|tf| tf.0.get()).unwrap_or(0))
// }

// begin_transform_feedback :: proc "contextless" (primitive_mode: u32) {
//     gl.BeginTransformFeedback(primitive_mode)
// }

// end_transform_feedback :: proc "contextless" (&self) {
//     gl.EndTransformFeedback()
// }

// pause_transform_feedback :: proc "contextless" (&self) {
//     gl.PauseTransformFeedback()
// }

// resume_transform_feedback :: proc "contextless" (&self) {
//     gl.ResumeTransformFeedback()
// }

// transform_feedback_varyings :: proc "contextless" (
//     program: Program,
//     varyings: &[&str],
//     buffer_mode: u32,
// ) {

//     let strings: Vec<CString> = varyings
//         .iter()
//         .copied()
//         .map(CString::new)
//         .collect::<Result<_, _>>()
//         .unwrap()
//     let varyings: Vec<_> = strings.iter().map(|c_str| c_str.as_ptr()).collect()

//     gl.TransformFeedbackVaryings(
//         u32(program),
//         varyings.len() as i32,
//         varyings.as_ptr(),
//         buffer_mode,
//     )
// }

// get_transform_feedback_varying :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveTransformFeedback> {

//     const max_name_size: usize = 256
//     let name_bytes = [0 max_name_size]

//     let size = 0
//     let tftype = 0

//     gl.GetTransformFeedbackVarying(
//         u32(program),
//         index,
//         name_bytes.len() as i32,
//         std::ptr::null_mut(),
//         &size,
//         &tftype,
//         name_bytes.as_mut_ptr(),
//     )

//     let name = CStr::from_ptr(name_bytes.as_mut_ptr())
//         .to_string_lossy()
//         .into_owned()

//     Some(ActiveTransformFeedback { size, tftype, name })
// }

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

// get_active_uniform_block_parameter_i32 :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
//     parameter: u32,
// ) -> i32 {
//     let value = 0
//     gl.GetActiveUniformBlockiv(u32(program), uniform_block_index, parameter, &value)
//     value
// }

// get_active_uniform_block_parameter_i32_slice :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
//     parameter: u32,
//     out: &[i32],
// ) {
//     gl.GetActiveUniformBlockiv(
//         u32(program),
//         uniform_block_index,
//         parameter,
//         out.as_mut_ptr(),
//     )
// }
// get_active_uniform_block_name :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
// ) -> string {

//     // Probe for the length of the name of the uniform block, and, failing
//     // that, fall back to allocating a buffer that is 256 bytes long. This
//     // should be good enough for pretty much all contexts, including faulty
//     // or partially faulty ones.
//     let len = self.get_active_uniform_block_parameter_i32(
//         program,
//         uniform_block_index,
//         crate::UNIFORM_BLOCK_NAME_LENGTH,
//     )
//     let len = if gl.GetError() == crate::NO_ERROR && len > 0 {
//         len as usize
//     } else {
//         256
//     }

//     let buffer = vec![0 len]
//     let length = 0
//     gl.GetActiveUniformBlockName(
//         u32(program),
//         uniform_block_index,
//         buffer.len() as _,
//         &length,
//         buffer.as_mut_ptr(),
//     )

//     if length > 0 {
//         assert_eq!(
//             std::mem::size_of::<u8>(),
//             std::mem::size_of::<native_gl::GLchar>(),
//             "This operation is only safe in systems in which the length of \
//             a GLchar is the same as that of an u8"
//         )
//         assert_eq!(
//             std::mem::align_of::<u8>(),
//             std::mem::align_of::<native_gl::GLchar>(),
//             "This operation is only safe in systems in which the alignment \
//             of a GLchar is the same as that of an u8"
//         )
//         let buffer = std::slice::from_raw_parts(
//             buffer.as_ptr() as *const u8,
//             (length as usize + 1).min(buffer.len()),
//         )

//         let name = CStr::from_bytes_with_nul(&buffer[..])
//             .unwrap()
//             .to_str()
//             .unwrap()
//             .to_owned()

//         name
//     } else {
//         string::from("")
//     }
// }

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

// get_internal_format_i32_slice :: proc "contextless" (
//     target: u32,
//     internal_format: u32,
//     pname: u32,
//     result: &[i32],
// ) {
//     gl.GetInternalformativ(
//         target,
//         internal_format,
//         pname,
//         result.len() as _,
//         result.as_mut_ptr(),
//     )
// }
