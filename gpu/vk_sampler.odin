#+build !js
package gpu

// Core
import "base:runtime"
import hm "core:container/handle_map"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

VK_Sampler_Handle :: distinct hm.Handle64

VK_Sampler_Impl :: struct {
    // Base
    using base: _Sampler_Impl,

    // Backend
    device:      Device,
    vk_sampler:  vk.Sampler,
    create_info: vk.SamplerCreateInfo,
    handle:      VK_Sampler_Handle,
}

@(require_results)
vk_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    impl := vk_device_get_impl(device, loc)

    resolved, ok := _resolve_sampler_descriptor(device, descriptor, loc)
    if !ok {
        return {}
    }

    create_info := vk.SamplerCreateInfo {
        sType                   = .SAMPLER_CREATE_INFO,
        magFilter               = vk_conv_to_filter(descriptor.mag_filter),
        minFilter               = vk_conv_to_filter(descriptor.min_filter),
        mipmapMode              = vk_cont_to_sampler_filter_mode(descriptor.mipmap_filter),
        addressModeU            = vk_conv_to_sampler_address_mode(descriptor.address_mode_u),
        addressModeV            = vk_conv_to_sampler_address_mode(descriptor.address_mode_v),
        addressModeW            = vk_conv_to_sampler_address_mode(descriptor.address_mode_w),
        mipLodBias              = 0.0,
        anisotropyEnable        = false,
        maxAnisotropy           = 1.0,
        compareEnable           = false,
        compareOp               = .ALWAYS,
        minLod                  = descriptor.lod_min_clamp,
        maxLod                  = resolved.lod_max_clamp,
        borderColor             = vk_conv_to_border_color(descriptor.border_color),
        unnormalizedCoordinates = false,
    }

    if descriptor.compare != .Undefined {
        create_info.compareEnable = true
        create_info.compareOp = vk_conv_to_compare_op(descriptor.compare)
    }

    if resolved.anisotropy_clamp > 1 {
        create_info.anisotropyEnable = true
        create_info.maxAnisotropy = f32(resolved.anisotropy_clamp)
    }

    vk_sampler := vk_sampler_cache_create_sampler(&impl.sampler_cache, &create_info, loc)
    if vk_sampler == {} {
        return {}
    }

    _, sampler_handle := add_impl(&impl.samplers, VK_Sampler_Impl {
        base = _Sampler_Impl {
            comparison = descriptor.compare != .Undefined,
            filtering  = descriptor.mag_filter ==
                .Linear || descriptor.min_filter == .Linear || descriptor.mipmap_filter == .Linear,
        },
        device = device,
        vk_sampler = vk_sampler,
        create_info = create_info,
    })
    vk_label_set(&impl.labels, .Sampler, pack_handle(sampler_handle), descriptor.label)

    return new_handle(Sampler, device, sampler_handle)
}

@(require_results)
vk_sampler_get_internal_impl :: #force_inline proc "contextless" (
    sampler: Sampler,
    loc := #caller_location,
) -> ^_Sampler_Impl {
    return &vk_sampler_get_impl(sampler, loc).base
}

@(require_results)
vk_sampler_get_impl :: #force_inline proc "contextless" (
    sampler: Sampler,
    loc := #caller_location,
) -> ^VK_Sampler_Impl {
    device_impl := vk_device_get_impl(sampler.device, loc)
    return get_handle_impl(&device_impl.samplers, sampler.handle, loc)
}

vk_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    impl := vk_sampler_get_impl(sampler, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    return vk_label_get(&device_impl.labels, .Sampler, pack_handle(impl.handle))
}

vk_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    impl := vk_sampler_get_impl(sampler, loc)
    device_impl := vk_device_get_impl(impl.device, loc)
    vk_label_set(&device_impl.labels, .Sampler, pack_handle(impl.handle), label)
    vk_utils_set_debug_object_name(device_impl.fp, .SAMPLER, impl.vk_sampler, label, loc)
}

vk_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    impl := vk_sampler_get_impl(sampler, loc)
    add_ref(impl, loc)
}

vk_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    impl := vk_sampler_get_impl(sampler, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_deferred_add_resource(
            &device_impl.deferred,
            &device_impl.submitter,
            VK_Deferred_Sampler {
                cache       = &device_impl.sampler_cache,
                create_info = impl.create_info,
                sampler     = impl.vk_sampler,
            },
        )
        vk_label_remove(&device_impl.labels, .Sampler, pack_handle(impl.handle))
        remove_handle_impl(&device_impl.samplers, impl.handle)
    }
}

// -----------------------------------------------------------------------------
// Sampler Cache
// -----------------------------------------------------------------------------

// If the allowed sampler count is above this value, the sampler cache is
// disabled and every create is a passthrough.
VK_ENABLE_SAMPLER_CACHE_CUTOFF :: 1 << 20

