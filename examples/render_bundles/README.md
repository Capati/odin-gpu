# Render Bundles

A ring of asteroids orbiting a planet, drawn one draw call at a time. That is
deliberately wasteful — instancing would collapse the whole ring into a single
call — because the point is to show the cost of *issuing* thousands of commands
and then let you toggle the cheaper path on and off.

The same scene-recording code drives both paths:

- **Bundle** — recorded once into a `Render_Bundle` and replayed each frame with
  `render_pass_execute_bundles`.
- **Manual** — the identical command sequence recorded straight into the pass.

Switching modes changes nothing on screen; the `record:` readout shows the CPU
time each path spends recording the scene.

## Render bundles

A render bundle is an immutable, pre-recorded sequence of render commands. It can
hold a pipeline, bind groups, vertex and index buffers, draws, indirect draws and
debug groups — but nothing that reads back state, and nothing whose target changes
between uses.

Because the command list is fixed at `render_bundle_encoder_finish`, anything that
changes what is *drawn* (rather than what the bound buffers contain) means encoding
a new bundle. Moving the asteroid slider here does exactly that. Frustum or
occlusion culling, where the draw list differs every frame, does not benefit from
bundles for the same reason.

## What this example found

This is the first code in the repo to execute a render bundle. The CTS tests only
validate bundle *descriptors* (device mismatch, colour and depth formats,
read-only attachments, sample counts, empty lists); none of them ever ran one.

**1. The reclaim-batch bound was wrong, and this example tripped it.**
`vk_submit_context_drain_refs` asserted that one purge reclaims at most
`MAX_COMMAND_BUFFERS * VK_MAX_SWAPCHAIN_IMAGES` (1024) resource references. That
assumes a command buffer touches only a handful of distinct resources. Nothing in
WebGPU caps binds per pass, and this scene binds one group per draw, so at 5000
asteroids the assertion fires. The assert has been removed; the arrays are pooled
and cleared each purge, so their capacity settles at the high-water mark of the
application's own per-frame resource count.

**2. Bundle execution re-validated everything, which inverted its purpose.**
`vk_render_pass_execute_bundles` replayed the bundle's recorded commands through
the fully validating public setters — every `set_bind_group` re-ran the offset
checks and `usage_scope_merge_bind_group`, every `set_pipeline` re-checked
attachment compatibility, every draw re-validated bind-group completeness and
vertex/index ranges. A bundle therefore paid validation *twice* and was measurably
slower than issuing the same commands directly.

The fix is to tally the bundle's resource usage while it is encoded and merge that
whole tally into the pass scope in one step at execution, then replay with the
per-binding re-validation skipped. `Render_Bundle_Scope` and
`usage_scope_merge_render_bundle` already existed for exactly this and had never
been called.

What is deliberately *not* skipped is draw-time validation against the pipeline —
whether every set the layout declares has a group, whether every declared vertex
slot is bound, and whether the draw stays inside those bindings. The bundle
encoder never made those checks (it only validates ranges as buffers are bound),
so skipping them on replay would silently accept draws the spec requires to be
rejected. The CTS caught this: `cts_pipeline_bindgroup_mismatch` and
`cts_pipeline_bindgroup_equivalence_buffer` both failed until the checks were
restored.

## Measurement

The timed region runs from the first scene command through `queue_submit`, so the
number covers recording plus the submit path. The microui overlay is excluded by
subtracting its own measured time — it sits inside the render pass, so it cannot
be excluded by moving a timestamp.

Fitting `t(n) = a + b·n` over several draw counts splits the per-frame cost into a
fixed part and a per-draw part. Release build, Vulkan, RTX 3060, 1200 frames x
4 runs x 6 counts, interleaved with alternating order:

| path | per-draw `b` | fixed `a` | R2 |
| --- | --- | --- | --- |
| bundle | 0.219 μs | 121 μs | 0.998 |

The manual path measured 0.700 μs/draw in an earlier 600-frame sweep. The bundle
row is the post-C9 value: the C9 batch gave the bundle its own compact replay
stream with pre-resolved impls, moved the resource references to one per bundle,
and collapsed the draw-time layout comparison to an identity check, taking it from
0.401 to 0.219 μs/draw. The sweep's point spreads were 5.2–9.9% (above the 5%
gate, under light operator activity), but the fit is tight and independent
confirm runs read 0.223, so the number is quoted with that disclosure.

