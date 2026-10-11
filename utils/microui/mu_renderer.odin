package microui_gpu

// Core
import "base:runtime"
import "core:log"
import la "core:math/linalg"

// Vendor
import mu "vendor:microui"
import "../../gpu"

BUFFER_SIZE :: 16384

Vertex :: struct {
    position:  [2]f32,
    tex_coord: [2]f32,
    color:     [4]u8,
}

Renderer :: struct {
    device:             gpu.Device,
    queue:              gpu.Queue,
    atlas_texture:      gpu.Texture,
    atlas_texture_view: gpu.Texture_View,
    pipeline_layout:    gpu.Pipeline_Layout,
    pipeline:           gpu.Render_Pipeline,
    const_buffer:       gpu.Buffer,
    vertex_buffer:      gpu.Buffer,
    index_buffer:       gpu.Buffer,
    sampler:            gpu.Sampler,
    bind_group_layout:  gpu.Bind_Group_Layout,
    bind_group:         gpu.Bind_Group,
    target_width:       u32,
    target_height:      u32,
    curr_pass:          gpu.Render_Pass,
    vert_buf:           [BUFFER_SIZE * 4]Vertex,
    index_buf:          [BUFFER_SIZE * 6]u32,
    prev_buf_idx:       u32,
    buf_idx:            u32,
}

Init_Info :: struct {
    device:                     gpu.Device,
    target_format:              gpu.Texture_Format,
    depth_stencil_format:       gpu.Texture_Format,
    pipeline_multisample_state: gpu.Multisample_State,
}

DEFAULT_INIT_INFO :: Init_Info {
    device                     = nil,
    target_format              = .Undefined,
    depth_stencil_format       = .Undefined,
    pipeline_multisample_state = gpu.DEFAULT_MULTISAMPLE_STATE,
}

