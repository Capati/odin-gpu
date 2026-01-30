package clear_screen

// Core
import "base:builtin"
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"
import la "core:math/linalg"

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"
import "../../utils/tobj"

CLIENT_WIDTH  :: 640
CLIENT_HEIGHT :: 480
EXAMPLE_TITLE :: "OBJ Model"
DEPTH_FORMAT  :: gpu.Texture_Format.Depth24_Plus

MODELS_DIR    :: "assets/models/" // relative to the build folder
OBJ_PYRAMID :: MODELS_DIR + "pyramid.obj"

My_Uniforms :: struct {
    projection_matrix: la.Matrix4f32,
    view_matrix:       la.Matrix4f32,
    model_matrix:      la.Matrix4f32,
}

Vertex_Attributes :: struct {
    position: la.Vector3f32,
    normal:   la.Vector3f32,
    color:    la.Vector3f32,
}

Application :: struct {
    using gc:           app.GPU_Context,

    vertex_buffer:      gpu.Buffer,
    uniform_buffer:     gpu.Buffer,
    render_pipeline:    gpu.Render_Pipeline,
    depth_view:         gpu.Texture_View,
    uniform_bind_group: gpu.Bind_Group,
    index_count:        u32,

    rpass:              struct {
        colors:                   [1]gpu.Render_Pass_Color_Attachment,
        depth_stencil_attachment: gpu.Render_Pass_Depth_Stencil_Attachment,
        descriptor:               gpu.Render_Pass_Descriptor,
    },
}

init :: proc(appstate: ^^Application) -> (res: app.App_Result) {
    // Allocate new application state
    appstate^ = new(Application)
    self := appstate^
    self.gc = app.get_gpu_context()

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // Load mesh data from OBJ file
    vertex_data := load_geometry_from_obj(ta) or_return

    // Create vertex buffer
    self.vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Vertex buffer",
            usage = { .Copy_Dst, .Vertex },
        },
        vertex_data[:],
    )

    // Load shaders
    vertex_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Vertex Shader",
            code = shaders.load(self.device, .Vertex),
            stage = .Vertex,
        },
    )
    defer gpu.release(vertex_shader)

    fragment_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Fragment Shader",
            code = shaders.load(self.device, .Fragment),
            stage = .Fragment,
        },
    )
    defer gpu.release(fragment_shader)

    // Create binding layout
    bind_group_layout := gpu.device_create_bind_group_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Bind Group Layout",
            entries = {
                {
                    binding = 0,
                    visibility = { .Vertex, .Fragment },
                    type = gpu.Buffer_Binding_Layout {
                        type = .Uniform,
                        has_dynamic_offset = false,
                        min_binding_size = size_of(My_Uniforms),
                    },
                },
            },
        },
    )
    defer gpu.release(bind_group_layout)

    // Create the pipeline layout
    pipeline_layout := gpu.device_create_pipeline_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Pipeline Layout",
            bind_group_layouts = { bind_group_layout },
        },
    )
    defer gpu.release(pipeline_layout)

    // Vertex fetch
    vertex_buffer_layout := gpu.Vertex_Buffer_Layout {
        array_stride = size_of(Vertex_Attributes),
        step_mode = .Vertex,
        attributes = {
            {
                shader_location = 0,
                format = .Float32x3,
                offset = 0,
            },
            {
                shader_location = 1,
                format = .Float32x3,
                offset = u64(offset_of(Vertex_Attributes, normal)),
            },
            {
                shader_location = 2,
                format = .Float32x3,
                offset = u64(offset_of(Vertex_Attributes, color)),
            },
        },
    }

    pipeline_descriptor := gpu.Render_Pipeline_Descriptor {
        label = EXAMPLE_TITLE + " Render Pipeline",
        layout = pipeline_layout,
        vertex = {
            module = vertex_shader,
            entry_point = "vs_main",
            buffers = { vertex_buffer_layout },
        },
        fragment = &{
            module = fragment_shader,
            entry_point = "fs_main",
            targets = {
                {
                    format = self.config.format,
                    blend = &gpu.BLEND_STATE_NORMAL,
                    write_mask = gpu.COLOR_WRITES_ALL,
                },
            },
        },
        depth_stencil = &{
            format = DEPTH_FORMAT,
            depth_write_enabled = true,
            depth_compare = .Less,
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
                read_mask = 0xFFFFFFFF,
                write_mask = 0xFFFFFFFF,
            },
        },
        primitive = {
            topology   = .Triangle_List,
            front_face = .Ccw,
            cull_mode = .Back,
        },
        multisample = gpu.MULTISAMPLE_STATE_DEFAULT,
    }

    self.render_pipeline = gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops = {
            load = .Clear,
            store = .Store,
            clear_value = { 0.16, 0.16, 0.18, 1.0 },
        },
    }

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = &self.rpass.depth_stencil_attachment,
    }

    create_depth_framebuffer(self)

    self.uniform_buffer = gpu.device_create_buffer(
        self.device,
        {
            label = EXAMPLE_TITLE + " Uniform Buffer",
            size  = size_of(My_Uniforms),
            usage = { .Uniform, .Copy_Dst },
        },
    )

    upload_uniforms(self, self.config.width, self.config.height)

    self.index_count = u32(len(vertex_data))

    self.uniform_bind_group = gpu.device_create_bind_group(
        self.device,
        {
            layout = bind_group_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = self.uniform_buffer,
                        size = gpu.buffer_get_size(self.uniform_buffer),
                    },
                },
            },
        },
    )

    return .Continue
}

