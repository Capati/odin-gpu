/// <reference types="@webgpu/types" />

interface WasmMemoryInterface {
    memory: WebAssembly.Memory;
    exports: any;
    intSize: number;
    loadU8(ptr: number): number;
    loadI8(ptr: number): number;
    loadU16(ptr: number): number;
    loadI32(ptr: number): number;
    loadU32(ptr: number): number;
    loadU64(ptr: number): bigint;
    loadUint(ptr: number): bigint;
    loadPtr(ptr: number): number;
    loadF32(ptr: number): number;
    loadF64(ptr: number): number;
    loadB32(ptr: number): boolean;
    loadBytes(ptr: number, size: number | bigint): Uint8Array;
    loadString(ptr: number, len: number | bigint): string;
    storeUint(ptr: number, value: number | bigint): void;
    storeI32(ptr: number, value: number): void;
    storeU32(ptr: number, value: number): void;
    storeU64(ptr: number, value: bigint): void;
    storeF32(ptr: number, value: number): void;
    storeF64(ptr: number, value: number): void;
    storeB32(ptr: number, value: boolean): void;
    storeString(ptr: number, str: string): void;
}

interface CallbackInfo {
    callback: Function;
    userdata1: number;
    userdata2: number;
}

interface BufferMapping {
    range: ArrayBuffer;
    ptr: number;
    size: number;
}

interface BufferData {
    buffer: GPUBuffer;
    mapping: BufferMapping | null;
    mapState?: string;
}

interface GPUDepthBiasState {
    constant?: GPUDepthBias;
    slopeScale?: number;
    clamp?: number;
}

interface GPUStencilState {
    front?: GPUStencilFaceState;
    back?: GPUStencilFaceState;
    readMask?: GPUStencilValue;
    writeMask?: GPUStencilValue;
}

// Constants
const STATUS_SUCCESS = 1;
const STATUS_ERROR = 2;

// Limit constants
const LIMIT_32_UNDEFINED = 0xffffffff;
const LIMIT_64_UNDEFINED = [0xffffffff, 0xffffffff];
const DEPTH_SLICE_UNDEFINED = 0xffffffff;

// Enum types
type EnumMap = Record<string, (string | null | undefined | boolean)[]>;

const ENUMS: EnumMap = {
    FeatureName: [
        "depth-clip-control",
        "depth32float-stencil8",
        "texture-compression-bc",
        "texture-compression-bc-sliced-3d",
        "texture-compression-etc2",
        "texture-compression-astc",
        "texture-compression-astc-sliced-3d",
        "timestamp-query",
        "indirect-first-instance",
        "shader-f16",
        "rg11b10ufloat-renderable",
        "bgra8unorm-storage",
        "float32-filterable",
        "float32-blendable",
        "clip-distances",
        "dual-source-blending",
        // "subgroups",
        // "texture-formats-tier1",
        // "texture-formats-tier2",
        // "primitive-index",
        // "texture-component-swizzle",
    ],
    StoreOp: [undefined, "store", "discard"],
    LoadOp: [undefined, "clear", "load"],
    BufferBindingType: [undefined, "uniform", "storage", "read-only-storage"],
    SamplerBindingType: [undefined, "filtering", "non-filtering", "comparison"],
    TextureSampleType: [
        undefined,
        "float",
        "unfilterable-float",
        "depth",
        "sint",
        "uint",
    ],
    TextureViewDimension: [
        undefined,
        "1d",
        "2d",
        "2d-array",
        "cube",
        "cube-array",
        "3d",
    ],
    StorageTextureAccess: [
        null,
        undefined,
        "write-only",
        "read-only",
        "read-write",
    ],
    TextureFormat: [
        undefined,
        "r8unorm",
        "r8snorm",
        "r8uint",
        "r8sint",
        "r16uint",
        "r16sint",
        "r16unorm",
        "r16snorm",
        "r16float",
        "rg8unorm",
        "rg8snorm",
        "rg8uint",
        "rg8sint",
        "r32uint",
        "r32sint",
        "r32float",
        "rg16unorm",
        "rg16snorm",
        "rg16uint",
        "rg16sint",
        "rg16float",
        "rgba8unorm",
        "rgba8unorm-srgb",
        "rgba8snorm",
        "rgba8uint",
        "rgba8sint",
        "bgra8unorm",
        "bgra8unorm-srgb",
        "rgb9e5ufloat",
        "rgb10a2uint",
        "rgb10a2unorm",
        "rg11b10ufloat",
        "r64uint",
        "rg32uint",
        "rg32sint",
        "rg32float",
        "rgba16uint",
        "rgba16sint",
        "rgba16unorm",
        "rgba16snorm",
        "rgba16float",
        "rgba32uint",
        "rgba32sint",
        "rgba32float",
        "stencil8",
        "depth16unorm",
        "depth24plus",
        "depth24plus-stencil8",
        "depth32float",
        "depth32float-stencil8",
        "bc1-rgba-unorm",
        "bc1-rgba-unorm-srgb",
        "bc2-rgba-unorm",
        "bc2-rgba-unorm-srgb",
        "bc3-rgba-unorm",
        "bc3-rgba-unorm-srgb",
        "bc4-r-unorm",
        "bc4-r-snorm",
        "bc5-rg-unorm",
        "bc5-rg-snorm",
        "bc6h-rgb-ufloat",
        "bc6h-rgb-float",
        "bc7-rgba-unorm",
        "bc7-rgba-unorm-srgb",
        "etc2-rgb8unorm",
        "etc2-rgb8unorm-srgb",
        "etc2-rgb8a1unorm",
        "etc2-rgb8a1unorm-srgb",
        "etc2-rgba8unorm",
        "etc2-rgba8unorm-srgb",
        "eac-r11unorm",
        "eac-r11snorm",
        "eac-rg11unorm",
        "eac-rg11snorm",
        "astc-4x4-unorm",
        "astc-4x4-unorm-srgb",
        "astc-5x4-unorm",
        "astc-5x4-unorm-srgb",
        "astc-5x5-unorm",
        "astc-5x5-unorm-srgb",
        "astc-6x5-unorm",
        "astc-6x5-unorm-srgb",
        "astc-6x6-unorm",
        "astc-6x6-unorm-srgb",
        "astc-8x5-unorm",
        "astc-8x5-unorm-srgb",
        "astc-8x6-unorm",
        "astc-8x6-unorm-srgb",
        "astc-8x8-unorm",
        "astc-8x8-unorm-srgb",
        "astc-10x5-unorm",
        "astc-10x5-unorm-srgb",
        "astc-10x6-unorm",
        "astc-10x6-unorm-srgb",
        "astc-10x8-unorm",
        "astc-10x8-unorm-srgb",
        "astc-10x10-unorm",
        "astc-10x10-unorm-srgb",
        "astc-12x10-unorm",
        "astc-12x10-unorm-srgb",
        "astc-12x12-unorm",
        "astc-12x12-unorm-srgb",
    ],
    QueryType: [undefined, "occlusion", "timestamp"],
    VertexStepMode: [undefined, "vertex", "instance"],
    VertexFormat: [
        "uint8",
        "uint8x2",
        "uint8x4",
        "sint8",
        "sint8x2",
        "sint8x4",
        "unorm8",
        "unorm8x2",
        "unorm8x4",
        "snorm8",
        "snorm8x2",
        "snorm8x4",
        "uint16",
        "uint16x2",
        "uint16x4",
        "sint16",
        "sint16x2",
        "sint16x4",
        "unorm16",
        "unorm16x2",
        "unorm16x4",
        "snorm16",
        "snorm16x2",
        "snorm16x4",
        "float16",
        "float16x2",
        "float16x4",
        "float32",
        "float32x2",
        "float32x3",
        "float32x4",
        "uint32",
        "uint32x2",
        "uint32x3",
        "uint32x4",
        "sint32",
        "sint32x2",
        "sint32x3",
        "sint32x4",
        "unorm10-10-2",
        "unorm8x4-bgra",
    ],
    PrimitiveTopology: [
        undefined,
        "point-list",
        "line-list",
        "line-strip",
        "triangle-list",
        "triangle-strip",
    ],
    IndexFormat: [undefined, "uint16", "uint32"],
    FrontFace: [undefined, "ccw", "cw"],
    CullMode: [undefined, "none", "front", "back"],
    AddressMode: [
        undefined,
        "clamp-to-edge",
        "repeat",
        "mirror-repeat",
        "clamp-to-border",
    ],
    FilterMode: [undefined, "nearest", "linear"],
    MipmapFilterMode: [undefined, "nearest", "linear"],
    CompareFunction: [
        undefined,
        "never",
        "less",
        "equal",
        "less-equal",
        "greater",
        "not-equal",
        "greater-equal",
        "always",
    ],
    TextureDimension: [undefined, "1d", "2d", "3d"],
    ErrorType: [
        undefined,
        "no-error",
        "validation",
        "out-of-memory",
        "internal",
        "unknown",
    ],
    WGSLLanguageFeatureName: [
        undefined,
        "readonly_and_readwrite_storage_textures",
        "packed_4x8_integer_dot_product",
        "unrestricted_pointer_parameters",
        "pointer_composite_access",
    ],
    PowerPreference: [undefined, "none", "low-power", "high-performance"],
    CompositeAlphaMode: [
        "auto",
        "opaque",
        "premultiplied",
        "unpremultiplied",
        "inherit",
    ],
    StencilOperation: [
        undefined,
        "keep",
        "zero",
        "replace",
        "invert",
        "increment-clamp",
        "decrement-clamp",
        "increment-wrap",
        "decrement-wrap",
    ],
    BlendOperation: [
        undefined,
        "add",
        "subtract",
        "reverse-subtract",
        "min",
        "max",
    ],
    BlendFactor: [
        undefined,
        "zero",
        "one",
        "src",
        "one-minus-src",
        "src-alpha",
        "one-minus-src-alpha",
        "dst",
        "one-minus-dst",
        "dst-alpha",
        "one-minus-dst-alpha",
        "src-alpha-saturated",
        "constant",
        "one-minus-constant",
        "src1",
        "one-minus-src1",
        "src1-alpha",
        "one-minus-src1-alpha",
    ],
    PresentMode: [undefined, "fifo", "fifo-relaxed", "immediate", "mailbox"],
    TextureAspect: [undefined, "all", "stencil-only", "depth-only"],
    DeviceLostReason: [
        "unknown",
        "destroyed",
        "instance-dropped",
        "failed-creation",
    ],
    BufferMapState: [undefined, "unmapped", "pending", "mapped"],
    OptionalBool: [false, true, undefined],

    // WARN: used with indexOf to pass to WASM, if we would pass to JS, this
    // needs to use official naming convention (not like Odin enums) like the ones above.
    BackendType: [
        undefined,
        null,
        "WebGPU",
        "D3D11",
        "D3D12",
        "Metal",
        "Vulkan",
        "OpenGL",
        "OpenGLES",
    ],
    AdapterType: [undefined, "DiscreteGPU", "IntegratedGPU", "CPU", "Unknown"],
    RequestDeviceStatus: ["Success", "InstanceDropped", "Error", "Unknown"],
    MapAsyncStatus: [
        undefined,
        "Success",
        "InstanceDropped",
        "Error",
        "Aborted",
        "Unknown",
    ],
    CreatePipelineAsyncStatus: [
        undefined,
        "Success",
        "InstanceDropped",
        "ValidationError",
        "InternalError",
        "Unknown",
    ],
    PopErrorScopeStatus: [
        undefined,
        "Success",
        "InstanceDropped",
        "EmptyStack",
    ],
    RequestAdapterStatus: [
        "Success",
        "InstanceDropped",
        "Unavailable",
        "Error",
        "Unknown",
    ],
    QueueWorkDoneStatus: [
        undefined,
        "Success",
        "InstanceDropped",
        "Error",
        "Unknown",
    ],
    CompilationInfoRequestStatus: [
        undefined,
        "Success",
        "InstanceDropped",
        "Error",
        "Unknown",
    ],
    CompilationMessageType: [undefined, "error", "warning", "info"],
    ErrorFilter: [undefined, "validation", "out-of-memory", "internal"],
};

