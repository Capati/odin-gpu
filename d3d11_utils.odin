#+build windows
package gpu

// Vendor
import "vendor:directx/d3d11"

d3d11_encode_basic_filter :: #force_inline proc(
    min, mag, mip: d3d11.FILTER_TYPE,
    reduction: d3d11.FILTER_REDUCTION_TYPE,
) -> d3d11.FILTER {
    return d3d11.FILTER(
        ((u32(min) & d3d11.FILTER_TYPE_MASK) << d3d11.MIN_FILTER_SHIFT) |
        ((u32(mag) & d3d11.FILTER_TYPE_MASK) << d3d11.MAG_FILTER_SHIFT) |
        ((u32(mip) & d3d11.FILTER_TYPE_MASK) << d3d11.MIP_FILTER_SHIFT) |
        ((u32(reduction) & d3d11.FILTER_REDUCTION_TYPE_MASK) << d3d11.FILTER_REDUCTION_TYPE_SHIFT))
}

d3d11_encode_anisotropic_filter :: #force_inline proc(
    reduction: d3d11.FILTER_REDUCTION_TYPE = .STANDARD,
) -> d3d11.FILTER {
    return d3d11.FILTER(
        u32(d3d11.ANISOTROPIC_FILTERING_BIT) |
        u32(d3d11_encode_basic_filter(
            .LINEAR,
            .LINEAR,
            .LINEAR,
            reduction)))
}

d3d11_buffer_size_alignment :: proc(usage: Buffer_Usages) -> u32 {
    if .Uniform in usage {
        // Each number of constants must be a multiple of 16 shader constants
        return size_of(f32) * 4 * 16 // 256 bytes
    }

    if .Storage in usage || .Copy_Src in usage || .Copy_Dst in usage {
        // Unordered access buffers must be 4-byte aligned
        // Also for Copy_Dst/Copy_Src buffers used in compute shaders
        return size_of(u32)
    }

    return 1
}
