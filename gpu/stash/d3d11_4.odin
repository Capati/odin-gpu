#+build windows
#+private
package gpu

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/dxgi"
import "vendor:directx/d3d11"

D3D11_IDevice4_UUID_STRING :: "8992ab71-02e6-4b8d-ba48-b056dcda42c4"
D3D11_IDevice4_UUID :=
    &win32.IID{0x8992ab71,0x02e6,0x4b8d,{0xba,0x48,0xb0,0x56,0xdc,0xda,0x42,0xc4}}
D3D11_IDevice4 :: struct #raw_union {
    #subtype idevice3: D3D11_IDevice3,
    using idevice4_vtable: ^D3D11_IDevice4_VTable,
}
D3D11_IDevice4_VTable :: struct {
    using idevice3_vtable: D3D11_IDevice3_VTable,
    RegisterDeviceRemovedEvent: proc "system" (
        This: ^D3D11_IDevice4,
        hEvent: win32.HANDLE,
        pdwCookie: ^win32.DWORD) -> win32.HRESULT,
    UnregisterDeviceRemoved: proc "system" (
        This: ^D3D11_IDevice4,
        dwCookie: win32.DWORD),
}

D3D11_IDevice5_UUID_STRING :: "8ffde202-a0e7-45df-9e01-e837801b5ea0"
D3D11_IDevice5_UUID :=
    &win32.IID{0x8ffde202,0xa0e7,0x45df,{0x9e,0x01,0xe8,0x37,0x80,0x1b,0x5e,0xa0}}
D3D11_IDevice5 :: struct #raw_union {
    #subtype idevice4: D3D11_IDevice4,
    using idevice5_vtable: ^D3D11_IDevice5_VTable,
}
D3D11_IDevice5_VTable :: struct {
    using idevice4_vtable: D3D11_IDevice4_VTable,
    OpenSharedFence: proc "system" (
        This: ^D3D11_IDevice5,
        hFence: win32.HANDLE,
        ReturnedInterface: win32.REFIID,
        ppFence: ^rawptr) -> win32.HRESULT,
    CreateFence: proc "system" (
        This: ^D3D11_IDevice5,
        InitialValue: win32.UINT64,
        Flags: D3D11_FENCE_FLAGS,
        ReturnedInterface: win32.REFIID,
        ppFence: ^rawptr) -> win32.HRESULT,
}

D3D11_IMultithread_UUID_STRING :: "9B7E4E00-342C-4106-A19F-4F2704F689F0"
D3D11_IMultithread_UUID :=
    &win32.IID{0x9B7E4E00,0x342C,0x4106,{0xA1,0x9F,0x4F,0x27,0x04,0xF6,0x89,0xF0}}
D3D11_IMultithread :: struct #raw_union {
    #subtype iunknown: d3d11.IUnknown,
}
D3D11_IMultithread_VTable :: struct {
    using iunknown_vtable: d3d11.IUnknown_VTable,
    Enter: proc "system" (This: ^D3D11_IMultithread),
    Leave: proc "system" (This: ^D3D11_IMultithread),
    SetMultithreadProtected: proc "system" (
        This: ^D3D11_IMultithread,
        bMTProtect: win32.BOOL) -> win32.BOOL,
    GetMultithreadProtected: proc "system" (This: ^D3D11_IMultithread) -> win32.BOOL,
}

D3D11_IVideoContext2_UUID_STRING :: "C4E7374C-6243-4D1B-AE87-52B4F740E261"
D3D11_IVideoContext2_UUID :=
    &win32.IID{0xC4E7374C,0x6243,0x4D1B,{0xAE,0x87,0x52,0xB4,0xF7,0x40,0xE2,0x61}}
D3D11_IVideoContext2 :: struct #raw_union {
    #subtype ivideocontext1: D3D11_IVideoContext1,
    using ivideocontext2_vtable: ^D3D11_IVideoContext2_VTable,
}
D3D11_IVideoContext2_VTable :: struct {
    using ivideocontext1_vtable: D3D11_IVideoContext1_VTable,
    VideoProcessorSetOutputHDRMetaData: proc "system" (
        This: ^D3D11_IVideoContext2,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        Type: dxgi.HDR_METADATA_TYPE,
        Size: win32.UINT,
        pHDRMetaData: rawptr),
    VideoProcessorGetOutputHDRMetaData: proc "system" (
        This: ^D3D11_IVideoContext2,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        pType: ^dxgi.HDR_METADATA_TYPE,
        Size: win32.UINT,
        pMetaData: rawptr),
    VideoProcessorSetStreamHDRMetaData: proc "system" (
        This: ^D3D11_IVideoContext2,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        Type: dxgi.HDR_METADATA_TYPE,
        Size: win32.UINT,
        pHDRMetaData: rawptr),
    VideoProcessorGetStreamHDRMetaData: proc "system" (
        This: ^D3D11_IVideoContext2,
        pVideoProcessor: ^d3d11.IVideoProcessor,
        StreamIndex: win32.UINT,
        pType: ^dxgi.HDR_METADATA_TYPE,
        Size: win32.UINT,
        pMetaData: rawptr),
}

