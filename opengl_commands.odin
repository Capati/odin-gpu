#+build windows, linux
package gpu

// Core
import "core:log"
import sa "core:container/small_array"

// Vendor
import gl "vendor:OpenGL"

gl_execute_begin_render_pass :: proc(cmd: ^Command_Begin_Render_Pass, loc := #caller_location) {
    // Determine which framebuffer to use
    fbo: u32
    first_attachment := sa.get(cmd.color_attachments, 0)
    assert(first_attachment.view != nil, loc = loc)

    texture_view_impl :=  get_impl(GL_Texture_View_Impl, first_attachment.view, loc)
    texture_impl := get_impl(GL_Texture_Impl, texture_view_impl.texture, loc)

    if texture_impl.is_swapchain {
        surface_impl := get_impl(GL_Surface_Impl, texture_impl.surface, loc)
        current_index := surface_impl.current_frame_index % surface_impl.back_buffer_count
        fbo = sa.get(surface_impl.framebuffers, int(current_index))
    } else {
        // Off-screen framebuffer
        panic("Off-screen rendering not yet implemented", loc)
    }

    // Detach any existing depth/stencil attachments to reset for this pass
    gl.NamedFramebufferTexture(fbo, gl.DEPTH_ATTACHMENT, 0, 0)
    gl.NamedFramebufferTexture(fbo, gl.STENCIL_ATTACHMENT, 0, 0)
    gl.NamedFramebufferTexture(fbo, gl.DEPTH_STENCIL_ATTACHMENT, 0, 0)

    // Bind the framebuffer FIRST
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

    // Default state
    gl.Viewport(0, 0, i32(cmd.width), i32(cmd.height))
    gl.DepthRangef(0.0, 1.0)
    gl.Scissor(0, 0, i32(cmd.width), i32(cmd.height))
    gl.BlendColor(0, 0, 0, 0)
    gl.ColorMask(true, true, true, true)
    gl.DepthMask(true)
    gl.StencilMask(0xff)

    // Process color attachments
    color_attachments := sa.slice(&cmd.color_attachments)
    for &attachment, i in color_attachments {
        // Handle load operation
        switch attachment.ops.load {
        case .Clear:
            clear_value := attachment.ops.clear_value
            clear_color := [4]f32{
                f32(clear_value.r),
                f32(clear_value.g),
                f32(clear_value.b),
                f32(clear_value.a),
            }
            gl.ClearNamedFramebufferfv(fbo, gl.COLOR, i32(i), &clear_color[0])

        case .Load:
            // Do nothing, keep existing contents

        case .Undefined:
            // Don't care about previous contents
        }
    }

    // Process depth/stencil attachment
    if depth_stencil, ok := cmd.depth_stencil_attachment.?; ok {
        assert(depth_stencil.view != nil, "Depth stencil view is nil", loc)

        depth_texture_view_impl := get_impl(GL_Texture_View_Impl, depth_stencil.view, loc)
        depth_texture_impl := get_impl(GL_Texture_Impl, depth_texture_view_impl.texture, loc)

        // Verify dimensions match the render pass
        if depth_texture_impl.size.width != cmd.width ||
           depth_texture_impl.size.height != cmd.height {
            log.errorf("Dimension mismatch: Depth=%dx%d, RenderPass=%dx%d",
                depth_texture_impl.size.width, depth_texture_impl.size.height,
                cmd.width, cmd.height)
            panic("Depth texture dimensions don't match render pass", loc)
        }

        // Determine attachment point based on format
        attachment_point: u32
        format := depth_texture_impl.format

        // First check if it's a combined depth-stencil format
        if texture_format_is_combined_depth_stencil_format(format) {
            attachment_point = gl.DEPTH_STENCIL_ATTACHMENT
        } else if texture_format_has_depth_aspect(format) {
            attachment_point = gl.DEPTH_ATTACHMENT
        } else if texture_format_has_stencil_aspect(format) {
            attachment_point = gl.STENCIL_ATTACHMENT
        } else {
            panic("Invalid depth/stencil format", loc)
        }

        view_impl := get_impl(GL_Texture_View_Impl, depth_stencil.view, loc)

        // Attach depth texture to framebuffer
        gl.NamedFramebufferTexture(
            fbo,
            attachment_point,
            depth_texture_impl.handle,
            i32(view_impl.base_mip_level),
        )

        // Check framebuffer completeness after attaching depth/stencil
        status := gl.CheckNamedFramebufferStatus(fbo, gl.FRAMEBUFFER)
        assert(status == gl.FRAMEBUFFER_COMPLETE,
            "Framebuffer not complete after depth attachment", loc)

        // NOW handle depth operations (with texture attached!)
        switch depth_stencil.depth_ops.load {
        case .Clear:
            depth_clear := f32(depth_stencil.depth_ops.clear_value)
            gl.ClearNamedFramebufferfv(fbo, gl.DEPTH, 0, &depth_clear)
        case .Load:
            // Keep existing contents
        case .Undefined:
            // Don't care
        }

        // Handle stencil operations (with texture attached!)
        switch depth_stencil.stencil_ops.load {
        case .Clear:
            stencil_clear := i32(depth_stencil.stencil_ops.clear_value)
            gl.ClearNamedFramebufferiv(fbo, gl.STENCIL, 0, &stencil_clear)
        case .Load:
            // Keep existing contents
        case .Undefined:
            // Don't care
        }
    }
}

