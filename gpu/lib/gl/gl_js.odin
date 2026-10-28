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

// TODO: get_active_uniform - unimplemented

use_program :: proc "contextless" (program: Program) {
    gl.UseProgram(u32(program))
}

create_buffer :: proc "contextless" () -> Buffer {
    return Buffer(gl.CreateBuffer())
}



// TODO: create_named_buffer - unimplemented

// TODO: is_buffer - unimplemented

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

// TODO: blit_named_framebuffer - unimplemented

create_vertex_array :: proc "contextless" () -> VertexArray {
    return VertexArray(gl.CreateVertexArray())
}

// TODO: create_named_vertex_array - unimplemented

delete_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    gl.DeleteVertexArray(u32(vertex_array))
}

bind_vertex_array :: proc "contextless" (vertex_array: VertexArray) {
    gl.BindVertexArray(u32(vertex_array))
}

// TODO: clear_color - unimplemented

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

// TODO: named_buffer_data_u8_slice - unimplemented

buffer_sub_data_u8_slice :: proc "contextless" (target: u32, offset: i32, src_data: []u8) {
    gl.BufferSubData(
        target,
        uintptr(offset),
        len(src_data),
        raw_data(src_data),
    )
}

// TODO: named_buffer_sub_data_u8_slice - unimplemented

get_buffer_sub_data :: proc "contextless" (target: u32, offset: i32, dst_data: []u8) {
    gl.GetBufferSubData(
        target,
        int(offset),
        dst_data,
    )
}


// TODO: tex_buffer - unimplemented


buffer_storage :: proc "contextless" (target: u32, size: i32, data: []u8, flags: u32) {
    unimplemented_contextless()
}

// TODO: named_buffer_storage - unimplemented

check_framebuffer_status :: proc "contextless" (target: u32) -> u32 {
    return gl.CheckFramebufferStatus(target)
}

// TODO: check_named_framebuffer_status - unimplemented

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

// TODO: clear_buffer_depth_stencil - unimplemented

// TODO: clear_named_framebuffer_i32_slice - unimplemented

// TODO: clear_named_framebuffer_u32_slice - unimplemented

// TODO: clear_named_framebuffer_f32_slice - unimplemented

// TODO: clear_named_framebuffer_depth_stencil - unimplemented

// TODO: client_wait_sync - unimplemented

// TODO: get_sync_parameter_i32 - unimplemented

// TODO: wait_sync - unimplemented

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

// TODO: copy_tex_image_2d - unimplemented

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

// TODO: delete_query - unimplemented

delete_renderbuffer :: proc "contextless" (renderbuffer: Renderbuffer) {
    gl.DeleteRenderbuffer(u32(renderbuffer))
}

delete_sampler :: proc "contextless" (sampler: Sampler) {
    gl.DeleteSampler(u32(sampler))
}

// TODO: delete_sync - unimplemented

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

// TODO: draw_buffer - unimplemented

// TODO: named_framebuffer_draw_buffer - unimplemented

draw_buffers :: proc "contextless" (buffers: []u32) {
    gl.DrawBuffers(buffers)
}

// TODO: named_framebuffer_draw_buffers - unimplemented

// TODO: draw_elements - unimplemented

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

// TODO: is_enabled - unimplemented

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

// TODO: framebuffer_texture - unimplemented

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

// TODO: named_framebuffer_renderbuffer - unimplemented

// TODO: named_framebuffer_texture - unimplemented

// TODO: named_framebuffer_texture_layer - unimplemented

front_face :: proc "contextless" (value: u32) {
    gl.FrontFace(value)
}

// TODO: get_error - unimplemented

// TODO: get_tex_parameter_i32 - unimplemented

// TODO: get_tex_parameter_f32 - unimplemented

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

// TODO: get_buffer_parameter_i32 - unimplemented

// TODO: get_parameter_bool - unimplemented

// TODO: get_parameter_bool_array - unimplemented

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



// TODO: get_parameter_indexed_i64 - unimplemented

// TODO: get_parameter_f32 - unimplemented

// TODO: get_parameter_f32_slice - unimplemented

get_parameter_indexed_i32 :: proc "contextless" (target: u32, index: u32) -> i32 {
    value: i32 = ---
    gl.GetIndexedParameter(target, index, &value)
    return value
}


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

// TODO: get_parameter_buffer - unimplemented

// TODO: get_parameter_framebuffer - unimplemented

// TODO: get_parameter_program - unimplemented

// TODO: get_parameter_renderbuffer - unimplemented

// TODO: get_parameter_sampler - unimplemented

// TODO: get_parameter_texture - unimplemented