// Optimized version of vk.SamplerCreateInfo to use as map key.
VK_Sampler_Cache_Key :: struct #packed {
    flags:                    vk.SamplerCreateFlags,
    mip_lod_bias_bits:        u32,
    max_anisotropy_bits:      u32,
    min_lod_bits:             u32,
    max_lod_bits:             u32,
    mag_filter:               vk.Filter,
    min_filter:               vk.Filter,
    mipmap_mode:              vk.SamplerMipmapMode,
    address_mode_u:           vk.SamplerAddressMode,
    address_mode_v:           vk.SamplerAddressMode,
    address_mode_w:           vk.SamplerAddressMode,
    compare_op:               vk.CompareOp,
    border_color:             vk.BorderColor,
    anisotropy_enable:        b32,
    compare_enable:           b32,
    unnormalized_coordinates: b32,
}

#assert(size_of(VK_Sampler_Cache_Key) == 16 * size_of(u32))

// Canonicalize an f32 into a stable u32 bit pattern for use as a key component.
vk_sampler_cache_f32_bits :: proc "contextless" (v: f32) -> u32 {
    bits := transmute(u32)v
    if bits == 0x8000_0000 {
        return 0 // -0.0 → +0.0
    }
    if bits & 0x7F80_0000 == 0x7F80_0000 && bits & 0x007F_FFFF != 0 {
        return 0x7FC0_0000 // canonical NaN
    }
    return bits
}

vk_sampler_cache_key_from_create_info :: proc(
    info: ^vk.SamplerCreateInfo,
    loc := #caller_location,
) -> VK_Sampler_Cache_Key {
    // pNext must be nil for the cache path; otherwise extension structs would
    // alias different samplers onto the same key.
    ensure(info.pNext == nil, "VULKAN: [VK_Sampler_Cache_Key] does not encode [pNext]", loc)

    // mipmapMode is ignored by spec when minFilter is NEAREST or LINEAR.
    mipmap_mode := info.mipmapMode
    if info.minFilter == .NEAREST || info.minFilter == .LINEAR {
        mipmap_mode = .NEAREST
    }

    // compareOp is ignored unless compareEnable is set.
    compare_op := info.compareOp
    if !info.compareEnable {
        compare_op = .NEVER
    }

    // borderColor is only meaningful if any address mode is CLAMP_TO_BORDER.
    border_color := info.borderColor
    if info.addressModeU != .CLAMP_TO_BORDER &&
       info.addressModeV != .CLAMP_TO_BORDER &&
       info.addressModeW != .CLAMP_TO_BORDER {
        border_color = .FLOAT_TRANSPARENT_BLACK
    }

    // maxAnisotropy is ignored unless anisotropyEnable is set.
    max_anisotropy_bits: u32
    if info.anisotropyEnable {
        max_anisotropy_bits = vk_sampler_cache_f32_bits(info.maxAnisotropy)
    }

    return {
        flags                    = info.flags,
        mip_lod_bias_bits        = vk_sampler_cache_f32_bits(info.mipLodBias),
        max_anisotropy_bits      = max_anisotropy_bits,
        min_lod_bits             = vk_sampler_cache_f32_bits(info.minLod),
        max_lod_bits             = vk_sampler_cache_f32_bits(info.maxLod),
        mag_filter               = info.magFilter,
        min_filter               = info.minFilter,
        mipmap_mode              = mipmap_mode,
        address_mode_u           = info.addressModeU,
        address_mode_v           = info.addressModeV,
        address_mode_w           = info.addressModeW,
        compare_op               = compare_op,
        border_color             = border_color,
        anisotropy_enable        = info.anisotropyEnable,
        compare_enable           = info.compareEnable,
        unnormalized_coordinates = info.unnormalizedCoordinates,
    }
}

vk_conv_to_border_color :: proc(border: Sampler_Border_Color) -> vk.BorderColor {
    switch border {
    case .Undefined, .Transparent_Black, .Zero:
        return .FLOAT_TRANSPARENT_BLACK
    case .Opaque_Black:
        return .FLOAT_OPAQUE_BLACK
    case .Opaque_White:
        return .FLOAT_OPAQUE_WHITE
    }
    return .FLOAT_TRANSPARENT_BLACK
}

// Hash the key's raw bytes with fnv64a and use that u64 as the map key.
// Entry in the sampler cache.
VK_Sampler_Cache_Entry :: struct {
    sampler:   vk.Sampler,
    ref_count: u32,
}

// Compares two keys by treating them as raw byte arrays.
VK_Sampler_Cache_Map :: map[VK_Sampler_Cache_Key]VK_Sampler_Cache_Entry

// Global sampler cache.
//
// As some devices have a low limit (4000) on the number of unique samplers
// that can be created, we need to cache samplers to avoid running out if
// people eagerly create duplicate samplers.
VK_Sampler_Cache :: struct {
    device:         Device,
    // Mapping from the sampler description
    samplers:       VK_Sampler_Cache_Map,
    // Maximum number of unique samplers that can be created.
    total_capacity: u32,
    // If true, the sampler cache is disabled and all samplers are created on demand.
    passthrough:    bool,
    // Guard the map mutations.
    mtx:            sync.Mutex,
}

