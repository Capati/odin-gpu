#+build windows
#+private
package gpu

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/dxgi"
import "vendor:directx/d3d11"

D3D11_TILED_RESOURCE_COORDINATE :: struct {
    X:           win32.UINT,
    Y:           win32.UINT,
    Z:           win32.UINT,
    Subresource: win32.UINT,
}

D3D11_TILE_REGION_SIZE :: struct {
    NumTiles: win32.UINT,
    bUseBox:  win32.BOOL,
    Width:    win32.UINT,
    Height:   win32.UINT16,
    Depth:    win32.UINT16,
}

D3D11_TILE_MAPPING_FLAGS :: distinct bit_set[D3D11_TILE_MAPPING_FLAG; u32]
D3D11_TILE_MAPPING_FLAG :: enum i32 {
    NO_OVERWRITE = 0,
}

D3D11_TILE_RANGE_FLAGS :: distinct bit_set[D3D11_TILE_RANGE_FLAG; u32]
D3D11_TILE_RANGE_FLAG :: enum i32 {
    NULL              = 0,
    SKIP              = 1,
    REUSE_SINGLE_TILE = 2,
}

D3D11_SUBRESOURCE_TILING :: struct {
    WidthInTiles:                    win32.UINT,
    HeightInTiles:                   win32.UINT16,
    DepthInTiles:                    win32.UINT16,
    StartTileIndexInOverallResource: win32.UINT,
}

D3D11_PACKED_TILE :: 0xffffffff

D3D11_TILE_SHAPE :: struct {
    WidthInTexels:  win32.UINT,
    HeightInTexels: win32.UINT,
    DepthInTexels:  win32.UINT,
}

D3D11_PACKED_MIP_DESC :: struct {
    NumStandardMips:                 win32.UINT8,
    NumPackedMips:                   win32.UINT8,
    NumTilesForPackedMips:           win32.UINT,
    StartTileIndexInOverallResource: win32.UINT,
}

D3D11_CHECK_MULTISAMPLE_QUALITY_LEVELS_FLAGS ::
    distinct bit_set[D3D11_CHECK_MULTISAMPLE_QUALITY_LEVELS_FLAG; u32]
D3D11_CHECK_MULTISAMPLE_QUALITY_LEVELS_FLAG :: enum i32 {
    TILED_RESOURCE = 0,
}

D3D11_TILE_COPY_FLAGS :: distinct bit_set[D3D11_TILE_COPY_FLAG; u32]
D3D11_TILE_COPY_FLAG :: enum i32 {
    NO_OVERWRITE                             = 0,
    LINEAR_BUFFER_TO_SWIZZLED_TILED_RESOURCE = 1,
    SWIZZLED_TILED_RESOURCE_TO_LINEAR_BUFFER = 2,
}

D3D11_IDeviceContext2_UUID_STRING :: "420d5b32-b90c-4da4-bef0-359f6a24a83a"
D3D11_IDeviceContext2_UUID :=
    &win32.IID{0x420d5b32,0xb90c,0x4da4,{0xbe,0xf0,0x35,0x9f,0x6a,0x24,0xa8,0x3a}}
