package cube_map

// Core
import "base:runtime"
import "core:log"
import "core:math"
import "core:mem"
import la "core:math/linalg"

// Core image
import "core:image/jpeg"
import "core:image"

_ :: jpeg

// Local packages
import gpu "../../"
import app "../framework"
import "shaders"

CLIENT_WIDTH    :: 640
CLIENT_HEIGHT   :: 480
EXAMPLE_TITLE   :: "Cube Map"
DEPTH_FORMAT    :: gpu.Texture_Format.Depth24_Plus
COLOR_DARK_GRAY :: gpu.Color{0.6, 0.6, 0.6, 1.0}

Texture :: struct {
    size:            gpu.Extent_3D,
    mip_level_count: u32,
    format:          gpu.Texture_Format,
    dimension:       gpu.Texture_Dimension,
    texture:         gpu.Texture,
    view:            gpu.Texture_View,
    sampler:         gpu.Sampler,
}

Application :: struct {
    using gc:          app.GPU_Context,

    // Buffers
    vertex_buffer:     gpu.Buffer,
    index_buffer:      gpu.Buffer,
    uniform_buffer:    gpu.Buffer,

    // Pipeline setup
    bind_group_layout: gpu.Bind_Group_Layout,
    render_pipeline:   gpu.Render_Pipeline,

    // Texture and related resources
    cubemap_texture:   Texture,
    bind_group:        gpu.Bind_Group,
    depth_view:        gpu.Texture_View,

    // Other state variables
    projection_matrix: la.Matrix4f32,
    model_matrix:      la.Matrix4f32,

    // Cache the render pass descriptor
    rpass:             struct {
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

    self.vertex_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Vertex buffer",
            usage = {.Vertex},
        },
        CUBE_VERTEX_DATA,
    )

    self.index_buffer = gpu.device_create_buffer_with_data(
        self.device,
        {
            label = "Index buffer",
            usage = {.Index},
        },
        CUBE_INDICES_DATA,
    )

    self.bind_group_layout = gpu.device_create_bind_group_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Bind Group Layout",
            entries = {
                {
                    binding = 0,
                    visibility = {.Vertex},
                    type = gpu.Buffer_Binding_Layout {
                        type             = .Uniform,
                        min_binding_size = size_of(la.Matrix4f32),
                    },
                },
                {
                    binding = 1,
                    visibility = { .Fragment },
                    type = gpu.Texture_Binding_Layout{
                        sample_type = .Float,
                        view_dimension = .Cube,
                    },
                },
                {
                    binding = 2,
                    visibility = { .Fragment },
                    type = gpu.Sampler_Binding_Layout{ type = .Filtering },
                },
            },
        },
    )

    pipeline_layout := gpu.device_create_pipeline_layout(
        self.device,
        {
            label = EXAMPLE_TITLE + " Pipeline bind group layout",
            bind_group_layouts = { self.bind_group_layout },
        },
    )
    defer gpu.release(pipeline_layout)

    attributes := gpu.vertex_attr_array(2, { 0, .Float32x4 }, { 1, .Float32x2 })
    vertex_buffer_layout := gpu.Vertex_Buffer_Layout {
        array_stride = size_of(Vertex),
        step_mode    = .Vertex,
        attributes   = attributes[:],
    }

    // Load and create a shader module
    vertex_source := shaders.load(self.device, .Vertex)
    vertex_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Vertex Shader",
            code = vertex_source,
            stage = .Vertex,
        },
    )
    defer gpu.release(vertex_shader)

    fragment_source := shaders.load(self.device, .Fragment)
    fragment_shader := gpu.device_create_shader_module(
        self.device,
        {
            label = EXAMPLE_TITLE + " Fragment Shader",
            code = fragment_source,
            stage = .Fragment,
        },
    )
    defer gpu.release(fragment_shader)

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
        primitive = {
            topology = .Triangle_List,
            front_face = .Ccw,
            // Since we are seeing from inside of the cube
            // and we are using the regular cube geometry data with outward-facing normals,
            // the cullMode should be 'front' or 'none'.
            cull_mode = .None,
        },
        // Enable depth testing so that the fragment closest to the camera
        // is rendered in front.
        depth_stencil = &{
            format = DEPTH_FORMAT,
            depth_write_enabled = false,
            depth_compare = .Less_Equal,
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
                read_mask = max(u32),
                write_mask = max(u32),
            },
        },
        multisample = {
            count = 1, // 1 means no sampling
            mask  = max(u32),
        },
    }

    // Create the triangle pipeline
    self.render_pipeline =
        gpu.device_create_render_pipeline(self.device, pipeline_descriptor)

    self.cubemap_texture = create_cubemap_texture_from_files(
        self,
        {
            "./assets/textures/cubemaps/bridge2_px.jpg",
            "./assets/textures/cubemaps/bridge2_nx.jpg",
            "./assets/textures/cubemaps/bridge2_py.jpg",
            "./assets/textures/cubemaps/bridge2_ny.jpg",
            "./assets/textures/cubemaps/bridge2_pz.jpg",
            "./assets/textures/cubemaps/bridge2_nz.jpg",
        },
    )

    self.uniform_buffer = gpu.device_create_buffer(
        self.device,
        {
            label = EXAMPLE_TITLE + " Uniform Buffer",
            size  = size_of(la.Matrix4f32), // 4x4 matrix
            usage = {.Uniform, .Copy_Dst},
        },
    )

    self.bind_group = gpu.device_create_bind_group(
        self.device,
        {
            layout = self.bind_group_layout,
            entries = {
                {
                    binding = 0,
                    resource = gpu.Buffer_Binding {
                        buffer = self.uniform_buffer,
                        size = gpu.buffer_get_size(self.uniform_buffer),
                    },
                },
                { binding = 1, resource = self.cubemap_texture.view },
                { binding = 2, resource = self.cubemap_texture.sampler },
            },
        },
    )

    self.rpass.colors[0] = {
        view = nil, // Assigned later
        ops  = { .Clear, .Store, { 0.0, 0.0, 0.0, 1.0 } },
    }

    create_depth_framebuffer(self)

    self.rpass.descriptor = {
        label                    = "Render pass descriptor",
        color_attachments        = self.rpass.colors[:],
        depth_stencil_attachment = &self.rpass.depth_stencil_attachment,
    }

    self.model_matrix = la.matrix4_scale_f32({1000.0, 1000.0, 1000.0})
    set_projection_matrix(self, self.config.width, self.config.height)

    return .Continue
}

