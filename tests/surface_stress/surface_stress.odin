// Multithreaded Vulkan surface lifecycle stress test, standalone: no
// example framework involved. Creates its own window, device and surface
// directly through gpu plus GLFW. Worker threads repeatedly unconfigure and
// reconfigure the surface while the main thread renders and presents.
// Exits on its own with an explicit PASS line.
#+build windows
package main

// Core
import "core:fmt"
import "core:os"
import "core:strings"
import "core:thread"

import intr "base:intrinsics"
import win32 "core:sys/windows"

// Vendor
import "vendor:glfw"

// Local
import "../../gpu"

TITLE  :: "Vulkan Surface Stress"
WIDTH  :: 640
HEIGHT :: 480

SURFACE_STRESS_THREADS                 :: 3
SURFACE_STRESS_RECONFIGURES_PER_THREAD :: 8
SURFACE_STRESS_REQUIRED_FRAMES         :: 12

Stress_Job :: struct {
    surface:    gpu.Surface,
    config:     gpu.Surface_Configuration,
    operations: ^int,
    remaining:  ^int,
}

Stress_State :: struct {
    instance: gpu.Instance,
    adapter:  gpu.Adapter,
    device:   gpu.Device,
    queue:    gpu.Queue,
    surface:  gpu.Surface,
    config:   gpu.Surface_Configuration,
    window:   glfw.WindowHandle,
    render_pass: struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
    jobs:             [SURFACE_STRESS_THREADS]Stress_Job,
    workers:          [SURFACE_STRESS_THREADS]^thread.Thread,
    worker_count:     int,
    operations:       int,
    remaining:        int,
    frames:           int,
    no_draw_frames:   int,
    abandoned_encoders: int,
    abandoned_command_buffers: int,
    workers_started:  bool,
}

state: Stress_State

stress_reconfigure_worker :: proc(raw: rawptr) {
    job := cast(^Stress_Job)raw
    for _ in 0 ..< SURFACE_STRESS_RECONFIGURES_PER_THREAD {
        gpu.surface_unconfigure(job.surface)
        gpu.surface_configure(job.surface, job.config)
        intr.atomic_add(job.operations, 2)
    }
    intr.atomic_add(job.remaining, -1)
}

setup_window :: proc() -> glfw.WindowHandle {
    if !glfw.Init() {
        fmt.eprintln("surface_stress: glfw.Init failed")
        return nil
    }

    ta := context.temp_allocator
    c_title := strings.clone_to_cstring(TITLE, ta)

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    window := glfw.CreateWindow(i32(WIDTH), i32(HEIGHT), c_title, nil, nil)
    assert(window != nil)
    return window
}

setup_device :: proc(window: glfw.WindowHandle) -> bool {
    instance_descriptor: gpu.Instance_Descriptor
    when ODIN_DEBUG {
        instance_descriptor.flags = {.Debug, .Validation}
    }
    instance := gpu.create_instance(context.allocator, instance_descriptor)
    if instance == {} {
        fmt.eprintln("surface_stress: instance creation failed")
        return false
    }

    surface := gpu.instance_create_surface(instance, {
        label  = TITLE,
        source = gpu.Surface_Source_Windows_HWND {
            hinstance = win32.GetModuleHandleW(nil),
            hwnd      = glfw.GetWin32Window(window),
        },
    })
    if surface == {} {
        fmt.eprintln("surface_stress: surface creation failed")
        return false
    }

    // Native instances are Vulkan-only, so no backend filter is needed.
    adapter := gpu.instance_create_adapter(instance, {
        power_preference       = .High_Performance,
        force_fallback_adapter = false,
        compatible_surface     = surface,
    })
    if adapter == {} {
        fmt.eprintln("surface_stress: no compatible adapter")
        return false
    }

    caps := gpu.surface_get_capabilities(surface, adapter)
    if len(caps.formats) == 0 {
        fmt.eprintln("surface_stress: surface has no formats")
        return false
    }
    format := caps.formats[0]
    present_mode := gpu.Present_Mode.Fifo
    for m in caps.present_modes {
        if m == .Mailbox {
            present_mode = m
            break
        }
    }
    gpu.surface_capabilities_free_members(caps)

    device := gpu.adapter_create_device(adapter, {
        required_limits = gpu.DEFAULT_DOWNLEVEL_LIMITS,
        default_queue   = {},
    })
    if device == {} {
        fmt.eprintln("surface_stress: device creation failed")
        return false
    }
    queue := gpu.device_get_queue(device)
    if queue == {} {
        fmt.eprintln("surface_stress: no default queue")
        return false
    }

    width, height := framebuffer_size(window)
    state.config = gpu.Surface_Configuration {
        device                        = device,
        usage                         = {.Render_Attachment},
        format                        = format,
        width                         = width,
        height                        = height,
        present_mode                  = present_mode,
        desired_maximum_frame_latency = 2,
        alpha_mode                    = .Opaque,
    }
    gpu.surface_configure(surface, state.config)

    state.window = window
    state.instance = instance
    state.adapter = adapter
    state.device = device
    state.queue = queue
    state.surface = surface
    return true
}

framebuffer_size :: proc(window: glfw.WindowHandle) -> (width, height: u32) {
    iw, ih := glfw.GetFramebufferSize(window)
    return u32(iw), u32(ih)
}

