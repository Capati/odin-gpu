#+build !js
package gpu

// Core
import "base:runtime"
import "core:math"
import "core:slice"
import "core:sync"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Buffer_Access :: struct {
    buffer:     Buffer,
    is_storage: bool,
}

VK_Texture_View_Access :: struct {
    texture_view: Texture_View,
    is_storage:   bool,
}

VK_Bind_Group_Handle :: distinct hm.Handle64

VK_Bind_Group_Impl :: struct {
    // Base
    using base:     Bind_Group_Impl,

    // Backend
    descriptor_set: VK_Descriptor_Set,
    buffers:        []VK_Buffer_Access,
    samplers:       []Sampler,
    texture_views:  []VK_Texture_View_Access,
    handle:         VK_Bind_Group_Handle,
}

vk_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    impl := vk_device_get_impl(device, loc)
    layout_impl := vk_bind_group_layout_get_impl(descriptor.layout, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    desc := resolve_device_create_bind_group(device, descriptor, loc)

    vk_bind_group_layout_add_ref(desc.layout)

    vk_descriptor_set := vk_descriptor_allocator_alloc(&impl.descriptor,
        VK_Descriptor_Layout_Info{
            raw                     = layout_impl.raw,
            desc_count              = layout_impl.desc_count,
            contains_binding_arrays = layout_impl.contains_binding_arrays,
        })

    buffer_desc_count := len(desc.buffers)
    image_desc_count  := len(desc.samplers) + len(desc.texture_views)

    writes       := make([]vk.WriteDescriptorSet, len(desc.entries), ta)
    buffer_infos := make([]vk.DescriptorBufferInfo, buffer_desc_count, ta)
    image_infos  := make([]vk.DescriptorImageInfo, image_desc_count, ta)

    buffers         := make([dynamic]VK_Buffer_Access, 0, buffer_desc_count, impl.allocator)
    texture_views   := make(
        [dynamic]VK_Texture_View_Access,
        0, len(desc.texture_views), impl.allocator)
    samplers      := make([dynamic]Sampler, 0, len(desc.samplers), impl.allocator)

    write_idx, buffer_idx, image_idx: int

    for entry in desc.entries {
        // Application binding numbers are mapped to Vulkan binding numbers when the
        // layout is created; only the lookup is a backend concern.
        layout_index, layout_found := slice.binary_search_by(
            layout_impl.binding_map,
            entry.binding,
            proc(layout_entry: VK_Binding_Info, binding: u32) -> slice.Ordering {
                return slice.cmp(layout_entry.key, binding)
            },
        )
        assert(layout_found, "Failed to find bind group layout entry for binding", loc)
        layout_binding := layout_impl.binding_map[layout_index]

        layout_entry := layout_impl.base.entries[layout_binding.key]

        assert(entry.binding_array_size == layout_binding.binding_array_size,
            "Descriptor count mismatch for binding (provided != layout expected)", loc)

        end := entry.resource_index + int(entry.binding_array_size)

        writes[write_idx] = vk.WriteDescriptorSet{
            sType           = .WRITE_DESCRIPTOR_SET,
            dstSet          = vk_descriptor_set.raw,
            dstBinding      = layout_binding.binding,
            dstArrayElement = 0,
            descriptorCount = entry.binding_array_size,
            descriptorType  = vk_conv_to_descriptor_type(layout_entry),
        }

        #partial switch t in entry.type {
        case Buffer_Binding_Layout:
            writes[write_idx].pBufferInfo = &buffer_infos[buffer_idx]

            for slot in desc.buffers[entry.resource_index:end] {
                buffer_impl := vk_buffer_get_impl(slot.binding.buffer, loc)
                buffer_infos[buffer_idx] = vk.DescriptorBufferInfo{
                    buffer = buffer_impl.vk_buffer,
                    offset = vk.DeviceSize(slot.binding.offset),
                    range  = vk.DeviceSize(slot.binding.size),
                }
                append(&buffers, VK_Buffer_Access{
                    buffer     = slot.binding.buffer,
                    is_storage = slot.is_storage,
                })
                vk_buffer_add_ref(slot.binding.buffer)
                buffer_idx += 1
            }

        case Sampler_Binding_Layout:
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for smp in desc.samplers[entry.resource_index:end] {
                sampler_impl := vk_sampler_get_impl(smp, loc)
                image_infos[image_idx] = vk.DescriptorImageInfo{sampler = sampler_impl.vk_sampler}
                append(&samplers, smp)
                vk_sampler_add_ref(smp)
                image_idx += 1
            }

        case Texture_Binding_Layout, Storage_Texture_Binding_Layout:
            writes[write_idx].pImageInfo = &image_infos[image_idx]

            for slot in desc.texture_views[entry.resource_index:end] {
                tv_impl := vk_texture_view_get_impl(slot.view, loc)
                image_infos[image_idx] = vk.DescriptorImageInfo{
                    imageView   = tv_impl.vk_image_view,
                    imageLayout = vk.ImageLayout.GENERAL if
                        slot.is_storage else .SHADER_READ_ONLY_OPTIMAL,
                }
                append(&texture_views, VK_Texture_View_Access{
                    texture_view = slot.view,
                    is_storage   = slot.is_storage,
                })
                vk_texture_view_add_ref(slot.view)
                image_idx += 1
            }

        case:
            panic("Unsupported bind group entry resource", loc)
        }

        write_idx += 1
    }

    vk.UpdateDescriptorSets(impl.vk_device, u32(write_idx), raw_data(writes), 0, nil)

    _, handle := add_impl(&impl.bind_groups, VK_Bind_Group_Impl{
        device         = device,
        layout         = desc.layout,
        used           = desc.used,
        descriptor_set = vk_descriptor_set,
        buffers        = buffers[:],
        texture_views  = texture_views[:],
        samplers       = samplers[:],
    })

    return new_handle(Bind_Group, device, handle)
}

