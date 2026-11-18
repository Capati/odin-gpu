#+build !js
package vulkan_tests

// Core
import "base:intrinsics"
import "base:runtime"
import "core:sync"
import "core:testing"
import "core:thread"

// Local
import gpu "../../gpu"

// Thread-safety stress tests for the Vulkan backend. Every device-backed test
// returns quietly when no Vulkan adapter exists.
//
// The device callback counts errors into a per-test counter (passed through
// `userdata1`), so a race that trips validation fails the test even when the
// driver itself survives. Tests only use the public API; they must not depend on
// internals except for the final leak checks.

VK_TS_THREADS      :: 4
VK_TS_ITERATIONS   :: 12
VK_TS_BUFFER_SIZE  :: 4096
VK_TS_BUFFER_WORDS :: VK_TS_BUFFER_SIZE / 4

vk_ts_count_error :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    if userdata1 != nil {
        intrinsics.atomic_add(cast(^int)userdata1, 1)
    }
}

vk_ts_pop_noop :: proc "contextless" (
    status: gpu.Pop_Error_Scope_Status,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {}

VK_TS_Fixture :: struct {
    instance: gpu.Instance,
    adapter:  gpu.Adapter,
    device:   gpu.Device,
    queue:    gpu.Queue,
}

vk_ts_fixture :: proc(errors: ^int) -> (fixture: VK_TS_Fixture, ok: bool) {
    fixture.instance = gpu.create_instance(context.allocator, {backends = {.Vulkan}})
    if fixture.instance == nil {
        return
    }
    fixture.adapter = gpu.instance_create_adapter(fixture.instance, {})
    if fixture.adapter == {} {
        gpu.instance_release(fixture.instance)
        return
    }
    descriptor := gpu.Device_Descriptor {
        required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS,
    }
    descriptor.uncaptured_error_callback_info = {
        callback  = vk_ts_count_error,
        userdata1 = rawptr(errors),
    }
    fixture.device = gpu.adapter_create_device(fixture.adapter, descriptor)
    if fixture.device == nil {
        gpu.adapter_release(fixture.adapter)
        gpu.instance_release(fixture.instance)
        return
    }
    fixture.queue = gpu.device_get_queue(fixture.device)
    if fixture.queue == {} {
        gpu.device_release(fixture.device)
        gpu.adapter_release(fixture.adapter)
        gpu.instance_release(fixture.instance)
        return
    }
    return fixture, true
}

vk_ts_fixture_destroy :: proc(fixture: VK_TS_Fixture) {
    if fixture.queue != {} {
        gpu.queue_release(fixture.queue)
    }
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

vk_ts_flush_and_wait :: proc(fixture: VK_TS_Fixture) {
    gpu.queue_submit(fixture.queue, []gpu.Command_Buffer{})
    _ = gpu.device_poll(fixture.device, true, nil)
}

// -----------------------------------------------------------------------------
// Parallel resource creation
// -----------------------------------------------------------------------------

VK_TS_Create_Job :: struct {
    device:     gpu.Device,
    iterations: int,
    errors:     ^int,
}

vk_ts_create_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Create_Job)raw

    for _ in 0 ..< job.iterations {
        buffer := gpu.device_create_buffer(job.device, {
            size  = VK_TS_BUFFER_SIZE,
            usage = {.Copy_Dst, .Copy_Src},
            label = "thread-safety create",
        })
        if buffer == {} {
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.buffer_set_label(buffer, "thread-safety label")
        _ = gpu.buffer_get_label(buffer)
        gpu.buffer_release(buffer)

        sampler := gpu.device_create_sampler(job.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
        if sampler == {} {
            intrinsics.atomic_add(job.errors, 1)
        } else {
            gpu.sampler_release(sampler)
        }

        gpu.device_push_error_scope(job.device, .Validation)
        _ = gpu.device_pop_error_scope(job.device, {
            callback = vk_ts_pop_noop,
        })
    }
}

@(test)
test_vk_ts_parallel_creation :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    jobs: [VK_TS_THREADS]VK_TS_Create_Job
    threads: [VK_TS_THREADS]^thread.Thread
    for &job, i in jobs {
        job = {
            device     = fixture.device,
            iterations = VK_TS_ITERATIONS,
            errors     = &errors,
        }
        threads[i] = thread.create_and_start_with_poly_data(
            rawptr(&job), vk_ts_create_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {
        thread.destroy(th)
    }

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)

    vk_ts_flush_and_wait(fixture)
    device_impl := gpu.vk_device_get_impl(fixture.device)
    testing.expect_value(t, int(gpu.dhm_len(&device_impl.buffers)), 0)
    testing.expect_value(t, int(gpu.dhm_len(&device_impl.samplers)), 0)
}

// -----------------------------------------------------------------------------
// Parallel queue writes
// -----------------------------------------------------------------------------

VK_TS_Write_Job :: struct {
    device:     gpu.Device,
    queue:      gpu.Queue,
    iterations: int,
    errors:     ^int,
    source:     gpu.Buffer,
    readback:   gpu.Buffer,
    last_value: u32,
}

vk_ts_write_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Write_Job)raw

    payload: [VK_TS_BUFFER_WORDS]u32
    for i in 0 ..< job.iterations {
        value := u32(i * 131 + 7)
        for &word, index in payload {
            word = value + u32(index)
        }
        gpu.queue_write_buffer_raw(
            job.queue, job.source, 0, rawptr(&payload[0]), uint(size_of(payload)))
        job.last_value = value
    }

    encoder := gpu.device_create_command_encoder(job.device)
    if encoder == {} {
        intrinsics.atomic_add(job.errors, 1)
        return
    }
    gpu.command_encoder_copy_buffer_to_buffer(
        encoder, job.source, 0, job.readback, 0, u64(VK_TS_BUFFER_SIZE))
    cmdbuf := gpu.command_encoder_finish(encoder)
    if cmdbuf == {} {
        gpu.command_encoder_release(encoder)
        intrinsics.atomic_add(job.errors, 1)
        return
    }
    gpu.queue_submit(job.queue, []gpu.Command_Buffer{cmdbuf})
    gpu.command_buffer_release(cmdbuf)
    gpu.command_encoder_release(encoder)
}

