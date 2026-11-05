#+build !js
package gpu

// Core
import "base:runtime"
import "core:math"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

// Bucketed descriptor-pool allocator.
//
// Pools are bucketed by their exact descriptor-count signature (and whether
// update-after-bind is needed), and a descriptor set is allocated from the
// oldest pool in the matching bucket that still has room.

// -----------------------------------------------------------------------------
// Descriptor Allocator
// -----------------------------------------------------------------------------

VK_POOL_MIN_SETS :: 64
VK_POOL_MAX_SETS :: 512

VK_NR_OF_DESCRIPTOR_TYPES :: 12

// Number of descriptors of each type.
VK_Descriptor_Counts :: struct {
    sampler:                       u32,
    combined_image_sampler:        u32,
    sampled_image:                 u32,
    storage_image:                 u32,
    uniform_texel_buffer:          u32,
    storage_texel_buffer:          u32,
    uniform_buffer:                u32,
    storage_buffer:                u32,
    uniform_buffer_dynamic:        u32,
    storage_buffer_dynamic:        u32,
    input_attachment:              u32,
    acceleration_structure:        u32,
    inline_uniform_block_bytes:    u32,
    inline_uniform_block_bindings: u32,
}

vk_descriptor_counts_total :: proc(counts: VK_Descriptor_Counts) -> u32 {
    return(
        counts.sampler +
        counts.combined_image_sampler +
        counts.sampled_image +
        counts.storage_image +
        counts.uniform_texel_buffer +
        counts.storage_texel_buffer +
        counts.uniform_buffer +
        counts.storage_buffer +
        counts.uniform_buffer_dynamic +
        counts.storage_buffer_dynamic +
        counts.input_attachment +
        counts.acceleration_structure +
        counts.inline_uniform_block_bytes +
        counts.inline_uniform_block_bindings \
    )
}

VK_Descriptor_Set :: struct {
    raw:        vk.DescriptorSet,
    bucket_key: VK_Descriptor_Bucket_Key,
    pool_index: int,
}

VK_Descriptor_Bucket_Key :: struct {
    counts:            VK_Descriptor_Counts,
    update_after_bind: bool,
}

VK_Descriptor_Pool :: struct {
    raw:       vk.DescriptorPool,
    capacity:  u32,
    available: u32,
}

// Keeps track of all pools created with this bucket's VK_Descriptor_Bucket_Key.
VK_Descriptor_Bucket :: struct {
    // We keep track of all descriptor set layouts that might use this bucket.
    // If the set becomes empty, the bucket is destroyed.
    layouts:        map[vk.DescriptorSetLayout]bool,
    pools:          [dynamic]VK_Descriptor_Pool,
    available_sets: u32,
    allocated_sets: u32,
}

vk_descriptor_bucket_create_pool :: proc(
    self: ^VK_Descriptor_Bucket,
    device: Device,
    key: VK_Descriptor_Bucket_Key,
    capacity_hint: u32,
    loc := #caller_location,
) -> (
    pool_index: int,
    pool: ^VK_Descriptor_Pool,
) {
    index := len(self.pools)
    new_pool := vk_create_descriptor_pool(device, key, capacity_hint, loc)
    self.available_sets += new_pool.capacity
    append(&self.pools, new_pool)
    return index, &self.pools[index]
}

VK_Descriptor_Bucket_Map :: map[VK_Descriptor_Bucket_Key]VK_Descriptor_Bucket

VK_Descriptor_Allocator :: struct {
    device:                Device,
    buckets:               VK_Descriptor_Bucket_Map,
    max_update_after_bind: u32,
    update_after_bind:     u32,
    allocator:             runtime.Allocator,
    mtx:                   sync.Mutex,
}

vk_descriptor_allocator_init :: proc(
    self: ^VK_Descriptor_Allocator,
    device: Device,
    max_update_after_bind: u32,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    ensure(self != nil, loc = loc)
    self.device = device
    self.allocator = allocator
    self.max_update_after_bind = max_update_after_bind
    self.update_after_bind = 0
    self.buckets = make(VK_Descriptor_Bucket_Map, allocator)
}

vk_descriptor_allocator_uninit :: proc(self: ^VK_Descriptor_Allocator, loc := #caller_location) {
    sync.guard(&self.mtx)
    assert(
        len(self.buckets) == 0,
        "buckets are not empty, at least one BGL has not been unregistered",
        loc,
    )
    delete(self.buckets)
}

