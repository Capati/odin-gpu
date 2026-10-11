package microui_gpu

// Core
import "core:fmt"
import intr "base:intrinsics"

// Vendor
import mu "vendor:microui"

Combobox_Item :: struct($T: typeid) where intr.type_is_enum(T) {
    name: string,
    item: T,
}

combobox :: proc(
    ctx: ^mu.Context,
    name: string,
    current_item: ^$T,
    items: []Combobox_Item(T),
) -> (res: mu.Result_Set) where intr.type_is_enum(T) {
    // Scope IDs per combobox so two combos can't share a popup container
    mu.push_id(ctx, name)
    defer mu.pop_id(ctx)

    ARROW_W :: 20

    id   := mu.get_id(ctx, "combo")
    rect := mu.layout_next(ctx)
    mu.update_control(ctx, id, rect)

    cnt := mu.get_container(ctx, "popup")
    if cnt.rect.w == 0 && cnt.rect.h == 0 {
        cnt.open = false   // freshly created: start closed
    }
    was_open := cnt.open

    // Control frame
    mu.draw_control_frame(ctx, id, rect, .BUTTON)

    // Current selection text (clipped so it can't run under the arrow)
    current_name := "<invalid>"
    for item in items {
        if item.item == current_item^ {
            current_name = item.name
            break
        }
    }

    text_rect := rect
    text_rect.w -= ARROW_W
    mu.push_clip_rect(ctx, text_rect)
    mu.draw_control_text(ctx, current_name, text_rect, .TEXT)
    mu.pop_clip_rect(ctx)

    // Dropdown arrow
    arrow_rect := mu.Rect{rect.x + rect.w - ARROW_W, rect.y, ARROW_W, rect.h}
    mu.draw_icon(ctx, .EXPANDED, arrow_rect, ctx.style.colors[.TEXT])

    hovered := ctx.hover_id == id
    popup_rect := mu.Rect{rect.x, rect.y + rect.h, rect.w, 1}

    if hovered && .LEFT in ctx.mouse_pressed_bits && !was_open {
        ctx.hover_root      = cnt
        ctx.next_hover_root = cnt
        cnt.open = true
        mu.bring_to_front(ctx, cnt)
    }

    if cnt.open {
        cnt.rect.x = rect.x
        cnt.rect.y = rect.y + rect.h

        opt := mu.Options{.POPUP, .AUTO_SIZE, .NO_RESIZE, .NO_SCROLL, .NO_TITLE}
        if mu.begin_window(ctx, "popup", popup_rect, opt) {
            defer mu.end_window(ctx)

            mu.layout_row(ctx, {rect.w - ctx.style.padding * 2})
            for item in items {
                if .SUBMIT in mu.button(ctx, item.name) {
                    current_item^ = item.item
                    res += {.SUBMIT, .CHANGE}
                    cnt.open = false
                }
            }
        }
    }

    return
}

// Label on its own row, combobox on the row below, both full width.
labeled_combobox :: proc(
    ctx: ^mu.Context,
    label: string,
    current_item: ^$T,
    items: []Combobox_Item(T),
) -> mu.Result_Set where intr.type_is_enum(T) {
    mu.layout_row(ctx, {-1}, 0)
    mu.label(ctx, label)
    mu.layout_row(ctx, {-1}, 0)
    return combobox(ctx, label, current_item, items)
}

slider :: proc(
    ctx: ^mu.Context,
    val: ^$T,
    lo, hi: T,
    step: mu.Real = 0.0,
    fmt_string: string = mu.SLIDER_FMT,
    options: mu.Options = {.ALIGN_CENTER},
) -> (
    res: mu.Result_Set,
) where intr.type_is_numeric(T) {
    mu.push_id(ctx, uintptr(val))

    @(static) tmp: mu.Real

    tmp = mu.Real(val^)
    res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), step, fmt_string, options)
    val^ = T(tmp)
    mu.pop_id(ctx)

    return
}

