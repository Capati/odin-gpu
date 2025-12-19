"use strict";
const STATUS_SUCCESS = 1;
const STATUS_ERROR = 2;
const LIMIT_32_UNDEFINED = 0xffffffff;
const LIMIT_64_UNDEFINED = [0xffffffff, 0xffffffff];
const DEPTH_SLICE_UNDEFINED = 0xffffffff;
const ENUMS = {
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
    constructor(mem) {
        Object.defineProperty(this, "mem", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "sizes", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "instances", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "adapters", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "bindGroups", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "bindGroupLayouts", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "buffers", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "devices", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "commandBuffers", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "commandEncoders", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "computePassEncoders", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "renderPassEncoders", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "querySets", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "computePipelines", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "pipelineLayouts", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "queues", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "renderBundles", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "renderBundleEncoders", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "renderPipelines", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "samplers", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "shaderModules", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "surfaces", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "textures", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "textureViews", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "zeroMessageAddr", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: 0
        });
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
        this.instances = new WebGPUObjectManager("Instance", this.mem);
        this.adapters = new WebGPUObjectManager("Adapter", this.mem);
        this.bindGroups = new WebGPUObjectManager("BindGroup", this.mem);
        this.bindGroupLayouts = new WebGPUObjectManager("BindGroupLayout", this.mem);
        this.buffers = new WebGPUObjectManager("Buffer", this.mem);
        this.devices = new WebGPUObjectManager("Device", this.mem);
        this.commandBuffers = new WebGPUObjectManager("CommandBuffer", this.mem);
        this.commandEncoders = new WebGPUObjectManager("CommandEncoder", this.mem);
        this.computePassEncoders =
            new WebGPUObjectManager("ComputePass", this.mem);
        this.renderPassEncoders = new WebGPUObjectManager("RenderPassEncoder", this.mem);
        this.querySets = new WebGPUObjectManager("QuerySet", this.mem);
        this.computePipelines = new WebGPUObjectManager("ComputePipeline", this.mem);
        this.pipelineLayouts = new WebGPUObjectManager("PipelineLayout", this.mem);
        this.queues = new WebGPUObjectManager("Queue", this.mem);
        this.renderBundles = new WebGPUObjectManager("RenderBundle", this.mem);
        this.renderBundleEncoders =
            new WebGPUObjectManager("RenderBundleEncoder", this.mem);
        this.renderPipelines = new WebGPUObjectManager("RenderPipeline", this.mem);
        this.samplers = new WebGPUObjectManager("Sampler", this.mem);
        this.shaderModules = new WebGPUObjectManager("ShaderModule", this.mem);
        this.surfaces = new WebGPUObjectManager("Surface", this.mem);
        this.textures = new WebGPUObjectManager("Texture", this.mem);
        this.textureViews = new WebGPUObjectManager("TextureView", this.mem);
    }
    struct(start) {
        let offset = start;
        return (size, alignment) => {
            let actualSize;
            let actualAlignment;
            if (alignment === undefined) {
                if (Array.isArray(size)) {
                    [actualSize, actualAlignment] = size;
                }
                else {
                    actualSize = size;
                    actualAlignment = size;
                }
            }
            else {
                actualSize = Array.isArray(size) ? size[0] : size;
                actualAlignment = alignment;
            }
            offset = Math.ceil(offset / actualAlignment) * actualAlignment;
            const currentOffset = offset;
            offset += actualSize;
            return currentOffset;
        };
    }
    uint(src) {
        if (this.mem.intSize == 8) {
            return BigInt(src);
        }
        else if (this.mem.intSize == 4) {
            return Number(src);
        }
        else {
            throw new Error("unreachable");
        }
    }
    unwrapBigInt(src) {
        if (typeof src == "number") {
            return src;
        }
        const MAX_SAFE_INTEGER = 9007199254740991n;
        if (typeof src != "bigint") {
            throw new TypeError(`unwrapBigInt got invalid param of type ${typeof src}`);
        }
        if (src > MAX_SAFE_INTEGER) {
            throw new Error(`unwrapBigInt precision would be lost converting ${src}`);
        }
        return Number(src);
    }
    assert(condition, message = "assertion failure") {
        if (!condition) {
            throw new Error(message);
        }
    }
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
    enumeration(name, ptr) {
        const int = this.mem.loadI32(ptr);
        return ENUMS[name]?.[int];
    }
    genericGetFeatures(features, ptr) {
        this.assert(ptr != 0);
        const availableFeatures = [];
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
        const featuresAddr = this.mem.exports.gpu_alloc(availableFeatures.length * 4);
        this.assert(featuresAddr != 0);
        let off = this.struct(ptr);
        this.mem.storeUint(off(this.mem.intSize), availableFeatures.length);
        this.mem.storeI32(off(4), featuresAddr);
        off = this.struct(featuresAddr);
        for (let i = 0; i < availableFeatures.length; i += 1) {
            this.mem.storeI32(off(4), availableFeatures[i]);
        }
    }
    genericGetLimits(limits, supportedLimitsPtr) {
        this.assert(supportedLimitsPtr != 0);
        const off = this.struct(supportedLimitsPtr);
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
    genericGetAdapterInfo(infoPtr) {
        this.assert(infoPtr != 0);
        const off = this.struct(infoPtr);
        off(this.sizes.StringView);
        off(this.sizes.StringView);
        off(this.sizes.StringView);
        off(this.sizes.StringView);
        this.mem.storeI32(off(4), ENUMS.BackendType.indexOf("WebGPU"));
        this.mem.storeI32(off(4), ENUMS.AdapterType.indexOf("Unknown"));
        return STATUS_SUCCESS;
    }
    FeatureNamePtr(ptr) {
        return this.FeatureName(this.mem.loadI32(ptr));
    }
    FeatureName(featureInt) {
        return ENUMS.FeatureName[featureInt];
    }
    RequiredLimitsPtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }
        const limits = this.Limits(start);
        if (!limits) {
            return undefined;
        }
        const limitsRecord = {};
        for (const key in limits) {
            const value = limits[key];
            if (typeof value === "number") {
                limitsRecord[key] = value;
            }
        }
        return limitsRecord;
    }
    Limits(start) {
        const limitU32 = (ptr) => {
            const value = this.mem.loadU32(ptr);
            if (value == LIMIT_32_UNDEFINED) {
                return undefined;
            }
            return value;
        };
        const limitU64 = (ptr) => {
            const part1 = this.mem.loadU32(ptr);
            const part2 = this.mem.loadU32(ptr + 4);
            if (part1 != 0xffffffff || part2 != 0xffffffff) {
                return this.mem.loadU64(ptr);
            }
            return undefined;
        };
        const off = this.struct(start);
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
        };
    }
    QueueDescriptor(start) {
        return {
            label: this.StringView(start),
        };
    }
    ComputePassTimestampWritesPtr(ptr) {
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
    RenderPassColorAttachment(start) {
        const off = this.struct(start);
        const viewIdx = this.mem.loadPtr(off(4));
        this.assert(viewIdx != 0);
        const resolveTargetIdx = this.mem.loadPtr(off(4));
        const loadOp = this.enumeration("LoadOp", off(4));
        const storeOp = this.enumeration("StoreOp", off(4));
        const clearValue = this.Color(off(this.sizes.Color));
        const depthSliceValue = this.mem.loadU32(off(4));
        const depthSlice = depthSliceValue === DEPTH_SLICE_UNDEFINED
            ? undefined
            : depthSliceValue;
        const result = {
            view: this.textureViews.get(viewIdx),
            resolveTarget: resolveTargetIdx > 0
                ? this.textureViews.get(resolveTargetIdx)
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
    Color(start) {
        const off = this.struct(start);
        return {
            r: this.mem.loadF64(off(8)),
            g: this.mem.loadF64(off(8)),
            b: this.mem.loadF64(off(8)),
            a: this.mem.loadF64(off(8)),
        };
    }
    RenderPassDepthStencilAttachmentPtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return undefined;
        }
        const off = this.struct(start);
        const viewIdx = this.mem.loadPtr(off(4));
        if (viewIdx === 0) {
            return undefined;
        }
        const result = {
            view: this.textureViews.get(viewIdx),
        };
        result.depthLoadOp = this.enumeration("LoadOp", off(4));
        result.depthStoreOp = this.enumeration("StoreOp", off(4));
        result.depthClearValue = this.mem.loadF32(off(4));
        result.depthReadOnly = this.mem.loadU32(off(4)) !== 0;
        result.stencilLoadOp = this.enumeration("LoadOp", off(4));
        result.stencilStoreOp = this.enumeration("StoreOp", off(4));
        result.stencilClearValue = this.mem.loadU32(off(4));
        result.stencilReadOnly = this.mem.loadU32(off(4)) !== 0;
        return result;
    }
    QuerySet(ptr) {
        const querySetPtr = this.mem.loadPtr(ptr);
        if (querySetPtr == 0) {
            return undefined;
        }
        return this.querySets.get(querySetPtr);
    }
    RenderPassTimestampWritesPtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return undefined;
        }
        const off = this.struct(start);
        const querySetIdx = this.mem.loadPtr(off(4));
        if (querySetIdx === 0) {
            return undefined;
        }
        return {
            querySet: this.querySets.get(querySetIdx),
            beginningOfPassWriteIndex: this.mem.loadU32(off(4)),
            endOfPassWriteIndex: this.mem.loadU32(off(4)),
        };
    }
    ConstantEntry(start) {
        const off = this.struct(start);
        off(4);
        return {
            key: this.StringView(off(this.sizes.StringView)),
            value: this.mem.loadF64(off(8)),
        };
    }
    VertexState(start) {
        const off = this.struct(start);
        const shaderModuleIdx = this.mem.loadPtr(off(4));
        const entryPoint = this.StringView(off(this.sizes.StringView));
        const constantsPtr = this.mem.loadPtr(off(4));
        const constantsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const constantsArray = this.array(constantsLen, constantsPtr, this.ConstantEntry, this.sizes.ConstantEntry[0]);
        const buffersPtr = this.mem.loadPtr(off(4));
        const buffersLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const buffersArray = this.array(buffersLen, buffersPtr, this.VertexBufferLayout, this.sizes.VertexBufferLayout[0]);
        const result = {
            module: this.shaderModules.get(shaderModuleIdx),
            entryPoint: entryPoint,
            constants: constantsArray.reduce((prev, curr) => {
                prev[curr.key] = curr.value;
                return prev;
            }, {}),
            buffers: buffersArray,
        };
        return result;
    }
    VertexBufferLayout(start) {
        const off = this.struct(start);
        const arrayStride = this.mem.loadU64(off(8));
        const stepMode = this.VertexStepMode(this.mem.loadU32(off(4)));
        const attributesPtr = this.mem.loadPtr(off(4));
        const attributesLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const attributesArray = this.array(attributesLen, attributesPtr, this.VertexAttribute, this.sizes.VertexAttribute[0]);
        return {
            arrayStride: Number(arrayStride),
            stepMode: stepMode,
            attributes: attributesArray,
        };
    }
    VertexStepMode(value) {
        switch (value) {
            case 1:
                return "vertex";
            case 2:
                return "instance";
            default:
                throw new Error(`Invalid VertexStepMode: ${value}`);
        }
    }
    VertexAttribute(start) {
        const off = this.struct(start);
        return {
            format: this.enumeration("VertexFormat", off(4)),
            offset: Number(this.mem.loadU64(off(8))),
            shaderLocation: this.mem.loadU32(off(4)),
        };
    }
    PrimitiveState(start) {
        const off = this.struct(start);
        const result = {
            topology: this.enumeration("PrimitiveTopology", off(4)),
            stripIndexFormat: this.enumeration("IndexFormat", off(4)),
            frontFace: this.enumeration("FrontFace", off(4)),
            cullMode: this.enumeration("CullMode", off(4)),
            unclippedDepth: this.mem.loadB32(off(4)),
        };
        off(4);
        off(4);
        return result;
    }
    RenderPipelineDescriptor(start) {
        const off = this.struct(start);
        const label = this.StringView(off(this.sizes.StringView));
        const layoutIdx = this.mem.loadPtr(off(4));
        const result = {
            label: label,
            layout: layoutIdx > 0 ? this.pipelineLayouts.get(layoutIdx) : "auto",
            vertex: this.VertexState(off(this.sizes.VertexState)),
            primitive: this.PrimitiveState(off(this.sizes.PrimitiveState)),
            depthStencil: this.DepthStencilStatePtr(off(4)),
            multisample: this.MultisampleState(off(this.sizes.MultisampleState)),
            fragment: this.FragmentStatePtr(off(4)),
        };
        return result;
    }
    DepthBiasState(start) {
        let currentOffset = start;
        const constant = this.mem.loadI32(currentOffset);
        currentOffset += 4;
        const slopeScale = this.mem.loadF32(currentOffset);
        currentOffset += 4;
        const clamp = this.mem.loadF32(currentOffset);
        currentOffset += 4;
        return {
            constant: constant,
            slopeScale: slopeScale,
            clamp: clamp,
        };
    }
    StencilState(start) {
        let currentOffset = start;
        const front = this.StencilFaceState(currentOffset);
        currentOffset += this.sizes.StencilFaceState[0];
        const back = this.StencilFaceState(currentOffset);
        currentOffset += this.sizes.StencilFaceState[0];
        const readMask = this.mem.loadU32(currentOffset);
        currentOffset += 4;
        const writeMask = this.mem.loadU32(currentOffset);
        currentOffset += 4;
        return {
            front: front,
            back: back,
            readMask: readMask,
            writeMask: writeMask,
        };
    }
    DepthStencilStatePtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }
        let currentOffset = start;
        const format = this.enumeration("TextureFormat", currentOffset);
        currentOffset += 4;
        const depthWriteEnabled = this.mem.loadU32(currentOffset) !== 0;
        currentOffset += 4;
        const depthCompare = this.enumeration("CompareFunction", currentOffset);
        currentOffset += 4;
        const stencil = this.StencilState(currentOffset);
        currentOffset += this.sizes.StencilState[0];
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
    MultisampleState(start) {
        const off = this.struct(start);
        const count = this.mem.loadU32(off(4));
        const mask = this.mem.loadU32(off(4));
        const alphaToCoverageEnabled = this.mem.loadB32(off(4));
        return {
            count: count,
            mask: mask,
            alphaToCoverageEnabled: alphaToCoverageEnabled,
        };
    }
    StencilFaceState(start) {
        return {
            compare: this.enumeration("CompareFunction", start + 0),
            failOp: this.enumeration("StencilOperation", start + 4),
            depthFailOp: this.enumeration("StencilOperation", start + 8),
            passOp: this.enumeration("StencilOperation", start + 12),
        };
    }
    FragmentStatePtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start == 0) {
            return undefined;
        }
        const off = this.struct(start);
        const shaderModule = this.shaderModules.get(this.mem.loadPtr(off(4)));
        const entryPoint = this.StringView(off(this.sizes.StringView[0]));
        const constantsPtr = this.mem.loadPtr(off(4));
        const constantsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const constantsArray = this.array(constantsLen, constantsPtr, this.ConstantEntry, this.sizes.ConstantEntry[0]);
        const targetsPtr = this.mem.loadPtr(off(4));
        const targetsLen = Number(this.mem.loadUint(off(this.mem.intSize)));
        const targetsArray = this.array(targetsLen, targetsPtr, this.ColorTargetState, this.sizes.ColorTargetState[0]);
        const result = {
            module: shaderModule,
            entryPoint: entryPoint,
            constants: constantsArray.reduce((prev, curr) => {
                prev[curr.key] = curr.value;
                return prev;
            }, {}),
            targets: targetsArray,
        };
        return result;
    }
    ColorTargetState(start) {
        const off = this.struct(start);
        const format = this.enumeration("TextureFormat", off(4));
        const blend = this.BlendStatePtr(off(4));
        const writeMask = Number(this.mem.loadU64(off(8)));
        return {
            format: format,
            blend: blend,
            writeMask: writeMask,
        };
    }
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
    BlendComponent(start) {
        return {
            operation: this.enumeration("BlendOperation", start + 0),
            srcFactor: this.enumeration("BlendFactor", start + 4),
            dstFactor: this.enumeration("BlendFactor", start + 8),
        };
    }
    StringView(start) {
        const data = this.mem.loadPtr(start);
        const length = this.mem.loadUint(start + this.mem.intSize);
        return this.mem.loadString(data, length);
    }
    CallbackInfoPtr(ptr) {
        const start = this.mem.loadPtr(ptr);
        if (start === 0) {
            return null;
        }
        return this.CallbackInfo(start);
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
        this.zeroMessageAddr = this.mem.exports.gpu_alloc(this.sizes.StringView[0]);
        return this.zeroMessageAddr;
    }
    makeMessageArg(message) {
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
    BindGroupEntry(start) {
        const binding = this.mem.loadU32(start);
        const buffer = this.mem.loadPtr(start + 4);
        const offset = this.mem.loadU64(start + 8);
        const size = this.mem.loadU64(start + 16);
        const sampler = this.mem.loadPtr(start + 24);
        const textureView = this.mem.loadPtr(start + 28);
        let resource;
        if (buffer > 0) {
            resource = {
                buffer: this.buffers.get(buffer).buffer,
                offset: Number(offset),
                size: Number(size),
            };
        }
        else if (sampler > 0) {
            resource = this.samplers.get(sampler);
        }
        else if (textureView > 0) {
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
    Origin3D(start) {
        return {
            x: this.mem.loadU32(start + 0),
            y: this.mem.loadU32(start + 4),
            z: this.mem.loadU32(start + 8),
        };
    }
    Extent3D(start) {
        return {
            width: this.mem.loadU32(start + 0),
            height: this.mem.loadU32(start + 4),
            depthOrArrayLayers: this.mem.loadU32(start + 8),
        };
    }
    BindGroupLayoutEntry(start) {
        const off = this.struct(start);
        const entry = {
            binding: this.mem.loadU32(off(4)),
            visibility: Number(this.mem.loadU64(off(8))),
            buffer: this.BufferBindingLayout(off(this.sizes.BufferBindingLayout)),
            sampler: this.SamplerBindingLayout(off(this.sizes.SamplerBindingLayout)),
            texture: this.TextureBindingLayout(off(this.sizes.TextureBindingLayout)),
            storageTexture: this.StorageTextureBindingLayout(off(this.sizes.StorageTextureBindingLayout)),
        };
        if (!entry.buffer?.type) {
            entry.buffer = undefined;
        }
        if (!entry.sampler?.type) {
            entry.sampler = undefined;
        }
        if (!entry.texture?.sampleType) {
            entry.texture = undefined;
        }
        if (!entry.storageTexture?.access) {
            entry.storageTexture = undefined;
        }
        return entry;
    }
    BufferBindingLayout(start) {
        return {
            type: this.enumeration("BufferBindingType", start),
            hasDynamicOffset: this.mem.loadU8(start + 4) !== 0,
            minBindingSize: Number(this.mem.loadU64(start + 8)),
        };
    }
    SamplerBindingLayout(start) {
        return {
            type: this.enumeration("SamplerBindingType", start),
        };
    }
    TextureBindingLayout(start) {
        return {
            sampleType: this.enumeration("TextureSampleType", start),
            viewDimension: this.enumeration("TextureViewDimension", start + 4),
            multisampled: this.mem.loadB32(start + 8),
        };
    }
    StorageTextureBindingLayout(start) {
        return {
            access: this.enumeration("StorageTextureAccess", start),
            format: this.enumeration("TextureFormat", start + 4),
            viewDimension: this.enumeration("TextureViewDimension", start + 8),
        };
    }
    TexelCopyBufferLayout(start) {
        const off = this.struct(start);
        return {
            offset: Number(this.mem.loadU64(off(8))),
            bytesPerRow: this.mem.loadU32(off(4)),
            rowsPerImage: this.mem.loadU32(off(4)),
        };
    }
    TexelCopyTextureInfo(start) {
        const off = this.struct(start);
        return {
            texture: this.textures.get(this.mem.loadPtr(off(4))),
            mipLevel: this.mem.loadU32(off(4)),
            origin: this.Origin3D(off(this.sizes.Origin3D)),
            aspect: this.enumeration("TextureAspect", off(4)),
        };
    }
    getInterface() {
        return {
            webgpuCreateInstance: (_descriptorPtr) => {
                if (!navigator.gpu) {
                    console.error("WebGPU is not supported by this browser");
                    return 0;
                }
                return this.instances.create({});
            },
            webgpuAdapterGetFeatures: (adapterIdx, featuresPtr) => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    this.genericGetFeatures(adapter.features, featuresPtr);
                }
            },
            webgpuAdapterGetInfo: (_adapterIdx, infoPtr) => {
                return this.genericGetAdapterInfo(infoPtr);
            },
            webgpuAdapterGetLimits: (adapterIdx, limitsPtr) => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    return this.genericGetLimits(adapter.limits, limitsPtr);
                }
                return STATUS_ERROR;
            },
            webgpuAdapterHasFeature: (adapterIdx, featureInt) => {
                const adapter = this.adapters.get(adapterIdx);
                if (adapter) {
                    return adapter.features.has(this.FeatureName(featureInt));
                }
                return false;
            },
            webgpuAdapterRequestDevice: (adapterIdx, descriptorPtr, callbackInfoPtr) => {
                const adapter = this.adapters.get(adapterIdx);
                if (!adapter) {
                    return 0n;
                }
                const off = this.struct(descriptorPtr);
                let descriptor;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(off(this.sizes.StringView)),
                        requiredFeatures: this.array(Number(this.mem.loadUint(off(this.mem.intSize))), this.mem.loadPtr(off(4)), this.FeatureNamePtr, 4),
                        requiredLimits: this.RequiredLimitsPtr(off(4)),
                        defaultQueue: this.QueueDescriptor(off(this.sizes.QueueDescriptor)),
                    };
                }
                const callbackInfo = this.CallbackInfo(callbackInfoPtr);
                const deviceLostCallbackInfo = this.CallbackInfo(off(this.sizes.CallbackInfo));
                const uncapturedErrorCallbackInfo = this.UncapturedErrorCallbackInfo(off(this.sizes.UncapturedErrorCallbackInfo));
                adapter
                    .requestDevice(descriptor)
                    .then((device) => {
                    if (!device) {
                        const messageAddr = this.makeMessageArg("Failed to create device");
                        this.callCallback(callbackInfo, [
                            ENUMS.RequestDeviceStatus.indexOf("Error"),
                            messageAddr,
                        ]);
                        this.mem.exports.gpu_free(messageAddr);
                        return;
                    }
                    const deviceIdx = this.devices.create(device);
                    if (deviceLostCallbackInfo.callback !== null) {
                        device.lost.then((info) => {
                            const reason = ENUMS.DeviceLostReason.indexOf(info.reason);
                            const devicePtr = this.mem.exports.gpu_alloc(4);
                            this.mem.storeI32(devicePtr, deviceIdx);
                            const messageAddr = this.makeMessageArg(info.message);
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
                        device.addEventListener("uncapturederror", (ev) => {
                            let status;
                            if (ev.error instanceof GPUValidationError) {
                                status =
                                    ENUMS.ErrorType.indexOf("validation");
                            }
                            else if (ev.error instanceof GPUOutOfMemoryError) {
                                status =
                                    ENUMS.ErrorType.indexOf("out-of-memory");
                            }
                            else if (ev.error instanceof GPUInternalError) {
                                status =
                                    ENUMS.ErrorType.indexOf("internal");
                            }
                            else {
                                status =
                                    ENUMS.ErrorType.indexOf("unknown");
                            }
                            const messageAddr = this.makeMessageArg(ev.error.message);
                            this.callCallback(uncapturedErrorCallbackInfo, [deviceIdx, status, messageAddr]);
                            this.mem.exports.gpu_free(messageAddr);
                        });
                    }
                    this.callCallback(callbackInfo, [
                        ENUMS.RequestDeviceStatus.indexOf("Success"),
                        deviceIdx,
                        this.zeroMessageArg(),
                    ]);
                })
                    .catch((e) => {
                    const messageAddr = this.makeMessageArg(e.message);
                    this.callCallback(callbackInfo, [
                        ENUMS.RequestDeviceStatus.indexOf("Error"),
                        messageAddr,
                    ]);
                    this.mem.exports.gpu_free(messageAddr);
                });
                return 0n;
            },
            webgpuAdapterInfoFreeMembers: (_infoPtr) => {
            },
            ...this.adapters.interface(true),
            ...this.bindGroups.interface(true),
            ...this.bindGroupLayouts.interface(true),
            webgpuBufferDestroy: (bufferIdx) => {
                const buffer = this.buffers.get(bufferIdx);
                if (buffer) {
                    buffer.buffer.destroy();
                }
            },
            webgpuBufferGetConstMappedRange: (bufferIdx, offset, size) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer)
                    return 0;
                offset = this.unwrapBigInt(offset);
                size = this.unwrapBigInt(size);
                this.assert(!buffer.mapping, "buffer already mapped");
                const range = buffer.buffer.getMappedRange(offset, size);
                const ptr = this.mem.exports.gpu_alloc(range.byteLength);
                const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
                mapping.set(new Uint8Array(range));
                buffer.mapping = {
                    range: range,
                    ptr: ptr,
                    size: range.byteLength,
                };
                return ptr;
            },
            webgpuBufferGetMapState: (bufferIdx) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer)
                    return ENUMS.BufferMapState.indexOf("unmapped");
                return ENUMS.BufferMapState.indexOf(buffer.mapState || "unmapped");
            },
            webgpuBufferGetMappedRange: (bufferIdx, offset, size) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer)
                    return 0;
                offset = this.unwrapBigInt(offset);
                size = this.unwrapBigInt(size);
                this.assert(!buffer.mapping, "buffer already mapped");
                const range = buffer.buffer.getMappedRange(offset, size);
                const ptr = this.mem.exports.gpu_alloc(range.byteLength);
                const mapping = new Uint8Array(this.mem.memory.buffer, ptr, size);
                mapping.set(new Uint8Array(range));
                buffer.mapping = {
                    range: range,
                    ptr: ptr,
                    size: range.byteLength,
                };
                return ptr;
            },
            webgpuBufferGetSize: (bufferIdx) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer)
                    return 0n;
                return BigInt(buffer.buffer.size);
            },
            webgpuBufferGetUsage: (bufferIdx) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer)
                    return 0;
                return buffer.buffer.usage;
            },
            webgpuBufferUnmap: (bufferIdx) => {
                const buffer = this.buffers.get(bufferIdx);
                if (!buffer || !buffer.mapping)
                    return;
                this.assert(buffer.mapping != null, "buffer not mapped");
                const mapping = new Uint8Array(this.mem.memory.buffer, buffer.mapping.ptr, buffer.mapping.size);
                new Uint8Array(buffer.mapping.range).set(mapping);
                buffer.buffer.unmap();
                this.mem.exports.gpu_free(buffer.mapping.ptr);
                buffer.mapping = null;
            },
            ...this.buffers.interface(true),
            webgpuCommandEncoderBeginRenderPass: (commandEncoderIdx, descriptorPtr) => {
                const commandEncoder = this.commandEncoders.get(commandEncoderIdx);
                if (!commandEncoder)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const label = this.StringView(off(this.sizes.StringView));
                const colorAttachmentsPtr = this.mem.loadPtr(off(4));
                const colorAttachmentsLen = this.mem.loadUint(off(this.mem.intSize));
                const colorAttachments = this.array(Number(colorAttachmentsLen), colorAttachmentsPtr, this.RenderPassColorAttachment.bind(this), this.sizes.RenderPassColorAttachment[0]);
                const depthStencilAttachment = this.RenderPassDepthStencilAttachmentPtr(off(4));
                const timestampWritesPtr = this.mem.loadPtr(off(4));
                const timestampWrites = timestampWritesPtr !== 0
                    ? this.RenderPassTimestampWritesPtr(timestampWritesPtr)
                    : undefined;
                const occlusionQuerySetPtr = this.mem.loadPtr(off(4));
                const occlusionQuerySet = occlusionQuerySetPtr !== 0
                    ? this.querySets.get(occlusionQuerySetPtr)
                    : undefined;
                const descriptor = {
                    label,
                    colorAttachments,
                    depthStencilAttachment,
                    timestampWrites,
                    occlusionQuerySet,
                };
                const renderPassEncoder = commandEncoder.beginRenderPass(descriptor);
                return this.renderPassEncoders.create(renderPassEncoder);
            },
            webgpuCommandEncoderFinish: (commandEncoderIdx, descriptorPtr) => {
                const commandEncoder = this.commandEncoders.get(commandEncoderIdx);
                if (!commandEncoder)
                    return 0;
                let descriptor;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(descriptorPtr + 4),
                    };
                }
                const commandBuffer = commandEncoder.finish(descriptor);
                return this.commandBuffers.create(commandBuffer);
            },
            ...this.commandEncoders.interface(true),
            ...this.commandBuffers.interface(true),
            ...this.computePassEncoders.interface(true),
            webgpuDeviceCreateBindGroup: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const descriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    layout: this.bindGroupLayouts.get(this.mem.loadPtr(off(4))),
                    entries: this.array(Number(this.mem.loadUint(off(this.mem.intSize))), this.mem.loadPtr(off(4)), this.BindGroupEntry, this.sizes.BindGroupEntry[0]),
                };
                const bindGroup = device.createBindGroup(descriptor);
                return this.bindGroups.create(bindGroup);
            },
            webgpuDeviceCreateBindGroupLayout: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const descriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    entries: this.array(Number(this.mem.loadUint(off(this.mem.intSize))), this.mem.loadPtr(off(4)), this.BindGroupLayoutEntry, this.sizes.BindGroupLayoutEntry[0]),
                };
                const layout = device.createBindGroupLayout(descriptor);
                return this.bindGroupLayouts.create(layout);
            },
            webgpuDeviceCreateBuffer: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const label = this.StringView(off(this.sizes.StringView[0]));
                const size = Number(this.mem.loadU64(off(8)));
                const usage = Number(this.mem.loadU64(off(8)));
                const mappedAtCreation = this.mem.loadB32(off(4));
                const descriptor = {
                    label: label,
                    usage: usage,
                    size: size,
                    mappedAtCreation: mappedAtCreation,
                };
                const buffer = device.createBuffer(descriptor);
                return this.buffers.create({ buffer: buffer, mapping: null });
            },
            webgpuDeviceCreateSampler: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                let descriptor;
                if (descriptorPtr != 0) {
                    const off = this.struct(descriptorPtr);
                    descriptor = {
                        label: this.StringView(off(this.sizes.StringView)),
                        addressModeU: this.enumeration("AddressMode", off(4)),
                        addressModeV: this.enumeration("AddressMode", off(4)),
                        addressModeW: this.enumeration("AddressMode", off(4)),
                        magFilter: this.enumeration("FilterMode", off(4)),
                        minFilter: this.enumeration("FilterMode", off(4)),
                        mipmapFilter: this.enumeration("MipmapFilterMode", off(4)),
                        lodMinClamp: this.mem.loadF32(off(4)),
                        lodMaxClamp: this.mem.loadF32(off(4)),
                        compare: this.enumeration("CompareFunction", off(4)),
                        maxAnisotropy: this.mem.loadU16(off(2)),
                    };
                }
                const sampler = device.createSampler(descriptor);
                return this.samplers.create(sampler);
            },
            webgpuDeviceCreateShaderModule: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const descriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    code: this.StringView(off(this.sizes.StringView)),
                };
                const shaderModule = device.createShaderModule(descriptor);
                return this.shaderModules.create(shaderModule);
            },
            webgpuDeviceCreateTexture: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const descriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    size: this.Extent3D(off(this.sizes.Extent3D)),
                    mipLevelCount: this.mem.loadU32(off(4)),
                    sampleCount: this.mem.loadU32(off(4)),
                    dimension: this.enumeration("TextureDimension", off(4)),
                    format: this.enumeration("TextureFormat", off(4)),
                    usage: Number(this.mem.loadU64(off(8))),
                    viewFormats: this.array(Number(this.mem.loadUint(off(this.mem.intSize))), this.mem.loadPtr(off(4)), (ptr) => this.enumeration("TextureFormat", ptr), 4),
                };
                const texture = device.createTexture(descriptor);
                return this.textures.create(texture);
            },
            webgpuDeviceCreatePipelineLayout: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const off = this.struct(descriptorPtr);
                const descriptor = {
                    label: this.StringView(off(this.sizes.StringView)),
                    bindGroupLayouts: this.array(Number(this.mem.loadUint(off(this.mem.intSize))), this.mem.loadPtr(off(4)), (ptr) => this.bindGroupLayouts.get(this.mem.loadPtr(ptr)), 4),
                };
                const pipelineLayout = device.createPipelineLayout(descriptor);
                return this.pipelineLayouts.create(pipelineLayout);
            },
            webgpuDeviceGetQueue: (deviceIdx) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                return this.queues.create(device.queue);
            },
            webgpuDeviceGetFeatures: (deviceIdx, featuresPtr) => {
                const device = this.devices.get(deviceIdx);
                if (device) {
                    this.genericGetFeatures(device.features, featuresPtr);
                }
            },
            webgpuDeviceCreateCommandEncoder: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                let descriptor;
                if (descriptorPtr != 0) {
                    descriptor = {
                        label: this.StringView(descriptorPtr + 4),
                    };
                }
                const commandEncoder = device.createCommandEncoder(descriptor);
                return this.commandEncoders.create(commandEncoder);
            },
            webgpuDeviceCreateRenderPipeline: (deviceIdx, descriptorPtr) => {
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return 0;
                this.assert(descriptorPtr != 0);
                const descriptor = this.RenderPipelineDescriptor(descriptorPtr);
                const renderPipeline = device.createRenderPipeline(descriptor);
                return this.renderPipelines.create(renderPipeline);
            },
            ...this.devices.interface(true),
            webgpuInstanceCreateSurface: (instanceIdx, selectorPtr, selectorLen) => {
                this.assert(instanceIdx > 0);
                this.assert(selectorPtr != 0);
                const selector = this.mem.loadString(selectorPtr, selectorLen);
                const surface = document.querySelector(selector);
                if (!surface) {
                    throw new Error(`Selector '${selector}' did not match any element`);
                }
                if (!(surface instanceof HTMLCanvasElement)) {
                    throw new Error("Selector matches an element that is not a canvas");
                }
                return this.surfaces.create(surface);
            },
            webgpuInstanceRequestAdapter: (instanceIdx, optionsPtr, callbackInfoPtr) => {
                this.assert(instanceIdx > 0);
                let options;
                if (optionsPtr != 0) {
                    const off = this.struct(optionsPtr);
                    options = {
                        powerPreference: this.enumeration("PowerPreference", off(4)),
                        forceFallbackAdapter: this.mem.loadB32(off(4)),
                    };
                }
                const callbackInfo = this.CallbackInfo(callbackInfoPtr);
                navigator.gpu
                    .requestAdapter(options)
                    .then((adapter) => {
                    if (!adapter) {
                        const messageAddr = this.makeMessageArg("No adapter found");
                        this.callCallback(callbackInfo, [
                            ENUMS.RequestAdapterStatus.indexOf("Unavailable"),
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
                    .catch((e) => {
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
            ...this.pipelineLayouts.interface(true),
            webgpuQueueSubmit: (queueIdx, commandCount, commandsPtr) => {
                const queue = this.queues.get(queueIdx);
                if (!queue)
                    return;
                const commands = this.array(this.unwrapBigInt(commandCount), commandsPtr, (ptr) => this.commandBuffers.get(this.mem.loadPtr(ptr)), 4);
                queue.submit(commands);
            },
            webgpuQueueWriteBuffer: (queueIdx, bufferIdx, bufferOffset, dataPtr, size) => {
                const queue = this.queues.get(queueIdx);
                const buffer = this.buffers.get(bufferIdx);
                if (!queue || !buffer)
                    return;
                bufferOffset = this.unwrapBigInt(bufferOffset);
                size = this.unwrapBigInt(size);
                const data = this.mem.loadBytes(dataPtr, size);
                queue.writeBuffer(buffer.buffer, bufferOffset, data, 0, size);
            },
            webgpuQueueWriteTexture: (queueIdx, destinationPtr, dataPtr, dataSize, dataLayoutPtr, writeSizePtr) => {
                const queue = this.queues.get(queueIdx);
                if (!queue)
                    return;
                const destination = this.TexelCopyTextureInfo(destinationPtr);
                dataSize = this.unwrapBigInt(dataSize);
                const dataLayout = this.TexelCopyBufferLayout(dataLayoutPtr);
                const writeSize = this.Extent3D(writeSizePtr);
                const data = this.mem.loadBytes(dataPtr, dataSize);
                queue.writeTexture(destination, data, dataLayout, writeSize);
            },
            ...this.queues.interface(true),
            webgpuRenderPassEncoderBeginOcclusionQuery: (renderPassEncoderIdx, queryIndex) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.beginOcclusionQuery(queryIndex);
            },
            webgpuRenderPassEncoderDraw: (renderPassEncoderIdx, vertexCount, instanceCount, firstVertex, firstInstance) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.draw(vertexCount, instanceCount, firstVertex, firstInstance);
            },
            webgpuRenderPassEncoderDrawIndexed: (renderPassEncoderIdx, indexCount, instanceCount, firstIndex, baseVertex, firstInstance) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.drawIndexed(indexCount, instanceCount, firstIndex, baseVertex, firstInstance);
            },
            webgpuRenderPassEncoderDrawIndexedIndirect: (renderPassEncoderIdx, indirectBufferIdx, indirectOffset) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(indirectBufferIdx);
                if (!renderPassEncoder || !buffer)
                    return;
                indirectOffset = BigInt(this.unwrapBigInt(indirectOffset));
                renderPassEncoder.drawIndexedIndirect(buffer.buffer, Number(indirectOffset));
            },
            webgpuRenderPassEncoderDrawIndirect: (renderPassEncoderIdx, indirectBufferIdx, indirectOffset) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(indirectBufferIdx);
                if (!renderPassEncoder || !buffer)
                    return;
                indirectOffset = BigInt(this.unwrapBigInt(indirectOffset));
                renderPassEncoder.drawIndirect(buffer.buffer, Number(indirectOffset));
            },
            webgpuRenderPassEncoderEnd: (renderPassEncoderIdx) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.end();
            },
            webgpuRenderPassEncoderEndOcclusionQuery: (renderPassEncoderIdx) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.endOcclusionQuery();
            },
            webgpuRenderPassEncoderExecuteBundles: (renderPassEncoderIdx, bundleCount, bundlesPtr) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                bundleCount = this.unwrapBigInt(bundleCount);
                const bundles = this.array(bundleCount, bundlesPtr, (ptr) => this.renderBundles.get(this.mem.loadPtr(ptr)), 4);
                renderPassEncoder.executeBundles(bundles);
            },
            webgpuRenderPassEncoderInsertDebugMarker: (renderPassEncoderIdx, markerLabelPtr, markerLabelLen) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                const markerLabel = this.mem.loadString(markerLabelPtr, markerLabelLen);
                renderPassEncoder.insertDebugMarker(markerLabel);
            },
            webgpuRenderPassEncoderPopDebugGroup: (renderPassEncoderIdx) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.popDebugGroup();
            },
            webgpuRenderPassEncoderPushDebugGroup: (renderPassEncoderIdx, groupLabelPtr, groupLabelLen) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                const groupLabel = this.mem.loadString(groupLabelPtr, groupLabelLen);
                renderPassEncoder.pushDebugGroup(groupLabel);
            },
            webgpuRenderPassEncoderSetBindGroup: (renderPassEncoderIdx, groupIndex, groupIdx, dynamicOffsetCount, dynamicOffsetsPtr) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                let group;
                if (groupIdx > 0) {
                    group = this.bindGroups.get(groupIdx);
                }
                dynamicOffsetCount = this.unwrapBigInt(dynamicOffsetCount);
                const dynamicOffsets = this.array(dynamicOffsetCount, dynamicOffsetsPtr, (ptr) => this.mem.loadU32(ptr), 4);
                renderPassEncoder.setBindGroup(groupIndex, group, dynamicOffsets);
            },
            webgpuRenderPassEncoderSetBlendConstant: (renderPassEncoderIdx, colorPtr) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                this.assert(colorPtr != 0);
                renderPassEncoder.setBlendConstant(this.Color(colorPtr));
            },
            webgpuRenderPassEncoderSetIndexBuffer: (renderPassEncoderIdx, bufferIdx, formatInt, offset, size) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                const buffer = this.buffers.get(bufferIdx);
                if (!renderPassEncoder || !buffer)
                    return;
                const format = ENUMS.IndexFormat[formatInt];
                offset = BigInt(this.unwrapBigInt(offset));
                size = BigInt(this.unwrapBigInt(size));
                renderPassEncoder.setIndexBuffer(buffer.buffer, format, Number(offset), Number(size));
            },
            webgpuRenderPassEncoderSetPipeline: (renderPassEncoderIdx, pipelineIdx) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                const pipeline = this.renderPipelines.get(pipelineIdx);
                if (!renderPassEncoder || !pipeline)
                    return;
                renderPassEncoder.setPipeline(pipeline);
            },
            webgpuRenderPassEncoderSetScissorRect: (renderPassEncoderIdx, x, y, width, height) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.setScissorRect(x, y, width, height);
            },
            webgpuRenderPassEncoderSetStencilReference: (renderPassEncoderIdx, reference) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.setStencilReference(reference);
            },
            webgpuRenderPassEncoderSetVertexBuffer: (renderPassEncoderIdx, slot, bufferIdx, offset, size) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                let buffer;
                if (bufferIdx > 0) {
                    const bufferData = this.buffers.get(bufferIdx);
                    if (bufferData) {
                        buffer = bufferData.buffer;
                    }
                }
                offset = BigInt(this.unwrapBigInt(offset));
                size = BigInt(this.unwrapBigInt(size));
                renderPassEncoder.setVertexBuffer(slot, buffer, Number(offset), Number(size));
            },
            webgpuRenderPassEncoderSetViewport: (renderPassEncoderIdx, x, y, width, height, minDepth, maxDepth) => {
                const renderPassEncoder = this.renderPassEncoders.get(renderPassEncoderIdx);
                if (!renderPassEncoder)
                    return;
                renderPassEncoder.setViewport(x, y, width, height, minDepth, maxDepth);
            },
            ...this.renderPassEncoders.interface(true),
            ...this.renderPipelines.interface(true),
            ...this.samplers.interface(true),
            ...this.shaderModules.interface(true),
            webgpuSurfaceConfigure: (surfaceIdx, deviceIdx, configPtr) => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface)
                    return;
                const context = surface.getContext("webgpu");
                if (!context)
                    return;
                const device = this.devices.get(deviceIdx);
                if (!device)
                    return;
                const off = this.struct(configPtr);
                const usage = this.mem.loadU32(off(4));
                const format = this.enumeration("TextureFormat", off(4));
                const width = this.mem.loadU32(off(4));
                const height = this.mem.loadU32(off(4));
                const presentMode = this.enumeration("PresentMode", off(4));
                const desiredMaximumFrameLatency = this.mem.loadU32(off(4));
                let alphaMode = this.enumeration("CompositeAlphaMode", off(4));
                if (alphaMode == "auto") {
                    alphaMode = "opaque";
                }
                const viewFormatsPtr = this.mem.loadPtr(off(4));
                const viewFormatsLen = this.mem.loadUint(off(this.mem.intSize));
                const viewFormats = this.array(Number(viewFormatsLen), viewFormatsPtr, (ptr) => this.enumeration("TextureFormat", ptr), 4);
                surface.width = width;
                surface.height = height;
                const config = {
                    device: device,
                    format: format,
                    usage: usage,
                    viewFormats: viewFormats,
                    alphaMode: alphaMode,
                };
                context.configure(config);
            },
            webgpuSurfaceGetCapabilities: (_surfaceIdx, _adapterIdx, capabilitiesPtr) => {
                const off = this.struct(capabilitiesPtr);
                const formatStr = navigator.gpu.getPreferredCanvasFormat();
                const format = ENUMS.TextureFormat.indexOf(formatStr);
                const formatAddr = this.mem.exports.gpu_alloc(4);
                this.mem.storeI32(formatAddr, format);
                this.mem.storeUint(off(4), formatAddr);
                this.mem.storeUint(off(this.mem.intSize), 1);
                const presentModesAddr = this.mem.exports.gpu_alloc(4);
                this.mem.storeI32(presentModesAddr, ENUMS.PresentMode.indexOf("fifo"));
                this.mem.storeUint(off(4), presentModesAddr);
                this.mem.storeUint(off(this.mem.intSize), 1);
                const alphaModesAddr = this.mem.exports.gpu_alloc(8);
                this.mem.storeI32(alphaModesAddr + 0, ENUMS.CompositeAlphaMode.indexOf("opaque"));
                this.mem.storeI32(alphaModesAddr + 4, ENUMS.CompositeAlphaMode.indexOf("premultiplied"));
                this.mem.storeUint(off(4), alphaModesAddr);
                this.mem.storeUint(off(this.mem.intSize), 2);
                const COPY_SRC = 1 << 0;
                const COPY_DST = 1 << 1;
                const TEXTURE_BINDING = 1 << 2;
                const RENDER_ATTACHMENT = 1 << 4;
                const usages = COPY_SRC | COPY_DST | TEXTURE_BINDING | RENDER_ATTACHMENT;
                this.mem.storeU32(off(4), usages);
                return STATUS_SUCCESS;
            },
            webgpuSurfaceGetCurrentTexture: (surfaceIdx, texturePtr) => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface)
                    return;
                const context = surface.getContext("webgpu");
                if (!context)
                    return;
                const off = this.struct(texturePtr);
                try {
                    const texture = context.getCurrentTexture();
                    const textureIdx = this.textures.create(texture);
                    this.mem.storeUint(off(this.mem.intSize), surfaceIdx);
                    this.mem.storeUint(off(this.mem.intSize), textureIdx);
                    this.mem.storeI32(off(4), 0);
                    this.mem.storeU32(off(4), 0);
                }
                catch (error) {
                    this.mem.storeUint(off(this.mem.intSize), surfaceIdx);
                    this.mem.storeUint(off(this.mem.intSize), 0);
                    this.mem.storeI32(off(4), 3);
                    this.mem.storeU32(off(4), 0);
                    console.error("Failed to get current texture:", error);
                }
            },
            webgpuSurfacePresent: (_surfaceIdx) => {
            },
            webgpuSurfaceUnconfigure: (surfaceIdx) => {
                const surface = this.surfaces.get(surfaceIdx);
                if (!surface)
                    return;
                const context = surface.getContext("webgpu");
                if (!context)
                    return;
                context.unconfigure();
            },
            ...this.surfaces.interface(true),
            webgpuSurfaceCapabilitiesFreeMembers: (surfaceCapabilitiesPtr) => {
                const off = this.struct(surfaceCapabilitiesPtr);
                const formatsAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize);
                if (formatsAddr !== 0) {
                    this.mem.exports.gpu_free(formatsAddr);
                }
                const presentModesAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize);
                if (presentModesAddr !== 0) {
                    this.mem.exports.gpu_free(presentModesAddr);
                }
                const alphaModesAddr = this.mem.loadPtr(off(4));
                off(this.mem.intSize);
                if (alphaModesAddr !== 0) {
                    this.mem.exports.gpu_free(alphaModesAddr);
                }
                off(4);
            },
            webgpuSupportedFeaturesFreeMembers: (_supportedFeaturesCount, supportedFeaturesPtr) => {
                this.mem.exports.gpu_free(supportedFeaturesPtr);
            },
            webgpuTextureCreateView: (textureIdx, descriptorPtr) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                let descriptor;
                if (descriptorPtr != 0) {
                    const off = this.struct(descriptorPtr);
                    const label = this.StringView(off(this.sizes.StringView));
                    const format = this.enumeration("TextureFormat", off(4));
                    const dimension = this.enumeration("TextureViewDimension", off(4));
                    const usage = this.mem.loadU32(off(4));
                    const aspect = this.enumeration("TextureAspect", off(4));
                    const baseMipLevel = this.mem.loadU32(off(4));
                    let mipLevelCount = this.mem.loadU32(off(4));
                    if (mipLevelCount === 0) {
                        mipLevelCount = undefined;
                    }
                    const baseArrayLayer = this.mem.loadU32(off(4));
                    let arrayLayerCount = this.mem.loadU32(off(4));
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
            webgpuTextureDestroy: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (texture) {
                    texture.destroy();
                }
            },
            webgpuTextureGetDepthOrArrayLayers: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.depthOrArrayLayers;
            },
            webgpuTextureGetDimension: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return ENUMS.TextureDimension.indexOf(texture.dimension);
            },
            webgpuTextureGetFormat: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return ENUMS.TextureFormat.indexOf(texture.format);
            },
            webgpuTextureGetHeight: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.height;
            },
            webgpuTextureGetMipLevelCount: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.mipLevelCount;
            },
            webgpuTextureGetSampleCount: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.sampleCount;
            },
            webgpuTextureGetUsage: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.usage;
            },
            webgpuTextureGetWidth: (textureIdx) => {
                const texture = this.textures.get(textureIdx);
                if (!texture)
                    return 0;
                return texture.width;
            },
            ...this.textures.interface(true),
            ...this.textureViews.interface(true),
        };
    }
}
class WebGPUObjectManager {
    constructor(name, mem) {
        Object.defineProperty(this, "name", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "mem", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: void 0
        });
        Object.defineProperty(this, "idx", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: 0
        });
        Object.defineProperty(this, "objects", {
            enumerable: true,
            configurable: true,
            writable: true,
            value: {}
        });
        this.name = name;
        this.mem = mem;
    }
    create(object) {
        this.idx += 1;
        this.objects[this.idx] = { references: 1, object };
        return this.idx;
    }
    get(idx) {
        if (idx <= 0) {
            throw new Error("Invalid object");
        }
        return this.objects[idx]?.object;
    }
    release(idx) {
        if (idx <= 0)
            return;
        const obj = this.objects[idx];
        if (obj) {
            obj.references -= 1;
            if (obj.references <= 0) {
                delete this.objects[idx];
            }
        }
    }
    reference(idx) {
        if (idx <= 0)
            return;
        const obj = this.objects[idx];
        if (obj) {
            obj.references += 1;
        }
    }
    interface(withLabelSetter = false) {
        const inter = {};
        inter[`webgpu${this.name}AddRef`] = this.reference.bind(this);
        inter[`webgpu${this.name}Release`] = this.release.bind(this);
        if (withLabelSetter) {
            inter[`webgpu${this.name}SetLabel`] = (idx, labelPtr, labelLen) => {
                const obj = this.get(idx);
                if (obj && obj.label !== undefined) {
                    obj.label = this.mem.loadString(labelPtr, labelLen);
                }
            };
            inter[`webgpu${this.name}GetLabel`] = (idx) => {
                const obj = this.get(idx);
                if (obj && obj.label !== undefined) {
                    return obj.label;
                }
            };
        }
        return inter;
    }
}
window.odin = window.odin || {};
window.odin.WebGPUInterface = WebGPUInterface;
