package gpu

// Indicates no copy stride is specified.
ARRAY_LAYER_COUNT_UNDEFINED :: max(u32)
// Indicates no depth clear value is specified.
COPY_STRIDE_UNDEFINED       :: max(u32)
// Indicates no depth slice is specified.
DEPTH_SLICE_UNDEFINED       :: max(u32)
// For `u32` limits, indicates no limit value is specified.
LIMIT_U32_UNDEFINED         :: max(u32)
// For `u64` limits, indicates no limit value is specified.
LIMIT_U64_UNDEFINED         :: max(u64)
// Indicates no mip level count is specified.
MIP_LEVEL_COUNT_UNDEFINED   :: max(u32)
// Indicates no query set index is specified.
QUERY_SET_INDEX_UNDEFINED   :: max(u32)
// Indicates a size extending to the end of the buffer.
WHOLE_MAP_SIZE              :: max(uint)
// Indicates a size extending to the end of the buffer.
WHOLE_SIZE                  :: max(u64)

// Buffer-texture copies must have `bytes_per_row` aligned to this number.
//
// This doesn't apply to `queue_write_texture`, only to
// `queue_copy_buffer_to_texture` and `queue_copy_texture_to_buffer`.
COPY_BYTES_PER_ROW_ALIGNMENT   :: 256

// An offset into the query resolve buffer has to be aligned to this.
QUERY_RESOLVE_BUFFER_ALIGNMENT :: 256

// Buffer to buffer copy as well as buffer clear offsets and sizes must be
// aligned to this number.
COPY_BUFFER_ALIGNMENT          :: 4

// Buffer alignment mask to calculate proper size.
COPY_BUFFER_ALIGNMENT_MASK     :: COPY_BUFFER_ALIGNMENT - 1

// Minimum alignment of buffer mappings.
//
// The range passed to `buffer_map_async` or `buffer_get_mapped_range` must be
// at least this aligned.
MAP_ALIGNMENT                  :: 8

// Vertex buffer offsets and strides have to be a multiple of this number.
VERTEX_ALIGNMENT               :: 4

// Vertex buffer strides have to be a multiple of this number.
VERTEX_STRIDE_ALIGNMENT        :: 4

// Ranges of writes to immediate data must be at least this aligned.
IMMEDIATE_DATA_ALIGNMENT       :: 4

// Storage buffer binding sizes must be multiples of this value.
STORAGE_BINDING_SIZE_ALIGNMENT :: 4

Flags :: u64

MAX_BIND_GROUPS                     :: 4
MAX_BINDINGS_PER_BIND_GROUP         :: 1000
MAX_VERTEX_ATTRIBUTES               :: 30
MAX_VERTEX_BUFFERS                  :: 8
MAX_VERTEX_BUFFER_ARRAY_STRIDE      :: 2048
MAX_BIND_GROUPS_PLUS_VERTEX_BUFFERS :: 24
NUM_STAGES                          :: 3
TEXTURE_BYTES_PER_ROW_ALIGNMENT     :: 256
QUERY_RESOLVE_ALIGNMENT             :: 256
MAX_INTER_STAGE_SHADER_VARIABLES    :: 16
ASSUMED_MAX_BUFFER_SIZE             :: 0x80000000 // 2 GB, used when the real limit is unavailable

// All immediates are 32-bit.
IMMEDIATE_ELEMENT_BYTE_SIZE :: size_of(u32)

// Cap the maximum number of immediates (internal + external) to 64 for fast
// bit algorithms on the immediates mask.
MAX_IMMEDIATE_MASK_BITS :: 64

// Adapter max limitation for user immediates is 64 bytes.
MAX_IMMEDIATE_DATA_BYTES :: 64

// Known as "Immediate Data" that users can update via the API.
MAX_EXTERNAL_IMMEDIATES_PER_PIPELINE :: MAX_IMMEDIATE_DATA_BYTES / IMMEDIATE_ELEMENT_BYTE_SIZE

// Default subgroup sizes.
DEFAULT_SUBGROUP_MIN_SIZE :: 4
DEFAULT_SUBGROUP_MAX_SIZE :: 128

// Per-stage maximum limits used to optimize internals.
MAX_SAMPLED_TEXTURES_PER_SHADER_STAGE :: 48
MAX_SAMPLERS_PER_SHADER_STAGE         :: 16
MAX_STORAGE_BUFFERS_PER_SHADER_STAGE  :: 16
MAX_STORAGE_TEXTURES_PER_SHADER_STAGE :: 8
MAX_UNIFORM_BUFFERS_PER_SHADER_STAGE  :: 12

