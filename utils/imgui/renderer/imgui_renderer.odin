/*
ImGui renderer

Ref:

- https://github.com/ocornut/imgui
- https://github.com/ocornut/imgui/blob/master/backends/imgui_impl_wgpu.cpp
*/
package imgui_renderer

// Core
import "base:runtime"
import "core:slice"
import intr "base:intrinsics"
import la "core:math/linalg"

// Vendor
import "../../../gpu"
import im "../"

//-----------------------------------------------------------------------------
// Backend data structures
//-----------------------------------------------------------------------------

Texture :: struct {
    texture:      gpu.Texture,
    texture_view: gpu.Texture_View,
}

Render_Resources :: struct {
    sampler_linear:            gpu.Sampler,
    sampler_nearest:           gpu.Sampler,
    uniforms:                  gpu.Buffer,
    common_bind_group_linear:  gpu.Bind_Group,
    common_bind_group_nearest: gpu.Bind_Group,
    image_bind_groups:         map[im.TextureID]gpu.Bind_Group,
    image_bind_group_layout:   gpu.Bind_Group_Layout,
}

Frame_Resources :: struct {
    index_buffer:       gpu.Buffer,
    vertex_buffer:      gpu.Buffer,
    index_buffer_host:  []im.DrawIdx,
    vertex_buffer_host: []im.DrawVert,
    index_buffer_size:  i32,
    vertex_buffer_size: i32,
}

Uniforms :: struct #align(16) {
    mvp:   matrix[4, 4]f32,
    gamma: f32,
}

Render_State :: struct {
    device:              gpu.Device,
    render_pass_encoder: gpu.Render_Pass,
}

Init_Info :: struct {
    device:                     gpu.Device,
    num_frames_in_flight:       u32,
    render_target_format:       gpu.Texture_Format,
    depth_stencil_format:       gpu.Texture_Format,
    pipeline_multisample_state: gpu.Multisample_State,
}

Backend_Data :: struct {
    init_info:            Init_Info,
    device:               gpu.Device,
    default_queue:        gpu.Queue,
    render_target_format: gpu.Texture_Format,
    depth_stencil_format: gpu.Texture_Format,
    pipeline_state:       gpu.Render_Pipeline,
    render_state:         ^Render_State,
    render_resources:     Render_Resources,
    frame_resources:      []Frame_Resources,
    num_frames_in_flight: u32,
    frame_index:          u32,
    allocator:            runtime.Allocator,
}

get_backend_data :: proc "contextless" () -> ^Backend_Data {
    ctx := im.GetCurrentContext()
    if ctx == nil {
        return nil
    }
    io := im.GetIO()
    return cast(^Backend_Data)io.BackendRendererUserData
}

