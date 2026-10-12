#+build !js
package gpu

// Core
import "base:runtime"
import "core:hash"
import "core:log"
import "core:mem"
import "core:sync"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Sampler_Handle :: distinct hm.Handle64

VK_Sampler_Impl :: struct {
    device:      Device,
    vk_sampler:  vk.Sampler,
    create_info: vk.SamplerCreateInfo,
    handle:      VK_Sampler_Handle,
    ref:         Ref_Count_Type,
}

vk_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    impl := vk_device_get_impl(device, loc)

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
        maxLod                  = descriptor.lod_max_clamp,
        borderColor             = .FLOAT_TRANSPARENT_BLACK,
        unnormalizedCoordinates = false,
    }

    if descriptor.compare != .Undefined {
        create_info.compareEnable = true
        create_info.compareOp = vk_conv_to_compare_op(descriptor.compare)
    }

    if descriptor.anisotropy_clamp > 1 {
        create_info.anisotropyEnable = true
        create_info.maxAnisotropy = f32(descriptor.anisotropy_clamp)
    }

    vk_sampler := vk_sampler_cache_create_sampler(&impl.sampler_cache, &create_info, loc)

    _, sampler_handle := add_impl(&impl.samplers, VK_Sampler_Impl {
        device      = device,
        vk_sampler  = vk_sampler,
        create_info = create_info,
    })

    return new_handle(Sampler, device, sampler_handle)
}

@(require_results)
vk_sampler_get_impl :: #force_inline proc "contextless" (
    sampler: Sampler,
    loc := #caller_location,
) -> ^VK_Sampler_Impl {
    device_impl := vk_device_get_impl(sampler.device, loc)
    return get_handle_impl(&device_impl.samplers, sampler.handle, loc)
}

vk_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    impl := vk_sampler_get_impl(sampler, loc)
    add_ref(impl, loc)
}

vk_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    impl := vk_sampler_get_impl(sampler, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
            VK_Deferred_Sampler{
                cache = &device_impl.sampler_cache,
                create_info = impl.create_info,
                sampler = impl.vk_sampler,
            },
        )
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
    assert(info.pNext == nil, "VULKAN: [VK_Sampler_Cache_Key] does not encode [pNext]", loc)

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

// Hash the key's raw bytes with fnv64a and use that u64 as the map key.
vk_sampler_cache_key_hash :: proc(key: ^VK_Sampler_Cache_Key) -> u64 {
    return hash.fnv64a(mem.ptr_to_bytes(key))
}

// Entry in the sampler cache.
VK_Sampler_Cache_Entry :: struct {
    sampler:   vk.Sampler,
    ref_count: u32,
}

// Compares two keys by treating them as raw byte arrays.
vk_sampler_cache_key_equal :: proc(a, b: ^VK_Sampler_Cache_Key) -> bool {
    return mem.compare(mem.ptr_to_bytes(a), mem.ptr_to_bytes(b)) == 0
}

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
    self.total_capacity = total_capacity
    // Only disable the cache if the device can create an effectively unbounded
    // number of samplers.
    self.passthrough = total_capacity > VK_ENABLE_SAMPLER_CACHE_CUTOFF
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
        vk_check(device_impl.fp.CreateSampler(
            device_impl.vk_device, create_info, nil, &vk_sampler), loc = loc)
        return vk_sampler
    }

    if self.passthrough {
        return create_sampler(self.device, create_info, loc)
    }

    key := vk_sampler_cache_key_from_create_info(create_info, loc)

    sync.guard(&self.mtx)

    if entry, ok := &self.samplers[key]; ok {
        entry.ref_count += 1
        return entry.sampler
    }

    // We need to create a new sampler, first check if we can create more.
    log.ensuref(u32(len(self.samplers)) < self.total_capacity,
        "VULKAN: There is no more room in the sampler map for more unique samplers. " +
        "\n\tThe device supports a maximum of [%d] unique samplers.",
        self.total_capacity, loc = loc)

    // Create the sampler.
    vk_sampler := create_sampler(self.device, create_info, loc)

    // Insert the new sampler into the mapping.
    self.samplers[key] = VK_Sampler_Cache_Entry {
        sampler   = vk_sampler,
        ref_count = 1,
    }

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

    sync.guard(&self.mtx)

    entry, entry_ok := &self.samplers[key]

    assert(entry_ok,
        "VULKAN: Trying to destroy a sampler that does not exist in the cache. " +
        "\n\tEither [create_info] does not match the one used at create time, or the " +
        "sampler was already fully released.", loc)
    assert(entry.sampler == provided_sampler,
        "VULKAN: Provided sampler handle does not match the cached one for this key.", loc)

    entry.ref_count -= 1
    if entry.ref_count == 0 {
        device_impl.fp.DestroySampler(device_impl.vk_device, provided_sampler, nil)
        delete_key(&self.samplers, key)
    }
}
