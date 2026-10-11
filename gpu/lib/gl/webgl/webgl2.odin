package webgl

foreign import "webgl2"

import "base:intrinsics"
import "base:runtime"
import glm "core:math/linalg/glsl"

IsWebGL2Supported :: proc "contextless" () -> bool {
    major, minor: i32
    GetWebGLVersion(&major, &minor)
    return major >= 2
}

@(default_calling_convention="contextless")
foreign webgl2 {
    /* u32 objects */
    CopyBufferSubData :: proc(readTarget, writeTarget: u32, readOffset, writeOffset: int, size: int) ---
    GetBufferSubData  :: proc(target: u32, srcByteOffset: int, dst_buffer: []byte, dstOffset: int = 0, length: int = 0) ---

    /* Framebuffer objects */
    BlitFramebuffer          :: proc(srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1: i32, mask: u32, filter: u32) ---
    FramebufferTextureLayer  :: proc(target: u32, attachment: u32, texture: u32, level: i32, layer: i32) ---
    InvalidateFramebuffer    :: proc(target: u32, attachments: []u32) ---
    InvalidateSubFramebuffer :: proc(target: u32, attachments: []u32, x, y, width, height: i32) ---
    ReadBuffer               :: proc(src: u32) ---

    /* Renderbuffer objects */
    RenderbufferStorageMultisample :: proc(target: u32, samples: i32, internalformat: u32, width, height: i32) ---

    /* u32 objects */
    TexStorage2D            :: proc(target: u32, levels: i32, internalformat: u32, width, height: i32) ---
    TexStorage3D            :: proc(target: u32, levels: i32, internalformat: u32, width, height, depth: i32) ---
    TexImage3D              :: proc(target: u32, level: i32, internalformat: u32, width, height, depth: i32, border: i32, format, type: u32, size: int, data: rawptr) ---
    TexSubImage3D           :: proc(target: u32, level: i32, xoffset, yoffset, zoffset, width, height, depth: i32, format, type: u32, size: int, data: rawptr) ---
    CompressedTexImage3D    :: proc(target: u32, level: i32, internalformat: u32, width, height, depth: i32, border: i32, imageSize: int, data: rawptr) ---
    CompressedTexSubImage3D :: proc(target: u32, level: i32, xoffset, yoffset, zoffset: i32, width, height, depth: i32, format: u32, imageSize: int, data: rawptr) ---
    CopyTexSubImage3D       :: proc(target: u32, level: i32, xoffset, yoffset, zoffset: i32, x, y, width, height: i32) ---

    /* Programs and shaders */
    GetFragDataLocation :: proc(program: u32, name: string) -> i32 ---

    /* Uniforms */
    Uniform1ui :: proc(location: i32, v0: u32) ---
    Uniform2ui :: proc(location: i32, v0: u32, v1: u32) ---
    Uniform3ui :: proc(location: i32, v0: u32, v1: u32, v2: u32) ---
    Uniform4ui :: proc(location: i32, v0: u32, v1: u32, v2: u32, v3: u32) ---

    /* Vertex attribs */
    VertexAttribI4i      :: proc(index: i32, x, y, z, w: i32) ---
    VertexAttribI4ui     :: proc(index: i32, x, y, z, w: u32) ---
    VertexAttribIPointer :: proc(index: i32, size: int, type: u32, stride: int, offset: uintptr) ---

    /* Writing to the drawing buffer */
    VertexAttribDivisor   :: proc(index: u32, divisor: u32) ---
    DrawArraysInstanced   :: proc(mode: u32, first, count: int, instanceCount: int) ---
    DrawElementsInstanced :: proc(mode: u32, count: int, type: u32, offset: int, instanceCount: int) ---
    DrawRangeElements     :: proc(mode: u32, start, end, count: int, type: u32, offset: int) ---

    /* Multiple Render Targets */
    DrawBuffers    :: proc(buffers: []u32) ---
    ClearBufferfv  :: proc(buffer: u32, drawbuffer: i32, values: []f32) ---
    ClearBufferiv  :: proc(buffer: u32, drawbuffer: i32, values: []i32) ---
    ClearBufferuiv :: proc(buffer: u32, drawbuffer: i32, values: []u32) ---
    ClearBufferfi  :: proc(buffer: u32, drawbuffer: i32, depth: f32, stencil: i32) ---

    CreateQuery :: proc() -> u32 ---
    DeleteQuery :: proc(query: u32) ---
    IsQuery     :: proc(query: u32) -> bool ---
    BeginQuery  :: proc(target: u32, query: u32) ---
    EndQuery    :: proc(target: u32) ---
    GetQuery    :: proc(target, pname: u32) ---

    CreateSampler     :: proc() -> u32 ---
    DeleteSampler     :: proc(sampler: u32) ---
    IsSampler         :: proc(sampler: u32) -> bool ---
    BindSampler       :: proc(unit: u32, sampler: u32) ---
    SamplerParameteri :: proc(sampler: u32, pname: u32, param: i32) ---
    SamplerParameterf :: proc(sampler: u32, pname: u32, param: f32) ---

    FenceSync      :: proc(condition: u32, flags: u32) -> u32 ---
    IsSync         :: proc(sync: u32) -> bool ---
    DeleteSync     :: proc(sync: u32) ---
    ClientWaitSync :: proc(sync: u32, flags: u32, timeout: u64) ---
    WaitSync       :: proc(sync: u32, flags: u32, timeout: i64) ---

    CreateTransformFeedback   :: proc() -> u32 ---
    DeleteTransformFeedback   :: proc(tf: u32) ---
    IsTransformFeedback       :: proc(tf: u32) -> bool ---
    BindTransformFeedback     :: proc(target: u32, tf: u32) ---
    BeginTransformFeedback    :: proc(primitiveMode: u32) ---
    EndTransformFeedback      :: proc() ---
    TransformFeedbackVaryings :: proc(program: u32, varyings: []string, bufferMode: u32) ---
    PauseTransformFeedback    :: proc() ---
    ResumeTransformFeedback   :: proc() ---

    BindBufferBase            :: proc(target: u32, index: i32, buffer: u32) ---
    BindBufferRange           :: proc(target: u32, index: i32, buffer: u32, offset: int, size: int) ---
    GetUniformBlockIndex      :: proc(program: u32, uniformBlockName: string) -> i32 ---
    UniformBlockBinding       :: proc(program: u32, uniformBlockIndex: i32, uniformBlockBinding: i32) ---

    // if `pname` is `UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES` then an array will be written at
    // `params`, in that case the length `params` need to have is given first querying using `pname`
    // `UNIFORM_BLOCK_ACTIVE_UNIFORMS`.
    GetActiveUniformBlockParameter :: proc(program: u32, uniformBlockIndex: i32, pname: u32, params: [^]i32) ---
    GetActiveUniforms :: proc(program: u32, uniformIndices: []u32, pname: u32, res: [^]i32) ---

    CreateVertexArray :: proc() -> u32 ---
    DeleteVertexArray :: proc(vertexArray: u32) ---
    IsVertexArray     :: proc(vertexArray: u32) -> bool ---
    BindVertexArray   :: proc(vertexArray: u32) ---

    GetIndexedParameter :: proc (target: u32, index: u32, data: ^i32) ---
    GetQueryParameter :: proc(query: u32, name: u32) -> u32 ---
}

