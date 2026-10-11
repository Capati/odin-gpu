package webgl

foreign import "webgl"

import glm "core:math/linalg/glsl"
import "base:runtime"

ContextAttribute :: enum u32 {
    disableAlpha                 = 0,
    disableAntialias             = 1,
    disableDepth                 = 2,
    failIfMajorPerformanceCaveat = 3,
    disablePremultipliedAlpha    = 4,
    preserveDrawingBuffer        = 5,
    stencil                      = 6,
    desynchronized               = 7,
}
ContextAttributes :: distinct bit_set[ContextAttribute; u32]

ActiveInfo :: struct {
    size: int,
    type: u32,
    name: string,
}

DEFAULT_CONTEXT_ATTRIBUTES :: ContextAttributes{}

@(default_calling_convention="contextless")
foreign webgl {
    // CreateCurrentContextById must be called before `GetCurrentContextAttributes` if the user wants to
    // set specific attributes, otherwise the default attributes will be set for the WebGL context
    CreateCurrentContextById :: proc(name: string, attributes: ContextAttributes) -> bool ---
    // Acquire the WebGL context from a canvas element by id
    SetCurrentContextById :: proc(name: string) -> bool ---
    GetCurrentContextAttributes :: proc() -> ContextAttributes ---

    DrawingBufferWidth  :: proc() -> i32 ---
    DrawingBufferHeight :: proc() -> i32 ---

    GetWebGLVersion :: proc(major, minor: ^i32) ---
    GetESVersion :: proc(major, minor: ^i32) ---

    GetError :: proc() -> u32 ---

    IsExtensionSupported :: proc(name: string) -> bool ---
    GetExtension :: proc(name: string) ---

    ActiveTexture         :: proc(x: u32) ---
    AttachShader          :: proc(program: u32, shader: u32) ---
    BindAttribLocation    :: proc(program: u32, index: i32, name: string) ---
    BindBuffer            :: proc(target: u32, buffer: u32) ---
    BindFramebuffer       :: proc(target: u32, framebuffer: u32) ---
    BindTexture           :: proc(target: u32, texture: u32) ---
    BindRenderbuffer      :: proc(target: u32, renderbuffer: u32) ---
    BlendColor            :: proc(red, green, blue, alpha: f32) ---
    BlendEquation         :: proc(mode: u32) ---
    BlendEquationSeparate :: proc(modeRGB: u32, modeAlpha: u32) ---
    BlendFunc             :: proc(sfactor, dfactor: u32) ---
    BlendFuncSeparate     :: proc(srcRGB, dstRGB, srcAlpha, dstAlpha: u32) ---

    BufferData    :: proc(target: u32, size: int, data: rawptr, usage: u32) ---
    BufferSubData :: proc(target: u32, offset: uintptr, size: int, data: rawptr) ---

    Clear         :: proc(bits: u32) ---
    ClearColor    :: proc(r, g, b, a: f32) ---
    ClearDepth    :: proc(x: f32) ---
    ClearStencil  :: proc(x: i32) ---
    ColorMask     :: proc(r, g, b, a: bool) ---
    CompileShader :: proc(shader: u32) ---

    CompressedTexImage2D    :: proc(target: u32, level: i32, internalformat: u32, width, height: i32, border: i32, imageSize: int, data: rawptr) ---
    CompressedTexSubImage2D :: proc(target: u32, level: i32, xoffset, yoffset, width, height: i32, format: u32, imageSize: int, data: rawptr) ---
    CopyTexImage2D          :: proc(target: u32, level: i32, internalformat: u32, x, y, width, height: i32, border: i32) ---
    CopyTexSubImage2D       :: proc(target: u32, level: i32, xoffset, yoffset, x, y: i32, width, height: i32) ---


    CreateBuffer       :: proc() -> u32 ---
    CreateFramebuffer  :: proc() -> u32 ---
    CreateProgram      :: proc() -> u32 ---
    CreateRenderbuffer :: proc() -> u32 ---
    CreateShader       :: proc(shaderType: u32) -> u32 ---
    CreateTexture      :: proc() -> u32 ---

    CullFace :: proc(mode: u32) ---

    DeleteBuffer       :: proc(buffer: u32) ---
    DeleteFramebuffer  :: proc(framebuffer: u32) ---
    DeleteProgram      :: proc(program: u32) ---
    DeleteRenderbuffer :: proc(renderbuffer: u32) ---
    DeleteShader       :: proc(shader: u32) ---
    DeleteTexture      :: proc(texture: u32) ---

    DepthFunc                :: proc(func: u32) ---
    DepthMask                :: proc(flag: bool) ---
    DepthRange               :: proc(zNear, zFar: f32) ---
    DetachShader             :: proc(program: u32, shader: u32) ---
    Disable                  :: proc(cap: u32) ---
    DisableVertexAttribArray :: proc(index: i32) ---
    DrawArrays               :: proc(mode: u32, first, count: int) ---
    DrawElements             :: proc(mode: u32, count: int, type: u32, indices: rawptr) ---

    Enable                  :: proc(cap: u32) ---
    EnableVertexAttribArray :: proc(index: i32) ---
    Finish                  :: proc() ---
    Flush                   :: proc() ---
    FramebufferRenderbuffer :: proc(target, attachment, renderbufertarget: u32, renderbuffer: u32) ---
    FramebufferTexture2D    :: proc(target, attachment, textarget: u32, texture: u32, level: i32) ---
    CheckFramebufferStatus  :: proc(target: u32) -> u32 ---
    FrontFace               :: proc(mode: u32) ---

    GenerateMipmap :: proc(target: u32) ---

    GetBufferParameter    :: proc(target, name: u32) -> int ---
    GetAttribLocation     :: proc(program: u32, name: string) -> i32 ---
    GetUniformLocation    :: proc(program: u32, name: string) -> i32 ---
    GetVertexAttribOffset :: proc(index: i32, pname: u32) -> uintptr ---
    GetProgramParameter   :: proc(program: u32, pname: u32) -> i32 ---
    GetParameter          :: proc(pname: u32) -> i32 ---
    GetParameter4i        :: proc(pname: u32, v0, v1, v2, v4: ^i32) ---

    Hint :: proc(target: u32, mode: u32) ---

    IsBuffer       :: proc(buffer: u32) -> bool ---
    IsEnabled      :: proc(cap: u32) -> bool ---
    IsFramebuffer  :: proc(framebuffer: u32) -> bool ---
    IsProgram      :: proc(program: u32) -> bool ---
    IsRenderbuffer :: proc(renderbuffer: u32) -> bool ---
    IsShader       :: proc(shader: u32) -> bool ---
    IsTexture      :: proc(texture: u32) -> bool ---

    LineWidth     :: proc(width: f32) ---
    LinkProgram   :: proc(program: u32) ---
    PixelStorei   :: proc(pname: u32, param: i32) ---
    PolygonOffset :: proc(factor: f32, units: f32) ---

    ReadnPixels         :: proc(x, y, width, height: i32, format: u32, type: u32, bufSize: int, data: rawptr) ---
    RenderbufferStorage :: proc(target: u32, internalformat: u32, width, height: i32) ---
    SampleCoverage      :: proc(value: f32, invert: bool) ---
    Scissor             :: proc(x, y, width, height: i32) ---
    ShaderSource        :: proc(shader: u32, strings: []string) ---

    StencilFunc         :: proc(func: u32, ref: i32, mask: u32) ---
    StencilFuncSeparate :: proc(face, func: u32, ref: i32, mask: u32) ---
    StencilMask         :: proc(mask: u32) ---
    StencilMaskSeparate :: proc(face: u32, mask: u32) ---
    StencilOp           :: proc(fail, zfail, zpass: u32) ---
    StencilOpSeparate   :: proc(face, fail, zfail, zpass: u32)  ---

    TexImage2D    :: proc(target: u32, level: i32, internalformat: u32, width, height: i32, border: i32, format, type: u32, size: int, data: rawptr) ---
    TexSubImage2D :: proc(target: u32, level: i32, xoffset, yoffset, width, height: i32, format, type: u32, size: int, data: rawptr) ---

    TexParameterf :: proc(target, pname: u32, param: f32) ---
    TexParameteri :: proc(target, pname: u32, param: i32) ---

    Uniform1f :: proc(location: i32, v0: f32) ---
    Uniform2f :: proc(location: i32, v0, v1: f32) ---
    Uniform3f :: proc(location: i32, v0, v1, v2: f32) ---
    Uniform4f :: proc(location: i32, v0, v1, v2, v3: f32) ---

    Uniform1i :: proc(location: i32, v0: i32) ---
    Uniform2i :: proc(location: i32, v0, v1: i32) ---
    Uniform3i :: proc(location: i32, v0, v1, v2: i32) ---
    Uniform4i :: proc(location: i32, v0, v1, v2, v3: i32) ---

    UseProgram      :: proc(program: u32) ---
    ValidateProgram :: proc(program: u32) ---

    VertexAttrib1f      :: proc(index: i32, x: f32) ---
    VertexAttrib2f      :: proc(index: i32, x, y: f32) ---
    VertexAttrib3f      :: proc(index: i32, x, y, z: f32) ---
    VertexAttrib4f      :: proc(index: i32, x, y, z, w: f32) ---
    VertexAttribPointer :: proc(index: i32, size: int, type: u32, normalized: bool, stride: int, ptr: uintptr) ---

    Viewport :: proc(x, y, w, h: i32) ---
}