### Where the per-draw cost goes, measured

`SHARED_BINDS` (`-define:SHARED_BINDS=true`) runs the identical draw count but
points every draw at the planet's bind group, vertex buffer and index buffer, so
the per-draw binds are redundant. The delta from the normal scene splits the
per-draw cost into the part spent *deriving* binds and the *residual* —
everything else a draw costs: dispatch, validation, bookkeeping. 5000 asteroids,
bundle path, 1200 frames x 5 runs:

| | normal | `SHARED_BINDS` | derivation | residual |
| --- | --- | --- | --- | --- |
| bundle | 1202 μs* | 623 μs** | 579 μs (0.116 μs/draw) | 0.100 μs/draw |

\* count-sweep n=5000 median, spread 9.3%.
\** shared re-take, spread 16.6% — above the gate, with the machine under light
activity. The decomposition is therefore **indicative only** and should be
re-taken on a quiet machine; the pre-C9 pair measured 2117 / 947 μs.

C9 re-shaped both buckets:

1. **The derivation bucket halved, 0.234 → ~0.116 μs/draw.** Pre-resolved group,
   pipeline and buffer impls removed the per-draw handle probes, and the layout
   identity check removed the per-draw equivalence walk. What is left is mostly
   the draw-time state validation a bundle cannot fully precompute, because pass
   state can disturb slots outside it.
2. **The residual fell 0.164 → ~0.100 μs/draw.** The compact replay stream, the
   shared state-update tails and the single bundle reference account for that.
3. **The remaining cost is submit-side and flush work, not bind derivation.**
   The profile puts the largest named in-exe items in the submit path
   (`vk_submit_context_submit_extra`, usage folding, the init-action drain) and
   the flush, not in replay.

A render bundle cannot reduce GPU-side command count for a scene like this. What
it can save is CPU time spent *deriving* those commands. The redundant-bind
pruning that predates all of this remains correct: it is why a repeated bind
costs no driver call.

## Measurement hygiene

Two environmental effects dominate the noise:

1. **Display power-off.** When the machine is left unattended long enough for the
   display to power off (or the workstation to lock), DWM throttles composition
   to ~24 Hz, the frame loop stops being vsync-paced, and submit-path cost
   inflates by ~25%. Throttled runs are also slow in wall clock, which is how the
   harness detects them: runs exceeding 1.4x the vsync expectation are discarded,
   a configuration whose every run lost pacing is aborted, and the display is held
   awake for the session.
2. **Operator activity.** The same count can measure 21% spread while the operator
   works and 2.3% with the machine unattended and the display held on. Only the
   pacing and load gates remain; they measure causes, not proxies.

Every run is stamped with wall-clock UTC and processor load at its start; runs
whose round saw the load move materially are discarded, and a configuration needs
at least three clean runs before anything is printed. A count cross-check refuses
a run whose measured draw count does not match the requested one.

## Structure

- `sphere.odin` — UV sphere generator, including the `randomness` jitter that
  roughens asteroids.
- `render_bundles.odin` — scene, bundle, and the union-based `Scene_Target` that
  lets one `record_scene` body serve both a pass and a bundle encoder.

Bind groups: group 0 holds the frame view-projection (rebound once per pass),
group 1 holds the object's model matrix plus its sampler and texture (rebound per
draw). That per-draw group is what makes the experiment meaningful — it is the
only state that varies.

Textures are generated procedurally (banded, noise-warped map for the planet;
cratered grey map for the asteroids) so the example does not depend on the asset
submodule, which has no Saturn or moon images.

The texture sits at binding 1 and the sampler at 2, matching `textured_cube`: the
GLSL path compiles the pair into a single combined `Sampler2D` at binding 1, so
the two cannot be swapped without a validation error on desktop.

## Web note

The JS bridge applied `unwrapBigInt` to the `size` argument of
`GPURenderBundleEncoder.setVertexBuffer` / `setIndexBuffer`, which throws on the
`WHOLE_SIZE` sentinel (u64 -1). The render-pass equivalents already used
`toOptionalSize64`, which maps that sentinel to `undefined`; both bundle setters
now match, so any bundle binding a buffer with `WHOLE_SIZE` works on the web.

## Running

```shell
build.bat|sh render_bundles run
```

## Screenshot

![Render Bundles](render_bundles.png)
