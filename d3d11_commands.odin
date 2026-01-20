#+build windows
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:slice"
import sa "core:container/small_array"

// Vendor
import "vendor:directx/d3d11"

d3d11_execute_begin_render_pass :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Begin_Render_Pass,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Collect render target views
    rtvs: [MAX_COLOR_ATTACHMENTS]^d3d11.IRenderTargetView
    rtv_count: u32

    // Process color attachments
    for i in 0 ..< sa.len(cmd.color_attachments) {
        color_att := sa.get(cmd.color_attachments, i)
        view_impl := get_impl(D3D11_Texture_View_Impl, color_att.view, loc)

        assert(view_impl.rtv != nil, "Color attachment view must have a render target view", loc)
        rtvs[rtv_count] = view_impl.rtv
        rtv_count += 1

        // Handle clear operation
        if color_att.ops.load == .Clear {
            clear_color: [4]f32 = {
                f32(color_att.ops.clear_value.r),
                f32(color_att.ops.clear_value.g),
                f32(color_att.ops.clear_value.b),
                f32(color_att.ops.clear_value.a),
            }
            d3d_context->ClearRenderTargetView(view_impl.rtv, &clear_color)
        }
    }

    // Handle depth stencil attachment
    dsv: ^d3d11.IDepthStencilView = nil
    if depth_stencil, ok := cmd.depth_stencil_attachment.?; ok {
        view_impl := get_impl(D3D11_Texture_View_Impl, depth_stencil.view, loc)
        texture_impl := get_impl(D3D11_Texture_Impl, view_impl.texture, loc)

        assert(view_impl.dsv != nil,
            "Depth stencil attachment view must have a depth stencil view", loc)
        dsv = view_impl.dsv

        // Determine clear flags based on format and load operations
        clear_flags: d3d11.CLEAR_FLAGS

        has_depth := texture_format_has_depth_aspect(texture_impl.format)
        has_stencil := texture_format_has_stencil_aspect(texture_impl.format)

        if has_depth && depth_stencil.depth_ops.load == .Clear {
            clear_flags |= { .DEPTH }
        }

        if has_stencil && depth_stencil.stencil_ops.load == .Clear {
            clear_flags |= { .STENCIL }
        }

        // Clear if any flags are set
        if clear_flags != {} {
            d3d_context->ClearDepthStencilView(
                dsv,
                clear_flags,
                depth_stencil.depth_ops.clear_value,
                u8(depth_stencil.stencil_ops.clear_value),
            )
        }
    }

    // Bind render targets
    d3d_context->OMSetRenderTargets(rtv_count, &rtvs[0], dsv)

    // Set default viewport
    viewport := d3d11.VIEWPORT{
        TopLeftX = 0,
        TopLeftY = 0,
        Width    = f32(cmd.width),
        Height   = f32(cmd.height),
        MinDepth = 0.0,
        MaxDepth = 1.0,
    }
    d3d_context->RSSetViewports(1, &viewport)

    // Set default scissor rect
    scissor := d3d11.RECT{
        left   = 0,
        top    = 0,
        right  = i32(cmd.width),
        bottom = i32(cmd.height),
    }
    d3d_context->RSSetScissorRects(1, &scissor)

    // Store render pass state for later commands
    encoder_impl.current_render_pass = cmd.render_pass
    encoder_impl.current_render_pass_width = cmd.width
    encoder_impl.current_render_pass_height = cmd.height
    encoder_impl.current_blend_color = {0, 0, 0, 0}
    encoder_impl.current_stencil_reference = 0
}

d3d11_execute_copy_texture_to_texture :: proc(
    cmd: ^Command_Copy_Texture_To_Texture,
    loc := #caller_location,
) {
}

d3d11_execute_render_pass_draw :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Draw,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Validate we have a pipeline set
    // assert(encoder_impl.current_pipeline != nil, "No render pipeline set", loc)

    d3d_context->Draw(cmd.vertex_count, cmd.first_vertex)
}

