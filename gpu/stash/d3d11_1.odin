#+build windows
#+private
package gpu

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/dxgi"
import "vendor:directx/d3d11"

D3D11_COPY_FLAGS :: enum i32 {
    NO_OVERWRITE = 0x1,
    DISCARD      = 0x2,
}

D3D11_LOGIC_OP :: enum i32 {
    CLEAR,
    SET,
    COPY,
    COPY_INVERTED,
    NOOP,
    INVERT,
    AND,
    NAND,
    OR,
    NOR,
    XOR,
    EQUIV,
    AND_REVERSE,
    AND_INVERTED,
    OR_REVERSE,
    OR_INVERTED,
}

D3D11_RENDER_TARGET_BLEND_DESC1 :: struct {
    BlendEnable:           win32.BOOL,
    LogicOpEnable:         win32.BOOL,
    SrcBlend:              d3d11.BLEND,
    DestBlend:             d3d11.BLEND,
    BlendOp:               d3d11.BLEND_OP,
    SrcBlendAlpha:         d3d11.BLEND,
    DestBlendAlpha:        d3d11.BLEND,
    BlendOpAlpha:          d3d11.BLEND_OP,
    LogicOp:               D3D11_LOGIC_OP,
    RenderTargetWriteMask: win32.UINT8,
}

D3D11_RENDER_TARGET_BLEND_DESC1_INIT :: D3D11_RENDER_TARGET_BLEND_DESC1 {
    BlendEnable           = false,
    LogicOpEnable         = false,
    SrcBlend              = .ONE,
    DestBlend             = .ZERO,
    BlendOp               = .ADD,
    SrcBlendAlpha         = .ONE,
    DestBlendAlpha        = .ZERO,
    BlendOpAlpha          = .ADD,
    LogicOp               = .NOOP,
    RenderTargetWriteMask = win32.UINT8(d3d11.COLOR_WRITE_ENABLE_ALL),
}

D3D11_BLEND_DESC1 :: struct {
    AlphaToCoverageEnable:  win32.BOOL,
    IndependentBlendEnable: win32.BOOL,
    RenderTarget:           [8]D3D11_RENDER_TARGET_BLEND_DESC1,
}

D3D11_BLEND_DESC1_INIT :: D3D11_BLEND_DESC1 {
    AlphaToCoverageEnable  = false,
    IndependentBlendEnable = false,
    RenderTarget           = {
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
        D3D11_RENDER_TARGET_BLEND_DESC1_INIT,
    },
}

D3D11_IBlendState1_UUID_STRING :: "cc86fabe-da55-401d-85e7-e3c9de2877e9"
D3D11_IBlendState1_UUID :=
    &win32.IID{0xcc86fabe,0xda55,0x401d,{0x85,0xe7,0xe3,0xc9,0xde,0x28,0x77,0xe9}}
D3D11_IBlendState1 :: struct #raw_union {
    #subtype iblendstate: d3d11.IBlendState,
    using iblendstate1_vtable: ^D3D11_IBlendState1_VTable,
}
D3D11_IBlendState1_VTable :: struct {
    using iblendstate_vtable: d3d11.IBlendState_VTable,
    GetDesc1: proc "system" (this: ^D3D11_IBlendState1, pDesc: ^D3D11_BLEND_DESC1),
}

D3D11_RASTERIZER_DESC1 :: struct {
    FillMode:              d3d11.FILL_MODE,
    CullMode:              d3d11.CULL_MODE,
    FrontCounterClockwise: win32.BOOL,
    DepthBias:             win32.INT,
    DepthBiasClamp:        f32,
    SlopeScaledDepthBias:  f32,
    DepthClipEnable:       win32.BOOL,
    ScissorEnable:         win32.BOOL,
    MultisampleEnable:     win32.BOOL,
    AntialiasedLineEnable: win32.BOOL,
    ForcedSampleCount:     win32.UINT,
}

