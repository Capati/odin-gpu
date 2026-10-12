package application

// Core
import "core:slice"
import "core:strings"

_ :: slice
_ :: strings

// Vendor
import "../../gpu"

SHADERS_DIR :: "shaders/"

DXIL_SHADERS_DIR    :: SHADERS_DIR + "DXIL/"
DXBC_SHADERS_DIR    :: SHADERS_DIR + "DXBC/"
GLSL_SHADERS_DIR    :: SHADERS_DIR + "GLSL/Desktop/"
GLSL_ES_SHADERS_DIR :: SHADERS_DIR + "GLSL/ES/"
SPIRV_SHADERS_DIR   :: SHADERS_DIR + "SPIRV/"
WGSL_SHADERS_DIR    :: SHADERS_DIR + "WGSL/"

@(require_results)
load_shader :: proc(
    device: gpu.Device,
    $dir: string,
    $name: string,
    loc := #caller_location,
) -> gpu.Shader_Module {
    descriptor := gpu.Shader_Module_Descriptor {
        label = name,
    }
    glsl: gpu.Shader_Source_GLSL

    stage: gpu.Shader_Stage
    if strings.has_suffix(name, ".vert") {
        stage = .Vertex
    } else if strings.has_suffix(name, ".frag") {
        stage = .Fragment
    } else {
        panic("Invalid shader stage", loc)
    }

    glsl.stage = stage

    when gpu.USE_SLANG {
        slang := gpu.Shader_Source_SLANG {
            source = #load(dir + name + ".slang"),
            entry_point = "vs_main" if stage == .Vertex else "fs_main",
            stage = stage,
        }
        descriptor.source = slang
    } else when ODIN_OS == .JS {
        wgsl: gpu.Shader_Source_WGSL
        #partial switch gpu.device_backend(device) {
        case .WebGPU:
            wgsl.code = #load(dir + WGSL_SHADERS_DIR + name + ".wgsl")
            descriptor.source = wgsl
        case .OpenGLES:
            // assert(gpu.is_embedded(), loc = loc)
            // glsl.shader = #load(dir + GLSL_ES_SHADERS_DIR + name + ".glsl")
            descriptor.source = glsl
        case:
            panic("Unsupported backend", loc)
        }
    } else when ODIN_OS == .Darwin {
        msl: gpu.Shader_Source_MSL
        mtl: gpu.Shader_Source_Metallib

        // TODO
    } else {
        spirv: gpu.Shader_Source_SPIRV
        dxil: gpu.Shader_Source_DXIL
        dxbc: gpu.Shader_Source_DXBC

        #partial switch gpu.device_backend(device) {
        case .Vulkan:
            spirv.code = slice.reinterpret([]u32,
                #load(dir + SPIRV_SHADERS_DIR + name + ".spv"))
            descriptor.source = spirv
        case .OpenGL:
            glsl.shader = #load(dir + GLSL_SHADERS_DIR + name + ".glsl")
            descriptor.source = glsl
        case .D3D11:
            dxbc.bytecode = #load(dir + DXBC_SHADERS_DIR + name + ".dxbc")
            dxbc.stage = stage
            descriptor.source = dxbc
        case .D3D12:
            dxil.code = #load(dir + DXIL_SHADERS_DIR + name + ".dxil")
            descriptor.source = dxil
        case:
            panic("Unsupported backend", loc)
        }
    }

    return gpu.device_create_shader_module(device, descriptor, loc)
}

// Loads a shader module for an explicit entry point. `load_shader` only knows
// the `vs_main` / `fs_main` pair, so modules with special entries (the IBL
// precompute passes, whose fragments are `fs_convert`, `fs_irradiance`, ...)
// need this variant. `$name` is the artifact base name and must remain a
// compile-time constant for `#load`; `entry` and `stage` are runtime values.
@(require_results)
load_shader_entry :: proc(
    device: gpu.Device,
    $dir: string,
    $name: string,
    entry: string,
    stage: gpu.Shader_Stage,
    loc := #caller_location,
) -> gpu.Shader_Module {
    descriptor := gpu.Shader_Module_Descriptor {
        label = name,
    }
    glsl: gpu.Shader_Source_GLSL
    glsl.stage = stage

    when gpu.USE_SLANG {
        slang := gpu.Shader_Source_SLANG {
            source     = #load(dir + name + ".slang"),
            entry_point = entry,
            stage      = stage,
        }
        descriptor.source = slang
    } else when ODIN_OS == .JS {
        wgsl: gpu.Shader_Source_WGSL
        #partial switch gpu.device_backend(device) {
        case .WebGPU:
            wgsl.code = #load(dir + WGSL_SHADERS_DIR + name + ".wgsl")
            descriptor.source = wgsl
        case .OpenGLES:
            // assert(gpu.is_embedded(), loc = loc)
            // glsl.shader = #load(dir + GLSL_ES_SHADERS_DIR + name + ".glsl")
            descriptor.source = glsl
        case:
            panic("Unsupported backend", loc)
        }
    } else when ODIN_OS == .Darwin {
        // TODO
        panic("MSL shaders not implemented", loc)
    } else {
        spirv: gpu.Shader_Source_SPIRV
        dxil: gpu.Shader_Source_DXIL
        dxbc: gpu.Shader_Source_DXBC

        #partial switch gpu.device_backend(device) {
        case .Vulkan:
            spirv.code = slice.reinterpret([]u32,
                #load(dir + SPIRV_SHADERS_DIR + name + ".spv"))
            descriptor.source = spirv
        case .OpenGL:
            glsl.shader = #load(dir + GLSL_SHADERS_DIR + name + ".glsl")
            descriptor.source = glsl
        case .D3D11:
            dxbc.bytecode = #load(dir + DXBC_SHADERS_DIR + name + ".dxbc")
            dxbc.stage = stage
            descriptor.source = dxbc
        case .D3D12:
            dxil.code = #load(dir + DXIL_SHADERS_DIR + name + ".dxil")
            descriptor.source = dxil
        case:
            panic("Unsupported backend", loc)
        }
    }

    return gpu.device_create_shader_module(device, descriptor, loc)
}