init :: proc(r: ^Renderer, info: Init_Info, loc := #caller_location) {
    assert(r != nil, "MicroUI: invalid renderer", loc)
    assert(info.device != nil, "MicroUI: invalid device", loc)
    assert(info.target_format != .Undefined, "MicroUI: invalid target format", loc)

    r.device = info.device
    r.queue = gpu.device_get_queue(info.device)
    gpu.device_add_ref(info.device)

    r.const_buffer = gpu.device_create_buffer(r.device, {
        label = "MicroUI Constant buffer",
        usage = { .Uniform, .Copy_Dst },
        size  = size_of(la.Matrix4x4f32),
    })

    r.atlas_texture = gpu.device_create_texture(r.device, {
        label           = "MicroUI Atlas",
        usage           = {.Texture_Binding, .Copy_Dst},
        dimension       = .D2,
        size            = {mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1},
        mip_level_count = 1,
        format          = .RGBA8_Unorm,
        sample_count    = 1,
    })
    r.atlas_texture_view = gpu.texture_create_view(r.atlas_texture)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = context.allocator == ta)

    // mu.default_atlas_alpha is one alpha byte per pixel. The atlas texture
    // is RGBA8, so expand each alpha value into a full RGBA pixel (white
    // RGB, original value as A) before uploading - and actually upload
    // that expanded buffer, not the raw 1-byte-per-pixel source.
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT, ta)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }

    bytes_per_row: u32 = mu.DEFAULT_ATLAS_WIDTH * 4 // 4 bytes per pixel for RGBA8

    gpu.queue_write_texture(
        queue       = r.queue,
        destination = { texture = r.atlas_texture },
        data        = gpu.to_bytes(pixels),
        data_layout = { 0, bytes_per_row, mu.DEFAULT_ATLAS_HEIGHT },
        write_size  = { mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1 },
    )

    sampler_descriptor := gpu.DEFAULT_SAMPLER_DESCRIPTOR
    // NOTE(Capati): Ideally, we would use LINEAR filtering for improved text
    // rendering, especially on high DPI displays. However, this causes texture
    // bleeding. This is likely due to the tight packing of glyphs in the
    // texture atlas.
    sampler_descriptor.min_filter = .Nearest
    sampler_descriptor.mag_filter = .Nearest
    sampler_descriptor.label = "MicroUI Sampler"
    r.sampler = gpu.device_create_sampler(r.device, sampler_descriptor)

    r.vertex_buffer = gpu.device_create_buffer(r.device, {
        label = "MicroUI Vertex Buffer",
        usage = { .Vertex, .Copy_Dst },
        size  = size_of(r.vert_buf),
    })
    r.index_buffer = gpu.device_create_buffer(r.device, {
        label = "MicroUI Index Buffer",
        usage = { .Index, .Copy_Dst },
        size  = size_of(r.index_buf),
    })

    r.bind_group_layout = gpu.device_create_bind_group_layout(r.device, {
        label = "MicroUI Bind Group Layout",
        entries = {
            {
                binding = 0,
                visibility = { .Vertex },
                type = gpu.Buffer_Binding_Layout {
                    type = .Uniform,
                    min_binding_size = size_of(la.Matrix4x4f32),
                },
            },
            {
                binding = 1,
                visibility = {.Fragment},
                type = gpu.Texture_Binding_Layout {
                    multisampled = false,
                    view_dimension = .D2,
                    sample_type = .Float,
                },
            },
            {
                binding = 2,
                visibility = {.Fragment},
                type = gpu.Sampler_Binding_Layout{ type = .Filtering },
            },
        },
    })

    r.bind_group = gpu.device_create_bind_group(r.device, {
        label = "MicroUI Bind Group",
        layout     = r.bind_group_layout,
        entries = {
            {
                binding = 0,
                resource = gpu.Buffer_Binding{
                    buffer = r.const_buffer,
                    size = gpu.WHOLE_SIZE,
                },
            },
            { binding = 1, resource = r.atlas_texture_view },
            { binding = 2, resource = r.sampler },
        },
    })

    r.pipeline_layout = gpu.device_create_pipeline_layout(r.device, {
        label = "MicroUI Pipeline Layout",
        bind_group_layouts = { r.bind_group_layout },
    })

    // Load vertex shader
    vertex_shader := load_shader(r.device, .Vertex)
    defer gpu.shader_module_release(vertex_shader)

    // Load fragment shader
    fragment_shader := load_shader(r.device, .Fragment)
    defer gpu.shader_module_release(fragment_shader)

    depth_stencil_state := gpu.Depth_Stencil_State {
        format = info.depth_stencil_format,
        depth_write_enabled = false,
        depth_compare = .Always,
        stencil = {
            front = {
                compare = .Always,
                fail_op = .Keep,
                depth_fail_op = .Keep,
                pass_op = .Keep,
            },
            back = {
                compare = .Always,
                fail_op = .Keep,
                depth_fail_op = .Keep,
                pass_op = .Keep,
            },
        },
    }

    r.pipeline = gpu.device_create_render_pipeline(r.device, {
        layout = r.pipeline_layout,
        vertex = {
            module      = vertex_shader,
            entry_point  = "vs_main",
            buffers = {
                {
                    array_stride = size_of(Vertex),
                    step_mode = .Vertex,
                    attributes = {
                        {
                            offset = u64(offset_of(Vertex, position)),
                            shader_location = 0,
                            format = .Float32x2,
                        },
                        {
                            offset = u64(offset_of(Vertex, tex_coord)),
                            shader_location = 1,
                            format = .Float32x2,
                        },
                        {
                            offset = u64(offset_of(Vertex, color)),
                            shader_location = 2,
                            format = .Unorm8x4,
                        },
                    },
                },
            },
        },
        fragment = &{
            module      = fragment_shader,
            entry_point  = "fs_main",
            targets = {
                {
                    format = info.target_format,
                    blend = &{
                        alpha = {
                            src_factor = .Src_Alpha,
                            dst_factor = .One_Minus_Src_Alpha,
                            operation  = .Add,
                        },
                        color = {
                            src_factor = .Src_Alpha,
                            dst_factor = .One_Minus_Src_Alpha,
                            operation  = .Add,
                        },
                    },
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        depth_stencil = info.depth_stencil_format != .Undefined ? &depth_stencil_state : nil,
        primitive = {
            topology = .Triangle_List,
            cull_mode = .None,
        },
        multisample = info.pipeline_multisample_state,
    })
}

uninit :: proc(r: ^Renderer, loc := #caller_location) {
    assert(r != nil, "MicroUI: renderer is invalid", loc)

    gpu.bind_group_release(r.bind_group)
    gpu.bind_group_layout_release(r.bind_group_layout)
    gpu.render_pipeline_release(r.pipeline)
    gpu.pipeline_layout_release(r.pipeline_layout)
    gpu.sampler_release(r.sampler)
    gpu.texture_view_release(r.atlas_texture_view)
    gpu.texture_release(r.atlas_texture)
    gpu.buffer_release(r.index_buffer)
    gpu.buffer_release(r.vertex_buffer)
    gpu.buffer_release(r.const_buffer)
    gpu.queue_release(r.queue)
    gpu.device_release(r.device)
    r^ = {}
}

destroy :: uninit

resize :: proc(r: ^Renderer, width, height: u32, dpi: f32 = 1, loc := #caller_location) {
    assert(r != nil, "MicroUI: renderer is invalid", loc)
    assert(width != 0, "MicroUI: width must not be 0", loc)
    assert(height != 0, "MicroUI: height must not be 0", loc)
    assert(dpi != 0, "MicroUI: dpi must not be 0", loc)

    r.target_width, r.target_height = width, height

    fw, fh := f32(width), f32(height)
    transform := la.matrix_ortho3d(0, fw, fh, 0, -1, 1) * la.matrix4_scale(dpi)
    gpu.queue_write_buffer(r.queue, r.const_buffer, 0, &transform, size_of(transform))
}

render :: proc(r: ^Renderer, ctx: ^mu.Context, pass: gpu.Render_Pass, loc := #caller_location) {
    assert(r != nil, "MicroUI: invalid renderer", loc)
    assert(pass != {}, "MicroUI:: invalid render pass", loc)

    r.buf_idx = 0
    r.prev_buf_idx = 0
    r.curr_pass = pass

    bind(r)

    command_backing: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text: draw_text(r, cmd.str, cmd.pos, cmd.color)
        case ^mu.Command_Rect: draw_rect(r, cmd.rect, cmd.color)
        case ^mu.Command_Icon: draw_icon(r, cmd.id, cmd.rect, cmd.color)
        case ^mu.Command_Clip: set_clip_rect(r, cmd.rect)
        case ^mu.Command_Jump: unreachable()
        }
    }

    flush(r)

    if r.buf_idx == 0 {
        r.curr_pass = {}
        return
    }

    gpu.queue_write_buffer_bytes(
        queue  = r.queue,
        buffer = r.vertex_buffer,
        offset = 0,
        data   = gpu.to_bytes(r.vert_buf[:r.buf_idx * 4]),
    )
    gpu.queue_write_buffer_bytes(
        queue  = r.queue,
        buffer = r.index_buffer,
        offset = 0,
        data   = gpu.to_bytes(r.index_buf[:r.buf_idx * 6]),
    )

    r.curr_pass = {}
}