class WebGPUInterface {
    private mem: WasmMemoryInterface;
    private sizes: Record<string, [number, number]>;
    private instances: WebGPUObjectManager<{}>;
    private adapters: WebGPUObjectManager<GPUAdapter>;
    private bindGroups: WebGPUObjectManager<GPUBindGroup>;
    private bindGroupLayouts: WebGPUObjectManager<GPUBindGroupLayout>;
    private buffers: WebGPUObjectManager<BufferData>;
    private devices: WebGPUObjectManager<GPUDevice>;
    private commandBuffers: WebGPUObjectManager<GPUCommandBuffer>;
    private commandEncoders: WebGPUObjectManager<GPUCommandEncoder>;
    private computePassEncoders: WebGPUObjectManager<GPUComputePassEncoder>;
    private renderPassEncoders: WebGPUObjectManager<GPURenderPassEncoder>;
    private querySets: WebGPUObjectManager<GPUQuerySet>;
    private computePipelines: WebGPUObjectManager<GPUComputePipeline>;
    private pipelineLayouts: WebGPUObjectManager<GPUPipelineLayout>;
    private queues: WebGPUObjectManager<GPUQueue>;
    private renderBundles: WebGPUObjectManager<GPURenderBundle>;
    private renderBundleEncoders: WebGPUObjectManager<GPURenderBundleEncoder>;
    private renderPipelines: WebGPUObjectManager<GPURenderPipeline>;
    private samplers: WebGPUObjectManager<GPUSampler>;
    private shaderModules: WebGPUObjectManager<GPUShaderModule>;
    private surfaces: WebGPUObjectManager<HTMLCanvasElement>;
    private textures: WebGPUObjectManager<GPUTexture>;
    private textureViews: WebGPUObjectManager<GPUTextureView>;
    private zeroMessageAddr: number = 0;

    constructor(mem: WasmMemoryInterface) {
        this.mem = mem;

        this.sizes = {
            Color: [32, 8],
            StencilState: [40, 4],
            DepthBiasState: [12, 4],
            BufferBindingLayout: [16, 4],
            SamplerBindingLayout: [4, 4],
            TextureBindingLayout: [12, 4],
            StorageTextureBindingLayout: [12, 8],
            StringView: [2 * this.mem.intSize, this.mem.intSize],
            ConstantEntry: [this.mem.intSize === 8 ? 32 : 24, 8],
            ProgrammableStageDescriptor: [
                8 + this.mem.intSize * 4,
                this.mem.intSize,
            ],
            VertexBufferLayout: [16 + this.mem.intSize * 2, 8],
            VertexAttribute: [24, 8],
            VertexState: [4 + this.mem.intSize * 6, this.mem.intSize],
            PrimitiveState: [28, 4],
            MultisampleState: [12, 4],
            StencilFaceState: [16, 4],
            ColorTargetState: [16, 8],
            BlendComponent: [12, 4],
            TexelCopyBufferLayout: [16, 8],
            Origin3D: [12, 4],
            QueueDescriptor: [8, this.mem.intSize],
            CallbackInfo: [16, 4],
            UncapturedErrorCallbackInfo: [16, 4],
            RenderPassColorAttachment: [56, 8],
            BindGroupEntry: [32, 8],
            BindGroupLayoutEntry: [64, 8],
            Extent3D: [12, 4],
            CompilationMessage: [this.mem.intSize == 8 ? 64 : 48, 8],
        };

        this.instances = new WebGPUObjectManager<{}>("Instance", this.mem);
        this.adapters = new WebGPUObjectManager<GPUAdapter>(
            "Adapter",
            this.mem,
        );
        this.bindGroups = new WebGPUObjectManager<GPUBindGroup>(
            "BindGroup",
            this.mem,
        );
        this.bindGroupLayouts = new WebGPUObjectManager<GPUBindGroupLayout>(
            "BindGroupLayout",
            this.mem,
        );
        this.buffers = new WebGPUObjectManager<BufferData>("Buffer", this.mem);
        this.devices = new WebGPUObjectManager<GPUDevice>("Device", this.mem);
        this.commandBuffers = new WebGPUObjectManager<GPUCommandBuffer>(
            "CommandBuffer",
            this.mem,
        );
        this.commandEncoders = new WebGPUObjectManager<GPUCommandEncoder>(
            "CommandEncoder",
            this.mem,
        );
        this.computePassEncoders =
            new WebGPUObjectManager<GPUComputePassEncoder>(
                "ComputePass",
                this.mem,
            );
        this.renderPassEncoders = new WebGPUObjectManager<GPURenderPassEncoder>(
            "RenderPassEncoder",
            this.mem,
        );
        this.querySets = new WebGPUObjectManager<GPUQuerySet>(
            "QuerySet",
            this.mem,
        );
        this.computePipelines = new WebGPUObjectManager<GPUComputePipeline>(
            "ComputePipeline",
            this.mem,
        );
        this.pipelineLayouts = new WebGPUObjectManager<GPUPipelineLayout>(
            "PipelineLayout",
            this.mem,
        );
        this.queues = new WebGPUObjectManager<GPUQueue>("Queue", this.mem);
        this.renderBundles = new WebGPUObjectManager<GPURenderBundle>(
            "RenderBundle",
            this.mem,
        );
        this.renderBundleEncoders =
            new WebGPUObjectManager<GPURenderBundleEncoder>(
                "RenderBundleEncoder",
                this.mem,
            );
        this.renderPipelines = new WebGPUObjectManager<GPURenderPipeline>(
            "RenderPipeline",
            this.mem,
        );
        this.samplers = new WebGPUObjectManager<GPUSampler>(
            "Sampler",
            this.mem,
        );
        this.shaderModules = new WebGPUObjectManager<GPUShaderModule>(
            "ShaderModule",
            this.mem,
        );
        this.surfaces = new WebGPUObjectManager<HTMLCanvasElement>(
            "Surface",
            this.mem,
        );
        this.textures = new WebGPUObjectManager<GPUTexture>(
            "Texture",
            this.mem,
        );
        this.textureViews = new WebGPUObjectManager<GPUTextureView>(
            "TextureView",
            this.mem,
        );
    }

    private struct(start: number) {
        let offset = start;
        return (
            size: number | [number, number],
            alignment?: number,
        ): number => {
            let actualSize: number;
            let actualAlignment: number;

            if (alignment === undefined) {
                if (Array.isArray(size)) {
                    [actualSize, actualAlignment] = size;
                } else {
                    actualSize = size;
                    actualAlignment = size;
                }
            } else {
                actualSize = Array.isArray(size) ? size[0] : size;
                actualAlignment = alignment;
            }

            // Align the offset to the required boundary
            offset = Math.ceil(offset / actualAlignment) * actualAlignment;
            const currentOffset = offset;
            offset += actualSize;
            return currentOffset;
        };
    }

    private uint(src: number | bigint): number | bigint {
        if (this.mem.intSize == 8) {
            return BigInt(src);
        } else if (this.mem.intSize == 4) {
            return Number(src);
        } else {
            throw new Error("unreachable");
        }
    }

    private unwrapBigInt(src: number | bigint): number {
        if (typeof src == "number") {
            return src;
        }

        const MAX_SAFE_INTEGER = 9007199254740991n;
        if (typeof src != "bigint") {
            throw new TypeError(
                `unwrapBigInt got invalid param of type ${typeof src}`,
            );
        }

        if (src > MAX_SAFE_INTEGER) {
            throw new Error(
                `unwrapBigInt precision would be lost converting ${src}`,
            );
        }

        return Number(src);
    }

    private assert(
        condition: boolean,
        message: string = "assertion failure",
    ): void {
        if (!condition) {
            throw new Error(message);
        }
    }

    private array<T>(
        count: number,
        start: number,
        decoder: (ptr: number) => T,
        stride: number,
    ): T[] {
        if (count == 0) {
            return [];
        }
        this.assert(start != 0);

        const out: T[] = [];
        for (let i = 0; i < count; i += 1) {
            out.push(decoder.call(this, start));
            start += stride;
        }
        return out;
    }

    private enumeration(
        name: string,
        ptr: number,
    ): string | null | undefined | boolean {
        const int = this.mem.loadI32(ptr);
        return ENUMS[name]?.[int];
    }

    private genericGetFeatures(
        features: GPUSupportedFeatures,
        ptr: number,
    ): void {
        this.assert(ptr != 0);

        const availableFeatures: number[] = [];
        ENUMS.FeatureName.forEach((feature, value) => {
            if (!feature || typeof feature !== "string") {
                return;
            }

            if (features.has(feature)) {
                availableFeatures.push(value);
            }
        });

        if (availableFeatures.length === 0) {
            return;
        }

        const featuresAddr = this.mem.exports.gpu_alloc(
            availableFeatures.length * 4,
        );
        this.assert(featuresAddr != 0);

        let off = this.struct(ptr);
        this.mem.storeUint(off(this.mem.intSize), availableFeatures.length);
        this.mem.storeI32(off(4), featuresAddr);

        off = this.struct(featuresAddr);
        for (let i = 0; i < availableFeatures.length; i += 1) {
            this.mem.storeI32(off(4), availableFeatures[i]);
        }
    }