gl_execute_copy_texture_to_texture :: proc(
    cmd: ^Command_Copy_Texture_To_Texture,
    loc := #caller_location,
) {
    src := &cmd.source
    dst := &cmd.destination

    src_texture := get_impl(GL_Texture_Impl, src.texture, loc)
    dst_texture := get_impl(GL_Texture_Impl, dst.texture, loc)

    // Validate textures are initialized
    assert(src_texture.handle != 0, "Source texture ID is invalid", loc)
    assert(dst_texture.handle != 0, "Destination texture ID is invalid", loc)
    assert(src_texture.gl_target != 0, "Source texture target is invalid", loc)
    assert(dst_texture.gl_target != 0, "Destination texture target is invalid", loc)

    // Calculate the actual dimensions at the specified mip levels
    src_width  := max(src_texture.size.width >> src.mip_level, 1)
    src_height := max(src_texture.size.height >> src.mip_level, 1)
    src_depth  := max(src_texture.size.depth_or_array_layers >> src.mip_level, 1)

    dst_width  := max(dst_texture.size.width >> dst.mip_level, 1)
    dst_height := max(dst_texture.size.height >> dst.mip_level, 1)
    dst_depth  := max(dst_texture.size.depth_or_array_layers >> dst.mip_level, 1)

    // Validate copy bounds
    assert(src.origin.x + cmd.copy_size.width <= src_width,
           "Source copy region exceeds texture bounds", loc)
    assert(src.origin.y + cmd.copy_size.height <= src_height,
           "Source copy region exceeds texture bounds", loc)
    assert(src.origin.z + cmd.copy_size.depth_or_array_layers <= src_depth,
           "Source copy region exceeds texture bounds", loc)

    assert(dst.origin.x + cmd.copy_size.width <= dst_width,
           "Destination copy region exceeds texture bounds", loc)
    assert(dst.origin.y + cmd.copy_size.height <= dst_height,
           "Destination copy region exceeds texture bounds", loc)
    assert(dst.origin.z + cmd.copy_size.depth_or_array_layers <= dst_depth,
           "Destination copy region exceeds texture bounds", loc)

    gl.CopyImageSubData(
        srcName   = src_texture.handle,
        srcTarget = src_texture.gl_target,
        srcLevel  = i32(src.mip_level),
        srcX      = i32(src.origin.x),
        srcY      = i32(src.origin.y),
        srcZ      = i32(src.origin.z),
        dstName   = dst_texture.handle,
        dstTarget = dst_texture.gl_target,
        dstLevel  = i32(dst.mip_level),
        dstX      = i32(dst.origin.x),
        dstY      = i32(dst.origin.y),
        dstZ      = i32(dst.origin.z),
        srcWidth  = i32(cmd.copy_size.width),
        srcHeight = i32(cmd.copy_size.height),
        srcDepth  = i32(cmd.copy_size.depth_or_array_layers),
    )
}

gl_execute_render_pass_draw :: proc(cmd: ^Command_Render_Pass_Draw, loc := #caller_location) {
    // impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)
    if cmd.pipeline != nil {
        pipeline_impl := get_impl(GL_Render_Pipeline_Impl, cmd.pipeline, loc)
        gl.DrawArrays(
            pipeline_impl.mode,
            i32(cmd.first_vertex),
            i32(cmd.vertex_count),
        )
    }
}

