#+build !js
package vulkan_tests

// Core
import "core:math"
import "core:testing"
import "core:thread"
import "core:time"

// Vendor
import vk "vendor:vulkan"

// Local
import gpu "../../gpu"

// Backend tests that need a live Vulkan device, plus cache bookkeeping that
// does not. Device-backed tests return quietly when no Vulkan adapter exists.

VK_Test_Fixture :: struct {
    instance: gpu.Instance,
    adapter:  gpu.Adapter,
    device:   gpu.Device,
}

vk_test_swallow_error :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {}

vk_test_fixture :: proc() -> (VK_Test_Fixture, bool) {
    fixture: VK_Test_Fixture
    fixture.instance = gpu.create_instance(context.allocator, {backends = {.Vulkan}})
    if fixture.instance == nil {
        return fixture, false
    }
    fixture.adapter = gpu.instance_create_adapter(fixture.instance, {})
    if fixture.adapter == {} {
        gpu.instance_release(fixture.instance)
        return fixture, false
    }
    descriptor := gpu.Device_Descriptor {
        required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS,
    }
    descriptor.uncaptured_error_callback_info = {
        callback = vk_test_swallow_error,
    }
    fixture.device = gpu.adapter_create_device(fixture.adapter, descriptor)
    if fixture.device == nil {
        gpu.adapter_release(fixture.adapter)
        gpu.instance_release(fixture.instance)
        return fixture, false
    }
    return fixture, true
}

vk_test_fixture_destroy :: proc(fixture: VK_Test_Fixture) {
    if fixture.device != nil {
        gpu.device_release(fixture.device)
    }
    if fixture.adapter != {} {
        gpu.adapter_release(fixture.adapter)
    }
    if fixture.instance != nil {
        gpu.instance_release(fixture.instance)
    }
}

@(test)
test_vk_descriptor_allocator_reuses_pools :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    device_impl := gpu.vk_device_get_impl(fixture.device)
    binding := vk.DescriptorSetLayoutBinding {
        binding         = 0,
        descriptorType  = .UNIFORM_BUFFER,
        descriptorCount = 1,
        stageFlags      = {.VERTEX},
    }
    create_info := vk.DescriptorSetLayoutCreateInfo {
        sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        bindingCount = 1,
        pBindings    = &binding,
    }
    raw_layout: vk.DescriptorSetLayout
    result := device_impl.fp.CreateDescriptorSetLayout(
        device_impl.vk_device, &create_info, nil, &raw_layout)
    testing.expect_value(t, result, vk.Result.SUCCESS)
    if result != .SUCCESS {
        return
    }
    defer device_impl.fp.DestroyDescriptorSetLayout(
        device_impl.vk_device, raw_layout, nil)

    layout := gpu.VK_Descriptor_Layout_Info {
        raw        = raw_layout,
        desc_count = {uniform_buffer = 1},
    }
    allocator: gpu.VK_Descriptor_Allocator
    gpu.vk_descriptor_allocator_init(&allocator, fixture.device, 0, context.allocator)
    defer gpu.vk_descriptor_allocator_uninit(&allocator)
    gpu.vk_descriptor_allocator_register_layout(&allocator, layout)
    defer gpu.vk_descriptor_allocator_unregister_layout(&allocator, layout)

    key := gpu.vk_bind_group_layout_bucket_key(layout)
    bucket := &allocator.buckets[key]
    pools_before := len(bucket.pools)
    capacity := bucket.pools[0].capacity
    testing.expect_value(t, pools_before, 1)

    first := gpu.vk_descriptor_allocator_alloc(&allocator, layout)
    testing.expect_value(t, bucket.allocated_sets, 1)
    gpu.vk_descriptor_allocator_free(&allocator, first)
    testing.expect_value(t, bucket.allocated_sets, 0)
    testing.expect_value(t, bucket.available_sets, capacity)

    second := gpu.vk_descriptor_allocator_alloc(&allocator, layout)
    testing.expect_value(t, len(bucket.pools), pools_before)
    testing.expect_value(t, second.pool_index, first.pool_index)
    gpu.vk_descriptor_allocator_free(&allocator, second)
}

@(test)
test_vk_fence_bookkeeping :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    for kind in ([2]gpu.VK_Fence_Kind{.Fence_Pool, .Timeline_Semaphore}) {
        fence: gpu.VK_Fence
        gpu.vk_fence_init(&fence, fixture.device, kind)
        testing.expect_value(t, gpu.vk_fence_get_value(&fence), u64(0))

        signals: gpu.VK_Semaphore_List
        signals.mode = .Signal
        raw := gpu.vk_fence_arm_submission(&fence, 1, &signals)

        if kind == .Fence_Pool {
            testing.expect(t, raw != {}, "the pool arm should return a VkFence")
            testing.expect_value(t, len(fence.active), 1)
            testing.expect_value(t, fence.active[0].value, u64(1))
            testing.expect_value(t, gpu.vk_fence_get_value(&fence), u64(0))
        } else {
            testing.expect(t, raw == {}, "the timeline arm signals a semaphore")
            testing.expect_value(t, len(signals.semaphores), 1)
            testing.expect_value(t, signals.values[0], u64(1))
            testing.expect_value(t, signals.semaphores[0], fence.timeline)
        }
        gpu.vk_fence_destroy(&fence)
    }
}

@(test)
test_vk_framebuffer_cache_insert_semantics :: proc(t: ^testing.T) {
    device_impl: gpu.VK_Device_Impl
    device_impl.framebuffer_cache.allocator = context.allocator
    defer delete(device_impl.framebuffer_cache)

    key := gpu.VK_Framebuffer_Key{}
    first := gpu.VK_Framebuffer_Cache {
        key            = key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x1000)),
    }
    second := gpu.VK_Framebuffer_Cache {
        key            = key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x2000)),
    }

    result, inserted := gpu.vk_framebuffer_cache_insert_if_absent(&device_impl, first)
    testing.expect(t, inserted, "first insertion should win")
    testing.expect_value(t, result, first.vk_framebuffer)

    result, inserted = gpu.vk_framebuffer_cache_insert_if_absent(&device_impl, second)
    testing.expect(t, !inserted, "an equivalent key should not replace the entry")
    testing.expect_value(t, result, first.vk_framebuffer)

    cached, found := gpu.vk_framebuffer_cache_lookup(&device_impl, key)
    testing.expect(t, found, "the inserted key should be found")
    testing.expect_value(t, cached.vk_framebuffer, first.vk_framebuffer)
    testing.expect_value(t, len(device_impl.framebuffer_cache), 1)
}