// TODO: get_parameter_transform_feedback - unimplemented

// TODO: get_parameter_vertex_array - unimplemented

// get_framebuffer_parameter_i32 :: proc "contextless" (_target: u32, _parameter: u32) -> i32 {
//     unimplemented_contextless("Get framebuffer parameter is not supported")
// }

// TODO: get_renderbuffer_parameter_i32 - unimplemented

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

// TODO: get_sampler_parameter_i32 - unimplemented

// TODO: get_sampler_parameter_f32 - unimplemented

get_sampler_parameter_f32_slice :: proc "contextless" (
    sampler: Sampler,
    name: u32,
    out: []f32,
) {
    // There is no current WebGL API to access this like there is for C
    unimplemented_contextless("Sampler parameter for `f32_slice` is not supported")
}

// TODO: generate_mipmap - unimplemented

// TODO: generate_texture_mipmap - unimplemented

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

// TODO: compressed_tex_image_3d - unimplemented

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

// TODO: texture_storage_2d - unimplemented

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


// TODO: invalidate_sub_framebuffer - unimplemented

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

// TODO: fence_sync - unimplemented

// TODO: tex_parameter_f32 - unimplemented

tex_parameter_i32 :: proc "contextless" (target: u32, parameter: u32, value: i32) {
    gl.TexParameteri(target, parameter, value)
}

// TODO: texture_parameter_i32 - unimplemented

// tex_parameter_f32_slice :: proc "contextless" (_target: u32, _parameter: u32, _values: []f32) {
//     // Blocked by https://github.com/rustwasm/wasm-bindgen/issues/1038
//     unimplemented_contextless("Texture parameters for `[]f32` are not supported yet")
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

// TODO: get_vertex_attrib_parameter_f32_slice - unimplemented

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

// TODO: vertex_attrib_1_f32 - unimplemented

// TODO: vertex_attrib_2_f32 - unimplemented

// TODO: vertex_attrib_3_f32 - unimplemented

// TODO: vertex_attrib_4_f32 - unimplemented

// TODO: vertex_attrib_4_i32 - unimplemented

// TODO: vertex_attrib_4_u32 - unimplemented

// TODO: vertex_attrib_1_f32_slice - unimplemented

// TODO: vertex_attrib_2_f32_slice - unimplemented

// TODO: vertex_attrib_3_f32_slice - unimplemented

// TODO: vertex_attrib_4_f32_slice - unimplemented

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

// TODO: stencil_op - unimplemented

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
    unimplemented_contextless()
}

// TODO: get_debug_message_log - unimplemented


// TODO: push_debug_group - unimplemented


// TODO: pop_debug_group - unimplemented


object_label :: proc "contextless" (
    #any_int identifier: u32,
    name: u32,
    label: string,
    loc := #caller_location,
) {
    unimplemented_contextless(loc = loc)
}

// TODO: get_object_label - unimplemented


// TODO: object_ptr_label - unimplemented

// TODO: get_object_ptr_label - unimplemented


// TODO: get_uniform_block_index - unimplemented

// TODO: get_uniform_indices - unimplemented

// TODO: uniform_block_binding - unimplemented

// TODO: get_shader_storage_block_index - unimplemented

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

// TODO: texture_storage_3d - unimplemented

// TODO: get_uniform_i32 - unimplemented

// TODO: get_uniform_u32 - unimplemented

// TODO: get_uniform_f32 - unimplemented

begin_query :: proc "contextless" (target: u32, query: Query) {
    gl.BeginQuery(target, u32(query))
}


end_query :: proc "contextless" (target: u32) {
    gl.EndQuery(target)
}

// TODO: query_counter - unimplemented


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

// TODO: create_transform_feedback - unimplemented


// TODO: is_transform_feedback - unimplemented

// TODO: delete_transform_feedback - unimplemented

// TODO: bind_transform_feedback - unimplemented

// TODO: begin_transform_feedback - unimplemented

// TODO: end_transform_feedback - unimplemented

// TODO: pause_transform_feedback - unimplemented

// TODO: resume_transform_feedback - unimplemented

// TODO: transform_feedback_varyings - unimplemented

// TODO: get_transform_feedback_varying - unimplemented

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

// TODO: get_active_uniform_block_parameter_i32 - unimplemented


// TODO: get_active_uniform_block_parameter_i32_slice - unimplemented

// TODO: get_active_uniform_block_name - unimplemented


// max_shader_compiler_threads :: proc "contextless" (_count: u32) {
//     // WebGL doesn't use this
// }

// TODO: hint - unimplemented

// TODO: sample_coverage - unimplemented

// TODO: get_internal_format_i32_slice - unimplemented
