#+build js
package gl

// Core
import "base:runtime"
import "core:mem"
import "core:strings"

// Vendor
import gl "webgl"

WebGLContextAttributes :: gl.ContextAttributes

Context :: struct {
    using base: ContextBase,
}

@private
ctx: Context

init_context :: proc(
    canvas_id: string,
    attributes := gl.DEFAULT_CONTEXT_ATTRIBUTES,
    loc := #caller_location,
) -> (
    ok: bool,
) {
    ensure(gl.CreateCurrentContextById(canvas_id, attributes),
        "WebGL: gl.CreateCurrentContextById failed", loc)
    ensure(gl.SetCurrentContextById(canvas_id), "WebGL: gl.SetCurrentContextById failed", loc)

    ctx.allocator = runtime.default_allocator()

    version_str_buf: [128]u8
    version_str := get_parameter_string(VERSION, version_str_buf[:])
    ctx.version = version_parse(version_str, ctx.allocator) or_return

    // Initialize an arena allocator with enough space to clone the supported
    // extensions strings.
    ctx.arena_buf = make([]byte, 256 * mem.Kilobyte, ctx.allocator)
    defer if !ok { delete(ctx.arena_buf) }
    mem.arena_init(&ctx.arena, ctx.arena_buf)

    buf_allocator := mem.arena_allocator(&ctx.arena)
    ctx.extensions = make(ExtensionSet, ctx.allocator)

    ext_buf: [256]byte
    i := 0
    for ext in gl.IterateSupportedExtensions(&i, ext_buf[:]) {
        gl.GetExtension(ext)
        ctx.extensions[strings.clone(ext, buf_allocator)] = {}
    }

    return true
}

deinit_context :: proc() {
    context.allocator = ctx.allocator
    delete(ctx.extensions)
    delete(ctx.arena_buf)
}

// Returns true if the `WEBGL_compressed_texture_astc` extension is enabled and the
// "ldr" profile is supported.
compressed_texture_astc_supports_ldr_profile :: proc() -> bool {
    return gl.ASTCSupportLDRProfile()
}

// Returns true if the `WEBGL_compressed_texture_astc` extension is enabled and the
// "hdr" profile is supported.
compressed_texture_astc_supports_hdr_profile :: proc() -> bool {
    return gl.ASTCSupportHDRProfile()
}

supports_debug :: proc "contextless" () -> bool {
    return false
}

create_framebuffer :: proc "contextless" () -> Framebuffer {
    return Framebuffer(gl.CreateFramebuffer())
}

create_named_framebuffer :: proc "contextless" () -> Framebuffer {
    unimplemented_contextless()
}

is_framebuffer :: proc "contextless" (framebuffer: Framebuffer) -> bool {
    return gl.IsFramebuffer(u32(framebuffer))
}

create_query :: proc "contextless" () -> Query {
    return Query(gl.CreateQuery())
}

create_renderbuffer :: proc "contextless" () -> Renderbuffer {
    return Renderbuffer(gl.CreateRenderbuffer())
}

is_renderbuffer :: proc "contextless" (renderbuffer: Renderbuffer) -> bool {
    return gl.IsRenderbuffer(u32(renderbuffer))
}

create_sampler :: proc "contextless" () -> Sampler {
    return Sampler(gl.CreateSampler())
}

create_shader :: proc "contextless" (shader_type: u32) -> Shader {
    return Shader(gl.CreateShader(u32(shader_type)))
}

is_shader :: proc "contextless" (shader: Shader) -> bool {
    return gl.IsShader(u32(shader))
}

create_texture :: proc "contextless" () -> Texture {
    return Texture(gl.CreateTexture())
}

create_named_texture :: proc "contextless" (target: u32) -> Texture {
    unimplemented_contextless()
}

is_texture :: proc "contextless" (texture: Texture) -> bool {
    return gl.IsTexture(u32(texture))
}

delete_shader :: proc "contextless" (shader: Shader) {
    gl.DeleteShader(u32(shader))
}

shader_source :: proc "contextless" (shader: Shader, source: string) {
    gl.ShaderSource(u32(shader), {source})
}

compile_shader :: proc "contextless" (shader: Shader) {
    gl.CompileShader(u32(shader))
}

get_shader_completion_status :: proc "contextless" (shader: Shader) -> bool {
    status := gl.GetShaderiv(u32(shader), u32(COMPLETION_STATUS))
    return status == 1
}

get_shader_compile_status :: proc "contextless" (shader: Shader) -> bool {
    status := gl.GetShaderiv(u32(shader), u32(COMPILE_STATUS))
    return status == 1
}

get_shader_info_log :: proc "contextless" (shader: Shader, buf: []u8) -> string {
    return gl.GetShaderInfoLog(u32(shader), buf)
}

get_shader_precision_format :: proc "contextless" (
    shader_type: u32,
    precision_mode: u32,
) -> ShaderPrecisionFormat {
    range_min, range_max, precision: i32
    gl.GetShaderPrecisionFormat(shader_type, precision_mode, &range_min, &range_max, &precision)
    return { range_min, range_max, precision }
}

get_tex_image :: proc "contextless" (
    target: u32,
    level: i32,
    format: u32,
    type: u32,
    pixels: PixelPackData,
) {
    unimplemented_contextless()
}

create_program :: proc "contextless" () -> Program {
    return Program(gl.CreateProgram())
}

is_program :: proc "contextless" (program: Program) -> bool {
    return gl.IsProgram(u32(program))
}

delete_program :: proc "contextless" (program: Program) {
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
    param := gl.GetProgramParameter(u32(program), COMPLETION_STATUS)
    return param == 1
}

get_program_link_status :: proc "contextless" (program: Program) -> bool {
    param := gl.GetProgramParameter(u32(program), LINK_STATUS)
    return param == 1
}

get_program_validate_status :: proc "contextless" (program: Program) -> bool {
    param := gl.GetProgramParameter(u32(program), VALIDATE_STATUS)
    return param == 1
}

get_program_parameter_i32 :: proc "contextless" (program: Program, parameter: u32) -> i32 {
    return gl.GetProgramParameter(u32(program), parameter)
}

get_program_info_log :: proc "contextless" (program: Program, buf: []u8) -> string {
    return gl.GetProgramInfoLog(u32(program), buf)
}

get_program_resource_i32_alloc :: proc(
    program: u32,
    interface: u32,
    index: u32,
    properties: []u32,
    allocator := context.allocator,
) -> []i32 {
    unimplemented()
}

get_program_resource_i32_buf :: proc "contextless" (
    program: u32,
    interface: u32,
    index: u32,
    properties: []u32,
    buf: []i32,
) -> []i32 {
    unimplemented_contextless()
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
    unimplemented_contextless()
}

program_uniform_2_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
) {
    unimplemented_contextless()
}

program_uniform_3_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
    z: i32,
) {
    unimplemented_contextless()
}

program_uniform_4_i32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: i32,
    y: i32,
    z: i32,
    w: i32,
) {
    unimplemented_contextless()
}

program_uniform_1_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    unimplemented_contextless()
}

program_uniform_2_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    unimplemented_contextless()
}