@(test)
test_vk_framebuffer_cache_eviction :: proc(t: ^testing.T) {
    device_impl: gpu.VK_Device_Impl
    device_impl.framebuffer_cache.allocator = context.allocator
    defer delete(device_impl.framebuffer_cache)

    removed_view := gpu.new_handle_packed(
        gpu.Texture_View, gpu.Device(nil), gpu.Handle_Packed(1))
    other_view := gpu.new_handle_packed(
        gpu.Texture_View, gpu.Device(nil), gpu.Handle_Packed(2))

    removed_key := gpu.VK_Framebuffer_Key{width = 1, height = 1, attachment_count = 1}
    removed_key.texture_views[0].texture_view = removed_view
    other_key := gpu.VK_Framebuffer_Key{width = 2, height = 2, attachment_count = 1}
    other_key.texture_views[0].texture_view = other_view

    device_impl.framebuffer_cache[removed_key] = {
        key            = removed_key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x1000)),
    }
    device_impl.framebuffer_cache[other_key] = {
        key            = other_key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x2000)),
    }

    matched: [dynamic]vk.Framebuffer
    matched.allocator = context.allocator
    defer delete(matched)
    gpu.vk_framebuffer_cache_remove_view(&device_impl, removed_view, &matched)

    testing.expect_value(t, len(matched), 1)
    testing.expect_value(t, matched[0], vk.Framebuffer(uintptr(0x1000)))
    testing.expect_value(t, len(device_impl.framebuffer_cache), 1)
    _, removed_still_cached := device_impl.framebuffer_cache[removed_key]
    _, other_still_cached := device_impl.framebuffer_cache[other_key]
    testing.expect(t, !removed_still_cached, "the evicted view's entry should be removed")
    testing.expect(t, other_still_cached, "an unrelated view's entry should stay cached")
}

@(test)
test_vk_render_pass_cache_is_bounded :: proc(t: ^testing.T) {
    device_impl: gpu.VK_Device_Impl
    device_impl.render_pass_cache.allocator = context.allocator
    defer delete(device_impl.render_pass_cache)

    for i in 0 ..< gpu.VK_RENDER_PASS_CACHE_MAX + 1 {
        key := gpu.VK_Render_Pass_Key{sample_count = u32(i + 1)}
        _, inserted, evicted := gpu.vk_render_pass_cache_insert_if_absent(
            &device_impl, key, vk.RenderPass(uintptr(0x1000 + i)))
        testing.expect(t, inserted, "a new key should insert")
        if i < gpu.VK_RENDER_PASS_CACHE_MAX {
            testing.expect_value(t, evicted, vk.RenderPass{})
        } else {
            testing.expect(t, evicted != {},
                "the cache must evict once it exceeds its bound")
        }
    }
    testing.expect_value(
        t, len(device_impl.render_pass_cache), gpu.VK_RENDER_PASS_CACHE_MAX)
    testing.expect_value(
        t, device_impl.render_pass_cache_order_len, gpu.VK_RENDER_PASS_CACHE_MAX)
}

@(test)
test_vk_barrier_batching :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffers: [4]gpu.Buffer
    for &buffer in buffers {
        buffer = gpu.device_create_buffer(fixture.device, {
            size  = 256,
            usage = {.Copy_Dst, .Uniform},
        })
        testing.expect(t, buffer != {}, "failed to create a barrier test buffer")
    }
    defer for buffer in buffers {
        if buffer != {} {
            gpu.buffer_release(buffer)
        }
    }

    record :: proc(device: gpu.Device, buffers: []gpu.Buffer) -> u64 {
        device_impl := gpu.vk_device_get_impl(device)
        transitions := make([]gpu.Buffer_State_Transition, len(buffers), context.temp_allocator)
        for buffer, index in buffers {
            transitions[index] = {
                buffer = buffer,
                from   = gpu.BUFFER_USES_UNIFORM,
                to     = gpu.BUFFER_USES_COPY_DST,
            }
        }

        before := device_impl.barrier_calls
        encoder := gpu.device_create_command_encoder(device)
        gpu._command_encoder_transition_buffers(encoder, transitions)
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
        return device_impl.barrier_calls - before
    }

    single_calls := record(fixture.device, buffers[0:1])
    many_calls := record(fixture.device, buffers[:])
    testing.expect(t, single_calls > 0, "a transition request must emit a barrier")
    testing.expect_value(t, many_calls, single_calls)
}

@(test)
test_vk_surface_view_formats_srgb_only :: proc(t: ^testing.T) {
    base := gpu.Texture_Format.RGBA8_Unorm
    testing.expect(t, gpu.vk_surface_view_formats_valid(base, nil),
        "no view formats must be valid")
    testing.expect(t, gpu.vk_surface_view_formats_valid(
        base, []gpu.Texture_Format{base}), "the base format may repeat")
    testing.expect(t, gpu.vk_surface_view_formats_valid(
        base, []gpu.Texture_Format{.RGBA8_Unorm_Srgb}),
        "the sRGB variant is the allowed surface view format")
    testing.expect(t, !gpu.vk_surface_view_formats_valid(
        base, []gpu.Texture_Format{.RGBA8_Snorm}),
        "a non-sRGB variant is not a legal surface view format")
}

@(test)
test_vk_new_advertised_features_create_devices :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    features := []gpu.Feature_Name {
        .Ray_Tracing_Pipelines,
        .Ray_Hit_Vertex_Return,
        .Extended_Acceleration_Structure_Vertex_Formats,
        .Mesh_Shader,
        .Mesh_Shader_Points,
        .Mesh_Shader_Multiview,
        .Vulkan_External_Memory_Fd,
        .Vulkan_External_Memory_Win32,
        .Vulkan_External_Memory_Dma_Buf,
        .Vulkan_Google_Display_Timing,
    }

    for feature in features {
        if !gpu.adapter_has_feature(fixture.adapter, feature) {
            continue
        }
        descriptor := gpu.Device_Descriptor {
            required_features = []gpu.Feature_Name{feature},
            required_limits   = gpu.DEFAULT_DOWNLEVEL_LIMITS,
        }
        descriptor.uncaptured_error_callback_info = {
            callback = vk_test_swallow_error,
        }
        device := gpu.adapter_create_device(fixture.adapter, descriptor)
        testing.expectf(t, device != nil,
            "advertised feature %v could not create a device", feature)
        if device != nil {
            gpu.device_release(device)
        }
    }
}

@(test)
test_vk_queue_write_buffer_host_visible_direct :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        usage = {.Map_Read, .Copy_Dst},
        size  = 16,
    })
    if buffer == {} {
        return
    }
    defer gpu.buffer_release(buffer)

    values := [4]u32{11, 22, 33, 44}
    gpu.queue_write_buffer_raw(
        gpu.device_get_queue(fixture.device),
        buffer,
        0,
        rawptr(&values[0]),
        uint(size_of(values)),
    )

    // A staged write is only copied by the next submission, so reading before
    // any submit proves the host-visible direct path ran.
    future := gpu.buffer_map_async(buffer, .Read, 0, 16, {})
    info := gpu.Future_Wait_Info{future = future}
    status := gpu.instance_wait_any(fixture.instance, []^gpu.Future_Wait_Info{&info})
    testing.expect(t, status == .Success, "the readback mapping did not resolve")

    ptr := gpu.buffer_get_const_mapped_range(buffer, 0, 16)
    testing.expect(t, ptr != nil, "the readback mapping is empty")
    if ptr != nil {
        readback := cast([^]u32)ptr
        for value, index in values {
            testing.expectf(t, readback[index] == value,
                "host-visible write mismatch at %d: got %d, want %d",
                index, readback[index], value)
        }
    }
}