// Device-teardown escape hatch: drop every pool and bucket even if descriptor
// sets are still allocated. Vulkan frees those sets with their pool.
vk_descriptor_allocator_destroy_all :: proc(
    self: ^VK_Descriptor_Allocator,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)
    device_impl := vk_device_get_impl(self.device, loc)
    for _, bucket in self.buckets {
        for pool in bucket.pools {
            device_impl.fp.DestroyDescriptorPool(device_impl.vk_device, pool.raw, nil)
        }
        delete(bucket.pools)
        delete(bucket.layouts)
    }
    clear(&self.buckets)
    self.update_after_bind = 0
}

VK_Descriptor_Layout_Info :: struct {
    raw:                     vk.DescriptorSetLayout,
    desc_count:              VK_Descriptor_Counts,
    contains_binding_arrays: bool,
}

vk_bind_group_layout_bucket_key :: proc(
    layout: VK_Descriptor_Layout_Info,
) -> VK_Descriptor_Bucket_Key {
    return {
        counts            = layout.desc_count,
        update_after_bind = layout.contains_binding_arrays,
    }
}

vk_descriptor_allocator_register_layout :: proc(
    self: ^VK_Descriptor_Allocator,
    layout: VK_Descriptor_Layout_Info,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)

    key := vk_bind_group_layout_bucket_key(layout)

    // Check if bucket already exists and mutate in place
    if bucket, bucket_ok := &self.buckets[key]; bucket_ok {
        ensure(layout.raw not_in bucket.layouts, "layout already registered in bucket")
        bucket.layouts[layout.raw] = true
        return
    }

    bucket := VK_Descriptor_Bucket {
        layouts = make(map[vk.DescriptorSetLayout]bool, self.allocator),
        pools   = make([dynamic]VK_Descriptor_Pool, self.allocator),
    }

    // Create at least 1 pool upfront instead of doing this when
    // creating the first bind group.
    vk_descriptor_bucket_create_pool(&bucket, self.device, key, VK_POOL_MIN_SETS)

    bucket.layouts[layout.raw] = true
    self.buckets[key] = bucket
}

vk_descriptor_allocator_unregister_layout :: proc(
    self: ^VK_Descriptor_Allocator,
    layout: VK_Descriptor_Layout_Info,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)

    key := vk_bind_group_layout_bucket_key(layout)
    bucket, bucket_ok := &self.buckets[key]
    ensure(bucket_ok, "bucket does not exists", loc)

    ensure(layout.raw in bucket.layouts, "layout not registered in bucket", loc)
    delete_key(&bucket.layouts, layout.raw)

    if len(bucket.layouts) == 0 {
        device_impl := vk_device_get_impl(self.device, loc)
        // Remove the bucket and destroy any remaining pools.
        delete_key(&self.buckets, key)
        for pool in bucket.pools {
            assert(
                pool.available == pool.capacity,
                "pool is not empty, at least one DescriptorSet has not been freed",
            )
            device_impl.fp.DestroyDescriptorPool(device_impl.vk_device, pool.raw, nil)
        }
        delete(bucket.pools)
        delete(bucket.layouts)
    }
}