create_cubemap_texture_from_files :: proc(
    self: ^Application,
    file_paths: [6]string,
    loc := #caller_location,
) -> (
    out: Texture,
) {
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    first_img_bytes, first_image_ok := app.load_file(file_paths[0], ta)
    if !first_image_ok {
        log.panic("Failed to load the first cubemap image file", location = loc)
    }

    // Get info of the first image
    first_img, first_img_err := image.load_from_bytes(first_img_bytes, allocator = ta)
    if first_img_err != nil {
        log.panicf("Failed to load bytes the first cubemap image: %v", first_img_err, location = loc)
    }

    // Set defaults
    out.size = { u32(first_img.width), u32(first_img.height), 1 }
    out.mip_level_count = 1 // Assume no mipmaps
    out.format = .Rgba8_Unorm
    out.dimension = .D2

    // Create the cubemap texture
    texture_desc := gpu.Texture_Descriptor {
        label = "Cube Texture",
        size = {
            width = u32(first_img.width),
            height = u32(first_img.height),
            depth_or_array_layers = 6,
        },
        mip_level_count = 1,
        sample_count = 1,
        dimension = out.dimension,
        format = out.format,
        usage = { .Texture_Binding, .Copy_Dst, .Render_Attachment },
    }
    out.texture = gpu.device_create_texture(self.device, texture_desc)

    image_properties_equal :: proc(img1, img2: ^image.Image) -> bool {
        if img1.width != img2.width {return false}
        if img1.height != img2.height {return false}
        if img1.channels != img2.channels {return false}
        if img1.depth != img2.depth {return false}
        return true
    }

    // Calculate bytes per row, ensuring it meets the alignment requirements
    bytes_per_row := gpu.texture_format_bytes_per_row(out.format, u32(first_img.width))

    // Load and copy each face of the cubemap
    for i in 0 ..< 6 {
        img_bytes, img_bytes_ok := app.load_file(file_paths[i], ta)
        if !img_bytes_ok {
            log.panic("Failed to load the [%v] cubemap image file", i, location = loc)
        }

        // Check info of each face
        img, img_err := image.load_from_bytes(img_bytes, allocator = ta)
        if img_err != nil {
            log.panicf("Failed to load cubemap image [%d]: %v", i, img_err, location = loc)
        }

        if !image_properties_equal(img, first_img) {
            log.panicf("Cubemap face '%s' has different properties",
                file_paths[i], location = loc,
            )
        }

        // Copy the face image to the appropriate layer of the cubemap texture
        origin := gpu.Origin_3D{ 0, 0, u32(i) }

        // Prepare image data for upload
        image_copy_texture := gpu.texture_as_image_copy(out.texture, origin)
        texture_data_layout := gpu.Texel_Copy_Buffer_Layout {
            offset         = 0,
            bytes_per_row  = bytes_per_row,
            rows_per_image = u32(img.height),
        }

        // Convert RGB to RGBA
        pixels := image_data_convert(img, ta)

        gpu.queue_write_texture(
            self.queue,
            image_copy_texture,
            pixels,
            texture_data_layout,
            out.size,
        )
    }

    cube_view_descriptor := gpu.Texture_View_Descriptor {
        label             = "Cube Texture View",
        format            = out.format,
        dimension         = .Cube,
        base_mip_level    = 0,
        mip_level_count   = out.mip_level_count,
        base_array_layer  = 0,
        array_layer_count = 6, // 6 faces of the cube
        aspect            = .All,
    }
    out.view = gpu.texture_create_view(out.texture, cube_view_descriptor)

    // Create a sampler with linear filtering for smooth interpolation.
    sampler_descriptor := gpu.Sampler_Descriptor {
        address_mode_u   = .Repeat,
        address_mode_v   = .Repeat,
        address_mode_w   = .Repeat,
        mag_filter       = .Linear,
        min_filter       = .Linear,
        mipmap_filter    = .Linear,
        lod_min_clamp    = 0.0,
        lod_max_clamp    = 1.0,
        compare          = .Undefined,
        max_anisotropy   = 1,
    }

    out.sampler = gpu.device_create_sampler(self.device, sampler_descriptor)

    return
}

