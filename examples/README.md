# Examples

Live WebGPU demos of every example: <https://capati.github.io/odin-gpu/>

Small examples ordered by complexity. Run any of them natively with:

```shell
build.bat|sh <name> run
```

## Table of Contents

- [Info](#info)
- [Minimal](#minimal)
- [Clear Screen](#clear-screen)
- [Hello Triangle](#hello-triangle)
- [Square](#square)
- [Blend](#blend)
- [Vertex Buffer](#vertex-buffer)
- [Coordinate System](#coordinate-system)
- [Colored Cube](#colored-cube)
- [Rotating Cube](#rotating-cube)
- [Two Cubes](#two-cubes)
- [Instanced Cube](#instanced-cube)
- [Textured Cube](#textured-cube)
- [Fractal Cube](#fractal-cube)
- [Cubemap](#cubemap)
- [3D Texture](#3d-texture)
- [Points](#points)
- [Pseudorandom Number Generation](#pseudorandom-number-generation)
- [Out-of-bounds Viewport](#out-of-bounds-viewport)
- [Stencil Triangles](#stencil-triangles)
- [Pristine Grid](#pristine-grid)
- [MicroUI](#microui)
- [ImGui Example](#imgui-example)
- [glTF Cube](#gltf-cube)
- [OBJ Model](#obj-model)
- [glTF Viewer](#gltf-viewer)

### Info

Prints the library version and the selected adapter information.

### Minimal

Minimalistic render pipeline demonstrating how to render a full-screen
colored quad.

### Clear Screen

This example shows how to set up a color target to clear the screen.

### Hello Triangle

This example shows rendering a basic triangle using a vertex buffer that
holds positions and colors.

### Square

This example shows how to render a static colored square with only using
vertex buffers.

### Blend

This example shows blending in sRGB or linear space.

### Vertex Buffer

Generates procedural triangle geometry with subdivision and renders it using
a vertex buffer. Shows how to create and upload vertex data to the GPU.

### Coordinate System

Illustrates the coordinate systems used in WebGPU. WebGPU's coordinate
systems match DirectX and Metal's coordinate systems in a graphics pipeline.
Y-axis is up in normalized device coordinate (NDC): point(-1.0, -1.0) in NDC
is located at the bottom-left corner of NDC. This example has several options
for changing relevant pipeline state, and displaying meshes with WebGPU or
Vulkan style coordinates.

### Colored Cube

This example demonstrates how to render a colored cube.

### Rotating Cube

This example shows how to bind and sample textures.

### Two Cubes

This example shows some of the alignment requirements involved when updating
and binding multiple slices of a uniform buffer. It renders two rotating
cubes which have transform matrices at different offsets in a uniform buffer.

### Instanced Cube

This example shows the use of instancing.

### Textured Cube

This example shows how to generate a texture on the GPU (a Mandelbrot
fractal, rendered into an R8_Unorm texture) and sample it onto a cube,
using a false-color gradient to visualize escape-time values.

### Fractal Cube

Renders a rotating cube that samples the previous frame, producing a fractal
feedback effect.

### Cubemap

This example shows how to render and sample from a cubemap texture.

The example uses a simplified approach: instead of rendering a cube geometry, it
draws a fullscreen triangle and uses the inverse view-projection matrix to
compute the cubemap sampling direction in the fragment shader.

This means:

- No vertex buffers needed
- No depth texture needed
- Only 3 vertices drawn instead of 36

### 3D Texture

Demonstrates 3D texture loading and generation using Perlin noise. A 3D noise
texture is procedurally generated on the CPU using fractal Perlin noise and
uploaded to the GPU as a 3D texture. The depth slice through the volume is
animated over time, showing a smoothly changing cross-section of the noise field
rendered on a lit quad.

Features:

- Procedural 3D Perlin noise generation (fractal noise with 6 octaves)
- 3D texture creation and upload (R8Unorm, 128x128x128)
- Animated depth slice through the 3D volume
- Phong lighting (diffuse + specular)
- GUI button to regenerate the noise texture
- Camera interaction (LookAt orbit) via mouse

### Points

This example shows how to render points of various sizes using a quad and
instancing.

### Pseudorandom Number Generation

An example demonstrating pseudorandom number generation on the GPU. A
32-bit PCG hash is used which is fast enough to be useful for real-time,
while also being high-quality enough for almost any graphics use-case.

A pseudorandom number generator (PRNG), also known as a deterministic random
bit generator (DRBG), is an algorithm for generating a sequence of numbers
whose properties approximate the properties of sequences of random numbers.

### Out-of-bounds Viewport

The spec doesn't let you set the viewport's values to be out-of-bounds.
Therefore, the viewport's values need to be clamped to the screen-size, which
means the viewport values can't be defined in a way that makes the viewport
go off the screen. This example shows how to render a viewport out-of-bounds.

### Stencil Triangles

This example renders two different sized triangles to display three same sized triangles, by
demonstrating the use of stencil buffers.

First it draws a small "mask" triangle, which sets the stencil buffer at every pixel to 1.

Then, it draws a larger "outer" triangle which only touches pixels where the stencil buffer is less
than 1.

### Pristine Grid

A simple WebGPU implementation of the "Pristine Grid" technique described in
this wonderful little blog post:

https://bgolus.medium.com/the-best-darn-grid-shader-yet-727f9278b9d8

### MicroUI

Renders a MicroUI user interface using the utils/microui renderer.

### ImGui Example

This example demonstrates how to use Dear ImGui to create graphical user interfaces.

### glTF Cube

Loads the first mesh primitive from a small glTF 2.0 asset through the
framework's pure-Odin glTF helper and renders its POSITION/NORMAL attributes
and indices. Materials and scene-node transforms are intentionally kept out
of this first loader example.

### OBJ Model

Loads a Wavefront OBJ model through the `tobj` utility package and renders it
with per-vertex normals and colors. The camera is a framework orbit camera: drag
to orbit, wheel to zoom.

### glTF Viewer

Instanced glTF renderer: scene graph, per-mesh instancing, animation,
preset cameras + orbit camera.

TODO:

- IBL