@(private = "file")
bind :: proc(r: ^Renderer) {
    gpu.render_pass_set_pipeline(r.curr_pass, r.pipeline)
    gpu.render_pass_set_bind_group(r.curr_pass, 0, r.bind_group)
    gpu.render_pass_set_vertex_buffer(r.curr_pass, 0, r.vertex_buffer, 0, size_of(r.vert_buf))
    gpu.render_pass_set_index_buffer(r.curr_pass, r.index_buffer, .Uint32, 0, size_of(r.index_buf))
}

@(private = "file")
flush :: proc(r: ^Renderer) {
    if r.buf_idx == 0 || r.buf_idx == r.prev_buf_idx { return }

    delta := uint(r.buf_idx - r.prev_buf_idx)
    gpu.render_pass_draw_indexed(r.curr_pass, u32(delta * 6), 1, r.prev_buf_idx * 6, 0, 0)

    r.prev_buf_idx = r.buf_idx
}

@(private = "file")
push_quad :: proc(r: ^Renderer, dst, src: mu.Rect, color: mu.Color) #no_bounds_check {
    if r.buf_idx >= BUFFER_SIZE {
        // TODO: dynamic grow
        panic("microui vertex buffer overflow")
    }

    vert_idx    := r.buf_idx * 4
    element_idx := u32(r.buf_idx * 4)
    index_idx   := r.buf_idx * 6

    r.buf_idx += 1

    x := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
    y := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
    w := f32(src.w) / mu.DEFAULT_ATLAS_WIDTH
    h := f32(src.h) / mu.DEFAULT_ATLAS_HEIGHT

    dx, dy, dw, dh := f32(dst.x), f32(dst.y), f32(dst.w), f32(dst.h)

    col: [4]u8 = { color.r, color.g, color.b, color.a }

    r.vert_buf[vert_idx + 0] ={ {dx,      dy},      {x,     y},     col }
    r.vert_buf[vert_idx + 1] ={ {dx + dw, dy},      {x + w, y},     col }
    r.vert_buf[vert_idx + 2] ={ {dx,      dy + dh}, {x,     y + h}, col }
    r.vert_buf[vert_idx + 3] ={ {dx + dw, dy + dh}, {x + w, y + h}, col }

    copy(r.index_buf[index_idx:], []u32{
        element_idx + 0,
        element_idx + 1,
        element_idx + 2,
        element_idx + 2,
        element_idx + 3,
        element_idx + 1,
    })
}

@(private = "file")
draw_rect :: proc(r: ^Renderer, rect: mu.Rect, color: mu.Color) {
    push_quad(r, rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

@(private = "file")
draw_text :: proc(r: ^Renderer, text: string, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect{ pos.x, pos.y, 0, 0 }
    for ch in text {
        if ch&0xc0 != 0x80 {
            ch := min(int(ch), 127)
            src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + ch]
            dst.w = src.w
            dst.h = src.h
            push_quad(r, dst, src, color)
            dst.x += dst.w
        }
    }
}

@(private = "file")
draw_icon :: proc(r: ^Renderer, id: mu.Icon, rect: mu.Rect, color: mu.Color) {
    src := mu.default_atlas[id]
    x := rect.x + (rect.w - src.w) / 2
    y := rect.y + (rect.h - src.h) / 2
    push_quad(r, {x, y, src.w, src.h}, src, color)
}

@(private = "file")
set_clip_rect :: proc(r: ^Renderer, rect: mu.Rect) {
    flush(r)

    x0 := clamp(rect.x,          0, i32(r.target_width))
    y0 := clamp(rect.y,          0, i32(r.target_height))
    x1 := clamp(rect.x + rect.w, 0, i32(r.target_width))
    y1 := clamp(rect.y + rect.h, 0, i32(r.target_height))

    gpu.render_pass_set_scissor_rect(
        r.curr_pass,
        u32(x0), u32(y0),
        u32(x1 - x0), u32(y1 - y0),
    )
}
