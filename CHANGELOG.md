# Changelog

## [18/11/2026]

### Added

- `tests/cts/`: Conformance suite covering the public API rules.
- `tests/bench/`: Headless benchmark suite, reporting draw and submit costs.
- `tools/`: Benchmark and allocation harnesses, plus the backend performance checklist.
- `tests/harness/`: Paced harness for running the examples and checking they keep advancing frames.

### Changed

- `gpu/tracker.odin`: render passes now record what they do to their attachments, so a discarded
  store no longer reads as defined, and a texture rendered to and then sampled is no longer cleared
  again before use.
- `gpu/tracker.odin`: a copy that fills only part of a subresource clears the rest instead of
  recording it as defined.
- `README.md`: documents the thread-safety contract for the public API.

#### Vulkan

- Fixed an out-of-bounds read in the tracker's metadata lookups.
- Image usage is derived through the tracker, so a texture no longer gains attachment usage unless
  it was created with it.

#### Examples

- Removed the scripted measurement mode from `render_bundles`; the headless benchmark suite is the
  measurement path now.

#### Fixes

- Fixed the README project structure and the archived backend path, which named `gpu/parked/`
  instead of `gpu/stash/`.

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
- Archived the previous implementation at `gpu/stash/vulkan_bk.odin` for reference.
- Made the backend thread-safe: tracker, staging-ring, label, error-scope and query-set locks;
  submission-ordered device-state merges; per-slot command pools for parallel encoders; and
  generation-checked command-buffer handles so a late release cannot cancel a reused slot.
- Queued writes hold their destination until the flush records it, so releasing a buffer or texture
  right after `queue_write_*` is safe.
- Collapsed deferred-write bookkeeping into two recycled flush batches: one tagged temporary list,
  dense per-tracker-index destination arrays with presence bitsets, and one spare batch instead of
  per-array spare twins. The mechanism is Vulkan-only (`vk_deferred_writes.odin` is `!js`), so the
  shared queue impl and the WebGPU build no longer see staging-ring types and no js stub is needed.
- Added `tests/vulkan/vk_thread_safety_tests.odin` and the `threaded_upload` example.
- `vk_submit_context_drain_refs`: removed `VK_RECLAIM_BATCH_CAP`. The bound assumed a command
  buffer touches only a handful of distinct resources, but nothing in WebGPU caps binds per pass —
  a scene binding one group per draw drains thousands of refs from one finished buffer, which the
  `render_bundles` example does at 5000 asteroids. The per-pass resource usage is unbounded and reclaimed on command-buffer destruction.
- Added the `render_bundles`, `occlusion_query`, `timestamp_query`, `game_of_life`,
  `compute_shader`, and `threaded_upload` examples.
- `render_pass_execute_bundles` no longer re-validates what the bundle already validated at
  record time. A bundle now tallies its resource usage while it is encoded
  (`Render_Bundle_Scope`, which existed unused), and executing it merges that tally into the
  pass scope once before replaying the commands, skipping the per-binding offset checks and the
  usage merge — the same split between recording and bundle execution.
  Draw-time validation against the pipeline (bind-group completeness, vertex slots, vertex and
  index ranges) is deliberately still performed, because the encoder never made those checks.
  Executing a bundle used to record ~2x slower than issuing the commands directly; it is now
  ~1.2-1.4x faster (1000: 430µs vs 606µs, 5000: 1992µs vs 2564µs, release, RTX 3060).
- `wasm/webgpu.js`: `webgpuRenderBundleEncoderSetVertexBuffer` and
  `webgpuRenderBundleEncoderSetIndexBuffer` passed `size` through `unwrapBigInt`, which rejects
  the `WHOLE_SIZE` sentinel (u64 -1) with "Value is outside the 'unsigned long long' value
  range". The render-pass equivalents already used `toOptionalSize64`; both bundle paths now do
  too. Previously any render bundle that bound a buffer with `WHOLE_SIZE` could not execute on
  the web.

#### WebGPU (WASM)

- **JSPI:** Browser-side asynchronous calls still use JavaScript promise callbacks. Blocking on
  these calls from WASM via JSPI.
- Updated `webgpu.js` to respect the current memory layout instead of assuming a C-like layout.
- Moved server-related files from `build/` to `wasm/`.

#### D3D11, D3D12, Metal, and OpenGL

- Moved these backends to `gpu/parked/` until the Vulkan backend is stable enough to support
  further backend development.