@(test)
test_vk_ts_parallel_queue_writes :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    jobs: [VK_TS_THREADS]VK_TS_Write_Job
    threads: [VK_TS_THREADS]^thread.Thread
    defer {
        for &job in jobs {
            if job.readback != {} {
                gpu.buffer_release(job.readback)
            }
            if job.source != {} {
                gpu.buffer_release(job.source)
            }
        }
    }

    for &job, i in jobs {
        job.device = fixture.device
        job.queue = fixture.queue
        job.iterations = VK_TS_ITERATIONS
        job.errors = &errors
        job.source = gpu.device_create_buffer(fixture.device, {
            size  = VK_TS_BUFFER_SIZE,
            usage = {.Copy_Dst, .Copy_Src},
        })
        job.readback = gpu.device_create_buffer(fixture.device, {
            size  = VK_TS_BUFFER_SIZE,
            usage = {.Map_Read, .Copy_Dst},
        })
        if job.source == {} || job.readback == {} {
            return
        }
        threads[i] = thread.create_and_start_with_poly_data(
            rawptr(&job), vk_ts_write_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {
        thread.destroy(th)
    }

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)
    vk_ts_flush_and_wait(fixture)

    for job, i in jobs {
        ptr := gpu.buffer_map_sync(job.readback, .Read, 0, VK_TS_BUFFER_SIZE)
        testing.expectf(t, ptr != nil, "worker %d could not map its readback buffer", i)
        if ptr == nil {
            continue
        }

        data := cast([^]u32)ptr
        mismatch := -1
        for word, index in data[:VK_TS_BUFFER_WORDS] {
            if word != job.last_value + u32(index) {
                mismatch = index
                break
            }
        }
        testing.expectf(t, mismatch < 0,
            "worker %d readback mismatch at word %d (expected %d)", i, mismatch,
            job.last_value + u32(mismatch))
        gpu.buffer_unmap(job.readback)
    }
}

