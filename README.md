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

Currently I'm working on [renderlink][] as a "proof of concept" for this library.

## Status

> [!WARNING]
> **This project is extremely work-in-progress.**. Until the API is stabilized, break
> changes can happen without notice.

## Overview

The current goal is to follow the WebGPU specification closely, using it as a foundation for a
modern API. However, it`s not intended to be a strict clone of the spec, if something doesn't fit
well with the intended usage, we'll change it.

The early API stages will probably match WebGPU pretty closely. Over time, naming, structure, and
even core concepts may shift as things stabilize for better patterns. A future refactor is not only
possible, it's expected.

## Backends

| Feature | Status | Notes |
|---------|--------|-------|
| **Core API** |
| Core API Layout | In Progress | Basic types exist, API not yet stable |
| **Backends** |
| Vulkan     | In Progress | Should be the main backend, requires 1.3 |
| DirectX 12 | Not Started | Windows support |
| DirectX 11 | In Progress | Fallback Windows support, requires 11.1 |
| Metal      | Not Started | Might rely on MoltenVK first |
| OpenGL     | In Progress | Fallback backend on Linux and Windows, requires 4.5 |
| WebGPU     | In Progress | WASM support |
| WebGL     | Not Started | Fallback WASM support, limited features |
| **Advanced** |
| Bindless    | TODO | |
| Ray Tracing | TODO | |

## Installation

Just copy or clone this repository to your dependencies folder.

```text
├── build          # Examples output folder
├── examples       # Collection of examples to show usage
├── libs           # External dependencies
│   ├── d3d12ma    # Memory allocator for the D3D12 backend
│   ├── egl        # Bindings to EGL on Linux for the OpenGL backend
│   └── vma        # Memory allocator for the Vulkan backend
├── shared         # Code reused across multiple packages
├── utils          # Additional renderer and utility packages
│   ├── microui    # Micro UI renderer
│   └── tobj       # OBJ loader
└── wasm           # WebGPU support
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
defer gpu.release(bind_group_layout)

// 2. Use it to create the pipeline layout
pipeline_layout := gpu.device_create_pipeline_layout(
    device,
    {
        label = "My Pipeline Layout",
        bind_group_layouts = {bind_group_layout},
    },
)
defer gpu.release(pipeline_layout)

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