load_geometry_from_obj :: proc(
    allocator := context.allocator,
) -> (
    vertex_data: []Vertex_Attributes,
    res: app.App_Result,
) #no_bounds_check {
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = allocator == ta)

    // Call the core loading procedure of tobj
    when ODIN_OS == .JS {
        obj_bytes, obj_bytes_ok := app.load_file(OBJ_PYRAMID, ta)
        if !obj_bytes_ok {
            log.panic("Failed to load [%s]", OBJ_PYRAMID)
        }
        models, _, obj_err := tobj.load_obj_bytes(obj_bytes, allocator = ta)
    } else {
        models, _, obj_err := tobj.load_obj_filename(OBJ_PYRAMID, allocator = ta)
    }
    if obj_err != nil {
        log.errorf("Could not load geometry %s: %v", OBJ_PYRAMID, obj_err)
        res = .Failure
        return
    }

    data := make([dynamic]Vertex_Attributes, allocator)

    for &model in models {
        offset := len(data)
        mesh := &model.mesh

        builtin.resize(&data, offset + len(mesh.indices))

        // Fill in vertex data for each index
        for i in 0..<len(mesh.indices) {
            idx := mesh.indices[i]

            // Position (apply coordinate system transform)
            if len(mesh.positions) > 0 {
                data[offset + i].position = {
                    mesh.positions[3 * idx + 0],
                    -mesh.positions[3 * idx + 2], // Add a minus to avoid mirroring
                    mesh.positions[3 * idx + 1],
                }
            }

            // Normal (also apply the transform to normals!)
            if len(mesh.normals) > 0 {
                data[offset + i].normal = {
                    mesh.normals[3 * idx + 0],
                    -mesh.normals[3 * idx + 2],
                    mesh.normals[3 * idx + 1],
                }
            }

            // Color
            if len(mesh.vertex_color) > 0 {
                data[offset + i].color = {
                    mesh.vertex_color[3 * idx + 0],
                    mesh.vertex_color[3 * idx + 1],
                    mesh.vertex_color[3 * idx + 2],
                }
            } else {
                // Default color if no vertex colors specified
                data[offset + i].color = {1.0, 1.0, 1.0}
            }
        }
    }

    return data[:], .Continue
}