d3d11_execute_render_pass_draw_indexed :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Draw_Indexed,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    d3d_context->DrawIndexedInstanced(
        IndexCountPerInstance = cmd.index_count,
        InstanceCount         = cmd.instance_count,
        StartIndexLocation    = cmd.first_index,
        BaseVertexLocation    = cmd.vertex_offset,
        StartInstanceLocation = cmd.first_instance,
    )
}

d3d11_execute_render_pass_end :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_End,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Unbind render targets
    d3d_context->OMSetRenderTargets(0, nil, nil)

    @(require_results)
    calculate_subresource_index :: proc(
        mip_level: u32,
        array_layer: u32,
        mip_level_count: u32,
    ) -> u32 {
        return mip_level + (array_layer * mip_level_count)
    }

    // Find the begin command to handle store operations and resolve
    begin_cmd := encoder_impl.current_begin_render_pass_cmd
    if begin_cmd != nil {
        // Check if we need to resolve multisampled attachments
        sample_count : u32 = 1
        if sa.len(begin_cmd.color_attachments) > 0 {
            color_att0 := sa.get(begin_cmd.color_attachments, 0)
            view_impl := get_impl(D3D11_Texture_View_Impl, color_att0.view, loc)
            texture_impl := get_impl(D3D11_Texture_Impl, view_impl.texture, loc)
            sample_count = texture_impl.sample_count
        }

        // Resolve multisampled textures if needed
        if sample_count > 1 {
            for i in 0..<sa.len(begin_cmd.color_attachments) {
                color_att := sa.get(begin_cmd.color_attachments, i)

                // Skip if no resolve target
                if color_att.resolve_target == nil {
                    continue
                }

                src_view_impl := get_impl(D3D11_Texture_View_Impl, color_att.view, loc)
                dst_view_impl := get_impl(D3D11_Texture_View_Impl, color_att.resolve_target, loc)

                src_texture_impl := get_impl(D3D11_Texture_Impl, src_view_impl.texture, loc)
                dst_texture_impl := get_impl(D3D11_Texture_Impl, dst_view_impl.texture, loc)

                // Calculate subresource indices
                dst_subresource := calculate_subresource_index(
                    dst_view_impl.base_mip_level,
                    dst_view_impl.base_array_layer,
                    dst_texture_impl.mip_level_count,
                )

                src_subresource := calculate_subresource_index(
                    src_view_impl.base_mip_level,
                    src_view_impl.base_array_layer,
                    src_texture_impl.mip_level_count,
                )

                // Resolve
                d3d_context->ResolveSubresource(
                    dst_texture_impl.texture2d,
                    dst_subresource,
                    src_texture_impl.texture2d,
                    src_subresource,
                    dst_texture_impl.dxgi_format,
                )
            }
        }

        // Handle store operations (discard optimization)
        for i in 0..<sa.len(begin_cmd.color_attachments) {
            color_att := sa.get(begin_cmd.color_attachments, i)

            if color_att.ops.store == .Discard {
                view_impl := get_impl(D3D11_Texture_View_Impl, color_att.view, loc)
                if view_impl.rtv != nil {
                    d3d_context->DiscardView(view_impl.rtv)
                }
            }
        }

        // Handle depth/stencil discard
        if depth_stencil, ok := begin_cmd.depth_stencil_attachment.?; ok {
            should_discard := (
                depth_stencil.depth_ops.store == .Discard ||
                depth_stencil.stencil_ops.store == .Discard)

            if should_discard {
                view_impl := get_impl(D3D11_Texture_View_Impl, depth_stencil.view, loc)
                if view_impl.dsv != nil {
                    d3d_context->DiscardView(view_impl.dsv)
                }
            }
        }
    }

    // Clear render pass state
    encoder_impl.current_render_pass = nil
    encoder_impl.current_render_pass_width = 0
    encoder_impl.current_render_pass_height = 0
    encoder_impl.current_begin_render_pass_cmd = nil
}