@(test)
test_vk_deferred_write_visible_after_map_async :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        usage              = {.Map_Read, .Copy_Dst},
        size               = 16,
        mapped_at_creation = true,
    })
    if buffer == {} {
        return
    }
    defer gpu.buffer_release(buffer)

    // Unmapping the mapped-at-creation buffer records a staging copy into the
    // deferred batch. `queue_write_buffer_raw` then bails out of the
    // host-visible fast path because the buffer already has a pending write,
    // so the write below is definitely staged.
    gpu.buffer_unmap(buffer)

    queue := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue)

    values := [4]u32{11, 22, 33, 44}
    gpu.queue_write_buffer_raw(
        queue, buffer, 0, rawptr(&values[0]), uint(size_of(values)))

    // No `queue_submit`: resolving the mapping has to flush the queued writes
    // first, otherwise this reads stale memory.
    future := gpu.buffer_map_async(buffer, .Read, 0, 16, {})
    info := gpu.Future_Wait_Info{future = future}
    status := gpu.instance_wait_any(fixture.instance, []^gpu.Future_Wait_Info{&info})
    testing.expect(t, status == .Success, "the readback mapping did not resolve")

    ptr := gpu.buffer_get_const_mapped_range(buffer, 0, 16)
    testing.expect(t, ptr != nil, "the readback mapping is empty")
    if ptr != nil {
        readback := cast([^]u32)ptr
        for value, index in values {
            testing.expectf(t, readback[index] == value,
                "deferred write mismatch at %d: got %d, want %d",
                index, readback[index], value)
        }
    }
}

@(test)
test_vk_deferred_write_destroy_before_submit :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        usage = {.Copy_Dst, .Copy_Src},
        size  = 16,
    })
    if buffer == {} {
        return
    }

    queue := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue)

    values := [4]u32{1, 2, 3, 4}
    gpu.queue_write_buffer_raw(
        queue, buffer, 0, rawptr(&values[0]), uint(size_of(values)))

    // Destroy and release while the write is still queued. The raw buffer must
    // stay alive until the submission that consumes it retires.
    gpu.buffer_destroy(buffer)
    gpu.buffer_release(buffer)

    gpu.queue_submit(queue, nil)
    testing.expect(t, gpu.device_poll(fixture.device, true, nil),
        "waiting for the queued write failed")

    // The empty submit drives the deferred deleter after the first submission
    // has retired.
    gpu.queue_submit(queue, nil)
}

@(test)
test_vk_buffer_mapped_range_access_mode :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    read_buffer := gpu.device_create_buffer(fixture.device, {
        size  = 16,
        usage = {.Map_Read, .Copy_Dst},
    })
    if read_buffer == {} {
        return
    }
    defer gpu.buffer_release(read_buffer)

    read_ptr := gpu.buffer_map_sync(read_buffer, .Read, 0, 16)
    testing.expect(t, read_ptr != nil, "the read mapping failed")
    testing.expect(t, gpu.buffer_get_mapped_range(read_buffer, 0, 8) == nil,
        "the writable getter accepted a read-only mapping")

    // Overlapping const ranges are allowed; the API does not track views.
    const_a := gpu.buffer_get_const_mapped_range(read_buffer, 0, 8)
    const_b := gpu.buffer_get_const_mapped_range(read_buffer, 0, 8)
    testing.expect(t, const_a != nil && const_b != nil,
        "overlapping const ranges were rejected")

    values := [2]u32{11, 22}
    testing.expect_value(t,
        gpu.buffer_write_mapped_range(read_buffer, 0, rawptr(&values[0]), 8),
        gpu.Status.Error)
    out: [2]u32
    testing.expect_value(t,
        gpu.buffer_read_mapped_range(read_buffer, 0, rawptr(&out[0]), 8),
        gpu.Status.Success)

    gpu.buffer_unmap(read_buffer)
    testing.expect_value(t, gpu.buffer_get_map_state(read_buffer), gpu.Buffer_Map_State.Unmapped)

    write_buffer := gpu.device_create_buffer(fixture.device, {
        size  = 16,
        usage = {.Map_Write},
    })
    if write_buffer == {} {
        return
    }
    defer gpu.buffer_release(write_buffer)

    write_ptr := gpu.buffer_map_sync(write_buffer, .Write, 0, 16)
    testing.expect(t, write_ptr != nil, "the write mapping failed")

    mutable_a := gpu.buffer_get_mapped_range(write_buffer, 0, 8)
    mutable_b := gpu.buffer_get_mapped_range(write_buffer, 0, 8)
    testing.expect(t, mutable_a != nil, "the first writable range was rejected")
    testing.expect(t, mutable_b != nil, "the overlapping writable range was rejected")
    testing.expect(t, gpu.buffer_get_const_mapped_range(write_buffer, 0, 8) != nil,
        "a const range was rejected on a writable mapping")

    written := [2]u32{33, 44}
    testing.expect_value(t,
        gpu.buffer_write_mapped_range(write_buffer, 0, rawptr(&written[0]), 8),
        gpu.Status.Success)
    readback: [2]u32
    testing.expect_value(t,
        gpu.buffer_read_mapped_range(write_buffer, 0, rawptr(&readback[0]), 8),
        gpu.Status.Success)
    testing.expect_value(t, readback[0], u32(33))
    testing.expect_value(t, readback[1], u32(44))

    gpu.buffer_unmap(write_buffer)
    testing.expect_value(t, gpu.buffer_get_map_state(write_buffer), gpu.Buffer_Map_State.Unmapped)
}

vk_test_error_message: string

vk_test_record_error :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    vk_test_error_message = message
}

@(test)
test_vk_sampler_binding_array_update_after_bind :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    if !gpu.adapter_has_feature(fixture.adapter, .Texture_Binding_Array) {
        return
    }

    limits := gpu.adapter_get_limits(fixture.adapter)
    if limits.max_binding_array_sampler_elements_per_shader_stage < 4 {
        return
    }

    descriptor := gpu.Device_Descriptor {
        required_features = {.Texture_Binding_Array},
        required_limits   = limits,
    }
    descriptor.uncaptured_error_callback_info = {
        callback = vk_test_record_error,
    }
    device := gpu.adapter_create_device(fixture.adapter, descriptor)
    if device == nil {
        return
    }
    defer gpu.device_release(device)

    entries := [1]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Fragment},
            type       = gpu.Sampler_Binding_Layout{},
            count      = 4,
        },
    }
    vk_test_error_message = ""
    layout := gpu.device_create_bind_group_layout(device, {entries = entries[:]})
    testing.expectf(t, layout != {}, "failed to create a sampler array layout: %s",
        vk_test_error_message)
    if layout == {} {
        return
    }
    defer gpu.bind_group_layout_release(layout)

    samplers: [4]gpu.Sampler
    for &sampler in samplers {
        sampler = gpu.device_create_sampler(device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
        if sampler == {} {
            return
        }
    }
    defer for sampler in samplers {
        gpu.sampler_release(sampler)
    }

    group_entries := [1]gpu.Bind_Group_Entry {
        {binding = 0, resource = samplers[:]},
    }
    vk_test_error_message = ""
    group := gpu.device_create_bind_group(device, {
        layout  = layout,
        entries = group_entries[:],
    })
    testing.expectf(t, group != {}, "failed to create a sampler array bind group: %s",
        vk_test_error_message)
    if group != {} {
        gpu.bind_group_release(group)
    }
}