D3D11_RASTERIZER_DESC1_INIT :: D3D11_RASTERIZER_DESC1 {
    FillMode              = .SOLID,
    CullMode              = .BACK,
    FrontCounterClockwise = false,
    DepthBias             = d3d11.DEFAULT_DEPTH_BIAS,
    DepthBiasClamp        = d3d11.DEFAULT_DEPTH_BIAS_CLAMP,
    SlopeScaledDepthBias  = d3d11.DEFAULT_SLOPE_SCALED_DEPTH_BIAS,
    DepthClipEnable       = true,
    ScissorEnable         = false,
    MultisampleEnable     = false,
    AntialiasedLineEnable = false,
    ForcedSampleCount     = 0,
}

D3D11_IRasterizerState1_UUID_STRING :: "1217d7a6-5039-418c-b042-9cbe256afd6e"
D3D11_IID_IRasterizerState1_UUID :=
    &win32.IID{0x1217d7a6,0x5039,0x418c,{0xb0,0x42,0x9c,0xbe,0x25,0x6a,0xfd,0x6e}}
D3D11_IRasterizerState1 :: struct #raw_union {
    #subtype irasterizerstate: d3d11.IRasterizerState,
    using irasterizerstate1_vtable: ^D3D11_IRasterizerState1_VTable,
}
D3D11_IRasterizerState1_VTable :: struct {
    using irasterizerstate_vtable: d3d11.IRasterizerState_VTable,
    GetDesc1: proc "system" (This: ^D3D11_IRasterizerState1, pDesc: ^D3D11_RASTERIZER_DESC1),
}

D3D11_1_CREATE_DEVICE_CONTEXT_STATE_FLAGS   ::
    distinct bit_set[D3D11_1_CREATE_DEVICE_CONTEXT_STATE_FLAG; u32]
D3D11_1_CREATE_DEVICE_CONTEXT_STATE_FLAG :: enum i32 {
    SINGLETHREADED  = 0,
}

D3D11_ID3DDeviceContextState_UUID_STRING :: "5c1e0d8a-7c23-48f9-8c59-a92958ceff11"
D3D11_ID3DDeviceContextState_UUID :=
    &win32.IID{0x5c1e0d8a,0x7c23,0x48f9,{0x8c,0x59,0xa9,0x29,0x58,0xce,0xff,0x11}}
D3D11_ID3DDeviceContextState :: struct #raw_union {
    #subtype idevicechild: d3d11.IDeviceChild,
    using id3ddevicecontextstate_vtable: ^D3D11_ID3DDeviceContextState_VTable,
}
D3D11_ID3DDeviceContextState_VTable :: struct {
    using idevicechild_vtable: d3d11.IDeviceChild_VTable,
}

D3D11_IDeviceContext1_UUID_STRING :: "bb2c6faa-b5fb-4082-8e6b-388b8cfa90e1"
D3D11_IDeviceContext1_UUID :=
    &win32.IID{0xbb2c6faa,0xb5fb,0x4082,{0x8e,0x6b,0x38,0x8b,0x8c,0xfa,0x90,0xe1}}
D3D11_IDeviceContext1 :: struct #raw_union {
    #subtype idevicecontext: d3d11.IDeviceContext,
    using idevicecontext1_vtable: ^D3D11_IDeviceContext1_VTable,
}
D3D11_IDeviceContext1_VTable :: struct {
    using idevicecontext_vtable: d3d11.IDeviceContext_VTable,
    CopySubresourceRegion1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pDstResource: ^d3d11.IResource,
        DstSubresource: win32.UINT,
        DstX: win32.UINT,
        DstY: win32.UINT,
        DstZ: win32.UINT,
        pSrcResource: ^d3d11.IResource,
        SrcSubresource: win32.UINT,
        pSrcBox: ^d3d11.BOX,
        CopyFlags: D3D11_COPY_FLAGS),
    UpdateSubresource1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pDstResource: ^d3d11.IResource,
        DstSubresource: win32.UINT,
        pDstBox: ^d3d11.BOX,
        pSrcData: rawptr,
        SrcRowPitch: win32.UINT,
        SrcDepthPitch: win32.UINT,
        CopyFlags: D3D11_COPY_FLAGS),
    DiscardResource: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pResource: ^d3d11.IResource),
    DiscardView: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pResourceView: ^d3d11.IView),
    VSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    HSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    DSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    GSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    PSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    CSSetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    VSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    HSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    DSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    GSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    PSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    CSGetConstantBuffers1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        StartSlot: win32.UINT,
        NumBuffers: win32.UINT,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: [^]win32.UINT,
        pNumConstants: [^]win32.UINT),
    SwapDeviceContextState: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pState: ^D3D11_ID3DDeviceContextState,
        ppPreviousState: ^^D3D11_ID3DDeviceContextState),
    ClearView: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pView: ^d3d11.IView,
        Color: [4]f32,
        pRect: [^]d3d11.RECT,
        NumRects: win32.UINT),
    DiscardView1: proc "system" (
        This: ^D3D11_IDeviceContext1,
        pResourceView: ^d3d11.IView,
        pRects: [^]d3d11.RECT,
        NumRects: win32.UINT),
}