d3d11_execute_render_pass_set_bind_group :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Bind_Group,
    loc := #caller_location,
) {
    bind_group_impl := get_impl(D3D11_Bind_Group_Impl, cmd.group, loc)
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    dynamic_offset_idx := 0

    for &entry in bind_group_impl.entries {
        layout_entry := &bind_group_impl.layout.entries[entry.binding]

        bind_vs := .Vertex   in layout_entry.visibility
        bind_ps := .Fragment in layout_entry.visibility
        bind_cs := .Compute  in layout_entry.visibility

        slot := entry.binding

        switch &res in entry.resource {
        case D3D11_Buffer_Binding:
            buffer_layout := layout_entry.type.(D3D11_Buffer_Binding_Layout)

            offset := res.offset
            size   := res.size

            if buffer_layout.has_dynamic_offset {
                assert(dynamic_offset_idx < len(cmd.dynamic_offsets),
                       "Not enough dynamic offsets provided", loc)
                offset += u64(cmd.dynamic_offsets[dynamic_offset_idx])
                dynamic_offset_idx += 1
            }

            switch buffer_layout.type {
            case .Uniform:
                cb := res.buffer.buffer

                // Constant buffer offsets are in units of 16 bytes (one "constant")
                // Dynamic offsets are required to be 256-byte aligned
                first_constant := u32(offset / 16)

                // Ceiling division to cover partial constants at the end
                num_constants  := u32((size + 15) / 16)

                if bind_vs {
                    d3d_context->VSSetConstantBuffers1(
                        slot, 1, &cb, &first_constant, &num_constants)
                }
                if bind_ps {
                    d3d_context->PSSetConstantBuffers1(
                        slot, 1, &cb, &first_constant, &num_constants)
                }
                if bind_cs {
                    d3d_context->CSSetConstantBuffers1(
                        slot, 1, &cb, &first_constant, &num_constants)
                }

            case .Storage, .Read_Only_Storage:
                uav := res.buffer.uav
                initial_count := max(u32) // keep existing counter for append/consume

                if bind_vs {
                    log.warn(
                        "Storage buffers in vertex shaders have very limited support in D3D11",
                        location = loc)
                }

                if bind_ps {
                    d3d_context->OMSetRenderTargetsAndUnorderedAccessViews(
                        d3d11.KEEP_RENDER_TARGETS_AND_DEPTH_STENCIL,
                        nil,
                        nil,
                        slot,
                        1,
                        &uav,
                        &initial_count,
                    )
                }

                if bind_cs {
                    d3d_context->CSSetUnorderedAccessViews(slot, 1, &uav, &initial_count)
                }

            case .Undefined:
                unreachable()
            }

        case D3D11_Sampler_Binding:
            sampler := res.sampler.sampler_state

            if bind_vs { d3d_context->VSSetSamplers(slot, 1, &sampler) }
            if bind_ps { d3d_context->PSSetSamplers(slot, 1, &sampler) }
            if bind_cs { d3d_context->CSSetSamplers(slot, 1, &sampler) }

        case D3D11_Texture_View_Binding:
            srv := res.texture_view.srv

            if bind_vs { d3d_context->VSSetShaderResources(slot, 1, &srv) }
            if bind_ps { d3d_context->PSSetShaderResources(slot, 1, &srv) }
            if bind_cs { d3d_context->CSSetShaderResources(slot, 1, &srv) }

        case []D3D11_Buffer_Binding:
            buffer_layout := layout_entry.type.(D3D11_Buffer_Binding_Layout)
            count := u32(len(res))

            switch buffer_layout.type {
            case .Uniform:
                runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

                cbs := make([]^d3d11.IBuffer, count, context.temp_allocator)
                first_constants := make([]u32, count, context.temp_allocator)
                num_constants := make([]u32, count, context.temp_allocator)

                for &buf, i in res {
                    offset := buf.offset
                    if buffer_layout.has_dynamic_offset {
                        assert(dynamic_offset_idx < len(cmd.dynamic_offsets),
                               "Not enough dynamic offsets provided", loc)
                        offset += u64(cmd.dynamic_offsets[dynamic_offset_idx])
                        dynamic_offset_idx += 1
                    }

                    cbs[i]             = buf.buffer.buffer
                    first_constants[i] = u32(offset / 16)
                    num_constants[i]   = u32((buf.size + 15) / 16)
                }

                if bind_vs {
                    d3d_context->VSSetConstantBuffers1(
                        slot, count, raw_data(cbs),
                        raw_data(first_constants), raw_data(num_constants))
                }
                if bind_ps {
                    d3d_context->PSSetConstantBuffers1(
                        slot, count, raw_data(cbs),
                        raw_data(first_constants), raw_data(num_constants))
                }
                if bind_cs {
                    d3d_context->CSSetConstantBuffers1(
                        slot, count, raw_data(cbs),
                        raw_data(first_constants), raw_data(num_constants))
                }

            case .Storage, .Read_Only_Storage:
                runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

                uavs := make([]^d3d11.IUnorderedAccessView, count, context.temp_allocator)
                initial_counts := make([]u32, count, context.temp_allocator)
                slice.fill(initial_counts, max(u32))

                for &buf, i in res {
                    uavs[i] = buf.buffer.uav
                }

                if bind_ps {
                    d3d_context->OMSetRenderTargetsAndUnorderedAccessViews(
                        d3d11.KEEP_RENDER_TARGETS_AND_DEPTH_STENCIL,
                        nil,
                        nil,
                        slot,
                        count,
                        raw_data(uavs),
                        raw_data(initial_counts),
                    )
                }
                if bind_cs {
                    d3d_context->CSSetUnorderedAccessViews(
                        slot, count, raw_data(uavs), raw_data(initial_counts))
                }

            case .Undefined:
                unreachable()
            }

        case []D3D11_Sampler_Binding:
            runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

            count := u32(len(res))
            samplers := make([]^d3d11.ISamplerState, count, context.temp_allocator)

            for &samp, i in res {
                samplers[i] = samp.sampler.sampler_state
            }

            if bind_vs { d3d_context->VSSetSamplers(slot, count, raw_data(samplers)) }
            if bind_ps { d3d_context->PSSetSamplers(slot, count, raw_data(samplers)) }
            if bind_cs { d3d_context->CSSetSamplers(slot, count, raw_data(samplers)) }

        case []D3D11_Texture_View_Binding:
            runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

            count := u32(len(res))
            srvs  := make([]^d3d11.IShaderResourceView, count, context.temp_allocator)

            for &view, i in res {
                srvs[i] = view.texture_view.srv
            }

            if bind_vs { d3d_context->VSSetShaderResources(slot, count, raw_data(srvs)) }
            if bind_ps { d3d_context->PSSetShaderResources(slot, count, raw_data(srvs)) }
            if bind_cs { d3d_context->CSSetShaderResources(slot, count, raw_data(srvs)) }
        }
    }
}

