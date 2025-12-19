#+build js
package framework

// Core
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"

// Libs
import "../../../gpu"

foreign import "odin_env"

@(default_calling_convention="contextless")
foreign odin_env {
    load_file_sync :: proc(path: string, buffer: [^]u8, buffer_size: int) -> int ---
}

// Load a compiled shader source for the WebGPU backend.
load_shader_source :: proc(
    device: gpu.Device,
    filename: string,
    stage: gpu.Shader_Stage,
    allocator := context.allocator,
) -> (
    code: []u8,
    ok: bool,
) {
    ext: string
    switch stage {
    case .Vertex:   ext = ".vert.wgsl"
    case .Fragment: ext = ".frag.wgsl"
    case .Compute:  ext = ".comp.wgsl"
    case .Task:     ext = ".task.wgsl"
    case .Mesh:     ext = ".mesh.wgsl"
    }

    // Build the full file path
    file_path := fmt.tprintf("./shaders/%s/%s%s", "WGSL", filename, ext)

    // Create temporary buffer
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == context.temp_allocator)
    temp_buffer := make([]u8, 1 * mem.Megabyte, context.temp_allocator)

    // Load file into buffer
    length := load_file_sync(file_path, raw_data(temp_buffer), len(temp_buffer))

    if length <= 0 {
        log.errorf("Failed to load shader: %s", file_path)
        return
    }

    // Copy to final buffer with requested allocator
    code = make([]u8, length, allocator)
    copy(code, temp_buffer[:length])

    // fmt.println("Loaded shader:", file_path, "- Size:", length)

    return code, true
}
