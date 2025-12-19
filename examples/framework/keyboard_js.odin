#+build js
package framework

to_key :: proc "contextless" (key: string) -> Key {
    switch key {
    case "a", "A":      return .A
    case "b", "B":      return .B
    case "c", "C":      return .C
    case "d", "D":      return .D
    case "e", "E":      return .E
    case "f", "F":      return .F
    case "g", "G":      return .G
    case "h", "H":      return .H
    case "i", "I":      return .I
    case "j", "J":      return .J
    case "k", "K":      return .K
    case "l", "L":      return .L
    case "m", "M":      return .M
    case "n", "N":      return .N
    case "o", "O":      return .O
    case "p", "P":      return .P
    case "q", "Q":      return .Q
    case "r", "R":      return .R
    case "s", "S":      return .S
    case "t", "T":      return .T
    case "u", "U":      return .U
    case "v", "V":      return .V
    case "w", "W":      return .W
    case "x", "X":      return .X
    case "y", "Y":      return .Y
    case "z", "Z":      return .Z
    case "0":           return .Num0
    case "1":           return .Num1
    case "2":           return .Num2
    case "3":           return .Num3
    case "4":           return .Num4
    case "5":           return .Num5
    case "6":           return .Num6
    case "7":           return .Num7
    case "8":           return .Num8
    case "9":           return .Num9
    case "Escape":      return .Escape
    case "Control":     return .L_Control
    case "Shift":       return .L_Shift
    case "Alt":         return .L_Alt
    case "Meta":        return .L_System
    case "ContextMenu": return .Menu
    case "[":           return .L_Bracket
    case "]":           return .R_Bracket
    case ";":           return .Semicolon
    case ",":           return .Comma
    case ".":           return .Period
    case "'":           return .Apostrophe
    case "/":           return .Slash
    case "\\":          return .Backslash
    case "`":           return .Grave
    case "=":           return .Equal
    case "-":           return .Hyphen
    case " ":           return .Space
    case "Enter":       return .Enter
    case "Backspace":   return .Backspace
    case "Tab":         return .Tab
    case "PageUp":      return .Page_Up
    case "PageDown":    return .Page_Down
    case "End":         return .End
    case "Home":        return .Home
    case "Insert":      return .Insert
    case "Delete":      return .Delete
    case "ArrowLeft":   return .Left
    case "ArrowRight":  return .Right
    case "ArrowUp":     return .Up
    case "ArrowDown":   return .Down
    case "F1":          return .F1
    case "F2":          return .F2
    case "F3":          return .F3
    case "F4":          return .F4
    case "F5":          return .F5
    case "F6":          return .F6
    case "F7":          return .F7
    case "F8":          return .F8
    case "F9":          return .F9
    case "F10":         return .F10
    case "F11":         return .F11
    case "F12":         return .F12
    case "F13":         return .F13
    case "F14":         return .F14
    case "F15":         return .F15
    case "Pause":       return .Pause
    }
    return .Unknown
}

