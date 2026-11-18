# CTS port

WebGPU CTS rows ported from C3's `test/cts/` (which in turn ports the WebGPU
CTS and Dawn validation tables).

Run it normally; the process-wide loader and proc tables are thread-safe, so the
runner may use as many threads as it likes:

```
odin test tests/cts
```

Add `-define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true` to turn tracked leaks into
failures; that is the gate used here.

Validation refusals are delivered through the device's uncaptured-error
callback (`Device_Descriptor.uncaptured_error_callback_info`); creation entry
points report and return an invalid handle instead of aborting. The helpers in
`helpers.odin` count those reports and assert the CTS outcome.

Ported so far:

- `buffer/create.spec.ts`: size, maxBufferSize, usage pairs, new core usages,
  invalid/OOM rows.
- `buffer/destroy.spec.ts`: all core usages, destroy twice.
- `buffer/mapping.spec.ts`: mapAsync usage/state/ranges/alignment, getMappedRange
  state/alignment/OOB, unmap state machine (15 cases).
- `query_set/create.spec.ts`: count bound (0, 4096, 4097) for occlusion and
  timestamp sets.
- `query_set/destroy.spec.ts`: destroy twice.
- `texture/destroy.spec.ts`: destroy and destroy twice.
- `create_texture/createTexture.spec.ts`: zero size/usage, dimension/format,
  mip bounds, sample counts, size limits, usages, view formats, compressed.
- `create_texture/createView.spec.ts`: format, dimension, aspect, array layers,
  mips, cube squareness, texture state and view usage.
- `limits`: limit invariants, maxBufferSize, texture dimension 1D/2D/3D, array
  layers.
- `encoding/cmds/clearBuffer.spec.ts`: buffer state/usage, default args, size and
  offset alignment, overflow and bounds.
- `encoding/cmds/copyBufferToBuffer.spec.ts`: state, device, usage, range
  alignment/overflow/OOB and same-buffer refusal.
- `encoding/queries/resolveQuerySet.spec.ts`: set/buffer state and device, query
  range, destination usage, 256-byte alignment and bounds.
- `encoding/queries/general.spec.ts` + `begin_end.spec.ts`: set type/state, query
  index, begin/end balance and nesting, one slot per pass.
- `encoding/cmds/copyTextureToTexture.spec.ts`: state, device, usage, format and
  sample compatibility, mips, rectangles, layers and compressed block alignment.
- `encoding/cmds/debug.spec.ts`: debug-group balance on command encoders, render
  passes, compute passes and bundles; labels and markers of any content.
- `image_copy/buffer_texture_copies.spec.ts`: buffer/texture state, device,
  usage, sample count, `bytesPerRow` alignment, the depth/stencil aspect matrix,
  and the depth/stencil buffer-size/offset tables (copy and `writeTexture`). The
  optional `depth32float-stencil8` feature row is not enabled.
- `texture/bgra8unorm_storage.spec.ts` + `float32_filterable.spec.ts`: storage
  usage/layout gating for `bgra8unorm`, and filterable vs unfilterable 32-bit
  float bindings. Feature arms run when the adapter offers the feature.
  `rg11b10ufloat_renderable.spec.ts` remains open (needs render-pipeline
  validation).
- `encoding/cmds/render/setPipeline.spec.ts`: live vs empty pipelines and device
  mismatch on both render encoder kinds.
- `render_pass/render_pass_descriptor.spec.ts`: attachment presence, color vs
  depth formats, same size/sample count, one mip level and one layer per view,
  resolve-target shape/format/usage, depth/stencil load-store pairing, the
  depth clear-value range, depth/stencil sample-count agreement, transient
  attachments (clear/discard only), and the pass's timestamp/occlusion set rules.
- `render_pass/attachment_compatibility.spec.ts`: pass vs bundle color
  format/count, sample count, depth presence/format, bundle device ownership,
  and the same comparison against render-pipeline targets at `setPipeline`,
  including depth/stencil read-only aspects.
- `render_pass/resolve.spec.ts`: multisampled source, single-sampled target,
  exact format match, one mip/layer, size match, and render-usage/no-transient
  target rules.
- `encoding/beginRenderPass.spec.ts`: every color/resolve/depth view, occlusion
  set and timestamp set must belong to the pass's device.
- `render_pipeline/` state files: depth/stencil format and aspect rules,
  depth-compare/optional-write rules, depth-bias topology, sample-count,
  alpha-to-coverage, float32 blending and unclipped depth.
- `bind_group/createBindGroup.spec.ts`: entry count/kind, buffer usage/
  alignment/range/min-size, texture usage/dimension/sample-type/multisampling,
  sampler comparison type, storage-texture shape, destroyed resources and
  device ownership. Effective-binding-size rows remain open.
- `bind_group/createBindGroupLayout.spec.ts`: unique in-budget bindings,
  non-empty visibility, per-stage resource budgets, dynamic-offset budgets,
  vertex-stage write restrictions, storage-texture dimension/format/access,
  multisampled texture shape and binding-type presence.