gl_execute_render_pass_draw_indexed :: proc(
    cmd: ^Command_Render_Pass_Draw_Indexed,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)
    if impl.pipeline != nil {
        pipeline_impl := get_impl(GL_Render_Pipeline_Impl, impl.pipeline, loc)

        // Calculate the offset into the index buffer
        // The offset is in bytes, so multiply first_index by the size of the index type
        index_size: int
        switch impl.index_type {
        case gl.UNSIGNED_SHORT:
            index_size = 2
        case gl.UNSIGNED_INT:
            index_size = 4
        case:
            assert(false, "Invalid index type", loc)
        }

        indices_offset := uintptr(impl.index_offset + u64(cmd.first_index * u32(index_size)))

        if cmd.instance_count <= 1 {
            // Non-instanced draw
            gl.DrawElementsBaseVertex(
                pipeline_impl.mode,
                i32(cmd.index_count),
                impl.index_type,
                rawptr(indices_offset),
                cmd.vertex_offset,
            )
        } else {
            // Instanced draw
            gl.DrawElementsInstancedBaseVertexBaseInstance(
                pipeline_impl.mode,
                i32(cmd.index_count),
                impl.index_type,
                rawptr(indices_offset),
                i32(cmd.instance_count),
                cmd.vertex_offset,
                cmd.first_instance,
            )
        }
    }
}

gl_execute_render_pass_end :: proc(cmd: ^Command_Render_Pass_End, loc := #caller_location) {
    impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)

    if impl.pipeline != nil {
        pipeline_impl := get_impl(GL_Render_Pipeline_Impl, impl.pipeline, loc)

        // Disable all enabled vertex attributes
        for slot in impl.enabled_vertex_buffers {
            buffer_attributes := pipeline_impl.buffer_attributes[slot]
            for attrib in buffer_attributes {
                gl.DisableVertexArrayAttrib(pipeline_impl.vao, attrib.index)
            }
        }
    }

    // Clear enabled state
    impl.enabled_vertex_buffers = {}

    impl.pipeline = nil
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
}

gl_execute_render_pass_set_bind_group :: proc(
    cmd: ^Command_Render_Pass_Set_Bind_Group,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)
    pipeline := get_impl(GL_Render_Pipeline_Impl, impl.pipeline, loc)
    group := get_impl(GL_Bind_Group_Impl, cmd.group, loc)

    assert(cmd.group_index < u32(len(pipeline.layout.group_layouts)),
           "Group index out of bounds", loc)

    layout := pipeline.layout.group_layouts[cmd.group_index]

    // Since both are sorted by binding, we can iterate by index
    assert(len(group.entries) == len(layout.entries),
           "Bind group entries don't match layout", loc)

    dynamic_offset_index: int

    for i in 0 ..< len(group.entries) {
        entry := &group.entries[i]
        layout_entry := &layout.entries[i]

        // Verify bindings match (should already be validated during creation)
        assert(entry.binding == layout_entry.binding,
               "Binding mismatch between group and layout", loc)

        switch res in entry.resource {
        case GL_Buffer_Binding:
            layout_type := layout_entry.type.(GL_Buffer_Binding_Layout) or_else \
                panic("Invalid buffer binding type", loc)

            offset := res.offset

            // Apply dynamic offset if this binding has one
            if layout_type.has_dynamic_offset {
                assert(dynamic_offset_index < len(cmd.dynamic_offsets),
                       "Not enough dynamic offsets provided", loc)
                offset += u64(cmd.dynamic_offsets[dynamic_offset_index])
                dynamic_offset_index += 1
            }

            size := res.size
            if size == 0 || size == WHOLE_SIZE {
                size = res.buffer.size - offset
            }

            // Bind buffer to the binding point
            gl.BindBufferRange(
                layout_type.gl_target,
                entry.binding,  // This is the binding point
                res.buffer.handle,
                int(offset),
                int(size),
            )

        case GL_Sampler_Binding:
            // FIXME(Todo): currently OpenGL is using combined texture/sampler,
            // this forces to use the same binding, but the entries should match
            // correct order
            gl.BindSampler(entry.binding-1, res.sampler.handle)

        case GL_Texture_View_Binding:
            texture_impl := get_impl(GL_Texture_Impl, res.texture_view.texture, loc)
            gl.BindTextureUnit(entry.binding, texture_impl.handle)

        case []GL_Buffer_Binding:
            unimplemented()

        case []GL_Sampler_Binding:
            unimplemented()

        case []GL_Texture_View_Binding:
            unimplemented()
        }
    }
}