@(rodata, private)
FROM_KEY_LUT := [Key]string {
    .Unknown    = "Unknown",
    .A          = "A",
    .B          = "B",
    .C          = "C",
    .D          = "D",
    .E          = "E",
    .F          = "F",
    .G          = "G",
    .H          = "H",
    .I          = "I",
    .J          = "J",
    .K          = "K",
    .L          = "L",
    .M          = "M",
    .N          = "N",
    .O          = "O",
    .P          = "P",
    .Q          = "Q",
    .R          = "R",
    .S          = "S",
    .T          = "T",
    .U          = "U",
    .V          = "V",
    .W          = "W",
    .X          = "X",
    .Y          = "Y",
    .Z          = "Z",
    .Num0       = "0",
    .Num1       = "1",
    .Num2       = "2",
    .Num3       = "3",
    .Num4       = "4",
    .Num5       = "5",
    .Num6       = "6",
    .Num7       = "7",
    .Num8       = "8",
    .Num9       = "9",
    .Escape     = "Escape",
    .L_Control  = "Control",
    .L_Shift    = "Shift",
    .L_Alt      = "Alt",
    .L_System   = "Meta",
    .R_Control  = "Control",
    .R_Shift    = "Shift",
    .R_Alt      = "Alt",
    .R_System   = "Meta",
    .Menu       = "ContextMenu",
    .L_Bracket  = "[",
    .R_Bracket  = "]",
    .Semicolon  = ";",
    .Comma      = ",",
    .Period     = ".",
    .Apostrophe = "'",
    .Slash      = "/",
    .Backslash  = "\\",
    .Grave      = "`",
    .Equal      = "=",
    .Hyphen     = "-",
    .Space      = " ",
    .Enter      = "Enter",
    .Backspace  = "Backspace",
    .Tab        = "Tab",
    .Page_Up    = "PageUp",
    .Page_Down  = "PageDown",
    .End        = "End",
    .Home       = "Home",
    .Insert     = "Insert",
    .Delete     = "Delete",
    .Add        = "+",
    .Subtract   = "-",
    .Multiply   = "*",
    .Divide     = "/",
    .Left       = "ArrowLeft",
    .Right      = "ArrowRight",
    .Up         = "ArrowUp",
    .Down       = "ArrowDown",
    .Numpad0    = "0",
    .Numpad1    = "1",
    .Numpad2    = "2",
    .Numpad3    = "3",
    .Numpad4    = "4",
    .Numpad5    = "5",
    .Numpad6    = "6",
    .Numpad7    = "7",
    .Numpad8    = "8",
    .Numpad9    = "9",
    .F1         = "F1",
    .F2         = "F2",
    .F3         = "F3",
    .F4         = "F4",
    .F5         = "F5",
    .F6         = "F6",
    .F7         = "F7",
    .F8         = "F8",
    .F9         = "F9",
    .F10        = "F10",
    .F11        = "F11",
    .F12        = "F12",
    .F13        = "F13",
    .F14        = "F14",
    .F15        = "F15",
    .Pause      = "Pause",
}

to_scancode :: proc "contextless" (code: string) -> i32 {
    // Web KeyboardEvent code to scancode mapping
    switch code {
    // Letters
    case "KeyA":           return 4
    case "KeyB":           return 5
    case "KeyC":           return 6
    case "KeyD":           return 7
    case "KeyE":           return 8
    case "KeyF":           return 9
    case "KeyG":           return 10
    case "KeyH":           return 11
    case "KeyI":           return 12
    case "KeyJ":           return 13
    case "KeyK":           return 14
    case "KeyL":           return 15
    case "KeyM":           return 16
    case "KeyN":           return 17
    case "KeyO":           return 18
    case "KeyP":           return 19
    case "KeyQ":           return 20
    case "KeyR":           return 21
    case "KeyS":           return 22
    case "KeyT":           return 23
    case "KeyU":           return 24
    case "KeyV":           return 25
    case "KeyW":           return 26
    case "KeyX":           return 27
    case "KeyY":           return 28
    case "KeyZ":           return 29

    // Numbers
    case "Digit1":         return 30
    case "Digit2":         return 31
    case "Digit3":         return 32
    case "Digit4":         return 33
    case "Digit5":         return 34
    case "Digit6":         return 35
    case "Digit7":         return 36
    case "Digit8":         return 37
    case "Digit9":         return 38
    case "Digit0":         return 39

    // Function keys
    case "F1":             return 58
    case "F2":             return 59
    case "F3":             return 60
    case "F4":             return 61
    case "F5":             return 62
    case "F6":             return 63
    case "F7":             return 64
    case "F8":             return 65
    case "F9":             return 66
    case "F10":            return 67
    case "F11":            return 68
    case "F12":            return 69
    case "F13":            return 104
    case "F14":            return 105
    case "F15":            return 106

    // Special keys
    case "Escape":         return 41
    case "Backspace":      return 42
    case "Tab":            return 43
    case "Enter":          return 40
    case "Space":          return 44
    case "Minus":          return 45
    case "Equal":          return 46
    case "BracketLeft":    return 47
    case "BracketRight":   return 48
    case "Backslash":      return 49
    case "Semicolon":      return 51
    case "Quote":          return 52
    case "Backquote":      return 53
    case "Comma":          return 54
    case "Period":         return 55
    case "Slash":          return 56

    // Navigation keys
    case "Insert":         return 73
    case "Home":           return 74
    case "PageUp":         return 75
    case "Delete":         return 76
    case "End":            return 77
    case "PageDown":       return 78
    case "ArrowRight":     return 79
    case "ArrowLeft":      return 80
    case "ArrowDown":      return 81
    case "ArrowUp":        return 82

    // Numpad
    case "NumLock":        return 83
    case "NumpadDivide":   return 84
    case "NumpadMultiply": return 85
    case "NumpadSubtract": return 86
    case "NumpadAdd":      return 87
    case "NumpadEnter":    return 88
    case "Numpad1":        return 89
    case "Numpad2":        return 90
    case "Numpad3":        return 91
    case "Numpad4":        return 92
    case "Numpad5":        return 93
    case "Numpad6":        return 94
    case "Numpad7":        return 95
    case "Numpad8":        return 96
    case "Numpad9":        return 97
    case "Numpad0":        return 98
    case "NumpadDecimal":  return 99

    // Modifiers
    case "ControlLeft":    return 224
    case "ShiftLeft":      return 225
    case "AltLeft":        return 226
    case "MetaLeft":       return 227
    case "ControlRight":   return 228
    case "ShiftRight":     return 229
    case "AltRight":       return 230
    case "MetaRight":      return 231

    // Other
    case "CapsLock":       return 57
    case "PrintScreen":    return 70
    case "ScrollLock":     return 71
    case "Pause":          return 72
    case "ContextMenu":    return 101
    }
    return 0 // Unknown scancode
}