@(test)
test_vk_queue_timestamp_period :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    queue := gpu.device_get_queue(fixture.device)
    testing.expect(t, queue != {}, "failed to get the default queue")
    if queue == {} {
        return
    }
    defer gpu.queue_release(queue)
    testing.expect(t, gpu.queue_get_timestamp_period(queue) > 0,
        "the Vulkan queue must report a positive timestamp period")
}

@(test)
test_create_instance_respects_backend_mask :: proc(t: ^testing.T) {
    instance := gpu.create_instance(context.allocator, {
        backends = {.DX12},
    })
    testing.expect(t, instance == nil,
        "a non-Vulkan backend request must not create a Vulkan instance")
    if instance != nil {
        gpu.instance_release(instance)
    }
}

@(test)
test_vk_multiplanar_plane_views :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    if !gpu.adapter_has_feature(fixture.adapter, .Texture_Format_Nv12) {
        return
    }
    descriptor := gpu.Device_Descriptor {
        required_features = []gpu.Feature_Name{.Texture_Format_Nv12},
        required_limits   = gpu.DEFAULT_DOWNLEVEL_LIMITS,
    }
    descriptor.uncaptured_error_callback_info = {
        callback = vk_test_swallow_error,
    }
    device := gpu.adapter_create_device(fixture.adapter, descriptor)
    testing.expect(t, device != nil, "failed to create an NV12 device")
    if device == nil {
        return
    }
    defer gpu.device_release(device)

    texture := gpu.device_create_texture(device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .NV12,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create an NV12 texture")
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    plane0 := gpu.texture_create_view(texture, {aspect = .Plane0})
    plane1 := gpu.texture_create_view(texture, {aspect = .Plane1})
    testing.expect(t, plane0 != {}, "failed to create the NV12 plane-0 view")
    testing.expect(t, plane1 != {}, "failed to create the NV12 plane-1 view")
    if plane0 != {} {
        defer gpu.texture_view_release(plane0)
    }
    if plane1 != {} {
        defer gpu.texture_view_release(plane1)
    }
}

@(test)
test_vk_buffer_self_write_barrier :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        size  = 64,
        usage = {.Copy_Dst, .Uniform},
    })
    testing.expect(t, buffer != {}, "failed to create a self-barrier test buffer")
    if buffer == {} {
        return
    }
    defer gpu.buffer_release(buffer)

    record :: proc(
        device: gpu.Device,
        buffer: gpu.Buffer,
        uses: gpu.Buffer_Uses,
    ) -> u64 {
        device_impl := gpu.vk_device_get_impl(device)
        transitions := [1]gpu.Buffer_State_Transition{{
            buffer = buffer,
            from   = uses,
            to     = uses,
        }}
        before := device_impl.barrier_calls
        encoder := gpu.device_create_command_encoder(device)
        gpu._command_encoder_transition_buffers(encoder, transitions[:])
        command_buffer := gpu.command_encoder_finish(encoder)
        if command_buffer != {} {
            gpu.command_buffer_release(command_buffer)
        }
        gpu.command_encoder_release(encoder)
        return device_impl.barrier_calls - before
    }

    write_calls := record(fixture.device, buffer, gpu.BUFFER_USES_COPY_DST)
    read_calls := record(fixture.device, buffer, gpu.BUFFER_USES_UNIFORM)
    testing.expect(t, write_calls > 0,
        "a same-state write transition must still emit a barrier")
    testing.expect_value(t, read_calls, 0)
}

@(test)
test_vk_buffer_mapped_at_creation_initialized :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    rows := [4]struct {
        usage:              gpu.Buffer_Usages,
        mapped_at_creation: bool,
        what:               string,
    } {
        {{.Map_Write, .Copy_Src}, true, "mapped-at-creation Map_Write"},
        {{.Map_Write, .Copy_Src}, false, "unmapped Map_Write"},
        {{.Map_Read, .Copy_Dst}, false, "unmapped Map_Read"},
        {{.Copy_Src, .Copy_Dst}, false, "unmapped non-mappable"},
    }

    for row in rows {
        buffer := gpu.device_create_buffer(fixture.device, {
            size               = 16,
            usage              = row.usage,
            mapped_at_creation = row.mapped_at_creation,
        })
        testing.expect(t, buffer != {}, row.what)
        if buffer == {} {
            continue
        }
        buffer_impl := gpu.vk_buffer_get_impl(buffer)
        if row.mapped_at_creation ||
           .Map_Write in row.usage || .Map_Read in row.usage {
            testing.expect(t, len(buffer_impl.init.uninitialized) == 0,
                "CPU-visible buffers should start initialized")
        } else {
            testing.expect(t, len(buffer_impl.init.uninitialized) == 1,
                "GPU-only buffers should start uninitialized")
        }
        gpu.buffer_release(buffer)
    }
}

@(test)
test_vk_pipeline_layout_null_slot :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    layout := gpu.device_create_bind_group_layout(fixture.device, {
        entries = nil,
    })
    testing.expect(t, layout != {}, "failed to create the bind group layout")
    if layout == {} {
        return
    }
    defer gpu.bind_group_layout_release(layout)

    layouts := [2]gpu.Bind_Group_Layout{{}, layout}
    pipeline_layout := gpu.device_create_pipeline_layout(fixture.device, {
        bind_group_layouts = layouts[:],
    })
    testing.expect(t, pipeline_layout != {},
        "a null bind-group-layout slot should use the shared empty layout")
    if pipeline_layout != {} {
        gpu.pipeline_layout_release(pipeline_layout)
    }
}

@(test)
test_vk_buffer_visible_size_padding :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    index := gpu.device_create_buffer(fixture.device, {
        size  = 4,
        usage = {.Index, .Copy_Dst},
    })
    testing.expect(t, index != {}, "failed to create the index buffer")
    if index != {} {
        defer gpu.buffer_release(index)
        testing.expect_value(t, gpu.buffer_get_size(index), u64(4))
        testing.expect_value(t, gpu.vk_buffer_get_impl(index).vk_size, vk.DeviceSize(4))
    }

    vertex := gpu.device_create_buffer(fixture.device, {
        size  = 4,
        usage = {.Vertex, .Copy_Dst},
    })
    testing.expect(t, vertex != {}, "failed to create the vertex buffer")
    if vertex != {} {
        defer gpu.buffer_release(vertex)
        testing.expect_value(t, gpu.buffer_get_size(vertex), u64(4))
        testing.expect(t, gpu.vk_buffer_get_impl(vertex).vk_size >= 8,
            "a vertex buffer needs the trailing byte before alignment")
    }
}