vk_descriptor_allocator_alloc :: proc(
    self: ^VK_Descriptor_Allocator,
    layout: VK_Descriptor_Layout_Info,
    loc := #caller_location,
) -> VK_Descriptor_Set {
    update_after_bind := layout.contains_binding_arrays
    total_descriptors := vk_descriptor_counts_total(layout.desc_count)
    key := vk_bind_group_layout_bucket_key(layout)
    vk_layout_raw := layout.raw
    device_impl := vk_device_get_impl(self.device, loc)

    vk_raw_set: vk.DescriptorSet

    // Reserve a slot under the lock, then call the driver outside it so a
    // multi-threaded creator does not serialize every allocation. The pool's
    // index and raw handle stay valid while unlocked: pools are only appended,
    // and the reclaim path pops the last pool only when it is fully available,
    // which our reservation prevents.
    for {
        pool_raw: vk.DescriptorPool
        pool_index: int

        sync.lock(&self.mtx)

        bucket, bucket_ok := &self.buckets[key]
        ensure(bucket_ok, "bucket does not exists", loc)

        if update_after_bind {
            assert(
                self.max_update_after_bind - self.update_after_bind >= total_descriptors,
                "update-after-bind descriptor budget exhausted",
                loc,
            )
        }

        selected := -1
        for i in 0 ..< len(bucket.pools) {
            if bucket.pools[i].available > 0 {
                selected = i
                break
            }
        }
        created_pool := false
        if selected < 0 {
            // All pools are full or marked exhausted, so create a new one. A
            // freshly created, correctly sized pool failing its first
            // allocation would be genuinely unexpected per the Vulkan spec.
            capacity_hint := bucket.allocated_sets
            new_index, _ := vk_descriptor_bucket_create_pool(
                bucket,
                self.device,
                key,
                capacity_hint,
                loc,
            )
            selected = new_index
            created_pool = true
        }

        pool := &bucket.pools[selected]
        pool.available -= 1
        bucket.available_sets -= 1
        bucket.allocated_sets += 1
        if update_after_bind {
            self.update_after_bind += total_descriptors
        }
        pool_raw = pool.raw
        pool_index = selected

        sync.unlock(&self.mtx)

        vk_info := vk.DescriptorSetAllocateInfo {
            sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool     = pool_raw,
            descriptorSetCount = 1,
            pSetLayouts        = &vk_layout_raw,
        }
        result := device_impl.fp.AllocateDescriptorSets(
            device_impl.vk_device,
            &vk_info,
            &vk_raw_set,
        )
        if result == .SUCCESS {
            return {
                raw        = vk_raw_set,
                bucket_key = key,
                pool_index = pool_index,
            }
        }

        // Roll the reservation back. A pool that reports out-of-memory or
        // fragmentation is leaving rotation; drop its remaining slots from the
        // bucket tally so the eviction heuristic in `free` stays accurate.
        sync.lock(&self.mtx)
        bucket2, bucket2_ok := &self.buckets[key]
        if !bucket2_ok || pool_index >= len(bucket2.pools) {
            sync.unlock(&self.mtx)
            vk_check(result, loc = loc)
            return {}
        }

        pool2 := &bucket2.pools[pool_index]
        bucket2.allocated_sets -= 1
        if update_after_bind {
            self.update_after_bind -= total_descriptors
        }
        #partial switch result {
        case .ERROR_OUT_OF_POOL_MEMORY, .ERROR_FRAGMENTED_POOL:
            bucket2.available_sets -= pool2.available
            pool2.available = 0
            if created_pool {
                // A fresh pool that cannot fit its first set will not improve
                // by retrying with another new pool.
                sync.unlock(&self.mtx)
                vk_check(result, loc = loc)
                return {}
            }

        case:
            pool2.available += 1
            bucket2.available_sets += 1
            sync.unlock(&self.mtx)
            vk_check(result, loc = loc)
            return {}
        }
        sync.unlock(&self.mtx)
        // Retry with the next pool.
    }
}

vk_descriptor_allocator_free :: proc(
    self: ^VK_Descriptor_Allocator,
    set: VK_Descriptor_Set,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)

    bucket := &self.buckets[set.bucket_key]
    pool := &bucket.pools[set.pool_index]

    device_impl := vk_device_get_impl(self.device, loc)

    vk_raw_set := set.raw
    vk_check(
        device_impl.fp.FreeDescriptorSets(device_impl.vk_device, pool.raw, 1, &vk_raw_set),
        loc = loc,
    )

    pool.available += 1
    bucket.available_sets += 1
    bucket.allocated_sets -= 1
    if set.bucket_key.update_after_bind {
        self.update_after_bind -= vk_descriptor_counts_total(set.bucket_key.counts)
    }

    // Don't immediately destroy empty pools - they may be recently created.
    // Destroy a pool only if it's empty and other pools have 1/4 of its
    // capacity. This never destroys the last pool.
    last_pool := &bucket.pools[len(bucket.pools) - 1]
    if last_pool.available == last_pool.capacity &&
       bucket.available_sets - last_pool.capacity > last_pool.capacity / 4 {
        popped := pop(&bucket.pools)
        device_impl.fp.DestroyDescriptorPool(device_impl.vk_device, popped.raw, nil)
        bucket.available_sets -= popped.capacity
    }
}