gl_execute_render_pass_set_index_buffer :: proc(
    cmd: ^Command_Render_Pass_Set_Index_Buffer,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)
    pipeline_impl := get_impl(GL_Render_Pipeline_Impl, impl.pipeline, loc)
    buffer_impl := get_impl(GL_Buffer_Impl, cmd.buffer, loc)

    // Convert Index_Format to OpenGL type
    gl_type: u32
    #partial switch cmd.format {
    case .Uint16:
        gl_type = gl.UNSIGNED_SHORT
    case .Uint32:
        gl_type = gl.UNSIGNED_INT
    case:
        panic("Invalid index format", loc)
    }

    // Bind the index buffer to the VAO
    gl.VertexArrayElementBuffer(pipeline_impl.vao, buffer_impl.handle)

    // Store the index buffer info in the render pass implementation
    impl.index_buffer = buffer_impl.handle
    impl.index_type = gl_type
    impl.index_offset = cmd.offset
}

gl_execute_render_pass_set_pipeline :: proc(
    cmd: ^Command_Render_Pass_Set_Render_Pipeline,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pipeline_Impl, cmd.pipeline, loc)
    device_impl := get_impl(GL_Device_Impl, impl.device, loc)

    // Bind program and VAO
    gl.UseProgram(impl.program)
    gl.BindVertexArray(impl.vao)

    // Primitive state
    gl.FrontFace(impl.front_face)
    if impl.cull_enabled {
        gl.Enable(gl.CULL_FACE)
        gl.CullFace(impl.cull_face)
    } else {
        gl.Disable(gl.CULL_FACE)
    }

    // Depth state
    if impl.depth_test_enabled {
        gl.Enable(gl.DEPTH_TEST)
        gl.DepthFunc(impl.depth_func)
    } else {
        gl.Disable(gl.DEPTH_TEST)
    }
    gl.DepthMask(impl.depth_write_mask ? gl.TRUE : gl.FALSE)

    // Stencil state
    if impl.stencil_test_enabled {
        gl.Enable(gl.STENCIL_TEST)

        // Only set operations and write mask
        gl.StencilOpSeparate(gl.FRONT,
            impl.stencil_front_fail_op,
            impl.stencil_front_depth_fail_op,
            impl.stencil_front_pass_op)
        gl.StencilOpSeparate(gl.BACK,
            impl.stencil_back_fail_op,
            impl.stencil_back_depth_fail_op,
            impl.stencil_back_pass_op)

        gl.StencilMask(impl.stencil_write_mask)
    } else {
        gl.Disable(gl.STENCIL_TEST)
    }

    // Polygon offset (depth bias)
    if impl.polygon_offset_enabled {
        gl.Enable(gl.POLYGON_OFFSET_FILL)

        if impl.depth_bias_clamp != 0.0 {
            if device_impl.polygon_offset_clamp {
                gl.PolygonOffsetClamp(
                    impl.depth_bias_slope_scale, impl.depth_bias, impl.depth_bias_clamp)
            } else {
                gl.PolygonOffset(impl.depth_bias_slope_scale, impl.depth_bias)
            }
        } else {
            gl.PolygonOffset(impl.depth_bias_slope_scale, impl.depth_bias)
        }
    } else {
        gl.Disable(gl.POLYGON_OFFSET_FILL)
    }

    // Multisample state
    if impl.multisample_enabled {
        gl.Enable(gl.MULTISAMPLE)
    } else {
        gl.Disable(gl.MULTISAMPLE)
    }

    if impl.alpha_to_coverage_enabled {
        gl.Enable(gl.SAMPLE_ALPHA_TO_COVERAGE)
    } else {
        gl.Disable(gl.SAMPLE_ALPHA_TO_COVERAGE)
    }

    if impl.sample_mask_enabled {
        gl.Enable(gl.SAMPLE_MASK)
        gl.SampleMaski(0, impl.sample_mask_value)
    } else {
        gl.Disable(gl.SAMPLE_MASK)
    }

    // Color target blend state
    for target, i in impl.color_targets {
        buf := u32(i)
        if target.blend_enabled {
            gl.Enablei(gl.BLEND, buf)
            gl.BlendEquationSeparatei(buf, target.color_op, target.alpha_op)
            gl.BlendFuncSeparatei(
                buf,
                target.src_color_blend,
                target.dst_color_blend,
                target.src_alpha_blend,
                target.dst_alpha_blend,
            )
        } else {
            gl.Disablei(gl.BLEND, buf)
        }

        gl.ColorMaski(
            buf,
            target.write_red ? gl.TRUE : gl.FALSE,
            target.write_green ? gl.TRUE : gl.FALSE,
            target.write_blue ? gl.TRUE : gl.FALSE,
            target.write_alpha ? gl.TRUE : gl.FALSE,
        )
    }
}

