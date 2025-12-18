#+build windows
package d3d12ma

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/d3d12"
import "vendor:directx/dxgi"

foreign import d3d12ma "d3d12ma.lib"

Pool                   :: struct {}
VirtualBlock           :: struct {}
Allocator              :: struct {}
Allocation             :: struct {}
DefragmentationContext :: struct {}

AllocHandle :: distinct u64

ALLOCATE_FUNC_PTR :: #type proc(size: uint, alignment: uint, data: rawptr) -> rawptr
FREE_FUNC_PTR :: #type proc(memory: rawptr, data: rawptr) -> rawptr

ALLOCATION_CALLBACKS :: struct {
    Allocate:    ALLOCATE_FUNC_PTR,
    Free:        FREE_FUNC_PTR,
    PrivateData: rawptr,
}

ALLOCATION_FLAGS :: bit_set[ALLOCATION_FLAG; u32]
ALLOCATION_FLAG :: enum u32 {
    COMMITTED           = 0,
    NEVER_ALLOCATE      = 1,
    WITHIN_BUDGET       = 2,
    UPPER_ADDRESS       = 3,
    CAN_ALIAS           = 4,
    STRATEGY_MIN_MEMORY = 16,
    STRATEGY_MIN_TIME   = 17,
    STRATEGY_MIN_OFFSET = 18,
}

ALLOCATION_FLAG_NONE :: ALLOCATION_FLAGS{}
ALLOCATION_FLAG_STRATEGY_BEST_FIT :: ALLOCATION_FLAGS{ .STRATEGY_MIN_MEMORY }
ALLOCATION_FLAG_STRATEGY_FIRST_FIT :: ALLOCATION_FLAGS{ .STRATEGY_MIN_TIME }
ALLOCATION_FLAG_STRATEGY_MASK :: ALLOCATION_FLAGS{
    .STRATEGY_MIN_MEMORY,
    .STRATEGY_MIN_TIME,
    .STRATEGY_MIN_OFFSET,
}

ALLOCATION_DESC :: struct {
    flags:          ALLOCATION_FLAGS,
    HeapType:       d3d12.HEAP_TYPE,
    ExtraHeapFlags: d3d12.HEAP_FLAGS,
    pCustomPool:    ^Pool,
    PrivateData:    rawptr,
}

Statistics :: struct {
    BlockCount:      win32.UINT,
    AllocationCount: win32.UINT,
    BlockBytes:      win32.UINT64,
    AllocationBytes: win32.UINT64,
}

DetailedStatistics :: struct {
    Stats:              Statistics,
    UnusedRangeCount:   win32.UINT,
    AllocationSizeMin:  win32.UINT64,
    AllocationSizeMax:  win32.UINT64,
    UnusedRangeSizeMin: win32.UINT64,
    UnusedRangeSizeMax: win32.UINT64,
}

TotalStatistics :: struct {
    HeapType:           [5]DetailedStatistics,
    MemorySegmentGroup: [2]DetailedStatistics,
    Total:              DetailedStatistics,
}

Budget :: struct  {
    Stats:       Statistics,
    UsageBytes:  win32.UINT64,
    BudgetBytes: win32.UINT64,
}

VirtualAllocation :: struct {
    AllocHandle: AllocHandle,
}

DEFRAGMENTATION_FLAGS :: bit_set[DEFRAGMENTATION_FLAG; u32]
DEFRAGMENTATION_FLAG :: enum u32 {
    ALGORITHM_FAST,
    ALGORITHM_BALANCED,
    ALGORITHM_FULL,
}

DEFRAGMENTATION_FLAG_ALGORITHM_MASK :: DEFRAGMENTATION_FLAGS{
    .ALGORITHM_FAST,
    .ALGORITHM_BALANCED,
    .ALGORITHM_FULL,
}

DEFRAGMENTATION_DESC :: struct {
    Flags:                 DEFRAGMENTATION_FLAGS,
    MaxBytesPerPass:       win32.UINT64,
    MaxAllocationsPerPass: win32.UINT32,
}

DEFRAGMENTATION_MOVE_OPERATION :: enum i32 {
    COPY,
    IGNORE,
    DESTROY,
}

DEFRAGMENTATION_MOVE :: struct {
    Operation:         DEFRAGMENTATION_MOVE_OPERATION,
    pSrcAllocation:    ^Allocation,
    pDstTmpAllocation: ^Allocation,
}

DEFRAGMENTATION_PASS_MOVE_INFO :: struct {
    MoveCount: win32.UINT32,
    pMoves:    ^DEFRAGMENTATION_MOVE,
}

DEFRAGMENTATION_STATS :: struct {
    BytesMoved:       win32.UINT64,
    BytesFreed:       win32.UINT64,
    AllocationsMoved: win32.UINT32,
    HeapsFreed:       win32.UINT32,
}