GetActiveUniformBlockNameBuf :: proc(program: u32, uniformBlockIndex: i32, buf: []byte) -> string {
    foreign webgl2 {
        @(link_name="GetActiveUniformBlockName")
        _GetActiveUniformBlockName :: proc "contextless" (program: u32, uniformBlockIndex: i32, buf: []byte, length: ^int) ---
    }
    n: int
    _GetActiveUniformBlockName(program, uniformBlockIndex, buf, &n)
    return string(buf[:n])
}

GetActiveUniformBlockNameAlloc :: proc(program: u32, uniformBlockIndex: i32, allocator: runtime.Allocator, loc := #caller_location) -> string {
    foreign webgl2 {
        @(link_name="GetActiveUniformBlockName")
        _GetActiveUniformBlockName :: proc "contextless" (program: u32, uniformBlockIndex: i32, buf: []byte, length: ^int) ---
    }
    n: int
    _GetActiveUniformBlockName(program, uniformBlockIndex, {}, &n)

    if n > 0 {
        buf := make([]byte, n, allocator, loc)
        _GetActiveUniformBlockName(program, uniformBlockIndex, buf, &n)
        assert(n == len(buf))
        return string(buf[:n])
    }

    return ""
}

GetActiveUniformBlockName :: proc {
    GetActiveUniformBlockNameBuf,
    GetActiveUniformBlockNameAlloc,
}

Uniform1uiv :: proc "contextless" (location: i32, v: u32) {
    Uniform1ui(location, v)
}
Uniform2uiv :: proc "contextless" (location: i32, v: glm.uvec2) {
    Uniform2ui(location, v.x, v.y)
}
Uniform3uiv :: proc "contextless" (location: i32, v: glm.uvec3) {
    Uniform3ui(location, v.x, v.y, v.z)
}
Uniform4uiv :: proc "contextless" (location: i32, v: glm.uvec4) {
    Uniform4ui(location, v.x, v.y, v.z, v.w)
}

UniformMatrix3x2fv :: proc "contextless" (location: i32, m: glm.mat3x2) {
    foreign webgl2 {
        @(link_name="UniformMatrix3x2fv")
        _UniformMatrix3x2fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix3x2fv(location, &array[0])
}
UniformMatrix4x2fv :: proc "contextless" (location: i32, m: glm.mat4x2) {
    foreign webgl2 {
        @(link_name="UniformMatrix4x2fv")
        _UniformMatrix4x2fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix4x2fv(location, &array[0])
}
UniformMatrix2x3fv :: proc "contextless" (location: i32, m: glm.mat2x3) {
    foreign webgl2 {
        @(link_name="UniformMatrix2x3fv")
        _UniformMatrix2x3fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix2x3fv(location, &array[0])
}
UniformMatrix4x3fv :: proc "contextless" (location: i32, m: glm.mat4x3) {
    foreign webgl2 {
        @(link_name="UniformMatrix4x3fv")
        _UniformMatrix4x3fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix4x3fv(location, &array[0])
}
UniformMatrix2x4fv :: proc "contextless" (location: i32, m: glm.mat2x4) {
    foreign webgl2 {
        @(link_name="UniformMatrix2x4fv")
        _UniformMatrix2x4fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix2x4fv(location, &array[0])
}
UniformMatrix3x4fv :: proc "contextless" (location: i32, m: glm.mat3x4) {
    foreign webgl2 {
        @(link_name="UniformMatrix3x4fv")
        _UniformMatrix3x4fv :: proc "contextless" (location: i32, addr: [^]f32) ---
    }
    array := intrinsics.matrix_flatten(m)
    _UniformMatrix3x4fv(location, &array[0])
}

VertexAttribI4iv :: proc "contextless" (index: i32, v: glm.ivec4) {
    VertexAttribI4i(index, v.x, v.y, v.z, v.w)
}
VertexAttribI4uiv :: proc "contextless" (index: i32, v: glm.uvec4) {
    VertexAttribI4ui(index, v.x, v.y, v.z, v.w)
}