D3D11_VIDEO_DECODER_SUB_SAMPLE_MAPPING_BLOCK :: struct {
    ClearSize:     win32.UINT,
    EncryptedSize: win32.UINT,
}

D3D11_VIDEO_DECODER_BUFFER_DESC1 :: struct {
    BufferType:             d3d11.VIDEO_DECODER_BUFFER_TYPE,
    DataOffset:             win32.UINT,
    DataSize:               win32.UINT,
    pIV:                    rawptr,
    IVSize:                 win32.UINT,
    pSubSampleMappingBlock: ^D3D11_VIDEO_DECODER_SUB_SAMPLE_MAPPING_BLOCK,
    SubSampleMappingCount:  win32.UINT,
}

D3D11_VIDEO_DECODER_BEGIN_FRAME_CRYPTO_SESSION :: struct {
    pCryptoSession:  ^d3d11.ICryptoSession,
    BlobSize:        win32.UINT,
    pBlob:           rawptr,
    pKeyInfoId:      ^win32.GUID,
    PrivateDataSize: win32.UINT,
    pPrivateData:    rawptr,
}

D3D11_VIDEO_DECODER_CAPS :: enum i32 {
    DOWNSAMPLE          = 0x1,
    NON_REAL_TIME       = 0x2,
    DOWNSAMPLE_DYNAMIC  = 0x4,
    DOWNSAMPLE_REQUIRED = 0x8,
    UNSUPPORTED         = 0x10,
}

D3D11_VIDEO_PROCESSOR_BEHAVIOR_HINTS :: distinct bit_set[D3D11_VIDEO_PROCESSOR_BEHAVIOR_HINT; u32]
D3D11_VIDEO_PROCESSOR_BEHAVIOR_HINT :: enum i32 {
    MULTIPLANE_OVERLAY_ROTATION               = 0,
    MULTIPLANE_OVERLAY_RESIZE                 = 1,
    MULTIPLANE_OVERLAY_COLOR_SPACE_CONVERSION = 2,
    TRIPLE_BUFFER_OUTPUT                      = 3,
}

D3D11_VIDEO_PROCESSOR_STREAM_BEHAVIOR_HINT :: struct {
    Enable: win32.BOOL,
    Width:  win32.UINT,
    Height: win32.UINT,
    Format: dxgi.FORMAT,
}

D3D11_CRYPTO_SESSION_STATUS :: enum i32 {
    OK                   = 0,
    KEY_LOST             = 1,
    KEY_AND_CONTENT_LOST = 2,
}

D3D11_KEY_EXCHANGE_HW_PROTECTION_INPUT_DATA :: struct {
    PrivateDataSize:      win32.UINT,
    HWProtectionDataSize: win32.UINT,
    pbInput:              [4]win32.BYTE,
}

D3D11_KEY_EXCHANGE_HW_PROTECTION_OUTPUT_DATA :: struct {
    PrivateDataSize:         win32.UINT,
    MaxHWProtectionDataSize: win32.UINT,
    HWProtectionDataSize:    win32.UINT,
    TransportTime:           win32.UINT64,
    ExecutionTime:           win32.UINT64,
    pbOutput:                [4]win32.BYTE,
}

