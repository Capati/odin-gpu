#+build !js
/*
Example - Threaded Upload

Worker threads create buffers and textures and upload through the queue while
the main thread records and presents frames. It is a live stress test for the
backend's thread safety: any validation error is counted and traps at shutdown.
*/
package threaded_upload

// Core
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:thread"
import "core:time"

// Local packages
import "../../gpu"
import app "../framework"

TITLE         :: "Threaded Upload"
CLIENT_WIDTH  :: 640
CLIENT_HEIGHT :: 480

// Each worker sleeps between iterations so uploads interleave with frames
// instead of starving the render thread. Keep this modest: with the validation
// layer enabled, a tight creation loop can monopolize it and stall the frame
// loop. The heavier stress lives in `tests/vulkan/vk_thread_safety_tests.odin`.
WORKER_COUNT    :: #config(THREADED_UPLOAD_WORKERS, 2)
UPLOAD_INTERVAL :: 8 * time.Millisecond

BUFFER_SIZE  :: 4096
TEXTURE_SIZE :: 64
TEXTURE_PITCH :: 256

g_errors: int
g_writes: u64
g_stop:   int

Upload_Worker :: struct {
    device: gpu.Device,
    queue:  gpu.Queue,
    id:     int,
}

State :: struct {
    rpass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
    workers:     [WORKER_COUNT]Upload_Worker,
    threads:     [WORKER_COUNT]^thread.Thread,
    frame_count: u64,
    last_report: time.Tick,
}

state: State

upload_error_callback :: proc "contextless" (
    device: ^gpu.Device,
    type: gpu.Error_Type,
    message: string,
    userdata1, userdata2: rawptr,
) {
    intrinsics.atomic_add(&g_errors, 1)
}

upload_worker :: proc(raw: rawptr) {
    context = runtime.default_context()
    worker := cast(^Upload_Worker)raw

    payload: [BUFFER_SIZE]u8
    texture_data: [TEXTURE_SIZE * TEXTURE_PITCH]u8
    for &byte, index in payload {
        byte = u8(index * 37 + worker.id)
    }
    for &byte, index in texture_data {
        byte = u8(index * 11 + worker.id)
    }

    iteration := 0
    for intrinsics.atomic_load(&g_stop) == 0 {
        buffer := gpu.device_create_buffer(worker.device, {
            label = "threaded upload buffer",
            size  = BUFFER_SIZE,
            usage = {.Copy_Dst},
        })
        if buffer != {} {
            gpu.buffer_set_label(buffer, "threaded upload buffer")
            gpu.queue_write_buffer_raw(
                worker.queue, buffer, 0, rawptr(&payload[0]), uint(size_of(payload)))
            gpu.buffer_release(buffer)
            intrinsics.atomic_add(&g_writes, 1)
        } else {
            intrinsics.atomic_add(&g_errors, 1)
        }

        if iteration % 16 == 0 {
            texture := gpu.device_create_texture(worker.device, {
                label  = "threaded upload texture",
                size   = {width = TEXTURE_SIZE, height = TEXTURE_SIZE, depth_or_array_layers = 1},
                format = .RGBA8_Unorm,
                usage  = {.Copy_Dst},
            })
            if texture != {} {
                gpu.texture_set_label(texture, "threaded upload texture")
                gpu.queue_write_texture(
                    worker.queue,
                    {texture = texture, aspect = .All},
                    texture_data[:],
                    {bytes_per_row = TEXTURE_PITCH, rows_per_image = TEXTURE_SIZE},
                    {TEXTURE_SIZE, TEXTURE_SIZE, 1},
                )
                gpu.texture_release(texture)
            } else {
                intrinsics.atomic_add(&g_errors, 1)
            }
        }

        if iteration % 32 == 0 {
            sampler := gpu.device_create_sampler(
                worker.device, gpu.DEFAULT_SAMPLER_DESCRIPTOR)
            if sampler != {} {
                gpu.sampler_release(sampler)
            } else {
                intrinsics.atomic_add(&g_errors, 1)
            }
        }

        iteration += 1
        time.sleep(UPLOAD_INTERVAL)
    }
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    gpu.device_set_uncaptured_error_callback(ctx.device, {
        callback = upload_error_callback,
    })

    state.rpass.colors[0] = {
        view        = {},
        depth_slice = gpu.DEPTH_SLICE_UNDEFINED,
        ops         = {.Clear, .Store, {0.05, 0.07, 0.12, 1.0}},
    }
    state.rpass.descriptor = {
        label             = "Threaded upload render pass",
        color_attachments = state.rpass.colors[:],
    }

    state.last_report = time.tick_now()

    for &worker, i in state.workers {
        worker = {
            device = ctx.device,
            queue  = ctx.queue,
            id     = i,
        }
        state.threads[i] = thread.create_and_start_with_poly_data(
            rawptr(&worker), upload_worker)
    }

    return true
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    frame := app.get_current_frame()
    if frame.skip {
        return true
    }
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_present(ctx.surface)

    // Drain deferred deletions periodically. Polling every frame is not needed
    // (the submit above already flushes writes) and adds lock traffic.
    state.frame_count += 1
    if state.frame_count % 4 == 0 {
        _ = gpu.device_poll(ctx.device, false, nil)
    }

    if time.tick_since(state.last_report) >= 1 * time.Second {
        state.last_report = time.tick_now()
        fmt.printfln(
            "THREADED_UPLOAD writes=%d errors=%d",
            intrinsics.atomic_load(&g_writes),
            intrinsics.atomic_load(&g_errors))
    }

    return true
}

quit :: proc(ctx: ^app.Application) {
    intrinsics.atomic_store(&g_stop, 1)
    for th in state.threads {
        if th != nil {
            thread.join(th)
            thread.destroy(th)
        }
    }

    _ = gpu.device_poll(ctx.device, true, nil)

    writes := intrinsics.atomic_load(&g_writes)
    errors := intrinsics.atomic_load(&g_errors)
    fmt.printfln("THREADED_UPLOAD PASS writes=%d errors=%d", writes, errors)
    ensure(errors == 0, "threaded upload reported errors")
}

event :: proc(ctx: ^app.Application, event: app.Event) {
}

main :: proc() {
    app.run(app.Application_Descriptor{
        title      = TITLE,
        width      = CLIENT_WIDTH,
        height     = CLIENT_HEIGHT,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