@(test)
test_vk_framebuffer_key_includes_render_pass :: proc(t: ^testing.T) {
    device_impl: gpu.VK_Device_Impl
    device_impl.framebuffer_cache.allocator = context.allocator
    defer delete(device_impl.framebuffer_cache)

    first_key := gpu.VK_Framebuffer_Key {
        render_pass = vk.RenderPass(uintptr(0x10)),
        width       = 8,
        height      = 8,
    }
    second_key := gpu.VK_Framebuffer_Key {
        render_pass = vk.RenderPass(uintptr(0x20)),
        width       = 8,
        height      = 8,
    }
    _, _ = gpu.vk_framebuffer_cache_insert_if_absent(&device_impl, {
        key            = first_key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x1000)),
    })
    _, _ = gpu.vk_framebuffer_cache_insert_if_absent(&device_impl, {
        key            = second_key,
        vk_framebuffer = vk.Framebuffer(uintptr(0x2000)),
    })
    testing.expect_value(t, len(device_impl.framebuffer_cache), 2)
}

@(test)
test_vk_query_statistics_requires_entries :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    set := gpu.device_create_query_set(fixture.device, {
        type = .Pipeline_Statistics,
        count = 1,
    })
    testing.expect(t, set == {},
        "an empty pipeline-statistics query set should be refused")
    if set != {} {
        gpu.query_set_release(set)
    }
}

COMPUTE_TEST_SPIRV :: []u32 {
    0x07230203, 0x00010000, 0x00000000, 0x00000005, 0x00000000,
    0x00020011, 1,
    0x0003000E, 0, 1,
    0x0005000F, 5, 3, 0x6E69616D, 0,
    0x00060010, 3, 17, 1, 1, 1,
    0x00020013, 1,
    0x00030021, 2, 1,
    0x00050036, 1, 3, 0, 2,
    0x000200F8, 4,
    0x000100FD,
    0x00010038,
}

Async_Status :: struct {
    status:   gpu.Create_Pipeline_Async_Status,
    pipeline: gpu.Compute_Pipeline,
}

async_status_callback :: proc "contextless" (
    status: gpu.Create_Pipeline_Async_Status,
    pipeline: gpu.Compute_Pipeline,
    message: string,
    userdata1, userdata2: rawptr,
) {
    result := cast(^Async_Status)userdata1
    result.status = status
    result.pipeline = pipeline
}

@(test)
test_vk_async_pipeline_status_and_ownership :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    module := gpu.device_create_shader_module(fixture.device, {
        source = gpu.Shader_Source_SPIRV{code = COMPUTE_TEST_SPIRV},
    })
    testing.expect(t, module != {}, "failed to create the compute shader module")
    if module == {} {
        return
    }
    defer gpu.shader_module_release(module)

    descriptor := gpu.Compute_Pipeline_Descriptor {
        module      = module,
        entry_point = "main",
    }

    // A nil callback must not leak the pipeline.
    _ = gpu.device_create_compute_pipeline_async(fixture.device, descriptor, {})

    // An invalid descriptor must report validation, not success.
    result: Async_Status
    info := gpu.Create_Compute_Pipeline_Async_Callback_Info {
        callback  = async_status_callback,
        userdata1 = &result,
    }
    _ = gpu.device_create_compute_pipeline_async(fixture.device, {
        module      = {},
        entry_point = "main",
    }, info)
    testing.expect_value(t, result.status, gpu.Create_Pipeline_Async_Status.Validation_Error)
    testing.expect_value(t, result.pipeline, gpu.Compute_Pipeline{})
}

@(test)
test_vk_sampler_defaults :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    descriptor := gpu.DEFAULT_SAMPLER_DESCRIPTOR
    sampler := gpu.device_create_sampler(fixture.device, descriptor)
    testing.expect(t, sampler != {}, "failed to create the default sampler")
    if sampler != {} {
        sampler_impl := gpu.vk_sampler_get_impl(sampler)
        testing.expect_value(t, sampler_impl.create_info.maxLod, f32(32))
        gpu.sampler_release(sampler)
    }

    descriptor = gpu.DEFAULT_SAMPLER_DESCRIPTOR
    descriptor.address_mode_u = .Clamp_To_Border
    descriptor.border_color = .Opaque_White
    sampler = gpu.device_create_sampler(fixture.device, descriptor)
    testing.expect(t, sampler == {},
        "Clamp_To_Border must require the Address_Mode_Clamp_To_Border feature")
    if sampler != {} {
        gpu.sampler_release(sampler)
    }

    descriptor = gpu.DEFAULT_SAMPLER_DESCRIPTOR
    descriptor.lod_max_clamp = math.inf_f32(1)
    sampler = gpu.device_create_sampler(fixture.device, descriptor)
    testing.expect(t, sampler == {}, "non-finite LOD clamps should be refused")
    if sampler != {} {
        gpu.sampler_release(sampler)
    }
}

@(test)
test_vk_texture_view_d2_array_promotion :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 2},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the array texture")
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    view := gpu.texture_create_view(texture, {
        dimension         = .D2,
        array_layer_count = 2,
    })
    testing.expect(t, view != {}, "failed to create the D2-array view")
    if view != {} {
        view_impl := gpu.vk_texture_view_get_impl(view)
        testing.expect_value(t, view_impl.dimension, gpu.Texture_View_Dimension.D2_Array)
        gpu.texture_view_release(view)
    }
}

@(test)
test_vk_buffer_mapping_usage_conflict :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        size  = 16,
        usage = {.Map_Read, .Map_Write},
    })
    testing.expect(t, buffer == {},
        "Map_Read and Map_Write together should be refused")
    if buffer != {} {
        gpu.buffer_release(buffer)
    }
}

@(test)
test_vk_texture_descriptor_defaults :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage  = {.Texture_Binding},
        format = .RGBA8_Unorm,
        size   = {width = 4, height = 4, depth_or_array_layers = 1},
    })
    testing.expect(t, texture != {},
        "a texture should default to 2D with one array layer")
    if texture != {} {
        gpu.texture_release(texture)
    }
}