D3D11_KEY_EXCHANGE_HW_PROTECTION_DATA :: struct {
    HWProtectionFunctionID: win32.UINT,
    pInputData:             ^D3D11_KEY_EXCHANGE_HW_PROTECTION_INPUT_DATA,
    pOutputData:            ^D3D11_KEY_EXCHANGE_HW_PROTECTION_OUTPUT_DATA,
    Status:                 win32.HRESULT,
}

D3D11_VIDEO_SAMPLE_DESC :: struct {
    Width:      win32.UINT,
    Height:     win32.UINT,
    Format:     dxgi.FORMAT,
    ColorSpace: dxgi.COLOR_SPACE_TYPE,
}

D3D11_IVideoContext1_UUID_STRING :: "A7F026DA-A5F8-4487-A564-15E34357651E"
D3D11_IVideoContext1_UUID :=
    &win32.IID{0xA7F026DA,0xA5F8,0x4487,{0xA5,0x64,0x15,0xE3,0x43,0x57,0x65,0x1E}}
D3D11_IVideoContext1 :: struct #raw_union {
    #subtype ivideocontext: d3d11.IVideoContext,
    using ivideocontext1_vtable: ^D3D11_IVideoContext1_VTable,
}
D3D11_IVideoContext1_VTable :: struct {
    using ivideocontext_vtable: d3d11.IVideoContext_VTable,
    SubmitDecoderBuffers1: proc "system" (
        This: ^D3D11_IVideoContext1,
        pDecoder: ^d3d11.IVideoDecoder,
        NumBuffers: win32.UINT,
        pBufferDesc: [^]D3D11_VIDEO_DECODER_BUFFER_DESC1) -> win32.HRESULT,
    GetDataForNewHardwareKey: proc "system" (
        This: ^D3D11_IVideoContext1,
        pCryptoSession: ^d3d11.ICryptoSession,
        PrivateInputSize: win32.UINT,
        pPrivatInputData: rawptr,
        pPrivateOutputData: ^win32.UINT64) -> win32.HRESULT,
    CheckCryptoSessionStatus: proc "system" (
        This: ^D3D11_IVideoContext1,
        pCryptoSession: ^d3d11.ICryptoSession,
        pStatus: ^D3D11_CRYPTO_SESSION_STATUS) -> win32.HRESULT,
    DecoderEnableDownsampling: proc "system" (
        This: ^D3D11_IVideoContext1,
        pDecoder: ^d3d11.IVideoDecoder,
        InputColorSpace: dxgi.COLOR_SPACE_TYPE,
        pOutputDesc: ^D3D11_VIDEO_SAMPLE_DESC,
        ReferenceFrameCount: win32.UINT) -> win32.HRESULT,
    DecoderUpdateDownsampling: proc "system" (
        This: ^D3D11_IVideoContext1,
        pDecoder: ^d3d11.IVideoDecoder,
        pOutputDesc: ^D3D11_VIDEO_SAMPLE_DESC) -> win32.HRESULT,
    VideoProcessorSetOutputColorSpace1: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        ColorSpace: dxgi.COLOR_SPACE_TYPE),
    VideoProcessorSetOutputShaderUsage: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        ShaderUsage: win32.BOOL),
    VideoProcessorGetOutputColorSpace1: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        pColorSpace: ^dxgi.COLOR_SPACE_TYPE),
    VideoProcessorGetOutputShaderUsage: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        pShaderUsage: ^win32.BOOL),
    VideoProcessorSetStreamColorSpace1: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        ColorSpace: dxgi.COLOR_SPACE_TYPE),
    VideoProcessorSetStreamMirror: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        Enable: win32.BOOL,
        FlipHorizontal: win32.BOOL,
        FlipVertical: win32.BOOL),
    VideoProcessorGetStreamColorSpace1: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        pColorSpace: ^dxgi.COLOR_SPACE_TYPE),
    VideoProcessorGetStreamMirror: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        pEnable: ^win32.BOOL,
        pFlipHorizontal: ^win32.BOOL,
        pFlipVertical: ^win32.BOOL),
    VideoProcessorGetBehaviorHints: proc "system" (
        This: ^D3D11_IVideoContext1,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        OutputWidth: win32.UINT,
        OutputHeight: win32.UINT,
        OutputFormat: dxgi.FORMAT,
        StreamCount: win32.UINT,
        pStreams: [^]D3D11_VIDEO_PROCESSOR_STREAM_BEHAVIOR_HINT,
        pBehaviorHints: ^D3D11_VIDEO_PROCESSOR_BEHAVIOR_HINTS) -> win32.HRESULT,
}

