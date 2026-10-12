# Changelog

## [10/12/2026]

### Added

- `gpu/` package: Core API moved out of the repository root.
- `gpu/tracker.odin`: Resource state tracking and barrier computation.
- `gpu/allocator/`: GPU memory allocation layer.
- `utils/gltf/` package based on cgltf.
- `utils/imgui/` package with a custom renderer.
- `utils/glfw/`, `utils/sdl2/`, and `utils/sdl3/` packages for surface creation helpers.
- Many more examples.
- `tests/`: Harness tests to validate specific behaviors and requirements.
- Many other tests added from:
  - gpu
  - gpu/allocator
  - gpu/small_vec
  - utils/gltf
  - utils/tobj

### Changed

- **Sync-by-default on native platforms:** Alongside the spec-style asynchronous API based on
  `request` procedures and callbacks/`Future` (e.g. `instance_request_adapter` and device
  mapping/pop error scopes), the API now exposes synchronous `create` procedures (e.g.
  `instance_create_adapter`), allowing callers to avoid callbacks.

#### Examples

- Moved example-related files into `examples/`.
- Moved assets into a submodule to keep the main repository smaller.
- Updated Sublime Text and VS Code configuration files to run the new examples.

#### Vulkan

- Rewrote the backend with initial thread-safety support.
- Split the monolithic implementation into per-area `vk_*` modules sharing a common `tracker.odin`.
- Drop the 1.3 minium version.
- Refactor deferred deletions.
- Archived the previous implementation at `gpu/parked/vulkan_bk.odin` for reference.

#### WebGPU (WASM)

- **JSPI:** Browser-side asynchronous calls still use JavaScript promise callbacks. Blocking on
  these calls from WASM via JSPI.
- Updated `webgpu.js` to respect the current memory layout instead of assuming a C-like layout.
- Moved server-related files from `build/` to `wasm/`.

#### D3D11, D3D12, Metal, and OpenGL

- Moved these backends to `gpu/parked/` until the Vulkan backend is stable enough to support
  further backend development.
