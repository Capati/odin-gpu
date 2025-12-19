#+build !js
package framework

// Core
import "base:runtime"
import "core:strings"
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
    ctx.os.window = glfw.CreateWindow(i32(width), i32(height), c_title, nil, nil)
    assert(ctx.os.window != nil)

    glfw.SetKeyCallback(ctx.os.window, key_callback)
    glfw.SetMouseButtonCallback(ctx.os.window, mouse_button_callback)
    glfw.SetCursorPosCallback(ctx.os.window, cursor_pos_callback)
    glfw.SetScrollCallback(ctx.os.window, scroll_callback)
    glfw.SetCharCallback(ctx.os.window, char_callback)
    glfw.SetFramebufferSizeCallback(ctx.os.window, size_callback)
    glfw.SetWindowIconifyCallback(ctx.os.window, minimized_callback)
    glfw.SetWindowFocusCallback(ctx.os.window, focus_callback)
}

os_fini :: proc() {
    glfw.DestroyWindow(ctx.os.window)
    glfw.Terminate()
    destroy()
}

run :: proc() {
    context = ctx.custom_ctx

    last_time := glfw.GetTime()
    for !glfw.WindowShouldClose(ctx.os.window) {
        glfw.PollEvents()

        current_time := glfw.GetTime()
        delta := f32(current_time - last_time)
        last_time = current_time

        if iterate_proc != nil {
            if res := iterate_proc(ctx.appstate, delta); res != .Continue {
                glfw.SetWindowShouldClose(ctx.os.window, true)
                break
            }
        }
    }

    os_fini()
}

get_framebuffer_size :: proc() -> (width, height: u32) {
    iw, ih := glfw.GetFramebufferSize(ctx.os.window)
    return u32(iw), u32(ih)
}

get_time :: proc() -> f32 {
    return f32(glfw.GetTime())
}

@(private="file")
size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = ctx.custom_ctx
    dispatch_event(Resize_Event{ u32(width), u32(height) })
}

@(private="file")
key_callback :: proc "c" (handle: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = ctx.custom_ctx

    event := Key_Event {
        key      = to_key(key),
        scancode = to_scancode(scancode),
        ctrl     = mods & glfw.MOD_CONTROL != 0,
        shift    = mods & glfw.MOD_SHIFT != 0,
        alt      = mods & glfw.MOD_ALT != 0,
    }

    if action == glfw.PRESS {
        dispatch_event(Key_Pressed_Event(event))
    } else {
        dispatch_event(Key_Released_Event(event))
    }
}

@(private="file")
mouse_button_callback :: proc "c" (handle: glfw.WindowHandle, button, action, mods: i32) {
    context = ctx.custom_ctx

    xpos, ypos := glfw.GetCursorPos(handle)

    event := Mouse_Button_Event {
        button = Mouse_Button(button),
        pos    = {f32(xpos), f32(ypos)},
    }

    if action == glfw.PRESS {
        dispatch_event(Mouse_Button_Pressed_Event(event))
    } else if action == glfw.RELEASE {
        dispatch_event(Mouse_Button_Released_Event(event))
    }
}

@(private="file")
cursor_pos_callback :: proc "c" (handle: glfw.WindowHandle, xpos, ypos: f64) {
    context = ctx.custom_ctx

    action: Input_Action
    button: Mouse_Button

    if glfw.GetMouseButton(handle, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
        button = .Left
        action = .Pressed
    } else if glfw.GetMouseButton(handle, glfw.MOUSE_BUTTON_MIDDLE) == glfw.PRESS {
        button = .Middle
        action = .Pressed
    } else if glfw.GetMouseButton(handle, glfw.MOUSE_BUTTON_RIGHT) == glfw.PRESS {
        button = .Right
        action = .Pressed
    } else if glfw.GetMouseButton(handle, glfw.MOUSE_BUTTON_4) == glfw.PRESS {
        button = .Four
        action = .Pressed
    } else if glfw.GetMouseButton(handle, glfw.MOUSE_BUTTON_5) == glfw.PRESS {
        button = .Five
        action = .Pressed
    }

    dispatch_event(Mouse_Moved_Event{
        pos = {f32(xpos), f32(ypos)},
        button = button,
        action = action,
    })
}

@(private="file")
scroll_callback :: proc "c" (handle: glfw.WindowHandle, xoffset, yoffset: f64) {
    context = ctx.custom_ctx
    dispatch_event(Mouse_Wheel_Event{f32(xoffset), f32(yoffset)})
}

@(private="file")
char_callback :: proc "c" (window: glfw.WindowHandle, ch: rune) {
    context = ctx.custom_ctx
    bytes, size := utf8.encode_rune(ch)
    dispatch_event(Char_Event{ bytes, size })
}

@(private="file")
minimized_callback :: proc "c" (handle: glfw.WindowHandle, iconified: i32) {
    context = ctx.custom_ctx
    ctx.is_minimized = bool(iconified)
    dispatch_event(Minimized_Event{ ctx.is_minimized })
}

@(private="file")
focus_callback :: proc "c" (handle: glfw.WindowHandle, focused: i32) {
    context = ctx.custom_ctx
    dispatch_event(Restored_Event{bool(focused)})
}
