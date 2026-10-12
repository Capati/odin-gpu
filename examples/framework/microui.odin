package application

// Vendor
import mu "vendor:microui"

@(require_results)
mu_mouse_button :: proc "contextless" (button: Mouse_Button) -> (mu_mouse: mu.Mouse) {
    if button == .Left {
        mu_mouse = .LEFT
    } else if button == .Right {
        mu_mouse = .RIGHT
    } else if button == .Middle {
        mu_mouse = .MIDDLE
    }
    return
}

@(require_results)
mu_key :: proc "contextless" (key: Key) -> (mu_key: mu.Key) {
    if key == .L_Shift || key == .R_Shift {
        mu_key = .SHIFT
    } else if key == .L_Control || key == .R_Control {
        mu_key = .CTRL
    } else if key == .L_Alt || key == .R_Alt {
        mu_key = .ALT
    } else if key == .Backspace {
        mu_key = .BACKSPACE
    } else if key == .Enter {
        mu_key = .RETURN
    }
    return
}

mu_handle_events :: proc(mu_ctx: ^mu.Context, event: Event) {
    #partial switch ev in event {
    // case Text_Input_Event:
    //  mu.input_text(mu_ctx, string(cstring(&ev.buf[0])))
    case Key_Event:
        #partial switch ev.action {
        case .Pressed:
            mu.input_key_down(mu_ctx, mu_key(ev.key))
        case .Released:
            mu.input_key_up(mu_ctx, mu_key(ev.key))
        }

    case Char_Event:
        buf := ev.bytes // local copy: switch values are not addressable
        mu.input_text(mu_ctx, string(buf[:ev.size]))

    case Mouse_Button_Event:
        #partial switch ev.action {
        case .Pressed:
            mu.input_mouse_down(mu_ctx, i32(ev.pos.x), i32(ev.pos.y), mu_mouse_button(ev.button))
        case .Released:
            mu.input_mouse_up(mu_ctx, i32(ev.pos.x), i32(ev.pos.y), mu_mouse_button(ev.button))
        }

    case Mouse_Wheel_Event:
        mu.input_scroll(mu_ctx, i32(ev.x), i32(ev.y))

    case Mouse_Motion_Event:
        mu.input_mouse_move(mu_ctx, i32(ev.pos.x), i32(ev.pos.y))
    }
}

mu_wants_mouse :: #force_inline proc "contextless" (ctx: ^mu.Context) -> bool {
    // cursor over a window/popup, or a widget is mid-interaction (e.g. dragging a slider)
    return ctx.hover_root != nil || ctx.focus_id != 0
}

mu_wants_keyboard :: #force_inline proc "contextless" (ctx: ^mu.Context) -> bool {
    return ctx.focus_id != 0
}

mu_wants_input :: #force_inline proc "contextless" (ctx: ^mu.Context) -> bool {
    return mu_wants_mouse(ctx) || mu_wants_keyboard(ctx)
}
