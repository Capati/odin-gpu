#+build js
package framework

// Core
import "core:time"
import "core:sys/wasm/js"

CANVAS_ID_DEFAULT :: #config(CANVAS_ID, "#canvas")

OS :: struct {
    start_time:  time.Time,
    canvas_id:   string,
    initialized: bool,
}

os_init :: proc(title: string, width, height: u32) {
	ctx.os.canvas_id = CANVAS_ID_DEFAULT
	ctx.os.start_time = time.now()
	id := string(ctx.os.canvas_id[1:]) // remove the #
    assert(js.add_window_event_listener(.Key_Down, nil, key_callback))
	assert(js.add_window_event_listener(.Key_Up, nil, key_callback))
	assert(js.add_window_event_listener(.Mouse_Down, nil, mouse_button_callback))
	assert(js.add_window_event_listener(.Mouse_Up, nil, mouse_button_callback))
	assert(js.add_event_listener(id, .Mouse_Move, nil, mouse_move_callback))
	assert(js.add_window_event_listener(.Wheel, nil, scroll_callback))
	assert(js.add_window_event_listener(.Resize,   nil, size_callback))
}

os_fini :: proc() {
	id := string(ctx.os.canvas_id[1:]) // remove the #
	js.remove_window_event_listener(.Key_Down, nil, key_callback)
	js.remove_window_event_listener(.Key_Up, nil, key_callback)
	js.remove_window_event_listener(.Mouse_Down, nil, mouse_button_callback)
	js.remove_window_event_listener(.Mouse_Up, nil, mouse_button_callback)
	js.remove_event_listener(id, .Mouse_Move, nil, mouse_move_callback)
	js.remove_window_event_listener(.Wheel, nil, scroll_callback)
	js.remove_window_event_listener(.Resize,   nil, size_callback)
    destroy()
}

// NOTE: frame loop is done by the runtime.js repeatedly calling `step`.
run :: proc() {
	ctx.os.initialized = true
}

@(private="file", export)
step :: proc(dt: f32) -> bool {
	context = ctx.custom_ctx

	if !ctx.os.initialized {
		return true
	}

    if iterate_proc != nil {
        if res := iterate_proc(ctx.appstate, dt); res != .Continue {
            return false
        }
    }

	return true
}

get_framebuffer_size :: proc() -> (width, height: u32) {
    rect := js.get_bounding_client_rect("body")
	dpi := get_dpi()
	return u32(f32(rect.width) * dpi), u32(f32(rect.height) * dpi)
}

get_dpi :: proc() -> f32 {
	ratio := f32(js.device_pixel_ratio())
	return ratio
}

get_time :: proc() -> f32 {
    return f32(time.duration_seconds(time.since(ctx.os.start_time)))
}

@(private="file")
key_callback :: proc(event: js.Event) {
    key := to_key(event.key.key)

    ev := Key_Event{
        key      = key,
        scancode = Scancode(to_scancode(event.key.code)),
        ctrl     = event.key.ctrl,
        shift    = event.key.shift,
        alt      = event.key.alt,
    }

    #partial switch event.kind {
    case .Key_Down:
        dispatch_event(Key_Pressed_Event(ev))
    case .Key_Up:
        dispatch_event(Key_Released_Event(ev))
    }
}

@(private="file")
mouse_button_callback :: proc(event: js.Event) {
    dpi := js.device_pixel_ratio()

    pos := [2]f32 {
        cast(f32)(f64(event.mouse.offset.x) * dpi),
        cast(f32)(f64(event.mouse.offset.y) * dpi),
    }

    button: Mouse_Button
    switch event.mouse.button {
    case 0: button = .Left
    case 1: button = .Middle
    case 2: button = .Right
    case: button = .Left // fallback
    }

    #partial switch event.kind {
    case .Mouse_Down, .Click:
        dispatch_event(Mouse_Button_Pressed_Event{button = button, pos = pos})
    case .Mouse_Up:
        dispatch_event(Mouse_Button_Released_Event{button = button, pos = pos})
    }
}

@(private="file")
mouse_move_callback :: proc(event: js.Event) {
    dpi := js.device_pixel_ratio()

    // Determine which buttons are currently pressed using button bit set
    button: Mouse_Button = .Unknown
    action: Input_Action = .None

    if 0 in event.mouse.buttons {  // Left button
        button = .Left
        action = .Pressed
    } else if 2 in event.mouse.buttons {  // Right button
        button = .Right
        action = .Pressed
    } else if 1 in event.mouse.buttons {  // Middle button
        button = .Middle
        action = .Pressed
    }

    dispatch_event(Mouse_Moved_Event{
        pos = {
			cast(f32)(f64(event.mouse.offset.x) * dpi),
			cast(f32)(f64(event.mouse.offset.y) * dpi),
		},
        button = button,
        action = action,
    })
}

@(private="file")
scroll_callback :: proc(event: js.Event) {
    dispatch_event(Mouse_Wheel_Event({
        f32(event.wheel.delta.x),
        f32(event.wheel.delta.y),
    }))
}

@(private="file")
size_callback :: proc(event: js.Event) {
    w, h := get_framebuffer_size()
    dispatch_event(Resize_Event{ w, h })
}