// // Load a shader relative to the build directory.
// load_shader :: proc(
//     device: gpu.Device, name: string, loc := #caller_location,
// ) -> (
//     shader: gpu.Shader_Module,
//     ok: bool,
// ) #optional_ok {
//     return

    // buf: [128]u8
    // sb := strings.builder_from_bytes(buf[:])

    // descriptor := gpu.ShaderModuleDescriptor {
    //     label = name,
    // }

    // #partial switch gpu.device_backend(device) {
    // case .Dx12:
    //     strings.write_string(&sb, DXIL_SHADERS_DIR)
    //     strings.write_string(&sb, name)
    //     strings.write_string(&sb, ".dxil")

    // case .Gl:
    //     if gpu.device_backend_is_embedded(device) {
    //         strings.write_string(&sb, GLSL_ES_SHADERS_DIR)
    //     } else {
    //         strings.write_string(&sb, GLSL_SHADERS_DIR)
    //     }
    //     strings.write_string(&sb, name)
    //     strings.write_string(&sb, ".glsl")

    // case .Vulkan:
    //     strings.write_string(&sb, SPIRV_SHADERS_DIR)
    //     strings.write_string(&sb, name)
    //     strings.write_string(&sb, ".spv")

    // case:
    //     panic("Unsupported backend")
    // }

    // ta := context.temp_allocator
    // runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = context.allocator == ta)

    // filename := strings.to_string(sb)
    // log.debugf("Loading shader: %s", filename)

    // data, data_err := os.read_entire_file(filename, ta)
    // if data_err != nil {
    //     log.errorf("Failed to load shader [%s]: %v", name, data_err, location = loc)
    //     return
    // }

    // stage: gpu.ShaderStage
    // if strings.contains(name, "vert") {
    //     stage = .Vertex
    // } else if strings.contains(name, "frag") {
    //     stage = .Fragment
    // } else if strings.contains(name, "comp") {
    //     stage = .Compute
    // } else {
    //     panic("Invalid shader stage", loc)
    // }

    // #partial switch ctx.gc.info.backend {
    // case .Dx12:
    //     descriptor.source = gpu.ShaderSourceDxil{
    //         code = data,
    //     }
    // case .Gl:
    //     descriptor.source = gpu.ShaderSourceGlsl{
    //         shader = string(data),
    //         stage = stage,
    //     }
    // case .Vulkan:
    //     descriptor.source = gpu.ShaderSourceSpirv{
    //         code = slice.reinterpret([]u32, data),
    //     }
    // case:
    //     panic("Unsupported backend")
    // }

    // shader = gpu.device_create_shader_module(ctx.gc.device, descriptor, loc)
    // if shader == nil {
    //     log.errorf("Failed to create shader [%s]", name, location = loc)
    //     return
    // }

    // return shader, true
// }

// // Load a compiled shader source for the current backend.
// load_shader_source :: proc(
//     device: gpu.Device,
//     filename: string,
//     stage: gpu.ShaderStage,
//     allocator := context.allocator,
// ) -> (
//     code: []u8,
//     ok: bool,
// ) #optional_ok {
//     device_impl := cast(^gpu.Device_Base)device
//     formats := device_impl.shader_formats

//     dir: string
//     ext: string

//     switch {
//     case .Glsl in formats:
//         dir = "GLSL"
//         switch stage {
//         case .Vertex:   ext = ".vert"
//         case .Fragment: ext = ".frag"
//         case .Compute:  ext = ".comp"
//         case .Task:     ext = ".task"
//         case .Mesh:     ext = ".mesh"
//         }

//     case .Spirv in formats:
//         dir = "SPIRV"
//         switch stage {
//         case .Vertex:   ext = ".vert.spv"
//         case .Fragment: ext = ".frag.spv"
//         case .Compute:  ext = ".comp.spv"
//         case .Task:     ext = ".task.spv"
//         case .Mesh:     ext = ".mesh.spv"
//         }

//     case .Dxil in formats:
//         dir = "DXIL"
//         ext = ".dxil"

//     case .Dxbc in formats:
//         dir = "DXBC"
//         switch stage {
//         case .Vertex:   ext = ".vert.dxbc"
//         case .Fragment: ext = ".frag.dxbc"
//         case .Compute:  ext = ".comp.dxbc"
//         case .Task:     ext = ".task.dxbc"
//         case .Mesh:     ext = ".mesh.dxbc"
//         }

//     case .Msl in formats:
//         dir = "MSL"
//         ext = ".metal"

//     case .Metallib in formats:
//         dir = "MSL"
//         ext = ".metallib"
//     }

//     runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == context.temp_allocator)

//     // Build the full file path
//     file_path := fmt.tprintf("./shaders/%s/%s%s", dir, filename, ext)

//     // Read the file
//     data, err := os.read_entire_file(file_path, allocator)
//     if err != nil {
//         log.errorf("Failed to load shader for backend %v [%v]: %s",
//             device_impl.backend, err, file_path)
//         return
//     }

//     return data, true
// }