program_uniform_3_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_4_i32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []i32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_1_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_2_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_3_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
    z: u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_4_u32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: u32,
    y: u32,
    z: u32,
    w: u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_1_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_2_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_3_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_4_u32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []u32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_1_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_2_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_3_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
    z: f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_4_f32 :: proc "contextless" (
    program: Program,
    location: i32,
    x: f32,
    y: f32,
    z: f32,
    w: f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_1_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_2x3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_2x4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_3x2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_3x4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_4x2_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_4x3_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_uniform_matrix_4_f32_slice :: proc "contextless" (
    program: Program,
    location: i32,
    transpose: bool,
    v: []f32,
) {
    unimplemented_contextless("DSA program objects are not supported")
}

program_binary_retrievable_hint :: proc "contextless" (_program: Program, _value: bool) {
    unimplemented_contextless("Program binaries are not supported")
}

get_program_binary :: proc (
    program: Program,
    allocator := context.allocator,
) -> ProgramBinary {
    unimplemented_contextless("Program binaries are not supported")
}

program_binary :: proc "contextless" (program: Program, binary: ProgramBinary) {
    unimplemented_contextless("Program binaries are not supported")
}

get_active_uniforms :: proc "contextless" (program: Program) -> u32 {
    return u32(gl.GetProgramParameter(u32(program), ACTIVE_UNIFORMS))
}

get_active_uniforms_parameter :: proc "contextless" (
    program: Program,
    uniforms: []u32,
    pname: u32,
) -> []i32 {
    unimplemented_contextless("GetActiveUniformsiv is not supported")
}

// get_active_uniform :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveUniform> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.get_active_uniform(raw_program, index)
//                 .map(|au| ActiveUniform {
//                     size: au.size(),
//                     utype: au.type_(),
//                     name: au.name(),
//                 })
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.get_active_uniform(raw_program, index)
//                 .map(|au| ActiveUniform {
//                     size: au.size(),
//                     utype: au.type_(),
//                     name: au.name(),
//                 })
//         }
//     }
// }

use_program :: proc "contextless" (program: Program) {
    gl.UseProgram(u32(program))
}

create_buffer :: proc "contextless" () -> Buffer {
    return Buffer(gl.CreateBuffer())
}

// create_buffer :: proc "contextless" (&self) -> Result<Buffer, string> {
//     let raw_buffer = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.create_buffer(),
//         RawRenderingContext::WebGl2(ref gl) => gl.create_buffer(),
//     };

//     match raw_buffer {
//         Some(p) => {
//             let key = self.buffers.borrow_mut().insert(p)
//             Ok(key)
//         }
//         None => Err(string::from("Unable to create buffer object")),
//     }
// }

// create_named_buffer :: proc "contextless" (&self) -> Result<Buffer, string> {
//     unimplemented!()
// }

// is_buffer :: proc "contextless" (buffer: Buffer) -> bool {
//     let buffers = self.buffers.borrow()
//     if let Some(b) = buffers.get(buffer) {
//         match self.raw {
//             RawRenderingContext::WebGl1(ref gl) => gl.is_buffer(Some(b)),
//             RawRenderingContext::WebGl2(ref gl) => gl.is_buffer(Some(b)),
//         }
//     } else {
//         false
//     }
// }

bind_buffer :: proc "contextless" (target: u32, buffer: Buffer) {
    gl.BindBuffer(target, u32(buffer))
}

bind_buffer_base :: proc "contextless" (target: u32, index: u32, buffer: Buffer) {
    gl.BindBufferBase(target, i32(index), u32(buffer))
}

bind_buffer_range :: proc "contextless" (
    target: u32,
    index: u32,
    buffer: Buffer,
    offset: i32,
    size: i32,
) {
    gl.BindBufferRange(target, i32(index), u32(buffer), int(offset), int(size))
}

bind_vertex_buffer :: proc "contextless" (
    binding_index: u32,
    buffer: Buffer,
    offset: i32,
    stride: i32,
) {
    unimplemented_contextless()
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
//     _read_buffer: Option<Framebuffer>,
//     _draw_buffer: Option<Framebuffer>,
//     _src_x0: i32,
//     _src_y0: i32,
//     _src_x1: i32,
//     _src_y1: i32,
//     _dst_x0: i32,
//     _dst_y0: i32,
//     _dst_x1: i32,
//     _dst_y1: i32,
//     _mask: u32,
//     _filter: u32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

create_vertex_array :: proc "contextless" () -> VertexArray {
    return VertexArray(gl.CreateVertexArray())
}

// create_named_vertex_array :: proc "contextless" (&self) -> Result<VertexArray, string> {
//     unimplemented!()
// }

delete_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    gl.DeleteVertexArray(u32(vertex_array))
}

bind_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    gl.BindVertexArray(u32(vertex_array))
}

// clear_color :: proc "contextless" (red: f32, green: f32, blue: f32, alpha: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.clear_color(red, green, blue, alpha),
//         RawRenderingContext::WebGl2(ref gl) => gl.clear_color(red, green, blue, alpha),
//     }
// }

supports_f64_precision :: proc "contextless" () -> bool {
    return false
}

clear_depth_f64 :: proc "contextless" (depth: f64) {
    unimplemented_contextless()
}

clear_depth_f32 :: proc "contextless" (depth: f32) {
    gl.ClearDepth(depth)
}

clear_depth :: proc "contextless" (depth: f64) {
    clear_depth_f32(f32(depth))
}

clear_stencil :: proc "contextless" (stencil: i32) {
    gl.ClearStencil(stencil)
}

clear :: proc "contextless" (mask: u32) {
    gl.Clear(mask)
}

// patch_parameter_i32 :: proc "contextless" (_parameter: u32, _value: i32) {
//     unimplemented_contextless("Patch parameter is not supported")
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
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Get frag data location is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.get_frag_data_location(raw_program, name),
//     }
// }

// bind_frag_data_location :: proc "contextless" (
//     _program: Program,
//     _color_number: u32,
//     _name: &str,
// ) {
//     unimplemented_contextless("Bind frag data location is not supported")
// }

buffer_data_size :: proc "contextless" (target: u32, size: i32, usage: u32) {
    gl.BufferData(target, int(size), nil, usage)
}

// named_buffer_data_size :: proc "contextless" (_buffer: Buffer, _size: i32, _usage: u32) {
//     unimplemented!()
// }

buffer_data_u8_slice :: proc "contextless" (target: u32, data: []u8, usage: u32) {
    gl.BufferData(
        target,
        int(len(data)),
        raw_data(data),
        usage,
    )
}

// named_buffer_data_u8_slice :: proc "contextless" (_buffer: Buffer, _data: &[u8], _usage: u32) {
//     unimplemented!()
// }

buffer_sub_data_u8_slice :: proc "contextless" (target: u32, offset: i32, src_data: []u8) {
    gl.BufferSubData(
        target,
        uintptr(offset),
        len(src_data),
        raw_data(src_data),
    )
}

// named_buffer_sub_data_u8_slice :: proc "contextless" (
//     _buffer: Buffer,
//     _offset: i32,
//     _src_data: &[u8],
// ) {
//     unimplemented!()
// }

get_buffer_sub_data :: proc "contextless" (target: u32, offset: i32, dst_data: []u8) {
    gl.GetBufferSubData(
        target,
        int(offset),
        dst_data,
    )
}

// get_buffer_sub_data :: proc "contextless" (target: u32, offset: i32, dst_data: &mut [u8]) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("get_buffer_sub_data not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             let array = js_sys::Uint8Array::view(dst_data)
//             gl.get_buffer_sub_data_with_i32_and_array_buffer_view(target, offset, &array)
//         }
//     }
// }

// tex_buffer :: proc "contextless" (target: u32, internal_format: u32, buffer: Option<Buffer>) {
//     unimplemented_contextless("Buffer textures are not supported")
// }

buffer_storage :: proc "contextless" (target: u32, size: i32, data: []u8, flags: u32) {
    unimplemented_contextless()
}

// named_buffer_storage :: proc "contextless" (
//     buffer: Buffer,
//     size: i32,
//     data: Option<&[u8]>,
//     flags: u32,
// ) {
//     unimplemented_contextless("Named buffer storage is not supported")
// }

check_framebuffer_status :: proc "contextless" (target: u32) -> u32 {
    return gl.CheckFramebufferStatus(target)
}

// check_named_framebuffer_status :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _target: u32,
// ) -> u32 {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

clear_buffer_i32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []i32) {
    gl.ClearBufferiv(target, i32(draw_buffer), values)
}

clear_buffer_u32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []u32) {
    gl.ClearBufferuiv(target, i32(draw_buffer), values)
}

clear_buffer_f32_slice :: proc "contextless" (target: u32, draw_buffer: u32, values: []f32) {
    gl.ClearBufferfv(target, i32(draw_buffer), values)
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
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Clear buffer depth stencil is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.clear_bufferfi(target, draw_buffer as i32, depth, stencil)
//         }
//     }
// }

// clear_named_framebuffer_i32_slice :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _target: u32,
//     _draw_buffer: u32,
//     _values: &[i32],
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// clear_named_framebuffer_u32_slice :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _target: u32,
//     _draw_buffer: u32,
//     _values: []u32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// clear_named_framebuffer_f32_slice :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _target: u32,
//     _draw_buffer: u32,
//     _values: []f32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// clear_named_framebuffer_depth_stencil :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _target: u32,
//     _draw_buffer: u32,
//     _depth: f32,
//     _stencil: i32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// client_wait_sync :: proc "contextless" (fence: Fence, flags: u32, timeout: i32) -> u32 {
//     let fences = self.fences.borrow()
//     let raw_fence = fences.get_unchecked(fence)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Client wait sync is not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.client_wait_sync_with_u32(raw_fence, flags, timeout as u32)
//         }
//     }
// }

// get_sync_parameter_i32 :: proc "contextless" (fence: Fence, parameter: u32) -> i32 {
//     let fences = self.fences.borrow()
//     let raw_fence = fences.get_unchecked(fence)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("get sync parameter is not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_sync_parameter(raw_fence, parameter),
//     }
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// wait_sync :: proc "contextless" (fence: Fence, flags: u32, timeout: u64) {
//     let fences = self.fences.borrow()
//     let raw_fence = fences.get_unchecked(fence)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Wait sync is not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.wait_sync_with_i32(raw_fence, flags, timeout as i32)
//         }
//     }
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
//     _src_name: Texture,
//     _src_target: u32,
//     _src_level: i32,
//     _src_x: i32,
//     _src_y: i32,
//     _src_z: i32,
//     _dst_name: Texture,
//     _dst_target: u32,
//     _dst_level: i32,
//     _dst_x: i32,
//     _dst_y: i32,
//     _dst_z: i32,
//     _src_width: i32,
//     _src_height: i32,
//     _src_depth: i32,
// ) {
//     unimplemented!()
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
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.copy_tex_image_2d(target, level, internal_format, x, y, width, height, border)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.copy_tex_image_2d(target, level, internal_format, x, y, width, height, border)
//         }
//     }
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
    gl.DeleteBuffer(u32(buffer))
}

