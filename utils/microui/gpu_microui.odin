package gpu_microui

// Core
import la "core:math/linalg"
import intr "base:intrinsics"

// Vendor
import mu "vendor:microui"

// Local packages
import gpu "../../"

BUFFER_SIZE :: 16384

Vertex :: struct {
    position:  [2]f32,
    tex_coord: [2]f32,
    color:     [4]u8,
}

// Information about the WebGPU context.
Init_Info :: struct {
    device:                     gpu.Device,
    num_frames_in_flight:       u32,
    format:                     gpu.Texture_Format,
    width:                      u32,
    height:                     u32,
    depth_stencil_format:       gpu.Texture_Format,
    pipeline_multisample_state: gpu.Multisample_State,
}

// Global renderer state
@(private = "file")
r := struct {
    // Settings
    info:                    Init_Info,

    // WGPU Context
    device:                  gpu.Device,
    queue:                   gpu.Queue,

    // Initialization
    const_buffer:            gpu.Buffer,
    atlas_texture:           gpu.Texture,
    atlas_view:              gpu.Texture_View,
    atlas_sampler:           gpu.Sampler,
    bind_group:              gpu.Bind_Group,
    render_pipeline:         gpu.Render_Pipeline,
    vertex_buffer:           gpu.Buffer,
    index_buffer:            gpu.Buffer,

    // Buffers
    vert_buf:                [BUFFER_SIZE * 4]Vertex,
    index_buf:               [BUFFER_SIZE * 6]u32,
    prev_buf_idx:            u32,
    buf_idx:                 u32,

    // State
    current_pass:            gpu.Render_Pass,
    viewport_width:          f32,
    viewport_height:         f32,
}{}

MICROUI_FRAMES_IN_FLIGHT_DEFAULT :: #config(MICROUI_FRAMES_IN_FLIGHT, 3)

MICROUI_INIT_INFO_DEFAULT :: Init_Info {
    num_frames_in_flight       = MICROUI_FRAMES_IN_FLIGHT_DEFAULT,
    depth_stencil_format       = .Undefined,
    pipeline_multisample_state = gpu.MULTISAMPLE_STATE_DEFAULT,
}