d3d11_execute_render_pass_set_index_buffer :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Index_Buffer,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    buffer_impl := get_impl(D3D11_Buffer_Impl, cmd.buffer, loc)
    index_buffer := buffer_impl.buffer
    index_buffer_format := d3d_dxgi_index_format(cmd.format)
    index_buffer_offset := u32(cmd.offset)

    d3d_context->IASetIndexBuffer(index_buffer, index_buffer_format, index_buffer_offset)
}

d3d11_command_render_pass_set_render_pipeline :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Render_Pipeline,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    pipeline_impl := get_impl(D3D11_Render_Pipeline_Impl, cmd.pipeline, loc)

    // Set primitive topology
    d3d_context->IASetPrimitiveTopology(pipeline_impl.primitive_topology)

    // Set input layout
    d3d_context->IASetInputLayout(pipeline_impl.input_layout)

    // Set rasterizer state
    d3d_context->RSSetState(pipeline_impl.rasterizer_state)

    // Set shaders
    d3d_context->VSSetShader(pipeline_impl.vertex_shader, nil, 0)
    d3d_context->PSSetShader(pipeline_impl.pixel_shader, nil, 0)

    // Set blend state
    blend_factor := [4]f32{1.0, 1.0, 1.0, 1.0}
    d3d_context->OMSetBlendState(
        pipeline_impl.blend_state,
        &blend_factor,
        pipeline_impl.sample_mask,
    )

    // Set depth stencil state
    if pipeline_impl.depth_stencil_state != nil {
        d3d_context->OMSetDepthStencilState(pipeline_impl.depth_stencil_state, 0)
    }
}

