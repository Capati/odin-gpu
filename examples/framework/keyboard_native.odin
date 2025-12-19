#+build !js
package framework

// Vendor
import "vendor:glfw"

to_key :: proc "contextless" (key: i32) -> Key {
    switch key {
    case glfw.KEY_SPACE:         return .Space
    case glfw.KEY_APOSTROPHE:    return .Apostrophe
    case glfw.KEY_COMMA:         return .Comma
    case glfw.KEY_MINUS:         return .Hyphen
    case glfw.KEY_PERIOD:        return .Period
    case glfw.KEY_SLASH:         return .Slash
    case glfw.KEY_SEMICOLON:     return .Semicolon
    case glfw.KEY_EQUAL:         return .Equal
    case glfw.KEY_LEFT_BRACKET:  return .L_Bracket
    case glfw.KEY_BACKSLASH:     return .Backslash
    case glfw.KEY_RIGHT_BRACKET: return .R_Bracket
    case glfw.KEY_GRAVE_ACCENT:  return .Grave
    case glfw.KEY_0:             return .Num0
    case glfw.KEY_1:             return .Num1
    case glfw.KEY_2:             return .Num2
    case glfw.KEY_3:             return .Num3
    case glfw.KEY_4:             return .Num4
    case glfw.KEY_5:             return .Num5
    case glfw.KEY_6:             return .Num6
    case glfw.KEY_7:             return .Num7
    case glfw.KEY_8:             return .Num8
    case glfw.KEY_9:             return .Num9
    case glfw.KEY_A:             return .A
    case glfw.KEY_B:             return .B
    case glfw.KEY_C:             return .C
    case glfw.KEY_D:             return .D
    case glfw.KEY_E:             return .E
    case glfw.KEY_F:             return .F
    case glfw.KEY_G:             return .G
    case glfw.KEY_H:             return .H
    case glfw.KEY_I:             return .I
    case glfw.KEY_J:             return .J
    case glfw.KEY_K:             return .K
    case glfw.KEY_L:             return .L
    case glfw.KEY_M:             return .M
    case glfw.KEY_N:             return .N
    case glfw.KEY_O:             return .O
    case glfw.KEY_P:             return .P
    case glfw.KEY_Q:             return .Q
    case glfw.KEY_R:             return .R
    case glfw.KEY_S:             return .S
    case glfw.KEY_T:             return .T
    case glfw.KEY_U:             return .U
    case glfw.KEY_V:             return .V
    case glfw.KEY_W:             return .W
    case glfw.KEY_X:             return .X
    case glfw.KEY_Y:             return .Y
    case glfw.KEY_Z:             return .Z
    case glfw.KEY_ESCAPE:        return .Escape
    case glfw.KEY_ENTER:         return .Enter
    case glfw.KEY_TAB:           return .Tab
    case glfw.KEY_BACKSPACE:     return .Backspace
    case glfw.KEY_INSERT:        return .Insert
    case glfw.KEY_DELETE:        return .Delete
    case glfw.KEY_RIGHT:         return .Right
    case glfw.KEY_LEFT:          return .Left
    case glfw.KEY_DOWN:          return .Down
    case glfw.KEY_UP:            return .Up
    case glfw.KEY_PAGE_UP:       return .Page_Up
    case glfw.KEY_PAGE_DOWN:     return .Page_Down
    case glfw.KEY_HOME:          return .Home
    case glfw.KEY_END:           return .End
    case glfw.KEY_PAUSE:         return .Pause
    case glfw.KEY_F1:            return .F1
    case glfw.KEY_F2:            return .F2
    case glfw.KEY_F3:            return .F3
    case glfw.KEY_F4:            return .F4
    case glfw.KEY_F5:            return .F5
    case glfw.KEY_F6:            return .F6
    case glfw.KEY_F7:            return .F7
    case glfw.KEY_F8:            return .F8
    case glfw.KEY_F9:            return .F9
    case glfw.KEY_F10:           return .F10
    case glfw.KEY_F11:           return .F11
    case glfw.KEY_F12:           return .F12
    case glfw.KEY_F13:           return .F13
    case glfw.KEY_F14:           return .F14
    case glfw.KEY_F15:           return .F15
    case glfw.KEY_KP_0:          return .Numpad0
    case glfw.KEY_KP_1:          return .Numpad1
    case glfw.KEY_KP_2:          return .Numpad2
    case glfw.KEY_KP_3:          return .Numpad3
    case glfw.KEY_KP_4:          return .Numpad4
    case glfw.KEY_KP_5:          return .Numpad5
    case glfw.KEY_KP_6:          return .Numpad6
    case glfw.KEY_KP_7:          return .Numpad7
    case glfw.KEY_KP_8:          return .Numpad8
    case glfw.KEY_KP_9:          return .Numpad9
    case glfw.KEY_KP_DECIMAL:    return .Divide  // Best match available
    case glfw.KEY_KP_DIVIDE:     return .Divide
    case glfw.KEY_KP_MULTIPLY:   return .Multiply
    case glfw.KEY_KP_SUBTRACT:   return .Subtract
    case glfw.KEY_KP_ADD:        return .Add
    case glfw.KEY_LEFT_SHIFT:    return .L_Shift
    case glfw.KEY_LEFT_CONTROL:  return .L_Control
    case glfw.KEY_LEFT_ALT:      return .L_Alt
    case glfw.KEY_LEFT_SUPER:    return .L_System
    case glfw.KEY_RIGHT_SHIFT:   return .R_Shift
    case glfw.KEY_RIGHT_CONTROL: return .R_Control
    case glfw.KEY_RIGHT_ALT:     return .R_Alt
    case glfw.KEY_RIGHT_SUPER:   return .R_System
    case glfw.KEY_MENU:          return .Menu
    }
    return .Unknown
}