start_stress_workers :: proc() {
    state.remaining = SURFACE_STRESS_THREADS
    for i in 0 ..< SURFACE_STRESS_THREADS {
        state.jobs[i] = Stress_Job{
            surface = state.surface,
            config = state.config,
            operations = &state.operations,
            remaining = &state.remaining,
        }
        state.workers[i] = thread.create_and_start_with_poly_data(
            rawptr(&state.jobs[i]), stress_reconfigure_worker)
    }
    state.worker_count = SURFACE_STRESS_THREADS
    state.workers_started = true
}

iterate :: proc() -> bool {
    tex := gpu.surface_get_current_texture(state.surface)
    if tex.status != .Success {
        if tex.texture != {} {
            gpu.texture_release(tex.texture)
        }
        return true
    }
    view := gpu.texture_create_view(tex.texture)

    // Start while a real surface image is acquired. Reconfigure/unconfigure
    // workers must wait for this frame's present before replacing its swapchain.
    if !state.workers_started {
        start_stress_workers()
    }

    switch state.frames % 4 {
    case 0:
        // Deliberately do not create an encoder. Present must still consume the
        // acquire semaphore and leave this image in PRESENT_SRC_KHR.
        state.no_draw_frames += 1
    case 1:
        // Abandon an encoder with an open render pass.
        encoder := gpu.device_create_command_encoder(state.device)
        state.render_pass.colors[0].view = view
        pass := gpu.command_encoder_begin_render_pass(encoder, state.render_pass.descriptor)
        gpu.render_pass_release(pass)
        gpu.command_encoder_release(encoder)
        state.abandoned_encoders += 1
        state.no_draw_frames += 1
    case 2:
        // Finish an encoder but abandon its command buffer without submitting.
        encoder := gpu.device_create_command_encoder(state.device)
        state.render_pass.colors[0].view = view
        pass := gpu.command_encoder_begin_render_pass(encoder, state.render_pass.descriptor)
        gpu.render_pass_end(pass)
        gpu.render_pass_release(pass)
        command_buffer := gpu.command_encoder_finish(encoder)
        gpu.command_buffer_release(command_buffer)
        gpu.command_encoder_release(encoder)
        state.abandoned_command_buffers += 1
        state.no_draw_frames += 1
    case 3:
        encoder := gpu.device_create_command_encoder(state.device)
        defer gpu.command_encoder_release(encoder)

        state.render_pass.colors[0].view = view
        pass := gpu.command_encoder_begin_render_pass(encoder, state.render_pass.descriptor)
        defer gpu.render_pass_release(pass)
        gpu.render_pass_end(pass)

        command_buffer := gpu.command_encoder_finish(encoder)
        defer gpu.command_buffer_release(command_buffer)
        gpu.queue_submit(state.queue, {command_buffer})

        // Release our view reference before present wakes a reconfiguration
        // worker. The command-buffer tracker keeps it alive through GPU completion.
        gpu.texture_view_release(view)
        gpu.texture_release(tex.texture)
        gpu.surface_texture_present(tex)
    }

    if state.frames%4 != 3 {
        // The abandonment paths must cancel their acquired command buffer before
        // presenting the frame with the internal fallback command buffer.
        gpu.texture_view_release(view)
        gpu.texture_release(tex.texture)
        gpu.surface_texture_discard(tex)
    }

    state.frames += 1
    return intr.atomic_load(&state.remaining) != 0 ||
        state.frames < SURFACE_STRESS_REQUIRED_FRAMES
}

teardown :: proc(window: glfw.WindowHandle) {
    if state.workers_started {
        thread.join_multiple(..state.workers[:state.worker_count])
        for worker in state.workers[:state.worker_count] {
            thread.destroy(worker)
        }
    }

    expected_operations := SURFACE_STRESS_THREADS * SURFACE_STRESS_RECONFIGURES_PER_THREAD * 2
    if state.frames < SURFACE_STRESS_REQUIRED_FRAMES || state.operations != expected_operations {
        fmt.printfln(
            "SURFACE_STRESS FAIL frames=%d operations=%d no_draws=%d abandoned_encoders=%d abandoned_command_buffers=%d expected_operations=%d",
            state.frames,
            state.operations,
            state.no_draw_frames,
            state.abandoned_encoders,
            state.abandoned_command_buffers,
            expected_operations,
        )
    } else {
        fmt.printfln(
            "SURFACE_STRESS PASS frames=%d operations=%d no_draws=%d abandoned_encoders=%d abandoned_command_buffers=%d",
            state.frames,
            state.operations,
            state.no_draw_frames,
            state.abandoned_encoders,
            state.abandoned_command_buffers,
        )
    }
    os.flush(os.stdout)

    gpu.adapter_release(state.adapter)
    gpu.surface_release(state.surface)
    gpu.queue_release(state.queue)
    gpu.device_release(state.device)
    gpu.instance_release(state.instance)

    glfw.DestroyWindow(window)
    glfw.Terminate()
}

main :: proc() {
    window := setup_window()
    if window == nil {
        os.exit(1)
    }

    if !setup_device(window) {
        glfw.DestroyWindow(window)
        glfw.Terminate()
        os.exit(1)
    }

    state.render_pass.colors[0] = {
        ops = { .Clear, .Store, gpu.COLOR_BLUE },
    }
    state.render_pass.descriptor = {
        label = "Surface stress pass",
        color_attachments = state.render_pass.colors[:],
    }

    for intr.atomic_load(&state.remaining) != 0 || state.frames < SURFACE_STRESS_REQUIRED_FRAMES {
        glfw.PollEvents()
        if glfw.WindowShouldClose(window) {
            break
        }
        if !iterate() {
            break
        }
    }

    teardown(window)
}
