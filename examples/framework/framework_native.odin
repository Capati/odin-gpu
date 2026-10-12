#+build !js
package application

// Core
import "base:runtime"
import "core:strings"
import "core:time"
import "core:unicode/utf8"

// Vendor
import "vendor:glfw"

OS :: struct {
    window: glfw.WindowHandle,
}

os_init :: proc(title: string, width, height: u32) {
    if !glfw.Init() {
        panic("[GLFW] init failure")
    }

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    c_title := strings.clone_to_cstring(title, ta)

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    g_ctx.os.window = glfw.CreateWindow(i32(width), i32(height), c_title, nil, nil)
    assert(g_ctx.os.window != nil)

    glfw.SetKeyCallback(g_ctx.os.window, key_callback)
    glfw.SetMouseButtonCallback(g_ctx.os.window, mouse_button_callback)
    glfw.SetCursorPosCallback(g_ctx.os.window, cursor_pos_callback)
    glfw.SetScrollCallback(g_ctx.os.window, scroll_callback)
    glfw.SetCharCallback(g_ctx.os.window, char_callback)
    glfw.SetFramebufferSizeCallback(g_ctx.os.window, size_callback)
    glfw.SetWindowIconifyCallback(g_ctx.os.window, minimized_callback)
    glfw.SetWindowFocusCallback(g_ctx.os.window, focus_callback)
}

os_quit :: proc() {
    glfw.DestroyWindow(g_ctx.os.window)
    glfw.Terminate()
}

os_run :: proc() {
    context = g_ctx.custom_ctx
    defer quit()

    last_time := glfw.GetTime()
    target_fps := g_ctx.desc.target_fps
    for !glfw.WindowShouldClose(g_ctx.os.window) {
        glfw.PollEvents()

        current_time := glfw.GetTime()
        delta := f32(current_time - last_time)
        last_time = current_time

        if !iterate_frame(delta) {
            glfw.SetWindowShouldClose(g_ctx.os.window, true)
            break
        }

        // Time-based frame pacing (opt-in via target_fps; 0 = uncapped).
        // Sleeps the remainder of the frame budget so mailbox doesn't spin
        // the GPU at full rate. Web gets this free from the browser compositor.
        if target_fps > 0 {
            budget := 1.0 / f64(target_fps)
            elapsed := glfw.GetTime() - current_time
            if wait := budget - elapsed; wait > 0 {
                time.sleep(auto_cast (wait * 1_000_000_000))
            }
        }
    }
}

get_framebuffer_size :: proc() -> (width, height: u32) {
    iw, ih := glfw.GetFramebufferSize(g_ctx.os.window)
    return u32(iw), u32(ih)
}

get_time :: proc() -> f32 {
    return f32(glfw.GetTime())
}

hide_window :: proc() {
    glfw.HideWindow(g_ctx.os.window)
}

@(private="file")
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = g_ctx.custom_ctx
    g_ctx.width = u32(width)
    g_ctx.height = u32(height)
    dispatch_event(Resize_Event{ g_ctx.width, g_ctx.height })
}

@(private="file")
key_callback :: proc "c" (handle: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = g_ctx.custom_ctx

    event := Key_Event {
        key      = to_key(key),
        scancode = to_scancode(scancode),
        action   = to_input_action(action),
        ctrl     = mods & glfw.MOD_CONTROL != 0,
        shift    = mods & glfw.MOD_SHIFT != 0,
        alt      = mods & glfw.MOD_ALT != 0,
    }

    dispatch_event(event)
}

@(private="file")
mouse_button_callback :: proc "c" (handle: glfw.WindowHandle, button, action, mods: i32) {
    context = g_ctx.custom_ctx

    xpos, ypos := glfw.GetCursorPos(handle)

    event := Mouse_Button_Event {
        button = to_mouse_button(button),
        pos    = {f32(xpos), f32(ypos)},
        action   = to_input_action(action),
    }

    dispatch_event(event)
}

@(private="file")
to_mouse_button :: proc(button: i32) -> Mouse_Button {
    switch button {
    case glfw.MOUSE_BUTTON_LEFT:   return .Left
    case glfw.MOUSE_BUTTON_MIDDLE: return .Middle
    case glfw.MOUSE_BUTTON_RIGHT:  return .Right
    case glfw.MOUSE_BUTTON_4:      return .Four
    case glfw.MOUSE_BUTTON_5:      return .Five
    case:
        return .Unknown
    }
}

@(private="file")
cursor_pos_callback :: proc "c" (handle: glfw.WindowHandle, xpos, ypos: f64) {
    context = g_ctx.custom_ctx

    dispatch_event(Mouse_Motion_Event{
        pos = {f32(xpos), f32(ypos)},
    })
}

@(private="file")
scroll_callback :: proc "c" (handle: glfw.WindowHandle, xoffset, yoffset: f64) {
    context = g_ctx.custom_ctx
    event := Mouse_Wheel_Event{ f32(xoffset), f32(yoffset) }
    dispatch_event(event)
}

@(private="file")
char_callback :: proc "c" (window: glfw.WindowHandle, ch: rune) {
    context = g_ctx.custom_ctx
    bytes, size := utf8.encode_rune(ch)
    dispatch_event(Char_Event{ bytes, size })
}

@(private="file")
minimized_callback :: proc "c" (handle: glfw.WindowHandle, iconified: i32) {
    context = g_ctx.custom_ctx
    g_ctx.is_minimized = bool(iconified)
    dispatch_event(Minimized_Event{ g_ctx.is_minimized })
}

@(private="file")
focus_callback :: proc "c" (handle: glfw.WindowHandle, focused: i32) {
    context = g_ctx.custom_ctx
    dispatch_event(Restored_Event{bool(focused)})
}