D3D11_IVideoDevice1_UUID_STRING :: "29DA1D51-1321-4454-804B-F5FC9F861F0F"
D3D11_IVideoDevice1_UUID :=
    &win32.IID{0x29DA1D51,0x1321,0x4454,{0x80,0x4B,0xF5,0xFC,0x9F,0x86,0x1F,0x0F}}
D3D11_IVideoDevice1 :: struct #raw_union {
    #subtype ivideodevice: d3d11.IVideoDevice,
    using ivideodevice1_vtable: ^D3D11_IVideoDevice1_VTable,
}
D3D11_IVideoDevice1_VTable :: struct {
    using ivideodevice_vtable: d3d11.IVideoDevice_VTable,
    GetCryptoSessionPrivateDataSize: proc "system" (
        This: ^D3D11_IVideoDevice1,
        pCryptoType: ^win32.GUID,
        pDecoderProfile: ^win32.GUID,
        pKeyExchangeType: ^win32.GUID,
        pPrivateInputSize: ^win32.UINT,
        pPrivateOutputSize: ^win32.UINT) -> win32.HRESULT,
    GetVideoDecoderCaps: proc "system" (
        This: ^D3D11_IVideoDevice1,
        pDecoderProfile: ^win32.GUID,
        SampleWidth: win32.UINT,
        SampleHeight: win32.UINT,
        pFrameRate: ^dxgi.RATIONAL,
        BitRate: win32.UINT,
        pCryptoType: ^win32.GUID,
        pDecoderCaps: ^win32.UINT) -> win32.HRESULT,
    CheckVideoDecoderDownsampling: proc "system" (
        This: ^D3D11_IVideoDevice1,
        pInputDesc: ^d3d11.VIDEO_DECODER_DESC,
        InputColorSpace: dxgi.COLOR_SPACE_TYPE,
        pInputConfig: ^d3d11.VIDEO_DECODER_CONFIG,
        pFrameRate: ^dxgi.RATIONAL,
        pOutputDesc: ^D3D11_VIDEO_SAMPLE_DESC,
        pSupported: ^win32.BOOL,
        pRealTimeHint: ^win32.BOOL) -> win32.HRESULT,
    RecommendVideoDecoderDownsampleParameters: proc "system" (
        This: ^D3D11_IVideoDevice1,
        pInputDesc: ^d3d11.VIDEO_DECODER_DESC,
        InputColorSpace: dxgi.COLOR_SPACE_TYPE,
        pInputConfig: ^d3d11.VIDEO_DECODER_CONFIG,
        pFrameRate: ^dxgi.RATIONAL,
        pRecommendedOutputDesc: ^D3D11_VIDEO_SAMPLE_DESC) -> win32.HRESULT,
}

D3D11_IVideoProcessorEnumerator1_UUID_STRING :: "465217F2-5568-43CF-B5B9-F61D54531CA1"
IID_IVideoProcessorEnumerator1_UUID :=
    &win32.IID{0x465217F2,0x5568,0x43CF, {0xB5,0xB9,0xF6,0x1D,0x54,0x53,0x1C,0xA1}}
D3D11_IVideoProcessorEnumerator1 :: struct #raw_union {
    #subtype ivideoprocessorenumerator: d3d11.IVideoProcessorEnumerator,
    using ivideoprocessorenumerator1_vtable: ^D3D11_IVideoProcessorEnumerator1_VTable,
}
D3D11_IVideoProcessorEnumerator1_VTable :: struct {
    using ivideoprocessorenumerator_vtable: d3d11.IVideoProcessorEnumerator_VTable,
    CheckVideoProcessorFormatConversion: proc "system" (
        This: ^D3D11_IVideoProcessorEnumerator1,
        InputFormat: dxgi.FORMAT,
        InputColorSpace: dxgi.COLOR_SPACE_TYPE,
        OutputFormat: dxgi.FORMAT,
        OutputColorSpace: dxgi.COLOR_SPACE_TYPE,
        pSupported: ^win32.BOOL) -> win32.HRESULT,
}

