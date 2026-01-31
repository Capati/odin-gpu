# Examples

## Table of Contents

- [Info](#info)
- [Clear Screen](#clear-screen)
- [Triangle](#triangle)
- [Square](#square)
- [Blend](#blend)
- [Stencil Triangles](#stencil-triangles)
- [Cube](#cube)
- [Rotating Cube](#rotating-cube)
- [Two Cubes](#two-cubes)
- [Fractal Cube](#fractal-cube)
- [Cube Textured](#cube-textured)
- [OBJ Model](#obj-model)
- [Cubemap](#cubemap)
- [MicroUI](#microui)

## [Info](./info)

Print current version and selected adapter information.

## [Clear Screen](./clear_screen)

This example demonstrates how to clear the screen.

![Clear Screen](./clear_screen/clear_screen.png)

## [Triangle](./triangle)

This example demonstrates how to render a colored triangle with smooth color interpolation between
vertices.

![Triangle](./triangle/triangle.png)

## [Square](./square)

This example demonstrates how to render a colored square with smooth color interpolation between
vertices.

![Square](./square/square.png)

## [Blend](./blend)

This example shows blending in sRGB or linear space.

![Blend](./blend/blend.png)

## [Stencil Triangles](./stencil_triangles)

This example shows using the stencil buffer for masking.

![Stencil Triangles](./stencil_triangles/stencil_triangles.png)

## [Cube](./cube)

This example demonstrates how to render a colored cube.

![Cube](./cube/cube.png)

## [Rotating Cube](./rotating_cube)

This example shows how to upload uniform data every frame to render a rotating object.

![Rotating Cube](./rotating_cube/rotating_cube.png)

## [Two Cubes](./two_cubes)

This example shows some of the alignment requirements involved when updating and binding multiple
slices of a uniform buffer. It renders two rotating cubes which have transform matrices at
different offsets in a uniform buffer.

![Two Cubes](./two_cubes/two_cubes.png)

## [Fractal Cube](./fractal_cube)

This example uses the previous frame's rendering result as the source texture for the next frame.

![Fractal Cube](./fractal_cube/fractal_cube.png)

## [Cube Textured](./cube_textured)

This example demonstrates how to render a textured cube.

![Cube Textured](./cube_textured/cube_textured.png)

## [OBJ Model](./obj_model)

This example demonstrates how to load a `OBJ` model using tobj (tinyobjloader).

![Cubemap](./obj_model/obj_model.png)

## [Cubemap](./cubemap)

This example shows how to render and sample from a cubemap texture. 

![Cubemap](./cubemap/cubemap.png)

## [MicroUI](./microui)

This example demonstrates how to use MicroUI with a custom renderer.

![MicroUI](./microui/microui.png)