    private genericGetLimits(
        limits: GPUSupportedLimits,
        supportedLimitsPtr: number,
    ): number {
        this.assert(supportedLimitsPtr != 0);

        const off = this.struct(supportedLimitsPtr);
        // off(4);

        this.mem.storeU32(off(4), limits.maxTextureDimension1D);
        this.mem.storeU32(off(4), limits.maxTextureDimension2D);
        this.mem.storeU32(off(4), limits.maxTextureDimension3D);
        this.mem.storeU32(off(4), limits.maxTextureArrayLayers);
        this.mem.storeU32(off(4), limits.maxBindGroups);
        this.mem.storeU32(off(4), limits.maxBindGroupsPlusVertexBuffers);
        this.mem.storeU32(off(4), limits.maxBindingsPerBindGroup);
        this.mem.storeU32(
            off(4),
            limits.maxDynamicUniformBuffersPerPipelineLayout,
        );
        this.mem.storeU32(
            off(4),
            limits.maxDynamicStorageBuffersPerPipelineLayout,
        );
        this.mem.storeU32(off(4), limits.maxSampledTexturesPerShaderStage);
        this.mem.storeU32(off(4), limits.maxSamplersPerShaderStage);
        this.mem.storeU32(off(4), limits.maxStorageBuffersPerShaderStage);
        this.mem.storeU32(off(4), limits.maxStorageTexturesPerShaderStage);
        this.mem.storeU32(off(4), limits.maxUniformBuffersPerShaderStage);
        this.mem.storeU32(off(4), limits.maxUniformBufferBindingSize);
        this.mem.storeU32(off(4), limits.maxStorageBufferBindingSize);
        this.mem.storeU32(off(4), limits.minUniformBufferOffsetAlignment);
        this.mem.storeU32(off(4), limits.minStorageBufferOffsetAlignment);
        this.mem.storeU32(off(4), limits.maxVertexBuffers);
        this.mem.storeU64(off(8), BigInt(limits.maxBufferSize));
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

    private genericGetAdapterInfo(infoPtr: number): number {
        this.assert(infoPtr != 0);

        const off = this.struct(infoPtr);
        // off(4); // nextInChain
        off(this.sizes.StringView); // vendor
        off(this.sizes.StringView); // architecture
        off(this.sizes.StringView); // device
        off(this.sizes.StringView); // description

        this.mem.storeI32(off(4), ENUMS.BackendType.indexOf("WebGPU"));
        this.mem.storeI32(off(4), ENUMS.AdapterType.indexOf("Unknown"));

        return STATUS_SUCCESS;
    }

    private FeatureNamePtr(ptr: number): string {
        return this.FeatureName(this.mem.loadI32(ptr));
    }

    private FeatureName(featureInt: number): string {
        return ENUMS.FeatureName[featureInt] as string;
    }

    private RequiredLimitsPtr(
        ptr: number,
    ): Record<string, GPUSize64 | undefined> | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }
        const limits = this.Limits(start);
        if (!limits) {
            return undefined;
        }

        // Convert GPUSupportedLimits to Record<string, GPUSize64>
        const limitsRecord: Record<string, GPUSize64> = {};
        for (const key in limits) {
            const value = limits[key as keyof GPUSupportedLimits];
            if (typeof value === "number") {
                limitsRecord[key] = value;
            }
        }