D3D11_IDevice1_UUID_STRING :: "a04bfb29-08ef-43d6-a49c-a9bdbdcbe686"
D3D11_IDevice1_UUID :=
    &win32.IID{0xa04bfb29,0x08ef,0x43d6, {0xa4,0x9c,0xa9,0xbd,0xbd,0xcb,0xe6,0x86}}
D3D11_IDevice1 :: struct #raw_union {
    #subtype idevice: d3d11.IDevice,
    using idevice1_vtable: ^D3D11_IDevice1_VTable,
}
D3D11_IDevice1_VTable :: struct {
    using idevice_vtable: d3d11.IDevice_VTable,
    GetImmediateContext1: proc "system" (
        This: ^D3D11_IDevice1,
        ppImmediateContext: ^^D3D11_IDeviceContext1),
    CreateDeferredContext1: proc "system" (
        This: ^D3D11_IDevice1,
        ContextFlags: win32.UINT,
        ppDeferredContext: ^^D3D11_IDeviceContext1) -> win32.HRESULT,
    CreateBlendState1: proc "system" (
        This: ^D3D11_IDevice1,
        pBlendStateDesc: ^D3D11_BLEND_DESC1,
        ppBlendState: ^^D3D11_IBlendState1) -> win32.HRESULT,
    CreateRasterizerState1: proc "system" (
        This: ^D3D11_IDevice1,
        pRasterizerDesc: ^D3D11_RASTERIZER_DESC1,
        ppRasterizerState: ^^D3D11_IRasterizerState1) -> win32.HRESULT,
    CreateDeviceContextState: proc "system" (
        This: ^D3D11_IDevice1,
        Flags: D3D11_1_CREATE_DEVICE_CONTEXT_STATE_FLAGS,
        pFeatureLevels: [^]d3d11.FEATURE_LEVEL,
        FeatureLevels: win32.UINT,
        SDKVersion: win32.UINT,
        EmulatedInterface: win32.REFIID,
        pChosenFeatureLevel: ^d3d11.FEATURE_LEVEL,
        ppContextState: ^^D3D11_ID3DDeviceContextState) -> win32.HRESULT,
    OpenSharedResource1: proc "system" (
        This: ^D3D11_IDevice1,
        hResource: win32.HANDLE,
        returnedInterface: win32.REFIID,
        ppResource: ^rawptr) -> win32.HRESULT,
    OpenSharedResourceByName: proc "system" (
        This: ^D3D11_IDevice1,
        lpName: win32.LPCWSTR,
        dwDesiredAccess: win32.DWORD,
        returnedInterface: win32.REFIID,
        ppResource: ^rawptr) -> win32.HRESULT,
}

D3D11_ID3DUserDefinedAnnotation_UUID_STRING :: "b2daad8b-03d4-4dbf-95eb-32ab4b63d0ab"
D3D11_ID3DUserDefinedAnnotation_UUID :=
    &win32.IID{0xb2daad8b,0x03d4,0x4dbf, {0x95,0xeb,0x32,0xab,0x4b,0x63,0xd0,0xab}}
D3D11_ID3DUserDefinedAnnotation :: struct #raw_union {
    #subtype iunknown: d3d11.IUnknown,
    using id3duserdefinedannotation: ^D3D11_ID3DUserDefinedAnnotation_VTable,
}
D3D11_ID3DUserDefinedAnnotation_VTable :: struct {
    using IUnknown_vtable: d3d11.IUnknown_VTable,
    BeginEvent: proc "system" (
        This: ^D3D11_ID3DUserDefinedAnnotation,
        Name: win32.LPCWSTR) -> win32.INT,
    EndEvent: proc "system" (This: ^D3D11_ID3DUserDefinedAnnotation) -> win32.INT,
    SetMarker: proc "system" (
        This: ^D3D11_ID3DUserDefinedAnnotation,
        Name: win32.LPCWSTR),
    GetStatus: proc "system" (This: ^D3D11_ID3DUserDefinedAnnotation),
}