delete_framebuffer :: proc "contextless" (framebuffer: Framebuffer) {
    gl.DeleteFramebuffer(u32(framebuffer))
}

// delete_query :: proc "contextless" (query: Query) {
//     let mut queries = self.queries.borrow_mut()
//     if let Some(ref r) = queries.remove(query) {
//         match self.raw {
//             RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Query objects are not supported"),
//             RawRenderingContext::WebGl2(ref gl) => gl.delete_query(Some(r)),
//         }
//     }
// }

delete_renderbuffer :: proc "contextless" (renderbuffer: Renderbuffer) {
    gl.DeleteRenderbuffer(u32(renderbuffer))
}

delete_sampler :: proc "contextless" (sampler: Sampler) {
    gl.DeleteSampler(u32(sampler))
}

// delete_sync :: proc "contextless" (fence: Fence) {
//     let mut fences = self.fences.borrow_mut()
//     if let Some(ref f) = fences.remove(fence) {
//         match self.raw {
//             RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Fences are not supported"),
//             RawRenderingContext::WebGl2(ref gl) => gl.delete_sync(Some(f)),
//         }
//     }
// }

delete_texture :: proc "contextless" (texture: Texture) {
    gl.DeleteTexture(u32(texture))
}

disable :: proc "contextless" (parameter: u32) {
    gl.Disable(parameter)
}

disable_draw_buffer :: proc "contextless" (parameter: u32, draw_buffer: u32) {
    unimplemented_contextless("Draw buffer disable is not supported")
}

disable_vertex_attrib_array :: proc "contextless" (index: u32) {
    gl.DisableVertexAttribArray(i32(index))
}

dispatch_compute :: proc "contextless" (groups_x: u32, groups_y: u32, groups_z: u32) {
    unimplemented_contextless("Dispatch compute is not supported")
}

dispatch_compute_indirect :: proc "contextless" (offset: i32) {
    unimplemented_contextless("Dispatch compute indirect is not supported")
}

draw_arrays :: proc "contextless" (mode: u32, first: i32, count: i32) {
    gl.DrawArrays(mode, int(first), int(count))
}

draw_arrays_instanced :: proc "contextless" (
    mode: u32,
    first: i32,
    count: i32,
    instance_count: i32,
) {
    gl.DrawArraysInstanced(mode, int(first), int(count), int(instance_count))
}

draw_arrays_instanced_base_instance :: proc "contextless" (
    mode: u32,
    first: i32,
    count: i32,
    instance_count: i32,
    base_instance: u32,
) {
    unimplemented_contextless("Draw arrays instanced base instance is not supported")
}

draw_arrays_indirect_offset :: proc "contextless" (mode: u32, offset: i32) {
    unimplemented_contextless("Draw arrays indirect is not supported")
}

// draw_buffer :: proc "contextless" (draw_buffer: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             if let Some(ext) = &self.extensions.webgl_draw_buffers {
//                 ext.draw_buffers_webgl(&Array::of1(&draw_buffer.into()))
//             } else {
//                 unimplemented_contextless("webgl1 WEBGL_draw_buffers extension not available")
//             }
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.draw_buffers(&Array::of1(&draw_buffer.into()))
//         }
//     }
// }

// named_framebuffer_draw_buffer :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _draw_buffer: u32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

draw_buffers :: proc "contextless" (buffers: []u32) {
    gl.DrawBuffers(buffers)
}

// named_framebuffer_draw_buffers :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _draw_buffers: []u32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// draw_elements :: proc "contextless" (mode: u32, count: i32, element_type: u32, offset: i32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.draw_elements_with_i32(mode as u32, count, element_type as u32, offset)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.draw_elements_with_i32(mode as u32, count, element_type as u32, offset)
//         }
//     }
// }

// draw_elements_base_vertex :: proc "contextless" (
//     _mode: u32,
//     _count: i32,
//     _element_type: u32,
//     _offset: i32,
//     _base_vertex: i32,
// ) {
//     unimplemented_contextless("Draw elements base vertex is not supported")
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
        int(count),
        element_type,
        int(offset),
        int(instance_count),
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
    unimplemented_contextless("Draw elements instanced base vertex is not supported")
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
    unimplemented_contextless(
        "Draw elements instanced base vertex base instance is not supported")
}

draw_elements_indirect_offset :: proc "contextless" (mode: u32, element_type: u32, offset: i32) {
    unimplemented_contextless("Draw elements indirect is not supported")
}

enable :: proc "contextless" (parameter: u32) {
    gl.Enable(parameter)
}

// is_enabled :: proc "contextless" (parameter: u32) -> bool {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.is_enabled(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.is_enabled(parameter),
//     }
// }

enable_draw_buffer :: proc "contextless" (parameter: u32, draw_buffer: u32) {
    unimplemented_contextless("Draw buffer enable is not supported")
}

enable_vertex_array_attrib :: proc "contextless" (vao: VertexArray, index: u32) {
    unimplemented_contextless()
}

enable_vertex_attrib_array :: proc "contextless" (index: u32) {
    gl.EnableVertexAttribArray(i32(index))
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
//     _target: u32,
//     _attachment: u32,
//     _texture: Option<Texture>,
//     _level: i32,
// ) {
//     unimplemented_contextless("Framebuffer texture is not supported")
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
    unimplemented_contextless("Framebuffer texture 2D multisample is not supported")
}