image_data_convert :: proc(img: ^image.Image, allocator := context.allocator) -> []byte {
    RGB_CHANNELS :: 3
    RGBA_CHANNELS :: 4

    src := gpu.to_bytes(img.pixels)

    // If already RGBA or has alpha, return original pixels
    if img.channels != RGB_CHANNELS {
        return src
    }

    // Convert RGB to RGBA
    bytes_per_channel := img.depth / 8
    pixel_count := img.width * img.height
    new_pixels := make([]byte, pixel_count * RGBA_CHANNELS * bytes_per_channel, allocator)

    for i in 0 ..< pixel_count {
        src_idx := i * RGB_CHANNELS * bytes_per_channel
        dst_idx := i * RGBA_CHANNELS * bytes_per_channel

        // Copy RGB
        copy(new_pixels[dst_idx:], src[src_idx:src_idx + RGB_CHANNELS * bytes_per_channel])

        // Set alpha to max value (255 for 8-bit, 65535 for 16-bit)
        if bytes_per_channel == 1 {
            new_pixels[dst_idx + 3] = 255
        } else if bytes_per_channel == 2 {
            // 16-bit alpha (little-endian)
            new_pixels[dst_idx + 6] = 0xFF
            new_pixels[dst_idx + 7] = 0xFF
        }
    }

    return new_pixels
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
        label           = "Depth Texture",
        size            = { width, height, 1 },
        mip_level_count = 1,
        sample_count    = 1,
        dimension       = .D2,
        format          = DEPTH_FORMAT,
        usage           = { .Copy_Dst, .Render_Attachment },
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

set_projection_matrix :: proc(self: ^Application, width, height: u32) {
    aspect := f32(width) / f32(height)
    self.projection_matrix = la.matrix4_perspective((2 * math.PI) / 5, aspect, 1, 3000.0)
}

get_transformation_matrix :: proc(self: ^Application) -> (mvp_mat: la.Matrix4f32) {
    now := app.get_time() / 0.8

    rotation_x := la.quaternion_from_euler_angle_x_f32((math.PI / 10) * math.sin(now))
    rotation_y := la.quaternion_from_euler_angle_y_f32(now * 0.2)

    combined_rotation := la.quaternion_mul_quaternion(rotation_x, rotation_y)
    view_matrix := la.matrix4_from_quaternion_f32(combined_rotation)

    mvp_mat = la.matrix_mul(view_matrix, self.model_matrix)
    mvp_mat = la.matrix_mul(self.projection_matrix, mvp_mat)

    return
}

update :: proc(self: ^Application) {
    transformation_matrix := get_transformation_matrix(self)
    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(transformation_matrix),
    )
}