// number edits any numeric value through mu.number: horizontal drag changes
// it, click opens text input. Mirrors slider's temp-Real dance.
number :: proc(
    ctx: ^mu.Context,
    val: ^$T,
    step: mu.Real = 0.01,
    fmt_string: string = mu.SLIDER_FMT,
    options: mu.Options = {.ALIGN_CENTER},
) -> (
    res: mu.Result_Set,
) where intr.type_is_numeric(T) {
    mu.push_id(ctx, uintptr(val))
    defer mu.pop_id(ctx)

    @(static) tmp: mu.Real

    tmp = mu.Real(val^)
    res = mu.number(ctx, &tmp, step, fmt_string, options)
    val^ = T(tmp)

    return
}

color_row :: proc(ctx: ^mu.Context, color: ^[4]u8) -> (changed: bool) {
    cnt := mu.get_current_container(ctx)
    body_w := cnt.rect.w - ctx.style.padding * 2
    well_w := i32(28)
    gap := ctx.style.spacing
    number_w := (body_w - well_w - gap * 4) / 4
    widths := [5]i32{
        number_w,
        number_w,
        number_w,
        body_w - well_w - gap * 4 - number_w * 3, // last number absorbs remainder
        well_w,
    }
    mu.layout_row(ctx, widths[:], 0)

    for i in 0 ..< 4 {
        rect := mu.layout_next(ctx)
        mu.push_id(ctx, uintptr(&color[i]))
        tmp := mu.Real(color[i])
        id := mu.get_id(ctx, uintptr(&tmp))
        if mu.number_textbox(ctx, &tmp, rect, id, "%.0f") {
            mu.pop_id(ctx)
            continue
        }
        mu.update_control(ctx, id, rect, {.ALIGN_CENTER})
        if ctx.focus_id == id && .LEFT in ctx.mouse_down_bits {
            tmp += mu.Real(ctx.mouse_delta.x)
        }
        tmp = clamp(tmp, 0, 255)
        if tmp != mu.Real(color[i]) {
            color[i] = u8(tmp)
            changed = true
        }
        mu.draw_control_frame(ctx, id, rect, .BASE, {.ALIGN_CENTER})
        text_buf: [4096]byte
        mu.draw_control_text(ctx,
            fmt.bprintf(text_buf[:], "%.0f", tmp), rect, .TEXT, {.ALIGN_CENTER})
        mu.pop_id(ctx)
    }

    // Preview well on the right (visual only: no id, never steals input).
    well := mu.layout_next(ctx)
    mu.draw_box(ctx, well, ctx.style.colors[.BORDER])
    mu.draw_rect(
        ctx,
        {well.x + 1, well.y + 1, well.w - 2, well.h - 2},
        mu.Color{color[0], color[1], color[2], color[3]},
    )
    return changed
}

GRADIENT_STEPS :: 32

@(private = "file")
lerp_u8 :: proc(a, b: u8, t: f32) -> u8 {
    return u8(f32(a) + (f32(b) - f32(a)) * t)
}

@(private = "file")
lerp_color :: proc(a, b: mu.Color, t: f32) -> mu.Color {
    return {lerp_u8(a.r, b.r, t), lerp_u8(a.g, b.g, t), lerp_u8(a.b, b.b, t), 255}
}

to_mu_color :: proc(c: [4]f32) -> mu.Color {
    return {
        u8(clamp(c[0], 0, 1) * 255),
        u8(clamp(c[1], 0, 1) * 255),
        u8(clamp(c[2], 0, 1) * 255),
        u8(clamp(c[3], 0, 1) * 255),
    }
}