@(require_results)
vk_bind_group_get_public_impl :: #force_inline proc "contextless" (
    bind_group: Bind_Group,
    loc := #caller_location,
) -> ^Bind_Group_Impl {
    return vk_bind_group_get_impl(bind_group, loc)
}

@(require_results)
vk_bind_group_get_impl :: #force_inline proc "contextless" (
    bind_group: Bind_Group,
    loc := #caller_location,
) -> ^VK_Bind_Group_Impl {
    device_impl := vk_device_get_impl(bind_group.device, loc)
    return get_handle_impl(&device_impl.bind_groups, bind_group.handle, loc)
}

vk_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

vk_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := vk_bind_group_get_impl(bind_group, loc)
    add_ref(impl, loc)
}

vk_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := vk_bind_group_get_impl(bind_group, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)

        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter,
            VK_Deferred_Descriptor_Set{
                descriptor     = &device_impl.descriptor,
                descriptor_set = impl.descriptor_set,
            },
        )

        for buffer_access in impl.buffers {
            vk_buffer_release(buffer_access.buffer, loc)
        }
        for texture_view_access in impl.texture_views {
            vk_texture_view_release(texture_view_access.texture_view, loc)
        }
        for sampler in impl.samplers {
            vk_sampler_release(sampler, loc)
        }
        vk_bind_group_layout_release(impl.layout, loc)

        delete(impl.buffers, device_impl.allocator)
        delete(impl.texture_views, device_impl.allocator)
        delete(impl.samplers, device_impl.allocator)

        bind_group_state_uiinit(&impl.used, loc)

        remove_handle_impl(&device_impl.bind_groups, impl.handle)
    }
}

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

vk_descriptor_counts_buffers :: proc(self: VK_Descriptor_Counts) -> u32 {
    return(
        self.uniform_buffer +
        self.storage_buffer +
        self.uniform_buffer_dynamic +
        self.storage_buffer_dynamic \
    )
}

vk_descriptor_counts_images :: proc(self: VK_Descriptor_Counts) -> u32 {
    return(
        self.sampler +
        self.combined_image_sampler +
        self.sampled_image +
        self.storage_image \
    )
}

vk_descriptor_counts_samplers :: proc(self: VK_Descriptor_Counts) -> u32 {
    return self.sampler
}

vk_descriptor_counts_texture_views :: proc(self: VK_Descriptor_Counts) -> u32 {
    return self.sampled_image + self.storage_image
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
    assert(self != nil, loc = loc)
    self.device = device
    self.allocator = allocator
    self.max_update_after_bind = max_update_after_bind
    self.update_after_bind = 0
    self.buckets = make(VK_Descriptor_Bucket_Map, allocator)
}