to_scancode :: proc "contextless" (scancode: i32) -> Scancode {
    switch scancode {
    case glfw.KEY_A:             return .A
    case glfw.KEY_B:             return .B
    case glfw.KEY_C:             return .C
    case glfw.KEY_D:             return .D
    case glfw.KEY_E:             return .E
    case glfw.KEY_F:             return .F
    case glfw.KEY_G:             return .G
    case glfw.KEY_H:             return .H
    case glfw.KEY_I:             return .I
    case glfw.KEY_J:             return .J
    case glfw.KEY_K:             return .K
    case glfw.KEY_L:             return .L
    case glfw.KEY_M:             return .M
    case glfw.KEY_N:             return .N
    case glfw.KEY_O:             return .O
    case glfw.KEY_P:             return .P
    case glfw.KEY_Q:             return .Q
    case glfw.KEY_R:             return .R
    case glfw.KEY_S:             return .S
    case glfw.KEY_T:             return .T
    case glfw.KEY_U:             return .U
    case glfw.KEY_V:             return .V
    case glfw.KEY_W:             return .W
    case glfw.KEY_X:             return .X
    case glfw.KEY_Y:             return .Y
    case glfw.KEY_Z:             return .Z
    case glfw.KEY_1:             return .Num1
    case glfw.KEY_2:             return .Num2
    case glfw.KEY_3:             return .Num3
    case glfw.KEY_4:             return .Num4
    case glfw.KEY_5:             return .Num5
    case glfw.KEY_6:             return .Num6
    case glfw.KEY_7:             return .Num7
    case glfw.KEY_8:             return .Num8
    case glfw.KEY_9:             return .Num9
    case glfw.KEY_0:             return .Num0
    case glfw.KEY_ENTER:         return .Enter
    case glfw.KEY_ESCAPE:        return .Escape
    case glfw.KEY_BACKSPACE:     return .Backspace
    case glfw.KEY_TAB:           return .Tab
    case glfw.KEY_SPACE:         return .Space
    case glfw.KEY_MINUS:         return .Hyphen
    case glfw.KEY_EQUAL:         return .Equal
    case glfw.KEY_LEFT_BRACKET:  return .L_Bracket
    case glfw.KEY_RIGHT_BRACKET: return .R_Bracket
    case glfw.KEY_BACKSLASH:     return .Backslash
    case glfw.KEY_SEMICOLON:     return .Semicolon
    case glfw.KEY_APOSTROPHE:    return .Apostrophe
    case glfw.KEY_GRAVE_ACCENT:  return .Grave
    case glfw.KEY_COMMA:         return .Comma
    case glfw.KEY_PERIOD:        return .Period
    case glfw.KEY_SLASH:         return .Slash
    case glfw.KEY_F1:            return .F1
    case glfw.KEY_F2:            return .F2
    case glfw.KEY_F3:            return .F3
    case glfw.KEY_F4:            return .F4
    case glfw.KEY_F5:            return .F5
    case glfw.KEY_F6:            return .F6
    case glfw.KEY_F7:            return .F7
    case glfw.KEY_F8:            return .F8
    case glfw.KEY_F9:            return .F9
    case glfw.KEY_F10:           return .F10
    case glfw.KEY_F11:           return .F11
    case glfw.KEY_F12:           return .F12
    case glfw.KEY_F13:           return .F13
    case glfw.KEY_F14:           return .F14
    case glfw.KEY_F15:           return .F15
    case glfw.KEY_F16:           return .F16
    case glfw.KEY_F17:           return .F17
    case glfw.KEY_F18:           return .F18
    case glfw.KEY_F19:           return .F19
    case glfw.KEY_F20:           return .F20
    case glfw.KEY_F21:           return .F21
    case glfw.KEY_F22:           return .F22
    case glfw.KEY_F23:           return .F23
    case glfw.KEY_F24:           return .F24
    case glfw.KEY_CAPS_LOCK:     return .Caps_Lock
    case glfw.KEY_PRINT_SCREEN:  return .Print_Screen
    case glfw.KEY_SCROLL_LOCK:   return .Scroll_Lock
    case glfw.KEY_PAUSE:         return .Pause
    case glfw.KEY_INSERT:        return .Insert
    case glfw.KEY_HOME:          return .Home
    case glfw.KEY_PAGE_UP:       return .Page_Up
    case glfw.KEY_DELETE:        return .Delete
    case glfw.KEY_END:           return .End
    case glfw.KEY_PAGE_DOWN:     return .Page_Down
    case glfw.KEY_RIGHT:         return .Right
    case glfw.KEY_LEFT:          return .Left
    case glfw.KEY_DOWN:          return .Down
    case glfw.KEY_UP:            return .Up
    case glfw.KEY_NUM_LOCK:      return .Num_Lock
    case glfw.KEY_KP_DIVIDE:     return .Numpad_Divide
    case glfw.KEY_KP_MULTIPLY:   return .Numpad_Multiply
    case glfw.KEY_KP_SUBTRACT:   return .Numpad_Minus
    case glfw.KEY_KP_ADD:        return .Numpad_Plus
    case glfw.KEY_KP_EQUAL:      return .Numpad_Equal
    case glfw.KEY_KP_ENTER:      return .Numpad_Enter
    case glfw.KEY_KP_DECIMAL:    return .Numpad_Decimal
    case glfw.KEY_KP_1:          return .Numpad1
    case glfw.KEY_KP_2:          return .Numpad2
    case glfw.KEY_KP_3:          return .Numpad3
    case glfw.KEY_KP_4:          return .Numpad4
    case glfw.KEY_KP_5:          return .Numpad5
    case glfw.KEY_KP_6:          return .Numpad6
    case glfw.KEY_KP_7:          return .Numpad7
    case glfw.KEY_KP_8:          return .Numpad8
    case glfw.KEY_KP_9:          return .Numpad9
    case glfw.KEY_KP_0:          return .Numpad0
    case glfw.KEY_MENU:          return .Menu
    case glfw.KEY_LEFT_CONTROL:  return .L_Control
    case glfw.KEY_LEFT_SHIFT:    return .L_Shift
    case glfw.KEY_LEFT_ALT:      return .L_Alt
    case glfw.KEY_LEFT_SUPER:    return .L_System
    case glfw.KEY_RIGHT_CONTROL: return .R_Control
    case glfw.KEY_RIGHT_SHIFT:   return .R_Shift
    case glfw.KEY_RIGHT_ALT:     return .R_Alt
    case glfw.KEY_RIGHT_SUPER:   return .R_System
    }
    return .Unknown
}