// -----------------------------------------------------------------------------
// Parallel command encoders
// -----------------------------------------------------------------------------

VK_TS_Clear_Job :: struct {
    device:     gpu.Device,
    queue:      gpu.Queue,
    iterations: int,
    errors:     ^int,
    buffer:     gpu.Buffer,
}

vk_ts_clear_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Clear_Job)raw

    for _ in 0 ..< job.iterations {
        encoder := gpu.device_create_command_encoder(job.device)
        if encoder == {} {
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.command_encoder_clear_buffer(encoder, job.buffer, 0, u64(VK_TS_BUFFER_SIZE))
        cmdbuf := gpu.command_encoder_finish(encoder)
        if cmdbuf == {} {
            gpu.command_encoder_release(encoder)
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.queue_submit(job.queue, []gpu.Command_Buffer{cmdbuf})
        gpu.command_buffer_release(cmdbuf)
        gpu.command_encoder_release(encoder)
    }
}

@(test)
test_vk_ts_parallel_encoders :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    jobs: [VK_TS_THREADS]VK_TS_Clear_Job
    threads: [VK_TS_THREADS]^thread.Thread
    defer {
        for &job in jobs {
            if job.buffer != {} {
                gpu.buffer_release(job.buffer)
            }
        }
    }

    for &job, i in jobs {
        job.device = fixture.device
        job.queue = fixture.queue
        job.iterations = VK_TS_ITERATIONS
        job.errors = &errors
        job.buffer = gpu.device_create_buffer(fixture.device, {
            size  = VK_TS_BUFFER_SIZE,
            usage = {.Map_Read, .Copy_Dst, .Copy_Src},
        })
        if job.buffer == {} {
            return
        }

        pattern: [VK_TS_BUFFER_WORDS]u32
        for &word, index in pattern {
            word = 0xA5A5_0000 + u32(index)
        }
        gpu.queue_write_buffer_raw(
            fixture.queue, job.buffer, 0, rawptr(&pattern[0]), uint(size_of(pattern)))

        threads[i] = thread.create_and_start_with_poly_data(
            rawptr(&job), vk_ts_clear_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {
        thread.destroy(th)
    }

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)
    vk_ts_flush_and_wait(fixture)

    for job, i in jobs {
        ptr := gpu.buffer_map_sync(job.buffer, .Read, 0, VK_TS_BUFFER_SIZE)
        testing.expectf(t, ptr != nil, "worker %d could not map its buffer", i)
        if ptr == nil {
            continue
        }
        data := cast([^]u8)ptr
        nonzero := -1
        for byte, index in data[:VK_TS_BUFFER_SIZE] {
            if byte != 0 {
                nonzero = index
                break
            }
        }
        bad_byte: u8
        if nonzero >= 0 {
            bad_byte = data[nonzero]
        }
        testing.expectf(t, nonzero < 0,
            "worker %d did not clear its buffer (byte %d is 0x%02x)", i, nonzero, bad_byte)
        gpu.buffer_unmap(job.buffer)
    }
}

// -----------------------------------------------------------------------------
// Concurrent use of one texture
// -----------------------------------------------------------------------------

VK_TS_Texture_Job :: struct {
    device:     gpu.Device,
    queue:      gpu.Queue,
    iterations: int,
    errors:     ^int,
    texture:    gpu.Texture,
}

vk_ts_texture_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Texture_Job)raw

    range := gpu.Image_Subresource_Range {
        aspect            = .All,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
    }

    for _ in 0 ..< job.iterations {
        encoder := gpu.device_create_command_encoder(job.device)
        if encoder == {} {
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.command_encoder_clear_texture(encoder, job.texture, range)
        cmdbuf := gpu.command_encoder_finish(encoder)
        if cmdbuf == {} {
            gpu.command_encoder_release(encoder)
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.queue_submit(job.queue, []gpu.Command_Buffer{cmdbuf})
        gpu.command_buffer_release(cmdbuf)
        gpu.command_encoder_release(encoder)
    }
}

@(test)
test_vk_ts_concurrent_texture_use :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    texture := gpu.device_create_texture(fixture.device, {
        size   = {width = 64, height = 64, depth_or_array_layers = 1},
        format = .RGBA8_Unorm,
        usage  = {.Copy_Dst, .Texture_Binding},
    })
    if texture == {} {
        return
    }
    defer gpu.texture_release(texture)

    jobs: [VK_TS_THREADS]VK_TS_Texture_Job
    threads: [VK_TS_THREADS]^thread.Thread
    for &job, i in jobs {
        job = {
            device     = fixture.device,
            queue      = fixture.queue,
            iterations = VK_TS_ITERATIONS,
            errors     = &errors,
            texture    = texture,
        }
        threads[i] = thread.create_and_start_with_poly_data(
            rawptr(&job), vk_ts_texture_worker)
    }
    thread.join_multiple(..threads[:])
    for th in threads {
        thread.destroy(th)
    }

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)
    vk_ts_flush_and_wait(fixture)
}