framebuffer_texture_3d :: proc "contextless" (
    target: u32,
    attachment: u32,
    texture_target: u32,
    texture: Texture,
    level: i32,
    layer: i32,
) {
    unimplemented_contextless("Framebuffer texture 3D is not supported")
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
//     _framebuffer: Option<Framebuffer>,
//     _attachment: u32,
//     _renderbuffer_target: u32,
//     _renderbuffer: Option<Renderbuffer>,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// named_framebuffer_texture :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _attachment: u32,
//     _texture: Option<Texture>,
//     _level: i32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// named_framebuffer_texture_layer :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _attachment: u32,
//     _texture: Option<Texture>,
//     _level: i32,
//     _layer: i32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

front_face :: proc "contextless" (value: u32) {
    gl.FrontFace(value)
}

// get_error :: proc "contextless" (&self) -> u32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_error(),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_error(),
//     }
// }

// get_tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_tex_parameter(target, parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_tex_parameter(target, parameter),
//     }
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_tex_parameter_f32 :: proc "contextless" (target: u32, parameter: u32) -> f32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_tex_parameter(target, parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_tex_parameter(target, parameter),
//     }
//     .as_f64()
//     .map(|v| v as f32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0.)
// }

// get_texture_level_parameter_i32 :: proc "contextless" (
//     _texture: Texture,
//     _level: i32,
//     _parameter: u32,
// ) -> i32 {
//     unimplemented_contextless("Texture level parameters are not supported in WebGL")
// }

// get_texture_level_parameter_f32 :: proc "contextless" (
//     _texture: Texture,
//     _level: i32,
//     _parameter: u32,
// ) -> f32 {
//     unimplemented_contextless("Texture level parameters are not supported in WebGL")
// }

// get_tex_level_parameter_i32 :: proc "contextless" (
//     _target: u32,
//     _level: i32,
//     _parameter: u32,
// ) -> i32 {
//     unimplemented_contextless("Tex level parameters are not supported in WebGL")
// }

// get_tex_level_parameter_f32 :: proc "contextless" (
//     _target: u32,
//     _level: i32,
//     _parameter: u32,
// ) -> f32 {
//     unimplemented_contextless("Tex level parameters are not supported in WebGL")
// }

// get_buffer_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_buffer_parameter(target, parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_buffer_parameter(target, parameter),
//     }
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_parameter_bool :: proc "contextless" (parameter: u32) -> bool {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     .as_bool()
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(false)
// }

// get_parameter_bool_array :: proc "contextless" <const N: usize>(parameter: u32) -> [bool; N] {
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     use wasm_bindgen::JsCast;
//     let mut v = [false; N];
//     if let Some(values) = value.dyn_ref::<js_sys::Array>() {
//         v.iter_mut()
//             .zip(values.values())
//             .for_each(|(v, val)| *v = val.unwrap().as_bool().unwrap_or_default())
//     }
//     v
// }

get_parameter_i32 :: proc "contextless" (parameter: u32) -> i32 {
    return gl.GetParameter(parameter)
}

get_parameter_i32_slice :: proc "contextless" (parameter: u32, out: []i32) {
    switch len(out) {
    case 1:
        out[0] = gl.GetParameter(parameter)
    case 4:
        gl.GetParameter4i(parameter, &out[0], &out[1], &out[2], &out[3])
    case:
        // unsupported slice length
    }
}

get_parameter_i64 :: proc "contextless" (parameter: u32) -> i64 {
    return i64(gl.GetParameter(parameter))
}

get_parameter_i64_slice :: proc "contextless" (parameter: u32, out: []i64) {
    tmp: [4]i32
    gl.GetParameter4i(parameter, &tmp[0], &tmp[1], &tmp[2], &tmp[3])
    for i in 0 ..< min(len(out), 4) {
        out[i] = i64(tmp[i])
    }
}

// get_parameter_i64 :: proc "contextless" (parameter: u32) -> i64 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     .as_f64()
//     .map(|v| v as i64)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_parameter_i64_slice :: proc "contextless" (parameter: u32, v: &mut [i64]) {
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         v[0] = value as i64;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Array>() {
//         v.iter_mut().zip(values.values()).for_each(|(v, val)| {
//             *v = val.unwrap().as_f64().map(|x| x as i64).unwrap_or_default()
//         })
//     }
// }

// get_parameter_indexed_i64 :: proc "contextless" (parameter: u32, index: u32) -> i64 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Get parameter indexed is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.get_indexed_parameter(parameter, index),
//     }
//     .unwrap()
//     .as_f64()
//     .map(|v| v as i64)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_parameter_f32 :: proc "contextless" (parameter: u32) -> f32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     .as_f64()
//     .map(|v| v as f32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0.0)
// }

// get_parameter_f32_slice :: proc "contextless" (parameter: u32, v: &mut [f32]) {
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_parameter(parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_parameter(parameter),
//     }
//     .unwrap()
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         v[0] = value as f32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Float32Array>() {
//         values.copy_to(v)
//     }
// }

get_parameter_indexed_i32 :: proc "contextless" (target: u32, index: u32) -> i32 {
    value: i32 = ---
    gl.GetIndexedParameter(target, index, &value)
    return value
}

// get_parameter_indexed_i32 :: proc "contextless" (parameter: u32, index: u32) -> i32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Get parameter indexed is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.get_indexed_parameter(parameter, index),
//     }
//     .unwrap()
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

get_parameter_indexed_string :: proc "contextless" (
    parameter: u32,
    index: u32,
    buf: []u8,
) -> string {
    return gl.GetParameterIndexedString(parameter, index, buf)
}

get_parameter_string :: proc "contextless" (parameter: u32, buf: []u8) -> string {
    return gl.GetParameterString(parameter, buf)
}

// get_parameter_buffer :: proc "contextless" (parameter: u32) -> Option<Buffer> {
//     self.get_parameter_gl_name(parameter, &self.buffers)
// }

// get_parameter_framebuffer :: proc "contextless" (parameter: u32) -> Option<Framebuffer> {
//     self.get_parameter_gl_name(parameter, &self.framebuffers)
// }

// get_parameter_program :: proc "contextless" (parameter: u32) -> Option<Program> {
//     self.get_parameter_gl_name(parameter, &self.programs)
// }

// get_parameter_renderbuffer :: proc "contextless" (parameter: u32) -> Option<Renderbuffer> {
//     self.get_parameter_gl_name(parameter, &self.renderbuffers)
// }

// get_parameter_sampler :: proc "contextless" (parameter: u32) -> Sampler {
//     self.get_parameter_gl_name(parameter, &self.samplers)
// }

// get_parameter_texture :: proc "contextless" (parameter: u32) -> Option<Texture> {
//     self.get_parameter_gl_name(parameter, &self.textures)
// }

// get_parameter_transform_feedback :: proc "contextless" (
//     parameter: u32,
// ) -> Option<TransformFeedback> {
//     self.get_parameter_gl_name(parameter, &self.transform_feedbacks)
// }

// get_parameter_vertex_array :: proc "contextless" (parameter: u32) -> Option<VertexArray> {
//     self.get_parameter_gl_name(parameter, &self.vertex_arrays)
// }

// get_framebuffer_parameter_i32 :: proc "contextless" (_target: u32, _parameter: u32) -> i32 {
//     unimplemented_contextless("Get framebuffer parameter is not supported")
// }

// get_renderbuffer_parameter_i32 :: proc "contextless" (target: u32, parameter: u32) -> i32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_renderbuffer_parameter(target, parameter),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_renderbuffer_parameter(target, parameter),
//     }
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_named_framebuffer_parameter_i32 :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _parameter: u32,
// ) -> i32 {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// get_framebuffer_attachment_parameter_i32 :: proc "contextless" (
//     target: u32,
//     attachment: u32,
//     parameter: u32,
// ) -> i32 {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.get_framebuffer_attachment_parameter(target, attachment, parameter)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.get_framebuffer_attachment_parameter(target, attachment, parameter)
//         }
//     }
//     .unwrap()
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_named_framebuffer_attachment_parameter_i32 :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _attachment: u32,
//     _parameter: u32,
// ) -> i32 {
//     unimplemented_contextless("Named framebuffers are not supported")
// }

// get_uniform_location :: proc "contextless" (
//     program: Program,
//     name: &str,
// ) -> Option<UniformLocation> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_uniform_location(raw_program, name),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_uniform_location(raw_program, name),
//     }
// }

// get_attrib_location :: proc "contextless" (program: Program, name: &str) -> Option<u32> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let attrib_location = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_attrib_location(raw_program, name),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_attrib_location(raw_program, name),
//     };
//     if attrib_location < 0 {
//         None
//     } else {
//         Some(attrib_location as u32)
//     }
// }

// bind_attrib_location :: proc "contextless" (program: Program, index: u32, name: &str) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.bind_attrib_location(raw_program, index, name)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.bind_attrib_location(raw_program, index, name)
//         }
//     }
// }

// get_active_attributes :: proc "contextless" (program: Program) -> u32 {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.get_program_parameter(raw_program, WebGlRenderingContext::ACTIVE_ATTRIBUTES)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.get_program_parameter(raw_program, WebGl2RenderingContext::ACTIVE_ATTRIBUTES)
//         }
//     }
//     .as_f64()
//     .map(|v| v as u32)
//     .unwrap_or(0)
// }

// get_active_attribute :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveAttribute> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.get_active_attrib(raw_program, index)
//                 .map(|au| ActiveAttribute {
//                     size: au.size(),
//                     atype: au.type_(),
//                     name: au.name(),
//                 })
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.get_active_attrib(raw_program, index)
//                 .map(|au| ActiveAttribute {
//                     size: au.size(),
//                     atype: au.type_(),
//                     name: au.name(),
//                 })
//         }
//     }
// }

// get_sync_status :: proc "contextless" (fence: Fence) -> u32 {
//     let fences = self.fences.borrow()
//     let raw_fence = fences.get_unchecked(fence)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Sync is not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl
//             .get_sync_parameter(raw_fence, SYNC_STATUS)
//             .as_f64()
//             .map(|v| v as u32)
//             .unwrap_or(UNSIGNALED),
//     }
// }

// is_sync :: proc "contextless" (fence: Fence) -> bool {
//     let fences = self.fences.borrow()
//     let raw_fence = fences.get_unchecked(fence)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Sync is not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.is_sync(Some(raw_fence)),
//     }
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

sampler_parameter_f32_slice :: proc "contextless" (
    sampler: Sampler,
    name: u32,
    value: []f32,
) {
    unimplemented_contextless("Sampler parameter for `f32` slice is not supported")
}

sampler_parameter_i32 :: proc "contextless" (sampler: Sampler, name: u32, value: i32) {
    gl.SamplerParameteri(u32(sampler), name, value)
}

// get_sampler_parameter_i32 :: proc "contextless" (sampler: Sampler, name: u32) -> i32 {
//     value: i32 = ---
//     gl.GetSamplerParameter(u32(sampler), name, &value)
//     return value
// }

// get_sampler_parameter_i32 :: proc "contextless" (sampler: Sampler, name: u32) -> i32 {
//     let samplers = self.samplers.borrow()
//     let raw_sampler = samplers.get_unchecked(sampler)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Samper parameter for `i32` is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.get_sampler_parameter(raw_sampler, name),
//     }
//     .as_f64()
//     .map(|v| v as i32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0)
// }

// get_sampler_parameter_f32 :: proc "contextless" (sampler: Sampler, name: u32) -> f32 {
//     let samplers = self.samplers.borrow()
//     let raw_sampler = samplers.get_unchecked(sampler)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Samper parameter for `i32` is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.get_sampler_parameter(raw_sampler, name),
//     }
//     .as_f64()
//     .map(|v| v as f32)
//     // Errors will be caught by the browser or through `get_error`
//     // so return a default instead
//     .unwrap_or(0.)
// }

get_sampler_parameter_f32_slice :: proc "contextless" (
    sampler: Sampler,
    name: u32,
    out: []f32,
) {
    // There is no current WebGL API to access this like there is for C
    unimplemented_contextless("Sampler parameter for `f32_slice` is not supported")
}

// generate_mipmap :: proc "contextless" (target: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.generate_mipmap(target)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.generate_mipmap(target)
//         }
//     }
// }

// generate_texture_mipmap :: proc "contextless" (_texture: Texture) {
//     unimplemented!()
// }

// tex_image_1d :: proc "contextless" (
//     _target: u32,
//     _level: i32,
//     _internal_format: i32,
//     _width: i32,
//     _border: i32,
//     _format: u32,
//     _ty: u32,
//     _pixels: PixelData,
// ) {
//     unimplemented_contextless("Tex image 1D is not supported")
// }

// compressed_tex_image_1d :: proc "contextless" (
//     _target: u32,
//     _level: i32,
//     _internal_format: i32,
//     _width: i32,
//     _border: i32,
//     _image_size: i32,
//     _pixels: &[u8],
// ) {
//     unimplemented_contextless("Compressed tex image 1D is not supported")
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
    size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        size = len(p)
        ptr = raw_data(p)
    case BufferOffset:
        size = int(p)
        ptr = nil
    }
    gl.TexImage2D(
        target, level, u32(internal_format), width, height, border, format, type, size, ptr)
}

// tex_image_2d_multisample :: proc "contextless" (
//     _target: u32,
//     _samples: i32,
//     _internal_format: i32,
//     _width: i32,
//     _height: i32,
//     _fixed_sample_locations: bool,
// ) {
//     unimplemented_contextless("Tex image 2D multisample is not supported")
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
        int(image_size),
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
    size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        size = len(p)
        ptr = raw_data(p)
    case BufferOffset:
        size = int(p)
        ptr = nil
    }
    gl.TexImage3D(
        target, level, u32(internal_format), width, height, depth, border, format, type, size, ptr)
}

// compressed_tex_image_3d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     internal_format: i32,
//     width: i32,
//     height: i32,
//     depth: i32,
//     border: i32,
//     _image_size: i32,
//     pixels: &[u8],
// ) {
//     let src_data = js_sys::Uint8Array::view(pixels)
//     match self.raw {
//         RawRenderingContext::WebGl1(_) => {
//             unimplemented_contextless("Compressed 3D textures are not supported.")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl
//             .compressed_tex_image_3d_with_array_buffer_view(
//                 target,
//                 level,
//                 internal_format as u32,
//                 width,
//                 height,
//                 depth,
//                 border,
//                 &src_data,
//             ),
//     }
// }

// tex_storage_1d :: proc "contextless" (
//     _target: u32,
//     _levels: i32,
//     _internal_format: u32,
//     _width: i32,
// ) {
//     unimplemented_contextless("Tex storage 1D is not supported")
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
//     _texture: Texture,
//     _levels: i32,
//     _internal_format: u32,
//     _width: i32,
//     _height: i32,
// ) {
//     unimplemented!()
// }

tex_storage_2d_multisample :: proc "contextless" (
    target: u32,
    samples: i32,
    internal_format: u32,
    width: i32,
    height: i32,
    fixed_sample_locations: bool,
) {
    unimplemented_contextless("Tex storage 2D multisample is not supported")
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

// uniform_1_i32 :: proc "contextless" (uniform_location: i32, x: i32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform1i(uniform_location, x),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform1i(uniform_location, x),
//     }
// }

// uniform_2_i32 :: proc "contextless" (
//     uniform_location: i32,
//     x: i32,
//     y: i32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform2i(uniform_location, x, y),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform2i(uniform_location, x, y),
//     }
// }

// uniform_3_i32 :: proc "contextless" (
//     uniform_location: i32,
//     x: i32,
//     y: i32,
//     z: i32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform3i(uniform_location, x, y, z),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform3i(uniform_location, x, y, z),
//     }
// }

// uniform_4_i32 :: proc "contextless" (
//     uniform_location: i32,
//     x: i32,
//     y: i32,
//     z: i32,
//     w: i32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform4i(uniform_location, x, y, z, w),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform4i(uniform_location, x, y, z, w),
//     }
// }

// uniform_1_i32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: &[i32],
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform1iv_with_i32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform1iv_with_i32_array(uniform_location, v)
//         }
//     }
// }

// uniform_2_i32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: &[i32],
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform2iv_with_i32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform2iv_with_i32_array(uniform_location, v)
//         }
//     }
// }

// uniform_3_i32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: &[i32],
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform3iv_with_i32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform3iv_with_i32_array(uniform_location, v)
//         }
//     }
// }

// uniform_4_i32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: &[i32],
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform4iv_with_i32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform4iv_with_i32_array(uniform_location, v)
//         }
//     }
// }

uniform_1_u32 :: proc "contextless" (location: i32, x: u32) {
    gl.Uniform1ui(location, x)
}

// uniform_2_u32 :: proc "contextless" (
//     uniform_location: i32,
//     x: u32,
//     y: u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Unsigned uniforms are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform2ui(uniform_location, x, y),
//     }
// }

// uniform_3_u32 :: proc "contextless" (
//     uniform_location: i32,
//     x: u32,
//     y: u32,
//     z: u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Unsigned uniforms are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform3ui(uniform_location, x, y, z),
//     }
// }

// uniform_4_u32 :: proc "contextless" (
//     uniform_location: i32,
//     x: u32,
//     y: u32,
//     z: u32,
//     w: u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Unsigned uniforms are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform4ui(uniform_location, x, y, z, w),
//     }
// }

// uniform_1_u32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Unsigned uniforms are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform1uiv_with_u32_array(uniform_location, v)
//         }
//     }
// }

// uniform_2_u32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Unsigned uniforms are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform2uiv_with_u32_array(uniform_location, v)
//         }
//     }
// }

// uniform_3_u32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Unsigned uniforms are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform3uiv_with_u32_array(uniform_location, v)
//         }
//     }
// }

// uniform_4_u32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []u32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Unsigned uniforms are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform4uiv_with_u32_array(uniform_location, v)
//         }
//     }
// }

// uniform_1_f32 :: proc "contextless" (uniform_location: i32, x: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform1f(uniform_location, x),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform1f(uniform_location, x),
//     }
// }

// uniform_2_f32 :: proc "contextless" (
//     uniform_location: i32,
//     x: f32,
//     y: f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform2f(uniform_location, x, y),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform2f(uniform_location, x, y),
//     }
// }

// uniform_3_f32 :: proc "contextless" (
//     uniform_location: i32,
//     x: f32,
//     y: f32,
//     z: f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform3f(uniform_location, x, y, z),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform3f(uniform_location, x, y, z),
//     }
// }

// uniform_4_f32 :: proc "contextless" (
//     uniform_location: i32,
//     x: f32,
//     y: f32,
//     z: f32,
//     w: f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.uniform4f(uniform_location, x, y, z, w),
//         RawRenderingContext::WebGl2(ref gl) => gl.uniform4f(uniform_location, x, y, z, w),
//     }
// }

// uniform_1_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform1fv_with_f32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform1fv_with_f32_array(uniform_location, v)
//         }
//     }
// }

// uniform_2_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform2fv_with_f32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform2fv_with_f32_array(uniform_location, v)
//         }
//     }
// }

// uniform_3_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform3fv_with_f32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform3fv_with_f32_array(uniform_location, v)
//         }
//     }
// }

// uniform_4_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform4fv_with_f32_array(uniform_location, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform4fv_with_f32_array(uniform_location, v)
//         }
//     }
// }

// uniform_matrix_2_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform_matrix2fv_with_f32_array(uniform_location, transpose, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix2fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_2x3_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("2x3 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix2x3fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_2x4_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("2x4 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix2x4fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_3x2_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("3x2 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix3x2fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_3_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform_matrix3fv_with_f32_array(uniform_location, transpose, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix3fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_3x4_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("3x4 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix3x4fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_4x2_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("4x2 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix4x2fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_4x3_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("4x3 matrices not supported in uniforms")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix4x3fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

// uniform_matrix_4_f32_slice :: proc "contextless" (
//     uniform_location: i32,
//     transpose: bool,
//     v: []f32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.uniform_matrix4fv_with_f32_array(uniform_location, transpose, v)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.uniform_matrix4fv_with_f32_array(uniform_location, transpose, v)
//         }
//     }
// }

unmap_buffer :: proc "contextless" (_target: u32) {
    unimplemented_contextless()
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
    unimplemented_contextless("Draw buffer color masks are not supported")
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
    unimplemented_contextless()
}

flush_mapped_buffer_range :: proc "contextless" (target: u32, offset: i32, length: i32) {
    unimplemented_contextless()
}

// invalidate_buffer_sub_data :: proc "contextless" (_target: u32, _offset: i32, _length: i32) {
//     unimplemented_contextless("Invalidate buffer sub data is not supported")
// }

invalidate_framebuffer :: proc "contextless" (target: u32, attachments: []u32) {
    gl.InvalidateFramebuffer(target, attachments)
}

// invalidate_framebuffer :: proc "contextless" (target: u32, attachments: []u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Invalidate framebuffer is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             let js_attachments = Array::new()
//             for &a in attachments {
//                 js_attachments.push(&a.into())
//             }
//             gl.invalidate_framebuffer(target, &js_attachments).unwrap()
//         }
//     }
// }

// invalidate_sub_framebuffer :: proc "contextless" (
//     target: u32,
//     attachments: []u32,
//     x: i32,
//     y: i32,
//     width: i32,
//     height: i32,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Invalidate sub framebuffer is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             let js_attachments = Array::new()
//             for &a in attachments {
//                 js_attachments.push(&a.into())
//             }
//             gl.invalidate_sub_framebuffer(target, &js_attachments, x, y, width, height)
//                 .unwrap()
//         }
//     }
// }

polygon_offset :: proc "contextless" (factor: f32, units: f32) {
    gl.PolygonOffset(factor, units)
}

polygon_mode :: proc "contextless" (face: u32, mode: u32) {
    unimplemented_contextless("Polygon mode other than FILL is not supported")
}

finish :: proc "contextless" () {
    gl.Finish()
}

bind_texture :: proc "contextless" (target: u32, texture: Texture) {
    gl.BindTexture(target, u32(texture))
}

bind_texture_unit :: proc "contextless" (unit: u32, texture: Texture) {
    unimplemented_contextless()
}

bind_sampler :: proc "contextless" (unit: u32, sampler: Sampler) {
    gl.BindSampler(unit, u32(sampler))
}

active_texture :: proc "contextless" (unit: u32) {
    gl.ActiveTexture(unit)
}

// fence_sync :: proc "contextless" (condition: u32, flags: u32) -> Result<Fence, string> {
//     let raw_fence = match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Fences are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.fence_sync(condition as u32, flags),
//     };
//     match raw_fence {
//         Some(f) => {
//             let key = self.fences.borrow_mut().insert(f)
//             Ok(key)
//         }
//         None => Err(string::from("Unable to create fence object")),
//     }
// }

// tex_parameter_f32 :: proc "contextless" (target: u32, parameter: u32, value: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.tex_parameterf(target, parameter, value),
//         RawRenderingContext::WebGl2(ref gl) => gl.tex_parameterf(target, parameter, value),
//     }
// }

tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32, value: i32) {
    gl.TexParameteri(target, parameter, value)
}

// texture_parameter_i32 :: proc "contextless" (_texture: Texture, _parameter: u32, _value: i32) {
//     unimplemented!()
// }

// tex_parameter_f32_slice :: proc "contextless" (_target: u32, _parameter: u32, _values: []f32) {
//     // Blocked by https://github.com/rustwasm/wasm-bindgen/issues/1038
//     unimplemented_contextless("Texture parameters for `[]f32` are not supported yet")
// }

// tex_parameter_i32_slice :: proc "contextless" (_target: u32, _parameter: u32, _values: &[i32]) {
//     unimplemented_contextless("Texture parameters for `&[i32]` are not supported yet")
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
    size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        size = len(p)
        ptr = raw_data(p)
    case BufferOffset:
        size = int(p)
        ptr = nil
    }
    gl.TexSubImage2D(
        target, level, x_offset, y_offset, width, height, format, type, size, ptr)
}