color_slider :: proc(
    ctx: ^mu.Context,
    val: ^mu.Real,
    from, to: mu.Color,
    fmt_string: string = "%.2f",
    opt: mu.Options = {.ALIGN_CENTER},
) -> (
    res: mu.Result_Set,
) {
    id := mu.get_id(ctx, uintptr(val))
    base := mu.layout_next(ctx)
    last := val^

    // Shift+click text entry (returns true while editing).
    if mu.number_textbox(ctx, val, base, id, fmt_string) {
        return
    }

    mu.update_control(ctx, id, base, opt)

    // Drag: map mouse x straight onto 0..1.
    if ctx.focus_id == id && ctx.mouse_down_bits == {.LEFT} {
        val^ = clamp(mu.Real(ctx.mouse_pos.x - base.x) / mu.Real(base.w), 0, 1)
    }
    val^ = clamp(val^, 0, 1)
    if val^ != last {
        res += {.CHANGE}
    }

    // Border + gradient track.
    mu.draw_box(ctx, base, ctx.style.colors[.BORDER])
    inner := mu.Rect{base.x + 1, base.y + 1, base.w - 2, base.h - 2}
    for i in 0 ..< GRADIENT_STEPS {
        x0 := inner.x + inner.w * i32(i) / GRADIENT_STEPS
        x1 := inner.x + inner.w * i32(i + 1) / GRADIENT_STEPS
        t := (f32(i) + 0.5) / GRADIENT_STEPS
        mu.draw_rect(ctx, {x0, inner.y, x1 - x0, inner.h}, lerp_color(from, to, t))
    }

    // Handle: a thin bar, bright when hovered/dragged.
    handle_w: i32 = 4
    hx := inner.x + i32(val^ * mu.Real(inner.w - handle_w))
    handle_col := ctx.style.colors[.TEXT]
    if ctx.focus_id == id || ctx.hover_id == id {
        handle_col = {255, 255, 255, 255}
    }
    mu.draw_rect(ctx, {hx - 1, inner.y, handle_w + 2, inner.h}, {0, 0, 0, 255})
    mu.draw_rect(ctx, {hx, inner.y, handle_w, inner.h}, handle_col)

    // Value text (drawn with a 1px shadow so it stays readable on any gradient).
    text_buf: [121]byte
    text := fmt.bprintf(text_buf[:], fmt_string, val^)
    shadow := mu.Rect{base.x + 1, base.y + 1, base.w, base.h}
    mu.draw_control_text(ctx, text, shadow, .BORDER, opt)
    mu.draw_control_text(ctx, text, base, .TEXT, opt)
    return
}

// color_edit4 edits an RGBA color (0..1) as a preview bar + four gradient
// sliders, each track showing what the color becomes along that channel.
color_edit4 :: proc(ctx: ^mu.Context, color: ^[4]f32) -> (changed: bool) {
    mu.push_id(ctx, uintptr(color))
    defer mu.pop_id(ctx)

    // Preview well (no id: never steals input).
    mu.layout_row(ctx, {-1}, 18)
    well := mu.layout_next(ctx)
    mu.draw_box(ctx, well, ctx.style.colors[.BORDER])
    mu.draw_rect(ctx, {well.x + 1, well.y + 1, well.w - 2, well.h - 2}, to_mu_color(color^))

    names := [4]string{"R", "G", "B", "A"}
    for i in 0 ..< 4 {
        lo, hi := color^, color^
        lo[i], hi[i] = 0, 1
        // Alpha track: show the color's RGB, fading from black to full.
        if i == 3 {
            lo = {0, 0, 0, 1}
            hi = {color[0], color[1], color[2], 1}
        } else {
            lo[3], hi[3] = 1, 1
        }

        mu.layout_row(ctx, {14, -1}, 0)
        mu.label(ctx, names[i])
        if .CHANGE in color_slider(ctx, &color[i], to_mu_color(lo), to_mu_color(hi)) {
            changed = true
        }
    }
    return
}

// Bar colors for the R, G, B, A cells.
CHANNEL_BAR_COLORS := [4]mu.Color {
    {230, 60, 60, 255},
    {70, 200, 70, 255},
    {70, 110, 240, 255},
    {150, 150, 150, 255},
}

