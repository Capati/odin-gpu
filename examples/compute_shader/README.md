# Compute Shader

The first example to use compute. A compute pass integrates a particle field in
an in-place storage buffer, and a render pass then draws that buffer as
instanced quads in the same frame — no vertex buffer, no readback.

This exercises the paths that no other example reaches:

- compute pipeline creation (`device_create_compute_pipeline`)
- `command_encoder_begin_compute_pass` + `compute_pass_dispatch_workgroups`
- a **read/write** storage buffer binding (`Buffer_Binding_Type.Storage`)
- the compute-to-vertex barrier the tracker emits between the two passes
- two bind groups over the same buffers with different layouts

## Two layouts, one buffer

A read/write storage buffer may not be visible from the vertex stage unless the
device has `Vertex_Writable_Storage` (WebGPU validates this in
`vk_bind_group_layout.odin`). The compute shader needs read/write; the render
pipeline only reads. So the example creates two layouts over the same buffers:

| Pipeline | Binding 1 type       | Visibility |
| -------- | -------------------- | ---------- |
| Compute  | `.Storage`           | `.Compute` |
| Render   | `.Read_Only_Storage` | `.Vertex`  |

## Simulation

`compute_shader.comp.slang` advances each particle by its velocity, reflects it
off the unit square, then applies a swirl plus damping. The field is initialized
on a golden-angle spiral so the swirl has structure to act on.

Colors come from the position the compute pass produced, brightness from speed —
both outputs of the simulation are visible at a glance.

## Shaders

`compute_shader.comp.slang` uses the new `.comp.slang` naming, which
`build_shader.bat|sh` compiles as a compute stage (`-entry cs_main`). Before this
example the shader driver only understood `.vert.slang` and `.frag.slang`.

## Running

```shell
build.bat|sh compute_shader run
```

## Screenshot

![Compute Shader](compute_shader.png)

## Ref

- https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/compute_shader.c
- https://webgpufundamentals.org/webgpu/lessons/webgpu-compute-shaders.html