@(default_calling_convention="contextless")
foreign webgl {
    GetShaderPrecisionFormat :: proc(shaderType, precisionType: u32, rangeMin: ^i32, rangeMax: ^i32, precision: ^i32) ---
}

Uniform1fv :: proc "contextless" (location: i32, v: []f32) {
    foreign webgl {
        @(link_name="Uniform1fv")
        _Uniform1fv :: proc "contextless" (location: i32, count: int, value: [^]f32) ---
    }
    _Uniform1fv(location, len(v), &v[0])
}
Uniform2fv :: proc "contextless" (location: i32, v: []glm.vec2) {
    foreign webgl {
        @(link_name="Uniform2fv")
        _Uniform2fv :: proc "contextless" (location: i32, count: int, value: [^]f32) ---
    }
    _Uniform2fv(location, len(v), &v[0].x)
}
Uniform3fv :: proc "contextless" (location: i32, v: []glm.vec3) {
    foreign webgl {
        @(link_name="Uniform3fv")
        _Uniform3fv :: proc "contextless" (location: i32, count: int, value: [^]f32) ---
    }
    _Uniform3fv(location, len(v), &v[0].x)
}
Uniform4fv :: proc "contextless" (location: i32, v: []glm.vec4) {
    foreign webgl {
        @(link_name="Uniform4fv")
        _Uniform4fv :: proc "contextless" (location: i32, count: int, value: [^]f32) ---
    }
    _Uniform4fv(location, len(v), &v[0].x)
}

