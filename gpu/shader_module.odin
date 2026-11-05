package gpu

// Handle to a compiled shader module.
//
// A `Shader_Module` represents a compiled shader module on the GPU. It can be
// created by passing source code to `device_create_shader_module`.
//
// Corresponds to [WebGPU
// `GPUShaderModule`](https://gpuweb.github.io/gpuweb/#shader-module).
Shader_Module :: distinct Handle

// SPIR-V module represented as a slice of words.
Shader_Source_SPIRV :: struct {
    code: []u32,
}

// WGSL module as a string.
Shader_Source_WGSL :: struct {
    code: string,
}

// Key-value pairs to represent defines sent to the glsl preprocessor.
//
// If the same name is defined multiple times, the last value is used.
Shader_Define :: struct {
    name:  string,
    value: string,
}

Shader_Source_GLSL :: struct {
    // The source code of the shader.
    shader:  string,
    // The shader stage that the shader targets. For example,
    // `naga: :ShaderStage::Vertex`
    stage:   Shader_Stage,
    // Key-value pairs to represent defines sent to the glsl preprocessor.
    //
    // If the same name is defined multiple times, the last value is used.
    defines: []Shader_Define,
}

// Slang module represented by a source string.
Shader_Source_SLANG :: struct {
    source:      string,
    entry_point: string,
    stage:       Shader_Stage,
}

Shader_Source_DXIL :: struct {
    code: []u8,
}

Shader_Source_HLSL :: struct {
    shader: string,
    stage:  Shader_Stage,
}

Shader_Source_DXBC :: struct {
    bytecode: []u8,
    stage:    Shader_Stage,
}

// Metal Shading Language source.
Shader_Source_MSL :: struct {
    shader:      string,
    entry_point: string,
    stage:       Shader_Stage,
}

// Precompiled Metal library (.metallib).
Shader_Source_Metallib :: struct {
    code:        []u8,
    entry_point: string,
    stage:       Shader_Stage,
}

// Source of a shader module.
Shader_Source :: union {
    Shader_Source_SPIRV,
    Shader_Source_WGSL,
    Shader_Source_GLSL,
    Shader_Source_SLANG,
    Shader_Source_DXIL,
    Shader_Source_HLSL,
    Shader_Source_DXBC,
    Shader_Source_MSL,
    Shader_Source_Metallib,
}

// Descriptor for use with `device_create_shader_module`.
//
// Corresponds to [WebGPU `GPUShaderModuleDescriptor`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpushadermoduledescriptor).
Shader_Module_Descriptor :: struct {
    // Debug label of the shader module.
    label:  string,
    // Source code for the shader.
    source: Shader_Source,
}

// Descriptor for creating a SPIR-V shader module.
Shader_Module_Descriptor_SpirV :: struct {
    label:  string,
    source: []u32,
}

// Optional runtime checks applied when trusted shader source is translated.
Shader_Runtime_Check :: enum i32 {
    Bounds_Checks,
    Force_Loop_Bounding,
    Ray_Query_Initialization_Tracking,
    Task_Shader_Dispatch_Tracking,
    Mesh_Shader_Primitive_Indices_Clamp,
}

Shader_Runtime_Checks :: bit_set[Shader_Runtime_Check;Flags]

// A single message from the shader compilation process.
//
// Roughly corresponds to
// [`GPUCompilationMessage`](https://www.w3.org/TR/webgpu/#gpucompilationmessage),
// except that the location uses UTF-8 for all positions.
Compilation_Message :: struct {
    // Human-readable text of the message.
    message:      string,
    // Severity / kind of the message (error, warning, or info).
    message_type: Compilation_Message_Type,
    // 1-based line number in the shader source where the message applies.
    // `0` if the message is not associated with a specific line.
    line_num:     u64,
    // 1-based UTF-8 offset from the start of the line where the message applies.
    // `0` if the message is not associated with a specific position.
    line_pos:     u64,
    // 0-based UTF-8 byte offset from the start of the whole shader source
    // where the message applies.
    offset:       u64,
    // Length in UTF-8 bytes of the range the message applies to.
    // `0` if the message is not associated with a specific range.
    length:       u64,
}

// Compilation messages reported by `shader_module_get_compilation_info()`.
Compilation_Info :: struct {
    messages: []Compilation_Message,
}

// Creates a shader module.
//
// The Vulkan backend accepts SPIR-V; the browser backend accepts WGSL. Other
// sources are backend-specific. Invalid source is reported through the device's
// validation path and returns `{}`.
device_create_shader_module: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module

// Creates a shader module from SPIR-V words.
//
// Requires the `Shader_Source_SPIRV` instance feature. The browser backend does
// not support this and reports a validation error.
device_create_shader_module_spirv: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor_SpirV,
    loc := #caller_location,
) -> Shader_Module

// Creates a shader module from source already trusted by the caller.
//
// `runtime_checks` selects which safety checks the translator should keep.
// Backends that consume the module directly ignore them.
device_create_shader_module_trusted: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    runtime_checks: Shader_Runtime_Checks,
    loc := #caller_location,
) -> Shader_Module

// Requests compilation messages for the shader module.
//
// The returned `Future` resolves when the information is available;
// `callback_info` receives the result. The Vulkan backend validates SPIR-V at
// pipeline creation, so it returns an already-complete future with no messages.
shader_module_get_compilation_info: proc(
    shader_module: Shader_Module,
    callback_info: Compilation_Info_Callback_Info,
    loc := #caller_location,
) -> Future

// Returns the shader module's debug label.
//
// The string is owned by the shader module and stays valid until the next
// `shader_module_set_label()` or until the shader module is released.
shader_module_get_label: proc(shader_module: Shader_Module, loc := #caller_location) -> string

// Sets the shader module's debug label.
//
// The shader module keeps its own copy of `label`, so the caller may release its
// copy immediately after this call.
shader_module_set_label: proc(shader_module: Shader_Module, label: string, loc := #caller_location)

// Increments the shader module's reference count.
shader_module_add_ref: proc(shader_module: Shader_Module, loc := #caller_location)

// Decrements the shader module's reference count, destroying it when it reaches
// zero.
shader_module_release: proc(shader_module: Shader_Module, loc := #caller_location)

// -----------------------------------------------------------------------------
// @private - Not part of the public API
// -----------------------------------------------------------------------------

_Shader_Module_Impl :: struct {
    device: Device,
    ref:    Ref_Count_Type,
}

// Backend hook: resolve a shader module to its owning device and liveness.
_shader_module_get_internal_impl: proc "contextless" (
    shader_module: Shader_Module,
    loc := #caller_location,
) -> ^_Shader_Module_Impl