// color_preview draws a framed color well. Colors with alpha < 1 are drawn
// over a small checkerboard so transparency is visible.
color_preview :: proc(ctx: ^mu.Context, rect: mu.Rect, c: [4]f32) {
    mu.draw_box(ctx, rect, ctx.style.colors[.BORDER])
    inner := mu.Rect{rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2}

    col := mu.Color {
        u8(clamp(c[0], 0, 1) * 255),
        u8(clamp(c[1], 0, 1) * 255),
        u8(clamp(c[2], 0, 1) * 255),
        u8(clamp(c[3], 0, 1) * 255),
    }

    if col.a < 255 {
        hw, hh := inner.w / 2, inner.h / 2
        light := mu.Color{200, 200, 200, 255}
        dark := mu.Color{120, 120, 120, 255}
        mu.draw_rect(ctx, {inner.x, inner.y, hw, hh}, light)
        mu.draw_rect(ctx, {inner.x + hw, inner.y, inner.w - hw, hh}, dark)
        mu.draw_rect(ctx, {inner.x, inner.y + hh, hw, inner.h - hh}, dark)
        mu.draw_rect(ctx, {inner.x + hw, inner.y + hh, inner.w - hw, inner.h - hh}, light)
    }
    mu.draw_rect(ctx, inner, col)
}

// ---------------------------------------------------------------------------
// Channel <-> 0..255 conversion. Float channels are 0..1, integer channels
// are already 0..255 (u8, int, ...).
// ---------------------------------------------------------------------------

@(private = "file")
channel_to_byte :: proc(v: $T) -> mu.Real where intr.type_is_numeric(T) {
    when intr.type_is_float(T) {
        return mu.Real(int(clamp(v, 0, 1) * 255 + 0.5))
    } else {
        return mu.Real(clamp(int(v), 0, 255))
    }
}

@(private = "file")
channel_from_byte :: proc($T: typeid, b: mu.Real) -> T where intr.type_is_numeric(T) {
    when intr.type_is_float(T) {
        return T(b) / 255 // divide in T's own precision (matters for f64)
    } else {
        return T(b)
    }
}

// ---------------------------------------------------------------------------
// The widget itself: works on `n` (3 or 4) channels in 0..255 space and tells
// the caller which channels changed, so untouched channels are never
// re-quantized.
// ---------------------------------------------------------------------------