@(test)
test_vk_bind_group_entry_coverage :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    entries := [2]gpu.Bind_Group_Layout_Entry {
        {binding = 0, visibility = {.Fragment}, type = gpu.Sampler_Binding_Layout{}},
        {binding = 1, visibility = {.Fragment}, type = gpu.Sampler_Binding_Layout{}},
    }
    layout := gpu.device_create_bind_group_layout(fixture.device, {
        entries = entries[:],
    })
    testing.expect(t, layout != {}, "failed to create the layout")
    if layout == {} {
        return
    }
    defer gpu.bind_group_layout_release(layout)

    sampler := gpu.device_create_sampler(fixture.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
    testing.expect(t, sampler != {}, "failed to create the sampler")
    if sampler == {} {
        return
    }
    defer gpu.sampler_release(sampler)

    duplicate_entries := [2]gpu.Bind_Group_Entry {
        {binding = 0, resource = sampler},
        {binding = 0, resource = sampler},
    }
    group := gpu.device_create_bind_group(fixture.device, {
        layout  = layout,
        entries = duplicate_entries[:],
    })
    testing.expect(t, group == {}, "duplicate bindings and missing coverage must be refused")
    if group != {} {
        gpu.bind_group_release(group)
    }
}

@(test)
test_vk_bind_group_layout_array_budget :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    limit := gpu.device_get_limits(fixture.device).max_storage_buffers_per_shader_stage
    entries := [1]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Compute},
            type       = gpu.Buffer_Binding_Layout{type = .Storage},
            count      = limit + 1,
        },
    }
    layout := gpu.device_create_bind_group_layout(fixture.device, {
        entries = entries[:],
    })
    testing.expect(t, layout == {},
        "an array binding must count every element against the stage budget")
    if layout != {} {
        gpu.bind_group_layout_release(layout)
    }
}

@(test)
test_vk_texture_view_swizzle_requires_feature :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
    })
    testing.expect(t, texture != {}, "failed to create the texture")
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    view := gpu.texture_create_view(texture, {
        swizzle = {r = .One, g = .Zero, b = .B, a = .A},
    })
    testing.expect(t, view == {},
        "swizzle without an enabled [Texture_Component_Swizzle] feature should be refused")
    if view != {} {
        gpu.texture_view_release(view)
    }
}

@(test)
test_vk_render_bundle_failed_encoder_is_tombstone :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    encoder := gpu.device_create_render_bundle_encoder(fixture.device, {})
    testing.expect(t, encoder != {},
        "a refused bundle descriptor should still return a valid encoder handle")
    if encoder == {} {
        return
    }
    bundle := gpu.render_bundle_encoder_finish(encoder, {})
    testing.expect(t, bundle == {}, "a failed encoder should finish as an empty bundle")
    if bundle != {} {
        gpu.render_bundle_release(bundle)
    }
    gpu.render_bundle_encoder_release(encoder)
}

@(test)
test_vk_borrow_keeps_layouts_alive :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    layout := gpu.device_create_bind_group_layout(fixture.device, {})
    testing.expect(t, layout != {}, "failed to create the bind group layout")
    if layout == {} {
        return
    }

    pipeline_layout := gpu.device_create_pipeline_layout(fixture.device, {
        bind_group_layouts = []gpu.Bind_Group_Layout{layout},
    })
    testing.expect(t, pipeline_layout != {}, "failed to create the pipeline layout")
    if pipeline_layout == {} {
        gpu.bind_group_layout_release(layout)
        return
    }

    module := gpu.device_create_shader_module(fixture.device, {
        source = gpu.Shader_Source_SPIRV{code = COMPUTE_TEST_SPIRV},
    })
    testing.expect(t, module != {}, "failed to create the shader module")

    // The pipeline layout borrows the released layout; both remain usable.
    gpu.bind_group_layout_release(layout)
    pipeline := gpu.device_create_compute_pipeline(fixture.device, {
        layout      = pipeline_layout,
        module      = module,
        entry_point = "main",
    })
    testing.expect(t, pipeline != {},
        "a borrowed bind group layout should stay alive for the pipeline layout")
    if pipeline != {} {
        gpu.compute_pipeline_release(pipeline)
    }
    gpu.pipeline_layout_release(pipeline_layout)
    if module != {} {
        gpu.shader_module_release(module)
    }
}

@(test)
test_vk_released_layout_is_not_a_public_handle :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    entries := [1]gpu.Bind_Group_Layout_Entry {
        {binding = 0, visibility = {.Fragment}, type = gpu.Sampler_Binding_Layout{}},
    }
    layout := gpu.device_create_bind_group_layout(fixture.device, {entries = entries[:]})
    testing.expect(t, layout != {}, "failed to create the bind group layout")
    if layout == {} {
        return
    }
    sampler := gpu.device_create_sampler(fixture.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
    testing.expect(t, sampler != {}, "failed to create the sampler")
    if sampler == {} {
        gpu.bind_group_layout_release(layout)
        return
    }

    group_entries := [1]gpu.Bind_Group_Entry{{binding = 0, resource = sampler}}
    group := gpu.device_create_bind_group(fixture.device, {
        layout  = layout,
        entries = group_entries[:],
    })
    testing.expect(t, group != {}, "failed to create the bind group")
    gpu.bind_group_layout_release(layout)

    // The live group borrows the layout, but the released handle cannot create
    // another group.
    group2 := gpu.device_create_bind_group(fixture.device, {
        layout  = layout,
        entries = group_entries[:],
    })
    testing.expect(t, group2 == {}, "a released layout handle must not be reusable")
    if group2 != {} {
        gpu.bind_group_release(group2)
    }

    if group != {} {
        gpu.bind_group_release(group)
    }
    gpu.sampler_release(sampler)
}

@(test)
test_vk_memory_init_buffer_clear :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    buffer := gpu.device_create_buffer(fixture.device, {
        size  = 16,
        usage = {.Copy_Src, .Copy_Dst},
    })
    testing.expect(t, buffer != {}, "failed to create the buffer")
    if buffer == {} {
        return
    }
    defer gpu.buffer_release(buffer)

    buffer_impl := gpu.vk_buffer_get_impl(buffer)
    testing.expect(t, len(buffer_impl.init.uninitialized) == 1,
        "a fresh buffer should start fully uninitialized")

    encoder := gpu.device_create_command_encoder(fixture.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    if encoder == {} {
        return
    }
    defer gpu.command_encoder_release(encoder)

    encoder_impl := gpu.vk_command_encoder_get_impl(encoder)
    cmdbuf := encoder_impl.cmdbuf
    gpu.tracker_record_buffer_init(&cmdbuf.tracker, buffer, {start = 0, end = 16},
        .Needs_Initialized_Memory)

    device_impl := gpu.vk_device_get_impl(fixture.device)
    clear_buffer := gpu.vk_apply_pending_init_actions_at_submit(device_impl, cmdbuf)
    testing.expect(t, clear_buffer != {}, "the init action should produce a clear buffer")
    testing.expect_value(t, len(cmdbuf.tracker.buffer_init_actions), 0)
    testing.expect(t, len(buffer_impl.init.uninitialized) == 0,
        "applying the clear should mark the buffer initialized")
}

@(test)
test_vk_adapter_label_roundtrip :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    testing.expect_value(t, gpu.adapter_get_label(fixture.adapter), "")

    gpu.adapter_set_label(fixture.adapter, "test adapter")
    testing.expect_value(t, gpu.adapter_get_label(fixture.adapter), "test adapter")

    gpu.adapter_set_label(fixture.adapter, "renamed")
    testing.expect_value(t, gpu.adapter_get_label(fixture.adapter), "renamed")

    gpu.adapter_set_label(fixture.adapter, "")
    testing.expect_value(t, gpu.adapter_get_label(fixture.adapter), "")
}