// -----------------------------------------------------------------------------
// Staging rings racing submissions
// -----------------------------------------------------------------------------

VK_TS_Staging_Job :: struct {
    device:     gpu.Device,
    queue:      gpu.Queue,
    iterations: int,
    errors:     ^int,
    source:     gpu.Buffer,
    readback:   gpu.Buffer,
    stop:       ^int,
    payload:    [VK_TS_BUFFER_WORDS]u32,
}

vk_ts_staging_write_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Staging_Job)raw

    for i in 0 ..< job.iterations {
        value := u32(i * 17 + 3)
        for &word, index in job.payload {
            word = value + u32(index)
        }
        gpu.queue_write_buffer_raw(
            job.queue, job.source, 0, rawptr(&job.payload[0]), uint(size_of(job.payload)))
        if i % 3 == 0 {
            gpu.queue_submit(job.queue, []gpu.Command_Buffer{})
        }
    }
    gpu.queue_submit(job.queue, []gpu.Command_Buffer{})
}

vk_ts_staging_poll_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Staging_Job)raw

    for intrinsics.atomic_load(job.stop) == 0 {
        gpu.queue_submit(job.queue, []gpu.Command_Buffer{})
        _ = gpu.device_poll(job.device, false, nil)
    }
}

@(test)
test_vk_ts_staging_vs_submit :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    job := VK_TS_Staging_Job {
        device     = fixture.device,
        queue      = fixture.queue,
        iterations = 24,
        errors     = &errors,
    }
    job.source = gpu.device_create_buffer(fixture.device, {
        size  = VK_TS_BUFFER_SIZE,
        usage = {.Copy_Dst, .Copy_Src},
    })
    job.readback = gpu.device_create_buffer(fixture.device, {
        size  = VK_TS_BUFFER_SIZE,
        usage = {.Map_Read, .Copy_Dst},
    })
    if job.source == {} || job.readback == {} {
        return
    }
    defer gpu.buffer_release(job.source)
    defer gpu.buffer_release(job.readback)

    stop: int
    job.stop = &stop

    writer := thread.create_and_start_with_poly_data(
        rawptr(&job), vk_ts_staging_write_worker)
    poller := thread.create_and_start_with_poly_data(
        rawptr(&job), vk_ts_staging_poll_worker)

    thread.join(writer)
    thread.destroy(writer)
    intrinsics.atomic_store(&stop, 1)
    thread.join(poller)
    thread.destroy(poller)

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)
    vk_ts_flush_and_wait(fixture)

    encoder := gpu.device_create_command_encoder(fixture.device)
    if encoder == {} {
        testing.expect(t, false, "failed to create the staging readback encoder")
        return
    }
    gpu.command_encoder_copy_buffer_to_buffer(
        encoder, job.source, 0, job.readback, 0, u64(VK_TS_BUFFER_SIZE))
    cmdbuf := gpu.command_encoder_finish(encoder)
    if cmdbuf == {} {
        gpu.command_encoder_release(encoder)
        testing.expect(t, false, "failed to finish the staging readback encoder")
        return
    }
    gpu.queue_submit(fixture.queue, []gpu.Command_Buffer{cmdbuf})
    gpu.command_buffer_release(cmdbuf)
    gpu.command_encoder_release(encoder)

    vk_ts_flush_and_wait(fixture)

    ptr := gpu.buffer_map_sync(job.readback, .Read, 0, VK_TS_BUFFER_SIZE)
    testing.expect(t, ptr != nil, "could not map the staging readback buffer")
    if ptr != nil {
        data := cast([^]u32)ptr
        mismatch := -1
        for word, index in data[:VK_TS_BUFFER_WORDS] {
            if word != job.payload[index] {
                mismatch = index
                break
            }
        }
        testing.expectf(t, mismatch < 0,
            "staging readback mismatch at word %d", mismatch)
        gpu.buffer_unmap(job.readback)
    }
}