POOL_FLAGS :: bit_set[POOL_FLAG; u32]
POOL_FLAG :: enum u32 {
    ALGORITHM_LINEAR,
    MSAA_TEXTURES_ALWAYS_COMMITTED,
}

POOL_FLAG_NONE :: POOL_FLAGS{}
POOL_FLAG_ALGORITHM_MASK :: POOL_FLAGS{ .ALGORITHM_LINEAR }

POOL_DESC :: struct {
    Flags:                  POOL_FLAGS,
    HeapProperties:         d3d12.HEAP_PROPERTIES,
    HeapFlags:              d3d12.HEAP_FLAGS,
    BlockSize:              win32.UINT64,
    MinBlockCount:          win32.UINT,
    MaxBlockCount:          win32.UINT,
    MinAllocationAlignment: win32.UINT64,
    pProtectedSession:      ^d3d12.IProtectedResourceSession,
    ResidencyPriority:      d3d12.RESIDENCY_PRIORITY,
}

ALLOCATOR_FLAGS :: bit_set[ALLOCATOR_FLAG; u32]
ALLOCATOR_FLAG :: enum u32 {
    SINGLETHREADED,
    ALWAYS_COMMITTED,
    DEFAULT_POOLS_NOT_ZEROED,
    MSAA_TEXTURES_ALWAYS_COMMITTED,
    DONT_PREFER_SMALL_BUFFERS_COMMITTED,
}

ALLOCATOR_FLAG_NONE :: ALLOCATOR_FLAGS{}

ALLOCATOR_DESC :: struct {
    Flags:                ALLOCATOR_FLAGS,
    pDevice:              ^d3d12.IDevice,
    PreferredBlockSize:   win32.UINT64,
    pAllocationCallbacks: ^ALLOCATION_CALLBACKS,
    pAdapter:             ^dxgi.IAdapter,
}

VIRTUAL_BLOCK_FLAGS :: bit_set[VIRTUAL_BLOCK_FLAG; u32]
VIRTUAL_BLOCK_FLAG :: enum u32 {
    ALGORITHM_LINEAR,
}

VIRTUAL_BLOCK_FLAG_NONE :: VIRTUAL_BLOCK_FLAGS{}
VIRTUAL_BLOCK_FLAG_ALGORITHM_MASK :: VIRTUAL_BLOCK_FLAGS{ .ALGORITHM_LINEAR }

VIRTUAL_BLOCK_DESC :: struct {
    Flags:                VIRTUAL_BLOCK_FLAGS,
    Size:                 win32.UINT64,
    pAllocationCallbacks: ^ALLOCATION_CALLBACKS,
}

VIRTUAL_ALLOCATION_FLAGS :: bit_set[VIRTUAL_ALLOCATION_FLAG; u32]
VIRTUAL_ALLOCATION_FLAG :: enum u32 {
    UPPER_ADDRESS       = 3,
    STRATEGY_MIN_MEMORY = 16,
    STRATEGY_MIN_TIME   = 17,
    STRATEGY_MIN_OFFSET = 18,
}

VIRTUAL_ALLOCATION_FLAG_NONE :: VIRTUAL_ALLOCATION_FLAGS{}
VIRTUAL_ALLOCATION_FLAG_STRATEGY_MASK :: VIRTUAL_ALLOCATION_FLAGS {
    .STRATEGY_MIN_MEMORY,
    .STRATEGY_MIN_TIME,
    .STRATEGY_MIN_OFFSET,
}

VIRTUAL_ALLOCATION_DESC :: struct {
    Flags:       VIRTUAL_ALLOCATION_FLAGS,
    Size:        win32.UINT64,
    Alignment:   win32.UINT64,
    PrivateData: rawptr,
}

VIRTUAL_ALLOCATION_INFO :: struct {
    Offset:      win32.UINT64,
    Size:        win32.UINT64,
    PrivateData: rawptr,
}

BARRIER_LAYOUT :: enum i32 {
    UNDEFINED,
    COMMON,
    PRESENT,
    GENERIC_READ,
    RENDER_TARGET,
    UNORDERED_ACCESS,
    DEPTH_STENCIL_WRITE,
    DEPTH_STENCIL_READ,
    SHADER_RESOURCE,
    COPY_SOURCE,
    COPY_DEST,
    RESOLVE_SOURCE,
    RESOLVE_DEST,
    SHADING_RATE_SOURCE,
    VIDEO_DECODE_READ,
    VIDEO_DECODE_WRITE,
    VIDEO_PROCESS_READ,
    VIDEO_PROCESS_WRITE,
    VIDEO_ENCODE_READ,
    VIDEO_ENCODE_WRITE,
    DIRECT_QUEUE_COMMON,
    DIRECT_QUEUE_GENERIC_READ,
    DIRECT_QUEUE_UNORDERED_ACCESS,
    DIRECT_QUEUE_SHADER_RESOURCE,
    DIRECT_QUEUE_COPY_SOURCE,
    DIRECT_QUEUE_COPY_DEST,
    COMPUTE_QUEUE_COMMON,
    COMPUTE_QUEUE_GENERIC_READ,
    COMPUTE_QUEUE_UNORDERED_ACCESS,
    COMPUTE_QUEUE_SHADER_RESOURCE,
    COMPUTE_QUEUE_COPY_SOURCE,
    COMPUTE_QUEUE_COPY_DEST,
    VIDEO_QUEUE_COMMON,
}