vk_descriptor_allocator_uninit :: proc(self: ^VK_Descriptor_Allocator, loc := #caller_location) {
    sync.guard(&self.mtx)
    assert(len(self.buckets) == 0,
        "buckets are not empty, at least one BGL has not been unregistered", loc)
    delete(self.buckets)
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
        assert(layout.raw not_in bucket.layouts, "layout already registered in bucket")
        bucket.layouts[layout.raw] = true
        return
    }

    bucket := VK_Descriptor_Bucket{
        layouts = make(map[vk.DescriptorSetLayout]bool, self.allocator),
        pools = make([dynamic]VK_Descriptor_Pool, self.allocator),
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
    assert(bucket_ok, "bucket does not exists", loc)

    assert(layout.raw in bucket.layouts, "layout not registered in bucket", loc)
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
    sync.guard(&self.mtx)

    update_after_bind := layout.contains_binding_arrays
    total_descriptors := vk_descriptor_counts_total(layout.desc_count)

    if update_after_bind {
        assert(self.max_update_after_bind - self.update_after_bind >= total_descriptors,
            "update-after-bind descriptor budget exhausted", loc)
    }

    key := vk_bind_group_layout_bucket_key(layout)

    bucket, bucket_ok := &self.buckets[key]
    assert(bucket_ok, "bucket does not exists", loc)

    vk_raw_set: vk.DescriptorSet
    pool_index := -1
    pool: ^VK_Descriptor_Pool

    vk_layout_raw := layout.raw

    device_impl := vk_device_get_impl(self.device, loc)

    // Prefer smaller/older/fuller pools to reduce fragmentation.
    //
    // A reused pool hitting either is recoverable - drivers can report it on a
    // churned pool even when there's room. Mark it exhausted for new
    // allocations and try the next one instead of asserting. Sets already
    // allocated from it still free normally and recycle its `available` count;
    // it just stops being offered to new allocations until it empties.
    for i in 0 ..< len(bucket.pools) {
        candidate := &bucket.pools[i]
        if candidate.available == 0 {
            continue
        }

        vk_info := vk.DescriptorSetAllocateInfo {
            sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool     = candidate.raw,
            descriptorSetCount = 1,
            pSetLayouts        = &vk_layout_raw,
        }

        result := device_impl.fp.AllocateDescriptorSets(
            device_impl.vk_device, &vk_info, &vk_raw_set)
        #partial switch result {
        case .SUCCESS:
            pool_index = i
            pool = candidate

        case .ERROR_OUT_OF_POOL_MEMORY, .ERROR_FRAGMENTED_POOL:
            // This pool's remaining slots are leaving rotation, so remove them
            // from the bucket-wide tally too; otherwise the eviction heuristic
            // in `free` overcounts.
            bucket.available_sets -= candidate.available
            candidate.available = 0
            continue

        case:
            vk_check(result, loc = loc)
        }

        if pool != nil {
            break
        }
    }

    if pool == nil {
        // All existing pools are full or marked exhausted above, so create a
        // new one. A freshly created, correctly sized pool failing its first
        // allocation would be genuinely unexpected per the Vulkan spec.
        capacity_hint := bucket.allocated_sets
        new_pool_index, new_pool :=
            vk_descriptor_bucket_create_pool(bucket, self.device, key, capacity_hint, loc)

        vk_info := vk.DescriptorSetAllocateInfo {
            sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool     = new_pool.raw,
            descriptorSetCount = 1,
            pSetLayouts        = &vk_layout_raw,
        }
        vk_check(device_impl.fp.AllocateDescriptorSets(
            device_impl.vk_device, &vk_info, &vk_raw_set), loc = loc)

        pool_index, pool = new_pool_index, new_pool
    }

    pool.available -= 1
    bucket.available_sets -= 1
    bucket.allocated_sets += 1
    if update_after_bind {
        self.update_after_bind += total_descriptors
    }

    return {
        raw = vk_raw_set,
        bucket_key = key,
        pool_index = pool_index,
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
    vk_check(device_impl.fp.FreeDescriptorSets(
        device_impl.vk_device, pool.raw, 1, &vk_raw_set), loc = loc)

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
    if last_pool.available == last_pool.capacity \
           && bucket.available_sets - last_pool.capacity > last_pool.capacity / 4 {
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
        {.SAMPLER,                    counts.sampler},
        {.COMBINED_IMAGE_SAMPLER,     counts.combined_image_sampler},
        {.SAMPLED_IMAGE,              counts.sampled_image},
        {.STORAGE_IMAGE,              counts.storage_image},
        {.UNIFORM_TEXEL_BUFFER,       counts.uniform_texel_buffer},
        {.STORAGE_TEXEL_BUFFER,       counts.storage_texel_buffer},
        {.UNIFORM_BUFFER,             counts.uniform_buffer},
        {.STORAGE_BUFFER,             counts.storage_buffer},
        {.UNIFORM_BUFFER_DYNAMIC,     counts.uniform_buffer_dynamic},
        {.STORAGE_BUFFER_DYNAMIC,     counts.storage_buffer_dynamic},
        {.INPUT_ATTACHMENT,           counts.input_attachment},
        {.ACCELERATION_STRUCTURE_KHR, counts.acceleration_structure},
    }

    // bounded doubling growth strategy
    capacity := u32(math.next_power_of_two(
        clamp(int(capacity_hint), VK_POOL_MIN_SETS, VK_POOL_MAX_SETS)))

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

    pool_sizes: [dynamic;VK_NR_OF_DESCRIPTOR_TYPES]vk.DescriptorPoolSize
    for entry in entries {
        if entry.count != 0 {
            append(&pool_sizes,
                vk.DescriptorPoolSize{
                    type = entry.ty,
                    descriptorCount = entry.count * capacity,
                },
            )
        }
    }

    // Prior to Vulkan 1.3.215 `poolSizeCount` was required to be non-zero, so
    // add a single small sampler entry if `pool_sizes` would otherwise be
    // empty.
    if len(pool_sizes) == 0 {
        append(&pool_sizes,
            vk.DescriptorPoolSize{
                type = .SAMPLER,
                descriptorCount = 1,
            },
        )
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
    vk_check(device_impl.fp.CreateDescriptorPool(
        device_impl.vk_device, &vk_info, nil, &raw), loc = loc)

    return {
        raw = raw,
        capacity = capacity,
        available = capacity,
    }
}
