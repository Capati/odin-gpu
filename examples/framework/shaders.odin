#+build !js
package framework

// Core
import "base:runtime"
import "core:fmt"
import "core:log"
import os "core:os/os2"

// Libs
import gpu "../../"

// Load a compiled shader source for the current backend.
load_shader_source :: proc(
    device: gpu.Device,
    filename: string,
    stage: gpu.Shader_Stage,
    allocator := context.allocator,
) -> (
    code: []u8,
    ok: bool,
) #optional_ok {
    device_impl := cast(^gpu.Device_Base)device
    formats := device_impl.shader_formats

    dir: string
    ext: string

    switch {
    case .Glsl in formats:
        dir = "GLSL"
        switch stage {
        case .Vertex:   ext = ".vert"
        case .Fragment: ext = ".frag"
        case .Compute:  ext = ".comp"
        case .Task:     ext = ".task"
        case .Mesh:     ext = ".mesh"
        }

    case .Spirv in formats:
        dir = "SPIRV"
        switch stage {
        case .Vertex:   ext = ".vert.spv"
        case .Fragment: ext = ".frag.spv"
        case .Compute:  ext = ".comp.spv"
        case .Task:     ext = ".task.spv"
        case .Mesh:     ext = ".mesh.spv"
        }

    case .Dxil in formats:
        dir = "DXIL"
        ext = ".dxil"

    case .Dxbc in formats:
        dir = "DXBC"
        switch stage {
        case .Vertex:   ext = ".vert.dxbc"
        case .Fragment: ext = ".frag.dxbc"
        case .Compute:  ext = ".comp.dxbc"
        case .Task:     ext = ".task.dxbc"
        case .Mesh:     ext = ".mesh.dxbc"
        }

    case .Msl in formats:
        dir = "MSL"
        ext = ".metal"

    case .Metallib in formats:
        dir = "MSL"
        ext = ".metallib"
    }

    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == context.temp_allocator)

    // Build the full file path
    file_path := fmt.tprintf("./shaders/%s/%s%s", dir, filename, ext)

    // Read the file
    data, err := os.read_entire_file(file_path, allocator)
    if err != nil {
        log.errorf("Failed to load shader for backend %v [%v]: %s",
            device_impl.backend, err, file_path)
        return
    }

    return data, true
}