// Lookup table to convert Key enum to i32 scancode
@(rodata, private)
FROM_KEY_TO_SCANCODE_LUT := [Key]i32 {
    .Unknown    = 0,

    // Letters
    .A          = 4,
    .B          = 5,
    .C          = 6,
    .D          = 7,
    .E          = 8,
    .F          = 9,
    .G          = 10,
    .H          = 11,
    .I          = 12,
    .J          = 13,
    .K          = 14,
    .L          = 15,
    .M          = 16,
    .N          = 17,
    .O          = 18,
    .P          = 19,
    .Q          = 20,
    .R          = 21,
    .S          = 22,
    .T          = 23,
    .U          = 24,
    .V          = 25,
    .W          = 26,
    .X          = 27,
    .Y          = 28,
    .Z          = 29,

    // Numbers
    .Num0       = 39,
    .Num1       = 30,
    .Num2       = 31,
    .Num3       = 32,
    .Num4       = 33,
    .Num5       = 34,
    .Num6       = 35,
    .Num7       = 36,
    .Num8       = 37,
    .Num9       = 38,

    // Function keys
    .F1         = 58,
    .F2         = 59,
    .F3         = 60,
    .F4         = 61,
    .F5         = 62,
    .F6         = 63,
    .F7         = 64,
    .F8         = 65,
    .F9         = 66,
    .F10        = 67,
    .F11        = 68,
    .F12        = 69,
    .F13        = 104,
    .F14        = 105,
    .F15        = 106,

    // Special keys
    .Escape     = 41,
    .Backspace  = 42,
    .Tab        = 43,
    .Enter      = 40,
    .Space      = 44,
    .Hyphen     = 45,
    .Equal      = 46,
    .L_Bracket  = 47,
    .R_Bracket  = 48,
    .Backslash  = 49,
    .Semicolon  = 51,
    .Apostrophe = 52,
    .Grave      = 53,
    .Comma      = 54,
    .Period     = 55,
    .Slash      = 56,

    // Navigation
    .Insert     = 73,
    .Home       = 74,
    .Page_Up    = 75,
    .Delete     = 76,
    .End        = 77,
    .Page_Down  = 78,
    .Right      = 79,
    .Left       = 80,
    .Down       = 81,
    .Up         = 82,

    // Numpad
    .Numpad0    = 98,
    .Numpad1    = 89,
    .Numpad2    = 90,
    .Numpad3    = 91,
    .Numpad4    = 92,
    .Numpad5    = 93,
    .Numpad6    = 94,
    .Numpad7    = 95,
    .Numpad8    = 96,
    .Numpad9    = 97,

    // Modifiers
    .L_Control  = 224,
    .L_Shift    = 225,
    .L_Alt      = 226,
    .L_System   = 227,
    .R_Control  = 228,
    .R_Shift    = 229,
    .R_Alt      = 230,
    .R_System   = 231,

    // Other
    .Menu       = 101,
    .Pause      = 72,

    // Math operations (mapped to numpad equivalents)
    .Add        = 87,
    .Subtract   = 86,
    .Multiply   = 85,
    .Divide     = 84,
}