Uniform1iv :: proc "contextless" (location: i32, v: []i32) {
    foreign webgl {
        @(link_name="Uniform1iv")
        _Uniform1iv :: proc "contextless" (location: i32, count: int, value: [^]i32) ---
    }
    _Uniform1iv(location, len(v), &v[0])
}
Uniform2iv :: proc "contextless" (location: i32, v: []glm.ivec2) {
    foreign webgl {
        @(link_name="Uniform2iv")
        _Uniform2iv :: proc "contextless" (location: i32, count: int, value: [^]i32) ---
    }
    _Uniform2iv(location, len(v), &v[0].x)
}
Uniform3iv :: proc "contextless" (location: i32, v: []glm.ivec3) {
    foreign webgl {
        @(link_name="Uniform3iv")
        _Uniform3iv :: proc "contextless" (location: i32, count: int, value: [^]i32) ---
    }
    _Uniform3iv(location, len(v), &v[0].x)
}
Uniform4iv :: proc "contextless" (location: i32, v: []glm.ivec4) {
    foreign webgl {
        @(link_name="Uniform4iv")
        _Uniform4iv :: proc "contextless" (location: i32, count: int, value: [^]i32) ---
    }
    _Uniform4iv(location, len(v), &v[0].x)
}

VertexAttrib1fv :: proc "contextless" (index: i32, v: f32)     { VertexAttrib1f(index, v) }
VertexAttrib2fv :: proc "contextless" (index: i32, v: glm.vec2){ VertexAttrib2f(index, v.x, v.y) }
VertexAttrib3fv :: proc "contextless" (index: i32, v: glm.vec3){ VertexAttrib3f(index, v.x, v.y, v.z) }
VertexAttrib4fv :: proc "contextless" (index: i32, v: glm.vec4){ VertexAttrib4f(index, v.x, v.y, v.z, v.w) }