gl_execute_render_pass_set_scissor_rect :: proc(
    cmd: ^Command_Render_Pass_Set_Scissor_Rect,
    loc := #caller_location,
) {
    gl.Enable(gl.SCISSOR_TEST)
    gl.Scissor(i32(cmd.x), i32(cmd.y), i32(cmd.width), i32(cmd.height))
}

gl_execute_render_pass_set_stencil_reference :: proc(
    cmd: ^Command_Render_Pass_Set_Stencil_Reference,
    loc := #caller_location,
) {
    // impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)

    if cmd.pipeline != nil {
        pipeline_impl := get_impl(GL_Render_Pipeline_Impl, cmd.pipeline, loc)

        gl.StencilFuncSeparate(
            gl.FRONT,
            pipeline_impl.stencil_front_compare_func,
            i32(cmd.reference),
            pipeline_impl.stencil_read_mask,
        )
        gl.StencilFuncSeparate(
            gl.BACK,
            pipeline_impl.stencil_back_compare_func,
            i32(cmd.reference),
            pipeline_impl.stencil_read_mask,
        )
    }
}

gl_execute_render_pass_set_vertex_buffer :: proc(
    cmd: ^Command_Render_Pass_Set_Vertex_Buffer,
    loc := #caller_location,
) {
    // impl := get_impl(GL_Render_Pass_Impl, cmd.render_pass, loc)
    pipeline_impl := get_impl(GL_Render_Pipeline_Impl, cmd.pipeline, loc)
    buffer_impl := get_impl(GL_Buffer_Impl, cmd.buffer, loc)

    // Validate slot
    assert(
        cmd.slot < u32(len(pipeline_impl.buffer_attributes)),
        "Invalid vertex buffer slot",
        loc,
    )

    // Get the attributes for this buffer slot
    buffer_attributes := pipeline_impl.buffer_attributes[cmd.slot]
    if len(buffer_attributes) == 0 do return

    // Get stride, all attributes in a buffer share the same stride
    stride := buffer_attributes[0].stride

    // Bind the vertex buffer
    gl.VertexArrayVertexBuffer(
        pipeline_impl.vao,
        cmd.slot,
        buffer_impl.handle,
        int(cmd.offset),
        stride,
    )

    // Enable attributes for this slot
    for &attrib in buffer_attributes {
        gl.EnableVertexArrayAttrib(pipeline_impl.vao, attrib.index)
    }
}

gl_execute_render_pass_set_viewport :: proc(
    cmd: ^Command_Render_Pass_Set_Viewport,
    loc := #caller_location,
) {
    gl.Viewport(i32(cmd.x), i32(cmd.y), i32(cmd.width), i32(cmd.height))
    gl.DepthRangef(cmd.min_depth, cmd.max_depth)
}

gl_execute_command :: proc(
    queue_impl: ^GL_Queue_Impl,
    cmd: ^Command,
    loc := #caller_location,
) {
    #partial switch &c in cmd {
    case Command_Begin_Render_Pass:
        gl_execute_begin_render_pass(&c)

    case Command_Copy_Texture_To_Texture:
        gl_execute_copy_texture_to_texture(&c)

    case Command_Render_Pass_Draw:
        gl_execute_render_pass_draw(&c)

    case Command_Render_Pass_Draw_Indexed:
        gl_execute_render_pass_draw_indexed(&c)

    case Command_Render_Pass_End:
        gl_execute_render_pass_end(&c)

    case Command_Render_Pass_Set_Bind_Group:
        gl_execute_render_pass_set_bind_group(&c)

    case Command_Render_Pass_Set_Index_Buffer:
        gl_execute_render_pass_set_index_buffer(&c)

    case Command_Render_Pass_Set_Render_Pipeline:
        gl_execute_render_pass_set_pipeline(&c)

    case Command_Render_Pass_Set_Scissor_Rect:
        gl_execute_render_pass_set_scissor_rect(&c)

    case Command_Render_Pass_Set_Stencil_Reference:
        gl_execute_render_pass_set_stencil_reference(&c)

    case Command_Render_Pass_Set_Vertex_Buffer:
        gl_execute_render_pass_set_vertex_buffer(&c)

    case Command_Render_Pass_Set_Viewport:
        gl_execute_render_pass_set_viewport(&c)
    }
}
