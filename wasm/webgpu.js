(function () {
  const STATUS_SUCCESS = 1;
  const STATUS_ERROR = 2;

  const ENUMS = {
    PrimitiveTopology: ['triangle-list', 'point-list', 'line-list', 'line-strip', 'triangle-strip'],
    IndexFormat: [undefined, 'uint32', 'uint16'],
    FrontFace: ['ccw', 'cw'],
    CullMode: ['none', 'front', 'back'],
    PolygonMode: ['fill', 'line', 'point'],
    VertexStepMode: ['vertex', 'instance'],
    CompareFunction: [
      undefined,
      'never',
      'less',
      'equal',
      'less-equal',
      'greater',
      'not-equal',
      'greater-equal',
      'always',
    ],
    BlendOperation: ['add', 'subtract', 'reverse-subtract', 'min', 'max'],
    BlendFactor: [
      undefined,
      'zero',
      'one',
      'src',
      'one-minus-src',
      'src-alpha',
      'one-minus-src-alpha',
      'dst',
      'one-minus-dst',
      'dst-alpha',
      'one-minus-dst-alpha',
      'src-alpha-saturated',
      'constant',
      'one-minus-constant',
      'src1',
      'one-minus-src1',
      'src1-alpha',
      'one-minus-src1-alpha',
    ],
    LoadOp: [undefined, 'load', 'clear', 'dont-care'],
    StoreOp: [undefined, 'store', 'discard'],
    StencilOperation: [
      'keep',
      'zero',
      'replace',
      'invert',
      'increment-clamp',
      'decrement-clamp',
      'increment-wrap',
      'decrement-wrap',
    ],
    TextureAspect: ['all', 'stencil-only', 'depth-only', undefined, undefined],
    TextureViewDimension: ['2d', '1d', '2d-array', 'cube', 'cube-array', '3d'],
    AddressMode: ['clamp-to-edge', 'repeat', 'mirror-repeat', 'clamp-to-border'],
    FilterMode: ['nearest', 'linear'],
    MipmapFilterMode: ['nearest', 'linear'],
    TextureFormat: [
      undefined,
      'r8unorm',
      'r8snorm',
      'r8uint',
      'r8sint',
      'r16unorm',
      'r16snorm',
      'r16uint',
      'r16sint',
      'r16float',
      'rg8unorm',
      'rg8snorm',
      'rg8uint',
      'rg8sint',
      'r32float',
      'r32uint',
      'r32sint',
      'rg16unorm',
      'rg16snorm',
      'rg16uint',
      'rg16sint',
      'rg16float',
      'rgba8unorm',
      'rgba8unorm-srgb',
      'rgba8snorm',
      'rgba8uint',
      'rgba8sint',
      'bgra8unorm',
      'bgra8unorm-srgb',
      'rgb10a2uint',
      'rgb10a2unorm',
      'rg11b10ufloat',
      'rgb9e5ufloat',
      'rg32float',
      'rg32uint',
      'rg32sint',
      'rgba16unorm',
      'rgba16snorm',
      'rgba16uint',
      'rgba16sint',
      'rgba16float',
      'rgba32float',
      'rgba32uint',
      'rgba32sint',
      'stencil8',
      'depth16unorm',
      'depth24plus',
      'depth24plus-stencil8',
      'depth32float',
      'depth32float-stencil8',
      'bc1-rgba-unorm',
      'bc1-rgba-unorm-srgb',
      'bc2-rgba-unorm',
      'bc2-rgba-unorm-srgb',
      'bc3-rgba-unorm',
      'bc3-rgba-unorm-srgb',
      'bc4-r-unorm',
      'bc4-r-snorm',
      'bc5-rg-unorm',
      'bc5-rg-snorm',
      'bc6h-rgb-ufloat',
      'bc6h-rgb-float',
      'bc7-rgba-unorm',
      'bc7-rgba-unorm-srgb',
      'etc2-rgb8unorm',
      'etc2-rgb8unorm-srgb',
      'etc2-rgb8a1unorm',
      'etc2-rgb8a1unorm-srgb',
      'etc2-rgba8unorm',
      'etc2-rgba8unorm-srgb',
      'eac-r11unorm',
      'eac-r11snorm',
      'eac-rg11unorm',
      'eac-rg11snorm',
      'astc-4x4-unorm',
      'astc-4x4-unorm-srgb',
      'astc-5x4-unorm',
      'astc-5x4-unorm-srgb',
      'astc-5x5-unorm',
      'astc-5x5-unorm-srgb',
      'astc-6x5-unorm',
      'astc-6x5-unorm-srgb',
      'astc-6x6-unorm',
      'astc-6x6-unorm-srgb',
      'astc-8x5-unorm',
      'astc-8x5-unorm-srgb',
      'astc-8x6-unorm',
      'astc-8x6-unorm-srgb',
      'astc-8x8-unorm',
      'astc-8x8-unorm-srgb',
      'astc-10x5-unorm',
      'astc-10x5-unorm-srgb',
      'astc-10x6-unorm',
      'astc-10x6-unorm-srgb',
      'astc-10x8-unorm',
      'astc-10x8-unorm-srgb',
      'astc-10x10-unorm',
      'astc-10x10-unorm-srgb',
      'astc-12x10-unorm',
      'astc-12x10-unorm-srgb',
      'astc-12x12-unorm',
      'astc-12x12-unorm-srgb',
    ],
    VertexFormat: [
      'uint8',
      'uint8x2',
      'uint8x4',
      'sint8',
      'sint8x2',
      'sint8x4',
      'unorm8',
      'unorm8x2',
      'unorm8x4',
      'snorm8',
      'snorm8x2',
      'snorm8x4',
      'uint16',
      'uint16x2',
      'uint16x4',
      'sint16',
      'sint16x2',
      'sint16x4',
      'unorm16',
      'unorm16x2',
      'unorm16x4',
      'snorm16',
      'snorm16x2',
      'snorm16x4',
      'float16',
      'float16x2',
      'float16x4',
      'float32',
      'float32x2',
      'float32x3',
      'float32x4',
      'uint32',
      'uint32x2',
      'uint32x3',
      'uint32x4',
      'sint32',
      'sint32x2',
      'sint32x3',
      'sint32x4',
      'unorm10-10-10-2',
      'unorm8x4-bgra',
    ],
    FeatureName: [
      'depth-clip-control',
      'depth32float-stencil8',
      'texture-compression-bc',
      'texture-compression-bc-sliced-3d',
      'texture-compression-etc2',
      'texture-compression-astc',
      'texture-compression-astc-sliced-3d',
      'timestamp-query',
      'indirect-first-instance',
      'shader-f16',
      'rg11b10ufloat-renderable',
      'bgra8unorm-storage',
      'float32-filterable',
      'float32-blendable',
      'clip-distances',
      'dual-source-blending',
      'subgroups',
      'texture-formats-tier1',
      'texture-formats-tier2',
      'primitive-index',
      'texture-component-swizzle',
    ],
    BufferBindingType: [null, undefined, 'uniform', 'storage', 'read-only-storage'],
    SamplerBindingType: [null, undefined, 'filtering', 'non-filtering', 'comparison'],
    TextureSampleType: [null, undefined, 'float', 'unfilterable-float', 'depth', 'sint', 'uint'],
    StorageTextureAccess: [null, undefined, 'write-only', 'read-only', 'read-write'],
    QueryType: [undefined, 'occlusion', 'timestamp'],
    TextureDimension: [undefined, '1d', '2d', '3d'],
    ErrorType: [undefined, 'no-error', 'validation', 'out-of-memory', 'internal', 'unknown'],
    WGSLLanguageFeatureName: [
      undefined,
      'readonly_and_readwrite_storage_textures',
      'packed_4x8_integer_dot_product',
      'unrestricted_pointer_parameters',
      'pointer_composite_access',
      'uniform_buffer_standard_layout',
      'subgroup_id',
      'texture_and_sampler_let',
      'subgroup_uniformity',
      'texture_formats_tier1',
    ],
    PowerPreference: [undefined, 'low-power', 'high-performance'],
    CompositeAlphaMode: ['auto', 'opaque', 'premultiplied', 'unpremultiplied', 'inherit'],
    PresentMode: ['fifo', 'auto-vsync', 'auto-no-vsync', 'fifo-relaxed', 'immediate', 'mailbox'],
    DeviceLostReason: [undefined, 'unknown', 'destroyed', 'callback-cancelled', 'failed-creation'],
    BufferMapState: [undefined, 'unmapped', 'pending', 'mapped'],
    OptionalBool: [false, true, undefined],
    ComponentSwizzle: [undefined, '0', '1', 'r', 'g', 'b', 'a'],
    PredefinedColorSpace: [undefined, 'srgb', 'display-p3'],
    ToneMappingMode: [undefined, 'standard', 'extended'],
    FeatureLevel: [undefined, 'compatibility', 'core'],
    BackendType: [
      undefined,
      null,
      'WebGPU',
      'D3D11',
      'D3D12',
      'Metal',
      'Vulkan',
      'OpenGL',
      'OpenGLES',
    ],
    AdapterType: ['Unknown', 'Integrated_Gpu', 'Discrete_Gpu', 'Virtual_Gpu', 'Cpu'],
    RequestDeviceStatus: [undefined, 'Success', 'CallbackCancelled', 'Error'],
    MapAsyncStatus: [undefined, 'Success', 'CallbackCancelled', 'Error', 'Aborted'],
    CreatePipelineAsyncStatus: [
      undefined,
      'Success',
      'CallbackCancelled',
      'ValidationError',
      'InternalError',
    ],
    PopErrorScopeStatus: [undefined, 'Success', 'CallbackCancelled', 'Error'],
    RequestAdapterStatus: [undefined, 'Success', 'CallbackCancelled', 'Unavailable', 'Error'],
    QueueWorkDoneStatus: [undefined, 'Success', 'CallbackCancelled', 'Error'],
    CompilationInfoRequestStatus: [undefined, 'Success', 'CallbackCancelled'],
    SurfaceGetCurrentTextureStatus: [
      'Unknown',
      'Success',
      'Suboptimal',
      'Timeout',
      'Occluded',
      'Outdated',
      'Lost',
      'Validation',
    ],
  };

  /**
   * Assumptions:
   * - Ability to allocate memory, set the context to allocate with using the
   *   global `gpu.g_context`
   * - Exports a function table (for callbacks), added with
   *   `-extra-linker-flags:"--export-table"`
   *
   * @class WebGPUInterface (name)
   */
  class WebGPUInterface {
    /**
     * @param {WasmMemoryInterface} mem
     */
    constructor(mem) {
      this.mem = mem;

      this._buildSizes();

      /** @type {WebGPUObjectManager<{}>} */
      this.instances = new WebGPUObjectManager('Instance', this.mem);

      /** @type {WebGPUObjectManager<GPUAdapter>} */
      this.adapters = new WebGPUObjectManager('Adapter', this.mem);

      /** @type {WebGPUHandleManager<GPUBindGroup>} */
      this.bindGroups = new WebGPUHandleManager('BindGroup', this.mem);

      /** @type {WebGPUHandleManager<GPUBindGroupLayout>} */
      this.bindGroupLayouts = new WebGPUHandleManager('BindGroupLayout', this.mem);

      /** @type {WebGPUHandleManager<{ buffer: GPUBuffer, mapping: ?{ range: ArrayBuffer, ptr: number, size: number } }>} */
      this.buffers = new WebGPUHandleManager('Buffer', this.mem);

      /** @type {WebGPUObjectManager<GPUDevice>} */
      this.devices = new WebGPUObjectManager('Device', this.mem);

      /** @type {WebGPUHandleManager<GPUCommandBuffer>} */
      this.commandBuffers = new WebGPUHandleManager('CommandBuffer', this.mem);

      /** @type {WebGPUHandleManager<GPUCommandEncoder>} */
      this.commandEncoders = new WebGPUHandleManager('CommandEncoder', this.mem);

      /** @type {WebGPUHandleManager<GPUComputePassEncoder>} */
      this.computePassEncoders = new WebGPUHandleManager('ComputePassEncoder', this.mem);

      /** @type {WebGPUHandleManager<GPURenderPassEncoder>} */
      this.renderPassEncoders = new WebGPUHandleManager('RenderPassEncoder', this.mem);

      /** @type {WebGPUHandleManager<GPUQuerySet>} */
      this.querySets = new WebGPUHandleManager('QuerySet', this.mem);

      /** @type {WebGPUHandleManager<GPUComputePipeline>} */
      this.computePipelines = new WebGPUHandleManager('ComputePipeline', this.mem);

      /** @type {WebGPUHandleManager<GPUPipelineLayout>} */
      this.pipelineLayouts = new WebGPUHandleManager('PipelineLayout', this.mem);

      /** @type {WebGPUHandleManager<GPUQueue>} */
      this.queues = new WebGPUHandleManager('Queue', this.mem);

      /** @type {WebGPUHandleManager<GPURenderBundle>} */
      this.renderBundles = new WebGPUHandleManager('RenderBundle', this.mem);

      /** @type {WebGPUHandleManager<GPURenderBundleEncoder>} */
      this.renderBundleEncoders = new WebGPUHandleManager('RenderBundleEncoder', this.mem);

      /** @type {WebGPUHandleManager<GPURenderPipeline>} */
      this.renderPipelines = new WebGPUHandleManager('RenderPipeline', this.mem);

      /** @type {WebGPUHandleManager<GPUSampler>} */
      this.samplers = new WebGPUHandleManager('Sampler', this.mem);

      /** @type {WebGPUHandleManager<GPUShaderModule>} */
      this.shaderModules = new WebGPUHandleManager('ShaderModule', this.mem);

      /** @type {WebGPUObjectManager<HTMLCanvasElement>} */
      this.surfaces = new WebGPUObjectManager('Surface', this.mem);

      /** @type {WebGPUHandleManager<GPUTexture>} */
      this.textures = new WebGPUHandleManager('Texture', this.mem);

      /** @type {WebGPUHandleManager<GPUTextureView>} */
      this.textureViews = new WebGPUHandleManager('TextureView', this.mem);

      /** @type {WebGPUHandleManager<GPUExternalTexture>} */
      this.externalTextures = new WebGPUHandleManager('ExternalTexture', this.mem);

      this.zeroMessageAddr = 0;
    }

    _buildSizes() {
      const is = this.mem.intSize;
      this.sizes = {
        // Common
        Color: [32, 8],
        StringView: [8, 4], // Odin string (ptr, len)

        // Bind group layout union variants
        BufferBindingLayout: [16, 8],
        SamplerBindingLayout: [4, 4],
        TextureBindingLayout: [12, 4],
        StorageTextureBindingLayout: [12, 4],
        BindGroupLayoutEntry: [48, 8],
        BindGroupEntry: [48, 8],

        // Vertex / fragment / pipeline state
        ConstantEntry: [16, 8],
        VertexBufferLayout: [24, 8],
        VertexAttribute: [24, 8],
        VertexState: [48, 8],
        FragmentState: [48, 8],
        PrimitiveState: [28, 4],
        MultisampleState: [12, 4],
        StencilFaceState: [16, 4],
        ColorTargetState: [16, 8],
        BlendComponent: [12, 4],

        // Texture / copy
        TexelCopyBufferLayout: [16, 8],
        Origin3D: [12, 4],
        Extent3D: [12, 4],

        // Device / callbacks
        QueueDescriptor: [8, 4],
        DeviceLostCallbackInfo: [12, 4], // Odin Device_Lost_Callback_Info
        UncapturedErrorCallbackInfo: [12, 4],

        // Render pass
        RenderPassColorAttachment: [80, 8],

        // Other
        CallbackInfo: [4 + 3 * is, Math.min(4, is)], // TODO
        ComputeState: [8 + is * 4, is],
        CompilationMessage: [is == 8 ? 64 : 48, 8],
      };
    }

    updateIntSize(size) {
      this.mem.setIntSize(size);
      this._buildSizes();
    }

    struct(start) {
      let offset = start;

      return (size, alignment = null) => {
        if (alignment === null) {
          if (Array.isArray(size)) {
            [size, alignment] = size;
          } else {
            alignment = size;
          }
        }

        // Align the offset to the required boundary
        offset = Math.ceil(offset / alignment) * alignment;
        let currentOffset = offset;
        offset += size;

        return currentOffset;
      };
    }

    /**
     * @param {number|BigInt} src
     * @returns {number|BigInt}
     */
    uint(src) {
      if (this.mem.intSize == 8) {
        return BigInt(src);
      } else if (this.mem.intSize == 4) {
        return src;
      } else {
        throw new Error('unreachable');
      }
    }

    /**
     * @param {number|BigInt} src
     * @returns {number}
     */
    unwrapBigInt(src) {
      if (typeof src == 'number') {
        return src;
      }

      const MAX_SAFE_INTEGER = 9007199254740991n;
      if (typeof src != 'bigint') {
        throw new TypeError(`unwrapBigInt got invalid param of type ${typeof src}`);
      }

      if (src > MAX_SAFE_INTEGER) {
        throw new Error(`unwrapBigInt precision would be lost converting ${src}`);
      }

      return Number(src);
    }

    // u64-width sentinel: WHOLE_SIZE / WHOLE_MAP_SIZE / LIMIT_U64_UNDEFINED
    toOptionalSize64(src) {
      if (src === -1 || src === -1n) {
        return undefined;
      }
      return this.unwrapBigInt(src);
    }

    // u32-width sentinel: ARRAY_LAYER_COUNT_UNDEFINED, COPY_STRIDE_UNDEFINED,
    // DEPTH_SLICE_UNDEFINED, LIMIT_U32_UNDEFINED, MIP_LEVEL_COUNT_UNDEFINED,
    // QUERY_SET_INDEX_UNDEFINED
    toOptionalU32(src) {
      if (src === -1) {
        return undefined;
      }
      return src;
    }

    /**
     * @param {boolean} condition
     * @param {string} message
     */
    assert(condition, message = 'assertion failure') {
      if (!condition) {
        throw new Error(message);
      }
    }

    /**
     * @template T
     *
     * @param {number} count
     * @param {number} start
     * @param {function(number): T} decoder
     * @param {number} stride
     * @returns {Array<T>}
     */
    array(count, start, decoder, stride) {
      if (count == 0) {
        return [];
      }
      this.assert(start != 0);

      const out = [];
      for (let i = 0; i < count; i += 1) {
        out.push(decoder.call(this, start));
        start += stride;
      }
      return out;
    }

    odinEnumValue(name, value) {
      const table = ENUMS[name];
      this.assert(table, `Unknown enum ${name}`);

      // string in → ordinal out
      if (typeof value === 'string') {
        const idx = table.indexOf(value);
        this.assert(idx >= 0, `Unknown ${name} name "${value}"`);
        return idx;
      }

      // ordinal in → string out
      this.assert(
        Number.isInteger(value) && value >= 0 && value < table.length,
        `Unknown ${name} ordinal ${value}`,
      );
      return table[value] ?? undefined;
    }

    odinEnum(name, ptr) {
      return this.odinEnumValue(name, this.mem.loadI32(ptr));
    }

    /**
     * Reads a `gpu.Handle` (a `Device` pointer plus a packed u64) and resolves
     * it through a `WebGPUHandleManager`. Returns `undefined` for a null handle,
     * which is how every `Handle`-typed descriptor spells "not provided".
     *
     * @param {WebGPUHandleManager<T>} manager
     * @param {number} ptr Address of the `Handle` struct.
     * @returns {?T}
     */
    handleAt(manager, ptr) {
      const packed = manager.packedAt(ptr);
      if (packed === 0n) {
        return undefined;
      }
      return manager.get(packed);
    }

    /**
     * Reads a `gpu.rawptr`-typed handle (`Device`, `Surface`, `Adapter`,
     * `Instance`, `Query_Set`, ...) and resolves it through a
     * `WebGPUObjectManager`. Returns `undefined` when the pointer is null.
     *
     * @param {WebGPUObjectManager<T>} manager
     * @param {number} ptr
     * @returns {?T}
     */
    objectAt(manager, ptr) {
      const idx = this.mem.loadPtr(ptr);
      if (idx === 0) {
        return undefined;
      }
      return manager.get(idx);
    }

    /**
     * Reads an Odin slice (a `{ptr, len}` pair of 4-byte words).
     *
     * @param {function(function(number, number=): number): number} off
     * @returns {{ptr: number, len: number}}
     */
    readSlice(off) {
      const ptr = this.mem.loadPtr(off(4));
      const len = this.mem.loadUint(off(this.mem.intSize));
      return { ptr, len };
    }

    /**
     * Converts a `gpu.Bit_Set` (a `Flags`-backed bitset, 8 bytes on wasm32) into
     * the WebGPU bitflag number. The Odin enums are declared in the same order
     * as the WebGPU flag bits, so this is a straight reinterpretation.
     *
     * @param {number} ptr
     * @returns {number}
     */
    bitSet(ptr) {
      return Number(this.mem.loadU64(ptr));
    }

    /**
     * @param {GPUSupportedFeatures} features
     * @param {number} ptr
     */
    genericGetFeatures(features, ptr) {
      this.assert(ptr != 0);

      const CAPACITY = 72; // FEATURE_COUNT
      const LEN_OFFSET = CAPACITY * 4;

      let count = 0;
      ENUMS.FeatureName.forEach((feature, ordinal) => {
        if (feature && features.has(feature) && count < CAPACITY) {
          this.mem.storeI32(ptr + count * 4, ordinal);
          count += 1;
        }
      });
      this.mem.storeUint(ptr + LEN_OFFSET, count);
    }

    /**
     * @param {GPUSupportedLimits} limits
     * @param {number} ptr
     * @returns {number}
     */
    genericGetLimits(limits, supportedLimitsPtr) {
      this.assert(supportedLimitsPtr != 0);

      const off = this.struct(supportedLimitsPtr);
      off(4);

      this.mem.storeU32(off(4), limits.maxTextureDimension1D);
      this.mem.storeU32(off(4), limits.maxTextureDimension2D);
      this.mem.storeU32(off(4), limits.maxTextureDimension3D);
      this.mem.storeU32(off(4), limits.maxTextureArrayLayers);
      this.mem.storeU32(off(4), limits.maxBindGroups);
      this.mem.storeU32(off(4), limits.maxBindGroupsPlusVertexBuffers);
      this.mem.storeU32(off(4), limits.maxBindingsPerBindGroup);
      this.mem.storeU32(off(4), limits.maxDynamicUniformBuffersPerPipelineLayout);
      this.mem.storeU32(off(4), limits.maxDynamicStorageBuffersPerPipelineLayout);
      this.mem.storeU32(off(4), limits.maxSampledTexturesPerShaderStage);
      this.mem.storeU32(off(4), limits.maxSamplersPerShaderStage);
      this.mem.storeU32(off(4), limits.maxStorageBuffersPerShaderStage);
      this.mem.storeU32(off(4), limits.maxStorageTexturesPerShaderStage);
      this.mem.storeU32(off(4), limits.maxUniformBuffersPerShaderStage);
      this.mem.storeU64(off(8), limits.maxUniformBufferBindingSize);
      this.mem.storeU64(off(8), limits.maxStorageBufferBindingSize);
      this.mem.storeU32(off(4), limits.minUniformBufferOffsetAlignment);
      this.mem.storeU32(off(4), limits.minStorageBufferOffsetAlignment);
      this.mem.storeU32(off(4), limits.maxVertexBuffers);
      this.mem.storeU64(off(8), limits.maxBufferSize);
      this.mem.storeU32(off(4), limits.maxVertexAttributes);
      this.mem.storeU32(off(4), limits.maxVertexBufferArrayStride);
      this.mem.storeU32(off(4), limits.maxInterStageShaderVariables);
      this.mem.storeU32(off(4), limits.maxColorAttachments);
      this.mem.storeU32(off(4), limits.maxColorAttachmentBytesPerSample);
      this.mem.storeU32(off(4), limits.maxComputeWorkgroupStorageSize);
      this.mem.storeU32(off(4), limits.maxComputeInvocationsPerWorkgroup);
      this.mem.storeU32(off(4), limits.maxComputeWorkgroupSizeX);
      this.mem.storeU32(off(4), limits.maxComputeWorkgroupSizeY);
      this.mem.storeU32(off(4), limits.maxComputeWorkgroupSizeZ);
      this.mem.storeU32(off(4), limits.maxComputeWorkgroupsPerDimension);

      return STATUS_SUCCESS;
    }

    /**
     * @param {number} infoPtr
     * @param {GPUAdapterInfo} info
     */
    genericGetAdapterInfo(infoPtr, info) {
      this.assert(infoPtr != 0);

      const off = this.struct(infoPtr);

      const storeString = (start, str) => {
        const len = new TextEncoder().encode(str).length;
        const strAddr = this.mem.exports.js_alloc(len);
        this.mem.storeString(strAddr, str);

        this.mem.storeI32(start, strAddr);
        this.mem.storeUint(start + this.mem.intSize, len);
      };

      // Name
      storeString(off(this.sizes.StringView), info.device);
      off(4); // vendor
      off(4); // device
      // Device type
      this.mem.storeI32(off(4), this.odinEnumValue('AdapterType', 'Unknown'));
      // Device pci bus id
      storeString(off(this.sizes.StringView), '');
      // Driver
      storeString(off(this.sizes.StringView), info.vendor);
      // Driver info
      storeString(off(this.sizes.StringView), info.description);
      // Backend
      this.mem.storeI32(off(4), this.odinEnumValue('BackendType', 'WebGPU'));
      this.mem.storeI32(off(4), info.subgroupMinSize);
      this.mem.storeI32(off(4), info.subgroupMaxSize);

      return STATUS_SUCCESS;
    }

    /**
     * @param {number} ptr
     * @returns {GPUFeatureName}
     */
    FeatureNamePtr(ptr) {
      return this.FeatureName(this.mem.loadI32(ptr));
    }

    /**
     * @param {number} featureInt
     * @returns {GPUFeatureName}
     */
    FeatureName(featureInt) {
      return ENUMS.FeatureName[featureInt];
    }

    /**
     * @param {number} ptr
     * @returns {GPUSupportedLimits}
     */
    RequiredLimitsPtr(ptr) {
      const start = this.mem.loadPtr(ptr);
      if (start == 0) {
        return undefined;
      }

      return this.Limits(start);
    }

    /**
     * @param {number} start
     * @return {GPUSupportedLimits}
     */
    LimitsInline(off) {
      const limitU32 = (ptr) => {
        const value = this.mem.loadU32(ptr);
        return value === 0 || value === 0xffffffff ? undefined : value;
      };

      const limitU64 = (ptr) => {
        const lo = this.mem.loadU32(ptr);
        const hi = this.mem.loadU32(ptr + 4);
        if ((lo === 0 && hi === 0) || (lo === 0xffffffff && hi === 0xffffffff)) return undefined;
        return Number(this.mem.loadU64(ptr));
      };

      let out = {
        maxTextureDimension1D: limitU32(off(4)),
        maxTextureDimension2D: limitU32(off(4)),
        maxTextureDimension3D: limitU32(off(4)),
        maxTextureArrayLayers: limitU32(off(4)),
        maxBindGroups: limitU32(off(4)),
        maxBindGroupsPlusVertexBuffers: limitU32(off(4)),
        maxBindingsPerBindGroup: limitU32(off(4)),
        maxDynamicUniformBuffersPerPipelineLayout: limitU32(off(4)),
        maxDynamicStorageBuffersPerPipelineLayout: limitU32(off(4)),
        maxSampledTexturesPerShaderStage: limitU32(off(4)),
        maxSamplersPerShaderStage: limitU32(off(4)),
        maxStorageBuffersPerShaderStage: limitU32(off(4)),
        maxStorageTexturesPerShaderStage: limitU32(off(4)),
        maxUniformBuffersPerShaderStage: limitU32(off(4)),
        maxUniformBufferBindingSize: limitU64(off(8)),
        maxStorageBufferBindingSize: limitU64(off(8)),
        minUniformBufferOffsetAlignment: limitU32(off(4)),
        minStorageBufferOffsetAlignment: limitU32(off(4)),
        maxVertexBuffers: limitU32(off(4)),
        maxBufferSize: limitU64(off(8)),
        maxVertexAttributes: limitU32(off(4)),
        maxVertexBufferArrayStride: limitU32(off(4)),
        maxInterStageShaderVariables: limitU32(off(4)),
        maxColorAttachments: limitU32(off(4)),
        maxColorAttachmentBytesPerSample: limitU32(off(4)),
        maxComputeWorkgroupStorageSize: limitU32(off(4)),
        maxComputeInvocationsPerWorkgroup: limitU32(off(4)),
        maxComputeWorkgroupSizeX: limitU32(off(4)),
        maxComputeWorkgroupSizeY: limitU32(off(4)),
        maxComputeWorkgroupSizeZ: limitU32(off(4)),
        maxComputeWorkgroupsPerDimension: limitU32(off(4)),
        maxImmediateSize: limitU32(off(4)),
      };
      off(4); // maxNonSamplerBindings
      off(4); // maxBindingArrayElementsPerShaderStage
      off(4); // maxBindingArraySamplerElementsPerShaderStage
      off(4); // maxMultiviewViewCount
      return out;
    }

    Limits(start) {
      return this.LimitsInline(this.struct(start));
    }

    /**
     * @param {number} start
     * @returns {GPUQueueDescriptor}
     */
    QueueDescriptor(start) {
      return {
        label: this.StringView(start),
      };
    }

    /**
     * @param {number} ptr
     */
    PassTimestampWritesPtr(ptr) {
      if (ptr == 0) return undefined;
      const start = this.mem.loadPtr(ptr);
      if (start == 0) return undefined;
      const off = this.struct(start);
      const querySet = this.querySets.getPacked(off(16, 8));
      return {
        querySet: querySet,
        beginningOfPassWriteIndex: this.mem.loadU32(off(4)),
        endOfPassWriteIndex: this.mem.loadU32(off(4)),
      };
    }

    /**
     * @param {number} start
     * @returns {GPURenderPassColorAttachment}
     */
    RenderPassColorAttachment(start) {
      const off = this.struct(start);
      const viewPacked = this.textureViews.getPacked(off(16, 8));
      let depthSlice = this.mem.loadU32(off(4));
      if (depthSlice == 0xffffffff) depthSlice = undefined;
      const resolveTargetPacked = this.textureViews.getPacked(off(16, 8));
      const loadOp = this.odinEnum('LoadOp', off(4));
      const storeOp = this.odinEnum('StoreOp', off(4));
      const clearValue = this.Color(off(this.sizes.Color));
      return {
        view: viewPacked,
        resolveTarget: resolveTargetPacked,
        depthSlice: depthSlice,
        loadOp: loadOp,
        storeOp: storeOp,
        clearValue: clearValue,
      };
    }

    /**
     * @param {number} start
     * @returns {GPUColor}
     */
    Color(start) {
      const off = this.struct(start);
      return {
        r: this.mem.loadF64(off(8)),
        g: this.mem.loadF64(off(8)),
        b: this.mem.loadF64(off(8)),
        a: this.mem.loadF64(off(8)),
      };
    }

    /**
     * @param {number} ptr
     * @returns {GPURenderPassDepthStencilAttachment}
     */
    RenderPassDepthStencilAttachmentPtr(start) {
      if (start === 0) return undefined;
      const off = this.struct(start);
      const view = this.textureViews.getPacked(off(16, 8)); // 0
      const depthLoadOp = this.odinEnum('LoadOp', off(4)); // 16
      const depthStoreOp = this.odinEnum('StoreOp', off(4)); // 20
      const depthClearValue = this.mem.loadF32(off(4)); // 24
      const stencilLoadOp = this.odinEnum('LoadOp', off(4)); // 28
      const stencilStoreOp = this.odinEnum('StoreOp', off(4)); // 32
      const stencilClearValue = this.mem.loadU32(off(4)); // 36
      const depthReadOnly = this.mem.loadU8(off(1)) !== 0; // 40
      const stencilReadOnly = this.mem.loadU8(off(1)) !== 0; // 41

      if (!view) {
        console.error('depth attachment: view did not resolve', { start });
        return undefined;
      }

      const fmt = view.__format ?? '';
      const hasDepth = fmt.startsWith('depth');
      const hasStencil = fmt === 'stencil8' || fmt.endsWith('-stencil8');

      const att = { view };

      if (hasDepth) {
        if (depthReadOnly) {
          att.depthReadOnly = true;
        } else if (depthLoadOp) {
          att.depthLoadOp = depthLoadOp;
          att.depthStoreOp = depthStoreOp;
          if (depthLoadOp === 'clear') att.depthClearValue = depthClearValue;
        }
      }

      if (hasStencil) {
        if (stencilReadOnly) {
          att.stencilReadOnly = true;
        } else if (stencilLoadOp) {
          att.stencilLoadOp = stencilLoadOp;
          att.stencilStoreOp = stencilStoreOp;
          if (stencilLoadOp === 'clear') att.stencilClearValue = stencilClearValue;
        }
      }

      return att;
    }

    /**
     * @param {number} ptr
     * @returns {undefined|GPUQuerySet}
     */
    QuerySet(ptr) {
      return this.objectAt(this.querySets, ptr);
    }

    /**
     * @param {number} start
     * @returns {GPUOrigin3D}
     */
    Origin3D(start) {
      return {
        x: this.mem.loadU32(start + 0),
        y: this.mem.loadU32(start + 4),
        z: this.mem.loadU32(start + 8),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUExtent3D}
     */
    Extent3D(start) {
      return {
        width: this.mem.loadU32(start + 0),
        height: this.mem.loadU32(start + 4),
        depthOrArrayLayers: this.mem.loadU32(start + 8),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUBindGroupEntry}
     */
    BindGroupEntry(start) {
      const m = this.mem;
      const binding = m.loadU32(start + 0);
      const tag = m.loadU8(start + 40);
      const u = start + 8; // union data

      let resource;
      switch (tag) {
        case 1: {
          // Buffer_Binding
          const entry = this.buffers.getPacked(u + 0);
          const lo = m.loadU32(u + 24),
            hi = m.loadU32(u + 28);
          const whole = (lo === 0xffffffff && hi === 0xffffffff) || (lo === 0 && hi === 0);
          resource = {
            buffer: entry?.buffer, // the wrapper holds the real GPUBuffer
            offset: Number(m.loadU64(u + 16)),
          };
          if (!whole) resource.size = Number(m.loadU64(u + 24));
          break;
        }
        case 3:
          resource = this.samplers.getPacked(u + 0);
          break; // Sampler
        case 5:
          resource = this.textureViews.getPacked(u + 0);
          break; // Texture_View
        default:
          console.error('unsupported Binding_Resource variant (arrays are not valid on the web)', {
            binding,
            tag,
          });
      }
      return { binding, resource };
    }

    /**
     * @param {number} start
     * @returns {GPUBindGroupLayoutEntry}
     */
    BindGroupLayoutEntry(start) {
      const m = this.mem;
      const binding = m.loadU32(start + 0);
      // low word of the u64; bits must match GPUShaderStage
      const visibility = m.loadU32(start + 8);
      const u = start + 16; // union data
      const tag = m.loadU8(start + 32);

      if (m.loadU32(start + 40) > 1) console.warn('binding arrays are not supported on the web');

      const entry = { binding, visibility };
      switch (tag) {
        case 1: // Buffer
          entry.buffer = {
            type: this.odinEnum('BufferBindingType', u + 0),
            hasDynamicOffset: m.loadU8(u + 4) !== 0,
            minBindingSize: Number(m.loadU64(u + 8)),
          };
          break;
        case 2: // Sampler
          entry.sampler = { type: this.odinEnum('SamplerBindingType', u + 0) };
          break;
        case 3: // Texture
          entry.texture = {
            sampleType: this.odinEnum('TextureSampleType', u + 0),
            viewDimension: this.odinEnum('TextureViewDimension', u + 4),
            multisampled: m.loadU8(u + 8) !== 0,
          };
          break;
        case 4: // Storage texture
          entry.storageTexture = {
            access: this.odinEnum('StorageTextureAccess', u + 0),
            format: this.odinEnum('TextureFormat', u + 4),
            viewDimension: this.odinEnum('TextureViewDimension', u + 8),
          };
          break;
        case 5: // External texture
          entry.externalTexture = {};
          break;
        default:
          console.error('Bind_Group_Layout_Entry has no binding type', { binding, tag });
      }
      return entry;
    }

    /**
     * @param {number} start
     * @returns {GPUBufferBindingLayout}
     */
    BufferBindingLayout(start) {
      return {
        type: this.odinEnum('BufferBindingType', start + 4),
        hasDynamicOffset: this.mem.loadB32(start + 8),
        minBindingSize: this.mem.loadU64(start + 16),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUSamplerBindingLayout}
     */
    SamplerBindingLayout(start) {
      return {
        type: this.odinEnum('SamplerBindingType', start + 4),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUTextureBindingLayout}
     */
    TextureBindingLayout(start) {
      return {
        sampleType: this.odinEnum('TextureSampleType', start + 4),
        viewDimension: this.odinEnum('TextureViewDimension', start + 8),
        multisampled: this.mem.loadB32(start + 12),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUStorageTextureBindingLayout}
     */
    StorageTextureBindingLayout(start) {
      return {
        access: this.odinEnum('StorageTextureAccess', start + 4),
        format: this.odinEnum('TextureFormat', start + 8),
        viewDimension: this.odinEnum('TextureViewDimension', start + 12),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUComputeState}
     */
    ComputeState(start) {
      const off = this.struct(start);
      off(4);

      const shaderModule = this.shaderModules.getPacked(this.mem.loadPtr(off(4)));
      const entryPoint = this.StringView(off(this.sizes.StringView));

      const constantsArray = this.array(
        this.mem.loadUint(off(this.mem.intSize)),
        this.mem.loadPtr(off(4)),
        this.ConstantEntry,
        this.sizes.ConstantEntry[0],
      );

      return {
        module: shaderModule,
        entryPoint: entryPoint,
        constants: constantsArray.reduce((prev, curr) => {
          prev[curr.key] = curr.value;
          return prev;
        }, {}),
      };
    }

    /**
     * @param {number} start
     * @returns {{ key: string, value: number }}
     */
    ConstantEntry(start) {
      const off = this.struct(start);
      const { ptr, len } = this.readSlice(off);
      return {
        key: this.mem.loadString(ptr, len),
        value: this.mem.loadF64(off(8)),
      };
    }

    /**
     * @param {number} start
     * @returns {GPUComputePipelineDescriptor}
     */
    ComputePipelineDescriptor(start) {
      const off = this.struct(start);
      off(4);

      const label = this.StringView(off(this.sizes.StringView));
      const layoutIdx = this.mem.loadPtr(off(4));
      return {
        label: label,
        layout: layoutIdx > 0 ? this.pipelineLayouts.getPacked(layoutIdx) : 'auto',
        compute: this.ComputeState(off(this.sizes.ComputeState)),
      };
    }

    /** `gpu.Pipeline_Compilation_Options` (12 bytes, align 4):
           constants @0 (slice, 8), zero_initialize_workgroup_memory @8 (bool).
         Returns the pipeline-overridable constants as a plain object. */
    compilationOptions(off) {
      const { ptr, len } = this.readSlice(off);
      off(1); // zero_initialize_workgroup_memory: no browser equivalent
      const constants = {};
      const entries = this.array(
        len,
        ptr,
        (p) => this.ConstantEntry(p),
        this.sizes.ConstantEntry[0],
      );
      for (const e of entries) constants[e.key] = e.value;
      return constants;
    }

    /**
     * `gpu.Vertex_State` (48 bytes, align 8):
     *   module @0 (Handle, 16), entry_point @16 (string, 8),
     *   compilation_options @24 (12), buffers @36 (slice, 8)
     *
     * @param {number} start
     * @returns {GPUVertexState}
     */
    VertexState(start) {
      const off = this.struct(start);

      const module = this.handleAt(this.shaderModules, off(16, 8));
      this.assert(module !== undefined, 'Vertex_State.module is not a valid Shader_Module');

      const entryPoint = this.StringView(off(this.sizes.StringView));

      const constants = this.compilationOptions(off);

      const { ptr: bPtr, len: bLen } = this.readSlice(off);

      return {
        module,
        entryPoint,
        constants,
        buffers: this.array(
          bLen,
          bPtr,
          (p) => this.VertexBufferLayout(p),
          this.sizes.VertexBufferLayout[0],
        ),
      };
    }

    /**
     * `gpu.Vertex_Buffer_Layout` (24 bytes, align 8):
     *   array_stride @0 (u64), step_mode @8 (enum), attributes @12 (slice)
     *
     * @param {number} start
     * @returns {GPUVertexBufferLayout}
     */
    VertexBufferLayout(start) {
      const off = this.struct(start);
      const arrayStride = Number(this.mem.loadU64(off(8)));
      const stepMode = this.odinEnum('VertexStepMode', off(4));
      const { ptr, len } = this.readSlice(off);
      return {
        arrayStride,
        stepMode,
        attributes: this.array(
          len,
          ptr,
          (p) => this.VertexAttribute(p),
          this.sizes.VertexAttribute[0],
        ),
      };
    }

    /**
     * `gpu.Vertex_Attribute` (24 bytes, align 8):
     *   format @0 (enum), offset @8 (u64), shader_location @16 (u32)
     *
     * @param {number} start
     * @returns {GPUVertexAttribute}
     */
    VertexAttribute(start) {
      const off = this.struct(start);
      const format = this.odinEnum('VertexFormat', off(4));
      const offset = Number(this.mem.loadU64(off(8)));
      const shaderLocation = this.mem.loadU32(off(4));
      return { format, offset, shaderLocation };
    }

    /**
     * `gpu.Primitive_State` (28 bytes, align 4):
     *   topology @0, strip_index_format @4, front_face @8, cull_mode @12,
     *   unclipped_depth @16 (bool), polygon_mode @20, conservative @24 (bool)
     *
     * @param {number} start
     * @returns {GPUPrimitiveState}
     */
    PrimitiveState(start) {
      const off = this.struct(start);

      return {
        topology: this.odinEnum('PrimitiveTopology', off(4)),
        stripIndexFormat: this.odinEnum('IndexFormat', off(4)),
        frontFace: this.odinEnum('FrontFace', off(4)),
        cullMode: this.odinEnum('CullMode', off(4)),
        unclippedDepth: this.mem.loadB32(off(4)),
        polygonMode: this.odinEnum('PolygonMode', off(4)),
        conservative: this.mem.loadB32(off(4)),
      };
    }

    /**
     * `gpu.Multisample_State` (12 bytes, align 4):
     *   count @0 (u32), mask @4 (u32), alpha_to_coverage_enabled @8 (bool)
     *
     * @param {number} start
     * @returns {GPUMultisampleState}
     */
    MultisampleState(start) {
      const off = this.struct(start);
      return {
        count: this.mem.loadU32(off(4)),
        mask: this.mem.loadU32(off(4)),
        alphaToCoverageEnabled: this.mem.loadB32(off(4)),
      };
    }

    /**
     * `gpu.Render_Pipeline_Descriptor` (144 bytes, align 8):
     *   label @0 (string, 8), layout @8 (Handle, 16), vertex @24 (48),
     *   primitive @72 (28), depth_stencil @100 (ptr), multisample @104 (12),
     *   fragment @116 (ptr), multiview_mask @120 (u32), cache @128 (Handle, 16)
     *
     * @param {number} start
     * @returns {GPURenderPipelineDescriptor}
     */
    RenderPipelineDescriptor(start) {
      const off = this.struct(start);

      const label = this.StringView(off(this.sizes.StringView));

      const layout = this.handleAt(this.pipelineLayouts, off(16, 8));

      const vertex = this.VertexState(off(this.sizes.VertexState));
      const primitive = this.PrimitiveState(off(this.sizes.PrimitiveState));
      const depthStencil = this.DepthStencilStatePtr(off(4));
      const multisample = this.MultisampleState(off(this.sizes.MultisampleState));
      const fragment = this.FragmentStatePtr(off(4));

      off(4); // multiview_mask: no browser equivalent

      return {
        label,
        layout: layout !== undefined ? layout : 'auto',
        vertex,
        primitive,
        depthStencil,
        multisample,
        fragment,
      };
    }

    /**
     * `gpu.Stencil_Face_State` (16 bytes, align 4):
     *   compare @0, fail_op @4, depth_fail_op @8, pass_op @12
     *
     * @param {number} start
     * @returns {GPUStencilFaceState}
     */
    StencilFaceState(start) {
      const off = this.struct(start);
      return {
        compare: this.odinEnum('CompareFunction', off(4)),
        failOp: this.odinEnum('StencilOperation', off(4)),
        depthFailOp: this.odinEnum('StencilOperation', off(4)),
        passOp: this.odinEnum('StencilOperation', off(4)),
      };
    }

    /**
     * `gpu.Depth_Stencil_State` (64 bytes, align 4):
     *   format @0, depth_write_enabled @4 (bool), depth_compare @8,
     *   stencil @12 (40), bias @52 (12)
     *
     * @param {number} ptr
     * @returns {?GPUDepthStencilState}
     */
    DepthStencilStatePtr(ptr) {
      const start = this.mem.loadPtr(ptr);
      if (start == 0) {
        return undefined;
      }

      const off = this.struct(start);

      const format = this.odinEnum('TextureFormat', off(4));
      const depthWriteEnabled = this.mem.loadB32(off(4));
      const depthCompare = this.odinEnum('CompareFunction', off(4));

      // stencil: `front` and `back` face states, then the read/write masks.
      const stencilFront = this.StencilFaceState(off(this.sizes.StencilFaceState));
      const stencilBack = this.StencilFaceState(off(this.sizes.StencilFaceState));
      const stencilReadMask = this.mem.loadU32(off(4));
      const stencilWriteMask = this.mem.loadU32(off(4));

      // bias: constant, slope_scale, clamp.
      const depthBias = this.mem.loadI32(off(4));
      const depthBiasSlopeScale = this.mem.loadF32(off(4));
      const depthBiasClamp = this.mem.loadF32(off(4));

      return {
        format,
        depthWriteEnabled,
        depthCompare,
        stencilFront,
        stencilBack,
        stencilReadMask,
        stencilWriteMask,
        depthBias,
        depthBiasSlopeScale,
        depthBiasClamp,
      };
    }

    /**
     * `gpu.Fragment_State` (48 bytes, align 8):
     *   module @0 (Handle, 16), entry_point @16 (string, 8),
     *   compilation_options @24 (12), targets @36 (slice, 8)
     *
     * @param {number} ptr
     * @returns {?GPUFragmentState}
     */
    FragmentStatePtr(ptr) {
      const start = this.mem.loadPtr(ptr);
      if (start == 0) {
        return undefined;
      }

      const off = this.struct(start);

      const module = this.handleAt(this.shaderModules, off(16, 8));
      this.assert(module !== undefined, 'Fragment_State.module is not a valid Shader_Module');

      const entryPoint = this.StringView(off(this.sizes.StringView));

      const constants = this.compilationOptions(off);

      const { ptr: tPtr, len: tLen } = this.readSlice(off);

      return {
        module,
        entryPoint,
        constants,
        targets: this.array(
          tLen,
          tPtr,
          (p) => this.ColorTargetState(p),
          this.sizes.ColorTargetState[0],
        ),
      };
    }

    /**
     * `gpu.Color_Target_State` (16 bytes, align 8):
     *   format @0, blend @4 (ptr), write_mask @8 (`Color_Writes` bitset, 8 bytes)
     *
     * @param {number} start
     * @returns {GPUColorTargetState}
     */
    ColorTargetState(start) {
      const off = this.struct(start);
      return {
        format: this.odinEnum('TextureFormat', off(4)),
        blend: this.BlendStatePtr(off(4)),
        // `Color_Write`'s ordinals line up with the WebGPU `GPUColorWrite` bits
        // (Red/Green/Blue/Alpha == 1/2/4/8), so the bitset passes straight over.
        writeMask: this.bitSet(off(8)),
      };
    }

    /**
     * `gpu.Blend_State` (24 bytes, align 4): color @0, alpha @12
     *
     * @param {number} ptr
     * @returns {?GPUBlendState}
     */
    BlendStatePtr(ptr) {
      const start = this.mem.loadPtr(ptr);
      if (start == 0) {
        return undefined;
      }

      const off = this.struct(start);

      return {
        color: this.BlendComponent(off(this.sizes.BlendComponent)),
        alpha: this.BlendComponent(off(this.sizes.BlendComponent)),
      };
    }

    /**
     * Reads a `gpu.Texture_Descriptor` (56 bytes, align 8). Measured by
     * `examples/layout`: `label` @0, `size` @8 (`Extent3D`), then a run of
     * 4-byte fields, `usage` @40 (u64) and `view_formats` @48 (slice).
     *
     * @param {number} descriptorPtr
     * @returns {GPUTextureDescriptor}
     */
    TextureDescriptor(descriptorPtr) {
      const off = this.struct(descriptorPtr);

      const { ptr: lp, len: ll } = this.readSlice(off); // 0 label
      const label = ll > 0 ? this.mem.loadString(lp, ll) : undefined;

      const sizeAt = off(12, 4); // 8 Extent_3D
      const size = {
        width: this.mem.loadU32(sizeAt),
        height: this.mem.loadU32(sizeAt + 4),
        depthOrArrayLayers: this.mem.loadU32(sizeAt + 8),
      };

      const mipLevelCount = this.mem.loadU32(off(4)); // 20
      const sampleCount = this.mem.loadU32(off(4)); // 24
      const dimension = this.odinEnum('TextureDimension', off(4)); // 28
      const format = this.odinEnum('TextureFormat', off(4)); // 32
      const usage = this.mem.loadU32(off(8, 8)); // 40 (low word of the u64)
      off(0, 1); // (usage's high word was consumed by off(8, 8))

      const { ptr: vp, len: vl } = this.readSlice(off); // 48
      const viewFormats =
        vl > 0 ? this.array(vl, vp, (p) => this.odinEnum('TextureFormat', p), 4) : [];

      return { label, size, mipLevelCount, sampleCount, dimension, format, usage, viewFormats };
    }

    /**
     * `gpu.Texture_View_Descriptor` (48 bytes, align 8):
     *   label @0 (string, 8), format @8, dimension @12, usage @16 (bitset, 8),
     *   aspect @24, base_mip_level @28, mip_level_count @32,
     *   base_array_layer @36, array_layer_count @40
     *
     * @param {number} ptr
     * @returns {?GPUTextureViewDescriptor}
     */
    TextureViewDescriptor(ptr) {
      if (ptr == 0) {
        return undefined;
      }

      const off = this.struct(ptr);

      const label = this.StringView(off(this.sizes.StringView));
      const format = this.odinEnum('TextureFormat', off(4));
      const dimension = this.odinEnum('TextureViewDimension', off(4));
      // `Texture_Usage`'s ordinals line up with the `GPUTextureUsageFlags` bits,
      // so the bitset passes straight over. Zero means "not provided".
      const usage = this.bitSet(off(8));
      const aspect = this.odinEnum('TextureAspect', off(4));
      const baseMipLevel = this.mem.loadU32(off(4));
      const mipLevelCount = this.mem.loadU32(off(4));
      const baseArrayLayer = this.mem.loadU32(off(4));
      const arrayLayerCount = this.mem.loadU32(off(4));

      /** @type {GPUTextureViewDescriptor} */
      const descriptor = { label, format, dimension, aspect, baseMipLevel, baseArrayLayer };
      if (usage != 0) descriptor.usage = usage;
      // A zero count means "all remaining", which WebGPU spells `undefined`.
      if (mipLevelCount != 0) descriptor.mipLevelCount = mipLevelCount;
      if (arrayLayerCount != 0) descriptor.arrayLayerCount = arrayLayerCount;
      return descriptor;
    }

    /**
     * `gpu.Blend_Component` (12 bytes, align 4):
     *   operation @0, src_factor @4, dst_factor @8
     *
     * @param {number} start
     * @returns {GPUBlendComponent}
     */
    BlendComponent(start) {
      const off = this.struct(start);
      return {
        operation: this.odinEnum('BlendOperation', off(4)),
        srcFactor: this.odinEnum('BlendFactor', off(4)),
        dstFactor: this.odinEnum('BlendFactor', off(4)),
      };
    }

    TexelCopyBufferInfo(start) {
      const off = this.struct(start);
      const entry = this.buffers.getPacked(off(16, 8)); // 0 (wrapper)
      const layout = this.TexelCopyBufferLayout(off(16, 8)); // 16
      return { buffer: entry?.buffer, ...layout };
    }

    TexelCopyBufferLayout(start) {
      const off = this.struct(start);
      const offset = Number(this.mem.loadU64(off(8))); // 0
      let bytesPerRow = this.mem.loadU32(off(4)); // 8
      let rowsPerImage = this.mem.loadU32(off(4)); // 12
      // 0 and 0xffffffff both mean "unspecified" here; the browser rejects an
      // explicit 0 when it isn't needed.
      if (bytesPerRow === 0 || bytesPerRow === 0xffffffff) bytesPerRow = undefined;
      if (rowsPerImage === 0 || rowsPerImage === 0xffffffff) rowsPerImage = undefined;
      return { offset, bytesPerRow, rowsPerImage };
    }

    TexelCopyTextureInfo(start) {
      const off = this.struct(start);
      const texture = this.textures.getPacked(off(16, 8)); // 0
      const mipLevel = this.mem.loadU32(off(4)); // 16
      const origin = {
        // 20
        x: this.mem.loadU32(off(4)),
        y: this.mem.loadU32(off(4)),
        z: this.mem.loadU32(off(4)),
      };
      const aspect = this.odinEnum('TextureAspect', off(4)); // 32
      return { texture, mipLevel, origin, aspect };
    }

    StringView(start) {
      const data = this.mem.loadPtr(start);
      return this.mem.loadString(data, this.mem.loadUint(start + this.mem.intSize));
    }

    CallbackInfoPtr(ptr) {
      const start = this.mem.loadPtr(ptr);
      if (start === 0) {
        return null;
      }

      return CallbackInfo(start);
    }

    CallbackInfo(start) {
      const off = this.struct(start);
      return {
        callback: this.mem.exports.__indirect_function_table.get(this.mem.loadPtr(off(4))),
        userdata1: this.mem.loadPtr(off(4)),
        userdata2: this.mem.loadPtr(off(4)),
      };
    }

    UncapturedErrorCallbackInfo(start) {
      const off = this.struct(start);
      return {
        callback: this.mem.exports.__indirect_function_table.get(this.mem.loadPtr(off(4))),
        userdata1: this.mem.loadPtr(off(4)),
        userdata2: this.mem.loadPtr(off(4)),
      };
    }

    callCallback(callback, args) {
      args.push(callback.userdata1);
      args.push(callback.userdata2);
      callback.callback(...args);
    }

    zeroMessageArg() {
      if (this.zeroMessageAddr > 0) {
        return this.zeroMessageAddr;
      }

      this.zeroMessageAddr = this.mem.exports.js_alloc(this.sizes.StringView[0]);
      return this.zeroMessageAddr;
    }

    makeMessageArg(message) {
      if (message.length == 0) {
        return this.zeroMessageArg();
      }

      const messageLength = new TextEncoder().encode(message).length;
      const stringSize = this.sizes.StringView[0];

      const addr = this.mem.exports.js_alloc(stringSize + messageLength);

      const messageAddr = addr + stringSize;

      this.mem.storeI32(addr, messageAddr);
      this.mem.storeUint(addr + this.mem.intSize, messageLength);

      this.mem.storeString(messageAddr, message);

      return addr;
    }

    loadSlice(slicePtr) {
      const off = this.struct(slicePtr);
      return {
        ptr: this.mem.loadPtr(off(4)),
        len: this.mem.loadUint(off(this.mem.intSize)),
      };
    }

    getInterface() {
      return {
        /**
         * @param {0|number} descriptorPtr
         * @returns {number}
         */
        webgpuCreateInstance: (descriptorPtr) => {
          if (!navigator.gpu) {
            console.error('WebGPU is not supported by this browser');
            return 0;
          }
          return this.instances.create({});
        },

        /**
         * @param {number} featuresPtr
         */
        webgpuGetInstanceFeatures: (featuresPtr) => {
          // TODO: implement (futures).
        },

        /**
         * @param {number} limitsPtr
         */
        webgpuGetInstanceLimits: (limitsPtr) => {
          // TODO: implement (futures).
        },

        /**
         * @param {number} feature
         * @returns {boolean}
         */
        webgpuHasInstanceFeature: (feature) => {
          // TODO: implement (futures).
          return false;
        },

        /**
         * @param {number} procNamePtr
         * @param {number} procNameLen
         * @returns {number}
         */
        webgpuGetProcAddress: (procNamePtr, procNameLen) => {
          console.error(`unimplemented: wgpuGetProcAddress`);
          return 0;
        },

        /* ---------------------- Adapter ---------------------- */

        /**
         * @param {number} adapterIdx
         * @param {number} featuresPtr
         */
        webgpuAdapterGetFeatures: (adapterIdx, featuresPtr) => {
          const adapter = this.adapters.get(adapterIdx);
          this.genericGetFeatures(adapter.features, featuresPtr);
        },

        /**
         * @param {number} adapterIdx
         * @param {number} infoPtr
         * @returns {number}
         */
        webgpuAdapterGetInfo: (adapterIdx, infoPtr) => {
          const adapter = this.adapters.get(adapterIdx);
          if (!adapter) return 0;
          return this.genericGetAdapterInfo(infoPtr, adapter.info);
        },

        /**
         * @param {number} adapterIdx
         * @param {number} limitsPtr
         * @returns {number}
         */
        webgpuAdapterGetLimits: (adapterIdx, limitsPtr) => {
          const adapter = this.adapters.get(adapterIdx);
          return this.genericGetLimits(adapter.limits, limitsPtr);
        },

        /**
         * @param {number} adapterIdx
         * @param {number} featureInt
         * @returns {boolean}
         */
        webgpuAdapterHasFeature: (adapterIdx, featureInt) => {
          const adapter = this.adapters.get(adapterIdx);
          return adapter.features.has(ENUMS.FeatureName[featureInt]);
        },

        /**
         * @param {number} adapterIdx
         * @param {GPUDeviceDescriptor} descriptorPtr
         * @return {number}
         */
        webgpuAdapterRequestDevice: new WebAssembly.Suspending(
          async function (adapterIdx, descriptorPtr) {
            const adapter = this.adapters.get(adapterIdx);
            const off = this.struct(descriptorPtr);

            const label = this.StringView(off(this.sizes.StringView));

            const requiredFeaturesData = this.mem.loadPtr(off(4));
            const requiredFeaturesLen = this.mem.loadUint(off(this.mem.intSize));

            // Inline struct: read from the shared cursor, which advances past it.
            const limits = this.LimitsInline(off);

            const requiredLimits = {};
            for (const [key, value] of Object.entries(limits)) {
              // requestDevice rejects unknown limit names and undefined values
              if (value !== undefined && key in adapter.limits) {
                requiredLimits[key] = value;
              }
            }

            const defaultQueue = this.QueueDescriptor(off(this.sizes.QueueDescriptor));

            /** @type {GPUDeviceDescriptor} */
            const descriptor = {
              label,
              requiredFeatures: this.array(
                requiredFeaturesLen,
                requiredFeaturesData,
                this.FeatureNamePtr,
                4,
              ),
              requiredLimits,
              defaultQueue,
            };

            const deviceLostCallbackInfo = this.CallbackInfo(off(this.sizes.CallbackInfo));
            const uncapturedErrorCallbackInfo = this.UncapturedErrorCallbackInfo(
              off(this.sizes.UncapturedErrorCallbackInfo),
            );

            /** @type {GPUDevice} */
            const device = await adapter.requestDevice(descriptor);
            const deviceIdx = this.devices.create(device);

            if (deviceLostCallbackInfo.callback !== null) {
              device.lost.then((info) => {
                const reason = this.odinEnumValue('DeviceLostReason', info.reason);

                const devicePtr = this.mem.exports.js_alloc(4);
                this.mem.storeI32(devicePtr, deviceIdx);

                const messageAddr = this.makeMessageArg(info.message);
                this.callCallback(deviceLostCallbackInfo, [devicePtr, reason, messageAddr]);

                this.mem.exports.js_free(devicePtr);
                this.mem.exports.js_free(messageAddr);
              });
            }

            if (uncapturedErrorCallbackInfo.callback !== null) {
              device.onuncapturederror = (ev) => {
                let status;
                if (ev.error instanceof GPUValidationError) {
                  status = this.odinEnumValue('ErrorType', 'validation');
                } else if (ev.error instanceof GPUOutOfMemoryError) {
                  status = this.odinEnumValue('ErrorType', 'out-of-memory');
                } else if (ev.error instanceof GPUInternalError) {
                  status = this.odinEnumValue('ErrorType', 'internal');
                } else {
                  status = this.odinEnumValue('ErrorType', 'unknown');
                }

                const messageAddr = this.makeMessageArg(ev.error.message);
                this.callCallback(uncapturedErrorCallbackInfo, [deviceIdx, status, messageAddr]);
                this.mem.exports.js_free(messageAddr);
              };
            }

            return deviceIdx;
          }.bind(this),
        ),

        ...this.adapters.interface(),

        /**
         * @param {number} infoPtr
         */
        webgpuAdapterInfoFreeMembers: (infoPtr) => {
          this.assert(infoPtr != 0);

          const off = this.struct(infoPtr);

          const freeString = (start) => {
            const strAddr = this.mem.loadPtr(start);
            if (strAddr !== 0) {
              this.mem.exports.js_free(strAddr);
            }
          };

          // Layout (wasm32): follows Adapter_Info in Odin
          freeString(off(this.sizes.StringView)); // name
          off(4);                                 // vendor: u32
          off(4);                                 // device: u32
          off(4);                                 // device_type: Device_Type
          freeString(off(this.sizes.StringView)); // device_pci_bus_id
          freeString(off(this.sizes.StringView)); // driver
          freeString(off(this.sizes.StringView)); // driver_info
          // backend, subgroup_min_size, subgroup_max_size: nothing to free
        },

        /* ---------------------- BindGroup ---------------------- */

        ...this.bindGroups.interface(true),

        /* ---------------------- BindGroupLayout ---------------------- */

        ...this.bindGroupLayouts.interface(true),

        /* ---------------------- Buffer ---------------------- */

        /** @param {number} bufferIdx */
        webgpuBufferDestroy: (bufferIdx) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          buffer.buffer.destroy();
        },

        /**
         * @param {number} bufferIdx
         * @param {number|BigInt} offset
         * @param {number|BigInt} size
         * @returns {number}
         */
        webgpuBufferGetConstMappedRange: (bufferIdx, offset, size) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);

          // TODO: does constMappedRange need to do something else?

          this.assert(!buffer.mapping, 'buffer already mapped');

          const range = buffer.buffer.getMappedRange(offset, size);

          const ptr = this.mem.exports.js_alloc(range.byteLength);

          const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
          mapping.set(new Uint8Array(range));

          buffer.mapping = { range: range, ptr: ptr, size: range.byteLength };
          return ptr;
        },

        /**
         * @param {number} bufferIdx
         * @return {number}
         */
        webgpuBufferGetMapState: (bufferIdx) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          return this.odinEnumValue('BufferMapState', buffer.mapState);
        },

        /**
         * @param {number} bufferIdx
         * @param {number|BigInt} offset
         * @param {number|BigInt} size
         * @returns {number}
         */
        webgpuBufferGetMappedRange: (bufferIdx, offset, size) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);

          this.assert(!buffer.mapping, 'buffer already mapped');

          const range = buffer.buffer.getMappedRange(offset, size);

          const ptr = this.mem.exports.js_alloc(range.byteLength);

          const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
          mapping.set(new Uint8Array(range));

          buffer.mapping = { range: range, ptr: ptr, size: range.byteLength };
          return ptr;
        },

        /**
         * @param {number} bufferIdx
         * @returns {BigInt}
         */
        webgpuBufferGetSize: (bufferIdx) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          return BigInt(buffer.buffer.size);
        },

        /**
         * @param {number} bufferIdx
         * @returns {number}
         */
        webgpuBufferGetUsage: (bufferIdx) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          return buffer.buffer.usage;
        },

        /**
         * @param {number} bufferIdx
         * @param {number} mode
         * @param {number|BigInt} offset
         * @param {number|BigInt} size
         * @param {number} callbackInfo
         * @return {number}
         */
        webgpuBufferMapAsync: (bufferIdx, mode, offset, size, callbackInfoPtr) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          mode = this.unwrapBigInt(mode);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          buffer.buffer
            .mapAsync(mode, offset, size)
            .catch((e) => {
              const messageAddr = this.makeMessageArg(e.message);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('MapAsyncStatus', 'Error'),
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            })
            .then(() => {
              this.callCallback(callbackInfo, [
                this.odinEnumValue('MapAsyncStatus', 'Success'),
                this.zeroMessageArg(),
              ]);
            });

          // TODO: returning a future? WARN that requires refactor removing await
          return BigInt(0);
        },

        /**
         * @param {number} bufferIdx
         * @param {number|BigInt} offset
         * @param {number} ptr
         * @param {number|BigInt} size
         * @return {number}
         */
        webgpuBufferReadMappedRange: (bufferIdx, offset, ptr, size) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);

          this.assert(!buffer.mapping, 'buffer already mapped');

          const range = buffer.buffer.getMappedRange(offset, size);

          const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
          mapping.set(new Uint8Array(range));

          buffer.mapping = { range: range, ptr: ptr, size: range.byteLength };

          return STATUS_SUCCESS;
        },

        /**
         * @param {number} bufferIdx
         * @param {number} labelPtr
         * @param {number} labelLen
         */
        webgpuBufferSetLabel: (bufferIdx, labelPtr, labelLen) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          buffer.buffer.label = this.mem.loadString(labelPtr, labelLen);
        },

        /**
         * @param {number} bufferIdx
         */
        webgpuBufferUnmap: (bufferIdx) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          this.assert(buffer.mapping, 'buffer not mapped');

          const mapping = new Uint8Array(
            this.mem.memory.buffer,
            buffer.mapping.ptr,
            buffer.mapping.size,
          );
          new Uint8Array(buffer.mapping.range).set(mapping);

          buffer.buffer.unmap();

          this.mem.exports.js_free(buffer.mapping.ptr);
          buffer.mapping = null;
        },

        /**
         * @param {number} bufferIdx
         * @param {number|BigInt} offset
         * @param {number} ptr
         * @param {number|BigInt} size
         * @return {number}
         */
        webgpuBufferWriteMappedRange: (bufferIdx, offset, ptr, size) => {
          const buffer = this.buffers.getPacked(bufferIdx);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);

          this.assert(!buffer.mapping, 'buffer already mapped');

          const range = buffer.buffer.getMappedRange(offset, size);

          const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
          new Uint8Array(range).set(mapping);

          buffer.mapping = { range: range, ptr: ptr, size: range.byteLength };

          return STATUS_SUCCESS;
        },

        ...this.buffers.interface(),

        /* ---------------------- CommandBuffer ---------------------- */

        ...this.commandBuffers.interface(true),

        /* ---------------------- CommandEncoder ---------------------- */

        /**
         * @param {number} commandEncoderIdx
         * @param {0|number} descriptorPtr
         * @return {number} The compute pass encoder
         */
        webgpuCommandEncoderBeginComputePass: (commandEncoderIdx, descriptorPtr) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);

          /** @type {?GPUComputePassDescriptor} */
          let descriptor;
          if (descriptorPtr != 0) {
            const off = this.struct(descriptorPtr);
            off(4);
            descriptor = {
              label: this.StringView(off(this.sizes.StringView)),
              timestampWrites: this.PassTimestampWritesPtr(off(4)),
            };
          }

          const computePassEncoder = commandEncoder.beginComputePass(descriptor);
          return this.computePassEncoders.create(computePassEncoder);
        },

        /**
         * @param {number} commandEncoderPtr
         * @param {number} descriptorPtr
         * @return {number} The render pass encoder
         */
        webgpuCommandEncoderBeginRenderPass: (commandEncoderPtr, descriptorPtr, outPtr) => {
          /** @type {GPUCommandEncoder} */
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderPtr);
          this.assert(commandEncoder != undefined);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);

          /**
     * `gpu.Render_Pass_Descriptor` (48 bytes, align 8):
       label @0 (string, 8), color_attachments @8 (slice, 8),
       depth_stencil_attachment @16 (ptr), timestamp_writes @20 (ptr),
       occlusion_query_set @24 (`Query_Set`, 16), multiview_mask @40 */
          const { ptr: labelPtr, len: labelLen } = this.readSlice(off); // 0: label
          const label = this.mem.loadString(labelPtr, labelLen);

          const { ptr: caPtr, len: caLen } = this.readSlice(off); // 8: color_attachments
          const dsPtr = this.mem.loadPtr(off(4)); // 16: depth_stencil_attachment
          const tsPtr = this.mem.loadPtr(off(4)); // 20: timestamp_writes
          const occlusionQuerySet = this.objectAt(this.querySets, off(4)); // 24
          off(4); // 40: multiview_mask (unused)

          /** @type {GPURenderPassEncoderDescriptor} */
          const descriptor = {
            label,
            colorAttachments: this.array(
              caLen,
              caPtr,
              this.RenderPassColorAttachment,
              this.sizes.RenderPassColorAttachment[0],
            ),
            occlusionQuerySet: occlusionQuerySet,
            timestampWrites: this.PassTimestampWritesPtr(tsPtr),
          };
          const depthStencil = this.RenderPassDepthStencilAttachmentPtr(dsPtr);
          if (depthStencil) descriptor.depthStencilAttachment = depthStencil;

          const renderPass = commandEncoder.beginRenderPass(descriptor);
          return this.renderPassEncoders.storePacked(
            outPtr,
            this.renderPassEncoders.create(renderPass),
          );
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} bufferIdx
         * @param {BigInt} offset
         * @param {BigInt} size
         */
        webgpuCommandEncoderClearBuffer: (commandEncoderIdx, bufferIdx, offset, size) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          const buffer = this.buffers.getPacked(bufferIdx);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);
          commandEncoder.clearBuffer(buffer.buffer, offset, size);
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} sourceIdx
         * @param {BigInt} sourceOffset
         * @param {number} destinationIdx
         * @param {BigInt} destinationOffset
         * @param {BigInt} size
         */
        webgpuCommandEncoderCopyBufferToBuffer: (
          commandEncoderIdx,
          sourceIdx,
          sourceOffset,
          destinationIdx,
          destinationOffset,
          size,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          const source = this.buffers.getPacked(sourceIdx);
          const destination = this.buffers.getPacked(destinationIdx);
          sourceOffset = this.unwrapBigInt(sourceOffset);
          destinationOffset = this.unwrapBigInt(destinationOffset);
          size = this.unwrapBigInt(size);
          commandEncoder.copyBufferToBuffer(
            source.buffer,
            sourceOffset,
            destination.buffer,
            destinationOffset,
            size,
          );
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} sourcePtr
         * @param {number} destinationPtr
         * @param {number} copySizePtr
         */
        webgpuCommandEncoderCopyBufferToTexture: (
          commandEncoderIdx,
          sourcePtr,
          destinationPtr,
          copySizePtr,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.copyBufferToTexture(
            this.TexelCopyBufferInfo(sourcePtr),
            this.TexelCopyTextureInfo(destinationPtr),
            this.Extent3D(copySizePtr),
          );
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} sourcePtr
         * @param {number} destinationPtr
         * @param {number} copySizePtr
         */
        webgpuCommandEncoderCopyTextureToBuffer: (
          commandEncoderIdx,
          sourcePtr,
          destinationPtr,
          copySizePtr,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.copyTextureToBuffer(
            this.TexelCopyTextureInfo(sourcePtr),
            this.TexelCopyBufferInfo(destinationPtr),
            this.Extent3D(copySizePtr),
          );
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} sourcePtr
         * @param {number} destinationPtr
         * @param {number} copySizePtr
         */
        webgpuCommandEncoderCopyTextureToTexture: (
          commandEncoderIdx,
          sourcePtr,
          destinationPtr,
          copySizePtr,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.copyTextureToTexture(
            this.TexelCopyTextureInfo(sourcePtr),
            this.TexelCopyTextureInfo(destinationPtr),
            this.Extent3D(copySizePtr),
          );
        },

        /**
         * @param {number} commandEncoderPtr
         * @param {0|number} descriptorPtr
         * @returns {number} The command buffer.
         */
        webgpuCommandEncoderFinish: (commandEncoderPtr, descriptorPtr, outPtr) => {
          /** @type {GPUCommandEncoder} */
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderPtr);
          this.assert(commandEncoder !== undefined);

          const off = this.struct(descriptorPtr);

          /** @type {GPUCommandBufferDescriptor} */
          const descriptor = {
            label: this.StringView(off(this.sizes.StringView)),
          };

          const commandBuffer = commandEncoder.finish(descriptor);
          return this.commandBuffers.storePacked(outPtr, this.commandBuffers.create(commandBuffer));
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} markerLabelPtr
         * @param {number} markerLabelLen
         */
        webgpuCommandEncoderInsertDebugMarker: (
          commandEncoderIdx,
          markerLabelPtr,
          markerLabelLen,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.insertDebugMarker(this.mem.loadString(markerLabelPtr, markerLabelLen));
        },

        /**
         * @param {number} commandEncoderIdx
         */
        webgpuCommandEncoderPopDebugGroup: (commandEncoderIdx) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.popDebugGroup();
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} groupLabelPtr
         * @param {number} groupLabelLen
         */
        webgpuCommandEncoderPushDebugGroup: (commandEncoderIdx, groupLabelPtr, groupLabelLen) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          commandEncoder.pushDebugGroup(this.mem.loadString(groupLabelPtr, groupLabelLen));
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} querySetIdx
         * @param {number} firstQuery
         * @param {number} queryCount
         * @param {number} destinationIdx
         * @param {BigInt} destinationOffset
         */
        webgpuCommandEncoderResolveQuerySet: (
          commandEncoderIdx,
          querySetIdx,
          firstQuery,
          queryCount,
          destinationIdx,
          destinationOffset,
        ) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          const querySet = this.querySets.get(querySetIdx);
          const destination = this.buffers.getPacked(destinationIdx);
          destinationOffset = this.unwrapBigInt(destinationOffset);
          commandEncoder.resolveQuerySet(
            querySet,
            firstQuery,
            queryCount,
            destination.buffer,
            destinationOffset,
          );
        },

        /**
         * @param {number} commandEncoderIdx
         * @param {number} querySetIdx
         * @param {number} queryIndex
         */
        webgpuCommandEncoderWriteTimestamp: (commandEncoderIdx, querySetIdx, queryIndex) => {
          const commandEncoder = this.commandEncoders.getPacked(commandEncoderIdx);
          const querySet = this.querySets.get(querySetIdx);
          commandEncoder.writeTimestamp(querySet, queryIndex);
        },

        ...this.commandEncoders.interface(true),

        /* ---------------------- ComputePassEncoder ---------------------- */

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} workgroupCountX
         * @param {number} workgroupCountY
         * @param {number} workgroupCountZ
         */
        webgpuComputePassEncoderDispatchWorkgroups: (
          computePassEncoderIdx,
          workgroupCountX,
          workgroupCountY,
          workgroupCountZ,
        ) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          computePassEncoder.dispatchWorkgroups(workgroupCountX, workgroupCountY, workgroupCountZ);
        },

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} indirectBufferIdx
         * @param {BigInt} indirectOffset
         */
        webgpuComputePassEncoderDispatchWorkgroupsIndirect: (
          computePassEncoderIdx,
          indirectBufferIdx,
          indirectOffset,
        ) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          const indirectBuffer = this.buffers.getPacked(indirectBufferIdx);
          indirectOffset = this.unwrapBigInt(indirectOffset);
          computePassEncoder.dispatchWorkgroupsIndirect(indirectBuffer.buffer, indirectOffset);
        },

        /**
         * @param {number} computePassEncoderIdx
         */
        webgpuComputePassEncoderEnd: (computePassEncoderIdx) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          computePassEncoder.end();
        },

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} markerLabelPtr
         * @param {number} markerLabelLen
         */
        webgpuComputePassEncoderInsertDebugMarker: (
          computePassEncoderIdx,
          markerLabelPtr,
          markerLabelLen,
        ) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          computePassEncoder.insertDebugMarker(this.mem.loadString(markerLabelPtr, markerLabelLen));
        },

        /**
         * @param {number} computePassEncoderIdx
         */
        webgpuComputePassEncoderPopDebugGroup: (computePassEncoderIdx) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          computePassEncoder.popDebugGroup();
        },

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} groupLabelPtr
         * @param {number} groupLabelLen
         */
        webgpuComputePassEncoderPushDebugGroup: (
          computePassEncoderIdx,
          groupLabelPtr,
          groupLabelLen,
        ) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          computePassEncoder.pushDebugGroup(this.mem.loadString(groupLabelPtr, groupLabelLen));
        },

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} groupIndex
         * @param {0|number} groupIdx
         * @param {number|BigInt} dynamicOffsetCount
         * @param {number} dynamicOffsetsPtr
         */
        webgpuComputePassEncoderSetBindGroup: (
          computePassEncoderIdx,
          groupIndex,
          groupIdx,
          dynamicOffsetCount,
          dynamicOffsetsPtr,
        ) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          dynamicOffsetCount = this.unwrapBigInt(dynamicOffsetCount);

          let bindGroup;
          if (groupIdx != 0) {
            bindGroup = this.bindGroups.getPacked(groupIdx);
          }

          const dynamicOffsets = [];
          for (let i = 0; i < dynamicOffsetCount; i += 1) {
            dynamicOffsets.push(this.mem.loadU32(dynamicOffsetsPtr));
            dynamicOffsetsPtr += 4;
          }

          computePassEncoder.setBindGroup(groupIndex, bindGroup, dynamicOffsets);
        },

        webgpuComputePassEncoderSetImmediates: (computePassEncoderIdx, offset, data, size) => {
          //
        },

        /**
         * @param {number} computePassEncoderIdx
         * @param {number} pipelineIdx
         */
        webgpuComputePassEncoderSetPipeline: (computePassEncoderIdx, pipelineIdx) => {
          const computePassEncoder = this.computePassEncoders.get(computePassEncoderIdx);
          const pipeline = this.computePipelines.get(pipelineIdx);
          computePassEncoder.setPipeline(pipeline);
        },

        ...this.computePassEncoders.interface(true),

        /* ---------------------- ComputePipeline ---------------------- */

        /**
         * @param {number} computePipelineIdx
         * @param {number} groupIndex
         * @returns {number}
         */
        webgpuComputePipelineGetBindGroupLayout: (computePipelineIdx, groupIndex) => {
          const computePipeline = this.computePipelines.get(computePipelineIdx);
          const bindGroupLayout = computePipeline.getBindGroupLayout(groupIndex);
          return this.bindGroupLayouts.create(bindGroupLayout);
        },

        ...this.computePipelines.interface(true),

        /* ---------------------- Device ---------------------- */

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The bind group.
         */
        webgpuDeviceCreateBindGroup: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);
          const { ptr: lp, len: ll } = this.readSlice(off); // 0 label
          const layout = this.bindGroupLayouts.getPacked(off(16, 8)); // 8
          const { ptr: ep, len: el } = this.readSlice(off); // 24 entries

          const descriptor = {
            label: ll > 0 ? this.mem.loadString(lp, ll) : undefined,
            layout,
            entries: this.array(el, ep, (p) => this.BindGroupEntry(p), 48),
          };

          const bindGroup = device.createBindGroup(descriptor);
          this.bindGroups.storePacked(outPtr, this.bindGroups.create(bindGroup));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The bind group layout.
         */
        webgpuDeviceCreateBindGroupLayout: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);
          const { ptr: lp, len: ll } = this.readSlice(off); // 0 label
          const { ptr: ep, len: el } = this.readSlice(off); // 8 entries

          const descriptor = {
            label: ll > 0 ? this.mem.loadString(lp, ll) : undefined,
            entries: this.array(el, ep, (p) => this.BindGroupLayoutEntry(p), 48),
          };

          const layout = device.createBindGroupLayout(descriptor);
          this.bindGroupLayouts.storePacked(outPtr, this.bindGroupLayouts.create(layout));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The buffer.
         */
        webgpuDeviceCreateBuffer: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);

          /** @type {GPUBufferDescriptor} */
          const descriptor = {
            label: this.StringView(off(this.sizes.StringView)),
            usage: this.mem.loadU64(off(8)),
            size: this.mem.loadU64(off(8)),
            mappedAtCreation: this.mem.loadB32(off(4)),
          };

          const buffer = device.createBuffer(descriptor);
          const buffer_handle = this.buffers.create({ buffer: buffer, mapping: null });
          this.buffers.storePacked(outPtr, buffer_handle);
        },

        /**
         * @param {number} deviceIdx
         * @param {0|number} descriptorPtr
         * @returns {number} The command encoder.
         */
        webgpuDeviceCreateCommandEncoder: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);

          /** @type {GPUCommandEncoderDescriptor} */
          let descriptor;
          if (descriptorPtr != 0) {
            const off = this.struct(descriptorPtr);
            descriptor = {
              label: this.StringView(off(this.sizes.StringView)),
            };
          }

          const commandEncoder = device.createCommandEncoder(descriptor);
          this.commandEncoders.storePacked(outPtr, this.commandEncoders.create(commandEncoder));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The compute pipeline.
         */
        webgpuDeviceCreateComputePipeline: (deviceIdx, descriptorPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);
          const computePipeline = device.createComputePipeline(
            this.ComputePipelineDescriptor(descriptorPtr),
          );
          return this.computePipelines.create(computePipeline);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @param {number} callbackInfo
         */
        webgpuDeviceCreateComputePipelineAsync: (deviceIdx, descriptorPtr, callbackInfoPtr) => {
          const device = this.devices.get(deviceIdx);

          this.assert(descriptorPtr != 0);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          device
            .createComputePipelineAsync(this.ComputePipelineDescriptor(descriptorPtr))
            .catch((e) => {
              const messageAddr = this.makeMessageArg(e.message);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('CreatePipelineAsyncStatus', 'ValidationError'),
                0,
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            })
            .then((computePipeline) => {
              const pipelineIdx = this.computePipelines.create(computePipeline);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('CreatePipelineAsyncStatus', 'Success'),
                pipelineIdx,
                this.zeroMessageArg(),
              ]);
            });

          // TODO: returning futures?
          return BigInt(0);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The pipeline layout.
         */
        webgpuDeviceCreatePipelineLayout: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);
          const { ptr: lp, len: ll } = this.readSlice(off); // 0 label
          const { ptr: bp, len: bl } = this.readSlice(off); // 8 bind_group_layouts
          off(4); // 16 immediate_size (no web equivalent)

          /** @type {GPUPipelineLayoutDescriptor} */
          const descriptor = {
            label: ll > 0 ? this.mem.loadString(lp, ll) : undefined,
            bindGroupLayouts: this.array(
              bl,
              bp,
              (p) => this.bindGroupLayouts.getPacked(p), // each element is a {device, handle} struct
              16,
            ),
          };

          if (this.mem.loadU32(descriptorPtr + 16) !== 0) {
            console.warn('immediate_size is not supported on the web, ignoring');
          }

          const pipelineLayout = device.createPipelineLayout(descriptor);
          this.pipelineLayouts.storePacked(outPtr, this.pipelineLayouts.create(pipelineLayout));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The query set.
         */
        webgpuDeviceCreateQuerySet: (deviceIdx, descriptorPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);
          off(4);

          /** @type {GPUQuerySetDescriptor} */
          const descriptor = {
            label: this.StringView(off(this.sizes.StringView)),
            type: this.odinEnum('QueryType', off(4)),
            count: this.mem.loadU32(off(4)),
          };

          const querySet = device.createQuerySet(descriptor);
          return this.querySets.create(querySet);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The query set.
         */
        webgpuDeviceCreateRenderBundleEncoder: (deviceIdx, descriptorPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);
          off(4);

          const colorFormatsDataOff = off(4);
          const colorFormatsData = this.mem.loadPtr(colorFormatsDataOff);

          const colorFormatsLenOff = off(this.mem.intSize);
          const colorFormatsLen = this.mem.loadUint(colorFormatsLenOff);

          /** @type {GPURenderBundleEncoderDescriptor} */
          const descriptor = {
            label: this.StringView(off(this.sizes.StringView)),
            colorFormats: this.array(colorFormatsLen, colorFormatsData, this.TextureFormat, 4),
            depthStencilFormat: this.odinEnum('TextureFormat', off(4)),
            sampleCount: this.mem.loadU32(off(4)),
            depthReadOnly: this.mem.loadB32(off(4)),
            stencilReadOnly: this.mem.loadB32(off(4)),
          };

          const renderBundleEncoder = device.createRenderBundleEncoder(descriptor);
          return this.renderBundleEncoders.create(renderBundleEncoder);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @param {number} outPtr `gpu.Handle_Packed` the new pipeline is written to.
         */
        webgpuDeviceCreateRenderPipeline: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);
          this.assert(outPtr != 0);

          const descriptor = this.RenderPipelineDescriptor(descriptorPtr);
          const renderPipeline = device.createRenderPipeline(descriptor);

          this.renderPipelines.storePacked(outPtr, this.renderPipelines.create(renderPipeline));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @param {number} callbackInfo
         */
        webgpuDeviceCreateRenderPipelineAsync: (deviceIdx, descriptorPtr, callbackInfoPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          device
            .createRenderPipelineAsync(this.RenderPipelineDescriptor(descriptorPtr))
            .catch((e) => {
              const messageAddr = this.makeMessageArg(e.message);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('CreatePipelineAsyncStatus', 'Unknown'),
                0,
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            })
            .then((renderPipeline) => {
              const renderPipelineIdx = this.renderPipelines.create(renderPipeline);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('CreatePipelineAsyncStatus', 'Success'),
                renderPipelineIdx,
                this.zeroMessageArg(),
              ]);
            });

          // TODO: returning futures?
          return BigInt(0);
        },

        /**
         * @param {number} deviceIdx
         * @param {0|number} descriptorPtr
         * @returns {number} The sampler.
         */
        webgpuDeviceCreateSampler: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);

          /** @type {?GPUSamplerDescriptor} */
          let descriptor;
          if (descriptorPtr != 0) {
            const off = this.struct(descriptorPtr);
            descriptor = {
              label: this.StringView(off(this.sizes.StringView)),
              addressModeU: this.odinEnum('AddressMode', off(4)),
              addressModeV: this.odinEnum('AddressMode', off(4)),
              addressModeW: this.odinEnum('AddressMode', off(4)),
              magFilter: this.odinEnum('FilterMode', off(4)),
              minFilter: this.odinEnum('FilterMode', off(4)),
              mipmapFilter: this.odinEnum('MipmapFilterMode', off(4)),
              lodMinClamp: this.mem.loadF32(off(4)),
              lodMaxClamp: this.mem.loadF32(off(4)),
              compare: this.odinEnum('CompareFunction', off(4)),
              maxAnisotropy: this.mem.loadU16(off(2)),
            };
          }

          const sampler = device.createSampler(descriptor);
          const sampler_handle = this.samplers.create(sampler);
          this.samplers.storePacked(outPtr, sampler_handle);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The shader module.
         */
        webgpuDeviceCreateShaderModule: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const off = this.struct(descriptorPtr);

          /** @type {GPUShaderModuleDescriptor} */
          const descriptor = {
            label: this.StringView(off(this.sizes.StringView)),
            code: this.StringView(off(this.sizes.StringView)),
          };

          const shaderModule = device.createShaderModule(descriptor);
          this.shaderModules.storePacked(outPtr, this.shaderModules.create(shaderModule));
        },

        /**
         * @param {number} deviceIdx
         * @param {number} descriptorPtr
         * @returns {number} The texture.
         */
        webgpuDeviceCreateTexture: (deviceIdx, descriptorPtr, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.assert(descriptorPtr != 0);

          const descriptor = this.TextureDescriptor(descriptorPtr);
          const texture = device.createTexture(descriptor);
          this.textures.storePacked(outPtr, this.textures.create(texture));
        },

        /**
         * @param {number} deviceIdx
         */
        webgpuDeviceDestroy: (deviceIdx) => {
          const device = this.devices.get(deviceIdx);
          device.destroy();
        },

        /**
         * @param {number} deviceIdx
         * @param {number} infoPtr
         * @returns {number}
         */
        webgpuDeviceGetAdapterInfo: (deviceIdx, infoPtr) => {
          const device = this.devices.get(deviceIdx);
          if (!device) return STATUS_ERROR;
          return this.genericGetAdapterInfo(infoPtr, device.adapterInfo);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} featuresPtr
         */
        webgpuDeviceGetFeatures: (deviceIdx, featuresPtr) => {
          const device = this.devices.get(deviceIdx);
          this.genericGetFeatures(device.features, featuresPtr);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} limitsPtr
         * @returns {number}
         */
        webgpuDeviceGetLimits: (deviceIdx, limitsPtr) => {
          const device = this.devices.get(deviceIdx);
          return this.genericGetLimits(device.limits, limitsPtr);
        },

        /**
         * @param {number} deviceIdx
         * @returns {number}
         */
        webgpuDeviceGetLostFuture: (deviceIdx) => {
          // TODO: futures?
          return BigInt(0);
        },

        /**
         * @param {number} deviceIdx
         * @returns {number}
         */
        webgpuDeviceGetQueue: (deviceIdx, outPtr) => {
          const device = this.devices.get(deviceIdx);
          this.queues.storePacked(outPtr, device ? this.queues.create(device.queue) : 0n);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} featureInt
         * @returns {boolean}
         */
        webgpuDeviceHasFeature: (deviceIdx, featureInt) => {
          const device = this.devices.get(deviceIdx);
          return device.features.has(ENUMS.FeatureName[featureInt]);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} callbackInfo
         * @returns {number}
         */
        webgpuDevicePopErrorScope: (deviceIdx, callbackInfoPtr) => {
          const device = this.devices.get(deviceIdx);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          device
            .popErrorScope()
            .catch((e) => {
              const messageAddr = this.makeMessageArg(e.message);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('PopErrorScopeStatus', 'Error'),
                this.odinEnumValue('ErrorType', 'unknown'),
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            })
            .then((error) => {
              if (!error) {
                this.callCallback(callbackInfo, [
                  this.odinEnumValue('PopErrorScopeStatus', 'Success'),
                  this.odinEnumValue('ErrorType', 'no-error'),
                  this.zeroMessageArg(),
                ]);
                return;
              }

              let status;
              if (error instanceof GPUValidationError) {
                status = this.odinEnumValue('ErrorType', 'validation');
              } else if (error instanceof GPUOutOfMemoryError) {
                status = this.odinEnumValue('ErrorType', 'out-of-memory');
              } else if (error instanceof GPUInternalError) {
                status = this.odinEnumValue('ErrorType', 'internal');
              } else {
                status = this.odinEnumValue('ErrorType', 'unknown');
              }

              const messageAddr = error.message;
              this.callCallback(callbackInfo, [
                this.odinEnumValue('PopErrorScopeStatus', 'Success'),
                status,
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            });

          // TODO: futures?
          return BigInt(0);
        },

        /**
         * @param {number} deviceIdx
         * @param {number} filterInt
         */
        webgpuDevicePushErrorScope: (deviceIdx, filterInt) => {
          const device = this.devices.get(deviceIdx);
          device.pushErrorScope(ENUMS.ErrorFilter[filterInt]);
        },

        ...this.devices.interface(true),

        /* ---------------------- ExternalTexture ---------------------- */

        ...this.externalTextures.interface(true),

        /* ---------------------- Instance ---------------------- */

        /**
         * @param {number} instanceIdx
         * @param {number} descriptorPtr
         */
        webgpuInstanceCreateSurface: (instanceIdx, descriptorPtr) => {
          this.assert(instanceIdx > 0);
          this.assert(descriptorPtr != 0);

          // Note: descriptorPtr is Surface_Source_Canvas_HTML_Selector
          const selector = this.StringView(descriptorPtr);

          const surface = document.querySelector(selector);
          if (!surface) throw new Error(`Selector '${selector}' did not match any element`);
          if (!(surface instanceof HTMLCanvasElement))
            throw new Error('Selector matches an element that is not a canvas');

          return this.surfaces.create(surface);
        },

        /**
         * @param {number} instanceIdx
         * @param {number} featurePtr
         */
        webgpuInstanceGetWGSLLanguageFeatures: (instanceIdx, featuresPtr) => {
          this.assert(featuresPtr != 0);

          const availableFeatures = [];
          ENUMS.WGSLLanguageFeatureName.forEach((feature, value) => {
            if (!feature) {
              return;
            }

            if (navigator.gpu.wgslLanguageFeatures.has(feature)) {
              availableFeatures.push(value);
            }
          });

          if (availableFeatures.length === 0) {
            return;
          }

          const featuresAddr = this.mem.exports.js_alloc(availableFeatures.length * 4);
          this.assert(featuresAddr != 0);

          let off = this.struct(featuresPtr);
          this.mem.storeI32(off(4), featuresAddr);
          this.mem.storeUint(off(this.mem.intSize), availableFeatures.length);

          off = this.struct(featuresAddr);
          for (let i = 0; i < availableFeatures.length; i += 1) {
            this.mem.storeI32(off(4), availableFeatures[i]);
          }
        },

        /**
         * @param {number} instanceIdx
         * @param {number} featureInt
         * @returns {boolean}
         */
        webgpuInstanceHasWGSLLanguageFeature: (instanceIdx, featureInt) => {
          return navigator.gpu.wgslLanguageFeatures.has(ENUMS.WGSLLanguageFeatureName[featureInt]);
        },

        /**
         * @param {number} instanceIdx
         */
        webgpuInstanceProcessEvents: (instanceIdx) => {
          console.warn('unimplemented: wgpuInstanceProcessEvents');
        },

        /**
         * @param {number} instanceIdx
         * @param {0|number} optionsPtr
         * @returns {number}
         */
        webgpuInstanceRequestAdapter: new WebAssembly.Suspending(
          async function (instanceIdx, optionsPtr) {
            this.assert(instanceIdx > 0);

            let options;
            if (optionsPtr != 0) {
              const off = this.struct(optionsPtr);
              off(4); // featureLevel
              options = {
                powerPreference: this.odinEnum('PowerPreference', off(4)),
                forceFallbackAdapter: this.mem.loadB32(off(4)),
              };
            }

            const adapter = await navigator.gpu.requestAdapter(options);
            if (!adapter) return 0;
            return this.adapters.create(adapter);
          }.bind(this),
        ),

        webgpuInstanceWaitAny: (instanceIdx, futureCount, futuresPtr, timeoutNS) => {
          // TODO: futures?
          console.warn('unimplemented: wgpuInstanceProcessEvents');
          return BigInt(0);
        },

        ...this.instances.interface(false),

        /* ---------------------- PipelineLayout ---------------------- */

        ...this.pipelineLayouts.interface(true),

        /* ---------------------- QuerySet ---------------------- */

        /**
         * @param {number} querySetIdx
         */
        webgpuQuerySetDestroy: (querySetIdx) => {
          const querySet = this.querySets.get(querySetIdx);
          querySet.destroy();
        },

        /**
         * @param {number} querySetIdx
         * @returns {number}
         */
        webgpuQuerySetGetCount: (querySetIdx) => {
          const querySet = this.querySets.get(querySetIdx);
          return querySet.count;
        },

        /**
         * @param {number} querySetIdx
         * @returns {number}
         */
        webgpuQuerySetGetType: (querySetIdx) => {
          const querySet = this.querySets.get(querySetIdx);
          return this.odinEnumValue('QueryType', querySet.type);
        },

        ...this.querySets.interface(true),

        /* ---------------------- Queue ---------------------- */

        /**
         * @param {number} queueIdx
         * @param {number} callbackInfo
         */
        webgpuQueueOnSubmittedWorkDone: (queueIdx, callbackInfoPtr) => {
          const queue = this.queues.getPacked(queueIdx);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          queue
            .onSubmittedWorkDone()
            .catch((e) => {
              console.warn(e);
              const messageAddr = this.makeMessageArg(e.message);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('QueueWorkDoneStatus', 'Error'),
                messageAddr,
              ]);
              this.mem.exports.js_free(messageAddr);
            })
            .then(() => {
              this.callCallback(callbackInfo, [
                this.odinEnumValue('QueueWorkDoneStatus', 'Success'),
                this.zeroMessageArg(),
              ]);
            });

          // TODO: futures?
          return BigInt(0);
        },

        /**
         * @param {number} queuePtr
         * @param {BigInt|number} commandCount
         * @param {number} commandsPtr
         */
        webgpuQueueSubmit: (queuePtr, commandsSlicePtr) => {
          const queue = this.queues.getPacked(queuePtr);
          this.assert(queue !== undefined);

          const { ptr: dataPtr, len: count } = this.loadSlice(commandsSlicePtr);

          const commands = [];
          for (let i = 0; i < count; i++) {
            const cb = this.commandBuffers.getPacked(dataPtr + i * 16);
            this.assert(cb !== undefined);
            commands.push(cb);
          }
          queue.submit(commands);
        },

        /**
         * @param {number} queueIdx
         * @param {number} bufferIdx
         * @param {BigInt} bufferOffset
         * @param {number} dataPtr
         * @param {number|BigInt} size
         */
        webgpuQueueWriteBuffer: (queueIdx, bufferIdx, bufferOffset, dataPtr, size) => {
          const queue = this.queues.getPacked(queueIdx);
          const buffer = this.buffers.getPacked(bufferIdx);
          bufferOffset = this.unwrapBigInt(bufferOffset);
          size = this.unwrapBigInt(size);
          queue.writeBuffer(
            buffer.buffer,
            bufferOffset,
            this.mem.loadBytes(dataPtr, size),
            0,
            size,
          );
        },

        /**
         * @param {number} queueIdx
         * @param {number} destinationPtr
         * @param {number} dataPtr
         * @param {number|BigInt} dataSize
         * @param {number} dataLayoutPtr
         * @param {number} writeSizePtr
         */
        webgpuQueueWriteTexture: (
          queuePtr,
          destinationPtr,
          dataPtr,
          dataSize,
          dataLayoutPtr,
          writeSizePtr,
        ) => {
          const queue = this.queues.getPacked(queuePtr);
          const destination = this.TexelCopyTextureInfo(destinationPtr);
          const layout = this.TexelCopyBufferLayout(dataLayoutPtr);
          const writeSize = this.Extent3D(writeSizePtr);
          const size = Number(dataSize);

          if (!destination.texture) console.error('write_texture: texture did not resolve');

          queue.writeTexture(destination, this.mem.loadBytes(dataPtr, size), layout, writeSize);
        },

        ...this.queues.interface(true),

        /* ---------------------- RenderBundle ---------------------- */

        ...this.renderBundles.interface(true),

        /* ---------------------- RenderBundleEncoder ---------------------- */

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} vertexCount
         * @param {number} instanceCount
         * @param {number} firstVertex
         * @param {number} firstInstance
         */
        webgpuRenderBundleEncoderDraw: (
          renderBundleEncoderIdx,
          vertexCount,
          instanceCount,
          firstVertex,
          firstInstance,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          renderBundleEncoder.draw(vertexCount, instanceCount, firstVertex, firstInstance);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} indexCount
         * @param {number} instanceCount
         * @param {number} firstIndex
         * @param {number} baseVertex
         * @param {number} firstInstance
         */
        webgpuRenderBundleEncoderDrawIndexed: (
          renderBundleEncoderIdx,
          indexCount,
          instanceCount,
          firstIndex,
          baseVertex,
          firstInstance,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          renderBundleEncoder.drawIndexed(
            indexCount,
            instanceCount,
            firstIndex,
            baseVertex,
            firstInstance,
          );
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} indirectBufferIdx
         * @param {BigInt} indirectOffset
         */
        webgpuRenderBundleEncoderDrawIndexedIndirect: (
          renderBundleEncoderIdx,
          indirectBufferIdx,
          indirectOffset,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          indirectOffset = this.unwrapBigInt(indirectOffset);
          const buffer = this.buffers.getPacked(indirectBufferIdx);
          renderBundleEncoder.drawIndexedIndirect(buffer.buffer, indirectOffset);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} indirectBufferIdx
         * @param {BigInt} indirectOffset
         */
        webgpuRenderBundleEncoderDrawIndirect: (
          renderBundleEncoderIdx,
          indirectBufferIdx,
          indirectOffset,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          indirectOffset = this.unwrapBigInt(indirectOffset);
          const buffer = this.buffers.getPacked(indirectBufferIdx);
          renderBundleEncoder.drawIndirect(buffer.buffer, indirectOffset);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {0|number} descriptorPtr
         * @returns {number}
         */
        webgpuRenderBundleEncoderFinish: (renderBundleEncoderIdx, descriptorPtr) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);

          /** @type {?GPURenderBundleDescriptor} */
          let descriptor;
          if (descriptorPtr != 0) {
            descriptor = {
              label: this.StringView(descriptorPtr + 4),
            };
          }

          const renderBundle = renderBundleEncoder.finish(descriptor);
          return this.renderBundles.create(renderBundle);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} markerLabelPtr
         * @param {number} markerLabelLen
         */
        webgpuRenderBundleEncoderInsertDebugMarker: (
          renderBundleEncoderIdx,
          markerLabelPtr,
          markerLabelLen,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          this.assert(markerLabelPtr != 0);
          const markerLabel = this.mem.loadString(markerLabelPtr, markerLabelLen);
          renderBundleEncoder.insertDebugMarker(markerLabel);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         */
        webgpuRenderBundleEncoderPopDebugGroup: (renderBundleEncoderIdx) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          renderBundleEncoder.popDebugGroup();
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} groupLabelPtr
         * @param {number} grouplabelLen
         */
        webgpuRenderBundleEncoderPushDebugGroup: (
          renderBundleEncoderIdx,
          groupLabelPtr,
          grouplabelLen,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          this.assert(groupLabelPtr != 0);
          const groupLabel = this.mem.loadString(groupLabelPtr, groupLabelLen);
          renderBundleEncoder.pushDebugGroup(groupLabel);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} groupIndex
         * @param {0|number} groupIdx
         * @param {number} dynamicOffsetsPtr
         * @param {number|BigInt} dynamicOffsetCount
         */
        webgpuRenderBundleEncoderSetBindGroup: (
          renderBundleEncoderIdx,
          groupIndex,
          groupIdx,
          dynamicOffsetCount,
          dynamicOffsetsPtr,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);

          let group;
          if (groupIdx > 0) {
            group = this.bindGroups.getPacked(groupIdx);
          }

          dynamicOffsetCount = this.unwrapBigInt(dynamicOffsetCount);
          const dynamicOffsets = this.array(
            dynamicOffsetCount,
            dynamicOffsetsPtr,
            (ptr) => this.mem.loadU32(ptr),
            4,
          );

          renderBundleEncoder.setBindGroup(groupIndex, group, dynamicOffsets);
        },

        webgpuRenderBundleEncoderSetImmediates: (renderBundleEncoderIdx, offset, data, size) => {
          //
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} bufferIdx
         * @param {number} formatInt
         * @param {BigInt} offset
         * @param {BigInt} size
         */
        webgpuRenderBundleEncoderSetIndexBuffer: (
          renderBundleEncoderIdx,
          bufferIdx,
          formatInt,
          offset,
          size,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          const buffer = this.buffers.getPacked(bufferIdx);
          const format = this.odinEnumValue('IndexFormat', formatInt);
          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);
          renderBundleEncoder.setIndexBuffer(buffer.buffer, format, offset, size);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} pipelineIdx
         */
        webgpuRenderBundleEncoderSetPipeline: (renderBundleEncoderIdx, pipelineIdx) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);
          const pipeline = this.renderPipelines.getPacked(pipelineIdx);
          renderBundleEncoder.setPipeline(pipeline);
        },

        /**
         * @param {number} renderBundleEncoderIdx
         * @param {number} slot
         * @param {0|number} bufferIdx
         * @param {BigInt} offset
         * @param {BigInt} size
         */
        webgpuRenderBundleEncoderSetVertexBuffer: (
          renderBundleEncoderIdx,
          slot,
          bufferIdx,
          offset,
          size,
        ) => {
          const renderBundleEncoder = this.renderBundleEncoders.get(renderBundleEncoderIdx);

          let buffer;
          if (bufferIdx > 0) {
            buffer = this.buffers.getPacked(bufferIdx).buffer;
          }

          offset = this.unwrapBigInt(offset);
          size = this.unwrapBigInt(size);
          renderBundleEncoder.setVertexBuffer(slot, buffer, offset, size);
        },

        ...this.renderBundleEncoders.interface(true),

        /* ---------------------- RenderPassEncoder ---------------------- */

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} queryIndex
         */
        webgpuRenderPassEncoderBeginOcclusionQuery: (renderPassEncoderIdx, queryIndex) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.beginOcclusionQuery(queryIndex);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} vertexCount
         * @param {number} instanceCount
         * @param {number} firstVertex
         * @param {number} firstInstance
         */
        webgpuRenderPassEncoderDraw: (
          renderPassEncoderIdx,
          vertexCount,
          instanceCount,
          firstVertex,
          firstInstance,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.draw(vertexCount, instanceCount, firstVertex, firstInstance);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} indexCount
         * @param {number} instanceCount
         * @param {number} firstIndex
         * @param {number} baseVertex
         * @param {number} firstInstance
         */
        webgpuRenderPassEncoderDrawIndexed: (
          renderPassEncoderIdx,
          indexCount,
          instanceCount,
          firstIndex,
          baseVertex,
          firstInstance,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.drawIndexed(
            indexCount,
            instanceCount,
            firstIndex,
            baseVertex,
            firstInstance,
          );
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} indirectBufferIdx
         * @param {BigInt} indirectOffset
         */
        webgpuRenderPassEncoderDrawIndexedIndirect: (
          renderPassEncoderIdx,
          indirectBufferIdx,
          indirectOffset,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const buffer = this.buffers.getPacked(indirectBufferIdx);
          indirectOffset = this.unwrapBigInt(indirectOffset);
          renderPassEncoder.drawIndexedIndirect(buffer.buffer, indirectOffset);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} indirectBufferIdx
         * @param {BigInt} indirectOffset
         */
        webgpuRenderPassEncoderDrawIndirect: (
          renderPassEncoderIdx,
          indirectBufferIdx,
          indirectOffset,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const buffer = this.buffers.getPacked(indirectBufferIdx);
          indirectOffset = this.unwrapBigInt(indirectOffset);
          renderPassEncoder.drawIndirect(buffer.buffer, indirectOffset);
        },

        /**
         * @param {number} renderPassPtr
         */
        webgpuRenderPassEncoderEnd: (renderPassPtr) => {
          /** @type {GPURenderPassEncoder} */
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassPtr);
          this.assert(renderPassEncoder != undefined);
          renderPassEncoder.end();
        },

        /**
         * @param {number} renderPassEncoderIdx
         */
        webgpuRenderPassEncoderEndOcclusionQuery: (renderPassEncoderIdx) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.endOcclusionQuery();
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} bundlesPtr
         * @param {number|BigInt} bundleCount
         */
        webgpuRenderPassEncoderExecuteBundles: (renderPassEncoderIdx, bundleCount, bundlesPtr) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          bundleCount = this.unwrapBigInt(bundleCount);
          const bundles = this.array(
            bundleCount,
            bundlesPtr,
            (ptr) => this.renderBundles.get(this.mem.loadPtr(ptr)),
            4,
          );
          renderPassEncoder.executeBundles(bundles);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} markerLabelPtr
         * @param {number} markerLabelLen
         */
        webgpuRenderPassEncoderInsertDebugMarker: (
          renderPassEncoderIdx,
          markerLabelPtr,
          markerLabelLen,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const markerLabel = this.mem.loadString(markerLabelPtr, markerLabelLen);
          renderPassEncoder.insertDebugMarker(markerLabel);
        },

        /**
         * @param {number} renderPassEncoderIdx
         */
        webgpuRenderPassEncoderPopDebugGroup: (renderPassEncoderIdx) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.popDebugGroup();
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} groupLabelPtr
         * @param {number} groupLabelLen
         */
        webgpuRenderPassEncoderPushDebugGroup: (
          renderPassEncoderIdx,
          groupLabelPtr,
          groupLabelLen,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const groupLabel = this.mem.loadString(groupLabelPtr, groupLabelLen);
          renderPassEncoder.pushDebugGroup(groupLabel);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} groupIndex
         * @param {0|number} groupIdx
         * @param {number} dynamicOffsetsPtr
         * @param {number|BigInt} dynamicOffsetCount
         */
        webgpuRenderPassEncoderSetBindGroup: (
          passPtr,
          groupIndex,
          groupPtr,
          dynamicOffsetsPtr,
          dynamicOffsetCount,
        ) => {
          const pass = this.renderPassEncoders.getPacked(passPtr);
          const group = this.bindGroups.getPacked(groupPtr);

          const offsets = [];
          for (let i = 0; i < dynamicOffsetCount; i++) {
            offsets.push(this.mem.loadU32(dynamicOffsetsPtr + i * 4));
          }

          pass.setBindGroup(groupIndex, group ?? null, offsets);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} colorPtr
         */
        webgpuRenderPassEncoderSetBlendConstant: (renderPassEncoderIdx, colorPtr) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          this.assert(colorPtr != 0);
          renderPassEncoder.setBlendConstant(this.Color(colorPtr));
        },

        webgpuRenderPassEncoderSetImmediates: (renderPassEncoderIdx, offset, data, size) => {
          //
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} bufferIdx
         * @param {number} formatInt
         * @param {BigInt} offset
         * @param {BigInt} size
         */
        webgpuRenderPassEncoderSetIndexBuffer: (
          renderPassEncoderIdx,
          bufferIdx,
          formatInt,
          offset,
          size,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const buffer = this.buffers.getPacked(bufferIdx);
          const format = this.odinEnumValue('IndexFormat', formatInt);
          offset = this.unwrapBigInt(offset);
          size = this.toOptionalSize64(size);
          renderPassEncoder.setIndexBuffer(buffer.buffer, format, offset, size);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} pipelineIdx
         */
        webgpuRenderPassEncoderSetPipeline: (renderPassEncoderIdx, pipelineIdx) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          const pipeline = this.renderPipelines.getPacked(pipelineIdx);
          renderPassEncoder.setPipeline(pipeline);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} x
         * @param {number} y
         * @param {number} width
         * @param {number} height
         */
        webgpuRenderPassEncoderSetScissorRect: (renderPassEncoderIdx, x, y, width, height) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.setScissorRect(x, y, width, height);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} reference
         */
        webgpuRenderPassEncoderSetStencilReference: (renderPassEncoderIdx, reference) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.setStencilReference(reference);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} slot
         * @param {0|number} bufferIdx
         * @param {BigInt} offset
         * @param {BigInt} size
         */
        webgpuRenderPassEncoderSetVertexBuffer: (
          renderPassEncoderIdx,
          slot,
          bufferIdx,
          offset,
          size,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);

          let buffer;
          if (bufferIdx > 0) {
            buffer = this.buffers.getPacked(bufferIdx).buffer;
          }

          offset = this.unwrapBigInt(offset);
          size = this.toOptionalSize64(size);
          renderPassEncoder.setVertexBuffer(slot, buffer, offset, size);
        },

        /**
         * @param {number} renderPassEncoderIdx
         * @param {number} x
         * @param {number} y
         * @param {number} width
         * @param {number} height
         * @param {number} minDepth
         * @param {number} maxDepth
         */
        webgpuRenderPassEncoderSetViewport: (
          renderPassEncoderIdx,
          x,
          y,
          width,
          height,
          minDepth,
          maxDepth,
        ) => {
          const renderPassEncoder = this.renderPassEncoders.getPacked(renderPassEncoderIdx);
          renderPassEncoder.setViewport(x, y, width, height, minDepth, maxDepth);
        },

        ...this.renderPassEncoders.interface(true),

        /* ---------------------- RenderPipeline ---------------------- */

        /**
         * @param {number} renderPipelineIdx
         * @param {number} groupIndex
         * @returns {number}
         */
        webgpuRenderPipelineGetBindGroupLayout: (renderPipelineIdx, groupIndex) => {
          const renderPipeline = this.renderPipelines.getPacked(renderPipelineIdx);
          const bindGroupLayout = renderPipeline.getBindGroupLayout(groupIndex);
          return this.bindGroupLayouts.create(bindGroupLayout);
        },

        ...this.renderPipelines.interface(true),

        /* ---------------------- Sampler ---------------------- */

        ...this.samplers.interface(true),

        /* ---------------------- ShaderModule ---------------------- */

        /**
         * @param {number} shaderModuleIdx
         * @param {number} callbackInfo
         */
        webgpuShaderModuleGetCompilationInfo: (shaderModuleIdx, callbackInfoPtr) => {
          const shaderModule = this.shaderModules.getPacked(shaderModuleIdx);

          const callbackInfo = this.CallbackInfo(callbackInfoPtr);
          shaderModule
            .getCompilationInfo()
            .catch((e) => {
              console.warn(e);
              this.callCallback(callbackInfo, [
                this.odinEnumValue('CompilationInfoRequestStatus', 'CallbackCancelled'),
                null,
              ]);
            })
            .then((compilationInfo) => {
              const ptrsToFree = [];

              const compilationMessageSize = this.sizes.CompilationMessage[0];

              const size = compilationInfo.messages.length * compilationMessageSize;

              const addr = this.mem.exports.js_alloc(size);
              ptrsToFree.push(addr);

              compilationInfo.messages.forEach((message, i) => {
                const messageLength = new TextEncoder().encode(message.message).length;
                const messageAddr = this.mem.exports.js_alloc(messageLength);
                ptrsToFree.push(messageAddr);
                this.mem.storeString(messageAddr, message.message);

                const off = this.struct(addr + i * compilationMessageSize);
                off(4);

                const messageStart = off(this.sizes.StringView);
                this.mem.storeI32(messageStart, messageAddr);
                this.mem.storeUint(messageStart + this.mem.intSize, messageLength);

                this.mem.storeI32(
                  off(4),
                  this.odinEnumValue('CompilationMessageType', message.type),
                );

                this.mem.storeU64(off(8), message.lineNum);
                this.mem.storeU64(off(8), message.linePos);
                this.mem.storeU64(off(8), message.offset);
                this.mem.storeU64(off(8), message.length);
              });

              const retAddr = this.mem.exports.js_alloc(3 * this.mem.intSize);
              ptrsToFree.push(retAddr);
              this.mem.storeUint(retAddr + this.mem.intSize, compilationInfo.messages.length);
              this.mem.storeI32(retAddr + this.mem.intSize * 2, addr);

              this.callCallback(callbackInfo, [
                this.odinEnumValue('CompilationInfoRequestStatus', 'Success'),
                retAddr,
              ]);

              ptrsToFree.forEach((ptr) => this.mem.exports.js_free(ptr));
            });

          // TODO: futures?
          return BigInt(0);
        },

        ...this.shaderModules.interface(true),

        /* ---------------------- SupportedFeatures ---------------------- */

        webgpuSupportedFeaturesFreeMembers: (supportedFeaturesCount, supportedFeaturesPtr) => {
          this.mem.exports.js_free(supportedFeaturesPtr);
        },

        /* ---------------------- SupportedInstanceFeatures ---------------------- */

        webgpuSupportedInstanceFeaturesFreeMembers: (
          supportedFeaturesCount,
          supportedFeaturesPtr,
        ) => {},

        /* ---------------------- SupportedWGSLLanguageFeatures ---------------------- */

        webgpuSupportedWGSLLanguageFeaturesFreeMembers: (
          supportedFeaturesCount,
          supportedFeaturesPtr,
        ) => {
          this.mem.exports.js_free(supportedFeaturesPtr);
        },

        /* ---------------------- Surface ---------------------- */

        /**
         * @param {number} surfaceIdx
         * @param {number} configPtr
         */
        webgpuSurfaceConfigure: (surfaceIdx, configPtr) => {
          /** @type {GPUSurface} */
          const surface = this.surfaces.get(surfaceIdx);
          /** @type {GPUCanvasContext} */
          const context = surface.getContext('webgpu');

          const off = this.struct(configPtr);

          const deviceIdx = this.mem.loadPtr(off(4));
          const device = this.devices.get(deviceIdx);
          const usage = this.mem.loadU32(off(8));
          const format = this.odinEnum('TextureFormat', off(4));
          const colorSpaceValue = this.mem.loadU32(off(4));
          const width = this.mem.loadU32(off(4));
          const height = this.mem.loadU32(off(4));
          off(4); // present_mode (unused in browsers)
          off(4); // desired_maximum_frame_latency (unused)
          const alphaModeValue = this.odinEnum('CompositeAlphaMode', off(4));

          const viewFormatsPtr = this.mem.loadPtr(off(4));
          const viewFormatsLen = this.mem.loadUint(off(this.mem.intSize));
          const viewFormats =
            viewFormatsLen > 0
              ? this.array(
                  viewFormatsLen,
                  viewFormatsPtr,
                  (ptr) => this.odinEnum('TextureFormat', ptr),
                  4,
                )
              : [];

          // Surface_Color_Space ordinals: Srgb, Extended_Srgb_Linear, Display_P3,
          // Bt2100_Pq, Bt2100_Hlg, Extended_Srgb, Extended_Display_P3
          let colorSpace = 'srgb';
          let toneMapping = { mode: 'standard' };
          switch (colorSpaceValue) {
            case 0:
              break; // Srgb
            case 2:
              colorSpace = 'display-p3';
              break; // Display_P3
            case 5:
              toneMapping = { mode: 'extended' };
              break; // Extended_Srgb
            case 6:
              colorSpace = 'display-p3';
              toneMapping = { mode: 'extended' };
              break; // Extended_Display_P3
            default:
              console.warn(
                `Surface color space ${colorSpaceValue} is not supported by canvas, using srgb`,
              );
          }

          const alphaMode = alphaModeValue === 'auto' ? 'opaque' : alphaModeValue;

          surface.width = width;
          surface.height = height;

          /** @type {GPUCanvasConfiguration} */
          const config = {
            device,
            format,
            usage,
            viewFormats,
            alphaMode,
            colorSpace,
            toneMapping,
          };

          context.configure(config);

          surface.deviceIdx = deviceIdx;
        },

        /**
         * @param {number} surfaceIdx
         * @param {number} adapterIdx
         * @param {number} capabilitiesPtr
         * @return {number}
         */
        webgpuSurfaceGetCapabilities: (surfaceIdx, adapterIdx, capabilitiesPtr) => {
          const off = this.struct(capabilitiesPtr);

          // Odin slice: (ptr, len), in that order. len is `int`.
          const writeSlice = (ptr, len) => {
            this.mem.storeI32(off(4), ptr);
            this.mem.storeUint(off(this.mem.intSize), len);
          };

          const formatStr = navigator.gpu.getPreferredCanvasFormat();
          const format = this.odinEnumValue('TextureFormat', formatStr);

          // formats: []Texture_Format
          const formatsAddr = this.mem.exports.js_alloc(4);
          this.mem.storeI32(formatsAddr, format);
          writeSlice(formatsAddr, 1);

          // format_capabilities: []Surface_Format_Capabilities { format, color_spaces }
          const SRGB = 1 << 0; // Surface_Color_Space.Srgb
          const formatCapsAddr = this.mem.exports.js_alloc(8);
          this.mem.storeI32(formatCapsAddr + 0, format);
          this.mem.storeU32(formatCapsAddr + 4, SRGB);
          writeSlice(formatCapsAddr, 1);

          // present_modes: []Present_Mode. Browsers ignore this, so FIFO is enough.
          const presentModesAddr = this.mem.exports.js_alloc(4);
          this.mem.storeI32(presentModesAddr, this.odinEnumValue('PresentMode', 'fifo'));
          writeSlice(presentModesAddr, 1);

          // alpha_modes: []Composite_Alpha_Mode. Browsers support opaque and premultiplied.
          const alphaModesAddr = this.mem.exports.js_alloc(8);
          this.mem.storeI32(alphaModesAddr + 0, this.odinEnumValue('CompositeAlphaMode', 'opaque'));
          this.mem.storeI32(
            alphaModesAddr + 4,
            this.odinEnumValue('CompositeAlphaMode', 'premultiplied'),
          );
          writeSlice(alphaModesAddr, 2);

          // usages: Texture_Usages (bit_set, 4 bytes). Canvas textures support these.
          // Bit positions = ordinals of YOUR Odin Texture_Usage enum. Adjust if the order differs.
          const USAGE = {
            Copy_Src: 0,
            Copy_Dst: 1,
            Texture_Binding: 2,
            Storage_Binding: 3,
            Render_Attachment: 4,
          };
          const usages =
            (1 << USAGE.Copy_Src) |
            (1 << USAGE.Copy_Dst) |
            (1 << USAGE.Texture_Binding) |
            (1 << USAGE.Render_Attachment);
          this.mem.storeU32(off(4), usages);

          return STATUS_SUCCESS;
        },

        /**
         * @param {number} surfaceIdx
         * @param {number} texturePtr
         */
        webgpuSurfaceGetCurrentTexture: (surfaceIdx, outPtr) => {
          /** @type GPUSurface */
          const surface = this.surfaces.get(surfaceIdx);

          // Release last frame's slot. A double release is harmless: stale handles are ignored.
          if (surface.currentTexture) {
            this.textures.release(surface.currentTexture);
            surface.currentTexture = 0n;
          }

          // Zero the struct so no field is left with garbage.
          for (let i = 0; i < 32; i += 4) this.mem.storeU32(outPtr + i, 0);

          let status = this.odinEnumValue('SurfaceGetCurrentTextureStatus', 'Success');
          try {
            const context = surface.getContext('webgpu');
            const texture = context.getCurrentTexture();
            const packed = this.textures.create(texture);
            surface.currentTexture = packed;

            this.mem.storeU32(outPtr + 8, surface.deviceIdx ?? 0); // texture.device
            this.textures.storePacked(outPtr + 16, packed); // texture.handle
          } catch (e) {
            console.warn('getCurrentTexture failed:', e);
            status = this.odinEnumValue('SurfaceGetCurrentTextureStatus', 'Lost');
          }
          this.mem.storeU32(outPtr + 24, status); // status
        },

        /**
         * @param {number} surfaceIdx
         */
        webgpuSurfacePresent: (surfaceIdx) => {
          // NOTE: Presenting a canvas is implicit in WebGPU -- the texture is
          // shown when the current task ends. Nothing to do here.
          // Must return a Status ordinal (0 == Success) for the Odin caller.
          return 0;
        },

        /**
         * @param {number} surfaceIdx
         */
        webgpuSurfaceUnconfigure: (surfaceIdx) => {
          const surface = this.surfaces.get(surfaceIdx);
          surface.getContext('webgpu').unconfigure();
        },

        ...this.surfaces.interface(true),

        /* ---------------------- SurfaceCapabilities ---------------------- */

        /**
         * @param {number} surfaceCapabilitiesPtr
         */
        webgpuSurfaceCapabilitiesFreeMembers: (surfaceCapabilitiesPtr) => {
          const off = this.struct(surfaceCapabilitiesPtr);

          // Odin slices: (ptr, len). Read the pointer, then skip the length.
          const freeSlice = () => {
            const ptr = this.mem.loadPtr(off(4));
            off(this.mem.intSize); // len
            if (ptr !== 0) {
              this.mem.exports.js_free(ptr);
            }
          };

          freeSlice(); // formats
          freeSlice(); // format_capabilities
          freeSlice(); // present_modes
          freeSlice(); // alpha_modes
          // usages is a bit_set, nothing to free
        },

        /* ---------------------- Texture ---------------------- */

        /**
         * @param {number} texturePtr
         * @param {0|number} descriptorPtr
         * @returns {number}
         */

        webgpuTextureCreateView: (texturePtr, descriptorPtr, outPtr) => {
          const texture = this.textures.getPacked(texturePtr);
          this.assert(texture !== undefined);

          const descriptor = this.TextureViewDescriptor(descriptorPtr);
          const textureView = texture.createView(descriptor);
          textureView.__format = descriptor?.format ?? texture.format;
          this.textureViews.storePacked(outPtr, this.textureViews.create(textureView));
        },

        /**
         * @param {number} textureIdx
         */
        webgpuTextureDestroy: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          texture.destroy();
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetDepthOrArrayLayers: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.depthOrArrayLayers;
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetDimension: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return this.odinEnumValue('TextureDimension', texture.dimension);
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetFormat: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return this.odinEnumValue('TextureFormat', texture.format);
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetHeight: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.height;
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetMipLevelCount: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.mipLevelCount;
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetSampleCount: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.sampleCount;
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetTextureBindingViewDimension: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return this.odinEnumValue('TextureViewDimension', texture.textureBindingViewDimension);
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetUsage: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.usage;
        },

        /**
         * @param {number} textureIdx
         * @returns {number}
         */
        webgpuTextureGetWidth: (textureIdx) => {
          const texture = this.textures.getPacked(textureIdx);
          return texture.width;
        },

        ...this.textures.interface(true),

        /* ---------------------- TextureView ---------------------- */

        ...this.textureViews.interface(true),
      };
    }
  }

  /** @template T */
  class WebGPUObjectManager {
    /**
     * @param {string} name
     * @param {WasmMemoryInterface} mem
     */
    constructor(name, mem) {
      this.name = name;
      this.mem = mem;

      this.idx = 0;

      /** @type {Record<number, { references: number, object: T }>} */
      this.objects = {};
    }

    /**
     * @param {T} object
     * @returns {number}
     */
    create(object) {
      if (object === null) {
        return 0;
      }

      this.objects[this.idx] = { references: 1, object };
      this.idx += 1;
      return this.idx;
    }

    storePacked(ptr, packed) {
      const h = BigInt.asUintN(64, BigInt(packed));
      this.mem.storeU32(ptr, Number(h & 0xffffffffn));
      this.mem.storeU32(ptr + 4, Number(h >> 32n));
    }

    loadPacked(ptr) {
      const lo = this.mem.loadU32(ptr);
      const hi = this.mem.loadU32(ptr + 4);
      return (BigInt(hi) << 32n) | BigInt(lo);
    }

    /**
     * @param {?number} idx
     * @returns {T}
     */
    get(idx) {
      return this.objects[idx - 1]?.object;
    }

    /** @param {number} idx */
    release(idx) {
      if (idx === 0) {
        return;
      }

      this.objects[idx - 1].references -= 1;
      if (this.objects[idx - 1].references == 0) {
        delete this.objects[idx - 1];
      }
    }

    /** @param {number} idx */
    reference(idx) {
      if (idx === 0) {
        return;
      }

      this.objects[idx - 1].references += 1;
    }

    interface(withLabelSetter = false) {
      const inter = {};
      inter[`webgpu${this.name}AddRef`] = this.reference.bind(this);
      inter[`webgpu${this.name}Release`] = this.release.bind(this);
      if (withLabelSetter) {
        inter[`webgpu${this.name}SetLabel`] = (idx, labelPtr, labelLen) => {
          const obj = this.get(idx);
          obj.label = this.mem.loadString(labelPtr, labelLen);
        };
      }
      return inter;
    }
  }

  class WebGPUHandleManager {
    /**
     * @param {string} name
     * @param {WasmMemoryInterface} mem
     */
    constructor(name, mem) {
      this.name = name;
      this.mem = mem;
      /** @type {{ generation: number, references: number, object: T|null }[]} */
      this.slots = [{ generation: 0, references: 0, object: null }]; // index 0 reserved
      this.free = [];
    }

    /**
     * @param {T} object
     * @returns {number}
     */
    create(object) {
      if (object === null) return 0n;
      let index;
      if (this.free.length > 0) {
        index = this.free.pop();
      } else {
        index = this.slots.length;
        this.slots.push({ generation: 0, references: 0, object: null });
      }
      const slot = this.slots[index];
      slot.generation = (slot.generation + 1) >>> 0 || 1; // never 0, so a packed handle is never 0n
      slot.references = 1;
      slot.object = object;
      return (BigInt(slot.generation) << 32n) | BigInt(index);
    }

    storePacked(ptr, packed) {
      const h = BigInt.asUintN(64, BigInt(packed));
      this.mem.storeU32(ptr, Number(h & 0xffffffffn));
      this.mem.storeU32(ptr + 4, Number(h >> 32n));
    }

    loadPacked(ptr) {
      const lo = this.mem.loadU32(ptr);
      const hi = this.mem.loadU32(ptr + 4);
      return (BigInt(hi) << 32n) | BigInt(lo);
    }

    slot(packed) {
      const h = BigInt.asUintN(64, BigInt(packed));
      const slot = this.slots[Number(h & 0xffffffffn)];
      if (!slot || slot.object === null || slot.generation !== Number(h >> 32n)) {
        return undefined; // stale or invalid handle
      }
      return slot;
    }

    /** @returns {T} */
    get(packed) {
      return this.slot(packed)?.object;
    }

    /**
     * Unpacks the `u64` stored in the `handle` field of a `gpu.Handle`
     * (16 bytes: `device` @0, `handle` @8, both with 8-byte alignment).
     *
     * @param {number} ptr
     * @returns {bigint}
     */
    packedAt(ptr) {
      const lo = this.mem.loadU32(ptr + 8);
      const hi = this.mem.loadU32(ptr + 12);
      return (BigInt(hi) << 32n) | BigInt(lo);
    }

    /** @returns {T} */
    getPacked(ptr) {
      return this.get(this.packedAt(ptr));
    }

    /** @param {number} idx */
    release(packed) {
      const slot = this.slot(packed);
      if (!slot) return;
      slot.references -= 1;
      if (slot.references === 0) {
        slot.object = null; // generation stays, so old handles stop resolving
        this.free.push(Number(BigInt.asUintN(64, BigInt(packed)) & 0xffffffffn));
      }
    }

    /** @param {number} idx */
    reference(packed) {
      const slot = this.slot(packed);
      if (slot) slot.references += 1;
    }

    /**
     * Builds the `AddRef` / `Release` / `SetLabel` imports.
     *
     * Every one of those procs takes its handle by value, so the argument that
     * arrives is an address of a `gpu.Handle` and has to go through
     * `getPacked`/`packedAt` rather than being treated as a handle value.
     *
     * @param {boolean} withLabelSetter
     * @returns {Object.<string, function(number, ...any): void>>}
     */
    interface(withLabelSetter = false) {
      const inter = {};
      inter[`webgpu${this.name}AddRef`] = (ptr) => this.reference(this.packedAt(ptr));
      inter[`webgpu${this.name}Release`] = (ptr) => this.release(this.packedAt(ptr));
      if (withLabelSetter) {
        inter[`webgpu${this.name}SetLabel`] = (ptr, labelPtr, labelLen) => {
          const obj = this.getPacked(ptr);
          if (obj !== undefined) obj.label = this.mem.loadString(labelPtr, labelLen);
        };
      }
      return inter;
    }
  }

  window.odin = window.odin || {};
  window.odin.WebGPUInterface = WebGPUInterface;
})();