@(test)
test_vk_queue_submit_for_index :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    queue := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue)

    encoder := gpu.device_create_command_encoder(fixture.device)
    if encoder == {} {
        return
    }
    defer gpu.command_encoder_release(encoder)

    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        defer gpu.command_buffer_release(command_buffer)
    }

    index := gpu.queue_submit_for_index(queue, {command_buffer})
    testing.expect(t, index != 0, "a submission must report an index")
}

@(test)
test_vk_instance_metadata_and_filters :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    testing.expect_value(t, gpu.instance_backend(fixture.instance), gpu.Backend_Type.Vulkan)
    testing.expect(t, !gpu.instance_is_embedded(fixture.instance))

    report := gpu.generate_report(fixture.instance)
    testing.expect_value(t, report.surfaces.num_allocated, 0)

    features := gpu.device_get_features(fixture.device)
    testing.expect_value(t, len(features), 0)

    options: gpu.Request_Adapter_Options
    options.backend_type = .D3D12
    testing.expect(t, gpu.instance_create_adapter(fixture.instance, options) == {})

    testing.expect(t, gpu.instance_enumerate_adapters(
        fixture.instance, {backends = {.GL}}, context.allocator) == nil)
}

@(test)
test_vk_instance_wait_any_work_done :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    queue := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue)

    size := u64(64 << 20)
    src := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Src}})
    if src == {} {
        return
    }
    defer gpu.buffer_release(src)
    dst := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Dst}})
    if dst == {} {
        return
    }
    defer gpu.buffer_release(dst)

    encoder := gpu.device_create_command_encoder(fixture.device)
    if encoder == {} {
        return
    }
    defer gpu.command_encoder_release(encoder)

    gpu.command_encoder_copy_buffer_to_buffer(encoder, src, 0, dst, 0, size)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        defer gpu.command_buffer_release(command_buffer)
    }

    gpu.queue_submit(queue, {command_buffer})
    future := gpu.queue_on_submitted_work_done(queue, {})

    wait_info := [1]gpu.Future_Wait_Info{{future = future}}
    wait_ptrs := [1]^gpu.Future_Wait_Info{&wait_info[0]}
    status := gpu.instance_wait_any(fixture.instance, wait_ptrs[:])
    testing.expect_value(t, status, gpu.Wait_Status.Success)
    testing.expect(t, wait_info[0].completed, "the waited future was not completed")
}

Lost_Destroy_Job :: struct {
    device: gpu.Device,
}

lost_destroy_worker :: proc(raw: rawptr) {
    job := cast(^Lost_Destroy_Job)raw
    time.sleep(20 * time.Millisecond)
    gpu.device_destroy(job.device)
}

@(test)
test_vk_instance_wait_any_lost_wakes :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    future := gpu.device_get_lost_future(fixture.device)
    testing.expect(t, future.id != 0, "the device lost future was not registered")
    if future.id == 0 {
        return
    }

    wait_info := [1]gpu.Future_Wait_Info{{future = future}}
    wait_ptrs := [1]^gpu.Future_Wait_Info{&wait_info[0]}

    job := Lost_Destroy_Job{device = fixture.device}
    destroy_thread := thread.create_and_start_with_poly_data(
        rawptr(&job), lost_destroy_worker)
    defer {
        thread.join(destroy_thread)
        thread.destroy(destroy_thread)
    }

    start := time.tick_now()
    status := gpu.instance_wait_any(fixture.instance, wait_ptrs[:], u64(10 * time.Second))
    elapsed := time.tick_since(start)

    testing.expect_value(t, status, gpu.Wait_Status.Success)
    testing.expect(t, wait_info[0].completed, "the lost future was not completed")
    testing.expect(t, elapsed < 10 * time.Second, "the lost wait timed out")
}

@(test)
test_vk_instance_wait_any_lost_timeout :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    future := gpu.device_get_lost_future(fixture.device)
    testing.expect(t, future.id != 0, "the device lost future was not registered")
    if future.id == 0 {
        return
    }

    wait_info := [1]gpu.Future_Wait_Info{{future = future}}
    wait_ptrs := [1]^gpu.Future_Wait_Info{&wait_info[0]}
    status := gpu.instance_wait_any(
        fixture.instance, wait_ptrs[:], u64(1 * time.Millisecond))

    testing.expect_value(t, status, gpu.Wait_Status.Timed_Out)
    testing.expect(t, !wait_info[0].completed, "the lost future completed before loss")

    gpu.device_destroy(fixture.device)
}

@(test)
test_vk_instance_wait_any_multiple_devices :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    descriptor := gpu.Device_Descriptor {
        required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS,
    }
    descriptor.uncaptured_error_callback_info = {
        callback = vk_test_swallow_error,
    }
    device2 := gpu.adapter_create_device(fixture.adapter, descriptor)
    if device2 == nil {
        return
    }
    defer gpu.device_release(device2)

    queue1 := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue1)
    queue2 := gpu.device_get_queue(device2)
    defer gpu.queue_release(queue2)

    size := u64(16 << 20)
    src1 := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Src}})
    if src1 == {} {
        return
    }
    defer gpu.buffer_release(src1)
    dst1 := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Dst}})
    if dst1 == {} {
        return
    }
    defer gpu.buffer_release(dst1)
    src2 := gpu.device_create_buffer(device2, {size = size, usage = {.Copy_Src}})
    if src2 == {} {
        return
    }
    defer gpu.buffer_release(src2)
    dst2 := gpu.device_create_buffer(device2, {size = size, usage = {.Copy_Dst}})
    if dst2 == {} {
        return
    }
    defer gpu.buffer_release(dst2)

    encoder1 := gpu.device_create_command_encoder(fixture.device)
    if encoder1 == {} {
        return
    }
    defer gpu.command_encoder_release(encoder1)
    gpu.command_encoder_copy_buffer_to_buffer(encoder1, src1, 0, dst1, 0, size)
    command_buffer1 := gpu.command_encoder_finish(encoder1)
    if command_buffer1 != {} {
        defer gpu.command_buffer_release(command_buffer1)
    }

    encoder2 := gpu.device_create_command_encoder(device2)
    if encoder2 == {} {
        return
    }
    defer gpu.command_encoder_release(encoder2)
    gpu.command_encoder_copy_buffer_to_buffer(encoder2, src2, 0, dst2, 0, size)
    command_buffer2 := gpu.command_encoder_finish(encoder2)
    if command_buffer2 != {} {
        defer gpu.command_buffer_release(command_buffer2)
    }

    gpu.queue_submit(queue1, {command_buffer1})
    future1 := gpu.queue_on_submitted_work_done(queue1, {})
    gpu.queue_submit(queue2, {command_buffer2})
    future2 := gpu.queue_on_submitted_work_done(queue2, {})

    wait_info := [2]gpu.Future_Wait_Info{{future = future1}, {future = future2}}
    wait_ptrs := [2]^gpu.Future_Wait_Info{&wait_info[0], &wait_info[1]}

    status := gpu.instance_wait_any(fixture.instance, wait_ptrs[:], u64(10 * time.Second))
    testing.expect_value(t, status, gpu.Wait_Status.Success)
    testing.expect(t, wait_info[0].completed || wait_info[1].completed,
        "no future completed across the two devices")

    if !wait_info[0].completed || !wait_info[1].completed {
        status = gpu.instance_wait_any(fixture.instance, wait_ptrs[:])
        testing.expect_value(t, status, gpu.Wait_Status.Success)
    }
    testing.expect(t, wait_info[0].completed, "the first device's future did not complete")
    testing.expect(t, wait_info[1].completed, "the second device's future did not complete")
}

