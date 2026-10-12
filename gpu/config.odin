package gpu

// Limits the total number of command buffers that can be active concurrently.
//
// If all buffers are in use, the system will wait until one is freed.
MAX_COMMAND_BUFFERS :: #config(GPU_MAX_COMMAND_BUFFERS, 64)

// The maximum allowed number of color attachments.
MAX_COLOR_ATTACHMENTS :: #config(GPU_MAX_COLOR_ATTACHMENTS, 8)

// 8 color + 8 resolve + 1 depth   = 17
MAX_ATTACHMENT_COUNT :: MAX_COLOR_ATTACHMENTS * 2 + 1

// Allow to use the Vulkan Memory Allocator library for the Vulkan backend.
//
// Default is `false`.
when ODIN_OS != .JS {
    USE_VMA :: #config(GPU_USE_VMA, false)
} else {
    USE_VMA :: false
}

// Allow to use the D3D12 Memory Allocator library for the D3D12 backend.
//
// Default is `false`.
when ODIN_OS != .JS {
    USE_D3D12MA :: #config(GPU_USE_D3D12MA, false)
} else {
    USE_D3D12MA :: false
}

// Allow to create shader module from Slang source.
//
// Default is `false`.
when ODIN_OS != .JS {
    USE_SLANG :: #config(GPU_USE_SLANG, false)
} else {
    USE_SLANG :: false
}

DEBUG :: ODIN_DEBUG || #config(GPU_DEBUG, false)
VALIDATION :: #config(GPU_VALIDATION, false)
ALLOW_UNDERLYING_NONCOMPLIANT_ADAPTER :: #config(GPU_ALLOW_UNDERLYING_NONCOMPLIANT_ADAPTER, false)
BASED_VALIDATION :: #config(GPU_BASED_VALIDATION, false)
VALIDATION_INDIRECT_CALL :: #config(GPU_VALIDATION_INDIRECT_CALL, false)
STRICT_WEBGPU_COMPLIANCE :: #config(GPU_STRICT_WEBGPU_COMPLIANCE, false)
