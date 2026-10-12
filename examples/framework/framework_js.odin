#+build js
package application

// Core
import "core:time"
import "core:sys/wasm/js"

DEFAULT_CANVAS_ID :: #config(CANVAS_ID, "#canvas")

OS :: struct {
    start_time:  time.Time,
    canvas_id:   string,
    initialized: bool,
}

os_init :: proc(title: string, width, height: u32) {
	g_ctx.os.canvas_id = DEFAULT_CANVAS_ID
	g_ctx.os.start_time = time.now()
	id := string(g_ctx.os.canvas_id[1:]) // remove the #
    ensure(js.add_window_event_listener(.Key_Down, nil, key_callback))
	ensure(js.add_window_event_listener(.Key_Up, nil, key_callback))
	ensure(js.add_window_event_listener(.Mouse_Down, nil, mouse_button_callback))
	ensure(js.add_window_event_listener(.Mouse_Up, nil, mouse_button_callback))
	ensure(js.add_event_listener(id, .Mouse_Move, nil, mouse_move_callback))
	ensure(js.add_window_event_listener(.Wheel, nil, scroll_callback))
	ensure(js.add_window_event_listener(.Resize, nil, size_callback))
}

os_quit :: proc() {
	id := string(g_ctx.os.canvas_id[1:]) // remove the #
	js.remove_window_event_listener(.Key_Down, nil, key_callback)
	js.remove_window_event_listener(.Key_Up, nil, key_callback)
	js.remove_window_event_listener(.Mouse_Down, nil, mouse_button_callback)
	js.remove_window_event_listener(.Mouse_Up, nil, mouse_button_callback)
	js.remove_event_listener(id, .Mouse_Move, nil, mouse_move_callback)
	js.remove_window_event_listener(.Wheel, nil, scroll_callback)
	js.remove_window_event_listener(.Resize, nil, size_callback)
}

// NOTE: frame loop is done by the runtime.js repeatedly calling `step`.
os_run :: proc() {
	g_ctx.os.initialized = true
}

@(private="file", export)
step :: proc(dt: f32) -> bool {
	context = g_ctx.custom_ctx

	if !g_ctx.os.initialized {
		return true
	}

    if g_ctx.desc.iterate_cb != nil {
        if !g_ctx.desc.iterate_cb(&g_ctx, dt) {
            quit()
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
    return f32(time.duration_seconds(time.since(g_ctx.os.start_time)))
}

hide_window :: proc() {
}

@(private="file")
key_callback :: proc(event: js.Event) {
    key := to_key(event.key.key)

    action: Input_Action
    #partial switch event.kind {
    case .Mouse_Down: action = .Pressed
    case .Mouse_Up:   action = .Released
    case:             action = .None
    }

    ev := Key_Event{
        key      = key,
        scancode = Scancode(to_scancode(event.key.code)),
        action   = action,
        ctrl     = event.key.ctrl,
        shift    = event.key.shift,
        alt      = event.key.alt,
    }

    dispatch_event(ev)
}

@(private="file")
mouse_button_callback :: proc(event: js.Event) {
    dpi := js.device_pixel_ratio()

    pos := [2]f32{
        cast(f32)(f64(event.mouse.offset.x) * dpi),
        cast(f32)(f64(event.mouse.offset.y) * dpi),
    }

    button: Mouse_Button
    switch event.mouse.button {
    case 0: button = .Left
    case 1: button = .Middle
    case 2: button = .Right
    case:   button = .Unknown
    }

    action: Input_Action
    #partial switch event.kind {
    case .Mouse_Down: action = .Pressed
    case .Mouse_Up:   action = .Released
    case:             action = .None
    }

    dispatch_event(Mouse_Button_Event{
        button = button,
        pos    = pos,
        action = action,
    })
}

@(private="file")
mouse_move_callback :: proc(event: js.Event) {
    dpi := js.device_pixel_ratio()

    dispatch_event(Mouse_Motion_Event{
        pos = {
            cast(f32)(f64(event.mouse.offset.x) * dpi),
            cast(f32)(f64(event.mouse.offset.y) * dpi),
        },
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
    g_ctx.width = w
    g_ctx.height = h
    dispatch_event(Resize_Event{ w, h })
}