// Indirect command sizes.
DISPATCH_INDIRECT_SIZE     : u64 : 3 * size_of(u32)
DRAW_INDIRECT_SIZE         : u64 : 4 * size_of(u32)
DRAW_INDEXED_INDIRECT_SIZE : u64 : 5 * size_of(u32)

// Non-spec-defined constants.
LOD_MIN :: f32(0.0)
LOD_MAX :: f32(1000.0)

// Offset alignment for buffer-to-buffer copies. Strictly required only on
// macOS, but applied on all platforms for consistency.
COPY_BUFFER_TO_BUFFER_OFFSET_ALIGNMENT : u64 : 4

// Required offset alignment for texel buffer view offsets, per the WebGPU
// texel-buffers proposal.
TEXEL_BUFFER_OFFSET_ALIGNMENT : u64 : 256

// Metal has a 32KB maximum size for a counter set buffer, 8 bytes per query.
MAX_QUERY_COUNT :: 4096

// An external texture occupies multiple binding slots; these are the
// per-external-texture binding counts needed.
SAMPLED_TEXTURES_PER_EXTERNAL_TEXTURE :: 4
SAMPLERS_PER_EXTERNAL_TEXTURE         :: 1
UNIFORMS_PER_EXTERNAL_TEXTURE         :: 1

MAX_PLS_SLOTS       :: 4
PLS_SLOT_BYTE_SIZE  :: 4
MAX_PLS_SIZE        :: MAX_PLS_SLOTS * PLS_SLOT_BYTE_SIZE

// Wire buffer alignment.
WIRE_BUFFER_ALIGNMENT :: 8

// Timestamp query quantization mask, ~0.1ms granularity.
TIMESTAMP_QUANTIZATION_MASK : u32 : 0xFFFF0000

// Max dynamic offset counts used to optimize internals.
MAX_DYNAMIC_UNIFORM_BUFFERS_PER_PIPELINE_LAYOUT :: 16
MAX_DYNAMIC_STORAGE_BUFFERS_PER_PIPELINE_LAYOUT :: 16

// Maximum resource table size.
MAX_RESOURCE_TABLE_SIZE :: 64 * 1024
// TODO: find if this is a reasonable amount to reserve for placeholders.
RESERVED_RESOURCE_TABLE_SLOTS :: 1000

// Required D3D12 shared buffer memory file mapping handle size alignment.
// Must be a multiple of D3D12_DEFAULT_RESOURCE_PLACEMENT_ALIGNMENT (65536)
// to hold a D3D12 buffer resource.
D3D12_SHARED_BUFFER_MEMORY_FILE_MAPPING_HANDLE_SIZE_ALIGNMENT :: 65536

VENDOR_AMD                  :: 0x1002
VENDOR_APPLE                :: 0x106B
VENDOR_ARM                  :: 0x13B5
VENDOR_BROADCOM             :: 0x14E4
VENDOR_IMGTEC               :: 0x1010
VENDOR_INTEL                :: 0x8086
VENDOR_MESA                 :: 0x10005
VENDOR_NVIDIA               :: 0x10DE
VENDOR_QUALCOMM             :: 0x5143
INTEL_DEVICE_KABY_LAKE_MASK :: 0x5900
INTEL_DEVICE_SKY_LAKE_MASK  :: 0x1900

vendor_name :: proc "contextless" (vendor_id: u32) -> string {
    switch vendor_id {
    case VENDOR_AMD:      return "AMD"
    case VENDOR_APPLE:    return "Apple"
    case VENDOR_ARM:      return "ARM"
    case VENDOR_BROADCOM: return "Broadcom"
    case VENDOR_IMGTEC:   return "ImgTec"
    case VENDOR_INTEL:    return "Intel"
    case VENDOR_MESA:     return "Mesa"
    case VENDOR_NVIDIA:   return "NVIDIA"
    case VENDOR_QUALCOMM: return "Qualcomm"
    case:
        return "Unknown"
    }
}

// Frame buffering
MAX_FRAMES_IN_FLIGHT :: 3

// Maximum binding size for the shaders that only support `i32` indexing.
// Interestingly, the index itself can't reach that high, because the minimum
// element size is 4 bytes, but the compiler toolchain still computes the
// offset at some intermediate point, internally, as i32.
MAX_I32_BINDING_SIZE :: (1 << 31) - 1

// - Vertex + Fragment
// - Compute
// Task + Mesh + Fragment
MAX_CONCURRENT_SHADER_STAGES :: 3

MAX_LABEL_LENGTH :: 256