// Initializes the WebGPU renderer for MicroUI.
init :: proc(info: Init_Info, loc := #caller_location) {
    r.info = info

    assert(info.device != nil, loc = loc)
    assert(info.format != .Undefined, loc = loc)

    r.device = r.info.device
    gpu.device_add_ref(r.device)

    r.queue = gpu.device_get_queue(r.device)

    r.const_buffer = gpu.device_create_buffer(r.device, {
        label = "Constant buffer",
        usage = { .Uniform, .Copy_Dst },
        size  = size_of(la.Matrix4x4f32),
    })

    r.atlas_texture = gpu.device_create_texture(
        r.device,
        {
            label           = "MicroUI Atlas",
            usage           = {.Texture_Binding, .Copy_Dst},
            dimension       = .D2,
            size            = {mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1},
            format          = .Rgba8_Unorm,
            mip_level_count = 1,
            sample_count    = 1,
        },
    )

    // The mu.default_atlas_alpha contains only alpha channel data for the Atlas
    // image We need to convert this single-channel (alpha) data to full RGBA
    // format. This involves expanding each alpha value into a complete RGBA
    // pixel where R, G, and B will be set to white by default and the original
    // alpha value will be used for the A channel
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }
    defer delete(pixels)

    bytes_per_row: u32 = mu.DEFAULT_ATLAS_WIDTH * 4 // 4 bytes per pixel for RGBA8

    gpu.queue_write_texture(
        r.queue,
        gpu.texture_as_image_copy(r.atlas_texture),
        gpu.to_bytes(pixels),
        { bytes_per_row = bytes_per_row, rows_per_image = mu.DEFAULT_ATLAS_HEIGHT },
        { mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1 },
    )

    r.atlas_view = gpu.texture_create_view(r.atlas_texture)

    sampler_descriptor := gpu.SAMPLER_DESCRIPTOR_DEFAULT
    // FIXME(Capati): Ideally, we would use LINEAR filtering for improved text
    // rendering, especially on high DPI displays. However, this causes texture
    // bleeding. This is likely due to the tight packing of glyphs in the
    // texture atlas.
    sampler_descriptor.min_filter = .Nearest
    sampler_descriptor.mag_filter = .Nearest

    r.atlas_sampler = gpu.device_create_sampler(r.device, sampler_descriptor)

    bind_group_layout := gpu.device_create_bind_group_layout(
        r.device,
        {
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
        },
    )
    defer gpu.release(bind_group_layout)

    r.bind_group = gpu.device_create_bind_group(
        r.device,
        {
            label = "MicroUI Bind Group",
            layout = bind_group_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding{
                        buffer = r.const_buffer,
                        size = gpu.WHOLE_SIZE,
                    },
                },
                { binding = 1, resource = r.atlas_view },
                { binding = 2, resource = r.atlas_sampler },
            },
        },
    )

    pipeline_layout := gpu.device_create_pipeline_layout(
        r.device,
        {
            label = "MicroUI Pipeline Layout",
            bind_group_layouts = { bind_group_layout },
        },
    )
    defer gpu.release(pipeline_layout)

    vertex_source: []u8
    fragment_source: []u8

    // Load the correct shader for the current platform and backend
    when ODIN_OS == .JS {
        vertex_source = #load("./shaders/WGSL/microui.vert.wgsl")
        fragment_source = #load("./shaders/WGSL/microui.frag.wgsl")
    } else {
        #partial switch gpu.device_get_backend(r.device) {
        case .Vulkan:
            vertex_source = #load("./shaders/SPIRV/microui.vert.spv")
            fragment_source = #load("./shaders/SPIRV/microui.frag.spv")

        case .Dx11:
            vertex_source = #load("./shaders/DXBC/microui.vert.dxbc")
            fragment_source = #load("./shaders/DXBC/microui.frag.dxbc")

        case .Gl:
            when ODIN_OS == .Windows || ODIN_OS == .Linux {
                vertex_source = #load("./shaders/GLSL/microui.vert")
                fragment_source = #load("./shaders/GLSL/microui.frag")
            } else {
                panic("OpenGL backend not supported on this platform")
            }

        case .Metal:
            when ODIN_OS == .Darwin {
                vertex_source = #load("./shaders/MSL/microui.vert.metal")
                fragment_source = #load("./shaders/MSL/microui.frag.metal")
            } else {
                panic("Metal backend only supported on macOS")
            }

        case:
            panic("Unsupported backend", loc)
        }
    }

    vertex_shader := gpu.device_create_shader_module(
        r.device,
        {
            label = "MicroUI Vertex Shader",
            code = vertex_source,
            stage = .Vertex,
        },
    )
    defer gpu.release(vertex_shader)

    fragment_shader := gpu.device_create_shader_module(
        r.device,
        {
            label = "MicroUI Fragment Shader",
            code = fragment_source,
            stage = .Fragment,
        },
    )
    defer gpu.release(fragment_shader)

    depth_stencil_state := gpu.Depth_Stencil_State {
        format = r.info.depth_stencil_format,
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

    r.render_pipeline = gpu.device_create_render_pipeline(
        r.device,
        {
            label = "MicroUI Pipeline",
            layout = pipeline_layout,
            vertex = {
                module = vertex_shader,
                entry_point = "vs_main",
                buffers = {
                    {
                        array_stride = size_of(Vertex),
                        step_mode = .Vertex,
                        attributes = {
                            {
                                offset = 0,
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
                module = fragment_shader,
                entry_point = "fs_main",
                targets = {
                    {
                        format = r.info.format,
                        blend = &gpu.BLEND_STATE_NORMAL,
                        write_mask = gpu.COLOR_WRITES_ALL,
                    },
                },
            },
            depth_stencil = r.info.depth_stencil_format != .Undefined ? &depth_stencil_state : nil,
            primitive = {
                topology = .Triangle_List,
                strip_index_format = .Undefined,
                front_face = .Ccw,
                cull_mode = .None,
            },
            multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
        },
    )

    r.viewport_width = f32(r.info.width)
    r.viewport_height = f32(r.info.height)

    r.vertex_buffer = gpu.device_create_buffer(
        r.device,
        {
            label = "MicroUI Vertex Buffer",
            usage = {.Vertex, .Copy_Dst},
            size = size_of(r.vert_buf),
        },
    )

    r.index_buffer = gpu.device_create_buffer(
        r.device,
        {
            label = "MicroUI Index Buffer",
            usage = {.Index, .Copy_Dst},
            size = size_of(r.index_buf),
        },
    )

    write_consts(r.info.width, r.info.height, 1.0)
}

destroy :: proc() {
    gpu.release(r.index_buffer)
    gpu.release(r.vertex_buffer)
    gpu.release(r.render_pipeline)
    gpu.release(r.bind_group)
    gpu.release(r.atlas_sampler)
    gpu.release(r.atlas_view)
    gpu.release(r.atlas_texture)
    gpu.release(r.const_buffer)

    gpu.release(r.queue)
    gpu.release(r.device)
}

write_consts :: proc(width, height: u32, dpi: f32) {
    fw, fh := f32(width), f32(height)
    transform := la.matrix_ortho3d(0, fw, fh, 0, -1, 1) * la.matrix4_scale(dpi)
    gpu.queue_write_buffer(r.queue, r.const_buffer, 0, gpu.to_bytes(transform))
}

resize :: proc(#any_int width, height: u32) {
    r.info.width = width
    r.info.height = height
    r.viewport_width = f32(width)
    r.viewport_height = f32(height)
    write_consts(width, height, 1.0)
}

// Begins rendering with the specified pass
begin :: proc(pass: gpu.Render_Pass) {
    r.current_pass = pass
    r.buf_idx = 0
    r.prev_buf_idx = 0

    gpu.render_pass_set_viewport(
        r.current_pass,
        0,
        0,
        r.viewport_width,
        r.viewport_height,
        0,
        1,
    )

    gpu.render_pass_set_scissor_rect(
        r.current_pass,
        0,
        0,
        u32(r.viewport_width),
        u32(r.viewport_height),
    )

    bind()
}

bind :: proc() {
    gpu.render_pass_set_pipeline(r.current_pass, r.render_pipeline)
    gpu.render_pass_set_bind_group(r.current_pass, 0, r.bind_group)
    gpu.render_pass_set_vertex_buffer(r.current_pass, 0, r.vertex_buffer, 0, size_of(r.vert_buf))
    gpu.render_pass_set_index_buffer(
        r.current_pass,
        r.index_buffer,
        .Uint32,
        0,
        size_of(r.index_buf),
    )
}

flush :: proc() {
    if r.buf_idx <= r.prev_buf_idx {
        return
    }

    delta := u32(r.buf_idx - r.prev_buf_idx)
    first_index := r.prev_buf_idx * 6
    index_count := delta * 6

    gpu.render_pass_draw_indexed(
        r.current_pass,
        { first_index, first_index + index_count },
        0,
    )

    r.prev_buf_idx = r.buf_idx
}

submit :: proc() {
    flush()

    gpu.queue_write_buffer(r.queue, r.vertex_buffer, 0, gpu.to_bytes(r.vert_buf[:r.buf_idx*4]))
    gpu.queue_write_buffer(r.queue, r.index_buffer, 0, gpu.to_bytes(r.index_buf[:r.buf_idx*6]))
}

// Renders the MicroUI context
render :: proc(ctx: ^mu.Context) {
    cmd: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &cmd) {
        #partial switch cmd in variant {
        case ^mu.Command_Text:
            draw_text(cmd.str, cmd.pos, cmd.color)
        case ^mu.Command_Rect:
            draw_rect(cmd.rect, cmd.color)
        case ^mu.Command_Icon:
            draw_icon(cmd.id, cmd.rect, cmd.color)
        case ^mu.Command_Clip:
            set_clip_rect(cmd.rect)
        case ^mu.Command_Jump:
            unreachable()
        }
    }

    submit()
}

push_quad :: proc(dst, src: mu.Rect, color: mu.Color) #no_bounds_check {
    if r.buf_idx == BUFFER_SIZE {
        submit()
        r.buf_idx = 0
        r.prev_buf_idx = 0
    }

    vert_idx := r.buf_idx * 4
    index_idx := r.buf_idx * 6
    element_idx := u32(r.buf_idx * 4)

    r.buf_idx += 1

    // Calculate texture coordinates
    x := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
    y := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
    w := f32(src.w) / mu.DEFAULT_ATLAS_WIDTH
    h := f32(src.h) / mu.DEFAULT_ATLAS_HEIGHT

    // Calculate vertex positions
    dx, dy := f32(dst.x), f32(dst.y)
    dw, dh := f32(dst.w), f32(dst.h)

    // Create vertices
    r.vert_buf[vert_idx + 0] = Vertex{{dx, dy}, {x, y}, {}}
    r.vert_buf[vert_idx + 1] = Vertex{{dx + dw, dy}, {x + w, y}, {}}
    r.vert_buf[vert_idx + 2] = Vertex{{dx, dy + dh}, {x, y + h}, {}}
    r.vert_buf[vert_idx + 3] = Vertex{{dx + dw, dy + dh}, {x + w, y + h}, {}}

    // Set color for all vertices
    color := color
    intr.mem_copy_non_overlapping(&r.vert_buf[vert_idx + 0].color, &color, 4)
    intr.mem_copy_non_overlapping(&r.vert_buf[vert_idx + 1].color, &color, 4)
    intr.mem_copy_non_overlapping(&r.vert_buf[vert_idx + 2].color, &color, 4)
    intr.mem_copy_non_overlapping(&r.vert_buf[vert_idx + 3].color, &color, 4)

    // Set indices
    r.index_buf[index_idx + 0] = element_idx + 0
    r.index_buf[index_idx + 1] = element_idx + 1
    r.index_buf[index_idx + 2] = element_idx + 2
    r.index_buf[index_idx + 3] = element_idx + 2
    r.index_buf[index_idx + 4] = element_idx + 3
    r.index_buf[index_idx + 5] = element_idx + 1
}

draw_text :: proc(text: string, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect{pos.x, pos.y, 0, 0}
    for ch in text {
        if ch & 0xc0 != 0x80 {
            r := min(int(ch), 127)
            src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
            dst.w = src.w
            dst.h = src.h
            push_quad(dst, src, color)
            dst.x += dst.w
        }
    }
}

draw_rect :: proc(rect: mu.Rect, color: mu.Color) {
    push_quad(rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

draw_icon :: proc(id: mu.Icon, rect: mu.Rect, color: mu.Color) {
    src := mu.default_atlas[id]
    x := rect.x + (rect.w - src.w) / 2
    y := rect.y + (rect.h - src.h) / 2
    push_quad({x, y, src.w, src.h}, src, color)
}

set_clip_rect :: proc(rect: mu.Rect) {
    flush()

    x := min(u32(rect.x), u32(r.viewport_width))
    y := min(u32(rect.y), u32(r.viewport_height))
    w := min(u32(rect.w), u32(r.viewport_width) - x)
    h := min(u32(rect.h), u32(r.viewport_height) - y)

    // OpenGL scissor uses lower-left origin, flip Y coordinate
    // FIXME(Capati): better way to fix this?
    backend := gpu.device_get_backend(r.device)
    final_y := y
    if backend == .Gl {
        final_y = u32(r.viewport_height) - y - h
    }

    gpu.render_pass_set_scissor_rect(r.current_pass, x, final_y, w, h)
}