        return limitsRecord;
    }

    private Limits(start: number): GPUSupportedLimits {
        const limitU32 = (ptr: number): number | undefined => {
            const value = this.mem.loadU32(ptr);
            if (value == LIMIT_32_UNDEFINED) {
                return undefined;
            }
            return value;
        };

        const limitU64 = (ptr: number): bigint | undefined => {
            const part1 = this.mem.loadU32(ptr);
            const part2 = this.mem.loadU32(ptr + 4);
            if (part1 != 0xffffffff || part2 != 0xffffffff) {
                return this.mem.loadU64(ptr);
            }
            return undefined;
        };

        const off = this.struct(start);
        // off(4);

        return {
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
            maxUniformBufferBindingSize: limitU32(off(4)),
            maxStorageBufferBindingSize: limitU32(off(4)),
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
        } as unknown as GPUSupportedLimits;
    }

    private QueueDescriptor(start: number): GPUQueueDescriptor {
        return {
            label: this.StringView(start),
        };
    }

    private ComputePassTimestampWritesPtr(
        ptr: number,
    ): GPUComputePassTimestampWrites | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }

        const off = this.struct(start);
        return {
            querySet: this.querySets.get(this.mem.loadPtr(off(4))),
            beginningOfPassWriteIndex: this.mem.loadU32(off(4)),
            endOfPassWriteIndex: this.mem.loadU32(off(4)),
        };
    }

    private RenderPassColorAttachment(
        start: number,
    ): GPURenderPassColorAttachment {
        const off = this.struct(start);

        // view: ^Texture_View
        const viewIdx = this.mem.loadPtr(off(4));
        this.assert(viewIdx != 0);

        // resolve_target: ^Texture_View
        const resolveTargetIdx = this.mem.loadPtr(off(4));

        // ops: Operations(Color)
        //   load: Load_Op
        const loadOp = this.enumeration("LoadOp", off(4)) as GPULoadOp;
        //   store: Store_Op
        const storeOp = this.enumeration("StoreOp", off(4)) as GPUStoreOp;
        //   clear_value: Color
        const clearValue = this.Color(off(this.sizes.Color));

        // depth_slice: u32
        const depthSliceValue = this.mem.loadU32(off(4));
        const depthSlice =
            depthSliceValue === DEPTH_SLICE_UNDEFINED
                ? undefined
                : depthSliceValue;

        const result: GPURenderPassColorAttachment = {
            view: this.textureViews.get(viewIdx) as GPUTextureView,
            resolveTarget:
                resolveTargetIdx > 0
                    ? (this.textureViews.get(
                          resolveTargetIdx,
                      ) as GPUTextureView)
                    : undefined,
            loadOp,
            storeOp,
            clearValue,
        };

        if (depthSlice !== undefined && depthSlice !== 0) {
            result.depthSlice = depthSlice;
        }

        return result;
    }

    private Color(start: number): GPUColor {
        const off = this.struct(start);
        return {
            r: this.mem.loadF64(off(8)),
            g: this.mem.loadF64(off(8)),
            b: this.mem.loadF64(off(8)),
            a: this.mem.loadF64(off(8)),
        };
    }

    // Render_Pass_Depth_Stencil_Attachment :: struct {
    //     view:        Texture_View,
    //     depth_ops:   Render_Pass_Depth_Operations,
    //     stencil_ops: Render_Pass_Stencil_Operations,
    // }
    private RenderPassDepthStencilAttachmentPtr(
        ptr: number,
    ): GPURenderPassDepthStencilAttachment | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return undefined;
        }

        const off = this.struct(start);

        // view: Texture_View (4 bytes pointer/index)
        const viewIdx = this.mem.loadPtr(off(4));
        if (viewIdx === 0) {
            return undefined;
        }

        const result: GPURenderPassDepthStencilAttachment = {
            view: this.textureViews.get(viewIdx),
        };

        // depth_ops: Render_Pass_Depth_Operations (inline struct, not pointer)
        // Operations<f32> = { load: Load_Op, store: Store_Op, clear_value: f32 }
        // + read_only: bool
        // Total: 4 + 4 + 4 + 4 = 16 bytes

        // load: Load_Op (4 bytes)
        result.depthLoadOp = this.enumeration("LoadOp", off(4)) as GPULoadOp;

        // store: Store_Op (4 bytes)
        result.depthStoreOp = this.enumeration("StoreOp", off(4)) as GPUStoreOp;

        // clear_value: f32 (4 bytes)
        result.depthClearValue = this.mem.loadF32(off(4));

        // read_only: bool (4 bytes as b32)
        result.depthReadOnly = this.mem.loadU32(off(4)) !== 0;

        // stencil_ops: Render_Pass_Stencil_Operations (inline struct, not pointer)
        // Operations<u32> = { load: Load_Op, store: Store_Op, clear_value: u32 }
        // + read_only: bool
        // Total: 4 + 4 + 4 + 4 = 16 bytes

        // load: Load_Op (4 bytes)
        result.stencilLoadOp = this.enumeration("LoadOp", off(4)) as GPULoadOp;

        // store: Store_Op (4 bytes)
        result.stencilStoreOp = this.enumeration(
            "StoreOp",
            off(4),
        ) as GPUStoreOp;

        // clear_value: u32 (4 bytes)
        result.stencilClearValue = this.mem.loadU32(off(4));

        // read_only: bool (4 bytes as b32)
        result.stencilReadOnly = this.mem.loadU32(off(4)) !== 0;

        return result;
    }

    private QuerySet(ptr: number): GPUQuerySet | undefined {
        const querySetPtr = this.mem.loadPtr(ptr);
        if (querySetPtr == 0) {
            return undefined;
        }

        return this.querySets.get(querySetPtr);
    }

    private RenderPassTimestampWritesPtr(
        ptr: number,
    ): GPURenderPassTimestampWrites | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return undefined;
        }
        const off = this.struct(start);

        // query_set: ^Query_Set
        const querySetIdx = this.mem.loadPtr(off(4));
        if (querySetIdx === 0) {
            return undefined;
        }

        return {
            querySet: this.querySets.get(querySetIdx) as GPUQuerySet,
            // beginning_of_pass_write_index: u32
            beginningOfPassWriteIndex: this.mem.loadU32(off(4)),
            // end_of_pass_write_index: u32
            endOfPassWriteIndex: this.mem.loadU32(off(4)),
        };
    }

    private ConstantEntry(start: number): { key: string; value: number } {
        const off = this.struct(start);
        off(4);

        return {
            key: this.StringView(off(this.sizes.StringView)),
            value: this.mem.loadF64(off(8)),
        };
    }

    private VertexState(start: number): GPUVertexState {
        const off = this.struct(start);

        // module: Shader_Module (4 bytes)
        const shaderModuleIdx = this.mem.loadPtr(off(4));

        // entry_point: string (ptr + len)
        const entryPoint = this.StringView(off(this.sizes.StringView));

        // constants: []Constant_Entry (ptr + len)
        const constantsPtr = this.mem.loadPtr(off(4));
        const constantsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const constantsArray = this.array(
            constantsLen,
            constantsPtr,
            this.ConstantEntry,
            this.sizes.ConstantEntry[0],
        );

        // buffers: []Vertex_Buffer_Layout (ptr + len)
        const buffersPtr = this.mem.loadPtr(off(4));
        const buffersLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const buffersArray = this.array(
            buffersLen,
            buffersPtr,
            this.VertexBufferLayout,
            this.sizes.VertexBufferLayout[0],
        );

        const result = {
            module: this.shaderModules.get(shaderModuleIdx)!,
            entryPoint: entryPoint,
            constants: constantsArray.reduce(
                (prev, curr) => {
                    prev[curr.key] = curr.value;
                    return prev;
                },
                {} as Record<string, number>,
            ),
            buffers: buffersArray,
        } as GPUVertexState;

        return result;
    }

    private VertexBufferLayout(start: number): GPUVertexBufferLayout {
        const off = this.struct(start);

        // array_stride: u64 (8 bytes)
        const arrayStride = this.mem.loadU64(off(8));

        // step_mode: Vertex_Step_Mode (enum, typically 4 bytes)
        const stepMode = this.VertexStepMode(this.mem.loadU32(off(4)));

        // attributes: []Vertex_Attribute (ptr + len) - SAME PATTERN
        const attributesPtr = this.mem.loadPtr(off(4));
        const attributesLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const attributesArray = this.array(
            attributesLen,
            attributesPtr,
            this.VertexAttribute,
            this.sizes.VertexAttribute[0],
        );

        return {
            arrayStride: Number(arrayStride),
            stepMode: stepMode,
            attributes: attributesArray,
        };
    }

    private VertexStepMode(value: number): GPUVertexStepMode {
        switch (value) {
            case 1:
                return "vertex";
            case 2:
                return "instance";
            default:
                throw new Error(`Invalid VertexStepMode: ${value}`);
        }
    }

    private VertexAttribute(start: number): GPUVertexAttribute {
        const off = this.struct(start);
        return {
            format: this.enumeration("VertexFormat", off(4)) as GPUVertexFormat,
            offset: Number(this.mem.loadU64(off(8))),
            shaderLocation: this.mem.loadU32(off(4)),
        };
    }

    private PrimitiveState(start: number): GPUPrimitiveState {
        const off = this.struct(start);
        // off(4);

        const result = {
            topology: this.enumeration(
                "PrimitiveTopology",
                off(4),
            ) as GPUPrimitiveTopology,
            stripIndexFormat: this.enumeration(
                "IndexFormat",
                off(4),
            ) as GPUIndexFormat,
            frontFace: this.enumeration("FrontFace", off(4)) as GPUFrontFace,
            cullMode: this.enumeration("CullMode", off(4)) as GPUCullMode,
            unclippedDepth: this.mem.loadB32(off(4)),
        } as GPUPrimitiveState;

        // polygon_mode: Polygon_Mode (4 bytes)
        off(4); // skip

        // conservative: bool (4 bytes)
        off(4); // skip

        return result;
    }

    private RenderPipelineDescriptor(
        start: number,
    ): GPURenderPipelineDescriptor {
        const off = this.struct(start);
        // off(4);

        const label = this.StringView(off(this.sizes.StringView));
        const layoutIdx = this.mem.loadPtr(off(4));

        const result = {
            label: label,
            layout:
                layoutIdx > 0 ? this.pipelineLayouts.get(layoutIdx) : "auto",
            vertex: this.VertexState(off(this.sizes.VertexState)),
            primitive: this.PrimitiveState(off(this.sizes.PrimitiveState)),
            depthStencil: this.DepthStencilStatePtr(off(4)),
            multisample: this.MultisampleState(
                off(this.sizes.MultisampleState),
            ),
            fragment: this.FragmentStatePtr(off(4)),
        } as GPURenderPipelineDescriptor;

        return result;
    }

    private DepthBiasState(start: number): GPUDepthBiasState {
        let currentOffset = start;

        // constant: i32 (4 bytes)
        const constant = this.mem.loadI32(currentOffset);
        currentOffset += 4;

        // slope_scale: f32 (4 bytes)
        const slopeScale = this.mem.loadF32(currentOffset);
        currentOffset += 4;

        // clamp: f32 (4 bytes)
        const clamp = this.mem.loadF32(currentOffset);
        currentOffset += 4;

        return {
            constant: constant,
            slopeScale: slopeScale,
            clamp: clamp,
        };
    }

    private StencilState(start: number): GPUStencilState {
        let currentOffset = start;

        // front: Stencil_Face_State (16 bytes)
        const front = this.StencilFaceState(currentOffset);
        currentOffset += this.sizes.StencilFaceState[0];

        // back: Stencil_Face_State (16 bytes)
        const back = this.StencilFaceState(currentOffset);
        currentOffset += this.sizes.StencilFaceState[0];

        // read_mask: u32 (4 bytes)
        const readMask = this.mem.loadU32(currentOffset);
        currentOffset += 4;

        // write_mask: u32 (4 bytes)
        const writeMask = this.mem.loadU32(currentOffset);
        currentOffset += 4;

        return {
            front: front,
            back: back,
            readMask: readMask,
            writeMask: writeMask,
        };
    }

    private DepthStencilStatePtr(
        ptr: number,
    ): GPUDepthStencilState | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }

        let currentOffset = start;

        // format: Texture_Format (4 bytes)
        const format = this.enumeration(
            "TextureFormat",
            currentOffset,
        ) as GPUTextureFormat;
        currentOffset += 4;

        // depth_write_enabled: bool (4 bytes - stored as u32)
        const depthWriteEnabled = this.mem.loadU32(currentOffset) !== 0;
        currentOffset += 4;

        // depth_compare: Compare_Function (4 bytes)
        const depthCompare = this.enumeration(
            "CompareFunction",
            currentOffset,
        ) as GPUCompareFunction;
        currentOffset += 4;

        // stencil: Stencil_State (nested struct at current offset)
        const stencil = this.StencilState(currentOffset);
        currentOffset += this.sizes.StencilState[0];

        // bias: Depth_Bias_State (nested struct at current offset)
        const bias = this.DepthBiasState(currentOffset);
        currentOffset += this.sizes.DepthBiasState[0];

        return {
            format: format,
            depthWriteEnabled: depthWriteEnabled,
            depthCompare: depthCompare,
            stencilFront: stencil.front,
            stencilBack: stencil.back,
            stencilReadMask: stencil.readMask,
            stencilWriteMask: stencil.writeMask,
            depthBias: bias.constant,
            depthBiasSlopeScale: bias.slopeScale,
            depthBiasClamp: bias.clamp,
        };
    }

    // Multisample_State :: struct {
    //     count: u32,
    //     mask: u32,
    //     alpha_to_coverage_enabled: bool,
    // }
    private MultisampleState(start: number): GPUMultisampleState {
        const off = this.struct(start);

        // count: u32 (4 bytes)
        const count = this.mem.loadU32(off(4));

        // mask: u32 (4 bytes)
        const mask = this.mem.loadU32(off(4));

        // alpha_to_coverage_enabled: bool (1 byte + 3 padding = 4 bytes)
        const alphaToCoverageEnabled = this.mem.loadB32(off(4));

        return {
            count: count,
            mask: mask,
            alphaToCoverageEnabled: alphaToCoverageEnabled,
        };
    }

    private StencilFaceState(start: number): GPUStencilFaceState {
        return {
            compare: this.enumeration(
                "CompareFunction",
                start + 0,
            ) as GPUCompareFunction,
            failOp: this.enumeration(
                "StencilOperation",
                start + 4,
            ) as GPUStencilOperation,
            depthFailOp: this.enumeration(
                "StencilOperation",
                start + 8,
            ) as GPUStencilOperation,
            passOp: this.enumeration(
                "StencilOperation",
                start + 12,
            ) as GPUStencilOperation,
        };
    }

    private FragmentStatePtr(ptr: number): GPUFragmentState | undefined {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }
        const off = this.struct(start);

        // module: Shader_Module (4 bytes)
        const shaderModule = this.shaderModules.get(this.mem.loadPtr(off(4)))!;

        // entry_point: string (ptr + len)
        const entryPoint = this.StringView(off(this.sizes.StringView[0]));

        // constants: []Constant_Entry (ptr + len)
        const constantsPtr = this.mem.loadPtr(off(4));
        const constantsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const constantsArray = this.array(
            constantsLen,
            constantsPtr,
            this.ConstantEntry,
            this.sizes.ConstantEntry[0],
        );

        // targets: []Color_Target_State (ptr + len)
        const targetsPtr = this.mem.loadPtr(off(4));
        const targetsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const targetsArray = this.array(
            targetsLen,
            targetsPtr,
            this.ColorTargetState,
            this.sizes.ColorTargetState[0],
        );

        const result = {
            module: shaderModule,
            entryPoint: entryPoint,
            constants: constantsArray.reduce(
                (prev, curr) => {
                    prev[curr.key] = curr.value;
                    return prev;
                },
                {} as Record<string, number>,
            ),
            targets: targetsArray,
        } as GPUFragmentState;

        return result;
    }

    // Color_Target_State :: struct {
    //     format:     Texture_Format,
    //     blend:      ^Blend_State,
    //     write_mask: Color_Writes,
    // }
    private ColorTargetState(start: number): GPUColorTargetState {
        const off = this.struct(start);

        // format: Texture_Format (4 bytes)
        const format = this.enumeration(
            "TextureFormat",
            off(4),
        ) as GPUTextureFormat;

        // blend: ^Blend_State (4 bytes pointer)
        const blend = this.BlendStatePtr(off(4));

        // write_mask: Color_Writes (8 bytes u64)
        const writeMask = Number(this.mem.loadU64(off(8)));

        return {
            format: format,
            blend: blend,
            writeMask: writeMask,
        };
    }

    private BlendStatePtr(ptr: number): GPUBlendState | undefined {
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

    private BlendComponent(start: number): GPUBlendComponent {
        return {
            operation: this.enumeration(
                "BlendOperation",
                start + 0,
            ) as GPUBlendOperation,
            srcFactor: this.enumeration(
                "BlendFactor",
                start + 4,
            ) as GPUBlendFactor,
            dstFactor: this.enumeration(
                "BlendFactor",
                start + 8,
            ) as GPUBlendFactor,
        };
    }

    StringView(start: number): string {
        const data = this.mem.loadPtr(start);
        const length = this.mem.loadUint(start + this.mem.intSize);
        return this.mem.loadString(data, length);
    }

    private CallbackInfoPtr(ptr: number): CallbackInfo | null {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return null;
        }

        return this.CallbackInfo(start);
    }

    private CallbackInfo(start: number): CallbackInfo {
        const off = this.struct(start);
        // off(4);
        // // TODO: callback mode?
        // off(4);
        return {
            callback: this.mem.exports.__indirect_function_table.get(
                this.mem.loadPtr(off(4)),
            ),
            userdata1: this.mem.loadPtr(off(4)),
            userdata2: this.mem.loadPtr(off(4)),
        };
    }

    private UncapturedErrorCallbackInfo(start: number): CallbackInfo {
        const off = this.struct(start);
        // off(4);
        return {
            callback: this.mem.exports.__indirect_function_table.get(
                this.mem.loadPtr(off(4)),
            ),
            userdata1: this.mem.loadPtr(off(4)),
            userdata2: this.mem.loadPtr(off(4)),
        };
    }

    private callCallback(callback: CallbackInfo, args: any[]): void {
        args.push(callback.userdata1);
        args.push(callback.userdata2);
        callback.callback(...args);
    }

    private zeroMessageArg(): number {
        if (this.zeroMessageAddr > 0) {
            return this.zeroMessageAddr;
        }

        this.zeroMessageAddr = this.mem.exports.gpu_alloc(
            this.sizes.StringView[0],
        );
        return this.zeroMessageAddr;
    }

    private makeMessageArg(message: string): number {
        if (message.length == 0) {
            return this.zeroMessageArg();
        }

        const messageLength = new TextEncoder().encode(message).length;
        const stringSize = this.sizes.StringView[0];

        const addr = this.mem.exports.gpu_alloc(stringSize + messageLength);

        const messageAddr = addr + stringSize;

        this.mem.storeI32(addr, messageAddr);
        this.mem.storeUint(addr + this.mem.intSize, messageLength);

        this.mem.storeString(messageAddr, message);

        return addr;
    }

    private BindGroupEntry(start: number): GPUBindGroupEntry {
        const binding = this.mem.loadU32(start);
        const buffer = this.mem.loadPtr(start + 4);
        const offset = this.mem.loadU64(start + 8);
        const size = this.mem.loadU64(start + 16);
        const sampler = this.mem.loadPtr(start + 24);
        const textureView = this.mem.loadPtr(start + 28);

        let resource: GPUBindingResource | undefined;
        if (buffer > 0) {
            resource = {
                buffer: this.buffers.get(buffer)!.buffer,
                offset: Number(offset),
                size: Number(size),
            };
        } else if (sampler > 0) {
            resource = this.samplers.get(sampler);
        } else if (textureView > 0) {
            resource = this.textureViews.get(textureView);
        }

        if (!resource) {
            throw new Error("No valid resource found for bind group entry");
        }

        return {
            binding: binding,
            resource: resource,
        };
    }

    private Origin3D(start: number): GPUOrigin3D {
        return {
            x: this.mem.loadU32(start + 0),
            y: this.mem.loadU32(start + 4),
            z: this.mem.loadU32(start + 8),
        };
    }

    private Extent3D(start: number): GPUExtent3D {
        return {
            width: this.mem.loadU32(start + 0),
            height: this.mem.loadU32(start + 4),
            depthOrArrayLayers: this.mem.loadU32(start + 8),
        };
    }

    private BindGroupLayoutEntry(start: number): GPUBindGroupLayoutEntry {
        const off = this.struct(start);

        const entry: GPUBindGroupLayoutEntry = {
            binding: this.mem.loadU32(off(4)),
            visibility: Number(this.mem.loadU64(off(8))) as GPUShaderStageFlags,
            buffer: this.BufferBindingLayout(
                off(this.sizes.BufferBindingLayout),
            ),
            sampler: this.SamplerBindingLayout(
                off(this.sizes.SamplerBindingLayout),
            ),
            texture: this.TextureBindingLayout(
                off(this.sizes.TextureBindingLayout),
            ),
            storageTexture: this.StorageTextureBindingLayout(
                off(this.sizes.StorageTextureBindingLayout),
            ),
        };

        if (!entry.buffer?.type) {
            (entry as any).buffer = undefined;
        }
        if (!entry.sampler?.type) {
            (entry as any).sampler = undefined;
        }
        if (!entry.texture?.sampleType) {
            (entry as any).texture = undefined;
        }
        if (!entry.storageTexture?.access) {
            (entry as any).storageTexture = undefined;
        }

        return entry;
    }

    private BufferBindingLayout(start: number): GPUBufferBindingLayout {
        return {
            type: this.enumeration(
                "BufferBindingType",
                start,
            ) as GPUBufferBindingType,
            hasDynamicOffset: this.mem.loadU8(start + 4) !== 0,
            minBindingSize: Number(this.mem.loadU64(start + 8)),
        };
    }

    private SamplerBindingLayout(start: number): GPUSamplerBindingLayout {
        return {
            type: this.enumeration(
                "SamplerBindingType",
                start,
            ) as GPUSamplerBindingType,
        };
    }

    private TextureBindingLayout(start: number): GPUTextureBindingLayout {
        return {
            sampleType: this.enumeration(
                "TextureSampleType",
                start,
            ) as GPUTextureSampleType,
            viewDimension: this.enumeration(
                "TextureViewDimension",
                start + 4,
            ) as GPUTextureViewDimension,
            multisampled: this.mem.loadB32(start + 8),
        };
    }

    private StorageTextureBindingLayout(
        start: number,
    ): GPUStorageTextureBindingLayout {
        return {
            access: this.enumeration(
                "StorageTextureAccess",
                start,
            ) as GPUStorageTextureAccess,
            format: this.enumeration(
                "TextureFormat",
                start + 4,
            ) as GPUTextureFormat,
            viewDimension: this.enumeration(
                "TextureViewDimension",
                start + 8,
            ) as GPUTextureViewDimension,
        };
    }

    private TexelCopyBufferLayout(start: number): {
        offset: number;
        bytesPerRow: number;
        rowsPerImage: number;
    } {
        const off = this.struct(start);
        return {
            offset: Number(this.mem.loadU64(off(8))),
            bytesPerRow: this.mem.loadU32(off(4)),
            rowsPerImage: this.mem.loadU32(off(4)),
        };
    }

    private TexelCopyTextureInfo(start: number): {
        texture: GPUTexture;
        mipLevel: number;
        origin: GPUOrigin3D;
        aspect: GPUTextureAspect;
    } {
        const off = this.struct(start);
        return {
            texture: this.textures.get(this.mem.loadPtr(off(4)))!,
            mipLevel: this.mem.loadU32(off(4)),
            origin: this.Origin3D(off(this.sizes.Origin3D)),
            aspect: this.enumeration(
                "TextureAspect",
                off(4),
            ) as GPUTextureAspect,
        };
    }

    public getInterface(): any {
        return {
            /* ---------------------- Global ---------------------- */

            webgpuCreateInstance: (_descriptorPtr: number): number => {
                if (!navigator.gpu) {
                    console.error("WebGPU is not supported by this browser");
                    return 0;
                }

                return this.instances.create({});
            },

            /* ---------------------- Adapter ---------------------- */

            webgpuAdapterGetFeatures: (
                adapterIdx: number,
                featuresPtr: number,
            ): void => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    this.genericGetFeatures(adapter.features, featuresPtr);
                }
            },

            webgpuAdapterGetInfo: (
                _adapterIdx: number,
                infoPtr: number,
            ): number => {
                return this.genericGetAdapterInfo(infoPtr);
            },

            webgpuAdapterGetLimits: (
                adapterIdx: number,
                limitsPtr: number,
            ): number => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    return this.genericGetLimits(adapter.limits, limitsPtr);
                }
                return STATUS_ERROR;
            },

            webgpuAdapterHasFeature: (
                adapterIdx: number,
                featureInt: number,
            ): boolean => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    return adapter.features.has(this.FeatureName(featureInt));
                }
                return false;
            },

            webgpuAdapterRequestDevice: (
                adapterIdx: number,
                descriptorPtr: number,
                callbackInfoPtr: number,
            ): bigint => {
                const adapter = this.adapters.get(adapterIdx);
                if (!adapter) {
                    return 0n;
                }

                const off = this.struct(descriptorPtr);
                // off(8);

                let descriptor: GPUDeviceDescriptor | undefined;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(off(this.sizes.StringView)),
                        requiredFeatures: this.array(
                            Number(this.mem.loadUint(off(this.mem.intSize))),
                            this.mem.loadPtr(off(4)),
                            this.FeatureNamePtr,
                            4,
                        ) as Iterable<GPUFeatureName>,
                        requiredLimits: this.RequiredLimitsPtr(off(4)),
                        defaultQueue: this.QueueDescriptor(
                            off(this.sizes.QueueDescriptor),
                        ),
                    };
                }

                const callbackInfo = this.CallbackInfo(callbackInfoPtr);

                const deviceLostCallbackInfo = this.CallbackInfo(
                    off(this.sizes.CallbackInfo),
                );
                const uncapturedErrorCallbackInfo =
                    this.UncapturedErrorCallbackInfo(
                        off(this.sizes.UncapturedErrorCallbackInfo),
                    );

                adapter
                    .requestDevice(descriptor)
                    .then((device: GPUDevice | null) => {
                        if (!device) {
                            const messageAddr = this.makeMessageArg(
                                "Failed to create device",
                            );
                            this.callCallback(callbackInfo, [
                                ENUMS.RequestDeviceStatus.indexOf("Error"),
                                messageAddr,
                            ]);
                            this.mem.exports.gpu_free(messageAddr);
                            return;
                        }

                        const deviceIdx = this.devices.create(device);

                        if (deviceLostCallbackInfo.callback !== null) {
                            device.lost.then((info: GPUDeviceLostInfo) => {
                                const reason = ENUMS.DeviceLostReason.indexOf(
                                    info.reason,
                                );

                                const devicePtr = this.mem.exports.gpu_alloc(4);
                                this.mem.storeI32(devicePtr, deviceIdx);

                                const messageAddr = this.makeMessageArg(
                                    info.message,
                                );
                                this.callCallback(deviceLostCallbackInfo, [
                                    devicePtr,
                                    reason,
                                    messageAddr,
                                ]);

                                this.mem.exports.gpu_free(devicePtr);
                                this.mem.exports.gpu_free(messageAddr);
                            });
                        }

                        if (uncapturedErrorCallbackInfo.callback !== null) {
                            device.addEventListener(
                                "uncapturederror",
                                (ev: GPUUncapturedErrorEvent) => {
                                    let status;
                                    if (
                                        ev.error instanceof GPUValidationError
                                    ) {
                                        status =
                                            ENUMS.ErrorType.indexOf(
                                                "validation",
                                            );
                                    } else if (
                                        ev.error instanceof GPUOutOfMemoryError
                                    ) {
                                        status =
                                            ENUMS.ErrorType.indexOf(
                                                "out-of-memory",
                                            );
                                    } else if (
                                        ev.error instanceof GPUInternalError
                                    ) {
                                        status =
                                            ENUMS.ErrorType.indexOf("internal");
                                    } else {
                                        status =
                                            ENUMS.ErrorType.indexOf("unknown");
                                    }

                                    const messageAddr = this.makeMessageArg(
                                        ev.error.message,
                                    );
                                    this.callCallback(
                                        uncapturedErrorCallbackInfo,
                                        [deviceIdx, status, messageAddr],
                                    );
                                    this.mem.exports.gpu_free(messageAddr);
                                },
                            );
                        }

                        this.callCallback(callbackInfo, [
                            ENUMS.RequestDeviceStatus.indexOf("Success"),
                            deviceIdx,
                            this.zeroMessageArg(),
                        ]);
                    })
                    .catch((e: Error) => {
                        const messageAddr = this.makeMessageArg(e.message);
                        this.callCallback(callbackInfo, [
                            ENUMS.RequestDeviceStatus.indexOf("Error"),
                            messageAddr,
                        ]);
                        this.mem.exports.gpu_free(messageAddr);
                    });

                return 0n;
            },

            webgpuAdapterInfoFreeMembers: (_infoPtr: number): void => {
                // NOTE: nothing to free.
            },

            ...this.adapters.interface(true),

            /* ---------------------- Bind Group ---------------------- */

            ...this.bindGroups.interface(true),

            /* ---------------------- Bind Group Layout ---------------------- */

            ...this.bindGroupLayouts.interface(true),

            /* ---------------------- Buffer ---------------------- */

            webgpuBufferDestroy: (bufferIdx: number): void => {
                const buffer = this.buffers.get(bufferIdx);
                if (buffer) {
                    buffer.buffer.destroy();
                }
            },

            webgpuBufferGetConstMappedRange: (
                bufferIdx: number,
                offset: number | bigint,
                size: number | bigint,
            ): number => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer) return 0;

                offset = this.unwrapBigInt(offset);
                size = this.unwrapBigInt(size);

                this.assert(!buffer.mapping, "buffer already mapped");

                const range = buffer.buffer.getMappedRange(offset, size);

                const ptr = this.mem.exports.gpu_alloc(range.byteLength);

                const mapping = new Uint8Array(
                    this.mem.memory.buffer,
                    ptr,
                    size as number,
                );
                mapping.set(new Uint8Array(range));

                buffer.mapping = {
                    range: range,
                    ptr: ptr,
                    size: range.byteLength,
                };
                return ptr;
            },

            webgpuBufferGetMapState: (bufferIdx: number): number => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer) return ENUMS.BufferMapState.indexOf("unmapped");
                return ENUMS.BufferMapState.indexOf(
                    buffer.mapState || "unmapped",
                );
            },

            webgpuBufferGetMappedRange: (
                bufferIdx: number,
                offset: number | bigint,
                size: number | bigint,
            ): number => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer) return 0;

                offset = this.unwrapBigInt(offset);
                size = this.unwrapBigInt(size);

                this.assert(!buffer.mapping, "buffer already mapped");

                const range = buffer.buffer.getMappedRange(offset, size);

                const ptr = this.mem.exports.gpu_alloc(range.byteLength);

                const mapping = new Uint8Array(
                    this.mem.memory.buffer,
                    ptr,
                    size as number,
                );
                mapping.set(new Uint8Array(range));

                buffer.mapping = {
                    range: range,
                    ptr: ptr,
                    size: range.byteLength,
                };
                return ptr;
            },

            webgpuBufferGetSize: (bufferIdx: number): bigint => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer) return 0n;
                return BigInt(buffer.buffer.size);
            },

            webgpuBufferGetUsage: (bufferIdx: number): number => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer) return 0;
                return buffer.buffer.usage;
            },

            webgpuBufferUnmap: (bufferIdx: number): void => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer || !buffer.mapping) return;

                this.assert(buffer.mapping != null, "buffer not mapped");

                const mapping = new Uint8Array(
                    this.mem.memory.buffer,
                    buffer.mapping.ptr,
                    buffer.mapping.size,
                );
                new Uint8Array(buffer.mapping.range).set(mapping);

                buffer.buffer.unmap();

                this.mem.exports.gpu_free(buffer.mapping.ptr);
                buffer.mapping = null;
            },

            ...this.buffers.interface(true),

            /* ---------------------- Command Encoder ---------------------- */

            webgpuCommandEncoderBeginRenderPass: (
                commandEncoderIdx: number,
                descriptorPtr: number,
            ): number => {
                const commandEncoder =
                    this.commandEncoders.get(commandEncoderIdx);
                if (!commandEncoder) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);

                // label: string
                const label = this.StringView(off(this.sizes.StringView));

                // color_attachments: []Render_Pass_Color_Attachment (slice = ptr + len)
                const colorAttachmentsPtr = this.mem.loadPtr(off(4));
                const colorAttachmentsLen = this.mem.loadUint(
                    off(this.mem.intSize),
                );
                const colorAttachments = this.array(
                    Number(colorAttachmentsLen),
                    colorAttachmentsPtr,
                    this.RenderPassColorAttachment.bind(this),
                    this.sizes.RenderPassColorAttachment[0],
                ) as GPURenderPassColorAttachment[];

                // depth_stencil_attachment: Maybe(Render_Pass_Depth_Stencil_Attachment)
                const depthStencilAttachment =
                    this.RenderPassDepthStencilAttachmentPtr(off(4));

                // timestamp_writes: Maybe(Render_Pass_Timestamp_Writes)
                const timestampWritesPtr = this.mem.loadPtr(off(4));
                const timestampWrites =
                    timestampWritesPtr !== 0
                        ? this.RenderPassTimestampWritesPtr(timestampWritesPtr)
                        : undefined;

                // occlusion_query_set: Maybe(Query_Set)
                const occlusionQuerySetPtr = this.mem.loadPtr(off(4));
                const occlusionQuerySet =
                    occlusionQuerySetPtr !== 0
                        ? this.querySets.get(occlusionQuerySetPtr)
                        : undefined;

                const descriptor: GPURenderPassDescriptor = {
                    label,
                    colorAttachments,
                    depthStencilAttachment,
                    timestampWrites,
                    occlusionQuerySet,
                };

                const renderPassEncoder =
                    commandEncoder.beginRenderPass(descriptor);
                return this.renderPassEncoders.create(renderPassEncoder);
            },

            webgpuCommandEncoderFinish: (
                commandEncoderIdx: number,
                descriptorPtr: number,
            ): number => {
                const commandEncoder =
                    this.commandEncoders.get(commandEncoderIdx);
                if (!commandEncoder) return 0;

                let descriptor: GPUCommandBufferDescriptor | undefined;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(descriptorPtr + 4),
                    };
                }

                const commandBuffer = commandEncoder.finish(descriptor);
                return this.commandBuffers.create(commandBuffer);
            },

            ...this.commandEncoders.interface(true),

            /* ---------------------- Command Buffer ---------------------- */

            ...this.commandBuffers.interface(true),

            /* ---------------------- Compute Pass ---------------------- */

            ...this.computePassEncoders.interface(true),

            /* ---------------------- Device ---------------------- */

            webgpuDeviceCreateBindGroup: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);

                const descriptor: GPUBindGroupDescriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    layout: this.bindGroupLayouts.get(
                        this.mem.loadPtr(off(4)),
                    )!,
                    entries: this.array(
                        Number(this.mem.loadUint(off(this.mem.intSize))),
                        this.mem.loadPtr(off(4)),
                        this.BindGroupEntry,
                        this.sizes.BindGroupEntry[0],
                    ) as GPUBindGroupEntry[],
                };

                const bindGroup = device.createBindGroup(descriptor);
                return this.bindGroups.create(bindGroup);
            },

            webgpuDeviceCreateBindGroupLayout: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);

                const descriptor: GPUBindGroupLayoutDescriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    entries: this.array(
                        Number(this.mem.loadUint(off(this.mem.intSize))),
                        this.mem.loadPtr(off(4)),
                        this.BindGroupLayoutEntry,
                        this.sizes.BindGroupLayoutEntry[0],
                    ) as GPUBindGroupLayoutEntry[],
                };

                const layout = device.createBindGroupLayout(descriptor);
                return this.bindGroupLayouts.create(layout);
            },

            webgpuDeviceCreateBuffer: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);

                // label: string (ptr + len = 8 bytes)
                const label = this.StringView(off(this.sizes.StringView[0]));

                // size: u64 (8 bytes)
                const size = Number(this.mem.loadU64(off(8)));

                // usage: Buffer_Usages (8 bytes u64)
                const usage = Number(
                    this.mem.loadU64(off(8)),
                ) as GPUBufferUsageFlags;

                // mapped_at_creation: bool (4 bytes with padding)
                const mappedAtCreation = this.mem.loadB32(off(4));

                const descriptor: GPUBufferDescriptor = {
                    label: label,
                    usage: usage,
                    size: size,
                    mappedAtCreation: mappedAtCreation,
                };

                const buffer = device.createBuffer(descriptor);
                return this.buffers.create({ buffer: buffer, mapping: null });
            },

            webgpuDeviceCreateSampler: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;

                let descriptor: GPUSamplerDescriptor | undefined;
                if (descriptorPtr != 0) {
                    const off = this.struct(descriptorPtr);
                    descriptor = {
                        label: this.StringView(off(this.sizes.StringView)),
                        addressModeU: this.enumeration(
                            "AddressMode",
                            off(4),
                        ) as GPUAddressMode,
                        addressModeV: this.enumeration(
                            "AddressMode",
                            off(4),
                        ) as GPUAddressMode,
                        addressModeW: this.enumeration(
                            "AddressMode",
                            off(4),
                        ) as GPUAddressMode,
                        magFilter: this.enumeration(
                            "FilterMode",
                            off(4),
                        ) as GPUFilterMode,
                        minFilter: this.enumeration(
                            "FilterMode",
                            off(4),
                        ) as GPUFilterMode,
                        mipmapFilter: this.enumeration(
                            "MipmapFilterMode",
                            off(4),
                        ) as GPUMipmapFilterMode,
                        lodMinClamp: this.mem.loadF32(off(4)),
                        lodMaxClamp: this.mem.loadF32(off(4)),
                        compare: this.enumeration(
                            "CompareFunction",
                            off(4),
                        ) as GPUCompareFunction,
                        maxAnisotropy: this.mem.loadU16(off(2)),
                    };
                }

                const sampler = device.createSampler(descriptor);
                return this.samplers.create(sampler);
            },

            webgpuDeviceCreateShaderModule: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);

                const descriptor: GPUShaderModuleDescriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    code: this.StringView(off(this.sizes.StringView)),
                };

                const shaderModule = device.createShaderModule(descriptor);
                return this.shaderModules.create(shaderModule);
            },

            webgpuDeviceCreateTexture: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);
                // off(4);

                const descriptor: GPUTextureDescriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    size: this.Extent3D(off(this.sizes.Extent3D)),
                    mipLevelCount: this.mem.loadU32(off(4)),
                    sampleCount: this.mem.loadU32(off(4)),
                    dimension: this.enumeration(
                        "TextureDimension",
                        off(4),
                    ) as GPUTextureDimension,
                    format: this.enumeration(
                        "TextureFormat",
                        off(4),
                    ) as GPUTextureFormat,
                    usage: Number(
                        this.mem.loadU64(off(8)),
                    ) as GPUTextureUsageFlags,
                    viewFormats: this.array(
                        Number(this.mem.loadUint(off(this.mem.intSize))),
                        this.mem.loadPtr(off(4)),
                        (ptr: number) =>
                            this.enumeration(
                                "TextureFormat",
                                ptr,
                            ) as GPUTextureFormat,
                        4,
                    ) as GPUTextureFormat[],
                };

                const texture = device.createTexture(descriptor);
                return this.textures.create(texture);
            },

            webgpuDeviceCreatePipelineLayout: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const off = this.struct(descriptorPtr);
                // off(4);

                const descriptor: GPUPipelineLayoutDescriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    bindGroupLayouts: this.array(
                        Number(this.mem.loadUint(off(this.mem.intSize))),
                        this.mem.loadPtr(off(4)),
                        (ptr: number) =>
                            this.bindGroupLayouts.get(this.mem.loadPtr(ptr))!,
                        4,
                    ) as GPUBindGroupLayout[],
                };

                const pipelineLayout = device.createPipelineLayout(descriptor);
                return this.pipelineLayouts.create(pipelineLayout);
            },

            webgpuDeviceGetQueue: (deviceIdx: number): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                return this.queues.create(device.queue);
            },

            webgpuDeviceGetFeatures: (
                deviceIdx: number,
                featuresPtr: number,
            ): void => {
                const device = this.devices.get(deviceIdx);
                if (device) {
                    this.genericGetFeatures(device.features, featuresPtr);
                }
            },

            webgpuDeviceCreateCommandEncoder: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;

                let descriptor: GPUCommandEncoderDescriptor | undefined;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(descriptorPtr + 4),
                    };
                }

                const commandEncoder = device.createCommandEncoder(descriptor);
                return this.commandEncoders.create(commandEncoder);
            },

            webgpuDeviceCreateRenderPipeline: (
                deviceIdx: number,
                descriptorPtr: number,
            ): number => {
                const device = this.devices.get(deviceIdx);
                if (!device) return 0;
                this.assert(descriptorPtr != 0);

                const descriptor = this.RenderPipelineDescriptor(descriptorPtr);
                const renderPipeline = device.createRenderPipeline(descriptor);
                return this.renderPipelines.create(renderPipeline);
            },

            ...this.devices.interface(true),

            /* ---------------------- Instance ---------------------- */

            webgpuInstanceCreateSurface: (
                instanceIdx: number,
                selectorPtr: number,
                selectorLen: number,
            ): number => {
                this.assert(instanceIdx > 0);
                this.assert(selectorPtr != 0);

                // Read the selector string from memory
                const selector = this.mem.loadString(selectorPtr, selectorLen);

                const surface = document.querySelector(selector);
                if (!surface) {
                    throw new Error(
                        `Selector '${selector}' did not match any element`,
                    );
                }
                if (!(surface instanceof HTMLCanvasElement)) {
                    throw new Error(
                        "Selector matches an element that is not a canvas",
                    );
                }
                return this.surfaces.create(surface);
            },

            webgpuInstanceRequestAdapter: (
                instanceIdx: number,
                optionsPtr: number,
                callbackInfoPtr: number,
            ): bigint => {
                this.assert(instanceIdx > 0);

                let options: GPURequestAdapterOptions | undefined;
                if (optionsPtr != 0) {
                    const off = this.struct(optionsPtr);
                    // off(4); // nextInChain
                    // off(4); // featureLevel
                    options = {
                        powerPreference: this.enumeration(
                            "PowerPreference",
                            off(4),
                        ) as GPUPowerPreference,
                        forceFallbackAdapter: this.mem.loadB32(off(4)),
                    };
                }

                const callbackInfo = this.CallbackInfo(callbackInfoPtr);
                navigator.gpu
                    .requestAdapter(options)
                    .then((adapter: GPUAdapter | null) => {
                        if (!adapter) {
                            const messageAddr =
                                this.makeMessageArg("No adapter found");
                            this.callCallback(callbackInfo, [
                                ENUMS.RequestAdapterStatus.indexOf(
                                    "Unavailable",
                                ),
                                0,
                                messageAddr,
                            ]);
                            this.mem.exports.gpu_free(messageAddr);
                            return;
                        }

                        const adapterIdx = this.adapters.create(adapter);
                        this.callCallback(callbackInfo, [
                            ENUMS.RequestAdapterStatus.indexOf("Success"),
                            adapterIdx,
                            this.zeroMessageArg(),
                        ]);
                    })
                    .catch((e: Error) => {
                        const messageAddr = this.makeMessageArg(e.message);
                        this.callCallback(callbackInfo, [
                            ENUMS.RequestAdapterStatus.indexOf("Error"),
                            0,
                            messageAddr,
                        ]);
                        this.mem.exports.gpu_free(messageAddr);
                    });

                return 0n;
            },

            ...this.instances.interface(true),

            /* ---------------------- Pipeline Layout  ---------------------- */

            ...this.pipelineLayouts.interface(true),

            /* ---------------------- Queue ---------------------- */

            webgpuQueueSubmit: (
                queueIdx: number,
                commandCount: number | bigint,
                commandsPtr: number,
            ): void => {
                const queue = this.queues.get(queueIdx);
                if (!queue) return;

                const commands = this.array(
                    this.unwrapBigInt(commandCount),
                    commandsPtr,
                    (ptr: number) =>
                        this.commandBuffers.get(this.mem.loadPtr(ptr))!,
                    4,
                ) as GPUCommandBuffer[];
                queue.submit(commands);
            },

            webgpuQueueWriteBuffer: (
                queueIdx: number,
                bufferIdx: number,
                bufferOffset: number | bigint,
                dataPtr: number,
                size: number | bigint,
            ): void => {
                const queue = this.queues.get(queueIdx);
                const buffer = this.buffers.get(bufferIdx);
                if (!queue || !buffer) return;

                bufferOffset = this.unwrapBigInt(bufferOffset);
                size = this.unwrapBigInt(size);

                const data = this.mem.loadBytes(dataPtr, size) as BufferSource;

                queue.writeBuffer(
                    buffer.buffer,
                    bufferOffset,
                    data,
                    0,
                    size as number,
                );
            },

            webgpuQueueWriteTexture: (
                queueIdx: number,
                destinationPtr: number,
                dataPtr: number,
                dataSize: number | bigint,
                dataLayoutPtr: number,
                writeSizePtr: number,
            ): void => {
                const queue = this.queues.get(queueIdx);
                if (!queue) return;

                const destination = this.TexelCopyTextureInfo(destinationPtr);
                dataSize = this.unwrapBigInt(dataSize);
                const dataLayout = this.TexelCopyBufferLayout(dataLayoutPtr);
                const writeSize = this.Extent3D(writeSizePtr);

                const data = this.mem.loadBytes(
                    dataPtr,
                    dataSize,
                ) as BufferSource;

                queue.writeTexture(destination, data, dataLayout, writeSize);
            },

            ...this.queues.interface(true),

            /* ---------------------- Render Pass ---------------------- */

            webgpuRenderPassEncoderBeginOcclusionQuery: (
                renderPassEncoderIdx: number,
                queryIndex: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.beginOcclusionQuery(queryIndex);
            },

            webgpuRenderPassEncoderDraw: (
                renderPassEncoderIdx: number,
                vertexCount: number,
                instanceCount: number,
                firstVertex: number,
                firstInstance: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.draw(
                    vertexCount,
                    instanceCount,
                    firstVertex,
                    firstInstance,
                );
            },

            webgpuRenderPassEncoderDrawIndexed: (
                renderPassEncoderIdx: number,
                indexCount: number,
                instanceCount: number,
                firstIndex: number,
                baseVertex: number,
                firstInstance: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.drawIndexed(
                    indexCount,
                    instanceCount,
                    firstIndex,
                    baseVertex,
                    firstInstance,
                );
            },

            webgpuRenderPassEncoderDrawIndexedIndirect: (
                renderPassEncoderIdx: number,
                indirectBufferIdx: number,
                indirectOffset: bigint,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(indirectBufferIdx);
                if (!renderPassEncoder || !buffer) return;

                indirectOffset = BigInt(this.unwrapBigInt(indirectOffset));
                renderPassEncoder.drawIndexedIndirect(
                    buffer.buffer,
                    Number(indirectOffset),
                );
            },

            webgpuRenderPassEncoderDrawIndirect: (
                renderPassEncoderIdx: number,
                indirectBufferIdx: number,
                indirectOffset: bigint,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(indirectBufferIdx);
                if (!renderPassEncoder || !buffer) return;

                indirectOffset = BigInt(this.unwrapBigInt(indirectOffset));
                renderPassEncoder.drawIndirect(
                    buffer.buffer,
                    Number(indirectOffset),
                );
            },

            webgpuRenderPassEncoderEnd: (
                renderPassEncoderIdx: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.end();
            },

            webgpuRenderPassEncoderEndOcclusionQuery: (
                renderPassEncoderIdx: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.endOcclusionQuery();
            },

            webgpuRenderPassEncoderExecuteBundles: (
                renderPassEncoderIdx: number,
                bundleCount: number | bigint,
                bundlesPtr: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;

                bundleCount = this.unwrapBigInt(bundleCount);
                const bundles = this.array(
                    bundleCount,
                    bundlesPtr,
                    (ptr: number) =>
                        this.renderBundles.get(this.mem.loadPtr(ptr))!,
                    4,
                ) as GPURenderBundle[];
                renderPassEncoder.executeBundles(bundles);
            },

            webgpuRenderPassEncoderInsertDebugMarker: (
                renderPassEncoderIdx: number,
                markerLabelPtr: number,
                markerLabelLen: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                const markerLabel = this.mem.loadString(
                    markerLabelPtr,
                    markerLabelLen,
                );
                renderPassEncoder.insertDebugMarker(markerLabel);
            },

            webgpuRenderPassEncoderPopDebugGroup: (
                renderPassEncoderIdx: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.popDebugGroup();
            },

            webgpuRenderPassEncoderPushDebugGroup: (
                renderPassEncoderIdx: number,
                groupLabelPtr: number,
                groupLabelLen: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                const groupLabel = this.mem.loadString(
                    groupLabelPtr,
                    groupLabelLen,
                );
                renderPassEncoder.pushDebugGroup(groupLabel);
            },

            webgpuRenderPassEncoderSetBindGroup: (
                renderPassEncoderIdx: number,
                groupIndex: number,
                groupIdx: number,
                dynamicOffsetCount: number | bigint,
                dynamicOffsetsPtr: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;

                let group: GPUBindGroup | undefined;
                if (groupIdx > 0) {
                    group = this.bindGroups.get(groupIdx);
                }

                dynamicOffsetCount = this.unwrapBigInt(dynamicOffsetCount);
                const dynamicOffsets = this.array(
                    dynamicOffsetCount,
                    dynamicOffsetsPtr,
                    (ptr: number) => this.mem.loadU32(ptr),
                    4,
                );

                renderPassEncoder.setBindGroup(
                    groupIndex,
                    group,
                    dynamicOffsets,
                );
            },

            webgpuRenderPassEncoderSetBlendConstant: (
                renderPassEncoderIdx: number,
                colorPtr: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                this.assert(colorPtr != 0);
                renderPassEncoder.setBlendConstant(this.Color(colorPtr));
            },

            webgpuRenderPassEncoderSetIndexBuffer: (
                renderPassEncoderIdx: number,
                bufferIdx: number,
                formatInt: number,
                offset: bigint,
                size: bigint,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(bufferIdx);
                if (!renderPassEncoder || !buffer) return;

                const format = ENUMS.IndexFormat[formatInt] as GPUIndexFormat;
                offset = BigInt(this.unwrapBigInt(offset));
                size = BigInt(this.unwrapBigInt(size));
                renderPassEncoder.setIndexBuffer(
                    buffer.buffer,
                    format,
                    Number(offset),
                    Number(size),
                );
            },

            webgpuRenderPassEncoderSetPipeline: (
                renderPassEncoderIdx: number,
                pipelineIdx: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                const pipeline = this.renderPipelines.get(pipelineIdx);
                if (!renderPassEncoder || !pipeline) return;
                renderPassEncoder.setPipeline(pipeline);
            },

            webgpuRenderPassEncoderSetScissorRect: (
                renderPassEncoderIdx: number,
                x: number,
                y: number,
                width: number,
                height: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.setScissorRect(x, y, width, height);
            },

            webgpuRenderPassEncoderSetStencilReference: (
                renderPassEncoderIdx: number,
                reference: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.setStencilReference(reference);
            },

            webgpuRenderPassEncoderSetVertexBuffer: (
                renderPassEncoderIdx: number,
                slot: number,
                bufferIdx: number,
                offset: bigint,
                size: bigint,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;

                let buffer: GPUBuffer | undefined;
                if (bufferIdx > 0) {
                    const bufferData = this.buffers.get(bufferIdx);
                    if (bufferData) {
                        buffer = bufferData.buffer;
                    }
                }

                offset = BigInt(this.unwrapBigInt(offset));
                size = BigInt(this.unwrapBigInt(size));
                renderPassEncoder.setVertexBuffer(
                    slot,
                    buffer,
                    Number(offset),
                    Number(size),
                );
            },

            webgpuRenderPassEncoderSetViewport: (
                renderPassEncoderIdx: number,
                x: number,
                y: number,
                width: number,
                height: number,
                minDepth: number,
                maxDepth: number,
            ): void => {
                const renderPassEncoder =
                    this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder) return;
                renderPassEncoder.setViewport(
                    x,
                    y,
                    width,
                    height,
                    minDepth,
                    maxDepth,
                );
            },

            ...this.renderPassEncoders.interface(true),

            /* ---------------------- Render Pipeline ---------------------- */

            ...this.renderPipelines.interface(true),

            /* ---------------------- Sampler ---------------------- */

            ...this.samplers.interface(true),

            /* ---------------------- Shader Module ---------------------- */

            ...this.shaderModules.interface(true),

            /* ---------------------- Surface ---------------------- */

            webgpuSurfaceConfigure: (
                surfaceIdx: number,
                deviceIdx: number,
                configPtr: number,
            ): void => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface) return;
                const context = surface.getContext(
                    "webgpu",
                ) as GPUCanvasContext | null;
                if (!context) return;

                const device = this.devices.get(deviceIdx);
                if (!device) return;

                const off = this.struct(configPtr);

                // usage: Texture_Usages (u32 bitflag)
                const usage = this.mem.loadU32(off(4)) as GPUTextureUsageFlags;

                // format: Texture_Format (i32 enum)
                const format = this.enumeration(
                    "TextureFormat",
                    off(4),
                ) as GPUTextureFormat;

                // width: u32
                const width = this.mem.loadU32(off(4));

                // height: u32
                const height = this.mem.loadU32(off(4));

                // present_mode: Present_Mode (i32 enum)
                const presentMode = this.enumeration("PresentMode", off(4));
                // Note: presentMode is not used in WebGPU canvas configuration

                // desired_maximum_frame_latency: u32
                const desiredMaximumFrameLatency = this.mem.loadU32(off(4));
                // Note: not directly supported in WebGPU

                // alpha_mode: Composite_Alpha_Mode (i32 enum)
                let alphaMode = this.enumeration("CompositeAlphaMode", off(4));
                if (alphaMode == "auto") {
                    alphaMode = "opaque";
                }

                // view_formats: []Texture_Format (slice = ptr + len)
                const viewFormatsPtr = this.mem.loadPtr(off(4));
                const viewFormatsLen = this.mem.loadUint(off(this.mem.intSize));
                const viewFormats = this.array(
                    Number(viewFormatsLen),
                    viewFormatsPtr,
                    (ptr: number) =>
                        this.enumeration(
                            "TextureFormat",
                            ptr,
                        ) as GPUTextureFormat,
                    4,
                ) as GPUTextureFormat[];

                surface.width = width;
                surface.height = height;

                const config: GPUCanvasConfiguration = {
                    device: device,
                    format: format,
                    usage: usage,
                    viewFormats: viewFormats,
                    alphaMode: alphaMode as GPUCanvasAlphaMode,
                };

                context.configure(config);
            },

            webgpuSurfaceGetCapabilities: (
                _surfaceIdx: number,
                _adapterIdx: number,
                capabilitiesPtr: number,
            ): number => {
                const off = this.struct(capabilitiesPtr);

                // formats: []Texture_Format (slice = ptr + len)
                const formatStr = navigator.gpu.getPreferredCanvasFormat();
                const format = ENUMS.TextureFormat.indexOf(formatStr);
                const formatAddr = this.mem.exports.gpu_alloc(4);
                this.mem.storeI32(formatAddr, format);
                this.mem.storeUint(off(4), formatAddr); // formats.data pointer
                this.mem.storeUint(off(this.mem.intSize), 1); // formats.len

                // present_modes: []Present_Mode (slice = ptr + len)
                const presentModesAddr = this.mem.exports.gpu_alloc(4);
                this.mem.storeI32(
                    presentModesAddr,
                    ENUMS.PresentMode.indexOf("fifo"),
                );
                this.mem.storeUint(off(4), presentModesAddr); // present_modes.data pointer
                this.mem.storeUint(off(this.mem.intSize), 1); // present_modes.len

                // alpha_modes: []Composite_Alpha_Mode (slice = ptr + len)
                const alphaModesAddr = this.mem.exports.gpu_alloc(8);
                this.mem.storeI32(
                    alphaModesAddr + 0,
                    ENUMS.CompositeAlphaMode.indexOf("opaque"),
                );
                this.mem.storeI32(
                    alphaModesAddr + 4,
                    ENUMS.CompositeAlphaMode.indexOf("premultiplied"),
                );
                this.mem.storeUint(off(4), alphaModesAddr); // alpha_modes.data pointer
                this.mem.storeUint(off(this.mem.intSize), 2); // alpha_modes.len

                const COPY_SRC = 1 << 0; // 0x01
                const COPY_DST = 1 << 1; // 0x02
                const TEXTURE_BINDING = 1 << 2; // 0x04
                const RENDER_ATTACHMENT = 1 << 4; // 0x10

                const usages =
                    COPY_SRC | COPY_DST | TEXTURE_BINDING | RENDER_ATTACHMENT;
                this.mem.storeU32(off(4), usages);

                return STATUS_SUCCESS;
            },

            webgpuSurfaceGetCurrentTexture: (
                surfaceIdx: number,
                texturePtr: number,
            ): void => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface) return;
                const context = surface.getContext(
                    "webgpu",
                ) as GPUCanvasContext | null;
                if (!context) return;

                const off = this.struct(texturePtr);

                try {
                    const texture = context.getCurrentTexture();
                    const textureIdx = this.textures.create(texture);

                    // surface: Surface
                    this.mem.storeUint(off(this.mem.intSize), surfaceIdx);

                    // texture: Texture
                    this.mem.storeUint(off(this.mem.intSize), textureIdx);

                    // status: Surface_Texture_Status (i32 enum)
                    // 0 = Success, 1 = Timeout, 2 = Outdated, 3 = Lost
                    this.mem.storeI32(off(4), 0); // Success

                    // presented: bool (b32)
                    this.mem.storeU32(off(4), 0); // false (not yet presented)
                } catch (error) {
                    // If getCurrentTexture fails, set error status
                    this.mem.storeUint(off(this.mem.intSize), surfaceIdx);
                    this.mem.storeUint(off(this.mem.intSize), 0); // null texture

                    // Determine status based on error
                    // In WebGPU, getCurrentTexture can throw if context is lost
                    this.mem.storeI32(off(4), 3); // Lost
                    this.mem.storeU32(off(4), 0); // false

                    console.error("Failed to get current texture:", error);
                }
            },

            webgpuSurfacePresent: (_surfaceIdx: number): void => {
                // NOTE: Not really anything to do here.
            },

            webgpuSurfaceUnconfigure: (surfaceIdx: number): void => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface) return;
                const context = surface.getContext(
                    "webgpu",
                ) as GPUCanvasContext | null;
                if (!context) return;
                context.unconfigure();
            },

            ...this.surfaces.interface(true),

            /* ---------------------- SurfaceCapabilities ---------------------- */

            webgpuSurfaceCapabilitiesFreeMembers: (
                surfaceCapabilitiesPtr: number,
            ): void => {
                const off = this.struct(surfaceCapabilitiesPtr);

                // formats: []Texture_Format (ptr + len)
                const formatsAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize); // skip len
                if (formatsAddr !== 0) {
                    this.mem.exports.gpu_free(formatsAddr);
                }

                // present_modes: []Present_Mode (ptr + len)
                const presentModesAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize); // skip len
                if (presentModesAddr !== 0) {
                    this.mem.exports.gpu_free(presentModesAddr);
                }

                // alpha_modes: []Composite_Alpha_Mode (ptr + len)
                const alphaModesAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize); // skip len
                if (alphaModesAddr !== 0) {
                    this.mem.exports.gpu_free(alphaModesAddr);
                }

                // usages is just a u32 bitflag, no need to free
                off(4); // skip usages
            },

            /* ---------------------- SupportedFeatures ---------------------- */

            webgpuSupportedFeaturesFreeMembers: (
                _supportedFeaturesCount: number,
                supportedFeaturesPtr: number,
            ): void => {
                this.mem.exports.gpu_free(supportedFeaturesPtr);
            },

            /* ---------------------- Texture ---------------------- */

            webgpuTextureCreateView: (
                textureIdx: number,
                descriptorPtr: number,
            ): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;

                let descriptor: GPUTextureViewDescriptor | undefined;
                if (descriptorPtr != 0) {
                    const off = this.struct(descriptorPtr);

                    // label: string
                    const label = this.StringView(off(this.sizes.StringView));

                    // format: Texture_Format (i32 enum)
                    const format = this.enumeration(
                        "TextureFormat",
                        off(4),
                    ) as GPUTextureFormat;

                    // dimension: Texture_View_Dimension (i32 enum)
                    const dimension = this.enumeration(
                        "TextureViewDimension",
                        off(4),
                    ) as GPUTextureViewDimension;

                    // usage: Texture_Usages (u32 bitflag)
                    const usage = this.mem.loadU32(
                        off(4),
                    ) as GPUTextureUsageFlags;

                    // aspect: Texture_Aspect (i32 enum)
                    const aspect = this.enumeration(
                        "TextureAspect",
                        off(4),
                    ) as GPUTextureAspect;

                    // base_mip_level: u32
                    const baseMipLevel = this.mem.loadU32(off(4));

                    // mip_level_count: u32
                    let mipLevelCount: number | undefined = this.mem.loadU32(
                        off(4),
                    );
                    if (mipLevelCount === 0) {
                        mipLevelCount = undefined;
                    }

                    // base_array_layer: u32
                    const baseArrayLayer = this.mem.loadU32(off(4));

                    // array_layer_count: u32
                    let arrayLayerCount: number | undefined = this.mem.loadU32(
                        off(4),
                    );
                    if (arrayLayerCount === 0) {
                        arrayLayerCount = undefined;
                    }

                    descriptor = {
                        label,
                        format,
                        dimension,
                        usage,
                        aspect,
                        baseMipLevel,
                        mipLevelCount,
                        baseArrayLayer,
                        arrayLayerCount,
                    };
                }

                const textureView = texture.createView(descriptor);
                return this.textureViews.create(textureView);
            },

            webgpuTextureDestroy: (textureIdx: number): void => {
                const texture = this.textures.get(textureIdx);
                if (texture) {
                    texture.destroy();
                }
            },

            webgpuTextureGetDepthOrArrayLayers: (
                textureIdx: number,
            ): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.depthOrArrayLayers;
            },

            webgpuTextureGetDimension: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return ENUMS.TextureDimension.indexOf(texture.dimension);
            },

            webgpuTextureGetFormat: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return ENUMS.TextureFormat.indexOf(texture.format);
            },

            webgpuTextureGetHeight: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.height;
            },

            webgpuTextureGetMipLevelCount: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.mipLevelCount;
            },

            webgpuTextureGetSampleCount: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.sampleCount;
            },

            webgpuTextureGetUsage: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.usage;
            },

            webgpuTextureGetWidth: (textureIdx: number): number => {
                const texture = this.textures.get(textureIdx);
                if (!texture) return 0;
                return texture.width;
            },

            ...this.textures.interface(true),

            /* ---------------------- Texture View ---------------------- */

            ...this.textureViews.interface(true),
        };
    }
}