create_depth_framebuffer :: proc(self: ^Application) {
    adapter_features := gpu.adapter_get_features(self.adapter)
    format_features :=
        gpu.texture_format_guaranteed_format_features(DEPTH_FORMAT, adapter_features)

    // Check if render attachment is supported
    assert(.Render_Attachment in format_features.allowed_usages,
           "Depth format does not support render attachment")

    width, height := app.get_framebuffer_size()

    texture_descriptor := gpu.Texture_Descriptor {
        size            = { width, height, 1 },
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = DEPTH_FORMAT,
        usage           = { .Copy_Src, .Copy_Dst, .Render_Attachment },
    }

    texture := gpu.device_create_texture(self.device, texture_descriptor)
    defer gpu.release(texture)

    self.depth_view = gpu.texture_create_view(texture)

    // Setup depth stencil attachment
    self.rpass.depth_stencil_attachment = {
        view = self.depth_view,
        depth_ops = {
            load        = .Clear,
            store       = .Store,
            clear_value = 1.0,
        },
    }
}

upload_uniforms :: proc(self: ^Application, width, height: u32) {
    uniforms: My_Uniforms

    // Convert Z-up to Y-up
    z_up_to_y_up := la.matrix4_rotate_f32(-math.PI / 2, {1.0, 0.0, 0.0})
    scale := la.matrix4_scale_f32({1.0, 1.0, 1.0})
    uniforms.model_matrix = z_up_to_y_up * scale

    eye := la.Vector3f32{2.1, 1.1, 2.1}
    center := la.Vector3f32{0.0, 0.0, 0.0}
    up := la.Vector3f32{0.0, 1.0, 0.0}
    uniforms.view_matrix = la.matrix4_look_at_f32(eye, center, up)

    aspect := f32(width) / f32(height)
    uniforms.projection_matrix = la.matrix4_perspective_f32(
        math.PI / 4,
        aspect,
        0.1,
        100.0,
    )

    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(uniforms),
    )
}

resize :: proc(self: ^Application, width, height: u32) {
    gpu.texture_view_release(self.depth_view)
    create_depth_framebuffer(self)
    upload_uniforms(self, width, height)
}

quit :: proc(self: ^Application, res: app.App_Result) {
    gpu.release(self.uniform_bind_group)
    gpu.release(self.uniform_buffer)
    gpu.release(self.depth_view)
    gpu.release(self.render_pipeline)
    gpu.release(self.vertex_buffer)
    free(self)
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.command_encoder_release(encoder)

    self.rpass.colors[0].view = frame.view
    rpass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.render_pass_release(rpass)

    gpu.render_pass_set_pipeline(rpass, self.render_pipeline)
    gpu.render_pass_set_bind_group(rpass, 0, self.uniform_bind_group)
    gpu.render_pass_set_vertex_buffer(rpass, 0, self.vertex_buffer)
    gpu.render_pass_draw(rpass, { 0, self.index_count })

    gpu.render_pass_end(rpass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.command_buffer_release(cmdbuf)

    gpu.queue_submit(self.queue, { cmdbuf })
    gpu.surface_present(self.surface)

    return .Continue
}

event :: proc(self: ^Application, event: app.Event) -> (ok: bool) {
    #partial switch &ev in event {
        case app.Resize_Event:
            resize(self, ev.width, ev.height)
    }
    return true
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})
        defer log.destroy_console_logger(context.logger)

        // TODO(Capati): WASM requires additional flags for the tracking allocator?
        when ODIN_OS != .JS {
            track: mem.Tracking_Allocator
            mem.tracking_allocator_init(&track, context.allocator)
            context.allocator = mem.tracking_allocator(&track)

            defer {
                if len(track.allocation_map) > 0 {
                    log.warnf("=== %v allocations not freed: ===", len(track.allocation_map))
                    for _, entry in track.allocation_map {
                        log.debugf("- %v bytes @ %v", entry.size, entry.location)
                    }
                }
                mem.tracking_allocator_destroy(&track)
            }
        }
    }

    // Set main callbacks
    app.init_proc = cast(app.App_Init_Proc)init
    app.quit_proc = cast(app.App_Quit_Proc)quit
    app.iterate_proc = cast(app.App_Iterate_Proc)iterate
    app.event_proc = cast(app.App_Event_Proc)event

    // Initialize framework and run application
    app.init(EXAMPLE_TITLE, CLIENT_WIDTH, CLIENT_HEIGHT)
}