vk_sampler_cache_init :: proc(
    self: ^VK_Sampler_Cache,
    device: Device,
    total_capacity: u32,
    allocator: runtime.Allocator,
) {
    self.device = device
    self.samplers = make(VK_Sampler_Cache_Map, allocator)
    self.total_capacity = total_capacity == 0 ? 4000 : total_capacity
    // Only disable the cache if the device can create an effectively unbounded
    // number of samplers.
    self.passthrough = self.total_capacity > VK_ENABLE_SAMPLER_CACHE_CUTOFF
}

vk_sampler_cache_destroy :: proc(self: ^VK_Sampler_Cache) {
    delete(self.samplers)
}

// Create a sampler, or return an existing one if the descriptor already has one in
// the cache. On a cache hit, the reference count is incremented.
//
// If the cache is full, an error is returned.
vk_sampler_cache_create_sampler :: proc(
    self: ^VK_Sampler_Cache,
    create_info: ^vk.SamplerCreateInfo,
    loc := #caller_location,
) -> vk.Sampler {
    create_sampler :: proc(
        device: Device,
        create_info: ^vk.SamplerCreateInfo,
        loc := #caller_location,
    ) -> vk.Sampler {
        device_impl := vk_device_get_impl(device, loc)
        vk_sampler: vk.Sampler
        vk_check(
            device_impl.fp.CreateSampler(device_impl.vk_device, create_info, nil, &vk_sampler),
            loc = loc,
        )
        return vk_sampler
    }

    create_sampler_destroy :: proc(device: Device, sampler: vk.Sampler, loc := #caller_location) {
        device_impl := vk_device_get_impl(device, loc)
        device_impl.fp.DestroySampler(device_impl.vk_device, sampler, nil)
    }

    if self.passthrough {
        return create_sampler(self.device, create_info, loc)
    }

    key := vk_sampler_cache_key_from_create_info(create_info, loc)

    // Check the cache, then create outside the lock so a slow driver call does
    // not serialize every sampler creation. Re-check on insert: another thread
    // may have created the same sampler in the meantime.
    sync.lock(&self.mtx)
    if entry, ok := &self.samplers[key]; ok {
        entry.ref_count += 1
        sync.unlock(&self.mtx)
        return entry.sampler
    }
    if u32(len(self.samplers)) >= self.total_capacity {
        sync.unlock(&self.mtx)
        gpu_report_validation_error(
            self.device,
            "no more unique samplers fit the device sampler cache",
            loc,
        )
        return {}
    }
    sync.unlock(&self.mtx)

    vk_sampler := create_sampler(self.device, create_info, loc)

    sync.lock(&self.mtx)
    if entry, ok := &self.samplers[key]; ok {
        entry.ref_count += 1
        sync.unlock(&self.mtx)
        create_sampler_destroy(self.device, vk_sampler, loc)
        return entry.sampler
    }
    if u32(len(self.samplers)) >= self.total_capacity {
        sync.unlock(&self.mtx)
        create_sampler_destroy(self.device, vk_sampler, loc)
        gpu_report_validation_error(
            self.device,
            "no more unique samplers fit the device sampler cache",
            loc,
        )
        return {}
    }
    self.samplers[key] = VK_Sampler_Cache_Entry {
        sampler   = vk_sampler,
        ref_count = 1,
    }
    sync.unlock(&self.mtx)

    return vk_sampler
}

// Destroy a cached sampler, or drop a passthrough sampler.
//
// The provided `create_info` must match the one used at create time. The
// `provided_sampler` must be the handle that was returned from create.
vk_sampler_cache_destroy_sampler :: proc(
    self: ^VK_Sampler_Cache,
    create_info: ^vk.SamplerCreateInfo,
    provided_sampler: vk.Sampler,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    if self.passthrough {
        device_impl.fp.DestroySampler(device_impl.vk_device, provided_sampler, nil)
        return
    }

    key := vk_sampler_cache_key_from_create_info(create_info, loc)

    should_destroy := false
    sync.lock(&self.mtx)

    entry, entry_ok := &self.samplers[key]

    ensure(
        entry_ok,
        "VULKAN: Trying to destroy a sampler that does not exist in the cache. " +
        "\n\tEither [create_info] does not match the one used at create time, or the " +
        "sampler was already fully released.",
        loc,
    )
    ensure(
        entry.sampler == provided_sampler,
        "VULKAN: Provided sampler handle does not match the cached one for this key.",
        loc,
    )

    entry.ref_count -= 1
    if entry.ref_count == 0 {
        delete_key(&self.samplers, key)
        should_destroy = true
    }
    sync.unlock(&self.mtx)

    // Destroy outside the cache lock: the driver call can block.
    if should_destroy {
        device_impl.fp.DestroySampler(device_impl.vk_device, provided_sampler, nil)
    }
}