align_down :: proc "contextless" (value: $T, #any_int alignment: u64) -> T
        where intr.type_is_integer(T) {
    return value & ~(T(alignment) - 1)
}

align_up :: proc "contextless" (value: $T, #any_int alignment: u64) -> T
        where intr.type_is_integer(T) {
    return align_down(value + T(alignment) - 1, alignment)
}

//-----------------------------------------------------------------------------
// Resource release helpers
//-----------------------------------------------------------------------------

release_frame_resources :: proc(fr: ^Frame_Resources, allocator: runtime.Allocator) {
    if fr.vertex_buffer != {} {
        gpu.buffer_release(fr.vertex_buffer)
        fr.vertex_buffer = {}
    }
    if fr.index_buffer != {} {
        gpu.buffer_release(fr.index_buffer)
        fr.index_buffer = {}
    }
    if fr.vertex_buffer_host != nil {
        delete(fr.vertex_buffer_host, allocator)
        fr.vertex_buffer_host = {}
    }
    if fr.index_buffer_host != nil {
        delete(fr.index_buffer_host, allocator)
        fr.index_buffer_host = {}
    }
}

release_render_resources :: proc(rr: ^Render_Resources) {
    if rr.sampler_linear != {} {
        gpu.sampler_release(rr.sampler_linear)
        rr.sampler_linear = {}
    }
    if rr.sampler_nearest != {} {
        gpu.sampler_release(rr.sampler_nearest)
        rr.sampler_nearest = {}
    }
    if rr.uniforms != {} {
        gpu.buffer_release(rr.uniforms)
        rr.uniforms = {}
    }
    if rr.common_bind_group_linear != {} {
        gpu.bind_group_release(rr.common_bind_group_linear)
        rr.common_bind_group_linear = {}
    }
    if rr.common_bind_group_nearest != {} {
        gpu.bind_group_release(rr.common_bind_group_nearest)
        rr.common_bind_group_nearest = {}
    }
    if rr.image_bind_group_layout != {} {
        gpu.bind_group_layout_release(rr.image_bind_group_layout)
        rr.image_bind_group_layout = {}
    }
}

//-----------------------------------------------------------------------------
// Bind groups
//-----------------------------------------------------------------------------

create_image_bind_group :: proc(
    bd: ^Backend_Data,
    layout: gpu.Bind_Group_Layout,
    texture_view: gpu.Texture_View,
) -> gpu.Bind_Group {
    return gpu.device_create_bind_group(bd.device, {
        layout = layout,
        entries = {
            {
                binding = 0,
                resource = texture_view,
            },
        },
    })
}

//-----------------------------------------------------------------------------
// Render state setup
//-----------------------------------------------------------------------------

setup_render_state :: proc(
    bd: ^Backend_Data,
    draw_data: ^im.DrawData,
    pass: gpu.Render_Pass,
    fr: ^Frame_Resources,
) {
    // Orthographic projection matrix, uploaded into the uniform buffer.
    // Visible imgui space runs from draw_data.DisplayPos (top-left) to
    // draw_data.DisplayPos + draw_data.DisplaySize (bottom-right).
    {
        // Setup orthographic projection matrix
        mvp := la.matrix_ortho3d_f32(
            left = draw_data.DisplayPos.x,
            right = draw_data.DisplayPos.x + draw_data.DisplaySize.x,
            bottom = draw_data.DisplayPos.y + draw_data.DisplaySize.y,
            top = draw_data.DisplayPos.y,
            near = -1,
            far = 1,
        )

        gamma := f32(1.0)
        if gpu.texture_format_is_srgb(bd.render_target_format) {
            gamma = 2.2
        }

        uniforms := Uniforms{mvp = mvp, gamma = gamma}
        gpu.queue_write_buffer(
            bd.default_queue, bd.render_resources.uniforms, 0, &uniforms, size_of(Uniforms))
    }

    // Viewport
    fb_width := i32(draw_data.DisplaySize.x * draw_data.FramebufferScale.x + 0.5)
    fb_height := i32(draw_data.DisplaySize.y * draw_data.FramebufferScale.y + 0.5)
    gpu.render_pass_set_viewport(pass, 0, 0, f32(fb_width), f32(fb_height), 0, 1)

    // Bind pipeline + vertex/index buffers
    gpu.render_pass_set_vertex_buffer(
        pass, 0, fr.vertex_buffer, 0,
        u64(fr.vertex_buffer_size * size_of(im.DrawVert)),
    )

    index_format : gpu.Index_Format = .Uint16 if size_of(im.DrawIdx) == 2 else .Uint32
    gpu.render_pass_set_index_buffer(
        pass, fr.index_buffer, index_format, 0,
        u64(fr.index_buffer_size * size_of(im.DrawIdx)),
    )

    gpu.render_pass_set_pipeline(pass, bd.pipeline_state)
    gpu.render_pass_set_bind_group(pass, 0, bd.render_resources.common_bind_group_linear, nil)

    blend_color := gpu.Color{0, 0, 0, 0}
    gpu.render_pass_set_blend_constant(pass, blend_color)
}

//-----------------------------------------------------------------------------
// Draw callbacks
//-----------------------------------------------------------------------------

draw_callback_reset_render_state :: proc (draw_list: ^im.DrawList, cmd: ^im.DrawCmd) {
}

draw_callback_set_sampler_linear :: proc (draw_list: ^im.DrawList, cmd: ^im.DrawCmd) {
    bd := get_backend_data()
    gpu.render_pass_set_bind_group(
        bd.render_state.render_pass_encoder, 0,
        bd.render_resources.common_bind_group_linear, nil,
    )
}

draw_callback_set_sampler_nearest :: proc (draw_list: ^im.DrawList, cmd: ^im.DrawCmd) {
    bd := get_backend_data()
    gpu.render_pass_set_bind_group(
        bd.render_state.render_pass_encoder, 0,
        bd.render_resources.common_bind_group_nearest, nil,
    )
}

//-----------------------------------------------------------------------------
// Main render function
//-----------------------------------------------------------------------------

render_draw_data :: proc(draw_data: ^im.DrawData, pass_encoder: gpu.Render_Pass) {
    // Avoid rendering when minimized
    fb_width := i32(draw_data.DisplaySize.x * draw_data.FramebufferScale.x + 0.5)
    fb_height := i32(draw_data.DisplaySize.y * draw_data.FramebufferScale.y + 0.5)
    if fb_width <= 0 || fb_height <= 0 || draw_data.CmdLists.Size == 0 {
        return
    }

    // Catch up with texture updates. Most of the time this list has one
    // element in an OK state, i.e. nothing to do.
    if draw_data.Textures != nil {
        for i in 0..<draw_data.Textures.Size {
            tex := draw_data.Textures.Data[i]
            if tex.Status != .OK {
                update_texture(tex)
            }
        }
    }

    // NOTE: assumes this is only called once per frame, same as the C++
    // backend — if not, replace the simple ring index below with a proper
    // allocator.
    bd := get_backend_data()
    bd.frame_index += 1
    fr := &bd.frame_resources[bd.frame_index % bd.num_frames_in_flight]

    // Grow vertex/index buffers if needed
    if fr.vertex_buffer == {} || fr.vertex_buffer_size < draw_data.TotalVtxCount {
        if fr.vertex_buffer != {} {
            gpu.buffer_destroy(fr.vertex_buffer)
            gpu.buffer_release(fr.vertex_buffer)
        }
        if fr.vertex_buffer_host != nil {
            delete(fr.vertex_buffer_host, bd.allocator)
        }
        fr.vertex_buffer_size = draw_data.TotalVtxCount + 5000

        buffer_size_aligned :=
            u64(align_up(fr.vertex_buffer_size * size_of(im.DrawVert), 4))
        vb_desc := gpu.Buffer_Descriptor {
            label              = "Dear ImGui Vertex buffer",
            usage              = {.Copy_Dst, .Vertex},
            size               = buffer_size_aligned,
            mapped_at_creation = false,
        }
        fr.vertex_buffer = gpu.device_create_buffer(bd.device, vb_desc)
        if fr.vertex_buffer == {} {
            return
        }
        fr.vertex_buffer_host = make([]im.DrawVert, fr.vertex_buffer_size, bd.allocator)
    }

    if fr.index_buffer == {} || fr.index_buffer_size < draw_data.TotalIdxCount {
        if fr.index_buffer != {} {
            gpu.buffer_destroy(fr.index_buffer)
            gpu.buffer_release(fr.index_buffer)
        }
        if fr.index_buffer_host != nil {
            delete(fr.index_buffer_host, bd.allocator)
        }
        fr.index_buffer_size = draw_data.TotalIdxCount + 10000

        buffer_size_aligned :=
            u64(align_up(fr.index_buffer_size * size_of(im.DrawIdx), 4))
        ib_desc := gpu.Buffer_Descriptor {
            label              = "Dear ImGui Index buffer",
            usage              = {.Copy_Dst, .Index},
            size               = buffer_size_aligned,
            mapped_at_creation = false,
        }
        fr.index_buffer = gpu.device_create_buffer(bd.device, ib_desc)
        if fr.index_buffer == {} {
            return
        }
        fr.index_buffer_host = make([]im.DrawIdx, fr.index_buffer_size, bd.allocator)
    }

    // Upload vertex/index data into a single contiguous host buffer, then to the GPU
    vtx_offset := 0
    idx_offset := 0

    cmd_lists := slice.from_ptr(draw_data.CmdLists.Data, int(draw_data.CmdLists.Size))
    for draw_list in cmd_lists {
        vtx := slice.from_ptr(draw_list.VtxBuffer.Data, int(draw_list.VtxBuffer.Size))
        idx := slice.from_ptr(draw_list.IdxBuffer.Data, int(draw_list.IdxBuffer.Size))

        copy(fr.vertex_buffer_host[vtx_offset:vtx_offset + len(vtx)], vtx)
        copy(fr.index_buffer_host[idx_offset:idx_offset + len(idx)], idx)

        vtx_offset += len(vtx)
        idx_offset += len(idx)
    }

    vb_write_size := align_up(vtx_offset * size_of(im.DrawVert), 4)
    ib_write_size := align_up(idx_offset * size_of(im.DrawIdx), 4)

    gpu.queue_write_buffer(
        bd.default_queue, fr.vertex_buffer, 0,
        raw_data(fr.vertex_buffer_host), uint(vb_write_size),
    )
    gpu.queue_write_buffer(
        bd.default_queue, fr.index_buffer, 0,
        raw_data(fr.index_buffer_host), uint(ib_write_size),
    )

    // Setup desired render state
    setup_render_state(bd, draw_data, pass_encoder, fr)

    // Setup render state (for callbacks and custom texture bindings)
    render_state := Render_State {
        device              = bd.device,
        render_pass_encoder = pass_encoder,
    }
    im.GetPlatformIO().Renderer_RenderState = &render_state
    bd.render_state = &render_state

    // Render command lists.
    // Because we merged all buffers into one, we track our own running offset.
    global_vtx_offset := 0
    global_idx_offset := 0
    clip_scale := draw_data.FramebufferScale
    clip_off := draw_data.DisplayPos

    for draw_list in cmd_lists {
        cmd_buffer := slice.from_ptr(draw_list.CmdBuffer.Data, int(draw_list.CmdBuffer.Size))
        for &pcmd in cmd_buffer {
            if pcmd.UserCallback != nil {
                // User callback, registered via ImDrawList::AddCallback()
                if pcmd.UserCallback == draw_callback_reset_render_state {
                    setup_render_state(bd, draw_data, pass_encoder, fr)
                } else {
                    pcmd.UserCallback(draw_list, &pcmd)
                }
            } else {
                // Bind custom texture
                tex_id := im.DrawCmd_GetTexID(&pcmd)
                bind_group, found := bd.render_resources.image_bind_groups[u64(tex_id)]
                if !found && tex_id != im.TextureID_Invalid {
                    bind_group = create_image_bind_group(
                        bd, bd.render_resources.image_bind_group_layout,
                        gpu.new_handle_packed(gpu.Texture_View, bd.device, tex_id),
                    )
                    if bind_group != {} {
                        bd.render_resources.image_bind_groups[tex_id] = bind_group
                    }
                }
                if bind_group != {} {
                    gpu.render_pass_set_bind_group(pass_encoder, 1, bind_group, nil)
                }

                // Project scissor/clipping rectangle into framebuffer space
                clip_min := [2]f32{
                    (pcmd.ClipRect.x - clip_off.x) * clip_scale.x,
                    (pcmd.ClipRect.y - clip_off.y) * clip_scale.y,
                }
                clip_max := [2]f32{
                    (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                    (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                }

                // Clamp to viewport, since SetScissorRect rejects out-of-bounds values
                clip_min.x = max(clip_min.x, 0.0)
                clip_min.y = max(clip_min.y, 0.0)
                clip_max.x = min(clip_max.x, f32(fb_width))
                clip_max.y = min(clip_max.y, f32(fb_height))
                if clip_max.x <= clip_min.x || clip_max.y <= clip_min.y {
                    continue
                }

                gpu.render_pass_set_scissor_rect(
                    pass_encoder,
                    u32(clip_min.x), u32(clip_min.y),
                    u32(clip_max.x - clip_min.x), u32(clip_max.y - clip_min.y),
                )
                gpu.render_pass_draw_indexed(
                    pass_encoder,
                    u32(pcmd.ElemCount), 1,
                    u32(pcmd.IdxOffset) + u32(global_idx_offset),
                    i32(pcmd.VtxOffset) + i32(global_vtx_offset),
                    0,
                )
            }
        }
        global_idx_offset += int(draw_list.IdxBuffer.Size)
        global_vtx_offset += int(draw_list.VtxBuffer.Size)
    }

    for _, bind_group in bd.render_resources.image_bind_groups {
        gpu.bind_group_release(bind_group)
    }
    clear(&bd.render_resources.image_bind_groups)

    im.GetPlatformIO().Renderer_RenderState = nil
    bd.render_state = nil
}

//-----------------------------------------------------------------------------
// Textures
//-----------------------------------------------------------------------------

destroy_texture :: proc(tex: ^im.TextureData, allocator: runtime.Allocator) {
    if tex.BackendUserData != nil {
        backend_tex := (^Texture)(tex.BackendUserData)
        assert(backend_tex.texture_view.handle == tex.TexID)
        gpu.texture_view_release(backend_tex.texture_view)
        gpu.texture_release(backend_tex.texture)
        free(backend_tex, allocator)

        // Clear identifiers and mark as destroyed (allows calling
        // invalidate_device_objects while running, same as the C++ backend)
        tex.TexID = im.TextureID_Invalid
        tex.BackendUserData = nil
    }
    tex.Status = .Destroyed
}

update_texture :: proc(tex: ^im.TextureData) {
    bd := get_backend_data()

    if tex.Status == .WantCreate {
        // Create and upload new texture to graphics system
        assert(tex.TexID == im.TextureID_Invalid && tex.BackendUserData == nil)
        assert(tex.Format == .RGBA32)

        backend_tex := new(Texture, bd.allocator)

        tex_desc := gpu.Texture_Descriptor {
            label           = "Dear ImGui Texture",
            dimension       = .D2,
            size            = {u32(tex.Width), u32(tex.Height), 1},
            sample_count    = 1,
            format          = .RGBA8_Unorm,
            mip_level_count = 1,
            usage           = {.Copy_Dst, .Texture_Binding},
        }
        backend_tex.texture = gpu.device_create_texture(bd.device, tex_desc)

        tex_view_desc := gpu.Texture_View_Descriptor {
            format            = .RGBA8_Unorm,
            dimension         = .D2,
            base_mip_level    = 0,
            mip_level_count   = 1,
            base_array_layer  = 0,
            array_layer_count = 1,
            aspect            = .All,
        }
        backend_tex.texture_view = gpu.texture_create_view(backend_tex.texture, tex_view_desc)

        // Store identifiers
        tex.TexID = im.TextureID(backend_tex.texture_view.handle)
        tex.BackendUserData = backend_tex
        // Status intentionally left as-is to fall through to the update path below.
    }

    if tex.Status == .WantCreate || tex.Status == .WantUpdates {
        backend_tex := (^Texture)(tex.BackendUserData)
        assert(tex.Format == .RGBA32)

        // Full rect on WantCreate (also clears the texture); update rect otherwise
        upload_x := 0 if tex.Status == .WantCreate else i32(tex.UpdateRect.x)
        upload_y := 0 if tex.Status == .WantCreate else i32(tex.UpdateRect.y)
        upload_w := tex.Width  if tex.Status == .WantCreate else i32(tex.UpdateRect.w)
        upload_h := tex.Height if tex.Status == .WantCreate else i32(tex.UpdateRect.h)

        dst_view := gpu.Texel_Copy_Texture_Info {
            texture   = backend_tex.texture,
            mip_level = 0,
            origin    = {u32(upload_x), u32(upload_y), 0},
            aspect    = .All,
        }
        layout := gpu.Texel_Copy_Buffer_Layout {
            offset         = 0,
            bytes_per_row  = u32(tex.Width * tex.BytesPerPixel),
            rows_per_image = u32(upload_h),
        }
        write_size := gpu.Extent_3D{u32(upload_w), u32(upload_h), 1}

        pixels := im.TextureData_GetPixelsAt(tex, upload_x, upload_y)
        size := int(tex.Width * upload_h * tex.BytesPerPixel)
        data := slice.bytes_from_ptr(pixels, size)

        gpu.queue_write_texture(
            bd.default_queue,
            dst_view,
            data,
            layout,
            write_size,
        )
        tex.Status = .OK
    }

    if tex.Status == .WantDestroy && tex.UnusedFrames > 0 {
        destroy_texture(tex, bd.allocator)
    }
}

//-----------------------------------------------------------------------------
// Device object creation / teardown
//-----------------------------------------------------------------------------

create_uniform_buffer :: proc(bd: ^Backend_Data) {
    ub_desc := gpu.Buffer_Descriptor {
        label              = "Dear ImGui Uniform buffer",
        usage              = {.Copy_Dst, .Uniform},
        size               = u64(align_up(size_of(Uniforms), 16)),
        mapped_at_creation = false,
    }
    bd.render_resources.uniforms = gpu.device_create_buffer(bd.device, ub_desc)
}

create_device_objects :: proc(bd: ^Backend_Data) -> bool {
    if bd.device == nil {
        return false
    }
    if bd.pipeline_state != {} {
        invalidate_device_objects(bd)
    }

    pipeline_desc := gpu.Render_Pipeline_Descriptor {
        primitive = {
            topology           = .Triangle_List,
            strip_index_format = .Undefined,
            front_face         = .CW,
            cull_mode          = .None,
        },
        multisample = bd.init_info.pipeline_multisample_state,
    }

    // Bind group layouts
    common_bg_layout_entries := [2]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Vertex, .Fragment},
            type = gpu.Buffer_Binding_Layout {
                type = .Uniform,
            },
        },
        {
            binding    = 1,
            visibility = {.Fragment},
            type = gpu.Sampler_Binding_Layout {
                type = .Filtering,
            },
        },
    }

    image_bg_layout_entries := [1]gpu.Bind_Group_Layout_Entry {
        {
            binding    = 0,
            visibility = {.Fragment},
            type = gpu.Texture_Binding_Layout {
                sample_type = .Float,
                view_dimension = .D2,
            },
        },
    }

    common_bg_layout_desc := gpu.Bind_Group_Layout_Descriptor {
        entries = common_bg_layout_entries[:],
    }
    image_bg_layout_desc := gpu.Bind_Group_Layout_Descriptor {
        entries = image_bg_layout_entries[:],
    }

    bg_layouts: [2]gpu.Bind_Group_Layout
    bg_layouts[0] = gpu.device_create_bind_group_layout(bd.device, common_bg_layout_desc)
    bg_layouts[1] = gpu.device_create_bind_group_layout(bd.device, image_bg_layout_desc)

    layout_desc := gpu.Pipeline_Layout_Descriptor {
        bind_group_layouts = bg_layouts[:],
    }
    pipeline_desc.layout = gpu.device_create_pipeline_layout(bd.device, layout_desc)

    // Vertex shader
    vertex_shader_module := load_shader(bd.device, .Vertex)
    pipeline_desc.vertex.module = vertex_shader_module
    pipeline_desc.vertex.entry_point = "vs_main"

    attribute_desc := [3]gpu.Vertex_Attribute {
        {format = .Float32x2, offset = u64(offset_of(im.DrawVert, pos)), shader_location = 0},
        {format = .Float32x2, offset = u64(offset_of(im.DrawVert, uv)),  shader_location = 1},
        {format = .Unorm8x4,  offset = u64(offset_of(im.DrawVert, col)), shader_location = 2},
    }

    buffer_layouts := [1]gpu.Vertex_Buffer_Layout {
        {
            array_stride = size_of(im.DrawVert),
            step_mode    = .Vertex,
            attributes   = attribute_desc[: ],
        },
    }

    pipeline_desc.vertex.buffers = buffer_layouts[:]

    // Fragment shader
    pixel_shader_module := load_shader(bd.device, .Fragment)

    blend_state := gpu.Blend_State {
        alpha = {operation = .Add, src_factor = .One, dst_factor = .One_Minus_Src_Alpha},
        color = {operation = .Add, src_factor = .Src_Alpha, dst_factor = .One_Minus_Src_Alpha},
    }

    color_state := gpu.Color_Target_State {
        format     = bd.render_target_format,
        blend      = &blend_state,
        write_mask = gpu.COLOR_WRITES_ALL,
    }

    fragment_state := gpu.Fragment_State {
        module       = pixel_shader_module,
        entry_point  = "fs_main",
        targets      = {color_state},
    }
    pipeline_desc.fragment = &fragment_state

    depth_stencil_state := gpu.Depth_Stencil_State {
        format = bd.depth_stencil_format,
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
            read_mask = max(u32),
            write_mask = max(u32),
        },
    }
    pipeline_desc.depth_stencil =
        nil if bd.depth_stencil_format == .Undefined else &depth_stencil_state

    bd.pipeline_state = gpu.device_create_render_pipeline(bd.device, pipeline_desc)

    create_uniform_buffer(bd)

    // Samplers
    sampler_desc := gpu.Sampler_Descriptor {
        address_mode_u   = .Clamp_To_Edge,
        address_mode_v   = .Clamp_To_Edge,
        address_mode_w   = .Clamp_To_Edge,
        anisotropy_clamp = 1,
        min_filter       = .Linear,
        mag_filter       = .Linear,
        mipmap_filter    = .Linear,
    }
    bd.render_resources.sampler_linear = gpu.device_create_sampler(bd.device, sampler_desc)

    sampler_desc.min_filter = .Nearest
    sampler_desc.mag_filter = .Nearest
    sampler_desc.mipmap_filter = .Nearest
    bd.render_resources.sampler_nearest = gpu.device_create_sampler(bd.device, sampler_desc)

    // Common bind groups (one per sampler, otherwise identical)
    common_bg_entries := [2]gpu.Bind_Group_Entry {
        {
            binding = 0,
            resource = gpu.Buffer_Binding{
                buffer  = bd.render_resources.uniforms,
                offset  = 0,
                size    = u64(align_up(size_of(Uniforms), 16)),
            },
        },
        {binding = 1, resource = bd.render_resources.sampler_linear},
    }
    common_bg_desc := gpu.Bind_Group_Descriptor {
        layout  = bg_layouts[0],
        entries = common_bg_entries[:],
    }
    bd.render_resources.common_bind_group_linear =
        gpu.device_create_bind_group(bd.device, common_bg_desc)

    common_bg_entries[1].resource = bd.render_resources.sampler_nearest
    bd.render_resources.common_bind_group_nearest =
        gpu.device_create_bind_group(bd.device, common_bg_desc)

    bd.render_resources.image_bind_group_layout = bg_layouts[1]

    // Release transient objects
    gpu.shader_module_release(vertex_shader_module)
    gpu.shader_module_release(pixel_shader_module)
    gpu.pipeline_layout_release(pipeline_desc.layout)
    gpu.bind_group_layout_release(bg_layouts[0])

    return true
}

