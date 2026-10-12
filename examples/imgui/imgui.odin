/*
Example - ImGui Example

This example demonstrates how to use Dear ImGui to create graphical user interfaces.
*/
#+build !js
package template_example

// Core
import "core:log"
import "core:mem"

// Vendor
import "../../gpu"
import app "../framework"
import im "../../utils/imgui"
import imglfw "../../utils/imgui/backends/glfw"
import imr "../../utils/imgui/renderer" /* imgui renderer */

TITLE :: "ImGui"

State :: struct {
    show_demo_window: bool,
    show_another_window: bool,
    clear_color: [3]f32,
    rpass:       struct {
        colors:     [1]gpu.Render_Pass_Color_Attachment,
        descriptor: gpu.Render_Pass_Descriptor,
    },
}

state: State

init_imgui :: proc(ctx: ^app.Application) -> bool {
    // Setup Dear ImGui context
    im.CHECKVERSION()
    im.CreateContext()
    io := im.GetIO()
    io.ConfigFlags |= {
        .NavEnableKeyboard, // Enable Keyboard Controls
        .NavEnableGamepad,  // Enable Gamepad Controls
        .DockingEnable,     // Enable Docking
        .ViewportsEnable,   // Enable Multi-Viewport / Platform Windows
    }

    // io.ConfigViewportsNoAutoMerge = true
    // io.ConfigViewportsNoTaskBarIcon = true

    // Setup Dear ImGui style
    im.StyleColorsDark()
    // im.StyleColorsLight()

    // Setup scaling
    style := im.GetStyle()
    // Bake a fixed style scale. (until we have a solution for dynamic style
    // scaling, changing this requires resetting Style + calling this again)
    im.Style_ScaleAllSizes(style, 1.0)
    // Set initial font scale. (in docking branch: using
    // io.ConfigDpiScaleFonts=true automatically overrides this for every window
    // depending on the current monitor)
    style.FontScaleDpi = 1.0
    // [Experimental] Automatically overwrite style.FontScaleDpi in Begin() when
    // Monitor DPI changes. This will scale fonts but _NOT_ scale sizes/padding
    // for now.
    io.ConfigDpiScaleFonts = true
    // [Experimental] Scale Dear ImGui and Platform Windows when Monitor DPI changes.
    io.ConfigDpiScaleViewports = true

    // When viewports are enabled we tweak WindowRounding/WindowBg so platform
    // windows can look identical to regular ones.
    if .ViewportsEnable in io.ConfigFlags {
        style.WindowRounding = 0.0
        style.Colors[im.Col.WindowBg].w = 1.0
    }

    // Setup Platform/Renderer backends
    imglfw.InitForOther(ctx.os.window, install_callbacks = true)

    imr.init({
        device                     = ctx.device,
        num_frames_in_flight       = 2,
        render_target_format       = ctx.render_format,
        depth_stencil_format       = .Undefined,
        pipeline_multisample_state = {count = 1, mask = max(u32)},
    }) or_return

    return true
}

init :: proc(ctx: ^app.Application) -> (ok: bool) {
    state.rpass.colors[0] = gpu.DEFAULT_RENDER_PASS_COLOR_ATTACHMENT
    state.rpass.colors[0].ops = {
        load        = .Clear,
        store       = .Store,
        clear_value = gpu.COLOR_BLACK,
    }

    state.rpass.descriptor = {
        label             = "Render Pass - " + TITLE,
        color_attachments = state.rpass.colors[:],
    }

    init_imgui(ctx) or_return

    // Default state
    state.show_demo_window = true
    state.clear_color = {0.45, 0.55, 0.60}
    set_clear_value(ctx, state.clear_color)

    return true
}

quit :: proc(ctx: ^app.Application) {
    imr.shutdown()
    imglfw.Shutdown()
    im.DestroyContext()
}

set_clear_value :: proc(ctx: ^app.Application, clear_color: [3]f32) {
    r, g, b := expand_values(clear_color)
    state.rpass.colors[0].ops.clear_value = {f64(r), f64(g), f64(b), 1.0}
}

update :: proc(ctx: ^app.Application, dt: f32) {
    // Start the Dear ImGui frame
    imr.new_frame()
    imglfw.NewFrame()
    im.NewFrame()

    io := im.GetIO()

    // 1. Show the big demo window (Most of the sample code is in
    //    im.ShowDemoWindow()! You can browse its code to learn more about
    //    Dear ImGui!).
    if state.show_demo_window {
        im.ShowDemoWindow(&state.show_demo_window)
    }

    // 2. Show a simple window that we create ourselves. We use a Begin/End
    //    pair to create a named window.
    {
        @static f: f32
        @static counter: i32

        // Create a window called "Hello, world!" and append into it.
        im.Begin("Hello, world!")

        // Display some text (you can use a format strings too)
        im.Text("This is some useful text.")
        // Edit bools storing our window open/close state
        im.Checkbox("Demo Window", &state.show_demo_window)
        im.Checkbox("Another Window", &state.show_another_window)

        // Edit 1 float using a slider from 0.0f to 1.0f
        im.SliderFloat("float", &f, 0.0, 1.0)
        // Edit 3 floats representing a color
        if im.ColorEdit3("clear color", &state.clear_color) {
            set_clear_value(ctx, state.clear_color)
        }

        // Buttons return true when clicked (most widgets return true when
        // edited/activated)
        if im.Button("Button") {
            counter += 1
        }
        im.SameLine()
        im.Text("counter = %d", counter)

        im.Text("Application average %.3f ms/frame (%.1f FPS)",
            1000.0 / io.Framerate, io.Framerate)
        im.End()
    }

    // 3. Show another simple window.
    if state.show_another_window {
        // Pass a pointer to our bool variable (the window will have a
        // closing button that will clear the bool when clicked)
        im.Begin("Another Window", &state.show_another_window)
        im.Text("Hello from another window!")
        if im.Button("Close Me") {
            state.show_another_window = false
        }
        im.End()
    }

    // Rendering
    im.Render()

    // Update and Render additional Platform Windows
    if .ViewportsEnable in io.ConfigFlags {
        im.UpdatePlatformWindows()
        im.RenderPlatformWindowsDefault()
    }
}

iterate :: proc(ctx: ^app.Application, dt: f32) -> (ok: bool) {
    update(ctx, dt)

    frame := app.get_current_frame()
    if frame.skip { return true }
    defer app.release_current_frame(&frame)

    state.rpass.colors[0].view = frame.view

    encoder := gpu.device_create_command_encoder(ctx.device)
    defer gpu.command_encoder_release(encoder)

    rpass := gpu.command_encoder_begin_render_pass(encoder, state.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    imr.render_draw_data(im.GetDrawData(), rpass)

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(ctx.queue, {cmdbuf})
    gpu.surface_texture_present(frame)

    return true
}

event :: proc(ctx: ^app.Application, event: app.Event) {
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(
            lowest = .Debug,
            opt = {.Level, .Terminal_Color},
        )
        defer log.destroy_console_logger(context.logger)

        when ODIN_OS != .JS {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)

            defer {
                if len(track.allocation_map) > 0 {
                    log.errorf("=== %v allocations not freed: ===", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        log.warnf("- %v bytes @ %v", entry.size, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }
    }

    // Initialize framework and run application
    app.run(app.Application_Descriptor{
        title      = TITLE,
        init_cb    = init,
        iterate_cb = iterate,
        quit_cb    = quit,
        event_cb   = event,
    })
}