// -----------------------------------------------------------------------------
// Deferred deletion under concurrent use
// -----------------------------------------------------------------------------

VK_TS_Delete_Job :: struct {
    device:     gpu.Device,
    queue:      gpu.Queue,
    iterations: int,
    errors:     ^int,
    stop:       ^int,
}

vk_ts_delete_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Delete_Job)raw

    payload := [4]u32{1, 2, 3, 4}
    for _ in 0 ..< job.iterations {
        buffer := gpu.device_create_buffer(job.device, {
            size  = 256,
            usage = {.Copy_Dst},
        })
        if buffer == {} {
            intrinsics.atomic_add(job.errors, 1)
            continue
        }
        gpu.queue_write_buffer_raw(
            job.queue, buffer, 0, rawptr(&payload[0]), uint(size_of(payload)))
        gpu.buffer_release(buffer)

        sampler := gpu.device_create_sampler(job.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
        if sampler == {} {
            intrinsics.atomic_add(job.errors, 1)
        } else {
            gpu.sampler_release(sampler)
        }
    }
}

vk_ts_delete_poll_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    job := cast(^VK_TS_Delete_Job)raw

    for intrinsics.atomic_load(job.stop) == 0 {
        gpu.queue_submit(job.queue, []gpu.Command_Buffer{})
        _ = gpu.device_poll(job.device, false, nil)
    }
}

@(test)
test_vk_ts_deferred_delete_stress :: proc(t: ^testing.T) {
    errors: int
    fixture, ok := vk_ts_fixture(&errors)
    if !ok {
        return
    }
    defer vk_ts_fixture_destroy(fixture)

    stop: int
    job := VK_TS_Delete_Job {
        device     = fixture.device,
        queue      = fixture.queue,
        iterations = 24,
        errors     = &errors,
        stop       = &stop,
    }

    workers: [VK_TS_THREADS]^thread.Thread
    for _, i in workers {
        workers[i] = thread.create_and_start_with_poly_data(
            rawptr(&job), vk_ts_delete_worker)
    }
    poller := thread.create_and_start_with_poly_data(
        rawptr(&job), vk_ts_delete_poll_worker)

    thread.join_multiple(..workers[:])
    for th in workers {
        thread.destroy(th)
    }
    intrinsics.atomic_store(&stop, 1)
    thread.join(poller)
    thread.destroy(poller)

    testing.expect_value(t, intrinsics.atomic_load(&errors), 0)

    // Deferred writes and releases are only processed by a submit, and only
    // once their pinned submission has completed. Two rounds drain both: the
    // first flushes the pending writes, the second reclaims their resources.
    for _ in 0 ..< 2 {
        gpu.queue_submit(fixture.queue, []gpu.Command_Buffer{})
        _ = gpu.device_poll(fixture.device, true, nil)
    }

    device_impl := gpu.vk_device_get_impl(fixture.device)

    // Staging rings own a buffer handle until device teardown; every other
    // buffer created by the workers must already be gone.
    live_staging_rings: int
    {
        sync.lock(&device_impl.staging_mtx)
        live_staging_rings = len(device_impl.staging_rings)
        sync.unlock(&device_impl.staging_mtx)
    }
    testing.expect_value(t, int(gpu.dhm_len(&device_impl.buffers)), live_staging_rings)
    testing.expect_value(t, int(gpu.dhm_len(&device_impl.samplers)), 0)
}