texture_sub_image_2d :: proc "contextless" (
    texture: Texture,
    level: i32,
    x_offset: i32,
    y_offset: i32,
    width: i32,
    height: i32,
    format: u32,
    ty: u32,
    pixels: PixelUnpackData,
) {
    unimplemented_contextless()
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
    ty: u32,
    pixels: PixelUnpackData,
) {
    unimplemented_contextless()
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
    image_size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        image_size = len(p)
        ptr = raw_data(p)
    case BufferRange:
        image_size = int(p.end - p.start)
        ptr = rawptr(uintptr(p.start))
    }
    gl.CompressedTexSubImage2D(target, level, x_offset, y_offset,
        width, height, format, image_size, ptr)
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
    size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        size = len(p)
        ptr = raw_data(p)
    case BufferOffset:
        size = int(p)
        ptr = nil
    }
    gl.TexSubImage3D(
        target,
        level,
        x_offset,
        y_offset,
        z_offset,
        width,
        height,
        depth,
        format,
        type,
        size,
        ptr,
    )
}

// tex_sub_image_3d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     x_offset: i32,
//     y_offset: i32,
//     z_offset: i32,
//     width: i32,
//     height: i32,
//     depth: i32,
//     format: u32,
//     ty: u32,
//     pixels: PixelData,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Sub image 3D is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             match pixels {
//                 PixelData::BufferOffset(offset) => gl.tex_sub_image_3d_with_i32(
//                     target,
//                     level,
//                     x_offset,
//                     y_offset,
//                     z_offset,
//                     width,
//                     height,
//                     depth,
//                     format,
//                     ty,
//                     offset as i32,
//                 ),
//                 PixelData::Slice(data) => {
//                     let data = data.map(|data| texture_data_view(ty, data))
//                     gl.tex_sub_image_3d_with_opt_array_buffer_view(
//                         target,
//                         level,
//                         x_offset,
//                         y_offset,
//                         z_offset,
//                         width,
//                         height,
//                         depth,
//                         format,
//                         ty,
//                         data.as_ref(),
//                     )
//                 }
//             }
//             .unwrap() // TODO: Handle return value?
//         }
//     }
// }

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
    image_size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        image_size = len(p)
        ptr = raw_data(p)
    case BufferRange:
        image_size = int(p.end - p.start)
        ptr = rawptr(uintptr(p.start))
    }
    gl.CompressedTexSubImage3D(target, level, x_offset, y_offset, z_offset,
        width, height, depth, format, image_size, ptr)
}