- `bind_group/createPipelineLayout.spec.ts` rules: per-stage budgets across
  layouts, pipeline-wide dynamic budgets, null layout slots, group count and
  device ownership.
- `capability/texture_formats.spec.ts` (partial): optional formats are refused
  by texture, view-format, storage-layout, pipeline-depth and bundle-depth entry
  points until the feature is requested, and accepted with it; 3D compressed
  textures require the sliced-3D feature. `R64_Uint` is not in this API's
  format set.
- `limits/` creation rules: per-stage resource budgets, dynamic buffer budgets,
  `maxBindGroups`, `maxBindingsPerBindGroup`, uniform/storage binding sizes,
  buffer-offset alignments, vertex attribute/stride budgets, color attachment
  count and bytes-per-sample budgets and compute workgroup limits, on devices
  with requested small limits.
- `encoding/cmds/compute_pass.spec.ts`: pipeline liveness/device, per-dimension
  dispatch budgets, and indirect dispatch buffer state/device/usage/alignment/
  bounds.
- `encoding/beginComputePass.spec.ts`: timestamp writes require a live timestamp
  set on this device, with distinct in-range slots; other query types are
  refused.
- `encoding/cmds/render/setVertexBuffer.spec.ts`: slot budget, buffer
  state/usage/device, 4-byte offset alignment and the binding range on both
  encoder kinds.
- `encoding/cmds/render/draw.spec.ts`: strip index-format matching (including
  pipeline/index dirtying), host index-range bounds, vertex/instance-rate
  ranges, unused small bindings and shared buffers across slots. The CTS's
  `maxDrawCount` rows have no counterpart in this API's descriptor.
- `encoding/cmds/render/indirect_draw.spec.ts`: indirect buffer state/usage/
  device, 4-byte offset alignment and 16/20-byte argument fit, on both encoder
  kinds.
- `encoding/cmds/render/setIndexBuffer.spec.ts`: buffer state/usage/device,
  offset alignment to the index size, and the binding range on both render
  encoder kinds.
- `encoding/render_bundle.spec.ts`: `executeBundles` device ownership, color
  formats/count/order, depth format, per-aspect read-only state and sample
  count against the pass; empty bundle lists are accepted.
- `encoding/createRenderBundleEncoder.spec.ts`: attachment count, the
  bytes-per-sample budget (with per-format alignment), at least one attachment,
  renderable color/depth formats and the depth/stencil read-only combinations.
- `encoding/cmds/setBindGroup.spec.ts`: group device ownership, the
  `max_bind_groups` slot budget, and dynamic offset count/alignment/range on
  compute, render and bundle encoders (including offsets passed for a layout
  with no dynamic binding).
- `texture/destroy.spec.ts`: destroying a texture twice stays valid, and a
  destroyed color/depth/stencil attachment is refused (recorded work is refused
  again at submit if the texture dies after encoding).
- `encoding/encoder_open_state.spec.ts`: commands on a finished command encoder,
  an ended render/compute pass, or a finished render bundle encoder are refused,
  including debug markers/groups; this port also reports an orphan
  `popDebugGroup` on every encoder kind.
- `encoding/pipeline_bindgroup.spec.ts`: every non-empty pipeline-layout slot
  needs a bound group at draw/dispatch, layouts are compared by definition
  (bindings, visibility, resource class, dynamic-offset flag), empty/null child
  layouts require no groups, and extra slots are ignored. Bundles are checked as
  a whole before replay.
- `encoding/encoder_state.spec.ts`: refused begins return invalid-pass
  tombstones, ending an invalid pass poisons the encoder for `finish`, out-of-
  order ends report, ending an ended pass twice reports without poisoning, and an
  unpopped debug group at a valid pass end poisons it.
- `resource_usages/buffer/in_pass_encoder.spec.ts` and `in_pass_misc`: a
  compute pass records one usage scope per dispatch, so setting conflicting
  groups without dispatching is legal and each dispatch re-validates a fresh
  scope; a render pass has one whole-pass scope (including vertex/index
  bindings and bindings made after a draw), usage is per buffer rather than per
  range, two passes use separate scopes, and a draw only reads the group slots
  its pipeline layout declares.
- `resource_usages/texture/in_render_common.spec.ts` and `in_render_misc`
  (complete): one texture subresource cannot be attached twice in a pass, a
  rendered cell conflicts with a sampled or storage view that reaches the same
  mip/layer/aspect, read-only aspects and read-only sampling agree, and sampled
  and storage bindings conflict only when their subresources overlap. Replacing
  a group at the same slot does not erase its earlier use; render passes scope
  even groups the pipeline does not declare or a bundle binds, while a compute
  dispatch scopes only declared slots and only when it dispatches. Copies and
  passes use separate scopes, and a narrowed view's usage decides whether a
  binding or attachment is legal.
- `queue/destroyed/texture.spec.ts`: a destroyed texture is refused by
  `writeTexture`, buffer↔texture/texture↔texture copies, bind-group resources on
  compute/render/bundle encoders, and render-pass color/resolve/depth
  attachments. A refused submission releases the refs its command buffer took.