D3D11_IDeviceContext2 :: struct #raw_union {
    #subtype idevicecontext1: D3D11_IDeviceContext1,
    using idevicecontext2_vtable: ^D3D11_IDeviceContext2_VTable,
}
D3D11_IDeviceContext2_VTable :: struct {
    using idevicecontext1_vtable: D3D11_IDeviceContext1_VTable,
    UpdateTileMappings: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pTiledResource: ^d3d11.IResource,
        NumTiledResourceRegions: win32.UINT,
        pTiledResourceRegionStartCoordinates: [^]D3D11_TILED_RESOURCE_COORDINATE,
        pTiledResourceRegionSizes: [^]D3D11_TILE_REGION_SIZE,
        pTilePool: ^d3d11.IBuffer,
        NumRanges: win32.UINT,
        pRangeFlags: [^]D3D11_TILE_RANGE_FLAGS,
        pTilePoolStartOffsets: [^]win32.UINT,
        pRangeTileCounts: [^]win32.UINT,
        Flags: D3D11_TILE_MAPPING_FLAGS) -> win32.HRESULT,
    CopyTileMappings: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pDestTiledResource: ^d3d11.IResource,
        pDestRegionStartCoordinate: ^D3D11_TILED_RESOURCE_COORDINATE,
        pSourceTiledResource: ^d3d11.IResource,
        pSourceRegionStartCoordinate: ^D3D11_TILED_RESOURCE_COORDINATE,
        pTileRegionSize: ^D3D11_TILE_REGION_SIZE,
        Flags: win32.UINT) -> win32.HRESULT,
    CopyTiles: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pTiledResource: ^d3d11.IResource,
        pTileRegionStartCoordinate: ^D3D11_TILED_RESOURCE_COORDINATE,
        pTileRegionSize: ^D3D11_TILE_REGION_SIZE,
        pBuffer: ^d3d11.IBuffer,
        BufferStartOffsetInBytes: win32.UINT64,
        Flags: D3D11_TILE_MAPPING_FLAGS),
    UpdateTiles: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pDestTiledResource: ^d3d11.IResource,
        pDestTileRegionStartCoordinate: ^D3D11_TILED_RESOURCE_COORDINATE,
        pDestTileRegionSize: ^D3D11_TILE_REGION_SIZE,
        pSourceTileData: rawptr,
        Flags: D3D11_TILE_COPY_FLAGS),
    ResizeTilePool: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pTilePool: ^d3d11.IBuffer,
        NewSizeInBytes: win32.UINT64) -> win32.HRESULT,
    TiledResourceBarrier: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pTiledResourceOrViewAccessBeforeBarrier: ^d3d11.IDeviceChild,
        pTiledResourceOrViewAccessAfterBarrier: ^d3d11.IDeviceChild),
    IsAnnotationEnabled: proc "system" (
        This: ^D3D11_IDeviceContext2) -> win32.BOOL,
    SetMarkerInt: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pLabel: win32.LPCWSTR,
        Data: win32.INT),
    BeginEventInt: proc "system" (
        This: ^D3D11_IDeviceContext2,
        pLabel: win32.LPCWSTR,
        Data: win32.INT),
    EndEvent: proc "system" (This: ^D3D11_IDeviceContext2),
}

D3D11_IDevice2_UUID_STRING :: "9d06dffa-d1e5-4d07-83a8-1bb123f2f841"
D3D11_IDevice2_UUID :=
    &win32.IID{0x9d06dffa,0xd1e5,0x4d07,{0x83,0xa8,0x1b,0xb1,0x23,0xf2,0xf8,0x41}}
D3D11_IDevice2 :: struct #raw_union {
    #subtype idevice1: D3D11_IDevice1,
    using idevice2_vtable: ^D3D11_IDevice2_VTable,
}
D3D11_IDevice2_VTable :: struct {
    using idevice1_vtable: D3D11_IDevice1_VTable,
    GetImmediateContext2: proc "system" (
        ppImmediateContext: ^^D3D11_IDeviceContext2),
    CreateDeferredContext2: proc "system" (
        ContextFlags: win32.UINT,
        ppDeferredContext: ^^D3D11_IDeviceContext2) -> win32.HRESULT,
    GetResourceTiling: proc "system" (
        pTiledResource: ^d3d11.IResource,
        pNumTilesForEntireResource: ^win32.UINT,
        pPackedMipDesc: ^D3D11_PACKED_MIP_DESC,
        pStandardTileShapeForNonPackedMips: ^D3D11_TILE_SHAPE,
        pNumSubresourceTilings: ^win32.UINT,
        FirstSubresourceTilingToGet: win32.UINT,
        pSubresourceTilingsForNonPackedMips: ^D3D11_SUBRESOURCE_TILING),
    CheckMultisampleQualityLevels1: proc "system" (
        Format: dxgi.FORMAT,
        SampleCount: win32.UINT,
        Flags: D3D11_CHECK_MULTISAMPLE_QUALITY_LEVELS_FLAGS,
        pNumQualityLevels: ^win32.UINT) -> win32.HRESULT,
}