// compressed_tex_sub_image_3d :: proc "contextless" (
//     target: u32,
//     level: i32,
//     x_offset: i32,
//     y_offset: i32,
//     z_offset: i32,
//     width: i32,
//     height: i32,
//     depth: i32,
//     format: u32,
//     pixels: CompressedPixelUnpackData,
// ) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Compressed sub image 3D is not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => match pixels {
//             CompressedPixelUnpackData::BufferRange(range) => gl
//                 .compressed_tex_sub_image_3d_with_i32_and_i32(
//                     target,
//                     level,
//                     x_offset,
//                     y_offset,
//                     z_offset,
//                     width,
//                     height,
//                     depth,
//                     format,
//                     (range.end - range.start) as i32,
//                     range.start as i32,
//                 ),
//             CompressedPixelUnpackData::Slice(data) => {
//                 let data = texture_data_view(BYTE, data)
//                 gl.compressed_tex_sub_image_3d_with_array_buffer_view(
//                     target, level, x_offset, y_offset, z_offset, width, height, depth, format,
//                     &data,
//                 )
//             }
//         },
//     }
// }

depth_func :: proc "contextless" (func: u32) {
    gl.DepthFunc(func)
}

depth_range_f32 :: proc "contextless" (near: f32, far: f32) {
    gl.DepthRange(near, far)
}

depth_range_f64 :: proc "contextless" (near: f64, far: f64) {
    unimplemented_contextless("Depth range with 64-bit float values is not supported")
}

depth_range :: proc "contextless" (near: f64, far: f64) {
    depth_range_f32(f32(near), f32(far))
}

// depth_range_f64_slice :: proc "contextless" (_first: u32, _count: i32, _values: &[[f64; 2]]) {
//     unimplemented_contextless("Depth range with 64-bit float slices is not supported")
// }

scissor :: proc "contextless" (x: i32, y: i32, width: i32, height: i32) {
    gl.Scissor(x, y, width, height)
}

// scissor_slice :: proc "contextless" (_first: u32, _count: i32, _scissors: &[[i32; 4]]) {
//     unimplemented_contextless("Scissor slice is not supported")
// }

// vertex_array_attrib_binding_f32 :: proc "contextless" (
//     _vao: VertexArray,
//     _index: u32,
//     _binding_index: u32,
// ) {
//     unimplemented!()
// }

// vertex_array_attrib_format_f32 :: proc "contextless" (
//     _vao: VertexArray,
//     _index: u32,
//     _size: i32,
//     _data_type: u32,
//     _normalized: bool,
//     _relative_offset: u32,
// ) {
//     unimplemented!()
// }

// vertex_array_attrib_format_i32 :: proc "contextless" (
//     _vao: VertexArray,
//     _index: u32,
//     _size: i32,
//     _data_type: u32,
//     _relative_offset: u32,
// ) {
//     unimplemented!()
// }

// vertex_array_attrib_format_f64 :: proc "contextless" (
//     _vao: VertexArray,
//     _index: u32,
//     _size: i32,
//     _data_type: u32,
//     _relative_offset: u32,
// ) {
//     unimplemented!()
// }

// vertex_array_element_buffer :: proc "contextless" (
//     _vao: VertexArray,
//     _buffer: Option<Buffer>,
// ) {
//     unimplemented!()
// }

// vertex_array_vertex_buffer :: proc "contextless" (
//     _vao: VertexArray,
//     _binding_index: u32,
//     _buffer: Option<Buffer>,
//     _offset: i32,
//     _stride: i32,
// ) {
//     unimplemented!()
// }

vertex_attrib_divisor :: proc "contextless" (index: u32, divisor: u32) {
    gl.VertexAttribDivisor(index, divisor)
}