class WebGPUObjectManager<T> {
    private name: string;
    private mem: WasmMemoryInterface;
    private idx: number = 0;
    private objects: Record<number, { references: number; object: T }> = {};

    constructor(name: string, mem: WasmMemoryInterface) {
        this.name = name;
        this.mem = mem;
    }

    create(object: T): number {
        this.idx += 1;
        this.objects[this.idx] = { references: 1, object };
        return this.idx;
    }

    get(idx: number): T {
        if (idx <= 0) {
            throw new Error("Invalid object");
        }
        return this.objects[idx]?.object as T;
    }

    release(idx: number): void {
        if (idx <= 0) return;
        const obj = this.objects[idx];
        if (obj) {
            obj.references -= 1;
            if (obj.references <= 0) {
                delete this.objects[idx];
            }
        }
    }

    reference(idx: number): void {
        if (idx <= 0) return;
        const obj = this.objects[idx];
        if (obj) {
            obj.references += 1;
        }
    }

    interface(withLabelSetter: boolean = false): Record<string, Function> {
        const inter: Record<string, Function> = {};
        inter[`webgpu${this.name}AddRef`] = this.reference.bind(this);
        inter[`webgpu${this.name}Release`] = this.release.bind(this);
        if (withLabelSetter) {
            inter[`webgpu${this.name}SetLabel`] = (
                idx: number,
                labelPtr: number,
                labelLen: number,
            ) => {
                const obj = this.get(idx) as any;
                if (obj && obj.label !== undefined) {
                    obj.label = this.mem.loadString(labelPtr, labelLen);
                }
            };
            inter[`webgpu${this.name}GetLabel`] = (idx: number) => {
                const obj = this.get(idx) as any;
                if (obj && obj.label !== undefined) {
                    return obj.label;
                }
            };
        }
        return inter;
    }
}

(window as any).odin = (window as any).odin || {};
(window as any).odin.WebGPUInterface = WebGPUInterface;