vk_create_descriptor_pool :: proc(
    device: Device,
    key: VK_Descriptor_Bucket_Key,
    capacity_hint: u32,
    loc := #caller_location,
) -> VK_Descriptor_Pool {
    counts := key.counts

    Count_Entry :: struct {
        ty:    vk.DescriptorType,
        count: u32,
    }

    entries := [VK_NR_OF_DESCRIPTOR_TYPES]Count_Entry {
        {.SAMPLER, counts.sampler},
        {.COMBINED_IMAGE_SAMPLER, counts.combined_image_sampler},
        {.SAMPLED_IMAGE, counts.sampled_image},
        {.STORAGE_IMAGE, counts.storage_image},
        {.UNIFORM_TEXEL_BUFFER, counts.uniform_texel_buffer},
        {.STORAGE_TEXEL_BUFFER, counts.storage_texel_buffer},
        {.UNIFORM_BUFFER, counts.uniform_buffer},
        {.STORAGE_BUFFER, counts.storage_buffer},
        {.UNIFORM_BUFFER_DYNAMIC, counts.uniform_buffer_dynamic},
        {.STORAGE_BUFFER_DYNAMIC, counts.storage_buffer_dynamic},
        {.INPUT_ATTACHMENT, counts.input_attachment},
        {.ACCELERATION_STRUCTURE_KHR, counts.acceleration_structure},
    }

    // bounded doubling growth strategy
    capacity := u32(
        math.next_power_of_two(clamp(int(capacity_hint), VK_POOL_MIN_SETS, VK_POOL_MAX_SETS)),
    )

    // Lower capacity to avoid overflowing `count * capacity` calculations
    // below. The resulting `capacity` might not be a power of 2 but that's ok.
    for entry in entries {
        capacity = min(max(u32) / max(entry.count, 1), capacity)
    }

    // Inline uniform block fields don't map to a single vk.DescriptorType
    // entry (they're scaled separately below), so they're clamped here too.
    if counts.inline_uniform_block_bytes > 0 {
        capacity = min(capacity, max(u32) / counts.inline_uniform_block_bytes)
    }
    if counts.inline_uniform_block_bindings > 0 {
        capacity = min(capacity, max(u32) / counts.inline_uniform_block_bindings)
    }

    pool_sizes: [dynamic; VK_NR_OF_DESCRIPTOR_TYPES]vk.DescriptorPoolSize
    for entry in entries {
        if entry.count != 0 {
            append(&pool_sizes, vk.DescriptorPoolSize {
                type            = entry.ty,
                descriptorCount = entry.count * capacity,
            })
        }
    }

    // Prior to Vulkan 1.3.215 `poolSizeCount` was required to be non-zero, so
    // add a single small sampler entry if `pool_sizes` would otherwise be
    // empty.
    if len(pool_sizes) == 0 {
        append(&pool_sizes, vk.DescriptorPoolSize {
            type            = .SAMPLER,
            descriptorCount = 1,
        })
    }

    flags := vk.DescriptorPoolCreateFlags{.FREE_DESCRIPTOR_SET}
    if key.update_after_bind {
        flags |= {.UPDATE_AFTER_BIND}
    }

    vk_info := vk.DescriptorPoolCreateInfo {
        sType         = .DESCRIPTOR_POOL_CREATE_INFO,
        flags         = flags,
        maxSets       = capacity,
        poolSizeCount = u32(len(pool_sizes)),
        pPoolSizes    = raw_data(pool_sizes[:]),
    }

    iub_info: vk.DescriptorPoolInlineUniformBlockCreateInfo
    inline_uniform_block_bindings := counts.inline_uniform_block_bindings * capacity
    if inline_uniform_block_bindings > 0 {
        iub_info = {
            sType                         = .DESCRIPTOR_POOL_INLINE_UNIFORM_BLOCK_CREATE_INFO,
            maxInlineUniformBlockBindings = inline_uniform_block_bindings,
        }
        vk_info.pNext = &iub_info
    }

    device_impl := vk_device_get_impl(device, loc)

    raw: vk.DescriptorPool
    vk_check(
        device_impl.fp.CreateDescriptorPool(device_impl.vk_device, &vk_info, nil, &raw),
        loc = loc,
    )

    return {
        raw       = raw,
        capacity  = capacity,
        available = capacity,
    }
}