D3D11_FEATURE_VIDEO :: enum i32 {
    DECODER_HISTOGRAM = 0,
}

D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT :: enum i32 {
    Y = 0,
    U = 1,
    V = 2,
    R = 0,
    G = 1,
    B = 2,
    A = 3,
}

D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT_FLAGS ::
    distinct bit_set[D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT; u32]

D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT_FLAGS_NONE ::
    D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT_FLAGS{}

D3D11_FEATURE_DATA_VIDEO_DECODER_HISTOGRAM :: struct {
    DecoderDesc:     d3d11.VIDEO_DECODER_DESC,
    Components:      D3D11_VIDEO_DECODER_HISTOGRAM_COMPONENT_FLAGS,
    BinCount:        win32.UINT,
    CounterBitDepth: win32.UINT,
}

D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAGS ::
    distinct bit_set[D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAG; u32]
D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAG :: enum i32 {}

D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAGS_NONE :: D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAGS{}

D3D11_IVideoDevice2_UUID_STRING :: "59C0CB01-35F0-4A70-8F67-87905C906A53"
D3D11_IVideoDevice2_UUID :=
    &win32.IID{0x59C0CB01,0x35F0,0x4A70,{0x8F,0x67,0x87,0x90,0x5C,0x90,0x6A,0x53}}
D3D11_IVideoDevice2 :: struct #raw_union {
    #subtype ivideodevice1: D3D11_IVideoDevice1,
    using IVideoDevice2_VTable: ^D3D11_IVideoDevice2_VTable,
}
D3D11_IVideoDevice2_VTable :: struct {
    using ivideodevice1_vtable: D3D11_IVideoDevice1_VTable,
    CheckFeatureSupport: proc "system" (
        This: ^D3D11_IVideoDevice2,
        Feature: D3D11_FEATURE_VIDEO,
        pFeatureSupportData: rawptr,
        FeatureSupportDataSize: win32.UINT) -> win32.HRESULT,
    NegotiateCryptoSessionKeyExchangeMT: proc "system" (
        This: ^D3D11_IVideoDevice2,
        pCryptoSession: ^d3d11.ICryptoSession,
        flags: D3D11_CRYPTO_SESSION_KEY_EXCHANGE_FLAGS,
        DataSize: win32.UINT,
        pData: rawptr) -> win32.HRESULT,
}

D3D11_VIDEO_DECODER_BUFFER_DESC2 :: struct {
    BufferType:             d3d11.VIDEO_DECODER_BUFFER_TYPE,
    DataOffset:             win32.UINT,
    DataSize:               win32.UINT,
    pIV:                    rawptr,
    IVSize:                 win32.UINT,
    pSubSampleMappingBlock: ^D3D11_VIDEO_DECODER_SUB_SAMPLE_MAPPING_BLOCK,
    SubSampleMappingCount:  win32.UINT,
    cBlocksStripeEncrypted: win32.UINT,
    cBlocksStripeClear:     win32.UINT,
}

D3D11_IVideoContext3_UUID_STRING :: "A9E2FAA0-CB39-418F-A0B7-D8AAD4DE672E"
D3D11_IVideoContext3_UUID :=
    &win32.IID{0xA9E2FAA0,0xCB39,0x418F,{0xA0,0xB7,0xD8,0xAA,0xD4,0xDE,0x67,0x2E}}
D3D11_IVideoContext3 :: struct #raw_union {
    #subtype ivideocontext2: D3D11_IVideoContext2,
    using ivideocontext3_vtable: ^D3D11_IVideoContext3_VTable,
}
D3D11_IVideoContext3_VTable :: struct {
    using ivideocontext2_vtable: D3D11_IVideoContext2_VTable,
    DecoderBeginFrame1: proc "system" (
        This: ^D3D11_IVideoContext3,
        pDecoder: ^d3d11.IVideoDecoder,
        pView: ^d3d11.IVideoDecoderOutputView,
        ContentKeySize: win32.UINT,
        pContentKey: rawptr,
        NumComponentHistograms: win32.UINT,
        pHistogramOffsets: [^]win32.UINT,
        ppHistogramBuffers: [^]^d3d11.IBuffer) -> win32.HRESULT,
    SubmitDecoderBuffers2: proc "system" (
        This: ^D3D11_IVideoContext3,
        pDecoder: ^d3d11.IVideoDecoder,
        NumBuffers: win32.UINT,
        pBufferDesc: [^]D3D11_VIDEO_DECODER_BUFFER_DESC2) -> win32.HRESULT,
}

D3D11_FEATURE_DATA_D3D11_OPTIONS4 :: struct {
    ExtendedNV12SharedTextureSupported: win32.BOOL,
}
