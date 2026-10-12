# Odin GPU

<p align="left">
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" height="25">
  </a>
  <a href="https://odin-lang.org/">
    <img src="https://img.shields.io/badge/Language-Odin-blue" alt="Language: Odin" height="25">
  </a>
  <a href="#status">
    <img src="https://img.shields.io/badge/Status-WIP-orange" alt="Status: WIP" height="25">
  </a>
</p>

A modern graphics API wrapper for [Odin Language][], inspired by the [WebGPU][] specification. This
library provides abstractions over Vulkan, DirectX 11/12, Metal, OpenGL, and WebGPU backends.

## Status

> [!WARNING]
> **This project is extremely work-in-progress.**. Until the API is stabilized, break
> changes can happen without notice.

## Overview

The goal is to follow the WebGPU spec in a one-to-one manner not only in the native backend but in
WebGPU itself as well. In case of any deviations due to constraints of native backends, the
implementation of WebGPU should work the same way; deviations should exist under the hood of native
backends and never affect the spec implementation.

Currently I'm working on [renderlink][] as a "proof of concept" for this library. You can also
check [all examples](./examples).

## Backends

Current development focus is the Vulkan backend and WebGPU/WASM support. The other backends are
parked until the Vulkan implementation stabilizes.

| Feature | Status | Notes |
| --------- | -------- | ------- |
| **Core API** | | |
| Core API Layout | In Progress | Basic types exist, API not yet stable |
| **Backends** | | |
| Vulkan | In Progress | Should be the main backend |
| DirectX 12 | Not Started | Windows support |
| DirectX 11 | Parked | Fallback Windows support |
| Metal | Not Started | Might rely on MoltenVK first |
| OpenGL | Parked | Fallback backend on Linux and Windows |
| WebGPU | In Progress | WASM support |
| WebGL | Not Started | Fallback WASM support, limited features |
| **Advanced** | | |
| Bindless | TODO | |
| Ray Tracing | TODO | |
| Mesh Shaders | TODO | |

## Installation

Tested in Odin version: `dev-2026-10`

Only the `gpu/` folder is required to use the library. Copy this folder next
to your project, then import it:

```odin
import "path/to/gpu"
```

Alternatively, register it as an Odin collection so all your projects can use
a stable import path:

```shell
odin build . -collection:libs=<path-to-this-repo>
```

```odin
import "libs:gpu"
```

### Project Structure

```text
├── gpu            # Core API
│   ├── lib        # Vendored library and bindings
│   └── stash      # D3D11/D3D12/Metal/OpenGL backends, returning later
├── examples       # Collection of examples to show usage
│   └── build      # Examples output folder + assets submodule
├── site           # Showcase website
│   ├── app        # Gallery homepage + per-example canvas pages
│   └── tools      # Manifest staging (prep) + web builds
├── utils          # Additional renderer and utility packages
│   ├── glfw       # Surface creation helpers for GLFW
│   ├── gltf       # glTF loader (+ tools/bench, tools/compare)
│   ├── imgui      # ImGui renderer
│   ├── sdl2/sdl3  # Surface creation helpers for SDL
│   ├── microui    # Micro UI renderer
│   └── tobj       # OBJ loader
├── tests          # Some harness tests
├── wasm           # Browser shell (webgpu.js, index.html)
├── resources      # Vendored WebGPU headers
└── CHANGELOG.md   # Release notes
```

## Current Implementation

### Shader Model

One major difference from the WebGPU specification is the shader language. WebGPU uses WGSL as its
shading language, but Odin GPU does **not** require WGSL for native backends.

WGSL is only used when targeting WebAssembly/WebGPU in the browser. For native platforms, you’re
free to bring your own shaders in whatever format or language your backend supports (SPIR-V, GLSL,
DXIL, MSL and WGSL).

That said, we **strongly recommend using [Slang](https://github.com/shader-slang/slang)**. Slang
lets you write modern HLSL-style shaders and compile them to multiple targets. The current examples
is using slang to compile for the supported backends.

### Bind Group Layout

Unlike WebGPU `"auto"` layout that allows the API to infer bind group layouts from shader reflection
at pipeline creation time, Odin GPU **requires explicit bind group layout creation**. The procedure
`render_pipeline_get_bind_group_layout()` is currently **not available**.

You must explicitly create and provide `Bind_Group_Layout` objects when creating pipelines and bind
groups. This gives you full control over resource bindings and makes the relationship between
shaders and resources explicit.

```odin
// 1. Create the bind group layout first
bind_group_layout := gpu.device_create_bind_group_layout(
    device,
    {
        label = "My Bind Group Layout",
        entries = {
            {
                binding = 0,
                visibility = {.Vertex},
                type = gpu.Buffer_Binding_Layout {
                    type = .Uniform,
                    has_dynamic_offset = false,
                    min_binding_size = size_of(la.Matrix4f32),
                },
            },
        },
    },
)
defer gpu.bind_group_layout_release(bind_group_layout)

// 2. Use it to create the pipeline layout
pipeline_layout := gpu.device_create_pipeline_layout(
    device,
    {
        label = "My Pipeline Layout",
        bind_group_layouts = {bind_group_layout},
    },
)
defer gpu.pipeline_layout_release(layout)

// 3. Create the render pipeline with the explicit layout
render_pipeline := gpu.device_create_render_pipeline(
    device,
    {
        label = "My Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            // vertex state configuration
        },
        // ... rest of pipeline descriptor
    },
)

// 4. Later, create bind groups using the same layout
uniform_bind_group := gpu.device_create_bind_group(
    device,
    {
        layout = bind_group_layout,  // Same layout used for pipeline
        entries = {
            // actual resource bindings
        },
    },
)
```

## Examples

Explore [all examples](./examples) to see the implementation in action.

## Contributing

Contributions and feedback are always welcome!

[Odin Language]: https://odin-lang.org/
[WebGPU]: https://www.w3.org/TR/webgpu/
[renderlink]: https://github.com/Capati/renderlink/
