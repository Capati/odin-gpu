package imgui_renderer

// Core
import "core:slice"

// Local
import "../../../gpu"

SHADER_NAME :: "imgui_renderer"

load_shader :: proc(device: gpu.Device, stage: gpu.Shader_Stage) -> gpu.Shader_Module {
    descriptor: gpu.Shader_Module_Descriptor

    glsl: gpu.Shader_Source_GLSL

    when ODIN_OS == .JS {
        wgsl := gpu.Shader_Source_WGSL {
            stype = .Shader_Source_WGSL,
        }
        #partial switch gpu.device_backend(device) {
        case .BrowserWebGPU:
            descriptor.next_in_chain = &wgsl.chain
            #partial switch stage {
            case .Vertex:
                wgsl.code = #load("shaders/WGSL/" + SHADER_NAME + ".vert.wgsl")
            case .Fragment:
                wgsl.code = #load("shaders/WGSL/" + SHADER_NAME + ".frag.wgsl")
            case:
                panic("Unsupported shader stage")
            }
        case .GL:
            assert(gpu.is_embedded())
            descriptor.next_in_chain = &glsl.chain
            glsl.stage = stage
            #partial switch stage {
            case .Vertex:
                glsl.code = #load("shaders/GLSL/ES/" + SHADER_NAME + ".vert.glsl")
            case .Fragment:
                glsl.code = #load("shaders/GLSL/ES/" + SHADER_NAME + ".frag.glsl")
            case:
                panic("Unsupported shader stage")
            }
        }
    } else when gpu.USE_SLANG {
        slang := gpu.Shader_Source_Slang {
            stype = .Shader_Source_Slang,
            code  = #load(SHADER_NAME + ".slang"),
            stage = stage,
        }
        #partial switch stage {
        case .Vertex:
            slang.entry_point = "vs_main"
        case .Fragment:
            slang.entry_point = "fs_main"
        case:
            panic("Unsupported shader stage")
        }
        descriptor.next_in_chain = &slang.chain
    } else {
        spirv: gpu.Shader_Source_SPIRV
        dxil: gpu.Shader_Source_DXIL
        dxbc: gpu.Shader_Source_DXBC

        #partial switch gpu.device_backend(device) {
        case .Vulkan:
            #partial switch stage {
            case .Vertex:
                spirv.code = slice.reinterpret([]u32,
                    #load("shaders/SPIRV/" + SHADER_NAME + ".vert.spv"))
            case .Fragment:
                spirv.code = slice.reinterpret([]u32,
                    #load("shaders/SPIRV/" + SHADER_NAME + ".frag.spv"))
            case:
                panic("Unsupported shader stage")
            }
            descriptor.source = spirv
        case .OpenGL:
            glsl.stage = stage
            #partial switch stage {
            case .Vertex:
                glsl.shader = #load("shaders/GLSL/Desktop/" + SHADER_NAME + ".vert.glsl")
            case .Fragment:
                glsl.shader = #load("shaders/GLSL/Desktop/" + SHADER_NAME + ".frag.glsl")
            case:
                panic("Unsupported shader stage")
            }
            descriptor.source = glsl
        case .D3D11:
            dxbc.stage = stage
            #partial switch stage {
            case .Vertex:
                dxbc.bytecode = #load("shaders/DXBC/" + SHADER_NAME + ".vert.dxbc")
            case .Fragment:
                dxbc.bytecode = #load("shaders/DXBC/" + SHADER_NAME + ".frag.dxbc")
            case:
                panic("Unsupported shader stage")
            }
            descriptor.source = dxbc
        case .D3D12:
            #partial switch stage {
            case .Vertex:
                dxil.code = #load("shaders/DXIL/" + SHADER_NAME + ".vert.dxil")
            case .Fragment:
                dxil.code = #load("shaders/DXIL/" + SHADER_NAME + ".frag.dxil")
            case:
                panic("Unsupported shader stage")
            }
            descriptor.source = dxil
        case:
            panic("Unsupported backend")
        }
    }

    return gpu.device_create_shader_module(device, descriptor)
}