UniformMatrix2fv :: proc "contextless" (location: i32, m: glm.mat2) {
    foreign webgl {
        @(link_name="UniformMatrix2fv")
        _UniformMatrix2fv :: proc "contextless" (location: i32, value: [^]f32) ---
    }
    value := transmute([2*2]f32)m
    _UniformMatrix2fv(location, &value[0])
}
UniformMatrix3fv :: proc "contextless" (location: i32, m: glm.mat3) {
    foreign webgl {
        @(link_name="UniformMatrix3fv")
        _UniformMatrix3fv :: proc "contextless" (location: i32, value: [^]f32) ---
    }
    value := transmute([3*3]f32)m
    _UniformMatrix3fv(location, &value[0])
}
UniformMatrix4fv :: proc "contextless" (location: i32, m: glm.mat4) {
    foreign webgl {
        @(link_name="UniformMatrix4fv")
        _UniformMatrix4fv :: proc "contextless" (location: i32, value: [^]f32) ---
    }
    value := transmute([4*4]f32)m
    _UniformMatrix4fv(location, &value[0])
}
GetShaderiv :: proc "contextless" (shader: u32, pname: u32) -> (p: i32) {
    foreign webgl {
        @(link_name="GetShaderiv")
        _GetShaderiv :: proc "contextless" (shader: u32, pname: u32, p: ^i32) ---
    }
    _GetShaderiv(shader, pname, &p)
    return
}

GetActiveAttribBuf :: proc "contextless" (program: u32, index: u32, name_buf: []byte) -> (info: ActiveInfo) {
    foreign webgl {
        @(link_name="GetActiveAttrib")
        _GetActiveAttrib :: proc "contextless" (shader: u32, index: u32, size: ^int, type: ^u32, name_buf: []byte, name_len: ^int) ---
    }
    name_len: int
    _GetActiveAttrib(program, index, &info.size, &info.type, name_buf, &name_len)
    info.name = string(name_buf[:name_len])
    return
}

GetActiveAttribAlloc :: proc(program: u32, index: u32, allocator: runtime.Allocator, loc := #caller_location) -> (info: ActiveInfo) {
    foreign webgl {
        @(link_name="GetActiveAttrib")
        _GetActiveAttrib :: proc "contextless" (shader: u32, index: u32, size: ^int, type: ^u32, name_buf: []byte, name_len: ^int) ---
    }

    name_len: int

    // Passing {} to the buf but giving it a name_len ptr will write the needed len into that int
    _GetActiveAttrib(program, index, &info.size, &info.type, {}, &name_len)

    if name_len > 0 {
        name_buf := make([]byte, name_len, allocator, loc)
        _GetActiveAttrib(program, index, &info.size, &info.type, name_buf, &name_len)
        assert(name_len == len(name_buf))
        info.name = string(name_buf[:name_len])
    }

    return
}

GetActiveAttrib :: proc {
    GetActiveAttribBuf,
    GetActiveAttribAlloc,
}

GetActiveUniformBuf :: proc "contextless" (program: u32, index: u32, name_buf: []byte) -> (info: ActiveInfo) {
    foreign webgl {
        @(link_name="GetActiveUniform")
        _GetActiveUniform :: proc "contextless" (shader: u32, index: u32, size: ^int, type: ^u32, name_buf: []byte, name_len: ^int) ---
    }
    name_len: int
    _GetActiveUniform(program, index, &info.size, &info.type, name_buf, &name_len)
    info.name = string(name_buf[:name_len])
    return
}

GetActiveUniformAlloc :: proc(program: u32, index: u32, allocator: runtime.Allocator, loc := #caller_location) -> (info: ActiveInfo) {
    foreign webgl {
        @(link_name="GetActiveUniform")
        _GetActiveUniform :: proc "contextless" (shader: u32, index: u32, size: ^int, type: ^u32, name_buf: []byte, name_len: ^int) ---
    }

    name_len: int

    // Passing {} to the buf but giving it a name_len ptr will write the needed len into that int
    _GetActiveUniform(program, index, &info.size, &info.type, {}, &name_len)

    if name_len > 0 {
        name_buf := make([]byte, name_len, allocator, loc)
        _GetActiveUniform(program, index, &info.size, &info.type, name_buf, &name_len)
        assert(name_len == len(name_buf))
        info.name = string(name_buf[:name_len])
    }

    return
}

GetActiveUniform :: proc {
    GetActiveUniformBuf,
    GetActiveUniformAlloc,
}