- `queue/destroyed/buffer.spec.ts`: a destroyed buffer is refused by
  `writeBuffer`, buffer↔buffer and buffer↔texture copies, bind-group resources,
  vertex/index bindings on render passes and bundles, and query resolves.
- `queue/destroyed/query_set.spec.ts`: a destroyed query set is refused as an
  occlusion set in a pass (used or unused), a timestamp set on render/compute
  passes, and a resolve source, either while recording or at submit.
- `queue/buffer_mapped.spec.ts`: a mapped, pending or mapped-at-creation buffer
  refuses `writeBuffer` and submissions (buffer↔buffer, buffer↔texture); the map
  state is checked at submit, so recording while mapped and unmapping before
  submit is legal.
- `encoding/cmds/render/dynamic_state.spec.ts`: viewport extent, depth-range
  and coordinate bounds, scissor bounds against the attachment, and the
  unconstrained blend-constant/stencil-reference setters.
- `encoding/cmds/render/state_tracking.spec.ts`: vertex bindings are pass
  state; every slot a pipeline declares must be bound at draw, bindings survive
  pipeline switches, and they do not cross passes.
- `encoding/cmds/index_access.spec.ts`: `firstIndex + indexCount` against the
  bound index buffer, zero-sized buffers and 32-bit overflow.
- `image_copy/layout_related.spec.ts`: rowsPerImage, offset and bytesPerRow
  bounds/alignment, required-bytes boundaries, u64 overflow, empty copies and
  `writeTexture` layout rows.

- `image_copy/buffer_related.spec.ts`: buffer state/device/usage and the
  bytesPerRow alignment split between command copies (256-byte pitch) and host
  writes (no pitch alignment).
- `encoding/cmds/copyTextureToTexture.spec.ts` and `image_copy/copy_texture.spec.ts`:
  resource state/device, mip ranges, usage, sample counts, multisampled
  full-subresource copies, format/aspect compatibility, per-side ranges,
  same-texture overlap, depth/stencil whole-subresource coverage, and compressed
  block alignment for origins, sizes and mip bounds.
- `queue/destroyed/buffer.spec.ts`, `query_set.spec.ts`, `texture.spec.ts`,
  `queue/buffer_mapped.spec.ts` and `buffer/destroy.spec.ts`: submit-time
  destroyed/mapped-resource rules, queue-write refusals, and destroying mapped
  buffers.

The full C3 CTS module set is ported (351 test functions).

Upstream additions:

- `api/validation/queue/writeBuffer.spec.ts`: buffer state/device/COPY_DST
  usage, byte-range bounds and 4-byte alignment. The port's host-write API is
  byte-oriented, so the CTS's typed-array element offsets are byte offsets here.
- `api/validation/queue/writeTexture.spec.ts`: valid/destroyed/invalid textures,
  device ownership, COPY_DST usage and single-sample enforcement.
- `api/validation/queue/submit.spec.ts`: command-buffer device ownership,
  duplicate entries, and invalidation after any submit, including refused ones.
- `api/validation/createSampler.spec.ts`: Lod clamp ordering/non-negativity and
  anisotropy requiring linear filters. Zero anisotropy is this API's unset
  value, so the CTS's explicit-zero row is not expressible.
- `api/validation/createPipelineLayout.spec.ts`: layout count, device
  ownership, null/empty layouts, the dynamic-buffer budget and immediate-data
  size. The two WGSL-reflection rows are omitted.
- `api/validation/compute_pipeline.spec.ts`: basic creation, empty modules, and
  shader-module/pipeline-layout device ownership. WGSL override/limits/resource
  rows need a shader frontend.
- `api/validation/getBindGroupLayout.spec.ts`: bind-group index range on an
  explicit layout. Auto-layout and JS-object identity rows are not applicable.
- `queue/copyToTexture/CopyExternalImageToTexture.spec.ts` is not applicable:
  this port has no external-image source API.
- `api/validation/error_scope.spec.ts`: matching/non-matching filters, empty
  stacks, parent/current scope resolution, and balanced sibling/nested stacks.
- `api/validation/render_pipeline/{misc,shader_module}.spec.ts`: the attachment
  requirement, vertex-only pipelines, invalid shader modules and
  shader-module/pipeline-layout device ownership. Reflection-dependent rows are
  omitted.
- `api/validation/render_pipeline/fragment_state.spec.ts`: color targets must be
  renderable color formats, the target count is capped by
  `max_color_attachments`, blending requires a blendable format, and zero
  targets are allowed with a depth attachment. Shader-output compatibility rows
  need a shader frontend.
- `api/validation/render_pipeline/vertex_state.spec.ts`: buffer/attribute count
  limits, stride bounds and 4-byte alignment, shader-location bounds and
  uniqueness, attribute offset alignment, and containment inside the stride.
  Shader-input compatibility rows need a shader frontend.
- `api/validation/render_pipeline/float32_blendable.spec.ts`: blending
  r32/rg32/rgba32float targets with and without the feature, for all three
  formats.
- `api/validation/capability_checks/features/query_types.spec.ts`: timestamp
  query sets and compute/render timestamp writes require the feature; occlusion
  sets do not.