iterate :: proc(self: ^Application, dt: f32) -> (res: app.App_Result) {
    update(self)

    frame := app.get_current_frame()
    if frame.skip { return }
    defer app.release_current_frame(&frame)

    encoder := gpu.device_create_command_encoder(self.device)
    defer gpu.release(encoder)

    self.rpass.colors[0].view = frame.view
    render_pass := gpu.command_encoder_begin_render_pass(encoder, self.rpass.descriptor)
    defer gpu.release(render_pass)

    gpu.render_pass_set_pipeline(render_pass, self.render_pipeline)
    gpu.render_pass_set_bind_group(render_pass, 0, self.bind_group)
    gpu.render_pass_set_vertex_buffer(render_pass, 0, self.vertex_buffer)
    gpu.render_pass_set_index_buffer(render_pass, self.index_buffer, .Uint16)
    gpu.render_pass_draw_indexed(render_pass, { 0, u32(len(CUBE_INDICES_DATA)) }, 0)
    gpu.render_pass_end(render_pass)

    cmdbuf := gpu.command_encoder_finish(encoder)
    defer gpu.release(cmdbuf)

    gpu.queue_submit(self.queue, {cmdbuf})
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

quit :: proc(self: ^Application, res: app.App_Result) {
    gpu.release(self.cubemap_texture.sampler)
    gpu.release(self.cubemap_texture.view)
    gpu.release(self.cubemap_texture.texture)

    gpu.release(self.bind_group_layout)

    gpu.release(self.depth_view)
    gpu.release(self.bind_group)
    gpu.release(self.uniform_buffer)
    gpu.release(self.index_buffer)
    gpu.release(self.vertex_buffer)
    gpu.release(self.render_pipeline)

    free(self)
}

resize :: proc(self: ^Application, width, height: u32) {
    gpu.texture_view_release(self.depth_view)
    create_depth_framebuffer(self)

    // Update uniform buffer with new aspect ratio
    aspect := f32(width) / f32(height)
    new_matrix := app.create_view_projection_matrix(aspect)
    gpu.queue_write_buffer(
        self.queue,
        self.uniform_buffer,
        0,
        gpu.to_bytes(new_matrix),
    )
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