@(default_calling_convention="c", link_prefix="D3D12MA")
foreign d3d12ma {
    Allocation_GetOffset      :: proc(pSelf: ^Allocation) -> win32.UINT64 ---
    Allocation_GetAlignment   :: proc(pSelf: ^Allocation) -> win32.UINT64 ---
    Allocation_GetSize        :: proc(pSelf: ^Allocation) -> win32.UINT64 ---
    Allocation_GetResource    :: proc(pSelf: ^Allocation) -> ^d3d12.IResource ---
    Allocation_SetResource    :: proc(pSelf: ^Allocation, Resource: ^d3d12.IResource) ---
    Allocation_GetHeap        :: proc(pSelf: ^Allocation) -> ^d3d12.IHeap ---
    Allocation_SetPrivateData :: proc(pSelf: ^Allocation, PrivateData: rawptr) ---
    Allocation_GetPrivateData :: proc(pSelf: ^Allocation) -> rawptr ---
    Allocation_SetName        :: proc(pSelf: ^Allocation, Name: win32.LPCWSTR) ---
    Allocation_GetName        :: proc(pSelf: ^Allocation) -> win32.LPCWSTR ---
    ADefragmentationContext_BeginPass :: proc(
        pSelf: ^Allocation,
        pPassInfo: ^DEFRAGMENTATION_PASS_MOVE_INFO) -> win32.HRESULT ---
    ADefragmentationContext_EndPass :: proc(
        pSelf: ^Allocation,
        pPassInfo: ^DEFRAGMENTATION_PASS_MOVE_INFO) -> win32.HRESULT ---
    ADefragmentationContext_GetStats :: proc(
        pSelf: ^Allocation,
        pStats: ^DEFRAGMENTATION_STATS) ---
    Pool_GetDesc :: proc(pSelf: ^Pool) -> POOL_DESC ---
    Pool_GetStatistics :: proc(pSelf: ^Pool, pStats: ^Statistics) ---
    Pool_CalculateStatistics :: proc(pSelf: ^Pool, pStats: ^DetailedStatistics) ---
    Pool_SetName :: proc(pSelf: ^Pool, Name: win32.LPCWSTR) ---
    Pool_GetName :: proc(pSelf: ^Pool) -> win32.LPCWSTR ---
    Pool_BeginDefragmentation :: proc(
        pSelf: ^Pool,
        #by_ptr pDesc: DEFRAGMENTATION_DESC, ppContext: ^^DefragmentationContext,
    ) -> win32.HRESULT ---
    Allocator_GetD3D12Options :: proc(pSelf: ^Allocator) -> ^d3d12.FEATURE_DATA_OPTIONS ---
    Allocator_IsUMA :: proc(pSelf: ^Allocator) -> win32.BOOL ---
    Allocator_IsCacheCoherentUMA :: proc(pSelf: ^Allocator) -> win32.BOOL ---
    Allocator_IsGPUUploadHeapSupported :: proc(pSelf: ^Allocator) -> win32.BOOL ---
    Allocator_GetMemoryCapacity :: proc(
        pSelf: ^Allocator,
        MemorySegmentGroup: win32.UINT,
    ) -> win32.UINT64 ---
    Allocator_CreateResource :: proc(
        pSelf: ^Allocator,
        #by_ptr pAllocDesc: ALLOCATION_DESC,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC,
        InitialResourceState: d3d12.RESOURCE_STATES,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        ppAllocation: ^^Allocation,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_CreateResource2 :: proc(
        pSelf: ^Allocator,
        #by_ptr pAllocDesc: ALLOCATION_DESC,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC1,
        InitialResourceState: d3d12.RESOURCE_STATES,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        ppAllocation: ^^Allocation,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_CreateResource3 :: proc(
        pSelf: ^Allocator,
        #by_ptr pAllocDesc: ALLOCATION_DESC,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC1,
        InitialLayout: BARRIER_LAYOUT,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        NumCastableFormats: win32.UINT32,
        pCastableFormats: dxgi.FORMAT,
        ppAllocation: ^^Allocation,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_AllocateMemory :: proc(
        pSelf: ^Allocator,
        #by_ptr pAllocDesc: ALLOCATION_DESC,
        #by_ptr pAllocInfo: d3d12.RESOURCE_ALLOCATION_INFO,
        ppAllocation: ^^Allocation,
    ) -> win32.HRESULT ---
    Allocator_CreateAliasingResource :: proc(
        pSelf: ^Allocator,
        pAllocation: ^Allocation,
        AllocationLocalOffset: win32.UINT64,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC,
        InitialResourceState: d3d12.RESOURCE_STATES,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_CreateAliasingResource1 :: proc(
        pSelf: ^Allocator,
        pAllocation: ^Allocation,
        AllocationLocalOffset: win32.UINT64,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC1,
        InitialResourceState: d3d12.RESOURCE_STATES,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_CreateAliasingResource2 :: proc(
        pSelf: ^Allocator,
        pAllocation: ^Allocation,
        AllocationLocalOffset: win32.UINT64,
        #by_ptr pResourceDesc: d3d12.RESOURCE_DESC1,
        InitialLayout: BARRIER_LAYOUT,
        #by_ptr pOptimizedClearValue: d3d12.CLEAR_VALUE,
        NumCastableFormats: win32.UINT32,
        pCastableFormats: ^dxgi.FORMAT,
        riidResource: win32.REFIID,
        ppvResource: ^rawptr,
    ) -> win32.HRESULT ---
    Allocator_CreatePool :: proc(
        pSelf: ^Allocator,
        #by_ptr pPoolDesc: POOL_DESC,
        ppPool: ^^Pool,
    ) -> win32.HRESULT ---
    Allocator_SetCurrentFrameIndex :: proc(pSelf: ^Allocator, FrameIndex: win32.UINT) ---
    Allocator_GetBudget :: proc(
        pSelf: ^Allocator,
        pLocalBudget: ^Budget,
        pNonLocalBudget: ^Budget,
    ) ---
    Allocator_CalculateStatistics :: proc(pSelf: ^Allocator, pStats: ^TotalStatistics) ---
    Allocator_BuildStatsString :: proc(
        pSelf: ^Allocator,
        ppStatsString: ^^win32.WCHAR,
        DetailedMap: win32.BOOL,
    ) ---
    Allocator_FreeStatsString :: proc(pSelf: ^Allocator, pStatsString: ^win32.WCHAR) ---
    Allocator_BeginDefragmentation :: proc(
        pSelf: ^Allocator,
        #by_ptr pDesc: DEFRAGMENTATION_DESC,
        ppContext: ^^DefragmentationContext,
    ) ---
    VirtualBlock_IsEmpty :: proc(self: ^VirtualBlock) -> win32.BOOL ---
    VirtualBlock_GetAllocationInfo :: proc(
        self: ^VirtualBlock,
        Allocation: VirtualAllocation,
        pInfo: ^VIRTUAL_ALLOCATION_INFO,
    ) ---
    VirtualBlock_Allocate :: proc(
        self: ^VirtualBlock,
        #by_ptr pDesc: VIRTUAL_ALLOCATION_DESC,
        pAllocation: ^VirtualAllocation,
        pOffset: ^win32.UINT64,
    ) -> win32.HRESULT ---
    VirtualBlock_FreeAllocation :: proc(self: ^VirtualBlock, Allocation: VirtualAllocation) ---
    VirtualBlock_Clear :: proc(self: ^VirtualBlock) ---
    VirtualBlock_SetAllocationPrivateData :: proc(
        self: ^VirtualBlock,
        Allocation: VirtualAllocation,
        pPrivateData: rawptr,
    ) ---
    VirtualBlock_GetStatistics :: proc(self: ^VirtualBlock, pStats: ^Statistics) ---
    VirtualBlock_CalculateStatistics :: proc(self: ^VirtualBlock, pStats: ^DetailedStatistics) ---
    VirtualBlock_BuildStatsString :: proc(self: ^VirtualBlock, ppStatsString: ^^win32.WCHAR) ---
    VirtualBlock_FreeStatsString :: proc(self: ^VirtualBlock, pStatsString: ^win32.WCHAR) ---
    CreateAllocator :: proc(
        #by_ptr pDesc: ALLOCATOR_DESC,
        ppAllocator: ^^Allocator,
    ) -> win32.HRESULT ---
    CreateVirtualBlock :: proc(
        #by_ptr pDesc: VIRTUAL_BLOCK_DESC,
        ppVirtualBlock: ^^VirtualBlock,
    ) -> win32.HRESULT ---

    Pool_Release :: proc(pSelf: ^Allocator) ---
    VirtualBlock_Release :: proc(pSelf: ^VirtualBlock) ---
    Allocator_Release :: proc(pSelf: ^Allocator) ---
    Allocation_Release :: proc(pSelf: ^Allocation) ---
    DefragmentationContext_Release :: proc(pSelf: ^DefragmentationContext) ---
}