// get_vertex_attrib_parameter_f32_slice :: proc "contextless" (
//     index: u32,
//     pname: u32,
//     result: &mut [f32],
// ) {
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_vertex_attrib(index, pname),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_vertex_attrib(index, pname),
//     }
//     .unwrap()
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         result[0] = value as f32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Float32Array>() {
//         values.copy_to(result)
//     }
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
        i32(index),
        int(size),
        data_type,
        normalized,
        int(stride),
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
        i32(index),
        int(size),
        data_type,
        int(stride),
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
    unimplemented_contextless()
}

vertex_attrib_format_f32 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    normalized: bool,
    relative_offset: u32,
) {
    unimplemented_contextless("Vertex attrib format is not supported in WebGL")
}

vertex_attrib_format_i32 :: proc "contextless" (
    index: u32,
    size: i32,
    data_type: u32,
    relative_offset: u32,
) {
    unimplemented_contextless("Vertex attrib format is not supported in WebGL")
}

// vertex_attrib_format_f64 :: proc "contextless" (
//     _index: u32,
//     _size: i32,
//     _data_type: u32,
//     _relative_offset: u32,
// ) {
//     unimplemented_contextless("Vertex attrib format is not supported in WebGL")
// }

// vertex_attrib_1_f32 :: proc "contextless" (index: u32, x: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib1f(index, x),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib1f(index, x),
//     }
// }

// vertex_attrib_2_f32 :: proc "contextless" (index: u32, x: f32, y: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib2f(index, x, y),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib2f(index, x, y),
//     }
// }

// vertex_attrib_3_f32 :: proc "contextless" (index: u32, x: f32, y: f32, z: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib3f(index, x, y, z),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib3f(index, x, y, z),
//     }
// }

// vertex_attrib_4_f32 :: proc "contextless" (index: u32, x: f32, y: f32, z: f32, w: f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib4f(index, x, y, z, w),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib4f(index, x, y, z, w),
//     }
// }

// vertex_attrib_4_i32 :: proc "contextless" (index: u32, x: i32, y: i32, z: i32, w: i32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("vertex_attrib_4_i32 not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib_i4i(index, x, y, z, w),
//     }
// }

// vertex_attrib_4_u32 :: proc "contextless" (index: u32, x: u32, y: u32, z: u32, w: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("vertex_attrib_4_u32 not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib_i4ui(index, x, y, z, w),
//     }
// }

// vertex_attrib_1_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib1fv_with_f32_array(index, v),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib1fv_with_f32_array(index, v),
//     }
// }

// vertex_attrib_2_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib2fv_with_f32_array(index, v),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib2fv_with_f32_array(index, v),
//     }
// }

// vertex_attrib_3_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib3fv_with_f32_array(index, v),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib3fv_with_f32_array(index, v),
//     }
// }

// vertex_attrib_4_f32_slice :: proc "contextless" (index: u32, v: []f32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.vertex_attrib4fv_with_f32_array(index, v),
//         RawRenderingContext::WebGl2(ref gl) => gl.vertex_attrib4fv_with_f32_array(index, v),
//     }
// }

vertex_attrib_binding :: proc "contextless" (attrib_index: u32, binding_index: u32) {
    unimplemented_contextless("Vertex attrib binding is not supported")
}

vertex_binding_divisor :: proc "contextless" (binding_index: u32, divisor: u32) {
    unimplemented_contextless("Vertex binding divisor is not supported")
}

viewport :: proc "contextless" (x: i32, y: i32, width: i32, height: i32) {
    gl.Viewport(x, y, width, height)
}

viewport_f32_slice :: proc "contextless" (first: u32, count: i32, values: [4]f32) {
    unimplemented_contextless("Viewport `f32` slice is not supported")
}

blend_func :: proc "contextless" (src: u32, dst: u32) {
    gl.BlendFunc(src, dst)
}

blend_func_draw_buffer :: proc "contextless" (draw_buffer: u32, src: u32, dst: u32) {
    unimplemented_contextless("Draw buffer blend func is not supported")
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
    unimplemented_contextless("Draw buffer blend func separate is not supported")
}

blend_equation :: proc "contextless" (mode: u32) {
    gl.BlendEquation(mode)
}

blend_equation_draw_buffer :: proc "contextless" (draw_buffer: u32, mode: u32) {
    unimplemented_contextless("Draw buffer blend equation is not supported")
}

blend_equation_separate :: proc "contextless" (mode_rgb: u32, mode_alpha: u32) {
    gl.BlendEquationSeparate(mode_rgb, mode_alpha)
}

blend_equation_separate_draw_buffer :: proc "contextless" (
    draw_buffer: u32,
    mode_rgb: u32,
    mode_alpha: u32,
) {
    unimplemented_contextless("Draw buffer blend equation separate is not supported")
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
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             gl.stencil_op(stencil_fail as u32, depth_fail as u32, pass as u32)
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.stencil_op(stencil_fail as u32, depth_fail as u32, pass as u32)
//         }
//     }
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
//     _source: u32,
//     _msg_type: u32,
//     _severity: u32,
//     _ids: []u32,
//     _enabled: bool,
// ) {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// debug_message_insert :: proc "contextless" <S>(
//     _source: u32,
//     _msg_type: u32,
//     _id: u32,
//     _severity: u32,
//     _msg: S,
// ) where
//     S: AsRef<str>,
// {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

debug_message_callback :: proc "contextless" (callback: debug_proc_t, userParam: rawptr) {
    unimplemented_contextless()
}

// get_debug_message_log :: proc "contextless" (_count: u32) -> Vec<DebugMessageLogEntry> {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// push_debug_group :: proc "contextless" <S>(_source: u32, _id: u32, _message: S)
// where
//     S: AsRef<str>,
// {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// pop_debug_group :: proc "contextless" (&self) {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

object_label :: proc "contextless" (
    #any_int identifier: u32,
    name: u32,
    label: string,
    loc := #caller_location,
) {
    unimplemented_contextless(loc = loc)
}

// get_object_label :: proc "contextless" (_identifier: u32, _name: u32) -> string {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// object_ptr_label :: proc "contextless" <S>(_sync: Fence, _label: Option<S>)
// where
//     S: AsRef<str>,
// {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// get_object_ptr_label :: proc "contextless" (_sync: Fence) -> string {
//     unimplemented_contextless("WebGL does not support the KHR_debug extension.")
// }

// get_uniform_block_index :: proc "contextless" (program: Program, name: &str) -> Option<u32> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let index = match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Uniform blocks are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_uniform_block_index(raw_program, name),
//     };
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
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let indices = match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Uniform blocks are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             let js_names = Array::new()
//             for &v in names {
//                 js_names.push(&v.into())
//             }
//             gl.get_uniform_indices(raw_program, &js_names)
//         }
//     }
//     .unwrap()
//     indices
//         .iter()
//         .map(|index| {
//             let index = index.as_f64().unwrap() as u32;
//             if index == INVALID_INDEX {
//                 None
//             } else {
//                 Some(index)
//             }
//         })
//         .collect()
// }

// uniform_block_binding :: proc "contextless" (program: Program, index: u32, binding: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("Uniform buffer bindings are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             let programs = self.programs.borrow()
//             let raw_program = programs.get_unchecked(program)
//             gl.uniform_block_binding(raw_program, index, binding)
//         }
//     }
// }

// get_shader_storage_block_index :: proc "contextless" (
//     _program: Program,
//     _name: &str,
// ) -> Option<u32> {
//     unimplemented_contextless("Shader Storage Buffers are not supported by webgl")
// }

// shader_storage_block_binding :: proc "contextless" (
//     _program: Program,
//     _index: u32,
//     _binding: u32,
// ) {
//     unimplemented_contextless("Shader Storage Buffers are not supported by webgl")
// }

read_buffer :: proc "contextless" (src: u32) {
    gl.ReadBuffer(src)
}

// named_framebuffer_read_buffer :: proc "contextless" (
//     _framebuffer: Option<Framebuffer>,
//     _src: u32,
// ) {
//     unimplemented_contextless("Named framebuffers are not supported")
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
    size: int
    ptr: rawptr
    switch p in pixels {
    case []u8:
        size = len(p)
        ptr = raw_data(p)
    case BufferOffset:
        size = int(p)
        ptr = nil
    }
    gl.ReadnPixels(x, y, width, height, format, gltype, size, ptr)
}

// texture_storage_3d :: proc "contextless" (
//     _texture: Texture,
//     _levels: i32,
//     _internal_format: u32,
//     _width: i32,
//     _height: i32,
//     _depth: i32,
// ) {
//     unimplemented!()
// }