key_to_scancode :: proc "contextless" (key: Key) -> Scancode {
    switch key {
    case .A:          return .A
    case .B:          return .B
    case .C:          return .C
    case .D:          return .D
    case .E:          return .E
    case .F:          return .F
    case .G:          return .G
    case .H:          return .H
    case .I:          return .I
    case .J:          return .J
    case .K:          return .K
    case .L:          return .L
    case .M:          return .M
    case .N:          return .N
    case .O:          return .O
    case .P:          return .P
    case .Q:          return .Q
    case .R:          return .R
    case .S:          return .S
    case .T:          return .T
    case .U:          return .U
    case .V:          return .V
    case .W:          return .W
    case .X:          return .X
    case .Y:          return .Y
    case .Z:          return .Z
    case .Num0:       return .Num0
    case .Num1:       return .Num1
    case .Num2:       return .Num2
    case .Num3:       return .Num3
    case .Num4:       return .Num4
    case .Num5:       return .Num5
    case .Num6:       return .Num6
    case .Num7:       return .Num7
    case .Num8:       return .Num8
    case .Num9:       return .Num9
    case .Escape:     return .Escape
    case .L_Control:  return .L_Control
    case .L_Shift:    return .L_Shift
    case .L_Alt:      return .L_Alt
    case .L_System:   return .L_System
    case .R_Control:  return .R_Control
    case .R_Shift:    return .R_Shift
    case .R_Alt:      return .R_Alt
    case .R_System:   return .R_System
    case .Menu:       return .Menu
    case .L_Bracket:  return .L_Bracket
    case .R_Bracket:  return .R_Bracket
    case .Semicolon:  return .Semicolon
    case .Comma:      return .Comma
    case .Period:     return .Period
    case .Apostrophe: return .Apostrophe
    case .Slash:      return .Slash
    case .Backslash:  return .Backslash
    case .Grave:      return .Grave
    case .Equal:      return .Equal
    case .Hyphen:     return .Hyphen
    case .Space:      return .Space
    case .Enter:      return .Enter
    case .Backspace:  return .Backspace
    case .Tab:        return .Tab
    case .Page_Up:    return .Page_Up
    case .Page_Down:  return .Page_Down
    case .End:        return .End
    case .Home:       return .Home
    case .Insert:     return .Insert
    case .Delete:     return .Delete
    case .Add:        return .Numpad_Plus
    case .Subtract:   return .Numpad_Minus
    case .Multiply:   return .Numpad_Multiply
    case .Divide:     return .Numpad_Divide
    case .Left:       return .Left
    case .Right:      return .Right
    case .Up:         return .Up
    case .Down:       return .Down
    case .Numpad0:    return .Numpad0
    case .Numpad1:    return .Numpad1
    case .Numpad2:    return .Numpad2
    case .Numpad3:    return .Numpad3
    case .Numpad4:    return .Numpad4
    case .Numpad5:    return .Numpad5
    case .Numpad6:    return .Numpad6
    case .Numpad7:    return .Numpad7
    case .Numpad8:    return .Numpad8
    case .Numpad9:    return .Numpad9
    case .F1:         return .F1
    case .F2:         return .F2
    case .F3:         return .F3
    case .F4:         return .F4
    case .F5:         return .F5
    case .F6:         return .F6
    case .F7:         return .F7
    case .F8:         return .F8
    case .F9:         return .F9
    case .F10:        return .F10
    case .F11:        return .F11
    case .F12:        return .F12
    case .F13:        return .F13
    case .F14:        return .F14
    case .F15:        return .F15
    case .Pause:      return .Pause
    case .Unknown:    return .Unknown
    }
    return .Unknown
}