@(test)
test_vk_device_poll :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    queue := gpu.device_get_queue(fixture.device)
    defer gpu.queue_release(queue)

    size := u64(64 << 20)
    src := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Src}})
    if src == {} {
        return
    }
    defer gpu.buffer_release(src)
    dst := gpu.device_create_buffer(fixture.device, {size = size, usage = {.Copy_Dst}})
    if dst == {} {
        return
    }
    defer gpu.buffer_release(dst)

    encoder := gpu.device_create_command_encoder(fixture.device)
    if encoder == {} {
        return
    }
    defer gpu.command_encoder_release(encoder)

    gpu.command_encoder_copy_buffer_to_buffer(encoder, src, 0, dst, 0, size)
    command_buffer := gpu.command_encoder_finish(encoder)
    if command_buffer != {} {
        defer gpu.command_buffer_release(command_buffer)
    }

    index := gpu.queue_submit_for_index(queue, {command_buffer})
    testing.expect(t, index != 0, "the submission did not report an index")
    testing.expect(t, gpu.device_poll(fixture.device, true, &index),
        "waiting poll did not complete")
    testing.expect(t, gpu.device_poll(fixture.device, false, &index),
        "completed submission was not idle")
    testing.expect(t, gpu.device_poll(fixture.device, false, nil),
        "the device was not idle")
    testing.expect(t, !gpu.device_start_graphics_debugger_capture(fixture.device),
        "Vulkan unexpectedly reported a capture")
    gpu.device_stop_graphics_debugger_capture(fixture.device)
}

@(test)
test_vk_texture_binding_view_dimension :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 2},
        mip_level_count = 1,
        sample_count    = 1,
    })
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    testing.expect_value(t, gpu.texture_get_texture_binding_view_dimension(texture),
        gpu.Texture_View_Dimension.D2_Array)
    testing.expect(t, gpu.texture_get_native_metal_texture(texture) == nil)
}

@(test)
test_vk_texture_view_formats_ownership :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    formats := make([]gpu.Texture_Format, 1, context.allocator)
    formats[0] = .RGBA8_Unorm_Srgb

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 4, height = 4, depth_or_array_layers = 1},
        mip_level_count = 1,
        sample_count    = 1,
        view_formats    = formats,
    })
    // The texture must own a copy, so freeing the input cannot invalidate it.
    delete(formats)
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    descriptor := gpu.texture_get_descriptor(texture)
    testing.expect_value(t, len(descriptor.view_formats), 1)
    testing.expect_value(t, descriptor.view_formats[0], gpu.Texture_Format.RGBA8_Unorm_Srgb)
}

@(test)
test_vk_texture_view_default_descriptor :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 8, height = 8, depth_or_array_layers = 1},
        mip_level_count = 3,
        sample_count    = 1,
    })
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    view := gpu.texture_create_view(texture, gpu.DEFAULT_TEXTURE_VIEW_DESCRIPTOR)
    testing.expect(t, view != {}, "default descriptor did not create a view")
    if view == {} {
        return
    }
    defer gpu.texture_view_release(view)

    view_impl := gpu.vk_texture_view_get_impl(view)
    testing.expect_value(t, view_impl.selector.mip_count, u32(3))
    testing.expect_value(t, view_impl.selector.layer_count, u32(1))

    d3_texture := gpu.device_create_texture(fixture.device, {
        usage     = {.Texture_Binding},
        dimension = .D3,
        format    = .RGBA8_Unorm,
        size      = {width = 4, height = 4, depth_or_array_layers = 4},
    })
    if d3_texture != {} {
        defer gpu.texture_release(d3_texture)
        d3_view := gpu.texture_create_view(d3_texture, gpu.DEFAULT_TEXTURE_VIEW_DESCRIPTOR)
        if d3_view != {} {
            defer gpu.texture_view_release(d3_view)
            testing.expect_value(t, gpu.vk_texture_view_get_impl(d3_view).dimension,
                gpu.Texture_View_Dimension.D3)
        }
    }
}

@(test)
test_vk_texture_view_cube_alignment :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        usage           = {.Texture_Binding},
        dimension       = .D2,
        format          = .RGBA8_Unorm,
        size            = {width = 8, height = 8, depth_or_array_layers = 12},
        mip_level_count = 1,
        sample_count    = 1,
    })
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    valid := gpu.texture_create_view(texture, {
        dimension         = .Cube_Array,
        base_array_layer  = 6,
        array_layer_count = 6,
    })
    testing.expect(t, valid != {}, "aligned cube-array view was rejected")
    if valid != {} {
        gpu.texture_view_release(valid)
    }

    invalid := gpu.texture_create_view(texture, {
        dimension         = .Cube_Array,
        base_array_layer  = 1,
        array_layer_count = 6,
    })
    testing.expect(t, invalid == {}, "unaligned cube-array view was accepted")
    if invalid != {} {
        gpu.texture_view_release(invalid)
    }
}

@(test)
test_vk_sampler_feature_validation :: proc(t: ^testing.T) {
    fixture, ok := vk_test_fixture()
    if !ok {
        return
    }
    defer vk_test_fixture_destroy(fixture)

    sampler := gpu.device_create_sampler(fixture.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
    testing.expect(t, sampler != {}, "default sampler was rejected")
    if sampler != {} {
        gpu.sampler_release(sampler)
    }

    border := gpu.device_create_sampler(fixture.device, {
        address_mode_u = .Clamp_To_Border,
    })
    testing.expect(t, border == {},
        "Clamp_To_Border was accepted without the feature")
    if border != {} {
        gpu.sampler_release(border)
    }

    zero := gpu.device_create_sampler(fixture.device, {border_color = .Zero})
    testing.expect(t, zero == {},
        "border color Zero was accepted without the feature")
    if zero != {} {
        gpu.sampler_release(zero)
    }

    no_anisotropy := gpu.device_create_sampler(fixture.device, {anisotropy_clamp = 0})
    testing.expect(t, no_anisotropy != {},
        "zero anisotropy should resolve to the default")
    if no_anisotropy != {} {
        gpu.sampler_release(no_anisotropy)
    }
}