invalidate_device_objects :: proc(bd: ^Backend_Data) {
    if bd.device == nil {
        return
    }

    if bd.pipeline_state != {} {
        gpu.render_pipeline_release(bd.pipeline_state)
        bd.pipeline_state = {}
    }
    release_render_resources(&bd.render_resources)

    // Destroy all textures still owned solely by the platform_io texture list
    platform_io := im.GetPlatformIO()
    for i in 0..<platform_io.Textures.Size {
        tex := platform_io.Textures.Data[i]
        if tex.RefCount == 1 {
            destroy_texture(tex, bd.allocator)
        }
    }

    for i in 0 ..< bd.num_frames_in_flight {
        release_frame_resources(&bd.frame_resources[i], bd.allocator)
    }
}

//-----------------------------------------------------------------------------
// Init / Shutdown / NewFrame
//-----------------------------------------------------------------------------

init :: proc(init_info: Init_Info, allocator := context.allocator) -> bool {
    io := im.GetIO()
    assert(io.BackendRendererUserData == nil, "Already initialized a renderer backend!")

    bd := new(Backend_Data, allocator)
    bd.allocator = allocator
    io.BackendRendererUserData = bd
    io.BackendRendererName = "imgui_impl_wgpu (Odin)"

    io.BackendFlags += {.RendererHasVtxOffset} // honor Draw_Cmd.vtx_offset, allows large meshes
    io.BackendFlags += {.RendererHasTextures}  // honor platform_io.textures[] update requests

    platform_io := im.GetPlatformIO()
    platform_io.DrawCallback_ResetRenderState = draw_callback_reset_render_state
    platform_io.DrawCallback_SetSamplerLinear = draw_callback_set_sampler_linear
    platform_io.DrawCallback_SetSamplerNearest = draw_callback_set_sampler_nearest

    bd.init_info = init_info
    bd.device = init_info.device
    bd.default_queue = gpu.device_get_queue(bd.device)
    bd.render_target_format = init_info.render_target_format
    bd.depth_stencil_format = init_info.depth_stencil_format
    bd.num_frames_in_flight = init_info.num_frames_in_flight
    bd.frame_index = max(u32)

    bd.render_resources.image_bind_groups =
        make(map[im.TextureID]gpu.Bind_Group, 100, allocator)

    // Frame resources, grown on demand later
    bd.frame_resources = make([]Frame_Resources, bd.num_frames_in_flight, allocator)
    for i in 0 ..< bd.num_frames_in_flight {
        fr := &bd.frame_resources[i]
        fr.index_buffer = {}
        fr.vertex_buffer = {}
        fr.index_buffer_host = nil
        fr.vertex_buffer_host = nil
        fr.index_buffer_size = 10000
        fr.vertex_buffer_size = 5000
    }

    return true
}

shutdown :: proc() {
    bd := get_backend_data()
    assert(bd != nil, "No renderer backend to shutdown, or already shutdown?")

    context.allocator = bd.allocator

    io := im.GetIO()
    platform_io := im.GetPlatformIO()

    invalidate_device_objects(bd)
    delete(bd.frame_resources)
    bd.frame_resources = nil
    gpu.queue_release(bd.default_queue)
    bd.device = nil
    bd.num_frames_in_flight = 0
    bd.frame_index = max(u32)

    delete(bd.render_resources.image_bind_groups)

    io.BackendRendererName = ""
    io.BackendRendererUserData = nil
    io.BackendFlags -= {.RendererHasVtxOffset, .RendererHasTextures}
    im.PlatformIO_ClearRendererHandlers(platform_io)

    free(bd)
}

new_frame :: proc() {
    bd := get_backend_data()
    if bd.pipeline_state == {} {
        ok := create_device_objects(bd)
        assert(ok, "create_device_objects() failed!")
    }
}