// get_uniform_i32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: &mut [i32],
// ) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_uniform(&raw_program, location),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_uniform(&raw_program, location),
//     };
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         v[0] = value as i32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Int32Array>() {
//         values.copy_to(v)
//     }
// }

// get_uniform_u32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: &mut [u32],
// ) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_uniform(&raw_program, location),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_uniform(&raw_program, location),
//     };
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         v[0] = value as u32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Uint32Array>() {
//         values.copy_to(v)
//     }
// }

// get_uniform_f32 :: proc "contextless" (
//     program: Program,
//     location: &UniformLocation,
//     v: &mut [f32],
// ) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.get_uniform(&raw_program, location),
//         RawRenderingContext::WebGl2(ref gl) => gl.get_uniform(&raw_program, location),
//     };
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         v[0] = value as f32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Float32Array>() {
//         values.copy_to(v)
//     }
// }

begin_query :: proc "contextless" (target: u32, query: Query) {
    gl.BeginQuery(target, u32(query))
}

// begin_query :: proc "contextless" (target: u32, query: Query) {
//     let queries = self.queries.borrow()
//     let raw_query = queries.get_unchecked(query)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Query objects are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl.begin_query(target, raw_query),
//     }
// }

end_query :: proc "contextless" (target: u32) {
    gl.EndQuery(target)
}

// query_counter :: proc "contextless" (query: Query, target: u32) {
//     let queries = self.queries.borrow()
//     let raw_query = queries.get_unchecked(query)
//     match self.extensions.ext_disjoint_timer_query_webgl2 {
//         Some(ref ext) => ext.query_counter_ext(raw_query, target),
//         None => {
//             unimplemented_contextless("Query counters are not supported without EXT_disjoint_timer_query_webgl2")
//         }
//     }
// }

// get_query_parameter_u32 :: proc "contextless" (query: Query, parameter: u32) -> u32 {
//     let queries = self.queries.borrow()
//     let raw_query = queries.get_unchecked(query)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Query objects are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             let v = gl.get_query_parameter(raw_query, parameter)
//             v.as_f64()
//                 .map(|v| v as u32)
//                 .or_else(|| v.as_bool().map(|v| v as u32))
//                 .unwrap_or(0)
//         }
//     }
// }

get_query_parameter_u32 :: proc "contextless" (query: Query, parameter: u32) -> u32 {
    return gl.GetQueryParameter(u32(query), parameter)
}

get_query_parameter_u64 :: proc "contextless" (query: Query, parameter: u32) -> u64 {
    return u64(gl.GetQueryParameter(u32(query), parameter))
}

get_query_parameter_u64_with_offset :: proc "contextless" (
    query: Query,
    parameter: u32,
    offset: u64,
) {
    unimplemented_contextless("Query buffers are not supported")
}

// create_transform_feedback :: proc "contextless" (&self) -> Result<TransformFeedback, string> {
//     let raw_transform_feedback = match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.create_transform_feedback(),
//     };

//     match raw_transform_feedback {
//         Some(t) => {
//             let key = self.transform_feedbacks.borrow_mut().insert(t)
//             Ok(key)
//         }
//         None => Err(string::from("Unable to create TransformFeedback object")),
//     }
// }

// is_transform_feedback :: proc "contextless" (transform_feedback: TransformFeedback) -> bool {
//     let transform_feedbacks = self.transform_feedbacks.borrow_mut()
//     if let Some(f) = transform_feedbacks.get(transform_feedback) {
//         match &self.raw {
//             RawRenderingContext::WebGl1(_gl) => unimplemented_contextless("TransformFeedback is not supported"),
//             RawRenderingContext::WebGl2(gl) => gl.is_transform_feedback(Some(f)),
//         }
//     } else {
//         false
//     }
// }

// delete_transform_feedback :: proc "contextless" (transform_feedback: TransformFeedback) {
//     let mut transform_feedbacks = self.transform_feedbacks.borrow_mut()
//     if let Some(ref t) = transform_feedbacks.remove(transform_feedback) {
//         match self.raw {
//             RawRenderingContext::WebGl1(ref _gl) => {
//                 unimplemented_contextless("TransformFeedback objects are not supported")
//             }
//             RawRenderingContext::WebGl2(ref gl) => gl.delete_transform_feedback(Some(t)),
//         }
//     }
// }

// bind_transform_feedback :: proc "contextless" (
//     target: u32,
//     transform_feedback: Option<TransformFeedback>,
// ) {
//     let transform_feedbacks = self.transform_feedbacks.borrow()
//     let raw_transform_feedback =
//         transform_feedback.map(|tf| transform_feedbacks.get_unchecked(tf))
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.bind_transform_feedback(target, raw_transform_feedback)
//         }
//     }
// }

// begin_transform_feedback :: proc "contextless" (primitive_mode: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.begin_transform_feedback(primitive_mode),
//     }
// }

// end_transform_feedback :: proc "contextless" (&self) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.end_transform_feedback(),
//     }
// }

// pause_transform_feedback :: proc "contextless" (&self) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.pause_transform_feedback(),
//     }
// }

// resume_transform_feedback :: proc "contextless" (&self) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl.resume_transform_feedback(),
//     }
// }

// transform_feedback_varyings :: proc "contextless" (
//     program: Program,
//     varyings: &[&str],
//     buffer_mode: u32,
// ) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             let js_varyings = Array::new()
//             for &v in varyings {
//                 js_varyings.push(&v.into())
//             }
//             gl.transform_feedback_varyings(raw_program, &js_varyings, buffer_mode)
//         }
//     }
// }

// get_transform_feedback_varying :: proc "contextless" (
//     program: Program,
//     index: u32,
// ) -> Option<ActiveTransformFeedback> {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)
//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => {
//             unimplemented_contextless("TransformFeedback objects are not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => gl
//             .get_transform_feedback_varying(raw_program, index)
//             .map(|info| ActiveTransformFeedback {
//                 size: info.size(),
//                 tftype: info.type_(),
//                 name: info.name(),
//             }),
//     }
// }

memory_barrier :: proc "contextless" (_barriers: u32) {
    unimplemented_contextless()
}

memory_barrier_by_region :: proc "contextless" (_barriers: u32) {
    unimplemented_contextless()
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
    unimplemented_contextless()
}

// get_active_uniform_block_parameter_i32 :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
//     parameter: u32,
// ) -> i32 {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)

//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Uniform blocks are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl
//             .get_active_uniform_block_parameter(raw_program, uniform_block_index, parameter)
//             .unwrap()
//             .as_f64()
//             .map(|v| v as i32)
//             // Errors will be caught by the browser or through `get_error`
//             // so return a default instead
//             .unwrap_or(0),
//     }
// }

// get_active_uniform_block_parameter_i32_slice :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
//     parameter: u32,
//     out: &mut [i32],
// ) {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)

//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Uniform blocks are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => {
//             let value = gl
//                 .get_active_uniform_block_parameter(raw_program, uniform_block_index, parameter)
//                 .unwrap()

//             use wasm_bindgen::JsCast;
//             if let Some(value) = value.as_f64() {
//                 out[0] = value as i32;
//             } else if let Some(values) = value.dyn_ref::<js_sys::Uint32Array>() {
//                 // To maintain compatibility with the pointers returned by
//                 // desktop GL, which are signed, an extra copy is needed
//                 // here.
//                 values
//                     .to_vec()
//                     .into_iter()
//                     .zip(out.iter_mut())
//                     .for_each(|(val, target)| *target = val as i32)
//             }
//         }
//     }
// }
// get_active_uniform_block_name :: proc "contextless" (
//     program: Program,
//     uniform_block_index: u32,
// ) -> string {
//     let programs = self.programs.borrow()
//     let raw_program = programs.get_unchecked(program)

//     match self.raw {
//         RawRenderingContext::WebGl1(ref _gl) => unimplemented_contextless("Uniform blocks are not supported"),
//         RawRenderingContext::WebGl2(ref gl) => gl
//             .get_active_uniform_block_name(raw_program, uniform_block_index)
//             .unwrap(),
//     }
// }

// max_shader_compiler_threads :: proc "contextless" (_count: u32) {
//     // WebGL doesn't use this
// }

// hint :: proc "contextless" (target: u32, mode: u32) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.hint(target, mode),
//         RawRenderingContext::WebGl2(ref gl) => gl.hint(target, mode),
//     }
// }

// sample_coverage :: proc "contextless" (value: f32, invert: bool) {
//     match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => gl.sample_coverage(value, invert),
//         RawRenderingContext::WebGl2(ref gl) => gl.sample_coverage(value, invert),
//     }
// }

// get_internal_format_i32_slice :: proc "contextless" (
//     target: u32,
//     internal_format: u32,
//     pname: u32,
//     result: &mut [i32],
// ) {
//     let value = match self.raw {
//         RawRenderingContext::WebGl1(ref gl) => {
//             unimplemented_contextless("get_internalformat_parameter not supported")
//         }
//         RawRenderingContext::WebGl2(ref gl) => {
//             gl.get_internalformat_parameter(target, internal_format, pname)
//         }
//     }
//     .unwrap()
//     use wasm_bindgen::JsCast;
//     if let Some(value) = value.as_f64() {
//         result[0] = value as i32;
//     } else if let Some(values) = value.dyn_ref::<js_sys::Int32Array>() {
//         values.copy_to(result)
//     }
// }