@(private = "file")
color_edit_row_impl :: proc(
    ctx: ^mu.Context,
    id: uintptr,
    vals: ^[4]mu.Real,
    n: int,
    label: string,
    label_width: i32,
) -> (
    changed: [4]bool,
) {
    @(static) tmp: mu.Real

    mu.push_id(ctx, id)
    defer mu.pop_id(ctx)

    // One full-width row; we slice it up ourselves with absolute rects.
    mu.layout_row(ctx, {-1}, 0)
    row := mu.layout_next(ctx)

    sp := ctx.style.spacing
    box_w := row.h
    has_label := len(label) > 0
    label_w: i32 = 0
    if has_label {
        label_w = label_width
        if label_w <= 0 {
            label_w = ctx.text_width(ctx.style.font, label) + ctx.style.padding * 2
        }
    }
    gaps := i32(n) + (has_label ? 1 : 0) // items: n cells + preview (+ label)
    cells_w := max(row.w - box_w - label_w - gaps * sp, i32(n) * 8)
    cell_w := cells_w / i32(n)

    x := row.x
    for i in 0 ..< n {
        cell := mu.Rect{x, row.y, cell_w, row.h}
        x += cell_w + sp

        mu.push_id(ctx, id + uintptr(i) + 1) // keeps ids distinct: they all share `tmp`
        tmp = vals[i]
        mu.layout_set_next(ctx, cell, false)
        // Inlined mu.number with one difference: the working value is
        // clamped before it is drawn and stored, so a drag past either end
        // holds at the bound instead of overshooting until release.
        // mu.number draws its unclamped working value (same snap-back bug
        // as color_row had before its fix).
        rect := mu.layout_next(ctx)
        nid := mu.get_id(ctx, uintptr(&tmp))
        if mu.number_textbox(ctx, &tmp, rect, nid, "%.0f") {
            mu.pop_id(ctx)
            continue
        }
        mu.update_control(ctx, nid, rect, {.ALIGN_CENTER})
        if ctx.focus_id == nid && .LEFT in ctx.mouse_down_bits {
            tmp += mu.Real(ctx.mouse_delta.x)
        }
        tmp = clamp(tmp, 0, 255)
        if tmp != vals[i] {
            vals[i] = clamp(mu.Real(int(tmp + 0.5)), 0, 255)
            changed[i] = true
        }
        mu.draw_control_frame(ctx, nid, rect, .BASE, {.ALIGN_CENTER})
        text_buf: [121]byte
        mu.draw_control_text(
            ctx, fmt.bprintf(text_buf[:], "%.0f", tmp), rect, .TEXT, {.ALIGN_CENTER})
        mu.pop_id(ctx)

        // Channel bar on top of the cell's left edge.
        mu.draw_rect(ctx, {cell.x + 1, cell.y + 1, 3, cell.h - 2}, CHANNEL_BAR_COLORS[i])
    }

    // Preview well (no id: never steals input).
    color_preview(
        ctx,
        {x, row.y, box_w, row.h},
        {vals[0] / 255, vals[1] / 255, vals[2] / 255, vals[3] / 255},
    )
    x += box_w + sp

    // Label (optional).
    if has_label {
        mu.draw_control_text(ctx, label, {x, row.y, row.x + row.w - x, row.h}, .TEXT, {})
    }
    return
}

color_edit_row_array :: proc(
    ctx: ^mu.Context,
    color: ^[$N]$T,
    label: string = "",
    label_width: i32 = 0,
) -> (
    changed: bool,
) where (N == 3 || N == 4), intr.type_is_numeric(T) {
    vals := [4]mu.Real{0, 0, 0, 255}
    for i in 0 ..< N {
        vals[i] = channel_to_byte(color[i])
    }

    ch := color_edit_row_impl(ctx, uintptr(color), &vals, N, label, label_width)

    for i in 0 ..< N {
        if ch[i] {
            color[i] = channel_from_byte(T, vals[i])
            changed = true
        }
    }
    return
}

color_edit_row_color :: proc(
    ctx: ^mu.Context,
    color: ^mu.Color,
    label: string = "",
    label_width: i32 = 0,
) -> (
    changed: bool,
) {
    vals := [4]mu.Real{mu.Real(color.r), mu.Real(color.g), mu.Real(color.b), mu.Real(color.a)}

    ch := color_edit_row_impl(ctx, uintptr(color), &vals, 4, label, label_width)

    if ch[0] {color.r = u8(vals[0])}
    if ch[1] {color.g = u8(vals[1])}
    if ch[2] {color.b = u8(vals[2])}
    if ch[3] {color.a = u8(vals[3])}
    return ch[0] || ch[1] || ch[2] || ch[3]
}

// Edits a color in a single row:
//
//   [ R ][ G ][ B ][ A ]  [preview]  label (optional)
//
// Accepted types:
//
//     [3]T / [4]T for any numeric T. Float channels are 0..1, integer channels
//               are 0..255 (so [4]f32, [3]f64, [4]u8, [4]int all work).
//     mu.Color  (RGBA, u8)
//
// Each cell shows 0..255, has a small vertical bar in its channel color, and
// behaves like mu.number: drag horizontally to change, shift+click to type.
// The cells stretch to fill the row. The label is optional: with an empty label
// nothing is reserved for it. `label_width` <= 0 sizes the label to its text;
// pass the same fixed width to several rows to keep their cells aligned.
// Returns true if any channel changed.
color_edit_row :: proc {
    color_edit_row_array,
    color_edit_row_color,
}
