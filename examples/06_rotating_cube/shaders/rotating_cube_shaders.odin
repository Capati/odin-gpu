package rotating_cube_shaders

// Local libs
import gpu "../../../"

SHADER_NAME :: "rotating_cube"

load :: proc(device: gpu.Device, stage: gpu.Shader_Stage) -> (code: []u8) {
    backend := gpu.device_get_backend(device)
    when ODIN_OS == .Windows {
        #partial switch stage {
        case .Vertex:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".vert.spv")
            case .Gl: code = #load("GLSL/" + SHADER_NAME + ".vert.glsl")
            case .Dx12: code = #load("DXIL/" + SHADER_NAME + ".vert.dxil")
            case .Dx11: code = #load("DXBC/" + SHADER_NAME + ".vert.dxbc")
            case: unreachable()
            }
        case .Fragment:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".frag.spv")
            case .Gl: code = #load("GLSL/" + SHADER_NAME + ".frag.glsl")
            case .Dx12: code = #load("DXIL/" + SHADER_NAME + ".frag.dxil")
            case .Dx11: code = #load("DXBC/" + SHADER_NAME + ".frag.dxbc")
            case: unreachable()
            }
        }
    } else when ODIN_OS == .Linux {
        #partial switch stage {
        case .Vertex:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".vert.spv")
            case .Gl: code = #load("GLSL/" + SHADER_NAME + ".vert.glsl")
            case: unreachable()
            }
        case .Fragment:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".frag.spv")
            case .Gl: code = #load("GLSL/" + SHADER_NAME + ".frag.glsl")
            case: unreachable()
            }
        }
    } else when ODIN_OS == .JS {
        #partial switch stage {
        case .Vertex:
            #partial switch backend {
            case .WebGPU: code = #load("WGSL/" + SHADER_NAME + ".vert.wgsl")
            case: unreachable()
            }
        case .Fragment:
            #partial switch backend {
            case .WebGPU: code = #load("WGSL/" + SHADER_NAME + ".frag.wgsl")
            case: unreachable()
            }
        }
    } else when ODIN_OS == .Darwin {
        #partial switch stage {
        case .Vertex:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".vert.spv")
            case .Metal: code = #load("MSL/" + SHADER_NAME + ".vert.metal")
            case: unreachable()
            }
        case .Fragment:
            #partial switch backend {
            case .Vulkan: code = #load("SPIRV/" + SHADER_NAME + ".vert.spv")
            case .Metal: code = #load("MSL/" + SHADER_NAME + ".frag.metal")
            case: unreachable()
            }
        }
    } else {
        #panic("unsupported platform")
    }
    return
}