GetProgramInfoLog :: proc "contextless" (program: u32, buf: []byte) -> string {
    foreign webgl {
        @(link_name="GetProgramInfoLog")
        _GetProgramInfoLog :: proc "contextless" (program: u32, buf: []byte, length: ^int) ---
    }

    length: int
    _GetProgramInfoLog(program, buf, &length)
    return string(buf[:length])
}

GetShaderInfoLog :: proc "contextless" (shader: u32, buf: []byte) -> string {
    foreign webgl {
        @(link_name="GetShaderInfoLog")
        _GetShaderInfoLog :: proc "contextless" (shader: u32, buf: []byte, length: ^int) ---
    }

    length: int
    _GetShaderInfoLog(shader, buf, &length)
    return string(buf[:length])
}

IterateSupportedExtensions :: proc(index: ^int, buf: []byte) -> (string, bool) {
    foreign webgl {
        @(link_name="GetSupportedExtensionFromIndex")
        _GetSupportedExtensionFromIndex :: proc "contextless" (index: int, buf: []byte, length: ^int) -> bool ---
    }

    length: int
    if !_GetSupportedExtensionFromIndex(index^, buf[:], &length) {
        return "", false
    }

    index^ += 1

    return string(buf[:length]), true
}

BufferDataSlice :: proc "contextless" (target: u32, slice: $S/[]$E, usage: u32) {
    BufferData(target, len(slice)*size_of(E), raw_data(slice), usage)
}
BufferSubDataSlice :: proc "contextless" (target: u32, offset: uintptr, slice: $S/[]$E) {
    BufferSubData(target, offset, len(slice)*size_of(E), raw_data(slice))
}

CompressedTexImage2DSlice :: proc "contextless" (target: u32, level: i32, internalformat: u32, width, height: i32, border: i32, slice: $S/[]$E) {
    CompressedTexImage2DSlice(target, level, internalformat, width, height, border, len(slice)*size_of(E), raw_data(slice))
}
CompressedTexSubImage2DSlice :: proc "contextless" (target: u32, level: i32, xoffset, yoffset, width, height: i32, format: u32, slice: $S/[]$E) {
    CompressedTexSubImage2DSlice(target, level, level, xoffset, yoffset, width, height, format, len(slice)*size_of(E), raw_data(slice))
}

ReadPixelsSlice :: proc "contextless" (x, y, width, height: i32, format: u32, type: u32, slice: $S/[]$E) {
    ReadnPixels(x, y, width, height, format, type, len(slice)*size_of(E), raw_data(slice))
}

TexImage2DSlice :: proc "contextless" (target: u32, level: i32, internalformat: u32, width, height: i32, border: i32, format, type: u32, slice: $S/[]$E) {
    TexImage2D(target, level, internalformat, width, height, border, format, type, len(slice)*size_of(E), raw_data(slice))
}
TexSubImage2DSlice :: proc "contextless" (target: u32, level: i32, xoffset, yoffset, width, height: i32, format, type: u32, slice: $S/[]$E) {
    TexSubImage2D(target, level, xoffset, yoffset, width, height, format, type, len(slice)*size_of(E), raw_data(slice))
}

GetParameterIndexedString :: proc "contextless" (pname: u32, index: u32, buf: []byte) -> string {
    foreign webgl {
        @(link_name="GetParameterIndexedString")
        _GetParameterIndexedString :: proc "contextless" (pname: u32, index: u32, buf: []byte, length: ^int) ---
    }

    length: int
    _GetParameterIndexedString(pname, index, buf, &length)
    return string(buf[:length])
}

GetParameterString :: proc "contextless" (pname: u32, buf: []byte) -> string {
    foreign webgl {
        @(link_name="GetParameterString")
        _GetParameterString :: proc "contextless" (pname: u32, buf: []byte, length: ^int) ---
    }

    length: int
    _GetParameterString(pname, buf, &length)
    return string(buf[:length])
}

ASTCSupportLDRProfile :: proc() -> bool {
    foreign webgl {
        @(link_name = "ASTCSupportLDRProfile")
        _ASTCSupportLDRProfile :: proc "contextless" () -> bool ---
    }
    return _ASTCSupportLDRProfile()
}

ASTCSupportHDRProfile :: proc() -> bool {
    foreign webgl {
        @(link_name = "ASTCSupportHDRProfile")
        _ASTCSupportHDRProfile :: proc "contextless" () -> bool ---
    }
    return _ASTCSupportHDRProfile()
}