@(rodata, private)
FROM_KEY_LUT := [Key]i32 {
    .Unknown    = glfw.KEY_UNKNOWN,
    .Space      = glfw.KEY_SPACE,
    .Apostrophe = glfw.KEY_APOSTROPHE,
    .Comma      = glfw.KEY_COMMA,
    .Hyphen     = glfw.KEY_MINUS,
    .Period     = glfw.KEY_PERIOD,
    .Slash      = glfw.KEY_SLASH,
    .Semicolon  = glfw.KEY_SEMICOLON,
    .Equal      = glfw.KEY_EQUAL,
    .L_Bracket  = glfw.KEY_LEFT_BRACKET,
    .Backslash  = glfw.KEY_BACKSLASH,
    .R_Bracket  = glfw.KEY_RIGHT_BRACKET,
    .Grave      = glfw.KEY_GRAVE_ACCENT,
    .Num0       = glfw.KEY_0,
    .Num1       = glfw.KEY_1,
    .Num2       = glfw.KEY_2,
    .Num3       = glfw.KEY_3,
    .Num4       = glfw.KEY_4,
    .Num5       = glfw.KEY_5,
    .Num6       = glfw.KEY_6,
    .Num7       = glfw.KEY_7,
    .Num8       = glfw.KEY_8,
    .Num9       = glfw.KEY_9,
    .A          = glfw.KEY_A,
    .B          = glfw.KEY_B,
    .C          = glfw.KEY_C,
    .D          = glfw.KEY_D,
    .E          = glfw.KEY_E,
    .F          = glfw.KEY_F,
    .G          = glfw.KEY_G,
    .H          = glfw.KEY_H,
    .I          = glfw.KEY_I,
    .J          = glfw.KEY_J,
    .K          = glfw.KEY_K,
    .L          = glfw.KEY_L,
    .M          = glfw.KEY_M,
    .N          = glfw.KEY_N,
    .O          = glfw.KEY_O,
    .P          = glfw.KEY_P,
    .Q          = glfw.KEY_Q,
    .R          = glfw.KEY_R,
    .S          = glfw.KEY_S,
    .T          = glfw.KEY_T,
    .U          = glfw.KEY_U,
    .V          = glfw.KEY_V,
    .W          = glfw.KEY_W,
    .X          = glfw.KEY_X,
    .Y          = glfw.KEY_Y,
    .Z          = glfw.KEY_Z,
    .Escape     = glfw.KEY_ESCAPE,
    .Enter      = glfw.KEY_ENTER,
    .Tab        = glfw.KEY_TAB,
    .Backspace  = glfw.KEY_BACKSPACE,
    .Insert     = glfw.KEY_INSERT,
    .Delete     = glfw.KEY_DELETE,
    .Right      = glfw.KEY_RIGHT,
    .Left       = glfw.KEY_LEFT,
    .Down       = glfw.KEY_DOWN,
    .Up         = glfw.KEY_UP,
    .Page_Up    = glfw.KEY_PAGE_UP,
    .Page_Down  = glfw.KEY_PAGE_DOWN,
    .Home       = glfw.KEY_HOME,
    .End        = glfw.KEY_END,
    .Pause      = glfw.KEY_PAUSE,
    .F1         = glfw.KEY_F1,
    .F2         = glfw.KEY_F2,
    .F3         = glfw.KEY_F3,
    .F4         = glfw.KEY_F4,
    .F5         = glfw.KEY_F5,
    .F6         = glfw.KEY_F6,
    .F7         = glfw.KEY_F7,
    .F8         = glfw.KEY_F8,
    .F9         = glfw.KEY_F9,
    .F10        = glfw.KEY_F10,
    .F11        = glfw.KEY_F11,
    .F12        = glfw.KEY_F12,
    .F13        = glfw.KEY_F13,
    .F14        = glfw.KEY_F14,
    .F15        = glfw.KEY_F15,
    .Numpad0    = glfw.KEY_KP_0,
    .Numpad1    = glfw.KEY_KP_1,
    .Numpad2    = glfw.KEY_KP_2,
    .Numpad3    = glfw.KEY_KP_3,
    .Numpad4    = glfw.KEY_KP_4,
    .Numpad5    = glfw.KEY_KP_5,
    .Numpad6    = glfw.KEY_KP_6,
    .Numpad7    = glfw.KEY_KP_7,
    .Numpad8    = glfw.KEY_KP_8,
    .Numpad9    = glfw.KEY_KP_9,
    .Divide     = glfw.KEY_KP_DIVIDE,
    .Multiply   = glfw.KEY_KP_MULTIPLY,
    .Subtract   = glfw.KEY_KP_SUBTRACT,
    .Add        = glfw.KEY_KP_ADD,
    .L_Control  = glfw.KEY_LEFT_CONTROL,
    .L_Shift    = glfw.KEY_RIGHT_SHIFT,
    .L_Alt      = glfw.KEY_LEFT_ALT,
    .L_System   = glfw.KEY_LEFT_SUPER,
    .R_Control  = glfw.KEY_RIGHT_CONTROL,
    .R_Shift    = glfw.KEY_RIGHT_SHIFT,
    .R_Alt      = glfw.KEY_RIGHT_ALT,
    .R_System   = glfw.KEY_RIGHT_SUPER,
    .Menu       = glfw.KEY_MENU,
}
