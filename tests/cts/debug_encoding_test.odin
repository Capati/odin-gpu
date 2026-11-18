package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the WebGPU CTS `api/validation/encoding/cmds/debug.spec.ts`.

cts_debug_kind_group :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    kind: uint,
    push_count, pop_count: uint,
    label: string,
) -> bool {
    texture := cts_query_attachment_texture(f)
    view := gpu.texture_create_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    switch kind {
    case 0:
        for i in 0 ..< push_count {
            gpu.command_encoder_push_debug_group(encoder, label)
        }
        for _ in 0 ..< pop_count {
            gpu.command_encoder_pop_debug_group(encoder)
        }
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }

    case 1:
        pass := cts_begin_query_pass(encoder, view, {})
        for _ in 0 ..< push_count {
            gpu.render_pass_push_debug_group(pass, label)
        }
        for _ in 0 ..< pop_count {
            gpu.render_pass_pop_debug_group(pass)
        }
        gpu.render_pass_end(pass)
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }

    case 2:
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        for _ in 0 ..< push_count {
            gpu.compute_pass_push_debug_group(pass, label)
        }
        for _ in 0 ..< pop_count {
            gpu.compute_pass_pop_debug_group(pass)
        }
        gpu.compute_pass_end(pass)
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }

    case:
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        testing.expect(t, bundle_encoder != {}, "failed to create the bundle encoder")
        for _ in 0 ..< push_count {
            gpu.render_bundle_encoder_push_debug_group(bundle_encoder, label)
        }
        for _ in 0 ..< pop_count {
            gpu.render_bundle_encoder_pop_debug_group(bundle_encoder)
        }
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
        gpu.render_bundle_encoder_release(bundle_encoder)
    }

    errors := cts_errors() - before
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_debug_kind_marker :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    kind: uint,
    label: string,
) -> bool {
    texture := cts_query_attachment_texture(f)
    view := gpu.texture_create_view(texture)
    defer gpu.texture_view_release(view)
    defer gpu.texture_release(texture)

    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")

    switch kind {
    case 0:
        gpu.command_encoder_insert_debug_marker(encoder, label)
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }
    case 1:
        pass := cts_begin_query_pass(encoder, view, {})
        gpu.render_pass_insert_debug_marker(pass, label)
        gpu.render_pass_end(pass)
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }
    case 2:
        pass := gpu.command_encoder_begin_compute_pass(encoder)
        gpu.compute_pass_insert_debug_marker(pass, label)
        gpu.compute_pass_end(pass)
        buffer := gpu.command_encoder_finish(encoder)
        if buffer != {} {
            gpu.command_buffer_release(buffer)
        }
    case:
        formats := [1]gpu.Texture_Format{.RGBA8_Unorm}
        bundle_encoder := gpu.device_create_render_bundle_encoder(f.device, {
            color_formats = formats[:],
            sample_count  = 1,
        })
        testing.expect(t, bundle_encoder != {}, "failed to create the bundle encoder")
        gpu.render_bundle_encoder_insert_debug_marker(bundle_encoder, label)
        bundle := gpu.render_bundle_encoder_finish(bundle_encoder)
        if bundle != {} {
            gpu.render_bundle_release(bundle)
        }
        gpu.render_bundle_encoder_release(bundle_encoder)
    }

    errors := cts_errors() - before
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_debug_group_balanced :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    counts := [3]uint{0, 1, 2}
    any_accepted := false
    any_refused := false

    for kind in 0 ..< 4 {
        for push_count in counts {
            for pop_count in counts {
                balanced := push_count == pop_count
                errors := cts_debug_kind_group(t, f, uint(kind), push_count, pop_count, "g")
                cts_expect_outcome(t, errors ? 1 : 0, !balanced,
                    "debug group balance per encoder kind")
                any_accepted = any_accepted || balanced
                any_refused = any_refused || !balanced
            }
        }
    }
    cts_require_both(t, any_accepted, any_refused, "debug_group_balanced")
}

@(test)
cts_debug_group_labels :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    labels := [5]string{
        "",
        "group",
        "null\x00in\x00group\x00label",
        "\x00null at beginning",
        "sun-hand",
    }

    for kind in 0 ..< 4 {
        for label in labels {
            errors := cts_debug_kind_group(t, f, uint(kind), 1, 1, label)
            cts_expect_outcome(t, errors ? 1 : 0, false,
                "a debug group label is never itself an error")
        }
    }
}

@(test)
cts_debug_marker_labels :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)

    labels := [5]string{
        "",
        "marker",
        "null\x00in\x00marker",
        "\x00null at beginning",
        "sun-hand",
    }

    for kind in 0 ..< 4 {
        for label in labels {
            errors := cts_debug_kind_marker(t, f, uint(kind), label)
            cts_expect_outcome(t, errors ? 1 : 0, false,
                "a debug marker label is never itself an error")
        }
    }
}