d3d11_execute_render_pass_set_scissor_rect :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Scissor_Rect,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    scissor_rect := d3d11.RECT{
        left   = i32(cmd.x),
        top    = i32(cmd.y),
        right  = i32(cmd.x + cmd.width),
        bottom = i32(cmd.y + cmd.height),
    }

    d3d_context->RSSetScissorRects(1, &scissor_rect)
}

d3d11_execute_render_pass_set_stencil_reference :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Stencil_Reference,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    pipeline_impl := get_impl(D3D11_Render_Pipeline_Impl, cmd.pipeline, loc)

    if pipeline_impl.depth_stencil_state != nil {
        d3d_context->OMSetDepthStencilState(pipeline_impl.depth_stencil_state, cmd.reference)
    }
}

d3d11_execute_render_pass_set_vertex_buffer :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Vertex_Buffer,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    buffer_impl := get_impl(D3D11_Buffer_Impl, cmd.buffer, loc)
    pipeline_impl := get_impl(D3D11_Render_Pipeline_Impl, cmd.pipeline, loc)

    assert(buffer_impl.buffer != nil, "Buffer is null", loc)
    assert(.Vertex in buffer_impl.usage, "Buffer is not a vertex buffer", loc)

    // Get stride from cached pipeline vertex buffer info
    stride: u32 = 0
    if cmd.slot < u32(len(pipeline_impl.vertex_buffers)) {
        #no_bounds_check stride = pipeline_impl.vertex_buffers[cmd.slot].stride
    } else {
        log.errorf("Vertex buffer slot %d out of range (pipeline has %d vertex buffers)",
            cmd.slot, len(pipeline_impl.vertex_buffers), location = loc)
        return
    }

    offset := u32(cmd.offset)

    d3d_context->IASetVertexBuffers(
        cmd.slot,
        1,
        &buffer_impl.buffer,
        &stride,
        &offset,
    )
}

d3d11_execute_render_pass_set_viewport :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command_Render_Pass_Set_Viewport,
    loc := #caller_location,
) {
    device_impl := get_impl(D3D11_Device_Impl, encoder_impl.device, loc)
    d3d_context := device_impl.d3d_context

    viewport := d3d11.VIEWPORT{
        TopLeftX = cmd.x,
        TopLeftY = cmd.y,
        Width    = cmd.width,
        Height   = cmd.height,
        MinDepth = cmd.min_depth,
        MaxDepth = cmd.max_depth,
    }

    d3d_context->RSSetViewports(1, &viewport)
}

d3d11_execute_command :: proc(
    encoder_impl: ^D3D11_Command_Encoder_Impl,
    cmd: ^Command,
    loc := #caller_location,
) {
    #partial switch &c in cmd {
    case Command_Begin_Render_Pass:
        d3d11_execute_begin_render_pass(encoder_impl, &c)

    case Command_Copy_Texture_To_Texture:
        d3d11_execute_copy_texture_to_texture(&c)

    case Command_Render_Pass_Draw:
        d3d11_execute_render_pass_draw(encoder_impl, &c)

    case Command_Render_Pass_Draw_Indexed:
        d3d11_execute_render_pass_draw_indexed(encoder_impl, &c)

    case Command_Render_Pass_End:
        d3d11_execute_render_pass_end(encoder_impl, &c)

    case Command_Render_Pass_Set_Bind_Group:
        d3d11_execute_render_pass_set_bind_group(encoder_impl, &c)

    case Command_Render_Pass_Set_Index_Buffer:
        d3d11_execute_render_pass_set_index_buffer(encoder_impl, &c)

    case Command_Render_Pass_Set_Render_Pipeline:
        d3d11_command_render_pass_set_render_pipeline(encoder_impl, &c)

    case Command_Render_Pass_Set_Scissor_Rect:
        d3d11_execute_render_pass_set_scissor_rect(encoder_impl, &c)

    case Command_Render_Pass_Set_Stencil_Reference:
        d3d11_execute_render_pass_set_stencil_reference(encoder_impl, &c)

    case Command_Render_Pass_Set_Vertex_Buffer:
        d3d11_execute_render_pass_set_vertex_buffer(encoder_impl, &c)

    case Command_Render_Pass_Set_Viewport:
        d3d11_execute_render_pass_set_viewport(encoder_impl, &c)
    }
}
